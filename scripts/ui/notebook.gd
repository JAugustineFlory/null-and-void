class_name Notebook
extends CanvasLayer
## The player's notebook, opened with Tab. It can't be opened while using a terminal,
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
var _open := false


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
	if get_node("/root/Game").diegetic_ui and player and player.camera:
		held = HeldNotebook.attach(player.camera, CharacterLooks.crew(NetPlayers.index_of(multiplayer.get_unique_id(), multiplayer)))
		held.set_content(pages)
		player.held_notebook = held
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("notebook"):
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
