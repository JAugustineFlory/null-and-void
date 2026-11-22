extends RefCounted
## Movement and parkour tests. Each one builds a small greybox arena, drives a
## player through `controls` (the same way a networked teammate is driven) and
## checks where they end up.

var t: SceneTree
var _check: Callable


## `part`: "moves" (parkour), "hands" (notebook, terminals, items, sitting,
## stamina, knocks and the gym) or "all". Split so each CI group stays short.
func run(tree: SceneTree, check: Callable, part := "all") -> void:
	t = tree
	_check = check
	print("Movement (%s)" % part)
	if part != "hands":
		await _run_moves()
	if part != "moves":
		await _run_hands()


func _run_moves() -> void:
	await test_walk_and_sprint()
	await test_gate_needs_slide_or_crouch()
	await test_crouch_fits_the_gap()
	await test_landing_roll()
	await test_mantle()
	await test_vault()
	await test_hang_shimmy_pull_up()
	await test_hang_one_arm()
	await test_leap_off_the_way_you_look()
	await test_too_high_alone()
	await test_no_climbing_through_the_ceiling()
	await test_climb()
	await test_vent()
	await test_ledge_shuffle()
	await test_shoulders()
	await test_leg_up()
	await test_cable_rope()
	await test_crate_stack()
	await test_pry_doors()
	await test_hatch()
	await test_stuck_lift()
	await test_ducts()
	await test_vent_entries()
	await test_grille_sides()
	await test_leg_up_hatch()
	await test_same_controls_same_moves()
	await test_first_person_motion()


func _run_hands() -> void:
	await test_notebook_hold()
	await test_use_terminal()
	await test_pick_up()
	await test_file_sticky()
	await test_inventory()
	await test_hotbar_keys()
	await test_inventory_screen()
	await test_sit()
	await test_stamina()
	await test_knocks()
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
	check(absf(walked - Player.WALK_SPEED) < 0.5, "walking covers about %.1f m a second (%.2f m)" % [Player.WALK_SPEED, walked])
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


## The camera moves with the body in first person: it looks down at your hands
## pushing up onto a ledge, dips when you land, and settles back where you look.
func test_first_person_motion() -> void:
	var a := arena()
	Greybox.box(a, Vector3(0, 0.6, -3), Vector3(4, 1.2, 2), Color.DIM_GRAY)  # a crate, face at z = -2
	var p := spawn(a, Vector3(0, 0.05, -1.4))
	await frames(10)
	check(p.camera.transform.is_equal_approx(Transform3D.IDENTITY) and p.move_name() == "walk", "standing still, the view is just where you look")
	p.controls.move = Vector2(0, -0.5)
	p.controls.jump = true
	var dip := 0.0
	var named := false
	var progress := 0.0
	var grip := {}
	for i in 40:
		await frames(1)
		named = named or p.move_name() == "mantle"
		progress = maxf(progress, p.parkour_progress())
		if p.move_name() == "mantle" and grip.is_empty():
			grip = p.parkour_grip()
		dip = minf(dip, p.camera.rotation.x)
	stop(p)
	check(named and progress > 0.5, "the mantle is named and has a progress for the arms")
	check(not grip.is_empty() and absf(grip.point.y - 1.2) < 0.05 and absf(grip.point.z + 2.0) < 0.15 and grip.normal.dot(Vector3.BACK) > 0.9, "and the hands grip the crate's edge")
	check(dip < -0.15, "mantling, you look down at your hands as you push up (%.2f rad)" % dip)
	await frames(60)
	check(p.camera.transform.origin.length() < 0.01 and absf(p.camera.rotation.x) < 0.01, "and the view settles back where you look")
	p.global_position = Vector3(0, 4.0, 2.0)
	p.velocity = Vector3.ZERO
	var low := 0.0
	for i in 70:
		await frames(1)
		low = minf(low, p.camera.position.y)
	check(low < -0.05, "dropping off a height, the view dips as you land (%.2f m)" % low)
	await done(a)

	a = arena()
	_high_wall(a, 2.0)
	p = spawn(a, Vector3(0, 0.05, -1.3))
	await frames(5)
	p.controls.move = Vector2(0, -0.5)
	p.controls.jump = true
	await frames(3)
	stop(p)
	var hold := p.parkour_grip()
	check(p.move_name() == "hang" and not hold.is_empty() and absf(hold.point.y - 2.0) < 0.05 and absf(hold.point.z + 2.0) < 0.1, "hanging, the hands are on the edge")
	stop(p)
	await frames(30)
	p.controls.jump = true
	await frames(60)
	check(p.parkour_grip().is_empty() and p.parkour_progress() == 0.0, "standing on top, nothing to hold")
	await done(a)


func _high_wall(a: Node, height: float) -> void:
	Greybox.box(a, Vector3(0, height / 2, -3), Vector3(6, height, 2), Color.DIM_GRAY)  # face at z = -2


## Walk a player at an obstacle built by `build` (in an arena, facing -Z from z = 2),
## pressing Space once when close if `jump`, and report whether they vaulted and
## where they ended up.
func _vault_run(build: Callable, jump := true, sprint := false, crouch := false, push := true) -> Dictionary:
	var a := arena()
	build.call(a)
	var p := spawn(a, Vector3(0, 0.05, 2))
	await frames(20)
	p.controls.crouch = crouch
	if push:
		forward(p, sprint)
	else:
		p.global_position.z = 0.6
	var vaulted := false
	var jumped := false
	for i in 150:
		if jump and not jumped and p.global_position.z < 0.75:
			p.controls.jump = true
			jumped = true
		await t.physics_frame
		vaulted = vaulted or p.state == Player.Move.VAULT
	var out := {"vaulted": vaulted, "pos": p.global_position, "state": p.state}
	await done(a)
	return out


func test_vault() -> void:
	# Desk: 0.9 m tall, 0.8 m deep, near face at z = 0.
	var desk := func(a): Greybox.box(a, Vector3(0, 0.45, -0.4), Vector3(3, 0.9, 0.8), Color.DIM_GRAY)
	var r: Dictionary = await _vault_run(desk, false)
	check(not r.vaulted and r.pos.z > 0.0, "just walking into a desk doesn't vault it")
	r = await _vault_run(desk)
	check(r.vaulted and r.pos.z < -1.0 and r.pos.y < 0.1, "W + Space at a desk vaults you over it (%.1f, %.1f)" % [r.pos.z, r.pos.y])
	r = await _vault_run(func(a): Greybox.box(a, Vector3(0, 0.55, -0.4), Vector3(3, 1.1, 0.8), Color.DIM_GRAY))
	check(r.vaulted and r.pos.z < -1.0, "and over a 1.1 m front-desk counter")
	r = await _vault_run(func(a): Greybox.box(a, Vector3(0, 0.5, -0.05), Vector3(3, 1.0, 0.1), Color.DIM_GRAY))
	check(r.vaulted and r.pos.z < -0.5, "and over a thin railing")
	r = await _vault_run(func(a): Greybox.box(a, Vector3(0, 0.2, -0.4), Vector3(3, 0.4, 0.8), Color.DIM_GRAY))
	check(r.vaulted and r.pos.z < -1.0, "and over a 0.4 m coffee table")
	r = await _vault_run(desk, true, true)
	check(r.vaulted and r.pos.z < -1.0, "sprinting in and pressing Space vaults too")
	r = await _vault_run(desk, true, false, false, false)
	check(not r.vaulted, "Space alone, standing at it, just jumps")
	r = await _vault_run(func(a): Greybox.box(a, Vector3(0, 0.1, -0.4), Vector3(3, 0.2, 0.8), Color.DIM_GRAY))
	check(not r.vaulted, "not over a kerb below the shin")
	r = await _vault_run(func(a): Greybox.box(a, Vector3(0, 0.7, -0.4), Vector3(3, 1.4, 0.8), Color.DIM_GRAY))
	check(not r.vaulted, "not over something chest high: the same keys mantle it")
	r = await _vault_run(func(a): Greybox.box(a, Vector3(0, 0.45, -2), Vector3(3, 0.9, 4), Color.DIM_GRAY))
	check(not r.vaulted, "not onto a deep platform")
	r = await _vault_run(func(a):
		desk.call(a)
		Greybox.box(a, Vector3(0, 1.5, -1.1), Vector3(3, 3, 0.4), Color.DIM_GRAY))  # a wall right behind it
	check(not r.vaulted, "not when there's no room on the far side")
	r = await _vault_run(func(a):
		desk.call(a)
		Greybox.box(a, Vector3(0, 1.35, -0.4), Vector3(3, 0.2, 1.4), Color.DIM_GRAY))  # a shelf low over it
	check(not r.vaulted, "not with no headroom over the top")
	r = await _vault_run(desk, true, false, true)
	check(not r.vaulted, "not while crouching")


