extends LevelBase
## Level 3: Records Archive, floor 18 ("Mercer's Room").
## The crew comes down the emergency stairs from 22 (the lifts are dead) into a
## records archive at night: a lift lobby, the records desk and reading room, the
## stacks (towering shelves you can climb and cross along the tops), a loop of halls
## round them with side rooms, the shredding room and the microfiche room at the
## north end. One side room hides Mercer's safe room: no network, no grid power, an
## analog lock. The first floppy disk of evidence is in there, and so is the key to
## the stairs down.
##
## Puzzles: ON HOLD (plan/level-3-records-archive.md). Each station has a Puzzle
## whose check can be swapped once the curriculum is settled; the defaults below are
## the old plan's and have no hints or SYSOP text yet. The data they read is built
## (Level3Data) with a visible source for every row.
## The Shredder (scripts/npc/shredder.gd) sleeps among the machines until the first
## crank is turned, then hunts by sound; the level feeds it every loud thing (`noise`).
##
## Layout (level space, north is -z):
##   lobby           x -4..4,    z 4..8     stairs in (west wall), stairs out (east wall)
##   reading room    x -8..8,    z -6..4    records desk, tables, card drawers
##   stacks          x -8..8,    z -22..-6  five shelf units A1..A5, climbable, 5.6 m ceiling
##   west/east halls x -11..-8 and 8..11, z -22..-2
##   side rooms      Vault C and the map room off the west hall, the cold store and the
##                   supply closet off the east hall; one of the three big ones hides
##                   the safe room behind its rolling shelves (Level3Data.host)
##   north corridor  x -11..11,  z -25..-22
##   shredding room  x -11..0,   z -33..-25 (the Shredder's lair)
##   microfiche room x 2..11,    z -31..-25 (the archive intranet terminal)
##
## Co-op: the host decides (cranks, pickups, the exit) and every machine plays it out
## through sync.event; the shelving tweens are driven from those events.

## Fired once the crew is on the stairs down: the wing is done.
signal completed
## Something loud happened (a crank, a dropped box): where and how loud (0..1).
## The Shredder listens to this (next PR), alongside each player's noise_made.
signal noise(at: Vector3, loudness: float)

## Player-facing lines, drafted for Augustine's approval: plan/approvals/l3-text.md.
const TEXT := {
	"todo_arrive": "Find a way down from 18",
	"todo_key": "Mercer's key opens the stairs. Everyone to the lobby",
	"todo_room": "One room on 18 kept its reader busy that night. Find it",
	"found_room": "A hidden room. No network jack, no grid power. The building can't see in here.",
	"floppy": "A 3.5\" floppy, hand-labelled. The first thing in this building that isn't on its network.",
	"key": "A brass key ring: STAIR 1 / 18.",
	"stairs_wait": "Waiting for everyone on the stairs (%d/%d)",
	"case_room": "Which room did someone keep going back to that night?",
	"end_card": "To be continued.",
	"shredder_wakes": "North of here, the machines stop. Something heavy gets up.",
}
## The level's case pages in the notebook (Cases tab), by id.
const CASES := {"room": TEXT.case_room}

## Where the side rooms sit (level space) and which wall is their back wall.
## `back` points from the room into its back wall; the safe room is beyond it.
const SIDE_ROOMS := {
	"VAULT C": {"center": Vector3(-13.5, 0, -19), "back": Vector3(-1, 0, 0), "door_id": "ARC-VAULT-C", "label": "VAULT C"},
	"MAP ROOM": {"center": Vector3(-13.5, 0, -11), "back": Vector3(-1, 0, 0), "door_id": "ARC-MAP", "label": "MAP ROOM"},
	"COLD STORE": {"center": Vector3(13.5, 0, -19), "back": Vector3(1, 0, 0), "door_id": "ARC-COLD", "label": "COLD STORE"},
}
const SIDE_ROOM_SIZE := Vector3(5, 3.2, 6)
const SAFE_ROOM_SIZE := Vector3(5, 3, 6)
## Rolling compact shelving: four units a hand crank slides along the room.
const UNITS := 4
const UNIT_PITCH := 0.8
const UNIT_SIZE := Vector3(0.6, 2.4, 5.4)
const CRANK_TRAVEL := 1.3
## A crank is heard across the floor (Shredder.HEAR_RANGE units).
const CRANK_LOUDNESS := 2.0
const SIDE_DOOR := Vector3(0.08, 2.3, 1.0)  # thin along x: a door in a wall that runs along z
## Where the stairs meet the lobby's walls.
const STAIR_IN_AT := Vector3(-4, 0, 6)
const STAIR_OUT_AT := Vector3(4, 0, 6)
## Where the Shredder starts (level space): among the machines, clear of the conveyor.
const SHREDDER_HOME := Vector3(-5.5, 0, -27)
## The shredding room: its machines drown out any sound in it (level space).
const SHRED_ROOM := AABB(Vector3(-11, -1, -33), Vector3(11, 5, 8))
## Where it wanders between sounds once awake (level space).
const ROAM_POINTS := [Vector3(0, 0, -23.5), Vector3(-4.5, 0, -14), Vector3(4.5, 0, -14), Vector3(-9.5, 0, -8), Vector3(9.5, 0, -8), Vector3(0, 0, -1)]

