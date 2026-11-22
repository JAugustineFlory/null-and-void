class_name DressGroundRooms
extends RefCounted
## Furnishing for the ground floor's staff rooms (GroundFloor's, behind their
## locked doors): where Halcyon's people work by day, left as they left them.
## Called from DressLevel0.ground, so Level 0 and Level 4's walk out share them.
## Solid props go in `geo`, the rest in `dress`. No words anywhere in here: a
## room's only writing is the sign over its door (GroundFloor).

const STEEL := Color(0.5, 0.52, 0.54)
const PAPER := Color(0.93, 0.92, 0.86)
const BLACK := Color(0.09, 0.09, 0.1)


## A window's frame, both sides of its glass, for each of GroundFloor's windows.
static func window_frames(dress: Node3D) -> void:
	var frame := ArtPalette.flat(Color(0.3, 0.31, 0.33), 0.5, 0.4)
	for o in GroundFloor.openings():
		if o.size() < 6:
			continue
		var wide: float = o[3]
		var sill: float = o[5]
		var head: float = o[4]
		var along := Vector3(1, 0, 0) if o[0] == "x" else Vector3(0, 0, 1)
		var through := Vector3(0, 0, 1) if o[0] == "x" else Vector3(1, 0, 0)
		var mid := Vector3(o[1], (sill + head) / 2.0, o[2])
		var deep := 0.24  # a little proud of the wall, both sides
		for y in [sill, head]:
			ArtDress.trim(dress, Vector3(mid.x, y, mid.z), along * (wide + 0.08) + through * deep + Vector3(0, 0.05, 0), frame)
		for side in [-1.0, 0.0, 1.0]:  # the jambs, and a mullion up the middle
			var bar := 0.05 if side != 0.0 else 0.035
			ArtDress.trim(dress, mid + along * side * wide / 2.0, along * bar + through * (deep if side != 0.0 else 0.06) + Vector3(0, head - sill, 0), frame)


## Visitor badges, off the lobby beside the front desk: where daytime visitors are
## photographed and badged. A counter across the room with the clerk's side behind
## it, the ID camera and its stool in front of a backdrop, and chairs to wait on.
static func visitor_badges(geo: Node3D, dress: Node3D) -> void:
	var room := GroundFloor.VISITOR_BADGES
	# The counter: from the north wall most of the way down the room. Staff walk
	# round its south end.
	var counter_e := 4.6
	var counter_long := 6.4
	var top := 1.05
	_counter(geo, GroundFloor.at(room, counter_e, 0, counter_long / 2.0), counter_long, top)
	var on := func(south: float, east := 0.0) -> Vector3: return GroundFloor.at(room, counter_e + east, top, south)
	_laminator(dress, on.call(2.1, -0.08))
	_badge_tray(dress, on.call(3.1, -0.05))
	_forms(dress, on.call(4.5, 0.08))
	_desk_bell(dress, on.call(5.3, 0.12))
	# The clerk's chair at the counter, and her desk behind it against the north wall.
	ArtProps.sittable(ArtProps.office_chair(geo, GroundFloor.at(room, counter_e - 0.85, 0, 3.3), -100), ArtProps.OFFICE_SEAT)
	var desk := GroundFloor.at(room, 1.7, 0, 0.5)
	ArtProps.desk(geo, desk, 180, 1.6)
	ArtProps.crt_monitor(dress, desk + Vector3(0.25, 0.76, -0.12), 172, "off")
	DressLevel0._in_tray(dress, desk + Vector3(-0.5, 0.76, -0.05), 2)
	ArtProps.sittable(ArtProps.office_chair(geo, desk + Vector3(0.2, 0, 0.85), 12), ArtProps.OFFICE_SEAT)
	DressLevel0._bin(dress, desk + Vector3(-0.95, 0, 0.3))
	# Along the west wall: the lanyards' pegboard, and filing.
	_lanyard_board(dress, GroundFloor.at(room, 0.11, 1.55, 4.6))
	for south in [6.6, 7.1, 7.6]:
		ArtProps.filing_cabinet(geo, GroundFloor.at(room, 0.42, 0, south), -90)
	ArtProps.boxes(geo, GroundFloor.at(room, 0.5, 0, 9.3), 8, 2)
	# The photo corner: a pale backdrop on the north wall, a stool in front of it,
	# and the camera on its stand, looking at the stool.
	var photo_e := 7.9
	ArtDress.trim(dress, GroundFloor.at(room, photo_e, 1.55, 0.115), Vector3(1.3, 1.3, 0.02), ArtPalette.flat(Color(0.62, 0.72, 0.8), 0.9))
	ArtDress.trim(dress, GroundFloor.at(room, photo_e, 2.22, 0.12), Vector3(1.36, 0.04, 0.04), ArtPalette.flat(Color(0.3, 0.31, 0.33), 0.5, 0.4))  # its roller
	ArtProps.bar_stool(dress, GroundFloor.at(room, photo_e, 0, 0.8), 0.6, Color(0.14, 0.15, 0.18))
	_id_camera(geo, GroundFloor.at(room, photo_e, 0, 2.7))
	# Waiting: three chairs under the window, two against the south wall.
	var shells := [Color(0.28, 0.42, 0.55), Color(0.28, 0.42, 0.55), Color(0.72, 0.45, 0.2)]
	for i in 3:
		ArtProps.sittable(ArtProps.cafe_chair(geo, GroundFloor.at(room, room.size.x - 0.45, 0, 6.95 + i * 0.8), 90 + (i - 1) * 4, shells[i]), ArtProps.CAFE_SEAT)
	for i in 2:
		ArtProps.sittable(ArtProps.cafe_chair(geo, GroundFloor.at(room, 6.3 + i * 0.8, 0, room.size.y - 0.45), 3 - i * 6, shells[2 - i]), ArtProps.CAFE_SEAT)
	ArtProps.potted_plant(geo, GroundFloor.at(room, room.size.x - 0.6, 0, 0.6))
	ArtDress.skirting(dress, GroundFloor.mid(room), GroundFloor.span(room, GroundFloor.BACK_H), GroundFloor.gaps_of(room))


