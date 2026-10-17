extends RefCounted
## Movement and parkour tests. Each one builds a small greybox arena, drives a
## player through `controls` (the same way a networked teammate is driven) and
## checks where they end up.

var t: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("Movement")
	await test_walk_and_sprint()
	await test_gate_needs_slide_or_crouch()
	await test_crouch_fits_the_gap()
	await test_landing_roll()
	await test_mantle()
	await test_hang_shimmy_pull_up()
	await test_too_high_alone()
	await test_climb()
	await test_vent()
	await test_ledge_shuffle()
	await test_shoulders()
	await test_same_controls_same_moves()
	await test_notebook_hold()
	await test_movement_gym()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


# --- Arena helpers -----------------------------------------------------------

func arena() -> Node3D:
	var a := Node3D.new()
	t.root.add_child(a)
	Greybox.box(a, Vector3(0, -0.1, 0), Vector3(40, 0.2, 40), Color.GRAY, "Floor")
	return a


func spawn(parent: Node, pos: Vector3) -> Player:
	var p := Player.new()
	p.local_control = false
	p.position = pos  # arenas sit at the origin
	parent.add_child(p)
	return p


func frames(n: int) -> void:
	for i in n:
		await t.physics_frame


func done(a: Node) -> void:
	a.queue_free()
	await t.process_frame


func forward(p: Player, sprint := false) -> void:
	p.controls.move = Vector2(0, -1)
	p.controls.sprint = sprint


func stop(p: Player) -> void:
	p.controls.move = Vector2.ZERO
	p.controls.sprint = false
	p.controls.crouch = false


## Push forward, jump once, keep pushing.
func jump_forward(p: Player, n: int) -> void:
	forward(p)
	p.controls.jump = true
	await frames(n)


# --- Tests ---------------------------------------------------------------------

func test_walk_and_sprint() -> void:
	var a := arena()
	var walker := spawn(a, Vector3(-3, 0.05, 10))
	var runner := spawn(a, Vector3(3, 0.05, 10))
	await frames(5)
	forward(walker)
	forward(runner, true)
	await frames(60)
	var walked := 10.0 - walker.global_position.z
	var ran := 10.0 - runner.global_position.z
	check(walked > 3.0 and walked < 4.0, "walking covers about 3.8 m a second (%.2f m)" % walked)
	check(ran > walked * 1.5, "sprinting is much faster (%.2f m)" % ran)
	await done(a)


func _gate_arena() -> Node3D:
	var a := arena()
	# A wall across the room with one jammed shutter: a 1 m gap under it.
	Greybox.box(a, Vector3(-11, 1.5, -4), Vector3(20, 3, 0.2), Color.DIM_GRAY)
	Greybox.box(a, Vector3(11, 1.5, -4), Vector3(20, 3, 0.2), Color.DIM_GRAY)
	Traversal.gate(a, Vector3(0, 0, -4), 2.0, 1.0, 3.0)
	return a


