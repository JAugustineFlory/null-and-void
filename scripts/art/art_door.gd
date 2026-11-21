class_name ArtDoor
extends Node3D
## A hinged door's hardware, hung on the leaf so it swings with it: lever handles
## on both faces (with a key cylinder under each), three hinge knuckles, and on a
## stair door a push bar on the stairwell side, steel kick plates and an overhead
## closer whose arm folds against the frame as the door swings. Visual only:
## nothing here collides, and the door's collider and pose stay Door's.
##
## It follows the door's `moved` phases, so it plays on every machine: "unlatch"
## presses the levers (and the push bar) down, "swing" lets them go as the leaf
## moves. A shove (no "unlatch") leaves the handles alone. Door._ready furnishes
## every door; a stairwell's painted copies of its door get the same look, shut
## for good (furnish_copy).

const STEEL := Color(0.64, 0.65, 0.66)
const DARK_STEEL := Color(0.3, 0.31, 0.32)
const CLOSER_GREY := Color(0.55, 0.56, 0.55)
## Lever handles sit this high off the floor, as door hardware does.
const HANDLE_Y := 1.0
const LEVER_PRESS := 38.0  # degrees a lever turns down under a hand
const BAR_PRESS := 0.022  # metres a push bar travels in
## The closer's two arms: main arm off the spindle, forearm to the shoe on the frame.
const MAIN_ARM := 0.24
const FOREARM := 0.28

var door: Door
var levers: Array[Node3D] = []
var push_bar: Node3D
var press := 0.0:
	set(v):
		press = v
		_pose_press()

var _lever_axes: Array[Vector3] = []
var _bar_rest := Vector3.ZERO
var _bar_in := Vector3.ZERO
var _tween: Tween
# The closer: its spindle on the leaf, the shoe on the frame (in the door's
# parent's space, so it stays put as the leaf swings), its arms and its plane.
var _closer := false
var _spindle := Vector3.ZERO
var _shoe_xf := Transform3D()  # the shoe on the frame, in the leaf's parent's space
var _away := Vector3.ZERO  # the arms' elbow folds out this way from the leaf
var _closer_rest_u := Vector3.ZERO  # how far along the leaf the shoe sits, shut
var _main: Node3D
var _fore: Node3D
var _shoe: Node3D
var _last_swing := -1.0


## Hang the hardware on `d` (once; sliding doors have none yet). Returns it, or null.
static func furnish(d: Door) -> ArtDoor:
	if not is_instance_valid(d) or not d.is_hinged() or d.has_node("Hardware"):
		return null
	var art := ArtDoor.new()
	art.name = "Hardware"
	art.door = d
	d.add_child(art)
	var stair := d.has_meta("stairwell")
	art._build(d.size, d.hinge, d.swing_deg, stair)
	_hide_stripe(d, d.size)
	if art._closer:
		art._anchor_shoe()
		art._pose_closer()
	art.set_notify_transform(art._closer)  # the arms follow the leaf, however it's moved
	d.moved.connect(art._on_moved)
	return art


## A stairwell's painted copy of its door (Stairwell._copy_door): the same
## hardware, shut for good.
static func furnish_copy(body: Node3D, size: Vector3, hinge: Vector3, swing_deg: float) -> ArtDoor:
	var art := ArtDoor.new()
	art.name = "Hardware"
	body.add_child(art)
	art._build(size, hinge, swing_deg, true)
	_hide_stripe(body, size)
	if art._closer:
		art._shoe_xf = body.transform.translated_local(art._shoe_rest())
		art._pose_closer(body.transform)
	return art


## The greybox hazard stripe across the leaf (Door.create) goes once it has real
## hardware to say it's a door.
static func _hide_stripe(body: Node3D, size: Vector3) -> void:
	for c in body.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.mesh is BoxMesh and is_equal_approx((mi.mesh as BoxMesh).size.y, 0.12) and is_equal_approx(mi.position.y, size.y * 0.25):
			mi.visible = false


## The arms follow the leaf as it moves, in the same frame (a tween moves it
## after nodes have processed, so this is where its new pose is first seen).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and _closer and door and door.swing != _last_swing:
		_pose_closer()


# --- Building -------------------------------------------------------------------

