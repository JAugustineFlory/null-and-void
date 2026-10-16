extends SceneTree
## Headless test runner. Usage:
##   godot --headless -s tests/run_tests.gd
## Exits with code 1 if any test fails.

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_facility_db()
	test_level_0_puzzles()
	test_level_1_data_every_seed()
	test_first_hints_show_working_queries()
	await test_screens_fill_window()
	await test_level_0_scene()
	await test_level_1_scene()
	await test_coop_level_0()
	await test_coop_level_1()
	await test_coop_six_players()
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  PASS  ", name)
	else:
		failed += 1
		print("  FAIL  ", name)


func test_facility_db() -> void:
	print("FacilityDB")
	var db := FacilityDB.new()
	db.load_seed("CREATE TABLE doors (id TEXT, locked INTEGER, actuator_fault INTEGER); INSERT INTO doors VALUES ('A', 1, 0), ('B', 1, 1);")
	var events := []
	db.door_changed.connect(func(id, locked, fault): events.append([id, locked, fault]))
	var r := db.execute("SELECT * FROM doors WHERE locked = 1")
	check(r.ok and r.rows.size() == 2 and r.columns == ["id", "locked", "actuator_fault"], "select returns rows and ordered columns")
	r = db.execute("SELEC * FROM doors")
	check(not r.ok and r.error.contains("syntax"), "syntax error is reported")
	check(FacilityDB.explain_error(r.error).contains("parse"), "syntax error gets a plain-English translation")
	r = db.execute("UPDATE doors SET locked = 0 WHERE id = 'A'")
	check(r.ok and r.changes == 1, "update reports rows changed")
	check(events.has(["A", false, false]), "door change is pushed to the world")
	r = db.execute("UPDATE doors SET locked = 0")
	check(r.changes == 2, "update without WHERE changes every row")
	r = db.execute("ATTACH DATABASE 'x.db' AS x")
	check(not r.ok, "ATTACH is blocked")
	db.reset()
	check(int(db.run_silent("SELECT locked FROM doors WHERE id = 'A'")[0]["locked"]) == 1, "reset restores seed data")


func test_level_0_puzzles() -> void:
	print("Level 0 puzzles")
	var db := FacilityDB.new()
	db.load_seed(FileAccess.get_file_as_string("res://data/level_0.sql"))
	var peek := Puzzle.new("peek", "SELECT text FROM memo_fragments", ["text"], false)
	var memo := Puzzle.new("memo", "SELECT text FROM memo_fragments ORDER BY piece_no", ["text"], true)
	check(peek.matches(db, db.execute("SELECT * FROM memo_fragments;")), "SELECT * solves the peek")
	check(not memo.matches(db, db.execute("SELECT * FROM memo_fragments")), "unsorted rows don't solve the memo")
	check(memo.matches(db, db.execute("SELECT * FROM memo_fragments ORDER BY piece_no")), "ORDER BY piece_no solves the memo")
	check(memo.matches(db, db.execute("select TEXT from memo_fragments order by piece_no asc")), "lowercase and ASC also work")
	check(not memo.matches(db, db.execute("SELECT * FROM memo_fragments ORDER BY piece_no DESC")), "reverse order doesn't solve the memo")
	check(not memo.matches(db, db.execute("SELECT piece_no FROM memo_fragments ORDER BY piece_no")), "missing the text column doesn't count")
	var memo_text := db.run_silent("SELECT text FROM memo_fragments ORDER BY piece_no")
	check(str(memo_text[0]["text"]).begins_with("If you are reading this") and str(memo_text[-1]["text"]) == "-- I.V.", "memo reads in the right order")


func test_level_1_data_every_seed() -> void:
	print("Level 1 data, 50 seeds")
	var puzzle := Puzzle.new("controller", "SELECT id FROM door_controllers WHERE zone = 'A' AND status = 'fault'", ["id"], false)
	var all_ok := true
	var never_guessable := true
	var all_explained := true
	var answers := {}
	for s in 50:
		var data := Level1Data.build(s)
		var db := FacilityDB.new()
		db.load_seed(data.sql)
		var rows := db.run_silent(puzzle.solution_sql)
		var n := int(str(data.answer).trim_prefix("DC-"))
		if rows.size() != 1 or rows[0]["id"] != data.answer or n < 1 or n > 8:
			all_ok = false
		if not puzzle.matches(db, db.execute("SELECT * FROM door_controllers WHERE status = 'fault' AND zone = 'A';")):
			all_ok = false
		if puzzle.matches(db, db.execute("SELECT * FROM door_controllers WHERE zone = 'A'")) or puzzle.matches(db, db.execute("SELECT * FROM door_controllers WHERE status = 'fault'")):
			never_guessable = false
		if not db.run_silent("SELECT id FROM door_controllers WHERE status != 'ok' AND id != '%s' AND note = 'normal'" % data.answer).is_empty():
			all_explained = false
		answers[data.answer] = true
	check(all_explained, "every other faulted or offline controller has a note saying why")
	check(all_ok, "exactly one zone-A fault on a physical rack, and AND finds it")
	check(never_guessable, "a single condition is never enough")
	check(answers.size() >= 5, "the answer varies between runs (%d different racks)" % answers.size())


