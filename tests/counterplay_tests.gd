extends RefCounted
## Fighting back without fists (E7, plan/environment-play-e7.md; Counterplay): stun
## an enemy with a fire extinguisher, the flashlight's strobe or something thrown;
## cage it; hide from it in a locker or crouched in the dark. Here with the
## Custodian; co-op at the end.

var t: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("Counterplay")
	await test_extinguisher()
	await test_strobe()
	await test_throw()
	await test_hide()
	await test_dark()
	await test_cage()
	await test_shredder()
	await test_watcher()
	await test_mimic()
	await test_coop()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func frames(n: int) -> void:
	for i in n:
		await t.physics_frame


func until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await t.physics_frame
	return cond.call()


static var _arena_gd: GDScript


static func _arena_script() -> GDScript:
	if _arena_gd == null:
		_arena_gd = GDScript.new()
		_arena_gd.source_code = "extends Node3D\nvar players\nvar player\n"
		_arena_gd.reload()
	return _arena_gd


## A floor, the player at `at` looking down -Z, and the world's Counterplay.
func arena(at := Vector3(0, 0.1, 5)) -> Array:
	var a := Node3D.new()
	a.set_script(_arena_script())  # a level's players and player, for the gear kit
	t.root.add_child(a)
	Greybox.box(a, Vector3(0, -0.1, 0), Vector3(60, 0.2, 60), Color.GRAY, "Floor")
	var p := Player.new()
	p.local_control = false
	p.position = at
	a.add_child(p)
	var np := NetPlayers.create(a, p)
	a.set("players", np)
	a.set("player", p)
	var cp := Counterplay.create(a, np)
	return [a, p, cp]


func custodian(parent: Node, at: Vector3, bay: Vector3) -> Custodian:
	var c := Custodian.new()
	c.position = at
	parent.add_child(c)
	c.set_bay(bay)
	return c


func hold(p: Player, item: String) -> void:
	p.inventory.add(item)
	if p.inventory.active_item() != item:
		p.inventory.use_slot(p.inventory.hotbar.find(item))


## `p` presses `action` (as if this machine's player).
## (Block goes in from the pad's left trigger: a headless run has no captured mouse.)
func press(p: Player, action: String) -> void:
	var ev: InputEvent
	if action == "block":
		var m := InputEventJoypadMotion.new()
		m.axis = JOY_AXIS_TRIGGER_LEFT
		m.axis_value = 1.0
		ev = m
	else:
		var act := InputEventAction.new()
		act.action = action
		act.pressed = true
		ev = act
	var was := p.local_control
	p.local_control = true
	p._unhandled_input(ev)
	p.local_control = was


## The `n`th thrown thing lying on the floor under `root`, or null.
func landed_gear(root: Node, n := 1) -> GearPickup:
	var g := root.find_child("Thrown%d" % n, true, false)
	return g if g is GearPickup and not g.taken else null


func done(a: Node) -> void:
	a.queue_free()
	await t.process_frame


func test_extinguisher() -> void:
	var r := arena()
	var a: Node3D = r[0]
	var p: Player = r[1]
	var cp: Counterplay = r[2]
	var c := custodian(a, Vector3(0, 0.1, 2.6), Vector3(0, 0.1, -20))
	await frames(20)
	check(not cp.blast(), "no extinguisher in your hands, no blast")
	hold(p, Counterplay.EXTINGUISHER)
	check(cp.blasts_left == Counterplay.BLASTS and Inventory.item_name(Counterplay.EXTINGUISHER) == "Fire extinguisher", "a fire extinguisher comes with %d blasts" % Counterplay.BLASTS)
	c.activate()
	check(cp.blast() and c.state == "stunned" and is_equal_approx(c._timer, Custodian.BLAST_STUN), "a blast in its face stuns the Custodian for %.0f s" % Custodian.BLAST_STUN)
	check(cp.blasts_left == Counterplay.BLASTS - 1 and a.find_children("*", "SightCloud", true, false).size() == 1, "one blast gone, and a cloud hangs where it went")
	var eye := p.global_position + Vector3.UP * 1.5
	check(SightCloud.blocks(a, eye, eye + Vector3(0, 0, -6)) and not SightCloud.blocks(a, eye, eye + Vector3(6, 0, 0)), "nothing sees through the cloud")
	check(not cp.blast(), "one blast at a time")
	var at := c.global_position
	await frames(int(Custodian.BLAST_STUN * 60 * 0.7))
	check(c.global_position.distance_to(at) < 0.1, "it stands still while its optics clear")
	check(await until(func(): return c.state != "stunned", 120), "then it hunts again")
	c._timer = 0.0
	c.state = "hunting"
	check(cp.blast() and c.state == "stunned" and is_equal_approx(c._timer, Custodian.BLAST_STUN * 0.5), "stunned again soon after, it shakes it off in half the time")
	# Grabbed: a teammate's blast makes it let go.
	await frames(60)
	var freed := []
	c.freed.connect(func(who, how): freed.append(how))
	c.state = "hunting"
	c._grab(p)
	check(c.held == p, "(it has hold of them)")
	c.set_meta("counter_stunned_at", -INF)
	c.counter("extinguisher", eye)
	check(freed == ["stunned"] and c.held == null and c.state == "stunned", "a blast while it drags someone makes it drop them")
	await frames(60)
	check(cp.blast() and cp.blasts_left == 0, "the last blast")
	await frames(60)
	check(not cp.blast(), "and then it's empty")
	await done(a)


