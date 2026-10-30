class_name SkinnedBody
extends RefCounted
## CharacterRig's body: one of the two models tools/art/build_characters.py
## makes from the Quaternius base characters, dressed from a look and posed
## from the rig every frame.
##
## The rig keeps its joints and procedural poses. Each joint turns the bone it
## names in JOINT_BONES, and the rest of the 65-bone skeleton follows. While
## nothing game-specific is playing, the pack's own clips (idle, walk, jog,
## sprint) move the body instead, since they are smoother than ours. An upper-
## body action like "talk" takes the arms back, and a full-body one (sit,
## crouch, crawl, down) takes everything.
##
## Each model holds every garment as its own mesh (Collar, Jacket_open,
## Hair_long, ...). The look picks which to keep and tints them. Skin, shirt,
## trousers and shoes are painted on the body by its shader, so a dressed
## character is about four draws.

const MODELS := {1: "character/body1", 2: "character/body2"}
const BODY_SHADER := preload("res://assets/art/characters/body.gdshader")
## Where a sleeve ends, as a share of the arm from shoulder to fingertips.
const SHORT_SLEEVE := 0.33
const LONG_SLEEVE := 0.86
const UNDER_JACKET := 0.6
## Where each jacket ends, as a height on the body (tools/art/build_characters.py).
const JACKET_HEMS := {"Jacket_open": 0.8, "Jacket_closed": 0.83, "Jacket_blazer": 0.79, "Jacket_coat": 0.48}
## How far the body draws in under a jacket, so it can't poke through.
const TUCK := 0.015
## Where shoes end, as a height on the body (CharacterRig's units, as the shader's).
const SHOE_TOP := 0.085
const HIGH_TOP := 0.15
## The rig's joints, and the bones they turn.
const JOINT_BONES := {
	"hips": "pelvis", "spine": "spine_01", "neck": "neck_01", "head": "Head",
	"r_shoulder": "upperarm_r", "r_elbow": "lowerarm_r", "r_hip": "thigh_r", "r_knee": "calf_r",
	"l_shoulder": "upperarm_l", "l_elbow": "lowerarm_l", "l_hip": "thigh_l", "l_knee": "calf_l",
}
const LOWER := ["hips", "r_hip", "r_knee", "l_hip", "l_knee"]
const ALWAYS := ["neck", "head"]  # look targets and nods win over any clip
## How far each clip moves in a second at normal speed (tools/art/extract_clips.gd).
const CLIP_SPEEDS := {"Walk_Loop": 0.97, "Jog_Fwd_Loop": 5.36, "Sprint_Loop": 8.25}
## The arms hang this far out from straight down (radians), clear of the hips.
const ARM_SPREAD := 0.12
## How fast a body hands over between the clips and the rig's poses, per second.
const BLEND_RATE := 5.0
## How far the clips' fists curl the fingers; less looks relaxed, not ready to fight.
const FINGER_CURL := 0.4
## Actions the pack has a clip for play it on the whole body, fists and all:
## a punch, the guard it starts from (held at its first frame), a hit taken.
const ACTION_CLIPS := {"jab": "Punch_Jab", "cross": "Punch_Cross", "guard": "Punch_Jab",
	"recoil": "Hit_Chest", "flinch": "Hit_Head"}
const HELD := ["guard"]
const FINGERS := ["thumb", "index", "middle", "ring", "pinky"]
## Reaching (CharacterRig.reach), the elbow bends towards this, in the rig's
## space for the right arm (x flips for the left): down, out and a little back.
const ELBOW_POLE := Vector3(0.6, -1.0, 0.4)
## A hand resting on its thigh: this far along it from the hip (forearm along
## the thigh, the upper arm hanging), and this far up, onto the top of it.
const KNEE_REST := Vector2(0.24, 0.08)
## The chest bones between the rig's spine and neck joints. The pack's idle bends
## them forward to stand over its own tilted pelvis; under the rig's upright hips
## that bend made everyone stoop, so while the rig holds the hips they keep their
## rest shape, upright.
const CHEST := ["spine_02", "spine_03"]
## How much of the clip's shoulder angle survives straightening the chest: all
## of it swings the arms back behind the hips, none leaves them reaching forward.
const SHOULDER_KEEP := 0.6
## The flesh a look's "shape" can fill out (CharacterLooks.CREW_BODIES), by the
## bones it follows: bone (left and right alike) -> region.
const REGIONS := {"clavicle": "shoulders", "spine_03": "chest", "spine_02": "belly", "spine_01": "belly",
	"pelvis": "hips", "thigh": "legs", "calf": "legs", "upperarm": "arms", "lowerarm": "arms", "neck_01": "neck"}
