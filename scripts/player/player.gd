class_name Player
extends CharacterBody3D
## First-person player: walk, sprint, crouch, slide, landing roll, mantle, ledge
## grab and shimmy, climb, crawl through vents, shuffle along narrow ledges and
## stand on a teammate's shoulders (up to three high), sit on a chair or the
## floor. Running, jumping and climbing cost stamina. Also flashlight, interact,
## strike and block (right mouse; health and fights live in `combat`).
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
## A picked-up paper or card has come up in front of you to read.
signal prop_raised(prop: Node3D)
## It's back where you found it.
signal prop_lowered(prop: Node3D)
## A sticky note has gone into the open notebook (`prop` is the note, or null if
## it was freed on the way). Write it onto the page now.
signal sticky_filed(prop: Node3D)
## You're at a terminal and the camera has settled on its screen: start typing.
signal terminal_focused
## You've stepped back from a terminal and can move again.
signal terminal_left
## You've sat down (on `seat`, or the floor when null), or got back up.
signal sat_down(seat: Node3D)
signal stood_up
## Knocked off your feet (knock_down), and back up again.
signal knocked_down
signal got_up

enum Move { WALK, SLIDE, ROLL, MANTLE, HANG, CLIMB, LEDGE, RIDE, TERMINAL, VAULT, SIT, DOWN }

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
## W + Space at something shin to waist high (a coffee table, a desk, a counter, a
## railing) vaults you over it if there's floor on the other side. Taller than
## that, the same keys mantle.
const VAULT_MIN := 0.3
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
## Mouse look is slower while reading.
const NOTEBOOK_LOOK_SCALE := 0.45
## Reading with the cursor out, off the page the view turns that way, up to
## EDGE_LOOK_SPEED (radians per second) at the screen's edge (edge_turn).
const EDGE_LOOK_MARGIN := 0.08
const EDGE_LOOK_SPEED := 1.6
## Pixels past the edge of what you read before the view starts to turn.
const EDGE_LOOK_DEADZONE := 12.0
## The turn ramps up over at least this share of the screen past the page.
const EDGE_LOOK_MIN_ROOM := 0.04
## How far your view can drift off the held notebook before it follows (radians):
## enough to look across the spread or down a page, never enough to lose it.
const NOTEBOOK_SLACK_SIDE := 0.2
const NOTEBOOK_SLACK_DOWN := 0.2
const NOTEBOOK_SLACK_UP := 0.08
## How long pulling the notebook out of the pocket (or putting it back) takes,
## matching HeldNotebook's open motion.
const NOTEBOOK_RAISE_TIME := 0.45
## Picking up a paper or card to read: how long it takes to come up (or go back
## down), and how much of the view's height it fills while you read it.
const PICKUP_TIME := 0.4
const READ_FILL := 0.7
## Moving a sticky note from where it is into the open notebook.
const FILE_TIME := 0.5
## Using a terminal: the step to its stand point, then the camera easing onto the screen.
const TERMINAL_STEP_TIME := 0.35
const TERMINAL_FOCUS_TIME := 0.5
## How far the camera sits from the screen's focus point, metres.
const TERMINAL_FOCUS_DISTANCE := 0.55
## Sitting: your body's height above what you sit on (eyes about 1.25 m up on a
## chair, 0.8 m on the floor), and how long sitting down or getting up takes.
const SIT_HEIGHT := 0.95
const SIT_TIME := 0.4
## Looking around sitting down (on a chair, the floor or a van seat): how far
## (radians) you can turn your head from the way a seat faces, and how far up
## and down you can look. A chair or van seat doesn't turn with you; on the floor
## you turn your whole body, so only the up-and-down range applies.
const SIT_LOOK := deg_to_rad(110.0)
const SIT_LOOK_UP := deg_to_rad(65.0)
const SIT_LOOK_DOWN := deg_to_rad(75.0)
## Getting up off a chair, you step this far out from it the way you're facing.
const SIT_STEP_OUT := 0.6
## Stamina, 0..STAMINA_MAX. Sprinting and climbing drain it per second; a jump,
## vault or mantle costs a lump. It comes back after STAMINA_REST
## seconds without spending: fast while you're still (standing, sitting,
## crouching), slowly on the move. Run it dry and you're winded until it's back
## to STAMINA_WINDED_UNTIL: no sprinting, and climbing is slower.
## Jumps and climbs never stop working, so being winded only slows you down.
const STAMINA_MAX := 100.0
const SPRINT_COST := 16.0
const CLIMB_COST := 12.0
const HANG_COST := 4.0
const JUMP_COST := 10.0
const MANTLE_COST := 8.0
const STAMINA_REST := 0.6
const STILL_REGEN := 45.0
const MOVING_REGEN := 10.0
const STAMINA_WINDED_UNTIL := 30.0
## Knocked down: how low you lie.
const DOWN_HEIGHT := 0.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health := 100.0
## 0..STAMINA_MAX; see spend_stamina(). Read-only.
var stamina := STAMINA_MAX
## Ran out of stamina and not yet recovered to STAMINA_WINDED_UNTIL. Read-only.
var winded := false
var _stamina_rest := 0.0  # seconds since stamina was last spent
var _stamina_state := Move.WALK  # last tick's state, to charge for a move once as it starts
var _down_time := 0.0  # seconds left lying down; INF until get_up()
## Health, blocking, going down and being thrown or grabbed (scripts/combat/).
var combat: PlayerCombat
## Lying on the floor at 0 health, waiting for a teammate.
var downed: bool:
	get:
		return combat != null and combat.down
