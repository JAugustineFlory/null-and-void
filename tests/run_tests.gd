extends SceneTree
## Headless test runner. Usage:
##   godot --headless -s tests/run_tests.gd
## Exits with code 1 if any test fails.

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# The full-screen notebook and terminal; test_in_world_ui covers the held and on-screen ones.
	_game().diegetic_ui = false
	test_facility_db()
	test_level_0_puzzles()
	test_level_1_data_every_seed()
	test_first_hints_show_working_queries()
	test_voice_codec()
	test_radio_rules()
	test_voice_script()
	await test_voice_playback()
	await test_pause_holds_subtitles()
	test_facility_api()
	test_level_2_data_every_seed()
	test_level_2_hints()
	await test_screens_fill_window()
	await test_level_0_scene()
	await test_ground_floor()
	await test_level_1_scene()
	await test_level_2_scene()
	await test_level_2_routes()
	await test_level_2_wall_controls()
	await test_level_2_main_route()
	test_level_2_lab_data_every_seed()
	for outcome in ["killed", "tied", "untied"]:
		await test_level_2_lab(outcome)
	test_wing_seeds_in_order()
	test_reset_keeps_earlier_wings()
	await test_world()
	await test_rourke_leads_in()
	test_sticky_notes_never_give_answers()
	await test_elevator()
	await test_notebook()
	await test_in_world_ui()
	await test_pick_up_papers()
	await load("res://tests/movement_tests.gd").new().run(self, check)
	await load("res://tests/art_tests.gd").new().run(self, check)
	await load("res://tests/teaching_tests.gd").new().run(self, check)
	await load("res://tests/teaching_voice_tests.gd").new().run(self, check)
	await test_coop_level_0()
	await test_coop_level_1()
	await test_coop_six_players()
	await test_coop_terminal_screens()
	await test_coop_world()
	await test_coop_lobby_walk_in()
	await test_coop_level_2()
	await test_coop_level_2_lab()
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
	# A microphone at 44.1 kHz, sent in frame-sized chunks, must come out as one
	# smooth wave: no jumps where one packet ends and the next begins.
	var mic := _tone(44100, 44100.0, 0.5)
	var enc := VoiceCodec.Encoder.new()
	var stream := PackedVector2Array()
	var at := 0
	while at < mic.size():
		var chunk := mic.slice(at, mini(at + 735, mic.size()))
		stream.append_array(VoiceCodec.decode(enc.encode(chunk, 44100.0)))
		at += 735
	var jump := 0.0
	for i in range(1, stream.size()):
		jump = maxf(jump, absf(stream[i].x - stream[i - 1].x))
	check(absi(stream.size() - 12000) <= 2 and jump < 0.15, "a 44.1 kHz mic sent in chunks stays one smooth 12 kHz wave (%d samples, biggest step %.3f)" % [stream.size(), jump])
	var quiet := _tone(4800, 48000.0, 0.02)
	var louder := VoiceCodec.amplify(quiet, 8.0)
	var peak := 0.0
	for f in VoiceCodec.amplify(_tone(4800, 48000.0, 0.9), 8.0):
		peak = maxf(peak, absf(f.x))
	check(VoiceCodec.rms(louder) > 0.1 and peak <= 1.0, "a quiet mic is brought up to speaking level, a loud one never clips (peak %.2f)" % peak)


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
	var hiss := Radio.degrade(_tone(600, 12000.0, 0.0), 1.0, rng)
	check(VoiceCodec.rms(clean) > 15.0 * VoiceCodec.rms(hiss), "close up, the static is faint under the voice (voice %.3f, hiss %.3f)" % [VoiceCodec.rms(clean), VoiceCodec.rms(hiss)])


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
				used[VoiceLines.resolve(m.get_string(1))] = true
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
	var sysop_voiced: bool = VoiceLines.CHARACTERS.has("SYSOP") or VoiceLines.LINES.values().any(func(l): return l["speaker"] == "SYSOP")
	var sysop_named: Array = docs.keys().filter(func(path): return docs[path].to_upper().contains("SYSOP"))
	var warden_l0: Array = VoiceLines.LINES.keys().filter(func(id): return VoiceLines.LINES[id]["speaker"] == "WARDEN" and VoiceLines.scene(VoiceLines.LINES[id]["scene"])["level"] == 0)
	var cut: String = VoiceLines.get_line("l2_contain_1")["text"].trim_suffix("--")
	check(VoiceLines.get_line("l2_contain_2")["text"].begins_with(cut), "after its PA tape interrupts, WARDEN repeats its warning word for word")
	var renamed_ok := VoiceLines.RENAMED.keys().all(func(old): return not VoiceLines.LINES.has(old) and VoiceLines.LINES.has(VoiceLines.RENAMED[old]) and VoiceLines.get_line(old) == VoiceLines.LINES[VoiceLines.RENAMED[old]])
	check(renamed_ok, "old ids of moved lines still find the line under its new id")
	check(VoiceLines.CUT.all(func(id): return VoiceLines.has_line(id) and VoiceLines.get_line(id).is_empty()), "cut lines are known but play nothing")
	check(warden_l0.is_empty(), "WARDEN says nothing in Level 0 %s" % [warden_l0])
	check(not sysop_voiced and sysop_named.is_empty(), "SYSOP stays text-only and out of every actor's script %s" % [sysop_named])
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
	var warden_path := Voice.folder.path_join("l2_sealed.wav")
	wav.save_to_wav(warden_path)
	voice.play("l2_sealed")
	check(voice._player.bus == Voice.PA_BUS and AudioServer.get_bus_index(Voice.PA_BUS) >= 0, "WARDEN plays through the PA speaker sound")
	var pa_path := Voice.folder.path_join("l0_pa_1.wav")
	wav.save_to_wav(pa_path)
	voice._player.bus = &"Master"
	voice.play("l0_pa_1")
	check(voice._player.bus == Voice.PA_BUS, "the building's announcements play through the PA speaker sound too")
	var pa_bus := AudioServer.get_bus_index(Voice.PA_BUS)
	var hall: AudioEffectReverb = null
	for i in AudioServer.get_bus_effect_count(pa_bus):
		if AudioServer.get_bus_effect(pa_bus, i) is AudioEffectReverb:
			hall = AudioServer.get_bus_effect(pa_bus, i)
	check(hall != null and hall.room_size >= 0.8 and hall.predelay_msec > 0.0 and hall.dry >= 1.0, "the PA echoes like a big empty hall without burying the voice")
	voice.queue_free()
	DirAccess.remove_absolute(wav_path)
	DirAccess.remove_absolute(warden_path)
	DirAccess.remove_absolute(pa_path)
	Voice.folder = real_folder


