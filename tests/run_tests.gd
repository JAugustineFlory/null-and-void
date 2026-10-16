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
	test_voice_script()
	await test_voice_playback()
	test_facility_api()
	test_level_2_data_every_seed()
	test_level_2_hints()
	await test_screens_fill_window()
	await test_level_0_scene()
	await test_level_1_scene()
	await test_level_2_scene()
	await test_level_2_routes()
	test_wing_seeds_in_order()
	test_reset_keeps_earlier_wings()
	await test_world()
	await load("res://tests/movement_tests.gd").new().run(self, check)
	await load("res://tests/art_tests.gd").new().run(self, check)
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
	db.load_seed("INSERT INTO doors (id, locked, actuator_fault) VALUES ('A', 1, 0), ('B', 1, 1);")
	var events := []
	db.door_changed.connect(func(id, locked, fault): events.append([id, locked, fault]))
	var r := db.execute("SELECT id, locked, actuator_fault FROM doors WHERE locked = 1")
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
	check(l0.memo_puzzle.hints[1].contains("ORDER BY piece_no") and not l0.memo_puzzle.hints[1].contains("visitors"),
		"memo: second hint names the real column, not an example table")
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


func test_voice_script() -> void:
	print("Voice script")
	var speakers_ok := true
	var scenes_ok := true
	for id in VoiceLines.LINES:
		var l: Dictionary = VoiceLines.LINES[id]
		if not VoiceLines.CHARACTERS.has(l["speaker"]):
			speakers_ok = false
		if VoiceLines.scene(l["scene"]).is_empty():
			scenes_ok = false
	check(speakers_ok, "every line's speaker has a character entry")
	var no_note := VoiceLines.LINES.keys().filter(func(id): return VoiceLines.LINES[id]["note"] == "")
	check(no_note.is_empty(), "every line has an acting note %s" % [no_note])
	check(scenes_ok, "every line belongs to a scene")

	var used := {}
	var unknown := []
	var unvoiced := []
	var id_re := RegEx.create_from_string("\"(l\\d+_[a-z0-9_]+)\"")
	var scene_re := RegEx.create_from_string("ids_in_scene\\(\"([a-z0-9_]+)\"\\)")
	var say_re := RegEx.create_from_string("say\\(\"(ROURKE|WARDEN|VALE|MERCER)\"")
	for f in DirAccess.get_files_at("res://scripts/levels"):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/levels/" + f)
		for m in scene_re.search_all(src):
			if VoiceLines.scene(m.get_string(1)).is_empty():
				unknown.append(m.get_string(1))
			for id in VoiceLines.ids_in_scene(m.get_string(1)):
				used[id] = true
		for m in id_re.search_all(src):
			if VoiceLines.has_line(m.get_string(1)):
				used[m.get_string(1)] = true
			elif VoiceLines.scene(m.get_string(1)).is_empty():
				unknown.append(m.get_string(1))
		for m in say_re.search_all(src):
			unvoiced.append("%s: %s" % [f, m.get_string(1)])
	check(unknown.is_empty(), "levels only play lines that are in the script %s" % [unknown])
	check(unvoiced.is_empty(), "character lines go through hud.line so recordings play %s" % [unvoiced])
	var unused := []
	for id in VoiceLines.LINES:
		if VoiceLines.scene(VoiceLines.LINES[id]["scene"]).get("wired", false) and not used.has(id):
			unused.append(id)
	check(unused.is_empty(), "every line marked as in the game is played by a level %s" % [unused])

	var in_sync := FileAccess.get_file_as_string(ScriptDocs.SCRIPT_PATH) == ScriptDocs.script_markdown() \
		and FileAccess.get_file_as_string(ScriptDocs.RECORDING_LIST_PATH) == ScriptDocs.recording_list_markdown()
	check(in_sync, "docs/script/ matches voice_lines.gd (run tools/write_script_docs.gd)")
	var listed := true
	var recording_list := ScriptDocs.recording_list_markdown()
	for id in VoiceLines.LINES:
		if not recording_list.contains("`%s`" % id):
			listed = false
	check(listed, "every line is on the recording list")

	var docs := ScriptDocs.character_docs()
	var on_disk := {}
	for f in DirAccess.get_files_at(ScriptDocs.CHARACTERS_DIR):
		if f.ends_with(".md"):
			on_disk[ScriptDocs.CHARACTERS_DIR.path_join(f)] = true
	var chars_in_sync := on_disk.size() == docs.size()
	for path in docs:
		if FileAccess.get_file_as_string(path) != docs[path]:
			chars_in_sync = false
	check(chars_in_sync, "docs/script/characters/ matches voice_lines.gd (run tools/write_script_docs.gd)")
	var placed_once := []
	var wrong_file := []
	for id in VoiceLines.LINES:
		var hits := 0
		var slug: String = VoiceLines.CHARACTERS[VoiceLines.LINES[id]["speaker"]]["slug"]
		for path in docs:
			if docs[path].contains("`%s.wav`" % id):
				hits += 1
				if not path.get_file().begins_with(slug):
					wrong_file.append(id)
		if hits != 1:
			placed_once.append(id)
	check(placed_once.is_empty(), "every line is in exactly one character's script %s" % [placed_once])
	check(wrong_file.is_empty(), "lines are only in their own character's script %s" % [wrong_file])
	var leaks := []
	for path in docs:
		for c in VoiceLines.CHARACTERS.values():
			if docs[path].contains(c["who"]):
				leaks.append("%s: who %s" % [path.get_file(), c["slug"]])
		for sc in VoiceLines.SCENES:
			if docs[path].contains(sc["context"]):
				leaks.append("%s: context %s" % [path.get_file(), sc["id"]])
	check(leaks.is_empty(), "actors' scripts leave out the team-only character notes %s" % [leaks])
	check(VoiceLines.held_back({"level": VoiceLines.REVEAL_LEVEL}) and VoiceLines.held_back({"level": 2, "reveal": true}) \
		and not VoiceLines.held_back({"level": 2}), "reveal scenes and late levels are held back for a later session")


