class_name Rourke
extends CharacterBody3D
## Dale Rourke, the friendly escort who is secretly working for the director.
## Tour guide in Levels 0 and 1, attacker in Level 2. In a fight he leans in
## before each swing (the cue to block, right mouse), shows his injuries instead
## of a health bar (Injuries: torn jacket, blood, a limp that slows him), and
## reels back when a swing is blocked.

signal arrived
signal downed
signal resolved(fate: String)  # "killed" or "tied"
signal hit_player
signal struck  # the player landed a hit that didn't put him down

enum State { IDLE, WALK, CHASE, STAGGER, DOWN, TIED, DEAD }

const WALK_SPEED := 1.9
const CHASE_SPEED := 4.4
const ATTACK_RANGE := 1.5
const ATTACK_DAMAGE := 22.0
const ATTACK_COOLDOWN := 1.15
const MAX_HITS := 4
const DOWN_TIME := 12.0
## A blocked swing knocks him off balance this long: a free hit for whoever's close.
const RECOIL_TIME := 0.8

var state := State.IDLE
var target: Node3D
## Hits to bring him down. Levels raise it with more players.
var max_hits := MAX_HITS
var hits_left := MAX_HITS
## How long he stays down before getting up again. Levels can keep him down.
var down_time := DOWN_TIME
## Who can tie him up: Callable(player) -> bool. Unset, anyone can.
var can_tie: Callable
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _agent: NavigationAgent3D
var _body: Node3D
var _attack_cd := 0.0
var _windup := 0.0
var _down_timer := 0.0
var _stagger := 0.0
var _walk_target := Vector3.ZERO
var _walk_direct := false
var _walk_time := 0.0
var _retarget := 0.0
## While standing (IDLE), he turns to keep facing this: the crew he's talking to.
var watch: Node3D
## What the fight has done to him, for everyone to see.
var wounds: Injuries


func _ready() -> void:
	add_to_group("npc")
	SfxCombat.watch(self)  # punches landing on him and his swings, heard on every machine
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	_body = Node3D.new()
	add_child(_body)
	_part(_body, CapsuleMesh.new(), Vector3(0, 0.95, 0), Color(0.18, 0.22, 0.32))  # navy work jacket
	_part(_body, SphereMesh.new(), Vector3(0, 1.68, 0), Color(0.82, 0.66, 0.55), Vector3(0.24, 0.27, 0.24))
	_part(_body, BoxMesh.new(), Vector3(0.12, 1.25, -0.3), Color(0.9, 0.9, 0.85), Vector3(0.09, 0.12, 0.02))  # badge
	(_body.get_child(0).mesh as CapsuleMesh).radius = 0.3
	(_body.get_child(0).mesh as CapsuleMesh).height = 1.5

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.6
	_agent.radius = 0.35
	add_child(_agent)
	wounds = Injuries.attach(self)


func _part(parent: Node3D, mesh: PrimitiveMesh, pos: Vector3, color: Color, scale_v: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = Greybox.mat(color, 0.0, 0.8)
	parent.add_child(mi)


## Walk to `pos` and emit `arrived`. `direct` walks a straight line instead of
## following the navigation mesh: for short scripted steps (through a doorway,
## between waypoints) where the path is known to be clear.
func walk_to(pos: Vector3, direct: bool = false) -> void:
	_walk_target = pos
	_walk_direct = direct
	_walk_time = 0.0
	_agent.target_position = pos
	state = State.WALK


func start_chase(player: Node3D) -> void:
	target = player
	state = State.CHASE


func reset_fight(at: Transform3D) -> void:
	global_transform = at
	remove_from_group("interactable")
	hits_left = max_hits
	wounds.severity = 0.0
	_body.rotation = Vector3.ZERO
	_body.position = Vector3.ZERO
	state = State.CHASE if target else State.IDLE


func face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.05:
		look_at(flat, Vector3.UP)


## Every machine (clients don't run his physics): his injuries follow the fight.
func _process(_delta: float) -> void:
	_show_wounds()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	_attack_cd = max(0.0, _attack_cd - delta)
	match state:
		State.WALK:
			_walk_time += delta
			if _walk_direct:
				_move_straight(WALK_SPEED)
			else:
				_move_along_path(WALK_SPEED)
			var flat := Vector3(_walk_target.x - global_position.x, 0, _walk_target.z - global_position.z)
			# Navigation can report "finished" before it has a path at all, so only
			# trust it once he has been walking a moment.
			var nav_done := not _walk_direct and _walk_time > 0.5 and _agent.is_navigation_finished()
			# A scripted step someone is standing in the way of mustn't hang the story.
			var gave_up := _walk_direct and _walk_time > 8.0
			if flat.length() < (0.25 if _walk_direct else 0.7) or nav_done or gave_up:
				velocity.x = 0
				velocity.z = 0
				state = State.IDLE
				arrived.emit()
		State.CHASE:
			_chase(delta)
		State.STAGGER:
			_stagger -= delta
			velocity.x = move_toward(velocity.x, 0, 12 * delta)
			velocity.z = move_toward(velocity.z, 0, 12 * delta)
			if _stagger <= 0.0:
				state = State.CHASE
		State.DOWN:
			velocity.x = 0
			velocity.z = 0
			_down_timer -= delta
			if _down_timer <= 0.0:
				_get_up()
		_:
			velocity.x = 0
			velocity.z = 0
			if state == State.IDLE and watch and is_instance_valid(watch):
				_turn_toward(watch.global_position, delta)
	move_and_slide()


func _move_straight(speed: float) -> void:
	var dir := _walk_target - global_position
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir.length() > 0.1:
		face(global_position + dir)


## Turn a little each frame to face `point`, like someone keeping an eye on you.
func _turn_toward(point: Vector3, delta: float) -> void:
	var to := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	if to.length() < 0.2:
		return
	var want := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, want, minf(1.0, 4.0 * delta))


