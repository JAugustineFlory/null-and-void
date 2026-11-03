extends RefCounted
## Every crew member's body against the building. Bodies scale with each
## character's height (CrewBody), so: wherever the standard body can get, the
## largest crew body must get too, and every move must work for the smallest
## and the largest. If a floor fails here, resize the route, never the crew.

var t: SceneTree
var _check: Callable

## Each floor's scene and a run seed to build it with.
const FLOORS := ["home_base", "level_0", "level_1", "level_2", "level_3", "level_4", "level_5", "movement_gym"]
## Spacing (metres) of the floor sweep's grid.
const GRID := 0.35


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("Crew bodies")
	test_crew_sizes()
	await test_eyes_and_size()
	for b in [CrewBody.smallest(), CrewBody.largest()]:
		await test_moves(b)
	await test_squeeze()
	for scene in FLOORS:
		await test_floor_fits(scene)


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func frames(n: int) -> void:
	for i in n:
		await t.physics_frame


func arena() -> Node3D:
	var a := Node3D.new()
	t.root.add_child(a)
	Greybox.box(a, Vector3(0, -0.1, 0), Vector3(40, 0.2, 40), Color.GRAY, "Floor")
	return a


func spawn(parent: Node, pos: Vector3, body: CrewBody) -> Player:
	var p := Player.new()
	p.local_control = false
	p.body = body
	p.position = pos
	parent.add_child(p)
	return p


func done(a: Node) -> void:
	a.queue_free()
	await t.process_frame


func test_crew_sizes() -> void:
	var big := CrewBody.largest()
	var small := CrewBody.smallest()
	check(is_equal_approx(big.size, CrewBody.of_crew("sam").size) and is_equal_approx(small.size, CrewBody.of_crew("priya").size),
		"Sam is the crew's largest body and Priya its smallest")
	check(absf(big.stand - 1.93) < 0.02 and absf(small.stand - 1.55) < 0.02,
		"they stand about 1.93 m and 1.55 m tall (%.2f, %.2f)" % [big.stand, small.stand])
	var dana := CrewBody.of_crew("dana")
	check(dana.size > small.size and dana.size < big.size and CrewBody.new().stand == Player.STAND_HEIGHT,
		"everyone else is in between; a standard body is Player.STAND_HEIGHT tall")
	check(CrewBody.from_look({}).size > 0.99 and CrewBody.from_look({}).size < 1.02, "a look with no height is a standard body")


## Your eyes, your collider and what teammates are told all follow your size.
func test_eyes_and_size() -> void:
	var a := arena()
	var seat := Seat.create_at(a, Vector3(4, 0.45, 0), 0.0)
	var small := spawn(a, Vector3(-2, 0.05, 0), CrewBody.smallest())
	var big := spawn(a, Vector3(2, 0.05, 0), CrewBody.largest())
	await frames(20)
	for p in [small, big]:
		var s: float = p.body.size
		check(absf(p.head.position.y - (Player.STAND_HEIGHT - 0.12) * s) < 0.03,
			"standing, eyes at %.2f m for a %.2f body" % [p.head.position.y, s])
		check(absf(p.stance_height - Player.STAND_HEIGHT) < 0.001, "and teammates are told a standing pose (%.3f)" % p.stance_height)
	check(big.head.position.y - small.head.position.y > 0.3, "the largest crew member sees from over 30 cm higher than the smallest")
	small.controls.crouch = true
	await frames(20)
	check(absf(small.stance_height - Player.CROUCH_HEIGHT) < 0.01 and small.head.position.y < 1.1,
		"crouching shrinks you in proportion: a crouch pose, eyes %.2f m up" % small.head.position.y)
	small.controls.crouch = false
	await frames(20)
	check(big.sit(seat), "the largest crew member sits on a chair")
	await frames(60)
	check(absf(big.camera.global_position.y - (0.45 + (Player.SIT_HEIGHT - 0.12) * big.body.size)) < 0.05,
		"seated, your eyes are at your own sitting height (%.2f m)" % big.camera.global_position.y)
	big.body = CrewBody.smallest()
	await frames(30)
	check(big.camera.global_position.y < 0.45 + (Player.SIT_HEIGHT - 0.12) * big.body.size + 0.05,
		"changing body while seated keeps you seated at the new size")
	await done(a)


