class_name Interactable
extends StaticBody3D
## Something the player can look at and press E (or X) on.

signal used(player: Node)
signal alt_used(player: Node)

var prompt := "Use"
var alt_prompt := ""
var enabled := true
## Co-op: act on this machine only, instead of asking the host (e.g. hopping a counter).
var local_only := false


static func create(parent: Node, center: Vector3, size: Vector3, prompt_text: String, color: Color = Color(0.3, 0.3, 0.3), visible_mesh: bool = true) -> Interactable:
	var it := Interactable.new()
	it.position = center
	it.prompt = prompt_text
	if visible_mesh:
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mesh.mesh = bm
		mesh.material_override = Greybox.mat(color)
		it.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	it.add_child(shape)
	parent.add_child(it)
	it.add_to_group("interactable")
	return it


func get_prompt(_player: Node) -> String:
	if not enabled:
		return ""
	var p := "[E] " + prompt
	if alt_prompt != "":
		p += "    [X] " + alt_prompt
	return p


## In co-op, a client's press is sent to the host, which decides what happens.
func interact(player: Node) -> void:
	if enabled and not _forwarded("interact"):
		used.emit(player)


func interact_alt(player: Node) -> void:
	if enabled and alt_prompt != "" and not _forwarded("interact_alt"):
		alt_used.emit(player)


func _forwarded(method: String) -> bool:
	if local_only:
		return false
	var sync := LevelSync.of(self)
	return sync != null and sync.forward(self, method)