func test_gate_needs_slide_or_crouch() -> void:
	var a := _gate_arena()
	var p := spawn(a, Vector3(0, 0.05, 2))
	await frames(5)
	forward(p, true)
	await frames(120)
	check(p.global_position.z > -4.0, "standing players can't pass a jammed shutter")
	await done(a)

	a = _gate_arena()
	p = spawn(a, Vector3(0, 0.05, 4))
	await frames(5)
	forward(p, true)
	await frames(40)
	p.controls.crouch = true
	await frames(2)
	var slid := p.state == Player.Move.SLIDE
	await frames(90)
	check(slid and p.global_position.z < -4.5, "a sprint slide goes under it (z %.1f)" % p.global_position.z)
	await done(a)

	a = _gate_arena()
	p = spawn(a, Vector3(0, 0.05, 4))
	await frames(5)
	forward(p, true)
	await frames(40)
	p.controls.sprint = false
	await frames(6)
	p.controls.crouch = true
	await frames(2)
	check(p.state == Player.Move.SLIDE, "letting go of Shift a moment before Ctrl still slides")
	stop(p)
	await frames(60)
	forward(p, true)
	await frames(40)
	p.controls.sprint = false
	await frames(30)
	p.controls.crouch = true
	await frames(2)
	check(p.state != Player.Move.SLIDE, "but not half a second later")
	await done(a)

	a = _gate_arena()
	p = spawn(a, Vector3(0, 0.05, 0))
	await frames(5)
	p.controls.crouch = true
	forward(p)
	p.controls.crouch = true
	var crawled := false
	for i in 180:
		await frames(1)
		crawled = crawled or p.crawling
	check(crawled, "you drop to a crawl on your own to fit under")
	check(p.global_position.z < -4.5, "crouch-walking also gets under (z %.1f)" % p.global_position.z)
	check(p.crouching and not p.crawling and p._height > 1.1, "crouching is a bent-knee stance, and you rise back to it past the shutter")
	await done(a)


func test_crouch_fits_the_gap() -> void:
	var heights := {}
	for gap in [1.15, 1.0]:
		var a := arena()
		Greybox.box(a, Vector3(-11, 1.5, -4), Vector3(20, 3, 0.2), Color.DIM_GRAY)
		Greybox.box(a, Vector3(11, 1.5, -4), Vector3(20, 3, 0.2), Color.DIM_GRAY)
		Traversal.gate(a, Vector3(0, 0, -4), 2.0, gap, 3.0)
		var p := spawn(a, Vector3(0, 0.05, -2))
		await frames(5)
		p.controls.crouch = true
		forward(p)
		p.controls.crouch = true
		var lowest := 9.0
		for i in 150:
			await frames(1)
			lowest = minf(lowest, p._height)
		heights[gap] = lowest
		check(p.global_position.z < -4.5, "crouch-walk under a %.2f m gap" % gap)
		await done(a)
	check(heights[1.15] > 1.0 and heights[1.15] < Player.CROUCH_HEIGHT, "under a 1.15 m gap you only duck a little (%.2f m)" % heights[1.15])
	check(heights[1.0] < heights[1.15], "a lower gap takes you lower (%.2f m)" % heights[1.0])


func test_landing_roll() -> void:
	var a := arena()
	var p := spawn(a, Vector3(0, 4.0, 0))
	var loud := []
	p.noise_made.connect(func(_at, l): if l >= 0.7: loud.append(l))
	await frames(2)
	p.velocity = Vector3(0, 0, -4)
	forward(p, true)
	await frames(60)
	check(loud.size() > 0, "a 4 m drop lands loudly")
	await done(a)

	a = arena()
	p = spawn(a, Vector3(0, 4.0, 0))
	loud.clear()
	p.noise_made.connect(func(_at, l): if l >= 0.7: loud.append(l))
	await frames(2)
	p.velocity = Vector3(0, 0, -4)
	forward(p, true)
	await frames(10)
	p.controls.crouch = true
	await frames(2)
	p.controls.crouch = false
	var rolled := false
	for i in 60:
		await frames(1)
		rolled = rolled or p.state == Player.Move.ROLL
	check(rolled and loud.is_empty(), "tapping crouch in the air rolls on landing, quietly")
	await done(a)


func test_mantle() -> void:
	var a := arena()
	Greybox.box(a, Vector3(0, 0.6, -3), Vector3(4, 1.2, 2), Color.DIM_GRAY)  # face at z = -2
	var p := spawn(a, Vector3(0, 0.05, 0))
	await frames(5)
	forward(p)
	await frames(30)
	p.controls.jump = true
	await frames(40)
	stop(p)
	await frames(10)
	check(p.global_position.y > 1.1 and p.global_position.z < -2.0, "jump at a waist-high crate mantles onto it (y %.2f)" % p.global_position.y)
	await done(a)


