class_name NotebookPages
extends Control
## What goes on which page of the player's notebook: the crew's work order,
## a case page per puzzle (everything found about it in one place, with the notes
## the player writes or copies while on it), tables discovered with the sticky
## notes found, Field Notes, and the crew's books: the chapters they've had so
## far (Huddle), each with a "Test yourself" quiz (BookQuiz). The notebook itself is drawn by
## NotebookView and NotebookArt (scripts/art/).
## Each section fills the left page, then the right; "next" turns to the next spread.
## In a co-op notes huddle (NotesHuddle), each line and sticky note has a "+ share"
## chip, and each case a button to share the whole page.

## "+ write a note" on the Cases page: the player wants to write something of their own.
signal write_requested

enum Page { WORK_ORDER, CASES, TABLES, FIELD_NOTES, BOOK }

const TAB_NAMES := ["Work order", "Cases", "Tables", "Field Notes", "Books"]
## The book tab's words (drafts for Augustine's word-for-word OK).
const BOOK_EMPTY := "New chapters of the crew's books go here."
const BOOK_TEST := "Test yourself"
const BOOK_CONTENTS := "< Contents"
const BOOK_NEXT := "Next question >"
const BOOK_DONE := "All done: every quick check in this chapter answered right."
const BOOK_BACK := "< Back to the chapter"

const CONCEPT_NOTES := {
	"SELECT": "SELECT picks which columns you want to see. * means all of them.",
	"FROM": "FROM names the table to read.",
	"ORDER BY": "ORDER BY sorts rows by a column. Add DESC for biggest first.",
	"WHERE": "WHERE keeps only the rows that match a condition.",
	"AND": "AND requires both conditions to be true.",
	"OR": "OR accepts a row if either condition is true.",
	"LIKE": "LIKE matches patterns: 'Har%' means starts with Har.",
	"LIMIT": "LIMIT 5 shows only the first 5 rows.",
	"COUNT": "COUNT(*) counts rows instead of showing them.",
	"GET": "GET /path asks a server for data. The answer comes back as JSON.",
}
const SUBTITLES := {
	"level_2": "Level 2  -  Security Office",
}
## How long the pen takes to write an answer into its blank.
const ANSWER_WRITE_TIME := 1.4
## An empty answer blank on a case page, and how to fill it.
const BLANK := "______________"
const BLANK_HOW := "Found it? Point at the line that answers it, on a screen or a paper, and click + add to notebook."
## The Cases tab's words (drafts for Augustine's word-for-word OK).
const CASE_LABEL := "CASE"
const SIDE_CASE := "SIDE CASE"
const PIECES_COUNT := "%d/%d pieces"
const PIECE_MISSING := "????"
const FROM := "From: %s"
const QUERY_SO_FAR := "The query so far"
## Above a case's query blocks (Augustine's words, playtest 2026-10-22).
const MAKE_QUERY := "Create a query in SQL to pull it up in the terminal."
const CHECKLIST := "Checklist"
const NOTES := "Notes"
const OTHER_WAYS := "Other ways in: %d found"
const ENDINGS := "Endings"
const HIDDEN := "???"
const ENDING := "%s  -  Ending %d of %d"
const COMPLETED := "Completed cases (%d)  >"
const COMPLETED_TITLE := "Completed cases"
const BACK_TO_CASE := "< Back to the current case"
const BACK_TO_COMPLETED := "< Completed cases"
const ENDINGS_FOUND := "Ending %d of %d found"
const ROUTES_FOUND := "%d of %d other ways in"
const PIECE_FOUND_COLOR := Color(0.91, 0.69, 0.29)
const PIECE_MISSING_COLOR := Color(0.78, 0.74, 0.62)
const KIND_LABELS := {"result": "Query result", "hint": "Hint", "error": "Error", "schema": "Table shape", "echo": "I typed", "document": "From a document"}

## At the end of a level the notebook opens on Field Notes with buttons to carry on.
var end_of_level := false
var book: NotebookView
var _page: Page = Page.WORK_ORDER
var _spread := 0
var _spreads: Array = []  # [[left items], [right items]] per spread
var _turn: Button
## The co-op notes huddle; found from the level when left unset.
var huddle: NotesHuddle
## On screen (the Notebook is open): an answer just found is written in when its
## page shows, not while the book is put away.
var showing := false
## The blank written in on this build of the pages, and its case.
var _fresh_blank: Control
var _fresh_case := ""
## The book tab: the chapter open in it ("" for the contents), and its quiz while
## testing yourself.
var book_chapter := ""
var quiz: BookQuiz
## The Cases tab: showing the list of completed cases, or one of them ("" for none).
var showing_completed := false
var completed_case := ""
## Just-solved cases shown on screen this time: filed when the notebook closes.
var _solved_seen := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if end_of_level:
		var shade := ColorRect.new()
		shade.color = Color(0.02, 0.03, 0.04)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(shade)
	book = NotebookView.new()
	add_child(book)
	for t in TAB_NAMES:
		book.add_tab(t)
	book.tab_pressed.connect(func(t): show_page(TAB_NAMES.find(t)))
	_turn = NotebookArt.write_button("next page  >")
	_turn.tooltip_text = "Turn the page"
	_turn.pressed.connect(func(): book.turn_page(func(): _show_spread(_spread + 1)))
	add_child(_turn)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	# End-of-level buttons sit centred; the close hint goes in the corner, clear of the controls line.
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM if end_of_level else Control.PRESET_BOTTOM_RIGHT)
	footer.grow_horizontal = Control.GROW_DIRECTION_BOTH if end_of_level else Control.GROW_DIRECTION_BEGIN
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.offset_bottom = -12
	if not end_of_level:
		footer.offset_right = -24
	add_child(footer)
	if end_of_level:
		_add_end_buttons(footer)
	else:
		var close_hint := NotebookArt.hand("Tab to close", 22, Color(0.9, 0.88, 0.8))
		close_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
		footer.add_child(close_hint)
	refresh()


