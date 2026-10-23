class_name Custodian
extends CharacterBody3D
## The Custodian (Level 4). The building's big maintenance robot, loose once the
## containment doors open. It is slow, but it doesn't tire and it can't be blocked:
## anyone it reaches it grabs, and it drags them back toward its charging bay. If it
## gets them there, they're down (in co-op a teammate can still help them up).
##
## Teammates free whoever it holds in two ways:
##   - hit it (STRIKES_TO_FREE strikes while it's dragging someone): it lets go and
##     shudders to a stop for a moment;
##   - cut its power by code (the level calls set_powered(false) from its handler):
##     it drops whoever it holds and stands dead until powered again.
## It can't be destroyed. Every strike shows on it (scorch marks and sparks, slower).
##
## Co-op: simulated on the host (sync.replicate(custodian, custodian.sync_properties())
## in the level's net_setup). The grab goes through CrewVitals, so it lands on the
## machine that owns the player; a client's strike is forwarded to the host.
## Power is shared state: call set_powered from a sync.event handler, on every machine.

## Out of its bay and hunting (host).
signal activated
## It has hold of someone (host).
signal caught(player: Node)
## It let go of someone before reaching the bay: "struck", "power" or "down" (host).
signal freed(player: Node, how: String)
## It got someone back to its bay (host).
signal docked(player: Node)

const HEIGHT := 2.3
const BODY_HEIGHT := 2.1
## Slower than a walk: you can always get away from it if you see it coming.
const SPEED := 3.0
## Hauling someone, it's slower still: time for the crew to act.
const DRAG_SPEED := 1.5
## It sees this far, if nothing is in the way.
const SIGHT_RANGE := 12.0
const CATCH_RANGE := 1.4
## The grab itself: it can't be blocked.
const GRAB_DAMAGE := 10.0
## Strikes by a teammate, while it drags someone, that make it let go.
const STRIKES_TO_FREE := 3
## How long it stands shuddering after it's made to let go (or struck while hunting).
const STUN_TIME := 2.5
const FLINCH_TIME := 0.6
## Strikes for its injuries to look as bad as they get.
const STRIKES_TO_WRECK := 12
## Close enough to the bay to dock whoever it holds.
const BAY_REACH := 1.2
## After docking someone, it stands in the bay this long before it hunts again.
const RECHARGE_TIME := 4.0

## In its bay | hunting | dragging | stunned | recharging | off
var state := "bay"
## Powered: it moves. The level cuts and restores this by code.
var powered := true
## Where it drags people to (world space). Set by the level; defaults to where it starts.
var bay_point := Vector3.ZERO
## The level's CrewVitals, for the grab. Found by itself if the level doesn't set it.
var crew: Node
## Who it's after, or holding.
var target: Node3D
var held: Node3D
var strikes := 0
var wounds: Injuries
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _agent: NavigationAgent3D
var _body: Node3D
var _arms: Array[Node3D] = []
var _lamp: MeshInstance3D
var _timer := 0.0
## Strikes since it grabbed the one it's holding.
var _drag_strikes := 0
var _bay_set := false


func _ready() -> void:
	add_to_group("npc")
	SfxCombat.watch(self)  # punches landing on it, heard on every machine
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, BODY_HEIGHT, 0.9)
	shape.shape = box
	shape.position.y = BODY_HEIGHT / 2
	add_child(shape)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var paint := Color(0.78, 0.6, 0.16)  # safety yellow, scuffed
	var steel := Color(0.3, 0.31, 0.33)
	_part(BoxMesh.new(), Vector3(0, 0.25, 0), steel, Vector3(1.0, 0.3, 0.9))  # the drive base
	_part(BoxMesh.new(), Vector3(0, 1.1, 0), paint, Vector3(0.85, 1.4, 0.7))  # the body
	_part(BoxMesh.new(), Vector3(0, 1.95, -0.05), steel, Vector3(0.5, 0.3, 0.45))  # sensor head
	_lamp = _part(BoxMesh.new(), Vector3(0, 1.97, -0.29), Color(0.9, 0.5, 0.1), Vector3(0.36, 0.06, 0.02))
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "ArmL" if side < 0 else "ArmR"
		pivot.position = Vector3(side * 0.52, 1.6, 0)
		_body.add_child(pivot)
		var arm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 1.1, 0.18)
		arm.mesh = bm
		arm.position = Vector3(0, -0.55, 0)
		arm.material_override = Greybox.mat(steel, 0.3, 0.6)
		pivot.add_child(arm)
		_arms.append(pivot)
	_pose_arms(0.0)
	_show_power()
	wounds = Injuries.attach(self, Injuries.Kind.MACHINE)

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 0.8
	_agent.radius = 0.5
	_agent.height = BODY_HEIGHT
	add_child(_agent)
	if not _bay_set:
		bay_point = global_position


