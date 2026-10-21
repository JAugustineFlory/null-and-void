class_name DressHomeBase
extends RefCounted
## Furnishing for the crew's garage, Byte-Right IT Services' home base in the fall
## of 1997: a two-car garage run as a startup. Painted block walls, an oil-stained
## slab, bare bulbs on cords, the workbench the crew huddles round, folding tables
## of CRTs, pizza boxes, the whiteboard and the company banner. The back corner
## stays dark under its dead bulb: the game sends you there to find the book.
## Called at the end of HomeBase.build(), before navigation bakes.

## Where the crew walks: spawn > fax > back corner > bench > van side door. Props
## stay out of these (tests check).
const KEEP_CLEAR := [
	Vector3(-0.5, 0, 3.0), Vector3(-3.6, 0, 2.3), Vector3(-4.2, 0, -3.3), Vector3(-2.5, 0, 0.3),
	Vector3(1.0, 0, 0.4), Vector3(-0.5, 0, 1.2), Vector3(-3.0, 0, -2.6),
]
## The whiteboard's marker writing: in-world flavor, no clues.
const WHITEBOARD := "ON CALL: everyone\nINVOICES: overdue (again)\nY2K: 808 days\n\nBUY: floppies, coffee, a real chair"


static func apply(level: LevelBase) -> void:
	var geo := level.geo
	var dress := ArtDress.dressing_root(level)
	var bench_mat := ArtPalette.surface("laminate", Color(0.8, 0.7, 0.6))
	ArtDress.reskin(geo, [
		{"names": ["Floor"], "mat": ArtPalette.surface("concrete", Color(0.95, 0.95, 0.92))},
		{"names": ["Wall_"], "mat": ArtPalette.surface("concrete", Color(1.45, 1.42, 1.32))},  # painted block
		{"names": ["Ceiling"], "mat": ArtPalette.surface("concrete", Color(1.2, 1.18, 1.1))},
		{"names": ["Shelf"], "mat": ArtPalette.surface("metal", Color(0.7, 0.72, 0.75))},
		{"names": ["Desk"], "mat": ArtPalette.surface("laminate", Color(0.75, 0.68, 0.6))},
		{"names": ["Radio"], "mat": ArtPalette.surface("dark_plastic")},
	])
	var legs := ArtPalette.flat(Color(0.22, 0.22, 0.23), 0.5, 0.6)
	for b in geo.get_children():
		if b is StaticBody3D and b.name.begins_with("Workbench"):
			ArtDress.table_look(b, bench_mat, legs, 0.06)
	_bulbs(level)
	_banner(level, dress)
	_book(level)

	# Oil on the slab where the van stands, and an old stain by the door.
	var oil := ArtPalette.flat(Color(0.05, 0.05, 0.05, 0.55), 0.25)
	oil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ArtDress.trim(dress, HomeBase.VAN + Vector3(0.1, 0.004, -1.2), Vector3(1.1, 0.002, 0.8), oil)
	ArtDress.trim(dress, Vector3(1.2, 0.004, -3.2), Vector3(0.5, 0.002, 0.35), oil)

	# The tech table on the south wall behind the van: two CRTs, a keyboard, dinner.
	ArtKit.folding_table(geo, Vector3(3.0, 0, 4.0), 180)
	ArtProps.crt_monitor(dress, Vector3(2.5, 0.76, 4.1), 0, "green")
	ArtProps.crt_monitor(dress, Vector3(3.5, 0.76, 4.1), 0, "blue")
	ArtKit.pizza_box(dress, Vector3(2.2, 0.76, 3.85), 15, true)
	_seat(ArtKit.folding_chair(geo, Vector3(2.6, 0, 3.35), 200))
	_seat(ArtKit.folding_chair(geo, Vector3(3.6, 0, 3.4), 170))
	ArtProps.boxes(geo, Vector3(4.9, 0, 3.9), 0, 2)
	_desk_lamp(dress, Vector3(3.75, 0.76, 4.2))

	# Round the workbench: the whiteboard on the west wall, empty boxes stacked on the end.
	ArtKit.whiteboard(dress, Vector3(-5.37, 1.55, -1.0), -90, WHITEBOARD, Vector2(1.6, 1.0))
	ArtKit.pizza_box(dress, HomeBase.BENCH + Vector3(-0.9, 0.95, -0.25), 0, false, 3)
	ArtProps.keyboard(dress, HomeBase.BENCH + Vector3(0.75, 0.95, -0.25), 180)

	# The office corner: a CRT and a stack of manuals by the fax.
	ArtProps.crt_monitor(dress, Vector3(-4.95, 0.8, 1.95), -90, "green")
	_seat(ArtKit.folding_chair(geo, Vector3(-4.1, 0, 3.95), 120))  # pushed back from the desk
	ArtProps.binder(dress, Vector3(-4.75, 0.8, 3.05), 80, "NETWARE 4.11", false)
	_fax(level)

	# Moving boxes and spare kit along the north wall, west of the roll-up door.
	ArtProps.boxes(geo, Vector3(-2.6, 0, -3.9), 8, 3)
	ArtProps.cable_coil(dress, Vector3(-1.9, 1.6, -4.36), 0)
	ArtProps.server_rack(geo, Vector3(5.05, 0, -3.8), -90, true)
	# The van the crew drives to Halcyon, seen from its sliding-door side.
	DressVan.apply(level, HomeBase.VAN, -1.0)