## Hanging from an edge, your head and shoulders turn with both hands on; further
## round one hand lets go and you pivot on the other.
func test_hang_one_arm() -> void:
	var a := arena()
	_high_wall(a, 2.0)
	var p := spawn(a, Vector3(0, 0.05, -1.3))
	await frames(5)
	p.controls.move = Vector2(0, -0.5)
	p.controls.jump = true
	await frames(3)
	stop(p)
	await frames(2)
	check(p.state == Player.Move.HANG, "caught the edge to test one-armed hanging")
	await frames(30)
	var lean := p.camera.global_position - p.head.global_position
	check(absf(lean.y - Player.HANG_LEAN.x) < 0.03 and absf(-lean.z - Player.HANG_LEAN.y) < 0.03, "hanging, your view leans up and in over your hands (%s)" % lean)
	check(p.camera.global_position.y <= p._hang_top - Player.HANG_EYES_BELOW + 0.01, "with your eyes still below the edge, not peeking over it")
	check(p.hang_free_hand() == "" and p.parkour_grip().get("hands", []) == ["l", "r"], "facing the wall, both hands hold the edge")
	p.rotation.y = deg_to_rad(70.0)
	check(p.hang_free_hand() == "", "turning head and shoulders aside keeps both hands on")
	p.rotation.y = deg_to_rad(90.0)
	check(p.hang_free_hand() == "l" and p.parkour_grip()["hands"] == ["r"], "looking further left lets go with the left hand")
	p.rotation.y = deg_to_rad(78.0)
	check(p.hang_free_hand() == "l", "turning back a touch doesn't flicker the hand on and off")
	p.rotation.y = deg_to_rad(175.0)
	check(p.hang_free_hand() == "l", "still the left hand looking almost straight back")
	p.rotation.y = deg_to_rad(-175.0)
	check(p.hang_free_hand() == "l", "no flicker just past straight behind")
	p.rotation.y = deg_to_rad(-120.0)
	check(p.hang_free_hand() == "r" and p.parkour_grip()["hands"] == ["l"], "past the centre line to the right, the hands swap")
	p.rotation.y = deg_to_rad(-90.0)
	await frames(10)
	check(p.state == Player.Move.HANG, "still hanging one-armed")
	p.rotation.y = 0.0
	check(p.parkour_grip()["hands"] == ["l", "r"], "face the wall again: both hands back on")
	p.controls.jump = true
	await frames(30)
	p.controls.jump = false
	await frames(10)
	check(p.state != Player.Move.HANG and p.hang_free_hand() == "", "off the wall, no hand is free")
	check((p.camera.global_position - p.head.global_position).length() < 0.05, "and your view settles back on your head")
	# The tallest crew member's eyes start nearer the edge: still kept below it.
	var big := spawn(a, Vector3(2, 0.05, -1.3))
	big.body = CrewBody.largest()
	await frames(5)
	big.controls.move = Vector2(0, -0.5)
	big.controls.jump = true
	await frames(3)
	stop(big)
	await frames(30)
	check(big.state == Player.Move.HANG and big.camera.global_position.y <= big._hang_top - Player.HANG_EYES_BELOW + 0.01, "the tallest crew member's eyes stay below the edge too (%.2f below)" % (big._hang_top - big.camera.global_position.y))
	await done(a)


## Hanging or on a pipe, Space while looking away from the wall kicks you off the
## way you look; facing the wall it climbs (or kicks straight back) as before.
func test_leap_off_the_way_you_look() -> void:
	var a := arena()
	_high_wall(a, 2.0)
	var p := spawn(a, Vector3(0, 0.05, -1.3))
	await frames(5)
	p.controls.move = Vector2(0, -0.5)
	p.controls.jump = true
	await frames(3)
	stop(p)
	await frames(10)
	check(p.state == Player.Move.HANG, "caught the edge to test kicking off")
	p.rotation.y = deg_to_rad(150.0)  # looking back over your left shoulder
	var look := -p.global_transform.basis.z
	var x0 := p.global_position.x
	var z0 := p.global_position.z
	p.controls.jump = true
	await frames(2)
	p.controls.jump = false
	check(p.state == Player.Move.WALK, "Space looking away from the wall lets go")
	var flat := Vector2(p.velocity.x, p.velocity.z).normalized()
	check(flat.dot(Vector2(look.x, look.z).normalized()) > 0.99 and p.velocity.y > 0.0, "and kicks you off the way you look")
	await frames(20)
	check(p.global_position.z > z0 + 0.8 and p.global_position.x < x0 - 0.3, "away from the wall and off to the side you looked (x %.2f z %.2f)" % [p.global_position.x - x0, p.global_position.z - z0])

	# On a pipe, the same.
	Greybox.box(a, Vector3(6, 2, -4), Vector3(2, 4, 4), Color.DIM_GRAY)  # face at z = -2
	Traversal.climbable(a, Vector3(6, 0, -2), Vector3(6, 4, -2), Vector3(0, 0, 1))
	var q := spawn(a, Vector3(6, 0.05, -1.0))
	await frames(5)
	forward(q)
	q.controls.jump = true
	await frames(30)
	q.controls.jump = false
	stop(q)
	await frames(2)
	check(q.state == Player.Move.CLIMB and q.parkour_grip().get("hands", []) == ["l", "r"], "up a pipe, both hands on it")
	q.rotation.y = deg_to_rad(-120.0)  # looking back over your right shoulder
	check(q.parkour_grip()["hands"] == ["l"], "looking round past your shoulder, the right hand lets go")
	q.controls.jump = true
	await frames(2)
	q.controls.jump = false
	check(q.state == Player.Move.WALK and q.velocity.x > 2.0 and q.velocity.z > 1.0, "Space looking away from a pipe kicks you off the way you look (v %s)" % q.velocity)
	await done(a)


func test_hang_shimmy_pull_up() -> void:
	var a := arena()
	_high_wall(a, 2.0)
	var p := spawn(a, Vector3(0, 0.05, -1.3))
	await frames(5)
	p.controls.move = Vector2(0, -0.5)  # a direction key with Space
	p.controls.jump = true
	await frames(3)
	check(p.state == Player.Move.HANG, "W + Space at a 2 m wall catches the edge")
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
	p.controls.move = Vector2(0, -0.5)
	p.controls.jump = true
	await frames(3)
	stop(p)
	await frames(15)
	check(p.state == Player.Move.HANG, "hanging, waiting")
	p.controls.jump = true
	for i in 60:
		await frames(1)
		if p.state == Player.Move.WALK:
			break
	await frames(5)
	check(p.global_position.y > 1.9 and p.state == Player.Move.WALK, "Space pulls you up from a hang")
	await done(a)

	a = arena()
	_high_wall(a, 2.0)
	p = spawn(a, Vector3(0, 0.05, -1.3))
	await frames(5)
	p.controls.move = Vector2(0, -0.5)
	p.controls.jump = true
	await frames(3)
	stop(p)
	p.controls.jump = true  # straight away, before you've settled on the edge
	for i in 60:
		await frames(1)
		if p.state == Player.Move.WALK:
			break
	await frames(5)
	check(p.global_position.y > 1.9, "Space pressed the moment you catch the edge still pulls you up (y %.2f)" % p.global_position.y)
	await done(a)

	a = arena()
	_high_wall(a, 2.0)
	p = spawn(a, Vector3(0, 0.05, -1.3))
	await frames(5)
	p.controls.move = Vector2(0, -0.5)
	p.controls.jump = true
	await frames(3)
	stop(p)
	await frames(15)
	Greybox.box(a, Vector3(0, 2.5, -2.6), Vector3(6, 1.0, 1.0), Color.DIM_GRAY)  # something lands on the edge
	await frames(2)
	var z_hang := p.global_position.z
	p.controls.jump = true
	await frames(20)
	check(p.state == Player.Move.WALK and p.global_position.z > z_hang + 0.5 and p.global_position.y < 1.9, "no room on top, Space kicks off the wall instead")
	await done(a)

	a = arena()
	_high_wall(a, 2.0)
	p = spawn(a, Vector3(0, 0.05, -1.3))
	await frames(5)
	p.controls.move = Vector2(0, -0.5)
	p.controls.jump = true
	await frames(3)
	stop(p)
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


## Up on a crate under the ceiling, the next room's roof is over a thin wall
## within reach: it's not a ledge.
func test_no_climbing_through_the_ceiling() -> void:
	var a := arena()
	Greybox.box(a, Vector3(0, 1.6, -3.05), Vector3(6, 3.2, 0.1), Color.DIM_GRAY)  # a thin wall up to the roof
	Greybox.box(a, Vector3(0, 3.1, -2.0), Vector3(6, 0.2, 9), Color.GRAY)  # one ceiling over both rooms
	Greybox.box(a, Vector3(0, 0.55, -2.5), Vector3(6, 1.1, 1), Color.DIM_GRAY)  # a crate against the wall
	var p := spawn(a, Vector3(0, 1.15, -2.45))
	await frames(20)
	check(p.is_on_floor() and p.global_position.y > 1.0, "standing on the crate, facing the wall")
	check(p._ledge_probe(Vector3.FORWARD).is_empty(), "the roof over the wall isn't a ledge to climb onto")
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
		p.controls.jump = not climbed and p.global_position.z < -1.0  # W + Space at the pipe
		await frames(1)
		climbed = climbed or p.state == Player.Move.CLIMB
		if climbed and p.state == Player.Move.WALK:
			break
	stop(p)
	await frames(10)
	check(climbed and p.global_position.y > 3.9 and p.global_position.z < -2.0, "W + Space at a pipe climbs it, and you step off on top (y %.2f)" % p.global_position.y)

	# Climbing down and kicking off.
	var q := spawn(a, Vector3(0.0, 0.05, -1.2))
	await frames(5)
	q.global_position.z = -1.2
	check(q.state == Player.Move.WALK, "standing at a pipe doesn't climb it")
	forward(q)
	await frames(20)
	check(q.state == Player.Move.WALK, "nor does walking into it")
	q.controls.jump = true
	await frames(40)
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
	var face_on := Vector3.ZERO
	var face_turned := Vector3.ZERO
	var grip := {}
	for i in 900:
		await frames(1)
		if p.state == Player.Move.LEDGE:
			if not turned:
				# Facing the wall on the ledge: try to turn right around.
				turned = true
				face_on = p.parkour_grip().get("face", Vector3.ZERO)
				p.rotation.y = PI
			elif max_turn == 0.0:
				face_turned = p.parkour_grip().get("face", Vector3.ZERO)
				max_turn = absf(angle_difference(0.0, p.rotation.y))
				grip = p.parkour_grip()
				p.rotation.y = 0.0  # face the wall again and carry on
			shuffled = true
			top_speed = max(top_speed, Vector2(p.velocity.x, p.velocity.z).length())
		lowest = min(lowest, p.global_position.y)
		if p.global_position.x > 9.0:
			break
	check(shuffled and top_speed < Player.LEDGE_SPEED + 0.6, "stepping onto a ledge shuffles slowly, even sprinting (%.2f m/s)" % top_speed)
	check(lowest > -0.5 and p.global_position.x > 9.0, "the shuffle reaches the far side without falling")
	check(turned and max_turn <= Player.LEDGE_LOOK + 0.01, "facing the wall on a ledge, you can't turn your back to it (%.0f deg)" % rad_to_deg(max_turn))
	check(face_on.is_equal_approx(Vector3(0, 0, -1)) and face_turned == face_on, "the ledge grip keeps the stance you stepped on with, however you look")
	check(grip.get("face", Vector3.ZERO).dot(Vector3(0, 0, -1)) > 0.99, "the ledge grip says you face the wall")
	check(grip.get("hands", []).size() == 1, "turned that far, one hand comes off the wall (%s)" % [grip.get("hands")])
	check(p.state == Player.Move.WALK, "walking off the end returns to normal movement")
	await done(a)


