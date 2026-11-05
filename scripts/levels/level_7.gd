extends LevelBase
## Level 7: B2, the building's machine room ("Lights Out"). Act 2's last floor, under
## the cold store. The crew walks down STAIR 2 from B1 into the bottom of the
## building: no windows, low ceilings, cable trays, raised floor tiles. WARDEN's core
## is down here, behind glass, and he knows the crew is below him now. He switches
## the plant ring's lights by zone.
##
## Stations (curriculum B: a function (function, return, async), a list ([ ], length,
## looping over many devices), the test bench and an assertion (assert), and auth
## tokens, looked up, not taught). One case at a time on the board, in order:
##   1. token    the IT admin office: B2's services take tokens, not keys (401). The
##               admin's runbook page says how: POST /auth/token with the key, then
##               Authorization: Bearer <token> on every request. The runbook's own
##               example token ran out long ago; a token runs out after a few minutes.
##   2. restore  the test bench, safe: the admin's printout is a function that lights
##               one zone, and never hands its answer back (no return: the test fails
##               on undefined). Fixed, called once, checked with assert. The bench is a
##               mock of B2's lighting: the same paths and zone ids, its own fake floor.
##   3. zones    still on the bench: every zone, from a list, each one asserted. A list
##               missing a zone leaves it dark (the bench names it); the emergency exit
##               circuit is life safety, not ours (403).
## Next (DRAFT, waiting on Augustine's calls 1, 2 and 4): lights out for real, under
## pressure, and beating WARDEN; then the lifts (GET /lifts, a restart for each car,
## 423 while WARDEN holds the lights, the freight lift's out of service).
## Every station is checked by the state the services are left in, never by code
## text. Every line players read or hear is a DRAFT in plan/approvals/l7-text.md
## until Augustine approves it word for word.
##
## Layout (level space, north is -z):
##   landing      x -4..4,   z 4..8     STAIR 2 (east wall): down from B1, the bottom
##   lift lobby   x -4..4,   z -6..4    lifts 1-4's doors (two come down here), the
##                                      freight lift, the out-of-service stand, the memo
##   motor room   x -10..-4, z -1..4    the lift controller (locked: the lifts case)
##   admin office x 4..14,   z -6..0    the runbook, the admin terminal, the test bench
##   plant ring   x -14..14, z -30..-6  a loop of corridors in six lighting zones
##   net closet   x -11..-5, z -15..-9  WARDEN's uplink (locked: call 1)
##   WARDEN core  x -2..11,  z -25..-11 behind glass, off the ring's east side; seen,
##                                      never entered on this floor (warden-arc)
##
## Co-op: the host decides (WARDEN's cuts, the bench's verdicts, tokens running out)
## and every machine plays it out through sync.event. Typed requests run on every
## machine (LevelSync) and scripts on the host (ScriptHost), so the services change
## the same way everywhere; anything that depends on time is a host timer that comes
## back as an event.

## Player-facing lines. All DRAFT: plan/approvals/l7-text.md. Case titles carry the
## story and how the crew feels; their details say what to do (Augustine 2026-11-05).
const TEXT := {
	"case_token": "Our key's no good down here",
	"case_token_do": "At the IT admin terminal, trade the key for a token and read GET /lights with it",
	"case_restore": "Test it before it touches the building",
	"case_restore_do": "On the test bench, fix the admin's function, light one zone with it and assert it's on",
	"case_zones": "Six zones. Prove the script lights them all",
	"case_zones_do": "On the test bench, light every zone from a list with your function, and assert each one",
	"todo_arrive": "Find the IT admin office, off the lift lobby",
	"todo_floor": "The bench says it works. Next: the real floor",
	"token_done": "B2 answered: %d zones and the emergency circuit. The token lasts %d seconds.",
	"restore_done": "%s lit on the bench, and the test says so. The function hands back its answer now.",
	"zones_done": "All six zones lit on the bench, every one asserted. Tested before it touched the building.",
	"arrive": "No windows. Low ceilings. Somewhere past the lobby, fans roar.",
	"cut": "Down the ring, a zone goes dark.",
	"bench_report": "BENCH: %d of %d zones lit. TESTS PASSED: %d.",
	"bench_dark": "BENCH: still dark: %s",
	"bench_em": "BENCH: emergency circuit refused (life safety). Leave it out.",
	# SYSOP tips (text only, never lies; each fires once per run).
	"tip_key_not_token": "401: B2 changed to tokens at the upgrade. the key still works, but only to ask for a token: POST /auth/token with it.",
	"tip_bearer": "the header wants the word Bearer, a space, then the token: Authorization: Bearer tok_...",
	"tip_example_token": "that's the runbook's example token, off the admin's training slides. it ran out long ago. get one of your own.",
	"tip_expired": "401 expired: tokens only last a few minutes. POST /auth/token again for a fresh one. a script can ask for its own at the top.",
	"tip_other_service": "that token's from the %s. each service gives out its own: ask this one with POST /auth/token.",
	"tip_unknown_token": "this service never gave out that token. copy it exactly, or ask for a new one.",
	"tip_no_return": "the function did its work, but gave nothing back: undefined. the last line inside it should be return res;",
	"tip_no_zone": "restore() was called with nothing in the brackets, so zone was undefined. put a zone id in quotes: restore(\"%s\")",
	"tip_no_assert": "it lit, but nothing checked it. the bench only counts a test: an assert after the call, like assert(answer.body.on, \"lit\").",
	"tip_em": "403: that's the emergency exit circuit. it sits on standby on purpose, and only fire control switches it. leave it out of the list.",
	"tip_lifts_held": "423 locked: the lift controller won't take commands while WARDEN holds the lights.",
}

## The to-dos' titles (the story and how the crew feels; TEXT has their details). DRAFT.
const TASK_TITLES := {
	"todo_arrive": "The bottom of the building",
	"todo_floor": "Now it's real",
}