func _move_along_path(speed: float) -> void:
	var next := _agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0
	if dir.length() < 0.05:
		dir = _agent.target_position - global_position
		dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir.length() > 0.1:
		face(global_position + dir)


func _chase(delta: float) -> void:
	_retarget -= delta
	if _retarget <= 0.0 or CrewVitals.is_down(target):
		_retarget = 0.5
		target = _nearest_player()
	if not target:
		velocity.x = 0
		velocity.z = 0
		return
	var dist := global_position.distance_to(target.global_position)
	face(target.global_position)
	if _windup > 0.0:
		_windup -= delta
		velocity.x = 0
		velocity.z = 0
		if _windup <= 0.0:
			_body.rotation.x = 0.0
			if global_position.distance_to(target.global_position) < ATTACK_RANGE + 0.4 and target.has_method("take_damage"):
				target.take_damage(ATTACK_DAMAGE, "rourke")
				hit_player.emit()
			_attack_cd = ATTACK_COOLDOWN
		return
	if dist < ATTACK_RANGE and _attack_cd <= 0.0:
		_windup = 0.4
		_body.rotation.x = -0.25  # lean in: a readable tell before the hit
		return
	_agent.target_position = target.global_position
	_move_along_path(CHASE_SPEED * wounds.speed_scale())


## Co-op: what other machines need to see him walk, fight and fall.
func sync_properties() -> Array:
	var body := str(get_path_to(_body))
	# _windup is his attack tell: clients must see it coming too.
	# hits_left: how hurt he looks.
	return [".:position", ".:rotation", ".:visible", ".:state", ".:_windup", ".:hits_left", ".:max_hits", body + ":position", body + ":rotation"]


## In co-op he goes after whoever is closest and still on their feet.
func _nearest_player() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("player"):
		if p.get_viewport() != get_viewport() or CrewVitals.is_down(p):
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


## A co-op client sends hits and choices to the host, which runs the fight.
func _forwarded(method: String) -> bool:
	var sync := LevelSync.of(self)
	return sync != null and sync.forward(self, method)


## The player struck him.
func take_hit(by: Node3D) -> void:
	if _forwarded("take_hit"):
		return
	if state != State.CHASE and state != State.STAGGER:
		return
	hits_left -= 1
	_windup = 0.0
	_body.rotation.x = 0.0
	var push := (global_position - by.global_position)
	push.y = 0
	velocity = push.normalized() * 5.0
	if hits_left <= 0:
		_go_down()
	else:
		state = State.STAGGER
		_stagger = 0.55
		struck.emit()


## Someone blocked his swing: he's thrown off balance for a moment.
func recoil() -> void:
	if state != State.CHASE:
		return
	_windup = 0.0
	_body.rotation.x = 0.0
	_attack_cd = maxf(_attack_cd, RECOIL_TIME)
	state = State.STAGGER
	_stagger = RECOIL_TIME
	if target:
		var push := global_position - target.global_position
		push.y = 0
		velocity = push.normalized() * 3.0


## Injuries follow how many hits he has left (synced), so every machine shows the same.
func _show_wounds() -> void:
	var hurt := 0.0
	if state in [State.DOWN, State.TIED, State.DEAD]:
		hurt = 1.0
	elif max_hits > 0 and state in [State.CHASE, State.STAGGER]:
		hurt = 1.0 - float(hits_left) / max_hits
	elif wounds.severity > 0.0:
		hurt = wounds.severity  # a fight that's over stays on him
	if not is_equal_approx(hurt, wounds.severity):
		wounds.severity = hurt


func _go_down() -> void:
	state = State.DOWN
	_down_timer = down_time
	_body.rotation.x = -PI / 2
	_body.position = Vector3(0, 0.3, 0.9)
	add_to_group("interactable")
	downed.emit()


func _get_up() -> void:
	remove_from_group("interactable")
	hits_left = 2
	_body.rotation = Vector3.ZERO
	_body.position = Vector3.ZERO
	state = State.CHASE


func get_prompt(player: Node) -> String:
	if state != State.DOWN:
		return ""
	if not _may_tie(player):
		return "[X] Finish it"
	return "[E] Tie him up with network cable    [X] Finish it"


func _may_tie(player: Node) -> bool:
	return not can_tie.is_valid() or can_tie.call(player)


func interact(player: Node) -> void:
	if _forwarded("interact"):
		return
	if state != State.DOWN or not _may_tie(player):
		return
	state = State.TIED
	remove_from_group("interactable")
	_body.rotation.x = -PI / 2
	resolved.emit("tied")


func interact_alt(_player: Node) -> void:
	if _forwarded("interact_alt"):
		return
	if state != State.DOWN:
		return
	state = State.DEAD
	remove_from_group("interactable")
	resolved.emit("killed")