var state := Move.WALK
## True when lower than standing (crouching or crawling).
var crouching := false
var crawling := false
## True while a terminal or menu has focus.
var input_locked := false
## What you carry: the hotbar on keys 1-4 (Inventory). LevelBase hands it the
## run's inventory; a bare Player gets its own.
var inventory := Inventory.new()
## Strapped into a seat (the van): look around and press E, but no walking,
## crouching or jumping. You look around from the way you face when strapped in,
## as far as on a chair (SIT_LOOK).
var seated := false:
	set(value):
		seated = value
		_seated_yaw = rotation.y
var _seated_yaw := 0.0
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
## Space pressed while hanging, waiting out HANG_SETTLE to pull you up.
var _hang_jump := false
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
## While the notebook is held a cursor is out for clicking the pages; pushed off
## the page, the view turns that way (edge_turn). Read-only (set_notebook_cursor()).
var notebook_cursor := false
## 0 stowed in the pocket, 1 fully held up; eases between them. Read-only.
var notebook_amount := 0.0
var _notebook_held := false
## How far your view has drifted off the held notebook: x yaw (+ left), y pitch
## (+ up), radians. The book stays put inside the slack and follows past it. Read-only.
var notebook_drift := Vector2.ZERO
## The paper or card you're holding up to read (pick_up), or null. Read-only.
var held_prop: Node3D
var _prop_home := {}  # where it came from: parent, local transform, collision
var _prop_read := Transform3D()  # camera-local reading pose
var _prop_from := Transform3D()  # camera-local, where it started coming up from
var _prop_t := 0.0  # 0 at home .. 1 held up
var _prop_lowering := false
var _filing := {}  # a sticky note on its way into the notebook
## The terminal you're using, its stand and focus points, and how far you are into it:
## 0..1 stepping over, 1..2 the camera easing onto the screen. Read-only.
var terminal_amount := 0.0
var _term_stand: Node3D
var _term_focus: Node3D
var _term_leaving := false
var _term_from := Transform3D()
var _term_look_from := Basis()
## The seat you're on (a Seat), or null on the floor or standing. Read-only.
var seat: Node3D
## 0 standing, 1 sat down; eases between them. Read-only.
var sit_amount := 0.0
var _sit_from := Transform3D()  # where you stood before sitting on a chair; where you'll stand up
var _sit_to := Transform3D()
var _sit_leaving := false

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
	combat = PlayerCombat.create(self)
	if local_control: FirstPersonBody.attach(self)  # your own body, seen from your eyes


## Turn your view right by `yaw` and down by `pitch` (radians); a held notebook
## drifts, then follows.
func _turn_view(yaw: float, pitch: float) -> void:
	var yaw0 := rotation.y
	var pitch0 := head.rotation.x
	rotate_y(-yaw)
	if state == Move.LEDGE:
		_clamp_ledge_yaw()
	elif state == Move.SIT and is_instance_valid(seat):
		rotation.y = _turned_within(_seat_yaw(), yaw0, yaw)
	elif seated:
		rotation.y = _turned_within(_seated_yaw, yaw0, yaw)
	if _sitting_look():
		head.rotation.x = clampf(head.rotation.x - pitch, -SIT_LOOK_DOWN, SIT_LOOK_UP)
	else:
		head.rotation.x = clamp(head.rotation.x - pitch, -1.45, 1.45)
	if _notebook_held or _prop_settled():
		_drift_notebook(wrapf(rotation.y - yaw0, -PI, PI), head.rotation.x - pitch0)


## Up in front of you and read: what you hold drifts with your view like the notebook.
func _prop_settled() -> bool:
	return held_prop != null and _prop_t >= 1.0 and not _prop_lowering


## Reading with the cursor out: over what you're reading (`reading`, its rect on
## screen) the view holds still, so its tabs and lines can be clicked; once the
## cursor leaves it, the view turns that way (radians per second: x right, y
## down), faster the nearer the screen's edge. Without a rect, only a band at
## each edge (EDGE_LOOK_MARGIN of the screen) turns. However big the page is on
## screen, the outer EDGE_LOOK_MIN_ROOM of each edge always turns.
func edge_turn(cursor: Vector2, screen: Vector2, reading := Rect2()) -> Vector2:
	var turn := Vector2.ZERO
	if screen.x <= 0.0 or screen.y <= 0.0 or not Rect2(Vector2.ZERO, screen).has_point(cursor):
		return turn
	var inner := reading if reading.has_area() else Rect2(screen * EDGE_LOOK_MARGIN, screen * (1.0 - 2.0 * EDGE_LOOK_MARGIN))
	inner = inner.grow(EDGE_LOOK_DEADZONE)
	# A page that reaches past the screen (held close, or a tall spread) still
	# leaves a band at each edge that turns.
	var band := Rect2(screen * EDGE_LOOK_MIN_ROOM, screen * (1.0 - 2.0 * EDGE_LOOK_MIN_ROOM))
	inner = inner.intersection(band) if inner.intersects(band) else band
	turn.x = _edge_axis(cursor.x, inner.position.x, inner.end.x, screen.x)
	turn.y = _edge_axis(cursor.y, inner.position.y, inner.end.y, screen.y)
	return turn * EDGE_LOOK_SPEED


