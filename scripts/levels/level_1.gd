extends LevelBase
## Level 1: the server floor. No threat: the crew's real job, done safely. Rourke
## asks them to find the door controller that keeps faulting (WHERE and AND on
## door_controllers) and reset it at its rack, which puts the floor's doors and
## elevator back in service. The controller's log points at Dr. Vale's lab, and
## Rourke rides up with the crew to see it.

var rourke: Rourke
var terminal: Terminal
var answer := ""
var rack_panels := {}
var panels_locked_until := 0.0
## Rourke has asked the crew to find the fault: the terminal and the racks work.
var asked := false
## Built from this run's zone (Level1Data): see build().
var controller_puzzle: Puzzle
## Optional: which of Server Room B's racks is over the vault's fire interlock limit.
var hot_rack_puzzle: Puzzle
## The controller chain's first step: which zone the stuck doors share (WHERE, =).
var stuck_doors_puzzle := stuck_doors_puzzle_for()
## Optional: every light that's dead or flickering (OR), then reset their circuit.
var dark_room_puzzle := dark_room_puzzle_for()
## Before the reset: how many controllers are faulted floor-wide (COUNT), for the
## sign-off form. The rack panels stay unpowered until it's counted.
var count_puzzle := count_puzzle_for()
## Tempting wrong counts, each with SYSOP's reason: every controller, and every one
## that isn't 'ok' (the offline ones are switched off on purpose).
var count_all := Puzzle.new("count_all", "SELECT COUNT(*) FROM door_controllers", ["count(*)"], false)
var count_not_ok := Puzzle.new("count_not_ok", "SELECT COUNT(*) FROM door_controllers WHERE status != 'ok'", ["count(*)"], false)
## The faulted rows listed, not counted: SYSOP points at COUNT(*).
var count_listed := Puzzle.new("count_listed", "SELECT id FROM door_controllers WHERE status = 'fault'", ["id"], false)
## How many controllers are faulted this run (Level1Data).
var faulted := 0
## The break room's lighting circuit reset, by its door.
var light_panel: Interactable
var lights_fixed := false
## The zone the stuck doors share, and the rest of the floor's zone (Level1Data).
var zone := ""
var other_zone := ""
var hot_rack := ""
## Each door's plate light (red: won't release), by door id.
var door_plates := {}
## The cable vault's back door, from the ops room: sealed by its fire interlock
## while any rack runs over Level1Data.INTERLOCK_C.
var vault_back: Door
var fan_trays := {}
var trays_locked_until := 0.0
## The terminal has found the hot rack: until then its tray's latch stays shut.
var hot_rack_found := false
## The way up to Level 2. Out of service until the controller is reset.
var elevator: Elevator
## Where the crew arrives from the ground floor (in the World).
var arrival_lift: Elevator
## Server Room C stays shut while its lock is on the faulted zone.
var room_c_door: Door
## The spare coil of network cable in the cable vault.
var cable_coil: ItemDock
## The emergency stairs beside the lift up: locked after hours.
var stair_door: Door
## Spare walkie-talkies on the NOC desk, for anyone who left theirs in the lobby.
var spare_walkies: ItemDock
## Who carries cable up to Level 2: peer id -> true, the same on every machine.
var cable_holders := {}
## Host: Easy SQL chapters whose paper has been read: "found" waits until its
## puzzle is ready, "played" has been held (_book_found).
var _books := {}
## The controller case's slot the crew is on: "zone", "controller", "count", or ""
## before Rourke asks and once the count is in (every machine).
var slot := ""
## The right result is on screen (the query matched); the slot waits for the click.
var stuck_listed := false
var controller_listed := false
var counted := false
var hot_listed := false
## The sign-off's count from the stuck doors' zone only (S30), built in build().
var count_zone: Puzzle
## The hot rack's query the wrong way round: the cool ones.
var hot_backwards := Puzzle.new("hot_backwards", "SELECT id FROM racks WHERE temp_c < %d" % Level1Data.INTERLOCK_C, ["id"], false)
var hot_backwards_eq := Puzzle.new("hot_backwards_eq", "SELECT id FROM racks WHERE temp_c <= %d" % Level1Data.INTERLOCK_C, ["id"], false)
## When the last main step or chapter landed (Time ticks, ms; -1 for none). A side
## case's paper read within pace_s of it opens its case when that minute is up (M5).
var _beat_ms := -1
var pace_s := 60.0
var _side_waiting := {}
## Rourke's pivot lines have played (M6), on the walk out through the rear exit.
var _pivot_done := false
## Lift 1's out-of-service sign (S43), taken down once the lift's back in service.
var lift_sign: Document

## What the floor's case is for, the same words on its page, the chip on screen and
## the to-do list once the stuck doors' zone is known.
const OBJ_CONTROLLER := "Find the door controller that keeps faulting, and reset it"
## The case's first step (S6), and the to-do while it's on.
const STEP_ZONE := "Find which zone the stuck doors are in"
const TODO_ZONE := "Find which zone the stuck doors are in, at the terminal"
## The to-do once the controller is found: the sign-off's count comes first.
const COUNT_TODO := "Count the faulted controllers for the reset sign-off, at the terminal"
## The dark break room's case page (optional), opened by facilities' card.
const DARK_CASE := "Why is the break room dark?"
## The hot rack's case page (optional), opened by the fire interlock plate.
const HOT_CASE := "Why won't the cable vault's back door open?"
## Each case's pieces (Game.set_pieces): what the crew finds on this floor to put
## its query together. Drafts for Augustine's word-for-word OK.
const CONTROLLER_QUERY := "SELECT id FROM {table} WHERE zone = '{zone}' AND status = '{status}';"
## The case's query follows its step (S7, S11): the doors first, then the
## controller's, then the count. Pieces found carry over.
const STUCK_QUERY := "SELECT name, zone FROM {doors} WHERE locked = {locked};"
const COUNT_QUERY := "SELECT {count} FROM {table} WHERE status = '{status}';"
const STUCK_PIECES := [
	{"id": "doors", "label": "The table of doors", "value": "doors", "task": "Find the table that lists every door", "where": "The NOC shift log", "seen_in": "doors", "blank": "enter_table_name"},
	{"id": "locked", "label": "What locked reads for a stuck door", "value": "1", "task": "Find the number a door that won't release shows", "where": "The NOC shift log", "blank": "enter_number"},
]
const COUNT_PIECE := {"id": "count", "label": "How to count rows", "value": "COUNT(*)", "task": "Find how to get one number instead of the rows", "where": "WARDEN's printout on the desk"}
const CONTROLLER_STEPS := [
	{"id": "zone", "text": STEP_ZONE},
	{"id": "run", "text": "Run it to find the faulting controller"},
	{"id": "count", "text": "Count the faulted units for the sign-off form"},
	{"id": "reset", "text": "Reset the faulted controller at its rack"},
]
const DARK_PIECES := [
	{"id": "table", "label": "The table", "value": "lights", "task": "Find the table the lights are in", "where": "Someone's grumbling, near the break room", "seen_in": "lights", "blank": "enter_table_name"},
	{"id": "dead", "label": "One status to list", "value": "dead", "task": "Find which lights count as out", "where": "Facilities' card", "blank": "enter_status"},
	{"id": "flickering", "label": "The other status", "value": "flickering", "task": "Find the other status that counts", "where": "Facilities' card", "blank": "enter_other_status"},
]
const DARK_QUERY := "SELECT room, status FROM {table} WHERE status = '{dead}' OR status = '{flickering}';"
const HOT_QUERY := "SELECT id, temp_c FROM {table} WHERE temp_c {more} {limit};"
const HOT_STEPS := [
	{"id": "run", "text": "Run it to find the hot rack"},
	{"id": "tray", "text": "Reseat that rack's fan tray"},
]
const DARK_STEPS := [
	{"id": "run", "text": "Run it to list the lights that are out"},
	{"id": "reset", "text": "Reset the circuit by the break room door"},
]
## Answer slots and the pencil notes under them when another cell is pointed at
## (approvals/puzzle-flow-floor-14.md, S13-S28).
const SLOT_ZONE := "The stuck doors' zone:"
const ZONE_ROW := "That's one of the stuck doors. The blank wants their zone."
const ZONE_OTHER_FLOOR := "That's another floor's door. The blank wants the zone of the three on the shift log."
const ZONE_OTHER := "Not that one: the blank wants the zone of the three doors on the shift log."
const SLOT_CONTROLLER := "The controller that keeps faulting:"
const CTRL_ROW := "That's the right row. The blank wants its id."
const CTRL_OFFLINE := "That one's 'offline': switched off on purpose. The blank wants the one that's 'fault'."
const CTRL_ELSEWHERE := "That one's faulted, but in another zone. The blank wants the stuck doors' zone."
const CTRL_OTHER := "Not that one: the blank wants the controller in the stuck doors' zone with status 'fault'."
const SLOT_COUNT := "Units faulted:"
const COUNT_ONE := "That's one unit. The form wants how many there are."
const COUNT_WRONG := "Not that number: the form wants every unit with status 'fault', whichever door it runs."
const SLOT_HOT := "The rack over the limit:"
const HOT_EDGE := "That one reads exactly 40: the limit, not over it."
const HOT_TEMP := "That's its temperature. The blank wants its id."
const HOT_OTHER := "Not that one: the blank wants the rack over the limit."
## No line of a paper answers these slots: only a pointed-at cell does.
const NO_LINE := ["\u0001"]
## .hint's first tier: the spot for the first piece the crew still lacks (S38-S42).
const SPOT_LOG := "Night shift logs every alarm. Their shift log is on a desk in the NOC."
const SPOT_CARD := "There's a reference card on the door controllers beside this keyboard."
const SPOT_REMINDERS := "Someone left handwritten reminders beside this keyboard about what the statuses mean."
const SPOT_PRINTOUT := "WARDEN's diagnostics printout on this desk shows how to count rows."
const SPOT_RACK_CARD := "Server Room B has a monitoring card just inside its door."
## The crew's commentary: the case's first step has the zone's lines, the rest the controller's.
const COMMENTARY_IDS := {"controller": "stuck_doors"}
const ROURKE_IN_LIFT := Vector3(-0.75, 0, 1.6)  # across the car from the buttons
const RESPAWN := Vector3(0, 0.1, 11.0)
## Seconds after Rourke's ask before he tells a slow crew to take their time.
const WAITING_AFTER := 60.0


