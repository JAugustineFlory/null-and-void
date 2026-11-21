extends LevelBase
## Level 3: Records Archive, floor 18 ("Mercer's Room").
## The crew comes down the emergency stairs from 22 (the lifts are dead) into a
## records archive at night: a lift lobby, the records desk and reading room, the
## stacks (towering shelves you can climb and cross along the tops), a loop of halls
## round them with side rooms, the shredding room and the microfiche room at the
## north end. One side room hides Mercer's safe room: no network, no grid power, an
## analog lock. The first floppy disk of evidence is in there, and so is the key to
## the stairs down.
##
## Puzzles: SQL stations on the records desk terminal (curriculum option B, approved
## 2026-10-21: Act 1 ends here, in Mercer's room): COUNT as review, DISTINCT, GROUP BY
## with COUNT under the Shredder, and IS NULL as the word the crew looks up on
## Mercer's card. Each station is a Puzzle checked on its result set. Their hints,
## chapters and SYSOP text are drafts in plan/approvals/l3-text.md until Augustine
## approves them word for word. The HTML `hidden` record moved to Level 8: the
## microfiche room has no terminal. The data the stations read is built (Level3Data)
## with a visible source for every row.
## The Shredder (scripts/npc/shredder.gd) sleeps among the machines until the first
## crank is turned, then hunts by sound; the level feeds it every loud thing (`noise`).
##
## Layout (level space, north is -z):
##   lobby           x -4..4,    z 4..8     stairs in (west wall), stairs out (east wall)
##   reading room    x -8..8,    z -6..4    records desk, tables, card drawers
##   stacks          x -8..8,    z -22..-6  five shelf units A1..A5, climbable, 5.6 m ceiling
##   west/east halls x -11..-8 and 8..11, z -22..-2
##   side rooms      Vault C and the map room off the west hall, the cold store and the
##                   supply closet off the east hall; one of the three big ones hides
##                   the safe room behind its rolling shelves (Level3Data.host). Each
##                   big one keeps a walkway along its north wall, past the shelving's
##                   end, from the door to the back wall; the crank sits at that end.
##   north corridor  x -11..11,  z -25..-22
##   shredding room  x -11..0,   z -33..-25 (the Shredder's lair)
##   microfiche room x 2..11,    z -31..-25 (readers; its tube is out)
##
## Co-op: the host decides (cranks, pickups, the exit) and every machine plays it out
## through sync.event; the shelving tweens are driven from those events.

## Fired once the crew is on the stairs down: the wing is done.
signal completed
## Something loud happened (a crank, a dropped box): where and how loud (0..1).
## The Shredder listens to this (next PR), alongside each player's noise_made.
signal noise(at: Vector3, loudness: float)

## Player-facing lines, drafted for Augustine's approval: plan/approvals/l3-text.md.
const TEXT := {
	"todo_arrive": "Find a way down from 18",
	"todo_key": "Mercer's key opens the stairs. Get everyone to the stair lobby",
	"todo_room": "Find the room on 18 whose door reader stayed busy tonight, at the records desk terminal",
	"found_room": "A hidden room. No network jack, no grid power. The building can't see in here.",
	"floppy": "A 3.5\" floppy, hand-labelled. The first thing in this building that isn't on its network.",
	"key": "A brass key ring: STAIR 1 / 18.",
	"stairs_wait": "Waiting for everyone on the stairs (%d/%d)",
	"case_room": "Which room did someone keep going back to tonight?",
	"shredder_wakes": "North of here, the machines stop. Something heavy gets up.",
	"todo_key_box": "At the records desk terminal, find which box on the returns cart was never checked back in. Mercer's key is in it",
	"case_duties": "What did the night clerk leave undone?",
	"case_key": "Which box on the returns cart is the stair key in?",
	"duties_done": "Counted, listed and tallied: the night clerk's list is done.",
	"box_empty": "Papers. No key.",
	"box_taped": "Returns. Taped for reshelving.",
	"box_tear": "Tear the tape on box %s",
	"lock_idle": "ENTER CODE",
	# SYSOP tips at the desk (text only, never lies; each fires once per run).
	"tip_first": "the readers log every swipe. the spike's slips are in retrieval_slips. start with what's on paper.",
	"tip_count": "that's the slips, listed. you've counted before: COUNT(*) does the counting.",
	"tip_log": "that's every swipe. you don't need to read them. count them: GROUP BY room.",
	"tip_week": "that's the week. the day shift lives in the reading room. you want one night. the readers write the date first.",
	"tip_null": "nothing equals NULL, not even NULL. the word is IS NULL.",
	"tip_error": "read the error. it names the word it tripped on. the fix is one character away.",
	"lock_wrong": "NO",
	"lock_open": "OPEN",
}

## Each task's title: how the crew feels and what's going on (Augustine, approved
## 2026-11-05: plan/approvals/task-titles.md). Its details are TEXT under the same key.
const TASK_TITLES := {
	"todo_arrive": "Dead end. Keep it down.",
	"todo_room": "Somebody was here tonight",
	"todo_key_box": "A key nobody brought back",
	"todo_key": "Out, quietly",
}

## The laminated sheet on the records desk that says where push-button codes come
## from. The code gate on Mercer's door: every route in needs the keyholder's badge
## number, which only the readers' log has.
const POLICY_LINES := [
	"HALCYON DATA SYSTEMS  -  FACILITIES",
	"PUSH-BUTTON DOOR LOCKS  (policy 4.2)",
	"The code of a push-button lock is the last four",
	"digits of its keyholder's badge number.",
	"Do not write codes down. Do not share badges.",
	"Lost badge: report to Security, ext. 2100.",
]
## The clerk's memo pinned on the card catalogue: where DISTINCT is found. The desk
## station (depts) is the same question, so the word is practised at once, safely.
## The query on it covers every room, so copying it shows DISTINCT at work but
## doesn't answer the ask: the station wants the stacks only (the WHERE is the
## player's own step, and leaving it off is the tempting wrong answer).
const MEMO_LINES := [
	"RETENTION REVIEW",
	"List every department that still has boxes in the stacks.",
	"ONCE each, please. Legal sent me forty lines last time.",
	{"text": "SELECT DISTINCT dept FROM catalogue;   <- that's every room. narrow it.", "hand": true},
	{"text": "DISTINCT = one of each. no repeats.", "hand": true},
]
## The clerk's sticky on the desk terminal: the reminder of COUNT, which floor 14
## teaches (the reset's sign-off, Easy SQL ch 9), so the slips count is review.
const COUNT_STICKY := "how many? SELECT COUNT(*) FROM ...   not one by one!"
## The note by the slip spike: the ask for the unreturned boxes.
const SPIKE_NOTE := "Pulled and never checked back in: chase Monday."
## Security's sheet by the shredding room's reader: the ask that opens the room
## case. It hangs in the north corridor, past the point where the Shredder wakes.
const EXCEPTIONS_LINES := [
	"HALCYON SECURITY  -  READER EXCEPTIONS  -  FLOOR 18",
	"Tonight one reader on this floor logged far more swipes than any other.",
	"Records desk: identify the room and report to Security, ext. 2100.",
	"Do not enter the room alone.",
]
## Mercer's note on his cot: where the stair key went, and that the desk knows which box.
const NOTE_LINES := [
	{"text": "If you came the hard way: the stair key is in the box nobody", "hand": true},
	{"text": "checked back in. Returns cart, by the desk. The desk knows which.", "hand": true},
	{"text": "- H.M.", "hand": true},
]
## September's reader tally, by the stacks doors (M4): where GROUP BY is found, with the harmless
## count that practises it (the tally station). Over the whole log the reading room
## wins, which is the decoy the night's count has to beat.
const TALLY_LINES := [
	"READER TALLY  -  SEPTEMBER 1997",
	{"columns": ["ROOM", "SWIPES"], "widths": [3.2, 1.6]},
	{"row": ["READING ROOM", "212"], "hand": true},
	{"row": ["STACKS", "96"], "hand": true},
	{"row": ["MICROFICHE", "41"], "hand": true},
	{"row": ["SHRED ROOM", "30"], "hand": true},
	{"row": ["VAULT C", "12"], "hand": true},
	{"row": ["MAP ROOM", "9"], "hand": true},
	{"row": ["COLD STORE", "7"], "hand": true},
	{"row": ["SUPPLY", "5"], "hand": true},
	{"text": "counted off the readers by hand. never again:", "hand": true},
	{"text": "SELECT room, COUNT(*) FROM access_log GROUP BY room;", "hand": true},
	{"text": "GROUP BY room = one line per room. COUNT(*) = how many in each.", "hand": true},
]
## Mercer's SQL pocket reference, open on his desk: the one Act 1 word no book
## teaches. Found here, practised on its own example, then used at the desk.
const CARD_LINES := [
	"SQL POCKET REFERENCE  -  p.2",
	"NULL     an empty cell. Not 0, not ''. Nothing was written.",
	"IS NULL  keeps rows where that cell is empty.",
	"         WHERE signed_out IS NULL   (the front desk's visitors who never signed out)",
	"IS NOT NULL   the opposite.",
	"= NULL   never matches anything. Don't.",
	{"text": "the ones nobody checked back in  - H.M.", "hand": true},
]
## The level's case pages in the notebook (Cases tab), by id.
const CASES := {"room": TEXT.case_room, "duties": TEXT.case_duties, "key": TEXT.case_key}

