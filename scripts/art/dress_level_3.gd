class_name DressLevel3
extends RefCounted
## Furnishing for Level 3, floor 18: the Records Archive at night. Lino and painted
## block in the lobby and halls, a carpeted reading room with oak panelling, the
## stacks in grey-green enamel shelving, compact rolling shelving in the side rooms,
## an industrial shredding room, the microfiche room with its dead tube, and
## Mercer's off-grid room. Called once at the end of Level 3's build(), before
## navigation bakes.
##
## Nothing added here collides. The Shredder walks a navmesh baked from the level's
## colliders and grabs only what nothing solid stands in front of, and the stacks'
## tops and ends are a route; so every prop is visual only and stands against a wall
## or inside a Greybox block that's already there (ArtDress.hide_block keeps that
## block's collider). Big pieces are built as one mesh each (ArtMesh): the five
## stack units, with all their boxes, are five draws instead of eight hundred.
## Papers on the walls are ordinary archive life, never hints.

const LOBBY := AABB(Vector3(-3.9, -0.5, 4.1), Vector3(7.8, 4.0, 3.8))
const READING := AABB(Vector3(-7.9, -0.5, -5.9), Vector3(15.8, 4.0, 9.8))
const STACKS := AABB(Vector3(-7.9, -0.5, -21.9), Vector3(15.8, 6.5, 15.8))
const HALL_W := AABB(Vector3(-10.9, -0.5, -21.9), Vector3(2.8, 4.0, 19.8))
const HALL_E := AABB(Vector3(8.1, -0.5, -21.9), Vector3(2.8, 4.0, 19.8))
const NORTH := AABB(Vector3(-10.9, -0.5, -24.9), Vector3(21.8, 4.0, 2.8))
const SHRED := AABB(Vector3(-10.9, -0.5, -32.9), Vector3(10.8, 4.4, 7.8))
const FICHE := AABB(Vector3(2.1, -0.5, -30.9), Vector3(8.8, 4.0, 5.8))
const SUPPLY := AABB(Vector3(11.1, -0.5, -11.9), Vector3(2.8, 4.0, 2.8))
## The three big side rooms and the safe rooms that can be behind them (all of
## them: which one is real changes with the run).
const SIDE := [AABB(Vector3(-15.9, -0.5, -21.9), Vector3(4.8, 4.0, 5.8)), AABB(Vector3(-15.9, -0.5, -13.9), Vector3(4.8, 4.0, 5.8)),
	AABB(Vector3(11.1, -0.5, -21.9), Vector3(4.8, 4.0, 5.8))]
const SAFE := [AABB(Vector3(-20.9, -0.5, -21.9), Vector3(4.8, 4.0, 5.8)), AABB(Vector3(-20.9, -0.5, -13.9), Vector3(4.8, 4.0, 5.8)),
	AABB(Vector3(16.1, -0.5, -21.9), Vector3(4.8, 4.0, 5.8))]
## Every room and corridor, for ArtDress.explain_dark.
const DARK_CHECK := [LOBBY, READING, STACKS, HALL_W, HALL_E, NORTH, SHRED, FICHE, SUPPLY, SIDE[0], SIDE[1], SIDE[2]]

## The archive's enamel and cardboard.
const ENAMEL := Color(0.4, 0.44, 0.41)  # grey-green steel shelving
const DECK := Color(0.52, 0.55, 0.51)
const SPINE := Color(0.24, 0.26, 0.25)
const CLIMB := Color(0.45, 0.3, 0.22)  # Traversal.RUST: what you can climb is this colour everywhere
const BOX_TONES: Array[Color] = [Color(0.68, 0.55, 0.38), Color(0.75, 0.64, 0.46), Color(0.86, 0.84, 0.78), Color(0.6, 0.58, 0.55), Color(0.71, 0.6, 0.43)]
const HOLE := Color(0.1, 0.08, 0.07)
const CARD := Color(0.93, 0.91, 0.85)
const OAK := Color(1.0, 0.82, 0.62)  # laminate tint


static func apply(level: LevelBase) -> void:
	var geo := level.geo
	var dress := ArtDress.dressing_root(level)
	var lino := ArtPalette.surface("floor_tile", Color(0.86, 0.9, 0.86))
	var block := ArtPalette.surface("drywall", Color(0.93, 1.0, 0.98))
	var concrete := ArtPalette.surface("concrete", Color(1.1, 1.1, 1.06))
	var steel := ArtPalette.flat(Color(0.5, 0.52, 0.53), 0.45, 0.6)
	ArtDress.reskin(geo, [
		{"names": ["RecordsDesk", "CardCatalogue"], "mat": ArtPalette.surface("laminate", OAK)},
		{"names": ["Table"], "mat": ArtPalette.surface("laminate", OAK)},
		{"names": ["ReturnsCart", "CartPost", "Rail", "SlipSpike"], "mat": steel},
		{"names": ["DoorWedge"], "mat": ArtPalette.flat(Color(0.55, 0.4, 0.22), 0.8)},
		{"names": ["Floor"], "zone": READING, "mat": ArtPalette.surface("carpet", Color(1.1, 1.0, 0.78))},
		{"names": ["Floor"], "zone": FICHE, "mat": ArtPalette.surface("carpet", Color(0.95, 0.95, 1.05))},
		{"names": ["Floor"], "zone": STACKS, "mat": ArtPalette.surface("concrete", Color(1.2, 1.2, 1.16))},
		{"names": ["Ceiling"], "zone": STACKS, "mat": ArtPalette.surface("concrete", Color(0.8, 0.8, 0.8))},
		{"names": ["Wall_"], "zone": STACKS, "mat": ArtPalette.surface("drywall", Color(0.82, 0.88, 0.9))},
		{"names": ["Floor", "Wall_"], "zone": SHRED, "mat": concrete},
		{"names": ["Floor"], "zone": SIDE[0], "mat": concrete},
		{"names": ["Floor"], "zone": SIDE[1], "mat": concrete},
		{"names": ["Floor"], "zone": SIDE[2], "mat": concrete},
		{"names": ["Floor"], "zone": SUPPLY, "mat": concrete},
		{"names": ["Floor", "Wall_", "Ceiling"], "zone": SAFE[0], "mat": ArtPalette.surface("concrete", Color(0.95, 0.9, 0.82))},
		{"names": ["Floor", "Wall_", "Ceiling"], "zone": SAFE[1], "mat": ArtPalette.surface("concrete", Color(0.95, 0.9, 0.82))},
		{"names": ["Floor", "Wall_", "Ceiling"], "zone": SAFE[2], "mat": ArtPalette.surface("concrete", Color(0.95, 0.9, 0.82))},
		{"names": ["Floor"], "mat": lino},
		{"names": ["Wall_"], "mat": block},
		{"names": ["Ceiling"], "mat": ArtPalette.surface("ceiling_tile")},
	])
	var legs := ArtPalette.flat(Color(0.22, 0.2, 0.18), 0.6, 0.3)
	for b in geo.get_children():
		if b is StaticBody3D and String(b.name).begins_with("TableLeg"):
			for mi in b.get_children():
				if mi is MeshInstance3D:
					mi.material_override = legs

	_lobby(level, dress)
	_reading_room(level, dress)
	_stacks(level, dress)
	_halls(dress)
	_side_rooms(level, dress)
	_supply(level, dress)
	_shredding_room(level, dress)
	_microfiche(level, dress)
	_safe_room(level, dress)

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