func build() -> void:
	var data := Level1Data.build(Game.run_seed)
	answer = data.answer
	zone = data.zone
	other_zone = data.other_zone
	hot_rack = data.hot_rack
	faulted = data.faulted
	load_level_seed(data.sql)
	controller_puzzle = controller_puzzle_for(zone)
	hot_rack_puzzle = hot_rack_puzzle_for()
	count_zone = Puzzle.new("count_zone", "SELECT COUNT(*) FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % zone, ["count(*)"], false)
	stuck_doors_puzzle.spots = [{"id": "shift_log", "text": SPOT_LOG, "piece": "locked"}]
	controller_puzzle.spots = [{"id": "controllers_card", "text": SPOT_CARD, "piece": "table"}, {"id": "reminders", "text": SPOT_REMINDERS, "piece": "status"}]
	count_puzzle.spots = [{"id": "warden_printout", "text": SPOT_PRINTOUT, "piece": "count"}]
	hot_rack_puzzle.case_id = "hot_rack"
	hot_rack_puzzle.spots = [{"id": "rack_card", "text": SPOT_RACK_CARD, "piece": "table"}]
	var game := get_node("/root/Game")
	game.set_pieces("hot_rack", hot_pieces(), HOT_QUERY, HOT_STEPS, true)
	game.set_pieces("dark_room", DARK_PIECES, DARK_QUERY, DARK_STEPS, true)
	# The hot rack's slot is set before its case opens: the interlock plate opens it.
	game.set_blank("hot_rack", SLOT_HOT, NO_LINE, hot_rack, {"column": "id", "values": [hot_rack], "rows": [{"id": hot_rack}]})
	game.answer_found.connect(_on_answer_found)
	game.cell_missed.connect(_on_cell_missed)

	var floor_c := Color(0.32, 0.33, 0.35)
	var wall_c := Color(0.5, 0.52, 0.55)
	var office := Color(0.95, 0.93, 0.85)
	var c := {"floor": floor_c, "wall": wall_c}
	var machine := {"floor": floor_c, "wall": wall_c, "ceiling": Color(0.4, 0.4, 0.42)}
	var door := {"width": 1.4, "height": 2.2}
	# Server Room A, the middle of the floor: x -7..7, z -9..9.
	Greybox.room(geo, Vector3.ZERO, Vector3(14, 3.6, 18), machine, [
		{"wall": "s", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4},
	])
	# South corridor: x -22..22, z 9..13. The ground floor's elevator arrives here.
	var south_gaps := [
		{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4},  # Server Room A
		_gap("n", -14.5, door), _gap("n", 14.5, door),  # NOC, Server Room B
	]
	if world:
		south_gaps.append({"wall": "s", "at": 0.0, "width": Elevator.DOORWAY, "height": Elevator.DOOR_H})
	Greybox.room(geo, Vector3(0, 0, 11), Vector3(44, 3, 4), c, south_gaps)
	if world:
		# The ground floor's elevator links to this car and opens it at the end of the ride.
		arrival_lift = Elevator.create(self, geo, Vector3(0, 0, 13), 0, "14", ["22", "14", "G", "B1"], "14")
		arrival_lift.name = "ArrivalElevator"
		arrival_lift.button.enabled = false
	# North corridor: x -22..22, z -13..-9. The elevator up, and Server Room C.
	Greybox.room(geo, Vector3(0, 0, -11), Vector3(44, 3, 4), c, [
		{"wall": "s", "at": 0.0, "width": 1.8, "height": 2.4},  # Server Room A's rear door
		_gap("s", -12.0, door), _gap("s", 12.0, door),  # cable vault, break room
		_gap("n", -12.0, door),  # Server Room C
		{"wall": "n", "at": 0.0, "width": Elevator.DOORWAY, "height": Elevator.DOOR_H},
		{"wall": "n", "at": 5.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},  # the stairs
	])
	stair_door = Stairwell.build(self, geo, Vector3(5, 0, -13), 0.0, "14")
	elevator = Elevator.create(self, geo, Vector3(0, 0, -13), 180, "14", ["22", "14", "G", "B1"], "22")
	elevator.button.enabled = false
	for x in [-16.0, -6.0, 6.0, 16.0]:
		add_light("corridor", Vector3(x, 3, 11), 7.0, 1.0, office)
		var l := add_light("corridor", Vector3(x, 3, -11), 7.0, 0.9, office)
		if x == 6.0:
			FlickerLight.attach(l, 0.3)
	add_door("SRA-ENTRY", Vector3(0, 1.2, 9), Vector3(1.8, 2.4, 0.15)).slide_axis = Vector3.UP
	add_door("SRA-EXIT", Vector3(0, 1.2, -9), Vector3(1.8, 2.4, 0.15))
	Greybox.label(geo, Vector3(0, 2.75, 9.12), "SERVER ROOM A", 48, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(0, 2.75, -9.12), "SERVER ROOM A", 48, Color(0.15, 0.15, 0.2), 180)
	_build_floor(c, machine, office)
	_build_door_plates()

	# Server racks: 4 rows x 2 columns, labeled DC-1 .. DC-8 on the center-aisle end.
	var n := 1
	for z in [-6.0, -3.0, 0.0, 3.0]:
		for side in [-1, 1]:
			var cx: float = side * 3.8
			Greybox.box(geo, Vector3(cx, 1.05, z), Vector3(4.0, 2.1, 0.9), Color(0.12, 0.12, 0.14), "Rack%d" % n)
			for k in 6:
				var led_color := Color(0.2, 1.0, 0.3) if randf() > 0.25 else Color(1.0, 0.6, 0.1)
				Greybox.panel(geo, Vector3(cx + randf_range(-1.7, 1.7), randf_range(0.3, 1.9), z + 0.46), Vector3(0.04, 0.04, 0.01), led_color, 3.0)
			var end_x: float = side * 1.78
			var face := 90.0 if side == -1 else -90.0
			var id := "DC-%d" % n
			Greybox.label(geo, Vector3(end_x + side * -0.02, 1.75, z), id, 72, Color(1, 1, 1), face)
			var p := Interactable.create(geo, Vector3(end_x + side * -0.04, 1.2, z), Vector3(0.08, 0.35, 0.45), "Reset controller " + id, Color(0.6, 0.55, 0.2))
			p.used.connect(_on_panel.bind(id))
			rack_panels[id] = p
			n += 1

	# Terminal desk by the entrance, facing into the room. Rourke's maintenance
	# session opens once he has asked the crew to look.
	Greybox.box(geo, Vector3(-4.5, 0.45, 8.4), Vector3(2.2, 0.9, 0.8), Color(0.4, 0.38, 0.35), "TermDesk")
	terminal = Terminal.spawn(geo, Vector3(-4.5, 0.9, 8.4), 180, "SERVER ROOM A", db, terminal_ui)
	stuck_doors_puzzle.case_id = "controller"
	# The shift log names the stuck doors and the Cold Lab; the zone is the answer.
	stuck_doors_puzzle.givens = ["Server Room C", "Cold Lab"]
	# The dark break room is the case itself; the north corridor is what the query finds.
	dark_room_puzzle.givens = ["Break room"]
	count_puzzle.case_id = "controller"
	terminal.puzzles = [stuck_doors_puzzle, controller_puzzle, count_puzzle, hot_rack_puzzle, dark_room_puzzle]
	terminal.boot_lines = _self_test_lines()
	terminal.locked = true
	terminal.locked_message = "MAINTENANCE SESSION ROURKE_D: WAITING FOR ESCORT."
	terminal.queried.connect(_on_query)
	StickyNote.on_monitor(terminal, "where_and")
	# Lift 1's doors, on the way the crew will need: the same fault as the self-test's (S43).
	lift_sign = Document.place(geo, Vector3(0, 1.45, -13.06), 0.0, "OUT OF SERVICE", [
		"OUT OF SERVICE",
		"Controller fault.",
		"- Facilities",
	], false, "paper", Vector2(0.28, 0.2))
	# The room's laminated reference card, and Mercer's note on what the statuses mean.
	var card := Document.place(geo, Vector3(-5.25, 0.902, 8.35), 175.0, "SERVER ROOM A - DOOR CONTROLLERS", [
		"Each rack drives one door lock. Rack ids DC-1 to DC-8 are on the aisle end.",
		{"before": "Every controller is listed in the table ", "filled": "door_controllers", "after": "."},
		"Columns: id, zone, status, location, last_reset, note",
		"Faulted lock? Reset it at its own rack. Never reset a healthy one.",
	], true, "laminated", Vector2(0.21, 0.15))
	card.pieces = [{"case": "controller", "piece": "table", "text": "door_controllers", "kind": "table"}]
	card.spot = "controllers_card"
	card.clues = [
		{"case": "controller", "text": "Every controller is listed in the table door_controllers. Columns: id, zone, status, location, last_reset, note."},
		{"case": "controller", "text": "Reset a faulted lock at its own rack. Never reset a healthy one."},
	]
	var reminders := Document.place(geo, Vector3(-3.55, 0.902, 8.3), -170.0, "Reminders", [
		{"text": "status 'fault' = the lock relay is stuck. Needs a hand reset at the rack.", "hand": true, "author": "mercer"},
		{"text": "status 'offline' = someone switched it off on purpose. Leave it alone.", "hand": true, "author": "mercer"},
		{"text": "Zone first, then status. Plenty of faults in this building aren't yours.", "hand": true, "author": "mercer"},
		{"text": "- H.M.", "hand": true, "author": "mercer"},
	], true, "note", Vector2(0.1, 0.14))
	reminders.pieces = [{"case": "controller", "piece": "status", "text": "fault", "kind": "value"}]
	reminders.spot = "reminders"
	reminders.clues = [
		{"case": "controller", "text": "status 'fault' means the lock relay is stuck. 'offline' means switched off on purpose: leave it alone."},
		{"case": "controller", "text": "Zone first, then status. Plenty of faults in this building aren't yours. - H.M."},
	]
	# COUNT, seen first on another table: WARDEN's diagnostics left on the desk. Its
	# numbers come from the racks table, so the paper never goes out of date.
	var racks_all: int = db.run_silent("SELECT COUNT(*) AS n FROM racks")[0]["n"]
	var racks_c: int = db.run_silent("SELECT COUNT(*) AS n FROM racks WHERE room = 'Server Room C'")[0]["n"]
	var printout := Document.place(geo, Vector3(-3.55, 0.902, 8.62), 174.0, "WARDEN DIAGNOSTICS", [
		"WARDEN DIAGNOSTICS - FLOOR 14 - 23:40",
		"> SELECT COUNT(*) FROM racks;",
		"  COUNT(*): %d" % racks_all,
		"> SELECT COUNT(*) FROM racks WHERE room = 'Server Room C';",
		"  COUNT(*): %d" % racks_c,
		{"text": "How many? COUNT(*). Don't count rows by hand.", "hand": true},
	], true, "paper", Vector2(0.12, 0.16))
	printout.clues = [
		{"case": "controller", "text": "COUNT(*) counts the rows instead of listing them: SELECT COUNT(*) FROM racks WHERE room = 'Server Room C'; gives %d." % racks_c},
	]
	printout.pieces = [{"case": "controller", "piece": "count", "text": "COUNT(*)", "kind": "keyword"}]
	printout.spot = "warden_printout"
	# The "How many?" chapter waits for the counting step (M3).
	printout.read_by.connect(func(_p): _book_found("easy_sql_count"))
	# The reset's paperwork: the count it wants comes from the terminal.
	var signoff := Document.place(geo, Vector3(-3.9, 0.902, 8.6), -176.0, "CONTROLLER RESET - SIGN-OFF", [
		"CONTROLLER RESET - SIGN-OFF",
		"Floor 14. No manual reset without this form.",
		"Units faulted (all doors this bank runs): ______",
		"Count every controller with status 'fault', whichever door it runs. Units marked 'offline' are switched off on purpose: they don't count.",
		"The rack reset circuits stay unpowered until the count is logged at the terminal.",
		"Badge: ______  (facilities)",
	], true, "paper", Vector2(0.15, 0.2))
	signoff.clues = [
		{"case": "controller", "text": "The reset sign-off wants the number of controllers with status 'fault', whichever door they run. 'offline' units don't count."},
		{"case": "controller", "text": "The rack reset circuits stay unpowered until the count is logged at the terminal."},
	]
	# Reading it brings back the book's COUNT chapter once the controller's found (M3).
	signoff.read_by.connect(func(_p): _book_found("easy_sql_count"))

	for p in [Vector3(0, 3.6, -7), Vector3(0, 3.6, -1.5), Vector3(0, 3.6, 4.5), Vector3(-6, 3.6, 8), Vector3(6, 3.6, -8)]:
		add_light("room", p, 9.0, 1.2)

	rourke = Rourke.new()
	rourke.name = "Rourke"
	rourke.position = Vector3(-2.4, 0, 6.4)
	# In the World the ground floor's Rourke rides up with the crew and this one takes
	# his place (start()); until then he mustn't be seen standing in the room.
	rourke.visible = world == null
	add_child(rourke)
	spawn = Transform3D(Basis(), RESPAWN)
	DressLevel1.apply(self)  # furniture and materials (Graphics thread)
	# The crew thinking out loud: floor 14's 13 approved lines (approvals/puzzle-flow-floor-14.md, part 3).
	commentary_ids = COMMENTARY_IDS.duplicate()
	start_commentary()


## A plate beside each of the floor's doors with its zone, and a light that's red
## while the lock won't release: the walking route to the stuck doors' zone.
## [door id, plate position (on the corridor side), facing]
const PLATES := [
	["SRA-ENTRY", Vector3(1.3, 1.6, 9.11), 0.0],
	["SRA-EXIT", Vector3(-1.3, 1.6, -9.11), 180.0],
	["SRC", Vector3(-10.95, 1.6, -12.89), 0.0],
	["LIFT-1", Vector3(-1.75, 1.6, -12.89), 0.0],
	["NOC", Vector3(-13.45, 1.6, 9.11), 0.0],
	["CABLE-VAULT", Vector3(-10.95, 1.6, -9.11), 180.0],
	["BREAK", Vector3(13.05, 1.6, -9.11), 180.0],
	["SRB", Vector3(15.55, 1.6, 9.11), 0.0],
]


func _build_door_plates() -> void:
	for p in PLATES:
		var row: Array = db.run_silent("SELECT zone, locked FROM doors WHERE id = '%s'" % p[0])
		if row.is_empty():
			continue
		var plate := Node3D.new()
		plate.name = "Plate_" + p[0]
		plate.position = p[1]
		plate.rotation_degrees.y = p[2]
		geo.add_child(plate)
		Greybox.panel(plate, Vector3(0, 0, -0.005), Vector3(0.2, 0.16, 0.01), Color(0.78, 0.76, 0.7))
		# The light says a door is stuck; only the doors table says its zone, so
		# walking the floor can't stand in for the query.
		Greybox.label(plate, Vector3(0, 0.025, 0.002), p[0], 30, Color(0.12, 0.12, 0.15))
		var lamp := Greybox.panel(plate, Vector3(0, -0.045, 0.002), Vector3(0.05, 0.025, 0.01), Color.WHITE, 3.0)
		lamp.name = "Lamp"
		door_plates[p[0]] = lamp
		_light_plate(p[0], int(row[0]["locked"]) == 1)
		if int(row[0]["locked"]) == 1:
			ClueSpot.watch(plate, Vector3.ZERO, "controller", "%s door: red light (stuck)." % p[0], "Door plate")


func _rack_card(pos: Vector3, facing: float, flat: bool) -> void:
	var card := Document.place(geo, pos, facing, "SERVER ROOM B - RACK MONITORING", [
		"SERVER ROOM B - RACK MONITORING",
		{"before": "Rack temperatures are logged in the table ", "filled": "racks", "after": "."},
		"Columns: id, room, temp_c, load_pct, note",
		"ALERT if temp_c > %d" % Level1Data.INTERLOCK_C,
		"Running hot? Reseat that rack's fan tray.",
		{"text": "40 on the dot is fine. It's OVER 40 that trips it.", "hand": true},
	], flat, "laminated", Vector2(0.3, 0.21) if not flat else Vector2(0.21, 0.15))
	card.spot = "rack_card"
	card.clues = [
		{"case": "hot_rack", "text": "Rack temperatures are in the table racks. Columns: id, room, temp_c, load_pct, note."},
		{"case": "hot_rack", "text": "ALERT if temp_c > %d. Running hot? Reseat that rack's fan tray." % Level1Data.INTERLOCK_C},
	]
	card.pieces = [{"case": "hot_rack", "piece": "table", "text": "racks", "kind": "table"}, {"case": "hot_rack", "piece": "more", "text": ">", "kind": "keyword"}]
	card.read_by.connect(func(_p): _book_found("easy_sql_7"))  # More than, less than


func _facilities_card(pos: Vector3, facing: float, flat: bool) -> void:
	var card := Document.place(geo, pos, facing, "FACILITIES - LIGHTING CIRCUITS", [
		"FACILITIES - LIGHTING CIRCUITS",
		{"before": "Before a reset, pull every light that's 'dead' OR 'flickering' from the table ", "filled": "lights", "after": "."},
		"Columns: id, room, floor, is_on, status",
		"One reset clears the lot.",
		"Lights marked 'off' are off on purpose. Leave them.",
	], flat, "laminated", Vector2(0.3, 0.21) if not flat else Vector2(0.21, 0.15))
	card.pieces = [{"case": "dark_room", "piece": "table", "text": "lights", "kind": "table"}, {"case": "dark_room", "piece": "dead", "text": "dead", "kind": "value"},
		{"case": "dark_room", "piece": "flickering", "text": "flickering", "kind": "value"}]
	card.read_by.connect(func(_p):
		_book_found("easy_sql_8")  # Either one will do
		_side_case_read("dark_room"))
	card.clues = [
		{"case": "dark_room", "text": "List every light that's 'dead' OR 'flickering' in the lights table (columns: id, room, floor, is_on, status), then reset the circuit by the break room door."},
		{"case": "dark_room", "text": "Lights marked 'off' are off on purpose. Leave them."},
	]


func _light_plate(id: String, stuck: bool) -> void:
	if door_plates.has(id):
		(door_plates[id] as MeshInstance3D).material_override = Greybox.mat(Color(1.0, 0.15, 0.1) if stuck else Color(0.2, 1.0, 0.3), 3.0)


## What's printed on a door's plate ("" if it has none).
func plate_text(id: String) -> String:
	var plate := geo.get_node_or_null("Plate_" + id)
	if plate == null:
		return ""
	for c in plate.get_children():
		if c is Label3D:
			return (c as Label3D).text
	return ""


func _on_noc_entered() -> void:
	hud.line("l1_noc_2")


## The controller case's pieces for a run whose stuck doors are in zone `z`.
static func controller_pieces(z: String) -> Array:
	return [
		{"id": "table", "label": "The table", "value": "door_controllers", "task": "Find the table of door controllers", "where": "A card on the terminal desk", "seen_in": "door_controllers", "blank": "enter_table_name"},
		{"id": "zone", "label": "The stuck doors' zone", "value": z, "task": "Find the zone the stuck doors share", "where": "Ask the doors table which doors won't release", "blank": "enter_zone"},
		{"id": "status", "label": "What a stuck lock reads", "value": "fault", "task": "Find the status a stuck lock shows", "where": "Someone's handwritten reminders, by the terminal", "blank": "enter_status"},
	]


## The hot rack's pieces: the limit is the interlock's.
static func hot_pieces() -> Array:
	return [
		{"id": "table", "label": "The table", "value": "racks", "task": "Find where rack temperatures are logged", "where": "Server Room B's monitoring card", "seen_in": "racks", "blank": "enter_table_name"},
		{"id": "more", "label": "More than", "value": ">", "task": "Find how to keep only the hot ones", "where": "Also on the monitoring card"},
		{"id": "limit", "label": "The limit", "value": str(Level1Data.INTERLOCK_C), "task": "Find how hot is too hot", "where": "The sealed door itself", "blank": "enter_limit"},
	]


## The controller puzzle for a run whose stuck doors are in `z`. Hints follow the
## ladder: the query's shape with enter_zone for the zone, then how to find it, then exact.
static func controller_puzzle_for(z: String) -> Puzzle:
	return Puzzle.new("controller",
		"SELECT id FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % z, ["id"], false, [
		"The shape of it:\n" +
		"    [color=#ffffff]SELECT id FROM door_controllers WHERE zone = 'enter_zone' AND status = 'fault';[/color]\n" +
		"  SELECT id                 just the controller's id\n" +
		"  FROM door_controllers     from the table of door controllers\n" +
		"  WHERE zone = 'enter_zone' keep only the rows in that zone\n" +
		"  AND status = 'fault'      ...that are ALSO faulted. Both must be true.\n" +
		"Replace enter_zone with the zone the stuck doors share.",
		"Replace enter_zone with the zone your doors query showed for the stuck doors. " +
		"No result yet? Run the doors query first: .hint walks you through it.",
		"Type this exactly and press Enter:\n" +
		"    [color=#ffffff]SELECT id FROM door_controllers WHERE zone = '%s' AND status = 'fault';[/color]\n" % z +
		"Then point at its id and add it to your notebook. Next, count the faulted controllers for the sign-off form on the desk, and press E on that rack's panel in Server Room A: its id is on the end facing the center aisle.",
	])