func _part(mesh: PrimitiveMesh, pos: Vector3, color: Color, scale_v: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = Greybox.mat(color, 0.2, 0.7)
	_body.add_child(mi)
	return mi


## Co-op: what clients mirror from the host, which runs it.
func sync_properties() -> Array:
	return [".:position", ".:rotation", ".:state", ".:strikes", "Body/ArmL:rotation", "Body/ArmR:rotation"]


## Where its charging bay is (world space): where it drags people.
func set_bay(at: Vector3) -> void:
	bay_point = at
	_bay_set = true


## Out of its bay: it hunts from now on (the containment doors opened).
func activate() -> void:
	if state != "bay":
		return
	state = "hunting"
	activated.emit()


func is_active() -> bool:
	return state != "bay"


## Cut or restore its power. Shared state: call it on every machine (from a
## sync.event handler). Cut, it drops whoever it holds and stands dead.
func set_powered(on: bool) -> void:
	if powered == on:
		return
	powered = on
	_show_power()
	if not on:
		_let_go("power")
		target = null
		_stand()
		_pose_arms(0.35)
	elif state == "off":
		state = "hunting"
		_pose_arms(0.0)


## Where the one it holds hangs: lifted, in front of it.
func grab_point() -> Vector3:
	return global_position + -global_basis.z * 1.0 + Vector3.UP * 0.9


## The player struck it. A client's strike goes to the host, which runs it.
func take_hit(by: Node3D) -> void:
	var sync := LevelSync.of(self)
	if sync and sync.forward(self, "take_hit"):
		return
	if by == held:
		return  # held, you can't reach it
	strikes += 1
	if state == "dragging":
		_drag_strikes += 1
		if _drag_strikes >= STRIKES_TO_FREE:
			_let_go("struck")
			_stun(STUN_TIME)
	elif state == "hunting":
		_stun(FLINCH_TIME)


## Clients don't run its physics (the host does), so wounds follow strikes here.
func _process(_delta: float) -> void:
	_show_wounds()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if not multiplayer.is_server():
		_stand()
		move_and_slide()
		return
	if not powered or state == "bay":
		_stand()
		move_and_slide()
		return
	match state:
		"hunting":
			_hunt()
		"dragging":
			_drag()
		"stunned", "recharging":
			_stand()
			_timer -= delta
			if _timer <= 0.0:
				state = "hunting"
				_pose_arms(0.0)
	move_and_slide()


func _hunt() -> void:
	if target == null or not _can_chase(target):
		target = _nearest_visible()
	if target == null:
		# Nobody in sight: back to the bay to wait.
		if _walk_to(bay_point, SPEED * _limp()):
			_stand()
		return
	if global_position.distance_to(target.global_position) < CATCH_RANGE and _can_see(target):
		_grab(target)
		return
	_walk_to(target.global_position, SPEED * _limp())


func _drag() -> void:
	if held == null or not is_instance_valid(held) or not held.is_inside_tree():
		held = null
	elif CrewVitals.is_down(held):
		_let_go("down")
	if held == null:
		state = "hunting"
		_pose_arms(0.0)
		return
	if _walk_to(bay_point, DRAG_SPEED * _limp(), BAY_REACH):
		_dock()


func _grab(p: Node3D) -> void:
	held = p
	target = p
	state = "dragging"
	_drag_strikes = 0
	_stand()
	_face(p.global_position)
	_pose_arms(-1.3)
	_hold(p, true)
	if p.has_method("take_damage"):
		p.take_damage(GRAB_DAMAGE, "custodian")
	caught.emit(p)


## Back in the bay with them: they're down.
func _dock() -> void:
	var p := held
	held = null
	target = null
	_hold(p, false)
	state = "recharging"
	_timer = RECHARGE_TIME
	_pose_arms(0.0)
	_stand()
	if p and p.has_method("take_damage"):
		p.take_damage(1000.0, "custodian")
	docked.emit(p)


func _let_go(how: String) -> void:
	if held == null:
		return
	var p := held
	held = null
	target = null
	if is_instance_valid(p):
		_hold(p, false)
	freed.emit(p, how)


func _stun(t: float) -> void:
	if not powered:
		return
	_timer = maxf(_timer, t) if state == "stunned" else t
	state = "stunned"
	_stand()
	_pose_arms(0.5)


## Take hold of `p` or let go, on whichever machine owns them (through the crew);
## in a world with no crew (tests, the gym), straight on the player.
func _hold(p: Node3D, on: bool) -> void:
	if crew == null:
		crew = CrewVitals.of(self)
	if crew and crew.players:
		if on:
			crew.grab(p, self)
		else:
			crew.release(p)
		return
	var combat = p.get("combat")
	if combat == null:
		return
	if on:
		combat.grab(self)
	else:
		combat.release()


## Its injuries follow its strikes (synced), so every machine shows the same.
func _show_wounds() -> void:
	if wounds:
		wounds.severity = minf(1.0, float(strikes) / STRIKES_TO_WRECK)


func _limp() -> float:
	return wounds.speed_scale() if wounds else 1.0


func _show_power() -> void:
	if _lamp:
		_lamp.visible = powered
	if not powered:
		state = "off" if state != "bay" else "bay"


func _can_chase(p: Node3D) -> bool:
	return is_instance_valid(p) and p.is_inside_tree() and not CrewVitals.is_down(p) and not _held_elsewhere(p) \
		and global_position.distance_to(p.global_position) < SIGHT_RANGE * 1.5


## Someone already being held (by another Custodian) or thrown isn't a target.
func _held_elsewhere(p: Node) -> bool:
	var combat = p.get("combat")
	return combat != null and (combat.thrown or (combat.grabbed_by != null and combat.grabbed_by != self))


func _nearest_visible() -> Node3D:
	var best: Node3D
	var best_d := SIGHT_RANGE
	for p in _players():
		if CrewVitals.is_down(p) or _held_elsewhere(p):
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best_d and _can_see(p):
			best = p
			best_d = d
	return best


## Nothing solid between it and them: a shut door keeps them safe.
func _can_see(p: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.9, p.global_position + Vector3.UP * 1.0, 0xFFFFFFFF, [get_rid(), p.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Walk toward `to`; true once within `reach`.
func _walk_to(to: Vector3, speed: float, reach: float = 0.9) -> bool:
	var flat := Vector3(to.x - global_position.x, 0, to.z - global_position.z)
	if flat.length() < reach:
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
	if state == "dragging":
		_face(global_position - dir)  # it backs toward the bay, facing the one it hauls
	else:
		_face(global_position + dir)
	return false


func _stand() -> void:
	velocity.x = 0
	velocity.z = 0


## Players in this world (tests run several co-op worlds in one process).
func _players() -> Array:
	return get_tree().get_nodes_in_group("player").filter(func(p): return p.get_viewport() == get_viewport())


func _face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.05:
		look_at(flat, Vector3.UP)


## Arms: down (0), raised to hold (-1.3), slumped (0.35).
func _pose_arms(raise: float) -> void:
	for a in _arms:
		a.rotation = Vector3(raise, 0, 0)
