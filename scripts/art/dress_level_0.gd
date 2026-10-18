class_name DressLevel0
extends RefCounted
## Furnishing for Level 0, the ground floor: a normal, tidy 90s office at night.
## Nothing here should look wrong. Called once at the end of Level 0's build(),
## before navigation bakes, so solid props are part of the navmesh. All positions
## are in the wing's own space. The van is DressVan.

const LOBBY := AABB(Vector3(-8.3, -0.5, -7.3), Vector3(16.6, 5.0, 14.6))
const HALL := AABB(Vector3(7.9, -0.5, 1.8), Vector3(16.3, 4.0, 2.4))
const CLOSET := AABB(Vector3(-20.5, -0.5, 0.5), Vector3(6.6, 4.0, 7.0))
# The rest of the ground floor (Level 0's _build_ground_floor). Room zones stop
# short of their walls, so a wall two rooms share takes the corridor's look.
const CORRIDOR := AABB(Vector3(-20.2, -0.5, -10.2), Vector3(32.4, 4.0, 3.4))
const MAILROOM := AABB(Vector3(-19.8, -0.5, -17.8), Vector3(6.6, 4.0, 7.6))
const RESTROOMS := AABB(Vector3(-12.8, -0.5, -17.8), Vector3(5.6, 4.0, 7.6))
const CAFETERIA := AABB(Vector3(-6.8, -0.5, -17.8), Vector3(14.6, 4.5, 7.6))
const IT_CLOSET := AABB(Vector3(8.2, -0.5, -13.8), Vector3(3.6, 4.0, 3.6))
const DARK := AABB(Vector3(12.0, -0.5, -10.2), Vector3(7.2, 4.0, 12.0))
const LIFTS := AABB(Vector3(23.9, -0.5, -1.1), Vector3(6.2, 4.0, 8.2))


