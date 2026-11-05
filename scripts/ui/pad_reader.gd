class_name PadReader
extends Node
## A screen that takes typing (the terminal, the notebook) reads the gamepad
## through this: each pad press reaches `on_press` before any control on screen
## sees it (true: it's used, so nothing else acts on it, like the d-pad moving
## focus off the typing line), and `on_stick` gets the right stick every frame
## (Movement leaves it alone while you read, PadInput's dead zone applied).

var on_press: Callable
var on_stick: Callable


static func attach(parent: Node, press: Callable, stick := Callable()) -> PadReader:
	var r := PadReader.new()
	r.name = "PadReader"
	r.on_press = press
	r.on_stick = stick
	parent.add_child(r)
	return r


static func is_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func _input(event: InputEvent) -> void:
	if not is_pad(event) or not on_press.is_valid():
		return
	InputGlyphs.saw(event)  # before it's used up, so the prompts switch to the pad
	if on_press.call(event):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not on_stick.is_valid():
		return
	var v := Input.get_vector("look_left", "look_right", "look_up", "look_down", PadInput.dead_zone)
	on_stick.call(v, delta)


## The on-screen keyboard, where the system has one, for typing with a pad
## (a Steam Deck in desktop mode brings up Steam's own with Steam + X).
static func show_keyboard(text: String) -> void:
	if InputGlyphs.pad and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(text)


static func hide_keyboard() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
