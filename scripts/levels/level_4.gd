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
##               anything. The crew INSERTs its own job (practised safely). Until it
##               has, no terminal on 10 takes a write to the doors table.
##   3. main_doors  the night-mode card says main_doors lets a crew out at night. Its
##               row says zone CONTAINMENT, for a crew that looks first. Opening it is
##               the accident: the entities get out, the Custodian leaves its bay,
##               WARDEN announces Containment protocol Epsilon, and STAIR 1 releases.
##      gantry   the control room's second way in: the gantry arm on the hall's ceiling
##               rail, moved by UPDATE to the bay under the high access panel. Then a
##               teammate's shoulders from its platform (fast), or raise it and climb
##               its mast (solo), or move and raise in one row change (advanced).
##   4. lockout  optional, under pressure: lock out the charging bay's breaker
##               (INSERT) and read it back at the bay's own panel within 30 seconds
##               (the two-terminal teaser). The Custodian goes dark for good.
## Why a careful crew still opens main_doors is a story call (Voice drafts, Augustine
## decides). Until then the build's default: STAIR 1's night release IS main_doors,
## so it's the only way on.
## Write stations are StatePuzzles: checked by the table's state after the write,
## as a result set, never by the query's text.
## Every line players read is a draft in plan/approvals/l4-text.md until Augustine
## approves it word for word.
##
## Layout (level space, north is -z):
##   lift lobby       x -4..4,   z 4..8     stairs in (west wall), stairs down (east wall)
##   switchgear hall  x -10..10, z -10..4   breaker panel on the west wall, the plant
##                                          maintenance terminal, a 6 m ceiling, the
##                                          gantry's rail along the north wall
##   control room     x 2..10,   z -18..-10 the door and lift controller, its clipboard;
##                                          the access panel high in its south wall
##   charging bay     x -10..0,  z -18..-10 the Custodian's, behind a sealed roll-up door;
##                                          its own panel terminal, and the night guard
##                                          it took on Tuesday
##
## Co-op: the host decides (puzzle checks, what a write sets off) and every machine
## plays it out through sync.event.

