class_name DressHomeBase
extends RefCounted
## Furnishing for the crew's garage, Byte-Right IT Services' home base in the fall
## of 1997: a converted RV garage run as a startup. Painted block walls, an
## oil-stained slab, bright bulbs on cords, the workbench, folding tables of CRTs,
## pizza boxes, the whiteboard the crew sits facing and the company banner.
## Called at the end of HomeBase.build(), before navigation bakes.

## Where the crew walks: spawn > fax > back corner > bench > van side door, and the
## briefing corner. Props stay out of these (tests check).
const KEEP_CLEAR := [
	Vector3(0.5, 0, 0.5), Vector3(-6.4, 0, -4.6), Vector3(-6.0, 0, 4.8), Vector3(-0.6, 0, 2.4),
	Vector3(2.4, 0, 0.8), Vector3(-6.4, 0, 2.2), Vector3(-3.4, 0, 0.0), Vector3(0.8, 0, -2.4),
]
## The whiteboard's marker writing: in-world flavor, no clues.
const WHITEBOARD := "ON CALL: everyone\nINVOICES: overdue (again)\nY2K: 808 days\n\nBUY: floppies, coffee, a real chair"


static func apply(level: LevelBase) -> void:
	var geo := level.geo
	var dress := ArtDress.dressing_root(level)
	var bench_mat := ArtPalette.surface("laminate", Color(0.8, 0.7, 0.6))
	front(geo, level)
	ArtDress.reskin(geo, [
		{"names": ["Desk"], "mat": ArtPalette.surface("laminate", Color(0.75, 0.68, 0.6))},
		{"names": ["Radio"], "mat": ArtPalette.surface("dark_plastic")},
	])
	var legs := ArtPalette.flat(Color(0.22, 0.22, 0.23), 0.5, 0.6)
	for b in geo.get_children():
		if b is StaticBody3D and b.name.begins_with("Workbench"):
			ArtDress.table_look(b, bench_mat, legs, 0.06)
	_bulbs(level)
	_banner(level, dress)
	_briefing_corner(level, dress)
	_bag_stand(level, dress)
	_book(level)
	_shelf(level, dress)
	_shop_bag(level)

	# Oil on the slab where the van stands, and an old stain by the door.
	var oil := ArtPalette.flat(Color(0.05, 0.05, 0.05, 0.55), 0.25)
	oil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ArtDress.trim(dress, HomeBase.VAN + Vector3(0.1, 0.004, -1.2), Vector3(1.1, 0.002, 0.8), oil)
	ArtDress.trim(dress, Vector3(HomeBase.DOOR_AT - 1.2, 0.004, -4.8), Vector3(0.5, 0.002, 0.35), oil)

	# The tech table on the south wall behind the van: two CRTs, a keyboard, dinner.
	var tech := Vector3(4.6, 0, 5.3)
	ArtKit.folding_table(geo, tech, 180)
	ArtProps.crt_monitor(dress, tech + Vector3(-0.5, 0.76, 0.1), 0, "green")
	ArtProps.crt_monitor(dress, tech + Vector3(0.5, 0.76, 0.1), 0, "blue")
	ArtKit.pizza_box(dress, tech + Vector3(-0.8, 0.76, -0.15), 15, true)
	_seat(ArtKit.folding_chair(geo, tech + Vector3(-0.4, 0, -0.65), 200))
	_seat(ArtKit.folding_chair(geo, tech + Vector3(0.6, 0, -0.6), 170))
	ArtProps.boxes(geo, tech + Vector3(2.3, 0, -0.1), 0, 2)
	_desk_lamp(dress, tech + Vector3(0.75, 0.76, 0.2))

	# The whiteboard the crew sits facing, on the west wall; empty boxes on the bench's end.
	ArtKit.whiteboard(dress, HomeBase.WHITEBOARD + Vector3(0.08, 0, 0), -90, WHITEBOARD, Vector2(2.4, 1.3))
	ArtKit.pizza_box(dress, HomeBase.BENCH + Vector3(-0.9, 0.95, -0.25), 0, false, 3)
	ArtProps.keyboard(dress, HomeBase.BENCH + Vector3(0.75, 0.95, -0.25), 180)

	# The office corner: a CRT and a stack of manuals by the fax.
	ArtProps.crt_monitor(dress, HomeBase.DESK + Vector3(-0.05, 0.8, 0.15), -90, "green")
	_seat(ArtKit.folding_chair(geo, HomeBase.DESK + Vector3(1.0, 0, -1.2), 60))  # pushed back into the corner
	ArtProps.binder(dress, HomeBase.DESK + Vector3(0.15, 0.8, 0.85), 80, "NETWARE 4.11", false)
	_fax(level)

	# Moving boxes and spare kit along the north wall, west of the roll-up door.
	ArtProps.boxes(geo, Vector3(-3.0, 0, -5.4), 8, 3)
	ArtProps.cable_coil(dress, Vector3(-2.0, 1.6, -5.86), 0)
	ArtProps.server_rack(geo, Vector3(7.55, 0, 3.0), -90, true)
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


