class_name ElevatorStall
extends Node3D
## E9: an elevator that can stick between floors. Only the run's own choices stall
## it, never chance: the level arms it (`arm`, from a sync.event), or gives it a
## condition (`when`, e.g. its fuse pulled for another puzzle), checked as the doors
## shut. A stalled ride jolts to a stop part-way (the seed picks where), the car
## light drops and the buttons do nothing. Two ways out:
##   - the roof: push the hatch open, get up through it (Movement: a boost or the
##     handrail), climb the shaft's ladder and pull the landing door's release;
##   - the doors: Movement's two-person pry, which calls `release("pry")`.
## Either way the ride ends as usual for everyone, in the car, on its roof or on the
## ladder: the crew is carried into the destination car and its doors open.
## Needs 5.6 m clear above the car for the shaft. Co-op: as every kit piece.

## Every machine: the ride stuck (true) or got going again.
signal stalled_changed(stalled: bool)
## Every machine: the crew got out, `how` "hatch" or "pry".
signal released_by(how: String)
signal _released

## Where the hatch is in the car's roof: its centre (x, z) and its size. A 1.0 m
## square, the least every body fits through.
const HATCH := Rect2(0.25, 1.1, 1.0, 1.0)
## From the car's roof to the landing door's sill above it.
const TO_LANDING := 3.0
const SHAFT_H := 5.5

var elevator: Elevator
var armed := false
## Calls that say "stall now", checked on every machine as the ride starts.
var conditions: Array[Callable] = []
## Stall once, then ride normally after.
var once := true
var stalled := false
var hatch: ItemLock
var door_release: ItemLock
## Of the way from one floor to the next where it sticks (0..1).
var stop_at := 0.5
var _hatch_frame: Node3D
## Movement's pieces, once linked (link_pry, link_hatch_climb).
var pry: Node
var hatch_climb: Node


static func attach(e: Elevator, geo: Node3D, key := "") -> ElevatorStall:
	var s := ElevatorStall.new()
	s.name = "Stall"
	s.elevator = e
	s.stop_at = 0.3 + 0.4 * KitPiece.seeded(key if key != "" else "stall_" + e.floor_label, 100) / 100.0
	e.add_child(s)
	e.stall = s
	s._build(geo)
	return s


## Every machine: the next ride stalls.
func arm() -> void:
	armed = true


## Stall the next ride if `condition` says so as it starts.
func when(condition: Callable) -> void:
	conditions.append(condition)


func should_stall() -> bool:
	return armed or conditions.any(func(c: Callable): return c.call())


## The car's roof, in the elevator's space.
func roof_y() -> float:
	return Elevator.SIZE.y + 0.1


## Movement's two-person pry (PryDoors): on only while stuck; its `pried_open`
## (every machine) gets the crew out.
func link_pry(p: Node) -> void:
	pry = p
	p.set("enabled", stalled)
	p.connect("pried_open", func(): release("pry"))


## Movement's climb up through the hatch (a MovementVolume): active only once the
## hatch is open and the car's stuck.
func link_hatch_climb(v: Node) -> void:
	hatch_climb = v
	_sync_links()


## Where Movement's hatch climb goes: the rim's centre, and the spot on the roof it
## lifts you to (global).
func hatch_rim() -> Vector3:
	return elevator.to_global(Vector3(HATCH.position.x, Elevator.SIZE.y + 0.1, HATCH.position.y))


func roof_spot() -> Vector3:
	return elevator.to_global(Vector3(-0.6, roof_y() + 0.05, 1.0))


func _sync_links() -> void:
	if is_instance_valid(pry):
		pry.set("enabled", stalled)
	if is_instance_valid(hatch_climb):
		hatch_climb.set("active", stalled and hatch.is_open)


## Every machine: the crew is out (the release, or the pry finishing).
func release(how: String) -> void:
	if not stalled:
		return
	released_by.emit(how)
	_released.emit()


