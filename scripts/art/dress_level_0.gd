class_name DressLevel0
extends RefCounted
## Furnishing for Level 0, the ground floor: a normal, tidy 90s office at night.
## Nothing here should look wrong. Called once at the end of Level 0's build(),
## before navigation bakes, so solid props are part of the navmesh. All positions
## are in the wing's own space, placed from GroundFloor's rooms. The van is DressVan.

## Each room's zone, for its floor, walls and ceiling's look: its GroundFloor
## rectangle, from half a metre under the floor to `top`, pushed out (or, with a
## minus, pulled in) at its west, north, east and south walls. Room zones stop
## short of their walls, so a wall two rooms share takes the corridor's look.
static func zones() -> Dictionary:
	return {
		"lobby": _zone(GroundFloor.LOBBY, 4.5, 0.3, 0.3, 0.3, 0.3),
		"hall": _zone(GroundFloor.HALL, 3.5, 0.1, 0.2, 0.2, 0.2),
		"closet": _zone(GroundFloor.CLOSET, 3.5, 0.5, 0.5, 0.1, 0.5),
		"corridor": _zone(GroundFloor.CORRIDOR, 3.5, 0.2, 0.2, 0.2, 0.2),
		"mailroom": _zone(GroundFloor.MAILROOM, 3.5, -0.2, -0.2, -0.2, -0.2),
		"restrooms": _zone(GroundFloor.MENS.merge(GroundFloor.WOMENS), 3.5, -0.2, -0.2, -0.2, -0.2),
		"cafeteria": _zone(GroundFloor.CAFETERIA, 4.0, -0.2, -0.2, -0.2, -0.2),
		"it_closet": _zone(GroundFloor.IT_CLOSET, 3.5, -0.2, -0.2, -0.2, -0.2),
		"dark": _zone(GroundFloor.DARK.merge(GroundFloor.PASSAGE), 3.5, 0.0, 0.2, 0.2, -0.2),
		"lifts": _zone(GroundFloor.LIFT_HALL, 3.5, 0.1, 0.1, 0.1, 0.1),
	}


## Every room and corridor, one box each, for ArtDress.explain_dark.
static func dark_check() -> Array:
	var z := zones()
	return [
		z.lobby, z.hall, z.closet, z.corridor, z.mailroom, z.cafeteria, z.it_closet, z.lifts,
		GroundFloor.box(GroundFloor.MENS, GroundFloor.BACK_H), GroundFloor.box(GroundFloor.WOMENS, GroundFloor.BACK_H),
		GroundFloor.box(GroundFloor.DARK, GroundFloor.BACK_H), GroundFloor.box(GroundFloor.PASSAGE, GroundFloor.BACK_H),
	]


static func _zone(room: Rect2, top: float, west: float, north: float, east: float, south: float) -> AABB:
	return AABB(Vector3(room.position.x - west, -0.5, room.position.y - north), Vector3(room.size.x + west + east, top + 0.5, room.size.y + north + south))


static func apply(level: LevelBase) -> void:
	var geo := level.geo
	var dress := ArtDress.dressing_root(level)
	ground(geo, dress)
	ArtDress.reskin(geo, [
		# Car park and the building front
		{"names": ["Asphalt"], "mat": ArtPalette.surface("asphalt")},
		{"names": ["Facade"], "mat": ArtPalette.surface("concrete", Color(1.1, 1.05, 0.95))},
		{"names": ["Fence"], "mat": ArtPalette.flat(Color(0.18, 0.22, 0.19), 0.6, 0.5)},
		{"names": ["Canopy", "LampPost"], "mat": ArtPalette.flat(Color(0.28, 0.28, 0.3), 0.6, 0.3)},
	])
	# Car park: two staff cars, one in each side bay. The van has the middle.
	var van: Vector3 = level.VAN_AT
	ArtProps.car(geo, van + Vector3(-6, 0, 0), 0, Color(0.42, 0.12, 0.1))
	ArtProps.car(geo, van + Vector3(6, 0, 0), 0, Color(0.55, 0.62, 0.68))
	_tower(level, dress)
	DressVan.apply(level, van)
	# The sagging cable tray in the hall (the first crouch) sits outside geo.
	var tray := level.get("cable_tray") as Node3D
	if tray:
		ArtDress.reskin(tray.get_parent() as Node3D, [{"names": ["CableTray"], "mat": ArtPalette.surface("metal")}])

	ArtDress.link_light_panels(level)
	ArtKit.dress_stairwells(level)
	ArtMood.polish(level.environment)
	ArtDress.explain_dark(level, dark_check(), 3.6, [Vector3(GroundFloor.IT_HATCH.x, 0, GroundFloor.IT_HATCH.z)])  # the IT closet's ceiling panel stays bare
	var rourke: Node3D = level.get("rourke")
	if rourke:
		NpcLook.attach(rourke, CharacterLooks.rourke(), level.hud)