## A body of `size` at `pos`, facing -Z (set before it enters the world).
func _spawn_sized(parent: Node, pos: Vector3, body: CrewBody) -> Player:
	var p := Player.new()
	p.local_control = false
	p.body = body
	p.position = pos
	parent.add_child(p)
	return p


## Climber takes a leg-up off `base`. True once they stand on the top, `top` m up.
func _go_up(base: Player, climber: Player, top: float) -> bool:
	base.interact(climber)
	for i in 120:
		await frames(1)
		if climber.state == Player.Move.WALK and climber.is_on_floor() and climber.global_position.y > top - 0.1:
			return true
	return false


## E1 (environment play): crouch at a wall, facing it, and you're braced; a
## teammate steps up off you to an edge too high to reach alone.
func test_leg_up() -> void:
	print("Movement: the leg-up")
	var a := arena()
	_high_wall(a, 3.5)  # face at z = -2
	var base := spawn(a, Vector3(0, 0.05, -1.5))
	var climber := spawn(a, Vector3(0, 0.05, -0.5))
	await frames(10)
	check(base.get_prompt(climber) == "[E] Climb on shoulders" and not climber.can_leg_up(base), "standing at the wall, a teammate still offers their shoulders, not a leg-up")
	base.controls.crouch = true
	await frames(10)
	check(not climber.brace_of(base).is_empty() and base.get_prompt(climber) == Player.LEG_UP_PROMPT, "crouched up against the wall, facing it, they're braced: a leg-up")
	base.rotation.y = PI
	await frames(2)
	check(climber.brace_of(base).is_empty() and base.get_prompt(climber) == "", "crouched with their back to it, they aren't")
	base.rotation.y = 0.0
	await frames(2)
	var base_at := base.global_position
	base.interact(climber)
	await frames(3)
	check(climber.state == Player.Move.LIFT and base.is_lifting(), "E on them: you're going up, and they hold still")
	base.controls.move = Vector2(0, 1)  # trying to walk off doesn't drop you
	base.controls.jump = true
	var up := false
	var held := INF
	for i in 120:
		await frames(1)
		if climber.state != Player.Move.LIFT and held == INF:
			held = base.global_position.distance_to(base_at)  # off their hands
		if climber.state == Player.Move.WALK and climber.is_on_floor() and climber.global_position.y > 3.4:
			up = true
			break
	stop(base)
	check(up, "you go up off them and over the 3.5 m edge (y %.2f)" % climber.global_position.y)
	check(held < 0.15, "and they stayed braced under you till you were off them (%.2f m)" % held)
	check(base.get_prompt(climber) == "", "from up there, nothing to press on them")
	await done(a)

	# Out of reach of the leg-up, or a ceiling over them: no prompt, so nobody's
	# lifted into nothing.
	a = arena()
	_high_wall(a, Player.LEG_UP_REACH + 0.4)
	base = spawn(a, Vector3(0, 0.05, -1.5))
	climber = spawn(a, Vector3(0, 0.05, -0.5))
	base.controls.crouch = true
	await frames(15)
	check(not climber.brace_of(base).is_empty() and not climber.can_leg_up(base) and base.get_prompt(climber) == "", "braced under an edge too high even for a leg-up, there's nothing to take")
	await done(a)
	a = arena()
	_high_wall(a, 3.5)
	Greybox.box(a, Vector3(0, 2.6, -1.0), Vector3(6, 0.2, 2), Color.GRAY)  # a soffit over them, 2.5 m up
	base = spawn(a, Vector3(0, 0.05, -1.5))
	climber = spawn(a, Vector3(0, 0.05, -0.5))
	base.controls.crouch = true
	await frames(15)
	check(not climber.can_leg_up(base), "with a ceiling over them, no leg-up through it")
	await done(a)

	# Every body, both ways round, gets up edges from too high to reach alone to
	# the top of the leg-up's reach.
	var ok := true
	var report := []
	var bodies := [CrewBody.smallest(), CrewBody.largest()]
	for h in [Player.SOLO_REACH + 0.1, Player.LEG_UP_REACH]:
		for bb in bodies:
			for cb in bodies:
				a = arena()
				_high_wall(a, h)
				base = _spawn_sized(a, Vector3(0, 0.05, -2.0 + bb.radius + 0.12), bb)
				climber = _spawn_sized(a, Vector3(0, 0.05, -0.6), cb)
				base.controls.crouch = true
				await frames(15)
				var got: bool = climber.can_leg_up(base) and await _go_up(base, climber, h)
				ok = ok and got
				if not got:
					report.append("%.2f m, base %.2f, climber %.2f" % [h, bb.size, cb.size])
				await done(a)
	check(ok, "every body size, braced or climbing, gets up a %.1f m and a %.1f m edge %s" % [Player.SOLO_REACH + 0.1, Player.LEG_UP_REACH, report])

	# Too high to reach alone, even with a running jump.
	a = arena()
	_high_wall(a, Player.SOLO_REACH + 0.1)
	var solo := spawn(a, Vector3(0, 0.05, 0))
	await frames(5)
	for i in 3:
		forward(solo, true)
		await frames(20)
		solo.controls.jump = true
		await frames(60)
	check(solo.global_position.y < 0.5, "and alone, nobody reaches a %.1f m edge" % (Player.SOLO_REACH + 0.1))
	await done(a)


## E2 (environment play): the first one up ties a network cable off at the top
## and everyone else climbs it; it's used up until someone unties it.
func test_cable_rope() -> void:
	print("Movement: the cable rope")
	var a := arena()
	_high_wall(a, 3.6)  # face at z = -2, top from z = -4
	var anchor := CableAnchor.make(a, Vector3(0, 3.6, -2.0), Vector3.BACK, 3.6)
	var up := spawn(a, Vector3(1.5, 3.65, -3.2))  # up top, out of the way of the climb
	var below := spawn(a, Vector3(0, 0.05, -0.9))
	await frames(15)
	check(anchor.get_prompt(below) == CableAnchor.NEED and anchor.get_prompt(up) == CableAnchor.NEED, "with no cable on you, the anchor's only something to tie one to")
	anchor.interact(up)
	check(not anchor.tied, "and pressing it does nothing")
	up.inventory.add("cable")
	check(anchor.get_prompt(up) == "[E] " + CableAnchor.TIE, "up top with a cable: tie it off")
	anchor.interact(up)
	await frames(2)
	check(anchor.tied and anchor.rope.visible and anchor.volume != null and not up.inventory.has("cable"), "tied: it hangs down the wall, and it's out of your inventory")
	check(anchor.get_prompt(up) == "[E] " + CableAnchor.UNTIE, "anyone up there without a cable can untie it")
	# Below, W + Space at it and climb.
	below.rotation.y = 0.0
	forward(below)
	below.controls.jump = true
	var climbed := false
	var on_it := false
	for i in 300:
		await frames(1)
		on_it = on_it or below.state == Player.Move.CLIMB
		if below.state == Player.Move.WALK and below.is_on_floor() and below.global_position.y > 3.5:
			climbed = true
			break
	stop(below)
	check(on_it and climbed, "below, W + Space takes hold of it, and you climb it to the top (y %.2f)" % below.global_position.y)
	# Untied with someone on it: they drop off it.
	var third := spawn(a, Vector3(0.0, 0.05, -0.9))
	await frames(10)
	forward(third)
	third.controls.jump = true
	await _until_state(third, Player.Move.CLIMB, 60)
	await frames(20)
	stop(third)
	var was_on := third.state == Player.Move.CLIMB
	anchor.interact(up)
	await frames(2)
	check(not anchor.tied and not anchor.rope.visible and anchor.volume == null and up.inventory.has("cable"), "untied: the cable's back in the inventory of whoever untied it")
	await frames(90)
	check(was_on and third.state == Player.Move.WALK and third.global_position.y < 0.3, "and whoever was on it is back on the floor")
	check(anchor.get_prompt(below) == CableAnchor.NEED, "with nothing tied, the one who climbed it has no cable to tie")
	await done(a)

	# A fixed one keeps its own cable, tied off a beam overhead: anyone ties and
	# unties it, and nobody's inventory changes.
	a = arena()
	_high_wall(a, 3.0)
	Greybox.box(a, Vector3(0, 3.95, -2.8), Vector3(6, 0.15, 0.15), Color.DIM_GRAY)  # a beam over the top
	anchor = CableAnchor.make(a, Vector3(0, 3.0, -2.0), Vector3.BACK, 3.0, true, Vector3(0, 3.8, -2.8))
	up = spawn(a, Vector3(0, 3.05, -3.4))
	await frames(15)
	check(anchor.get_prompt(up) == "[E] " + CableAnchor.TIE and anchor.coil.visible, "a fixed one lies coiled by its beam: anyone can tie it off")
	anchor.interact(up)
	await frames(2)
	check(anchor.tied and anchor.volume != null and not anchor.coil.visible and not up.inventory.has("cable"), "tied off in place, from nobody's inventory")
	anchor.interact(up)
	check(anchor.tied, "a second press straight after counts as the same press")
	anchor._changed_at = -100000  # a moment later
	anchor.interact(up)
	await frames(2)
	check(not anchor.tied and anchor.coil.visible and not up.inventory.has("cable"), "and untied, it stays where it is")
	await done(a)


func _until_state(p: Player, s: Player.Move, n: int) -> bool:
	for i in n:
		if p.state == s:
			return true
		await frames(1)
	return p.state == s