## Fired once the crew is on the stairs down: the floor is done.
signal completed

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
	"todo_down": "STAIR 1 is open. Everyone down the stairs",
	"case_main_doors": "What did main_doors open?",
	"main_doors_done": "main_doors was never the front door. Its row said so: zone CONTAINMENT. Look at a row before you write to it.",
	"accident": "Far below, something heavy unlocks. Then every light on the floor goes red.",
	"bay_opens": "The charging bay's door rolls up on its own.",
	"stairs_release": "Out by the lifts, the stair door's lock clacks open.",
	"case_seal": "Can the Custodian be shut in its bay?",
	"seal_done": "The CHARGING BAY breaker, %s, is locked out and read back. The Custodian is dark for good.",
	"lockout_logged": "Lockout logged. Read it back at the bay's panel within %d seconds.",
	"lockout_lapsed": "The lockout lapsed: nobody read it back in time.",
	"sealed": "The Custodian's light goes out. It doesn't move again.",
	"power_cut": "The Custodian's light dies. It sags where it stands.",
	"power_returns": "The bay breaker snaps back on. Its light comes back.",
	"refused_login": "DOOR AND LIFT CONTROL: NO CONTRACTOR LOGGED IN. LOG IN FIRST (contractor_log).",
	"stairs_wait": "Waiting for everyone on the stairs (%d/%d)",
	"gantry_moves": "Overhead, the gantry hums along its rail.",
	"gantry_docks": "The gantry docks under the access panel. Its latch lets go and the panel slides up.",
	"gantry_undocks": "The access panel drops shut behind the gantry.",
	"gantry_interlock": "GANTRY 10: INTERLOCK. LOWER THE ARM (raised = 0) BEFORE IT TRAVELS.",
	"gantry_no_bay": "GANTRY 10: NO SUCH POSITION. bay IS 1 TO 4. raised IS 0 (DOWN) OR 1 (UP).",
	"gantry_bolted": "GANTRY 10: GA-1 IS BOLTED TO THE RAIL. IT CAN'T BE REMOVED.",
	"manual_release": "Pull the manual release",
	"released": "The door's manual release gives. It shoves open.",
	"end_card": "To be continued.",
	# SYSOP tips (text only, never lies; each fires once per run).
	"tip_first": "the breakers are rows. the work order names a circuit. find its row first, then change only that one.",
	"tip_no_where": "that changed every row. UPDATE without WHERE does that. put the others back the same way, one WHERE at a time.",
	"tip_zero": "0 rows changed: your WHERE matched nothing. look at the row first: SELECT * FROM breakers;",
	"tip_verify": "the terminal said it changed. did it? read it back.",
	"tip_order": "that row went in, but its values are in the wrong columns. they line up with the columns you named: company, job, time_in.",
	"tip_count": "the log has four columns and log_no fills itself in. name the three you're filling: (company, job, time_in).",
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
## The night-mode card in the control room: the papers' name for the way out. It is
## wrong, and the row it names says so (zone CONTAINMENT) to anyone who reads it.
const NIGHT_CARD_LINES := [
	"NIGHT MODE  -  DOOR AND LIFT CONTROL",
	"After 19:00 the controller holds the exterior and stair doors.",
	"To let a contractor crew out at night: open main_doors.",
	"STAIR 1 then releases down to G.",
	{"text": "doors table. locked = 0 is open  - Facilities", "hand": true},
]
## The earlier copy of the warning, pinned in the control room among the shift's
## papers: an observant crew reads it before the accident.
const WARNING := "Note for security: Never open main_doors."
## The lockout/tagout card by the breaker panel: where the bay's seal is found.
const LOCKOUT_LINES := [
	"LOCKOUT / TAGOUT  -  PLANT 10",
	"Working on anything a breaker feeds? Lock it out first.",
	"1. Log it on the controller: lockouts (breaker, company, job).",
	"2. A second person reads it back at the panel it covers within 30 seconds, or it lapses.",
	"A locked-out breaker stays off until Facilities clears it.",
]
## The gantry arm: its rail runs along the hall's north wall. Bay positions west to
## east (level space x); the bays are numbered from one end or the other (seeded),
## so the access panel over the east end is bay 4 or bay 1.
const GANTRY_X := [-8.5, -1.5, 3.0, 8.5]
const GANTRY_Z := -9.3
## The platform's top, lowered (a step up) and raised (level with the panel's sill).
const GANTRY_LOW := 0.3
const GANTRY_HIGH := 3.65
## The high access panel, through the wall into the control room (its centre).
## Crouch-high: you duck through it.
const HATCH_AT := Vector3(8.5, 4.35, -10)
const HATCH_SIZE := Vector3(1.0, 1.4, 0.12)
## The gantry card, on the wall by where it parks: where the second route is found.
const GANTRY_CARD := [
	"GANTRY ARM GA-1  -  PLANT 10",
	"Service platform on the ceiling rail. Controlled from the plant terminal: gantry.",
	"Bay %d: parking.   Bay %d: the access panel to door and lift control.",
	{"text": "to the riser fans' bay: UPDATE gantry SET bay = 3 WHERE id = 'GA-1';", "hand": true},
	{"text": "raised = 1 takes the platform up to the panel. numbers, no quotes!", "hand": true},
	"Do not ride the platform while it travels.",
]
## How long a lockout waits to be read back at the bay's panel.
const LOCKOUT_WINDOW := 30.0
## How long the bay's breaker stays off before WARDEN puts it back (unless locked out).
const POWER_CUT_TIME := 10.0
const CASES := {"power": TEXT.case_power, "login": TEXT.case_login, "main_doors": TEXT.case_main_doors, "seal": TEXT.case_seal}

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
## The control room and the bay, for tests and the art pass.
const CTRL_ROOM := AABB(Vector3(2, -0.5, -18), Vector3(8, 3.5, 8))
const BAY_ROOM := AABB(Vector3(-10, -0.5, -18), Vector3(10, 4, 8))
## The Custodian's cradle in the bay, and its rounds once it's loose (level space).
const CUSTODIAN_HOME := Vector3(-5, 0, -15.8)
const ROAM_POINTS := [Vector3(-5, 0, -7), Vector3(5, 0, -7), Vector3(0, 0, -1), Vector3(-6, 0, 2.5), Vector3(4, 0, -4), Vector3(0, 0, 6)]

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
var bay_terminal: Terminal
var custodian: Custodian
var exit_trigger: Trigger
## main_doors is open: the accident has happened.
var accident := false
## Someone read the earlier warning before the accident (peer ids).
var warned_early := {}
## A lockout row for the bay is waiting to be read back, until this (msec, host).
var lockout_until := 0
var sealed := false
## LOCKOUT_WINDOW and POWER_CUT_TIME, here so tests can shorten the wait.
var lockout_window := LOCKOUT_WINDOW
var power_cut_time := POWER_CUT_TIME
## Bumped each time the bay's power is cut, so a stale restore does nothing.
var _cut := 0
var gantry: AnimatableBody3D
var gantry_mast: MovementVolume
var hatch: Door
var release: Interactable
## Where the gantry is, as the world has it (every machine): what its interlock goes by.
var gantry_at := {"bay": 0, "raised": 0}
var _gantry_tween: Tween
## The SYSOP tips that have fired this run (every machine).
var tips_sent := {}