func test_pause_holds_subtitles() -> void:
	print("Pause holds subtitles")
	var hud := HUD.new()
	root.add_child(hud)
	await process_frame
	hud.say("ROURKE", "Front desk is this way.", 0.3)
	paused = true
	await create_timer(0.6).timeout  # this wait runs through the pause
	check(hud._subtitle.text != "", "a subtitle stays up while the game is paused")
	paused = false
	await create_timer(0.6).timeout
	check(hud._subtitle.text == "", "and clears once its time has run after unpausing")
	hud.queue_free()


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
	check(level.player.seated and level.find_children("Windscreen", "", true, false).size() == 1, "players start belted in, behind a solid windscreen")
	check(level.rourke.global_position.distance_to(level.ROURKE_OUTSIDE) < 0.3 and level.rourke.visible, "Rourke is already waiting outside the front doors")
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
	check(not level.player.seated, "out of the van, the player can walk again")
	var mpos: Vector3 = mate.global_position
	check(mpos.x > 3.5 and mpos.y < 0.3 and not mate.input_locked, "a rear-bench player climbs out of the side door (%.1f, %.1f, %.1f)" % [mpos.x, mpos.y, mpos.z])
	mate.queue_free()
	level.player.global_position = Vector3(0, 0.1, 11.5)
	await create_timer(3.5).timeout
	check(level.front_doors.is_open and level.rourke.global_position.z > 7.5, "Rourke comes out to meet the crew")
	level.desk_terminal.enabled = true
	level.terminal_ui.terminal = level.desk_terminal
	level.terminal_ui.run("SELECT * FROM table_name;")
	check(not level.peek_puzzle.solved and TerminalUI._plain(level.desk_terminal.transcript[-1]).contains("table_name is a blank. the real name is handwritten on the ScanRight card."), "typing table_name literally gets SYSOP pointing at the ScanRight card")
	level.terminal_ui.run("SELECT * FROM nonsense")
	check(not TerminalUI._plain(level.desk_terminal.transcript[-1]).contains("ScanRight"), "other missing tables get the usual explanation")
	level.terminal_ui.run("SELECT * FROM memo_fragments")
	check(level.peek_puzzle.solved, "terminal run solves the peek")
	var nudge: Array = Array(level.desk_terminal.transcript).filter(func(l): return l.contains("ORDER BY"))
	check(not nudge.is_empty() and nudge.all(func(l): return not l.contains("piece_no")), "SYSOP's nudge points at the numbering column without naming it")
	level.terminal_ui.run("SELECT * FROM memo_fragments ORDER BY piece_no DESC")
	check(not level.memo_puzzle.solved and Array(level.desk_terminal.transcript).any(func(l): return l.contains("memo backwards")), "a memo sorted DESC doesn't count, and SYSOP says why")
	level.terminal_ui.run("SELECT * FROM memo_fragments ORDER BY piece_no")
	check(level.memo_puzzle.solved, "terminal run solves the memo")
	check(_game().query_log.size() >= 2 and _game().concepts_learned.has("ORDER BY"), "queries are logged for Field Notes")
	_check_l0_documents(level)
	# Walking into the west end of the counter vaults you over it, and back again.
	level.rourke.walk_to(Vector3(-0.5, 0, 0.6))
	var lp: Player = level.player
	lp.local_control = false  # driven by the test, not the keyboard
	lp.global_position = Vector3(-3.6, 0.05, 0.4)
	lp.rotation.y = 0.0
	await create_timer(0.3).timeout
	lp.controls.move = Vector2(0, -1)
	var vaulted := false
	for i in 120:
		lp.controls.jump = not vaulted and lp.global_position.z < -0.1  # W + Space at the counter
		await physics_frame
		vaulted = vaulted or lp.state == Player.Move.VAULT
	pos = lp.global_position
	check(vaulted and pos.z < -1.6 and pos.y < 0.3, "W + Space at the counter vaults you over to the back (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z])
	lp.rotation.y = PI
	lp.global_position.z = -2.6
	vaulted = false
	for i in 120:
		lp.controls.jump = not vaulted and lp.global_position.z > -1.9
		await physics_frame
		vaulted = vaulted or lp.state == Player.Move.VAULT
	check(vaulted and lp.global_position.z > -0.4, "and back to the lobby side")
	lp.controls.move = Vector2.ZERO
	lp.local_control = true
	# Let the greeting on the steps finish and the crew come inside first, as in play.
	for i in 1800:
		if level.sync._gates.has("inside"):
			break
		await physics_frame
	check(level.sync._gates.has("inside"), "Rourke greets the crew outside, then they all come in")
	# Rourke walks the crew down the hall himself; nothing blocks the way.
	level._on_walkies()
	for i in 1500:  # the PA's escort tape and Rourke's cover come first
		if level.shutter.is_open:
			break
		await physics_frame
	check(level.shutter.is_open, "Rourke opens the hall shutter all the way (Rourke at %s)" % level.rourke.global_position)
	level.player.global_position = Vector3(8.2, 0.1, 3)
	for i in 60:
		await physics_frame
	check(level.rourke.state == Rourke.State.WALK and level.rourke._walk_target.x > 20.0, "Rourke leads the way down the hall to Server Room A")
	# No pipes in the hall any more: it's a plain walk to the room.
	check(level.find_children("CableTray", "", true, false).is_empty(), "the hall to Server Room A is clear")
	# The air return: the grate comes off by hand, then it's a crawl to the closet.
	check(level.vent_grate.enabled, "the air return has a grate on it")
	level._on_vent_grate()
	check(not level.vent_grate.enabled and level.find_children("*", "MovementVolume", true, false).any(func(v): return v.kind == MovementVolume.Kind.VENT), "the grate comes off, and the duct behind it is a crawlspace")
	var crawler: Player = level.player
	var was_seated := crawler.seated
	crawler.seated = false
	crawler.local_control = false
	crawler.global_position = Vector3(-7.0, 0.1, 4)
	crawler.rotation.y = PI / 2  # facing the air return
	crawler.controls.crouch = true
	crawler.controls.move = Vector2(0, -1)
	for i in 360:
		await physics_frame
	check(crawler.global_position.x < -14.0, "holding crouch and walking in crawls all the way through to the closet (x %.1f)" % crawler.global_position.x)
	crawler.controls.crouch = false
	crawler.controls.move = Vector2.ZERO
	crawler.seated = was_seated
	crawler.local_control = true
	# Ordinary hinged doors open and shut with E; Server Room A's is a badge door.
	check(level.exit_door.get_prompt(crawler) == "Locked", "Server Room A's door says it's locked")
	level.exit_door.interact(crawler)
	check(not level.exit_door.is_open, "and E doesn't open it: only Rourke's badge does")
	var plain := Door.create(level, "TEST-PLAIN", Vector3(30, 1.2, 30), Vector3(0.1, 2.4, 0.9)).make_hinged(Vector3(0, 0, -0.45))
	await process_frame
	check(plain.get_prompt(crawler).contains("Open"), "an ordinary door offers to open")
	plain.interact(crawler)
	check(plain.is_open and plain.get_prompt(crawler).contains("Close"), "E opens it, and then offers to close it")
	plain.interact(crawler)
	check(not plain.is_open, "E again shuts it")
	level.queue_free()
	await process_frame


func test_ground_floor() -> void:
	print("Ground floor")
	_game().new_run(6)
	var level = load("res://scenes/level_0.tscn").instantiate()
	root.add_child(level)
	for i in 30:
		await physics_frame
	var p: Player = level.player
	level._release_camera(p)
	p.seated = false
	# Every room off the lobby can be walked to, and the dark corridor loops back to the hall.
	var map: RID = p.get_world_3d().navigation_map
	var lobby := Vector3(0, 0, 3)
	for room in [["mailroom", Vector3(-16.5, 0, -14)], ["men's", Vector3(-11.5, 0, -13)], ["women's", Vector3(-8.5, 0, -13)],
			["cafeteria", Vector3(0, 0, -14)], ["IT closet", Vector3(10, 0, -12)], ["dark corridor", Vector3(15, 0, -8.5)],
			["hall, by the dark passage", Vector3(18, 0, 3)], ["elevator bank", Vector3(27, 0, 3)]]:
		var path := NavigationServer3D.map_get_path(map, lobby, room[1], true)
		check(path.size() > 1 and path[path.size() - 1].distance_to(room[1]) < 1.0, "the %s can be reached from the lobby" % room[0])
	var loop := NavigationServer3D.map_get_path(map, Vector3(18, 0, 3), Vector3(6.5, 0, -8.5), true)
	check(loop.size() > 1 and loop[loop.size() - 1].distance_to(Vector3(6.5, 0, -8.5)) < 1.0 and Array(loop).all(func(q): return q.x < 20.0), "from the hall, the dark corridor leads back round to the lobby without the elevator bank")
	for id in ["MAILROOM", "MENS", "WOMENS", "IT-CLOSET"]:
		var d: Door = level.doors[id]
		check(d.is_hinged() and not d.locked and d.get_prompt(p).contains("Open"), "the %s door is an ordinary door you can open" % id)
	# Nothing discoverable is labelled.
	var labels: Array = level.find_children("*", "Label3D", true, false).map(func(l): return l.text.to_upper())
	check(not labels.any(func(t): return t.contains("VENT") or t.contains("AIR RETURN")), "vents carry no labels")
	# The Hum: it grows while you stand in the dark corridor, and fades with your flashlight on.
	var hum: Hum = level.hum
	p.flashlight.visible = false
	p.global_position = Vector3(15, 0.1, -8.5)
	await create_timer(2.0).timeout
	var grown: float = hum.intensity
	check(grown > 0.1 and hum.is_humming(), "standing in the dark corridor, the Hum grows (%.2f)" % grown)
	p.flashlight.visible = true
	await create_timer(1.5).timeout
	check(hum.intensity < grown - 0.2, "with the flashlight on, it fades (%.2f)" % hum.intensity)
	p.flashlight.visible = false
	p.global_position = Vector3(0, 0.1, 3)
	await create_timer(3.0).timeout
	check(not hum.is_humming(), "back in the lit lobby, it's gone")
	check(level.elevator.button.enabled == false, "the elevator won't go anywhere until Rourke takes the crew up")
	# Trust beats while the crew works on the memo: Rourke wanders over to help.
	level.rourke.global_position = level.DESK_SPOT
	level._on_hatch(null)
	await process_frame
	check(level.hud._notice.text.contains("stuck"), "the ceiling panel in the IT closet is stuck and too high alone")
	level._rourke_free = true
	level._on_vending(null)
	for i in 1800:
		if level.geo.has_node("CoffeeCup"):
			break
		await physics_frame
	check(level.geo.has_node("CoffeeCup") and level.rourke.global_position.distance_to(Vector3(6.2, 0, -12)) < 1.0, "at the vending machine, Rourke knows the trick and gets a coffee out")
	level._on_vending(null)
	await process_frame
	check(not level.vending.enabled or level.hud._notice.text.contains("keeps it"), "only once")
	for i in 1800:
		if level._rourke_can_help():
			break
		await physics_frame
	check(level._rourke_can_help(), "he walks back to the front desk")
	level._on_hatch(null)
	for i in 1800:
		if level.find_children("*", "Document", true, false).any(func(d): return d.title == "Old sticker"):
			break
		await physics_frame
	check(not level.ceiling_hatch.enabled and level.rourke.global_position.distance_to(Vector3(10, 0, -11)) < 1.0, "in the IT closet, he gives a leg up to the stuck ceiling panel")
	for i in 1800:
		if level.rourke.global_position.distance_to(level.DESK_SPOT) < 0.5:
			break
		await physics_frame
	check(level.rourke.global_position.distance_to(level.DESK_SPOT) < 0.5, "then goes back to the front desk")
	level.queue_free()
	await process_frame


func test_level_1_scene() -> void:
	print("Level 1 scene: the server floor")
	_game().new_run(7)
	var level = load("res://scenes/level_1.tscn").instantiate()
	root.add_child(level)
	for i in 30:
		await physics_frame
	check(level.doors["SRA-EXIT"].is_open == false and level.room_c_door.locked, "Server Room A's rear door and Server Room C start stuck")
	check(not level.elevator.button.enabled and level.elevator.open_amount == 0.0, "the elevator up is out of service")
	check(level.terminal.locked, "the terminal waits for Rourke's maintenance session")
	level._on_panel(null, level.answer)
	check(not level.controller_puzzle.solved and level.doors["SRA-EXIT"].is_open == false, "the racks do nothing before Rourke asks")
	level._on_asked()
	check(not level.terminal.locked and _game().current_todo() != "", "once Rourke asks, the terminal opens and the job goes on the to-do list")
	check(not level.rourke.is_in_group(VoiceChat.INTERFERENCE_GROUP) and Rourke.State.keys()[level.rourke.state] != "CHASE", "no fight on the server floor")
	# Every room of the floor is on the navigation mesh, reachable from the arrival corridor.
	var map: RID = level.get_world_3d().navigation_map
	for i in 5:
		await physics_frame
	var from: Vector3 = level.to_global(Vector3(0, 0, 11))
	var rooms := {"the NOC": Vector3(-15, 0, 3), "the cable vault": Vector3(-15, 0, -6), "Server Room B": Vector3(15, 0, 3),
		"the break room": Vector3(15, 0, -6), "Server Room C": Vector3(-12, 0, -18.5), "the north corridor": Vector3(0, 0, -11)}
	for room_name in rooms:
		var to: Vector3 = level.to_global(rooms[room_name])
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		check(path.size() > 1 and path[path.size() - 1].distance_to(to) < 1.0, "%s is reachable on foot" % room_name)
	var round_west := NavigationServer3D.map_get_path(map, level.to_global(Vector3(-14.5, 0, 10)), level.to_global(Vector3(-12, 0, -10.5)), true)
	check(round_west.size() > 1 and Array(round_west).all(func(q): return level.to_local(q).x < -7.5), "the west side loops round through the NOC and the cable vault, not Server Room A")

	level.terminal_ui.terminal = level.terminal
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = 'A'")
	check(not level.controller_puzzle.solved, "zone alone isn't enough")
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = 'A' AND status = 'fault'")
	check(level.controller_puzzle.solved, "WHERE + AND finds the controller")
	_check_l1_documents(level)
	var healthy: String = level.db.run_silent("SELECT id FROM door_controllers WHERE status = 'ok' AND location LIKE 'Server Room A%'")[0]["id"]
	level._on_panel(null, healthy)
	check(level.panels_locked_until == 0.0, "pressing a healthy rack explains itself without a lockout")
	var wrong: String = level.db.run_silent("SELECT id FROM door_controllers WHERE zone = 'A' AND status = 'offline'")[0]["id"]
	level._on_panel(null, wrong)
	check(level.doors["SRA-EXIT"].is_open == false and level.panels_locked_until > 0.0, "an offline zone-A rack fixes nothing")
	check(level.hud._notice.text.contains("'offline'") and level.hud._notice.text.contains("off on purpose"), "the rack's readout shows why it was the wrong one, where the player is standing")
	level.panels_locked_until = 0.0
	level._on_panel(null, level.answer)
	for i in 1500:
		if level.doors["SRA-EXIT"].is_open:
			break
		await physics_frame
	check(level.rourke.global_position.distance_to(level.rack_panels[level.answer].global_position) < 1.6, "Rourke comes over to badge the reset")
	check(level.doors["SRA-EXIT"].is_open and not level.room_c_door.locked, "resetting the right rack frees the floor's stuck doors")
	var shown := "\n".join(Array(level.terminal.transcript))
	check(shown.contains("VALE_I") and shown.contains("SECURE LAB B"), "the controller's log points at Vale's lab")
	check(level.find_children("*", "Document", true, false).any(func(d): return d.title == "SYSLOG PRINTOUT" and str(d.doc_lines).contains("VALE")), "and so does the syslog printout in Server Room C")
	check(_game().rourke_fate == "unknown", "Rourke's fate is still open after the server floor")

	# The cable vault's spare coil: whoever takes it carries it up.
	level.cable_coil.interact(level.player)
	await physics_frame
	check(level.cable_holders.has(level.players.id_of(level.player)) and not level.cable_coil.visible, "taking the coil of network cable marks who carries it")

	# Rourke heads for the elevator; it opens once the crew is with him.
	for i in 2400:
		if level.sync._gates.has("rourke_at_lift"):
			break
		await physics_frame
	check(level.sync._gates.has("rourke_at_lift") and level.rourke.global_position.distance_to(level.to_global(Vector3(1.8, 0, -11))) < 0.5, "Rourke walks the crew through Server Room A to the elevator")
	check(level.elevator.open_amount == 0.0, "the elevator waits for the crew")
	level.player.global_position = level.to_global(Vector3(-1.5, 0.1, -11))
	for i in 900:
		if level.sync._gates.has("rourke_in_lift"):
			break
		await physics_frame
	check(level.elevator.open_amount > 0.9 and level.elevator.contains(level.rourke.global_position), "with everyone there, the elevator opens and Rourke steps in")
	level.player.global_position = level.elevator.to_global(Vector3(-0.6, 0.1, 1.2))
	await physics_frame
	check(level.elevator.button.get_prompt(level.player).contains("Press 2"), "inside, the button says where it goes")
	level.player.global_position = level.to_global(Vector3(0, 0.1, -10.5))
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
	check(c2.desk_terminal.transcript.any(func(l): return l.contains("scraps are out of order")), "SYSOP's reply shows on every copy")
	# Documents are read and copied on your own machine only.
	var brochures: Array = levels.map(func(l): return _doc(l, "ScanRight"))
	check(brochures.all(func(d): return d != null and d.local_only), "documents are read locally, not through the host")
	brochures[1].interact(c1.player)
	check(c1.find_children("*", "DocumentReader", true, false).size() == 1 and host.find_children("*", "DocumentReader", true, false).is_empty() \
		and c2.find_children("*", "DocumentReader", true, false).is_empty(), "a client reading a document opens it on their screen only")
	c1.find_children("*", "DocumentReader", true, false)[0].close()
	await _frames(2)
	check(not c1.player.input_locked, "putting the document down gives the client their controls back")

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

	host.player.global_position = Vector3(0, 0.1, 11.5)
	client.player.global_position = Vector3(-4.5, 0.1, 7.4)  # at the terminal desk
	host.sync.event("_on_asked")
	await _frames(30)
	check(not host.terminal.locked and not client.terminal.locked, "Rourke's ask opens the terminal for everyone")
	client.terminal.interact(client.player)
	await _frames(5)
	check(client.terminal_ui.visible and not host.terminal_ui.visible, "a client sits down at the terminal on their own screen")
	client.terminal_ui.close()

	host.rourke.global_position = Vector3(-3, 0, 5)
	await _frames(20)
	check(client.rourke.global_position.distance_to(host.rourke.global_position) < 1.0, "clients see Rourke where the host has him")

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
	check(mate.crawling and mate.stance_height < 1.0 and mate.rig.crawl_amount() > 0.9, "a teammate crawling shows crawling for the others, not standing")
	client.player._set_stance(Player.STAND_HEIGHT)
	await _frames(10)
	check(not mate.crouching and is_equal_approx(mate.stance_height, Player.STAND_HEIGHT) and mate.rig.crouch_amount() == 0.0, "and stands back up with them")
	client.player.set_physics_process(true)

	client.player.global_position = Vector3(-17.5, 0.1, -7.2)
	await _frames(5)
	client.cable_coil.interact(client.player)
	await _frames(10)
	check(host.cable_holders.has(client_id) and client.cable_holders.has(client_id) and not host.cable_coil.visible, "the client takes the cable coil, and every machine knows who carries it")

	# The elevator: the host counts heads, then the doors close everywhere.
	host.sync.event("_on_crew_at_lift")
	await _frames(5)
	for l in levels:
		l.elevator.closed.disconnect(l._on_elevator_closed)  # stay in this level for the checks
		l.elevator.open(true)
	host.player.global_position = host.elevator.to_global(Vector3(0.4, 0.1, 1.2))
	client.player.global_position = Vector3(-3, 0.1, -11.0)
	await _frames(30)
	client.elevator.button.interact(client.player)
	await _frames(10)
	check(host.elevator.refusal.contains("1/2") and not host.elevator.is_closing and not client.elevator.is_closing, "the elevator waits for a teammate still outside")
	client.player.global_position = client.elevator.to_global(Vector3(-0.4, 0.1, 1.2))
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


func test_coop_terminal_screens() -> void:
	print("Co-op: terminal screens are shared")
	_game().new_run(5)
	var worlds := await _coop_worlds(1)
	var levels := await _coop_load(worlds, "res://scenes/level_0.tscn")
	var host = levels[0]
	var c1 = levels[1]
	var c1_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()
	var screen: Terminal = host.desk_terminal  # the host's copy of the client's terminal
	var ui: TerminalUI = c1.terminal_ui

	ui.open(c1.desk_terminal, c1.player)
	await _frames(10)
	check(screen.seated == [c1_id], "the host sees the client sit down at the terminal")
	check(not screen.transcript.is_empty() and screen.transcript == c1.desk_terminal.transcript, "the boot screen shows on the host's copy too")

	var changes := [0]
	screen.screen_changed.connect(func(): changes[0] += 1)
	for word in ["S", "SE", "SEL", "SELE", "SELEC", "SELECT", "SELECT *", "SELECT * FROM"]:
		ui._input.text = word
		ui._typed()
	await _frames(10)
	check(screen.typing.get(c1_id, "") == "SELECT * FROM", "the host sees what the client is typing")
	check(changes[0] <= 2, "typing is rate-limited, not sent per keystroke (%d updates)" % changes[0])

	host.terminal_ui.open(host.desk_terminal, host.player)
	await _frames(10)
	check(c1.desk_terminal.seated.size() == 2 and screen.seated.size() == 2, "two players can sit at the same terminal")
	check(host.terminal_ui._others.visible and host.terminal_ui._others.text.contains("SELECT * FROM"), "the host's screen shows the client's line being typed")

	ui._input.text = ".help"
	ui._typed()
	ui._submit()
	await _frames(10)
	check(not screen.typing.has(c1_id), "entering the line clears it from the host's screen")
	check(screen.transcript.any(func(l): return l.contains("Commands:")), ".help output shows on the host's copy of the screen")
	check(host.terminal_ui._output.get_parsed_text().contains("Commands:"), "and on the host's open terminal window")

	ui.run(".hint")
	await _frames(10)
	check(screen.transcript.any(func(l): return l.contains("SYSOP")), "a client's .hint is readable over their shoulder")
	check(screen.transcript == c1.desk_terminal.transcript, "both copies of the screen match line for line")

	ui.run(".clear")
	await _frames(10)
	check(screen.transcript.is_empty() and c1.desk_terminal.transcript.is_empty(), ".clear wipes the screen for everyone")
	check(host.terminal_ui._output.get_parsed_text().strip_edges() == "", "including the host's open window")

	ui.close()
	await _frames(10)
	check(screen.seated.size() == 1 and not screen.seated.has(c1_id), "stepping away frees the seat on the host")
	host.terminal_ui.close()
	ui.open(c1.desk_terminal, c1.player)
	await _frames(10)
	get_multiplayer(worlds[1].get_path()).multiplayer_peer.close()
	await _frames(30)
	check(screen.seated.is_empty() and screen.typing.is_empty(), "a player who drops out leaves the terminal free")
	ui.close()
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
	for f in 1800:  # the PA tape and Rourke's cover, then he walks to the hall shutter
		await physics_frame
		if lobby_h.sync._gates.has("rourke_at_shutter"):
			break
	lobby_h.sync.event("_on_reach_server_room", [null])
	for f in 900:  # Rourke opens the elevator bank's door and says his line
		await physics_frame
		if lobby_h.sync._gates.has("rourke_holds_door") and lobby_c.sync._gates.has("rourke_holds_door"):
			break
	# Both walk past him into the elevator bank; once the door shuts, the car opens.
	for w in machines:
		w.player.global_position = Vector3(28.0, 0.2, 1.5)
	client.player.global_position = Vector3(28.0, 0.2, 4.5)
	for f in 1200:
		await physics_frame
		if lobby_h.elevator.open_amount > 0.99 and lobby_c.elevator.open_amount > 0.99 and lobby_h.sync._gates.has("rourke_in_lift"):
			break
	check(lobby_c.elevator.open_amount > 0.99 and not lobby_c.exit_door.is_open, "the door shuts behind the crew and the elevator opens on every machine")
	host.player.global_position = lobby_h.elevator.to_global(Vector3(-0.6, 0.2, 1.0))
	client.player.global_position = lobby_c.elevator.to_global(Vector3(0.0, 0.2, 0.7))
	await _frames(20)
	lobby_c.elevator.button.interact(client.player)
	for f in 900:
		await physics_frame
		if host.current == sra_h and client.current == sra_c:
			break
	await _frames(10)
	check(host.current == sra_h and client.current == sra_c and sra_c.active, "play moves into Server Room A on every machine")

	sra_h.rourke.global_position = sra_h.to_global(Vector3(-3, 0, 5))
	await _frames(20)
	check(sra_c.rourke.global_position.distance_to(sra_h.rourke.global_position) < 1.0, "clients see the wing's Rourke where the host has him")
	sra_h.sync.event("_on_asked")
	await _frames(10)
	sra_c.terminal_ui.terminal = sra_c.terminal
	sra_c.terminal_ui.run("UPDATE doors SET locked = 0 WHERE id = 'SRA-EXIT'")
	await _frames(10)
	check(sra_h.doors["SRA-EXIT"].is_open and sra_c.doors["SRA-EXIT"].is_open, "a client's query in a wing opens the door for everyone")
	check(_table(sra_h, dump) == _table(sra_c, dump), "the shared database still matches")
	check(host.players.puppet(client_id) != null, "the client is still in the game")
	await _coop_close(worlds)


## Augustine's co-op playtest: the host followed Rourke to the desk first, and the
## story stopped. Walking in one at a time must still count everyone, and Rourke
## must not be shut out by the front doors.
func test_coop_lobby_walk_in() -> void:
	print("Co-op: walking into the lobby one at a time")
	_game().new_run(9)
	var worlds := await _coop_worlds(1)
	var m := await _coop_load(worlds, "res://scenes/world.tscn")
	var h = m[0].current
	var c = m[1].current
	h.van_seats[0].buckle.interact(m[0].player)
	c.van_seats[1].buckle.interact(m[1].player)
	for f in 2400:
		await physics_frame
		if h.player.input_locked == false and h._intro_started and h.get_tree() and f > 600:
			break
	for p in [m[0].player, m[1].player]:
		p.global_position = h.to_global(Vector3(0, 0.1, 11.5))
	for f in 2400:
		await physics_frame
		if h.rourke.state == Rourke.State.WALK and c.sync._gates.has("approach"):
			break  # he's said hello on the steps and is heading in
	m[0].player.global_position = h.to_global(Vector3(0, 0.1, 4.5))
	await _frames(20)
	m[0].player.global_position = h.to_global(Vector3(0, 0.1, 1.8))
	await _frames(20)
	m[1].player.global_position = h.to_global(Vector3(1, 0.1, 4.5))
	await _frames(20)
	m[1].player.global_position = h.to_global(Vector3(1, 0.1, 1.8))
	for f in 3000:
		await physics_frame
		if c.visitor_log.enabled:
			break
	check(h.sync._gates.has("inside") and c.sync._gates.has("inside"), "a crew walking in one at a time all counts as inside")
	check(c.visitor_log.enabled and h.to_local(h.rourke.global_position).z < 3.0, "Rourke makes it through the front doors to the desk")
	c.visitor_log.interact(m[1].player)
	for f in 1500:
		await physics_frame
		if c.desk_terminal.enabled:
			break
	check(h.desk_terminal.enabled and c.desk_terminal.enabled, "the client signs in and the story carries on for everyone")
	await _coop_close(worlds)


func test_coop_level_2() -> void:
	print("Co-op: Level 2 with a host and a client")
	_game().new_run(5)
	_game().rourke_fate = "killed"  # just the security section: Rourke turned before it
	var worlds := await _coop_worlds(1)
	var machines := await _coop_load(worlds, "res://scenes/level_2.tscn")
	var host = machines[0]
	var client = machines[1]
	var client_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()
	check(machines.all(func(l): return l.sync._begun and l.players.count() == 2), "both machines start Level 2 with two players")
	host.player.input_locked = true  # the host looks at nothing; the client does the work
	client.terminal_ui.terminal = client.booth
	client.terminal_ui.run("GET /cameras")
	await _frames(10)
	check(machines.all(func(l): return l.cameras_puzzle.solved and l.booth.transcript.any(func(t): return t.contains("JSON"))), "a client's GET /cameras solves it, and the JSON lines print on every machine")
	client.terminal_ui.run("SELECT * FROM guards WHERE name LIKE 'Pike%'")
	await _frames(10)
	check(machines.all(func(l): return l.pike_puzzle.solved and l.loose and l.frozen_cams.has("CAM-2")), "the Pike practice freezes CAM-2 for everyone")
	client.terminal_ui.run("SELECT * FROM guards WHERE name LIKE 'Har%' AND shift = 'night'")
	await _frames(20)
	check(machines.all(func(l): return l.har_puzzle.solved), "LIKE + AND finds the PIN for everyone")
	check(client.watcher.global_position.distance_to(host.watcher.global_position) < 0.2, "clients see the Watcher where the host has it")
	client.type_pin("office", host.data.pin, client.player)
	await _frames(10)
	check(machines.all(func(l): return l.office_open and l.doors["SEC-OFFICE"].is_open) and host.watcher.active, "a client's PIN opens the office door on every machine, and it's free")
	host.watcher.holders.append(func(_w): return true)  # hold it still for the rest of the test
	await _frames(2)
	host.watcher.place(host.to_global(Vector3(0, 0, 4)), host.to_global(Vector3(3, 0, 4)))
	await _frames(20)
	check(client.watcher.global_position.distance_to(host.watcher.global_position) < 0.2, "when it moves, clients see it move")

	# Someone on another machine looking at it holds it too.
	client.player.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), client.to_global(Vector3(3, 0.1, 4)))
	client.player.head.rotation = Vector3.ZERO
	await _frames(20)
	var puppet = host.players.puppet(client_id)
	host.watcher.holders.clear()
	host.watcher.active = false
	check(puppet != null and host.watcher.player_sees(puppet), "the host knows a client is looking at it")
	host.watcher.place(host.to_global(Vector3(5.5, 0, 4)), host.to_global(Vector3(3, 0, 4)))
	await physics_frame
	check(not host.watcher.player_sees(puppet), "and that it's behind them when it is")
	host.watcher.holders.append(func(_w): return true)
	host.watcher.place(host.to_global(Vector3(-4, 0, -6)), host.to_global(Vector3(0, 0, 0)))

	client.key_glass.take_hit(client.player)
	await _frames(10)
	check(machines.all(func(l): return not is_instance_valid(l.key_glass)), "a client's strike breaks the glass on every machine")
	client.geo.get_node("Screwdriver").interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return l.has_screwdriver and l.geo.get_node_or_null("Screwdriver") == null), "the screwdriver is picked up for everyone")
	client.vent_grate.interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return not l.vent_grate.enabled), "the grate comes off on every machine")

	client.type_pin("exit", host.data.pin, client.player)
	await _frames(10)
	check(machines.all(func(l): return l.pin_entered and not l.door_open), "the stairwell PIN goes through for everyone, and the door still jams")
	client.breakers[host.data.breaker].interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return l.door_open and l.doors["SEC-EXIT"].is_open), "a client's breaker reset opens SEC-EXIT for everyone")
	await _frames(100)
	for l in machines:
		l.completed.disconnect(l._on_completed)
	client.player.global_transform = Transform3D(Basis(), client.to_global(Vector3(0, 0.1, -18.2)))
	await _frames(20)
	client.exit_lift.button.interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return not l.exit_lift.is_closing), "the doors won't close while someone is still outside")
	client.seal_button.interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return not l.doors["SEC-EXIT"].is_open), "a client can lock SEC-EXIT behind the team")
	host.player.input_locked = false
	host.player.global_transform = Transform3D(Basis(), host.to_global(Vector3(0.6, 0.1, -18.4)))
	await _frames(20)
	client.exit_lift.button.interact(client.player)
	await _frames(180)
	check(machines.all(func(l): return l.exit_lift.open_amount == 0.0), "with everyone inside, the doors shut on every machine")
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
	check(stacked and door_ids.has("SRA-EXIT") and door_ids.has("SEC-EXIT") and door_ids.has("SEC-OFFICE") and door_ids.has("SECLAB-B") and door_ids.size() == doors_before + 4, "the wing's seed loads on top of Level 1's: only SEC- and SECLAB- doors added (%s)" % [door_ids])
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
	_game().rourke_fate = "killed"  # just the security section: Rourke turned before it
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
	check(level.stage == "near" and w.global_position.distance_to(level.to_global(level.STAGES.near[0])) < 0.2, "closer to the PIN, it creeps closer while nobody looks")
	check(w.active, "finding Pike wakes it: the Har search is typed while it hunts")
	p.global_transform = Transform3D(Basis(), Vector3(-3, 0.1, 3.4))
	p.head.rotation = Vector3.ZERO
	await physics_frame
	await physics_frame
	check(w.player_sees(p), "now players can see it through the office window")
	var watched: Vector3 = w.global_position
	for i in 10:
		await physics_frame
	check(w.global_position.distance_to(watched) < 0.05, "it doesn't move while someone is watching it")
	# Back at the booth, typing with it behind them: it comes, but the door and glass hold.
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-3, 0.1, 4.6))
	level.terminal_ui.run("SELECT * FROM guards WHERE name LIKE 'Har%' AND shift = 'night'")
	check(level.har_puzzle.solved, "LIKE + AND finds the PIN")
	for i in 240:
		await physics_frame
	check(w.global_position.distance_to(watched) > 1.0 and level.to_local(w.global_position).z < 2.0 and p.health > 0.0, "unseen, it hunts, but the locked office door keeps it in")
	p.global_transform = Transform3D(Basis(), Vector3(-3, 0.1, 2.35))
	p.head.rotation = Vector3.ZERO
	w.place(level.to_global(Vector3(-3, 0, 1.6)), p.global_position)
	w.holders.append(func(_w): return false)
	p.input_locked = true  # not looking: only the glass is between them
	for i in 30:
		await physics_frame
	check(p.health > 0.0, "it can't get you through the glass")
	p.input_locked = false
	w.holders.clear()
	w.holders.append(level._camera_holds)
	check(not level.check_pin("12a4").ok and not level.check_pin(level.data.pike_pin).ok, "letters and Pike's suspended PIN are refused")
	check(level.check_pin(level.data.pike_pin).message.contains("suspended"), "a wrong guard's PIN says why it was refused")
	check(level.check_pin(level.data.pin).ok, "the night-shift Har- guard's PIN is accepted")
	# Open the office from the east end of the corridor, then look away.
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(3, 0.1, 4.6))
	level.type_pin("office", level.data.pin)
	for i in 5:
		await physics_frame
	check(level.doors["SEC-OFFICE"].is_open and w.active, "the PIN opens the office door, and it's free")
	var before: float = w.global_position.distance_to(p.global_position)
	for i in 90:
		await physics_frame
	var after: float = w.global_position.distance_to(p.global_position)
	check(after < before - 1.5 and p.health > 0.0, "unseen, it comes for you, through the open door (%.1f m -> %.1f m)" % [before, after])
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
	check(level._lie_explained and _game().cam_lie_learned and level.booth.transcript[-1].contains("last_frame") and (Array(level.panel.transcript) + level.panel.boot_lines).any(func(l): return l.contains("last_frame")), "dying to it explains the frozen camera, as lines you can note on both terminals")
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
	check((Array(level.panel.transcript) + level.panel.boot_lines).any(func(l): return str(l).contains("CAM-3: NO SIGNAL")), "and the panel reports the camera lost its signal")
	check(level.breaker_status.text.contains("CAM-3: NO SIGNAL"), "the breaker box itself shows what the wrong breaker cut")
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
	check(level.exit_lift.headcount() == Vector2i(1, 1) and level.exit_lift.press(p), "inside, the button closes the doors")
	for i in 160:
		await physics_frame
	check(shut[0] and level.exit_lift.open_amount == 0.0, "the doors shut: the wing is done")
	for i in 120:
		await physics_frame
	var taps: Array = level.geo.get_meta("sounds_played", []).filter(func(x): return x.kind == "tap")
	check(taps.size() == 1 and taps[0].pos == level.SEC_EXIT_FRAME and level.hud._subtitle.text == "",
		"leaving, there's one tap on the metal behind SEC-EXIT, and no narration")
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
	_game().rourke_fate = "killed"  # just the security section: Rourke turned before it
	var level = load("res://scenes/level_2.tscn").instantiate()
	root.add_child(level)
	for i in 20:
		await physics_frame
	level.watcher.active = false
	var p: Player = level.player
	p.local_control = false
	# The clues are on paper in the booth, and E copies them into the notebook.
	var docs: Array = level.get_tree().get_nodes_in_group("document").filter(func(d): return level.is_ancestor_of(d))
	var titles: Array = docs.map(func(d): return d.title)
	check(["NIGHT SHIFT SIGN-IN      DATE: 10/15", "Camera system card", "WARDEN manual, p.12", "Lockdown PIN policy", "Door controller card"].all(func(t): return titles.has(t)), "the wing's clues are on documents: roster, camera card, manual page, PIN policy, door card")
	var sheet: Document = docs[titles.find("NIGHT SHIFT SIGN-IN      DATE: 10/15")]
	check(sheet.lines().any(func(l): return l.hand and l.text.begins_with("Har")) and sheet.lines().any(func(l): return l.hand and l.text == "guards"),
		"the sign-in sheet has the half-legible name and the PIN table, handwritten")
	check(not str(docs.map(func(d): return d.plain_text())).contains("Har%"), "no document gives the Har query away")
	# Papers on the walls are drawn full size, their words readable from the room.
	for d in docs:
		var wall_sheet: Node3D = d.get_node_or_null("WallSheet")
		var printed: Array = wall_sheet.find_children("Line*", "Label3D", false, false) if wall_sheet else []
		var shown := " ".join(printed.map(func(l): return l.text))
		check(wall_sheet != null and d.lines().all(func(l): return l.text == "" or shown.contains(l.text) or wall_sheet.find_child("Title", false, false).text == l.text), "%s is on the wall with all its words" % d.title)
		check(printed.all(func(l): return l.font_size >= 20), "%s is printed big enough to read" % d.title)
	var facing := func(title: String) -> float:
		var label: Label3D = docs[titles.find(title)].get_node("WallSheet").find_child("Line0", false, false)
		return label.global_basis.z.z  # Label3D reads from its +Z side
	check(facing.call("NIGHT SHIFT SIGN-IN      DATE: 10/15") < -0.9 and facing.call("Lockdown PIN policy") > 0.9, "wall papers face into the corridor, not into the wall")
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
	check(not level.vent_grate.enabled and level.vent_grate.get_children().filter(func(c): return c is CollisionShape3D).all(func(c): return c.disabled),
		"the screwdriver takes the grate off, and it's out of the way")
	await _frames(40)
	check(level.vent_grate.position.y < 0.5, "the grate drops to the floor, where everyone can see it came off")
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


