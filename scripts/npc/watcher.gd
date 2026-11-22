class_name Watcher
extends CharacterBody3D
## The Watcher (Level 2). A tall, faceless figure that moves only when nobody is
## looking at it: no player has it on screen with a clear line of sight, and no
## working camera covers the spot it stands on. Seen, it freezes mid-step.
## Unseen, it walks toward the nearest player, and if it reaches one, they go down.
##
## Counterplay (plan/environment-play-e7.md): a flashlight strobe in its face keeps
## it frozen for a few seconds after everyone looks away. A fire extinguisher's
## cloud blocks your view of it, so it moves. Any shut door between you holds it.
## Hiding: from a locker you can see out (staring keeps it frozen); under a desk or
## in a cabinet you can't, and if it was coming for you, it comes to the spot.

signal caught(player: Node)
## Fired the first time it moves after being seen, so levels can warn players.
signal started_moving

const SPEED := 1.7
const CATCH_RANGE := 1.15
const HEIGHT := 2.35
## What it collides with: shorter than it looks, so it fits under an open door
## (it stoops). At full height an opened office door stopped it dead.
const BODY_HEIGHT := 2.1
const CATCH_COOLDOWN := 3.0
## How far off-center a co-op player on another machine can still see it.
const PUPPET_VIEW_HALF_ANGLE := 50.0
## Counterplay: a strobe keeps it frozen this long after everyone looks away.
const STROBE_FREEZE := 3.0

## Off until the level lets it loose.
var active := false
## Extra "something is watching it" checks, e.g. live cameras: Callable(watcher) -> bool.
var holders: Array[Callable] = []
## Colliders players can see through, like window glass.
var see_through: Array[RID] = []
var seen := true
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _agent: NavigationAgent3D
var _body: Node3D
var _arms: Array[Node3D] = []
var _cooldown := 0.0
var _was_moving := false
## Strobed: frozen while anyone looks, then for _freeze more seconds.
var _strobed := false
var _freeze := 0.0
## A hiding place the one it was coming for got into: it goes there (host).
var _search: Node3D


func _ready() -> void:
	add_to_group("npc")
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = BODY_HEIGHT
	shape.shape = cap
	shape.position.y = BODY_HEIGHT / 2
	add_child(shape)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var skin := Color(0.78, 0.76, 0.72)
	_part(CapsuleMesh.new(), Vector3(0, 1.45, 0), skin, Vector3(0.42, 0.55, 0.3))  # torso
	for side in [-1, 1]:
		_part(CapsuleMesh.new(), Vector3(side * 0.1, 0.5, 0), skin, Vector3(0.14, 0.52, 0.14))  # legs
	_part(SphereMesh.new(), Vector3(0, 2.12, -0.02), skin, Vector3(0.26, 0.36, 0.26))
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "ArmL" if side < 0 else "ArmR"
		pivot.position = Vector3(side * 0.24, 1.78, 0)
		_body.add_child(pivot)
		var arm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 1.15, 0.08)
		arm.mesh = bm
		arm.position = Vector3(0, -0.58, 0)
		arm.material_override = Greybox.mat(skin, 0.0, 0.7)
		pivot.add_child(arm)
		_arms.append(pivot)

	_agent = NavigationAgent3D.new()
	# The baked path floats about half a meter over the floor, so a point counts as
	# reached a little further out than that. At 0.5 it never did, and it stalled.
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 0.8
	_agent.radius = 0.35
	_agent.height = BODY_HEIGHT
	add_child(_agent)