## E1's solo route: carry two crates to the wall, stack them, and climb an edge
## that would otherwise take a leg-up.
func test_crate_stack() -> void:
	print("Movement: stacking crates")
	var a := arena()
	_high_wall(a, 3.4)  # face at z = -2
	var one := Crate.make(a, Vector3(2.0, 0, 1.0))
	var two := Crate.make(a, Vector3(-2.0, 0, 1.0))
	var p := spawn(a, Vector3(2.0, 0.05, 1.8))
	await frames(15)
	check(one.get_prompt(p) == "[E] " + Crate.PICK_UP, "a crate: pick it up")
	one.interact(p)
	await frames(2)
	check(p.carrying == one and one.collision_layer == 0 and p._hands_full(), "it's in both hands")
	forward(p, true)
	await frames(60)
	stop(p)
	var carried := Vector2(p.global_position.x - 2.0, p.global_position.z - 1.8).length()
	check(carried < Player.NOTEBOOK_WALK_SPEED * 1.0 + 0.2, "carrying it you walk slowly, even sprinting (%.2f m in a second)" % carried)
	var ahead := one.global_position - p.global_position
	check(Vector2(ahead.x, ahead.z).length() > 0.5 and ahead.y > 0.5, "it's in front of you, chest high")
	# To the wall and down against it.
	p.global_position = Vector3(0, 0.05, -2.0 + 0.6 + Crate.SET_AHEAD + 0.02)
	p.rotation.y = 0.0
	await frames(5)
	var spot := one.set_down_spot(p)
	check(one.set_down(p) and p.carrying == null, "E sets it down in front of you (%s, from %s)" % [spot, p.global_position])
	await frames(2)
	check(absf(one.global_position.y - Crate.SIZE / 2.0) < 0.02 and one.global_position.z < -1.6 and one.collision_layer != 0, "on the floor against the wall (z %.2f)" % one.global_position.z)
	# The second, onto the first.
	p.global_position = Vector3(-2.0, 0.05, 1.8)
	await frames(10)
	two.interact(p)
	await frames(2)
	check(not one.get_prompt(p).contains(Crate.PICK_UP), "with one in your hands you can't pick up another")
	p.global_position = Vector3(0.1, 0.05, -2.0 + 0.6 + Crate.SET_AHEAD + 0.02)
	await frames(5)
	check(two.set_down(p), "and set it down on top of the first")
	await frames(2)
	check(absf(two.global_position.y - Crate.SIZE * 1.5) < 0.02 and absf(two.global_position.x - one.global_position.x) < 0.01 and absf(two.global_position.z - one.global_position.z) < 0.01,
		"it squares up on it: a stack %.1f m high" % (Crate.SIZE * 2))
	check(one.get_prompt(p) == "", "and the bottom one can't be pulled out from under it")
	# Up the stack and up the wall.
	p.global_position = Vector3(0, 0.05, -0.8)
	await frames(10)
	var up := false
	for i in 4:
		forward(p)
		p.controls.jump = true
		for f in 80:
			await frames(1)
			if p.state == Player.Move.HANG:
				p.controls.jump = true
			if p.state == Player.Move.WALK and p.is_on_floor() and p.global_position.y > 3.3:
				up = true
				break
		if up:
			break
	stop(p)
	check(up, "up the stack, then up the %.1f m wall (y %.2f)" % [3.4, p.global_position.y])
	await done(a)

	# No setting it down through a wall, or too high.
	a = arena()
	Greybox.box(a, Vector3(0, 1.5, -1.0), Vector3(6, 3, 0.1), Color.DIM_GRAY)
	var c := Crate.make(a, Vector3(0, 0, 0.5))
	p = spawn(a, Vector3(0, 0.05, 1.2))
	await frames(10)
	c.interact(p)
	await frames(2)
	p.global_position = Vector3(0, 0.05, -0.7)
	await frames(5)
	check(not c.set_down(p) and p.carrying == c and p.hud == null, "up against a wall there's no room in front of you: you keep it")
	await done(a)


## Two players pull on a stuck lift's doors (E9): strong crew together, or
## anyone with a crowbar between them.
func _pry(crews: Array, crowbar: bool) -> Dictionary:
	var a := arena()
	var doors := PryDoors.make(a, Vector3(0, 1.0, -2.0), Vector3.BACK, 0.5)
	var ps := []
	for i in 2:
		var p := spawn(a, Vector3(-0.4 + 0.8 * i, 0.05, -1.4))
		p.crew = crews[i]
		ps.append(p)
	if crowbar:
		ps[1].inventory.add("crowbar")
	await frames(10)
	var prompt: String = doors.grips[0].get_prompt(ps[0])
	ps[0].controls.use = true
	doors.grips[0].interact(ps[0])
	await frames(5)
	var alone: String = doors.prompt_for(0, ps[0])
	ps[1].controls.use = true
	doors.grips[1].interact(ps[1])
	var held := false
	for f in 30:
		await frames(1)
		held = held or (ps[0].gripping != null and ps[1].gripping != null)
	var both: String = doors.prompt_for(0, ps[0])
	var opened := false
	for f in int(PryDoors.PRY_TIME * 60) + 30:
		await frames(1)
		if doors.opened:
			opened = true
			break
	var out := {"prompt": prompt, "alone": alone, "both": both, "held": held, "opened": opened,
		"free": ps[0].gripping == null and ps[1].gripping == null, "taken": doors.grips[0].get_prompt(ps[1])}
	# Letting go ends it.
	ps[0].controls.use = false
	await frames(3)
	out["let_go"] = ps[0].gripping == null and doors.holders[0] == 0
	await done(a)
	return out


func test_pry_doors() -> void:
	print("Movement: prying a stuck lift's doors")
	var r := await _pry(["sam", "dana"], false)
	check(r.prompt == PryDoors.HOLD and r.alone == PryDoors.WAITING, "a door's edge: hold E on it; on your own, someone needs the other door")
	check(r.held and r.both == PryDoors.PRYING and r.opened, "two strong crew pulling together pry it open")
	check(r.free, "and let go once it gives")
	r = await _pry(["theo", "ike"], false)
	check(r.held and r.both == PryDoors.WONT_BUDGE and not r.opened, "two who aren't strong: it won't budge")
	check(r.let_go, "letting go of E lets go of the door")
	r = await _pry(["theo", "ike"], true)
	check(r.opened, "with a crowbar between them, anyone can")
	r = await _pry(["sam", "theo"], false)
	check(not r.opened, "one strong and one not isn't enough")
	check(PlayableCrew.STRONG.size() == 5 and PlayableCrew.STRONG.any(func(s): return PlayableCrew.info(s).body == 2), "five crew are strong, women among them")
	var a := arena()
	var doors := PryDoors.make(a, Vector3(0, 1.0, -2.0), Vector3.BACK, 0.5)
	var p := spawn(a, Vector3(-0.4, 0.05, -1.4))
	var q := spawn(a, Vector3(0.4, 0.05, -1.4))
	await frames(10)
	p.controls.use = true
	doors.grips[0].interact(p)
	await frames(3)
	q.controls.use = true
	doors.grips[0].interact(q)
	await frames(3)
	check(p.gripping == doors.grips[0] and q.gripping == null and doors.grips[0].get_prompt(q) == "", "one pair of hands to each door")
	doors.enabled = false
	await frames(3)
	check(p.gripping == null and doors.holders == [0, 0] and doors.grips[1].get_prompt(q) == "", "switched off (the car's moving again), nobody's holding and there's nothing to hold")
	doors.enabled = true
	p.controls.use = true
	doors.grips[0].interact(p)
	await frames(3)
	var at := p.global_position
	p.controls.move = Vector2(0, 1)
	await frames(30)
	check(p.global_position.distance_to(at) < 0.1, "holding on, you stay at the door (%.2f m)" % p.global_position.distance_to(at))
	await done(a)


## E9's roof hatch: Space under it with the rim in reach, or a jump to catch a
## higher one, pulls you up through it onto the roof.
func test_hatch() -> void:
	print("Movement: up through a roof hatch")
	for big in [false, true]:
		var a := arena()
		# A 2.5 m ceiling with a 0.8 m hatch in it, and the roof over it.
		Greybox.box(a, Vector3(0, 2.55, -2.9), Vector3(4, 0.1, 3.0), Color.GRAY)  # z -4.4 .. -1.4
		Greybox.box(a, Vector3(0, 2.55, 0.9), Vector3(4, 0.1, 3.0), Color.GRAY)  # z -0.6 .. 2.4
		Greybox.box(a, Vector3(-1.2, 2.55, -1.0), Vector3(1.6, 0.1, 0.8), Color.GRAY)
		Greybox.box(a, Vector3(1.2, 2.55, -1.0), Vector3(1.6, 0.1, 0.8), Color.GRAY)
		var vol := Traversal.hatch(a, Vector3(0, 2.6, -1.0), Vector2(0.8, 0.8), Vector3(0, 2.6, -2.0))
		vol.active = false
		var p := spawn(a, Vector3(0, 0.05, -1.0)) if not big else _spawn_sized(a, Vector3(0, 0.05, -1.0), CrewBody.largest())
		await frames(15)
		p.controls.jump = true
		await frames(60)
		var shut_ok := p.global_position.y < 0.3
		vol.active = true
		var up := false
		for i in 3:
			p.controls.jump = true
			for f in 60:
				await frames(1)
				if p.state == Player.Move.WALK and p.is_on_floor() and p.global_position.y > 2.5:
					up = true
					break
			if up:
				break
		check(shut_ok and up, "%s: shut, a jump goes nowhere; open, you jump, catch the rim and pull up onto the roof (y %.2f)" % ["largest body" if big else "standard body", p.global_position.y])
		await done(a)


## E9 on a real lift that sticks (ElevatorStall), fitted with PryDoors.fit: out
## through its roof hatch, or two strong crew prying its doors.
func test_stuck_lift() -> void:
	print("Movement: out of a stuck lift")
	var a := arena()
	var lift := Elevator.create(a, a, Vector3(0, 0, -3), 0, "G", ["G", "1"], "1")
	var stall := ElevatorStall.attach(lift, a, "movement_lift")
	var doors := PryDoors.fit(stall)
	var climb: MovementVolume = stall.hatch_climb
	var shape: CollisionShape3D = doors.grips[0].get_child(0)
	await frames(5)
	check(not doors.enabled and shape.disabled and not climb.active and doors.grips[1].get_prompt(null) == "", "fitted to a lift that isn't stuck: nothing in its doorway, nothing to climb")
	var p := spawn(a, lift.to_global(Vector3(ElevatorStall.HATCH.position.x, 0.05, ElevatorStall.HATCH.position.y)))
	var q := spawn(a, lift.to_global(Vector3(-0.4, 0.05, 0.7)))
	var r := spawn(a, lift.to_global(Vector3(0.4, 0.05, 0.7)))
	q.crew = "june"
	r.crew = "marcus"
	var hows := []
	stall.released_by.connect(func(how): hows.append(how))
	stall.stall_ride(0, 1, 0.1)
	for i in 120:
		if stall.stalled:
			break
		await frames(1)
	await frames(3)
	check(stall.stalled and doors.enabled and not shape.disabled and not climb.active, "stuck: the doors can be gripped; the hatch is still shut")
	p.controls.jump = true
	await frames(60)
	var shut_ok := p.global_position.y < 0.3
	stall.hatch._open(0)
	await frames(2)
	var roof := lift.global_position.y + Elevator.SIZE.y
	var up := false
	for i in 3:
		p.controls.jump = true
		for f in 60:
			await frames(1)
			if p.state == Player.Move.WALK and p.is_on_floor() and p.global_position.y > roof:
				up = true
				break
		if up:
			break
	check(shut_ok and climb.active and up, "shut, a jump goes nowhere; pushed open, you're up through it onto the car's roof (y %.2f)" % p.global_position.y)
	q.controls.use = true
	doors.grips[0].interact(q)
	r.controls.use = true
	doors.grips[1].interact(r)
	for f in int(PryDoors.PRY_TIME * 60) + 60:
		await frames(1)
		if not hows.is_empty():
			break
	check(doors.opened and hows == ["pry"], "June and Marcus pull the doors apart, and that's the way out")
	for i in 60:
		if not stall.stalled:
			break
		await frames(1)
	await frames(3)
	check(not stall.stalled and not climb.active and shape.disabled and q.gripping == null, "moving again: the grips and the climb are gone, and nobody's left holding on")
	await done(a)


