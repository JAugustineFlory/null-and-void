class_name GroundFloor
extends RefCounted
## Floor G, as the crew walk in: the lobby with its front desk, the hall to the
## lift hall, the north corridor and the rooms off it, the dark east corridor, the
## forgotten closet behind the air return, and the staff's rooms, locked for the
## night, with what stands in the back of house (the kitchen's walk-in, the air
## handler, receiving's racking and cage). Level 0 builds it where it stands;
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
const LINO := Color(0.3, 0.31, 0.3)
const TILE := Color(0.75, 0.76, 0.74)
const STEEL := Color(0.6, 0.6, 0.62)

# --- The rooms --------------------------------------------------------------------
# Each is Rect2(its west wall's x, its north wall's z, how wide east, how deep
# south), with its ceiling height. North is -Z: the car park is south, at +Z.

## The lobby, with the front desk across it and the front doors in its south wall.
## Behind the desk, between its partitions, is the front office.
const LOBBY := Rect2(-16, -19, 32, 26)
const LOBBY_H := 5.0
## The hall east from the lobby to the lift hall. Near its far end, an unlit
## passage turns north into the dark east corridor.
const HALL := Rect2(16, -3, 32, 3)
const HALL_H := 3.0
## The north corridor behind the lobby, and the rooms along its north side.
const CORRIDOR := Rect2(-40, -22, 64, 3)
const CORRIDOR_Z := CORRIDOR.position.y + CORRIDOR.size.y / 2.0  # its centre line
const MAILROOM := Rect2(-40, -31, 12.5, 9)
const MENS := Rect2(-27.5, -30, 5.5, 8)
const WOMENS := Rect2(-19.5, -30, 5.5, 8)
const CAFETERIA := Rect2(-14, -33, 28, 11)
const CAFETERIA_H := 3.5
const IT_CLOSET := Rect2(14, -28, 6, 6)
const BACK_H := 3.0
## The dark east corridor, on from the north corridor's east end, and the passage
## from it south to the hall. No working lights.
const DARK := Rect2(24, -22, 14, 3)
const PASSAGE := Rect2(35, -19, 3, 16)
## The lift hall, through the door at the end of the hall: STAIR 1 in its south
## wall, three lifts in its east wall (one runs).
const LIFT_HALL := Rect2(48, -11, 10, 12)
const LIFT_HALL_H := 3.2
## The forgotten storage closet behind the lobby's air return.
const CLOSET := Rect2(-38, -3, 8, 8)
const CLOSET_H := 2.6
## Where Halcyon's ground-floor staff work. Built as bare rooms behind shut doors
## until each is furnished: visitor badges (off the lobby), the security post and
## the conference room (south of the hall), Facilities with its manager's office in
## the corner (north of the hall), Building Services (off the dark corridor), the
## janitor's closet (between the restrooms), the kitchen (behind the cafeteria) and
## receiving (behind the mailroom).
const VISITOR_BADGES := Rect2(-26, -14, 10, 10)
const SECURITY := Rect2(16, 0, 10, 7)
const CONFERENCE := Rect2(28, 0, 14, 7)
const FACILITIES := Rect2(16, -19, 19, 16)
const MANAGER := Rect2(29, -19, 6, 6)
const BUILDING_SERVICES := Rect2(24, -34, 14, 12)
const JANITOR := Rect2(-22, -26, 2.5, 4)
const KITCHEN := Rect2(-14, -40, 28, 7)
const RECEIVING := Rect2(-40, -40, 12.5, 9)
## Everything indoors, as one rectangle (the building's footprint, bar the lifts'
## shafts east of the lift hall).
const FOOTPRINT := Rect2(-40, -40, 98, 47)
## The building from outside: the footprint with its outside walls, and the lifts'
## shafts east of the lift hall. Its south edge is the front wall.
const OUTSIDE := Rect2(FOOTPRINT.position.x - 0.6, FOOTPRINT.position.y - 0.4, FOOTPRINT.size.x + 3.0, FOOTPRINT.size.y + 0.4)

# --- Named places -----------------------------------------------------------------

