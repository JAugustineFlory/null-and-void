class_name DressVan
extends RefCounted
## The crew's Byte-Right IT van, dressed over Level 0's six-seat greybox van:
## white paint, a windscreen you can see out of, lights, bumpers, round wheels,
## two bucket seats and a rear bench, a steering wheel and a roof rack. Visual
## only: the greybox keeps every collider, seat-belt buckle and door it had.

const PAINT := Color(0.9, 0.9, 0.87)
const SEAT_FABRIC := Color(0.17, 0.18, 0.21)


## `center` is the van's middle at ground level, as Level 0's _build_van gets it.
static func apply(level: LevelBase, center: Vector3) -> void:
	var geo := level.geo
	var root := Node3D.new()
	root.name = "Van"
	root.position = center
	ArtDress.dressing_root(level).add_child(root)
	var zone := AABB(center + Vector3(-1.45, -0.2, -2.8), Vector3(2.9, 3.2, 5.6))
	var paint := ArtPalette.flat(PAINT, 0.35, 0.15)
	var rubber := ArtPalette.flat(Color(0.06, 0.06, 0.065), 0.9)
	var trim := ArtPalette.flat(Color(0.12, 0.12, 0.13), 0.6, 0.2)
	var chrome := ArtPalette.flat(Color(0.72, 0.73, 0.75), 0.25, 0.9)
	ArtDress.reskin(geo, [
		{"names": ["Floor"], "zone": zone, "mat": ArtPalette.surface("dark_plastic")},  # ribbed rubber mat
		{"names": ["Ceiling", "Wall_", "Bonnet"], "zone": zone, "mat": paint},
		{"names": ["Chassis"], "zone": zone, "mat": trim},
		{"names": ["Rack"], "zone": zone, "mat": ArtPalette.surface("metal")},
	])
	# The doors hang off pivots outside geo.
	for door in level.find_children("*Door*", "StaticBody3D", true, false):
		if door.name.begins_with("VanDoor") or door.name.begins_with("SideDoor"):
			for mi in door.get_children():
				if mi is MeshInstance3D:
					mi.material_override = paint
	# Round wheels with hubcaps in place of the greybox blocks.
	for wheel in wheels(geo, center):
			for mi in wheel.get_children():
				if mi is MeshInstance3D:
					mi.visible = false
			var side := signf(wheel.position.x - center.x)
			var at := wheel.position - center + Vector3(side * 0.08, 0.09, 0)  # proud of the chassis
			var tyre := _cylinder(root, 0.34, 0.3, at, rubber)
			tyre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_cylinder(root, 0.17, 0.02, at + Vector3(side * 0.16, 0, 0), chrome)
	# Hide the greybox seat blocks and dashboard; real ones go in below.
	var floor_y := 0.5
	for mi in geo.get_children():
		if mi is MeshInstance3D and zone.has_point(mi.position) and mi.position.y < center.y + floor_y + 1.0:
			mi.visible = false

	# Front: bumper, grille, headlights, indicators.
	var front := -2.2 - 0.9  # front face of the bonnet
	ArtDress.trim(root, Vector3(0, 0.42, front - 0.06), Vector3(2.66, 0.22, 0.14), trim)
	ArtDress.trim(root, Vector3(0, 0.95, front - 0.01), Vector3(1.2, 0.36, 0.02), trim)
	for i in 4:
		ArtDress.trim(root, Vector3(0, 0.84 + i * 0.075, front - 0.025), Vector3(1.14, 0.02, 0.01), chrome)
	for sx in [-1, 1]:
		ArtDress.trim(root, Vector3(sx * 0.95, 0.98, front - 0.015), Vector3(0.42, 0.24, 0.02), ArtPalette.glow(Color(1.0, 0.95, 0.8), 1.6))
		ArtDress.trim(root, Vector3(sx * 1.22, 0.98, front - 0.015), Vector3(0.1, 0.2, 0.02), ArtPalette.glow(Color(1.0, 0.6, 0.15), 0.8))
		# Wing mirrors, by the front doors.
		ArtDress.trim(root, Vector3(sx * 1.42, 1.85, -1.95), Vector3(0.16, 0.24, 0.08), trim)
		ArtDress.trim(root, Vector3(sx * 1.37, 1.85, -1.95), Vector3(0.1, 0.03, 0.03), trim)
	# Back: bumper, tail lights, rear door seam and handle.
	var back := 2.2 + 0.1
	ArtDress.trim(root, Vector3(0, 0.42, back + 0.05), Vector3(2.66, 0.22, 0.14), trim)
	for sx in [-1, 1]:
		ArtDress.trim(root, Vector3(sx * 1.18, 1.25, back + 0.01), Vector3(0.16, 0.5, 0.02), ArtPalette.glow(Color(0.8, 0.08, 0.06), 0.9))
	ArtDress.trim(root, Vector3(0, 1.55, back + 0.01), Vector3(0.015, 2.0, 0.02), trim)
	ArtDress.trim(root, Vector3(0.12, 1.45, back + 0.02), Vector3(0.12, 0.04, 0.03), chrome)
	# A brand stripe along each side, below the windows; the sliding door carries its own piece.
	var navy := ArtPalette.flat(ArtPalette.BYTERIGHT_BLUE, 0.5)
	# Solid wall only: behind the driver door on the left; between the passenger
	# door and the sliding door, and behind the sliding door, on the right.
	ArtDress.trim(root, Vector3(-1.315, 1.3, 0.575), Vector3(0.01, 0.12, 3.25), navy)
	ArtDress.trim(root, Vector3(1.315, 1.3, -0.8), Vector3(0.01, 0.12, 0.5), navy)
	ArtDress.trim(root, Vector3(1.315, 1.3, 1.475), Vector3(0.01, 0.12, 1.45), navy)
	var side_door := level.get("side_door") as Node3D
	if side_door:
		ArtDress.trim(side_door, Vector3(0.06, 0.8, 0), Vector3(0.01, 0.12, 1.3), navy)
	# Windscreen: faintly tinted glass, so you can still see the building through it.
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.65, 0.7, 0.14)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic = 0.4
	ArtDress.trim(root, Vector3(0, floor_y + 0.85 + 0.55, -2.2), Vector3(2.3, 1.1, 0.02), glass)
	# Roof rack.
	for x in [-0.9, 0.9]:
		ArtDress.trim(root, Vector3(x, floor_y + 2.1 + 0.25, 0.2), Vector3(0.05, 0.05, 3.6), trim)
	for z in [-1.2, 0.0, 1.2]:
		ArtDress.trim(root, Vector3(0, floor_y + 2.1 + 0.29, z), Vector3(1.9, 0.04, 0.05), trim)
	for x in [-0.9, 0.9]:
		for z in [-1.5, 1.9]:
			ArtDress.trim(root, Vector3(x, floor_y + 2.1 + 0.15, z), Vector3(0.05, 0.2, 0.05), trim)

	# Cab: dashboard, steering wheel, a green clock.
	var dash := ArtPalette.surface("dark_plastic")
	ArtDress.trim(root, Vector3(0, floor_y + 0.75, -2.05), Vector3(2.4, 0.22, 0.32), dash)
	ArtDress.trim(root, Vector3(0, floor_y + 0.45, -2.1), Vector3(2.4, 0.4, 0.2), dash)
	ArtDress.trim(root, Vector3(0.2, floor_y + 0.87, -1.95), Vector3(0.12, 0.04, 0.01), ArtPalette.glow(ArtPalette.LIGHT_SCREEN, 1.4))
	# Somebody's "Easy SQL", price sticker still on, tossed on the passenger side.
	ArtKit.easy_sql_book(root, Vector3(0.62, floor_y + 0.86, -2.02), 168.0)
	var wheel_mesh := TorusMesh.new()
	wheel_mesh.inner_radius = 0.16
	wheel_mesh.outer_radius = 0.19
	var steer := MeshInstance3D.new()
	steer.name = "SteeringWheel"
	steer.mesh = wheel_mesh
	steer.material_override = trim
	steer.position = Vector3(-0.55, floor_y + 1.02, -1.8)
	steer.rotation_degrees.x = 65
	root.add_child(steer)
	ArtDress.trim(root, Vector3(-0.55, floor_y + 0.92, -1.9), Vector3(0.05, 0.05, 0.25), trim)  # column
	# Seats: two buckets in front, a bench for four behind.
	var fabric := ArtPalette.surface("partition", Color(0.55, 0.55, 0.65))
	for sx in [-0.55, 0.55]:
		_seat(root, Vector3(sx, floor_y, -1.3), 0.55, fabric, true)
	_seat(root, Vector3(0, floor_y, 0.7), 2.5, fabric, false)


