class_name Mimic
extends CharacterBody3D
## A Mimic (Level 5). It wears a staffer's face and sits at their desk, or stands
## with its back turned, and it walks away whenever somebody looks at it: out of
## the room, round a corner, gone. Unseen again, it turns up somewhere else on the
## floor, closer. It never attacks: the danger is where its voice sends you.
##
## Up close its lanyard reads: a staffer's name over a badge number that isn't
## theirs (the badge log is how the crew tells faces from people). The host runs it;
## clients mirror it (sync_properties).

signal left(by_sight: bool)

const SPEED := 2.4
const HEIGHT := 1.8
## Looked at from closer than this, it leaves.
const NOTICE_RANGE := 14.0
## How long it waits out of sight before it turns up at its next haunt.
const HAUNT_WAIT := 20.0

## "seated", "standing", "leaving" or "gone".
var state := "standing"
## The staffer whose face it wears, and the badge on its lanyard (not theirs).
var face := ""
var badge := ""
var dept := ""
## Where it goes when looked at (world space): a doorway out of sight.
var retreat := Vector3.ZERO
## Where it turns up next, in order, once it has been chased off (world space).
var haunts: Array = []
var haunt_index := 0
## How many times it has been chased off: the crew's radio gets worse each time.
var times_left := 0
var active := true
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _agent: NavigationAgent3D
var _body: Node3D
var _wait := 0.0


func _ready() -> void:
	add_to_group("npc")
	add_to_group("interactable")  # so looking at it shows the lanyard
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = HEIGHT
	shape.shape = cap
	shape.position.y = HEIGHT / 2
	add_child(shape)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	# Office clothes: a shirt, trousers, a head, and the lanyard down the front.
	_part(CapsuleMesh.new(), Vector3(0, 1.15, 0), Color(0.75, 0.78, 0.82), Vector3(0.4, 0.5, 0.26))
	for side in [-1, 1]:
		_part(CapsuleMesh.new(), Vector3(side * 0.11, 0.42, 0), Color(0.22, 0.22, 0.26), Vector3(0.14, 0.44, 0.14))
		_part(CapsuleMesh.new(), Vector3(side * 0.27, 1.12, 0), Color(0.75, 0.78, 0.82), Vector3(0.09, 0.4, 0.09))
	_part(SphereMesh.new(), Vector3(0, 1.62, 0), Color(0.8, 0.68, 0.58), Vector3(0.22, 0.24, 0.22))
	var lanyard := _part(BoxMesh.new(), Vector3(0, 1.1, 0.14), Color(0.9, 0.9, 0.85), Vector3(0.09, 0.06, 0.01))
	lanyard.name = "Lanyard"
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 0.8
	_agent.radius = 0.35
	_agent.height = HEIGHT
	add_child(_agent)


func _part(mesh: PrimitiveMesh, pos: Vector3, color: Color, scale_v: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = Greybox.mat(color, 0.0, 0.8)
	_body.add_child(mi)
	return mi


## Co-op: what clients mirror from the host.
func sync_properties() -> Array:
	return [".:position", ".:rotation", ".:state", ".:visible", ".:times_left"]


## What you read on its lanyard, up close: the face's name over somebody else's badge.
func get_prompt(_player: Node) -> String:
	if state == "gone" or not visible:
		return ""
	return "%s  -  %s\nBadge %s" % [face, dept, badge]


## Looking is all you can do: there is nothing to say to it.
func interact(_player: Node) -> void:
	pass


## Sit it down at a desk, back to the room, facing `look`.
func seat(at: Vector3, look: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	state = "seated"
	_face(look)
	_body.position.y = -0.35  # down on the chair


## Stand it somewhere, facing `look`.
func stand(at: Vector3, look: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	state = "standing"
	_body.position.y = 0.0
	_face(look)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not active:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	match state:
		"seated", "standing":
			velocity.x = 0.0
			velocity.z = 0.0
			if _watched_from_near():
				_leave()
		"leaving":
			var dir := _agent.get_next_path_position() - global_position
			dir.y = 0.0
			if _agent.is_navigation_finished() or global_position.distance_to(retreat) < 1.0:
				_vanish()
			elif dir.length() > 0.05:
				dir = dir.normalized()
				velocity.x = dir.x * SPEED
				velocity.z = dir.z * SPEED
				_face(global_position + dir)
		"gone":
			velocity.x = 0.0
			velocity.z = 0.0
			_wait -= delta
			if _wait <= 0.0 and not haunts.is_empty():
				_haunt()
	move_and_slide()


## Somebody has it on screen, with nothing in the way, from inside NOTICE_RANGE.
func _watched_from_near() -> bool:
	for p in _players():
		if global_position.distance_to(p.global_position) < NOTICE_RANGE and _player_sees(p):
			return true
	return false


## This player has it on screen with nothing in the way (as the Watcher is seen:
## a player at a terminal is looking at the screen; a co-op puppet sees a cone).
func _player_sees(p: Node) -> bool:
	if p.get("input_locked"):
		return false
	var cam: Camera3D = p.get("camera")
	var head: Node3D = p.get("head")
	if cam == null and head == null:
		return false
	var eye: Node3D = cam if cam else head
	if not eye.is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	for h in [0.5, 1.3]:
		var pt: Vector3 = global_position + Vector3.UP * h
		if cam and not cam.is_position_in_frustum(pt):
			continue
		if not cam and (-eye.global_basis.z).angle_to(pt - eye.global_position) > deg_to_rad(50.0):
			continue
		var q := PhysicsRayQueryParameters3D.create(eye.global_position, pt, 0xFFFFFFFF, [p.get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.collider == self:
			return true
	return false


func _leave() -> void:
	state = "leaving"
	times_left += 1
	_body.position.y = 0.0
	_agent.target_position = retreat
	left.emit(true)


## Out of sight: it isn't there any more.
func _vanish() -> void:
	state = "gone"
	visible = false
	_wait = HAUNT_WAIT


## Back, somewhere else, with its back turned, when nobody can see the spot.
func _haunt() -> void:
	var h: Dictionary = haunts[haunt_index % haunts.size()]
	var p := _players()
	for pl in p:
		if pl.global_position.distance_to(h.at) < 4.0:
			_wait = 2.0  # too close to appear unseen: wait
			return
	haunt_index += 1
	visible = true
	stand(h.at, h.look)
	retreat = h.get("retreat", retreat)


func _players() -> Array:
	return get_tree().get_nodes_in_group("player").filter(func(p): return p.get_viewport() == get_viewport())


func _face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.05:
		look_at(flat, Vector3.UP)
