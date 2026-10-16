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
	test_voice_codec()
	test_radio_rules()
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
	test_sticky_notes_never_give_answers()
	await test_elevator()
	await test_notebook()
	await load("res://tests/movement_tests.gd").new().run(self, check)
	await load("res://tests/art_tests.gd").new().run(self, check)
	await load("res://tests/teaching_tests.gd").new().run(self, check)
	await test_coop_level_0()
	await test_coop_level_1()
	await test_coop_six_players()
	await test_coop_world()
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


func _tone(n: int, rate: float, amp: float) -> PackedVector2Array:
	var f := PackedVector2Array()
	for i in n:
		var v := sin(TAU * 440.0 * i / rate) * amp
		f.append(Vector2(v, v))
	return f


func test_voice_codec() -> void:
	print("Voice codec")
	var tone := _tone(4800, 48000.0, 0.5)
	var packet := VoiceCodec.encode(tone, 48000.0)
	check(packet.size() == 1200, "48 kHz audio is cut to 12 kHz, one byte a sample (%d bytes)" % packet.size())
	var back := VoiceCodec.decode(packet)
	var worst := 0.0
	for i in back.size():
		worst = maxf(worst, absf(back[i].x - tone[i * 4].x))
	check(worst < 0.03, "mu-law keeps the voice close to the original (worst error %.3f)" % worst)
	check(VoiceCodec.rms(back) > 0.3 and VoiceCodec.rms(_tone(100, 48000.0, 0.0)) == 0.0, "loudness tells talking from silence")
	check(VoiceCodec.mulaw_decode(VoiceCodec.mulaw_encode(-0.25)) < 0.0, "negative samples stay negative")


