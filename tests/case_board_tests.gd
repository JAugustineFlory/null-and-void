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
	test_cell_slots()
	test_board_page()
	test_endings_and_routes()
	test_job_over()
	test_chip()
	test_query_on_screen()
	test_task_titles()
	test_paper_pieces()
	test_growing_case()
	test_hint_pieces()
	test_floor_g_memo()
	test_one_case_at_a_time()
	test_book_before_bag()
	await test_notebook_tabs()
	_game().new_run(1)


func _game() -> Node:
	return _tree.root.get_node("Game")


static func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


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
	check(g.current_case() == "memo" and g.main_case() == "memo", "a side case opened later doesn't take the page: the case in hand stays the current one")
	check(g.side_cases().map(func(c): return c.id) == ["visit"], "it's listed as a side case alongside it")
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
	check(chip.count.text == "1/3" and chip.toast.visible and chip.toast_head.text == CaseChip.FOUND % [1, 3] and chip.toast_value.get_parsed_text() == "The words that sort rows: ORDER BY", "a piece found: the count goes up and it slides up, saying what it was")
	check(chip.toast.anchor_top == 1.0 and chip.toast.anchor_left == 0.5, "it slides up at the screen's bottom edge")
	check(chip.toast_value.text.contains(PieceKind.hex(PieceKind.KEYWORD)) and chip.toast_value.text.contains("[b]"), "in its kind's color and cue (ORDER BY is a keyword: bold)")
	check(not chip.toast_by.visible, "this player's own find names no one")
	var up_tween: Tween = chip._toast_tween
	chip.toast.gui_input.emit(_click())
	check(not up_tween.is_valid() and chip._toast_tween.is_running(), "a click on it starts sliding it back down")
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
	g.collect_piece("memo", "table", "", "Dana")
	check(chip.chip.visible and chip.toast.visible and chip.chip.custom_minimum_size.x == CaseChip.NARROW, "at a terminal the case stays up, narrower, and a find still slides up: the terminal stays open")
	check(chip.toast_head.text == CaseChip.FOUND % [2, 3] and chip.toast_by.visible and chip.toast_by.text == CaseChip.FOUND_BY % "Dana", "a crewmate's find says who found it (G21)")
	chip.set_allowed(true)
	check(chip.chip.custom_minimum_size.x == CaseChip.WIDE, "and it's full width again once the terminal's put away")
	g.open_case("side", "A side case")
	g.set_pieces("side", [PIECES[0]], "", [], true)
	g.collect_piece("side", "table")
	check(chip.title.text == "What does the memo say?" and chip.toast_head.text == CaseChip.FOUND_SIDE, "a side case's piece gets a card, but the chip keeps counting the main case")
	g.solve_case("memo", "done.")
	check(not chip.chip.visible, "solved: nothing to count")
	chip.free()


