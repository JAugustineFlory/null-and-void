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


## Skirting board round the inside of a room (Greybox.room geometry), skipping
## openings. `gaps` uses the same format as Greybox.room.
static func skirting(parent: Node3D, center: Vector3, size: Vector3, gaps: Array = [], height: float = 0.1) -> void:
	var mat := ArtPalette.flat(ArtPalette.OFFICE_TRIM, 0.6)
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
			var panel := _panel_for(level.geo, l)
			if panel:
				LightPanelLink.attach(l, panel)
				linked += 1
	return linked


## Greybox.ceiling_light puts the panel 0.37 m above its light.
static func _panel_for(geo: Node3D, light: Light3D) -> MeshInstance3D:
	var want := light.position + Vector3(0, 0.37, 0)
	for c in geo.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).position.distance_to(want) < 0.02:
			return c
	return null