func test_voice_playback() -> void:
	print("Voice playback")
	var real_folder := Voice.folder
	Voice.folder = "user://voice_test/"
	DirAccess.make_dir_recursive_absolute(Voice.folder)
	var wav_path := Voice.folder.path_join("l0_greet_1.wav")
	if FileAccess.file_exists(wav_path):
		DirAccess.remove_absolute(wav_path)
	var voice := Voice.new()
	root.add_child(voice)
	await process_frame
	check(Voice.path_for("l0_greet_1") == "" and voice.play("l0_greet_1") == 0.0, "a line with no recording stays silent")
	# Half a second of 16-bit mono silence stands in for a recording.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050)
	wav.data = data
	wav.save_to_wav(wav_path)
	check(Voice.path_for("l0_greet_1") == wav_path, "a dropped-in recording is found by its line id")
	var wait := voice.play("l0_greet_1")
	check(absf(wait - (0.5 + Voice.TAIL)) < 0.05, "the line lasts as long as its recording (%.2f s)" % wait)
	check(voice.is_playing(), "the recording plays")
	check(voice._player.bus == &"Master", "Rourke plays without the PA filter")
	DirAccess.remove_absolute(wav_path)
	DirAccess.make_dir_recursive_absolute(Voice.folder.path_join("rourke"))
	var take2 := Voice.folder.path_join("rourke/l0_greet_1_take2.wav")
	wav.save_to_wav(take2)
	check(Voice.path_for("l0_greet_1") == "", "a second take alone isn't played")
	var actor_path := Voice.folder.path_join("rourke/l0_greet_1.wav")
	wav.save_to_wav(actor_path)
	check(Voice.path_for("l0_greet_1") == actor_path, "an actor's file in the character's folder is found")
	DirAccess.remove_absolute(take2)
	DirAccess.remove_absolute(actor_path)
	wav.save_to_wav(wav_path)
	var warden_path := Voice.folder.path_join("l1_sealed.wav")
	wav.save_to_wav(warden_path)
	voice.play("l1_sealed")
	check(voice._player.bus == Voice.PA_BUS and AudioServer.get_bus_index(Voice.PA_BUS) >= 0, "WARDEN plays through the PA speaker sound")
	voice.queue_free()
	DirAccess.remove_absolute(wav_path)
	DirAccess.remove_absolute(warden_path)
	Voice.folder = real_folder