# --- The v0.10 package (approvals/puzzle-flow-floor-18.md) -----------------------
## The spike note's title, now that it's taped to the returns cart (M3, R1).
const SPIKE_TITLE := "Note on the returns cart"
## The clipboard on the slip spike: the night clerk's three chores (R2).
const CLIPBOARD_LINES := [
	"RETRIEVAL SLIPS  -  OPEN",
	{"text": "%s  -  not pulled yet" % Level3Data.NIGHT, "hand": true},
	"OPEN AT END OF SHIFT: ____",
	{"text": "Night clerk, also tonight:", "hand": true},
	{"text": "- the retention review list (memo's on the catalogue)", "hand": true},
	{"text": "- October's reader tally (September's is up by the stacks doors)", "hand": true},
]
const CLIPBOARD_NOTE := "The clipboard's open-slip count is blank: the night clerk never filled it in."
## The night clerk's case: three chores (R3-R5).
const DUTIES_STEPS := [
	{"id": "slips", "text": "Count the slips still open"},
	{"id": "depts", "text": "List each department with boxes in the stacks, once each"},
	{"id": "tally", "text": "Tally the readers' swipes, a line per room"},
]
const SLIPS_QUERY := "SELECT COUNT(*) FROM {slips} WHERE status = '{status}';"
const DEPTS_QUERY := "SELECT {distinct} dept FROM {catalogue} WHERE room = '{room}';"
const TALLY_QUERY := "SELECT room, COUNT(*) FROM {log} {group_by} room;"
const SLIPS_PIECE := {"id": "slips", "label": "The slips' table", "value": "retrieval_slips", "task": "Find the table the retrieval slips are kept in", "where": "The records desk's screen", "seen_in": "retrieval_slips", "blank": "enter_table_name"}
const OPEN_PIECE := {"id": "status", "label": "What an open slip reads", "value": "open", "task": "Find the word for a slip not pulled yet", "where": "The clipboard on the slip spike", "blank": "enter_status"}
const DISTINCT_PIECE := {"id": "distinct", "label": "How to list each one once", "value": "DISTINCT", "task": "Find how to show each value only once", "where": "The retention review memo on the catalogue"}
const CATALOGUE_PIECE := {"id": "catalogue", "label": "The box records", "value": "catalogue", "task": "Find the table the boxes are filed in", "where": "The records desk's screen", "seen_in": "catalogue", "blank": "enter_table_name"}
const STACKS_PIECE := {"id": "room", "label": "What the catalogue calls the shelves", "value": "STACKS", "task": "Find the room the tall shelves are filed under", "where": "The catalogue's drawer labels", "blank": "enter_room"}
const GROUP_PIECE := {"id": "group_by", "label": "How to count in piles", "value": "GROUP BY", "task": "Find how to count the rows for each room", "where": "September's reader tally by the stacks doors"}
const LOG_PIECE := {"id": "log", "label": "The readers' log", "value": "access_log", "task": "Find where the door readers keep every swipe", "where": "The records desk's screen", "seen_in": "access_log", "blank": "enter_table_name"}
const SLIPS_SLOT := "Open at end of shift:"
const SLIPS_ROW := "That's one slip. The clipboard wants how many are still open."
const SLIPS_OTHER := "Not that number: the clipboard wants only the slips still 'open'."
const DEPTS_REPEATS := "that's the stacks, box by box. the memo wants each department once."
const DEPTS_EVERY := "that's every room's departments. the memo wants only the ones out in the stacks."
const TALLY_NO_COUNT := "one line per room. now count each one: COUNT(*) beside room."
## The card catalogue's drawer labels (R17, R18), and the archivist's own drawer (R30, R31).
const DRAWERS_TITLE := "Catalogue drawers"
const DRAWER_LINES := ["STACKS", "VAULT C", "MAP ROOM", "COLD STORE"]
const DRAWERS_NOTE := "The catalogue drawers are labeled by room: STACKS, VAULT C, MAP ROOM, COLD STORE."
const EXEC_CARD := "EXECUTIVE BOXES  -  ARCHIVIST ONLY"
const EXEC_NOTE := "One catalogue drawer is the archivist's alone: the EXECUTIVE boxes."
## The sign over the reading room's two doors into the stacks (R29).
const STACKS_SIGN := "STACKS"
## The room case: the room, then the badge (R32-R51).
const ROOM_STEPS := [
	{"id": "room", "text": "Find the room the readers logged most tonight"},
	{"id": "badge", "text": "Find whose badge kept opening that room"},
]
const ROOM_QUERY := "SELECT room, COUNT(*) FROM {log} WHERE time LIKE '{date}%' {group_by} room ORDER BY COUNT(*) DESC;"
const DATE_PIECE := {"id": "date", "label": "Tonight, the way the readers write it", "value": Level3Data.NIGHT, "task": "Find how the door readers write tonight's date", "where": "Any door reader's screen", "blank": "enter_date"}
const ROOM_SLOT := "The room someone kept going back to:"
const ROOM_SWIPE := "That's one swipe. The blank wants the room the readers logged most tonight: count them."
const ROOM_WHOLE := "That's the whole log: the day shift fills the reading room. The blank wants tonight's busiest."
const ROOM_QUIET := "That room was quieter tonight. The blank wants the busiest."
const ROOM_OTHER := "Not that one: the blank wants the side room someone kept going back to tonight."
const BADGE_QUERY := "SELECT badge_id FROM {log} WHERE room = '%s';"
const BADGE_SLOT := "The badge that kept opening it:"
const BADGE_PATROL := "That's the night patrol: every room, once or twice. The blank wants the badge on that room's reader, over and over."
const BADGE_HOLDER := "That's whose badge it is. The blank wants its number."
const BADGE_OTHER := "Not that one: the blank wants the badge on that room's reader, over and over."
const ROOM_SOLVED := "The badge's last four digits opened the door behind the shelving."
## The key case: Mercer's question first, then the cart's (R52-R69).
const KEY_STEPS := [
	{"id": "pc", "text": "Answer the question on Mercer's PC"},
	{"id": "cart", "text": "Find which box on the returns cart was never checked back in"},
]
const PC_QUERY := "SELECT box_id FROM pulled WHERE status = 'filled' AND back_on IS NULL;"
const PC_BOOT := [
	"MERCER  -  OFFLINE  -  BATTERY",
	"pulled: my own slips. what I asked for, what came up, when it went back.",
	"what haven't I put back?",
	"    SELECT box_id FROM pulled WHERE status = 'filled' AND back_on IS NULL;",
]
const PC_SLOT := "Mercer never put back:"
const PC_OPEN := "He never got that one: the slip's still open. The blank wants a box he took and never put back."
const PC_BACK := "That one went back. The blank wants one with no date."
const PC_OTHER := "Not that one: the blank wants a box Mercer took and never put back."
const CART_QUERY := "SELECT box_id FROM {slips} WHERE status = '{status}' AND returned_at {is_null};"
const FILLED_PIECE := {"id": "status", "label": "What a pulled slip reads", "value": "filled", "task": "Find the word for a slip whose box was pulled", "where": "Mercer's PC", "blank": "enter_status"}
const NULL_PIECE := {"id": "is_null", "label": "How to ask for an empty cell", "value": "IS NULL", "task": "Find how to ask for a cell nobody wrote in", "where": "Mercer's SQL pocket reference"}
const CART_SLOT := "Never checked back in:"
const CART_OPEN := "That slip's still open: its box never left the shelf. The blank wants a box that came back on the cart."
const CART_BACK := "That one was checked back in. The blank wants one with no return time."
const CART_OTHER := "Not that one: the blank wants a box on the cart that nobody checked back in."
## .hint's first tier: where to look on the floor (R21, R27, R42, R49).
const SPOT_DRAWERS := "the catalogue's drawers are labeled by room, the way the catalogue spells them."
const SPOT_TALLY := "the reader tally for September is up by the stacks doors. it shows how to count each room."
const SPOT_READER := "every door reader on this floor shows its last swipe, the way the readers write the time."
const SPOT_NOTICE := "facilities' notice by the elevators says where push-button codes come from."
## The workers' note on the desk monitor's bezel (v0.10-policy.md, W3).
const W3 := ["Forgot a column name?", ".schema + the table's name.", "Policy can't stop it.   - L."]
## No line of a paper answers these slots: only a pointed-at cell does.
const NO_LINE := ["\u0001"]
## The two book chapters keep this far from the clerk's case opening and from each other (M5).
const CHAPTER_GAP_S := 60.0

## Where the side rooms sit (level space) and which wall is their back wall.
## `back` points from the room into its back wall; the safe room is beyond it.
const SIDE_ROOMS := {
	"VAULT C": {"center": Vector3(-13.5, 0, -19), "back": Vector3(-1, 0, 0), "door_id": "ARC-VAULT-C", "label": "VAULT C"},
	"MAP ROOM": {"center": Vector3(-13.5, 0, -11), "back": Vector3(-1, 0, 0), "door_id": "ARC-MAP", "label": "MAP ROOM"},
	"COLD STORE": {"center": Vector3(13.5, 0, -19), "back": Vector3(1, 0, 0), "door_id": "ARC-COLD", "label": "COLD STORE"},
}
const SIDE_ROOM_SIZE := Vector3(5, 3.2, 6)
## The box labels on each stack unit's shelf face: an aisle's catalogue rows, and
## how many spots a metre apart each shelf has for them (stack_label_spots).
const STACK_LABELS_SQL := "SELECT box_id, dept, shelf FROM catalogue WHERE aisle = '%s' AND status != 'destroyed' ORDER BY shelf LIMIT 6"
const STACK_LABEL_SLOTS := 8
const SAFE_ROOM_SIZE := Vector3(5, 3, 6)
## Rolling compact shelving: four units a hand crank slides along the room. Shut,
## they stand at the back wall with 2.2 m clear inside the door; cranked, they slide
## CRANK_TRAVEL toward the door and still leave 1.2 m there (a player in their path
## is pushed back, never pinned) while the aisle they open at the back wall is
## 1.15 m wide. They stop WALKWAY short of the room's north wall, so a player can
## always walk past their end to the back wall (the only way into that aisle).
const UNITS := 4
const UNIT_PITCH := 0.65
const UNIT_SIZE := Vector3(0.5, 2.4, 4.6)
const CRANK_TRAVEL := 1.0
const WALKWAY := 1.1
## A crank is heard across the floor (Shredder.HEAR_RANGE units).
const CRANK_LOUDNESS := 2.0
const SIDE_DOOR := Vector3(0.08, 2.3, 1.0)  # thin along x: a door in a wall that runs along z
## Where the stairs meet the lobby's walls.
const STAIR_IN_AT := Vector3(-4, 0, 6)
const STAIR_OUT_AT := Vector3(4, 0, 6)
## Where the Shredder starts (level space): among the machines, clear of the conveyor.
const SHREDDER_HOME := Vector3(-5.5, 0, -27)
## The shredding room: its machines drown out any sound in it (level space).
const SHRED_ROOM := AABB(Vector3(-11, -1, -33), Vector3(11, 5, 8))
## Where it wanders between sounds once awake (level space).
const ROAM_POINTS := [Vector3(0, 0, -23.5), Vector3(-4.5, 0, -14), Vector3(4.5, 0, -14), Vector3(-9.5, 0, -8), Vector3(9.5, 0, -8), Vector3(0, 0, -1)]

var data: Dictionary
var desk: Terminal
var stair_in: Door
var stair_out: Door
var room_doors := {}  # reader room -> Door
var cranks := {}  # reader room -> Interactable
var shelving := {}  # reader room -> Array[AnimatableBody3D]
var cranked := {}  # reader room -> bool
var safe_door: Door
## The push-button lock on Mercer's door, and whether its code has been entered.
var lock: Level2Keypad
var safe_unlocked := false
var safe_room_box := AABB()
var reached_safe := false
var floppy: ItemDock
## The PC's drive light, on while the floppy's in it.
var drive_light: Node3D
## The stair key, inside the box on the returns cart that nobody checked back in.
var key_dock: ItemDock
var cart_boxes := {}  # box_id -> CartBox (the key box is key_dock)
## The boxes stay taped until Mercer's note has been read (the safe room, behind the
## lock) and the IS NULL query has named the ones nobody checked back in.
var note_read := false
var boxes_named := false
var key_taken := false
## Mercer's battery PC and its own little database.
var pc: Terminal
var pc_db: FacilityDB
## The room case has been asked (Security's sheet read): the night's count and the
## catalogue route count from then on.
var room_asked := false
var floppy_taken := false
var exit_trigger: Trigger
var shredder: Shredder
## The first crank has been turned: the floor knows what's hunting it now.
var shredder_awake := false
## The stacks' shelf units, for the climb tests and the dressing pass.
var stack_units: Array[StaticBody3D] = []
## Every door reader's screen (its last swipe tonight).
var reader_screens: Array[Document] = []

## Puzzle stations on the desk terminal. Any query with the same result passes.
## Hint ladders (ladder A: the shape with the value as a named blank (enter_...), how to find it, the exact
## query; a station with no value to find starts on the exact query), approved by
## Augustine 2026-10-21 (plan/approvals/l3-text.md, with Teaching's suggestions).
## COUNT, as review, safe: how many slips are still open. The player counted on 14
## already, so the ladder is two tiers: a reminder with the shape, then the query.
var slips_puzzle := Puzzle.new("slips", "SELECT COUNT(*) FROM retrieval_slips WHERE status = 'open'", ["count(*)"], false, [
	"you've counted before: the reset's sign-off on 14. same shape, with the word left blank:\n" +
	"    [color=#ffffff]SELECT COUNT(*) FROM retrieval_slips WHERE status = 'enter_status';[/color]\n" +
	"replace enter_status with the word for \"not filled yet\": the one on the clipboard's header, in small letters.",
	"type this, then Enter:\n" +
	"    [color=#ffffff]SELECT COUNT(*) FROM retrieval_slips WHERE status = 'open';[/color]\n" +
	"point at the number and add it to your notebook. it's the clipboard's blank.",
])
## DISTINCT, new: which departments still have boxes in the stacks (one of each).
var depts_puzzle := Puzzle.new("depts", "SELECT DISTINCT dept FROM catalogue WHERE room = 'STACKS'", ["dept"], false, [
	"the shape, with the room left blank:\n" +
	"    [color=#ffffff]SELECT DISTINCT dept FROM catalogue WHERE room = 'enter_room';[/color]\n" +
	"  SELECT DISTINCT dept   each department once, no repeats\n" +
	"  FROM catalogue   the box records\n" +
	"  WHERE room = 'enter_room'   only the boxes out on the shelves. replace enter_room with what the catalogue calls the shelves.",
	"type\n" +
	"    [color=#ffffff]SELECT DISTINCT room FROM catalogue;[/color]\n" +
	"each room once, the way the catalogue spells it. the tall shelves are the stacks.",
	"type this, then Enter:\n" +
	"    [color=#ffffff]SELECT DISTINCT dept FROM catalogue WHERE room = 'STACKS';[/color]\n",
])
## GROUP BY + COUNT, practised safely: the tally sheet's own count over the whole log.
## The reading room comes out on top, which is the day shift: the decoy. Nothing to
## find, so the ladder starts on the exact query (it's on the sheet anyway).
var tally_puzzle := Puzzle.new("tally", "SELECT room, COUNT(*) FROM access_log GROUP BY room", ["room", "count(*)"], false, [
	"the whole log, a line per room:\n" +
	"    [color=#ffffff]SELECT room, COUNT(*) FROM access_log GROUP BY room;[/color]\n" +
	"  SELECT room, COUNT(*)   each room and how many times\n" +
	"  FROM access_log   the readers' log, every swipe\n" +
	"  GROUP BY room   one line per room, counted",
	"type it exactly as above, then Enter. the tally by the stacks doors did September by hand; this is every month at once.",
])
## GROUP BY + COUNT + ORDER BY DESC, the gate under the Shredder: that night's busiest
## reader. Over the whole log the reading room wins, so the WHERE matters.
## The busiest room with its count, as one row, is the same answer as the whole
## ranking. A lone row without the count isn't: it could be any swipe.
var visits_puzzle := _also(Puzzle.new("visits", "SELECT room FROM access_log WHERE time LIKE '%s%%' GROUP BY room ORDER BY COUNT(*) DESC" % Level3Data.NIGHT, ["room"], true, [
	"the shape, with the night left blank:\n" +
	"    [color=#ffffff]SELECT room, COUNT(*) FROM access_log WHERE time LIKE 'enter_date%' GROUP BY room ORDER BY COUNT(*) DESC;[/color]\n" +
	"  SELECT room, COUNT(*)   each room and how many times\n" +
	"  FROM access_log   the readers' log, every swipe\n" +
	"  WHERE time LIKE 'enter_date%'   only that night's swipes. replace enter_date with the date, as the readers write it\n" +
	"  GROUP BY room   one line per room\n" +
	"  ORDER BY COUNT(*) DESC   busiest first",
	"the night is tonight: the date on every sign-in sheet you've signed. the readers write it year-month-day. without the WHERE, the reading room wins: that's the day shift.",
	"type this, then Enter:\n" +
	"    [color=#ffffff]SELECT room, COUNT(*) FROM access_log WHERE time LIKE '%s%%' GROUP BY room ORDER BY COUNT(*) DESC;[/color]\n" % Level3Data.NIGHT +
	"the top line is the room: point at it and add it to your notebook. its shelving is on a crank.",
]),
	"SELECT room, COUNT(*) FROM access_log WHERE time LIKE '%s%%' GROUP BY room ORDER BY COUNT(*) DESC LIMIT 1" % Level3Data.NIGHT, ["room", "count(*)"], false)
