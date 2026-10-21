extends LevelBase
## Level 4: Power Plant, floor 10 ("Don't Forget the WHERE"). Act 2 opens.
## The crew comes down STAIR 1 from 18 and finds the stairs closed below 10 for the
## night. Floor 10 is the tower's mid-height mechanical floor: a switchgear hall with
## the breaker panel, the door and lift control room (dark since Tuesday's power
## event), and the Custodian's charging bay behind a sealed door.
##
## Puzzles (curriculum option B: UPDATE ... WHERE and INSERT are the last new SQL):
##   1. reset    Facilities' work order: reset the tripped PLANT CONTROL breaker with
##               an UPDATE ... WHERE (practised safely). Forget the WHERE and every
##               breaker flips: alarms, and the crew puts the others back.
##      check    the work order's sign-off: read the breaker back with a SELECT
##               (verify after write, practised safely).
##   2. login    the clipboard by the controller: contractors log in before touching
##               anything. The crew INSERTs its own job (practised safely).
## Write stations are StatePuzzles: checked by the table's state after the write,
## as a result set, never by the query's text.
## Every line players read is a draft in plan/approvals/l4-text.md until Augustine
## approves it word for word.
##
## Layout (level space, north is -z):
##   lift lobby       x -4..4,   z 4..8     stairs in (west wall), stairs down (east wall)
##   switchgear hall  x -10..10, z -10..4   breaker panel on the west wall, the plant
##                                          maintenance terminal, a 4.5 m ceiling
##   control room     x 2..10,   z -18..-10 the door and lift controller, its clipboard
##   charging bay     x -10..0,  z -18..-10 the Custodian's, behind a sealed roll-up door
##
## Co-op: the host decides (puzzle checks, what a write sets off) and every machine
## plays it out through sync.event.

## Player-facing lines, drafted for Augustine's approval: plan/approvals/l4-text.md.
const TEXT := {
	"todo_arrive": "The stairs are shut below 10. Find another way down",
	"todo_power": "Get the power back on in door and lift control",
	"todo_login": "Log the crew in before touching the controller",
	"todo_put_back": "Put the other breakers back the way they were",
	"case_power": "Why is door and lift control dark?",
	"case_login": "How do contractors get onto the controller?",
	"power_done": "Facilities' work order: the PLANT CONTROL breaker, %s, was tripped. Reset, and read back as on.",
	"login_done": "Logged in on the controller as %s, %s, at %s.",
	"alarm": "Every breaker on the panel slams over at once. An alarm starts somewhere in the walls.",
	"alarm_over": "The alarm stops.",
	"bay_stirs": "Behind the charging bay's door, something powers up.",
	"bay_quiet": "Behind the bay door, the hum winds down.",
	"power_back": "In the control room, the lights come on. Its door clunks open.",
	# SYSOP tips (text only, never lies; each fires once per run).
	"tip_first": "the breakers are rows. the work order names a circuit. find its row first, then change only that one.",
	"tip_no_where": "that changed every row. UPDATE without WHERE does that. put the others back the same way, one WHERE at a time.",
	"tip_zero": "0 rows changed: your WHERE matched nothing. look at the row first: SELECT * FROM breakers;",
	"tip_verify": "the terminal said it changed. did it? read it back.",
	"tip_order": "that row went in, but its values are in the wrong columns. the clipboard's columns go company, job, time in.",
	"tip_quotes": "a word without 'quotes' reads as a column name. put every value in single quotes.",
}
## Facilities' work order on the maintenance desk: where UPDATE ... SET ... WHERE is
## found. Its example is last month's job on another breaker, so copying it practises
## the shape without answering tonight's (the id is the player's own step).
const WORK_ORDER_LINES := [
	"HALCYON DATA SYSTEMS  -  FACILITIES WORK ORDER",
	"PLANT 10  -  OPENED 10/15",
	"Tuesday's power event tripped the PLANT CONTROL breaker.",
	"Door and lift control has had no power since. Reset it from the plant terminal.",
	{"text": "last month's, for the riser fans:", "hand": true},
	{"text": "UPDATE breakers SET state = 'on' WHERE id = 'CB-03';", "hand": true},
	{"text": "WHERE = that ONE breaker. no WHERE = every breaker on the panel!", "hand": true},
	"Check it took: read its state back and write it here: ________",
	{"text": "- R. Okonkwo, Building Engineer", "hand": true},
]
## The sign by the control room's door: why it won't open.
const CTRL_SIGN_LINES := [
	"DOOR AND LIFT CONTROL",
	"Powered door. With no power it stays shut.",
	"Authorized staff and logged-in contractors only.",
]
## The sign on the charging bay's door.
const BAY_SIGN_LINES := [
	"CHARGING BAY",
	"Maintenance unit inside. Keep this door shut.",
	"Facilities only.",
]
## The placard at the top of the stairs down: why the crew stops on 10.
const STAIR_CLOSED_LINES := [
	"STAIR 1  -  CLOSED BELOW 10",
	"After 19:00 the stairs below this floor are held shut.",
	"Night release: PLANT 10, door and lift control.",
]
## The level's case pages in the notebook (Cases tab), by id.
const CASES := {"power": TEXT.case_power, "login": TEXT.case_login}

