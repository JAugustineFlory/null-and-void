class_name Notebook
extends CanvasLayer
## The player's notebook, opened with Tab (on the current case, if there is one);
## 1-5 turn to its tabs. It can't be opened while using a terminal,
## so players have to read it, remember, and then type.
## With Game.diegetic_ui it's held in your hands (HeldNotebook on the camera, raised
## by the Player): you can still look round and walk slowly. Without, it opens
## full-screen over the view and holds you still.

signal opened
signal closed

var player: Player
var terminal_ui: TerminalUI
var pages: NotebookPages
## The notebook in your hands, when it's held rather than full-screen.
var held: HeldNotebook
## Where you type a note of your own (from "+ write a note"); shown while writing.
var writer: LineEdit
var _open := false
## How long an answer waits for your hands to be free to show the notebook.
const ANSWER_WAIT_FRAMES := 300
var _was_locked := false
## The right stick turned a page and hasn't come back to the middle yet.
var _stick_turned := false


func _ready() -> void:
	layer = 15  # above the VHS overlay (3), below the terminal (20)
	_build()
	get_node("/root/Game").notebook_changed.connect(func():
		if _open:
			pages.refresh())
	get_node("/root/Game").answer_found.connect(_show_answer)
	PadReader.attach(self, _on_pad, _on_stick)


## Held or full-screen, as Game.diegetic_ui says. Call again after changing it.
func rebuild() -> void:
	close()
	if held:
		if player and player.held_notebook == held:
			player.held_notebook = null
		held.queue_free()
		held = null
	if pages:
		pages.queue_free()
	_build()


func _build() -> void:
	pages = NotebookPages.new()
	pages.write_requested.connect(start_writing)
	if get_node("/root/Game").diegetic_ui and player and player.camera:
		var look := NetPlayers.look_for(self, multiplayer.get_unique_id())
		held = HeldNotebook.attach(player.camera, look)
		held.set_content(pages)
		held.follow(player)  # its hand reaches for a sticky note being filed
		player.held_notebook = held
		# The same hands hold papers you pick up to read.
		if player.camera.get_node_or_null("HeldPaper") == null:
			HeldPaper.attach(player.camera, look).follow(player)
		# Put away by the player's own moves too (stepping up to a terminal, a respawn).
		if not player.notebook_lowered.is_connected(_on_lowered):
			player.notebook_lowered.connect(_on_lowered)
	else:
		pages.visible = false
		add_child(pages)


## You added the line that answers a case: once you've stepped back from the
## terminal or put the paper down, the notebook comes up at the case page and the
## answer is written into its blank there (NotebookPages).
func _show_answer(_case_id: String) -> void:
	for i in ANSWER_WAIT_FRAMES:
		if _open:
			pages.show_page(NotebookPages.Page.CASES)
			return
		if open(NotebookPages.Page.CASES):
			return
		await get_tree().process_frame


## Where Tab opens the notebook: on the case being worked on (or one just
## solved), or on the work order while there's no case and the job is still the job.
static func default_page_for(game: Node) -> int:
	if game.current_case() != "" or game.job_over or game.notebook_cases.any(func(c): return c.get("fresh_solve", false)):
		return NotebookPages.Page.CASES
	return NotebookPages.Page.WORK_ORDER


func default_page() -> int:
	return default_page_for(get_node("/root/Game"))


func _on_lowered() -> void:
	if _open and held and not player.is_holding_notebook():
		_set_closed()


func is_open() -> bool:
	return _open


## Open unless something else has the player: a terminal, a scripted move, a menu.
func open(page: int = -1) -> bool:
	if _open or not player or player.input_locked:
		return false
	if terminal_ui and terminal_ui.visible:
		return false
	if held:
		if player.is_using_terminal() or not player.raise_notebook():
			return false
	else:
		player.input_locked = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open = true
	pages.visible = true
	pages.showing = true
	pages.showing_completed = false
	pages.completed_case = ""
	pages.show_page(page if page >= 0 else default_page())
	pages.book.show_book()
	opened.emit()
	return true


func close() -> void:
	if not _open:
		return
	stop_writing()
	if held:
		player.lower_notebook()
	else:
		if player:
			player.input_locked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_closed()


