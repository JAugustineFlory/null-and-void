class_name DocumentReader
extends CanvasLayer
## A document held up to read (see Document), drawn by DocumentView. Each line has
## a "+ note" button that copies it into this player's notebook, with an optional
## name. E or Esc puts it down.

signal closed

var document: Node
var player: Node
var view: DocumentView
var _note_label: LineEdit
var _note_index := -1
var _opened_frame := -1


func _ready() -> void:
	layer = 20
	view = DocumentView.new()
	add_child(view)
	view.copy_requested.connect(func(text): _start_note(_index_of(text)))
	view.closed.connect(close)
	_note_label = LineEdit.new()
	_note_label.visible = false
	_note_label.placeholder_text = "Name this note (optional), then Enter. Esc to cancel."
	_note_label.max_length = 40
	_note_label.custom_minimum_size = Vector2(520, 0)
	_note_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_note_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_note_label.offset_top = -64
	_note_label.offset_bottom = -24
	_note_label.text_submitted.connect(func(t): _finish_note(t))
	add_child(_note_label)


func open(doc: Node, by_player: Node) -> void:
	document = doc
	player = by_player
	_opened_frame = Engine.get_process_frames()
	if player and "input_locked" in player:
		player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view.clear()
	view.set_paper(document.paper_kind())
	view.set_title(document.title)
	for l in document.lines():
		if l.has("filled"):
			view.add_blank(l.get("before", ""), l.filled, l.get("after", ""), l.get("author", "player"))
		elif str(l.text).strip_edges() == "":
			view.body.add_child(Control.new())  # a gap between paragraphs
		elif l.get("hand", false):
			view.add_hand_line(l.text, l.get("author", "player"))
		else:
			view.add_line(l.text)
	view.show_doc()


func close() -> void:
	if not is_inside_tree():
		return
	if player and is_instance_valid(player) and "input_locked" in player:
		player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


## Copy line `index` into this player's notebook. A blank name uses the
## document's title, so the note says where it came from.
func write_note(index: int, label: String = "") -> bool:
	var all: Array[Dictionary] = document.lines()
	if index < 0 or index >= all.size() or str(all[index].text).strip_edges() == "":
		return false
	var name_it := label.strip_edges()
	get_node("/root/Game").write_note(name_it if name_it != "" else document.title, str(all[index].text).strip_edges(), "document")
	var level: Node = document._level()
	if level and level.get("hud"):
		level.hud.notice("Added to your notebook (Tab)", 3.0)
	return true


func _index_of(text: String) -> int:
	var all: Array[Dictionary] = document.lines()
	for i in all.size():
		if all[i].text == text:
			return i
	return -1


func _start_note(index: int) -> void:
	if index < 0:
		return
	_note_index = index
	_note_label.text = ""
	_note_label.visible = true
	_note_label.grab_focus()


func _finish_note(label: String) -> void:
	write_note(_note_index, label)
	_cancel_note()


func _cancel_note() -> void:
	_note_index = -1
	_note_label.visible = false
	_note_label.release_focus()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _note_label.visible:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_cancel_note()
		return
	# The E that opened it mustn't also put it down.
	if Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()
