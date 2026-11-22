class_name GroundFloor
extends RefCounted
## Floor G, as the crew walk in: the lobby with its front desk, the hall to the
## lift hall, the back corridor and the rooms off it, the dark east corridor, and
## the forgotten closet behind the air return. Level 0 builds it where it stands;
## Level 4 builds it again for the walk out at the end, so it's the same lobby
## (Augustine, v0.8). Static geometry only, in Level 0's coordinates, under `geo`
## (navigation bakes from it). Each level adds its own doors' states, lights,
## terminals, papers and story on top.
##
## Every room is one Rect2 below, and everything on the floor is placed from the
## rooms and the named places after them (`at`, `mid`, `on_desk`), in this file
## and in whatever stands on the floor (Level 0, Level 4, DressLevel0, the
## tests). Resize a room here and what's in it moves with it.

const WALL := Color(0.62, 0.58, 0.5)
const CARPET := Color(0.22, 0.2, 0.24)

# --- The rooms --------------------------------------------------------------------
# Each is Rect2(its west wall's x, its north wall's z, how wide east, how deep
# south), with its ceiling height. North is -Z: the car park is south, at +Z.

## The lobby, with the front desk across it and the front doors in its south wall.
const LOBBY := Rect2(-8, -7, 16, 14)
const LOBBY_H := 4.0
## The hall east from the lobby to the lift hall. Part way along, an unlit passage
## turns north into the dark east corridor.
const HALL := Rect2(8, 2, 16, 2)
const HALL_H := 3.0
## The back corridor behind the lobby, and the rooms along its north side.
const CORRIDOR := Rect2(-20, -10, 32, 3)
const CORRIDOR_Z := CORRIDOR.position.y + CORRIDOR.size.y / 2.0  # its centre line
const MAILROOM := Rect2(-20, -18, 7, 8)
const MENS := Rect2(-13, -18, 3, 8)
const WOMENS := Rect2(-10, -18, 3, 8)
const CAFETERIA := Rect2(-7, -18, 15, 8)
const CAFETERIA_H := 3.5
const IT_CLOSET := Rect2(8, -14, 4, 4)
const BACK_H := 3.0
## The dark east corridor, on from the back corridor's east end, and the passage
## from it south to the hall. No working lights.
const DARK := Rect2(12, -10, 7, 3)
const PASSAGE := Rect2(17, -7, 2, 9)
## The lift hall, through the door at the end of the hall: STAIR 1 in its south
## wall, the lift in its east wall.
const LIFT_HALL := Rect2(24, -1, 6, 8)
const LIFT_HALL_H := 3.2
## The forgotten storage closet behind the lobby's air return.
const CLOSET := Rect2(-20, 1, 6, 6)
const CLOSET_H := 2.6

# --- Named places -----------------------------------------------------------------