## The garage from outside, for the lobby's shot and the World's garage alike
## (HomeBase.build_front, and apply): painted block, a concrete driveway with its
## joints, a ribbed roll-up door with windows and a lift handle, trim round the
## doorway, gooseneck lamps, a fascia and gutter along the roof, a downspout, the
## bins, a hose reel and the power meter. `solid` holds the walls, driveway and
## lamps; `door_parent` holds the roll-up door and takes the dressing.
static func front(solid: Node3D, door_parent: Node3D) -> void:
	ArtDress.reskin(solid, [
		{"names": ["Floor"], "mat": ArtPalette.surface("concrete", Color(0.95, 0.95, 0.92))},
		{"names": ["Wall_"], "mat": ArtPalette.surface("concrete", Color(1.45, 1.42, 1.32))},  # painted block
		{"names": ["Ceiling"], "mat": ArtPalette.surface("concrete", Color(1.2, 1.18, 1.1))},
		{"names": ["Driveway"], "mat": ArtPalette.surface("concrete", Color(0.78, 0.78, 0.76))},
	])
	var dress := ArtDress.dressing_root(door_parent)
	var m := ArtMesh.new()
	var face := -HomeBase.SIZE.z / 2 - 0.1  # the outside of the north wall
	var trim := Color(0.92, 0.91, 0.87)
	var dark := Color(0.12, 0.13, 0.13)
	var door := HomeBase.DOOR_AT
	var half := HomeBase.DOOR_SIZE.x / 2
	var top := HomeBase.DOOR_SIZE.y
	for side in [-1.0, 1.0]:
		m.box(Vector3(door + side * (half + 0.06), top / 2, face - 0.015), Vector3(0.12, top, 0.03), trim)
	m.box(Vector3(door, top + 0.06, face - 0.015), Vector3(half * 2 + 0.24, 0.12, 0.03), trim)
	# The roof edge: soffit, fascia and gutter, the full width, and a downspout.
	var w := HomeBase.SIZE.x / 2 + 0.2
	var roof := HomeBase.SIZE.y
	m.box(Vector3(0, roof - 0.01, face - 0.2), Vector3(w * 2, 0.02, 0.4), trim)
	m.box(Vector3(0, roof + 0.1, face - 0.41), Vector3(w * 2, 0.24, 0.025), trim)
	m.box(Vector3(0, roof + 0.03, face - 0.49), Vector3(w * 2, 0.1, 0.12), Color(0.82, 0.82, 0.8), 0.0, ["top"])
	var spout := Vector3(HomeBase.SIZE.x / 2 - 0.35, 0, face - 0.06)
	m.rod(Vector3(spout.x, roof, face - 0.45), Vector3(spout.x, roof - 0.35, spout.z), 0.035, Color(0.8, 0.8, 0.78), 6)
	m.rod(Vector3(spout.x, roof - 0.35, spout.z), Vector3(spout.x, 0.25, spout.z), 0.035, Color(0.8, 0.8, 0.78), 6)
	m.rod(Vector3(spout.x, 0.25, spout.z), Vector3(spout.x, 0.05, spout.z - 0.3), 0.035, Color(0.8, 0.8, 0.78), 6)
	m.box(Vector3(spout.x, 0.02, spout.z - 0.5), Vector3(0.2, 0.04, 0.4), Color(0.5, 0.5, 0.48))  # the splash block
	# The driveway's control joints, and where the van drips.
	var apron := HomeBase.APRON_CENTER
	for i in 7:
		var x := apron.x - HomeBase.APRON_SIZE.x / 2 + 3.0 * (i + 1)
		m.box(Vector3(x, 0.002, apron.z), Vector3(0.025, 0.004, HomeBase.APRON_SIZE.z), dark)
	m.box(Vector3(apron.x, 0.002, apron.z), Vector3(HomeBase.APRON_SIZE.x, 0.004, 0.025), dark)
	for blot in [[Vector3(0, 0, 0), 0.32], [Vector3(0.28, 0, 0.12), 0.2], [Vector3(-0.22, 0, -0.1), 0.16]]:
		var at: Vector3 = Vector3(door + 0.2, 0.002, -8.2) + blot[0]
		m.rod(at, at + Vector3(0, 0.002, 0), blot[1], Color(0.3, 0.29, 0.27), 12, true)
	# The bins against the wall west of the door, the hose reel and meter east of it.
	_bin(m, Vector3(0.7, 0, face - 0.4), Color(0.18, 0.32, 0.2))
	_bin(m, Vector3(1.45, 0, face - 0.4), Color(0.17, 0.3, 0.55))
	var reel := Vector3(door + half + 0.55, 0.7, face - 0.12)
	m.box(reel + Vector3(0, 0, 0.1), Vector3(0.32, 0.12, 0.02), Color(0.3, 0.3, 0.3))  # the wall bracket
	for x in [-0.13, 0.13]:
		m.rod(reel + Vector3(x, 0, 0), reel + Vector3(x + signf(x) * 0.015, 0, 0), 0.21, Color(0.3, 0.3, 0.3), 12, true)
	m.rod(reel + Vector3(-0.13, 0, 0), reel + Vector3(0.13, 0, 0), 0.17, Color(0.2, 0.42, 0.18), 12, true)  # the hose, wound on
	for k in 4:
		m.rod(reel + Vector3(-0.1 + k * 0.066, 0, 0), reel + Vector3(-0.1 + k * 0.066 + 0.01, 0, 0), 0.172, Color(0.15, 0.33, 0.14), 12, true)
	m.rod(Vector3(reel.x - 0.3, 0.45, face), Vector3(reel.x - 0.3, 0.45, face - 0.1), 0.02, Color(0.6, 0.5, 0.25), 6, true)  # the tap
	var meter := Vector3(-1.2, 1.5, face)
	m.box(meter + Vector3(0, 0, -0.06), Vector3(0.3, 0.42, 0.12), Color(0.58, 0.6, 0.58))
	m.rod(meter + Vector3(0, 0.05, -0.12), meter + Vector3(0, 0.05, -0.2), 0.09, Color(0.75, 0.8, 0.82), 10, true)
	m.rod(meter + Vector3(0, -0.21, -0.06), Vector3(meter.x, 0.0, face - 0.06), 0.025, Color(0.4, 0.42, 0.4), 6)  # conduit
	# Gooseneck barn lamps on the FrontLamp lights.
	for l in solid.get_children():
		if l is OmniLight3D and l.position.z < face:  # the lamps out front
			var at: Vector3 = l.position
			var shade := Color(0.13, 0.26, 0.19)
			m.rod(Vector3(at.x, at.y + 0.18, face), Vector3(at.x, at.y + 0.18, face - 0.03), 0.07, shade, 10, true)
			m.rod(Vector3(at.x, at.y + 0.18, face - 0.03), Vector3(at.x, at.y + 0.3, at.z + 0.2), 0.015, shade, 6)
			m.rod(Vector3(at.x, at.y + 0.3, at.z + 0.2), Vector3(at.x, at.y + 0.2, at.z), 0.015, shade, 6)
			m.rod(Vector3(at.x, at.y + 0.16, at.z), Vector3(at.x, at.y + 0.22, at.z), 0.06, shade, 10, true)
			m.rod(Vector3(at.x, at.y + 0.1, at.z), Vector3(at.x, at.y + 0.16, at.z), 0.17, shade, 12, true)
			var bulb := ArtDress.trim(dress, at + Vector3(0, 0.08, 0), Vector3(0.12, 0.02, 0.12), ArtPalette.glow(l.light_color, 4.0))
			bulb.name = "LampBulb"
	# The sign board behind the lettering over the door.
	var sign_y := (top + 0.12 + roof) / 2
	m.box(Vector3(door, sign_y, face - 0.01), Vector3(3.6, 0.56, 0.02), Color(0.12, 0.25, 0.5))
	m.box(Vector3(door, sign_y, face - 0.022), Vector3(3.5, 0.46, 0.006), trim)
	for c in solid.get_children():
		if c is Label3D and (c as Label3D).text == "BYTE-RIGHT IT":
			c.position = Vector3(door, sign_y, face - 0.03)
	m.commit(dress, "Front", true, 0.7)
	_roll_up_door(door_parent.get_node_or_null("RollUpDoor"))