## The lobby's openings: the hall (east wall, at this z), the front doors (south
## wall), the two ways round the desk to the north corridor (north wall, at -x and
## +x), and the air return (west wall, at this z, flush with the floor so you can
## crawl in).
const HALL_Z := -1.5
const AISLE_X := 11.0
const VENT_Z := 1.0
const VENT_SIZE := Vector2(0.9, 1.0)
## The reception desk: the only way behind it is over it. Partitions run back
## from its ends (at -x and +x) to the lobby's north wall.
const DESK := Vector3(0, 0.55, -9.0)
const DESK_SIZE := Vector3(12, 1.1, 0.8)
const PARTITION_X := 6.0
## Along the desk, east of its middle: the receptionist's terminal, and the phone.
const TERMINAL_ALONG := 1.5
const PHONE_ALONG := 3.4
## The front office: behind the desk, between its partitions, back to the lobby's
## north wall. No door and no gate: the only way in is over the desk.
const FRONT_OFFICE := Rect2(DESK.x - PARTITION_X, LOBBY.position.y, PARTITION_X * 2.0, DESK.z - DESK_SIZE.z / 2.0 - LOBBY.position.y)
## The side table behind the desk (Level 0 keeps the walkie-talkies' dock on it).
const CHARGER_TABLE := Vector3(-2.5, 0.68, -13.5)
## The front office's two back desks (whoever sits at one faces the counter), and
## the table for its machines, against the east partition.
const BACK_DESKS := [Vector3(FRONT_OFFICE.position.x + 3.0, 0, FRONT_OFFICE.position.y + 3.2), Vector3(FRONT_OFFICE.position.x + 7.0, 0, FRONT_OFFICE.position.y + 3.2)]
const MACHINES_TABLE := Vector3(FRONT_OFFICE.end.x - 0.5, 0, FRONT_OFFICE.position.y + 5.8)
## The front doors (glass, sliding), in the lobby's south wall.
const FRONT_AT := Vector3(0, 1.3, 6.95)
const FRONT_SIZE := Vector3(3.2, 2.6, 0.12)
const FRONT_COLOR := Color(0.25, 0.35, 0.4)
## The hall's roller shutter, just in from the lobby.
const SHUTTER_AT := Vector3(19, 1.5, HALL_Z)
const SHUTTER_SIZE := Vector3(0.15, 3.0, 3.0)
## Where the dark passage meets the hall and the dark corridor (its centre line).
const PASSAGE_X := 36.5
## STAIR 1's door, in the lift hall's south wall, and the working lift's, in its
## east wall. The other two lifts' doors (shut) are along from it, at these z.
const STAIR_AT := Vector3(53, 0, 1)
const LIFT_AT := Vector3(58, 0, HALL_Z)
const SPARE_LIFTS_Z := [-5.0, -8.5]
## The doorways off the north corridor's north side, by their middle's x.
const MAILROOM_DOOR_X := -34.0
const MENS_DOOR_X := -24.75
const JANITOR_DOOR_X := -20.75
const WOMENS_DOOR_X := -16.75
const CAFETERIA_DOOR_X := 0.0
const IT_DOOR_X := 17.0
## The other rooms' doorways: [x, z] of each one's middle, on its wall's line.
const VISITOR_DOOR := Vector2(-16, -9)
const SECURITY_DOOR := Vector2(23, 0)
const CONFERENCE_DOOR := Vector2(31, 0)
const FACILITIES_DOOR := Vector2(22, -3)
const MANAGER_DOOR := Vector2(29, -15)
const BUILDING_SERVICES_DOOR := Vector2(31, -22)
const KITCHEN_DOOR := Vector2(11, -33)
const RECEIVING_DOOR := Vector2(-34, -31)
## Windows, glazed from the sill up: [x, z] of each one's middle, on its wall's
## line. Onto the lobby: visitor badges has one beside its door, and the security
## post's is the guard's view of the front doors. Along the hall: Facilities on
## its north side, the conference room on its south. And the manager's office
## looks out over Facilities through its south partition.
const VISITOR_WINDOW := Vector2(-16, -6.1)
const SECURITY_WINDOW := Vector2(16, 3.0)
const FACILITIES_WINDOW := Vector2(27.5, -3)
const CONFERENCE_WINDOW := Vector2(37, 0)
const MANAGER_WINDOW := Vector2(32, -13)
const WINDOW_SILL := 0.9
const WINDOW_HEAD := 2.2
## A door's sign: over it, at this height, in this ink.
const SIGN_Y := 2.45
const SIGN_INK := Color(0.15, 0.15, 0.2)
## Ordinary doors, on hinges: [id, centre, size, hinge edge, swing]. A door in an
## east-west wall is DOOR_X; one in a north-south wall is DOOR_Z.
const DOOR_X := Vector3(1.35, 2.2, 0.08)
const DOOR_Z := Vector3(0.08, 2.2, 1.35)
const HINGE_X := Vector3(-0.675, 0, 0)
const HINGE_Z := Vector3(0, 0, -0.675)
const DOORS := [
	["MAILROOM", Vector3(MAILROOM_DOOR_X, 1.1, CORRIDOR.position.y), DOOR_X, HINGE_X, 90.0],
	["MENS", Vector3(MENS_DOOR_X, 1.1, CORRIDOR.position.y), DOOR_X, HINGE_X, 90.0],
	["WOMENS", Vector3(WOMENS_DOOR_X, 1.1, CORRIDOR.position.y), DOOR_X, HINGE_X, 90.0],
	["IT-CLOSET", Vector3(IT_DOOR_X, 1.1, CORRIDOR.position.y), DOOR_X, HINGE_X, 90.0],
	["LOBBY-HALL-END", Vector3(HALL.end.x - 0.1, 1.2, HALL_Z), Vector3(0.15, 2.4, 1.8), Vector3(0, 0, -0.9), 90.0],  # into the lift hall
	["JANITOR", Vector3(JANITOR_DOOR_X, 1.1, CORRIDOR.position.y), Vector3(1.05, 2.2, 0.08), Vector3(-0.525, 0, 0), 90.0],
	["VISITOR-BADGES", Vector3(VISITOR_DOOR.x, 1.1, VISITOR_DOOR.y), DOOR_Z, HINGE_Z, 90.0],
	["SECURITY", Vector3(SECURITY_DOOR.x, 1.1, SECURITY_DOOR.y), DOOR_X, HINGE_X, 90.0],
	["CONFERENCE", Vector3(CONFERENCE_DOOR.x, 1.1, CONFERENCE_DOOR.y), DOOR_X, HINGE_X, 90.0],
	["FACILITIES", Vector3(FACILITIES_DOOR.x, 1.1, FACILITIES_DOOR.y), DOOR_X, HINGE_X, 90.0],
	["FACILITIES-MANAGER", Vector3(MANAGER_DOOR.x, 1.1, MANAGER_DOOR.y), Vector3(0.08, 2.2, 1.15), Vector3(0, 0, -0.575), 90.0],
	["BUILDING-SERVICES", Vector3(BUILDING_SERVICES_DOOR.x, 1.1, BUILDING_SERVICES_DOOR.y), DOOR_X, HINGE_X, 90.0],
	["KITCHEN", Vector3(KITCHEN_DOOR.x, 1.1, KITCHEN_DOOR.y), DOOR_X, HINGE_X, 90.0],
	["RECEIVING", Vector3(RECEIVING_DOOR.x, 1.1, RECEIVING_DOOR.y), DOOR_X, HINGE_X, 90.0],
]
## The doors that are locked for the night: the staff's rooms, furnished or not
## yet, and the manager's office.
const LOCKED := ["JANITOR", "VISITOR-BADGES", "SECURITY", "CONFERENCE", "FACILITIES", "FACILITIES-MANAGER", "BUILDING-SERVICES", "KITCHEN", "RECEIVING"]
## Its ceiling lights: [room, position, range, energy] (Level 0's lights table names the rooms).
const LIGHTS := [
	["lobby", Vector3(-10.5, 5, -15), 11.0, 1.5], ["lobby", Vector3(0, 5, -15), 11.0, 1.5], ["lobby", Vector3(10.5, 5, -15), 11.0, 1.5],
	["lobby", Vector3(-10.5, 5, -6), 11.0, 1.5], ["lobby", Vector3(0, 5, -6), 11.0, 1.5], ["lobby", Vector3(10.5, 5, -6), 11.0, 1.5],
	["lobby", Vector3(-10.5, 5, 3), 11.0, 1.5], ["lobby", Vector3(0, 5, 3), 11.0, 1.5], ["lobby", Vector3(10.5, 5, 3), 11.0, 1.5],
	["hall", Vector3(20, 3, HALL_Z), 6.0, 1.1], ["hall", Vector3(28, 3, HALL_Z), 6.0, 1.1],
	["hall", Vector3(36, 3, HALL_Z), 6.0, 1.1], ["hall", Vector3(44, 3, HALL_Z), 6.0, 1.1],
	["corridor", Vector3(-36, 3, CORRIDOR_Z), 6.0, 1.0], ["corridor", Vector3(-28, 3, CORRIDOR_Z), 6.0, 1.0],
	["corridor", Vector3(-20, 3, CORRIDOR_Z), 6.0, 1.0], ["corridor", Vector3(-12, 3, CORRIDOR_Z), 6.0, 1.0],
	["corridor", Vector3(-4, 3, CORRIDOR_Z), 6.0, 1.0], ["corridor", Vector3(4, 3, CORRIDOR_Z), 6.0, 1.0],
	["corridor", Vector3(12, 3, CORRIDOR_Z), 6.0, 1.0], ["corridor", Vector3(20, 3, CORRIDOR_Z), 6.0, 1.0],
	["mailroom", Vector3(-36.75, 3, -26.5), 6.5, 1.0], ["mailroom", Vector3(-30.75, 3, -26.5), 6.5, 1.0],
	["restrooms", Vector3(-24.75, 3, -26), 5.5, 0.8], ["restrooms", Vector3(-16.75, 3, -26), 5.5, 0.8],
	["cafeteria", Vector3(-9, 3.5, -25), 8.0, 1.1], ["cafeteria", Vector3(0, 3.5, -25), 8.0, 1.1], ["cafeteria", Vector3(9, 3.5, -25), 8.0, 1.1],
	["cafeteria", Vector3(-9, 3.5, -30), 8.0, 1.1], ["cafeteria", Vector3(0, 3.5, -30), 8.0, 1.1], ["cafeteria", Vector3(9, 3.5, -30), 8.0, 1.1],
	["it_closet", Vector3(17, 3, -25), 5.0, 0.7],
	["elevators", Vector3(53, 3.2, -2), 7.0, 1.1], ["elevators", Vector3(53, 3.2, -8), 7.0, 1.1],
]
## The dead fitting in the dark east corridor.
const DEAD_LIGHT := Vector3(31, 2.97, CORRIDOR_Z)