## Where the stairs meet the lobby's walls.
const STAIR_IN_AT := Vector3(-4, 0, 6)
const STAIR_OUT_AT := Vector3(4, 0, 6)
## The breaker panel: boxes along the hall's west wall, two rows (level space).
const PANEL_X := -9.85
const PANEL_Z0 := -7.5
const PANEL_PITCH := 1.1
## The control room's and the bay's doors, in the hall's north wall.
const CTRL_DOOR_AT := Vector3(6, 1.2, -10)
const BAY_DOOR_AT := Vector3(-5, 1.4, -10)
## The control room, for tests and the art pass.
const CTRL_ROOM := AABB(Vector3(2, -0.5, -18), Vector3(8, 3.5, 8))

var data: Dictionary
var maint: Terminal
var controller: Terminal
var stair_in: Door
var stair_out: Door
var ctrl_door: Door
var bay_door: Door
## The breaker boxes on the panel, by id: their state lamps follow the table.
var lamps := {}
## The alarm is going: some breaker other than tonight's is not as the panel had it.
var alarm := false
## The charging bay's breaker is on: the thing inside is awake behind its door.
var bay_powered := false
var power_back := false
var logged_in := false
## The SYSOP tips that have fired this run (every machine).
var tips_sent := {}

## Puzzle stations. Built with the data (the breaker and the job vary per run).
## Ladder A for each: the shape with the value as ?, how to find it, the exact query.
var reset_puzzle: StatePuzzle
var check_puzzle: Puzzle
var login_puzzle: StatePuzzle


func build() -> void:
	data = Level4Data.build(Game.run_seed, Game.ticket_number())
	load_level_seed(data.sql)
	_make_puzzles()

	var colors := {"floor": Color(0.3, 0.31, 0.3), "wall": Color(0.55, 0.56, 0.52)}
	# Lift lobby: the dead lifts on the south wall, stairs either side.
	Greybox.room(geo, Vector3(0, 0, 6), Vector3(8, 3.2, 4), colors, [
		{"wall": "n", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "w", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},
		{"wall": "e", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},
	])
	Greybox.label(geo, Vector3(0, 2.75, 4.12), "10   PLANT", 56, Color(0.75, 0.75, 0.7))
	for x in [-1.5, 1.5]:
		Greybox.panel(geo, Vector3(x, 1.1, 7.88), Vector3(1.3, 2.2, 0.04), Color(0.5, 0.52, 0.55), 0.0)
		Greybox.label(geo, Vector3(x, 2.5, 7.86), "ELEVATOR  10", 32, Color(1.0, 0.45, 0.1), 180)
	# Stairs in from 18, on the west wall: Facilities wedged it for the plant work.
	stair_in = Stairwell.build(self, geo, STAIR_IN_AT, 90.0, "10")
	stair_in.name = "Door_STAIR-IN"
	stair_in.locked = false
	Greybox.box(geo, STAIR_IN_AT + Vector3(0.1, 0.03, 0.55), Vector3(0.12, 0.06, 0.2), Color(0.6, 0.45, 0.2), "DoorWedge")
	# Stairs down toward G, on the east wall: held shut for the night.
	stair_out = Stairwell.build(self, geo, STAIR_OUT_AT, -90.0, "10")
	stair_out.name = "Door_STAIR-OUT"
	exit_door = stair_out
	Document.place(geo, STAIR_OUT_AT + Vector3(-0.12, 1.75, 0.9), -90.0, "Stair notice", STAIR_CLOSED_LINES, false, "laminated", Vector2(0.26, 0.2))

	_build_hall(colors)
	_build_control_room(colors)
	_build_bay(colors)

	# Lights follow the `lights` table (sync_world): control room and bay are dark.
	add_light("L10-LOBBY", Vector3(0, 3.2, 6), 6.0, 0.9)
	for z in [-7.0, 0.0]:
		for x in [-5.0, 5.0]:
			add_light("L10-HALL", Vector3(x, 4.5, z), 8.0, 0.9, Color(0.95, 0.95, 0.85))
	add_light("L10-CTRL", Vector3(6, 3.0, -14), 6.0, 0.9)
	add_light("L10-BAY", Vector3(-5, 3.5, -14), 7.0, 0.6, Color(0.6, 0.8, 1.0))

	spawn = _stair_landing(STAIR_IN_AT, 90.0)


