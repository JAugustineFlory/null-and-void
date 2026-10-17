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
## The notebook finished coming out of the pocket and is up in front of you.
signal notebook_raised
## The notebook is back in the pocket.
signal notebook_lowered
## You're at a terminal and the camera has settled on its screen: start typing.
signal terminal_focused
## You've stepped back from a terminal and can move again.
signal terminal_left

enum Move { WALK, SLIDE, ROLL, MANTLE, HANG, CLIMB, LEDGE, RIDE, TERMINAL, VAULT }

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
## Sprint lingers this long after Shift is released, so Shift-off-then-Ctrl still slides.
const SPRINT_GRACE := 0.3
const ROLL_SPEED := 5.5
const ROLL_TIME := 0.6
const STAND_HEIGHT := 1.8
## Crouching is on two feet with bent knees.
const CROUCH_HEIGHT := 1.25
## Crawling is on hands and knees: slides, rolls, vents and any gap too low to crouch through.
const CRAWL_HEIGHT := 0.85
const RADIUS := 0.32
const MOUSE_SENS := 0.0022
## Highest ledge, above your feet, you can mantle straight onto.
const MANTLE_MAX := 1.6
## Highest ledge, above your feet, you can catch with your hands and hang from.
const HANG_REACH := 2.25
## A beat after catching an edge before you can pull up.
const HANG_SETTLE := 0.15
## How far (radians) you can turn from your stance while shuffling along a ledge.
const LEDGE_LOOK := deg_to_rad(100.0)
const MANTLE_UP_TIME := 0.22
## Walking into something knee to waist high (a desk, a counter, a railing) vaults
## you over it if there's floor on the other side. Taller than that, Space mantles.
const VAULT_MIN := 0.45
const VAULT_MAX := 1.15
## Thicker than this on top and it's a platform to climb onto, not something to vault.
const VAULT_DEPTH := 1.0
const VAULT_UP_TIME := 0.16
const VAULT_OVER_TIME := 0.24
const VAULT_DOWN_TIME := 0.18
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
## Walking pace while reading the notebook: no sprinting, jumping or climbing.
const NOTEBOOK_WALK_SPEED := 1.4
## Mouse look is a little slower while reading.
const NOTEBOOK_LOOK_SCALE := 0.75
## How long pulling the notebook out of the pocket (or putting it back) takes,
## matching HeldNotebook's open motion.
const NOTEBOOK_RAISE_TIME := 0.45
## Using a terminal: the step to its stand point, then the camera easing onto the screen.
const TERMINAL_STEP_TIME := 0.35
const TERMINAL_FOCUS_TIME := 0.5
## How far the camera sits from the screen's focus point, metres.
const TERMINAL_FOCUS_DISTANCE := 0.55

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health := 100.0
var state := Move.WALK
## True when lower than standing (crouching or crawling).
var crouching := false
var crawling := false
## True while a terminal or menu has focus.
var input_locked := false
## Strapped into a seat (the van): look around and press E, but no walking,
## crouching or jumping.
var seated := false
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
## Forward must be let go after catching an edge before it pulls you up.
var _fwd_released := false
var _sprint_grace := 0.0
## The way your body faces on a narrow ledge: into the wall or out over the drop.
var _ledge_face := Vector3.ZERO
var _climb: MovementVolume
var _ledge: MovementVolume
var _step_t := 0.0
var _strike_cd := 0.0
var _height := STAND_HEIGHT
## How tall the body is right now: 1.8 standing, 1.25 crouching, 0.85 crawling,
## or in between. Read-only; co-op sends it so teammates see the same pose.
var stance_height: float:
	get:
		return _height
var _bob_t := 0.0
## The notebook model in your hands (a HeldNotebook on `camera`, from
## HeldNotebook.attach). raise/lower_notebook() call its open_book()/close_book(),
## which play the pull-out and put-away. Optional: without one only the state changes.
## It only takes mouse input while `notebook_cursor` is on.
var held_notebook: Node3D:
	set(n):
		held_notebook = n
		if n:
			n.set_process_input(notebook_cursor)
