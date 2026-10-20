class_name Notebook
extends CanvasLayer
## The player's notebook, opened with Tab; 1-4 turn to its tabs. It can't be opened while using a terminal,
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
var _was_locked := false


func _ready() -> void:
	layer = 15  # above the VHS overlay (3), below the terminal (20)
	_build()
	get_node("/root/Game").notebook_changed.connect(func():
		if _open:
			pages.refresh())


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
		var look := CharacterLooks.crew(NetPlayers.index_of(multiplayer.get_unique_id(), multiplayer))
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
	if page >= 0:
		pages.show_page(page)
	else:
		pages.refresh()
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
	if player:
		player.input_locked = _was_locked
		if held:
			player.set_notebook_cursor(not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))


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