## A wheelie bin, lid shut, handle to the wall.
static func _bin(m: ArtMesh, at: Vector3, color: Color) -> void:
	m.box(at + Vector3(0, 0.5, 0), Vector3(0.58, 0.9, 0.68), color, 0.0, ["bottom"])
	m.box(at + Vector3(0, 0.97, -0.02), Vector3(0.62, 0.05, 0.74), color.darkened(0.15))
	m.rod(at + Vector3(-0.27, 1.0, 0.33), at + Vector3(0.27, 1.0, 0.33), 0.02, color.darkened(0.25), 6, true)
	for x in [-0.25, 0.25]:
		m.rod(at + Vector3(x, 0.1, 0.3), at + Vector3(x * 1.15, 0.1, 0.3), 0.1, Color(0.08, 0.08, 0.08), 10, true)


## The roll-up door's sheet steel: fine ribs instead of the greybox slats, a row
## of windows, a bottom seal, and a lift handle and lock on the outside. All on
## the door itself, so it rolls up with it.
static func _roll_up_door(door: Node3D) -> void:
	if door == null:
		return
	var size := Vector3(HomeBase.DOOR_SIZE.x, HomeBase.DOOR_SIZE.y, 0.08)
	for c in door.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			if ((c as MeshInstance3D).mesh as BoxMesh).size.y < 0.1:
				c.visible = false  # the greybox slats
			else:
				c.material_override = ArtPalette.flat(Color(0.86, 0.86, 0.83), 0.45, 0.3)
	var m := ArtMesh.new()
	var rib := Color(0.72, 0.72, 0.7)
	var sections := 8
	var high := size.y / sections
	for i in sections:
		var y := -size.y / 2 + high * (i + 1)
		for z in [-size.z / 2 - 0.004, size.z / 2 + 0.004]:
			if i < sections - 1:
				m.box(Vector3(0, y, z), Vector3(size.x, 0.025, 0.008), rib)
			m.box(Vector3(0, y - high / 2, z), Vector3(size.x, 0.008, 0.006), rib.lightened(0.1))
	var glass := Color(0.16, 0.2, 0.24)
	var row := -size.y / 2 + high * 5.5
	for k in 5:
		var x := -size.x / 2 + size.x * (k + 0.5) / 5
		for z in [-size.z / 2 - 0.005, size.z / 2 + 0.005]:
			m.box(Vector3(x, row, z), Vector3(0.6, 0.28, 0.006), glass)
	m.box(Vector3(0, -size.y / 2 + 0.02, 0), Vector3(size.x, 0.04, size.z + 0.03), Color(0.08, 0.08, 0.08))  # the seal
	var out := -size.z / 2 - 0.02
	m.box(Vector3(0, -size.y / 2 + 0.55, out), Vector3(0.3, 0.03, 0.03), Color(0.3, 0.3, 0.32))  # the lift handle
	m.rod(Vector3(0, -size.y / 2 + 1.1, out + 0.01), Vector3(0, -size.y / 2 + 1.1, out - 0.02), 0.035, Color(0.7, 0.66, 0.5), 10, true)  # the T-lock
	m.box(Vector3(0, -size.y / 2 + 1.1, out - 0.025), Vector3(0.12, 0.02, 0.015), Color(0.7, 0.66, 0.5))
	m.commit(door, "DoorSkin", true, 0.45, 0.3)


