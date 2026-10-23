extends RefCounted
## The case board (Game's case pieces, the notebook's Cases tab, the HUD's case
## chip): pieces found in the world fill in a case's page and query, the HUD
## counts the main case's, solved cases are filed under Completed cases with
## their endings and other ways in, and once the job's over the work order is
## void and Tab opens on the case.

var _tree: SceneTree
var _check: Callable

const PIECES := [
	{"id": "table", "label": "The table", "value": "memo_fragments", "task": "Find the table", "where": "The scanner", "seen_in": "memo_fragments"},
	{"id": "order", "label": "The words that sort rows", "value": "ORDER BY", "task": "Find how to sort", "where": "A sticky"},
	{"id": "column", "label": "The column", "value": "piece_no", "task": "Find the column", "where": "The scanner too"},
]


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	test_pieces()
	test_board_page()
	test_endings_and_routes()
	test_job_over()
	test_chip()
	test_paper_pieces()
	test_growing_case()
	test_hint_pieces()
	test_floor_g_memo()
	test_book_before_bag()
	_game().new_run(1)


func _game() -> Node:
	return _tree.root.get_node("Game")


func test_pieces() -> void:
	print("Case board: pieces")
	var g := _game()
	g.new_run(3)
	check(g.collect_piece("memo", "order", "Desk"), "a piece found before its case says what pieces it has is kept")
	g.open_case("memo", "What does the memo say?", ["memo_fragments"])
	var fired := []
	var on_found := func(c, p): fired.append([c, p])
	g.piece_found.connect(on_found)
	g.set_pieces("memo", PIECES, "SELECT * FROM {table} {order} {column};", [{"id": "run", "text": "Run it"}])
	check(g.has_piece("memo", "order") and g.pieces_found("memo") == 1 and g.pieces_total("memo") == 3, "and it's in once the case has its pieces: 1/3")
	check(g.case_query("memo") == "SELECT * FROM ???? ORDER BY ????;", "the query so far writes in what's found and ???? for the rest")
	check(g.main_case() == "memo" and g.case_next("memo") == "Find the table", "it's the main case, and next is the first piece still to find")
	g.discover_table("memo_fragments", ["piece_no", "text"])
	check(g.has_piece("memo", "table") and not g.has_piece("memo", "column") and fired == [["memo", "table"]], "a piece seen in a table is found when the table turns up on the Tables page, and says so")
	check(not g.collect_piece("memo", "table") and fired.size() == 1, "a piece is only found once")
	g.collect_piece("memo", "column", "The scanner")
	check(g.case_query("memo") == "SELECT * FROM memo_fragments ORDER BY piece_no;" and g.case_next("memo") == "Run it", "all three in: the query is whole, and next is the step after the pieces")
	g.piece_found.disconnect(on_found)
	g.open_case("visit", "Who signed in last?")
	g.set_pieces("visit", [PIECES[0]], "", [], true)
	check(g.current_case() == "visit" and g.main_case() == "memo", "a side case can be the newest, but the HUD's main case stays the main one")
	g.open_case("caller", "Who called?")
	g.set_pieces("caller", [{"id": "ext", "label": "The number", "value": "ext. 1", "task": "Read it", "where": "The work order"}])
	g.solve_case("caller", "it was Mercer.")
	check(g.pieces_found("caller") == 1 and g.case_checklist("caller").all(func(l): return l.done), "solving a case completes its board and ticks its checklist, however they got there")
	check(g.completed_cases().size() == 1 and g.case_info("caller").get("fresh_solve", false), "it's a completed case, shown once as just solved")
	var saved: Dictionary = g.notebook_data()
	g.notebook_cases.clear()
	g.load_notebook(saved)
	check(g.pieces_found("memo") == 3 and g.case_query("memo").contains("piece_no"), "pieces are saved with the notebook")