func test_strobe() -> void:
	var r := arena()
	var a: Node3D = r[0]
	var p: Player = r[1]
	var cp: Counterplay = r[2]
	var c := custodian(a, Vector3(0, 0.1, 1.8), Vector3(0, 0.1, -20))
	await frames(20)
	check(cp.prompt_for(p) == Counterplay.STROBE_HINT, "close to an enemy, you're shown \"%s\"" % Counterplay.STROBE_HINT)
	c.activate()
	check(cp.strobe() and c.state == "stunned" and is_equal_approx(c._timer, Custodian.STROBE_STUN) and p.flashlight.visible,
		"the strobe in its optics stuns the Custodian for %.1f s, and leaves your light on" % Custodian.STROBE_STUN)
	check(cp.prompt_for(p) == "", "once you've used it, the hint is gone")
	check(not cp.strobe(), "the strobe needs a moment before the next")
	# Behind you, it does nothing.
	var behind := custodian(a, Vector3(0, 0.1, 7.5), Vector3(0, 0.1, -20))
	await frames(5)
	behind.activate()
	cp._strobe_cd = 0.0
	c.set_meta("counter_stunned_at", -INF)
	cp.strobe()
	check(behind.state == "hunting", "it has to be in front of you")
	await done(a)


func test_throw() -> void:
	var r := arena()
	var a: Node3D = r[0]
	var p: Player = r[1]
	var cp: Counterplay = r[2]
	var c := custodian(a, Vector3(0, 0.1, 1.5), Vector3(0, 0.1, -20))
	await frames(20)
	hold(p, "screwdriver")
	check(cp.prompt_for(p) != Counterplay.THROW_PROMPT and not cp.throw_held(), "a screwdriver isn't for throwing")
	press(p, "block")
	check(p.combat.guard.is_up(p.combat._clock) and p.inventory.has("screwdriver"), "so right-click blocks, as always")
	await frames(int((Guard.WINDOW + Guard.RECOVER) * 60) + 5)
	hold(p, Counterplay.EXTINGUISHER)
	cp.blasts_left = 2
	check(cp.prompt_for(p) == Counterplay.THROW_PROMPT, "an extinguisher in your hands: \"%s\"" % Counterplay.THROW_PROMPT)
	c.activate()
	press(p, "block")
	check(not p.inventory.has(Counterplay.EXTINGUISHER) and not p.combat.guard.is_up(p.combat._clock), "right-click throws it (no block): it leaves your hands")
	check(a.find_children("Flying*", "ThrownItem", true, false).size() == 1, "it flies")
	check(await until(func(): return c.state == "stunned", 90), "it hits the Custodian: a flinch")
	check(await until(func(): return landed_gear(a) != null, 90) and landed_gear(a).global_position.y < 0.4 \
		and a.find_children("Flying*", "ThrownItem", true, false).is_empty(), "and lands on the floor")
	var thrown: GearPickup = landed_gear(a)
	check(thrown.get_prompt(p) == "[E] Pick up the fire extinguisher", "for anyone to pick up again (it's gear)")
	thrown.interact(p)
	await frames(3)
	check(p.inventory.has(Counterplay.EXTINGUISHER) and cp.blasts_left == 2 and thrown.taken, "picked up, it still has the blasts it had")
	# Hands full of gear: swapping it for something leaves it, with its blasts, on the floor.
	for g in ["keyboard", "power_cord", "fuse"]:
		p.inventory.add(g)
	hold(p, Counterplay.EXTINGUISHER)
	cp.blasts_left = 1
	var bar := GearPickup.make(a, "crowbar", Vector3(0, 0, 4.2))
	await frames(2)
	bar.interact(p)
	await frames(3)
	check(p.inventory.has("crowbar") and not p.inventory.has(Counterplay.EXTINGUISHER) and bar.item == Counterplay.EXTINGUISHER, "(swapped for a crowbar)")
	hold(p, "crowbar")
	bar.interact(p)
	await frames(3)
	check(p.inventory.has(Counterplay.EXTINGUISHER) and cp.blasts_left == 1, "swapped back, it still has the one blast left")
	for g in ["keyboard", "power_cord", "fuse", "crowbar"]:
		p.inventory.remove(g)
	# Thrown at nothing: it lands out in front.
	c.queue_free()
	await frames(2)
	hold(p, Counterplay.EXTINGUISHER)
	check(cp.throw_held(), "(thrown again)")
	await until(func(): return landed_gear(a, 2) != null, 150)
	var far: GearPickup = landed_gear(a, 2)
	check(far != null and far.global_position.z < p.global_position.z - 2.0, "thrown at nothing, it lands out in front of you")
	await done(a)