func _high_wall(a: Node, height: float) -> void:
	Greybox.box(a, Vector3(0, height / 2, -3), Vector3(6, height, 2), Color.DIM_GRAY)  # face at z = -2


func test_hang_shimmy_pull_up() -> void:
	var a := arena()
	_high_wall(a, 2.0)
	var p := spawn(a, Vector3(0, 0.05, -1.3))
	await frames(5)
	p.controls.jump = true
	await frames(3)
	check(p.state == Player.Move.HANG, "jumping at a 2 m wall catches the edge")
	var x0 := p.global_position.x
	p.controls.move = Vector2(1, 0)
	await frames(60)
	check(p.state == Player.Move.HANG and p.global_position.x > x0 + 0.8, "shimmy sideways along the edge (%.2f m)" % (p.global_position.x - x0))
	p.controls.move = Vector2(1, 0)
	await frames(240)
	check(p.global_position.x < 3.0 and p.state == Player.Move.HANG, "the shimmy stops where the edge ends")
	forward(p)
	await frames(40)
	stop(p)
	await frames(5)
	check(p.global_position.y > 1.9 and p.state == Player.Move.WALK, "push forward to pull up on top")
	await done(a)

	a = arena()
	_high_wall(a, 2.8)
	p = spawn(a, Vector3(0, 0.05, 0))
	await frames(5)
	forward(p)
	await frames(20)
	p.controls.jump = true
	await frames(60)
	check(p.state == Player.Move.HANG and p.global_position.y < 1.0, "holding W through a running jump at a 2.8 m wall grabs and hangs, without climbing")
	stop(p)
	await frames(3)
	forward(p)
	for i in 60:
		await frames(1)
		if p.state == Player.Move.WALK:
			break
	stop(p)
	await frames(5)
	check(p.global_position.y > 2.7, "release W and press it again to climb up (y %.2f)" % p.global_position.y)
	await done(a)

	a = arena()
	_high_wall(a, 2.0)
	p = spawn(a, Vector3(0, 0.05, -1.3))
	await frames(5)
	p.controls.jump = true
	await frames(3)
	var z_hang := p.global_position.z
	p.controls.jump = true
	await frames(20)
	check(p.state == Player.Move.WALK and p.global_position.z > z_hang + 0.5, "Space kicks off the wall from a hang")
	await done(a)

	a = arena()
	_high_wall(a, 2.0)
	p = spawn(a, Vector3(0, 0.05, -1.3))
	await frames(5)
	p.controls.jump = true
	await frames(3)
	p.controls.crouch = true
	await frames(30)
	check(p.state == Player.Move.WALK and p.global_position.y < 0.2, "crouch lets go")
	await done(a)


func test_too_high_alone() -> void:
	var a := arena()
	_high_wall(a, 3.6)
	var p := spawn(a, Vector3(0, 0.05, 0))
	await frames(5)
	for i in 3:
		forward(p, true)
		await frames(20)
		p.controls.jump = true
		await frames(60)
	check(p.global_position.y < 0.5, "nobody reaches a 3.6 m ledge alone")
	await done(a)


func test_climb() -> void:
	var a := arena()
	# A 4 m platform with a pipe up its face.
	Greybox.box(a, Vector3(0, 2, -4), Vector3(6, 4, 4), Color.DIM_GRAY)  # face at z = -2
	Traversal.climbable(a, Vector3(0, 0, -2), Vector3(0, 4, -2), Vector3(0, 0, 1))
	var p := spawn(a, Vector3(0, 0.05, 0))
	await frames(5)
	forward(p)
	var climbed := false
	for i in 300:
		await frames(1)
		climbed = climbed or p.state == Player.Move.CLIMB
		if climbed and p.state == Player.Move.WALK:
			break
	stop(p)
	await frames(10)
	check(climbed and p.global_position.y > 3.9 and p.global_position.z < -2.0, "walk into a pipe to climb it and step off on top (y %.2f)" % p.global_position.y)

	# Climbing down and kicking off.
	var q := spawn(a, Vector3(0.0, 0.05, 0))
	await frames(5)
	forward(q)
	await frames(60)
	var mid := q.global_position.y
	q.controls.move = Vector2(0, 1)
	await frames(90)
	check(mid > 1.0 and q.global_position.y < 0.2 and q.state == Player.Move.WALK, "climb back down to the floor")
	await done(a)


