class_name CharacterRig
extends Node3D
## A low-poly person built from primitives, with procedural animation. One rig
## serves players (as teammates see them), Rourke and every other NPC.
##
##   var rig := CharacterRig.build(body_node, CharacterLooks.rourke())
##   rig.play("wave")          # or "idle", "talk", "windup", "down", ...
##
## Walking and running need no calls: the rig measures how fast it is moving and
## swings its legs to match, so it animates the same on every machine from the
## position that is already synced. Actions are either full-body (they replace
## walking) or upper-body (arms and head only; legs keep walking).
##
## The rig stands on its parent's origin and faces -Z, like CharacterBody3D.

## Upper-body actions keep the legs walking; the rest take over the whole body.
const UPPER_BODY := ["idle", "talk", "wave", "point", "radio", "flashlight", "type", "hands_up", "windup", "strike", "shoulder"]
const FULL_BODY := ["stagger", "down", "tied", "dead", "sit", "sit_floor", "crouch", "crawl", "lean", "pose"]
const ACTIONS := UPPER_BODY + FULL_BODY

## Meters covered by one full walk cycle (two steps).
const STRIDE := 1.5
const WALK_SPEED := 1.9
## Turning on the spot steps the feet round: a turn this fast (radians a
## second) or slower doesn't move them, and above it each radian a second
## counts as this many metres a second of walking.
const TURN_STILL := 0.8
const TURN_STEP := 0.3
## Beyond this distance from the camera the rig updates less often.
const FAR_DISTANCE := 30.0
## Body heights, matching Player's collider.
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.25
const CRAWL_HEIGHT := 0.85

## The action playing now (see ACTIONS).
var action := "idle"
## Crouched walking: a 1.25 m bent-knee stance, like Player's crouch.
var crouching := false
## On hands and knees (Player.crawling: vents and low gaps). Wins over crouching.
var crawling := false
## How tall the body is right now, in meters, like the player's collider: 1.8
## standing, 1.25 a bent-knee crouch, 0.85 a crawl. In between, the pose blends
## (lower crouch, then down onto all fours). Leave at -1 to use the two flags.
var stance_height := -1.0
## Up/down look, in radians (a teammate's camera pitch). Positive looks up.
var head_pitch := 0.0
## A point to turn the head toward, or null.
var look_target: Variant = null
## Set >= 0 to drive the walk cycle directly instead of measuring movement.
var speed_override := -1.0

var look: Dictionary
var joints := {}  # name -> Node3D

var _pose := {}  # joint -> current Vector3 rotation
var _root_pos := Vector3.ZERO
var _root_rot := Vector3.ZERO
var _phase := 0.0
var _speed := 0.0
var _t := 0.0
var _last_pos := Vector3.ZERO
var _last_yaw := 0.0
var _has_last := false
var _skip := 0
var _skipped_delta := 0.0

static var _meshes := {}
## Draw the skinned body models (SkinnedBody); false draws the old primitives.
static var skinned := true
var _skin: SkinnedBody


static func build(parent: Node3D, character: Dictionary) -> CharacterRig:
	var rig := CharacterRig.new()
	rig.name = "Rig"
	rig._make(character)
	parent.add_child(rig)
	return rig


## Switch to an action. Unknown names fall back to idle.
func play(new_action: String) -> void:
	action = new_action if ACTIONS.has(new_action) else "idle"


func is_full_body() -> bool:
	return FULL_BODY.has(action)


## How many mesh pieces the rig draws (performance tests keep this small).
func part_count() -> int:
	return find_children("*", "MeshInstance3D", true, false).size()


func _ready() -> void:
	if _skin:
		_skin.update(0.0)  # the skeleton drops poses set before it entered the tree


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	# Far away rigs animate at a quarter rate; nobody can see the difference.
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam and cam.global_position.distance_to(global_position) > FAR_DISTANCE:
		_skip = (_skip + 1) % 4
		_skipped_delta += delta
		if _skip != 0:
			return
		delta = _skipped_delta
	_skipped_delta = 0.0
	animate(delta)


