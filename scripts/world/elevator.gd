class_name Elevator
extends Node3D
## The way out of a level. Everyone gets in, someone presses the button, and the
## doors have to shut before whatever is chasing the crew gets there. The doors
## shutting is the checkpoint and the seal; the ride covers loading the next wing,
## then carries the crew into the next wing's arrival car (link_to) and opens it.
##
## The origin is the middle of the doorway at floor level and the car extends along
## local +Z: you walk in along +Z. The shell is static and goes under the level's
## `geo` so it is part of the navigation mesh; the door leaves move, so they don't.
## Looks: ArtElevator when the art is in the project, plain greybox otherwise.
## Co-op: the host decides when the button works and when the doors move.

signal button_pressed(by: Node)
## The doors have shut.
signal closed
## The doors are fully open.
signal opened
## The ride is over; the crew is in the destination car, if there is one.
signal arrived

const SIZE := Vector3(2.6, 2.5, 2.2)
const DOOR_H := 2.1
const LEAF_W := 0.62  # each door leaf; together a 1.2 m doorway
const DOORWAY := LEAF_W * 2
const CLOSE_TIME := 2.2
const OPEN_TIME := 1.4
const RIDE_TIME := 3.0

var open_amount := 0.0:
	set(v):
		open_amount = clampf(v, 0.0, 1.0)
		_place_doors()
var is_closing := false
var riding := false
var art: Node3D  # ArtElevator, when available
var button: Interactable
## The other floors' buttons (with art): pressing one does nothing but light it.
var other_buttons: Array[Interactable] = []
## Why the button didn't work, for the HUD. Set by press().
var refusal := ""
## Shows the refusal as a notice when set.
var hud: Node
## The car the crew steps out of after the ride.
var destination: Elevator
var floor_label := ""
var _leaves: Array[AnimatableBody3D] = []
var _tween: Tween
var _light: OmniLight3D


## Builds the car under `parent` (the level), with its shell under `geo`.
static func create(parent: Node3D, geo: Node3D, pos: Vector3, facing_deg: float, label: String, floors: Array = ["1", "B1", "B2", "B3"]) -> Elevator:
	var e := Elevator.new()
	e.name = "Elevator"
	e.position = pos
	e.rotation_degrees.y = facing_deg
	e.floor_label = label
	parent.add_child(e)
	e._build(geo, floors)
	return e


func _build(geo: Node3D, floors: Array) -> void:
	var art_script: Script = load("res://scripts/art/art_elevator.gd") if ResourceLoader.exists("res://scripts/art/art_elevator.gd") else null
	if art_script:
		art = art_script.call("build", self, Vector3.ZERO, 0.0, SIZE, floors)
		art.call("set_floor", floor_label)
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
	_solid(shell, Vector3(DOORWAY, h - DOOR_H, 0.1), Vector3(0, DOOR_H + (h - DOOR_H) / 2, 0.05), steel, show)
	if show:
		Greybox.label(shell, Vector3(0, DOOR_H + 0.2, -0.01), "ELEVATOR  " + floor_label, 40, Color(1.0, 0.45, 0.1), 180)
		_light = OmniLight3D.new()
		_light.position = Vector3(0, h - 0.2, d / 2)
		_light.omni_range = 3.2
		_light.light_energy = 0.9
		_light.light_color = Color(1.0, 0.95, 0.85)
		add_child(_light)
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
	# With art, each floor's button is pressed where it's drawn: only the floor
	# you're going to (the last) takes you there.
	var panel: Node3D = art.get_node_or_null("ButtonPanel") if art else null
	if panel:
		var n := floors.size()
		for i in n:
			var at := panel.transform * Vector3(0.04, -0.04 + (n - 1 - i) * 0.09, -0.03)
			var b := button if i == n - 1 else Interactable.create(self, at, Vector3(0.08, 0.08, 0.06), "Press %s" % floors[i], Color(0.15, 0.15, 0.15), false)
			b.basis = panel.basis
			b.position = at
			if b == button:
				for c in button.get_children():
					if c is CollisionShape3D:
						(c.shape as BoxShape3D).size = Vector3(0.08, 0.08, 0.06)
			else:
				var label: String = floors[i]
				b.used.connect(func(by): _press_other(label, by))
				other_buttons.append(b)
	button.used.connect(press)
	_place_doors()