func test_vent() -> void:
	var a := arena()
	var vent := Traversal.vent(a, Vector3(0, 0, -2), Vector3(0, 0, -10))
	# Walls so the duct is the only way through.
	Greybox.box(a, Vector3(-10.6, 1.5, -2), Vector3(20, 3, 0.2), Color.DIM_GRAY)
	Greybox.box(a, Vector3(10.6, 1.5, -2), Vector3(20, 3, 0.2), Color.DIM_GRAY)
	Greybox.box(a, Vector3(0, 2.0, -2), Vector3(1.2, 2.0, 0.2), Color.DIM_GRAY)
	check(vent.kind == MovementVolume.Kind.VENT, "vent helper builds a crawl volume")
	await frames(2)
	var probe := PhysicsRayQueryParameters3D.create(Vector3(0, 0.5, -6), Vector3(0, -0.5, -6))
	var floor_hit := a.get_world_3d().direct_space_state.intersect_ray(probe)
	check(not floor_hit.is_empty() and floor_hit.position.y > 0.005, "the duct floor sits just above the room floor, so they don't flicker")
	var p := spawn(a, Vector3(0, 0.05, 0))
	await frames(5)
	forward(p)
	await frames(120)
	check(p.global_position.z > -2.0, "you can't walk into a vent standing")
	var noises := []
	p.noise_made.connect(func(_at, l): noises.append(l))
	p.controls.crouch = true
	await frames(120)
	check(p.global_position.z < -2.5 and p.in_volume(MovementVolume.Kind.VENT) != null, "crouch to crawl in")
	check(noises.is_empty(), "crawling slowly is silent")
	var z := p.global_position.z
	await frames(60)
	check(z - p.global_position.z < Player.CRAWL_SPEED + 0.1, "crawling is slow")
	p.controls.crouch = false
	await frames(10)
	check(p.crouching, "you can't stand up in a duct")
	check(p.crawling and p.head.position.y < 0.85, "in a duct you crawl, camera low (%.2f m)" % p.head.position.y)
	p.controls.sprint = true
	await frames(60)
	check(noises.any(func(l): return l >= 0.9), "hurrying bangs the duct loudly")
	await done(a)


func test_ledge_shuffle() -> void:
	var a := Node3D.new()
	t.root.add_child(a)
	# Two floors with a long drop between; a wall along the back.
	Greybox.box(a, Vector3(-5, -0.1, 0), Vector3(6, 0.2, 6), Color.GRAY)
	Greybox.box(a, Vector3(11, -0.1, 0), Vector3(6, 0.2, 6), Color.GRAY)
	Greybox.box(a, Vector3(3, -20, 0), Vector3(40, 0.2, 40), Color.GRAY)  # far below
	Greybox.box(a, Vector3(3, 1.5, -3.1), Vector3(22, 3, 0.2), Color.DIM_GRAY)  # face at z = -3
	Traversal.ledge(a, Vector3(-2, 0, -3), Vector3(8, 0, -3), Vector3(0, 0, 1))
	var p := spawn(a, Vector3(-4, 0.05, -2.66))
	await frames(5)
	p.controls.move = Vector2(1, 0)
	p.controls.sprint = true
	var shuffled := false
	var top_speed := 0.0
	var lowest := 10.0
	var turned := false
	var max_turn := 0.0
	for i in 900:
		await frames(1)
		if p.state == Player.Move.LEDGE:
			if not turned:
				# Facing the wall on the ledge: try to turn right around.
				turned = true
				p.rotation.y = PI
			elif max_turn == 0.0:
				max_turn = absf(angle_difference(0.0, p.rotation.y))
				p.rotation.y = 0.0  # face the wall again and carry on
			shuffled = true
			top_speed = max(top_speed, Vector2(p.velocity.x, p.velocity.z).length())
		lowest = min(lowest, p.global_position.y)
		if p.global_position.x > 9.0:
			break
	check(shuffled and top_speed < Player.LEDGE_SPEED + 0.6, "stepping onto a ledge shuffles slowly, even sprinting (%.2f m/s)" % top_speed)
	check(lowest > -0.5 and p.global_position.x > 9.0, "the shuffle reaches the far side without falling")
	check(turned and max_turn <= Player.LEDGE_LOOK + 0.01, "facing the wall on a ledge, you can't turn your back to it (%.0f deg)" % rad_to_deg(max_turn))
	check(p.state == Player.Move.WALK, "walking off the end returns to normal movement")
	await done(a)