## The doors are worked from the wall, nothing floats a sign over what's hidden,
## and the exit car closes and drops by itself once everyone is in.
func test_level_2_wall_controls() -> void:
	print("Level 2 wall controls")
	_game().new_run(7)
	_game().rourke_fate = "killed"  # just the security section: Rourke turned before it
	var level = load("res://scenes/level_2.tscn").instantiate()
	root.add_child(level)
	await _frames(20)
	level.watcher.active = false
	level.watcher.holders.append(func(_w): return true)
	var p: Player = level.player
	var signs: Array = level.find_children("*", "Label3D", true, false).map(func(l): return l.text.to_upper())
	check(not signs.any(func(t): return t.contains("VENT") or t == "LOCK" or t == "GUARD PIN"), "no floating sign marks the vent or the lock")
	check(_doc(level, "Badge reader") != null and _doc_has(level, "backup copy"), "a laminated card by the badge reader says the paper sheet is the backup")
	check(_doc_has(level, "(backup copy)") and level.db.run_silent("SELECT note FROM guards WHERE pin = '%s'" % level.data.pin)[0]["note"].contains("Badged in 22:00"), "the sheet is the backup copy, and the answer's row says it badged in")
	var pad: Level2Keypad = level.office_pad
	check(pad.keys.size() == 12 and pad.keys["5"].get_prompt(p).contains("Press 5") and pad.screen.text.contains("GUARD PIN"), "the office door has a wall keypad with twelve keys")
	pad.keys["1"].interact(p)
	pad.keys["2"].interact(p)
	check(pad.screen.text == "12__", "pressed digits show on the pad's screen")
	pad.keys["C"].interact(p)
	check(pad.code == "" and pad.screen.text.contains("GUARD PIN"), "Clear empties it")
	level.type_pin("office", level.data.pike_pin)
	await process_frame
	check(not level.doors["SEC-OFFICE"].is_open and pad.screen.text.contains("REFUSED") and pad.screen.text.contains("suspended"), "a wrong guard's PIN is refused on the pad, saying why")
	level.type_pin("office", level.data.pin)
	await _frames(5)
	check(level.office_open and pad.screen.text.contains("ACCEPTED"), "the right PIN, typed on the wall, opens the office")
	level.type_pin("exit", level.data.pin)
	level._on_breaker(null, level.data.breaker)
	await _frames(5)
	check(level.door_open and level.doors["SEC-EXIT"].is_open, "the exit pad and breaker open SEC-EXIT")
	check(level.seal_button.get_prompt(p).contains("lock") and level.exit_pad.keys.size() == 12, "past the door, a button closes it")
	level.seal_button.interact(p)
	await _frames(5)
	check(not level.doors["SEC-EXIT"].is_open and _game().watcher_sealed, "closing and locking SEC-EXIT needs no PIN")
	level.completed.disconnect(level._on_completed)
	var done := [false]
	level.completed.connect(func(): done[0] = true)
	await _frames(100)
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(0, 0.1, -18.2)))
	await _frames(30)
	check(not level.exit_lift.is_closing, "the car waits a moment once you walk in")
	await create_timer(1.6).timeout
	check(level.exit_lift.is_closing or level.exit_lift.open_amount < 1.0, "then, with everyone inside, its doors close by themselves")
	await create_timer(6.0).timeout
	var card: Node = level.get_node_or_null("EndCard")
	check(card != null and card.find_children("*", "Label", true, false).any(func(l): return l.text == "To be continued."), "the car drops and a black card reads \"To be continued.\"")
	check(level.geo.get_meta("sounds_played", []).any(func(x): return x.kind == "clunk"), "the drop clunks")
	for i in 20:
		if done[0]:
			break
		await create_timer(0.5).timeout
	check(done[0], "after the card, the wing is complete")
	level.queue_free()
	await process_frame