func _set_closed() -> void:
	_open = false
	pages.pad_pick(null)
	pages.showing = false
	pages.file_solved()
	pages.book.hide_book().finished.connect(func():
		if not _open and not held:
			pages.visible = false)
	closed.emit()


## A line at the foot of the screen to write your own note: you stand still
## while you write, Enter writes it in, Esc puts the pen down.
func start_writing() -> void:
	if not _open or is_writing():
		return
	if not writer:
		writer = LineEdit.new()
		writer.name = "Writer"
		writer.placeholder_text = "Write a note: a PIN, a name, anything. Enter to write it in, Esc to stop."
		writer.max_length = 120
		writer.add_theme_font_override("font", NotebookArt.hand_font())
		writer.add_theme_font_size_override("font_size", 28)
		writer.add_theme_color_override("font_color", NotebookArt.INK)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.97, 0.95, 0.88)
		sb.border_color = NotebookArt.INK
		sb.border_width_bottom = 2
		sb.set_content_margin_all(10)
		writer.add_theme_stylebox_override("normal", sb)
		writer.add_theme_stylebox_override("focus", sb)
		writer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		writer.custom_minimum_size = Vector2(760, 0)
		writer.offset_left = -380
		writer.offset_right = 380
		writer.offset_top = -120
		writer.offset_bottom = -64
		writer.text_submitted.connect(func(t): finish_writing(t))
		writer.gui_input.connect(_on_writer_key)
		add_child(writer)
	writer.text = ""
	writer.visible = true
	_was_locked = player.input_locked if player else false
	if player:
		player.input_locked = true  # typing doesn't walk you around
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	writer.grab_focus()
	PadReader.show_keyboard("")


func is_writing() -> bool:
	return writer != null and writer.visible


## Write `text` into the notebook as your own note (nothing if it's blank).
func finish_writing(text: String) -> void:
	text = text.strip_edges()
	if text != "":
		get_node("/root/Game").write_note("", text, "mine")
	stop_writing()


func stop_writing() -> void:
	if not is_writing():
		return
	writer.visible = false
	writer.release_focus()
	PadReader.hide_keyboard()
	if player:
		player.input_locked = _was_locked
		if held:
			player.set_notebook_cursor(true)


func _on_writer_key(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		stop_writing()
		writer.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if is_writing():
		return
	if event.is_action_pressed("notebook"):
		if _open:
			close()
		elif not open():
			return  # Tab is someone else's (the pause menu closes on it)
		get_viewport().set_input_as_handled()
	elif _open and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode >= KEY_1 and event.physical_keycode < KEY_1 + NotebookPages.TAB_NAMES.size():
		pages.show_page(event.physical_keycode - KEY_1)  # 1-4: the tabs, in order
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


## A gamepad press while the notebook is up (PadReader): LB and RB turn the
## tabs, Y writes a note, the d-pad (left, right) picks a button on the pages and
## A presses it, B puts the notebook away (View too, as Tab does). Up and down
## stay the radio's.
func _on_pad(event: InputEvent) -> bool:
	if not _open or event is InputEventJoypadMotion or not event.is_pressed() or event.is_echo():
		return false
	if is_writing():
		if event.is_action_pressed("alt_interact"):
			finish_writing(writer.text)
			return true
		return false  # B is ui_cancel: the writer puts the pen down
	if event.is_action_pressed("ui_tab_prev") or event.is_action_pressed("ui_tab_next"):
		var step := -1 if event.is_action_pressed("ui_tab_prev") else 1
		var n := NotebookPages.TAB_NAMES.size()
		pages.show_page((pages.current_page() + step + n) % n)
	elif event.is_action_pressed("alt_interact"):
		start_writing()
	elif event.is_action_pressed("ui_left"):
		pages.pad_move(-1)
	elif event.is_action_pressed("ui_right"):
		pages.pad_move(1)
	elif event.is_action_pressed("ui_accept"):
		pages.pad_press()
	elif event.is_action_pressed("ui_cancel"):
		close()
	else:
		return false
	return true


## The right stick pushed left or right turns the page back or on, once a push.
func _on_stick(v: Vector2, _delta: float) -> void:
	if not _open or is_writing():
		_stick_turned = false
		return
	if absf(v.x) < 0.3:
		_stick_turned = false
	elif absf(v.x) > 0.6 and not _stick_turned:
		_stick_turned = true
		pages.turn(1 if v.x > 0.0 else -1)
