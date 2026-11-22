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
## The practice is safe: the air only starts to count once the power is back and
## the crew has asked something since, and a loose Custodian only starts up the dock
## stairs 180 s after the people case opens, once the crew is at the passes, or when
## the loading door is opened. Cases open one at a time and chapters land on their
## gates (the v0.10 package, plan/approvals/puzzle-flow-floor-9.md). A chapter of the
## book stops nothing (Huddle).
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
	"todo_arrive": "Find HR's badge log and check where the crew's badges were tonight",
	"todo_key": "Get the HR service to answer",
	"todo_power": "Get payroll's lights and the cage lock back on",
	"todo_air": "Get the air moving again",
	"todo_radio": "Someone on the radio wants the loading door open. Find out who's really there",
	"todo_people": "Find the two night-shifters, log an escort pass for each one, and lock every door behind you",
	"todo_down": "Take STAIR 2 down, with both night-shifters",
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

## Each task's title: how the crew feels and what's going on (Augustine, approved
## 2026-11-05: plan/approvals/task-titles.md). Its details are TEXT under the same key.
const TASK_TITLES := {
	"todo_arrive": "Prove where we were",
	"todo_key": "HR won't talk to us",
	"todo_power": "Payroll's in the dark",
	"todo_air": "Getting hard to breathe",
	"todo_radio": "That sounds like one of us",
	"todo_people": "Nobody gets left behind",
	"todo_down": "Down we go",
}

# --- The v0.10 package (plan/approvals/puzzle-flow-floor-9.md, approved 2026-11-22) -----

## A slot answered only by pointing at a cell, never by a noted line.
const NO_LINE := ["\u0001"]
## Every case on the floor asks with the HR key: each has it as a piece (N8).
const KEY_CASES := ["hr_key", "frame", "panel_power", "air", "radio", "people", "vale"]
## Each case's query under its chip (N1-N7): {piece} is a found piece or its blank.
const KEY_QUERY := "GET /staff\nX-Api-Key: {key}"
const FRAME_QUERY := "GET /swipes/{badge}\nX-Api-Key: {key}"
const POWER_QUERY := "PATCH /circuits/{circuit}\nX-Api-Key: {key}\n\n{\"on\": true}"
const POWER_READ_QUERY := "GET /circuits\nX-Api-Key: {key}"
const AIR_QUERY := "POST /work_orders\nX-Api-Key: {key}\n\n{\"floor\": {floor}, \"unit\": \"{unit}\", \"fault\": \"no air\"}"
const AIR_READ_QUERY := "GET /work_orders\nX-Api-Key: {key}"
const RADIO_QUERY := "GET /swipes/enter_badge\nX-Api-Key: {key}"
const PASS_QUERY := "POST /escorts\nX-Api-Key: {key}\n\n{\"badge\": \"{their_badge}\", \"escort\": \"{our_badge}\"}"
const LOCK_QUERY := "PATCH /doors/enter_door\nX-Api-Key: {key}\n\n{\"locked\": true}"
const DOORS_READ_QUERY := "GET /doors\nX-Api-Key: {key}"
const VALE_QUERY := "GET /staff/{vale_badge}\nX-Api-Key: {key}"
## The cases' steps (N18, N21, N34-N36); the first lines are the to-dos' own.
const POWER_STEPS := [{"id": "switch", "text": "Get payroll's lights and the cage lock back on"}, {"id": "readback", "text": "Read the panel back"}]
const AIR_STEPS := [{"id": "order", "text": "Get the air moving again"}, {"id": "readback", "text": "Read our work order back"}]
const PEOPLE_STEPS := [{"id": "passes", "text": "Get both night-shifters out on an escort pass"}, {"id": "lockup", "text": "Lock every door opened tonight"}, {"id": "readback", "text": "Read the doors back"}]
## The pieces (N8, N10, N19, N22, N23, N37, N39). The key's value is this run's.
const BADGE_PIECE := {"id": "badge", "label": "Our visitor badge", "task": "Find the number on one of our visitor badges", "where": "The visitor pass list at the HR desk", "blank": "enter_badge"}
const OUR_BADGE_PIECE := {"id": "our_badge", "label": "Our visitor badge", "task": "Find the number on one of our visitor badges", "where": "The visitor pass list at the HR desk", "blank": "enter_our_badge"}
const CIRCUIT_PIECE := {"id": "circuit", "label": "A circuit Epsilon shed", "value": "C9-01", "task": "Find the id of a circuit that was shed", "where": "The Facilities clipboard", "blank": "enter_circuit_id"}
const UNIT_PIECE := {"id": "unit", "label": "This floor's air handler", "value": "AHU-9", "task": "Find the unit that moves this floor's air", "where": "The tag on payroll's air grille", "blank": "enter_unit"}
const FLOOR_PIECE := {"id": "floor", "label": "This floor", "value": "9", "task": "Find the number of the floor we're on", "where": "The tag on payroll's air grille", "blank": "enter_floor"}
const VALE_PIECE := {"id": "vale_badge", "label": "Vale's badge", "value": "ST-0077", "task": "Find Iris Vale's badge number", "where": "The HR service's staff list", "blank": "enter_badge"}
## The slots and the pencil's notes when a click isn't it (N11-N14, N27-N30, N40-N43).
const FRAME_SLOT := "Swiped into Vale's lab at:"
const FRAME_ROW := "That's the lab swipe. The blank wants its time."
const FRAME_READER := "That's a swipe at another reader. The blank wants the one at LAB-B, Vale's lab."
const FRAME_MISS := "Not that one: the blank wants when our badges were swiped into Vale's lab."
const RADIO_SLOT := "Where the voice's badge really is:"
const RADIO_OLDER := "That's an older swipe. The blank wants that badge's newest one."
const RADIO_OWN := "That's your own badge. The voice said it had the next one in the book."
const RADIO_MISS := "Not that one: the blank wants what the log says about the voice's badge."
const VALE_SLOT := "Last edited by:"
const VALE_WHEN := "That's when it was edited. The blank wants who by."
const VALE_ROW := "That's Vale's record. The blank wants who edited it last."
const VALE_MISS := "Not that one: the blank wants who last edited Vale's record."
## `.hint`'s first tiers, each skipped once its paper is read (N9, N15, N20, N24, N38).
const SPOT_DESK_SHEET := "the request sheet on the HR desk says how to ask the HR service."
const SPOT_POSTER := "the badge poster on HR's wall says how to read a badge's log."
const SPOT_CLIPBOARD := "the Facilities clipboard beside PANEL 9 lists every circuit, and how to switch one."
const SPOT_CARBON := "the carbon copy pinned over PANEL 9 is a work order like the one you need."
const SPOT_PROCEDURE := "the after-hours procedure is pinned on the wall behind the HR desk."
## The new papers (N45-N50) and their notebook lines.
const PASS_LIST_HEAD := [
	"HALCYON SECURITY  -  VISITOR PASSES  -  10/15",
	"Issued at the front desk, ground floor. Copy to Personnel.",
	{"columns": ["BADGE", "NAME", "COMPANY", "IN", "ESCORT"], "widths": [0.7, 0.9, 1.9, 0.5, 0.9]},
]
const PASS_LIST_TAIL := ["Visitors are escorted at all times."]
const PASS_LIST_NOTE := "Visitor passes issued tonight: %s."
const NOTICE_LINES := [
	"SECURITY NOTICE",
	"Reader access revoked for these badges:",
	"ST-0416   reported lost 10/13",
	"ST-0590   not returned 09/30",
	"Found one? Hand it in at the HR desk.",
	"                            - Personnel",
]
const NOTICE_NOTE := "Reader access revoked for two badges: ST-0416, lost 10/13, and ST-0590, never returned."
const PLATE_LINES := ["COPIER BANK", "Panel 9, circuit C9-03: %d A with all three running."]
const GRILLE_TAG_LINES := ["AHU-9", "FLOOR 9 SUPPLY"]
## SYSOP's two air tips (N25, N26).
const TIP_FLOOR := "that order went in, but for floor %d. AHU-9 is this floor's, and this is floor 9."
const TIP_NO_UNIT := "that order went in for %s, and no unit by that name answered. the clipboard spells this floor's unit AHU-9."

