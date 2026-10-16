class_name Player
extends CharacterBody3D
## First-person player: walk, sprint, crouch, slide, landing roll, mantle, ledge
## grab and shimmy, climb, crawl through vents, shuffle along narrow ledges and
## stand on a teammate's shoulders (up to three high). Also flashlight, interact
## and strike.
##
## Movement reads only `controls`, never `Input`, so a copy of this player on
## another machine moves the same way when fed the same controls. Only the
## local player reads the keyboard, takes mouse look and owns the camera.

signal died
## A sound entities could hear. `loudness` runs from 0 (silent) to 1 (a bang).
signal noise_made(at: Vector3, loudness: float)

enum Move { WALK, SLIDE, ROLL, MANTLE, HANG, CLIMB, LEDGE, RIDE }

const WALK_SPEED := 3.8
const SPRINT_SPEED := 6.5
const CROUCH_SPEED := 1.9
const CRAWL_SPEED := 1.5
## Hurrying through a vent: faster, but you bang the duct.
const VENT_RUSH_SPEED := 2.6
const CARRY_SPEED := 1.6
const JUMP_VELOCITY := 4.3
const SLIDE_SPEED := 9.0
const SLIDE_TIME := 0.8
const ROLL_SPEED := 5.5
const ROLL_TIME := 0.6
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 0.85
const RADIUS := 0.32
const MOUSE_SENS := 0.0022
## Highest ledge, above your feet, you can mantle straight onto.
const MANTLE_MAX := 1.6
## Highest ledge, above your feet, you can catch with your hands and hang from.
const HANG_REACH := 2.25
const MANTLE_UP_TIME := 0.22
const MANTLE_OVER_TIME := 0.18
const SHIMMY_SPEED := 1.2
const CLIMB_SPEED := 2.2
const LEDGE_SPEED := 1.1
## Upward kick when jumping off a teammate's shoulders.
const BOOST_VELOCITY := 5.0
const MAX_STACK := 3
## Falling faster than this lands loudly, unless you roll.
const HARD_LANDING := 7.0
const STRIKE_RANGE := 2.0
const STRIKE_COOLDOWN := 0.55

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health := 100.0
var state := Move.WALK
var crouching := false
## True while a terminal or menu has focus.
var input_locked := false
var hud: Node
## This tick's intent. Filled from the keyboard when `local_control` is set.
var controls := PlayerControls.new()
## True for the player at this machine; false for teammates driven from elsewhere.
var local_control := true
## Who this player stands on, and who stands on this player.
var carrier: Player = null
var rider: Player = null

var _volumes: Array[MovementVolume] = []
var _timer := 0.0
var _dir := Vector3.ZERO
var _crouch_was := false
var _roll_queued := false
var _was_on_floor := true
var _air_time := 0.0
var _mantle_path: Array[Vector3] = []
var _hang_normal := Vector3.ZERO
var _hang_top := 0.0
var _climb: MovementVolume
var _ledge: MovementVolume
var _step_t := 0.0
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
	camera.current = local_control
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

	if local_control:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_add_body_mesh()


func _unhandled_input(event: InputEvent) -> void:
	if input_locked or not local_control:
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
	if local_control:
		controls.read_local(input_locked)
	step(delta)
	_update_head(delta)
	if local_control:
		_update_prompt()


## Advance movement by one physics tick using `controls`.
func step(delta: float) -> void:
	var jump_pressed := controls.jump
	controls.jump = false
	var crouch_pressed := controls.crouch and not _crouch_was
	_crouch_was = controls.crouch
	match state:
		Move.MANTLE:
			_step_mantle(delta)
		Move.RIDE:
			_step_ride(jump_pressed, crouch_pressed)
		Move.HANG:
			_step_hang(delta, jump_pressed, crouch_pressed)
		Move.CLIMB:
			_step_climb(delta, jump_pressed)
		Move.LEDGE:
			_step_ledge(delta)
		_:
			_step_ground(delta, jump_pressed, crouch_pressed)


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
	if rider:
		rider._leave_carrier()
	_leave_carrier()
	global_transform = at
	velocity = Vector3.ZERO
	head.rotation = Vector3.ZERO
	state = Move.WALK
	_set_crouch(false)
	heal_full()