## Puzzle stations. Built with the data (the breaker and the job vary per run).
## Ladder A for each: the shape with the value as ?, how to find it, the exact query.
var reset_puzzle: StatePuzzle
var check_puzzle: Puzzle
var login_puzzle: StatePuzzle
var main_doors_puzzle: StatePuzzle
var lockout_puzzle: StatePuzzle
var readback_puzzle: Puzzle
var gantry_puzzle: StatePuzzle


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
	_build_gantry()

	# Lights follow the `lights` table (sync_world): control room and bay are dark.
	add_light("L10-LOBBY", Vector3(0, 3.2, 6), 6.0, 0.9)
	for z in [-7.0, 0.0]:
		for x in [-5.0, 5.0]:
			add_light("L10-HALL", Vector3(x, 6.0, z), 9.0, 0.9, Color(0.95, 0.95, 0.85))
	add_light("L10-CTRL", Vector3(6, 5.4, -14), 7.0, 0.9)
	add_light("L10-BAY", Vector3(-5, 3.5, -14), 7.0, 0.6, Color(0.6, 0.8, 1.0))

	spawn = _stair_landing(STAIR_IN_AT, 90.0)
	exit_trigger = Trigger.create(self, STAIR_OUT_AT + Vector3(2.4, 1, 0), Vector3(2.8, 2, 3.2))
	exit_trigger.name = "StairsDown"
	exit_trigger.require_all = true
	exit_trigger.waiting.connect(func(n, total): sync.team_notice(TEXT.stairs_wait % [n, total]))
	exit_trigger.entered.connect(func(_b): sync.event("_on_exit"), CONNECT_ONE_SHOT)

	custodian = Custodian.new()
	custodian.name = "Custodian"
	custodian.space = self
	custodian.home = CUSTODIAN_HOME
	custodian.roam_points.assign(ROAM_POINTS)
	custodian.position = CUSTODIAN_HOME  # before add_child: a body at the origin for a step can set off triggers
	add_child(custodian)
	custodian.rotation_degrees.y = 0.0
	# Every terminal on 10 sees the building's database through the floor's rules.
	var guarded := GuardedDB.over(db, _guard, _gantry_check)
	for term in [maint, controller, bay_terminal]:
		term.db = guarded


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
	login_puzzle = StatePuzzle.new("login", "INSERT INTO contractor_log (company, job, time_in) VALUES %s" % who,
		"SELECT COUNT(*) > 0 AS logged FROM contractor_log WHERE lower(trim(company)) = lower('%s') AND upper(trim(job)) = '%s' AND trim(time_in) = '%s'" % [data.company, data.ticket, data.time_in],
		"SELECT 1 AS logged", ["logged"], [
		"the shape, with your job and the time left as ?:\n" +
		"    [color=#ffffff]INSERT INTO contractor_log (company, job, time_in) VALUES ('%s', '?', '?');[/color]\n" % data.company +
		"  INSERT INTO contractor_log   add a new row to the contractor log\n" +
		"  (company, job, time_in)   the columns you're filling. log_no fills itself in\n" +
		"  VALUES (...)   the new row's values, in the same order as those columns\n" +
		"  '...'   every value in single quotes\n" +
		"the first ? is your work order's number. the second ? is the time on the clock over this room's door.",
		"open your notebook (Tab): the work order's number is printed at the top, WO- and five digits. the clock over the door reads hours:minutes.",
		"type this, then Enter:\n" +
		"    [color=#ffffff]INSERT INTO contractor_log (company, job, time_in) VALUES %s;[/color]\n" % who +
		"then read the log back: SELECT * FROM contractor_log;",
	])
	login_puzzle.case_id = "login"
	main_doors_puzzle = StatePuzzle.new("main_doors", "UPDATE doors SET locked = 0 WHERE id = 'main_doors'",
		"SELECT locked FROM doors WHERE id = 'main_doors'", "SELECT 0 AS locked", ["locked"], [
		"the shape, with the door left as ?:\n" +
		"    [color=#ffffff]UPDATE doors SET locked = 0 WHERE id = '?';[/color]\n" +
		"  UPDATE doors   change rows in the doors table\n" +
		"  SET locked = 0   0 is open, 1 is locked\n" +
		"  WHERE id = '?'   only that door. ? is the one the night-mode card names",
		"the night-mode card on the wall here names the door that lets a crew out at night. read its row first: SELECT * FROM doors;",
		"type this, then Enter:\n" +
		"    [color=#ffffff]UPDATE doors SET locked = 0 WHERE id = 'main_doors';[/color]\n",
	])
	main_doors_puzzle.case_id = "main_doors"
	var lock_row := "('%s', '%s', '%s')" % [data.bay_breaker, data.company, data.ticket]
	lockout_puzzle = StatePuzzle.new("lockout", "INSERT INTO lockouts (breaker, company, job) VALUES %s" % lock_row,
		"SELECT COUNT(*) > 0 AS locked_out FROM lockouts WHERE upper(trim(breaker)) = '%s' AND lower(trim(company)) = lower('%s') AND upper(trim(job)) = '%s'" % [data.bay_breaker, data.company, data.ticket],
		"SELECT 1 AS locked_out", ["locked_out"], [
		"the shape, with the breaker and your job left as ?:\n" +
		"    [color=#ffffff]INSERT INTO lockouts (breaker, company, job) VALUES ('?', '%s', '?');[/color]\n" % data.company +
		"  INSERT INTO lockouts   add a lockout\n" +
		"  (breaker, company, job)   the columns you're filling\n" +
		"  VALUES (...)   the values, in the same order\n" +
		"the first ? is the charging bay's breaker id. the second ? is your work order's number.",
		"type\n" +
		"    [color=#ffffff]SELECT * FROM breakers;[/color]\n" +
		"the CHARGING BAY row's id is the first ?. then someone reads the lockout back at the bay's own panel, fast.",
		"type this, then Enter:\n" +
		"    [color=#ffffff]INSERT INTO lockouts (breaker, company, job) VALUES %s;[/color]\n" % lock_row +
		"then, at the panel in the bay, within 30 seconds: SELECT * FROM lockouts;",
	])
	lockout_puzzle.case_id = "seal"
	# The read-back at the bay's panel: the lockouts table, or the bay's own row.
	# SELECT * is long practised: the review ladder (the shape with ?, then the query).
	readback_puzzle = Puzzle.new("readback", "SELECT breaker, company, job FROM lockouts", ["breaker", "company", "job"], false, [
		"the shape, with the table left as ?:\n" +
		"    [color=#ffffff]SELECT * FROM ?;[/color]\n" +
		"? is the lockout log's table: its name is on the lockout card by the breaker panel.",
		"type this, then Enter, within 30 seconds of logging the lockout:\n" +
		"    [color=#ffffff]SELECT * FROM lockouts;[/color]",
	])
	readback_puzzle.accept_also("SELECT breaker, company, job FROM lockouts WHERE breaker = '%s'" % data.bay_breaker, ["breaker", "company", "job"], false)
	readback_puzzle.case_id = "seal"
	var hb: int = data.hatch_bay
	gantry_puzzle = StatePuzzle.new("gantry", "UPDATE gantry SET bay = %d WHERE id = 'GA-1'" % hb,
		"SELECT bay FROM gantry WHERE id = 'GA-1'", "SELECT %d AS bay" % hb, ["bay"], [
		"the shape, with the bay left as ?:\n" +
		"    [color=#ffffff]UPDATE gantry SET bay = ? WHERE id = 'GA-1';[/color]\n" +
		"  UPDATE gantry   change the gantry arm's row\n" +
		"  SET bay = ?   move it to that bay. ? is a number: no quotes\n" +
		"  WHERE id = 'GA-1'   only the arm GA-1\n" +
		"? is the bay under the access panel: the gantry card on the north wall says which.",
		"read the gantry card by where the arm parks: it numbers the bays and names the one under the access panel. or type\n" +
		"    [color=#ffffff]SELECT * FROM gantry;[/color]\n" +
		"to see where the arm is now.",
		"type this, then Enter:\n" +
		"    [color=#ffffff]UPDATE gantry SET bay = %d WHERE id = 'GA-1';[/color]\n" % hb +
		"then get a teammate onto your shoulders from its platform, or raise it and climb: UPDATE gantry SET raised = 1 WHERE id = 'GA-1';",
	])


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
	Greybox.room(geo, Vector3(0, 0, -3), Vector3(20, 6.0, 14), {"floor": colors.floor, "wall": colors.wall, "ceiling": Color(0.32, 0.33, 0.33)}, [
		{"wall": "s", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "n", "at": CTRL_DOOR_AT.x, "width": 1.6, "height": 2.4},
		{"wall": "n", "at": BAY_DOOR_AT.x, "width": 3.0, "height": 2.8},
		{"wall": "n", "at": HATCH_AT.x, "width": HATCH_SIZE.x, "height": HATCH_AT.y + HATCH_SIZE.y / 2, "bottom": HATCH_AT.y - HATCH_SIZE.y / 2},
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
	var card := Document.place(geo, Vector3(-9.6, 1.6, -0.4), 90.0, "Lockout card", LOCKOUT_LINES, false, "laminated", Vector2(0.3, 0.3))
	card.clues = [{"case": "seal", "opens": TEXT.case_seal, "tables": ["lockouts", "breakers"], "text": "The lockout card: a locked-out breaker stays off. Log it on the controller, then read it back at the panel it covers within 30 seconds."}]
	# The plant maintenance desk, facing the panel's end: its terminal and the work order.
	Greybox.box(geo, Vector3(-6, 0.5, 1.6), Vector3(2.4, 1.0, 0.8), Color(0.4, 0.38, 0.34), "MaintDesk")
	maint = Terminal.spawn(geo, Vector3(-6.5, 1.0, 1.6), 0, "PLANT MAINT", db, terminal_ui)
	maint.name = "MaintTerminal"
	maint.puzzles = [reset_puzzle, check_puzzle, gantry_puzzle]
	maint.boot_lines = [
		"HALCYON FACILITIES  -  PLANT 10  -  MAINTENANCE",
		"Breaker panel: breakers. One row per breaker box.",
	]
	maint.queried.connect(_on_query.bind("maint"))
	var wo := Document.place(geo, Vector3(-5.3, 1.0, 1.6), 0, "Facilities work order", WORK_ORDER_LINES, true, "clipboard")
	wo.clues = [{"case": "power", "opens": TEXT.case_power, "tables": ["breakers"], "text": "Facilities' work order: Tuesday's power event tripped the PLANT CONTROL breaker. Reset it, then check it took."}]
	wo.read_by.connect(func(_p): sync.event("_ask_power"))
	# Cable trays and ducts overhead, a transformer cage in the south-east corner.
	# (Clear of the gantry's rail and anyone on its mast, along the north wall.)
	for z in [-6.5, -1.0]:
		Greybox.box(geo, Vector3(0, 4.6, z), Vector3(18, 0.15, 0.6), Color(0.45, 0.45, 0.42), "CableTray")
	Greybox.box(geo, Vector3(7.5, 1.2, 1.5), Vector3(3.0, 2.4, 3.0), Color(0.3, 0.34, 0.32), "Transformer")
	Greybox.label(geo, Vector3(7.5, 2.0, -0.02), "DANGER  480V", 36, Color(0.9, 0.75, 0.1), 180)


func _build_control_room(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(6, 0, -14), Vector3(8, 5.4, 8), {"floor": Color(0.25, 0.26, 0.28), "wall": colors.wall}, [
		{"wall": "s", "at": 0.0, "width": 1.6, "height": 2.4},
		{"wall": "s", "at": HATCH_AT.x - 6.0, "width": HATCH_SIZE.x, "height": HATCH_AT.y + HATCH_SIZE.y / 2, "bottom": HATCH_AT.y - HATCH_SIZE.y / 2},
	])
	Greybox.label(geo, Vector3(CTRL_DOOR_AT.x, 2.75, -9.88), "DOOR AND LIFT CONTROL", 32, Color(0.8, 0.8, 0.72), 180)
	Document.place(geo, Vector3(CTRL_DOOR_AT.x + 1.3, 1.5, -9.88), 180, "Control room sign", CTRL_SIGN_LINES, false, "laminated", Vector2(0.3, 0.2))
	# A powered sliding door: unlocked in the doors table, but no power to its actuator.
	ctrl_door = add_door("PLANT-CTRL", CTRL_DOOR_AT, Vector3(1.6, 2.4, 0.12))
	# Inside, by the door: its manual release. A powered door always lets you out.
	release = Interactable.create(self, Vector3(CTRL_DOOR_AT.x - 1.1, 1.2, -10.2), Vector3(0.12, 0.3, 0.1), TEXT.manual_release, Color(0.75, 0.15, 0.1))
	release.name = "ManualRelease"
	release.used.connect(func(_p): sync.event("_manual_release"))
	# The controller on its desk, with the contractor clipboard beside it.
	Greybox.box(geo, Vector3(6, 0.5, -16.6), Vector3(3.0, 1.0, 0.8), Color(0.38, 0.38, 0.4), "ControlDesk")
	controller = Terminal.spawn(geo, Vector3(5.4, 1.0, -16.6), 0, "DOOR & LIFT CONTROL", db, terminal_ui)
	controller.name = "ControlTerminal"
	controller.puzzles = [login_puzzle, main_doors_puzzle, lockout_puzzle]
	controller.boot_lines = [
		"HALCYON DOOR AND LIFT CONTROL  -  PLANT 10",
		"Contractors: log in first. contractor_log. Doors: doors.",
	]
	controller.queried.connect(_on_query.bind("controller"))
	# A value typed without its quotes reads as a column name: SYSOP says why, in
	# place of the usual "that column isn't in the table".
	# And the plain VALUES form, without the column list, is a value short.
	controller.blanks = {"WO": TEXT.tip_quotes, data.ticket.replace("-", ""): TEXT.tip_quotes, "Byte": TEXT.tip_quotes,
		"contractor_log": TEXT.tip_count}
	var board := Document.place(geo, Vector3(6.6, 1.0, -16.6), 0, "Contractor log", _clipboard_lines(), true, "clipboard")
	board.clues = [{"case": "login", "opens": TEXT.case_login, "tables": ["contractor_log"], "text": "The clipboard by the controller: all contractors log in on the controller before touching anything."}]
	board.read_by.connect(func(_p): sync.event("_ask_login"))
	# The clock over the door, on the room's side: the time the crew logs in with.
	Greybox.label(geo, Vector3(CTRL_DOOR_AT.x, 2.6, -10.12), data.time_in, 48, Color(1.0, 0.25, 0.15), 0).name = "Clock"
	# The night-mode card on the wall by the desk, and the shift's papers pinned on a
	# board beside it: among them, the earlier copy of the warning.
	Document.place(geo, Vector3(3.5, 1.5, -17.88), 0, "Night mode card", NIGHT_CARD_LINES, false, "laminated", Vector2(0.3, 0.24))
	Greybox.box(geo, Vector3(8.0, 1.6, -17.92), Vector3(1.4, 0.9, 0.04), Color(0.55, 0.42, 0.28), "Corkboard")
	Document.place(geo, Vector3(7.6, 1.75, -17.88), 0, "Shift roster", ["PLANT 10  -  ON CALL", "Mon-Wed: R. Okonkwo, ext. 4410", "Thu-Sun: Facilities desk, ext. 2200"], false, "paper", Vector2(0.21, 0.15))
	var warning := Document.place(geo, Vector3(8.45, 1.55, -17.88), 0, "Sticky note", [{"text": WARNING, "hand": true}], false, "sticky")
	warning.name = "EarlyWarning"
	warning.read_by.connect(func(p): sync.event("_warning_read", [players.id_of(p)]))
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
		{"columns": ["NO.", "COMPANY", "JOB", "TIME IN"], "widths": [0.6, 2.4, 1.5, 1.0]},
	]
	for i in data.log.size():
		lines.append({"row": [str(i + 1)] + data.log[i], "hand": true})
	var ex: Array = data.example_log
	lines.append({"text": "on the controller now, not on paper:", "hand": true})
	lines.append({"text": "INSERT INTO contractor_log (company, job, time_in) VALUES ('%s', '%s', '%s');" % ex, "hand": true})
	lines.append({"text": "text goes in 'quotes'. values in the same order as the columns. the log no. fills itself in.", "hand": true})
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
	# The bay's own panel, by the door: where a lockout is read back.
	Greybox.box(geo, Vector3(-1.2, 0.5, -11.2), Vector3(1.2, 1.0, 0.7), Color(0.38, 0.38, 0.4), "BayDesk")
	bay_terminal = Terminal.spawn(geo, Vector3(-1.2, 1.0, -11.2), 0, "BAY 10 PANEL", db, terminal_ui)
	bay_terminal.name = "BayTerminal"
	bay_terminal.puzzles = [readback_puzzle]
	bay_terminal.boot_lines = [
		"HALCYON FACILITIES  -  CHARGING BAY 10",
		"Lockouts: lockouts. Read a new lockout back here to make it count.",
	]
	bay_terminal.queried.connect(_on_query.bind("bay"))
	# The night guard it took on Tuesday, in the corner behind the cradle. His copy of
	# the note is still in his hand.
	Greybox.box(geo, Vector3(-8.6, 0.15, -16.6), Vector3(0.5, 0.3, 1.7), Color(0.12, 0.15, 0.25), "NightGuard")
	Greybox.box(geo, Vector3(-8.6, 0.2, -15.6), Vector3(0.3, 0.25, 0.3), Color(0.55, 0.45, 0.4), "NightGuardHead")
	var his := Document.place(geo, Vector3(-8.2, 0.31, -16.4), 0, "Sticky note", [{"text": WARNING, "hand": true}], true, "sticky")
	his.name = "GuardsWarning"
	his.clues = [{"case": "main_doors", "text": "On the dead guard in the bay: \"%s\"" % WARNING}]


func net_setup() -> void:
	custodian.crew = crew
	sync.replicate(custodian, custodian.sync_properties())


func apply_environment(env: Environment) -> void:
	env.ambient_light_energy = 0.07
	env.fog_density = 0.035


func start() -> void:
	stair_in.set_open(true, true)  # wedged open for the plant work
	maint.ensure_booted()
	controller.ensure_booted()
	bay_terminal.ensure_booted()
	_show_lamps()
	if completed.get_connections().is_empty():
		completed.connect(_on_completed)
	hud.todo(TEXT.todo_arrive)


# --- Terminals -------------------------------------------------------------------

func puzzles() -> Array:
	return [reset_puzzle, check_puzzle, login_puzzle, main_doors_puzzle, lockout_puzzle, readback_puzzle, gantry_puzzle]


## The floor's rule in front of every write (GuardedDB): no door writes before a
## contractor has logged in.
func _guard(sql: String) -> String:
	if GuardedDB.is_write(sql) and not logged_in and sql.to_lower().contains("doors"):
		return TEXT.refused_login
	return ""


func _on_query(sql: String, result: Dictionary, _ui: TerminalUI, which: String) -> void:
	var lower := sql.to_lower()
	var changed := int(result.get("changes", 0))
	if which == "maint":
		if not reset_puzzle.solved and reset_puzzle.matches(db, result):
			sync.event("_on_solved", ["reset"])
		# Read back after the reset: the sign-off.
		elif reset_puzzle.solved and not check_puzzle.solved and changed == 0 and check_puzzle.matches(db, result):
			sync.event("_on_solved", ["check"])
	elif which == "controller":
		if not login_puzzle.solved and login_puzzle.matches(db, result):
			sync.event("_on_solved", ["login"])
	elif which == "bay":
		if lockout_until > 0 and not sealed and readback_puzzle.matches(db, result) and _has_lockout():
			sync.event("_seal")
	# Any terminal: a breaker write lights the lamps (and, loose, cuts the Custodian's
	# power); a write that leaves main_doors open is the accident; one that logs the
	# bay's lockout starts its read-back clock.
	if changed > 0 and lower.contains("breakers"):
		sync.event("_breakers_changed")
	if changed > 0 and lower.contains("gantry"):
		if not gantry_puzzle.solved and gantry_puzzle.matches(db, result):
			sync.event("_on_solved", ["gantry"])
		sync.event("_gantry_changed")
	if changed > 0 and not accident and main_doors_puzzle.state_ok(db):
		sync.event("_on_solved", ["main_doors"])
	if changed > 0 and lower.contains("lockouts") and not sealed and lockout_until == 0 and _has_lockout():
		sync.event("_lockout_logged")
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
	_terminal(which).print_line(TerminalUI.sysop(TEXT["tip_" + id]))


func _terminal(which: String) -> Terminal:
	return {"maint": maint, "controller": controller, "bay": bay_terminal}.get(which, controller)


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
		"main_doors":
			_accident()


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


# --- The gantry arm -------------------------------------------------------------------

func _build_gantry() -> void:
	# The rail along the hall's ceiling, the bays' plates on the north wall under it.
	Greybox.box(geo, Vector3(0, 5.85, GANTRY_Z), Vector3(19.5, 0.2, 0.35), Color(0.5, 0.45, 0.2), "GantryRail")
	for bay in range(1, 5):
		Greybox.label(geo, Vector3(_bay_x(bay), 3.0, -9.88), "BAY %d" % bay, 40, Color(0.9, 0.75, 0.1), 180)
	var park_x := _bay_x(data.park_bay)
	var lines := GANTRY_CARD.duplicate()
	lines[2] = GANTRY_CARD[2] % [data.park_bay, data.hatch_bay]
	Document.place(geo, Vector3(park_x + (1.2 if park_x < 0 else -1.2), 1.6, -9.88), 180, "Gantry card", lines, false, "laminated", Vector2(0.3, 0.24))
	# The carriage: a platform hung from the rail, with a mast to climb on its open side.
	gantry = AnimatableBody3D.new()
	gantry.name = "Gantry"
	gantry.sync_to_physics = true
	gantry.position = Vector3(park_x, GANTRY_LOW, GANTRY_Z)
	add_child(gantry)
	var deck := Vector3(1.2, 0.2, 1.2)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = deck
	mesh.mesh = bm
	mesh.position.y = -deck.y / 2
	mesh.material_override = Greybox.mat(Color(0.75, 0.6, 0.15), 0.0, 0.6)
	gantry.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = deck
	shape.shape = bs
	shape.position.y = -deck.y / 2
	gantry.add_child(shape)
	var hanger := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.12, 6.0, 0.12)
	hanger.mesh = hm
	hanger.position = Vector3(-0.5, 3.0, -0.5)
	hanger.material_override = Greybox.mat(Color(0.3, 0.3, 0.32))
	gantry.add_child(hanger)
	gantry_mast = Traversal.climbable(gantry, Vector3(0, -GANTRY_HIGH, deck.z / 2), Vector3(0, 0, deck.z / 2), Vector3(0, 0, 1), 0.6)
	gantry_mast.name = "GantryMast"
	# The panel, latched shut until the carriage docks under it (not a doors row: it's
	# the gantry's own service hatch).
	hatch = Door.create(self, "PLANT-HATCH", HATCH_AT, HATCH_SIZE, Color(0.4, 0.42, 0.45))
	Greybox.label(geo, HATCH_AT + Vector3(0, HATCH_SIZE.y / 2 + 0.2, 0.12), "ACCESS PANEL", 24, Color(0.85, 0.85, 0.8), 180)
	gantry_at = {"bay": data.park_bay, "raised": 0}
	_place_gantry(gantry.position)