## Spreads that aren't on the pages have no parent, so nothing else frees them.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_spreads()


func _free_spreads() -> void:
	for spread in _spreads:
		for side in spread:
			for item in side:
				if is_instance_valid(item) and item.get_parent() == null:
					item.free()
	_spreads = []


func show_page(page: int) -> void:
	_page = page as Page
	if book:
		book.select_tab(TAB_NAMES[_page])
	refresh()


func current_page() -> Page:
	return _page


## Rebuild the open section from the notebook data, back to its first spread.
func refresh() -> void:
	if not book:
		return
	var h := _find_huddle()
	if h and not h.changed.is_connected(refresh):
		h.changed.connect(refresh)
	book.clear_pages()
	_free_spreads()
	_fresh_blank = null
	_spreads = _paginate(section_items(_page))
	_show_spread(0)


## The pieces that make up a section, in reading order. Public for tests.
func section_items(page: int) -> Array[Control]:
	var game := get_node("/root/Game")
	match page:
		Page.WORK_ORDER:
			return WorkOrderForm.build(game.ticket(), book.left.size.y if book else 0.0)
		Page.CASES:
			return _case_items(game)
		Page.TABLES:
			return _table_items(game.notebook_tables) + _notes_items(game.notebook_notes, _huddling())
		Page.BOOK:
			return _book_items(game)
		_:
			return _field_notes_items(game)


## The Books tab: the contents (each book's chapters had so far), a chapter's
## pages, or a quiz on it. Each press redraws the tab.
func _book_items(game: Node) -> Array[Control]:
	var items: Array[Control] = []
	if quiz:
		items.append(NotebookArt.heading("%s: Ch. %d" % [BOOK_TEST, quiz.chapter.number]))
		if quiz.is_done():
			items.append(NotebookArt.hand(BOOK_DONE, 24))
			items.append(_book_button(BOOK_BACK, "BookBack", func(): quiz = null))
			return items
		var q := quiz.question()
		for text in quiz.shown_beside():
			items.append(_book_page(text, 15))
		# The question, its options and its why stay on one page: if they don't
		# fit under the reference, they start the next page.
		var check := VBoxContainer.new()
		check.name = "QuickCheck"
		check.add_theme_constant_override("separation", book.left.get_theme_constant("separation"))
		check.add_child(NotebookArt.hand("Quick check %d of %d   %s" % [quiz.at + 1, quiz.steps.size(), q.word], 20, NotebookArt.PENCIL))
		check.add_child(NotebookArt.hand(q.q, 26))
		for i in q.options.size():
			var mark := ">  " if quiz.result.get("choice", -1) == i else "    "
			var b := _book_button(mark + str(q.options[i]), "Option%d" % i, quiz.answer.bind(i))
			b.disabled = quiz.result.get("right", false)
			check.add_child(b)
		if not quiz.result.is_empty():
			var right: bool = quiz.result.right
			check.add_child(NotebookArt.hand(("Right. " if right else "Not quite. ") + str(q.why), 22, NotebookArt.INK if right else NotebookArt.RED_PEN))
			if right:
				check.add_child(_book_button(BOOK_NEXT, "BookNext", quiz.next))
		items.append(check)
		items.append(_book_button(BOOK_BACK, "BookBack", func(): quiz = null))
		return items
	if book_chapter != "":
		var ch := Books.chapter(book_chapter)
		items.append(NotebookArt.heading("Ch. %d: %s" % [ch.number, ch.title]))
		for i in Books.reading_order(ch):
			items.append(_book_page(ch.pages[i]))
		if not ch.quiz.is_empty():
			var id := book_chapter
			items.append(_book_button(BOOK_TEST, "TestYourself", func(): quiz = BookQuiz.create(id, game.run_seed)))
		items.append(_book_button(BOOK_CONTENTS, "BookContents", func(): book_chapter = ""))
		return items
	var have := _chapters_had(game)
	if have.is_empty():
		items.append(NotebookArt.heading(TAB_NAMES[Page.BOOK]))
		items.append(NotebookArt.hand(BOOK_EMPTY, 24, NotebookArt.PENCIL))
	for book_id in Books.BOOKS:
		var had: Array = Books.book_chapter_ids(book_id).filter(func(c): return have.has(c))
		if not had.is_empty():
			items.append(NotebookArt.heading(Books.book_name(book_id)))
		for id in had:
			var ch := Books.chapter(id)
			items.append(_book_button("Ch. %d: %s" % [ch.number, ch.title], "Chapter_" + id, func(): book_chapter = id))
	return items