func test_shoulders() -> void:
	var a := arena()
	_high_wall(a, 3.6)
	var base := spawn(a, Vector3(0, 0.05, -1.55))
	var climber := spawn(a, Vector3(0, 0.05, -0.6))
	var third := spawn(a, Vector3(1.5, 0.05, -0.6))
	var fourth := spawn(a, Vector3(-1.5, 0.05, -0.6))
	await frames(10)
	check(base.can_carry(climber) and base.get_prompt(climber) != "", "a standing teammate offers their shoulders")
	base.interact(climber)
	await frames(5)
	check(climber.state == Player.Move.RIDE and absf(climber.global_position.y - Player.STAND_HEIGHT) < 0.15, "climb on: your feet are at their shoulders (y %.2f)" % climber.global_position.y)
	climber.interact(third)
	await frames(5)
	check(third.state == Player.Move.RIDE and third.global_position.y > Player.STAND_HEIGHT * 2 - 0.2, "three high (y %.2f)" % third.global_position.y)
	check(not third.can_carry(fourth), "no fourth on the stack")
	third.controls.crouch = true
	await frames(60)
	third.controls.crouch = false
	check(third.state == Player.Move.WALK and third.global_position.y < 0.3, "crouch to step down")

	climber.rotation.y = 0.0
	climber.controls.jump = true
	await frames(2)
	forward(climber)
	for i in 60:
		await frames(1)
		if climber.state == Player.Move.WALK and climber.global_position.y > 3.5:
			break
	stop(climber)
	await frames(10)
	check(climber.global_position.y > 3.5 and base.rider == null, "jump off their shoulders to reach the 3.6 m ledge (y %.2f)" % climber.global_position.y)
	await done(a)

	a = arena()
	base = spawn(a, Vector3(0, 0.05, 0))
	climber = spawn(a, Vector3(0, 0.05, 1))
	await frames(10)
	base.interact(climber)
	forward(base, true)
	await frames(60)
	var moved := -base.global_position.z
	var gap := Vector2(climber.global_position.x - base.global_position.x, climber.global_position.z - base.global_position.z).length()
	check(moved > 0.8 and moved < Player.CARRY_SPEED + 0.1 and gap < 0.15, "the base walks slowly and the rider goes along (%.2f m)" % moved)
	climber.controls.jump = true
	await frames(90)
	check(climber.state == Player.Move.WALK and climber.is_on_floor(), "jumping off with nothing to grab lands you back on the floor")
	await done(a)


