class_name Staffer
extends CharacterBody3D
## A night-shift staffer (Level 5): a real person, hiding behind a locked door
## while the Mimics wear their face. Once the crew has an escort pass logged for
## their badge, they come out and walk to the stairs, and wait there for everyone.
## Up close their lanyard reads their own name and badge, the one the badge log
## has at their hiding place. The host runs them; clients mirror.

signal arrived

const SPEED := 2.0
const HEIGHT := 1.75

## "hiding", "walking", "waiting".
var state := "hiding"
var staff_name := ""
var first_name := ""
var badge := ""
var dept := ""
## Where they go once passed (world space).
var goal := Vector3.ZERO
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _agent: NavigationAgent3D
var _body: Node3D


func _ready() -> void:
	add_to_group("npc")
	add_to_group("interactable")
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
	_part(CapsuleMesh.new(), Vector3(0, 1.12, 0), Color(0.45, 0.55, 0.7), Vector3(0.4, 0.48, 0.26))
	for side in [-1, 1]:
		_part(CapsuleMesh.new(), Vector3(side * 0.11, 0.42, 0), Color(0.25, 0.25, 0.3), Vector3(0.14, 0.44, 0.14))
		_part(CapsuleMesh.new(), Vector3(side * 0.27, 1.1, 0), Color(0.45, 0.55, 0.7), Vector3(0.09, 0.38, 0.09))
	_part(SphereMesh.new(), Vector3(0, 1.58, 0), Color(0.72, 0.6, 0.5), Vector3(0.22, 0.24, 0.22))
	_part(BoxMesh.new(), Vector3(0, 1.08, 0.14), Color(0.9, 0.9, 0.85), Vector3(0.09, 0.06, 0.01)).name = "Lanyard"
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 0.8
	_agent.radius = 0.35
	_agent.height = HEIGHT
	add_child(_agent)
	_crouch(true)


func _part(mesh: PrimitiveMesh, pos: Vector3, color: Color, scale_v: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = Greybox.mat(color, 0.0, 0.8)
	_body.add_child(mi)
	return mi


func sync_properties() -> Array:
	return [".:position", ".:rotation", ".:state", "Body:position"]


func get_prompt(_player: Node) -> String:
	return "%s  -  %s\nBadge %s" % [staff_name, dept, badge]


func interact(_player: Node) -> void:
	pass


## Hide them somewhere, facing `look`, down behind whatever's there.
func hide_at(at: Vector3, look: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	state = "hiding"
	_face(look)
	_crouch(true)


## Their escort pass is logged: they get up and head for the stairs.
func rescue(to: Vector3) -> void:
	if state != "hiding":
		return
	goal = to
	state = "walking"
	_crouch(false)
	_agent.target_position = to


func _crouch(down: bool) -> void:
	_body.position.y = -0.5 if down else 0.0


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if state == "walking":
		var dir := _agent.get_next_path_position() - global_position
		dir.y = 0.0
		if _agent.is_navigation_finished() or global_position.distance_to(goal) < 1.0:
			state = "waiting"
			velocity.x = 0.0
			velocity.z = 0.0
			arrived.emit()
		elif dir.length() > 0.05:
			dir = dir.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			_face(global_position + dir)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.05:
		look_at(flat, Vector3.UP)
