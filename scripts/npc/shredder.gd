class_name Shredder
extends CharacterBody3D
## The Shredder (Level 3). A big, blind thing that lives among the shredding machines
## on floor 18 and hunts by sound. It sleeps until something loud wakes it; awake, it
## turns toward every sound it hears, walks to where it came from, and roams the floor
## between sounds. Anyone it bumps into it picks up, holds for a moment, and throws
## across the room: heavy damage, and off a high shelf you fall the rest of the way.
## It can't be blocked. It never sees: crouching and slow walking are quiet, and the
## machines in its own room drown out everything near them.
##
## Hearing, on the host: the level feeds it sounds with hear() (a crank, a dropped
## box, this machine's player's noise_made), and it listens to every body itself:
## one moving faster than a walk is sprinting, which is loud, on every machine.
## Co-op: simulated on the host (sync.replicate in the level's net_setup); the grab
## and throw go through CrewVitals, so they land on whichever machine owns the player.

## It woke up (host).
signal woke
## It heard something worth walking to (host).
signal heard(at: Vector3)
## It has hold of someone (host).
signal caught(player: Node)
## It threw them (host).
signal threw(player: Node)

const SPEED := 3.4  # faster than a walk, slower than a sprint
const ROAM_SPEED := 2.2
const HEIGHT := 2.4
const BODY_HEIGHT := 2.1
const CATCH_RANGE := 1.3
## Held before the throw: the tell, and the crew's chance to make it let go.
const GRAB_TIME := 1.1
const THROW_FORCE := 9.0
const THROW_DAMAGE := 35.0
## A sound of loudness 1.0 carries this far; one of loudness L carries L times it. So a
## sprint (0.5) is heard from 8 m, a hard landing (0.7) from 11 m, footsteps (0.15)
## from under 3 m, and a crank (2.0) from across the floor.
const HEAR_RANGE := 16.0
## Inside a masking zone, only a sound this close still gets through.
const MASK_REACH := 3.0
## It turns toward a sound before it moves, then forgets it after a while.
const LISTEN_TIME := 0.8
const FORGET_TIME := 6.0
## After a throw it stands and listens; quiet for this long and it roams.
const RECOVER_TIME := 2.5
const ROAM_AFTER := 8.0
## How loud a body is for how fast it moves (see Player._footsteps). A body "moving"
## faster than anyone can run was teleported, and makes no sound.
const SPRINT_LOUDNESS := 0.5
const TELEPORT_SPEED := 10.0

## Awake and hunting. Dormant, it hears nothing: the level wakes it.
var active := false
## dormant | listening | turning | investigating | roaming | grabbing | recovering
var state := "dormant"
## The level's CrewVitals, for the grab and the throw. Set by the level.
var crew: Node
## The level, whose space `mask_zones` and `roam_points` are in.
var space: Node3D
## Where the machines drown out sound (level space).
var mask_zones: Array[AABB] = []
## Where it wanders between sounds (level space).
var roam_points: Array[Vector3] = []
var target_point := Vector3.ZERO
var held: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _agent: NavigationAgent3D
var _body: Node3D
var _arms: Array[Node3D] = []
var _timer := 0.0
var _quiet := 0.0
var _last_pos := {}
var _roam_i := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("npc")
	_rng.seed = 18
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = BODY_HEIGHT
	shape.shape = cap
	shape.position.y = BODY_HEIGHT / 2
	add_child(shape)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var hide := Color(0.32, 0.3, 0.28)
	_part(BoxMesh.new(), Vector3(0, 1.45, 0), hide, Vector3(0.9, 1.1, 0.6))  # a broad, hunched trunk
	for side in [-1, 1]:
		_part(CapsuleMesh.new(), Vector3(side * 0.22, 0.5, 0), hide, Vector3(0.2, 0.55, 0.2))  # legs
	# No head to speak of: a low, eyeless block, split by a slot like a feed hopper.
	_part(BoxMesh.new(), Vector3(0, 2.15, -0.1), hide.darkened(0.2), Vector3(0.55, 0.35, 0.5))
	_part(BoxMesh.new(), Vector3(0, 2.12, -0.36), Color(0.05, 0.05, 0.05), Vector3(0.4, 0.06, 0.02))
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "ArmL" if side < 0 else "ArmR"
		pivot.position = Vector3(side * 0.5, 1.9, 0)
		_body.add_child(pivot)
		var arm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 1.3, 0.16)
		arm.mesh = bm
		arm.position = Vector3(0, -0.65, 0)
		arm.material_override = Greybox.mat(hide.darkened(0.1), 0.0, 0.8)
		pivot.add_child(arm)
		_arms.append(pivot)
	_pose_arms(0.1, 0.0)

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 0.8
	_agent.radius = 0.4
	_agent.height = BODY_HEIGHT
	add_child(_agent)


