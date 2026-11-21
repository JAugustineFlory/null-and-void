class_name Door
extends AnimatableBody3D
## A sliding security door, or an ordinary hinged one (see `hinge`). Its state
## comes from the `doors` table.
## If the actuator is faulted, the database can say "unlocked" while the door stays shut.

@export var door_id := ""
@export var size := Vector3(1.6, 2.4, 0.2)
@export var slide_axis := Vector3.UP

## Set to swing open on a hinge instead of sliding: the hinge's offset from the
## door's centre (its edge, e.g. Vector3(0, 0, -0.9) for a 1.8 m door along z),
## and how far it swings, in degrees (the sign picks the side it opens to).
var hinge := Vector3.ZERO
var swing_deg := 90.0
## 0 shut, 1 fully open. Hinged doors are posed from it.
var swing := 0.0:
	set(v):
		swing = v
		_pose_swing()

## A hinged door that swings only to the side `swing_deg` picks, whoever opens it
## and from wherever (a stair door opens out of its stairwell).
var one_way := false

## Hinged doors are ordinary doors: anyone can open and shut them with E,
## unless `locked` (a badge door: only a badge holder like Rourke opens it).
var locked := false

var is_open := false

## Each step of the door's motion as it plays (art and sound follow it; it plays
## on every machine, since set_open does):
##   hinged: "unlatch" (the handle goes down: HOLD before the leaf moves), "swing",
##           "stop" (at the stop, a small rebound), then "close" and "latch";
##   sliding: "unlock" (the bolts draw, the motor lurches it), "run", "stop", then
##           "close" and "thud" (it bumps the floor or the jamb, a little rebound).
## Set at once (`instant`), a door moves without a sound or a phase.
signal moved(phase: StringName)

## How long a hand holds the handle down, or a motor takes to draw the bolts,
## before the leaf moves. A shove (the Shredder walking into a door) skips it.
const HOLD := 0.12

var _closed_pos := Vector3.ZERO
var _closed_rot := 0.0
var _tween: Tween


## Make it an ordinary door on a hinge at `edge` (offset from its centre) that
## swings `degrees` when opened.
func make_hinged(edge: Vector3, degrees: float = 90.0) -> Door:
	hinge = edge
	swing_deg = degrees
	return self


static func create(parent: Node, id: String, pos: Vector3, door_size: Vector3, color: Color = Color(0.35, 0.37, 0.4)) -> Door:
	var d := Door.new()
	d.door_id = id
	d.size = door_size
	d.position = pos
	d.name = "Door_" + id
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = door_size
	mesh.mesh = bm
	mesh.material_override = Greybox.mat(color, 0.0, 0.5)
	d.add_child(mesh)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(door_size.x * 0.9 if door_size.x > door_size.z else door_size.x + 0.02, 0.12, door_size.z + 0.02 if door_size.x > door_size.z else door_size.z * 0.9)
	stripe.mesh = sm
	stripe.material_override = Greybox.mat(Color(0.8, 0.6, 0.1))
	stripe.position.y = door_size.y * 0.25
	d.add_child(stripe)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = door_size
	shape.shape = bs
	d.add_child(shape)
	parent.add_child(d)
	d.add_to_group("doors")
	return d


func _ready() -> void:
	_capture_closed_pose()
	sync_to_physics = false
	_furnish.call_deferred()  # once its caller has made it hinged, one-way or a stair door


## Its handles, push bar and closer (scripts/art/art_door.gd), which follow `moved`.
func _furnish() -> void:
	ArtDoor.furnish(self)


## A shut door at rest is in its closed pose. Taken again each time it starts to
## open, so a door placed or turned after Door.create (a stairwell's) swings from
## where it really stands.
func _capture_closed_pose() -> void:
	_closed_pos = position
	_closed_rot = rotation.y


func is_hinged() -> bool:
	return hinge != Vector3.ZERO


## What looking at the door says: hinged doors open and shut with E.
func get_prompt(_player: Node) -> String:
	if not is_hinged():
		return ""
	if locked:
		return "Locked"
	return "[E] Close the door" if is_open else "[E] Open the door"


## E on a hinged door: the host opens or shuts it on every machine. A door opens
## away from whoever opens it, so a crew at a doorway is never swept aside or pinned
## by its leaf; shut again, it keeps that side (what it offers to anything that can
## only push, like the Shredder). A `one_way` door keeps its own side.
func interact(player: Node) -> void:
	if is_hinged() and locked and get_parent() is Node3D:
		Sfx.play(get_parent(), "lock", position)  # the handle won't turn
	if not is_hinged() or locked:
		return
	var sync := LevelSync.of(self)
	if sync == null:
		set_open(not is_open, false, away_from(player))
	elif not sync.forward(self, "interact"):
		sync.run_on(self, "set_open", [not is_open, false, away_from(player)])