## Furniture other things are placed against (Level 0's papers, DressLevel0's
## props): the mailroom's pigeonholes, sorting table and cart, the cafeteria's
## tables (two rows of five), serving counter and the coffee machine of its two
## vending machines, the IT closet's crate and ceiling access panel (Level 0's
## leg-up), and the forgotten closet's shelf.
const PIGEONHOLES := Vector3(MAILROOM.position.x + 9.6, 1.1, MAILROOM.position.y + 0.4)
const SORTING_TABLE := Vector3(MAILROOM.position.x + 9.2, 0.45, MAILROOM.position.y + 4.5)
const MAIL_CART := Vector3(MAILROOM.position.x + 1.0, 0.5, MAILROOM.position.y + 7.0)
const CAFE_TABLES_X := [-10.0, -5.0, 0.0, 5.0, 10.0]
const CAFE_TABLES_Z := [-25.5, -29.0]
const SERVING_COUNTER := Vector3(0, 0.5, CAFETERIA.position.y + 0.6)
const SERVING_COUNTER_SIZE := Vector3(16.0, 1.0, 0.9)
## The two vending machines stand against the cafeteria's south wall, just east of
## its door, facing the room: the coffee machine, then the snack machine beside it.
const VENDING_AT := Vector3(CAFETERIA_DOOR_X + 2.2, 0.9, CAFETERIA.end.y - 0.6)
const VENDING_NEXT := Vector3(1.2, 0, 0)
const VENDING_SIZE := Vector3(0.8, 1.8, 0.9)
## Facilities: the counter inside its door where work orders are handed in (its
## public side faces the door), six cubicles in two rows of three, back to back
## along a spine (CUBICLES is the spine's west end; each cubicle is CUBICLE wide
## and deep), and the plan table, in view of the hall's glass.
const FACILITIES_COUNTER := Vector3(FACILITIES_DOOR.x, 0, FACILITIES.end.y - 4.2)
const FACILITIES_COUNTER_LONG := 5.0
const CUBICLES := Vector3(FACILITIES.position.x + 1.2, 0, FACILITIES.position.y + 5.0)
const CUBICLE := Vector2(2.6, 2.4)
const PLAN_TABLE := Vector3(FACILITIES_WINDOW.x + 2.0, 0, FACILITIES.end.y - 6.0)
## The manager's desk (whoever sits at it faces the office's glass), and the
## conference room's table.
const MANAGER_DESK := Vector3(MANAGER.position.x + 3.3, 0, MANAGER.position.y + 2.4)
const CONFERENCE_TABLE := Vector3(CONFERENCE.position.x + 7.5, 0, CONFERENCE.position.y + 3.7)
const CONFERENCE_TABLE_SIZE := Vector3(6.0, 0.74, 1.4)
## The kitchen. Its serving hatch is over the cafeteria's serving counter (the
## counter's top is its sill), shut for the night by a roller grille you can see
## through; the pass counter is under it on the kitchen's side. The walk-in cold
## room fills the north-east corner, its door in its west side. The dish station
## is along the east wall (DISH_STATION is on its top).
const SERVING_HATCH := Vector2(SERVING_COUNTER.x, CAFETERIA.position.y)
const SERVING_HATCH_WIDE := 8.0
const SERVING_HATCH_HEAD := 2.3
const PASS_COUNTER_SIZE := Vector3(SERVING_HATCH_WIDE, 0.9, 0.7)
const PASS_COUNTER := Vector3(SERVING_HATCH.x, PASS_COUNTER_SIZE.y / 2.0, KITCHEN.end.y - 0.1 - PASS_COUNTER_SIZE.z / 2.0)
const WALK_IN := Rect2(KITCHEN.end.x - 3.0, KITCHEN.position.y, 3.0, 3.0)
const WALK_IN_DOOR := Vector3(WALK_IN.position.x, 1.0, WALK_IN.position.y + 1.6)
const WALK_IN_DOOR_SIZE := Vector3(0.08, 2.0, 1.0)
const DISH_STATION := Vector3(KITCHEN.end.x - 0.5, 0.9, KITCHEN.end.y - 2.3)
## The janitor's closet: the shelves on its north wall (the floor under their middle).
const JANITOR_SHELVES := Vector3(JANITOR.position.x + 1.7, 0, JANITOR.position.y + 0.3)
## Building Services. The air handler stands against the west wall, its top flat
## and clear of the ceiling by more than a crawl; its supply drops into the floor
## through the plenum on its south end, and the floor south of that is kept clear.
## The engineer's bench is along the east wall (ENGINEERS_BENCH is on its top).
const AIR_HANDLER := Rect2(BUILDING_SERVICES.position.x + 0.5, BUILDING_SERVICES.position.y + 3.5, 3.4, 4.6)
const AIR_HANDLER_H := 1.9
const PLENUM := Vector3(AIR_HANDLER.position.x + 1.5, 0.6, AIR_HANDLER.end.y + 0.45)
const PLENUM_SIZE := Vector3(1.2, 1.2, 0.9)
const ENGINEERS_BENCH := Vector3(BUILDING_SERVICES.end.x - 0.5, 0.9, BUILDING_SERVICES.end.y - 3.2)
const ENGINEERS_BENCH_LONG := 4.0
## Receiving. The roll-up door to the dock is in the north wall, shut. Pallet
## racking runs along the west wall: two decks (RACK_DECKS are their tops), the top
## one clear of the ceiling by more than a crawl. The parcel cage fills the
## north-east corner, mesh to the ceiling, its gate in its west side.
const ROLLUP_DOOR := Vector3(RECEIVING_DOOR.x, 1.3, RECEIVING.position.y + 0.14)
const ROLLUP_DOOR_SIZE := Vector3(3.0, 2.6, 0.08)
const RACKING := Rect2(RECEIVING.position.x + 0.1, RECEIVING.position.y + 0.6, 1.1, 7.2)
const RACK_DECKS := [0.95, 1.9]
const PARCEL_CAGE := Rect2(RECEIVING.end.x - 3.0, RECEIVING.position.y, 3.0, 4.0)
const CAGE_GATE := Vector3(PARCEL_CAGE.position.x, 1.05, PARCEL_CAGE.end.y - 1.0)
const CAGE_GATE_SIZE := Vector3(0.04, 2.1, 1.1)
const IT_CRATE := Vector3(IT_CLOSET.position.x + 4.8, 0.3, IT_CLOSET.position.y + 0.6)
const IT_HATCH := Vector3(IT_CLOSET.position.x + 4.2, BACK_H - 0.03, IT_CLOSET.position.y + 1.4)
const CLOSET_SHELF := Vector3(CLOSET.position.x + 0.5, 0.9, VENT_Z)
## A restroom's two stalls: along its east wall from the north end, each this
## wide (east-west) and deep (north-south), with a doorway this wide in its front.
const STALL := Vector2(1.6, 1.7)
const STALL_DOORWAY := 1.0


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
static func gap(room: Rect2, wall: String, where: float, width: float, height: float, sill: float = 0.0) -> Dictionary:
	var c := room.get_center()
	var out := {"wall": wall, "at": where - (c.x if wall == "n" or wall == "s" else c.y), "width": width, "height": height}
	if sill > 0.0:
		out["bottom"] = sill
	return out