func test_screens_fill_window() -> void:
	print("Menu screens")
	var win := root.get_visible_rect().size
	for path in ["res://scenes/main_menu.tscn", "res://scenes/field_notes.tscn"]:
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
	check(level.player.global_position.z > 14.0 and level.player.global_position.y > 0.3, "player starts inside the van")
	var flickering := 0
	for id in ["lobby", "hall"]:
		for l in level.lights[id]:
			for c in l.get_children():
				if c is FlickerLight:
					flickering += 1
	check(flickering == 0 and level.lights["lobby"].size() >= 6, "lobby and hall lights are steady")
	check(not level.front_doors.is_open, "front doors start closed")
	check(level.van_seats.size() == 6, "the van seats six")
	check(level.seat_spawn(1).origin.distance_to(level.player.global_position) < 0.3, "solo play starts in the passenger seat")
	var exits: Array = level.van_seats.map(func(s): return s.exit)
	check(exits.count("side") == 4 and exits.has("w") and exits.has("e"), "two front doors and a side door for the rear bench")
	level.players_needed = 2
	var mate := Player.new()
	level.add_child(mate)
	mate.global_transform = level.seat_spawn(4)
	level.ready_up(level.player, 1)
	check(not level._intro_started, "one of two ready players doesn't start the intro")
	level.ready_up(mate, 1)
	check(not level.ready_players.has(mate), "a seat can only be readied once")
	level.van_seats[4].buckle.interact(mate)
	check(level._intro_started and level.ready_players[mate] == 4, "the second player's buckle starts the intro")
	await create_timer(0.55).timeout
	check(level.player.rotation.y < -1.0 and level.player.head.rotation.x < -0.2, "climbing out, the camera looks down at the door handle (yaw %.2f, pitch %.2f)" % [level.player.rotation.y, level.player.head.rotation.x])
	var look := InputEventMouseMotion.new()
	look.relative = Vector2(-5000, 0)
	var held_yaw: float = level.player.rotation.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	level._unhandled_input(look)
	var turned: float = level.player.rotation.y - held_yaw
	check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or absf(turned - level.LOOK_YAW) < 0.01, "the mouse can look around a little while climbing out, no further (%.2f)" % turned)
	await create_timer(2.95).timeout
	var pos: Vector3 = level.player.global_position
	check(pos.x > 3.5 and pos.y < 0.3 and not level.player.input_locked, "readying up climbs the player out of the van (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z])
	var mpos: Vector3 = mate.global_position
	check(mpos.x > 3.5 and mpos.y < 0.3 and not mate.input_locked, "a rear-bench player climbs out of the side door (%.1f, %.1f, %.1f)" % [mpos.x, mpos.y, mpos.z])
	mate.queue_free()
	level.player.global_position = Vector3(0, 0.1, 11.5)
	await create_timer(3.5).timeout
	check(level.front_doors.is_open and level.rourke.global_position.z > 7.5, "Rourke comes out to meet the crew")
	level.desk_terminal.enabled = true
	level.terminal_ui.terminal = level.desk_terminal
	level.terminal_ui.run("SELECT * FROM memo_fragments")
	check(level.peek_puzzle.solved, "terminal run solves the peek")
	level.terminal_ui.run("SELECT * FROM memo_fragments ORDER BY piece_no")
	check(level.memo_puzzle.solved, "terminal run solves the memo")
	check(_game().query_log.size() >= 2 and _game().concepts_learned.has("ORDER BY"), "queries are logged for Field Notes")
	# Over the counter, staff style, and back again.
	level.rourke.walk_to(Vector3(-0.5, 0, 0.6))
	level.counter_hop.enabled = true
	level.player.global_position = Vector3(-3.6, 0.1, 0.4)
	await physics_frame
	level.counter_hop.interact(level.player)
	check(level.player.input_locked, "hopping the counter takes over the camera")
	await create_timer(1.8).timeout
	pos = level.player.global_position
	check(pos.z < -1.6 and pos.y < 0.3 and not level.player.input_locked, "sitting on the counter swings you over to the back (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z])
	level.counter_hop.interact(level.player)
	await create_timer(1.8).timeout
	check(level.player.global_position.z > -0.4 and not level.player.input_locked, "and back to the lobby side")
	# Rourke walks the crew down the hall himself; nothing blocks the way.
	level._on_walkies(level.player)
	for i in 600:
		if level.shutter.is_open:
			break
		await physics_frame
	check(level.shutter.is_open, "Rourke opens the hall shutter all the way (Rourke at %s)" % level.rourke.global_position)
	level.player.global_position = Vector3(8.2, 0.1, 3)
	for i in 60:
		await physics_frame
	check(level.rourke.state == Rourke.State.WALK and level.rourke._walk_target.x > 20.0, "Rourke leads the way down the hall to Server Room A")
	# The cable tray: a harmless first crouch on the walk.
	var tray_z: float = level.TRAY_X
	level.player.global_position = Vector3(tray_z - 1.5, 0.1, 3)
	level.player.rotation.y = -PI / 2  # facing down the hall
	level.player.local_control = false  # drive it from the test, not the keyboard
	for i in 90:
		level.player.controls.move = Vector2(0, -1)
		await physics_frame
	check(level.player.global_position.x < tray_z - 0.3, "standing players can't walk through the cable tray (x %.2f)" % level.player.global_position.x)
	for i in 120:
		level.player.controls.move = Vector2(0, -1)
		level.player.controls.crouch = true
		await physics_frame
	check(level.player.global_position.x > tray_z + 0.4, "crouching gets under it (x %.2f)" % level.player.global_position.x)
	level.player.controls.crouch = false
	level.player.controls.move = Vector2.ZERO
	level.player.local_control = true
	for i in 400:
		if level.rourke.global_position.x > tray_z + 1.0:
			break
		await physics_frame
	check(level.rourke.global_position.x > tray_z + 1.0, "Rourke ducks under it on his way")
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
	level.terminal_ui.terminal = level.terminal
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = 'A' AND status = 'fault'")
	check(not level.controller_puzzle.solved, "the puzzle waits for the self-test")
	level.terminal.interact(level.player)
	check(level.terminal_ui.visible and not level.terminal.locked, "the terminal opens normally: nothing is wrong yet")
	await create_timer(level.ATTACK_DELAY - 1.0).timeout
	check(not level._trapped, "Rourke waits a few seconds")
	await create_timer(1.5).timeout
	check(level._trapped and level.terminal.locked, "Rourke turns a few seconds after a player starts working, and locks the terminal")
	check(not level.terminal_ui.visible and not level.player.input_locked, "the terminal screen closes so the player can fight")
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


func test_facility_api() -> void:
	print("FacilityAPI")
	var api := FacilityAPI.new()
	api.route("GET", "/cameras", func(_p): return {"status": 200, "body": {"cameras": [{"id": "CAM-1", "motion": true}]}})
	api.route("GET", "/cameras/:id", func(p): return {"status": 200, "body": {"id": p[0]}})
	check(FacilityAPI.is_request("GET /cameras") and FacilityAPI.is_request("get /cameras;") and not FacilityAPI.is_request("SELECT * FROM cameras"), "HTTP lines are told apart from SQL")
	var r := api.request("GET /cameras")
	check(r.status == 200 and JSON.parse_string(r.text)["cameras"][0]["motion"] == true, "GET returns JSON")
	check(api.request("get /Cameras/;").status == 200, "method and path are case- and slash-tolerant")
	check(api.request("GET /cameras/CAM-3").body["id"] == "CAM-3", "path parameters are passed through")
	check(api.request("DELETE /cameras").status == 405, "a known path with the wrong verb is 405")
	check(api.request("GET /coffee").status == 404, "an unknown path is 404")


func test_level_2_data_every_seed() -> void:
	print("Level 2 data, 50 seeds")
	var correct := "SELECT * FROM guards WHERE name LIKE 'Har%' AND shift = 'night'"
	var puzzle := Puzzle.new("har", "SELECT pin FROM guards WHERE name LIKE 'Har%' AND shift = 'night'", ["pin"], false)
	var pike := Puzzle.new("pike", "SELECT name FROM guards WHERE name LIKE 'Pike%'", ["name"], false)
	var one_answer := true
	var wrongs_fail := true
	var explained := true
	var pins_unique := true
	var practice_ok := true
	var pins := {}
	var names := {}
	for s in 50:
		var data := Level2Data.build(s)
		var db := FacilityDB.new()
		db.load_seed(data.sql)
		var rows := db.run_silent(correct)
		if rows.size() != 1 or rows[0]["pin"] != data.pin or rows[0]["name"] != data.name or not puzzle.matches(db, db.execute(correct.to_lower())):
			one_answer = false
		for wrong in [
			"SELECT * FROM guards WHERE name LIKE 'Har%'",
			"SELECT * FROM guards WHERE name LIKE '%Har%' AND shift = 'night'",
			"SELECT * FROM guards WHERE shift = 'night'",
			"SELECT * FROM guards WHERE name LIKE 'Har'",
			"SELECT * FROM guards LIMIT 5",
		]:
			if puzzle.matches(db, db.execute(wrong)):
				wrongs_fail = false
		if db.run_silent("SELECT COUNT(*) AS n FROM guards WHERE name LIKE '%Har%' AND shift = 'night'")[0]["n"] < 3:
			wrongs_fail = false
		# Every guard a player might try instead has a note that rules them out.
		var suspects := db.run_silent("SELECT note FROM guards WHERE (name LIKE '%Har%' OR shift = 'night') AND pin != '" + data.pin + "'")
		for row in suspects:
			if str(row["note"]) == "" or str(row["note"]).contains("normal"):
				explained = false
		if int(db.run_silent("SELECT COUNT(DISTINCT pin) AS n FROM guards")[0]["n"]) != int(db.run_silent("SELECT COUNT(*) AS n FROM guards")[0]["n"]):
			pins_unique = false
		if int(db.run_silent("SELECT COUNT(*) AS n FROM guards")[0]["n"]) <= TerminalUI.MAX_ROWS_SHOWN:
			pins_unique = false
		if not pike.matches(db, db.execute("SELECT * FROM guards WHERE name LIKE 'pike%'")) or db.run_silent("SELECT * FROM guards WHERE name LIKE 'Pike%'").size() != 1:
			practice_ok = false
		pins[data.pin] = true
		names[data.name] = true
	check(one_answer, "exactly one night-shift Har- guard, and LIKE + AND finds them")
	check(wrongs_fail, "LIKE alone, '%Har%', shift alone and LIMIT never solve it")
	check(explained, "every other Har- or night-shift guard has a note saying why not")
	check(pins_unique, "PINs are unique and the roster is too long to read in one screen")
	check(practice_ok, "the Pike practice query finds exactly one row")
	var building := FacilityDB.new()
	building.load_seed(Level1Data.build(1).sql)
	var doors_before := building.run_silent("SELECT id FROM doors").size()
	var stacked: bool = building.db.query(Level2Data.build(1).sql)
	var door_ids := []
	for row in building.run_silent("SELECT id FROM doors ORDER BY id"):
		door_ids.append(row["id"])
	check(stacked and door_ids.has("SRA-EXIT") and door_ids.has("SEC-EXIT") and door_ids.has("SEC-OFFICE") and door_ids.size() == doors_before + 2, "the wing's seed loads on top of Level 1's: only SEC- doors added (%s)" % [door_ids])
	check(pins.size() >= 40 and names.size() >= 4, "PIN and guard vary between runs (%d PINs, %d names)" % [pins.size(), names.size()])


func test_level_2_hints() -> void:
	print("Level 2 first hints")
	var l2 = load("res://scripts/levels/level_2.gd").new()
	var ok := true
	for s in 20:
		var d := FacilityDB.new()
		d.load_seed(Level2Data.build(s).sql)
		for p in [l2.pike_puzzle, l2.har_puzzle]:
			if not p.matches(d, d.execute(_hint_query(p.hints[0]))):
				ok = false
	check(ok, "pike and har: first hint's query solves it on every seed")
	check(_hint_query(l2.cameras_puzzle.hints[0]) == "GET /cameras", "cameras: first hint is GET /cameras")
	check(_hint_query(l2.door_puzzle.hints[0]) == "GET /doors/SEC-EXIT", "door: first hint is GET /doors/SEC-EXIT")
	l2.free()


func test_level_2_scene() -> void:
	print("Level 2 scene")
	_game().new_run(11)
	var level = load("res://scenes/level_2.tscn").instantiate()
	root.add_child(level)
	for i in 30:
		await physics_frame
	var w: Watcher = level.watcher
	var p: Player = level.player
	check(level.doors["SEC-EXIT"].is_open == false, "stairwell exit starts locked")
	check(level.doors["SEC-OFFICE"].is_open == false, "the Security Office door starts locked")
	check(w.is_on_floor() and not w.active, "the Watcher waits in the office")
	# At the window, looking in: the office looks empty.
	p.global_transform = Transform3D(Basis(), Vector3(-3, 0.1, 3.4))
	p.head.rotation = Vector3.ZERO
	await physics_frame
	check(not w.player_sees(p), "at first it's out of sight from the window")
	# Player at the booth, facing the terminal: the office is behind them.
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-3, 0.1, 4.6))
	level.terminal_ui.terminal = level.booth
	level.terminal_ui.run("GET /cameras")
	var cams0: Dictionary = JSON.parse_string(level.booth.api.request("GET /cameras").text)
	check(level.cameras_puzzle.solved and cams0["cameras"][1]["motion"] == true, "GET /cameras solves the first puzzle: CAM-2 sees motion")
	var start: Vector3 = w.global_position
	for i in 30:
		await physics_frame
	check(w.global_position.distance_to(start) < 0.05, "a working camera holds it while nobody looks")
	level.terminal_ui.run("SELECT * FROM guards WHERE name LIKE 'Pike%'")
	check(level.pike_puzzle.solved and level.loose and level.frozen_cams.has("CAM-2"), "the Pike practice freezes CAM-2")
	level.terminal_ui.run("GET /doors/SEC-EXIT")
	check(not level.door_puzzle.solved, "checking the door early doesn't use up its puzzle")
	await physics_frame
	await physics_frame
	check(level.stage == "near" and w.global_position.distance_to(level.to_global(level.STAGES.near[0])) < 0.1, "closer to the PIN, it creeps closer while nobody looks")
	check(not w.active, "the locked door keeps it in the office")
	p.global_transform = Transform3D(Basis(), Vector3(-3, 0.1, 3.4))
	p.head.rotation = Vector3.ZERO
	await physics_frame
	check(w.player_sees(p), "now players can see it through the office window")
	level.terminal_ui.run("SELECT * FROM guards WHERE name LIKE 'Har%' AND shift = 'night'")
	check(level.har_puzzle.solved, "LIKE + AND finds the PIN")
	for i in 10:
		await physics_frame
	check(level.stage == "near", "it doesn't move while someone is watching it")
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-3, 0.1, 4.6))
	for i in 3:
		await physics_frame
	check(level.stage == "window" and w.global_position.distance_to(level.to_global(level.STAGES.window[0])) < 0.1, "look away and it's at the window")
	p.global_transform = Transform3D(Basis(), Vector3(-3, 0.1, 3.4))
	p.head.rotation = Vector3.ZERO
	await physics_frame
	check(w.player_sees(p) and not w.active, "with the PIN found, it stares at you through the glass")
	check(not level.check_pin("12a4").ok and not level.check_pin(level.data.pike_pin).ok, "letters and Pike's suspended PIN are refused")
	check(level.check_pin(level.data.pike_pin).message.contains("suspended"), "a wrong guard's PIN says why it was refused")
	check(level.check_pin(level.data.pin).ok, "the night-shift Har- guard's PIN is accepted")
	# Open the office from the east end of the corridor, then look away.
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(3, 0.1, 4.6))
	level._pad_mode = "office"
	level._on_pin(level.data.pin)
	for i in 5:
		await physics_frame
	check(level.doors["SEC-OFFICE"].is_open and w.active, "the PIN opens the office door, and it's free")
	var before: float = w.global_position.distance_to(p.global_position)
	for i in 180:
		await physics_frame
	var after: float = w.global_position.distance_to(p.global_position)
	check(after < before - 1.5, "unseen, it comes for you (%.1f m -> %.1f m)" % [before, after])
	var frame: String = level.db.run_silent("SELECT last_frame FROM cameras WHERE id = 'CAM-2'")[0]["last_frame"]
	level._clock += 5.0
	level.update_cameras()
	var cams: Dictionary = JSON.parse_string(level.booth.api.request("GET /cameras").text)
	var cam2: Dictionary = cams["cameras"][1]
	check(cam2["status"] == "live" and cam2["last_frame"] == frame and cams["server_time"] != frame, "the lie: CAM-2 says live but its frame is stuck")
	# It slips out into the corridor. Turn around and look at it: it stops.
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-3, 0.1, 4.6))
	w.place(Vector3(2.5, 0, 4.0), p.global_position)
	p.look_at(w.global_position + Vector3.UP * 1.2, Vector3.UP)
	p.rotation.x = 0
	await physics_frame
	await physics_frame
	var held: Vector3 = w.global_position
	for i in 30:
		await physics_frame
	check(w.seen and w.global_position.distance_to(held) < 0.05, "looking at it freezes it")
	level.terminal_ui.run("GET /cameras")
	check(level._lie_explained, "fetching cameras after it left explains the frozen frame")
	level._lie_explained = false
	_game().cam_lie_learned = false
	level.on_player_died()
	await create_timer(2.8).timeout
	check(level._lie_explained and _game().cam_lie_learned and level.booth.boot_lines[-1].contains("last_frame"), "dying to it explains the frozen camera, as lines you can note")
	for i in 3:
		await physics_frame
	level.enter_pin()
	for i in 5:
		await physics_frame
	check(not level.doors["SEC-EXIT"].is_open and int(level.db.run_silent("SELECT locked FROM doors WHERE id = 'SEC-EXIT'")[0]["locked"]) == 0, "the second lie: the PIN unlocks the row but the door stays shut")
	level.terminal_ui.terminal = level.panel
	level.terminal_ui.run("GET /doors/SEC-EXIT")
	var door: Dictionary = JSON.parse_string(level.booth.api.request("GET /doors/SEC-EXIT").text)
	check(level.door_checked and door["locked"] == false and door["sensor"] == "closed" and door["actuator"] == "fault", "the door's sensor shows the actuator fault")
	check(str(door["note"]).contains("B-%d" % level.data.breaker), "the note names the tripped breaker")
	var wrong_b: int = level.data.breaker % 4 + 1
	level._on_breaker(null, wrong_b)
	check(level.frozen_cams.has("CAM-3") and not level.doors["SEC-EXIT"].is_open, "the wrong breaker blacks out the vestibule camera instead")
	level._on_breaker(null, level.data.breaker)
	for i in 5:
		await physics_frame
	check(level.doors["SEC-EXIT"].is_open and level.door_open and level.door_puzzle.solved, "resetting the right breaker opens the door")
	check(level.db.run_silent("SELECT sensor FROM door_status WHERE door_id = 'SEC-EXIT'")[0]["sensor"] == "open", "the sensor now agrees")
	for i in 100:
		await physics_frame
	check(level.exit_lift.open_amount > 0.99, "with SEC-EXIT open, the elevator is waiting")
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(0, 0.1, -14.5)))
	await physics_frame
	check(not level.exit_lift.press(p) and level.exit_lift.refusal != "", "the button won't work until everyone is inside")
	level.seal_exit()
	for i in 5:
		await physics_frame
	check(not level.doors["SEC-EXIT"].is_open and _game().watcher_sealed, "the PIN locks it behind you")
	var shut := [false]
	level.exit_lift.closed.connect(func(): shut[0] = true)
	level.completed.disconnect(level._on_completed)
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(0, 0.1, -18.2)))
	await physics_frame
	check(level.exit_lift.headcount() == 1 and level.exit_lift.press(p), "inside, the button closes the doors")
	for i in 160:
		await physics_frame
	check(shut[0] and level.exit_lift.open_amount == 0.0, "the doors shut: the wing is done")
	p.input_locked = false
	p.global_transform = Transform3D(Basis(), Vector3(0, 0.1, 4.0))
	# Caught: put it right behind the player, out of sight.
	w.place(Vector3(0, 0, 5.2), p.global_position)
	for i in 20:
		await physics_frame
	check(p.health <= 0.0, "it gets you if you look away")
	level.queue_free()
	await process_frame