## The ground floor indoors (GroundFloor's rooms, under `geo`, in Level 0's
## coordinates): Level 0's, and Level 4's when the crew come back down to it.
## Solid props go in `geo`, the rest in `dress`, which stands where `geo` does.
static func ground(geo: Node3D, dress: Node3D) -> void:
	var drywall := ArtPalette.surface("drywall")
	var tiles := ArtPalette.surface("ceiling_tile")
	var concrete := ArtPalette.surface("concrete")
	var metal := ArtPalette.surface("metal")
	var lino := ArtPalette.surface("floor_tile", Color(1.0, 1.02, 1.02))
	var z := zones()
	ArtDress.reskin(geo, [
		# The rooms off the back corridor
		{"names": ["Floor"], "zone": z.restrooms, "mat": ArtPalette.surface("floor_tile", Color(1.25, 1.27, 1.28))},
		{"names": ["Floor"], "zone": z.mailroom, "mat": lino},
		{"names": ["Floor"], "zone": z.cafeteria, "mat": ArtPalette.surface("floor_tile", Color(0.95, 0.85, 0.72))},
		{"names": ["Floor"], "zone": z.it_closet, "mat": ArtPalette.surface("floor_tile", Color(0.62, 0.62, 0.62))},
		{"names": ["Floor"], "zone": z.lifts, "mat": ArtPalette.surface("floor_tile", Color(1.05, 0.98, 0.9))},
		{"names": ["Floor"], "zone": z.dark, "mat": ArtPalette.surface("floor_tile", Color(0.55, 0.56, 0.56))},
		{"names": ["Wall_"], "zone": z.dark, "mat": ArtPalette.surface("drywall", Color(0.7, 0.7, 0.68))},
		{"names": ["Pigeonholes"], "mat": ArtPalette.flat(Color(0.45, 0.32, 0.2), 0.7)},
		{"names": ["SortingTable", "CafTable"], "mat": ArtPalette.surface("laminate")},
		{"names": ["MailCart", "ServingCounter"], "mat": metal},
		{"names": ["SpareShelf"], "mat": ArtPalette.flat(Color(0.5, 0.52, 0.54), 0.6, 0.1)},
		{"names": ["Sinks"], "mat": ArtPalette.flat(Color(0.92, 0.92, 0.9), 0.2)},
		{"names": ["StallWall"], "mat": ArtPalette.flat(Color(0.55, 0.6, 0.6), 0.5, 0.2)},
		{"names": ["VendingMachine"], "mat": ArtPalette.flat(Color(0.2, 0.2, 0.22), 0.4, 0.3)},
		{"names": ["PatchPanel"], "mat": ArtPalette.surface("rack_front")},
		{"names": ["Crate"], "mat": ArtPalette.flat(Color(0.62, 0.48, 0.3), 0.9)},
		{"names": ["Floor"], "zone": z.corridor, "mat": lino},
		# Lobby
		{"names": ["Floor"], "zone": z.lobby, "mat": ArtPalette.surface("carpet")},
		{"names": ["Ceiling"], "zone": z.lobby, "mat": tiles},
		{"names": ["Wall_"], "zone": z.lobby, "mat": drywall},
		{"names": ["Desk", "Table"], "zone": z.lobby, "mat": ArtPalette.surface("laminate")},
		{"names": ["LostFound"], "zone": z.lobby, "mat": ArtPalette.surface("laminate", Color(0.8, 0.8, 0.8))},
		{"names": ["Partition"], "zone": z.lobby, "mat": ArtPalette.surface("partition")},
		{"names": ["Chair"], "zone": z.lobby, "mat": ArtPalette.flat(Color(0.36, 0.14, 0.16), 0.95)},  # maroon waiting-room fabric
		# Hall to Server Room A
		{"names": ["Floor"], "zone": z.hall, "mat": ArtPalette.surface("floor_tile")},
		{"names": ["Ceiling"], "zone": z.hall, "mat": tiles},
		{"names": ["Wall_"], "zone": z.hall, "mat": drywall},
		# The forgotten closet and its duct
		{"names": ["Floor", "Ceiling"], "zone": z.closet, "mat": concrete},
		{"names": ["Wall_"], "zone": z.closet, "mat": ArtPalette.surface("concrete", Color(1.0, 0.95, 0.85))},
		{"names": ["Shelf", "Vent"], "mat": metal},
		# Everything else indoors on this floor
		{"names": ["Ceiling"], "mat": tiles},
		{"names": ["Wall_"], "mat": drywall},
	])

	# Lobby: plants by the front doors, a water cooler, skirting and notices.
	var lobby := GroundFloor.LOBBY
	var desk := GroundFloor.DESK
	ArtProps.potted_plant(geo, Vector3(lobby.position.x + 0.7, 0, lobby.end.y - 0.7))
	ArtProps.potted_plant(geo, Vector3(lobby.end.x - 0.7, 0, lobby.end.y - 0.7))
	ArtProps.water_cooler(geo, Vector3(lobby.end.x - 0.5, 0, lobby.end.y - 1.4))
	ArtDress.skirting(dress, GroundFloor.mid(lobby), GroundFloor.span(lobby, GroundFloor.LOBBY_H), [
		GroundFloor.gap(lobby, "e", GroundFloor.HALL_Z, 2.0, 3.0),
		GroundFloor.gap(lobby, "s", GroundFloor.FRONT_AT.x, GroundFloor.FRONT_SIZE.x, GroundFloor.FRONT_SIZE.y),
	])
	# On the side walls, beside the desk.
	ArtProps.poster(dress, Vector3(lobby.position.x + 0.11, 1.8, desk.z - 2.0), -90,
		"HALCYON DATA SYSTEMS\n\nEMPLOYEE OF THE MONTH\n\nOctober\nDale Rourke, Facilities\n\"Always happy to help!\"")
	ArtProps.poster(dress, Vector3(lobby.end.x - 0.11, 1.8, desk.z - 2.0), 90,
		"WARDEN v3.1\n\nDoors, lights and climate,\nmanaged for you.\n\nWARDEN keeps you safe.")
	ArtProps.exit_sign(dress, Vector3(lobby.end.x - 0.12, 3.3, GroundFloor.HALL_Z), 90)

	# Behind reception: cabinets, the receptionist's chair, archive boxes.
	for x in [3.4, 3.9, 4.4]:
		ArtProps.filing_cabinet(geo, Vector3(desk.x + x, 0, lobby.position.y + 0.4), 180)
	ArtProps.sittable(ArtProps.office_chair(geo, Vector3(desk.x + 3.0, 0, desk.z - 0.9), 180), ArtProps.OFFICE_SEAT)
	ArtProps.boxes(geo, Vector3(desk.x - 4.3, 0, lobby.position.y + 0.5), 10, 2)

	# Hall: one more notice.
	ArtProps.poster(dress, Vector3(GroundFloor.PASSAGE_X - 3.0, 1.6, GroundFloor.HALL.position.y + 0.11), 180,
		"CLEAN DESK POLICY\n\nLock your screen.\nShred what you print.\nDon't share your PIN.", Vector2(0.5, 0.6))

	# Closet: forgotten archive boxes, clear of the duct and the shelf.
	ArtProps.boxes(geo, GroundFloor.at(GroundFloor.CLOSET, 4.4, 0, 0.6), 0, 3)
	ArtProps.boxes(geo, GroundFloor.at(GroundFloor.CLOSET, 3.6, 0, 5.4), 20, 2)

	var legs := ArtPalette.flat(Color(0.6, 0.61, 0.62), 0.3, 0.8)
	for b in geo.get_children():
		if b is StaticBody3D and ArtDress._name_matches(b.name, ["CafTable", "SortingTable"]):
			ArtDress.table_look(b, ArtPalette.surface("laminate"), legs)
	_ground_floor(geo, dress)