func _hint_query(hint: String) -> String:
	var start := hint.find("[color=#ffffff]") + "[color=#ffffff]".length()
	return hint.substr(start, hint.find("[/color]", start) - start)


func test_first_hints_show_working_queries() -> void:
	print("First hints")
	var l0 = load("res://scripts/levels/level_0.gd").new()
	var db := FacilityDB.new()
	db.load_seed(FileAccess.get_file_as_string("res://data/level_0.sql"))
	for p in [l0.peek_puzzle, l0.memo_puzzle]:
		var q := _hint_query(p.hints[0])
		check(q != "" and p.matches(db, db.execute(q)), "%s: first hint's query solves it (%s)" % [p.id, q])
	l0.free()
	var l1 = load("res://scripts/levels/level_1.gd").new()
	var ok := true
	for s in 20:
		var d := FacilityDB.new()
		d.load_seed(Level1Data.build(s).sql)
		if not l1.controller_puzzle.matches(d, d.execute(_hint_query(l1.controller_puzzle.hints[0]))):
			ok = false
	check(ok, "controller: first hint's query solves it on every seed")
	l1.free()


func test_screens_fill_window() -> void:
	print("Menu screens")
	var win := root.get_visible_rect().size
	for path in ["res://scenes/main_menu.tscn", "res://scenes/field_notes.tscn", "res://scenes/lobby.tscn"]:
		var screen: Control = load(path).instantiate()
		root.add_child(screen)
		await process_frame
		await process_frame
		check(screen.size.is_equal_approx(win), "%s fills the window (%s vs %s)" % [path.get_file(), screen.size, win])
		var inside := true
		for b in screen.find_children("*", "Button", true, false):
			var r: Rect2 = b.get_global_rect()
			if r.position.x < 0 or r.position.y < 0 or r.end.x > win.x or r.end.y > win.y:
				inside = false
		check(inside, "%s buttons are fully on screen" % path.get_file())
		screen.queue_free()
		await process_frame


func test_level_0_scene() -> void:
	print("Level 0 scene")
	var level = load("res://scenes/level_0.tscn").instantiate()
	root.add_child(level)
	for i in 30:
		await physics_frame
	check(level.player != null and level.player.is_inside_tree(), "level 0 loads with a player")
	check(level.player.global_position.y > -1.0, "player stands on the floor")
	level.desk_terminal.enabled = true
	level.terminal_ui.terminal = level.desk_terminal
	level.terminal_ui.run("SELECT * FROM memo_fragments")
	check(level.peek_puzzle.solved, "terminal run solves the peek")
	level.terminal_ui.run("SELECT * FROM memo_fragments ORDER BY piece_no")
	check(level.memo_puzzle.solved, "terminal run solves the memo")
	check(_game().query_log.size() >= 2 and _game().concepts_learned.has("ORDER BY"), "queries are logged for Field Notes")
	level.queue_free()
	await process_frame


