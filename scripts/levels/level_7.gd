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
##   4. the fight, under pressure (Augustine's calls 2026-11-06: 1a, 2b, 3b, 6a+b), in
##      three stages:
##      lights_out  "He cuts the lights", everyone: the bench-tested script on the
##                  real floor, every ring zone lit at once. WARDEN has revoked every
##                  token the crew held, so the script gets its own at the top.
##      warden      "He fights back", then "Last stand": each player picks a route.
##                  lockout   in the dark the closet's maglock fails open; pull his
##                            uplink. He fails over to the backup uplink: move the
##                            ring to the local controller (PATCH /controller).
##                  revoke    find his token in the auth log (a list, filtered) and
##                            revoke it. He mints more off a backup key: revoke every
##                            one he issued (a loop over the list).
##                  watchdog  a script that keeps relighting what he cuts. He cuts
##                            faster and holds one zone: the watchdog's assert catches
##                            the zone he's holding, the fault hands it to manual.
##                  Any route's last stand beats him; every stage finished on any
##                  route stretches his beat. The route that finishes sets his 4.0
##                  rule rows (warden_protocols) and Game.warden_route.
##      In the dark: a Watcher every run (the lights hold it still), the Custodian if
##      floor 10 left it unsealed, Rourke with a torch if 22 didn't kill him. Ines and
##      Tomas guide the crew down, then shelter in the plant rooms; WARDEN locks them
##      in and arms each room's gas suppression. Abort it (POST /suppression/<room>/
##      abort) or they die.
##   5. lifts     GET /lifts, a restart for each passenger car, each one in service
##               (423 while WARDEN holds the lights; the freight lift's out of
##               service). The car comes; the crew and whoever lived ride up to 18.
##               Hello HTML! is behind the handrail. End of Act 2.
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
	"tip_revoked": "401 revoked: WARDEN revoked that token. get a fresh one. a script that asks for its own at the top always has one.",
	"tip_controller": "409: the ring follows WARDEN's uplink while it's connected. it's patched in the network closet.",
	"tip_no_sleep": "a loop that never waits never lets the building answer. put await sleep(1000); inside it.",
	"tip_gas": "the suppression panel takes an empty body: POST /suppression/%s/abort {} with your token.",
	# The fight (case 4) and the lifts (case 5).
	"case_lights": "He's cutting the lights. Run it for real",
	"case_lights_do": "From a deck or the admin terminal, run your tested script on the real floor: every ring zone lit at once, with a fresh token at the top",
	"case_warden": "He's fighting back. Pick your way to beat him",
	"case_warden_do": "Split up: pull his uplink in the network closet, revoke his token from the auth log, or keep a watchdog script relighting every zone",
	"case_lifts": "The lifts. Our way out",
	"case_lifts_do": "GET /lifts, then restart each passenger car with POST /lifts/<id>/restart {} and check it's in service",
	"revoked_all": "Every token you had just stopped working. WARDEN revoked them.",
	"lights_done": "Every zone lit on the real floor, by a script the bench had tested.",
	"stage2": "The ring's yours, for a moment. Then WARDEN logs in to the services himself.",
	"closet_open": "In the dark, the network closet's maglock lets go. Its door slides open.",
	"uplink_pulled": "You pull WARDEN's uplink out of the patch panel. Nothing in the ring switches.",
	"failover": "A relay clicks in the closet. The ring's controller has found its backup uplink. WARDEN is back.",
	"warden_revoked": "WARDEN's token is revoked. For a moment, nothing switches.",
	"minted": "New lines in the auth log: WARDEN is minting tokens off a backup key.",
	"watchdog": "Your watchdog relights the ring as fast as he cuts it.",
	"held": "One zone won't stay lit. Something keeps holding it dark.",
	"fault": "FAULT LOGGED: %s failed its check. The zone is on manual now. Nobody remote can hold it.",
	"warden_done_lockout": "The ring runs off the local controller now. WARDEN's uplinks are just cables.",
	"warden_done_revoke": "Every token WARDEN issued is revoked. He can't ask the services for anything.",
	"warden_done_watchdog": "The watchdog caught him holding a zone, and the fault took it off him.",
	"beaten": "Every light in the ring comes on, and stays on.",
	"trapped": "%s's door slams shut. The lock won't open from inside.",
	"gas_armed": "Gas suppression armed in the %s. %s is inside. Discharge in %d seconds.",
	"gas_warn": "Thirty seconds until the %s discharges.",
	"gas_saved": "The suppression panel reads ABORTED. %s is safe in there.",
	"gas_lost": "A roar of gas behind the %s's door. Then nothing. %s doesn't answer.",
	"car_ready": "%s: in service.",
	"lifts_done": "Both cars restarted and in service. The controller is ours.",
	"car_here": "A chime in the lobby. %s's doors slide open.",
	"ride": "The doors close. The car climbs.",
	"on_18": "18. The rear doors open.",
	"book_taken": "Hello HTML! Same series as the other two. Somebody tucked it behind the handrail.",
	"todo_car": "Everyone in the car",
	"car_wait": "%d of %d in the car.",
	"end_card": "End of Act 2",
}
## WARDEN's 4.0 rule rows, written into warden_protocols when the crew beats him. The
## crew's names come off the job ticket (call 5a: written rows name them, spoken lines
## say "technician"). DRAFT.
const RULES_4 := {
	"opener": [51, "The crew is not lost. The crew is choosing."],
	"name": "%s is not a technician.",
	"lockout": "Never trust one uplink.",
	"revoke": "Never trust one key.",
	"watchdog": "Never let them write the test.",
}
## The plant rooms' suppression signs, by each door. %s is the room's id. DRAFT.
const GAS_SIGN := [
	"GAS SUPPRESSION  -  THIS ROOM IS PROTECTED",
	"On alarm: leave the room. The door locks during a discharge countdown.",
	"Remote abort (building services, with a token):",
	{"text": "POST /suppression/%s/abort {}", "hand": false},
]
## The local lighting controller's plate, in the network closet. DRAFT.
const CONTROLLER_PLATE := [
	"LOCAL LIGHTING CONTROLLER  -  PLANT RING",
	"Normally follows the security uplink. If the uplink is lost:",
	{"text": "PATCH /controller {\"source\": \"local\"}", "hand": false},
	{"text": "only with the uplink pulled. - G.P.", "hand": true},
]
const SHELTER_NAMES := {"B2-MOTOR": "lift motor room", "B2-UPS": "battery room"}
## What's heard when a room's gas is armed (the PA, then whoever's inside), and when
## it's aborted.
const GAS_LINES := {"B2-MOTOR": ["l7_gas_motor_pa", "l7_ines_gas"], "B2-UPS": ["l7_gas_ups_pa", "l7_tomas_gas"]}
const SAVED_LINES := {"ines": "l7_ines_saved", "tomas": "l7_tomas_saved"}