var data: Dictionary
var desk: Terminal
var fiche: Terminal
var stair_in: Door
var stair_out: Door
var room_doors := {}  # reader room -> Door
var cranks := {}  # reader room -> Interactable
var shelving := {}  # reader room -> Array[AnimatableBody3D]
var cranked := {}  # reader room -> bool
var safe_door: Door
var safe_room_box := AABB()
var reached_safe := false
var floppy: ItemDock
var key_dock: ItemDock
var key_taken := false
var floppy_taken := false
var exit_trigger: Trigger
var shredder: Shredder
## The first crank has been turned: the floor knows what's hunting it now.
var shredder_awake := false
## The stacks' shelf units, for the climb tests and the dressing pass.
var stack_units: Array[StaticBody3D] = []

## Puzzle stations. HOLD: the checks below are the old plan's defaults (COUNT review,
## DISTINCT, GROUP BY), kept so the stations and gates work and tests run. No hints
## until the architect confirms which skill each station teaches.
var slips_puzzle := Puzzle.new("slips", "SELECT COUNT(*) FROM retrieval_slips WHERE status = 'open'", ["count(*)"], false)
var depts_puzzle := Puzzle.new("depts", "SELECT DISTINCT dept FROM catalogue WHERE room = 'STACKS'", ["dept"], false)
var visits_puzzle := Puzzle.new("visits", "SELECT room FROM access_log WHERE time LIKE '%s%%' GROUP BY room ORDER BY COUNT(*) DESC" % Level3Data.NIGHT, ["room"], true)


func build() -> void:
	data = Level3Data.build(Game.run_seed)
	load_level_seed(data.sql)
	slips_puzzle.case_id = "room"
	depts_puzzle.case_id = "room"
	visits_puzzle.case_id = "room"

	var floor_c := Color(0.26, 0.25, 0.23)
	var wall_c := Color(0.56, 0.54, 0.48)
	var colors := {"floor": floor_c, "wall": wall_c}
	# Lift lobby: the dead lifts on the south wall, stairs either side.
	Greybox.room(geo, Vector3(0, 0, 6), Vector3(8, 3.2, 4), colors, [
		{"wall": "n", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "w", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},
		{"wall": "e", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},
	])
	Greybox.label(geo, Vector3(0, 2.75, 4.12), "18   RECORDS ARCHIVE", 56, Color(0.75, 0.75, 0.7))
	for x in [-1.5, 1.5]:
		Greybox.panel(geo, Vector3(x, 1.1, 7.88), Vector3(1.3, 2.2, 0.04), Color(0.5, 0.52, 0.55), 0.0)
		Greybox.label(geo, Vector3(x, 2.5, 7.86), "ELEVATOR  18", 32, Color(1.0, 0.45, 0.1), 180)
	# Facilities memo by the lifts: day staff use the stairs until the lifts are fixed.
	Document.place(geo, Vector3(0, 1.5, 7.87), 180, "Facilities memo", [
		"HALCYON DATA SYSTEMS  -  FACILITIES",
		"MEMO  10/13",
		"Lifts 1-4 are out of service pending inspection.",
		"Until further notice, use STAIR 1 between floors.",
		"Stair doors lock at 19:00. Do not prop them.",
		"- Facilities, ext. 2200",
	], false, "paper").clues = []
	# Stairs in from 22, on the lobby's west wall. Day staff wedged it open, memo or no memo.
	stair_in = Stairwell.build(self, geo, STAIR_IN_AT, 90.0, "18")
	stair_in.name = "Door_STAIR-IN"
	stair_in.locked = false
	Greybox.box(geo, STAIR_IN_AT + Vector3(0.1, 0.03, 0.55), Vector3(0.12, 0.06, 0.2), Color(0.6, 0.45, 0.2), "DoorWedge")
	Document.place(geo, STAIR_IN_AT + Vector3(0.12, 1.75, -0.9), 90.0, "Door sign", [
		"FIRE DOOR",
		"KEEP CLOSED",
		"DO NOT PROP",
	], false, "laminated", Vector2(0.22, 0.16))
	# Stairs out, down toward 14, on the east wall: locked after hours. Mercer's key opens it.
	stair_out = Stairwell.build(self, geo, STAIR_OUT_AT, -90.0, "18")
	stair_out.name = "Door_STAIR-OUT"
	exit_door = stair_out
	exit_trigger = Trigger.create(self, STAIR_OUT_AT + Vector3(2.4, 1, 0), Vector3(2.8, 2, 3.2))
	exit_trigger.name = "StairsDown"
	exit_trigger.require_all = true
	exit_trigger.waiting.connect(func(n, total): sync.team_notice(TEXT.stairs_wait % [n, total]))
	exit_trigger.entered.connect(func(_b): sync.event("_on_exit"), CONNECT_ONE_SHOT)

	_build_reading_room(colors)
	_build_stacks(colors)
	_build_halls(colors)
	for room in SIDE_ROOMS:
		_build_side_room(room, colors)
	_build_supply(colors)
	_build_north(colors)
	_build_safe_room()

	# Lights follow the `lights` table (sync_world): the stacks' sensor lights are off
	# after hours, the microfiche room's tube is out.
	add_light("L18-LOBBY", Vector3(0, 3.2, 6), 6.0, 0.9)
	add_light("L18-DESK", Vector3(0, 3.2, 1.5), 7.0, 1.0)
	for x in [-5.0, 5.0]:
		add_light("L18-READ", Vector3(x, 3.2, -3), 7.0, 0.9)
	for z in [-9.0, -14.0, -19.0]:
		add_light("L18-STACKS", Vector3(0, 5.6, z), 9.0, 0.9)
	for z in [-6.0, -16.0]:
		add_light("L18-HALL-W", Vector3(-9.5, 3.2, z), 6.0, 0.8)
		add_light("L18-HALL-E", Vector3(9.5, 3.2, z), 6.0, 0.8)
	for x in [-7.0, 0.0, 7.0]:
		add_light("L18-NORTH", Vector3(x, 3.2, -23.5), 6.0, 0.8)
	for x in [-8.5, -2.5]:
		add_light("L18-SHRED", Vector3(x, 3.6, -29), 8.0, 1.1, Color(1.0, 0.95, 0.85))
	FlickerLight.attach(add_light("L18-FICHE", Vector3(6.5, 3.2, -28), 6.0, 0.5), 0.3)
	add_light("L18-VAULT-C", Vector3(-13.5, 3.2, -19), 6.0, 0.8)
	add_light("L18-MAP", Vector3(-13.5, 3.2, -11), 6.0, 0.8)
	add_light("L18-COLD", Vector3(13.5, 3.2, -19), 6.0, 0.8, Color(0.85, 0.92, 1.0))

	spawn = _stair_landing(STAIR_IN_AT, 90.0)

	shredder = Shredder.new()
	shredder.name = "Shredder"
	shredder.space = self
	shredder.mask_zones = [SHRED_ROOM]
	shredder.roam_points.assign(ROAM_POINTS)
	shredder.position = SHREDDER_HOME  # before add_child: a body at the origin for a step can set off triggers
	add_child(shredder)
	noise.connect(func(at, loudness): if sync.is_host(): shredder.hear(at, loudness))


