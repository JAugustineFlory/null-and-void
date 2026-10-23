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
## (HeldPaper, HeldNotebook) only say where, and aren't drawn. Vaulting,
## mantling, hanging, climbing or edging along a ledge, they grab the edge,
## pipe or wall the move holds on to (Player.parkour_grip); sliding, the legs go
## out in front; rolling, the body tucks and turns over with the view.

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
## The parkour moves the body plays (Player.move_name), and how quickly the
## hands get to a grip in one: a grab is quick.
const PARKOUR := ["slide", "roll", "mantle", "vault", "hang", "climb", "ledge"]
const GRAB_RATE := 14.0
## About where the shoulders are above the feet, standing: an edge above this
## is grabbed from below, one under it pushed down on.
const SHOULDER := 1.45
## Hands on an edge are this far apart; on a wall, this far.
const EDGE_SPREAD := 0.2
const WALL_SPREAD := 0.26
## Climbing, each hand takes the next hold this far above the other's, and one
## pull is twice it: the body's hand-over-hand cycle.
const RUNG := 0.35
## How far above where Player reaches on a pipe the hands may go, overhead.
const CLIMB_REACH := 0.45
## Where the wrists are, out from the wall a pipe runs up (Traversal.climbable).
const PIPE_OUT := 0.15
## Mantling, the hands let go of the edge this far through (you're up on it);
## vaulting, the planted hand lets go this far through (you're over).
const MANTLE_LET_GO := 0.8
const VAULT_LET_GO := 0.7
## Hanging from an edge, climbing a pipe or edging along a wall further than
## arm's length away, the body moves up to this far towards it, so the hands get
## there: you're pulling yourself in to it, or (vaulting) pushing down on it.
## Otherwise, or further than that, a hand that can't reach lets go.
const PULL_MAX := 0.45
const PULLED_IN := ["hang", "climb", "vault", "ledge"]
const PUSHED_OFF := ["vault"]
## Pulled towards a grip, the body near your eyes (the collar, the backs of the
## shoulders) isn't drawn this close, so your arms show reaching past your face.
const NEAR_CUT := 0.4

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
var _holds := {}  # climbing, side -> where that hand is on the pipe now
var _pull := Vector3.ZERO  # how far the body has moved towards what the hands hold
var _grips := {}  # this frame's parkour grips, side -> wrist transform
var _arm := 0.0  # shoulder to wrist, arm straight
var _own: Array[Material] = []  # this body's own copies of its materials (near cut)
var _cut := -1.0


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
	fp._own_materials()
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
	_grips = _parkour_grips(delta)
	rig.reach_rate = GRAB_RATE if action in PARKOUR else CharacterRig.REACH_RATE
	if action == "climb":
		rig.move_progress = fposmod(player.global_position.y / (2.0 * RUNG), 1.0)
	elif player.has_method("parkour_progress"):
		rig.move_progress = player.parkour_progress()
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
	basis = Basis(Vector3.UP, -turned)
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
	_pull = _pull.lerp(_pull_needed(), 1.0 - exp(-12.0 * delta))
	if _grips.is_empty() and _pull.length() < 0.005:
		_pull = Vector3.ZERO
	at += _pull
	_near_cut(NEAR_CUT if action == "roll" else NEAR_CUT * clampf(_pull.length() / 0.1, 0.0, 1.0))
	var need := _neck_needs(at) if _pull.length() < 0.05 else 0.0
	if chair:
		_clear = 0.0
		_lean_back = clampf(_lean_back + need / TORSO * k, 0.0, LEAN_MAX)
	else:
		_lean_back = move_toward(_lean_back, 0.0, delta * 2.0)
		if action != "roll":  # (turning over with the view: see below)
			_clear = maxf(need, lerpf(_clear, maxf(need, 0.0), k))
		at.z += maxf(_clear, 0.0)
	rig.lean_back = _lean_back
	position = at
	if action == "roll" and head and player.get("camera") is Camera3D:
		# Tucked, you turn over with your view: the world goes round, not you.
		var eye: Vector3 = head.position
		transform = Transform3D((player.camera as Camera3D).transform.basis, eye) * Transform3D(Basis.IDENTITY, -eye) * transform
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
	var grips := _grips.duplicate()
	if grips.is_empty() and cam is Camera3D:
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


## Your body's materials are shared with everyone dressed the same: this one
## gets its own, so leaving the near parts out (_near_cut) leaves out only yours.
func _own_materials() -> void:
	for mi: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi.material_override
		if m is ShaderMaterial or m is StandardMaterial3D:
			m = m.duplicate()
			if m is StandardMaterial3D:
				# Always on, so changing how near costs no new shader mid-climb.
				(m as StandardMaterial3D).distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			mi.material_override = m
			_own.append(m)
	_near_cut(0.0)


func _near_cut(near: float) -> void:
	if is_equal_approx(near, _cut):
		return
	_cut = near
	for m in _own:
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("near_cut", near)
		else:
			(m as StandardMaterial3D).distance_fade_min_distance = near * 0.8
			(m as StandardMaterial3D).distance_fade_max_distance = maxf(near, 0.001)


