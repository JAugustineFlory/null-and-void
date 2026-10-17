class_name DressLevel1
extends RefCounted
## Furnishing for Level 1, Server Room A: a cold machine room that turns red when
## Rourke locks the door. Called once at the end of Level 1's build(), before
## navigation bakes. Positions are in the wing's own space; the World turns the
## whole wing, and the textures are mapped in world space so they still line up.

const ROOM := AABB(Vector3(-7.2, -0.5, -9.2), Vector3(14.4, 4.5, 18.4))


static func apply(level: LevelBase) -> void:
	var geo := level.geo
	var dress := ArtDress.dressing_root(level)
	ArtDress.reskin(geo, [
		{"names": ["Rack"], "mat": ArtPalette.surface("rack_front")},
		{"names": ["TermDesk"], "mat": ArtPalette.surface("laminate", Color(0.75, 0.75, 0.75))},
		# Raised floor and painted block walls in the machine room...
		{"names": ["Floor"], "zone": ROOM, "mat": ArtPalette.surface("floor_tile", Color(0.72, 0.74, 0.76))},
		{"names": ["Ceiling"], "zone": ROOM, "mat": ArtPalette.surface("ceiling_tile", Color(0.8, 0.82, 0.84))},
		{"names": ["Wall_"], "zone": ROOM, "mat": ArtPalette.surface("drywall", Color(0.78, 0.82, 0.86))},
		# ...bare concrete in the antechamber and the exit corridor.
		{"names": ["Floor", "Ceiling", "Wall_"], "mat": ArtPalette.surface("concrete")},
	])

	# Cable trays over each row of racks.
	for x in [-3.8, 3.8]:
		ArtProps.cable_tray(dress, Vector3(x, 3.0, -1.5), 11.0)
	ArtProps.poster(dress, Vector3(1.39, 1.6, 12.0), 90,
		"SERVER ROOM A\n\nAUTHORIZED PERSONNEL ONLY\n\nEscort badge required\nafter 18:00.", Vector2(0.5, 0.6))
	# Spare-parts boxes in two far corners, out of the aisles.
	ArtProps.boxes(geo, Vector3(6.3, 0, 8.3), 0, 3)
	ArtProps.boxes(geo, Vector3(-6.3, 0, -8.4), 15, 2)

	ArtDress.link_light_panels(level)
	var rourke: Node3D = level.get("rourke")
	if rourke:
		NpcLook.attach(rourke, CharacterLooks.rourke(), level.hud)