## A spot on a stairwell's landing, clear of the flight, facing its door.
func _stair_landing(at: Vector3, yaw_deg: float) -> Transform3D:
	var holder := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg + 180.0)), holder * Vector3(-0.8, 0.1, -1.3))


func player_spawn(index: int) -> Transform3D:
	# Six people fit on the landing in a row along the flight, not spread into the walls.
	var holder := Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), STAIR_IN_AT)
	var slot := holder * Vector3(-0.8 + 0.5 * (index % 2), 0.1, -0.7 - 0.55 * (index / 2))
	return global_transform * Transform3D(spawn.basis, slot)


## Level 2 calls this (through the World) as the crew heads down STAIR 1: everyone
## is placed on 18's landing before play moves here. Runs on every machine.
func arrive_by_stairs() -> void:
	players.place_all(self)


func _build_reading_room(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(0, 0, -1), Vector3(16, 3.2, 10), colors, [
		{"wall": "s", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "n", "at": -4.0, "width": 2.0, "height": 2.6},
		{"wall": "n", "at": 4.0, "width": 2.0, "height": 2.6},
		{"wall": "w", "at": -3.0, "width": 1.0, "height": 2.3},
		{"wall": "e", "at": -3.0, "width": 1.0, "height": 2.3},
	])
	Greybox.label(geo, Vector3(0, 2.75, 3.88), "RECORDS", 56, Color(0.75, 0.75, 0.7), 180)
	# The records desk faces the lobby door, with its terminal and the slip spike.
	Greybox.box(geo, Vector3(0, 0.5, 1.6), Vector3(4.0, 1.0, 0.8), Color(0.4, 0.34, 0.28), "RecordsDesk")
	desk = Terminal.spawn(geo, Vector3(-0.8, 1.0, 1.6), 0, "RECORDS DESK", db, terminal_ui)
	desk.name = "DeskTerminal"
	desk.puzzles = [slips_puzzle, depts_puzzle, visits_puzzle]
	desk.boot_lines = [
		"HALCYON RECORDS  -  ARCHIVE DESK  -  FLOOR 18",
		"Box requests: see retrieval_slips. Holdings: catalogue. Reader events: access_log.",
	]
	desk.queried.connect(_on_query.bind("desk"))
	# The spike of paper slips: the open requests, as the desk left them.
	var slip_lines: Array = ["RETRIEVAL SLIPS  -  OPEN", {"columns": ["SLIP", "BOX", "FOR"], "widths": [1.6, 2.2, 2.4]}]
	for row in db.run_silent("SELECT slip_no, box_id, requested_by FROM retrieval_slips WHERE status = 'open' ORDER BY slip_no"):
		slip_lines.append({"row": [row["slip_no"], row["box_id"], row["requested_by"]], "hand": true})
	Document.place(geo, Vector3(1.2, 1.0, 1.6), 0, "Retrieval slips", slip_lines, true, "clipboard")
	Greybox.box(geo, Vector3(1.2, 1.1, 1.6), Vector3(0.02, 0.2, 0.02), Color(0.6, 0.6, 0.62), "SlipSpike")
	# Reading tables: a top on four legs, so there's room to hide under them.
	for pos in [Vector3(-4.5, 0, -3), Vector3(4.5, 0, -3)]:
		_table(pos, Vector3(2.4, 0.75, 1.1))
	# The card catalogue along the west wall: drawers labelled by range.
	Greybox.box(geo, Vector3(-7.5, 0.7, 1.0), Vector3(0.9, 1.4, 3.6), Color(0.45, 0.32, 0.2), "CardCatalogue")
	Greybox.label(geo, Vector3(-7.03, 1.5, 1.0), "CATALOGUE  A - Z", 30, Color(0.95, 0.92, 0.85), 90)
	# The stacks' lighting panel by the stacks doors: why it's dark through there.
	Document.place(geo, Vector3(-1.6, 1.5, -5.88), 0, "Stacks lighting notice", [
		"STACKS LIGHTING",
		"Occupancy sensors. Lights come on with motion 07:00-19:00.",
		"After 19:00 the sensors are off. Override at the records desk (archivist key).",
	], false, "laminated", Vector2(0.3, 0.3))