## The IT admin's runbook page, pinned by the admin terminal: tokens, looked up (no
## chapter; the Act 2 version of a reference card). DRAFT.
const RUNBOOK := [
	"B2 BUILDING SERVICES  -  RUNBOOK  -  p.14  ACCESS",
	"Since the B2 upgrade the services take tokens, not keys.",
	"1. Trade your key for a token:",
	{"text": "POST /auth/token {\"key\": \"<your key>\"}", "hand": false},
	"   The answer's token field is the token. expires_in says how long it lasts, in seconds.",
	"2. Send it on every request, in a header:",
	{"text": "GET /lights", "hand": false},
	{"text": "Authorization: Bearer <token>", "hand": false},
	"   The word Bearer, a space, then the token.",
	"3. Tokens run out. A 401 that says expired: get a fresh one.",
	"Example:",
	{"text": "Authorization: Bearer %s", "hand": false},
	{"text": "(example's from my training slides. it's long dead. key's under the keyboard - G.P.)", "hand": true},
]
## Under the admin's keyboard.
const KEY_STICKY := "B2 svc key: %s  (lights, lifts)"
## The bench's card: what a test bench is, and the rule. DRAFT.
const BENCH_CARD := [
	"TEST BENCH  -  MOCK B2 LIGHTING",
	"Same paths as the floor: /auth/token, /lights. Same zone ids.",
	"Its own fake floor. Nothing here touches the building.",
	"Every run starts with the mock dark.",
	"The bench counts every assert() that passes. That's a test.",
	{"text": "test before you touch. every time. - G.P.", "hand": true},
]
## The admin's printout, taped over the bench: a function to light one zone, never
## finished (it doesn't hand its answer back). %s is the key; DRAFT.
const PRINTOUT := [
	{"text": "// restore one zone. TODO: test on the bench before Monday", "hand": false},
	{"text": "let key = \"<the key>\";", "hand": false},
	{"text": "let login = await api.post(\"/auth/token\", {\"key\": key});", "hand": false},
	{"text": "let auth = {\"Authorization\": \"Bearer \" + login.body.token};", "hand": false},
	{"text": "", "hand": false},
	{"text": "async function restore(zone) {", "hand": false},
	{"text": "  let res = await api.get(\"/lights/\" + zone, auth);", "hand": false},
	{"text": "  if (res.body.on !== true) {", "hand": false},
	{"text": "    res = await api.patch(\"/lights/\" + zone, {\"on\": true}, auth);", "hand": false},
	{"text": "  }", "hand": false},
	{"text": "  // TODO hand the answer back", "hand": false},
	{"text": "}", "hand": false},
	{"text": "", "hand": false},
	{"text": "let answer = await restore(\"%s\");", "hand": false},
	{"text": "assert(answer.body.on, \"%s is lit\");", "hand": false},
	{"text": "fails every time. G.P.", "hand": true},
]
## The bench's lamp labels, one per zone; the emergency lamp's own label.
const EM_LABEL := "EMERGENCY  -  LIFE SAFETY  -  NOT SWITCHABLE"
## The facilities memo, the same one as on 18 (approved there 2026-10-21).
const MEMO_LINES := [
	"HALCYON DATA SYSTEMS  -  FACILITIES",
	"MEMO  10/15",
	"Lifts 1-4 keep faulting after Tuesday night's power event.",
	"Until they are fixed, use STAIR 1 between floors.",
	"Stair doors lock at 19:00. Do not prop them.",
	"- Facilities, ext. 2200",
]
## The stand in the lift lobby, and the freight lift's own sign (the decoy's reason). DRAFT.
const STAND_LINES := ["LIFTS OUT OF SERVICE", "Please use the stairs.", "We apologise for any inconvenience."]
const FREIGHT_SIGN := [
	"FREIGHT LIFT  -  OUT OF SERVICE",
	"Door operator replaced Tue 10/14. Awaiting inspection.",
	"Do not restart before sign-off.",
	{"text": "inspector booked for the 20th", "hand": true},
]

const CASES := {"token": TEXT.case_token, "restore": TEXT.case_restore, "zones": TEXT.case_zones}
const CASE_DO := {"token": TEXT.case_token_do, "restore": TEXT.case_restore_do, "zones": TEXT.case_zones_do}
## The cases, in the order they open.
const CASE_ORDER := ["token", "restore", "zones"]

const STAIR_AT := Vector3(4, 0, 6)
const STAIR_YAW := -90.0
## The rooms, for tests and the ring's lights.
const LANDING := AABB(Vector3(-4, -0.5, 4), Vector3(8, 4, 4))
const LOBBY := AABB(Vector3(-4, -0.5, -6), Vector3(8, 4, 10))
const MOTOR := AABB(Vector3(-10, -0.5, -1), Vector3(6, 4, 5))
const OFFICE := AABB(Vector3(4, -0.5, -6), Vector3(10, 4, 6))
const CLOSET := AABB(Vector3(-11, -0.5, -15), Vector3(6, 4, 6))
const CORE := AABB(Vector3(-2, -0.5, -25), Vector3(13, 4, 14))
## The plant ring's six zones, in ring order (Level7Data.ZONE_NAMES), clockwise from
## the lobby door.
const ZONE_BOXES := [
	AABB(Vector3(-14, -0.5, -9), Vector3(14, 4, 3)),
	AABB(Vector3(0, -0.5, -9), Vector3(14, 4, 3)),
	AABB(Vector3(11, -0.5, -27), Vector3(3, 4, 18)),
	AABB(Vector3(0, -0.5, -30), Vector3(14, 4, 3)),
	AABB(Vector3(-14, -0.5, -30), Vector3(14, 4, 3)),
	AABB(Vector3(-14, -0.5, -27), Vector3(3, 4, 18)),
]
## Where each zone's id is stencilled on the ring's wall, and which way it faces.
const ZONE_SIGNS := [
	[Vector3(-7, 2.2, -6.12), 180.0], [Vector3(7, 2.2, -6.12), 180.0], [Vector3(13.88, 2.2, -18), -90.0],
	[Vector3(7, 2.2, -29.88), 0.0], [Vector3(-7, 2.2, -29.88), 0.0], [Vector3(-13.88, 2.2, -18), 90.0],
]
const RING_HEIGHT := 2.8
## The bench's mock: lamp colours.
const LAMP_OFF := Color(0.14, 0.14, 0.13)
const LAMP_ON := Color(1.0, 0.85, 0.45)
const LAMP_STANDBY := Color(0.55, 0.08, 0.06)
## WARDEN's first cut, this long after the crew steps off the stairs.
const FIRST_CUT_AFTER := 14.0

var data: Dictionary
## The floor's services, and the test bench's mock of them.
var api: FacilityAPI
var bench_api: FacilityAPI
var admin_terminal: Terminal
var bench_terminal: Terminal
var stair_in: Door
var motor_door: Door
var closet_door: Door
## Portable decks, one per player slot, each following its player, on the floor's
## services (B2 is wired everywhere, and B1 fitted every deck).
var decks: Array[Terminal] = []
## The bench's fake floor: zone id -> lit.
var bench_on := {}
var _bench_lamps := {}
var _bench_readout: Label3D
## The bench's verdict for the run going now (host): asserts passed, a request that
## hit the emergency circuit, a zone left undefined.
var bench_passes := 0
var _bench_em := false
## The services' state WARDEN decides: he holds the lights (and so the lift controller).
var warden_holds := true
var tips_sent := {}
var cut_zones := {}
var _started_msec := 0
var _watched := {}
var _voice: Voice

var token_puzzle: RequestPuzzle
var restore_puzzle: RequestPuzzle
var zones_puzzle: RequestPuzzle
## Timings, here so tests can shorten them.
var first_cut_after := FIRST_CUT_AFTER


## A screen's way into the services: the floor's own, or the bench's mock. Every
## request through it is reported to the level, so SYSOP answers on the screen where
## the mistake was made, scripts included.
class Link:
	extends FacilityAPI
	var level: Node
	## "floor" or "bench".
	var service := "floor"
	## Whose screen this is: admin, bench, or deck<n>.
	var terminal := "admin"

	func send(method: String, path: String, headers := {}, body := "") -> Dictionary:
		var to: FacilityAPI = level.bench_api if service == "bench" else level.api
		var res: Dictionary = to.send(method, path, headers, body)
		level._on_sent(self, method, path, headers, res)
		return res