func test_level_2_routes() -> void:
	print("Level 2 routes")
	_game().new_run(3)
	var level = load("res://scenes/level_2.tscn").instantiate()
	root.add_child(level)
	for i in 20:
		await physics_frame
	level.watcher.active = false
	var p: Player = level.player
	p.local_control = false
	# The break-glass box on the landing: the safe place to learn both.
	check(level.key_glass.get_prompt(p).contains("Strike") and level.ledge_glass.get_prompt(p).contains("Strike"), "breakable glass says to strike it")
	check(level.spawn_point().origin.distance_to(level.key_glass.global_position) < 5.0, "the first breakable glass is on the landing, by the arrival elevator")
	# Vent: the grate is screwed shut until someone finds the screwdriver.
	level._on_vent_grate(p)
	await process_frame
	check(is_instance_valid(level.vent_grate) and not level.has_screwdriver, "the vent grate won't come off by hand")
	level.key_glass.take_hit(p)
	await process_frame
	var sd: Interactable = null
	for n in level.geo.get_children():
		if n is Interactable and n.prompt == "Take the screwdriver":
			sd = n
	check(not is_instance_valid(level.key_glass) and sd != null, "strike the box's glass and the screwdriver is there")
	sd.interact(p)
	level._on_vent_grate(p)
	await process_frame
	check(not is_instance_valid(level.vent_grate), "the screwdriver takes the grate off")
	level.set_hatch(true)
	check(level.hatch_open and level.vent_hatch.rotation.z != 0.0, "the hinged hatch at the vestibule end swings open")
	level.set_hatch(false)
	check(not level.hatch_open, "and closes again")
	level.set_hatch(true)
	# Climb the crate, then into the duct.
	p.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-4.4, 0.1, 4.0))
	for i in 5:
		await physics_frame
	check(p._try_ledge(false), "you can climb onto the crate")
	for i in 40:
		await physics_frame
	check(p._try_ledge(false), "from the crate you can climb into the vent")
	for i in 40:
		await physics_frame
	check(p.global_position.y > 1.9 and p.crouching and p.in_volume(MovementVolume.Kind.VENT) != null, "inside the vent, crouched (y %.2f)" % p.global_position.y)
	# Ledge: break the outside window first. The office window is security glass.
	level.office_glass.take_hit(p)
	level.ledge_glass.take_hit(p)
	await process_frame
	check(is_instance_valid(level.office_glass) and not is_instance_valid(level.ledge_glass), "the outside window breaks; the office window doesn't")
	# Out the broken window and along the east wall, back to the wall.
	p.global_transform = Transform3D(Basis(), Vector3(6.44, 0.05, 4.0))
	for i in 5:
		await physics_frame
	p.controls.move = Vector2(0, -1)
	var shuffled := false
	var lowest := 10.0
	for i in 900:
		await physics_frame
		shuffled = shuffled or p.state == Player.Move.LEDGE
		lowest = min(lowest, p.global_position.y)
		if p.global_position.z < -7.5:
			break
	p.controls.move = Vector2.ZERO
	check(shuffled and lowest > -0.5 and p.global_position.z < -7.5, "the east ledge shuffles to the far corner without falling (z %.1f)" % p.global_position.z)
	level.loose = true
	level._process(0.0)
	check(level.watcher.active, "going round the office another way wakes the Watcher too")
	level.watcher.active = false
	# Navigation: the Watcher can walk from the office to the vestibule and the corridor.
	var map: RID = level.watcher.get_world_3d().navigation_map
	var to_vest := NavigationServer3D.map_get_path(map, level.watcher_home, Vector3(0, 0, -10.5), true)
	var to_booth := NavigationServer3D.map_get_path(map, level.watcher_home, Vector3(-3, 0, 4.5), true)
	check(to_vest.size() > 0 and to_vest[-1].distance_to(Vector3(0, 0, -10.5)) < 0.8, "the Watcher can reach the vestibule")
	check(to_booth.size() > 0 and to_booth[-1].distance_to(Vector3(-3, 0, 4.5)) < 0.8, "the Watcher can reach the booth")
	var to_ledge := NavigationServer3D.map_get_path(map, level.watcher_home, Vector3(6.35, 0, -2), true)
	check(to_ledge.is_empty() or to_ledge[-1].distance_to(Vector3(6.35, 0, -2)) > 0.8, "the Watcher can't follow onto the ledge")
	level.queue_free()
	await process_frame


