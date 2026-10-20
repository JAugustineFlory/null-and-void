class_name NotebookPages
extends Control
## What goes on which page of the player's notebook: the crew's work order,
## a case page per puzzle (everything found about it in one place, with the notes
## the player writes or copies while on it), tables discovered with the sticky
## notes found, and Field Notes. The book
## itself is drawn by NotebookView and NotebookArt (scripts/art/).
## Each section fills the left page, then the right; "next" turns to the next spread.
## In a co-op notes huddle (NotesHuddle), each line and sticky note has a "+ share"
## chip, and each case a button to share the whole page.

## "+ write a note" on the Cases page: the player wants to write something of their own.
signal write_requested

enum Page { WORK_ORDER, CASES, TABLES, FIELD_NOTES }

const TAB_NAMES := ["Work order", "Cases", "Tables", "Field Notes"]

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
		_:
			return _field_notes_items(game)


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


## A page per open case, unsolved ones first: the question, what this player has
## read about it and where, the notes they wrote or copied while on it, and the
## tables it needs that they've found. Notes from before any case, or from one
## not open, go under Other notes at the end.
func _case_items(game: Node) -> Array[Control]:
	var items: Array[Control] = []
	var open: Array = game.notebook_cases.filter(func(c): return c.open)
	var current: String = game.current_case()
	var shown := {}
	var h := _huddling()
	if h:
		items.append_array(_huddle_items(h, game))
	if open.is_empty():
		items.append(NotebookArt.heading("Cases"))
		items.append(NotebookArt.hand("No open cases. When the job turns up something to figure out, it gets a page here.", 24, NotebookArt.PENCIL))
	open.sort_custom(func(a, b): return not a.solved and b.solved)
	for c in open:
		shown[c.id] = true
		var notes: Array = game.notebook_written.filter(func(w): return w.get("case", "") == c.id)
		items.append(NotebookArt.heading(("[x]  " if c.solved else "") + c.title))
		if h and not (c.clues.is_empty() and notes.is_empty()):
			items.append(_share_case_button(h, game, c.id))
		if c.solved:
			items.append(NotebookArt.hand("Solved: " + c.how, 22))
		if c.clues.is_empty() and notes.is_empty():
			items.append(NotebookArt.hand("Nothing yet. Read what's around: papers, plates on the doors, the terminal.", 22, NotebookArt.PENCIL))
		for k in c.clues:
			items.append(_clue_item(k.text, k.from, NotesHuddle.clue_item(c, k.text, k.from) if h else {}))
		for w in notes:
			items.append(_written_item(w, NotesHuddle.note_item(game, w) if h else {}))
		if c.id == current:
			items.append_array(_write_button())
		for t in c.tables:
			if game.notebook_tables.has(t):
				items.append(NotebookArt.table_card(t, game.notebook_tables[t]))
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
