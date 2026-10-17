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
	await test_auto_vault()
	await test_hang_shimmy_pull_up()
	await test_too_high_alone()
	await test_climb()
	await test_vent()
	await test_ledge_shuffle()
	await test_shoulders()
	await test_same_controls_same_moves()
	await test_notebook_hold()
	await test_use_terminal()
	await test_pick_up()
	await test_file_sticky()
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


## Walk a player at an obstacle built by `build` (in an arena, facing -Z from z = 2)
## and report whether they vaulted and where they ended up.
func _vault_run(build: Callable, sprint := false, crouch := false) -> Dictionary:
	var a := arena()
	build.call(a)
	var p := spawn(a, Vector3(0, 0.05, 2))
	await frames(20)
	p.controls.crouch = crouch
	forward(p, sprint)
	var vaulted := false
	for i in 150:
		await t.physics_frame
		vaulted = vaulted or p.state == Player.Move.VAULT
	var out := {"vaulted": vaulted, "pos": p.global_position, "state": p.state}
	await done(a)
	return out


func test_auto_vault() -> void:
	# Desk: 0.9 m tall, 0.8 m deep, near face at z = 0.
	var desk := func(a): Greybox.box(a, Vector3(0, 0.45, -0.4), Vector3(3, 0.9, 0.8), Color.DIM_GRAY)
	var r: Dictionary = await _vault_run(desk)
	check(r.vaulted and r.pos.z < -1.0 and r.pos.y < 0.1, "walking into a desk vaults you over it (%.1f, %.1f)" % [r.pos.z, r.pos.y])
	r = await _vault_run(func(a): Greybox.box(a, Vector3(0, 0.55, -0.4), Vector3(3, 1.1, 0.8), Color.DIM_GRAY))
	check(r.vaulted and r.pos.z < -1.0, "and over a 1.1 m front-desk counter")
	r = await _vault_run(func(a): Greybox.box(a, Vector3(0, 0.5, -0.05), Vector3(3, 1.0, 0.1), Color.DIM_GRAY))
	check(r.vaulted and r.pos.z < -0.5, "and over a thin railing")
	r = await _vault_run(func(a): Greybox.box(a, Vector3(0, 0.15, -0.4), Vector3(3, 0.3, 0.8), Color.DIM_GRAY))
	check(not r.vaulted, "not over something below the knee")
	r = await _vault_run(func(a): Greybox.box(a, Vector3(0, 0.7, -0.4), Vector3(3, 1.4, 0.8), Color.DIM_GRAY))
	check(not r.vaulted and r.pos.z > 0.0, "not over something chest high: that's a mantle with Space")
	r = await _vault_run(func(a): Greybox.box(a, Vector3(0, 0.45, -2), Vector3(3, 0.9, 4), Color.DIM_GRAY))
	check(not r.vaulted and r.pos.z > 0.0, "not onto a deep platform")
	r = await _vault_run(func(a):
		desk.call(a)
		Greybox.box(a, Vector3(0, 1.5, -1.1), Vector3(3, 3, 0.4), Color.DIM_GRAY))  # a wall right behind it
	check(not r.vaulted, "not when there's no room on the far side")
	r = await _vault_run(func(a):
		desk.call(a)
		Greybox.box(a, Vector3(0, 1.35, -0.4), Vector3(3, 0.2, 1.4), Color.DIM_GRAY))  # a shelf low over it
	check(not r.vaulted, "not with no headroom over the top")
	r = await _vault_run(desk, true)
	check(not r.vaulted and r.pos.z > 0.0, "sprinting into it doesn't vault")
	r = await _vault_run(desk, false, true)
	check(not r.vaulted, "neither does crouching into it")


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
	var book := FakeHeldNotebook.new()
	p.held_notebook = book
	check(p.toggle_notebook() and p.is_holding_notebook(), "Tab pulls the notebook out")
	await frames(10)
	var mid := p.notebook_amount
	await frames(30)
	check(mid > 0.05 and mid < 0.95 and p.notebook_amount == 1.0 and events == ["raised"], "it comes up over a moment, then says it's raised (%.2f halfway)" % mid)
	check(book.calls == ["open"], "and the notebook model plays its pull-out")
	p.raise_notebook()
	check(book.calls == ["open"], "raising it again while held does nothing")
	var z0 := p.global_position.z
	forward(p, true)
	p.controls.jump = true
	await frames(60)
	var moved := z0 - p.global_position.z
	check(moved > 0.8 and moved < Player.NOTEBOOK_WALK_SPEED + 0.1, "reading, you walk slowly even holding Shift (%.2f m/s)" % moved)
	check(p.global_position.y < 0.1, "and you can't jump")
	stop(p)
	var yaw0 := p.rotation.y
	_mouse_move(p, Vector2(100, 0))
	var turned := yaw0 - p.rotation.y
	check(p.is_holding_notebook() and not p.notebook_cursor and absf(turned - 100 * Player.MOUSE_SENS * Player.NOTEBOOK_LOOK_SCALE) < 0.001, "reading, the mouse still looks around, a little slower")
	check(not book.is_processing_input(), "and the pages ignore the mouse while it's looking")
	p.set_notebook_cursor(true)
	yaw0 = p.rotation.y
	_mouse_move(p, Vector2(100, 40))
	check(p.notebook_cursor and p.rotation.y == yaw0 and book.is_processing_input(), "holding right mouse shows a cursor for the pages and stops looking")
	p.set_notebook_cursor(false)
	_mouse_move(p, Vector2(100, 0))
	check(p.rotation.y < yaw0 and not book.is_processing_input(), "letting go of right mouse looks around again")
	p.set_notebook_cursor(true)
	p.toggle_notebook()
	check(not p.notebook_cursor, "putting the notebook away drops the cursor")
	await frames(40)
	check(not p.is_holding_notebook() and events == ["raised", "lowered"] and book.calls == ["open", "close"], "Tab again puts it away")
	p.held_notebook = null
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


