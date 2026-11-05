extends RefCounted
## The terminal and the notebook on a controller, no mouse or keys: real joypad
## events through Input (PadReader), on the ground floor's front-desk terminal.

var t: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	PadInput.bind()
	InputGlyphs.watch(t.root)
	await t.process_frame
	t.call("_game").call("new_run", 6)
	var level = load("res://scenes/level_0.tscn").instantiate()
	t.root.add_child(level)
	t.call("_lower_chapters_read", [level])
	for i in 30:
		await t.physics_frame
	var p = level.player
	level._release_camera(p)
	p.seated = false
	await test_terminal(level, p)
	await test_notebook(level, p)
	_release_all()
	InputGlyphs.pad = false
	level.queue_free()
	await t.process_frame


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func button(which: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = which
	e.pressed = pressed
	e.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


func axis(which: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = which
	e.axis_value = value
	Input.parse_input_event(e)


func tap(which: JoyButton) -> void:
	button(which, true)
	await frames(2)
	button(which, false)
	await frames(2)


func frames(n: int) -> void:
	for i in n:
		await t.process_frame


func _release_all() -> void:
	for a in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		axis(a, 0.0)


func test_terminal(level: Node, p: Node) -> void:
	print("Controller: the terminal")
	var ui: TerminalUI = level.terminal_ui
	ui.open(level.desk_terminal, p)
	await frames(2)
	await tap(JOY_BUTTON_DPAD_LEFT)  # any press: the pad is in use now
	check(InputGlyphs.pad and ui._foot.text.begins_with("Y: run") and ui._foot.text.contains("X: pick a line") and ui._foot.text.contains("B: step away"), "with a pad in hand, the foot line names its buttons (%s)" % ui._foot.text)
	check(ui._input.has_focus(), "the d-pad doesn't take the typing line's focus away")
	ui._input.text = "SELECT * FROM visitors;"
	await tap(JOY_BUTTON_Y)
	check(t.call("screen_text", ui).contains("visitors") and ui._input.text == "", "Y runs what's typed")
	ui._input.text = "SELECT name FROM visitors"
	await tap(JOY_BUTTON_Y)
	check(ui._input.text.contains("SELECT name FROM visitors"), "a statement without its ; isn't run: Y carries on to the next line, as Enter does")
	ui._input.text = ""
	await tap(JOY_BUTTON_DPAD_UP)
	check(ui._input.text == "SELECT * FROM visitors;", "d-pad up brings back the last query")
	await tap(JOY_BUTTON_DPAD_DOWN)
	check(ui._input.text == "", "and down goes back to a blank line")
	check(ui.visible and not level.inventory_screen.is_open(), "d-pad left doesn't open the inventory or leave the screen")
	# Scrolling with the right stick.
	for i in 6:
		ui.run("SELECT * FROM visitors;")
	await frames(2)
	var bar := ui._output.get_v_scroll_bar()
	bar.value = bar.max_value
	await frames(1)
	var bottom := bar.value
	axis(JOY_AXIS_RIGHT_Y, -1.0)
	await frames(20)
	axis(JOY_AXIS_RIGHT_Y, 0.0)
	await frames(1)
	check(bar.value < bottom - 50.0, "the right stick scrolls back up the screen (%d to %d)" % [bottom, bar.value])
	# Picking a line for the notebook.
	var lines: Array = ui.noteable_lines()
	await tap(JOY_BUTTON_X)
	check(ui.picking == lines.size() - 1 and ui._hover_band.visible, "X picks the newest line to add, lit up")
	check(ui._foot.text.begins_with("D-pad up/down: choose a line"), "and the foot line says how to choose (%s)" % ui._foot.text)
	await tap(JOY_BUTTON_DPAD_UP)
	check(ui.picking == lines.size() - 2 and ui._hover_band.visible, "d-pad up picks the line above, still lit as the screen scrolls to it")
	var notes: int = t.call("_game").notebook_written.size()
	await tap(JOY_BUTTON_A)
	check(ui._note_label.visible and ui.picking == -1, "A takes it: the note asks for a name")
	await tap(JOY_BUTTON_Y)
	check(not ui._note_label.visible and t.call("_game").notebook_written.size() == notes + 1, "Y writes it into the notebook")
	await tap(JOY_BUTTON_X)
	await tap(JOY_BUTTON_B)
	check(ui.picking == -1 and ui.visible and not ui._hover_band.visible, "B stops picking without leaving the screen")
	await tap(JOY_BUTTON_B)
	check(not ui.visible, "and B again steps away from the terminal")
	await frames(10)


func test_notebook(level: Node, p: Node) -> void:
	print("Controller: the notebook")
	var nb: Notebook = level.notebook
	var pages: NotebookPages = nb.pages
	await tap(JOY_BUTTON_BACK)
	for i in 30:
		if nb.is_open():
			break
		await t.process_frame
	check(nb.is_open(), "View opens the notebook")
	var close_hint: Label = pages.find_child("CloseHint", true, false)
	check(close_hint != null and close_hint.text == "View to close", "its corner says View closes it (%s)" % (close_hint.text if close_hint else "none"))
	var light: bool = p.flashlight.visible
	var at := pages.current_page()
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(pages.current_page() == (at + 1) % NotebookPages.TAB_NAMES.size(), "RB turns to the next tab")
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	check(pages.current_page() == at and p.flashlight.visible == light, "LB back to the one before, and the flashlight stays as it was")
	await frames(5)
	check(p.seat == null and p.state == p.Move.WALK, "RB doesn't sit you down while you read")
	# A button on the pages, picked and pressed with the d-pad and A.
	pages.show_page(NotebookPages.Page.CASES)
	await frames(2)
	var all := pages.pad_buttons()
	check(not all.is_empty() and all.any(func(b): return b.name == "WriteMine"), "the case page has buttons a pad can pick, \"+ write a note\" among them")
	await tap(JOY_BUTTON_DPAD_RIGHT)
	check(pages.picked_button() == all[0] and all[0].get_node_or_null("PadRing") != null, "d-pad right picks the first, outlined")
	if all.size() > 1:
		await tap(JOY_BUTTON_DPAD_RIGHT)
		check(pages.picked_button() == all[1], "and right again the next")
	await tap(JOY_BUTTON_DPAD_LEFT)
	check(pages.picked_button() == all[0] and not level.inventory_screen.is_open(), "left goes back (and doesn't open the inventory)")
	while pages.picked_button() and pages.picked_button().name != "WriteMine":
		await tap(JOY_BUTTON_DPAD_RIGHT)
	await tap(JOY_BUTTON_A)
	check(nb.is_writing(), "A presses it: the pen comes out to write a note")
	nb.writer.text = "PIN 4471"
	await tap(JOY_BUTTON_Y)
	check(not nb.is_writing() and t.call("_game").notebook_written.any(func(w): return w.text == "PIN 4471"), "Y writes the note in")
	await tap(JOY_BUTTON_Y)
	check(nb.is_writing(), "Y on the pages starts a note straight away")
	await tap(JOY_BUTTON_B)
	check(not nb.is_writing() and nb.is_open(), "B puts the pen down, the notebook still up")
	# The right stick turns the page when there's more than one spread.
	var spreads: int = pages._spreads.size()
	if spreads > 1:
		var was: int = pages._spread
		axis(JOY_AXIS_RIGHT_X, 1.0)
		await frames(40)
		axis(JOY_AXIS_RIGHT_X, 0.0)
		await frames(40)
		check(pages._spread == (was + 1) % spreads, "the right stick pushed right turns one page, not one a frame")
	await tap(JOY_BUTTON_B)
	await frames(5)
	check(not nb.is_open(), "B puts the notebook away")