## The first step: the stuck doors, and the zone they share. Hints follow the ladder.
static func stuck_doors_puzzle_for() -> Puzzle:
	return Puzzle.new("stuck_doors", "SELECT name, zone FROM doors WHERE locked = 1", ["name", "zone"], false, [
		"The shape of it:\n" +
		"    [color=#ffffff]SELECT name, zone FROM doors WHERE locked = enter_number;[/color]\n" +
		"  SELECT name, zone           each door's name and zone\n" +
		"  FROM doors                  from the table of doors\n" +
		"  WHERE locked = enter_number keep only the rows where locked is that number\n" +
		"Replace enter_number with the number the doors table uses for a door that won't release. The NOC shift log says which.",
		"The NOC shift log says what locked holds for a door that won't release. Numbers go in without quotes. " +
		"Then find the shift log's three doors in the result: they share one zone.",
		"Type this exactly and press Enter:\n" +
		"    [color=#ffffff]SELECT name, zone FROM doors WHERE locked = 1;[/color]\n" +
		"The shift log's three doors share one zone. Point at it and add it to your notebook.",
	])


## Optional: every light that's out, dead or flickering, for facilities' circuit reset.
static func dark_room_puzzle_for() -> Puzzle:
	return Puzzle.new("dark_room",
		"SELECT room, status FROM lights WHERE status = 'dead' OR status = 'flickering'", ["room", "status"], false, [
		"The shape of it:\n" +
		"    [color=#ffffff]SELECT room, status FROM lights WHERE status = 'enter_status' OR status = 'enter_other_status';[/color]\n" +
		"  SELECT room, status               each light's room and status\n" +
		"  FROM lights                       from the lights table\n" +
		"  WHERE status = 'enter_status'     keep the rows with this status\n" +
		"  OR status = 'enter_other_status'  ...or with this one. Either will do.\n" +
		"Replace enter_status and enter_other_status with the two statuses on facilities' card by the break room door.",
		"Facilities' card in the break room names the two statuses to list. Words go in 'single quotes'. " +
		"With OR, a row stays if either condition is true.",
		"Type this exactly and press Enter:\n" +
		"    [color=#ffffff]SELECT room, status FROM lights WHERE status = 'dead' OR status = 'flickering';[/color]\n" +
		"Then reset the lighting circuit by the break room door.",
	])