## The chapters this player has: come in this run, or earned on their profile on
## an earlier one (so a resumed run, or one started on a later floor, has them too),
## once the crew has the book this run.
func _chapters_had(game: Node) -> Array:
	var out: Array = game.book_chapters.duplicate()
	if game.get("before_book"):
		return out  # still in the shop bag
	var net := get_node_or_null("/root/Net")
	if net and net.profile:
		for source in net.profile.earned:
			var id := String(source).trim_prefix("chapter:")
			if id != String(source) and not out.has(id):
				out.append(id)
	return out


## A press on the book tab: do it, then redraw the tab.
func _book_button(caption: String, node_name: String, action: Callable) -> Button:
	var b := NotebookArt.write_button(caption)
	b.name = node_name
	b.tooltip_text = ""
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func():
		action.call()
		refresh.call_deferred())
	return b


## A page of the book, printed: its code lines in typewriter text, sized to fit.
func _book_page(text: String, size: int = 17) -> Control:
	var page := RichTextLabel.new()
	page.name = "BookPage"
	page.bbcode_enabled = true
	page.fit_content = true
	page.scroll_active = false
	page.custom_minimum_size.x = NotebookArt.HEADING_RULE_MAX
	page.add_theme_color_override("default_color", NotebookArt.INK)
	page.add_theme_font_size_override("normal_font_size", size + 2)
	page.add_theme_font_override("mono_font", ThemeUtil.mono())
	page.text = Books.page_bbcode(text, NotebookArt.HEADING_RULE_MAX, size)
	return page


## Every word in a section, for tests.
func section_text(page: int) -> String:
	var items := section_items(page)
	var out := text_of(items)
	for item in items:
		item.free()
	return out


## Every word on a section's pages, for tests.
static func text_of(items: Array) -> String:
	var out := ""
	for item in items:
		if item is Label:
			out += item.text + "\n"
		for l in item.find_children("*", "Label", true, false):
			out += l.text + "\n"
	return out


func _find_huddle() -> NotesHuddle:
	if huddle == null and is_inside_tree():
		var s := LevelSync.of(self)
		huddle = s.huddle if s else null
	return huddle


## The huddle this player is in, if any.
func _huddling() -> NotesHuddle:
	var h := _find_huddle()
	return h if h and h.in_huddle() and not end_of_level else null


## Top of the Cases page in a huddle: who's in it, and sharing everything at once.
func _huddle_items(h: NotesHuddle, game: Node) -> Array[Control]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var all := NotebookArt.write_button("Share all cases")
	all.name = "ShareAll"
	all.tooltip_text = "Share every case page and sticky note with the huddle"
	all.pressed.connect(func():
		h.share(NotesHuddle.all_items(game))
		all.text = "All shared")
	row.add_child(all)
	var leave := NotebookArt.write_button("Leave huddle")
	leave.name = "LeaveHuddle"
	leave.tooltip_text = "Stop sharing notes with them"
	leave.pressed.connect(h.leave)
	row.add_child(leave)
	return [NotebookArt.hand("Notes huddle with " + ", ".join(h.others().map(h.name_of)), 24, NotebookArt.RED_PEN), row]


func _share_case_button(h: NotesHuddle, game: Node, case_id: String) -> Control:
	var b := NotebookArt.write_button("Share case notes")
	b.name = "ShareCase"
	b.tooltip_text = "Share everything on this page with the huddle"
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func():
		h.share(NotesHuddle.case_items(game, case_id))
		b.text = "Case shared")
	return b


## The "+ share" chip under a line, while in a huddle: like "+ add to notebook" on papers.
func _share_chip(h: NotesHuddle, item: Dictionary) -> Button:
	var chip := DocumentView.add_chip()
	chip.name = "Share"
	chip.visible = true
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.tooltip_text = "Share this line with the huddle"
	var done := func():
		chip.text = "shared"
		chip.disabled = true
	chip.text = "+ share"
	if h.was_sent(item.text):
		done.call()
	chip.pressed.connect(func():
		h.share([item])
		done.call())
	return chip


## "+ write a note": it goes on the case being worked on.
func _write_button() -> Array[Control]:
	if end_of_level:
		return []
	var write := NotebookArt.write_button("+ write a note")
	write.name = "WriteMine"
	write.tooltip_text = "Write your own note on this case's page"
	write.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	write.pressed.connect(func(): write_requested.emit())
	return [write]