func test_radio_rules() -> void:
	print("Radio rules")
	check(Radio.signal_quality(10.0, 0.0) == 1.0, "clear at close range")
	check(Radio.signal_quality(50.0, 0.0) < 1.0 and Radio.signal_quality(50.0, 0.0) > 0.0, "fades with distance")
	check(Radio.signal_quality(Radio.MAX_RANGE + 1.0, 0.0) == 0.0, "nothing but static out of range")
	var near_entity := Radio.interference_at(Vector3.ZERO, [Vector3(2, 0, 0)])
	check(near_entity > 0.5 and Radio.interference_at(Vector3.ZERO, [Vector3(30, 0, 0)]) == 0.0, "entities nearby cause static, far ones don't")
	check(Radio.signal_quality(10.0, near_entity) < 0.5, "static near an entity drowns out a close teammate")
	var r := Radio.new()
	r.tick(Radio.TALK_TIME / 2.0, true)
	check(is_equal_approx(r.battery, 0.5) and r.transmitting, "talking drains the battery")
	r.tick(10.0, false)
	check(is_equal_approx(r.battery, 0.5), "listening doesn't")
	r.tick(Radio.TALK_TIME, true)
	check(not r.can_transmit() and not r.transmitting, "a dead battery can't transmit")
	r.recharge()
	check(r.can_transmit(), "fresh batteries bring it back")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var clean := Radio.degrade(_tone(600, 12000.0, 0.5), 1.0, rng)
	var noisy := Radio.degrade(_tone(600, 12000.0, 0.0), 0.0, rng)
	check(VoiceCodec.rms(clean) > 0.3 and VoiceCodec.rms(noisy) > 0.1, "a good signal carries the voice, a dead one is only static")


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
	var nudge: Array = Array(level.desk_terminal.transcript).filter(func(l): return l.contains("ORDER BY"))
	check(not nudge.is_empty() and nudge.all(func(l): return not l.contains("piece_no")), "WARDEN's nudge points at the numbering column without naming it")
	level.terminal_ui.run("SELECT * FROM memo_fragments ORDER BY piece_no DESC")
	check(not level.memo_puzzle.solved and Array(level.desk_terminal.transcript).any(func(l): return l.contains("memo backwards")), "a memo sorted DESC doesn't count, and WARDEN says why")
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
	level._on_walkies()
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
	check(not level.terminal.locked, "the trap doesn't spring while the player is still in the antechamber")
	level.terminal_ui.terminal = level.terminal
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = 'A' AND status = 'fault'")
	check(not level.controller_puzzle.solved, "the puzzle waits for the self-test")
	level.player.global_position = level.to_global(Vector3(-4.5, 0.1, 7.4))  # at the terminal desk
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
	check(level.elevator.open_amount == 0.0, "the elevator waits with its doors shut")
	level._on_exit(null)
	await level.elevator.opened
	check(level.elevator.open_amount == 1.0, "reaching the exit corridor opens the elevator")
	level.player.global_position = level.to_global(Vector3(0, 0.1, -13.5))
	await physics_frame
	check(not level.elevator.press() and not level.elevator.is_closing and level.elevator.refusal != "", "the button does nothing while someone is still outside")
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

	# Notebooks are per player: a loose sticky goes to whoever took it and is gone
	# for everyone; one stuck to a terminal is copied by each player on their own.
	var loose: Array = levels.map(func(l): return l.find_children("*", "StickyNote", true, false).filter(func(n): return n.note_id == "order_by")[0])
	check(not loose[0].on_terminal and levels.all(func(l): return l.find_children("*", "StickyNote", true, false).any(func(n): return n.on_terminal and n.local_only)), "terminal stickies are copied locally, not through the host")
	_game().notebook_notes.clear()
	loose[1].interact(c1.player)
	await _frames(10)
	check(loose.all(func(n): return not is_instance_valid(n) or n.is_queued_for_deletion()), "a loose note taken by a client disappears on every machine")
	check(_game().notebook_notes == ["order_by"], "and goes into the taker's notebook")

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

	_game().has_walkie = true
	var tone := _tone(4800, 48000.0, 0.5)
	c1.voice.send_frames(tone, 48000.0, false)
	await _frames(10)
	check(host.voice.heard.near == 1 and c2.voice.heard.near == 1, "open-mic voice reaches players nearby")
	c2.player.global_position = Vector3(-17, 0.1, 4)
	c1.player.global_position = Vector3(23, 0.1, 3)
	await _frames(30)
	c1.voice.send_frames(tone, 48000.0, true)
	await _frames(10)
	check(c2.voice.heard.near == 1 and c2.voice.heard.radio == 1, "radio reaches a teammate too far away to hear directly")
	check(c2.voice.last_quality > 0.0 and c2.voice.last_quality < 1.0, "at 40 m the radio is crackly (quality %.2f)" % c2.voice.last_quality)
	_game().has_walkie = false

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

	host.player.global_position = Vector3(0, 0.1, 12.5)
	client.player.global_position = Vector3(-4.5, 0.1, 7.4)  # at the terminal desk
	await _frames(30)
	client.terminal.interact(client.player)
	await _frames(5)
	check(client.terminal_ui.visible and not host.terminal_ui.visible, "a client sits down at the terminal on their own screen")
	await create_timer(host.ATTACK_DELAY + 0.5).timeout
	check(not host._trapped and not host.terminal.locked, "Rourke holds off while someone is still outside")
	check(host.rourke.global_position.distance_to(Vector3(-4.5, 0, 7.4)) < 2.5, "the host hears the client sat down: Rourke drifts up behind them")
	host.player.global_position = Vector3(1, 0.1, 3)
	await _frames(30)
	check(host.terminal.locked and client.terminal.locked, "the trap springs once everyone is inside")
	check(not client.terminal_ui.visible, "the client's terminal screen closes for the fight")
	check(host.rourke.max_hits == Rourke.MAX_HITS + 2, "Rourke is tougher with two players (%d hits)" % host.rourke.max_hits)

	host.rourke.global_position = Vector3(-3, 0, 5)
	await _frames(20)
	check(client.rourke.global_position.distance_to(host.rourke.global_position) < 1.0, "clients see Rourke where the host has him")
	host.rourke.set_physics_process(false)
	host.rourke._windup = 0.4
	await _frames(5)
	check(client.rourke._windup > 0.0, "clients see Rourke wind up an attack")
	host.rourke._windup = 0.0
	host.rourke.set_physics_process(true)
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
	client.player.set_physics_process(false)  # hold the stance still for the check
	client.player._set_stance(Player.CRAWL_HEIGHT)
	await _frames(10)
	var mate: PlayerPuppet = host.players.puppet(client_id)
	check(mate.crawling and mate.height < 1.0, "a teammate crawling shows crawling for the others, not standing")
	client.player._set_stance(Player.STAND_HEIGHT)
	await _frames(10)
	check(not mate.crouching and is_equal_approx(mate.height, Player.STAND_HEIGHT), "and stands back up with them")
	client.player.set_physics_process(true)

	# The elevator: the host counts heads, then the doors close everywhere.
	host.sync.event("_on_exit", [null])
	await _frames(5)
	for l in levels:
		l.elevator.closed.disconnect(l._on_elevator_closed)  # stay in this level for the checks
		l.elevator.open(true)
	host.player.global_position = Vector3(0.4, 0.1, -17.1)
	client.player.global_position = Vector3(0, 0.1, -12.0)
	await _frames(30)
	client.elevator.button.interact(client.player)
	await _frames(10)
	check(host.elevator.refusal.contains("1/2") and not host.elevator.is_closing and not client.elevator.is_closing, "the elevator waits for a teammate still outside")
	client.player.global_position = Vector3(-0.4, 0.1, -17.1)
	await _frames(30)
	client.elevator.button.interact(client.player)
	await _frames(10)
	check(host.elevator.is_closing and client.elevator.is_closing, "with everyone inside, a client's press closes the doors on every machine")
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