func _part(mesh: PrimitiveMesh, pos: Vector3, color: Color, scale_v: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = Greybox.mat(color, 0.0, 0.7)
	_body.add_child(mi)


## Co-op: what clients mirror from the host, which runs it. Its pose changes
## while nobody looks, so the arms and body go too.
func sync_properties() -> Array:
	return [".:position", ".:rotation", ".:seen", "Body:rotation", "Body/ArmL:rotation", "Body/ArmR:rotation"]


## Put it somewhere, standing still, facing a point.
func place(at: Vector3, look: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_face(look)


## Move somewhere while nobody is looking, in a new pose: the next time
## someone looks, it's standing somewhere else, a little differently.
func step_to(at: Vector3, look: Vector3) -> void:
	place(at, look)
	_new_pose()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	_cooldown = max(0.0, _cooldown - delta)
	seen = is_watched()
	if _strobed:
		_freeze = STROBE_FREEZE if seen else _freeze - delta
		_strobed = _freeze > 0.0
		seen = true  # still dazzled
	var target := nearest_player()
	if is_instance_valid(_search) and Counterplay.hiding_in(_search) == null:
		_search = null  # they got out
	var goal: Node3D = _search if is_instance_valid(_search) else target
	if not active or seen or goal == null or _cooldown > 0.0:
		velocity.x = 0
		velocity.z = 0
		_was_moving = false
		move_and_slide()
		return
	if not _was_moving:
		_was_moving = true
		_new_pose()
		started_moving.emit()
	_face(goal.global_position)
	if goal == _search:
		if _flat_to(goal) < CATCH_RANGE + 0.5:
			_take_from(_search)
			return
	elif global_position.distance_to(target.global_position) < CATCH_RANGE and _can_reach(target):
		_cooldown = CATCH_COOLDOWN
		velocity = Vector3.ZERO
		caught.emit(target)
		return
	_agent.target_position = goal.global_position
	var next := _agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0
	if dir.length() < 0.05:
		dir = goal.global_position - global_position
		dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()


## Counterplay (host): `how` is "extinguisher", "strobe" or "thrown". Only the
## strobe does anything (the cloud works against you: see player_sees).
func counter(how: String, _from: Vector3) -> void:
	if how == "strobe":
		_strobed = true
		_freeze = STROBE_FREEZE


## Counterplay (host): someone got into hiding. It cares if it was coming for them.
func counter_saw(body: Node3D) -> bool:
	return active and body == nearest_player(true)


## Counterplay (host): the one it was coming for is hiding there: it goes there.
func counter_search(spot: Node3D) -> void:
	if spot:
		_search = spot


## At the spot: it pulls them out, and has them.
func _take_from(spot: Node3D) -> void:
	_search = null
	var p := Counterplay.hiding_in(spot)
	var c := Counterplay.of(self)
	if p == null or c == null or not c.pull_out(spot):
		return
	_cooldown = CATCH_COOLDOWN
	velocity = Vector3.ZERO
	caught.emit(p)


func _flat_to(n: Node3D) -> float:
	return Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length()


func is_watched() -> bool:
	for p in _players():
		if player_sees(p):
			return true
	for h in holders:
		if h.call(self):
			return true
	return false


## True if this player has the Watcher on screen with nothing in the way.
## A player busy at a terminal is looking at the screen, not at the room.
## Co-op players on other machines have no camera here, only a head: they see
## what's inside a cone about as wide as the screen.
func player_sees(p: Node) -> bool:
	if p.get("input_locked"):
		return false
	var spot := Counterplay.hidden_in(p)
	if spot and not spot.get("see_out"):
		return false  # under a desk or in a cabinet: you can't see out
	var cam: Camera3D = p.get("camera")
	var head: Node3D = p.get("_head")
	if cam == null and head == null:
		return false
	var eye: Node3D = cam if cam else head
	if not eye.is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [p.get_rid()]
	exclude.append_array(see_through)
	for h in [0.4, 1.3, 2.1]:
		var pt: Vector3 = global_position + Vector3.UP * h
		if cam and not cam.is_position_in_frustum(pt):
			continue
		if not cam and (-eye.global_basis.z).angle_to(pt - eye.global_position) > deg_to_rad(PUPPET_VIEW_HALF_ANGLE):
			continue
		if SightCloud.blocks(self, eye.global_position, pt):
			continue  # an extinguisher's cloud in the way: it moves
		var q := PhysicsRayQueryParameters3D.create(eye.global_position, pt, 0xFFFFFFFF, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.collider == self:
			return true
	return false


## Whoever's closest and still on their feet: it leaves the ones it put down, and
## anyone hiding (`with_hidden` counts them: who was it coming for?).
func nearest_player(with_hidden := false) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p in _players():
		if CrewVitals.is_down(p) or (not with_hidden and Counterplay.hidden_in(p) != null):
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


## Nothing solid between it and them: a locked door or a pane of glass keeps them safe.
func _can_reach(p: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.3, p.global_position + Vector3.UP * 1.0, 0xFFFFFFFF, [get_rid(), p.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Players in this world (tests run several co-op worlds in one process).
func _players() -> Array:
	return get_tree().get_nodes_in_group("player").filter(func(p): return p.get_viewport() == get_viewport())


func _face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.05:
		look_at(flat, Vector3.UP)


## Every time you look back, it is standing a little differently.
func _new_pose() -> void:
	for i in _arms.size():
		_arms[i].rotation = Vector3(randf_range(-1.2, 0.2), 0, randf_range(-0.3, 0.3) * (1 if i == 0 else -1))
	_body.rotation.z = randf_range(-0.12, 0.12)
	_body.rotation.x = randf_range(-0.05, 0.18)
