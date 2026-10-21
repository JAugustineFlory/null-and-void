extends Control
## Title screen.


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

	var start := _button("Start (solo)")
	start.pressed.connect(func():
		get_node("/root/Net").begin_solo_lobby()  # the same opening as co-op, for one
		Game.goto("lobby"))
	box.add_child(start)
	var customize := _button("Customize")
	customize.name = "Customize"
	customize.pressed.connect(func(): Game.goto("customize"))
	box.add_child(customize)
	var skip := _button("Playtest: jump to Level 2")
	skip.pressed.connect(func():
		Game.new_run()
		Game.goto("level_2"))
	box.add_child(skip)
	var gym := _button("Movement gym (practice)")
	gym.pressed.connect(func(): Game.goto("movement_gym"))
	box.add_child(gym)
	var coop := _button("Co-op (2 to 6 players)")
	coop.pressed.connect(func():
		get_node("/root/Net").leave(false)  # nothing left over from a solo lobby
		Game.goto("lobby"))
	box.add_child(coop)
	var quit := _button("Quit")
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
