extends Control
## Title screen: Start (into the garage), Settings and Quit.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.02)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# In the middle of the window, scrolling: on a short window the buttons stay
	# reachable instead of running off the bottom.
	var box := VBoxContainer.new()
	box.name = "Menu"
	box.custom_minimum_size = Vector2(700, 0)
	box.add_theme_constant_override("separation", 18)
	MenuModal.column(self, box)

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
	var settings := _button("Settings")
	settings.name = "Settings"
	settings.pressed.connect(_open_settings)
	box.add_child(settings)
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

	var note := ThemeUtil.label("In development: greybox art, placeholder voices. Six floors playable.", 16, Color(1, 1, 1, 0.4))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	start.grab_focus()


## Audio and controls, the same pages the pause menu shows.
func _open_settings() -> void:
	var m := MenuModal.open(self)
	m.box.add_child(SettingsPanel.audio())
	m.box.add_child(SettingsPanel.controls())
	m.add_back()


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 24)
	return b
