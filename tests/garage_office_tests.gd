extends RefCounted
## The garage's secret (GarageOffice, ArchiveTerminal): the locked corner door,
## its hidden key and riddle, the back office, and the old PC's menu and query mode.

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	var net := _tree.root.get_node("Net")
	var real_profile = net.profile
	net.profile = Profile.new()  # in memory, so tests never touch a real save
	await test_office()
	await test_coop_office()
	net.profile = real_profile


func _game() -> Node:
	return _tree.root.get_node("Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree.physics_frame


## What a look along `from` -> `to` hits first in `level`'s world, or null.
func _aim(level: Node3D, from: Vector3, to: Vector3) -> Object:
	var q := PhysicsRayQueryParameters3D.create(level.to_global(from), level.to_global(to))
	return level.get_world_3d().direct_space_state.intersect_ray(q).get("collider")


func test_office() -> void:
	print("Garage: the locked corner door and the back office")
	_game().new_run(31)
	_game().open_at_home = true
	var world = load("res://scenes/world.tscn").instantiate()
	_tree.root.add_child(world)
	await _frames(30)
	var home = world.home
	var office = home.office
	var p: Player = world.player
	var spots: Array = office.SPOTS
	_check.call(spots.size() == 3 and spots.map(func(s): return s.riddle).filter(func(r): return r != "").size() == 3 and office.KEY_AT.size() == 3,
		"the spare key has three hiding places, each with its own riddle")
	_check.call(office.spot == spots[31 % 3] and office.spot != spots[32 % 3], "which one is picked from the run's seed, so a walkthrough can't name it")
	var riddle: Label3D = office.door_pivot.find_child("Riddle", true, false)
	_check.call(riddle != null and riddle.text == office.spot.riddle, "its riddle is on a sticky on the door")
	var key_at: Vector3 = office.KEY_AT[office.spot.id]
	_check.call(home.to_local(office.key.global_position).distance_to(key_at) < 0.01, "and the key is where the riddle says")
	var near := key_at + Vector3(0.0, 0.5, 0.0) if office.spot.id == "coffee" else key_at + Vector3(0.0, 0.1, 0.8)
	_check.call(_aim(home, near, key_at) == office.key, "looking at its hiding place finds the key, not the tin or glove round it")
	var doorway: Vector3 = home.SIDE_DOOR + Vector3(0.6, 1.0, 0)
	var inside: Vector3 = home.SIDE_DOOR + Vector3(-1.0, 1.0, 0)
	_check.call(_aim(home, doorway, inside) == office.door, "the door is shut: you can't see or walk into the office")
	office.door.interact(p)
	await _frames(2)
	_check.call(not office.unlocked and home.hud._notice.text == office.LOCKED, "trying it without the key: it's locked")
	office.key.interact(p)
	await _frames(2)
	_check.call(office.key_holder != 0 and not office.key.visible and office.door.prompt == office.UNLOCK_PROMPT, "you take the key, and the door now offers to unlock")
	office.door.interact(p)
	await _frames(90)
	_check.call(office.unlocked and _aim(home, doorway, inside) == null, "with it, the door swings open into the office")
	_check.call(home.geo.find_child("OldPC", true, false) != null and office.pc.enabled, "where the crew's old PC is")

	# The PC: a menu anyone can browse, and real SQL on the same tables.
	_game().solve_case("test_case", "Somebody's sandwich, in the server room fridge.")
	var prof: Profile = _tree.root.get_node("Net").profile
	_check.call(prof.cases.has("test_case"), "solving a case puts it on your profile's list of cases closed")
	prof.earned = ["achievement:book_easy_sql"]
	office.pc.interact(p)
	await _frames(3)
	var term = home.find_child("ArchiveTerminal", true, false)
	_check.call(term != null and p.input_locked and term.box.find_child("Section_crew", true, false) != null and term.box.find_child("Query", true, false) != null,
		"sitting at it opens its menu, crew files to query mode, and holds you still")
	_check.call(term.page == "menu" and term.is_ancestor_of(_tree.root.gui_get_focus_owner()), "with a menu item picked, so a controller can use it")
	term.show_page("crew")
	await _frames(2)
	var text := " ".join(term.box.find_children("*", "Label", true, false).map(func(l): return l.text))
	_check.call(text.contains("June Whitaker") and text.contains("Walt Henley") and text.contains(term.CREW_NOTES.june), "the crew files list every crew member, with Maddison's note")
	term.show_page("achievements")
	await _frames(2)
	text = " ".join(term.box.find_children("*", "Label", true, false).map(func(l): return l.text))
	_check.call(text.contains("Required Reading") and text.contains(term.SECRET) and not text.contains("Mercer's Tape"), "achievements: what you've earned, and secrets you haven't found as ???")
	term.show_page("cases")
	await _frames(2)
	text = " ".join(term.box.find_children("*", "Label", true, false).map(func(l): return l.text))
	_check.call(text.contains("Somebody's sandwich"), "and the cases you've closed")
	term.show_page("query")
	await _frames(2)
	term._query.text = "SELECT name FROM crew WHERE age = '60s';"
	var res: Dictionary = term.run_query()
	_check.call(res.ok and res.rows.size() == 1 and term._result.text.contains("June Whitaker"), "query mode runs real SQL on the same tables")
	term._query.text = "DELETE FROM crew;"
	res = term.run_query()
	_check.call(not res.ok and term.db.execute("SELECT * FROM crew;").rows.size() == 12, "but it's read-only: nothing can be deleted")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	_tree.root.push_input(cancel)
	await _frames(2)
	_check.call(term.page == "menu", "B goes back to the menu")
	_tree.root.push_input(cancel)
	await _frames(3)
	_check.call(not is_instance_valid(term) or not term.is_inside_tree(), "and again logs off")
	_check.call(not p.input_locked, "letting you move again")
	world.queue_free()
	await _frames(2)


func test_coop_office() -> void:
	print("Garage: co-op, one key opens the office for everyone")
	_game().new_run(33)
	_game().open_at_home = true
	var worlds: Array = await _tree._coop_worlds(1)
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/world.tscn")
	var homes := machines.map(func(w): return w.home)
	var ph = machines[0].player
	var pc = machines[1].player
	_check.call(homes[0].office.spot == homes[1].office.spot, "the key is in the same place on every machine")
	homes[1].office.key.interact(pc)  # the client finds it
	_check.call(await _until(func(): return homes[0].office.key_holder != 0 and not homes[0].office.key.visible and not homes[1].office.key.visible, 120),
		"a client takes the key, and it's gone on every machine")
	homes[0].office.door.interact(ph)
	await _frames(10)
	_check.call(not homes[0].office.unlocked and homes[0].hud._notice.text == homes[0].office.LOCKED, "the host doesn't have it: still locked for them")
	homes[1].office.door.interact(pc)
	_check.call(await _until(func(): return homes[0].office.unlocked and homes[1].office.unlocked, 120), "the client unlocks it, and it opens for everyone")
	_tree._coop_close(worlds)
	await _frames(2)


func _until(cond: Callable, frames: int = 600) -> bool:
	for i in frames:
		if cond.call():
			return true
		await _tree.physics_frame
	return cond.call()
