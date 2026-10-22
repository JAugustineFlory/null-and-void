class_name DressLevel4
extends RefCounted
## Furnishing for Level 4, floor 10: the Power Plant. The tower's mechanical floor
## at night: a painted-block lift lobby, a tall switchgear hall in grey-green epoxy
## with its walkways lined in yellow, the breaker lineup along the west wall, ladder
## trays and ducts overhead, the transformer in its cage, the gantry on its I-beam;
## the door and lift control room on its raised floor, with the relay cabinets and
## the mimic board; the Custodian's charging bay, its dock and charger; and the
## ground floor's lobby as the crew left it. Called once at the end of Level 4's
## build(), before navigation bakes.
##
## Nothing added here collides: every prop is visual only, against a wall, overhead,
## or over a Greybox block whose collider stays (ArtDress.hide_block). The strip
## along the hall's north wall stays clear for the gantry and whoever rides it.
## Papers on the walls are plant life, never hints.

const LOBBY := AABB(Vector3(-3.9, -0.5, 4.1), Vector3(7.8, 3.5, 3.8))
const HALL := AABB(Vector3(-9.9, -0.5, -9.9), Vector3(19.8, 7.0, 13.8))
const CTRL := AABB(Vector3(2.1, -0.5, -17.9), Vector3(7.8, 6.0, 7.8))
const BAY := AABB(Vector3(-9.9, -0.5, -17.9), Vector3(9.8, 4.0, 7.8))
const DARK_CHECK := [LOBBY, HALL]

const STEEL := Color(0.5, 0.52, 0.53)
const CABINET := Color(0.62, 0.64, 0.6)  # ANSI 61 grey switchgear
const DARK := Color(0.12, 0.12, 0.13)
const CABLE := Color(0.1, 0.1, 0.11)
const CLIMB := Traversal.RUST  # what you can climb is this colour everywhere

# Level 4's own spots (level_4.gd has no class name: it reads Game at parse time).
const CTRL_DOOR_X := 6.0
const BAY_DOOR_X := -5.0
const GANTRY_Z := -9.3
const GANTRY_HIGH := 3.65
const CUSTODIAN_HOME := Vector3(-5, 0, -15.8)
const G_FRONT_AT := Vector3(0, 1.3, 6.95)


static func apply(level: LevelBase) -> void:
	var geo := level.geo
	var dress := ArtDress.dressing_root(level)
	var block := ArtPalette.surface("drywall", Color(0.95, 0.97, 0.92))
	var concrete := ArtPalette.surface("concrete", Color(1.05, 1.05, 1.0))
	ArtDress.reskin(geo, [
		{"names": ["Floor"], "zone": HALL, "mat": ArtPalette.surface("concrete", Color(0.72, 0.86, 0.8))},  # epoxy
		{"names": ["Floor"], "zone": CTRL, "mat": ArtPalette.surface("floor_tile", Color(0.95, 0.95, 1.0))},  # raised floor
		{"names": ["Floor"], "zone": BAY, "mat": ArtPalette.surface("concrete", Color(0.8, 0.8, 0.8))},
		{"names": ["Floor"], "zone": LOBBY, "mat": ArtPalette.surface("floor_tile", Color(0.85, 0.86, 0.84))},
		{"names": ["Wall_"], "zone": BAY, "mat": ArtPalette.surface("concrete", Color(0.85, 0.85, 0.82))},
		{"names": ["Wall_"], "zone": HALL, "mat": concrete},
		{"names": ["Wall_"], "mat": block},
		{"names": ["Ceiling"], "zone": HALL, "mat": ArtPalette.surface("concrete", Color(0.7, 0.7, 0.7))},
		{"names": ["Ceiling"], "zone": BAY, "mat": ArtPalette.surface("concrete", Color(0.75, 0.75, 0.75))},
		{"names": ["Ceiling"], "mat": ArtPalette.surface("ceiling_tile")},
		{"names": ["ControlDesk"], "mat": ArtPalette.surface("laminate", Color(0.75, 0.75, 0.72))},
		{"names": ["DoorWedge"], "mat": ArtPalette.flat(Color(0.55, 0.4, 0.22), 0.8)},
	])
	_lobby(dress)
	_hall(level, dress)
	_switchgear(level, dress)
	_gantry(level, dress)
	_control_room(level, dress)
	_bay(level, dress)
	_ground(level)
	if level.get("custodian"):
		custodian(level.custodian)

	ArtDress.link_light_panels(level)
	ArtKit.dress_stairwells(level)
	ArtMood.polish(level.environment)
	ArtDress.explain_dark(level, DARK_CHECK, 3.6)


## The Greybox block named `node_name` nearest `near` (level space), or null.
static func _block(geo: Node3D, node_name: String, near: Vector3) -> StaticBody3D:
	var best: StaticBody3D = null
	for b in geo.get_children():
		if b is StaticBody3D and String(b.name).begins_with(node_name):
			if best == null or b.position.distance_to(near) < best.position.distance_to(near):
				best = b
	return best if best and best.position.distance_to(near) < 0.5 else null


static func _hide(geo: Node3D, node_name: String, near: Vector3) -> void:
	var b := _block(geo, node_name, near)
	if b:
		ArtDress.hide_block(b)


# --- Lift lobby ------------------------------------------------------------------