## -1..1 along one axis: 0 between `lo` and `hi`, easing up to 1 at the screen's edge.
static func _edge_axis(at: float, lo: float, hi: float, screen: float) -> float:
	var room := screen * EDGE_LOOK_MIN_ROOM  # even when the page reaches the edge
	if at < lo:
		return -pow(clampf((lo - at) / maxf(lo, room), 0.0, 1.0), 2.0)
	if at > hi:
		return pow(clampf((at - hi) / maxf(screen - hi, room), 0.0, 1.0), 2.0)
	return 0.0


## Where the notebook or the paper you hold is on screen (empty if neither):
## its pages, not the hands and sleeves holding them, which reach off the screen.
func reading_rect() -> Rect2:
	var root: Node3D = held_prop if held_prop else (held_notebook.get("book_root") if held_notebook and _notebook_held else null)
	if root == null or not is_instance_valid(root):
		return Rect2()
	var rect := Rect2()
	var first := true
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree() or str(root.get_path_to(g)).contains("Hand/"):
			continue
		var box := g.get_aabb()
		for i in 8:
			var corner := g.global_transform * box.get_endpoint(i)
			if camera.is_position_behind(corner):
				continue
			var at := camera.unproject_position(corner)
			rect = Rect2(at, Vector2.ZERO) if first else rect.expand(at)
			first = false
	return rect


func _edge_look(delta: float) -> void:
	if not (local_control and notebook_cursor and _reading()) or input_locked or state == Move.TERMINAL:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or not get_window().has_focus():
		return
	var turn := edge_turn(get_viewport().get_mouse_position(), get_viewport().get_visible_rect().size, reading_rect())
	if turn != Vector2.ZERO:
		_turn_view(turn.x * delta, turn.y * delta)


func _unhandled_input(event: InputEvent) -> void:
	if input_locked or not local_control:
		return
	if state == Move.TERMINAL:
		return  # the screen has the mouse and keys; the terminal UI calls leave_terminal()
	if event is InputEventMouseMotion and _mouse_looks():
		var sens := MOUSE_SENS * (NOTEBOOK_LOOK_SCALE if _reading() else 1.0)
		_turn_view(event.relative.x * sens, event.relative.y * sens)
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
	elif event is InputEventKey and event.pressed and not event.echo and not _reading() \
			and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_4:
		inventory.use_slot(event.physical_keycode - KEY_1)  # reading, 1-4 turn the notebook's tabs
	elif event.is_action_pressed("interact"):
		var target := _look_target()
		if target and target.has_method("interact"):
			target.interact(self)
	elif event.is_action_pressed("alt_interact"):
		var target := _look_target()
		if target and target.has_method("interact_alt"):
			target.interact_alt(self)
	elif event.is_action_pressed("block") and not _reading() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		combat.raise_guard()
	elif event.is_action_pressed("attack") and not _hands_full():
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
	var sit_pressed := controls.sit
	controls.sit = false
	_tick_stamina(delta)
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
		Move.SIT:
			_step_sit(delta, jump_pressed or sit_pressed)
		Move.DOWN:
			_step_down(delta)
		_:
			if sit_pressed and sit():
				return
			_step_ground(delta, jump_pressed, crouch_pressed)


## A hit from `cause` (see PlayerCombat.CAUSES): blocked, hurt, down or dead.
func take_damage(amount: float, cause: String = "") -> String:
	return combat.take_damage(amount, cause)


func heal_full() -> void:
	health = 100.0
	if hud:
		hud.damage_flash(health)


func respawn(at: Transform3D) -> void:
	_end_sit()
	_end_down()
	stamina = STAMINA_MAX
	winded = false
	if rider:
		rider._leave_carrier()
	_leave_carrier()
	global_transform = at
	_seated_yaw = rotation.y
	velocity = Vector3.ZERO
	head.rotation = Vector3.ZERO
	state = Move.WALK
	_set_crouch(false)
	lower_notebook(true)
	put_down(true)
	_end_filing()
	_end_terminal(false)
	combat.reset()
	heal_full()


# --- Notebook --------------------------------------------------------------

## Pull the notebook out of your pocket and hold it up. You can still look around
## and walk slowly. False if your hands are busy (climbing, hanging, mantling).
func raise_notebook() -> bool:
	if state in [Move.MANTLE, Move.HANG, Move.CLIMB, Move.VAULT]:
		return false
	if _notebook_held:
		return true
	put_down()  # one thing in your hands at a time
	_notebook_held = true
	notebook_drift = Vector2.ZERO
	_pose_notebook()
	if held_notebook:
		held_notebook.open_book()
	set_notebook_cursor(_wants_cursor())
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