func _notes_items(ids: Array, h: NotesHuddle = null) -> Array[Control]:
	var items: Array[Control] = [NotebookArt.heading("Sticky notes")]
	if ids.is_empty():
		items.append(NotebookArt.hand("None yet. Look on desks and terminals: the staff leave themselves reminders.", 24, NotebookArt.PENCIL))
	for id in ids:
		var n := StickyNotes.get_note(id)
		items.append(NotebookArt.sticky(n.title, n.syntax, n.example))
		items.append(NotebookArt.hand(n.what, 22))
		if h:
			items.append(_share_chip(h, NotesHuddle.sticky_item(id)))
	return items


## A note the player wrote or copied, as a clue: their label, then the lines.
func _written_item(w: Dictionary, share: Dictionary = {}) -> Control:
	var label: String = "My note" if w.kind == "mine" else (w.label if w.label != "" else KIND_LABELS.get(w.kind, "From the terminal"))
	var lines: PackedStringArray = w.text.split("\n")
	return _clue_item("\n".join(lines.slice(0, 12)), label, share)


## The Cases tab. Solved cases are filed under Completed cases (the button at
## the top), except one just solved, shown once, solved, before it's filed. A
## case with pieces (Game.set_pieces) gets a spread to itself: the case on the
## left, its checklist and notes on the right, the main case first. One without
## pieces is a page of its question, clues and notes, as before. Notes from
## before any case, or from one not open, go under Other notes at the end.
func _case_items(game: Node) -> Array[Control]:
	if completed_case != "":
		return _completed_case_items(game)
	if showing_completed:
		return _completed_items(game)
	var items: Array[Control] = []
	var open: Array = game.notebook_cases.filter(func(c): return c.open)
	var current: String = game.current_case()
	var main: String = game.main_case()
	var shown := {}
	var h := _huddling()
	if h:
		items.append_array(_huddle_items(h, game))
	var filed: Array = open.filter(func(c): return c.solved and not c.get("fresh_solve", false))
	if not filed.is_empty() and not end_of_level:
		items.append(_case_button(COMPLETED % filed.size(), "CompletedCases", func(): showing_completed = true))
	for c in filed:
		shown[c.id] = true  # their notes stay with them
	var list: Array = open.filter(func(c): return not filed.has(c))
	if list.is_empty():
		items.append(NotebookArt.heading("Cases"))
		items.append(NotebookArt.hand("No open cases. When the job turns up something to figure out, it gets a page here.", 24, NotebookArt.PENCIL))
	# Just solved first (the reward), then the main case, then the rest.
	list.sort_custom(func(a, b): return _case_rank(a, main) < _case_rank(b, main))
	for c in list:
		shown[c.id] = true
		if c.get("fresh_solve", false) and showing:
			_solved_seen[c.id] = true
		if not c.get("pieces", []).is_empty():
			var board := _board_items(game, c, c.id == current)
			if c == list[0]:
				board.pop_front().free()  # the first starts right under the button
			items.append_array(board)
		else:
			items.append_array(_plain_case_items(game, c, c.id == current, h))
	var other: Array = game.notebook_written.filter(func(w): return not shown.has(w.get("case", "")))
	if not other.is_empty() or current == "":
		items.append(NotebookArt.heading("Other notes"))
		if other.is_empty():
			items.append(NotebookArt.hand("At a terminal or on a paper, point at any line and add it to your notebook.", 22, NotebookArt.PENCIL))
		for w in other:
			items.append(_written_item(w, NotesHuddle.note_item(game, w) if h else {}))
		if current == "":
			items.append_array(_write_button())
	return items


## Where a case goes on the Cases tab: just solved, the main case, the rest.
static func _case_rank(c: Dictionary, main: String) -> int:
	if c.get("fresh_solve", false):
		return 0
	return 1 if c.id == main else 2


## A case without pieces: its question, blank, clues, notes and tables, in order.
func _plain_case_items(game: Node, c: Dictionary, is_current: bool, h: NotesHuddle) -> Array[Control]:
	var items: Array[Control] = []
	var notes: Array = game.notebook_written.filter(func(w): return w.get("case", "") == c.id)
	items.append(NotebookArt.heading(("[x]  " if c.solved else "") + c.title))
	if h and not (c.clues.is_empty() and notes.is_empty()):
		items.append(_share_case_button(h, game, c.id))
	if c.has("blank"):
		items.append_array(_blank_items(c))
	if c.solved:
		items.append(NotebookArt.hand("Solved: " + c.how, 22))
	if c.clues.is_empty() and notes.is_empty():
		items.append(NotebookArt.hand("Nothing yet. Read what's around: papers, plates on the doors, the terminal.", 22, NotebookArt.PENCIL))
	items.append_array(_case_notes(game, c, notes, h))
	if is_current:
		items.append_array(_write_button())
	for t in c.tables:
		if game.notebook_tables.has(t):
			items.append(NotebookArt.table_card(t, game.notebook_tables[t]))
	return items