## The lift lobby: the dead lifts taped off, a bench, a clock and the fire notice.
static func _lobby(level: LevelBase, dress: Node3D) -> void:
	ArtDress.skirting(dress, Vector3(0, 0, 6), Vector3(8, 3.2, 4), [
		{"wall": "n", "at": 0.0, "width": 2.4}, {"wall": "w", "at": 0.0, "width": Stairwell.DOOR_W}, {"wall": "e", "at": 0.0, "width": Stairwell.DOOR_W}])
	var m := ArtMesh.new()
	var frame := Color(0.62, 0.64, 0.66)
	var leaf := Color(0.55, 0.57, 0.6)
	for x in [-1.5, 1.5]:
		# Brushed-steel doors in a frame, taped across: out of service (the memo).
		for side in [-1.0, 1.0]:
			m.box(Vector3(x + side * 0.33, 1.1, 7.855), Vector3(0.64, 2.18, 0.02), leaf, 0.0, ["-z"])
		m.box(Vector3(x, 1.1, 7.85), Vector3(0.008, 2.18, 0.03), Color(0.2, 0.2, 0.22))  # the seam
		for side in [-1.0, 1.0]:
			m.box(Vector3(x + side * 0.72, 1.12, 7.84), Vector3(0.1, 2.3, 0.08), frame)
		m.box(Vector3(x, 2.3, 7.84), Vector3(1.54, 0.12, 0.08), frame)
		for tilt in [-24.0, 24.0]:
			var tape := Basis(Vector3.FORWARD, deg_to_rad(tilt))
			m.plate(Vector3(x, 1.25, 7.83), tape * Vector3(-0.62, 0, 0), tape * Vector3(0, 0.035, 0), ArtPalette.SAFETY_YELLOW)
		# The call buttons, dark: the lifts have no power.
		var px: float = x + signf(x) * 0.95
		m.box(Vector3(px, 1.1, 7.885), Vector3(0.12, 0.26, 0.02), frame)
		for y in [1.04, 1.16]:
			m.box(Vector3(px, y, 7.873), Vector3(0.04, 0.04, 0.01), Color(0.25, 0.25, 0.26))
	# A bench either side of the way in, under the archive's name.
	for x in [-2.4, 2.4]:
		m.box(Vector3(x, 0.44, 4.45), Vector3(1.4, 0.05, 0.42), Color(0.55, 0.4, 0.26))
		for sx in [-0.6, 0.6]:
			m.box(Vector3(x + sx, 0.21, 4.45), Vector3(0.05, 0.42, 0.36), Color(0.22, 0.22, 0.23))
	m.commit(dress, "Lobby", true, 0.5, 0.4)
	_clock(dress, Vector3(-2.4, 2.05, 4.13), 180, 7.4)
	ArtProps.fire_extinguisher(dress, Vector3(3.5, 1.1, 4.11), 180)
	ArtProps.poster(dress, Vector3(2.4, 1.55, 4.11), 180,
		"IN CASE OF FIRE\nDO NOT USE ELEVATOR\n\nUSE STAIRS", Vector2(0.5, 0.4), Color(0.93, 0.92, 0.86), 22)
	ArtDress.visual_only(ArtProps.potted_plant(dress, Vector3(-3.55, 0, 7.5)))


## A wall clock with its back on the wall at `pos` (its bottom edge), face out,
## its hands at `hour` (all the clocks on the floor agree).
static func _clock(dress: Node3D, pos: Vector3, facing_deg: float, hour: float) -> void:
	var clock := ArtProps.model(dress, "wall_clock", pos, facing_deg, Vector3.ONE, false)
	var m := ArtMesh.new()
	var c := Vector3(0, 0.16, -0.03)
	var ink := Color(0.08, 0.08, 0.08)
	for k in 12:
		var a := TAU * k / 12.0
		var at := c + Vector3(sin(a), cos(a), 0) * 0.118
		m.plate(at, Vector3(-cos(a), sin(a), 0) * 0.004, Vector3(sin(a), cos(a), 0) * (0.012 if k % 3 == 0 else 0.007), ink)
	for hand in [[hour / 12.0, 0.07, 0.007], [fmod(hour, 1.0), 0.105, 0.005]]:
		var a: float = TAU * hand[0]
		var dir := Vector3(sin(a), cos(a), 0)
		m.plate(c + dir * hand[1] * 0.4 + Vector3(0, 0, -0.002), Vector3(-cos(a), sin(a), 0) * hand[2], dir * hand[1] * 0.6, ink)
	m.commit(clock, "Hands")


# --- Reading room and records desk -------------------------------------------------

