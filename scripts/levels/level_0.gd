extends LevelBase
## Level 0: The Lobby. The IT van, Rourke's tour, the shredded memo, the walkie-talkies.
## Teaches SELECT, FROM and ORDER BY. Nothing here should look wrong yet:
## the players think this is an ordinary after-hours IT callout.

signal all_ready

var rourke: Rourke
var desk_terminal: Terminal
var shutter: Door
var walkies: ItemDock
var front_doors: Door
var visitor_log: ItemDock
## Visitor badges on the counter, one for each of the crew.
var badges: ItemDock
## Players ready up by pressing E on their seat-belt buckle. Co-op raises this to the
## number of connected players; solo play starts as soon as one is ready.
var players_needed := 1
## player -> the van seat they climb out of
var ready_players := {}
## Each seat: spawn transform, seat-belt buckle, which door it exits by, its handle, and the
## climb-out path in world space.
var van_seats: Array[Dictionary] = []
## Front van doors by side ("w", "e"): hinge pivot and swing angle.
var van_doors := {}
var side_door: Node3D
var _side_door_open := false
## Climbing out of the van moves the camera for the player, but
## the mouse can still look around a little from where it points.
const LOOK_YAW := 0.6
const LOOK_PITCH := 0.4
var _look_player: Player
var _look_offset := Vector2.ZERO
var _look_base := Vector2.ZERO
## The air return in the lobby's west wall: its grate comes off by hand, and the
## duct behind it leads to a forgotten closet (an optional find and a first crawl).
var vent_grate: Interactable
## The forgotten closet at the end of the duct (the room around the tape's shelf).
const VENT_CLOSET := AABB(Vector3(-20, -0.5, 1), Vector3(6, 3.1, 6))
var _intro_started := false
var tape: Interactable
## The dark east corridor's Hum.
var hum: Hum
## Optional trust beats Rourke helps with while the crew works on the memo.
var vending: Interactable
var ceiling_hatch: Interactable
## Host: Rourke is just waiting at the desk, so he can wander over to help.
var _rourke_free := false
## The crew has signed the visitor log (they can do it as soon as they are in).
var _signed_in := false
## Who has taken a walkie-talkie off the dock (peer id -> true). One each.
var _coffee_done := false
var _boost_done := false
## Host: bumped whenever Rourke's walk back to the desk should stop.
var _errand := 0
## Up to the server floor, at the end of the hall.
var elevator: Elevator
## The emergency stairs beside the lifts: locked after hours.
var stair_door: Door
## The elevator's doorway, in the elevator bank's east wall.
const LIFT_AT := Vector3(30, 0, 3)
## The visitor book's case page, opened by reading the book (optional).
const BOOK_CASE := "Who signed in last? The book's last page is gone."
## Each case's pieces (Game.set_pieces): what the crew finds on this floor to
## put its query together. Drafts for Augustine's word-for-word OK.
## A value piece's `blank` is its slot's name while it's missing, as its hint
## names it; only a table piece is `seen_in` its table (the column is the
## thinking step). The memo starts as the peek: its table, then run it. The
## scraps come out of order, and the sort and the column join it then.
const MEMO_PEEK_PIECES := [
	{"id": "table", "label": "The table", "value": "memo_fragments", "task": "Find the table the scans are saved in", "where": "Something about the scanner, on the front desk", "seen_in": "memo_fragments", "blank": "enter_table_name"},
]
const MEMO_PEEK_QUERY := "SELECT * FROM {table};"
const MEMO_PEEK_STEPS := [{"id": "peek", "text": "Run it at the front desk terminal"}]
## The scraps come back out of order: that's the next case, with the sort and the
## column of its own. The table is already in hand from the case before it.
const ORDER_PIECES := [
	MEMO_PEEK_PIECES[0],
	{"id": "column", "label": "The column that numbers the scraps", "value": "piece_no", "task": "Find the column that numbers the scraps", "where": "Also something about the scanner", "blank": "enter_column_name"},
	{"id": "order", "label": "The words that sort rows", "value": "ORDER BY", "task": "Find how to put rows in order", "where": "Someone's reminder, on the front desk"},
]
const ORDER_QUERY := "SELECT * FROM {table} {order} {column};"
const ORDER_STEPS := [{"id": "run", "text": "Run it at the front desk terminal"}]
## What to do about each case, in the imperative: the HUD and the top of the case
## page show these same words (drafts for Augustine's word-for-word OK).
const OBJ_MEMO := "Read what's left of Dr. Vale's memo on the front desk terminal"
const OBJ_ORDER := "Put the memo's scraps back in the order they were written"
const OBJ_CALLER := "Find out who called the office from ext. %d"
const OBJ_VISITOR := "Find who signed in last, now the book's last page is gone"
## The ground floor teaches the case board itself, so the first case says how it
## works and the papers it needs shine until they've been read.
const INTRO_CASE := "Your notebook keeps one case at a time. This is it: read it, find what it needs, then type the query at a terminal."
const INTRO_HUNT := "The words you need are written down somewhere out here. Anything worth reading has a shine on it until you've read it."
const INTRO_SHINE := "Press E to read it. What it tells you goes straight into your case."
## This floor's queries are all typed at the front desk.
const DESK_TERMINAL := "front desk terminal"
const CALLER_STEPS := [{"id": "row", "text": "Point at the caller's row and add it to your notebook"}]
const CALLER_QUERY := "SELECT name, {column} FROM {table};"
const CALLER_ROUTES := [{"id": "printout", "name": "The mailroom's printout"}]
const VISITOR_PIECES := [
	{"id": "table", "label": "The table", "value": "visitors", "task": "Find where every visitor is logged", "where": "The visitor book, on the front desk", "seen_in": "visitors", "blank": "enter_table_name"},
	{"id": "desc", "label": "Newest first", "value": "DESC", "task": "Find how to put the newest first", "where": "A reminder beside the visitor book"},
	{"id": "limit", "label": "Just the last few", "value": "LIMIT 5", "task": "Find how to keep only the last few", "where": "Another reminder beside the book"},
]
## Which column to sort by is the step being taught (.schema visitors), so it
## stays the hint's own blank.
const VISITOR_QUERY := "SELECT * FROM {table} ORDER BY enter_column_name {desc} {limit};"
var peek_puzzle := Puzzle.new("peek", "SELECT text FROM memo_fragments", ["text"], false, [
	"The shape of it:\n" +
	"    [color=#ffffff]SELECT * FROM enter_table_name;[/color]\n" +
	"  SELECT *                which columns to show (* means every column)\n" +
	"  FROM enter_table_name   which table to read them from\n" +
	"Replace enter_table_name with the table's name. It's handwritten on the ScanRight card.",
	"The ScanRight card lies on the desk, left of the keyboard. Step 2 has the table name written into its blank. " +
	"Or type .tables to list every table.",
	"Type this exactly and press Enter. Spelling matters, capitals don't:\n" +
	"    [color=#ffffff]SELECT * FROM memo_fragments;[/color]",
])
## Not a solution: the memo sorted biggest first (copying the ORDER BY sticky's DESC).
var memo_backwards := Puzzle.new("memo_backwards", "SELECT text FROM memo_fragments ORDER BY piece_no DESC", ["text"], true)
var memo_puzzle := Puzzle.new("memo", "SELECT text FROM memo_fragments ORDER BY piece_no", ["text"], true, [
	"The shape of it:\n" +
	"    [color=#ffffff]SELECT * FROM memo_fragments ORDER BY enter_column_name;[/color]\n" +
	"  SELECT *                    every column\n" +
	"  FROM memo_fragments         from the scraps table\n" +
	"  ORDER BY enter_column_name  sorted by a column, smallest first\n" +
	"Replace enter_column_name with the column that numbers the scraps.",
	"Step 4 of the ScanRight card says which column numbers each scrap. .schema memo_fragments lists every column.",
	"Type this exactly and press Enter:\n" +
	"    [color=#ffffff]SELECT * FROM memo_fragments ORDER BY piece_no;[/color]",
])
## Who placed the call: the work order's caller extension, looked up in the staff
## directory (Level0Data). Any query listing names beside extensions finds it.
var caller_puzzle: Puzzle
## Optional: the visitor log newest first shows Vale signed in and never left.
var visitor_puzzle: Puzzle
var visitor_top_one: Puzzle  # LIMIT 1: just the crew's own row, one short of Vale's
## This run's ground-floor data (Level0Data.build).
var data := {}
## Rourke has asked who called. The answer is Mercer's line, added to the
## notebook from the directory on the terminal or the mailroom's printout.
var caller_asked := false
## The caller's row (name and extension) has been on the desk terminal's screen.
var caller_listed := false
## SYSOP has said why a wrong directory row didn't fill the blank (once per run).
var caller_miss_said := false
signal caller_found
## This floor's clue papers, as [the paper, the case whose word it carries]: the
## ones for the case in hand shine until they're read (_shine_clue_papers).
var _clue_papers: Array = []
## INTRO_SHINE has been on screen.
var _shine_told := false
## The staff directory printout in the mailroom: the walking route to the caller.
var directory_printout: Document
## Host: Easy SQL chapters whose paper has been read: "found" waits for the puzzle
## before it, "played" has been held (_book_found).
var _books := {}
## Every machine: Rourke is talking the crew through the memo and the call, so a
## chapter found now waits until he's done.
var _rourke_briefing := false