func test_hide() -> void:
	var r := arena()
	var a: Node3D = r[0]
	var p: Player = r[1]
	var cp: Counterplay = r[2]
	# A locker beside you, and the Custodian round a wall where it can't see you get in.
	var spot := HidingSpot.make(a, Vector3(1.2, 0.0, 5), 0.0, "locker")
	Greybox.box(a, Vector3(0, 1.2, -1), Vector3(8, 2.4, 0.3), Color.GRAY, "Wall")
	var c := custodian(a, Vector3(0, 0.1, -4), Vector3(0, 0.1, -4))
	await frames(20)
	check(spot.get_prompt(p) == "[E] Hide" and spot.kind == "locker", "a locker: \"[E] Hide\" (it sounds like a locker)")
	spot.interact(p)
	await frames(5)
	check(p.is_sitting() and Counterplay.hidden_in(p) == spot and cp.hidden.size() == 1, "inside, you're hidden")
	c.activate()
	c.global_position = Vector3(0, 0.1, 3.0)  # right in front of the locker now
	await frames(90)
	check(c.held == null and c.target == null, "it walks right past: it never saw you get in")
	check(p._leave_by_interact() and spot.leave_prompt == "[E] Get out", "inside: \"[E] Get out\"")
	press(p, "interact")
	check(await until(func(): return not p.is_sitting(), 120), "E gets you out, the way it got you in")
	await frames(2)
	check(Counterplay.hidden_in(p) == null and cp.hidden.is_empty(), "out again, you're in plain sight")
	check(await until(func(): return c.held == p, 120), "and it has you")
	spot.interact(p)
	await frames(2)
	check(not p.is_sitting() and Counterplay.hidden_in(p) == null, "held, it's too late to hide")
	c._let_go("struck")
	c._stun(5.0)
	# Seen getting in: it comes and looks.
	await frames(30)
	c.global_position = Vector3(0, 0.1, 1.0)
	c.state = "hunting"
	c.target = null
	await frames(2)
	spot.interact(p)
	await frames(2)
	check(Counterplay.hidden_in(p) == spot and c._search == spot, "seen getting in, it heads for the locker")
	check(await until(func(): return c.held == p, 240), "and pulls you out")
	check(not p.is_sitting() and Counterplay.hidden_in(p) == null, "(out of the locker)")
	await done(a)