## The laminated desk sheet at the HR front desk: where the header is found. Its
## example asks for the HR manager's own record, with a blank where the key goes.
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
const CASES := {"hr_key": TEXT.case_key, "panel_power": TEXT.case_power, "air": TEXT.case_air, "radio": TEXT.case_radio,
	"frame": TEXT.case_frame, "people": TEXT.case_people, "vale": TEXT.case_vale}
## The clock on the HR front wall reads 00:MM when the crew arrives (seeded) and runs.
## The stairs down hold this long before the end card, or the walkie's last line if longer.
const EXIT_HOLD := 2.5
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
## How the air goes: from the crew's first request after the air case opens (once
## the power is back), a grace long enough to type it at a lost player's pace
## (Teaching's walk: about four minutes), then a little each tick until it's back.
const AIR_GRACE := 300.0
const AIR_TICK := 15.0
const AIR_DAMAGE := 3.0
## The stair door propped: how long until the air clears on its own.
const PROP_TIME := 90.0
## The breaker cupboard's hand reset: how long it takes, in the dark.
const HAND_RESET_TIME := 20.0
## When the radio lies: this long after the air comes back on (or after it clears
## through the propped stair door: M6), then once more if nobody has looked.
const LURE_DELAY := 40.0
const LURE_DELAY_PROPPED := 15.0
const LURE_AGAIN := 50.0
## Not sealed on 10, the Custodian comes up the dock stairs this long after the people
## case opens (M8: the practice is safe; the passes and the lockup aren't), sooner
## once the crew logs a pass or opens a hiding door, or the moment the loading door
## is opened for the voice on the radio.
const CUSTODIAN_DELAY := 180.0

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
var power_back := false
var air_on := false
var air_cleared := false
## The air starts to count against the crew at their first request after its case
## opens (M4) (host: the seconds counted so far, and the ticks dealt).
var air_armed := false
var _air_time := 0.0
var _air_ticks := 0
var custodian_timed := false
## The radio's first line is on its way (host; once a run).
var lure_timed := false
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
## How long the stairs down hold before the end card: the walkie's last line, at least.
var exit_hold := 0.0
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
## The frame's station (M1): read our badges' log, and point at the lab swipe's time.
var frame_puzzle: RequestPuzzle
## A find's answer is on a screen now (for the teaching walk: a first-time player
## who sees it there points at it).
var frame_listed := false
var radio_listed := false
var vale_listed := false
## Circuits the crew has changed (the power's read-back takes any of them shown in
## its new state), and the terminal anyone last typed at (tip_lure prints there).
var changed_circuits := {}
var last_which := "hr"
## The HR service has answered once (200): the key's done, and the frame's to-do is back.
var hr_answered := false


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
	stair_in = Stairwell.build(self, geo, STAIR_IN_AT, -90.0, "9", "STAIR 1", 1)  # up from G, nothing under it
	stair_in.name = "Door_STAIR-IN"  # the crew opens it once they're all up (start())
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
		# No escort on file: the security policy (P1, P7-P9). Both reach every
		# service, so `.hint` follows the case, not the terminal (_hint_station).
		term.policy = true
		term.hint_station = _hint_station
	_set_cases()
	Game.answer_found.connect(_on_answer_found)
	Game.cell_missed.connect(_on_cell_missed)


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
	key_puzzle.case_id = "hr_key"
	key_puzzle.spots = [{"id": "desk_sheet", "text": SPOT_DESK_SHEET}]
	# The frame (M1): our own badges' log, practised safely before the radio needs it.
	# Answered by pointing at the lab swipe's time (_cell_counts); the review ladder.
	frame_puzzle = RequestPuzzle.new("frame", "GET /swipes/VIS-01\n%s" % hr_key, func(_line: String, _res: Dictionary) -> bool:
		return false, [])
	frame_puzzle.case_id = "frame"
	frame_puzzle.spots = [{"id": "badge_poster", "text": SPOT_POSTER}]
	_frame_hints()
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
	circuits_puzzle.case_id = "panel_power"
	circuits_puzzle.spots = [{"id": "clipboard", "text": SPOT_CLIPBOARD}]
	# Verify after the change: GET is long practised (floor 22), so the review ladder.
	# Any circuit the crew changed, shown in its new state, reads it back.
	check_circuits_puzzle = RequestPuzzle.new("check_circuits", "GET /circuits\n%s" % hr_key, func(line: String, res: Dictionary) -> bool:
		return res.status == 200 and _method_of(line) == "GET" and _path_of(line).begins_with("/circuits") and power_back and _shows_changed(res.body), [
		"the shape: ask the panel back, with the service left as enter_service:\n" +
		"    [color=#ffffff]GET /enter_service\nX-Api-Key: %s[/color]\n" % key +
		"enter_service is the service you just changed.",
		"type this, then Enter twice:\n" +
		"    [color=#ffffff]GET /circuits\n%s[/color]" % hr_key,
	])
	check_circuits_puzzle.case_id = "panel_power"
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
	air_puzzle.spots = [{"id": "carbon_copy", "text": SPOT_CARBON}]
	check_air_puzzle = RequestPuzzle.new("check_air", "GET /work_orders\n%s" % hr_key, func(line: String, res: Dictionary) -> bool:
		return res.status == 200 and _method_of(line) == "GET" and _path_of(line).begins_with("/work_orders") and _air_ok() and _shows_order(res.body), [
		"the shape: ask for it back, with the service left as enter_service:\n" +
		"    [color=#ffffff]GET /enter_service\nX-Api-Key: %s[/color]\n" % key +
		"enter_service is the service you just posted to.",
		"type this, then Enter twice:\n" +
		"    [color=#ffffff]GET /work_orders\n%s[/color]\n" % hr_key +
		"the 201 came with the order's number: GET /work_orders/enter_order_id asks for just that one.",
	])
	check_air_puzzle.case_id = "air"
	# The radio's claim against the readers' log: GET with an id in the path is
	# practised (floor 22's /doors/SEC-EXIT), so the review ladder.
	# Answered by pointing at what the log says about the voice's badge (_cell_counts).
	swipes_puzzle = RequestPuzzle.new("swipes", "GET /swipes/enter_badge\n%s" % hr_key, func(_line: String, _res: Dictionary) -> bool:
		return false, [
		"the shape, with the badge left as enter_badge:\n" +
		"    [color=#ffffff]GET /swipes/enter_badge\nX-Api-Key: %s[/color]\n" % key +
		"enter_badge is the badge of whoever's talking. the visitor pass list at the HR desk says whose is whose. the readers log where every badge really is: the voice says it's at the loading door; the log says where that badge is.",
		"",  # the exact query is built once the voice has spoken (_lure_hints)
	])
	swipes_puzzle.case_id = "radio"
	swipes_puzzle.spots = [{"id": "badge_poster", "text": SPOT_POSTER}]
	swipes_puzzle.solved = true  # until the radio lies
	# The escort passes: both night-shifters passed and out (their doors opened). POST
	# is practised at the air handler, so the review ladder, unless the prop route
	# skipped the work order (_passes_hints).
	passes_puzzle = RequestPuzzle.new("passes", "POST /escorts\n%s\n\n{\"badge\": \"enter_badge\", \"escort\": \"VIS-01\"}" % hr_key, func(_line: String, _res: Dictionary) -> bool:
		return _passes_ok(), [], _passes_ok)
	passes_puzzle.case_id = "people"
	passes_puzzle.spots = [{"id": "procedure", "text": SPOT_PROCEDURE}]
	_passes_hints()
	# The lockup: PATCH is practised at the panel, so the review ladder; its last tier
	# lists the doors still open (_lockup_hints).
	lockup_puzzle = RequestPuzzle.new("lockup", "PATCH /doors/enter_door\n%s\n\n{\"locked\": true}" % hr_key, func(line: String, res: Dictionary) -> bool:
		return res.status == 200 and _path_of(line).begins_with("/doors") and _lockup_ok(), [], _lockup_ok)
	lockup_puzzle.case_id = "people"
	_lockup_hints()
	check_lockup_puzzle = RequestPuzzle.new("check_lockup", "GET /doors\n%s" % hr_key, func(line: String, res: Dictionary) -> bool:
		return res.status == 200 and _method_of(line) == "GET" and _path_of(line).begins_with("/doors") and _shows_locked(res.body) and _lockup_ok(), [
		"the shape: read the doors back, with the service left as enter_service:\n" +
		"    [color=#ffffff]GET /enter_service\nX-Api-Key: %s[/color]\n" % key +
		"enter_service is the service whose doors you just locked.",
		"type this, then Enter twice:\n" +
		"    [color=#ffffff]GET /doors\n%s[/color]\n" % hr_key +
		"GET /doors/enter_door reads one back.",
	])
	check_lockup_puzzle.case_id = "people"
	# Answered by pointing at who last edited her record (_cell_counts).
	vale_puzzle = RequestPuzzle.new("vale", "GET /staff/%s\n%s" % [Level5Data.VALE.id, hr_key], func(_line: String, _res: Dictionary) -> bool:
		return false, [
		"the shape, with the badge left as enter_badge:\n" +
		"    [color=#ffffff]GET /staff/enter_badge\nX-Api-Key: %s[/color]\n" % key +
		"enter_badge is her badge number: GET /staff lists every record, with its id.",
		"type this, then Enter twice:\n" +
		"    [color=#ffffff]GET /staff/%s\n%s[/color]\n" % [Level5Data.VALE.id, hr_key] +
		"point at who last edited it and add it to your notebook.",
	])
	vale_puzzle.case_id = "vale"