## The lobby's openings: the hall (east wall, at this z), the front doors (south
## wall), the two ways round the desk to the back corridor (north wall, at -x and
## +x), and the air return (west wall, at this z, flush with the floor so you can
## crawl in).
const HALL_Z := 3.0
const AISLE_X := 6.5
const VENT_Z := 4.0
const VENT_SIZE := Vector2(0.9, 1.0)
## The reception desk: the only way behind it is over it. Partitions run back
## from its ends (at -x and +x) to the lobby's north wall.
const DESK := Vector3(0, 0.55, -1.0)
const DESK_SIZE := Vector3(10, 1.1, 0.8)
const PARTITION_X := 5.0
## The side table behind the desk (Level 0 keeps the walkie-talkies' dock on it).
const CHARGER_TABLE := Vector3(-2.5, 0.68, -5.5)
## The front doors (glass, sliding), in the lobby's south wall.
const FRONT_AT := Vector3(0, 1.3, 6.95)
const FRONT_SIZE := Vector3(3.2, 2.6, 0.12)
const FRONT_COLOR := Color(0.25, 0.35, 0.4)
## The hall's roller shutter, part way along to the lift hall.
const SHUTTER_AT := Vector3(11, 1.5, 3)
const SHUTTER_SIZE := Vector3(0.15, 3.0, 2.0)
## Where the dark passage meets the hall and the dark corridor (its centre line).
const PASSAGE_X := 18.0
## STAIR 1's door, in the lift hall's south wall, and the lift's, in its east wall.
const STAIR_AT := Vector3(27, 0, 7)
const LIFT_AT := Vector3(30, 0, 3)
## The doorways off the back corridor's north side, by their middle's x.
const MAILROOM_DOOR_X := -16.5
const MENS_DOOR_X := -11.5
const WOMENS_DOOR_X := -8.5
const CAFETERIA_DOOR_X := 0.0
const IT_DOOR_X := 10.0
## Ordinary doors, on hinges: [id, centre, size, hinge edge, swing].
const DOORS := [
	["MAILROOM", Vector3(MAILROOM_DOOR_X, 1.1, -10.0), Vector3(1.35, 2.2, 0.08), Vector3(-0.675, 0, 0), 90.0],
	["MENS", Vector3(MENS_DOOR_X, 1.1, -10.0), Vector3(1.35, 2.2, 0.08), Vector3(-0.675, 0, 0), 90.0],
	["WOMENS", Vector3(WOMENS_DOOR_X, 1.1, -10.0), Vector3(1.35, 2.2, 0.08), Vector3(-0.675, 0, 0), 90.0],
	["IT-CLOSET", Vector3(IT_DOOR_X, 1.1, -10.0), Vector3(1.35, 2.2, 0.08), Vector3(-0.675, 0, 0), 90.0],
	["LOBBY-HALL-END", Vector3(23.9, 1.2, HALL_Z), Vector3(0.15, 2.4, 1.8), Vector3(0, 0, -0.9), 90.0],  # into the lift hall
]
## Its ceiling lights: [room, position, range, energy] (Level 0's lights table names the rooms).
const LIGHTS := [
	["lobby", Vector3(-4, 4, -4), 9.0, 1.4], ["lobby", Vector3(4, 4, -4), 9.0, 1.4],
	["lobby", Vector3(-4, 4, 1.5), 9.0, 1.4], ["lobby", Vector3(4, 4, 1.5), 9.0, 1.4],
	["lobby", Vector3(-4, 4, 5), 9.0, 1.4], ["lobby", Vector3(4, 4, 5), 9.0, 1.4],
	["hall", Vector3(13, 3, 3), 6.0, 1.1], ["hall", Vector3(20, 3, 3), 6.0, 1.1],
	["corridor", Vector3(-16, 3, -8.5), 6.0, 1.0], ["corridor", Vector3(-8, 3, -8.5), 6.0, 1.0],
	["corridor", Vector3(0, 3, -8.5), 6.0, 1.0], ["corridor", Vector3(8, 3, -8.5), 6.0, 1.0],
	["mailroom", Vector3(-16.5, 3, -14), 6.0, 1.0],
	["restrooms", Vector3(-11.5, 3, -13), 4.5, 0.8], ["restrooms", Vector3(-8.5, 3, -13), 4.5, 0.8],
	["cafeteria", Vector3(-3.5, 3.5, -14), 8.0, 1.1], ["cafeteria", Vector3(4.5, 3.5, -14), 8.0, 1.1],
	["it_closet", Vector3(10, 3, -12), 4.0, 0.7],
	["elevators", Vector3(27, 3.2, 1), 7.0, 1.1], ["elevators", Vector3(27, 3.2, 5), 7.0, 1.1],
]
## The dead fitting in the dark east corridor.
const DEAD_LIGHT := Vector3(15.5, 2.97, -8.5)


# --- Placing things ---------------------------------------------------------------

## The middle of `room`'s floor, at height `y`.
static func mid(room: Rect2, y: float = 0.0) -> Vector3:
	var c := room.get_center()
	return Vector3(c.x, y, c.y)


