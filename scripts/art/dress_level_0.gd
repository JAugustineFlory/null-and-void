class_name DressLevel0
extends RefCounted
## Furnishing for Level 0, the lobby wing: a normal, tidy 90s office at night.
## Nothing here should look wrong. Called once at the end of Level 0's build(),
## before navigation bakes, so solid props are part of the navmesh. All positions
## are in the wing's own space. The van is left alone until its six-seat rework.

const LOBBY := AABB(Vector3(-8.3, -0.5, -7.3), Vector3(16.6, 5.0, 14.6))
const HALL := AABB(Vector3(7.9, -0.5, 1.8), Vector3(16.3, 4.0, 2.4))
const CLOSET := AABB(Vector3(-20.5, -0.5, 0.5), Vector3(6.6, 4.0, 7.0))


static func apply(level: LevelBase) -> void:
	var geo := level.geo
	var dress := ArtDress.dressing_root(level)
	var drywall := ArtPalette.surface("drywall")
	var tiles := ArtPalette.surface("ceiling_tile")
	var concrete := ArtPalette.surface("concrete")
	var metal := ArtPalette.surface("metal")
	ArtDress.reskin(geo, [
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

	ArtDress.link_light_panels(level)
	var rourke: Node3D = level.get("rourke")
	if rourke:
		NpcLook.attach(rourke, CharacterLooks.rourke(), level.hud)