## Advance the animation by `delta` seconds. Called every frame; tests call it directly.
func animate(delta: float) -> void:
	_t += delta
	_measure_speed(delta)
	var target := _target_pose()
	var k := 1.0 - exp(-14.0 * delta)
	var k_root := 1.0 - exp(-7.0 * delta)
	for j in joints:
		var cur: Vector3 = _pose.get(j, Vector3.ZERO)
		var to: Vector3 = target.get(j, Vector3.ZERO)
		cur = cur.lerp(to, k)
		_pose[j] = cur
		joints[j].rotation = cur
	_root_pos = _root_pos.lerp(target.get("_root_pos", Vector3.ZERO), k_root)
	_root_rot = _root_rot.lerp(target.get("_root_rot", Vector3.ZERO), k_root)
	position = _root_pos
	rotation = _root_rot
	if _skin:
		_skin.update(delta)


func _measure_speed(delta: float) -> void:
	var measured := 0.0
	if speed_override >= 0.0:
		measured = speed_override
	elif is_inside_tree():
		var body := get_parent_node_3d() if get_parent_node_3d() else self
		var p := body.global_position
		var yaw := body.global_rotation.y
		if _has_last and delta > 0.0:
			var d := p - _last_pos
			d.y = 0.0
			measured = d.length() / delta
			if measured > 20.0:  # a teleport or respawn, not a sprint
				measured = 0.0
			var turn := absf(wrapf(yaw - _last_yaw, -PI, PI)) / delta
			if turn > TURN_STILL and turn < 30.0:
				measured = maxf(measured, minf(1.2, (turn - TURN_STILL) * TURN_STEP + 0.3))
		_last_pos = p
		_last_yaw = yaw
		_has_last = true
	_speed = lerpf(_speed, measured, 1.0 - exp(-8.0 * delta))
	_phase = fmod(_phase + delta * _speed / STRIDE * TAU, TAU)


## Speed of the walk cycle right now, in m/s.
func current_speed() -> float:
	return _speed


# --- Poses -------------------------------------------------------------------

func _target_pose() -> Dictionary:
	var p := {}
	if not is_full_body():
		var low := crawl_amount()
		if low >= 1.0:
			_crawl(p)
		else:
			_locomotion(p)
			if low > 0.0:
				var on_all_fours := {}
				_crawl(on_all_fours)
				_blend_into(p, on_all_fours, low)
	_action_pose(p)
	_head(p)
	return p


## The body height the rig is posing for (see stance_height).
func current_stance() -> float:
	if stance_height > 0.0:
		return clampf(stance_height, CRAWL_HEIGHT, STAND_HEIGHT)
	if crawling:
		return CRAWL_HEIGHT
	return CROUCH_HEIGHT if crouching else STAND_HEIGHT


## 0 standing .. 1 at the full bent-knee crouch.
func crouch_amount() -> float:
	return clampf((STAND_HEIGHT - current_stance()) / (STAND_HEIGHT - CROUCH_HEIGHT), 0.0, 1.0)


## 0 at the bent-knee crouch .. 1 on hands and knees.
func crawl_amount() -> float:
	return clampf((CROUCH_HEIGHT - current_stance()) / (CROUCH_HEIGHT - CRAWL_HEIGHT), 0.0, 1.0)


static func _blend_into(p: Dictionary, other: Dictionary, k: float) -> void:
	for key in other:
		var kk := k
		if key == "_root_rot":
			kk = pow(k, 0.7)  # tip forward early, so the head drops as the gap does
		p[key] = (p.get(key, Vector3.ZERO) as Vector3).lerp(other[key], kk)
	for key in p:
		if not other.has(key):
			p[key] = (p[key] as Vector3).lerp(Vector3.ZERO, k)


static func _sym(p: Dictionary, joint: String, right: Vector3) -> void:
	p["r_" + joint] = right
	p["l_" + joint] = Vector3(right.x, -right.y, -right.z)