## Crawl `p` toward `to` (flat), face first; true once there.
func _crawl_to(p: Player, to: Vector3, seconds: float = 8.0) -> bool:
	for i in int(seconds * 60):
		var d := to - p.global_position
		d.y = 0.0
		if d.length() < 0.2:
			p.controls.move = Vector2.ZERO
			return true
		p.rotation.y = atan2(-d.x, -d.z)
		p.controls.crouch = true
		p.controls.move = Vector2(0, -1)
		await frames(1)
	p.controls.move = Vector2.ZERO
	return false


## E10: a duct network. Runs join at turns and T-junctions with no wall across the
## joint; outside corners and dead ends are shut; every body crawls it.
func test_ducts() -> void:
	print("Movement: duct networks")
	for big in [false, true]:
		var a := arena()
		var runs := [
			[Vector3(0, 0, -2), Vector3(6, 0, -2)],
			[Vector3(6, 0, -2), Vector3(6, 0, -8)],  # an L turn
			[Vector3(3, 0, -2), Vector3(3, 0, 2)],  # a T off the first run
		]
		var vols := Traversal.ducts(a, runs, Vector2(1.0, 1.0), [Vector3(0, 0, -2)])
		var p := spawn(a, Vector3(-1.5, 0.05, -2)) if not big else _spawn_sized(a, Vector3(-1.5, 0.05, -2), CrewBody.largest())
		await frames(10)
		var name := "largest body" if big else "standard body"
		var ok := await _crawl_to(p, Vector3(1.0, 0, -2))
		ok = ok and await _crawl_to(p, Vector3(6, 0, -2))
		ok = ok and await _crawl_to(p, Vector3(6, 0, -7.6))
		check(ok and vols.size() == 3 and p.crawling, "%s: in at the open end and round the turn to the far end, crawling (%.1f, %.1f)" % [name, p.global_position.x, p.global_position.z])
		ok = await _crawl_to(p, Vector3(6, 0, -2))
		ok = ok and await _crawl_to(p, Vector3(3, 0, -2))
		ok = ok and await _crawl_to(p, Vector3(3, 0, 1.6))
		check(ok, "%s: back, and into the T's branch" % name)
		if not big:
			var space := a.get_world_3d().direct_space_state
			var ray := func(from: Vector3, to: Vector3) -> bool:
				return not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to)).is_empty()
			check(ray.call(Vector3(6, 0.5, -2), Vector3(7.5, 0.5, -0.5)) and ray.call(Vector3(6, 0.5, -2), Vector3(7.5, 0.5, -2)), "the turn's outside corner is shut")
			check(ray.call(Vector3(6, 0.5, -7), Vector3(6, 0.5, -9)) and ray.call(Vector3(3, 0.5, 1), Vector3(3, 0.5, 3)), "dead ends are capped")
			check(ray.call(Vector3(1.5, 0.5, -2), Vector3(1.5, 0.5, -0.5)) and not ray.call(Vector3(3, 0.5, -2.3), Vector3(3, 0.5, 0)), "the run's side is a wall, except where the T joins it")
			check(not ray.call(Vector3(-1, 0.5, -2), Vector3(1, 0.5, -2)), "the open end is open")
		await done(a)


## E10's ways in and out: a floor vent (its grille unscrewed) dropped into and
## climbed out of, a ceiling vent jumped up into, and a drop down a shaft and back
## up its rungs.
func test_vent_entries() -> void:
	print("Movement: into and out of the ducts")
	for big in [false, true]:
		var a := arena()
		var name := "largest body" if big else "standard body"
		# A duct under a raised floor (its top 1.1 m up), with a floor vent at x 11.
		Traversal.ducts(a, [[Vector3(10, 0, 0), Vector3(16, 0, 0)]], Vector2(1.0, 1.0), [], [Vector3(11, 1.0, 0)])
		for slab in [[Vector3(9.75, 1.05, 0), Vector3(1.5, 0.1, 4)], [Vector3(14.0, 1.05, 0), Vector3(5.0, 0.1, 4)], [Vector3(11, 1.05, 1.25), Vector3(1, 0.1, 1.5)], [Vector3(11, 1.05, -1.25), Vector3(1, 0.1, 1.5)]]:
			Greybox.box(a, slab[0], slab[1], Color.GRAY, "RaisedFloor")
		var grille := VentGrille.place(a, "test", Vector3(11, 1.12, 0), Vector3.UP, Vector2(1.0, 1.0), VentGrille.SCREWDRIVER, VentGrille.UNSCREW, "", Vector3(11, 1.1, 1.2))
		var out := grille.climb_out
		var shut_climb := not out.active
		var p := spawn(a, Vector3(11, 1.15, 1.2)) if not big else _spawn_sized(a, Vector3(11, 1.15, 1.2), CrewBody.largest())
		p.rotation.y = 0.0  # facing -z, at the grille
		await frames(15)
		var shut: String = grille.get_prompt(p)
		await _crawl_to(p, Vector3(11, 0, 0.0), 1.0)
		p.controls.crouch = false
		await frames(30)
		var held_up := p.global_position.y > 1.0
		p.inventory.add(VentGrille.SCREWDRIVER)
		var can: String = grille.get_prompt(p)
		grille.interact(p)
		await frames(5)
		await _crawl_to(p, Vector3(11, 0, 0), 3.0)
		if not big:
			check(shut == VentGrille.SCREWED and can == "[E] " + VentGrille.UNSCREW and held_up and shut_climb, "a floor vent's grille is screwed shut, and holds you; with the screwdriver, unscrew it")
		var t := 0
		while p.global_position.y > 0.3 and t < 120:
			await frames(1)
			t += 1
		var fell := p.global_position.y < 0.3
		var ok := await _crawl_to(p, Vector3(15, 0, 0))
		check(grille.is_open and fell and ok, "%s: off, you drop through into the duct and crawl along it (open %s, fell %s, at %s)" % [name, grille.is_open, fell, p.global_position])
		ok = await _crawl_to(p, Vector3(11, 0, 0))
		p.controls.crouch = false
		var up := false
		for i in 3:
			p.controls.jump = true
			for f in 60:
				await frames(1)
				if p.state == Player.Move.WALK and p.global_position.y > 1.05:
					up = true
					break
			if up:
				break
		check(ok and fell and up and out.active, "%s: back under it, Space climbs you out (y %.2f)" % [name, p.global_position.y])
		await done(a)
		# A duct up at 2.6 m, over open floor: a ceiling vent at x 3, and at x 7 a
		# drop back down a shaft to the floor.
		a = arena()
		Traversal.ducts(a, [[Vector3(2, 2.6, 0), Vector3(8, 2.6, 0)]], Vector2(1.0, 1.0), [], [Vector3(3, 2.6, 0), Vector3(7, 2.6, 0)])
		Traversal.hatch(a, Vector3(3, 2.61, 0), Vector2(1.0, 1.0), Vector3(4.2, 2.61, 0))
		var rungs := Traversal.drop(a, Vector3(7, 2.6, 0), 2.6, Vector3.LEFT)
		p = spawn(a, Vector3(3, 0.05, 0)) if not big else _spawn_sized(a, Vector3(3, 0.05, 0), CrewBody.largest())
		await frames(15)
		up = false
		for i in 3:
			p.controls.jump = true
			for f in 90:
				await frames(1)
				if p.state == Player.Move.WALK and p.global_position.y > 2.5:
					up = true
					break
			if up:
				break
		check(up and p.crawling, "%s: jump at a ceiling vent, catch its rim and pull up into the duct (y %.2f)" % [name, p.global_position.y])
		ok = await _crawl_to(p, Vector3(7, 0, 0))
		t = 0
		while p.global_position.y > 0.3 and t < 120:
			await frames(1)
			t += 1
			if p.state == Player.Move.HANG:
				p.controls.move = Vector2(0, 1)  # caught the far edge: let go
		p.controls.move = Vector2.ZERO
		check(ok and p.global_position.y < 0.3, "%s: crawl over the drop and down the shaft you go (%s, at %s)" % [name, ok, p.global_position])
		p.controls.crouch = false
		p.rotation.y = atan2(1.0, 0.0)  # facing -x, the rungs
		await frames(20)
		var climbed := false
		p.controls.move = Vector2(0, -1)
		p.controls.jump = true
		for f in 300:
			await frames(1)
			if p.state == Player.Move.WALK and p.global_position.y > 2.5:
				climbed = true
				break
		p.controls.move = Vector2.ZERO
		check(climbed and rungs != null, "%s: and back up its rungs, out onto the duct's floor (y %.2f)" % [name, p.global_position.y])
		await done(a)


