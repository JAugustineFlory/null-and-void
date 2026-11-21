class_name TerminalUI
extends CanvasLayer
## The SQL terminal screen. Players type real SQL; results come from the real database.

signal closed

## Cells show in full; this only stops a runaway value from flooding the screen.
const MAX_COL_WIDTH := 240
const MAX_ROWS_SHOWN := 60
## Screen colors, so each kind of line reads apart: tables amber and green,
## hints cyan, SQL keywords gold (as the input line colors them).
const TABLE_HEAD := "#ffd27f"
const TABLE_RULE := "#4f8a5c"
const TABLE_ROWS := ["#e2ffe6", "#8fdca2"]
const HINT := "#7fd4ff"
## SYSOP, when a hint's blank (enter_...) is typed in as it is.
const BLANK_TYPED := "%s is the blank from the hint. Type the real value in its place."
## Where a piece came from when a crewmate's query found it.
const QUERY_BY := "%s's query"
## SYSOP, when a case page's missing piece (????) is typed in as it is.
const PIECE_TYPED := "???? is a piece you haven't found yet. Your case page says where to look."
const KEYWORD := "#ffcc59"
const KEYWORDS := ["SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "ORDER", "BY", "ASC", "DESC", "LIMIT", "LIKE", "IN", "IS", "NULL", "AS", "DISTINCT", "COUNT", "GROUP", "HAVING", "JOIN", "ON", "UPDATE", "SET", "INSERT", "INTO", "VALUES", "DELETE", "BEGIN", "COMMIT", "ROLLBACK", "GET", "POST", "PATCH"]

var terminal: Node  # the Terminal in the world that opened this
## When this player last typed here (the HUD holds lines that can wait meanwhile).
var last_typed_msec := -1000000
var player: Player
var _output: RichTextLabel
var _input: TextEdit
## The selected case's query with blanks, just above the typing line, colored by
## kind (PieceKind). Hidden with no case selected, or one with no query.
var _case_line: RichTextLabel
var _title: Label
## Up and Down: every command typed at the open terminal, by anyone in the crew,
## in the order the host ran them (yours go in as you press Enter). Each terminal
## keeps its own (_histories); this is the open one's, and _history_i your place in it.
var _history: Array[String] = []
var _history_i := -1
## Each terminal's history on this floor, by terminal.
var _histories := {}
## Every line on screen that can be written into the notebook: {kind, text,
## from, to}, where from/to are the paragraphs it covers in the output.
## Kinds: info, echo, result, row (one row of a result, with its header), hint,
## error, schema, note.
var _noteable: Array[Dictionary] = []
var _note_label: LineEdit
## The red ; that flashes when Enter is pressed before the statement ends.
var _semicolon: Label
var _semicolon_tween: Tween
var _note_index := -1
## Hovering a line lights it up and offers to add it to the notebook.
var _hover_band: ColorRect
var _add_chip: Button
var _hover_index := -1
## The cell lit up in that line (an index into its "cells"), or -1 for the line.
## A result row's cells are its columns; a request's answer has one per field line.
var _hover_cell := -1
## The query (or request) behind the lines printed after it: what found a cell.
var _last_query := ""
## How long an open case's answer has sat on this screen with nobody pointing at
## it, and the cases already nudged about that (TerminalUI.NUDGE_AFTER).
var _unclicked := 0.0
var _nudged: Array[String] = []
var _answer_now := ""
var _check_in := 0.0
## Who else is at this terminal, and what they're typing.
var _others: Label
var _foot: Label
## On a terminal's in-world screen (open_on_screen), the window fills the glass:
## no dimmed backdrop, no margin. `_home` is where it goes back to afterwards.
var _dim: ColorRect
var _panel: PanelContainer
## The look the screen is drawn in now (TerminalLook.of; the terminal's, set by
## whoever sat down first).
var _look := {}
var _style: StyleBoxFlat
var _screen: Node
var _home: Node
## The script runner (.script), made the first time it's needed, and the
## terminal whose script it's showing.
var _editor: ScriptEditorUI
var _script_terminal: Node
## With a gamepad: the line being picked for the notebook (X, then the d-pad), or -1.
var picking := -1
## Your notebook below the screen, with the next-word buttons (TerminalNotebook).
## It lives beside this window, never on the glass with it.
var book: TerminalNotebook
## Words written with the buttons since the last query was sent, and for each
## query sent, whether it went with a pad and which words were tapped: on a pad,
## tapped words don't count as uses (only typed ones do).
var _tapped: Array = []
var _sent := {}
## The right stick scrolls the screen this fast at full push (pixels a second).
const PAD_SCROLL := 900.0
## An open case's answer left on the screen this long with nobody pointing at it:
## the crew says to point at it (NUDGE_LINE), once per case.
const NUDGE_AFTER := 20.0
const NUDGE_LINE := "cc_point_at_it"
## The typing line's grey example with no case selected (policy P8). With one,
## it's that case's query (Game.case_query).
const EXAMPLE := "Type a query   (.help for commands)"
const FOOT := "Enter: run (a query ends with ;)    Up/Down: previous queries    point at a line: add it to your notebook    Esc: step away"
## The foot line while a pad is in use (draft for Augustine's word-for-word OK).
const PAD_FOOT := "%s: run    D-pad up/down: previous queries    %s: pick a line for your notebook    Right stick: scroll    %s: step away"
## Left/right step between a row's cells (draft on plan/approvals/v0.10-small-strings.md).
const PAD_PICK_FOOT := "D-pad up/down: choose a line    D-pad left/right: pick a cell    %s: add it to your notebook    %s: back to typing"


func _ready() -> void:
	layer = 20
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.75)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	var panel := PanelContainer.new()
	_panel = panel
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_set_hosted(false)
	var style := StyleBoxFlat.new()
	_style = style
	style.bg_color = Color(0.02, 0.05, 0.03)
	style.border_color = Color(0.2, 0.45, 0.25)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	_title = ThemeUtil.label("", 18, ThemeUtil.DIM)
	_title.add_theme_font_override("font", ThemeUtil.mono())
	vbox.add_child(_title)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.meta_underlined = false
	_output.meta_clicked.connect(_on_meta)
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_override("normal_font", ThemeUtil.mono())
	_output.add_theme_font_override("bold_font", ThemeUtil.mono())
	_output.add_theme_font_size_override("normal_font_size", 17)
	_output.add_theme_font_size_override("bold_font_size", 17)
	_output.add_theme_color_override("default_color", ThemeUtil.GREEN)
	_output.mouse_exited.connect(func(): if not _chip_hovered(): _hover_line(picking))
	_output.gui_input.connect(_on_output_input)
	vbox.add_child(_output)
	_hover_band = ColorRect.new()
	_hover_band.color = Color(ThemeUtil.GREEN, 0.12)
	_hover_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_band.visible = false
	_output.add_child(_hover_band)
	_add_chip = Button.new()
	_add_chip.text = "+ add to notebook"
	_add_chip.flat = true
	_add_chip.focus_mode = Control.FOCUS_NONE
	_add_chip.add_theme_font_override("font", ThemeUtil.mono())
	_add_chip.add_theme_font_size_override("font_size", 13)
	_add_chip.add_theme_color_override("font_color", Color(ThemeUtil.GREEN, 0.75))
	_add_chip.add_theme_color_override("font_hover_color", Color(0.98, 0.9, 0.42))
	_add_chip.visible = false
	_add_chip.pressed.connect(func(): use_cell(_hover_index, _hover_cell))
	_output.add_child(_add_chip)
	_output.get_v_scroll_bar().value_changed.connect(func(_v): _hover_line(picking, _hover_cell if picking >= 0 else -1))  # a pad's pick follows the scroll

	# Naming a note before it goes in the notebook.
	_note_label = LineEdit.new()
	_note_label.visible = false
	_note_label.placeholder_text = "Name this note (optional), then Enter. Esc to cancel."
	_note_label.max_length = 40
	_note_label.add_theme_font_override("font", ThemeUtil.mono())
	_note_label.add_theme_font_size_override("font_size", 17)
	_note_label.text_submitted.connect(func(t): _finish_note(t))
	_note_label.gui_input.connect(_on_note_key)
	vbox.add_child(_note_label)

	_case_line = RichTextLabel.new()
	_case_line.name = "CaseQuery"
	_case_line.bbcode_enabled = true
	_case_line.fit_content = true
	_case_line.scroll_active = false
	_case_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_case_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for f in ["normal_font", "bold_font", "italics_font"]:
		_case_line.add_theme_font_override(f, ThemeUtil.mono())
	_case_line.add_theme_color_override("default_color", Color(0.85, 1.0, 0.85))
	_case_line.visible = false
	vbox.add_child(_case_line)

	_input = TextEdit.new()
	_input.custom_minimum_size = Vector2(0, 110)
	_input.placeholder_text = EXAMPLE
	_input.add_theme_font_override("font", ThemeUtil.mono())
	_input.add_theme_font_size_override("font_size", 18)
	_input.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_input.add_theme_color_override("background_color", Color(0.0, 0.1, 0.04))
	_input.syntax_highlighter = _sql_highlighter()
	_input.gui_input.connect(_on_input_key)
	_input.text_changed.connect(_typed)
	vbox.add_child(_input)

	_others = ThemeUtil.label("", 15, ThemeUtil.DIM)
	_others.add_theme_font_override("font", ThemeUtil.mono())
	_others.visible = false
	vbox.add_child(_others)

	_foot = ThemeUtil.label(FOOT, 15, ThemeUtil.DIM)
	vbox.add_child(_foot)
	PadReader.attach(self, _on_pad, _on_stick)
	book = TerminalNotebook.new()
	book.name = "TerminalNotebook"
	if get_parent():
		get_parent().add_child.call_deferred(book)
	else:
		add_child(book)
	var game := get_node_or_null("/root/Game")
	if game:
		game.notebook_changed.connect(_words_check)
		game.notebook_changed.connect(show_case_query)
	InputGlyphs.watch(self).changed.connect(_on_device_changed)  # a method: it goes when the screen does


