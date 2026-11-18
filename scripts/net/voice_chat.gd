class_name VoiceChat
extends Node
## Co-op voice. Up close you just talk (open mic, B to mute). Once the team
## has the walkie-talkies, hold V to talk to everyone on the radio: range,
## battery and static near entities apply. Radio voice also carries to anyone
## standing next to the person talking, like a real walkie-talkie.
##
## Voice keeps working through a flashback or cutscene: there the view cuts away,
## often far from where everyone is standing, so teammates' voices play flat
## instead of fading with distance from that camera, and the radio still keys
## while the scene holds everyone still.

const MIC_BUS := "VoiceMic"
const RADIO_BUS := "Radio"
## Teammates' voices (near and radio) mix here, through a limiter, so several
## people talking at once never crackle.
const CREW_BUS := "CrewVoice"
## Open-mic voice carries this far (meters)...
const NEAR_RANGE := 40.0
## ...at full volume out to this distance, fading after it (AudioStreamPlayer3D.unit_size).
const NEAR_FULL := 8.0
## How loud a teammate right next to you is (dB). The CrewVoice limiter catches the peaks.
const VOICE_DB := 4.0
## The microphone is cleaned up before it's sent: rumble below this goes (Hz)...
const MIC_HIGH_PASS := 100.0
## ...and hiss above this, which the 16 kHz codec can't carry.
const MIC_LOW_PASS := 7000.0
## Audio held back before a voice starts playing, so a late packet doesn't
## leave a gap (seconds).
const JITTER_CUSHION := 0.1
## Tag nodes with this group to make radios crackle near them.
const INTERFERENCE_GROUP := "radio_interference"

var level: Node
var radio := Radio.new()
var mic_muted := false
## Counters for tests and the debug overlay: packets heard per mode.
var heard := {"near": 0, "radio": 0}
var last_quality := 1.0

var _capture: AudioEffectCapture
var _mic: AudioStreamPlayer
## peer id -> {"radio": AudioStreamPlayer, "near": AudioStreamPlayer3D, "flat": AudioStreamPlayer}
var _speakers := {}
var _rng := RandomNumberGenerator.new()
var _was_transmitting := false
var _rx_name := ""
var _rx_t := 0.0
var _hud: Label
var _encoder := VoiceCodec.Encoder.new()
var _gate := VoiceCodec.Gate.new()
var _leveler := VoiceCodec.Leveler.new()
## While the mic is closed, its last moment of audio, sent when it opens.
var _preroll := PackedVector2Array()


static func create(for_level: Node) -> VoiceChat:
	var v := VoiceChat.new()
	v.name = "Voice"
	v.level = for_level
	for_level.add_child(v)
	return v


func _ready() -> void:
	_setup_radio_bus()
	_build_hud()
	if _online() and DisplayServer.get_name() != "headless":
		_start_mic()


func _online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)


func _has_walkie() -> bool:
	var game := get_node_or_null("/root/Game")
	return game != null and game.has_walkie


func _process(delta: float) -> void:
	var talking := false
	if _online() and _has_walkie() and _keys_free():
		talking = Input.is_action_pressed("radio_talk")
	radio.tick(delta, talking)
	if radio.transmitting != _was_transmitting:
		_was_transmitting = radio.transmitting
		_squelch.rpc(radio.transmitting)
	if _online() and Input.is_action_just_pressed("voice_toggle") and _keys_free():
		mic_muted = not mic_muted
	if _capture:
		var n := _capture.get_frames_available()
		if n > 0:
			var rate := AudioServer.get_mix_rate()
			var out := mic_block(_capture.get_buffer(n), rate)
			if not out.is_empty():
				send_frames(out, rate, radio.transmitting)
	_rx_t -= delta
	_update_hud()


