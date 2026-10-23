class_name PlayerPuppet
extends AnimatableBody3D
## Another player, as seen on this machine. It follows the position that
## player's machine sends, has a body you can bump into, and a flashlight.
## Damage dealt to it here is sent to the machine that owns that player.

const SNAP_DISTANCE := 4.0
const STAND_HEIGHT := 1.8
## At or below this the player is on hands and knees (Player.CRAWL_HEIGHT).
const CRAWL_HEIGHT := 0.85
const FOLLOW_RATE := 14.0
## The hip joint is this far above the underside of the thigh.
const SEAT_THIGH := 0.06
## How far to the side of a terminal's stand point a teammate typing at it is
## drawn, so the people behind them can read the screen over their shoulder.
const TERMINAL_STEP_ASIDE := 0.55
## How a player is sitting (sent with their position): not, on a chair, on the floor.
enum Sit { NONE, CHAIR, FLOOR }
## What their fists can be doing, as FirstPersonBody plays it on their own machine.
const FIGHT_ACTIONS := ["jab", "cross", "guard", "recoil", "flinch"]

var peer_id := 0
var display_name := ""
var crouching := false
var crawling := false
## How tall the owner's body is right now, as their machine sends it: 1.8
## standing, 1.25 crouching, 0.85 crawling, and anything in between.
var stance_height := STAND_HEIGHT
var health := 100.0
## Lying on the floor at 0 health (CrewVitals keeps this the same everywhere).
var downed := false
## Their fists right now (FIGHT_ACTIONS), or "" when they aren't fighting.
var fighting := ""
var players: Node  # NetPlayers
## The teammate's body, posed from the synced position, stance and look.
var rig: CharacterRig
## Sitting down (Sit): on a chair the owner's position is the seat's top, so
## the body is lowered to put the hips there; on the floor it stays put.
var sitting := Sit.NONE
## The terminal they're sitting at, if any (set by TerminalMirror).
var at_terminal: Node3D
## Which side of it they lean in from: 1 right, -1 left.
var terminal_side := 1.0
## On a chair: the way they faced when they sat down. Their legs stay facing
## it while they look around, and only the upper body turns (rig.twist).
var seat_yaw := 0.0

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _target_pitch := 0.0
var _has_state := false
var _head: Node3D
var _light: SpotLight3D
var _tag: Label3D
var _capsule: CapsuleShape3D
var _shape: CollisionShape3D
## Holds the rig, so it can be lowered onto a chair (the rig sets its own position).
var _body: Node3D
## How high the hips are above the feet in the rig's "sit" pose, for this body's height.
var _sit_hip := 0.42


## `look` is how they look (a CharacterLooks dictionary, see NetPlayers.look_for).
static func create(parent: Node, id: int, player_name: String, look: Dictionary, at: Transform3D) -> PlayerPuppet:
	var p := PlayerPuppet.new()
	p.peer_id = id
	p.display_name = player_name
	p.name = str(id)
	p._build(look)
	SfxSteps.attach(p)  # a teammate's footsteps, from how their body moves here
	p.transform = at  # before entering the world, so it never flashes at the origin
	parent.add_child(p)
	return p


func _build(look: Dictionary) -> void:
	add_to_group("player")
	add_to_group("puppet")
	sync_to_physics = false
	_shape = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.32
	_capsule.height = STAND_HEIGHT
	_shape.shape = _capsule
	_shape.position.y = STAND_HEIGHT / 2
	add_child(_shape)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	rig = CharacterRig.build(_body, look)
	# The rig's hips are 0.87 m up at height 1.0, and "sit" drops them 0.45 m.
	_sit_hip = 0.87 * float(look.get("height", 1.0)) - 0.45

	# The flashlight rides at eye level, in the direction they look.
	_head = Node3D.new()
	_head.name = "Head"
	_head.position.y = STAND_HEIGHT - 0.18
	add_child(_head)
	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	var lm := BoxMesh.new()
	lm.size = Vector3(0.06, 0.06, 0.16)
	lamp.mesh = lm
	lamp.position = Vector3(0.18, -0.15, -0.12)
	# In their flashlight skin's color.
	var torch = look.get("tools", {}).get("flashlight", {}).get("color")
	lamp.material_override = Greybox.mat(torch if torch is Color else Color(0.1, 0.1, 0.1))
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
func apply_state(pos: Vector3, yaw: float, pitch: float, height: float, light_on: bool, sit: int = Sit.NONE) -> void:
	_target_pos = pos
	_target_yaw = yaw
	if sit != sitting:
		set_sitting(sit)
	_target_pitch = pitch
	_light.visible = light_on
	if not is_equal_approx(height, stance_height):
		set_stance(height)
	if not _has_state or global_position.distance_to(pos) > SNAP_DISTANCE:
		global_position = pos
		rotation.y = yaw
	_has_state = true


