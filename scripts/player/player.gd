class_name Player
extends CharacterBody3D
## First-person player: walk, sprint, crouch, slide, mantle, crawl through vents,
## flashlight, interact and strike.

signal died

const WALK_SPEED := 3.8
const SPRINT_SPEED := 6.5
const CROUCH_SPEED := 1.9
const JUMP_VELOCITY := 4.3
const SLIDE_SPEED := 9.0
const SLIDE_TIME := 0.8
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 0.85
const RADIUS := 0.32
const MOUSE_SENS := 0.0022
const MANTLE_MAX := 1.6
const STRIKE_RANGE := 2.0
const STRIKE_COOLDOWN := 0.55

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health := 100.0
var crouching := false
var sliding := false
var mantling := false
## True while a terminal or menu has focus.
var input_locked := false
var hud: Node

var _slide_timer := 0.0
var _slide_dir := Vector3.ZERO
var _strike_cd := 0.0
var _height := STAND_HEIGHT
var _bob_t := 0.0

var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var _capsule: CapsuleShape3D
var _collider: CollisionShape3D
var _ray: RayCast3D


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.3
	_collider = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = RADIUS
	_capsule.height = STAND_HEIGHT
	_collider.shape = _capsule
	_collider.position.y = STAND_HEIGHT / 2
	add_child(_collider)

	head = Node3D.new()
	head.position.y = STAND_HEIGHT - 0.12
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 78
	camera.near = 0.05
	camera.current = true
	head.add_child(camera)

	flashlight = SpotLight3D.new()
	flashlight.spot_range = 18.0
	flashlight.spot_angle = 26.0
	flashlight.spot_attenuation = 0.8
	flashlight.light_energy = 3.0
	flashlight.light_color = Color(1.0, 0.95, 0.82)
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.18, -0.15, 0)
	camera.add_child(flashlight)

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -2.4)
	_ray.add_exception(self)
	_ray.collide_with_areas = false
	camera.add_child(_ray)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotation.x = clamp(head.rotation.x - event.relative.y * MOUSE_SENS, -1.45, 1.45)
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
	elif event.is_action_pressed("interact"):
		var target := _look_target()
		if target and target.has_method("interact"):
			target.interact(self)
	elif event.is_action_pressed("alt_interact"):
		var target := _look_target()
		if target and target.has_method("interact_alt"):
			target.interact_alt(self)
	elif event.is_action_pressed("attack"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_strike()


func _physics_process(delta: float) -> void:
	_strike_cd = max(0.0, _strike_cd - delta)
	if mantling:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	var want_crouch := Input.is_action_pressed("crouch") and not input_locked
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if want_crouch and not crouching:
		if Input.is_action_pressed("sprint") and is_on_floor() and flat_speed > WALK_SPEED:
			sliding = true
			_slide_timer = SLIDE_TIME
			_slide_dir = Vector3(velocity.x, 0, velocity.z).normalized()
		_set_crouch(true)
	elif not want_crouch and crouching and not sliding and _can_stand():
		_set_crouch(false)

	if sliding:
		_slide_timer -= delta
		var k: float = clamp(_slide_timer / SLIDE_TIME, 0.0, 1.0)
		var spd: float = lerp(CROUCH_SPEED, SLIDE_SPEED, k)
		velocity.x = _slide_dir.x * spd
		velocity.z = _slide_dir.z * spd
		if _slide_timer <= 0.0 or is_on_wall():
			sliding = false
	else:
		var input := Vector2.ZERO
		if not input_locked:
			input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
		var speed := WALK_SPEED
		if crouching:
			speed = CROUCH_SPEED
		elif Input.is_action_pressed("sprint"):
			speed = SPRINT_SPEED
		var accel := 12.0 if is_on_floor() else 3.0
		velocity.x = move_toward(velocity.x, dir.x * speed, accel * speed * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, accel * speed * delta)

	if not input_locked and Input.is_action_just_pressed("jump"):
		if not _try_mantle() and is_on_floor() and not crouching:
			velocity.y = JUMP_VELOCITY

	move_and_slide()
	_update_head(delta)
	_update_prompt()


func take_damage(amount: float) -> void:
	health = max(0.0, health - amount)
	if hud:
		hud.damage_flash(health)
	if health <= 0.0:
		died.emit()


func heal_full() -> void:
	health = 100.0
	if hud:
		hud.damage_flash(health)


func respawn(at: Transform3D) -> void:
	global_transform = at
	velocity = Vector3.ZERO
	head.rotation = Vector3.ZERO
	sliding = false
	heal_full()


func _set_crouch(on: bool) -> void:
	crouching = on
	_height = CROUCH_HEIGHT if on else STAND_HEIGHT
	_capsule.height = _height
	_collider.position.y = _height / 2


func _can_stand() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * (CROUCH_HEIGHT - 0.05)
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS * 0.95
	q.shape = sphere
	q.exclude = [get_rid()]
	q.transform = Transform3D(Basis(), from + Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT))
	return space.intersect_shape(q, 1).is_empty()