## One block of microphone audio in; what to send (nothing while the mic is
## closed). When it opens, the moment just before comes too, so the first sound
## of a word isn't cut off.
func mic_block(frames: PackedVector2Array, rate: float) -> PackedVector2Array:
	var open := _gate.update(VoiceCodec.rms(frames), frames.size() / rate)
	if radio.transmitting or (open and not mic_muted):
		if _preroll.is_empty():
			return frames
		_preroll.append_array(frames)
		var out := _preroll
		_preroll = PackedVector2Array()
		return out
	_preroll.append_array(frames)
	var keep := int(rate * VoiceCodec.Gate.PREROLL)
	if _preroll.size() > keep:
		_preroll = _preroll.slice(_preroll.size() - keep)
	return PackedVector2Array()


## V and B work while the player can move, and while a flashback or cutscene
## holds them still (nothing to type into there). Not at a terminal or the
## notebook, which keep the player's own view and take typing.
func _keys_free() -> bool:
	if not is_instance_valid(level.player):
		return false
	return not level.player.input_locked or not hearing_from_body()


## Hearing the world from the player's own head: their camera is the one in use.
## Not in a flashback or cutscene, where the camera is somewhere else entirely.
func hearing_from_body() -> bool:
	if not is_instance_valid(level.player):
		return false
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam == level.player.get("camera")


## Send some microphone audio. Public so tests can feed it frames.
func send_frames(frames: PackedVector2Array, rate: float, on_radio: bool) -> void:
	if not _online():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var packet := _encoder.encode(_leveler.process(frames, rate, _gate.speech), rate)
	if not packet.is_empty():
		_voice.rpc(on_radio, packet)


@rpc("any_peer", "unreliable_ordered", "call_remote", 2)
func _voice(on_radio: bool, data: PackedByteArray) -> void:
	var from := multiplayer.get_remote_sender_id()
	var body: Node3D = level.players.puppet(from)
	if body == null or not is_instance_valid(level.player):
		return
	var frames := VoiceCodec.decode(data)
	var spk := _speaker(from)
	var dist := body.global_position.distance_to(level.player.global_position)
	if not hearing_from_body():
		# The camera is away (a flashback's garage): a voice from the world would
		# fade out with distance from it, so the whole crew is heard as if close.
		heard.near += 1
		_push(spk.flat, frames)
	elif dist < NEAR_RANGE:
		heard.near += 1
		_push(spk.near, frames)
	if on_radio and _has_walkie():
		var sources := _interference_sources()
		var interference := maxf(Radio.interference_at(body.global_position, sources), Radio.interference_at(level.player.global_position, sources))
		last_quality = Radio.signal_quality(dist, interference)
		heard.radio += 1
		_push(spk.radio, Radio.degrade(frames, last_quality, _rng))
		_rx_name = body.get("display_name") if body.get("display_name") else "?"
		_rx_t = 0.3


@rpc("any_peer", "reliable", "call_remote", 2)
func _squelch(on: bool) -> void:
	if not _has_walkie():
		return
	var spk := _speaker(multiplayer.get_remote_sender_id())
	_push(spk.radio, Radio.squelch(int(VoiceCodec.RATE * (0.08 if on else 0.15)), _rng))


func _interference_sources() -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group(INTERFERENCE_GROUP):
		if n is Node3D and n.get_viewport() == get_viewport() and n.is_visible_in_tree():
			out.append(n.global_position)
	return out


func _speaker(id: int) -> Dictionary:
	if _speakers.has(id) and is_instance_valid(_speakers[id].radio):
		return _speakers[id]
	var r := AudioStreamPlayer.new()
	r.stream = _generator()
	r.bus = RADIO_BUS
	r.volume_db = VOICE_DB
	add_child(r)
	r.play()
	var near := AudioStreamPlayer3D.new()
	near.stream = _generator()
	near.bus = CREW_BUS
	near.max_distance = NEAR_RANGE
	# Full volume within a few meters, still clear across a big room.
	near.unit_size = NEAR_FULL
	near.volume_db = VOICE_DB
	near.max_db = VOICE_DB
	# Distance makes a voice quieter, not muffled: keep every word clear.
	near.attenuation_filter_cutoff_hz = 20500.0
	var body: Node = level.players.puppet(id)
	(body if body else self).add_child(near)
	near.position.y = 1.6
	near.play()
	var flat := AudioStreamPlayer.new()
	flat.stream = _generator()
	flat.bus = CREW_BUS
	flat.volume_db = near.volume_db  # as loud as someone standing next to you
	add_child(flat)
	flat.play()
	_speakers[id] = {"radio": r, "near": near, "flat": flat}
	return _speakers[id]