func test_board_page() -> void:
	print("Case board: the Cases tab")
	var g := _game()
	g.new_run(4)
	g.open_case("memo", "What does the memo say?")
	g.set_pieces("memo", PIECES, "SELECT * FROM {table} {order} {column};", [{"id": "run", "text": "Run it"}])
	g.collect_piece("memo", "table", "The scanner")
	g.add_clue("memo", "ORDER matters.", "Sticky note")
	var pages := NotebookPages.new()
	var items := pages._case_items(g)
	var text := NotebookPages.text_of(items)
	check(text.contains(NotebookPages.PIECES_COUNT % [1, 3]) and text.contains("memo_fragments") and text.contains(NotebookPages.FROM % "The scanner"), "the case shows its count and each found piece with where it came from")
	var blocks: Control = items.filter(func(i): return i.name == "QuerySoFar")[0].get_node("QueryBlocks")
	var shown: Array = blocks.get_children().map(func(b): return NotebookPages.text_of([b]).strip_edges().replace("\n", " "))
	check(text.contains(NotebookPages.MAKE_QUERY) and blocks.get_meta("query") == "SELECT * FROM memo_fragments ???? ????;", "the case says to make a query, and builds it from blocks")
	check(shown == ["SELECT * FROM", "1 memo_fragments", "2 ????", "3 ????", ";"], "the query's own words, then a numbered block per piece: found ones filled in (%s)" % [shown])
	check(blocks.get_node("Piece1").get_meta("found") and not blocks.get_node("Piece2").get_meta("found"), "a found piece's block is filled, a missing one's gray")
	check(text.contains(NotebookPages.PIECE_MISSING) and text.contains("A sticky"), "a missing piece is ???? with where to look")
	check(text.contains("[x]  Find the table") and text.contains("[  ]  Find how to sort") and text.contains("[  ]  Run it"), "the checklist ticks what's found")
	check(text.find(NotebookPages.CHECKLIST) > text.find(NotebookPages.MAKE_QUERY) and text.find("ORDER matters.") > text.find(NotebookPages.CHECKLIST), "the case comes first, then its checklist, then its notes")
	var breaks := items.filter(func(i): return i.has_meta("break"))
	check(breaks.size() == 1 and breaks[0].get_meta("break") == "page" and items.find(breaks[0]) > items.find(items.filter(func(i): return i.name == "QuerySoFar")[0]), "the checklist starts the right-hand page")
	for i in items:
		i.free()
	pages.free()


func test_endings_and_routes() -> void:
	print("Case board: endings and other ways in")
	var g := _game()
	g.new_run(5)
	g.open_case("lab", "What happened in the lab?")
	g.set_pieces("lab", [PIECES[0]])
	g.set_endings("lab", [{"id": "lived", "name": "Rourke survived", "hint": "Not everyone has to fight"}, {"id": "died", "name": "Rourke died", "hint": ""}, {"id": "third", "name": "Something else", "hint": "Look closer"}])
	g.set_routes("lab", [{"id": "vent", "name": "The vent"}, {"id": "badge", "name": "His badge"}])
	check(g.find_route("lab", "vent") and not g.find_route("lab", "vent"), "another way in is found once a run")
	check(g.ever_found("route:lab:vent") and not g.ever_found("route:lab:badge"), "and kept on the player's profile")
	var pages := NotebookPages.new()
	var text := NotebookPages.text_of(pages._case_items(g))
	check(text.contains(NotebookPages.OTHER_WAYS % 1) and text.contains("The vent") and not text.contains("His badge") and text.contains("Not everyone has to fight") and not text.contains("Rourke survived"), "the page lists the ways in found and hides the rest; endings show only their nudge")
	g.reach_ending("lab", "lived")
	g.solve_case("lab", "he walked out.")
	var items := pages._case_items(g)
	text = NotebookPages.text_of(items)
	check(text.contains(NotebookPages.ENDING % ["Rourke survived", 1, 3]) and text.contains("Look closer"), "solved, it says which ending: Rourke survived, ending 1 of 3, the others still hidden")
	for i in items:
		i.free()
	g.case_info("lab").erase("fresh_solve")
	g.new_run(6)
	g.open_case("lab", "What happened in the lab?")
	g.set_pieces("lab", [PIECES[0]])
	g.set_endings("lab", [{"id": "lived", "name": "Rourke survived", "hint": ""}])
	g.set_routes("lab", [{"id": "vent", "name": "The vent"}])
	items = pages._case_items(g)
	text = NotebookPages.text_of(items)
	check(text.contains("Rourke survived") and text.contains("The vent"), "on a later run, the endings and ways in found before still show as found")
	for i in items:
		i.free()
	pages.free()


