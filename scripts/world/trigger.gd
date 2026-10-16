class_name Trigger
extends Area3D
## Fires `entered` once when the player walks in. In co-op only the host's
## copy fires (it sees everyone), and `require_all` waits for every player.

signal entered(body: Node)
## With require_all: how many players are inside so far.
signal waiting(inside: int, total: int)

var once := true
## Wait until every player is inside before firing.
var require_all := false
var _fired := false
var _inside := {}


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
	if not body.is_in_group("player") or not multiplayer.is_server():
		return
	if once and _fired:
		return
	if require_all:
		_inside[body] = true
		var total := get_tree().get_nodes_in_group("player").filter(func(p): return p.get_viewport() == get_viewport()).size()
		for b in _inside.keys():
			if not is_instance_valid(b) or not overlaps_body(b):
				_inside.erase(b)
		if _inside.size() < total:
			waiting.emit(_inside.size(), total)
			return
	_fired = true
	entered.emit(body)