## Augustine's playtest: through the office by the main route, the Watcher never
## moved. Inside the World, it now follows through the open office door and the
## vestibule, and gets you if you look away.
func test_level_2_main_route() -> void:
	print("Level 2 main route, in the World")
	_game().new_run(5)
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await _frames(30)
	world.load_next(world.current)
	var sra = world.wings["level_1"]
	world.wing_finished(world.current)
	world.load_next(sra)
	var sec = world.wings["level_2"]
	world.wing_finished(sra)
	await _frames(10)
	check(world.current == sec and sec.active, "play is in the security wing")
	var p: Player = world.player
	p.global_position = sec.to_global(Vector3(-3, 0.1, 4.4))
	sec._on_cameras_found("booth")
	sec._on_pike_found("booth")
	sec._on_har_found("booth")
	sec.type_pin("office", sec.data.pin)
	await _frames(5)
	check(sec.office_open and sec.watcher.active, "the main route opens the office and frees it")
	# Into the vestibule, back to the office.
	p.global_transform = sec.global_transform * Transform3D(Basis(), Vector3(0, 0.1, -10.5))
	p.head.rotation = Vector3.ZERO
	var start: Vector3 = sec.watcher.global_position
	var passed_door := false
	for i in 900:
		await physics_frame
		passed_door = passed_door or sec.to_local(sec.watcher.global_position).z < -3.0
		if p.health <= 0.0:
			break
	check(start.distance_to(sec.watcher.global_position) > 3.0 and passed_door, "it walks out through the open office door")
	check(p.health <= 0.0 or sec.watcher.global_position.distance_to(p.global_position) < 2.0, "and through the vestibule to you (%.1f m)" % sec.watcher.global_position.distance_to(p.global_position))
	world.queue_free()
	await process_frame


