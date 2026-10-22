extends LevelBase
## Level 5: the Personnel Wing, floor 9 ("Faces That Don't Match"). Act 2's second floor.
## Locked in at G after the main-entrance lie, the crew climbs one flight up STAIR 1 to
## Personnel (payroll and HR), looking for proof of where it really was tonight. The
## database is read-only now, so every change goes through the building's services:
## the HR service (staff records, the badge readers' log, escort passes), the
## Facilities service (the floor's panel and work orders) and the doors.
##
## Stations (curriculum option B: POST and PATCH with a JSON body, the status codes
## 201/400/401/403/409, a header carrying an API key, GET to check it took):
##   1. key      the HR front desk: GET a staff record and get 401; the key is on a
##               sticky under the HR manager's keyboard, and goes in an X-Api-Key
##               header (the temp's key from the mail tray gets 403). Practised safely.
##   2. circuits payroll's panel: PATCH the shed circuits back on. The lights don't fit
##               under the night limit while the copier bank is on (409), so that goes
##               off first. GET the panel to see it took. Practised safely.
##   3. air      the air handler restarts on a logged work order: POST one with a JSON
##               body (400 names a missing field, 201 means it was made), GET it back.
##   4. swipes   a teammate's voice on the walkie (solo: Maddison's) asks for the
##               loading door. It's a Mimic. The badge readers' log says where every
##               badge really is: GET /swipes/<badge> before you believe a voice.
##   5. passes   two night-shift staffers are hiding behind locked doors while Mimics
##               wear their faces (with somebody else's badge on the lanyard). The log
##               says which badges are really on the floor and where: PATCH their doors
##               open and POST an escort pass for each real person (a Mimic's badge
##               answers 401), in either order; the station passes once both are out.
##               Then PATCH every door opened tonight shut and GET them back.
##               Under pressure: the Mimics, and the Custodian if its bay wasn't sealed.
## The practice is safe: the air only starts to count once the carbon copy has shown
## the fix (and never during a chapter), and a loose Custodian only starts up the
## dock stairs once the power and the air are back, or the loading door is opened.
## Every station is checked by what the services answer and the state they're left in
## (RequestPuzzle), never by the request's text. Every line players read is a draft
## in plan/approvals/l5-text.md until Augustine approves it word for word.
##
## Layout (level space, north is -z):
##   lift lobby    x -4..4,   z 4..8     STAIR 1 in (east wall), STAIR 2 down (west wall)
##   HR front      x -10..10, z -8..4    the HR desk and its terminal, the training shelf
##                                       with the book, the badge poster, the procedure
##   records cage  x -10..-2, z -16..-8  behind PERS-CAGE; a night-shifter hides here
##   corridor      x -1..3,   z -16..-8  HR front to payroll (a badge reader at each end)
##   HR manager    x 4..10,   z -16..-8  the key under the keyboard, the temp's in the tray
##   payroll       x -10..10, z -28..-16 dark: the desks, a Mimic at one, the panel's
##                                       terminal and clipboard, the vending machines
##   payroll store x -9..-3,  z -32..-28 behind PERS-STORE; the other night-shifter
##   dock landing  x 3..9,    z -34..-28 behind PERS-DOCK: a landing, then the shaft
##
## Co-op: the host decides (what a request set off, who the radio impersonates) and
## every machine plays it out through sync.event. The services run on every machine in
## the same order, so each copy of the panel and the log stays in step.

## Fired once the crew is on the stairs down: the floor is done.
signal completed

## Player-facing lines, drafted for Augustine's approval: plan/approvals/l5-text.md.
const TEXT := {
	"todo_arrive": "HR keeps the badge log. Find where we really were tonight",
	"todo_key": "Get the HR service to answer",
	"todo_power": "Get payroll's lights and the cage lock back on",
	"todo_air": "Get the air moving again",
	"todo_radio": "Someone on the radio wants the loading door open. Find out who's really there",
	"todo_people": "Find the two night-shifters, pass them out, lock every door behind us",
	"todo_down": "STAIR 2 is open. Everyone down, both of them too",
	"case_key": "How do we get the HR service to answer?",
	"case_power": "Why is payroll dark?",
	"case_air": "Why is the air off?",
	"case_radio": "Who's really at the loading door?",
	"case_frame": "Where were our badges tonight?",
	"case_people": "Who on this floor is real?",
	"case_vale": "Who edited Vale's record?",
	"key_done": "The HR service answers to the manager's key, sent in an X-Api-Key header. The temp's key is real and still gets 403: it isn't allowed to.",
	"power_done": "Panel 9 only has %d A at night. The copier bank had to go off before the lights fit; the cage lock came back with them.",
	"air_done": "AHU-9 restarts on a logged work order. Ours was %s. 201 means it was made; reading it back shows it.",
	"radio_done": "The voice on the radio said the loading door. The badge log had %s somewhere else. It wasn't them.",
	"radio_done_solo": "The voice said it was Maddison, with badge %s. No such badge was issued tonight. Maddison is in the garage.",
	"frame_done": "Our visitor badges were swiped into Vale's lab at %s. We were on 14 then, every one of us. Somebody carried our badges there.",
	"people_done": "%s was in %s and %s in %s: the badge log said so. The ones wearing their faces carried badges that don't answer a reader. Both passed out, every door locked again and read back.",
	"vale_done": "Vale's record says deceased 10/14. It was last edited 10/15 at 02:14, after her death, by %s.",
	"arrive": "Payroll is dark through the glass. Somewhere a fan has stopped.",
	"power_back": "Payroll's lights come on. Down the hall, the cage's lock clunks.",
	"copiers_off": "The copier bank winds down.",
	"air_back": "Somewhere above the ceiling, the air handler spins up. The air moves.",
	"air_thick": "The air is thick. It's getting hard to breathe.",
	"air_cleared": "Cold air from the stairwell. The floor clears, slowly.",
	"propped": "The stair door is propped open.",
	"hand_reset": "The breaker is stiff. It takes both hands.",
	"hand_reset_done": "The breaker goes over with a bang. The copiers die; the lights come on.",
	"dock_opens": "The loading door swings open on a black shaft. Cold air. Nobody there.",
	"shaft": "The dock stairs are gone. You fell.",
	"custodian_comes": "Something heavy is coming up the dock stairs.",
	"custodian_in": "The loading door buckles inward. It's on the floor with you.",
	"door_opens": "%s unlocks.",
	"door_locks": "%s locks.",
	"staffer_passed": "%s gets up and heads for the stairs.",
	"stairs_release": "Out by the lifts, STAIR 2's lock clacks open.",
	"stairs_wait": "Waiting for everyone on the stairs (%d/%d)",
	"end_card": "To be continued.",
	"book_taken": "Acceptable API's. Same series as Easy SQL, with a Halcyon asset sticker on the spine.",
	"mimic_leaves": "It gets up and walks away without looking at you.",
	# SYSOP tips (text only, never lies; each fires once per run).
	"tip_header": "401 means the service wants a key with the request. a key goes in a header, on its own line under the request, like the desk sheet shows. Shift+Enter starts the line; Enter on an empty line sends it.",
	"tip_temp": "403: that key is real, and it still isn't allowed in. it's the temp's, for the mail room. HR's own key is the manager's.",
	"tip_wrong_key": "401: the service doesn't know that key. copy it from the sticky character by character.",
	"tip_load": "409: the panel's over its night limit. something heavy is still on. the clipboard lists every circuit's amps; turn the heavy one off first, then try the lights again.",
	"tip_example": "404: that's the clipboard's example, another panel's circuit. this panel's circuits all start C9-.",
	"tip_unit": "that order went in, for the carbon copy's unit: floor 14's air handler. this floor's unit is on the clipboard.",
	"tip_verify": "201 means the service made it. did it do anything? ask for it back.",
	"tip_lure": "a voice on the radio isn't a record. the readers know where every badge is tonight; the poster by the desk says how to ask.",
	"tip_mimic": "that badge didn't answer the reader. a real badge on the floor swipes in somewhere. whoever's wearing that one isn't who the face says.",
	"tip_off_site": "409: that badge left the building hours ago. the night shift is still here; the log says where.",
	"tip_lockup": "both passes are logged. every door opened tonight goes back to locked, then gets read back. GET /doors shows which are still open.",
}
## The laminated desk sheet at the HR front desk: where the header is found. Its
## example asks for another floor's clerk with a blank where the key goes.
const DESK_SHEET_LINES := [
	"HALCYON PERSONNEL  -  HOW TO FILE A PERSONNEL REQUEST",
	"The HR service answers requests from this desk. Every request carries the HR key.",
	"A staff record, by badge number:",
	{"text": "GET /staff/%s", "hand": false},
	{"text": "X-Api-Key: <the HR key>", "hand": false},
	"The key goes on its own line under the request, then an empty line sends it.",
	"Keys are issued by the HR manager. Temps use the mail-room key.",
	{"text": "on the terminal: Shift+Enter starts the next line.", "hand": true},
]
## The poster on the HR front's east wall: the badge readers' log.
const POSTER_LINES := [
	"BADGE IN, BADGE OUT",
	"PERSONNEL KNOWS WHERE YOU ARE.",
	"Every reader logs every swipe. Your log, by badge:",
	"GET /swipes/<badge>",
	"Lost your badge? Tell Personnel the same day.",
]
## The escort-badge procedure pinned by the HR desk: the night-mode rule, and the
## night lockup (every door opened after hours goes back, and is read back).
const PROCEDURE_LINES := [
	"AFTER-HOURS PROCEDURE  -  FLOOR 9",
	"1. Staff leave the floor after 19:00 only on an escort pass logged with Personnel:",
	"POST /escorts",
	"{\"badge\": \"<their badge>\", \"escort\": \"<your badge>\"}",
	"A pass is logged only for a badge the readers have on the floor.",
	"2. Night lockup: every door opened after hours is locked again, and read back:",
	"PATCH /doors/<door>",
	"{\"locked\": true}",
	"then GET /doors/<door>",
	{"text": "doors on 9: GET /doors", "hand": true},
]
## The sign on the records cage's door.
const CAGE_SIGN_LINES := [
	"RECORDS CAGE",
	"Powered lock. Personnel staff only.",
	"No power to the lock: the door holds shut.",
]
## The sign on the payroll store's door.
const STORE_SIGN_LINES := [
	"PAYROLL STORE",
	"Cheque stock and ledgers. Payroll staff only.",
]
## The sign on the loading door.
const DOCK_SIGN_LINES := [
	"LOADING DOOR  -  DOCK STAIRS",
	"Deliveries only. Keep shut after 19:00.",
	{"text": "dock stairs OUT OF SERVICE since 10/09. Use the lifts.", "hand": true},
]
## The sign on the HR manager's door.
const OFFICE_SIGN_LINES := [
	"B. OKONJO",
	"HR MANAGER",
]
## The breaker cupboard behind the vending machines.
const CUPBOARD_LINES := [
	"PANEL 9  -  LOCAL RESET",
	"Lights circuit only. Main trips the heaviest load first.",
]
## The temp's key card in the mail tray: a real key that opens the wrong thing.
const TEMP_CARD_LINES := [
	"PERSONNEL  -  TEMP ACCESS",
	"D. Fisk, temp. Returns 10/16.",
	"Mail-room service key: %s",
	"Not for HR records.",
]
## The Facilities clipboard by the payroll terminal: the panel's circuits, their
## loads, and the night limit, with a clerk's crib for switching one through the
## service (another panel's circuit, so copying it shows the shape without the answer).
const CLIPBOARD_HEAD := [
	"HALCYON FACILITIES  -  PANEL 9  -  NIGHT LOAD SHEDDING",
	"Under Epsilon the panel carries %d A after 19:00. Shed circuits come back through the service, one at a time.",
	{"columns": ["CIRCUIT", "FEEDS", "AMPS", "STATE"], "widths": [0.8, 2.2, 0.6, 0.8]},
]
const CLIPBOARD_TAIL := [
	{"text": "through the service (last night, panel 14's copiers):", "hand": true},
	{"text": "PATCH /circuits/C14-03", "hand": true},
	{"text": "X-Api-Key: <key>", "hand": true},
	{"text": "{\"on\": false}", "hand": true},
	{"text": "true = on, false = off. then GET /circuits to see it took.", "hand": true},
	"Air: AHU-9 restarts on a logged work order (night interlock).",
]
## The carbon copy of a work order pinned over the facilities desk: filled in for
## another floor, so it shows the body's fields without this floor's.
const CARBON_LINES := [
	"HALCYON FACILITIES  -  WORK ORDER  (carbon copy)",
	"Filed on the service from panel 14, 10/13:",
	"POST /work_orders",
	"X-Api-Key: <key>",
	"",
	"{\"floor\": %d, \"unit\": \"%s\", \"fault\": \"%s\"}",
	"Answer: 201 Created, WO-9142.",
	{"text": "every field, every time. floor is a number: no quotes.", "hand": true},
	{"text": "then GET /work_orders/WO-9142 to see it's there.", "hand": true},
]
## The voice on the walkie, by how many times it has spoken: a teammate's voice, or
## Maddison's when there's nobody else to sound like.
const LURE_LINES := {
	1: {"crew": "l5_mimic_lure", "maddison": "l5_mimic_maddison_lure"},
	2: {"crew": "l5_mimic_again", "maddison": "l5_mimic_maddison_again"},
	3: {"crew": "l5_mimic_last", "maddison": "l5_mimic_maddison_last"},
}
const CASES := {"key": TEXT.case_key, "power": TEXT.case_power, "air": TEXT.case_air, "radio": TEXT.case_radio,
	"frame": TEXT.case_frame, "people": TEXT.case_people, "vale": TEXT.case_vale}