## The lift lobby: steel lift doors with their call buttons dark, a fire notice.
static func _lobby(dress: Node3D) -> void:
	ArtDress.skirting(dress, Vector3(0, 0, 6), Vector3(8, 3.2, 4), [
		{"wall": "n", "at": 0.0, "width": 2.4}, {"wall": "w", "at": 0.0, "width": Stairwell.DOOR_W}, {"wall": "e", "at": 0.0, "width": Stairwell.DOOR_W}])
	var m := ArtMesh.new()
	var frame := Color(0.62, 0.64, 0.66)
	var leaf := Color(0.55, 0.57, 0.6)
	for x in [-1.5, 1.5]:
		for side in [-1.0, 1.0]:
			m.box(Vector3(x + side * 0.33, 1.1, 7.855), Vector3(0.64, 2.18, 0.02), leaf, 0.0, ["-z"])
		m.box(Vector3(x, 1.1, 7.85), Vector3(0.008, 2.18, 0.03), Color(0.2, 0.2, 0.22))
		for side in [-1.0, 1.0]:
			m.box(Vector3(x + side * 0.72, 1.12, 7.84), Vector3(0.1, 2.3, 0.08), frame)
		m.box(Vector3(x, 2.3, 7.84), Vector3(1.54, 0.12, 0.08), frame)
		var px: float = x + signf(x) * 0.95
		m.box(Vector3(px, 1.1, 7.885), Vector3(0.12, 0.26, 0.02), frame)
		for y in [1.04, 1.16]:
			m.box(Vector3(px, y, 7.873), Vector3(0.04, 0.04, 0.01), Color(0.25, 0.25, 0.26))
	# Through the way into the hall: a strip of yellow on the floor, and a kick plate.
	m.box(Vector3(0, 0.003, 4.0), Vector3(2.4, 0.004, 0.2), ArtPalette.SAFETY_YELLOW)
	m.commit(dress, "Lobby", true, 0.5, 0.4)
	ArtProps.fire_extinguisher(dress, Vector3(-3.5, 1.1, 4.11), 180)
	ArtProps.poster(dress, Vector3(-2.3, 1.55, 4.11), 180,
		"PLANT FLOOR\nHEARING PROTECTION\nBEYOND THIS POINT", Vector2(0.5, 0.4), Color(0.95, 0.85, 0.3), 22)


# --- Switchgear hall ----------------------------------------------------------------

