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


## A floor, the player at `at` looking down -Z, and the world's Counterplay.
func arena(at := Vector3(0, 0.1, 5)) -> Array:
	var a := Node3D.new()
	t.root.add_child(a)
	Greybox.box(a, Vector3(0, -0.1, 0), Vector3(60, 0.2, 60), Color.GRAY, "Floor")
	var p := Player.new()
	p.local_control = false
	p.position = at
	a.add_child(p)
	var np := NetPlayers.create(a, p)
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
	hold(p, Counterplay.EXTINGUISHER)
	cp.blasts_left = 2
	check(cp.prompt_for(p) == Counterplay.THROW_PROMPT, "an extinguisher in your hands: \"%s\"" % Counterplay.THROW_PROMPT)
	c.activate()
	check(cp.throw_held() and not p.inventory.has(Counterplay.EXTINGUISHER), "thrown, it leaves your hands")
	var thrown: ThrownItem = a.find_children("*", "ThrownItem", true, false)[0] if a.find_children("*", "ThrownItem", true, false).size() > 0 else null
	check(thrown != null and not thrown.enabled, "it flies")
	check(await until(func(): return c.state == "stunned", 90), "it hits the Custodian: a flinch")
	check(await until(func(): return thrown.enabled, 90) and thrown.global_position.y < 0.4, "and lands on the floor")
	check(thrown.get_prompt(p) == "[E] Pick up fire extinguisher", "for anyone to pick up again")
	thrown.interact(p)
	await frames(3)
	check(p.inventory.has(Counterplay.EXTINGUISHER) and cp.blasts_left == 2 and not is_instance_valid(thrown), "picked up, it still has the blasts it had")
	# Thrown at nothing: it lands out in front.
	c.queue_free()
	await frames(2)
	hold(p, Counterplay.EXTINGUISHER)
	check(cp.throw_held(), "(thrown again)")
	var lands := func():
		var found := a.find_children("*", "ThrownItem", true, false)
		return found.size() > 0 and found[0].enabled
	await until(lands, 150)
	var found := a.find_children("*", "ThrownItem", true, false)
	var far: ThrownItem = found[0] if found.size() > 0 else null
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
	p.stand_up(true)
	await frames(5)
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
	var landed := func(l):
		var f: Array = l.find_children("Thrown*", "ThrownItem", true, false)
		return f.size() > 0 and f[0].enabled
	check(await until(func(): return landed.call(host) and landed.call(client), 180), "it lands on every machine")
	var hi: ThrownItem = host.find_children("Thrown*", "ThrownItem", true, false)[0]
	var ci: ThrownItem = client.find_children("Thrown*", "ThrownItem", true, false)[0]
	check(hi.global_position.distance_to(ci.global_position) < 0.05, "in the same place")
	hi.interact(host.player)
	# (Both machines share one Game.inventory in a test, so only the floors can show who took it.)
	check(await until(func(): return host.player.inventory.has(Counterplay.EXTINGUISHER) and not is_instance_valid(ci), 60),
		"the host picks it up: it's gone from the client's floor too")
	host.player.inventory.remove(Counterplay.EXTINGUISHER)
	for s in spots:
		s.queue_free()
	await tests._coop_close(worlds)
