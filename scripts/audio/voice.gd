class_name Voice
extends Node
## Plays recorded dialogue. A recording is a file in audio/voice/ named after its
## line id in VoiceLines (l0_greet_1.ogg, .wav or .mp3). Lines without a recording
## stay silent and their subtitle is timed from the text instead.

const EXTENSIONS := ["ogg", "wav", "mp3"]
## Gap after a recording before the next line starts. Actors leave half a second
## of silence at each end of their files, so this only needs to be short.
const TAIL := 0.1
## WARDEN and the building's announcements play through the PA: thin, boxy speakers
## echoing down empty halls. The dry voice stays at full level so subtitles and
## speech still line up; the hall is added underneath. Both end up on the Voice bus,
## so the pause menu's Voices slider turns them up and down together.
const PA_BUS := &"VoicePA"
const PA_SPEAKERS := ["WARDEN", "PA"]

## Where recordings live. Tests point this somewhere else.
static var folder := "res://audio/voice/"

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_ensure_pa_bus()


## Path of the recording for this line, or "" if it hasn't been recorded yet.
## Looks in the character's own folder first (audio/voice/rourke/l0_greet_1.wav,
## where actors' files go), then in audio/voice/ itself. Extra takes
## (l0_greet_1_take2.wav) are never picked up; rename the one you want.
## `own_dir` is a folder to look in before all of those: a crew line is recorded once
## per playable character, in audio/voice/crew_<character>/.
static func path_for(id: String, own_dir: String = "") -> String:
	id = VoiceLines.resolve(id)
	var dirs: Array[String] = [folder]
	var speaker: String = VoiceLines.get_line(id).get("speaker", "")
	if VoiceLines.CHARACTERS.has(speaker):
		dirs.push_front(folder.path_join(VoiceLines.CHARACTERS[speaker]["slug"]))
	if own_dir != "":
		dirs.push_front(folder.path_join(own_dir))
	for dir in dirs:
		for ext in EXTENSIONS:
			var p: String = dir.path_join("%s.%s" % [id, ext])
			if ResourceLoader.exists(p) or FileAccess.file_exists(p):
				return p
	return ""


## The recording for this line, or null.
static func stream_for(id: String, dir: String = "") -> AudioStream:
	var p := path_for(id, dir)
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


## Play a crew member's bark (see VoiceLines.BARKS). Returns its length, or
## 0.0 if they haven't recorded it yet.
func play_bark(slug: String, bark: String) -> float:
	return play(VoiceLines.bark_id(bark), VoiceLines.crew_dir(slug))


## How long a subtitle stays up when there is no recording.
static func read_time(text: String) -> float:
	return clamp(1.2 + text.length() * 0.055, 2.0, 9.0)


## Start this line's recording, cutting off whatever was playing.
## Returns how long to wait before the next line: the recording's length,
## or 0.0 if there is no recording.
func play(id: String, dir: String = "") -> float:
	var stream := stream_for(id, dir)
	if stream == null:
		return 0.0
	_player.stream = stream
	_player.bus = PA_BUS if VoiceLines.get_line(id).get("speaker") in PA_SPEAKERS else Sfx.VOICE
	_player.play()
	return stream.get_length() + TAIL


func stop() -> void:
	_player.stop()


func is_playing() -> bool:
	return _player.playing


static func _ensure_pa_bus() -> void:
	# Voice first: a bus only sends to one made before it.
	Sfx.ensure_buses()
	if AudioServer.get_bus_index(PA_BUS) >= 0:
		return
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, PA_BUS)
	AudioServer.set_bus_send(bus, Sfx.VOICE)
	var high := AudioEffectHighPassFilter.new()
	high.cutoff_hz = 350.0
	var low := AudioEffectLowPassFilter.new()
	low.cutoff_hz = 3800.0
	var hall := AudioEffectReverb.new()
	hall.room_size = 0.85
	hall.damping = 0.45
	hall.spread = 1.0
	hall.hipass = 0.3
	# A short gap and a faint repeat before the tail: the slap off the far wall.
	hall.predelay_msec = 80.0
	hall.predelay_feedback = 0.3
	hall.dry = 1.0
	hall.wet = 0.32
	for fx in [high, low, hall]:
		AudioServer.add_bus_effect(bus, fx)