## Secure Lab B's door: one controller in the lab's zone has status 'fault', on every seed.
## Zone alone or status alone gives more than one row, so both conditions matter.
func test_level_2_lab_data_every_seed() -> void:
	print("Secure Lab B data, 50 seeds")
	var ok := true
	var rekey_ok := true
	var zones := {}
	var lab := Level2Lab.new()
	for s in 50:
		var data := Level2Data.build(s)
		var d := FacilityDB.new()
		d.load_seed(data.sql)
		zones[data.lab_zone] = true
		var pz := Level2Lab.door_puzzle_for(data.lab_zone)
		var right: Array = d.run_silent(pz.solution_sql)
		var by_zone := d.run_silent("SELECT * FROM door_controllers WHERE zone = '%s'" % data.lab_zone)
		var by_status := d.run_silent("SELECT * FROM door_controllers WHERE status = 'fault'")
		ok = ok and right.size() == 1 and right[0]["id"] == data.lab_answer and by_zone.size() == 3 and by_status.size() >= 2
		ok = ok and data.lab_switches.size() == 3 and data.lab_switches.has(data.lab_answer)
		for wrong in [
			"SELECT * FROM door_controllers WHERE zone = '%s'" % data.lab_zone,
			"SELECT * FROM door_controllers WHERE status = 'fault'",
			"SELECT * FROM door_controllers WHERE zone = '%s' OR status = 'fault'" % data.lab_zone,
			"SELECT * FROM door_controllers WHERE zone = '%s' AND status = 'offline'" % data.lab_zone,
			"SELECT * FROM door_controllers WHERE zone = 'S' AND status = 'fault'",
		]:
			ok = ok and not pz.matches(d, d.execute(wrong))
		ok = ok and pz.matches(d, d.execute("SELECT * FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % data.lab_zone))
		var order: Puzzle = lab.log_puzzle
		ok = ok and order.matches(d, d.execute("SELECT * FROM badge_log ORDER BY time")) and not order.matches(d, d.execute("SELECT * FROM badge_log"))
		# Caught twice: each re-key moves the lab to another zone, still with one answer.
		var z: String = data.lab_zone
		for attempt in [1, 2]:
			var k := Level2Data.lab_rekey(s, attempt, z)
			d.run_silent(k.sql)
			var again := Level2Lab.door_puzzle_for(k.zone)
			var found: Array = d.run_silent(again.solution_sql)
			var doors: Array = d.run_silent("SELECT zone FROM doors WHERE id = 'SECLAB-B'")
			rekey_ok = rekey_ok and k.zone != z and found.size() == 1 and found[0]["id"] == k.answer and k.switches.has(k.answer)
			rekey_ok = rekey_ok and d.run_silent("SELECT * FROM door_controllers").size() == 6 and doors[0]["zone"] == k.zone
			rekey_ok = rekey_ok and not again.matches(d, d.execute("SELECT * FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % z))
			z = k.zone
	lab.free()
	check(rekey_ok, "caught by the security response, the lab is re-keyed to a new zone with exactly one answer, on every seed")
	check(ok, "the lab door is the one 'fault' in the lab's zone, and only zone AND status finds it, on every seed")
	check(zones.size() > 1, "the lab's zone changes between runs (%s)" % [zones.keys()])
	check(Level2Lab.door_puzzle_for("E").hints[0].contains("WHERE zone = 'E'") and Level2Lab.door_puzzle_for("E").hints[0].contains("AND status = 'fault'"), "the first hint is the exact query, a line per keyword")


## Wait up to `seconds` (game time) for `cond`.
func _until(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0 / Engine.time_scale)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			return false
		await physics_frame
	return true


func _in_lab_room(level: Node, p: Node3D) -> bool:
	return Level2Floor.LAB_BOX.has_point(level.to_local(p.global_position) + Vector3.UP * 0.5)


## The betrayal in Vale's lab, with each of the three ways it ends for Rourke.
func test_level_2_lab(outcome: String) -> void:
	print("Level 2 lab: Rourke %s" % outcome)
	_game().new_run(21)
	var level = load("res://scenes/level_2.tscn").instantiate()
	root.add_child(level)
	Engine.time_scale = 4.0
	await _frames(20)
	level.watcher.active = false
	var lab: Level2Lab = level.lab
	var p: Player = level.player
	var r: Rourke = lab.rourke
	check(r.visible and _game().notebook_todo.any(func(t): return t.text == "Follow Rourke to Dr. Vale's lab"), "Rourke walks the crew up to Vale's lab")
	check(level.booth.locked, "the night desk terminal stays locked while he's their escort")
	check(await _until(func(): return lab.phase == "badge", 40.0), "at the lab door he asks them to badge in")
	check(level.doors["SECLAB-B"].is_open == false and lab.reader.enabled, "the lab door waits for everyone's badge")
	lab.reader.interact(p)
	await _frames(3)
	var swipes: Array = level.db.run_silent("SELECT * FROM badge_log WHERE door = 'SECLAB-B' AND badge_id LIKE 'VIS-%'")
	check(swipes.size() == 1 and str(swipes[0]["time"]).begins_with("1997-10-16"), "the swipe is in badge_log: the crew's own badge, at her door, tonight")
	check(await _until(func(): return level.doors["SECLAB-B"].is_open, 10.0), "once everyone has badged, the door opens")
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(-12.5, 0.1, 1.5)))
	check(await _until(func(): return lab.phase == "locked", 40.0), "with everyone inside and Rourke out, the door locks")
	check(level.doors["SECLAB-B"].is_open == false and lab.terminal.locked, "locked in, and her terminal is locked too")
	check(await _until(func(): return lab.phase == "fight", 60.0), "he comes back in through the rear door")
	check(not level.doors["SECLAB-B-REAR"].is_open, "and the rear door shuts behind him")
	p.health = 100000.0  # this test is about what happens to him
	for i in 30:
		if r.state == Rourke.State.DOWN:
			break
		r.take_hit(p)
		await _frames(2)
	check(r.state == Rourke.State.DOWN, "struck enough times, he goes down")
	check(r.get_prompt(p) == "[X] Finish it", "with no cable, there's no way to tie him up")
	r.interact(p)
	check(r.state == Rourke.State.DOWN, "and pressing E does nothing")
	match outcome:
		"killed":
			r.interact_alt(p)
		"tied":
			lab.cable.interact(p)
			await _frames(3)
			check(lab.cable_holders.has(level.players.id_of(p)) and r.get_prompt(p).contains("Tie him up"), "holding the cable from the shelf, you can tie him up")
			r.interact(p)
		"untied":
			pass
	check(await _until(func(): return lab.fate == outcome, 30.0), "Rourke's fate: %s" % outcome)
	check(_game().rourke_fate == outcome, "the game remembers it, from Level 2")
	check(await _until(func(): return lab.switches.values().all(func(s): return s.enabled) and not lab.terminal.locked, 60.0), "the lockdown starts, and her terminal opens on Rourke's badge")
	check(_game().current_todo() != "" and not _game().current_todo().contains(level.data.lab_answer) and not _game().current_todo().contains(level.data.lab_zone + "'"), "the to-do names no answer (%s)" % _game().current_todo())
	var screen_text := "\n".join(lab.terminal.transcript)
	check(not screen_text.contains("ORDER BY") and screen_text.contains("badge_log"), "the lockdown screen names badge_log but doesn't give the query")
	check(screen_text.contains("[lb]SYSOP[rb]: two conditions?"), "the two-conditions tip is SYSOP's, not the system's")
	check(lab.response_left > Level2Lab.RESPONSE_TIME - 5.0 and lab.clock.text.begins_with("RESPONSE  "), "WARDEN sends a security response, and the clock over the door counts down")
	if outcome == "killed":
		# Too slow: the response arrives, and the lab's controllers are re-keyed.
		var old_zone: String = level.data.lab_zone
		lab.response_left = 0.2
		check(await _until(func(): return lab.phase == "caught", 5.0), "when the clock runs out, the crew is caught")
		check(await _until(func(): return lab.phase == "escape" and lab.response_left > 0.0, 20.0), "and the escape starts over, with the clock reset")
		var new_zone: String = level.data.lab_zone
		check(new_zone != old_zone and lab.zone == new_zone, "the lab's controllers are re-keyed to another zone (%s to %s)" % [old_zone, new_zone])
		check(lab._plate.text.contains("ZONE " + new_zone) and lab._card.plain_text().contains("zone " + new_zone), "the door plate and the card inside show the new zone")
		check(lab.switches.keys() == level.data.lab_switches and lab.switches.values().all(func(s): return s.enabled), "the switches carry the new zone's ids, ready to use")
		check(_in_lab_room(level, p), "the crew wakes up inside the lab")
		level.terminal_ui.terminal = lab.terminal
		level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % old_zone)
		check(not lab.door_puzzle.solved, "the old zone's answer no longer works")
	level.terminal_ui.terminal = lab.terminal
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = '%s'" % level.data.lab_zone)
	check(not lab.door_puzzle.solved, "the zone alone isn't enough")
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % level.data.lab_zone)
	check(lab.door_puzzle.solved, "zone AND status finds the lab door's controller")
	level.terminal_ui.run("SELECT * FROM badge_log ORDER BY time")
	check(lab.log_puzzle.solved, "ORDER BY time lays out the visitor log")
	var wrong: String = lab.switches.keys().filter(func(k): return k != level.data.lab_answer)[0]
	lab.switches[wrong].interact(p)
	await _frames(3)
	check(not level.doors["SECLAB-B"].is_open, "the wrong switch doesn't open the door")
	lab.switches_locked_until = 0.0
	lab.switches[level.data.lab_answer].interact(p)
	check(await _until(func(): return level.doors["SECLAB-B"].is_open, 5.0), "the right switch resets it, and the door opens")
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(-3, 0.1, 4.0)))
	check(await _until(func(): return lab.phase == "done" and not level.booth.locked, 20.0), "out of the lab, it's over, and the night desk terminal works")
	check(not level.watcher.active, "the Watcher stays still: it's quiet until Pike")
	if outcome == "untied":
		check(await _until(func(): return not r.visible, 30.0), "left untied, he's gone soon after")
	else:
		await _frames(30)
		check(r.visible == (outcome == "killed" or outcome == "tied"), "tied or dead, he's still lying there for now")
	Engine.time_scale = 1.0
	level.queue_free()
	await process_frame