## Every opening on the floor, each listed once: [the way its wall runs ("x" for
## an east-west wall, "z" for a north-south one), its middle's x, its middle's z,
## width, height, and for a window or a hatch the height of its sill; a hatch
## then says what shuts it]. A room gets a gap wherever one lies on its walls
## (gaps_of), so the rooms either side of a wall always agree. A window is glazed
## (build): seen through, never climbed through. The kitchen's serving hatch has
## its roller grille down.
static func openings() -> Array:
	var north := CORRIDOR.position.y
	return [
		["x", FRONT_AT.x, LOBBY.end.y, FRONT_SIZE.x, FRONT_SIZE.y],  # the front doors
		["x", -AISLE_X, LOBBY.position.y, 2.0, 2.6], ["x", AISLE_X, LOBBY.position.y, 2.0, 2.6],  # round the desk
		["z", LOBBY.end.x, HALL_Z, 2.6, 3.0],  # lobby to hall
		["z", LOBBY.position.x, VENT_Z, VENT_SIZE.x, VENT_SIZE.y], ["z", CLOSET.end.x, VENT_Z, VENT_SIZE.x, VENT_SIZE.y],  # the air return
		["z", VISITOR_DOOR.x, VISITOR_DOOR.y, 1.4, 2.2],
		["z", VISITOR_WINDOW.x, VISITOR_WINDOW.y, 2.6, WINDOW_HEAD, WINDOW_SILL],
		["z", SECURITY_WINDOW.x, SECURITY_WINDOW.y, 3.6, WINDOW_HEAD, WINDOW_SILL],
		["x", FACILITIES_WINDOW.x, FACILITIES_WINDOW.y, 6.0, WINDOW_HEAD, WINDOW_SILL],
		["x", CONFERENCE_WINDOW.x, CONFERENCE_WINDOW.y, 6.0, WINDOW_HEAD, WINDOW_SILL],
		["x", SECURITY_DOOR.x, SECURITY_DOOR.y, 1.4, 2.2], ["x", CONFERENCE_DOOR.x, CONFERENCE_DOOR.y, 1.4, 2.2],
		["x", FACILITIES_DOOR.x, FACILITIES_DOOR.y, 1.4, 2.2],
		["x", PASSAGE_X, PASSAGE.end.y, 2.6, 2.6], ["x", PASSAGE_X, PASSAGE.position.y, 2.6, 2.6],  # the dark passage's two ends
		["z", CORRIDOR.end.x, CORRIDOR_Z, 2.8, 3.0],  # north corridor into the dark
		["x", BUILDING_SERVICES_DOOR.x, BUILDING_SERVICES_DOOR.y, 1.4, 2.2],
		["x", MAILROOM_DOOR_X, north, 1.4, 2.2], ["x", MENS_DOOR_X, north, 1.4, 2.2], ["x", JANITOR_DOOR_X, north, 1.1, 2.2],
		["x", WOMENS_DOOR_X, north, 1.4, 2.2], ["x", CAFETERIA_DOOR_X, north, 2.4, 2.6], ["x", IT_DOOR_X, north, 1.4, 2.2],
		["x", KITCHEN_DOOR.x, KITCHEN_DOOR.y, 1.4, 2.2], ["x", RECEIVING_DOOR.x, RECEIVING_DOOR.y, 1.4, 2.2],
		["x", SERVING_HATCH.x, SERVING_HATCH.y, SERVING_HATCH_WIDE, SERVING_HATCH_HEAD, SERVING_COUNTER_SIZE.y, "grille"],
		["z", HALL.end.x, HALL_Z, 1.8, 2.4],  # into the lift hall
		["z", LIFT_AT.x, LIFT_AT.z, Elevator.DOORWAY, Elevator.DOOR_H],
		["x", STAIR_AT.x, STAIR_AT.z, Stairwell.DOOR_W, Stairwell.DOOR_H],
	]


