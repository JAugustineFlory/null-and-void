class_name FirstPersonBody
extends Node3D
## Your own body, seen from your own eyes: the same CharacterRig your teammates
## see, built from your look, with the head hidden so the camera sits where it
## was. Look down and you see your chest, legs and feet; swing, block or get hit
## and your own arms do it in front of you. (Garage playtest item 14, ground
## floor item 7: one set of animations, played when you do something.)
##
##   FirstPersonBody.attach(player)   # Player._ready, for the local player
##
## Typing at a terminal plays "type" like everywhere else; the camera is on the
## screen by then, so the hands stay out of sight. Holding a paper, the notebook
## or something carried, these hands hold it: the held things' own stand-in hands
## (HeldPaper, HeldNotebook) only say where, and aren't drawn.

## The rig stands this far behind the camera, so looking down shows the chest
## and feet in front of you rather than the inside of your collar.
const BACK := 0.08
## Punching or guarding, the body comes this much further forward under the
## camera, as you lean in behind your fists: they come into view. (Not for a
## hit taken: leaning in then shows the top of the neck.)
const FIGHT_LEAN := 0.3
const FIGHTING := ["jab", "cross", "guard"]
## How long one-shot actions hold before the body goes back to what it was doing.
const JAB_TIME := 0.6
const RECOIL_TIME := 0.3
const FLINCH_TIME := 0.35
## The hip joint is this far above the underside of the thigh (as PlayerPuppet).
const SEAT_THIGH := 0.06
## On a chair, the body sits this much further back under the camera, so looking
## down shows your chest and lap rather than the top of your collar.
const SEAT_BACK := 0.14
## Standing or moving, the body slides back under the camera as you look down,
## so that looking straight down your neck is this far behind the camera: you see
## your chest, legs and feet, not down your own collar. Walking and running lean
## the body forward; the slide makes up for that too.
const DOWN_BACK := 0.17
## Whatever the body is doing (a punch leans the neck forward), your neck stays
## this far outside what the camera sees: no stump of neck under your nose.
const NECK_CLEAR := 0.06
## Sitting, the knees come forward to this far over the seat's front edge, so
## the shins hang in front of it rather than through a deep couch.
const KNEE_OVER := 0.04
## Leaning back into the seat as far as this (radians) keeps the neck out of
## view once the hips have come forward; the chest and shoulders are this long.
const LEAN_MAX := 0.7
const TORSO := 0.45
## The wrist sits this far behind and below where a stand-in hand holds a
## paper's edge, so the palm and fingers are behind the page, the thumb on it.
const GRIP_BEHIND := 0.035
const GRIP_BELOW := 0.075

var player: Node3D  # Player
var rig: CharacterRig

## What's playing for a moment, and until when (seconds on _t).
var _moment := ""
var _until := 0.0
var _t := 0.0
var _notebook := false
var _prop := false
var _sit_hip := 0.42
var _lean := 0.0
var _clear := 0.0  # how far back the neck needs the body to go, standing
var _seat_fwd := 0.0  # how far forward the hips came, seated
var _lean_back := 0.0
var _edges := {}  # seat -> how far ahead its front edge is


static func attach(to: Node3D, look: Dictionary = {}) -> FirstPersonBody:
	var fp := FirstPersonBody.new()
	fp.name = "FirstPersonBody"
	fp.player = to
	if look.is_empty():
		look = NetPlayers.look_for(to, to.multiplayer.get_unique_id() if to.is_inside_tree() else 1)
	fp.position = Vector3(0, 0, BACK)
	fp.process_priority = 10  # after the camera and what it holds have moved
	to.add_child(fp)
	fp.rig = CharacterRig.build(fp, look)
	fp.rig.hide_head = true
	fp.rig.process_priority = 11
	fp._sit_hip = 0.87 * float(look.get("height", 1.0)) - 0.45
	fp._listen()
	return fp


func _listen() -> void:
	var combat = player.get("combat")
	if combat:
		combat.swung.connect(_swing)
		combat.blocked.connect(func(_cause): _hold("recoil", RECOIL_TIME))
		combat.hurt.connect(func(_amount, _cause): _hold("flinch", FLINCH_TIME))
	for pair in [["notebook_raised", func(): _notebook = true], ["notebook_lowered", func(): _notebook = false],
			["prop_raised", func(_p): _prop = true], ["prop_lowered", func(_p): _prop = false]]:
		if player.has_signal(pair[0]):
			player.connect(pair[0], pair[1])


## Swings alternate: a jab, then a cross.
func _swing() -> void:
	_hold("cross" if _moment == "jab" and _t < _until + 0.4 else "jab", JAB_TIME)


func _hold(action: String, seconds: float) -> void:
	_moment = action
	_until = _t + seconds