## The notebook below the screen lives beside this window, so it goes with it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and book and is_instance_valid(book) and book.get_parent() != self:
		book.queue_free()


func open(from_terminal: Node, by_player: Player) -> void:
	terminal = from_terminal
	player = by_player
	player.input_locked = true
	# Its own history, shared by everyone who uses it; Up starts from the newest.
	_history = _history_of(terminal)
	_history_i = _history.size()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title.text = "HALCYON DATA SYSTEMS  //  %s" % terminal.terminal_name
	visible = true
	# Each terminal keeps its own screen; in co-op it shows everyone's queries.
	terminal.ensure_booted()
	_look = {}
	_apply_look()
	_show_transcript()
	if not terminal.screen_changed.is_connected(_show_others):
		terminal.screen_changed.connect(_show_others)
	var mirror := _mirror()
	if mirror:
		mirror.seat(terminal, true)
	_show_others()
	show_case_query()
	_input.syntax_highlighter = _sql_highlighter()  # the names on this player's Tables page by now
	_input.grab_focus()
	_show_foot()
	PadReader.show_keyboard(_input.text)
	_tapped.clear()
	if book and book.is_inside_tree():
		book.open(self, player)


## Open on the terminal's own CRT (a TerminalScreen) instead of over the whole
## view: the player has stepped up and is looking at the glass.
func open_on_screen(from_terminal: Node, by_player: Player, screen: Node) -> void:
	_home = get_parent()
	_screen = screen
	_set_hosted(true)
	screen.host(self)
	open(from_terminal, by_player)


func is_on_screen() -> bool:
	return _screen != null


func _set_hosted(on: bool) -> void:
	_dim.visible = not on
	var margin := Vector2.ZERO if on else Vector2(120, 60)
	_panel.offset_left = margin.x
	_panel.offset_right = -margin.x
	_panel.offset_top = margin.y
	_panel.offset_bottom = -margin.y
	if _output == null:
		return
	# On the glass the text stays the size it was when you walked up
	# (TerminalScreen.TYPE_SIZE), so it doesn't shrink when you sit down.
	var big := TerminalScreen.TYPE_SIZE
	_output.add_theme_font_size_override("normal_font_size", big if on else 17)
	_output.add_theme_font_size_override("bold_font_size", big if on else 17)
	_input.add_theme_font_size_override("font_size", big if on else 18)
	_note_label.add_theme_font_size_override("font_size", big if on else 17)
	_title.add_theme_font_size_override("font_size", TerminalScreen.TITLE_SIZE if on else 18)
	for l in [_others, _foot]:
		l.add_theme_font_size_override("font_size", 20 if on else 15)
	_add_chip.add_theme_font_size_override("font_size", 18 if on else 13)
	for f in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		_case_line.add_theme_font_size_override(f, big if on else 17)
	_input.custom_minimum_size.y = big * 4 if on else 110
	# Subtitles move above the glass, off the line you're typing.
	var hud = _hud()
	if hud and hud.has_method("subtitles_on_top"):
		hud.subtitles_on_top(on)


## The level's HUD, found from the terminal's level (duck-typed, like Document._level).
func _hud() -> Node:
	var n: Node = terminal if terminal and is_instance_valid(terminal) else _screen
	while n and n.get("hud") == null:
		n = n.get_parent()
	return n.get("hud") if n else null


## Off the glass and back where it lives; the player steps back from the desk.
func _leave_screen() -> void:
	var screen := _screen
	_screen = null
	if screen and is_instance_valid(screen) and screen.hosted == self:
		screen.release()
	_set_hosted(false)
	if _home and is_instance_valid(_home) and get_parent() == null:
		_home.add_child(self)


func close() -> void:
	if not visible:
		return
	visible = false
	_input.release_focus()
	_stop_picking()
	_cancel_note()
	if book:
		book.close()
	PadReader.hide_keyboard()
	if terminal and terminal.has_signal("screen_changed"):
		if terminal.screen_changed.is_connected(_show_others):
			terminal.screen_changed.disconnect(_show_others)
		var mirror := _mirror()
		if mirror:
			mirror.seat(terminal, false)
	if player:
		player.input_locked = false
		if _screen and player.has_method("leave_terminal"):
			player.leave_terminal()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _screen:
		# Not mid-way through the key that closed it, which the glass is still handing on.
		_leave_screen.call_deferred()
	closed.emit()


## Print a line on the open terminal's screen (everyone's copy of it, in co-op).
## `kind` says what it is, for the notebook; "" works it out.
func print_line(bbcode: String, kind: String = "") -> void:
	var mirror := _mirror()
	if mirror:
		mirror.line(terminal, bbcode, kind)
	elif terminal and terminal.has_method("print_line"):
		terminal.print_line(bbcode, kind)
	else:
		_render(bbcode, kind)


## A terminal's screen changed. Show it if that's the one open here.
func on_terminal_line(from_terminal: Node, bbcode: String, kind: String = "") -> void:
	if visible and from_terminal == terminal:
		_render(bbcode, kind)


## A terminal's screen was wiped. Clear it if that's the one open here.
func on_terminal_cleared(from_terminal: Node) -> void:
	if visible and from_terminal == terminal:
		_clear_output()


## The level's terminal mirror, when this terminal belongs to a synced level.
## None once the connection has dropped: the screen is then this machine's alone.
func _mirror() -> TerminalMirror:
	if terminal == null or not terminal.has_signal("screen_changed"):
		return null
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return null
	var sync := LevelSync.of(terminal)
	return sync.mirror if sync else null


## The input line changed: show it on everyone's copy of the screen.
func _typed() -> void:
	last_typed_msec = Time.get_ticks_msec()
	if visible and terminal and terminal.has_method("sound"):
		terminal.sound("key")
	var mirror := _mirror()
	if mirror and visible:
		mirror.typed(terminal, _input.text)
	if book and visible:
		book.refresh()