func test_level_1_scene() -> void:
	print("Level 1 scene")
	_game().new_run(7)
	var level = load("res://scenes/level_1.tscn").instantiate()
	root.add_child(level)
	for i in 30:
		await physics_frame
	check(level.doors["SRA-EXIT"].is_open == false, "exit starts locked")
	level._on_trapped(null)
	check(level.terminal.locked, "Rourke locks the terminal")
	level.terminal_ui.terminal = level.terminal
	level.terminal_ui.run("SELECT * FROM door_controllers")
	check(not level.controller_puzzle.solved, "locked terminal refuses queries")
	level.player.global_position = Vector3(-6.4, 0.1, -7.5)  # far corner, behind the racks
	level.rourke.global_position = Vector3(0, 0, 4)
	level.rourke.start_chase(level.player)
	var start_dist: float = level.rourke.global_position.distance_to(level.player.global_position)
	for i in 240:
		await physics_frame
	var end_dist: float = level.rourke.global_position.distance_to(level.player.global_position)
	check(end_dist < start_dist - 4.0, "Rourke chases around the racks (%.1f m -> %.1f m)" % [start_dist, end_dist])
	level.rourke.state = Rourke.State.IDLE
	level._on_rourke_resolved("tied")
	check(not level.terminal.locked and _game().rourke_fate == "tied", "taking the badge unlocks the terminal")
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = 'A' AND status = 'fault'")
	check(level.controller_puzzle.solved, "WHERE + AND solves the controller puzzle")
	var healthy: String = level.db.run_silent("SELECT id FROM door_controllers WHERE status = 'ok' AND location LIKE 'Server Room A%'")[0]["id"]
	level._on_panel(null, healthy)
	check(level.panels_locked_until == 0.0, "pressing a healthy rack explains itself without a lockout")
	var wrong: String = level.db.run_silent("SELECT id FROM door_controllers WHERE zone = 'A' AND status = 'offline'")[0]["id"]
	level._on_panel(null, wrong)
	check(level.doors["SRA-EXIT"].is_open == false and level.panels_locked_until > 0.0, "an offline zone-A rack does not open the exit")
	level.panels_locked_until = 0.0
	level._on_panel(null, level.answer)
	check(level.doors["SRA-EXIT"].is_open, "resetting the right rack opens the exit")
	level.queue_free()
	await process_frame


# --- Co-op ---------------------------------------------------------------------
# Each "machine" is a SubViewport with its own 3D world and its own
# SceneMultiplayer, connected over real ENet on localhost.

var _next_port := 17800


## Start a host and `clients` clients. Returns the worlds, host first.
func _coop_worlds(clients: int) -> Array:
	_next_port += 1
	var worlds := []
	for i in clients + 1:
		var vp := SubViewport.new()
		vp.name = "Machine%d" % i
		vp.own_world_3d = true
		vp.size = Vector2i(320, 180)
		root.add_child(vp)
		var mp := SceneMultiplayer.new()
		set_multiplayer(mp, vp.get_path())
		var peer := ENetMultiplayerPeer.new()
		if i == 0:
			peer.create_server(_next_port, 6)
		else:
			peer.create_client("127.0.0.1", _next_port)
		mp.multiplayer_peer = peer
		worlds.append(vp)
	for f in 300:
		await process_frame
		if get_multiplayer(worlds[0].get_path()).get_peers().size() == clients:
			break
	return worlds


func _coop_load(worlds: Array, scene: String) -> Array:
	var levels := []
	for w in worlds:
		var level = load(scene).instantiate()
		w.add_child(level)
		levels.append(level)
	for f in 300:
		await physics_frame
		if levels.all(func(l): return l.sync._begun):
			break
	for f in 10:
		await physics_frame
	return levels


func _coop_close(worlds: Array) -> void:
	for w in worlds:
		get_multiplayer(w.get_path()).multiplayer_peer.close()
		w.queue_free()
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _table(level: Node, sql: String) -> String:
	return JSON.stringify(level.db.run_silent(sql))


func test_coop_level_0() -> void:
	print("Co-op: Level 0 with a host and two clients")
	_game().new_run(11)
	var worlds := await _coop_worlds(2)
	check(get_multiplayer(worlds[0].get_path()).get_peers().size() == 2, "two clients connect to the host")
	var levels := await _coop_load(worlds, "res://scenes/level_0.tscn")
	var host = levels[0]
	var c1 = levels[1]
	var c2 = levels[2]
	check(levels.all(func(l): return l.sync._begun), "every machine starts the level together")
	check(levels.all(func(l): return l.players.count() == 3), "everyone sees three players")
	check(host.player.global_position.distance_to(c1.player.global_position) > 0.5, "players spawn apart")

	c1.player.global_position = Vector3(3, 0.1, 3)
	await _frames(30)
	var c1_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()
	check(host.players.puppet(c1_id).global_position.distance_to(Vector3(3, 0.1, 3)) < 0.3, "the host sees a client move")
	check(c2.players.puppet(c1_id).global_position.distance_to(Vector3(3, 0.1, 3)) < 0.3, "another client sees it too (relayed by the host)")

	c1.terminal_ui.terminal = c1.desk_terminal
	c1.terminal_ui.run("SELECT * FROM memo_fragments")
	await _frames(10)
	check(host.peek_puzzle.solved and c1.peek_puzzle.solved and c2.peek_puzzle.solved, "a client's query solves the puzzle for everyone")
	check(host.desk_terminal.transcript.any(func(l): return l.contains("SELECT * FROM memo_fragments")), "the query shows on the host's copy of that terminal")
	check(c2.desk_terminal.transcript.any(func(l): return l.contains("Those scraps are out of order")), "WARDEN's reply shows on every copy")

	c2.terminal_ui.terminal = c2.desk_terminal
	c2.terminal_ui.run("INSERT INTO visitors (name) VALUES ('Intruder')")
	await _frames(10)
	var dump := "SELECT * FROM visitors ORDER BY rowid"
	check(_table(host, dump) == _table(c1, dump) and _table(c1, dump) == _table(c2, dump) and _table(host, dump).contains("Intruder"), "a write lands in every machine's copy of the database")

	for l in levels:
		l.walkies.enabled = true
	c2.walkies.interact(c2.player)
	await _frames(10)
	check(levels.all(func(l): return not is_instance_valid(l.walkies) or l.walkies.is_queued_for_deletion()), "a client picking up the walkies is seen by everyone")

	get_multiplayer(worlds[2].get_path()).multiplayer_peer.close()
	await _frames(30)
	check(host.players.count() == 2 and c1.players.count() == 2, "a player who drops out disappears for the others")
	await _coop_close(worlds)