## The clock on the HR front wall reads 00:MM when the crew arrives (seeded) and runs.
const STAIR_IN_AT := Vector3(4, 0, 6)
const STAIR_OUT_AT := Vector3(-4, 0, 6)
const CAGE_DOOR_AT := Vector3(-6, 1.15, -8)
const STORE_DOOR_AT := Vector3(-6, 1.15, -28)
const DOCK_DOOR_AT := Vector3(6, 1.25, -28)
## The rooms, for tests and the art pass.
const HR_FRONT := AABB(Vector3(-10, -0.5, -8), Vector3(20, 4, 12))
const CAGE := AABB(Vector3(-10, -0.5, -16), Vector3(8, 4, 8))
const OFFICE := AABB(Vector3(4, -0.5, -16), Vector3(6, 4, 8))
const PAYROLL := AABB(Vector3(-10, -0.5, -28), Vector3(20, 4, 12))
const STORE := AABB(Vector3(-9, -0.5, -32), Vector3(6, 4, 4))
const DOCK := AABB(Vector3(3, -0.5, -34), Vector3(6, 4, 6))
## Where the staffers hide (level space), by hiding place.
const HIDE_AT := {"cage": Vector3(-8.2, 0, -14.2), "store": Vector3(-7.6, 0, -30.6)}
## Where the passed staffers wait, by the stairs down.
const WAIT_AT := [Vector3(-2.4, 0, 6.2), Vector3(-2.4, 0, 7.3)]
## The shaft past the loading door: step onto it and you fall.
const SHAFT_AT := Vector3(6, 0, -32.5)
## How the air goes: once the carbon copy has shown the fix, a grace long enough to
## type it at a first-timer's pace, then a little each tick until it's back. Nothing
## counts while a chapter is being read.
const AIR_GRACE := 180.0
const AIR_TICK := 15.0
const AIR_DAMAGE := 3.0
## The stair door propped: how long until the air clears on its own.
const PROP_TIME := 90.0
## The breaker cupboard's hand reset: how long it takes, in the dark.
const HAND_RESET_TIME := 20.0
## When the radio lies: this long after the HR service first answers (sooner once
## the stair door is propped), then once more if nobody has looked.
const LURE_DELAY := 40.0
const LURE_DELAY_PROPPED := 15.0
const LURE_AGAIN := 50.0
## Not sealed on 10, the Custodian comes up the dock stairs this long after the power
## and the air are back (the practice is safe; the passes and the lockup aren't), or
## the moment the loading door is opened for the voice on the radio.
const CUSTODIAN_DELAY := 150.0

var data: Dictionary
var api: FacilityAPI
var hr: Terminal
var panel: Terminal
var stair_in: Door
var stair_out: Door
var cage_door: Door
var store_door: Door
var dock_door: Door
var book: Interactable
var prop: Interactable
var cupboard: Interactable
var exit_trigger: Trigger
var mimics: Array[Mimic] = []
var staffers := {}  # badge -> Staffer
var custodian: Custodian
## The services' state, the same on every machine: the panel's circuits by id, the
## work orders, the escort passes and the badge readers' log.
var circuits := {}
var orders: Array = []
var escorts: Array = []
var swipes: Array = []
## Visitor badges issued tonight (the crew's), VIS-01 up.
var issued: Array = []
var book_found := false
var pending_chapters: Array = []
var _huddles := 0
var power_back := false
var air_on := false
var air_cleared := false
## The air starts to count against the crew once the carbon copy has shown the fix
## (host: the seconds counted so far, and the ticks dealt).
var air_armed := false
var _air_time := 0.0
var _air_ticks := 0
var custodian_timed := false
## The passes ladder: "review" (POST practised at the work order) or "a" (the prop
## route skipped the work order, so POST is new here). Set when the people case opens.
var passes_ladder := ""
var propped := false
var hand_reset := false
## Floor 9's doors that have been unlocked tonight, by id (the lockup covers them),
## and those read back locked since (the lockup's read-back, one door at a time).
var doors_opened := {}
var read_back := {}
## The radio's lie: the peer it impersonates (0 = Maddison, solo), the badge the
## voice claims, how many times it has spoken, and whether the loading door opened.
var lure_peer := -1
var lure_badge := ""
var lures := 0
var dock_opened := false
var custodian_loose := false
var custodian_here := false
var passed := {}  # badge -> true once a pass is logged
var out := {}  # badge -> true once the staffer has left their hiding place (_send_out)
var released := false
var tips_sent := {}
var _started_msec := 0
var _radio_voice: Voice
## AIR_*, PROP_TIME, HAND_RESET_TIME, LURE_* and CUSTODIAN_DELAY, here so tests can shorten them.
var air_grace := AIR_GRACE
var air_tick := AIR_TICK
var prop_time := PROP_TIME
var hand_reset_time := HAND_RESET_TIME
var lure_delay := LURE_DELAY
var lure_delay_propped := LURE_DELAY_PROPPED
var lure_again := LURE_AGAIN
var custodian_delay := CUSTODIAN_DELAY

## Puzzle stations (RequestPuzzle). Ladder A for every new word; the review ladder
## (two tiers) where the word was practised safely on this floor or an earlier one.
var key_puzzle: RequestPuzzle
var circuits_puzzle: RequestPuzzle
var check_circuits_puzzle: RequestPuzzle
var air_puzzle: RequestPuzzle
var check_air_puzzle: RequestPuzzle
var swipes_puzzle: RequestPuzzle
var passes_puzzle: RequestPuzzle
var lockup_puzzle: RequestPuzzle
var check_lockup_puzzle: RequestPuzzle
var vale_puzzle: RequestPuzzle


func build() -> void:
	data = Level5Data.build(Game.run_seed)
	load_level_seed(data.sql)
	for c in data.circuits:
		circuits[c[0]] = {"id": c[0], "circuit": c[1], "amps": int(c[2]), "on": bool(c[3]), "note": c[4]}
	swipes = data.swipes.duplicate(true)
	custodian_loose = not get_node("/root/Game").custodian_sealed
	api = _make_api()
	_make_puzzles()

	var colors := {"floor": Color(0.3, 0.28, 0.26), "wall": Color(0.62, 0.6, 0.55)}
	# Lift lobby: the dead lifts on the south wall, STAIR 1 (up from G) on the east
	# wall, STAIR 2 (down to B1) on the west wall.
	Greybox.room(geo, Vector3(0, 0, 6), Vector3(8, 3.2, 4), colors, [
		{"wall": "n", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "w", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},
		{"wall": "e", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},
	])
	Greybox.label(geo, Vector3(0, 2.75, 4.12), "9   PERSONNEL", 56, Color(0.75, 0.75, 0.7))
	for x in [-1.5, 1.5]:
		Greybox.panel(geo, Vector3(x, 1.1, 7.88), Vector3(1.3, 2.2, 0.04), Color(0.5, 0.52, 0.55), 0.0)
		Greybox.label(geo, Vector3(x, 2.5, 7.86), "ELEVATOR  9", 32, Color(1.0, 0.45, 0.1), 180)
	stair_in = Stairwell.build(self, geo, STAIR_IN_AT, -90.0, "9")
	stair_in.name = "Door_STAIR-IN"
	stair_in.locked = false
	stair_out = Stairwell.build(self, geo, STAIR_OUT_AT, 90.0, "9", "STAIR 2")
	stair_out.name = "Door_STAIR-OUT"
	exit_door = stair_out
	# The stair door's wedge: propped, the stairwell's air clears the floor, slowly.
	prop = Interactable.create(self, STAIR_IN_AT + Vector3(0.12, 0.1, 0.7), Vector3(0.12, 0.2, 0.3), "Prop the stair door open", Color(0.6, 0.45, 0.2))
	prop.name = "DoorProp"
	prop.used.connect(func(_p): sync.event("_propped"))

	_build_hr_front(colors)
	_build_office(colors)
	_build_cage(colors)
	_build_corridor(colors)
	_build_payroll(colors)
	_build_store(colors)
	_build_dock(colors)
	_place_people()

	# Lights follow the `lights` table (sync_world): payroll, the cage and the store are dark.
	add_light("L9-LOBBY", Vector3(0, 3.2, 6), 6.0, 0.9)
	for x in [-5.0, 5.0]:
		add_light("L9-HR", Vector3(x, 3.2, -2), 8.0, 0.9, Color(0.95, 0.95, 0.88))
	add_light("L9-HR", Vector3(1, 3.0, -12), 6.0, 0.7)
	add_light("L9-OFFICE", Vector3(7, 3.0, -12), 6.0, 0.8)
	add_light("L9-CAGE", Vector3(-6, 3.0, -12), 6.0, 0.8)
	for x in [-5.0, 5.0]:
		add_light("L9-PAY", Vector3(x, 3.2, -22), 8.0, 0.9, Color(0.95, 0.95, 0.88))
	add_light("L9-STORE", Vector3(-6, 3.0, -30), 5.0, 0.7)
	# An emergency light in payroll (its own circuit stayed on): just enough to see shapes.
	Greybox.ceiling_light(geo, Vector3(0, 3.1, -17), 7.0, 0.25, Color(1.0, 0.4, 0.3))

	spawn = _stair_landing(STAIR_IN_AT, -90.0)
	exit_trigger = Trigger.create(self, STAIR_OUT_AT + Vector3(-2.4, 1, 0), Vector3(2.8, 2, 3.2))
	exit_trigger.name = "StairsDown"
	exit_trigger.require_all = true
	exit_trigger.waiting.connect(func(n, total): sync.team_notice(TEXT.stairs_wait % [n, total]))
	exit_trigger.entered.connect(func(_b): sync.event("_on_exit"), CONNECT_ONE_SHOT)
	# The badge readers at the floor's doorways: every swipe goes in the log.
	for r in [["PERS-FRONT", Vector3(0, 1, 3.4), Vector3(2.4, 2, 1.2)], ["PERS-PAY", Vector3(1, 1, -16), Vector3(2.4, 2, 1.2)]]:
		var reader := Trigger.create(self, r[1], r[2], false)
		reader.name = "Reader_" + r[0]
		reader.entered.connect(_on_reader.bind(r[0]))
	for term in [hr, panel]:
		term.api = api