# --- Teammates -------------------------------------------------------------

## Where a rider's feet go.
func shoulder_point() -> Vector3:
	return global_position + Vector3.UP * (_height + 0.02)


## Players in the stack from the floor up to and including this one.
func stack_height() -> int:
	return 1 + (carrier.stack_height() if carrier else 0)


## Can `other` climb onto this player's shoulders right now?
func can_carry(other: Player) -> bool:
	if other == self or rider != null or other.carrier != null or other.rider != null:
		return false
	if other.state != Move.WALK or not other.is_on_floor():
		return false
	if crouching or not (state == Move.RIDE or (state == Move.WALK and is_on_floor())):
		return false
	return stack_height() + 1 <= MAX_STACK


func get_prompt(other: Node) -> String:
	if other is Player and can_carry(other):
		return "[E] Climb on shoulders"
	return ""


func interact(other: Node) -> void:
	if other is Player and can_carry(other):
		other.mount(self)


## Climb onto `base`'s shoulders.
func mount(base: Player) -> void:
	carrier = base
	base.rider = self
	add_collision_exception_with(base)
	base.add_collision_exception_with(self)
	_set_crouch(false)
	state = Move.RIDE
	velocity = Vector3.ZERO
	global_position = base.shoulder_point()
	_noise(0.2)


func _leave_carrier() -> void:
	if carrier and is_instance_valid(carrier):
		carrier.rider = null
		remove_collision_exception_with(carrier)
		carrier.remove_collision_exception_with(self)
	carrier = null
	if state == Move.RIDE:
		state = Move.WALK


func _step_ride(jump_pressed: bool, crouch_pressed: bool) -> void:
	if carrier == null or not is_instance_valid(carrier):
		_leave_carrier()
		return
	var base := carrier
	global_position = base.shoulder_point()
	velocity = base.velocity
	if crouch_pressed:
		# Step down behind them.
		_leave_carrier()
		global_position = base.global_position - base._forward() * (RADIUS * 2 + 0.15)
		velocity = Vector3.ZERO
		return
	if jump_pressed:
		_leave_carrier()
		if _try_ledge(true):
			return
		velocity = base.velocity + Vector3.UP * BOOST_VELOCITY + _forward() * 1.5
		_was_on_floor = false


# --- Volumes ---------------------------------------------------------------

func enter_volume(v: MovementVolume) -> void:
	if not _volumes.has(v):
		_volumes.append(v)


func exit_volume(v: MovementVolume) -> void:
	_volumes.erase(v)


func in_volume(kind: MovementVolume.Kind) -> MovementVolume:
	for v in _volumes:
		if v.kind == kind:
			return v
	return null


# --- On foot ---------------------------------------------------------------

