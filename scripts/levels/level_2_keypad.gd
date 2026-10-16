class_name Level2Keypad
extends CanvasLayer
## The PIN pad on the stairwell door. Type four digits, press Enter.

signal submitted(pin: String)

var player: Player
var _title: Label
var _entry: LineEdit
var _status: Label


func _ready() -> void:
	layer = 20
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.09)
	style.border_color = Color(0.5, 0.45, 0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_title = ThemeUtil.label("", 22, ThemeUtil.AMBER)
	box.add_child(_title)
	_entry = LineEdit.new()
	_entry.max_length = 4
	_entry.secret = false
	_entry.placeholder_text = "PIN"
	_entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry.add_theme_font_override("font", ThemeUtil.mono())
	_entry.add_theme_font_size_override("font_size", 48)
	_entry.text_submitted.connect(_on_submit)
	_entry.gui_input.connect(_on_key)
	box.add_child(_entry)
	_status = ThemeUtil.label("", 18, ThemeUtil.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	box.add_child(ThemeUtil.label("Enter: submit    Esc: step away", 15, ThemeUtil.DIM))


func open(by_player: Player, title: String, status: String = "") -> void:
	player = by_player
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title.text = title
	_status.text = status
	_entry.text = ""
	visible = true
	_entry.grab_focus()


func show_status(text: String, color: Color = ThemeUtil.DIM) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func close() -> void:
	if not visible:
		return
	visible = false
	_entry.release_focus()
	if player:
		player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_submit(text: String) -> void:
	_entry.text = ""
	submitted.emit(text.strip_edges())


func _on_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_entry.accept_event()
		close()