func _make_puzzles() -> void:
	var key: String = data.keys.hr
	var hr_key := "X-Api-Key: %s" % key
	# The station's point is the key: every service here wants it, so any 200 at either
	# terminal is the manager's key in a header (the temp's key can't get one).
	key_puzzle = RequestPuzzle.new("key", "GET /staff\n%s" % hr_key, func(_line: String, res: Dictionary) -> bool:
		return res.status == 200, [
		"the shape, with the key left as enter_key:\n" +
		"    [color=#ffffff]GET /staff\nX-Api-Key: enter_key[/color]\n" +
		"  GET /staff   ask the HR service for the staff records (it only reads)\n" +
		"  X-Api-Key: enter_key   a header: the key, on its own line under the request. Shift+Enter starts the line, and an empty line sends it\n" +
		"enter_key is the HR key. the desk sheet says who issues keys.",
		"the HR manager's office is through the door on the right. the key is on a sticky under the keyboard. the card in the mail tray is the temp's key, and it won't do.",
		"type this, then Enter twice:\n" +
		"    [color=#ffffff]GET /staff\n%s[/color]" % hr_key,
	])
	key_puzzle.case_id = "key"
	var lights_id := "C9-01"
	var copiers_id := "C9-03"
	var cage_id := "C9-04"
	circuits_puzzle = RequestPuzzle.new("circuits", "PATCH /circuits/%s\n%s\n\n{\"on\": true}" % [lights_id, hr_key], func(line: String, res: Dictionary) -> bool:
		return res.status == 200 and _path_of(line).begins_with("/circuits") and _power_ok(), [
		"the shape, with the circuit left as enter_circuit_id:\n" +
		"    [color=#ffffff]PATCH /circuits/enter_circuit_id\nX-Api-Key: %s\n\n{\"on\": true}[/color]\n" % key +
		"  PATCH /circuits/enter_circuit_id   change one thing about one circuit, and leave the rest alone\n" +
		"  X-Api-Key: ...   the header, as before\n" +
		"  (an empty line)   headers end, the body begins\n" +
		"  {\"on\": true}   the body: JSON. the field and its new value. true is on, false is off, no quotes on either\n" +
		"enter_circuit_id is a circuit's id from the clipboard: the two that were shed. if the panel answers 409, something heavy has to go off first.",
		"the clipboard lists every circuit's amps and the panel's night limit. add up what's on. the copier bank is the heavy one: PATCH it to false first, then the lights and the cage lock to true.",
		"type these, one at a time, Enter twice after each:\n" +
		"    [color=#ffffff]PATCH /circuits/%s\n%s\n\n{\"on\": false}[/color]\n" % [copiers_id, hr_key] +
		"    [color=#ffffff]PATCH /circuits/%s\n%s\n\n{\"on\": true}[/color]\n" % [lights_id, hr_key] +
		"    [color=#ffffff]PATCH /circuits/%s\n%s\n\n{\"on\": true}[/color]\n" % [cage_id, hr_key] +
		"then GET /circuits to see it took.",
	], _power_ok)
	circuits_puzzle.case_id = "power"
	# Verify after the change: GET is long practised (floor 22), so the review ladder.
	check_circuits_puzzle = RequestPuzzle.new("check_circuits", "GET /circuits\n%s" % hr_key, func(line: String, res: Dictionary) -> bool:
		return res.status == 200 and _method_of(line) == "GET" and _path_of(line).begins_with("/circuits") and _power_ok() and _shows_circuit_on(res.body, lights_id), [
		"the shape: ask the panel back, with the service left as enter_service:\n" +
		"    [color=#ffffff]GET /enter_service\nX-Api-Key: %s[/color]\n" % key +
		"enter_service is the service you just changed.",
		"type this, then Enter twice:\n" +
		"    [color=#ffffff]GET /circuits\n%s[/color]" % hr_key,
	])
	check_circuits_puzzle.case_id = "power"
	var ex: Dictionary = data.example_order
	air_puzzle = RequestPuzzle.new("air", "POST /work_orders\n%s\n\n{\"floor\": 9, \"unit\": \"%s\", \"fault\": \"no air\"}" % [hr_key, data.ahu], func(line: String, res: Dictionary) -> bool:
		return res.status == 201 and _path_of(line).begins_with("/work_orders") and _air_ok(), [
		"the shape, with the unit left as enter_unit:\n" +
		"    [color=#ffffff]POST /work_orders\nX-Api-Key: %s\n\n{\"floor\": 9, \"unit\": \"enter_unit\", \"fault\": \"no air\"}[/color]\n" % key +
		"  POST /work_orders   ask the service to make a new work order\n" +
		"  X-Api-Key: ...   the header, then an empty line\n" +
		"  {...}   the body: every field the carbon copy shows. floor is a number, no quotes; the others are text, in double quotes\n" +
		"enter_unit is this floor's air handler: the clipboard names it. 400 means a field is missing or wrong, and says which.",
		"the carbon copy over the desk is floor 14's order: the same three fields. the clipboard's last line names this floor's unit.",
		"type this, then Enter twice:\n" +
		"    [color=#ffffff]POST /work_orders\n%s\n\n{\"floor\": 9, \"unit\": \"%s\", \"fault\": \"no air\"}[/color]\n" % [hr_key, data.ahu] +
		"201 means it was made. then ask for it back: GET /work_orders.",
	], _air_ok)
	air_puzzle.case_id = "air"
	check_air_puzzle = RequestPuzzle.new("check_air", "GET /work_orders\n%s" % hr_key, func(line: String, res: Dictionary) -> bool:
		return res.status == 200 and _method_of(line) == "GET" and _path_of(line).begins_with("/work_orders") and _air_ok() and _shows_order(res.body), [
		"the shape: ask for it back, with the service left as enter_service:\n" +
		"    [color=#ffffff]GET /enter_service\nX-Api-Key: %s[/color]\n" % key +
		"enter_service is the service you just posted to. the 201 came with the order's number: GET /work_orders/enter_order_id asks for just that one.",
		"type this, then Enter twice:\n" +
		"    [color=#ffffff]GET /work_orders\n%s[/color]" % hr_key,
	])
	check_air_puzzle.case_id = "air"
	# The radio's claim against the readers' log: GET with an id in the path is
	# practised (floor 22's /doors/SEC-EXIT), so the review ladder.
	swipes_puzzle = RequestPuzzle.new("swipes", "GET /swipes/enter_badge\n%s" % hr_key, func(line: String, res: Dictionary) -> bool:
		return _exposes_lure(line, res), [
		"the shape, with the badge left as enter_badge:\n" +
		"    [color=#ffffff]GET /swipes/enter_badge\nX-Api-Key: %s[/color]\n" % key +
		"enter_badge is the badge of whoever's talking. the readers log where every badge really is: the voice says the loading door; the log says where they are.",
		"",  # the exact query is built once the voice has spoken (_lure_hints)
	])
	swipes_puzzle.case_id = "radio"
	swipes_puzzle.solved = true  # until the radio lies
	# The escort passes: both night-shifters passed and out (their doors opened). POST
	# is practised at the air handler, so the review ladder, unless the prop route
	# skipped the work order (_passes_hints).
	passes_puzzle = RequestPuzzle.new("passes", "POST /escorts\n%s\n\n{\"badge\": \"enter_badge\", \"escort\": \"VIS-01\"}" % hr_key, func(_line: String, _res: Dictionary) -> bool:
		return _passes_ok(), [], _passes_ok)
	passes_puzzle.case_id = "people"
	_passes_hints()
	# The lockup: PATCH is practised at the panel, so the review ladder; its last tier
	# lists the doors still open (_lockup_hints).
	lockup_puzzle = RequestPuzzle.new("lockup", "PATCH /doors/enter_door\n%s\n\n{\"locked\": true}" % hr_key, func(line: String, res: Dictionary) -> bool:
		return res.status == 200 and _path_of(line).begins_with("/doors") and _lockup_ok(), [], _lockup_ok)
	lockup_puzzle.case_id = "people"
	_lockup_hints()
	check_lockup_puzzle = RequestPuzzle.new("check_lockup", "GET /doors\n%s" % hr_key, func(line: String, res: Dictionary) -> bool:
		return res.status == 200 and _method_of(line) == "GET" and _path_of(line).begins_with("/doors") and _lockup_ok() and _shows_locked(res.body), [
		"the shape: read the doors back, with the service left as enter_service:\n" +
		"    [color=#ffffff]GET /enter_service\nX-Api-Key: %s[/color]\n" % key +
		"enter_service is the service whose doors you just locked. GET /doors/enter_door reads one back.",
		"type this, then Enter twice:\n" +
		"    [color=#ffffff]GET /doors\n%s[/color]" % hr_key,
	])
	check_lockup_puzzle.case_id = "people"
	vale_puzzle = RequestPuzzle.new("vale", "GET /staff/%s\n%s" % [Level5Data.VALE.id, hr_key], func(line: String, res: Dictionary) -> bool:
		return res.status == 200 and _path_of(line).to_upper() == "/STAFF/" + Level5Data.VALE.id, [
		"the shape, with the badge left as enter_badge:\n" +
		"    [color=#ffffff]GET /staff/enter_badge\nX-Api-Key: %s[/color]\n" % key +
		"enter_badge is her badge number: GET /staff lists every record, with its id.",
		"type this, then Enter twice:\n" +
		"    [color=#ffffff]GET /staff/%s\n%s[/color]" % [Level5Data.VALE.id, hr_key],
	])
	vale_puzzle.case_id = "vale"


## A spot on a stairwell's landing, clear of the flight, facing its door.
func _stair_landing(at: Vector3, yaw_deg: float) -> Transform3D:
	var holder := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg + 180.0)), holder * Vector3(-0.8, 0.1, -1.3))


func player_spawn(index: int) -> Transform3D:
	# Six people fit on the landing in a row along the flight, not spread into the walls.
	var holder := Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), STAIR_IN_AT)
	var slot := holder * Vector3(-0.8 + 0.5 * (index % 2), 0.1, -0.7 - 0.55 * (index / 2))
	return global_transform * Transform3D(spawn.basis, slot)


## Level 4 calls this (through the World) as the crew heads up STAIR 1 from the
## lobby: everyone is placed on 9's landing before play moves here. Every machine.
func arrive_by_stairs() -> void:
	players.place_all(self)


# --- The rooms ------------------------------------------------------------------------

func _build_hr_front(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(0, 0, -2), Vector3(20, 3.2, 12), colors, [
		{"wall": "s", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "n", "at": CAGE_DOOR_AT.x, "width": 1.6, "height": 2.3},
		{"wall": "n", "at": 1.0, "width": 2.4, "height": 2.4},
		{"wall": "n", "at": 7.0, "width": 1.4, "height": 2.3},
	])
	Greybox.label(geo, Vector3(0, 2.8, 3.88), "PERSONNEL  -  HR", 48, Color(0.8, 0.8, 0.72), 180)
	# The HR front desk, its terminal and the desk sheet, facing the lobby.
	Greybox.box(geo, Vector3(0, 0.5, -1.5), Vector3(3.2, 1.0, 0.8), Color(0.42, 0.34, 0.28), "HRDesk")
	hr = Terminal.spawn(geo, Vector3(-0.6, 1.0, -1.5), 0, "HR FRONT DESK", db, terminal_ui)
	hr.name = "HRTerminal"
	hr.puzzles = [key_puzzle, swipes_puzzle, passes_puzzle, lockup_puzzle, check_lockup_puzzle, vale_puzzle]
	hr.boot_lines = [
		"HALCYON PERSONNEL  -  HR FRONT DESK",
		"Services on this desk: /staff  /swipes  /escorts  /doors",
	]
	hr.requested.connect(_on_request.bind("hr"))
	hr.queried.connect(_on_query.bind("hr"))
	var lines := DESK_SHEET_LINES.duplicate(true)
	lines[3] = {"text": "GET /staff/%s" % data.example_key_id, "hand": false}
	var sheet := Document.place(geo, Vector3(0.7, 1.0, -1.5), 0, "Personnel request sheet", lines, true, "laminated", Vector2(0.24, 0.3))
	sheet.clues = [{"case": "key", "opens": TEXT.case_key, "text": "The desk sheet: every HR request carries the HR key in an X-Api-Key header, on its own line. The manager issues keys."}]
	sheet.read_by.connect(func(_p):
		sync.event("_ask", ["key"])
		sync.event("_book_huddle", ["api_codes"])
		sync.event("_book_huddle", ["api_keys"]))
	# The after-hours procedure, pinned on the wall behind the desk.
	var proc := Document.place(geo, Vector3(-1.5, 1.7, -7.88), 180, "Escort procedure", PROCEDURE_LINES, false, "laminated", Vector2(0.3, 0.36))
	proc.clues = [{"case": "people", "opens": TEXT.case_people, "text": "The after-hours procedure: staff leave only on an escort pass (POST /escorts, logged for a badge the readers have on the floor). Night lockup: every door opened is locked again and read back."}]
	proc.read_by.connect(func(_p):
		sync.event("_ask", ["people"])
		sync.event("_book_huddle", ["api_check"]))
	# The badge poster on the east wall.
	var poster := Document.place(geo, Vector3(9.88, 1.8, -3), -90, "Badge poster", POSTER_LINES, false, "paper", Vector2(0.42, 0.56))
	poster.clues = [{"case": "radio", "text": "The poster: every reader logs every swipe. GET /swipes/<badge> is a badge's log."}]
	# The training shelf by the west wall, with the book on it.
	Greybox.box(geo, Vector3(-9.3, 0.9, 0.5), Vector3(1.2, 1.8, 0.4), Color(0.36, 0.3, 0.26), "TrainingShelf")
	Greybox.label(geo, Vector3(-9.2, 1.95, 0.5), "TRAINING", 24, Color(0.85, 0.85, 0.8), 90)
	for i in 5:
		Greybox.box(geo, Vector3(-9.3, 1.0, 0.32 + i * 0.09), Vector3(0.9, 0.05, 0.07), Color(0.3 + i * 0.1, 0.35, 0.5 - i * 0.05), "Binder")
	book = Interactable.create(self, Vector3(-9.3, 1.1, 0.72), Vector3(0.6, 0.05, 0.2), "Pick up: Acceptable API's", Color(0.9, 0.5, 0.1))
	book.name = "Book"
	book.used.connect(func(p): sync.event("_book_found", [players.id_of(p)]))
	# The clock on the wall over the desk: the floor's time when the crew arrives.
	Greybox.label(geo, Vector3(0, 2.6, -7.88), data.clock, 48, Color(1.0, 0.25, 0.15), 180).name = "Clock"
	# A row of waiting chairs by the east wall.
	for z in [-5.0, -4.0, -3.0]:
		Greybox.box(geo, Vector3(8.6, 0.25, z), Vector3(0.5, 0.5, 0.5), Color(0.35, 0.4, 0.45), "Chair")