## `room`'s size as a box `height` tall.
static func span(room: Rect2, height: float) -> Vector3:
	return Vector3(room.size.x, height, room.size.y)


## A point in `room`: `east` metres in from its west wall and `south` metres in
## from its north wall, at height `y`.
static func at(room: Rect2, east: float, y: float, south: float) -> Vector3:
	return Vector3(room.position.x + east, y, room.position.y + south)


## A point by the front desk: `along` metres east of its middle, `toward` metres
## toward the front doors from its centre line (minus is behind it), at height `y`.
static func by_desk(along: float, toward: float, y: float = 0.0) -> Vector3:
	return Vector3(DESK.x + along, y, DESK.z + toward)


## A point on the front desk's top: the same, `lift` above the top.
static func on_desk(along: float, toward: float = 0.0, lift: float = 0.0) -> Vector3:
	return by_desk(along, toward, DESK_SIZE.y + lift)


## `room` as a box from `below` its floor to `above` its ceiling, grown by
## `grow` on every side (for zones and triggers).
static func box(room: Rect2, height: float, grow: float = 0.0, below: float = 0.0, above: float = 0.0) -> AABB:
	return AABB(Vector3(room.position.x - grow, -below, room.position.y - grow), Vector3(room.size.x + grow * 2.0, height + below + above, room.size.y + grow * 2.0))


## An opening in one of `room`'s walls, for Greybox.room: `where` is its middle's
## place in the world, x along a north or south wall, z along an east or west one.
static func gap(room: Rect2, wall: String, where: float, width: float, height: float) -> Dictionary:
	var c := room.get_center()
	return {"wall": wall, "at": where - (c.x if wall == "n" or wall == "s" else c.y), "width": width, "height": height}


## Build the floor under `geo`.
static func build(geo: Node3D) -> void:
	_lobby(geo)
	_hall(geo)
	_back(geo)
	_lift_hall(geo)
	_closet(geo)


## The ordinary doors (DOORS), under `parent`, named `prefix` + id. Returns them by id.
static func doors(parent: Node3D, prefix: String = "") -> Dictionary:
	var made := {}
	for d in DOORS:
		made[d[0]] = Door.create(parent, prefix + d[0], d[1], d[2]).make_hinged(d[3], d[4])
	return made


## The front doors, under `parent`: they slide aside.
static func front_doors(parent: Node3D, id: String) -> Door:
	var d := Door.create(parent, id, FRONT_AT, FRONT_SIZE, FRONT_COLOR)
	d.slide_axis = Vector3.RIGHT
	return d