func _physics_process(delta: float) -> void:
	if not _has_state:
		return
	var k: float = clamp(delta * FOLLOW_RATE, 0.0, 1.0)
	var pos := _target_pos
	var yaw := _target_yaw
	if at_terminal and is_instance_valid(at_terminal):
		# On their own screen they're centred on the glass; here they lean in
		# from the side, turned to it, so the screen stays readable from behind.
		var glass: Vector3 = at_terminal.global_position
		pos += at_terminal.global_basis.x.normalized() * TERMINAL_STEP_ASIDE * terminal_side
		var to_glass := glass - pos
		yaw = atan2(-to_glass.x, -to_glass.z)
	global_position = global_position.lerp(pos, k)
	rotation.y = lerp_angle(rotation.y, yaw, k)
	_head.rotation.x = lerp_angle(_head.rotation.x, _target_pitch, k)
	rig.head_pitch = _head.rotation.x
	# Seated, the legs hold the seat's way and the chest and neck turn instead.
	var turned := angle_difference(seat_yaw, rotation.y) if sitting == Sit.CHAIR else 0.0
	_body.rotation.y = -turned
	rig.twist = turned


## They sat down at `terminal` (null: stood up). `seat` is their place in
## the queue there; neighbours lean in from opposite sides.
func sit_at(terminal: Node3D, seat: int = 0) -> void:
	at_terminal = terminal
	terminal_side = 1.0 if seat % 2 == 0 else -1.0


## Stand, crouch or crawl at the owner's height: the rig poses for it, and
## the collider shrinks too, so a teammate in a vent fits in it.
func set_stance(height: float) -> void:
	stance_height = clampf(height, CRAWL_HEIGHT * 0.5, STAND_HEIGHT)
	crouching = stance_height < STAND_HEIGHT
	crawling = stance_height <= CRAWL_HEIGHT
	rig.stance_height = stance_height
	_capsule.height = maxf(stance_height, _capsule.radius * 2.0)
	_shape.position.y = _capsule.height / 2
	_head.position.y = stance_height - 0.18
	_tag.position.y = stance_height + 0.3


## Their fists, as their own machine plays them ("" when not fighting): the
## punches, the held guard, and recoiling from a block or flinching from a hit.
func set_fight(action: String) -> void:
	action = action if action in FIGHT_ACTIONS else ""
	if action == fighting:
		return
	fighting = action
	if not downed and sitting == Sit.NONE:
		rig.play(action if action != "" else "idle")


## They sat down (Sit.CHAIR or Sit.FLOOR) or got up (Sit.NONE).
func set_sitting(how: int) -> void:
	sitting = how if how in Sit.values() else Sit.NONE
	seat_yaw = _target_yaw
	# Hips on the seat; a little up, since the hip joint is inside the thigh.
	_body.position.y = -(_sit_hip - SEAT_THIGH) if sitting == Sit.CHAIR else 0.0
	if not downed:
		rig.play(["idle", "sit", "sit_floor"][sitting])


func take_damage(amount: float, cause: String = "") -> void:
	if players:
		players.hurt(peer_id, amount, cause)


func set_downed(on: bool) -> void:
	downed = on
	rig.play("down" if on else ["idle", "sit", "sit_floor"][sitting])
	health = 0.0 if on else 100.0


func _crew() -> Node:
	return CrewVitals.of(players.level) if players else null


## E on a teammate: help them up if they're down; otherwise huddle up to share
## notes, or join the huddle they're in.
func get_prompt(_by: Node) -> String:
	if downed:
		var c := _crew()
		return c.revive_prompt(peer_id) if c else ""
	return _huddle_prompt()


func interact(_by: Node) -> void:
	if downed:
		var c := _crew()
		if c:
			c.revive(peer_id)
	elif _huddle_prompt() != "":
		_huddle().huddle_with(peer_id)


func _huddle() -> NotesHuddle:
	var s := LevelSync.of(self)
	return s.huddle if s else null


func _huddle_prompt() -> String:
	var h := _huddle()
	if h == null:
		return ""
	var theirs := h.group_of(peer_id)
	if theirs != 0 and theirs == h.group_of(multiplayer.get_unique_id()):
		return ""
	return "[E] Join the notes huddle" if theirs != 0 else "[E] Huddle up to share notes"


func flashlight_on() -> bool:
	return _light.visible
