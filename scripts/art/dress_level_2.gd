class_name DressLevel2
extends RefCounted
## Furnishing for Level 2, the security floor: an institutional floor of painted
## block and lino, carpet where the guards sit, and Secure Lab B's clean white.
## Called once at the end of Level 2's build(), before navigation bakes.
##
## Nothing added here collides. The Watcher moves only while nobody can see it,
## and what blocks a line of sight or a path is part of that puzzle, so every
## prop is visual only (ArtDress.visual_only) and stands against a wall or in
## the footprint of a Greybox block that is already there. The vent and the
## ledge get nothing that points at them.

const LANDING := AABB(Vector3(2.6, -0.5, 6.1), Vector3(2.8, 4.0, 3.8))
const OFFICE := AABB(Vector3(-5.9, -0.5, -7.9), Vector3(11.8, 4.0, 9.8))
const RECEPTION := AABB(Vector3(-7.9, -0.5, 6.1), Vector3(10.3, 4.0, 3.8))
const CAMERA_ROOM := AABB(Vector3(-7.7, -0.5, -19.9), Vector3(4.6, 4.0, 4.8))
const LAB := AABB(Vector3(-15.9, -0.5, -3.9), Vector3(5.8, 4.5, 7.8))
const SERVICE := AABB(Vector3(-18.2, -0.5, -18.2), Vector3(4.2, 4.0, 28.4))
## Every room and corridor, for ArtDress.explain_dark.
const DARK_CHECK := [
	LANDING, OFFICE, RECEPTION, CAMERA_ROOM, LAB,
	AABB(Vector3(-18, 0, -16), Vector3(2, 3, 24)),  # service passage (SERVICE also takes in the lab's wall)
	AABB(Vector3(-6, 0, 2), Vector3(12, 3, 4)),  # corridor
	AABB(Vector3(-2.5, 0, -12), Vector3(5, 3, 4)), AABB(Vector3(-2, 0, -17), Vector3(4, 3, 5)),  # vestibule, elevator lobby
	AABB(Vector3(-10, 0, -18), Vector3(2, 3, 28)),  # patrol corridor
	AABB(Vector3(-18, 0, 8), Vector3(8, 3, 2)), AABB(Vector3(-18, 0, -18), Vector3(8, 3, 2)),  # the passages round the lab
	AABB(Vector3(-16, 0, 4.2), Vector3(6, 3, 3.6)), AABB(Vector3(-16, 0, -9.8), Vector3(6, 3, 5.6)),  # interview, briefing
	AABB(Vector3(-16, 0, -15.8), Vector3(6, 3, 5.6)),  # lockers
]


static func apply(level: LevelBase) -> void:
	var geo := level.geo
	var dress := ArtDress.dressing_root(level)
	var carpet := ArtPalette.surface("carpet", Color(0.75, 0.85, 1.05))
	var lino := ArtPalette.surface("floor_tile", Color(0.82, 0.84, 0.82))
	var block := ArtPalette.surface("drywall", Color(0.88, 0.9, 0.9))
	var lab_white := ArtPalette.surface("drywall", Color(1.33, 1.42, 1.6))
	var concrete := ArtPalette.surface("concrete")
	var metal_green := ArtPalette.flat(Color(0.32, 0.38, 0.33), 0.5, 0.4)
	ArtDress.reskin(geo, [
		{"names": ["NightDesk", "BoothDesk", "PanelDesk", "Desk", "InterviewTable", "BriefingTable", "ValeDesk"], "mat": ArtPalette.surface("laminate")},
		{"names": ["MonitorDesk", "RecorderDesk"], "mat": ArtPalette.surface("laminate", Color(0.55, 0.55, 0.58))},
		{"names": ["LabBench"], "mat": ArtPalette.flat(Color(0.86, 0.87, 0.86), 0.4)},
		{"names": ["Lockers", "LockerRow"], "mat": metal_green},
		{"names": ["TapeRack"], "mat": ArtPalette.surface("rack")},
		{"names": ["Bench"], "mat": ArtPalette.surface("laminate", Color(1.1, 1.0, 0.9))},
		{"names": ["Crate"], "mat": ArtPalette.flat(Color(0.62, 0.48, 0.3), 0.9)},
		{"names": ["Vent"], "mat": ArtPalette.surface("metal")},
		{"names": ["Floor"], "zone": OFFICE, "mat": carpet},
		{"names": ["Floor"], "zone": RECEPTION, "mat": carpet},
		{"names": ["Floor"], "zone": CAMERA_ROOM, "mat": carpet},
		{"names": ["Floor"], "zone": LAB, "mat": ArtPalette.surface("floor_tile", Color(1.3, 1.32, 1.32))},
		{"names": ["Wall_"], "zone": LAB, "mat": lab_white},
		{"names": ["Ceiling"], "zone": LAB, "mat": ArtPalette.surface("ceiling_tile", Color(1.05, 1.05, 1.05))},
		{"names": ["Floor", "Wall_", "Ceiling"], "zone": SERVICE, "mat": concrete},
		{"names": ["Floor", "LabSill"], "mat": lino},
		{"names": ["Wall_"], "mat": block},
		{"names": ["Ceiling"], "mat": ArtPalette.surface("ceiling_tile")},
	])
	var legs := ArtPalette.flat(Color(0.3, 0.3, 0.31), 0.5, 0.6)
	for b in geo.get_children():
		if b is StaticBody3D and ArtDress._name_matches(b.name, ["Desk", "InterviewTable", "BriefingTable"]):
			ArtDress.table_look(b, ArtPalette.surface("laminate"), legs)

	_front(geo, dress)
	_side_rooms(geo, dress)
	_back(dress)

	ArtDress.link_light_panels(level)
	var vent: Array = []
	for z in range(-11, 5):
		vent.append(Vector3(-6.6, 0, z))  # the vent's duct runs under this ceiling
	for x in [-4.8, -3.0]:
		vent.append(Vector3(x, 0, -10.0))
	ArtDress.explain_dark(level, DARK_CHECK, 3.6, vent)
	var lab = level.get("lab")
	var rourke: Node3D = lab.get("rourke") if lab else null
	if rourke:
		NpcLook.attach(rourke, CharacterLooks.rourke(), level.hud)


