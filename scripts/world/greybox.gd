class_name Greybox
extends RefCounted
## Helpers that build greybox level geometry from code, so levels are plain text
## and easy to change. Every solid is a StaticBody3D so navigation can bake from it.

static var _materials := {}


static func mat(color: Color, emission: float = 0.0, roughness: float = 0.9) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color.to_html(), emission, roughness]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_materials[key] = m
	return m


## A solid box. `center` is the box center, `size` its full size.
static func box(parent: Node, center: Vector3, size: Vector3, color: Color, name: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	if name != "":
		body.name = name
	body.position = center
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat(color)
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)
	return body


## A visual-only box (no collision), e.g. a glowing light panel.
static func panel(parent: Node, center: Vector3, size: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat(color, emission)
	mesh.position = center
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


## Floor, ceiling and four walls of a room. `gaps` lists wall openings as
## {"wall": "n"|"s"|"e"|"w", "at": offset along the wall from its center, "width": w, "height": h}.
static func room(parent: Node, center: Vector3, size: Vector3, colors: Dictionary, gaps: Array = []) -> void:
	var t := 0.2
	var floor_c: Color = colors.get("floor", Color(0.25, 0.24, 0.22))
	var wall_c: Color = colors.get("wall", Color(0.55, 0.52, 0.45))
	var ceil_c: Color = colors.get("ceiling", Color(0.6, 0.6, 0.58))
	box(parent, center + Vector3(0, -t / 2, 0), Vector3(size.x, t, size.z), floor_c, "Floor")
	box(parent, center + Vector3(0, size.y + t / 2, 0), Vector3(size.x, t, size.z), ceil_c, "Ceiling")
	for wall in ["n", "s", "e", "w"]:
		var wall_gaps := gaps.filter(func(g): return g.wall == wall)
		_wall(parent, center, size, wall, wall_c, wall_gaps, t)


static func _wall(parent: Node, center: Vector3, size: Vector3, wall: String, color: Color, gaps: Array, t: float) -> void:
	var along_x := wall == "n" or wall == "s"
	var length := size.x if along_x else size.z
	var offset := Vector3.ZERO
	match wall:
		"n": offset = Vector3(0, 0, -size.z / 2)
		"s": offset = Vector3(0, 0, size.z / 2)
		"e": offset = Vector3(size.x / 2, 0, 0)
		"w": offset = Vector3(-size.x / 2, 0, 0)
	# Split the wall into solid segments around each gap.
	gaps.sort_custom(func(a, b): return a.at < b.at)
	var cursor := -length / 2
	var segments := []
	for g in gaps:
		var g_start: float = g.at - g.width / 2.0
		var g_end: float = g.at + g.width / 2.0
		if g_start > cursor:
			segments.append([cursor, g_start, 0.0, size.y])
		# Lintel above the gap.
		if g.height < size.y:
			segments.append([g_start, g_end, g.height, size.y])
		# Sill below the gap (for windows and vents).
		var bottom: float = g.get("bottom", 0.0)
		if bottom > 0.0:
			segments.append([g_start, g_end, 0.0, bottom])
		cursor = g_end
	if cursor < length / 2:
		segments.append([cursor, length / 2, 0.0, size.y])
	for s in segments:
		var seg_len: float = s[1] - s[0]
		var seg_h: float = s[3] - s[2]
		if seg_len <= 0.01 or seg_h <= 0.01:
			continue
		var mid: float = (s[0] + s[1]) / 2.0
		var pos := center + offset + Vector3(0, s[2] + seg_h / 2.0, 0)
		var dims := Vector3.ZERO
		if along_x:
			pos.x += mid
			dims = Vector3(seg_len, seg_h, t)
		else:
			pos.z += mid
			dims = Vector3(t, seg_h, seg_len)
		box(parent, pos, dims, color, "Wall_" + wall)


## A ceiling fluorescent fixture with a real light.
static func ceiling_light(parent: Node, pos: Vector3, light_range: float = 8.0, energy: float = 1.4, color: Color = Color(0.92, 0.95, 1.0)) -> OmniLight3D:
	panel(parent, pos + Vector3(0, -0.03, 0), Vector3(1.2, 0.05, 0.3), color, 2.5)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, -0.4, 0)
	light.omni_range = light_range
	light.light_energy = energy
	light.light_color = color
	light.shadow_enabled = false
	parent.add_child(light)
	return light


## World-space text, e.g. a sign or a sticky note.
static func label(parent: Node, pos: Vector3, text: String, size: int = 48, color: Color = Color(0.1, 0.1, 0.1), facing_deg: float = 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.002
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees.y = facing_deg
	l.double_sided = false
	parent.add_child(l)
	return l