## Co-op in Vale's lab: everyone has to badge in, and the cable is held by whoever took it.
func test_coop_level_2_lab() -> void:
	print("Co-op: Level 2 lab with a host and a client")
	_game().new_run(9)
	var worlds := await _coop_worlds(1)
	var machines := await _coop_load(worlds, "res://scenes/level_2.tscn")
	var host = machines[0]
	var client = machines[1]
	var client_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()
	Engine.time_scale = 4.0
	host.player.input_locked = true
	check(await _until(func(): return machines.all(func(l): return l.lab.phase == "badge"), 40.0), "Rourke leads both players to the lab door")
	client.lab.reader.interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return l.lab.badged.size() == 1 and not l.doors["SECLAB-B"].is_open), "one badge in, the door waits for the other player")
	host.lab.reader.interact(host.player)
	check(await _until(func(): return machines.all(func(l): return l.doors["SECLAB-B"].is_open), 10.0), "with both badged in, it opens on every machine")
	check(machines.all(func(l): return l.db.run_silent("SELECT * FROM badge_log WHERE badge_id LIKE 'VIS-%'").size() == 2), "both visitor badges are in badge_log on every machine")
	client.lab.cable.interact(client.player)
	await _frames(10)
	var holder: Node = host.players.puppet(client_id)
	check(machines.all(func(l): return l.lab.cable_holders.has(client_id)) and host.lab.rourke.can_tie.call(holder) and not host.lab.rourke.can_tie.call(host.player),
		"the client took the cable: only they can tie Rourke up")
	Engine.time_scale = 1.0
	await _coop_close(worlds)


func _doc(level: Node, title_part: String) -> Node:
	for d in level.find_children("*", "Document", true, false):
		if d.title.contains(title_part):
			return d
	return null


func _doc_has(level: Node, text: String) -> bool:
	return level.find_children("*", "Document", true, false).any(func(d): return d.plain_text().contains(text))


## Level 0's clues live on paper in the lobby, and copy into the notebook.
func _check_l0_documents(level: Node) -> void:
	check(_doc_has(level, "memo_fragments") and _doc_has(level, "piece_no"), "the scanner card names the scraps table and the column that numbers them")
	check(not level.desk_terminal.boot_lines.any(func(l): return l.contains("memo_fragments")), "the terminal no longer names the table: it's on the card")
	var todo: Array = _game().notebook_todo.map(func(t): return t.text)
	check(todo.has("Put the memo back in order") and todo.find("Put the memo back in order") > todo.find("Read Dr. Vale's shredded memo (front desk terminal)") \
		and _game().notebook_todo.filter(func(t): return t.text.contains("memo")).all(func(t): return t.done), "the to-do list adds sorting the memo after reading it, and ticks both off (%s)" % [todo])
	check(_game().ticket().tasks.any(func(t): return t.filled.contains("memo_fragments")), "the job ticket records which table the crew rebuilt the memo from")
	check(Array(level.desk_terminal.transcript).all(func(l): return not TerminalUI._plain(l).strip_edges().begins_with("WARDEN:")), "no tips from WARDEN on the front desk terminal")
	var tips: Array = Array(level.desk_terminal.transcript).filter(func(l): return TerminalUI._plain(l).begins_with("[SYSOP]: "))
	check(tips.size() >= 3, "SYSOP gives the tips (%d lines)" % tips.size())
	var brochure := _doc(level, "ScanRight")
	var reader: DocumentReader = brochure.open_reader(level.player)
	check(reader.visible and level.player.input_locked, "reading a document holds the player still")
	var i: int = brochure.lines().map(func(l): return l.get("filled", "")).find("memo_fragments")
	check(i >= 0, "the table name is handwritten in the brochure's blank")
	var before: int = _game().notebook_written.size()
	check(reader.write_note(i), "a document line can be copied")
	var w: Dictionary = _game().notebook_written.back()
	check(_game().notebook_written.size() == before + 1 and w.text.contains("table of your choice: memo_fragments") and w.label == brochure.title and w.kind == "document", "an unnamed copy is labeled with the document's title")
	check(reader.view.kind == "brochure" and reader.view.body.get_child_count() >= brochure.lines().size(), "the reader shows it on a brochure page, line by line")
	reader.view.copy_requested.emit(brochure.lines()[i].text)
	check(reader._note_label.visible and reader._note_index == i, "pressing + note on the page asks for a name")
	reader._finish_note("")
	check(_game().notebook_written.size() == before + 2, "Enter copies it, name optional")
	reader.write_note(i, "scraps table")
	check(_game().notebook_written.back().label == "scraps table", "a copy can be given its own name")
	check(not reader.write_note(brochure.lines().size()) and not reader.write_note(brochure.lines().map(func(l): return l.text).find("")), "blank or missing lines can't be copied")
	reader.close()
	check(not level.player.input_locked, "putting the document down gives the controls back")
	# SYSOP's lines keep their name when copied off the terminal.
	level.terminal_ui.run(".hint")
	var t: Array[String] = level.desk_terminal.transcript
	check(level.desk_terminal.transcript_kinds[t.size() - 1] == "hint" and TerminalUI._plain(t[t.size() - 1]).begins_with("[SYSOP]: "), "a .hint answer comes from SYSOP and copies with its name")