## Halcyon Tower over the lobby: from the car park it rises out of sight, thirty
## storeys of concrete and ribbon windows, a red light on its mast.
static func _tower(level: LevelBase, dress: Node3D) -> void:
	var sky := ArtSkyline.backdrop(level, "level_0")
	var roof := ArtSkyline.roof_height()
	# Set back a metre behind the front facade, which is 6 m tall.
	var w := GroundFloor.CORRIDOR.position.x - 0.6
	var e := GroundFloor.HALL.end.x + 0.2
	var front := GroundFloor.LOBBY.end.y - 0.75
	var back := GroundFloor.MAILROOM.position.y - 0.4
	var core := Vector2((w + e) / 2.0 + 0.2, (front + back) / 2.0 - 0.925)  # the plant room and mast, a little off centre
	ArtSkyline.facade(sky, PackedVector2Array([Vector2(e, back), Vector2(e, front), Vector2(w, front), Vector2(w, back), Vector2(e, back)]),
		ArtSkyline.LOBBY_H, roof, "Tower", true)
	var concrete := ArtPalette.surface("concrete", Color(0.8, 0.78, 0.74))
	ArtDress.trim(dress, Vector3((w + e) / 2.0, 6.05, front + 0.55), Vector3(e - w, 0.1, 1.2), concrete)  # the podium's roof, in front of the tower
	var plant := BoxMesh.new()
	plant.size = Vector3(12, 5, 10)
	ArtSkyline.piece(sky, plant, Vector3(core.x, roof + 2.5, core.y), Color(0.16, 0.16, 0.17), 0.0, "PlantRoom")
	var mast := BoxMesh.new()
	mast.size = Vector3(0.35, 14, 0.35)
	ArtSkyline.piece(sky, mast, Vector3(core.x, roof + 12, core.y), Color(0.2, 0.2, 0.21), 0.0, "Mast")
	ArtSkyline.beacon(sky, Vector3(core.x, roof + 19.3, core.y))
	var corners := [Vector2(w, front), Vector2(e, front), Vector2(w, back), Vector2(e, back)]
	for i in corners.size():
		var c: Vector2 = corners[i]
		var out := Vector2(signf(c.x - core.x) * 0.3, signf(c.y - core.y) * 0.3)
		ArtSkyline.beacon(sky, Vector3(c.x + out.x, roof + 0.7, c.y + out.y), true, 0.2 * i)
		if c.y == front:
			ArtSkyline.beacon(sky, Vector3(c.x + out.x, ArtSkyline.floor_height(15), c.y + out.y), false)


