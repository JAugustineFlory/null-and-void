class_name HandItem
extends RefCounted
## Hotbar items you see in your own hands when you take them out (keys 1-4): a
## model under the camera in the "carried" group, which your own body's hands
## hold by its two near corners (FirstPersonBody). An item with no model here is
## carried out of sight. The Player shows it, and puts it away while your hands
## are busy (climbing, fighting, reading, at a terminal).

## Where each item is held, in the camera's space: low in front of you, its top
## tipped towards you.
const HELD := {
	"deck": Transform3D(Basis(Vector3.RIGHT, 1.05), Vector3(0.0, -0.27, -0.42)),
}
## The portable deck, shut: a rugged laptop in a rubber bumper, with a carry handle.
const DECK_SIZE := Vector3(0.3, 0.035, 0.22)
const DECK_BODY := Color(0.16, 0.17, 0.18)
const DECK_BUMPER := Color(0.85, 0.55, 0.12)


static func has_model(item: String) -> bool:
	return HELD.has(item)


## `item`'s model in your hands, under `camera`; null if it has none.
static func make(item: String, camera: Node3D) -> Node3D:
	if not has_model(item):
		return null
	var n: Node3D = deck() if item == "deck" else null
	n.name = "Hand_" + item
	n.transform = HELD[item]
	n.add_to_group("carried")
	for m in n.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(n)
	return n


## A portable deck, shut, lying flat (its lid up, the handle at the front, -z).
static func deck() -> Node3D:
	var root := Node3D.new()
	_box(root, Vector3.ZERO, DECK_SIZE, DECK_BODY)
	# The lid's seam, round the sides.
	_box(root, Vector3(0, 0.002, 0), Vector3(DECK_SIZE.x + 0.002, 0.003, DECK_SIZE.z + 0.002), Color(0.06, 0.06, 0.07))
	# Rubber corners.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(root, Vector3(sx * (DECK_SIZE.x / 2 - 0.012), 0, sz * (DECK_SIZE.z / 2 - 0.012)), Vector3(0.034, DECK_SIZE.y + 0.008, 0.034), DECK_BUMPER)
	# The carry handle, along the front edge.
	_box(root, Vector3(0, 0, -DECK_SIZE.z / 2 - 0.012), Vector3(0.12, 0.016, 0.014), Color(0.08, 0.08, 0.09))
	return root


static func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = Greybox.mat(color)
	m.position = at
	parent.add_child(m)
	return m
