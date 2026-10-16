class_name Voice
extends Node
## Plays recorded dialogue. A recording is a file in audio/voice/ named after its
## line id in VoiceLines (l0_greet_1.ogg, .wav or .mp3). Lines without a recording
## stay silent and their subtitle is timed from the text instead.

const EXTENSIONS := ["ogg", "wav", "mp3"]
## Gap after a recording before the next line starts.
const TAIL := 0.35
## WARDEN speaks through the building's PA: thin, boxy, a little roomy.
const PA_BUS := &"VoicePA"

## Where recordings live. Tests point this somewhere else.
static var folder := "res://audio/voice/"

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_ensure_pa_bus()


## Path of the recording for this line, or "" if it hasn't been recorded yet.
static func path_for(id: String) -> String:
	for ext in EXTENSIONS:
		var p: String = folder.path_join("%s.%s" % [id, ext])
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			return p
	return ""


## The recording for this line, or null.
static func stream_for(id: String) -> AudioStream:
	var p := path_for(id)
	if p == "":
		return null
	if ResourceLoader.exists(p):
		return load(p) as AudioStream
	# Not imported (a file dropped in while the game wasn't opened in the editor).
	match p.get_extension():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(p)
		"wav":
			return AudioStreamWAV.load_from_file(p)
		"mp3":
			return AudioStreamMP3.load_from_file(p)
	return null


## How long a subtitle stays up when there is no recording.
static func read_time(text: String) -> float:
	return clamp(1.2 + text.length() * 0.055, 2.0, 9.0)


## Start this line's recording, cutting off whatever was playing.
## Returns how long to wait before the next line: the recording's length,
## or 0.0 if there is no recording.
func play(id: String) -> float:
	var stream := stream_for(id)
	if stream == null:
		return 0.0
	_player.stream = stream
	_player.bus = PA_BUS if VoiceLines.get_line(id).get("speaker") == "WARDEN" else &"Master"
	_player.play()
	return stream.get_length() + TAIL


func stop() -> void:
	_player.stop()


func is_playing() -> bool:
	return _player.playing


static func _ensure_pa_bus() -> void:
	if AudioServer.get_bus_index(PA_BUS) >= 0:
		return
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, PA_BUS)
	AudioServer.set_bus_send(bus, &"Master")
	var high := AudioEffectHighPassFilter.new()
	high.cutoff_hz = 350.0
	var low := AudioEffectLowPassFilter.new()
	low.cutoff_hz = 3800.0
	var room := AudioEffectReverb.new()
	room.room_size = 0.35
	room.wet = 0.18
	room.dry = 0.9
	for fx in [high, low, room]:
		AudioServer.add_bus_effect(bus, fx)
