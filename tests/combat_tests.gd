extends RefCounted
## Combat tests: blocking, health, being thrown and grabbed, and the injuries
## enemies show instead of health bars. Co-op (going down, being helped up) and
## Rourke's fight in Vale's lab are in run_tests.gd, next to the other co-op and
## Level 2 tests.

var t: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("Combat")
	test_guard_timing()
	await test_block()
	await test_regen()
	await test_throw()
	await test_thrown_off_a_shelf()
	await test_grab()
	await test_injuries()
	await test_rourke_fight_feel()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func arena() -> Node3D:
	var a := Node3D.new()
	t.root.add_child(a)
	Greybox.box(a, Vector3(0, -0.1, 0), Vector3(40, 0.2, 40), Color.GRAY, "Floor")
	return a


func spawn(parent: Node, pos: Vector3) -> Player:
	var p := Player.new()
	p.local_control = false
	p.position = pos
	parent.add_child(p)
	return p


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
	a.queue_free()
	await t.process_frame


func test_guard_timing() -> void:
	var g := Guard.new()
	check(g.raise(10.0) and g.catch_hit(10.2), "a block pressed just before the hit catches it")
	g = Guard.new()
	g.raise(10.0)
	check(not g.catch_hit(10.0 + Guard.WINDOW + 0.05), "pressed too early, the guard is already down")
	g = Guard.new()
	check(not g.catch_hit(10.0), "never pressed, nothing is blocked")
	g = Guard.new()
	g.raise(10.0)
	check(not g.raise(10.0 + Guard.WINDOW + 0.1) and not g.catch_hit(10.0 + Guard.WINDOW + 0.15), "mashing doesn't work: a missed block leaves you open for a beat")
	check(g.raise(10.0 + Guard.WINDOW + Guard.RECOVER + 0.01), "then you can raise it again")
	g = Guard.new()
	g.raise(10.0)
	g.catch_hit(10.1)
	check(g.raise(10.15), "after a block, you can block the next swing straight away")


func test_block() -> void:
	var a := arena()
	var p := spawn(a, Vector3(0, 0.1, 0))
	await frames(20)
	check(p.combat != null and p.health == 100.0, "a player starts with full health")
	check(p.take_damage(22.0, "rourke") == "hit" and is_equal_approx(p.health, 78.0), "an unblocked swing hurts")
	p.combat.raise_guard()
	await frames(5)
	check(p.take_damage(22.0, "rourke") == "blocked" and is_equal_approx(p.health, 78.0), "right-click just before his swing lands, and it does nothing")
	p.combat.raise_guard()
	await frames(int((Guard.WINDOW + 0.1) * 60))
	check(p.take_damage(22.0, "rourke") == "hit" and is_equal_approx(p.health, 56.0), "too early, and the swing lands")
	await frames(int(Guard.RECOVER * 60) + 2)
	p.combat.raise_guard()
	check(p.take_damage(30.0, "shredder") == "hit" and is_equal_approx(p.health, 26.0), "big entities can't be blocked")
	var died := [false]
	p.died.connect(func(): died[0] = true)
	check(p.take_damage(30.0) == "dead" and died[0], "with no crew around (no level), 0 health is straight back to the checkpoint")
	await done(a)


func test_regen() -> void:
	var a := arena()
	var p := spawn(a, Vector3(0, 0.1, 0))
	await frames(20)
	p.take_damage(40.0, "rourke")
	Engine.time_scale = 4.0
	await frames(int(PlayerCombat.REGEN_DELAY * 0.5 * 60 / 4.0))
	check(is_equal_approx(p.health, 60.0), "health doesn't come back while you're still in it")
	check(await until(func(): return p.health > 70.0, int((PlayerCombat.REGEN_DELAY + 4.0) * 60 / 4.0)), "a while after the last hit, it creeps back (%.1f)" % p.health)
	Engine.time_scale = 1.0
	await done(a)


func test_throw() -> void:
	var a := arena()
	var p := spawn(a, Vector3(0, 0.1, 0))
	await frames(20)
	p.combat.throw(Vector3(0, 0, 1.0), 8.0, 25.0)
	check(is_equal_approx(p.health, 75.0) and p.input_locked and p.combat.thrown, "the Shredder's throw hurts, and you've no control in the air")
	await frames(3)
	check(not p.is_on_floor(), "you leave the ground")
	check(await until(func(): return not p.combat.thrown, 240), "you land")
	check(p.global_position.z < -2.5, "across the room (%.1f m)" % -p.global_position.z)
	check(not p.input_locked, "and the controls come back")
	await done(a)


