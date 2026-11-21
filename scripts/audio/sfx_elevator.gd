class_name SfxElevator
extends Node
## An elevator's sounds, from what its car is doing (Elevator.open_amount, is_closing,
## riding), which every machine plays out together: the bell and the door motor as the
## doors part, the motor as they close and a clunk as they meet, then the brake letting
## go, the hoist humming through the shaft with the cables groaning now and then, and
## the brake catching at the floor.

## Cable groans while riding: one every this many seconds, give or take.
const CREAK_EVERY := Vector2(0.9, 2.0)

var lift: Elevator
## The ride's loop, while it rides.
var ride_loop: AudioStreamPlayer3D
var _open := 0.0
var _closing := false
var _riding := false
var _creak_in := 0.0


static func attach(e: Elevator) -> SfxElevator:
	var s := SfxElevator.new()
	s.name = "Sounds"
	s.lift = e
	e.add_child(s)
	return s


func _ready() -> void:
	_open = lift.open_amount
	_riding = lift.riding


func _process(delta: float) -> void:
	if not is_instance_valid(lift):
		return
	var doorway := Vector3(0, 1.2, 0.1)
	var inside := Vector3(0, 1.4, Elevator.SIZE.z / 2)
	var now := lift.open_amount
	if _open <= 0.0 and now > 0.0 and now < 1.0:
		_play("lift_ding", doorway)  # the car is here
		_play("door_motor", doorway)
	if lift.is_closing and not _closing and now > 0.0:
		_play("door_motor", doorway)
	if _open > 0.0 and now <= 0.0 and _closing:
		_play("clunk", doorway)  # the leaves meet
	_open = now
	_closing = lift.is_closing
	if lift.riding and not _riding:
		_play("lift_thunk", inside)  # the brake lets go
		ride_loop = Sfx.loop(lift, "lift_ride", inside)
		_creak_in = randf_range(CREAK_EVERY.x, CREAK_EVERY.y) * 0.5
	elif _riding and not lift.riding:
		_play("lift_thunk", inside)  # and catches, at the floor
		if is_instance_valid(ride_loop):
			ride_loop.queue_free()
		ride_loop = null
	_riding = lift.riding
	if _riding:
		_creak_in -= delta
		if _creak_in <= 0.0:
			_creak_in = randf_range(CREAK_EVERY.x, CREAK_EVERY.y)
			_play("cable_creak", inside + Vector3(randf_range(-1, 1), 1.0, 0))


func _play(kind: String, local: Vector3) -> void:
	Sfx.play(lift, kind, local)