## While reading (the notebook, or a paper you picked up) the cursor is out to click
## the pages (tabs, next page, "+ add"), so a trackpad can click them; pushing it to
## the edge of what you read looks that way (edge_turn).
func set_notebook_cursor(on: bool) -> void:
	on = on and _reading()
	notebook_cursor = on
	if held_notebook:
		held_notebook.set_process_input(on)  # the pages only take clicks with the cursor up
	if held_prop:
		held_prop.set_process_input(on)
	if local_control and not input_locked and state != Move.TERMINAL:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


## Your view turned by `yaw`, `pitch` while holding the notebook: the book stays
## where it is in front of you until you look past the slack, then comes along.
func _drift_notebook(yaw: float, pitch: float) -> void:
	notebook_drift.x = clampf(notebook_drift.x + yaw, -NOTEBOOK_SLACK_SIDE, NOTEBOOK_SLACK_SIDE)
	notebook_drift.y = clampf(notebook_drift.y + pitch, -NOTEBOOK_SLACK_DOWN, NOTEBOOK_SLACK_UP)
	_pose_notebook()
	if _prop_settled() and is_instance_valid(held_prop):
		held_prop.transform = Transform3D(_drift_basis()) * _prop_read  # now, not on the next frame


## Turns the held notebook (the HeldNotebook node itself; Graphics poses its book
## inside) back against the drift, so it holds still in the room. Body yaw then
## head pitch: undo the pitch, the yaw drift, then pitch back to where the book was.
func _pose_notebook() -> void:
	if not held_notebook or not is_instance_valid(held_notebook):
		return
	held_notebook.transform = Transform3D(_drift_basis(), held_notebook.position)


## The turn that holds what you read still in the room against `notebook_drift`.
func _drift_basis() -> Basis:
	var pitch := head.rotation.x
	return Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.UP, -notebook_drift.x) * Basis(Vector3.RIGHT, pitch - notebook_drift.y)


## The cursor is out whenever this player reads.
func _wants_cursor() -> bool:
	return local_control


## Does moving the mouse turn your head right now?
func _mouse_looks() -> bool:
	if _reading():
		return not notebook_cursor
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


# --- Picking things up -----------------------------------------------------

## Lift a paper or card up in front of you to read it. It comes off the desk or
## wall over PICKUP_TIME and ends up facing you, filling READ_FILL of the view's
## height; `prop_raised` fires then. `size` is its readable face in metres and
## `face` the local direction that face points (+Z for a poster on a wall,
## Vector3.UP for one lying on a desk). You can walk slowly and look around while
## you read: a cursor is out (set_notebook_cursor), and pushing it off the page turns the view. It doesn't collide
## while held. False if your hands are busy or you're not on your feet.
func pick_up(prop: Node3D, size := Vector2(0.21, 0.28), face := Vector3.BACK) -> bool:
	if prop == null or held_prop or not _filing.is_empty() or not state in [Move.WALK, Move.SIT]:
		return false
	lower_notebook()
	held_prop = prop
	_prop_home = {"parent": prop.get_parent(), "transform": prop.transform}
	if prop is CollisionObject3D:
		_prop_home["layer"] = prop.collision_layer
		_prop_home["mask"] = prop.collision_mask
		prop.collision_layer = 0  # not in your face, and not what E aims at
		prop.collision_mask = 0
	prop.reparent(camera, true)
	_prop_from = prop.transform
	_prop_read = read_pose(size, face)
	notebook_drift = Vector2.ZERO
	_prop_t = 0.0
	_prop_lowering = false
	set_notebook_cursor(_wants_cursor())
	return true


## Put what you're holding back where it came from (`prop_lowered` when it's
## there). `instant` skips the motion.
func put_down(instant: bool = false) -> void:
	if held_prop == null:
		return
	if not is_instance_valid(held_prop):
		_drop_prop()
		return
	_prop_lowering = true
	if instant:
		_prop_t = 0.0
		_return_prop()


func is_holding_prop() -> bool:
	return held_prop != null and not _prop_lowering


## Camera-local pose for reading something `size` big whose readable side points
## along its local `face`: centred, tilted back a little, as close as it needs to
## be to fill READ_FILL of the view's height.
func read_pose(size: Vector2, face := Vector3.BACK) -> Transform3D:
	var tan_v := tan(deg_to_rad(camera.fov / 2.0))
	var aspect := 16.0 / 9.0
	if is_inside_tree():
		var rect := get_viewport().get_visible_rect()
		aspect = rect.size.x / maxf(rect.size.y, 1.0)
	var d := maxf(size.y / 2.0 / (tan_v * READ_FILL), size.x / 2.0 / (tan_v * aspect * 0.9))
	# Turn the readable side to face the camera (+Z in camera space), upright.
	var turn := Basis.IDENTITY
	if face.normalized().is_equal_approx(Vector3.UP):
		turn = Basis(Vector3.RIGHT, -PI / 2)
	elif not face.normalized().is_equal_approx(Vector3.BACK):
		turn = Basis(Quaternion(face.normalized(), Vector3.BACK))
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-8.0))
	return Transform3D(tilt * turn.inverse(), Vector3(0, -0.01, -d))