func build() -> void:
	data = Level0Data.build(Game.run_seed)
	load_level_seed(data.sql)
	caller_puzzle = caller_puzzle_for(data.extension)
	visitor_puzzle = visitor_puzzle_for()
	visitor_top_one = visitor_top_one_for()
	var game := get_node("/root/Game")
	game.answer_found.connect(_on_answer_found)
	game.line_noted.connect(_on_line_noted)
	var carpet := Color(0.22, 0.2, 0.24)
	var wall := Color(0.62, 0.58, 0.5)
	# Lobby: x -8..8, z -7..7
	Greybox.room(geo, Vector3.ZERO, Vector3(16, 4, 14), {"floor": carpet, "wall": wall}, [
		{"wall": "e", "at": 3.0, "width": 2.0, "height": 3.0},
		{"wall": "s", "at": 0.0, "width": 3.2, "height": 2.6},
		{"wall": "n", "at": -6.5, "width": 1.6, "height": 2.6},  # to the north corridor, either side of the desk
		{"wall": "n", "at": 6.5, "width": 1.6, "height": 2.6},
		{"wall": "w", "at": 4.0, "width": 0.9, "height": 1.0},  # the air return, flush with the floor so you can crawl in
	])
	Sfx.mark_surface(geo.get_node("Floor"), "carpet")  # the lobby's
	Greybox.label(geo, Vector3(0, 3.0, -6.88), "HALCYON DATA SYSTEMS", 160, Color(0.15, 0.2, 0.35))
	Greybox.label(geo, Vector3(0, 2.55, -6.88), "Data you can trust.", 64, Color(0.25, 0.25, 0.3))
	# Front doors: Rourke lets the crew in, then they lock behind them.
	front_doors = Door.create(self, "LOBBY-FRONT", Vector3(0, 1.3, 6.95), Vector3(3.2, 2.6, 0.12), Color(0.25, 0.35, 0.4))
	front_doors.slide_axis = Vector3.RIGHT
	doors["LOBBY-FRONT"] = front_doors
	Greybox.label(geo, Vector3(0, 2.8, 6.85), "EXIT", 72, Color(0.8, 0.15, 0.1), 180)

	# Reception desk with side partitions: the only way behind it is over the desk.
	Greybox.box(geo, Vector3(0, 0.55, -1.0), Vector3(10, 1.1, 0.8), Color(0.42, 0.3, 0.22), "Desk")
	Greybox.box(geo, Vector3(-5.0, 1.1, -4.2), Vector3(0.15, 2.2, 5.6), Color(0.5, 0.55, 0.6), "PartitionW")
	Greybox.box(geo, Vector3(5.0, 1.1, -4.2), Vector3(0.15, 2.2, 5.6), Color(0.5, 0.55, 0.6), "PartitionE")
	Greybox.label(geo, Vector3(0, 1.3, -0.58), "RECEPTION", 64, Color(0.85, 0.8, 0.6))
	desk_terminal = Terminal.spawn(geo, Vector3(1.5, 1.1, -1.0), 0, "FRONT DESK", db, terminal_ui)
	desk_terminal.boot_lines = [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  FRONT DESK",
		"Visitor session opened 23:04.",
		"",
		"ScanRight: 1 shredded document saved, one row per scrap.",
		"Scans go in the table named on the ScanRight card (on the desk).",
		"To see every row of a table, type this and press Enter:",
		"",
		"    [color=#ffffff]SELECT * FROM [i]table_name[/i];[/color]",
		"",
		"Type .help for commands, .hint if you're stuck.",
	]
	peek_puzzle.case_id = "memo"
	memo_puzzle.case_id = "memo_order"
	desk_terminal.puzzles = [peek_puzzle, memo_puzzle, caller_puzzle, visitor_puzzle]
	desk_terminal.blanks = {"table_name": "table_name is a blank. the real name is handwritten on the ScanRight card."}
	desk_terminal.enabled = false
	desk_terminal.queried.connect(_on_desk_query)
	StickyNote.on_monitor(desk_terminal, "select_from")
	# Someone's reminder to themselves, left on the desk.
	var order_sticky := StickyNote.place(geo, Vector3(2.55, 1.102, -0.78), "order_by", false, 0.0, true)
	order_sticky.taken.connect(
		func(_p): get_node("/root/Game").collect_piece("memo_order", "order", "Sticky note on the front desk"))
	var order_note := Document.place(geo, Vector3(1.86, 1.102, -0.78), 0.0, "Sticky note", [{"text": "ORDER matters.", "hand": true}, {"text": "  - I.", "hand": true}], true, "sticky")
	order_note.clues = [
		{"case": "memo_order", "text": "\"ORDER matters.\" - I."},
	]
	# The scanner's quick-start card: the table name is handwritten in its blank.
	var scan_card := Document.place(geo, Vector3(0.75, 1.102, -0.75), 10.0, "ScanRight 3000 - Quick Start", [
		"Shredded? Torn? Chewed by the fax?",
		"ScanRight saves every scrap!",
		"",
		"1. Feed the scraps in, any order.",
		{"before": "2. Each scrap is saved as one row in a table of your choice: ", "filled": "memo_fragments", "after": "."},
		"3. The text column holds the words on each scrap.",
		"4. piece_no numbers each scrap by where it sat on the page, starting at 1.",
		"",
		{"text": "Front desk scanner. Don't feed it staples!! - IT", "hand": true},
	], true, "brochure", Vector2(0.15, 0.21))
	scan_card.pieces = [{"case": "memo", "piece": "table"}, {"case": "memo_order", "piece": "column"}]
	scan_card.clues = [
		{"case": "memo", "text": "The scanner saves each scrap as one row in the table memo_fragments."},
		{"case": "memo_order", "text": "piece_no numbers each scrap by where it sat on the page, starting at 1."},
	]
	# This floor is also the game's lesson in reading the room: whatever carries a
	# word the case in hand needs shines until this player has read it.
	_clue_papers = [[scan_card, "memo"], [scan_card, "memo_order"], [order_sticky, "memo_order"], [order_note, "memo_order"]]
	game.notebook_changed.connect(_shine_clue_papers)
	for pair in _clue_papers:
		if not pair[0].shine_seen.is_connected(_on_shine_seen):
			pair[0].shine_seen.connect(_on_shine_seen)
	# Everyone signs the log, and everyone takes a badge off the counter.
	_mesh(geo, Vector3(-1.5, 1.13, -0.8), Vector3(0.35, 0.05, 0.26), Color(0.92, 0.9, 0.82)).name = "VisitorLog"
	visitor_log = ItemDock.make(geo, Vector3(-1.5, 1.13, -0.8), Vector3(0.35, 0.05, 0.26), "Sign the visitor log")
	visitor_log.already = "You've signed in."
	Greybox.label(geo, Vector3(-1.5, 1.2, -0.66), "VISITOR LOG", 24, Color(0.15, 0.15, 0.2), 0)
	visitor_log.enabled = false
	visitor_log.taken.connect(_on_signed)
	_mesh(geo, Vector3(-0.6, 1.11, -0.8), Vector3(0.62, 0.02, 0.2), Color(0.2, 0.22, 0.3)).name = "BadgeTray"
	badges = ItemDock.make(geo, Vector3(-0.6, 1.15, -0.8), Vector3(0.62, 0.08, 0.22), "Take a visitor badge", "visitor_badge")
	badges.already = "Your visitor badge is clipped on."
	badges.add_boxes(6, 0.1, Vector3(0.07, 0.006, 0.1), Color(0.95, 0.95, 0.9), -0.02)
	badges.enabled = false
	badges.taken.connect(_on_badge_taken)
	Greybox.label(geo, Vector3(-0.6, 1.2, -0.66), "VISITORS", 20, Color(0.15, 0.15, 0.2), 0)
	# The book's own last page is gone; the visitors table still has it.
	var book := Document.place(geo, Vector3(-2.25, 1.102, -0.72), -10.0, "Visitor book", [
		"VISITOR BOOK - AFTER HOURS",
		"Sign in AND out. All visitors are also logged in visitors.",
		{"text": "Who tore the last page out?? - N.F.", "hand": true},
	], true, "note", Vector2(0.15, 0.2))
	game.set_pieces("last_visitor", VISITOR_PIECES, VISITOR_QUERY, [], true)
	book.pieces = [{"case": "last_visitor", "piece": "table"}]
	book.clues = [{"case": "last_visitor", "opens": BOOK_CASE, "tables": ["visitors"],
		"text": "The book's last page is torn out, but every visitor is also logged in the visitors table."}]
	# The night desk's own reminder beside the book: DESC, found before it's needed.
	var newest := Document.place(geo, Vector3(-2.62, 1.102, -0.95), 15.0, "Sticky note", [
		{"text": "Newest first =", "hand": true},
		{"text": "ORDER BY ... DESC", "hand": true},
		{"text": "  - N.F.", "hand": true},
	], true, "sticky")
	newest.clues = [{"case": "last_visitor", "text": "Newest first = ORDER BY ... DESC"}]
	newest.pieces = [{"case": "last_visitor", "piece": "desc"}]
	var last_few := Document.place(geo, Vector3(-2.95, 1.102, -1.15), -8.0, "Sticky note", [
		{"text": "Just the last few?", "hand": true},
		{"text": "...DESC LIMIT 5", "hand": true},
		{"text": "  - N.F.", "hand": true},
	], true, "sticky")
	last_few.clues = [{"case": "last_visitor", "text": "Just the last few? End the query with LIMIT 5: only the first 5 rows."}]
	last_few.pieces = [{"case": "last_visitor", "piece": "limit"}]
	# The book or N.F.'s stickies bring back Newest first (DESC, LIMIT), once the memo
	# has put ORDER BY to use.
	for d in [book, newest, last_few]:
		d.read_by.connect(func(_p): _book_found("easy_sql_4"))

	# A side table behind the desk with the walkie-talkies' charging dock on it.
	Greybox.box(geo, Vector3(-2.5, 0.68, -5.5), Vector3(1.2, 0.04, 0.6), Color(0.45, 0.35, 0.2), "TableCharger")
	for leg in [Vector3(-0.55, 0, -0.25), Vector3(0.55, 0, -0.25), Vector3(-0.55, 0, 0.25), Vector3(0.55, 0, 0.25)]:
		Greybox.box(geo, Vector3(-2.5, 0.33, -5.5) + leg, Vector3(0.05, 0.66, 0.05), Color(0.3, 0.3, 0.32), "TableChargerLeg")
	# The dock stays on the table when the radios are taken; the radios sit in it,
	# one for each of the crew (up to six).
	_mesh(geo, Vector3(-2.5, 0.73, -5.5), Vector3(0.9, 0.06, 0.26), Color(0.12, 0.12, 0.13)).name = "ChargingDock"
	# Optional: one each for whoever wants one. Spares turn up on later floors.
	walkies = ItemDock.walkies(geo, Vector3(-2.5, 0.8, -5.5))
	for radio in walkies.models:
		_mesh(radio, Vector3(0, 0.03, 0.021), Vector3(0.05, 0.04, 0.002), Color(0.35, 0.8, 0.4))  # charge light
	walkies.enabled = false
	# The west end of the counter is clear of the log and terminal: walking into it
	# vaults you over (Player.VAULT_MAX), from either side.

	# Waiting area chairs (cover, atmosphere)
	for x in [-6.0, -4.8, 4.8, 6.0]:
		Greybox.box(geo, Vector3(x, 0.25, 4.5), Vector3(0.9, 0.5, 0.9), Color(0.3, 0.12, 0.12), "Chair")
		Seat.create_at(geo, Vector3(x, 0.5, 4.5), 0.0, Vector2(0.8, 0.8))  # facing the coffee table
	Greybox.box(geo, Vector3(-5.4, 0.2, 2.8), Vector3(2.0, 0.4, 0.8), Color(0.35, 0.28, 0.2), "Table")

	# East hall to the elevator bank: x 8..24, z 2..4. Halfway along, an unlit
	# passage turns north into the dark east corridor.
	Greybox.room(geo, Vector3(16, 0, 3), Vector3(16, 3, 2), {"floor": Color(0.3, 0.3, 0.3), "wall": wall}, [
		{"wall": "w", "at": 0.0, "width": 2.0, "height": 3.0},
		{"wall": "e", "at": 0.0, "width": 1.8, "height": 2.4},  # into the elevator bank
		{"wall": "n", "at": 2.0, "width": 2.0, "height": 2.6},  # the dark passage
	])
	Greybox.label(geo, Vector3(23.88, 2.72, 3), "ELEVATORS  >", 64, Color(0.7, 0.1, 0.1), -90)
	shutter = add_door("LOBBY-SHUTTER", Vector3(11, 1.5, 3), Vector3(0.15, 3.0, 2.0))
	# The elevator bank's door is an ordinary one: Rourke opens it, holds it, and it
	# swings shut behind the crew.
	exit_door = add_door("LOBBY-HALL-END", Vector3(23.9, 1.2, 3), Vector3(0.15, 2.4, 1.8)).make_hinged(Vector3(0, 0, -0.9), 90.0)
	exit_door.locked = true  # a badge door: only Rourke opens it
	_build_ground_floor(wall)

	# The vent in the west wall leads to a forgotten storage closet: x -14..-8, z 3.5..4.5 duct
	Traversal.vent(geo, Vector3(-8, 0.0, 4), Vector3(-14, 0.0, 4), Vector2(0.9, 0.95))
	vent_grate = Interactable.create(self, Vector3(-7.96, 0.5, 4), Vector3(0.05, 0.95, 0.9), "Pull the grate off the air return", Color(0.55, 0.56, 0.58))
	vent_grate.name = "VentGrate"
	for i in 6:  # louvres
		var louvre := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.02, 0.05, 0.86)
		louvre.mesh = lm
		louvre.material_override = Greybox.mat(Color(0.3, 0.3, 0.32))
		louvre.position = Vector3(0.03, -0.38 + i * 0.15, 0)
		vent_grate.add_child(louvre)
	vent_grate.used.connect(func(_p): sync.event("_on_vent_grate"))
	Greybox.room(geo, Vector3(-17, 0, 4), Vector3(6, 2.6, 6), {"floor": Color(0.2, 0.2, 0.2), "wall": Color(0.4, 0.38, 0.33)}, [
		{"wall": "e", "at": 0.0, "width": 0.9, "height": 1.0},
	])
	Greybox.box(geo, Vector3(-19.5, 0.9, 4), Vector3(0.8, 1.8, 3), Color(0.35, 0.35, 0.35), "Shelf")
	Greybox.label(geo, Vector3(-19.05, 1.4, 4),
		"THE HALCYON LEDGER - March 1994\nFOUNDER OUSTED OVER 'WARDEN' PLAN\nHarold Mercer, who built Halcyon from a garage,\nwas removed by the board after refusing to let an\nautomated system run the campus. 'You don't hand\nthe keys to something that can't be locked out,'\nhe told staff on his last day.",
		26, Color(0.9, 0.88, 0.8), 90)
	tape = Interactable.create(geo, Vector3(-19.3, 1.88, 5.0), Vector3(0.3, 0.12, 0.2), "Play the cassette", Color(0.12, 0.12, 0.12))
	tape.used.connect(func(_p): sync.event("_on_tape"))
	var closet_light := Greybox.ceiling_light(geo, Vector3(-17, 2.6, 4), 5.0, 0.9)
	FlickerLight.attach(closet_light, 0.35)

	# Lights. An ordinary, well-lit office lobby: every tube works, nothing flickers.
	# The first thing that looks wrong should be Rourke himself, in Server Room A.
	var office := Color(1.0, 0.95, 0.86)
	for p in [Vector3(-4, 4, -4), Vector3(4, 4, -4), Vector3(-4, 4, 1.5), Vector3(4, 4, 1.5), Vector3(-4, 4, 5), Vector3(4, 4, 5)]:
		add_light("lobby", p, 9.0, 1.4, office)
	add_light("hall", Vector3(13, 3, 3), 6.0, 1.1, office)
	add_light("hall", Vector3(20, 3, 3), 6.0, 1.1, office)

	_build_parking_lot()
	_build_van(Vector3(2, 0, 16.6))

	rourke = Rourke.new()
	rourke.name = "Rourke"
	add_child(rourke)
	# Already waiting outside the front doors when the van pulls up.
	rourke.position = ROURKE_OUTSIDE
	rourke.rotation.y = PI  # looking out at the lot
	spawn = global_transform.affine_inverse() * van_seats[seat_for(0)].spawn  # the host's own van seat
	DressLevel0.apply(self)  # furniture and materials (Graphics thread)