## A fuller belly comes this much further forward than it fills out to the sides.
const BELLY_FORWARD := 1.0
## The feet below the rig's knees. The pack's idle turns them in to stand under
## its own legs; under the rig's straight legs that left everyone pigeon-toed, so
## while the rig holds the legs they keep their rest shape, flat and forward.
const FEET := ["foot_r", "foot_l", "ball_r", "ball_l"]
## The pack's feet are bare and small (about 21 cm), and the shader only paints
## shoes on them, so they read as small and pointed. A shoe is this much longer
## (about its middle), wider (and wider still towards a blunt toe) and higher
## near the floor, its sole staying on it.
const SHOE_LONG := 0.35
const SHOE_WIDE := 0.35
const SHOE_TOE := 0.5
const SHOE_HIGH := 0.5
const SHOE_LOW := 0.08  # how high off the floor the shoe fills out
const SHOE_BONES := ["foot", "ball", "ball_leaf"]
## The bare toes show through as bumps and a point; this many passes smooth them
## into a toe box, and the toe's sides push out this far (m) to round its tip.
const TOE_SMOOTH := 8
const TOE_ROUND := 0.02

var model: Node3D
var skeleton: Skeleton3D
## Plays the pack's clips; null when the clip library is missing.
var player: AnimationPlayer

var _rig: CharacterRig
var _order: Array[int] = []  # every bone, parents first
var _parent: Array[int] = []
var _rest_local: Array[Transform3D] = []  # the pose the rig's joints start from (arms down)
var _driven := {}  # bone -> [joint, the bone's rest basis relative to the joint's]
var _hips_offset := Transform3D.IDENTITY  # the pelvis relative to the hips joint
var _skel := Transform3D.IDENTITY  # the skeleton in rig space
var _feet: Array[int] = []
var _fingers := {}  # finger bone -> its hand's side ("r", "l"), or "thumb"
var _chest := {}
var _foot_bones := {}
var _pelvis := -1
var _foot_height := 0.0
var _head_bone := -1
var _action_playing := ""  # the ACTION_CLIPS action the clips are playing, if any
var _upper := 1.0
var _lower := 1.0
var _clip := ""
var _stoop := 0.0  # look.stoop

static var _scaled := {}  # "body|build|shape|mesh" -> [Mesh, Skin]
static var _materials := {}


## Builds the model under `rig`, keeps the meshes `look` wears and binds the
## skeleton to the rig's joints. `look.build` widens the body, `look.shape`
## fills out its regions and `look.stoop` rounds its back.
static func attach(rig: CharacterRig, look: Dictionary) -> SkinnedBody:
	var sb := SkinnedBody.new()
	sb._rig = rig
	var body: int = 2 if int(look.body) == 2 else 1
	sb.model = ArtModels.scene(MODELS[body]).instantiate()
	sb.model.name = "Model"
	rig.add_child(sb.model)
	sb.skeleton = sb.model.find_children("*", "Skeleton3D", true, false)[0]
	var keep := wears(look)
	var build: float = look.build
	var shape: Dictionary = look.get("shape", {})
	sb._stoop = float(look.get("stoop", 0.0))
	for mi: MeshInstance3D in sb.model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.name)
		if not keep.has(part):
			mi.get_parent().remove_child(mi)
			mi.free()
			continue
		if part == "Body" or not is_equal_approx(build, 1.0) or not shape.is_empty():
			var m: Array = _shaped(body, build, shape, part, mi.mesh, mi.skin)
			mi.mesh = m[0]
			mi.skin = m[1]
		mi.material_override = _material(part, keep[part])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _casts_shadow(part) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sb._bind()
	sb._add_clips()
	sb.update(0.0)
	return sb


