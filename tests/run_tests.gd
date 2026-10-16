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
	await test_screens_fill_window()
	await test_level_0_scene()
	await test_level_1_scene()
	test_wing_seeds_in_order()
	test_reset_keeps_earlier_wings()
	await test_world()
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
		var ids := db.run_silent("SELECT id FROM doors").map(func(r): return r["id"])
		ok = ok and ids.has("LOBBY-FRONT") and ids.has("SRA-EXIT")
	check(ok, "Level 0 then Level 1 seeds load into one database on every seed")
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
	world.wing_finished(lobby)
	check(world.current == sra and sra.active, "finishing the lobby hands play to Server Room A")
	world.seal_behind(sra)
	check(not lobby.exit_door.is_open, "the hall door seals behind the players")
	sra._on_trapped(null)
	check(sra.terminal.locked, "Server Room A's story runs inside the World")
	world.wing_finished(sra)
	check(world._field_notes != null and world.player.input_locked, "Field Notes opens as an overlay at the end")
	world.queue_free()
	await process_frame