## A real fax machine on the fax Interactable, in place of its box, facing the
## room (+X). It's the Interactable's child, so it goes wherever the fax does.
static func _fax(level: LevelBase) -> void:
	var fax := level.get("fax") as Node3D
	if fax == null:
		return
	var height := 0.26
	for c in fax.get_children():
		if c is MeshInstance3D:
			c.visible = false
		elif c is CollisionShape3D and c.shape is BoxShape3D:
			height = (c.shape as BoxShape3D).size.y
	ArtProps.fax_machine(fax, Vector3(0, -height / 2.0, 0), -90)


## Bare bulbs on cords in place of the greybox light panels. The bulb is the
## light's child, so it goes out with it.
static func _bulbs(level: LevelBase) -> void:
	var cord := ArtPalette.flat(Color(0.08, 0.08, 0.08), 0.7)
	for id in level.lights:
		for l in level.lights[id]:
			var panel := ArtDress._panel_for(level.geo, l)
			if panel:
				panel.visible = false
			ArtDress.ceiling_shadow(l)  # turns the light; hang the bulb straight in spite of it
			var hang := Node3D.new()
			hang.name = "Hang"
			hang.basis = l.basis.inverse()
			l.add_child(hang)
			var bulb := MeshInstance3D.new()
			bulb.name = "Bulb"
			var s := SphereMesh.new()
			s.radius = 0.06
			s.height = 0.13
			bulb.mesh = s
			bulb.material_override = ArtPalette.glow(l.light_color, 4.0)
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hang.add_child(bulb)
			ArtDress.trim(hang, Vector3(0, 0.22, 0), Vector3(0.012, 0.36, 0.012), cord)
	ArtMood.polish(level.environment)


## A clip-on work lamp on the tech table: the only light back there.
static func _desk_lamp(dress: Node3D, at: Vector3) -> void:
	var lamp := ArtProps._node(dress, at, 200, "DeskLamp")
	var black := ArtPalette.flat(Color(0.1, 0.1, 0.11), 0.4, 0.5)
	ArtProps._piece(lamp, Vector3(0.14, 0.03, 0.14), Vector3(0, 0.015, 0), black)
	ArtProps._piece(lamp, Vector3(0.02, 0.4, 0.02), Vector3(0, 0.2, 0), black)
	var shade := ArtProps._piece(lamp, Vector3(0.14, 0.1, 0.14), Vector3(0, 0.42, -0.1), black)
	shade.rotation_degrees.x = 35
	ArtProps._piece(lamp, Vector3(0.1, 0.01, 0.1), Vector3(0, 0.37, -0.13), ArtPalette.glow(ArtPalette.LIGHT_WARM, 3.0))
	var l := OmniLight3D.new()
	l.name = "LampLight"
	l.light_color = ArtPalette.LIGHT_WARM
	l.light_energy = 0.9
	l.omni_range = 3.0
	l.position = Vector3(0, 0.3, -0.18)
	lamp.add_child(l)


## The real banner over the old greybox lettering on the south wall.
static func _banner(level: LevelBase, dress: Node3D) -> void:
	for c in level.geo.get_children():
		if c is Label3D and (c as Label3D).text == "BYTE-RIGHT IT SERVICES":
			c.visible = false
			ArtKit.banner(dress, c.position - Vector3(0, 0, 0.05), 0)


## The bench copy of Easy SQL wears the real cover; it shows and hides with the node.
static func _book(level: Node) -> void:
	var book: Node3D = level.get("bench_book")
	if book == null:
		return
	for c in book.get_children():
		if c is GeometryInstance3D:
			c.visible = false
	ArtKit.easy_sql_book(book, Vector3(0, -0.04, 0), 180)


## Somewhere to sit (Seat, from Movement): E on the chair sits you facing the way it faces.
static func _seat(chair: Node3D) -> Seat:
	return Seat.create_at(chair.get_parent(), chair.transform * Vector3(0, ArtKit.CHAIR_SEAT, 0), chair.rotation.y, Vector2(0.42, 0.4))