## Every window on the floor, as openings() lists one: the rooms' own, and the
## one in the manager's office's partition.
static func windows() -> Array:
	var out := openings().filter(func(o): return o.size() == 6)
	out.append(["x", MANAGER_WINDOW.x, MANAGER_WINDOW.y, 3.0, WINDOW_HEAD, WINDOW_SILL])
	return out


## `room`'s openings, as Greybox.room's gaps.
static func gaps_of(room: Rect2) -> Array:
	var out := []
	for o in openings():
		var x: float = o[1]
		var z: float = o[2]
		var sill: float = o[5] if o.size() > 5 else 0.0
		if o[0] == "x" and x > room.position.x and x < room.end.x:
			if is_equal_approx(z, room.position.y):
				out.append(gap(room, "n", x, o[3], o[4], sill))
			elif is_equal_approx(z, room.end.y):
				out.append(gap(room, "s", x, o[3], o[4], sill))
		elif o[0] == "z" and z > room.position.y and z < room.end.y:
			if is_equal_approx(x, room.position.x):
				out.append(gap(room, "w", z, o[3], o[4], sill))
			elif is_equal_approx(x, room.end.x):
				out.append(gap(room, "e", z, o[3], o[4], sill))
	return out


## Every room on the floor: [its rectangle, its ceiling height, its floor's colour,
## its walls' colour, and any walls it leaves to its neighbours]. The lobby is first
## (its floor is the node named "Floor"). Facilities has no north wall of its own:
## the north corridor's and the dark corridor's south walls stand there, each with
## its own look.
static func rooms() -> Array:
	var dim := LINO.darkened(0.2)
	var dim_wall := WALL.darkened(0.3)
	return [
		[LOBBY, LOBBY_H, CARPET, WALL], [HALL, HALL_H, Color(0.3, 0.3, 0.3), WALL],
		[CORRIDOR, BACK_H, LINO, WALL], [MAILROOM, BACK_H, LINO, WALL],
		[MENS, BACK_H, TILE, TILE.darkened(0.1)], [WOMENS, BACK_H, TILE, TILE.darkened(0.1)],
		[CAFETERIA, CAFETERIA_H, LINO, WALL], [IT_CLOSET, BACK_H, LINO, WALL],
		[DARK, BACK_H, dim, dim_wall], [PASSAGE, BACK_H, dim, dim_wall],
		[LIFT_HALL, LIFT_HALL_H, Color(0.35, 0.33, 0.3), WALL],
		[CLOSET, CLOSET_H, Color(0.2, 0.2, 0.2), Color(0.4, 0.38, 0.33)],
		[VISITOR_BADGES, BACK_H, LINO, WALL], [SECURITY, BACK_H, LINO, WALL], [CONFERENCE, BACK_H, LINO, WALL],
		[FACILITIES, BACK_H, LINO, WALL, ["n"]], [BUILDING_SERVICES, BACK_H, LINO, WALL], [JANITOR, BACK_H, TILE, WALL],
		[KITCHEN, BACK_H, TILE, WALL], [RECEIVING, BACK_H, LINO, WALL],
	]