## The hall: walkways painted on the epoxy, the transformer in its cage, ladder
## trays and a supply duct overhead, conduit runs on the walls, the maintenance
## bench, and the safety kit by the way in.
static func _hall(level: LevelBase, dress: Node3D) -> void:
	var geo := level.geo
	ArtDress.skirting(dress, Vector3(0, 0, -3), Vector3(20, 6.0, 14), [
		{"wall": "s", "at": 0.0, "width": 2.4}, {"wall": "n", "at": CTRL_DOOR_X, "width": 1.6},
		{"wall": "n", "at": BAY_DOOR_X, "width": 3.0}], 0.12, ArtPalette.flat(Color(0.2, 0.22, 0.2), 0.7))
	var m := ArtMesh.new()
	var yellow := ArtPalette.SAFETY_YELLOW
	# Walkway lines: in from the lobby, then along the hall to both doors.
	for x in [-1.3, 1.3]:
		m.box(Vector3(x, 0.003, 1.0), Vector3(0.08, 0.004, 6.0), yellow)
	for z in [-8.2, -2.2]:
		m.box(Vector3(0, 0.003, z), Vector3(17.0, 0.004, 0.08), yellow)
	# Hatched keep-out round the transformer.
	var tx := Vector3(7.5, 0, 1.5)
	for sx in [-1.0, 1.0]:
		m.box(tx + Vector3(sx * 1.9, 0.003, 0), Vector3(0.1, 0.004, 3.8), yellow)
	m.box(tx + Vector3(0, 0.003, -1.9), Vector3(3.9, 0.004, 0.1), yellow)
	for k in 8:
		var stripe := Basis(Vector3.UP, deg_to_rad(45.0))
		m.oriented_box(tx + Vector3(-1.7 + k * 0.48, 0.003, -1.72), Vector3(0.08, 0.004, 0.36), Color(0.12, 0.12, 0.1), stripe)
	m.commit(dress, "HallFloor", false, 0.6)
	_transformer(level, dress, tx)
	# Ladder trays with their cables on the greybox trays' colliders.
	var trays := ArtMesh.new()
	for z in [-6.5, -1.0]:
		_hide(geo, "CableTray", Vector3(0, 4.6, z))
		for side in [-0.28, 0.28]:
			trays.box(Vector3(0, 4.62, z + side), Vector3(18, 0.1, 0.03), STEEL)
		for k in 37:
			trays.box(Vector3(-9.0 + k * 0.5, 4.56, z), Vector3(0.03, 0.02, 0.56), STEEL)
		for c in 6:
			var cz: float = z - 0.2 + c * 0.08
			trays.rod(Vector3(-9.0, 4.62, cz), Vector3(9.0, 4.62, cz), 0.03, CABLE if c % 3 else Color(0.45, 0.12, 0.08), 6)
		for x in [-8.0, -2.0, 4.0]:
			trays.box(Vector3(x, 5.32, z), Vector3(0.04, 1.36, 0.04), STEEL)  # hangers from the slab
	# The supply duct, galvanised, between the trays; and conduit along the walls.
	var galv := Color(0.62, 0.64, 0.66)
	trays.box(Vector3(0, 5.45, -3.75), Vector3(19.8, 0.7, 1.0), galv)
	for k in 10:
		trays.box(Vector3(-9.0 + k * 2.0, 5.45, -3.75), Vector3(0.05, 0.74, 1.04), galv.darkened(0.12))
	for z in [-3.0, 1.0]:
		trays.box(Vector3(0, 5.08, z - 0.75), Vector3(0.6, 0.04, 0.4), Color(0.25, 0.25, 0.27))  # supply grilles
	for y in [3.9, 4.05]:
		trays.rod(Vector3(9.88, y, -9.6), Vector3(9.88, y, 3.6), 0.025, galv, 6)
		trays.rod(Vector3(-9.6, y + 0.4, 3.88), Vector3(9.6, y + 0.4, 3.88), 0.025, galv, 6)
	trays.commit(dress, "Overhead", true, 0.45, 0.5)
	# The maintenance bench: a steel workbench with a vice, a parts tray and a
	# pegboard along its back edge (the terminal's front stays clear).
	var bench := _block(geo, "MaintDesk", Vector3(-6, 0.5, 1.6))
	if bench:
		ArtDress.table_look(bench, ArtPalette.surface("metal", Color(0.8, 0.82, 0.8)), ArtPalette.flat(Color(0.25, 0.3, 0.28), 0.5, 0.5), 0.05)
	var kit := ArtMesh.new()
	kit.box(Vector3(-7.0, 1.04, 1.4), Vector3(0.14, 0.08, 0.1), Color(0.2, 0.35, 0.55))  # the vice
	kit.box(Vector3(-7.0, 1.1, 1.4), Vector3(0.2, 0.04, 0.06), Color(0.2, 0.35, 0.55))
	kit.box(Vector3(-4.95, 1.03, 1.4), Vector3(0.4, 0.06, 0.25), Color(0.65, 0.15, 0.1))  # parts tray
	for k in 5:
		kit.rod(Vector3(-5.1 + k * 0.07, 1.06, 1.4), Vector3(-5.1 + k * 0.07, 1.09, 1.4), 0.012, Color(0.7, 0.62, 0.35), 6, true)
	kit.box(Vector3(-5.4, 1.45, 1.22), Vector3(1.2, 0.7, 0.02), Color(0.45, 0.34, 0.22))  # the pegboard, beside the screen
	for k in 4:
		kit.box(Vector3(-5.85 + k * 0.3, 1.42 + (k % 2) * 0.12, 1.24), Vector3(0.04, 0.22, 0.02), Color(0.2, 0.2, 0.22))
	kit.commit(dress, "Bench", true, 0.5, 0.3)
	# Safety kit by the way in: an eyewash station, hard hats on hooks, an extinguisher.
	var safe := ArtMesh.new()
	safe.box(Vector3(-2.2, 1.4, 3.86), Vector3(0.5, 0.6, 0.18), Color(0.2, 0.55, 0.3))
	safe.box(Vector3(-2.2, 1.78, 3.86), Vector3(0.5, 0.12, 0.2), Color(0.95, 0.95, 0.9))
	for k in 3:
		var hat := Vector3(2.0 + k * 0.4, 1.7, 3.84)
		safe.box(hat + Vector3(0, 0.08, 0), Vector3(0.02, 0.02, 0.08), STEEL)
		safe.rod(hat + Vector3(0, -0.02, -0.12), hat + Vector3(0, 0.08, -0.12), 0.13, [ArtPalette.SAFETY_YELLOW, Color(0.95, 0.95, 0.92), ArtPalette.SAFETY_YELLOW][k], 10, true)
	safe.commit(dress, "SafetyKit", true, 0.5)
	ArtProps.fire_extinguisher(dress, Vector3(-3.2, 1.1, 3.89), 180)
	ArtProps.poster(dress, Vector3(4.0, 1.6, 3.89), 180, "DANGER\nHIGH VOLTAGE\n\nAUTHORISED PERSONS ONLY", Vector2(0.45, 0.6), Color(0.95, 0.95, 0.92), 22)
	ArtProps.poster(dress, Vector3(9.89, 2.2, -4.0), -90, "ARC FLASH HAZARD\n\nPPE REQUIRED\nCAT 2", Vector2(0.4, 0.5), Color(0.95, 0.6, 0.15), 22)