## The briefing corner: a hand-me-down couch and a counter run with red diner
## stools, all facing Maddison's whiteboard. Their greybox blocks keep the
## collision; the Seats are HomeBase's.
static func _briefing_corner(level: LevelBase, dress: Node3D) -> void:
	for n in ["Couch", "CouchBack", "Counter"]:
		var block := level.geo.get_node_or_null(n)
		if block:
			ArtDress.hide_block(block)
	ArtProps.sofa(dress, HomeBase.COUCH, 90)
	ArtProps.kitchen_counter(dress, HomeBase.COUNTER, -90, 3.4, 0.6, 1.04)
	for i in HomeBase.CREW_SEATS.size():
		var stool := level.geo.get_node_or_null("Stool%d" % i)
		if stool:
			ArtDress.hide_block(stool)
			var top: Vector3 = HomeBase.CREW_SEATS[i]
			ArtProps.bar_stool(dress, Vector3(top.x, 0, top.z), top.y, Color(0.55, 0.12, 0.1), i == 4)
	# On the counter: the coffee, everyone's mugs, a stack of floppies.
	var on := HomeBase.COUNTER + Vector3(0, 1.04, 0)
	ArtProps.coffee_maker(dress, on + Vector3(0.05, 0, -1.2), -90)
	var m := ArtMesh.new()
	for mug in [[Vector3(0.12, 0, -0.75), Color(0.85, 0.83, 0.78)], [Vector3(-0.1, 0, -0.55), Color(0.2, 0.35, 0.6)],
			[Vector3(0.05, 0, 0.35), Color(0.7, 0.25, 0.15)]]:
		var at: Vector3 = on + mug[0]
		m.rod(at, at + Vector3(0, 0.095, 0), 0.04, mug[1], 10, true)
		m.rod(at + Vector3(0, 0.095, 0), at + Vector3(0, 0.096, 0), 0.034, Color(0.2, 0.11, 0.05), 10, true)
		m.box(at + Vector3(0.045, 0.05, 0), Vector3(0.015, 0.06, 0.012), mug[1])
	for k in 5:
		var tint: Color = [Color(0.1, 0.1, 0.11), Color(0.15, 0.25, 0.5), Color(0.1, 0.1, 0.11), Color(0.6, 0.15, 0.12), Color(0.85, 0.85, 0.82)][k]
		m.box(on + Vector3(-0.05, 0.002 + k * 0.0034, 0.95), Vector3(0.09, 0.0033, 0.094), tint, float(k * 7 - 10))
	m.commit(dress, "CounterClutter", true, 0.5)


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