## What's typed before the cursor: what the next-word buttons follow.
func text_before_caret() -> String:
	var line := _input.get_caret_line()
	var lines := PackedStringArray()
	for i in line:
		lines.append(_input.get_line(i))
	lines.append(_input.get_line(line).substr(0, _input.get_caret_column()))
	return "\n".join(lines)


## What the next-word buttons read: the text before the cursor, past a pair the
## cursor sits inside once something's typed in it (KeywordHelp.past_pair).
func button_text() -> String:
	var before := text_before_caret()
	return KeywordHelp.past_pair(before, _input.text.substr(before.length()))[0]


## Write `word` in at the cursor, as if typed, over the `replace` characters
## before it (a word half typed): a next-word button was picked.
func insert_word(word: String, replace: int = 0) -> void:
	var caret := text_before_caret()
	var parts := KeywordHelp.past_pair(caret, _input.text.substr(caret.length()))
	var before: String = parts[0]
	var after: String = parts[1]
	# A found value ('fault') picked in an empty pair of quotes brings its own.
	if replace > 0 and before.substr(before.length() - replace).begins_with("'") and after.begins_with("'"):
		after = after.substr(1)
	var done := KeywordHelp.insert(before, word, replace)
	var new_before: String = done[0]
	_input.text = new_before + after
	var at := new_before.length() - int(done[1])
	var head := new_before.substr(0, at)
	_input.set_caret_line(head.count("\n"))
	_input.set_caret_column(head.length() - (head.rfind("\n") + 1))
	_tapped.append(word)
	_typed()
	_input.grab_focus()


## A full-screen terminal makes room for the notebook below it (TerminalNotebook):
## `top` is how much of the screen's height the window keeps.
func make_room(top: float) -> void:
	if _panel == null or is_on_screen():
		return
	_panel.anchor_bottom = top
	_panel.offset_bottom = -60.0 if top >= 1.0 else -6.0

## Name the other players at this terminal and show what they're typing.
func _show_others() -> void:
	if terminal == null or not visible:
		return
	if _apply_look():
		_show_transcript()  # whoever sat first has a look of their own: redraw in it
	var me := multiplayer.get_unique_id()
	var net := get_node_or_null("/root/Net")
	var lines := PackedStringArray()
	for peer in terminal.seated:
		if peer == me:
			continue
		var who: String = net.display_name(peer) if net else "Player %d" % peer
		var text: String = terminal.typing.get(peer, "")
		lines.append("%s> %s_" % [who, text.replace("\n", " ")] if text != "" else "%s is here" % who)
	_others.text = "\n".join(lines)
	_others.visible = not lines.is_empty()


## Put a line on this machine's screen. Every non-blank line can be pointed at
## and added to this player's own notebook; "none" lines can't.
func _render(bbcode: String, kind: String = "") -> void:
	if not _look.is_empty():
		bbcode = TerminalLook.recolor(bbcode, _look)
	var text := _plain(bbcode).strip_edges()
	if text == "" or kind == "none":
		_output.append_text(bbcode + "\n")
		return
	if kind == "":
		kind = "error" if text.begins_with("ERROR") else ("hint" if text.begins_with("[SYSOP]") else "info")
	if kind == "echo":
		_last_query = text.substr(text.find(">") + 1).strip_edges() if text.contains(">") else text
	var from := _output.get_paragraph_count() - 1
	_output.append_text(bbcode + "\n")
	if kind == "result" and (text.begins_with("{") or text.begins_with("[")):
		# A request's answer: the whole of it from its first line, and each field
		# line ("edited_by": "EXEC-30") a cell of its own.
		var lines := bbcode.split("\n")
		_noteable.append({"kind": kind, "text": text, "from": from, "to": from + 1})
		for i in range(1, lines.size()):
			var field := json_field(_plain(lines[i]))
			if not field.is_empty():
				_noteable.append({"kind": "field", "text": _plain(lines[i]).strip_edges(), "from": from + i, "to": from + i + 1,
					"cells": [field], "query": _last_query})
	elif kind == "result" and bbcode.count("\n") >= 3:
		# A table: its header line copies the whole result, and each row (under
		# the rule, above the row count) is a line of its own, copied with the header.
		# Each of a row's cells can be pointed at on its own.
		var rows := bbcode.split("\n")
		_noteable.append({"kind": kind, "text": text, "from": from, "to": from + 1})
		var head_line := _plain(rows[0])
		var head := head_line.strip_edges()
		for i in range(2, rows.size() - 1):
			_noteable.append({"kind": "row", "text": head + "\n" + _plain(rows[i]).strip_edges(), "from": from + i, "to": from + i + 1,
				"cells": row_cells(head_line, _plain(rows[i])), "query": _last_query})
	else:
		_noteable.append({"kind": kind, "text": text, "from": from, "to": _output.get_paragraph_count() - 1})
	_hover_line(picking, _hover_cell if picking >= 0 else -1)  # the screen may scroll under the pointer


func _process(delta: float) -> void:
	if not visible or terminal == null or not is_instance_valid(terminal):
		_unclicked = 0.0
		return
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = 0.5
		_answer_now = answer_on_screen()
	if _answer_now == "" or _answer_now in _nudged:
		_unclicked = 0.0
		return
	_unclicked += delta
	if _unclicked < NUDGE_AFTER:
		return
	_nudged.append(_answer_now)
	_unclicked = 0.0
	var hud = _hud()
	var line := VoiceLines.get_line(NUDGE_LINE)
	if hud and hud.has_method("say") and not line.is_empty():
		var net := get_node_or_null("/root/Net")
		var me: String = net.display_name(multiplayer.get_unique_id()) if net and net.has_method("display_name") else ""
		hud.say(me if me != "" else "You", line.text, -1.0, HUD.Turn.CAN_WAIT)


## The open case whose answer is in a cell on screen right now, or "". The nudge
## clock (_unclicked) restarts whenever nothing on screen answers anything.
func answer_on_screen() -> String:
	if _output == null:
		return ""
	var game := get_node("/root/Game")
	var top := _output.get_v_scroll_bar().value
	var bottom := top + _output.size.y
	for i in range(_noteable.size() - 1, -1, -1):
		var e: Dictionary = _noteable[i]
		if not e.has("cells"):
			continue
		var y := _para_top(e.from)
		if y > bottom:
			continue
		if y + _line_height() < top:
			break
		var row := _row_of(i)
		for c in e.cells:
			var id: String = game.answers_cell(c.column, c.value, row)
			if id != "":
				return id
	return ""


## What on screen right now can be written into the notebook, oldest first.
func noteable_lines() -> Array[Dictionary]:
	return _noteable.duplicate(true)


## A result row's cells, read off its line by the header's columns (the table is
## fixed-width): [{column, value, start, end}], start and end in characters.
static func row_cells(header: String, row: String) -> Array:
	var cells := []
	var at := 0
	var names := header.split(" | ")
	for i in names.size():
		var width: int = names[i].length() if i < names.size() - 1 else maxi(names[i].length(), row.length() - at)
		cells.append({"column": names[i].strip_edges(), "value": row.substr(at, width).strip_edges(), "start": at, "end": at + width})
		at += width + 3
	return cells


## A request's field line as a cell: "edited_by": "EXEC-30", gives {column
## edited_by, value EXEC-30}. A line that opens an object or a list isn't one.
static func json_field(line: String) -> Dictionary:
	var re := RegEx.create_from_string('^(\\s*)"([^"]+)"\\s*:\\s*(.*?),?\\s*$')
	var m := re.search(line)
	if m == null:
		return {}
	var raw := m.get_string(3)
	if raw.begins_with("{") or raw.begins_with("["):
		return {}
	var value := raw.trim_prefix('"').trim_suffix('"') if raw.begins_with('"') else raw
	return {"column": m.get_string(2), "value": "NULL" if raw == "null" else value, "start": m.get_string(1).length(), "end": line.rstrip(", ").length()}


## The row behind line `index`'s cells, column -> value: what names the row.
func _row_of(index: int) -> Dictionary:
	var row := {}
	for c in _noteable[index].get("cells", []):
		row[c.column] = c.value
	return row