## The query with blanks under the case chip (puzzle-flow spec, section 5), the
## answer's slide-up, the typing line's example (policy P8), and the kinds' colors.
func test_query_on_screen() -> void:
	print("Case board: the query on screen and the slide-up")
	var g := _game()
	g.new_run(8)
	var chip := CaseChip.new()
	_tree.root.add_child(chip)
	var pieces: Array = PIECES.duplicate(true)
	pieces[2]["blank"] = "enter_column_name"
	g.open_case("memo", "What does the memo say?")
	g.set_pieces("memo", pieces, "SELECT * FROM {table} {order} {column};")
	check(g.case_selected() == "memo", "with nothing picked in the notebook, the selected case is the main one")
	check(not chip.query_panel.visible, "the query isn't up on its own: the screen stays clear")
	chip.hold_query(true)
	check(chip.query_panel.visible and chip.query.get_parsed_text() == g.case_query("memo"), "a paper of the case in hand: its query is up, word for word the case page's (%s)" % chip.query.get_parsed_text())
	check(chip.query.text.contains(PieceKind.hex(PieceKind.TABLE, true)) and chip.query.text.contains(PieceKind.hex(PieceKind.COLUMN, true)), "each blank in the faded color of what fits it")
	chip.set_allowed(false)
	check(not chip.query_panel.visible, "at a terminal it gives way to the one over the typing line")
	chip.set_allowed(true)
	check(chip.query_panel.visible, "and comes back after")
	chip.hold_query(false)
	check(not chip._query_on, "put down: it fades")
	g.collect_piece("memo", "table")
	check(chip.query_panel.visible and chip.query.get_parsed_text().contains("FROM memo_fragments") and chip._fresh_piece == "table", "a piece found: the query comes up with it written in")
	chip._query_turn += 1  # as if its time ran out
	chip._set_query(false)
	g.selected_case = "nope"
	check(g.case_selected() == "memo", "a pick that isn't an open case falls back to the main one")
	g.selected_case = ""
	# The answer slides up too, and a crewmate's says who.
	g.set_blank("memo", "Who wrote it?", ["harold"], "Harold Mercer")
	check(g.add_answer("Signed, Harold Mercer", "document") and chip.toast.visible and chip.toast_head.text == "Who wrote it?" and chip.toast_value.get_parsed_text() == "Harold Mercer" and not chip.toast_by.visible, "an answer slides up under its question")
	g.answer_shared.emit("memo", "Kit")
	check(chip.toast_by.visible and chip.toast_by.text == CaseChip.FOUND_BY % "Kit", "a crewmate's answer names them")
	chip.free()
	# The typing line: the selected case's shape, above it and as its grey example.
	var ui := TerminalUI.new()
	_tree.root.add_child(ui)
	g.new_run(8)
	ui.show_case_query()
	check(ui._input.placeholder_text == TerminalUI.EXAMPLE and not ui._case_line.visible, "no case: the plain example, with no SELECT * in it (P8)")
	check(not TerminalUI.EXAMPLE.contains("*"), "the example never shows the refused query")
	g.open_case("memo", "What does the memo say?")
	g.set_pieces("memo", PIECES, "SELECT * FROM {table} {order} {column};")
	check(ui._input.placeholder_text == g.case_query("memo") and ui._case_line.visible and ui._case_line.get_parsed_text() == g.case_query("memo"), "a case: its query is the example and sits over the typing line")
	ui.free()
	# Kinds.
	check(PieceKind.of_piece({"value": "visitors", "seen_in": "visitors"}) == PieceKind.TABLE and PieceKind.of_piece({"value": "extension", "seen_in": "staff_directory"}) == PieceKind.COLUMN, "a piece seen in a table is that table, or one of its columns")
	check(PieceKind.of_piece({"value": "ORDER BY"}) == PieceKind.KEYWORD and PieceKind.of_piece({"value": "LIMIT 5"}) == PieceKind.KEYWORD and PieceKind.of_piece({"value": ">"}) == PieceKind.KEYWORD, "query words and signs are keywords")
	check(PieceKind.of_piece({"value": "fault", "blank": "enter_status"}) == PieceKind.VALUE and PieceKind.of_piece({"value": "DC-7"}) == PieceKind.VALUE and PieceKind.of_piece({"value": "lights", "blank": "enter_table_name"}) == PieceKind.TABLE, "the rest are values; a blank's name says what it wants")
	check(PieceKind.of_piece({"value": "x", "kind": "column"}) == PieceKind.COLUMN, "a piece can say its own kind")
	var cues := [PieceKind.bbcode("a", PieceKind.KEYWORD), PieceKind.bbcode("a", PieceKind.TABLE), PieceKind.bbcode("a", PieceKind.COLUMN), PieceKind.bbcode("a", PieceKind.VALUE)]
	check(cues[0].begins_with("[b]") and cues[1].begins_with("[bgcolor") and cues[2].begins_with("[u]") and cues[3].begins_with("[i]"), "each kind has a shape cue as well as a color")