func _build_office(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(7, 0, -12), Vector3(6, 3.0, 8), {"floor": Color(0.34, 0.3, 0.28), "wall": colors.wall}, [
		{"wall": "s", "at": 0.0, "width": 1.4, "height": 2.3},
	])
	Document.place(geo, Vector3(5.6, 1.6, -7.88), 180, "Office sign", OFFICE_SIGN_LINES, false, "laminated", Vector2(0.22, 0.14))
	# The manager's desk, the keyboard, and under its front edge the sticky with the key.
	Greybox.box(geo, Vector3(7, 0.5, -14.5), Vector3(2.4, 1.0, 0.8), Color(0.4, 0.33, 0.28), "ManagerDesk")
	Greybox.box(geo, Vector3(6.6, 1.02, -14.45), Vector3(0.45, 0.03, 0.16), Color(0.85, 0.83, 0.78), "Keyboard")
	Greybox.panel(geo, Vector3(6.6, 1.25, -14.75), Vector3(0.4, 0.3, 0.04), Color(0.12, 0.14, 0.16), 0.0)
	var sticky := Document.place(geo, Vector3(6.6, 1.003, -14.28), 0, "Key sticky", [{"text": "HR svc key: %s  (don't share!!)" % data.keys.hr, "hand": true}], true, "sticky")
	sticky.name = "KeySticky"
	sticky.clues = [{"case": "key", "text": "Under the HR manager's keyboard: HR svc key: %s" % data.keys.hr}]
	# The mail tray with the temp's key card: a real key for the wrong service.
	Greybox.box(geo, Vector3(8.0, 1.03, -14.5), Vector3(0.5, 0.06, 0.35), Color(0.2, 0.22, 0.3), "MailTray")
	var card_lines := TEMP_CARD_LINES.duplicate()
	card_lines[2] = TEMP_CARD_LINES[2] % data.keys.temp
	var card := Document.place(geo, Vector3(8.0, 1.07, -14.5), 0, "Temp key card", card_lines, true, "laminated", Vector2(0.2, 0.14))
	card.clues = [{"case": "key", "text": "In the mail tray: the temp's mail-room key, %s. Not for HR records." % data.keys.temp}]
	# A filing cabinet and a framed certificate.
	Greybox.box(geo, Vector3(9.5, 0.7, -10), Vector3(0.6, 1.4, 0.5), Color(0.45, 0.47, 0.5), "Cabinet")


func _build_cage(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(-6, 0, -12), Vector3(8, 3.0, 8), {"floor": Color(0.26, 0.26, 0.28), "wall": colors.wall.darkened(0.15)}, [
		{"wall": "s", "at": 0.0, "width": 1.6, "height": 2.3},
	])
	Greybox.label(geo, Vector3(CAGE_DOOR_AT.x, 2.6, -7.88), "RECORDS CAGE", 32, Color(0.8, 0.8, 0.72), 180)
	Document.place(geo, Vector3(CAGE_DOOR_AT.x + 1.4, 1.5, -7.88), 180, "Cage sign", CAGE_SIGN_LINES, false, "laminated", Vector2(0.26, 0.2))
	cage_door = add_door("PERS-CAGE", CAGE_DOOR_AT, Vector3(1.6, 2.3, 0.12))
	# Shelving stacks down both sides; the staffer hides behind the back one.
	for x in [-9.2, -2.8]:
		for z in [-10.5, -13.0]:
			Greybox.box(geo, Vector3(x, 1.0, z), Vector3(0.6, 2.0, 2.0), Color(0.5, 0.48, 0.42), "Stack")
	Greybox.box(geo, Vector3(-6.5, 0.9, -15.3), Vector3(3.0, 1.8, 0.5), Color(0.5, 0.48, 0.42), "BackStack")


func _build_corridor(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(1, 0, -12), Vector3(4, 3.0, 8), colors, [
		{"wall": "s", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "n", "at": 0.0, "width": 2.4, "height": 2.4},
	])
	Greybox.label(geo, Vector3(1, 2.7, -7.88), "PAYROLL  >", 32, Color(0.8, 0.8, 0.72), 180)
	# The readers by each doorway: a grey box with a slot.
	Greybox.box(geo, Vector3(2.0, 1.3, 3.9), Vector3(0.1, 0.16, 0.1), Color(0.3, 0.3, 0.32), "ReaderFront")
	Greybox.box(geo, Vector3(2.9, 1.3, -15.9), Vector3(0.1, 0.16, 0.1), Color(0.3, 0.3, 0.32), "ReaderPay")


func _build_payroll(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(0, 0, -22), Vector3(20, 3.2, 12), {"floor": Color(0.3, 0.28, 0.26), "wall": colors.wall}, [
		{"wall": "s", "at": 1.0, "width": 2.4, "height": 2.4},
		{"wall": "n", "at": STORE_DOOR_AT.x, "width": 1.2, "height": 2.3},
		{"wall": "n", "at": DOCK_DOOR_AT.x, "width": 1.6, "height": 2.5},
	])
	Greybox.label(geo, Vector3(1, 2.8, -16.12), "PAYROLL", 48, Color(0.8, 0.8, 0.72), 0)
	# Desks in two rows; the Mimic sits at the second on the left, back to the door.
	for x in [-4.0, 2.0]:
		for z in [-20.0, -24.0]:
			Greybox.box(geo, Vector3(x, 0.5, z), Vector3(2.0, 1.0, 0.8), Color(0.4, 0.38, 0.34), "PayDesk")
			Greybox.panel(geo, Vector3(x, 1.25, z - 0.3), Vector3(0.4, 0.3, 0.04), Color(0.1, 0.1, 0.12), 0.0)
	Greybox.label(geo, Vector3(-4, 1.05, -19.55), "T. LINDQVIST", 14, Color(0.1, 0.1, 0.1), 0)
	# The filing bank the Mimic walks behind.
	Greybox.box(geo, Vector3(-7, 1.0, -23), Vector3(2.4, 2.0, 0.5), Color(0.45, 0.47, 0.5), "FilingBank")
	# The copier bank along the west wall, humming: the heavy load.
	for z in [-18.5, -20.0, -21.5]:
		Greybox.box(geo, Vector3(-9.2, 0.6, z), Vector3(0.9, 1.2, 1.1), Color(0.75, 0.75, 0.72), "Copier")
	Greybox.label(geo, Vector3(-9.6, 1.9, -20), "COPIERS", 24, Color(0.85, 0.85, 0.8), 90)
	# The vending machines on the east wall, and the breaker cupboard behind them.
	for z in [-18.2, -19.6]:
		Greybox.box(geo, Vector3(9.2, 0.95, z), Vector3(0.9, 1.9, 1.2), Color(0.25, 0.3, 0.5), "Vending")
	cupboard = Interactable.create(self, Vector3(9.4, 1.0, -21.0), Vector3(0.5, 0.8, 0.5), "Reset the lights breaker by hand", Color(0.4, 0.4, 0.42))
	cupboard.name = "BreakerCupboard"
	cupboard.used.connect(func(p): sync.event("_hand_reset_started", [players.id_of(p)]))
	Document.place(geo, Vector3(9.88, 1.7, -21.0), -90, "Cupboard sign", CUPBOARD_LINES, false, "laminated", Vector2(0.22, 0.16))
	# The facilities desk by the north wall: the panel's terminal and its clipboard.
	Greybox.box(geo, Vector3(6, 0.5, -26.5), Vector3(3.0, 1.0, 0.8), Color(0.38, 0.38, 0.4), "FacilitiesDesk")
	panel = Terminal.spawn(geo, Vector3(5.4, 1.0, -26.5), 0, "PANEL 9", db, terminal_ui)
	panel.name = "PanelTerminal"
	panel.puzzles = [circuits_puzzle, check_circuits_puzzle, air_puzzle, check_air_puzzle]
	panel.boot_lines = [
		"HALCYON FACILITIES  -  PANEL 9",
		"Services on this panel: /circuits  /work_orders  /doors",
	]
	panel.requested.connect(_on_request.bind("panel"))
	panel.queried.connect(_on_query.bind("panel"))
	var board := Document.place(geo, Vector3(6.8, 1.0, -26.5), 0, "Facilities clipboard", _clipboard_lines(), true, "clipboard")
	board.clues = [{"case": "power", "opens": TEXT.case_power, "text": "Panel 9 carries %d A at night. Shed circuits come back through the service, one at a time: PATCH /circuits/<id> with {\"on\": true}. The copier bank is still on." % data.limit},
		{"case": "air", "opens": TEXT.case_air, "text": "The clipboard: %s restarts on a logged work order (night interlock)." % data.ahu}]
	board.read_by.connect(func(_p):
		sync.event("_ask", ["power"])
		sync.event("_book_huddle", ["api_patch"]))
	var carbon := CARBON_LINES.duplicate()
	carbon[5] = CARBON_LINES[5] % [data.example_order.floor, data.example_order.unit, data.example_order.fault]
	var copy := Document.place(geo, Vector3(3.2, 1.7, -27.88), 180, "Carbon copy", carbon, false, "paper", Vector2(0.21, 0.28))
	copy.clues = [{"case": "air", "opens": TEXT.case_air, "text": "A carbon copy of floor 14's work order: POST /work_orders with a body of floor, unit and fault. 201 Created, then GET it back."}]
	copy.read_by.connect(func(_p):
		sync.event("_ask", ["air"])
		sync.event("_air_armed")
		sync.event("_book_huddle", ["api_post"]))
	# The air handler's grille in the ceiling, still.
	Greybox.box(geo, Vector3(0, 3.1, -24), Vector3(1.2, 0.1, 0.6), Color(0.55, 0.55, 0.52), "AirGrille")