## The moves every floor relies on work for this body.
func test_moves(b: CrewBody) -> void:
	var who := "the largest crew body" if b.size > 1.0 else "the smallest crew body"
	# Mantle a waist-high crate.
	var a := arena()
	Greybox.box(a, Vector3(0, 0.6, -3), Vector3(4, 1.2, 2), Color.DIM_GRAY)
	var p := spawn(a, Vector3(0, 0.05, 0), b)
	await frames(5)
	p.controls.move = Vector2(0, -1)
	await frames(30)
	p.controls.jump = true
	await frames(40)
	_stop(p)
	await frames(10)
	check(p.global_position.y > 1.1 and p.global_position.z < -2.0, "%s mantles onto a waist-high crate" % who)
	await done(a)

	# Catch a 2 m edge and pull up.
	a = arena()
	Greybox.box(a, Vector3(0, 1.0, -3), Vector3(6, 2.0, 2), Color.DIM_GRAY)
	p = spawn(a, Vector3(0, 0.05, -1.3), b)
	await frames(5)
	p.controls.move = Vector2(0, -0.5)
	p.controls.jump = true
	await frames(3)
	check(p.state == Player.Move.HANG, "%s catches a 2 m edge" % who)
	p.controls.jump = false
	p.controls.move = Vector2(0, -1)
	await frames(40)
	_stop(p)
	await frames(5)
	check(p.global_position.y > 1.9 and p.state == Player.Move.WALK, "%s pulls up on top" % who)
	await done(a)

	# Climb a 4 m pipe and step off on top.
	a = arena()
	Greybox.box(a, Vector3(0, 2, -4), Vector3(6, 4, 4), Color.DIM_GRAY)
	Traversal.climbable(a, Vector3(0, 0, -2), Vector3(0, 4, -2), Vector3(0, 0, 1))
	p = spawn(a, Vector3(0, 0.05, 0), b)
	await frames(5)
	p.controls.move = Vector2(0, -1)
	var climbed := false
	for i in 300:
		p.controls.jump = not climbed and p.global_position.z < -1.0
		await frames(1)
		climbed = climbed or p.state == Player.Move.CLIMB
		if climbed and p.state == Player.Move.WALK:
			break
	_stop(p)
	await frames(10)
	check(climbed and p.global_position.y > 3.9, "%s climbs a 4 m pipe and steps off on top" % who)
	await done(a)

	# Crawl the length of a vent: the standard duct, and floor 0's narrower one.
	for inner in [Vector2(1.0, 1.0), Vector2(0.9, 1.0)]:
		a = arena()
		Traversal.vent(a, Vector3(0, 0, -2), Vector3(0, 0, -8), inner)
		Greybox.box(a, Vector3(-10.6, 1.5, -2), Vector3(20, 3, 0.2), Color.DIM_GRAY)
		Greybox.box(a, Vector3(10.6, 1.5, -2), Vector3(20, 3, 0.2), Color.DIM_GRAY)
		Greybox.box(a, Vector3(0, 2.0, -2), Vector3(1.2, 2.0, 0.2), Color.DIM_GRAY)
		p = spawn(a, Vector3(0, 0.05, 0), b)
		await frames(5)
		p.controls.move = Vector2(0, -1)
		p.controls.crouch = true
		for i in 600:
			await frames(1)
			if p.global_position.z < -8.6:
				break
		check(p.global_position.z < -8.6, "%s crawls through a %.1f m wide, %.2f m tall vent (z %.1f)" % [who, inner.x, inner.y, p.global_position.z])
		await done(a)

	# Slide under a jammed shutter with a 1 m gap.
	a = arena()
	Greybox.box(a, Vector3(-11, 1.5, -4), Vector3(20, 3, 0.2), Color.DIM_GRAY)
	Greybox.box(a, Vector3(11, 1.5, -4), Vector3(20, 3, 0.2), Color.DIM_GRAY)
	Traversal.gate(a, Vector3(0, 0, -4), 2.0, 1.0, 3.0)
	p = spawn(a, Vector3(0, 0.05, 4), b)
	await frames(5)
	p.controls.move = Vector2(0, -1)
	p.controls.sprint = true
	await frames(40)
	p.controls.crouch = true
	await frames(120)
	check(p.global_position.z < -4.5, "%s gets under a jammed shutter's 1 m gap (z %.1f)" % [who, p.global_position.z])
	await done(a)

	# Shuffle along a ledge.
	a = Node3D.new()
	t.root.add_child(a)
	Greybox.box(a, Vector3(-5, -0.1, 0), Vector3(6, 0.2, 6), Color.GRAY)
	Greybox.box(a, Vector3(11, -0.1, 0), Vector3(6, 0.2, 6), Color.GRAY)
	Greybox.box(a, Vector3(3, -20, 0), Vector3(40, 0.2, 40), Color.GRAY)
	Greybox.box(a, Vector3(3, 1.5, -3.1), Vector3(22, 3, 0.2), Color.DIM_GRAY)
	Traversal.ledge(a, Vector3(-2, 0, -3), Vector3(8, 0, -3), Vector3(0, 0, 1))
	p = spawn(a, Vector3(-4, 0.05, -2.66), b)
	await frames(5)
	p.controls.move = Vector2(1, 0)
	var lowest := 10.0
	for i in 900:
		await frames(1)
		lowest = minf(lowest, p.global_position.y)
		if p.global_position.x > 9.0:
			break
	check(lowest > -0.5 and p.global_position.x > 9.0, "%s shuffles the length of a ledge without falling" % who)
	await done(a)


