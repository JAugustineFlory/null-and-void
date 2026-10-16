extends Control
## End-of-level summary: what you learned, with your own queries as examples.

const CONCEPT_NOTES := {
	"SELECT": "SELECT picks which columns you want to see. * means all of them.",
	"FROM": "FROM names the table to read.",
	"ORDER BY": "ORDER BY sorts rows by a column. Add DESC for biggest first.",
	"WHERE": "WHERE keeps only the rows that match a condition.",
	"AND": "AND requires both conditions to be true.",
	"OR": "OR accepts a row if either condition is true.",
	"LIKE": "LIKE matches patterns: 'Har%' means starts with Har.",
}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.02)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 160
	scroll.offset_right = -160
	scroll.offset_top = 50
	scroll.offset_bottom = -50
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)

	box.add_child(ThemeUtil.label("FIELD NOTES", 54, ThemeUtil.GREEN))
	box.add_child(ThemeUtil.label("Levels 0 and 1  -  The Lobby, Server Room A", 20, ThemeUtil.DIM))
	box.add_child(_spacer())

	box.add_child(ThemeUtil.label("What you learned", 28, ThemeUtil.AMBER))
	for c in Game.concepts_learned:
		box.add_child(_mono("  %-9s %s" % [c, CONCEPT_NOTES.get(c, "")]))
	box.add_child(_mono("  TESTS     A self-test lists PASS/FAIL checks. Failing tests tell you where to look."))
	box.add_child(_spacer())

	box.add_child(ThemeUtil.label("Queries you wrote", 28, ThemeUtil.AMBER))
	var shown := Game.query_log.slice(max(0, Game.query_log.size() - 12))
	if shown.is_empty():
		box.add_child(_mono("  (none)"))
	for q in shown:
		box.add_child(_mono("  > " + q.replace("\n", " ")))
	box.add_child(_spacer())

	var fate: String = {
		"killed": "Rourke is dead. WARDEN locked the building the moment his heart stopped.",
		"tied": "You tied Rourke up. He didn't stay tied.",
	}.get(Game.rourke_fate, "Rourke's fate is unknown.")
	box.add_child(ThemeUtil.label(fate, 22, Color(0.9, 0.85, 0.8)))
	box.add_child(ThemeUtil.label("End of the first playable slice. Thanks for testing.", 22, Color(0.9, 0.85, 0.8)))
	box.add_child(_spacer())

	var again := Button.new()
	again.text = "Play again (new data)"
	again.custom_minimum_size = Vector2(320, 50)
	again.pressed.connect(func():
		Game.new_run()
		Game.goto("level_0"))
	box.add_child(again)
	var menu := Button.new()
	menu.text = "Main menu"
	menu.custom_minimum_size = Vector2(320, 50)
	menu.pressed.connect(func(): Game.goto("menu"))
	box.add_child(menu)


func _mono(text: String) -> Label:
	var l := ThemeUtil.label(text, 18, ThemeUtil.GREEN)
	l.add_theme_font_override("font", ThemeUtil.mono())
	return l


func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 14)
	return c