func net_setup() -> void:
	sync.replicate(rourke, rourke.sync_properties())


## Brighter and clearer than the rest of the building: nothing looks wrong yet.
func apply_environment(env: Environment) -> void:
	env.ambient_light_energy = 0.3
	env.fog_density = 0.01


## The car park in front of the building, at night.
func _build_parking_lot() -> void:
	var asphalt := Color(0.12, 0.12, 0.13)
	var facade := Color(0.5, 0.48, 0.44)
	# Lot: x -20..24, z 7..28, fenced on three sides; the building closes the fourth.
	Greybox.box(geo, Vector3(2, -0.1, 17.5), Vector3(44, 0.2, 21), asphalt, "Asphalt")
	Greybox.box(geo, Vector3(-20, 1.5, 17.5), Vector3(0.2, 3, 21), Color(0.2, 0.22, 0.2), "FenceW")
	Greybox.box(geo, Vector3(24, 1.5, 17.5), Vector3(0.2, 3, 21), Color(0.2, 0.22, 0.2), "FenceE")
	Greybox.box(geo, Vector3(2, 1.5, 28), Vector3(44, 3, 0.2), Color(0.2, 0.22, 0.2), "FenceS")
	# Building front, with a gap for the doors and a canopy over them.
	Greybox.box(geo, Vector3(-10.8, 3, 7.25), Vector3(18.4, 6, 0.3), facade, "Facade")
	Greybox.box(geo, Vector3(12.8, 3, 7.25), Vector3(22.4, 6, 0.3), facade, "Facade")
	Greybox.box(geo, Vector3(0, 4.3, 7.25), Vector3(3.2, 3.4, 0.3), facade, "Facade")
	Greybox.box(geo, Vector3(0, 3.0, 8.5), Vector3(5, 0.2, 2.2), Color(0.3, 0.3, 0.32), "Canopy")
	Greybox.label(geo, Vector3(0, 4.9, 7.42), "HALCYON DATA SYSTEMS", 200, Color(0.75, 0.8, 0.9))
	Greybox.label(geo, Vector3(3.2, 1.6, 7.42), "Visitors after 18:00:\nplease wait for your escort.", 36, Color(0.9, 0.9, 0.85))
	var porch := Greybox.ceiling_light(geo, Vector3(0, 2.9, 8.5), 7.0, 1.2, Color(1.0, 0.95, 0.86))
	porch.name = "PorchLight"
	# Painted bays and two sodium lamps.
	for x in [-6.0, -2.0, 6.0, 10.0]:
		Greybox.panel(geo, Vector3(x, 0.01, 16.6), Vector3(0.12, 0.01, 5), Color(0.8, 0.8, 0.7))
	Greybox.panel(geo, Vector3(2, 0.01, 8.6), Vector3(44, 0.01, 2.6), Color(0.35, 0.35, 0.34))  # sidewalk
	for x in [-8.0, 12.0]:
		Greybox.box(geo, Vector3(x, 2.5, 20), Vector3(0.2, 5, 0.2), Color(0.25, 0.25, 0.25), "LampPost")
		Greybox.panel(geo, Vector3(x, 5.0, 20), Vector3(0.8, 0.12, 0.4), Color(1.0, 0.75, 0.45), 3.0)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 4.7, 20)
		lamp.omni_range = 14.0
		lamp.light_energy = 1.3
		lamp.light_color = Color(1.0, 0.72, 0.42)
		geo.add_child(lamp)


## The crew's IT van, nose to the building. It seats six: two in front and a bench
## of four in the back. Each player readies up by pressing E on their own seat-belt
## buckle; front-seat players climb out of their front door, the rest out of the
## sliding side door. `center` is the middle of the van at ground level.
func _build_van(center: Vector3) -> void:
	var white := Color(0.86, 0.86, 0.83)
	var floor_y := center.y + 0.5
	var cab := Vector3(center.x, floor_y, center.z)
	# Body: a hollow box you can stand in. x center±1.3, z center±2.2.
	Greybox.room(geo, cab, Vector3(2.6, 2.1, 4.4), {"floor": Color(0.2, 0.2, 0.22), "wall": white, "ceiling": white}, [
		{"wall": "n", "at": 0.0, "width": 2.3, "height": 1.95, "bottom": 0.85},  # windscreen
		{"wall": "w", "at": -1.5, "width": 0.9, "height": 1.9},  # driver door
		{"wall": "e", "at": -1.5, "width": 0.9, "height": 1.9},  # passenger door
		{"wall": "e", "at": 0.1, "width": 1.3, "height": 1.9},  # sliding side door
	])
	# The windscreen is glass: you can see through it, not climb through it.
	var glass := StaticBody3D.new()
	glass.name = "Windscreen"
	glass.position = cab + Vector3(0, 0.85 + 1.95 / 2.0, -2.2)
	var glass_shape := CollisionShape3D.new()
	var glass_box := BoxShape3D.new()
	glass_box.size = Vector3(2.3, 1.95, 0.06)
	glass_shape.shape = glass_box
	glass.add_child(glass_shape)
	geo.add_child(glass)
	Greybox.box(geo, center + Vector3(0, 0.2, 0), Vector3(2.7, 0.2, 4.7), Color(0.15, 0.15, 0.15), "Chassis")
	Greybox.box(geo, center + Vector3(0, 0.95, -2.65), Vector3(2.6, 0.9, 0.9), white, "Bonnet")
	for dx in [-1.0, 1.0]:
		for dz in [-1.7, 1.5]:
			Greybox.box(geo, center + Vector3(dx * 1.15, 0.25, dz), Vector3(0.3, 0.5, 0.7), Color(0.05, 0.05, 0.05), "Wheel")
	Greybox.label(geo, center + Vector3(-1.42, 1.7, 0.4), "BYTE-RIGHT IT SERVICES\nWe fix what's broken.", 60, Color(0.1, 0.3, 0.6), -90.0)
	Greybox.label(geo, center + Vector3(1.42, 1.7, 1.5), "BYTE-RIGHT\nIT SERVICES", 50, Color(0.1, 0.3, 0.6), 90.0)
	# Inside: dashboard, the job ticket on the equipment rack, a dome light.
	Greybox.panel(geo, cab + Vector3(0, 0.75, -2.05), Vector3(2.4, 0.2, 0.3), Color(0.12, 0.12, 0.13))
	Greybox.box(geo, cab + Vector3(-0.6, 0.6, 1.85), Vector3(1.0, 1.2, 0.6), Color(0.3, 0.3, 0.32), "Rack")
	Greybox.label(geo, cab + Vector3(-0.6, 0.9, 1.54),
		"WORK ORDER %s\nHalcyon Data Systems\nAfter hours, 23:00\nReported: database problem.\nContact: D. Rourke, facilities.\nCaller: %s" % [get_node("/root/Game").ticket_number(), Level0Data.caller_line(get_node("/root/Game").run_seed)], 22, Color(0.95, 0.95, 0.9), 180)
	var dome := OmniLight3D.new()
	dome.position = cab + Vector3(0, 1.9, 0)
	dome.omni_range = 3.5
	dome.light_energy = 0.6
	dome.light_color = Color(1.0, 0.9, 0.7)
	geo.add_child(dome)

	# Front doors hinge at their front edge and swing outward.
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = cab + Vector3(1.3 * side, 0, -1.95)
		add_child(pivot)
		Greybox.box(pivot, Vector3(0, 0.95, 0.45), Vector3(0.1, 1.9, 0.9), white, "VanDoor")
		van_doors["w" if side < 0 else "e"] = {"pivot": pivot, "swing": deg_to_rad(90.0 * side)}
	# The side door slides back along the outside of the van.
	side_door = Node3D.new()
	side_door.position = cab + Vector3(1.3, 0, 0.1)
	add_child(side_door)
	Greybox.box(side_door, Vector3(0, 0.95, 0), Vector3(0.1, 1.9, 1.3), white, "SideDoor")

	# Seats: two in front (driver, passenger), then the rear bench left to right.
	var seats := [
		[Vector3(-0.55, 0, -1.3), "w"], [Vector3(0.55, 0, -1.3), "e"],
		[Vector3(-0.99, 0, 0.7), "side"], [Vector3(-0.33, 0, 0.7), "side"],
		[Vector3(0.33, 0, 0.7), "side"], [Vector3(0.99, 0, 0.7), "side"],
	]
	var rear := 0
	for seat in seats:
		var at: Vector3 = cab + seat[0]
		Greybox.panel(geo, at + Vector3(0, 0.25, 0.1), Vector3(0.55, 0.5, 0.5), Color(0.15, 0.15, 0.18))
		var buckle := Interactable.create(self, at + Vector3(0.15, 0.3, -0.38), Vector3(0.08, 0.06, 0.08), "Unbuckle (ready up)", Color(0.85, 0.1, 0.1))
		# A real seat on the cushion, as on the garage couch: the crew rides sitting up
		# on it, not on the van floor. Nobody looks at it to sit (they're belted in),
		# so it has no aim box to get in the way of the buckle.
		var cushion := Seat.create_at(geo, at + Vector3(0, 0.5, 0.1), 0.0, Vector2(0.55, 0.5))
		cushion.name = "VanSeat"
		for c in cushion.get_children():
			if c is CollisionShape3D:
				c.disabled = true
		var entry := {
			"spawn": global_transform * Transform3D(Basis(), at + Vector3(0, 0.05, 0)),
			"buckle": buckle,
			"exit": seat[1],
			"seat": cushion,
		}
		var handle_side := -1.0 if seat[1] == "w" else 1.0
		var handle_z := -0.45 if seat[1] == "side" else -1.15
		entry["handle"] = to_global(cab + Vector3(1.22 * handle_side, 0.95, handle_z))
		if seat[1] == "side":
			entry["inside"] = to_global(cab + Vector3(0.95, 0.05, 0.1))
			entry["outside"] = to_global(Vector3(cab.x + 2.3, center.y + 0.05, cab.z + 0.1 + (rear - 1.5) * 0.8))
			rear += 1
		else:
			var side := -1.0 if seat[1] == "w" else 1.0
			entry["inside"] = to_global(cab + Vector3(1.05 * side, 0.05, -1.5))
			entry["outside"] = to_global(Vector3(cab.x + 2.3 * side, center.y + 0.05, cab.z - 1.8))
		van_seats.append(entry)
		buckle.used.connect(ready_up.bind(van_seats.size() - 1))