func _build_store(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(-6, 0, -30), Vector3(6, 3.0, 4), {"floor": Color(0.26, 0.26, 0.28), "wall": colors.wall.darkened(0.15)}, [
		{"wall": "s", "at": 0.0, "width": 1.2, "height": 2.3},
	])
	Document.place(geo, Vector3(STORE_DOOR_AT.x + 1.2, 1.5, -28.12), 0, "Store sign", STORE_SIGN_LINES, false, "laminated", Vector2(0.26, 0.16))
	store_door = add_door("PERS-STORE", STORE_DOOR_AT, Vector3(1.2, 2.3, 0.12))
	Greybox.box(geo, Vector3(-4.0, 0.9, -31.0), Vector3(1.2, 1.8, 1.4), Color(0.5, 0.48, 0.42), "StoreShelf")


func _build_dock(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(6, 0, -31), Vector3(6, 3.2, 6), {"floor": Color(0.08, 0.08, 0.09), "wall": colors.wall.darkened(0.4)}, [
		{"wall": "s", "at": 0.0, "width": 1.6, "height": 2.5},
	])
	Document.place(geo, Vector3(DOCK_DOOR_AT.x + 1.4, 1.5, -28.12), 0, "Dock sign", DOCK_SIGN_LINES, false, "laminated", Vector2(0.26, 0.2))
	dock_door = add_door("PERS-DOCK", DOCK_DOOR_AT, Vector3(1.6, 2.5, 0.12))
	# A landing, then nothing: the dock stairs are a black drop.
	Greybox.box(geo, Vector3(6, -0.05, -29.0), Vector3(5.6, 0.1, 1.8), Color(0.3, 0.3, 0.3), "DockLanding")
	Greybox.label(geo, Vector3(6, 2.2, -33.88), "DOCK STAIRS", 28, Color(0.5, 0.1, 0.1), 180)
	# The drop itself is checked per machine in _process (a Trigger only fires on the host).


## Wherever everyone stands: the Mimics, the staffers, and the Custodian up the
## dock stairs if its bay on 10 wasn't sealed.
func _place_people() -> void:
	var haunts := [
		{"at": Vector3(-9, 0, -7), "look": Vector3(-9, 0, -9), "retreat": Vector3(1, 0, -14)},
		{"at": Vector3(1, 0, -15), "look": Vector3(1, 0, -17), "retreat": Vector3(-9, 0, -26)},
		{"at": Vector3(1.5, 0, 7.4), "look": Vector3(1.5, 0, 9), "retreat": Vector3(-9, 0, -7)},
		{"at": Vector3(8.6, 0, -6), "look": Vector3(8.6, 0, -8), "retreat": Vector3(1, 0, -14)},
	]
	for i in data.night.size():
		var s: Dictionary = data.night[i]
		var m := Mimic.new()
		m.name = "Mimic%d" % (i + 1)
		m.face = s.name
		m.dept = s.dept
		m.badge = Level5Data.LOST[i].id
		var where := Vector3(-4, 0, -20.6) if s.dept == "Payroll" else Vector3(-9, 0, -7)
		m.position = where
		add_child(m)
		if s.dept == "Payroll":
			m.seat(to_global(where), to_global(Vector3(-4, 0, -24)))
			m.retreat = to_global(Vector3(-9, 0, -26))
		else:
			m.stand(to_global(where), to_global(Vector3(-9, 0, -9)))
			m.retreat = to_global(Vector3(1, 0, -14))
		var mine: Array = haunts.slice(1) + haunts.slice(0, 1)  # not where it already stands
		if i == 1:
			mine.reverse()
		m.haunts = mine.map(func(h): return {"at": to_global(h.at), "look": to_global(h.look), "retreat": to_global(h.retreat)})
		m.left.connect(func(_s): sync.event("_mimic_left", [m.name]))
		mimics.append(m)
		# The real one, hiding where their badge last swiped in.
		var st := Staffer.new()
		st.name = "Staffer_" + s.first
		st.staff_name = s.name
		st.first_name = s.first
		st.badge = s.id
		st.dept = s.dept
		var hide_at: Vector3 = HIDE_AT[s.hide.id]
		st.position = hide_at
		add_child(st)
		st.hide_at(to_global(hide_at), to_global(hide_at + Vector3(0, 0, 1)))
		staffers[s.id] = st
	if custodian_loose:
		custodian = Custodian.new()
		custodian.name = "Custodian"
		custodian.position = Vector3(6, 0, -30)
		add_child(custodian)
		custodian.set_bay(to_global(SHAFT_AT))


## The Facilities clipboard: the panel's limit, every circuit with its amps and
## state, and the clerk's crib for switching one through the service.
func _clipboard_lines() -> Array:
	var lines: Array = CLIPBOARD_HEAD.duplicate(true)
	lines[1] = CLIPBOARD_HEAD[1] % data.limit
	for c in data.circuits:
		lines.append({"row": [c[0], c[1], str(c[2]), "on" if c[3] else "off"], "hand": false})
		if str(c[4]) != "":
			lines.append({"text": "    %s" % c[4], "hand": true})
	lines.append_array(CLIPBOARD_TAIL)
	return lines


func net_setup() -> void:
	for m in mimics:
		sync.replicate(m, m.sync_properties())
	for b in staffers:
		sync.replicate(staffers[b], staffers[b].sync_properties())
	if custodian:
		custodian.crew = crew
		sync.replicate(custodian, custodian.sync_properties())


func apply_environment(env: Environment) -> void:
	env.ambient_light_energy = 0.06
	env.fog_density = 0.04


func start() -> void:
	_started_msec = Time.get_ticks_msec()
	stair_in.set_open(true, true)  # the crew came up through it
	hr.ensure_booted()
	panel.ensure_booted()
	_radio_voice = Voice.new()
	_radio_voice.name = "RadioVoice"
	add_child(_radio_voice)
	seed_crew(players.count() if players else 1)
	if completed.get_connections().is_empty():
		completed.connect(_on_completed)
	hud.todo(TEXT.todo_arrive)
	hud.notice(TEXT.arrive, 5.0)
	_warden(["l5_arrive_pa", "l5_arrive", "l5_arrive_tease"], 0.8)


## The crew's visitor badges, issued at the front desk tonight, and their swipes
## so far: in at the lobby, and (the frame) into Vale's lab on 22 while everyone
## was on 14. Every machine seeds the same badges from the player count.
func seed_crew(count: int) -> void:
	issued.clear()
	for i in count:
		var badge := "VIS-%02d" % (i + 1)
		issued.append(badge)
		swipes.append({"badge": badge, "reader": "G-LOBBY", "dir": "IN", "time": "23:0%d" % (2 + i % 4)})
		swipes.append({"badge": badge, "reader": "LAB-B", "dir": "IN", "time": "23:%02d" % (17 + i % 3)})
		swipes.append({"badge": badge, "reader": "SEC-22", "dir": "IN", "time": "23:%02d" % (34 + i % 3)})
	_passes_hints()  # the escort on the last tier is this machine's own badge


## WARDEN's floor 9 lines and the PA's tapes, in order, with a pause between them
## (the announcement, then his own voice). A line that isn't in VoiceLines yet is
## skipped, so they play as soon as Voice adds them.
func _warden(ids: Array, pause := 1.0) -> void:
	var first := true
	for id in ids:
		if VoiceLines.get_line(id).is_empty():
			continue
		if not first:
			await get_tree().create_timer(pause, false).timeout
			if not is_inside_tree():
				return
		first = false
		await hud.line(id)


## The floor's clock: the time on the wall when the crew arrived, plus the minutes since.
func floor_time() -> String:
	var elapsed := 0
	if _started_msec > 0:
		elapsed = int((Time.get_ticks_msec() - _started_msec) / 60000.0)
	var m: int = data.minute + elapsed
	return "%02d:%02d" % [(Level5Data.CLOCK_HOUR + m / 60) % 24, m % 60]


# --- The services ---------------------------------------------------------------------

## The HR service (staff, the badge log, escort passes), the Facilities service (the
## panel, work orders) and the doors, all behind the floor's keys. Handlers change
## only the services' own state and the building's tables; what that means for the
## floor plays out from _on_request on the host, through sync.event.
func _make_api() -> FacilityAPI:
	var a := FacilityAPI.new()
	a.add_key(data.keys.hr, ["hr", "facilities", "doors"], "HR manager")
	a.add_key(data.keys.temp, ["mail"], "temp")
	a.route("GET", "/staff", func(_p):
		return {"status": 200, "body": {"staff": data.staff.map(Level5Data.staff_json)}}, "hr")
	a.route("GET", "/staff/:id", func(p):
		var s := _staff(str(p[0]))
		if s.is_empty():
			return {"status": 404, "body": {"error": "No staff record %s. GET /staff lists them." % p[0]}}
		return {"status": 200, "body": Level5Data.staff_json(s)}, "hr")
	a.route("GET", "/swipes", func(_p):
		return {"status": 200, "body": {"swipes": swipes.duplicate(true)}}, "hr")
	a.route("GET", "/swipes/:badge", func(p):
		var badge := str(p[0]).to_upper()
		if badge.begins_with("VIS-") and not issued.has(badge):
			return {"status": 404, "body": {"error": "No visitor badge %s was issued tonight." % badge}}
		if not badge.begins_with("VIS-") and _staff(badge).is_empty():
			return {"status": 404, "body": {"error": "No badge %s. GET /staff lists the staff badges." % badge}}
		var mine := swipes.filter(func(s): return s.badge == badge)
		var holder: String = "Visitor (%s)" % data.company if badge.begins_with("VIS-") else _staff(badge).name
		return {"status": 200, "body": {"badge": badge, "holder": holder, "swipes": mine}}, "hr")
	a.route("GET", "/circuits", func(_p):
		return {"status": 200, "body": {"panel": "PANEL 9", "limit_amps": data.limit, "load_amps": _load(), "circuits": circuits.keys().map(func(id): return circuits[id].duplicate())}}, "facilities")
	a.route("GET", "/circuits/:id", func(p):
		var id := str(p[0]).to_upper()
		if not circuits.has(id):
			return {"status": 404, "body": {"error": "No circuit %s on this panel. GET /circuits lists them." % p[0]}}
		return {"status": 200, "body": circuits[id].duplicate()}, "facilities")
	a.route("PATCH", "/circuits/:id", func(p, req):
		var id := str(p[0]).to_upper()
		if not circuits.has(id):
			return {"status": 404, "body": {"error": "No circuit %s on this panel. GET /circuits lists them." % p[0]}}
		var bad := FacilityAPI.check_fields(req.body, {"on": TYPE_BOOL})
		if bad != "":
			return {"status": 400, "body": {"error": bad}}
		var c: Dictionary = circuits[id]
		var want: bool = req.body.on
		if want and not c.on:
			if str(c.note).begins_with("LOCKED OUT"):
				return {"status": 409, "body": {"error": "%s is locked out: %s" % [id, c.note]}}
			if id == "C9-06":
				return {"status": 409, "body": {"error": "%s has a night interlock. %s restarts on a logged work order, not from the panel." % [id, data.ahu]}}
			if _load() + int(c.amps) > int(data.limit):
				return {"status": 409, "body": {"error": "Panel 9 is at %d A of %d A at night; %s needs %d A. Turn something off first." % [_load(), data.limit, c.circuit, c.amps]}}
		c.on = want
		return {"status": 200, "body": c.duplicate()}, "facilities")
	a.route("GET", "/work_orders", func(_p):
		return {"status": 200, "body": {"work_orders": orders.duplicate(true)}}, "facilities")
	a.route("GET", "/work_orders/:id", func(p):
		for o in orders:
			if o.id == str(p[0]).to_upper():
				return {"status": 200, "body": o.duplicate()}
		return {"status": 404, "body": {"error": "No work order %s. GET /work_orders lists them." % p[0]}}, "facilities")
	a.route("POST", "/work_orders", func(_p, req):
		var bad := FacilityAPI.check_fields(req.body, {"floor": TYPE_INT, "unit": TYPE_STRING, "fault": TYPE_STRING})
		if bad != "":
			return {"status": 400, "body": {"error": bad}}
		var o := {"id": "WO-9%03d" % (143 + orders.size()), "floor": req.body.floor, "unit": str(req.body.unit).to_upper(), "fault": req.body.fault, "logged": floor_time(), "status": "open"}
		orders.append(o)
		return {"status": 201, "body": o.duplicate()}, "facilities")
	a.route("GET", "/doors", func(_p):
		return {"status": 200, "body": {"doors": db.run_silent("SELECT id, name, locked, actuator_fault FROM doors WHERE zone = '9' ORDER BY id").map(_door_json)}}, "doors")
	a.route("GET", "/doors/:id", func(p):
		var rows := db.run_silent("SELECT id, name, locked, actuator_fault FROM doors WHERE zone = '9' AND id = '%s'" % str(p[0]).to_upper().replace("'", ""))
		if rows.is_empty():
			return {"status": 404, "body": {"error": "No door %s on this floor. GET /doors lists them." % p[0]}}
		return {"status": 200, "body": _door_json(rows[0])}, "doors")
	a.route("PATCH", "/doors/:id", func(p, req):
		var id := str(p[0]).to_upper().replace("'", "")
		var rows := db.run_silent("SELECT id, name, locked, actuator_fault FROM doors WHERE zone = '9' AND id = '%s'" % id)
		if rows.is_empty():
			return {"status": 404, "body": {"error": "No door %s on this floor. GET /doors lists them." % p[0]}}
		var bad := FacilityAPI.check_fields(req.body, {"locked": TYPE_BOOL})
		if bad != "":
			return {"status": 400, "body": {"error": bad}}
		if int(rows[0].actuator_fault) == 1 and not req.body.locked:
			return {"status": 409, "body": {"error": "%s: the lock has no power (circuit C9-04). It holds shut." % id}}
		db.run_silent("UPDATE doors SET locked = %d WHERE id = '%s'" % [1 if req.body.locked else 0, id])
		db.sync_world()
		return {"status": 200, "body": _door_json(db.run_silent("SELECT id, name, locked, actuator_fault FROM doors WHERE id = '%s'" % id)[0])}, "doors")
	a.route("GET", "/escorts", func(_p):
		return {"status": 200, "body": {"escorts": escorts.duplicate(true)}}, "hr")
	a.route("POST", "/escorts", func(_p, req):
		var bad := FacilityAPI.check_fields(req.body, {"badge": TYPE_STRING, "escort": TYPE_STRING})
		if bad != "":
			return {"status": 400, "body": {"error": bad}}
		var badge := str(req.body.badge).to_upper()
		var escort := str(req.body.escort).to_upper()
		var s := _staff(badge)
		if s.is_empty():
			return {"status": 404, "body": {"error": "No staff badge %s. GET /staff lists them." % badge}}
		if not issued.has(escort):
			return {"status": 400, "body": {"error": "\"escort\" should be a visitor badge issued tonight (yours is clipped on)."}}
		var last := _last_swipe(badge)
		if s.note.begins_with("Badge reported lost") or s.note.begins_with("Badge not returned") or last.is_empty():
			return {"status": 401, "body": {"error": "Badge %s did not answer the reader. No pass logged." % badge}}
		if last.reader == "G-LOBBY" and last.dir == "OUT":
			return {"status": 409, "body": {"error": "Badge %s is off site (last swipe %s OUT %s). No pass logged." % [badge, last.reader, last.time]}}
		for e in escorts:
			if e.badge == badge:
				return {"status": 409, "body": {"error": "Badge %s already has a pass (%s)." % [badge, e.id]}}
		var e := {"id": "EP-%02d" % (escorts.size() + 1), "badge": badge, "name": s.name, "escort": escort, "from": last.reader, "logged": floor_time()}
		escorts.append(e)
		return {"status": 201, "body": e.duplicate()}, "hr")
	return a