## A table top on four legs: something to hide under.
func _table(pos: Vector3, size: Vector3) -> void:
	Greybox.box(geo, pos + Vector3(0, size.y - 0.03, 0), Vector3(size.x, 0.06, size.z), Color(0.42, 0.36, 0.3), "Table")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Greybox.box(geo, pos + Vector3(sx * (size.x / 2 - 0.06), (size.y - 0.06) / 2, sz * (size.z / 2 - 0.06)), Vector3(0.08, size.y - 0.06, 0.08), Color(0.3, 0.3, 0.32), "TableLeg")


func _build_stacks(colors: Dictionary) -> void:
	# A tall room: the shelf tops are 2 m under the ceiling, so you can stand up there.
	Greybox.room(geo, Vector3(0, 0, -14), Vector3(16, 5.6, 16), {"floor": colors.floor, "wall": colors.wall, "ceiling": Color(0.35, 0.35, 0.34)}, [
		{"wall": "s", "at": -4.0, "width": 2.0, "height": 2.6},
		{"wall": "s", "at": 4.0, "width": 2.0, "height": 2.6},
		{"wall": "n", "at": -4.0, "width": 2.0, "height": 2.6},
		{"wall": "n", "at": 4.0, "width": 2.0, "height": 2.6},
		{"wall": "w", "at": 0.0, "width": 1.0, "height": 2.3},
		{"wall": "e", "at": 0.0, "width": 1.0, "height": 2.3},
	])
	var shelf_c := Color(0.42, 0.44, 0.4)
	for i in 5:
		var x := -6.0 + i * 3.0
		var unit := Greybox.box(geo, Vector3(x, 1.8, -15), Vector3(1.2, 3.6, 10), shelf_c, "ShelfUnit")
		stack_units.append(unit)
		var aisle := "A%d" % (i + 1)
		Greybox.label(geo, Vector3(x, 3.2, -9.88), aisle, 64, Color(0.95, 0.9, 0.8))
		Greybox.label(geo, Vector3(x, 3.2, -20.12), aisle, 64, Color(0.95, 0.9, 0.8), 180)
		# Box labels on the shelf faces: the catalogue's rows, where you can read them.
		for row in db.run_silent("SELECT box_id, dept, shelf FROM catalogue WHERE aisle = '%s' AND status != 'destroyed' ORDER BY shelf LIMIT 6" % aisle):
			var y := 0.5 + int(row["shelf"]) * 0.5
			var z := -18.5 + (int(row["shelf"]) % 4) * 2.0
			Greybox.label(geo, Vector3(x + 0.61, y, z), "%s\n%s" % [row["box_id"], row["dept"]], 18, Color(0.15, 0.12, 0.1), 90)
		# Each unit's end face is a ladder of shelf edges: climb it, then cross along the tops.
		Traversal.climbable(geo, Vector3(x, 0, -10), Vector3(x, 3.6, -10), Vector3(0, 0, 1), 1.0)
		Traversal.climbable(geo, Vector3(x, 0, -20), Vector3(x, 3.6, -20), Vector3(0, 0, -1), 1.0)
	# A records cart left in an aisle: cover, and something to climb from.
	Greybox.box(geo, Vector3(1.5, 0.45, -12), Vector3(0.7, 0.9, 1.1), Color(0.5, 0.5, 0.52), "RecordsCart")