func build() -> void:
	data = Level7Data.build(Game.run_seed)
	load_level_seed(data.sql)
	db.read_only = true  # Epsilon (floor 10 on): the database only reads
	api = _make_api(false)
	bench_api = _make_api(true)
	for z in data.zones:
		bench_on[z.id] = false
	_make_puzzles()

	var colors := {"floor": Color(0.3, 0.31, 0.32), "wall": Color(0.5, 0.52, 0.52), "ceiling": Color(0.4, 0.41, 0.42)}
	# The landing: the bottom of STAIR 2, down from B1. No stairs go further down.
	Greybox.room(geo, Vector3(0, 0, 6), Vector3(8, 3.2, 4), colors, [
		{"wall": "n", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "e", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},
	])
	Greybox.label(geo, Vector3(0, 2.75, 7.88), "B2   BUILDING SERVICES", 56, Color(0.75, 0.78, 0.8), 180)
	stair_in = Stairwell.build(self, geo, STAIR_AT, STAIR_YAW, "B2", "STAIR 2", 0)
	stair_in.name = "Door_STAIR-IN"  # unlocked once the whole crew is down (start())
	exit_door = stair_in

	_build_lobby(colors)
	_build_motor_room(colors)
	_build_office(colors)
	_build_ring()
	_build_core()
	_make_decks()

	add_light("LB2-LANDING", Vector3(0, 3.2, 6), 6.0, 0.7)
	add_light("LB2-LOBBY", Vector3(0, 3.0, -1), 8.0, 0.6, Color(0.9, 0.95, 1.0))
	add_light("LB2-ADMIN", Vector3(9, 3.0, -3), 8.0, 0.8, Color(1.0, 0.95, 0.85))
	add_light("LB2-MOTOR", Vector3(-7, 3.0, 1.5), 5.0, 0.6)
	for i in data.zones.size():
		var box: AABB = ZONE_BOXES[i]
		var c := box.get_center()
		var long := box.size.x > box.size.z
		for f in [-0.25, 0.25]:
			var at := c + (Vector3(box.size.x * f, 0, 0) if long else Vector3(0, 0, box.size.z * f))
			add_light(data.zones[i].id, Vector3(at.x, RING_HEIGHT - 0.05, at.z), 7.0, 0.7, Color(0.85, 0.92, 1.0))
	# The emergency exit signs: life safety, on their own batteries. Never dark.
	for at in [Vector3(0, 2.3, -6.15), Vector3(0, 2.3, -29.85)]:
		Greybox.panel(geo, at, Vector3(0.6, 0.22, 0.04), Color(0.1, 0.8, 0.3), 1.5)

	spawn = Transform3D(Basis(Vector3.UP, deg_to_rad(STAIR_YAW + 180.0)), Stairwell.landing_slot(STAIR_AT, STAIR_YAW, 0))
	admin_terminal.api = _link("floor", "admin")
	bench_terminal.api = _link("bench", "bench")


func _link(service: String, terminal: String) -> Link:
	var l := Link.new()
	l.level = self
	l.service = service
	l.terminal = terminal
	l.test_bench = service == "bench"
	return l


func player_spawn(index: int) -> Transform3D:
	return global_transform * Transform3D(spawn.basis, Stairwell.landing_slot(STAIR_AT, STAIR_YAW, index))


# --- The rooms ------------------------------------------------------------------------

func _build_lobby(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(0, 0, -1), Vector3(8, 3.0, 10), colors, [
		{"wall": "s", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "e", "at": -2.0, "width": 1.4, "height": 2.3},
		{"wall": "n", "at": 0.0, "width": 2.0, "height": 2.4},
		{"wall": "w", "at": 2.5, "width": 1.2, "height": 2.2},
	])
	Greybox.label(geo, Vector3(0, 2.7, -5.88), "PLANT RING  >", 34, Color(0.75, 0.8, 0.85), 0)
	Greybox.label(geo, Vector3(3.88, 2.6, -3), "IT ADMIN", 28, Color(0.8, 0.8, 0.75), -90)
	# The lifts that come down here, on the west wall, dead; the freight lift on the east.
	var cars: Array = data.lifts.filter(func(l): return l.kind == "passenger")
	for i in cars.size():
		var z := -4.5 + i * 2.4
		Greybox.panel(geo, Vector3(-3.88, 1.1, z), Vector3(0.04, 2.2, 1.3), Color(0.5, 0.52, 0.55), 0.0)
		Greybox.label(geo, Vector3(-3.86, 2.5, z), "LIFT %s  -  B2" % str(cars[i].id).trim_prefix("LIFT-"), 30, Color(0.4, 0.4, 0.4), 90).name = "LiftLabel%d" % i
	Greybox.panel(geo, Vector3(3.88, 1.2, 2.0), Vector3(0.04, 2.4, 2.0), Color(0.45, 0.42, 0.3), 0.0)
	Greybox.label(geo, Vector3(3.86, 2.65, 2.0), "FREIGHT", 30, Color(0.6, 0.55, 0.3), -90)
	Document.place(geo, Vector3(3.87, 1.5, 0.6), 90, "Freight lift sign", FREIGHT_SIGN, false, "laminated", Vector2(0.26, 0.2))
	# The out-of-service stand in front of them, and the memo from G on the wall.
	Greybox.box(geo, Vector3(-2.4, 0.5, -3.3), Vector3(0.5, 1.0, 0.1), Color(0.85, 0.75, 0.1), "OutOfServiceStand")
	Document.place(geo, Vector3(-2.4, 0.8, -3.24), 180, "Lift stand", STAND_LINES, false, "laminated", Vector2(0.4, 0.3))
	Document.place(geo, Vector3(-3.87, 1.5, -0.6), -90, "Facilities memo", MEMO_LINES, false, "paper")


func _build_motor_room(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(-7, 0, 1.5), Vector3(6, 3.0, 5), {"floor": Color(0.26, 0.26, 0.26), "wall": colors.wall.darkened(0.15)}, [
		{"wall": "e", "at": 0.0, "width": 1.2, "height": 2.2},
	])
	motor_door = add_door("B2-MOTOR", Vector3(-4, 1.1, 1.5), Vector3(0.12, 2.2, 1.2))
	Greybox.label(geo, Vector3(-3.86, 2.45, 1.5), "LIFT MOTOR ROOM", 22, Color(0.8, 0.8, 0.75), 90)
	# The lift controller and the motors, seen through the door's wired glass later.
	Greybox.box(geo, Vector3(-9.4, 1.0, 1.5), Vector3(0.8, 2.0, 1.6), Color(0.3, 0.35, 0.32), "LiftController")
	for z in [-0.2, 3.2]:
		Greybox.box(geo, Vector3(-7.5, 0.6, z), Vector3(1.4, 1.2, 1.0), Color(0.35, 0.33, 0.3), "LiftMotor")


