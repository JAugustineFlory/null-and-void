extends RefCounted
## The Custodian (Level 4's maintenance robot): it grabs you and drags you to its
## bay; teammates free you by striking it or cutting its power. Co-op, where the
## grab lands on the client's own machine and a client's strike reaches the host,
## is test_coop_custodian in run_tests.gd.

var t: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("Custodian")
	await test_hunt_and_grab()
	await test_struck_free()
	await test_power_cut()
	await test_docked()
	await test_walls_and_wounds()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func arena() -> Node3D:
	var a := Node3D.new()
	t.root.add_child(a)
	Greybox.box(a, Vector3(0, -0.1, 0), Vector3(60, 0.2, 60), Color.GRAY, "Floor")
	return a


func spawn(parent: Node, pos: Vector3) -> Player:
	var p := Player.new()
	p.local_control = false
	p.position = pos
	parent.add_child(p)
	return p


## A Custodian whose bay is at `bay`, facing +Z.
func custodian(parent: Node, at: Vector3, bay: Vector3) -> Custodian:
	var c := Custodian.new()
	c.position = at
	parent.add_child(c)
	c.set_bay(bay)
	return c


func frames(n: int) -> void:
	for i in n:
		await t.physics_frame


func until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await t.physics_frame
	return cond.call()


func done(a: Node) -> void:
	Engine.time_scale = 1.0
	a.queue_free()
	await t.process_frame


func test_hunt_and_grab() -> void:
	var a := arena()
	var c := custodian(a, Vector3(0, 0.1, 0), Vector3(0, 0.1, -10))
	var p := spawn(a, Vector3(0, 0.1, 5))
	await frames(20)
	await frames(60)
	check(c.state == "bay" and c.global_position.distance_to(Vector3(0, 0.1, 0)) < 0.2 and p.combat.grabbed_by == null,
		"in its bay, it doesn't move, even with someone in plain sight")
	var caught := []
	c.caught.connect(func(who): caught.append(who))
	c.activate()
	check(c.is_active() and c.state == "hunting", "let out, it hunts")
	p.combat.raise_guard()
	Engine.time_scale = 3.0
	check(await until(func(): return not caught.is_empty(), 300), "it walks up to someone it can see and grabs them")
	check(caught == [p] and p.combat.grabbed_by == c and p.input_locked, "held, you can't move")
	check(is_equal_approx(p.health, 100.0 - Custodian.GRAB_DAMAGE), "its grab can't be blocked: it hurts")
	var z0 := p.global_position.z
	await frames(60)
	check(c.state == "dragging" and p.global_position.z < z0 - 1.0, "it drags you back toward its bay (%.1f m)" % (z0 - p.global_position.z))
	await done(a)


func test_struck_free() -> void:
	var a := arena()
	var c := custodian(a, Vector3(0, 0.1, 3.8), Vector3(0, 0.1, -20))
	var p := spawn(a, Vector3(0, 0.1, 5))
	var mate := spawn(a, Vector3(2, 0.1, 4))
	await frames(20)
	c.activate()
	check(await until(func(): return c.held != null, 120), "it grabs the nearest one")
	var held: Player = c.held
	var other: Player = mate if held == p else p
	var freed := []
	c.freed.connect(func(who, how): freed.append([who, how]))
	for i in 5:
		c.take_hit(held)
	check(c.held == held and c.strikes == 0, "held, you can't hit it yourself")
	for i in Custodian.STRIKES_TO_FREE - 1:
		c.take_hit(other)
	check(c.held == held and c.state == "dragging", "a strike or two doesn't do it")
	c.take_hit(other)
	check(freed == [[held, "struck"]] and c.held == null and held.combat.grabbed_by == null, "enough strikes from a teammate, and it lets go")
	await frames(3)
	check(not held.input_locked, "free, you have your controls back")
	check(c.state == "stunned", "and it stands shuddering for a moment")
	var at := c.global_position
	await frames(int(Custodian.STUN_TIME * 60 * 0.6))
	check(c.global_position.distance_to(at) < 0.1, "long enough to get away")
	check(await until(func(): return c.state != "stunned", int(Custodian.STUN_TIME * 60)), "then it hunts again")
	await done(a)


func test_power_cut() -> void:
	var a := arena()
	var c := custodian(a, Vector3(0, 0.1, 3.8), Vector3(0, 0.1, -20))
	var p := spawn(a, Vector3(0, 0.1, 5))
	await frames(20)
	c.activate()
	check(await until(func(): return c.held == p, 120), "grabbed")
	var freed := []
	c.freed.connect(func(who, how): freed.append([who, how]))
	c.set_powered(false)
	check(freed == [[p, "power"]] and p.combat.grabbed_by == null, "cut its power by code, and it drops you")
	await frames(3)
	check(not p.input_locked and c.state == "off", "and stands dead")
	var at := c.global_position
	await frames(90)
	check(c.global_position.distance_to(at) < 0.1 and c.held == null, "with no power, it doesn't move, even with you right in front of it")
	c.set_powered(true)
	check(c.state == "hunting", "power back on, it hunts again")
	check(await until(func(): return c.held == p, 120), "and it grabs whoever's still standing in front of it")
	await done(a)


func test_docked() -> void:
	var a := arena()
	var c := custodian(a, Vector3(0, 0.1, 3.8), Vector3(0, 0.1, 1.0))
	var p := spawn(a, Vector3(0, 0.1, 5))
	await frames(20)
	var died := [false]
	p.died.connect(func(): died[0] = true)
	var docked := []
	c.docked.connect(func(who): docked.append(who))
	c.activate()
	check(await until(func(): return c.held == p, 120), "grabbed")
	Engine.time_scale = 3.0
	check(await until(func(): return not docked.is_empty(), 600), "nobody frees you, and it gets you back to its bay")
	check(docked == [p] and died[0], "there you're done (alone, back to the checkpoint; with a crew, you're down)")
	check(c.state == "recharging" and c.held == null, "and it stands in its bay for a while")
	await done(a)


func test_walls_and_wounds() -> void:
	var a := arena()
	Greybox.box(a, Vector3(0, 1.5, 2.5), Vector3(6, 3, 0.3), Color.DIM_GRAY, "Wall")
	var c := custodian(a, Vector3(0, 0.1, 0), Vector3(0, 0.1, -5))
	var p := spawn(a, Vector3(0, 0.1, 5))
	await frames(20)
	c.activate()
	await frames(60)
	check(c.target == null and c.held == null, "it can't see through a wall")
	check(c.wounds.shown() == 0 and c.wounds.speed_scale() == 1.0, "unhurt, it shows nothing")
	for i in int(Custodian.STRIKES_TO_WRECK * 0.5):
		c.take_hit(p)
		c.state = "hunting"
	await frames(2)
	check(c.wounds.shown() > 0 and c.wounds.speed_scale() < 1.0 and c.wounds._sparks.emitting, "struck, it shows scorch marks and sparks, and it's slower")
	check(not a.find_children("*", "ProgressBar", true, false).size(), "and there's no health bar on it")
	await done(a)