func _staff(badge: String) -> Dictionary:
	for s in data.staff:
		if s.id == badge.to_upper():
			return s
	return {}


func _last_swipe(badge: String) -> Dictionary:
	var last := {}
	for s in swipes:
		if s.badge == badge:
			last = s
	return last


## The panel's load now: the amps of every circuit that's on.
func _load() -> int:
	var total := 0
	for id in circuits:
		if circuits[id].on:
			total += int(circuits[id].amps)
	return total


func _door_json(row: Dictionary) -> Dictionary:
	return {"id": row["id"], "name": row["name"], "locked": int(row["locked"]) == 1, "powered": int(row["actuator_fault"]) == 0}


## The request's path, lowercased: the services answer /STAFF and /staff alike, so the
## stations read them alike.
static func _path_of(line: String) -> String:
	var first := line.strip_edges().get_slice("\n", 0).strip_edges()
	var parts := first.split(" ", false)
	return parts[1].trim_suffix("/").to_lower() if parts.size() > 1 else ""


static func _method_of(line: String) -> String:
	return line.strip_edges().get_slice("\n", 0).strip_edges().get_slice(" ", 0).to_upper()


# --- What the stations want ----------------------------------------------------------------

func _power_ok() -> bool:
	return circuits["C9-01"].on and circuits["C9-04"].on and _load() <= int(data.limit)


func _shows_circuit_on(body: Variant, id: String) -> bool:
	if not body is Dictionary:
		return false
	if body.get("id", "") == id:
		return bool(body.get("on", false))
	for c in body.get("circuits", []):
		if c.get("id", "") == id and bool(c.get("on", false)):
			return true
	return false


## A work order for this floor's air handler has been logged.
func _air_ok() -> bool:
	for o in orders:
		if o.unit == data.ahu and int(o.floor) == 9:
			return true
	return false


func _shows_order(body: Variant) -> bool:
	if not body is Dictionary:
		return false
	if str(body.get("unit", "")) == data.ahu:
		return true
	for o in body.get("work_orders", []):
		if str(o.get("unit", "")) == data.ahu:
			return true
	return false


## Both night-shifters have a pass and are out (_send_out ran: the pass was logged
## with their door open, or their door opened after the pass). A door opened to look
## and locked again before the pass leaves them hiding, and the station waiting.
func _passes_ok() -> bool:
	for s in data.night:
		if not escorts.any(func(e): return e.badge == s.id) or not out.has(s.id):
			return false
	return true


## This machine's own visitor badge, as the escort on a pass (the first one issued
## when the badge isn't known, as in tests).
func _my_badge() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var game: Node = tree.root.get_node_or_null("Game") if tree else null
	var mine := str(game.visitor_badge_no) if game else ""
	return mine if issued.has(mine) else "VIS-01"


## The passes ladder: the review ladder (shape, then exactly what to type), or ladder
## A with where-in-the-world between when POST wasn't practised at the work order.
## The last tier types this run's door unlocks and both passes, in any order.
func _passes_hints() -> void:
	var key: String = data.keys.hr
	var hr_key := "X-Api-Key: %s" % key
	var shape: String = "the shape, with the staffer's badge left as enter_badge:\n" + \
		"    [color=#ffffff]POST /escorts\nX-Api-Key: %s\n\n{\"badge\": \"enter_badge\", \"escort\": \"enter_your_badge\"}[/color]\n" % key + \
		"enter_badge is a night-shifter's badge, enter_your_badge your own visitor badge (the one clipped on; GET /swipes lists every badge tonight). " + \
		"the readers have the real ones on the floor: GET /swipes/enter_badge says where. the faces at the desks carry badges that don't answer."
	if passes_ladder == "a":
		shape = "the shape, with the staffer's badge left as enter_badge:\n" + \
			"    [color=#ffffff]POST /escorts\nX-Api-Key: %s\n\n{\"badge\": \"enter_badge\", \"escort\": \"enter_your_badge\"}[/color]\n" % key + \
			"  POST /escorts   ask Personnel to log a new pass (it makes one)\n" + \
			"  X-Api-Key: ...   the header, then an empty line\n" + \
			"  {...}   the body: JSON, the two fields the procedure shows, both text in double quotes\n" + \
			"enter_badge is a night-shifter's badge, enter_your_badge your own visitor badge (the one clipped on). 201 means the pass was logged; 401 means that badge never answered a reader."
	var where: String = "the night shift is in the staff list (GET /staff). the readers say which door each one is behind: GET /swipes/enter_badge, their last swipe. " + \
		"a locked door opens through the doors service: PATCH /doors/enter_door with {\"locked\": false}. the faces at the desks carry badges that don't answer a reader."
	var exact := "type these, Enter twice after each, in any order (the escort is your own visitor badge):\n"
	for s in data.night:
		exact += "    [color=#ffffff]PATCH /doors/%s\n%s\n\n{\"locked\": false}[/color]\n" % [s.hide.door, hr_key]
	for s in data.night:
		exact += "    [color=#ffffff]POST /escorts\n%s\n\n{\"badge\": \"%s\", \"escort\": \"%s\"}[/color]\n" % [hr_key, s.id, _my_badge()]
	exact += "a pass logged first sends them out as soon as their door opens."
	passes_puzzle.hints = [shape, where, exact] if passes_ladder == "a" else [shape, exact]


## Both night-shifters passed and out, and every door opened tonight is locked again
## (a door opened for a look and locked again before the passes isn't the lockup).
func _lockup_ok() -> bool:
	return _passes_ok() and not doors_opened.is_empty() and db.run_silent("SELECT 1 FROM doors WHERE zone = '9' AND locked = 0").is_empty()


## The doors read back: one door's record, or the whole list. Each door read back
## locked is remembered, so the lockup can be read back a door at a time; it passes
## once every door opened tonight has been.
func _shows_locked(body: Variant) -> bool:
	if not body is Dictionary:
		return false
	if body.has("locked"):
		if bool(body.locked):
			read_back[str(body.get("id", ""))] = true
	else:
		for d in body.get("doors", []):
			if bool(d.get("locked", false)):
				read_back[str(d.get("id", ""))] = true
	for id in doors_opened:
		if not read_back.has(id):
			return false
	return true


## The radio's claim, against the log: the voice's badge read back shows it somewhere
## else (co-op), or no such badge was issued (solo, Maddison). The whole log counts too.
func _exposes_lure(line: String, res: Dictionary) -> bool:
	if lures == 0:
		return false
	var path := _path_of(line).to_upper()
	if path == "/SWIPES":
		return res.status == 200
	if path == "/SWIPES/" + lure_badge:
		return res.status == 200 or res.status == 404
	return false


## The lockup ladder's last tier: one PATCH per door still open, then the read-back.
func _lockup_hints() -> void:
	var fixes := PackedStringArray()
	if db:
		for row in db.run_silent("SELECT id FROM doors WHERE zone = '9' AND locked = 0 ORDER BY id"):
			fixes.append("    [color=#ffffff]PATCH /doors/%s\nX-Api-Key: %s\n\n{\"locked\": true}[/color]" % [row["id"], data.keys.hr])
	var read_back_all := "    [color=#ffffff]GET /doors\nX-Api-Key: %s[/color]" % data.keys.hr
	lockup_puzzle.hints = [
		"the shape, with the door left as enter_door:\n" +
		"    [color=#ffffff]PATCH /doors/enter_door\nX-Api-Key: %s\n\n{\"locked\": true}[/color]\n" % data.keys.hr +
		"enter_door is each door opened tonight. GET /doors shows which are still open.",
		("type these, Enter twice after each:\n" + "\n".join(fixes) + "\nthen read them back:\n" + read_back_all) if not fixes.is_empty() else
			"every door on the floor is locked. read them back, then Enter twice:\n" + read_back_all,
	]


## The swipes ladder's last tier, once the voice has claimed a badge.
func _lure_hints() -> void:
	swipes_puzzle.hints[1] = "type this, then Enter twice:\n" + \
		"    [color=#ffffff]GET /swipes/%s\nX-Api-Key: %s[/color]\n" % [lure_badge, data.keys.hr] + \
		"the voice said the loading door. the log says where that badge really is."


# --- Terminals --------------------------------------------------------------------------

func puzzles() -> Array:
	return [key_puzzle, circuits_puzzle, check_circuits_puzzle, air_puzzle, check_air_puzzle, swipes_puzzle, passes_puzzle, lockup_puzzle, check_lockup_puzzle, vale_puzzle]