static func _lobby(geo: Node3D) -> void:
	var north := LOBBY.position.y
	var south := LOBBY.end.y
	Greybox.room(geo, mid(LOBBY), span(LOBBY, LOBBY_H), {"floor": CARPET, "wall": WALL}, [
		gap(LOBBY, "e", HALL_Z, 2.0, 3.0),
		gap(LOBBY, "s", FRONT_AT.x, FRONT_SIZE.x, FRONT_SIZE.y),
		gap(LOBBY, "n", -AISLE_X, 1.6, 2.6),  # to the back corridor, either side of the desk
		gap(LOBBY, "n", AISLE_X, 1.6, 2.6),
		gap(LOBBY, "w", VENT_Z, VENT_SIZE.x, VENT_SIZE.y),  # the air return
	])
	Sfx.mark_surface(geo.get_node("Floor"), "carpet")  # the lobby's
	Greybox.label(geo, Vector3(DESK.x, 3.0, north + 0.12), "HALCYON DATA SYSTEMS", 160, Color(0.15, 0.2, 0.35))
	Greybox.label(geo, Vector3(DESK.x, 2.55, north + 0.12), "Data you can trust.", 64, Color(0.25, 0.25, 0.3))
	Greybox.label(geo, Vector3(FRONT_AT.x, 2.8, south - 0.15), "EXIT", 72, Color(0.8, 0.15, 0.1), 180)
	# Reception desk with side partitions: the only way behind it is over the desk.
	Greybox.box(geo, DESK, DESK_SIZE, Color(0.42, 0.3, 0.22), "Desk")
	var behind := (DESK.z - DESK_SIZE.z / 2.0) - north  # from the desk's back edge to the north wall
	var partition_z := north + behind / 2.0
	Greybox.box(geo, Vector3(DESK.x - PARTITION_X, 1.1, partition_z), Vector3(0.15, 2.2, behind), Color(0.5, 0.55, 0.6), "PartitionW")
	Greybox.box(geo, Vector3(DESK.x + PARTITION_X, 1.1, partition_z), Vector3(0.15, 2.2, behind), Color(0.5, 0.55, 0.6), "PartitionE")
	Greybox.label(geo, Vector3(DESK.x, 1.3, DESK.z + DESK_SIZE.z / 2.0 + 0.02), "FRONT DESK", 64, Color(0.85, 0.8, 0.6))
	# A side table behind the desk (Level 0 keeps the walkie-talkies' dock on it).
	Greybox.box(geo, CHARGER_TABLE, Vector3(1.2, 0.04, 0.6), Color(0.45, 0.35, 0.2), "TableCharger")
	for leg in [Vector3(-0.55, 0, -0.25), Vector3(0.55, 0, -0.25), Vector3(-0.55, 0, 0.25), Vector3(0.55, 0, 0.25)]:
		Greybox.box(geo, Vector3(CHARGER_TABLE.x, 0.33, CHARGER_TABLE.z) + leg, Vector3(0.05, 0.66, 0.05), Color(0.3, 0.3, 0.32), "TableChargerLeg")
	# Waiting area chairs (cover, atmosphere), facing the coffee table.
	for x in [-6.0, -4.8, 4.8, 6.0]:
		Greybox.box(geo, Vector3(x, 0.25, south - 2.5), Vector3(0.9, 0.5, 0.9), Color(0.3, 0.12, 0.12), "Chair")
		Seat.create_at(geo, Vector3(x, 0.5, south - 2.5), 0.0, Vector2(0.8, 0.8))
	Greybox.box(geo, Vector3(-5.4, 0.2, south - 4.2), Vector3(2.0, 0.4, 0.8), Color(0.35, 0.28, 0.2), "Table")


## The hall east to the lift hall. Part way along, an unlit passage turns north
## into the dark east corridor.
static func _hall(geo: Node3D) -> void:
	Greybox.room(geo, mid(HALL), span(HALL, HALL_H), {"floor": Color(0.3, 0.3, 0.3), "wall": WALL}, [
		gap(HALL, "w", HALL_Z, 2.0, 3.0),
		gap(HALL, "e", HALL_Z, 1.8, 2.4),  # into the lift hall
		gap(HALL, "n", PASSAGE_X, 2.0, 2.6),  # the dark passage
	])
	Greybox.label(geo, Vector3(HALL.end.x - 0.12, 2.72, HALL_Z), "ELEVATORS  >", 64, Color(0.7, 0.1, 0.1), -90)