## The greybox wheel blocks (found by size: Godot renames repeated "Wheel" nodes).
static func wheels(geo: Node3D, center: Vector3) -> Array[StaticBody3D]:
	var out: Array[StaticBody3D] = []
	var zone := AABB(center + Vector3(-1.45, -0.2, -2.8), Vector3(2.9, 1.0, 5.6))
	for b in geo.get_children():
		if b is StaticBody3D and zone.has_point(b.position) and b.get_child_count() > 0:
			var mi := b.get_child(0) as MeshInstance3D
			if mi and mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.is_equal_approx(Vector3(0.3, 0.5, 0.7)):
				out.append(b)
	return out


## A seat: cushion and backrest (and a headrest for a bucket seat), facing -Z.
static func _seat(root: Node3D, at: Vector3, width: float, mat: Material, bucket: bool) -> void:
	var seat := Node3D.new()
	seat.name = "Seat_%d" % root.get_child_count()
	seat.position = at
	root.add_child(seat)
	ArtDress.trim(seat, Vector3(0, 0.2, 0.0), Vector3(width, 0.4, 0.45), ArtPalette.flat(Color(0.1, 0.1, 0.11), 0.8))  # base
	ArtDress.trim(seat, Vector3(0, 0.45, 0.02), Vector3(width, 0.12, 0.5), mat)  # cushion
	var back := ArtDress.trim(seat, Vector3(0, 0.82, 0.3), Vector3(width, 0.66, 0.12), mat)
	back.rotation_degrees.x = -10
	if bucket:
		ArtDress.trim(seat, Vector3(0, 1.26, 0.36), Vector3(0.28, 0.18, 0.1), mat)


static func _cylinder(parent: Node3D, radius: float, width: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = width
	cm.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees.z = 90
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