## The security post, at the hall's shutter: the guard's desk under the window
## onto the lobby, the camera monitors beside it, the key cabinet, a locker.
## Nobody is in tonight: the chair is pushed back with a jacket over it, and the
## monitors are still on.
static func security_post(geo: Node3D, dress: Node3D) -> void:
	var room := GroundFloor.SECURITY
	# The window desk: whoever sits at it looks out at the front doors.
	var watch := GroundFloor.at(room, 0.5, 0, GroundFloor.SECURITY_WINDOW.y - room.position.y)
	ArtProps.desk(geo, watch, -90, 2.4)
	_logbook(dress, watch + Vector3(0.02, 0.76, -0.45))
	_mug(dress, watch + Vector3(-0.12, 0.76, 0.5), Color(0.2, 0.3, 0.5))
	_torch(dress, watch + Vector3(0.05, 0.76, 0.95))
	# The monitors' desk, along the south wall: four screens, two on a riser.
	var bank := GroundFloor.at(room, 2.7, 0, room.size.y - 0.5)
	ArtProps.desk(geo, bank, 0, 2.4)
	_monitor_bank(dress, bank + Vector3(0, 0.76, 0.08))
	# His chair, pushed back from the screens and turned, his jacket over its back.
	var chair := ArtProps.office_chair(geo, bank + Vector3(0.35, 0, -1.35), 158)
	ArtProps.sittable(chair, ArtProps.OFFICE_SEAT)
	_jacket(chair)
	DressLevel0._bin(dress, bank + Vector3(1.45, 0, -0.2))
	# The east wall: the key cabinet, and filing under it.
	_key_cabinet(dress, GroundFloor.at(room, room.size.x - 0.11, 1.55, 3.4))
	ArtProps.filing_cabinet(geo, GroundFloor.at(room, room.size.x - 0.42, 0, 5.9), 90)
	ArtProps.filing_cabinet(geo, GroundFloor.at(room, room.size.x - 0.42, 0, 6.4), 90)
	# By the door: a side table with the coffee maker, and a spare mug.
	var brew := GroundFloor.at(room, 4.6, 0, 0.48)
	ArtProps.desk(geo, brew, 180, 1.2)
	ArtProps.coffee_maker(dress, brew + Vector3(-0.25, 0.76, -0.05), 180)
	_mug(dress, brew + Vector3(0.25, 0.76, 0.1), Color(0.85, 0.85, 0.8))
	# His locker, in the corner past the door.
	_locker(geo, GroundFloor.at(room, room.size.x - 0.5, 0, 0.4))
	ArtDress.skirting(dress, GroundFloor.mid(room), GroundFloor.span(room, GroundFloor.BACK_H), GroundFloor.gaps_of(room))