## Before the reset: how many controllers are faulted, floor-wide. COUNT(id) and
## AS n give the same value, so they pass too.
static func count_puzzle_for() -> Puzzle:
	return Puzzle.new("faulted_count",
		"SELECT COUNT(*) FROM door_controllers WHERE status = 'fault'", ["count(*)"], false, [
		"The shape of it:\n" +
		"    [color=#ffffff]SELECT COUNT(*) FROM enter_table_name WHERE status = 'fault';[/color]\n" +
		"  SELECT COUNT(*)         how many rows, not the rows themselves\n" +
		"  FROM enter_table_name   from the table that lists the controllers\n" +
		"  WHERE status = 'fault'  count only the faulted ones\n" +
		"Replace enter_table_name with the table you found the faulted controller in.",
		"The DOOR CONTROLLERS card by the terminal names the table. COUNT(*) counts rows, like WARDEN's printout on the desk. The sign-off form says 'offline' units don't count.",
		"Type this exactly and press Enter:\n" +
		"    [color=#ffffff]SELECT COUNT(*) FROM door_controllers WHERE status = 'fault';[/color]\n" +
		"Then point at the number and add it to your notebook, and reset the faulted controller at its rack.",
	])


## Optional: Server Room B's rack over the vault's fire interlock limit.
static func hot_rack_puzzle_for() -> Puzzle:
	return Puzzle.new("hot_rack",
		"SELECT id FROM racks WHERE temp_c > %d" % Level1Data.INTERLOCK_C, ["id"], false, [
		"The shape of it:\n" +
		"    [color=#ffffff]SELECT id, temp_c FROM racks WHERE temp_c > enter_limit;[/color]\n" +
		"  SELECT id, temp_c            each rack's id and temperature\n" +
		"  FROM racks                   from the rack table\n" +
		"  WHERE temp_c > enter_limit   only rows where temp_c is more than the limit\n" +
		"Replace enter_limit with the limit on the cable vault's back door (a number: no quotes).",
		"The fire interlock plate on the cable vault's back door (in the NOC) gives the limit, in °C.",
		"Type this exactly and press Enter:\n" +
		"    [color=#ffffff]SELECT id, temp_c FROM racks WHERE temp_c > %d;[/color]\n" % Level1Data.INTERLOCK_C +
		"Then point at the rack's id and add it to your notebook, and reseat its fan tray in Server Room B.",
	])


func _gap(wall: String, at: float, size: Dictionary) -> Dictionary:
	return {"wall": wall, "at": at, "width": size.width, "height": size.height}