## The rooms nobody can get into, behind LOCKED doors, as boxes (a level's
## `shut_rooms`). The manager's office is inside Facilities.
static func shut_rooms() -> Array[AABB]:
	var out: Array[AABB] = []
	for room in [VISITOR_BADGES, SECURITY, CONFERENCE, FACILITIES, BUILDING_SERVICES, JANITOR, KITCHEN, RECEIVING]:
		out.append(box(room, BACK_H, 0.0, 0.5, 0.5))  # its roof too
	return out


## Facilities' cubicles: [the middle of its floor, which way it opens (-1 north,
## +1 south)], the north row first, west to east.
static func cubicles() -> Array:
	var out := []
	for side in [-1.0, 1.0]:
		for k in 3:
			out.append([CUBICLES + Vector3(CUBICLE.x * (k + 0.5), 0, side * CUBICLE.y / 2.0), side])
	return out


## The floor centre of each of `room`'s stalls (a restroom), north one first.
static func stalls(room: Rect2) -> Array:
	var out := []
	for k in 2:
		out.append(Vector3(room.end.x - STALL.x / 2.0, 0, room.position.y + 0.1 + STALL.y * (k + 0.5)))
	return out


## Build the floor under `geo`.
static func build(geo: Node3D) -> void:
	for r in rooms():
		var gaps := gaps_of(r[0])
		for wall in (r[4] if r.size() > 4 else []):
			gaps.append({"wall": wall, "at": 0.0, "width": maxf(r[0].size.x, r[0].size.y), "height": r[1]})
		Greybox.room(geo, mid(r[0]), span(r[0], r[1]), {"floor": r[2], "wall": r[3]}, gaps)
	for o in windows():
		_window(geo, o)
	for o in openings():
		if o.size() > 6:
			_see_through(Greybox.box(geo, Vector3(o[1], (o[4] + o[5]) / 2.0, o[2]), Vector3(o[3], o[4] - o[5], 0.05), STEEL, "ServingGrille"), 0.5)
	_lobby(geo)
	_hall(geo)
	_back(geo)
	_back_of_house(geo)
	_lift_hall(geo)
	_closet(geo)
	# The manager's office: two partitions across Facilities' north-east corner.
	Greybox._wall(geo, mid(MANAGER), span(MANAGER, BACK_H), "w", WALL, [gap(MANAGER, "w", MANAGER_DOOR.y, 1.2, 2.2)], 0.2)
	Greybox._wall(geo, mid(MANAGER), span(MANAGER, BACK_H), "s", WALL, [gap(MANAGER, "s", MANAGER_WINDOW.x, 3.0, WINDOW_HEAD, WINDOW_SILL)], 0.2)


## The pane in a window (an opening with a sill): solid, and seen through.
static func _window(geo: Node3D, o: Array) -> void:
	var tall: float = o[4] - o[5]
	var size := Vector3(o[3], tall, 0.04) if o[0] == "x" else Vector3(0.04, tall, o[3])
	_see_through(Greybox.box(geo, Vector3(o[1], o[5] + tall / 2.0, o[2]), size, Color(0.7, 0.8, 0.82), "Window"), 0.2, 0.05)