## A spot on a stairwell's landing, clear of the flight, facing its door.
func _stair_landing(at: Vector3, yaw_deg: float) -> Transform3D:
	var holder := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg + 180.0)), holder * Vector3(-0.8, 0.1, -1.3))


func player_spawn(index: int) -> Transform3D:
	# Six people fit on the landing, two abreast beside the flight up, clear of the door.
	var slot := Stairwell.landing_slot(STAIR_IN_AT, -90.0, index)
	return global_transform * Transform3D(spawn.basis, slot)


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
	# The desk sheet's example asks for the manager's own record: copied with the
	# key, it answers 200 with hers.
	var lines := DESK_SHEET_LINES.duplicate(true)
	lines[3] = {"text": "GET /staff/%s" % data.manager.id, "hand": false}
	var sheet := Document.place(geo, Vector3(0.7, 1.0, -1.5), 0, "Personnel request sheet", lines, true, "laminated", Vector2(0.24, 0.3))
	sheet.clues = [{"case": "hr_key", "text": "The desk sheet: every HR request carries the HR key in an X-Api-Key header, on its own line. The manager issues keys."}]
	sheet.spot = "desk_sheet"
	sheet.read_by.connect(func(_p): sync.event("_ask", ["hr_key"]))
	# The policy card (P5) beside the terminal: floor 9's first policy terminal.
	TerminalPolicy.place_card(geo, Vector3(-1.32, 1.002, -1.42), 0, true)
	# The in-tray at the desk's end, for the visitor pass list (seed_crew: it lists
	# the crew, so it's printed once everyone's here).
	Greybox.box(geo, Vector3(1.3, 1.025, -1.62), Vector3(0.36, 0.05, 0.28), Color(0.2, 0.22, 0.3), "InTray")
	# The after-hours procedure, pinned on the wall behind the desk. Read early, its
	# line waits in Floor notes until the people case opens (M7).
	var proc := Document.place(geo, Vector3(-1.5, 1.7, -7.88), 180, "Escort procedure", PROCEDURE_LINES, false, "laminated", Vector2(0.3, 0.36))
	proc.clues = [{"case": "people", "text": "The after-hours procedure: staff leave only on an escort pass (POST /escorts, logged for a badge the readers have on the floor). Night lockup: every door opened is locked again and read back."}]
	proc.spot = "procedure"
	# The badge poster on the east wall.
	var poster := Document.place(geo, Vector3(9.88, 1.8, -3), 90, "Badge poster", POSTER_LINES, false, "paper", Vector2(0.42, 0.56))
	poster.clues = [{"case": "radio", "text": "The poster: every reader logs every swipe. GET /swipes/<badge> is a badge's log."}]
	poster.spot = "badge_poster"
	# The security notice beside the reader at HR's door (N47).
	var notice := Document.place(geo, Vector3(2.75, 1.45, 3.88), 0, "Security notice", NOTICE_LINES, false, "paper", Vector2(0.21, 0.28))
	notice.name = "SecurityNotice"
	notice.clues = [{"case": "people", "text": NOTICE_NOTE}]
	# The training shelf by the west wall, with the book on it.
	Greybox.box(geo, Vector3(-9.3, 0.9, 0.5), Vector3(1.2, 1.8, 0.4), Color(0.36, 0.3, 0.26), "TrainingShelf")
	Greybox.label(geo, Vector3(-9.2, 1.95, 0.5), "TRAINING", 24, Color(0.85, 0.85, 0.8), 90)
	for i in 5:
		Greybox.box(geo, Vector3(-9.3, 1.0, 0.32 + i * 0.09), Vector3(0.9, 0.05, 0.07), Color(0.3 + i * 0.1, 0.35, 0.5 - i * 0.05), "Binder")
	book = Interactable.create(self, Vector3(-9.3, 1.1, 0.72), Vector3(0.6, 0.05, 0.2), "Pick up: Acceptable API's", Color(0.9, 0.5, 0.1))
	book.name = "Book"
	book.used.connect(func(p): sync.event("_book_found", [players.id_of(p)]))
	# The clock on the wall over the desk: the floor's time when the crew arrives.
	Greybox.label(geo, Vector3(0, 2.6, -7.88), data.clock, 48, Color(1.0, 0.25, 0.15), 0).name = "Clock"
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
	sticky.clues = [{"case": "hr_key", "text": "Under the HR manager's keyboard: HR svc key: %s" % data.keys.hr}]
	# Every case on the floor asks with the key (N8).
	sticky.pieces = KEY_CASES.map(func(c): return {"case": c, "piece": "key", "text": data.keys.hr, "kind": "value"})
	# The mail tray with the temp's key card: a real key for the wrong service.
	Greybox.box(geo, Vector3(8.0, 1.03, -14.5), Vector3(0.5, 0.06, 0.35), Color(0.2, 0.22, 0.3), "MailTray")
	var card_lines := TEMP_CARD_LINES.duplicate()
	card_lines[2] = TEMP_CARD_LINES[2] % data.keys.temp
	var card := Document.place(geo, Vector3(8.0, 1.07, -14.5), 0, "Temp key card", card_lines, true, "laminated", Vector2(0.2, 0.14))
	card.clues = [{"case": "hr_key", "text": "In the mail tray: the temp's mail-room key, %s. Not for HR records." % data.keys.temp}]
	# A filing cabinet and a framed certificate.
	Greybox.box(geo, Vector3(9.5, 0.7, -10), Vector3(0.6, 1.4, 0.5), Color(0.45, 0.47, 0.5), "Cabinet")