static func apply(level: LevelBase) -> void:
	var geo := level.geo
	var dress := ArtDress.dressing_root(level)
	var drywall := ArtPalette.surface("drywall")
	var tiles := ArtPalette.surface("ceiling_tile")
	var concrete := ArtPalette.surface("concrete")
	var metal := ArtPalette.surface("metal")
	var lino := ArtPalette.surface("floor_tile", Color(1.0, 1.02, 1.02))
	ArtDress.reskin(geo, [
		# The rooms off the back corridor
		{"names": ["Floor"], "zone": RESTROOMS, "mat": ArtPalette.surface("floor_tile", Color(1.25, 1.27, 1.28))},
		{"names": ["Floor"], "zone": MAILROOM, "mat": lino},
		{"names": ["Floor"], "zone": CAFETERIA, "mat": ArtPalette.surface("floor_tile", Color(0.95, 0.85, 0.72))},
		{"names": ["Floor"], "zone": IT_CLOSET, "mat": ArtPalette.surface("floor_tile", Color(0.62, 0.62, 0.62))},
		{"names": ["Floor"], "zone": LIFTS, "mat": ArtPalette.surface("floor_tile", Color(1.05, 0.98, 0.9))},
		{"names": ["Floor"], "zone": DARK, "mat": ArtPalette.surface("floor_tile", Color(0.55, 0.56, 0.56))},
		{"names": ["Wall_"], "zone": DARK, "mat": ArtPalette.surface("drywall", Color(0.7, 0.7, 0.68))},
		{"names": ["Pigeonholes"], "mat": ArtPalette.flat(Color(0.45, 0.32, 0.2), 0.7)},
		{"names": ["SortingTable", "CafTable"], "mat": ArtPalette.surface("laminate")},
		{"names": ["MailCart", "ServingCounter"], "mat": metal},
		{"names": ["SpareShelf"], "mat": ArtPalette.flat(Color(0.5, 0.52, 0.54), 0.6, 0.1)},
		{"names": ["Sinks"], "mat": ArtPalette.flat(Color(0.92, 0.92, 0.9), 0.2)},
		{"names": ["StallWall"], "mat": ArtPalette.flat(Color(0.55, 0.6, 0.6), 0.5, 0.2)},
		{"names": ["VendingMachine"], "mat": ArtPalette.flat(Color(0.2, 0.2, 0.22), 0.4, 0.3)},
		{"names": ["PatchPanel"], "mat": ArtPalette.surface("rack_front")},
		{"names": ["Crate"], "mat": ArtPalette.flat(Color(0.62, 0.48, 0.3), 0.9)},
		{"names": ["Floor"], "zone": CORRIDOR, "mat": lino},
		# Lobby
		{"names": ["Floor"], "zone": LOBBY, "mat": ArtPalette.surface("carpet")},
		{"names": ["Ceiling"], "zone": LOBBY, "mat": tiles},
		{"names": ["Wall_"], "zone": LOBBY, "mat": drywall},
		{"names": ["Desk", "Table"], "zone": LOBBY, "mat": ArtPalette.surface("laminate")},
		{"names": ["LostFound"], "zone": LOBBY, "mat": ArtPalette.surface("laminate", Color(0.8, 0.8, 0.8))},
		{"names": ["Partition"], "zone": LOBBY, "mat": ArtPalette.surface("partition")},
		{"names": ["Chair"], "zone": LOBBY, "mat": ArtPalette.flat(Color(0.36, 0.14, 0.16), 0.95)},  # maroon waiting-room fabric
		# Hall to Server Room A
		{"names": ["Floor"], "zone": HALL, "mat": ArtPalette.surface("floor_tile")},
		{"names": ["Ceiling"], "zone": HALL, "mat": tiles},
		{"names": ["Wall_"], "zone": HALL, "mat": drywall},
		# The forgotten closet and its duct
		{"names": ["Floor", "Ceiling"], "zone": CLOSET, "mat": concrete},
		{"names": ["Wall_"], "zone": CLOSET, "mat": ArtPalette.surface("concrete", Color(1.0, 0.95, 0.85))},
		{"names": ["Shelf", "Vent"], "mat": metal},
		# Car park and the building front
		{"names": ["Asphalt"], "mat": ArtPalette.surface("asphalt")},
		{"names": ["Facade"], "mat": ArtPalette.surface("concrete", Color(1.1, 1.05, 0.95))},
		{"names": ["Fence"], "mat": ArtPalette.flat(Color(0.18, 0.22, 0.19), 0.6, 0.5)},
		{"names": ["Canopy", "LampPost"], "mat": ArtPalette.flat(Color(0.28, 0.28, 0.3), 0.6, 0.3)},
		# Everything else indoors on this floor
		{"names": ["Ceiling"], "mat": tiles},
		{"names": ["Wall_"], "mat": drywall},
	])

	# Lobby: plants by the front doors, a water cooler, skirting and notices.
	ArtProps.potted_plant(geo, Vector3(-7.3, 0, 6.3))
	ArtProps.potted_plant(geo, Vector3(7.3, 0, 6.3))
	ArtProps.water_cooler(geo, Vector3(7.5, 0, 5.6))
	ArtDress.skirting(dress, Vector3.ZERO, Vector3(16, 4, 14), [
		{"wall": "e", "at": 3.0, "width": 2.0},
		{"wall": "s", "at": 0.0, "width": 3.2},
	])
	ArtProps.poster(dress, Vector3(-7.89, 1.8, -3.0), -90,
		"HALCYON DATA SYSTEMS\n\nEMPLOYEE OF THE MONTH\n\nOctober\nDale Rourke, Facilities\n\"Always happy to help!\"")
	ArtProps.poster(dress, Vector3(7.89, 1.8, -3.0), 90,
		"WARDEN v3.1\n\nDoors, lights and climate,\nmanaged for you.\n\nWARDEN keeps you safe.")
	ArtProps.exit_sign(dress, Vector3(7.88, 3.3, 3.0), 90)

	# Behind reception: cabinets, the receptionist's chair, archive boxes.
	for x in [3.4, 3.9, 4.4]:
		ArtProps.filing_cabinet(geo, Vector3(x, 0, -6.6), 180)
	ArtProps.office_chair(geo, Vector3(3.0, 0, -1.9), 180)
	ArtProps.boxes(geo, Vector3(-4.3, 0, -6.5), 10, 2)

	# Hall: one more notice.
	ArtProps.poster(dress, Vector3(15.0, 1.6, 2.11), 180,
		"CLEAN DESK POLICY\n\nLock your screen.\nShred what you print.\nDon't share your PIN.", Vector2(0.5, 0.6))

	# Closet: forgotten archive boxes, clear of the duct and the shelf.
	ArtProps.boxes(geo, Vector3(-15.6, 0, 1.6), 0, 3)
	ArtProps.boxes(geo, Vector3(-16.4, 0, 6.4), 20, 2)

	# Car park: two staff cars, one in each side bay. The van has the middle.
	ArtProps.car(geo, Vector3(-4, 0, 16.6), 0, Color(0.42, 0.12, 0.1))
	ArtProps.car(geo, Vector3(8, 0, 16.6), 0, Color(0.55, 0.62, 0.68))

	var legs := ArtPalette.flat(Color(0.6, 0.61, 0.62), 0.3, 0.8)
	for b in geo.get_children():
		if b is StaticBody3D and ArtDress._name_matches(b.name, ["CafTable", "SortingTable"]):
			ArtDress.table_look(b, ArtPalette.surface("laminate"), legs)
	_ground_floor(geo, dress)
	DressVan.apply(level, Vector3(2, 0, 16.6))
	# The sagging cable tray in the hall (the first crouch) sits outside geo.
	var tray := level.get("cable_tray") as Node3D
	if tray:
		ArtDress.reskin(tray.get_parent() as Node3D, [{"names": ["CableTray"], "mat": metal}])

	ArtDress.link_light_panels(level)
	var rourke: Node3D = level.get("rourke")
	if rourke:
		NpcLook.attach(rourke, CharacterLooks.rourke(), level.hud)