## The to-dos' titles (the story and how the crew feels; TEXT has their details). DRAFT.
const TASK_TITLES := {
	"todo_arrive": "The bottom of the building",
	"todo_floor": "Now it's real",
	"todo_fight": "Lights out. For real",
	"todo_warden": "He's fighting back",
	"todo_lifts": "The lifts. Our way out",
	"todo_car": "Going up",
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

const CASES := {"token": TEXT.case_token, "restore": TEXT.case_restore, "zones": TEXT.case_zones,
	"lights_out": TEXT.case_lights, "warden": TEXT.case_warden, "lifts": TEXT.case_lifts}
const CASE_DO := {"token": TEXT.case_token_do, "restore": TEXT.case_restore_do, "zones": TEXT.case_zones_do,
	"lights_out": TEXT.case_lights_do, "warden": TEXT.case_warden_do, "lifts": TEXT.case_lifts_do}
## The cases, in the order they open.
const CASE_ORDER := ["token", "restore", "zones", "lights_out", "warden", "lifts"]
## The ways to beat WARDEN (call 1a: each player picks one).
const ROUTES := ["lockout", "revoke", "watchdog"]
## Each stage the crew finishes, on any route, stretches WARDEN's beat this much.
const SLOWER := 1.3
## The night-shifters: who, where they wait in the admin office, and the plant room
## each shelters in (and where they stand in it).
const NIGHT_SHIFT := {
	"ines": {"name": "Oyelaran, Ines", "first": "Ines", "start": Vector3(-1.6, 0, 2.6), "office": Vector3(5.6, 0, -1.0), "room": "B2-MOTOR", "inside": Vector3(-6.0, 0, 1.5)},
	"tomas": {"name": "Lindqvist, Tomas", "first": "Tomas", "start": Vector3(1.6, 0, 2.6), "office": Vector3(7.2, 0, -0.9), "room": "B2-UPS", "inside": Vector3(10.6, 0, 1.6)},
}
## The car: its box (level space), where the crew rides, and the lobby it opens on 18.
const CAR := AABB(Vector3(-6.4, -0.5, -5.6), Vector3(2.4, 4, 2.2))
const UPS := AABB(Vector3(9, -0.5, 0), Vector3(5, 4, 3))
const ON_18 := AABB(Vector3(-10, -0.5, -5.8), Vector3(3.6, 4, 2.6))

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
var _stage2_sent := false
var _started_msec := 0
var _watched := {}
var _voice: Voice

signal completed

var token_puzzle: RequestPuzzle
var restore_puzzle: RequestPuzzle
var zones_puzzle: RequestPuzzle
var lights_puzzle: RequestPuzzle
var warden_puzzle: RequestPuzzle
var lifts_puzzle: RequestPuzzle
## Timings, here so tests can shorten them.
var first_cut_after := FIRST_CUT_AFTER
## WARDEN's beat in the fight (<= 0: the run's, data.cut_every), the waits before his
## failovers, the lifts' restart, the car, the ride; and each plant room's gas
## countdown (empty: the run's, data.suppression).
var cut_every := -1.0
var failover_after := 6.0
var mint_after := 6.0
var lift_start := 4.0
var car_after := 3.0
var ride_time := 12.0
var gas_seconds := {}
## A watchdog's run counts once it has relit this many zones WARDEN cut.
var watchdog_relights := 3

# --- The fight's state (the same on every machine: events and requests change it) ---
## 0 not yet, 1 lights out, 2 he fights back, 3 last stand (a route's first step is
## done), 4 beaten.
var fight_stage := 0
## Steps done on each route: 1 = its stage-2 step, 2 = its last stand.
var route_done := {"lockout": 0, "revoke": 0, "watchdog": 0}
## Where the ring takes orders from: "uplink", "none" (failing over), "uplink-b", "local".
var controller_source := "uplink"
var uplink_pulled := false
var closet_open := false
## WARDEN logs in to the services himself once the crew fights back.
var warden_logged_in := false
var minted := false
## The zone WARDEN holds dark on the watchdog route's last stand ("" none).
var held_zone := ""
## Each plant room's suppression: "idle", "armed", "aborted", "discharged".
var gas := {"B2-MOTOR": "idle", "B2-UPS": "idle"}
var _gas_armed_msec := {}
## Night-shifters: "guiding", "office", "walking", "sheltered", "trapped", "dead", "out".
var shift_state := {"ines": "guiding", "tomas": "guiding"}
## Lifts: id -> "stopped", "restarting", "in service".
var cars := {}
var car_here := false
var riding := false
var arrived_18 := false
var book_found := false
var said := {}

var watcher: Watcher
var custodian: Custodian
var rourke: Rourke
var staffers := {}
var uplink: Interactable
var hello_book: Interactable
var ups_door: Door
var car_door: Door
var car_rear: Door
var _car_floor: Label3D
var _cut_clock := 0.0
var _cut_rng := RandomNumberGenerator.new()
## Zones a request just relit after WARDEN cut them, for the watchdog's count.
var _relit := {}
## Each floor screen's watchdog count for the run going now.
var _relights := {}


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
	for l in data.lifts:
		cars[l.id] = "out of service" if l.kind == "freight" else "stopped"
	_cut_rng.seed = Game.run_seed * 31 + 7
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
	_build_shelters()
	_build_car()
	_make_decks()
	_place_people()
	_place_hunters()

	add_light("LB2-LANDING", Vector3(0, 3.2, 6), 6.0, 0.7)
	add_light("LB2-LOBBY", Vector3(0, 3.0, -1), 8.0, 0.6, Color(0.9, 0.95, 1.0))
	add_light("LB2-ADMIN", Vector3(9, 3.0, -3), 8.0, 0.8, Color(1.0, 0.95, 0.85))
	add_light("LB2-MOTOR", Vector3(-7, 3.0, 1.5), 5.0, 0.6)
	add_light("LB2-UPS", Vector3(11.5, 2.6, 1.5), 4.0, 0.5)
	add_light("LB2-CAR", Vector3(-5.2, 2.5, -4.5), 3.0, 0.8, Color(1.0, 0.96, 0.88))
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
		{"wall": "w", "at": -3.5, "width": 1.2, "height": 2.2},
	])
	Greybox.label(geo, Vector3(0, 2.7, -5.88), "PLANT RING  >", 34, Color(0.75, 0.8, 0.85), 0)
	Greybox.label(geo, Vector3(3.88, 2.6, -3), "IT ADMIN", 28, Color(0.8, 0.8, 0.75), -90)
	# The lifts that come down here, on the west wall, dead; the freight lift on the east.
	# The car that comes for the crew first (its doorway is real: _build_car).
	var cars_here: Array = data.lifts.filter(func(l): return l.kind == "passenger")
	cars_here.sort_custom(func(a, b): return a.id == data.car and b.id != data.car)
	for i in cars_here.size():
		var z := -4.5 + i * 2.4
		if i > 0:
			Greybox.panel(geo, Vector3(-3.88, 1.1, z), Vector3(0.04, 2.2, 1.3), Color(0.5, 0.52, 0.55), 0.0)
		Greybox.label(geo, Vector3(-3.86, 2.5, z), "LIFT %s  -  B2" % str(cars_here[i].id).trim_prefix("LIFT-"), 30, Color(0.4, 0.4, 0.4), 90).name = "LiftLabel%d" % i
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
		{"wall": "s", "at": 2.5, "width": 1.2, "height": 2.2},
	])
	Greybox.label(geo, Vector3(9, 2.65, -0.12), "IT ADMIN  -  B2", 36, Color(0.8, 0.8, 0.75), 180)
	# The admin's desk on the east wall: the terminal, the key under the keyboard,
	# and the runbook page pinned beside it.
	Greybox.box(geo, Vector3(13.2, 0.5, -3), Vector3(0.8, 1.0, 2.6), Color(0.38, 0.36, 0.34), "AdminDesk")
	admin_terminal = Terminal.spawn(geo, Vector3(13.2, 1.0, -3.6), -90, "IT ADMIN", db, terminal_ui)
	admin_terminal.name = "AdminTerminal"
	admin_terminal.set_meta("scripts", true)
	admin_terminal.set_meta("ticked_elsewhere", true)
	admin_terminal.puzzles = [token_puzzle, lights_puzzle, warden_puzzle, lifts_puzzle]
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


