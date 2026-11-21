extends RefCounted
## Nothing on any floor faces a wall by mistake (Augustine, 2026-11-18: floors
## need real workplaces, and the front desk's screen should face whoever works
## there). Screens face their users, chairs face their desks:
##   - a terminal has somewhere to stand or sit in front of its screen, with a
##     clear view of it;
##   - a monitor on a desk doesn't have its glass against a wall;
##   - nobody sits with their nose to a wall, and a chair at a desk, table or
##     counter faces it;
##   - a toilet faces out of its stall.
## Papers and signs have sweeps of their own (paper_facing_tests, sign_tests).

## Each floor's scene.
const FLOORS := ["home_base", "level_0", "level_1", "level_2", "level_3", "level_4", "level_5", "level_6", "level_7"]
const SEED := 3
## How high a seated pair of eyes is above the seat, and how high a wall is
## looked for (above any furniture).
const SEATED_EYE := 0.45
const WALL_Y := 1.9
## A sitter needs this much clear in front of their face.
const NOSE_ROOM := 0.8
## A chair pulled up this close to a work surface (from the middle of its seat)
## faces it to within this angle. A swivel chair left a little askew is fine,
## and so is one pushed back from the table and turned, as if someone just left.
const DESK_REACH := 0.62
const DESK_TURN := 60.0
## Work surfaces: tops this far above the floor, and at least this long.
const SURFACE_TOP := Vector2(0.6, 1.15)
const SURFACE_LONG := 0.9
## The room a body needs to stand in front of a screen.
const BODY := Vector2(0.25, 1.6)
## Found facing the wrong way on floors that are waiting for their own rebuild:
## "<floor>: <what>" exactly as the sweep words it. Each floor's builder clears
## its lines; a line here that no longer offends is reported, so it gets removed.
const WAITING: Array[String] = [
	# Floor 14's network operations room: the chairs' turn was meant as a few
	# degrees of disorder (dress_level_1.gd, `(x + row) * 7.0`).
	"level_1: the chair at (-18.0, 0.5, 1.8) is turned 119° away from the NocDesk it's at",
	"level_1: the chair at (-15.0, 0.5, 1.8) is turned 98° away from the NocDesk it's at",
	"level_1: the chair at (-12.0, 0.5, 1.8) is turned 77° away from the NocDesk it's at",
	"level_1: the chair at (-18.0, 0.5, 5.3) is turned 94° away from the NocDesk2 it's at",
	# Floor 10's control room: the chair has its back to the controller's desk
	# (dress_level_4.gd, office_chair at 180).
	"level_4: the chair at (6.2, 0.0, -15.6) is turned 180° away from the ControlDesk it's at",
]

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	await test_sweep_catches_mistakes()
	await test_nothing_faces_a_wall()


func _game() -> Node:
	return _tree.root.get_node("/root/Game")


## The sweep itself: a room furnished the right way round passes, and each
## kind of mistake in it is caught.
func test_sweep_catches_mistakes() -> void:
	print("The facing sweep catches a screen, a chair or a toilet turned the wrong way")
	var cases := [
		["right", "", "a room furnished the right way round has nothing to report"],
		["terminal", "nowhere to stand or sit", "a terminal with its screen to the wall"],
		["monitor", "has its screen", "a desk monitor with its glass against the wall"],
		["nose", "faces a wall", "a chair with nothing but wall in front of it"],
		["back", "away from the Desk", "a chair with its back to the desk it's pulled up to"],
		["toilet", "the toilet", "a toilet facing the wall behind it"],
	]
	for c in cases:
		var room := _room(c[0])
		for f in 4:
			await _tree.physics_frame
		var found := sweep(room, {"terminals": 0, "monitors": 0, "seats": 0, "chairs": 0, "toilets": 0})
		if c[1] == "":
			_check.call(found.is_empty(), "%s%s" % [c[2], "" if found.is_empty() else " (found: %s)" % "; ".join(found)])
		else:
			_check.call(found.size() == 1 and found[0].contains(c[1]), "%s is caught%s" % [c[2], "" if found.size() == 1 else " (found: %s)" % "; ".join(found)])
		room.queue_free()
		await _tree.process_frame


