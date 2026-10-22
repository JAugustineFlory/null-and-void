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
## shape (the value as '?') and then the exact query. Every other puzzle uses hint ladder A.
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
		"needs": ["SELECT", "FROM", "ORDER BY", "DESC", "LIMIT", "visitors"],
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
	# Optional, in the lab: the visitor log sorted shows the crew's badges at the scene.
	"badge_log": {
		"level": 2,
		"pressure": true,
		"ladder": "exact",
		"teaches": ["badge_log"],
		"needs": ["SELECT", "FROM", "ORDER BY", "badge_log", "time"],
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
		"needs": ["SELECT", "FROM", "WHERE", "LIKE", "guards", "Pike"],
	},
	"har": {
		"level": 2,
		"pressure": true,
		"teaches": ["Har", "NIGHT SHIFT", "pin", "badge_id"],
		# Main route (depth pass): badge_log sorted by time (ORDER BY, from the memo,
		# now under pressure) gives the night lead's badge; guards by badge_id gives
		# the PIN. LIKE 'Har%' AND shift = 'night' and the roster board still work.
		# DEBT (design plan, 2026-10-19): LIKE is now practised (pike) but no longer
		# required under threat. Level 3 or later must need it again under pressure.
		"needs": ["SELECT", "FROM", "WHERE", "ORDER BY", "guards", "badge_log", "badge_id", "time"],
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
	"slips": {
		"level": 3,
		"pressure": false,
		"ladder": "review",
		"teaches": ["retrieval_slips"],
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
	# GROUP BY with COUNT, found on the reader tally taped to the desk and practised
	# on its harmless whole-log count. The reading room wins by day: the decoy.
	"tally": {
		"level": 3,
		"pressure": false,
		"ladder": "exact",
		"teaches": ["GROUP BY", "one line per room", "access_log"],
		"needs": ["SELECT", "FROM", "COLUMNS", "COUNT", "GROUP BY", "access_log", "room"],
	},
	# The gate: that night's busiest reader. The tally's query plus the date (on the
	# slips, as the readers write it) and the sort from Level 0. The question is on
	# Security's sheet in the north corridor, and setting foot there wakes the
	# Shredder, so this is always typed with it up.
	"visits": {
		"level": 3,
		"pressure": true,
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
		"needs": ["SELECT", "FROM", "WHERE", "IS NULL", "pulled"],
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
	# their room (LIKE on the archivist's note, or his department), under threat.
	"mercer_room": {
		"level": 3,
		"pressure": true,
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
	"check": {
		"level": 4,
		"pressure": false,
		"teaches": ["Check it took"],
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
		"needs": ["SELECT", "FROM", "contractor_log"],
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
	# pressure), then read it back at the bay's own panel within 30 seconds.
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
		"needs": ["SELECT", "FROM", "lockouts"],
	},
}