func _game() -> Node:
	return root.get_node("Game")


func test_wing_seeds_in_order() -> void:
	print("Wing seeds in one database")
	var lobby := FileAccess.get_file_as_string("res://data/level_0.sql")
	var ok := true
	for seed_value in 20:
		var db := FacilityDB.new()
		ok = ok and db.add_wing("level_0", lobby)
		ok = ok and db.add_wing("level_1", Level1Data.build(seed_value).sql)
		ok = ok and db.add_wing("level_2", Level2Data.build(seed_value).sql)
		var ids := db.run_silent("SELECT id FROM doors").map(func(r): return r["id"])
		ok = ok and ids.has("LOBBY-FRONT") and ids.has("SRA-EXIT") and ids.has("SEC-EXIT")
	check(ok, "Level 0, 1 and 2 seeds load into one database in order on every seed")
	var clash := FacilityDB.new()
	clash.add_wing("level_0", lobby)
	print("  (expected error below: a wing reusing another wing's door id)")
	check(not clash.add_wing("bad", "INSERT INTO doors VALUES ('LOBBY-FRONT', 'dup', 'L', 0, 0);"),
		"a wing reusing another wing's door id fails loudly")


func test_reset_keeps_earlier_wings() -> void:
	print("Reset restores the last checkpoint")
	var db := FacilityDB.new()
	db.add_wing("level_0", FileAccess.get_file_as_string("res://data/level_0.sql"))
	db.run_silent("UPDATE doors SET locked = 0 WHERE id = 'LOBBY-FRONT'")
	db.add_wing("level_1", Level1Data.build(3).sql)
	db.run_silent("UPDATE door_controllers SET status = 'ok'")
	db.run_silent("DELETE FROM memo_fragments")
	db.reset()
	check(db.run_silent("SELECT * FROM door_controllers WHERE status = 'fault'").size() > 0, "reset restores this wing's tables")
	check(db.run_silent("SELECT * FROM memo_fragments").size() == 7, "reset restores earlier wings' tables too")
	check(int(db.run_silent("SELECT locked FROM doors WHERE id = 'LOBBY-FRONT'")[0]["locked"]) == 0,
		"reset keeps what earlier wings changed before the checkpoint")


