extends RefCounted
## What each puzzle teaches and what it needs, in play order. The lost-player
## walkthrough (tests/teaching_tests.gd) builds a cumulative "taught" set from this:
##   - every item a puzzle `needs` must already be taught (shown on a terminal line
##     or a sticky note in an earlier puzzle or level) or be on screen now;
##   - every item a puzzle `teaches` must appear on a terminal line or sticky note,
##     so the player is offered it as a "write note" line;
##   - `pressure` says whether something can hunt the player while it's typed. The
##     walkthrough checks the game still matches, so a level change can't quietly
##     take a concept's pressure step away.
## Items are SQL keywords (matched as capitalised words), or plain text that must
## appear as written: table and column names, values, and facts.
## Owned by the Teaching and UX thread. Add a row for every new puzzle.
## `"known_gap"` says why a puzzle's "taught before any hint" check prints as GAP
## until its owner fixes it. `"silent_copy"` says why a write copied off a paper, when it
## isn't the answer, still gets no reason; it prints as GAP until one is added. `"ladder": "exact"` marks a puzzle with no value to find (one request, one sort):
## its first hint stays the exact query. `"ladder": "review"` marks a puzzle whose
## keyword was practised safely on an earlier floor: two tiers, a reminder with the
## shape (the value as a named blank, enter_...) and then the exact query. Every other puzzle uses hint ladder A.
## `"shape_gap"` says why a request ladder's hint 1 still names the value its shape
## leaves blank; it prints as GAP until the owner fixes it.
## `"hint_gap"` says why a script ladder's hint 1 still lacks a line for a script word the
## station teaches; it prints as GAP until the line is approved and in.
## `"threat_first"` says why a keyword is first needed under threat; it prints as GAP.
## Keywords include two patterns (tests/teaching_tests.gd KEYWORD_PATTERNS): ">" is a
## comparison with a value, and "COLUMNS" is SELECT naming columns instead of *.