static func _reading_room(level: LevelBase, dress: Node3D) -> void:
	var geo := level.geo
	var gaps := [{"wall": "s", "at": 0.0, "width": 2.4}, {"wall": "n", "at": -4.0, "width": 2.0}, {"wall": "n", "at": 4.0, "width": 2.0},
		{"wall": "w", "at": -3.0, "width": 1.0}, {"wall": "e", "at": -3.0, "width": 1.0}]
	# Oak panelling to dado height, and a rail along its top.
	var oak := ArtPalette.surface("laminate", Color(0.85, 0.68, 0.5))
	ArtDress.skirting(dress, Vector3(0, 0, -1), Vector3(16, 3.2, 10), gaps, 0.9, oak)
	ArtDress.skirting(dress, Vector3(0, 0.88, -1), Vector3(16.04, 3.2, 10.04), gaps, 0.05, ArtPalette.flat(Color(0.35, 0.25, 0.16), 0.6))
	var m := ArtMesh.new()
	var wood := Color(0.5, 0.36, 0.22)
	var dark_wood := Color(0.32, 0.22, 0.14)
	# The records desk: a counter with a lip, a kick plate and slats on its public face.
	m.box(Vector3(0, 1.015, 1.6), Vector3(4.08, 0.03, 0.88), dark_wood)
	m.box(Vector3(0, 0.05, 1.205), Vector3(4.0, 0.1, 0.02), Color(0.15, 0.13, 0.12))
	for k in 20:
		m.box(Vector3(-1.9 + k * 0.2, 0.55, 1.195), Vector3(0.012, 0.88, 0.012), dark_wood)
	# Card catalogue: a hundred little drawers, each with a brass pull and a card frame.
	var brass := Color(0.72, 0.58, 0.3)
	for row in 9:
		for col in 12:
			var y := 0.12 + row * 0.14
			var z := 1.0 - 1.8 + 0.15 + col * 0.3
			m.box(Vector3(-7.047, y + 0.06, z), Vector3(0.006, 0.124, 0.29), Color(0.42, 0.29, 0.17), 0.0, ["-x"])
			m.box(Vector3(-7.04, y + 0.085, z), Vector3(0.004, 0.035, 0.08), CARD, 0.0, ["-x"])
			m.box(Vector3(-7.037, y + 0.04, z), Vector3(0.012, 0.018, 0.05), brass, 0.0, ["-x"])
	m.box(Vector3(-7.5, 1.415, 1.0), Vector3(0.96, 0.03, 3.66), dark_wood)
	m.box(Vector3(-7.5, 0.03, 1.0), Vector3(0.92, 0.06, 3.62), Color(0.15, 0.13, 0.12))
	# The returns cart: a handle, castors under its lower shelf.
	for z in [0.05, 2.55]:
		for x in [6.8, 7.4]:
			m.rod(Vector3(x, 0.0, z), Vector3(x, 0.08, z), 0.04, Color(0.12, 0.12, 0.12), 6, true)
	m.rod(Vector3(7.42, 0.95, 0.0), Vector3(7.42, 0.95, 2.6), 0.015, Color(0.15, 0.15, 0.16))
	m.commit(dress, "ReadingRoom", true, 0.6)
	# Chairs round the reading tables and a lamp on each, off after hours.
	for tx in [-4.5, 4.5]:
		for dx in [-0.7, 0.7]:
			ArtProps.model(dress, "wood_chair", Vector3(tx + dx, 0, -3.0 - 0.85), 180)
			ArtProps.model(dress, "wood_chair", Vector3(tx + dx, 0, -3.0 + 0.85), 0)
		ArtProps.model(dress, "desk_lamp", Vector3(tx - 0.8, 0.75, -3.25), 30.0, Vector3.ONE, false)
		ArtProps.model(dress, "desk_lamp", Vector3(tx + 0.8, 0.75, -2.75), 210.0, Vector3.ONE, false)
	# Behind the desk: the clerk's chair, a lamp and an in-tray.
	ArtDress.visual_only(ArtProps.office_chair(dress, Vector3(-0.6, 0, 2.55), 0))
	ArtProps.model(dress, "desk_lamp", Vector3(-1.5, 1.03, 1.35), 200.0, Vector3.ONE, false)
	_clock(dress, Vector3(3.2, 2.45, 3.89), 0, 7.4)
	ArtProps.poster(dress, Vector3(-3.2, 1.6, 3.89), 0, "QUIET PLEASE\n\nThe reading room is\nfor study.", Vector2(0.45, 0.5))
	ArtProps.poster(dress, Vector3(-7.89, 1.6, -1.2), -90,
		"READING ROOM\n\nNo food or drink.\nPencils only.\nReturn all boxes\nto the desk.", Vector2(0.45, 0.6))
	ArtProps.fire_extinguisher(dress, Vector3(7.89, 1.1, -5.0), 90)


# --- The stacks ---------------------------------------------------------------------

## The stacks: each shelf unit (a solid block you climb and walk along the top of) is
## drawn as enamel shelving full of archive boxes, one mesh per unit, with a fixed
## ladder in the climbing colour on both ends. The level's own placeholder pieces
## for the units go; their labels stay.
static func _stacks(level: LevelBase, dress: Node3D) -> void:
	var geo := level.geo
	var l3 = level
	var units: Array = l3.stack_units
	var tags: Array[Label3D] = []
	for u in units:
		var c: Vector3 = (u as Node3D).position
		var bounds := AABB(Vector3(c.x - 0.63, -0.1, -20.06), Vector3(1.26, 3.8, 10.12))
		for child in geo.get_children():
			if child is MeshInstance3D and bounds.has_point(child.position):
				child.free()
			elif child is Label3D and bounds.grow(0.05).has_point(child.position):
				tags.append(child)
	for i in units.size():
		_stack_unit(dress, (units[i] as Node3D).position, i, tags)
	for b in geo.get_children():
		if b is StaticBody3D and String(b.name).begins_with("Climbable") and STACKS.has_point(b.position):
			ArtDress.hide_block(b)
	# The records cart left in an aisle: a book truck with a few boxes on it.
	var cart := _block(geo, "RecordsCart", Vector3(1.5, 0.45, -12))
	if cart:
		ArtDress.hide_block(cart)
		var m := ArtMesh.new()
		var grey := Color(0.5, 0.52, 0.53)
		var p := cart.position - Vector3(0, 0.45, 0)
		for y in [0.18, 0.86]:
			m.box(p + Vector3(0, y, 0), Vector3(0.66, 0.03, 1.06), grey)
		for sz in [-1.0, 1.0]:
			m.box(p + Vector3(0, 0.5, sz * 0.52), Vector3(0.66, 0.84, 0.02), grey)
			for sx in [-1.0, 1.0]:
				m.rod(p + Vector3(sx * 0.26, 0, sz * 0.42), p + Vector3(sx * 0.26, 0.09, sz * 0.42), 0.045, Color(0.1, 0.1, 0.1), 6, true)
		for k in 2:
			m.box(p + Vector3(0, 0.88 + 0.14, -0.25 + k * 0.48), Vector3(0.38, 0.27, 0.32), BOX_TONES[k + 1])
		m.box(p + Vector3(0.05, 0.2 + 0.14, 0.1), Vector3(0.4, 0.27, 0.32), BOX_TONES[0])
		m.commit(dress, "RecordsCart", true, 0.6, 0.3)
	# Overhead: sprinkler mains above the aisles, and the occupancy sensors that keep
	# the stacks dark after hours.
	var o := ArtMesh.new()
	for x in [-4.5, 1.5]:
		o.rod(Vector3(x, 5.56, -21.8), Vector3(x, 5.56, -6.2), 0.025, Color(0.5, 0.2, 0.16), 6)
		for z in range(-20, -6, 3):
			o.rod(Vector3(x, 5.56, z), Vector3(x, 5.48, z), 0.01, Color(0.7, 0.7, 0.68), 5, true)
	for z in [-9.0, -14.0, -19.0]:
		o.rod(Vector3(1.0, 5.6, z), Vector3(1.0, 5.55, z), 0.05, Color(0.9, 0.9, 0.88), 8, true)
		o.box(Vector3(1.0, 5.545, z + 0.03), Vector3(0.012, 0.008, 0.012), Color(0.6, 0.1, 0.08))
	o.commit(dress, "StacksCeiling")