func test_dark() -> void:
	var r := arena(Vector3(0, 0.1, 6))
	var a: Node3D = r[0]
	var p: Player = r[1]
	var cp: Counterplay = r[2]
	var c := custodian(a, Vector3(0, 0.1, 0), Vector3(0, 0.1, -20))
	await frames(20)
	p.flashlight.visible = false
	p.controls.crouch = true
	await frames(20)
	check(p.crouching and Counterplay.in_dark(p), "crouched, light off, no lamp: you're in the dark")
	check(not Counterplay.can_see(c.global_position, p, Custodian.SIGHT_RANGE) and c._nearest_visible() == null, "and the Custodian can't see you from 6 m")
	p.flashlight.visible = true
	check(not Counterplay.in_dark(p) and c._nearest_visible() == p, "your flashlight on, it can")
	p.flashlight.visible = false
	var lamp := OmniLight3D.new()
	lamp.omni_range = 6.0
	lamp.light_energy = 1.0
	lamp.position = Vector3(0, 2.5, 6)
	a.add_child(lamp)
	cp._lights_age = INF
	check(cp.lit(p.global_position + Vector3.UP * 0.6) and not Counterplay.in_dark(p) and c._nearest_visible() == p, "under a lamp, it can")
	lamp.visible = false
	cp._lights_age = INF
	p.global_position = Vector3(0, 0.1, 2.5)
	await frames(2)
	check(Counterplay.in_dark(p) and c._nearest_visible() == p, "in the dark, it still sees you this close (%.0f m)" % Counterplay.DARK_SIGHT)
	p.controls.crouch = false
	await done(a)


func test_cage() -> void:
	var r := arena()
	var a: Node3D = r[0]
	var p: Player = r[1]
	var c := custodian(a, Vector3(0, 0.1, 0), Vector3(0, 0.1, 0))
	await frames(20)
	c.activate()
	check(c.in_bay(), "it's in its bay")
	c.set_caged(true)
	await frames(120)
	check(c.state == "caged" and c.global_position.distance_to(Vector3(0, 0.1, 0)) < 0.2 and c.held == null, "caged in its bay, it stays put with someone in plain sight")
	c.counter("strobe", Vector3.ZERO)
	check(c.state == "caged", "(nothing to stun in a cage)")
	c.set_caged(false)
	check(await until(func(): return c.held == p, 240), "let out, it hunts again")
	await done(a)


## Co-op: a client hides, and the host's enemies know; a client's blast reaches them.
func shredder(parent: Node, at: Vector3) -> Shredder:
	var s := Shredder.new()
	s.position = at
	parent.add_child(s)
	s.wake()
	return s


## The Shredder: blind, so the strobe does nothing; the blast stuns it but it hears
## the hiss; a thrown thing lures it; hiding is safe unless it heard you get in.
func test_shredder() -> void:
	print("Counterplay: the Shredder")
	var r := arena()
	var a: Node3D = r[0]
	var p: Player = r[1]
	var cp: Counterplay = r[2]
	var s := shredder(a, Vector3(0, 0.1, 2.6))
	await frames(20)
	s.state = "listening"
	cp.strobe()
	await frames(2)
	check(s.state == "listening", "a strobe does nothing to it: it's blind")
	hold(p, Counterplay.EXTINGUISHER)
	check(cp.blast() and s.state == "stunned" and is_equal_approx(s._timer, Shredder.BLAST_STUN), "a blast stuns it for %.0f s" % Shredder.BLAST_STUN)
	check(s.target_point.distance_to(p.global_position) < 2.0, "but it heard the hiss")
	check(await until(func(): return s.state == "investigating", 200), "and once it shakes it off, it comes for you")
	check(s.target_point.distance_to(p.global_position) < 2.0, "(where the hiss was)")
	# A thrown thing: no stun, but it walks to where it lands.
	s.global_position = Vector3(-4, 0.1, -4)
	s.state = "listening"
	s.set_meta("counter_stunned_at", -INF)
	p.rotation.y = deg_to_rad(-40.0)  # off to the right, away from it
	await frames(2)
	check(cp.throw_held(), "(thrown)")
	check(await until(func(): return landed_gear(a) != null, 150), "(landed)")
	await frames(2)
	var at := landed_gear(a).global_position
	check(s.state in ["turning", "investigating"] and s.target_point.distance_to(at) < 1.0, "the clatter where it lands draws it away")
	check(await until(func(): return Vector2(s.global_position.x - at.x, s.global_position.z - at.z).length() < 1.5, 400), "and it walks over there")
	p.rotation.y = 0.0
	# Hiding where it can't hear you get in: it walks right past.
	var spot := HidingSpot.make(a, Vector3(1.2, 0.0, 5), 0.0, "locker")
	s.global_position = Vector3(0, 0.1, -8)
	s.state = "listening"
	await frames(5)
	spot.interact(p)
	await frames(2)
	check(p.is_sitting() and Counterplay.hidden_in(p) == spot and s._search == null, "it's too far off to hear the locker shut")
	s.global_position = Vector3(1.2, 0.1, 3.8)  # right by it
	s.state = "roaming"
	s.target_point = Vector3(1.2, 0.1, 8)
	await frames(90)
	check(s.held == null and Counterplay.hidden_in(p) == spot, "it bumps right past the locker: you make no sound in there")
	p.stand_up(true)
	await frames(5)
	# Heard getting in: it bangs on the locker and pulls you out.
	s.global_position = Vector3(1.2, 0.1, 2.6)
	s.state = "listening"
	s.held = null
	await frames(30)
	spot.interact(p)
	await frames(2)
	check(Counterplay.hidden_in(p) == spot and s._search == spot and s.state == "investigating", "close by, it hears the locker shut and comes")
	check(await until(func(): return s.held == p, 240), "it pulls you out")
	check(not p.is_sitting() and Counterplay.hidden_in(p) == null, "(out of the locker)")
	await done(a)