func _build_office(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(9, 0, -3), Vector3(10, 3.0, 6), {"floor": Color(0.34, 0.33, 0.32), "wall": colors.wall}, [
		{"wall": "w", "at": 0.0, "width": 1.4, "height": 2.3},
	])
	Greybox.label(geo, Vector3(9, 2.65, -0.12), "IT ADMIN  -  B2", 36, Color(0.8, 0.8, 0.75), 180)
	# The admin's desk on the east wall: the terminal, the key under the keyboard,
	# and the runbook page pinned beside it.
	Greybox.box(geo, Vector3(13.2, 0.5, -3), Vector3(0.8, 1.0, 2.6), Color(0.38, 0.36, 0.34), "AdminDesk")
	admin_terminal = Terminal.spawn(geo, Vector3(13.2, 1.0, -3.6), -90, "IT ADMIN", db, terminal_ui)
	admin_terminal.name = "AdminTerminal"
	admin_terminal.set_meta("scripts", true)
	admin_terminal.set_meta("ticked_elsewhere", true)
	admin_terminal.puzzles = [token_puzzle]
	admin_terminal.boot_lines = [
		"HALCYON BUILDING SERVICES  -  B2",
		"Services: /auth/token  /lights  /lifts      Scripts: .script",
	]
	admin_terminal.requested.connect(_on_request.bind("admin"))
	var sticky := Document.place(geo, Vector3(13.1, 1.003, -2.6), -90, "Key sticky", [{"text": KEY_STICKY % data.key, "hand": true}], true, "sticky")
	sticky.name = "KeySticky"
	sticky.clues = [{"case": "token", "text": "Under the admin's keyboard: B2's service key, %s (lights, lifts)." % data.key}]
	var runbook := Document.place(geo, Vector3(13.88, 1.6, -1.6), 90, "Runbook page", _runbook(), false, "paper", Vector2(0.21, 0.3))
	runbook.name = "Runbook"
	runbook.clues = [{"case": "token", "opens": TEXT.case_token, "text": "The runbook: POST /auth/token {\"key\": ...} trades the key for a token. Then every request sends Authorization: Bearer <token>. Tokens run out; the page's example is long dead."}]
	runbook.read_by.connect(func(_p): sync.event("_ask", ["token"]))
	# The test bench along the north wall: the mock lighting panel, its terminal, its
	# card, and the admin's unfinished function taped above it.
	Greybox.box(geo, Vector3(8.5, 0.5, -5.4), Vector3(5.0, 1.0, 0.9), Color(0.32, 0.34, 0.36), "TestBench")
	Greybox.box(geo, Vector3(8.5, 1.6, -5.85), Vector3(4.6, 1.2, 0.12), Color(0.12, 0.13, 0.14), "MockPanel")
	Greybox.label(geo, Vector3(8.5, 2.35, -5.78), "TEST BENCH  -  MOCK B2 LIGHTING", 22, Color(0.85, 0.85, 0.8), 0).name = "BenchTitle"
	var all: Array = data.zones + [data.emergency]
	for i in all.size():
		var z: Dictionary = all[i]
		var at := Vector3(6.6 + i * 0.62, 1.75, -5.78)
		var lamp := Greybox.panel(geo, at, Vector3(0.22, 0.22, 0.04), LAMP_OFF, 0.0)
		lamp.name = "Lamp_" + z.id
		_bench_lamps[z.id] = lamp
		Greybox.label(geo, at + Vector3(0, -0.24, 0.01), z.id, 14, Color(0.85, 0.85, 0.8), 0).name = "LampLabel_" + z.id
	Greybox.label(geo, Vector3(8.5, 1.18, -5.78), EM_LABEL, 11, Color(0.85, 0.3, 0.25), 0)
	_bench_readout = Greybox.label(geo, Vector3(8.5, 2.12, -5.78), "", 18, Color(0.5, 1.0, 0.6), 0)
	_bench_readout.name = "BenchReadout"
	bench_terminal = Terminal.spawn(geo, Vector3(7.0, 1.0, -5.3), 0, "TEST BENCH", db, terminal_ui)
	bench_terminal.name = "BenchTerminal"
	bench_terminal.set_meta("scripts", true)
	bench_terminal.set_meta("ticked_elsewhere", true)
	bench_terminal.puzzles = [restore_puzzle, zones_puzzle]
	bench_terminal.boot_lines = [
		"TEST BENCH  -  MOCK B2 LIGHTING",
		"Same paths as the floor: /auth/token  /lights      Scripts: .script",
		"Nothing here touches the building.",
	]
	bench_terminal.requested.connect(_on_request.bind("bench"))
	var card := Document.place(geo, Vector3(10.6, 1.003, -5.2), 0, "Bench card", BENCH_CARD, true, "laminated", Vector2(0.28, 0.22))
	card.name = "BenchCard"
	card.clues = [{"case": "restore", "text": "The test bench mocks B2's lighting: the same paths and zone ids, its own fake floor, dark at the start of every run. It counts every assert() that passes."}]
	card.read_by.connect(func(_p): sync.event("_book_huddle", ["js_testing"]))
	var printout := Document.place(geo, Vector3(11.2, 1.6, -5.92), 180, "Admin's printout", _printout(), false, "paper", Vector2(0.21, 0.3))
	printout.name = "Printout"
	printout.clues = [{"case": "restore", "opens": TEXT.case_restore, "text": "The admin's function: async function restore(zone) GETs a zone and PATCHes it on if it's dark. It never hands its answer back, so the test after it fails."}]
	printout.read_by.connect(func(_p):
		sync.event("_ask", ["restore"])
		sync.event("_book_huddle", ["js_functions"]))
	_show_bench()