## While the notebook is held the mouse looks around; holding right mouse shows a
## cursor for clicking the pages instead. Read-only (set_notebook_cursor()).
var notebook_cursor := false
var _rmb_was := false
## 0 stowed in the pocket, 1 fully held up; eases between them. Read-only.
var notebook_amount := 0.0
var _notebook_held := false
## The terminal you're using, its stand and focus points, and how far you are into it:
## 0..1 stepping over, 1..2 the camera easing onto the screen. Read-only.
var terminal_amount := 0.0
var _term_stand: Node3D
var _term_focus: Node3D
var _term_leaving := false
var _term_from := Transform3D()

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
	if state == Move.TERMINAL:
		return  # the screen has the mouse and keys; the terminal UI calls leave_terminal()
	if event is InputEventMouseMotion and _mouse_looks():
		var sens := MOUSE_SENS * (NOTEBOOK_LOOK_SCALE if _notebook_held else 1.0)
		rotate_y(-event.relative.x * sens)
		if state == Move.LEDGE:
			_clamp_ledge_yaw()
		head.rotation.x = clamp(head.rotation.x - event.relative.y * sens, -1.45, 1.45)
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
	elif event.is_action_pressed("attack") and not _notebook_held:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_strike()


func _physics_process(delta: float) -> void:
	_strike_cd = max(0.0, _strike_cd - delta)
	if local_control:
		controls.read_local(input_locked or seated)
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
	if _notebook_held and state in [Move.MANTLE, Move.HANG, Move.CLIMB, Move.VAULT]:
		lower_notebook()  # you need both hands
	match state:
		Move.MANTLE:
			_step_mantle(delta)
		Move.VAULT:
			_step_vault(delta)
		Move.RIDE:
			_step_ride(jump_pressed, crouch_pressed)
		Move.HANG:
			_step_hang(delta, jump_pressed, crouch_pressed)
		Move.CLIMB:
			_step_climb(delta, jump_pressed)
		Move.LEDGE:
			_step_ledge(delta)
		Move.TERMINAL:
			_step_terminal(delta)
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
	lower_notebook(true)
	_end_terminal(false)
	heal_full()


# --- Notebook --------------------------------------------------------------