func _locomotion(p: Dictionary) -> void:
	var walk := clampf(_speed / WALK_SPEED, 0.0, 1.0)
	var run := clampf((_speed - WALK_SPEED) / 2.5, 0.0, 1.0)
	var amp := walk * (0.85 + 0.35 * run)
	var s := sin(_phase)
	var c := cos(_phase)
	var crouch := crouch_amount()
	# Legs.
	p["r_hip"] = Vector3(s * 0.5 * amp * (1.0 - 0.5 * crouch) + crouch * 1.4, 0, 0.03)
	p["l_hip"] = Vector3(-s * 0.5 * amp * (1.0 - 0.5 * crouch) + crouch * 1.4, 0, -0.03)
	p["r_knee"] = Vector3(-amp * (0.1 + 0.75 * maxf(0.0, c)) - crouch * 2.2, 0, 0)
	p["l_knee"] = Vector3(-amp * (0.1 + 0.75 * maxf(0.0, -c)) - crouch * 2.2, 0, 0)
	# Arms swing against the legs; running pumps with bent elbows.
	p["r_shoulder"] = Vector3(-s * 0.45 * amp, 0, 0.07)
	p["l_shoulder"] = Vector3(s * 0.45 * amp, 0, -0.07)
	_sym(p, "elbow", Vector3(0.15 + 0.35 * walk + 0.9 * run, 0, 0))
	# Body: twist, lean into a run, bob on each footfall, breathe when still.
	var breathe := sin(_t * 1.7) * 0.02 * (1.0 - walk)
	p["spine"] = Vector3(-0.03 * walk - 0.18 * run - 0.3 * crouch + breathe, s * 0.07 * amp, 0)
	p["neck"] = Vector3(0.03 * walk + 0.12 * run + 0.2 * crouch, -s * 0.05 * amp, 0)
	p["hips"] = Vector3(0, -s * 0.05 * amp, c * 0.03 * amp)
	p["_root_pos"] = Vector3(0, -0.035 * amp * absf(s) - 0.48 * crouch, 0)