## Elevator.ride, on every machine: the ride as far as it sticks, then wait.
func stall_ride(from: int, to: int, seconds: float) -> void:
	var e := elevator
	var at := lerpf(float(from), float(to), stop_at)
	if e.art and to != from:
		var count := e.create_tween()
		count.tween_method(func(f: float): e.art.call("set_floor", Elevator.label_of(roundi(f))), float(from), at, seconds * stop_at)
	await e.get_tree().create_timer(seconds * stop_at, false).timeout
	stalled = true
	if once:
		armed = false
		conditions.clear()
	e._set_car_light(0.35)
	if e.get_parent() is Node3D:
		Sfx.play(e, "clunk", Vector3(0, Elevator.SIZE.y, Elevator.SIZE.z / 2))
	hatch.enabled = not hatch.is_open
	door_release.enabled = true
	_sync_links()
	stalled_changed.emit(true)
	await _released
	_gather()
	stalled = false
	door_release.enabled = false
	hatch.enabled = false
	_sync_links()
	e._set_car_light(1.0)
	stalled_changed.emit(false)


## Everyone up in the shaft steps back into the car, so the ride carries them too.
func _gather() -> void:
	var e := elevator
	var i := 0
	for p in e._players():
		var l := e.to_local(p.global_position)
		var in_shaft := absf(l.x) < Elevator.SIZE.x / 2 + 0.3 and l.z > -0.3 and l.z < Elevator.SIZE.z + 0.2 and l.y > Elevator.SIZE.y - 0.2 and l.y < Elevator.SIZE.y + SHAFT_H + 2.0
		if in_shaft:
			p.global_position = e.to_global(Vector3(-0.6 + 0.4 * (i % 4), 0.1, 0.8 + 0.4 * (i / 4)))
			if p is CharacterBody3D:
				p.velocity = Vector3.ZERO
			i += 1