## Pull the notebook out of your pocket and hold it up. You can still look around
## and walk slowly. False if your hands are busy (climbing, hanging, mantling).
func raise_notebook() -> bool:
	if state in [Move.MANTLE, Move.HANG, Move.CLIMB, Move.VAULT]:
		return false
	if _notebook_held:
		return true
	_notebook_held = true
	if held_notebook:
		held_notebook.open_book()
	set_notebook_cursor(local_control and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	return true


## Put the notebook back. `instant` skips the motion (respawns, cutscenes).
func lower_notebook(instant: bool = false) -> void:
	var was_out := _notebook_held or notebook_amount > 0.0
	var was_held := _notebook_held
	_notebook_held = false
	if was_held and held_notebook:
		held_notebook.close_book()
	if was_held:
		set_notebook_cursor(false)
	if instant and was_out:
		notebook_amount = 0.0
		if held_notebook:
			held_notebook.visible = false
		notebook_lowered.emit()


## Tab: raise or lower. Returns whether the notebook is now held.
func toggle_notebook() -> bool:
	if _notebook_held:
		lower_notebook()
		return false
	return raise_notebook()


func is_holding_notebook() -> bool:
	return _notebook_held


## Right mouse held while reading: show the cursor to click the pages (tabs, next
## page, "+ add") and stop looking around; released, the mouse looks again.
## The local player follows the right mouse button by itself.
func set_notebook_cursor(on: bool) -> void:
	on = on and _notebook_held
	notebook_cursor = on
	if held_notebook:
		held_notebook.set_process_input(on)  # the pages only take clicks with the cursor up
	if local_control and not input_locked and state != Move.TERMINAL:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


## Does moving the mouse turn your head right now?
func _mouse_looks() -> bool:
	if _notebook_held:
		return not notebook_cursor
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


# --- Terminals -------------------------------------------------------------

## Step up to a terminal: you move onto `stand` (its position and facing; -Z looks
## at the terminal), then the camera eases onto `focus` and movement locks.
## `focus` is the terminal's TerminalScreen (the camera goes to its
## focus_transform()) or any Node3D on the screen with +Z pointing out of it. `terminal_focused` fires when the
## camera has settled. False if you're busy (mid-air, climbing, on shoulders).
func use_terminal(stand: Node3D, focus: Node3D) -> bool:
	if state != Move.WALK or not is_on_floor() or rider or carrier:
		return false
	lower_notebook()
	_term_stand = stand
	_term_focus = focus
	_term_from = global_transform
	_term_leaving = false
	terminal_amount = 0.0
	state = Move.TERMINAL
	velocity = Vector3.ZERO
	if local_control and not input_locked:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # to hover and click lines on the screen
	return true


## Esc or E at the terminal: the camera eases back and you can move again.
func leave_terminal() -> void:
	if state == Move.TERMINAL and not _term_leaving:
		_term_leaving = true
		terminal_amount = minf(terminal_amount, 2.0)


func is_using_terminal() -> bool:
	return state == Move.TERMINAL


## The camera has settled on the screen (and isn't easing back).
func is_terminal_focused() -> bool:
	return state == Move.TERMINAL and not _term_leaving and terminal_amount >= 2.0


## Where the camera ends up at the terminal: the screen's focus_transform(), or
## TERMINAL_FOCUS_DISTANCE out from a plain focus point, looking straight at it.
func terminal_view() -> Transform3D:
	if _term_focus.has_method("focus_transform"):
		return _term_focus.focus_transform(camera.fov)
	var at := _term_focus.global_position
	var eye := at + _term_focus.global_basis.z.normalized() * TERMINAL_FOCUS_DISTANCE
	return Transform3D(Basis.IDENTITY, eye).looking_at(at, Vector3.UP)


func _step_terminal(delta: float) -> void:
	velocity = Vector3.ZERO
	if _term_stand == null or not is_instance_valid(_term_stand) or (_term_focus and not is_instance_valid(_term_focus)):
		_end_terminal(true)
		return
	if _term_leaving:
		terminal_amount = move_toward(terminal_amount, 1.0, delta / TERMINAL_FOCUS_TIME)
		if terminal_amount <= 1.0:
			_end_terminal(true)
		return
	if terminal_amount >= 2.0:
		return
	if terminal_amount < 1.0:
		terminal_amount = minf(1.0, terminal_amount + delta / TERMINAL_STEP_TIME)
		var to := _term_stand.global_position
		var fwd := -_term_stand.global_basis.z
		var stand := Transform3D(Basis(Vector3.UP, atan2(-fwd.x, -fwd.z)), Vector3(to.x, global_position.y, to.z))
		var t := smoothstep(0.0, 1.0, terminal_amount)
		global_transform = _term_from.interpolate_with(stand, t)
		head.rotation.x = lerpf(head.rotation.x, 0.0, t)
	elif _term_focus == null:
		terminal_amount = 2.0
		terminal_focused.emit()
	else:
		terminal_amount = minf(2.0, terminal_amount + delta / TERMINAL_FOCUS_TIME)
		if terminal_amount == 2.0:
			terminal_focused.emit()


func _end_terminal(announce: bool) -> void:
	var was := state == Move.TERMINAL or terminal_amount > 0.0
	if state == Move.TERMINAL:
		state = Move.WALK
	terminal_amount = 0.0
	_term_stand = null
	_term_focus = null
	_term_leaving = false
	camera.transform = Transform3D.IDENTITY
	if was and local_control and not input_locked and not _notebook_held:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if was and announce:
		terminal_left.emit()


func _process(delta: float) -> void:
	if local_control:
		# Polled, not an input event: the pages take clicks under the cursor, the
		# release included, so an event could be swallowed and leave the cursor stuck.
		var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if rmb != _rmb_was:
			_rmb_was = rmb
			if _notebook_held and not input_locked:
				set_notebook_cursor(rmb)
	var target := 1.0 if _notebook_held else 0.0
	if notebook_amount == target:
		return
	notebook_amount = move_toward(notebook_amount, target, delta / NOTEBOOK_RAISE_TIME)
	if notebook_amount == 1.0:
		notebook_raised.emit()
	elif notebook_amount == 0.0:
		notebook_lowered.emit()


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
	_sprint_grace = SPRINT_GRACE if controls.sprint else maxf(0.0, _sprint_grace - delta)
	var sprinting := (controls.sprint or _sprint_grace > 0.0) and not _notebook_held

	if state == Move.WALK and rider == null and on_floor:
		if controls.crouch and not crouching and sprinting and flat.length() > WALK_SPEED and not in_vent:
			_begin_dash(Move.SLIDE, SLIDE_TIME, flat.normalized())
			_set_stance(CRAWL_HEIGHT)
		else:
			_settle_stance()

	if state == Move.SLIDE or state == Move.ROLL:
		_timer -= delta
		var top := SLIDE_SPEED if state == Move.SLIDE else ROLL_SPEED
		var total := SLIDE_TIME if state == Move.SLIDE else ROLL_TIME
		var spd: float = lerp(CROUCH_SPEED, top, clamp(_timer / total, 0.0, 1.0))
		velocity.x = _dir.x * spd
		velocity.z = _dir.z * spd
		if _timer <= 0.0 or is_on_wall():
			state = Move.WALK  # stance settles next tick, as high as there's room for
	else:
		var dir := (transform.basis * Vector3(controls.move.x, 0, controls.move.y)).normalized()
		var speed := WALK_SPEED
		if rider:
			speed = CARRY_SPEED
		elif in_vent:
			speed = VENT_RUSH_SPEED if controls.sprint else CRAWL_SPEED
		elif crawling:
			speed = CRAWL_SPEED
		elif crouching:
			speed = CROUCH_SPEED
		elif sprinting:
			speed = SPRINT_SPEED
		if _notebook_held:
			speed = minf(speed, NOTEBOOK_WALK_SPEED)
		var accel := 12.0 if on_floor else 3.0
		if not on_floor and dir == Vector3.ZERO:
			accel = 0.0  # keep your momentum through the air
		velocity.x = move_toward(velocity.x, dir.x * speed, accel * speed * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, accel * speed * delta)

	if state == Move.WALK and rider == null and not in_vent and not _notebook_held:
		var climb := in_volume(MovementVolume.Kind.CLIMB)
		if climb and _forward().dot(-climb.normal) > 0.5 and (controls.move.y < -0.3 or jump_pressed):
			_climb = climb
			state = Move.CLIMB
			velocity = Vector3.ZERO
			_roll_queued = false
			if crouching and _can_stand():
				_set_stance(STAND_HEIGHT)
			return
		var ledge := in_volume(MovementVolume.Kind.LEDGE)
		if ledge and on_floor and _on_ledge_line(ledge, 0.15):
			_ledge = ledge
			state = Move.LEDGE
			velocity = Vector3.ZERO
			# Keep the stance you stepped on with: facing the wall or back to it.
			_ledge_face = -ledge.normal if _forward().dot(-ledge.normal) > 0.0 else ledge.normal
			_clamp_ledge_yaw()
			return
		var going := Vector3(velocity.x, 0, velocity.z).length()
		if on_floor and not jump_pressed and not crouching and not sprinting and controls.move.y < -0.5 and going > 0.3 and _try_vault():
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
		_set_stance(CRAWL_HEIGHT)
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
	if not _fits(target, CRAWL_HEIGHT):
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
		_timer = 0.0
		_fwd_released = controls.move.y > -0.5
		_set_crouch(false)
		velocity = Vector3.ZERO
		_roll_queued = false
		global_position = p.face + p.normal * (RADIUS + 0.03) + Vector3.UP * (p.top - p.face.y - HANG_REACH + 0.1)
		_noise(0.25)
		return true
	return false


## Vault over a low obstacle just ahead: it's VAULT_MIN..VAULT_MAX tall, no deeper
## than VAULT_DEPTH, with room to pass over it and floor to land on beyond.
func _try_vault() -> bool:
	var space := get_world_3d().direct_space_state
	var feet := global_position
	var fwd := _forward()
	var wall := {}
	for h in [0.3, 0.6]:
		var from: Vector3 = feet + Vector3.UP * h
		wall = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + fwd * (RADIUS + 0.35), collision_mask, _exclude()))
		if not wall.is_empty():
			break
	if wall.is_empty() or absf(wall.normal.y) > 0.3:
		return false
	var n := Vector3(wall.normal.x, 0, wall.normal.z).normalized()
	if fwd.dot(-n) < 0.7:
		return false  # only when heading at it, not brushing past
	var face := Vector3(wall.position.x, feet.y, wall.position.z)
	var top := _surface_at(face - n * 0.1, feet.y + VAULT_MAX + 0.3, VAULT_MAX + 0.3 - 0.2)
	if top == INF:
		return false
	var height := top - feet.y
	if height < VAULT_MIN or height > VAULT_MAX:
		return false
	# Find its far edge: where the top stops.
	var depth := 0.0
	var d := 0.2
	while d <= VAULT_DEPTH + 0.05:
		if absf(_surface_at(face - n * d, top + 0.2, 0.4) - top) > 0.1:
			depth = d
			break
		d += 0.1
	if depth == 0.0:
		return false
	var over := face - n * (depth / 2.0)
	over.y = top + 0.05
	var land := face - n * (depth + RADIUS + 0.12)
	var floor_y := _surface_at(land, top + 0.2, top + 0.2 - (feet.y - 0.6))
	if floor_y == INF or floor_y > top - 0.35:
		return false
	land.y = floor_y + 0.02
	if not _fits(over, CRAWL_HEIGHT) or not _fits(land, STAND_HEIGHT):
		return false
	state = Move.VAULT
	_timer = 0.0
	velocity = Vector3.ZERO
	_roll_queued = false
	_dir = -n
	_set_stance(CROUCH_HEIGHT)  # the camera dips as you go over
	_mantle_path = [feet, Vector3(feet.x, top + 0.05, feet.z), over, land]
	_noise(0.3)
	return true