func _make_puzzles() -> void:
	var t: String = data.target
	var expected := PackedStringArray()
	for r in data.breakers:
		expected.append("('%s', '%s')" % [r[0], "on" if r[0] == t else r[3]])
	reset_puzzle = StatePuzzle.new("reset", "UPDATE breakers SET state = 'on' WHERE id = '%s'" % t,
		"SELECT id, state FROM breakers",
		"SELECT column1 AS id, column2 AS state FROM (VALUES %s)" % ", ".join(expected), ["id", "state"], [
		"the shape, with the breaker left as ?:\n" +
		"    [color=#ffffff]UPDATE breakers SET state = 'on' WHERE id = '?';[/color]\n" +
		"  UPDATE breakers   change rows in the breakers table\n" +
		"  SET state = 'on'   what to change: the state column becomes 'on'\n" +
		"  WHERE id = '?'   only that one row. ? is the id of the breaker the work order names. without WHERE, every row changes",
		"type\n" +
		"    [color=#ffffff]SELECT * FROM breakers;[/color]\n" +
		"the work order names a circuit, not an id. find the PLANT CONTROL row: its id is in the first column.",
		"type this, then Enter:\n" +
		"    [color=#ffffff]UPDATE breakers SET state = 'on' WHERE id = '%s';[/color]\n" % t +
		"then check it took.",
	])
	reset_puzzle.case_id = "power"
	# Verify after write, practised: the breaker read back, once it's been reset.
	# The whole panel read back (its id and state shown) answers it too.
	check_puzzle = Puzzle.new("check", "SELECT state FROM breakers WHERE id = '%s'" % t, ["state"], false, [
		"the shape, with the breaker left as ?:\n" +
		"    [color=#ffffff]SELECT state FROM breakers WHERE id = '?';[/color]\n" +
		"  SELECT state   just the state column\n" +
		"  FROM breakers   the breaker panel\n" +
		"  WHERE id = '?'   only that breaker. ? is the one you just reset",
		"the work order's sign-off wants the state you read, not the one you typed. ? is the id from your UPDATE.",
		"type this, then Enter:\n" +
		"    [color=#ffffff]SELECT state FROM breakers WHERE id = '%s';[/color]\n" % t +
		"it should say on. write that on the work order.",
	])
	check_puzzle.accept_also("SELECT id, state FROM breakers WHERE id = '%s'" % t, ["id", "state"], false)
	check_puzzle.case_id = "power"
	var who := "('%s', '%s', '%s')" % [data.company, data.ticket, data.time_in]
	login_puzzle = StatePuzzle.new("login", "INSERT INTO contractor_log VALUES %s" % who,
		"SELECT COUNT(*) > 0 AS logged FROM contractor_log WHERE lower(trim(company)) = lower('%s') AND upper(trim(job)) = '%s' AND trim(time_in) = '%s'" % [data.company, data.ticket, data.time_in],
		"SELECT 1 AS logged", ["logged"], [
		"the shape, with your job and the time left as ?:\n" +
		"    [color=#ffffff]INSERT INTO contractor_log VALUES ('%s', '?', '?');[/color]\n" % data.company +
		"  INSERT INTO contractor_log   add a new row to the contractor log\n" +
		"  VALUES (...)   the new row's values, in the clipboard's column order: company, job, time in\n" +
		"  '...'   every value in single quotes\n" +
		"the first ? is your work order's number. the second ? is the time on the clock over this room's door.",
		"open your notebook (Tab): the work order's number is printed at the top, WO- and five digits. the clock over the door reads hours:minutes.",
		"type this, then Enter:\n" +
		"    [color=#ffffff]INSERT INTO contractor_log VALUES %s;[/color]\n" % who +
		"then read the log back: SELECT * FROM contractor_log;",
	])
	login_puzzle.case_id = "login"