## The transformer: a dry-type unit, louvred, in a mesh cage on its keep-out.
static func _transformer(level: LevelBase, dress: Node3D, at: Vector3) -> void:
	_hide(level.geo, "Transformer", at + Vector3(0, 1.2, 0))
	var m := ArtMesh.new()
	var green := Color(0.3, 0.38, 0.33)
	m.box(at + Vector3(0, 0.05, 0), Vector3(2.4, 0.1, 2.4), DARK)  # plinth
	m.box(at + Vector3(0, 1.05, 0), Vector3(2.0, 1.9, 1.6), green, 0.0, ["bottom"])
	for k in 9:
		for z in [-0.805, 0.805]:
			m.box(at + Vector3(0, 0.45 + k * 0.12, z), Vector3(1.6, 0.03, 0.01), green.darkened(0.3))
	for x in [-0.6, 0.0, 0.6]:
		m.rod(at + Vector3(x, 2.0, 0), at + Vector3(x, 2.3, 0), 0.06, Color(0.75, 0.72, 0.62), 8, true)  # bushings
		m.rod(at + Vector3(x, 2.3, 0), at + Vector3(x, 4.48, 0), 0.03, CABLE, 6)  # up to the tray
		m.rod(at + Vector3(x, 4.48, 0), at + Vector3(x, 4.48, -2.5), 0.03, CABLE, 6)
	# The cage: posts, a top rail and mesh panels (thin wires both ways).
	var cage := 1.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			m.box(at + Vector3(sx * cage, 1.2, sz * cage), Vector3(0.06, 2.4, 0.06), STEEL)
	for side in 4:
		var b := Basis(Vector3.UP, side * PI / 2)
		m.oriented_box(at + b * Vector3(0, 2.38, -cage), Vector3(cage * 2, 0.05, 0.05), STEEL, b)
		for k in 15:
			m.oriented_box(at + b * Vector3(-cage + 0.2 * k, 1.2, -cage), Vector3(0.008, 2.3, 0.008), STEEL.darkened(0.2), b)
		for k in 12:
			m.oriented_box(at + b * Vector3(0, 0.1 + 0.2 * k, -cage), Vector3(cage * 2, 0.008, 0.008), STEEL.darkened(0.2), b)
	m.commit(dress, "Transformer", true, 0.55, 0.35)


# --- Breaker lineup -------------------------------------------------------------------

## The main distribution: a lineup of grey cabinets behind the breakers, with
## vents, nameplates and a bus duct along the top; each breaker a moulded-case unit
## with its handle and a rating label. The lamps and labels stay the level's.
static func _switchgear(level: LevelBase, dress: Node3D) -> void:
	var geo := level.geo
	_hide(geo, "PanelBack", Vector3(-9.7, 1.9, -4.75))
	var m := ArtMesh.new()
	var x := -9.75
	m.box(Vector3(x, 1.6, -4.75), Vector3(0.2, 3.2, 7.2), CABINET, 0.0, ["-x"])
	for k in 7:
		var z := -8.25 + k * 1.0 + 0.5
		m.box(Vector3(x + 0.105, 1.6, z - 0.5), Vector3(0.01, 3.1, 0.02), CABINET.darkened(0.25))  # cabinet seams
		for v in 4:
			m.box(Vector3(x + 0.105, 0.2 + v * 0.05, z), Vector3(0.01, 0.015, 0.6), CABINET.darkened(0.35))  # kick vents
	m.box(Vector3(x + 0.02, 3.35, -4.75), Vector3(0.3, 0.25, 7.2), CABINET.darkened(0.1))  # bus duct
	m.box(Vector3(x + 0.15, 3.35, -4.75), Vector3(0.02, 0.02, 7.2), CABINET.darkened(0.3))
	for b in geo.get_children():
		if b is StaticBody3D and String(b.name).begins_with("Breaker"):
			ArtDress.hide_block(b)
			var at: Vector3 = b.position
			m.box(at + Vector3(-0.02, 0, 0), Vector3(0.2, 0.78, 0.76), Color(0.2, 0.2, 0.21))  # the moulded case
			m.box(at + Vector3(0.085, 0.0, 0), Vector3(0.02, 0.5, 0.6), Color(0.28, 0.28, 0.3))  # its face
			m.box(at + Vector3(0.11, 0.06, 0.24), Vector3(0.05, 0.16, 0.06), Color(0.08, 0.08, 0.08))  # the handle
			m.box(at + Vector3(0.096, 0.25, 0), Vector3(0.008, 0.16, 0.5), Color(0.92, 0.9, 0.82))  # the rating label
	m.commit(dress, "Switchgear", true, 0.5, 0.3)


# --- Gantry ----------------------------------------------------------------------------