## Take a sticky note and put it in the notebook: the notebook comes out, then the
## note moves from where it is onto the open page and `sticky_filed` fires. With
## `keep` (a note stuck to a terminal, copied rather than taken) it stays where it
## is and a copy goes in; otherwise it's hidden as you take it, and the caller
## removes it. False if your hands are busy or the notebook can't come out.
func file_into_notebook(prop: Node3D, keep: bool = false) -> bool:
	if prop == null or not _filing.is_empty() or state == Move.TERMINAL:
		return false
	if not raise_notebook():
		return false
	var copy := prop.duplicate(0) as Node3D  # just the look: no script, no signals
	if copy is CollisionObject3D:
		copy.collision_layer = 0
		copy.collision_mask = 0
	camera.add_child(copy)
	copy.global_transform = prop.global_transform
	copy.visible = true
	if not keep:
		prop.visible = false
	_filing = {"copy": copy, "prop": prop, "from": copy.transform, "t": 0.0}
	return true


func is_filing() -> bool:
	return not _filing.is_empty()


## The copy of the note travelling into the notebook while filing, or null.
func filing_note() -> Node3D:
	var copy = _filing.get("copy")
	return copy if is_instance_valid(copy) else null


## How far the note is into the notebook: 0 just picked off, 1 on the page; 0 when not filing.
func filing_progress() -> float:
	return _filing.get("t", 0.0)


func _reading() -> bool:
	return _notebook_held or is_holding_prop()


## Something in your hands: no sprinting, jumping or climbing.
func _hands_full() -> bool:
	return _notebook_held or held_prop != null or not _filing.is_empty()


func _animate_prop(delta: float) -> void:
	if held_prop == null:
		return
	if not is_instance_valid(held_prop):
		_drop_prop()
		return
	if _prop_lowering:
		_prop_t = maxf(0.0, _prop_t - delta / PICKUP_TIME)
		if _prop_t == 0.0:
			_return_prop()
			return
		var home: Node = _prop_home.parent
		var home_cam: Transform3D = _prop_from
		if is_instance_valid(home) and home is Node3D:
			home_cam = camera.global_transform.affine_inverse() * (home as Node3D).global_transform * _prop_home.transform
		held_prop.transform = home_cam.interpolate_with(Transform3D(_drift_basis()) * _prop_read, smoothstep(0.0, 1.0, _prop_t))
		return
	if _prop_t < 1.0:
		_prop_t = minf(1.0, _prop_t + delta / PICKUP_TIME)
		var pose := _prop_from.interpolate_with(_prop_read, smoothstep(0.0, 1.0, _prop_t))
		pose.origin.y += sin(_prop_t * PI) * 0.04  # lifted, not slid
		held_prop.transform = pose
		if _prop_t == 1.0:
			prop_raised.emit(held_prop)
	else:
		held_prop.transform = Transform3D(_drift_basis()) * _prop_read


## Back on its desk or wall, colliding again.
func _return_prop() -> void:
	var prop := held_prop
	var home: Node = _prop_home.get("parent")
	if is_instance_valid(home):
		prop.reparent(home, false)
		prop.transform = _prop_home.transform
	if prop is CollisionObject3D and _prop_home.has("layer"):
		prop.collision_layer = _prop_home.layer
		prop.collision_mask = _prop_home.mask
	prop.set_process_input(true)
	_drop_prop()
	prop_lowered.emit(prop)


func _drop_prop() -> void:
	held_prop = null
	_prop_home = {}
	_prop_lowering = false
	_prop_t = 0.0
	if not _notebook_held:
		set_notebook_cursor(false)


func _animate_filing(delta: float) -> void:
	if _filing.is_empty():
		return
	# Untyped: a typed var errors on a freed object, and the note can be freed
	# under us (a level clearing it, a teammate's pickup).
	var copy = _filing.copy
	if not is_instance_valid(copy):
		_filing = {}
		return
	if not is_instance_valid(_filing.prop):
		_end_filing()  # the note is gone: nothing to file
		return
	if not _notebook_held:
		_end_filing()  # the notebook went away first
		return
	if notebook_amount < 1.0:
		return  # wait for the notebook to be up and open
	_filing.t = minf(1.0, _filing.t + delta / FILE_TIME)
	var page := camera.global_transform.affine_inverse() * _notebook_page()
	var t := smoothstep(0.0, 1.0, _filing.t)
	var pose: Transform3D = (_filing.from as Transform3D).interpolate_with(page, t)
	pose.origin.y += sin(_filing.t * PI) * 0.05
	copy.transform = pose
	if _filing.t == 1.0:
		var prop: Node3D = _filing.prop
		_end_filing()
		sticky_filed.emit(prop)


## Where a filed note lands: on the held notebook's open page, or where the
## notebook would be held without a model.
func _notebook_page() -> Transform3D:
	if held_notebook and is_instance_valid(held_notebook):
		var book = held_notebook.get("book_root")
		var at: Node3D = book if book is Node3D else held_notebook
		return at.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.8), Vector3(0.05, 0.0, 0.005))
	return camera.global_transform * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-38)).scaled(Vector3.ONE * 0.8), Vector3(0.04, -0.3, -0.42))


func _end_filing() -> void:
	if _filing.is_empty():
		return
	var copy = _filing.copy
	if is_instance_valid(copy):
		copy.queue_free()
	_filing = {}