func _action_pose(p: Dictionary) -> void:
	var t := _t
	match action:
		"idle":
			pass
		"talk":
			p["r_shoulder"] = Vector3(0.35 + sin(t * 2.3) * 0.15, 0, 0.12)
			p["r_elbow"] = Vector3(1.0 + sin(t * 3.1) * 0.25, 0, 0)
			p["l_shoulder"] = Vector3(0.15 + sin(t * 1.7 + 1.0) * 0.08, 0, -0.1)
			p["l_elbow"] = Vector3(0.6 + sin(t * 2.2) * 0.15, 0, 0)
			p["neck"] = Vector3(sin(t * 2.7) * 0.06, sin(t * 0.9) * 0.12, 0)
		"wave":
			p["r_shoulder"] = Vector3(0.2, 0, 2.5 + sin(t * 8.0) * 0.25)
			p["r_elbow"] = Vector3(0.5, 0, 0)
		"point":
			p["r_shoulder"] = Vector3(1.5, 0.15, 0.05)
			p["r_elbow"] = Vector3(0.05, 0, 0)
		"radio":
			# Walkie up to the mouth in the left hand.
			p["l_shoulder"] = Vector3(1.0, 0.3, -0.45)
			p["l_elbow"] = Vector3(2.1, 0, 0)
			p["neck"] = Vector3(-0.1, -0.15, 0)
		"flashlight":
			# Torch held out in the right hand, following where they look.
			p["r_shoulder"] = Vector3(1.35 + head_pitch * 0.8, 0.1, -0.05)
			p["r_elbow"] = Vector3(0.3, 0, 0)
		"type":
			_sym(p, "shoulder", Vector3(0.55, 0, -0.12))
			p["r_elbow"] = Vector3(1.15 + sin(t * 11.0) * 0.06, 0, 0)
			p["l_elbow"] = Vector3(1.15 + sin(t * 9.0 + 2.0) * 0.06, 0, 0)
			p["neck"] = Vector3(-0.25, 0, 0)
		"hands_up":
			_sym(p, "shoulder", Vector3(0.3, 0, 2.3))
			_sym(p, "elbow", Vector3(1.2, 0, 0))
		"windup":
			# Rourke's tell before a hit: lean in, arms back and up.
			p["spine"] = Vector3(-0.3, 0.25, 0)
			p["r_shoulder"] = Vector3(1.9, 0, 0.5)
			p["r_elbow"] = Vector3(1.5, 0, 0)
			p["l_shoulder"] = Vector3(0.9, 0, -0.25)
			p["l_elbow"] = Vector3(1.2, 0, 0)
		"shoulder":
			# An arm around whoever stands about 0.6 m to the right, the hand
			# resting on their far shoulder.
			p["r_shoulder"] = Vector3(-0.45, 0, 1.45)
			p["r_elbow"] = Vector3(0.35, 0, 0)
			p["neck"] = Vector3(0, -0.1, 0.05)
		"strike":
			p["spine"] = Vector3(-0.45, -0.2, 0)
			_sym(p, "shoulder", Vector3(1.45, 0, 0.05))
			_sym(p, "elbow", Vector3(0.15, 0, 0))
		"stagger":
			p["spine"] = Vector3(0.35, 0, 0.05)
			p["neck"] = Vector3(0.3, 0.2, 0)
			_sym(p, "shoulder", Vector3(0.5, 0, 0.9))
			_sym(p, "elbow", Vector3(0.5, 0, 0))
			p["r_hip"] = Vector3(0.25, 0, 0.05)
			p["l_hip"] = Vector3(-0.2, 0, -0.05)
			p["r_knee"] = Vector3(-0.4, 0, 0)
			p["l_knee"] = Vector3(-0.1, 0, 0)
		"down", "dead":
			# Flat on his back, limbs loose.
			p["_root_rot"] = Vector3(PI / 2, 0, 0)
			p["_root_pos"] = Vector3(0, 0.14, 0)
			_sym(p, "shoulder", Vector3(0.1, 0, 0.6 if action == "down" else 1.3))
			_sym(p, "elbow", Vector3(0.4, 0, 0))
			p["r_hip"] = Vector3(0.1, 0, 0.12)
			p["l_hip"] = Vector3(0.25, 0, -0.08)
			p["l_knee"] = Vector3(-0.4, 0, 0)
			p["neck"] = Vector3(0.1, 0.9 if action == "dead" else sin(t * 0.8) * 0.15, 0)
		"tied":
			# On his side, wrists behind his back, knees drawn up.
			p["_root_rot"] = Vector3(PI / 2, 0, PI / 2)
			p["_root_pos"] = Vector3(0, 0.2, 0)
			_sym(p, "shoulder", Vector3(-0.7, 0, 0.15))
			_sym(p, "elbow", Vector3(1.3, 0, 0))
			_sym(p, "hip", Vector3(0.7, 0, 0))
			_sym(p, "knee", Vector3(-1.2, 0, 0))
			# He struggles now and then.
			p["spine"] = Vector3(0.1 + maxf(0.0, sin(t * 0.7)) * 0.15 * sin(t * 9.0), 0, 0)
		"sit":
			p["_root_pos"] = Vector3(0, -0.45, 0)
			_sym(p, "hip", Vector3(1.5, 0, 0.05))
			_sym(p, "knee", Vector3(-1.5, 0, 0))
			_sym(p, "shoulder", Vector3(0.35, 0, 0.05))
			_sym(p, "elbow", Vector3(0.9, 0, 0))
		"sit_floor":
			# On the floor, legs out in front and knees loose, leaning back on both hands.
			p["_root_pos"] = Vector3(0, -0.75, 0)
			_sym(p, "hip", Vector3(1.75, 0, 0.12))
			_sym(p, "knee", Vector3(-0.45, 0, 0))
			p["spine"] = Vector3(0.18, 0, 0)
			p["neck"] = Vector3(-0.12, 0, 0)
			_sym(p, "shoulder", Vector3(-0.55, 0, 0.18))
			_sym(p, "elbow", Vector3(0.1, 0, 0))
		"crawl":
			_crawl(p)
		"lean":
			# Back against a wall or the van, arms crossed, one foot up flat behind.
			p["_root_rot"] = Vector3(0.1, 0, 0)
			p["_root_pos"] = Vector3(0, -0.02, 0)
			_sym(p, "hip", Vector3(0.1, 0, 0.03))
			p["l_hip"] = Vector3(0.3, 0, -0.03)
			p["l_knee"] = Vector3(-1.0, 0, 0)
			p["neck"] = Vector3(-0.08, 0.15, 0)
			p["r_shoulder"] = Vector3(0.05, 1.4, 0.7)
			p["l_shoulder"] = Vector3(0.0, -1.4, -0.7)
			p["r_elbow"] = Vector3(1.7, 0, 0)
			p["l_elbow"] = Vector3(1.55, 0, 0)
		"pose":
			# Feet apart, chest out, fists on the hips: ready for anything.
			_sym(p, "hip", Vector3(0, 0, 0.14))
			p["spine"] = Vector3(0.06, 0, 0)
			p["neck"] = Vector3(0.08, -0.1, 0)
			_sym(p, "shoulder", Vector3(-0.6, 1.4, 0))
			_sym(p, "elbow", Vector3(1.6, 0, 0))
		"crouch":
			p["_root_pos"] = Vector3(0, -0.48, 0)
			_sym(p, "hip", Vector3(1.4, 0, 0.1))
			_sym(p, "knee", Vector3(-2.2, 0, 0))
			p["spine"] = Vector3(-0.3, 0, 0)
			p["neck"] = Vector3(0.2, 0, 0)
			_sym(p, "shoulder", Vector3(0.4, 0, 0.1))
			_sym(p, "elbow", Vector3(0.6, 0, 0))