func _build_halls(colors: Dictionary) -> void:
	# West hall, with its side rooms' doors; east hall the same.
	Greybox.room(geo, Vector3(-9.5, 0, -12), Vector3(3, 3.2, 20), colors, [
		{"wall": "e", "at": 8.0, "width": 1.0, "height": 2.3},  # reading room
		{"wall": "e", "at": -2.0, "width": 1.0, "height": 2.3},  # stacks
		{"wall": "n", "at": 0.0, "width": 1.6, "height": 2.4},  # north corridor
		{"wall": "w", "at": -7.0, "width": 1.0, "height": 2.3},  # Vault C
		{"wall": "w", "at": 1.0, "width": 1.0, "height": 2.3},  # map room
	])
	Greybox.room(geo, Vector3(9.5, 0, -12), Vector3(3, 3.2, 20), colors, [
		{"wall": "w", "at": 8.0, "width": 1.0, "height": 2.3},
		{"wall": "w", "at": -2.0, "width": 1.0, "height": 2.3},
		{"wall": "n", "at": 0.0, "width": 1.6, "height": 2.4},
		{"wall": "e", "at": -7.0, "width": 1.0, "height": 2.3},  # cold store
		{"wall": "e", "at": 1.5, "width": 1.0, "height": 2.3},  # supply closet
	])
	# Readers for the stacks' hall doors (both log as STACKS).
	_reader(Vector3(-8.12, 1.3, -14.9), 90.0)
	_reader(Vector3(8.12, 1.3, -14.9), -90.0)


## A side room off a hall: a reader by its door, rolling shelving inside with a crank
## at the door end. Cranked, the units slide toward the door and open an aisle along
## the back wall. In the host room the safe room's door is in that wall.
func _build_side_room(room: String, colors: Dictionary) -> void:
	var spec: Dictionary = SIDE_ROOMS[room]
	var c: Vector3 = spec.center
	var back: Vector3 = spec.back
	var door_wall := "w" if back.x > 0 else "e"  # the door is opposite the back wall
	var back_wall := "e" if back.x > 0 else "w"
	var gaps := [{"wall": door_wall, "at": 0.0, "width": 1.0, "height": 2.3}]
	if room == data.host:
		gaps.append({"wall": back_wall, "at": 1.0, "width": 1.0, "height": 2.2})
	Greybox.room(geo, c, SIDE_ROOM_SIZE, colors, gaps)
	var door_x: float = c.x - back.x * SIDE_ROOM_SIZE.x / 2
	Greybox.label(geo, Vector3(door_x - back.x * 0.12, 2.6, c.z), spec.label, 40, Color(0.2, 0.2, 0.2), 90.0 if back.x < 0 else -90.0)
	var d := add_door(spec.door_id, Vector3(door_x, SIDE_DOOR.y / 2, c.z), SIDE_DOOR)
	d.make_hinged(Vector3(0, 0, -0.5), 90.0 * -back.x)
	room_doors[room] = d
	_reader(Vector3(door_x - back.x * 0.12, 1.3, c.z + 0.9), 90.0 if back.x < 0 else -90.0)
	# Rolling units, back to front, on rails.
	Greybox.box(geo, c + Vector3(0, 0.02, 0), Vector3(SIDE_ROOM_SIZE.x - 0.4, 0.04, 0.1), Color(0.3, 0.3, 0.32), "Rail")
	var units: Array = []
	for i in UNITS:
		var x: float = c.x + back.x * (SIDE_ROOM_SIZE.x / 2 - 0.5 - i * UNIT_PITCH)
		units.append(_rolling_unit(Vector3(x, UNIT_SIZE.y / 2, c.z), "%s unit %d" % [room, i + 1]))
	shelving[room] = units
	cranked[room] = false
	# The crank on the front unit's end, by the door.
	var front_x: float = c.x + back.x * (SIDE_ROOM_SIZE.x / 2 - 0.5 - (UNITS - 1) * UNIT_PITCH)
	var crank := Interactable.create(self, Vector3(front_x, 1.1, c.z + UNIT_SIZE.z / 2 + 0.12), Vector3(0.3, 0.3, 0.2), "Turn the crank", Color(0.25, 0.25, 0.28))
	crank.name = "Crank_" + room.replace(" ", "")
	crank.used.connect(func(_p): sync.event("_crank", [room]))
	cranks[room] = crank


func _rolling_unit(center: Vector3, label: String) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = "RollingUnit"
	body.sync_to_physics = false
	body.position = center
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = UNIT_SIZE
	mesh.mesh = bm
	mesh.material_override = Greybox.mat(Color(0.5, 0.52, 0.48))
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = UNIT_SIZE
	shape.shape = bs
	body.add_child(shape)
	body.set_meta("label", label)
	add_child(body, true)
	return body