## A task's title says how the crew feels; its details say what to do (Augustine,
## 2026-11-05: plan/approvals/task-titles.md). The chip shows "Next: <title>" for a
## moment; the notebook's checklist and the work order show the title, with the
## details in pencil under it until it's ticked.
func test_task_titles() -> void:
	print("Case board: task titles and details")
	var g := _game()
	g.new_run(8)
	var hud := HUD.new()
	_tree.root.add_child(hud)
	hud.todo("Our first big job", "Read the work order in your notebook")
	check(g.current_todo() == "Read the work order in your notebook" and g.notebook_todo[-1].title == "Our first big job", "a task keeps its details as what to do, and its title")
	var chip: CaseChip = hud.case_chip
	check(chip.chip.visible and chip.next.visible and chip.next.text == CaseChip.NEXT % "Our first big job" and not chip.title.visible, "with no case open, the chip shows just \"Next:\" and the title for a moment")
	chip._end_next(chip._next_turn)
	check(not chip.chip.visible, "then it goes")
	var form := NotebookPages.text_of(WorkOrderForm.build(g.ticket()))
	check(form.contains("[  ]  Our first big job") and form.contains("Read the work order in your notebook"), "the work order's crew notes: the title, the details under it")
	hud.todo("Showtime. Act like experts.", "Get in the van")
	form = NotebookPages.text_of(WorkOrderForm.build(g.ticket()))
	check(form.contains("[x]  Our first big job") and not form.contains("Read the work order in your notebook") and form.contains("Get in the van"), "ticked, it's just the title; the next one has its details")
	hud.todo("Sit down with the book")
	check(g.notebook_todo[-1].get("title", "") == "" and g.current_todo() == "Sit down with the book", "one string is a task with no title")
	# Once the job's over, a task goes on the case's checklist: the title, then the details.
	g.end_job()
	g.open_case("lab", "Get out of the lab")
	hud.todo("Still trapped. Think fast.", "Find out what's wrong with the lab door, at Dr. Vale's terminal")
	check(g.case_next("lab") == "Still trapped. Think fast." and chip.next.text == CaseChip.NEXT % "Still trapped. Think fast.", "the case's next step is the task's title")
	var lines: Array = g.case_checklist("lab")
	check(lines[-1].title == "Still trapped. Think fast." and lines[-1].text.ends_with("at Dr. Vale's terminal"), "and its checklist line has both")
	hud.free()


func test_paper_pieces() -> void:
	print("Case board: E on a paper notes its pieces")
	var g := _game()
	g.new_run(9)
	g.open_case("memo", "What does the memo say?")
	g.set_pieces("memo", PIECES)
	var holder := Node3D.new()
	_tree.root.add_child(holder)
	var card := Document.place(holder, Vector3.ZERO, 0.0, "ScanRight", ["Feed the scraps in.", "Saved in memo_fragments.", "piece_no numbers them; ORDER BY sorts."], true, "brochure")
	card.pieces = [{"case": "memo", "piece": "table"}, {"case": "memo", "piece": "column"}, {"case": "memo", "piece": "order"}]
	card.clues = [{"case": "memo", "text": "Scraps are saved in memo_fragments."}]
	var reads := []
	card.read_by.connect(func(p): reads.append(p))
	check(card.get_prompt(null) == "[E] Read: ScanRight", "a paper holding pieces is read like any paper: E picks it up")
	check(card.marks_case("memo") and card.marked() and not card.marks_case("other"), "it matters to the memo case, so it shows the marker while that case is selected")
	card._note_clues()  # what picking it up does (pick_up / open_reader)
	card._report_read(null)
	check(g.pieces_found("memo") == 0, "reading it doesn't take its pieces: they're clicked (F)")
	check(g.case_info("memo").clues.size() == 1 and reads.size() == 1, "its clues go on the case page, and it counts as read")
	var lines := card.lines()
	check(lines[0].get("piece_kind", -1) == -1 and lines[1].get("piece_kind", -1) == PieceKind.TABLE and lines[2].has("piece_kind"), "each line holding a piece says its kind, for the pointer's highlight; the rest don't")
	check(not card.take_line(null, 0) and g.pieces_found("memo") == 0, "clicking a line with no piece on it takes nothing")
	check(card.take_line(null, 1) and g.has_piece("memo", "table") and not g.has_piece("memo", "column") and g.case_info("memo").pieces[0].from == "ScanRight", "clicking the line with the table takes just that piece, from the paper")
	check(not card.take_line(null, 1), "and only once")
	check(card.take_line(null, 2) and g.has_piece("memo", "column") and g.has_piece("memo", "order"), "a line with two pieces on it takes both")
	var view := DocumentView.new()
	_tree.root.add_child(view)
	view.add_lines(card.lines())
	var rows := view.body.get_children().filter(func(r): return r.get("piece_kind") != null)
	var took := []
	view.take_requested.connect(func(t): took.append(t))
	var table_row = rows.filter(func(r): return r.piece_kind == PieceKind.TABLE)[0]
	var plain_row = rows.filter(func(r): return r.piece_kind == -1)[0]
	check(table_row.band() != plain_row.band() and table_row.band().to_html(false) == PieceKind.color(PieceKind.TABLE).to_html(false), "pointed at, a piece's line is highlighted in its kind's color; others in the notebook's yellow")
	table_row.size = Vector2(400, 30)
	plain_row.size = Vector2(400, 30)
	var click := _click()
	click.position = Vector2(20, 10)
	table_row._gui_input(click)
	plain_row._gui_input(click)
	check(took == ["Saved in memo_fragments."], "clicking a piece's line asks to take it; clicking any other line doesn't")
	check(not view.marker.visible, "no marker until the reader says the paper matters")
	view.set_marker(true)
	check(view.marker.visible and view.marker.position.y == 0.0, "the marker: a tab at the paper's top edge")
	view.free()
	check(Document._shows("ALERT if temp_c > 40", ">") and Document._shows("reads over 40°C", "40") and not Document._shows("LIGHTING CIRCUITS", "lights") and Document._shows("the table lights.", "lights"), "a piece's words are matched whole, any case")
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