## Level-space x of a bay: numbered from the west end or the east, as the card says.
func _bay_x(bay: int) -> float:
	return GANTRY_X[bay - 1] if data.park_bay == 1 else GANTRY_X[4 - bay]


func _place_gantry(at: Vector3) -> void:
	gantry.position = at
	# The mast's line, in world space, for whoever climbs it.
	gantry_mast.a = gantry.global_transform * Vector3(0, -at.y, 0.6)
	gantry_mast.b = gantry.global_transform * Vector3(0, 0, 0.6)


## GuardedDB's check after a write: the gantry's own controller refuses what it can't
## do, and the write is rolled back. It goes by where the arm really is.
func _gantry_check() -> String:
	var rows := db.run_silent("SELECT bay, raised FROM gantry WHERE id = 'GA-1'")
	if rows.size() != 1:
		return TEXT.gantry_bolted
	var bay = rows[0]["bay"]
	var raised = rows[0]["raised"]
	if typeof(bay) != TYPE_INT or typeof(raised) != TYPE_INT or bay < 1 or bay > 4 or raised < 0 or raised > 1:
		return TEXT.gantry_no_bay
	if int(gantry_at.raised) == 1 and bay != int(gantry_at.bay):
		return TEXT.gantry_interlock
	return ""


## Every machine: the gantry's row changed. It travels first, then lifts (or lowers
## first, then stays: it can't travel raised). Docked at the panel's bay, it unlatches.
func _gantry_changed() -> void:
	var rows := db.run_silent("SELECT bay, raised FROM gantry WHERE id = 'GA-1'")
	if rows.is_empty():
		return
	var bay := int(rows[0]["bay"])
	var raised := int(rows[0]["raised"])
	if bay == int(gantry_at.bay) and raised == int(gantry_at.raised):
		return
	gantry_at = {"bay": bay, "raised": raised}
	if _gantry_tween:
		_gantry_tween.kill()
	_gantry_tween = create_tween()
	_gantry_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var from := gantry.position
	var over := Vector3(_bay_x(bay), from.y, GANTRY_Z)
	var to := Vector3(over.x, GANTRY_HIGH if raised == 1 else GANTRY_LOW, GANTRY_Z)
	if hatch.is_open and bay != data.hatch_bay:
		hatch.set_open(false)
		hud.notice(TEXT.gantry_undocks, 3.0)
	hud.notice(TEXT.gantry_moves, 3.0)
	if not over.is_equal_approx(from):
		_gantry_tween.tween_method(_place_gantry, from, over, maxf(0.5, from.distance_to(over) / 1.5))
	if not to.is_equal_approx(over):
		_gantry_tween.tween_method(_place_gantry, over, to, maxf(0.5, over.distance_to(to) / 1.0))
	_gantry_tween.tween_callback(_gantry_arrived.bind(bay))