func _build_cage(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(-6, 0, -12), Vector3(8, 3.0, 8), {"floor": Color(0.26, 0.26, 0.28), "wall": colors.wall.darkened(0.15)}, [
		{"wall": "s", "at": 0.0, "width": 1.6, "height": 2.3},
	])
	Greybox.label(geo, Vector3(CAGE_DOOR_AT.x, 2.6, -7.88), "RECORDS CAGE", 32, Color(0.8, 0.8, 0.72), 0)
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
	Greybox.label(geo, Vector3(1, 2.7, -7.88), "PAYROLL  >", 32, Color(0.8, 0.8, 0.72), 0)
	# The readers by each doorway: a grey box with a slot.
	Greybox.box(geo, Vector3(2.0, 1.3, 3.9), Vector3(0.1, 0.16, 0.1), Color(0.3, 0.3, 0.32), "ReaderFront")
	Greybox.box(geo, Vector3(2.9, 1.3, -15.9), Vector3(0.1, 0.16, 0.1), Color(0.3, 0.3, 0.32), "ReaderPay")


func _build_payroll(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(0, 0, -22), Vector3(20, 3.2, 12), {"floor": Color(0.3, 0.28, 0.26), "wall": colors.wall}, [
		{"wall": "s", "at": 1.0, "width": 2.4, "height": 2.4},
		{"wall": "n", "at": STORE_DOOR_AT.x, "width": 1.2, "height": 2.3},
		{"wall": "n", "at": DOCK_DOOR_AT.x, "width": 1.6, "height": 2.5},
	])
	Greybox.label(geo, Vector3(1, 2.8, -16.12), "PAYROLL", 48, Color(0.8, 0.8, 0.72), 180)
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
	# One plate on the bank: the three share a circuit (N49).
	var plate_lines := PLATE_LINES.duplicate()
	plate_lines[1] = PLATE_LINES[1] % int(circuits["C9-03"].amps)
	Document.place(geo, Vector3(-8.735, 1.0, -20.0), -90, "Copier bank plate", plate_lines, false, "laminated", Vector2(0.22, 0.1)).name = "CopierPlate"
	# The vending machines on the east wall, and the breaker cupboard behind them.
	for z in [-18.2, -19.6]:
		Greybox.box(geo, Vector3(9.2, 0.95, z), Vector3(0.9, 1.9, 1.2), Color(0.25, 0.3, 0.5), "Vending")
	cupboard = Interactable.create(self, Vector3(9.4, 1.0, -21.0), Vector3(0.5, 0.8, 0.5), "Reset the lights breaker by hand", Color(0.4, 0.4, 0.42))
	cupboard.name = "BreakerCupboard"
	cupboard.used.connect(func(p): sync.event("_hand_reset_started", [players.id_of(p)]))
	Document.place(geo, Vector3(9.88, 1.7, -21.0), 90, "Cupboard sign", CUPBOARD_LINES, false, "laminated", Vector2(0.22, 0.16))
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
	# The clipboard opens the power case (or the frame's solve does: M3). Its air
	# line waits in Floor notes until the power's back (M4).
	var board := Document.place(geo, Vector3(6.8, 1.0, -26.5), 0, "Facilities clipboard", _clipboard_lines(), true, "clipboard")
	board.clues = [{"case": "panel_power", "text": "Panel 9 carries %d A at night. Shed circuits come back through the service, one at a time: PATCH /circuits/<id> with {\"on\": true}. The copier bank is still on." % data.limit},
		{"case": "air", "text": "The clipboard: %s restarts on a logged work order (night interlock)." % data.ahu}]
	board.pieces = [{"case": "panel_power", "piece": "circuit", "text": "C9-01", "kind": "value"}, {"case": "panel_power", "piece": "circuit", "text": "C9-04", "kind": "value"},
		{"case": "air", "piece": "unit", "text": "Air: AHU-9", "kind": "value"}]
	board.spot = "clipboard"
	board.read_by.connect(func(_p): sync.event("_ask", ["panel_power"]))
	var carbon := CARBON_LINES.duplicate()
	carbon[5] = CARBON_LINES[5] % [data.example_order.floor, data.example_order.unit, data.example_order.fault]
	var copy := Document.place(geo, Vector3(3.2, 1.7, -27.88), 180, "Carbon copy", carbon, false, "paper", Vector2(0.21, 0.28))
	copy.clues = [{"case": "air", "text": "A carbon copy of floor 14's work order: POST /work_orders with a body of floor, unit and fault. 201 Created, then GET it back."}]
	copy.spot = "carbon_copy"
	# The air handler's grille in the ceiling over the facilities desk, still, with
	# its tag hung low enough to read (N50).
	Greybox.box(geo, Vector3(4.6, 3.1, -27.2), Vector3(1.2, 0.1, 0.6), Color(0.55, 0.55, 0.52), "AirGrille")
	var tag := Document.place(geo, Vector3(4.6, 2.5, -27.2), 180, "Grille tag", GRILLE_TAG_LINES, false, "laminated", Vector2(0.16, 0.1))
	tag.name = "GrilleTag"
	tag.pieces = [{"case": "air", "piece": "unit", "text": "AHU-9", "kind": "value"}, {"case": "air", "piece": "floor", "text": "FLOOR 9", "kind": "value"}]


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
	Greybox.label(geo, Vector3(6, 2.2, -33.88), "DOCK STAIRS", 28, Color(0.5, 0.1, 0.1), 0)
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
	Game.cell_rule = _cell_counts  # this floor's slots, from here on (a wing built ahead keeps its own until then)
	stair_in.locked = false  # the crew's all up: out of the stairwell, onto 9
	hr.ensure_booted()
	panel.ensure_booted()
	_radio_voice = Voice.new()
	_radio_voice.name = "RadioVoice"
	add_child(_radio_voice)
	seed_crew(players.count() if players else 1)
	if completed.get_connections().is_empty():
		completed.connect(_on_completed)
	# The frame is why the crew climbed to 9: its case is open from the start (M1).
	_open("frame")
	_todo("todo_arrive")
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
	_frame_hints()
	_pass_list()
	_frame_step()


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


# --- The cases: pieces, steps, slots (the v0.10 package) --------------------------------

## The HR key, as every case's piece (N8).
func _key_piece() -> Dictionary:
	return {"id": "key", "label": "The HR key", "value": data.keys.hr, "task": "Find the key the HR service answers to", "where": "The HR manager's office", "blank": "enter_key"}


func _badge_piece(base: Dictionary) -> Dictionary:
	var p := base.duplicate()
	p["value"] = _my_badge()
	return p


## A night-shifter's badge (N37): either fills it.
func _night_piece() -> Dictionary:
	return {"id": "their_badge", "label": "A night-shifter's badge", "value": data.night[0].id, "task": "Find a badge on tonight's night shift", "where": "The HR service's staff list", "blank": "enter_badge"}


## Every machine: each case's pieces and its query for the step it's on.
func _set_cases() -> void:
	Game.set_pieces("hr_key", [_key_piece()], KEY_QUERY)
	Game.set_pieces("frame", [_badge_piece(BADGE_PIECE), _key_piece()], FRAME_QUERY)
	_power_step("switch")
	_air_step("order")
	Game.set_pieces("radio", [_key_piece()], RADIO_QUERY)
	_people_step("passes")
	Game.set_assemble("people", false)  # under pressure: the bare shape, the pieces on the page
	Game.set_pieces("vale", [VALE_PIECE, _key_piece()], VALE_QUERY, [], true)  # a side case: it never takes the page


func _power_step(step: String) -> void:
	match step:
		"switch":
			Game.set_pieces("panel_power", [CIRCUIT_PIECE, _key_piece()], POWER_QUERY, POWER_STEPS)
		"readback":
			Game.tick_step("panel_power", "switch")
			Game.set_pieces("panel_power", [CIRCUIT_PIECE, _key_piece()], POWER_READ_QUERY, POWER_STEPS)


