class_name Custodian
extends CharacterBody3D
## The Custodian (Level 4). Floor 10's maintenance unit: a squat, patient machine that
## lives in the charging bay and runs on the bay's circuit. Until the accident it's
## dormant behind the bay door (it only stirs when the bay's breaker comes on). Loose,
## it patrols the floor and hunts by sight: anyone it sees within SIGHT_RANGE, with
## nothing between, it follows; anyone it reaches it grabs and drags back toward its
## bay. Teammates free you by hitting it, or by cutting its power by code (the
## CHARGING BAY breaker off). WARDEN puts the power back after a while unless the bay
## is locked out, and then it's off for good: sealed.
##
## Co-op: simulated on the host (sync.replicate in the level's net_setup); the grab,
## the drag and the throw at the bay go through CrewVitals, so they land on whichever
## machine owns the player. Combat owns what being grabbed does to a player.

signal woke
## It has hold of someone (host).
signal caught(player: Node)
## It let go: hit, powered off, or it reached the bay (host).
signal let_go(player: Node)

const SPEED := 3.0  # a fast walk: a sprint gets away, a walk doesn't
const ROAM_SPEED := 1.8
const DRAG_SPEED := 1.4
const BODY_HEIGHT := 1.5
const CATCH_RANGE := 1.2
## Sees this far, if nothing's in the way. Crouching in the dark doesn't hide you:
## line of sight does.
const SIGHT_RANGE := 12.0
## Out of sight this long and it goes back to its rounds.
const LOSE_TIME := 4.0
## A hit makes it drop what it holds and stand still this long.
const STAGGER_TIME := 2.5
## At the bay: it lets go with a shove that hurts.
const BAY_DAMAGE := 40.0
const BAY_SHOVE := 4.0
const RECOVER_TIME := 3.0

## Loose and hunting. Dormant (in the bay, or powered off) it does nothing.
var active := false
## Its circuit has power. Off, it stands limp wherever it is.
var powered := false
## Locked out for good (the bay's lockout): never powered again.
var sealed := false
## dormant | roaming | chasing | dragging | stunned | recovering | off
var state := "dormant"
## The level's CrewVitals, for the grab and the shove. Set by the level.
var crew: Node
## The level, whose space `roam_points` and `home` are in.
var space: Node3D
var roam_points: Array[Vector3] = []
## Where it drags people: its bay (level space).
var home := Vector3.ZERO
var held: Node3D
var target: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _agent: NavigationAgent3D
var _body: Node3D
var _eye: MeshInstance3D
var _timer := 0.0
var _unseen := 0.0
var _roam_i := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("npc")
	_rng.seed = 10
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = BODY_HEIGHT
	shape.shape = cap
	shape.position.y = BODY_HEIGHT / 2
	add_child(shape)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var shell := Color(0.62, 0.55, 0.2)  # facilities yellow, scuffed
	_part(BoxMesh.new(), Vector3(0, 0.75, 0), shell, Vector3(0.9, 0.9, 0.8))
	_part(BoxMesh.new(), Vector3(0, 0.15, 0), Color(0.15, 0.15, 0.16), Vector3(0.95, 0.3, 0.85))  # the drive base
	_part(BoxMesh.new(), Vector3(0, 1.35, -0.05), shell.darkened(0.3), Vector3(0.5, 0.3, 0.5))
	for side in [-1, 1]:
		_part(BoxMesh.new(), Vector3(side * 0.55, 0.85, -0.35), Color(0.3, 0.3, 0.32), Vector3(0.12, 0.12, 0.8))  # pincer arms
	_eye = MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(0.3, 0.06, 0.02)
	_eye.mesh = em
	_eye.position = Vector3(0, 1.38, -0.31)
	_body.add_child(_eye)
	_show_eye()
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 0.8
	_agent.radius = 0.45
	_agent.height = BODY_HEIGHT
	add_child(_agent)