## IS NULL, looked up on Mercer's card and practised on his PC: the boxes on the
## returns cart that nobody checked back in. The stair key is in the first. `= NULL`
## and `= ''` find nothing; without the status the open slips sneak in.
var unreturned_puzzle := Puzzle.new("unreturned", "SELECT box_id FROM retrieval_slips WHERE status = 'filled' AND returned_at IS NULL", ["box_id"], false, [
	"the shape, with the word left blank:\n" +
	"    [color=#ffffff]SELECT box_id FROM retrieval_slips WHERE status = 'enter_status' AND returned_at IS NULL;[/color]\n" +
	"  SELECT box_id   just the box labels\n" +
	"  FROM retrieval_slips   the slips on the spike\n" +
	"  WHERE status = 'enter_status'   slips whose box was pulled. replace enter_status with the other word in the status column\n" +
	"  AND returned_at IS NULL   and nobody ever wrote a return time",
	"type\n" +
	"    [color=#ffffff]SELECT DISTINCT status FROM retrieval_slips;[/color]\n" +
	"each status once. the word is the one that isn't on the clipboard, the same as on Mercer's PC. IS NULL is on Mercer's card.",
	"type this, then Enter:\n" +
	"    [color=#ffffff]SELECT box_id FROM retrieval_slips WHERE status = 'filled' AND returned_at IS NULL;[/color]\n" +
	"point at each box it gives and add it to your notebook. those are the ones on the cart you can open.",
])
## The second route to the same room, through the catalogue instead of the night's
## log: Mercer's own boxes are filed in the room that hides his door (LIKE on the
## note, or his department). His three rows pass, with or without DISTINCT, and so
## does SELECT *. Not the twenty rows of that room's reader: that's the other table.
## Solves the "room" case like `visits`.
var mercer_puzzle := _also(Puzzle.new("mercer_room", "SELECT room FROM catalogue WHERE dept = 'EXECUTIVE'", ["room"], false, [
	"the shape, with the department left blank:\n" +
	"    [color=#ffffff]SELECT room FROM catalogue WHERE dept = 'enter_dept';[/color]\n" +
	"  SELECT room   where each box is filed\n" +
	"  FROM catalogue   the box records\n" +
	"  WHERE dept = 'enter_dept'   only one department's boxes. replace enter_dept with the department of the man who founded the company",
	"type\n" +
	"    [color=#ffffff]SELECT DISTINCT dept FROM catalogue;[/color]\n" +
	"one of those departments is the top of the company. its boxes are all in one side room: his.",
	"type this, then Enter:\n" +
	"    [color=#ffffff]SELECT room FROM catalogue WHERE dept = 'EXECUTIVE';[/color]\n" +
	"the room they're filed in hides his door.",
]),
	"SELECT DISTINCT room FROM catalogue WHERE dept = 'EXECUTIVE'", ["room"], false)
## The lock's question, so `.hint` can help at Mercer's door: whose badge kept using
## that room's reader. Built with the data (the room varies). Distinct, so the raw
## rows read by eye pass too.
var keyholder_puzzle: Puzzle
## The safe practice for IS NULL, on Mercer's PC: what he never put back.
var pc_puzzle := Puzzle.new("mercer_list", "SELECT box_id FROM pulled WHERE status = 'filled' AND back_on IS NULL", ["box_id"], false, [
	"what he never put back (it's on the screen above):\n" +
	"    [color=#ffffff]SELECT box_id FROM pulled WHERE status = 'filled' AND back_on IS NULL;[/color]\n" +
	"  SELECT box_id   just the box labels\n" +
	"  FROM pulled   Mercer's own slips\n" +
	"  WHERE status = 'filled'   the ones that came up to him\n" +
	"  AND back_on IS NULL   and have no date written back in",
	"type it exactly as above, then Enter. two of his boxes never went back: point at each one and add it to your notebook.",
])
## The SYSOP tips that have fired this run (every machine).
var tips_sent := {}
## Each case's slot is on this step (every machine): duties "slips" or "",
## room "room", "badge" or "", key "pc", "cart" or "".
var duties_slot := "slips"
var room_slot := "room"
var key_slot := "pc"
## The boxes named so far in the key case's two steps (every machine).
var pc_named: Array = []
var cart_named: Array = []
## Host: what's been on screen: each step's answer, waiting to be pointed at.
var slips_listed := false
var room_listed := false
var badge_listed := false
var pc_listed := false
var cart_listed := false
## Host: Easy SQL chapters whose paper has been read: "found" waits for the
## clerk's case and the quiet minute, "played" has been held (M5).
var _books := {}
## When the clerk's case opened or a chapter last landed (Time ticks, ms; -1 for none).
var _beat_ms := -1
var pace_s := CHAPTER_GAP_S
## The SYSOP lines on a near miss at the desk that have played (each once).
var misses_said := {}

## Typing is loud (a setting, default OFF, listed for Augustine): a burst of keys at a
## terminal is a sound the Shredder hears from about half a sprint's distance. It
## teaches planning the query before you type. Only the host listens.
var typing_is_loud := false
const TYPING_LOUDNESS := 0.5
const TYPING_BURST := 6  # keys within TYPING_WINDOW before a sound is made
const TYPING_WINDOW := 1.5  # seconds
var _typed := {}  # terminal -> {"len": chars seen, "count": keys this burst, "since": msec}


func build() -> void:
	data = Level3Data.build(Game.run_seed)
	load_level_seed(data.sql)
	pc_db = FacilityDB.new()
	pc_db.load_seed(data.pc_sql)
	keyholder_puzzle = _distinct(Puzzle.new("keyholder", "SELECT badge_id FROM access_log WHERE room = '%s'" % data.host, ["badge_id"], false, [
		"the shape, with the room left blank:\n" +
		"    [color=#ffffff]SELECT badge_id FROM access_log WHERE room = 'enter_room';[/color]\n" +
		"  SELECT badge_id   the badge numbers\n" +
		"  FROM access_log   the readers' log\n" +
		"  WHERE room = 'enter_room'   only this room's reader. replace enter_room with the name over this room's door",
		"the push-button locks notice by the elevators: a lock's code is the last four digits of its keyholder's badge. the badge that keeps coming up is the keyholder.",
		"type this, then Enter:\n" +
		"    [color=#ffffff]SELECT badge_id FROM access_log WHERE room = '%s';[/color]\n" % data.host +
		"point at the badge and add it to your notebook, then key its last four digits into the lock.",
	]))
	for p in [slips_puzzle, depts_puzzle, tally_puzzle]:
		p.case_id = "duties"
	for p in [visits_puzzle, mercer_puzzle, keyholder_puzzle]:
		p.case_id = "room"
	for p in [unreturned_puzzle, pc_puzzle]:
		p.case_id = "key"
	depts_puzzle.spots = [{"id": "drawers", "text": SPOT_DRAWERS, "piece": "room"}]
	tally_puzzle.spots = [{"id": "reader_tally", "text": SPOT_TALLY, "piece": "group_by"}]
	visits_puzzle.spots = [{"id": "reader_tally", "text": SPOT_TALLY, "piece": "group_by"}, {"id": "reader_screen", "text": SPOT_READER, "piece": "date"}]
	keyholder_puzzle.spots = [{"id": "locks_notice", "text": SPOT_NOTICE}]
	# The stacks and the side rooms are named on their doors and the drawers: no
	# result naming them gives anything away.
	for p in [tally_puzzle, visits_puzzle, mercer_puzzle]:
		p.givens = Level3Data.CANDIDATES + ["STACKS"]
	var game := get_node("/root/Game")
	game.answer_found.connect(_on_answer_found)
	game.cell_missed.connect(_on_cell_missed)
	# Each case's first step is ready before its paper opens it: a cell pointed at
	# earlier fills its slot then (M7).
	_duties_step("slips")
	_room_step("room")
	_key_step("pc")

	var floor_c := Color(0.26, 0.25, 0.23)
	var wall_c := Color(0.56, 0.54, 0.48)
	var colors := {"floor": floor_c, "wall": wall_c}
	# Lift lobby: the dead lifts on the south wall, stairs either side.
	Greybox.room(geo, Vector3(0, 0, 6), Vector3(8, 3.2, 4), colors, [
		{"wall": "n", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "w", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},
		{"wall": "e", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},
	])
	Greybox.label(geo, Vector3(0, 2.75, 4.12), "18   RECORDS ARCHIVE", 56, Color(0.75, 0.75, 0.7))
	for x in [-1.5, 1.5]:
		Greybox.panel(geo, Vector3(x, 1.1, 7.88), Vector3(1.3, 2.2, 0.04), Color(0.5, 0.52, 0.55), 0.0)
		Greybox.label(geo, Vector3(x, 2.5, 7.86), "ELEVATOR  18", 32, Color(1.0, 0.45, 0.1), 180)
	# Facilities memo by the lifts: day staff use the stairs until the lifts are fixed.
	Document.place(geo, Vector3(0, 1.5, 7.87), 0, "Facilities memo", [
		"HALCYON DATA SYSTEMS  -  FACILITIES",
		"MEMO  10/15",
		"Lifts 1-4 keep faulting after Tuesday night's power event.",
		"Until they are fixed, use STAIR 1 between floors.",
		"Stair doors lock at 19:00. Do not prop them.",
		"- Facilities, ext. 2200",
	], false, "paper").clues = []
	# Facilities' push-button locks notice, beside its memo (M2): where door codes come from.
	var locks := Document.place(geo, Vector3(0.5, 1.5, 7.87), 0, "Push-button locks", POLICY_LINES, false, "paper")
	locks.spot = "locks_notice"
	# Stairs in from 22, on the lobby's west wall: the crew comes down them and opens
	# the door once they're all on the landing (start()).
	stair_in = Stairwell.build(self, geo, STAIR_IN_AT, 90.0, "18")
	stair_in.name = "Door_STAIR-IN"
	Document.place(geo, STAIR_IN_AT + Vector3(0.12, 1.75, -0.9), -90.0, "Door sign", [
		"FIRE DOOR",
		"KEEP CLOSED",
		"DO NOT PROP",
	], false, "laminated", Vector2(0.22, 0.16))
	# Stairs out, down toward 14, on the east wall: locked after hours. Mercer's key opens it.
	stair_out = Stairwell.build(self, geo, STAIR_OUT_AT, -90.0, "18")
	stair_out.name = "Door_STAIR-OUT"
	exit_door = stair_out
	if not world:
		# On its own, everyone on the stairs ends the floor. In the World the crew
		# walks down them to 10 (_on_key_taken).
		exit_trigger = Trigger.create(self, STAIR_OUT_AT + Vector3(2.4, 1, 0), Vector3(2.8, 2, 3.2))
		exit_trigger.name = "StairsDown"
		exit_trigger.require_all = true
		exit_trigger.waiting.connect(func(n, total): sync.team_notice(TEXT.stairs_wait % [n, total]))
		exit_trigger.entered.connect(func(_b): sync.event("_on_exit"), CONNECT_ONE_SHOT)

	_build_reading_room(colors)
	_build_stacks(colors)
	_build_halls(colors)
	for room in SIDE_ROOMS:
		_build_side_room(room, colors)
	_build_supply(colors)
	_build_north(colors)
	_build_safe_room()

	# Lights follow the `lights` table (sync_world): the stacks' sensor lights are off
	# after hours, the microfiche room's tube is out.
	add_light("L18-LOBBY", Vector3(0, 3.2, 6), 6.0, 0.9)
	add_light("L18-DESK", Vector3(0, 3.2, 1.5), 7.0, 1.0)
	for x in [-5.0, 5.0]:
		add_light("L18-READ", Vector3(x, 3.2, -3), 7.0, 0.9)
	for z in [-9.0, -14.0, -19.0]:
		add_light("L18-STACKS", Vector3(0, 5.6, z), 9.0, 0.9)
	for z in [-6.0, -16.0]:
		add_light("L18-HALL-W", Vector3(-9.5, 3.2, z), 6.0, 0.8)
		add_light("L18-HALL-E", Vector3(9.5, 3.2, z), 6.0, 0.8)
	for x in [-7.0, 0.0, 7.0]:
		add_light("L18-NORTH", Vector3(x, 3.2, -23.5), 6.0, 0.8)
	for x in [-8.5, -2.5]:
		add_light("L18-SHRED", Vector3(x, 3.6, -29), 8.0, 1.1, Color(1.0, 0.95, 0.85))
	FlickerLight.attach(add_light("L18-FICHE", Vector3(6.5, 3.2, -28), 6.0, 0.5), 0.3)
	add_light("L18-VAULT-C", Vector3(-13.5, 3.2, -19), 6.0, 0.8)
	add_light("L18-MAP", Vector3(-13.5, 3.2, -11), 6.0, 0.8)
	add_light("L18-COLD", Vector3(13.5, 3.2, -19), 6.0, 0.8, Color(0.85, 0.92, 1.0))

	spawn = _stair_landing(STAIR_IN_AT, 90.0)

	shredder = Shredder.new()
	shredder.name = "Shredder"
	shredder.space = self
	shredder.mask_zones = [SHRED_ROOM]
	shredder.roam_points.assign(ROAM_POINTS)
	shredder.position = SHREDDER_HOME  # before add_child: a body at the origin for a step can set off triggers
	add_child(shredder)
	noise.connect(func(at, loudness): if sync.is_host(): shredder.hear(at, loudness))
	DressLevel3.apply(self)