func test_use_terminal() -> void:
	var a := arena()
	Greybox.box(a, Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 0.8), Color.DIM_GRAY, "Desk")
	var term := Terminal.spawn(a, Vector3(0, 0.9, 0), 0, "TEST", null, null)  # screen faces +Z
	var p := spawn(a, Vector3(1.4, 0.05, 2.6))
	p.rotate_y(2.0)
	await frames(20)
	var events := []
	p.terminal_focused.connect(func(): events.append("focused"))
	p.terminal_left.connect(func(): events.append("left"))
	p.raise_notebook()
	check(p.use_terminal(term.stand_point, term.focus_point) and p.is_using_terminal(), "E at a terminal steps you up to it")
	check(not p.is_holding_notebook(), "and puts the notebook away")
	forward(p, true)
	await frames(Player.TERMINAL_STEP_TIME * 60 + 2)
	var stand := term.stand_point.global_position
	var flat := Vector2(p.global_position.x - stand.x, p.global_position.z - stand.z).length()
	var facing := -p.global_basis.z
	check(flat < 0.05 and facing.dot(Vector3(0, 0, -1)) > 0.99, "you end up on its stand point, facing the screen (%.2f m off)" % flat)
	check(events.is_empty() and not p.is_terminal_focused(), "then the camera starts easing onto the screen")
	await frames(Player.TERMINAL_FOCUS_TIME * 60 + 2)
	var cam := p.camera.global_transform
	var to_screen := (term.focus_point.global_position - cam.origin)
	check(events == ["focused"] and p.is_terminal_focused(), "and settles on it")
	check(absf(to_screen.length() - Player.TERMINAL_FOCUS_DISTANCE) < 0.02 and (-cam.basis.z).dot(to_screen.normalized()) > 0.999, "looking straight at the screen from %.2f m" % to_screen.length())
	var held_at := p.global_position
	p.controls.jump = true
	await frames(30)
	check(p.global_position.distance_to(held_at) < 0.01 and p.state == Player.Move.TERMINAL, "you don't move while using it, whatever you press")
	stop(p)
	p.leave_terminal()
	await frames(Player.TERMINAL_FOCUS_TIME * 60 + 3)
	check(events == ["focused", "left"] and p.state == Player.Move.WALK, "Esc eases you back and you can move again")
	check(p.camera.transform.is_equal_approx(Transform3D.IDENTITY), "the camera is back in your head")
	p.rotate_y(PI)
	forward(p)
	await frames(30)
	check(Vector2(p.global_position.x - stand.x, p.global_position.z - stand.z).length() > 0.5, "and walk away")
	stop(p)
	p.controls.jump = true
	await frames(4)
	check(not p.use_terminal(term.stand_point, term.focus_point), "you can't start using one mid-jump")
	await frames(60)
	var screen := FakeTerminalScreen.new()
	screen.view = Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.1, 1.2, 0.9))
	p.use_terminal(term.stand_point, screen)
	await frames((Player.TERMINAL_STEP_TIME + Player.TERMINAL_FOCUS_TIME) * 60 + 4)
	check(p.is_terminal_focused() and p.camera.global_transform.is_equal_approx(screen.view), "with a real screen model, the camera goes where the screen says to read it from")
	p.leave_terminal()
	await frames(Player.TERMINAL_FOCUS_TIME * 60 + 3)
	screen.free()
	await done(a)