## A player pressed E on a seat-belt buckle. Runs on the host (clients' presses are
## forwarded); once everyone is ready, every machine climbs its own player out.
func ready_up(p: Node, seat_index: int) -> void:
	if ready_players.has(p) or _intro_started or ready_players.values().has(seat_index):
		return
	ready_players[p] = seat_index
	players_needed = maxi(players_needed, players.count())
	if ready_players.size() >= players_needed:
		var seats := []
		for body in ready_players:
			seats.append([players.id_of(body), ready_players[body]])
		sync.event("_on_crew_ready", [seats])
	else:
		sync.event("_on_waiting_for_crew", [seat_index, ready_players.size(), players_needed])


func _on_waiting_for_crew(seat_index: int, ready_count: int, needed: int) -> void:
	van_seats[seat_index].buckle.enabled = false
	hud.notice("Ready. Waiting for your team (%d/%d)" % [ready_count, needed], 600.0)


## Everyone is ready. `seats` is [peer id, seat] in the order they readied. Each
## machine climbs out the players it controls and opens the doors for the others.
func _on_crew_ready(seats: Array) -> void:
	_intro_started = true
	var rear := 0
	for pair in seats:
		var seat: Dictionary = van_seats[pair[1]]
		seat.buckle.enabled = false
		var order := rear if seat.exit == "side" else 0
		if seat.exit == "side":
			rear += 1
		var body = _body_in_seat(pair[0], pair[1])
		if body is Player:
			climb_out(body, seat, order)
		else:
			_open_door_for(seat, order)
	all_ready.emit()


## The Player in a seat if this machine controls it: its own, or (on the host)
## any extra local Player that readied up there.
func _body_in_seat(peer_id: int, seat_index: int) -> Node:
	if peer_id == multiplayer.get_unique_id():
		return player
	for body in ready_players:
		if ready_players[body] == seat_index and not body is PlayerPuppet:
			return body
	return null


## A teammate climbs out on their own machine; here we just see their door open.
func _open_door_for(seat: Dictionary, order: int) -> void:
	if order > 0:
		await get_tree().create_timer(0.8 * order, false).timeout
	var tw := create_tween()
	tw.tween_interval(0.5)
	if seat.exit == "side":
		if _side_door_open:
			return
		_side_door_open = true
		tw.tween_property(side_door, "position", side_door.position + Vector3(0.15, 0, 1.3), 0.7).set_trans(Tween.TRANS_QUAD)
	else:
		var door: Dictionary = van_doors[seat.exit]
		tw.tween_property(door.pivot, "rotation:y", door.swing, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.5)
		tw.tween_property(door.pivot, "rotation:y", 0.0, 0.4).set_trans(Tween.TRANS_QUAD)


