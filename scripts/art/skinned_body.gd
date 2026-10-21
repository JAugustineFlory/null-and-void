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
const FINGERS := ["thumb", "index", "middle", "ring", "pinky"]

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
var _fingers := {}
var _pelvis := -1
var _foot_height := 0.0
var _upper := 1.0
var _lower := 1.0
var _clip := ""

static var _scaled := {}  # "body|build|mesh" -> [Mesh, Skin]
static var _materials := {}


## Builds the model under `rig`, keeps the meshes `look` wears and binds the
## skeleton to the rig's joints. `look.build` thickens the body.
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
	for mi: MeshInstance3D in sb.model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.name)
		if not keep.has(part):
			mi.get_parent().remove_child(mi)
			mi.free()
			continue
		if not is_equal_approx(build, 1.0):
			var m: Array = _widened(body, build, part, mi.mesh, mi.skin)
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
	var upper_target := 1.0 if full or _rig.action != "idle" or player == null else 0.0
	var lower_target := 1.0 if full or player == null or _clip == "Idle_Loop" else 0.0
	var k := clampf(delta * BLEND_RATE, 0.0, 1.0) if delta > 0.0 else 1.0
	_upper = lerpf(_upper, upper_target, k)
	_lower = lerpf(_lower, lower_target, k)
	if player:
		_play_clip(_rig.current_speed())
		player.advance(delta)
	var cache := {}
	var inv := _skel.affine_inverse()
	var g: Array[Transform3D] = []
	g.resize(_parent.size())
	for i in _order:
		var parent := _parent[i]
		var parent_g: Transform3D = g[parent] if parent >= 0 else Transform3D.IDENTITY
		var base: Transform3D = skeleton.get_bone_pose(i) if player else _rest_local[i]
		if player and _fingers.has(i):
			base.basis = Basis(_rest_local[i].basis.get_rotation_quaternion().slerp(base.basis.get_rotation_quaternion(), FINGER_CURL))
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
	if _lower > 0.0:
		_plant_feet(g, cache)


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
	for i in n:
		if skeleton.get_bone_name(i).get_slice("_", 0) in FINGERS:
			_fingers[i] = true
	for side in ["r", "l"]:
		_feet.append(skeleton.find_bone("foot_" + side))
	_foot_height = (_skel * g[_feet[0]]).origin.y


## Lifts or lowers the body so its feet land where the rig's do: the pack's legs
## are longer than the rig's, so a crouch or a chair would sink them otherwise.
func _plant_feet(g: Array[Transform3D], cache: Dictionary) -> void:
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
		return
	var up: Vector3 = to_parent.basis.inverse() * Vector3(0, lift, 0)
	var parent_g: Transform3D = g[_parent[_pelvis]] if _parent[_pelvis] >= 0 else Transform3D.IDENTITY
	var pose := skeleton.get_bone_pose(_pelvis)
	pose.origin += parent_g.basis.inverse() * up
	skeleton.set_bone_pose(_pelvis, pose)


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


func _play_clip(speed: float) -> void:
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


## A copy of a body part `build` times thicker round each bone, with the skin
## moved to match.
static func _widened(body: int, build: float, part: String, mesh: Mesh, skin: Skin) -> Array:
	var key := "%d|%.3f|%s" % [body, build, part]
	if _scaled.has(key):
		return _scaled[key]
	var s := Vector3(build, 1.0, build)
	var out := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for v in verts.size():
			verts[v] *= s
			normals[v] = (normals[v] / s).normalized()
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var sk := skin.duplicate() as Skin
	for b in sk.get_bind_count():
		var bone_rest := sk.get_bind_pose(b).affine_inverse()
		bone_rest.origin *= s
		sk.set_bind_pose(b, bone_rest.affine_inverse())
	_scaled[key] = [out, sk]
	return _scaled[key]