func _generator() -> AudioStreamGenerator:
	var g := AudioStreamGenerator.new()
	g.mix_rate = VoiceCodec.RATE
	g.buffer_length = 0.6
	return g


func _push(player: Node, frames: PackedVector2Array) -> void:
	if not is_instance_valid(player):
		return
	var pb = player.get_stream_playback()
	if pb == null:
		return
	var room: int = pb.get_frames_available()
	# Nothing queued (the talker just started, or a packet was late): hold a
	# moment of silence first so the next packet arrives before this runs out.
	var capacity: int = player.get_meta("capacity", 0)
	if room > capacity:
		player.set_meta("capacity", room)
		capacity = room
	if room >= capacity:
		var cushion := PackedVector2Array()
		cushion.resize(int(VoiceCodec.RATE * JITTER_CUSHION))
		pb.push_buffer(cushion)
		room -= cushion.size()
	if room < frames.size():
		frames = frames.slice(0, room)
	if not frames.is_empty():
		pb.push_buffer(frames)


func _start_mic() -> void:
	var idx := AudioServer.get_bus_index(MIC_BUS)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, MIC_BUS)
		AudioServer.set_bus_mute(idx, true)  # capture it, but don't play yourself back
		for fx in mic_effects():
			AudioServer.add_bus_effect(idx, fx)
	_capture = AudioServer.get_bus_effect(idx, AudioServer.get_bus_effect_count(idx) - 1)
	_capture.clear_buffer()
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = MIC_BUS
	add_child(_mic)
	_mic.play()


## The microphone bus, in order: rumble out, hiss out, then the capture the
## game reads (last). Public so tests can run audio through the same chain.
static func mic_effects() -> Array[AudioEffect]:
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = MIC_HIGH_PASS
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = MIC_LOW_PASS
	lp.db = AudioEffectFilter.FILTER_24DB
	lp.resonance = 0.85  # flat (within 2 dB) up to 6 kHz
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 0.5  # rides out a slow frame without losing audio
	return [hp, lp, capture]


## Teammates' voices, then a band-limited walkie-talkie bus that feeds into it.
## (A bus can only send to one before it, so CrewVoice comes first.)
static func _setup_radio_bus() -> void:
	if AudioServer.get_bus_index(CREW_BUS) == -1:
		AudioServer.add_bus()
		var crew := AudioServer.bus_count - 1
		AudioServer.set_bus_name(crew, CREW_BUS)
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(crew, limiter)
	if AudioServer.get_bus_index(RADIO_BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, RADIO_BUS)
	AudioServer.set_bus_send(idx, CREW_BUS)
	# A real walkie-talkie's narrow band, but wide enough to understand every word.
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 300
	AudioServer.add_bus_effect(idx, hp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 4500
	AudioServer.add_bus_effect(idx, lp)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_hud = ThemeUtil.label("", 18, ThemeUtil.GREEN)
	_hud.add_theme_font_override("font", ThemeUtil.mono())
	_hud.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.position = Vector2(-28, -40)
	layer.add_child(_hud)


func _update_hud() -> void:
	if not _online():
		_hud.text = ""
		return
	var lines := PackedStringArray()
	if _rx_t > 0.0:
		lines.append("RX  %s" % _rx_name)
	if _has_walkie():
		var bars := int(ceil(radio.battery * 5))
		var state := "TX" if radio.transmitting else ("DEAD" if not radio.can_transmit() else "[V] talk")
		lines.append("RADIO %s%s %3d%%  %s" % ["|".repeat(bars), ".".repeat(5 - bars), int(radio.battery * 100), state])
	lines.append("MIC %s  [B]" % ("muted" if mic_muted else "open"))
	_hud.text = "\n".join(lines)
	_hud.add_theme_color_override("font_color", ThemeUtil.RED if radio.transmitting else ThemeUtil.GREEN)