func _air_step(step: String) -> void:
	match step:
		"order":
			Game.set_pieces("air", [FLOOR_PIECE, UNIT_PIECE, _key_piece()], AIR_QUERY, AIR_STEPS)
		"readback":
			Game.tick_step("air", "order")
			Game.set_pieces("air", [FLOOR_PIECE, UNIT_PIECE, _key_piece()], AIR_READ_QUERY, AIR_STEPS)


func _people_step(step: String) -> void:
	var pieces := [_night_piece(), _badge_piece(OUR_BADGE_PIECE), _key_piece()]
	match step:
		"passes":
			Game.set_pieces("people", pieces, PASS_QUERY, PEOPLE_STEPS)
		"lockup":
			Game.tick_step("people", "passes")
			Game.set_pieces("people", pieces, LOCK_QUERY, PEOPLE_STEPS)
		"readback":
			Game.tick_step("people", "passes")
			Game.tick_step("people", "lockup")
			Game.set_pieces("people", pieces, DOORS_READ_QUERY, PEOPLE_STEPS)


## Every machine: the frame's slot (N11), the time of a LAB-B swipe of our badges.
func _frame_step() -> void:
	var times := swipes.filter(func(w): return issued.has(w.badge) and w.reader == "LAB-B").map(func(w): return w.time)
	if times.is_empty() or Game.case_info("frame").get("solved", false):
		return
	Game.set_blank("frame", FRAME_SLOT, NO_LINE, times[0], {"column": "time", "values": times, "rows": [{"reader": "LAB-B"}]})


## Every machine: the radio's slot (N27). Co-op: the reader on the voice's badge's
## newest swipe; solo: the log's word that no such badge was issued.
func _radio_step() -> void:
	if lure_peer > 0:
		var readers := {}
		for w in swipes:
			readers[w.reader] = true
		for r in ["PERS-FRONT", "PERS-PAY"]:
			readers[r] = true
		var newest := _last_swipe(lure_badge)
		Game.set_blank("radio", RADIO_SLOT, NO_LINE, str(newest.get("reader", "")), {"column": "reader", "values": readers.keys()})
	else:
		Game.set_blank("radio", RADIO_SLOT, NO_LINE, _no_badge(lure_badge), {"column": "error", "values": [_no_badge(lure_badge)]})


static func _no_badge(badge: String) -> String:
	return "No visitor badge %s was issued tonight." % badge


## Every machine: Vale's slot (N40), who last edited her record.
func _vale_step() -> void:
	Game.set_blank("vale", VALE_SLOT, NO_LINE, Level5Data.VALE.edited_by, {"column": "edited_by", "values": [Level5Data.VALE.edited_by]})


## The visitor pass list in the HR desk's in-tray (N45): a row per crew member, as
## the badges were numbered on G, with each badge's lobby swipe. Every machine
## prints the same list, once everyone's here.
func _pass_list() -> void:
	if geo == null:
		return  # outside a floor (the stations alone, in tests)
	var old := geo.get_node_or_null("VisitorPasses")
	if old:
		old.free()
	var lines: Array = PASS_LIST_HEAD.duplicate(true)
	var names := []
	var noted := PackedStringArray()
	for i in issued.size():
		var badge: String = issued[i]
		var who := _crew_name(i)
		names.append(who)
		var lobby := swipes.filter(func(w): return w.badge == badge and w.reader == "G-LOBBY")
		lines.append({"row": [badge, who, data.company, str(lobby[0].time) if not lobby.is_empty() else "", "ROURKE, D."], "hand": false})
		noted.append("%s (%s)" % [badge, who])
	lines.append_array(PASS_LIST_TAIL)
	var list := Document.place(geo, Vector3(1.3, 1.052, -1.62), 0, "Visitor passes", lines, true, "paper", Vector2(0.21, 0.28))
	list.name = "VisitorPasses"
	list.clues = [{"case": "frame", "text": PASS_LIST_NOTE % ", ".join(noted)}]
	var pieces := []
	for badge in issued:
		pieces.append({"case": "frame", "piece": "badge", "text": badge, "kind": "value"})
		pieces.append({"case": "people", "piece": "our_badge", "text": badge, "kind": "value"})
	list.pieces = pieces


## The name of the crew member with visitor badge `i` + 1 (player order, as on G).
func _crew_name(i: int) -> String:
	var net := get_node_or_null("/root/Net")
	if players and net:
		for id in players.all_ids():
			if NetPlayers.index_of(id, multiplayer) == i:
				return net.display_name(id)
	return net.display_name(multiplayer.get_unique_id()) if net and i == 0 else "Visitor %d" % (i + 1)


## The frame's ladder (N16, N17): our own badge in the last tier's request.
func _frame_hints() -> void:
	if frame_puzzle == null:
		return
	var key: String = data.keys.hr
	frame_puzzle.hints = [
		"the shape, with our badge left as enter_badge:\n" +
		"    [color=#ffffff]GET /swipes/enter_badge\nX-Api-Key: %s[/color]\n" % key +
		"enter_badge is one of our visitor badges. the visitor pass list at the HR desk says whose is whose.",
		"type this, then Enter twice:\n" +
		"    [color=#ffffff]GET /swipes/%s\nX-Api-Key: %s[/color]\n" % [_my_badge(), key] +
		"find the swipe at LAB-B, Vale's lab. point at its time and add it to your notebook.",
	]


## `.hint` follows the case (no new words): while the HR service hasn't answered,
## the key's ladder; else the selected case's first unsolved station, from either
## terminal's list; else the first unsolved station whose case is open; else none.
func _hint_station() -> Puzzle:
	if not key_puzzle.solved:
		return key_puzzle
	var stations := [frame_puzzle, circuits_puzzle, check_circuits_puzzle, air_puzzle, check_air_puzzle, swipes_puzzle, passes_puzzle, lockup_puzzle, check_lockup_puzzle, vale_puzzle]
	var open := stations.filter(func(p): return not p.solved and Game.case_info(p.case_id).get("open", false) and not Game.case_info(p.case_id).get("solved", false))
	var picked: String = Game.case_selected()
	for p in open:
		if p.case_id == picked:
			return p
	return open[0] if not open.is_empty() else null


# --- Pointing at the answer ------------------------------------------------------------------

## Game.cell_rule: a cell that matches a floor 9 slot counts only if it's this one's.
## The frame's, in a swipe of one of our badges; the radio's (co-op), on the voice's
## badge's newest swipe; Vale's, in her record.
func _cell_counts(case_id: String, f: Dictionary) -> bool:
	var row: Dictionary = f.row
	match case_id:
		"frame":
			return issued.has(str(row.get("badge", "")).to_upper())
		"radio":
			if lure_peer <= 0:
				return true
			var newest := _last_swipe(lure_badge)
			return str(row.get("badge", "")).to_upper() == lure_badge and str(row.get("time", "")) == str(newest.get("time", "")) and str(f.value).to_upper() == str(newest.get("reader", ""))
		"vale":
			return not row.has("id") or str(row.id).to_upper() == Level5Data.VALE.id
	return true


## This player's click filled a slot: the host hears whose it was.
func _on_answer_found(id: String) -> void:
	match id:
		"frame":
			sync.report_answer("frame@" + str(Game.case_info("frame").get("blank", {}).get("value", "")))
		"radio", "vale":
			sync.report_answer(id)


## Every machine: a crewmate's answer goes in everyone's slot (the frame's with the
## time they pointed at).
func _crew_answered(id: String, peer: int) -> void:
	var case_id := id.get_slice("@", 0)
	if id.contains("@"):
		var b: Dictionary = Game.case_info(case_id).get("blank", {})
		if not b.is_empty() and str(b.get("filled", "")) == "":
			b.value = id.get_slice("@", 1)
	super._crew_answered(case_id, peer)