## The rest of the floor, a loop around Server Room A: the network operations room
## and the cable vault to the west, Server Room B and the break room to the east,
## and Server Room C behind a stuck lock off the north corridor.
func _build_floor(c: Dictionary, machine: Dictionary, office: Color) -> void:
	var door := {"width": 1.4, "height": 2.2}
	var sign_c := Color(0.15, 0.15, 0.2)
	var desk_c := Color(0.42, 0.4, 0.37)
	var rack_c := Color(0.12, 0.12, 0.14)

	# Network operations room (NOC): x -22..-8, z -3..9. Desks facing a wall of status screens.
	Greybox.room(geo, Vector3(-15, 0, 3), Vector3(14, 3, 12), c, [_gap("s", 0.5, door), _gap("n", 3.0, door)])
	add_door("NOC", Vector3(-14.5, 1.1, 9.0), Vector3(1.35, 2.2, 0.08)).make_hinged(Vector3(-0.675, 0, 0), 90.0)
	Greybox.label(geo, Vector3(-14.5, 2.45, 9.12), "NETWORK OPERATIONS (NOC)", 36, sign_c)
	Greybox.box(geo, Vector3(-18.5, 1.6, -2.85), Vector3(6.6, 2.0, 0.1), Color(0.08, 0.09, 0.1), "StatusWall")
	for i in 3:
		Greybox.panel(geo, Vector3(-20.6 + i * 2.1, 1.7, -2.78), Vector3(1.7, 1.0, 0.02), Color(0.15, 0.45, 0.6), 1.5)
	for row in [1.0, 4.5]:
		Greybox.box(geo, Vector3(-15, 0.38, row), Vector3(8, 0.76, 1.0), desk_c, "NocDesk")
		for x in [-18.0, -15.0, -12.0]:
			Greybox.panel(geo, Vector3(x, 1.0, row - 0.3), Vector3(0.6, 0.4, 0.04), Color(0.2, 0.7, 0.4), 1.2)
	var shift_log := Document.place(geo, Vector3(-15, 0.762, 4.6), 180.0, "NOC SHIFT LOG", [
		"22:40  Alarms: doors on this floor won't release. Server Room A rear exit, Server Room C, Lift 1.",
		"22:41  Facilities (Rourke) informed. Contractor called out.",
		"22:44  doors table: all three show locked = 1.",
		"22:55  Records Archive and Cold Lab faults: not ours, tickets open.",
		{"text": "Contractor: use the terminal in Server Room A.", "hand": true},
	], true, "paper")
	shift_log.clues = [
		{"case": "controller", "text": "The stuck doors on this floor: Server Room A's rear exit, Server Room C, Lift 1."},
		{"case": "controller", "text": "The doors table marks a stuck door as locked = 1."},
		{"case": "controller", "text": "The Records Archive and Cold Lab faults aren't this floor's."},
	]
	shift_log.pieces = [{"case": "controller", "piece": "doors", "text": "doors table", "kind": "table"},
		{"case": "controller", "piece": "locked", "text": "locked = 1", "kind": "value"}]
	shift_log.spot = "shift_log"
	shift_log.read_by.connect(func(_p): _book_found("easy_sql_5"))  # Keeping only some rows: it waits for Rourke (M1)
	# A charger of spare walkie-talkies on the front desk.
	Greybox.box(geo, Vector3(-13.5, 0.78, 1.2), Vector3(0.9, 0.04, 0.26), Color(0.12, 0.12, 0.13), "ChargingDock")
	spare_walkies = ItemDock.walkies(geo, Vector3(-13.5, 0.8, 1.2))
	spare_walkies.prompt = "Take a spare walkie-talkie"
	spare_walkies.stock(6)
	for x in [-18.0, -12.0]:
		add_light("noc", Vector3(x, 3, 3), 7.0, 1.0, office)
	var in_noc := Trigger.create(self, Vector3(-15, 1, 3), Vector3(13.6, 2, 11.6))
	in_noc.entered.connect(func(_b): sync.event("_on_noc_entered"), CONNECT_ONE_SHOT)

	# Cable vault: x -22..-8, z -9..-3. Shelves of cable, patch panels, a spare coil.
	Greybox.room(geo, Vector3(-15, 0, -6), Vector3(14, 3, 6), c, [_gap("s", 3.0, door), _gap("n", 3.0, door)])
	add_door("CABLE-VAULT", Vector3(-12.0, 1.1, -9.0), Vector3(1.35, 2.2, 0.08)).make_hinged(Vector3(-0.675, 0, 0), -90.0)
	Greybox.label(geo, Vector3(-12.0, 2.45, -9.12), "CABLE VAULT", 36, sign_c, 180)
	for x in [-20.5, -17.5]:
		Greybox.box(geo, Vector3(x, 1.0, -8.4), Vector3(2.4, 2.0, 0.6), Color(0.35, 0.36, 0.38), "CableShelf")
	Greybox.box(geo, Vector3(-21.6, 1.0, -5.5), Vector3(0.6, 2.0, 3.0), Color(0.35, 0.36, 0.38), "CableShelf")
	Greybox.box(geo, Vector3(-18.5, 0.4, -5.0), Vector3(2.0, 0.8, 1.0), Color(0.3, 0.28, 0.25), "Spool")
	# Spare coils on the shelf, one each for whoever wants one.
	cable_coil = ItemDock.make(geo, Vector3(-17.5, 1.25, -8.3), Vector3(2.3, 0.3, 0.5), "Take a coil of network cable", "cable")
	cable_coil.already = "You've already got a coil of cable."
	cable_coil.add_boxes(6, 0.38, Vector3(0.32, 0.28, 0.4), Color(0.15, 0.3, 0.75), -0.15)
	cable_coil.taken.connect(_on_cable_taken)
	add_light("vault", Vector3(-15, 3, -6), 6.0, 0.7, office)
	# Its back door, into the ops room, is on a fire interlock rather than WARDEN:
	# a room full of cable stays sealed while any rack on the floor runs hot.
	vault_back = add_door("VAULT-BACK", Vector3(-12.0, 1.1, -3.0), Vector3(1.35, 2.2, 0.08)).make_hinged(Vector3(-0.675, 0, 0), 90.0)
	vault_back.locked = true
	var interlock := Document.place(geo, Vector3(-10.85, 1.5, -2.89), 180.0, "Fire interlock", [
		"FIRE INTERLOCK",
		"This door stays sealed while any rack on this floor reads over %d°C." % Level1Data.INTERLOCK_C,
	], false, "laminated", Vector2(0.36, 0.24))
	interlock.clues = [
		{"case": "hot_rack",
			"text": "It stays sealed while any rack on this floor reads over %d°C." % Level1Data.INTERLOCK_C},
	]
	interlock.pieces = [{"case": "hot_rack", "piece": "limit", "text": str(Level1Data.INTERLOCK_C), "kind": "value"}, {"case": "hot_rack", "piece": "more", "text": "over", "kind": "keyword"}]  # "over" it
	interlock.read_by.connect(func(_p):
		_book_found("easy_sql_7")
		_side_case_read("hot_rack"))

	# Server Room B: x 8..22, z -3..9. Racks on another zone; nothing to fix here.
	Greybox.room(geo, Vector3(15, 0, 3), Vector3(14, 3.6, 12), machine, [_gap("s", -0.5, door), _gap("n", -3.0, door)])
	add_door("SRB", Vector3(14.5, 1.1, 9.0), Vector3(1.35, 2.2, 0.08)).make_hinged(Vector3(-0.675, 0, 0), 90.0)
	Greybox.label(geo, Vector3(14.5, 2.45, 9.12), "SERVER ROOM B", 36, sign_c)
	# RB-1 .. RB-6, each with a fan tray at the bottom of its front: one runs hot
	# (racks.temp_c), and reseating its tray lets the cable vault's interlock go.
	var rb := 1
	for z in [-1.0, 2.0, 5.0]:
		for x in [11.0, 19.0]:
			var id := "RB-%d" % rb
			Greybox.box(geo, Vector3(x, 1.05, z), Vector3(4.0, 2.1, 0.9), rack_c, "RackB")
			for k in 4:
				var led := Color(1.0, 0.45, 0.1) if id == hot_rack and k < 2 else Color(0.2, 1.0, 0.3)
				Greybox.panel(geo, Vector3(x + randf_range(-1.7, 1.7), randf_range(0.6, 1.9), z + 0.46), Vector3(0.04, 0.04, 0.01), led, 3.0)
			Greybox.label(geo, Vector3(x, 1.85, z + 0.47), id, 56, Color(1, 1, 1))
			var tray := Interactable.create(geo, Vector3(x, 0.32, z + 0.47), Vector3(0.9, 0.22, 0.05), "Reseat the fan tray (%s)" % id, Color(0.22, 0.22, 0.24))
			tray.used.connect(_on_tray.bind(id))
			fan_trays[id] = tray
			rb += 1
	for z in [0.0, 6.0]:
		add_light("srb", Vector3(15, 3.6, z), 8.0, 1.0)
	# Inside the door, the room's monitoring card: where the temperatures live and
	# what counts as too hot (the > the hot rack's query needs, found in the world).
	_rack_card(Vector3(12.6, 1.5, 8.89), 0.0, false)

	# Break room: x 8..22, z -9..-3. Coffee, a fridge, a table.
	Greybox.room(geo, Vector3(15, 0, -6), Vector3(14, 3, 6), c, [_gap("n", -3.0, door), _gap("s", -3.0, door)])
	add_door("BREAK", Vector3(12.0, 1.1, -9.0), Vector3(1.35, 2.2, 0.08)).make_hinged(Vector3(-0.675, 0, 0), -90.0)
	Greybox.label(geo, Vector3(12.0, 2.45, -9.12), "BREAK ROOM", 36, sign_c, 180)
	Greybox.box(geo, Vector3(17.5, 0.38, -5.5), Vector3(3.0, 0.76, 1.4), desk_c, "BreakTable")
	Greybox.box(geo, Vector3(21.4, 0.45, -6), Vector3(0.8, 0.9, 4.0), Color(0.55, 0.55, 0.5), "Counter")
	Greybox.box(geo, Vector3(21.3, 0.95, -4.0), Vector3(0.6, 1.9, 0.8), Color(0.85, 0.85, 0.82), "Fridge")
	Greybox.box(geo, Vector3(21.5, 1.15, -7.0), Vector3(0.4, 0.5, 0.4), Color(0.15, 0.15, 0.15), "CoffeeMachine")
	Document.place(geo, Vector3(21.0, 0.902, -6.0), -90.0, "Coffee fund", [
		{"text": "Coffee fund is EMPTY. You know who you are.", "hand": true},
		{"text": "- night shift", "hand": true},
	], true, "note", Vector2(0.1, 0.1))
	var bulb := Document.place(geo, Vector3(13.0, 1.15, -9.12), 180.0, "Sticky note", [
		{"text": "Bulb's dead AGAIN. It's in the lights table. Nobody reads it.", "hand": true},
		{"text": "- night shift", "hand": true},
	], false, "sticky")
	bulb.pieces = [{"case": "dark_room", "piece": "table"}, {"case": "dark_room", "piece": "dead"}]
	bulb.read_by.connect(func(_p): _book_found("easy_sql_8"))
	# Its row in the lights table says the bulb is dead (Level1Data), so it's dark.
	add_light("1-BREAK", Vector3(15, 3, -6), 6.0, 1.0, office)
	# Optional: inside the door, the floor's lighting circuit reset and facilities'
	# card on how to use it. The reset only takes once the terminal has listed the
	# lights that are out: dead OR flickering, not the ones off on purpose.
	light_panel = Interactable.create(geo, Vector3(13.3, 1.3, -8.86), Vector3(0.35, 0.45, 0.08), "Reset the lighting circuit", Color(0.55, 0.56, 0.5))
	light_panel.used.connect(_on_light_panel)
	_facilities_card(Vector3(14.1, 1.45, -8.89), 180.0, false)

	# Server Room C: x -17..-7, z -24..-13. Its lock is on the faulting controller (seeded zone).
	Greybox.room(geo, Vector3(-12, 0, -18.5), Vector3(10, 3.6, 11), machine, [_gap("s", 0.0, door)])
	# Locked by its row in doors: it's one of the stuck doors.
	room_c_door = add_door("SRC", Vector3(-12.0, 1.1, -13.0), Vector3(1.35, 2.2, 0.08)).make_hinged(Vector3(-0.675, 0, 0), 90.0)
	Greybox.label(geo, Vector3(-12.0, 2.45, -12.88), "SERVER ROOM C", 36, sign_c)
	for x in [-15.0, -9.0]:
		Greybox.box(geo, Vector3(x, 1.05, -19), Vector3(0.9, 2.1, 6.0), rack_c, "RackC")
	Greybox.box(geo, Vector3(-12, 0.38, -23.2), Vector3(2.0, 0.76, 0.8), desk_c, "PrinterDesk")
	# The floor's syslog printer: the night's events, in-world proof of Vale's override.
	Document.place(geo, Vector3(-12, 0.762, -23.1), 0.0, "SYSLOG PRINTOUT", [
		"SERVER FLOOR  -  SYSLOG  -  15 OCT 1997",
		"23:02  LAB B   badge V-0042 (VALE, I.) door open",
		"23:12  ZONE %s  manual override by user VALE_I, from SECURE LAB B" % zone,
		"23:14  ZONE %s  lock relay stuck" % zone,
		"23:31  LAB B   door forced",
		"23:31  LAB B   camera feed lost",
	], true, "paper")
	add_light("src", Vector3(-12, 3.6, -18.5), 7.0, 0.8)


func net_setup() -> void:
	sync.replicate(rourke, rourke.sync_properties())