func _process(delta: float) -> void:
	_t += delta
	var action := current_action()
	# Lying down, the camera is on the floor inside the body: leave it out.
	visible = action != "down"
	rig.play(action)
	var height = player.get("stance_height")
	rig.stance_height = height if height != null else -1.0
	var head = player.get("head")
	rig.head_pitch = head.rotation.x if head else 0.0
	# Your legs walk when you do, not when you look round or the body slides
	# under the camera: standing still is standing still.
	var v = player.get("velocity")
	rig.speed_override = Vector2(v.x, v.z).length() if v is Vector3 else -1.0
	# On a chair the player's origin is the seat top: lower the hips onto it, and
	# keep them and the legs facing the way the seat does; looking round turns
	# only the upper body (the player turns, the chair doesn't).
	var chair: bool = rig.action == "sit"
	_lean = lerpf(_lean, FIGHT_LEAN if action in FIGHTING else 0.0, 1.0 - exp(-12.0 * delta))
	var seat = player.get("seat")
	var turned := 0.0
	if chair and is_instance_valid(seat):
		var fwd: Vector3 = -(seat as Node3D).global_basis.z
		turned = angle_difference(atan2(-fwd.x, -fwd.z), player.global_rotation.y)
	rotation.y = -turned
	rig.twist = turned
	var back := BACK - _lean
	var k := 1.0 - exp(-10.0 * delta)
	if chair:
		# Knees to the seat's front edge, then lean back into it as far as the
		# neck needs to stay out of sight.
		var edge := _seat_edge(seat)
		if edge < INF:
			_seat_fwd = clampf(lerpf(_seat_fwd, _seat_fwd + edge + KNEE_OVER - _knee_ahead(seat), k), 0.0, SEAT_BACK + BACK + 0.25)
		back += SEAT_BACK - _seat_fwd
	else:
		_seat_fwd = 0.0
		var down := clampf(-(head.rotation.x if head else 0.0) / 1.45, 0.0, 1.0)
		back += down * (DOWN_BACK - minf(neck_z(), 0.0))
	# Behind the camera, the way you look (seated, the way the seat faces).
	var at := Vector3(0, -(_sit_hip - SEAT_THIGH) if chair else 0.0, 0) + Basis(Vector3.UP, rotation.y) * Vector3(0, 0, back)
	var need := _neck_needs(at)
	if chair:
		_clear = 0.0
		_lean_back = clampf(_lean_back + need / TORSO * k, 0.0, LEAN_MAX)
	else:
		_lean_back = move_toward(_lean_back, 0.0, delta * 2.0)
		_clear = maxf(need, lerpf(_clear, maxf(need, 0.0), k))
		at.z += maxf(_clear, 0.0)
	rig.lean_back = _lean_back
	position = at
	_hold_with_hands()


## How much further back the body at `at` must go for the neck to be out of the
## camera's view, NECK_CLEAR clear of its edges (negative: room to spare).
func _neck_needs(at: Vector3) -> float:
	var cam = player.get("camera")
	var skin: SkinnedBody = rig._skin
	if not (cam is Camera3D) or not cam.is_inside_tree() or skin == null or skin._head_bone < 0:
		return 0.0
	var neck: Vector3 = skin.skeleton.global_transform * skin.skeleton.get_bone_global_pose(skin._head_bone).origin
	var parent := get_parent_node_3d().global_basis
	neck += parent * (at - position)  # where it will be once the body is at `at`
	var back := (parent * Vector3.BACK).normalized()
	var need := INF
	for plane: Plane in (cam as Camera3D).get_frustum():
		var dist := plane.distance_to(neck)
		var rate := plane.normal.dot(back)
		if rate > 0.05:
			need = minf(need, (NECK_CLEAR - dist) / rate)
		elif dist >= NECK_CLEAR:
			need = minf(need, -0.5)
	return clampf(need, -0.5, 0.5)


## How far ahead of the seat its front edge is: where what's under you stops.
## INF if it can't tell (no physics, or nothing there).
func _seat_edge(seat: Node3D) -> float:
	if _edges.has(seat):
		return _edges[seat]
	if not seat.is_inside_tree():
		return INF
	var space := seat.get_world_3d().direct_space_state
	var fwd := -seat.global_basis.z
	fwd = Vector3(fwd.x, 0, fwd.z).normalized()
	var top := seat.global_position.y
	var skip: Array[RID] = []
	for n in [seat, player]:
		if n is CollisionObject3D:
			skip.append((n as CollisionObject3D).get_rid())
	var edge := INF
	var d := 0.1
	while d <= 0.9:
		var from := seat.global_position + fwd * d + Vector3.UP * 0.15
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.3)
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.position.y < top - 0.08:
			edge = d
			break
		d += 0.025
	_edges[seat] = edge
	return edge


## How far ahead of the seat your knees are, along the way it faces.
func _knee_ahead(seat: Node3D) -> float:
	var skin: SkinnedBody = rig._skin
	if skin == null or not seat.is_inside_tree():
		return 0.0
	var fwd := -seat.global_basis.z
	fwd = Vector3(fwd.x, 0, fwd.z).normalized()
	var ahead := -INF
	for side in ["r", "l"]:
		var knee := skin.skeleton.global_transform * skin.skeleton.get_bone_global_pose(skin.skeleton.find_bone("calf_" + side)).origin
		ahead = maxf(ahead, (knee - seat.global_position).dot(fwd))
	return ahead


