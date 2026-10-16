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
	await load("res://tests/movement_tests.gd").new().run(self, check)
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
	level.ready_up(level.player, 1)
	await create_timer(2.5).timeout
	var pos: Vector3 = level.player.global_position
	check(pos.x > 3.5 and pos.y < 0.3 and not level.player.input_locked, "readying up climbs the player out of the van (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z])
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
	var stacked: bool = building.db.query(Level2Data.build(1).sql)
	var door_ids := []
	for row in building.run_silent("SELECT id FROM doors ORDER BY id"):
		door_ids.append(row["id"])
	check(stacked and door_ids.has("SRA-EXIT") and door_ids.has("SEC-EXIT") and door_ids.size() == 6, "the wing's seed loads on top of Level 1's: only SEC- doors added (%s)" % [door_ids])
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
	check(w.is_on_floor() and w.active, "the Watcher stands in the office")
	# Player at the booth, facing the terminal: the office is behind them.
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-3, 0.1, 4.6))
	level.terminal_ui.terminal = level.booth
	level.terminal_ui.run("GET /cameras")
	check(level.cameras_puzzle.solved, "GET /cameras solves the first puzzle")
	var start: Vector3 = w.global_position
	for i in 60:
		await physics_frame
	check(w.global_position.distance_to(start) < 0.05, "a working camera holds it while nobody looks")
	p.global_transform = Transform3D(Basis(), Vector3(-3, 0.1, 3.4))
	p.head.rotation = Vector3.ZERO
	await physics_frame
	check(w.player_sees(p), "players can see it through the office window")
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-3, 0.1, 4.6))
	level.terminal_ui.run("SELECT * FROM guards WHERE name LIKE 'Pike%'")
	check(level.pike_puzzle.solved and level.loose and level.frozen_cams.has("CAM-2"), "the Pike practice frees it: CAM-2 freezes")
	var before: float = w.global_position.distance_to(p.global_position)
	for i in 120:
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
	level.terminal_ui.run("SELECT * FROM guards WHERE name LIKE 'Har%' AND shift = 'night'")
	check(level.har_puzzle.solved, "LIKE + AND finds the PIN")
	check(not level.check_pin("12a4").ok and not level.check_pin(level.data.pike_pin).ok, "letters and Pike's suspended PIN are refused")
	check(level.check_pin(level.data.pike_pin).message.contains("suspended"), "a wrong guard's PIN says why it was refused")
	check(level.check_pin(level.data.pin).ok, "the night-shift Har- guard's PIN is accepted")
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
	check(level.doors["SEC-EXIT"].is_open and level.door_open, "resetting the right breaker opens the door")
	check(level.db.run_silent("SELECT sensor FROM door_status WHERE door_id = 'SEC-EXIT'")[0]["sensor"] == "open", "the sensor now agrees")
	level.seal_exit()
	for i in 5:
		await physics_frame
	check(not level.doors["SEC-EXIT"].is_open and _game().watcher_sealed, "the PIN locks it behind you")
	# Caught: put it right behind the player, out of sight.
	p.global_transform = Transform3D(Basis(), Vector3(0, 0.1, 4.0))
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
	# Vent: climb the crate, then into the duct.
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
	# Ledge: out the smashed window and along the east wall, back to the wall.
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