## The two plant rooms the night-shifters shelter in: the lift motor room (built with
## the lobby) and the battery room off the admin office. Each has its gas suppression
## sign by the door. And in the network closet: WARDEN's uplink, and the local
## lighting controller's plate.
func _build_shelters() -> void:
	Greybox.room(geo, UPS.get_center() * Vector3(1, 0, 1), Vector3(UPS.size.x, 2.8, UPS.size.z), {"floor": Color(0.27, 0.27, 0.28), "wall": Color(0.44, 0.45, 0.45)}, [
		{"wall": "n", "at": 0.0, "width": 1.2, "height": 2.2},
	])
	ups_door = add_door("B2-UPS", Vector3(11.5, 1.1, 0), Vector3(1.2, 2.2, 0.12))
	Greybox.label(geo, Vector3(11.5, 2.45, -0.12), "BATTERY ROOM  -  UPS", 20, Color(0.8, 0.8, 0.75), 180)
	for x in [10.0, 13.0]:
		Greybox.box(geo, Vector3(x, 0.7, 2.6), Vector3(1.2, 1.4, 0.6), Color(0.2, 0.22, 0.2), "BatteryRack")
	Document.place(geo, Vector3(12.6, 1.5, -0.08), 0, "Suppression sign", _gas_sign("B2-UPS"), false, "laminated", Vector2(0.24, 0.2)).name = "GasSign_B2-UPS"
	Document.place(geo, Vector3(-3.87, 1.5, 2.6), -90, "Suppression sign", _gas_sign("B2-MOTOR"), false, "laminated", Vector2(0.24, 0.2)).name = "GasSign_B2-MOTOR"
	uplink = Interactable.create(self, Vector3(-9.2, 1.2, -13.95), Vector3(0.5, 0.3, 0.1), "Pull WARDEN's uplink", Color(0.2, 0.5, 1.0))
	uplink.name = "Uplink"
	uplink.enabled = false
	uplink.used.connect(func(_p):
		if fight_stage in [2, 3] and not uplink_pulled:
			sync.event("_pull_uplink"))
	Greybox.label(geo, Vector3(-9.2, 1.6, -13.88), "SECURITY UPLINK  -  W.A.R.D.E.N.", 12, Color(0.6, 0.75, 1.0), 0)
	Document.place(geo, Vector3(-5.82, 1.5, -12.5), 90, "Controller plate", CONTROLLER_PLATE, false, "laminated", Vector2(0.24, 0.18)).name = "ControllerPlate"


func _gas_sign(room: String) -> Array:
	var lines := GAS_SIGN.duplicate(true)
	lines[3] = {"text": GAS_SIGN[3].text % room, "hand": false}
	return lines


## The car that comes for the crew, behind the lobby's west wall: a through car, with
## doors front (the lobby) and back (the lobby it opens on, upstairs), and the lift
## lobby on 18 it opens onto at the end of the ride.
func _build_car() -> void:
	Greybox.room(geo, CAR.get_center() * Vector3(1, 0, 1), Vector3(CAR.size.x, 2.6, CAR.size.z), {"floor": Color(0.4, 0.36, 0.3), "wall": Color(0.62, 0.6, 0.55), "ceiling": Color(0.7, 0.7, 0.68)}, [
		{"wall": "e", "at": 0.0, "width": 1.2, "height": 2.2},
		{"wall": "w", "at": 0.0, "width": 1.2, "height": 2.2},
	])
	car_door = add_door("B2-CAR", Vector3(-4, 1.1, -4.5), Vector3(0.12, 2.2, 1.2))
	car_rear = add_door("B2-CAR-REAR", Vector3(-6.4, 1.1, -4.5), Vector3(0.12, 2.2, 1.2))
	Greybox.box(geo, Vector3(-5.2, 0.95, -5.45), Vector3(2.0, 0.05, 0.05), Color(0.75, 0.75, 0.72), "Handrail")
	_car_floor = Greybox.label(geo, Vector3(-4.7, 2.3, -5.48), "B2", 40, Color(1.0, 0.4, 0.2), 0)
	_car_floor.name = "CarFloor"
	hello_book = Interactable.create(self, Vector3(-5.6, 0.85, -5.42), Vector3(0.2, 0.28, 0.04), "Pick up: Hello HTML!", Color(0.2, 0.55, 0.95))
	hello_book.name = "HelloHTML"
	hello_book.enabled = false
	hello_book.visible = false
	hello_book.used.connect(func(p): sync.event("_book_taken", [players.id_of(p) if players else 1]))
	# Upstairs: the lift lobby on 18, the archive floor, as the car's back doors find it.
	Greybox.room(geo, ON_18.get_center() * Vector3(1, 0, 1), Vector3(ON_18.size.x, 3.0, ON_18.size.z), {"floor": Color(0.36, 0.3, 0.26), "wall": Color(0.72, 0.7, 0.64), "ceiling": Color(0.8, 0.8, 0.78)}, [
		{"wall": "e", "at": 0.0, "width": 1.2, "height": 2.2},
	])
	Greybox.label(geo, Vector3(-9.88, 2.2, -4.5), "18", 120, Color(0.25, 0.25, 0.25), 90).name = "Sign18"
	Greybox.label(geo, Vector3(-9.88, 1.5, -4.5), "ARCHIVE  -  RECORDS", 26, Color(0.3, 0.3, 0.3), 90)
	add_light("L18-LOBBY", Vector3(-8.2, 2.9, -4.5), 5.0, 0.8, Color(1.0, 0.95, 0.85))


## The night-shifters from 9 came down with the crew: they know the building, and
## stand in the lobby when the crew steps off the stairs.
func _place_people() -> void:
	for k in NIGHT_SHIFT:
		var n: Dictionary = NIGHT_SHIFT[k]
		var st := Staffer.new()
		st.name = "Staffer_" + n.first
		st.staff_name = n.name
		st.first_name = n.first
		st.position = n.start
		add_child(st)
		st.state = "waiting"
		st._crouch(false)
		st.arrived.connect(_on_staffer_arrived.bind(k))
		staffers[k] = st


## Whoever is loose in the dark (call 2b): a Watcher every run, the Custodian if floor
## 10 didn't seal it, Rourke if 22 didn't kill him. None of them moves until the fight.
func _place_hunters() -> void:
	watcher = Watcher.new()
	watcher.name = "Watcher"
	watcher.position = Vector3(0, 0, -28.5)
	add_child(watcher)
	watcher.holders.append(_held_by_light)
	var game := get_node("/root/Game")
	if not game.custodian_sealed:
		custodian = Custodian.new()
		custodian.name = "Custodian"
		custodian.position = Vector3(2.6, 0, 2.0)
		add_child(custodian)
		custodian.set_bay(to_global(Vector3(2.6, 0, 2.0)))
	if game.rourke_fate != "killed":
		rourke = Rourke.new()
		rourke.name = "Rourke"
		rourke.position = Vector3(4.5, 0, -24.0)  # out of sight in the core until he comes down
		add_child(rourke)
		rourke.visible = false
		var torch := SpotLight3D.new()
		torch.name = "Torch"
		torch.position = Vector3(0.25, 1.3, -0.3)
		torch.spot_range = 12.0
		torch.spot_angle = 22.0
		torch.light_energy = 3.0
		rourke.add_child(torch)
		rourke.resolved.connect(func(fate): sync.event("_rourke_resolved", [fate]))
		rourke.hit_player.connect(func(): sync.event("_say_once", ["l7_rourke_dark"]))
		rourke.downed.connect(func(): sync.event("_say_once", ["l7_rourke_down"]))