func test_world() -> void:
	print("World")
	_game().new_run(5)
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var lobby = world.current
	check(lobby != null and lobby.wing_id == "level_0" and lobby.active, "the World starts in the lobby wing")
	check(world.player.global_position.z > 14.0 and world.player.global_position.y > 0.3, "players start in the van")
	check(not world.wings.has("level_1"), "Server Room A isn't loaded before it's needed")
	world.load_next(lobby)
	var sra = world.wings.get("level_1")
	check(sra != null and not sra.active, "Server Room A loads behind its door without starting")
	var entry: Vector3 = sra.doors["SRA-ENTRY"].global_position
	check(entry.distance_to(Vector3(29, 1.2, 3)) < 0.1, "Server Room A sits at the end of the lobby hall (%s)" % entry)
	var tables: Array = world.db.table_names()
	check(tables.has("memo_fragments") and tables.has("door_controllers"), "both wings share one database")
	lobby.exit_door.set_open(true)
	var guide_at: Vector3 = lobby.rourke.global_position
	world.wing_finished(lobby)
	check(world.current == sra and sra.active, "finishing the lobby hands play to Server Room A")
	check(sra.rourke.global_position.distance_to(guide_at) < 0.1 and lobby.rourke.is_queued_for_deletion(), "Server Room A's Rourke takes over where the lobby's stood")
	world.seal_behind(sra)
	check(not lobby.exit_door.is_open, "the hall door seals behind the players")
	sra._on_trapped(null)
	check(sra.terminal.locked, "Server Room A's story runs inside the World")
	check(not world.wings.has("level_2"), "the security wing isn't loaded before it's needed")
	world.load_next(sra)
	var sec = world.wings.get("level_2")
	check(sec != null and not sec.active, "the security wing loads behind Server Room A's stairwell door")
	check(sra.exit_door != null and not sra.exit_door.is_open, "Server Room A's stairwell door is shut while the wing waits")
	var joint: Vector3 = sra.exit_door.global_position
	var landing: Vector3 = sec.to_global(Vector3(4, 0.1, 9))
	check(joint.distance_to(Vector3(53.9, 1.2, 3)) < 0.2 and landing.distance_to(Vector3(55, 0.1, 3)) < 0.1 and sec.arrival_lift.contains(sec.spawn_point().origin),
		"the security wing's landing meets Server Room A's exit corridor (%s, %s)" % [joint, landing])
	check(world.db.run_silent("SELECT * FROM doors WHERE id LIKE 'SEC-%'").size() == 2 and world.db.table_names().has("guards"),
		"the security wing adds its own rows to the one building database")
	await process_frame
	check(sec._clock == 0.0, "the security wing's clock doesn't run before players get there")
	check(sec._camera_holds(sec.watcher), "cameras cover the Watcher's spot in the office, wherever the wing sits")
	sra.exit_door.set_open(true)
	world.wing_finished(sra)
	check(world.current == sec and sec.active, "finishing Server Room A hands play to the security wing")
	check(sec.watcher.global_position.distance_to(sec.to_global(sec.watcher_home)) < 0.1, "the Watcher stands in the office")
	world.seal_behind(sec)
	check(not sra.exit_door.is_open, "Server Room A's stairwell door seals behind the players")
	sec.player.global_position = sec.to_global(Vector3(0, 0.1, -10.5))
	await physics_frame
	await physics_frame
	sec._process(0.0)
	check(sec.reached_vestibule, "the vestibule camera zone works at the wing's position")
	sec.on_player_died()
	check(sec.player.global_position.distance_to(sec.to_global(Vector3(0, 0.1, -10.8))) < 0.2, "dying past the office respawns in the vestibule")
	var map: RID = sec.watcher.get_world_3d().navigation_map
	for i in 5:
		await physics_frame
	var path := NavigationServer3D.map_get_path(map, sec.to_global(sec.watcher_home), sec.to_global(Vector3(-3, 0, 4)), true)
	check(path.size() > 1 and path[path.size() - 1].distance_to(sec.to_global(Vector3(-3, 0, 4))) < 1.0, "the Watcher can path from the office to the corridor in the World")
	world.wing_finished(sec)
	check(world._field_notes != null and world.player.input_locked, "Field Notes opens as an overlay at the end")
	world.queue_free()
	await process_frame
