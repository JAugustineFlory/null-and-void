class_name SettingsPanel
## The settings pages, shared by the pause menu and the title screen: audio on one
## page, controls on the other. Each is a plain VBoxContainer, so whoever shows it
## decides where it sits and adds its own way back.

## Every key the game listens to. Kept here, not in a level, so the title screen
## can show the same list before a run starts.
const CONTROLS := """WASD  move          Shift  sprint
Ctrl  crouch, slide, roll
Space  jump     W + Space  vault, mantle, grab a ledge or pipe
Z  sit on the floor (E at a chair sits on it)     Space or Z  stand up
E  use, boost a teammate     X  other use
F  flashlight     Click  strike
Tab  your notebook: work order, cases, tables, Field Notes (1-4 turn to a tab)
     reading, push the cursor to a screen edge to look that way; Tab also closes menus
1-4  take out a hotbar item     I  inventory: choose what's on the hotbar
V (hold)  talk on the radio, once you have one
B  mute your open mic
Esc  the pause menu"""


## Master, music, effects, ambience and voices, each saved for next time.
static func audio() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "AudioSettings"
	box.add_theme_constant_override("separation", 10)
	box.add_child(heading("Audio"))
	box.add_child(SfxVolume.sliders())
	return box


## The key list, and the choice between a notebook you hold and one that fills the
## screen. `on_in_world` (optional) is called with the new setting, for a level that
## has a notebook open to rebuild.
static func controls(on_in_world := Callable()) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "ControlSettings"
	box.add_theme_constant_override("separation", 10)
	box.add_child(heading("Controls"))
	# Off: the notebook and terminals open full-screen (for anyone who finds that easier).
	var in_world := CheckButton.new()
	in_world.name = "InWorldUI"
	in_world.text = "Notebook and terminals in the world"
	var game := _game()
	in_world.button_pressed = game.diegetic_ui if game else true
	in_world.toggled.connect(func(on):
		var g := _game()
		if g:
			g.diegetic_ui = on
		if on_in_world.is_valid():
			on_in_world.call(on))
	box.add_child(in_world)
	box.add_child(ThemeUtil.label(CONTROLS, 17, Color(0.85, 0.85, 0.85)))
	return box


## A page's title.
static func heading(text: String) -> Label:
	var l := ThemeUtil.label(text, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A menu button the width of its page.
static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 22)
	return b


## The Game autoload, or null (tests load this script without it).
static func _game() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("Game") if loop else null