## The Watcher moves only in the dark: anywhere outside the ring is lit, and in the
## ring its zone's lights hold it still.
func _held_by_light(w: Node3D) -> bool:
	var at := to_local(w.global_position)
	for i in ZONE_BOXES.size():
		if (ZONE_BOXES[i] as AABB).grow(0.1).has_point(at):
			return zone_on(data.zones[i].id)
	return true


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
		d.puzzles = [token_puzzle, restore_puzzle, zones_puzzle, lights_puzzle, warden_puzzle, lifts_puzzle]
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
	for k in staffers:
		sync.replicate(staffers[k], staffers[k].sync_properties())
	sync.replicate(watcher, watcher.sync_properties())
	if custodian:
		custodian.crew = crew
		sync.replicate(custodian, custodian.sync_properties())
	if rourke:
		sync.replicate(rourke, rourke.sync_properties())


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
	if completed.get_connections().is_empty():
		completed.connect(_on_completed)
	if not watcher.caught.is_connected(_on_watcher_caught):
		watcher.caught.connect(_on_watcher_caught)
	if _is_host():
		for k in staffers:
			staffers[k].walk_to(to_global(NIGHT_SHIFT[k].office))
	if player and not player.inventory.selected.is_connected(_on_selected):
		player.inventory.selected.connect(_on_selected)
	hud.todo(TASK_TITLES.todo_arrive, TEXT.todo_arrive)
	hud.notice(TEXT.arrive, 5.0)
	_lines(["l7_arrive_pa", "l7_arrive_tease", "l7_ines_lobby"], 0.8)
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
	a.add_key(data.key, ["lights", "lifts", "plant", "auth_admin"], "IT admin")
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
	# The fight's services: the ring's controller, the auth log, the plant rooms' gas.
	a.route("GET", "/controller", func(_p):
		return {"status": 200, "body": _controller_json()}, "lights", "token")
	a.route("PATCH", "/controller", func(_p, req):
		return _patch_controller(req), "lights", "token")
	a.route("GET", "/auth/log", func(_p):
		return {"status": 200, "body": {"entries": _auth_log()}}, "auth_admin", "token")
	a.route("GET", "/suppression", func(_p):
		return {"status": 200, "body": {"rooms": gas.keys().map(_gas_json)}}, "plant", "token")
	a.route("POST", "/suppression/:id/abort", func(p, req):
		return _abort_gas(str(p[0]).to_upper(), req), "plant", "token")
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
	# The watchdog's last stand: WARDEN holds one zone dark. The switch answers, and
	# the zone stays off; only a check that reads the answer notices.
	if not bench and z.id == held_zone and req.body.on:
		var held := _zone_json(z.id, false)
		held["held"] = "security control"
		return {"status": 200, "body": held}
	if not bench and req.body.on and cut_zones.has(z.id):
		_relit[z.id] = true
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
	# The network closet's maglock is on the south-west zone's circuit, and fails open
	# when it loses power. Once the crew fights back, the dark lets them in.
	if not on and id == data.zones[0].id and fight_stage >= 2 and not closet_open:
		_closet_opens()
	# Lights out, for real: the whole ring lit at once ends the first stage.
	if on and fight_stage == 1 and _is_host() and ring_lit() and not _stage2_sent:
		_stage2_sent = true
		sync.event("_begin_stage2")


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
	return {"id": l.id, "name": l.name, "state": cars.get(l.id, "stopped"), "controller": "held by WARDEN" if warden_holds else "ready"}


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
	if cars.get(l.id, "") == "in service":
		return {"status": 200, "body": {"id": l.id, "state": "in service"}}
	cars[l.id] = "restarting"
	return {"status": 202, "body": {"id": l.id, "state": "restarting", "note": "Check back in a few seconds: GET /lifts/%s" % l.id}}


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
	# 4a. Lights out, for real: the tested script, used under pressure. Review ladder.
	lights_puzzle = RequestPuzzle.new("lights_out", _every_script(key, ids), func(_l, _r): return false, [
		"it's the bench's script. it already gets its own token at the top, so WARDEN revoking yours doesn't matter.\n" +
		"  run it here, on the real floor: a deck or the admin terminal, not the bench.",
		"type .script on your deck, write the bench's script again (or open what you saved), and ^R. every ring zone has to be lit at the same moment.",
		"type .script, then this, then ^R:\n    [color=#ffffff]%s[/color]" % _every_script(key, ids),
	], func(): return fight_stage >= 2)
	lights_puzzle.case_id = "lights_out"
	# 4b. Beat him: three routes (call 1a), each its own way in. Ladder A for the new
	# requests, the review ladder for the rest.
	warden_puzzle = RequestPuzzle.new("warden", _revoke_script(key), func(_l, _r): return false, [
		"three ways. pick one each:\n" +
		"  lockout   the network closet off the south corridor. its door opens when its zone is dark. inside: his uplink. then\n" +
		"            [color=#ffffff]PATCH /controller {\"source\": \"local\"}[/color]   moves the ring to the local controller\n" +
		"  revoke    [color=#ffffff]GET /auth/log[/color]   every token B2 gave out, and whose. his says WARDEN. then\n" +
		"            [color=#ffffff]POST /auth/revoke {\"token\": \"enter_token\"}[/color]   ends a token\n" +
		"  watchdog  a while loop round your function: relight every zone, assert each one, await sleep, again\n" +
		"every request needs your token in the Authorization header.",
		"he has a spare of everything. pull the uplink and he finds the backup: move the ring to local. revoke his token and he mints more: revoke every one. outrun him and he holds a zone: let the assert catch it.",
		"revoke: type .script, then this, then ^R:\n    [color=#ffffff]%s[/color]\n" % _revoke_script(key) +
		"watchdog: type .script, then this, then ^R:\n    [color=#ffffff]%s[/color]\n" % _watchdog_script(key, ids) +
		"lockout: when the closet's door opens, go in and pull the uplink (E). then type this, with your token:\n    [color=#ffffff]PATCH /controller\nAuthorization: Bearer <the token>\n\n{\"source\": \"local\"}[/color]",
	], func(): return fight_stage >= 4)
	warden_puzzle.case_id = "warden"
	# 5. The lifts: GET, then a POST for each car (a list again). Review ladder.
	var passenger: Array = data.lifts.filter(func(l): return l.kind == "passenger").map(func(l): return l.id)
	passenger.sort()
	lifts_puzzle = RequestPuzzle.new("lifts", _lifts_script(key, passenger), func(_l, _r): return false, [
		"the shape:\n    [color=#ffffff]GET /lifts[/color]   which cars come down here, and their state\n" +
		"    [color=#ffffff]POST /lifts/enter_id/restart {}[/color]   restarts one; give it a few seconds, then GET it again\n" +
		"enter_id is a passenger car's id. each needs your token.",
		"two passenger cars come down to B2. the freight lift's sign says why it stays where it is.",
		"type .script, then this, then ^R:\n    [color=#ffffff]%s[/color]" % _lifts_script(key, passenger),
	], func(): return Game.case_info("lifts").get("solved", false))
	lifts_puzzle.case_id = "lifts"


