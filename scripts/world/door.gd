class_name Door
extends AnimatableBody3D
## A sliding security door. Its state comes from the `doors` table.
## If the actuator is faulted, the database can say "unlocked" while the door stays shut.

@export var door_id := ""
@export var size := Vector3(1.6, 2.4, 0.2)
@export var slide_axis := Vector3.UP

var is_open := false
var _closed_pos := Vector3.ZERO
var _tween: Tween


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
	_closed_pos = position
	sync_to_physics = false


func set_open(open: bool, instant: bool = false) -> void:
	if open == is_open:
		return
	is_open = open
	var target := _closed_pos + (slide_axis * (size.y - 0.15) if open else Vector3.ZERO)
	if _tween:
		_tween.kill()
	if instant:
		position = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "position", target, 1.1 if open else 0.35).set_trans(Tween.TRANS_QUAD)


## Called when the database row changes. A faulted actuator ignores the change.
func apply_db_state(locked: bool, fault: bool) -> void:
	if fault:
		return
	set_open(not locked)
