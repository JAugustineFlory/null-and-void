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
	check(text.contains(NotebookPages.PIECE_MISSING) and text.contains("A sticky") and not text.contains("ORDER BY ????") and text.contains("SELECT * FROM memo_fragments ???? ????;"), "a missing piece is ???? with where to look, in the slot and in the query")
	check(text.contains("[x]  Find the table") and text.contains("[  ]  Find how to sort") and text.contains("[  ]  Run it"), "the checklist ticks what's found")
	check(text.find(NotebookPages.CHECKLIST) > text.find(NotebookPages.QUERY_SO_FAR) and text.find("ORDER matters.") > text.find(NotebookPages.CHECKLIST), "the case comes first, then its checklist, then its notes")
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
	g.collect_piece("memo", "order", "A sticky")
	check(chip.count.text == "1/3" and chip.toast.visible and chip.toast_head.text == CaseChip.FOUND % [1, 3] and chip.toast_value.text == "The words that sort rows: ORDER BY", "a piece found: the count goes up and a card says what it was")
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
	holder.free()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)