## Host: a player put a find's answer in its slot.
func case_answered(answer: String, peer: int) -> void:
	var case_id := answer.get_slice("@", 0)
	match case_id:
		"frame":
			if not frame_puzzle.solved:
				# achievement:framed goes to whoever's click it was (Augustine 2026-10-21).
				sync.unlock_for([peer], "achievement:framed")
				sync.event("_frame_solved", [answer.get_slice("@", 1)])
		"radio":
			if lures > 0 and not swipes_puzzle.solved:
				sync.event("_on_solved", ["swipes"])
		"vale":
			if not vale_puzzle.solved:
				sync.event("_on_solved", ["vale"])


## This player pointed at a cell that answers no slot: if it's in the answer a slot
## is about, a pencil line under the blank says why (this player's notebook only).
func _on_cell_missed(column: String, _value: String, row: Dictionary) -> void:
	var col := column.to_lower()
	var badge := str(row.get("badge", "")).to_upper()
	var swipe := row.has("reader")
	var record := row.has("edited_by") or row.has("last_edited") or str(row.get("id", "")).to_upper() == Level5Data.VALE.id
	var home := Game.case_selected()
	if swipe:
		home = "radio" if _open_unsolved("radio") and lures > 0 else "frame"
	elif record:
		home = "vale"
	elif col == "error" and _open_unsolved("radio"):
		home = "radio"
	match home:
		"frame":
			if not _open_unsolved("frame"):
				return
			var note := FRAME_MISS
			if swipe and issued.has(badge) and str(row.reader) == "LAB-B" and col != "time":
				note = FRAME_ROW
			elif swipe and col == "time" and str(row.reader) != "LAB-B":
				note = FRAME_READER
			Game.blank_miss("frame", note)
		"radio":
			if not _open_unsolved("radio") or lures == 0:
				return
			var note := RADIO_MISS
			if lure_peer > 0 and swipe and badge == lure_badge:
				note = RADIO_OLDER
			elif lure_peer <= 0 and issued.has(badge):
				note = RADIO_OWN
			Game.blank_miss("radio", note)
		"vale":
			if not _open_unsolved("vale"):
				return
			var note := VALE_MISS
			if record and col == "last_edited":
				note = VALE_WHEN
			elif record and str(row.get("id", Level5Data.VALE.id)).to_upper() == Level5Data.VALE.id:
				note = VALE_ROW
			Game.blank_miss("vale", note)


func _open_unsolved(id: String) -> bool:
	var c: Dictionary = Game.case_info(id)
	return c.get("open", false) and not c.get("solved", false)


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


## The answer shows this floor's order: AHU-9, on floor 9 (an order for another
## floor's number never reads back as ours: N25).
func _shows_order(body: Variant) -> bool:
	if not body is Dictionary:
		return false
	var ours := func(o: Variant) -> bool:
		return o is Dictionary and str(o.get("unit", "")) == data.ahu and int(o.get("floor", 0)) == 9
	if ours.call(body):
		return true
	for o in body.get("work_orders", []):
		if ours.call(o):
			return true
	return false


## The answer shows a circuit the crew changed, in the state it's in now (C9-01 or
## C9-04 on, C9-03 off): the power case's read-back (M5).
func _shows_changed(body: Variant) -> bool:
	if not body is Dictionary:
		return false
	var list: Array = body.get("circuits", [body])
	for c in list:
		if not c is Dictionary:
			continue
		var id := str(c.get("id", ""))
		if not changed_circuits.has(id) or not circuits.has(id) or not c.has("on"):
			continue
		var now: bool = circuits[id].on
		if bool(c.on) == now and {"C9-01": true, "C9-04": true, "C9-03": false}.get(id, null) == now:
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
		("the voice said it was at the loading door. the log says where that badge really is: point at the reader on its newest swipe and add it to your notebook." if lure_peer > 0 else
		"the voice said it was at the loading door. the log says where that badge really is: point at what it says and add it to your notebook.")  # N32, N33


# --- Terminals --------------------------------------------------------------------------

func puzzles() -> Array:
	return [key_puzzle, circuits_puzzle, check_circuits_puzzle, air_puzzle, check_air_puzzle, swipes_puzzle, passes_puzzle, lockup_puzzle, check_lockup_puzzle, vale_puzzle]


## Host: a request went through at `which` terminal. Its station checks, and what
## it set off, play out on every machine.
func _on_request(line: String, res: Dictionary, _ui: TerminalUI, which: String) -> void:
	var path := _path_of(line).to_upper()
	var method := _method_of(line)
	var status := int(res.status)
	last_which = which
	var body: Dictionary = res.body if res.body is Dictionary else {}
	# The air's grace starts at the crew's first request after its case opens (M4).
	if not air_armed and Game.case_info("air").get("open", false) and not air_on and not air_cleared:
		sync.event("_air_armed")
	# Every station checks at either terminal (both reach every service): the key
	# passes on any 200, a GET /doors at the panel is the lockup's read-back too.
	for p in puzzles():
		if not p.solved and p.request_matches(line, res):
			sync.event("_on_solved", [p.id])
	# The key's case opens at the first 401, if the desk sheet hasn't opened it (M2).
	if status == 401 and not key_puzzle.solved and not Game.case_info("hr_key").get("open", false):
		sync.event("_ask", ["hr_key"])
	if status == 200 and (path == "/STAFF" or path.begins_with("/STAFF/")):
		sync.event("_staff_listed", [path == "/STAFF"])
	if status == 200 and path.begins_with("/SWIPES/VIS-") and issued.has(path.trim_prefix("/SWIPES/")):
		sync.event("_frame_seen", [path.trim_prefix("/SWIPES/")])
	if lures > 0 and _exposes_lure(line, res):
		sync.event("_radio_seen")
	if status == 200 and method == "PATCH" and path.begins_with("/CIRCUITS/"):
		sync.event("_circuits_changed", [path.trim_prefix("/CIRCUITS/")])
	if status == 200 and method == "PATCH" and path.begins_with("/DOORS/"):
		sync.event("_door_changed", [path.trim_prefix("/DOORS/"), bool(body.get("locked", true))])
	# Only an order for this floor's unit, on this floor, brings the air back.
	var order := status == 201 and path == "/WORK_ORDERS"
	var unit := str(body.get("unit", ""))
	var on_9 := order and int(body.get("floor", 0)) == 9
	if order and unit == data.ahu and on_9 and not air_on:
		sync.event("_air_on")
	if status == 201 and path == "/ESCORTS":
		sync.event("_passed", [str(body.get("badge", ""))])
	# SYSOP's tips, each once: text only, and never the answer. A 401 from the badge
	# reader (a pass for a badge that never swiped in) isn't a key problem; it's the
	# Mimic tip only when the badge is one off a Mimic's lanyard (Vale's gets no tip).
	var keyed := line.to_lower().contains(FacilityAPI.KEY_HEADER)
	var error := str(body.get("error", ""))
	var reader_401 := status == 401 and path == "/ESCORTS" and error.contains("did not answer the reader")
	_tip_if(status == 401 and not keyed, "header", which)
	_tip_if(status == 403, "temp", which)
	_tip_if(status == 401 and keyed and not reader_401, "wrong_key", which)
	_tip_if(status == 409 and path.begins_with("/CIRCUITS/") and error.contains("Turn something off"), "load", which)
	_tip_if(status == 404 and path.begins_with("/CIRCUITS/C14"), "example", which)
	_tip_if(order and unit == data.example_order.unit, "unit", which)
	_tip_if(order and unit == data.ahu and on_9, "verify", which)
	if order and unit == data.ahu and not on_9 and not tips_sent.has("floor"):
		sync.event("_tip", ["floor", which, str(int(body.get("floor", 0)))])  # N25
	if on_9 and unit != data.ahu and unit != data.example_order.unit and not tips_sent.has("no_unit"):
		sync.event("_tip", ["no_unit", which, unit])  # N26
	_tip_if(reader_401 and Level5Data.LOST.any(func(l): return error.contains(l.id)), "mimic", which)
	_tip_if(status == 409 and path == "/ESCORTS" and error.contains("off site"), "off_site", which)


