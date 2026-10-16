class_name Elevator
extends Node3D
## The way out of a level. Everyone gets in, someone presses the button, and the
## doors have to close before whatever is chasing the crew gets there.
## The doors closing is the checkpoint; the ride covers loading the next wing.
## Built facing +Z: the doors are at z = 0 and the car goes back to z = -DEPTH.
## Co-op: the host decides when the button works and when the doors move.

signal doors_opened
## Everyone is in and the doors have shut: checkpoint and seal here.
signal doors_closed
## The ride is over.
signal arrived
## Someone pressed the button with players still outside.
signal waiting(inside: int, total: int)

const WIDTH := 2.4
const DEPTH := 2.4
const HEIGHT := 2.6
const DOOR_WIDTH := 1.6
const DOOR_TIME := 0.9
const RIDE_TIME := 3.0

var doors_open := false
var riding := false
var button: Interactable
var hud: Node
var _inside: Area3D
var _doors: Array[Node3D] = []
var _light: OmniLight3D


static func create(parent: Node, at: Vector3, facing_deg: float = 0.0) -> Elevator:
	var e := Elevator.new()
	e.position = at
	e.rotation_degrees.y = facing_deg
	parent.add_child(e)
	return e


func _ready() -> void:
	var steel := Color(0.55, 0.56, 0.58)
	var hw := WIDTH / 2
	Greybox.box(self, Vector3(0, -0.05, -DEPTH / 2), Vector3(WIDTH, 0.1, DEPTH), Color(0.25, 0.25, 0.27), "CarFloor")
	Greybox.box(self, Vector3(0, HEIGHT + 0.05, -DEPTH / 2), Vector3(WIDTH, 0.1, DEPTH), steel, "CarCeiling")
	Greybox.box(self, Vector3(-hw - 0.05, HEIGHT / 2, -DEPTH / 2), Vector3(0.1, HEIGHT, DEPTH), steel, "CarWallW")
	Greybox.box(self, Vector3(hw + 0.05, HEIGHT / 2, -DEPTH / 2), Vector3(0.1, HEIGHT, DEPTH), steel, "CarWallE")
	Greybox.box(self, Vector3(0, HEIGHT / 2, -DEPTH - 0.05), Vector3(WIDTH, HEIGHT, 0.1), steel, "CarWallBack")
	# The front wall, either side of the doorway and above it.
	var side_w := (WIDTH - DOOR_WIDTH) / 2
	for s in [-1.0, 1.0]:
		Greybox.box(self, Vector3(s * (DOOR_WIDTH / 2 + side_w / 2), HEIGHT / 2, 0.05), Vector3(side_w, HEIGHT, 0.1), steel, "CarFront")
	Greybox.box(self, Vector3(0, 2.3 + (HEIGHT - 2.3) / 2, 0.05), Vector3(DOOR_WIDTH, HEIGHT - 2.3, 0.1), steel, "CarLintel")
	Greybox.label(self, Vector3(0, 2.45, 0.11), "ELEVATOR", 40, Color(0.9, 0.85, 0.6))

	# Two doors that part in the middle.
	for s in [-1.0, 1.0]:
		var door := Node3D.new()
		door.position = Vector3(s * DOOR_WIDTH / 4, 0, 0.12)
		door.set_meta("closed_x", door.position.x)
		add_child(door)
		Greybox.box(door, Vector3(0, 1.15, 0), Vector3(DOOR_WIDTH / 2, 2.3, 0.06), Color(0.7, 0.7, 0.72), "ElevatorDoor")
		_doors.append(door)

	button = Interactable.create(self, Vector3(hw - 0.03, 1.2, -0.45), Vector3(0.04, 0.14, 0.14), "Press the button", Color(1.0, 0.6, 0.1))
	button.used.connect(press)

	_inside = Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH - 0.2, 2.0, DEPTH - 0.2)
	shape.shape = box
	shape.position = Vector3(0, 1.0, -DEPTH / 2)
	_inside.add_child(shape)
	add_child(_inside)

	_light = OmniLight3D.new()
	_light.position = Vector3(0, HEIGHT - 0.2, -DEPTH / 2)
	_light.omni_range = 3.2
	_light.light_energy = 0.9
	_light.light_color = Color(1.0, 0.95, 0.85)
	add_child(_light)


func open_doors() -> void:
	if doors_open:
		return
	doors_open = true
	var tw := create_tween().set_parallel()
	for d in _doors:
		var s := signf(d.get_meta("closed_x"))
		tw.tween_property(d, "position:x", d.get_meta("closed_x") + s * DOOR_WIDTH / 2, DOOR_TIME).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	doors_opened.emit()


func close_doors() -> void:
	if not doors_open:
		return
	doors_open = false
	var tw := create_tween().set_parallel()
	for d in _doors:
		tw.tween_property(d, "position:x", d.get_meta("closed_x"), DOOR_TIME).set_trans(Tween.TRANS_QUAD)
	await tw.finished


## Every living player, and how many of them are in the car.
func headcount() -> Vector2i:
	var total := 0
	var inside := 0
	for p in get_tree().get_nodes_in_group("player"):
		if p.get_viewport() != get_viewport() or p.get("health") != null and p.health <= 0.0:
			continue
		total += 1
		if _inside.overlaps_body(p):
			inside += 1
	return Vector2i(inside, total)


func everyone_inside() -> bool:
	var c := headcount()
	return c.y > 0 and c.x == c.y


## The button: only works once the whole crew is in.
func press(_p: Node = null) -> void:
	if riding or not doors_open:
		return
	var c := headcount()
	if c.x < c.y or c.y == 0:
		waiting.emit(c.x, c.y)
		if hud:
			hud.notice("The doors won't close until everyone is inside (%d/%d)." % [c.x, c.y], 3.0)
		return
	riding = true
	button.enabled = false
	await close_doors()
	doors_closed.emit()
	# The ride: a low hum and a flicker while the next wing loads behind the walls.
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 0.5, RIDE_TIME * 0.5)
	tw.tween_property(_light, "light_energy", 0.9, RIDE_TIME * 0.5)
	await tw.finished
	riding = false
	arrived.emit()