func _build(geo: Node3D) -> void:
	var e := elevator
	var w := Elevator.SIZE.x
	var h := Elevator.SIZE.y
	var d := Elevator.SIZE.z
	var roof := roof_y()
	var steel := Color(0.5, 0.52, 0.55)
	# The shaft's geometry is static: it goes in geo, placed like the car's shell.
	var shaft := Node3D.new()
	shaft.name = "StallShaft_" + e.floor_label
	geo.add_child(shaft)
	shaft.global_transform = e.global_transform
	# The car's solid ceiling makes way for one with a hatch hole in it.
	var shell: Node3D = null
	for n in geo.get_children():
		if String(n.name).contains("ElevatorShell") and (n as Node3D).global_transform.is_equal_approx(e.global_transform):
			shell = n
	for n in (shell.get_children() if shell else []):
		if n is StaticBody3D and n.position.is_equal_approx(Vector3(0, h + 0.05, d / 2)):
			n.queue_free()
	_hide_art_ceiling(h, d)
	var x0 := HATCH.position.x - HATCH.size.x / 2.0
	var x1 := HATCH.position.x + HATCH.size.x / 2.0
	var z0 := HATCH.position.y - HATCH.size.y / 2.0
	var z1 := HATCH.position.y + HATCH.size.y / 2.0
	var left := -w / 2.0 - 0.1
	var right := w / 2.0 + 0.1
	var back := d + 0.05
	_slab(shaft, Rect2(left, -0.05, x0 - left, back + 0.05), h, steel)  # beside the hatch, towards -x
	_slab(shaft, Rect2(x1, -0.05, right - x1, back + 0.05), h, steel)  # beside it, towards +x
	_slab(shaft, Rect2(x0, -0.05, x1 - x0, z0 + 0.05), h, steel)  # in front of it
	_slab(shaft, Rect2(x0, z1, x1 - x0, back - z1), h, steel)  # behind it
	# The shaft's walls, above the car.
	var wall_y := roof + SHAFT_H / 2.0
	Greybox.box(shaft, Vector3(left - 0.1, wall_y, d / 2), Vector3(0.2, SHAFT_H, d + 0.6), steel.darkened(0.4), "ShaftWallL")
	Greybox.box(shaft, Vector3(right + 0.1, wall_y, d / 2), Vector3(0.2, SHAFT_H, d + 0.6), steel.darkened(0.4), "ShaftWallR")
	Greybox.box(shaft, Vector3(0, wall_y, back + 0.15), Vector3(w + 0.6, SHAFT_H, 0.2), steel.darkened(0.4), "ShaftWallBack")
	# The landing above: its sill, its shut doors, the wall round them.
	var sill := roof + TO_LANDING
	Greybox.box(shaft, Vector3(0, sill - 0.05, -0.15), Vector3(w + 0.4, 0.1, 0.3), steel, "LandingSill")
	Greybox.box(shaft, Vector3(0, sill + Elevator.DOOR_H / 2.0, -0.25), Vector3(Elevator.DOORWAY, Elevator.DOOR_H, 0.06), steel.lightened(0.15), "LandingDoors")
	Greybox.box(shaft, Vector3(0, (roof + sill) / 2.0, -0.25), Vector3(w + 0.4, sill - roof, 0.2), steel.darkened(0.4), "ShaftFront")
	for sx in [-1.0, 1.0]:
		var side := (w + 0.4 - Elevator.DOORWAY) / 2.0
		Greybox.box(shaft, Vector3(sx * (Elevator.DOORWAY / 2.0 + side / 2.0), sill + (SHAFT_H - TO_LANDING) / 2.0, -0.25), Vector3(side, SHAFT_H - TO_LANDING, 0.2), steel.darkened(0.4))
	# The ladder up the left wall, near the front, to the landing.
	Traversal.climbable(shaft, Vector3(left, roof, 0.45), Vector3(left, sill + 0.6, 0.45), Vector3(1, 0, 0), 0.6)
	# The hatch: its lid is the piece. Pushed open, the lid swings up and away.
	hatch = ItemLock.make(e, "hatch", Vector3(HATCH.position.x, h + 0.05, HATCH.position.y), Vector3(HATCH.size.x, 0.1, HATCH.size.y), "",
		KitWords.say("hatch_open"), "")
	hatch.sound = "hinge" if Sfx.KINDS.has("hinge") else "clunk"
	hatch.kind = "lever"
	hatch.enabled = false
	_hatch_frame = Node3D.new()
	_hatch_frame.name = "Lid"
	hatch.add_child(_hatch_frame)
	KitPiece._box(_hatch_frame, Vector3.ZERO, Vector3(HATCH.size.x - 0.04, 0.04, HATCH.size.y - 0.04), steel.darkened(0.2))
	KitPiece._box(_hatch_frame, Vector3(0, -0.03, 0), Vector3(0.3, 0.02, 0.05), Color(0.1, 0.1, 0.1))  # its handle
	hatch.opened.connect(func(_peer):
		for c in hatch.get_children():
			if c is CollisionShape3D:
				c.disabled = true
		_hatch_frame.position = Vector3(HATCH.size.x / 2.0 + 0.1, 0.5, 0)
		_hatch_frame.rotation_degrees.z = 90
		_sync_links())
	# The landing door's release, on the shaft side of the doors, by the ladder.
	door_release = ItemLock.make(e, "door_release", Vector3(-Elevator.DOORWAY / 2.0 + 0.1, sill + 1.1, -0.18), Vector3(0.2, 0.3, 0.1), "",
		KitWords.say("door_release"), "")
	door_release.sound = "lever"
	door_release.enabled = false
	KitPiece._box(door_release, Vector3.ZERO, Vector3(0.05, 0.22, 0.04), Color(0.75, 0.6, 0.1))
	door_release.opened.connect(func(_peer):
		door_release.is_open = false  # it springs back: a later stall can use it again
		release("hatch"))


## A slab of the car's ceiling over `rect` (x, z), its top at the roof.
func _slab(parent: Node3D, rect: Rect2, h: float, color: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var c := rect.get_center()
	Greybox.box(parent, Vector3(c.x, h + 0.05, c.y), Vector3(rect.size.x, 0.1, rect.size.y), color, "CarRoof")


## The art car's ceiling (one plate) gives way to the greybox one with the hatch;
## its light panel shrinks out of the hatch's way.
func _hide_art_ceiling(h: float, d: float) -> void:
	var art := elevator.art
	if art == null:
		return
	for n in art.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.position.is_equal_approx(Vector3(0, h + 0.025, d / 2)):
			m.visible = false
		elif m.position.is_equal_approx(Vector3(0, h - 0.01, d / 2)):
			m.scale.x = 0.55
			m.position.x = -0.35