func _gantry_arrived(bay: int) -> void:
	if bay == data.hatch_bay and not hatch.is_open:
		hatch.set_open(true)
		hud.notice(TEXT.gantry_docks, 4.0)


## Every machine: someone inside the control room pulled its door's manual release.
func _manual_release() -> void:
	if not ctrl_door.is_open:
		ctrl_door.set_open(true)
		hud.notice(TEXT.released, 3.0)


# --- The breaker panel -------------------------------------------------------------

## The crew's lockout row for the bay is in the table.
func _has_lockout() -> bool:
	return lockout_puzzle.state_ok(db)


# --- The accident --------------------------------------------------------------------

## Every machine: someone read the earlier warning. Before the accident, only that
## reader earns the observant crew's find (draft unlock, held for Augustine).
func _warning_read(peer_id: int) -> void:
	if accident or warned_early.has(peer_id):
		return
	warned_early[peer_id] = true
	sync.unlock_for([peer_id], "achievement:main_doors_warning")


## Every machine: main_doors is open. It was never the front: the containment doors
## release, the charging bay's door rolls up and its breaker comes on, and the
## Custodian leaves its cradle. WARDEN seals the building (Containment protocol
## Epsilon; the approved lines, without the read-only one), and STAIR 1's night
## release lets go (the build's default for why the crew still had to open it).
func _accident() -> void:
	if accident:
		return
	accident = true
	main_doors_puzzle.solved = true
	alarm = false
	db.run_silent("UPDATE doors SET locked = 0 WHERE id = 'PLANT-BAY'")
	db.run_silent("UPDATE breakers SET state = 'on' WHERE id = '%s'" % data.bay_breaker)
	# Epsilon: every door outside the plant locks; containment and the plant stay as they are.
	db.run_silent("UPDATE doors SET locked = 1 WHERE zone NOT IN ('CONTAINMENT', 'P')")
	db.run_silent("UPDATE lights SET is_on = 1, status = 'ok' WHERE id = 'L10-BAY'")
	db.sync_world()
	db.checkpoint()  # a backup tape can't undo it
	_show_lamps()
	bay_powered = true
	set_all_lights_color(Color(1.0, 0.35, 0.3))
	stair_out.locked = false
	Game.open_case("main_doors", CASES.main_doors, ["doors"])
	Game.solve_case("main_doors", TEXT.main_doors_done)
	hud.notice(TEXT.accident, 6.0, ThemeUtil.RED)
	if sync.is_host():
		custodian.wake()
	hud.todo(TEXT.todo_down)
	_epsilon()