## E10's grilles from inside the duct: a screwed one stays shut from there (its
## screws are on the room side); one that lifts out pushes up from underneath.
func test_grille_sides() -> void:
	print("Movement: vent grilles from inside the duct")
	var a := arena()
	Traversal.ducts(a, [[Vector3(10, 0, 0), Vector3(16, 0, 0)]], Vector2(1.0, 1.0), [Vector3(10, 0, 0)], [Vector3(12, 1.0, 0), Vector3(14, 1.0, 0)])
	for slab in [[Vector3(11.25, 1.05, 0), Vector3(1.5, 0.1, 4)], [Vector3(13, 1.05, 0), Vector3(1, 0.1, 4)], [Vector3(15.25, 1.05, 0), Vector3(1.5, 0.1, 4)], [Vector3(13, 1.05, 1.25), Vector3(4, 0.1, 1.5)], [Vector3(13, 1.05, -1.25), Vector3(4, 0.1, 1.5)]]:
		Greybox.box(a, slab[0], slab[1], Color.GRAY, "RaisedFloor")
	var screwed := VentGrille.place(a, "screwed", Vector3(12, 1.12, 0), Vector3.UP, Vector2(1.0, 1.0), VentGrille.SCREWDRIVER, VentGrille.UNSCREW, "", Vector3(12, 1.1, 1.2))
	var loose := VentGrille.place(a, "loose", Vector3(14, 1.12, 0), Vector3.UP, Vector2(1.0, 1.0), "", "Lift the grille out", "Push the grille up", Vector3(14, 1.1, 1.2))
	var p := spawn(a, Vector3(8.5, 0.05, 0))
	p.inventory.add(VentGrille.SCREWDRIVER)
	await frames(10)
	await _crawl_to(p, Vector3(12, 0, 0))
	await frames(5)
	var said: String = screwed.get_prompt(p)
	screwed.interact(p)
	await frames(5)
	check(said == VentGrille.SCREWED and not screwed.is_open, "under a screwed grille, screwdriver or not: it's screwed shut from in here")
	await _crawl_to(p, Vector3(14, 0, 0))
	await frames(5)
	said = loose.get_prompt(p)
	loose.interact(p)
	await frames(5)
	check(said == "[E] Push the grille up" and loose.is_open and loose.climb_out.active, "under one that lifts out: push it up")
	p.controls.crouch = false
	var up := false
	for i in 3:
		p.controls.jump = true
		for f in 60:
			await frames(1)
			if p.state == Player.Move.WALK and p.global_position.y > 1.05:
				up = true
				break
		if up:
			break
	check(up, "and climb out through it (y %.2f)" % p.global_position.y)
	var room := spawn(a, Vector3(12, 1.15, 1.2))
	room.inventory.add(VentGrille.SCREWDRIVER)
	await frames(10)
	check(screwed.get_prompt(room) == "[E] " + VentGrille.UNSCREW, "from the room, the same screwed grille unscrews")
	await done(a)


## E10: a ceiling vent too high to jump to (3.5 m), by a wall: a braced teammate's
## leg-up takes you up through it, once it's open.
func test_leg_up_hatch() -> void:
	print("Movement: a leg-up into a ceiling vent")
	var a := arena()
	_high_wall(a, 4.5)  # face at z = -2, nothing to catch on top
	Traversal.ducts(a, [[Vector3(-3, 3.5, -1.5), Vector3(3, 3.5, -1.5)]], Vector2(1.0, 1.0), [], [Vector3(0, 3.5, -1.5)])
	var vol := Traversal.hatch(a, Vector3(0, 3.51, -1.5), Vector2(1.0, 1.0), Vector3(1.2, 3.51, -1.5))
	vol.active = false
	var base := spawn(a, Vector3(0, 0.05, -1.55))
	var climber := spawn(a, Vector3(0, 0.05, -0.5))
	base.controls.crouch = true
	await frames(15)
	var shut := base.get_prompt(climber)
	vol.active = true
	var open := base.get_prompt(climber)
	check(shut == "" and open == Player.LEG_UP_PROMPT, "shut, nothing to give a leg-up to; open, a leg-up")
	base.interact(climber)
	var up := false
	for i in 180:
		await frames(1)
		if climber.state == Player.Move.WALK and climber.global_position.y > 3.4:
			up = true
			break
	check(up and climber.crawling, "up off them and through it, into the duct (y %.2f)" % climber.global_position.y)
	stop(base)
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

	# Floor 14's lift (Augustine, v0.9-beta2: "players can clip through the elevator"):
	# a shoulder stand put the rider's head through the car's roof, and stepping down
	# behind a teammate with their back to the wall put you through the wall.
	a = arena()
	var car := Elevator.create(a, a, Vector3.ZERO, 0.0, "14")
	car.open(true)
	base = spawn(a, car.to_global(Vector3(0, 0.05, 1.2)))
	climber = spawn(a, car.to_global(Vector3(0.7, 0.05, 1.2)))
	await frames(10)
	check(not base.can_carry(climber) and base.get_prompt(climber) == "", "no shoulder stand inside a lift car: no room over their shoulders")
	await done(a)

	a = arena()
	Greybox.box(a, Vector3(0, 1.5, 0.05), Vector3(6, 3, 0.1), Color.DIM_GRAY)  # a thin wall at z = 0
	base = spawn(a, Vector3(0, 0.05, -0.45))  # back to the wall, facing -Z
	climber = spawn(a, Vector3(0, 0.05, -1.4))
	await frames(10)
	base.interact(climber)
	await frames(5)
	climber.controls.crouch = true
	await frames(10)
	climber.controls.crouch = false
	await frames(10)
	check(climber.state == Player.Move.WALK and climber.global_position.z < 0.0, "stepping down with their back to a wall puts you beside them, not through it (z %.2f)" % climber.global_position.z)
	await done(a)

	a = arena()
	Greybox.box(a, Vector3(0, 3.0, -4.0), Vector3(6, 0.2, 4), Color.DIM_GRAY)  # a ceiling 2.9 m up, from z -2 to -6
	base = spawn(a, Vector3(0, 0.05, 0))
	climber = spawn(a, Vector3(0, 0.05, 1))
	await frames(10)
	base.interact(climber)
	forward(base)
	var highest := 0.0
	for i in 240:
		await frames(1)
		if climber.global_position.z < -2.0 - climber.body.radius:  # under it
			highest = maxf(highest, climber.global_position.y + climber.stance_height)
		if base.global_position.z < -3.5:
			break
	stop(base)
	check(highest < 2.9 + 0.05 and base.global_position.z < -3.5, "carried under a low ceiling, the rider ducks or steps down, never through it (top %.2f m)" % highest)
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
	p.camera.add_child(book)
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
	var screen := Vector2(1920, 1080)
	check(p.edge_turn(screen / 2, screen) == Vector2.ZERO and p.edge_turn(Vector2(900, 300), screen) == Vector2.ZERO, "with the cursor over the page the view holds still")
	var full := Player.EDGE_LOOK_SPEED * 0.9
	check(p.edge_turn(Vector2(2, 540), screen).x < -full and p.edge_turn(Vector2(1917, 540), screen).x > full, "the cursor at the left or right edge turns your view that way")
	check(p.edge_turn(Vector2(960, 1078), screen).y > full and p.edge_turn(Vector2(960, 3), screen).y < -full, "and at the top or bottom edge, up or down")
	check(Player.EDGE_LOOK_SPEED <= 1.0 and Player.NOTEBOOK_LOOK_SCALE <= 0.3, "reading, the view turns gently (playtest v0.7: it was too sensitive)")
	var slight := p.edge_turn(Vector2(screen.x * Player.EDGE_LOOK_MARGIN * 0.8, 540), screen).x
	check(slight < 0.0 and slight > -0.2, "just inside the edge zone it turns slowly")
	check(p.edge_turn(Vector2(-5, 540), screen) == Vector2.ZERO, "and off the window it doesn't turn at all")
	var on_screen := Rect2(400, 100, 1100, 900)  # the notebook and its tabs on screen
	check(p.edge_turn(Vector2(1490, 300), screen, on_screen) == Vector2.ZERO and p.edge_turn(Vector2(1508, 300), screen, on_screen) == Vector2.ZERO, "over the notebook, its tabs included, the view holds still")
	check(p.edge_turn(Vector2(1600, 300), screen, on_screen).x > 0.0 and p.edge_turn(Vector2(1910, 300), screen, on_screen).x > full * 0.8, "off the notebook it starts turning, fastest at the screen's edge")
	check(p.edge_turn(Vector2(300, 540), screen, on_screen).x < 0.0, "and off its left side, the other way")
	p.local_control = true
	check(p._wants_cursor(), "reading, the cursor is always out: no button puts it away to look around")
	p.local_control = false
	p.set_notebook_cursor(false)  # the cursor away (a remote copy, or a scripted look)
	var yaw0 := p.rotation.y
	var book_at := book.global_basis
	var cam_at := p.camera.global_basis
	_mouse_move(p, Vector2(100, 0))
	var turned := yaw0 - p.rotation.y
	check(p.is_holding_notebook() and not p.notebook_cursor and absf(turned - 100 * Player.MOUSE_SENS * Player.NOTEBOOK_LOOK_SCALE) < 0.001, "reading, the mouse still looks around, slower")
	check(not book.is_processing_input(), "and the pages ignore the mouse while it's looking")
	check(book.global_basis.is_equal_approx(book_at) and (-p.camera.global_basis.z).dot(-cam_at.z) < 0.999, "glancing across the spread, the book stays put while your view moves")
	_mouse_move(p, Vector2(0, 225))
	check(book.global_basis.is_equal_approx(book_at) and p.notebook_drift.y < -0.1, "and looking down the page, too")
	_mouse_move(p, Vector2(600, 0))
	var off := (-book.global_basis.z).signed_angle_to(-book_at.z, Vector3.UP)
	check(absf(p.notebook_drift.x + Player.NOTEBOOK_SLACK_SIDE) < 0.001 and off > 0.2, "look further and it comes with you (%.2f rad)" % off)
	var in_view := p.camera.global_basis.inverse() * (-book.global_basis.z)
	check(in_view.z < -0.95, "so it stays in front of you")
	p.toggle_notebook()
	await frames(40)
	p.toggle_notebook()
	p.set_notebook_cursor(false)
	check(p.notebook_drift == Vector2.ZERO and book.transform.is_equal_approx(Transform3D.IDENTITY), "out again, it comes up square in front of you")
	await frames(40)
	events.clear()
	book.calls.clear()
	p.set_notebook_cursor(true)
	yaw0 = p.rotation.y
	_mouse_move(p, Vector2(100, 40))
	check(p.notebook_cursor and p.rotation.y == yaw0 and book.is_processing_input(), "with the cursor out the pages take the mouse and the view holds still")
	p.set_notebook_cursor(false)
	_mouse_move(p, Vector2(100, 0))
	check(p.rotation.y < yaw0 and not book.is_processing_input(), "with the cursor away the mouse looks around again")
	p.set_notebook_cursor(true)
	p.toggle_notebook()
	check(not p.notebook_cursor, "putting the notebook away drops the cursor")
	await frames(40)
	check(not p.is_holding_notebook() and events == ["lowered"] and book.calls == ["close"], "Tab again puts it away")
	p.held_notebook = null
	book.free()
	p.rotation.y = 0.0
	p.global_position = Vector3(0, 0.05, -1.3)
	await frames(5)
	p.raise_notebook()
	p.controls.jump = true
	await frames(3)
	check(p.state == Player.Move.WALK, "holding the notebook, Space doesn't grab edges either")
	p.lower_notebook()
	await frames(30)
	p.controls.move = Vector2(0, -0.5)
	p.controls.jump = true
	await frames(3)
	p.controls.move = Vector2.ZERO
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
	var screen_at := term.focus_point.global_position
	var look_at_screen := func() -> float:
		var c: Transform3D = p.camera.global_transform
		return (-c.basis.z).dot((screen_at - c.origin).normalized())
	var looked_before: float = look_at_screen.call()
	await frames(Player.TERMINAL_STEP_TIME * 30)
	check(look_at_screen.call() > looked_before + 0.2 and p.terminal_amount < 1.0, "your eyes turn onto the screen as you step up (%.2f to %.2f)" % [looked_before, look_at_screen.call()])
	await frames(Player.TERMINAL_STEP_TIME * 30 + 2)
	check(look_at_screen.call() > 0.999, "and are on it by the time you get there, before the camera moves in")
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
	check(look_at_screen.call() > 0.99, "still looking at the screen, so nothing snaps")
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
	p.set_notebook_cursor(false)  # right mouse held: look around
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
	var in_view := p.camera.global_basis.inverse() * (paper.global_position - p.camera.global_position)
	check(p.notebook_drift.x != 0.0 and in_view.x < -0.01, "glancing aside, the paper stays put a moment, like the notebook")
	p.set_notebook_cursor(true)
	check(p.notebook_cursor and paper.is_processing_input(), "letting go of right mouse brings the cursor back for its lines")
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
	check(p.filing_note() != null and p.filing_progress() == 0.0, "the hands can follow the note in yours")
	await frames(int(Player.NOTEBOOK_RAISE_TIME * 60) + 10)
	check(p.filing_progress() > 0.0 and p.filing_progress() < 1.0, "and how far it is into the book (%.2f)" % p.filing_progress())
	await frames(int(Player.FILE_TIME * 60))
	check(filed == [note] and not p.is_filing(), "then goes onto the page, and says so")
	await frames(2)
	check(p.camera.get_child_count() == kids, "the note in your hand is gone into the book")
	check(p.is_holding_notebook(), "and the notebook stays open to see it")
	var stuck := _paper(a, Vector3(-0.2, 1.2, -0.8), false)
	check(p.file_into_notebook(stuck, true) and stuck.visible, "copying a note stuck to a terminal leaves it there")
	await frames(int(Player.FILE_TIME * 60) + 10)
	check(filed.size() == 2 and filed[1] == stuck, "and a copy goes in the notebook")
	await frames(2)
	var gone := _paper(a, Vector3(0.0, 1.2, -0.8), false)
	check(p.file_into_notebook(gone), "filing another note")
	await frames(5)
	gone.free()  # cleared by the level, or a teammate took it, while it travels
	await frames(int(Player.FILE_TIME * 60) + 10)
	check(not p.is_filing() and p.filing_note() == null and filed.size() == 2, "a note that disappears mid-file just stops, with nothing filed")
	await frames(2)
	check(p.camera.get_child_count() == kids, "and the copy in your hand goes too")
	p.held_notebook = null
	book.free()
	await done(a)