## Poses the skeleton: the clip for the moment, then the rig's joints over it.
## CharacterRig calls this after each animate().
func update(delta: float) -> void:
	var full := _rig.is_full_body() or _rig.crouch_amount() > 0.02
	var acted: bool = player != null and ACTION_CLIPS.has(_rig.action) and not full
	var upper_target := 1.0 if (full or _rig.action != "idle" or player == null) and not acted else 0.0
	var lower_target := 1.0 if (full or player == null or _clip == "Idle_Loop") and not acted else 0.0
	var k := clampf(delta * BLEND_RATE, 0.0, 1.0) if delta > 0.0 else 1.0
	_upper = lerpf(_upper, upper_target, k)
	_lower = lerpf(_lower, lower_target, k)
	if player:
		if acted:
			_play_action(_rig.action)
		else:
			_play_clip(_rig.current_speed())
		player.advance(delta)
	var cache := {}
	var curl := 1.0 if acted else FINGER_CURL
	var clip_chest := {}  # chest bone -> where the clip alone would put it
	var inv := _skel.affine_inverse()
	var g: Array[Transform3D] = []
	g.resize(_parent.size())
	for i in _order:
		var parent := _parent[i]
		var parent_g: Transform3D = g[parent] if parent >= 0 else Transform3D.IDENTITY
		var base: Transform3D = skeleton.get_bone_pose(i) if player else _rest_local[i]
		if player and _fingers.has(i):
			var c := curl
			if _rig.grip_curl >= 0.0 and _fingers[i] != "thumb":
				c = lerpf(curl, _rig.grip_curl, _rig.reach_weight(_fingers[i]))  # flat behind what it holds
			base.basis = Basis(_rest_local[i].basis.get_rotation_quaternion().slerp(base.basis.get_rotation_quaternion(), c))
		elif player and _chest.has(i):
			# Straighten the chest, and remember where the clip had it, so the
			# shoulders it carries can stay where the clip put them (arms hanging).
			var clip_parent: Transform3D = clip_chest.get(parent, parent_g)
			clip_chest[i] = clip_parent * base
			base.basis = Basis(base.basis.get_rotation_quaternion().slerp(_rest_local[i].basis.get_rotation_quaternion(), _lower))
		elif player and _foot_bones.has(i):
			base.basis = Basis(base.basis.get_rotation_quaternion().slerp(_rest_local[i].basis.get_rotation_quaternion(), _lower))
		if _stoop != 0.0 and _chest.has(i):
			# Round forward about the body's own side-to-side axis (the rig faces -z);
			# the neck and head stay level (ALWAYS).
			var across := (parent_g.basis.inverse() * (inv.basis * Vector3.RIGHT)).normalized()
			base.basis = Basis(across, -_stoop / CHEST.size()) * base.basis
		elif player and clip_chest.has(parent) and not _driven.has(i):
			var keep := Basis(Quaternion.IDENTITY.slerp((parent_g.basis.inverse() * clip_chest[parent].basis).get_rotation_quaternion(), SHOULDER_KEEP))
			base.basis = keep * base.basis
		var pose := base
		if _driven.has(i):
			var joint: String = _driven[i][0]
			var w := 1.0 if joint in ALWAYS else (_lower if joint in LOWER else _upper)
			var target: Basis = inv.basis * _in_rig(_rig.joints[joint], cache).basis * _driven[i][1]
			var turn := (parent_g.basis.inverse() * target).get_rotation_quaternion()
			pose.basis = Basis(base.basis.get_rotation_quaternion().slerp(turn, w))
			if joint == "hips":
				var at: Vector3 = inv * (_in_rig(_rig.joints["hips"], cache) * _hips_offset).origin
				pose.origin = base.origin.lerp(parent_g.affine_inverse() * at, w)
		g[i] = parent_g * pose
		skeleton.set_bone_pose(i, pose)
	var lift := _plant_feet(g, cache) if _lower > 0.0 else Vector3.ZERO
	for side in ["r", "l"]:
		if _rig.reach_weight(side) > 0.0:
			_reach(side, g, lift)
	if _rig.hide_head:
		# Shrink the head to a point: the hair, hat and glasses ride on it too.
		skeleton.set_bone_pose_scale(_head_bone, Vector3.ONE * 0.001)