## A badge reader beside a door: the source of every access_log row.
func _reader(pos: Vector3, facing_deg: float) -> void:
	var r := Node3D.new()
	r.name = "Reader"
	r.position = pos
	r.rotation_degrees.y = facing_deg
	geo.add_child(r, true)
	Greybox.panel(r, Vector3.ZERO, Vector3(0.1, 0.16, 0.03), Color(0.15, 0.15, 0.16))
	Greybox.panel(r, Vector3(0, 0.05, 0.017), Vector3(0.02, 0.02, 0.005), Color(0.2, 1.0, 0.3), 3.0)


func _build_supply(colors: Dictionary) -> void:
	# A closet with a door that shuts: somewhere to hide.
	Greybox.room(geo, Vector3(12.5, 0, -10.5), Vector3(3, 3.2, 3), colors, [
		{"wall": "w", "at": 0.0, "width": 1.0, "height": 2.3},
	])
	Greybox.label(geo, Vector3(10.88, 2.6, -10.5), "SUPPLY", 36, Color(0.2, 0.2, 0.2), -90)
	var d := add_door("ARC-SUPPLY", Vector3(11, SIDE_DOOR.y / 2, -10.5), SIDE_DOOR)
	d.make_hinged(Vector3(0, 0, -0.5), -90.0)
	room_doors["SUPPLY"] = d
	_reader(Vector3(10.88, 1.3, -9.6), -90.0)
	Greybox.box(geo, Vector3(13.6, 1.0, -10.5), Vector3(0.6, 2.0, 2.4), Color(0.4, 0.4, 0.42), "SupplyShelf")


func _build_north(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(0, 0, -23.5), Vector3(22, 3.2, 3), colors, [
		{"wall": "s", "at": -9.5, "width": 1.6, "height": 2.4},
		{"wall": "s", "at": 9.5, "width": 1.6, "height": 2.4},
		{"wall": "s", "at": -4.0, "width": 2.0, "height": 2.6},
		{"wall": "s", "at": 4.0, "width": 2.0, "height": 2.6},
		{"wall": "n", "at": -5.5, "width": 2.4, "height": 2.4},
		{"wall": "n", "at": 6.5, "width": 1.0, "height": 2.3},
	])
	# The shredding room: industrial shredders, bins and a conveyor. Loud when running.
	Greybox.room(geo, Vector3(-5.5, 0, -29), Vector3(11, 3.6, 8), {"floor": Color(0.3, 0.3, 0.3), "wall": Color(0.5, 0.5, 0.48)}, [
		{"wall": "s", "at": 0.0, "width": 2.4, "height": 2.4},
	])
	Greybox.label(geo, Vector3(-5.5, 2.7, -24.88), "SHREDDING", 44, Color(0.75, 0.2, 0.15), 180)
	# A wide roll-up door for the bins, up while the machines run (its row is unlocked):
	# the Shredder's way out, and the way its noise spills into the corridor.
	room_doors["SHRED ROOM"] = add_door("ARC-SHRED", Vector3(-5.5, 1.2, -25), Vector3(2.4, 2.4, 0.08))
	_reader(Vector3(-4.3, 1.3, -24.88), 180.0)
	for x in [-9.0, -6.5]:
		Greybox.box(geo, Vector3(x, 0.9, -31.5), Vector3(1.6, 1.8, 1.2), Color(0.25, 0.27, 0.3), "Shredder")
		Greybox.panel(geo, Vector3(x, 1.95, -31.5), Vector3(1.0, 0.3, 0.6), Color(0.1, 0.1, 0.1))
	Greybox.box(geo, Vector3(-4.5, 0.4, -29.5), Vector3(5.0, 0.8, 0.9), Color(0.35, 0.35, 0.38), "Conveyor")
	for x in [-2.0, -0.9]:
		Greybox.box(geo, Vector3(x, 0.55, -32.0), Vector3(0.8, 1.1, 0.8), Color(0.15, 0.3, 0.5), "Bin")
	Greybox.box(geo, Vector3(-9.5, 0.6, -27.0), Vector3(1.2, 1.2, 1.2), Color(0.75, 0.72, 0.6), "PaperBale")
	# The microfiche room: readers along the wall and the archive intranet terminal.
	Greybox.room(geo, Vector3(6.5, 0, -28), Vector3(9, 3.2, 6), colors, [
		{"wall": "s", "at": 0.0, "width": 1.0, "height": 2.3},
	])
	Greybox.label(geo, Vector3(6.5, 2.6, -24.88), "MICROFICHE", 36, Color(0.2, 0.2, 0.2), 180)
	var fd := add_door("ARC-FICHE", Vector3(6.5, SIDE_DOOR.y / 2, -25), Vector3(1.0, 2.3, 0.08))
	fd.make_hinged(Vector3(-0.5, 0, 0), 90.0)
	room_doors["MICROFICHE"] = fd
	_reader(Vector3(7.4, 1.3, -24.88), 180.0)
	for x in [3.5, 5.5, 7.5]:
		Greybox.box(geo, Vector3(x, 0.4, -30.3), Vector3(1.4, 0.8, 0.8), Color(0.36, 0.3, 0.25), "FicheDesk")
		Greybox.box(geo, Vector3(x, 1.1, -30.5), Vector3(0.6, 0.6, 0.5), Color(0.75, 0.72, 0.62), "FicheReader")
	Greybox.box(geo, Vector3(9.8, 0.4, -27.5), Vector3(1.4, 0.8, 0.8), Color(0.36, 0.3, 0.25), "FicheDesk")
	fiche = Terminal.spawn(geo, Vector3(9.8, 0.8, -27.5), -90, "ARCHIVE INTRANET", db, terminal_ui)
	fiche.name = "FicheTerminal"
	fiche.boot_lines = ["HALCYON RECORDS  -  ARCHIVE INTRANET  -  FLOOR 18"]
	fiche.queried.connect(_on_query.bind("fiche"))