## One stack unit, centred at `c` (Greybox's block: 1.2 wide, 3.6 tall, 10 long along z).
static func _stack_unit(dress: Node3D, c: Vector3, index: int, tags: Array[Label3D]) -> void:
	var m := ArtMesh.new()
	var length := 10.0
	var height := 3.6
	var z0 := c.z - length / 2.0
	m.box(Vector3(c.x, height / 2.0, c.z), Vector3(0.03, height - 0.04, length - 0.04), SPINE, 0.0, ["top", "bottom"])
	for k in 6:
		for sx in [-0.575, 0.575]:
			m.box(Vector3(c.x + sx, height / 2.0, z0 + 0.03 + k * (length - 0.06) / 5.0), Vector3(0.05, height, 0.05), ENAMEL)
	for lvl in 8:
		var y := 0.05 + lvl * 0.5
		if lvl == 7:
			m.box(Vector3(c.x, height - 0.015, c.z), Vector3(1.2, 0.03, length), Color(0.47, 0.49, 0.46))  # the top deck you walk on
		else:
			m.box(Vector3(c.x, y, c.z), Vector3(1.14, 0.02, length - 0.04), DECK, 0.0, ["-z", "+z"])
		for sx in [-0.585, 0.585]:
			m.box(Vector3(c.x + sx, y - 0.01, c.z), Vector3(0.03, 0.05, length), ENAMEL, 0.0, ["-z", "+z"])  # the shelf lips
	# End panels, each with a fixed ladder: the way up.
	for end in [-1.0, 1.0]:
		var ez: float = c.z + end * length / 2.0
		m.box(Vector3(c.x, height / 2.0, ez - end * 0.012), Vector3(1.2, height, 0.024), ENAMEL)
		var out: float = ez + end * 0.07
		for rx in [-0.2, 0.2]:
			m.box(Vector3(c.x + rx, (height + 0.25) / 2.0, out), Vector3(0.04, height + 0.25, 0.03), CLIMB)
			for y in [0.4, 1.8, 3.2]:
				m.box(Vector3(c.x + rx, y, ez + end * 0.035), Vector3(0.03, 0.03, 0.06), CLIMB)  # standoffs
		var rung := 0.3
		while rung < height:
			m.rod(Vector3(c.x - 0.2, rung, out), Vector3(c.x + 0.2, rung, out), 0.016, CLIMB, 6)
			rung += 0.3
		# The aisle's number plate, behind the level's label.
		m.box(Vector3(c.x, 3.2, ez + end * 0.11), Vector3(0.34, 0.2, 0.01), Color(0.12, 0.15, 0.22))
	# Shelf tags behind the catalogue labels on the shelf lips.
	for t in tags:
		if absf(t.position.x - (c.x + 0.61)) < 0.05:
			m.box(Vector3(c.x + 0.598, t.position.y, t.position.z), Vector3(0.006, 0.1, 0.26), CARD)
	# Archive boxes, end-on to the aisle, a few tones, with gaps where the shelves are
	# empty. Cosmetic, so the layout comes from the unit's index, not the run seed.
	# Their own mesh, with no shadow: the decks shade them already, and a thousand
	# boxes in every lamp's shadow pass would cost more than they show.
	var boxes := ArtMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + index
	for lvl in 7:
		var y := 0.06 + lvl * 0.5
		for face in [-1.0, 1.0]:
			var z := z0 + 0.1
			while z < c.z + length / 2.0 - 0.4:
				if rng.randf() < 0.12:
					z += rng.randf_range(0.4, 1.2)  # an empty stretch
					continue
				var w := rng.randf_range(0.3, 0.34)
				var h := rng.randf_range(0.25, 0.28)
				var tone: Color = BOX_TONES[rng.randi_range(0, BOX_TONES.size() - 1)]
				_archive_box(boxes, Vector3(c.x + face * 0.355, y, z + w / 2.0), Vector3(0.42, h, w), tone, face, rng.randf() < 0.85)
				z += w + 0.012
	var unit := m.commit(dress, "StackUnit", true, 0.8)
	boxes.commit(unit, "Boxes", false, 0.8)


## An archive box standing on a shelf at `base` (bottom centre), its end facing the
## aisle on side `face` (+1 or -1 along x): a lid line, a hand hole and its card.
static func _archive_box(m: ArtMesh, base: Vector3, size: Vector3, tone: Color, face: float, labelled: bool) -> void:
	m.box(base + Vector3(0, size.y / 2.0, 0), size, tone, 0.0, ["bottom", "-x" if face > 0 else "+x"])
	var fx: float = base.x + face * (size.x / 2.0 + 0.002)
	var n := Vector3(face, 0, 0)
	var along := Vector3.UP.cross(n)
	m.plate(Vector3(fx, base.y + size.y - 0.025, base.z), along * (size.z / 2.0), Vector3(0, 0.022, 0), tone.darkened(0.18))
	m.plate(Vector3(fx, base.y + size.y - 0.08, base.z), along * 0.04, Vector3(0, 0.015, 0), HOLE)
	if labelled:
		m.plate(Vector3(fx, base.y + size.y * 0.42, base.z), along * 0.06, Vector3(0, 0.035, 0), CARD)


# --- Halls and the north corridor ---------------------------------------------------

static func _halls(dress: Node3D) -> void:
	ArtDress.skirting(dress, Vector3(-9.5, 0, -12), Vector3(3, 3.2, 20), [
		{"wall": "e", "at": 8.0, "width": 1.0}, {"wall": "e", "at": -2.0, "width": 1.0}, {"wall": "n", "at": 0.0, "width": 1.6},
		{"wall": "w", "at": -7.0, "width": 1.0}, {"wall": "w", "at": 1.0, "width": 1.0}])
	ArtDress.skirting(dress, Vector3(9.5, 0, -12), Vector3(3, 3.2, 20), [
		{"wall": "w", "at": 8.0, "width": 1.0}, {"wall": "w", "at": -2.0, "width": 1.0}, {"wall": "n", "at": 0.0, "width": 1.6},
		{"wall": "e", "at": -7.0, "width": 1.0}, {"wall": "e", "at": 1.5, "width": 1.0}])
	ArtDress.skirting(dress, Vector3(0, 0, -23.5), Vector3(22, 3.2, 3), [
		{"wall": "s", "at": -9.5, "width": 1.6}, {"wall": "s", "at": 9.5, "width": 1.6}, {"wall": "s", "at": -4.0, "width": 2.0},
		{"wall": "s", "at": 4.0, "width": 2.0}, {"wall": "n", "at": -5.5, "width": 2.4}, {"wall": "n", "at": 6.5, "width": 1.0}])
	ArtProps.fire_extinguisher(dress, Vector3(-10.89, 1.1, -3.2), -90)
	ArtProps.fire_extinguisher(dress, Vector3(10.89, 1.1, -21.2), 90)
	ArtProps.poster(dress, Vector3(-8.11, 1.6, -9.0), 90,
		"RECORDS ARE COMPANY PROPERTY\n\nNo box leaves this floor\nwithout a signed slip.", Vector2(0.45, 0.55))
	ArtProps.poster(dress, Vector3(8.11, 1.6, -18.0), -90,
		"SAFETY FIRST\n\nUse the step stools.\nNever climb the shelving.", Vector2(0.45, 0.55))
	ArtProps.model(dress, "utility_box", Vector3(10.9 - 0.18, 0.95, -6.5), 90, Vector3(1, 0.8, 1), false)
	# North corridor: hearing protection by the shredding room, the roll-up's slats.
	ArtProps.poster(dress, Vector3(-8.2, 1.6, -24.89), 180,
		"HEARING PROTECTION\nREQUIRED\n\nShredders in use.", Vector2(0.42, 0.5), Color(0.2, 0.36, 0.62), 30)
	ArtProps.fire_extinguisher(dress, Vector3(1.5, 1.1, -24.89), 180)