## The back corridor behind the lobby and the rooms off it, and the dark east corridor.
static func _back(geo: Node3D) -> void:
	var lino := Color(0.3, 0.31, 0.3)
	var tile := Color(0.75, 0.76, 0.74)
	var sign_z := CORRIDOR.position.y + 0.12  # on the corridor's north wall
	Greybox.room(geo, mid(CORRIDOR), span(CORRIDOR, BACK_H), {"floor": lino, "wall": WALL}, [
		gap(CORRIDOR, "s", -AISLE_X, 1.6, 2.6),  # lobby, west of the desk
		gap(CORRIDOR, "s", AISLE_X, 1.6, 2.6),  # lobby, east of the desk
		gap(CORRIDOR, "e", CORRIDOR_Z, 2.8, 3.0),  # into the dark east corridor
		gap(CORRIDOR, "n", MAILROOM_DOOR_X, 1.4, 2.2),
		gap(CORRIDOR, "n", MENS_DOOR_X, 1.4, 2.2),
		gap(CORRIDOR, "n", WOMENS_DOOR_X, 1.4, 2.2),
		gap(CORRIDOR, "n", CAFETERIA_DOOR_X, 2.4, 2.6),
		gap(CORRIDOR, "n", IT_DOOR_X, 1.4, 2.2),
	])
	Greybox.label(geo, Vector3(MAILROOM_DOOR_X, 2.45, sign_z), "MAILROOM", 36, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(MENS_DOOR_X, 2.45, sign_z), "MEN", 36, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(WOMENS_DOOR_X, 2.45, sign_z), "WOMEN", 36, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(CAFETERIA_DOOR_X, 2.8, sign_z), "CAFETERIA", 48, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(IT_DOOR_X, 2.45, sign_z), "IT", 36, Color(0.15, 0.15, 0.2))

	# Mailroom. Pigeonholes, a sorting table, a cart.
	Greybox.room(geo, mid(MAILROOM), span(MAILROOM, BACK_H), {"floor": lino, "wall": WALL}, [
		gap(MAILROOM, "s", MAILROOM_DOOR_X, 1.4, 2.2),
	])
	Greybox.box(geo, at(MAILROOM, 3.5, 1.1, 0.4), Vector3(5.5, 2.2, 0.6), Color(0.45, 0.38, 0.28), "Pigeonholes")
	Greybox.box(geo, at(MAILROOM, 3.5, 0.45, 3.5), Vector3(3.0, 0.9, 1.2), Color(0.5, 0.45, 0.38), "SortingTable")
	Greybox.box(geo, at(MAILROOM, 1.0, 0.5, 6.0), Vector3(1.0, 1.0, 1.4), Color(0.35, 0.35, 0.38), "MailCart")

	# Restrooms: two narrow rooms with stalls to duck into.
	for room in [MENS, WOMENS]:
		var r: float = mid(room).x
		Greybox.room(geo, mid(room), span(room, BACK_H), {"floor": tile, "wall": tile.darkened(0.1)}, [
			gap(room, "s", r, 1.4, 2.2),
		])
		# Along the west wall, past where the door swings.
		Greybox.box(geo, at(room, 0.25, 0.45, 5.7), Vector3(0.5, 0.9, 1.0), Color(0.85, 0.85, 0.82), "Sinks")
		for k in 2:
			Greybox.box(geo, at(room, 1.7, 1.0, 3.5 - k * 1.4), Vector3(2.2, 2.0, 0.05), Color(0.55, 0.6, 0.62), "StallWall")
		Greybox.box(geo, at(room, 1.7, 1.0, 0.05), Vector3(2.2, 2.0, 0.05), Color(0.55, 0.6, 0.62), "StallWall")

	# Cafeteria. Tables to hop, a serving counter, vending machines.
	Greybox.room(geo, mid(CAFETERIA), span(CAFETERIA, CAFETERIA_H), {"floor": lino, "wall": WALL}, [
		gap(CAFETERIA, "s", CAFETERIA_DOOR_X, 2.4, 2.6),
	])
	for tx in CAFE_TABLES_X:
		for tz in CAFE_TABLES_Z:
			Greybox.box(geo, Vector3(tx, 0.375, tz), Vector3(2.0, 0.75, 1.0), Color(0.55, 0.42, 0.3), "CafTable")
	Greybox.box(geo, at(CAFETERIA, 7.5, 0.5, 0.6), Vector3(8.0, 1.0, 0.9), Color(0.6, 0.6, 0.62), "ServingCounter")
	Greybox.box(geo, VENDING_AT, Vector3(0.9, 1.8, 0.8), Color(0.25, 0.3, 0.5), "VendingMachine")
	Greybox.box(geo, VENDING_AT + Vector3(0, 0, -1.2), Vector3(0.9, 1.8, 0.8), Color(0.6, 0.15, 0.12), "VendingMachine")

	# IT closet. Shelves of spares and a patch panel.
	Greybox.room(geo, mid(IT_CLOSET), span(IT_CLOSET, BACK_H), {"floor": lino, "wall": WALL}, [
		gap(IT_CLOSET, "s", IT_DOOR_X, 1.4, 2.2),
	])
	Greybox.box(geo, at(IT_CLOSET, 0.4, 1.0, 2.0), Vector3(0.6, 2.0, 3.4), Color(0.4, 0.4, 0.42), "SpareShelf")
	Greybox.box(geo, at(IT_CLOSET, 3.7, 1.3, 1.5), Vector3(0.3, 1.2, 1.6), Color(0.12, 0.12, 0.14), "PatchPanel")
	Greybox.box(geo, IT_CRATE, Vector3(0.8, 0.6, 0.6), Color(0.45, 0.35, 0.2), "Crate")

	# The dark east corridor, then a passage south to the hall. No working lights.
	Greybox.room(geo, mid(DARK), span(DARK, BACK_H), {"floor": lino.darkened(0.2), "wall": WALL.darkened(0.3)}, [
		gap(DARK, "w", CORRIDOR_Z, 2.8, 3.0),
		gap(DARK, "s", PASSAGE_X, 2.0, 2.6),
	])
	Greybox.room(geo, mid(PASSAGE), span(PASSAGE, BACK_H), {"floor": lino.darkened(0.2), "wall": WALL.darkened(0.3)}, [
		gap(PASSAGE, "n", PASSAGE_X, 2.0, 2.6),
		gap(PASSAGE, "s", PASSAGE_X, 2.0, 2.6),
	])
	Greybox.panel(geo, DEAD_LIGHT, Vector3(1.2, 0.05, 0.3), Color(0.3, 0.3, 0.3))  # a dead light