func test_job_over() -> void:
	print("Case board: the work order and where Tab opens")
	var g := _game()
	g.new_run(7)
	check(Notebook.default_page_for(g) == NotebookPages.Page.WORK_ORDER, "with no case open, Tab opens on the work order")
	g.set_todo("Sign in at the desk")
	g.open_case("memo", "What does the memo say?")
	check(Notebook.default_page_for(g) == NotebookPages.Page.CASES, "with a case open, Tab opens on the case")
	var form := _form_text(g)
	check(form.contains("Sign in at the desk") and not form.contains(WorkOrderForm.VOID_STAMP), "the work order has the job's own tasks")
	g.end_job()
	g.set_todo("Find a way out")
	form = _form_text(g)
	check(form.contains(WorkOrderForm.VOID_STAMP) and not form.contains("Find a way out"), "once the job's over it's void, and new tasks don't go on it")
	check(g.case_checklist("memo").any(func(l): return l.text == "Find a way out") and g.current_todo() == "Find a way out", "they go on the current case's checklist instead")
	g.solve_case("memo", "done.")
	g.case_info("memo").erase("fresh_solve")
	check(Notebook.default_page_for(g) == NotebookPages.Page.CASES, "and Tab keeps opening on Cases")
	var saved: Dictionary = g.notebook_data()
	g.job_over = false
	g.load_notebook(saved)
	check(g.job_over, "the job being over is saved with the notebook")


func _form_text(g: Node) -> String:
	var items := WorkOrderForm.build(g.ticket())
	var text := NotebookPages.text_of(items)
	for i in items:
		i.free()
	return text


func test_chip() -> void:
	print("Case board: the HUD's case chip")
	var g := _game()
	g.new_run(8)
	var chip := CaseChip.new()
	_tree.root.add_child(chip)
	check(not chip.chip.visible, "no main case, no chip")
	g.open_case("memo", "What does the memo say?")
	g.set_pieces("memo", PIECES, "", [{"id": "run", "text": "Run it"}])
	check(chip.chip.visible and chip.count.text == "0/3" and chip.title.text == "What does the memo say?" and chip.bar.get_child_count() == 3, "the main case: its question, 0/3 and a segment per piece")
	check(not chip.next.visible, "the next step isn't up until something happens")
	g.collect_piece("memo", "order", "A sticky")
	check(chip.count.text == "1/3" and chip.toast.visible and chip.toast_head.text == CaseChip.FOUND % [1, 3] and chip.toast_value.text == "The words that sort rows: ORDER BY", "a piece found: the count goes up and a card says what it was")
	check(chip.next.visible and chip.next.text == CaseChip.NEXT % "Find the table", "and the next step shows for a moment")
	chip._end_next(chip._next_turn)
	check(chip.chip.visible and not chip.next.visible and chip.count.text == "1/3", "then the chip is just the case and its count")
	chip.brief_next()
	var turn: int = chip._next_turn
	chip.brief_next()
	chip._end_next(turn)
	check(chip.next.visible, "a newer brief show isn't cut short by an older one's time running out")
	chip._end_next(chip._next_turn)
	chip.set_allowed(false)
	g.collect_piece("memo", "table")
	check(not chip.chip.visible and not chip.toast.visible, "hidden while a terminal fills the view")
	chip.set_allowed(true)
	check(chip.chip.visible and chip.toast.visible and chip.toast_head.text == CaseChip.FOUND % [2, 3], "and the piece found meanwhile is said once it's back")
	g.open_case("side", "A side case")
	g.set_pieces("side", [PIECES[0]], "", [], true)
	g.collect_piece("side", "table")
	check(chip.title.text == "What does the memo say?" and chip.toast_head.text == CaseChip.FOUND_SIDE, "a side case's piece gets a card, but the chip keeps counting the main case")
	g.solve_case("memo", "done.")
	check(not chip.chip.visible, "solved: nothing to count")
	chip.free()


func test_paper_pieces() -> void:
	print("Case board: E on a paper notes its pieces")
	var g := _game()
	g.new_run(9)
	g.open_case("memo", "What does the memo say?")
	g.set_pieces("memo", PIECES)
	var holder := Node3D.new()
	_tree.root.add_child(holder)
	var card := Document.place(holder, Vector3.ZERO, 0.0, "ScanRight", ["Saved in memo_fragments."], true, "brochure")
	card.pieces = [{"case": "memo", "piece": "table"}, {"case": "memo", "piece": "column"}]
	card.clues = [{"case": "memo", "text": "Scraps are saved in memo_fragments."}]
	var reads := []
	card.read_by.connect(func(p): reads.append(p))
	check(card.get_prompt(null) == "[E] %s    [X] %s" % [Document.NOTE_IT % "ScanRight", Document.READ_IT], "a paper holding pieces offers E to note it, X to read it")
	card.collect(null)
	check(g.has_piece("memo", "table") and g.has_piece("memo", "column") and g.case_info("memo").pieces[0].from == "ScanRight", "E notes both its pieces, from the paper")
	check(g.case_info("memo").clues.size() == 1 and reads.size() == 1, "its clues go on the case page too, and it counts as read")
	check(card.uncollected().is_empty() and card.get_prompt(null).contains("Read: ScanRight"), "with its pieces in, E reads it as any paper")
	var side := Document.place(holder, Vector3.ZERO, 0.0, "Rack card", ["Temps are logged in racks."], true, "brochure")
	side.pieces = [{"case": "hot", "piece": "table"}]
	g.set_pieces("hot", [PIECES[0]], "", [], true)
	check(side.notable().is_empty() and not side.get_prompt(null).contains(Document.NOTE_IT % "Rack card"), "a paper for a case nobody has open yet is read, not noted unseen")
	side.clues = [{"case": "hot", "opens": "Why is it hot?", "text": "Racks run hot."}]
	check(side.notable().size() == 1, "unless the paper itself opens that case")
	holder.free()


