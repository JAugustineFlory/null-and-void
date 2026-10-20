class_name DressLevel1
extends RefCounted
## Furnishing for Level 1, the server floor: machine rooms behind cold blue walls,
## a network operations room, a cable vault and a break room round two plain
## corridors. A working night shift's floor; nothing threatens here. Called once at
## the end of Level 1's build(), before navigation bakes. Positions are in the
## wing's own space; the World turns the whole wing, and the textures are mapped in
## world space so they still line up.

# Room zones stop short of the walls rooms share with a corridor, so those walls
# take the corridor's look (see ArtDress.reskin).
const ROOM := AABB(Vector3(-7.2, -0.5, -8.8), Vector3(14.4, 4.5, 17.6))
const SERVER_B := AABB(Vector3(8.2, -0.5, -2.8), Vector3(13.6, 4.5, 11.6))
const SERVER_C := AABB(Vector3(-16.8, -0.5, -23.8), Vector3(9.6, 4.5, 10.6))
const NOC := AABB(Vector3(-21.8, -0.5, -2.8), Vector3(13.6, 4.0, 11.6))
const VAULT := AABB(Vector3(-21.8, -0.5, -8.8), Vector3(13.6, 4.0, 5.6))
const BREAK := AABB(Vector3(8.2, -0.5, -8.8), Vector3(13.6, 4.0, 5.6))
## Every room and corridor, for ArtDress.explain_dark.
const DARK_CHECK := [
	ROOM, SERVER_B, SERVER_C, NOC, VAULT, BREAK,
	AABB(Vector3(-22, 0, 9), Vector3(44, 3, 4)), AABB(Vector3(-22, 0, -13), Vector3(44, 3, 4)),  # corridors
]


static func apply(level: LevelBase) -> void:
	var geo := level.geo
	var dress := ArtDress.dressing_root(level)
	var machine_floor := ArtPalette.surface("floor_tile", Color(0.72, 0.74, 0.76))
	var machine_ceiling := ArtPalette.surface("ceiling_tile", Color(0.8, 0.82, 0.84))
	var machine_wall := ArtPalette.surface("drywall", Color(0.78, 0.82, 0.86))
	var desk_top := ArtPalette.surface("laminate")
	ArtDress.reskin(geo, [
		{"names": ["Rack"], "mat": ArtPalette.surface("rack_front")},
		{"names": ["TermDesk"], "mat": ArtPalette.surface("laminate", Color(0.75, 0.75, 0.75))},
		{"names": ["StatusWall"], "mat": ArtPalette.flat(Color(0.06, 0.07, 0.08), 0.4)},
		{"names": ["CableShelf"], "mat": ArtPalette.flat(Color(0.42, 0.44, 0.46), 0.6, 0.2)},
		{"names": ["Counter"], "mat": ArtPalette.surface("laminate", Color(0.9, 0.88, 0.84))},
		{"names": ["Fridge"], "mat": ArtPalette.flat(Color(0.9, 0.9, 0.87), 0.35)},
		{"names": ["CoffeeMachine"], "mat": ArtPalette.flat(Color(0.12, 0.12, 0.13), 0.4, 0.3)},
		# Raised floor and painted block walls in the machine rooms...
		{"names": ["Floor"], "zone": ROOM, "mat": machine_floor},
		{"names": ["Floor"], "zone": SERVER_B, "mat": machine_floor},
		{"names": ["Floor"], "zone": SERVER_C, "mat": machine_floor},
		{"names": ["Ceiling"], "zone": ROOM, "mat": machine_ceiling},
		{"names": ["Ceiling"], "zone": SERVER_B, "mat": machine_ceiling},
		{"names": ["Ceiling"], "zone": SERVER_C, "mat": machine_ceiling},
		{"names": ["Wall_"], "zone": ROOM, "mat": machine_wall},
		{"names": ["Wall_"], "zone": SERVER_B, "mat": machine_wall},
		{"names": ["Wall_"], "zone": SERVER_C, "mat": machine_wall},
		# ...carpet in the operations room, bare concrete in the cable vault,
		# lino in the break room...
		{"names": ["Floor"], "zone": NOC, "mat": ArtPalette.surface("carpet", Color(0.85, 0.9, 1.0))},
		{"names": ["Floor", "Ceiling", "Wall_"], "zone": VAULT, "mat": ArtPalette.surface("concrete")},
		{"names": ["Floor"], "zone": BREAK, "mat": ArtPalette.surface("floor_tile", Color(0.95, 0.85, 0.72))},
		# ...and plain office corridors round them.
		{"names": ["Floor"], "mat": ArtPalette.surface("floor_tile", Color(0.85, 0.87, 0.88))},
		{"names": ["Ceiling"], "mat": ArtPalette.surface("ceiling_tile")},
		{"names": ["Wall_"], "mat": ArtPalette.surface("drywall")},
	])
	var legs := ArtPalette.flat(Color(0.3, 0.3, 0.31), 0.5, 0.6)
	for b in geo.get_children():
		if b is StaticBody3D and ArtDress._name_matches(b.name, ["NocDesk", "BreakTable", "PrinterDesk"]):
			ArtDress.table_look(b, desk_top, legs)

	_server_room_a(geo, dress)
	_corridors(geo, dress)
	_noc(geo, dress)
	_cable_vault(geo, dress)
	_server_room_b(dress)
	_break_room(geo, dress)
	_server_room_c(dress)

	ArtDress.link_light_panels(level)
	ArtMood.polish(level.environment)
	ArtDress.explain_dark(level, DARK_CHECK, 4.0)
	ArtSkyline.backdrop(level, "level_1")  # 14 floors up, for any window onto the outside
	var rourke: Node3D = level.get("rourke")
	if rourke:
		NpcLook.attach(rourke, CharacterLooks.rourke(), level.hud)