func test_coop_level_1() -> void:
	print("Co-op: Level 1 with a host and a client")
	_game().new_run(5)
	var worlds := await _coop_worlds(1)
	var levels := await _coop_load(worlds, "res://scenes/level_1.tscn")
	var host = levels[0]
	var client = levels[1]
	var client_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()

	host.player.global_position = Vector3(0, 0.1, 3)
	client.player.global_position = Vector3(0, 0.1, 12.5)
	await _frames(30)
	check(not host.terminal.locked, "the trap waits while someone is still outside")
	client.player.global_position = Vector3(1, 0.1, 3)
	await _frames(30)
	check(host.terminal.locked and client.terminal.locked, "the trap springs once everyone is inside")
	check(host.rourke.max_hits == Rourke.MAX_HITS + 2, "Rourke is tougher with two players (%d hits)" % host.rourke.max_hits)

	host.rourke.global_position = Vector3(-3, 0, 5)
	await _frames(20)
	check(client.rourke.global_position.distance_to(host.rourke.global_position) < 1.0, "clients see Rourke where the host has him")
	var before: int = host.rourke.hits_left
	host.rourke.state = Rourke.State.CHASE
	client.rourke.take_hit(client.player)
	await _frames(10)
	check(host.rourke.hits_left == before - 1, "a client's strike lands on the host's Rourke")

	var hp: float = client.player.health
	host.players.puppet(client_id).take_damage(10.0)
	await _frames(10)
	check(client.player.health == hp - 10.0, "damage reaches the player it was meant for")

	host.rourke.state = Rourke.State.IDLE
	host.sync.event("_on_rourke_resolved", ["tied"])
	await _frames(10)
	check(not client.terminal.locked and client.has_badge, "the badge unlocks the terminal for everyone")

	var wrong: String = host.db.run_silent("SELECT id FROM door_controllers WHERE zone = 'A' AND status = 'offline'")[0]["id"]
	client.rack_panels[wrong].interact(client.player)
	await _frames(10)
	check(host.panels_locked_until > 0.0 and client.panels_locked_until > 0.0, "a wrong rack locks the panels for everyone")

	client.terminal_ui.terminal = client.terminal
	client.terminal_ui.run("UPDATE doors SET locked = 0 WHERE id = 'SRA-EXIT'")
	await _frames(10)
	check(host.doors["SRA-EXIT"].is_open and client.doors["SRA-EXIT"].is_open, "a door opened by a client's query opens for everyone")
	var dump := "SELECT * FROM doors ORDER BY id"
	check(_table(host, dump) == _table(client, dump), "the doors table matches on both machines")
	await _coop_close(worlds)


func test_coop_six_players() -> void:
	print("Co-op: six players")
	_game().new_run(3)
	var worlds := await _coop_worlds(5)
	check(get_multiplayer(worlds[0].get_path()).get_peers().size() == 5, "five clients connect")
	var levels := await _coop_load(worlds, "res://scenes/level_0.tscn")
	check(levels.all(func(l): return l.sync._begun and l.players.count() == 6), "all six start together and see each other")
	var spots := {}
	for l in levels:
		spots[Vector2i(roundi(l.player.global_position.x * 10), roundi(l.player.global_position.z * 10))] = true
	check(spots.size() == 6, "six different spawn spots")
	await _coop_close(worlds)


func _game() -> Node:
	return root.get_node("Game")