## Level 1: the table name and what each status means are on paper by the terminal.
func _check_l1_documents(level: Node) -> void:
	check(_doc_has(level, "door_controllers") and _doc_has(level, "zone A"), "the rack card names the controller table and the exit's zone")
	check(_doc_has(level, "'fault'") and _doc_has(level, "'offline'") and _doc_has(level, "- H.M."), "Mercer's note explains fault vs offline")
	check(not level._self_test_lines().any(func(l): return l.contains("door_controllers")), "the self-test no longer names the table: it's on the card")
	check(Array(level.terminal.transcript).all(func(l): return not TerminalUI._plain(l).strip_edges().begins_with("WARDEN:")), "no tips from WARDEN on the Server Room A terminal")
	check(Array(level.terminal.transcript).any(func(l): return TerminalUI._plain(l).begins_with("[SYSOP]: that's the one")), "SYSOP confirms the controller")
	check(_game().current_todo() != "" and not _game().current_todo().contains(level.answer), "the to-do names the task, never the answer (%s)" % _game().current_todo())
	for d in level.find_children("*", "Document", true, false):
		if d.title in ["SERVER ROOM A - DOOR CONTROLLERS", "Reminders"]:
			check(level.terminal.global_position.distance_to(d.global_position) < 1.5, "%s is on the terminal desk" % d.title)


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
	check(lobby.elevator != null and sra.arrival_lift != null, "the ground floor's elevator rides up to an arrival car on the server floor")
	var apart: float = sra.arrival_lift.global_position.distance_to(lobby.elevator.global_position)
	check(apart > 30.0, "the server floor sits apart from the ground floor, not behind a door (%.0f m)" % apart)
	check(not sra.rourke.visible, "Server Room A's own Rourke isn't seen standing in the room before he takes over")
	check(lobby.exit_door.is_hinged() and lobby.exit_door.locked, "the elevator bank's door is an ordinary hinged one, locked to all but Rourke's badge")
	var tables: Array = world.db.table_names()
	check(tables.has("memo_fragments") and tables.has("door_controllers"), "both wings share one database")
	# Rourke and the crew in the ground floor's car; the doors shut and it rides up.
	lobby._release_camera(world.player)
	lobby.elevator.open(true)
	lobby.elevator.closed.connect(lobby._on_elevator_closed, CONNECT_ONE_SHOT)
	world.player.global_position = lobby.elevator.to_global(Vector3(-0.5, 0.1, 1.0))
	lobby.rourke.global_position = lobby.elevator.to_global(lobby.ROURKE_IN_LIFT)
	var guide_local: Vector3 = lobby.elevator.to_local(lobby.rourke.global_position)
	for i in 5:
		await physics_frame
	check(lobby.elevator.press() and lobby.elevator.is_closing, "with everyone in the car, the button closes the doors")
	for i in 900:
		if world.current == sra:
			break
		await physics_frame
	check(world.current == sra and sra.active, "the ride up hands play to Server Room A")
	check(sra.arrival_lift.contains(world.player.global_position), "the crew steps out of the server floor's arrival car")
	check(sra.rourke.global_position.distance_to(sra.arrival_lift.to_global(guide_local)) < 0.2 and (not is_instance_valid(lobby.rourke) or lobby.rourke.is_queued_for_deletion()), "Server Room A's Rourke takes over where the ground floor's stood in the car")
	for i in 10:
		await physics_frame
	check(sra.rourke.visible and sra.arrival_lift.open_amount > 0.0, "he rides up with them, and the car opens on the server floor")
	sra._on_asked()
	check(not sra.terminal.locked and sra.asked, "the server floor's story runs inside the World")
	check(not world.wings.has("level_2"), "the security wing isn't loaded before it's needed")
	world.load_next(sra)
	var sec = world.wings.get("level_2")
	check(sec != null and not sec.active, "the security wing loads ahead, out of sight, while players are in Server Room A")
	var car_back: Vector3 = sec.to_local(sra.elevator.to_global(Vector3(0, 0, Elevator.SIZE.z)))
	check(car_back.z > 10.5 and sec.arrival_lift.contains(sec.spawn_point().origin), "the security wing doesn't overlap Server Room A's elevator, and players start in its arrival car (%s)" % car_back)
	check(world.db.run_silent("SELECT * FROM doors WHERE id LIKE 'SEC-%'").size() == 2 and world.db.table_names().has("guards"),
		"the security wing adds its own rows to the one building database")
	await process_frame
	check(sec._clock == 0.0, "the security wing's clock doesn't run before players get there")
	check(sec._camera_holds(sec.watcher), "cameras cover the Watcher's spot in the office, wherever the wing sits")
	# Out by the elevator: the doors closing are the checkpoint, the ride ends in the security wing.
	sra.elevator.closed.connect(sra._on_elevator_closed, CONNECT_ONE_SHOT)
	sra.elevator.open()
	await sra.elevator.opened
	world.player.global_position = sra.elevator.to_global(Vector3(0, 0.1, Elevator.SIZE.z / 2))
	for i in 5:
		await physics_frame
	sra.cable_holders[sra.players.id_of(world.player)] = true  # carrying the server floor's spare coil
	sra.rourke.global_position = sra.elevator.to_global(Vector3(0.6, 0.05, Elevator.SIZE.z / 2))  # he rides up with them
	var rourke_up: Vector3 = sra.elevator.to_local(sra.rourke.global_position)
	check(sra.elevator.press() and sra.elevator.is_closing, "with everyone inside, the button closes the doors")
	await sra.elevator.closed
	check(sra.elevator.open_amount == 0.0 and sra.elevator.riding, "the doors shut before it moves")
	await sra.elevator.arrived
	await process_frame
	check(sra.elevator.destination == sec.arrival_lift and sec.arrival_lift.contains(world.player.global_position), "the ride carries the crew into the security wing's arrival car")
	check(world.current == sec and sec.active, "the ride hands play to the security wing")
	await physics_frame
	check(_game().rourke_fate == "unknown" and sec.lab.phase == "lead" and sec.lab.rourke.visible, "Rourke is still their escort, so he walks them to Vale's lab")
	check(sec.lab.rourke.global_position.distance_to(sec.arrival_lift.to_global(rourke_up)) < 1.0 and not is_instance_valid(sra.rourke), "the Rourke who rode up from the server floor is the one who leads them on")
	check(sec.lab.cable_holders.has(sec.players.id_of(world.player)), "cable carried up from the server floor still ties him up")
	check(sec.watcher.global_position.distance_to(sec.to_global(sec.watcher_home)) < 0.1, "the Watcher stands in the office")
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
	check(world._field_notes != null and world.player.input_locked, "the route ends at Field Notes, in the notebook")
	check(world._field_notes.find_children("*", "NotebookView", true, false).size() == 1, "Field Notes is the notebook's page")
	world.queue_free()
	await process_frame


func test_rourke_leads_in() -> void:
	print("Rourke leads the crew up to Server Room A")
	_game().new_run(8)
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var lobby = world.current
	world.load_next(lobby)
	var sra = world.wings.get("level_1")
	var p: Player = world.player
	lobby._release_camera(p)
	p.global_position = Vector3(20.5, 0.2, 3)
	lobby.rourke.global_position = Vector3(22.4, 0.05, 3)
	lobby.rourke.watch = p
	for i in 30:
		await physics_frame
	var r: Rourke = lobby.rourke
	var to_p := p.global_position - r.global_position
	check(to_p.normalized().dot(-r.global_basis.z) > 0.8, "at the door, he turns to talk to the crew, not to the door")
	lobby.sync.event("_on_reach_server_room", [null])
	for i in 600:
		if lobby.exit_door.swing > 0.9 and r.global_position.distance_to(lobby.HOLD_DOOR_AT) < 0.5:
			break
		await physics_frame
	check(lobby.exit_door.is_open and lobby.exit_door.swing > 0.9, "he swings the elevator bank's door open and goes in first")
	check(r.global_position.distance_to(lobby.HOLD_DOOR_AT) < 0.5, "then holds it, beside the doorway, out of the crew's way (%s)" % r.global_position)
	p.global_position = Vector3(25.0, 0.2, 3)  # in the doorway, still in the door's swing
	for i in 60:
		await physics_frame
	check(lobby.exit_door.is_open, "the door stays open while anyone is still in its swing")
	p.global_position = Vector3(28.0, 0.2, 1.5)  # past him, clear of the swing
	for i in 400:
		if not lobby.exit_door.is_open:
			break
		await physics_frame
	check(not lobby.exit_door.is_open, "it swings shut once the whole crew is past him")
	for i in 900:
		if lobby.elevator.contains(r.global_position) and r.state == Rourke.State.IDLE:
			break
		await physics_frame
	check(lobby.elevator.open_amount > 0.9 and lobby.elevator.contains(r.global_position), "the elevator opens and Rourke steps in first")
	p.global_position = lobby.elevator.to_global(Vector3(-0.6, 0.2, 1.2))
	for i in 5:
		await physics_frame
	check(lobby.elevator.button.get_prompt(p).contains("Press 1"), "inside, the button says where it goes")
	lobby.elevator.button.interact(p)
	for i in 900:
		if world.current == sra:
			break
		await physics_frame
	check(world.current == sra and sra.arrival_lift.contains(p.global_position) and sra.arrival_lift.contains(sra.rourke.global_position), "the crew and Rourke ride up together")
	p.global_position = sra.to_global(Vector3(-1.0, 0.2, 12.0))  # out of the car and out of his way
	var desk: Vector3 = sra.to_global(Vector3(-2.4, 0, 6.4))
	for i in 1200:
		if Vector2(sra.rourke.global_position.x - desk.x, sra.rourke.global_position.z - desk.z).length() < 0.4:
			break
		await physics_frame
	var off := Vector2(sra.rourke.global_position.x - desk.x, sra.rourke.global_position.z - desk.z).length()
	check(off < 0.4, "and he walks them to the terminal desk (%.2f m off)" % off)
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
	check(nb.pages.current_page() == NotebookPages.Page.WORK_ORDER and NotebookPages.TAB_NAMES == ["Work order", "Tables", "Notes", "Field Notes"], "it opens on the work order, then Tables, Notes and Field Notes")
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
	var taught := lines.filter(func(l): return l.text.contains("SELECT * FROM table_name") and l.kind == "info")
	check(not taught.is_empty(), "the boot screen's SELECT example can be noted")
	var result_i := -1
	for i in lines.size():
		if lines[i].kind == "result" and lines[i].text.contains("piece_no"):
			result_i = i
	check(ui.write_note(result_i, "memo scraps") and _game().notebook_written[-1].label == "memo scraps" and _game().notebook_written[-1].kind == "result", "write note copies a query result under the player's own label")
	var taught_i: int = lines.find(taught[0])
	var probe: float = ui._para_top(lines[taught_i].from) + 2.0 - ui._output.get_v_scroll_bar().value
	check(ui._line_at(probe) == taught_i, "the pointer's height finds the line under it")
	ui._hover_line(taught_i)
	check(ui._hover_band.visible and ui._add_chip.visible and ui._add_chip.text.contains("add to notebook"), "pointing at a line lights it up and offers to add it to the notebook")
	check(not ui._output.get_parsed_text().contains("+ note"), "lines carry no + note buttons of their own")
	ui._add_chip.pressed.emit()
	check(ui._note_label.visible and ui._note_index == taught_i, "clicking add asks for a label")
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
	_game().set_todo("Find the exit")
	_game().set_todo("Open the exit door")
	check(not _game().set_todo("Open the exit door"), "the same task isn't written twice")
	nb.pages.show_page(NotebookPages.Page.WORK_ORDER)
	for i in 4:
		await process_frame
	var form: Control = nb.pages.book.left.find_child("WorkOrder", true, false)
	var page_h: float = nb.pages.book.left.size.y
	print("    work order: %.0f px tall on a %.0f px page" % [form.size.y if form else -1.0, page_h])
	check(form != null and form.get_parent() == nb.pages.book.left and form.size.y <= page_h + 0.5, "the printed work order fills the left page and fits on it")
	check(not NotebookPages.text_of(nb.pages.book.left.get_children()).contains("Crew notes") and NotebookPages.text_of(nb.pages.book.right.get_children()).contains("Crew notes"), "the crew's own notes start on the facing page")
	var squeezed := form.find_children("*", "Label", true, false).filter(func(l): return l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.size.x + 1.0 < l.get_minimum_size().x)
	check(squeezed.is_empty(), "no printed label is squeezed narrower than its text")
	var order_text := nb.pages.section_text(NotebookPages.Page.WORK_ORDER)
	check(order_text.contains("WORK ORDER") and order_text.contains("Halcyon Data Systems") and order_text.contains("Rourke") and order_text.contains(_game().ticket_number()), "the Work order page is the crew's printed Byte-Right work order")
	check(order_text.contains("SCOPE OF WORK") and order_text.contains("Diagnose the reported database problem") and order_text.contains("Client sign-off"), "it lists the job they were hired for and the sign-off lines")
	for word in ["Vale", "trap", "WARDEN", "escape", "lock"]:
		check(not order_text.contains(word), "nothing on the work order hints at foul play (%s)" % word)
	check(order_text.contains("[x]  Find the exit") and order_text.contains("[  ]  Open the exit door\n"), "the crew's tasks are written under it and ticked off as they're done")
	check(not nb.pages.section_text(NotebookPages.Page.NOTES).contains("Find the exit"), "the tasks aren't on the Notes page")
	check(_game().ticket_fill("Find the exit", "stairwell, east side") and nb.pages.section_text(NotebookPages.Page.WORK_ORDER).contains("[x]  Find the exit  - stairwell, east side"), "a done task can be filled in")
	check(_game().ticket().tasks.any(func(t): return t.filled == "stairwell, east side") and _game().ticket().customer == "Halcyon Data Systems", "later levels can read the ticket back")
	level.hud.todo("")
	check(_game().current_todo() == "" and _game().notebook_todo.all(func(t): return t.done), "an empty task ticks off the last one")
	check(_game().notebook_data().todo.map(func(t): return t.text).has("Open the exit door"), "the to-do list is saved with the notebook")
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
	var written_text := nb.pages.section_text(NotebookPages.Page.NOTES)
	check(written_text.contains("memo scraps") and written_text.contains("piece_no") and written_text.contains("Sticky notes"), "copied lines show on Notes with their labels, after the sticky notes")
	nb.close()
	var saved: Dictionary = _game().notebook_data()
	_game().new_run(4)
	check(_game().notebook_notes.is_empty(), "a new run starts with an empty notebook")
	_game().load_notebook(saved)
	check(_game().notebook_notes.size() == 2 and _game().notebook_tables.has("memo_fragments") and _game().notebook_written.size() == 3, "a saved notebook loads back")
	# Your own notes: "+ write a note" on the Notes page, typed at the foot of the screen.
	level.player.input_locked = false
	nb.open(NotebookPages.Page.NOTES)
	var write_btn: Button = nb.pages.book.find_child("WriteMine", true, false)
	check(write_btn != null and write_btn.text.contains("write a note"), "the Notes page has a button to write your own note")
	write_btn.pressed.emit()
	check(nb.is_writing() and nb.writer.has_focus() and level.player.input_locked, "it opens a line to type on, and you stand still while you write")
	nb.finish_writing("  PIN for HARDY: 2751 ")
	check(not nb.is_writing() and level.player.input_locked and nb.is_open(), "Enter writes it in and the notebook stays open")
	check(_game().notebook_written[-1].text == "PIN for HARDY: 2751" and _game().notebook_written[-1].kind == "mine", "the note is written as typed")
	var mine_text := nb.pages.section_text(NotebookPages.Page.NOTES)
	check(mine_text.contains("My notes") and mine_text.contains("PIN for HARDY: 2751") and mine_text.find("My notes") < mine_text.find("Sticky notes"), "your own notes come first on the Notes page")
	check(mine_text.count("PIN for HARDY") == 1, "and aren't listed again under copied lines")
	var count_before: int = _game().notebook_written.size()
	nb.start_writing()
	nb.finish_writing("   ")
	check(_game().notebook_written.size() == count_before and not nb.is_writing(), "a blank note writes nothing")
	nb.start_writing()
	nb.close()
	check(not nb.is_writing() and not level.player.input_locked, "closing the notebook puts the pen down and frees you")
	level.queue_free()
	await process_frame


