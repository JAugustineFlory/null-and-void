class_name ArtDress
extends RefCounted
## Shared helpers for furnishing a level (see docs/art/style-guide.md). Dressing
## never moves or resizes the Greybox collision the puzzles and routes depend on:
## it swaps materials on existing pieces, adds props, and hangs visuals off nodes
## the level already has. Everything is in the level's own (wing-local) space.


## Re-skin Greybox pieces under `geo`. `rules` is a list of
## {"names": [prefixes], "zone": AABB (optional, level-local), "mat": Material}.
## The first rule that matches a piece wins; pieces that match nothing keep
## their greybox color. Returns how many pieces were re-skinned.
static func reskin(geo: Node3D, rules: Array) -> int:
	var count := 0
	for child in geo.get_children():
		var body := child as StaticBody3D
		if not body:
			continue
		for rule in rules:
			if not _name_matches(body.name, rule.names):
				continue
			if rule.has("zone") and not (rule.zone as AABB).has_point(body.position):
				continue
			for mi in body.get_children():
				if mi is MeshInstance3D:
					(mi as MeshInstance3D).material_override = rule.mat
			count += 1
			break
	return count


static func _name_matches(node_name: String, prefixes: Array) -> bool:
	for p in prefixes:
		if node_name.begins_with(p):
			return true
	return false


## The node visual-only dressing hangs from (no collision, so it never changes
## navigation or movement).
static func dressing_root(level: Node3D) -> Node3D:
	var n := level.get_node_or_null("Dressing") as Node3D
	if n:
		return n
	n = Node3D.new()
	n.name = "Dressing"
	level.add_child(n)
	return n