func watcher(parent: Node, at: Vector3) -> Watcher:
	var w := Watcher.new()
	w.position = at
	parent.add_child(w)
	w.active = true
	return w


## The Watcher: the strobe keeps it frozen after you look away; the extinguisher's
## cloud blocks your view of it; from a locker you can still watch it, from a
## cabinet you can't.
func test_watcher() -> void:
	print("Counterplay: the Watcher")
	var r := arena(Vector3(0, 0.1, 6))
	var a: Node3D = r[0]
	var p: Player = r[1]
	var cp: Counterplay = r[2]
	var w := watcher(a, Vector3(0, 0.1, 3))
	var caught := []
	w.caught.connect(func(b): caught.append(b))
	await frames(20)
	var at := w.global_position
	check(w.seen and w.global_position.distance_to(at) < 0.05, "you're looking: it's frozen")
	check(cp.strobe(), "you strobe it")
	p.rotation.y = PI  # turn your back and run
	await frames(90)
	check(w.global_position.distance_to(at) < 0.05, "back turned, it stays frozen a moment longer")
	check(await until(func(): return w.global_position.distance_to(at) > 0.3, 200), "then it comes")
	p.rotation.y = 0.0
	w.global_position = Vector3(0, 0.1, 1)
	await frames(10)
	at = w.global_position
	check(w.seen and w.global_position.distance_to(at) < 0.05, "(frozen again)")
	# The extinguisher's cloud: it hides it from you, so it moves.
	hold(p, Counterplay.EXTINGUISHER)
	check(cp.blast(), "you blast it")
	check(await until(func(): return w.global_position.distance_to(at) > 0.3, 120), "the cloud blocks your view of it: it moves")
	for c in a.find_children("*", "SightCloud", true, false):
		c.free()
	# In a locker you can see out through the slats: staring keeps it frozen.
	w.global_position = Vector3(0, 0.1, 1)
	var locker := HidingSpot.make(a, Vector3(0, 0.0, 6.3), 0.0, "locker")
	await frames(10)
	locker.interact(p)
	await frames(10)
	at = w.global_position
	check(Counterplay.hidden_in(p) == locker and w._search == locker, "it was coming for you: it heads for the locker")
	await frames(60)
	check(w.seen and w.global_position.distance_to(at) < 0.05 and caught.is_empty(), "but from in there you can watch it, and it stays put")
	SightCloud.make(a, Vector3(0, 1.4, 4.0), 1.4, 6.0)
	check(await until(func(): return not caught.is_empty(), 400), "lose sight of it and it comes to the locker")
	check(caught[0] == p and not p.is_sitting() and Counterplay.hidden_in(p) == null, "and takes you out")
	for c in a.find_children("*", "SightCloud", true, false):
		c.free()
	# A cabinet: you can't see out.
	caught.clear()
	await frames(int(Watcher.CATCH_COOLDOWN * 60) + 5)
	w.global_position = Vector3(0, 0.1, 1)
	var cabinet := HidingSpot.make(a, Vector3(1.4, 0.0, 6.0), 0.0, "cabinet")
	await frames(5)
	cabinet.interact(p)
	await frames(5)
	check(Counterplay.hidden_in(p) == cabinet and not w.player_sees(p), "in a cabinet, you can't see out")
	check(await until(func(): return not caught.is_empty(), 400) and caught[0] == p, "it walks to the cabinet and takes you")
	await done(a)


