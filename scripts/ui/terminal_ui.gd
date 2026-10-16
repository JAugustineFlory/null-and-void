class_name TerminalUI
extends CanvasLayer
## The SQL terminal screen. Players type real SQL; results come from the real database.

signal closed

const MAX_COL_WIDTH := 48
const MAX_ROWS_SHOWN := 60

var terminal: Node  # the Terminal in the world that opened this
var player: Player
var _output: RichTextLabel
var _input: TextEdit
var _title: Label
var _history: Array[String] = []
var _history_i := -1


func _ready() -> void:
	layer = 20
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120
	panel.offset_right = -120
	panel.offset_top = 60
	panel.offset_bottom = -60
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
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_override("normal_font", ThemeUtil.mono())
	_output.add_theme_font_override("bold_font", ThemeUtil.mono())
	_output.add_theme_font_size_override("normal_font_size", 17)
	_output.add_theme_font_size_override("bold_font_size", 17)
	_output.add_theme_color_override("default_color", ThemeUtil.GREEN)
	vbox.add_child(_output)

	_input = TextEdit.new()
	_input.custom_minimum_size = Vector2(0, 110)
	_input.placeholder_text = "Type a query, e.g.  SELECT * FROM table_name;   (.help for commands)"
	_input.add_theme_font_override("font", ThemeUtil.mono())
	_input.add_theme_font_size_override("font_size", 18)
	_input.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_input.add_theme_color_override("background_color", Color(0.0, 0.1, 0.04))
	_input.syntax_highlighter = _sql_highlighter()
	_input.gui_input.connect(_on_input_key)
	vbox.add_child(_input)

	var foot := ThemeUtil.label("Enter: run    Shift+Enter: new line    Up/Down: previous queries    Esc: step away", 15, ThemeUtil.DIM)
	vbox.add_child(foot)


func open(from_terminal: Node, by_player: Player) -> void:
	var switched := terminal != from_terminal
	terminal = from_terminal
	player = by_player
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title.text = "HALCYON DATA SYSTEMS  //  %s" % terminal.terminal_name
	visible = true
	# One screen is shared by every terminal, so a different terminal starts fresh.
	if terminal.consume_fresh_boot() or switched or _output.get_parsed_text().strip_edges() == "":
		_output.clear()
		for line in terminal.boot_text():
			print_line(line)
	_input.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_input.release_focus()
	if player:
		player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func print_line(bbcode: String) -> void:
	_output.append_text(bbcode + "\n")


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
		_submit()
	elif event.keycode == KEY_UP and _input.get_caret_line() == 0 and not _history.is_empty():
		_input.accept_event()
		_history_i = clamp(_history_i - 1, 0, _history.size() - 1)
		_input.text = _history[_history_i]
	elif event.keycode == KEY_DOWN and _input.get_caret_line() == _input.get_line_count() - 1 and not _history.is_empty():
		_input.accept_event()
		_history_i = clamp(_history_i + 1, 0, _history.size())
		_input.text = _history[_history_i] if _history_i < _history.size() else ""


func _submit() -> void:
	var sql := _input.text.strip_edges()
	_input.text = ""
	if sql == "":
		return
	_history.append(sql)
	_history_i = _history.size()
	print_line("[color=#ffffff]> %s[/color]" % _esc(sql).replace("\n", "\n  "))
	run(sql)


## Run a command or query as if typed. Public so tests and scripted events can use it.
func run(sql: String) -> void:
	if sql.begins_with("."):
		_command(sql)
		return
	if terminal.is_locked():
		print_line("[color=#ff6655]%s[/color]" % terminal.locked_message)
		return
	if FacilityAPI.is_request(sql):
		_http(sql)
		return
	var db: FacilityDB = terminal.db
	var result := db.execute(sql)
	if not result.ok:
		print_line("[color=#ff6655]ERROR: %s[/color]" % _esc(result.error))
		print_line("[color=#e0b050]WARDEN: %s[/color]" % FacilityDB.explain_error(result.error))
		return
	get_node("/root/Game").log_query(sql)
	if result.rows.is_empty():
		if result.changes > 0:
			print_line("OK. %d row(s) changed." % result.changes)
		else:
			print_line("(0 rows)")
	else:
		print_line(_format_table(result.columns, result.rows))
	terminal.on_query(sql, result, self)


func _http(line: String) -> void:
	if terminal.api == null:
		print_line("[color=#ff6655]No network API on this terminal. It only speaks SQL.[/color]")
		return
	var res: Dictionary = terminal.api.request(line)
	get_node("/root/Game").log_query(line)
	var color := "#7dff8c" if res.status < 400 else "#ff6655"
	print_line("[color=%s]HTTP/1.0 %d %s[/color]" % [color, res.status, FacilityAPI.status_text(res.status)])
	print_line(_esc(res.text))
	terminal.on_request(line, res, self)


func _command(cmd: String) -> void:
	var parts := cmd.split(" ", false)
	var db: FacilityDB = terminal.db
	match parts[0].to_lower():
		".help":
			print_line("Commands:")
			print_line("  .tables          list every table")
			print_line("  .schema NAME     show the columns of a table")
			print_line("  .hint            ask WARDEN for a hint")
			print_line("  .clear           clear the screen")
			print_line("  .reset           restore this terminal's data from backup")
			if terminal.api != null:
				print_line("  GET /path        send a web request, e.g. GET /cameras")
			print_line("Anything else is run as SQL. End queries with ; (optional).")
		".tables":
			if terminal.is_locked():
				print_line("[color=#ff6655]%s[/color]" % terminal.locked_message)
				return
			print_line("  ".join(db.table_names()))
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
				print_line("%s(%s)" % [t, ", ".join(desc)])
		".hint":
			print_line("[color=#e0b050]WARDEN: %s[/color]" % terminal.next_hint())
		".clear":
			_output.clear()
		".reset":
			db.reset()
			print_line("Backup tape restored. Data is back to how it started.")
		_:
			print_line("[color=#ff6655]Unknown command %s. Try .help[/color]" % _esc(parts[0]))


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
	lines.append("[b]%s[/b]" % _esc(" | ".join(header)))
	lines.append(" + ".join(rule).replace(" + ", "-+-"))
	for row in shown:
		var cells := PackedStringArray()
		for i in columns.size():
			cells.append(_pad(_cell(row[columns[i]]), widths[i]))
		lines.append(_esc(" | ".join(cells)))
	var footer := "(%d row%s)" % [rows.size(), "" if rows.size() == 1 else "s"]
	if rows.size() > MAX_ROWS_SHOWN:
		footer += "  showing first %d. Try LIMIT or WHERE." % MAX_ROWS_SHOWN
	lines.append(footer)
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
	var kw := Color(1.0, 0.8, 0.35)
	for word in ["SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "ORDER", "BY", "ASC", "DESC", "LIMIT", "LIKE", "IN", "IS", "NULL", "AS", "DISTINCT", "COUNT", "GROUP", "HAVING", "JOIN", "ON", "UPDATE", "SET", "INSERT", "INTO", "VALUES", "DELETE", "BEGIN", "COMMIT", "ROLLBACK", "GET", "POST", "PATCH"]:
		h.add_keyword_color(word, kw)
		h.add_keyword_color(word.to_lower(), kw)
	h.add_color_region("'", "'", Color(0.6, 1.0, 1.0))
	return h