## Hands and knees, body level with the floor, head forward. Opposite hand and
## knee move together, paced by the measured speed.
func _crawl(p: Dictionary) -> void:
	var go := clampf(_speed / 1.0, 0.0, 1.0)
	var s := sin(_phase * 2.0) * go
	# Tip the whole body forward onto all fours, then lift it to arm's length.
	p["_root_rot"] = Vector3(-PI / 2, 0, 0)
	p["_root_pos"] = Vector3(0, 0.5, 0.55)
	p["r_shoulder"] = Vector3(1.5 + 0.35 * s, 0, 0.05)
	p["l_shoulder"] = Vector3(1.5 - 0.35 * s, 0, -0.05)
	_sym(p, "elbow", Vector3(0.1, 0, 0))
	p["r_hip"] = Vector3(1.5 + 0.3 * s, 0, 0.05)
	p["l_hip"] = Vector3(1.5 - 0.3 * s, 0, -0.05)
	_sym(p, "knee", Vector3(-1.5, 0, 0))
	p["spine"] = Vector3(0.1, s * 0.06, 0)
	p["neck"] = Vector3(1.2, 0, 0)  # look ahead down the duct, not at the floor


func _head(p: Dictionary) -> void:
	var h: Vector3 = p.get("head", Vector3.ZERO)
	h.x += clampf(head_pitch, -1.2, 1.2) * 0.7
	if look_target is Vector3 and not is_full_body() and is_inside_tree():
		var head_node: Node3D = joints["head"]
		var d: Vector3 = global_transform.basis.inverse() * ((look_target as Vector3) - head_node.global_position)
		var flat := Vector2(d.x, d.z).length()
		if flat > 0.05:
			h.y += clampf(atan2(-d.x, -d.z), -1.1, 1.1)
			h.x += clampf(atan2(d.y, flat), -0.6, 0.6)
	p["head"] = h


# --- Building the body ---------------------------------------------------------

