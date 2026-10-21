class_name ScriptEditorUI
extends CanvasLayer
## The script runner: a full-screen editor in the spirit of nano or Notepad.
## Write a script, Ctrl+S saves it, Ctrl+R runs the saved script, Ctrl+T stops
## it, and its log shows underneath. A key bar along the bottom lists the keys.
##
## It doesn't care what opened it (a terminal's .script command now, the
## portable deck later) or which language the runtime speaks: callers hand it a
## ScriptRuntime and a context, and it only talks to that runtime.
##
## editor.open(ScriptRuntime.for_language("javascript"), {
##     "title": "COLD STORE 2",            # shown in the title bar
##     "library": BuildingLibrary.new(api, db),
##     "seed": game.run_seed,              # Math.random follows the run
##     "code": "...",                       # the saved script it starts with
##     "player": player,                    # locked while the editor is open
## })
##
## While a script runs the editor ticks it every frame, open or closed, so a
## watchdog loop keeps going after the player steps away. Pass "ticks": false
## when something else (the co-op host) ticks the runtime itself.

signal closed
## The player saved: whoever opened the editor keeps `code` (the terminal for
## now, the deck later).
signal saved(code: String)

const KEYWORDS := ["let", "const", "function", "return", "if", "else", "while", "for", "of", "break",
	"continue", "async", "await", "true", "false", "null", "undefined", "typeof"]
const BUILT_INS := ["api", "db", "sleep", "assert", "console", "Math", "JSON", "Object", "Array"]
const LOG_LIMIT := 400
const COLORS := {"log": "#bfffc8", "warn": "#ffd27f", "error": "#ff6655", "system": "#5f8f6a"}
## The key bar, as nano writes it: ^S is Ctrl+S. Cut, copy and paste keep their
## usual keys, so nano's ^X (exit) and ^K (cut) aren't used.
const KEYS := [[KEY_S, "^S", "Save"], [KEY_R, "^R", "Run"], [KEY_T, "^T", "Stop"], [KEY_Q, "^Q", "Close"]]
const INK := Color(0.02, 0.05, 0.03)

var runtime: ScriptRuntime
var context := {}
var player: Node
## What Run runs: the code as it was last saved.
var saved_code := ""
var _code: CodeEdit
var _log: RichTextLabel
var _title: Label
var _modified: Label
var _status: Label
var _keys := {}
var _log_lines: Array[String] = []
var _error_line := -1
## A one-off message on the status line ("Saved, 4 lines."), until the next change.
var _message := ""


func _ready() -> void:
	layer = 21
	visible = false
	var back := ColorRect.new()
	back.color = INK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16
	vbox.offset_right = -16
	vbox.offset_top = 12
	vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Title bar in reverse video, as nano draws it.
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _flat(ThemeUtil.GREEN, 6))
	vbox.add_child(top)
	var top_row := HBoxContainer.new()
	top.add_child(top_row)
	_title = _text("", 18, INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_title)
	_modified = _text("", 18, INK)
	top_row.add_child(_modified)

	_code = CodeEdit.new()
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.size_flags_stretch_ratio = 2.0
	_code.gutters_draw_line_numbers = true
	_code.indent_automatic = true
	_code.indent_size = 2
	_code.indent_use_spaces = true
	_code.auto_brace_completion_enabled = true
	_code.placeholder_text = "// Write JavaScript here. Ctrl+S saves it, Ctrl+R runs it.\nconsole.log(\"hello\");"
	_code.add_theme_font_override("font", ThemeUtil.mono())
	_code.add_theme_font_size_override("font_size", 18)
	_code.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_code.add_theme_color_override("background_color", Color(0.0, 0.1, 0.04))
	_code.add_theme_color_override("line_number_color", ThemeUtil.DIM)
	_code.syntax_highlighter = _highlighter()
	_code.text_changed.connect(_on_text_changed)
	vbox.add_child(_code)

	vbox.add_child(_text("LOG", 14, ThemeUtil.DIM))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_override("normal_font", ThemeUtil.mono())
	_log.add_theme_font_size_override("normal_font_size", 16)
	_log.add_theme_color_override("default_color", ThemeUtil.GREEN)
	_log.add_theme_stylebox_override("normal", _flat(Color(0.0, 0.07, 0.03), 8))
	vbox.add_child(_log)

	# nano's message line, then its key bar.
	_status = _text("", 16, ThemeUtil.DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 28)
	vbox.add_child(bar)
	for k in KEYS:
		_keys[k[0]] = _key_button(k[1], k[2], _action(k[0]))
		bar.add_child(_keys[k[0]])
	_show_state()