## A paper-sized prop: a collider and a mesh, like a Document.
func _paper(parent: Node, pos: Vector3, flat: bool) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	var mesh := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.21, 0.28)
	mesh.mesh = qm
	if flat:
		mesh.rotation_degrees.x = -90  # lying face up
	b.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.21, 0.02, 0.28) if flat else Vector3(0.21, 0.28, 0.05)
	shape.shape = bs
	b.add_child(shape)
	parent.add_child(b)
	return b


func test_pick_up() -> void:
	var a := arena()
	Greybox.box(a, Vector3(0, 0.45, -1), Vector3(1.6, 0.9, 0.8), Color.DIM_GRAY, "Desk")
	var paper := _paper(a, Vector3(0.3, 0.91, -1), true)
	var home := paper.global_transform
	var p := spawn(a, Vector3(0, 0.05, 0.2))
	await frames(20)
	var events := []
	p.prop_raised.connect(func(pr): events.append(["raised", pr]))
	p.prop_lowered.connect(func(pr): events.append(["lowered", pr]))
	check(p.pick_up(paper, Vector2(0.21, 0.28), Vector3.UP) and p.is_holding_prop(), "E on a paper picks it up")
	check(paper.collision_layer == 0 and paper.get_parent() == p.camera, "it's in your hands and doesn't bump into anything")
	await frames(int(Player.PICKUP_TIME * 60) + 6)
	check(events == [["raised", paper]], "it comes up over a moment, then it's ready to read")
	var cam := p.camera.global_transform
	var face := paper.global_basis * Vector3.UP  # the side with the writing
	var to_cam := (cam.origin - paper.global_position).normalized()
	check(face.normalized().dot(to_cam) > 0.95, "the writing faces you")
	var tan_v := tan(deg_to_rad(p.camera.fov / 2.0))
	var dist := -(cam.affine_inverse() * paper.global_position).z
	var fill := 0.28 / (2.0 * tan_v * dist)
	check(absf(fill - Player.READ_FILL) < 0.05 and absf((cam.affine_inverse() * paper.global_position).x) < 0.01, "held centred, big enough to read (fills %.2f of the view)" % fill)
	var yaw0 := p.rotation.y
	_mouse_move(p, Vector2(80, 0))
	check(p.rotation.y < yaw0, "you can look around while you read")
	p.set_notebook_cursor(true)
	check(p.notebook_cursor and paper.is_processing_input(), "right mouse gives a cursor for its lines")
	p.set_notebook_cursor(false)
	var z0 := p.global_position.z
	p.controls.move = Vector2(0, 1)  # back away from the desk
	p.controls.sprint = true
	await frames(60)
	stop(p)
	check(p.global_position.z - z0 < Player.NOTEBOOK_WALK_SPEED + 0.1 and p.global_position.z - z0 > 0.5, "and walk slowly")
	p.put_down()
	check(not p.is_holding_prop(), "E again puts it down")
	await frames(int(Player.PICKUP_TIME * 60) + 6)
	check(events.size() == 2 and events[1] == ["lowered", paper] and p.held_prop == null, "it goes back down, then says so")
	check(paper.get_parent() == a and paper.global_transform.is_equal_approx(home) and paper.collision_layer == 1, "back on the desk where it was, solid again")
	# A poster on a wall faces out along +Z.
	var poster := _paper(a, Vector3(-0.5, 1.5, -2), false)
	p.pick_up(poster)
	await frames(int(Player.PICKUP_TIME * 60) + 6)
	var out := (poster.global_basis * Vector3.BACK).normalized()
	check(out.dot((p.camera.global_position - poster.global_position).normalized()) > 0.95, "a wall poster comes off the wall facing you too")
	check(p.raise_notebook() and p.is_holding_notebook() and not p.is_holding_prop(), "Tab while reading puts it back and gets the notebook out")
	await frames(int(Player.PICKUP_TIME * 60) + 6)
	check(poster.get_parent() == a and p.held_prop == null, "and it's back on the wall")
	p.lower_notebook(true)
	check(not p.pick_up(null), "nothing to pick up, nothing happens")
	await done(a)