# --- Side rooms: compact rolling shelving --------------------------------------------

## The three big side rooms: each rolling unit becomes compact shelving that rolls with
## it (the look is a child of the moving body), the front one with its crank wheel.
## Vault C keeps boxes, the map room rolled plans, the cold store film cans and tapes.
static func _side_rooms(level: LevelBase, dress: Node3D) -> void:
	var l3 = level
	var shelving: Dictionary = l3.shelving
	var cranks: Dictionary = l3.cranks
	var specs: Dictionary = l3.SIDE_ROOMS
	var size: Vector3 = l3.UNIT_SIZE
	for room in shelving:
		var units: Array = shelving[room]
		var c: Vector3 = specs[room].center
		var paint: Color = {"VAULT C": Color(0.78, 0.74, 0.62), "MAP ROOM": Color(0.5, 0.58, 0.64), "COLD STORE": Color(0.84, 0.86, 0.86)}.get(room, ENAMEL)
		for i in units.size():
			var body: Node3D = units[i]
			for child in body.get_children():
				if child is MeshInstance3D:
					child.visible = false
			_rolling_unit(body, size, paint, room, i, i == units.size() - 1)
		var crank: Node = cranks.get(room)
		if crank:
			for child in crank.get_children():
				if child is MeshInstance3D:
					child.visible = false
		# Two more floor rails for the carriages.
		var r := ArtMesh.new()
		for dz in [-2.2, 2.2]:
			r.box(Vector3(c.x, 0.01, c.z + dz), Vector3(4.6, 0.02, 0.08), Color(0.45, 0.47, 0.48))
		r.commit(dress, "Rails", false, 0.4, 0.6)


static func _rolling_unit(body: Node3D, size: Vector3, paint: Color, room: String, index: int, front: bool) -> void:
	var m := ArtMesh.new()
	var h := size / 2.0
	m.box(Vector3(0, -h.y + 0.06, 0), Vector3(size.x, 0.12, size.z), Color(0.2, 0.2, 0.21))  # the carriage
	m.box(Vector3(0, 0, 0), Vector3(0.02, size.y - 0.1, size.z - 0.1), SPINE, 0.0, ["top", "bottom"])
	m.box(Vector3(0, h.y - 0.015, 0), Vector3(size.x, 0.03, size.z), paint)
	for end in [-1.0, 1.0]:
		m.box(Vector3(0, 0.03, end * (h.z - 0.015)), Vector3(size.x, size.y - 0.06, 0.03), paint)
		m.box(Vector3(0, 0.75, end * (h.z + 0.002)), Vector3(0.14, 0.09, 0.004), CARD)  # the range card
	var stock := ArtMesh.new()  # what's on the shelves: no shadow, as in the stacks
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(room) + index
	for lvl in 5:
		var y := -h.y + 0.14 + lvl * 0.48
		m.box(Vector3(0, y, 0), Vector3(size.x - 0.02, 0.02, size.z - 0.08), DECK, 0.0, ["-z", "+z"])
		for face in [-1.0, 1.0]:
			var z := -h.z + 0.1
			while z < h.z - 0.35:
				if rng.randf() < 0.15:
					z += rng.randf_range(0.3, 0.8)
					continue
				match room:
					"MAP ROOM":
						# Rolled plans, lying along the shelf.
						var len_ := rng.randf_range(0.5, 0.9)
						for k in rng.randi_range(3, 6):
							var r := rng.randf_range(0.022, 0.035)
							var px: float = face * (0.05 + (k % 3) * 0.075)
							var tone := Color(0.9, 0.88, 0.8).lerp(Color(0.7, 0.75, 0.82), rng.randf())
							stock.rod(Vector3(px, y + 0.01 + r + (k / 3) * 0.065, z), Vector3(px, y + 0.01 + r + (k / 3) * 0.065, z + len_), r, tone, 6, true)
						z += len_ + 0.05
					"COLD STORE":
						# Film cans in stacks, and tapes in grey cases.
						if rng.randf() < 0.5:
							for k in rng.randi_range(3, 7):
								stock.rod(Vector3(face * 0.15, y + 0.01 + k * 0.035, z + 0.17), Vector3(face * 0.15, y + 0.04 + k * 0.035, z + 0.17), 0.16, Color(0.55, 0.57, 0.58) if k % 2 == 0 else Color(0.4, 0.42, 0.44), 8, true)
							z += 0.36
						else:
							for k in 4:
								stock.box(Vector3(face * 0.15, y + 0.13, z + 0.05 + k * 0.05), Vector3(0.24, 0.24, 0.04), Color(0.3, 0.31, 0.33))
							z += 0.24
					_:
						var w := rng.randf_range(0.3, 0.34)
						_archive_box(stock, Vector3(face * 0.155, y + 0.01, z + w / 2.0), Vector3(0.27, rng.randf_range(0.25, 0.28), w), BOX_TONES[rng.randi_range(0, BOX_TONES.size() - 1)], face, rng.randf() < 0.8)
						z += w + 0.012
	if front:
		# The crank: a three-spoke wheel with a handle, on the end by the door.
		var at := Vector3(0, -0.1, h.z + 0.08)
		m.rod(Vector3(0, at.y, h.z), at, 0.025, Color(0.25, 0.25, 0.26), 6)
		for k in 3:
			var a := TAU * k / 3.0
			m.rod(at, at + Vector3(cos(a), sin(a), 0) * 0.19, 0.012, Color(0.3, 0.3, 0.32), 5)
		for k in 12:
			var a0 := TAU * k / 12.0
			var a1 := TAU * (k + 1) / 12.0
			m.rod(at + Vector3(cos(a0), sin(a0), 0) * 0.19, at + Vector3(cos(a1), sin(a1), 0) * 0.19, 0.014, Color(0.3, 0.3, 0.32), 5)
		var knob := at + Vector3(0.19, 0, 0)
		m.rod(knob, knob + Vector3(0, 0, 0.1), 0.018, Color(0.12, 0.12, 0.12), 6, true)
	var look := m.commit(body, "Look", true, 0.7, 0.2)
	stock.commit(look, "Stock", false, 0.75)


