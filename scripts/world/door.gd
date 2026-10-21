class_name Door
extends AnimatableBody3D
## A sliding security door, or an ordinary hinged one (see `hinge`). Its state
## comes from the `doors` table.
## If the actuator is faulted, the database can say "unlocked" while the door stays shut.

@export var door_id := ""
@export var size := Vector3(1.6, 2.4, 0.2)
@export var slide_axis := Vector3.UP

## Set to swing open on a hinge instead of sliding: the hinge's offset from the
## door's centre (its edge, e.g. Vector3(0, 0, -0.9) for a 1.8 m door along z),
## and how far it swings, in degrees (the sign picks the side it opens to).
var hinge := Vector3.ZERO
var swing_deg := 90.0
## 0 shut, 1 fully open. Hinged doors are posed from it.
var swing := 0.0:
	set(v):
		swing = v
		_pose_swing()

## Hinged doors are ordinary doors: anyone can open and shut them with E,
## unless `locked` (a badge door: only a badge holder like Rourke opens it).
var locked := false

var is_open := false
var _closed_pos := Vector3.ZERO
var _closed_rot := 0.0
var _tween: Tween


## Make it an ordinary door on a hinge at `edge` (offset from its centre) that
## swings `degrees` when opened.
func make_hinged(edge: Vector3, degrees: float = 90.0) -> Door:
	hinge = edge
	swing_deg = degrees
	return self


static func create(parent: Node, id: String, pos: Vector3, door_size: Vector3, color: Color = Color(0.35, 0.37, 0.4)) -> Door:
	var d := Door.new()
	d.door_id = id
	d.size = door_size
	d.position = pos
	d.name = "Door_" + id
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = door_size
	mesh.mesh = bm
	mesh.material_override = Greybox.mat(color, 0.0, 0.5)
	d.add_child(mesh)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(door_size.x * 0.9 if door_size.x > door_size.z else door_size.x + 0.02, 0.12, door_size.z + 0.02 if door_size.x > door_size.z else door_size.z * 0.9)
	stripe.mesh = sm
	stripe.material_override = Greybox.mat(Color(0.8, 0.6, 0.1))
	stripe.position.y = door_size.y * 0.25
	d.add_child(stripe)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = door_size
	shape.shape = bs
	d.add_child(shape)
	parent.add_child(d)
	d.add_to_group("doors")
	return d


func _ready() -> void:
	_capture_closed_pose()
	sync_to_physics = false


## A shut door at rest is in its closed pose. Taken again each time it starts to
## open, so a door placed or turned after Door.create (a stairwell's) swings from
## where it really stands.
func _capture_closed_pose() -> void:
	_closed_pos = position
	_closed_rot = rotation.y


func is_hinged() -> bool:
	return hinge != Vector3.ZERO


## What looking at the door says: hinged doors open and shut with E.
func get_prompt(_player: Node) -> String:
	if not is_hinged():
		return ""
	if locked:
		return "Locked"
	return "[E] Close the door" if is_open else "[E] Open the door"


## E on a hinged door: the host opens or shuts it on every machine.
func interact(_player: Node) -> void:
	if not is_hinged() or locked:
		return
	var sync := LevelSync.of(self)
	if sync == null:
		set_open(not is_open)
	elif not sync.forward(self, "interact"):
		sync.run_on(self, "set_open", [not is_open])


func _pose_swing() -> void:
	if not is_hinged() or not is_inside_tree():
		return
	var turn := Basis(Vector3.UP, deg_to_rad(swing_deg * swing))
	var edge := Basis(Vector3.UP, _closed_rot) * hinge  # the hinge turns with the door
	position = _closed_pos + edge + turn * -edge
	rotation.y = _closed_rot + deg_to_rad(swing_deg * swing)


func set_open(open: bool, instant: bool = false) -> void:
	if open == is_open:
		return
	if open and not (_tween and _tween.is_running()) and swing == 0.0:
		_capture_closed_pose()
	is_open = open
	if is_hinged():
		if _tween:
			_tween.kill()
		if instant:
			swing = 1.0 if open else 0.0
			return
		_tween = create_tween()
		_tween.tween_property(self, "swing", 1.0 if open else 0.0, 0.9 if open else 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return
	var target := _closed_pos + (slide_axis * (size.y - 0.15) if open else Vector3.ZERO)
	if _tween:
		_tween.kill()
	if instant:
		position = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "position", target, 1.1 if open else 0.35).set_trans(Tween.TRANS_QUAD)


## Called when the database row changes. A hinged door's row is its lock: it
## shuts and stays shut while locked, and players open it themselves once it
## isn't. A sliding door opens itself when unlocked, unless its actuator is faulted.
func apply_db_state(db_locked: bool, fault: bool) -> void:
	if is_hinged():
		locked = db_locked
		if db_locked:
			set_open(false)
		return
	if fault:
		return
	set_open(not db_locked)