## Host: a request went through at `which` terminal. Its station checks, and what
## it set off, play out on every machine.
func _on_request(line: String, res: Dictionary, _ui: TerminalUI, which: String) -> void:
	var path := _path_of(line).to_upper()
	var method := _method_of(line)
	var status := int(res.status)
	var term: Terminal = _terminal(which)
	for p in term.puzzles:
		if not p.solved and p.request_matches(line, res):
			sync.event("_on_solved", [p.id])
	# The key passes at either terminal (any 200 is the manager's key), and Vale's
	# record is read at either, whichever listed the staff.
	if not key_puzzle.solved and key_puzzle.request_matches(line, res):
		sync.event("_on_solved", ["key"])
	if not vale_puzzle.solved and vale_puzzle.request_matches(line, res):
		sync.event("_on_solved", ["vale"])
	if status == 200 and path == "/STAFF":
		sync.event("_staff_listed")
	if status == 200 and path.begins_with("/SWIPES/VIS-") and issued.has(path.trim_prefix("/SWIPES/")):
		sync.event("_frame_seen", [path.trim_prefix("/SWIPES/")])
	if status == 200 and method == "PATCH" and path.begins_with("/CIRCUITS/"):
		sync.event("_circuits_changed", [path.trim_prefix("/CIRCUITS/")])
	if status == 200 and method == "PATCH" and path.begins_with("/DOORS/"):
		sync.event("_door_changed", [path.trim_prefix("/DOORS/"), bool(res.body.get("locked", true))])
	if status == 201 and path == "/WORK_ORDERS" and str(res.body.get("unit", "")) == data.ahu and not air_on:
		sync.event("_air_on")
	if status == 201 and path == "/ESCORTS":
		sync.event("_passed", [str(res.body.get("badge", ""))])
	# SYSOP's tips, each once: text only, and never the answer. A 401 from the badge
	# reader (a pass for a badge that never swiped in) isn't a key problem; it's the
	# Mimic tip only when the badge is one off a Mimic's lanyard (Vale's gets no tip).
	var keyed := line.to_lower().contains(FacilityAPI.KEY_HEADER)
	var error := str(res.body.get("error", "")) if res.body is Dictionary else ""
	var reader_401 := status == 401 and path == "/ESCORTS" and error.contains("did not answer the reader")
	_tip_if(status == 401 and not keyed, "header", which)
	_tip_if(status == 403, "temp", which)
	_tip_if(status == 401 and keyed and not reader_401, "wrong_key", which)
	_tip_if(status == 409 and path.begins_with("/CIRCUITS/") and str(res.body.get("error", "")).contains("Turn something off"), "load", which)
	_tip_if(status == 404 and path.begins_with("/CIRCUITS/C14"), "example", which)
	_tip_if(status == 201 and path == "/WORK_ORDERS" and str(res.body.get("unit", "")) == data.example_order.unit, "unit", which)
	_tip_if(status == 201 and path == "/WORK_ORDERS" and str(res.body.get("unit", "")) == data.ahu, "verify", which)
	_tip_if(reader_401 and Level5Data.LOST.any(func(l): return error.contains(l.id)), "mimic", which)
	_tip_if(status == 409 and path == "/ESCORTS" and str(res.body.get("error", "")).contains("off site"), "off_site", which)


## A SQL read at either terminal (the database is read-only; looking is free). The
## doors table read back counts as the lockup's read-back too.
func _on_query(sql: String, result: Dictionary, _ui: TerminalUI, _which: String) -> void:
	if not result.get("ok", false) or not check_lockup_puzzle or check_lockup_puzzle.solved or lockup_puzzle == null:
		return
	if lockup_puzzle.solved and sql.to_lower().contains("doors") and _shows_locked({"doors": result.get("rows", []).map(func(r): return {"id": str(r.get("id", "")), "locked": int(r.get("locked", 0)) == 1})}):
		sync.event("_on_solved", ["check_lockup"])


func _tip_if(when: bool, id: String, which: String) -> void:
	if when and not tips_sent.has(id):
		sync.event("_tip", [id, which])


## Every machine: a line from SYSOP on the screen the request was typed at (once per tip).
func _tip(id: String, which: String) -> void:
	if tips_sent.has(id):
		return
	tips_sent[id] = true
	_terminal(which).print_line(TerminalUI.sysop(TEXT["tip_" + id]))


func _terminal(which: String) -> Terminal:
	return panel if which == "panel" else hr


## Every machine: a station's check passed.
func _on_solved(id: String) -> void:
	for p in puzzles():
		if p.id == id:
			p.solved = true
	match id:
		"key":
			Game.open_case("key", CASES.key)
			Game.solve_case("key", TEXT.key_done)
			if not power_back:
				hud.todo(TEXT.todo_power)
			if sync.is_host():
				_lure_after(lure_delay_propped if propped else lure_delay)
		"circuits":
			Game.open_case("power", CASES.power)
			Game.solve_case("power", TEXT.power_done % data.limit)
		"air":
			Game.open_case("air", CASES.air)
			var mine := orders.filter(func(o): return o.unit == data.ahu)
			Game.solve_case("air", TEXT.air_done % (mine[0].id if not mine.is_empty() else "logged"))
		"swipes":
			Game.open_case("radio", CASES.radio)
			if lure_peer > 0:
				Game.solve_case("radio", TEXT.radio_done % _name_of(lure_peer))
			else:
				Game.solve_case("radio", TEXT.radio_done_solo % lure_badge)
			_warden(["l5_radio_checked", "l5_radio_checked_tease"])
			if _todo_is(TEXT.todo_radio):
				hud.todo(_next_todo())
		"passes":
			if _lockup_ok():
				_on_solved("lockup")  # every door opened tonight is already locked again
			elif not lockup_puzzle.solved:
				_tip("lockup", "hr")
		"check_lockup":
			_check_done()
		"vale":
			Game.open_case("vale", CASES.vale)
			Game.solve_case("vale", TEXT.vale_done % Level5Data.VALE.edited_by)
	if id in ["passes", "lockup", "check_lockup"]:
		_check_done()


func _todo_is(text: String) -> bool:
	return Game.current_todo() == text


## What the notebook should say next, from what's left on the floor: the power, the
## air, the people (once the procedure has been read), the stairs; or nothing.
func _next_todo() -> String:
	if not key_puzzle.solved:
		return TEXT.todo_key if Game.case_info("key").get("open", false) else TEXT.todo_arrive
	if not power_back:
		return TEXT.todo_power
	if not (air_on or air_cleared):
		return TEXT.todo_air
	if released:
		return TEXT.todo_down
	if Game.case_info("people").get("open", false):
		return TEXT.todo_people
	return ""


## Every machine: a paper opened a case.
func _ask(case_id: String) -> void:
	Game.open_case(case_id, CASES[case_id])
	match case_id:
		"key":
			if not key_puzzle.solved:
				hud.todo(TEXT.todo_key)
		"power":
			if key_puzzle.solved and not power_back:
				hud.todo(TEXT.todo_power)
		"air":
			if key_puzzle.solved and power_back and not air_on and not air_cleared:
				hud.todo(TEXT.todo_air)
		"people":
			if passes_ladder == "":
				# POST practised at the work order: the review ladder. Skipped (the stair
				# door propped instead): ladder A, the word is new here.
				passes_ladder = "review" if _air_ok() else "a"
				_passes_hints()
			if key_puzzle.solved and not released and not _todo_is(TEXT.todo_radio):
				hud.todo(TEXT.todo_people)


## Every machine: the staff were listed. Vale's row is in it, so her case opens.
func _staff_listed() -> void:
	Game.open_case("vale", CASES.vale)


## Every machine: a crew badge's log was read: our badges were in Vale's lab.
func _frame_seen(badge: String) -> void:
	var at := ""
	for s in swipes:
		if s.badge == badge and s.reader == "LAB-B":
			at = s.time
	Game.open_case("frame", CASES.frame)
	if at != "" and not Game.case_info("frame").get("solved", false):
		Game.solve_case("frame", TEXT.frame_done % at)
		get_node("/root/Net").earn("achievement:framed", hud)


# --- The book -----------------------------------------------------------------------------

## Every machine: somebody took Acceptable API's off the training shelf. Its find
## and open lines, in their voice; then any chapter a paper has already called for.
func _book_found(peer_id: int) -> void:
	if book_found:
		return
	book_found = true
	book.enabled = false
	book.visible = false
	if peer_id == players.id_of(player):
		hud.notice(TEXT.book_taken, 5.0)
	sync.unlock_for([peer_id], "achievement:acceptable_apis_pickup")
	await _crew_line("l5_book_find", peer_id)
	await _crew_line("l5_book_open", peer_id)
	var waiting := pending_chapters.duplicate()
	pending_chapters.clear()
	for id in waiting:
		_book_huddle(id)


## Every machine: a paper brings up its chapter of Acceptable API's, read on the
## spot (once per run). Before the book is found the chapter waits for it. The
## Mimics and the Custodian stand still while the crew reads.
func _book_huddle(id: String) -> void:
	if Huddle.of(self).done.has(id):
		return
	if not book_found:
		if not pending_chapters.has(id):
			pending_chapters.append(id)
		return
	_huddles += 1
	_freeze_people(true)
	await Huddle.of(self).run(id, Huddle.HERE)
	_huddles -= 1
	if _huddles == 0:
		_freeze_people(false)


func _freeze_people(still: bool) -> void:
	if not sync.is_host():
		return
	for m in mimics:
		m.set_physics_process(not still)
	if custodian:
		custodian.set_physics_process(not still)


## A crew line in the voice of the player who says it, their name on the subtitle.
func _crew_line(id: String, peer_id: int) -> void:
	var l := VoiceLines.get_line(id)
	if l.is_empty():
		return
	var dur: float = _radio_voice.play(id, _voice_dir(peer_id)) if _radio_voice else 0.0
	await hud.say(_name_of(peer_id), l.text, dur if dur > 0.0 else Voice.read_time(l.text))


## A peer's name as the roster has it (the local player's too).
func _name_of(peer_id: int) -> String:
	var net := get_node_or_null("/root/Net")
	return net.display_name(peer_id) if net else "Crew"


## The recordings folder for a peer's crew member ("crew_dana"), or "" for none.
func _voice_dir(peer_id: int) -> String:
	var net := get_node_or_null("/root/Net")
	if net == null:
		return ""
	var slug := str(net.look_of(peer_id, maxi(NetPlayers.index_of(peer_id, multiplayer), 0)).get("crew", ""))
	return VoiceLines.crew_dir(slug) if slug != "" else ""


# --- Power and air ----------------------------------------------------------------------

## Every machine: a circuit changed through the service. The lights follow their
## circuits, the cage's lock gets its power back, and the copiers wind down.
func _circuits_changed(id: String) -> void:
	var c: Dictionary = circuits.get(id, {})
	if c.is_empty():
		return
	match id:
		"C9-01":
			db.run_silent("UPDATE lights SET is_on = %d, status = 'ok' WHERE id IN ('L9-PAY', 'L9-STORE')" % int(c.on))
		"C9-04":
			db.run_silent("UPDATE lights SET is_on = %d, status = 'ok' WHERE id = 'L9-CAGE'" % int(c.on))
			db.run_silent("UPDATE doors SET actuator_fault = %d WHERE id = 'PERS-CAGE'" % int(not c.on))
		"C9-03":
			if not c.on:
				hud.notice(TEXT.copiers_off, 3.0)
	db.sync_world()
	if not power_back and _power_ok():
		power_back = true
		circuits_puzzle.solved = true
		hud.notice(TEXT.power_back, 5.0)
		_warden(["l5_power_back", "l5_power_back_tease"])
		if _todo_is(TEXT.todo_power):
			hud.todo(_next_todo())
		_custodian_clock()


## Host: the practice is safe. Once the power is back and the air is on or cleared,
## the Custodian (if loose) starts up the dock stairs towards the passes and the
## lockup. It also starts (`engaged`) the moment the crew is at those stations (the
## first pass logged or a hiding door opened), so a crew that never fixes the air
## still meets it.
func _custodian_clock(engaged := false) -> void:
	if custodian_timed or custodian == null or sync == null or not sync.is_host():
		return
	if engaged or (power_back and (air_on or air_cleared)):
		custodian_timed = true
		_custodian_after(custodian_delay)


## Every machine: someone is forcing the lights breaker by hand, behind the vending
## machines. It takes a while, in the dark.
func _hand_reset_started(peer_id: int) -> void:
	if hand_reset or circuits["C9-01"].on:
		return
	if peer_id == players.id_of(player):
		hud.notice(TEXT.hand_reset, 4.0)
	if sync.is_host():
		_hand_reset_after(hand_reset_time)