# --- Supply closet ---------------------------------------------------------------------

static func _supply(level: LevelBase, dress: Node3D) -> void:
	_hide(level.geo, "SupplyShelf", Vector3(13.6, 1.0, -10.5))
	var m := ArtMesh.new()
	for z in [-11.0, -10.0]:
		ArtProps.model(dress, "metal_rack", Vector3(13.6, 0, z), 90)
		for k in 3:
			var y := 0.47 + k * 0.48
			m.box(Vector3(13.6, y + 0.1, z - 0.2), Vector3(0.28, 0.2, 0.22), Color(0.92, 0.92, 0.9))  # reams of paper
			m.box(Vector3(13.6, y + 0.12, z + 0.18), Vector3(0.36, 0.24, 0.3), BOX_TONES[k])
	m.rod(Vector3(12.0, 0, -11.6), Vector3(12.0, 0.3, -11.6), 0.15, Color(0.75, 0.6, 0.15), 8, true)  # a mop bucket
	m.rod(Vector3(12.0, 0.25, -11.6), Vector3(11.75, 1.4, -11.75), 0.015, Color(0.6, 0.5, 0.35))
	m.commit(dress, "Supplies", true)


# --- Shredding room ---------------------------------------------------------------------

static func _shredding_room(level: LevelBase, dress: Node3D) -> void:
	var geo := level.geo
	var m := ArtMesh.new()
	var body := Color(0.22, 0.28, 0.27)
	var panel := Color(0.3, 0.36, 0.35)
	# The two industrial shredders: cabinet, feed hopper, louvres, control box,
	# hazard stripes along the kick.
	for x in [-9.0, -6.5]:
		var b := _block(geo, "Shredder", Vector3(x, 0.9, -31.5))
		if b == null:
			continue
		ArtDress.hide_block(b)
		var p := b.position - Vector3(0, 0.9, 0)
		m.box(p + Vector3(0, 0.75, 0), Vector3(1.6, 1.5, 1.2), body)
		m.box(p + Vector3(0, 1.62, 0), Vector3(1.4, 0.24, 1.0), panel)
		m.box(p + Vector3(0, 1.79, 0), Vector3(1.1, 0.1, 0.7), Color(0.2, 0.2, 0.2))
		for k in 6:
			m.box(p + Vector3(-0.5 + k * 0.2, 0.9, 0.602), Vector3(0.12, 0.012, 0.004), Color(0.12, 0.14, 0.14))
		m.box(p + Vector3(0.0, 0.45, 0.602), Vector3(1.0, 0.6, 0.004), panel)  # access panel
		m.box(p + Vector3(0.55, 1.25, 0.66), Vector3(0.32, 0.4, 0.12), Color(0.68, 0.68, 0.64))
		for k in 10:
			m.plate(p + Vector3(-0.72 + k * 0.16, 0.06, 0.603), Vector3(0.04, 0, 0).rotated(Vector3.BACK, 0.6), Vector3(0, 0.05, 0), ArtPalette.SAFETY_YELLOW if k % 2 == 0 else Color(0.08, 0.08, 0.08))
		var lamp := ArtDress.trim(dress, p + Vector3(0.5, 1.33, 0.725), Vector3(0.05, 0.05, 0.02), ArtPalette.glow(Color(0.3, 1.0, 0.4), 2.0))
		lamp.name = "RunLamp"
		ArtDress.trim(dress, p + Vector3(0.6, 1.33, 0.725), Vector3(0.05, 0.05, 0.02), ArtPalette.flat(Color(0.5, 0.08, 0.06), 0.4))
	# The conveyor feeding them: rails, a belt, rollers, legs and a motor.
	var conv := _block(geo, "Conveyor", Vector3(-4.5, 0.4, -29.5))
	if conv:
		ArtDress.hide_block(conv)
		var cp := conv.position
		var steel := Color(0.45, 0.47, 0.48)
		for side in [-1.0, 1.0]:
			m.box(cp + Vector3(0, 0.3, side * 0.42), Vector3(5.0, 0.16, 0.05), steel)
		m.box(cp + Vector3(0, 0.37, 0), Vector3(4.9, 0.03, 0.78), Color(0.1, 0.1, 0.1))
		for x in [-2.45, 2.45]:
			m.rod(cp + Vector3(x, 0.32, -0.4), cp + Vector3(x, 0.32, 0.4), 0.07, Color(0.35, 0.36, 0.37), 8, true)
		for x in [-2.2, -0.7, 0.8, 2.2]:
			for side in [-1.0, 1.0]:
				m.box(cp + Vector3(x, -0.08, side * 0.38), Vector3(0.06, 0.64, 0.06), steel)
			m.box(cp + Vector3(x, -0.3, 0), Vector3(0.05, 0.05, 0.76), steel)
		m.box(cp + Vector3(2.2, -0.05, 0.62), Vector3(0.4, 0.35, 0.3), Color(0.25, 0.3, 0.45))  # the motor
		var rng := RandomNumberGenerator.new()
		rng.seed = 1818
		for k in 18:
			m.box(cp + Vector3(rng.randf_range(-2.3, 2.3), 0.4, rng.randf_range(-0.3, 0.3)), Vector3(0.18, 0.006, 0.12), [CARD, Color(0.8, 0.85, 0.92), Color(0.95, 0.9, 0.6)][k % 3], rng.randf_range(0, 180))
	# The bale: shredded paper pressed into a block, strapped, on a pallet.
	var bale := _block(geo, "PaperBale", Vector3(-9.5, 0.6, -27))
	if bale:
		ArtDress.hide_block(bale)
		var bp := bale.position - Vector3(0, 0.6, 0)
		for k in 3:
			m.box(bp + Vector3(0, 0.04 + k * 0.0, 0) + Vector3(0, 0, -0.45 + k * 0.45), Vector3(1.2, 0.08, 0.14), Color(0.55, 0.42, 0.26))
		m.box(bp + Vector3(0, 0.66, 0), Vector3(1.18, 1.08, 1.18), Color(0.84, 0.82, 0.76))
		var rng := RandomNumberGenerator.new()
		rng.seed = 18
		for k in 10:
			var y := 0.16 + k * 0.1
			var tone: Color = [Color(0.92, 0.91, 0.88), Color(0.76, 0.8, 0.86), Color(0.9, 0.86, 0.62), Color(0.7, 0.7, 0.68)][rng.randi_range(0, 3)]
			for f in 4:
				var yaw := f * 90.0
				var n := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3.BACK
				m.plate(bp + Vector3(0, y, 0) + n * 0.592, n.cross(Vector3.UP) * -0.58, Vector3(0, rng.randf_range(0.02, 0.045), 0), tone)
		for sx in [-0.35, 0.35]:
			m.box(bp + Vector3(sx, 0.66, 0), Vector3(0.025, 1.1, 1.2), Color(0.25, 0.25, 0.26), 0.0, ["bottom"])
	# Paper scraps on the floor, and hazard lines round the machines.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1997
	for k in 40:
		m.box(Vector3(rng2.randf_range(-10.5, -0.5), 0.004, rng2.randf_range(-32.6, -25.5)), Vector3(0.12, 0.004, 0.06), [CARD, Color(0.8, 0.85, 0.92)][k % 2], rng2.randf_range(0, 180))
	for z in [-30.6, -32.85]:
		m.box(Vector3(-7.75, 0.003, z), Vector3(3.5, 0.004, 0.06), ArtPalette.SAFETY_YELLOW)
	for x in [-10.0, -5.5]:
		m.box(Vector3(x, 0.003, -31.72), Vector3(0.06, 0.004, 2.25), ArtPalette.SAFETY_YELLOW)
	# The roll-up door's slats (on the door, so they go up with it).
	var door: Node3D = level.doors.get("ARC-SHRED")
	if door:
		var s := ArtMesh.new()
		for k in 16:
			for face in [-1.0, 1.0]:
				s.box(Vector3(0, -1.12 + k * 0.15, face * 0.045), Vector3(2.36, 0.02, 0.012), Color(0.42, 0.44, 0.45))
		s.box(Vector3(0, -1.17, 0), Vector3(2.4, 0.06, 0.12), Color(0.2, 0.2, 0.21))
		s.commit(door, "Slats", false, 0.5, 0.6)
	m.commit(dress, "ShreddingRoom", true, 0.7, 0.2)
	# Confidential waste bins in place of the bin blocks, and a hand truck by the wall.
	for x in [-2.0, -0.9]:
		var b := _block(geo, "Bin", Vector3(x, 0.55, -32))
		if b:
			ArtDress.hide_block(b)
			ArtProps.model(dress, "wheelie_bin", b.position - Vector3(0, 0.55, 0), 180, Vector3(1.15, 1, 1))
	ArtProps.model(dress, "hand_truck", Vector3(-10.5, 0, -29.6), -90)
	ArtProps.poster(dress, Vector3(-3.0, 1.7, -32.89), 180,
		"DANGER\n\nKeep hands, ties and\nlanyards clear of the\nfeed throat.", Vector2(0.45, 0.55), ArtPalette.SAFETY_YELLOW, 30)
	ArtProps.poster(dress, Vector3(-1.45, 1.75, -32.89), 180, "CONFIDENTIAL\nWASTE ONLY", Vector2(0.5, 0.3), Color(0.2, 0.3, 0.5), 30)