## The rest of the ground floor: the back corridor and the rooms off it, the dark
## east corridor and the elevator bank. Ordinary office life, nothing wrong yet.
static func _ground_floor(geo: Node3D, dress: Node3D) -> void:
	# Back corridor: skirting, an extinguisher, notices between the doors.
	ArtDress.skirting(dress, Vector3(-4, 0, -8.5), Vector3(32, 3, 3), [
		{"wall": "s", "at": -2.5, "width": 1.6}, {"wall": "s", "at": 10.5, "width": 1.6},
		{"wall": "e", "at": 0.0, "width": 2.8}, {"wall": "n", "at": -12.5, "width": 1.4},
		{"wall": "n", "at": -7.5, "width": 1.4}, {"wall": "n", "at": -4.5, "width": 1.4},
		{"wall": "n", "at": 4.0, "width": 2.4}, {"wall": "n", "at": 14.0, "width": 1.4},
	])
	ArtProps.fire_extinguisher(dress, Vector3(-14.0, 1.1, -7.11), 0)
	ArtProps.fire_extinguisher(dress, Vector3(8.0, 1.1, -7.11), 0)
	ArtProps.poster(dress, Vector3(-19.89, 1.6, -8.5), -90,
		"IN CASE OF FIRE\n\nLeave by the nearest exit.\nDo not use the elevators.\nMeet in the car park.", Vector2(0.5, 0.65))
	ArtProps.poster(dress, Vector3(-3.0, 1.6, -7.11), 0,
		"HALCYON SOFTBALL\n\nThursdays, 6pm\nRiverside Park\n\nAll welcome!", Vector2(0.45, 0.6), Color(0.96, 0.93, 0.8))
	ArtProps.water_cooler(geo, Vector3(-19.5, 0, -7.6), -90)

	# Mailroom: pigeonholes full of post, parcels on the table and the cart, a
	# corkboard of notices.
	ArtProps.pigeonhole_front(dress, Vector3(-16.5, 1.1, -17.3), 180, Vector2(5.5, 2.2), 12, 7)
	ArtProps.boxes(dress, Vector3(-17.4, 0.9, -14.5), 12, 1)
	ArtProps.clipboard(dress, Vector3(-15.6, 0.9, -14.2), -10, "MAIL LOG")
	for i in 3:
		ArtProps.memo(dress, Vector3(-16.4 + i * 0.07, 0.902 + i * 0.002, -14.7 + i * 0.03), 8 - i * 9, "", true)
	ArtProps.boxes(dress, Vector3(-19.0, 1.0, -12.2), 80, 2)
	var board := ArtProps.corkboard(dress, Vector3(-13.11, 1.6, -14.0), 90, Vector2(1.3, 0.9))
	ArtProps.memo(board, Vector3(-0.35, 0.05, -0.017), 0, "OUTGOING MAIL\nleaves at 4:30")
	ArtProps.memo(board, Vector3(0.25, 0.1, -0.017), 0, "FEDEX ACCOUNT #\nask reception")
	ArtProps.sticky_note(board, Vector3(0.5, -0.25, -0.017), 0, "stamps in top drawer", ArtProps.STICKY_COLORS[1])

	# Restrooms: tiled to shoulder height, a mirror and dryer by the sinks, a
	# toilet in each stall.
	var tile := ArtPalette.surface("floor_tile", Color(1.3, 1.33, 1.34))
	for r in [-11.5, -8.5]:
		ArtDress.skirting(dress, Vector3(r, 0, -14), Vector3(3, 3, 8), [{"wall": "s", "at": 0.0, "width": 1.4}], 1.5, tile)
		ArtProps.restroom_mirror(dress, Vector3(r - 1.39, 1.5, -12.3), -90, 0.5)
		ArtProps.hand_dryer(dress, Vector3(r + 1.39, 1.2, -11.0), 90)
		for z in [-15.2, -16.9]:
			ArtProps.toilet(dress, Vector3(r + 1.05, 0, z), 90)
	ArtProps.wet_floor_sign(dress, Vector3(-8.0, 0, -12.6), 30)

	# Cafeteria: chairs on the tables' outer sides (the gaps between rows stay
	# open to hop through), fronts on the vending machines, the counter set up
	# for the morning, and the staff noticeboard.
	var shells := [Color(0.72, 0.45, 0.2), Color(0.28, 0.42, 0.55), Color(0.62, 0.22, 0.18)]
	var n := 0
	for tx in [-4.0, 0.0, 4.0]:
		for sx in [-0.5, 0.5]:
			ArtProps.cafe_chair(geo, Vector3(tx + sx, 0, -11.85), (n % 3 - 1) * 6, shells[n % 3])
			ArtProps.cafe_chair(geo, Vector3(tx + sx, 0, -15.65), 180 + (n % 3 - 1) * 5, shells[(n + 1) % 3])
			n += 1
	ArtProps.vending_front(dress, Vector3(6.945, 0.9, -12.0), 90, Vector2(0.8, 1.8), Color(0.18, 0.28, 0.5), true)
	ArtProps.vending_front(dress, Vector3(6.945, 0.9, -13.2), 90, Vector2(0.8, 1.8), Color(0.55, 0.12, 0.1))
	ArtProps.microwave(dress, Vector3(-2.8, 1.0, -17.5), 180)
	ArtProps.microwave(dress, Vector3(-2.2, 1.0, -17.5), 180)
	ArtDress.trim(dress, Vector3(0.5, 1.01, -17.4), Vector3(8.04, 0.02, 0.94), ArtPalette.flat(Color(0.75, 0.76, 0.77), 0.3, 0.8))  # steel top
	var guard := ArtPalette.glass(Color(0.6, 0.7, 0.72))
	ArtDress.trim(dress, Vector3(2.0, 1.35, -17.0), Vector3(4.0, 0.5, 0.01), guard)  # sneeze guard
	ArtProps.poster(dress, Vector3(0.5, 2.5, -17.89), 180,
		"TODAY\n\nSoup of the day  1.50\nTuna melt  2.75\nChef salad  3.25\nCoffee  .50", Vector2(1.4, 0.8))
	var cafe_board := ArtProps.corkboard(dress, Vector3(-4.5, 1.6, -10.11), 0, Vector2(1.4, 0.9))
	ArtProps.memo(cafe_board, Vector3(-0.4, 0.05, -0.017), 0, "PLEASE LABEL FOOD\nin the fridge")
	ArtProps.memo(cafe_board, Vector3(0.15, 0.08, -0.017), 0, "FIRE DRILL\nFriday 10am")
	ArtProps.clipboard(cafe_board, Vector3(0.5, -0.05, -0.02), 0, "POTLUCK SIGN-UP", false)
	ArtProps.potted_plant(geo, Vector3(-6.4, 0, -10.6))

	# IT closet: shelving on the spares rack, boxed spares and an old monitor,
	# the patch panel's port rows. The ceiling panel stays as it is: nothing
	# here points at it.
	var shelf := ArtPalette.flat(Color(0.3, 0.31, 0.33), 0.4, 0.7)
	for y in [0.4, 0.9, 1.4, 1.9]:
		ArtDress.trim(dress, Vector3(8.71, y, -12.0), Vector3(0.02, 0.03, 3.4), shelf)
	ArtProps.crt_monitor(dress, Vector3(8.4, 2.0, -11.0), -90, "off")
	ArtProps.boxes(dress, Vector3(8.4, 2.0, -12.6), -90, 1)
	for y in [1.0, 1.2, 1.4, 1.6]:
		ArtDress.trim(dress, Vector3(11.545, y, -12.5), Vector3(0.01, 0.05, 1.4), ArtPalette.flat(Color(0.25, 0.27, 0.3), 0.5))
		for k in 6:  # a link light here and there
			ArtDress.trim(dress, Vector3(11.538, y + 0.012, -13.1 + k * 0.23 + float((k + int(y * 10.0)) % 3) * 0.04), Vector3(0.004, 0.008, 0.012), ArtPalette.glow(Color(0.2, 1.0, 0.35), 0.8))
	ArtProps.clipboard(dress, Vector3(11.89, 1.5, -10.9), 90, "EQUIPMENT SIGN-OUT", false)

	# The dark east corridor: stacked spare chairs and boxes against the walls,
	# a sign someone knocked over. Left mostly bare.
	ArtProps.boxes(geo, Vector3(14.0, 0, -9.55), 5, 3)
	ArtProps.boxes(geo, Vector3(14.6, 0, -9.55), -8, 2)
	ArtProps.wet_floor_sign(dress, Vector3(17.6, 0, -6.0), 70, true)

	# Elevator bank: plants either side, a bin and a fire notice by the doors.
	ArtProps.potted_plant(geo, Vector3(29.4, 0, -0.4))
	ArtProps.potted_plant(geo, Vector3(29.4, 0, 6.4))
	ArtProps.poster(dress, Vector3(29.89, 1.5, 5.0), 90,
		"IN CASE OF FIRE\nDO NOT USE ELEVATOR\n\nUSE STAIRS", Vector2(0.4, 0.4))
	ArtDress.skirting(dress, Vector3(27, 0, 3), Vector3(6, 3.2, 8), [
		{"wall": "w", "at": 0.0, "width": 1.8}, {"wall": "e", "at": 0.0, "width": Elevator.DOORWAY},
	])