## A mouse movement as the local player gets it.
func test_inventory() -> void:
	var inv := Inventory.new()
	check(inv.items == Array(["notebook", "flashlight"], TYPE_STRING, "", null) and inv.hotbar.all(func(i): return i == ""), "you start with the notebook and flashlight, and an empty hotbar")
	check(inv.add("radio") and inv.hotbar[0] == "radio", "a pickup fills the first empty hotbar slot")
	check(not inv.add("radio") and inv.items.count("radio") == 1, "picking up something you have does nothing")
	check(not inv.add("notebook") and not inv.hotbar.has("notebook"), "the notebook and flashlight never go on the hotbar")
	inv.add("screwdriver")
	inv.add("cable")
	inv.add("keycard")
	check(inv.hotbar == Array(["radio", "screwdriver", "cable", "keycard"], TYPE_STRING, "", null), "four items fill the four slots in order")
	inv.add("first_aid_kit")
	check(inv.has("first_aid_kit") and not inv.hotbar.has("first_aid_kit") and inv.stowed() == Array(["first_aid_kit"], TYPE_STRING, "", null), "a fifth goes in the bag, not over another slot")
	inv.use_slot(1)
	check(inv.active_item() == "screwdriver", "1-4 take out what's in that slot")
	inv.assign(3, "screwdriver")
	check(inv.hotbar[3] == "screwdriver" and inv.hotbar[1] == "keycard" and inv.active_item() == "screwdriver", "moving an item to another slot swaps them, and it stays in your hands")
	inv.assign(0, "first_aid_kit")
	check(inv.hotbar[0] == "first_aid_kit" and inv.stowed().has("radio"), "putting a bag item on a full slot sends that slot's item to the bag")
	inv.assign(3, "")
	check(inv.hotbar[3] == "" and inv.active_item() == "" and inv.stowed().has("screwdriver"), "taking what you hold off the hotbar puts it away")
	check(not inv.assign(2, "flashlight") and not inv.assign(2, "crowbar") and not inv.assign(7, "radio"), "nothing fixed, missing or out of range goes on the bar")
	inv.use_slot(0)
	inv.use_slot(0)
	check(inv.active_item() == "", "pressing the same key again puts it away")
	inv.use_slot(3)
	check(inv.active_item() == "", "an empty slot leaves your hands empty")
	inv.remove("first_aid_kit")
	check(not inv.has("first_aid_kit") and inv.hotbar[0] == "", "using up an item frees its slot")
	var copy := Inventory.new()
	copy.load_dict(inv.to_dict())
	check(copy.items == inv.items and copy.hotbar == inv.hotbar, "an inventory saves and loads")
	check(not inv.add_for_peer("crowbar", 2, 1) and inv.add_for_peer("crowbar", 1, 1), "a pickup played out on every machine only lands in the taker's inventory")
	inv.clear()
	check(inv.items.size() == 2 and inv.hotbar.all(func(i): return i == ""), "a new run starts empty-handed")
	for id in ["floppy_disk", "stair_key"]:
		check(Inventory.ITEMS.has(id) and Inventory.ITEMS[id].get("about", "") != "", "floor 18's %s has a name and a line about it" % id)
	check(Inventory.item_name("floppy_disk") == "Floppy disk" and Inventory.item_name("stair_key") == "Key ring", "floor 18's pickups show their own names")
	check(inv.add("floppy_disk") and inv.add("stair_key") and inv.hotbar[0] == "floppy_disk" and inv.hotbar[1] == "stair_key", "the floppy and the key ring go on the hotbar")
	inv.clear()


func test_hotbar_keys() -> void:
	var a := arena()
	var p := spawn(a, Vector3(0, 0.05, 0))
	await frames(20)
	p.inventory.add("radio")
	p.inventory.add("screwdriver")
	var picked := []
	p.inventory.selected.connect(func(i): picked.append(i))
	_key(p, KEY_2)
	check(p.inventory.active_item() == "screwdriver" and picked == ["screwdriver"], "2 takes out the screwdriver")
	_key(p, KEY_1)
	check(p.inventory.active_item() == "radio", "1 swaps to the walkie-talkie")
	var flashlight_on := p.flashlight.visible
	_key(p, KEY_F)
	check(p.flashlight.visible != flashlight_on and p.inventory.active_item() == "radio", "F is still the flashlight, whatever's in your hands")
	p.raise_notebook()
	_key(p, KEY_2)
	check(p.inventory.active_item() == "radio", "reading the notebook, 1-4 are its tabs, not the hotbar")
	p.lower_notebook(true)
	p.input_locked = true
	_key(p, KEY_2)
	check(p.inventory.active_item() == "radio", "nor in a menu")
	p.input_locked = false
	await done(a)


func test_inventory_screen() -> void:
	var a := arena()
	var p := spawn(a, Vector3(0, 0.05, 0))
	await frames(20)
	var screen := InventoryScreen.create(a, p, null)
	await t.process_frame
	p.inventory.add("radio")
	p.inventory.add("screwdriver")
	p.inventory.add("cable")
	p.inventory.add("keycard")
	p.inventory.add("first_aid_kit")
	check(screen._bar.visible, "the hotbar is on screen")
	var stand := Node3D.new()
	a.add_child(stand)
	p.use_terminal(stand, null)
	await t.process_frame
	check(not screen._bar.visible, "and steps aside while you're at a terminal")
	p.leave_terminal()
	await frames(40)
	await t.process_frame
	check(screen._bar.visible and not p.is_using_terminal(), "then comes back")
	check(screen.open() and screen.is_open() and p.input_locked, "I opens the inventory, and you stop walking around")
	screen.pick("first_aid_kit")
	screen.choose_slot(1)
	check(p.inventory.hotbar[1] == "first_aid_kit" and p.inventory.stowed().has("screwdriver") and screen.picked == "", "click a bag item, then a slot, to put it on the hotbar")
	screen.choose_slot(0)
	check(screen.picked == "radio", "clicking a filled slot picks up its item")
	screen.choose_slot(3)
	check(p.inventory.hotbar[3] == "radio" and p.inventory.hotbar[0] == "keycard", "and clicking another slot swaps them")
	screen.pick("cable")
	screen.stow_picked()
	check(not p.inventory.hotbar.has("cable") and p.inventory.has("cable"), "an item can come off the hotbar into the bag")
	screen.pick("cable")
	p.local_control = true
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_3
	ev.pressed = true
	screen._unhandled_input(ev)
	p.local_control = false
	check(p.inventory.hotbar[2] == "cable", "or press 1-4 to drop the picked item in that slot")
	screen.close()
	check(not screen.is_open() and not p.input_locked, "I again closes it")
	p.raise_notebook()
	check(not screen.open(), "it doesn't open over the notebook")
	p.lower_notebook(true)
	screen.queue_free()
	await done(a)


