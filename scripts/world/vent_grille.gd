class_name VentGrille
extends ItemLock
## E10: a vent's grille over a duct-wide opening (a floor vent, a ceiling vent, a
## wall vent, or a hole in a duct's own floor). Screwed on, the screwdriver takes
## it off, and only from the room side (the screws are on that side: from inside
## the duct it's just shut). Built with no item, anyone lifts it out from the room
## or pushes it up from underneath. Off, it swings open on one edge and the way's
## open. A kit piece (ItemLock), so co-op plays it as every kit piece: the host
## decides, every machine swings it. Never labeled: its prompt shows only when you
## look at it.

const SCREWDRIVER := "screwdriver"
## Words for a screwed grille, waiting on Augustine's OK (plan/approvals/v0.10-vent-strings.md).
const UNSCREW := "Unscrew the vent grille"
const SCREWED := "It's screwed shut."
const COLOR := Color(0.16, 0.17, 0.18)

## Out of the duct: the room side, where its screws are (world space).
var normal := Vector3.UP
## What it says to someone on the duct side, for a grille with no screws ("" for
## the same as the room side).
var below_text := ""
## A floor vent's climb out of the duct, up through it (Traversal.hatch): on once
## the grille's off. Null for other grilles.
var climb_out: MovementVolume


## A grille over the opening centred at `center`, facing `facing` (out of the duct,
## toward the room: up for a floor vent, down for a ceiling vent, out of the wall
## for a wall vent). `inner` is the duct's inside (width, height). `id` names it
## the same on every machine. In `parent`'s space; it isn't geo (it moves).
## Screwed (`item` "screwdriver", the default) it says UNSCREW / SCREWED. With
## `item` "" anyone opens it, and `use` is what it says from the room side and
## `below` from the duct side. A floor vent with an `out` spot (on the room floor,
## beside it) also gets the climb up out of the duct through it, on once it's open.
static func place(parent: Node, id: String, center: Vector3, facing: Vector3, inner := Vector2(1.0, 1.0), item_id := SCREWDRIVER, use := UNSCREW, below := "", out := Vector3(INF, INF, INF)) -> VentGrille:
	facing = facing.normalized()
	var flat := absf(facing.y) > 0.5
	# Across the opening: `side` is where its hinge is, `span` the other way.
	var side := Vector3.RIGHT if flat or absf(facing.x) < 0.5 else Vector3.BACK
	var span := facing.cross(side).normalized()
	var w := inner.x
	var tall := inner.x if flat else inner.y
	var thick := 0.04
	var size := (side * w + span * tall).abs() + facing.abs() * thick
	var g := VentGrille.new()
	g.name = "Grille_" + id
	g.position = center
	g.item = item_id
	g.use_text = use
	g.need_text = SCREWED if item_id == SCREWDRIVER else ""
	g.below_text = below
	g.kind = "lever"
	g._shape(size)
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = -side * w / 2.0
	g.add_child(hinge)
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = size
	frame.mesh = fm
	frame.material_override = Greybox.mat(COLOR)
	frame.position = side * w / 2.0
	hinge.add_child(frame)
	# Its slats, across it, so it reads as a vent.
	var n := int(tall / 0.12)
	for i in n:
		var s := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = (side * (w - 0.08)).abs() + span.abs() * 0.03 + facing.abs() * 0.02
		s.mesh = sm
		s.material_override = Greybox.mat(COLOR.darkened(0.4))
		s.position = side * w / 2.0 + span * (-tall / 2.0 + 0.06 + i * (tall - 0.12) / maxf(n - 1, 1)) + facing * (thick / 2.0 + 0.005)
		hinge.add_child(s)
	parent.add_child(g)
	g.add_to_group("interactable")
	g.normal = (g.global_basis * facing).normalized() if g.is_inside_tree() else facing
	if flat and facing.y > 0.0 and out.x != INF:
		g.climb_out = Traversal.hatch(parent, center, Vector2(w, w), out)
		g.climb_out.name = "ClimbOut_" + id
		if g.is_inside_tree():
			g.climb_out.a = (parent as Node3D).to_global(center)
			g.climb_out.b = (parent as Node3D).to_global(out)
		g.climb_out.active = false
	g.opened.connect(func(_peer):
		for c in g.get_children():
			if c is CollisionShape3D:
				c.set_deferred("disabled", true)
		# Off, it swings out on the hinge edge.
		hinge.basis = Basis(span, -PI / 2.0)
		if g.climb_out:
			g.climb_out.active = true)
	return g


## On the room side (where its screws are)?
func from_room(player: Node) -> bool:
	return not (player is Node3D) or ((player as Node3D).global_position + Vector3.UP * 0.9 - global_position).dot(normal) > 0.0


func get_prompt(player: Node) -> String:
	_seen_shining(player)
	if not enabled or is_open:
		return ""
	if from_room(player):
		return super.get_prompt(player)
	if item != "":
		return SCREWED  # the screws are on the other side
	return "[E] " + (below_text if below_text != "" else use_text)


func interact(player: Node) -> void:
	if item == "" or from_room(player):
		super.interact(player)


## Host: a player pressed it (their puppet, in co-op).
func report_use(player: Node, hand: Dictionary) -> void:
	if item == "" or from_room(player):
		super.report_use(player, hand)
