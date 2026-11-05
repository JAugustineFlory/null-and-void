extends RefCounted
## Walking the stairs between floors (Augustine, v0.9: "I would like to see players
## actually having to walk down the stairs, and open the door"): a real player body,
## on the keys, opens each floor's stair door, walks the flights down (or up) past
## every floor in between (Augustine, 2026-11-05: "the actual number of stairs") to
## the next floor's landing and out through its door, with no fade and nobody placed.
## Solo in the World for every trip (22 to 18, 18 to 10, 10 to G, G up to 9); in
## co-op, two machines walk 22 to 18, and on 10 to G one goes down on the stairs and
## the other walks back up from G to help them, since a downed player mustn't strand the crew.

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	await test_world_trips()
	await test_coop_world()
	await test_coop_downed()


func _game() -> Node:
	return _tree.root.get_node("/root/Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree.physics_frame


func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await _tree.physics_frame
	return cond.call()


## Every trip in one World, as the crew makes them: each floor's way down opened
## the way its story opens it, then walked.
func test_world_trips() -> void:
	print("Stairs: walking every trip between floors in the World, no fade")
	_game().new_run(21)
	_game().rourke_fate = "killed"  # 22 without Rourke's scenes: just the stairs
	var world = load("res://scenes/world.tscn").instantiate()
	_tree.root.add_child(world)
	await _frames(10)
	var p: Player = world.player
	_tree._lower_chapters_read([world])  # about the stairs: no huddle cuts in
	_tree._books_read([world])
	var times := []
	# 22 down to 18: the door's PIN goes through, floor 18 builds at the foot of the stairs.
	world.enter_wing(world.route_index("level_2"))
	var l2 = world.current
	await _frames(20)
	world.db.run_silent("UPDATE doors SET locked = 0, actuator_fault = 0 WHERE id = 'SEC-EXIT'")
	l2._update_door()
	var l3 = world.wings.get("level_3")
	_check.call(l3 != null and world.stairs.is_linked(Stairwell.of(l2.stair_door)), "once 22's stairs open, floor 18 builds and its stairs join 22's")
	_check.call(_plate(l2.stair_door, -1) == "21" and _plate(l3.stair_in, 1) == "19", "the landings round them are the real floors: 21 below 22, 19 above 18 (%s, %s)" % [_plate(l2.stair_door, -1), _plate(l3.stair_in, 1)])
	_check.call(Stairwell.of(l2.stair_door).find_children("BadgeReader*", "", false, false).size() >= 2, "every other floor's stair door has a badge reader beside it, lit red")
	var r: Dictionary = await _trip(world, p, l2.stair_door, l3.stair_in, true)
	_check.call(r.ok, "22 to 18: a real body opens 22's stair door, walks down the flights and out through 18's door %s" % [r])
	_check.call(r.passed == ["21", "20", "19"], "on the way it walks past 21, 20 and 19, each landing numbered (%s)" % [r.passed])
	times.append(["22", "18", 4, r.secs])
	_check.call(r.fade == 0.0 and r.handed and world.current == l3 and l3.active, "nothing fades, and the floor hands over once everyone's on 18's landing")
	_check.call(_game().completed_level == "level_2" and _game().next_level == "level_3" and root_net().profile.earned.has("achievement:floor_22"), "floor 22 is complete and earns its unlock")
	_check.call(not world.stairs.is_linked(Stairwell.of(l3.stair_in)) or not _crew_rides(world, Stairwell.of(l3.stair_in)), "and the stairs back up to 22 end at its shut door now")
	# 18 down to 10: Mercer's key.
	l3._on_key_taken(world.players.id_of(p))
	var l4 = world.wings.get("level_4")
	_check.call(l4 != null and world.stairs.is_linked(Stairwell.of(l3.stair_out)), "the key opens 18's stairs down, to 10")
	r = await _trip(world, p, l3.stair_out, l4.stair_in, true)
	_check.call(r.ok and r.fade == 0.0 and world.current == l4 and l4.active, "18 to 10: down the stairs and out on 10, no fade %s" % [r])
	_check.call(r.passed == ["17", "16", "15", "14", "13", "12", "11"], "past every floor from 17 to 11 (%s)" % [r.passed])
	times.append(["18", "10", 8, r.secs])
	_check.call(_game().completed_level == "level_3" and _game().next_level == "level_4", "floor 18 is complete, floor 10 is next")
	# 10 down to G: STAIR 1 opens at the accident.
	l4.stair_out.locked = false
	_check.call(_plate(l4.stair_out, -1) == "9" and _plate(l4.g_stair, 1) == "1", "10's stairs go down past 9, and G's up to 1")
	r = await _trip(world, p, l4.stair_out, l4.g_stair, true)
	_check.call(r.ok and r.fade == 0.0 and l4.on_ground and world.current == l4, "10 to G: down the stairs and out by the lifts on G, no fade %s" % [r])
	_check.call(r.passed == ["9", "8", "7", "6", "5", "4", "3", "2", "1"], "past every floor from 9 to 1 (%s)" % [r.passed])
	times.append(["10", "G", 10, r.secs])
	# G up to 9: locked in at the front, back up STAIR 1.
	l4.prepare_next()
	var l5 = world.wings.get("level_5")
	l4.sync.event("_finish")
	_check.call(await _until(func(): return world.stairs.is_linked(Stairwell.of(l5.stair_in)) and not p.input_locked, 1800), "after WARDEN's lines, STAIR 1 goes up to 9 and the crew can move")
	_check.call(_plate(l4.g_stair, 1) == "1" and _plate(l5.stair_in, -1) == "8", "G's stairs go up past 1, and 9's down to 8")
	r = await _trip(world, p, l4.g_stair, l5.stair_in, false)
	_check.call(r.ok and r.fade == 0.0 and world.current == l5 and l5.active, "G up to 9: up the stairs and out on 9, no fade %s" % [r])
	_check.call(r.passed == ["1", "2", "3", "4", "5", "6", "7", "8"], "past every floor from 1 to 8 (%s)" % [r.passed])
	times.append(["G", "9", 9, r.secs])
	_check.call(_game().completed_level == "level_4" and _game().next_level == "level_5", "floor 10 is complete, floor 9 is next")
	for t in times:
		print("    stairs %s to %s: %d storeys, %.1f s from the first step to the landing at walking pace" % t)
	world.queue_free()
	await _tree.process_frame


## Co-op in the World: host and client both walk from 22 down to 18. Play moves to
## 18 on both machines once both are on its landing, not before.
func test_coop_world() -> void:
	print("Stairs: co-op, two machines walk 22 down to 18")
	_game().new_run(22)
	_game().rourke_fate = "killed"
	var worlds: Array = await _tree._coop_worlds(1)
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/world.tscn")
	_tree._lower_chapters_read(machines)
	_tree._books_read(machines)
	var host = machines[0]
	var client = machines[1]
	for w in machines:
		w.enter_wing(w.route_index("level_2"))
	await _frames(20)
	for w in machines:
		w.db.run_silent("UPDATE doors SET locked = 0, actuator_fault = 0 WHERE id = 'SEC-EXIT'")
		w.current._update_door()
	var l2: Array = machines.map(func(w): return w.wings["level_2"])
	var l3: Array = machines.map(func(w): return w.wings["level_3"])
	# The host goes first, all the way to 18's landing: play stays on 22 for both.
	var r: Dictionary = await _trip(host, host.player, l2[0].stair_door, l3[0].stair_in, true, false, Vector3(-0.8, 0, -0.9))
	await _frames(20)
	_check.call(r.landed and machines.all(func(w): return w.current.wing_id == "level_2"), "the host alone on 18's landing: play stays on 22 until everyone's down %s" % [r])
	_check.call(not l3[0].stair_in.is_open and l3[0].stair_in.locked, "18's stair door won't open for the first one down")
	r = await _trip(client, client.player, l2[1].stair_door, l3[1].stair_in, true, false, Vector3(0.6, 0, -0.7))
	_check.call(r.landed, "the client walks down too %s" % [r])
	_check.call(await _until(func(): return machines.all(func(w): return w.current.wing_id == "level_3" and w.current.active), 300), "with both on 18's landing, play moves to 18 on both machines")
	var client_id: int = _tree.get_multiplayer(worlds[1].get_path()).get_unique_id()
	var puppet: Node3D = host.players.puppet(client_id)
	_check.call(puppet != null and puppet.global_position.distance_to(client.player.global_position) < 0.6, "the host sees the client on 18's landing, where they are")
	await _tree._coop_close(worlds)


## Co-op on 10 (its G floor is part of it): the host is first down to G's landing;
## the client, following, goes down on the stairs a floor and a half above it. The
## host walks back up off G's stairs onto 10's, past the floor numbered 1, helps
## them up, and both go down; only then is the crew on G.
func test_coop_downed() -> void:
	print("Stairs: co-op, a player downed on the stairs is reached and revived")
	_game().new_run(23)
	var worlds: Array = await _tree._coop_worlds(1)
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/level_4.tscn")
	for l in machines:
		for id in ["easy_sql_update", "easy_sql_insert"]:
			l.get_node("Huddle").done[id] = true
		l.stair_out.locked = false
	var host = machines[0]
	var client = machines[1]
	var client_id: int = _tree.get_multiplayer(worlds[1].get_path()).get_unique_id()
	var up: Node3D = Stairwell.of(host.stair_out)
	var n := Stairwell.storeys_between("10", "G")
	var route := _route(n, -1, Vector3(-0.8, 0, -0.9))
	# Where the client goes down: the half-landing two flights above G's landing, on
	# the side the flight from the floor numbered 2 comes down.
	var downed_at := Vector3(-0.9, -(n - 2) * Stairwell.STOREY - Stairwell.HALF, -5.0)
	var turn := Vector3(0.9, downed_at.y, -5.0)
	# The host walks all the way down to G's landing.
	var r: Dictionary = await _trip(host, host.player, host.stair_out, host.g_stair, true, false, Vector3(-0.8, 0, -0.9))
	await _frames(20)
	_check.call(r.landed and machines.all(func(l): return not l.on_ground), "the host on G's landing, alone: the crew isn't on G yet %s" % [r])
	var cp: Player = client.player
	await _open_from_lobby(client, cp, client.stair_out)
	var ok := true
	for w in route.slice(0, route.find(downed_at) + 1):
		ok = ok and await _walk(cp, func(): return client.stairs.place(cp, Stairwell.of(client.stair_out), w))
	cp.combat.go_down("test")
	await _frames(20)
	_check.call(ok and CrewVitals.is_down(cp) and client.stairs.progress(cp, Stairwell.of(client.stair_out)).e == n - 3, "the client goes down on the stairs, between the landings numbered 2 and 1 (%s)" % [client.stairs.progress(cp, Stairwell.of(client.stair_out))])
	await _frames(20)
	_check.call(machines.all(func(l): return not l.on_ground), "with someone down on the stairs, the crew still isn't on G")
	# Back up past the turn, off G's stairs and onto 10's, to the one who's down.
	var hp: Player = host.player
	var back := true
	var climb: Array = route.slice(route.find(turn), -1)
	climb.reverse()
	climb.append(Vector3(-0.5, downed_at.y, -4.9))
	for w in climb:
		back = back and await _walk(hp, func(): return host.stairs.place(hp, up, w))
	var puppet: Node3D = host.players.puppet(client_id)
	_check.call(back and hp.global_position.distance_to(puppet.global_position) < 1.6, "the host walks back up onto 10's stairs, counting back up past 1, and reaches them (%.1f m, %s)" % [hp.global_position.distance_to(puppet.global_position), host.stairs.progress(hp, up)])
	puppet.interact(hp)
	_check.call(await _until(func(): return not CrewVitals.is_down(cp) and cp.health > 0.0, 120), "and helps them up")
	# Both down to G's landing.
	var done := [false, false]
	var where := ["", ""]
	var walkers := [[host, hp, 0, Vector3(-0.8, 0, -0.9)], [client, cp, 1, Vector3(0.6, 0, -0.7)]]
	for wk in walkers:
		var w_level = wk[0]
		var w_p: Player = wk[1]
		var i: int = wk[2]
		var walk := func():
			var good := true
			for w in _route(n, -1, wk[3]).slice(route.find(turn)):
				good = good and await _walk(w_p, func(): return w_level.stairs.place(w_p, Stairwell.of(w_level.stair_out), w))
				if not good and where[i] == "":
					where[i] = "short of %s at %s" % [w, Stairwell.of(w_level.g_stair).global_transform.affine_inverse() * w_p.global_position]
			done[i] = good
		walk.call()
	_check.call(await _until(func(): return done[0] and done[1], 1800), "both walk down to G's landing %s" % [where])
	_check.call(await _until(func(): return machines.all(func(l): return l.on_ground), 300), "and with everyone there, the crew is on G on both machines")
	await _tree._coop_close(worlds)


func root_net() -> Node:
	return _tree.root.get_node("/root/Net")


## What a copied landing's plate says (Stairwell.relabel).
func _plate(door: Door, k: int) -> String:
	var l: Label3D = Stairwell.of(door).get_node_or_null("FloorLabel_%s" % (str(k) if k >= 0 else "m%d" % -k))
	return l.text.get_slice("FLOOR ", 1).strip_edges() if l else "?"


func _crew_rides(world: Node, holder: Node3D) -> bool:
	for l in world.stairs._links:
		if (l.upper == holder or l.lower == holder) and l.crew:
			return true
	return false


## One trip, as a player makes it: in the lobby, open `from`'s door, walk onto the
## landing and down (or up) every flight, past each floor's landing, to `to`'s
## landing; then (with `out`) open `to`'s door once it unlocks and walk out into its
## lobby. Reports how far it got, how dark the screen got, whether play handed
## over, the landings walked past (by their numbers), and how long the stairs took.
func _trip(world: Node, p: Player, from: Door, to: Door, down: bool, out := true, spot := Vector3(0, 0, -0.8)) -> Dictionary:
	var a := Stairwell.of(from)
	var b := Stairwell.of(to)
	var start := a  # where the floors in between are walked past
	var n := Stairwell.storeys_between(a.get_meta("floor"), b.get_meta("floor"))
	var r := {"ok": false, "landed": false, "fade": 0.0, "handed": false, "at": "", "end": Vector3.ZERO, "passed": [], "secs": 0.0}
	var wing: Node = world.get("current")
	var fade := [0.0]
	var s := -1 if down else 1
	var stairs: StairLinks = world.stairs
	var watch := func():
		var hud = world.hud
		fade[0] = maxf(fade[0], hud._fade.color.a)
		# On the next landing in the start's stairwell: what it's numbered.
		var local := start.global_transform.affine_inverse() * p.global_position - Vector3(0, s * Stairwell.STOREY, 0)
		if not stairs.progress(p, start).dest and absf(local.y) < 0.3 and local.z < -0.3 and local.z > Stairwell.LANDING_Z:
			var label: Label3D = start.get_node("FloorLabel_%s" % ("m1" if down else "1"))
			var floor_name := label.text.get_slice("FLOOR ", 1).strip_edges()
			if r.passed.is_empty() or r.passed.back() != floor_name:
				r.passed.append(floor_name)
	_tree.physics_frame.connect(watch)
	p.input_locked = false
	await _open_from_lobby(world, p, from)
	var ok := true
	var frames := [0]
	var count := func(): frames[0] += 1
	_tree.physics_frame.connect(count)
	for w in _route(n, s, spot):
		ok = ok and await _walk(p, func(): return stairs.place(p, start, w))
		if not ok:
			r.at = "stuck short of %s at %s, %s" % [w, start.global_transform.affine_inverse() * p.global_position, stairs.progress(p, start)]
			break
	_tree.physics_frame.disconnect(count)
	r.secs = frames[0] / float(Engine.physics_ticks_per_second)
	r.end = b.global_transform.affine_inverse() * p.global_position
	r.landed = ok and Stairwell.landing_box().has_point(r.end)
	if r.landed and out:
		ok = await _until(func(): return not to.locked, 300)
		r.handed = ok and world.get("current") != wing or (world.get("current") == wing and wing.get("on_ground") == true)
		if ok:
			to.interact(p)
			await _frames(60)
			ok = to.is_open and await _walk(p, func(): return b.global_transform * Vector3(0.3, 0, 1.6))
			if not ok:
				r.at = "couldn't get out through %s's door (open %s)" % [b.get_meta("floor"), to.is_open]
	r.ok = r.landed and ok
	r.fade = fade[0]
	_tree.physics_frame.disconnect(watch)
	return r


## The way from a stairwell's landing (just inside the door) `n` storeys down
## (`s` -1) or up, to `spot` on the last landing, in the start's space as if the
## stairs were stacked (StairLinks.place puts each point where it is now): each
## storey, along the landing to the flight, down it, across the half-landing,
## down the next to the landing below.
func _route(n: int, s: int, spot: Vector3) -> Array:
	var side := 0.9 * s
	var out := [Vector3(0, 0, -0.9)]
	for m in n:
		var y := m * s * Stairwell.STOREY
		if m > 0:
			out.append(Vector3(side, y, -1.3))
		out.append_array([Vector3(side, y, -2.1), Vector3(side, y + s * Stairwell.HALF, -5.0), Vector3(-side, y + s * Stairwell.HALF, -5.0),
			Vector3(-side, y + s * Stairwell.STOREY, -1.5)])
	out.append(spot + Vector3(0, n * s * Stairwell.STOREY, 0))
	return out


## In `from`'s lobby, clear of the leaf's swing, open the stair door.
func _open_from_lobby(world: Node, p: Player, door: Door) -> void:
	var h := Stairwell.of(door)
	p.global_transform = Transform3D(h.global_basis, h.global_transform * Vector3(0.5, 0.1, 1.6))
	p.velocity = Vector3.ZERO
	await _frames(10)
	if not door.is_open:
		door.interact(p)
		await _frames(60)


## On the keys toward wherever `goal` says (it can move), as a hand would (the
## test's hand: the keyboard's left alone).
func _walk(p: Player, goal: Callable, max_frames := 360, near := 0.3) -> bool:
	p.local_control = false
	for i in max_frames:
		var d: Vector3 = goal.call() - p.global_position
		d.y = 0.0
		if d.length() <= near:
			p.controls.move = Vector2.ZERO
			return true
		p.rotation.y = atan2(-d.x, -d.z)
		p.controls.move = Vector2(0, -1)
		await _tree.physics_frame
	p.controls.move = Vector2.ZERO
	return false