## Make a Greybox piece one you see through (glass, a grille, mesh): it stays solid.
static func _see_through(body: StaticBody3D, alpha: float, roughness := 0.6) -> void:
	for c in body.get_children():
		if c is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			var tint: Color = ((c as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
			mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = roughness
			(c as MeshInstance3D).material_override = mat
			(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The ordinary doors (DOORS), under `parent`, named `prefix` + id. Returns them by
## id. The staff rooms' (LOCKED) are locked.
static func doors(parent: Node3D, prefix: String = "") -> Dictionary:
	var made := {}
	for d in DOORS:
		var door := Door.create(parent, prefix + d[0], d[1], d[2]).make_hinged(d[3], d[4])
		door.locked = d[0] in LOCKED
		made[d[0]] = door
	return made


## The front doors, under `parent`: they slide aside.
static func front_doors(parent: Node3D, id: String) -> Door:
	var d := Door.create(parent, id, FRONT_AT, FRONT_SIZE, FRONT_COLOR)
	d.slide_axis = Vector3.RIGHT
	return d


static func _lobby(geo: Node3D) -> void:
	var north := LOBBY.position.y
	var south := LOBBY.end.y
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
	Greybox.label(geo, Vector3(VISITOR_DOOR.x + 0.12, SIGN_Y, VISITOR_DOOR.y), "VISITOR BADGES", 36, SIGN_INK, 90)
	# A side table behind the desk (Level 0 keeps the walkie-talkies' dock on it).
	Greybox.box(geo, CHARGER_TABLE, Vector3(1.2, 0.04, 0.6), Color(0.45, 0.35, 0.2), "TableCharger")
	for leg in [Vector3(-0.55, 0, -0.25), Vector3(0.55, 0, -0.25), Vector3(-0.55, 0, 0.25), Vector3(0.55, 0, 0.25)]:
		Greybox.box(geo, Vector3(CHARGER_TABLE.x, 0.33, CHARGER_TABLE.z) + leg, Vector3(0.05, 0.66, 0.05), Color(0.3, 0.3, 0.32), "TableChargerLeg")
	# Waiting area chairs by the front doors (cover, atmosphere), facing the coffee table.
	for x in [-6.0, -4.8, 4.8, 6.0]:
		Greybox.box(geo, Vector3(FRONT_AT.x + x, 0.25, south - 2.5), Vector3(0.9, 0.5, 0.9), Color(0.3, 0.12, 0.12), "Chair")
		Seat.create_at(geo, Vector3(FRONT_AT.x + x, 0.5, south - 2.5), 0.0, Vector2(0.8, 0.8))
	Greybox.box(geo, Vector3(FRONT_AT.x - 5.4, 0.2, south - 4.2), Vector3(2.0, 0.4, 0.8), Color(0.35, 0.28, 0.2), "Table")


## The hall east to the lift hall.
static func _hall(geo: Node3D) -> void:
	Greybox.label(geo, Vector3(HALL.end.x - 0.12, 2.72, HALL_Z), "ELEVATORS  >", 64, Color(0.7, 0.1, 0.1), -90)
	# Over the staff rooms' doors, on the hall's side of each.
	Greybox.label(geo, Vector3(SECURITY_DOOR.x, SIGN_Y, SECURITY_DOOR.y - 0.12), "SECURITY", 36, SIGN_INK, 180)
	Greybox.label(geo, Vector3(CONFERENCE_DOOR.x, SIGN_Y, CONFERENCE_DOOR.y - 0.12), "CONFERENCE ROOM", 36, SIGN_INK, 180)
	Greybox.label(geo, Vector3(FACILITIES_DOOR.x, SIGN_Y, FACILITIES_DOOR.y + 0.12), "FACILITIES", 36, SIGN_INK)
	Greybox.label(geo, Vector3(MANAGER_DOOR.x - 0.12, SIGN_Y, MANAGER_DOOR.y), "FACILITIES MANAGER", 36, SIGN_INK, -90)  # inside Facilities


## The north corridor behind the lobby and the rooms off it, and the dark east corridor.
static func _back(geo: Node3D) -> void:
	var sign_z := CORRIDOR.position.y + 0.12  # on the corridor's north wall
	Greybox.label(geo, Vector3(MAILROOM_DOOR_X, SIGN_Y, sign_z), "MAILROOM", 36, SIGN_INK)
	Greybox.label(geo, Vector3(MENS_DOOR_X, SIGN_Y, sign_z), "MEN", 36, SIGN_INK)
	Greybox.label(geo, Vector3(JANITOR_DOOR_X, SIGN_Y, sign_z), "JANITOR", 36, SIGN_INK)
	Greybox.label(geo, Vector3(WOMENS_DOOR_X, SIGN_Y, sign_z), "WOMEN", 36, SIGN_INK)
	Greybox.label(geo, Vector3(CAFETERIA_DOOR_X, 2.8, sign_z), "CAFETERIA", 48, SIGN_INK)
	Greybox.label(geo, Vector3(IT_DOOR_X, SIGN_Y, sign_z), "IT", 36, SIGN_INK)
	# The rooms behind rooms: receiving off the mailroom, the kitchen off the
	# cafeteria, Building Services off the dark corridor.
	Greybox.label(geo, Vector3(RECEIVING_DOOR.x, SIGN_Y, RECEIVING_DOOR.y + 0.12), "RECEIVING", 36, SIGN_INK)
	Greybox.label(geo, Vector3(KITCHEN_DOOR.x, SIGN_Y, KITCHEN_DOOR.y + 0.12), "KITCHEN", 36, SIGN_INK)
	Greybox.label(geo, Vector3(BUILDING_SERVICES_DOOR.x, SIGN_Y, BUILDING_SERVICES_DOOR.y + 0.12), "BUILDING SERVICES", 36, SIGN_INK)

	# Mailroom. Pigeonholes, a sorting table, a cart.
	Greybox.box(geo, PIGEONHOLES, Vector3(5.5, 2.2, 0.6), Color(0.45, 0.38, 0.28), "Pigeonholes")
	Greybox.box(geo, SORTING_TABLE, Vector3(3.0, 0.9, 1.2), Color(0.5, 0.45, 0.38), "SortingTable")
	Greybox.box(geo, MAIL_CART, Vector3(1.0, 1.0, 1.4), Color(0.35, 0.35, 0.38), "MailCart")

	# Restrooms: sinks along the west wall, and two stalls along the east wall with
	# a wide aisle in front of them.
	var panel := Color(0.55, 0.6, 0.62)
	for room in [MENS, WOMENS]:
		Greybox.box(geo, at(room, 0.25, 0.45, 5.0), Vector3(0.5, 0.9, 2.0), Color(0.85, 0.85, 0.82), "Sinks")
		var front: float = room.end.x - STALL.x  # the stalls' fronts
		var jamb := (STALL.y - STALL_DOORWAY) / 2.0  # the panel either side of a stall's doorway
		for stall in stalls(room):
			Greybox.box(geo, Vector3(stall.x, 1.0, stall.z + STALL.y / 2.0), Vector3(STALL.x, 2.0, 0.05), panel, "StallWall")  # its south side
			for side in [-1.0, 1.0]:
				Greybox.box(geo, Vector3(front, 1.0, stall.z + side * (STALL.y - jamb) / 2.0), Vector3(0.05, 2.0, jamb), panel, "StallWall")

	# Cafeteria. Tables to hop, a serving counter, vending machines.
	for tx in CAFE_TABLES_X:
		for tz in CAFE_TABLES_Z:
			Greybox.box(geo, Vector3(tx, 0.375, tz), Vector3(2.0, 0.75, 1.0), Color(0.55, 0.42, 0.3), "CafTable")
	Greybox.box(geo, SERVING_COUNTER, SERVING_COUNTER_SIZE, Color(0.6, 0.6, 0.62), "ServingCounter")
	Greybox.box(geo, VENDING_AT, VENDING_SIZE, Color(0.25, 0.3, 0.5), "VendingMachine")
	Greybox.box(geo, VENDING_AT + VENDING_NEXT, VENDING_SIZE, Color(0.6, 0.15, 0.12), "VendingMachine")

	# IT closet. Shelves of spares and a patch panel.
	Greybox.box(geo, at(IT_CLOSET, 0.4, 1.0, 3.0), Vector3(0.6, 2.0, 3.4), Color(0.4, 0.4, 0.42), "SpareShelf")
	Greybox.box(geo, at(IT_CLOSET, IT_CLOSET.size.x - 0.3, 1.3, 1.5), Vector3(0.3, 1.2, 1.6), Color(0.12, 0.12, 0.14), "PatchPanel")
	Greybox.box(geo, IT_CRATE, Vector3(0.8, 0.6, 0.6), Color(0.45, 0.35, 0.2), "Crate")

	# The dark east corridor and its passage south to the hall. No working lights.
	Greybox.panel(geo, DEAD_LIGHT, Vector3(1.2, 0.05, 0.3), Color(0.3, 0.3, 0.3))  # a dead light


## What stands in the back of house, behind the staff's locked doors: the
## kitchen's pass counter and walk-in, Building Services' air handler, and
## receiving's roll-up door, racking and parcel cage. Their furniture is
## DressGroundBack's.
static func _back_of_house(geo: Node3D) -> void:
	# The kitchen: the pass under the hatch, and the walk-in, panelled to the ceiling.
	Greybox.box(geo, PASS_COUNTER, PASS_COUNTER_SIZE, STEEL, "PassCounter")
	var panel := Color(0.8, 0.81, 0.8)
	var t := 0.1
	var wi := WALK_IN
	Greybox.box(geo, Vector3(wi.get_center().x, BACK_H / 2.0, wi.end.y - t / 2.0), Vector3(wi.size.x, BACK_H, t), panel, "WalkIn")  # its south side
	_side_with_doorway(geo, wi.position.x + t / 2.0, wi.position.y, wi.end.y, WALK_IN_DOOR.z, WALK_IN_DOOR_SIZE.z, WALK_IN_DOOR_SIZE.y, t, panel, "WalkIn")
	Greybox.box(geo, WALK_IN_DOOR + Vector3(t / 2.0, 0, 0), WALK_IN_DOOR_SIZE, panel.darkened(0.12), "WalkInDoor")  # shut

	# Building Services: the air handler, the plenum that takes its supply down
	# into the floor, and the return duct into its top.
	var unit := Color(0.55, 0.6, 0.62)
	var ah := AIR_HANDLER
	Greybox.box(geo, mid(ah, AIR_HANDLER_H / 2.0), span(ah, AIR_HANDLER_H), unit, "AirHandler")
	Greybox.box(geo, PLENUM, PLENUM_SIZE, unit, "Plenum")
	Greybox.box(geo, Vector3(ah.get_center().x, (AIR_HANDLER_H + BACK_H) / 2.0, ah.position.y + 0.8), Vector3(1.2, BACK_H - AIR_HANDLER_H, 1.2), unit, "ReturnDuct")

	# Receiving: the roll-up door, down; the racking; the parcel cage, its gate
	# swung right back against it.
	Greybox.box(geo, ROLLUP_DOOR, ROLLUP_DOOR_SIZE, Color(0.6, 0.62, 0.6), "RollUpDoor")
	var rk := RACKING
	for top in RACK_DECKS:
		Greybox.box(geo, Vector3(rk.get_center().x, top - 0.04, rk.get_center().y), Vector3(rk.size.x, 0.08, rk.size.y), Color(0.7, 0.55, 0.35), "RackDeck")
	for k in 3:
		for x in [rk.position.x + 0.04, rk.end.x - 0.04]:
			Greybox.box(geo, Vector3(x, RACK_DECKS[1] / 2.0, rk.position.y + 0.04 + k * (rk.size.y - 0.08) / 2.0), Vector3(0.08, RACK_DECKS[1], 0.08), Color(0.2, 0.3, 0.55), "RackPost")
	var mesh := Color(0.45, 0.47, 0.5)
	var cg := PARCEL_CAGE
	_see_through(Greybox.box(geo, Vector3(cg.get_center().x, BACK_H / 2.0, cg.end.y), Vector3(cg.size.x, BACK_H, 0.06), mesh, "CagePanel"), 0.4)  # its south side
	for piece in _side_with_doorway(geo, cg.position.x, cg.position.y, cg.end.y, CAGE_GATE.z, CAGE_GATE_SIZE.z, CAGE_GATE_SIZE.y, 0.06, mesh, "CagePanel"):
		_see_through(piece, 0.4)
	_see_through(Greybox.box(geo, CAGE_GATE + Vector3(-0.06, 0, -CAGE_GATE_SIZE.z), CAGE_GATE_SIZE, mesh, "CageGate"), 0.4)


## A north-south partition to the ceiling at `x`, from z `north` to `south`, with a
## doorway `wide` and `tall` whose middle is at z `door`. Returns its pieces.
static func _side_with_doorway(geo: Node3D, x: float, north: float, south: float, door: float, wide: float, tall: float, t: float, color: Color, piece_name: String) -> Array:
	var out := []
	var jambs := [[north, door - wide / 2.0, 0.0], [door + wide / 2.0, south, 0.0], [door - wide / 2.0, door + wide / 2.0, tall]]
	for j in jambs:
		out.append(Greybox.box(geo, Vector3(x, (j[2] + BACK_H) / 2.0, (j[0] + j[1]) / 2.0), Vector3(t, BACK_H - j[2], j[1] - j[0]), color, piece_name))
	return out


## The lift hall, through the door at the end of the hall. Two of its three
## lifts are out of service: their doors stay shut.
static func _lift_hall(geo: Node3D) -> void:
	for z in SPARE_LIFTS_Z:
		Greybox.box(geo, Vector3(LIFT_AT.x - 0.07, Elevator.DOOR_H / 2.0, z), Vector3(0.06, Elevator.DOOR_H, Elevator.DOORWAY), Color(0.55, 0.56, 0.58), "LiftDoorsShut")


## The forgotten storage closet behind the lobby's air return, and the duct to it.
static func _closet(geo: Node3D) -> void:
	Traversal.vent(geo, Vector3(LOBBY.position.x, 0.0, VENT_Z), Vector3(CLOSET.end.x, 0.0, VENT_Z), VENT_SIZE)
	Greybox.box(geo, CLOSET_SHELF, Vector3(0.8, 1.8, 3), Color(0.35, 0.35, 0.35), "Shelf")