## A spot on a stairwell's landing, clear of the flight, facing its door.
func _stair_landing(at: Vector3, yaw_deg: float) -> Transform3D:
	var holder := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg + 180.0)), holder * Vector3(-0.8, 0.1, -1.3))


func player_spawn(index: int) -> Transform3D:
	# Six people fit on the landing, two abreast beside the flight up, clear of the door.
	var slot := Stairwell.landing_slot(STAIR_IN_AT, 90.0, index)
	return global_transform * Transform3D(spawn.basis, slot)


func _build_reading_room(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(0, 0, -1), Vector3(16, 3.2, 10), colors, [
		{"wall": "s", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "n", "at": -4.0, "width": 2.0, "height": 2.6},
		{"wall": "n", "at": 4.0, "width": 2.0, "height": 2.6},
		{"wall": "w", "at": -3.0, "width": 1.0, "height": 2.3},
		{"wall": "e", "at": -3.0, "width": 1.0, "height": 2.3},
	])
	Greybox.label(geo, Vector3(0, 2.75, 3.88), "RECORDS", 56, Color(0.75, 0.75, 0.7), 180)
	# The reading room's hours, beside its door: why the day shift fills it (the decoy).
	Greybox.label(geo, Vector3(0, 2.3, 3.88), "READING ROOM  08:30 - 17:30", 22, Color(0.75, 0.75, 0.7), 180)
	# The records desk faces the lobby door, with its terminal and the slip spike.
	Greybox.box(geo, Vector3(0, 0.5, 1.6), Vector3(4.0, 1.0, 0.8), Color(0.4, 0.34, 0.28), "RecordsDesk")
	desk = Terminal.spawn(geo, Vector3(-0.8, 1.0, 1.6), 0, "RECORDS DESK", db, terminal_ui)
	desk.name = "DeskTerminal"
	desk.puzzles = desk_puzzles()
	_order_hints()
	# Nobody's escorting the crew now: the security policy, from the first query (P1-P9).
	desk.policy = true
	desk.boot_lines = [
		"HALCYON RECORDS  -  ARCHIVE DESK  -  FLOOR 18",
		TerminalPolicy.BOOT_LINE,
		"Box requests: see retrieval_slips. Holdings: catalogue. Reader events: access_log.",
	]
	desk.queried.connect(_on_query.bind("desk"))
	desk.screen_changed.connect(_on_typing.bind(desk))
	# The clipboard on the slip spike: the night clerk's three chores (R2). The open
	# slips aren't listed on it any more, so the count has to be asked. Its date is
	# the night's, written the way the archive files things (and the readers log
	# them): year-month-day.
	var clipboard := Document.place(geo, Vector3(1.2, 1.0, 1.6), 0, "Retrieval slips", CLIPBOARD_LINES, true, "clipboard")
	# Reading the clipboard opens the night clerk's list: the desk's three chores.
	clipboard.clues = [{"case": "duties", "opens": TEXT.case_duties, "tables": ["retrieval_slips", "catalogue", "access_log"], "text": CLIPBOARD_NOTE}]
	clipboard.pieces = [{"case": "duties", "piece": "status", "text": "OPEN", "kind": "value"}, {"case": "room", "piece": "date", "text": Level3Data.NIGHT, "kind": "value"}]
	clipboard.read_by.connect(func(_p): sync.event("_open_duties"))
	# The clerk's sticky on the terminal (COUNT), and beside it on the monitor's
	# bezel, the clerk's note about .schema (W3).
	Document.place(geo, Vector3(-0.52, 1.12, 1.62), 0, "Clerk's sticky", [{"text": COUNT_STICKY, "hand": true}], false, "sticky")
	Document.place(geo, Vector3(-1.08, 1.12, 1.62), 0, "Sticky note", W3.map(func(l): return {"text": l, "hand": true}), false, "sticky")
	# The policy card (P5), pinned to the desk's partition above the terminal: the
	# floor's first policy terminal.
	Greybox.box(geo, Vector3(-0.8, 1.35, 1.17), Vector3(1.8, 0.7, 0.04), Color(0.36, 0.38, 0.4), "DeskPartition")
	TerminalPolicy.place_card(geo, Vector3(-1.5, 1.45, 1.2), 180, false).name = "PolicyCard"
	Greybox.box(geo, Vector3(1.2, 1.1, 1.6), Vector3(0.02, 0.2, 0.02), Color(0.6, 0.6, 0.62), "SlipSpike")
	_build_cart()
	# Reading tables: a top on four legs, so there's room to hide under them.
	for pos in [Vector3(-4.5, 0, -3), Vector3(4.5, 0, -3)]:
		_table(pos, Vector3(2.4, 0.75, 1.1))
	# The card catalogue along the west wall: drawers labelled by range.
	Greybox.box(geo, Vector3(-7.5, 0.7, 1.0), Vector3(0.9, 1.4, 3.6), Color(0.45, 0.32, 0.2), "CardCatalogue")
	Greybox.label(geo, Vector3(-7.03, 1.5, 1.0), "CATALOGUE  A - Z", 30, Color(0.95, 0.92, 0.85), 90)
	# The clerk's memo pinned on the drawers: DISTINCT, found here.
	var memo := Document.place(geo, Vector3(-7.02, 1.15, 2.3), -90, "Retention review memo", MEMO_LINES, false, "memo")
	memo.pieces = [{"case": "duties", "piece": "distinct", "text": "DISTINCT", "kind": "keyword"}]
	memo.read_by.connect(func(_p): _book_found("easy_sql_distinct"))
	# The drawers' labels: a drawer for each room the catalogue files boxes in, as
	# it spells them (R17). All three side rooms have boxes.
	var drawers := Document.place(geo, Vector3(-7.02, 0.95, 0.9), -90, DRAWERS_TITLE, DRAWER_LINES, false, "laminated", Vector2(0.24, 0.24))
	drawers.spot = "drawers"
	drawers.pieces = [{"case": "duties", "piece": "room", "text": "STACKS", "kind": "value"}]
	drawers.clues = [{"case": "duties", "text": DRAWERS_NOTE}]
	# A drawer of its own, kept locked, apart from the room drawers (R30).
	var exec_card := Document.place(geo, Vector3(-7.02, 0.45, -0.3), -90, DRAWERS_TITLE, [EXEC_CARD], false, "laminated", Vector2(0.26, 0.12))
	exec_card.name = "ExecutiveDrawer"
	exec_card.clues = [{"case": "room", "text": EXEC_NOTE}]
	# The stacks doors on the north wall: their sign (R29), a door reader with
	# September's tally beside it (M4), and the lighting notice.
	for x in [-4.0, 4.0]:
		Greybox.label(geo, Vector3(x, 2.85, -5.88), STACKS_SIGN, 40, Color(0.75, 0.75, 0.7))
	_reader(Vector3(5.4, 1.3, -5.88), 180.0, "STACKS", Vector3(0, 0, 1))
	var tally := Document.place(geo, Vector3(6.3, 1.45, -5.87), 180, "Reader tally", TALLY_LINES, false, "laminated", Vector2(0.3, 0.4))
	tally.spot = "reader_tally"
	tally.pieces = [{"case": "duties", "piece": "group_by", "text": "GROUP BY", "kind": "keyword"}, {"case": "room", "piece": "group_by", "text": "GROUP BY", "kind": "keyword"}]
	tally.read_by.connect(func(_p): _book_found("easy_sql_group_by"))
	# The stacks' lighting panel by the stacks doors: why it's dark through there.
	Document.place(geo, Vector3(-1.6, 1.5, -5.88), 180, "Stacks lighting notice", [
		"STACKS LIGHTING",
		"Occupancy sensors. Lights come on with motion 07:00-19:00.",
		"After 19:00 the sensors are off. Override at the records desk (archivist key).",
	], false, "laminated", Vector2(0.3, 0.3))


## A box on the returns cart: taped shut for reshelving, and it stays so until the
## desk names it (Mercer's note read, the IS NULL query run). Then the tape tears
## and it opens. One of them has the key; the rest of the named ones hold papers.
class CartBox extends ItemDock:
	var box_id := ""
	var tape: MeshInstance3D

	static func place(parent: Node, pos: Vector3, size: Vector3, p_box_id: String, item_id: String, tear_prompt: String) -> CartBox:
		var b := CartBox.new()
		b.box_id = p_box_id
		b.position = pos
		b.item = item_id
		b.prompt = tear_prompt
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		b.add_child(shape)
		b.tape = MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(size.x + 0.01, 0.012, 0.09)
		b.tape.mesh = tm
		b.tape.material_override = Greybox.mat(Color(0.86, 0.82, 0.62))
		b.tape.position = Vector3(0, size.y / 2.0 + 0.006, 0)
		b.add_child(b.tape)
		parent.add_child(b)
		b.add_to_group("interactable")
		b.used.connect(b._on_used)
		return b

	func openable() -> bool:
		var lvl: Variant = _level()
		return lvl != null and lvl._box_openable(box_id)

	func get_prompt(player: Node) -> String:
		if not openable():
			var lvl: Variant = _level()
			return lvl.TEXT.box_taped if enabled and lvl != null else ""
		return super.get_prompt(player)

	func interact(player: Node) -> void:
		if openable():
			super.interact(player)


## The returns cart by the reading room's east wall: the filled slips' boxes, back
## from the readers and waiting to be reshelved, each with its label and taped shut.
## One of them was never checked back in, and Mercer's stair key is inside it. No
## box opens until his note has been read and the slips table has named the one or
## two nobody checked in: every way down goes through the lock, the room and IS NULL.
func _build_cart() -> void:
	var cz := 1.3
	Greybox.box(geo, Vector3(7.1, 0.12, cz), Vector3(0.7, 0.04, 2.6), Color(0.3, 0.3, 0.32), "ReturnsCart")
	Greybox.box(geo, Vector3(7.1, 0.67, cz), Vector3(0.7, 0.04, 2.6), Color(0.3, 0.3, 0.32), "ReturnsCart")
	for z in [-1.25, 1.25]:
		Greybox.box(geo, Vector3(7.4, 0.5, cz + z), Vector3(0.05, 1.0, 0.05), Color(0.25, 0.25, 0.27), "CartPost")
	Greybox.label(geo, Vector3(6.74, 0.96, cz - 1.0), "RETURNS\nreshelve FRI", 16, Color(0.9, 0.9, 0.85), -90)
	# The note that used to be by the spike, taped to the cart (M3): it's about these boxes.
	Document.place(geo, Vector3(6.74, 0.92, cz + 0.6), 90, SPIKE_TITLE, [{"text": SPIKE_NOTE, "hand": true}], false, "note", Vector2(0.15, 0.12))
	var ids: Array = data.cart
	for i in ids.size():
		var shelf_y := 0.3 if i < 5 else 0.85
		var pos := Vector3(7.1, shelf_y + 0.14, cz - 1.0 + (i % 5) * 0.5)
		var size := Vector3(0.5, 0.28, 0.4)
		var box_id: String = ids[i]
		if box_id == data.key_box:
			key_dock = CartBox.place(geo, pos, size, box_id, "stair_key", TEXT.box_tear % box_id)
			key_dock.name = "KeyBox"
			key_dock.add_boxes(1, 0.1, Vector3(0.03, 0.12, 0.01), Color(0.75, 0.6, 0.2))
			key_dock.already = "You have the key."
			key_dock.taken.connect(_on_key_taken)
			cart_boxes[box_id] = key_dock
		else:
			var it := CartBox.place(geo, pos, size, box_id, "", TEXT.box_tear % box_id)
			it.name = "CartBox"
			it.already = TEXT.box_empty
			it.taken.connect(func(peer_id): if peer_id == players.id_of(player): hud.notice(TEXT.box_empty, 2.0))
			cart_boxes[box_id] = it
		Greybox.panel(geo, pos, size, Color(0.76, 0.66, 0.5))
		Greybox.label(geo, pos + Vector3(-0.26, 0.0, 0), box_id, 14, Color(0.15, 0.12, 0.1), -90)


## A table top on four legs: something to hide under.
func _table(pos: Vector3, size: Vector3) -> void:
	Greybox.box(geo, pos + Vector3(0, size.y - 0.03, 0), Vector3(size.x, 0.06, size.z), Color(0.42, 0.36, 0.3), "Table")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Greybox.box(geo, pos + Vector3(sx * (size.x / 2 - 0.06), (size.y - 0.06) / 2, sz * (size.z / 2 - 0.06)), Vector3(0.08, size.y - 0.06, 0.08), Color(0.3, 0.3, 0.32), "TableLeg")


