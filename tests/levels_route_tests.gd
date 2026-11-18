extends RefCounted
## A floor picked from Levels plays inside the building, like a full run (Augustine,
## v0.9-beta2: "after every level it says, 'to be continued' ... I had to exit to the
## menu and restart the lobby after almost every level"). Every floor opens the World
## at that floor, with the crew at its start, and play carries on into the next one.

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	test_levels_open_the_building()
	await test_every_floor_carries_on()


func _game() -> Node:
	return _tree.root.get_node("/root/Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree.physics_frame


## Every floor on the Levels screen, and every floor of the route, opens the World.
func test_levels_open_the_building() -> void:
	print("Levels: every floor opens inside the building")
	var keys: Array = World.ROUTE.map(func(e): return e.key)
	_check.call(keys == _game().WINGS, "the Game's floors are the World's route, in order")
	var all_open := true
	for entry in LevelSelect.FLOORS:
		_game().new_run(3)
		var scene: String = _game().open_for(entry.key)
		all_open = all_open and scene == "world" and not _game().open_at_home and _game().open_at_wing == keys.find(entry.key)
	_check.call(all_open, "each floor on the Levels screen opens the World at that floor")
	_game().new_run(3)
	_check.call(_game().open_for("movement_gym") == "movement_gym" and _game().open_for("menu") == "menu" and _game().open_at_wing == 0, "the gym and the menus open as themselves")


## Opened at each floor: that floor is the one in play, the crew stands at its start,
## nothing before it is built, and finishing it moves play on to the next floor.
func test_every_floor_carries_on() -> void:
	print("Levels: every floor carries on into the next")
	for i in World.ROUTE.size():
		var key: String = World.ROUTE[i].key
		_game().new_run(40 + i)
		_game().open_for(key)
		var world = load("res://scenes/world.tscn").instantiate()
		_tree.root.add_child(world)
		await _frames(30)
		var here: LevelBase = world.current
		var p: Player = world.player
		_check.call(here != null and here.wing_id == key and here.active, "%s opens with that floor in play" % key)
		_check.call(p.global_position.distance_to(here.player_spawn(0).origin) < 1.5, "%s: the crew starts at the floor's own start (at %s)" % [key, here.to_local(p.global_position)])
		_check.call(range(i).all(func(j): return not world.wings.has(World.ROUTE[j].key)), "%s: no floor before it is built" % key)
		var car = here.get("arrival_lift")
		if car is Elevator:
			for f in 150:
				if car.open_amount > 0.9:
					break
				await _tree.physics_frame
			_check.call(car.open_amount > 0.9, "%s: its arrival car stands open, so nobody's shut in it" % key)
		if i + 1 < World.ROUTE.size():
			var next_key: String = World.ROUTE[i + 1].key
			world.wing_finished(here)
			await _frames(5)
			_check.call(world.current != null and world.current.wing_id == next_key and world.current.active, "%s: finishing it moves play on to %s" % [key, next_key])
		world.queue_free()
		await _frames(10)