## A visual-only box.
static func trim(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = center
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Take the collision out of a prop, so it's only seen: for floors where what
## blocks a line of sight or a path is part of the puzzle (Level 2's Watcher).
static func visual_only(prop: Node) -> Node:
	for c in prop.find_children("*", "CollisionShape3D", true, false):
		c.free()
	if prop is CollisionObject3D:
		(prop as CollisionObject3D).collision_layer = 0
		(prop as CollisionObject3D).collision_mask = 0
	prop.remove_meta("art_prop")
	return prop


## Hide a Greybox piece's block mesh (its collision stays), to draw something
## else in its place.
static func hide_block(body: Node) -> void:
	for c in body.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false


## Show a solid Greybox box as a table: its block mesh is hidden and a top and
## four legs drawn in its place. Its collision stays the full block, so it still
## stops a player walking under it and can still be climbed onto.
static func table_look(body: StaticBody3D, top: Material, legs: Material, top_thickness := 0.04) -> void:
	var size := Vector3.ZERO
	for c in body.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			size = ((c as MeshInstance3D).mesh as BoxMesh).size
			(c as MeshInstance3D).visible = false
	if size == Vector3.ZERO:
		return
	var look := Node3D.new()
	look.name = "TableLook"
	body.add_child(look)
	var top_mi := trim(look, Vector3(0, size.y / 2.0 - top_thickness / 2.0, 0), Vector3(size.x, top_thickness, size.z), top)
	top_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var leg_h := size.y - top_thickness
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			trim(look, Vector3(sx * (size.x / 2.0 - 0.06), -size.y / 2.0 + leg_h / 2.0, sz * (size.z / 2.0 - 0.06)), Vector3(0.045, leg_h, 0.045), legs)


## Skirting board round the inside of a room (Greybox.room geometry), skipping
## openings. `gaps` uses the same format as Greybox.room.
## A taller `height` with `mat` makes a wainscot, such as a restroom's tiles.
static func skirting(parent: Node3D, center: Vector3, size: Vector3, gaps: Array = [], height: float = 0.1, mat: Material = null) -> void:
	if mat == null:
		mat = ArtPalette.flat(ArtPalette.OFFICE_TRIM, 0.6)
	var t := 0.1  # half the wall thickness: sits on the wall's inner face
	for wall in ["n", "s", "e", "w"]:
		var along_x: bool = wall == "n" or wall == "s"
		var length: float = size.x if along_x else size.z
		var cuts := gaps.filter(func(g): return g.wall == wall and g.get("bottom", 0.0) < height)
		cuts.sort_custom(func(a, b): return a.at < b.at)
		var cursor := -length / 2.0
		var segs := []
		for g in cuts:
			segs.append([cursor, g.at - g.width / 2.0])
			cursor = g.at + g.width / 2.0
		segs.append([cursor, length / 2.0])
		for s in segs:
			var seg_len: float = s[1] - s[0]
			if seg_len < 0.05:
				continue
			var mid: float = (s[0] + s[1]) / 2.0
			var pos := center + Vector3(0, height / 2.0, 0)
			var dims := Vector3(seg_len, height, 0.02) if along_x else Vector3(0.02, height, seg_len)
			match wall:
				"n": pos += Vector3(mid, 0, -size.z / 2.0 + t + 0.01)
				"s": pos += Vector3(mid, 0, size.z / 2.0 - t - 0.01)
				"e": pos += Vector3(size.x / 2.0 - t - 0.01, 0, mid)
				"w": pos += Vector3(-size.x / 2.0 + t + 0.01, 0, mid)
			trim(parent, pos, dims, mat)


## Make every ceiling light's glowing panel follow its light: same color, and
## dark when the light is off (the `lights` table) or turned down to nothing.
static func link_light_panels(level: LevelBase) -> int:
	var linked := 0
	for id in level.lights:
		for l in level.lights[id]:
			ceiling_shadow(l)
			var panel := _panel_for(level.geo, l)
			if panel:
				LightPanelLink.attach(l, panel)
				linked += 1
	return linked


## Ceiling lights near the camera cast soft shadows, so furniture sits on the floor
## instead of floating. Faced straight down, one paraboloid covers the room and the
## other only the ceiling; past SHADOW_NEAR metres the shadow fades out, so only the
## few lights round each player ever draw one.
const SHADOW_NEAR := 9.0


static func ceiling_shadow(light: Light3D) -> void:
	var omni := light as OmniLight3D
	if not omni:
		return
	omni.rotation_degrees.x = -90.0
	omni.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	omni.shadow_enabled = true
	omni.shadow_bias = 0.08
	omni.shadow_normal_bias = 1.5
	omni.shadow_blur = 1.5
	omni.shadow_opacity = 0.85
	omni.distance_fade_enabled = true
	omni.distance_fade_begin = 40.0
	omni.distance_fade_length = 10.0
	omni.distance_fade_shadow = SHADOW_NEAR


## Greybox.ceiling_light puts the panel 0.37 m above its light.
static func _panel_for(geo: Node3D, light: Light3D) -> MeshInstance3D:
	var want := light.position + Vector3(0, 0.37, 0)
	for c in geo.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).position.distance_to(want) < 0.02:
			return c
	return null


## Augustine's rule: a dark patch always has a cause you can see. Wherever a
## room or corridor is out of reach of its own lights, fit a dead troffer on the
## ceiling there, on a regular grid `spacing` apart like the working ones, so the
## ceiling shows why it's dark. `avoid`: points to keep clear (hidden ceiling
## routes). Returns how many.
static func explain_dark(level: LevelBase, zones: Array, spacing := 3.6, avoid: Array = []) -> int:
	var dress := dressing_root(level)
	var lights := _lights(level)
	var causes := _causes(level)
	var placed := 0
	for zone in zones:
		var box: AABB = zone
		var nx := maxi(1, roundi(box.size.x / spacing))
		var nz := maxi(1, roundi(box.size.z / spacing))
		var slots: Array[Vector3] = []
		for ix in nx:
			for iz in nz:
				slots.append(Vector3(box.position.x + box.size.x * (ix + 0.5) / nx, 0, box.position.z + box.size.z * (iz + 0.5) / nz))
		var given_up := []  # dark spots nothing can be fitted over (no ceiling, a route)
		for guard in 40:
			var dark := _dark_points(box, lights, causes)
			dark = dark.filter(func(q: Vector2): return not _near(given_up, q.x, q.y, 0.1))
			if dark.is_empty():
				break
			var p: Vector2 = dark[0]
			var at := Vector3(p.x, 0, p.y)
			var best := INF
			for slot in slots:
				var d := Vector2(slot.x - p.x, slot.z - p.y).length()
				if d < best and d < CAUSE_SEEN - 0.3 and _clear_of(slot, lights, causes + avoid):
					best = d
					at = slot
			var y := ceiling_at(level.geo, at.x, at.z)
			if is_nan(y) or _near(avoid, at.x, at.z, 1.3):
				given_up.append(Vector3(p.x, 0, p.y))
				continue
			var along := 90.0 if box.size.z > box.size.x * 1.5 else 0.0  # long side down a narrow passage
			ArtProps.dead_troffer(dress, Vector3(at.x, y, at.z), along, placed % 3 == 1)
			causes.append(at)
			placed += 1
	return placed