func test_coop_world() -> void:
	print("Co-op: the World with a host and a client")
	_game().new_run(9)
	var worlds := await _coop_worlds(1)
	var machines := await _coop_load(worlds, "res://scenes/world.tscn")
	var host = machines[0]
	var client = machines[1]
	var client_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()
	check(machines.all(func(w): return w.sync._begun and w.current != null and w.current.wing_id == "level_0" and w.current.active), "both machines start the World in the lobby wing")
	check(machines.all(func(w): return w.players.count() == 2), "both see two players in the World")
	var lobby_h = host.current
	var lobby_c = client.current
	check(lobby_c.players == client.players and lobby_c.sync != client.sync, "a wing shares the World's players but has its own events")

	lobby_c.van_seats[0].buckle.interact(client.player)
	await _frames(10)
	check(lobby_h.ready_players.size() == 1 and not lobby_h._intro_started, "a client's van door, pressed inside a wing, reaches the host")
	lobby_h.van_seats[1].buckle.interact(host.player)
	await _frames(10)
	check(lobby_h._intro_started and lobby_c._intro_started, "once both are ready, everyone climbs out together")

	lobby_h.sync.event("_on_walkies")
	await _frames(10)
	check(host.wings.has("level_1") and client.wings.has("level_1"), "the next wing loads on every machine")
	var sra_h = host.wings["level_1"]
	var sra_c = client.wings["level_1"]
	var dump := "SELECT * FROM doors ORDER BY id"
	check(_table(sra_h, dump) == _table(sra_c, dump), "both machines built the same building from the run seed")
	lobby_h.sync.event("_on_reach_server_room", [null])
	for f in 900:  # Rourke's line at the door plays first
		await physics_frame
		if host.current == sra_h and client.current == sra_c:
			break
	await _frames(10)
	check(host.current == sra_h and client.current == sra_c and sra_c.active, "play moves into Server Room A on every machine")

	sra_h.rourke.global_position = sra_h.to_global(Vector3(-3, 0, 5))
	await _frames(20)
	check(sra_c.rourke.global_position.distance_to(sra_h.rourke.global_position) < 1.0, "clients see the wing's Rourke where the host has him")
	sra_h.sync.event("_on_rourke_resolved", ["tied"])
	await _frames(10)
	sra_c.terminal_ui.terminal = sra_c.terminal
	sra_c.terminal_ui.run("UPDATE doors SET locked = 0 WHERE id = 'SRA-EXIT'")
	await _frames(10)
	check(sra_h.doors["SRA-EXIT"].is_open and sra_c.doors["SRA-EXIT"].is_open, "a client's query in a wing opens the door for everyone")
	check(_table(sra_h, dump) == _table(sra_c, dump), "the shared database still matches")
	check(host.players.puppet(client_id) != null, "the client is still in the game")
	await _coop_close(worlds)


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
	check(stacked and door_ids.has("SRA-EXIT") and door_ids.has("SEC-EXIT") and door_ids.size() == doors_before + 1, "the wing's seed loads on top of Level 1's: only SEC- doors added (%s)" % [door_ids])
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
	# Out by the elevator: the doors closing are the checkpoint, the ride ends the level.
	sra.rourke.state = Rourke.State.IDLE
	sra._on_exit(null)
	await sra.elevator.opened
	world.player.global_position = sra.elevator.to_global(Vector3(0, 0.1, Elevator.SIZE.z / 2))
	for i in 5:
		await physics_frame
	check(sra.elevator.press() and sra.elevator.is_closing, "with everyone inside, the button closes the doors")
	await sra.elevator.closed
	check(sra.elevator.open_amount == 0.0 and sra.elevator.riding, "the doors shut before it moves")
	await sra.elevator.arrived
	await process_frame
	check(world._field_notes != null and world.player.input_locked, "the ride ends at Field Notes, in the notebook")
	check(world._field_notes.find_children("*", "NotebookView", true, false).size() == 1, "Field Notes is the notebook's page")
	world.queue_free()
	await process_frame


