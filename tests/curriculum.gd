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
	# Level 1: Server Room A.
	"controller": {
		"level": 1,
		"pressure": false,
		"teaches": ["WHERE", "AND", "door_controllers", "single quotes", "zone A", "'fault'"],
		"needs": ["SELECT", "FROM", "WHERE", "AND", "door_controllers", "zone", "status", "'fault'", "'A'"],
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
		"teaches": ["badge_log"],
		"needs": ["SELECT", "FROM", "ORDER BY", "badge_log", "time"],
	},
	"cameras": {
		"level": 2,
		"pressure": false,
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
		"teaches": ["Har", "NIGHT SHIFT", "pin"],
		# Composed from earlier lessons: LIKE (pike), AND (controller), the shift
		# column and its 'night' value (Pike's row in the guards table).
		"needs": ["SELECT", "FROM", "WHERE", "LIKE", "AND", "guards", "Har", "shift", "night"],
	},
	"door": {
		"level": 2,
		"pressure": true,
		"teaches": ["GET /doors/SEC-EXIT", "sensor", "actuator", "B-"],
		"needs": ["GET", "/doors/SEC-EXIT"],
	},
}