func start() -> void:
	cable_coil.stock(players.count())
	if world:
		# The ground floor's Rourke rode up with the crew: this one takes his place,
		# where he stands in the arrival car.
		var lobby: LevelBase = world.wings.get("level_0")
		var guide = lobby.get("rourke") if lobby else null
		if is_instance_valid(guide):
			rourke.global_transform = guide.global_transform
			guide.queue_free()
		else:
			# The building opened on this floor (Levels): nobody rode up, so the
			# arrival car opens with him in it.
			rourke.global_transform = arrival_lift.global_transform * Transform3D(Basis(), ROURKE_IN_LIFT)
			arrival_lift.open(true)
		rourke.visible = true
	hud.todo("Time to look like IT", "Follow Rourke to Server Room A")
	rourke.watch = null
	var led_in := _lead_in()
	await hud.line("l1_noc_1")  # passing the ops room's window
	if world:
		await hud.line("l0_sra")  # off the elevator, at the server room door
	await sync.gate("rourke_at_desk", func():
		if not led_in.finished:
			await led_in.done)
	_watch_nearest()
	await hud.line("l1_terminal")
	_on_asked()


## Rourke has asked: his maintenance session opens on the terminal.
func _on_asked() -> void:
	if asked:
		return
	asked = true
	# Keeping only some rows lands with his ask, always: read earlier, the shift
	# log's chapter waited for him (M1). AND comes with the stuck doors' zone (M2).
	if sync.is_host():
		_books["easy_sql_5"] = "played"
	await _book_huddle("easy_sql_5")
	terminal.locked = false
	_mark_beat()
	if not controller_puzzle.solved:
		var game := get_node("/root/Game")
		hud.todo("Doors that won't open", TODO_ZONE)
		game.open_case("controller", "Which door controller keeps faulting?", ["door_controllers", "doors"], OBJ_CONTROLLER)
		# The case's query follows its step (S7): the doors table first.
		game.set_pieces("controller", STUCK_PIECES, STUCK_QUERY, CONTROLLER_STEPS)
		_set_zone_slot()
	if sync.is_host():
		await get_tree().create_timer(WAITING_AFTER, false).timeout
		if not controller_puzzle.solved:
			sync.event("_on_rourke_waiting")


## The first slot (S13): any stuck door's zone cell answers it.
func _set_zone_slot() -> void:
	slot = "zone"
	var rows := db.run_silent("SELECT id, name FROM doors WHERE id IN ('%s')" % "', '".join(Level1Data.STUCK_DOORS))
	get_node("/root/Game").set_blank("controller", SLOT_ZONE, NO_LINE, zone, {"column": "zone", "values": [zone], "rows": rows})


## A while in and still looking: Rourke tells them to take their time. The crew's
## commentary holds around his line, so the two never overlap.
func _on_rourke_waiting() -> void:
	if controller_puzzle.solved:
		return
	if is_instance_valid(commentary):
		commentary.hold(true)
	await hud.line("l1_waiting")
	if is_instance_valid(commentary):
		commentary.hold(false)


## Rourke leads the crew in: out of the car, along the corridor and through Server
## Room A's door, then to the terminal desk. Straight walks between waypoints, so
## he never depends on a navigation path across the wing's seam.
class LeadIn:
	signal done
	var finished := false


func _lead_in() -> LeadIn:
	var lead := LeadIn.new()
	var walk := func():
		for p in [Vector3(0, 0, 13.6), Vector3(0, 0, 11), Vector3(0, 0, 7.8), Vector3(-2.4, 0, 6.4)]:
			if p.z > to_local(rourke.global_position).z + 0.3:
				continue  # already past this one
			rourke.walk_to(to_global(p), true)
			await rourke.arrived
		lead.finished = true
		lead.done.emit()
	walk.call()
	return lead


## Host: Rourke turns to whoever is closest when he talks.
func _watch_nearest() -> void:
	if sync.is_host():
		rourke.watch = players.nearest(rourke.global_position)


func _self_test_lines() -> Array:
	return [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  SERVER ROOM A",
		"Session: ROURKE_D (facilities)  -  maintenance window open until 06:00",
		"[b]WARDEN SELF-TEST[/b]  23:51:07",
		"  [color=#ff6655]FAIL[/color]  doors.server_room_a.exit    expected: unlocked     got: controller fault",
		"  [color=#ff6655]FAIL[/color]  lift.server_floor           expected: in service   got: controller fault",
		"  [color=#ff6655]FAIL[/color]  doors.cold_lab              expected: unlocked     got: controller fault",
		"3 failed, 4 passed.",
		"Stuck? Type [b].hint[/b]",
	]


## Runs on the host; the result plays out on every machine. A result that
## answers a step puts SYSOP's word up at most; the step itself waits for the
## crew to point at the answer in it (case_answered).
func _on_query(_sql: String, result: Dictionary, _ui: TerminalUI) -> void:
	if not hot_listed and hot_rack_puzzle.matches(db, result):
		sync.event("_on_hot_rack_listed")
	elif not hot_rack_puzzle.solved and (hot_backwards.matches(db, result) or hot_backwards_eq.matches(db, result)):
		comment_mistake("backwards")
	if not dark_room_puzzle.solved and dark_room_puzzle.matches(db, result):
		sync.event("_on_dark_room_found")
	if not asked:
		return
	if slot == "zone" and not stuck_listed and stuck_doors_puzzle.matches(db, result):
		sync.event("_on_stuck_doors_listed")
	if slot == "controller" and not controller_listed and controller_puzzle.matches(db, result):
		sync.event("_on_controller_listed")
	if not count_puzzle.solved:
		if count_puzzle.matches(db, result):
			if not counted:
				sync.event("_on_counted")
		elif count_all.matches(db, result):
			sync.event("_on_count_wrong", ["all"])
		elif count_not_ok.matches(db, result):
			sync.event("_on_count_wrong", ["not_ok"])
		elif count_zone.matches(db, result):
			sync.event("_on_count_wrong", ["zone"])
		elif controller_puzzle.solved and count_listed.matches(db, result):
			sync.event("_on_count_wrong", ["listed"])


## The hot rack is on screen: pointing at its id finds it.
func _on_hot_rack_listed() -> void:
	hot_listed = true


## The terminal found the hot rack (its id pointed at): its tray's latch lets go.
func _on_hot_rack_found() -> void:
	if hot_rack_found:
		return
	hot_rack_found = true
	get_node("/root/Game").tick_step("hot_rack", "run")
	terminal.print_line("> FAN TRAY LATCH RELEASED: RACK %s RUNNING HOT." % hot_rack)


## The stuck doors are on screen: SYSOP says what they share (S29).
func _on_stuck_doors_listed() -> void:
	if stuck_listed:
		return
	stuck_listed = true
	terminal.print_line("")
	terminal.print_line(TerminalUI.sysop("those are the doors that won't release. the three on the shift log share one zone: the faulting controller is in it."))


func _on_controller_listed() -> void:
	controller_listed = true


func _on_counted() -> void:
	counted = true


## The stuck doors' zone is in the slot: the controller is the next step, and
## the case's query becomes the controller's. AND's chapter lands now (M2).
func _on_stuck_doors_found() -> void:
	if stuck_doors_puzzle.solved:
		return
	stuck_doors_puzzle.solved = true
	var game := get_node("/root/Game")
	game.add_clue("controller", "The stuck doors on this floor are all in zone %s." % zone, "Query result")
	game.tick_step("controller", "zone")
	game.set_pieces("controller", controller_pieces(zone), CONTROLLER_QUERY, CONTROLLER_STEPS)
	game.collect_piece("controller", "zone", "the doors query")
	slot = "controller"
	game.set_blank("controller", SLOT_CONTROLLER, NO_LINE, answer, {"column": "id", "values": [answer], "rows": [{"id": answer}]})
	if not controller_puzzle.solved:
		hud.todo("The one that keeps breaking", OBJ_CONTROLLER)
	# The crew sees it now: every stuck door in one zone. Then the controller's lines.
	if is_instance_valid(commentary):
		if sync.is_host():
			commentary.solved("stuck_doors")
		commentary_ids["controller"] = "controller"
		commentary.begin("controller")
	_mark_beat()
	_book_huddle("easy_sql_6")


## Optional: the list of lights that are out. The circuit reset takes now.
func _on_dark_room_found() -> void:
	dark_room_puzzle.solved = true
	terminal.print_line("")
	terminal.print_line(TerminalUI.sysop("that's every light that's out. the reset by the break room door takes now."))
	var game := get_node("/root/Game")
	game.open_case("dark_room", DARK_CASE, ["lights"])
	game.tick_step("dark_room", "run")
	game.add_clue("dark_room", "The lights out are the dead and flickering ones. Reset the circuit by the break room door.", "SYSOP")


## Host: someone pressed the break room's lighting reset.
func _on_light_panel(_p: Node) -> void:
	if lights_fixed:
		return
	sync.event("_on_light_reset" if dark_room_puzzle.solved else "_on_light_refused")


func _on_light_refused() -> void:
	hud.notice("> LIGHTING CIRCUIT: RESET LOCKED.\n> It unlocks once the terminal lists every light that's dead or flickering.", 4.0, ThemeUtil.RED)


## Host: a paper brings back chapter `id` of Easy SQL. Read before its puzzle is
## ready, it waits: reading that paper again once it is plays it.
func _book_found(id: String) -> void:
	if sync.is_host():
		if not _books.has(id):
			_books[id] = "found"
		_book_check(id)


## Host: play chapter `id` if its paper has been read and its puzzle is ready.
func _book_check(id: String) -> void:
	if sync.is_host() and _books.get(id, "") == "found" and _book_ready(id):
		_books[id] = "played"
		sync.event("_book_huddle", [id])


func _book_ready(id: String) -> bool:
	match id:
		"easy_sql_5":
			return asked  # it lands with Rourke's ask (M1)
		"easy_sql_7", "easy_sql_8":
			# After WHERE and AND's chapters, so their WHERE comes first.
			var h := Huddle.of(self)
			return asked and h != null and h.done.has("easy_sql_6")
		"easy_sql_count":
			return controller_puzzle.solved  # counting is the third step (M3)
	return true