## The swing sign (+1 or -1) that opens this shut door away from `body`; 0 to keep
## the side it has (it's open, or `body` stands in the door's plane).
func away_from(body: Node) -> float:
	if body == null or not (body is Node3D) or is_open or swing != 0.0:
		return 0.0
	var edge := Basis(Vector3.UP, _closed_rot) * hinge
	var plus: Vector3 = edge + Basis(Vector3.UP, _closed_rot + PI / 2) * -hinge  # the leaf's middle, opened by +90
	var through: Vector3 = global_basis.z if size.x > size.z else global_basis.x
	var plus_side: float = (get_parent().global_basis * plus).dot(through)
	var body_side: float = (body.global_position - global_position).dot(through)
	if absf(body_side) < 0.05 or absf(plus_side) < 0.01:
		return 0.0
	return -1.0 if body_side * plus_side > 0.0 else 1.0


func _pose_swing() -> void:
	if not is_hinged() or not is_inside_tree():
		return
	var turn := Basis(Vector3.UP, deg_to_rad(swing_deg * swing))
	var edge := Basis(Vector3.UP, _closed_rot) * hinge  # the hinge turns with the door
	position = _closed_pos + edge + turn * -edge
	rotation.y = _closed_rot + deg_to_rad(swing_deg * swing)


## `away` (+1/-1, from away_from) picks the side a shut hinged door swings to.
## `pushed`: shoved open, not by its handle (no HOLD; it starts moving at once).
func set_open(open: bool, instant: bool = false, away: float = 0.0, pushed: bool = false) -> void:
	if open == is_open:
		return
	var moving := _tween != null and _tween.is_running()
	if open and not moving and swing == 0.0:
		_capture_closed_pose()
		if away != 0.0 and not one_way:
			swing_deg = absf(swing_deg) * away
	is_open = open
	if not instant:
		_sound(open)
	if _tween:
		_tween.kill()
	if is_hinged():
		if instant:
			swing = 1.0 if open else 0.0
			return
		_tween = create_tween()
		if open:
			_swing_open(pushed or swing > 0.0)
		else:
			_swing_shut()
		return
	var target := _closed_pos + (slide_axis * (size.y - 0.15) if open else Vector3.ZERO)
	if instant:
		position = target
		return
	_tween = create_tween()
	if open:
		_slide_open(target, moving)
	else:
		_slide_shut(target)


## Handle down, a beat, then the leaf eases round to its stop and rebounds a
## touch off it (back toward shut, never past open into a wall or a teammate).
func _swing_open(unlatched: bool) -> void:
	if not unlatched:
		_phase(&"unlatch")
		_tween.tween_interval(HOLD)
		_tween.tween_callback(_phase.bind(&"swing"))
	else:
		_phase(&"swing")
	var left := 1.0 - swing
	_tween.tween_property(self, "swing", 1.0, 0.25 + 0.47 * left).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if unlatched else Tween.EASE_IN_OUT)
	_tween.tween_callback(_phase.bind(&"stop"))
	_tween.tween_property(self, "swing", 0.97, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "swing", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A closer's sweep: steady, slowing as it nears the frame, then the last few
## degrees snap it onto the latch.
func _swing_shut() -> void:
	_phase(&"close")
	_tween.tween_property(self, "swing", 0.04, maxf(0.15, 0.55 * swing)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "swing", 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_phase.bind(&"latch"))


## The bolts draw and the motor lurches it a centimetre, then it runs open and
## stops. One already moving just turns round.
func _slide_open(target: Vector3, moving: bool) -> void:
	var dir := (target - _closed_pos).normalized()
	if not moving and position.distance_to(_closed_pos) < 0.001:
		_phase(&"unlock")
		_tween.tween_property(self, "position", _closed_pos + dir * 0.012, HOLD * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "position", _closed_pos + dir * 0.004, HOLD * 0.6).set_trans(Tween.TRANS_SINE)
		_tween.tween_callback(_phase.bind(&"run"))
	else:
		_phase(&"run")
	var left := position.distance_to(target) / maxf(0.01, _closed_pos.distance_to(target))
	_tween.tween_property(self, "position", target, 0.3 + 0.65 * left).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_phase.bind(&"stop"))


## It runs shut fast, thuds home and bounces a centimetre off the floor or jamb.
func _slide_shut(target: Vector3) -> void:
	_phase(&"close")
	var open_at := _closed_pos + slide_axis * (size.y - 0.15)
	var dir := (open_at - target).normalized()
	_tween.tween_property(self, "position", target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_phase.bind(&"thud"))
	_tween.tween_property(self, "position", target + dir * 0.01, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", target, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _phase(phase: StringName) -> void:
	moved.emit(phase)


## A sliding door's motor runs it open and it thuds shut; a hinged one's latch clicks.
func _sound(opening: bool) -> void:
	var parent := get_parent()
	if parent is Node3D:
		var hinged := "push_bar" if String(name).contains("STAIR") else ("handle" if opening else "click")
		Sfx.play(parent, hinged if is_hinged() else ("door_motor" if opening else "clunk"), position)


## Called when the database row changes. A hinged door's row is its lock: it
## shuts and stays shut while locked, and players open it themselves once it
## isn't. A sliding door opens itself when unlocked, unless its actuator is faulted.
func apply_db_state(db_locked: bool, fault: bool) -> void:
	if is_hinged():
		locked = db_locked
		if db_locked:
			set_open(false)
		return
	if fault:
		return
	set_open(not db_locked)
