extends RefCounted
## Gamepad (Steam Deck) tests: every action has a pad button, prompts name the
## pad's buttons while it's in use, and each crew member can do every move with
## the sticks and buttons alone (real joypad events through Input, not `controls`).

var t: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("Gamepad")
	PadInput.bind()
	InputGlyphs.watch(t.root)
	await t.process_frame
	await test_every_action_has_a_button()
	await test_glyphs_follow_the_device()
	await test_sticks_and_buttons()
	await test_every_crew_member_on_a_pad()
	_release_all()
	InputGlyphs.pad = false


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func frames(n: int) -> void:
	for i in n:
		await t.physics_frame


func arena() -> Node3D:
	var a := Node3D.new()
	t.root.add_child(a)
	Greybox.box(a, Vector3(0, -0.1, 0), Vector3(40, 0.2, 40), Color.GRAY, "Floor")
	return a


## A player read from the real Input (like the one on your screen).
func spawn(parent: Node, pos: Vector3, body := CrewBody.new()) -> Player:
	var p := Player.new()
	p.local_control = true
	p.body = body
	p.position = pos
	parent.add_child(p)
	return p


func done(a: Node) -> void:
	_release_all()
	a.queue_free()
	await t.process_frame


func axis(which: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = which
	e.axis_value = value
	Input.parse_input_event(e)


func button(which: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = which
	e.pressed = pressed
	e.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


## Tap a button: down for a couple of physics frames, then up.
func tap(which: JoyButton) -> void:
	button(which, true)
	await frames(2)
	button(which, false)
	await frames(1)


func _release_all() -> void:
	for a in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		axis(a, 0.0)
	for b in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		button(b, false)


# --- Tests ---------------------------------------------------------------------

func test_every_action_has_a_button() -> void:
	var missing := []
	for action in ["move_forward", "move_back", "move_left", "move_right", "look_left", "look_right", "look_up", "look_down",
			"sprint", "crouch", "jump", "interact", "alt_interact", "flashlight", "attack", "block", "radio_talk",
			"voice_toggle", "pause", "notebook", "inventory", "sit", "hotbar_next", "ui_tab_prev", "ui_tab_next"]:
		var pad := false
		for ev in InputMap.action_get_events(action) if InputMap.has_action(action) else []:
			pad = pad or ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if not pad:
			missing.append(action)
	check(missing.is_empty(), "every action has a gamepad button (missing: %s)" % [missing])
	check(InputGlyphs.of("radio_talk", false) == "V" and InputGlyphs.of("voice_toggle", false) == "B", "the radio keys are still V and B")


func test_glyphs_follow_the_device() -> void:
	check(InputGlyphs.of("interact", false) == "E" and InputGlyphs.of("interact", true) == "X", "use is E on the keyboard, X on a pad")
	check(InputGlyphs.text("[E] Open the door    [X] Knock", true) == "[X] Open the door    [Y] Knock", "a prompt names the pad's buttons, each swapped once (%s)" % InputGlyphs.text("[E] Open the door    [X] Knock", true))
	check(InputGlyphs.text("Hold V to talk on the radio. Press E to read it.", true) == "Hold D-pad up to talk on the radio. Press X to read it.", "and so does \"press E\" in a notice")
	check(InputGlyphs.text("[E] Open the door", false) == "[E] Open the door", "on the keyboard, prompts stay as written")
	check(InputGlyphs.text("Shift roster [A] [WASD]", true) == "Shift roster [A] [WASD]", "words that aren't keys are left alone")
	InputGlyphs.deck = true
	check(InputGlyphs.of("attack", true) == "R2" and InputGlyphs.of("flashlight", true) == "L1", "a Steam Deck's triggers and bumpers read R2 and L1")
	check(InputGlyphs.deck_names("LB  flashlight     RT  strike     LT  block (LB/RB turn tabs)") == "L1  flashlight     R2  strike     L2  block (L1/R1 turn tabs)", "and so does the controls list")
	InputGlyphs.deck = false
	# The last device used decides.
	InputGlyphs.pad = false
	button(JOY_BUTTON_A, true)
	await t.process_frame
	button(JOY_BUTTON_A, false)
	await t.process_frame
	check(InputGlyphs.pad, "pressing a pad button switches prompts to the pad")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	await t.process_frame
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await t.process_frame
	check(not InputGlyphs.pad, "and a key press switches them back")


func test_sticks_and_buttons() -> void:
	var a := arena()
	var p := spawn(a, Vector3(0, 0.05, 10))
	await frames(5)
	# Stick drift inside the dead zone doesn't move or turn you.
	axis(JOY_AXIS_LEFT_Y, -PadInput.dead_zone * 0.6)
	axis(JOY_AXIS_RIGHT_X, PadInput.dead_zone * 0.6)
	var z0 := p.global_position.z
	var yaw0 := p.rotation.y
	await frames(30)
	check(absf(p.global_position.z - z0) < 0.01 and absf(p.rotation.y - yaw0) < 0.001, "a resting stick's drift does nothing")
	# Left stick walks.
	axis(JOY_AXIS_RIGHT_X, 0.0)
	axis(JOY_AXIS_LEFT_Y, -1.0)
	await frames(30)
	var walk := Vector2(p.velocity.x, p.velocity.z).length()
	check(p.global_position.z < z0 - 1.0 and absf(walk - Player.WALK_SPEED) < 0.3, "the left stick walks (%.2f m/s)" % walk)
	# L3 sprints, and stays sprinting until you stop.
	InputGlyphs.pad = true
	await tap(JOY_BUTTON_LEFT_STICK)
	await frames(30)
	var run := Vector2(p.velocity.x, p.velocity.z).length()
	check(run > Player.WALK_SPEED + 1.5, "click L3: sprint, without holding it (%.2f m/s)" % run)
	axis(JOY_AXIS_LEFT_Y, 0.0)
	await frames(20)
	axis(JOY_AXIS_LEFT_Y, -1.0)
	await frames(30)
	walk = Vector2(p.velocity.x, p.velocity.z).length()
	check(walk < Player.WALK_SPEED + 0.3, "stop, and you walk again (%.2f m/s)" % walk)
	axis(JOY_AXIS_LEFT_Y, 0.0)
	await frames(20)
	# A jumps; B crouches.
	var y0 := p.global_position.y
	var top := y0
	button(JOY_BUTTON_A, true)
	for i in 20:
		await frames(1)
		top = maxf(top, p.global_position.y)
	button(JOY_BUTTON_A, false)
	check(top > y0 + 0.5, "A jumps (%.2f m up)" % (top - y0))
	await frames(40)
	button(JOY_BUTTON_B, true)
	await frames(20)
	check(p.crouching, "holding B crouches")
	button(JOY_BUTTON_B, false)
	await frames(20)
	check(not p.crouching, "let go of B to stand")
	# The right stick looks round; invert look flips up and down.
	axis(JOY_AXIS_RIGHT_X, 1.0)
	await frames(30)
	axis(JOY_AXIS_RIGHT_X, 0.0)
	await t.process_frame
	check(p.rotation.y < yaw0 - 0.5, "the right stick turns you (%.2f rad)" % (yaw0 - p.rotation.y))
	var pitch0 := p.head.rotation.x
	axis(JOY_AXIS_RIGHT_Y, -1.0)
	await frames(10)
	axis(JOY_AXIS_RIGHT_Y, 0.0)
	await t.process_frame
	check(p.head.rotation.x > pitch0 + 0.1, "pushing the right stick up looks up")
	PadInput.invert_look = true
	pitch0 = p.head.rotation.x
	axis(JOY_AXIS_RIGHT_Y, -1.0)
	await frames(10)
	axis(JOY_AXIS_RIGHT_Y, 0.0)
	await t.process_frame
	PadInput.invert_look = false
	check(p.head.rotation.x < pitch0 - 0.1, "with invert look on, it looks down")
	# LB is the flashlight; D-pad right takes out the next hotbar item.
	var lit := p.flashlight.visible
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	check(p.flashlight.visible != lit, "LB switches the flashlight")
	p.inventory.add("radio")
	p.inventory.assign(1, "radio")
	await tap(JOY_BUTTON_DPAD_RIGHT)
	check(p.inventory.active_item() == "radio", "D-pad right takes out the next hotbar item (%s)" % p.inventory.active_item())
	await tap(JOY_BUTTON_DPAD_RIGHT)
	check(p.inventory.active_item() == "", "past the last one, it puts it away")
	await done(a)


## Every crew member, with the pad alone: mantle a 1.5 m box, crawl a vent and
## get up a 2 m wall.
func test_every_crew_member_on_a_pad() -> void:
	InputGlyphs.pad = true
	var failed := []
	for slug in PlayableCrew.slugs():
		var a := arena()
		Greybox.box(a, Vector3(0, 0.75, -3), Vector3(2, 1.5, 1), Color.DIM_GRAY)  # mantle onto it
		Greybox.box(a, Vector3(6, 1.0, -3), Vector3(3, 2.0, 1), Color.DIM_GRAY)  # wall to catch and climb
		Traversal.vent(a, Vector3(-6, 0, -2), Vector3(-6, 0, -8))
		var body := CrewBody.of_crew(slug)
		var p := spawn(a, Vector3(0, 0.05, 0), body)
		await frames(5)
		# Stick forward + A at the box: mantle.
		axis(JOY_AXIS_LEFT_Y, -1.0)
		var mantled := false
		for i in 120:
			if p.global_position.z < -1.6:
				button(JOY_BUTTON_A, true)
			await frames(1)
			mantled = mantled or p.global_position.y > 1.4
			if mantled:
				break
		button(JOY_BUTTON_A, false)
		axis(JOY_AXIS_LEFT_Y, 0.0)
		if not mantled:
			failed.append("%s mantle" % slug)
		# Hold B and push through the vent.
		p.global_position = Vector3(-6, 0.05, 0)
		await frames(5)
		button(JOY_BUTTON_B, true)
		axis(JOY_AXIS_LEFT_Y, -1.0)
		var through := false
		for i in 600:
			await frames(1)
			if p.global_position.z < -8.5:
				through = true
				break
		axis(JOY_AXIS_LEFT_Y, 0.0)
		button(JOY_BUTTON_B, false)
		if not through:
			failed.append("%s vent (z %.1f)" % [slug, p.global_position.z])
		# Stick forward + A at a 2 m wall: up it (a jump and mantle, or a catch and climb).
		p.global_position = Vector3(6, 0.05, -1.0)
		await frames(20)
		axis(JOY_AXIS_LEFT_Y, -1.0)
		button(JOY_BUTTON_A, true)
		await frames(30)
		button(JOY_BUTTON_A, false)
		axis(JOY_AXIS_LEFT_Y, 0.0)  # don't walk off the far side
		await frames(15)
		await tap(JOY_BUTTON_A)  # pulls up if you're hanging
		await frames(60)
		if p.global_position.y < 1.9:
			failed.append("%s wall (y %.1f)" % [slug, p.global_position.y])
		await done(a)
	check(failed.is_empty(), "all %d crew members mantle, crawl a vent and get up a wall with the pad alone (failed: %s)" % [PlayableCrew.slugs().size(), failed])