## Point at cell `cell` of line `index`: if it answers a case's slot it's written
## in there (Game.add_cell). Otherwise the line is noted, as any line can be.
func use_cell(index: int, cell: int) -> bool:
	if index < 0 or index >= _noteable.size():
		return false
	var cells: Array = _noteable[index].get("cells", [])
	if cell < 0 or cell >= cells.size():
		_start_note(index)
		return false
	var c: Dictionary = cells[cell]
	if get_node("/root/Game").add_cell(c.column, c.value, _row_of(index), _noteable[index].get("query", ""), "terminal"):
		_render("[color=#7fa88a]Written in your notebook.[/color]", "none")  # and it slides up (CaseChip)
		return true
	_start_note(index)
	return false


## Copy line `index` into this player's notebook, with an optional label. A line
## that answers a case's blank goes in the blank instead (answer()).
func write_note(index: int, label: String = "") -> bool:
	if index < 0 or index >= _noteable.size():
		return false
	if answer(index):
		return true
	var line: Dictionary = _noteable[index]
	get_node("/root/Game").write_note(label.strip_edges(), line.text, line.kind, terminal.hint_case() if terminal else "")
	_render("[color=#7fa88a]Written in your notebook%s.[/color]" % (": " + label.strip_edges() if label.strip_edges() != "" else ""), "none")
	return true


func _on_meta(meta: Variant) -> void:
	var m := str(meta)
	if m.begins_with("note:"):
		_start_note(int(m.substr(5)))


## Line `index` answers a case's blank (Game.add_answer): it's written in there,
## with no name to give it, and it slides up (CaseChip) while you stay at the
## screen. False if it answers nothing.
func answer(index: int) -> bool:
	if index < 0 or index >= _noteable.size() or not get_node("/root/Game").add_answer(_noteable[index].text, "terminal"):
		return false
	_render("[color=#7fa88a]Written in your notebook.[/color]", "none")
	return true


## Ask for an optional name, then write line `index` into the notebook.
func _start_note(index: int) -> void:
	if index < 0 or index >= _noteable.size():
		return
	if answer(index):
		return
	_note_index = index
	_note_label.text = ""
	_note_label.visible = true
	_note_label.grab_focus()
	PadReader.show_keyboard("")


## Clicking the screen's text to select it takes the keyboard from the typing
## line. Ctrl+C copies the selection and hands the keyboard back, ready to paste;
## typing and pasting go straight to the typing line. (Other Ctrl keys, like
## select-all, stay with the text.)
func _on_output_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index := _line_at(event.position.y)
		_hover_line(index, _cell_at(index, event.position.x))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed \
			and _hover_index >= 0 and _hover_cell >= 0 and _output.get_selected_text() == "":
		use_cell(_hover_index, _hover_cell)  # a click on a cell, not a drag to select
	elif event is InputEventKey and event.pressed:
		if event.is_action("ui_copy", true):
			_input.grab_focus.call_deferred()
		elif event.keycode not in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META] and (event.is_action("ui_paste", true) or not (event.ctrl_pressed or event.meta_pressed)):
			_output.accept_event()
			_input.grab_focus()
			get_viewport().push_input.call_deferred(event)


## Which noteable line is at this height in the output, or -1.
func _line_at(y: float) -> int:
	_output.get_content_height()  # lay out first: that can move the scroll
	var at := y + _output.get_v_scroll_bar().value
	for i in range(_noteable.size() - 1, -1, -1):
		var top := _para_top(_noteable[i].from)
		if at >= top:
			return i if at < _para_top(_noteable[i].to) else -1
	return -1


## Light up line `index` (-1 for none), or just its cell `cell`, and put the add
## chip at the line's right end.
func _hover_line(index: int, cell: int = -1) -> void:
	_hover_index = index
	var on := index >= 0 and index < _noteable.size()
	_hover_cell = cell if on and cell < _noteable[index].get("cells", []).size() else -1
	_hover_band.visible = on
	_add_chip.visible = on
	if not on:
		return
	_output.get_content_height()
	var scroll := _output.get_v_scroll_bar().value
	var top := _para_top(_noteable[index].from) - scroll
	var bottom := _para_top(_noteable[index].to) - scroll
	_hover_band.position = Vector2(0, top)
	_hover_band.size = Vector2(_output.size.x, maxf(bottom - top, 4.0))
	if _hover_cell >= 0:
		var c: Dictionary = _noteable[index].cells[_hover_cell]
		var w := _char_width()
		_hover_band.position.x = _text_left() + c.start * w - 3.0
		_hover_band.size.x = (c.end - c.start) * w + 6.0
	_add_chip.reset_size()
	_add_chip.position = Vector2(_output.size.x - _add_chip.size.x - 18, top + (bottom - top - _add_chip.size.y) / 2.0)


## Which cell of line `index` is at `x` in the output, or -1 (no cells, between
## them, or a line long enough to wrap, where columns don't line up).
func _cell_at(index: int, x: float) -> int:
	if index < 0 or index >= _noteable.size() or not _noteable[index].has("cells"):
		return -1
	var e: Dictionary = _noteable[index]
	if _para_top(e.to) - _para_top(e.from) > _line_height() * 1.5:
		return -1
	var at := (x - _text_left()) / _char_width()
	for i in e.cells.size():
		if at >= e.cells[i].start and at < e.cells[i].end:
			return i
	return -1


func _char_width() -> float:
	return ThemeUtil.mono().get_char_size("M".unicode_at(0), _output.get_theme_font_size("normal_font_size")).x


func _line_height() -> float:
	return ThemeUtil.mono().get_height(_output.get_theme_font_size("normal_font_size"))


func _text_left() -> float:
	var box := _output.get_theme_stylebox("normal")
	return box.get_margin(SIDE_LEFT) if box else 0.0


## Where paragraph `p` starts in the output's content. Asking for the content
## height first makes sure the text has been laid out.
func _para_top(p: int) -> float:
	_output.get_content_height()
	return _output.get_paragraph_offset(p)


func _chip_hovered() -> bool:
	return _add_chip.visible and _add_chip.get_global_rect().has_point(_add_chip.get_global_mouse_position())


func _finish_note(label: String) -> void:
	write_note(_note_index, label)
	_cancel_note()


func _cancel_note() -> void:
	_note_index = -1
	_note_label.visible = false
	if visible:
		_input.grab_focus()


func _on_note_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_note_label.accept_event()
		_cancel_note()


## Everything on the open terminal's screen so far, drawn afresh.
func _show_transcript() -> void:
	_clear_output()
	for i in terminal.transcript.size():
		_render(terminal.transcript[i], terminal.transcript_kinds[i] if i < terminal.transcript_kinds.size() else "")


## Draw in the open terminal's look (its text theme and screen). True if it changed.
func _apply_look() -> bool:
	var l: Dictionary = terminal.look if terminal and terminal.get("look") is Dictionary and not terminal.look.is_empty() else TerminalLook.standard()
	if l == _look:
		return false
	_look = l
	_style.bg_color = l.bg
	_style.border_color = l.rule
	_output.add_theme_color_override("default_color", l.text)
	_hover_band.color = Color(l.text, 0.12)
	_add_chip.add_theme_color_override("font_color", Color(l.text, 0.75))
	_input.add_theme_color_override("font_color", l.row)
	_input.add_theme_color_override("background_color", l.bg.lerp(l.text, 0.06))
	_input.syntax_highlighter = _sql_highlighter()
	return true


func _clear_output() -> void:
	_output.clear()
	_noteable.clear()
	_hover_line(-1)


static func _plain(bbcode: String) -> String:
	var text := RegEx.create_from_string("\\[(?!lb\\]|rb\\])[^\\]]*\\]").sub(bbcode, "", true)
	return text.replace("[lb]", "[").replace("[rb]", "]")