## Mesh name -> what it wears: a Color for a tinted part, or a Dictionary of
## shader settings for the body.
static func wears(look: Dictionary) -> Dictionary:
	var out := {}
	out["Body"] = {
		"skin_color": look.skin,
		"top_color": look.shirt,
		"pants_color": look.pants,
		"shoe_color": look.shoes,
		"shoe_top": HIGH_TOP if look.high_tops else SHOE_TOP,
		"sleeve": LONG_SLEEVE if look.sleeves == "long" else SHORT_SLEEVE,
		"lip_color": look.lips if look.lips is Color else look.skin,
		"lip_amount": 1.0 if look.lips is Color else 0.0,
	}
	var jacket = look.jacket
	if jacket is Color:
		var cut := "Jacket_open"
		if look.coat:
			cut = "Jacket_coat"
		elif look.jacket_closed:
			cut = "Jacket_closed"
		elif look.shoulder_pads:
			cut = "Jacket_blazer"
		out[cut] = jacket
		out["Body"].sleeve = UNDER_JACKET  # the shirt's sleeves stay inside the jacket's
		out["Body"].tuck = TUCK
		out["Body"].jacket_hem = JACKET_HEMS[cut]
		if look.jacket_badge is Color:
			out["Jacket_badge"] = look.jacket_badge
	elif look.collar:
		out["Collar"] = look.shirt
	if look.logo is Color:
		out["Logo_jacket" if jacket is Color else "Logo"] = look.logo
	var over := "_jacket" if jacket is Color else ""
	if look.lanyard is Color:
		out["Lanyard" + over] = look.lanyard
		if look.badge:
			out["Lanyard_badge" + over] = Color(0.95, 0.95, 0.92)
	elif look.badge:
		out["Badge" + over] = Color(0.95, 0.95, 0.92)
	if look.belt_radio and not (jacket is Color and look.coat):
		out["Belt_radio"] = ArtPalette.DARK_PLASTIC
	var style: String = look.hair_style
	var hat = look.headwear
	if style == "cap" and not hat is String:
		hat = "cap"  # the crew's cap is part of the hair look
		out["Head_cap"] = look.hair
		style = "short"
	elif hat is String:
		out["Head_" + hat] = look.headwear_color
	if not style in ["short", "long", "bald", "bob"]:
		style = "short"
	if hat is String and style in ["short", "bob"]:
		style = "buzzed"  # cropped under a hat, so the hat fits the head
	out["Hair_" + style] = look.hair
	if look.glasses:
		out["Face_glasses"] = look.glasses if look.glasses is Color else Color(0.12, 0.1, 0.1)
	elif look.readers is Color:
		out["Face_reading_glasses"] = look.readers
	if look.mustache is Color:
		out["Face_mustache"] = look.mustache
	if look.earrings is Color:
		out["Ears_studs"] = look.earrings
	return out


## Only the body casts a shadow: clothes and hair hug it, so their shadows would
## look the same, and every caster is drawn again for each lamp it stands under.
static func _casts_shadow(part: String) -> bool:
	return part == "Body"


static func _material(part: String, tint) -> Material:
	if tint is Dictionary:
		var body_key := str(tint)
		if not _materials.has(body_key):
			var sm := ShaderMaterial.new()
			sm.shader = BODY_SHADER
			for k in tint:
				sm.set_shader_parameter(k, tint[k])
			_materials[body_key] = sm
		return _materials[body_key]
	var c: Color = tint
	var metal := 0.8 if part in ["Jacket_badge", "Ears_studs"] else 0.0
	var rough := 0.35 if part in ["Face_glasses", "Face_reading_glasses", "Belt_radio"] else 0.85
	var key := "%s|%.3f|%.3f" % [c.to_html(), metal, rough]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if part.begins_with("Jacket_"):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED  # the lining shows at an open front, and where a sleeve folds
	m.vertex_color_use_as_albedo = true  # the model's shading: hair strands, brims, the zip
	m.metallic = metal
	m.roughness = rough
	_materials[key] = m
	return m


