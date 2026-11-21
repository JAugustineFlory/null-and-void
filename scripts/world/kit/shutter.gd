class_name Shutter
extends AnimatableBody3D
## A motor-driven roller shutter or gate that rises to open. The level drives it
## (`set_open`), or it runs on its own cycle (`cycle`: open for x seconds, shut for y),
## and a jammed GearTrain stops it dead where it is: held open, held shut, or stuck
## half-way, with a gap underneath to slide through. Co-op: the host runs the cycle
## and every machine follows its flips; a jam carries the host's exact position.

## It reached the top (true) or the floor (false).
signal settled(open: bool)

var size := Vector3(2.0, 2.4, 0.12)
## 0 shut, 1 fully open.
var openness := 0.0
## Where it's heading: 0 or 1.
var target := 0.0
## Of its travel per second, opening and closing.
var speed := 0.45
## Stopped by a jam: it doesn't move, whatever it's told.
var jammed := false
## (seconds open, seconds shut) to run by itself; ZERO for none (the level drives it).
var cycle := Vector2.ZERO
var _wait := 0.0
var _closed_pos := Vector3.ZERO
var _moving := false
var _motor: AudioStreamPlayer3D


static func make(parent: Node, id: String, pos: Vector3, door_size: Vector3, facing_deg := 0.0, start_open := false) -> Shutter:
	var s := Shutter.new()
	s.name = "Shutter_" + id
	s.size = door_size
	s.position = pos
	s.rotation_degrees.y = facing_deg
	s.openness = 1.0 if start_open else 0.0
	s.target = s.openness
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = door_size
	mesh.mesh = bm
	mesh.material_override = Greybox.mat(Color(0.46, 0.47, 0.48), 0.0, 0.5)
	s.add_child(mesh)
	# Slats, so it reads as a roller shutter.
	for i in int(door_size.y / 0.3):
		KitPiece._box(s, Vector3(0, -door_size.y / 2.0 + 0.15 + i * 0.3, door_size.z / 2.0 + 0.004), Vector3(door_size.x - 0.04, 0.03, 0.01), Color(0.36, 0.37, 0.38))
	# A yellow-black bottom bar.
	KitPiece._box(s, Vector3(0, -door_size.y / 2.0 + 0.04, 0), Vector3(door_size.x, 0.08, door_size.z + 0.03), Color(0.85, 0.65, 0.1))
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = door_size
	shape.shape = bs
	s.add_child(shape)
	parent.add_child(s)
	return s


func _ready() -> void:
	_closed_pos = position
	_pose()


## The height of the opening under it, in metres.
func gap() -> float:
	return openness * (size.y - 0.1)


func is_open() -> bool:
	return openness >= 0.999


## Every machine: head open or shut (ignored while jammed, but remembered).
func set_open(open: bool) -> void:
	target = 1.0 if open else 0.0
	_wait = cycle.x if open else cycle.y


## Every machine: stop where the host says (`at`), or run on again.
func set_jammed(on: bool, at: float) -> void:
	jammed = on
	if on:
		openness = clampf(at, 0.0, 1.0)
		_pose()
		_set_moving(false)


func _physics_process(delta: float) -> void:
	if jammed:
		return
	if openness != target:
		var was := openness
		openness = move_toward(openness, target, speed * delta)
		_set_moving(true)
		_pose()
		if openness == target:
			_set_moving(false)
			if target == 0.0 and was > 0.0 and get_parent() is Node3D:
				Sfx.play(get_parent(), "clunk", position)
			settled.emit(target == 1.0)
	elif cycle != Vector2.ZERO and _is_host():
		_wait -= delta
		if _wait <= 0.0:
			var sync := LevelSync.of(self)
			if sync and sync.level and sync.level.is_ancestor_of(self):
				sync.run_on(self, "set_open", [target == 0.0])
			else:
				set_open(target == 0.0)


func _pose() -> void:
	if is_inside_tree():
		position = _closed_pos + Vector3.UP * gap()


func _set_moving(on: bool) -> void:
	if on == _moving:
		return
	_moving = on
	if on and get_parent() is Node3D and is_inside_tree():
		_motor = Sfx.play(self, "door_motor", Vector3.ZERO)
	elif is_instance_valid(_motor):
		_motor.stop()


func _is_host() -> bool:
	var sync := LevelSync.of(self)
	return sync == null or sync.is_host()