## Floor G's memo is two cases, one idea each: read the scraps, then put them in
## order. The sort and the column come from the world, not the Tables page.
func test_floor_g_memo() -> void:
	print("Case board: the memo, then putting it in order")
	var g := _game()
	g.new_run(12)
	var l0: GDScript = load("res://scripts/levels/level_0.gd")
	g.open_case("memo", "What does the memo say?", ["memo_fragments"], l0.OBJ_MEMO)
	g.set_pieces("memo", l0.MEMO_PEEK_PIECES, l0.MEMO_PEEK_QUERY, l0.MEMO_PEEK_STEPS)
	check(g.pieces_total("memo") == 1 and g.case_query("memo") == "SELECT * FROM enter_table_name;" and not _case_text(g).contains("ORDER"), "the first case asks for the table and nothing else: no sort anywhere on it")
	check(_case_text(g).contains(l0.OBJ_MEMO), "what to do about it is the top line of its page")
	g.discover_table("memo_fragments", ["text", "piece_no", "scanned_at"])
	g.solve_case("memo", "one scrap to a row.")
	g.collect_piece("memo_order", "table", "your first query")
	g.open_case("memo_order", "Which scrap comes first?", ["memo_fragments"], l0.OBJ_ORDER)
	g.set_pieces("memo_order", l0.ORDER_PIECES, l0.ORDER_QUERY, l0.ORDER_STEPS)
	check(g.has_piece("memo_order", "table") and not g.has_piece("memo_order", "column") and g.pieces_total("memo_order") == 3, "the sort is the next case, with the table already in hand and the column still to find")
	check(g.current_case() == "memo_order" and not _case_text(g).contains("What does the memo say?"), "and it has the page to itself: the one just read is filed")
	check(l0.VISITOR_PIECES.any(func(p): return p.id == "column" and p.value == "signed_in") and l0.VISITOR_QUERY == "SELECT name, {column} FROM {table} ORDER BY {column} {desc} {limit};", "after the caller, the visitor case names its columns, the sign-in time a piece of its own (G22, G23)")