## The top every B2 script needs: a token for the key, and the header that carries it,
## then the admin's function, finished (it returns its answer).
static func _restore_fn(key: String) -> String:
	return "let key = \"%s\";\nlet login = await api.post(\"/auth/token\", {\"key\": key});\nlet auth = {\"Authorization\": \"Bearer \" + login.body.token};\n\nasync function restore(zone) {\n  let res = await api.get(\"/lights/\" + zone, auth);\n  if (res.body.on !== true) {\n    res = await api.patch(\"/lights/\" + zone, {\"on\": true}, auth);\n  }\n  return res;\n}\n" % key


static func _one_script(key: String, zone: String) -> String:
	return _restore_fn(key) + "\nlet answer = await restore(\"%s\");\nassert(answer.body.on, \"%s is lit\");" % [zone, zone]


static func _every_script(key: String, ids: Array) -> String:
	var list: String = ", ".join(PackedStringArray(ids.map(func(i): return "enter_zones" if i == "enter_zones" else "\"%s\"" % i)))
	return _restore_fn(key) + "\nlet zones = [%s];\nfor (const zone of zones) {\n  let answer = await restore(zone);\n  assert(answer.body.on, zone + \" is lit\");\n}\nconsole.log(zones.length + \" zones lit\");" % list


## The top of a script that keeps going: the key, and the function, which reads its
## token from auth (each pass gets a fresh one: tokens run out).
static func _loop_top(key: String) -> String:
	return "let key = \"%s\";\nlet auth = {};\n\nasync function restore(zone) {\n  let res = await api.get(\"/lights/\" + zone, auth);\n  if (res.body.on !== true) {\n    res = await api.patch(\"/lights/\" + zone, {\"on\": true}, auth);\n  }\n  return res;\n}\n" % key


static func _login() -> String:
	return "  let login = await api.post(\"/auth/token\", {\"key\": key});\n  auth = {\"Authorization\": \"Bearer \" + login.body.token};\n"


## The watchdog: every zone, every pass, each one asserted; then a breath.
static func _watchdog_script(key: String, ids: Array) -> String:
	var list: String = ", ".join(PackedStringArray(ids.map(func(i): return "\"%s\"" % i)))
	return _loop_top(key) + "\nlet zones = [%s];\nwhile (true) {\n" % list + _login() + "  for (const zone of zones) {\n    let answer = await restore(zone);\n    assert(answer.body.on, zone + \" is lit\");\n  }\n  await sleep(1000);\n}"


## Revoke every live token WARDEN holds, again and again (he mints more).
static func _revoke_script(key: String) -> String:
	return "let key = \"%s\";\nlet auth = {};\nwhile (true) {\n" % key + _login() + "  let log = await api.get(\"/auth/log\", auth);\n  for (const entry of log.body.entries) {\n    if (entry.holder === \"WARDEN\") {\n      if (entry.state === \"ok\") {\n        await api.post(\"/auth/revoke\", {\"token\": entry.token}, auth);\n        console.log(\"revoked \" + entry.token);\n      }\n    }\n  }\n  await sleep(2000);\n}"


## Restart each passenger car, wait, and check each one is in service.
static func _lifts_script(key: String, ids: Array) -> String:
	var list: String = ", ".join(PackedStringArray(ids.map(func(i): return "\"%s\"" % i)))
	return "let key = \"%s\";\nlet login = await api.post(\"/auth/token\", {\"key\": key});\nlet auth = {\"Authorization\": \"Bearer \" + login.body.token};\n\nlet cars = [%s];\nfor (const car of cars) {\n  await api.post(\"/lifts/\" + car + \"/restart\", {}, auth);\n}\nawait sleep(6000);\nfor (const car of cars) {\n  let res = await api.get(\"/lifts/\" + car, auth);\n  assert(res.body.state === \"in service\", car + \" is in service\");\n}" % [key, list]


func puzzles() -> Array:
	return [token_puzzle, restore_puzzle, zones_puzzle, lights_puzzle, warden_puzzle, lifts_puzzle]


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
		elif error.begins_with("That token was revoked"):
			sync.event("_tip", ["revoked", which])
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
	if link.service != "floor":
		return
	# The fight: a route's step, read from what the services were left doing.
	if status == 200 and method == "POST" and path == "/auth/revoke" and body is Dictionary:
		var gone := str(body.get("token", ""))
		if gone == data.warden_token and fight_stage in [2, 3] and int(route_done.revoke) == 0:
			sync.event("_route_step", ["revoke"])
		elif minted and data.warden_minted.has(gone) and not warden_token_live() and fight_stage == 3:
			sync.event("_warden_beaten", ["revoke"])
	elif status == 200 and method == "PATCH" and path == "/controller" and controller_source == "local" and fight_stage in [2, 3]:
		sync.event("_warden_beaten", ["lockout"])
	elif status == 200 and method == "PATCH" and path.begins_with("/lights/") and body is Dictionary:
		var id := str(body.get("id", ""))
		if _relit.has(id):
			_relit.erase(id)
			var term := _terminal(which)
			var rt = term.get_meta("script_runtime") if term and term.has_meta("script_runtime") else null
			if rt and rt.is_running() and fight_stage in [2, 3] and int(route_done.watchdog) == 0:
				_relights[which] = int(_relights.get(which, 0)) + 1
				if int(_relights[which]) >= watchdog_relights:
					sync.event("_route_step", ["watchdog"])
	elif status == 202 and method == "POST" and path.begins_with("/lifts/"):
		_later(lift_start, "_car_ready", [str(body.get("id", "")) if body is Dictionary else ""])
	elif status == 409 and path == "/controller":
		sync.event("_tip", ["controller", which])
	elif status == 400 and path.begins_with("/suppression/"):
		sync.event("_tip", ["gas", which, [path.get_slice("/", 2).to_upper()]])


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
			_begin_fight()


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
		else:
			var which: String = (t.api as Link).terminal
			rt.started.connect(func(): _relights[which] = 0)
			rt.finished.connect(_on_floor_finished.bind(which))


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


## Host: a script on the floor ended. On the watchdog's last stand, an assert that
## failed on the zone WARDEN holds logs the fault that beats him.
func _on_floor_finished(ok: bool, err: Dictionary, which: String) -> void:
	if not _is_host() or ok:
		return
	var message := str(err.get("message", ""))
	if message.contains("without waiting"):
		sync.event("_tip", ["no_sleep", which])
	if fight_stage == 3 and held_zone != "" and message.begins_with("assert failed") and message.contains(held_zone):
		sync.event("_fault", [held_zone])


## Every machine: the bench prints its verdict on its own screen, in-world: how many
## zones it lit, how many tests passed, and which zones are still dark.
func _bench_report(lit: int, passes: int, em: bool) -> void:
	bench_terminal.print_line(TEXT.bench_report % [lit, data.zones.size(), passes])
	if em:
		bench_terminal.print_line(TEXT.bench_em)
	if lit > 0 and lit < data.zones.size() and restore_puzzle.solved:
		bench_terminal.print_line(TEXT.bench_dark % ", ".join(PackedStringArray(_bench_dark())))


# --- The fight (case 4): lights out, for real ---------------------------------------------

## Every ring zone lit on the real floor.
func ring_lit() -> bool:
	return data.zones.all(func(z): return zone_on(z.id))


## Every machine: the bench has proved the script. Ines and Tomas see the plan and go
## to shelter; WARDEN revokes every token the crew had, and starts cutting for real.
func _begin_fight() -> void:
	if fight_stage != 0:
		return
	fight_stage = 1
	for t in api.tokens():
		if api.token_label(t) == "IT admin" and api.token_state(t) == "ok":
			api.revoke_token(t)
	if watcher:
		watcher.active = true
	_open_case("lights_out")
	if hud and is_inside_tree():
		hud.todo(TASK_TITLES.todo_fight, TEXT.case_lights_do)
		hud.notice(TEXT.revoked_all, 5.0, ThemeUtil.RED)
	_lines(["l7_ines_plan", "l7_tomas_shelter"], 0.6)
	_shelter()
	_cut_clock = 0.0


