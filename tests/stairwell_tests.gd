extends RefCounted
## Every floor's fire stairs (Augustine, v0.8 playtest): the door swings out of the
## stairwell from either side, nobody arrives behind it or in it, and every floor
## but G has a flight going down beside the flight up.

## Bigger than any of the crew (CrewBody.largest() on release/v0.8 is about 0.35 m
## round and under 2 m tall), so a slot clear for this is clear for everyone.
const BODY_RADIUS := 0.42
const BODY_HEIGHT := 2.1

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	await test_every_stairwell()


func _game() -> Node:
	return _tree.root.get_node("/root/Game")


func test_every_stairwell() -> void:
	print("Every floor's stairs: the door swings out, the landing is clear, the way down is there")
	var stairwells := 0
	var bad_swing := []
	var bad_leaf := []
	var bad_down := []
	var bad_well := []
	var bad_route := []
	var bad_slots := []
	var i := 0
	while ResourceLoader.exists("res://scenes/level_%d.tscn" % i):
		_game().new_run(7 + i)
		var level = load("res://scenes/level_%d.tscn" % i).instantiate()
		_tree.root.add_child(level)
		for f in 10:
			await _tree.physics_frame
		for holder in level.geo.find_children("Stairwell*", "Node3D", true, false):
			stairwells += 1
			var where := "level %d %s" % [i, _floor_of(holder)]
			var door := _door_of(level, holder)
			if door == null:
				bad_swing.append("%s: no door" % where)
				continue
			var out: Vector3 = holder.global_basis.z  # the lobby side
			var doorway: Vector3 = holder.global_position
			var was_open: bool = door.is_open
			# Opened from inside the stairwell and from the lobby, it swings out both times.
			for side in [-1.5, 1.5]:
				door.set_open(false, true)
				var by := Node3D.new()
				level.add_child(by)
				by.global_position = doorway + out * side + Vector3.UP
				door.set_open(true, true, door.away_from(by))
				by.free()
				if (door.global_position - doorway).dot(out) < 0.3:
					bad_swing.append("%s from the %s" % [where, "stairwell" if side < 0 else "lobby"])
			# Nothing in the lobby stands in the leaf's way as it swings.
			for s in [0.25, 0.5, 0.75, 1.0]:
				door.swing = s
				var hits := _leaf_hits(level, door)
				if not hits.is_empty():
					bad_leaf.append("%s at %d%%: %s" % [where, int(s * 100), hits])
					break
			door.set_open(false, true)
			if was_open:
				door.set_open(true, true)
			# The flight down, on every floor but G: steps going down from the landing.
			var steps: Array = holder.find_children("StepDown*", "StaticBody3D", false, false)
			var ground := _floor_of(holder) == "G"
			if ground != steps.is_empty():
				bad_down.append("%s: %d steps down" % [where, steps.size()])
			elif not ground:
				var going_down := true
				var prev := INF
				steps.sort_custom(func(a, b): return a.position.z > b.position.z)
				for st in steps:
					var top: float = st.position.y + _box(st).y / 2.0
					going_down = going_down and top < prev and top < 0.0
					prev = top
				if not going_down:
					bad_down.append("%s: the steps don't go down from the landing" % where)
				# The well only takes what's under the stairwell's own floor.
				var well := _hits(level, holder.global_transform * Transform3D(Basis(), Vector3(-0.9, -0.65, -3.2)), _shape_box(Vector3(1.4, 1.1, 1.6)), holder)
				if not well.is_empty():
					bad_well.append("%s: %s" % [where, well])
				# Someone bigger than any of the crew fits down the flight: on every tread
				# but the last, short one against the far wall, nothing but the step under them.
				for st in steps.slice(0, steps.size() - 1):
					var tread: Vector3 = st.position + Vector3(0, _box(st).y / 2.0, 0)
					var hits := _body_hits(level, holder, tread)
					if not hits.is_empty():
						bad_route.append("%s: down the flight at %.2f: %s" % [where, tread.y, hits])
						break
			# And through the doorway, door open, from the landing out into the lobby.
			door.set_open(true, true)
			await _settle()
			for z in [-0.8, 0.0, 0.7]:
				var hits := _body_hits(level, holder, Vector3(0, 0, z))
				if not hits.is_empty():
					bad_route.append("%s: landing to lobby at %.1f: %s" % [where, z, hits])
					break
			door.set_open(false, true)
			if was_open:
				door.set_open(true, true)
		# Where the crew arrives by the stairs, all six slots stand clear: of the
		# door, shut or open, of both flights and of the walls.
		if level.has_method("arrive_by_stairs"):
			var doors := []
			for holder in level.geo.find_children("Stairwell*", "Node3D", true, false):
				var d := _door_of(level, holder)
				if d:
					doors.append([d, d.is_open])
			for open in [false, true]:
				for d in doors:
					d[0].set_open(open, true)
				await _settle()
				for on_ground in ([false, true] if "on_ground" in level else [false]):
					if on_ground:
						level.on_ground = true
					for n in 6:
						var slot: Vector3 = level.player_spawn(n).origin
						var at := Transform3D(Basis(), slot + Vector3(0, -0.1 + 0.08 + BODY_HEIGHT / 2.0, 0))
						var hits := _hits(level, at, _shape_capsule(), null)
						if not hits.is_empty():
							bad_slots.append("level %d%s slot %d, doors %s: %s" % [i, " (G)" if on_ground else "", n, "open" if open else "shut", hits])
					if on_ground:
						level.on_ground = false
			for d in doors:
				d[0].set_open(d[1], true)
		level.queue_free()
		for f in 3:
			await _tree.process_frame
		i += 1
	_check.call(stairwells >= 10, "found the fire stairs on every floor (%d stairwells)" % stairwells)
	_check.call(bad_swing.is_empty(), "every stair door swings out into the lobby, opened from either side %s" % [bad_swing])
	_check.call(bad_leaf.is_empty(), "nothing in a lobby stands in a stair door's swing %s" % [bad_leaf])
	_check.call(bad_down.is_empty(), "every floor but G has a flight going down beside the flight up, and G has none %s" % [bad_down])
	_check.call(bad_well.is_empty(), "the flight down's well cuts into nothing but its own floor %s" % [bad_well])
	_check.call(bad_route.is_empty(), "someone bigger than any of the crew fits from each landing out through the open door, and down the flight %s" % [bad_route])
	_check.call(bad_slots.is_empty(), "all six arrival spots on each landing stand clear of the door (shut or open), the flights and the walls, for a body bigger than any of the crew %s" % [bad_slots])