func test_file_sticky() -> void:
	var a := arena()
	var p := spawn(a, Vector3(0, 0.05, 0))
	await frames(20)
	var book := FakeHeldNotebook.new()
	p.camera.add_child(book)
	book.position = Vector3(0, -0.3, -0.42)
	p.held_notebook = book
	var note := _paper(a, Vector3(0.2, 1.2, -0.8), false)
	note.scale = Vector3.ONE * 0.4
	var filed := []
	p.sticky_filed.connect(func(n): filed.append(n))
	var kids := p.camera.get_child_count()
	check(p.file_into_notebook(note) and p.is_holding_notebook(), "taking a sticky note gets the notebook out")
	check(not note.visible and p.camera.get_child_count() == kids + 1, "the note leaves its spot and is in your hand")
	await frames(10)
	check(filed.is_empty(), "it waits for the notebook to open")
	await frames(int((Player.NOTEBOOK_RAISE_TIME + Player.FILE_TIME) * 60) + 10)
	check(filed == [note] and not p.is_filing(), "then goes onto the page, and says so")
	await frames(2)
	check(p.camera.get_child_count() == kids, "the note in your hand is gone into the book")
	check(p.is_holding_notebook(), "and the notebook stays open to see it")
	var stuck := _paper(a, Vector3(-0.2, 1.2, -0.8), false)
	check(p.file_into_notebook(stuck, true) and stuck.visible, "copying a note stuck to a terminal leaves it there")
	await frames(int(Player.FILE_TIME * 60) + 10)
	check(filed.size() == 2 and filed[1] == stuck, "and a copy goes in the notebook")
	p.held_notebook = null
	book.free()
	await done(a)


## A mouse movement as the local player gets it.
func _mouse_move(p: Player, by: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = by
	p.local_control = true  # only for this event: local players read the keyboard each tick
	p._unhandled_input(ev)
	p.local_control = false


## Stands in for Graphics' TerminalScreen.
class FakeTerminalScreen extends Node3D:
	var view := Transform3D()

	func focus_transform(_fov: float = 75.0, _fill: float = 0.85) -> Transform3D:
		return view


## Stands in for Graphics' HeldNotebook: records what the player asks of it.
class FakeHeldNotebook extends Node3D:
	var calls := []

	func open_book() -> void:
		calls.append("open")

	func close_book() -> void:
		calls.append("close")


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
	# The vault station: walk east from just past the shutter.
	var p: Player = level.player
	p.local_control = false
	p.global_position = Vector3(-21.5, 0.1, 2.0)
	p.rotation.y = -PI / 2
	await frames(20)
	forward(p)
	var vaulted := false
	for i in 60:
		await t.physics_frame
		vaulted = vaulted or p.state == Player.Move.VAULT
	check(vaulted and p.global_position.x > -19.9, "the gym has a desk to vault")
	level.queue_free()
	await t.process_frame