func _part(mesh: PrimitiveMesh, pos: Vector3, color: Color, scale_v: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = Greybox.mat(color, 0.0, 0.7)
	_body.add_child(mi)


## Co-op: what clients mirror from the host, which runs it.
func sync_properties() -> Array:
	return [".:position", ".:rotation", ".:state", ".:active", ".:powered"]


func place(at: Vector3, look: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_face(look)


## Released (the accident): out of its bay and on its rounds.
func wake() -> void:
	if active:
		return
	active = true
	powered = not sealed
	state = "roaming" if powered else "off"
	_next_roam()
	_show_eye()
	woke.emit()


## Its circuit came on or went off (the level follows the bay breaker's row).
func set_power(on: bool) -> void:
	on = on and not sealed
	if on == powered:
		return
	powered = on
	if not on:
		_let_go()
		state = "off"
	elif active:
		state = "roaming"
		_next_roam()
	_show_eye()


## Locked out: off now and for good.
func seal() -> void:
	sealed = true
	set_power(false)


## Where the person it's dragging is held: low in front, along the floor.
func grab_point() -> Vector3:
	return global_position + -global_basis.z * 1.0 + Vector3.UP * 0.4


## A teammate struck it: it drops whoever it holds and stops for a moment.
func take_hit(_by: Node3D) -> void:
	var sync := LevelSync.of(self)
	if sync != null and sync.forward(self, "take_hit"):
		return
	if not active or not powered or state in ["off", "stunned"]:
		return
	_let_go()
	state = "stunned"
	_timer = STAGGER_TIME


func _show_eye() -> void:
	if _eye:
		_eye.material_override = Greybox.mat(Color(1.0, 0.3, 0.1) if powered else Color(0.1, 0.05, 0.05), 3.0 if powered else 0.0)


func _physics_process(delta: float) -> void:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return  # the session is closing
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if not multiplayer.is_server() or not active or not powered:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
	match state:
		"roaming":
			if _spot():
				return
			if _walk_to(_roam_target(), ROAM_SPEED):
				_next_roam()
		"chasing":
			if target == null or not is_instance_valid(target) or CrewVitals.is_down(target):
				_back_to_rounds()
			elif _try_catch():
				pass
			else:
				_unseen = 0.0 if _sees(target) else _unseen + delta
				if _unseen > LOSE_TIME:
					_back_to_rounds()
				else:
					_walk_to(target.global_position, SPEED)
		"dragging":
			if held == null or not is_instance_valid(held) or not held.is_inside_tree():
				held = null
				_back_to_rounds()
			elif _walk_to(_home(), DRAG_SPEED):
				_shove_at_bay()
		"stunned", "recovering":
			_stand()
			_timer -= delta
			if _timer <= 0.0:
				_back_to_rounds()
		_:
			_stand()
	move_and_slide()


## Anyone in sight: it follows them.
func _spot() -> bool:
	for p in _players():
		if CrewVitals.is_down(p) or not _sees(p):
			continue
		target = p
		_unseen = 0.0
		state = "chasing"
		return true
	return false


func _sees(p: Node3D) -> bool:
	if global_position.distance_to(p.global_position) > SIGHT_RANGE:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.35, p.global_position + Vector3.UP * 1.0, 0xFFFFFFFF, [get_rid(), p.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _try_catch() -> bool:
	if target == null or global_position.distance_to(target.global_position) > CATCH_RANGE or not _sees(target):
		return false
	held = target
	state = "dragging"
	_stand()
	if crew:
		crew.grab(held, self)
	caught.emit(held)
	return true


## At the bay with someone: a shove that hurts, and it lets go.
func _shove_at_bay() -> void:
	var p := held
	_let_go()
	if p and is_instance_valid(p) and crew:
		crew.throw(p, global_position, BAY_SHOVE, BAY_DAMAGE, "custodian")
	state = "recovering"
	_timer = RECOVER_TIME


func _let_go() -> void:
	var p := held
	held = null
	target = null
	if p and is_instance_valid(p):
		if crew:
			crew.release(p)
		let_go.emit(p)


func _back_to_rounds() -> void:
	target = null
	state = "roaming"
	_next_roam()


func _next_roam() -> void:
	if roam_points.size() > 1:
		_roam_i = (_roam_i + 1 + _rng.randi_range(0, roam_points.size() - 2)) % roam_points.size()


func _roam_target() -> Vector3:
	if roam_points.is_empty():
		return global_position
	return space.to_global(roam_points[_roam_i]) if space else roam_points[_roam_i]


func _home() -> Vector3:
	return space.to_global(home) if space else home


func _walk_to(to: Vector3, speed: float) -> bool:
	var flat := Vector3(to.x - global_position.x, 0, to.z - global_position.z)
	if flat.length() < 0.9:
		_stand()
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


func _players() -> Array:
	return get_tree().get_nodes_in_group("player").filter(func(p): return p.get_viewport() == get_viewport())


func _face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.05:
		look_at(flat, Vector3.UP)
