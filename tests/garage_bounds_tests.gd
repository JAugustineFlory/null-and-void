extends RefCounted
## The garage's edges: the driveway's barriers, and the van's shell and doors
## (Augustine's v0.9-beta2 notes: players walked off the driveway out of the world,
## and got inside the parked van by spamming jump and crouch).

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	await test_van_spam()
	await test_van_doors()
	await test_driveway()
	await test_coop_van_doors()


func _game() -> Node:
	return _tree.root.get_node("Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree.physics_frame


func _home() -> Array:
	_game().new_run(41)
	_game().open_at_home = true
	var world = load("res://scenes/world.tscn").instantiate()
	_tree.root.add_child(world)
	await _frames(30)
	var p: Player = world.player
	p.stand_up(true)
	p.local_control = false
	p.body = CrewBody.largest()
	return [world, world.home, p]


## Is garage-local point `at` inside the van's cab?
static func in_van(home, at: Vector3) -> bool:
	var d: Vector3 = at - home.VAN
	return absf(d.x) < 1.15 and absf(d.z) < 2.1 and at.y > 0.35 and at.y < 2.6


## From `from` (garage-local), walk at `target` mashing jump and crouch for `ticks`.
func _spam(home, p: Player, from: Vector3, target: Vector3, ticks: int) -> bool:
	p.global_position = home.to_global(from)
	p.velocity = Vector3.ZERO
	var got_in := false
	for i in ticks:
		var to: Vector3 = home.to_global(target)
		p.look_at(Vector3(to.x, p.global_position.y, to.z))
		p.controls.move = Vector2(0, -1)
		p.controls.crouch = (i / 4) % 2 == 0
		if i % 7 == 0:
			p.controls.jump = true
		await _tree.physics_frame
		if in_van(home, home.to_local(p.global_position)):
			got_in = true
	p.controls.move = Vector2.ZERO
	p.controls.crouch = false
	return got_in


func test_van_spam() -> void:
	print("Garage: the van's shell holds against jump-and-crouch spam")
	var r: Array = await _home()
	var world = r[0]
	var home = r[1]
	var p: Player = r[2]
	var van: Vector3 = home.VAN
	var tries := {
		"sliding door": [van + Vector3(-2.0, 0.1, 0.1), van + Vector3(0, 0.1, 0.1)],
		"driver door": [van + Vector3(-2.0, 0.1, -1.5), van + Vector3(0, 0.1, -1.5)],
		"passenger door": [van + Vector3(2.0, 0.1, -1.5), van + Vector3(0, 0.1, -1.5)],
		"back": [van + Vector3(0, 0.1, 3.2), van + Vector3(0, 0.1, 0)],
		"windscreen, off the bonnet": [van + Vector3(0, 0.1, -4.0), van + Vector3(0, 1.5, 0)],
		"roof": [van + Vector3(0, 2.75, 0.5), van + Vector3(0, 0, 0.5)],
	}
	for k in tries:
		var got_in: bool = await _spam(home, p, tries[k][0], tries[k][1], 600)
		_check.call(not got_in, "mashing jump and crouch at the van's %s doesn't get you inside" % k)
	world.queue_free()
	await _frames(2)


func test_van_doors() -> void:
	print("Garage: the van's doors open and shut with E")
	var r: Array = await _home()
	var world = r[0]
	var home = r[1]
	var p: Player = r[2]
	for key in ["w", "e", "side"]:
		var door: Dictionary = home.van_doors[key]
		var panel: Interactable = door.panel
		_check.call(panel.prompt == home.VAN_DOOR_OPEN and not home.van_open.get(key, false), "the %s door starts shut, offering to open" % key)
		panel.interact(p)
		await _frames(50)
		var open_now: bool = home.side_door.position.distance_to(home.SIDE_DOOR_OPEN) < 0.05 if key == "side" else absf(door.pivot.rotation.y - door.swing) < 0.01
		_check.call(home.van_open[key] and open_now and panel.prompt == home.VAN_DOOR_SHUT, "E opens it, and it offers to close")
		panel.interact(p)
		await _frames(50)
		var shut_now: bool = home.side_door.position.distance_to(door.shut) < 0.05 if key == "side" else absf(door.pivot.rotation.y) < 0.01
		_check.call(not home.van_open[key] and shut_now and panel.prompt == home.VAN_DOOR_OPEN, "and E again shuts it")
	# Shut, the doors still hold against the jump-and-crouch mash.
	var got_in: bool = await _spam(home, p, home.VAN + Vector3(-2.0, 0.1, -1.5), home.VAN + Vector3(0, 0.1, -1.5), 300)
	_check.call(not got_in, "shut again, the driver's door still holds")
	world.queue_free()
	await _frames(2)


## Run at each open side of the driveway, jumping and climbing: nobody gets past it.
func test_driveway() -> void:
	print("Garage: the driveway is fenced, so nobody walks off the world")
	var r: Array = await _home()
	var world = r[0]
	var home = r[1]
	var p: Player = r[2]
	var c: Vector3 = home.APRON_CENTER
	var half: Vector3 = home.APRON_SIZE / 2
	_check.call(["FenceW", "FenceE", "FenceBeside", "DrivewayGate"].all(func(n): return home.geo.find_child(n, true, false) != null),
		"a fence down both ends and past the garage, and a gate across the street end")
	var runs := {
		"west end": [c + Vector3(-half.x + 3.0, 0.1, 0), c + Vector3(-half.x - 5.0, 0.1, 0)],
		"east end": [c + Vector3(half.x - 3.0, 0.1, 0), c + Vector3(half.x + 5.0, 0.1, 0)],
		"street end": [c + Vector3(0, 0.1, -half.z + 3.0), c + Vector3(0, 0.1, -half.z - 5.0)],
		"side by the garage": [Vector3(12.0, 0.1, c.z), Vector3(12.0, 0.1, c.z + 10.0)],
	}
	for k in runs:
		p.global_position = home.to_global(runs[k][0])
		p.velocity = Vector3.ZERO
		var lowest := INF
		var out := false
		for i in 360:
			var to: Vector3 = home.to_global(runs[k][1])
			p.look_at(Vector3(to.x, p.global_position.y, to.z))
			p.controls.move = Vector2(0, -1)
			p.controls.sprint = true
			p.controls.crouch = (i / 4) % 2 == 0 and i > 200
			if i % 9 == 0:
				p.controls.jump = true
			await _tree.physics_frame
			var at: Vector3 = home.to_local(p.global_position)
			lowest = minf(lowest, at.y)
			if absf(at.x - c.x) > half.x or at.z < c.z - half.z or (at.x > home.SIZE.x / 2 and at.z > -home.SIZE.z / 2):
				out = true
		p.controls.move = Vector2.ZERO
		p.controls.sprint = false
		p.controls.crouch = false
		_check.call(not out and lowest > -0.5, "running, jumping and climbing at the driveway's %s, you stay on it" % k)
	world.queue_free()
	await _frames(2)


func test_coop_van_doors() -> void:
	print("Garage: co-op, a van door opened by anyone opens for everyone")
	_game().new_run(43)
	_game().open_at_home = true
	var worlds: Array = await _tree._coop_worlds(1)
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/world.tscn")
	var homes := machines.map(func(w): return w.home)
	var pc = machines[1].player
	homes[1].van_doors["e"].panel.interact(pc)  # the client opens the passenger door
	_check.call(await _until(func(): return homes.all(func(h): return h.van_open.get("e", false)), 120), "a client opens the passenger door, and it's open on every machine")
	homes[0].van_doors["e"].panel.interact(machines[0].player)
	_check.call(await _until(func(): return homes.all(func(h): return not h.van_open.get("e", true)), 120), "the host shuts it, and it's shut everywhere")
	_tree._coop_close(worlds)
	await _frames(2)


func _until(cond: Callable, frames: int = 600) -> bool:
	for i in frames:
		if cond.call():
			return true
		await _tree.physics_frame
	return cond.call()