## The plant ring: four corridors round the core in six lighting zones, under cable
## trays, on raised floor tiles.
func _build_ring() -> void:
	var c := {"floor": Color(0.42, 0.43, 0.44), "wall": Color(0.46, 0.47, 0.47), "ceiling": Color(0.3, 0.3, 0.31)}
	Greybox.room(geo, Vector3(0, 0, -7.5), Vector3(28, RING_HEIGHT, 3), c, [
		{"wall": "s", "at": 0.0, "width": 2.0, "height": 2.4},
		{"wall": "n", "at": -12.5, "width": 3.0, "height": RING_HEIGHT},
		{"wall": "n", "at": 12.5, "width": 3.0, "height": RING_HEIGHT},
		{"wall": "n", "at": -8.0, "width": 1.2, "height": 2.2},
	])
	Greybox.room(geo, Vector3(0, 0, -28.5), Vector3(28, RING_HEIGHT, 3), c, [
		{"wall": "s", "at": -12.5, "width": 3.0, "height": RING_HEIGHT},
		{"wall": "s", "at": 12.5, "width": 3.0, "height": RING_HEIGHT},
	])
	Greybox.room(geo, Vector3(-12.5, 0, -18), Vector3(3, RING_HEIGHT, 18), c, [
		{"wall": "s", "at": 0.0, "width": 3.0, "height": RING_HEIGHT},
		{"wall": "n", "at": 0.0, "width": 3.0, "height": RING_HEIGHT},
	])
	Greybox.room(geo, Vector3(12.5, 0, -18), Vector3(3, RING_HEIGHT, 18), c, [
		{"wall": "s", "at": 0.0, "width": 3.0, "height": RING_HEIGHT},
		{"wall": "n", "at": 0.0, "width": 3.0, "height": RING_HEIGHT},
		{"wall": "w", "at": 0.0, "width": 4.0, "height": 2.4, "bottom": 1.0},
	])
	# Each zone's id stencilled on its wall, where a crew in the ring reads it.
	for i in data.zones.size():
		var s: Array = ZONE_SIGNS[i]
		Greybox.label(geo, s[0], "ZONE  %s" % data.zones[i].id, 26, Color(0.85, 0.75, 0.2), s[1]).name = "ZoneSign_%d" % i
	# Cable trays along every ceiling, and the raised floor's tile seams.
	for t in [[Vector3(0, 2.6, -7.0), Vector3(27, 0.08, 0.5)], [Vector3(0, 2.6, -29.0), Vector3(27, 0.08, 0.5)],
			[Vector3(-12.0, 2.6, -18), Vector3(0.5, 0.08, 17)], [Vector3(13.0, 2.6, -18), Vector3(0.5, 0.08, 17)]]:
		Greybox.panel(geo, t[0], t[1], Color(0.55, 0.55, 0.5), 0.0)
	for x in range(-13, 14, 2):
		Greybox.panel(geo, Vector3(x, 0.005, -7.5), Vector3(0.03, 0.01, 2.9), Color(0.3, 0.3, 0.3), 0.0)
	# The network closet off the south corridor: WARDEN's uplink, locked.
	Greybox.room(geo, Vector3(-8, 0, -12), Vector3(6, RING_HEIGHT, 6), {"floor": Color(0.3, 0.3, 0.32), "wall": Color(0.45, 0.46, 0.47)}, [
		{"wall": "s", "at": 0.0, "width": 1.2, "height": 2.2},
	])
	closet_door = add_door("B2-NETCL", Vector3(-8, 1.1, -9), Vector3(1.2, 2.2, 0.12))
	Greybox.label(geo, Vector3(-8, 2.45, -8.88), "NETWORK CLOSET", 22, Color(0.8, 0.8, 0.75), 0)
	for x in [-10.2, -9.2]:
		Greybox.box(geo, Vector3(x, 1.0, -14.4), Vector3(0.8, 2.0, 0.8), Color(0.15, 0.16, 0.18), "PatchRack")
	Greybox.box(geo, Vector3(-5.6, 1.2, -12.5), Vector3(0.4, 0.8, 1.0), Color(0.3, 0.3, 0.28), "LightingController")


## WARDEN's core, behind glass off the ring's east side: the racks that run him.
func _build_core() -> void:
	Greybox.room(geo, Vector3(4.5, 0, -18), Vector3(13, RING_HEIGHT, 14), {"floor": Color(0.2, 0.2, 0.22), "wall": Color(0.3, 0.31, 0.33)}, [
		{"wall": "e", "at": 0.0, "width": 4.0, "height": 2.4, "bottom": 1.0},
	])
	var glass := Greybox.box(geo, Vector3(11, 1.7, -18), Vector3(0.06, 1.4, 4.0), Color(0.6, 0.75, 0.85), "CoreGlass")
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.8, 0.9, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(glass.get_child(0) as MeshInstance3D).material_override = m
	for z in [-22.0, -18.0, -14.0]:
		for x in [1.0, 4.0, 7.0]:
			Greybox.box(geo, Vector3(x, 1.1, z), Vector3(0.8, 2.2, 1.6), Color(0.1, 0.1, 0.12), "CoreRack")
			Greybox.panel(geo, Vector3(x + 0.41, 1.6, z), Vector3(0.02, 0.05, 1.2), Color(0.2, 1.0, 0.4), 2.0)
	Greybox.label(geo, Vector3(10.85, 2.55, -18), "W.A.R.D.E.N.  CORE", 26, Color(0.7, 0.75, 0.8), -90)
	Greybox.ceiling_light(geo, Vector3(4.5, 2.6, -18), 9.0, 0.35, Color(0.4, 1.0, 0.6))
	Hum.create(geo, AABB(Vector3(-2, 0, -25), Vector3(13, 3, 14)))


func _make_decks() -> void:
	for i in 6:
		var d := Terminal.new()
		d.name = "Deck%d" % (i + 1)
		d.terminal_name = "PORTABLE DECK"
		d.db = db
		d.ui = terminal_ui
		d.api = _link("floor", "deck%d" % i)
		d.prompt = ""
		d.enabled = false
		d.boot_lines = ["HALCYON PORTABLE DECK  -  FIELD UNIT", "B2: wired jacks everywhere. Services: /auth/token  /lights  /lifts"]
		d.set_meta("scripts", true)
		d.set_meta("ticked_elsewhere", true)
		d.requested.connect(_on_request.bind("deck"))
		d.focus_point = Marker3D.new()
		d.focus_point.name = "FocusPoint"
		d.focus_point.position = Vector3(0, 1.1, -0.3)
		d.add_child(d.focus_point)
		d.stand_point = Marker3D.new()
		d.stand_point.name = "StandPoint"
		d.add_child(d.stand_point)
		add_child(d)
		decks.append(d)


func _runbook() -> Array:
	var lines := RUNBOOK.duplicate(true)
	for i in lines.size():
		if lines[i] is Dictionary and str(lines[i].text).contains("Bearer %s"):
			lines[i] = {"text": lines[i].text % data.example_token, "hand": false}
	return lines


func _printout() -> Array:
	var lines := PRINTOUT.duplicate(true)
	var z: String = data.zones[0].id
	for i in lines.size():
		if lines[i] is Dictionary and str(lines[i].text).contains("%s"):
			lines[i] = {"text": lines[i].text % z, "hand": lines[i].hand}
	return lines


func net_setup() -> void:
	pass


func apply_environment(env: Environment) -> void:
	env.ambient_light_energy = 0.03
	env.fog_density = 0.04


func start() -> void:
	_started_msec = Time.get_ticks_msec()
	stair_in.locked = false  # the crew's all down: out of the stairwell, onto B2
	for term in [admin_terminal, bench_terminal]:
		term.ensure_booted()
	_voice = Voice.new()
	_voice.name = "B2Voice"
	add_child(_voice)
	if player and not player.inventory.selected.is_connected(_on_selected):
		player.inventory.selected.connect(_on_selected)
	hud.todo(TASK_TITLES.todo_arrive, TEXT.todo_arrive)
	hud.notice(TEXT.arrive, 5.0)
	_lines(["l7_arrive_pa", "l7_arrive_tease"], 0.8)
	# WARDEN hears the crew below him, and starts on the ring's lights.
	_later(first_cut_after, "_cut", [data.first_cut])


## A line by id: Voice's recording and subtitle once VoiceLines has it.
func _say(id: String) -> void:
	if hud and not VoiceLines.get_line(id).is_empty():
		await hud.line(id)


## Lines in order, with a pause between (the PA, then his own voice).
func _lines(ids: Array, pause := 1.0) -> void:
	var first := true
	for id in ids:
		if not first:
			await get_tree().create_timer(pause, false).timeout
			if not is_inside_tree():
				return
		first = false
		await _say(id)


func _is_host() -> bool:
	return sync == null or sync.is_host()