## A message from SYSOP: an unknown user on the system who sends tips, nudges
## and .hint answers. (Players never learn who it is until much later.)
## Its messages are cyan, in the terminal's own colours: SQL keywords gold, as on
## the input line, and names like memo_fragments amber, as in a table's header,
## in its queries and in the advice around them alike. Only capitals count as
## keywords, so "or" in a sentence stays plain.
## An UPDATE, INSERT, DELETE or REPLACE: a statement whose answer is how many rows it changed.
static func _changes_rows(sql: String) -> bool:
	var head := sql.strip_edges().to_upper()
	return ["UPDATE", "INSERT", "DELETE", "REPLACE"].any(func(w): return head.begins_with(w))


static func sysop(text: String) -> String:
	return "[color=%s][lb]SYSOP[rb]: %s[/color]" % [HINT, _words(text)]


## Keywords gold and snake_case names amber, leaving BBCode tags alone.
static func _words(text: String) -> String:
	return _outside_tags(text, func(t: String) -> String:
		return _keyword_re().sub(_names(t), "[color=%s]$1[/color]" % KEYWORD, true))


static func _names(text: String) -> String:
	return RegEx.create_from_string("\\b([a-z]+(?:_[a-z0-9]+)+)\\b").sub(text, "[color=%s]$1[/color]" % TABLE_HEAD, true)


static func _keyword_re() -> RegEx:
	var words: Array = ["ORDER BY", "GROUP BY"] + KEYWORDS
	return RegEx.create_from_string("\\b(%s)\\b" % "|".join(words))


