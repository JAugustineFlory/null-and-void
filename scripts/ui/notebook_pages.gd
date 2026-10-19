class_name NotebookPages
extends Control
## What goes on which page of the player's notebook: the crew's work order,
## tables discovered, notes (sticky notes found and lines copied down), and Field Notes. The book
## itself is drawn by NotebookView and NotebookArt (scripts/art/).
## Each section fills the left page, then the right; "next" turns to the next spread.

## "+ write a note" on the Notes page: the player wants to write something of their own.
signal write_requested

enum Page { WORK_ORDER, TABLES, NOTES, FIELD_NOTES }

const TAB_NAMES := ["Work order", "Tables", "Notes", "Field Notes"]

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
		Page.NOTES:
			var copied: Array = game.notebook_written.filter(func(w): return w.kind != "mine")
			var mine: Array = game.notebook_written.filter(func(w): return w.kind == "mine")
			return _mine_items(mine) + _crew_items(game.notebook_shared) + _notes_items(game.notebook_notes) + _written_items(copied)
		Page.TABLES:
			return _table_items(game.notebook_tables)
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


## The player's own notes, in their handwriting, with a button to write another.
func _mine_items(mine: Array) -> Array[Control]:
	var items: Array[Control] = [NotebookArt.heading("My notes")]
	for w in mine:
		items.append(NotebookArt.hand("- " + w.text, 26))
		_add_share(items, w)
	if not end_of_level:
		var write := NotebookArt.write_button("+ write a note")
		write.name = "WriteMine"
		write.tooltip_text = "Write your own note in the notebook"
		write.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		write.pressed.connect(func(): write_requested.emit())
		items.append(write)
	return items


func _notes_items(ids: Array) -> Array[Control]:
	var items: Array[Control] = [NotebookArt.heading("Sticky notes")]
	if ids.is_empty():
		items.append(NotebookArt.hand("None yet. Look on desks and terminals: the staff leave themselves reminders.", 24, NotebookArt.PENCIL))
	for id in ids:
		var n := StickyNotes.get_note(id)
		items.append(NotebookArt.sticky(n.title, n.syntax, n.example))
		items.append(NotebookArt.hand(n.what, 22))
	return items


func _written_items(written: Array) -> Array[Control]:
	var items: Array[Control] = [NotebookArt.heading("Copied lines")]
	if written.is_empty():
		items.append(NotebookArt.hand("At a terminal or on a paper, point at any line and add it to your notebook.", 24, NotebookArt.PENCIL))
	for w in written:
		var label: String = w.label if w.label != "" else KIND_LABELS.get(w.kind, "From the terminal")
		var lines: PackedStringArray = w.text.split("\n")
		items.append(NotebookArt.note_line(lines[0], label))
		for extra in lines.slice(1, 12):
			items.append(NotebookArt.note_line(extra))
		_add_share(items, w)
	return items


## In co-op, a button under a line to copy it into every teammate's notebook.
func _add_share(items: Array[Control], entry: Dictionary) -> void:
	if end_of_level:
		return
	var crew := NetPlayers.of_session(get_tree()) if is_inside_tree() else null
	if crew == null:
		return
	if entry.get("shared", false):
		items.append(NotebookArt.hand("(shared with the crew)", 20, NotebookArt.PENCIL))
		return
	var share := NotebookArt.write_button("share with the crew")
	share.name = "Share"
	share.tooltip_text = "Put this line in your teammates' notebooks too"
	share.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	share.pressed.connect(func(): crew.share_note(entry))
	items.append(share)


## Lines teammates shared, under their names.
func _crew_items(shared: Array) -> Array[Control]:
	if shared.is_empty():
		return []
	var items: Array[Control] = [NotebookArt.heading("From the crew")]
	for s in shared:
		var lines: PackedStringArray = s.text.split("\n")
		var label: String = s.label if s.label != "" else KIND_LABELS.get(s.kind, "Note")
		if s.kind == "mine":
			label = ""
		items.append(NotebookArt.note_line(lines[0], "%s: %s" % [s.from, label] if label != "" else s.from))
		for extra in lines.slice(1, 12):
			items.append(NotebookArt.note_line(extra))
	return items


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