## WARDEN's beat right now: the run's, stretched by every stage the crew has finished.
func cut_interval() -> float:
	var steps := (1 if fight_stage >= 2 else 0)
	for r in route_done:
		steps += int(route_done[r])
	return (cut_every if cut_every > 0.0 else float(data.cut_every)) * pow(SLOWER, steps)


## Can WARDEN switch the ring right now? Through his uplink (or the backup) and, once
## he's logged in to the services, with a token that still works.
func warden_can_cut() -> bool:
	if fight_stage < 1 or fight_stage > 3:
		return false
	if controller_source != "uplink" and controller_source != "uplink-b":
		return false
	return fight_stage == 1 or warden_token_live()


func warden_token_live() -> bool:
	if api.token_state(data.warden_token) == "ok":
		return true
	return minted and data.warden_minted.any(func(t): return api.token_state(t) == "ok")


## Host: which zones he cuts on this beat. Two lit ones (three on the watchdog's last
## stand); never the closet's in the first stage, and always the closet's first once
## the crew fights back (its maglock fails open in the dark).
func _choose_cut() -> Array:
	var lit: Array = data.zones.map(func(z): return z.id).filter(func(id): return zone_on(id) and id != held_zone)
	if fight_stage == 1:
		lit.erase(data.zones[0].id)
	var out := []
	if fight_stage >= 2 and not closet_open and lit.has(data.zones[0].id):
		out.append(data.zones[0].id)
		lit.erase(data.zones[0].id)
	for i in range(lit.size() - 1, 0, -1):
		var j := _cut_rng.randi_range(0, i)
		var tmp = lit[i]
		lit[i] = lit[j]
		lit[j] = tmp
	var count := 3 if int(route_done.watchdog) >= 1 else 2
	for id in lit:
		if out.size() >= count:
			break
		out.append(id)
	return out


## Host, every frame of the fight: WARDEN's beat.
func _fight_tick(delta: float) -> void:
	if not warden_can_cut():
		return
	_cut_clock += delta
	if _cut_clock < cut_interval():
		return
	_cut_clock = 0.0
	var ids := _choose_cut()
	if not ids.is_empty():
		sync.event("_warden_cut", [ids])


## Every machine: WARDEN cuts zones in the fight. The first cut of each stage is heard.
func _warden_cut(ids: Array) -> void:
	for id in ids:
		_set_zone(str(id), false)
	if hud and is_inside_tree():
		hud.notice(TEXT.cut, 2.5, ThemeUtil.RED)


## Every machine: the closet's door slides open in the dark.
func _closet_opens() -> void:
	closet_open = true
	db.run_silent("UPDATE doors SET locked = 0 WHERE id = 'B2-NETCL'")
	db.door_changed.emit("B2-NETCL", false, false)
	if hud and is_inside_tree():
		hud.notice(TEXT.closet_open, 4.0)


## Every machine: the ring was lit all at once. WARDEN logs in to the services himself
## (his token is in the auth log from now on) and fights back: the hunters come, and
## the motor room's gas is armed.
func _begin_stage2() -> void:
	if fight_stage != 1:
		return
	fight_stage = 2
	lights_puzzle.solved = true
	Game.solve_case("lights_out", TEXT.lights_done)
	_open_case("warden")
	api.add_key(data.warden_key, ["lights", "lifts", "plant"], "WARDEN")
	api.add_token(data.warden_token, data.warden_key)
	warden_logged_in = true
	uplink.enabled = true
	if hud and is_inside_tree():
		hud.todo(TASK_TITLES.todo_warden, TEXT.case_warden_do)
		hud.notice(TEXT.stage2, 5.0, ThemeUtil.RED)
	_lines(["l7_stage2_pa", "l7_stage2_tease"], 0.8)
	if _is_host():
		_cut_clock = cut_interval() - 2.0  # he answers at once
		_arm("B2-MOTOR")
		if custodian:
			custodian.activate()
		if rourke:
			_later(4.0, "_rourke_arrives")


## Every machine: a route's step is done. The first one done on any route starts the
## last stand (and arms the battery room's gas).
func _route_step(route: String) -> void:
	route_done[route] = int(route_done[route]) + 1
	if int(route_done[route]) != 1:
		return
	if fight_stage == 2:
		fight_stage = 3
		_lines(["l7_stage3_tease"])
		if _is_host():
			_arm("B2-UPS")
	match route:
		"revoke":
			if hud and is_inside_tree():
				hud.notice(TEXT.warden_revoked, 4.0)
			if _is_host():
				_later(mint_after, "_mint")
		"watchdog":
			held_zone = data.held_zone
			_set_zone(held_zone, false)
			if hud and is_inside_tree():
				hud.notice(TEXT.watchdog, 4.0)
				hud.notice.call_deferred(TEXT.held, 4.0, ThemeUtil.RED)


## Every machine: lockout, stage 2. The uplink's out; the controller looks for its backup.
func _pull_uplink() -> void:
	if uplink_pulled:
		return
	uplink_pulled = true
	uplink.enabled = false
	uplink.visible = false
	controller_source = "none"
	if hud and is_inside_tree():
		hud.notice(TEXT.uplink_pulled, 4.0)
	_route_step("lockout")
	if _is_host():
		_later(failover_after, "_failover")


## Every machine: lockout's last stand. The backup uplink takes the ring.
func _failover() -> void:
	if controller_source != "none":
		return
	controller_source = "uplink-b"
	if hud and is_inside_tree():
		hud.notice(TEXT.failover, 4.0, ThemeUtil.RED)


## Every machine: revoke's last stand. He mints tokens off a backup key.
func _mint() -> void:
	if minted or fight_stage == 4:
		return
	minted = true
	api.add_key(data.warden_key + "-b", ["lights", "lifts", "plant"], "WARDEN")
	for t in data.warden_minted:
		api.add_token(t, data.warden_key + "-b")
	if hud and is_inside_tree():
		hud.notice(TEXT.minted, 4.0, ThemeUtil.RED)


func _controller_json() -> Dictionary:
	return {"source": controller_source, "uplink": "pulled" if uplink_pulled else "connected",
		"backup": "active" if controller_source == "uplink-b" else "standby",
		"local": "active" if controller_source == "local" else "standby"}


## PATCH /controller {"source": "local"}: only with his uplink pulled.
func _patch_controller(req: Dictionary) -> Dictionary:
	var bad := FacilityAPI.check_fields(req.body, {"source": TYPE_STRING})
	if bad != "":
		return {"status": 400, "body": {"error": bad + " The ring moves to the local controller with {\"source\": \"local\"}"}}
	if str(req.body.source).to_lower() != "local":
		return {"status": 400, "body": {"error": "From here the ring can only move to the local controller: {\"source\": \"local\"}"}}
	if not uplink_pulled:
		return {"status": 409, "body": {"error": "The security uplink is connected: the ring follows it. It's patched in the network closet."}}
	controller_source = "local"
	return {"status": 200, "body": _controller_json()}


