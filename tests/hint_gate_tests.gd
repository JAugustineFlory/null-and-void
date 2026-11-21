extends RefCounted
## `.hint` starts in the world (spec G2, plan/teaching/puzzle-flow-v0.10.md
## section 3): its first tier names the spot for the first piece the crew still
## lacks, and the tiers go on only once someone has found it. And the crew's
## commentary, which no floor played before, can be turned on for a floor
## (LevelBase.start_commentary).

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	await test_hint_spots()
	await test_commentary_hook()
	await test_floor_g()
	await test_floor_g_package()


func _game() -> Node:
	return _tree.root.get_node("/root/Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree.physics_frame


func _last_line(term: Node) -> String:
	return TerminalUI._plain(term.transcript[term.transcript.size() - 1])


func test_hint_spots() -> void:
	print("Hints start in the world")
	var g := _game()
	g.new_run(21)
	check(g.spots_found.is_empty() and g.find_spot("a") and not g.find_spot("a") and g.spot_found("a"), "a spot is found once, and stays found")
	g.new_run(21)
	check(not g.spot_found("a"), "a new run starts with none found")
	# The puzzle on its own: spots in order, skipping one found or whose piece is in hand.
	var p := Puzzle.new("t", "SELECT 1;", [], false, ["tier one", "tier two", "tier three"])
	p.case_id = "t_case"
	p.spots = [{"id": "card", "text": "the card", "piece": "table"}, {"id": "phone", "text": "the phone"}]
	g.open_case("t_case", "Test case")
	g.set_pieces("t_case", [{"id": "table", "label": "The table", "value": "memo_fragments", "task": "Find the table", "where": "The card"}], "SELECT * FROM {table};")
	check(p.spot_hint(g) == "the card", "the first tier names the spot for the first piece still missing")
	g.collect_piece("t_case", "table", "somewhere else")
	check(p.spot_hint(g) == "the phone", "a spot whose piece is already in hand is skipped")
	g.find_spot("phone")
	check(p.spot_hint(g) == "", "with every spot found, there's no world tier")
	# At a terminal: .hint gives the spot until someone finds it, then the tiers.
	g.new_run(21)
	var level = load("res://scenes/level_0.tscn").instantiate()
	_tree.root.add_child(level)
	await _frames(12)
	var term: Node = level.desk_terminal
	var pz: Puzzle = null
	for q in term.puzzles:
		if not q.solved:
			pz = q
			break
	check(pz != null, "the desk terminal has a puzzle to hint at")
	if pz == null:
		level.queue_free()
		return
	pz.spots = [{"id": "test_card", "text": "The scanner came with a quick-start card."}, {"id": "schema:visitors", "text": "Type .schema, a space and the table's name."}]
	pz.hint_index = 0
	var ui: TerminalUI = level.terminal_ui
	ui.open(term, level.player)
	ui.run(".hint")
	check(_last_line(term).contains("The scanner came with a quick-start card.") and pz.hint_index == 0, ".hint first points at the spot, without using up a tier")
	ui.run(".hint")
	check(_last_line(term).contains("quick-start card") and pz.hint_index == 0, "and keeps pointing there until someone finds it")
	var card := Document.place(level.geo, Vector3(1, 1, 1), 0.0, "Test card", [{"text": "Step 1"}], false)
	card.spot = "test_card"
	card.report_open(level.player)
	check(g.spot_found("test_card"), "reading the paper that is the spot finds it")
	ui.run(".hint")
	check(_last_line(term).contains(".schema") and pz.hint_index == 0, "then .hint moves on to the next spot")
	ui.run(".schema visitors")
	check(g.spot_found("schema:visitors"), "running .schema on a table finds that table's spot")
	ui.run(".hint")
	check(pz.hint_index == 1 and _last_line(term).contains(TerminalUI._plain(pz.hints[0]).left(20)), "with every spot found, the tiers go on as before")
	ui.close()
	level.queue_free()
	await _tree.process_frame


func test_commentary_hook() -> void:
	print("The crew's commentary, turned on for a floor")
	var g := _game()
	g.new_run(22)
	var level = load("res://scenes/level_0.tscn").instantiate()
	_tree.root.add_child(level)
	await _frames(12)
	var first: Commentary = level.commentary
	check(first != null and first.is_in_group(Commentary.GROUP) and level.start_commentary() == first, "the ground floor turns its commentary on, once")
	# Started again with a case already solved, as on a floor reached with cases behind it.
	first.queue_free()
	level.commentary = null
	await _tree.process_frame
	g.open_case("memo", "Old case")
	g.solve_case("memo", "done")
	var c: Commentary = level.start_commentary()
	check(c != null and c != first and level.start_commentary() == c, "start_commentary makes one Commentary for the floor")
	check(not _pay("peek").any(func(l): return c.played.has(l)), "a case solved before it started plays no payoff")
	g.open_case("caller", "Who called?")
	await _frames(1)
	check(g.main_case() != "caller" or c.case_id == "caller", "it follows the case being worked on (%s)" % c.case_id)
	var on := c.case_id
	var term: Node = level.desk_terminal
	var ui: TerminalUI = level.terminal_ui
	ui.open(term, level.player)
	ui.run("SELECT * FROM no_such_table;")
	ui.run("SELECT * FROM no_such_table;")
	check(on == "" or c.fails >= 2, "it hears failed queries at the floor's terminals")
	ui.run(".hint")
	check(c.sysop_helped, "and .hint")
	ui.close()
	var doc := Document.place(level.geo, Vector3(1, 1, 1), 0.0, "HALCYON STAFF DIRECTORY", [{"text": "Front desk 1001"}], false)
	c.watch_documents(level)
	doc.report_open(level.player)
	check(c.seen.has("HALCYON STAFF DIRECTORY"), "and every paper read")
	if on != "":
		g.solve_case(on, "found")
		check(_pay(on).all(func(l): return c.played.has(l)), "a case solved plays its payoff")
	level.queue_free()
	await _tree.process_frame


## Floor G's hints start at its spots (G26-G30), and its commentary follows its
## cases under the puzzles' own ids.
func test_floor_g() -> void:
	print("Floor G: hints start in the world, and the crew talks")
	var g := _game()
	g.new_run(23)
	var level = load("res://scenes/level_0.tscn").instantiate()
	_tree.root.add_child(level)
	await _frames(12)
	var k: Dictionary = level.get_script().get_script_constant_map()
	var term: Node = level.desk_terminal
	check(term.next_hint() == k.SPOT_CARD, "the first .hint on G sends the crew to the scanner's card (G26)")
	var card: Document = null
	for d in level.find_children("*", "Document", true, false):
		if d.spot == "scan_card":
			card = d
	check(card != null, "the scanner's card is that spot")
	if card:
		card.report_open(level.player)
	check(g.spot_found("scan_card") and term.next_hint() != k.SPOT_CARD, "once it's read, .hint goes on to the tiers")
	check(level.caller_puzzle.spots[0].text == k.SPOT_PHONE and level.phone_note.spot == "phone_note", "the caller's first spot is the note by the front desk phone (G28)")
	check(level.caller_puzzle.spots[1].text == k.SPOT_SCHEMA and level.visitor_puzzle.spots[0].text == k.SPOT_SCHEMA and level.visitor_puzzle.spots[1].text == k.SPOT_NIGHT_DESK, "then .schema, and the night desk's stickies (G29, G30)")
	var c: Commentary = level.commentary
	check(c != null, "G's commentary is on")
	g.open_case("memo", "What does the memo say?", ["memo_fragments"], "Read it")
	await _frames(1)
	check(c.case_id == "peek", "the memo case is the commentary's peek (%s)" % c.case_id)
	level.comment("memo_scraps")
	check(c.played.has("l0_cc_memo_disc"), "the floor's own moments play their discovery lines")
	level.queue_free()
	await _tree.process_frame


## Floor G's v0.10 package (plan/approvals/puzzle-flow-floor-g.md): the moves,
## the desk phone, the visitor slot and the pencil notes under the slots.
func test_floor_g_package() -> void:
	print("Floor G: the v0.10 package")
	var g := _game()
	g.new_run(24)
	var level = load("res://scenes/level_0.tscn").instantiate()
	_tree.root.add_child(level)
	await _frames(12)
	var k: Dictionary = level.get_script().get_script_constant_map()
	var term: Terminal = level.desk_terminal
	# The monitor faces behind the desk until the first case opens, then Rourke turns it.
	check(is_equal_approx(term.rotation_degrees.y, 180.0), "the front desk's monitor faces behind the desk to start with")
	level._turn_monitor()
	await _tree.create_timer(1.0).timeout
	check(is_equal_approx(term.rotation_degrees.y, 0.0), "turned round to face the crew when the first case opens")
	# Chapter 1 comes in when someone first sits at the terminal (M2).
	check(not g.book_chapters.has("easy_sql_1"), "chapter 1 isn't in the book before anyone sits at the terminal")
	level._on_desk_opened(level.player)
	await _frames(4)
	check(g.book_chapters.has("easy_sql_1"), "it comes in when someone first sits at the front desk terminal (M2)")
	# The phone and its sticky (G1-G3).
	var labels: Array = level.find_children("*", "Label3D", true, false).map(func(l): return l.text)
	check(labels.has(k.PHONE_LABEL % level.data.front_desk), "the desk phone shows the front desk's own extension (G1)")
	level.phone_note.take_sticky(level.player)
	check(g.spot_found("phone_note"), "reading the phone's sticky finds its spot")
	level.peek_puzzle.solved = true
	level.memo_puzzle.solved = true
	level._ask_caller()
	check(g.has_piece("caller", "table"), "read before Rourke asks, it still brings the caller's table")
	for i in 120:
		if g.notebook_written.any(func(w): return w.text == k.PHONE_NOTE and w.case == "caller"):
			break
		await _tree.physics_frame
	check(g.notebook_written.any(func(w): return w.text == k.PHONE_NOTE and w.case == "caller"), "and its note, on the caller's page now it's open (G3)")
	# Pencil notes under the caller's slot (G11).
	g.add_cell("extension", str(level.data.extension), {"name": "Harold Mercer", "extension": str(level.data.extension)})
	check(g.case_info("caller").blank.get("miss", "") == k.CALLER_NUMBER, "pointing at the right row's extension: the blank wants the name beside it (G11)")
	g.add_cell("name", "Iris Vale", {"name": "Iris Vale", "extension": "2301"})
	check(g.case_info("caller").blank.get("miss", "") == k.CALLER_OTHER % level.data.extension, "any other row: not that one")
	# The visitor book read before the caller's solved waits in Floor notes (M3).
	var book: Document = null
	for d in level.find_children("*", "Document", true, false):
		if d.title == "Visitor book":
			book = d
	book._note_clues(true)
	book.report_open(level.player)
	check(not g.case_info("last_visitor").get("open", false) and level.notebook.pages.section_text(NotebookPages.Page.TABLES).contains("every visitor is also logged"), "the visitor book read before the caller's solved: no case yet, its note in Floor notes (M3)")
	level._on_caller_found()
	await _frames(2)
	check(g.case_info("last_visitor").get("open", false) and g.case_info("last_visitor").title == k.BOOK_CASE, "the caller solved, the visitor case opens (G13)")
	check(not g.book_chapters.has("easy_sql_4"), "Newest first waits for Rourke's exchange at the desk (M4)")
	level._exchange_done = true
	level._book_check("easy_sql_4")
	await _frames(4)
	check(g.book_chapters.has("easy_sql_4"), "then it comes in")
	# The visitor slot (G15-G17).
	check(g.case_info("last_visitor").blank.prompt == k.VISITOR_SLOT, "the visitor case's slot (G15)")
	g.add_cell("name", "Contract IT crew", {"name": "Contract IT crew", "signed_in": "1997-10-15 23:04"})
	check(g.case_info("last_visitor").blank.get("miss", "") == k.VISITOR_OURS, "our own sign-in: the blank wants whoever came before us (G16)")
	g.add_cell("name", "P. Okafor", {"name": "P. Okafor", "signed_in": "1997-10-15 16:40"})
	check(g.case_info("last_visitor").blank.get("miss", "") == k.VISITOR_LEFT, "someone who signed out: the blank wants whoever never did (G17)")
	check(g.add_cell("name", "VALE, I.", {"name": "VALE, I.", "signed_in": level.data.vale_in}), "Vale's name fills it")
	await _frames(2)
	check(level.visitor_puzzle.solved and g.case_info("last_visitor").solved, "and answers the visitor log")
	# The memo sorted by the wrong column (G18, G19).
	var db: FacilityDB = level.db
	check(level.memo_sort_kind(db.execute("SELECT * FROM memo_fragments ORDER BY scanned_at")) == "scan", "sorted by scan time: the order they were scanned in (G18)")
	check(level.memo_sort_kind(db.execute("SELECT text FROM memo_fragments ORDER BY text DESC")) == "other", "sorted by another column (G19)")
	check(level.memo_sort_kind(db.execute("SELECT * FROM memo_fragments")) == "" and level.memo_sort_kind(db.execute("SELECT * FROM memo_fragments ORDER BY piece_no DESC")) == "", "not for the unsorted scraps, nor the memo backwards")
	level.queue_free()
	await _tree.process_frame


static func _pay(id: String) -> Array:
	return Commentary.NUDGES.get(id, {}).get("pay", [])


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)