func _step_ground(delta: float, jump_pressed: bool, crouch_pressed: bool) -> void:
	var on_floor := is_on_floor()
	_air_time = 0.0 if on_floor else _air_time + delta
	if not on_floor:
		velocity.y -= gravity * delta
		if crouch_pressed:
			_roll_queued = true
	var in_vent := in_volume(MovementVolume.Kind.VENT) != null
	var flat := Vector3(velocity.x, 0, velocity.z)

	if state == Move.WALK and rider == null:
		if controls.crouch and not crouching and on_floor:
			if controls.sprint and flat.length() > WALK_SPEED and not in_vent:
				_begin_dash(Move.SLIDE, SLIDE_TIME, flat.normalized())
			_set_crouch(true)
		elif not controls.crouch and crouching and _can_stand():
			_set_crouch(false)

	if state == Move.SLIDE or state == Move.ROLL:
		_timer -= delta
		var top := SLIDE_SPEED if state == Move.SLIDE else ROLL_SPEED
		var total := SLIDE_TIME if state == Move.SLIDE else ROLL_TIME
		var spd: float = lerp(CROUCH_SPEED, top, clamp(_timer / total, 0.0, 1.0))
		velocity.x = _dir.x * spd
		velocity.z = _dir.z * spd
		if _timer <= 0.0 or is_on_wall():
			state = Move.WALK
			if not controls.crouch and _can_stand():
				_set_crouch(false)
	else:
		var dir := (transform.basis * Vector3(controls.move.x, 0, controls.move.y)).normalized()
		var speed := WALK_SPEED
		if rider:
			speed = CARRY_SPEED
		elif in_vent:
			speed = VENT_RUSH_SPEED if controls.sprint else CRAWL_SPEED
		elif crouching:
			speed = CROUCH_SPEED
		elif controls.sprint:
			speed = SPRINT_SPEED
		var accel := 12.0 if on_floor else 3.0
		if not on_floor and dir == Vector3.ZERO:
			accel = 0.0  # keep your momentum through the air
		velocity.x = move_toward(velocity.x, dir.x * speed, accel * speed * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, accel * speed * delta)

	if state == Move.WALK and rider == null and not in_vent:
		var climb := in_volume(MovementVolume.Kind.CLIMB)
		if climb and _forward().dot(-climb.normal) > 0.5 and (controls.move.y < -0.3 or jump_pressed):
			_climb = climb
			state = Move.CLIMB
			velocity = Vector3.ZERO
			_roll_queued = false
			if crouching and _can_stand():
				_set_crouch(false)
			return
		var ledge := in_volume(MovementVolume.Kind.LEDGE)
		if ledge and on_floor and _on_ledge_line(ledge, 0.15):
			_ledge = ledge
			state = Move.LEDGE
			velocity = Vector3.ZERO
			return
		if jump_pressed:
			if _try_ledge(true):
				return
			if on_floor and not crouching:
				velocity.y = JUMP_VELOCITY
		elif not on_floor and _air_time > 0.1 and controls.move.y < -0.5 and velocity.y < 1.5:
			# Reaching for a ledge mid-jump catches it.
			if _try_ledge(true):
				return

	var fall_speed := -velocity.y
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_land(fall_speed)
	_was_on_floor = is_on_floor()
	_footsteps(delta, in_vent)


func _land(fall_speed: float) -> void:
	var flat := Vector3(velocity.x, 0, velocity.z)
	if _roll_queued and flat.length() > 1.5 and rider == null:
		# Tuck and roll: keeps your speed, gets you under low gaps, and is quiet.
		_begin_dash(Move.ROLL, ROLL_TIME, flat.normalized())
		_set_crouch(true)
	elif fall_speed > HARD_LANDING:
		_noise(0.7)
	_roll_queued = false


func _begin_dash(kind: Move, time: float, dir: Vector3) -> void:
	state = kind
	_timer = time
	_dir = dir


func _footsteps(delta: float, in_vent: bool) -> void:
	var flat := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or flat < 0.5 or state != Move.WALK:
		_step_t = 0.0
		return
	_step_t += delta
	var interval := 0.33 if flat > WALK_SPEED + 0.5 or (in_vent and controls.sprint) else 0.5
	if _step_t < interval:
		return
	_step_t = 0.0
	if in_vent:
		if controls.sprint:
			_noise(0.9)  # banging the duct
	elif crouching:
		pass
	elif flat > WALK_SPEED + 0.5:
		_noise(0.5)
	else:
		_noise(0.15)


func _noise(loudness: float) -> void:
	noise_made.emit(global_position, loudness)


# --- Mantle and hang -------------------------------------------------------

## Looks for a ledge straight ahead along `dir`: a wall, a flat top within
## reach, and room to crouch on it.
func _ledge_probe(dir: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var feet := global_position
	var wall := {}
	for h in [0.5, 1.1, 1.7]:
		var from: Vector3 = feet + Vector3.UP * h
		wall = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * (RADIUS + 0.55), collision_mask, _exclude()))
		if not wall.is_empty():
			break
	if wall.is_empty() or absf(wall.normal.y) > 0.3:
		return {}
	var n := Vector3(wall.normal.x, 0, wall.normal.z).normalized()
	var face := Vector3(wall.position.x, feet.y, wall.position.z)
	var probe := face - n * 0.25 + Vector3.UP * (HANG_REACH + 0.25)
	var q := PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * (HANG_REACH - 0.05), collision_mask, _exclude())
	q.hit_from_inside = true
	var top := space.intersect_ray(q)
	if top.is_empty() or top.normal.y < 0.7:
		return {}
	var height: float = top.position.y - feet.y
	if height < 0.35:
		return {}
	var target := face - n * (RADIUS + 0.08)
	target.y = top.position.y + 0.02
	if not _fits(target, CROUCH_HEIGHT):
		return {}
	return {"normal": n, "face": face, "top": top.position.y, "height": height, "target": target}