## Height of the first upward-facing surface straight below `at` (from `from_y`,
## looking down `reach`), or INF.
func _surface_at(at: Vector3, from_y: float, reach: float) -> float:
	var from := Vector3(at.x, from_y, at.z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * reach, collision_mask, _exclude())
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.normal.y < 0.7:
		return INF
	return hit.position.y


func _step_vault(delta: float) -> void:
	_timer += delta
	var p := _mantle_path
	var t1 := VAULT_UP_TIME
	var t2 := t1 + VAULT_OVER_TIME
	var t3 := t2 + VAULT_DOWN_TIME
	if _timer < t1:
		global_position = p[0].lerp(p[1], ease(_timer / t1, -1.6))
	elif _timer < t2:
		global_position = p[1].lerp(p[2], (_timer - t1) / VAULT_OVER_TIME)
	elif _timer < t3:
		var k := (_timer - t2) / VAULT_DOWN_TIME
		var at: Vector3 = p[2].lerp(p[3], k)
		at.y = lerpf(p[2].y, p[3].y, k * k)  # drop off the far side
		global_position = at
	else:
		global_position = p[3]
		state = Move.WALK
		velocity = _dir * WALK_SPEED * 0.6  # carry on walking
		_was_on_floor = true


func _start_mantle(target: Vector3) -> void:
	if not _fits(target, STAND_HEIGHT):
		_set_stance(CROUCH_HEIGHT if _fits(target, CROUCH_HEIGHT) else CRAWL_HEIGHT)
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
	_timer += delta
	velocity = Vector3.ZERO
	if crouch_pressed or controls.move.y > 0.5:
		# Let go.
		state = Move.WALK
		velocity = n * 1.0
		_was_on_floor = false
		return
	if jump_pressed:
		# Kick off backwards, like off a pipe.
		state = Move.WALK
		velocity = n * 3.0 + Vector3.UP * 3.0
		_was_on_floor = false
		return
	var fwd := controls.move.y < -0.5
	if not fwd:
		_fwd_released = true
	elif _fwd_released and _timer >= HANG_SETTLE:
		# Holding W from the jump only grabs; a fresh W press climbs up.
		var face := global_position - n * (RADIUS + 0.03)
		var target := face - n * (RADIUS + 0.08)
		target.y = _hang_top + 0.02
		if _fits(target, CRAWL_HEIGHT):
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
	_clamp_ledge_yaw()
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


