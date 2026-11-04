class_name GroundFloor
extends RefCounted
## Floor G, as the crew walk in: the lobby with its reception desk, the hall to the
## lift hall, the back corridor and the rooms off it, the dark east corridor, and
## the forgotten closet behind the air return. Level 0 builds it where it stands;
## Level 4 builds it again for the walk out at the end, so it's the same lobby
## (Augustine, v0.8). Static geometry only, in Level 0's coordinates, under `geo`
## (navigation bakes from it). Each level adds its own doors' states, lights,
## terminals, papers and story on top.

const WALL := Color(0.62, 0.58, 0.5)
const CARPET := Color(0.22, 0.2, 0.24)
## The lobby: x -8..8, z -7..7, and its openings.
const LOBBY_SIZE := Vector3(16, 4, 14)
const LOBBY_OPENINGS := [
	{"wall": "e", "at": 3.0, "width": 2.0, "height": 3.0},
	{"wall": "s", "at": 0.0, "width": 3.2, "height": 2.6},
	{"wall": "n", "at": -6.5, "width": 1.6, "height": 2.6},  # to the north corridor, either side of the desk
	{"wall": "n", "at": 6.5, "width": 1.6, "height": 2.6},
	{"wall": "w", "at": 4.0, "width": 0.9, "height": 1.0},  # the air return, flush with the floor so you can crawl in
]
## The reception desk: the only way behind it is over it.
const DESK := Vector3(0, 0.55, -1.0)
const DESK_SIZE := Vector3(10, 1.1, 0.8)
## The front doors (glass, sliding), in the lobby's south wall.
const FRONT_AT := Vector3(0, 1.3, 6.95)
const FRONT_SIZE := Vector3(3.2, 2.6, 0.12)
const FRONT_COLOR := Color(0.25, 0.35, 0.4)
## The hall's roller shutter, part way along to the lift hall.
const SHUTTER_AT := Vector3(11, 1.5, 3)
const SHUTTER_SIZE := Vector3(0.15, 3.0, 2.0)
## STAIR 1's door, in the lift hall's south wall, and the lift's, in its east wall.
const STAIR_AT := Vector3(27, 0, 7)
const LIFT_AT := Vector3(30, 0, 3)
## Ordinary doors, on hinges: [id, centre, size, hinge edge, swing].
const DOORS := [
	["MAILROOM", Vector3(-16.5, 1.1, -10.0), Vector3(1.35, 2.2, 0.08), Vector3(-0.675, 0, 0), 90.0],
	["MENS", Vector3(-11.5, 1.1, -10.0), Vector3(1.35, 2.2, 0.08), Vector3(-0.675, 0, 0), 90.0],
	["WOMENS", Vector3(-8.5, 1.1, -10.0), Vector3(1.35, 2.2, 0.08), Vector3(-0.675, 0, 0), 90.0],
	["IT-CLOSET", Vector3(10.0, 1.1, -10.0), Vector3(1.35, 2.2, 0.08), Vector3(-0.675, 0, 0), 90.0],
	["LOBBY-HALL-END", Vector3(23.9, 1.2, 3), Vector3(0.15, 2.4, 1.8), Vector3(0, 0, -0.9), 90.0],  # into the lift hall
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
	Greybox.room(geo, Vector3.ZERO, LOBBY_SIZE, {"floor": CARPET, "wall": WALL}, LOBBY_OPENINGS)
	Sfx.mark_surface(geo.get_node("Floor"), "carpet")  # the lobby's
	Greybox.label(geo, Vector3(0, 3.0, -6.88), "HALCYON DATA SYSTEMS", 160, Color(0.15, 0.2, 0.35))
	Greybox.label(geo, Vector3(0, 2.55, -6.88), "Data you can trust.", 64, Color(0.25, 0.25, 0.3))
	Greybox.label(geo, Vector3(0, 2.8, 6.85), "EXIT", 72, Color(0.8, 0.15, 0.1), 180)
	# Reception desk with side partitions: the only way behind it is over the desk.
	Greybox.box(geo, DESK, DESK_SIZE, Color(0.42, 0.3, 0.22), "Desk")
	Greybox.box(geo, Vector3(-5.0, 1.1, -4.2), Vector3(0.15, 2.2, 5.6), Color(0.5, 0.55, 0.6), "PartitionW")
	Greybox.box(geo, Vector3(5.0, 1.1, -4.2), Vector3(0.15, 2.2, 5.6), Color(0.5, 0.55, 0.6), "PartitionE")
	Greybox.label(geo, Vector3(0, 1.3, -0.58), "RECEPTION", 64, Color(0.85, 0.8, 0.6))
	# A side table behind the desk (Level 0 keeps the walkie-talkies' dock on it).
	Greybox.box(geo, Vector3(-2.5, 0.68, -5.5), Vector3(1.2, 0.04, 0.6), Color(0.45, 0.35, 0.2), "TableCharger")
	for leg in [Vector3(-0.55, 0, -0.25), Vector3(0.55, 0, -0.25), Vector3(-0.55, 0, 0.25), Vector3(0.55, 0, 0.25)]:
		Greybox.box(geo, Vector3(-2.5, 0.33, -5.5) + leg, Vector3(0.05, 0.66, 0.05), Color(0.3, 0.3, 0.32), "TableChargerLeg")
	# Waiting area chairs (cover, atmosphere), facing the coffee table.
	for x in [-6.0, -4.8, 4.8, 6.0]:
		Greybox.box(geo, Vector3(x, 0.25, 4.5), Vector3(0.9, 0.5, 0.9), Color(0.3, 0.12, 0.12), "Chair")
		Seat.create_at(geo, Vector3(x, 0.5, 4.5), 0.0, Vector2(0.8, 0.8))
	Greybox.box(geo, Vector3(-5.4, 0.2, 2.8), Vector3(2.0, 0.4, 0.8), Color(0.35, 0.28, 0.2), "Table")


## The hall east to the lift hall: x 8..24, z 2..4. Halfway along, an unlit passage
## turns north into the dark east corridor.
static func _hall(geo: Node3D) -> void:
	Greybox.room(geo, Vector3(16, 0, 3), Vector3(16, 3, 2), {"floor": Color(0.3, 0.3, 0.3), "wall": WALL}, [
		{"wall": "w", "at": 0.0, "width": 2.0, "height": 3.0},
		{"wall": "e", "at": 0.0, "width": 1.8, "height": 2.4},  # into the lift hall
		{"wall": "n", "at": 2.0, "width": 2.0, "height": 2.6},  # the dark passage
	])
	Greybox.label(geo, Vector3(23.88, 2.72, 3), "ELEVATORS  >", 64, Color(0.7, 0.1, 0.1), -90)


## The back corridor behind the lobby and the rooms off it, and the dark east corridor.
static func _back(geo: Node3D) -> void:
	var lino := Color(0.3, 0.31, 0.3)
	var tile := Color(0.75, 0.76, 0.74)
	# North corridor: x -20..12, z -10..-7, behind the lobby.
	Greybox.room(geo, Vector3(-4, 0, -8.5), Vector3(32, 3, 3), {"floor": lino, "wall": WALL}, [
		{"wall": "s", "at": -2.5, "width": 1.6, "height": 2.6},  # lobby, west of the desk
		{"wall": "s", "at": 10.5, "width": 1.6, "height": 2.6},  # lobby, east of the desk
		{"wall": "e", "at": 0.0, "width": 2.8, "height": 3.0},  # into the dark east corridor
		{"wall": "n", "at": -12.5, "width": 1.4, "height": 2.2},  # mailroom
		{"wall": "n", "at": -7.5, "width": 1.4, "height": 2.2},  # men's
		{"wall": "n", "at": -4.5, "width": 1.4, "height": 2.2},  # women's
		{"wall": "n", "at": 4.0, "width": 2.4, "height": 2.6},  # cafeteria
		{"wall": "n", "at": 14.0, "width": 1.4, "height": 2.2},  # IT closet
	])
	Greybox.label(geo, Vector3(-16.5, 2.45, -9.88), "MAILROOM", 36, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(-11.5, 2.45, -9.88), "MEN", 36, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(-8.5, 2.45, -9.88), "WOMEN", 36, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(0, 2.8, -9.88), "CAFETERIA", 48, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(10, 2.45, -9.88), "IT", 36, Color(0.15, 0.15, 0.2))

	# Mailroom: x -20..-13, z -18..-10. Pigeonholes, a sorting table, a cart.
	Greybox.room(geo, Vector3(-16.5, 0, -14), Vector3(7, 3, 8), {"floor": lino, "wall": WALL}, [
		{"wall": "s", "at": 0.0, "width": 1.4, "height": 2.2},
	])
	Greybox.box(geo, Vector3(-16.5, 1.1, -17.6), Vector3(5.5, 2.2, 0.6), Color(0.45, 0.38, 0.28), "Pigeonholes")
	Greybox.box(geo, Vector3(-16.5, 0.45, -14.5), Vector3(3.0, 0.9, 1.2), Color(0.5, 0.45, 0.38), "SortingTable")
	Greybox.box(geo, Vector3(-19.0, 0.5, -12.0), Vector3(1.0, 1.0, 1.4), Color(0.35, 0.35, 0.38), "MailCart")

	# Restrooms: two narrow rooms with stalls to duck into.
	for r in [-11.5, -8.5]:
		Greybox.room(geo, Vector3(r, 0, -14), Vector3(3, 3, 8), {"floor": tile, "wall": tile.darkened(0.1)}, [
			{"wall": "s", "at": 0.0, "width": 1.4, "height": 2.2},
		])
		# Along the west wall, past where the door swings.
		Greybox.box(geo, Vector3(r - 1.25, 0.45, -12.3), Vector3(0.5, 0.9, 1.0), Color(0.85, 0.85, 0.82), "Sinks")
		for k in 2:
			var z := -15.2 - k * 1.4
			Greybox.box(geo, Vector3(r + 0.2, 1.0, z + 0.7), Vector3(2.2, 2.0, 0.05), Color(0.55, 0.6, 0.62), "StallWall")
		Greybox.box(geo, Vector3(r + 0.2, 1.0, -17.95), Vector3(2.2, 2.0, 0.05), Color(0.55, 0.6, 0.62), "StallWall")

	# Cafeteria: x -7..8, z -18..-10. Tables to hop, a serving counter, vending machines.
	Greybox.room(geo, Vector3(0.5, 0, -14), Vector3(15, 3.5, 8), {"floor": lino, "wall": WALL}, [
		{"wall": "s", "at": -0.5, "width": 2.4, "height": 2.6},
	])
	for tx in [-4.0, 0.0, 4.0]:
		for tz in [-12.5, -15.0]:
			Greybox.box(geo, Vector3(tx, 0.375, tz), Vector3(2.0, 0.75, 1.0), Color(0.55, 0.42, 0.3), "CafTable")
	Greybox.box(geo, Vector3(0.5, 0.5, -17.4), Vector3(8.0, 1.0, 0.9), Color(0.6, 0.6, 0.62), "ServingCounter")
	Greybox.box(geo, Vector3(7.4, 0.9, -12.0), Vector3(0.9, 1.8, 0.8), Color(0.25, 0.3, 0.5), "VendingMachine")
	Greybox.box(geo, Vector3(7.4, 0.9, -13.2), Vector3(0.9, 1.8, 0.8), Color(0.6, 0.15, 0.12), "VendingMachine")

	# IT closet: x 8..12, z -14..-10. Shelves of spares and a patch panel.
	Greybox.room(geo, Vector3(10, 0, -12), Vector3(4, 3, 4), {"floor": lino, "wall": WALL}, [
		{"wall": "s", "at": 0.0, "width": 1.4, "height": 2.2},
	])
	Greybox.box(geo, Vector3(8.4, 1.0, -12.0), Vector3(0.6, 2.0, 3.4), Color(0.4, 0.4, 0.42), "SpareShelf")
	Greybox.box(geo, Vector3(11.7, 1.3, -12.5), Vector3(0.3, 1.2, 1.6), Color(0.12, 0.12, 0.14), "PatchPanel")
	Greybox.box(geo, Vector3(10.8, 0.3, -13.4), Vector3(0.8, 0.6, 0.6), Color(0.45, 0.35, 0.2), "Crate")

	# The dark east corridor: x 12..19, z -10..-7, then a passage south (x 17..19)
	# to the hall. No working lights.
	Greybox.room(geo, Vector3(15.5, 0, -8.5), Vector3(7, 3, 3), {"floor": lino.darkened(0.2), "wall": WALL.darkened(0.3)}, [
		{"wall": "w", "at": 0.0, "width": 2.8, "height": 3.0},
		{"wall": "s", "at": 2.5, "width": 2.0, "height": 2.6},
	])
	Greybox.room(geo, Vector3(18, 0, -2.5), Vector3(2, 3, 9), {"floor": lino.darkened(0.2), "wall": WALL.darkened(0.3)}, [
		{"wall": "n", "at": 0.0, "width": 2.0, "height": 2.6},
		{"wall": "s", "at": 0.0, "width": 2.0, "height": 2.6},
	])
	Greybox.panel(geo, DEAD_LIGHT, Vector3(1.2, 0.05, 0.3), Color(0.3, 0.3, 0.3))  # a dead light


## The lift hall: x 24..30, z -1..7, through the door at the end of the hall, with
## STAIR 1 in its south wall and the lift in its east wall.
static func _lift_hall(geo: Node3D) -> void:
	Greybox.room(geo, Vector3(27, 0, 3), Vector3(6, 3.2, 8), {"floor": Color(0.35, 0.33, 0.3), "wall": WALL}, [
		{"wall": "w", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "e", "at": 0.0, "width": Elevator.DOORWAY, "height": Elevator.DOOR_H},
		{"wall": "s", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},  # the stairs
	])


## The forgotten storage closet behind the lobby's air return, and the duct to it:
## x -20..-14, z 1..7.
static func _closet(geo: Node3D) -> void:
	Traversal.vent(geo, Vector3(-8, 0.0, 4), Vector3(-14, 0.0, 4), Vector2(0.9, 0.95))
	Greybox.room(geo, Vector3(-17, 0, 4), Vector3(6, 2.6, 6), {"floor": Color(0.2, 0.2, 0.2), "wall": Color(0.4, 0.38, 0.33)}, [
		{"wall": "e", "at": 0.0, "width": 0.9, "height": 1.0},
	])
	Greybox.box(geo, Vector3(-19.5, 0.9, 4), Vector3(0.8, 1.8, 3), Color(0.35, 0.35, 0.35), "Shelf")