## The lockdown announcement over every speaker, then the stair door.
func _epsilon() -> void:
	await get_tree().create_timer(1.5, false).timeout
	hud.notice(TEXT.bay_opens, 4.0)
	for id in ["l4_epsilon_1", "l4_epsilon_2", "l4_epsilon_3"]:
		if VoiceLines.get_line(id).is_empty():
			await get_tree().create_timer(2.0, false).timeout
		else:
			await hud.line(id)
	if is_inside_tree():
		hud.notice(TEXT.stairs_release, 4.0)


# --- The Custodian's bay ---------------------------------------------------------------

## Every machine: the crew's lockout for the bay is logged. It counts once someone
## reads it back at the bay's panel (the two-terminal teaser); it lapses otherwise.
func _lockout_logged() -> void:
	lockout_until = Time.get_ticks_msec() + int(lockout_window * 1000.0)
	Game.open_case("seal", CASES.seal, ["lockouts", "breakers"])
	lockout_puzzle.solved = true
	hud.notice(TEXT.lockout_logged % int(lockout_window), 5.0)
	if sync.is_host():
		_lapse_after(lockout_until)


func _lapse_after(until: int) -> void:
	await get_tree().create_timer(lockout_window, false).timeout
	if is_inside_tree() and not sealed and lockout_until == until:
		sync.event("_lockout_lapsed")