# --- Bones -------------------------------------------------------------------------

func _bind() -> void:
	var n := skeleton.get_bone_count()
	_parent.resize(n)
	_rest_local.resize(n)
	var depth := []
	for i in n:
		_parent[i] = skeleton.get_bone_parent(i)
		var d := 0
		var p := _parent[i]
		while p >= 0:
			d += 1
			p = _parent[p] if p < i else skeleton.get_bone_parent(p)
		depth.append([d, i])
	depth.sort_custom(func(a, b): return a[0] < b[0])
	for d in depth:
		_order.append(d[1])
	_skel = _in_rig(skeleton, {})
	# The rig stands with its arms hanging; the pack rests in a T-pose. Turning
	# the upper arms down makes the pose the rig's joints start from.
	var g: Array[Transform3D] = []
	g.resize(n)
	for i in _order:
		var local := skeleton.get_bone_rest(i)
		var parent_g: Transform3D = g[_parent[i]] if _parent[i] >= 0 else Transform3D.IDENTITY
		var here := parent_g * local
		var bone := skeleton.get_bone_name(i)
		if bone.begins_with("upperarm_"):
			var elbow := skeleton.find_bone("lowerarm_" + bone.right(1))
			var along: Vector3 = (here * skeleton.get_bone_rest(elbow).origin - here.origin).normalized()
			var side := 1.0 if (_skel * here.origin).x > 0.0 else -1.0
			var down := (_skel.basis.inverse() * Vector3(side * sin(ARM_SPREAD), -cos(ARM_SPREAD), 0.0)).normalized()
			here.basis = Basis(Quaternion(along, down)) * here.basis
			local = parent_g.affine_inverse() * here
		_rest_local[i] = local
		g[i] = here
	var cache := {}
	for joint in JOINT_BONES:
		var i := skeleton.find_bone(JOINT_BONES[joint])
		var j: Transform3D = _in_rig(_rig.joints[joint], cache)
		_driven[i] = [joint, j.basis.inverse() * _skel.basis * g[i].basis]
		if joint == "hips":
			_hips_offset = j.affine_inverse() * _skel * g[i]
	_pelvis = skeleton.find_bone("pelvis")
	_head_bone = skeleton.find_bone("Head")
	for i in n:
		var bone := skeleton.get_bone_name(i)
		if bone.get_slice("_", 0) in FINGERS:
			_fingers[i] = "thumb" if bone.begins_with("thumb") else bone.right(1)  # its side, "r" or "l"
	for bone in CHEST:
		_chest[skeleton.find_bone(bone)] = true
	for bone in FEET:
		_foot_bones[skeleton.find_bone(bone)] = true
	for side in ["r", "l"]:
		_feet.append(skeleton.find_bone("foot_" + side))
	_foot_height = (_skel * g[_feet[0]]).origin.y


## Lifts or lowers the body so its feet land where the rig's do: the pack's legs
## are longer than the rig's, so a crouch or a chair would sink them otherwise.
func _plant_feet(g: Array[Transform3D], cache: Dictionary) -> Vector3:
	var to_parent: Transform3D = _rig.transform * _skel
	var low := INF
	for f in _feet:
		low = minf(low, (to_parent * g[f]).origin.y)
	var rig_low := INF
	for side in ["r", "l"]:
		var sole: Vector3 = _rig.transform * (_in_rig(_rig.joints[side + "_knee"], cache) * Vector3(0, -0.44, 0))
		rig_low = minf(rig_low, sole.y)
	var lift := (rig_low - (low - _foot_height * _rig.scale.y)) * _lower
	if absf(lift) < 0.001:
		return Vector3.ZERO
	var up: Vector3 = to_parent.basis.inverse() * Vector3(0, lift, 0)
	var parent_g: Transform3D = g[_parent[_pelvis]] if _parent[_pelvis] >= 0 else Transform3D.IDENTITY
	var pose := skeleton.get_bone_pose(_pelvis)
	pose.origin += parent_g.basis.inverse() * up
	skeleton.set_bone_pose(_pelvis, pose)
	return up  # how far the whole body moved, in the skeleton's space