## Mantle onto a ledge ahead, or catch it and hang if it's higher.
func _try_ledge(allow_hang: bool, dir: Vector3 = Vector3.ZERO) -> bool:
	var p := _ledge_probe(_forward() if dir == Vector3.ZERO else dir)
	if p.is_empty():
		return false
	if p.height <= MANTLE_MAX:
		_start_mantle(p.target)
		return true
	if allow_hang and p.height <= HANG_REACH:
		state = Move.HANG
		_hang_normal = p.normal
		_hang_top = p.top
		_set_crouch(false)
		velocity = Vector3.ZERO
		_roll_queued = false
		global_position = p.face + p.normal * (RADIUS + 0.03) + Vector3.UP * (p.top - p.face.y - HANG_REACH + 0.1)
		_noise(0.25)
		return true
	return false


func _start_mantle(target: Vector3) -> void:
	if not _fits(target, STAND_HEIGHT):
		_set_crouch(true)
	state = Move.MANTLE
	_timer = 0.0
	velocity = Vector3.ZERO
	_roll_queued = false
	var here := global_position
	_mantle_path = [here, Vector3(here.x, target.y + 0.05, here.z), target]
	_noise(0.2)


func _step_mantle(delta: float) -> void:
	_timer += delta
	var p := _mantle_path
	if _timer < MANTLE_UP_TIME:
		global_position = p[0].lerp(p[1], ease(_timer / MANTLE_UP_TIME, -1.6))
	elif _timer < MANTLE_UP_TIME + MANTLE_OVER_TIME:
		global_position = p[1].lerp(p[2], (_timer - MANTLE_UP_TIME) / MANTLE_OVER_TIME)
	else:
		global_position = p[2]
		velocity = Vector3.ZERO
		state = Move.WALK
		_was_on_floor = true


func _step_hang(delta: float, jump_pressed: bool, crouch_pressed: bool) -> void:
	var n := _hang_normal
	velocity = Vector3.ZERO
	if crouch_pressed or controls.move.y > 0.5:
		# Let go.
		state = Move.WALK
		velocity = n * 1.0
		_was_on_floor = false
		return
	if jump_pressed or controls.move.y < -0.5:
		var face := global_position - n * (RADIUS + 0.03)
		var target := face - n * (RADIUS + 0.08)
		target.y = _hang_top + 0.02
		if _fits(target, CROUCH_HEIGHT):
			_start_mantle(target)
			return
	if absf(controls.move.x) > 0.1:
		var right := (-n).cross(Vector3.UP)
		var move := right * signf(controls.move.x) * SHIMMY_SPEED * delta
		if _edge_at(global_position + move * 4.0):
			var y := global_position.y
			velocity = move / delta
			move_and_slide()
			global_position.y = y
			velocity = Vector3.ZERO


## Is there still ledge to hold onto above this hanging position?
func _edge_at(pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var over := pos - _hang_normal * (RADIUS + 0.03 + 0.15)
	over.y = _hang_top + 0.3
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(over, over + Vector3.DOWN * 0.5, collision_mask, _exclude()))
	return not hit.is_empty() and hit.normal.y > 0.7 and absf(hit.position.y - _hang_top) < 0.15


# --- Climb -----------------------------------------------------------------

func _step_climb(delta: float, jump_pressed: bool) -> void:
	var v := _climb
	if v == null or not _volumes.has(v):
		state = Move.WALK
		_climb = null
		return
	if jump_pressed:
		# Kick off backwards.
		state = Move.WALK
		_climb = null
		velocity = v.normal * 3.0 + Vector3.UP * 3.0
		_was_on_floor = false
		return
	var up := -controls.move.y
	var right := (-v.normal).cross(Vector3.UP)
	velocity = Vector3.UP * up * CLIMB_SPEED + right * controls.move.x * CLIMB_SPEED * 0.5
	# Stay snug against the surface.
	var dist := (global_position - v.a).dot(v.normal)
	velocity += v.normal * (RADIUS + 0.2 - dist) * 8.0
	if up > 0.0 and global_position.y + MANTLE_MAX - 0.1 >= v.b.y:
		if _try_ledge(false, -v.normal):
			_climb = null
			return
	if global_position.y >= v.b.y - 1.0 and velocity.y > 0.0:
		velocity.y = 0.0  # top of a pipe with nowhere to go
	move_and_slide()
	if up < 0.0 and is_on_floor():
		state = Move.WALK
		_climb = null
	_step_t += delta * absf(up)
	if _step_t > 0.6:
		_step_t = 0.0
		_noise(0.2)


