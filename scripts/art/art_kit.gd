class_name ArtKit
extends RefCounted
## Prop kits for spaces other threads are building: the tower's fire stairs and
## the crew's garage home base. Same rules as ArtProps: boxes, faces -Z at
## rotation 0, `facing_deg` turns it. Stairwell pieces are visual only (the
## stairs' owners build the steps and walls, and the Watcher sees by raycast);
## garage furniture you can bump into is a StaticBody3D with one box collider.


# --- Fire stairs ---------------------------------------------------------------

const STAIR_GREY := Color(0.5, 0.5, 0.48)  # painted concrete
const RAIL_RED := Color(0.55, 0.12, 0.09)  # gloss-painted steel handrail
const STENCIL := Color(0.92, 0.9, 0.84)


## A steel handrail on posts from `from` to `to` (both at the nosing line, on the
## tread), 0.9 m above it. Works for a sloped flight or a flat landing run.
static func stair_rail(parent: Node, from: Vector3, to: Vector3, posts := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Handrail"
	parent.add_child(root, true)
	var rail_mat := ArtPalette.flat(RAIL_RED, 0.35, 0.4)
	var post_mat := ArtPalette.flat(Color(0.2, 0.2, 0.21), 0.5, 0.6)
	var up := Vector3(0, 0.9, 0)
	_bar(root, from + up, to + up, 0.045, rail_mat)
	_bar(root, from + up * 0.5, to + up * 0.5, 0.025, post_mat)  # mid rail
	var n := posts if posts > 0 else maxi(2, int(ceil(from.distance_to(to) / 1.2)) + 1)
	for i in n:
		var p := from.lerp(to, float(i) / (n - 1))
		_bar(root, p, p + up, 0.04, post_mat)
	return root


## The stencilled floor number on a stairwell wall, as fire codes ask: a big
## number with the tower's name over it and the roof/ground arrows under it.
## `storey` 0 is the ground floor ("G").
static func landing_number(parent: Node, pos: Vector3, facing_deg: float, storey: int) -> Node3D:
	var root := ArtProps._node(parent, pos, facing_deg, "LandingNumber")
	ArtProps._piece(root, Vector3(0.62, 0.82, 0.01), Vector3.ZERO, ArtPalette.flat(Color(0.12, 0.2, 0.36), 0.6))
	var big := _stencil(root, "G" if storey == 0 else str(storey), 220, Vector3(0, 0.06, -0.008))
	big.pixel_size = 0.0018
	_stencil(root, "HALCYON TOWER", 34, Vector3(0, 0.33, -0.008)).pixel_size = 0.0012
	_stencil(root, "STAIR A   ROOF 30 ↑   EXIT G ↓", 30, Vector3(0, -0.3, -0.008)).pixel_size = 0.0011
	return root


## A twin-head battery emergency light over a stairwell door: a white box with
## two lamp heads and a green charge LED. With `lit` it carries a small real light
## (the stairs are lit by these alone when the mains are down).
static func emergency_light(parent: Node, pos: Vector3, facing_deg: float, lit := true) -> Node3D:
	var root := ArtProps._node(parent, pos, facing_deg, "EmergencyLight")
	var shell := ArtPalette.flat(Color(0.88, 0.87, 0.83), 0.45)
	ArtProps._piece(root, Vector3(0.36, 0.14, 0.1), Vector3.ZERO, shell)
	ArtProps._piece(root, Vector3(0.012, 0.012, 0.004), Vector3(0.13, -0.03, -0.051), ArtPalette.glow(Color(0.2, 1.0, 0.3), 3.0))
	var head_mat: Material = ArtPalette.glow(ArtPalette.LIGHT_WARM, 3.0) if lit else ArtPalette.flat(Color(0.35, 0.34, 0.3), 0.3)
	for sx in [-1.0, 1.0]:
		var head := ArtProps._piece(root, Vector3(0.1, 0.08, 0.1), Vector3(sx * 0.14, -0.1, -0.06), head_mat)
		head.rotation_degrees = Vector3(-30, sx * 25, 0)
	if lit:
		var l := SpotLight3D.new()
		l.name = "Lamp"
		l.light_color = ArtPalette.LIGHT_WARM
		l.light_energy = 1.6
		l.spot_range = 7.0
		l.spot_angle = 60.0
		l.position = Vector3(0, -0.12, -0.08)
		l.rotation_degrees.x = -50.0
		root.add_child(l)
	return root


## Dress every Stairwell (scripts/world/stairwell.gd) under the level's geo:
## painted concrete, a real handrail up the flight, the stencilled floor plate in
## place of the greybox label, and a lit emergency light over the door, which is
## the stairs' only light. The flight's colliders and the door stay as built.
static func dress_stairwells(level: Node3D) -> int:
	var count := 0
	var geo: Node3D = level.get("geo")
	if geo == null:
		return 0
	for holder in geo.get_children():
		if not (holder is Node3D and holder.name.begins_with("Stairwell")):
			continue
		var storey := -1
		for c in holder.get_children():
			if c is Label3D and "FLOOR " in (c as Label3D).text:
				var f := (c as Label3D).text.get_slice("FLOOR ", 1).strip_edges()
				storey = 0 if f == "G" else int(f)
				c.visible = false
				ArtKit.landing_number(holder, Vector3(c.position.x + 0.06, 1.6, c.position.z), -90, storey)
		ArtDress.reskin(holder, [
			{"names": ["Stair"], "mat": ArtPalette.surface("concrete", Color(1.05, 1.05, 1.0))},
			{"names": ["Floor"], "mat": ArtPalette.surface("concrete", Color(0.85, 0.85, 0.82))},
			{"names": ["Wall_", "Ceiling"], "mat": ArtPalette.surface("concrete", Color(1.3, 1.3, 1.24))},
		])
		var first := Vector3.INF
		var last := Vector3.INF
		for c in holder.get_children():
			if c is StaticBody3D and c.name.begins_with("StairRail"):
				for mi in c.get_children():
					if mi is MeshInstance3D:
						mi.visible = false
			elif c is StaticBody3D and c.name.begins_with("Stair"):
				var top := _box_top(c)
				if first == Vector3.INF or top.z > first.z:
					first = top
				if last == Vector3.INF or top.z < last.z:
					last = top
		if first != Vector3.INF and last != first:
			var inner := first.x - _box_size(_first_stair(holder)).x / 2.0 + 0.05
			stair_rail(holder, Vector3(inner, first.y, first.z), Vector3(inner, last.y, last.z))
		emergency_light(holder, Vector3(0, 2.55, -0.21), 0)
		count += 1
	return count


static func _first_stair(holder: Node) -> StaticBody3D:
	for c in holder.get_children():
		if c is StaticBody3D and c.name.begins_with("Stair") and not c.name.begins_with("StairRail"):
			return c
	return null


static func _box_size(body: Node) -> Vector3:
	for mi in body.get_children():
		if mi is MeshInstance3D and (mi as MeshInstance3D).mesh is BoxMesh:
			return ((mi as MeshInstance3D).mesh as BoxMesh).size
	return Vector3.ZERO


## The middle of a step's tread, in the holder's space.
static func _box_top(body: Node3D) -> Vector3:
	return body.position + Vector3(0, _box_size(body).y / 2.0, 0)


# --- The garage home base (Byte-Right IT Services, 1997) ------------------------

## A grey folding table on splayed legs, top at 0.74 m.
static func folding_table(parent: Node, pos: Vector3, facing_deg := 0.0, width := 1.8) -> StaticBody3D:
	var body := ArtProps._body(parent, pos, facing_deg, "FoldingTable", Vector3(width, 0.76, 0.76), Vector3(0, 0.38, 0))
	ArtProps._piece(body, Vector3(width, 0.035, 0.76), Vector3(0, 0.74, 0), ArtPalette.flat(Color(0.62, 0.6, 0.55), 0.6), true)
	var leg := ArtPalette.flat(Color(0.2, 0.2, 0.2), 0.4, 0.7)
	for sx in [-1.0, 1.0]:
		var a := ArtProps._piece(body, Vector3(0.03, 0.78, 0.03), Vector3(sx * (width / 2 - 0.2), 0.37, 0), leg)
		a.rotation_degrees.x = 18.0
		var b := ArtProps._piece(body, Vector3(0.03, 0.78, 0.03), Vector3(sx * (width / 2 - 0.2), 0.37, 0), leg)
		b.rotation_degrees.x = -18.0
	return body


## A metal folding chair.
static func folding_chair(parent: Node, pos: Vector3, facing_deg := 0.0) -> StaticBody3D:
	var body := ArtProps._body(parent, pos, facing_deg, "FoldingChair", Vector3(0.44, 0.85, 0.44), Vector3(0, 0.42, 0))
	var steel := ArtPalette.flat(Color(0.32, 0.33, 0.35), 0.45, 0.6)
	ArtProps._piece(body, Vector3(0.42, 0.03, 0.4), Vector3(0, 0.45, 0), steel, true)
	ArtProps._piece(body, Vector3(0.42, 0.2, 0.02), Vector3(0, 0.75, 0.2), steel)
	for sx in [-1.0, 1.0]:
		ArtProps._piece(body, Vector3(0.025, 0.88, 0.025), Vector3(sx * 0.2, 0.44, 0.19), steel)
		var front := ArtProps._piece(body, Vector3(0.025, 0.47, 0.025), Vector3(sx * 0.2, 0.23, -0.12), steel)
		front.rotation_degrees.x = 15.0
	return body


## A rolling whiteboard with marker writing. Visual only (lean it on a wall).
static func whiteboard(parent: Node, pos: Vector3, facing_deg: float, text: String, size := Vector2(1.8, 1.1)) -> Node3D:
	var root := ArtProps._node(parent, pos, facing_deg, "Whiteboard")
	ArtProps._piece(root, Vector3(size.x + 0.05, size.y + 0.05, 0.03), Vector3.ZERO, ArtPalette.flat(Color(0.7, 0.71, 0.72), 0.3, 0.6))
	ArtProps._piece(root, Vector3(size.x, size.y, 0.005), Vector3(0, 0, -0.016), ArtPalette.flat(Color(0.95, 0.96, 0.95), 0.15))
	ArtProps._piece(root, Vector3(size.x * 0.6, 0.03, 0.06), Vector3(0, -size.y / 2 - 0.02, -0.04), ArtPalette.flat(Color(0.7, 0.71, 0.72), 0.3, 0.6))  # marker tray
	var l := Label3D.new()
	l.text = text
	l.font = NotebookArt.hand_font()
	l.font_size = 64
	l.pixel_size = 0.0016
	l.width = size.x / l.pixel_size * 0.9
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.offset = Vector2(-l.width / 2, 0)  # a left-aligned box starts at the label's origin: centre it on the board
	l.modulate = Color(0.1, 0.2, 0.55)
	l.outline_size = 0
	l.position = Vector3(0, 0, -0.02)
	l.rotation_degrees.y = 180
	l.double_sided = false
	root.add_child(l)
	return root


## A pizza box, shut (stacked `count` high) or open with two slices left.
static func pizza_box(parent: Node, pos: Vector3, facing_deg := 0.0, open := false, count := 1) -> Node3D:
	var root := ArtProps._node(parent, pos, facing_deg, "PizzaBox")
	var card := ArtPalette.flat(Color(0.78, 0.68, 0.5), 0.95)
	if not open:
		for i in count:
			var b := ArtProps._piece(root, Vector3(0.4, 0.045, 0.4), Vector3(0, 0.023 + i * 0.046, 0), card)
			b.rotation_degrees.y = (i * 37) % 11 - 5.0
		return root
	ArtProps._piece(root, Vector3(0.4, 0.045, 0.4), Vector3(0, 0.023, 0), card)
	var lid := ArtProps._piece(root, Vector3(0.4, 0.4, 0.006), Vector3(0, 0.22, 0.2), card)
	lid.rotation_degrees.x = -12.0
	var slice := ArtPalette.flat(Color(0.85, 0.55, 0.2), 0.8)
	ArtProps._piece(root, Vector3(0.12, 0.012, 0.16), Vector3(-0.08, 0.052, -0.05), slice)
	ArtProps._piece(root, Vector3(0.12, 0.012, 0.16), Vector3(0.07, 0.052, 0.06), slice)
	return root


## The company banner: a vinyl strip with grommets, "BYTE-RIGHT IT SERVICES".
static func banner(parent: Node, pos: Vector3, facing_deg: float, text := "BYTE-RIGHT IT SERVICES", width := 3.2) -> Node3D:
	var root := ArtProps._node(parent, pos, facing_deg, "Banner")
	ArtProps._piece(root, Vector3(width, 0.6, 0.004), Vector3.ZERO, ArtPalette.flat(ArtPalette.BYTERIGHT_BLUE, 0.7))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			ArtProps._piece(root, Vector3(0.025, 0.025, 0.008), Vector3(sx * (width / 2 - 0.05), sy * 0.25, -0.002), ArtPalette.flat(Color(0.75, 0.75, 0.72), 0.3, 0.8))
	var l := _stencil(root, text, 110, Vector3(0, 0.02, -0.004))
	l.pixel_size = 0.0022
	l.modulate = Color(1, 1, 1)
	var tag := _stencil(root, "Networks • Databases • Y2K Ready", 40, Vector3(0, -0.2, -0.004))
	tag.pixel_size = 0.0018
	tag.modulate = Color(0.95, 0.8, 0.3)
	return root


## "Easy SQL", the beginner's paperback the crew learns from (one in the garage,
## one on the van's dash with the price sticker still on). A cheerful 90s cover:
## teal with a sunburst-orange band and a cartoon database cylinder. Lies flat
## unless `flat` is false (then it stands on its foot edge, spine out of a shelf).
static func easy_sql_book(parent: Node, pos: Vector3, facing_deg := 0.0, flat := true) -> Node3D:
	var root := ArtProps._node(parent, pos, facing_deg, "EasySQL")
	var w := 0.19
	var h := 0.235
	var t := 0.025
	var holder := Node3D.new()
	root.add_child(holder)
	if not flat:
		holder.rotation_degrees.x = -90
		holder.position.y = h / 2
	ArtProps._piece(holder, Vector3(w, t, h), Vector3(0, t / 2, 0), ArtPalette.flat(Color(0.95, 0.94, 0.88), 0.9), true)  # page block
	ArtProps._piece(holder, Vector3(w + 0.003, 0.002, h + 0.003), Vector3(0, t, 0), ArtPalette.flat(Color(0.05, 0.55, 0.6), 0.35))  # front cover
	ArtProps._piece(holder, Vector3(w + 0.003, 0.002, h + 0.003), Vector3(0, 0.001, 0), ArtPalette.flat(Color(0.05, 0.55, 0.6), 0.35))  # back
	ArtProps._piece(holder, Vector3(0.003, t, h + 0.003), Vector3(-w / 2 - 0.001, t / 2, 0), ArtPalette.flat(Color(0.05, 0.55, 0.6), 0.35))  # spine
	var face := Node3D.new()
	face.name = "Cover"
	face.rotation_degrees.x = 90
	face.position.y = t + 0.0015
	holder.add_child(face)
	ArtProps._piece(face, Vector3(w, 0.05, 0.0005), Vector3(0, 0.035, 0), ArtPalette.flat(Color(0.98, 0.55, 0.12), 0.4))  # the orange band
	ArtProps._piece(face, Vector3(0.05, 0.035, 0.0006), Vector3(0.05, -0.06, 0), ArtPalette.flat(Color(0.98, 0.85, 0.2), 0.4))  # the cartoon cylinder
	var bold := ThemeDB.fallback_font
	ArtProps._print(face, "Easy SQL", Vector3(0, 0.08, -0.001), w * 0.95, bold, 130, Color(1, 1, 1)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ArtProps._print(face, "Learn databases in a weekend!", Vector3(0, 0.035, -0.001), w * 0.85, bold, 64, Color(0.1, 0.12, 0.2)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ArtProps._print(face, "2nd Edition • 1996\nIncludes 3.5\" disk", Vector3(-0.035, -0.065, -0.001), w * 0.45, bold, 44, Color(0.9, 0.97, 0.97))
	# The bookshop's price sticker, never peeled off.
	ArtProps._piece(face, Vector3(0.035, 0.02, 0.0007), Vector3(0.065, 0.098, 0), ArtPalette.flat(Color(1, 1, 1), 0.6))
	ArtProps._print(face, "$24.95", Vector3(0.065, 0.098, -0.0012), 0.033, bold, 52, Color(0.8, 0.1, 0.1)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.set_meta("doc_size", Vector3(w, t, h))
	return root


# --- Helpers -------------------------------------------------------------------

## A bar of square section from a to b.
static func _bar(parent: Node3D, a: Vector3, b: Vector3, thick: float, mat: Material) -> MeshInstance3D:
	var mi := ArtProps._piece(parent, Vector3(thick, thick, a.distance_to(b)), (a + b) / 2, mat)
	if not a.is_equal_approx(b):
		var dir := (b - a).normalized()
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		mi.basis = Basis.looking_at(dir, up)
	return mi


static func _stencil(parent: Node3D, text: String, size: int, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0015
	l.modulate = STENCIL
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees.y = 180
	l.double_sided = false
	parent.add_child(l)
	return l