## A service counter running north-south, `long` metres, its middle on `pos` (the
## floor): a laminate top on a panelled front, open underneath on the staff
## (west) side.
static func _counter(geo: Node3D, pos: Vector3, long: float, top: float) -> void:
	var deep := 0.6
	var body := ArtProps._body(geo, pos, 0, "BadgeCounter", Vector3(deep, top, long), Vector3(0, top / 2.0, 0))
	var m := ArtMesh.new()
	var panel := Color(0.42, 0.44, 0.5)
	m.box(Vector3(0, top - 0.02, 0), Vector3(deep + 0.06, 0.04, long), Color(0.8, 0.78, 0.7))  # the top
	m.box(Vector3(deep / 2.0 - 0.02, (top - 0.04) / 2.0, 0), Vector3(0.04, top - 0.04, long), panel)  # its public face
	m.box(Vector3(deep / 2.0 + 0.005, 0.06, 0), Vector3(0.01, 0.12, long), panel.darkened(0.45))  # kick strip
	var bays := 4
	for i in bays + 1:  # the uprights, and a shelf between them
		m.box(Vector3(-0.02, (top - 0.04) / 2.0, -long / 2.0 + 0.02 + i * (long - 0.04) / bays), Vector3(deep - 0.04, top - 0.04, 0.04), panel.darkened(0.2))
	m.box(Vector3(-0.02, 0.5, 0), Vector3(deep - 0.06, 0.03, long - 0.04), panel.darkened(0.2))
	m.commit(body, "Counter", true)


