class_name Hum
extends Node3D
## The Hum: a low tone that grows the longer you stand in the dark, and fades
## when you leave or switch your flashlight on. It never hurts anyone; it teaches
## that the dark is somewhere you don't want to linger.
## Each machine hears its own player's Hum, so nothing is synced.

const RATE := 22050
## Seconds of darkness to reach full volume, and to fade back out with light.
const RISE_TIME := 8.0
const FALL_TIME := 2.5
const QUIET_DB := -40.0
const LOUD_DB := -6.0

## Where it's dark, in this node's space.
var zone := AABB()
## 0 silent, 1 as loud as it gets. Read-only.
var intensity := 0.0
## Overrides which player it listens for (tests); otherwise this machine's own.
var listener: Node3D
var _player: AudioStreamPlayer


## A Hum over the box `zone` (in `parent`'s space).
static func create(parent: Node3D, box: AABB) -> Hum:
	var h := Hum.new()
	h.name = "Hum"
	h.zone = box
	parent.add_child(h)
	return h


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.stream = tone()
	_player.volume_db = QUIET_DB
	add_child(_player)


func _process(delta: float) -> void:
	var p := _listener()
	var target := 0.0
	if p and zone.has_point(to_local(p.global_position) + Vector3(0, 0.5, 0)):
		var lit: bool = p.get("flashlight") != null and p.flashlight.visible
		target = 0.0 if lit else 1.0
	if target > intensity:
		intensity = minf(target, intensity + delta / RISE_TIME)
	else:
		intensity = maxf(target, intensity - delta / FALL_TIME)
	if intensity > 0.0:
		if not _player.playing:
			_player.play()
		_player.volume_db = lerpf(QUIET_DB, LOUD_DB, sqrt(intensity))
	elif _player.playing:
		_player.stop()


func is_humming() -> bool:
	return intensity > 0.0


func _listener() -> Node3D:
	if is_instance_valid(listener):
		return listener
	var level := get_parent()
	while level and level.get("player") == null:
		level = level.get_parent()
	return level.player if level else null


## Two seconds of a low drone that loops: two close tones beating slowly, a
## little mains buzz on top.
static func tone() -> AudioStreamWAV:
	var n := RATE * 2
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 55.5 * t) * 0.35 + sin(TAU * 110.0 * t) * 0.12 + sin(TAU * 165.0 * t) * 0.05
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 22000))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w