## The gantry's rail as a steel I-beam with end stops and a festoon cable, and the
## carriage dressed: a diamond-plate deck with toe boards and hazard edges, its
## trolley and hanger, and the climbable mast in the climb colour.
static func _gantry(level: LevelBase, dress: Node3D) -> void:
	var geo := level.geo
	var z := GANTRY_Z
	_hide(geo, "GantryRail", Vector3(0, 5.85, z))
	var m := ArtMesh.new()
	var beam := Color(0.75, 0.6, 0.15)
	m.box(Vector3(0, 5.94, z), Vector3(19.5, 0.03, 0.3), beam)
	m.box(Vector3(0, 5.76, z), Vector3(19.5, 0.03, 0.3), beam)
	m.box(Vector3(0, 5.85, z), Vector3(19.5, 0.16, 0.03), beam)
	for x in [-9.7, 9.7]:
		m.box(Vector3(x, 5.85, z), Vector3(0.1, 0.25, 0.32), Color(0.75, 0.15, 0.1))  # end stops
	for k in 20:
		var cx := -9.3 + k * 0.98
		m.rod(Vector3(cx, 5.74, z + 0.22), Vector3(cx + 0.49, 5.5, z + 0.22), 0.015, CABLE, 4)  # festoon loops
		m.rod(Vector3(cx + 0.49, 5.5, z + 0.22), Vector3(cx + 0.98, 5.74, z + 0.22), 0.015, CABLE, 4)
	m.commit(dress, "GantryRail", true, 0.5, 0.5)
	var gantry: Node3D = level.get("gantry")
	if gantry == null:
		return
	for c in gantry.get_children():
		if c is MeshInstance3D:
			c.visible = false
	var g := ArtMesh.new()
	var plate := Color(0.6, 0.62, 0.62)
	g.box(Vector3(0, -0.1, 0), Vector3(1.2, 0.2, 1.2), Color(0.3, 0.3, 0.32))
	g.box(Vector3(0, -0.005, 0), Vector3(1.18, 0.01, 1.18), plate)
	for i in 8:
		for j in 8:
			g.box(Vector3(-0.52 + i * 0.15, 0.002, -0.52 + j * 0.15), Vector3(0.06, 0.006, 0.015), plate.lightened(0.15), 45.0 if (i + j) % 2 else -45.0)
	for k in 10:  # hazard stripes on the deck's edge
		g.box(Vector3(-0.54 + k * 0.12, -0.1, 0.605), Vector3(0.06, 0.19, 0.01), ArtPalette.SAFETY_YELLOW if k % 2 else DARK)
	for side in [-1.0, 1.0]:  # toe boards and a rail on three sides (the mast side is open)
		g.box(Vector3(side * 0.59, 0.075, 0), Vector3(0.02, 0.15, 1.2), ArtPalette.SAFETY_YELLOW)
		g.box(Vector3(side * 0.59, 1.0, 0), Vector3(0.04, 0.04, 1.2), ArtPalette.SAFETY_YELLOW)
		g.box(Vector3(side * 0.59, 0.5, -0.58), Vector3(0.04, 1.0, 0.04), ArtPalette.SAFETY_YELLOW)
		g.box(Vector3(side * 0.59, 0.5, 0.58), Vector3(0.04, 1.0, 0.04), ArtPalette.SAFETY_YELLOW)
	g.box(Vector3(0, 0.075, -0.59), Vector3(1.2, 0.15, 0.02), ArtPalette.SAFETY_YELLOW)
	g.box(Vector3(0, 1.0, -0.59), Vector3(1.2, 0.04, 0.04), ArtPalette.SAFETY_YELLOW)
	# The hanger up to the trolley on the rail (it rides 5.6 above the floor).
	g.box(Vector3(-0.5, 3.0, -0.5), Vector3(0.14, 6.0, 0.14), STEEL)
	g.box(Vector3(-0.5, 0.6, -0.5), Vector3(0.3, 0.4, 0.2), Color(0.2, 0.22, 0.25))  # the pendant control box
	g.box(Vector3(-0.38, 0.65, -0.5), Vector3(0.02, 0.06, 0.06), Color(0.8, 0.15, 0.1))
	# The mast: a ladder down the open side, from the deck to the floor (it runs on
	# below the floor when the deck is down, out of sight).
	for side in [-0.2, 0.2]:
		g.box(Vector3(side, -GANTRY_HIGH / 2, 0.66), Vector3(0.05, GANTRY_HIGH, 0.05), CLIMB)
	for k in int(GANTRY_HIGH / 0.3):
		g.box(Vector3(0, -0.25 - k * 0.3, 0.66), Vector3(0.4, 0.03, 0.03), CLIMB)
	g.commit(gantry, "Look", true, 0.5, 0.5)


# --- Door and lift control --------------------------------------------------------------