## The Mimic: a strobe pins it, a blast or a throw sends it off, and with its way
## out shut it's cornered and stops turning up anywhere else.
func test_mimic() -> void:
	print("Counterplay: the Mimic")
	var r := arena(Vector3(0, 0.1, 3))  # strobe range
	var a: Node3D = r[0]
	var p: Player = r[1]
	var cp: Counterplay = r[2]
	# A wall at x 3 with a doorway at z 0 and a door in it; the Mimic's way out is through it.
	var geo := NavigationRegion3D.new()
	a.add_child(geo)
	Greybox.box(geo, Vector3(0, -0.1, 0), Vector3(40, 0.2, 40), Color.GRAY, "NavFloor")
	Greybox.box(geo, Vector3(3, 1.5, -10.75), Vector3(0.3, 3, 19.5), Color.GRAY, "WallN")
	Greybox.box(geo, Vector3(3, 1.5, 10.75), Vector3(0.3, 3, 19.5), Color.GRAY, "WallS")
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.agent_radius = 0.3
	nm.cell_size = 0.1
	nm.cell_height = 0.1
	geo.navigation_mesh = nm
	geo.bake_navigation_mesh(false)
	var door := Door.create(a, "TEST-MIMIC", Vector3(3, 1.2, 0), Vector3(0.1, 2.4, 2.0))
	door.set_open(true, true)
	var m := Mimic.new()
	m.active = false
	a.add_child(m)
	m.stand(Vector3(0, 0.1, 0), Vector3(0, 0.1, -5))
	m.retreat = Vector3(8, 0.1, 0)
	m.haunts = [{"at": Vector3(-2, 0.1, -4), "look": Vector3(-2, 0.1, -8)}]
	await frames(30)
	m.active = true
	check(cp.strobe() and m._pinned > 0.0, "you strobe it as you look at it")
	await frames(60)
	check(m.state == "standing", "it can't get away: time to read its lanyard")
	check(await until(func(): return m.state == "leaving", 120), "then it goes")
	check(await until(func(): return m.state == "gone", 400), "out through the door")
	# Its way out shut: cornered.
	m.stand(Vector3(0, 0.1, 0), Vector3(0, 0.1, -5))
	m.visible = true
	door.set_open(false, true)
	door.locked = true
	await frames(5)
	check(await until(func(): return m.state == "cornered", 400), "with the door shut, it's cornered")
	await frames(int((Mimic.CORNER_RETRY + Mimic.CORNER_AFTER) * 60) + 30)
	check(m.state in ["cornered", "leaving"] and m.visible and m.global_position.x < 3.0, "and stays cornered, turning up nowhere else")
	door.locked = false
	door.set_open(true, true)
	check(await until(func(): return m.state == "gone", 600), "open the door and it gets away")
	# A blast or a throw sends it off, the same as being seen; strobed, it stays.
	p.rotation.y = PI  # not looking
	m.stand(Vector3(0, 0.1, 0), Vector3(0, 0.1, -5))
	m.visible = true
	await frames(5)
	m.set_meta("counter_stunned_at", -INF)
	m.counter("strobe", Vector3.ZERO)
	m.counter("extinguisher", Vector3.ZERO)
	check(m.state == "standing", "pinned by the strobe, a blast doesn't move it")
	m._pinned = 0.0
	m.counter("extinguisher", Vector3.ZERO)
	check(m.state == "leaving", "a blast sends it off")
	m.stand(Vector3(0, 0.1, 0), Vector3(0, 0.1, -5))
	m.counter("thrown", Vector3.ZERO)
	check(m.state == "leaving", "so does something thrown")
	await done(a)