func test_sticky_notes_never_give_answers() -> void:
	print("Sticky notes")
	var l0 = load("res://scripts/levels/level_0.gd").new()
	var l1 = load("res://scripts/levels/level_1.gd").new()
	var puzzles: Array = [l0.peek_puzzle, l0.memo_puzzle, l1.controller_puzzle]
	var every_example_runs := true
	var gives_answer := []
	for seed_value in 20:
		var db := FacilityDB.new()
		db.add_wing("level_0", FileAccess.get_file_as_string("res://data/level_0.sql"))
		db.add_wing("level_1", Level1Data.build(seed_value).sql)
		for id in StickyNotes.NOTES:
			for example in StickyNotes.NOTES[id].example.split(";", false):
				if example.strip_edges() == "":
					continue
				var result := db.execute(example + ";")
				if not result.ok:
					every_example_runs = false
					continue
				for p in puzzles:
					if p.matches(db, result) and not gives_answer.has(id):
						gives_answer.append(id)
	check(every_example_runs, "every sticky note example runs on the real tables")
	check(gives_answer.is_empty(), "no sticky note example solves a puzzle %s" % [gives_answer])
	var fits := true
	for id in StickyNotes.NOTES:
		var lines: PackedStringArray = (StickyNotes.NOTES[id].syntax + "\n" + StickyNotes.NOTES[id].example).split("\n")
		fits = fits and lines.size() <= 4 and Array(lines).all(func(line): return line.length() <= 30)
	check(fits, "every sticky note fits on its paper")
	l0.free()
	l1.free()


func test_notebook() -> void:
	print("Notebook")
	_game().new_run(3)
	var level = load("res://scenes/level_0.tscn").instantiate()
	root.add_child(level)
	for i in 10:
		await physics_frame
	var nb: Notebook = level.notebook
	level.player.input_locked = false
	check(nb.open() and nb.is_open() and level.player.input_locked, "Tab opens the notebook and holds the player")
	check(nb.pages.current_page() == NotebookPages.Page.NOTES, "it opens on the sticky notes")
	nb.close()
	check(not nb.is_open() and not level.player.input_locked, "and closes again")
	level.terminal_ui.open(level.desk_terminal, level.player)
	check(not nb.open(), "the notebook can't be opened while using a terminal")
	level.terminal_ui.run("SELECT * FROM memo_fragments")
	check(_game().notebook_tables.get("memo_fragments", []) == ["piece_no", "text", "scanned_at"], "a query writes its table and columns on the Tables page")
	level.terminal_ui.run(".tables")
	check(_game().notebook_tables.has("visitors") and _game().notebook_tables.has("doors"), ".tables writes down every table")
	# Write note: any line on the terminal can go in the notebook, with a label.
	var ui: TerminalUI = level.terminal_ui
	ui.run("SELEC * FROM memo_fragments")
	ui.run(".hint")
	ui.run(".schema memo_fragments")
	var kinds := {}
	for line in ui.noteable_lines():
		kinds[line.kind] = kinds.get(line.kind, 0) + 1
	check(kinds.has("result") and kinds.has("error") and kinds.has("hint") and kinds.has("schema") and kinds.has("info"), "results, errors, hints, schemas and boot text can all be noted (%s)" % [kinds])
	var lines: Array = ui.noteable_lines()
	var taught := lines.filter(func(l): return l.text.contains("SELECT * FROM memo_fragments") and l.kind == "info")
	check(not taught.is_empty(), "the boot screen's SELECT example can be noted")
	var result_i := -1
	for i in lines.size():
		if lines[i].kind == "result" and lines[i].text.contains("piece_no"):
			result_i = i
	check(ui.write_note(result_i, "memo scraps") and _game().notebook_written[-1].label == "memo scraps" and _game().notebook_written[-1].kind == "result", "write note copies a query result under the player's own label")
	ui._on_meta("note:%d" % taught[0].get("index", lines.find(taught[0])))
	check(ui._note_label.visible, "clicking +note asks for a label")
	ui._finish_note("")
	check(_game().notebook_written.size() == 2 and not ui._note_label.visible, "Enter writes it down, label optional")
	ui.run(".note schema")
	check(_game().notebook_written[-1].kind == "schema" and _game().notebook_written[-1].label == "schema", ".note writes the last line down")
	level.terminal_ui.close()
	var stickies: Array = level.find_children("*", "StickyNote", true, false)
	var on_screen: StickyNote
	var loose: StickyNote
	for n in stickies:
		if n.on_terminal:
			on_screen = n
		else:
			loose = n
	check(on_screen != null and on_screen.note_id == "select_from" and on_screen.get_parent() == level.desk_terminal, "the desk terminal has a SELECT sticky note on its monitor")
	on_screen.interact(level.player)
	check(_game().notebook_notes == ["select_from"] and is_instance_valid(on_screen) and not on_screen.is_queued_for_deletion(), "copying a terminal sticky leaves it for the rest of the crew")
	check(on_screen.get_prompt(level.player) == "", "a copied note has nothing more to offer you")
	var mate := Player.new()
	level.add_child(mate)
	check(on_screen.get_prompt(mate) != "", "but a teammate can still copy it")
	loose.interact(mate)
	check(not _game().notebook_notes.has("order_by") and loose.is_queued_for_deletion(), "a loose note goes to whoever picked it up, not into everyone's notebook")
	mate.queue_free()
	_game().add_note("order_by")
	check(not _game().add_note("order_by") and _game().notebook_notes.size() == 2, "a note is only written down once")
	nb.open(NotebookPages.Page.TABLES)
	var on_pages: Array = nb.pages.book.left.get_children() + nb.pages.book.right.get_children()
	check(nb.pages.current_page() == NotebookPages.Page.TABLES and NotebookPages.text_of(on_pages).contains("memo_fragments"), "the Tables page lists what was found")
	var notes_text := nb.pages.section_text(NotebookPages.Page.NOTES)
	check(notes_text.contains("ORDER BY") and notes_text.contains("staff_directory"), "the Notes page shows each note's example")
	nb.pages.show_page(NotebookPages.Page.TABLES)
	check(nb.pages._spreads.size() == 1 and not nb.pages._turn.visible, "a short section fits on one spread")
	for t in 20:
		_game().discover_table("extra_%d" % t, ["a", "b", "c", "d"])
	nb.pages.refresh()
	check(nb.pages._spreads.size() > 1 and nb.pages._turn.visible, "a long section turns onto more pages")
	var first_page: Array = nb.pages.book.left.get_children()
	for i in nb.pages._spreads.size():
		nb.pages._show_spread(nb.pages._spread + 1)
	check(nb.pages._spread == 0 and nb.pages.book.left.get_children() == first_page and first_page.all(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion()), "turning all the way round comes back to the first spread intact")
	var written_text := nb.pages.section_text(NotebookPages.Page.WRITTEN)
	check(written_text.contains("memo scraps") and written_text.contains("piece_no"), "written notes show on My notes with their labels")
	nb.close()
	var saved: Dictionary = _game().notebook_data()
	_game().new_run(4)
	check(_game().notebook_notes.is_empty(), "a new run starts with an empty notebook")
	_game().load_notebook(saved)
	check(_game().notebook_notes.size() == 2 and _game().notebook_tables.has("memo_fragments") and _game().notebook_written.size() == 3, "a saved notebook loads back")
	level.queue_free()
	await process_frame


