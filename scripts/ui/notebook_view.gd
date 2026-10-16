class_name NotebookView
extends Control
## The notebook's pages: sticky notes found, tables discovered, and Field Notes.
## Greybox paper for now; the art pass dresses it.

enum Page { NOTES, TABLES, FIELD_NOTES }

const PAPER := Color(0.93, 0.9, 0.8)
const INK := Color(0.12, 0.13, 0.2)
const PENCIL := Color(0.35, 0.35, 0.4)
const STICKY := Color(1.0, 0.92, 0.45)

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

## At the end of a level the notebook opens on Field Notes with buttons to carry on.
var end_of_level := false
var _tabs: TabContainer
var _pages := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.92 if end_of_level else 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var paper := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	paper.add_theme_stylebox_override("panel", style)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.offset_left = 120
	paper.offset_right = -120
	paper.offset_top = 40
	paper.offset_bottom = -40
	add_child(paper)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	paper.add_child(column)
	column.add_child(_text("NOTEBOOK", 34, INK))

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	for page in [["Notes", Page.NOTES], ["Tables", Page.TABLES], ["Field Notes", Page.FIELD_NOTES]]:
		var scroll := ScrollContainer.new()
		scroll.name = page[0]
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		scroll.add_child(box)
		_tabs.add_child(scroll)
		_pages[page[1]] = box

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	if end_of_level:
		_add_end_buttons(footer)
	else:
		footer.add_child(_text("Tab to close", 16, PENCIL))
	refresh()


func show_page(page: Page) -> void:
	_tabs.current_tab = page


func current_page() -> Page:
	return _tabs.current_tab as Page


## Rewrite every page from the notebook data.
func refresh() -> void:
	if not _tabs:
		return
	var game := get_node("/root/Game")
	_fill_notes(_pages[Page.NOTES], game.notebook_notes)
	_fill_tables(_pages[Page.TABLES], game.notebook_tables)
	_fill_field_notes(_pages[Page.FIELD_NOTES], game)


func _fill_notes(box: VBoxContainer, ids: Array) -> void:
	_clear(box)
	if ids.is_empty():
		box.add_child(_text("No sticky notes yet. Look on desks and terminals: the staff leave themselves reminders.", 18, PENCIL))
		return
	for id in ids:
		var n := StickyNotes.get_note(id)
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = STICKY
		style.set_content_margin_all(14)
		card.add_theme_stylebox_override("panel", style)
		var inner := VBoxContainer.new()
		card.add_child(inner)
		inner.add_child(_text(n.title, 24, INK))
		inner.add_child(_text(n.what, 18, INK))
		inner.add_child(_mono("Shape:    " + n.syntax))
		inner.add_child(_mono("Example:  " + n.example.replace("\n", "\n          ")))
		inner.add_child(_text(n.tip, 16, PENCIL))
		box.add_child(card)


func _fill_tables(box: VBoxContainer, tables: Dictionary) -> void:
	_clear(box)
	if tables.is_empty():
		box.add_child(_text("No tables yet. At a terminal, type .tables to list them, or run a query.", 18, PENCIL))
		return
	for t in tables:
		box.add_child(_text(t, 22, INK))
		box.add_child(_mono("  " + ", ".join(tables[t])))


func _fill_field_notes(box: VBoxContainer, game: Node) -> void:
	_clear(box)
	box.add_child(_text(SUBTITLES.get(game.completed_level, "Levels 0 and 1  -  The Lobby, Server Room A"), 18, PENCIL))
	box.add_child(_text("What you learned", 24, INK))
	if game.concepts_learned.is_empty():
		box.add_child(_mono("  (nothing yet)"))
	for c in game.concepts_learned:
		box.add_child(_mono("  %-9s %s" % [c, CONCEPT_NOTES.get(c, "")]))
	if game.completed_level != "":
		box.add_child(_mono("  TESTS     A self-test lists PASS/FAIL checks. Failing tests tell you where to look."))
	if game.completed_level == "level_2":
		box.add_child(_mono("  VERIFY    A status can lie. CAM-2 said 'live' with a frozen picture; the keypad said\n            'opened' while the door stayed shut. Check the sensor, not the request."))

	box.add_child(_text("Queries you wrote", 24, INK))
	var shown: Array = game.query_log.slice(max(0, game.query_log.size() - 12))
	if shown.is_empty():
		box.add_child(_mono("  (none)"))
	for q in shown:
		box.add_child(_mono("  > " + q.replace("\n", " ")))

	if game.completed_level == "":
		return
	if game.completed_level == "level_2":
		box.add_child(_text("You locked the Watcher in behind you." if game.watcher_sealed else "You left SEC-EXIT open. The Watcher is still out there.", 20, INK))
	var fate: String = {
		"killed": "Rourke is dead. WARDEN locked the building the moment his heart stopped.",
		"tied": "You tied Rourke up. He didn't stay tied.",
	}.get(game.rourke_fate, "Rourke's fate is unknown.")
	box.add_child(_text(fate, 20, INK))
	if game.next_level == "":
		box.add_child(_text("End of the playable slice. Thanks for testing.", 20, INK))


func _add_end_buttons(footer: HBoxContainer) -> void:
	var game := get_node("/root/Game")
	if game.next_level != "":
		footer.add_child(_button("Continue", func(): game.goto(game.next_level)))
	footer.add_child(_button("Play again (new data)", func():
		game.new_run()
		game.goto("world")))
	footer.add_child(_button("Main menu", func(): game.goto("menu")))


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 46)
	b.pressed.connect(action)
	return b


func _text(text: String, size: int, color: Color) -> Label:
	var l := ThemeUtil.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _mono(text: String) -> Label:
	var l := ThemeUtil.label(text, 17, INK)
	l.add_theme_font_override("font", ThemeUtil.mono())
	return l


func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
