class_name Trigger
extends Area3D
## Fires `entered` once when the player walks in. In co-op only the host's
## copy fires (it sees everyone), and `require_all` waits for every player
## who's present: not dead (Hard mode) and not passed out (CrewVitals.is_present),
## or one teammate out cold with no kit near would hold the crew there for good.

const GROUP := "triggers"

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
	t.add_to_group(GROUP)
	return t


## Look again at who's inside (someone waited on just died or passed out).
func recheck() -> void:
	if not require_all or (once and _fired) or not multiplayer.is_server():
		return
	for b in _inside.keys():
		if is_instance_valid(b) and overlaps_body(b) and _living(b):
			_on_body_entered(b)
			return


## Counted for "everyone": not dead or out cold. Down but awake still counts.
func _living(body: Node) -> bool:
	var crew = CrewVitals.of(self)
	if crew == null or not crew.has_method("is_present") or crew.players == null:
		return true
	return crew.is_present(crew.players.id_of(body))


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or not multiplayer.is_server():
		return
	if once and _fired:
		return
	if require_all:
		_inside[body] = true
		var total := get_tree().get_nodes_in_group("player").filter(func(p): return p.get_viewport() == get_viewport() and _living(p)).size()
		for b in _inside.keys():
			if not is_instance_valid(b) or not overlaps_body(b):
				_inside.erase(b)
		var here := _inside.keys().filter(_living).size()
		if here == 0 or here < total:
			waiting.emit(here, total)
			return
	_fired = true
	entered.emit(body)