## Mercer's room, beyond the host room's back wall. Off-grid: a generator and a
## battery bank, a lantern, a cot, his desk. The floppy disk is on the desk; the stair
## key hangs by the door. Nothing in here is on the building's network or its lights table.
func _build_safe_room() -> void:
	var spec: Dictionary = SIDE_ROOMS[data.host]
	var back: Vector3 = spec.back
	var c: Vector3 = spec.center + back * (SIDE_ROOM_SIZE.x / 2 + SAFE_ROOM_SIZE.x / 2)
	var door_wall := "w" if back.x > 0 else "e"
	Greybox.room(geo, c, SAFE_ROOM_SIZE, {"floor": Color(0.22, 0.2, 0.18), "wall": Color(0.42, 0.38, 0.32), "ceiling": Color(0.3, 0.28, 0.26)}, [
		{"wall": door_wall, "at": 1.0, "width": 1.0, "height": 2.2},
	])
	safe_room_box = AABB(c - Vector3(SAFE_ROOM_SIZE.x / 2, 0.5, SAFE_ROOM_SIZE.z / 2), SAFE_ROOM_SIZE + Vector3(0, 1, 0))
	# An ordinary door in the vault's back wall, where the shelving hid it.
	var wall_x: float = spec.center.x + back.x * SIDE_ROOM_SIZE.x / 2
	safe_door = Door.create(self, "MERCER", Vector3(wall_x, 1.1, spec.center.z + 1.0), Vector3(0.08, 2.2, 1.0), Color(0.45, 0.4, 0.34))
	safe_door.make_hinged(Vector3(0, 0, -0.5), 90.0 * back.x)
	safe_door.locked = false
	# Found: the host says so, everyone hears it.
	var found := Trigger.create(self, c + Vector3(0, 1, 0), Vector3(SAFE_ROOM_SIZE.x - 0.6, 2, SAFE_ROOM_SIZE.z - 0.6))
	found.name = "SafeRoomFound"
	found.entered.connect(func(_b): sync.event("_enter_safe_room"), CONNECT_ONE_SHOT)
	# Generator and battery bank along the back wall, the lantern on the desk.
	var far_x: float = c.x + back.x * (SAFE_ROOM_SIZE.x / 2 - 0.6)
	Greybox.box(geo, Vector3(far_x, 0.5, c.z - 2.0), Vector3(1.0, 1.0, 1.2), Color(0.6, 0.25, 0.1), "Generator")
	for i in 3:
		Greybox.box(geo, Vector3(far_x, 0.25, c.z - 0.4 + i * 0.6), Vector3(0.8, 0.5, 0.5), Color(0.1, 0.1, 0.12), "Battery")
	Greybox.box(geo, Vector3(c.x, 0.2, c.z + 2.2), Vector3(1.9, 0.4, 0.8), Color(0.3, 0.32, 0.28), "Cot")
	Greybox.box(geo, Vector3(c.x - back.x * 0.4, 0.38, c.z - 1.0), Vector3(1.6, 0.76, 0.8), Color(0.4, 0.34, 0.28), "MercerDesk")
	var lantern := OmniLight3D.new()
	lantern.position = Vector3(c.x - back.x * 0.4, 1.1, c.z - 1.0)
	lantern.omni_range = 5.5
	lantern.light_energy = 1.2
	lantern.light_color = Color(1.0, 0.85, 0.6)
	geo.add_child(lantern)
	Greybox.panel(geo, lantern.position, Vector3(0.12, 0.2, 0.12), Color(1.0, 0.9, 0.7), 2.0)
	# The floppy, one copy: whoever takes it carries it.
	floppy = ItemDock.make(geo, Vector3(c.x - back.x * 0.9, 0.8, c.z - 1.0), Vector3(0.3, 0.1, 0.3), "Take the floppy disk", "floppy_disk")
	floppy.name = "FloppyDock"
	floppy.add_boxes(1, 0.1, Vector3(0.09, 0.01, 0.09), Color(0.1, 0.1, 0.12))
	floppy.already = "You have the disk."
	floppy.taken.connect(_on_floppy_taken)
	# The key ring on a hook by the door.
	key_dock = ItemDock.make(geo, Vector3(wall_x + back.x * 0.3, 1.5, spec.center.z + 2.0), Vector3(0.2, 0.3, 0.2), "Take the key ring", "stair_key")
	key_dock.name = "KeyHook"
	key_dock.add_boxes(1, 0.1, Vector3(0.03, 0.12, 0.01), Color(0.75, 0.6, 0.2))
	key_dock.already = "You have the key."
	key_dock.taken.connect(_on_key_taken)