func test_notebook_hold() -> void:
	var a := arena()
	_high_wall(a, 2.0)  # face at z = -2
	var p := spawn(a, Vector3(0, 0.05, 6))
	await frames(5)
	var events := []
	p.notebook_raised.connect(func(): events.append("raised"))
	p.notebook_lowered.connect(func(): events.append("lowered"))
	check(not p.notebook_anchor.visible and p.notebook_anchor.get_parent() == p.camera, "the notebook anchor rides the camera, hidden in the pocket")
	check(p.toggle_notebook() and p.is_holding_notebook(), "Tab pulls the notebook out")
	await frames(10)
	var mid := p.notebook_amount
	await frames(30)
	check(mid > 0.05 and mid < 0.95 and p.notebook_amount == 1.0 and events == ["raised"], "it comes up over a moment, then says it's raised (%.2f halfway)" % mid)
	var held_pos := p.notebook_anchor.position
	check(held_pos.y < -0.1 and held_pos.z < -0.2 and absf(held_pos.x) < 0.05, "held in front, lower centre of the view")
	var z0 := p.global_position.z
	forward(p, true)
	p.controls.jump = true
	await frames(60)
	var moved := z0 - p.global_position.z
	check(moved > 0.8 and moved < Player.NOTEBOOK_WALK_SPEED + 0.1, "reading, you walk slowly even holding Shift (%.2f m/s)" % moved)
	check(p.global_position.y < 0.1, "and you can't jump")
	stop(p)
	p.rotate_y(1.0)
	check(p.is_holding_notebook(), "you can still look around")
	p.toggle_notebook()
	await frames(40)
	check(not p.notebook_anchor.visible and events == ["raised", "lowered"], "Tab again puts it away")
	p.rotation.y = 0.0
	p.global_position = Vector3(0, 0.05, -1.3)
	await frames(5)
	p.raise_notebook()
	p.controls.jump = true
	await frames(3)
	check(p.state == Player.Move.WALK, "holding the notebook, Space doesn't grab edges either")
	p.lower_notebook()
	await frames(30)
	p.controls.jump = true
	await frames(3)
	check(p.state == Player.Move.HANG and not p.raise_notebook(), "you can't get the notebook out while hanging")
	await done(a)


func test_same_controls_same_moves() -> void:
	# Two copies of one course, far apart, driven by one recorded input stream:
	# what a remote teammate's machine does with the inputs it receives.
	var a := Node3D.new()
	t.root.add_child(a)
	var players: Array[Player] = []
	for ox in [0.0, 60.0]:
		var o := Vector3(ox, 0, 0)
		Greybox.box(a, o + Vector3(0, -0.1, 0), Vector3(20, 0.2, 30), Color.GRAY)
		Greybox.box(a, o + Vector3(0, 0.6, -3), Vector3(4, 1.2, 2), Color.DIM_GRAY)
		Traversal.gate(a, o + Vector3(0, 0, -9), 4.0, 1.0, 3.0)
		players.append(spawn(a, o + Vector3(0, 0.05, 0)))
	await frames(5)
	var script := []
	for i in 240:
		var c := PlayerControls.new()
		c.move = Vector2(0, -1)
		c.sprint = i > 120
		c.jump = i == 30
		c.crouch = i > 150 and i < 200
		script.append(c.pack())
	for frame in script:
		for p in players:
			p.controls.unpack(frame)
		await frames(1)
	var d: Vector3 = players[1].global_position - players[0].global_position - Vector3(60, 0, 0)
	check(d.length() < 0.01 and players[0].global_position.z < -9.5, "the same inputs replay the same run (drift %.4f m)" % d.length())
	await done(a)


func test_movement_gym() -> void:
	var level = load("res://scenes/movement_gym.tscn").instantiate()
	t.root.add_child(level)
	await frames(30)
	check(level.player != null and level.player.global_position.y > -1.0, "movement gym loads with a player on the floor")
	check(level.teammate is Player and not level.teammate.local_control, "the gym has a teammate to climb on")
	var kinds := {}
	for v in level.find_children("*", "MovementVolume", true, false):
		kinds[v.kind] = true
	check(kinds.size() == 3, "the gym has a vent, a climb and a ledge")
	level.queue_free()
	await t.process_frame