## Where you barely fit you go slower: the largest crew member crawls a vent
## slower than a standard body, nobody is stopped, and roomy crouching isn't slowed.
func test_squeeze() -> void:
	var times := {}
	for b in [CrewBody.smallest(), CrewBody.new(), CrewBody.largest()]:
		var a := arena()
		Traversal.vent(a, Vector3(0, 0, -2), Vector3(0, 0, -10))
		var p := spawn(a, Vector3(0, 0.05, 0), b)
		await frames(5)
		p.controls.move = Vector2(0, -1)
		p.controls.crouch = true
		var n := 0
		while p.global_position.z > -3.0 and n < 600:
			await frames(1)
			n += 1
		n = 0
		while p.global_position.z > -7.0 and n < 900:
			await frames(1)
			n += 1
		times[b.size] = n
		check(p.global_position.z <= -7.0, "a %.2f body crawls 4 m of vent (%d frames)" % [b.size, n])
		await done(a)
	var small: int = times[CrewBody.smallest().size]
	var std: int = times[1.0]
	var big: int = times[CrewBody.largest().size]
	check(big > std * 1.2, "the largest crew member, barely fitting, crawls a vent much slower (%d frames to %d)" % [big, std])
	check(absf(small - std) <= std * 0.05, "a standard or smaller body has room, and isn't slowed (%d, %d)" % [small, std])
	var o := arena()
	var q := spawn(o, Vector3(0, 0.05, 0), CrewBody.largest())
	await frames(5)
	q.controls.crouch = true
	await frames(20)
	check(q.squeeze(Vector3.FORWARD) == 0.0, "crouching out in the open is no squeeze, even for the largest")
	await done(o)


func _stop(p: Player) -> void:
	p.controls.move = Vector2.ZERO
	p.controls.sprint = false
	p.controls.crouch = false
	p.controls.jump = false


# --- Floor sweep -------------------------------------------------------------