## Holding a paper, the notebook or something carried (a camera child in the
## "carried" group), these arms reach for it, where the stand-in hands would hold it.
func _hold_with_hands() -> void:
	var cam = player.get("camera")
	var grips := {}
	if cam is Camera3D:
		for hand: Node3D in (cam as Node).find_children("*Hand", "Node3D", true, false):
			if not hand.has_meta("body_hand"):
				hand.set_meta("body_hand", true)
				for part in hand.get_children():
					if part is GeometryInstance3D:
						part.visible = false
			if not hand.is_visible_in_tree():
				continue
			var left := String(hand.name).begins_with("Left")
			grips["l" if left else "r"] = _edge_grip(hand.global_transform.orthonormalized(), left)
		for held in (cam as Node).get_children():
			if held is Node3D and held.is_in_group("carried") and held.is_visible_in_tree():
				# By its two bottom corners, as a paper is held up to read.
				var face := _face_of(held, cam)
				for left in [false, true]:
					var side := "l" if left else "r"
					if not grips.has(side):
						var corner := face.origin + face.basis.x * (-1.0 if left else 1.0) - face.basis.y + face.basis.y.normalized() * 0.03
						grips[side] = _edge_grip(Transform3D(face.basis.orthonormalized(), corner), left)
	rig.reach = grips


## Where a hand holds something by its edge, its frame `t` on the held thing's
## face at the edge (x across the face, outwards for the right hand, y up it, z
## out of it towards you): round the edge, fingers up behind it, the palm facing
## in and the thumb on the front.
static func _edge_grip(t: Transform3D, left: bool) -> Transform3D:
	var out := t.basis.x * (-1.0 if left else 1.0)
	var at := t.origin + out * 0.02 - t.basis.y * GRIP_BELOW - t.basis.z * GRIP_BEHIND
	return _grip(at, t.basis.y * 0.9 - t.basis.z * 0.3, -out * 0.75 + t.basis.z * 0.65)


## The face of something carried that's turned towards `cam`, as a transform at
## its middle whose x and y reach its side and top edges (half sizes) and whose z
## points out of it: its thinnest side is the face, its most upright side "up".
static func _face_of(held: Node3D, cam: Node3D) -> Transform3D:
	var box := AABB()
	var first := true
	for mi in held.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = held.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var size := box.size if not first else Vector3(0.2, 0.25, 0.02)
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var thin := 0
	for i in 3:
		if size[i] < size[thin]:
			thin = i
	var g := held.global_transform
	var normal := (g.basis * axes[thin]).normalized()
	var mid := g * box.get_center() if not first else g.origin
	if normal.dot(cam.global_position - mid) < 0.0:
		normal = -normal
	var up_i := (thin + 1) % 3
	var other := (thin + 2) % 3
	var cam_up := cam.global_basis.y
	if absf((g.basis * axes[other]).normalized().dot(cam_up)) > absf((g.basis * axes[up_i]).normalized().dot(cam_up)):
		up_i = other
	var up := (g.basis * axes[up_i]).normalized()
	if up.dot(cam_up) < 0.0:
		up = -up
	var across := up.cross(normal).normalized()
	var half_across: float = size[3 - thin - up_i] / 2.0
	var half_up: float = size[up_i] / 2.0
	return Transform3D(Basis(across * half_across, up * half_up, normal), mid + normal * size[thin] / 2.0)


## A wrist at `at`, fingers pointing along `fingers`, the palm facing `palm`.
static func _grip(at: Vector3, fingers: Vector3, palm: Vector3) -> Transform3D:
	var y := fingers.normalized()
	var z := palm.normalized()
	return Transform3D(Basis(y.cross(z), y, z), at)


## Where the neck is (the head's root), front to back in this node's space:
## negative when the pose leans it forward of the hips.
func neck_z() -> float:
	var skin: SkinnedBody = rig._skin
	if skin and skin._head_bone >= 0:
		return to_local(skin.skeleton.global_transform * skin.skeleton.get_bone_global_pose(skin._head_bone).origin).z
	return to_local((rig.joints["head"] as Node3D).global_position).z


## The action the body should be playing now.
func current_action() -> String:
	if _is("is_down") or player.get("downed") == true:
		return "down"
	if _is("is_sitting"):
		return "sit" if player.get("seat") != null else "sit_floor"
	if _is("is_using_terminal"):
		return "type"
	if _notebook or _prop:
		return "idle"  # the notebook or the paper is up in front of you
	if _t < _until:
		return _moment
	var combat = player.get("combat")
	if combat and combat.has_method("guard_up") and combat.guard_up():
		return "guard"
	return "idle"


func _is(method: String) -> bool:
	return player.has_method(method) and player.call(method)