## A clip-on work lamp on the tech table.
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


## The steel shelving in the back corner, where the shop bag was left: grey
## angle posts, three particle-board shelves and the garage's overflow below.
## The greybox block keeps its collider.
static func _shelf(level: LevelBase, dress: Node3D) -> void:
	var block := level.geo.get_node_or_null("Shelf")
	if block == null:
		return
	ArtDress.hide_block(block)
	var at := HomeBase.SHELF
	var w := 1.6
	var d := 0.7
	var steel := Color(0.55, 0.57, 0.6)
	var board := Color(0.74, 0.69, 0.6)
	var card := Color(0.52, 0.36, 0.19)
	var m := ArtMesh.new()
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			# Slotted angle posts, one flange along each side.
			var post := at + Vector3(sx * (w / 2 - 0.02), 0.5, sz * (d / 2 - 0.02))
			m.box(post + Vector3(-sx * 0.015, 0, 0), Vector3(0.035, 1.0, 0.004), steel)
			m.box(post + Vector3(0, 0, -sz * 0.015), Vector3(0.004, 1.0, 0.035), steel)
	for y in [0.12, 0.55, 0.985]:
		m.box(at + Vector3(0, y, 0), Vector3(w - 0.02, 0.025, d - 0.02), board)
		for sz in [-1.0, 1.0]:
			m.box(at + Vector3(0, y - 0.02, sz * (d / 2 - 0.02)), Vector3(w, 0.035, 0.004), steel)  # front and back rails
	# The overflow: storage boxes, a paint can, a coil of network cable.
	m.box(at + Vector3(-0.45, 0.135 + 0.16, 0.0), Vector3(0.5, 0.32, 0.45), card)
	m.box(at + Vector3(-0.45, 0.135 + 0.28, -0.12), Vector3(0.12, 0.08, 0.004), Color(0.95, 0.93, 0.85))  # its label
	m.box(at + Vector3(0.2, 0.135 + 0.12, 0.05), Vector3(0.42, 0.24, 0.38), card.darkened(0.15))
	for x in [-0.45, -0.3]:
		var top: float = 0.135 + 0.32 if x < -0.4 else 0.565 + 0.22
		var bx: float = x
		m.box(at + Vector3(bx, top + 0.001, 0.0), Vector3(0.05, 0.002, 0.36), Color(0.78, 0.7, 0.5))  # packing tape
	m.rod(at + Vector3(0.6, 0.135, -0.05), at + Vector3(0.6, 0.135 + 0.19, -0.05), 0.085, Color(0.75, 0.75, 0.72), 10, true)
	m.box(at + Vector3(-0.3, 0.565 + 0.11, 0.0), Vector3(0.38, 0.22, 0.34), card)
	for i in 6:
		var a := TAU * i / 6.0
		var b := TAU * (i + 1) / 6.0
		var c := at + Vector3(0.35, 0.585, 0.0)
		m.rod(c + Vector3(cos(a), 0, sin(a)) * 0.13, c + Vector3(cos(b), 0, sin(b)) * 0.13, 0.02, Color(0.25, 0.45, 0.75), 5)
	m.commit(dress, "Shelf", true, 0.7)


