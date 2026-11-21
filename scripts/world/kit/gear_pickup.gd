class_name GearPickup
extends KitPiece
## One piece of gear lying somewhere (a keyboard on a shelf, a fuse in a drawer):
## whoever takes it has it, and it's gone for everyone else. Hands full of gear, you
## swap: what you hold is left here in its place. `place` puts it at one of a few
## spots, picked by the run's seed, so each run hides it somewhere else.

## Every machine: player `peer_id` took `item` (and left `left`, or "").
signal picked(peer_id: int, item: String, left: String)

## Aim box for each kind of gear (anything else gets DEFAULT_SIZE).
const SIZES := {
	"keyboard": Vector3(0.48, 0.08, 0.2),
	"power_cord": Vector3(0.24, 0.1, 0.24),
	"fuse": Vector3(0.14, 0.08, 0.14),
	"crowbar": Vector3(0.7, 0.08, 0.14),
	"fire_extinguisher": Vector3(0.2, 0.55, 0.2),
	"screwdriver": Vector3(0.24, 0.06, 0.1),
	"cable": Vector3(0.32, 0.1, 0.32),
}
const DEFAULT_SIZE := Vector3(0.25, 0.12, 0.25)

var item := ""
var taken := false
var _model: Node3D
var _shape_node: CollisionShape3D


## Gear `item` resting at `pos` (its bottom on the surface).
static func make(parent: Node, item_id: String, pos: Vector3, facing_deg := 0.0) -> GearPickup:
	var g := GearPickup.new()
	g.name = "Gear_" + item_id
	g.position = pos
	g.rotation_degrees.y = facing_deg
	g.kind = "item"
	parent.add_child(g)
	g.add_to_group("interactable")
	g._show(item_id)
	return g


## Gear `item` at one of `spots` (Vector3s, or [Vector3, facing_deg] pairs), picked
## for `key` by the run's seed. Every machine picks the same one.
static func place(parent: Node, item_id: String, spots: Array, key: String) -> GearPickup:
	var spot = spots[KitPiece.seeded(key, spots.size())]
	var g: GearPickup
	if spot is Array:
		g = make(parent, item_id, spot[0], spot[1])
	else:
		g = make(parent, item_id, spot)
	g.name = "Gear_" + key
	return g


func prompt_for(hand: Dictionary) -> String:
	if taken:
		return ""
	if KitPiece.carries(hand, item):
		return KitWords.say("already", [KitWords.item(item)])
	if KitPiece.has_room(hand, item):
		return KitWords.say("pick_up", [KitWords.item(item)])
	if Inventory.GEAR.has(hand.get("held", "")):
		return KitWords.say("swap", [KitWords.item(hand.held), KitWords.item(item)])
	return KitWords.say("hands_full")


func can_use(hand: Dictionary) -> bool:
	return not taken and not KitPiece.carries(hand, item) and (KitPiece.has_room(hand, item) or Inventory.GEAR.has(hand.get("held", "")))


func decide(peer: int, hand: Dictionary) -> void:
	play("_picked", [peer, "" if KitPiece.has_room(hand, item) else String(hand.held)])


## Every machine: `peer` takes it, leaving `left` (gear from their hands) here.
func _picked(peer: int, left: String) -> void:
	if taken:
		return
	var got := item
	if left != "":
		_take(peer, left)
	_give(peer, got)
	_sound_for(peer, "item")
	if left != "":
		_show(left)
	else:
		taken = true
		visible = false
		enabled = false
		_shape_node.disabled = true
	picked.emit(peer, got, left)


## Shows `item_id` here: its model and aim box.
func _show(item_id: String) -> void:
	item = item_id
	if is_instance_valid(_model):
		_model.queue_free()
	if is_instance_valid(_shape_node):
		_shape_node.queue_free()
	var size: Vector3 = SIZES.get(item, DEFAULT_SIZE)
	_shape_node = _shape(size, Vector3(0, size.y / 2.0, 0))
	_model = model_of(item)
	add_child(_model)
	prompt = KitWords.say("pick_up", [KitWords.item(item)])


## A small model of gear `item_id`, lying flat, its bottom at y 0.
static func model_of(item_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	match item_id:
		"keyboard":
			ArtProps.keyboard(root, Vector3.ZERO, 0)
		"power_cord":
			var coil := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.06
			tm.outer_radius = 0.1
			tm.rings = 12
			tm.ring_segments = 6
			coil.mesh = tm
			coil.position.y = 0.02
			coil.scale.y = 0.6
			coil.material_override = Greybox.mat(Color(0.12, 0.12, 0.13))
			root.add_child(coil)
			KitPiece._box(root, Vector3(0.11, 0.02, 0), Vector3(0.05, 0.03, 0.04), Color(0.1, 0.1, 0.1))  # the plug
		"fuse":
			var glass := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.012
			cy.bottom_radius = 0.012
			cy.height = 0.07
			cy.radial_segments = 8
			glass.mesh = cy
			glass.rotation_degrees.z = 90
			glass.position.y = 0.012
			glass.material_override = Greybox.mat(Color(0.8, 0.85, 0.9), 0.0, 0.2)
			root.add_child(glass)
			for x in [-0.04, 0.04]:
				KitPiece._box(root, Vector3(x, 0.012, 0), Vector3(0.012, 0.026, 0.026), Color(0.75, 0.72, 0.65))  # caps
		"crowbar":
			KitPiece._box(root, Vector3(0, 0.012, 0), Vector3(0.62, 0.024, 0.024), Color(0.12, 0.12, 0.14))
			KitPiece._box(root, Vector3(0.31, 0.012, 0.03), Vector3(0.024, 0.024, 0.07), Color(0.12, 0.12, 0.14))  # the hook
			KitPiece._box(root, Vector3(-0.2, 0.013, 0), Vector3(0.18, 0.028, 0.028), Color(0.7, 0.1, 0.08))  # red grip
		"fire_extinguisher":
			var can := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.075
			cyl.bottom_radius = 0.075
			cyl.height = 0.45
			cyl.radial_segments = 12
			can.mesh = cyl
			can.position.y = 0.225
			can.material_override = Greybox.mat(Color(0.72, 0.08, 0.06))
			root.add_child(can)
			KitPiece._box(root, Vector3(0, 0.48, 0), Vector3(0.05, 0.07, 0.05), Color(0.15, 0.15, 0.15))  # valve
		"screwdriver":
			KitPiece._box(root, Vector3(-0.05, 0.015, 0), Vector3(0.1, 0.03, 0.03), Color(0.95, 0.75, 0.1))  # handle
			KitPiece._box(root, Vector3(0.05, 0.015, 0), Vector3(0.11, 0.008, 0.008), Color(0.7, 0.7, 0.72))  # shaft
		_:
			KitPiece._box(root, Vector3(0, 0.05, 0), Vector3(0.2, 0.1, 0.2), Color(0.4, 0.4, 0.42))
	return root