func _solid(parent: Node3D, box_size: Vector3, pos: Vector3, color: Color, visible_mesh: bool) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box_size
	cs.shape = bs
	body.add_child(cs)
	if visible_mesh:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = box_size
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


## Is this point inside the car (world space)?
func contains(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) < SIZE.x / 2 and l.z > 0.15 and l.z < SIZE.z and l.y > -0.5 and l.y < SIZE.y


## Every living player, and how many of them are in the car.
func headcount() -> Vector2i:
	var total := 0
	var inside := 0
	for p in _players():
		if p.get("health") != null and p.health <= 0.0:
			continue
		total += 1
		if contains(p.global_position):
			inside += 1
	return Vector2i(inside, total)


## Everyone in this elevator's level: this machine's player and its teammates.
## (The nearest ancestor that holds players: a wing's players live in the world.)
func _players() -> Array:
	var all := get_tree().get_nodes_in_group("player")
	var n := get_parent()
	while n:
		var mine := all.filter(func(p): return n.is_ancestor_of(p))
		if not mine.is_empty():
			return mine
		n = n.get_parent()
	return []


## The button: works only when every living player is inside.
func press(by: Node = null) -> bool:
	refusal = ""
	if is_closing or riding or open_amount <= 0.0:
		return false
	var c := headcount()
	var sync := LevelSync.of(self)
	if c.y == 0 or c.x < c.y:
		refusal = "The doors won't close until everyone is inside (%d/%d)." % [c.x, c.y]
		if sync and sync.is_online():
			sync.team_notice(refusal, 3.0)
		elif hud:
			hud.notice(refusal, 3.0)
		return false
	button_pressed.emit(by)
	# In co-op the press reaches the host, which counts heads; then the doors
	# close on every machine together.
	if sync:
		sync.run_on(self, "close")
	else:
		close()
	return true


## Another floor's button: it lights, and goes dark again. Not this trip.
func _press_other(label: String, _by: Node) -> void:
	if art:
		art.call("light_button", label, true)
		get_tree().create_timer(0.6, false).timeout.connect(func():
			if is_instance_valid(art):
				art.call("light_button", label, false))


func _process(_delta: float) -> void:
	for b in other_buttons:
		b.enabled = button.enabled  # the panel works as a whole


## Ride from this car to `other`: the crew steps out of that car when the ride ends.
func link_to(other: Elevator) -> void:
	destination = other


## The ride, once the doors have shut. The next wing loads meanwhile; then every
## player in this car moves to the same spot in the destination car, still facing
## the same way relative to it, and its doors open.
func ride(seconds: float = RIDE_TIME) -> void:
	riding = true
	if art:
		art.call("set_direction", -1)
	var tw := create_tween()
	tw.tween_method(_set_car_light, 1.0, 0.6, seconds * 0.5)
	tw.tween_method(_set_car_light, 0.6, 1.0, seconds * 0.5)
	await tw.finished
	if art:
		art.call("set_direction", 0)
	if destination:
		carry_players_to(destination)
		destination.open()
	riding = false
	arrived.emit()


## Move everyone in this car to the same place in `other`, keeping their facing.
func carry_players_to(other: Elevator) -> void:
	var turn := other.global_basis.get_euler().y - global_basis.get_euler().y
	for p in _players():
		if not contains(p.global_position):
			continue
		var local := to_local(p.global_position)
		p.global_position = other.to_global(local)
		p.rotation.y += turn
		if p is CharacterBody3D:
			p.velocity = Vector3.ZERO


func _set_car_light(scale: float) -> void:
	if art:
		art.call("set_car_light", scale)
	elif _light:
		_light.light_energy = 0.9 * scale
