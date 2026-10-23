class_name Sfx
## Sound effects and the sound buses. Levels call `Sfx.play(parent, "glass", pos)`
## from code that already runs on every machine (a sync.event handler), so everyone
## hears the same thing in the same place.
##
## Each kind is a recorded file in audio/sfx/ when there is one (<kind>.ogg or .wav,
## or variants <kind>_1, <kind>_2, ... picked at random each time), otherwise a sound
## SfxSynth makes in code. Drop a same-named file in audio/sfx/ to replace one.
##
## Buses: Master > Music, SFX, Ambience, Voice. Volumes are saved in user://audio.cfg.

const MUSIC := &"Music"
const SFX := &"SFX"
const AMBIENCE := &"Ambience"
const VOICE := &"Voice"
const BUSES := [MUSIC, SFX, AMBIENCE, VOICE]
const DIR := "res://audio/sfx/"
const SETTINGS := "user://audio.cfg"
## Most variants a kind can have (<kind>_1 .. <kind>_8).
const MAX_VARIANTS := 8

## How each kind plays: its bus, loudness and how far it carries (unit_size: metres
## at full volume). Anything not listed is a short effect on SFX.
const KINDS := {
	"glass": {"unit": 6.0},
	"clunk": {"unit": 6.0},
	"click": {"unit": 6.0},
	"clatter": {"unit": 6.0},
	"tap": {"unit": 6.0},
	"beep": {"unit": 2.0, "db": -8.0},
	"error": {"unit": 2.0, "db": -8.0},
	"key": {"unit": 1.5, "db": -10.0, "pitch": 0.12},
	"flicker": {"bus": AMBIENCE, "unit": 2.5, "db": -6.0, "pitch": 0.15},
	"door_motor": {"unit": 4.0, "db": -4.0},
	"fluorescent_buzz": {"bus": AMBIENCE, "unit": 1.2, "db": -18.0},
	"crt_whine": {"bus": AMBIENCE, "unit": 0.8, "db": -20.0},
	"server_hum": {"bus": AMBIENCE, "unit": 3.0, "db": -10.0},
}

static var _streams := {}
static var _settings_loaded := false


## Adds the buses if they aren't there yet, at their saved volumes. Safe to call often.
static func ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, &"Master")
	if not _settings_loaded:
		_settings_loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS) == OK:
			for b in [&"Master"] + BUSES:
				if cfg.has_section_key("volume", b):
					_set_bus_linear(b, float(cfg.get_value("volume", b)))


## The bus a kind plays on (made if it's missing).
static func bus_for(kind: String) -> StringName:
	ensure_buses()
	return KINDS.get(kind, {}).get("bus", SFX)


## The sound for `kind`: a recorded file if audio/sfx/ has one, else made in code.
## Null if neither exists.
static func stream(kind: String) -> AudioStream:
	if not _streams.has(kind):
		_streams[kind] = _recorded(kind, DIR)
		if _streams[kind] == null:
			_streams[kind] = SfxSynth.make(kind)
	return _streams[kind]


## Forgets loaded sounds, so a newly dropped-in file is picked up (tests, Foley swaps).
static func clear_cache() -> void:
	_streams.clear()


## Plays `kind` once at `pos` (in `parent`'s space). The player frees itself after.
static func play(parent: Node, kind: String, pos: Vector3, volume_db := 0.0) -> AudioStreamPlayer3D:
	if not parent.is_inside_tree():
		return null
	# What played where, for the tests (a played sound frees itself). The last few only.
	var played: Array = parent.get_meta("sounds_played", [])
	played.append({"kind": kind, "pos": pos})
	if played.size() > 32:
		played.pop_front()
	parent.set_meta("sounds_played", played)
	var p := _player_3d(kind, volume_db)
	p.name = "Sound_" + kind
	p.position = pos
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Plays `kind` once with no position: menus, the terminal you're sitting at.
static func play_flat(parent: Node, kind: String, volume_db := 0.0) -> AudioStreamPlayer:
	if not parent.is_inside_tree():
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream(kind)
	p.bus = bus_for(kind)
	p.volume_db = KINDS.get(kind, {}).get("db", 0.0) + volume_db
	p.pitch_scale = _pitch(kind)
	p.name = "Sound_" + kind
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## A looping sound (a buzzing tube, a monitor) at `pos` that plays until freed or
## stopped. Each loop starts at a different point so a row of them doesn't phase.
static func loop(parent: Node, kind: String, pos: Vector3, volume_db := 0.0) -> AudioStreamPlayer3D:
	var p := _player_3d(kind, volume_db)
	p.name = "Loop_" + kind
	p.position = pos
	p.autoplay = true
	parent.add_child(p)
	if p.is_inside_tree() and p.stream:
		p.play(randf() * p.stream.get_length())
	return p


## A bus's volume, 0 silent to 1 as mixed (Master goes to 2).
static func volume(bus: StringName) -> float:
	ensure_buses()
	var idx := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(idx)) if idx != -1 else 0.0


## Sets a bus's volume and saves it.
static func set_volume(bus: StringName, linear: float) -> void:
	ensure_buses()
	_set_bus_linear(bus, linear)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("volume", bus, linear)
	cfg.save(SETTINGS)


static func _set_bus_linear(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


static func _player_3d(kind: String, volume_db: float) -> AudioStreamPlayer3D:
	var info: Dictionary = KINDS.get(kind, {})
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(kind)
	p.bus = bus_for(kind)
	p.unit_size = info.get("unit", 6.0)
	p.volume_db = info.get("db", 0.0) + volume_db
	p.pitch_scale = _pitch(kind)
	return p


## Small random pitch changes, so a repeated sound (keys, flickers) isn't a machine gun.
static func _pitch(kind: String) -> float:
	var spread: float = KINDS.get(kind, {}).get("pitch", 0.0)
	return 1.0 + randf_range(-spread, spread) if spread > 0.0 else 1.0


## The recorded file(s) for `kind` in `dir`, or null. Several variants come back as
## one AudioStreamRandomizer.
static func _recorded(kind: String, dir: String) -> AudioStream:
	var found: Array[AudioStream] = []
	var one := _load_file(dir + kind)
	if one:
		found.append(one)
	for i in range(1, MAX_VARIANTS + 1):
		var v := _load_file("%s%s_%d" % [dir, kind, i])
		if v == null:
			break
		found.append(v)
	if found.is_empty():
		return null
	if found.size() == 1:
		return found[0]
	var r := AudioStreamRandomizer.new()
	r.random_pitch = 1.0
	for s in found:
		r.add_stream(-1, s)
	return r


## `base`.ogg or `base`.wav: imported (res://), or loaded raw (anywhere else).
static func _load_file(base: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		var path: String = base + ext
		if ResourceLoader.exists(path):
			return load(path)
		if not path.begins_with("res://") and FileAccess.file_exists(path):
			return AudioStreamOggVorbis.load_from_file(path) if ext == ".ogg" else AudioStreamWAV.load_from_file(path)
	return null