## Apply `fn` to the text between BBCode tags, leaving the tags alone.
static func _outside_tags(text: String, fn: Callable) -> String:
	var out := ""
	var at := 0
	for m in RegEx.create_from_string("\\[[^\\]]*\\]").search_all(text):
		out += fn.call(text.substr(at, m.get_start() - at)) + m.get_string()
		at = m.get_end()
	return out + fn.call(text.substr(at))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _on_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_ESCAPE:
		_input.accept_event()
		close()
	elif event.keycode == KEY_TAB and book and book.is_open():
		_input.accept_event()
		book.toggle()
	elif (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and not event.shift_pressed:
		_input.accept_event()
		_enter()
	elif event.keycode == KEY_UP and _input.get_caret_line() == 0 and not _history.is_empty():
		_input.accept_event()
		_history_step(-1)
	elif event.keycode == KEY_DOWN and _input.get_caret_line() == _input.get_line_count() - 1 and not _history.is_empty():
		_input.accept_event()
		_history_step(1)


## Enter: run what's typed if it's a whole statement, or carry on to the next line.
func _enter() -> void:
	if is_complete(_input.text):
		_submit()
	else:
		_continue_statement()


## Up (-1) or down (+1) through this terminal's earlier queries; past the newest, a blank line.
func _history_step(step: int) -> void:
	if _history.is_empty():
		return
	_history_i = clampi(_history_i + step, 0, _history.size() if step > 0 else _history.size() - 1)
	_input.text = _history[_history_i] if _history_i < _history.size() else ""
	_input.set_caret_line(_input.get_line_count() - 1)
	_input.set_caret_column(_input.get_line(_input.get_line_count() - 1).length())
	_typed()


## A gamepad press while the screen is up (PadReader). Typing is the on-screen
## keyboard's; the buttons do what the keys round it do: Y runs, the d-pad walks
## the history, X picks a line for the notebook, B steps away (Menu too).
func _on_pad(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventJoypadMotion:
		return true  # the sticks are polled (scrolling); kept off the focus
	if not event.is_pressed() or event.is_echo():
		return false
	if book and not _note_label.visible and picking < 0 and book.on_pad(event):
		return true  # looked down at the notebook: the d-pad, A and LB/RB are its
	if _note_label.visible:  # naming a note: Y writes it in, B leaves it
		if event.is_action_pressed("alt_interact"):
			_finish_note(_note_label.text)
			return true
		if event.is_action_pressed("ui_cancel"):
			_cancel_note()
			return true
		return false
	if picking >= 0:
		var cells: int = _noteable[picking].get("cells", []).size()
		if event.is_action_pressed("ui_up"):
			_pick(picking - 1)
		elif event.is_action_pressed("ui_down"):
			_pick(picking + 1)
		elif event.is_action_pressed("ui_left") and cells > 0:
			_hover_line(picking, maxi(_hover_cell - 1, 0))
		elif event.is_action_pressed("ui_right") and cells > 0:
			_hover_line(picking, mini(_hover_cell + 1, cells - 1))
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("alt_interact"):
			var index := picking
			var cell := _hover_cell
			_stop_picking()
			use_cell(index, cell)
		elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
			_stop_picking()
		else:
			return false
		return true
	if event.is_action_pressed("alt_interact"):
		_enter()
	elif event.is_action_pressed("ui_up"):
		_history_step(-1)
	elif event.is_action_pressed("ui_down"):
		_history_step(1)
	elif event.is_action_pressed("interact"):
		if not _noteable.is_empty():
			_pick(_noteable.size() - 1)  # the newest line first
	elif event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		pass  # keep the typing line focused
	else:
		return false
	return true


## The right stick scrolls the screen.
func _on_stick(v: Vector2, delta: float) -> void:
	if visible and v.y != 0.0:
		var bar := _output.get_v_scroll_bar()
		bar.value += v.y * PAD_SCROLL * delta


## Light up noteable line `index` (clamped) to add with the pad, scrolled into view.
func _pick(index: int) -> void:
	if _noteable.is_empty():
		return
	picking = clampi(index, 0, _noteable.size() - 1)
	_output.scroll_to_paragraph(_noteable[picking].from)
	_hover_line(picking, _hover_cell if picking >= 0 else -1)
	_show_foot()


func _stop_picking() -> void:
	if picking < 0:
		return
	picking = -1
	_hover_line(-1)
	_show_foot()


func _on_device_changed(_pad: bool) -> void:
	_show_foot()


## The foot line names the keys, or the pad's buttons while a pad is in use.
func _show_foot() -> void:
	if not _foot:
		return
	if not InputGlyphs.pad:
		_foot.text = FOOT
	elif picking >= 0:
		_foot.text = PAD_PICK_FOOT % [InputGlyphs.of("ui_accept"), InputGlyphs.of("ui_cancel")]
	else:
		_foot.text = PAD_FOOT % [InputGlyphs.of("alt_interact"), InputGlyphs.of("interact"), InputGlyphs.of("ui_cancel")]


## A red ; at the end of what was typed, blinking for a couple of seconds.
func _flash_semicolon() -> void:
	if not is_instance_valid(_semicolon):
		_semicolon = Label.new()
		_semicolon.name = "MissingSemicolon"
		_semicolon.text = ";"
		_semicolon.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_semicolon.add_theme_font_override("font", _input.get_theme_font("font"))
		_semicolon.add_theme_font_size_override("font_size", _input.get_theme_font_size("font_size"))
		_semicolon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_input.add_child(_semicolon)
	var line := _input.get_caret_line()
	var at := _input.get_rect_at_line_column(line, _input.get_line(line).length())
	_semicolon.position = Vector2(at.position.x + at.size.x, at.position.y) if at.position.x >= 0 else Vector2.ZERO
	_semicolon.visible = true
	if _semicolon_tween:
		_semicolon_tween.kill()
	_semicolon.modulate.a = 1.0
	_semicolon_tween = create_tween()
	for i in 4:
		_semicolon_tween.tween_property(_semicolon, "modulate:a", 0.15, 0.25)
		_semicolon_tween.tween_property(_semicolon, "modulate:a", 1.0, 0.25)
	_semicolon_tween.tween_callback(func(): _semicolon.visible = false)


## Is `text` ready to run? Like a real SQL prompt, a query runs only once it ends
## with ; (dot-commands need none, and requests follow request_complete).
static func is_complete(text: String) -> bool:
	var t := text.strip_edges()
	if t == "" or t.begins_with("."):
		return true
	if FacilityAPI.is_request(t):
		return request_complete(text)
	return t.ends_with(";")


## Is a web request whole? A GET or DELETE is one line, as on Level 2. A POST,
## PUT or PATCH carries on (header lines, a blank line, then the body) until its
## JSON body closes. Header lines after a GET (started with Shift+Enter) end with
## a blank line. A blank line after an unfinished body, or two blank lines, sends
## it anyway, so the service can say what's wrong.
static func request_complete(text: String) -> bool:
	var raw := text.replace("\r", "").strip_edges(true, false)
	var lines := raw.strip_edges().split("\n")
	var first := lines[0].strip_edges().split(" ", false, 2)
	var on_blank_line := raw.ends_with("\n")
	if raw.ends_with("\n\n"):
		return true
	var body := first[2] if first.size() > 2 else ""
	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if body == "" and (line.begins_with("{") or line.begins_with("[")):
			body = "\n".join(lines.slice(i))
			break
	if body != "":
		return on_blank_line or _json_closed(body)
	if first[0].to_upper() in ["POST", "PUT", "PATCH"]:
		return false
	return lines.size() == 1 or on_blank_line


## Do a JSON body's brackets all close? (Text inside quotes doesn't count.)
static func _json_closed(body: String) -> bool:
	var depth := 0
	var in_text := false
	var escaped := false
	for c in body:
		if in_text:
			if escaped:
				escaped = false
			elif c == "\\":
				escaped = true
			elif c == "\"":
				in_text = false
		elif c == "\"":
			in_text = true
		elif c == "{" or c == "[":
			depth += 1
		elif c == "}" or c == "]":
			depth -= 1
	return depth <= 0


## Enter before the statement is finished: it carries on, on a new line. For SQL
## a red ; flashes where it's missing.
func _continue_statement() -> void:
	var request := FacilityAPI.is_request(_input.text.strip_edges())
	var blank_line := _input.text.ends_with("\n") or _input.text.strip_edges() == ""
	_input.set_caret_line(_input.get_line_count() - 1)
	_input.set_caret_column(_input.get_line(_input.get_line_count() - 1).length())
	if not blank_line and not request:
		_flash_semicolon()
	_input.insert_text_at_caret("\n")
	_typed()
	if blank_line and request:
		print_line("[color=#6f8f6f]... now the JSON body. The request is sent once its { } close.[/color]")
	elif blank_line:
		print_line("[color=#6f8f6f]... the statement isn't finished until it ends with ;[/color]")


func _submit() -> void:
	var sql := _input.text.strip_edges()
	_input.text = ""
	if is_instance_valid(_semicolon):
		_semicolon.visible = false
	if sql == "":
		return
	_sent[KeywordHelp.same_query(sql)] = {"pad": InputGlyphs.pad, "tapped": _tapped.duplicate()}
	_tapped.clear()
	_history.append(sql)
	_history_i = _history.size()
	var mirror := _mirror()
	if mirror:
		mirror.submitted(terminal)
	if sql.begins_with(".") or terminal.is_locked():
		print_line(_echo(sql, ""), "echo")
	run(sql)


## The history of commands typed at `t`, by anyone.
func _history_of(t: Node) -> Array[String]:
	if not _histories.has(t):
		var h: Array[String] = []
		_histories[t] = h
	return _histories[t]


## A teammate's command at `on_terminal`, for Up and Down there. If it's the open
## terminal: scrolling back stays where it is; at the end, Up now starts from this one.
func _remember(on_terminal: Node, line: String) -> void:
	var h := _history_of(on_terminal)
	var at_end := on_terminal == terminal and (_history_i < 0 or _history_i >= h.size())
	h.append(line)
	if at_end:
		_history_i = h.size()


## Run a command or query as if typed. Public so tests and scripted events can use it.
## Queries go through the level's LevelSync, so in co-op the host runs them.
func run(sql: String) -> void:
	if sql.begins_with("."):
		_command(sql)
		return
	if terminal.is_locked():
		print_line("[color=#ff6655]%s[/color]" % terminal.locked_message)
		return
	var sync := LevelSync.of(terminal)
	if FacilityAPI.is_request(sql):
		if sync:
			sync.submit_request(terminal, sql)
		else:
			show_request(terminal, sql, terminal.api.request(sql) if terminal.api else {}, multiplayer.get_unique_id())
		return
	if sync:
		sync.submit_query(terminal, sql)
		return
	var result: Dictionary = terminal.query(sql) if terminal.has_method("query") else terminal.db.execute(sql)
	show_query(terminal, sql, result, multiplayer.get_unique_id())
	if result.ok:
		terminal.on_query(sql, result, self)


## What SYSOP says about an error: a typed-in placeholder gets its own answer.
static func _explain(on_terminal: Node, sql: String, error: String) -> String:
	var blanks: Dictionary = on_terminal.get("blanks") if on_terminal and on_terminal.get("blanks") != null else {}
	for blank in blanks:
		if RegEx.create_from_string("(?i)\\b%s\\b" % blank).search(sql) and error.contains(blank):
			return blanks[blank]
	var hint_blank := hint_blank_in(sql)
	if hint_blank != "" and error.to_lower().contains(hint_blank):
		return BLANK_TYPED % hint_blank
	return FacilityDB.explain_error(error)


## A hint's shape names each value to fill in (enter_column_name, enter_zone...):
## the first one typed into `sql` as it is, or "".
static func hint_blank_in(sql: String) -> String:
	var m := RegEx.create_from_string("(?i)\\b(enter_[a-z_]+)").search(sql)
	return m.get_string(1).to_lower() if m else ""


## Print a query and its result on `on_terminal`'s screen. `from_peer` typed it.
func show_query(on_terminal: Node, sql: String, result: Dictionary, from_peer: int) -> void:
	var mine := from_peer == multiplayer.get_unique_id()
	var who := ""
	if not mine:
		var net := get_node_or_null("/root/Net")
		who = net.display_name(from_peer) if net else "Player %d" % from_peer
	if not mine:
		_remember(on_terminal, sql)
	var out: Array = [[_echo(sql, who), "echo"]]
	if result.get("policy", "") == "refused":
		# The policy's refusal stands alone: no SYSOP line under it, nothing noted.
		# SYSOP answers the next .hint here instead (P9).
		on_terminal.set_meta("policy_refused", true)
		on_terminal.print_line(out[0][0], "echo")
		on_terminal.print_line("[color=#ff6655]%s[/color]" % TerminalPolicy.REFUSAL, "error")
		if on_terminal.has_method("sound"):
			on_terminal.sound("error")
		if on_terminal.has_signal("query_failed"):
			on_terminal.query_failed.emit(sql, result)
		return
	if not result.ok:
		out.append(["[color=#ff6655]ERROR: %s[/color]" % _esc(result.error), "error"])
		out.append([sysop(_explain(on_terminal, sql, result.error)), "hint"])
	else:
		if mine:
			get_node("/root/Game").log_query(sql)
			_note_tables(sql, on_terminal.db, "", result.get("columns", []))
			count_words(sql, on_terminal)
		else:
			_note_tables(sql, on_terminal.db, QUERY_BY % who)
		if result.rows.is_empty():
			if result.changes > 0:
				out.append(["OK. %d row(s) changed." % result.changes, "info"])
			elif _changes_rows(sql):
				# A write that matched nothing (a typo in its WHERE, say) reads as one.
				out.append(["0 rows changed.", "info"])
			else:
				out.append(["(0 rows)", "info"])
		else:
			out.append([_format_table(result.columns, result.rows), "result"])
			if result.get("capped", false):
				out.append([TerminalPolicy.CAPPED, "info"])
	# A hint's shape typed in as it is: a quoted blank runs but finds nothing useful
	# (an unquoted one is an error, explained above). So is ?, which SQLite takes
	# as an empty value.
	if result.ok and hint_blank_in(sql) != "":
		out.append([sysop(BLANK_TYPED % hint_blank_in(sql)), "hint"])
	elif sql.contains("????"):
		out.append([sysop(PIECE_TYPED), "hint"])
	elif sql.contains("?"):
		out.append([sysop("? is the blank from the hint. Type the real value in its place."), "hint"])
	for line in out:
		on_terminal.print_line(line[0], line[1])
	if on_terminal.has_method("sound"):
		on_terminal.sound("beep" if result.ok else "error")
	if not result.ok and on_terminal.has_signal("query_failed"):
		on_terminal.query_failed.emit(sql, result)


func _echo(sql: String, who: String) -> String:
	return "[color=#ffffff]%s> %s[/color]" % [_esc(who), _esc(sql).replace("\n", "\n  ")]


## Print an HTTP request and its response on `on_terminal`'s screen. An empty
## response means the terminal has no API. The host calls on_request itself.
func show_request(on_terminal: Node, line: String, res: Dictionary, from_peer: int) -> void:
	var mine := from_peer == multiplayer.get_unique_id()
	var who := ""
	if not mine:
		var net := get_node_or_null("/root/Net")
		who = net.display_name(from_peer) if net else "Player %d" % from_peer
		_remember(on_terminal, line)
	on_terminal.print_line(_echo(line, who), "echo")
	if res.is_empty():
		on_terminal.print_line("[color=#ff6655]No network API on this terminal. It only speaks SQL.[/color]")
		return
	if mine:
		get_node("/root/Game").log_query(line)
		if res.status < 400:
			count_words(line, on_terminal)
	var color := "#7dff8c" if res.status < 400 else "#ff6655"
	on_terminal.print_line("[color=%s]HTTP/1.0 %d %s[/color]" % [color, res.status, FacilityAPI.status_text(res.status)])
	on_terminal.print_line(_esc(res.text), "result")
	if on_terminal.has_method("sound"):
		on_terminal.sound("beep" if res.status < 400 else "error")
	if LevelSync.of(on_terminal) == null:
		on_terminal.on_request(line, res, self)


func _command(cmd: String) -> void:
	var parts := cmd.split(" ", false)
	var db: FacilityDB = terminal.db
	match parts[0].to_lower():
		".help":
			print_line("Commands:")
			# Under the policy, officially they don't exist: they still work (P7).
			if not terminal.policy:
				print_line("  .tables          list every table")
				print_line("  .schema NAME     show the columns of a table")
			print_line("  .hint            ask SYSOP for a hint")
			print_line("  .clear           clear the screen")
			print_line("  .note LABEL      write the last line into your notebook (or point at a line)")
			print_line("  .reset           restore this terminal's data from backup")
			if terminal.api != null:
				print_line("  GET /path        send a web request, e.g. GET /cameras")
			if terminal.get_meta("scripts", false):
				print_line("  .script          write and run a script (JavaScript)")
			print_line("Anything else is run as SQL. End queries with ; (optional).")
			if terminal.policy:
				print_line(TerminalPolicy.HELP_LINE)
		".tables":
			if terminal.is_locked():
				print_line("[color=#ff6655]%s[/color]" % terminal.locked_message)
				return
			print_line("  ".join(db.table_names()))
			# Only the names: a table's columns are written down once .schema or
			# SELECT * shows them (Augustine, 2026-11-07).
			for t in db.table_names():
				get_node("/root/Game").discover_table(t, [])
			count_words(".tables", terminal)
		".schema":
			if terminal.is_locked():
				print_line("[color=#ff6655]%s[/color]" % terminal.locked_message)
				return
			var names: Array = db.table_names() if parts.size() < 2 else [parts[1]]
			for t in names:
				var cols := db.table_schema(t)
				if cols.is_empty():
					print_line("[color=#ff6655]No table named %s. Try .tables[/color]" % _esc(t))
					continue
				var desc := PackedStringArray()
				for c in cols:
					desc.append("%s %s" % [c["name"], c["type"]])
				print_line("[color=%s]%s[/color](%s)" % [TABLE_HEAD, t, ", ".join(desc)], "schema")
				_discover(t, db)
				var level := _level_of(terminal)
				if level:
					level.found_spot("schema:" + t)  # a hint spot for a table's columns
				if parts.size() >= 2:
					count_words(".schema " + t, terminal)
		".hint":
			var case_id: String = terminal.hint_case()
			var policy_hint := _policy_hint(terminal)
			print_line(sysop(_noted_hint(case_id, policy_hint if policy_hint != "" else terminal.next_hint())), "hint")
			if is_inside_tree():
				get_tree().call_group(Commentary.GROUP, "hinted")
		".clear":
			var mirror := _mirror()
			if mirror:
				mirror.clear(terminal)
			else:
				_clear_output()
				terminal.clear_screen()
		".note":
			var last := -1
			for i in range(_noteable.size() - 1, -1, -1):
				if not _noteable[i].kind in ["echo", "row"]:  # a table's last line is its whole result
					last = i
					break
			if last < 0:
				_render("Nothing on screen to write down yet.", "none")
			else:
				write_note(last, " ".join(parts.slice(1)))
		".script":
			if not terminal.get_meta("scripts", false):
				print_line("[color=#ff6655]Unknown command %s. Try .help[/color]" % _esc(parts[0]))
				return
			open_script_editor()
		".reset":
			var sync := LevelSync.of(terminal)
			if sync:
				sync.reset_db(terminal)
			else:
				db.reset()
				print_line("Backup tape restored. Data is back to how it started.")
		_:
			print_line("[color=#ff6655]Unknown command %s. Try .help[/color]" % _esc(parts[0]))


## Steps from the terminal to its script runner. Terminals that take scripts
## have the "scripts" meta set by their level. Each terminal keeps its own
## runtime and saved script, so a script left running here keeps running.
func open_script_editor() -> ScriptEditorUI:
	if _editor == null:
		_editor = ScriptEditorUI.new()
		# Beside this window, not on a terminal's glass it may be showing on.
		(_home if _screen and _home else get_parent()).add_child(_editor)
		_editor.saved.connect(func(c: String):
			if is_instance_valid(_script_terminal):
				_script_terminal.set_meta("script_code", c))
	var on: Node = terminal
	var rt: ScriptRuntime = on.get_meta("script_runtime") if on.has_meta("script_runtime") else null
	if rt == null:
		rt = ScriptRuntime.for_language("javascript")
		on.set_meta("script_runtime", rt)
	var game := get_node_or_null("/root/Game")
	var who := player
	close()
	_script_terminal = on
	_editor.open(rt, {
		"title": on.terminal_name,
		"library": BuildingLibrary.new(on.api, on.db, on.get("policy") == true),
		"seed": game.run_seed if game else 0,
		"code": on.get_meta("script_code", ""),
		"player": who,
		"skin": on.skin_color,
		# A level that ticks this terminal's runtimes itself (B1's decks) says so.
		"ticks": not on.get_meta("ticked_elsewhere", false),
	})
	return _editor


## Every hint asked for also goes on its puzzle's case page. Returns the hint.
## SYSOP's answer to `.hint` just after the policy refused a query here (P9), or
## "": point at the posted card until someone in the crew has read a copy, then
## say it plainly, once a floor.
func _policy_hint(on_terminal: Node) -> String:
	if not on_terminal.get_meta("policy_refused", false):
		return ""
	on_terminal.set_meta("policy_refused", false)
	var game := get_node("/root/Game")
	if not game.spot_found(TerminalPolicy.SPOT):
		return TerminalPolicy.HINT_UNREAD
	var here := str(game.floor_start.get("key", ""))
	if game.policy_explained == here and here != "":
		return ""
	game.policy_explained = here
	return TerminalPolicy.HINT_READ


## The level `node` is in (one with found_spot), or null.
static func _level_of(node: Node) -> Node:
	var n := node
	while n and not n.has_method("found_spot"):
		n = n.get_parent()
	return n


func _noted_hint(case_id: String, hint: String) -> String:
	if case_id != "":
		get_node("/root/Game").add_clue(case_id, _plain(hint), "SYSOP hint")
	return hint


## Tables a query read from go on the notebook's Tables page: with every column
## after SELECT *, otherwise with the columns its result showed. A crewmate's
## (`by` says whose) only finds the case pieces seen in them.
func _note_tables(sql: String, db: FacilityDB, by: String = "", shown: Array = []) -> void:
	var known: Array = db.table_names()
	var star := RegEx.create_from_string("(?i)\\bSELECT\\s+(?:DISTINCT\\s+)?\\*").search(sql) != null
	for m in RegEx.create_from_string("(?i)\\b(?:FROM|JOIN)\\s+([A-Za-z_][A-Za-z0-9_]*)").search_all(sql):
		var t := m.get_string(1).to_lower()
		for name in known:
			if name.to_lower() == t and by != "":
				get_node("/root/Game").see_table_pieces(name, by)
			elif name.to_lower() == t and star:
				_discover(name, db)
			elif name.to_lower() == t:
				var cols: Array = db.table_schema(name).map(func(c): return c["name"])
				get_node("/root/Game").discover_table(name, cols.filter(func(c): return shown.has(c)))


func _discover(table: String, db: FacilityDB) -> void:
	var cols := []
	for c in db.table_schema(table):
		cols.append(c["name"])
	if not cols.is_empty():
		get_node("/root/Game").discover_table(table, cols)


func _format_table(columns: Array, rows: Array) -> String:
	var widths := []
	for c in columns:
		widths.append(min(str(c).length(), MAX_COL_WIDTH))
	var shown := rows.slice(0, MAX_ROWS_SHOWN)
	for row in shown:
		for i in columns.size():
			widths[i] = clamp(max(widths[i], _cell(row[columns[i]]).length()), 1, MAX_COL_WIDTH)
	var lines := PackedStringArray()
	var header := PackedStringArray()
	var rule := PackedStringArray()
	for i in columns.size():
		header.append(_pad(str(columns[i]), widths[i]))
		rule.append("-".repeat(widths[i]))
	# Results read apart from everything else: an amber header, then rows in two
	# alternating shades so the eye can follow one across.
	lines.append("[b][color=%s]%s[/color][/b]" % [TABLE_HEAD, _esc(" | ".join(header))])
	lines.append("[color=%s]%s[/color]" % [TABLE_RULE, " + ".join(rule).replace(" + ", "-+-")])
	for r in shown.size():
		var cells := PackedStringArray()
		for i in columns.size():
			cells.append(_pad(_cell(shown[r][columns[i]]), widths[i]))
		lines.append("[color=%s]%s[/color]" % [TABLE_ROWS[r % 2], _esc(" | ".join(cells))])
	var footer := "(%d row%s)" % [rows.size(), "" if rows.size() == 1 else "s"]
	if rows.size() > MAX_ROWS_SHOWN:
		footer += "  showing first %d. Try LIMIT or WHERE." % MAX_ROWS_SHOWN
	lines.append("[color=%s]%s[/color]" % [TABLE_RULE, footer])
	return "\n".join(lines)


func _cell(v: Variant) -> String:
	return "NULL" if v == null else str(v)


func _pad(s: String, w: int) -> String:
	if s.length() > w:
		return s.substr(0, w - 1) + "~"
	return s + " ".repeat(w - s.length())


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


## The typing line's colors: the look's words and values, and the tables and
## columns on this player's Tables page (only ones they've found) by kind.
func _sql_highlighter() -> CodeHighlighter:
	var l: Dictionary = _look if not _look.is_empty() else TerminalLook.standard()
	var h := CodeHighlighter.new()
	# Words, numbers and quoted text follow the screen's look, as the echoed query
	# does; tables and columns found keep their kind's color (PieceKind), as on the
	# case board.
	h.number_color = l.number
	h.symbol_color = l.row.lerp(l.text, 0.3)
	h.function_color = l.row
	h.member_variable_color = l.row
	var game := get_node_or_null("/root/Game")
	if game:
		for t in game.notebook_tables:
			for col in game.notebook_tables[t]:
				h.add_keyword_color(str(col), PieceKind.color(PieceKind.COLUMN))
		for t in game.notebook_tables:
			h.add_keyword_color(str(t), PieceKind.color(PieceKind.TABLE))
	var kw: Color = l.keyword
	for word in KEYWORDS:
		h.add_keyword_color(word, kw)
		h.add_keyword_color(word.to_lower(), kw)
	h.add_color_region("'", "'", l.string)
	return h


## The selected case's query: just above the typing line, and as its grey
## example (P8). With none: the plain example, and no line.
func show_case_query() -> void:
	if _input == null:
		return
	var game := get_node_or_null("/root/Game")
	var id: String = game.case_selected() if game else ""
	var q: String = game.case_query(id) if id != "" else ""
	_input.placeholder_text = q if q != "" else EXAMPLE
	_case_line.text = PieceKind.query_bbcode(game.case_info(id), game.PIECE_MISSING) if q != "" else ""
	_case_line.visible = q != ""


# --- The next-word buttons' counts ----------------------------------------------------

## A query or command of this player's ran without an error: each word in it
## counts once toward its button coming off (KeywordHelp.USES), unless the exact
## same query was counted already this run. Sent with a pad, tapped words don't
## count: only typed ones do.
func count_words(sql: String, on_terminal: Node = null) -> void:
	var game := get_node_or_null("/root/Game")
	var net := get_node_or_null("/root/Net")
	if game == null or net == null or net.get("profile") == null or not KeywordHelp.counting:
		return
	if on_terminal and on_terminal.get("practice"):
		return  # the garage lab's practice doesn't count
	var key := KeywordHelp.same_query(sql)
	var how: Dictionary = _sent.get(key, {})
	_sent.erase(key)
	if game.counted_queries.has(key):
		return
	game.counted_queries.append(key)
	var words := KeywordHelp.used_in(sql)
	if how.get("pad", false):
		var tapped: Array = how.get("tapped", [])
		words = words.filter(func(w): return not tapped.has(w))
	var case_id := ""
	if on_terminal and on_terminal.has_method("hint_case"):
		case_id = on_terminal.hint_case()
	for w in net.profile.use_words(words):
		if not game.words_waiting.has(w):
			game.words_waiting[w] = case_id
	_words_check.call_deferred()


## Never in the middle of something (Augustine, 2026-11-05): a word that's been
## used enough comes off once the puzzle it was used on is solved and no puzzle
## under pressure is open. On a keyboard on Easy, its button goes, with the
## notice; on a pad the buttons stay. Both achievements are checked here too.
func _words_check() -> void:
	var game := get_node_or_null("/root/Game")
	var net := get_node_or_null("/root/Net")
	if game == null or net == null or net.get("profile") == null:
		return
	for c in game.notebook_cases:
		if c.get("open", false) and not c.get("solved", false) and not c.get("assemble", true):
			return  # a puzzle under pressure
	var profile: Profile = net.profile
	var ready := []
	for w in profile.word_uses:
		if profile.uses_of(w) < KeywordHelp.USES:
			continue
		var on := str(game.words_waiting.get(w, ""))
		if on != "" and game.case_info(on).get("open", false) and not game.case_info(on).get("solved", false):
			continue
		game.words_waiting.erase(w)
		ready.append(w)
	if ready.is_empty():
		return
	var lines := []
	KeywordHelp.load_settings()
	if not InputGlyphs.pad and KeywordHelp.mode == "easy":
		var off := KeywordHelp.ORDER.filter(func(w): return ready.has(w) and not profile.words_off.has(w))
		if not off.is_empty():
			profile.words_off.append_array(off)
			profile.save()
			lines.append(KeywordHelp.off_notice(off))
			if book:
				book.refresh(true)
	var earn := ["achievement:no_training_wheels"]
	if KeywordHelp.easy_sql_tokens().all(func(w): return profile.uses_of(w) >= KeywordHelp.USES):
		earn.append("achievement:look_no_buttons")
	for id in earn:
		var fresh := not profile.earned.has(id)
		var got: Array = net.earn(id)
		if fresh:
			lines.append(Achievements.NOTICE % Achievements.name_of(id))
		for k in got:
			var slot: String = k.get_slice("/", 0)
			var item: String = k.get_slice("/", 1)
			if Cosmetics.drawable(slot, item):
				lines.append("Unlocked: %s" % Cosmetics.info(slot, item).name)
	var hud = _hud()
	if hud and not lines.is_empty():
		hud.notice("\n".join(lines), 4.0 + 1.5 * lines.size())