## The rest of the ground floor: the back corridor and the rooms off it, the dark
## east corridor and the elevator bank. Ordinary office life, nothing wrong yet.
static func _ground_floor(geo: Node3D, dress: Node3D) -> void:
	# Back corridor: skirting, an extinguisher, notices between the doors.
	var corridor := GroundFloor.CORRIDOR
	var lobby := GroundFloor.LOBBY
	var south_wall := corridor.end.y - 0.11
	ArtDress.skirting(dress, GroundFloor.mid(corridor), GroundFloor.span(corridor, GroundFloor.BACK_H), [
		GroundFloor.gap(corridor, "s", -GroundFloor.AISLE_X, 1.6, 2.6), GroundFloor.gap(corridor, "s", GroundFloor.AISLE_X, 1.6, 2.6),
		GroundFloor.gap(corridor, "e", GroundFloor.CORRIDOR_Z, 2.8, 3.0), GroundFloor.gap(corridor, "n", GroundFloor.MAILROOM_DOOR_X, 1.4, 2.2),
		GroundFloor.gap(corridor, "n", GroundFloor.MENS_DOOR_X, 1.4, 2.2), GroundFloor.gap(corridor, "n", GroundFloor.WOMENS_DOOR_X, 1.4, 2.2),
		GroundFloor.gap(corridor, "n", GroundFloor.CAFETERIA_DOOR_X, 2.4, 2.6), GroundFloor.gap(corridor, "n", GroundFloor.IT_DOOR_X, 1.4, 2.2),
	])
	ArtProps.fire_extinguisher(dress, Vector3(lobby.position.x - 6.0, 1.1, south_wall), 0)
	ArtProps.fire_extinguisher(dress, Vector3(lobby.end.x, 1.1, south_wall), 0)
	ArtProps.poster(dress, Vector3(corridor.position.x + 0.11, 1.6, GroundFloor.CORRIDOR_Z), -90,
		"IN CASE OF FIRE\n\nLeave by the nearest exit.\nDo not use the elevators.\nMeet in the car park.", Vector2(0.5, 0.65))
	ArtProps.poster(dress, Vector3(GroundFloor.DESK.x - 3.0, 1.6, south_wall), 0,
		"HALCYON SOFTBALL\n\nThursdays, 6pm\nRiverside Park\n\nAll welcome!", Vector2(0.45, 0.6), Color(0.96, 0.93, 0.8))
	ArtProps.water_cooler(geo, Vector3(corridor.position.x + 0.5, 0, corridor.end.y - 0.6), -90)

	# Mailroom: pigeonholes full of post, parcels on the table and the cart, a
	# corkboard of notices.
	var mail := GroundFloor.MAILROOM
	ArtProps.pigeonhole_front(dress, GroundFloor.at(mail, 3.5, 1.1, 0.7), 180, Vector2(5.5, 2.2), 12, 7)
	ArtProps.boxes(dress, GroundFloor.at(mail, 2.6, 0.9, 3.5), 12, 1)  # on the sorting table
	ArtProps.clipboard(dress, GroundFloor.at(mail, 4.4, 0.9, 3.8), -10, "MAIL LOG")
	for i in 3:
		ArtProps.memo(dress, GroundFloor.at(mail, 3.6 + i * 0.07, 0.902 + i * 0.002, 3.3 + i * 0.03), 8 - i * 9, "", true)
	ArtProps.boxes(dress, GroundFloor.at(mail, 1.0, 1.0, 5.8), 80, 2)  # on the cart
	var board := ArtProps.corkboard(dress, GroundFloor.at(mail, mail.size.x - 0.11, 1.6, 4.0), 90, Vector2(1.3, 0.9))
	ArtProps.memo(board, Vector3(-0.35, 0.05, -0.017), 0, "OUTGOING MAIL\nleaves at 4:30")
	ArtProps.memo(board, Vector3(0.25, 0.1, -0.017), 0, "FEDEX ACCOUNT #\nask reception")
	ArtProps.sticky_note(board, Vector3(0.5, -0.25, -0.017), 0, "stamps in top drawer", ArtProps.STICKY_COLORS[1])

	# Restrooms: tiled to shoulder height, a mirror and dryer by the sinks, a
	# toilet in each stall.
	var tile := ArtPalette.surface("floor_tile", Color(1.3, 1.33, 1.34))
	for room in [GroundFloor.MENS, GroundFloor.WOMENS]:
		ArtDress.skirting(dress, GroundFloor.mid(room), GroundFloor.span(room, GroundFloor.BACK_H), [GroundFloor.gap(room, "s", GroundFloor.mid(room).x, 1.4, 2.2)], 1.5, tile)
		ArtProps.restroom_mirror(dress, GroundFloor.at(room, 0.11, 1.5, 5.7), -90, 0.5)
		ArtProps.hand_dryer(dress, GroundFloor.at(room, room.size.x - 0.11, 1.2, 7.0), 90)
		for south in [2.8, 1.1]:  # one in each stall
			ArtProps.toilet(dress, GroundFloor.at(room, 2.55, 0, south), 90)
	ArtProps.wet_floor_sign(dress, GroundFloor.at(GroundFloor.WOMENS, 2.0, 0, 5.4), 30)

	# Cafeteria: chairs on the tables' outer sides (the gaps between rows stay
	# open to hop through), fronts on the vending machines, the counter set up
	# for the morning, and the staff noticeboard.
	var shells := [Color(0.72, 0.45, 0.2), Color(0.28, 0.42, 0.55), Color(0.62, 0.22, 0.18)]
	var n := 0
	var cafe := GroundFloor.CAFETERIA
	var rows: Array = GroundFloor.CAFE_TABLES_Z
	for tx in GroundFloor.CAFE_TABLES_X:
		for sx in [-0.5, 0.5]:
			ArtProps.sittable(ArtProps.cafe_chair(geo, Vector3(tx + sx, 0, rows[0] + 0.65), (n % 3 - 1) * 6, shells[n % 3]), ArtProps.CAFE_SEAT)
			ArtProps.sittable(ArtProps.cafe_chair(geo, Vector3(tx + sx, 0, rows[1] - 0.65), 180 + (n % 3 - 1) * 5, shells[(n + 1) % 3]), ArtProps.CAFE_SEAT)
			n += 1
	var vending := GroundFloor.VENDING_AT + Vector3(-0.455, 0, 0)  # the coffee machine's front
	ArtProps.vending_front(dress, vending, 90, Vector2(0.8, 1.8), Color(0.18, 0.28, 0.5), true)
	ArtProps.vending_front(dress, vending + Vector3(0, 0, -1.2), 90, Vector2(0.8, 1.8), Color(0.55, 0.12, 0.1))
	# The serving counter, along the north wall.
	ArtProps.microwave(dress, GroundFloor.at(cafe, 4.2, 1.0, 0.5), 180)
	ArtProps.microwave(dress, GroundFloor.at(cafe, 4.8, 1.0, 0.5), 180)
	ArtDress.trim(dress, GroundFloor.at(cafe, 7.5, 1.01, 0.6), Vector3(8.04, 0.02, 0.94), ArtPalette.flat(Color(0.75, 0.76, 0.77), 0.3, 0.8))  # steel top
	var guard := ArtPalette.glass(Color(0.6, 0.7, 0.72))
	ArtDress.trim(dress, GroundFloor.at(cafe, 9.0, 1.35, 1.0), Vector3(4.0, 0.5, 0.01), guard)  # sneeze guard
	ArtProps.poster(dress, GroundFloor.at(cafe, 7.5, 2.5, 0.11), 180,
		"TODAY\n\nSoup of the day  1.50\nTuna melt  2.75\nChef salad  3.25\nCoffee  .50", Vector2(1.4, 0.8))
	var cafe_board := ArtProps.corkboard(dress, GroundFloor.at(cafe, 2.5, 1.6, cafe.size.y - 0.11), 0, Vector2(1.4, 0.9))
	ArtProps.memo(cafe_board, Vector3(-0.4, 0.05, -0.017), 0, "PLEASE LABEL FOOD\nin the fridge")
	ArtProps.memo(cafe_board, Vector3(0.15, 0.08, -0.017), 0, "FIRE DRILL\nFriday 10am")
	ArtProps.clipboard(cafe_board, Vector3(0.5, -0.05, -0.02), 0, "POTLUCK SIGN-UP", false)
	ArtProps.potted_plant(geo, GroundFloor.at(cafe, 0.6, 0, cafe.size.y - 0.6))

	# IT closet: shelving on the spares rack, boxed spares and an old monitor,
	# the patch panel's port rows. The ceiling panel stays as it is: nothing
	# here points at it.
	var shelf := ArtPalette.flat(Color(0.3, 0.31, 0.33), 0.4, 0.7)
	var it := GroundFloor.IT_CLOSET
	for y in [0.4, 0.9, 1.4, 1.9]:
		ArtDress.trim(dress, GroundFloor.at(it, 0.71, y, 2.0), Vector3(0.02, 0.03, 3.4), shelf)
	ArtProps.crt_monitor(dress, GroundFloor.at(it, 0.4, 2.0, 3.0), -90, "off")
	ArtProps.boxes(dress, GroundFloor.at(it, 0.4, 2.0, 1.4), -90, 1)
	for y in [1.0, 1.2, 1.4, 1.6]:
		ArtDress.trim(dress, GroundFloor.at(it, 3.545, y, 1.5), Vector3(0.01, 0.05, 1.4), ArtPalette.flat(Color(0.25, 0.27, 0.3), 0.5))
		for k in 6:  # a link light here and there
			ArtDress.trim(dress, GroundFloor.at(it, 3.538, y + 0.012, 0.9 + k * 0.23 + float((k + int(y * 10.0)) % 3) * 0.04), Vector3(0.004, 0.008, 0.012), ArtPalette.glow(Color(0.2, 1.0, 0.35), 0.8))
	ArtProps.clipboard(dress, GroundFloor.at(it, it.size.x - 0.11, 1.5, 3.1), 90, "EQUIPMENT SIGN-OUT", false)

	# The dark east corridor: stacked spare chairs and boxes against the walls,
	# a sign someone knocked over. Left mostly bare.
	ArtProps.boxes(geo, GroundFloor.at(GroundFloor.DARK, 2.0, 0, 0.45), 5, 3)
	ArtProps.boxes(geo, GroundFloor.at(GroundFloor.DARK, 2.6, 0, 0.45), -8, 2)
	ArtProps.wet_floor_sign(dress, GroundFloor.at(GroundFloor.PASSAGE, 0.6, 0, 1.0), 70, true)
	# Its one fitting is dead, the diffuser hanging: why nobody's lit it.
	for c in geo.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).position.distance_to(GroundFloor.DEAD_LIGHT) < 0.05:
			c.visible = false
	ArtProps.dead_troffer(dress, Vector3(GroundFloor.DEAD_LIGHT.x, GroundFloor.BACK_H, GroundFloor.DEAD_LIGHT.z), 0.0, true)

	# Elevator bank: plants either side, a bin and a fire notice by the doors.
	var lifts := GroundFloor.LIFT_HALL
	ArtProps.potted_plant(geo, GroundFloor.at(lifts, lifts.size.x - 0.6, 0, 0.6))
	ArtProps.potted_plant(geo, GroundFloor.at(lifts, lifts.size.x - 0.6, 0, lifts.size.y - 0.6))
	ArtProps.poster(dress, Vector3(lifts.end.x - 0.11, 1.5, GroundFloor.LIFT_AT.z + 2.0), 90,
		"IN CASE OF FIRE\nDO NOT USE ELEVATOR\n\nUSE STAIRS", Vector2(0.5, 0.4), Color(0.93, 0.92, 0.86), 22)
	ArtDress.skirting(dress, GroundFloor.mid(lifts), GroundFloor.span(lifts, GroundFloor.LIFT_HALL_H), [
		GroundFloor.gap(lifts, "w", GroundFloor.HALL_Z, 1.8, 2.4), GroundFloor.gap(lifts, "e", GroundFloor.LIFT_AT.z, Elevator.DOORWAY, Elevator.DOOR_H),
	])