## Host: `method` runs on every machine after `seconds` (a timer the services need).
func _later(seconds: float, method: String, args := []) -> void:
	if not _is_host() or not is_inside_tree():
		return
	await get_tree().create_timer(seconds, false).timeout
	if is_inside_tree():
		sync.event(method, args)


# --- The services ---------------------------------------------------------------------

## B2's services behind one key (the IT admin's), traded for tokens: the ring's
## lights and the lifts. The bench is the same lighting service on its own fake
## floor (no lifts). Handlers change only service state and the building's tables,
## the same on every machine.
func _make_api(bench: bool) -> FacilityAPI:
	var a := FacilityAPI.new()
	a.test_bench = bench
	a.add_key(data.key, ["lights", "lifts"], "IT admin")
	a.enable_tokens(data.token_seconds, data.bench_seed if bench else data.token_seed)
	a.token_issued.connect(func(token: String, seconds: float): _later(seconds, "_expire", [bench, token]))
	if not bench:
		a.add_token(data.example_token, data.key, true)
	a.route("GET", "/lights", func(_p):
		return {"status": 200, "body": {"zones": data.listed.map(func(id): return _zone_json(id, bench))}}, "lights", "token")
	a.route("GET", "/lights/:id", func(p):
		var z := Level7Data.zone(data, str(p[0]))
		if z.is_empty():
			return {"status": 404, "body": {"error": "No zone %s on B2. GET /lights lists them." % p[0]}}
		return {"status": 200, "body": _zone_json(z.id, bench)}, "lights", "token")
	a.route("PATCH", "/lights/:id", func(p, req):
		return _patch_zone(str(p[0]), req, bench), "lights", "token")
	if bench:
		return a
	a.route("GET", "/lifts", func(_p):
		return {"status": 200, "body": {"lifts": data.lifts.map(_lift_json)}}, "lifts", "token")
	a.route("GET", "/lifts/:id", func(p):
		var l := _lift(str(p[0]))
		if l.is_empty():
			return {"status": 404, "body": {"error": "No lift %s comes down to B2. GET /lifts lists them." % p[0]}}
		return {"status": 200, "body": _lift_json(l)}, "lifts", "token")
	a.route("POST", "/lifts/:id/restart", func(p, req):
		return _restart(str(p[0]), req), "lifts", "token")
	return a


## Every machine: a token ran out, on the host's clock.
func _expire(bench: bool, token: String) -> void:
	(bench_api if bench else api).expire_token(token)


## Is a zone lit: on the bench, its mock; on the floor, the lights table.
func zone_on(id: String, bench := false) -> bool:
	if bench:
		return bench_on.get(id, false)
	var rows := db.run_silent("SELECT is_on FROM lights WHERE id = '%s'" % id.replace("'", ""))
	return not rows.is_empty() and int(rows[0].is_on) == 1


func _zone_json(id: String, bench: bool) -> Dictionary:
	var z := Level7Data.zone(data, id)
	if z.id == data.emergency.id:
		return {"id": z.id, "name": z.name, "on": false, "circuit": "life safety", "mode": "standby"}
	return {"id": z.id, "name": z.name, "on": zone_on(z.id, bench), "circuit": "ring"}


## PATCH /lights/<id> {"on": bool}. The emergency circuit is life safety: 403.
func _patch_zone(id: String, req: Dictionary, bench: bool) -> Dictionary:
	var z := Level7Data.zone(data, id)
	if z.is_empty():
		return {"status": 404, "body": {"error": "No zone %s on B2. GET /lights lists them." % id}}
	if z.id == data.emergency.id:
		return {"status": 403, "body": {"error": "Life safety circuit: emergency lighting is switched by fire control only. Not yours."}}
	var bad := FacilityAPI.check_fields(req.body, {"on": TYPE_BOOL})
	if bad != "":
		return {"status": 400, "body": {"error": bad}}
	_set_zone(z.id, req.body.on, bench)
	return {"status": 200, "body": _zone_json(z.id, bench)}


## Every machine (a request or an event): a zone's lights go on or off.
func _set_zone(id: String, on: bool, bench := false) -> void:
	if bench:
		bench_on[id] = on
		_show_bench()
		return
	db.run_silent("UPDATE lights SET is_on = %d WHERE id = '%s'" % [1 if on else 0, id])
	db.light_changed.emit(id, on)
	if on:
		cut_zones.erase(id)
	else:
		cut_zones[id] = true


## Every machine: WARDEN cuts zones of the ring.
func _cut(ids: Array) -> void:
	for id in ids:
		_set_zone(str(id), false)
	if hud and is_inside_tree():
		hud.notice(TEXT.cut, 3.0, ThemeUtil.RED)
		_lines(["l7_cut_pa", "l7_cut_tease"], 0.8)


func _lift(id: String) -> Dictionary:
	for l in data.lifts:
		if str(l.id).to_upper() == id.to_upper():
			return l
	return {}


func _lift_json(l: Dictionary) -> Dictionary:
	if l.kind == "freight":
		return {"id": l.id, "name": l.name, "state": "out of service", "since": "Tue 10/14"}
	return {"id": l.id, "name": l.name, "state": "stopped", "controller": "held by WARDEN" if warden_holds else "ready"}


## POST /lifts/<id>/restart {}: the freight lift is out of service (its sign says
## why); the cars won't take commands while WARDEN holds the lights (423).
func _restart(id: String, req: Dictionary) -> Dictionary:
	var l := _lift(id)
	if l.is_empty():
		return {"status": 404, "body": {"error": "No lift %s comes down to B2. GET /lifts lists them." % id}}
	var bad := FacilityAPI.check_fields(req.body, {})
	if bad != "":
		return {"status": 400, "body": {"error": bad + " A restart's body is empty: {}"}}
	if l.kind == "freight":
		return {"status": 409, "body": {"error": "Out of service since Tue 10/14: awaiting inspection. Not restartable from here."}}
	if warden_holds:
		return {"status": 423, "body": {"error": "Locked: the lift controller is held by WARDEN while he holds the lights."}}
	return {"status": 202, "body": {"id": l.id, "state": "restarting"}}


# --- The bench ------------------------------------------------------------------------

## Every machine: the mock's lamps and readout show its fake floor.
func _show_bench() -> void:
	for id in _bench_lamps:
		var lamp: MeshInstance3D = _bench_lamps[id]
		if id == data.emergency.id:
			lamp.material_override = Greybox.mat(LAMP_STANDBY, 0.6)
		elif bench_on.get(id, false):
			lamp.material_override = Greybox.mat(LAMP_ON, 2.0)
		else:
			lamp.material_override = Greybox.mat(LAMP_OFF)
	if _bench_readout:
		_bench_readout.text = "ZONES LIT %d / %d     TESTS PASSED %d" % [bench_lit(), data.zones.size(), bench_passes]


func bench_lit() -> int:
	return bench_on.values().filter(func(v): return v).size()


## Every machine: a run starts on the bench. Its fake floor goes dark again, and the
## count of tests starts over.
func _bench_reset() -> void:
	for id in bench_on:
		bench_on[id] = false
	bench_passes = 0
	_bench_em = false
	_show_bench()


## Every machine: an assert passed in the bench's run.
func _bench_passed() -> void:
	bench_passes += 1
	_show_bench()


