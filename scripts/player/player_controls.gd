class_name PlayerControls
extends RefCounted
## One physics tick of player intent. The local player fills it from the
## keyboard; a networked or test player has it written from outside. The
## controller only ever reads this, never `Input`, so the same inputs replay
## the same movement on every machine.

## Movement stick: x is right, y is back (the `Input.get_vector` convention).
var move := Vector2.ZERO
var sprint := false
var crouch := false
## Edge: set when jump is pressed, cleared by the controller once it is used.
var jump := false
## Edge, like jump: sit down on the floor, or stand back up.
var sit := false
## Sprint pressed on a gamepad (L3) stays on until you stop moving.
var _sprint_latched := false


## Fill from the keyboard or a gamepad. `locked` (a terminal or menu has focus) gives no input.
func read_local(locked: bool) -> void:
	if locked:
		move = Vector2.ZERO
		sprint = false
		crouch = false
		_sprint_latched = false
		return
	move = PadInput.move_vector()
	if Input.is_action_just_pressed("sprint") and InputGlyphs.pad:
		_sprint_latched = true
	if move.length() < 0.2:
		_sprint_latched = false
	sprint = _sprint_latched or Input.is_action_pressed("sprint")
	crouch = Input.is_action_pressed("crouch")
	jump = jump or Input.is_action_just_pressed("jump")
	sit = sit or Input.is_action_just_pressed("sit")


## Compact form for sending over the network.
func pack() -> Array:
	return [move.x, move.y, sprint, crouch, jump]


func unpack(data: Array) -> void:
	move = Vector2(data[0], data[1])
	sprint = data[2]
	crouch = data[3]
	jump = jump or data[4]