# --- Microfiche room ---------------------------------------------------------------------

static func _microfiche(level: LevelBase, dress: Node3D) -> void:
	var geo := level.geo
	var m := ArtMesh.new()
	var beige := ArtPalette.BEIGE_PLASTIC
	for x in [3.5, 5.5, 7.5]:
		var desk := _block(geo, "FicheDesk", Vector3(x, 0.4, -30.3))
		if desk:
			ArtDress.hide_block(desk)
			ArtProps.model(dress, "metal_desk", desk.position - Vector3(0, 0.4, 0), 180, Vector3(0.725, 1.05, 0.88))
		var reader := _block(geo, "FicheReader", Vector3(x, 1.1, -30.5))
		if reader:
			ArtDress.hide_block(reader)
			var p := reader.position - Vector3(0, 0.3, 0)
			m.box(p + Vector3(0, 0.05, 0.05), Vector3(0.5, 0.1, 0.42), beige)
			m.box(p + Vector3(0, 0.3, -0.12), Vector3(0.48, 0.5, 0.2), beige)
			var tilt := Basis(Vector3.RIGHT, deg_to_rad(-12))
			m.box(p + Vector3(0, 0.38, -0.02), Vector3(0.5, 0.42, 0.06), beige.darkened(0.08), 0.0)
			m.plate(p + Vector3(0, 0.38, 0.012), tilt * Vector3(0.2, 0, 0), tilt * Vector3(0, 0.17, 0), Color(0.06, 0.08, 0.08))
			m.box(p + Vector3(0, 0.115, 0.14), Vector3(0.3, 0.02, 0.18), Color(0.3, 0.3, 0.32))  # the fiche carrier
		ArtProps.model(dress, "wood_chair", Vector3(x, 0, -29.35), 0)
	var intranet := _block(geo, "FicheDesk", Vector3(9.8, 0.4, -27.5))
	if intranet:
		ArtDress.hide_block(intranet)
		ArtProps.model(dress, "metal_desk", intranet.position - Vector3(0, 0.4, 0), 180, Vector3(0.725, 1.05, 0.88))
	# A fiche cabinet against the west wall: shallow drawers, a card frame on each.
	m.box(Vector3(2.42, 0.5, -27.8), Vector3(0.6, 1.0, 1.6), Color(0.55, 0.57, 0.55))
	for row in 6:
		for col in 3:
			var at := Vector3(2.725, 0.12 + row * 0.155, -28.33 + col * 0.53)
			m.box(at + Vector3(0, 0.03, 0), Vector3(0.006, 0.14, 0.5), Color(0.6, 0.62, 0.6), 0.0, ["-x"])
			m.box(at + Vector3(0.004, 0.06, 0), Vector3(0.004, 0.03, 0.09), CARD, 0.0, ["-x"])
			m.box(at + Vector3(0.008, 0.02, 0), Vector3(0.012, 0.015, 0.1), Color(0.3, 0.3, 0.3), 0.0, ["-x"])
	# Why it's dark: the tube's been out since the 9th. A stepladder's been left by the
	# door and the new tubes are still in their box.
	var al := Color(0.7, 0.72, 0.74)
	for rx in [-0.2, 0.2]:
		m.rod(Vector3(3.2 + rx, 0, -25.5), Vector3(3.2 + rx, 1.7, -25.15), 0.02, al, 5, true)
	var step := 0.3
	while step < 1.7:
		var t := step / 1.7
		m.box(Vector3(3.2, step, lerpf(-25.5, -25.15, t) - 0.03), Vector3(0.38, 0.025, 0.09), al)
		step += 0.28
	m.box(Vector3(3.85, 0.62, -25.17), Vector3(0.1, 1.24, 0.08), CARD, -4.0)  # the tube box
	m.commit(dress, "Microfiche", true, 0.6, 0.1)