func _hand_reset_after(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
	if is_inside_tree() and not hand_reset and not circuits["C9-01"].on:
		sync.event("_hand_reset")


## Every machine: the breaker goes over. The panel's main trips its heaviest load
## (the copiers) and the lights come on; the cage lock still wants the service.
func _hand_reset() -> void:
	hand_reset = true
	cupboard.enabled = false
	circuits["C9-03"].on = false
	circuits["C9-01"].on = true
	hud.notice(TEXT.hand_reset_done, 5.0)
	_circuits_changed("C9-03")
	_circuits_changed("C9-01")


## Every machine: a work order for AHU-9 was logged. The air handler spins up.
func _air_on() -> void:
	if air_on:
		return
	air_on = true
	air_puzzle.solved = true
	hud.notice(TEXT.air_back, 5.0)
	_warden(["l5_air_back", "l5_air_back_tease"])
	if _todo_is(TEXT.todo_air):
		hud.todo(_next_todo())
	_custodian_clock()


## Every machine: the carbon copy has shown how the air comes back. From here the air
## counts against the crew (host: _process), after a grace long enough to type it.
func _air_armed() -> void:
	air_armed = true


## Host, each frame: while the air is off and no chapter is being read, the clock
## runs; after the grace everyone on the floor takes a little each tick. Deaths
## explain themselves (the cause is "air"). Not before the power is back either: the
## panel's practice stays safe whichever paper was read first.
func _air_clock(delta: float) -> void:
	if not air_armed or not power_back or air_on or air_cleared or released or _huddles > 0:
		return
	_air_time += delta
	if _air_time >= air_grace + _air_ticks * air_tick:
		_air_ticks += 1
		sync.event("_air_hurts")


## Every machine: this machine's player breathes the floor's air.
func _air_hurts() -> void:
	if air_on or air_cleared or player == null:
		return
	if not tips_sent.has("air_thick"):
		tips_sent["air_thick"] = true
		hud.notice(TEXT.air_thick, 5.0, ThemeUtil.RED)
	if player.health > 0.0:
		player.take_damage(AIR_DAMAGE, "air")


## Every machine: the stair door is propped. The stairwell's air clears the floor,
## slowly, and the voice on the radio comes sooner.
func _propped() -> void:
	if propped:
		return
	propped = true
	prop.enabled = false
	hud.notice(TEXT.propped, 3.0)
	if sync.is_host():
		_clear_after(prop_time)


func _clear_after(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
	if is_inside_tree() and not air_on and not air_cleared:
		sync.event("_air_cleared")


func _air_cleared() -> void:
	air_cleared = true
	hud.notice(TEXT.air_cleared, 5.0)
	if _todo_is(TEXT.todo_air):
		hud.todo(_next_todo())
	_custodian_clock()


# --- The radio -----------------------------------------------------------------------------

## Host: once the HR service answers, the radio lies after a while: a teammate's
## voice (solo: Maddison's), asking for the loading door.
func _lure_after(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
	if not is_inside_tree() or lures > 0 or dock_opened or released:
		return
	var ids: Array = players.all_ids()
	ids.sort()
	var peer := 0
	var badge := "VIS-%02d" % (ids.size() + 1)
	if ids.size() > 1:
		var rng := RandomNumberGenerator.new()
		rng.seed = Game.run_seed * 31 + 9
		peer = ids[rng.randi_range(0, ids.size() - 1)]
		badge = "VIS-%02d" % (ids.find(peer) + 1)
	sync.event("_lure", [peer, badge, 1])
	await get_tree().create_timer(lure_again, false).timeout
	if is_inside_tree() and not dock_opened and not swipes_puzzle.solved and not released:
		sync.event("_lure", [peer, badge, 2])


## Every machine: the voice on the walkie. `peer` is who it sounds like (0 for
## Maddison), in their own recorded voice and with their name on the subtitle.
func _lure(peer: int, badge: String, n: int) -> void:
	lure_peer = peer
	lure_badge = badge
	lures = n
	var id: String = LURE_LINES[n]["maddison" if peer == 0 else "crew"]
	if n == 1:
		swipes_puzzle.solved = false
		swipes_puzzle.hint_index = 0
		_lure_hints()
		Game.open_case("radio", CASES.radio)
		if not released:
			hud.todo(TEXT.todo_radio)
		_tip("lure", "hr")
	var l := VoiceLines.get_line(id)
	if l.is_empty():
		return
	var who: String = "MADDISON" if peer == 0 else _name_of(peer)
	var dur: float = _radio_voice.play(id, _voice_dir(peer) if peer > 0 else "") if _radio_voice else 0.0
	hud.say(who, l.text, dur if dur > 0.0 else Voice.read_time(l.text))


## Every machine: a Mimic was looked at and left.
func _mimic_left(_name: String) -> void:
	if not tips_sent.has("mimic_leaves"):
		tips_sent["mimic_leaves"] = true
		hud.notice(TEXT.mimic_leaves, 4.0)


# --- Doors, passes and the lockup ---------------------------------------------------------

## Every machine: a floor-9 door changed through the service. Opened, it's on the
## lockup's list; the loading door opened is the voice's reward; a hiding place
## opened shows the real staffer, who leaves once passed.
func _door_changed(id: String, locked: bool) -> void:
	var name_row := db.run_silent("SELECT name FROM doors WHERE id = '%s'" % id)
	var door_name: String = str(name_row[0]["name"]) if not name_row.is_empty() else id
	if not locked:
		doors_opened[id] = true
		read_back.erase(id)
		hud.notice(TEXT.door_opens % door_name, 3.0)
		if id == "PERS-DOCK":
			_dock_opened()
		if Level5Data.HIDES.any(func(h): return h.door == id):
			_custodian_clock(true)  # the crew is at the hiding places now
		for badge in staffers:
			if passed.has(badge) and _hide_door(badge) == id:
				_send_out(badge)
	else:
		hud.notice(TEXT.door_locks % door_name, 3.0)
	_lockup_hints()
	if not passes_puzzle.solved and _passes_ok():
		_on_solved("passes")  # both passed; this door let the last one out
	if lockup_puzzle.solved and not _lockup_ok():
		lockup_puzzle.solved = false  # opened again after the lockup: lock it again
		check_lockup_puzzle.solved = false
	if not lockup_puzzle.solved and passes_puzzle.solved and _lockup_ok():
		_on_solved("lockup")


## The doors table's word on a floor-9 door (a sliding door's node doesn't track its lock).
func _door_unlocked(id: String) -> bool:
	var rows := db.run_silent("SELECT locked FROM doors WHERE id = '%s'" % id)
	return not rows.is_empty() and int(rows[0]["locked"]) == 0


func _hide_door(badge: String) -> String:
	for s in data.night:
		if s.id == badge:
			return s.hide.door
	return ""


## Every machine: the loading door is open. Nobody is there: a black shaft and cold
## air. Not sealed on 10, the Custodian comes up now.
func _dock_opened() -> void:
	if dock_opened:
		return
	dock_opened = true
	hud.notice(TEXT.dock_opens, 6.0, ThemeUtil.RED)
	_warden(["l5_dock_open", "l5_dock_open_tease"])
	if custodian and not custodian_here and sync.is_host():
		sync.event("_custodian_arrives")


## Every machine: an escort pass was logged. The staffer gets up, if their door is open.
func _passed(badge: String) -> void:
	if passed.has(badge) or not staffers.has(badge):
		return
	passed[badge] = true
	Game.open_case("people", CASES.people)
	for s in data.night:
		if s.id == badge:
			hud.line(s.line)
	_custodian_clock(true)  # the crew is at the passes now
	if _door_unlocked(_hide_door(badge)):
		_send_out(badge)
	if not passes_puzzle.solved and _passes_ok():
		_on_solved("passes")


## Every machine: a passed night-shifter's door is open. They get up and head for the
## stairs (once), and count as out for the passes station. A loose Custodian starts
## up the dock stairs now if it hasn't already.
func _send_out(badge: String) -> void:
	if out.has(badge):
		return
	out[badge] = true
	var st: Staffer = staffers.get(badge)
	if st:
		var n: int = data.night.map(func(s): return s.id).find(badge)
		st.rescue(to_global(WAIT_AT[maxi(n, 0)]))
		if hud:
			hud.notice(TEXT.staffer_passed % st.first_name, 4.0)
	_custodian_clock(true)


## Every machine: both passed, everything locked and read back. The stairs release.
func _check_done() -> void:
	if released or not (passes_puzzle.solved and lockup_puzzle.solved and check_lockup_puzzle.solved):
		return
	released = true
	stair_out.locked = false
	var n: Array = data.night
	Game.open_case("people", CASES.people)
	Game.solve_case("people", TEXT.people_done % [n[0].first, n[0].hide.place, n[1].first, n[1].hide.place])
	hud.notice(TEXT.stairs_release, 4.0)
	hud.todo(TEXT.todo_down)
	_warden(["l5_secured", "l5_secured_tease"])


# --- The Custodian ------------------------------------------------------------------------

func _custodian_after(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
	if is_inside_tree() and custodian and not custodian_here and not released:
		sync.event("_custodian_arrives")


## Every machine: it's come up the dock stairs. The loading door gives, and it's loose
## on the floor (an opened door more for the lockup).
func _custodian_arrives() -> void:
	if custodian_here or custodian == null:
		return
	custodian_here = true
	hud.notice(TEXT.custodian_comes, 4.0, ThemeUtil.RED)
	db.run_silent("UPDATE doors SET locked = 0 WHERE id = 'PERS-DOCK'")
	db.sync_world()
	doors_opened["PERS-DOCK"] = true
	_lockup_hints()
	custodian.activate()
	if sync.is_host():
		custodian.global_position = to_global(Vector3(6, 0, -27))
		custodian.set_bay(to_global(SHAFT_AT))
	hud.notice(TEXT.custodian_in, 4.0, ThemeUtil.RED)


## Every machine watches its own player for the drop (a Trigger fires on the host
## only); the host keeps the air's clock.
func _process(delta: float) -> void:
	if player and player.health > 0.0 and player.is_inside_tree() and _in_shaft(to_local(player.global_position)):
		_fell()
	if sync and sync.is_host():
		_air_clock(delta)


## Is this level-space point out over the dock shaft?
func _in_shaft(p: Vector3) -> bool:
	return absf(p.x - SHAFT_AT.x) < 2.8 and absf(p.z - SHAFT_AT.z) < 1.6 and p.y < 1.0


## This machine's player stepped off the landing past the loading door: hurt, and
## back on the landing (the shaft is the Custodian's way up, not the crew's way down).
func _fell() -> void:
	player.take_damage(40.0, "shaft")
	hud.notice(TEXT.shaft, 4.0, ThemeUtil.RED)
	if player.health > 0.0:
		player.respawn(global_transform * Transform3D(Basis(), Vector3(6, 0.1, -26.5)))


# --- The way down -------------------------------------------------------------------------

## Host: a badge reader at a doorway saw a player go through.
func _on_reader(body: Node, reader: String) -> void:
	var id := players.id_of(body)
	if id <= 0:
		return
	var badge := "VIS-%02d" % (NetPlayers.index_of(id, multiplayer) + 1)
	var last := _last_swipe(badge)
	if last.get("reader", "") == reader:
		return
	sync.event("_swipe", [badge, reader, floor_time()])


## Every machine: a swipe goes in the log.
func _swipe(badge: String, reader: String, time: String) -> void:
	swipes.append({"badge": badge, "reader": reader, "dir": "IN", "time": time})


## Every machine: everyone is on STAIR 2. The radio crackles once more, then down.
func _on_exit() -> void:
	get_node("/root/Net").earn("achievement:floor_9", hud)
	if lures > 0:
		_lure(lure_peer, lure_badge, 3)
	if not player:
		return
	player.input_locked = true
	await get_tree().create_timer(2.5, false).timeout
	if not is_inside_tree():
		return
	await Level2FX.end_card(self, TEXT.end_card)
	Game.completed_level = "level_5"
	Game.next_level = ""
	completed.emit()


func _on_completed() -> void:
	await hud.fade(true, 1.2)
	finish_level("field_notes")


func on_player_died() -> void:
	player.respawn(spawn_point())