func test_elevator() -> void:
	print("Elevator")
	var stage := Node3D.new()
	root.add_child(stage)
	var geo := Node3D.new()
	stage.add_child(geo)
	var lift := Elevator.create(stage, geo, Vector3.ZERO, 0, "1")
	var dest := Elevator.create(stage, geo, Vector3(40, 0, 10), 90, "B2")
	var a := Player.new()
	var b := Player.new()
	a.local_control = false
	b.local_control = false
	a.position = Vector3(0.4, 0.1, 1.2)
	b.position = Vector3(0, 0.1, -3.0)
	stage.add_child(a)
	stage.add_child(b)
	lift.open(true)
	for i in 3:
		await physics_frame
	check(not lift.press() and lift.headcount() == Vector2i(1, 2), "the button waits for every living player")
	b.health = 0.0
	check(lift.headcount() == Vector2i(1, 1), "a downed player doesn't hold the doors")
	b.health = 100.0
	b.global_position = Vector3(-0.5, 0.1, 1.5)
	for i in 3:
		await physics_frame
	check(lift.press() and lift.is_closing, "with the whole crew in, the doors close")
	await lift.closed
	var a_local: Vector3 = lift.to_local(a.global_position)
	var a_yaw: float = a.rotation.y
	lift.link_to(dest)
	await lift.ride(0.3)
	check(dest.to_local(a.global_position).distance_to(a_local) < 0.01 and dest.contains(b.global_position), "the ride carries everyone to the same spot in the next car")
	check(is_equal_approx(angle_difference(a_yaw + PI / 2, a.rotation.y), 0.0), "facing the same way relative to the car")
	await dest.opened
	check(dest.open_amount == 1.0 and lift.open_amount == 0.0, "the next car's doors open; the old ones stay shut")
	stage.queue_free()
	await process_frame