func apply_environment(env: Environment) -> void:
	env.ambient_light_energy = 0.06
	env.fog_density = 0.04


func net_setup() -> void:
	shredder.crew = crew
	sync.replicate(shredder, shredder.sync_properties())
	# This machine's player's own sounds (landings, vents, a dropped box); other
	# players' sprints it hears from how fast their bodies move.
	player.noise_made.connect(func(at, loudness): if sync.is_host(): shredder.hear(at, loudness))


func start() -> void:
	if completed.get_connections().is_empty():
		completed.connect(_on_completed)
	stair_in.set_open(true, true)  # wedged open by day staff
	floppy.stock(1)
	key_dock.stock(1)
	hud.todo(TEXT.todo_arrive)


# --- Terminals -------------------------------------------------------------------

func _on_query(_sql: String, result: Dictionary, _ui: TerminalUI, which: String) -> void:
	for p in [slips_puzzle, depts_puzzle, visits_puzzle]:
		if not p.solved and p.matches(db, result):
			sync.event("_on_solved", [p.id, which])


## Every machine: a station's check passed.
func _on_solved(id: String, _which: String) -> void:
	for p in [slips_puzzle, depts_puzzle, visits_puzzle]:
		if p.id == id:
			p.solved = true
	if id == "visits":
		hud.todo(TEXT.todo_room)
		Game.open_case("room", CASES.room, ["access_log"])
		Game.solve_case("room", "The readers logged one room far more than any other that night: %s." % data.host)


# --- The side rooms' shelving ------------------------------------------------------

## Every machine: the crank in `room` was turned. The units roll toward the door and
## the aisle opens along the back wall. Loud: the whole floor hears it.
func _crank(room: String) -> void:
	if cranked.get(room, true):
		return
	cranked[room] = true
	cranks[room].enabled = false
	if not shredder_awake:
		# The pressure peak: the first crank wakes it. Everyone hears the machines stop.
		shredder_awake = true
		hud.notice(TEXT.shredder_wakes, 6.0)
		if sync.is_host():
			shredder.wake()
	var back: Vector3 = SIDE_ROOMS[room].back
	for unit in shelving[room]:
		var tw := create_tween()
		tw.tween_property(unit, "position", unit.position - back * CRANK_TRAVEL, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	noise.emit(to_global(cranks[room].position), CRANK_LOUDNESS)


## Is the aisle along `room`'s back wall open (wide enough to walk)?
func back_aisle_open(room: String) -> bool:
	return cranked.get(room, false)


# --- Mercer's room -------------------------------------------------------------------

func _enter_safe_room() -> void:
	if reached_safe:
		return
	reached_safe = true
	if world and not world.keep_loaded.has(wing_id):
		world.keep_loaded.append(wing_id)  # a hub: later floors come back here
	hud.notice(TEXT.found_room, 6.0)
	hud.todo("")


func _on_floppy_taken(peer_id: int) -> void:
	floppy_taken = true
	floppy.enabled = false  # one disk
	if peer_id == players.id_of(player):
		hud.notice(TEXT.floppy, 6.0)
	# Only whoever picked it up earns Mercer's first secret.
	sync.unlock_for([peer_id], "secret:mercer_floppy_1")


func _on_key_taken(peer_id: int) -> void:
	key_taken = true
	key_dock.enabled = false
	stair_out.locked = false
	if peer_id == players.id_of(player):
		hud.notice(TEXT.key, 5.0)
	hud.todo(TEXT.todo_key)


# --- The way down -------------------------------------------------------------------

## Everyone is on the stairs. Until Level 4 is built, the slice ends here.
func _on_exit() -> void:
	get_node("/root/Net").earn("achievement:floor_18", hud)
	if not player or player.health <= 0.0:
		return
	player.input_locked = true
	await get_tree().create_timer(1.0).timeout
	await Level2FX.end_card(self, TEXT.end_card)
	Game.completed_level = "level_3"
	Game.next_level = ""
	completed.emit()


func _on_completed() -> void:
	await hud.fade(true, 1.2)
	finish_level("field_notes")


func on_player_died() -> void:
	if reached_safe:
		# The safe room is the breather: you come to on Mercer's cot.
		var c := safe_room_box.get_center()
		player.respawn(global_transform * Transform3D(Basis(), Vector3(c.x, 0.1, c.z + 1.0)))
	else:
		player.respawn(spawn_point())