func _make(character: Dictionary) -> void:
	look = CharacterLooks.base()
	look.merge(character, true)
	var hs: float = look.height
	var b: float = look.build
	scale = Vector3.ONE * hs
	if skinned:
		_make_joints(b)
		_skin = SkinnedBody.attach(self, look)
		return
	var skin := ArtPalette.flat(look.skin, 0.7)
	var shirt := ArtPalette.flat(look.shirt, 0.9)
	var pants := ArtPalette.flat(look.pants, 0.9)
	var shoes := ArtPalette.flat(look.shoes, 0.6)
	var jacket: StandardMaterial3D = ArtPalette.flat(look.jacket, 0.85) if look.jacket is Color else null
	var sleeve := jacket if jacket else shirt
	var forearm := sleeve if look.sleeves == "long" or jacket else skin

	# Body type 2: narrower shoulders and waist, fuller hips, a shaped chest.
	var two: bool = look.body == 2
	var sw := b * (0.88 if two else 1.0)  # shoulder and chest width
	var ww := b * (0.8 if two else 1.0)  # waist
	var hw := b * (1.1 if two else 1.0)  # hips
	var hips := _joint("hips", self, Vector3(0, 0.92, 0))
	_part(hips, "box", Vector3(0.32 * hw, 0.2, 0.2), Vector3(0, 0, 0), pants, true)
	var spine := _joint("spine", hips, Vector3(0, 0.06, 0))
	# A zipped jacket covers the shirt: it is drawn as the torso itself.
	var closed: bool = jacket != null and look.jacket_closed
	var torso := jacket if closed else shirt
	var bulk := 0.012 if closed else 0.0
	_part(spine, "box", Vector3(0.4 * sw + bulk, 0.28, (0.23 if not two else 0.21) + bulk), Vector3(0, 0.35, 0), torso, true)  # chest
	_part(spine, "box", Vector3(0.34 * ww + bulk, 0.22, (0.21 if not two else 0.19) + bulk), Vector3(0, 0.1, 0), torso, true)  # waist
	if two:
		_part(spine, "sphere", Vector3(0.13 * sw, 0.055, 0.03), Vector3(0, 0.33, -0.095 - bulk / 2), torso)
	if closed:
		_part(spine, "box", Vector3((0.42 if not look.shoulder_pads else 0.46) * sw, 0.12, 0.25), Vector3(0, 0.44, 0.01), jacket)  # collar and shoulders
	elif jacket:
		var shoulder := 0.46 if look.shoulder_pads else 0.42
		for side in [-1.0, 1.0]:
			_part(spine, "box", Vector3(0.15 * sw, 0.5, 0.25), Vector3(side * 0.13 * sw, 0.24, 0.005), jacket, true)
		_part(spine, "box", Vector3(shoulder * sw, 0.12, 0.25), Vector3(0, 0.44, 0.01), jacket)  # collar and shoulders
	if look.collar and not jacket:
		_part(spine, "box", Vector3(0.17 * sw, 0.035, 0.17), Vector3(0, 0.485, -0.005), shirt)
	if look.logo is Color:
		_part(spine, "box", Vector3(0.07, 0.05, 0.01), Vector3(-0.1 * sw, 0.38, -0.12 if not jacket else -0.13), ArtPalette.flat(look.logo))
	if jacket and look.jacket_badge is Color:
		_part(spine, "box", Vector3(0.045, 0.055, 0.012), Vector3(-0.1 * sw, 0.37, -0.132), ArtPalette.flat(look.jacket_badge, 0.3, 0.8))
	if look.lanyard is Color:
		_part(spine, "box", Vector3(0.025, 0.24, 0.01), Vector3(0, 0.38, -0.121), ArtPalette.flat(look.lanyard))
	if look.badge:
		var badge_y := 0.24 if look.lanyard is Color else 0.33
		var badge_x := 0.0 if look.lanyard is Color else 0.1 * sw
		_part(spine, "box", Vector3(0.06, 0.085, 0.01), Vector3(badge_x, badge_y, -0.125), ArtPalette.flat(Color(0.95, 0.95, 0.92), 0.4))
	var neck := _joint("neck", spine, Vector3(0, 0.49, 0))
	_part(neck, "cyl", Vector3(0.05, 0.08, 0), Vector3(0, 0.03, 0), skin)
	var head := _joint("head", neck, Vector3(0, 0.07, 0))
	_part(head, "sphere", Vector3(0.115, 0.135, 0.12), Vector3(0, 0.1, 0), skin, true)
	_make_face(head)
	_make_hair(head)

	for side in ["r", "l"]:
		var sx := 1.0 if side == "r" else -1.0
		var sh := _joint(side + "_shoulder", spine, Vector3(sx * 0.215 * sw, 0.43, 0))
		_part(sh, "sphere", Vector3(0.062 * sw, 0.06, 0.062), Vector3(0, -0.02, 0), sleeve)
		_part(sh, "capsule", Vector3((0.05 if two else 0.055) * b, 0.3, 0), Vector3(0, -0.13, 0), sleeve)
		var el := _joint(side + "_elbow", sh, Vector3(0, -0.28, 0))
		_part(el, "capsule", Vector3(0.045, 0.28, 0), Vector3(0, -0.12, 0), forearm)
		_part(el, "box", Vector3(0.07, 0.1, 0.04), Vector3(0, -0.29, 0), skin)
		var hip := _joint(side + "_hip", hips, Vector3(sx * 0.09 * hw, -0.05, 0))
		_part(hip, "capsule", Vector3(0.075 * b, 0.46, 0), Vector3(0, -0.21, 0), pants, true)
		var knee := _joint(side + "_knee", hip, Vector3(0, -0.43, 0))
		_part(knee, "capsule", Vector3(0.06, 0.42, 0), Vector3(0, -0.19, 0), pants, true)
		if look.high_tops:
			_part(knee, "box", Vector3(0.11, 0.14, 0.25), Vector3(0, -0.37, -0.045), shoes)  # up over the ankle
		else:
			_part(knee, "box", Vector3(0.1, 0.08, 0.25), Vector3(0, -0.4, -0.05), shoes)
		if side == "r" and look.belt_radio and not (jacket and look.coat):  # a long coat hides the belt
			_part(hips, "box", Vector3(0.05, 0.12, 0.07), Vector3(0.19 * hw, -0.02, 0.02), ArtPalette.flat(ArtPalette.DARK_PLASTIC, 0.5))
	if jacket and look.coat:
		# A long coat (lab coat) hangs from the waist to the knees.
		_part(hips, "box", Vector3(0.4 * hw, 0.5, 0.26), Vector3(0, -0.2, 0.005), jacket, true)