func _part(mesh: PrimitiveMesh, pos: Vector3, color: Color, scale_v: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = Greybox.mat(color, 0.0, 0.8)
	_body.add_child(mi)


## Co-op: what clients mirror from the host, which runs it.
func sync_properties() -> Array:
	return [".:position", ".:rotation", ".:state", ".:active", "Body:rotation", "Body/ArmL:rotation", "Body/ArmR:rotation"]


## Put it somewhere, standing still, facing a point.
func place(at: Vector3, look: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_face(look)


## Something loud woke it. From now on it listens.
func wake() -> void:
	if active:
		return
	active = true
	state = "listening"
	_quiet = 0.0
	_pose_arms(0.6, 0.3)
	woke.emit()


## Where the thing it's holding hangs: up in front of it.
func grab_point() -> Vector3:
	return global_position + -global_basis.z * 0.9 + Vector3.UP * 1.4


## A sound at `at` (world space), `loudness` in range units (see HEAR_RANGE). Dormant,
## it hears nothing. Inside a masking zone only a nearby sound gets through.
func hear(at: Vector3, loudness: float) -> bool:
	if not active or state in ["grabbing"]:
		return false
	var dist := global_position.distance_to(at)
	if _masked(at) and dist > MASK_REACH:
		return false
	if dist > loudness * HEAR_RANGE:
		return false
	target_point = at
	_timer = FORGET_TIME
	_quiet = 0.0
	if state in ["listening", "roaming", "recovering"]:
		state = "turning"
		_timer = LISTEN_TIME
	heard.emit(at)
	return true


func _masked(at: Vector3) -> bool:
	if space == null:
		return false
	var local := space.to_local(at)
	for z in mask_zones:
		if z.has_point(local):
			return true
	return false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if not multiplayer.is_server() or not active:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
	_listen_to_bodies(delta)
	match state:
		"turning":
			_face(target_point)
			_timer -= delta
			_stand()
			if _timer <= 0.0:
				state = "investigating"
				_timer = FORGET_TIME
		"investigating":
			_timer -= delta
			if _try_catch():
				return
			if _walk_to(target_point, SPEED) or _timer <= 0.0:
				_settle()
		"roaming":
			if _try_catch():
				return
			if _walk_to(target_point, ROAM_SPEED):
				_settle()
		"grabbing":
			_stand()
			_timer -= delta
			if held and (not is_instance_valid(held) or not held.is_inside_tree()):
				held = null
				_settle()
			elif _timer <= 0.0:
				_throw()
		"recovering":
			_stand()
			_timer -= delta
			if _timer <= 0.0:
				state = "listening"
		_:
			_stand()
			_quiet += delta
			if _quiet >= ROAM_AFTER and not roam_points.is_empty():
				_roam()
	move_and_slide()
	_shove_doors()


## Host: every body's speed says how loud it is. Puppets have no footsteps of their
## own, so this is how a client's sprint reaches it.
func _listen_to_bodies(delta: float) -> void:
	var seen := {}
	for p in _players():
		seen[p] = true
		var now: Vector3 = p.global_position
		if _last_pos.has(p) and p != held and not _thrown(p):
			var moved: Vector3 = now - _last_pos[p]
			moved.y = 0.0
			var speed := moved.length() / maxf(delta, 0.001)
			if speed > Player.WALK_SPEED + 0.5 and speed < TELEPORT_SPEED and not CrewVitals.is_down(p):
				hear(now, SPRINT_LOUDNESS)
		_last_pos[p] = now
	for p in _last_pos.keys():
		if not seen.has(p):
			_last_pos.erase(p)


## A shut door it walks into swings open ahead of it, if it swings away from it and
## isn't locked: it pushes, it can't pull. Side rooms stay safe anyway: their doorways
## are too narrow for its navigation.
func _shove_doors() -> void:
	for i in get_slide_collision_count():
		var door := get_slide_collision(i).get_collider() as Door
		if door == null or not door.is_hinged() or door.locked or door.is_open:
			continue
		# Which side of the door the leaf's middle ends up on once open, and which side
		# it stands on: only the component through the door counts, not along it.
		var open_side: Vector3 = door.hinge + Basis(Vector3.UP, deg_to_rad(door.swing_deg)) * -door.hinge
		var through: Vector3 = door.global_basis.z if door.size.x > door.size.z else door.global_basis.x
		var leaf_side: float = (door.get_parent().to_global(door.position + open_side) - door.global_position).dot(through)
		var my_side: float = (global_position - door.global_position).dot(through)
		if leaf_side * my_side >= 0.0:
			continue  # it would swing into it: it can push, not pull
		var sync := LevelSync.of(self)
		if sync:
			sync.run_on(door, "set_open", [true])
		else:
			door.set_open(true)


## Walk toward `to`; true once it's there.
func _walk_to(to: Vector3, speed: float) -> bool:
	var flat := Vector3(to.x - global_position.x, 0, to.z - global_position.z)
	if flat.length() < 0.9:
		return true
	_agent.target_position = to
	var next := _agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0
	if dir.length() < 0.05:
		dir = flat
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(global_position + dir)
	return false


func _stand() -> void:
	velocity.x = 0
	velocity.z = 0


func _settle() -> void:
	state = "listening"
	_quiet = 0.0
	_pose_arms(0.6, 0.3)


func _roam() -> void:
	_roam_i = (_roam_i + 1 + _rng.randi_range(0, roam_points.size() - 2)) % roam_points.size() if roam_points.size() > 1 else 0
	target_point = space.to_global(roam_points[_roam_i]) if space else roam_points[_roam_i]
	state = "roaming"
	_quiet = 0.0


## In the air after a throw (this machine's player; puppets don't say).
func _thrown(p: Node) -> bool:
	var combat = p.get("combat")
	return combat != null and combat.thrown


## Anyone standing within reach, with nothing between: it has them.
func _try_catch() -> bool:
	for p in _players():
		if CrewVitals.is_down(p) or _thrown(p):
			continue
		if global_position.distance_to(p.global_position) < CATCH_RANGE and _can_reach(p):
			_grab(p)
			return true
	return false


func _grab(p: Node3D) -> void:
	held = p
	state = "grabbing"
	_timer = GRAB_TIME
	_stand()
	_face(p.global_position)
	_pose_arms(-1.4, 0.0)
	if crew:
		crew.grab(p, self)
	caught.emit(p)


func _throw() -> void:
	var p := held
	held = null
	state = "recovering"
	_timer = RECOVER_TIME
	_pose_arms(-0.4, 0.5)
	if p and is_instance_valid(p) and crew:
		crew.release(p)
		crew.throw(p, global_position, THROW_FORCE, THROW_DAMAGE, "shredder")
	threw.emit(p)


## Nothing solid between it and them: a shut door or a shelf keeps them safe.
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


## Arms: hanging (0), spread to listen (0.6), raised to hold (-1.4).
func _pose_arms(raise: float, spread: float) -> void:
	for i in _arms.size():
		_arms[i].rotation = Vector3(raise, 0, spread * (1 if i == 0 else -1))