static func _server_room_a(geo: Node3D, dress: Node3D) -> void:
	# Cable trays over each row of racks.
	for x in [-3.8, 3.8]:
		ArtProps.cable_tray(dress, Vector3(x, 3.0, -1.5), 11.0)
	ArtProps.poster(dress, Vector3(2.4, 1.6, 8.79), 180,
		"SERVER ROOM A\n\nAUTHORIZED PERSONNEL ONLY\n\nEscort badge required\nafter 18:00.", Vector2(0.5, 0.6))
	# Spare-parts boxes in two far corners, out of the aisles.
	ArtProps.boxes(geo, Vector3(6.3, 0, 8.1), 0, 3)
	ArtProps.boxes(geo, Vector3(-6.3, 0, -8.2), 15, 2)
	ArtProps.fire_extinguisher(dress, Vector3(-6.89, 1.1, 6.0), -90)


static func _corridors(geo: Node3D, dress: Node3D) -> void:
	ArtDress.skirting(dress, Vector3(0, 0, 11), Vector3(44, 3, 4), [
		{"wall": "n", "at": 0.0, "width": 1.8}, {"wall": "n", "at": -14.5, "width": 1.4},
		{"wall": "n", "at": 14.5, "width": 1.4}, {"wall": "s", "at": 0.0, "width": Elevator.DOORWAY},
	])
	ArtDress.skirting(dress, Vector3(0, 0, -11), Vector3(44, 3, 4), [
		{"wall": "s", "at": 0.0, "width": 1.8}, {"wall": "s", "at": -12.0, "width": 1.4},
		{"wall": "s", "at": 12.0, "width": 1.4}, {"wall": "n", "at": -12.0, "width": 1.4},
		{"wall": "n", "at": 0.0, "width": Elevator.DOORWAY},
	])
	for x in [-8.0, 8.0]:
		ArtProps.fire_extinguisher(dress, Vector3(x, 1.1, 9.11), 180)
	for x in [-6.0, 6.0]:
		ArtProps.fire_extinguisher(dress, Vector3(x, 1.1, -9.11), 0)
	ArtProps.poster(dress, Vector3(4.0, 1.6, 9.11), 180,
		"MACHINE ROOMS\n\nNo food or drink past this point.\nKeep doors closed.\nReport alarms to the NOC.", Vector2(0.5, 0.65))
	ArtProps.poster(dress, Vector3(2.4, 1.5, -12.89), 180,
		"IN CASE OF FIRE\nDO NOT USE ELEVATOR\n\nUSE STAIRS", Vector2(0.5, 0.4), Color(0.93, 0.92, 0.86), 22)
	ArtProps.water_cooler(geo, Vector3(-21.5, 0, 12.3), -90)
	ArtProps.potted_plant(geo, Vector3(21.5, 0, 12.4))
	ArtProps.potted_plant(geo, Vector3(-21.5, 0, -12.4))


## The network operations room: desks facing the status screens, an operator's
## chair at each place but the one with the shift log.
static func _noc(geo: Node3D, dress: Node3D) -> void:
	ArtDress.trim(dress, Vector3(-18.5, 2.65, -2.84), Vector3(6.7, 0.08, 0.12), ArtPalette.flat(Color(0.2, 0.2, 0.22), 0.4, 0.5))
	for row in [1.0, 4.5]:
		for x in [-18.0, -15.0, -12.0]:
			if row == 4.5 and x == -15.0:
				continue  # the shift log lies here: room to stand and read it
			ArtProps.office_chair(geo, Vector3(x, 0, row + 0.8), (x + row) * 7.0)
			ArtProps.keyboard(dress, Vector3(x, 0.76, row + 0.15), 0)
	ArtProps.binder(dress, Vector3(-17.0, 0.76, 1.2), 15, "NOC RUNBOOK", false)
	ArtProps.poster(dress, Vector3(-11.0, 1.6, 8.89), 0,
		"ON-CALL\n\nNetwork: page 2210\nFacilities: ext. 4410\nSecurity desk: ext. 4000", Vector2(0.45, 0.6))
	ArtProps.potted_plant(geo, Vector3(-21.4, 0, 8.4))
	ArtProps.filing_cabinet(geo, Vector3(-21.4, 0, 6.6), -90)


