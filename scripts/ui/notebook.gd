class_name Notebook
extends CanvasLayer
## The player's notebook, opened with Tab. It can't be opened while using a terminal,
## so players have to read it, remember, and then type.

signal opened
signal closed

var player: Player
var terminal_ui: TerminalUI
var pages: NotebookPages
var _open := false


func _ready() -> void:
	layer = 15  # above the VHS overlay (3), below the terminal (20)
	pages = NotebookPages.new()
	pages.visible = false
	add_child(pages)
	get_node("/root/Game").notebook_changed.connect(func():
		if _open:
			pages.refresh())


func is_open() -> bool:
	return _open


## Open unless something else has the player: a terminal, a scripted move, a menu.
func open(page: int = -1) -> bool:
	if _open or not player or player.input_locked:
		return false
	if terminal_ui and terminal_ui.visible:
		return false
	_open = true
	pages.visible = true
	if page >= 0:
		pages.show_page(page)
	else:
		pages.refresh()
	pages.book.show_book()
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	opened.emit()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	pages.book.hide_book().finished.connect(func():
		if not _open:
			pages.visible = false)
	if player:
		player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
