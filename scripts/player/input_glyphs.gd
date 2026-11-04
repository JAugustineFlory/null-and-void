class_name InputGlyphs
extends RefCounted
## What to call each button on screen, for whichever device the player used last:
## the keyboard ("E", "Space") or a gamepad ("X", "A"). On-screen prompts are
## written with keyboard keys in brackets ("[E] Open the door"); `text()` swaps
## them for the pad's buttons while a pad is in use, so prompts follow the device.

## True when the last input came from a gamepad.
static var pad := false
## The pad's name says Steam Deck: its bumpers and triggers read L1 R1 L2 R2.
static var deck := false
static var _watcher: DeviceWatch

const PAD_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
const PAD_AXES := {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
	JOY_AXIS_LEFT_X: "Left stick", JOY_AXIS_LEFT_Y: "Left stick",
	JOY_AXIS_RIGHT_X: "Right stick", JOY_AXIS_RIGHT_Y: "Right stick"}
const DECK_NAMES := {"LB": "L1", "RB": "R1", "LT": "L2", "RT": "R2"}
const KEY_NAMES := {KEY_SPACE: "Space", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ESCAPE: "Esc",
	KEY_TAB: "Tab", KEY_ENTER: "Enter", KEY_UP: "Up", KEY_DOWN: "Down", KEY_LEFT: "Left", KEY_RIGHT: "Right"}
## Which action a bracketed keyboard key in a prompt stands for.
const PROMPT_KEYS := {"E": "interact", "X": "alt_interact", "Space": "jump", "Shift": "sprint",
	"Ctrl": "crouch", "C": "crouch", "Z": "sit", "F": "flashlight", "Tab": "notebook", "I": "inventory",
	"V": "radio_talk", "B": "voice_toggle", "Esc": "pause", "Click": "attack", "Right-click": "block"}
static var _press := RegEx.create_from_string("\\b(Press|press|Hold|hold) (E|X|Space|Z|F|Tab|I|V|B|Esc)\\b")
static var _bracket := RegEx.create_from_string("\\[([A-Za-z\\-]+)\\]")


## Watches for which device the player touches; add once (Game does, at start).
## `changed` fires when the player switches between keyboard and pad.
class DeviceWatch extends Node:
	signal changed(pad: bool)

	func _input(event: InputEvent) -> void:
		var now := InputGlyphs.pad
		if event is InputEventJoypadButton and event.pressed:
			now = true
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
			now = true
		elif event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed:
			now = false
		elif event is InputEventMouseMotion and event.relative.length() > 4.0:
			now = false
		if now and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			InputGlyphs.deck = Input.get_joy_name(event.device).to_lower().contains("steam")
		if now != InputGlyphs.pad:
			InputGlyphs.pad = now
			changed.emit(now)


## The device watcher (made and added under `parent` the first time).
static func watch(parent: Node = null) -> DeviceWatch:
	if not is_instance_valid(_watcher):
		_watcher = DeviceWatch.new()
		_watcher.name = "InputGlyphs"
		if parent:
			parent.add_child.call_deferred(_watcher)
	return _watcher


## What to call `action`'s button on the device in use (or on `on_pad`).
static func of(action: String, on_pad: Variant = null) -> String:
	var want_pad: bool = pad if on_pad == null else on_pad
	if not InputMap.has_action(action):
		return ""
	for ev in InputMap.action_get_events(action):
		if want_pad:
			var name := ""
			if ev is InputEventJoypadButton:
				name = PAD_BUTTONS.get(ev.button_index, "")
			elif ev is InputEventJoypadMotion:
				name = PAD_AXES.get(ev.axis, "")
			if name != "":
				return DECK_NAMES.get(name, name) if deck else name
		elif ev is InputEventKey:
			var code: Key = ev.physical_keycode if ev.physical_keycode else ev.keycode
			return KEY_NAMES.get(code, OS.get_keycode_string(code))
		elif ev is InputEventMouseButton:
			return "Click" if ev.button_index == MOUSE_BUTTON_LEFT else "Right-click"
	return ""


## `s` with each bracketed key ("[E]") and "press E" / "hold V" naming the
## button on the device in use. Unchanged on the keyboard.
static func text(s: String, on_pad: Variant = null) -> String:
	var want_pad: bool = pad if on_pad == null else on_pad
	if not want_pad or s == "":
		return s
	var out := _swap(s, _bracket, func(m: RegExMatch) -> String:
		var name := of(PROMPT_KEYS.get(m.get_string(1), ""), true)
		return "[%s]" % name if name != "" else m.get_string(0))
	return _swap(out, _press, func(m: RegExMatch) -> String:
		var name := of(PROMPT_KEYS[m.get_string(2)], true)
		return "%s %s" % [m.get_string(1), name] if name != "" else m.get_string(0))


## `s` with each match of `re` replaced by `fn(match)`, in one pass.
static func _swap(s: String, re: RegEx, fn: Callable) -> String:
	var out := ""
	var at := 0
	for m in re.search_all(s):
		out += s.substr(at, m.get_start() - at) + fn.call(m)
		at = m.get_end()
	return out + s.substr(at)
