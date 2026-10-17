class_name Level2Keypad
extends Node3D
## A guard-PIN keypad on the wall: twelve keys you look at and press, and a small
## screen above them. Nothing opens on your screen; you stand at the door and type.
##
## Co-op: a key press goes to the host, which plays it on every machine in order
## (the level's `_pad_key` event), so everyone sees the same digits and the same answer.

## Host: someone pressed `key` ("0".."9", "C" to clear, "E" to enter).
signal key_pressed(key: String, by: Node)

const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "E"]
const KEY_SIZE := Vector3(0.055, 0.055, 0.025)
const STEP := 0.07
const SCREEN_IDLE := Color(0.55, 0.85, 0.55)

## Which door this pad works: "office" or "exit".
var mode := ""
## What the screen says while nobody is typing.
var idle_text := "ENTER GUARD PIN"
var code := ""
var keys := {}
var screen: Label3D


## A pad on a wall at `pos`, its face toward local +Z turned by `facing_deg`.
static func mount(parent: Node3D, pos: Vector3, facing_deg: float, pad_mode: String, idle: String = "ENTER GUARD PIN") -> Level2Keypad:
	var k := Level2Keypad.new()
	k.name = "Keypad_" + pad_mode
	k.mode = pad_mode
	k.idle_text = idle
	k.position = pos
	k.rotation_degrees.y = facing_deg
	parent.add_child(k)
	k._build()
	return k


func _build() -> void:
	Greybox.panel(self, Vector3(0, 0.02, -0.015), Vector3(0.26, 0.42, 0.02), Color(0.13, 0.13, 0.12))
	Greybox.panel(self, Vector3(0, 0.15, -0.002), Vector3(0.22, 0.09, 0.006), Color(0.03, 0.05, 0.03))
	screen = Label3D.new()
	screen.name = "Screen"
	screen.font_size = 18
	screen.pixel_size = 0.0006
	screen.width = 0.2 / screen.pixel_size
	screen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.outline_size = 0
	screen.position = Vector3(0, 0.15, 0.003)
	screen.modulate = SCREEN_IDLE
	add_child(screen)
	for i in KEYS.size():
		var key: String = KEYS[i]
		var at := Vector3((i % 3 - 1) * STEP, 0.04 - (i / 3) * STEP, 0.0)
		var color := Color(0.6, 0.15, 0.1) if key == "C" else (Color(0.15, 0.45, 0.2) if key == "E" else Color(0.42, 0.42, 0.4))
		var b := Interactable.create(self, at, KEY_SIZE, _key_prompt(key), color)
		b.name = "Key_" + key
		var face := Label3D.new()
		face.text = "CLR" if key == "C" else ("ENT" if key == "E" else key)
		face.font_size = 28 if key.is_valid_int() else 16
		face.pixel_size = 0.0008
		face.outline_size = 0
		face.modulate = Color(0.95, 0.95, 0.9)
		face.position = Vector3(0, 0, KEY_SIZE.z / 2 + 0.001)
		b.add_child(face)
		b.used.connect(func(p): key_pressed.emit(key, p))
		keys[key] = b
	show_text(idle_text)


static func _key_prompt(key: String) -> String:
	match key:
		"C":
			return "Clear"
		"E":
			return "Enter"
	return "Press " + key


## Every machine: a digit or Clear went down. (Enter is the level's: see take_code().)
func press(key: String) -> void:
	if key == "C":
		code = ""
		show_text(idle_text)
	elif code.length() < 4:
		code += key
		show_text(code + "_".repeat(4 - code.length()))


## Enter: what was typed, and the pad is ready for the next try.
func take_code() -> String:
	var entered := code
	code = ""
	return entered


func show_text(text: String, color: Color = SCREEN_IDLE) -> void:
	screen.text = text
	screen.modulate = color