func test_coop() -> void:
	print("Counterplay: co-op")
	var tests = t
	t.root.get_node("Game").new_run(4)
	var worlds: Array = await tests._coop_worlds(1)
	var machines: Array = await tests._coop_load(worlds, "res://scenes/level_1.tscn")
	var host = machines[0]
	var client = machines[1]
	var client_id: int = t.get_multiplayer(worlds[1].get_path()).get_unique_id()
	await until(func(): return host.players.puppet(client_id) != null, 240)
	var puppet: Node3D = host.players.puppet(client_id)
	var hcp: Counterplay = Counterplay.of(host)
	var ccp: Counterplay = Counterplay.of(client)
	check(hcp != null and ccp != null, "every floor has its Counterplay")
	# A locker by the client, on both machines.
	var spots := []
	for l in machines:
		var s := HidingSpot.make(l, l.to_local(client.player.global_position + Vector3(1.0, 0, 0)), 0.0, "locker")
		s.name = "TestLocker"
		spots.append(s)
	await tests._frames(5)
	spots[1].interact(client.player)
	check(await until(func(): return Counterplay.hidden_in(puppet) == spots[0], 120), "the client gets into a locker: the host knows")
	check(not puppet.visible, "and nobody sees them in there")
	client.player.stand_up(true)
	check(await until(func(): return Counterplay.hidden_in(puppet) == null and puppet.visible, 120), "out again, on every machine")
	# The client's blast reaches the host's Custodian.
	var bots := []
	# Face somewhere open (level 1 has walls about).
	var space: PhysicsDirectSpaceState3D = client.player.get_world_3d().direct_space_state
	for yaw in [0.0, PI / 2, PI, -PI / 2]:
		var eye: Vector3 = client.player.global_position + Vector3.UP * 1.2
		var look := Vector3(0, 0, -1).rotated(Vector3.UP, yaw)
		var q := PhysicsRayQueryParameters3D.create(eye, eye + look * 4.0, 1, [client.player.get_rid()])
		if space.intersect_ray(q).is_empty():
			client.player.rotation.y = yaw
			break
	await tests._frames(2)
	var front: Vector3 = client.player.global_position + (-client.player.camera.global_basis.z * Vector3(1, 0, 1)).normalized() * 2.0
	for l in machines:
		var c := Custodian.new()
		c.name = "Custodian"
		c.position = l.to_local(front)
		l.add_child(c)
		c.set_bay(front + Vector3(0, 0, -40))
		l.sync.replicate(c, c.sync_properties())
		bots.append(c)
	host.sync._synchronizers.back().set_visibility_for(client_id, true)
	await tests._frames(5)
	bots[0].state = "recharging"
	bots[0]._timer = 100.0
	hold(client.player, Counterplay.EXTINGUISHER)
	check(ccp.blast(), "the client blasts it")
	check(await until(func(): return bots[0].state == "stunned", 60), "and the host's Custodian is stunned")
	check(await until(func(): return host.find_children("*", "SightCloud", true, false).size() > 0 and client.find_children("*", "SightCloud", true, false).size() > 0, 60),
		"the cloud hangs on every machine")
	# A client's throw: it lands the same everywhere, and the host hands it back.
	hold(client.player, Counterplay.EXTINGUISHER)
	for b in bots:
		b.queue_free()
	await tests._frames(2)
	check(ccp.throw_held(), "the client throws it")
	check(await until(func(): return landed_gear(host) != null and landed_gear(client) != null, 180), "it lands on every machine")
	var hi: GearPickup = landed_gear(host)
	var ci: GearPickup = landed_gear(client)
	check(hi.global_position.distance_to(ci.global_position) < 0.05 and hi.get_path() != ci.get_path() \
		and host.get_path_to(hi) == client.get_path_to(ci), "in the same place, as the same gear")
	hi.interact(host.player)
	# (Both machines share one Game.inventory in a test, so only the floors can show who took it.)
	check(await until(func(): return host.player.inventory.has(Counterplay.EXTINGUISHER) and ci.taken, 60),
		"the host picks it up: it's gone from the client's floor too")
	host.player.inventory.remove(Counterplay.EXTINGUISHER)
	for s in spots:
		s.queue_free()
	await tests._coop_close(worlds)
