class_name SfxRooms
extends Node
## Every room sounds its size. A few times a second it measures the space around
## this machine's player (rays out to the walls and up to the ceiling) and tunes
## the reverb on the SFX bus to match: a vent rings close and tinny, an office is
## nearly dry, a hall or a stairwell carries a long tail, and outside there's no
## echo at all. Footsteps, doors, punches and monsters all go through it.
##
## Nothing is synced: each machine hears the room its own player is standing in.
## No floor needs any code for it; a new floor sounds right as it's built.

## How often the room is measured, in seconds.
const POLL := 0.3
## How far a ray looks for a wall, in metres. Nothing within this is outdoors.
const REACH := 30.0
## How fast the reverb follows a new room (per second): walking through a door
## opens the sound up over about a second, not with a jump.
const FOLLOW := 2.5
## Under this ceiling (metres from the ears) and this wide, you're in a duct.
const DUCT_UP := 1.0
const DUCT_ACROSS := 2.2
## Eight ways round, level.
const AROUND := 8

var world: Node
## The reverb on the SFX bus that this tunes.
var reverb: AudioEffectReverb
## Where the reverb is heading, and where it is.
var goal := {}
var now := {}
## What it measured last, for tests and debugging: {across, up, open}.
var last := {}
var _t := 0.0


## Follows `w` (the World) for as long as it exists. One per game.
static func follow(w: Node) -> SfxRooms:
	var music := Music.of(w)
	var r := music.get_node_or_null("Rooms") as SfxRooms
	if r == null:
		r = SfxRooms.new()
		r.name = "Rooms"
		music.add_child(r)
	r.world = w
	return r


func _ready() -> void:
	reverb = ensure_reverb()
	goal = feel(6.0, 1.5, 0.0)
	now = goal.duplicate()
	_apply()


## The SFX bus's reverb, added the first time it's asked for.
static func ensure_reverb() -> AudioEffectReverb:
	Sfx.ensure_buses()
	var bus := AudioServer.get_bus_index(Sfx.SFX)
	for i in AudioServer.get_bus_effect_count(bus):
		var fx := AudioServer.get_bus_effect(bus, i)
		if fx is AudioEffectReverb:
			return fx
	var r := AudioEffectReverb.new()
	r.dry = 1.0
	r.spread = 0.7
	r.hipass = 0.15
	r.predelay_feedback = 0.1
	AudioServer.add_bus_effect(bus, r)
	return r


## How a room sounds: `across` is how far apart its walls are (metres), `up` how far
## the ceiling is above your ears, `open` how much of the way round has no wall at
## all (0 to 1). Returns the reverb's settings.
static func feel(across: float, up: float, open: float) -> Dictionary:
	if up < DUCT_UP and across < DUCT_ACROSS:
		# Inside sheet metal: short, bright, close.
		return {"room_size": 0.12, "damping": 0.1, "wet": 0.3, "predelay_msec": 3.0}
	var big := clampf((across - 3.0) / 22.0, 0.0, 1.0)
	var high := clampf((up - 1.5) / 6.0, 0.0, 1.0)
	var size := clampf(maxf(big, high * 0.8), 0.0, 1.0)
	var s := {
		"room_size": lerpf(0.2, 0.85, size),
		"damping": lerpf(0.65, 0.35, size),
		"wet": lerpf(0.08, 0.3, size),
		# Sound takes about 3 ms a metre: the far wall's first answer.
		"predelay_msec": clampf(across * 3.0, 5.0, 70.0),
	}
	# Out where most of the way round there's nothing to bounce off: no echo.
	var outside := clampf((open - 0.4) / 0.4, 0.0, 1.0)
	s.wet = lerpf(s.wet, 0.02, outside)
	return s


## Measures the room around `from`: rays out to the walls and one up. `exclude` is
## the bodies to look past (the player's own).
static func measure(space: PhysicsDirectSpaceState3D, from: Vector3, mask: int, exclude: Array[RID]) -> Dictionary:
	var dists: Array[float] = []
	var misses := 0
	for i in AROUND:
		var a := TAU * i / AROUND
		var dir := Vector3(cos(a), 0, sin(a))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * REACH, mask, exclude))
		if hit.is_empty():
			misses += 1
			dists.append(REACH)
		else:
			dists.append(from.distance_to(hit.position))
	dists.sort()
	# Opposite walls: twice the distance half the rays reach (the corners are further,
	# and a pillar or a person close by doesn't make a hall sound like a cupboard).
	var across := dists[AROUND / 2 - 1] * 2.0
	var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * REACH, mask, exclude))
	var up := REACH if roof.is_empty() else from.distance_to(roof.position)
	if roof.is_empty():
		misses += 1
	return {"across": across, "up": up, "open": float(misses) / (AROUND + 1)}


func _process(delta: float) -> void:
	_t += delta
	if _t >= POLL:
		_t = 0.0
		_measure()
	var k := minf(1.0, delta * FOLLOW)
	for key in goal:
		now[key] = lerpf(now[key], goal[key], k)
	_apply()


func _measure() -> void:
	var me: Node3D = world.get("player") if is_instance_valid(world) else null
	if me == null or not me.is_inside_tree():
		return
	var ears := me.global_position + Vector3.UP * _ears(me)
	var mask: int = me.get("collision_mask") if me.get("collision_mask") != null else 1
	var skip: Array[RID] = []
	if me is CollisionObject3D:
		skip.append(me.get_rid())
	last = measure(me.get_world_3d().direct_space_state, ears, mask, skip)
	goal = feel(last.across, last.up, last.open)


## How high this player's ears are (lower crouched or crawling).
static func _ears(me: Node3D) -> float:
	var cam := me.get_viewport().get_camera_3d() if me.get_viewport() else null
	if cam and me.is_ancestor_of(cam):
		return cam.global_position.y - me.global_position.y
	return 1.5


func _apply() -> void:
	if reverb == null:
		return
	reverb.room_size = now.room_size
	reverb.damping = now.damping
	reverb.wet = now.wet
	reverb.predelay_msec = now.predelay_msec