## GET /auth/log: everyone who asked B2 for a token, oldest first, and what state each
## token is in. WARDEN's own shows once he's logged in; the crew's (the IT admin's key)
## and his backup key's as they're given out.
func _auth_log() -> Array:
	var out := []
	for e in data.auth_log:
		if e.token == data.warden_token:
			if warden_logged_in:
				out.append({"token": e.token, "holder": e.holder, "issued": e.issued, "state": api.token_state(e.token)})
			continue
		out.append(e.duplicate())
	for t in api.tokens():
		if t == data.warden_token or t == data.example_token:
			continue
		var holder := "IT admin (G.P.)" if api.token_label(t) == "IT admin" else "WARDEN"
		out.append({"token": t, "holder": holder, "issued": "Thu 10/16 %s" % data.clock, "state": api.token_state(t)})
	return out


# --- The night-shifters and the gas -------------------------------------------------------

## Every machine: Ines and Tomas go to shelter in the plant rooms (their badges open them).
func _shelter() -> void:
	for k in NIGHT_SHIFT:
		if shift_state[k] == "dead":
			continue
		var room: String = NIGHT_SHIFT[k].room
		_set_door(room, false)
		shift_state[k] = "walking"
		if _is_host() and staffers.has(k):
			staffers[k].walk_to(to_global(NIGHT_SHIFT[k].inside))
			_later(25.0, "_trap", [k])  # however the walk went, they're in there by now


func _on_staffer_arrived(k: String) -> void:
	if not _is_host():
		return
	if shift_state.get(k, "") == "walking":
		sync.event("_trap", [k])


## Every machine: they're inside, and WARDEN locks the door behind them.
func _trap(k: String) -> void:
	if shift_state[k] != "walking":
		return
	shift_state[k] = "trapped"
	if staffers.has(k):
		staffers[k].global_position = to_global(NIGHT_SHIFT[k].inside)
		staffers[k].state = "waiting"
	_set_door(NIGHT_SHIFT[k].room, true)
	if hud and is_inside_tree():
		hud.notice(TEXT.trapped % NIGHT_SHIFT[k].first, 4.0, ThemeUtil.RED)
	if not said.has("l7_trap_pa"):
		said["l7_trap_pa"] = true
		_lines(["l7_trap_pa", "l7_trap_tease"], 0.8)


## Every machine: a door on the building's doors table opens (false) or locks (true).
func _set_door(id: String, is_locked: bool) -> void:
	db.run_silent("UPDATE doors SET locked = %d WHERE id = '%s'" % [1 if is_locked else 0, id])
	db.door_changed.emit(id, is_locked, false)


func _who_in(room: String) -> String:
	for k in NIGHT_SHIFT:
		if NIGHT_SHIFT[k].room == room:
			return k
	return ""


func _gas_time(room: String) -> float:
	return float(gas_seconds.get(room, data.suppression[room]))


## Host: WARDEN arms a plant room's gas suppression with someone inside.
func _arm(room: String) -> void:
	if gas.get(room, "") != "idle" or shift_state.get(_who_in(room), "") == "dead":
		return
	sync.event("_gas_armed", [room])
	var t := _gas_time(room)
	if t > 30.0:
		_later(t - 30.0, "_gas_warn", [room])
	_later(t, "_discharge", [room])


## Every machine: the countdown starts.
func _gas_armed(room: String) -> void:
	if gas[room] != "idle":
		return
	gas[room] = "armed"
	_gas_armed_msec[room] = Time.get_ticks_msec()
	var k := _who_in(room)
	if hud and is_inside_tree():
		hud.notice(TEXT.gas_armed % [SHELTER_NAMES[room], NIGHT_SHIFT[k].first, int(_gas_time(room))], 6.0, ThemeUtil.RED)
	_lines(GAS_LINES[room], 0.6)


func _gas_warn(room: String) -> void:
	if gas[room] == "armed" and hud and is_inside_tree():
		hud.notice(TEXT.gas_warn % SHELTER_NAMES[room], 4.0, ThemeUtil.RED)


## Every machine: nobody aborted it.
func _discharge(room: String) -> void:
	if gas[room] != "armed":
		return
	gas[room] = "discharged"
	var k := _who_in(room)
	shift_state[k] = "dead"
	if staffers.has(k):
		staffers[k].die()
	if hud and is_inside_tree():
		hud.notice(TEXT.gas_lost % [SHELTER_NAMES[room], NIGHT_SHIFT[k].first], 6.0, ThemeUtil.RED)


func _gas_json(room: String) -> Dictionary:
	var out := {"id": room, "name": SHELTER_NAMES[room], "state": gas[room]}
	if gas[room] == "armed":
		var left := _gas_time(room) - (Time.get_ticks_msec() - int(_gas_armed_msec.get(room, 0))) / 1000.0
		out["seconds_left"] = maxi(0, int(snappedf(left, 5.0)))
	return out


## POST /suppression/<room>/abort {}: every machine (the request runs everywhere).
func _abort_gas(room: String, req: Dictionary) -> Dictionary:
	if not gas.has(room):
		return {"status": 404, "body": {"error": "No suppression zone %s on B2. GET /suppression lists them." % room}}
	var bad := FacilityAPI.check_fields(req.body, {})
	if bad != "":
		return {"status": 400, "body": {"error": bad + " An abort's body is empty: {}"}}
	match gas[room]:
		"idle":
			return {"status": 409, "body": {"error": "Nothing is armed in the %s." % SHELTER_NAMES[room]}}
		"aborted":
			return {"status": 200, "body": _gas_json(room)}
		"discharged":
			return {"status": 409, "body": {"error": "The %s has already discharged." % SHELTER_NAMES[room]}}
	gas[room] = "aborted"
	var k := _who_in(room)
	if hud and is_inside_tree():
		hud.notice(TEXT.gas_saved % NIGHT_SHIFT[k].first, 4.0)
	_say_once(SAVED_LINES[k])
	if fight_stage == 4:
		_let_out(k)
	return {"status": 200, "body": _gas_json(room)}


## Every machine: a shelter's door opens again, and whoever's alive in there comes out
## to the lobby to wait for the lifts.
func _let_out(k: String) -> void:
	if shift_state[k] != "trapped":
		return
	_set_door(NIGHT_SHIFT[k].room, false)
	shift_state[k] = "out"
	if _is_host() and staffers.has(k):
		staffers[k].walk_to(to_global(Vector3(-1.5 if k == "ines" else 1.5, 0, -3.5)))


# --- WARDEN beaten ------------------------------------------------------------------------

## Every machine: a route's last stand is done. The lights come on and stay on; the
## lift controller is free; his new rules name the crew.
func _warden_beaten(route: String) -> void:
	if fight_stage == 4:
		return
	if int(route_done[route]) < 2:
		route_done[route] = 2
	fight_stage = 4
	warden_puzzle.solved = true
	Game.warden_route = route
	warden_holds = false
	held_zone = ""
	for z in data.zones:
		_set_zone(z.id, true)
	if watcher:
		watcher.active = false
	_write_rules(route)
	Game.solve_case("warden", TEXT["warden_done_" + route])
	_open_case("lifts")
	for k in NIGHT_SHIFT:
		if gas[NIGHT_SHIFT[k].room] != "armed":
			_let_out(k)
	if hud and is_inside_tree():
		hud.todo(TASK_TITLES.todo_lifts, TEXT.case_lifts_do)
		hud.notice(TEXT.beaten, 5.0)
	_lines(["l7_beaten_pa", "l7_beaten_tease"], 0.8)


## Every machine: the zone he held failed a watchdog's check. Facilities' fault rule
## hands it to manual, and nobody remote can hold it.
func _fault(zone: String) -> void:
	if hud and is_inside_tree():
		hud.notice(TEXT.fault % zone, 5.0)
	_warden_beaten("watchdog")


