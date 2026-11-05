extends RefCounted
## The front end on a controller (PadFocus): the title screen, its panels, the
## pre-game lobby and the pause menu, driven by d-pad, A and B (ui_up/down,
## ui_accept, ui_cancel) with no mouse.

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	await test_title_screen()
	await test_lobby()
	await test_pause_menu()


## Press a ui_* action as a controller would, and let the menu answer it.
func _press(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		_tree.root.push_input(ev)
	await _tree.process_frame
	await _tree.process_frame


func _focus() -> Control:
	return _tree.root.gui_get_focus_owner()


func _named(c: Control) -> String:
	return c.name if c else "nothing"


func test_title_screen() -> void:
	print("Controller: the title screen and its panels")
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	_tree.root.add_child(menu)
	await _tree.process_frame
	await _tree.process_frame
	_check.call(_named(_focus()) == "Start", "it opens with Start picked, so A starts the game")
	var ring := menu.get_theme_stylebox("focus", "Button") as StyleBoxFlat
	_check.call(ring != null and ring.border_color == PadFocus.RING and ring.border_width_left >= 3, "what's picked has a thick amber outline round it")
	await _press("ui_down")
	_check.call(_named(_focus()) == "Settings", "down the d-pad goes to Settings")
	await _press("ui_accept")
	var panel: MenuModal = menu.find_children("*", "MenuModal", true, false).back() if not menu.find_children("*", "MenuModal", true, false).is_empty() else null
	_check.call(panel != null and panel.is_ancestor_of(_focus()), "A opens it, with something on it picked (%s)" % _named(_focus()))
	var left := true
	for i in 12:
		await _press("ui_up")
		left = left and panel.is_ancestor_of(_focus())
	for i in 30:
		await _press("ui_down")
		left = left and panel.is_ancestor_of(_focus())
	_check.call(left, "up or down, the pick stays on the panel: it never wanders to the buttons behind it")
	_check.call(_named(_focus()) == "Back", "and goes all the way down to Back")
	await _press("ui_cancel")
	_check.call(not is_instance_valid(panel) or panel.is_queued_for_deletion() or not panel.is_inside_tree(), "B closes it")
	await _tree.process_frame
	_check.call(_named(_focus()) == "Settings", "and the pick goes back to Settings, where it was")
	_tree.root.gui_release_focus()  # as a mouse click on empty space does
	await _press("ui_down")
	_check.call(_named(_focus()) == "Start", "with nothing picked, the first press picks the first button instead of being lost")
	var levels: MenuModal = LevelSelect.open(menu)
	await _tree.process_frame
	await _tree.process_frame
	_check.call(levels.is_ancestor_of(_focus()) and (_focus() as Button).text == "Ground floor", "the Levels list opens on its first floor")
	levels.close()
	menu.queue_free()
	await _tree.process_frame


func test_lobby() -> void:
	print("Controller: the pre-game lobby")
	var net := _tree.root.get_node("Net")
	var real_profile = net.profile
	net.profile = Profile.new()
	net.wanted_look = {}
	net.begin_solo_lobby()
	var lobby: Control = load("res://scenes/lobby.tscn").instantiate()
	_tree.root.add_child(lobby)
	await _tree.process_frame
	var skip := InputEventJoypadButton.new()
	skip.button_index = JOY_BUTTON_A
	skip.pressed = true
	_tree.root.push_input(skip)
	await _tree.process_frame
	_check.call(lobby.stage.intro_done, "a controller button skips the opening, as a key or a click does")
	await _tree.process_frame
	await _tree.process_frame
	_check.call(_named(_focus()) == "Ready", "Ready is picked to start with, so A readies up")
	await _press("ui_accept")
	_check.call(net.lobby_of(net.my_id()).ready, "and A does")
	await _press("ui_accept")
	_check.call(not net.lobby_of(net.my_id()).ready, "and A again takes it back")
	var nav: Button = lobby.find_child("NavCustomize", true, false)
	nav.grab_focus()
	await _press("ui_accept")
	var picker: LookPicker = lobby.find_child("LookPicker", true, false)
	_check.call(picker.is_visible_in_tree(), "A on Customize opens the picker")
	var swatches := ["Crew_mei", "Skin3", "Item_head", "Color_top"].map(func(n): return picker.find_child(n, true, false))
	_check.call(swatches.all(func(c): return c != null and c.focus_mode == Control.FOCUS_ALL), "and everything on it can be picked with the d-pad: crew, skin, items and colors")
	var mei: Button = picker.find_child("Crew_mei", true, false)
	mei.grab_focus()
	await _press("ui_accept")
	_check.call(net.wanted_look.get("crew", "") == "mei", "A on a crew member picks them")
	lobby.queue_free()
	net.leave(false)
	net.profile = real_profile
	await _tree.process_frame


func test_pause_menu() -> void:
	print("Controller: the pause menu")
	var level = load("res://scenes/movement_gym.tscn").instantiate()
	_tree.root.add_child(level)
	await _tree.process_frame
	await _tree.process_frame
	level._toggle_pause()
	await _tree.process_frame
	await _tree.process_frame
	_check.call(_named(_focus()) == "Resume" or (_focus() is Button and (_focus() as Button).text == "Resume"), "it opens with Resume picked (%s)" % _named(_focus()))
	await _press("ui_down")
	await _press("ui_down")
	_check.call(_focus() is Button and (_focus() as Button).text == "Audio", "down goes through Restart to Audio")
	await _press("ui_accept")
	_check.call(level._pause_at == "audio" and level._pause_pages["audio"].is_ancestor_of(_focus()), "A opens its page, with the first slider picked")
	await _press("ui_cancel")
	_check.call(level._pause_at == "main" and level._pause.visible and level._pause_pages["main"].is_ancestor_of(_focus()), "B goes back a page")
	await _press("ui_cancel")
	_check.call(not level._pause.visible and _focus() == null, "and B again closes the menu, and lets go of the pick so A goes back to the game")
	_tree.paused = false
	level.queue_free()
	await _tree.process_frame
