class_name SfxSteps
extends Node3D
## Footsteps and landings for a body: your own player, or a teammate's puppet on
## your machine. Worked out from how the body moves, which every machine sees the
## same way, so everyone hears the same steps in the same place.
##
## Loudness follows what the Shredder hears (Player._footsteps): sprinting is loud,
## walking is soft, crouching is barely there, banging along a duct is loud.
## The floor picks the sound: a body's "surface" meta (Sfx.mark_surface) if a
## level set one, otherwise a guess from its name, otherwise concrete.

## Player.WALK_SPEED, plus the margin Player._footsteps uses to call it a sprint.
const SPRINT_ABOVE := 4.3
## Between Player.CRAWL_SPEED and VENT_RUSH_SPEED: hurrying through a duct.
const VENT_RUSH_ABOVE := 2.1
const WALK_INTERVAL := 0.5
const SPRINT_INTERVAL := 0.33
## Falls slower than this land without a sound; faster than HARD land hard (Player.HARD_LANDING).
const LAND_SPEED := 2.5
const HARD_LANDING := 7.0
## Moving faster than this is a teleport or a respawn, not a step.
const TELEPORT_SPEED := 15.0
const CROUCH_DB := -18.0
const WALK_DB := -6.0
const SPRINT_DB := 0.0

## Collider names that say what a floor is made of, checked in order.
const NAMED_SURFACES := [
	["vent", "vent"], ["grate", "metal"], ["gantry", "metal"], ["catwalk", "metal"],
	["carpet", "carpet"], ["rug", "carpet"],
	["desk", "wood"], ["table", "wood"], ["counter", "wood"], ["crate", "wood"],
	["shelf", "wood"], ["bench", "wood"],
]

var body: Node3D
## What played, newest last (tests): {"kind", "db"}. The last few only.
var heard: Array = []
var _last := Vector3.ZERO
var _step_t := 0.0
var _fall := 0.0
var _was_on_floor := true
var _move := ""


## Steps for `b`, on every machine that has it, and its fight sounds (SfxCombat).
static func attach(b: Node3D) -> SfxSteps:
	var s := SfxSteps.new()
	s.name = "Steps"
	s.body = b
	b.add_child(s)
	SfxCombat.attach(b)
	return s


func _ready() -> void:
	_last = body.global_position


func _physics_process(delta: float) -> void:
	if delta <= 0.0 or not is_instance_valid(body):
		return
	var pos := body.global_position
	var v := (pos - _last) / delta
	_last = pos
	var flat := Vector2(v.x, v.z).length()
	if flat > TELEPORT_SPEED:
		_fall = 0.0
		return
	var floor_hit := _floor()
	var on_floor := not floor_hit.is_empty()
	_moves()
	if not on_floor:
		_fall = maxf(_fall, -v.y)
		_step_t = 0.0
	elif not _was_on_floor:
		if _fall > LAND_SPEED and _upright():
			var hard := _fall > HARD_LANDING
			_play("land_hard" if hard else "land", 0.0 if hard else lerpf(-8.0, 0.0, inverse_lerp(LAND_SPEED, HARD_LANDING, _fall)))
		_fall = 0.0
		_step_t = 0.0
	_was_on_floor = on_floor
	if not on_floor or flat < 0.5 or not _walking():
		_step_t = 0.0
		return
	var surface := surface_of(floor_hit.collider)
	var sprinting := flat > (VENT_RUSH_ABOVE if surface == "vent" else SPRINT_ABOVE)
	_step_t += delta
	if _step_t < (SPRINT_INTERVAL if sprinting else WALK_INTERVAL):
		return
	_step_t = 0.0
	var db := SPRINT_DB if sprinting else WALK_DB
	if _crouched():
		# In a duct you're always on hands and knees: only scrambling is loud.
		db = SPRINT_DB if surface == "vent" and sprinting else CROUCH_DB
	_play("step_" + surface, db)


## What a floor is made of: "concrete", "carpet", "wood", "metal" or "vent".
static func surface_of(collider: Object) -> String:
	if collider == null:
		return "concrete"
	if collider.has_meta("surface"):
		return collider.get_meta("surface")
	var n := String(collider.name).to_lower() if collider is Node else ""
	for pair in NAMED_SURFACES:
		if n.contains(pair[0]):
			return pair[1]
	return "concrete"


func _play(kind: String, db: float) -> void:
	heard.append({"kind": kind, "db": db})
	if heard.size() > 16:
		heard.pop_front()
	Sfx.play(body.get_parent(), kind, body.position, db)


## The floor right under the body, or {} when it's in the air.
func _floor() -> Dictionary:
	var from := body.global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.45)
	if body is CollisionObject3D:
		q.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_ray(q)


## Your own player says what it's doing; a teammate's puppet only how it sits.
func _walking() -> bool:
	if body.has_method("move_name"):
		return body.move_name() == "walk" and body.get("rider") == null
	return body.get("sitting") == 0 and not body.get("downed") and body.get("at_terminal") == null


func _upright() -> bool:
	return not body.has_method("move_name") or body.move_name() in ["walk", "slide"]


func _crouched() -> bool:
	return body.get("crouching") == true or body.get("crawling") == true


## Your own player's vaults, mantles and ledge grabs, as they start.
func _moves() -> void:
	if not body.has_method("move_name"):
		return
	var m: String = body.move_name()
	if m == _move:
		return
	match m:
		"vault", "mantle":
			_play("vault", -4.0)
		"hang", "ledge":
			_play("ledge_grab", -4.0)
	_move = m