## A key press as the local player gets it.
func _key(p: Player, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.pressed = true
	p.local_control = true
	p._unhandled_input(ev)
	p.local_control = false


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


func test_sit() -> void:
	var a := arena()
	Greybox.box(a, Vector3(0, 0.225, -1.5), Vector3(0.5, 0.45, 0.5), Color.DIM_GRAY, "Chair")
	var chair := Seat.create_at(a, Vector3(0, 0.45, -1.5), PI)  # faces +Z, toward the player
	var p := spawn(a, Vector3(0, 0.05, 0))
	var q := spawn(a, Vector3(2, 0.05, 0))
	await frames(20)
	var stood := p.global_position
	var stood_yaw := p.rotation.y
	var eyes := p.camera.global_position.y
	var settle := int(Player.SIT_TIME * 60) + 10
	p.controls.sit = true
	await frames(2)
	check(p.is_sitting() and p.seat == null, "Z sits you down on the floor")
	await frames(settle)
	check(p.camera.global_position.y < eyes - 0.8 and p.global_position.distance_to(stood) < 0.05, "down low, right where you were")
	forward(p)
	p.controls.sprint = true
	await frames(20)
	stop(p)
	check(p.is_sitting() and p.global_position.distance_to(stood) < 0.05, "W doesn't walk you off: you're sitting")
	p._turn_view(5.0, 0.0)
	await frames(5)
	check(absf(angle_difference(stood_yaw - 5.0, p.rotation.y)) < 0.001, "on the floor you turn your whole body")
	check(p.raise_notebook() and p.is_sitting(), "you can read your notebook sitting down")
	p.lower_notebook(true)
	p.controls.jump = true
	await frames(settle + 20)  # up, then the view eases back to standing height
	check(not p.is_sitting() and p.stance_height == Player.STAND_HEIGHT and absf(p.camera.global_position.y - eyes) < 0.05, "Space stands you up")

	check(chair.get_prompt(p) == "[E] Sit down", "a chair says E to sit")
	chair.interact(p)
	await frames(settle)
	check(p.is_sitting() and p.seat == chair and p.global_position.distance_to(Vector3(0, 0.45, -1.5)) < 0.02, "E at a chair sits you on it")
	check((-p.global_basis.z).dot(Vector3.BACK) > 0.99, "facing the way the chair faces")
	check(absf(p.camera.global_position.y - (0.45 + Player.SIT_HEIGHT - 0.12)) < 0.05, "eyes at sitting height")
	check(not chair.is_free(q) and chair.get_prompt(q) == "" and not q.sit(chair), "one to a chair")
	p._turn_view(1.0, -0.6)
	await frames(10)
	check(absf(angle_difference(PI - 1.0, p.rotation.y)) < 0.001 and absf(p.head.rotation.x - 0.6) < 0.001, "sitting on a chair, you can look around and up, and the view stays put")
	p._turn_view(4.0, 3.0)
	await frames(10)
	check(absf(angle_difference(PI, p.rotation.y)) <= Player.SIT_LOOK + 0.001, "you can look around, but not turn your back on the desk")
	check(absf(p.head.rotation.x + Player.SIT_LOOK_DOWN) < 0.001, "and only as far down as a seated person can")
	p._turn_view(0.0, -10.0)
	check(absf(p.head.rotation.x - Player.SIT_LOOK_UP) < 0.001, "or as far up")
	p._turn_view(-8.0, 0.0)
	check(absf(angle_difference(PI + Player.SIT_LOOK, p.rotation.y)) < 0.001, "turning hard the other way stops at the same limit")
	p._turn_view(Player.SIT_LOOK - 0.3, 0.0)  # back round to a little left of the chair's facing
	var yaw := p.rotation.y
	var facing := Vector3(-sin(yaw), 0, -cos(yaw))
	var out := Vector3(0, stood.y, -1.5) + facing * Player.SIT_STEP_OUT
	p.controls.sit = true
	await frames(settle)
	check(not p.is_sitting() and chair.is_free(q), "Z gets you up and frees the chair")
	check(p.global_position.distance_to(out) < 0.05 and absf(angle_difference(yaw, p.rotation.y)) < 0.001, "stepping off the way you're facing, still facing it")
	chair.interact(p)
	await frames(settle)
	Greybox.box(a, Vector3(0, 1, -0.6), Vector3(2, 2, 0.2), Color.DIM_GRAY, "Desk")  # right in front of the chair
	p.controls.sit = true
	await frames(settle)
	check(not p.is_sitting() and p.global_position.distance_to(out) < 0.05, "boxed in that way, you get up where you came from")

	p.rotation.y = 0.5
	p.seated = true
	p._turn_view(4.0, 3.0)
	check(absf(angle_difference(0.5, p.rotation.y)) <= Player.SIT_LOOK + 0.001 and absf(p.head.rotation.x + Player.SIT_LOOK_DOWN) < 0.001, "strapped into a van seat, you look around like on a chair")
	p.seated = false
	p._turn_view(0.0, 3.0)
	check(p.head.rotation.x < -Player.SIT_LOOK_DOWN - 0.1, "unbuckled, the full range is back")
	p._turn_view(0.0, -3.0)
	p.controls.jump = true
	await frames(3)
	check(not p.sit(), "you can't sit in mid-air")
	await frames(40)
	chair.interact(p)
	await frames(settle)
	p.respawn(Transform3D(Basis(), Vector3(3, 0.05, 2)))
	check(not p.is_sitting() and p.global_position.distance_to(Vector3(3, 0.05, 2)) < 0.01 and chair.is_free(q), "respawning gets you up and frees the chair")
	await frames(20)
	chair.interact(p)
	await frames(settle)
	p.sit_held = true  # belted in
	p.controls.jump = true
	await frames(5)
	p.controls.sit = true
	await frames(settle)
	check(p.is_sitting() and p.seat == chair, "belted in, Space and Z don't stand you up")
	p.sit_held = false  # unbuckled
	p.controls.jump = true
	await frames(settle + 5)
	check(not p.is_sitting(), "unbuckled, Space stands you up again")
	var air := Seat.create_at(a, Vector3(-3, 0.45, 2), PI)
	p.global_position = Vector3(-3, 1.6, 2)
	await frames(2)
	check(not p.is_on_floor() and p.sit(air) and p.seat == air, "a chair catches you even off the floor (the van at the start)")
	p.sit_held = true
	p.respawn(Transform3D(Basis(), Vector3(3, 0.05, 2)))
	check(not p.is_sitting() and not p.sit_held, "respawning gets you out of a belt too")
	await done(a)


func test_stamina() -> void:
	var a := arena()
	var p := spawn(a, Vector3(0, 0.05, 10))
	await frames(20)
	check(p.stamina == Player.STAMINA_MAX and not p.winded, "you start fresh")
	forward(p, true)
	await frames(60)
	stop(p)
	var after_run := p.stamina
	check(after_run < Player.STAMINA_MAX - 10.0, "sprinting tires you (%.0f left)" % after_run)
	await frames(90)
	check(p.stamina >= minf(after_run + 30.0, Player.STAMINA_MAX), "standing still, you get your breath back quickly")
	p.restore_stamina(Player.STAMINA_MAX)
	p.controls.jump = true
	await frames(5)
	check(absf(p.stamina - (Player.STAMINA_MAX - Player.JUMP_COST)) < 0.5, "a jump costs a little")
	await frames(60)
	p.spend_stamina(Player.STAMINA_MAX * 2.0)
	check(p.winded and p.stamina == 0.0, "run it dry and you're winded")
	var z0 := p.global_position.z
	forward(p, true)
	await frames(30)
	var pace := (z0 - p.global_position.z) / 0.5
	stop(p)
	check(pace < Player.WALK_SPEED + 0.2, "or sprint (%.1f m/s)" % pace)
	p.controls.jump = true
	await frames(5)
	check(p.velocity.y > 0.0 or not p.is_on_floor(), "but you can still jump: being winded never stops you")
	await frames(120)
	check(not p.winded and p.stamina >= Player.STAMINA_WINDED_UNTIL, "rest a moment and you're over it")
	p.sit()
	var sat := p.stamina
	await frames(60)
	check(p.stamina > sat + 10.0 or p.stamina == Player.STAMINA_MAX, "sitting rests you too")
	await done(a)


func test_knocks() -> void:
	var a := arena()
	var p := spawn(a, Vector3(0, 0.05, 0))
	await frames(20)
	p.sit()
	await frames(5)
	var from := p.global_position
	p.knock_back(Vector3(0, 3, 6))
	check(not p.is_sitting(), "a shove gets you off your seat")
	await frames(20)
	check(p.global_position.z - from.z > 1.0, "and sends you flying")
	await frames(60)
	p.knock_down(0.5)
	check(p.is_down() and p.stance_height == Player.DOWN_HEIGHT, "knocked down, you're on the floor")
	forward(p)
	await frames(10)
	stop(p)
	check(p.is_down(), "and can't walk")
	await frames(40)
	check(not p.is_down() and p.stance_height == Player.STAND_HEIGHT, "then you get up by yourself")
	p.knock_down(INF)
	await frames(90)
	check(p.is_down(), "knocked out, you stay down")
	p.get_up()
	check(not p.is_down() and p.stance_height == Player.STAND_HEIGHT, "until a teammate gets you up")

	var vit := Vitals.create(a, p)
	p.take_damage(25.0)
	p.spend_stamina(50.0)
	await t.process_frame
	await t.process_frame
	check(absf(vit.health_fill() - 0.75) < 0.01 and absf(vit.stamina_fill() - p.stamina / Player.STAMINA_MAX) < 0.01, "the bars show your health and stamina")
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
		p.controls.jump = not vaulted and p.global_position.x > -21.3
		await t.physics_frame
		vaulted = vaulted or p.state == Player.Move.VAULT
	check(vaulted and p.global_position.x > -19.9, "the gym has a desk to vault")
	check(level.find_children("*", "Seat", true, false).size() == 1, "the gym has a chair to sit on")
	level.queue_free()
	await t.process_frame