## A spot on a stairwell's landing, clear of the flight, facing its door.
func _stair_landing(at: Vector3, yaw_deg: float) -> Transform3D:
	var holder := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg + 180.0)), holder * Vector3(-0.8, 0.1, -1.3))


func player_spawn(index: int) -> Transform3D:
	# Six people fit on the landing in a row along the flight, not spread into the walls.
	var holder := Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), STAIR_IN_AT)
	var slot := holder * Vector3(-0.8 + 0.5 * (index % 2), 0.1, -0.7 - 0.55 * (index / 2))
	return global_transform * Transform3D(spawn.basis, slot)


## Level 3 calls this (through the World) as the crew heads down STAIR 1: everyone
## is placed on 10's landing before play moves here. Runs on every machine.
func arrive_by_stairs() -> void:
	players.place_all(self)


func _build_hall(colors: Dictionary) -> void:
	# A tall plant room: ducts and cable trays above, the panel along the west wall.
	Greybox.room(geo, Vector3(0, 0, -3), Vector3(20, 4.5, 14), {"floor": colors.floor, "wall": colors.wall, "ceiling": Color(0.32, 0.33, 0.33)}, [
		{"wall": "s", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "n", "at": CTRL_DOOR_AT.x, "width": 1.6, "height": 2.4},
		{"wall": "n", "at": BAY_DOOR_AT.x, "width": 3.0, "height": 2.8},
	])
	Greybox.label(geo, Vector3(0, 3.6, 3.88), "PLANT 10  -  SWITCHGEAR", 48, Color(0.8, 0.8, 0.72), 180)
	# The breaker panel: one box per row of `breakers`, its label and a lamp on the
	# front, and a paper tag hanging off any breaker with a note.
	Greybox.box(geo, Vector3(-9.7, 1.9, -4.75), Vector3(0.1, 2.6, 7.0), Color(0.36, 0.38, 0.4), "PanelBack")
	Greybox.label(geo, Vector3(-9.6, 3.45, -4.75), "MAIN DISTRIBUTION  -  FLOOR 10", 32, Color(0.9, 0.9, 0.85), 90)
	var rows: Array = data.breakers
	for i in rows.size():
		var r: Array = rows[i]
		var at := Vector3(PANEL_X + 0.25, 2.5 if i < 6 else 1.3, PANEL_Z0 + (i % 6) * PANEL_PITCH)
		Greybox.box(geo, at, Vector3(0.25, 0.8, 0.8), Color(0.55, 0.56, 0.58), "Breaker")
		Greybox.label(geo, at + Vector3(0.13, 0.25, 0), "%s\n%s" % [r[0], r[1]], 16, Color(0.1, 0.1, 0.1), 90)
		var lamp := Greybox.panel(geo, at + Vector3(0.13, -0.1, 0), Vector3(0.02, 0.1, 0.1), Color(0.2, 0.2, 0.2), 0.0)
		lamp.name = "Lamp_" + r[0]
		lamps[r[0]] = lamp
		if str(r[4]) != "":
			Document.place(geo, at + Vector3(0.14, -0.3, 0.2), 90.0, "Breaker tag", [r[0], {"text": r[4], "hand": true}], false, "note", Vector2(0.12, 0.09))
	# The plant maintenance desk, facing the panel's end: its terminal and the work order.
	Greybox.box(geo, Vector3(-6, 0.5, 1.6), Vector3(2.4, 1.0, 0.8), Color(0.4, 0.38, 0.34), "MaintDesk")
	maint = Terminal.spawn(geo, Vector3(-6.5, 1.0, 1.6), 0, "PLANT MAINT", db, terminal_ui)
	maint.name = "MaintTerminal"
	maint.puzzles = [reset_puzzle, check_puzzle]
	maint.boot_lines = [
		"HALCYON FACILITIES  -  PLANT 10  -  MAINTENANCE",
		"Breaker panel: breakers. One row per breaker box.",
	]
	maint.queried.connect(_on_query.bind("maint"))
	var wo := Document.place(geo, Vector3(-5.3, 1.0, 1.6), 0, "Facilities work order", WORK_ORDER_LINES, true, "clipboard")
	wo.clues = [{"case": "power", "opens": TEXT.case_power, "tables": ["breakers"], "text": "Facilities' work order: Tuesday's power event tripped the PLANT CONTROL breaker. Reset it, then check it took."}]
	wo.read_by.connect(func(_p): sync.event("_ask_power"))
	# Cable trays and ducts overhead, a transformer cage in the south-east corner.
	for z in [-8.0, -2.0]:
		Greybox.box(geo, Vector3(0, 4.0, z), Vector3(18, 0.15, 0.6), Color(0.45, 0.45, 0.42), "CableTray")
	Greybox.box(geo, Vector3(7.5, 1.2, 1.5), Vector3(3.0, 2.4, 3.0), Color(0.3, 0.34, 0.32), "Transformer")
	Greybox.label(geo, Vector3(7.5, 2.0, -0.02), "DANGER  480V", 36, Color(0.9, 0.75, 0.1), 180)