# --- Mercer's room ---------------------------------------------------------------------------

## Mercer's room behind the host room: the generator, his battery bank wired to an
## inverter, a camp cot, his old wooden desk and the lantern hung over it.
static func _safe_room(level: LevelBase, dress: Node3D) -> void:
	var geo := level.geo
	var l3 = level
	var data: Dictionary = l3.data
	var specs: Dictionary = l3.SIDE_ROOMS
	var spec: Dictionary = specs[data.host]
	var back: Vector3 = spec.back
	var room_x: float = l3.SIDE_ROOM_SIZE.x
	var safe_x: float = l3.SAFE_ROOM_SIZE.x
	var c: Vector3 = spec.center + back * (room_x / 2.0 + safe_x / 2.0)
	var far_x: float = c.x + back.x * (safe_x / 2.0 - 0.6)
	var m := ArtMesh.new()
	var gen := _block(geo, "Generator", Vector3(far_x, 0.5, c.z - 2.0))
	if gen:
		ArtDress.hide_block(gen)
		ArtProps.model(dress, "generator", Vector3(far_x, 0, c.z - 2.0), 90, Vector3(1.4, 1.4, 1.4))
	for i in 3:
		var bat := _block(geo, "Battery", Vector3(far_x, 0.25, c.z - 0.4 + i * 0.6))
		if bat == null:
			continue
		ArtDress.hide_block(bat)
		var p := bat.position - Vector3(0, 0.25, 0)
		m.box(p + Vector3(0, 0.22, 0), Vector3(0.78, 0.44, 0.46), Color(0.1, 0.1, 0.11))
		m.box(p + Vector3(0, 0.455, 0), Vector3(0.8, 0.03, 0.48), Color(0.18, 0.18, 0.2))
		for k in 2:
			var t := p + Vector3(-back.x * 0.25, 0.49, -0.12 + k * 0.24)
			m.rod(t - Vector3(0, 0.02, 0), t + Vector3(0, 0.03, 0), 0.025, Color(0.75, 0.12, 0.08) if k == 0 else Color(0.08, 0.08, 0.08), 6, true)
		if i < 2:
			m.rod(p + Vector3(-back.x * 0.25, 0.52, 0.12), p + Vector3(-back.x * 0.25, 0.52, 0.48), 0.012, Color(0.75, 0.12, 0.08))
	# A cable from the bank to the desk, along the floor.
	m.rod(Vector3(far_x - back.x * 0.4, 0.01, c.z + 0.8), Vector3(c.x - back.x * 0.4, 0.01, c.z - 0.6), 0.012, Color(0.1, 0.1, 0.1))
	m.box(Vector3(far_x - back.x * 0.45, 0.15, c.z + 1.3), Vector3(0.3, 0.3, 0.4), Color(0.6, 0.6, 0.58))  # the inverter
	# The camp cot: canvas on an X frame, a grey blanket folded at its foot.
	var cot := _block(geo, "Cot", Vector3(c.x, 0.2, c.z + 2.2))
	if cot:
		ArtDress.hide_block(cot)
		var p := cot.position - Vector3(0, 0.2, 0)
		m.box(p + Vector3(0, 0.37, 0), Vector3(1.86, 0.03, 0.72), Color(0.36, 0.38, 0.26))
		for sz in [-0.36, 0.36]:
			m.rod(p + Vector3(-0.95, 0.37, sz), p + Vector3(0.95, 0.37, sz), 0.016, Color(0.4, 0.4, 0.38))
		for sx in [-0.7, 0.0, 0.7]:
			for k in 2:
				var s := 1.0 if k == 0 else -1.0
				m.rod(p + Vector3(sx, 0.0, -0.34 * s), p + Vector3(sx, 0.37, 0.34 * s), 0.012, Color(0.4, 0.4, 0.38))
		m.box(p + Vector3(0.68, 0.42, 0), Vector3(0.4, 0.07, 0.66), Color(0.4, 0.41, 0.42))
	# His desk: the pack's old wooden desk, the PC on it facing his chair.
	var desk := _block(geo, "MercerDesk", Vector3(c.x - back.x * 0.4, 0.38, c.z - 1.0))
	if desk:
		ArtDress.hide_block(desk)
		ArtProps.model(dress, "wood_desk", desk.position - Vector3(0, 0.38, 0), 180, Vector3(1.6 / 1.5, 1, 0.8 / 0.7))
		ArtProps.model(dress, "wood_chair", desk.position + Vector3(0.3, -0.38, 0.75), 0)
	# The lantern, hung from a hook over the desk: frame, cap and wire round its glow.
	var lantern: Vector3 = Vector3(c.x - back.x * 0.4, 1.1, c.z - 1.0)
	var iron := Color(0.15, 0.15, 0.14)
	m.box(lantern - Vector3(0, 0.115, 0), Vector3(0.17, 0.03, 0.17), iron)
	m.box(lantern + Vector3(0, 0.115, 0), Vector3(0.15, 0.03, 0.15), iron)
	for sx in [-0.07, 0.07]:
		for sz in [-0.07, 0.07]:
			m.box(lantern + Vector3(sx, 0, sz), Vector3(0.012, 0.22, 0.012), iron)
	m.rod(lantern + Vector3(0, 0.13, 0), lantern + Vector3(0, SAFE_CEILING - lantern.y, 0), 0.004, iron, 4)
	# A rug under the desk and a rack of supplies on the north wall.
	m.box(Vector3(c.x - back.x * 0.3, 0.004, c.z - 0.6), Vector3(1.8, 0.008, 1.4), Color(0.42, 0.18, 0.14))
	m.commit(dress, "MercerRoom", true, 0.7, 0.2)
	ArtProps.model(dress, "metal_rack", Vector3(c.x + back.x * 0.2, 0, c.z - 2.62), 180)
	var s := ArtMesh.new()
	for k in 3:
		s.box(Vector3(c.x + back.x * 0.2 - 0.2, 0.47 + k * 0.48 + 0.14, c.z - 2.62), Vector3(0.3, 0.28, 0.3), BOX_TONES[k])
		s.rod(Vector3(c.x + back.x * 0.2 + 0.2, 0.47 + k * 0.48, c.z - 2.62), Vector3(c.x + back.x * 0.2 + 0.2, 0.47 + k * 0.48 + 0.3, c.z - 2.62), 0.1, Color(0.75, 0.82, 0.88), 8, true)
	s.commit(dress, "MercerSupplies", true, 0.5)


## The safe room's ceiling height (Level 3's SAFE_ROOM_SIZE.y).
const SAFE_CEILING := 3.0