## The control room on its raised floor: the console desk, relay cabinets for the
## lifts, the mimic board of the tower's doors and shafts, a phone, the chair.
static func _control_room(level: LevelBase, dress: Node3D) -> void:
	var geo := level.geo
	var m := ArtMesh.new()
	# Raised floor: tile seams.
	for k in 13:
		m.box(Vector3(2.0 + k * 0.6 + 0.3, 0.002, -14), Vector3(0.008, 0.004, 7.9), Color(0.55, 0.56, 0.58))
		m.box(Vector3(6, 0.002, -18 + k * 0.6 + 0.3), Vector3(7.9, 0.004, 0.008), Color(0.55, 0.56, 0.58))
	# The console: a sloped panel of switches and lamps on the desk, behind the terminal.
	var slope := Basis(Vector3.RIGHT, deg_to_rad(-35.0))
	var panel := Vector3(6.0, 1.15, -16.9)
	m.oriented_box(panel, Vector3(2.9, 0.3, 0.06), Color(0.42, 0.44, 0.46), slope)
	for i in 14:
		for j in 2:
			var at := panel + slope * Vector3(-1.3 + i * 0.2, -0.05 + j * 0.1, -0.035)
			m.oriented_box(at, Vector3(0.05, 0.03, 0.02), [Color(0.7, 0.15, 0.1), Color(0.15, 0.5, 0.2), Color(0.85, 0.85, 0.8)][(i + j) % 3], slope)
	# The phone, a binder, a mug.
	m.box(Vector3(7.2, 1.04, -16.5), Vector3(0.22, 0.08, 0.2), Color(0.85, 0.82, 0.72))
	m.box(Vector3(7.2, 1.1, -16.52), Vector3(0.22, 0.04, 0.06), Color(0.85, 0.82, 0.72))
	m.rod(Vector3(4.6, 1.0, -16.4), Vector3(4.6, 1.1, -16.4), 0.04, Color(0.2, 0.35, 0.6), 10, true)
	# The mimic board on the west wall: the tower in outline, a lamp per door and lift.
	var wall := 2.11
	m.box(Vector3(wall, 1.9, -14.0), Vector3(0.03, 1.6, 3.6), Color(0.18, 0.22, 0.2))
	for floor_i in 6:
		var y := 1.25 + floor_i * 0.24
		m.box(Vector3(wall + 0.02, y, -14.0), Vector3(0.006, 0.01, 3.2), Color(0.8, 0.8, 0.75))
		for door in 7:
			m.box(Vector3(wall + 0.022, y + 0.09, -15.4 + door * 0.45), Vector3(0.006, 0.05, 0.05), Color(0.35, 0.12, 0.1))
	for shaft in 3:
		m.box(Vector3(wall + 0.02, 1.9, -12.7 + shaft * 0.25), Vector3(0.006, 1.45, 0.012), Color(0.8, 0.8, 0.75))
	m.commit(dress, "ControlRoom", true, 0.45, 0.3)
	ArtProps.poster(dress, Vector3(wall + 0.03, 2.9, -14.0), 90, "HALCYON TOWER  -  DOORS AND LIFTS", Vector2(2.4, 0.2), Color(0.18, 0.22, 0.2), 30)
	# The relay cabinets for the three lifts, on the greybox cabinets' colliders.
	var cab := ArtMesh.new()
	for z in [-16.5, -14.5, -12.5]:
		_hide(geo, "LiftController", Vector3(9.5, 1.1, z))
		cab.box(Vector3(9.5, 1.1, z), Vector3(0.8, 2.2, 1.56), Color(0.45, 0.47, 0.5), 0.0, ["bottom"])
		for side in [-1.0, 1.0]:
			cab.box(Vector3(9.09, 1.15, z + side * 0.385), Vector3(0.02, 1.9, 0.74), Color(0.5, 0.52, 0.55))
			cab.box(Vector3(9.07, 1.15, z + side * 0.06), Vector3(0.03, 0.18, 0.03), DARK)  # handles
		for v in 6:
			cab.box(Vector3(9.075, 1.85 + v * 0.04, z), Vector3(0.006, 0.015, 1.3), Color(0.3, 0.32, 0.34))
		cab.box(Vector3(9.08, 1.55, z - 0.4), Vector3(0.004, 0.12, 0.3), Color(0.92, 0.9, 0.82))  # its nameplate
	cab.commit(dress, "LiftCabinets", true, 0.5, 0.4)
	_hide(geo, "Corkboard", Vector3(7.9, 1.6, -17.92))
	ArtProps.corkboard(dress, Vector3(7.9, 1.6, -17.92), 0, Vector2(1.8, 1.0))
	ArtDress.visual_only(ArtProps.office_chair(dress, Vector3(6.2, 0, -15.6), 180))


# --- Charging bay -----------------------------------------------------------------------

## The Custodian's bay: a dock on a hazard-striped plate, the wall charger with its
## cables and gauges, a parts rack, a steel console for the bay's panel, and the
## night guard where it left him.
static func _bay(level: LevelBase, dress: Node3D) -> void:
	var geo := level.geo
	_hide(geo, "Cradle", Vector3(-5, 0.2, -17.2))
	_hide(geo, "Charger", Vector3(-5, 1.6, -17.8))
	var m := ArtMesh.new()
	var home := CUSTODIAN_HOME
	# The dock plate, striped round, with contact rails where the base sits.
	m.box(Vector3(-5, 0.01, -16.6), Vector3(3.0, 0.02, 2.6), Color(0.3, 0.3, 0.32))
	for k in 14:
		m.box(Vector3(-6.4 + k * 0.2, 0.022, -15.35), Vector3(0.1, 0.004, 0.1), ArtPalette.SAFETY_YELLOW if k % 2 else DARK)
	for x in [-0.25, 0.25]:
		m.box(Vector3(home.x + x, 0.03, -17.0), Vector3(0.06, 0.03, 1.4), Color(0.75, 0.55, 0.25))  # copper
	# The cradle itself: two buffers at the back the base noses into.
	m.box(Vector3(-5, 0.2, -17.6), Vector3(2.4, 0.4, 0.4), Color(0.2, 0.2, 0.22))
	for x in [-0.8, 0.8]:
		m.box(Vector3(-5 + x, 0.3, -17.35), Vector3(0.3, 0.3, 0.12), DARK)
	# The charger on the back wall: a cabinet with a gauge and status lights, and the
	# fat cables down to the cradle.
	m.box(Vector3(-5, 1.6, -17.8), Vector3(1.6, 2.4, 0.3), Color(0.36, 0.38, 0.42))
	m.box(Vector3(-5, 2.3, -17.64), Vector3(1.2, 0.5, 0.02), Color(0.15, 0.17, 0.2))
	m.rod(Vector3(-5.3, 2.3, -17.63), Vector3(-5.3, 2.3, -17.62), 0.14, Color(0.9, 0.9, 0.85), 16, true)  # a gauge
	m.box(Vector3(-5.3, 2.33, -17.615), Vector3(0.01, 0.1, 0.004), DARK)
	for k in 3:
		m.box(Vector3(-4.9 + k * 0.15, 2.3, -17.625), Vector3(0.06, 0.06, 0.01), [Color(0.2, 0.6, 0.3), Color(0.85, 0.6, 0.1), Color(0.7, 0.15, 0.1)][k])
	m.box(Vector3(-5, 1.2, -17.64), Vector3(0.8, 0.04, 0.02), ArtPalette.SAFETY_YELLOW)
	for x in [-0.45, 0.45]:
		m.rod(Vector3(-5 + x, 0.8, -17.66), Vector3(-5 + x * 0.8, 0.35, -17.45), 0.045, CABLE, 6)
	# A parts rack against the east wall, with spare arm segments and drums.
	var rack := Vector3(-0.6, 0, -15.5)
	for y in [0.3, 0.9, 1.5]:
		m.box(rack + Vector3(0, y, 0), Vector3(0.6, 0.04, 2.0), STEEL)
	for sz in [-0.95, 0.95]:
		for sx in [-0.27, 0.27]:
			m.box(rack + Vector3(sx, 0.9, sz), Vector3(0.04, 1.8, 0.04), STEEL)
	m.box(rack + Vector3(0, 0.37, -0.4), Vector3(0.2, 0.1, 1.0), Color(0.78, 0.6, 0.16))  # a spare arm segment
	for k in 3:
		m.rod(rack + Vector3(0, 0.92, -0.6 + k * 0.5), rack + Vector3(0, 1.28, -0.6 + k * 0.5), 0.17, Color(0.25, 0.32, 0.45), 10, true)
	# Drag marks on the floor from the doorway to the dock.
	for k in 7:
		m.box(Vector3(-5.2 + (k % 2) * 0.4, 0.003, -11.0 - k * 0.6), Vector3(0.08, 0.004, 0.5), Color(0.15, 0.14, 0.13), (k % 3 - 1) * 6.0)
	m.commit(dress, "Bay", true, 0.55, 0.35)
	var desk := _block(geo, "BayDesk", Vector3(-1.2, 0.5, -11.2))
	if desk:
		ArtDress.table_look(desk, ArtPalette.surface("metal", Color(0.75, 0.77, 0.78)), ArtPalette.flat(Color(0.22, 0.22, 0.24), 0.5, 0.5), 0.05)
	ArtProps.poster(dress, Vector3(-9.89, 1.7, -12.5), 90, "CUSTODIAN UNIT C-10\nCHARGE CYCLE 6 H\n\nKEEP CLEAR OF\nDOCK WHILE ARMED", Vector2(0.5, 0.55), Color(0.95, 0.95, 0.92), 20)
	_night_guard(level, dress)