## The leaf's frame: `u` across it, `t` through it, y up; `hs` which end of `u`
## the hinge is on, `fs` which face it swings toward.
func _build(size: Vector3, hinge: Vector3, swing_deg: float, stair: bool) -> void:
	var wide_x := size.x >= size.z
	var u := Vector3.RIGHT if wide_x else Vector3.BACK
	var t := Vector3.BACK if wide_x else Vector3.RIGHT
	var w := maxf(size.x, size.z)
	var th := minf(size.x, size.z)
	var hs := signf(hinge.dot(u))
	if hs == 0.0:
		hs = 1.0
	# The face the leaf swings toward: where its middle ends up, opened.
	var open_mid: Vector3 = hinge + Basis(Vector3.UP, deg_to_rad(swing_deg)) * -hinge
	var fs := signf(open_mid.dot(t))
	if fs == 0.0:
		fs = 1.0
	var floor_y := -size.y / 2.0
	var hy := floor_y + HANDLE_Y
	var latch_u := -hs * (w / 2.0 - 0.065)

	var m := ArtMesh.new()
	# Hinge knuckles on the hinge edge.
	for y: float in [size.y / 2.0 - 0.2, 0.0, floor_y + 0.25]:
		var k := u * hs * (w / 2.0 + 0.006) + Vector3.UP * y
		m.rod(k - Vector3.UP * 0.05, k + Vector3.UP * 0.05, 0.012, STEEL, 8, true)
	# A lever on each face, except a stair door's stairwell side, which has its push bar.
	for f: float in [1.0, -1.0]:
		var face := t * f * th / 2.0
		var c := u * latch_u + Vector3.UP * hy + face
		if stair and f == -fs:
			_push_bar(m, u, t, f, th, w, hs, hy)
			continue
		m.rod(c, c + t * f * 0.012, 0.027, STEEL, 12, true)  # the rose
		var cyl := c - Vector3.UP * 0.075
		m.rod(cyl, cyl + t * f * 0.01, 0.014, STEEL, 10, true)  # the key cylinder
		m.box(cyl + t * f * 0.0105, _along(u, t, 0.004, 0.013, 0.002), DARK_STEEL)  # its keyway
		_lever(c + t * f * 0.012, u * hs, t * f)
	if stair:
		for f: float in [1.0, -1.0]:
			m.box(Vector3.UP * (floor_y + 0.15) + t * f * (th / 2.0 + 0.002), _along(u, t, w * 0.9, 0.25, 0.003), STEEL)
		_build_closer(m, u, t, fs, th, w, hs, size.y)
	m.commit(self, "Fittings", false, 0.4, 0.75)