## The bench's ids that are still dark, by name.
func _bench_dark() -> Array:
	return data.zones.filter(func(z): return not bench_on.get(z.id, false)).map(func(z): return "%s (%s)" % [z.id, z.name])


# --- The stations ---------------------------------------------------------------------

func _make_puzzles() -> void:
	var key: String = data.key
	# 1. A token: looked up off the runbook, not taught by a chapter. Ladder A (new words).
	token_puzzle = RequestPuzzle.new("token", "POST /auth/token {\"key\": \"%s\"}" % key, func(_l, _r): return false, [
		"the shape, with the key left as enter_key, then the token as enter_token:\n" +
		"    [color=#ffffff]POST /auth/token {\"key\": \"enter_key\"}[/color]\n" +
		"    [color=#ffffff]GET /lights\nAuthorization: Bearer enter_token[/color]\n" +
		"  POST /auth/token   trades a key for a token: a pass that runs out after a few minutes\n" +
		"  Authorization: Bearer ...   the header B2 reads: the word Bearer, a space, then the token\n" +
		"enter_key is the admin's key. enter_token is the token field in the first answer. Enter twice after the header.",
		"the runbook page by this terminal says how. the key's on the sticky under the keyboard. not the runbook's example token: it ran out long ago.",
		"type this:\n    [color=#ffffff]POST /auth/token {\"key\": \"%s\"}[/color]\n" % key +
		"then this, with the token it gave you after Bearer, and Enter twice:\n    [color=#ffffff]GET /lights\nAuthorization: Bearer <the token>[/color]",
	], func(): return false)
	token_puzzle.case_id = "token"
	# 2. One zone on the bench: function, return, async and assert are new. Ladder A.
	var zone: String = data.zones[0].id
	restore_puzzle = RequestPuzzle.new("restore", _one_script(key, zone), func(_l, _r): return false, [
		"the shape, with the zone left as enter_zone:\n" +
		"    [color=#ffffff]%s[/color]\n" % _one_script("enter_key", "enter_zone") +
		"  async function restore(zone) { ... }   a function: steps with a name, run whenever you call it. zone is what you hand it. async lets it await inside\n" +
		"  return res;   hands the answer back to whoever called it. without it, they get undefined\n" +
		"  await restore(\"...\")   calls it with a zone, and waits for what it hands back\n" +
		"  assert(answer.body.on, \"... is lit\")   a test: stops the script with your words if it isn't true. on the bench, every assert that passes counts\n" +
		"enter_zone is a zone id, off a lamp on the bench or GET /lights. type .script to open the runner, then ^S saves and ^R runs it.",
		"the admin's printout over the bench is most of it. it never hands the answer back: a function gives back what comes after return.",
		"type .script, then this, then ^R:\n    [color=#ffffff]%s[/color]" % _one_script(key, zone),
	], func(): return false)
	restore_puzzle.case_id = "restore"
	# 3. Every zone: a list is new. Ladder A.
	var ids: Array = data.zones.map(func(z): return z.id)
	zones_puzzle = RequestPuzzle.new("zones", _every_script(key, ids), func(_l, _r): return false, [
		"the shape, with the zones left as enter_zones:\n" +
		"    [color=#ffffff]%s[/color]\n" % _every_script("enter_key", ["enter_zones"]) +
		"  [\"...\", \"...\"]   a list: a whole line of things, in square brackets, split by commas\n" +
		"  for (const zone of zones) { ... }   once for each zone in the list, as on B1\n" +
		"  zones.length   how many things are in the list\n" +
		"enter_zones is every ring zone's id, each in quotes. the emergency circuit isn't one of them.",
		"the six ring zones are on the bench's lamps, and on the ring's walls. GET /lights lists the emergency circuit too: life safety, leave it out.",
		"type .script, then this, then ^R:\n    [color=#ffffff]%s[/color]" % _every_script(key, ids),
	], func(): return false)
	zones_puzzle.case_id = "zones"


## The top every B2 script needs: a token for the key, and the header that carries it,
## then the admin's function, finished (it returns its answer).
static func _restore_fn(key: String) -> String:
	return "let key = \"%s\";\nlet login = await api.post(\"/auth/token\", {\"key\": key});\nlet auth = {\"Authorization\": \"Bearer \" + login.body.token};\n\nasync function restore(zone) {\n  let res = await api.get(\"/lights/\" + zone, auth);\n  if (res.body.on !== true) {\n    res = await api.patch(\"/lights/\" + zone, {\"on\": true}, auth);\n  }\n  return res;\n}\n" % key


static func _one_script(key: String, zone: String) -> String:
	return _restore_fn(key) + "\nlet answer = await restore(\"%s\");\nassert(answer.body.on, \"%s is lit\");" % [zone, zone]


static func _every_script(key: String, ids: Array) -> String:
	var list: String = ", ".join(PackedStringArray(ids.map(func(i): return "enter_zones" if i == "enter_zones" else "\"%s\"" % i)))
	return _restore_fn(key) + "\nlet zones = [%s];\nfor (const zone of zones) {\n  let answer = await restore(zone);\n  assert(answer.body.on, zone + \" is lit\");\n}\nconsole.log(zones.length + \" zones lit\");" % list


func puzzles() -> Array:
	return [token_puzzle, restore_puzzle, zones_puzzle]


## Host: a request typed at a terminal or deck. The services did the rest already,
## on every machine, and SYSOP answered from _on_sent.
func _on_request(_line: String, _res: Dictionary, _ui: TerminalUI, _which: String) -> void:
	pass


## Host: any request the services answered, typed or from a script, from the screen
## `link.terminal`. A good token's first answer from B2 closes the token case; the
## mistakes SYSOP has a line for are answered there.
func _on_sent(link: Link, method: String, path: String, headers: Dictionary, res: Dictionary) -> void:
	if not _is_host():
		return
	var which: String = link.terminal
	method = method.to_upper()
	path = path.strip_edges().to_lower()
	var status := int(res.get("status", 0))
	var body = res.get("body")
	var error := str(body.get("error", "")) if body is Dictionary else ""
	var auth := ""
	for h in headers:
		if str(h).to_lower() == "authorization":
			auth = str(headers[h]).strip_edges()
	var token := auth.substr(7).strip_edges() if auth.to_lower().begins_with("bearer ") else ""
	if status == 200 and (path.begins_with("/lights") or path.begins_with("/lifts")):
		if not token_puzzle.solved:
			sync.event("_on_solved", ["token"])
	elif status == 401:
		sync.event("_ask", ["token"])
		if error.begins_with("This service takes tokens"):
			sync.event("_tip", ["key_not_token", which])
		elif error.begins_with("Send the token after"):
			sync.event("_tip", ["bearer", which])
		elif error.begins_with("That token has expired"):
			sync.event("_tip", ["example_token" if token == data.example_token else "expired", which])
		elif error.begins_with("That token isn't one"):
			var other: FacilityAPI = api if link.service == "bench" else bench_api
			if other.token_state(token) != "":
				sync.event("_tip", ["other_service", which, ["floor's services" if link.service == "bench" else "test bench"]])
			else:
				sync.event("_tip", ["unknown_token", which])
	elif status == 403 and path.begins_with("/lights/"):
		if link.service == "bench":
			_bench_em = true
		sync.event("_tip", ["em", which])
	elif status == 404 and path.ends_with("/undefined"):
		sync.event("_tip", ["no_zone", which, [data.zones[0].id]])
	elif status == 423:
		sync.event("_tip", ["lifts_held", which])


