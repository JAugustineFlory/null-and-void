class_name PlayerPuppet
extends AnimatableBody3D
## Another player, as seen on this machine. It follows the position that
## player's machine sends, has a body you can bump into, and a flashlight.
## Damage dealt to it here is sent to the machine that owns that player.

const SNAP_DISTANCE := 4.0
const FOLLOW_RATE := 14.0

var peer_id := 0
var display_name := ""
var crouching := false
var health := 100.0
var players: Node  # NetPlayers

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _target_pitch := 0.0
var _has_state := false
var _body: Node3D
var _head: Node3D
var _light: SpotLight3D
var _tag: Label3D


static func create(parent: Node, id: int, player_name: String, color: Color) -> PlayerPuppet:
	var p := PlayerPuppet.new()
	p.peer_id = id
	p.display_name = player_name
	p.name = str(id)
	p._build(color)
	parent.add_child(p)
	return p


func _build(color: Color) -> void:
	add_to_group("player")
	add_to_group("puppet")
	sync_to_physics = false
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.45
	torso.mesh = cm
	torso.position.y = 0.78
	torso.material_override = Greybox.mat(color, 0.0, 0.8)
	_body.add_child(torso)

	_head = Node3D.new()
	_head.name = "Head"
	_head.position.y = 1.62
	_body.add_child(_head)
	var skull := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	skull.mesh = sm
	skull.material_override = Greybox.mat(Color(0.8, 0.66, 0.55), 0.0, 0.8)
	_head.add_child(skull)
	var lamp := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.06, 0.06, 0.16)
	lamp.mesh = lm
	lamp.position = Vector3(0.18, -0.15, -0.12)
	lamp.material_override = Greybox.mat(Color(0.1, 0.1, 0.1))
	_head.add_child(lamp)

	_light = SpotLight3D.new()
	_light.spot_range = 18.0
	_light.spot_angle = 26.0
	_light.spot_attenuation = 0.8
	_light.light_energy = 2.4
	_light.light_color = Color(1.0, 0.95, 0.82)
	_light.shadow_enabled = true
	_light.position = Vector3(0.18, -0.15, -0.2)
	_head.add_child(_light)

	_tag = Label3D.new()
	_tag.text = display_name
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.font_size = 40
	_tag.pixel_size = 0.004
	_tag.modulate = Color(1, 1, 1, 0.7)
	_tag.outline_size = 8
	_tag.position.y = 2.1
	add_child(_tag)


## A state update from the owning machine.
func apply_state(pos: Vector3, yaw: float, pitch: float, crouch: bool, light_on: bool) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_target_pitch = pitch
	_light.visible = light_on
	if crouch != crouching:
		crouching = crouch
		_body.scale.y = 0.5 if crouch else 1.0
	if not _has_state or global_position.distance_to(pos) > SNAP_DISTANCE:
		global_position = pos
		rotation.y = yaw
	_has_state = true


func _physics_process(delta: float) -> void:
	if not _has_state:
		return
	var k: float = clamp(delta * FOLLOW_RATE, 0.0, 1.0)
	global_position = global_position.lerp(_target_pos, k)
	rotation.y = lerp_angle(rotation.y, _target_yaw, k)
	_head.rotation.x = lerp_angle(_head.rotation.x, _target_pitch, k)


func take_damage(amount: float) -> void:
	if players:
		players.hurt(peer_id, amount)


func flashlight_on() -> bool:
	return _light.visible
