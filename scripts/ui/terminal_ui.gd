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
## SYSOP, when a case page's missing piece (????) is typed in as it is.
const PIECE_TYPED := "???? is a piece you haven't found yet. Your case page says where to look."
const KEYWORD := "#ffcc59"
const KEYWORDS := ["SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "ORDER", "BY", "ASC", "DESC", "LIMIT", "LIKE", "IN", "IS", "NULL", "AS", "DISTINCT", "COUNT", "GROUP", "HAVING", "JOIN", "ON", "UPDATE", "SET", "INSERT", "INTO", "VALUES", "DELETE", "BEGIN", "COMMIT", "ROLLBACK", "GET", "POST", "PATCH"]

var terminal: Node  # the Terminal in the world that opened this
var player: Player
var _output: RichTextLabel
var _input: TextEdit
var _title: Label
var _history: Array[String] = []
var _history_i := -1
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
## Who else is at this terminal, and what they're typing.
var _others: Label
var _foot: Label
## On a terminal's in-world screen (open_on_screen), the window fills the glass:
## no dimmed backdrop, no margin. `_home` is where it goes back to afterwards.
var _dim: ColorRect
var _panel: PanelContainer
var _screen: Node
var _home: Node
## The script runner (.script), made the first time it's needed, and the
## terminal whose script it's showing.
var _editor: ScriptEditorUI
var _script_terminal: Node


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
	_output.mouse_exited.connect(func(): if not _chip_hovered(): _hover_line(-1))
	_output.gui_input.connect(_on_output_mouse)
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
	_add_chip.pressed.connect(func(): _start_note(_hover_index))
	_output.add_child(_add_chip)
	_output.get_v_scroll_bar().value_changed.connect(func(_v): _hover_line(-1))

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

	_input = TextEdit.new()
	_input.custom_minimum_size = Vector2(0, 110)
	_input.placeholder_text = "Type a query, e.g.  SELECT * FROM table_name;   (.help for commands)"
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

	_foot = ThemeUtil.label("Enter: run (a query ends with ;)    Up/Down: previous queries    point at a line: add it to your notebook    Esc: step away", 15, ThemeUtil.DIM)
	vbox.add_child(_foot)


func open(from_terminal: Node, by_player: Player) -> void:
	terminal = from_terminal
	player = by_player
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title.text = "HALCYON DATA SYSTEMS  //  %s" % terminal.terminal_name
	visible = true
	# Each terminal keeps its own screen; in co-op it shows everyone's queries.
	terminal.ensure_booted()
	_clear_output()
	for i in terminal.transcript.size():
		_render(terminal.transcript[i], terminal.transcript_kinds[i] if i < terminal.transcript_kinds.size() else "")
	if not terminal.screen_changed.is_connected(_show_others):
		terminal.screen_changed.connect(_show_others)
	var mirror := _mirror()
	if mirror:
		mirror.seat(terminal, true)
	_show_others()
	_input.grab_focus()


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
	_cancel_note()
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
	var mirror := _mirror()
	if mirror and visible:
		mirror.typed(terminal, _input.text)


## Name the other players at this terminal and show what they're typing.
func _show_others() -> void:
	if terminal == null or not visible:
		return
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
	var text := _plain(bbcode).strip_edges()
	if text == "" or kind == "none":
		_output.append_text(bbcode + "\n")
		return
	if kind == "":
		kind = "error" if text.begins_with("ERROR") else ("hint" if text.begins_with("[SYSOP]") else "info")
	var from := _output.get_paragraph_count() - 1
	_output.append_text(bbcode + "\n")
	if kind == "result" and bbcode.count("\n") >= 3:
		# A table: its header line copies the whole result, and each row (under
		# the rule, above the row count) is a line of its own, copied with the header.
		var rows := bbcode.split("\n")
		_noteable.append({"kind": kind, "text": text, "from": from, "to": from + 1})
		var head := _plain(rows[0]).strip_edges()
		for i in range(2, rows.size() - 1):
			_noteable.append({"kind": "row", "text": head + "\n" + _plain(rows[i]).strip_edges(), "from": from + i, "to": from + i + 1})
	else:
		_noteable.append({"kind": kind, "text": text, "from": from, "to": _output.get_paragraph_count() - 1})
	_hover_line(-1)  # the screen may scroll under the pointer


## What on screen right now can be written into the notebook, oldest first.
func noteable_lines() -> Array[Dictionary]:
	return _noteable.duplicate(true)


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
## with no name to give it, and you step back from the screen while the notebook
## comes up to show it written in (Notebook). False if it answers nothing.
func answer(index: int) -> bool:
	if index < 0 or index >= _noteable.size() or not get_node("/root/Game").add_answer(_noteable[index].text, "terminal"):
		return false
	_render("[color=#7fa88a]Written in your notebook.[/color]", "none")
	if visible:
		close()
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


func _on_output_mouse(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_line(_line_at(event.position.y))


## Which noteable line is at this height in the output, or -1.
func _line_at(y: float) -> int:
	_output.get_content_height()  # lay out first: that can move the scroll
	var at := y + _output.get_v_scroll_bar().value
	for i in range(_noteable.size() - 1, -1, -1):
		var top := _para_top(_noteable[i].from)
		if at >= top:
			return i if at < _para_top(_noteable[i].to) else -1
	return -1


## Light up line `index` (-1 for none) and put the add chip at its right end.
func _hover_line(index: int) -> void:
	_hover_index = index
	var on := index >= 0 and index < _noteable.size()
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
	_add_chip.reset_size()
	_add_chip.position = Vector2(_output.size.x - _add_chip.size.x - 18, top + (bottom - top - _add_chip.size.y) / 2.0)


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
	elif (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and not event.shift_pressed:
		_input.accept_event()
		if is_complete(_input.text):
			_submit()
		else:
			_continue_statement()
	elif event.keycode == KEY_UP and _input.get_caret_line() == 0 and not _history.is_empty():
		_input.accept_event()
		_history_i = clamp(_history_i - 1, 0, _history.size() - 1)
		_input.text = _history[_history_i]
		_typed()
	elif event.keycode == KEY_DOWN and _input.get_caret_line() == _input.get_line_count() - 1 and not _history.is_empty():
		_input.accept_event()
		_history_i = clamp(_history_i + 1, 0, _history.size())
		_input.text = _history[_history_i] if _history_i < _history.size() else ""
		_typed()


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
	_history.append(sql)
	_history_i = _history.size()
	var mirror := _mirror()
	if mirror:
		mirror.submitted(terminal)
	if sql.begins_with(".") or terminal.is_locked():
		print_line(_echo(sql, ""), "echo")
	run(sql)


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
	var result: Dictionary = terminal.db.execute(sql)
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
	var out: Array = [[_echo(sql, who), "echo"]]
	if not result.ok:
		out.append(["[color=#ff6655]ERROR: %s[/color]" % _esc(result.error), "error"])
		out.append([sysop(_explain(on_terminal, sql, result.error)), "hint"])
	else:
		if mine:
			get_node("/root/Game").log_query(sql)
			_note_tables(sql, on_terminal.db)
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
	on_terminal.print_line(_echo(line, who), "echo")
	if res.is_empty():
		on_terminal.print_line("[color=#ff6655]No network API on this terminal. It only speaks SQL.[/color]")
		return
	if mine:
		get_node("/root/Game").log_query(line)
	var color := "#7dff8c" if res.status < 400 else "#ff6655"
	on_terminal.print_line("[color=%s]HTTP/1.0 %d %s[/color]" % [color, res.status, FacilityAPI.status_text(res.status)])
	on_terminal.print_line(_esc(res.text), "result")
	if LevelSync.of(on_terminal) == null:
		on_terminal.on_request(line, res, self)


func _command(cmd: String) -> void:
	var parts := cmd.split(" ", false)
	var db: FacilityDB = terminal.db
	match parts[0].to_lower():
		".help":
			print_line("Commands:")
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
		".tables":
			if terminal.is_locked():
				print_line("[color=#ff6655]%s[/color]" % terminal.locked_message)
				return
			print_line("  ".join(db.table_names()))
			for t in db.table_names():
				_discover(t, db)
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
		".hint":
			var case_id: String = terminal.hint_case()
			print_line(sysop(_noted_hint(case_id, terminal.next_hint())), "hint")
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
		"library": BuildingLibrary.new(on.api, on.db),
		"seed": game.run_seed if game else 0,
		"code": on.get_meta("script_code", ""),
		"player": who,
		"skin": on.skin_color,
	})
	return _editor


## Every hint asked for also goes on its puzzle's case page. Returns the hint.
func _noted_hint(case_id: String, hint: String) -> String:
	if case_id != "":
		get_node("/root/Game").add_clue(case_id, _plain(hint), "SYSOP hint")
		get_node("/root/Game").note_hint(case_id, hint)
	return hint


## Tables a query read from go on the notebook's Tables page.
func _note_tables(sql: String, db: FacilityDB) -> void:
	var known: Array = db.table_names()
	for m in RegEx.create_from_string("(?i)\\b(?:FROM|JOIN)\\s+([A-Za-z_][A-Za-z0-9_]*)").search_all(sql):
		var t := m.get_string(1).to_lower()
		for name in known:
			if name.to_lower() == t:
				_discover(name, db)


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


func _sql_highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = Color(0.7, 0.85, 1.0)
	h.symbol_color = Color(0.8, 0.9, 0.8)
	h.function_color = Color(0.85, 1.0, 0.85)
	h.member_variable_color = Color(0.85, 1.0, 0.85)
	var kw := Color(KEYWORD)
	for word in KEYWORDS:
		h.add_keyword_color(word, kw)
		h.add_keyword_color(word.to_lower(), kw)
	h.add_color_region("'", "'", Color(0.6, 1.0, 1.0))
	return h