## A SQL read at either terminal (the database is read-only; looking is free). The
## doors table read back counts as the lockup's read-back too, and the lights table
## showing payroll's light on reads the power back.
func _on_query(sql: String, result: Dictionary, _ui: TerminalUI, which: String) -> void:
	last_which = which
	if not result.get("ok", false):
		return
	var rows: Array = result.get("rows", [])
	if power_back and not check_circuits_puzzle.solved and rows.any(func(r): return str(r.get("id", "")) == "L9-PAY" and int(r.get("is_on", 0)) == 1):
		sync.event("_on_solved", ["check_circuits"])
	if not check_lockup_puzzle or check_lockup_puzzle.solved or lockup_puzzle == null:
		return
	# Read-backs count as they come, a door at a time, before the lockup is done.
	if sql.to_lower().contains("doors") and _shows_locked({"doors": rows.map(func(r): return {"id": str(r.get("id", "")), "locked": int(r.get("locked", 0)) == 1})}) and lockup_puzzle.solved:
		sync.event("_on_solved", ["check_lockup"])


func _tip_if(when: bool, id: String, which: String) -> void:
	if when and not tips_sent.has(id):
		sync.event("_tip", [id, which])


## Every machine: a line from SYSOP on the screen the request was typed at (once
## per tip). `arg` fills the two air tips' blanks (N25's floor, N26's unit).
func _tip(id: String, which: String, arg := "") -> void:
	if tips_sent.has(id):
		return
	tips_sent[id] = true
	var line: String
	match id:
		"floor":
			line = TIP_FLOOR % int(arg)
		"no_unit":
			line = TIP_NO_UNIT % arg
		_:
			line = TEXT["tip_" + id]
	_terminal(which).print_line(TerminalUI.sysop(line))


func _terminal(which: String) -> Terminal:
	return panel if which == "panel" else hr


## Every machine: a station's check passed.
func _on_solved(id: String) -> void:
	for p in puzzles():
		if p.id == id:
			p.solved = true
	match id:
		"key":
			hr_answered = true
			_open("hr_key")
			_solve("hr_key", TEXT.key_done, "api_codes")  # "Read the number": the first 200 (M9)
			if not frame_puzzle.solved:
				_todo("todo_arrive")  # the frame's to-do is back until it's solved (M1)
			elif not power_back:
				_todo("todo_power")
		"circuits":
			_power_step("readback")
		"check_circuits":
			_open("panel_power")
			Game.tick_step("panel_power", "switch")
			Game.tick_step("panel_power", "readback")
			_solve("panel_power", TEXT.power_done % data.limit)  # at its read-back (M5)
		"air":
			_air_step("readback")
		"check_air":
			_open("air")
			Game.tick_step("air", "order")
			Game.tick_step("air", "readback")
			var mine := orders.filter(func(o): return o.unit == data.ahu and int(o.floor) == 9)
			_solve("air", TEXT.air_done % (mine[0].id if not mine.is_empty() else "logged"))
		"swipes":
			_open("radio")
			if lure_peer > 0:
				_solve("radio", TEXT.radio_done % _name_of(lure_peer))
			else:
				_solve("radio", TEXT.radio_done_solo % lure_badge)
			_warden(["l5_radio_checked", "l5_radio_checked_tease"])
			_open_people()  # the radio's done: who on this floor is real? (M7)
			if _todo_is(TEXT.todo_radio):
				_todo(_next_todo())
		"passes":
			_people_step("lockup")
			if _lockup_ok():
				_on_solved("lockup")  # every door opened tonight is already locked again
			elif not lockup_puzzle.solved:
				_tip("lockup", "hr")
		"lockup":
			_people_step("readback")
		"check_lockup":
			_check_done()
		"vale":
			_open("vale")
			_solve("vale", TEXT.vale_done % Level5Data.VALE.edited_by)
	if id in ["passes", "lockup", "check_lockup"]:
		_check_done()


func _todo_is(text: String) -> bool:
	return Game.current_todo() == text


## What the notebook should say next, from what's left on the floor: the key, the
## frame, the power, the air, the people (once their case is open), the stairs; or nothing.
func _next_todo() -> String:
	if not key_puzzle.solved:
		return "todo_key" if Game.case_info("hr_key").get("open", false) else "todo_arrive"
	if not frame_puzzle.solved:
		return "todo_arrive"
	if not power_back:
		return "todo_power"
	if not (air_on or air_cleared):
		return "todo_air"
	if released:
		return "todo_down"
	if Game.case_info("people").get("open", false):
		return "todo_people"
	return ""


## Every machine: case `id` opens (once), with its chapter if it has one, and the
## crew's next waiting chapter lands (a gate: M9).
func _open(id: String) -> void:
	var chapter: String = {"hr_key": "api_keys", "panel_power": "api_patch", "air": "api_post", "people": "api_check"}.get(id, "")
	if Game.open_case(id, CASES[id]):
		_gate(chapter)


## Every machine: case `id` is solved, with what was found; a gate too (M9).
func _solve(id: String, how: String, chapter := "") -> void:
	if Game.case_info(id).get("solved", false):
		return
	Game.solve_case(id, how)
	_gate(chapter)


## Every machine: a paper or a 401 opened a case.
func _ask(case_id: String) -> void:
	_open(case_id)
	match case_id:
		"hr_key":
			if not key_puzzle.solved:
				_todo("todo_key")
		"panel_power":
			if key_puzzle.solved and not power_back:
				_todo("todo_power")


## Every machine: the people case opens once the radio is done (M7): the voice's
## badge read back, the loading door opened, or the voice's second line played.
## A pass logged opens it too.
func _open_people() -> void:
	if Game.case_info("people").get("open", false):
		return
	if passes_ladder == "":
		# POST practised at the work order: the review ladder. Skipped (the stair
		# door propped instead): ladder A, the word is new here.
		passes_ladder = "review" if _air_ok() else "a"
		_passes_hints()
	_open("people")
	if key_puzzle.solved and not released and not _todo_is(TEXT.todo_radio):
		_todo("todo_people")
	_custodian_clock()  # its 180 s start now (M8)


## Every machine: a staff record was shown (the list, or one). The list has Vale's
## row in it, so her case opens; a night-shifter's badge and hers are found (N37,
## N39), and her slot waits for who edited it.
func _staff_listed(whole: bool) -> void:
	if whole:
		_open("vale")
		_vale_step()
		Game.collect_piece("people", "their_badge", "The HR service's staff list")
		Game.collect_piece("vale", "vale_badge", "The HR service's staff list")
	vale_listed = vale_listed or Game.case_info("vale").get("open", false)


## Every machine: a crew badge's log was read: our badges were in Vale's lab. It's
## answered by pointing at the time (_cell_counts).
func _frame_seen(_badge: String) -> void:
	frame_listed = true


## Every machine: someone's click put the lab swipe's time in the frame's slot.
func _frame_solved(at: String) -> void:
	if frame_puzzle.solved:
		return
	frame_puzzle.solved = true
	_solve("frame", TEXT.frame_done % at)
	# The frame solved opens the power case (M3), unless the clipboard did already.
	_open("panel_power")
	if key_puzzle.solved and not power_back:
		_todo("todo_power")


## Every machine: the voice's badge's log is on a screen.
func _radio_seen() -> void:
	radio_listed = true


# --- The book -----------------------------------------------------------------------------

## Every machine: somebody took Acceptable API's off the training shelf. Its find
## and open lines, in their voice; then the earliest chapter waiting for it. The
## others land one at each gate after (M9).
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
	_gate()