## A 6 x 6 m office, far from everything: a terminal on a desk with a chair at
## it, a second desk with a monitor and chair, a waiting chair against the wall
## and a toilet in the corner. `mistake` turns one of them the wrong way.
func _room(mistake: String) -> Node3D:
	var room := Node3D.new()
	room.position = Vector3(500, 0, 500)  # before add_child: nothing of it at the origin
	_tree.root.add_child(room)
	Greybox.room(room, Vector3.ZERO, Vector3(6, 3, 6), {})
	# A terminal on a desk against the north wall, facing the room, its chair in front.
	Greybox.box(room, Vector3(-1.5, 0.38, -2.5), Vector3(1.6, 0.76, 0.8), Color.GRAY, "Desk")
	Terminal.spawn(room, Vector3(-1.5, 0.76, -2.5), 180.0 if mistake == "terminal" else 0.0, "TEST", null, null)
	# A second desk against the east wall, a monitor on it, the chair pulled up.
	Greybox.box(room, Vector3(2.5, 0.38, 0), Vector3(0.8, 0.76, 1.6), Color.GRAY, "Desk")
	ArtProps.crt_monitor(room, Vector3(2.6, 0.76, 0), 90.0 if mistake != "monitor" else -90.0, "off")
	ArtProps.office_chair(room, Vector3(1.6, 0, 0), -90.0 if mistake != "back" else 90.0)
	# A waiting chair with its back to the south wall, looking into the room.
	ArtProps.sittable(ArtProps.cafe_chair(room, Vector3(0, 0, 2.5), 0.0 if mistake != "nose" else 180.0), ArtProps.CAFE_SEAT)
	# A toilet against the west wall.
	ArtProps.toilet(room, Vector3(-2.6, 0, 1.5), -90.0 if mistake != "toilet" else 90.0)
	return room


func test_nothing_faces_a_wall() -> void:
	print("Screens face their users, chairs face their desks")
	var wrong: Array[String] = []
	var counts := {"terminals": 0, "monitors": 0, "seats": 0, "chairs": 0, "toilets": 0}
	for floor_name in FLOORS:
		if not ResourceLoader.exists("res://scenes/%s.tscn" % floor_name):
			continue
		_game().new_run(SEED)
		var level: Node3D = load("res://scenes/%s.tscn" % floor_name).instantiate()
		_tree.root.add_child(level)
		for f in 12:
			await _tree.physics_frame
		for line in sweep(level, counts):
			wrong.append("%s: %s" % [floor_name, line])
		# Floor G's front desk screen starts turned to the staff side and ends
		# turned to the crew: both ways round it has a user.
		if level.has_method("reading_layout"):
			level.reading_layout()
			for f in 2:
				await _tree.physics_frame
			for line in _terminals(level, {"terminals": 0}):
				var turned := "%s: %s" % [floor_name, line]
				if turned not in wrong:
					wrong.append(turned)
		level.queue_free()
		for f in 3:
			await _tree.process_frame
	var fresh := wrong.filter(func(w): return w not in WAITING)
	var stale := WAITING.filter(func(w): return w not in wrong)
	for w in stale:
		print("  note: no longer facing the wrong way, take it off WAITING in tests/facing_tests.gd: %s" % w)
	_check.call(counts.terminals >= 20 and counts.seats + counts.chairs >= 60, "found the screens and seats on every floor (%d terminals, %d monitors, %d seats, %d other chairs, %d toilets)" % [counts.terminals, counts.monitors, counts.seats, counts.chairs, counts.toilets])
	_check.call(fresh.is_empty(), "every screen faces its user and every chair its desk, none into a wall%s" % ("" if fresh.is_empty() else " (not:\n  %s)" % "\n  ".join(fresh)))


## Everything on `level` that faces the wrong way, one line each. `counts` tallies
## what was looked at.
static func sweep(level: Node3D, counts: Dictionary) -> Array[String]:
	var wrong: Array[String] = []
	wrong.append_array(_terminals(level, counts))
	wrong.append_array(_monitors(level, counts))
	wrong.append_array(_seats(level, counts))
	wrong.append_array(_toilets(level, counts))
	return wrong


static func _at(n: Node3D, level: Node3D) -> String:
	return str((level.global_transform.affine_inverse() * n.global_position).snapped(Vector3.ONE * 0.1))