## The joints alone, where the primitive body puts them; the skinned body follows them.
func _make_joints(b: float) -> void:
	var two: bool = look.body == 2
	var sw := b * (0.88 if two else 1.0)
	var hw := b * (1.1 if two else 1.0)
	var hips := _joint("hips", self, Vector3(0, 0.92, 0))
	var spine := _joint("spine", hips, Vector3(0, 0.06, 0))
	_joint("head", _joint("neck", spine, Vector3(0, 0.49, 0)), Vector3(0, 0.07, 0))
	for side in ["r", "l"]:
		var sx := 1.0 if side == "r" else -1.0
		_joint(side + "_elbow", _joint(side + "_shoulder", spine, Vector3(sx * 0.215 * sw, 0.43, 0)), Vector3(0, -0.28, 0))
		_joint(side + "_knee", _joint(side + "_hip", hips, Vector3(sx * 0.09 * hw, -0.05, 0)), Vector3(0, -0.43, 0))


func _make_face(head: Node3D) -> void:
	var dark := ArtPalette.flat(Color(0.06, 0.05, 0.05), 0.4)
	for sx in [-1.0, 1.0]:
		_part(head, "box", Vector3(0.025, 0.018, 0.01), Vector3(sx * 0.045, 0.125, -0.108), dark)
	_part(head, "box", Vector3(0.03, 0.045, 0.03), Vector3(0, 0.09, -0.118), ArtPalette.flat(look.skin, 0.7))
	if look.lips is Color:
		_part(head, "box", Vector3(0.034, 0.01, 0.01), Vector3(0, 0.06, -0.112), ArtPalette.flat(look.lips, 0.35))
	if look.earrings is Color:
		# One bar through the head: only its two ends show, as studs at the lobes.
		_part(head, "box", Vector3(0.222, 0.012, 0.012), Vector3(0, 0.035, -0.01), ArtPalette.flat(look.earrings, 0.25, 0.9))
	if look.mustache is Color:
		_part(head, "box", Vector3(0.08, 0.02, 0.02), Vector3(0, 0.055, -0.115), ArtPalette.flat(look.mustache))
	if look.glasses:
		# Thin frames just above the eyes, so they read as glasses, not shades.
		var frames: Color = look.glasses if look.glasses is Color else Color(0.12, 0.1, 0.1)
		_part(head, "box", Vector3(0.15, 0.012, 0.008), Vector3(0, 0.138, -0.118), ArtPalette.flat(frames, 0.3))
	elif look.readers is Color:
		# Half-moon readers: thin wire perched low on the nose, under the eyes.
		_part(head, "box", Vector3(0.13, 0.012, 0.006), Vector3(0, 0.106, -0.136), ArtPalette.flat(look.readers, 0.3, 0.6))


func _make_hair(head: Node3D) -> void:
	var hair := ArtPalette.flat(look.hair, 0.95)
	if look.headwear is String:
		_make_headwear(head, hair)
		return
	match look.hair_style:
		"short":
			_part(head, "sphere", Vector3(0.122, 0.1, 0.127), Vector3(0, 0.15, 0.01), hair)
		"long":
			_part(head, "sphere", Vector3(0.125, 0.11, 0.13), Vector3(0, 0.15, 0.012), hair)
			_part(head, "box", Vector3(0.22, 0.28, 0.08), Vector3(0, 0.0, 0.08), hair)
		"bald":
			# A fringe round the back and sides only.
			_part(head, "sphere", Vector3(0.122, 0.055, 0.11), Vector3(0, 0.09, 0.035), hair)
		"bob":
			# Chin-length, full at the sides, a side part with volume on top.
			_part(head, "sphere", Vector3(0.124, 0.1, 0.13), Vector3(0.006, 0.152, 0.012), hair)
			_part(head, "box", Vector3(0.24, 0.14, 0.19), Vector3(0, 0.1, 0.035), hair)  # sides and back, open at the face
		"cap":
			_part(head, "sphere", Vector3(0.125, 0.09, 0.13), Vector3(0, 0.17, 0.0), hair)
			_part(head, "box", Vector3(0.18, 0.015, 0.1), Vector3(0, 0.165, -0.15), hair)