## A prop that's only seen (see the header).
static func _see(prop: Node) -> Node:
	return ArtDress.visual_only(prop)


## The landing, the booth's corridor, the Security Office and the way out.
static func _front(geo: Node3D, dress: Node3D) -> void:
	ArtProps.fire_extinguisher(dress, Vector3(3.0, 1.1, 9.89), 0)
	ArtProps.fire_extinguisher(dress, Vector3(4.5, 1.1, 2.11), 180)
	ArtProps.poster(dress, Vector3(-1.0, 1.6, 5.89), 0,
		"SECURITY FLOOR\n\nVisitors must be escorted\nat all times.\n\nBadges visible, please.", Vector2(0.5, 0.65))
	# Security Office: locker doors on the gear lockers, a noticeboard of shift life.
	var line := ArtPalette.flat(Color(0.2, 0.23, 0.2), 0.5)
	for k in 9:
		ArtDress.trim(dress, Vector3(2.6 + k * 0.4, 1.3, -5.94), Vector3(0.012, 2.5, 0.01), line)
	for k in 8:
		ArtDress.trim(dress, Vector3(2.8 + k * 0.4, 1.5, -5.935), Vector3(0.03, 0.12, 0.015), ArtPalette.flat(Color(0.7, 0.7, 0.72), 0.3, 0.8))  # handles
	var board := ArtProps.corkboard(dress, Vector3(5.89, 1.6, -2.5), 90, Vector2(1.2, 0.85))
	ArtProps.clipboard(board, Vector3(-0.35, 0.0, -0.02), 0, "OVERTIME SIGN-UP", false)
	ArtProps.memo(board, Vector3(0.1, 0.05, -0.017), 0, "LOST BADGES\nReport them the same night.")
	ArtProps.memo(board, Vector3(0.42, -0.05, -0.017), 0, "XMAS PARTY\nDec 19, cafeteria")
	ArtProps.poster(dress, Vector3(-1.89, 1.5, -14.0), -90,
		"IN CASE OF FIRE\nDO NOT USE ELEVATOR\n\nUSE STAIRS", Vector2(0.4, 0.4))
	# The night desk: the guard's chair in place of its block, a plant, a bench for visitors.
	var chair := geo.get_node_or_null("NightDeskChair")
	if chair:
		ArtDress.hide_block(chair)
		_see(ArtProps.office_chair(dress, Vector3(-3.5, 0, 8.5), 6))
	_see(ArtProps.potted_plant(dress, Vector3(-7.4, 0, 9.4)))
	for x in [-0.4, 0.2, 0.8]:
		_see(ArtProps.cafe_chair(dress, Vector3(x, 0, 9.65), 0, Color(0.3, 0.32, 0.38)))
	ArtProps.poster(dress, Vector3(0.6, 1.7, 6.11), 180,
		"NIGHT DESK\n18:00 - 06:00\n\nAfter hours, all visitors\nsign in here.", Vector2(0.5, 0.6))