## Every machine: a paper brings back its chapter of Easy SQL, into the crew's book
## (once per run), and one of the crew remembers what Maddison said about it. A
## chapter landing is a beat: a side case's paper read just now waits (M5).
func _book_huddle(id: String) -> void:
	if id == "easy_sql_count":
		get_node("/root/Game").collect_piece("controller", "count", "Easy SQL")  # the chapter fills its piece (S12)
	var h := Huddle.of(self)
	if h == null or h.done.has(id):
		return
	_mark_beat()
	await h.run(id, Huddle.REMEMBERED)
	if sync.is_host():
		for k in _books.keys():
			_book_check(k)  # a chapter that waited on this one


## A main step or a chapter landed just now (M5).
func _mark_beat() -> void:
	_beat_ms = Time.get_ticks_msec()


## Host: a side case's paper was read. Within a minute of the last beat its case
## waits for that minute to be up, so it doesn't crowd the main one (M5).
func _side_case_read(id: String) -> void:
	if not sync.is_host() or _side_waiting.has(id) or get_node("/root/Game").case_info(id).get("open", false):
		return
	_side_waiting[id] = true
	if _beat_ms >= 0:
		var wait := pace_s - (Time.get_ticks_msec() - _beat_ms) / 1000.0
		if wait > 0.0:
			await get_tree().create_timer(wait, false).timeout
	sync.event("_open_side_case", [id])


## Every machine: a side case opens.
func _open_side_case(id: String) -> void:
	var game := get_node("/root/Game")
	match id:
		"hot_rack":
			game.open_case("hot_rack", HOT_CASE, ["racks"])
		"dark_room":
			game.open_case("dark_room", DARK_CASE, ["lights"])


## This player pointed at a cell that answers one of their cases: tell the host.
func _on_answer_found(id: String) -> void:
	if id in ["controller", "hot_rack"]:
		sync.report_answer(id)


## Host: a player put the answer in a slot. The controller case's slot is the
## step it's on.
func case_answered(id: String, _peer: int) -> void:
	if id == "hot_rack" and not hot_rack_found:
		sync.event("_on_hot_rack_found")
	if id != "controller" or not asked:
		return
	match slot:
		"zone":
			sync.event("_on_stuck_doors_found")
		"controller":
			sync.event("_on_controller_found")
		"count":
			sync.event("_on_count_found")


## This player pointed at a cell that answers no slot: if it's in a row the slot
## is about, a pencil line under the blank says why (S14-S16, S18-S21, S23-S24,
## S26-S28; this player's notebook only).
func _on_cell_missed(column: String, value: String, row: Dictionary) -> void:
	var game := get_node("/root/Game")
	var shown := {}
	for k in row:
		shown[str(k).to_lower()] = str(row[k])
	if not shown.has(column.to_lower()):
		shown[column.to_lower()] = value
	var col := column.to_lower()
	var ctl: Dictionary = game.case_info("controller")
	if asked and ctl.get("open", false) and not ctl.get("solved", false):
		var note := _controller_miss(col, value, shown)
		if note != "":
			game.blank_miss("controller", note)
	var hot: Dictionary = game.case_info("hot_rack")
	if hot.get("open", false) and not hot.get("solved", false) and not hot_rack_found:
		var rows := rows_like("racks", shown)
		if not rows.is_empty():
			var edge := rows.all(func(r): return int(r.temp_c) == Level1Data.INTERLOCK_C)
			if edge:
				game.blank_miss("hot_rack", HOT_EDGE)
			elif col == "temp_c" and rows.all(func(r): return r.id == hot_rack):
				game.blank_miss("hot_rack", HOT_TEMP)
			else:
				game.blank_miss("hot_rack", HOT_OTHER)


## The pencil note for a missed cell on the controller case's current slot, or "".
func _controller_miss(col: String, value: String, shown: Dictionary) -> String:
	match slot:
		"zone":
			var rows := rows_like("doors", shown)
			if rows.is_empty():
				return ""
			if rows.all(func(r): return r.id in Level1Data.STUCK_DOORS):
				return ZONE_ROW
			if col == "zone" and rows.all(func(r): return int(r.locked) == 1 and not r.id in Level1Data.STUCK_DOORS):
				return ZONE_OTHER_FLOOR
			return ZONE_OTHER
		"controller":
			var rows := rows_like("door_controllers", shown)
			if rows.is_empty():
				return ""
			if rows.all(func(r): return r.id == answer):
				return CTRL_ROW
			if rows.all(func(r): return r.zone == zone and r.status == "offline"):
				return CTRL_OFFLINE
			if rows.all(func(r): return r.zone != zone and r.status == "fault"):
				return CTRL_ELSEWHERE
			return CTRL_OTHER
		"count":
			if col == "id" and not rows_like("door_controllers", shown).is_empty():
				return COUNT_ONE
			if shown.size() == 1 and value.is_valid_int():
				return COUNT_WRONG
	return ""


## The rows of `table` that a result row showing `shown` (column -> value, lower-
## case names) could be: every shown column is the table's and holds that value.
## [] if a shown column isn't the table's.
func rows_like(table: String, shown: Dictionary) -> Array:
	var all := db.run_silent("SELECT * FROM %s" % table)
	if all.is_empty():
		return []
	var cols := {}
	for k in all[0]:
		cols[str(k).to_lower()] = k
	for k in shown:
		if not cols.has(k):
			return []
	return all.filter(func(r):
		for k in shown:
			var v = r[cols[k]]
			if ("NULL" if v == null else str(v)).to_lower() != str(shown[k]).to_lower():
				return false
		return true)


## Every machine: the break room lights up and the north corridor stops flickering.
func _on_light_reset() -> void:
	lights_fixed = true
	light_panel.enabled = false
	db.run_silent("UPDATE lights SET is_on = 1, status = 'ok' WHERE floor = 1 AND (status = 'dead' OR status = 'flickering')")
	db.sync_world()
	for l in lights.get("corridor", []):
		for f in l.get_children():
			if f is FlickerLight:
				l.light_energy = f.base_energy
				f.queue_free()
	hud.notice("> LIGHTING CIRCUIT RESET: BREAK ROOM AND NORTH CORRIDOR BACK ON.", 4.0, ThemeUtil.GREEN)
	get_node("/root/Game").solve_case("dark_room", "the break room's bulb was dead and the north corridor flickering. One circuit reset fixed both.")


## The controller's id is in the slot: next, the sign-off's count, and the
## case's query becomes the count's (S11). "How many?" lands now if the sign-off
## or WARDEN's printout has been read (M3).
func _on_controller_found() -> void:
	if controller_puzzle.solved:
		return
	controller_puzzle.solved = true
	var game := get_node("/root/Game")
	game.tick_step("controller", "run")
	terminal.print_line("")
	terminal.print_line(TerminalUI.sysop("that's the one. %s, zone %s, 'fault'. reset it by hand at its rack." % [answer, zone]))
	game.add_clue("controller", "%s is the one: zone %s, 'fault'. Reset it by hand at its rack." % [answer, zone], "SYSOP")
	game.set_pieces("controller", count_pieces(), COUNT_QUERY, CONTROLLER_STEPS)
	slot = "count"
	game.set_blank("controller", SLOT_COUNT, NO_LINE, str(faulted), {"column": "", "values": [str(faulted)], "only": true})
	_mark_beat()
	_book_check("easy_sql_count")
	terminal.print_line(TerminalUI.sysop("the reset wants its sign-off first: how many controllers are faulted, whichever door they run. count them here, not by walking the racks."))
	hud.todo("Paperwork. Even tonight.", COUNT_TODO)


## The count step's pieces (S12): COUNT(*) is new; the table and the status carry over.
func count_pieces() -> Array:
	var out: Array = [COUNT_PIECE]
	for p in controller_pieces(zone):
		if p.id != "zone":
			out.append(p)
	return out


## The sign-off's count is in the slot. Its blank on the job ticket is filled in
## with the number, and the rack reset circuits are powered.
func _on_count_found() -> void:
	if count_puzzle.solved:
		return
	count_puzzle.solved = true
	slot = ""
	_mark_beat()
	terminal.print_line("")
	terminal.print_line(TerminalUI.sysop("%d faulted, whichever door they run. that's the number for the sign-off. the rack reset circuits are powered now." % faulted))
	var game := get_node("/root/Game")
	game.ticket_fill(COUNT_TODO, "units faulted: %d" % faulted)
	game.tick_step("controller", "count")
	if controller_puzzle.solved:
		hud.todo("Turn it off and on again", "Reset the faulted controller at its rack")


func _on_count_wrong(why: String) -> void:
	if why == "all":
		terminal.print_line(TerminalUI.sysop("that counts every controller on the floor, healthy ones too. the sign-off wants only the faulted ones."))
	elif why == "listed":
		terminal.print_line(TerminalUI.sysop("that's them. the form wants how many: let COUNT(*) do the counting."))
	elif why == "zone":
		terminal.print_line(TerminalUI.sysop("that's only the stuck doors' zone. the sign-off wants every faulted unit, whichever door it runs."))
	else:
		terminal.print_line(TerminalUI.sysop("that counts the offline ones too. they're switched off on purpose, not faulted."))


## Runs on the host when anyone presses a rack panel. It decides, then
## everyone sees the outcome, so the lockout timer is the same for all.
func _on_panel(_p: Node, id: String) -> void:
	if not asked:
		sync.event("_on_panel_result", [id, "not_yet", 0.0])
		return
	# The reset circuits stay dead until the terminal has found the controller and
	# counted the faults for the sign-off, so pressing every rack can't stand in for
	# the queries.
	if not controller_puzzle.solved or not count_puzzle.solved:
		sync.event("_on_panel_result", [id, "unpowered", 0.0])
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < panels_locked_until:
		sync.event("_on_panel_result", [id, "locked", panels_locked_until - now])
		return
	if id != answer:
		var row: Dictionary = db.run_silent("SELECT status FROM door_controllers WHERE id = '%s'" % id)[0]
		sync.event("_on_panel_result", [id, "healthy" if row["status"] == "ok" else "wrong", 10.0])
		return
	sync.event("_on_panel_result", [id, "reset", 0.0])


