class_name PadInput
extends RefCounted
## Gamepad support (Steam Deck and any XInput-style pad): the buttons for every
## input action, and the stick settings (look speed, dead zone, invert look),
## saved in user://controls.cfg. Keyboard and mouse keep working alongside.
##
## Layout (Xbox names; a Steam Deck's bumpers and triggers are L1 R1 L2 R2):
##   left stick move, right stick look, L3 sprint (stays on until you stop)
##   A jump/vault/mantle/stand up, B crouch/slide/roll (hold), X use, Y other use
##   LT block, RT strike, LB flashlight, RB sit on the floor
##   D-pad up radio (hold), down mute, left inventory, right next hotbar item
##   View notebook, Menu pause; in menus A picks, B goes back, LB/RB turn tabs (ui_tab_prev/next)

const SETTINGS := "user://controls.cfg"

## Each action's pad inputs: a JoyButton, or [JoyAxis, direction] for a stick or trigger.
const BUTTONS := {
	"move_forward": [[JOY_AXIS_LEFT_Y, -1]],
	"move_back": [[JOY_AXIS_LEFT_Y, 1]],
	"move_left": [[JOY_AXIS_LEFT_X, -1]],
	"move_right": [[JOY_AXIS_LEFT_X, 1]],
	"look_left": [[JOY_AXIS_RIGHT_X, -1]],
	"look_right": [[JOY_AXIS_RIGHT_X, 1]],
	"look_up": [[JOY_AXIS_RIGHT_Y, -1]],
	"look_down": [[JOY_AXIS_RIGHT_Y, 1]],
	"sprint": [JOY_BUTTON_LEFT_STICK],
	"jump": [JOY_BUTTON_A],
	"crouch": [JOY_BUTTON_B],
	"interact": [JOY_BUTTON_X],
	"alt_interact": [JOY_BUTTON_Y],
	"block": [[JOY_AXIS_TRIGGER_LEFT, 1]],
	"attack": [[JOY_AXIS_TRIGGER_RIGHT, 1]],
	"flashlight": [JOY_BUTTON_LEFT_SHOULDER],
	"sit": [JOY_BUTTON_RIGHT_SHOULDER],
	"radio_talk": [JOY_BUTTON_DPAD_UP],
	"voice_toggle": [JOY_BUTTON_DPAD_DOWN],
	"inventory": [JOY_BUTTON_DPAD_LEFT],
	"hotbar_next": [JOY_BUTTON_DPAD_RIGHT],
	"notebook": [JOY_BUTTON_BACK],
	"pause": [JOY_BUTTON_START],
	"ui_accept": [JOY_BUTTON_A],  # Godot gives these no pad buttons of its own
	"ui_cancel": [JOY_BUTTON_B],
	"ui_tab_prev": [JOY_BUTTON_LEFT_SHOULDER],
	"ui_tab_next": [JOY_BUTTON_RIGHT_SHOULDER],
}
## Keys for actions this file may be first to create (the rest come from Game and Net).
const KEYS := {"radio_talk": KEY_V, "voice_toggle": KEY_B}
## Sticks report every small wobble; the dead zone (a setting) is applied on top.
const STICK_ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "look_left", "look_right", "look_up", "look_down"]

## Full right stick turns the view this fast (radians per second) at look speed 1.0.
const LOOK_RATE := Vector2(3.6, 2.4)

## Look speed (0.25-2.5, 1.0 normal), stick dead zone (0.05-0.4) and invert look.
static var look_speed := 1.0
static var dead_zone := 0.15
static var invert_look := false
static var _loaded := false


## Adds the pad buttons to every action (after the keyboard bindings exist).
static func bind() -> void:
	load_settings()
	for action: String in BUTTONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			if KEYS.has(action):
				var key := InputEventKey.new()
				key.physical_keycode = KEYS[action]
				InputMap.action_add_event(action, key)
		if action in STICK_ACTIONS:
			InputMap.action_set_deadzone(action, 0.05)
		for b in BUTTONS[action]:
			var ev: InputEvent
			if b is Array:
				var m := InputEventJoypadMotion.new()
				m.axis = b[0]
				m.axis_value = b[1]
				ev = m
			else:
				var j := InputEventJoypadButton.new()
				j.button_index = b
				ev = j
			ev.device = -1  # any pad
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)


## The move stick, with the dead zone. Keys give full strength as before.
static func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back", dead_zone)


## How far to turn the view this frame from the right stick: x right, y down
## (radians). Small pushes turn slowly for aiming, full pushes turn fast.
static func look_turn(delta: float) -> Vector2:
	var v := Input.get_vector("look_left", "look_right", "look_up", "look_down", dead_zone)
	if v == Vector2.ZERO:
		return Vector2.ZERO
	v *= v.length()  # gentle near the middle, for aiming
	if invert_look:
		v.y = -v.y
	return v * LOOK_RATE * look_speed * delta


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		return
	look_speed = clampf(float(cfg.get_value("pad", "look_speed", look_speed)), 0.25, 2.5)
	dead_zone = clampf(float(cfg.get_value("pad", "dead_zone", dead_zone)), 0.05, 0.4)
	invert_look = bool(cfg.get_value("pad", "invert_look", invert_look))


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("pad", "look_speed", look_speed)
	cfg.set_value("pad", "dead_zone", dead_zone)
	cfg.set_value("pad", "invert_look", invert_look)
	cfg.save(SETTINGS)