## The bookshop's paper bag on the shelf, with the book in it: kraft paper with
## a folded rim, twisted paper handles and the shop's name on the front. It rides
## on the bag itself, so it goes when the bag is picked up; the greybox box keeps
## its collider and prompt.
static func _shop_bag(level: Node) -> void:
	var bag: Node3D = level.get("book_bag")
	if bag == null:
		return
	for c in bag.get_children():
		if c is GeometryInstance3D:
			c.visible = false
	var kraft := Color(0.66, 0.49, 0.31)
	var crease := kraft.darkened(0.18)
	var m := ArtMesh.new()
	var w := 0.38
	var h := 0.27
	var d := 0.14
	var base := -0.15  # the shelf, under the bag's middle
	m.box(Vector3(0, base + h / 2, 0), Vector3(w, h, d), kraft, 0.0, ["top"])
	m.box(Vector3(0, base + h - 0.015, 0), Vector3(w + 0.004, 0.03, d + 0.004), kraft.lightened(0.06), 0.0, ["top", "bottom"])  # the folded rim
	for sx in [-1.0, 1.0]:
		m.box(Vector3(sx * (w / 2 + 0.001), base + h / 2 - 0.01, 0), Vector3(0.002, h - 0.04, 0.006), crease)  # the gusset folds
	m.box(Vector3(0, base + h - 0.035, 0), Vector3(w - 0.01, 0.002, d - 0.01), kraft.darkened(0.55), 0.0, ["bottom"])  # the shadow inside
	# Twisted paper handles over the top, one on each face.
	for sz in [-1.0, 1.0]:
		var z: float = sz * (d / 2 - 0.01)
		var pts := []
		for i in 7:
			var t := float(i) / 6.0
			pts.append(Vector3(lerpf(-0.07, 0.07, t), base + h - 0.02 + sin(PI * t) * 0.09, z))
		for i in 6:
			m.rod(pts[i], pts[i + 1], 0.006, kraft.darkened(0.1), 5)
	# The book, standing in the bag: its teal top edge just shows above the rim.
	m.box(Vector3(-0.03, base + 0.13, 0.005), Vector3(0.19, 0.25, 0.03), Color(0.05, 0.55, 0.6), -4.0)
	m.box(Vector3(-0.03, base + 0.255, 0.005), Vector3(0.18, 0.004, 0.025), Color(0.95, 0.94, 0.88), -4.0)  # page edges
	m.commit(bag, "ShopBag", true)
	# The shop's name, printed on the side that faces the room.
	var bold := ThemeDB.fallback_font
	var front := Node3D.new()
	front.name = "Print"
	front.position = Vector3(0, base + h * 0.45, -d / 2 - 0.0015)
	bag.add_child(front)
	ArtProps._print(front, "PAGE ONE", Vector3(0, 0.025, 0), 0.24, bold, 110, Color(0.12, 0.25, 0.16)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ArtProps._print(front, "books · software · coffee", Vector3(0, -0.02, 0), 0.22, bold, 52, Color(0.12, 0.25, 0.16)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Somewhere to sit (Seat, from Movement): E on the chair sits you facing the way it faces.
static func _seat(chair: Node3D) -> Seat:
	return Seat.create_at(chair.get_parent(), chair.transform * Vector3(0, ArtKit.CHAIR_SEAT, 0), chair.rotation.y, Vector2(0.42, 0.4))


## The punch bag's stand: black powder-coated square tube, a gusset in each top
## corner, rubber-capped feet with weight plates on each end to hold it down, and
## a swivel plate under the bar for the chain. The greybox posts, feet and bar keep
## their colliders.
static func _bag_stand(level: LevelBase, dress: Node3D) -> void:
	var at := HomeBase.PUNCH_BAG
	var half := HomeBase.BAG_STAND_HALF
	var top := HomeBase.BAG_HOOK
	var found := 0
	for b in level.geo.get_children():
		if b is StaticBody3D and String(b.name).begins_with("BagStand"):
			ArtDress.hide_block(b)
			found += 1
	if found == 0:
		return
	var tube := Color(0.09, 0.09, 0.1)
	var rubber := Color(0.05, 0.05, 0.05)
	var iron := Color(0.16, 0.16, 0.17)
	var m := ArtMesh.new()
	for side in [-1.0, 1.0]:
		var x: float = at.x + side * half
		m.box(Vector3(x, top / 2 + 0.05, at.z), Vector3(0.07, top + 0.1, 0.07), tube)
		m.box(Vector3(x, 0.04, at.z), Vector3(0.08, 0.07, 1.06), tube)
		m.box(Vector3(x, 0.03, at.z), Vector3(0.16, 0.06, 0.16), tube)  # base plate
		for dz in [-1.0, 1.0]:
			m.box(Vector3(x, 0.04, at.z + dz * 0.54), Vector3(0.09, 0.08, 0.04), rubber)  # end caps
			# Two plates lying flat on a peg at each end of the foot.
			var peg := Vector3(x, 0.08, at.z + dz * 0.38)
			for k in 2:
				m.rod(peg + Vector3(0, k * 0.045, 0), peg + Vector3(0, k * 0.045 + 0.04, 0), 0.17 - k * 0.03, iron, 18, true)
			m.rod(peg, peg + Vector3(0, 0.13, 0), 0.025, Color(0.55, 0.55, 0.57), 8, true)
		# The corner gusset, inward and above head height.
		var g := Basis(Vector3.BACK, side * deg_to_rad(45.0))  # leaning in toward the bar
		m.oriented_box(Vector3(x - side * 0.17, top - 0.12, at.z), Vector3(0.05, 0.42, 0.05), tube, g)
	m.box(Vector3(at.x, top + 0.06, at.z), Vector3(half * 2 + 0.08, 0.08, 0.08), tube)
	m.box(Vector3(at.x, top + 0.01, at.z), Vector3(0.14, 0.02, 0.14), Color(0.5, 0.5, 0.52))  # swivel plate
	m.rod(Vector3(at.x, top + 0.0, at.z), Vector3(at.x, top - 0.05, at.z), 0.025, Color(0.6, 0.6, 0.62), 8, true)
	m.commit(dress, "BagStand", true, 0.45, 0.4)