## Every machine: a SYSOP tip on the screen it was earned at (once per run). `args`
## fill the line's blanks.
func _tip(id: String, which: String, args := []) -> void:
	if tips_sent.has(id):
		return
	tips_sent[id] = true
	var term := _terminal(which)
	if term and TEXT.has("tip_" + id):
		var text: String = TEXT["tip_" + id]
		if not args.is_empty():
			text = text % args
		term.print_line(TerminalUI.sysop(text), "hint")


func _terminal(which: String) -> Terminal:
	match which:
		"admin": return admin_terminal
		"bench": return bench_terminal
	if which.begins_with("deck") and which.length() > 4:
		var i := int(which.trim_prefix("deck"))
		if i >= 0 and i < decks.size():
			return decks[i]
	return admin_terminal


## Every machine: a station passed.
func _on_solved(id: String) -> void:
	for p in puzzles():
		if p.id == id:
			if p.solved:
				return
			p.solved = true
	match id:
		"token":
			_open_case("token")
			Game.solve_case("token", TEXT.token_done % [data.zones.size(), int(data.token_seconds)])
			_next_case()
		"restore":
			_open_case("restore")
			var lit: Array = data.zones.filter(func(z): return bench_on.get(z.id, false)).map(func(z): return z.id)
			Game.solve_case("restore", TEXT.restore_done % (lit[0] if not lit.is_empty() else "A zone"))
			_book_huddle("js_functions")
			_next_case()
		"zones":
			_open_case("zones")
			Game.solve_case("zones", TEXT.zones_done)
			_book_huddle("js_lists")
			_book_huddle("js_testing")
			if hud and is_inside_tree():
				hud.todo(TASK_TITLES.todo_floor, TEXT.todo_floor)


func _open_case(id: String) -> void:
	Game.open_case(id, CASES[id], [], CASE_DO[id])


## One case at a time, in order (the case board): the next one opens when the last
## is done.
func _next_case() -> void:
	for id in CASE_ORDER:
		if not Game.case_info(id).get("solved", false):
			_open_case(id)
			return


## Every machine: a paper opened a case. Only in order: a case waits for the one before.
func _ask(id: String) -> void:
	var at := CASE_ORDER.find(id)
	for i in at:
		if not Game.case_info(CASE_ORDER[i]).get("solved", false):
			return
	_open_case(id)


## Every machine: a paper brings a chapter into the crew's book, quietly (nothing
## stops). Teaching writes B2's three (Functions, Lists, Test before you touch); until
## they're in the book, nothing happens.
func _book_huddle(id: String) -> void:
	if Huddle.of(self) == null or Huddle.of(self).done.has(id) or Books.chapter(id).is_empty():
		return
	await Huddle.of(self).run(id, Huddle.REMEMBERED)


# --- The script runners (every one is listened to) ----------------------------------------

func _script_terminals() -> Array:
	var out: Array = [admin_terminal, bench_terminal]
	out.append_array(decks)
	return out


## Every frame: a runner that appeared (opened for the first time, or adopted online)
## is listened to.
func _watch_scripts() -> void:
	for t in _script_terminals():
		var rt = t.get_meta("script_runtime") if t and t.has_meta("script_runtime") else null
		if rt == null or _watched.has(rt):
			continue
		_watched[rt] = true
		if t == bench_terminal:
			rt.started.connect(_on_bench_started)
			rt.printed.connect(_on_bench_printed)
			rt.finished.connect(_on_bench_finished)


## Host: a run starts on the bench.
func _on_bench_started() -> void:
	if _is_host():
		sync.event("_bench_reset")


## Host: a line the bench's run printed. A passing assert says PASS.
func _on_bench_printed(_text: String, kind: String) -> void:
	if _is_host() and kind == "pass":
		sync.event("_bench_passed")


## Host: the bench's run ended (`ok`: on its own, not stopped or failed). The bench
## says how it went; a station passes when its zones are lit and a test said so.
func _on_bench_finished(ok: bool, err: Dictionary) -> void:
	if not _is_host():
		return
	var message := str(err.get("message", ""))
	if not ok and message.contains("is undefined, so it has no"):
		sync.event("_tip", ["no_return", "bench"])
	var stopped := not ok and err.is_empty()
	if stopped:
		return
	sync.event("_bench_report", [bench_lit(), bench_passes, _bench_em])
	if not ok:
		return
	var lit := bench_lit()
	if lit > 0 and bench_passes == 0:
		sync.event("_tip", ["no_assert", "bench"])
		return
	if lit == 0 or bench_passes == 0:
		return
	if not restore_puzzle.solved and Game.case_info("token").get("solved", false):
		sync.event("_on_solved", ["restore"])
	if restore_puzzle.solved or Game.case_info("restore").get("solved", false):
		if lit == data.zones.size() and not zones_puzzle.solved:
			sync.event("_on_solved", ["zones"])


## Every machine: the bench prints its verdict on its own screen, in-world: how many
## zones it lit, how many tests passed, and which zones are still dark.
func _bench_report(lit: int, passes: int, em: bool) -> void:
	bench_terminal.print_line(TEXT.bench_report % [lit, data.zones.size(), passes])
	if em:
		bench_terminal.print_line(TEXT.bench_em)
	if lit > 0 and lit < data.zones.size() and restore_puzzle.solved:
		bench_terminal.print_line(TEXT.bench_dark % ", ".join(PackedStringArray(_bench_dark())))


# --- The decks --------------------------------------------------------------------------

## This machine's player took something out of their hotbar: the deck opens.
func _on_selected(item: String) -> void:
	if item != "deck" or not active or terminal_ui.visible:
		return
	open_deck()


func open_deck() -> void:
	var i := players.my_index() if players else 0
	if i < 0 or i >= decks.size():
		return
	terminal_ui.open(decks[i], player)


## Each deck goes where its holder is (every machine moves its copies).
func _follow_decks() -> void:
	if players == null:
		if player and not decks.is_empty():
			decks[0].global_position = player.global_position
		return
	for id in players.all_ids():
		var i := NetPlayers.index_of(id, multiplayer)
		var body: Node3D = player if id == players.id_of(player) else players.puppet(id)
		if body and i >= 0 and i < decks.size():
			decks[i].global_position = body.global_position


# --- Every frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not active:
		return
	_watch_scripts()
	# Solo: B2's scripts keep running while you're away from their runner. (Online,
	# ScriptHost runs them on the host.)
	if sync == null or not sync.is_online():
		for t in _script_terminals():
			var rt = t.get_meta("script_runtime") if t.has_meta("script_runtime") else null
			if rt and rt.is_running():
				rt.tick(delta)
	_follow_decks()


func on_player_died() -> void:
	player.respawn(spawn_point())