func _try_mantle() -> bool:
	var space := get_world_3d().direct_space_state
	var fwd := -global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var chest := global_position + Vector3.UP * 0.7
	var q := PhysicsRayQueryParameters3D.create(chest, chest + fwd * 0.8, collision_mask, [get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var probe := Vector3(hit.position.x, global_position.y + MANTLE_MAX + 0.3, hit.position.z) + fwd * 0.4
	var q2 := PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * (MANTLE_MAX + 0.2), collision_mask, [get_rid()])
	var top := space.intersect_ray(q2)
	if top.is_empty():
		return false
	var ledge: float = top.position.y - global_position.y
	if ledge < 0.35 or ledge > MANTLE_MAX:
		return false
	# Is there room to stand (or at least crouch) on top?
	var room_q := PhysicsRayQueryParameters3D.create(top.position + Vector3.UP * 0.05, top.position + Vector3.UP * CROUCH_HEIGHT, collision_mask, [get_rid()])
	if not space.intersect_ray(room_q).is_empty():
		return false
	var stand_q := PhysicsRayQueryParameters3D.create(top.position + Vector3.UP * 0.05, top.position + Vector3.UP * STAND_HEIGHT, collision_mask, [get_rid()])
	if not space.intersect_ray(stand_q).is_empty():
		_set_crouch(true)
	mantling = true
	velocity = Vector3.ZERO
	var up := Vector3(global_position.x, top.position.y + 0.05, global_position.z)
	var over: Vector3 = top.position + Vector3.UP * 0.05
	var tw := create_tween()
	tw.tween_property(self, "global_position", up, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "global_position", over, 0.18)
	tw.tween_callback(func(): mantling = false)
	return true


func _strike() -> void:
	if _strike_cd > 0.0:
		return
	_strike_cd = STRIKE_COOLDOWN
	if hud:
		hud.strike_swing()
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * STRIKE_RANGE
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()]))
	if hit.is_empty():
		return
	var node: Node = hit.collider
	while node and not node.has_method("take_hit"):
		node = node.get_parent()
	if node:
		node.take_hit(self)


func _look_target() -> Node:
	if not _ray.is_colliding():
		return null
	var node: Node = _ray.get_collider()
	while node and not (node.has_method("interact") or node.has_method("interact_alt")):
		node = node.get_parent()
	return node


func _update_head(delta: float) -> void:
	var target_y := _height - 0.12
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and flat_speed > 0.5 and not sliding:
		_bob_t += delta * flat_speed * 2.2
		target_y += sin(_bob_t) * 0.035
	head.position.y = lerp(head.position.y, target_y, clamp(delta * 12.0, 0.0, 1.0))
	camera.fov = lerp(camera.fov, 86.0 if sliding else 78.0, clamp(delta * 8.0, 0.0, 1.0))


func _update_prompt() -> void:
	if not hud:
		return
	var text := ""
	if not input_locked:
		var target := _look_target()
		if target and target.has_method("get_prompt"):
			text = target.get_prompt(self)
	hud.set_prompt(text)