func _build_control_room(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(6, 0, -14), Vector3(8, 3.0, 8), {"floor": Color(0.25, 0.26, 0.28), "wall": colors.wall}, [
		{"wall": "s", "at": 0.0, "width": 1.6, "height": 2.4},
	])
	Greybox.label(geo, Vector3(CTRL_DOOR_AT.x, 2.75, -9.88), "DOOR AND LIFT CONTROL", 32, Color(0.8, 0.8, 0.72), 180)
	Document.place(geo, Vector3(CTRL_DOOR_AT.x + 1.3, 1.5, -9.88), 180, "Control room sign", CTRL_SIGN_LINES, false, "laminated", Vector2(0.3, 0.2))
	# A powered sliding door: unlocked in the doors table, but no power to its actuator.
	ctrl_door = add_door("PLANT-CTRL", CTRL_DOOR_AT, Vector3(1.6, 2.4, 0.12))
	# The controller on its desk, with the contractor clipboard beside it.
	Greybox.box(geo, Vector3(6, 0.5, -16.6), Vector3(3.0, 1.0, 0.8), Color(0.38, 0.38, 0.4), "ControlDesk")
	controller = Terminal.spawn(geo, Vector3(5.4, 1.0, -16.6), 0, "DOOR & LIFT CONTROL", db, terminal_ui)
	controller.name = "ControlTerminal"
	controller.puzzles = [login_puzzle]
	controller.boot_lines = [
		"HALCYON DOOR AND LIFT CONTROL  -  PLANT 10",
		"Contractors: log in first. contractor_log. Doors: doors.",
	]
	controller.queried.connect(_on_query.bind("controller"))
	# A value typed without its quotes reads as a column name: SYSOP says why, in
	# place of the usual "that column isn't in the table".
	controller.blanks = {"WO": TEXT.tip_quotes, data.ticket.replace("-", ""): TEXT.tip_quotes, "Byte": TEXT.tip_quotes}
	var board := Document.place(geo, Vector3(6.6, 1.0, -16.6), 0, "Contractor log", _clipboard_lines(), true, "clipboard")
	board.clues = [{"case": "login", "opens": TEXT.case_login, "tables": ["contractor_log"], "text": "The clipboard by the controller: all contractors log in on the controller before touching anything."}]
	board.read_by.connect(func(_p): sync.event("_ask_login"))
	# The clock over the door, on the room's side: the time the crew logs in with.
	Greybox.label(geo, Vector3(CTRL_DOOR_AT.x, 2.6, -10.12), data.time_in, 48, Color(1.0, 0.25, 0.15), 0).name = "Clock"
	# Lift controller cabinets along the east wall.
	for z in [-16.5, -14.5, -12.5]:
		Greybox.box(geo, Vector3(9.5, 1.1, z), Vector3(0.8, 2.2, 1.6), Color(0.32, 0.34, 0.38), "LiftController")