## How far from a dead fitting a dark patch still reads as explained.
const CAUSE_SEEN := 3.5
## How much of a light's range still reads as lit: past this the floor's in the dark.
const LIT_REACH := 0.85


## Points in `zones` (1 m apart) that are neither near one of the zone's own
## lights nor in sight of a dead fitting: dark for no reason. Tests want none.
static func unexplained_dark(level: LevelBase, zones: Array) -> Array:
	var lights := _lights(level)
	var causes := _causes(level)
	var bad := []
	for zone in zones:
		bad.append_array(_dark_points(zone, lights, causes))
	return bad


## [position, range] of every light in the level's geo and dressing, in its space.
static func _lights(level: LevelBase) -> Array:
	var out := []
	for root in [level.geo, dressing_root(level)]:
		for l in (root as Node).find_children("*", "Light3D", true, false):
			var r: float = l.omni_range if l is OmniLight3D else (l.spot_range if l is SpotLight3D else 0.0)
			out.append([_in(root, l), r])
	return out


static func _causes(level: LevelBase) -> Array:
	var out := []
	var dress := dressing_root(level)
	for c in dress.find_children("*", "Node3D", true, false):
		if c.is_in_group("dark_cause"):
			out.append(_in(dress, c))
	return out


static func _dark_points(box: AABB, lights: Array, causes: Array) -> Array:
	var bad := []
	var x := box.position.x + 0.5
	while x < box.end.x:
		var z := box.position.z + 0.5
		while z < box.end.z:
			if not _lit(box, x, z, lights) and not _near(causes, x, z, CAUSE_SEEN):
				bad.append(Vector2(x, z))
			z += 1.0
		x += 1.0
	return bad


## Near one of the zone's own lights (one through the wall doesn't light it).
static func _lit(box: AABB, x: float, z: float, lights: Array) -> bool:
	for l in lights:
		var q: Vector3 = l[0]
		var own := q.x > box.position.x - 0.5 and q.x < box.end.x + 0.5 and q.z > box.position.z - 0.5 and q.z < box.end.z + 0.5
		if own and Vector2(q.x - x, q.z - z).length() < l[1] * LIT_REACH:
			return true
	return false


static func _near(points: Array, x: float, z: float, d: float) -> bool:
	for p in points:
		if Vector2(p.x - x, p.z - z).length() < d:
			return true
	return false


## A free spot on the ceiling: not on a working fitting, a dead one, or a route.
static func _clear_of(p: Vector3, lights: Array, taken: Array) -> bool:
	for l in lights:
		if Vector2(l[0].x - p.x, l[0].z - p.z).length() < 1.4:
			return false
	return not _near(taken, p.x, p.z, 1.3)


## Where `n` sits in `root`'s space, without needing the tree (levels dress
## before they're added to it). Geo and Dressing share the level's space.
static func _in(root: Node, n: Node3D) -> Vector3:
	var xf := Transform3D.IDENTITY
	var at: Node = n
	while at and at != root:
		if at is Node3D:
			xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf.origin


## The underside of the Greybox ceiling over (x, z) in the wing's space, or NAN.
static func ceiling_at(geo: Node3D, x: float, z: float) -> float:
	for b in geo.get_children():
		if not (b is StaticBody3D and String(b.name).begins_with("Ceiling")):
			continue
		for cs in b.get_children():
			if cs is CollisionShape3D and cs.shape is BoxShape3D:
				var size: Vector3 = cs.shape.size
				var c: Vector3 = (b as Node3D).transform * cs.position
				if absf(x - c.x) <= size.x / 2.0 and absf(z - c.z) <= size.z / 2.0:
					return c.y - size.y / 2.0
	return NAN