func test_growing_case() -> void:
	print("Case board: a case that grows keeps what's found")
	var g := _game()
	g.new_run(10)
	g.open_case("memo", "What does the memo say?")
	g.set_pieces("memo", [PIECES[0]], "SELECT * FROM {table};", [{"id": "peek", "text": "Run it"}])
	g.collect_piece("memo", "table", "The scanner")
	g.tick_step("memo", "peek")
	g.collect_piece("memo", "column", "The scanner")
	g.set_pieces("memo", PIECES, "SELECT * FROM {table} {order} {column};", [{"id": "peek", "text": "Run it"}, {"id": "run", "text": "Run it sorted"}])
	check(g.has_piece("memo", "table") and g.case_info("memo").pieces[0].from == "The scanner", "a piece found keeps its place, and where it came from, when the case grows")
	check(g.has_piece("memo", "column") and not g.has_piece("memo", "order"), "and one found before the case had it is in too")
	check(g.case_checklist("memo").any(func(l): return l.text == "Run it" and l.done), "a step ticked stays ticked")
	var named: Array = PIECES.map(func(p): return p.duplicate())
	named[2]["blank"] = "enter_column_name"
	g.open_case("named", "Named blanks")
	g.set_pieces("named", named, "SELECT * FROM {table} {order} {column};")
	check(g.case_query("named") == "SELECT * FROM ???? ???? enter_column_name;", "a missing value is named as its hint names it; a missing word is ????")
	g.collect_piece("named", "table")
	g.set_assemble("named", false)
	check(g.has_piece("named", "table") and g.case_query("named") == "SELECT * FROM ???? ???? enter_column_name;", "under pressure the page keeps the piece found, but the query so far stays the bare shape")
	var pages := NotebookPages.new()
	var items := pages._case_items(g)
	check(NotebookPages.text_of(items).contains("memo_fragments"), "and the piece itself still shows on the page")
	var qb: Control = items.filter(func(i): return i.name == "QuerySoFar")[0].get_node("QueryBlocks")
	check(not qb.get_node("Piece1").get_meta("found"), "but its block in the query stays gray")
	check(qb.get_children().all(func(b): return b.find_child("Number", true, false) == null), "and no block is numbered, so the page doesn't say which piece goes where")
	for i in items:
		i.free()
	pages.free()
	g.set_assemble("named", true)
	check(g.case_query("named").contains("FROM memo_fragments"), "a case that assembles writes it in")


