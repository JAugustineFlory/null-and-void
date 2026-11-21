class_name ThrownItem
extends Interactable
## Something a player threw (Counterplay): it flies the path the host worked out,
## lands, and lies there for anyone to pick up again. A fire extinguisher keeps the
## blasts it had left.

var item := ""
## A fire extinguisher's blasts left, or -1.
var blasts := -1
var _mesh: MeshInstance3D


static func make(parent: Node, what: String, at: Vector3, left: int) -> ThrownItem:
	var it := ThrownItem.new()
	it.item = what
	it.blasts = left
	it.prompt = "Pick up " + Inventory.item_name(what).to_lower()
	it.position = (parent as Node3D).to_local(at) if parent is Node3D else at
	var size := Vector3(0.22, 0.32, 0.22) if what == Counterplay.EXTINGUISHER else Vector3(0.24, 0.12, 0.18)
	it._mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	it._mesh.mesh = bm
	it._mesh.position.y = size.y / 2.0
	it._mesh.material_override = Greybox.mat(Color(0.75, 0.1, 0.08) if what == Counterplay.EXTINGUISHER else Color(0.55, 0.55, 0.5))
	it.add_child(it._mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size + Vector3(0.1, 0.1, 0.1)
	shape.shape = box
	shape.position.y = size.y / 2.0
	it.add_child(shape)
	parent.add_child(it)
	it.add_to_group("interactable")
	return it


func interact(player: Node) -> void:
	if not enabled:
		return
	var c := Counterplay.of(self)
	if c:
		enabled = false  # once: the host hands it to whoever asked first
		c.pick_up(self)
		used.emit(player)


## Along `path` (world space points) over `time` seconds; it can be picked up once down.
func fly(path: PackedVector3Array, time: float) -> void:
	if path.size() < 2:
		return
	enabled = false
	var parent := get_parent() as Node3D
	var tw := create_tween()
	var step := time / float(path.size() - 1)
	for i in range(1, path.size()):
		tw.tween_property(self, "position", parent.to_local(path[i]) if parent else path[i], step)
	tw.tween_callback(func(): enabled = true)