func test_in_world_ui() -> void:
	print("Notebook in hand, terminals on their own screens")
	_game().new_run(5)
	_game().diegetic_ui = true
	var level = load("res://scenes/level_0.tscn").instantiate()
	root.add_child(level)
	for i in 10:
		await physics_frame
	var nb: Notebook = level.notebook
	var p: Player = level.player
	level._release_camera(p)  # out of the van intro
	check(nb.held != null and p.held_notebook == nb.held and nb.pages.get_parent() == nb.held.viewport, "the notebook is held in your hands, its pages drawn on it")
	check(nb.open() and p.is_holding_notebook() and not p.input_locked, "Tab raises it without freezing you in place")
	check(nb.pages.current_page() == NotebookPages.Page.WORK_ORDER, "it opens on the work order")
	nb.close()
	check(not nb.is_open() and not p.is_holding_notebook(), "and Tab puts it away")
	var t: Terminal = level.desk_terminal
	check(t.screen != null and t.screen.keyboard != null and t.screen.hosted == null, "every terminal is a CRT with its own screen and keyboard")
	var sticky: StickyNote = t.find_children("*", "StickyNote", true, false)[0]
	check(t.to_local(sticky.global_position).z > t.to_local(t.screen.glass.global_position).z, "the monitor's sticky note sits in front of the glass")
	check(t.to_local(sticky.global_position).x - 0.038 > TerminalScreen.SCREEN_SIZE.x / 2.0, "and off to the right of the glass, so it never covers the screen's text")
	var sp := t.stand_point.global_position
	p.global_position = Vector3(sp.x, 0.4, sp.z + 0.3)
	for i in 60:
		await physics_frame
	var ui: TerminalUI = level.terminal_ui
	var home: Node = ui.get_parent()
	nb.open()
	t.enabled = true
	t.interact(p)
	check(p.is_using_terminal() and not p.is_holding_notebook() and not ui.visible, "E steps you up to the desk and puts the notebook away first")
	for i in 400:
		if ui.visible:
			break
		await physics_frame
	check(ui.visible and ui.is_on_screen() and t.screen.hosted == ui and not ui._dim.visible, "once the camera settles, the terminal opens on its own glass")
	check(not nb.open(), "the notebook can't come out at a terminal")
	ui.run("SELECT * FROM memo_fragments")
	check(t.transcript.any(func(l): return l.contains("piece_no")), "queries typed on the glass run as usual")
	ui.close()
	await process_frame
	await process_frame
	check(ui.get_parent() == home and not ui.is_on_screen() and t.screen.hosted == null and ui._dim.visible, "stepping away puts the window back and the glass shows the screen again")
	for i in 200:
		if not p.is_using_terminal():
			break
		await physics_frame
	check(not p.is_using_terminal(), "and you step back from the desk")
	_game().diegetic_ui = false
	nb.rebuild()
	check(nb.held == null and p.held_notebook == null and nb.pages.get_parent() == nb, "the setting switches back to the full-screen notebook")
	t.interact(p)
	check(ui.visible and not ui.is_on_screen(), "and the full-screen terminal")
	ui.close()
	level.queue_free()
	await process_frame


## Papers come up off the desk or wall into your hands, and sticky notes go onto
## the notebook's page (Game.diegetic_ui).
func test_pick_up_papers() -> void:
	print("Picking up papers and filing sticky notes")
	_game().new_run(5)
	_game().diegetic_ui = true
	var level = load("res://scenes/level_0.tscn").instantiate()
	root.add_child(level)
	for i in 10:
		await physics_frame
	var p: Player = level.player
	level._release_camera(p)
	p.seated = false
	p.global_position = Vector3(1.0, 0.1, -1.9)  # behind the front desk
	p.rotation.y = 0.0
	for i in 20:
		await physics_frame
	var hands: HeldPaper = p.camera.get_node_or_null("HeldPaper")
	check(hands != null, "the notebook's hands also hold papers")
	var card: Document = level.find_children("*", "Document", true, false).filter(func(d): return d.title.begins_with("ScanRight"))[0]
	var home := card.global_transform
	card._on_used(p)
	var reader: DocumentReader = level.find_children("*", "DocumentReader", true, false)[0]
	check(reader.held and p.held_prop == card and not p.input_locked and not reader.view.visible, "E lifts the card off the desk into your hands, with no full-screen page and no freezing in place")
	for i in 120:
		if p.is_holding_prop() and p._prop_t >= 1.0:
			break
		await physics_frame
	var face: Vector3 = card.global_basis * card.read_face
	check(face.dot(p.camera.global_position - card.global_position) > 0.0, "its printed side faces you")
	check(hands.prop == card and hands.page != null and reader.page_viewport != null, "the hands hold it, with its real page on it")
	var centre := p.get_viewport().get_visible_rect().size / 2.0
	check(reader.page_point(centre).x >= 0.0 and reader.page_point(Vector2(2, 2)).x < 0.0, "the pointer in the middle of the view is on the page, and the corner isn't")
	var line: String = card.lines()[4].text
	(reader.page_viewport.get_child(0) as DocumentView).copy_requested.emit(line)
	check(reader._note_label.visible and p.input_locked, "a line's \"+ note\" on the page asks for a name, standing still to type it")
	reader._finish_note("scanner")
	check(_game().notebook_written.any(func(n): return n.text == line.strip_edges() and n.label == "scanner") and not p.input_locked, "and goes in the notebook")
	reader.close()
	for i in 120:
		if not is_instance_valid(reader):
			break
		await physics_frame
	check(not is_instance_valid(reader) and p.held_prop == null and card.global_transform.origin.distance_to(home.origin) < 0.01, "E puts it back where it was")
	# A sheet on a wall comes off the wall the same way, its printed side to you.
	var sheet := Document.place(level.geo, Vector3(1.0, 1.5, -3.2), 180.0, "Wall test", ["one", "two"])
	p.look_at(Vector3(1.0, p.global_position.y, -3.2))
	await physics_frame
	sheet._on_used(p)
	for i in 120:
		if p.is_holding_prop() and p._prop_t >= 1.0:
			break
		await physics_frame
	face = sheet.global_basis * sheet.read_face
	check(p.held_prop == sheet and face.dot(p.camera.global_position - sheet.global_position) > 0.0, "a wall sheet comes up printed side to you")
	p.put_down(true)
	await physics_frame
	# A loose sticky note goes onto the notebook's page, then in the notebook.
	var sticky: StickyNote = level.find_children("*", "StickyNote", true, false).filter(func(n): return not n.on_terminal)[0]
	var id := sticky.note_id
	sticky._on_used(p)
	check(p.is_filing() and level.notebook.is_open(), "taking a sticky note opens the notebook and puts the note on its page")
	for i in 240:
		if _game().notebook_notes.has(id):
			break
		await physics_frame
	check(_game().notebook_notes.has(id) and not is_instance_valid(sticky), "once it lands it's in the notebook, and gone from the desk")
	_game().diegetic_ui = false
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