## The Cases tab holds one case: the case in hand. Everything solved is in the
## archive, and a side case is a line under it, not a second page (Augustine,
## 2026-10-26).
func test_one_case_at_a_time() -> void:
	print("Case board: one case on the page")
	var g := _game()
	g.new_run(15)
	g.open_case("first", "What does the memo say?", [], "Read the memo at the front desk")
	g.set_pieces("first", [PIECES[0]], "SELECT * FROM {table};", [{"id": "run", "text": "Run it"}])
	var pages := NotebookPages.new()
	_tree.root.add_child(pages)
	var text := _case_text(g)
	check(text.contains("Read the memo at the front desk") and text.find("Read the memo at the front desk") < text.find("What does the memo say?"),
		"what to do about the case is its top line, with the question under it")
	check(text.contains(NotebookPages.MAKE_QUERY) and not text.contains(NotebookPages.QUERY_READY % "terminal"), "with a word still missing, the page says to build the query")
	g.set_case_note("first", "", "The words are out there.", "front desk terminal")
	check(_case_text(g).contains("The words are out there."), "while no word is found, the line about where they are sits under the pieces")
	g.collect_piece("first", "table", "The scanner")
	text = _case_text(g)
	check(text.contains(NotebookPages.QUERY_READY % "front desk terminal") and not text.contains("The words are out there."),
		"with every word in, it says the query is whole and which terminal takes it, and the line about finding words is gone")
	# A side case and the next case open; neither takes the page from the case in hand.
	g.open_case("side", "Who signed in last?", [], "Find who signed in last")
	g.set_pieces("side", [PIECES[0]], "SELECT * FROM {table};", [], true)
	text = _case_text(g)
	check(g.current_case() == "first" and text.contains("What does the memo say?") and not text.contains("Find who signed in last"),
		"a side case doesn't take the page")
	check(pages.bookmarks(g).any(func(m): return m.id == "side" and m.state == "side"), "it has a bookmark of its own instead, in the side cases' color")
	g.solve_case("first", "the scraps are in memo_fragments.")
	g.open_case("second", "Which scrap comes first?", [], "Put the scraps in order")
	g.set_pieces("second", [PIECES[2]], "SELECT * FROM memo_fragments ORDER BY {column};", [])
	pages.file_solved()
	g.case_info("first").erase("fresh_solve")
	text = _case_text(g)
	check(text.contains("Put the scraps in order") and not text.contains("What does the memo say?"), "once a case is solved the next one has the page")
	var items := pages._case_items(g)
	check(items.any(func(i): return i is Button and i.text == NotebookPages.COMPLETED % 1), "and the one before it is in the archive")
	for i in items:
		i.free()
	# The HUD says the same sentence as the page.
	var chip := CaseChip.new()
	_tree.root.add_child(chip)
	check(chip.title.text == "Put the scraps in order", "the HUD's case chip says what to do in those same words")
	chip.free()
	pages.free()


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
## Three tabs (Work order, Cases, Books). On Cases, each case on the floor is a
## bookmark in the order it opened, then Floor notes; picking one selects that
## case. A case page shows its tables; a filled blank says how it was found
## (plan/teaching/puzzle-flow-v0.10.md section 6).
func test_notebook_tabs() -> void:
	print("Notebook: three tabs, bookmarks, Floor notes")
	var g := _game()
	g.new_run(16)
	g.mark_floor_start("level_0")
	check(NotebookPages.TAB_NAMES == ["Work order", "Cases", "Books"], "the notebook has three tabs: Work order, Cases and Books")
	var pages := NotebookPages.new()
	_tree.root.add_child(pages)
	await _tree.process_frame
	check(pages.book.bookmarks.get_child_count() == 0 and not pages.book.bookmarks.visible, "the work order has no bookmarks")
	var link: Button = null
	for i in pages.book.right.find_children("*", "Button", true, false) + pages.book.left.find_children("*", "Button", true, false):
		if i.name == "FieldNotesLink":
			link = i
	check(link != null and link.text == NotebookPages.FIELD_NOTES_LINK, "the work order links to Field Notes")
	if link:
		link.pressed.emit()
		await _tree.process_frame
		check(pages.current_page() == NotebookPages.Page.FIELD_NOTES and pages.current_tab() == 0, "which opens under the work order's tab")
	g.discover_table("visitors", ["name", "signed_in"])
	g.discover_table("doors", ["zone"])
	g.add_note("order_by")
	g.note_aside("PA", "The lobby closes at seven.", "voice")
	g.open_case("first", "Who called?", ["visitors"], "Find the caller")
	g.open_case("second", "Who signed in last?", [], "Find the last visitor")
	g.open_case("side", "Why is the break room dark?", [], "Look into the dark break room")
	g.set_pieces("side", [PIECES[0]], "SELECT * FROM {table};", [], true)
	g.set_blank("first", "The caller", ["hardy"], "HARDY", {"column": "name", "values": ["HARDY"]})
	pages.show_page(NotebookPages.Page.CASES)
	var marks: Array = pages.bookmarks(g)
	check(marks.map(func(m): return m.id) == ["first", "second", "side", NotebookPages.NOTES_MARK], "each case is a bookmark in the order it opened, then Floor notes last")
	check(marks[0].state == "open" and marks[2].state == "side" and marks[3].label == NotebookPages.FLOOR_NOTES, "a side case and Floor notes have their own look")
	check(pages.book.bookmarks.visible and pages.book.bookmarks.get_child_count() == 4, "they show down the left edge of the Cases tab")
	var shown: Button = pages.book.bookmarks.get_node("Mark_" + g.current_case())
	check(shown.get_meta("selected"), "the tab opens on the case being worked on, its bookmark picked")
	pages.book.bookmarks.get_node("Mark_first").pressed.emit()
	check(g.selected_case == "first" and g.case_selected() == "first", "picking a bookmark selects its case (the query on screen follows it)")
	var text := NotebookPages.text_of(pages.book.left.get_children() + pages.book.right.get_children())
	check(pages.book.bookmarks.get_node("Mark_first").get_meta("selected") and text.contains("Find the caller"), "and turns to its page")
	check(text.contains("visitors") and text.contains("signed_in") and not text.contains("zone"), "a case page shows the tables it needs, with their columns, and no others")
	check(not text.contains("The lobby closes at seven."), "a note with no case isn't on the case page")
	g.write_note("", "HARDY rang at 9", "mine")
	check(g.notebook_written[-1].case == "first", "a note written now goes on the selected case")
	pages.book.bookmarks.get_node("Mark_" + NotebookPages.NOTES_MARK).pressed.emit()
	text = NotebookPages.text_of(pages.book.left.get_children() + pages.book.right.get_children())
	check(text.contains(NotebookPages.FLOOR_NOTES) and text.contains("The lobby closes at seven.") and text.contains("Sticky notes") and text.contains("doors"), "Floor notes holds the notes with no case, the sticky notes and every table found")
	check(g.selected_case == "first", "and leaves the selected case as it was")
	pages.show_page(NotebookPages.Page.TABLES)
	check(pages.current_page() == NotebookPages.Page.CASES and pages.mark == NotebookPages.NOTES_MARK, "what opened the old Tables tab opens Floor notes")
	# A cell found fills the blank, with the query that found it.
	check(g.add_cell("name", "HARDY", {"name": "HARDY"}, "SELECT name FROM visitors WHERE signed_in > 9;"), "the caller's cell fills the blank")
	g.case_info("first").blank["by"] = "Sam"
	pages.mark = "first"
	pages.refresh()
	text = NotebookPages.text_of(pages.book.left.get_children() + pages.book.right.get_children())
	check(text.contains(NotebookPages.FOUND_WITH % "SELECT name FROM visitors WHERE signed_in > 9;"), "the filled blank says the query that found it")
	check(text.contains(NotebookPages.FOUND_BY % "Sam"), "and in co-op, who found it")
	g.solve_case("first", "HARDY")
	g.case_info("first").erase("fresh_solve")
	pages.mark = ""
	pages.refresh()
	marks = pages.bookmarks(g)
	check(marks.any(func(m): return m.id == "first" and m.state == "solved") and g.case_selected() != "first", "a solved case keeps its bookmark for the floor, ticked, and is no longer the selected one")
	g.mark_floor_start("level_1")
	check(not pages.bookmarks(g).any(func(m): return m.id == "first"), "on the next floor it's only in the archive")
	pages.free()


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