## Every machine: a gate (a case opening or being solved). Its own chapter of
## Acceptable API's, if it has one, joins the wait; once the book is found, the
## earliest one waiting lands, quietly: nothing stops (Huddle). One per gate.
func _gate(chapter := "") -> void:
	if chapter != "" and not Huddle.of(self).done.has(chapter) and not pending_chapters.has(chapter):
		pending_chapters.append(chapter)
	if not book_found:
		return
	while not pending_chapters.is_empty() and Huddle.of(self).done.has(pending_chapters[0]):
		pending_chapters.pop_front()
	if not pending_chapters.is_empty():
		_book_huddle(pending_chapters.pop_front())


## Every machine: chapter `id` of Acceptable API's lands in the crew's book (once per run).
func _book_huddle(id: String) -> void:
	if Huddle.of(self).done.has(id):
		return
	await Huddle.of(self).run(id, Huddle.REMEMBERED)


## A crew line in the voice of the player who says it, their name on the subtitle.
func _crew_line(id: String, peer_id: int) -> void:
	var l := VoiceLines.get_line(id)
	if l.is_empty():
		return
	var dir := _voice_dir(peer_id)
	# Waits its turn like any line (HUD.Turn); the voice starts with the subtitle.
	await hud.say(_name_of(peer_id), l.text, -1.0, HUD.Turn.NORMAL,
		func() -> float: return _radio_voice.play(id, dir) if _radio_voice else 0.0)


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
	changed_circuits[id] = true  # the read-back takes any circuit the crew changed
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
		_power_step("readback")  # the switch is done; the case waits for its read-back (M5)
		# The power back opens the air case, with its to-do (M4).
		_open("air")
		if _todo_is(TEXT.todo_power):
			_todo(_next_todo())


## Host: the practice is safe. Once the people case is open, the Custodian (if loose)
## starts up the dock stairs towards the passes and the lockup, 180 s on (M8). It
## starts sooner (`engaged`) the moment the crew is at those stations (the first
## pass logged or a hiding door opened).
func _custodian_clock(engaged := false) -> void:
	if custodian_timed or custodian == null or sync == null or not sync.is_host():
		return
	if engaged or Game.case_info("people").get("open", false):
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
	_air_step("readback")  # the order is in; the case waits for its read-back (M5)
	if _todo_is(TEXT.todo_air):
		_todo(_next_todo())
	if sync.is_host():
		_lure_after(lure_delay)  # the radio lies 40 s after the air comes back (M6)


## Every machine: the crew's first request after the air case opened (M4). From here
## the air counts against the crew (host: _process), after a grace long enough to type it.
func _air_armed() -> void:
	air_armed = true


## Host, each frame: while the air is off, the clock runs; after the grace everyone
## on the floor takes a little each tick. Deaths explain themselves (the cause is
## "air"). Not before the power is back either: the panel's practice stays safe
## whichever paper was read first.
func _air_clock(delta: float) -> void:
	if not air_armed or not power_back or air_on or air_cleared or released:
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
	stair_in.set_open(true)  # propped open, if it wasn't already
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
		_todo(_next_todo())
	if sync.is_host() and not air_on:
		_lure_after(lure_delay_propped)  # 15 s after it clears through the stair door (M6)


# --- The radio -----------------------------------------------------------------------------

## Host: once the air is back (or cleared), the radio lies after a while: a
## teammate's voice (solo: Maddison's), asking for the loading door (M6).
func _lure_after(seconds: float) -> void:
	if lure_timed:
		return
	lure_timed = true
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
	sync.event("_lure", [peer, badge, 1, last_which])
	await get_tree().create_timer(lure_again, false).timeout
	if is_inside_tree() and not dock_opened and not swipes_puzzle.solved and not released:
		sync.event("_lure", [peer, badge, 2, last_which])


## Every machine: the voice on the walkie. `peer` is who it sounds like (0 for
## Maddison), in their own recorded voice and with their name on the subtitle.
## Returns how long the line takes (the recording, or the time to read it). SYSOP's
## tip prints on the screen the crew last typed at (`which`, M6).
func _lure(peer: int, badge: String, n: int, which := "hr") -> float:
	lure_peer = peer
	lure_badge = badge
	lures = maxi(lures, n)
	var id: String = LURE_LINES[n]["maddison" if peer == 0 else "crew"]
	if n == 1:
		swipes_puzzle.solved = false
		swipes_puzzle.hint_index = 0
		_lure_hints()
		_radio_step()
		_open("radio")
		if not released:
			_todo("todo_radio")
		_tip("lure", which)
	elif n == 2:
		_open_people()  # the voice's second line: the radio's done either way (M7)
	var l := VoiceLines.get_line(id)
	if l.is_empty():
		return 0.0
	var who: String = "MADDISON" if peer == 0 else _name_of(peer)
	var dur: float = _radio_voice.play(id, _voice_dir(peer) if peer > 0 else "") if _radio_voice else 0.0
	if dur <= 0.0:
		dur = Voice.read_time(l.text)
	hud.say(who, l.text, dur, HUD.Turn.URGENT)  # a threat starting: it cuts across (HUD.Turn)
	return dur


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
	if lures > 0:
		_open_people()  # the radio's done: the door it asked for is open (M7)
		if _todo_is(TEXT.todo_radio):
			_todo(_next_todo())
	if custodian and not custodian_here and sync.is_host():
		sync.event("_custodian_arrives")


## Every machine: an escort pass was logged. The staffer gets up, if their door is open.
func _passed(badge: String) -> void:
	if passed.has(badge) or not staffers.has(badge):
		return
	passed[badge] = true
	_open_people()
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
	# In the World, B1 builds now at the foot of STAIR 2, and the crew walks down
	# to it; on its own the floor ends on the stairs.
	prepare_next()
	var next: Node = world.wings.get("level_6") if world else null
	if next:
		exit_trigger.monitoring = false
		walk_stairs(stair_out, next.stair_in, true, "_down_to_b1", TEXT.stairs_wait)
	var n: Array = data.night
	_open_people()
	Game.tick_step("people", "passes")
	Game.tick_step("people", "lockup")
	Game.tick_step("people", "readback")
	_solve("people", TEXT.people_done % [n[0].first, n[0].hide.place, n[1].first, n[1].hide.place])
	hud.notice(TEXT.stairs_release, 4.0)
	_todo("todo_down")
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
	SfxTouch.reader(get_node_or_null("Reader_" + reader), true)
	if badge == lure_badge and lures > 0 and not swipes_puzzle.solved:
		_radio_step()  # the voice's badge moved: its newest swipe is the one that counts


## Every machine: everyone is on STAIR 2. The radio crackles once more, then down.
func _on_exit() -> void:
	get_node("/root/Net").earn("achievement:floor_9", hud)
	# The voice has one more thing to say; the end card waits for it to be heard.
	exit_hold = EXIT_HOLD
	if lures > 0:
		exit_hold = maxf(exit_hold, _lure(lure_peer, lure_badge, 3))
	if not player:
		return
	player.input_locked = true
	await get_tree().create_timer(exit_hold, false).timeout
	if not is_inside_tree():
		return
	Game.completed_level = "level_5"
	Game.next_level = "level_6"  # Field Notes' Continue: the next floor, in the building
	completed.emit()


## Every machine: everyone is down STAIR 2 on B1's landing. The radio crackles once
## more on the way, and play moves to the cold store.
func _down_to_b1() -> void:
	get_node("/root/Net").earn("achievement:floor_9", hud)
	if lures > 0:
		_lure(lure_peer, lure_badge, 3)
	stairs.seal(Stairwell.of(stair_out))
	Game.completed_level = "level_5"
	Game.next_level = "level_6"
	finish_level("level_6")


func _on_completed() -> void:
	await hud.fade(true, 1.2)
	finish_level("field_notes")


func on_player_died() -> void:
	player.respawn(spawn_point())


## Put task `key` (a TEXT key) on the job: its title and its details. "" ticks off the current one.
func _todo(key: String) -> void:
	if key == "":
		hud.todo("")
	else:
		hud.todo(TASK_TITLES[key], TEXT[key])
