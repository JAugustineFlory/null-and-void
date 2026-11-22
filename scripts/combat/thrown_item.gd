class_name ThrownItem
extends Node3D
## Something a player threw (Counterplay), in the air: it flies the path the host
## worked out. Where it lands, Counterplay leaves it as gear (GearPickup) for anyone
## to pick up again.

var item := ""


## `what` in flight, starting at `at` (world space).
static func make(parent: Node, what: String, at: Vector3) -> ThrownItem:
	var it := ThrownItem.new()
	it.item = what
	it.position = (parent as Node3D).to_local(at) if parent is Node3D else at
	it.add_child(GearPickup.model_of(what))
	parent.add_child(it)
	return it


## Along `path` (world space points) over `time` seconds, tumbling.
func fly(path: PackedVector3Array, time: float) -> void:
	if path.size() < 2:
		return
	var parent := get_parent() as Node3D
	var tw := create_tween()
	var step := time / float(path.size() - 1)
	for i in range(1, path.size()):
		tw.tween_property(self, "position", parent.to_local(path[i]) if parent else path[i], step)
	create_tween().tween_property(self, "rotation:x", TAU * maxf(1.0, round(time * 2.0)), time)
