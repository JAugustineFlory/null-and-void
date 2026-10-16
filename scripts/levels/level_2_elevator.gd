class_name Level2Elevator
extends Node3D
## A stand-in for the shared elevator (scripts/world/elevator.gd, coming from the
## Playtest fixes thread) with the same idea: a car with sliding doors, a button
## inside that works only when every living player is in the car, and a `closed`
## signal once the doors meet. Swap it for the shared component when that lands.
##
## Looks: ArtElevator when the art is in the project, plain greybox otherwise.
## Like ArtElevator, the origin is the middle of the doorway at floor level and
## the car extends along local +Z (you walk in along +Z).

signal button_pressed(by: Node)
signal closed
signal opened
## Fired when a ride ends here and the doors are about to open (the shared elevator
## moves players car to car; this stub only declares it).
signal arrived

const SIZE := Vector3(2.6, 2.5, 2.2)
const DOOR_H := 2.1
const LEAF_W := 0.62  # each door leaf; together a 1.2 m doorway
const CLOSE_TIME := 2.2
const OPEN_TIME := 1.4

var open_amount := 0.0:
	set(v):
		open_amount = clampf(v, 0.0, 1.0)
		_place_doors()
var is_closing := false
var art: Node3D  # ArtElevator, when available
var button: Interactable
## Why the button didn't work, for the HUD. Set by press().
var refusal := ""
var _leaves: Array[AnimatableBody3D] = []
var _tween: Tween


## Builds the car under `parent` (the level). The shell is static and goes under
## `geo` so it's part of the navigation mesh; the doors move, so they don't.
static func create(parent: Node3D, geo: Node3D, pos: Vector3, facing_deg: float, floor_label: String, floors: Array = ["1", "B1", "B2", "B3"]) -> Level2Elevator:
	var e := Level2Elevator.new()
	e.name = "Elevator"
	e.position = pos
	e.rotation_degrees.y = facing_deg
	parent.add_child(e)
	e._build(geo, floor_label, floors)
	return e


func _build(geo: Node3D, floor_label: String, floors: Array) -> void:
	var art_script: Script = load("res://scripts/art/art_elevator.gd") if ResourceLoader.exists("res://scripts/art/art_elevator.gd") else null
	if art_script:
		art = art_script.call("build", self, Vector3.ZERO, 0.0, SIZE, floors)
		art.call("set_floor", floor_label)
	# Collision shell: floor, ceiling, back, sides, and the front wall around the doorway.
	var w := SIZE.x
	var h := SIZE.y
	var d := SIZE.z
	var shell := Node3D.new()
	shell.name = "ElevatorShell"
	geo.add_child(shell)
	shell.global_transform = global_transform
	var steel := Color(0.55, 0.57, 0.6)
	var show := art == null
	_solid(shell, Vector3(w + 0.2, 0.1, d + 0.1), Vector3(0, -0.05, d / 2), steel.darkened(0.6), show)
	_solid(shell, Vector3(w + 0.2, 0.1, d + 0.1), Vector3(0, h + 0.05, d / 2), steel, show)
	_solid(shell, Vector3(w + 0.2, h, 0.1), Vector3(0, h / 2, d + 0.05), steel, show)
	for sx in [-1, 1]:
		_solid(shell, Vector3(0.1, h, d), Vector3(sx * (w / 2 + 0.05), h / 2, d / 2), steel, show)
		var jamb := w / 2 - LEAF_W + 0.02
		_solid(shell, Vector3(jamb, h, 0.1), Vector3(sx * (w / 2 - jamb / 2), h / 2, 0.05), steel, show)
	_solid(shell, Vector3(LEAF_W * 2, h - DOOR_H, 0.1), Vector3(0, DOOR_H + (h - DOOR_H) / 2, 0.05), steel, show)
	if show:
		Greybox.label(shell, Vector3(0, DOOR_H + 0.2, -0.01), "ELEVATOR  " + floor_label, 40, Color(1.0, 0.45, 0.1), 180)
	# Door leaves: they block when shut.
	for sx in [-1, 1]:
		var leaf := AnimatableBody3D.new()
		leaf.name = "Leaf"
		leaf.sync_to_physics = false
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(LEAF_W, DOOR_H, 0.06)
		cs.shape = bs
		leaf.add_child(cs)
		if show:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = bs.size
			mi.mesh = bm
			mi.material_override = Greybox.mat(steel.lightened(0.15), 0.4, 0.5)
			leaf.add_child(mi)
		leaf.set_meta("side", sx)
		add_child(leaf)
		_leaves.append(leaf)
	# The button panel inside, on the right as you walk in.
	button = Interactable.create(self, Vector3(-(w / 2 - 0.08), 1.15, 0.45), Vector3(0.04, 0.3, 0.16), "Press %s" % floors[floors.size() - 1], Color(0.15, 0.15, 0.15), show)
	button.used.connect(press)
	_place_doors()


func _solid(parent: Node3D, size: Vector3, pos: Vector3, color: Color, visible_mesh: bool) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	if visible_mesh:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = Greybox.mat(color, 0.3, 0.6)
		body.add_child(mi)
	parent.add_child(body)


func _place_doors() -> void:
	for leaf in _leaves:
		var sx: int = leaf.get_meta("side")
		leaf.position = Vector3(sx * (LEAF_W / 2 + open_amount * (LEAF_W - 0.04)), DOOR_H / 2, 0.11)
	if art:
		art.set("open_amount", open_amount)


func open(instant: bool = false) -> void:
	is_closing = false
	if _tween:
		_tween.kill()
	if instant:
		open_amount = 1.0
		opened.emit()
		return
	_tween = create_tween()
	_tween.tween_property(self, "open_amount", 1.0, OPEN_TIME * (1.0 - open_amount)).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(opened.emit)


## Is this point inside the car (world space)?
func contains(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) < SIZE.x / 2 and l.z > 0.15 and l.z < SIZE.z and l.y > -0.5 and l.y < SIZE.y


## How many living players are in the car.
func headcount() -> int:
	var n := 0
	for p in get_tree().get_nodes_in_group("player"):
		if (p.get("health") == null or p.health > 0.0) and contains(p.global_position):
			n += 1
	return n


## The button: works only when every living player is inside.
func press(by: Node = null) -> bool:
	refusal = ""
	if is_closing or open_amount <= 0.0:
		return false
	for p in get_tree().get_nodes_in_group("player"):
		if p.get("health") != null and p.health <= 0.0:
			continue
		if not contains(p.global_position):
			refusal = "The doors won't close until everyone is inside."
			return false
	button_pressed.emit(by)
	close()
	return true


func close() -> void:
	is_closing = true
	if _tween:
		_tween.kill()
	if art:
		art.call("light_button", button.prompt.trim_prefix("Press "), true)
	_tween = create_tween()
	_tween.tween_property(self, "open_amount", 0.0, CLOSE_TIME * open_amount).set_trans(Tween.TRANS_LINEAR)
	_tween.tween_callback(func():
		is_closing = false
		closed.emit())