## The badge laminator: a low grey box with a slot and a lit ready lamp gone dark.
static func _laminator(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	m.box(Vector3(0, 0.05, 0), Vector3(0.3, 0.1, 0.42), Color(0.78, 0.76, 0.68))
	m.box(Vector3(0, 0.102, 0), Vector3(0.22, 0.006, 0.36), Color(0.6, 0.58, 0.52))
	m.box(Vector3(0.151, 0.06, 0), Vector3(0.004, 0.012, 0.3), BLACK)  # the slot
	m.box(Vector3(0.1, 0.104, -0.17), Vector3(0.02, 0.006, 0.02), Color(0.3, 0.08, 0.06))  # its lamp, off
	m.commit(ArtProps._node(parent, pos, 0, "Laminator"), "Laminator")


## A tray of blank visitor badges on their clips, and a few lanyards beside it.
static func _badge_tray(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	m.box(Vector3(0, 0.012, 0), Vector3(0.24, 0.024, 0.34), Color(0.2, 0.2, 0.22))
	for i in 4:
		for k in 2:
			m.box(Vector3(-0.055 + k * 0.11, 0.028, -0.115 + i * 0.077), Vector3(0.085, 0.006, 0.055), Color(0.92, 0.92, 0.9), 4.0 - i * 3.0)
			m.box(Vector3(-0.055 + k * 0.11, 0.033, -0.135 + i * 0.077), Vector3(0.03, 0.006, 0.012), STEEL)  # its clip
	m.commit(ArtProps._node(parent, pos, 0, "BadgeTray"), "Tray")


## A pad of blank sign-in slips, squared up, with a pen on a chain.
static func _forms(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	m.box(Vector3(0, 0.012, 0), Vector3(0.22, 0.024, 0.3), PAPER, 4.0)
	m.box(Vector3(0.003, 0.026, -0.14), Vector3(0.22, 0.006, 0.025), Color(0.3, 0.3, 0.34), 4.0)  # the pad's binding
	m.rod(Vector3(0.14, 0.008, 0.2), Vector3(0.2, 0.008, 0.08), 0.006, Color(0.1, 0.15, 0.4), 5, true)  # the pen
	m.rod(Vector3(0.2, 0.004, 0.08), Vector3(0.22, 0.004, -0.1), 0.002, STEEL, 3)  # its chain
	m.commit(ArtProps._node(parent, pos, 0, "SignInSlips"), "Slips")


## A counter bell.
static func _desk_bell(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	var brass := Color(0.75, 0.62, 0.3)
	m.rod(Vector3.ZERO, Vector3(0, 0.012, 0), 0.05, BLACK, 10, true)
	m.rod(Vector3(0, 0.012, 0), Vector3(0, 0.04, 0), 0.042, brass, 10, true)
	m.rod(Vector3(0, 0.04, 0), Vector3(0, 0.052, 0), 0.024, brass, 8, true)
	m.rod(Vector3(0, 0.052, 0), Vector3(0, 0.066, 0), 0.007, brass.darkened(0.3), 5, true)
	m.commit(ArtProps._node(parent, pos, 0, "DeskBell"), "Bell", false, 0.35, 0.7)


## A pegboard on the west wall (its face to the east), lanyards hanging from its
## pegs in rows. `pos` is its middle.
static func _lanyard_board(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	m.box(Vector3(0, 0, 0), Vector3(0.02, 0.8, 1.2), Color(0.55, 0.47, 0.36))
	var cords := [Color(0.1, 0.2, 0.5), Color(0.1, 0.2, 0.5), Color(0.55, 0.12, 0.1), Color(0.1, 0.2, 0.5), Color(0.2, 0.2, 0.22)]
	for i in 9:
		var z := -0.48 + i * 0.12
		m.rod(Vector3(0.01, 0.3, z), Vector3(0.05, 0.3, z), 0.006, STEEL, 4, true)  # the peg
		if i == 3 or i == 7:
			continue  # two taken
		var long := 0.42 + float(i % 3) * 0.03
		m.box(Vector3(0.04, 0.3 - long / 2.0, z), Vector3(0.012, long, 0.03), cords[i % cords.size()])
		m.box(Vector3(0.04, 0.3 - long - 0.035, z), Vector3(0.008, 0.07, 0.09), Color(0.92, 0.92, 0.9))  # a blank card in its sleeve
	m.commit(ArtProps._node(parent, pos, 0, "LanyardBoard"), "Board")


## The ID camera on its stand: a boxy instant camera with a flash, looking north.
## `pos` is the floor under it.
static func _id_camera(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "IdCamera", Vector3(0.5, 1.5, 0.5), Vector3(0, 0.75, 0))
	var m := ArtMesh.new()
	var head := 1.32
	for i in 3:  # the tripod
		var a := TAU * i / 3.0 + 0.5
		m.rod(Vector3(cos(a) * 0.34, 0, sin(a) * 0.34), Vector3(0, head - 0.2, 0), 0.014, BLACK, 5)
	m.rod(Vector3(0, head - 0.24, 0), Vector3(0, head - 0.1, 0), 0.022, STEEL, 6, true)
	m.box(Vector3(0, head, 0), Vector3(0.24, 0.2, 0.2), Color(0.16, 0.16, 0.18))  # the camera
	m.rod(Vector3(0, head, -0.1), Vector3(0, head, -0.17), 0.05, BLACK, 10, true)  # its lens
	m.rod(Vector3(0, head, -0.17), Vector3(0, head, -0.172), 0.036, Color(0.25, 0.3, 0.4), 10, true)
	m.box(Vector3(0, head + 0.15, -0.04), Vector3(0.16, 0.09, 0.08), Color(0.2, 0.2, 0.22))  # the flash
	m.box(Vector3(0, head + 0.15, -0.081), Vector3(0.13, 0.065, 0.004), Color(0.85, 0.87, 0.9))
	m.box(Vector3(0, head - 0.06, 0.102), Vector3(0.12, 0.012, 0.006), BLACK)  # where the print comes out
	m.commit(body, "Camera", true)


## The guard's logbook, open on the desk with a pen in its gutter: ruled lines,
## nothing to read. Its spine runs north-south.
static func _logbook(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	m.box(Vector3(0, 0.008, 0), Vector3(0.34, 0.016, 0.46), Color(0.15, 0.2, 0.16), 6.0)  # the cover
	var turn := Basis(Vector3.UP, deg_to_rad(6.0))
	for side in [-1.0, 1.0]:
		m.oriented_box(turn * Vector3(0, 0.02, side * 0.113), Vector3(0.31, 0.012, 0.215), PAPER, turn)
		for i in 7:  # ruled, and half filled in
			if side > 0.0 and i > 2:
				continue
			m.oriented_box(turn * Vector3(-0.11 + i * 0.036, 0.0265, side * 0.113), Vector3(0.004, 0.001, 0.17), Color(0.2, 0.22, 0.4), turn)
	m.rod(turn * Vector3(-0.1, 0.03, 0.0), turn * Vector3(0.05, 0.03, 0.01), 0.006, Color(0.1, 0.1, 0.12), 5, true)
	m.commit(ArtProps._node(parent, pos, 0, "Logbook"), "Logbook")


## A coffee mug, long cold.
static func _mug(parent: Node3D, pos: Vector3, glaze: Color) -> void:
	var m := ArtMesh.new()
	m.rod(Vector3.ZERO, Vector3(0, 0.095, 0), 0.04, glaze, 10, true)
	m.rod(Vector3(0, 0.095, 0), Vector3(0, 0.096, 0), 0.033, Color(0.12, 0.08, 0.05), 10, true)
	m.box(Vector3(0.052, 0.05, 0), Vector3(0.03, 0.055, 0.012), glaze)
	m.commit(ArtProps._node(parent, pos, 0, "Mug"), "Mug")


## A heavy flashlight, lying on the desk.
static func _torch(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	m.rod(Vector3(0, 0.024, -0.13), Vector3(0, 0.024, 0.1), 0.02, BLACK, 8, true)
	m.rod(Vector3(0, 0.03, 0.1), Vector3(0, 0.03, 0.17), 0.03, BLACK, 8, true)
	m.rod(Vector3(0, 0.03, 0.17), Vector3(0, 0.03, 0.172), 0.025, Color(0.8, 0.82, 0.78), 8, true)
	m.commit(ArtProps._node(parent, pos, 24, "Torch"), "Torch")


## Four camera monitors, two on the desk and two on a riser over them, their
## screens to the north, all on: grey pictures of empty corridors. `pos` is on the
## desk top, under the middle of the bank. They light the room a little.
static func _monitor_bank(parent: Node3D, pos: Vector3) -> void:
	var root := ArtProps._node(parent, pos, 0, "CameraMonitors")
	var m := ArtMesh.new()
	var shell := Color(0.2, 0.2, 0.22)
	var wide := 0.46
	var tall := 0.38
	m.box(Vector3(0, tall + 0.02, 0.02), Vector3(wide * 2.0 + 0.2, 0.03, 0.42), STEEL.darkened(0.3))  # the riser's shelf
	for sx in [-1.0, 1.0]:
		m.box(Vector3(sx * (wide + 0.085), (tall + 0.02) / 2.0, 0.02), Vector3(0.03, tall + 0.02, 0.42), STEEL.darkened(0.3))
	var views := [Color(0.42, 0.46, 0.46), Color(0.36, 0.4, 0.42), Color(0.44, 0.47, 0.45), Color(0.33, 0.37, 0.4)]
	var n := 0
	for row in 2:
		for sx in [-0.5, 0.5]:
			var at := Vector3(sx * (wide + 0.02), row * (tall + 0.04) + tall / 2.0, 0.02)
			m.box(at, Vector3(wide, tall, 0.4), shell)
			# The picture: a floor, a far wall, a doorway. No two alike.
			var glass := at + Vector3(0, 0.01, -0.201)
			ArtProps._piece(root, Vector3(wide - 0.08, tall - 0.1, 0.004), glass, ArtPalette.glow(views[n], 0.7))
			ArtProps._piece(root, Vector3(wide - 0.08, 0.09 + 0.02 * (n % 2), 0.005), glass + Vector3(0, -0.1 + 0.01 * (n % 2), -0.001), ArtPalette.glow(views[n].darkened(0.45), 0.5))
			ArtProps._piece(root, Vector3(0.07, 0.12, 0.005), glass + Vector3(-0.1 + n * 0.07, 0.01, -0.001), ArtPalette.glow(views[n].darkened(0.7), 0.4))
			m.box(at + Vector3(wide / 2.0 - 0.04, -tall / 2.0 + 0.03, -0.201), Vector3(0.012, 0.012, 0.004), Color(0.9, 0.2, 0.1))  # power lamp
			n += 1
	m.box(Vector3(0, 0.02, -0.3), Vector3(0.34, 0.04, 0.14), shell)  # the switcher, with its row of buttons
	for i in 4:
		m.box(Vector3(-0.11 + i * 0.073, 0.043, -0.3), Vector3(0.04, 0.008, 0.04), Color(0.55, 0.55, 0.5) if i > 0 else Color(0.8, 0.6, 0.15))
	m.commit(root, "Bank", true)
	var light := OmniLight3D.new()
	light.name = "MonitorGlow"
	light.position = Vector3(0, 0.5, -0.9)
	light.light_color = Color(0.72, 0.8, 0.85)
	light.light_energy = 0.45
	light.omni_range = 4.5
	light.shadow_enabled = false
	root.add_child(light)


## A jacket hung over an office chair's back (ArtProps.office_chair's own space).
static func _jacket(chair: Node3D) -> void:
	var m := ArtMesh.new()
	var cloth := Color(0.17, 0.25, 0.43)
	m.box(Vector3(0, 0.86, 0.225), Vector3(0.5, 0.5, 0.12), cloth)  # over the back
	m.box(Vector3(0, 1.1, 0.225), Vector3(0.54, 0.05, 0.15), cloth)  # the shoulders
	m.box(Vector3(0, 1.13, 0.21), Vector3(0.2, 0.03, 0.1), cloth.lightened(0.12))  # the collar
	for sx in [-1.0, 1.0]:
		m.box(Vector3(sx * 0.285, 0.8, 0.225), Vector3(0.09, 0.56, 0.11), cloth.darkened(0.1), sx * 4.0)  # a sleeve
	m.box(Vector3(0.14, 0.95, 0.288), Vector3(0.09, 0.07, 0.006), Color(0.7, 0.62, 0.3))  # a shoulder patch, too worn to read
	m.commit(chair, "Jacket", true)


## The key cabinet on the east wall (its face to the west): a shallow steel box
## with its door shut. `pos` is its middle.
static func _key_cabinet(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	m.box(Vector3(-0.05, 0, 0), Vector3(0.1, 0.7, 0.55), STEEL)
	m.box(Vector3(-0.103, 0, 0), Vector3(0.006, 0.64, 0.49), STEEL.lightened(0.08))  # the door
	m.rod(Vector3(-0.106, 0, -0.2), Vector3(-0.115, 0, -0.2), 0.014, Color(0.75, 0.65, 0.3), 8, true)  # its lock
	for y in [-0.24, 0.24]:
		m.box(Vector3(-0.104, y, 0.262), Vector3(0.012, 0.06, 0.014), STEEL.darkened(0.3))  # hinges
	m.commit(ArtProps._node(parent, pos, 0, "KeyCabinet"), "KeyCabinet", false, 0.5, 0.5)


## A tall steel locker, its door to the south. `pos` is the floor under it.
static func _locker(geo: Node3D, pos: Vector3) -> void:
	var w := 0.45
	var h := 1.8
	var d := 0.5
	var body := ArtProps._body(geo, pos, 0, "Locker", Vector3(w, h, d), Vector3(0, h / 2.0, 0))
	var m := ArtMesh.new()
	var paint := Color(0.36, 0.42, 0.44)
	m.box(Vector3(0, h / 2.0, 0), Vector3(w, h, d), paint)
	m.box(Vector3(0, h / 2.0, d / 2.0 + 0.003), Vector3(w - 0.04, h - 0.06, 0.006), paint.lightened(0.06))  # the door
	for i in 4:  # louvres top and bottom
		m.box(Vector3(0, h - 0.16 - i * 0.03, d / 2.0 + 0.007), Vector3(w - 0.14, 0.008, 0.004), paint.darkened(0.4))
		m.box(Vector3(0, 0.16 + i * 0.03, d / 2.0 + 0.007), Vector3(w - 0.14, 0.008, 0.004), paint.darkened(0.4))
	m.box(Vector3(w / 2.0 - 0.07, h / 2.0, d / 2.0 + 0.012), Vector3(0.025, 0.1, 0.014), STEEL)  # the handle
	m.commit(body, "Locker", true, 0.55, 0.4)