func _on_panel_result(id: String, outcome: String, seconds: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	match outcome:
		"not_yet":
			hud.notice("RESET REFUSED: no maintenance session open.", 2.5, ThemeUtil.RED)
			return
		"unpowered":
			hud.notice("> %s: NO POWER TO THE RESET CIRCUIT.\n> It powers up once the terminal finds the faulted controller and logs the count for the sign-off." % id, 4.0, ThemeUtil.RED)
			return
		"locked":
			panels_locked_until = now + seconds
			hud.notice("PANELS LOCKED: tamper lockout, %d s" % int(seconds), 2.0, ThemeUtil.RED)
			return
		"healthy":
			var zone: String = db.run_silent("SELECT zone FROM door_controllers WHERE id = '%s'" % id)[0]["zone"]
			hud.notice("> CONTROLLER %s: ZONE %s, OK. NOTHING TO RESET." % [id, zone], 4.0)
			terminal.print_line(TerminalUI.sysop("%s is healthy. you want the controller with status 'fault' in the stuck doors' zone." % id))
			hud.line("l1_wrong_panel", false)
			comment_mistake("reset")
			return
		"wrong":
			var row: Dictionary = db.run_silent("SELECT status, zone, note FROM door_controllers WHERE id = '%s'" % id)[0]
			panels_locked_until = now + seconds
			# The rack's own readout shows why, right where the player made the mistake.
			hud.notice("> %s: ZONE %s, '%s': %s\n> RESET REFUSED. PANELS LOCKED: %d s" % [id, row["zone"], row["status"], row["note"], int(seconds)], 6.0, ThemeUtil.RED)
			terminal.print_line(TerminalUI.sysop("not that one. %s is zone %s, '%s': %s" % [id, row["zone"], row["status"], row["note"]]))
			hud.line("l1_wrong_panel", false)
			comment_mistake("reset")
			return
	_on_reset(id)


## The right rack: the floor's stuck doors and the elevator come back, and the
## controller's log shows who caused the fault.
func _on_reset(id: String) -> void:
	controller_puzzle.solved = true
	for p in rack_panels.values():
		p.enabled = false
	# The reset wants a badge: Rourke lends his own.
	if sync.is_host():
		var at := to_local(rack_panels[id].global_position)
		rourke.watch = null
		rourke.walk_to(to_global(Vector3(0, 0, 5)), true)
		await rourke.arrived
		rourke.walk_to(to_global(Vector3(signf(at.x) * 1.2, 0, at.z)), true)
	await sync.gate("rourke_badges_in", func():
		if rourke.state == Rourke.State.WALK:
			await rourke.arrived)
	await hud.line("l1_badge_help")
	db.run_silent("UPDATE door_controllers SET status = 'ok', last_reset = '1997-10-15 23:58' WHERE id = '%s'" % id)
	db.run_silent("UPDATE doors SET locked = 0, actuator_fault = 0 WHERE id IN ('%s')" % "', '".join(Level1Data.STUCK_DOORS))
	db.sync_world()
	for door_id in Level1Data.STUCK_DOORS:
		_light_plate(door_id, false)
	if is_instance_valid(lift_sign):
		lift_sign.queue_free()  # Lift 1's back in service: facilities' sign comes down
	comment("right_rack")
	_mark_beat()
	hud.notice("> CONTROLLER %s: RESET OK\n> ZONE %s DOORS: OK\n> LIFT 1: IN SERVICE" % [id, zone], 4.0, ThemeUtil.GREEN)
	get_node("/root/Game").solve_case("controller", "%s, reset at its rack. Its log says VALE_I kept resetting it from Secure Lab B." % id)
	terminal.print_line("")
	for line in _controller_log(id):
		terminal.print_line(line)
	hud.todo("")
	_watch_nearest()
	await hud.lines(["l1_fixed_1", "l1_fixed_2"])
	hud.todo("Job done. Next floor.", "Follow Rourke to the elevator")
	# Vale's login comes up on the walk out, through the rear exit the reset just
	# opened (M6), not at the rack.
	var rear := Trigger.create(self, Vector3(0, 1, -9.4), Vector3(3.0, 2, 2.0))
	rear.entered.connect(func(_b): sync.event("_on_pivot"), CONNECT_ONE_SHOT)
	rourke.watch = null
	await sync.gate("rourke_at_lift", func():
		for p in [Vector3(0, 0, to_local(rourke.global_position).z), Vector3(0, 0, -7.8), Vector3(0, 0, -10.5), Vector3(1.8, 0, -11)]:
			rourke.walk_to(to_global(p), true)
			await rourke.arrived)
	_watch_nearest()
	# The elevator opens once the whole crew is with him in the north corridor.
	var t := Trigger.create(self, Vector3(0, 1, -11), Vector3(8, 2, 4))
	t.require_all = true
	t.waiting.connect(func(n, total): sync.team_notice("Rourke is waiting at the elevator for everyone (%d/%d)" % [n, total]))
	t.entered.connect(func(_b): sync.event("_on_crew_at_lift"), CONNECT_ONE_SHOT)


func _controller_log(id: String) -> Array:
	return [
		"> %s FAULT LOG" % id,
		"  10/13 22:51  RESET            user VALE_I   from SECURE LAB B",
		"  10/14 23:40  RESET            user VALE_I   from SECURE LAB B",
		"  10/15 23:12  RESET            user VALE_I   from SECURE LAB B",
		"  10/15 23:14  LOCK RELAY STUCK",
		"  10/15 23:58  RESET            at rack, badge R-0117 (ROURKE, D.)",
	]


## Every machine: through Server Room A's rear exit, Rourke works out whose login
## kept resetting the controller (M6).
func _on_pivot() -> void:
	if _pivot_done:
		return
	_pivot_done = true
	await hud.lines(["l1_pivot_1", "l1_pivot_2", "l1_pivot_3"])


## Everyone is with Rourke: the elevator opens and he steps in first.
func _on_crew_at_lift() -> void:
	if not _pivot_done:
		await _on_pivot()  # the crew went round another way: he says it here
	elevator.hud = hud
	elevator.open()
	elevator.closed.connect(_on_elevator_closed, CONNECT_ONE_SHOT)
	elevator.button.enabled = true
	prepare_next()
	rourke.watch = null
	await sync.gate("rourke_in_lift", func():
		await get_tree().create_timer(0.6, false).timeout
		rourke.walk_to(elevator.to_global(Vector3(0, 0, 0.6)), true)
		await rourke.arrived
		rourke.walk_to(elevator.to_global(ROURKE_IN_LIFT), true)
		await rourke.arrived)
	_watch_nearest()
	if not elevator.is_closing and not elevator.riding:
		hud.todo("Up to the labs", "Get everyone into the elevator, then press 22")
		hud.line("l1_lift_button")


## Runs on the host when anyone reseats a fan tray in Server Room B. Only the hot
## rack's tray matters; pulling a healthy one trips its alarm and locks the trays.
func _on_tray(_p: Node, id: String) -> void:
	if not vault_back.locked:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not hot_rack_found:
		sync.event("_on_tray_result", [id, "latched", 0.0])
	elif now < trays_locked_until:
		sync.event("_on_tray_result", [id, "locked", trays_locked_until - now])
	elif id == hot_rack:
		sync.event("_on_tray_result", [id, "fixed", 0.0])
	else:
		sync.event("_on_tray_result", [id, "fine", 15.0])


func _on_tray_result(id: String, outcome: String, seconds: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	match outcome:
		"latched":
			hud.notice("> %s: TRAY LATCH LOCKED.\n> It releases once the terminal finds the rack over the limit." % id, 4.0, ThemeUtil.RED)
		"locked":
			trays_locked_until = now + seconds
			hud.notice("TRAYS LOCKED: %d s" % int(seconds), 2.0, ThemeUtil.RED)
		"fine":
			trays_locked_until = now + seconds
			var t: int = db.run_silent("SELECT temp_c FROM racks WHERE id = '%s'" % id)[0]["temp_c"]
			hud.notice("> %s: fans already fine. %d°C\n> TRAYS LOCKED: %d s" % [id, t, int(seconds)], 5.0, ThemeUtil.RED)
		"fixed":
			hot_rack_puzzle.solved = true
			get_node("/root/Game").solve_case("hot_rack", "%s ran over the limit. Reseating its fan tray let the interlock go." % id)
			db.run_silent("UPDATE racks SET temp_c = 33, note = 'fan tray reseated' WHERE id = '%s'" % id)
			hud.notice("> %s: FANS 100%%. TEMP FALLING" % id, 3.0, ThemeUtil.GREEN)
			await get_tree().create_timer(2.5, false).timeout
			vault_back.locked = false
			hud.notice("> FIRE INTERLOCK RELEASED: CABLE VAULT", 3.0, ThemeUtil.GREEN)


## Someone took a coil of cable (every machine): Level 2 knows who carries one.
func _on_cable_taken(id: int) -> void:
	cable_holders[id] = true
	if id == players.id_of(player):
		hud.notice("You sling the coil of network cable over your shoulder.", 3.0)


## The doors are shut: this is the checkpoint. The next floor loads during the ride,
## and the crew (Rourke too) steps out of its arrival car.
func _on_elevator_closed() -> void:
	get_node("/root/Net").earn("achievement:floor_14", hud)  # floor 14 is done: everyone aboard earns it
	hud.todo("")
	if world:
		db.checkpoint()
	prepare_next()
	var next: Node = world.wings.get("level_2") if world else null
	if next and next.get("arrival_lift") is Elevator:
		elevator.link_to(next.arrival_lift)
	await elevator.ride()
	if elevator.destination:
		var into := elevator.destination.global_transform * elevator.global_transform.affine_inverse()
		rourke.global_transform = into * rourke.global_transform
	Game.completed_level = "level_1"
	Game.next_level = "level_2"
	if not world:
		player.input_locked = true
		await hud.fade(true, 1.2)
	finish_level("field_notes")


func on_player_died() -> void:
	player.respawn(global_transform * Transform3D(Basis(), RESPAWN))