## The clipboard by the controller: the log's columns, the earlier jobs in a clerk's
## hand, and the clerk's crib for typing one in (another contractor's, so it shows
## the shape without the crew's own values).
func _clipboard_lines() -> Array:
	var lines: Array = [
		"CONTRACTOR LOG  -  PLANT 10",
		"ALL CONTRACTORS LOG IN BEFORE TOUCHING ANYTHING.  - Facilities",
		{"columns": ["COMPANY", "JOB", "TIME IN"], "widths": [2.6, 1.6, 1.2]},
	]
	for row in data.log:
		lines.append({"row": row, "hand": true})
	var ex: Array = data.example_log
	lines.append({"text": "on the controller now, not on paper:", "hand": true})
	lines.append({"text": "INSERT INTO contractor_log VALUES ('%s', '%s', '%s');" % ex, "hand": true})
	lines.append({"text": "text goes in 'quotes'. same order as the columns.", "hand": true})
	return lines


func _build_bay(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(-5, 0, -14), Vector3(10, 3.5, 8), {"floor": Color(0.22, 0.23, 0.25), "wall": colors.wall.darkened(0.2)}, [
		{"wall": "s", "at": 0.0, "width": 3.0, "height": 2.8},
	])
	Greybox.label(geo, Vector3(BAY_DOOR_AT.x, 3.1, -9.88), "CHARGING BAY", 40, Color(0.85, 0.7, 0.2), 180)
	Document.place(geo, Vector3(BAY_DOOR_AT.x + 2.0, 1.5, -9.88), 180, "Bay sign", BAY_SIGN_LINES, false, "laminated", Vector2(0.3, 0.2))
	bay_door = add_door("PLANT-BAY", BAY_DOOR_AT, Vector3(3.0, 2.8, 0.12))
	# The charging cradle against the back wall.
	Greybox.box(geo, Vector3(-5, 0.2, -17.2), Vector3(2.4, 0.4, 1.2), Color(0.2, 0.2, 0.22), "Cradle")
	Greybox.box(geo, Vector3(-5, 1.6, -17.8), Vector3(1.6, 2.4, 0.3), Color(0.25, 0.25, 0.28), "Charger")


func apply_environment(env: Environment) -> void:
	env.ambient_light_energy = 0.07
	env.fog_density = 0.035


func start() -> void:
	stair_in.set_open(true, true)  # wedged open for the plant work
	maint.ensure_booted()
	controller.ensure_booted()
	_show_lamps()
	hud.todo(TEXT.todo_arrive)


# --- Terminals -------------------------------------------------------------------

func puzzles() -> Array:
	return [reset_puzzle, check_puzzle, login_puzzle]


func _on_query(sql: String, result: Dictionary, _ui: TerminalUI, which: String) -> void:
	var lower := sql.to_lower()
	var changed := int(result.get("changes", 0))
	if which == "maint":
		if not reset_puzzle.solved and reset_puzzle.matches(db, result):
			sync.event("_on_solved", ["reset"])
		# Read back after the reset: the sign-off.
		elif reset_puzzle.solved and not check_puzzle.solved and changed == 0 and check_puzzle.matches(db, result):
			sync.event("_on_solved", ["check"])
		if changed > 0 and lower.contains("breakers"):
			sync.event("_breakers_changed")
	else:
		if not login_puzzle.solved and login_puzzle.matches(db, result):
			sync.event("_on_solved", ["login"])
	# SYSOP's tips, each once: text only, and never the answer.
	_tip_if(which == "maint", "first", which)
	var is_update := lower.strip_edges().begins_with("update")
	var is_insert := lower.strip_edges().begins_with("insert")
	_tip_if(is_update and changed == 0 and result.get("ok", false), "zero", which)
	_tip_if(is_update and lower.contains("breakers") and not lower.contains("where") and changed > 1, "no_where", which)
	_tip_if(which == "maint" and reset_puzzle.solved and not check_puzzle.solved and changed > 0, "verify", which)
	_tip_if(is_insert and lower.contains("contractor_log") and changed > 0 and not login_puzzle.solved and _ticket_in_wrong_column(), "order", which)


## A ticket number in the log's company or time column: the values went in out of order.
func _ticket_in_wrong_column() -> bool:
	return not db.run_silent("SELECT 1 FROM contractor_log WHERE upper(company) = '%s' OR upper(time_in) = '%s'" % [data.ticket, data.ticket]).is_empty()