# --- Narrow ledge ----------------------------------------------------------

func _on_ledge_line(v: MovementVolume, margin: float) -> bool:
	var line := v.b - v.a
	var length := line.length()
	var dir := line / length
	var rel := global_position - v.a
	var t := rel.dot(dir)
	var side := rel - dir * t
	side.y = 0.0
	return t > margin and t < length - margin and side.length() < 0.4


func _step_ledge(delta: float) -> void:
	var v := _ledge
	if v == null or not _volumes.has(v):
		state = Move.WALK
		_ledge = null
		return
	var line := v.b - v.a
	var length := line.length()
	var dir := line / length
	var wish := transform.basis * Vector3(controls.move.x, 0, controls.move.y)
	var s: float = clamp(wish.dot(dir), -1.0, 1.0)
	var t := (global_position - v.a).dot(dir)
	var next_t := t + s * LEDGE_SPEED * delta
	if next_t < 0.0 or next_t > length:
		# Stepped off the end, onto whatever is there.
		state = Move.WALK
		_ledge = null
		velocity = dir * s * LEDGE_SPEED
		return
	var on_line := v.a + dir * t
	var pull := on_line - global_position
	pull.y = 0.0
	velocity = dir * s * LEDGE_SPEED + pull * 10.0
	velocity.y = -1.0
	move_and_slide()


# --- Helpers ---------------------------------------------------------------

func _forward() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _exclude() -> Array[RID]:
	var out: Array[RID] = [get_rid()]
	if carrier:
		out.append(carrier.get_rid())
	if rider:
		out.append(rider.get_rid())
	return out


func _set_crouch(on: bool) -> void:
	crouching = on
	_height = CROUCH_HEIGHT if on else STAND_HEIGHT
	_capsule.height = _height
	_collider.position.y = _height / 2


func _can_stand() -> bool:
	return _fits(global_position, STAND_HEIGHT)


## Would a body `height` tall fit with its feet at `feet`?
func _fits(feet: Vector3, height: float) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS * 0.9
	shape.height = height - 0.1
	q.shape = shape
	q.exclude = _exclude()
	q.transform = Transform3D(Basis(), feet + Vector3.UP * (height / 2 + 0.05))
	return space.intersect_shape(q, 1).is_empty()


func _add_body_mesh() -> void:
	# Teammates need a body to look at and climb on.
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = RADIUS
	cm.height = STAND_HEIGHT
	mesh.mesh = cm
	mesh.material_override = Greybox.mat(Color(0.3, 0.38, 0.5))
	mesh.position.y = STAND_HEIGHT / 2
	add_child(mesh)


func _strike() -> void:
	if _strike_cd > 0.0:
		return
	_strike_cd = STRIKE_COOLDOWN
	if hud:
		hud.strike_swing()
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * STRIKE_RANGE
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, collision_mask, _exclude()))
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
	if is_on_floor() and flat_speed > 0.5 and state == Move.WALK:
		_bob_t += delta * flat_speed * 2.2
		target_y += sin(_bob_t) * 0.035
	head.position.y = lerp(head.position.y, target_y, clamp(delta * 12.0, 0.0, 1.0))
	camera.fov = lerp(camera.fov, 86.0 if state == Move.SLIDE else 78.0, clamp(delta * 8.0, 0.0, 1.0))
	if state == Move.ROLL:
		camera.rotation.x = -TAU * (1.0 - clamp(_timer / ROLL_TIME, 0.0, 1.0))
	else:
		camera.rotation.x = 0.0


func _update_prompt() -> void:
	if not hud:
		return
	var text := ""
	if not input_locked:
		var target := _look_target()
		if target and target.has_method("get_prompt"):
			text = target.get_prompt(self)
	hud.set_prompt(text)