func _clamp_ledge_yaw() -> void:
	var center := atan2(-_ledge_face.x, -_ledge_face.z)
	var d := angle_difference(center, rotation.y)
	if absf(d) > LEDGE_LOOK:
		rotation.y = center + signf(d) * LEDGE_LOOK


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
	_set_stance(CROUCH_HEIGHT if on else STAND_HEIGHT)


func _set_stance(height: float) -> void:
	_height = height
	crouching = height < STAND_HEIGHT
	# Below about a metre you're on hands and knees.
	crawling = height < 1.0
	_capsule.height = height
	_collider.position.y = height / 2


## Pick the stance for this tick. Standing unless Ctrl is held; when low, crouch
## only as far as the space needs: just under a desk, all the way down for a vent.
## Looks a step ahead so you duck before you hit something, and rises where there's room.
func _settle_stance() -> void:
	if not controls.crouch and not crouching:
		return
	if not controls.crouch and _fits(global_position, STAND_HEIGHT):
		_set_stance(STAND_HEIGHT)
		return
	var room := _room(global_position)
	var wish := transform.basis * Vector3(controls.move.x, 0, controls.move.y)
	wish.y = 0.0
	if wish.length() > 0.1:
		var ahead := _room(global_position + wish.normalized() * 0.45)
		if ahead > 0.0:
			room = minf(room, ahead)
	if room > 0.0 and absf(room - _height) > 0.01:
		_set_stance(room)


## The tallest low stance, crawl to crouch, that fits with feet at `feet`; 0 if none.
func _room(feet: Vector3) -> float:
	var h := CROUCH_HEIGHT
	while h >= CRAWL_HEIGHT - 0.001:
		if _fits(feet, h + 0.05):  # keep a little headroom; the probe is slimmer than the body
			return h
		h -= 0.05
	return 0.0


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
	if state == Move.TERMINAL and terminal_amount > 1.0 and _term_focus:
		var f := smoothstep(0.0, 1.0, terminal_amount - 1.0)
		camera.global_transform = head.global_transform.interpolate_with(terminal_view(), f)
	elif state == Move.ROLL:
		camera.transform = Transform3D(Basis(Vector3.RIGHT, -TAU * (1.0 - clamp(_timer / ROLL_TIME, 0.0, 1.0))), Vector3.ZERO)
	else:
		camera.transform = Transform3D.IDENTITY


func _update_prompt() -> void:
	if not hud:
		return
	var text := ""
	if not input_locked:
		var target := _look_target()
		if target and target.has_method("get_prompt"):
			text = target.get_prompt(self)
	hud.set_prompt(text)