## His 4.0 rows: the crew by the names on the job ticket, and the route that beat him.
func _write_rules(route: String) -> void:
	var rows := [[int(RULES_4.opener[0]), str(RULES_4.opener[1])]]
	var n: int = RULES_4.opener[0] + 1
	for who in crew_names():
		rows.append([n, RULES_4.name % who])
		n += 1
	rows.append([n, str(RULES_4[route])])
	for r in rows:
		db.run_silent("INSERT INTO warden_protocols VALUES (%d, '4.0', '%s')" % [r[0], str(r[1]).replace("'", "''")])


## The crew's names, as the job ticket has them (one per player, in seat order).
func crew_names() -> Array:
	var net := get_node_or_null("/root/Net")
	if net == null or not "roster" in net:
		return ["The technician"]
	if net.roster.is_empty():
		return [str(net.player_name)] if str(net.player_name) != "" else ["The technician"]
	var ids: Array = net.roster.keys()
	ids.sort()
	return ids.map(func(id): return str(net.roster[id]))


# --- The hunters ----------------------------------------------------------------------------

## Every machine: Rourke comes down STAIR 2 with a torch.
func _rourke_arrives() -> void:
	if rourke == null or Game.rourke_fate == "killed":
		return
	rourke.visible = true
	if _is_host():
		rourke.global_position = to_global(Stairwell.landing_slot(STAIR_AT, STAIR_YAW, 0))
		var target = player if player else null
		rourke.start_chase(target)
	_say_once("l7_rourke_arrive")


func _rourke_resolved(fate: String) -> void:
	Game.rourke_fate = fate


## Every machine: a line heard once a run.
func _say_once(id: String) -> void:
	if said.has(id):
		return
	said[id] = true
	_say(id)


func _on_watcher_caught(p: Node) -> void:
	if p.has_method("take_damage") and p.health > 0.0:
		p.take_damage(1000.0, "watcher")  # out cold: teammates can help them up


# --- The lifts (case 5) and the ride up ---------------------------------------------------

## Every machine: a car finished restarting.
func _car_ready(id: String) -> void:
	if cars.get(id, "") != "restarting":
		return
	cars[id] = "in service"
	if hud and is_inside_tree():
		hud.notice(TEXT.car_ready % id, 3.0)
	var passenger: Array = data.lifts.filter(func(l): return l.kind == "passenger")
	if passenger.all(func(l): return cars[l.id] == "in service") and not Game.case_info("lifts").get("solved", false):
		lifts_puzzle.solved = true
		Game.solve_case("lifts", TEXT.lifts_done)
		if _is_host():
			_later(car_after, "_car_arrives")


## Every machine: the car comes down for the crew, and opens on the lobby. Whoever
## lived walks in.
func _car_arrives() -> void:
	if car_here:
		return
	car_here = true
	car_door.set_open(true)
	if hud and is_inside_tree():
		hud.notice(TEXT.car_here % data.car, 4.0)
		hud.todo(TASK_TITLES.todo_car, TEXT.todo_car)
	for k in NIGHT_SHIFT:
		if shift_state[k] == "out" and _is_host() and staffers.has(k):
			staffers[k].walk_to(to_global(Vector3(-5.6 if k == "ines" else -4.8, 0, -4.0)))
	var t := Trigger.create(self, CAR.get_center(), Vector3(CAR.size.x - 0.4, 2.4, CAR.size.z - 0.4))
	t.name = "CarTrigger"
	t.require_all = true
	if sync:
		t.waiting.connect(func(n, total): sync.team_notice(TEXT.car_wait % [n, total]))
	t.entered.connect(func(_b): sync.event("_ride"), CONNECT_ONE_SHOT)


## Every machine: everyone's in the car. The doors close, and it climbs to 18.
func _ride() -> void:
	if riding:
		return
	riding = true
	car_door.set_open(false)
	for k in NIGHT_SHIFT:
		if shift_state[k] == "out" and staffers.has(k):
			staffers[k].global_position = to_global(Vector3(-5.6 if k == "ines" else -4.8, 0, -4.0))
			staffers[k].state = "waiting"
	hello_book.visible = true
	hello_book.enabled = true
	if hud and is_inside_tree():
		hud.notice(TEXT.ride, 4.0)
	var floors := ["B2", "B1", "G"]
	for f in range(1, 19):
		floors.append(str(f))
	for i in floors.size():
		if not is_inside_tree():
			return
		_car_floor.text = floors[i]
		await get_tree().create_timer(ride_time / floors.size(), false).timeout
	_on_18()


## Every machine: the back doors open on 18's lift lobby.
func _on_18() -> void:
	if arrived_18 or not is_inside_tree():
		return
	arrived_18 = true
	car_rear.set_open(true)
	if hud:
		hud.notice(TEXT.on_18, 3.0)
	var t := Trigger.create(self, ON_18.get_center() + Vector3(-0.4, 0, 0), Vector3(2.4, 2.4, 2.0))
	t.name = "Arrive18"
	t.require_all = true
	if sync:
		t.waiting.connect(func(n, total): sync.team_notice(TEXT.car_wait % [n, total]))
	t.entered.connect(func(_b): sync.event("_act2_end"), CONNECT_ONE_SHOT)


## Every machine: someone found the book behind the handrail.
func _book_taken(peer_id: int) -> void:
	if book_found:
		return
	book_found = true
	hello_book.enabled = false
	hello_book.visible = false
	if hud and is_inside_tree():
		hud.notice(TEXT.book_taken, 5.0)
	_say_once("l8_book_find")


## The night-shift achievement this run earns (everyone, for beating the level together).
func night_shift_achievement() -> String:
	var alive: Array = NIGHT_SHIFT.keys().filter(func(k): return shift_state[k] != "dead")
	if alive.size() == 2:
		return "achievement:b2_both_saved"
	if alive.is_empty():
		return "achievement:b2_both_lost"
	return "achievement:b2_%s_only" % alive[0]


## Every machine: the crew steps out on 18. End of Act 2.
func _act2_end() -> void:
	if Game.completed_level == "level_7":
		return
	var net := get_node_or_null("/root/Net")
	if net:
		net.earn("achievement:floor_b2", hud)
		net.earn(night_shift_achievement(), hud)
	Game.night_shift_alive.clear()
	for k in NIGHT_SHIFT:
		if shift_state[k] != "dead":
			Game.night_shift_alive.append(k)
	Game.completed_level = "level_7"
	Game.next_level = ""
	if player:
		player.input_locked = true
	if hud and is_inside_tree():
		await Level2FX.end_card(self, TEXT.end_card)
	completed.emit()


func _on_completed() -> void:
	if hud:
		await hud.fade(true, 1.2)
	finish_level("field_notes")


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
	if _is_host():
		_fight_tick(delta)
		if not said.has("l7_tomas_ring") and player and _in_ring(to_local(player.global_position)):
			sync.event("_say_once", ["l7_tomas_ring"])
	# Solo: B2's scripts keep running while you're away from their runner. (Online,
	# ScriptHost runs them on the host.)
	if sync == null or not sync.is_online():
		for t in _script_terminals():
			var rt = t.get_meta("script_runtime") if t.has_meta("script_runtime") else null
			if rt and rt.is_running():
				rt.tick(delta)
	_follow_decks()


func _in_ring(at: Vector3) -> bool:
	return ZONE_BOXES.any(func(b): return (b as AABB).has_point(at))


func on_player_died() -> void:
	player.respawn(spawn_point())