## Every machine: nobody read it back in time. The row comes out; try again.
func _lockout_lapsed() -> void:
	lockout_until = 0
	lockout_puzzle.solved = false
	db.run_silent("DELETE FROM lockouts WHERE upper(trim(breaker)) = '%s' AND read_back IS NULL" % data.bay_breaker)
	hud.notice(TEXT.lockout_lapsed, 4.0)


## Every machine: read back in time. The bay's breaker is held off and the
## Custodian goes dark for good, wherever it is.
func _seal() -> void:
	if sealed:
		return
	sealed = true
	readback_puzzle.solved = true
	lockout_until = 0
	db.run_silent("UPDATE lockouts SET read_back = '%s' WHERE upper(trim(breaker)) = '%s' AND read_back IS NULL" % [data.time_in, data.bay_breaker])
	db.run_silent("UPDATE breakers SET state = 'off' WHERE id = '%s'" % data.bay_breaker)
	_show_lamps()
	custodian.seal()
	Game.solve_case("seal", TEXT.seal_done % data.bay_breaker)
	hud.notice(TEXT.sealed, 5.0)


## Every machine: the bay's breaker went off by a crew's write. It drops whoever it
## holds; WARDEN puts the power back after a while, unless the bay is locked out.
func _bay_power(on: bool) -> void:
	if sealed:
		return
	custodian.set_power(on)
	if on:
		hud.notice(TEXT.power_returns, 3.0)
		return
	_cut += 1
	hud.notice(TEXT.power_cut, 3.0)
	if sync.is_host():
		_restore_after(_cut)