## The night guard it took on Tuesday, on his back behind the cradle.
static func _night_guard(level: LevelBase, dress: Node3D) -> void:
	var geo := level.geo
	_hide(geo, "NightGuardHead", Vector3(-8.6, 0.2, -15.6))
	_hide(geo, "NightGuard", Vector3(-8.6, 0.15, -16.6))
	var holder := Node3D.new()
	holder.name = "NightGuard"
	holder.position = Vector3(-8.6, 0, -16.45)
	# Flat on his back, head toward the door (the rig lies head to its +Z), as the greybox lay.
	dress.add_child(holder)
	var rig := CharacterRig.build(holder, CharacterLooks.night_guard())
	rig.play("dead")
	for i in 30:
		rig.animate(1.0 / 30.0)
	rig.set_process(false)
	# His torch where it rolled, still on.
	var torch := ArtMesh.new()
	torch.rod(Vector3(-7.6, 0.04, -15.5), Vector3(-7.35, 0.04, -15.62), 0.03, DARK, 8, true)
	torch.commit(dress, "Torch", true, 0.4, 0.4)
	var beam := SpotLight3D.new()
	beam.name = "TorchBeam"
	beam.position = Vector3(-7.35, 0.05, -15.62)
	beam.light_energy = 1.2
	beam.spot_range = 4.0
	beam.spot_angle = 22.0
	beam.light_color = Color(1.0, 0.92, 0.75)
	dress.add_child(beam)
	beam.look_at(beam.global_position + Vector3(0.9, 0.05, -0.45))


# --- Ground floor ----------------------------------------------------------------------

## The ground floor rebuilt in this wing: carpet and plaster as the crew saw it coming
## in, the front desk in laminate, the night grille dark behind the glass.
static func _ground(level: LevelBase) -> void:
	var g: Node3D = level.get("g_geo")
	if g == null:
		return
	ArtDress.reskin(g, [
		{"names": ["Floor"], "zone": AABB(Vector3(-8, -0.5, -7), Vector3(16, 4.5, 14)), "mat": ArtPalette.surface("carpet", Color(1.15, 0.95, 0.85))},
		{"names": ["Floor"], "mat": ArtPalette.surface("floor_tile")},
		{"names": ["Wall_"], "mat": ArtPalette.surface("drywall")},
		{"names": ["Ceiling"], "mat": ArtPalette.surface("ceiling_tile")},
		{"names": ["FrontDesk"], "mat": ArtPalette.surface("laminate", Color(0.85, 0.68, 0.5))},
		{"names": ["NightGrille"], "mat": ArtPalette.flat(Color(0.14, 0.14, 0.15), 0.4, 0.7)},
	])
	var m := ArtMesh.new()
	var grille := G_FRONT_AT + Vector3(0, 0, 0.22)
	for k in 17:
		m.box(grille + Vector3(-1.6 + k * 0.2, 0, 0), Vector3(0.02, 2.65, 0.02), Color(0.35, 0.35, 0.36))
	m.commit(g, "GrilleSlats", false, 0.4, 0.7)
	ArtDress.visual_only(ArtProps.potted_plant(g, Vector3(-3.0, 0, 6.2)))
	ArtDress.visual_only(ArtProps.potted_plant(g, Vector3(3.0, 0, 6.2)))


