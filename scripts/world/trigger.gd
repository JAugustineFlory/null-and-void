class_name Trigger
extends Area3D
## Fires `entered` once when the player walks in.

signal entered(body: Node)

var once := true
var _fired := false


static func create(parent: Node, center: Vector3, size: Vector3, fire_once: bool = true) -> Trigger:
	var t := Trigger.new()
	t.position = center
	t.once = fire_once
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	t.add_child(shape)
	parent.add_child(t)
	t.body_entered.connect(t._on_body_entered)
	return t


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if once and _fired:
		return
	_fired = true
	entered.emit(body)