func _restore_after(cut: int) -> void:
	await get_tree().create_timer(power_cut_time, false).timeout
	if is_inside_tree() and not sealed and cut == _cut and not custodian.powered:
		sync.event("_restore_bay")


func _restore_bay() -> void:
	if sealed:
		return
	db.run_silent("UPDATE breakers SET state = 'on' WHERE id = '%s'" % data.bay_breaker)
	_show_lamps()
	_bay_power(true)


# --- The way down ----------------------------------------------------------------------

## Everyone is on the stairs. Until the ground floor is built, the slice ends here.
func _on_exit() -> void:
	if not player or player.health <= 0.0:
		return
	player.input_locked = true
	await get_tree().create_timer(1.0).timeout
	await Level2FX.end_card(self, TEXT.end_card)
	Game.completed_level = "level_4"
	Game.next_level = ""
	completed.emit()


func _on_completed() -> void:
	await hud.fade(true, 1.2)
	finish_level("field_notes")


## Every machine: the breakers table changed. Each lamp follows its row; anything
## other than tonight's breaker that isn't as the panel had it sets the alarm off
## (no WHERE flips the lot), and the charging bay's breaker wakes what's in the bay.
func _breakers_changed() -> void:
	_show_lamps()
	if accident:
		# Loose, the Custodian runs on the bay's circuit: cutting it drops it.
		var on := not db.run_silent("SELECT 1 FROM breakers WHERE id = '%s' AND state = 'on'" % data.bay_breaker).is_empty()
		if on != custodian.powered and not sealed:
			_bay_power(on)
		return
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