## Bends one arm (CharacterRig.reach) so its wrist lands on the rig's reach
## point, or onto its own thigh: the upper arm swings to put the elbow down and out
## of the way, then the forearm turns onto the point, and the hand turns the way
## it's asked to (fingers along the reach's y, palm facing its z). `g` is every
## bone in the skeleton's space before `lift` raised the body.
func _reach(side: String, g: Array[Transform3D], lift: Vector3) -> void:
	var u := skeleton.find_bone("upperarm_" + side)
	var l := skeleton.find_bone("lowerarm_" + side)
	var h := skeleton.find_bone("hand_" + side)
	if u < 0 or l < 0 or h < 0:
		return
	var to_skel := _rig.global_transform * _skel if _rig.is_inside_tree() else _skel
	var at = _rig.reach_point(side)
	var target: Vector3
	var fingers := Vector3.ZERO
	var palm := Vector3.ZERO
	var from_world := to_skel.affine_inverse()
	if at is Transform3D:
		var t: Transform3D = at
		target = from_world * t.origin - lift
		fingers = (from_world.basis * t.basis.y).normalized()
		palm = (from_world.basis * t.basis.z).normalized()
	elif at is Vector3:
		target = from_world * (at as Vector3) - lift
	else:
		# Resting on the thigh, palm down and fingers towards the knee.
		var hip: Vector3 = g[skeleton.find_bone("thigh_" + side)].origin
		var knee: Vector3 = g[skeleton.find_bone("calf_" + side)].origin
		var up := (_skel.basis.inverse() * Vector3.UP).normalized()
		target = hip + (knee - hip).normalized() * KNEE_REST.x + up * KNEE_REST.y
		fingers = (knee - hip).normalized()
		palm = -up
	var s := g[u].origin
	var e := g[l].origin
	var hand := g[h].origin
	var l1 := s.distance_to(e)
	var l2 := e.distance_to(hand)
	var to := target - s
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.002)
	var dir := to.normalized()
	var sx := 1.0 if side == "r" else -1.0
	var pole := (_skel.basis.inverse() * ELBOW_POLE * Vector3(sx, 1, 1)).normalized()
	var perp := pole - dir * pole.dot(dir)
	if perp.length() < 0.001:
		perp = (_skel.basis.inverse() * Vector3.DOWN).normalized()
	perp = perp.normalized()
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var elbow := s + (dir * cos(a) + perp * sin(a)) * l1
	var upper := Basis(Quaternion((e - s).normalized(), (elbow - s).normalized())) * g[u].basis
	var lower_g := Transform3D(upper, s) * skeleton.get_bone_pose(l)
	var hand_now := (lower_g * skeleton.get_bone_pose(h)).origin
	var lower := Basis(Quaternion((hand_now - lower_g.origin).normalized(), (s + dir * d - lower_g.origin).normalized())) * lower_g.basis
	var w := _rig.reach_weight(side)
	var parent_g := g[_parent[u]]
	var up_local := (parent_g.basis.inverse() * upper).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(u, skeleton.get_bone_pose_rotation(u).slerp(up_local, w))
	var low_local := (upper.inverse() * lower).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(l, skeleton.get_bone_pose_rotation(l).slerp(low_local, w))
	if fingers != Vector3.ZERO:
		# The pack's hands run their y along the fingers, with x up the back of
		# the right hand and the palm of the left.
		var y := fingers
		var x := (-palm if side == "r" else palm)
		x = (x - y * x.dot(y)).normalized()
		var want := Basis(x, y, x.cross(y))
		var hand_local := (lower.orthonormalized().inverse() * want).get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(h, skeleton.get_bone_pose_rotation(h).slerp(hand_local, w))


