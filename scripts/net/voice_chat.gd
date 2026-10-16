class_name VoiceChat
extends Node
## Co-op voice. Up close you just talk (open mic, B to mute). Once the team
## has the walkie-talkies, hold V to talk to everyone on the radio: range,
## battery and static near entities apply. Radio voice also carries to anyone
## standing next to the person talking, like a real walkie-talkie.

const MIC_BUS := "VoiceMic"
const RADIO_BUS := "Radio"
const NEAR_RANGE := 25.0
const OPEN_MIC_THRESHOLD := 0.015
const OPEN_MIC_HANG := 0.5
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
var _speakers := {}  # peer id -> {"radio": AudioStreamPlayer, "near": AudioStreamPlayer3D}
var _rng := RandomNumberGenerator.new()
var _open_mic_t := 0.0
var _was_transmitting := false
var _rx_name := ""
var _rx_t := 0.0
var _hud: Label


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
	if _online() and _has_walkie() and is_instance_valid(level.player) and not level.player.input_locked:
		talking = Input.is_action_pressed("radio_talk")
	radio.tick(delta, talking)
	if radio.transmitting != _was_transmitting:
		_was_transmitting = radio.transmitting
		_squelch.rpc(radio.transmitting)
	if _online() and Input.is_action_just_pressed("voice_toggle") and is_instance_valid(level.player) and not level.player.input_locked:
		mic_muted = not mic_muted
	if _capture:
		var n := _capture.get_frames_available()
		if n > 0:
			var frames := _capture.get_buffer(n)
			if VoiceCodec.rms(frames) > OPEN_MIC_THRESHOLD:
				_open_mic_t = OPEN_MIC_HANG
			_open_mic_t -= delta
			if radio.transmitting or (_open_mic_t > 0.0 and not mic_muted):
				send_frames(frames, AudioServer.get_mix_rate(), radio.transmitting)
	_rx_t -= delta
	_update_hud()


## Send some microphone audio. Public so tests can feed it frames.
func send_frames(frames: PackedVector2Array, rate: float, on_radio: bool) -> void:
	if not _online():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_voice.rpc(on_radio, VoiceCodec.encode(frames, rate))


@rpc("any_peer", "unreliable_ordered", "call_remote", 2)
func _voice(on_radio: bool, data: PackedByteArray) -> void:
	var from := multiplayer.get_remote_sender_id()
	var body: Node3D = level.players.puppet(from)
	if body == null or not is_instance_valid(level.player):
		return
	var frames := VoiceCodec.decode(data)
	var spk := _speaker(from)
	var dist := body.global_position.distance_to(level.player.global_position)
	if dist < NEAR_RANGE:
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
	add_child(r)
	r.play()
	var near := AudioStreamPlayer3D.new()
	near.stream = _generator()
	near.max_distance = NEAR_RANGE
	near.unit_size = 4.0
	var body: Node = level.players.puppet(id)
	(body if body else self).add_child(near)
	near.position.y = 1.6
	near.play()
	_speakers[id] = {"radio": r, "near": near}
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
		AudioServer.add_bus_effect(idx, AudioEffectCapture.new())
	_capture = AudioServer.get_bus_effect(idx, 0)
	_capture.clear_buffer()
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = MIC_BUS
	add_child(_mic)
	_mic.play()


## A tinny, band-limited bus for radio voices.
static func _setup_radio_bus() -> void:
	if AudioServer.get_bus_index(RADIO_BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, RADIO_BUS)
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 500
	AudioServer.add_bus_effect(idx, hp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 3200
	AudioServer.add_bus_effect(idx, lp)
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	dist.drive = 0.35
	AudioServer.add_bus_effect(idx, dist)


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