func _build_stacks(colors: Dictionary) -> void:
	# A tall room: the shelf tops are 2 m under the ceiling, so you can stand up there.
	Greybox.room(geo, Vector3(0, 0, -14), Vector3(16, 5.6, 16), {"floor": colors.floor, "wall": colors.wall, "ceiling": Color(0.35, 0.35, 0.34)}, [
		{"wall": "s", "at": -4.0, "width": 2.0, "height": 2.6},
		{"wall": "s", "at": 4.0, "width": 2.0, "height": 2.6},
		{"wall": "n", "at": -4.0, "width": 2.0, "height": 2.6},
		{"wall": "n", "at": 4.0, "width": 2.0, "height": 2.6},
		{"wall": "w", "at": 0.0, "width": 1.0, "height": 2.3},
		{"wall": "e", "at": 0.0, "width": 1.0, "height": 2.3},
	])
	var shelf_c := Color(0.42, 0.44, 0.4)
	for i in 5:
		var x := -6.0 + i * 3.0
		var unit := Greybox.box(geo, Vector3(x, 1.8, -15), Vector3(1.2, 3.6, 10), shelf_c, "ShelfUnit")
		stack_units.append(unit)
		_dress_shelf_unit(unit, i)
		var aisle := "A%d" % (i + 1)
		Greybox.label(geo, Vector3(x, 3.2, -9.88), aisle, 64, Color(0.95, 0.9, 0.8))
		Greybox.label(geo, Vector3(x, 3.2, -20.12), aisle, 64, Color(0.95, 0.9, 0.8), 180)
		# Box labels on the shelf faces: the catalogue's rows, where you can read them.
		var rows: Array = db.run_silent(STACK_LABELS_SQL % aisle)
		var spots := stack_label_spots(rows)
		for k in rows.size():
			Greybox.label(geo, Vector3(x + 0.61, spots[k].x, spots[k].y), "%s\n%s" % [rows[k]["box_id"], rows[k]["dept"]], 18, Color(0.15, 0.12, 0.1), 90)
		# Each unit's end face is a ladder of shelf edges: climb it, then cross along the tops.
		Traversal.climbable(geo, Vector3(x, 0, -10), Vector3(x, 3.6, -10), Vector3(0, 0, 1), 1.0)
		Traversal.climbable(geo, Vector3(x, 0, -20), Vector3(x, 3.6, -20), Vector3(0, 0, -1), 1.0)
	# A records cart left in an aisle: cover, and something to climb from.
	Greybox.box(geo, Vector3(1.5, 0.45, -12), Vector3(0.7, 0.9, 1.1), Color(0.5, 0.5, 0.52), "RecordsCart")