func _tip_if(when: bool, id: String, which: String) -> void:
	if when and not tips_sent.has(id):
		sync.event("_tip", [id, which])


## Every machine: a line from SYSOP on the screen the query was typed at (once per tip).
func _tip(id: String, which: String) -> void:
	if tips_sent.has(id):
		return
	tips_sent[id] = true
	(maint if which == "maint" else controller).print_line(TerminalUI.sysop(TEXT["tip_" + id]))


## Every machine: a station's check passed.
func _on_solved(id: String) -> void:
	for p in puzzles():
		if p.id == id:
			p.solved = true
	match id:
		"reset":
			_restore_power()
		"check":
			Game.open_case("power", CASES.power, ["breakers"])
			Game.solve_case("power", TEXT.power_done % data.target)
			if not logged_in:
				hud.todo(TEXT.todo_login)
		"login":
			logged_in = true
			Game.open_case("login", CASES.login, ["contractor_log"])
			Game.solve_case("login", TEXT.login_done % [data.company, data.ticket, data.time_in])
			hud.todo("")


## Every machine: the work order has been read. The power case is open.
func _ask_power() -> void:
	Game.open_case("power", CASES.power, ["breakers"])
	if not power_back and not alarm:
		hud.todo(TEXT.todo_power)


## Every machine: the contractor clipboard has been read.
func _ask_login() -> void:
	Game.open_case("login", CASES.login, ["contractor_log"])
	if not logged_in and not alarm:
		hud.todo(TEXT.todo_login)


# --- The breaker panel -------------------------------------------------------------

## Every machine: the breakers table changed. Each lamp follows its row; anything
## other than tonight's breaker that isn't as the panel had it sets the alarm off
## (no WHERE flips the lot), and the charging bay's breaker wakes what's in the bay.
func _breakers_changed() -> void:
	_show_lamps()
	var wrong := false
	var bay_on := false
	for row in db.run_silent("SELECT id, state FROM breakers"):
		var id := str(row["id"])
		if id != data.target and str(row["state"]) != str(data.start_states.get(id, "")):
			wrong = true
		if id == data.bay_breaker and str(row["state"]) == "on":
			bay_on = true
	if wrong != alarm:
		alarm = wrong
		hud.notice(TEXT.alarm if alarm else TEXT.alarm_over, 5.0, ThemeUtil.RED if alarm else ThemeUtil.AMBER)
		if alarm:
			hud.todo(TEXT.todo_put_back)
		elif not power_back:
			hud.todo(TEXT.todo_power)
		elif not logged_in:
			hud.todo(TEXT.todo_login)
		else:
			hud.todo("")
	if bay_on != bay_powered:
		bay_powered = bay_on
		db.run_silent("UPDATE lights SET is_on = %d WHERE id = 'L10-BAY'" % int(bay_on))
		db.sync_world()
		hud.notice(TEXT.bay_stirs if bay_on else TEXT.bay_quiet, 5.0)
	# Tonight's breaker on by any route (the lot flipped, say) still restores the
	# power; the station passes once the rest are back as well.
	if not power_back and not db.run_silent("SELECT 1 FROM breakers WHERE id = '%s' AND state = 'on'" % data.target).is_empty():
		_restore_power()


func _show_lamps() -> void:
	for row in db.run_silent("SELECT id, state FROM breakers"):
		var lamp: MeshInstance3D = lamps.get(str(row["id"]))
		if lamp:
			var on := str(row["state"]) == "on"
			lamp.material_override = Greybox.mat(Color(0.2, 1.0, 0.3) if on else Color(1.0, 0.25, 0.1), 2.0)


## Every machine: PLANT CONTROL has power again. The control room's lights come on
## and its door's actuator works: unlocked in the table, it opens.
func _restore_power() -> void:
	if power_back:
		return
	power_back = true
	db.run_silent("UPDATE lights SET is_on = 1, status = 'ok' WHERE id = 'L10-CTRL'")
	db.run_silent("UPDATE doors SET actuator_fault = 0 WHERE id = 'PLANT-CTRL'")
	db.sync_world()
	hud.notice(TEXT.power_back, 5.0)
	if not alarm and not check_puzzle.solved:
		hud.todo("")


func on_player_died() -> void:
	player.respawn(spawn_point())