## The patrol corridor and the rooms off it.
static func _side_rooms(geo: Node3D, dress: Node3D) -> void:
	ArtProps.fire_extinguisher(dress, Vector3(-8.11, 1.1, -2.0), 90)
	ArtProps.poster(dress, Vector3(-8.11, 1.6, 3.5), 90,
		"EMPLOYEE ASSISTANCE\n\nTalk to someone, any time.\nConfidential.\n\nCall ext. 2900", Vector2(0.45, 0.6))
	ArtProps.poster(dress, Vector3(-8.11, 1.6, -10.0), 90,
		"HALCYON SECURITY\n\nProfessional.\nVigilant.\nCourteous.", Vector2(0.45, 0.6))
	# Interview room: two folding chairs either side of the table.
	var grey := Color(0.36, 0.37, 0.4)
	for b in geo.get_children():
		if b is StaticBody3D and b.name.begins_with("Chair") and absf(b.position.z - 6.0) < 0.1 and b.position.x < -11.0:
			ArtDress.hide_block(b)
			_see(ArtProps.cafe_chair(dress, Vector3(b.position.x, 0, 6.0), -90.0 if b.position.x < -13.5 else 90.0, grey))
	# Briefing room: chairs down both sides, a frame and tray on the whiteboard.
	for z in [-8.2, -7.0, -5.8]:
		_see(ArtProps.cafe_chair(dress, Vector3(-14.15, 0, z), -90, grey))
		_see(ArtProps.cafe_chair(dress, Vector3(-12.25, 0, z), 90, grey))
	var frame := ArtPalette.flat(Color(0.72, 0.73, 0.75), 0.3, 0.8)
	for dy in [-0.57, 0.57]:
		ArtDress.trim(dress, Vector3(-15.87, 1.5 + dy, -7.0), Vector3(0.03, 0.04, 2.26), frame)
	for dz in [-1.12, 1.12]:
		ArtDress.trim(dress, Vector3(-15.87, 1.5, -7.0 + dz), Vector3(0.03, 1.18, 0.04), frame)
	ArtDress.trim(dress, Vector3(-15.83, 0.92, -7.0), Vector3(0.08, 0.02, 1.6), frame)  # marker tray
	# Locker room: doors and vents on both faces of each row.
	var line := ArtPalette.flat(Color(0.2, 0.23, 0.2), 0.5)
	for z in [-14.5, -11.8]:
		for side in [-1.0, 1.0]:
			var face: float = z + side * 0.255
			for k in 10:
				ArtDress.trim(dress, Vector3(-15.4 + k * 0.4, 1.0, face), Vector3(0.012, 1.9, 0.01), line)
			for k in 9:
				ArtDress.trim(dress, Vector3(-15.2 + k * 0.4, 1.75, face), Vector3(0.2, 0.08, 0.008), line)  # vents


## The service passage and the camera room.
static func _back(dress: Node3D) -> void:
	var pipe := ArtPalette.flat(Color(0.45, 0.47, 0.45), 0.5, 0.6)
	for y in [2.75, 2.95]:
		ArtDress.trim(dress, Vector3(-17.86, y, -4.0), Vector3(0.08, 0.08, 23.8), pipe)
	ArtDress.trim(dress, Vector3(-16.14, 2.9, -4.0), Vector3(0.06, 0.06, 23.8), ArtPalette.flat(Color(0.65, 0.2, 0.15), 0.5))  # sprinkler main
	# Camera room: tape spines along the rack, labelled by hand.
	var black := ArtPalette.flat(Color(0.06, 0.06, 0.07), 0.4)
	var labels := ArtPalette.flat(Color(0.92, 0.9, 0.84), 0.9)
	for row in 4:
		var y := 0.35 + row * 0.45
		ArtDress.trim(dress, Vector3(-5.4, y - 0.1, -19.34), Vector3(2.9, 0.02, 0.03), ArtPalette.flat(Color(0.3, 0.3, 0.32), 0.4, 0.6))
		for k in 14:
			if (k * 7 + row * 3) % 11 == 0:
				continue  # a gap where a tape was taken out
			var x := -6.75 + k * 0.2
			ArtDress.trim(dress, Vector3(x, y + 0.02, -19.33), Vector3(0.16, 0.22, 0.02), black)
			ArtDress.trim(dress, Vector3(x, y + 0.06, -19.318), Vector3(0.12, 0.05, 0.004), labels)
