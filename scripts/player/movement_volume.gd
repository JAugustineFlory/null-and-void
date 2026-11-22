class_name MovementVolume
extends Area3D
## A space that changes how the player moves while they are inside it: a vent
## to crawl through, something to climb, or a narrow ledge to shuffle along.
## Build them with the `Traversal` helpers.

enum Kind { VENT, CLIMB, LEDGE, HATCH }

var kind := Kind.VENT
## CLIMB: bottom and top of the climbable, at the climber's feet.
## LEDGE: the two ends of the walkable line, at foot height.
## HATCH: a = the middle of the opening's rim, b = where you come out on top.
var a := Vector3.ZERO
var b := Vector3.ZERO
## Points away from the wall, toward where the player stands or hangs.
var normal := Vector3.FORWARD
## Off, it changes nothing (a hatch whose panel is shut).
var active := true


static func create(parent: Node, center: Vector3, size: Vector3, volume_kind: Kind) -> MovementVolume:
	var v := MovementVolume.new()
	v.kind = volume_kind
	v.position = center
	v.monitorable = false
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	v.add_child(shape)
	parent.add_child(v)
	v.body_entered.connect(v._on_body_entered)
	v.body_exited.connect(v._on_body_exited)
	v.add_to_group("movement_volume")
	return v


## Is `p` (world space) inside it?
func has_point(p: Vector3) -> bool:
	var bs := (get_child(0) as CollisionShape3D).shape as BoxShape3D
	var l := global_transform.affine_inverse() * p
	return absf(l.x) <= bs.size.x / 2.0 and absf(l.y) <= bs.size.y / 2.0 and absf(l.z) <= bs.size.z / 2.0


func _on_body_entered(body: Node) -> void:
	if body.has_method("enter_volume"):
		body.enter_volume(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("exit_volume"):
		body.exit_volume(self)