func test_thrown_off_a_shelf() -> void:
	var a := arena()
	Greybox.box(a, Vector3(0, 1.5, 0), Vector3(2, 3, 2), Color.DIM_GRAY, "Shelf")
	var p := spawn(a, Vector3(0, 3.1, 0))
	await frames(30)
	check(p.global_position.y > 2.9, "standing on a high shelf")
	p.combat.throw(Vector3(0, 3, 0.6), 6.0, 20.0)
	check(await until(func(): return not p.combat.thrown, 300), "thrown off it")
	check(p.global_position.y < 0.5 and p.global_position.z < -1.0, "you fall all the way to the floor (%.1f m)" % p.global_position.y)
	await done(a)


func test_grab() -> void:
	var a := arena()
	var p := spawn(a, Vector3(0, 0.1, 0))
	await frames(20)
	var grabber := Node3D.new()
	grabber.position = Vector3(0, 0, -1)
	a.add_child(grabber)
	p.combat.grab(grabber)
	await frames(3)
	check(p.input_locked and p.global_position.distance_to(Vector3(0, 0, -1.8)) < 0.3, "grabbed, you're held in front of it, and can't move")
	for i in 60:
		grabber.position.z -= 0.05
		await t.physics_frame
	check(p.global_position.z < -4.0, "it drags you along (%.1f)" % p.global_position.z)
	p.combat.release()
	await frames(3)
	check(not p.input_locked and p.combat.grabbed_by == null, "let go, you have your controls back")
	p.combat.grab(grabber)
	grabber.queue_free()
	await frames(3)
	check(not p.input_locked, "if it's destroyed, it lets go")
	await done(a)


func test_injuries() -> void:
	var a := arena()
	var r := Rourke.new()
	r.position = Vector3(0, 0.1, 0)
	a.add_child(r)
	await frames(5)
	check(r.wounds != null and r.wounds.shown() == 0 and r.wounds.speed_scale() == 1.0, "unhurt, he shows nothing")
	r.state = Rourke.State.CHASE
	r.max_hits = 6
	r.hits_left = 4
	await t.process_frame
	await t.process_frame
	var some := r.wounds.shown()
	check(some > 0 and r.wounds.speed_scale() < 1.0, "a couple of hits in, his jacket is torn and he's slower (%d marks)" % some)
	r.hits_left = 1
	await t.process_frame
	await t.process_frame
	check(r.wounds.shown() > some and r.wounds.speed_scale() < 0.7, "nearly beaten, more wounds and a heavy limp (%d marks)" % r.wounds.shown())
	check(not a.find_children("*", "ProgressBar", true, false).size() and not a.find_children("*", "HealthBar", true, false).size(), "and no health bar over his head")
	# Dressed with a rig (Graphics), the wounds move with the rig's joints.
	NpcLook.attach(r, CharacterLooks.rourke())
	await t.process_frame
	await t.process_frame
	var rig: CharacterRig = r.get_node("Rig")
	var on_rig := r.wounds._marks.all(func(m): return rig.is_ancestor_of(m))
	check(on_rig and r.wounds.shown() > some, "on his rig, the wounds sit on its joints, so they lie down when he does")
	r.reset_fight(Transform3D(Basis(), Vector3(0, 0.1, 0)))
	await t.process_frame
	await t.process_frame
	check(r.wounds.shown() == 0, "a fight that starts over starts him unhurt")
	# A machine scorches and sparks instead of bleeding (any entity with a _body will do).
	var machine := Watcher.new()
	machine.position = Vector3(4, 0.1, 0)
	a.add_child(machine)
	var w := Injuries.attach(machine, Injuries.Kind.MACHINE)
	w.severity = 0.6
	check(w.shown() > 0 and w._sparks != null and w._sparks.emitting, "a damaged machine shows scorch marks and throws sparks")
	await done(a)


## Rourke's side: he reels when blocked, and walks past someone who's down.
func test_rourke_fight_feel() -> void:
	var a := arena()
	var p := spawn(a, Vector3(0, 0.1, -1.2))
	var r := Rourke.new()
	r.position = Vector3(0, 0.1, 0)
	a.add_child(r)
	await frames(20)
	r.start_chase(p)
	check(await until(func(): return r._windup > 0.0, 120), "he leans in before he swings")
	await frames(8)  # a player's reaction to the lean
	p.combat.raise_guard()
	var blocked := [false]
	p.combat.blocked.connect(func(_c): blocked[0] = true)
	check(await until(func(): return blocked[0], 60), "and a block timed on the lean catches the swing")
	check(p.health == 100.0, "it does nothing")
	r.recoil()
	check(r.state == Rourke.State.STAGGER, "blocked, he reels back")
	p.combat.down = true  # as if a teammate's crew had them on the floor
	r.state = Rourke.State.CHASE
	r._retarget = 0.0
	await frames(5)
	check(r.target == null, "he leaves someone who's down alone")
	p.combat.down = false
	await done(a)
