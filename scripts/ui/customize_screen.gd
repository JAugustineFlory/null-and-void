extends Control
## The main menu's Customize screen: who you play and how you look, for solo as
## well as co-op (LookPicker). Picks are saved to your profile; the co-op lobby
## shows the same picker for quick changes.


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
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title := ThemeUtil.label("CUSTOMIZE", 64, ThemeUtil.GREEN)
	title.add_theme_font_override("font", ThemeUtil.mono())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(LookPicker.new())
	var back := Button.new()
	back.name = "Back"
	back.text = "Back"
	back.custom_minimum_size = Vector2(240, 50)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func(): get_node("/root/Game").goto("menu"))
	box.add_child(back)
	back.grab_focus()