# --- Terminals -------------------------------------------------------------

## Step up to a terminal: you move onto `stand` (its position and facing; -Z looks
## at the terminal) while your eyes turn onto the screen, then the camera eases in
## to `focus` and movement locks.
## `focus` is the terminal's TerminalScreen (the camera goes to its
## focus_transform()) or any Node3D on the screen with +Z pointing out of it. `terminal_focused` fires when the
## camera has settled. False if you're busy (mid-air, climbing, on shoulders).
func use_terminal(stand: Node3D, focus: Node3D) -> bool:
	if state != Move.WALK or not is_on_floor() or rider or carrier:
		return false
	lower_notebook()
	put_down()
	_term_stand = stand
	_term_focus = focus
	_term_from = global_transform
	_term_look_from = camera.global_basis
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


## Your eyes on the screen from where your head is: what you look at while stepping
## up, before the camera moves in.
func _terminal_aim() -> Basis:
	var view := terminal_view()
	var at := view.origin - view.basis.z.normalized() * TERMINAL_FOCUS_DISTANCE
	var from := head.global_position
	if from.distance_squared_to(at) < 0.0001:
		return view.basis
	return Basis.looking_at(at - from, Vector3.UP)


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
		if _term_focus == null:
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
		if _term_leaving and is_instance_valid(_term_focus):
			# Hand the view back where it is, still on the screen, so nothing snaps.
			var look := -_terminal_aim().z
			rotation.y = atan2(-look.x, -look.z)
			head.rotation.x = clampf(asin(clampf(look.y, -1.0, 1.0)), -1.45, 1.45)
	terminal_amount = 0.0
	_term_stand = null
	_term_focus = null
	_term_leaving = false
	camera.transform = Transform3D.IDENTITY
	if was and local_control and not input_locked and not _reading():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if was and announce:
		terminal_left.emit()


func _process(delta: float) -> void:
	_edge_look(delta)
	_animate_prop(delta)
	_animate_filing(delta)
	_pose_notebook()
	var target := 1.0 if _notebook_held else 0.0
	if notebook_amount == target:
		return
	notebook_amount = move_toward(notebook_amount, target, delta / NOTEBOOK_RAISE_TIME)
	if notebook_amount == 1.0:
		notebook_raised.emit()
	elif notebook_amount == 0.0:
		notebook_lowered.emit()


# --- Sitting -------------------------------------------------------------

## Sit down: on `on_seat` (a Seat: you turn and lower onto it) or, with null, on
## the floor where you stand. You can look around, read and use things you can
## reach; Space or Z stands you up (stand_up). False if you can't: mid-air, busy,
## on or under a teammate, in a vent, or the seat is taken.
func sit(on_seat: Node3D = null) -> bool:
	if state != Move.WALK or not is_on_floor() or rider or carrier or not _filing.is_empty():
		return false
	if in_volume(MovementVolume.Kind.VENT) or crawling:
		return false
	if on_seat:
		if on_seat.has_method("is_free") and not on_seat.is_free(self):
			return false
		on_seat.set("occupant", self)
	seat = on_seat
	_sit_from = global_transform
	_sit_to = global_transform
	if on_seat:
		var fwd := -on_seat.global_basis.z
		_sit_to = Transform3D(Basis(Vector3.UP, atan2(-fwd.x, -fwd.z)), on_seat.global_position)
	_sit_leaving = false
	sit_amount = 0.0
	state = Move.SIT
	velocity = Vector3.ZERO
	_height = SIT_HEIGHT
	crouching = false
	crawling = false
	_capsule.height = SIT_HEIGHT
	_collider.position.y = SIT_HEIGHT / 2
	sat_down.emit(on_seat)
	return true


## Get back up, facing the way you're looking: off a chair you step out that
## way (or back where you came from, if that's blocked); off the floor you rise
## where you are (into a crouch if something's overhead). `instant` skips the motion.
func stand_up(instant: bool = false) -> void:
	if state != Move.SIT:
		return
	if not _sit_leaving and _sit_from.origin.distance_to(_sit_to.origin) > 0.01:
		var out := Vector3(_sit_to.origin.x, _sit_from.origin.y, _sit_to.origin.z) + _forward() * SIT_STEP_OUT
		if _fits(out, STAND_HEIGHT):
			_sit_from.origin = out
	_sit_leaving = true
	if instant:
		_end_sit()


func is_sitting() -> bool:
	return state == Move.SIT


func _step_sit(delta: float, stand_pressed: bool) -> void:
	velocity = Vector3.ZERO
	if _sit_from.origin != _sit_to.origin and not is_instance_valid(seat):
		_sit_leaving = true  # the chair's gone
	if stand_pressed and not _sit_leaving:
		stand_up()
	var settling := sit_amount < 1.0
	sit_amount = move_toward(sit_amount, 0.0 if _sit_leaving else 1.0, delta / SIT_TIME)
	if _sit_from.origin.distance_to(_sit_to.origin) > 0.01:
		# Onto the chair, turning to face the way it does; or back off it, looking
		# wherever you were looking. Once you're down, the view is yours again.
		var t := smoothstep(0.0, 1.0, sit_amount)
		global_position = _sit_from.origin.lerp(_sit_to.origin, t)
		if settling and not _sit_leaving:
			rotation.y = lerp_angle(_sit_from.basis.get_euler().y, _sit_to.basis.get_euler().y, t)
	if not _sit_leaving:
		# Looking further up or down than you can sitting: the head eases back into range.
		head.rotation.x = move_toward(head.rotation.x, clampf(head.rotation.x, -SIT_LOOK_DOWN, SIT_LOOK_UP), delta * 3.0)
	if _sit_leaving and sit_amount <= 0.0:
		_end_sit()