## Open the door by this seat and step down onto the tarmac, facing the building.
## The camera looks at the door handle, then out of the door, and the mouse can still
## look around a little. Rear-bench players leave one after another through the side door.
func climb_out(p: Player, seat: Dictionary, order: int = 0) -> void:
	_hold_camera(p)
	if order > 0:
		await get_tree().create_timer(0.8 * order, false).timeout
	var eye: Vector3 = p.global_position + Vector3.UP * p.head.position.y  # sat on the cushion
	var start := _view(p)
	var at_handle := _view_at(eye, seat.handle, start.x)
	var out_yaw := PI / 2 if seat.exit == "w" else -PI / 2
	var out := Vector2(_near(at_handle.x, out_yaw), -0.1)
	var ahead := Vector2(_near(out.x, 0.0), 0.0)
	var tw := create_tween()
	if seat.exit == "side" and _side_door_open:
		out = Vector2(_near(start.x, out_yaw), -0.1)
		ahead = Vector2(_near(out.x, 0.0), 0.0)
		tw.tween_method(_aim.bind(p), start, out, 0.5).set_trans(Tween.TRANS_SINE)
	else:
		tw.tween_method(_aim.bind(p), start, at_handle, 0.5).set_trans(Tween.TRANS_SINE)
		if seat.exit == "side":
			_side_door_open = true
			tw.tween_property(side_door, "position", side_door.position + Vector3(0.15, 0, 1.3), 0.7).set_trans(Tween.TRANS_QUAD)
		else:
			var door: Dictionary = van_doors[seat.exit]
			tw.tween_property(door.pivot, "rotation:y", door.swing, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_aim.bind(p), at_handle, out, 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(p, "global_position", seat.inside, 0.7)
	tw.tween_property(p, "global_position", seat.outside, 0.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_method(_aim.bind(p), out, ahead, 0.8).set_trans(Tween.TRANS_SINE)
	if seat.exit != "side":
		tw.tween_property(van_doors[seat.exit].pivot, "rotation:y", 0.0, 0.4).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	if is_instance_valid(p):
		_release_camera(p)


## A scripted move takes over the player's body and camera.
func _hold_camera(p: Player) -> void:
	p.input_locked = true
	p.velocity = Vector3.ZERO
	p.process_mode = Node.PROCESS_MODE_DISABLED
	if p == player:
		_look_player = p
		_look_offset = Vector2.ZERO
		_look_base = _view(p)


## Sat in the van seat, strapped in: the crew rides in on the seat's cushion with
## the view and the body of someone sitting down, and Space and Z don't get them out
## of it (Player.sit_held). The seat is the one this player spawned at.
func _belt_in() -> void:
	for i in 60:
		await get_tree().physics_frame
		if not is_instance_valid(player) or not player.seated or player.is_sitting():
			return  # already down, or out of the van before they ever sat
		if player.sit(_van_seat_near(player.global_position)):
			player.sit_held = true
			return


## The van seat closest to `at`.
func _van_seat_near(at: Vector3) -> Seat:
	var best: Seat = null
	for entry in van_seats:
		var s: Seat = entry.seat
		if best == null or s.global_position.distance_to(at) < best.global_position.distance_to(at):
			best = s
	return best


func _release_camera(p: Node) -> void:
	p.process_mode = Node.PROCESS_MODE_INHERIT
	p.input_locked = false
	p.seated = false  # out of the van
	p.sit_held = false  # the belt's off: on their feet on the tarmac
	if p.is_sitting():
		var at: Vector3 = p.global_position  # out on the tarmac: standing up off the seat doesn't put them back by it
		p.stand_up(true)
		p.global_position = at
	if p == _look_player:
		_look_player = null
		_look_offset = Vector2.ZERO


## Where the camera points: x is body yaw, y is head pitch.
func _view(p: Player) -> Vector2:
	return Vector2(p.rotation.y, p.head.rotation.x)


## The view from `eye` looking at `target`, turning the short way from `from_yaw`.
func _view_at(eye: Vector3, target: Vector3, from_yaw: float) -> Vector2:
	var d := target - eye
	return Vector2(_near(from_yaw, atan2(-d.x, -d.z)), atan2(d.y, Vector2(d.x, d.z).length()))


func _near(from_yaw: float, to_yaw: float) -> float:
	return from_yaw + angle_difference(from_yaw, to_yaw)


## Point the camera, plus however far the local player has looked away with the mouse.
func _aim(v: Vector2, p: Player) -> void:
	var o := _look_offset if p == _look_player else Vector2.ZERO
	p.rotation.y = v.x + o.x
	p.head.rotation.x = clampf(v.y + o.y, -1.45, 1.45)
	if p == _look_player:
		_look_base = v


func _unhandled_input(event: InputEvent) -> void:
	if _look_player and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_offset.x = clampf(_look_offset.x - event.relative.x * Player.MOUSE_SENS, -LOOK_YAW, LOOK_YAW)
		_look_offset.y = clampf(_look_offset.y - event.relative.y * Player.MOUSE_SENS, -LOOK_PITCH, LOOK_PITCH)
		_aim(_look_base, _look_player)


## Where a player sits at the start.
func seat_spawn(index: int) -> Transform3D:
	return van_seats[index].spawn


## Player number `index` (0 = host) starts in their own van seat.
func player_spawn(index: int) -> Transform3D:
	return seat_spawn(seat_for(index))


## The seat player number `index` took in the van at home base (Game.van_seating),
## so nobody changes seats on the way. Without one (a game started here), seats
## go in order: the driver's first.
func seat_for(index: int) -> int:
	var ids := NetPlayers.ids_for(multiplayer)
	var seating: Array = get_node("/root/Game").van_seating
	var at := seating.find(ids[index]) if index < ids.size() else -1
	return at if at >= 0 and at < van_seats.size() else index % van_seats.size()


func start() -> void:
	player.flashlight.visible = false  # the lights are on; nobody needs a torch yet
	player.seated = true  # belted in until they unbuckle
	hud.notice("Look down at your seat belt and press E to unbuckle when you're ready", 600.0)
	_belt_in()
	_dispatch_chatter()
	if not _intro_started:
		await all_ready
	await get_tree().create_timer(2.0, false).timeout
	hud.todo("Meet our contact at the front doors")
	# Co-op: triggers and Rourke run on the host, so every machine waits on gates.
	var approach := Trigger.create(self, Vector3(0, 1, 11.5), Vector3(16, 2, 2))
	await sync.gate("approach", approach.entered)

	# Rourke is waiting outside: he greets the crew on the steps, then takes them in.
	_set_front_doors_locked(false)
	# Sign in and take a badge whenever you reach the desk, no waiting on Rourke.
	visitor_log.enabled = true
	badges.enabled = true
	badges.stock(players.count())
	_watch_nearest()
	await hud.lines(["l0_greet_1", "l0_greet_3", "l0_greet_4"])
	rourke.watch = null
	# The whole lobby, not a strip by the door: whoever follows Rourke first walks
	# on to the desk, and a strip they've left wouldn't count them.
	var inside := Trigger.create(self, Vector3(0, 1, 0), Vector3(15.6, 2, 13.6))
	rourke.walk_to(Vector3(-0.5, 0, 0.6))
	hud.todo("Follow Rourke to the front desk")
	inside.require_all = true
	inside.waiting.connect(func(n, total): sync.team_notice("Waiting for everyone to come inside (%d/%d)" % [n, total]))
	await sync.gate("inside", inside.entered)
	spawn = Transform3D(Basis(), Vector3(0, 0.1, 5.6))
	# The building's PA greets everyone who walks in, and Rourke apologises for it.
	await get_tree().create_timer(0.8, false).timeout
	await hud.lines(["l0_pa_1", "l0_pa_2"])
	await sync.gate("rourke_at_desk", func():
		if rourke.state == Rourke.State.WALK:
			await rourke.arrived)
	# Only once Rourke is through too: shutting the doors on him would strand him.
	_set_front_doors_locked(true)
	_watch_nearest()
	_checkin_todo()
	if not _checked_in_all():
		hud.lines(["l0_greet_2", "l0_signin", "l0_badges"])  # not awaited: the log works while he talks
	await sync.gate("signed_in", func():
		while not _checked_in_all():
			await get_tree().create_timer(0.2, false).timeout)
	_signed_in = true
	visitor_log.enabled = false
	badges.enabled = false
	hud.todo("")
	await Huddle.of(self).run("easy_sql_1")  # flashback: the garage, the book's first query
	# The terminal is ready at once: nobody waits on Rourke to finish talking.
	desk_terminal.enabled = true
	_rourke_free = true
	# The walkie-talkies on the charger are there for whoever wants one.
	walkies.enabled = true
	walkies.stock(players.count())
	hud.lines(["l0_tour_1", "l0_tour_2", "l0_desk_1", "l0_desk_2"])
	hud.todo(OBJ_MEMO)
	var game := get_node("/root/Game")
	game.open_case("memo", "What does Dr. Vale's shredded memo say?", ["memo_fragments"], OBJ_MEMO)
	game.set_pieces("memo", MEMO_PEEK_PIECES, MEMO_PEEK_QUERY, MEMO_PEEK_STEPS)
	# The crew's first case, so the page says how a case works and the room says
	# which things are worth reading.
	game.set_case_note("memo", INTRO_CASE, INTRO_HUNT, DESK_TERMINAL)
	_shine_clue_papers()


## Whatever carries a word the case in hand still needs: it shines until this
## player reads it (Interactable.shine), which is how the ground floor teaches that
## the answers are lying around the room. Papers already read stay as they are.
func _shine_clue_papers() -> void:
	var on: String = get_node("/root/Game").current_case()
	for pair in _clue_papers:
		if pair[1] == on and is_instance_valid(pair[0]):
			pair[0].shine()


## The first shining paper this player looks at: what the shine is for, on screen.
func _on_shine_seen(_player: Node) -> void:
	if not _shine_told:
		_shine_told = true
		hud.notice(INTRO_SHINE, 8.0)


## Host: everyone has signed the log and taken a badge.
func _checked_in_all() -> bool:
	var n := players.count()
	return visitor_log.taken_by.size() >= n and badges.taken_by.size() >= n


## Someone signed the visitor log: on every machine.
func _on_signed(id: int) -> void:
	if id == players.id_of(player):
		hud.notice("Signed in: BYTE-RIGHT IT SERVICES, 23:04", 4.0)
	_checkin_progress()


## Someone took a badge off the counter: on every machine. Numbered by who took it.
func _on_badge_taken(id: int) -> void:
	if id == players.id_of(player):
		Game.visitor_badge_no = "VIS-%02d" % badges.taken_by.size()
		hud.notice("Visitor badge %s clipped on." % Game.visitor_badge_no, 4.0)
	_checkin_progress()


## What this player still has to do at the desk.
func _checkin_todo() -> void:
	var me := players.id_of(player)
	var signed := visitor_log.has_taken(me)
	var badged := badges.has_taken(me)
	if signed and badged:
		hud.todo("" if _checked_in_all() else "Wait for everyone to sign in and take a badge")
	elif signed:
		hud.todo("Take a visitor badge from the counter")
	elif badged:
		hud.todo("Sign the visitor log")
	else:
		hud.todo("Sign the visitor log and take a visitor badge")


func _checkin_progress() -> void:
	if _signed_in:
		return
	_checkin_todo()
	var n := players.count()
	if n > 1:
		var done := 0
		for id in visitor_log.taken_by:
			if badges.taken_by.has(id):
				done += 1
		if done < n:
			sync.team_notice("Checked in: %d/%d (sign the log, take a badge)" % [done, n])


## The rest of the ground floor around the lobby: a corridor along the back with
## the mailroom, restrooms, cafeteria and IT closet off it; the unlit east corridor
## where the Hum lives, looping back to the hall; and the elevator bank at the end
## of the hall. Optional to explore: nothing here is needed to finish the level.
func _build_ground_floor(wall: Color) -> void:
	var lino := Color(0.3, 0.31, 0.3)
	var tile := Color(0.75, 0.76, 0.74)
	var office := Color(1.0, 0.95, 0.86)
	# North corridor: x -20..12, z -10..-7, behind the lobby.
	Greybox.room(geo, Vector3(-4, 0, -8.5), Vector3(32, 3, 3), {"floor": lino, "wall": wall}, [
		{"wall": "s", "at": -2.5, "width": 1.6, "height": 2.6},  # lobby, west of the desk
		{"wall": "s", "at": 10.5, "width": 1.6, "height": 2.6},  # lobby, east of the desk
		{"wall": "e", "at": 0.0, "width": 2.8, "height": 3.0},  # into the dark east corridor
		{"wall": "n", "at": -12.5, "width": 1.4, "height": 2.2},  # mailroom
		{"wall": "n", "at": -7.5, "width": 1.4, "height": 2.2},  # men's
		{"wall": "n", "at": -4.5, "width": 1.4, "height": 2.2},  # women's
		{"wall": "n", "at": 4.0, "width": 2.4, "height": 2.6},  # cafeteria
		{"wall": "n", "at": 14.0, "width": 1.4, "height": 2.2},  # IT closet
	])
	for x in [-16.0, -8.0, 0.0, 8.0]:
		add_light("corridor", Vector3(x, 3, -8.5), 6.0, 1.0, office)
	# Rooms off the corridor, each behind an ordinary door that players can shut.
	for d in [["MAILROOM", -16.5], ["MENS", -11.5], ["WOMENS", -8.5], ["IT-CLOSET", 10.0]]:
		add_door(d[0], Vector3(d[1], 1.1, -10.0), Vector3(1.35, 2.2, 0.08)).make_hinged(Vector3(-0.675, 0, 0), 90.0)
	Greybox.label(geo, Vector3(-16.5, 2.45, -9.88), "MAILROOM", 36, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(-11.5, 2.45, -9.88), "MEN", 36, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(-8.5, 2.45, -9.88), "WOMEN", 36, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(0, 2.8, -9.88), "CAFETERIA", 48, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(10, 2.45, -9.88), "IT", 36, Color(0.15, 0.15, 0.2))

	# Mailroom: x -20..-13, z -18..-10. Pigeonholes, a sorting table, a cart.
	Greybox.room(geo, Vector3(-16.5, 0, -14), Vector3(7, 3, 8), {"floor": lino, "wall": wall}, [
		{"wall": "s", "at": 0.0, "width": 1.4, "height": 2.2},
	])
	Greybox.box(geo, Vector3(-16.5, 1.1, -17.6), Vector3(5.5, 2.2, 0.6), Color(0.45, 0.38, 0.28), "Pigeonholes")
	Greybox.box(geo, Vector3(-16.5, 0.45, -14.5), Vector3(3.0, 0.9, 1.2), Color(0.5, 0.45, 0.38), "SortingTable")
	Greybox.box(geo, Vector3(-19.0, 0.5, -12.0), Vector3(1.0, 1.0, 1.4), Color(0.35, 0.35, 0.38), "MailCart")
	add_light("mailroom", Vector3(-16.5, 3, -14), 6.0, 1.0, office)
	# The directory printout, pinned to the wall so nobody walks off with it: the
	# walking route to the caller.
	var listing: Array = [
		"Printed 09/30/97. Report changes to the mailroom.",
		{"columns": ["NAME", "DEPT", "EXT."], "widths": [3.0, 2.6, 1.0]},
	]
	for row in data.staff:
		if row[0] != "Office of the Director":
			listing.append({"row": [row[0], row[2], str(row[3])]})
	listing.append({"text": "Mercer's still on here?? - mailroom", "hand": true})
	directory_printout = Document.place(geo, Vector3(-13.12, 1.5, -13.0), 90.0, "HALCYON STAFF DIRECTORY", listing, false, "paper", Vector2(0.5, 0.66))
	directory_printout.clues = [{"case": "caller", "text": "The mailroom's printout of the staff directory lists everyone's extension."}]
	var in_mailroom := Trigger.create(self, Vector3(-16.5, 1, -14), Vector3(6.6, 2, 7.6))
	in_mailroom.entered.connect(func(_b): sync.event("_on_mailroom_entered"), CONNECT_ONE_SHOT)

	# Restrooms: two narrow rooms with stalls to duck into.
	for r in [-11.5, -8.5]:
		Greybox.room(geo, Vector3(r, 0, -14), Vector3(3, 3, 8), {"floor": tile, "wall": tile.darkened(0.1)}, [
			{"wall": "s", "at": 0.0, "width": 1.4, "height": 2.2},
		])
		# Along the west wall, past where the door swings.
		Greybox.box(geo, Vector3(r - 1.25, 0.45, -12.3), Vector3(0.5, 0.9, 1.0), Color(0.85, 0.85, 0.82), "Sinks")
		for k in 2:
			var z := -15.2 - k * 1.4
			Greybox.box(geo, Vector3(r + 0.2, 1.0, z + 0.7), Vector3(2.2, 2.0, 0.05), Color(0.55, 0.6, 0.62), "StallWall")
		Greybox.box(geo, Vector3(r + 0.2, 1.0, -17.95), Vector3(2.2, 2.0, 0.05), Color(0.55, 0.6, 0.62), "StallWall")
		add_light("restrooms", Vector3(r, 3, -13), 4.5, 0.8, office)

	# Cafeteria: x -7..8, z -18..-10. Tables to hop, a serving counter, vending machines.
	Greybox.room(geo, Vector3(0.5, 0, -14), Vector3(15, 3.5, 8), {"floor": lino, "wall": wall}, [
		{"wall": "s", "at": -0.5, "width": 2.4, "height": 2.6},
	])
	for tx in [-4.0, 0.0, 4.0]:
		for tz in [-12.5, -15.0]:
			Greybox.box(geo, Vector3(tx, 0.375, tz), Vector3(2.0, 0.75, 1.0), Color(0.55, 0.42, 0.3), "CafTable")
	Greybox.box(geo, Vector3(0.5, 0.5, -17.4), Vector3(8.0, 1.0, 0.9), Color(0.6, 0.6, 0.62), "ServingCounter")
	Greybox.box(geo, Vector3(7.4, 0.9, -12.0), Vector3(0.9, 1.8, 0.8), Color(0.25, 0.3, 0.5), "VendingMachine")
	Greybox.box(geo, Vector3(7.4, 0.9, -13.2), Vector3(0.9, 1.8, 0.8), Color(0.6, 0.15, 0.12), "VendingMachine")
	vending = Interactable.create(geo, Vector3(6.92, 1.0, -12.0), Vector3(0.06, 0.6, 0.6), "Buy a coffee", Color.WHITE, false)
	vending.used.connect(_on_vending)
	for x in [-3.5, 4.5]:
		add_light("cafeteria", Vector3(x, 3.5, -14), 8.0, 1.1, office)

	# IT closet: x 8..12, z -14..-10. Shelves of spares and a patch panel.
	Greybox.room(geo, Vector3(10, 0, -12), Vector3(4, 3, 4), {"floor": lino, "wall": wall}, [
		{"wall": "s", "at": 0.0, "width": 1.4, "height": 2.2},
	])
	Greybox.box(geo, Vector3(8.4, 1.0, -12.0), Vector3(0.6, 2.0, 3.4), Color(0.4, 0.4, 0.42), "SpareShelf")
	Greybox.box(geo, Vector3(11.7, 1.3, -12.5), Vector3(0.3, 1.2, 1.6), Color(0.12, 0.12, 0.14), "PatchPanel")
	Greybox.box(geo, Vector3(10.8, 0.3, -13.4), Vector3(0.8, 0.6, 0.6), Color(0.45, 0.35, 0.2), "Crate")
	# A ceiling access panel that sticks: out of reach without a leg up.
	ceiling_hatch = Interactable.create(self, Vector3(10.2, 2.97, -12.6), Vector3(0.7, 0.04, 0.7), "Push the ceiling panel", Color(0.78, 0.78, 0.74))
	ceiling_hatch.used.connect(_on_hatch)
	add_light("it_closet", Vector3(10, 3, -12), 4.0, 0.7, office)

	# The dark east corridor: x 12..19, z -10..-7, then a passage south (x 17..19)
	# to the hall. No working lights: this is where the Hum lives.
	Greybox.room(geo, Vector3(15.5, 0, -8.5), Vector3(7, 3, 3), {"floor": lino.darkened(0.2), "wall": wall.darkened(0.3)}, [
		{"wall": "w", "at": 0.0, "width": 2.8, "height": 3.0},
		{"wall": "s", "at": 2.5, "width": 2.0, "height": 2.6},
	])
	Greybox.room(geo, Vector3(18, 0, -2.5), Vector3(2, 3, 9), {"floor": lino.darkened(0.2), "wall": wall.darkened(0.3)}, [
		{"wall": "n", "at": 0.0, "width": 2.0, "height": 2.6},
		{"wall": "s", "at": 0.0, "width": 2.0, "height": 2.6},
	])
	Greybox.panel(geo, Vector3(15.5, 2.97, -8.5), Vector3(1.2, 0.05, 0.3), Color(0.3, 0.3, 0.3))  # a dead light
	hum = Hum.create(self, AABB(Vector3(12, 0, -10), Vector3(7, 3, 12)))

	# Elevator bank: x 24..30, z -1..7, through the badge door at the end of the hall.
	Greybox.room(geo, Vector3(27, 0, 3), Vector3(6, 3.2, 8), {"floor": Color(0.35, 0.33, 0.3), "wall": wall}, [
		{"wall": "w", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "e", "at": 0.0, "width": Elevator.DOORWAY, "height": Elevator.DOOR_H},
		{"wall": "s", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},  # the stairs
	])
	stair_door = Stairwell.build(self, geo, Vector3(27, 0, 7), 180.0, "G")
	add_light("elevators", Vector3(27, 3.2, 1), 7.0, 1.1, office)
	add_light("elevators", Vector3(27, 3.2, 5), 7.0, 1.1, office)
	elevator = Elevator.create(self, geo, LIFT_AT, 90, "G", ["22", "14", "G", "B1"], "14")
	elevator.name = "Elevator"
	elevator.button.enabled = false


## A shape with no collision, for small props on an interactable (so they don't
## catch the player's aim instead of it).
static func _mesh(parent: Node, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _set_front_doors_locked(locked: bool) -> void:
	db.run_silent("UPDATE doors SET locked = %d WHERE id = 'LOBBY-FRONT'" % int(locked))
	db.sync_world()


## The van radio, until the crew is ready.
func _dispatch_chatter() -> void:
	for id in ["l0_dispatch_1", "l0_dispatch_2", "l0_dispatch_3"]:
		if _intro_started:
			return
		await hud.line(id)


## Runs on the host. What the puzzle unlocks then plays out on every machine.
func _on_desk_query(_sql: String, result: Dictionary, _ui: TerminalUI) -> void:
	if not peek_puzzle.solved and peek_puzzle.matches(db, result):
		sync.event("_on_peek_solved")
	if not memo_puzzle.solved and memo_puzzle.matches(db, result):
		sync.event("_on_memo_solved")
	elif not memo_puzzle.solved and memo_backwards.matches(db, result):
		sync.event("_on_memo_backwards")
	if caller_asked and not caller_puzzle.solved and not caller_listed and _shows_caller(result):
		sync.event("_on_caller_listed")
	if not visitor_puzzle.solved and visitor_puzzle.matches(db, result):
		sync.event("_on_last_visitor")
	elif not visitor_puzzle.solved and visitor_top_one.matches(db, result):
		sync.event("_on_visitor_top_one")


## LIMIT 1 shows only the crew's own sign-in; Vale is the row below it.
func _on_visitor_top_one() -> void:
	desk_terminal.print_line(TerminalUI.sysop("that's your own crew, signed in at 23:04. whoever came before you is one row further down: LIMIT 2 or more."))


func _on_memo_backwards() -> void:
	desk_terminal.print_line(TerminalUI.sysop("that's the memo backwards. leave out DESC: smallest first."))


func _on_peek_solved() -> void:
	_file_memo_case()
	# The scraps came out of order: the book's ORDER BY chapter, round the garage bench.
	await _book_huddle("easy_sql_2")
	if memo_puzzle.solved:
		return  # sorted in the same breath: nothing left to nudge
	desk_terminal.print_line("")
	desk_terminal.print_line(TerminalUI.sysop("the scraps are out of order. one of the columns numbers them."))
	desk_terminal.print_line(TerminalUI.sysop("add ORDER BY to the end of your query, then that column's name."))
	hud.todo(OBJ_ORDER)


## The memo is up on the screen, so the first case is answered: file it, and the
## scraps being in the scanner's order makes putting them straight the next case.
## Once only, whether the crew peeked first or went straight to the sorted query.
func _file_memo_case() -> void:
	if peek_puzzle.solved:
		return
	peek_puzzle.solved = true
	var game := get_node("/root/Game")
	game.tick_step("memo", "peek")
	game.solve_case("memo", "memo_fragments holds the shredded memo: one scrap to a row.")
	game.collect_piece("memo_order", "table", "your first query")  # already in hand
	game.open_case("memo_order", "Which scrap comes first?", ["memo_fragments"], OBJ_ORDER)
	game.set_pieces("memo_order", ORDER_PIECES, ORDER_QUERY, ORDER_STEPS)
	game.set_case_note("memo_order", "", "", DESK_TERMINAL)
	game.collect_piece("memo_order", "order", "Easy SQL")  # the chapter the crew is about to read
	_shine_clue_papers()


func _on_memo_solved() -> void:
	memo_puzzle.solved = true
	_file_memo_case()  # sorted in one go, without the peek: both cases are answered
	# The sorted result on screen is the memo: nothing more to print.
	_after_memo()


func _after_memo() -> void:
	hud.todo("")
	_rourke_free = false
	if sync.is_host() and Vector2(rourke.global_position.x - DESK_SPOT.x, rourke.global_position.z - DESK_SPOT.z).length() > 1.5:
		var from_it: bool = rourke.global_position.x > 8.0
		_rourke_back_to_desk(TO_IT_CLOSET if from_it else TO_CAFETERIA)
	# Written on the job ticket: what the crew touched, for later levels to read back.
	get_node("/root/Game").ticket_fill(OBJ_ORDER, "rebuilt from memo_fragments. Copy to the director, says Rourke")
	get_node("/root/Game").solve_case("memo_order", "the scraps sorted by piece_no read as the memo.")
	# Sorted without the peek first: ORDER BY's chapter still comes before Rourke
	# moves on, and Newest first too if its paper was read on the way.
	await _book_huddle("easy_sql_2")
	_book_check("easy_sql_4")
	# Rourke waits for the crew to step back from the screen before he says anything,
	# and the building's PA only cuts in once he's done.
	await sync.gate("memo_left_terminal", _crew_off_desk_terminal)
	await _huddles_over()
	_rourke_briefing = true
	await get_tree().create_timer(0.6, false).timeout
	_watch_nearest()
	await hud.lines(["l0_memo_flag", "l0_memo_1", "l0_caller_1", "l0_caller_2", "l0_mailroom_1"])
	# He's asked who called: the book's chapter on naming columns, then the case opens.
	await _book_huddle("easy_sql_3")
	_rourke_briefing = false
	_ask_caller()
	_book_check("easy_sql_4")
	await sync.gate("caller_found", func():
		if not caller_puzzle.solved:
			await caller_found)
	await get_tree().create_timer(0.6, false).timeout
	_watch_nearest()
	await hud.lines(["l0_caller_3", "l0_memo_2", "l0_memo_3", "l0_memo_4"])
	_pa_after_memo()
	_leave_lobby()


## Who called, for a run whose work order shows extension `ext`. Hints follow
## the ladder: the query's shape with ?, then how to find it, then exact.
static func caller_puzzle_for(ext: int) -> Puzzle:
	return Puzzle.new("caller", "SELECT name, extension FROM staff_directory", ["name", "extension"], false, [
		"The shape of it:\n" +
		"    [color=#ffffff]SELECT name, enter_column_name FROM staff_directory;[/color]\n" +
		"  SELECT name, enter_column_name  just these columns, so each row fits on the screen\n" +
		"  FROM staff_directory            from the staff directory\n" +
		"Replace enter_column_name with the column holding phone extensions. " +
		"To see every column's name, type .schema staff_directory (or run SELECT * FROM staff_directory; once: the names are across the top). " +
		"Then find %d, the number on your work order." % ext,
		"Type .schema staff_directory and press Enter: it lists the table's columns. One of them holds the phone extensions.",
		"Type this exactly and press Enter:\n" +
		"    [color=#ffffff]SELECT name, extension FROM staff_directory;[/color]\n" +
		"Then find %d in the extension column, point at that row and click + add to notebook." % ext,
	])


## Optional: the visitor log, newest first. The whole list passes, and so does
## any LIMIT that still reaches Vale's row (the crew's own is above it).
static func visitor_puzzle_for() -> Puzzle:
	var p := Puzzle.new("last_visitor", "SELECT name, signed_in FROM visitors ORDER BY signed_in DESC", ["name", "signed_in"], true, [
		"The shape of it:\n" +
		"    [color=#ffffff]SELECT * FROM visitors ORDER BY enter_column_name DESC LIMIT 5;[/color]\n" +
		"  SELECT *                    every column\n" +
		"  FROM visitors               from the visitor log\n" +
		"  ORDER BY enter_column_name  sorted by a column\n" +
		"  DESC                        biggest (newest) first\n" +
		"  LIMIT 5                     only the first 5 rows\n" +
		"Replace enter_column_name with the column with the sign-in time.",
		".schema visitors lists its columns. One of them holds the sign-in time. LIMIT 5 keeps the first 5 rows, and with DESC those are the newest. The sticky on the desk shows where it goes.",
		"Type this exactly and press Enter:\n" +
		"    [color=#ffffff]SELECT * FROM visitors ORDER BY signed_in DESC LIMIT 5;[/color]",
	])
	p.top_rows = 2
	return p


## LIMIT 1 on the visitor log: just the crew's own row, one short of Vale's.
static func visitor_top_one_for() -> Puzzle:
	return Puzzle.new("visitor_top_one", "SELECT name, signed_in FROM visitors ORDER BY signed_in DESC LIMIT 1", ["name", "signed_in"], true)


## The caller case's pieces for a run whose work order shows extension `ext`.
## Drafts for Augustine's word-for-word OK.
static func caller_pieces(ext: int) -> Array:
	return [
		{"id": "ext", "label": "The number", "value": "ext. %d" % ext, "task": "Read the extension off the work order", "where": "The work order"},
		{"id": "table", "label": "The table", "value": "staff_directory", "task": "Find the table of staff", "where": "Ask SYSOP at the front desk terminal", "seen_in": "staff_directory", "blank": "enter_table_name"},
		{"id": "column", "label": "The column with extensions", "value": "extension", "task": "Find the column that holds extensions", "where": "Type .schema staff_directory at the terminal", "seen_in": "staff_directory", "blank": "enter_column_name"},
	]


## Rourke didn't place the call: who did? The work order has the extension; the
## staff directory (or the mailroom's printout of it) has the name.
func _ask_caller() -> void:
	caller_asked = true
	hud.todo(OBJ_CALLER % data.extension)
	var game := get_node("/root/Game")
	game.open_case("caller", "Who called from ext. %d?" % data.extension, ["staff_directory"], OBJ_CALLER % data.extension)
	game.set_pieces("caller", caller_pieces(data.extension), CALLER_QUERY, CALLER_STEPS)
	game.set_routes("caller", CALLER_ROUTES)
	game.collect_piece("caller", "ext", "the work order")
	game.collect_piece("caller", "table", "SYSOP")
	game.add_clue("caller", "The call came from ext. %d." % data.extension, "Work order")
	game.set_blank("caller", "Ext. %d belongs to" % data.extension, ["harold mercer", str(data.extension)], "Harold Mercer")
	game.add_clue("caller", "Name just the columns you want, with commas between them: SELECT column, column FROM table_name;", "SYSOP")
	game.add_clue("caller", "Column names: .schema staff_directory lists them.", "SYSOP")
	desk_terminal.print_line("")
	desk_terminal.print_line(TerminalUI.sysop("staff_directory is wide. Instead of *, name just the columns you want, with commas between them:"))
	desk_terminal.print_line("    [color=#ffffff]SELECT [i]column[/i], [i]column[/i] FROM [i]table_name[/i];[/color]")
	desk_terminal.print_line(TerminalUI.sysop("don't know its column names? type [b].schema staff_directory[/b] and press Enter: it lists them."))


func _on_mailroom_entered() -> void:
	hud.line("l0_mailroom_2")


## A result row holds the caller's name beside the work order's extension.
func _shows_caller(result: Dictionary) -> bool:
	return result.get("ok", false) and result.rows.any(func(r: Dictionary):
		var cells := r.values().map(func(v): return str(v).to_lower())
		return cells.has("harold mercer") and cells.has(str(data.extension)))


## The caller's row is on screen: the answer is in it, but it's the crew's to pick
## out. From now on .hint gives that step.
func _on_caller_listed() -> void:
	caller_listed = true
	var step := "point at the row with ext. %d and click + add to notebook: it goes in the blank on your case page." % data.extension
	desk_terminal.print_line(TerminalUI.sysop("there it is. " + step))
	caller_puzzle.hints = [step]
	caller_puzzle.hint_index = 0


## This player added a line that answers one of their cases: tell the host.
func _on_answer_found(id: String) -> void:
	if id == "caller":
		var game := get_node("/root/Game")
		if game.case_info("caller").blank.get("source", "") == "document":
			game.find_route("caller", "printout")  # off the wall, no query needed
		sync.report_answer(id)


## This player noted a directory line that isn't the caller's. A terminal row:
## tell the host which extension it held, so SYSOP can say why the blank stayed
## empty. A line of the mailroom's printout: SYSOP isn't there, so a pencil line
## under the blank says it (this player's notebook only).
func _on_line_noted(text: String, kind: String) -> void:
	if not caller_asked or caller_puzzle.solved:
		return
	if kind == "document":
		if directory_printout.lines().any(func(l): return l.has("row") and str(l.text).strip_edges() == text):
			get_node("/root/Game").blank_miss("caller", "Not that one: the blank wants whoever has ext. %d." % data.extension)
		return
	if kind != "row" or caller_miss_said:
		return
	var lines := text.split("\n")
	if lines.size() < 2:
		return
	var head := Array(lines[0].split("|")).map(func(c): return c.strip_edges().to_lower())
	var cells := Array(lines[1].split("|")).map(func(c): return c.strip_edges())
	var at := head.find("extension")
	if at < 0 or at >= cells.size() or cells[at] == str(data.extension):
		return
	sync.report_answer("caller", cells[at])


## Host: a player noted ext. `missed`'s row instead of the caller's.
func case_missed(id: String, _peer: int, missed: String) -> void:
	if id == "caller" and caller_asked and not caller_puzzle.solved and not caller_miss_said:
		sync.event("_on_caller_missed", [missed])


func _on_caller_missed(missed: String) -> void:
	caller_miss_said = true
	desk_terminal.print_line(TerminalUI.sysop("that's ext. %s's row. the blank wants whoever has ext. %d." % [missed, data.extension]))


## Host: a player wrote the caller's name into their case page.
func case_answered(id: String, _peer: int) -> void:
	if id == "caller" and caller_asked and not caller_puzzle.solved:
		sync.event("_on_caller_found")


func _on_caller_found() -> void:
	if caller_puzzle.solved:
		return
	caller_puzzle.solved = true
	get_node("/root/Game").fill_blank("caller", false)  # the rest of the crew's pages too
	var task := "Find out who called from ext. %d" % data.extension
	hud.todo("")
	get_node("/root/Game").ticket_fill(task, "ext. %d: Harold Mercer, Building Services (left 03/94)" % data.extension)
	get_node("/root/Game").solve_case("caller", "ext. %d is Harold Mercer, Building Services. He left in 03/94." % data.extension)
	caller_found.emit()


## Host: a paper brings back chapter `id` of Easy SQL. Read before its puzzle is
## ready, it waits for that (_book_check).
func _book_found(id: String) -> void:
	if sync.is_host() and not _books.has(id):
		_books[id] = "found"
		_book_check(id)


## Host: play chapter `id` if its paper has been read and its puzzle is ready.
func _book_check(id: String) -> void:
	if sync.is_host() and _books.get(id, "") == "found" and _book_ready(id):
		_books[id] = "played"
		sync.event("_book_huddle", [id])


func _book_ready(id: String) -> bool:
	match id:
		"easy_sql_4":
			return memo_puzzle.solved and not _rourke_briefing  # DESC flips the memo's ORDER BY
	return true


## Every machine: a chapter of Easy SQL, read round the garage bench (a flashback,
## once per run).
func _book_huddle(id: String) -> void:
	await Huddle.of(self).run(id)


## Every machine: until no huddle is open or waiting here.
func _huddles_over() -> void:
	var h := Huddle.of(self)
	while h and h.is_busy():
		await h.idle


## Optional: the visitor log, newest first. Vale signed in tonight and never left.
func _on_last_visitor() -> void:
	visitor_puzzle.solved = true
	get_node("/root/Game").open_case("last_visitor", BOOK_CASE, ["visitors"], OBJ_VISITOR)
	get_node("/root/Game").solve_case("last_visitor", "VALE, I. signed in at %s tonight and never signed out." % str(data.vale_in).right(5))
	get_node("/root/Game").write_note("Last visitor", "VALE, I. signed in %s tonight. Never signed out." % str(data.vale_in).right(5), "result")
	hud.notice("Added to your notebook (Tab)", 3.0)


## Host: until nobody is at the desk terminal any more (or a while has passed,
## so the story never waits forever on someone who stays).
func _crew_off_desk_terminal() -> void:
	var waited := 0.0
	while waited < 30.0:
		var anyone: bool = terminal_ui.visible and terminal_ui.terminal == desk_terminal
		if not desk_terminal.seated.is_empty():
			anyone = true
		if not anyone:
			return
		await get_tree().create_timer(0.25, false).timeout
		waited += 0.25


func _pa_after_memo() -> void:
	await get_tree().create_timer(2.5, false).timeout
	hud.line("l0_sort_hint")


## The memo and the caller are done: Rourke takes the crew on. The walkie-talkies
## stay on the charger for anyone who still wants one.
func _leave_lobby() -> void:
	_errand += 1  # the story has him now
	prepare_next()
	# Behind the counter, the PA's escort tape replays; Rourke covers for the crew.
	await hud.line("l0_pa_2")
	_watch_nearest()
	await hud.line("l0_cover")
	hud.line("l0_walkie")
	hud.todo("Follow Rourke")
	_walk_to_server_room()


## Rourke walks the crew down the hall himself, making small talk. Nothing is wrong yet.
func _walk_to_server_room() -> void:
	rourke.walk_to(Vector3(9.6, 0, 3))
	await sync.gate("rourke_at_shutter", rourke.arrived)
	_watch_nearest()
	shutter.set_open(true)  # he badges it, and it opens like any other door
	hud.todo("Follow Rourke to Server Room A")
	var hall := Trigger.create(self, Vector3(8.2, 1, 3), Vector3(1.2, 2, 2))
	await sync.gate("hall", hall.entered)
	rourke.walk_to(Vector3(22.4, 0, 3))
	_face_crew_on_arrival()
	await hud.lines(["l0_tour_3", "l0_tour_4", "l0_tour_5", "l0_tour_6"])
	# Past the dark passage to the east corridor, he waves the hum away.
	await hud.line("l0_hum")
	await sync.gate("rourke_at_sra", func():
		if rourke.state == Rourke.State.WALK:
			await rourke.arrived)
	# He waits until the whole crew has caught up.
	var near := Trigger.create(self, Vector3(19.4, 1, 3), Vector3(4.8, 2, 2))
	near.require_all = true
	near.waiting.connect(func(inside, total): sync.team_notice("Rourke is waiting for everyone at Server Room A (%d/%d)" % [inside, total]))
	near.entered.connect(func(_b): sync.event("_on_reach_server_room", [null]))


## Rourke turns to whoever is closest and keeps facing them while he talks (host).
func _watch_nearest() -> void:
	if sync.is_host():
		rourke.watch = players.nearest(rourke.global_position)


## Host: once he's at the door, he turns round to talk to the crew rather than to it.
func _face_crew_on_arrival() -> void:
	if not sync.is_host():
		return
	if rourke.state == Rourke.State.WALK:
		await rourke.arrived
	rourke.watch = players.nearest(rourke.global_position)


## Where Rourke waits for the crew: on the steps outside the front doors.
const ROURKE_OUTSIDE := Vector3(0, 0, 8.8)

## Where Rourke stands in the elevator car, at the back by the buttons.
const ROURKE_IN_LIFT := Vector3(-0.75, 0, 1.6)  # across the car from the buttons

## Where Rourke waits at the front desk while the crew works.
const DESK_SPOT := Vector3(-0.5, 0, 0.6)

## Where Rourke stands holding the door: just inside the elevator bank, beside
## the doorway so the crew can walk past him.
const HOLD_DOOR_AT := Vector3(25.0, 0, 4.05)


func _on_reach_server_room(_b: Node) -> void:
	# He opens the door, steps through, and holds it while the crew files past.
	rourke.watch = null
	rourke.face(exit_door.global_position)
	exit_door.set_open(true)
	await sync.gate("rourke_holds_door", func():
		if Vector2(rourke.global_position.x - 22.4, rourke.global_position.z - 3.0).length() > 2.5:
			rourke.global_position = Vector3(22.4, rourke.global_position.y, 3)  # never left behind
		await get_tree().create_timer(0.5, false).timeout
		rourke.walk_to(Vector3(HOLD_DOOR_AT.x, 0, 3), true)
		await rourke.arrived
		rourke.walk_to(HOLD_DOOR_AT, true)
		await rourke.arrived)
	_watch_nearest()
	await hud.line("l0_elevator")
	hud.todo("Follow Rourke to the elevator")
	# The door swings shut once the whole crew is past him and clear of its swing.
	var past := Trigger.create(self, Vector3(28.1, 1, 3), Vector3(3.8, 2, 8))
	past.require_all = true
	past.waiting.connect(func(n, total): sync.team_notice("Rourke is holding the door for everyone (%d/%d)" % [n, total]))
	past.entered.connect(func(_b): sync.event("_on_crew_at_elevators"))


## Everyone is through: the door shuts behind them, the elevator opens and Rourke
## steps in first.
func _on_crew_at_elevators() -> void:
	exit_door.set_open(false)
	elevator.hud = hud
	elevator.open()
	elevator.closed.connect(_on_elevator_closed, CONNECT_ONE_SHOT)
	elevator.button.enabled = true
	prepare_next()
	rourke.watch = null
	await sync.gate("rourke_in_lift", func():
		await get_tree().create_timer(0.6, false).timeout
		rourke.walk_to(elevator.to_global(Vector3(0, 0, 0.6)), true)
		await rourke.arrived
		rourke.walk_to(elevator.to_global(ROURKE_IN_LIFT), true)
		await rourke.arrived)
	_watch_nearest()
	if not elevator.is_closing and not elevator.riding:
		hud.todo("Everyone into the elevator, then press 14")
		hud.line("l0_lift_button")


## The doors are shut: the checkpoint. The server floor loads during the ride, and
## everyone (Rourke too) steps out of its arrival car.
func _on_elevator_closed() -> void:
	get_node("/root/Net").earn("achievement:floor_g", hud)  # the ground floor is done: everyone aboard earns it
	hud.todo("")
	if world:
		db.checkpoint()
	prepare_next()
	var next: Node = world.wings.get("level_1") if world else null
	if next and next.get("arrival_lift") is Elevator:
		elevator.link_to(next.arrival_lift)
	await elevator.ride()
	if elevator.destination:
		# He rides up with the crew: the server floor's Rourke takes over where he stands.
		var into := elevator.destination.global_transform * elevator.global_transform.affine_inverse()
		rourke.global_transform = into * rourke.global_transform
	if world:
		finish_level("level_1")
		return
	player.input_locked = true
	await hud.fade(true, 1.0)
	finish_level("level_1")


## Rourke's walks from the front desk, round the west partition and along the north
## corridor: straight steps, so he never snags on the desk's corner.
const TO_CAFETERIA := [Vector3(-6.3, 0, 0.6), Vector3(-6.5, 0, -6.5), Vector3(-6.5, 0, -8.5), Vector3(0, 0, -8.5), Vector3(0, 0, -10.6), Vector3(6.2, 0, -11.0), Vector3(6.2, 0, -12.0)]
const TO_IT_CLOSET := [Vector3(-6.3, 0, 0.6), Vector3(-6.5, 0, -6.5), Vector3(-6.5, 0, -8.5), Vector3(10.0, 0, -8.5), Vector3(10.0, 0, -11.0)]


## Host: Rourke walks over to help with something, if he's free. True once he's
## there and still free (the story hasn't called him away).
func _rourke_errand(route: Array) -> bool:
	_errand += 1
	var mine := _errand
	rourke.watch = null
	for spot in route:
		if not _rourke_free or mine != _errand:
			return false
		rourke.walk_to(spot, true)
		await rourke.arrived
	return _rourke_free and mine == _errand


## Host: Rourke is free and standing at the front desk, so he can come and help.
func _rourke_can_help() -> bool:
	return _rourke_free and Vector2(rourke.global_position.x - DESK_SPOT.x, rourke.global_position.z - DESK_SPOT.z).length() < 1.5


## Host: back to the desk the way he came, from wherever he is along the route.
## Stops if the story takes him somewhere else (_on_walkies).
func _rourke_back_to_desk(route: Array) -> void:
	_errand += 1
	var mine := _errand
	var k := 0
	for i in route.size():
		if rourke.global_position.distance_to(route[i]) < rourke.global_position.distance_to(route[k]):
			k = i
	var back := route.slice(0, k + 1)
	back.reverse()
	back.append(DESK_SPOT)
	for spot in back:
		if mine != _errand:
			return
		rourke.walk_to(spot, true)
		await rourke.arrived
	if mine == _errand:
		_watch_nearest()


## Host: the vending machine eats quarters. Rourke knows the trick, once.
func _on_vending(_p: Node) -> void:
	if _coffee_done or not _rourke_can_help():
		sync.event("_on_vending_eats")
		return
	_coffee_done = true
	sync.event("_on_vending_eats")
	if await _rourke_errand(TO_CAFETERIA):
		sync.event("_on_coffee")


func _on_vending_eats() -> void:
	hud.notice("The machine takes your quarter and keeps it.", 2.5)


func _on_coffee() -> void:
	rourke.face(vending.global_position)
	await hud.line("l0_coffee")
	vending.enabled = false
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.035
	cm.height = 0.1
	cup.mesh = cm
	cup.material_override = Greybox.mat(Color(0.92, 0.9, 0.85))
	cup.name = "CoffeeCup"
	cup.position = Vector3(6.85, 0.55, -12.0)
	geo.add_child(cup)
	if sync.is_host():
		_rourke_back_to_desk(TO_CAFETERIA)


## Host: the ceiling panel is too high to shift alone. Rourke gives a leg up, once.
func _on_hatch(_p: Node) -> void:
	if _boost_done or not _rourke_can_help():
		sync.event("_on_hatch_stuck")
		return
	_boost_done = true
	sync.run_on(doors["IT-CLOSET"], "set_open", [true])  # he opens the closet if it's shut
	if await _rourke_errand(TO_IT_CLOSET):
		sync.event("_on_boost")
	else:
		_boost_done = false


func _on_hatch_stuck() -> void:
	hud.notice("It's stuck, and too high to get any force on it.", 2.5)


func _on_boost() -> void:
	rourke.face(ceiling_hatch.global_position)
	await hud.line("l0_boost_1")
	ceiling_hatch.enabled = false
	ceiling_hatch.position.y += 0.3  # pushed up into the ceiling void
	hud.notice("You step on Rourke's hands and shove the panel up. Something drops out of the ceiling void.", 4.0)
	Document.place(geo, Vector3(10.8, 0.602, -13.4), 20.0, "Old sticker", [
		"FIXED BY BYTE-RIGHT IT SERVICES!",
		{"text": "ceiling cable run, 3/94", "hand": true},
	], true, "note", Vector2(0.1, 0.07))
	await hud.line("l0_boost_2")
	if sync.is_host():
		_rourke_back_to_desk(TO_IT_CLOSET)


## The grate comes off and leans against the wall, on every machine.
func _on_vent_grate() -> void:
	vent_grate.enabled = false
	for c in vent_grate.get_children():
		if c is CollisionShape3D:
			c.disabled = true
	vent_grate.position = Vector3(-7.75, 0.48, 5.1)
	vent_grate.rotation_degrees = Vector3(0, 0, -12)
	hud.notice("Hold Ctrl to crouch, and keep holding it to crawl in.", 5.0)


## Optional: Mercer's cassette in the forgotten closet. Everyone hears it, but
## only whoever is in the closet when it plays earns its secret (each machine
## checks its own player).
func _on_tape() -> void:
	tape.enabled = false
	# The secret goes only to whoever is in the closet when it plays; the host decides.
	if sync.is_host():
		sync.unlock_for(players.all_ids().filter(func(id):
			var body: Node3D = players.puppet(id)
			return body and VENT_CLOSET.has_point(to_local(body.global_position))), "secret:mercer_vent_tape")
	await hud.lines(VoiceLines.ids_in_scene("l0_tape"))