## Lets a door's new pose reach the physics world before anything is asked of it.
func _settle() -> void:
	for f in 2:
		await _tree.physics_frame


func _floor_of(holder: Node) -> String:
	for c in holder.get_children():
		if c is Label3D and "FLOOR " in (c as Label3D).text:
			return (c as Label3D).text.get_slice("FLOOR ", 1).strip_edges()
	return "?"


## The stairwell's door: the Door hanging in its doorway.
func _door_of(level: Node, holder: Node3D) -> Door:
	var at: Vector3 = holder.global_transform * Vector3(0, Stairwell.DOOR_H / 2.0, 0)
	for d in level.find_children("*", "Door", true, false):
		var shut: Vector3 = d.get_parent().global_transform * (d._closed_pos if d.is_open else d.position)
		if shut.distance_to(at) < 0.2:
			return d
	return null


func _box(body: Node) -> Vector3:
	for c in body.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			return ((c as CollisionShape3D).shape as BoxShape3D).size
	return Vector3.ZERO


func _shape_box(size: Vector3) -> Shape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


func _shape_capsule() -> Shape3D:
	var c := CapsuleShape3D.new()
	c.radius = BODY_RADIUS
	c.height = BODY_HEIGHT
	return c


## The leaf, less a hand's width at each end and its foot and head, so the
## doorway's own frame and the floor don't count.
func _leaf_hits(level: Node3D, door: Door) -> Array:
	var leaf := _shape_box(Vector3(door.size.x - 0.3, door.size.y - 0.3, 0.04))
	return _hits(level, door.global_transform, leaf, null, door)


## What `shape` at `at` overlaps: bodies, by their path in the level, leaving out
## players and anything under `own` or `skip`.
func _hits(level: Node3D, at: Transform3D, shape: Shape3D, own: Node, skip: Node = null) -> Array:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = at
	var out := []
	for h in level.get_world_3d().direct_space_state.intersect_shape(q, 32):
		var c: Node = h.collider
		if c is CharacterBody3D or c == skip or (own != null and own.is_ancestor_of(c)):
			continue
		out.append(String(level.get_path_to(c)))
	return out


## What a body of the test's size, standing at `feet` (the stairwell's space), runs
## into: as wide as it is, a hand's depth front to back so a step's neighbours
## don't count, lifted just clear of what it stands on.
func _body_hits(level: Node3D, holder: Node3D, feet: Vector3) -> Array:
	var body := _shape_box(Vector3(BODY_RADIUS * 2.0, BODY_HEIGHT, 0.2))
	var at: Transform3D = holder.global_transform * Transform3D(Basis(), feet + Vector3(0, 0.05 + BODY_HEIGHT / 2.0, 0))
	return _hits(level, at, body, null)