func _end_sit() -> void:
	if state != Move.SIT:
		return
	if is_instance_valid(seat) and seat.get("occupant") == self:
		seat.set("occupant", null)
	if _sit_from.origin.distance_to(_sit_to.origin) > 0.01:
		global_position = _sit_from.origin
	seat = null
	sit_amount = 0.0
	_sit_leaving = false
	state = Move.WALK
	if _can_stand():
		_set_stance(STAND_HEIGHT)
	else:
		_set_stance(maxf(_room(global_position), CRAWL_HEIGHT))
	stood_up.emit()


## Sitting down or strapped in: the view keeps to a seated person's range.
func _sitting_look() -> bool:
	return seated or (state == Move.SIT and not _sit_leaving)


## The way the chair you're on faces (yaw).
func _seat_yaw() -> float:
	var fwd := -seat.global_basis.z
	return atan2(-fwd.x, -fwd.z)


## `from` turned right by `yaw`, kept within SIT_LOOK of `center`. The turn isn't
## wrapped first, so one big flick of the mouse can't swing you round the back.
func _turned_within(center: float, from: float, yaw: float) -> float:
	return center + clampf(angle_difference(center, from) - yaw, -SIT_LOOK, SIT_LOOK)


# --- Stamina and knocks ------------------------------------------

## Use up `amount` of stamina (Combat: a block, a struggle). Running it dry leaves
## you winded. Returns false, spending nothing, if you're winded or it's 0.
func spend_stamina(amount: float) -> bool:
	if amount <= 0.0:
		return true
	_stamina_rest = 0.0
	if winded:
		return false
	stamina = maxf(0.0, stamina - amount)
	if stamina <= 0.0:
		winded = true
	return true


## Give back `amount` of stamina (a pickup, a breather).
func restore_stamina(amount: float) -> void:
	stamina = minf(STAMINA_MAX, stamina + amount)
	if winded and stamina >= STAMINA_WINDED_UNTIL:
		winded = false


func _tick_stamina(delta: float) -> void:
	var flat := Vector2(velocity.x, velocity.z).length()
	var cost := 0.0
	if state == Move.CLIMB and velocity.length() > 0.3:
		cost = CLIMB_COST
	elif state == Move.HANG:
		cost = HANG_COST
	elif state == Move.WALK and is_on_floor() and flat > WALK_SPEED + 0.3 and not crouching:
		cost = SPRINT_COST
	if state != _stamina_state and state in [Move.VAULT, Move.MANTLE]:
		spend_stamina(MANTLE_COST)
	_stamina_state = state
	if cost > 0.0:
		_stamina_rest = 0.0
		stamina = maxf(0.0, stamina - cost * delta)
		if stamina <= 0.0:
			winded = true
		return
	_stamina_rest += delta
	if _stamina_rest < STAMINA_REST:
		return
	var still := flat < 0.3 and state in [Move.WALK, Move.SIT, Move.DOWN, Move.TERMINAL, Move.RIDE]
	restore_stamina((STILL_REGEN if still else MOVING_REGEN) * delta)


## Shoved, thrown or blasted (Combat): drop whatever you were doing (sitting, a
## terminal, a ledge, a teammate's shoulders, what's in your hands) and fly with
## `impulse` (metres per second, added to your velocity).
func knock_back(impulse: Vector3) -> void:
	_let_go()
	velocity += impulse
	if impulse.y > 0.0:
		_was_on_floor = false


## Knocked off your feet (Combat): you drop to the floor and lie there for
## `seconds`, then get up by yourself; INF lies there until get_up() (a teammate
## reviving you). A knock_back() still moves you while you're down.
func knock_down(seconds: float = 2.0) -> void:
	_let_go()
	state = Move.DOWN
	_down_time = seconds
	_height = DOWN_HEIGHT
	crouching = true
	crawling = true
	_capsule.height = maxf(DOWN_HEIGHT, RADIUS * 2.0)
	_collider.position.y = _capsule.height / 2
	knocked_down.emit()


## Back on your feet after knock_down() (as far up as there's room for).
func get_up() -> void:
	_end_down()


func is_down() -> bool:
	return state == Move.DOWN