## The cafeteria's tables (two rows of three), the coffee machine of its two
## vending machines, and the crate in the IT closet's corner.
const CAFE_TABLES_X := [-4.0, 0.0, 4.0]
const CAFE_TABLES_Z := [-12.5, -15.0]
const VENDING_AT := Vector3(7.4, 0.9, -12.0)
const IT_CRATE := Vector3(10.8, 0.3, -13.4)
## The IT closet's ceiling access panel (Level 0's leg-up).
const IT_HATCH := Vector3(10.2, 2.97, -12.6)


## The lift hall, through the door at the end of the hall, with STAIR 1 in its
## south wall and the lift in its east wall.
static func _lift_hall(geo: Node3D) -> void:
	Greybox.room(geo, mid(LIFT_HALL), span(LIFT_HALL, LIFT_HALL_H), {"floor": Color(0.35, 0.33, 0.3), "wall": WALL}, [
		gap(LIFT_HALL, "w", HALL_Z, 1.8, 2.4),
		gap(LIFT_HALL, "e", LIFT_AT.z, Elevator.DOORWAY, Elevator.DOOR_H),
		gap(LIFT_HALL, "s", STAIR_AT.x, Stairwell.DOOR_W, Stairwell.DOOR_H),  # the stairs
	])


## The forgotten storage closet behind the lobby's air return, and the duct to it.
static func _closet(geo: Node3D) -> void:
	Traversal.vent(geo, Vector3(LOBBY.position.x, 0.0, VENT_Z), Vector3(CLOSET.end.x, 0.0, VENT_Z), VENT_SIZE)
	Greybox.room(geo, mid(CLOSET), span(CLOSET, CLOSET_H), {"floor": Color(0.2, 0.2, 0.2), "wall": Color(0.4, 0.38, 0.33)}, [
		gap(CLOSET, "e", VENT_Z, VENT_SIZE.x, VENT_SIZE.y),
	])
	Greybox.box(geo, at(CLOSET, 0.5, 0.9, 3.0), Vector3(0.8, 1.8, 3), Color(0.35, 0.35, 0.35), "Shelf")