## Build a floor and check it everywhere: every spot the standard body can stand,
## crouch or crawl, the largest crew body can at least crawl; and along every
## vent, shutter gap, ledge, climb and doorway the largest body fits as it moves.
func test_floor_fits(scene: String) -> void:
	t.root.get_node("Game").new_run(7)
	var level = load("res://scenes/%s.tscn" % scene).instantiate()
	t.root.add_child(level)
	await frames(10)
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var skip: Array[RID] = []
	for n in level.find_children("*", "PhysicsBody3D", true, false):
		if n is CharacterBody3D or n is RigidBody3D or n is AnimatableBody3D:  # people, and whatever moves: every door counts as open
			skip.append(n.get_rid())
	var std := CrewBody.new()
	var big := CrewBody.largest()
	var bounds := AABB()
	var first := true
	for mi in level.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		if box.size.length() > 400.0:
			continue  # skies and backdrops
		bounds = box if first else bounds.merge(box)
		first = false
	# Walk the floor on a grid: every spot a standard body can reach on foot
	# (standing, crouching or crawling), the largest crew body must reach too,
	# wherever it fits at all. (Pockets only a standard body
	# fits into, under a chair or a hanging bag, lead nowhere and don't count.)
	var nodes := {}  # Vector2i column -> Array of feet positions
	var cells := 0
	var ix := 0
	var x := bounds.position.x
	while x <= bounds.end.x:
		var iz := 0
		var z := bounds.position.z
		while z <= bounds.end.z:
			var here := _floors(space, skip, Vector3(x, bounds.end.y + 0.5, z), bounds.position.y - 0.5)
			if not here.is_empty():
				nodes[Vector2i(ix, iz)] = here
				cells += here.size()
			z += GRID
			iz += 1
		x += GRID
		ix += 1
	# Set out from where the crew starts and from every doorway (doors count as
	# open). This walk checks heights; widths are the route checks' below, since
	# a grid this coarse can't thread a body through a doorway to the centimetre.
	var starts: Array[Vector3i] = []
	var from: Array[Vector3] = [level.player.global_position]
	for d in level.get_tree().get_nodes_in_group("doors"):
		if level.is_ancestor_of(d):
			from.append(d.get_parent().global_transform * d._closed_pos + Vector3.DOWN * d.size.y / 2)
	for pos in from:
		var best := Vector3i(-1, -1, -1)
		var dist := 0.5  # within a couple of grid steps, or not on this grid
		for col in nodes:
			for k in nodes[col].size():
				var d: float = nodes[col][k].distance_to(pos)
				if d < dist:
					dist = d
					best = Vector3i(col.x, col.y, k)
		if best.x != -1 and not best in starts:
			starts.append(best)
	var by_std := _reach(space, skip, nodes, starts, std.radius, std.crawl)
	var by_big := _reach(space, skip, nodes, starts, std.radius, big.crawl)  # the largest body's height
	var cut_off := []
	for key in by_std:
		if not by_big.has(key) and _fits(space, skip, nodes[Vector2i(key.x, key.y)][key.z], std.radius, big.crawl + 0.05):
			cut_off.append(_round(nodes[Vector2i(key.x, key.y)][key.z]))
	check(by_std.size() > 200 and cut_off.is_empty(),
		"%s: everywhere a standard body can walk or crawl to (%d of %d spots), the largest crew body gets to too (%s)" % [scene, by_std.size(), cells, str(cut_off.slice(0, 8))])

	var tight := []
	for v in level.find_children("*", "MovementVolume", true, false):
		var shape: BoxShape3D = v.get_child(0).shape
		var size: Vector3 = shape.size
		match v.kind:
			MovementVolume.Kind.VENT:
				var along := Vector3.RIGHT if size.x > size.z else Vector3.BACK
				var length: float = maxf(size.x, size.z)
				var bottom: Vector3 = v.global_position + Vector3.DOWN * (size.y / 2 - 0.02)
				for i in int(length / 0.3) + 1:
					var feet := bottom + along * (-length / 2 + 0.3 * i)
					if _fits(space, skip, feet, std.radius, std.crawl + 0.05) and not _fits(space, skip, feet, big.radius, big.crawl + 0.05):
						tight.append("vent %s" % _round(feet))
			MovementVolume.Kind.LEDGE:
				var out: Vector3 = v.normal
				for i in 11:
					var line: Vector3 = v.a.lerp(v.b, i / 10.0)
					if _fits(space, skip, line + out * (std.radius - Player.RADIUS), std.radius, std.stand) \
							and not _fits(space, skip, line + out * (big.radius - Player.RADIUS), big.radius, big.stand):
						tight.append("ledge %s" % _round(line))
			MovementVolume.Kind.CLIMB:
				for i in 9:
					var at: Vector3 = v.a.lerp(v.b, i / 8.0)
					if _fits(space, skip, at + v.normal * (std.radius + 0.2), std.radius, std.stand) \
							and not _fits(space, skip, at + v.normal * (big.radius + 0.2), big.radius, big.stand):
						tight.append("climb %s" % _round(at))
	for g in level.find_children("Gate*", "StaticBody3D", true, false):
		var past: Array[RID] = skip.duplicate()
		past.append(g.get_rid())
		var below := space.intersect_ray(_ray(g.global_position, g.global_position + Vector3.DOWN * 4.0, past))
		if below.is_empty():
			continue
		var feet: Vector3 = below.position
		if _fits(space, skip, feet, std.radius, std.crawl + 0.05) and not _fits(space, skip, feet, big.radius, big.crawl + 0.05):
			tight.append("shutter %s" % _round(feet))
	for d in level.get_tree().get_nodes_in_group("doors"):
		if not level.is_ancestor_of(d) or d.size.y < Player.STAND_HEIGHT:
			continue  # hatches and cupboards
		var leaf: Vector3 = d.get_parent().global_transform * d._closed_pos  # where the shut door fills the doorway (it may stand open)
		var under := space.intersect_ray(_ray(leaf, leaf + Vector3.DOWN * (d.size.y / 2 + 0.3), skip))
		if under.is_empty():
			continue
		var feet: Vector3 = under.position
		if _fits(space, skip, feet, std.radius, std.stand) and not _fits(space, skip, feet, big.radius, big.stand):
			tight.append("door %s" % d.name)
	check(tight.is_empty(), "%s: every vent, shutter, ledge, climb and doorway fits the largest crew body (%s)" % [scene, str(tight.slice(0, 8))])
	level.queue_free()
	await frames(2)