func test_hint_pieces() -> void:
	print("Case board: a hint that shows a piece finds it")
	var g := _game()
	g.new_run(11)
	g.open_case("memo", "What does the memo say?")
	g.set_pieces("memo", PIECES, "SELECT * FROM {table} {order} {column};")
	g.note_hint("memo", "Replace enter_column_name with the column. ORDER BY sorts them, and memo_fragments holds them.")
	check(g.pieces_found("memo") == 0, "words in a hint's prose don't count, only the query it prints")
	g.note_hint("memo", "The shape of it:\n    [color=#ffffff]SELECT * FROM memo_fragments ORDER BY enter_column_name;[/color]")
	check(g.has_piece("memo", "table") and g.has_piece("memo", "order") and not g.has_piece("memo", "column") and g.case_info("memo").pieces[0].from == "SYSOP", "the hint's query shows the table and ORDER BY: they're found, from SYSOP")
	g.open_case("hot", "Why is it hot?")
	g.set_pieces("hot", [{"id": "more", "label": "More than", "value": ">", "task": "t", "where": "w"}, {"id": "limit", "label": "The limit", "value": "45", "task": "t", "where": "w"}])
	g.note_hint("hot", "[color=#ffffff]SELECT id FROM racks WHERE temp_c > enter_limit;[/color]")
	check(g.has_piece("hot", "more") and not g.has_piece("hot", "limit"), "a sign shows as is; a number only as a whole number")
	g.see_table_pieces("visitors", TerminalUI.QUERY_BY % "Sam")
	check(not g.has_piece("memo", "column"), "a crewmate's query finds only pieces seen in the table it read")
	g.open_case("visit", "Who signed in last?")
	g.set_pieces("visit", [{"id": "table", "label": "The table", "value": "visitors", "task": "t", "where": "w", "seen_in": "visitors"}])
	g.see_table_pieces("visitors", TerminalUI.QUERY_BY % "Sam")
	check(g.has_piece("visit", "table") and g.case_info("visit").pieces[0].from == "Sam's query" and not g.notebook_tables.has("visitors"), "in co-op a crewmate's query finds a table piece on every board, without filling your Tables page")
	var term := Terminal.new()
	var pz := Puzzle.new("p", "SELECT * FROM memo_fragments ORDER BY piece_no", ["text"], true, ["The shape:\n    [color=#ffffff]SELECT * FROM memo_fragments ORDER BY piece_no;[/color]"])
	pz.case_id = "memo"
	term.puzzles = [pz]
	_tree.root.add_child(term)
	term.print_line(TerminalUI.sysop("Something else entirely."), "hint")
	check(not g.has_piece("memo", "column"), "a SYSOP line that isn't one of the terminal's hints finds nothing")
	term.print_line(TerminalUI.sysop(pz.hints[0]), "hint")
	check(g.has_piece("memo", "column"), "a hint shown on a terminal's screen finds its pieces on that machine, whoever asked (the screen is shared in co-op)")
	term.free()
	check(Game.hint_shows("WHERE zone = 'b2'", "B2") and not Game.hint_shows("WHERE zone = 'b21'", "B2"), "a value matches as a whole word, any case")


## Floor G's memo: the board asks only for the peek's table until the scraps come
## out of order, and the sort and the column come from the world, not the Tables page.
func test_floor_g_memo() -> void:
	print("Case board: the memo grows after the peek")
	var g := _game()
	g.new_run(12)
	var l0: GDScript = load("res://scripts/levels/level_0.gd")
	g.open_case("memo", "What does the memo say?", ["memo_fragments"])
	g.set_pieces("memo", l0.MEMO_PEEK_PIECES, l0.MEMO_PEEK_QUERY, l0.MEMO_PEEK_STEPS)
	check(g.pieces_total("memo") == 1 and g.case_query("memo") == "SELECT * FROM enter_table_name;" and not _case_text(g).contains("ORDER"), "before the peek the memo's board asks only for the table, and names no sort")
	g.discover_table("memo_fragments", ["text", "piece_no", "scanned_at"])
	g.set_pieces("memo", l0.MEMO_PIECES, l0.MEMO_QUERY, l0.MEMO_STEPS)
	check(g.has_piece("memo", "table") and not g.has_piece("memo", "column") and g.pieces_total("memo") == 3, "after it, the table stays found and the column isn't handed over by the Tables page")
	check(l0.VISITOR_PIECES.all(func(p): return p.id != "column") and l0.VISITOR_QUERY.contains("ORDER BY enter_column_name"), "the visitor case leaves choosing its column to the player")



## In the garage, chapters earned on an earlier run stay out of the Books tab
## until the shop bag's been taken.
func test_book_before_bag() -> void:
	print("Case board: no book before the shop bag")
	var g := _game()
	g.new_run(13)
	var net := _tree.root.get_node_or_null("Net")
	var had_profile: bool = net != null and net.profile != null
	if had_profile:
		net.profile.earned.append("chapter:easy_sql_0")
	var pages := NotebookPages.new()
	_tree.root.add_child(pages)
	g.before_book = true
	check(pages._chapters_had(g).is_empty(), "before the shop bag's taken, the Books tab has nothing in it")
	g.before_book = false
	check(not had_profile or pages._chapters_had(g).has("easy_sql_0"), "once it's taken, chapters earned before are back")
	if had_profile:
		net.profile.earned.erase("chapter:easy_sql_0")
	g.new_run(14)
	check(not g.before_book, "a new run starts with the book (a run started past the garage has it)")
	pages.free()


## The Cases tab's text for the current case.
func _case_text(g: Node) -> String:
	var pages := NotebookPages.new()
	var items := pages._case_items(g)
	var text := NotebookPages.text_of(items)
	for i in items:
		i.free()
	pages.free()
	return text


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)