func _add_clips() -> void:
	var lib := ArtModels.load_resource("character/locomotion") as AnimationLibrary
	if lib == null:
		return
	player = AnimationPlayer.new()
	player.name = "Clips"
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library("", lib)
	_play_clip(0.0)
	# Bodies standing together shouldn't breathe in step. (Not randf(): levels
	# seed the shared generator, and a body must not change what they roll.)
	var offset := float(hash(model.get_instance_id()) % 1000) / 1000.0
	player.seek(offset * player.current_animation_length, true)


func _play_action(action: String) -> void:
	if action == _action_playing:
		return
	_action_playing = action
	_clip = ACTION_CLIPS[action]
	# A held pose can't cross-fade (the fade runs on clip time, which is stopped):
	# the rig's own upper/lower blend eases into it instead.
	player.play(_clip, 0.0 if action in HELD else 0.08)
	player.seek(0.0, true)
	player.speed_scale = 0.0 if action in HELD else 1.0


func _play_clip(speed: float) -> void:
	_action_playing = ""
	var clip := "Idle_Loop"
	if speed > 5.6:
		clip = "Sprint_Loop"
	elif speed > 2.4:
		clip = "Jog_Fwd_Loop"
	elif speed > 0.15:
		clip = "Walk_Loop"
	if clip != _clip:
		_clip = clip
		player.play(clip, 0.25)
	player.speed_scale = clampf(speed / CLIP_SPEEDS[clip], 0.6, 1.6) if CLIP_SPEEDS.has(clip) else 1.0


## `node`'s transform relative to the rig, from its parents' local transforms
## (so it works before the rig is in the tree). `cache` saves repeat walks.
func _in_rig(node: Node3D, cache: Dictionary) -> Transform3D:
	if node == _rig:
		return Transform3D.IDENTITY
	if cache.has(node):
		return cache[node]
	var t := _in_rig(node.get_parent_node_3d(), cache) * node.transform
	cache[node] = t
	return t