## Click to solve: a find step's slot is filled by pointing at the cell that holds
## its answer, in the column the case asks about, whatever query put it on screen.
func test_cell_slots() -> void:
	print("Case board: click the answer's cell")
	var g := _game()
	g.new_run(41)
	var db := FacilityDB.new()
	db.run_silent("CREATE TABLE ctl (id TEXT, zone TEXT, status TEXT)")
	db.run_silent("INSERT INTO ctl VALUES ('DC-1', 'A', 'ok'), ('DC-15', 'C', 'fault'), ('DC-7', 'C', 'ok'), ('DC-2', 'B', 'fault')")
	var p := Puzzle.new("ctl", "SELECT id, zone FROM ctl WHERE status = 'fault' AND zone = 'C'", ["id"], false)
	var slot := p.answer_slot(db, "id")
	check(slot.values == ["DC-15"] and slot.rows.is_empty(), "the slot is read from the solution on this run's data: the id DC-15 (%s)" % [slot])
	g.open_case("ctl", "Which controller is faulting?")
	g.set_blank("ctl", "The faulting controller", [], "DC-15", slot)
	check(not g.add_cell("id", "DC-1", {"id": "DC-1", "zone": "A"}) and g.case_info("ctl").blank.filled == "", "DC-1 isn't DC-15: values match whole, not as part of another")
	check(not g.add_cell("zone", "C", {"id": "DC-15", "zone": "C"}), "the right row's other cell isn't it")
	check(g.add_cell("ID", "dc-15", {"ID": "dc-15"}, "SELECT * FROM ctl WHERE status = 'fault';"), "the id cell holding DC-15 is, in any case and from any query")
	var b: Dictionary = g.case_info("ctl").blank
	check(b.filled == "DC-15" and b.query == "SELECT * FROM ctl WHERE status = 'fault';" and b.source == "terminal", "it's written in, with the query that found it")

	# A value a set shares (the zone of a stuck door): any answer row's zone cell, but
	# not the same value in a row that isn't one; with no naming column shown, the value's enough.
	var zp := Puzzle.new("zone", "SELECT id, zone FROM ctl WHERE zone = 'C'", ["zone"], false)
	var zs := zp.answer_slot(db, "zone")
	check(zs.values == ["C"] and zs.rows.size() == 2 and zs.rows[0].has("id") and not zs.rows[0].has("zone"), "a set's slot holds the shared value and names each answer row by its id")
	g.found_cells.clear()  # (the zone cell pointed at above would fill it straight away)
	g.open_case("zone", "Which zone?")
	g.set_blank("zone", "The zone", [], "C", zs)
	check(not g.add_cell("zone", "C", {"id": "DC-2", "zone": "C"}), "the value in a row that isn't an answer row doesn't count")
	check(g.add_cell("zone", "c", {"zone": "C"}), "a result with no naming column: the column and value are enough")

	# A count: the result's only cell, under whatever name the query gave it.
	g.open_case("count", "How many?")
	g.set_blank("count", "Faulted", [], "2", {"column": "", "values": ["2"], "only": true})
	check(not g.add_cell("n", "2", {"id": "DC-2", "n": "2"}), "a 2 in a wider row isn't the count")
	check(g.add_cell("COUNT(*)", "2", {"COUNT(*)": "2"}), "the count on its own is")

	# Pointed at before the case opens: kept for the floor, it fills the slot when it's set.
	g.add_cell("name", "Harold Mercer", {"name": "Harold Mercer", "extension": "4815"}, "SELECT name, extension FROM staff;")
	g.open_case("caller", "Who called?")
	g.set_blank("caller", "Ext. 4815 belongs to", [], "Harold Mercer", {"column": "name", "values": ["Harold Mercer"], "rows": [{"extension": 4815}]})
	check(g.case_info("caller").blank.filled == "Harold Mercer" and g.case_info("caller").blank.query == "SELECT name, extension FROM staff;", "a cell found before its case opened fills the slot once it's set")
	g.add_cell("name", "Dana Price", {"name": "Dana Price"})
	g.set_blank("later", "Who?", [], "Dana Price", {"column": "name", "values": ["Dana Price"]})
	check(g.case_info("later").blank.filled == "", "set before its case opens, a slot waits")
	g.open_case("later", "Who?")
	check(g.case_info("later").blank.filled == "Dana Price", "and fills when the case opens")
	g.mark_floor_start("level_1")
	check(g.found_cells.is_empty(), "a new floor starts with nothing pointed at")

	# A terminal line isn't a cell slot's answer, a paper's line still is.
	g.open_case("paper", "Who?")
	g.set_blank("paper", "Who?", ["vale"], "Vale", {"column": "name", "values": ["Vale"]})
	check(not g.add_answer("name | Vale", "terminal") and g.add_answer("Dr. Vale, Secure Lab B", "document"), "a whole terminal line doesn't fill a cell's slot; a line on a paper still does")

	# Reading cells off the screen.
	var cells := TerminalUI.row_cells("id    | zone | status", "DC-15 | C    | fault")
	check(cells.map(func(x): return [x.column, x.value]) == [["id", "DC-15"], ["zone", "C"], ["status", "fault"]] and cells[1].start == 8 and cells[1].end == 12, "a result row's cells come from its header's columns (%s)" % [cells])
	var f := TerminalUI.json_field('  "edited_by": "EXEC-30",')
	check(f.column == "edited_by" and f.value == "EXEC-30" and TerminalUI.json_field('  "doors": [').is_empty() and TerminalUI.json_field('  "locked": null').value == "NULL", "a request's field line is a cell: its key and value")