## The key bar's entries are buttons too, for the mouse: the key in reverse
## video, then what it does.
func _key_button(key: String, what: String, action: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	b.add_child(row)
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_stylebox_override("panel", _flat(ThemeUtil.GREEN, 3))
	cap.add_child(_text(key, 16, INK))
	row.add_child(cap)
	row.add_child(_text(what, 16, ThemeUtil.GREEN))
	b.custom_minimum_size = Vector2(32 + 11 * (key.length() + what.length()), 26)
	b.pressed.connect(action)
	return b


func _action(key: Key) -> Callable:
	match key:
		KEY_S: return save
		KEY_R: return run
		KEY_T: return stop
	return close


func _text(s: String, size: int, color: Color) -> Label:
	var l := ThemeUtil.label(s, size, color)
	l.add_theme_font_override("font", ThemeUtil.mono())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _flat(color: Color, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_content_margin_all(margin)
	return s


## Shows the editor for `rt`. Opening it again on the same runtime keeps its log,
## any unsaved edits and whatever the script is doing.
func open(rt: ScriptRuntime, ctx := {}) -> void:
	if rt != runtime:
		_forget_runtime()
		runtime = rt
		runtime.started.connect(_on_started)
		runtime.printed.connect(_on_printed)
		runtime.finished.connect(_on_finished)
		_log_lines.clear()
		_log.clear()
		# Opened mid-run (a teammate walking up in co-op): show what's been logged so far.
		if runtime.is_running():
			_add_line("--- running ---", "system")
		if runtime.has_method("log_history"):
			for line in runtime.log_history():
				_add_line(_esc(line[0]), line[1])
		saved_code = ctx.get("code", "")
		_code.text = saved_code
		_code.clear_undo_history()
		_mark_error(-1)
		_message = ""
	context = ctx
	_title.text = " HALCYON SCRIPT RUNNER  //  %s  //  %s" % [ctx.get("title", "DECK"), runtime.language().to_upper()]
	player = ctx.get("player")
	if player and "input_locked" in player:
		player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_show_state()
	_code.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_code.release_focus()
	if player and is_instance_valid(player) and "input_locked" in player:
		player.input_locked = false
	if player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func save() -> void:
	saved_code = _code.text
	var lines := saved_code.split("\n").size() if saved_code != "" else 0
	_message = "Saved, %d line%s." % [lines, "" if lines == 1 else "s"]
	saved.emit(saved_code)
	_show_state()


func is_modified() -> bool:
	return _code.text != saved_code


## Runs the saved script, saving first if there are edits, so what runs is
## always what's saved. A mistake found before running goes in the log with its
## line, and the line is marked in the editor.
func run() -> void:
	if runtime == null or runtime.is_running():
		return
	if is_modified():
		save()
	_message = ""
	_mark_error(-1)
	var res := runtime.compile(saved_code)
	if not res.ok:
		_add_line(_esc(ScriptRuntime.format_error(saved_code, res.error)), "error")
		_mark_error(res.error.line)
		_show_state()
		return
	runtime.start(context.get("library", BuildingLibrary.new()), context.get("seed", 0))


## Always on: with nothing running it just says so.
func stop() -> void:
	if runtime and runtime.is_running():
		runtime.stop()
	else:
		_message = "Nothing is running."
		_show_state()


func _process(delta: float) -> void:
	if runtime == null or not runtime.is_running():
		return
	if context.get("ticks", true):
		runtime.tick(delta)
	if visible:
		_show_state()


func code() -> String:
	return _code.text


## What the log says, as plain text (for tests and the notebook).
func log_text() -> String:
	var tags := RegEx.create_from_string("\\[/?color[^\\]]*\\]")
	return "\n".join(PackedStringArray(_log_lines.map(func(l): return tags.sub(l, "", true).replace("[lb]", "["))))


func _on_started() -> void:
	_add_line("--- running ---", "system")
	_show_state()


func _on_printed(text: String, kind: String) -> void:
	_add_line(_esc(text), kind)


func _on_finished(ok: bool, error: Dictionary) -> void:
	var secs := "%.1f s" % runtime.clock() if runtime.has_method("clock") else ""
	if ok:
		_add_line("--- finished after %s ---" % secs, "system")
	elif error.is_empty():
		_add_line("--- stopped after %s ---" % secs, "system")
	else:
		_add_line(_esc(ScriptRuntime.format_error(runtime.source, error)), "error")
		# The mark only lines up while the editor still shows what ran.
		if not is_modified():
			_mark_error(error.line)
	_show_state()


func _add_line(text: String, kind: String) -> void:
	_log_lines.append("[color=%s]%s[/color]" % [COLORS.get(kind, COLORS.log), text])
	if _log_lines.size() > LOG_LIMIT:
		_log_lines = _log_lines.slice(_log_lines.size() - LOG_LIMIT)
		_log.clear()
		for l in _log_lines:
			_log.append_text(l + "\n")
	else:
		_log.append_text(_log_lines.back() + "\n")


func _show_state() -> void:
	if _status == null:
		return
	_modified.text = "Modified " if runtime != null and is_modified() else ""
	var running := runtime != null and runtime.is_running()
	_keys[KEY_R].modulate.a = 0.4 if runtime == null or running else 1.0
	_keys[KEY_T].modulate.a = 1.0 if running else 0.7
	if runtime == null:
		_status.text = ""
		return
	if _message != "":
		_status.text = "[ %s ]" % _message
		return
	var words := {
		ScriptRuntime.State.IDLE: "ready",
		ScriptRuntime.State.READY: "ready",
		ScriptRuntime.State.RUNNING: "running",
		ScriptRuntime.State.WAITING: "waiting",
		ScriptRuntime.State.DONE: "finished",
		ScriptRuntime.State.FAILED: "stopped on an error",
		ScriptRuntime.State.STOPPED: "stopped",
	}
	_status.text = words.get(runtime.state, "")
	if running and runtime.has_method("clock"):
		_status.text += "  %.1f s" % runtime.clock()


## Marks the line an error points at (1-based), or clears the mark with -1.
func _mark_error(line: int) -> void:
	if _error_line >= 0 and _error_line < _code.get_line_count():
		_code.set_line_background_color(_error_line, Color(0, 0, 0, 0))
	_error_line = line - 1 if line > 0 else -1
	if _error_line >= 0 and _error_line < _code.get_line_count():
		_code.set_line_background_color(_error_line, Color(0.5, 0.08, 0.06, 0.6))
		_code.set_caret_line(_error_line)


func error_line() -> int:
	return _error_line + 1


func _on_text_changed() -> void:
	_mark_error(-1)
	_message = ""
	_show_state()


## The keys work wherever focus is, and before the code box sees them. Esc
## (also the pause key) closes, as Ctrl+Q does; Ctrl+Enter runs, as Ctrl+R does.
func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
		return
	if not event.is_command_or_control_pressed() or event.shift_pressed or event.alt_pressed:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:  # Ctrl+Enter, as other editors run
		get_viewport().set_input_as_handled()
		run()
		return
	for k in KEYS:
		if event.keycode == k[0]:
			get_viewport().set_input_as_handled()
			_action(k[0]).call()
			return


func _forget_runtime() -> void:
	if runtime == null:
		return
	for pair in [[runtime.started, _on_started], [runtime.printed, _on_printed], [runtime.finished, _on_finished]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


func _highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = Color(0.6, 0.85, 1.0)
	h.symbol_color = Color(0.7, 0.9, 0.75)
	h.function_color = Color(0.85, 1.0, 0.85)
	h.member_variable_color = Color(0.85, 1.0, 0.85)
	for k in KEYWORDS:
		h.add_keyword_color(k, Color(1.0, 0.8, 0.35))
	for k in BUILT_INS:
		h.add_keyword_color(k, Color(0.5, 0.85, 1.0))
	h.add_color_region("\"", "\"", Color(1.0, 0.65, 0.5), true)
	h.add_color_region("'", "'", Color(1.0, 0.65, 0.5), true)
	h.add_color_region("`", "`", Color(1.0, 0.65, 0.5))
	h.add_color_region("//", "", Color(0.45, 0.6, 0.5), true)
	h.add_color_region("/*", "*/", Color(0.45, 0.6, 0.5))
	return h