## A copy of a body part `build` times wider, with the skin moved to match, and
## its flesh filled out round each bone by `shape` (REGIONS): every vertex moves
## out from the bones it follows, by how much each one's region asks, so the
## clothes over a region fill out with it.
static func _shaped(body: int, build: float, shape: Dictionary, part: String, mesh: Mesh, skin: Skin) -> Array:
	var key := "%d|%.3f|%s|%s" % [body, build, JSON.stringify(shape, "", true), part]
	if _scaled.has(key):
		return _scaled[key]
	var s := Vector3(build, 1.0, build)
	var sk := skin.duplicate() as Skin
	# Per bind: how much thicker its flesh, and the bone's line.
	var grow := PackedFloat32Array()
	var belly: Array[bool] = []
	var shoe_at := {}  # foot or ball bind -> its side
	var heads := PackedVector3Array()  # where each bone starts
	var ways := PackedVector3Array()  # and the way it runs
	var front := Vector3.FORWARD
	for b in sk.get_bind_count():
		var bone_rest := sk.get_bind_pose(b).affine_inverse()
		bone_rest.origin *= s
		sk.set_bind_pose(b, bone_rest.affine_inverse())
		var region: String = REGIONS.get(_bone_kind(sk.get_bind_name(b)), "")
		grow.append(float(shape.get(region, 1.0)) - 1.0)
		belly.append(region == "belly")
		var bone := sk.get_bind_name(b)
		if part == "Body" and _bone_kind(bone) in SHOE_BONES:
			shoe_at[b] = bone.right(1)
		heads.append(bone_rest.origin)
		ways.append(bone_rest.basis.y.normalized())
	# Each foot's ball (where a shoe widens from), toe tip and middle, by side.
	var balls := {}
	var tips := {}
	var mids := {}
	for b in sk.get_bind_count():
		var bone := String(sk.get_bind_name(b))
		var side := bone.right(1)
		if bone.begins_with("ball_leaf_"):
			tips[side] = heads[b].z
		elif bone.begins_with("ball_"):
			balls[side] = heads[b]
		elif bone.begins_with("foot_"):
			mids[side] = heads[b].z  # the ankle, for now
	for side in balls:
		tips[side] = tips.get(side, balls[side].z - 0.08)
		mids[side] = (mids.get(side, balls[side].z) + tips[side]) / 2.0
	var out := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var per := bones.size() / maxi(verts.size(), 1)
		var toes := {}  # vertex past the ball of a shod foot -> how far towards the tip, times how shod
		for v in verts.size():
			var p := verts[v] * s
			var move := Vector3.ZERO
			for k in per:
				var w := weights[v * per + k]
				var b := bones[v * per + k]
				if w <= 0.0 or grow[b] == 0.0:
					continue
				# Out from the bone's line, square to it.
				var off := p - heads[b]
				off -= ways[b] * off.dot(ways[b])
				var g := grow[b]
				if belly[b] and off.dot(front) > 0.0 and g > 0.0:
					off += front * off.dot(front) * BELLY_FORWARD  # a belly comes forward more than out
				move += off * g * w
			p += move
			var shod := 0.0
			var side := ""
			for k in per:
				var b := bones[v * per + k]
				if shoe_at.has(b):
					shod += weights[v * per + k]
					side = shoe_at[b]
			if shod > 0.0 and balls.has(side):
				var ball: Vector3 = balls[side]
				var toe := clampf((ball.z - p.z) / maxf(ball.z - tips[side], 0.01), 0.0, 1.0)
				p.x = ball.x + (p.x - ball.x) * (1.0 + (SHOE_WIDE + SHOE_TOE * toe) * shod)
				p.z = mids[side] + (p.z - mids[side]) * (1.0 + SHOE_LONG * shod)
				p.y *= 1.0 + SHOE_HIGH * shod * clampf(1.0 - p.y / SHOE_LOW, 0.0, 1.0)
				p.x += tanh((p.x - ball.x) / 0.01) * TOE_ROUND * toe * shod
				if toe > 0.0:
					toes[v] = toe * shod
			verts[v] = p
			normals[v] = (normals[v] / s).normalized()
		if not toes.is_empty():
			_smooth_toes(verts, arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(), toes)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_scaled[key] = [out, sk]
	return _scaled[key]


## Evens out the toes (TOE_SMOOTH passes, each vertex towards its neighbours'
## middle), more towards the tip, so a shoe shows no toes. Vertices that share a
## spot (at a seam) move together; soles stay on the floor.
static func _smooth_toes(verts: PackedVector3Array, index: PackedInt32Array, toes: Dictionary) -> void:
	var spot := {}  # vertex -> the first vertex at its spot
	var at := {}
	for v in toes:
		var key := Vector3i((verts[v] * 10000.0).round())
		if not at.has(key):
			at[key] = v
		spot[v] = at[key]
	var near := {}  # spot -> the spots it shares an edge with
	for i in range(0, index.size(), 3):
		for k in 3:
			var a := index[i + k]
			var b := index[i + (k + 1) % 3]
			if spot.has(a) and spot.has(b) and spot[a] != spot[b]:
				near.get_or_add(spot[a], {})[spot[b]] = true
				near.get_or_add(spot[b], {})[spot[a]] = true
	for _round in TOE_SMOOTH:
		var moved := {}
		for s in near:
			var mid := Vector3.ZERO
			for n in near[s]:
				mid += verts[n]
			mid /= near[s].size()
			var p := verts[s].lerp(mid, 0.5 * smoothstep(0.1, 0.5, toes[s]))
			p.y = maxf(p.y, 0.0) if verts[s].y > 0.002 else verts[s].y
			moved[s] = p
		for s in moved:
			verts[s] = moved[s]
	for v in spot:
		verts[v] = verts[spot[v]]


## "upperarm" for "upperarm_r", "spine_02" for itself: the name REGIONS knows a bone by.
static func _bone_kind(bone: String) -> String:
	return bone if REGIONS.has(bone) else bone.trim_suffix("_r").trim_suffix("_l")