## What's between `from` and `to`, ignoring `skip` and anybody standing there.
static func _ray(level: Node3D, from: Vector3, to: Vector3, skip: Array = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = skip.duplicate()
	for i in 4:
		var hit := level.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or not hit.collider is CharacterBody3D:
			return hit
		q.exclude = q.exclude + [hit.rid]
	return {}


## The floor under `at` (within 1.5 m below it) if a body has room to stand
## there, or null.
static func _standing_room(level: Node3D, at: Vector3, skip: Array) -> Variant:
	var down := _ray(level, at + Vector3.UP * 0.9, at + Vector3.DOWN * 1.5, skip)
	if down.is_empty():
		return null
	var body := CylinderShape3D.new()
	body.radius = BODY.x
	body.height = BODY.y
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = body
	q.transform = Transform3D(Basis(), down.position + Vector3.UP * (BODY.y / 2.0 + 0.1))
	q.exclude = skip
	for hit in level.get_world_3d().direct_space_state.intersect_shape(q, 8):
		if hit.collider is StaticBody3D or hit.collider is AnimatableBody3D:
			return null
	return down.position


## Every collider under `n` (its own body and any child bodies).
static func _rids(n: Node) -> Array:
	var out: Array = []
	if n is CollisionObject3D:
		out.append(n.get_rid())
	for c in n.find_children("*", "CollisionObject3D", true, false):
		out.append(c.get_rid())
	return out


## A terminal that stands somewhere (not one carried about): room to stand in
## front of its screen, or a seat there, and a clear view of the screen from it.
static func _terminals(level: Node3D, counts: Dictionary) -> Array[String]:
	var wrong: Array[String] = []
	for t in level.find_children("*", "Terminal", true, false):
		if not t.is_visible_in_tree() or t.stand_point == null or not t.get_parent() is Node3D or t.get_parent() is CharacterBody3D:
			continue
		counts.terminals += 1
		var stand: Vector3 = t.stand_point.global_position
		var screen: Vector3 = t.focus_point.global_position
		# Anywhere from just clear of its desk to an arm's length back will do.
		var out: Vector3 = (stand - t.global_position).slide(Vector3.UP).normalized()
		var floor_at = null
		for back in [0.0, -0.15, 0.15, 0.3, 0.45]:
			floor_at = _standing_room(level, Vector3(stand.x, screen.y - 0.9, stand.z) + out * back, _rids(t))
			if floor_at != null:
				break
		var on_floor: bool = floor_at != null
		var floor_p: Vector3 = floor_at if on_floor else stand
		var seat: Seat = null
		for s in level.find_children("*", "Seat", true, false):
			if Vector2(s.global_position.x - stand.x, s.global_position.z - stand.z).length() < 0.9 and absf(s.global_position.y - screen.y) < 1.2:
				seat = s
		var name := "the %s terminal at %s" % [t.terminal_name, _at(t, level)]
		if not on_floor and seat == null:
			wrong.append("%s has nowhere to stand or sit in front of its screen" % name)
			continue
		var eye := seat.global_position + Vector3.UP * SEATED_EYE if seat and not on_floor else floor_p + Vector3.UP * 1.5
		var hit := _ray(level, eye, screen, _rids(t))
		if not hit.is_empty() and hit.position.distance_to(screen) > 0.1:
			wrong.append("%s can't be seen from in front of it (%s is in the way)" % [name, hit.collider.name])
	return wrong


## A monitor on a desk (ArtProps.crt_monitor: glass on its -Z side): its glass
## isn't up against a wall or a partition.
static func _monitors(level: Node3D, counts: Dictionary) -> Array[String]:
	var wrong: Array[String] = []
	for m in level.find_children("CRT*", "Node3D", true, false):
		if not m.is_visible_in_tree() or m is CollisionObject3D or _under_terminal(m):
			continue  # a terminal's own tube is checked as a terminal
		counts.monitors += 1
		var front: Vector3 = -m.global_basis.z.normalized()
		var glass: Vector3 = m.global_position + Vector3.UP * 0.23 + front * 0.16
		var hit := _ray(level, glass, glass + front * 0.45)
		if not hit.is_empty():
			wrong.append("the monitor at %s has its screen %.2f m from %s" % [_at(m, level), hit.position.distance_to(glass), hit.collider.name])
	return wrong


## Seats, and chairs nobody can sit on: no nose to a wall, and facing the desk,
## table or counter they're at.
static func _seats(level: Node3D, counts: Dictionary) -> Array[String]:
	var wrong: Array[String] = []
	var surfaces := _work_surfaces(level)
	# [node, top of the seat (world), its own colliders to skip, what it is, has a back]
	var sitters: Array = []
	for s in level.find_children("*", "Seat", true, false):
		if s.is_visible_in_tree():
			counts.seats += 1
			var skip := _rids(s)
			var chair: bool = s.get_parent() is StaticBody3D and _is_chair(s.get_parent())
			if chair:
				skip.append_array(_rids(s.get_parent()))
			sitters.append([s, s.global_position, skip, "chair" if chair else "seat", chair and _has_back(s.get_parent())])
	for c in level.find_children("*", "StaticBody3D", true, false):
		if c.is_visible_in_tree() and _is_chair(c) and c.find_children("*", "Seat", true, false).is_empty() and _has_back(c):
			counts.chairs += 1
			sitters.append([c, c.global_position + Vector3.UP * 0.5, _rids(c), "chair", true])
	for entry in sitters:
		var n: Node3D = entry[0]
		var top: Vector3 = entry[1]
		var skip: Array = entry[2]
		var front: Vector3 = -n.global_basis.z
		front.y = 0
		front = front.normalized()
		var name := "the %s at %s" % [entry[3], _at(n, level)]
		# Something floor-to-ceiling right in front, with no furniture before it.
		var eye := top + Vector3.UP * SEATED_EYE
		var floor_y := top.y - 0.5
		var high := _ray(level, Vector3(top.x, floor_y + WALL_Y, top.z), Vector3(top.x, floor_y + WALL_Y, top.z) + front * NOSE_ROOM, skip)
		var face := _ray(level, eye, eye + front * NOSE_ROOM, skip)
		var low := _ray(level, Vector3(top.x, floor_y + 0.62, top.z), Vector3(top.x, floor_y + 0.62, top.z) + front * NOSE_ROOM, skip)
		if not high.is_empty() and not face.is_empty():
			var wall_at: float = high.position.distance_to(Vector3(top.x, floor_y + WALL_Y, top.z))
			var desk_first: bool = not low.is_empty() and low.position.distance_to(Vector3(top.x, floor_y + 0.62, top.z)) < wall_at - 0.2
			if not desk_first:
				wrong.append("%s faces a wall %.2f m in front of it (%s)" % [name, wall_at, high.collider.name])
				continue
		# A chair with a back, pulled up to a work surface: facing it. A stool or a
		# bench can be sat on any way round.
		if not entry[4]:
			continue
		var best: StaticBody3D = null
		var best_d := DESK_REACH
		var best_p := Vector3.ZERO
		for b in surfaces:
			var up := _top_of(b) - floor_y
			if b == n or b == n.get_parent() or up < SURFACE_TOP.x or up > SURFACE_TOP.y:
				continue
			var p := _closest_on(b, top)
			var d := Vector2(p.x - top.x, p.z - top.z).length()
			if d < best_d:
				best = b
				best_d = d
				best_p = p
		if best and best_d > 0.05:
			var to := Vector3(best_p.x - top.x, 0, best_p.z - top.z).normalized()
			var turn := rad_to_deg(front.angle_to(to))
			if turn > DESK_TURN:
				wrong.append("%s is turned %d° away from the %s it's at" % [name, roundi(turn), best.name])
	return wrong


## A toilet (ArtProps.toilet: its front is -Z, the wall behind it +Z) faces out.
static func _toilets(level: Node3D, counts: Dictionary) -> Array[String]:
	var wrong: Array[String] = []
	for t in level.find_children("Toilet*", "Node3D", true, false):
		if not t.is_visible_in_tree():
			continue
		counts.toilets += 1
		var front: Vector3 = -t.global_basis.z.normalized()
		var seat: Vector3 = t.global_position + Vector3.UP * 0.6
		var hit := _ray(level, seat, seat + front * 0.85)
		if not hit.is_empty():
			wrong.append("the toilet at %s faces %s, %.2f m in front of it" % [_at(t, level), hit.collider.name, hit.position.distance_to(seat)])
	return wrong


static func _under_terminal(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if p is Terminal:
			return true
		p = p.get_parent()
	return false


static func _is_chair(b: Node) -> bool:
	var n := String(b.name)
	return n.begins_with("Chair") or n.begins_with("CafeChair") or n.begins_with("@Chair") or n.begins_with("@CafeChair") or n.contains("Chair@")


## An ArtProps chair has a back rest (a piece standing up at its +Z side); a
## Greybox cube called Chair doesn't, and faces wherever its Seat does.
static func _has_back(b: Node) -> bool:
	for c in b.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).position.z > 0.15 and (c as MeshInstance3D).position.y > 0.55:
			return true
	return false


## Desks, tables, counters and benches: static boxes with a top at working
## height, long enough to work at.
static func _work_surfaces(level: Node3D) -> Array:
	var out: Array = []
	for b in level.find_children("*", "StaticBody3D", true, false):
		if not b.is_visible_in_tree() or _is_chair(b):
			continue
		var box := _box_of(b)
		if box == null:
			continue
		if box.size.y > 1.3 or maxf(box.size.x, box.size.z) < SURFACE_LONG:
			continue
		out.append(b)
	return out


static func _shape_of(b: Node) -> CollisionShape3D:
	for c in b.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			return c
	return null


static func _box_of(b: Node) -> BoxShape3D:
	var s := _shape_of(b)
	return s.shape if s else null


static func _top_of(b: Node3D) -> float:
	var s := _shape_of(b)
	return s.global_position.y + (s.shape as BoxShape3D).size.y / 2.0


## The point of `b`'s box nearest to `p`, in the world.
static func _closest_on(b: Node3D, p: Vector3) -> Vector3:
	var s := _shape_of(b)
	var half := (s.shape as BoxShape3D).size / 2.0
	var local: Vector3 = s.global_transform.affine_inverse() * p
	local = local.clamp(-half, half)
	return s.global_transform * local