## The grid spots (Vector3i: column x, column z, which floor) a body `radius`
## wide that crawls `crawl` high can get to on foot from `starts`: it fits there,
## and nothing solid stands between neighbouring spots less than a step apart.
func _reach(space: PhysicsDirectSpaceState3D, skip: Array[RID], nodes: Dictionary, starts: Array[Vector3i], radius: float, crawl: float) -> Dictionary:
	var seen := {}
	var fits := {}
	var todo: Array[Vector3i] = starts.duplicate()
	for s in starts:
		seen[s] = true
	while not todo.is_empty():
		var at: Vector3i = todo.pop_back()
		var feet: Vector3 = nodes[Vector2i(at.x, at.y)][at.z]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var col: Vector2i = Vector2i(at.x, at.y) + d
			if not nodes.has(col):
				continue
			var floors: Array = nodes[col]
			for k in floors.size():
				var next := Vector3i(col.x, col.y, k)
				var to: Vector3 = floors[k]
				if seen.has(next) or absf(to.y - feet.y) > 0.35:
					continue
				if not fits.has(next):
					fits[next] = _fits(space, skip, to, radius, crawl + 0.05)
				if not fits[next]:
					continue
				var y := maxf(feet.y, to.y)
				var open := true
				for h in [0.3, Player.CRAWL_HEIGHT * 0.6]:
					var a := Vector3(feet.x, y + h, feet.z)
					var b := Vector3(to.x, y + h, to.z)
					if not space.intersect_ray(_ray(a, b, skip)).is_empty():
						open = false
						break
				if open:
					seen[next] = true
					todo.append(next)
	return seen


## Every floor (upward-facing surface) under a column from `top` down to `bottom_y`.
func _floors(space: PhysicsDirectSpaceState3D, skip: Array[RID], top: Vector3, bottom_y: float) -> Array:
	var out := []
	var from := top
	for i in 8:
		var hit := space.intersect_ray(_ray(from, Vector3(from.x, bottom_y, from.z), skip))
		if hit.is_empty():
			break
		if hit.normal.y > 0.7:
			out.append(hit.position)
		from = hit.position + Vector3.DOWN * 0.03
	return out


func _ray(from: Vector3, to: Vector3, skip: Array[RID]) -> PhysicsRayQueryParameters3D:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, skip)
	return q


## Player._fits for any radius: would a body this tall fit with its feet at `feet`?
func _fits(space: PhysicsDirectSpaceState3D, skip: Array[RID], feet: Vector3, radius: float, height: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius * 0.9
	shape.height = height - 0.1
	q.shape = shape
	q.exclude = skip
	q.transform = Transform3D(Basis(), feet + Vector3.UP * (height / 2 + 0.05))
	return space.intersect_shape(q, 1).is_empty()


func _round(v: Vector3) -> Vector3:
	return (v * 10.0).round() / 10.0