const PUZZLES := {
	# Level 0: the lobby.
	"peek": {
		"level": 0,
		"pressure": false,
		"teaches": ["SELECT", "FROM", "memo_fragments", "SELECT * FROM memo_fragments;"],
		"needs": ["SELECT", "FROM", "memo_fragments"],
	},
	"memo": {
		"level": 0,
		"pressure": false,
		"teaches": ["ORDER BY", "piece_no"],
		"needs": ["SELECT", "FROM", "memo_fragments", "ORDER BY", "piece_no"],
	},
	# Depth pass (plan/depth-pass-floors-0-2.md): ground floor.
	# "Who called us?": the ticket's extension, matched in the staff directory.
	"caller": {
		"level": 0,
		"pressure": false,
		"teaches": ["COLUMNS", "staff_directory", "extension"],
		# The extension column's name comes from the result (SELECT * also solves it).
		"needs": ["SELECT", "FROM", "COLUMNS", "staff_directory"],
	},
	# Optional: the newest visitor first.
	"last_visitor": {
		"level": 0,
		"pressure": false,
		"teaches": ["DESC", "LIMIT", "visitors", "signed_in"],
		# After the caller: its query names its columns (G22).
		"needs": ["SELECT", "FROM", "COLUMNS", "ORDER BY", "DESC", "LIMIT", "visitors"],
	},
	# Level 1: Server Room A.
	# The controller chain's first step (Easy SQL ch 5): which zone the stuck doors share.
	"stuck_doors": {
		"level": 1,
		"pressure": false,
		"teaches": ["WHERE", "doors", "locked"],
		"needs": ["SELECT", "FROM", "COLUMNS", "WHERE", "doors", "locked", "name", "zone"],
	},
	"controller": {
		"level": 1,
		"pressure": false,
		"teaches": ["WHERE", "AND", "door_controllers", "single quotes", "'fault'"],
		"needs": ["SELECT", "FROM", "WHERE", "AND", "door_controllers", "zone", "status", "'fault'"],
	},
	# Curriculum B: before the reset, the sign-off form wants the floor's faults
	# counted. COUNT practised safely; WARDEN's diagnostics on the desk show it first.
	"faulted_count": {
		"level": 1,
		"pressure": false,
		"teaches": ["COUNT"],
		"needs": ["SELECT", "FROM", "WHERE", "COUNT", "door_controllers", "status", "'fault'"],
	},
	# Depth pass, server floor: the zone now comes from the stuck doors (or their red
	# plates), not the screen; the controller row above covers that query.
	# Optional: the overheating rack, comparison taught safely.
	"hot_rack": {
		"level": 1,
		"pressure": false,
		"teaches": [">", "racks", "temp_c"],
		"needs": ["SELECT", "FROM", "COLUMNS", "WHERE", ">", "racks", "temp_c"],
	},
	# Optional (Easy SQL ch 8): the dark break room, every light that's dead OR flickering.
	"dark_room": {
		"level": 1,
		"pressure": false,
		"teaches": ["OR", "lights"],
		"needs": ["SELECT", "FROM", "COLUMNS", "WHERE", "OR", "lights", "room", "status"],
	},
	# Level 2: the security floor. Rourke turns in Secure Lab B (plan/floors-expansion.md);
	# the lab door's controller is Level 1's WHERE / AND, now under pressure, with the
	# lab's own zone read off the room, not the screen. Walked once Level 2 builds the lab.
	"lab_door": {
		"level": 2,
		"pressure": true,
		"teaches": [],
		"needs": ["SELECT", "FROM", "WHERE", "AND", "door_controllers", "zone", "status", "'fault'"],
	},
	"cameras": {
		"level": 2,
		"pressure": false,
		"ladder": "exact",
		"teaches": ["GET", "GET /cameras", "motion"],
		"needs": ["GET", "/cameras"],
	},
	"pike": {
		"level": 2,
		"pressure": false,
		"teaches": ["LIKE", "% = any letters", "guards", "LIKE 'Pike%'"],
		"needs": ["SELECT", "FROM", "WHERE", "LIKE", "COLUMNS", "guards", "Pike"],
	},
	# The PIN case's step 2 (v0.10 package, M7): the last guard badge through SEC-EXIT,
	# from the badge readers' log sorted by time, found calmly. The Watcher wakes when
	# it's pointed at. Allowed routes: ORDER BY time DESC (the policy card's "sort
	# newest first"), and the briefing room's roster board, whose lead's badge fills it.
	"last": {
		"level": 2,
		"pressure": false,
		"teaches": ["badge_log", "SEC-EXIT"],
		"needs": ["SELECT", "FROM", "WHERE", "ORDER BY", "COLUMNS", "badge_log", "badge_id", "time", "SEC-EXIT"],
	},
	"har": {
		"level": 2,
		"pressure": true,
		# Two tiers, as approved (T58, T59): the middle one was cut, and step 2 found the badge.
		"ladder": "review",
		"teaches": ["Har", "NIGHT SHIFT", "pin", "badge_id"],
		# Step 3 (v0.10 package): guards by the badge step 2 found gives the PIN, typed
		# while it hunts. Allowed routes, any of which fills steps 2 and 3 at once:
		# LIKE 'Har%' AND shift = 'night' (the coffee-stained sheet), WHERE shift =
		# 'night' and the notes ("night shift lead. Badged in 22:00", with the lockdown
		# PIN policy), and the roster board's badge.
		# DEBT (design plan, 2026-10-19): LIKE is now practised (pike) but no longer
		# required under threat. Level 3 or later must need it again under pressure.
		"needs": ["SELECT", "FROM", "WHERE", "COLUMNS", "guards", "badge_id"],
	},
	# Optional (M5): Rourke's statement against his badge's swipes, a calm first use
	# of badge_log once the lab door is open. ORDER BY time DESC reaches 23:40 too.
	"statement": {
		"level": 2,
		"pressure": false,
		"teaches": [],
		"needs": ["SELECT", "FROM", "WHERE", "ORDER BY", "COLUMNS", "badge_log", "badge_id", "time"],
	},
	"door": {
		"level": 2,
		"pressure": true,
		"teaches": ["GET /doors/SEC-EXIT", "sensor", "actuator", "B-"],
		"needs": ["GET", "/doors/SEC-EXIT"],
	},
	# Level 3: the Records Archive on 18 (plan/level-3-records-archive.md), where
	# Act 1 ends (curriculum option B, approved 2026-10-21). The hint ladders are
	# built from plan/approvals/l3-text.md (approved 2026-10-21 11:27Z).
	# COUNT as review: practised on floor 14's reset sign-off (faulted_count, Easy SQL
	# ch 9 "How many?"), found again on the clerk's sticky on the desk terminal, and
	# used safely here before the tally and the night count build on it.
	# The table is on the desk's boot screen and the status word on the clipboard
	# (R3): the board puts the review count together from them.
	"slips": {
		"level": 3,
		"pressure": false,
		"ladder": "review",
		"teaches": [],
		"needs": ["SELECT", "FROM", "WHERE", "COUNT", "retrieval_slips"],
	},
	# DISTINCT, found on the clerk's memo pinned to the card catalogue and practised
	# at once: the memo writes the desk's question out in full.
	"depts": {
		"level": 3,
		"pressure": false,
		"teaches": ["DISTINCT", "one of each", "catalogue", "dept"],
		"needs": ["SELECT", "FROM", "WHERE", "DISTINCT", "catalogue", "dept"],
	},
	# GROUP BY with COUNT, found on the reader tally by the stacks doors and practised
	# on its harmless whole-log count. The reading room wins by day: the decoy.
	"tally": {
		"level": 3,
		"pressure": false,
		"ladder": "exact",
		"teaches": ["GROUP BY", "one line per room", "access_log"],
		"needs": ["SELECT", "FROM", "COLUMNS", "COUNT", "GROUP BY", "access_log", "room"],
	},
	# The room: that night's busiest reader. The tally's query plus the date (on every
	# reader's screen, as the readers write it) and the sort from Level 0. Security's
	# sheet asks it before anything hunts (M1): answered calmly, then the crank wakes
	# the Shredder.
	"visits": {
		"level": 3,
		"pressure": false,
		"teaches": [],
		"needs": ["SELECT", "FROM", "WHERE", "LIKE", "COLUMNS", "COUNT", "GROUP BY", "ORDER BY", "DESC", "access_log", "room", "1997-10-15"],
	},
	# IS NULL, the word no book teaches: found on Mercer's card in the safe room, and
	# practised there on his battery PC (the Shredder can't get in), copying the
	# query his screen shows.
	"mercer_list": {
		"level": 3,
		"pressure": false,
		"ladder": "exact",
		"teaches": ["IS NULL", "pulled", "back_on"],
		"needs": ["SELECT", "FROM", "WHERE", "AND", "IS NULL", "pulled"],
	},
	# Then under threat, back at the desk: the box on the returns cart that nobody
	# checked back in, which holds the stair key. The exit gate.
	"unreturned": {
		"level": 3,
		"pressure": true,
		"teaches": ["returned_at"],
		"needs": ["SELECT", "FROM", "WHERE", "AND", "IS NULL", "retrieval_slips", "returned_at"],
	},
	# The lock's question: whose badge kept using that room's reader. The raw rows
	# read by eye pass too; the digits go on the push-button lock.
	"keyholder": {
		"level": 3,
		"pressure": true,
		"teaches": [],
		"needs": ["SELECT", "FROM", "WHERE", "access_log", "badge_id", "room"],
	},
	# The second route to the room: Mercer's own boxes in the catalogue, listed with
	# their room (LIKE on the archivist's note, or his department), before the crank.
	"mercer_room": {
		"level": 3,
		"pressure": false,
		"teaches": [],
		"needs": ["SELECT", "FROM", "WHERE", "catalogue", "room"],
	},
	# Level 4: the Power Plant on 10 (plan/level-4-power-plant.md). UPDATE and INSERT,
	# the last new SQL, and verify after write. Both writes are StatePuzzles, checked
	# by the table's state after the write. walk_level_4 types them, on both routes.
	# Facilities' work order: reset the tripped breaker, practised safely. Forgetting
	# the WHERE flips the whole panel (loud, never dangerous).
	"reset": {
		"level": 4,
		"pressure": false,
		"teaches": ["UPDATE", "SET", "breakers", "state"],
		"needs": ["UPDATE", "SET", "WHERE", "breakers", "state", "id"],
	},
	# Only after a forgotten WHERE, while the alarm sounds: the others back, one WHERE
	# at a time, as their tags say (practised safely: loud, never dangerous).
	"put_back": {
		"level": 4,
		"pressure": false,
		"teaches": ["note"],
		"needs": ["UPDATE", "SET", "WHERE", "breakers", "state", "id", "note"],
	},
	# The work order's sign-off: read the breaker back (verify after write, safely).
	# The read-back: the case board shows its whole query once the breaker's found
	# (U10, approved 2026-11-21); the step is pointing at the state it reads.
	"check": {
		"level": 4,
		"pressure": false,
		"teaches": [],
		"needs": ["SELECT", "FROM", "WHERE", "breakers", "state", "id"],
	},
	# The clipboard by the controller: the crew logs its own job, practised safely.
	"login": {
		"level": 4,
		"pressure": false,
		"silent_copy": "the clerk's crib is another contractor's row: SYSOP's why drafted for Augustine 2026-10-22, Level 4 wires it",
		"teaches": ["INSERT INTO", "VALUES", "contractor_log"],
		"needs": ["INSERT INTO", "VALUES", "contractor_log"],
	},
	# The log read back: the log-in counts once the crew has seen its row (verify after
	# write, practised safely on every route). SELECT * is long practised: a review ladder.
	"login_read": {
		"level": 4,
		"pressure": false,
		"ladder": "review",
		"teaches": [],
		"needs": ["SELECT", "COLUMNS", "FROM", "contractor_log", "company", "job", "time_in"],
	},
	# The control room's second way in: the gantry arm moved by UPDATE to the bay under
	# the access panel (the gantry card numbers the bays). Optional, practised safely.
	"gantry": {
		"level": 4,
		"pressure": false,
		"teaches": ["gantry", "bay", "raised"],
		"needs": ["UPDATE", "SET", "WHERE", "gantry", "bay", "id"],
	},
	# Facilities' notice's fire exit: an UPDATE on doors. Its row says CONTAINMENT for a
	# crew that reads it first; opening it is the accident (UPDATE's first real use).
	"main_doors": {
		"level": 4,
		"pressure": false,
		"teaches": ["main_doors", "locked"],
		"needs": ["UPDATE", "SET", "WHERE", "doors", "locked", "id", "main_doors"],
	},
	# Optional, with the Custodian loose: lock out the bay's breaker (INSERT under
	# pressure), then read it back at the bay's own panel within 45 seconds.
	"lockout": {
		"level": 4,
		"pressure": true,
		"teaches": ["lockouts"],
		"needs": ["INSERT INTO", "VALUES", "lockouts", "breaker", "company", "job"],
	},
	# The ground floor: the main entrance's row. The write is the lie ("1 row changed",
	# then Epsilon puts it back); the read-back, under pressure, shows it.
	"entrance": {
		"level": 4,
		"pressure": true,
		"teaches": ["gates", "main_entrance", "unlocked"],
		"needs": ["UPDATE", "SET", "WHERE", "gates", "unlocked", "name", "main_entrance"],
	},
	"verify": {
		"level": 4,
		"pressure": true,
		"ladder": "review",
		"teaches": [],
		"needs": ["SELECT", "FROM", "WHERE", "gates", "unlocked", "name", "main_entrance"],
	},
	"readback": {
		"level": 4,
		"pressure": true,
		"ladder": "review",
		"teaches": [],
		"needs": ["SELECT", "FROM", "WHERE", "lockouts", "breaker"],
	},
	# Level 5: the Personnel Wing on 9 (plan/level-5-personnel-wing.md). The database is
	# read-only, so every change goes through the building's services: a key in a header,
	# PATCH and POST with a JSON body, the status codes, and GET to check it took. Every
	# station is a RequestPuzzle, checked by the service's answer and the state it leaves.
	# walk_level_5 types the requests as the hints show them, sealed (the work order) and
	# loose (the stair door propped instead).
	# The HR desk: GET answers 401 until the manager's key rides in an X-Api-Key header.
	# Practised safely. (The temp's key gets 403, but only for whoever tries it.)
	"key": {
		"level": 5,
		"pressure": false,
		"teaches": ["X-Api-Key", "401", "/staff"],
		"needs": ["GET", "X-Api-Key", "/staff"],
	},
	# The frame, the floor's first case: our own visitor badges' log (GET with an id in
	# the path) says we were swiped into Vale's lab while we were on 14. Practised
	# safely on the crew's own badges, before the radio needs it under pressure; the
	# time is pointed at. GET is long practised: a review ladder.
	"frame": {
		"level": 5,
		"pressure": false,
		"ladder": "review",
		"teaches": ["/swipes"],
		"needs": ["GET", "X-Api-Key", "/swipes"],
	},
	# The panel: PATCH the shed circuits back on; the lights don't fit under the night
	# limit until the copiers go off (409). Practised safely.
	"circuits": {
		"level": 5,
		"pressure": false,
		"teaches": ["PATCH", "409", "/circuits", "{\"on\": true}"],
		"needs": ["PATCH", "X-Api-Key", "/circuits"],
	},
	# The panel read back (GET is long practised: a review ladder).
	"check_circuits": {
		"level": 5,
		"pressure": false,
		"ladder": "review",
		"teaches": [],
		"needs": ["GET", "X-Api-Key", "/circuits"],
	},
	# The work order: POST with a body of three fields (400 names a missing one, 201
	# means it was made). Practised safely: the air only counts once the power is back
	# and the crew has asked something since, and its grace is long enough for a
	# first-timer (the sealed walk paces it).
	"air": {
		"level": 5,
		"pressure": false,
		"teaches": ["POST", "201", "400", "/work_orders"],
		"needs": ["POST", "X-Api-Key", "/work_orders"],
	},
	"check_air": {
		"level": 5,
		"pressure": false,
		"ladder": "review",
		"teaches": [],
		"needs": ["GET", "X-Api-Key", "/work_orders"],
	},
	# A voice on the walkie wants the loading door: the badge log says where that badge
	# really is (practised at the frame), pointed at. The voice lies, but nothing hunts
	# the crew while they check it: the Mimics never attack, and the Custodian's clock
	# starts with the people case, once the radio is done.
	"swipes": {
		"level": 5,
		"pressure": false,
		"ladder": "review",
		"teaches": [],
		"needs": ["GET", "X-Api-Key", "/swipes"],
	},
	# Escort passes for the two real night-shifters (POST, practised at the work order),
	# their doors PATCHed open; a Mimic's badge answers 401. Ladder A instead when the
	# stair door was propped and the work order skipped (the walk reads the level's
	# passes_ladder). Under pressure: the Custodian, if its bay wasn't sealed (sealed,
	# nothing hunts here: a gap the architect put to Augustine).
	"passes": {
		"level": 5,
		"pressure": true,
		"ladder": "review",
		"teaches": ["/escorts"],
		"needs": ["POST", "PATCH", "X-Api-Key", "/escorts", "/doors"],
	},
	# The night lockup: every door opened tonight PATCHed shut (practised at the panel),
	# then read back, one at a time or all at once.
	"lockup": {
		"level": 5,
		"pressure": true,
		"ladder": "review",
		"teaches": ["/doors"],
		"needs": ["PATCH", "GET", "X-Api-Key", "/doors"],
	},
	"check_lockup": {
		"level": 5,
		"pressure": true,
		"ladder": "review",
		"shape_gap": "hint 1 also says GET /doors/enter_door: told the architect 2026-10-22",
		"teaches": [],
		"needs": ["GET", "X-Api-Key", "/doors"],
	},
	# Optional: Vale's own record, by id (the staff list shows it). Its ladder comes once
	# the desk's other stations are done; the sealed walk reads it then.
	"vale": {
		"level": 5,
		"pressure": false,
		"ladder": "review",
		"teaches": [],
		"needs": ["GET", "X-Api-Key", "/staff"],
	},
	# Level 6: B1, the cold store (plan/approvals/l6-text.md). The crew's first scripts,
	# from Journey through JavaScript: let, if, while, await sleep and console.log, then
	# for ... of and db.query ("Once for each"). The cold is the threat: the corridor and
	# the vaults drain stamina, then health. Warm rooms are safe.
	# Who's been in there longest: IS NULL, practised on 18, so the review ladder; the
	# name pointed at (v0.10 package). Allowed route: ORDER BY clock_in without IS NULL,
	# reading clock_out down the sorted log (it shows the oldest open visit within 13
	# rows on every seed, and reads the right column).
	"open": {
		"level": 6,
		"pressure": false,
		"ladder": "review",
		"teaches": ["freezer_log", "clock_out"],
		# Naming columns is floor G's lesson; on B1 the case's query on screen names
		# them (V1) once the time clock's sign (or the first query) opens the case.
		"needs": ["SELECT", "COLUMNS", "FROM", "WHERE", "IS NULL", "ORDER BY", "freezer_log"],
	},
	# The try (v0.10 package, M1): the cradle's self-test label, one set. The editor,
	# let, a request as a script line and the log, run once. Two tiers, as approved
	# (V19, V20): its first tier is the label (V18).
	"try": {
		"level": 6,
		"pressure": false,
		"tiers": 2,
		"teaches": ["let", "console.log", "api.post", "/earpieces/pair"],
		"needs": ["let", "console.log", "api.post", "X-Api-Key", "/earpieces/pair"],
	},
	# The loop, at the IT cage: the pairing card's script with this cradle's key, for
	# the crew and Ines and Tomas (M2).
	"pair": {
		"level": 6,
		"pressure": false,
		"teaches": ["while", "await sleep"],
		"needs": ["let", "while", "await sleep", "console.log", "api.post", "X-Api-Key", "/earpieces/pair"],
	},
	# The names, one a line, still at the IT cage: the warm first use of for and db.query
	# (Teaching's B1 audit, item 1).
	"list": {
		"level": 6,
		"pressure": false,
		"teaches": ["for", "const", "db.query"],
		"needs": ["let", "for", "const", "if", "!==", "db.query", "console.log", "SELECT", "FROM", "WHERE", "IS NULL", "freezer_log"],
	},
	# The watchdog, practised at the anteroom, warm: if is new.
	"practice": {
		"level": 6,
		"pressure": false,
		"teaches": ["if", "api.get", "api.patch", "res.body"],
		"needs": ["let", "while", "if", "await sleep", "console.log", "api.get", "api.patch", "X-Api-Key", "/doors"],
	},
	# The same watchdog for the deep freeze, from a deck in the cold corridor.
	"hold": {
		"level": 6,
		"pressure": true,
		"ladder": "review",
		"teaches": [],
		"needs": ["let", "while", "if", "await sleep", "console.log", "api.get", "api.patch", "X-Api-Key", "/doors"],
	},
	# The release, from inside Vault C: every open entry but ours, a slip at a time.
	"release": {
		"level": 6,
		"pressure": true,
		"teaches": ["/clock_outs"],
		"needs": ["let", "for", "const", "if", "!==", "await sleep", "console.log", "db.query", "api.post", "X-Api-Key", "/clock_outs", "SELECT", "FROM", "WHERE", "IS NULL", "freezer_log"],
	},
	# Optional: leave it tidy, every script stopped and both vault doors locked and read back.
	"stop": {
		"level": 6,
		"pressure": false,
		"ladder": "review",
		"teaches": [],
		"needs": ["PATCH", "GET", "X-Api-Key", "/doors"],
	},
	# Level 7: B2, the machine room (plan/approvals/l7-text.md, DRAFT). Journey through
	# JavaScript's last three chapters: a function (function, return, async), a list
	# ([ ], length) and testing (the test bench, assert). Tokens are looked up off the
	# admin's runbook, with no chapter. Nothing hunts on the bench; the dark comes next.
	# A token: trade the key for one, then send it as a header.
	"token": {
		"level": 7,
		"pressure": false,
		"teaches": ["/auth/token", "Authorization: Bearer"],
		"needs": ["POST", "GET", "/auth/token", "Authorization: Bearer", "/lights"],
	},
	# One zone on the bench: the admin's function, finished with return, and tested.
	"restore": {
		"level": 7,
		"pressure": false,
		"teaches": ["async function", "return", "assert"],
		"needs": ["let", "if", "!==", "async function", "return", "assert", "api.get", "api.patch", "api.post", "/auth/token", "Authorization: Bearer", "/lights"],
	},
	# Every zone on the bench, from a list, each asserted.
	"zones": {
		"level": 7,
		"pressure": false,
		"teaches": ["[", "length"],
		"needs": ["let", "for", "const", "async function", "return", "assert", "[", "length", "/lights"],
	},
	# The fight (Augustine's calls 2026-11-06): the tested script, used under pressure,
	# while WARDEN cuts the ring and the Watcher (and whoever else is loose) hunts.
	"lights_out": {
		"level": 7,
		"pressure": true,
		"ladder": "review",
		"teaches": [],
		"needs": ["let", "for", "const", "async function", "return", "assert", "[", "/auth/token", "Authorization: Bearer", "/lights"],
	},
	# Beat him: each player's route (an uplink and the controller, the auth log and a
	# revoke, a watchdog loop with its assert). Each looked up in the world: the
	# controller's plate, the runbook's access page.
	"warden": {
		"level": 7,
		"pressure": true,
		"teaches": ["/auth/log", "/auth/revoke", "/controller"],
		"needs": ["while", "await sleep", "for", "if", "assert", "/auth/log", "/auth/revoke", "/controller", "Authorization: Bearer"],
	},
	# The lifts: a POST for each car, then a check that each is in service.
	"lifts": {
		"level": 7,
		"pressure": true,
		"ladder": "review",
		"teaches": [],
		"needs": ["POST", "GET", "/lifts", "for", "assert", "Authorization: Bearer"],
	},
}