func _step_down(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	velocity.y -= gravity * delta
	move_and_slide()
	_down_time -= delta
	if _down_time <= 0.0:
		_end_down()


func _end_down() -> void:
	if state != Move.DOWN:
		return
	state = Move.WALK
	_down_time = 0.0
	if _can_stand():
		_set_stance(STAND_HEIGHT)
	else:
		_set_stance(maxf(_room(global_position), CRAWL_HEIGHT))
	got_up.emit()


## Out of anything that holds you in place, hands empty, on your feet's physics again.
func _let_go() -> void:
	stand_up(true)
	if state == Move.TERMINAL:
		_end_terminal(true)
	if rider:
		rider._leave_carrier()
	_leave_carrier()
	lower_notebook()
	put_down()
	_end_filing()
	if state in [Move.HANG, Move.CLIMB, Move.LEDGE, Move.MANTLE, Move.VAULT, Move.SLIDE, Move.ROLL]:
		state = Move.WALK
	_climb = null
	_ledge = null


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
	var sprinting := (controls.sprint or _sprint_grace > 0.0) and not _hands_full() and not winded

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
		if _hands_full():
			speed = minf(speed, NOTEBOOK_WALK_SPEED)
		var accel := 12.0 if on_floor else 3.0
		if not on_floor and dir == Vector3.ZERO:
			accel = 0.0  # keep your momentum through the air
		velocity.x = move_toward(velocity.x, dir.x * speed, accel * speed * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, accel * speed * delta)

	if state == Move.WALK and rider == null and not in_vent and not _hands_full():
		var climb := in_volume(MovementVolume.Kind.CLIMB)
		# W + Space starts a climb (or W while already in the air), so walking past
		# a pipe never grabs it.
		var pushing := controls.move.y < -0.3
		if climb and _forward().dot(-climb.normal) > 0.5 and pushing and (jump_pressed or (not on_floor and _air_time > 0.1)):
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
		if jump_pressed:
			# A direction key plus Space: vault something low, mantle or grab something
			# higher. Space alone just jumps, so nothing happens by accident.
			if pushing and on_floor and not crouching and _try_vault():
				return
			if pushing and _try_ledge(true):
				return
			if on_floor and not crouching:
				velocity.y = JUMP_VELOCITY
				spend_stamina(JUMP_COST)
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
	# Never reach up past a ceiling: the top of the room's ceiling isn't a ledge.
	var head := feet + Vector3.UP * (_height - 0.05)
	var lid := space.intersect_ray(PhysicsRayQueryParameters3D.create(head, Vector3(head.x, probe.y, head.z), collision_mask, _exclude()))
	if not lid.is_empty():
		probe.y = minf(probe.y, lid.position.y - 0.02)
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
		_hang_jump = false
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
	for h in [0.2, 0.5]:
		var from: Vector3 = feet + Vector3.UP * h
		wall = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + fwd * (RADIUS + 0.5), collision_mask, _exclude()))
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
	_hang_jump = _hang_jump or jump_pressed
	var fwd := controls.move.y < -0.5
	if not fwd:
		_fwd_released = true
	if (_hang_jump or (fwd and _fwd_released)) and _timer >= HANG_SETTLE:
		# Space or a fresh W press climbs up (holding W from the jump only grabs).
		var face := global_position - n * (RADIUS + 0.03)
		var target := face - n * (RADIUS + 0.08)
		target.y = _hang_top + 0.02
		if _fits(target, CRAWL_HEIGHT):
			_start_mantle(target)
			return
		if _hang_jump:
			# No room on top: Space kicks off backwards instead, like off a pipe.
			state = Move.WALK
			velocity = n * 3.0 + Vector3.UP * 3.0
			_was_on_floor = false
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
	var climb_speed := CLIMB_SPEED * (0.5 if winded else 1.0)
	velocity = Vector3.UP * up * climb_speed + right * controls.move.x * climb_speed * 0.5
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
	combat.swung.emit()
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
	var target_y := PlayerCombat.DOWN_EYE if downed else _height - 0.12
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and flat_speed > 0.5 and state == Move.WALK:
		_bob_t += delta * flat_speed * 2.2
		target_y += sin(_bob_t) * 0.035
	head.position.y = lerp(head.position.y, target_y, clamp(delta * 12.0, 0.0, 1.0))
	camera.fov = lerp(camera.fov, 86.0 if state == Move.SLIDE else 78.0, clamp(delta * 8.0, 0.0, 1.0))
	if state == Move.TERMINAL and _term_focus:
		# Eyes onto the screen while stepping up, then the camera moves in to read it.
		var aim := _terminal_aim()
		if terminal_amount <= 1.0:
			var turn := smoothstep(0.0, 1.0, terminal_amount)
			camera.global_transform = Transform3D(_term_look_from.slerp(aim, turn).orthonormalized(), head.global_position)
		else:
			var f := smoothstep(0.0, 1.0, terminal_amount - 1.0)
			camera.global_transform = Transform3D(aim, head.global_position).interpolate_with(terminal_view(), f)
	elif state == Move.ROLL:
		camera.transform = Transform3D(Basis(Vector3.RIGHT, -TAU * (1.0 - clamp(_timer / ROLL_TIME, 0.0, 1.0))), Vector3.ZERO)
	elif downed:
		camera.transform = Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3.ZERO)  # head on the floor
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
		if text == "" and state == Move.SIT and not _sit_leaving:
			text = "[Space] Stand up"
	hud.set_prompt(text)
	if hud.has_method("set_crosshair"):
		hud.set_crosshair(not notebook_cursor)  # reading, the mouse pointer is the one to aim with