## A lever on its rose at `at`: a short stem out from the door, the handle
## pointing `along` (toward the hinge) with its tip curled back in.
func _lever(at: Vector3, along: Vector3, out: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.name = "Lever"
	pivot.position = at + out * 0.045
	add_child(pivot)
	var m := ArtMesh.new()
	m.rod(-out * 0.045, Vector3.ZERO, 0.009, STEEL, 8)
	m.rod(Vector3.ZERO, along * 0.125, 0.0095, STEEL, 8, true)
	m.rod(along * 0.12, along * 0.128 - out * 0.022, 0.0085, STEEL, 8, true)
	m.commit(pivot, "Handle", false, 0.35, 0.8)
	levers.append(pivot)
	# Turning about this axis takes the handle's end down.
	_lever_axes.append(along.cross(Vector3.DOWN).normalized())


## A panic bar across the push side: a bracket at each end and the bar, which
## travels in under a push.
func _push_bar(m: ArtMesh, u: Vector3, t: Vector3, f: float, th: float, w: float, hs: float, hy: float) -> void:
	var a := -hs * (w / 2.0 - 0.07)
	var b := hs * (w / 2.0 - 0.2)
	var face := th / 2.0
	for e: float in [a, b]:
		m.box(u * e + Vector3.UP * hy + t * f * (face + 0.035), _along(u, t, 0.07, 0.085, 0.07), DARK_STEEL)
	push_bar = Node3D.new()
	push_bar.name = "PushBar"
	_bar_rest = u * (a + b) / 2.0 + Vector3.UP * hy + t * f * (face + 0.075)
	_bar_in = -t * f * BAR_PRESS
	push_bar.position = _bar_rest
	add_child(push_bar)
	var bar := ArtMesh.new()
	bar.box(Vector3.ZERO, _along(u, t, absf(b - a) - 0.07, 0.05, 0.035), STEEL)
	bar.box(-t * f * 0.02, _along(u, t, absf(b - a) - 0.09, 0.03, 0.006), DARK_STEEL)  # its sleeve, behind
	bar.commit(push_bar, "Bar", false, 0.35, 0.8)


## An overhead closer on the face the door swings toward: its body on the leaf by
## the hinge, two arms to a shoe on the frame header.
func _build_closer(m: ArtMesh, u: Vector3, t: Vector3, fs: float, th: float, w: float, hs: float, h: float) -> void:
	var top := h / 2.0
	# Deep enough that the arms clear the wall face (walls are 0.2 thick, the
	# leaf hangs in the middle of them).
	var body_at := u * hs * (w / 2.0 - 0.2) + Vector3.UP * (top - 0.05) + t * fs * (th / 2.0 + 0.04)
	m.box(body_at, _along(u, t, 0.28, 0.065, 0.08), CLOSER_GREY)
	m.rod(body_at + u * hs * 0.14, body_at + u * hs * 0.146, 0.03, CLOSER_GREY, 10, true)  # end cap
	_spindle = u * hs * (w / 2.0 - 0.1) + Vector3.UP * (top + 0.03) + t * fs * (th / 2.0 + 0.07)
	m.rod(_spindle - Vector3.UP * 0.05, _spindle, 0.009, DARK_STEEL, 8)
	_away = t * fs
	_closer_rest_u = u * hs * (w / 2.0 - 0.32)
	_main = _arm("MainArm", MAIN_ARM)
	_fore = _arm("Forearm", FOREARM)
	_shoe = Node3D.new()
	_shoe.name = "Shoe"
	add_child(_shoe)
	var s := ArtMesh.new()
	s.box(-_away * 0.008, _along(u, t, 0.09, 0.04, 0.03), CLOSER_GREY)
	s.commit(_shoe, "Body", false, 0.4, 0.7)
	_closer = true



## Where the shoe sits on the frame, in the leaf's own space while it's shut.
func _shoe_rest() -> Vector3:
	return _closer_rest_u + Vector3.UP * _spindle.y + _away * _spindle.dot(_away)


## One arm: a flat steel bar along +x from its pivot, `length` long.
func _arm(arm_name: String, length: float) -> Node3D:
	var n := Node3D.new()
	n.name = arm_name
	add_child(n)
	var m := ArtMesh.new()
	m.box(Vector3(length / 2.0, 0, 0), Vector3(length, 0.012, 0.022), DARK_STEEL)
	m.rod(Vector3(0, -0.01, 0), Vector3(0, 0.01, 0), 0.013, DARK_STEEL, 8, true)
	m.commit(n, "Bar", false, 0.4, 0.75)
	return n


## The shoe is fixed to the frame: take where it is from the shut leaf.
func _anchor_shoe() -> void:
	var shut := door.transform if door.swing == 0.0 else Transform3D(Basis(Vector3.UP, door._closed_rot), door._closed_pos)
	_shoe_xf = shut.translated_local(_shoe_rest())


## Fold the arms between the spindle and the shoe for the leaf's pose (`leaf`:
## the leaf's transform in its parent; the live door's own by default).
func _pose_closer(leaf: Variant = null) -> void:
	var xf: Transform3D = door.transform if leaf == null else leaf
	if door:
		_last_swing = door.swing
	_shoe.transform = xf.affine_inverse() * _shoe_xf
	var shoe := _shoe.position
	var d := _spindle.distance_to(shoe)
	var dir := (shoe - _spindle) / maxf(d, 0.001)
	d = clampf(d, absf(MAIN_ARM - FOREARM) + 0.001, MAIN_ARM + FOREARM - 0.001)
	var a := (MAIN_ARM * MAIN_ARM - FOREARM * FOREARM + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, MAIN_ARM * MAIN_ARM - a * a))
	var side := Vector3.UP.cross(dir)
	if side.dot(_away) < 0.0:
		side = -side
	var elbow := _spindle + dir * a + side * h
	_aim(_main, _spindle, elbow)
	_aim(_fore, elbow + Vector3.UP * 0.014, shoe + Vector3.UP * 0.014)


func _aim(arm: Node3D, from: Vector3, to: Vector3) -> void:
	var x := to - from
	x.y = 0.0
	x = x.normalized() if x.length() > 0.0001 else Vector3.RIGHT
	arm.transform = Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), from)


## A box `across` wide along the leaf, `high` tall, `deep` through it.
static func _along(u: Vector3, t: Vector3, across: float, high: float, deep: float) -> Vector3:
	return (u * across + t * deep).abs() + Vector3.UP * high


# --- Motion ---------------------------------------------------------------------

func _on_moved(phase: StringName) -> void:
	match phase:
		&"unlatch":
			if _closer:
				_anchor_shoe()
			_press_to(1.0, Door.HOLD * 0.8)
		&"swing":
			_release(0.12, 0.28)  # (even unpressed: a long frame can bring both at once)


func _press_to(to: float, time: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "press", to, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The hand lets go once the leaf is on its way, and the spring brings it back up.
func _release(after: float, time: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(after)
	_tween.tween_property(self, "press", 0.0, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pose_press() -> void:
	for i in levers.size():
		levers[i].basis = Basis(_lever_axes[i], deg_to_rad(LEVER_PRESS * press))
	if push_bar:
		push_bar.position = _bar_rest + _bar_in * clampf(press, 0.0, 1.1)