## A case's clues and the notes written on it.
func _case_notes(game: Node, c: Dictionary, notes: Array, h: NotesHuddle) -> Array[Control]:
	var items: Array[Control] = []
	for k in c.clues:
		items.append(_clue_item(k.text, k.from, NotesHuddle.clue_item(c, k.text, k.from) if h else {}))
	for w in notes:
		items.append(_written_item(w, NotesHuddle.note_item(game, w) if h else {}))
	return items


## A case with pieces, on a spread of its own. Left: the question, how many
## pieces are in, each piece (found, or ???? with where to look), the query so
## far and the blank for the answer; solved, its ending. Right: the checklist,
## the other ways in and endings still hidden, then the clues and notes.
func _board_items(game: Node, c: Dictionary, is_current: bool) -> Array[Control]:
	var h := _huddling()
	var items: Array[Control] = [_break("spread")]
	var found: int = game.pieces_found(c.id)
	var total: int = game.pieces_total(c.id)
	items.append(NotebookArt.hand(SIDE_CASE if c.get("optional", false) else CASE_LABEL, 18, NotebookArt.PENCIL))
	items.append(NotebookArt.heading(("[x]  " if c.solved else "") + c.title))
	if c.solved:
		items.append_array(_ending_items(game, c))
	items.append(_progress(found, total))
	if c.get("query", "") != "":
		items.append(_query_blocks(game, c))
	var n := 1
	for p in c.pieces:
		items.append(_piece_item(n, p))
		n += 1
	if c.has("blank"):
		items.append_array(_blank_items(c))
	if c.solved:
		items.append(NotebookArt.hand("Solved: " + c.how, 22))
	items.append(_break("page"))
	items.append(NotebookArt.hand(CHECKLIST, 30))
	for line in game.case_checklist(c.id):
		var l := NotebookArt.hand(("[x]  " if line.done else "[  ]  ") + line.text, 22 if line.done else 24, NotebookArt.PENCIL if line.done else NotebookArt.INK)
		l.name = "Check"
		items.append(l)
	items.append_array(_route_items(game, c))
	var notes: Array = game.notebook_written.filter(func(w): return w.get("case", "") == c.id)
	if h and not (c.clues.is_empty() and notes.is_empty()):
		items.append(_share_case_button(h, game, c.id))
	if not (c.clues.is_empty() and notes.is_empty()):
		items.append(NotebookArt.hand(NOTES, 26))
	items.append_array(_case_notes(game, c, notes, h))
	if is_current:
		items.append_array(_write_button())
	return items