## The cable vault: coils hung along the shelves (the spare one players take stays
## on its own shelf), a drum of cable on the floor, a tray overhead.
static func _cable_vault(geo: Node3D, dress: Node3D) -> void:
	var shelf := ArtPalette.flat(Color(0.3, 0.31, 0.33), 0.5, 0.5)
	for x in [-20.5, -17.5]:
		for y in [0.5, 1.0, 1.5, 2.0]:
			ArtDress.trim(dress, Vector3(x, y, -8.09), Vector3(2.4, 0.03, 0.02), shelf)
	var colors := [Color(0.85, 0.75, 0.15), Color(0.15, 0.3, 0.75), Color(0.75, 0.2, 0.15), Color(0.9, 0.9, 0.88)]
	for i in 4:
		ArtProps.cable_coil(dress, Vector3(-21.4 + i * 0.55, 1.95, -8.07), 0 + i * 9, colors[i])
		ArtProps.cable_coil(dress, Vector3(-21.4 + i * 0.55, 1.45, -8.07), 0 - i * 7, colors[(i + 2) % 4])
	for i in 3:
		ArtProps.cable_coil(dress, Vector3(-21.29, 1.95, -6.5 + i * 0.9), -90, colors[i])
	var spool := geo.get_node_or_null("Spool") as StaticBody3D
	if spool:
		for c in spool.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = false
		for x in [-19.0, -18.0]:
			ArtProps.cable_drum(dress, Vector3(x, 0, -5.0), 0, 0.4, 0.9)
	ArtProps.cable_tray(dress, Vector3(-15.0, 2.7, -6.0), 13.0, true)


static func _server_room_b(dress: Node3D) -> void:
	for z in [-1.0, 2.0, 5.0]:
		ArtProps.cable_tray(dress, Vector3(15.0, 3.2, z), 12.5, true)
	ArtProps.fire_extinguisher(dress, Vector3(21.89, 1.1, 7.5), 90)


## The break room: chairs round the table, cupboard doors on the counter, a fridge
## and a microwave. The coffee-fund note stays where it is on the counter.
static func _break_room(geo: Node3D, dress: Node3D) -> void:
	var shells := [Color(0.72, 0.45, 0.2), Color(0.28, 0.42, 0.55)]
	# Tucked in to the table (0 faces -Z, towards it from the south side), except
	# one someone pushed back and left turned away.
	ArtProps.cafe_chair(geo, Vector3(16.8, 0, -4.45), -4, shells[0])
	ArtProps.cafe_chair(geo, Vector3(18.2, 0, -4.45), 7, shells[1])
	ArtProps.cafe_chair(geo, Vector3(16.8, 0, -6.55), 176, shells[1])
	ArtProps.cafe_chair(geo, Vector3(18.35, 0, -6.85), 35, shells[0])
	var line := ArtPalette.flat(Color(0.45, 0.43, 0.4), 0.6)
	for z in [-7.0, -6.0, -5.0]:
		ArtDress.trim(dress, Vector3(20.99, 0.45, z), Vector3(0.01, 0.8, 0.01), line)  # cupboard door gaps
	ArtDress.trim(dress, Vector3(20.99, 0.8, -4.0), Vector3(0.01, 0.01, 0.78), line)  # fridge door
	ArtDress.trim(dress, Vector3(20.98, 1.2, -3.7), Vector3(0.02, 0.4, 0.03), ArtPalette.flat(Color(0.7, 0.7, 0.72), 0.3, 0.8))  # handle
	ArtProps.microwave(dress, Vector3(21.45, 0.9, -5.0), 90)
	ArtProps.poster(dress, Vector3(8.11, 1.6, -6.0), -90,
		"SAFETY FIRST\n\n214 days\nwithout a lost-time incident", Vector2(0.45, 0.6))


static func _server_room_c(dress: Node3D) -> void:
	ArtProps.dot_matrix_printer(dress, Vector3(-11.4, 0.76, -23.3), 180)
	ArtProps.boxes(dress, Vector3(-12.6, 0, -23.35), 0, 1)
	ArtProps.cable_tray(dress, Vector3(-12.0, 3.2, -19.0), 6.0)
