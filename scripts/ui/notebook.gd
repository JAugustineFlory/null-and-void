class_name Notebook
extends CanvasLayer
## The player's notebook, opened with Tab. It can't be opened while using a terminal,
## so players have to read it, remember, and then type.

signal opened
signal closed

var player: Player
var terminal_ui: TerminalUI
var view: NotebookView


func _ready() -> void:
	layer = 22
	view = NotebookView.new()
	view.visible = false
	add_child(view)
	get_node("/root/Game").notebook_changed.connect(view.refresh)


func is_open() -> bool:
	return view.visible


## Open unless something else has the player: a terminal, a scripted move, a menu.
func open(page: int = -1) -> bool:
	if is_open() or not player or player.input_locked:
		return false
	if terminal_ui and terminal_ui.visible:
		return false
	view.refresh()
	if page >= 0:
		view.show_page(page)
	view.visible = true
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	opened.emit()
	return true


func close() -> void:
	if not is_open():
		return
	view.visible = false
	if player:
		player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("notebook"):
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