## The case's query as blocks put together: its fixed words outlined, and each
## piece a numbered block, filled in once found (gray with its hint's name for
## the blank until then). A case that doesn't assemble (Game.set_assemble)
## keeps every piece gray. The whole query so far is the blocks' "query" meta.
func _query_blocks(game: Node, c: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.name = "QuerySoFar"
	box.add_theme_constant_override("separation", 6)
	var goal := NotebookArt.hand(MAKE_QUERY, 22)
	goal.name = "Goal"
	box.add_child(goal)
	var flow := HFlowContainer.new()
	flow.name = "QueryBlocks"
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.set_meta("query", game.case_query(c.id))
	var q: String = c.query
	var assemble: bool = c.get("assemble", true)
	var at := 0
	for m in RegEx.create_from_string("\\{([a-z_]+)\\}").search_all(q):
		var lit := q.substr(at, m.get_start() - at)
		var quoted := lit.ends_with("'") and q.substr(m.get_end(), 1) == "'"
		_literal_blocks(flow, lit.left(-1) if quoted else lit)
		var n := 0
		for i in c.pieces.size():
			if c.pieces[i].id == m.get_string(1):
				n = i + 1
		if n > 0:
			flow.add_child(_piece_block(n, c.pieces[n - 1], quoted, assemble))
		at = m.get_end() + (1 if quoted else 0)
	_literal_blocks(flow, q.substr(at))
	box.add_child(flow)
	return box


## A query's fixed words as outlined blocks; a hint's own blank in them
## (enter_column_name) is a gray block with no number: nothing to find for it.
func _literal_blocks(flow: Control, text: String) -> void:
	var at := 0
	for m in RegEx.create_from_string("\\benter_[a-z_]+").search_all(text):
		_add_block(flow, text.substr(at, m.get_start() - at), false, Color(0, 0, 0, 0))
		_add_block(flow, m.get_string(), false, PIECE_MISSING_COLOR)
		at = m.get_end()
	_add_block(flow, text.substr(at), false, Color(0, 0, 0, 0))


func _add_block(flow: Control, text: String, bold: bool, fill: Color) -> void:
	text = text.strip_edges()
	if text != "":
		flow.add_child(_block(NotebookArt.code(text, 18), fill, bold))


## Piece `n`'s block: its value once found, else its hint's name for it.
func _piece_block(n: int, p: Dictionary, quoted: bool, assemble: bool) -> Control:
	var shown: bool = p.found and assemble
	var text := str(p.value) if shown else str(p.get("blank", PIECE_MISSING))
	if quoted:
		text = "'%s'" % text
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var num := NotebookArt.hand(str(n), 16, NotebookArt.INK if shown else NotebookArt.PENCIL)
	num.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(num)
	var value := NotebookArt.code(text, 18, Color(0.1, 0.1, 0.12) if shown else NotebookArt.PENCIL)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(value)
	var block := _block(row, PIECE_FOUND_COLOR if shown else PIECE_MISSING_COLOR, true)
	block.name = "Piece%d" % n
	block.set_meta("found", shown)
	return block


## One block: `inner` on a rounded card, filled with `fill` (a piece) or just
## outlined in pencil (the query's own words).
static func _block(inner: Control, fill: Color, solid: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = Color(NotebookArt.PENCIL, 0.0 if solid else 0.6)
	sb.set_border_width_all(0 if solid else 1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	if inner is Label:
		(inner as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(inner)
	return p


## "3/4 pieces" and a bar of one segment per piece, the found ones filled.
func _progress(found: int, total: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "Progress"
	row.add_theme_constant_override("separation", 6)
	for i in total:
		var seg := ColorRect.new()
		seg.color = PIECE_FOUND_COLOR if i < found else PIECE_MISSING_COLOR
		seg.custom_minimum_size = Vector2(0, 10)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(seg)
	var count := NotebookArt.hand(PIECES_COUNT % [found, total], 24)
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(count)
	return row


## One piece: its number and what kind of piece it is, then what it is (or ????)
## and where it came from (or a vague nudge where to look).
func _piece_item(n: int, p: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "Piece"
	row.add_theme_constant_override("separation", 10)
	var num := NotebookArt.hand("%d." % n, 26, NotebookArt.INK if p.found else NotebookArt.PENCIL)
	num.autowrap_mode = TextServer.AUTOWRAP_OFF
	num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(num)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(NotebookArt.hand(str(p.label), 17, NotebookArt.PENCIL))
	var value := NotebookArt.hand(str(p.value) if p.found else str(p.get("blank", PIECE_MISSING)), 28, NotebookArt.INK if p.found else NotebookArt.PENCIL)
	value.name = "Value"
	box.add_child(value)
	var source := str(p.get("from", "")) if p.found else str(p.get("where", ""))
	if source != "":
		box.add_child(NotebookArt.hand((FROM % source) if p.found else source, 17, NotebookArt.PENCIL))
	row.add_child(box)
	return row


## A solved case's ending: "Rourke survived  -  Ending 1 of 3", in red pen. None
## if the case has only the one way to end.
func _ending_items(game: Node, c: Dictionary) -> Array[Control]:
	var endings: Array = c.get("endings", [])
	var at := -1
	for i in endings.size():
		if endings[i].id == c.get("ending", ""):
			at = i
	if at < 0:
		return []
	var l := NotebookArt.hand(ENDING % [endings[at].name, at + 1, endings.size()], 30, NotebookArt.RED_PEN)
	l.name = "Ending"
	return [l]


## The right page's other ways in and endings: each one found (this run, or on
## an earlier one) by name, the rest as ???.
func _route_items(game: Node, c: Dictionary) -> Array[Control]:
	var items: Array[Control] = []
	var routes: Array = c.get("routes", [])
	if not routes.is_empty():
		var found := routes.filter(func(r): return r.found or game.ever_found("route:%s:%s" % [c.id, r.id]))
		items.append(NotebookArt.hand(OTHER_WAYS % found.size(), 24))
		for r in routes:
			items.append(NotebookArt.hand("   " + (r.name if found.has(r) else HIDDEN), 20, NotebookArt.INK if found.has(r) else NotebookArt.PENCIL))
	var endings: Array = c.get("endings", [])
	if not endings.is_empty():
		items.append(NotebookArt.hand(ENDINGS, 24))
		for e in endings:
			var had: bool = c.get("ending", "") == e.id or game.ever_found("ending:%s:%s" % [c.id, e.id])
			items.append(NotebookArt.hand("   " + (e.name if had else HIDDEN + "   " + str(e.get("hint", ""))), 20, NotebookArt.INK if had else NotebookArt.PENCIL))
	return items


## Completed cases: each solved case, with its pieces, ending and other ways in
## found. Pressing one opens it.
func _completed_items(game: Node) -> Array[Control]:
	var items: Array[Control] = [NotebookArt.heading(COMPLETED_TITLE)]
	items.append(_case_button(BACK_TO_CASE, "BackToCase", func(): showing_completed = false))
	for c in game.completed_cases():
		items.append(_case_button("[x]  " + c.title, "Completed_" + c.id, func(): completed_case = c.id))
		var parts: Array = []
		if not c.get("pieces", []).is_empty():
			parts.append(PIECES_COUNT % [game.pieces_found(c.id), game.pieces_total(c.id)])
		var endings: Array = c.get("endings", [])
		if not endings.is_empty():
			parts.append(ENDINGS_FOUND % [endings.filter(func(e): return c.ending == e.id or game.ever_found("ending:%s:%s" % [c.id, e.id])).size(), endings.size()])
		var routes: Array = c.get("routes", [])
		if not routes.is_empty():
			parts.append(ROUTES_FOUND % [routes.filter(func(r): return r.found or game.ever_found("route:%s:%s" % [c.id, r.id])).size(), routes.size()])
		parts.append(c.how)
		items.append(NotebookArt.hand("   " + "  -  ".join(parts), 20, NotebookArt.PENCIL))
	return items


## One completed case, opened from the list.
func _completed_case_items(game: Node) -> Array[Control]:
	var c: Dictionary = game.case_info(completed_case)
	var items: Array[Control] = [_case_button(BACK_TO_COMPLETED, "BackToCompleted", func(): completed_case = "")]
	if c.is_empty():
		return items
	if c.get("pieces", []).is_empty():
		items.append_array(_plain_case_items(game, c, false, null))
	else:
		var board := _board_items(game, c, false)
		board.pop_front().free()  # straight under the button, not on a spread of its own
		items.append_array(board)
	return items


## A press on the Cases tab (completed cases, back): do it, then redraw the tab.
func _case_button(caption: String, node_name: String, action: Callable) -> Button:
	return _book_button(caption, node_name, action)


## Where the pages break: "page" goes on to the next page, "spread" to the next
## left-hand page. Taken out when the pages are laid out (_paginate).
static func _break(kind: String) -> Control:
	var c := Control.new()
	c.name = "Break"
	c.set_meta("break", kind)
	return c


## The notebook was put away: cases it showed just solved are filed now.
func file_solved() -> void:
	var game := (Engine.get_main_loop() as SceneTree).root.get_node("Game")
	for id in _solved_seen:
		game.case_info(id).erase("fresh_solve")
	if not _solved_seen.is_empty():
		_solved_seen.clear()


## A case's blank for its answer, under the question: empty, with how to fill it
## in pencil, or filled in in pen. One just filled is written in as you watch.
func _blank_items(c: Dictionary) -> Array[Control]:
	var b: Dictionary = c.blank
	var line := HFlowContainer.new()  # the answer drops under the question if it won't fit beside it
	line.name = "Blank"
	line.add_theme_constant_override("h_separation", 10)
	var question := NotebookArt.hand(b.prompt + ":", 26)
	var answer := NotebookArt.hand(b.filled if b.filled != "" else BLANK, 26)
	answer.name = "Answer"
	for l in [question, answer]:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.add_child(l)
	if b.filled == "":
		var how: Array[Control] = [line, NotebookArt.hand(BLANK_HOW, 20, NotebookArt.PENCIL)]
		if b.has("miss"):
			how.append(NotebookArt.hand(b.miss, 20, NotebookArt.PENCIL))
		return how
	if b.get("fresh", false):
		_fresh_blank = answer
		_fresh_case = c.id
	return [line]


## One clue: where it came from in pencil, then the clue itself, wrapped to the
## page. A hint keeps its lines, in typewriter text like the screen it came from.
## In a huddle, `share` is what its "+ share" chip sends.
func _clue_item(text: String, from: String, share: Dictionary = {}) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(NotebookArt.hand(from, 18, NotebookArt.PENCIL))
	var line: Label = NotebookArt.code(text, 15) if text.contains("\n") else NotebookArt.hand(text, 22)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(line)
	if not share.is_empty():
		box.add_child(_share_chip(_huddling(), share))
	return box


func _table_items(tables: Dictionary) -> Array[Control]:
	var items: Array[Control] = [NotebookArt.heading("Tables")]
	if tables.is_empty():
		items.append(NotebookArt.hand("None yet. At a terminal, type .tables to list them, or run a query.", 24, NotebookArt.PENCIL))
	for t in tables:
		items.append(NotebookArt.table_card(t, tables[t]))
	return items


func _field_notes_items(game: Node) -> Array[Control]:
	var items: Array[Control] = [NotebookArt.heading("Field Notes")]
	items.append(NotebookArt.hand(SUBTITLES.get(game.completed_level, "Levels 0 and 1  -  The Lobby, Server Room A"), 22, NotebookArt.PENCIL))
	items.append(NotebookArt.hand("What I learned", 28))
	if game.concepts_learned.is_empty():
		items.append(NotebookArt.hand("(nothing yet)", 22, NotebookArt.PENCIL))
	for c in game.concepts_learned:
		items.append(NotebookArt.code(c, 18))
		items.append(NotebookArt.hand(CONCEPT_NOTES.get(c, ""), 22))
	if game.completed_level != "":
		items.append(NotebookArt.code("TESTS", 18))
		items.append(NotebookArt.hand("A self-test lists PASS/FAIL checks. Failing tests tell you where to look.", 22))
	if game.completed_level == "level_2":
		# Only claim the camera lie if they saw it explained.
		var cam := "CAM-2 said 'live' with a frozen picture; the keypad said" if game.cam_lie_learned else "The keypad said"
		items.append(NotebookArt.margin_note("A status can lie. %s 'opened' while the door stayed shut. Check the sensor, not the request." % cam))
	items.append(NotebookArt.hand("Queries I wrote", 28))
	var shown: Array = game.query_log.slice(max(0, game.query_log.size() - 12))
	if shown.is_empty():
		items.append(NotebookArt.hand("(none)", 22, NotebookArt.PENCIL))
	for q in shown:
		var line := NotebookArt.code("> " + q.replace("\n", " "), 16)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		items.append(line)
	if game.completed_level == "":
		return items
	if game.completed_level == "level_2":
		items.append(NotebookArt.hand("You locked the Watcher in behind you." if game.watcher_sealed else "You left SEC-EXIT open. The Watcher is still out there.", 24))
	var fate: String = {
		"killed": "Rourke is dead. WARDEN locked the building the moment his heart stopped.",
		"tied": "You tied Rourke up. He didn't stay tied.",
	}.get(game.rourke_fate, "Rourke's fate is unknown.")
	items.append(NotebookArt.hand(fate, 24))
	if game.next_level == "":
		items.append(NotebookArt.margin_note("End of the playable slice. Thanks for testing."))
	return items


## Lay items onto pages: fill the left page, then the right, then the next spread.
func _paginate(items: Array[Control]) -> Array:
	var page_h := book.left.size.y
	var gap := float(book.left.get_theme_constant("separation"))
	var pages: Array = [[]]
	var used := 0.0
	book.clear_pages()
	for item in items:
		if item.has_meta("break"):
			var kind: String = item.get_meta("break")
			item.free()
			var empty: bool = pages[-1].is_empty()
			# A spread starts on a left page; one already starting there needs no break.
			if kind == "page" or not empty:
				pages.append([])
			if kind == "spread" and (pages.size() - 1) % 2 == 1:
				pages.append([])
			used = 0.0
			continue
		# Measure on the page itself, so fonts and wrapping match what's shown.
		book.left.add_child(item)
		# Wrapped text measures at the page's width, before the page lays it out.
		var labels: Array = item.find_children("*", "Label", true, false)
		if item is Label:
			labels.append(item)
		for l in labels:
			if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
				l.size.x = book.left.size.x
				# Resizing doesn't invalidate cached minimum sizes up the chain.
				var n: Control = l
				while n:
					n.update_minimum_size()
					n = n.get_parent() as Control if n != item else null
		var h := item.get_combined_minimum_size().y
		book.left.remove_child(item)
		if not pages[-1].is_empty() and used + h > page_h:
			pages.append([])
			used = 0.0
		pages[-1].append(item)
		used += h + gap
	var spreads := []
	for i in range(0, pages.size(), 2):
		spreads.append([pages[i], pages[i + 1] if i + 1 < pages.size() else []])
	return spreads


func _show_spread(index: int) -> void:
	_spread = index % maxi(1, _spreads.size())
	# Take the last spread off the pages without freeing it: we may turn back to it.
	for page in [book.left, book.right]:
		for c in page.get_children():
			page.remove_child(c)
	var spread: Array = _spreads[_spread] if not _spreads.is_empty() else [[], []]
	for side in 2:
		var page: VBoxContainer = book.left if side == 0 else book.right
		for item in spread[side]:
			if item.get_parent():
				item.get_parent().remove_child(item)
			page.add_child(item)
	_turn.visible = _spreads.size() > 1
	_turn.text = "next page  >" if _spread < _spreads.size() - 1 else "back to start  >"
	_place_turn()
	_write_in_fresh()


## An answer just found, on the spread now showing: the pen writes it in, once.
func _write_in_fresh() -> void:
	if not (showing and is_instance_valid(_fresh_blank) and _fresh_blank.is_inside_tree()):
		return
	var b: Dictionary = get_node("/root/Game").case_info(_fresh_case).get("blank", {})
	b["fresh"] = false
	book.write_in(_fresh_blank, ANSWER_WRITE_TIME)
	_fresh_blank = null


func _place_turn() -> void:
	var s := book.book.scale.x
	_turn.position = book.book.position + Vector2(NotebookView.BOOK_SIZE.x - 210, NotebookView.BOOK_SIZE.y - 60) * s


func _add_end_buttons(footer: HBoxContainer) -> void:
	var game := get_node("/root/Game")
	var net := get_node_or_null("/root/Net")
	var online: bool = net != null and net.is_online()
	# In co-op the host moves everyone on together.
	var leads: bool = not online or net.is_host()
	if game.next_level != "" and leads:
		footer.add_child(_button("Continue", func():
			if online:
				net.goto_all(game.next_level)
			else:
				game.goto(game.next_level)))
	if leads:
		footer.add_child(_button("Play again (new data)", func():
			if online:
				net.start_game()
			else:
				game.new_run()
				game.goto("world")))
	footer.add_child(_button("Main menu", func():
		if net:
			net.leave(false)
		game.goto("menu")))


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 46)
	b.pressed.connect(action)
	return b
