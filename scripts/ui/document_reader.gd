class_name DocumentReader
extends CanvasLayer
## A document held up to read (see Document). Each line has a "+ note" button
## that copies it into this player's notebook, with an optional name.
## E or Esc puts it down.

signal closed

var document: Node
var player: Node
var _lines: VBoxContainer
var _note_label: LineEdit
var _note_index := -1
var _opened_frame := -1


func _ready() -> void:
	layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = NotebookArt.PAPER
	style.set_corner_radius_all(4)
	style.set_content_margin_all(28)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 6)
	box.add_child(_lines)
	_note_label = LineEdit.new()
	_note_label.visible = false
	_note_label.placeholder_text = "Name this note (optional), then Enter. Esc to cancel."
	_note_label.max_length = 40
	_note_label.text_submitted.connect(func(t): _finish_note(t))
	box.add_child(_note_label)
	var foot := NotebookArt.hand("+ note: copy a line into your notebook    E or Esc: put it down", 18, NotebookArt.PENCIL)
	box.add_child(foot)


func open(doc: Node, by_player: Node) -> void:
	document = doc
	player = by_player
	_opened_frame = Engine.get_process_frames()
	if player and "input_locked" in player:
		player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in _lines.get_children():
		c.queue_free()
	var heading := NotebookArt.code(document.title, 24)
	_lines.add_child(heading)
	var all: Array[Dictionary] = document.lines()
	for i in all.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var text: String = all[i].text
		var label: Label = NotebookArt.hand(text, 26) if all[i].get("hand", false) else NotebookArt.code(text, 19)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size.x = 540
		row.add_child(label)
		if text.strip_edges() != "":
			var b := NotebookArt.write_button()
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(_start_note.bind(i))
			row.add_child(b)
		_lines.add_child(row)


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


func _start_note(index: int) -> void:
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