## How far (in the player's space) the body needs to move for the hands to
## reach their grips, at most PULL_MAX: zero when they reach already. A grip
## still out of reach after that is dropped from _grips: that hand lets go.
func _pull_needed() -> Vector3:
	var skin: SkinnedBody = rig._skin
	if _grips.is_empty() or skin == null:
		return Vector3.ZERO
	var sk := skin.skeleton
	if _arm == 0.0:
		var u := sk.get_bone_global_rest(sk.find_bone("upperarm_r")).origin
		var l := sk.get_bone_global_rest(sk.find_bone("lowerarm_r")).origin
		var h := sk.get_bone_global_rest(sk.find_bone("hand_r")).origin
		_arm = (u.distance_to(l) + l.distance_to(h)) * sk.global_basis.get_scale().x * 0.95
	var to_player := (player as Node3D).global_transform.affine_inverse()
	var most := Vector3.ZERO
	for side in _grips.keys():
		var shoulder := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("upperarm_" + side)).origin
		var gap: Vector3 = to_player.basis * ((_grips[side] as Transform3D).origin - shoulder)
		# Up to it if it's out of reach above (down, too, pushing off it as you
		# go over), then in towards it.
		var lift := maxf(gap.y - _arm * 0.9, 0.0)
		if rig.action in PUSHED_OFF:
			lift += minf(gap.y + _arm * 0.9, 0.0)
		var flat := Vector3(gap.x, 0, gap.z)
		var dy := gap.y - lift
		var fwd := maxf(flat.length() - sqrt(maxf(_arm * _arm - dy * dy, 0.0)), 0.0)
		var move := flat.normalized() * fwd + Vector3.UP * lift
		if not rig.action in PULLED_IN:
			move = Vector3.ZERO
		var pulled := (_pull + move).limit_length(PULL_MAX)
		if (gap - (pulled - _pull)).length() > _arm * 1.2:
			_grips.erase(side)  # out of reach: let go
		elif move.length() > most.length():
			most = move
	return (_pull + most).limit_length(PULL_MAX)


## Where the hands hold on in a parkour move ({} in any other): on an edge,
## palms down and fingers over it; on a pipe, hand over hand; on a wall, flat
## against it, at the shoulders facing it or the hips with your back to it.
func _parkour_grips(delta: float) -> Dictionary:
	var move: String = rig.action
	if not (move in PARKOUR and player.has_method("parkour_grip")):
		_holds.clear()
		return {}
	var grip: Dictionary = player.parkour_grip()
	if grip.is_empty():
		return {}
	var at: Vector3 = grip.point
	var n: Vector3 = grip.normal
	n = Vector3(n.x, 0, n.z).normalized()
	var you_right := (player as Node3D).global_basis.x
	var along := (-n).cross(Vector3.UP)  # along the edge or wall, to your right
	if along.dot(you_right) < 0.0:
		along = -along
	var grips := {}
	for side in ["r", "l"]:
		var s := 1.0 if side == "r" else -1.0
		match move:
			"mantle", "hang", "vault":
				if move == "mantle" and rig.move_progress > MANTLE_LET_GO:
					continue
				if move == "vault" and (side == "r" or rig.move_progress > VAULT_LET_GO):
					continue  # the left hand is planted, the right swings free
				var spread := EDGE_SPREAD if move != "vault" else 0.08
				var edge := at + along * s * spread
				if edge.y > (player as Node3D).global_position.y + SHOULDER:
					# Above you: fingers curled over it, the wrist below the lip.
					grips[side] = _grip(edge + n * 0.03 - Vector3.UP * 0.05, Vector3.UP - n, -n - Vector3.UP)
				else:
					# Below you: the palm flat on top, fingers pointing on over it.
					grips[side] = _grip(edge - n * 0.03 + Vector3.UP * 0.035, -n - Vector3.UP * 0.2, Vector3.DOWN)
			"climb":
				# Each hand holds on up by your head until the other has gone
				# past it, then reaches over it.
				var off := 0.0 if side == "r" else RUNG
				var top := minf(at.y + CLIMB_REACH, (player as Node3D).global_position.y + 2.1)
				var y := floorf((top - off) / (2.0 * RUNG)) * 2.0 * RUNG + off
				var hold := Vector3(at.x, y, at.z) + along * s * 0.06 + n * PIPE_OUT
				var now: Vector3 = _holds.get(side, hold)
				_holds[side] = now.move_toward(hold, delta * 3.0)
				grips[side] = _grip(_holds[side], Vector3.UP, -n)
			"ledge":
				var facing := ((player as Node3D).global_basis.z * -1.0).dot(-n) > 0.0
				var high := 0.15 if facing else -0.3
				var wrist := at + Vector3.UP * high + along * s * WALL_SPREAD + n * 0.02
				grips[side] = _grip(wrist, Vector3.UP if facing else Vector3.DOWN, -n)
	return grips


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
	var move: String = player.move_name() if player.has_method("move_name") else ""
	if move in PARKOUR:
		return move
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