## A hat replaces the top of the hair; long hair and bobs still show below it.
func _make_headwear(head: Node3D, hair: StandardMaterial3D) -> void:
	match look.hair_style:
		"long":
			_part(head, "box", Vector3(0.22, 0.28, 0.08), Vector3(0, 0.0, 0.08), hair)
		"bob":
			_part(head, "box", Vector3(0.24, 0.14, 0.19), Vector3(0, 0.1, 0.035), hair)
		"short":
			_part(head, "sphere", Vector3(0.121, 0.08, 0.125), Vector3(0, 0.12, 0.012), hair)
	var hat := ArtPalette.flat(look.headwear_color, 0.85)
	match look.headwear:
		"cap":
			_part(head, "sphere", Vector3(0.125, 0.09, 0.13), Vector3(0, 0.17, 0.0), hat)
			_part(head, "box", Vector3(0.18, 0.015, 0.1), Vector3(0, 0.165, -0.15), hat)
		"beanie":
			_part(head, "sphere", Vector3(0.128, 0.11, 0.132), Vector3(0, 0.175, 0.0), hat)
			_part(head, "cyl", Vector3(0.127, 0.035, 0), Vector3(0, 0.15, 0.0), hat)  # turned-up cuff
		"hard_hat":
			_part(head, "sphere", Vector3(0.13, 0.1, 0.135), Vector3(0, 0.18, 0.0), ArtPalette.flat(look.headwear_color, 0.45))
			_part(head, "cyl", Vector3(0.15, 0.012, 0), Vector3(0, 0.155, -0.01), ArtPalette.flat(look.headwear_color, 0.45))  # brim
		"mercer_cap":
			# Mercer's old cap: faded, the crown gone soft and the brim bent down from years of wear.
			var faded := ArtPalette.flat(look.headwear_color.lerp(Color(0.75, 0.72, 0.62), 0.15), 1.0)
			_part(head, "sphere", Vector3(0.126, 0.08, 0.13), Vector3(0.004, 0.165, 0.005), faded).rotation = Vector3(0.08, 0, -0.06)
			_part(head, "box", Vector3(0.17, 0.014, 0.1), Vector3(0, 0.155, -0.148), faded).rotation = Vector3(-0.3, 0, 0)


func _joint(joint_name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = joint_name
	j.position = pos
	parent.add_child(j)
	joints[joint_name] = j
	_pose[joint_name] = Vector3.ZERO
	return j


## One mesh piece. kind: box (size), sphere (radii), capsule (radius, length),
## cyl (radius, length). Meshes are shared between rigs by size.
func _part(parent: Node3D, kind: String, dims: Vector3, pos: Vector3, mat: Material, shadow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind, dims)
	mi.position = pos
	if kind == "sphere":
		mi.scale = dims / dims.x
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _mesh(kind: String, dims: Vector3) -> Mesh:
	var key := "%s|%.3f|%.3f|%.3f" % [kind, dims.x, dims.y, dims.z]
	if _meshes.has(key):
		return _meshes[key]
	var m: PrimitiveMesh
	match kind:
		"box":
			var bm := BoxMesh.new()
			bm.size = dims
			m = bm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = dims.x
			sm.height = dims.x * 2.0
			sm.radial_segments = 12
			sm.rings = 6
			m = sm
		"capsule":
			var cm := CapsuleMesh.new()
			cm.radius = dims.x
			cm.height = maxf(dims.y, dims.x * 2.0 + 0.01)
			cm.radial_segments = 8
			cm.rings = 2
			m = cm
		"cyl":
			var cy := CylinderMesh.new()
			cy.top_radius = dims.x
			cy.bottom_radius = dims.x
			cy.height = dims.y
			cy.radial_segments = 8
			m = cy
	_meshes[key] = m
	return m