# --- The Custodian ------------------------------------------------------------------------

## The Custodian's look: a tracked base, a scuffed safety-yellow body with service
## panels, a grille and a warning stripe, a sensor head with its visor, and
## hydraulic arms with claws. Drawn in its greybox's place, the same size, so its
## wounds and its arms' poses land where they did.
static func custodian(robot: Node3D) -> void:
	var body: Node3D = robot.get("_body")
	if body == null:
		return
	var lamp: MeshInstance3D = robot.get("_lamp")
	for c in body.get_children():
		if c is MeshInstance3D and c != lamp:
			c.visible = false
	var paint := Color(0.78, 0.6, 0.16)
	var steel := Color(0.3, 0.31, 0.33)
	var m := ArtMesh.new()
	# The tracked base.
	m.box(Vector3(0, 0.25, 0), Vector3(0.7, 0.26, 0.8), steel)
	for side in [-1.0, 1.0]:
		m.box(Vector3(side * 0.43, 0.2, 0), Vector3(0.16, 0.28, 0.9), DARK)
		for k in 9:
			m.box(Vector3(side * 0.43, 0.06, -0.4 + k * 0.1), Vector3(0.17, 0.03, 0.04), Color(0.2, 0.2, 0.2))
		for z in [-0.36, 0.36]:
			m.rod(Vector3(side * 0.35, 0.2, z), Vector3(side * 0.52, 0.2, z), 0.12, steel.lightened(0.1), 10, true)
	# The body: chamfered edges, side service panels, a front grille and a stripe.
	m.box(Vector3(0, 1.1, 0), Vector3(0.85, 1.4, 0.7), paint)
	for sx in [-1.0, 1.0]:
		m.box(Vector3(sx * 0.4, 1.1, -0.33), Vector3(0.06, 1.4, 0.06), paint.darkened(0.2))
		m.box(Vector3(sx * 0.426, 1.1, 0.05), Vector3(0.01, 0.9, 0.45), paint.darkened(0.12))  # service panel
		for b in 4:
			m.box(Vector3(sx * 0.432, 0.7 + (b / 2) * 0.8, -0.15 + (b % 2) * 0.4), Vector3(0.01, 0.03, 0.03), steel)
	m.box(Vector3(0, 0.75, -0.352), Vector3(0.6, 0.3, 0.01), DARK)
	for k in 6:
		m.box(Vector3(0, 0.63 + k * 0.045, -0.358), Vector3(0.58, 0.012, 0.006), steel)
	for k in 8:
		m.box(Vector3(-0.375 + k * 0.107, 1.68, -0.354), Vector3(0.054, 0.08, 0.006), DARK if k % 2 else ArtPalette.SAFETY_YELLOW.darkened(0.05))
	m.box(Vector3(0, 1.82, 0), Vector3(0.6, 0.06, 0.5), steel)  # the neck ring
	# The sensor head: a housing, the visor slot (the lamp shines through it), antennae.
	m.box(Vector3(0, 1.97, -0.05), Vector3(0.5, 0.26, 0.45), steel)
	m.box(Vector3(0, 1.97, -0.28), Vector3(0.42, 0.11, 0.02), Color(0.05, 0.05, 0.05))
	m.rod(Vector3(0.18, 2.1, 0.1), Vector3(0.2, 2.35, 0.12), 0.01, DARK, 4)
	m.rod(Vector3(0.2, 2.35, 0.12), Vector3(0.2, 2.36, 0.12), 0.02, Color(0.8, 0.15, 0.1), 6, true)
	# The shoulders the arms hang from.
	for sx in [-1.0, 1.0]:
		m.rod(Vector3(sx * 0.42, 1.6, 0), Vector3(sx * 0.56, 1.6, 0), 0.11, steel, 10, true)
	m.commit(body, "Shell", true, 0.55, 0.3)
	if lamp:
		lamp.position = Vector3(0, 1.97, -0.295)
		lamp.scale = Vector3(0.36, 0.05, 0.02)
		lamp.material_override = ArtPalette.glow(Color(1.0, 0.55, 0.1), 3.0)
	for side in ["ArmL", "ArmR"]:
		var pivot := body.get_node_or_null(side) as Node3D
		if pivot == null:
			continue
		for c in pivot.get_children():
			if c is MeshInstance3D:
				c.visible = false
		var a := ArtMesh.new()
		a.rod(Vector3(0, 0, 0), Vector3(0, -0.55, 0), 0.07, steel, 8)  # upper arm
		a.rod(Vector3(0, -0.12, 0.06), Vector3(0, -0.5, 0.06), 0.025, Color(0.75, 0.76, 0.78), 6)  # its ram
		a.rod(Vector3(0, -0.55, 0), Vector3(0, -0.57, 0), 0.09, DARK, 10, true)  # the elbow
		a.rod(Vector3(0, -0.57, 0), Vector3(0, -0.95, 0), 0.06, paint.darkened(0.1), 8)
		for k in [-1.0, 1.0]:  # the claw's two fingers
			a.rod(Vector3(0, -0.95, 0), Vector3(k * 0.08, -1.05, -0.04), 0.025, DARK, 6)
			a.rod(Vector3(k * 0.08, -1.05, -0.04), Vector3(k * 0.04, -1.12, -0.08), 0.02, DARK, 6)
		a.commit(pivot, "Arm", true, 0.5, 0.4)
