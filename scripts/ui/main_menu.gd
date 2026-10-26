extends Control
## Title screen: Start (into the garage) and Quit.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.02)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(700, 0)
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := ThemeUtil.label("NULL & VOID", 84, ThemeUtil.GREEN)
	title.add_theme_font_override("font", ThemeUtil.mono())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := ThemeUtil.label("Halcyon Data Systems  -  October 15, 1997  -  11:02 PM", 20, ThemeUtil.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(Control.new())

	# Start goes into the crew's garage. Single-player, co-op, levels and
	# customize are on its nav bar (lobby.gd), not here.
	var start := _button("Start")
	start.name = "Start"
	start.pressed.connect(func():
		get_node("/root/Net").begin_solo_lobby()
		Game.goto("lobby"))
	box.add_child(start)
	var quit := _button("Quit")
	quit.name = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)

	var net := get_node("/root/Net")
	if net.last_message != "":
		var msg := ThemeUtil.label(net.last_message, 18, ThemeUtil.AMBER)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(msg)
		net.last_message = ""

	var note := ThemeUtil.label("First playable slice: greybox art, placeholder voices. Levels 0 to 2.", 16, Color(1, 1, 1, 0.4))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	start.grab_focus()


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 24)
	return b