## Where each of an aisle's box labels goes on its shelf face, as (height, z along
## the unit), for its catalogue rows (STACK_LABELS_SQL): on its shelf's lip, and
## boxes on the same shelf each in their own spot along it, a metre apart, so no
## two labels print over each other (Augustine, v0.8-beta1 playtest).
static func stack_label_spots(rows: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var taken := {}
	for row in rows:
		var shelf := int(row["shelf"])
		var slot := (shelf % 4) * 2  # the first box on a shelf: where it always went
		while taken.has(Vector2i(shelf, slot % STACK_LABEL_SLOTS)):
			slot += 1
		slot %= STACK_LABEL_SLOTS
		taken[Vector2i(shelf, slot)] = true
		out.append(Vector2(0.5 + shelf * 0.5, -18.5 + slot * 1.0))
	return out


## Make a shelf unit read as shelving, not a slab: the solid box keeps the collision
## (you stand on its top and climb its ends), its own mesh is hidden, and uprights,
## shelf levels and runs of boxes are drawn over it. Cosmetic only, so the boxes'
## layout comes from the unit's index, not the run seed. Graphics polishes later.
func _dress_shelf_unit(unit: StaticBody3D, index: int) -> void:
	var c: Vector3 = unit.position
	var length := 10.0
	var height := 3.6
	for child in unit.get_children():
		if child is MeshInstance3D:
			child.visible = false
	var steel := Color(0.3, 0.32, 0.34)
	var shelf := Color(0.55, 0.56, 0.52)
	# A central back panel the boxes stand against, uprights every 2 m, a slab per level.
	Greybox.panel(geo, c, Vector3(0.12, height, length), Color(0.26, 0.27, 0.28))
	for k in 6:
		var z := c.z - length / 2 + k * 2.0
		for sx in [-0.56, 0.56]:
			Greybox.panel(geo, Vector3(c.x + sx, height / 2, z), Vector3(0.08, height, 0.08), steel)
	for lvl in 8:
		var y := 0.05 + lvl * 0.5
		Greybox.panel(geo, Vector3(c.x, y, c.z), Vector3(1.2, 0.05, length), shelf if lvl < 7 else Color(0.48, 0.5, 0.46))
	# Runs of boxes on each level, each face, each bay: cardboard in a few tones, with
	# gaps so you can see where the shelves are empty.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + index
	var tones := [Color(0.72, 0.62, 0.46), Color(0.66, 0.56, 0.42), Color(0.76, 0.68, 0.52), Color(0.5, 0.5, 0.56)]
	for lvl in 7:
		var y := 0.08 + lvl * 0.5 + 0.15
		for face in [-1.0, 1.0]:
			for bay in 5:
				var z0 := c.z - length / 2 + bay * 2.0 + 0.1
				var cursor := 0.0
				while cursor < 1.7:
					var run := rng.randf_range(0.3, 0.9)
					if rng.randf() < 0.25:
						cursor += run  # an empty stretch
						continue
					run = minf(run, 1.8 - cursor)
					Greybox.panel(geo, Vector3(c.x + face * 0.35, y, z0 + cursor + run / 2), Vector3(0.42, 0.3, run - 0.04), tones[rng.randi_range(0, tones.size() - 1)])
					cursor += run + 0.05


func _build_halls(colors: Dictionary) -> void:
	# West hall, with its side rooms' doors; east hall the same.
	Greybox.room(geo, Vector3(-9.5, 0, -12), Vector3(3, 3.2, 20), colors, [
		{"wall": "e", "at": 8.0, "width": 1.0, "height": 2.3},  # reading room
		{"wall": "e", "at": -2.0, "width": 1.0, "height": 2.3},  # stacks
		{"wall": "n", "at": 0.0, "width": 1.6, "height": 2.4},  # north corridor
		{"wall": "w", "at": -7.0, "width": 1.0, "height": 2.3},  # Vault C
		{"wall": "w", "at": 1.0, "width": 1.0, "height": 2.3},  # map room
	])
	Greybox.room(geo, Vector3(9.5, 0, -12), Vector3(3, 3.2, 20), colors, [
		{"wall": "w", "at": 8.0, "width": 1.0, "height": 2.3},
		{"wall": "w", "at": -2.0, "width": 1.0, "height": 2.3},
		{"wall": "n", "at": 0.0, "width": 1.6, "height": 2.4},
		{"wall": "e", "at": -7.0, "width": 1.0, "height": 2.3},  # cold store
		{"wall": "e", "at": 1.5, "width": 1.0, "height": 2.3},  # supply closet
	])
	# Readers for the stacks' hall doors (both log as STACKS).
	_reader(Vector3(-8.12, 1.3, -14.9), 90.0, "STACKS", Vector3(-1, 0, 0))
	_reader(Vector3(8.12, 1.3, -14.9), -90.0, "STACKS", Vector3(1, 0, 0))


## A side room off a hall: a reader by its door, rolling shelving inside with a crank
## at the door end. Cranked, the units slide toward the door and open an aisle along
## the back wall. In the host room the safe room's door is in that wall.
func _build_side_room(room: String, colors: Dictionary) -> void:
	var spec: Dictionary = SIDE_ROOMS[room]
	var c: Vector3 = spec.center
	var back: Vector3 = spec.back
	var door_wall := "w" if back.x > 0 else "e"  # the door is opposite the back wall
	var back_wall := "e" if back.x > 0 else "w"
	var gaps := [{"wall": door_wall, "at": 0.0, "width": 1.0, "height": 2.3}]
	if room == data.host:
		gaps.append({"wall": back_wall, "at": 1.0, "width": 1.0, "height": 2.2})
	Greybox.room(geo, c, SIDE_ROOM_SIZE, colors, gaps)
	var door_x: float = c.x - back.x * SIDE_ROOM_SIZE.x / 2
	Greybox.label(geo, Vector3(door_x - back.x * 0.12, 2.6, c.z), spec.label, 40, Color(0.2, 0.2, 0.2), 90.0 if back.x < 0 else -90.0)
	var d := add_door(spec.door_id, Vector3(door_x, SIDE_DOOR.y / 2, c.z), SIDE_DOOR)
	# Hinged on its south edge, so a leaf swung into the room lies clear of the walkway.
	d.make_hinged(Vector3(0, 0, 0.5), 90.0 * back.x)
	room_doors[room] = d
	_reader(Vector3(door_x - back.x * 0.12, 1.3, c.z + 0.9), 90.0 if back.x < 0 else -90.0, room, -back)
	# Rolling units, back to front, on rails; the walkway runs along the north wall.
	var unit_z: float = c.z - SIDE_ROOM_SIZE.z / 2 + 0.1 + WALKWAY + UNIT_SIZE.z / 2
	Greybox.box(geo, Vector3(c.x, 0.02, unit_z), Vector3(SIDE_ROOM_SIZE.x - 0.4, 0.04, 0.1), Color(0.3, 0.3, 0.32), "Rail")
	var units: Array = []
	for i in UNITS:
		var x: float = c.x + back.x * (SIDE_ROOM_SIZE.x / 2 - 0.1 - 0.15 - UNIT_SIZE.x / 2 - i * UNIT_PITCH)
		units.append(_rolling_unit(Vector3(x, UNIT_SIZE.y / 2, unit_z), "%s unit %d" % [room, i + 1]))
	shelving[room] = units
	cranked[room] = false
	# The crank on the front unit's north end, in the walkway: it rides along with the unit.
	var crank := Interactable.create(units[UNITS - 1], Vector3(0, 1.1 - UNIT_SIZE.y / 2, -(UNIT_SIZE.z / 2 + 0.12)), Vector3(0.3, 0.3, 0.2), "Turn the crank", Color(0.25, 0.25, 0.28))
	crank.name = "Crank_" + room.replace(" ", "")
	crank.used.connect(func(_p): sync.event("_crank", [room]))
	cranks[room] = crank


func _rolling_unit(center: Vector3, label: String) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = "RollingUnit"
	body.sync_to_physics = false
	body.position = center
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = UNIT_SIZE
	mesh.mesh = bm
	mesh.material_override = Greybox.mat(Color(0.5, 0.52, 0.48))
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = UNIT_SIZE
	shape.shape = bs
	body.add_child(shape)
	body.set_meta("label", label)
	add_child(body, true)
	return body


## A badge reader beside a door: the source of every access_log row. Its screen,
## above it, shows the last swipe tonight at `room`'s doors, as the readers log it:
## the date piece's spot (no words, only the time). `out` points from its wall
## into the room it's read from.
func _reader(pos: Vector3, facing_deg: float, room := "", out := Vector3.ZERO) -> void:
	var r := Node3D.new()
	r.name = "Reader"
	r.position = pos
	r.rotation_degrees.y = facing_deg
	geo.add_child(r, true)
	Greybox.panel(r, Vector3.ZERO, Vector3(0.1, 0.16, 0.03), Color(0.15, 0.15, 0.16))
	Greybox.panel(r, Vector3(0, 0.05, 0.017), Vector3(0.02, 0.02, 0.005), Color(0.2, 1.0, 0.3), 3.0)
	if room == "":
		return
	var last: Array = db.run_silent("SELECT time FROM access_log WHERE room = '%s' AND time LIKE '%s%%' ORDER BY time DESC LIMIT 1" % [room, Level3Data.NIGHT])
	if last.is_empty():
		return
	# A laminated face looks along -z at 0 degrees: turn it to look along `out`.
	var face := rad_to_deg(atan2(-out.x, -out.z))
	var screen := Document.place(geo, pos + out * 0.03 + Vector3(0, 0.14, 0), face, room, [str(last[0]["time"])], false, "laminated", Vector2(0.22, 0.12))
	screen.name = "ReaderScreen"
	screen.spot = "reader_screen"
	screen.pieces = [{"case": "room", "piece": "date", "text": Level3Data.NIGHT, "kind": "value"}]
	reader_screens.append(screen)


func _build_supply(colors: Dictionary) -> void:
	# A closet with a door that shuts: somewhere to hide.
	Greybox.room(geo, Vector3(12.5, 0, -10.5), Vector3(3, 3.2, 3), colors, [
		{"wall": "w", "at": 0.0, "width": 1.0, "height": 2.3},
	])
	Greybox.label(geo, Vector3(10.88, 2.6, -10.5), "SUPPLY", 36, Color(0.2, 0.2, 0.2), -90)
	var d := add_door("ARC-SUPPLY", Vector3(11, SIDE_DOOR.y / 2, -10.5), SIDE_DOOR)
	d.make_hinged(Vector3(0, 0, -0.5), -90.0)
	room_doors["SUPPLY"] = d
	_reader(Vector3(10.88, 1.3, -9.6), -90.0, "SUPPLY", Vector3(-1, 0, 0))
	Greybox.box(geo, Vector3(13.6, 1.0, -10.5), Vector3(0.6, 2.0, 2.4), Color(0.4, 0.4, 0.42), "SupplyShelf")


func _build_north(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(0, 0, -23.5), Vector3(22, 3.2, 3), colors, [
		{"wall": "s", "at": -9.5, "width": 1.6, "height": 2.4},
		{"wall": "s", "at": 9.5, "width": 1.6, "height": 2.4},
		{"wall": "s", "at": -4.0, "width": 2.0, "height": 2.6},
		{"wall": "s", "at": 4.0, "width": 2.0, "height": 2.6},
		{"wall": "n", "at": -5.5, "width": 2.4, "height": 2.4},
		{"wall": "n", "at": 6.5, "width": 1.0, "height": 2.3},
	])
	# The Shredder sleeps on until the first crank (M1): the question that hangs here
	# by the reader is read, and answered, calmly.
	var sheet := Document.place(geo, Vector3(-3.3, 1.5, -24.88), 180, "Reader exceptions", EXCEPTIONS_LINES, false, "paper")
	sheet.clues = [{"case": "room", "opens": TEXT.case_room, "tables": ["access_log", "catalogue"], "text": "The exceptions sheet by the shredding room: one reader on 18 logged far more swipes than any other tonight."}]
	sheet.read_by.connect(func(_p): sync.event("_ask_room"))
	# The shredding room: industrial shredders, bins and a conveyor. Loud when running.
	Greybox.room(geo, Vector3(-5.5, 0, -29), Vector3(11, 3.6, 8), {"floor": Color(0.3, 0.3, 0.3), "wall": Color(0.5, 0.5, 0.48)}, [
		{"wall": "s", "at": 0.0, "width": 2.4, "height": 2.4},
	])
	Greybox.label(geo, Vector3(-5.5, 2.7, -24.88), "SHREDDING", 44, Color(0.75, 0.2, 0.15), 0)
	# A wide roll-up door for the bins, up while the machines run (its row is unlocked):
	# the Shredder's way out, and the way its noise spills into the corridor.
	room_doors["SHRED ROOM"] = add_door("ARC-SHRED", Vector3(-5.5, 1.2, -25), Vector3(2.4, 2.4, 0.08))
	_reader(Vector3(-4.3, 1.3, -24.88), 180.0, "SHRED ROOM", Vector3(0, 0, 1))
	for x in [-9.0, -6.5]:
		Greybox.box(geo, Vector3(x, 0.9, -31.5), Vector3(1.6, 1.8, 1.2), Color(0.25, 0.27, 0.3), "Shredder")
		Greybox.panel(geo, Vector3(x, 1.95, -31.5), Vector3(1.0, 0.3, 0.6), Color(0.1, 0.1, 0.1))
	Greybox.box(geo, Vector3(-4.5, 0.4, -29.5), Vector3(5.0, 0.8, 0.9), Color(0.35, 0.35, 0.38), "Conveyor")
	for x in [-2.0, -0.9]:
		Greybox.box(geo, Vector3(x, 0.55, -32.0), Vector3(0.8, 1.1, 0.8), Color(0.15, 0.3, 0.5), "Bin")
	Greybox.box(geo, Vector3(-9.5, 0.6, -27.0), Vector3(1.2, 1.2, 1.2), Color(0.75, 0.72, 0.6), "PaperBale")
	# The microfiche room: readers along the wall, and a dead monitor on the end desk.
	Greybox.room(geo, Vector3(6.5, 0, -28), Vector3(9, 3.2, 6), colors, [
		{"wall": "s", "at": 0.0, "width": 1.0, "height": 2.3},
	])
	Greybox.label(geo, Vector3(6.5, 2.6, -24.88), "MICROFICHE", 36, Color(0.2, 0.2, 0.2), 0)
	var fd := add_door("ARC-FICHE", Vector3(6.5, SIDE_DOOR.y / 2, -25), Vector3(1.0, 2.3, 0.08))
	fd.make_hinged(Vector3(-0.5, 0, 0), 90.0)
	room_doors["MICROFICHE"] = fd
	_reader(Vector3(7.4, 1.3, -24.88), 180.0, "MICROFICHE", Vector3(0, 0, 1))
	for x in [3.5, 5.5, 7.5]:
		Greybox.box(geo, Vector3(x, 0.4, -30.3), Vector3(1.4, 0.8, 0.8), Color(0.36, 0.3, 0.25), "FicheDesk")
		Greybox.box(geo, Vector3(x, 1.1, -30.5), Vector3(0.6, 0.6, 0.5), Color(0.75, 0.72, 0.62), "FicheReader")
	Greybox.box(geo, Vector3(9.8, 0.4, -27.5), Vector3(1.4, 0.8, 0.8), Color(0.36, 0.3, 0.25), "FicheDesk")
	Greybox.box(geo, Vector3(9.8, 1.05, -27.5), Vector3(0.12, 0.5, 0.6), Color(0.08, 0.08, 0.09), "DeadMonitor")


## Mercer's room, beyond the host room's back wall. Off-grid: a generator and a
## battery bank, a lantern, a cot, his desk. The floppy disk is on the desk; the stair
## key hangs by the door. Nothing in here is on the building's network or its lights table.
func _build_safe_room() -> void:
	var spec: Dictionary = SIDE_ROOMS[data.host]
	var back: Vector3 = spec.back
	var c: Vector3 = spec.center + back * (SIDE_ROOM_SIZE.x / 2 + SAFE_ROOM_SIZE.x / 2)
	var door_wall := "w" if back.x > 0 else "e"
	Greybox.room(geo, c, SAFE_ROOM_SIZE, {"floor": Color(0.22, 0.2, 0.18), "wall": Color(0.42, 0.38, 0.32), "ceiling": Color(0.3, 0.28, 0.26)}, [
		{"wall": door_wall, "at": 1.0, "width": 1.0, "height": 2.2},
	])
	safe_room_box = AABB(c - Vector3(SAFE_ROOM_SIZE.x / 2, 0.5, SAFE_ROOM_SIZE.z / 2), SAFE_ROOM_SIZE + Vector3(0, 1, 0))
	# An ordinary door in the vault's back wall, where the shelving hid it.
	var wall_x: float = spec.center.x + back.x * SIDE_ROOM_SIZE.x / 2
	safe_door = Door.create(self, "MERCER", Vector3(wall_x, 1.1, spec.center.z + 1.0), Vector3(0.08, 2.2, 1.0), Color(0.45, 0.4, 0.34))
	safe_door.make_hinged(Vector3(0, 0, -0.5), 90.0 * back.x)
	# Locked by a push-button lock beside it (the coded step on every route in: the
	# code is the keyholder's badge number, from access_log). Cranks only find the door.
	safe_door.locked = true
	# Proud of the wall (walls are 0.2 thick), its face toward the room.
	lock = Level2Keypad.mount(geo, Vector3(wall_x - back.x * 0.13, 1.3, spec.center.z + 1.9), -90.0 * back.x, "mercer", TEXT.lock_idle)
	lock.name = "MercerLock"
	lock.key_pressed.connect(func(key, _by): sync.event("_lock_key", [key]))
	# Found: the host says so, everyone hears it.
	var found := Trigger.create(self, c + Vector3(0, 1, 0), Vector3(SAFE_ROOM_SIZE.x - 0.6, 2, SAFE_ROOM_SIZE.z - 0.6))
	found.name = "SafeRoomFound"
	found.entered.connect(func(_b): sync.event("_enter_safe_room"), CONNECT_ONE_SHOT)
	# Generator and battery bank along the back wall, the lantern on the desk.
	var far_x: float = c.x + back.x * (SAFE_ROOM_SIZE.x / 2 - 0.6)
	Greybox.box(geo, Vector3(far_x, 0.5, c.z - 2.0), Vector3(1.0, 1.0, 1.2), Color(0.6, 0.25, 0.1), "Generator")
	for i in 3:
		Greybox.box(geo, Vector3(far_x, 0.25, c.z - 0.4 + i * 0.6), Vector3(0.8, 0.5, 0.5), Color(0.1, 0.1, 0.12), "Battery")
	Greybox.box(geo, Vector3(c.x, 0.2, c.z + 2.2), Vector3(1.9, 0.4, 0.8), Color(0.3, 0.32, 0.28), "Cot")
	Greybox.box(geo, Vector3(c.x - back.x * 0.4, 0.38, c.z - 1.0), Vector3(1.6, 0.76, 0.8), Color(0.4, 0.34, 0.28), "MercerDesk")
	var lantern := OmniLight3D.new()
	lantern.position = Vector3(c.x - back.x * 0.4, 1.1, c.z - 1.0)
	lantern.omni_range = 5.5
	lantern.light_energy = 1.2
	lantern.light_color = Color(1.0, 0.85, 0.6)
	geo.add_child(lantern)
	Greybox.panel(geo, lantern.position, Vector3(0.12, 0.2, 0.12), Color(1.0, 0.9, 0.7), 2.0)
	# Mercer's SQL reference card, open at the page he dog-eared.
	var card := Document.place(geo, Vector3(c.x + back.x * 0.55, 0.77, c.z - 0.9), 0, "SQL pocket reference", CARD_LINES, true, "paper")
	card.words = ["IS NULL"]  # read, it's on the terminal's buttons
	card.pieces = [{"case": "key", "piece": "is_null", "text": "IS NULL", "kind": "keyword"}]
	# His battery PC: off the network, with his own list on it. The safe practice for IS NULL.
	pc = Terminal.spawn(geo, Vector3(c.x, 0.76, c.z - 1.2), 0, "MERCER (OFFLINE)", pc_db, terminal_ui)
	pc.name = "MercerPC"
	pc.puzzles = [pc_puzzle]
	# Off the network, the policy doesn't reach it: SELECT * runs here.
	pc.boot_lines = PC_BOOT.duplicate()
	pc.queried.connect(_on_query.bind("pc"))
	# His note, on the cot: where the stair key went.
	var note := Document.place(geo, Vector3(c.x, 0.41, c.z + 2.2), 180, "Mercer's note", NOTE_LINES, true, "note")
	note.clues = [{"case": "key", "opens": TEXT.case_key, "tables": ["retrieval_slips"], "text": "Mercer's note: the stair key is in the box on the returns cart that nobody checked back in."}]
	note.read_by.connect(func(_p): sync.event("_note_read"))
	# The floppy, one copy, in his PC's drive with its light on (M6): it comes out
	# once his question on the PC is answered. Whoever takes it carries it.
	var drive := Vector3(c.x + 0.32, 0.8, c.z - 1.05)
	floppy = ItemDock.make(geo, drive, Vector3(0.2, 0.08, 0.2), "Take the floppy disk", "floppy_disk")
	floppy.name = "FloppyDock"
	floppy.add_boxes(1, 0.1, Vector3(0.09, 0.01, 0.09), Color(0.1, 0.1, 0.12))
	floppy.enabled = false
	Greybox.box(geo, drive + Vector3(0, -0.02, -0.02), Vector3(0.18, 0.06, 0.16), Color(0.7, 0.68, 0.62), "FloppyDrive")
	drive_light = Greybox.panel(geo, drive + Vector3(0.06, 0.0, 0.065), Vector3(0.015, 0.01, 0.005), Color(0.2, 1.0, 0.3), 3.0)
	floppy.already = "You have the disk."
	floppy.taken.connect(_on_floppy_taken)
	# An empty hook by the door: the key ring isn't on it (see the note).
	Greybox.panel(geo, Vector3(wall_x + back.x * 0.3, 1.5, spec.center.z + 2.0), Vector3(0.03, 0.08, 0.03), Color(0.5, 0.5, 0.5))


func apply_environment(env: Environment) -> void:
	env.ambient_light_energy = 0.06
	env.fog_density = 0.04


func net_setup() -> void:
	shredder.crew = crew
	sync.replicate(shredder, shredder.sync_properties())
	# This machine's player's own sounds (landings, vents, a dropped box); other
	# players' sprints it hears from how fast their bodies move.
	player.noise_made.connect(func(at, loudness): if sync.is_host(): shredder.hear(at, loudness))


func start() -> void:
	if completed.get_connections().is_empty():
		completed.connect(_on_completed)
	stair_in.locked = false  # the crew's all here: out of the stairwell, onto 18
	floppy.stock(1)
	key_dock.stock(1)
	pc.ensure_booted()
	_todo("todo_arrive")


# --- Terminals -------------------------------------------------------------------

func puzzles() -> Array:
	return desk_puzzles() + [pc_puzzle]


static func _distinct(p: Puzzle) -> Puzzle:
	p.distinct = true
	return p


static func _also(p: Puzzle, sql: String, cols: Array, p_ordered: bool) -> Puzzle:
	p.accept_also(sql, cols, p_ordered)
	return p


func desk_puzzles() -> Array:
	return [slips_puzzle, depts_puzzle, tally_puzzle, visits_puzzle, unreturned_puzzle, mercer_puzzle, keyholder_puzzle]


## `.hint` helps with the first unsolved station on the desk, so the order follows
## the floor's questions as they come up: the key's box once Mercer's note is read,
## the lock once the room is known (named by a query, or its door found), the room
## once Security's sheet asks, and the clerk's three practice stations before any
## of them. Every station stays listed.
func _order_hints() -> void:
	var order := []
	if note_read:
		order.append(unreturned_puzzle)
	var room_known: bool = room_slot != "room" or cranked.get(data.host, false)
	if room_known:
		order.append(keyholder_puzzle)
	if room_asked and not room_known:
		order.append_array([visits_puzzle, mercer_puzzle])
	order.append_array([slips_puzzle, depts_puzzle, tally_puzzle])
	for p in desk_puzzles():
		if not order.has(p):
			order.append(p)
	desk.puzzles = order


## Host: a query ran at the desk or on Mercer's PC. A step solved by the whole
## result (the clerk's departments and tally) plays out on every machine; one
## answered by pointing at a cell waits for the click (the *_listed flags).
func _on_query(sql: String, result: Dictionary, _ui: TerminalUI, which: String) -> void:
	var lower := sql.to_lower()
	var rows: Array = result.get("rows", [])
	if which == "pc":
		if pc_puzzle.matches(pc_db, result):
			pc_listed = true
		return
	# The whole result, past the policy's cap, for the checks that need every row.
	var full := result
	if result.get("capped", false):
		full = db.execute(sql)
	if slips_puzzle.matches(db, result):
		slips_listed = true
	if not depts_puzzle.solved and depts_puzzle.matches(db, full):
		sync.event("_on_solved", ["depts", which])
	if not tally_puzzle.solved and tally_puzzle.matches(db, full):
		sync.event("_on_solved", ["tally", which])
	if visits_puzzle.matches(db, result) or mercer_puzzle.matches(db, full):
		room_listed = true
	if keyholder_puzzle.matches(db, full):
		badge_listed = true
	if unreturned_puzzle.matches(db, result):
		cart_listed = true
	# The clerk's near misses: each gives its reason once (R19, R20, R26).
	if Game.case_info("duties").get("open", false) and not depts_puzzle.solved:
		if depts_repeats.matches(db, full):
			_miss_if("depts_repeats", DEPTS_REPEATS)
		elif depts_every.matches(db, full):
			_miss_if("depts_every", DEPTS_EVERY)
	if Game.case_info("duties").get("open", false) and not tally_puzzle.solved and tally_rooms.matches(db, full):
		_miss_if("tally_rooms", TALLY_NO_COUNT)
	# SYSOP's tips at the desk, each once: text only, and never the answer.
	var fresh := not tips_sent.has("first")
	_tip_if(true, "first")
	_tip_if(result.get("error", "") != "" and result.get("policy", "") != "refused", "error")
	# The slips listed instead of counted (review of COUNT, as 14's sign-off put it).
	# Not once Mercer's note has asked the slips a different question: the key's box.
	_tip_if(not fresh and not note_read and not slips_puzzle.solved and lower.contains("retrieval_slips")
		and not lower.contains("count(") and not rows.is_empty(), "count")
	_tip_if(RegEx.create_from_string("=\\s*null").search(lower) != null, "null")
	# Every swipe: past the policy's cap of 20 rows.
	_tip_if(lower.contains("access_log") and full.get("rows", []).size() > TerminalPolicy.CAP, "log")
	_tip_if(lower.contains("access_log") and lower.contains("group by") and lower.contains("desc") and not lower.contains(Level3Data.NIGHT)
		and not rows.is_empty() and str(rows[0].get("room", "")) == "READING ROOM", "week")


## The clerk's near misses, checked on the whole result like the stations.
var depts_repeats := Puzzle.new("depts_repeats", "SELECT dept FROM catalogue WHERE room = 'STACKS'", ["dept"], false)
var depts_every := Puzzle.new("depts_every", "SELECT DISTINCT dept FROM catalogue", ["dept"], false)
var tally_rooms := _distinct(Puzzle.new("tally_rooms", "SELECT DISTINCT room FROM access_log", ["room"], false))


func _miss_if(id: String, text: String) -> void:
	if not misses_said.has(id):
		sync.event("_miss_line", [id, text])


## Every machine: SYSOP gives a near miss its reason, once.
func _miss_line(id: String, text: String) -> void:
	if misses_said.has(id):
		return
	misses_said[id] = true
	desk.print_line(TerminalUI.sysop(text))


func _tip_if(when: bool, id: String) -> void:
	if when and not tips_sent.has(id):
		sync.event("_tip", [id])


## Every machine: a line from SYSOP on the desk's screen (once per tip).
func _tip(id: String) -> void:
	if tips_sent.has(id):
		return
	tips_sent[id] = true
	desk.print_line(TerminalUI.sysop(TEXT["tip_" + id]))


## Every machine: a station's check passed. The clerk's departments and tally are
## solved by their whole result: each ticks its step on the clerk's case.
func _on_solved(id: String, _which: String) -> void:
	for p in puzzles():
		if p.id == id:
			p.solved = true
	if id in ["depts", "tally"]:
		Game.tick_step("duties", id)
		if duties_slot == id:
			_duties_next()
		_duties_check()
	_order_hints()


# --- The night clerk's case: three chores (R2-R29) -------------------------------

## Every machine: the clerk's case is on step `step`: its pieces, its query and,
## for the count, its slot.
func _duties_step(step: String) -> void:
	duties_slot = step
	var game := get_node("/root/Game")
	match step:
		"slips":
			game.set_pieces("duties", [SLIPS_PIECE, OPEN_PIECE], SLIPS_QUERY, DUTIES_STEPS)
			game.set_blank("duties", SLIPS_SLOT, NO_LINE, str(data.open_slips), {"column": "", "values": [str(data.open_slips)], "only": true})
		"depts":
			game.set_pieces("duties", [DISTINCT_PIECE, CATALOGUE_PIECE, STACKS_PIECE], DEPTS_QUERY, DUTIES_STEPS)
		"tally":
			game.set_pieces("duties", [LOG_PIECE, GROUP_PIECE], TALLY_QUERY, DUTIES_STEPS)


## Every machine: on to the first chore not done yet.
func _duties_next() -> void:
	var done := {}
	for st in Game.case_info("duties").get("steps", []):
		done[st.id] = st.done
	for st in DUTIES_STEPS:
		if not done.get(st.id, false):
			_duties_step(st.id)
			return
	duties_slot = ""


## Every machine: all three chores done closes the clerk's case.
func _duties_check() -> void:
	if slips_puzzle.solved and depts_puzzle.solved and tally_puzzle.solved:
		Game.open_case("duties", CASES.duties, ["retrieval_slips", "catalogue", "access_log"])
		Game.solve_case("duties", TEXT.duties_done)


## Every machine: the clipboard has been read: the clerk's case is open for the
## crew, and the chapters its papers bring can land, a quiet minute apart (M5).
func _open_duties() -> void:
	if Game.case_info("duties").get("open", false) and _beat_ms >= 0:
		return
	Game.open_case("duties", CASES.duties, ["retrieval_slips", "catalogue", "access_log"])
	_mark_beat()
	if sync.is_host():
		for k in _books.keys():
			_book_check(k)


## Every machine: the open slips' count is in the slot.
func _on_slips_found() -> void:
	if slips_puzzle.solved:
		return
	slips_puzzle.solved = true
	Game.tick_step("duties", "slips")
	_duties_next()
	_duties_check()
	_order_hints()


## Host: a paper brings back chapter `id` of Easy SQL: it waits for the clerk's
## case to open, and for a quiet minute since that or the last chapter (M5).
func _book_found(id: String) -> void:
	if not sync.is_host():
		return
	if not _books.has(id):
		_books[id] = "found"
	_book_check(id)


func _book_check(id: String) -> void:
	if not sync.is_host() or _books.get(id, "") != "found" or not Game.case_info("duties").get("open", false):
		return
	if _beat_ms >= 0:
		var left := pace_s - (Time.get_ticks_msec() - _beat_ms) / 1000.0
		if left > 0.0:
			get_tree().create_timer(left + 0.05, false).timeout.connect(_book_check.bind(id), CONNECT_ONE_SHOT)
			return
	_books[id] = "played"
	_beat_ms = Time.get_ticks_msec()  # the other chapter waits from now, here too
	sync.event("_book_huddle", [id])


## Every machine: a chapter of Easy SQL comes back into the crew's book (once per
## run), and fills the piece it explains. Nothing stops: the Shredder keeps listening.
func _book_huddle(id: String) -> void:
	_mark_beat()
	var game := get_node("/root/Game")
	match id:
		"easy_sql_distinct":
			game.collect_piece("duties", "distinct", "Easy SQL")
		"easy_sql_group_by":
			game.collect_piece("duties", "group_by", "Easy SQL")
			game.collect_piece("room", "group_by", "Easy SQL")
	var h := Huddle.of(self)
	if h:
		await h.run(id, Huddle.REMEMBERED)


func _mark_beat() -> void:
	_beat_ms = Time.get_ticks_msec()


# --- The room case: the room, then the badge (R32-R51) ------------------------------

## The cells beside a room that make it the room's answer: its count tonight (the
## same over the whole log: nobody goes in by day), or an EXECUTIVE box (M7, the
## click rules).
func room_also() -> Array:
	return [str(data.night_counts[data.host]), "EXECUTIVE"] + data.mercer_boxes


## Every machine: the room case is on step `step`.
func _room_step(step: String) -> void:
	room_slot = step
	var game := get_node("/root/Game")
	match step:
		"room":
			game.set_pieces("room", [LOG_PIECE, GROUP_PIECE, DATE_PIECE], ROOM_QUERY, ROOM_STEPS)
			game.set_blank("room", ROOM_SLOT, NO_LINE, data.host, {"column": "room", "values": [data.host], "also": room_also()})
		"badge":
			game.tick_step("room", "room")
			game.set_pieces("room", [LOG_PIECE], BADGE_QUERY % data.host, ROOM_STEPS)
			game.set_assemble("room", false)  # typed once something's hunting: the crew puts it together
			game.set_blank("room", BADGE_SLOT, NO_LINE, data.visitor_badge, {"column": "badge_id", "values": [data.visitor_badge]})
		"":
			game.tick_step("room", "room")
			game.tick_step("room", "badge")


## Every machine: Security's sheet has been read. The room's question is open. A
## room found before it (a click, the catalogue, a crank) answers it now (M7).
func _ask_room() -> void:
	if room_asked:
		return
	room_asked = true
	Game.open_case("room", CASES.room, ["access_log", "catalogue"])
	_todo("todo_room")
	if room_slot == "room" and cranked.get(data.host, false):
		Game.fill_blank("room")
		_on_room_found("crank")
	elif room_slot == "room":
		_room_from_catalogue()
	_order_hints()


## This player pointed at the room in a catalogue result holding only Mercer's
## boxes: that's the room's answer too (the click rules).
func _room_from_catalogue() -> void:
	var game := get_node("/root/Game")
	if room_slot != "room" or not game.case_info("room").get("open", false):
		return
	for f in game.found_cells:
		if str(f.column).to_lower() == "room" and str(f.value) == data.host and only_executive(str(f.query)):
			game._fill_from_cell("room", f)
			return


## Does `query` (run at the desk) give only rows of the EXECUTIVE boxes?
func only_executive(query: String) -> bool:
	if query == "" or not query.to_lower().contains("catalogue"):
		return false
	var res := db.execute(query)
	if not res.get("ok", false) or res.rows.is_empty():
		return false
	for r in res.rows:
		var shown := {}
		for k in r:
			shown[str(k).to_lower()] = "NULL" if r[k] == null else str(r[k])
		var like := rows_like("catalogue", shown)
		if like.is_empty() or like.any(func(b): return b.dept != "EXECUTIVE"):
			return false
	return true


## Every machine: the room is in the slot (or its door found behind the shelving).
## The notebook writes in how it was found, and the badge step is next.
func _on_room_found(how: String) -> void:
	if room_slot != "room":
		return
	visits_puzzle.solved = true
	if how == "visits":
		Game.add_clue("room", "The readers logged one room far more than any other tonight: %s." % data.host, "Records desk")
	elif how == "catalogue":
		mercer_puzzle.solved = true
		Game.add_clue("room", "Mercer's own boxes are filed in one side room: %s." % data.host, "Records desk")
	_room_step("badge")
	_order_hints()


## Every machine: the keyholder's badge is in the slot.
func _on_badge_found() -> void:
	if room_slot != "badge":
		return
	keyholder_puzzle.solved = true
	_room_step("")
	_order_hints()


# --- The key case: Mercer's question first, then the cart's (R52-R69) ---------------

## Every machine: the key case is on step `step`.
func _key_step(step: String) -> void:
	key_slot = step
	var game := get_node("/root/Game")
	match step:
		"pc":
			# The query on screen is his boot screen's, with no blanks: he wrote it out.
			game.set_pieces("key", [], PC_QUERY, KEY_STEPS)
			game.set_blank("key", PC_SLOT, NO_LINE, data.mercer_out[0], {"column": "box_id", "values": data.mercer_out})
		"cart":
			game.tick_step("key", "pc")
			game.set_pieces("key", [SLIPS_PIECE, FILLED_PIECE, NULL_PIECE], CART_QUERY, KEY_STEPS)
			game.set_assemble("key", false)  # typed under threat: the crew puts it together
			game.set_blank("key", CART_SLOT, NO_LINE, data.unreturned[0], {"column": "box_id", "values": data.unreturned})
		"":
			game.tick_step("key", "cart")


## Every machine: Mercer's note has been read. The key is on the cart, in one box.
func _note_read() -> void:
	note_read = true
	Game.open_case("key", CASES.key, ["retrieval_slips"])
	if not key_taken:
		_todo("todo_key_box")
	_update_cart()
	_order_hints()


## Every machine: `box` is named in the key case's current step. A step with two
## lines (or one or two on the cart) sets its next line until each is named.
func _on_box_named(step: String, box: String) -> void:
	if step != key_slot:
		return
	var game := get_node("/root/Game")
	match step:
		"pc":
			if pc_named.has(box):
				return
			pc_named.append(box)
			if pc_named.size() < data.mercer_out.size():
				_next_box(PC_SLOT, data.mercer_out, pc_named)
				return
			pc_puzzle.solved = true
			floppy.enabled = true  # "Take the floppy disk" (M6)
			# His PC says what a pulled slip reads.
			game.collect_piece("key", "status", "Mercer's PC")
			_key_step("cart")
		"cart":
			if cart_named.has(box):
				return
			cart_named.append(box)
			_update_cart()  # its own tape tears
			if cart_named.size() < data.unreturned.size():
				_next_box(CART_SLOT, data.unreturned, cart_named)
				return
			unreturned_puzzle.solved = true
			boxes_named = true
			_key_step("")
			game.solve_case("key", "The slips say which box nobody checked back in: %s." % ", ".join(data.unreturned))
	_order_hints()


## The key case's next line on this step, for the boxes not named yet. A line this
## player filled that the host hasn't heard yet stays as it is.
func _next_box(prompt: String, all: Array, named: Array) -> void:
	var game := get_node("/root/Game")
	var left := all.filter(func(b): return not named.has(b))
	var b: Dictionary = game.case_info("key").get("blank", {})
	if not b.is_empty() and str(b.filled) != "" and not named.has(str(b.filled)):
		return
	game.set_blank("key", prompt, NO_LINE, left[0], {"column": "box_id", "values": left})


## Whether a box on the returns cart can be opened: only once the desk has named
## it as never checked back in (each box its own tape). No key without the lock,
## the safe room and the IS NULL query.
func _box_openable(box_id: String) -> bool:
	return note_read and cart_named.has(box_id)


## Every machine: the tape comes off the boxes the desk named.
func _update_cart() -> void:
	for box_id in cart_boxes:
		var b: CartBox = cart_boxes[box_id]
		if b.tape:
			b.tape.visible = not b.openable()


# --- Pointing at cells ------------------------------------------------------------

## This player pointed at a cell that answers one of this floor's slots: tell the
## host. Each answer names its step (and a box, its box), so two crewmates
## answering the same thing at once count once.
func _on_answer_found(id: String) -> void:
	match id:
		"duties":
			sync.report_answer("duties@slips")
		"room":
			sync.report_answer("room@" + room_slot)
		"key":
			var box := str(Game.case_info("key").get("blank", {}).get("filled", ""))
			if box != "":  # a box, or nothing to say
				sync.report_answer("key@%s:%s" % [key_slot, box])


## Every machine: a crewmate's answer goes in everyone's slot, if it's still the
## step it answers (and, for a box, the box goes in).
func _crew_answered(id: String, peer: int) -> void:
	var case_id := id.get_slice("@", 0)
	var step := id.get_slice("@", 1).get_slice(":", 0)
	var current := {"duties": duties_slot, "room": room_slot, "key": key_slot}
	if id.contains("@") and current.get(case_id, "") != step:
		return
	if case_id == "key" and id.contains(":"):
		var b: Dictionary = Game.case_info("key").get("blank", {})
		var box := id.get_slice(":", 1)
		if box == "" or b.is_empty() or (str(b.filled) != "" and str(b.filled) != box) or (step == "pc" and pc_named.has(box)) or (step == "cart" and cart_named.has(box)):
			return
		if str(b.filled) == "":
			b.value = box
	super._crew_answered(case_id, peer)


## Host: a player put an answer in a slot, on the step it names.
func case_answered(answer: String, _peer: int) -> void:
	var case_id := answer.get_slice("@", 0)
	var step := answer.get_slice("@", 1).get_slice(":", 0)
	match case_id:
		"duties":
			if duties_slot == "slips" and not slips_puzzle.solved:
				sync.event("_on_slips_found")
		"room":
			if step == "room" and room_slot == "room":
				var f: Dictionary = _last_cell()
				sync.event("_on_room_found", ["catalogue" if str(f.get("query", "")).to_lower().contains("catalogue") else "visits"])
			elif step == "badge" and room_slot == "badge":
				sync.event("_on_badge_found")
		"key":
			if step == key_slot and answer.get_slice(":", 1) != "":
				sync.event("_on_box_named", [step, answer.get_slice(":", 1)])


## This machine's last pointed-at cell.
func _last_cell() -> Dictionary:
	var cells: Array = get_node("/root/Game").found_cells
	return cells[-1] if not cells.is_empty() else {}


## This player pointed at a cell that answers no slot: if it's in a row the slot
## is about, a pencil line under the blank says why (this player's notebook only).
func _on_cell_missed(column: String, value: String, row: Dictionary) -> void:
	var game := get_node("/root/Game")
	var shown := {}
	for k in row:
		shown[str(k).to_lower()] = "NULL" if row[k] == null else str(row[k])
	var col := column.to_lower()
	if not shown.has(col):
		shown[col] = value
	if _open_unsolved("duties") and duties_slot == "slips":
		var note := ""
		if not rows_like("retrieval_slips", shown).is_empty():
			note = SLIPS_ROW
		elif shown.size() == 1 and value.is_valid_int():
			note = SLIPS_OTHER
		if note != "":
			game.blank_miss("duties", note)
	if _open_unsolved("room") and room_slot == "room":
		if col == "room" and value == data.host and only_executive(str(_last_cell().get("query", ""))):
			_room_from_catalogue()
			return
		var note := _room_miss(col, value, shown)
		if note != "":
			game.blank_miss("room", note)
	if _open_unsolved("room") and room_slot == "badge":
		var swipes := rows_like("access_log", shown)
		if not swipes.is_empty():
			var note := BADGE_OTHER
			if col == "badge_id" and value == Level3Data.PATROL[0]:
				note = BADGE_PATROL
			elif col == "holder" and value == Level3Data.VISITOR:
				note = BADGE_HOLDER
			game.blank_miss("room", note)
	if _open_unsolved("key") and key_slot == "pc":
		var mine := rows_like("pulled", shown, pc_db)
		if not mine.is_empty():
			var note := PC_OTHER
			if col == "box_id" and mine.all(func(r): return r.status == "open"):
				note = PC_OPEN
			elif col == "box_id" and mine.all(func(r): return r.back_on != null):
				note = PC_BACK
			game.blank_miss("key", note)
	if _open_unsolved("key") and key_slot == "cart":
		var slips := rows_like("retrieval_slips", shown)
		if not slips.is_empty():
			var note := CART_OTHER
			if col == "box_id" and slips.all(func(r): return r.status == "open"):
				note = CART_OPEN
			elif col == "box_id" and slips.all(func(r): return r.returned_at != null):
				note = CART_BACK
			game.blank_miss("key", note)


func _open_unsolved(id: String) -> bool:
	var c: Dictionary = get_node("/root/Game").case_info(id)
	return c.get("open", false) and not c.get("solved", false)


## The pencil note for a missed cell on the room step, "" for none (R38-R41).
func _room_miss(col: String, value: String, shown: Dictionary) -> String:
	var counts := shown.keys().filter(func(k): return k != "room" and str(shown[k]).is_valid_int())
	if col == "room" and counts.is_empty() and not rows_like("access_log", shown).is_empty():
		return ROOM_SWIPE
	if col == "room" and not counts.is_empty():
		var n := int(shown[counts[0]])
		var whole: int = db.run_silent("SELECT COUNT(*) AS n FROM access_log WHERE room = '%s'" % value.replace("'", "''"))[0]["n"] if Level3Data.ROOMS.has(value) else -1
		if value == "READING ROOM" and n == whole:
			return ROOM_WHOLE
		if value != data.host and data.night_counts.has(value) and n == int(data.night_counts[value]):
			return ROOM_QUIET
	if shown.has("room") or not rows_like("access_log", shown).is_empty() or not rows_like("catalogue", shown).is_empty():
		return ROOM_OTHER
	return ""


## The rows of `table` (on `on`, the desk's database by default) that a result row
## showing `shown` (column -> value, lower-case names) could be: every shown column
## is the table's and holds that value. [] if a shown column isn't the table's.
func rows_like(table: String, shown: Dictionary, on: FacilityDB = null) -> Array:
	var from: FacilityDB = on if on else db
	var all := from.run_silent("SELECT * FROM %s" % table)
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


# --- Mercer's lock ---------------------------------------------------------------

## Every machine: a key went down on the push-button lock. Enter checks the code
## against the keyholder's badge; right, and the door is unlocked for good.
func _lock_key(key: String) -> void:
	if safe_unlocked:
		lock.show_text(TEXT.lock_open, ThemeUtil.GREEN)
		return
	if key != "E":
		lock.press(key)
		return
	if lock.take_code() != data.code:
		lock.show_text(TEXT.lock_wrong, ThemeUtil.RED)
		return
	safe_unlocked = true
	safe_door.locked = false
	lock.show_text(TEXT.lock_open, ThemeUtil.GREEN)
	# The room case is solved when Mercer's door opens (R34).
	if room_slot == "room":
		_on_room_found("lock")
	if room_slot == "badge":
		_on_badge_found()
	Game.open_case("room", CASES.room, ["access_log", "catalogue"])
	Game.solve_case("room", ROOM_SOLVED)


## Type a code on the lock and press Enter, key by key, as a player does.
func type_code(code: String, by: Node = null) -> void:
	var who: Node = by if by else player
	for k in code.split(""):
		if lock.keys.has(k):
			lock.keys[k].interact(who)
	lock.keys["E"].interact(who)


## Host only, and only when typing is loud: the typed lines at `terminal` changed
## (local keys at once, teammates' at the mirror's rate). Count the new characters
## and make a sound at the terminal after a burst of them.
func _on_typing(terminal: Terminal) -> void:
	var total := 0
	for text in terminal.typing.values():
		total += str(text).length()
	# Always keep up with the typed length, so turning the setting on mid-game
	# doesn't make a line already on screen into a burst.
	var t: Dictionary = _typed.get(terminal, {"len": 0, "count": 0, "since": 0})
	var now := Time.get_ticks_msec()
	if now - int(t.since) > TYPING_WINDOW * 1000.0:
		t.count = 0
	var added: int = total - int(t.len)
	t.len = total
	if added > 0 and typing_is_loud and sync.is_host():
		t.count = int(t.count) + added
		t.since = now
		if int(t.count) >= TYPING_BURST:
			t.count = 0
			noise.emit(terminal.global_position, TYPING_LOUDNESS)
	_typed[terminal] = t


# --- The side rooms' shelving ------------------------------------------------------

## Every machine: the crank in `room` was turned. The units roll toward the door and
## the aisle opens along the back wall. Loud: the whole floor hears it.
func _crank(room: String) -> void:
	if cranked.get(room, true):
		return
	cranked[room] = true
	cranks[room].enabled = false
	_wake()
	# The door behind the right room's shelving answers the room's step (R37).
	if room == data.host and room_slot == "room" and Game.case_info("room").get("open", false):
		Game.fill_blank("room")
		_on_room_found("crank")
	_order_hints()
	var back: Vector3 = SIDE_ROOMS[room].back
	for unit in shelving[room]:
		var tw := create_tween()
		tw.tween_property(unit, "position", unit.position - back * CRANK_TRAVEL, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	noise.emit(cranks[room].global_position, CRANK_LOUDNESS)


## Every machine: the pressure peak. The first crank wakes it (M1): the floor's
## one loud act starts the hunt.
func _wake() -> void:
	if shredder_awake:
		return
	shredder_awake = true
	hud.notice(TEXT.shredder_wakes, 6.0)
	if sync.is_host():
		shredder.wake()


## Is the aisle along `room`'s back wall open (wide enough to walk)?
func back_aisle_open(room: String) -> bool:
	return cranked.get(room, false)


# --- Mercer's room -------------------------------------------------------------------

func _enter_safe_room() -> void:
	if reached_safe:
		return
	reached_safe = true
	if world and not world.keep_loaded.has(wing_id):
		world.keep_loaded.append(wing_id)  # a hub: later floors come back here
	hud.notice(TEXT.found_room, 6.0)
	hud.todo("")  # the note on the cot sets the next one


func _on_floppy_taken(peer_id: int) -> void:
	floppy_taken = true
	floppy.enabled = false  # one disk
	if drive_light:
		drive_light.visible = false
	if peer_id == players.id_of(player):
		hud.notice(TEXT.floppy, 6.0)
	# Only whoever picked it up earns Mercer's first secret.
	sync.unlock_for([peer_id], "secret:mercer_floppy_1")


func _on_key_taken(peer_id: int) -> void:
	key_taken = true
	key_dock.enabled = false
	stair_out.locked = false
	prepare_next()  # floor 10 builds now, at the foot of the stairs
	var next: Node = world.wings.get("level_4") if world else null
	if next:
		walk_stairs(stair_out, next.stair_in, true, "_on_exit", TEXT.stairs_wait)
	if peer_id == players.id_of(player):
		hud.notice(TEXT.key, 5.0)
	_todo("todo_key")


# --- The way down -------------------------------------------------------------------

## Everyone is down the stairs: in the World, on 10's landing, and play moves to
## floor 10; on its own, on 18's stairs, and Field Notes leads on to 10.
func _on_exit() -> void:
	get_node("/root/Net").earn("achievement:floor_18", hud)
	if not player:
		return
	var next: Node = world.wings.get("level_4") if world else null
	if next:
		stairs.seal(Stairwell.of(stair_out))
		Game.completed_level = "level_3"
		Game.next_level = "level_4"
		finish_level("level_4")
		return
	if player.health <= 0.0:
		return
	player.input_locked = true
	await get_tree().create_timer(1.0).timeout
	Game.completed_level = "level_3"
	Game.next_level = "level_4"  # Field Notes' Continue: the next floor, in the building
	completed.emit()


func _on_completed() -> void:
	await hud.fade(true, 1.2)
	finish_level("field_notes")


func on_player_died() -> void:
	if reached_safe:
		# The safe room is the breather: you come to on Mercer's cot.
		var c := safe_room_box.get_center()
		player.respawn(global_transform * Transform3D(Basis(), Vector3(c.x, 0.1, c.z + 1.0)))
	else:
		player.respawn(spawn_point())


## Put task `key` (a TEXT key) on the job: its title and its details. "" ticks off the current one.
func _todo(key: String) -> void:
	if key == "":
		hud.todo("")
	else:
		hud.todo(TASK_TITLES[key], TEXT[key])
