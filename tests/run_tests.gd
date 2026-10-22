extends SceneTree
## Headless test runner. Usage:
##   godot --headless -s tests/run_tests.gd                     every group
##   godot --headless -s tests/run_tests.gd -- --group=floor_22  one group (or a,b,c)
## Exits with code 1 if any test fails. CI runs each group as its own job, side by side,
## so add a new test to the group it belongs to and keep each group under ~3 minutes.

var passed := 0
var failed := 0
## Counts SCRIPT ERRORs (parse errors, bad calls): Godot prints them and carries on, so a
## test script that fails to parse, or a test that dies halfway, would otherwise go green.
var _errors := ScriptErrors.new()
## Inside the floor 22 stairwell, past the lift lobby's stair door (Level 2 local).
const STAIRS := Vector3(4.5, 0.1, -15.0)  # on the landing, clear of the flight


func _initialize() -> void:
	OS.add_logger(_errors)
	_run.call_deferred()


class ScriptErrors extends Logger:
	var count := 0
	var _lock := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			_lock.lock()
			count += 1
			_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


## Each group is a _group_<name>() function below. CI runs one job per entry here.
const GROUPS := ["core", "floor_g", "floor_14", "floor_22", "floor_22_lab", "floor_18", "floor_10", "coop", "combat", "movement", "movement_hands", "teaching", "teaching_lab", "scripting", "chapters"]


func _run() -> void:
	# The full-screen notebook and terminal; test_in_world_ui covers the held and on-screen ones.
	_game().diegetic_ui = false
	# Huddles, pickups and finished floors earn unlocks: keep them off this computer's real save.
	root.get_node("Net").profile = Profile.new()
	var only := _groups_from_args()
	for g in only:
		if g not in GROUPS:
			check(false, "unknown test group '%s' (groups: %s)" % [g, ", ".join(GROUPS)])
	for g in GROUPS:
		if only.is_empty() or g in only:
			print("\n=== group: %s ===" % g)
			await _run_group(g)
	if passed + failed == 0:
		check(false, "no tests ran")
	check(_errors.count == 0, "no SCRIPT ERRORs while testing (found %d; search the log for SCRIPT ERROR)" % _errors.count)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _groups_from_args() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--group="):
			return Array(arg.trim_prefix("--group=").split(",", false))
	return []


func _run_group(g: String) -> void:
	match g:
		"core": await _group_core()
		"floor_g": await _group_floor_g()
		"floor_14": await _group_floor_14()
		"floor_22": await _group_floor_22()
		"floor_22_lab": await _group_floor_22_lab()
		"floor_18": await _group_floor_18()
		"floor_10": await _group_floor_10()
		"coop": await _group_coop()
		"combat": await _group_combat()
		"movement": await _group_movement()
		"movement_hands": await _group_movement_hands()
		"teaching": await _group_teaching()
		"teaching_lab": await _group_teaching_lab()
		"scripting": await _group_scripting()
		"chapters": await _group_chapters()


## Shared systems: database, voice, notebook, world streaming, UI, combat, art, garage huddles.
func _group_core() -> void:
	test_facility_db()
	test_facility_db_read_only()
	test_facility_api()
	test_voice_codec()
	test_radio_rules()
	test_voice_script()
	await test_voice_playback()
	await test_commentary()
	await test_pause_holds_subtitles()
	await test_screens_fill_window()
	test_wing_seeds_in_order()
	test_reset_keeps_earlier_wings()
	await test_world()
	test_sticky_notes_never_give_answers()
	test_visitor_badge()
	await test_elevator()
	await test_notebook()
	await test_case_pages()
	test_sysop_colors()
	test_dialogue_jots()
	await test_stairwells()
	await test_in_world_ui()
	await test_pick_up_papers()
	await _run_file("res://tests/art_tests.gd")
	await _run_file("res://tests/huddle_tests.gd")


## Ground floor (Level 0) and Rourke's tour.
func _group_floor_g() -> void:
	test_level_0_puzzles()
	await test_mercer_tape_secret()
	test_first_hints_show_working_queries()
	await test_level_0_scene()
	await test_ground_floor()
	await test_rourke_leads_in()
	await test_caller_answer()


## Floor 14, the server floor (Level 1).
func _group_floor_14() -> void:
	test_level_1_data_every_seed()
	await test_level_1_scene()
	await test_level_1_book_huddle()


## Easy SQL's chapters at their moments on the ground floor and floor 14.
func _group_chapters() -> void:
	await test_level_0_book_huddles()
	await test_level_1_book_huddles()


## Floor 22, the security floor (Level 2), outside the lab.
func _group_floor_22() -> void:
	test_level_2_data_every_seed()
	test_level_2_hints()
	test_level_2_badge_route()
	await test_level_2_scene()
	await test_level_2_routes()
	await test_level_2_wall_controls()
	await test_level_2_main_route()
	await test_level_2_cases()
	await test_level_2_book_huddles()


## Floor 22's Secure Lab B, once per way the Rourke fight can end.
func _group_floor_22_lab() -> void:
	test_level_2_lab_data_every_seed()
	for outcome in ["killed", "tied", "untied"]:
		await test_level_2_lab(outcome)


## Floor 18, the Records Archive (Level 3): its data, the floor, Mercer's room, the
## stairs down from 22, and co-op.
func _group_floor_18() -> void:
	test_level_3_data_every_seed()
	await test_level_3_scene()
	await test_level_3_safe_room()
	await test_level_3_shredder()
	await test_level_3_book_huddles()
	await test_level_3_stairs_from_22()
	await test_coop_level_3()


## Floor 10, the Power Plant (Level 4).
func _group_floor_10() -> void:
	await _run_file("res://tests/level_4_tests.gd")


## Co-op: several machines in one process.
func _group_coop() -> void:
	await test_coop_level_0()
	await test_coop_level_1()
	await test_coop_six_players()
	await test_coop_terminal_screens()
	await test_coop_notes_huddle()
	await test_coop_looks()
	await test_coop_sitting()
	await test_coop_unlocks()
	await test_coop_achievements()
	await test_coop_scripts()
	await test_coop_pregame_lobby()
	await test_coop_tape_secret()
	await test_coop_world()
	await test_coop_lobby_walk_in()
	await test_coop_lobby_names()
	await test_coop_patience()
	await test_coop_level_2()
	await test_coop_level_2_lab()


## Fights: health, blocking, the entities' grabs and throws, solo and co-op.
func _group_combat() -> void:
	await _run_file("res://tests/combat_tests.gd")
	await _run_file("res://tests/custodian_tests.gd")
	await test_coop_combat()
	await test_coop_custodian()


## Parkour: walking, sliding, mantling, vaulting, hanging, climbing, vents, ledges, shoulders.
func _group_movement() -> void:
	await _run_file("res://tests/movement_tests.gd", "moves")


## The rest of the player: notebook, terminals, pickups, inventory, sitting, stamina, knocks, gym.
func _group_movement_hands() -> void:
	await _run_file("res://tests/movement_tests.gd", "hands")


## Teaching walkthroughs and audits across every floor.
func _group_teaching() -> void:
	await _run_file("res://tests/teaching_tests.gd")
	await _run_file("res://tests/teaching_voice_tests.gd")


## The second lab seed's paced walk, on its own so neither teaching group runs long.
func _group_teaching_lab() -> void:
	await _run_file("res://tests/teaching_tests.gd", "lab")


## Scripting and services: the facility API's writes, and deck scripts.
func _group_scripting() -> void:
	await _run_file("res://tests/scripting_tests.gd")
	await _run_file("res://tests/script_runtime_tests.gd")
	await _run_file("res://tests/script_editor_tests.gd")


## Runs a test file's run(tree, check, ...). One that fails to parse is a failed test, not a skip.
func _run_file(path: String, part := "") -> void:
	var script: GDScript = load(path)
	if script == null or not script.can_instantiate():
		check(false, "%s loads (it has a parse error: see SCRIPT ERROR above)" % path)
		return
	var tests = script.new()
	if part.is_empty():
		await tests.run(self, check)
	else:
		await tests.run(self, check, part)


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


## Protocol Epsilon's read-only building: direct writes refused, reads and game logic
## untouched, and it outlasts a checkpoint reload.
func test_facility_db_read_only() -> void:
	print("FacilityDB: read-only")
	var db := FacilityDB.new()
	db.load_seed("INSERT INTO doors (id, locked, actuator_fault) VALUES ('A', 1, 0), ('B', 1, 0);")
	var refused := []
	db.write_refused.connect(func(sql): refused.append(sql))
	db.read_only = true
	var r := db.execute("UPDATE doors SET locked = 0 WHERE id = 'A'")
	check(not r.ok and r.error == db.read_only_error and r.changes == 0 and refused.size() == 1, "an UPDATE is refused with the read-only error, and write_refused fires")
	check(db.run_silent("SELECT locked FROM doors WHERE id = 'A'")[0]["locked"] == 1, "and nothing changed")
	for sql in ["insert into doors (id) values ('C')", "DELETE FROM doors", "  DROP TABLE doors", "CREATE TABLE x (a)", "\nUPDATE doors SET locked = 0"]:
		check(not db.execute(sql).ok, "refused: %s" % sql.strip_edges())
	r = db.execute("WITH t AS (SELECT 1) UPDATE doors SET locked = 0")
	check(not r.ok and db.run_silent("SELECT COUNT(*) AS n FROM doors WHERE locked = 1")[0]["n"] == 2, "a write behind a WITH is rolled back and refused")
	r = db.execute("WITH t AS (SELECT id FROM doors) SELECT id FROM t")
	check(r.ok and r.rows.size() == 2, "a read behind a WITH still works")
	r = db.execute("SELECT id, locked FROM doors ORDER BY id")
	check(r.ok and r.rows.size() == 2 and r.columns == ["id", "locked"], "reads still work")
	db.run_silent("UPDATE doors SET locked = 0 WHERE id = 'B'")
	check(db.run_silent("SELECT locked FROM doors WHERE id = 'B'")[0]["locked"] == 0, "game logic (run_silent) still writes")
	db.reset()
	check(db.read_only and not db.execute("UPDATE doors SET locked = 0").ok, "a checkpoint reload keeps it read-only")
	db.read_only = false
	check(db.execute("UPDATE doors SET locked = 0 WHERE id = 'A'").changes == 1, "off again, writes work")


func test_level_0_puzzles() -> void:
	print("Level 0 puzzles")
	var db := FacilityDB.new()
	db.load_seed(Level0Data.build(1).sql)
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
	# Who called: the work order's extension, looked up in the staff directory.
	var l0 = load("res://scripts/levels/level_0.gd")
	var exts := {}
	var caller_ok := true
	var visitor_ok := true
	for seed_value in 30:
		var data := Level0Data.build(seed_value)
		var d := FacilityDB.new()
		d.load_seed(data.sql)
		exts[data.extension] = true
		var caller: Puzzle = l0.caller_puzzle_for(data.extension)
		var rows := d.run_silent("SELECT name, dept, status FROM staff_directory WHERE extension = %d" % data.extension)
		caller_ok = caller_ok and rows.size() == 1 and rows[0]["name"] == "Harold Mercer" and str(rows[0]["status"]).begins_with("LEFT")
		caller_ok = caller_ok and d.run_silent("SELECT name FROM staff_directory WHERE dept = 'Building Services'").size() > 1
		caller_ok = caller_ok and caller.matches(d, d.execute("SELECT name, extension, dept FROM staff_directory;"))
		caller_ok = caller_ok and caller.matches(d, d.execute("SELECT * FROM staff_directory"))
		caller_ok = caller_ok and not caller.matches(d, d.execute("SELECT name, dept FROM staff_directory"))
		caller_ok = caller_ok and not caller.matches(d, d.execute("SELECT name, extension FROM staff_directory WHERE dept = 'Research'"))
		var visitor: Puzzle = l0.visitor_puzzle_for()
		var newest := d.run_silent("SELECT name, signed_out FROM visitors ORDER BY signed_in DESC")
		visitor_ok = visitor_ok and newest[1]["name"] == "VALE, I." and newest[1]["signed_out"] == null and str(data.vale_in).begins_with("1997-10-15 21:")
		visitor_ok = visitor_ok and visitor.matches(d, d.execute("SELECT * FROM visitors ORDER BY signed_in DESC"))
		visitor_ok = visitor_ok and not visitor.matches(d, d.execute("SELECT * FROM visitors ORDER BY signed_in"))
		visitor_ok = visitor_ok and not visitor.matches(d, d.execute("SELECT * FROM visitors"))
		for n in [2, 3, 5, 10, 100]:
			visitor_ok = visitor_ok and visitor.matches(d, d.execute("SELECT * FROM visitors ORDER BY signed_in DESC LIMIT %d" % n))
		var top_one := d.execute("SELECT name, signed_in FROM visitors ORDER BY signed_in DESC LIMIT 1")
		visitor_ok = visitor_ok and not visitor.matches(d, top_one) and l0.visitor_top_one_for().matches(d, top_one)
		visitor_ok = visitor_ok and not l0.visitor_top_one_for().matches(d, d.execute("SELECT * FROM visitors ORDER BY signed_in DESC LIMIT 2"))
		visitor_ok = visitor_ok and not visitor.matches(d, d.execute("SELECT * FROM visitors ORDER BY signed_in ASC LIMIT 5"))
		visitor_ok = visitor_ok and not visitor.matches(d, d.execute("SELECT * FROM visitors ORDER BY signed_in ASC LIMIT 2"))
		# Stored oldest first, so these hold Vale's row too, but not at the top of the newest-first list.
		visitor_ok = visitor_ok and not visitor.matches(d, d.execute("SELECT * FROM visitors LIMIT 5;"))
		visitor_ok = visitor_ok and not visitor.matches(d, d.execute("SELECT * FROM visitors ORDER BY signed_in LIMIT 5;"))
		visitor_ok = visitor_ok and d.run_silent("SELECT name FROM visitors LIMIT 5").any(func(r): return r["name"] == "VALE, I.")
	check(caller_ok, "the caller's extension is Harold Mercer's, gone since '94; listing names beside extensions finds it, the department alone doesn't")
	check(visitor_ok, "the visitor log newest first shows the crew, then Vale, never signed out; only DESC finds it, the whole list or any LIMIT of 2 or more; LIMIT 1 is the near miss")
	check(exts.size() >= 10, "the caller's extension varies between runs (%d different)" % exts.size())


func test_level_1_data_every_seed() -> void:
	print("Level 1 data, 50 seeds")
	var all_ok := true
	var doors_ok := true
	var racks_ok := true
	var zones := {}
	var never_guessable := true
	var all_explained := true
	var answers := {}
	var count_ok := true
	var counts := {}
	var l1 = load("res://scripts/levels/level_1.gd")
	var l1i = l1.new()
	for s in 50:
		var data := Level1Data.build(s)
		var db := FacilityDB.new()
		db.load_seed(data.sql)
		var z: String = data.zone
		zones[z] = true
		var puzzle: Puzzle = load("res://scripts/levels/level_1.gd").controller_puzzle_for(z)
		var rows := db.run_silent(puzzle.solution_sql)
		var n := int(str(data.answer).trim_prefix("DC-"))
		if rows.size() != 1 or rows[0]["id"] != data.answer or n < 1 or n > 8:
			all_ok = false
		if not puzzle.matches(db, db.execute("SELECT * FROM door_controllers WHERE status = 'fault' AND zone = '%s';" % z)):
			all_ok = false
		if puzzle.matches(db, db.execute("SELECT * FROM door_controllers WHERE zone = '%s'" % z)) or puzzle.matches(db, db.execute("SELECT * FROM door_controllers WHERE status = 'fault'")):
			never_guessable = false
		# The stuck doors the NOC log names all share the zone; no other zone's fault is on this floor.
		var stuck := db.run_silent("SELECT id, zone FROM doors WHERE locked = 1 AND id IN ('SRA-EXIT', 'SRC', 'LIFT-1')")
		doors_ok = doors_ok and stuck.size() == 3 and stuck.all(func(r): return r["zone"] == z)
		doors_ok = doors_ok and db.run_silent("SELECT id FROM doors WHERE locked = 0 AND zone = '%s'" % z).size() == 1  # the entrance
		# One rack is over the interlock limit; another sits right on it, so >= finds two.
		var hot := db.run_silent("SELECT id FROM racks WHERE temp_c > %d" % Level1Data.INTERLOCK_C)
		racks_ok = racks_ok and hot.size() == 1 and hot[0]["id"] == data.hot_rack
		racks_ok = racks_ok and db.run_silent("SELECT id FROM racks WHERE temp_c >= %d" % Level1Data.INTERLOCK_C).size() == 2
		racks_ok = racks_ok and db.run_silent("SELECT status FROM lights WHERE room = 'Break room' AND floor = 1")[0]["status"] == "dead"
		if not db.run_silent("SELECT id FROM door_controllers WHERE status != 'ok' AND id != '%s' AND note = 'normal'" % data.answer).is_empty():
			all_explained = false
		answers[data.answer] = true
		# The reset sign-off's count: 3, 5 or 6 faults, never a tempting wrong count.
		var faults: int = data.faulted
		counts[faults] = true
		var count: Puzzle = l1.count_puzzle_for()
		count_ok = count_ok and faults >= 2 and db.run_silent("SELECT COUNT(*) AS n FROM door_controllers WHERE status = 'fault'")[0]["n"] == faults
		for right in ["SELECT COUNT(*) FROM door_controllers WHERE status = 'fault';", "SELECT COUNT(id) FROM door_controllers WHERE status = 'fault'",
				"SELECT COUNT(*) AS n FROM door_controllers WHERE status = 'fault'"]:
			count_ok = count_ok and count.matches(db, db.execute(right))
		for wrong in ["SELECT COUNT(*) FROM door_controllers", "SELECT COUNT(*) FROM door_controllers WHERE status != 'ok'",
				"SELECT COUNT(*) FROM door_controllers WHERE status = 'offline'", "SELECT COUNT(*) FROM door_controllers WHERE status = 'ok'",
				"SELECT COUNT(*) FROM door_controllers WHERE zone = '%s'" % z, "SELECT COUNT(*) FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % z,
				"SELECT COUNT(*) FROM door_controllers WHERE location LIKE 'Server Room A%'", "SELECT COUNT(*) FROM door_controllers WHERE location = 'Records Archive'",
				"SELECT * FROM door_controllers WHERE status = 'fault'"]:
			count_ok = count_ok and not count.matches(db, db.execute(wrong))
		count_ok = count_ok and l1i.count_all.matches(db, db.execute("SELECT COUNT(*) FROM door_controllers"))
		count_ok = count_ok and l1i.count_not_ok.matches(db, db.execute("SELECT COUNT(*) FROM door_controllers WHERE status != 'ok'"))
	l1i.free()
	check(count_ok, "the sign-off count is the 'fault' rows, as COUNT(*), COUNT(id) or AS n; no WHERE, != 'ok', a zone or a room never gives it")
	check(counts.size() == 3, "how many controllers are faulted varies between runs (%s)" % ", ".join(counts.keys().map(func(k): return str(k))))
	check(all_explained, "every other faulted or offline controller has a note saying why")
	check(all_ok, "exactly one zone-A fault on a physical rack, and AND finds it")
	check(never_guessable, "a single condition is never enough")
	check(answers.size() >= 5, "the answer varies between runs (%d different racks)" % answers.size())
	check(doors_ok, "the doors the NOC log names are all locked, and all in the faulted zone")
	check(zones.size() >= 4, "the zone varies between runs (%d different)" % zones.size())
	check(racks_ok, "exactly one Server Room B rack is over 40°C, one sits on it, and the break room's light is dead")


func _hint_query(hint: String) -> String:
	var start := hint.find("[color=#ffffff]") + "[color=#ffffff]".length()
	return hint.substr(start, hint.find("[/color]", start) - start)


## The exact query a last hint gives, on its own line.
func _exact_query(hint: String) -> String:
	for line in hint.replace("[color=#ffffff]", "").replace("[/color]", "").split("\n"):
		var l := line.strip_edges()
		if l.to_upper().begins_with("SELECT ") and l.ends_with(";") and not l.contains("?"):
			return l
	return ""


## The hint ladder (Augustine, 2026-10-18): hint 1 is the query's shape with ? for
## the value and doesn't give `secret` away; the last hint's exact query solves it.
func _check_hint_ladder(p: Puzzle, db: FacilityDB, secret: String) -> bool:
	if p.hints.size() < 3 or not p.hints[0].contains("?"):
		return false
	# Whole words only: "phone extensions" says what to look for, not the column's name.
	if secret != "" and RegEx.create_from_string("(?<![\\w'])%s(?![\\w'])" % secret).search(p.hints[0]):
		return false
	var q := _exact_query(p.hints[-1])
	return q != "" and p.matches(db, db.execute(q))


func test_first_hints_show_working_queries() -> void:
	print("Hint ladder")
	var l0 = load("res://scripts/levels/level_0.gd")
	var l0i = l0.new()
	var l1 = load("res://scripts/levels/level_1.gd")
	var ok := {"peek": true, "memo": true, "caller": true, "last_visitor": true, "controller": true, "hot_rack": true, "stuck_doors": true, "dark_room": true, "faulted_count": true}
	for seed_value in 20:
		var d0 := FacilityDB.new()
		var data0 := Level0Data.build(seed_value)
		d0.load_seed(data0.sql)
		ok.peek = ok.peek and _check_hint_ladder(l0i.peek_puzzle, d0, "memo_fragments")
		ok.memo = ok.memo and _check_hint_ladder(l0i.memo_puzzle, d0, "piece_no")
		ok.caller = ok.caller and _check_hint_ladder(l0.caller_puzzle_for(data0.extension), d0, "extension")
		ok.last_visitor = ok.last_visitor and _check_hint_ladder(l0.visitor_puzzle_for(), d0, "signed_in")
		var d1 := FacilityDB.new()
		var data1 := Level1Data.build(seed_value)
		d1.load_seed(data1.sql)
		ok.controller = ok.controller and _check_hint_ladder(l1.controller_puzzle_for(data1.zone), d1, "'%s'" % data1.zone)
		ok.hot_rack = ok.hot_rack and _check_hint_ladder(l1.hot_rack_puzzle_for(), d1, str(Level1Data.INTERLOCK_C))
		ok.stuck_doors = ok.stuck_doors and _check_hint_ladder(l1.stuck_doors_puzzle_for(), d1, "1")
		ok.faulted_count = ok.faulted_count and _check_hint_ladder(l1.count_puzzle_for(), d1, "door_controllers")
		ok.dark_room = ok.dark_room and _check_hint_ladder(l1.dark_room_puzzle_for(), d1, "'dead'") and not l1.dark_room_puzzle_for().hints[0].contains("flickering")
	for id in ok:
		check(ok[id], "%s: hint 1 is the query's shape with ?, and the last hint's query solves it, on every seed" % id)
	check(not l0i.memo_puzzle.hints[1].contains("visitors"), "memo: hints never use an example table")
	l0i.free()


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
	var sources := []
	for dir in ["res://scripts/levels/", "res://scripts/huddle/"]:  # huddle: the book's chapter lines
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				sources.append(dir + f)
	for path in sources:
		var f: String = path.get_file()
		var src := FileAccess.get_file_as_string(path)
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
		# The shared crew lines are in every playable crew member's script.
		if hits != (VoiceLines.CREW.size() if VoiceLines.LINES[id]["speaker"] == "CREW" else 1):
			placed_once.append(id)
	check(placed_once.is_empty(), "every line is in exactly one character's script %s" % [placed_once])
	var bodies := {}
	var missing_barks := []
	var named := []
	for slug in VoiceLines.CREW:
		var m: Dictionary = VoiceLines.CREW[slug]
		bodies[m["body"]] = bodies.get(m["body"], 0) + 1
		if m["barks"].keys() != VoiceLines.BARKS.keys():
			missing_barks.append(slug)
		if not docs.has(ScriptDocs.CHARACTERS_DIR.path_join(VoiceLines.crew_dir(slug) + ".md")):
			missing_barks.append(slug + " (no script)")
	var crew_text: Array = VoiceLines.LINES.values().filter(func(l): return l["speaker"] == "CREW").map(func(l): return l["text"])
	for slug in VoiceLines.CREW:
		crew_text.append_array(VoiceLines.CREW[slug]["barks"].values())
	for slug in VoiceLines.CREW:
		var first: String = VoiceLines.CREW[slug]["name"].get_slice(" ", 0)
		for t in crew_text:
			if RegEx.create_from_string("\\b%s\\b" % first).search(t):
				named.append(first)
	check(bodies == {"woman": 6, "man": 6}, "six women and six men to play %s" % [bodies])
	check(missing_barks.is_empty(), "every crew member has every bark, and a script %s" % [missing_barks])
	check(named.is_empty(), "no crew line names a crew member: players type their own names %s" % [named])
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
	# The crew can say the name on the screen; nobody voices or describes SYSOP.
	var sysop_named: Array = docs.keys().filter(func(path): return not path.get_file().begins_with("crew") and docs[path].to_upper().contains("SYSOP"))
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


class FakeHud extends Node:
	var said: Array = []

	func say(speaker: String, text: String, _seconds: float = -1.0) -> void:
		said.append([speaker, text])


func test_commentary() -> void:
	print("Crew commentary")
	var levels_src := ""
	for f in DirAccess.get_files_at("res://scripts/levels"):
		if f.ends_with(".gd"):
			levels_src += FileAccess.get_file_as_string("res://scripts/levels/" + f)
	var bad_ids := []
	var bad_docs := []
	var bad_puzzles := []
	var used := {Commentary.NUDGE2_FIRST: true, Commentary.NUDGE2: true}
	for pid in Commentary.NUDGES:
		var d: Dictionary = Commentary.NUDGES[pid]
		if not levels_src.contains('Puzzle.new("%s"' % pid):
			bad_puzzles.append(pid)
		var ids: Array = d.get("disc", {}).values() + d.get("errors", {}).values() + d.get("pay", [])
		var n1: Dictionary = d.get("n1", {})
		for k in ["seen", "unseen"]:
			if n1.has(k):
				ids.append(n1[k])
		var titles: Array = []
		if n1.has("doc"):
			titles.append(n1["doc"])
		for ev in d.get("disc", {}):
			if ev.begins_with("read:"):
				titles.append(ev.trim_prefix("read:"))
		for t in titles:
			if not levels_src.contains('"%s"' % t):
				bad_docs.append(t)
		for id in ids:
			used[id] = true
			if VoiceLines.get_line(id).get("speaker", "") != "CREW":
				bad_ids.append(id)
	check(bad_puzzles.is_empty(), "commentary only covers puzzles the levels have %s" % [bad_puzzles])
	check(bad_ids.is_empty(), "every commentary line is a crew line in the script %s" % [bad_ids])
	check(bad_docs.is_empty(), "commentary only points at papers that are in the levels %s" % [bad_docs])
	# Crew lines in a commentary scene ("l0_crew" and so on); the crew's book huddles are played elsewhere.
	var unused := VoiceLines.LINES.keys().filter(func(id): return VoiceLines.LINES[id]["scene"].ends_with("_crew") and not used.has(id))
	check(unused.is_empty(), "every crew commentary line has a moment to play %s" % [unused])

	var hud := FakeHud.new()
	var cc := Commentary.new()
	cc.hud = hud
	root.add_child(hud)
	root.add_child(cc)
	await process_frame
	var last := func() -> String: return hud.said[-1][1] if not hud.said.is_empty() else ""
	var text := func(id: String) -> String: return VoiceLines.get_line(id)["text"]

	cc.begin("controller")
	cc.mistake("reset")
	cc.mistake("")
	cc.tick(Commentary.QUIET_START_S - 1.0)
	check(hud.said.size() == 0, "no nudge in a puzzle's first seconds, even after two fails")
	cc.mistake("reset")
	check(last.call() == text.call("l1_cc_err_reset"), "the same mistake twice plays its error line")
	cc.mistake("reset")
	check(hud.said.size() == 1, "an error line plays once")
	cc.pause(true)
	cc.tick(100.0)
	cc.pause(false)
	cc.typing(true)
	cc.tick(100.0)
	cc.typing(false)
	check(hud.said.size() == 1 and cc.clock < Commentary.NUDGE1_S, "the nudge clock stops in cut-scenes and while someone types")

	cc.begin("controller")
	cc.since_line = INF
	cc.tick(Commentary.NUDGE1_S)
	check(last.call() == text.call("l1_cc_nudge1_a"), "Nudge 1 points at the room before the paper is found")
	cc.tick(Commentary.COOLDOWN_S - 1.0)
	cc.mistake()
	cc.mistake()
	cc.tick(0.5)
	check(last.call() == text.call("l1_cc_nudge1_a"), "nothing plays inside the cooldown")
	cc.tick(1.0)
	check(last.call() == text.call(Commentary.NUDGE2_FIRST), "after two fails Nudge 2 points at SYSOP")
	var count: int = hud.said.size()
	cc.tick(1000.0)
	check(hud.said.size() == count and cc.nudges == Commentary.MAX_NUDGES, "at most two nudges per puzzle")

	cc.read("NOC SHIFT LOG")
	check(last.call() == text.call("l1_cc_log"), "reading a paper plays its discovery line")
	cc.read("NOC SHIFT LOG")
	check(hud.said.size() == count + 1, "a discovery plays once")
	cc.begin("controller")
	cc.since_line = INF
	cc.tick(Commentary.NUDGE1_S)
	check(last.call() == text.call("l1_cc_nudge1_b"), "once the paper is found, Nudge 1 points at it")

	cc.begin("lab_door", true)
	cc.since_line = INF
	cc.tick(Commentary.NUDGE2_TIMED_S)
	check(last.call() == text.call(Commentary.NUDGE2), "under a timer Nudge 1 is skipped, and later Nudge 2s don't repeat the first one")
	cc.solved()
	check(last.call() == text.call("l2_cc_door_pay") and cc.case_id == "", "solving plays the payoff and stops the nudges")

	cc.hold(true)
	cc.read("Fire interlock")
	check(last.call() != text.call("l1_cc_hot_plate"), "commentary waits while other dialogue plays")
	cc.hold(false)
	check(last.call() == text.call("l1_cc_hot_plate"), "a waiting discovery plays once the dialogue is over")
	check(Commentary.kind_of({"ok": false, "error": "no such table: door"}) == "table" \
		and Commentary.kind_of({"ok": false, "error": "no such column: ext"}) == "column", "failed queries are sorted into mistakes")
	cc.queue_free()
	hud.queue_free()


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
	for path in ["res://scenes/main_menu.tscn", "res://scenes/field_notes.tscn", "res://scenes/lobby.tscn", "res://scenes/customize.tscn"]:
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
	_lower_chapters_read([level])  # about something else: no huddle cuts in
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
	check(level.seat_spawn(0).origin.distance_to(level.player.global_position) < 0.3, "solo play starts in the driver's seat, where you got in at home base")
	_game().van_seating.assign([7, level.multiplayer.get_unique_id()])
	check(level.seat_for(0) == 1, "each player arrives in the seat they took at home base")
	_game().van_seating.clear()
	level.player.global_transform = level.seat_spawn(1)  # the rest climbs out of the passenger side
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
	level.terminal_ui.run("SELECT * FROM visitors ORDER BY signed_in DESC LIMIT 1")
	check(not level.visitor_puzzle.solved and TerminalUI._plain(level.desk_terminal.transcript[-1]).contains("one row further down"), "the visitor log cut to LIMIT 1 shows only the crew, and SYSOP says Vale is one row down")
	level.terminal_ui.run("SELECT * FROM visitors ORDER BY signed_in DESC LIMIT 3")
	check(level.visitor_puzzle.solved, "LIMIT 3 reaches Vale's row and solves the visitor log")
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
	level._leave_lobby()
	await process_frame
	check(is_instance_valid(level.walkies) and not level.player.inventory.has("radio"), "the story moves on without anyone taking a walkie-talkie: they're optional")
	level.walkies.enabled = true
	level.walkies.stock(1)
	level.walkies.interact(level.player)
	await process_frame
	check(level.player.inventory.has("radio") and level.player.inventory.hotbar.has("radio"), "your walkie-talkie goes on the hotbar")
	check(level.walkies.models.all(func(m): return not m.visible) and level.geo.get_node_or_null("ChargingDock") != null, "and leaves its charger empty on the table")
	check(level.walkies.get_prompt(level.player) == "You already have a walkie-talkie.", "and you can't take a second")
	var panel: Node3D = level.elevator.art.get_node("ButtonPanel") if level.elevator.art else null
	check(panel == null or level.elevator.button.global_position.distance_to(panel.global_position) < 0.35, "the elevator's button is pressed where its panel is drawn")
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
	# A door moved and turned after Door.create (a stairwell's) still swings on its own hinge.
	var rotated_door := Door.create(level, "TEST-TURNED", Vector3(30, 1.2, 34), Vector3(0.9, 2.4, 0.1))
	rotated_door.position = Vector3(32, 1.2, 36)
	rotated_door.rotation_degrees.y = 90.0
	rotated_door.make_hinged(Vector3(-0.45, 0, 0), 90.0)
	var hinge_at := rotated_door.to_global(rotated_door.hinge)
	rotated_door.set_open(true, true)
	check(rotated_door.to_global(rotated_door.hinge).distance_to(hinge_at) < 0.01 and is_equal_approx(rotated_door.rotation_degrees.y, 180.0),
		"a door turned after it's built swings round its own hinge")
	rotated_door.set_open(false, true)
	check(rotated_door.position.distance_to(Vector3(32, 1.2, 36)) < 0.01 and is_equal_approx(rotated_door.rotation_degrees.y, 90.0), "and shuts back where it was put")
	var slid := Door.create(level, "TEST-SLID", Vector3(30, 1.2, 38), Vector3(1.6, 2.4, 0.2))
	slid.position = Vector3(34, 1.2, 38)
	slid.set_open(true, true)
	slid.set_open(false, true)
	check(slid.position.distance_to(Vector3(34, 1.2, 38)) < 0.01, "a sliding door moved after it's built shuts where it was put")
	level.queue_free()
	await process_frame


## Who called: the crew pick the answer out themselves. Adding Mercer's row (or
## his line on the mailroom printout) to the notebook writes him into the blank
## on the case page, and that's what moves the story on; listing the directory
## alone doesn't.
func test_caller_answer() -> void:
	print("Who called: the answer goes in the case page's blank")
	for route in ["terminal", "printout"]:
		_game().new_run(8)
		var level = load("res://scenes/level_0.tscn").instantiate()
		root.add_child(level)
		for i in 20:
			await physics_frame
		var p: Player = level.player
		level._release_camera(p)
		p.seated = false
		p.global_position = Vector3(1.0, 0.1, -1.9)
		for i in 10:
			await physics_frame
		level.peek_puzzle.solved = true  # the memo comes first: .hint is the caller's from here
		level.memo_puzzle.solved = true
		level._ask_caller()
		var ext := str(level.data.extension)
		var c: Dictionary = _game().case_info("caller")
		check(c.has("blank") and c.blank.filled == "" and c.blank.prompt.contains(ext), "%s: the caller's case page has a blank for the name beside ext. %s" % [route, ext])
		var page: String = level.notebook.pages.section_text(NotebookPages.Page.CASES)
		check(page.contains("Ext. %s belongs to:" % ext) and page.contains(NotebookPages.BLANK) and page.contains(NotebookPages.BLANK_HOW), "%s: the page shows the empty blank, and in pencil how to fill it" % route)
		if route == "terminal":
			var ui: TerminalUI = level.terminal_ui
			ui.open(level.desk_terminal, p)
			ui.run("SELECT name, extension FROM staff_directory WHERE extension != %s;" % ext)
			await process_frame
			check(not level.caller_listed and not screen_text(ui).contains("there it is"), "terminal: a list without the caller's row gets no \"there it is\" from SYSOP")
			ui.run("SELECT name, extension FROM staff_directory;")
			await process_frame
			check(not level.caller_puzzle.solved and level.caller_listed and screen_text(ui).contains("point at the row with ext. %s" % ext), "terminal: listing the directory doesn't answer it for you: SYSOP says to pick out the row")
			var rows: Array = ui.noteable_lines().filter(func(l): return l.kind == "row")
			var shown: int = level.db.run_silent("SELECT name FROM staff_directory").size() + level.db.run_silent("SELECT name FROM staff_directory WHERE extension != %s" % ext).size()  # both lists
			check(rows.size() == shown and rows.all(func(r): return r.text.begins_with("name")), "terminal: every row of a result is a line of its own, copied with its header")
			var lines: Array = ui.noteable_lines()
			var wrong := -1
			var right := -1
			for i in lines.size():
				if lines[i].kind != "row":
					continue
				if lines[i].text.contains("Harold Mercer"):
					right = i
				elif wrong < 0:
					wrong = i
			var probe: float = ui._para_top(lines[right].from) + 2.0 - ui._output.get_v_scroll_bar().value
			check(ui._line_at(probe) == right, "terminal: the pointer finds Mercer's row on its own")
			ui.run(".hint")
			check(TerminalUI._plain(level.desk_terminal.transcript[-1]).contains("point at the row with ext. %s and click + add to notebook" % ext), "terminal: once the row has shown, .hint gives the add step, not the query again")
			ui._start_note(wrong)
			check(ui._note_label.visible and not level.caller_puzzle.solved, "terminal: someone else's row is an ordinary note, and asks for a name")
			ui._finish_note("")
			await process_frame
			var wrong_ext: String = Array(lines[wrong].text.split("\n")[1].split("|"))[1].strip_edges()
			check(screen_text(ui).contains("that's ext. %s's row. the blank wants whoever has ext. %s." % [wrong_ext, ext]), "terminal: SYSOP says why the blank stayed empty, without naming the answer")
			ui._start_note(wrong + 1 if wrong + 1 != right else wrong + 2)
			ui._finish_note("")
			await process_frame
			check(screen_text(ui).count("the blank wants whoever") == 1, "terminal: once per run")
			ui._start_note(right)
			check(not ui.visible and not ui._note_label.visible, "terminal: Mercer's row goes straight in, and you step back from the screen")
		else:
			var reader: DocumentReader = level.directory_printout.open_reader(p)
			var at: int = level.directory_printout.lines().map(func(l): return l.text).find(level.directory_printout.lines().filter(func(l): return l.text.contains("Harold Mercer"))[0].text)
			var others: Array = []
			for i in level.directory_printout.lines().size():
				var l: Dictionary = level.directory_printout.lines()[i]
				if l.has("row") and i != at:
					others.append(i)
			var miss := "Not that one: the blank wants whoever has ext. %s." % ext
			reader.write_note(others[0])
			page = level.notebook.pages.section_text(NotebookPages.Page.CASES)
			check(page.contains(miss) and _game().case_info("caller").blank.filled == "", "printout: someone else's line leaves the blank empty, and a pencil line under it says why")
			reader.write_note(others[1])
			page = level.notebook.pages.section_text(NotebookPages.Page.CASES)
			check(page.count(miss) == 1, "printout: once")
			reader._start_note(at)
			for i in 30:
				if not is_instance_valid(reader):
					break
				await physics_frame
			check(not is_instance_valid(reader), "printout: adding Mercer's line puts the printout down")
		for i in 30:
			if level.caller_puzzle.solved:
				break
			await physics_frame
		c = _game().case_info("caller")
		check(level.caller_puzzle.solved and c.solved and c.blank.filled == "Harold Mercer", "%s: Mercer is written into the blank, and that solves the case" % route)
		for i in 60:
			if level.notebook.is_open():
				break
			await physics_frame
		check(level.notebook.is_open() and level.notebook.pages.current_page() == NotebookPages.Page.CASES, "%s: the notebook comes up at the case page" % route)
		check(not c.blank.fresh and level.notebook.pages.book.book.get_node_or_null("Pen") != null, "%s: and the pen writes the name in as you watch" % route)
		check(not _game().notebook_written.any(func(w): return w.text.contains("Harold Mercer")), "%s: the answer goes in the blank, not as a loose note too" % route)
		level.queue_free()
		await process_frame


## All the text on a terminal's screen.
func screen_text(ui: TerminalUI) -> String:
	return ui._output.get_parsed_text()


func test_ground_floor() -> void:
	print("Ground floor")
	_game().new_run(6)
	var level = load("res://scenes/level_0.tscn").instantiate()
	root.add_child(level)
	_lower_chapters_read([level])  # about something else: no huddle cuts in
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
	_lower_chapters_read([level])  # about something else: no huddle cuts in
	for i in 30:
		await physics_frame
	check(level.doors["SRA-EXIT"].is_open == false and level.room_c_door.locked, "Server Room A's rear door and Server Room C start stuck")
	var z: String = level.zone
	check(level.plate_text("SRC") == "SRC" and not level.plate_text("SRA-EXIT").contains("ZONE"), "door plates name the door, not its zone: only the doors query gives that")
	check((level.door_plates["SRC"].material_override as StandardMaterial3D).albedo_color.r > 0.8 and (level.door_plates["NOC"].material_override as StandardMaterial3D).albedo_color.g > 0.8, "stuck doors' plates are red, the rest green")
	check(not _doc_has(level, "zone %s" % z) and not _doc_has(level, "zone A") and not Array(level.terminal.boot_lines).any(func(l): return l.contains("zone %s" % z) or l.contains("(zone")), "nothing printed names the faulted zone")
	check(not level.lights["1-BREAK"][0].visible and level.lights["noc"][0].visible, "the break room's bulb is dead, by its row in the lights table")
	check(not level.elevator.button.enabled and level.elevator.open_amount == 0.0, "the elevator up is out of service")
	check(level.terminal.locked, "the terminal waits for Rourke's maintenance session")
	level._on_panel(null, level.answer)
	check(not level.controller_puzzle.solved and level.doors["SRA-EXIT"].is_open == false, "the racks do nothing before Rourke asks")
	level._on_asked()
	check(not level.terminal.locked and _game().current_todo() != "", "once Rourke asks, the terminal opens and the job goes on the to-do list")
	level._on_panel(null, level.answer)
	check(not level.controller_puzzle.solved and level.doors["SRA-EXIT"].is_open == false and level.panels_locked_until == 0.0 and level.hud._notice.text.contains("NO POWER"), "pressing racks can't stand in for the query: no power until the terminal finds the controller")
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
	check(level.terminal.hint_case() == "controller" and level.terminal.puzzles[0] == level.stuck_doors_puzzle, "the first hints are for the stuck doors, on the controller's case page")
	for bad in ["SELECT name, zone FROM doors", "SELECT name, zone FROM doors WHERE locked = 0", "SELECT name FROM doors WHERE locked = 1"]:
		level.terminal_ui.run(bad)
		check(not level.stuck_doors_puzzle.solved, "stuck doors: '%s' isn't it" % bad)
	level.terminal_ui.run("SELECT name, zone FROM doors WHERE locked = 1")
	check(level.stuck_doors_puzzle.solved and not level.controller_puzzle.solved, "WHERE locked = 1 finds the stuck doors: a step, not the answer")
	check(_game().current_todo() == "Find the door controller that keeps faulting, and reset it" and _game().case_info("controller").clues.any(func(k): return k.text == "The stuck doors on this floor are all in zone %s." % z), "their zone goes on the case page, and the to-do moves on to the controller")
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = '%s'" % z)
	check(not level.controller_puzzle.solved, "zone alone isn't enough")
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % z)
	check(level.controller_puzzle.solved, "WHERE + AND finds the controller")
	# The reset's sign-off wants the floor's faulted count first.
	check(_game().current_todo() == level.COUNT_TODO and not level.count_puzzle.solved, "next, the sign-off wants the faults counted")
	level._on_panel(null, level.answer)
	check(level.doors["SRA-EXIT"].is_open == false and level.panels_locked_until == 0.0 and level.hud._notice.text.contains("NO POWER"), "the right rack still has no power until the count is logged")
	level.terminal_ui.run("SELECT COUNT(*) FROM door_controllers")
	check(not level.count_puzzle.solved and TerminalUI._plain(level.terminal.transcript[-1]).contains("healthy ones too"), "counting every controller isn't it, and SYSOP says why")
	level.terminal_ui.run("SELECT COUNT(*) FROM door_controllers WHERE status != 'ok'")
	check(not level.count_puzzle.solved and TerminalUI._plain(level.terminal.transcript[-1]).contains("offline ones too"), "counting everything not 'ok' takes in the offline ones, and SYSOP says why")
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE status = 'fault'")
	check(not level.count_puzzle.solved and TerminalUI._plain(level.terminal.transcript[-1]).contains("let COUNT(*) do the counting"), "listing the faulted rows isn't the count, and SYSOP points at COUNT(*)")
	var printout: Document = level.find_children("*", "Document", true, false).filter(func(d): return d.title == "WARDEN DIAGNOSTICS")[0]
	check(printout.plain_text().contains("COUNT(*): %d" % level.db.run_silent("SELECT COUNT(*) AS n FROM racks")[0]["n"])
		and printout.plain_text().contains("COUNT(*): %d" % level.db.run_silent("SELECT COUNT(*) AS n FROM racks WHERE room = 'Server Room C'")[0]["n"]),
		"WARDEN's printout shows the racks table's real counts")
	level.terminal_ui.run("SELECT COUNT(id) AS n FROM door_controllers WHERE status = 'fault'")
	check(level.count_puzzle.solved and _game().current_todo() == "Reset the faulted controller at its rack", "COUNT with WHERE status = 'fault' logs the count, and the to-do moves on to the reset")
	check(_game().notebook_todo.any(func(t): return t.text == level.COUNT_TODO and t.filled == "units faulted: %d" % level.faulted), "the count is written on the job ticket")
	_check_l1_documents(level)
	check(level.find_children("*", "Document", true, false).any(func(d): return d.title.ends_with("RACK MONITORING") and d.global_position.distance_to(level.terminal.global_position) < 1.5 and d.plain_text().contains("temp_c > %d" % Level1Data.INTERLOCK_C)), "the racks table and its limit are on a card at the terminal, before any hint")
	var healthy: String = level.db.run_silent("SELECT id FROM door_controllers WHERE status = 'ok' AND location LIKE 'Server Room A%'")[0]["id"]
	level._on_panel(null, healthy)
	check(level.panels_locked_until == 0.0, "pressing a healthy rack explains itself without a lockout")
	var wrong: String = level.db.run_silent("SELECT id FROM door_controllers WHERE zone = '%s' AND status = 'offline'" % z)[0]["id"]
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
	check((level.door_plates["SRC"].material_override as StandardMaterial3D).albedo_color.g > 0.8, "and their plates go green")
	var shown := "\n".join(Array(level.terminal.transcript))
	check(shown.contains("VALE_I") and shown.contains("SECURE LAB B"), "the controller's log points at Vale's lab")
	check(level.find_children("*", "Document", true, false).any(func(d): return d.title == "SYSLOG PRINTOUT" and str(d.doc_lines).contains("VALE")), "and so does the syslog printout in Server Room C")
	check(_game().rourke_fate == "unknown", "Rourke's fate is still open after the server floor")

	# Optional: the dark break room. Facilities' card asks for every light that's
	# dead or flickering; the circuit reset only takes once the terminal has the list.
	level._on_light_panel(null)
	check(not level.lights_fixed and level.hud._notice.text.contains("RESET LOCKED"), "the break room's circuit reset won't take before the terminal lists the lights")
	for bad in ["SELECT room, status FROM lights WHERE status = 'dead'", "SELECT room, status FROM lights WHERE is_on = 0",
			"SELECT room, status FROM lights WHERE status != 'ok'", "SELECT room, status FROM lights WHERE status = 'dead' AND status = 'flickering'"]:
		level.terminal_ui.run(bad)
		check(not level.dark_room_puzzle.solved, "dark room: '%s' isn't it" % bad)
	level.terminal_ui.run("SELECT * FROM lights WHERE status = 'flickering' OR status = 'dead'")
	check(level.dark_room_puzzle.solved and _game().case_info("dark_room").open, "dead OR flickering lists the lights that are out")
	level._on_light_panel(null)
	check(level.lights_fixed and level.lights["1-BREAK"][0].visible, "then the reset lights the break room")
	check(level.db.run_silent("SELECT status FROM lights WHERE id = '1-VAULT-BAY'")[0]["status"] == "off" and level.db.run_silent("SELECT status FROM lights WHERE id = '1-HALL-N'")[0]["status"] == "ok", "it fixes the flicker too, and leaves the light that's off on purpose")
	check(level.lights["corridor"].all(func(l): return l.find_children("*", "FlickerLight", false, false).filter(func(f): return not f.is_queued_for_deletion()).is_empty()), "the north corridor stops flickering")
	check(_game().case_info("dark_room").solved, "and the case is solved")

	# The cable vault's spare coil: whoever takes it carries it up.
	level.cable_coil.interact(level.player)
	await physics_frame
	check(level.cable_holders.has(level.players.id_of(level.player)) and level.player.inventory.has("cable") and level.cable_coil.models.all(func(m): return not m.visible), "taking a coil of network cable marks who carries it")
	check(level.spare_walkies.models.filter(func(m): return m.visible).size() == 6, "the NOC desk has spare walkie-talkies for anyone who left theirs downstairs")

	# Server Room B's hot rack: reseating its fan tray releases the cable vault's back door.
	check(level.vault_back.locked, "the cable vault's back door starts sealed by its fire interlock")
	var cool: String = level.db.run_silent("SELECT id FROM racks WHERE room = 'Server Room B' AND temp_c <= 40")[0]["id"]
	level._on_tray(null, level.hot_rack)
	check(level.vault_back.locked and level.trays_locked_until == 0.0 and level.hud._notice.text.contains("LATCH LOCKED"), "even the hot rack's tray stays latched until the terminal finds it")
	level.terminal_ui.run("SELECT id, temp_c FROM racks WHERE temp_c > 40")
	check(level.hot_rack_found and "\n".join(Array(level.terminal.transcript)).contains("LATCH RELEASED"), "the query releases the tray latch")
	level._on_tray(null, cool)
	check(level.vault_back.locked and level.trays_locked_until > 0.0, "reseating a healthy rack's tray does nothing but lock the trays")
	level.trays_locked_until = 0.0
	check(level.hot_rack_puzzle.matches(level.db, level.db.execute("SELECT id FROM racks WHERE temp_c > 40")), "WHERE temp_c > 40 finds the hot rack")
	level._on_tray(null, level.hot_rack)
	for i in 300:
		if not level.vault_back.locked:
			break
		await physics_frame
	check(not level.vault_back.locked and level.hot_rack_puzzle.solved, "reseating the hot rack's tray releases the interlock")

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
	check(level.elevator.button.get_prompt(level.player).contains("Press 22"), "inside, the button says where it goes")
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


## The Huddle for a level (not named as a class here: it pulls in LevelBase).
func _huddle_of(node: Node) -> Node:
	while node:
		if node.get_node_or_null("Huddle"):
			return node.get_node("Huddle")
		node = node.get_parent()
	return null


## Floor 22's chapters count as read on these levels, for tests about something else.
func _books_read(levels: Array) -> void:
	for l in levels:
		for id in ["easy_sql_9", "easy_sql_10", "easy_sql_11", "easy_sql_12", "easy_sql_13"]:
			_huddle_of(l).done[id] = true


## Play through the next book huddle on every machine: everyone turns the pages
## (a page turns once the whole crew is ready), then everyone votes for the
## right answer (scripts/huddle/).
func _crew_reads(levels: Array) -> void:
	var hs: Array = levels.map(func(l): return _huddle_of(l))
	var seen := false
	for f in 6000:
		await physics_frame
		for h in hs:
			h.reveal_scale = 0.05
			if not h.is_running():
				continue
			seen = true
			if h.question < 0:
				if f % 5 == 0 and not h.ready_to_turn():
					h.turn_page()
			elif h.result.is_empty() and not h.votes.has(h.multiplayer.get_unique_id()):
				h.vote(h.current_question().answer)
		if seen and hs.all(func(h): return not h.is_running() and h.get_node_or_null("HuddleUI") == null):
			return


## The ground floor's and floor 14's chapters (Ch 2 to 8) count as read on these
## levels, for tests about something else.
func _lower_chapters_read(levels: Array) -> void:
	for l in levels:
		for id in ["easy_sql_2", "easy_sql_3", "easy_sql_4", "easy_sql_5", "easy_sql_6", "easy_sql_7", "easy_sql_8"]:
			_huddle_of(l).done[id] = true


## Until a huddle for chapter `id` is open here (at most `seconds`).
func _huddle_opens(level: Node, id: String, seconds: float = 30.0) -> bool:
	var h := _huddle_of(level)
	return await _until(func(): return h.chapter.get("id", "") == id, seconds)


func _table(level: Node, sql: String) -> String:
	return JSON.stringify(level.db.run_silent(sql))


func test_coop_level_0() -> void:
	print("Co-op: Level 0 with a host and two clients")
	_game().new_run(11)
	var worlds := await _coop_worlds(2)
	check(get_multiplayer(worlds[0].get_path()).get_peers().size() == 2, "two clients connect to the host")
	var levels := await _coop_load(worlds, "res://scenes/level_0.tscn")
	_lower_chapters_read(levels)  # about something else: no huddle cuts in
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

	# Who called: a client writes Mercer into their blank, and the host moves everyone on.
	for l in levels:
		l._ask_caller()
	check(_game().fill_blank("caller"), "the client's blank takes the caller's name")
	c1.sync.report_answer("caller")
	await _frames(10)
	check(levels.all(func(l): return l.caller_puzzle.solved), "a client's answer settles who called for every machine")

	c2.terminal_ui.terminal = c2.desk_terminal
	c2.terminal_ui.run("INSERT INTO visitors (name) VALUES ('Intruder')")
	await _frames(10)
	var dump := "SELECT * FROM visitors ORDER BY rowid"
	check(_table(host, dump) == _table(c1, dump) and _table(c1, dump) == _table(c2, dump) and _table(host, dump).contains("Intruder"), "a write lands in every machine's copy of the database")

	for l in levels:
		l.walkies.enabled = true
		l.walkies.stock(l.players.count())
	c2.walkies.interact(c2.player)
	await _frames(10)
	var on_dock := func(l): return l.walkies.models.filter(func(m): return m.visible).size()
	check(levels.all(func(l): return l.walkies.taken_by.size() == 1 and on_dock.call(l) == 2) and _game().has_walkie and c2.player.inventory.has("radio"), "a client taking a walkie-talkie takes only their own; the rest stay on the dock")
	c2.walkies.interact(c2.player)
	await _frames(10)
	check(levels.all(func(l): return l.walkies.taken_by.size() == 1), "and can't take a second one")
	_game().inventory.remove("radio")  # all three machines share this process's inventory
	host.walkies.interact(host.player)
	await _frames(10)
	_game().inventory.remove("radio")
	c1.walkies.interact(c1.player)
	await _frames(10)
	check(levels.all(func(l): return on_dock.call(l) == 0 and l.walkies.taken_by.size() == 3), "once everyone has one, the dock is empty for everyone")

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
	_lower_chapters_read(levels)  # about something else: no huddle cuts in
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

	var wrong: String = host.db.run_silent("SELECT id FROM door_controllers WHERE zone = '%s' AND status = 'offline'" % host.zone)[0]["id"]
	client.terminal_ui.terminal = client.terminal
	client.terminal_ui.run("SELECT id FROM door_controllers WHERE zone = '%s' AND status = 'fault';" % host.zone)
	await _frames(10)
	check(host.controller_puzzle.solved and client.controller_puzzle.solved, "a client's query finds the controller for everyone")
	client.terminal_ui.run("SELECT COUNT(*) FROM door_controllers WHERE status = 'fault';")
	await _frames(10)
	check(host.count_puzzle.solved and client.count_puzzle.solved, "a client's count logs the sign-off for everyone")
	client.rack_panels[wrong].interact(client.player)
	await _frames(10)
	check(host.panels_locked_until > 0.0 and client.panels_locked_until > 0.0, "a wrong rack locks the panels for everyone")

	client.terminal_ui.terminal = client.terminal
	client.terminal_ui.run("UPDATE doors SET locked = 0, actuator_fault = 0 WHERE id = 'SRA-EXIT'")
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
	# Fists: a teammate's punch and guard show on their body for the others.
	check(client.player.get_node_or_null("FirstPersonBody") != null and client.player.get("combat") != null, "each player has their own first-person body and fists")
	client.player.leave_terminal()  # still at the desk from the queries above
	await create_timer(0.8).timeout
	client.player.combat.swung.emit()
	await _frames(8)
	check(mate.fighting == "jab" and mate.rig.action == "jab", "a teammate's punch shows on their body for the others")
	await create_timer(1.0).timeout
	check(mate.fighting == "" and mate.rig.action == "idle", "and they drop their fists after it")
	client.player.combat.hurt.emit(5.0, "test")
	await _frames(8)
	check(mate.rig.action == "flinch", "a hit they take shows as a flinch")
	await create_timer(0.6).timeout

	client.player.global_position = Vector3(-17.5, 0.1, -7.2)
	await _frames(5)
	client.cable_coil.interact(client.player)
	await _frames(10)
	check(host.cable_holders.has(client_id) and client.cable_holders.has(client_id) and client.player.inventory.has("cable"), "the client takes a cable coil, and every machine knows who carries it")
	_game().inventory.remove("cable")  # both machines share this process's inventory
	host.player.global_position = Vector3(-17.5, 0.1, -7.2)
	host.cable_coil.interact(host.player)
	await _frames(10)
	check(host.cable_holders.size() == 2 and client.cable_holders.size() == 2 and host.player.inventory.has("cable"), "and there's a coil for the host too")

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
	_lower_chapters_read(levels)  # about something else: no huddle cuts in
	check(levels.all(func(l): return l.sync._begun and l.players.count() == 6), "all six start together and see each other")
	var spots := {}
	for l in levels:
		spots[Vector2i(roundi(l.player.global_position.x * 10), roundi(l.player.global_position.z * 10))] = true
	check(spots.size() == 6, "six different spawn spots")
	await _coop_close(worlds)


func test_coop_tape_secret() -> void:
	print("Co-op: Mercer's tape")
	_game().new_run(3)
	var net: Node = root.get_node("/root/Net")
	var saved: Profile = net.profile
	var worlds := await _coop_worlds(1)
	var levels := await _coop_load(worlds, "res://scenes/level_0.tscn")
	_lower_chapters_read(levels)  # about something else: no huddle cuts in
	var client_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()
	levels[0].player.global_position = levels[0].to_global(Vector3(0, 0.1, 6))
	levels[1].player.global_position = levels[1].to_global(Vector3(-17.5, 0.1, 4))
	await _frames(30)  # the host sees the client reach the closet
	var host_profile := Profile.new()
	var client_profile := Profile.new()
	net.profile = host_profile
	levels[1].sync.unlock_for([client_id], "secret:mercer_vent_tape")  # a client can't hand it out
	levels[0].sync.event("_on_tape")
	net.profile = client_profile  # the test's machines share one Net, so give the client its own save
	await _frames(10)
	check(client_profile.earned.has("secret:mercer_vent_tape"),
		"the player in the vent closet when the tape plays earns its secret")
	check(not host_profile.earned.has("secret:mercer_vent_tape") and not levels[0].hud._notice.text.begins_with("Unlocked:"),
		"the host, out in the lobby, doesn't")
	check(not levels[0].tape.enabled and not levels[1].tape.enabled, "the tape is used up on every machine")
	await _coop_close(worlds)
	net.profile = saved


func test_coop_terminal_screens() -> void:
	print("Co-op: terminal screens are shared")
	_game().new_run(5)
	var worlds := await _coop_worlds(1)
	var levels := await _coop_load(worlds, "res://scenes/level_0.tscn")
	_lower_chapters_read(levels)  # about something else: no huddle cuts in
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
	check(screen.get_prompt(host.player).contains("SELECT * FROM_"), "looking at the terminal shows the client's half-typed line, no need to use it")
	var typist: PlayerPuppet = host.players.puppet(c1_id)
	await _frames(30)
	var aside: Vector3 = typist.global_position - typist._target_pos
	check(typist.at_terminal == screen and Vector2(aside.x, aside.z).length() > 0.4, "the typist leans in from the side, so the glass isn't hidden behind them")
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
	await _frames(30)
	aside = typist.global_position - typist._target_pos
	check(typist.at_terminal == null and Vector2(aside.x, aside.z).length() < 0.05, "and they step back to where they really are")
	check(not screen.get_prompt(host.player).contains("_"), "with nobody typing, looking at it just offers to use it")
	host.terminal_ui.close()
	ui.open(c1.desk_terminal, c1.player)
	await _frames(10)
	get_multiplayer(worlds[1].get_path()).multiplayer_peer.close()
	await _frames(30)
	check(screen.seated.is_empty() and screen.typing.is_empty(), "a player who drops out leaves the terminal free")
	ui.close()
	await _coop_close(worlds)


func test_coop_notes_huddle() -> void:
	print("Co-op: a notes huddle")
	_game().new_run(6)
	var worlds := await _coop_worlds(2)
	var levels := await _coop_load(worlds, "res://scenes/level_0.tscn")
	_lower_chapters_read(levels)  # about something else: no huddle cuts in
	var ids: Array = worlds.map(func(w): return get_multiplayer(w.get_path()).get_unique_id())
	var h_id: int = ids[0]
	var c1_id: int = ids[1]
	var c2_id: int = ids[2]
	var host_seen_by_c1: PlayerPuppet = levels[1].players.puppet(h_id)
	check(host_seen_by_c1.get_prompt(levels[1].player) == "[E] Huddle up to share notes", "E on a crewmate offers to huddle up")
	host_seen_by_c1.downed = true
	check(not host_seen_by_c1.get_prompt(levels[1].player).contains("huddle"), "a crewmate who's down is helped up, not huddled with")
	host_seen_by_c1.downed = false
	host_seen_by_c1.interact(levels[1].player)
	await _frames(10)
	check(levels.all(func(l): return l.sync.huddle.members(c1_id) == [h_id, c1_id] and l.sync.huddle.group_of(c2_id) == 0), "they're in a huddle, the same on every machine")
	check(levels[1].notebook.is_open() and levels[1].notebook.pages.current_page() == NotebookPages.Page.CASES, "the one who asked opens their notebook on the case pages")
	levels[1].notebook.close()
	var c1_seen_by_c2: PlayerPuppet = levels[2].players.puppet(c1_id)
	check(c1_seen_by_c2.get_prompt(levels[2].player) == "[E] Join the notes huddle", "anyone else can join by pressing E on someone in it")
	c1_seen_by_c2.interact(levels[2].player)
	await _frames(10)
	check(levels.all(func(l): return l.sync.huddle.members(h_id).size() == 3), "and joins the same huddle")
	check(levels[0].players.puppet(c1_id).get_prompt(levels[0].player) == "", "nothing to press on someone already in yours")
	# Every machine shares one Game in tests, so what the others receive lands there.
	var game := _game()
	game.open_case("rack", "Which fan tray tripped?", [])
	var case_info: Dictionary = game.case_info("rack")
	levels[1].sync.huddle.share([NotesHuddle.clue_item(case_info, "Fan tray 3 tripped at 21:40", "Rack log")])
	await _frames(10)
	var got: Array = game.case_info("rack").clues.filter(func(k): return k.text == "Fan tray 3 tripped at 21:40")
	check(got.size() == 1 and got[0].from == "Rack log (from Player %d)" % c1_id, "a shared line fills in the same case page, saying who it came from")
	check(levels[1].sync.huddle.was_sent("Fan tray 3 tripped at 21:40"), "and the sender's chip says it's shared")
	check(NotesHuddle.take(game, {"kind": "clue", "case": "vale", "title": "Where is Vale?", "tables": [], "text": "Lab B", "from": "Badge log"}, "Ana") and game.case_info("vale").open,
		"a line from a case you haven't opened opens it")
	check(NotesHuddle.take(game, NotesHuddle.sticky_item("like"), "Ana") and game.notebook_notes.has("like") and not NotesHuddle.take(game, NotesHuddle.sticky_item("like"), "Ana"),
		"a shared sticky note goes in your notebook once")
	game.write_note("", "Rourke checks his watch a lot", "mine", "rack")
	var items := NotesHuddle.case_items(game, "rack")
	check(items.size() == 2 and NotesHuddle.all_items(game).size() >= 4, "Share case notes sends the whole page; Share all cases every page and sticky")
	check(not NotesHuddle.take(game, NotesHuddle.note_item(game, game.notebook_written[-1]), "Ana"), "your own note shared back to you isn't added twice")
	# The notebook in a huddle.
	var pages := NotebookPages.new()
	pages.huddle = levels[1].sync.huddle
	root.add_child(pages)
	var cases := pages.section_items(NotebookPages.Page.CASES)
	var names: Array = []
	for item in cases:
		names.append_array(([item] + item.find_children("*", "Button", true, false)).filter(func(n): return n is Button).map(func(b): return b.name))
	check(names.has("ShareAll") and names.has("LeaveHuddle") and names.has("ShareCase") and names.count("Share") >= 3, "in a huddle, the case pages offer + share on each line, Share case notes and Share all cases")
	check(NotebookPages.text_of(cases).contains("Notes huddle with Player %d, Player %d" % [h_id, c2_id]), "and say who's in it")
	for item in cases:
		item.free()
	# Walking away takes you out.
	levels[2].player.global_position += Vector3(20, 0, 0)
	await _frames(60)
	check(levels.all(func(l): return l.sync.huddle.members(h_id) == [h_id, c1_id]), "walking away from the huddle leaves it")
	levels[1].sync.huddle.leave()
	await _frames(10)
	check(levels.all(func(l): return l.sync.huddle.groups.is_empty()), "Leave huddle ends a huddle of two")
	check(not NotebookPages.text_of(pages.section_items(NotebookPages.Page.CASES)).contains("Notes huddle"), "and the notebook goes back to normal")
	pages.queue_free()
	await _coop_close(worlds)
	_game().new_run(6)


func test_coop_looks() -> void:
	print("Co-op: picking a look in the lobby")
	var net := root.get_node("Net")
	var real_profile = net.profile
	net.profile = Profile.new()  # in memory, so tests never touch a real save
	net.wanted_look = {}
	# The catalogue covers everything Graphics can draw, and nothing it can't.
	var drawn := true
	for slot in CharacterLooks.SLOTS:
		for item in CharacterLooks.SLOTS[slot]:
			drawn = drawn and not Cosmetics.info(slot, item).is_empty()
	check(drawn and Cosmetics.ITEMS.all(func(it): return it.name != "" and (Cosmetics.drawable(it.slot, it.item) or it.unlock != "default")),
		"every outfit piece Graphics draws is in the catalogue, with a name, and every starting item can be drawn")
	check(Cosmetics.WORN_SLOTS.all(func(s): return CharacterLooks.SLOTS.has(s)) and CharacterLooks.TOOL_SLOTS.all(func(s): return s in Cosmetics.TOOL_SLOTS)
	and Cosmetics.TOOL_SLOTS.all(func(s): return s in CharacterLooks.TOOL_SLOTS or s in Cosmetics.NOTEBOOK_ADDONS), "the picker's slots are Graphics' slots, plus the notebook's add-ons")
	var defaults := range(6).map(func(i): return Cosmetics.default_loadout(i).top.color)
	check(defaults.all(func(c): return defaults.count(c) == 1), "players who never open the picker still wear different colors")
	# The host checks a loadout against the catalogue, and trusts what you own.
	net.roster = {1: "Host", 55: "Ana"}
	net.looks = {}
	net._assign_look(55, {"crew": "theo", "skin": 4, "head": {"item": "beanie", "color": Color(0.9, 0.1, 0.1)}, "terminal": {"color": Color(1, 0.7, 0.1)}})
	var ana: Dictionary = net.looks[55]
	check(ana.crew == "theo" and ana.body == 1 and ana.skin == 4 and ana.head.item == "beanie" and ana.head.color == Color(0.9, 0.1, 0.1), "a teammate's crew, skin, hat and its color reach the host")
	check(ana.terminal == {"item": "phosphor", "color": Color(1, 0.7, 0.1)} and ana.top == Cosmetics.default_loadout(1).top, "a color with no item keeps the default item, and slots left alone follow their place in the order")
	net._assign_look(1, {"crew": "theo", "skin": 4, "head": {"item": "beanie", "color": Color(0.9, 0.1, 0.1)}})
	check(net.looks[1].crew == "theo" and net.looks[1].head == ana.head, "teammates can pick the same crew member and the same everything")
	net._assign_look(1, {"crew": "nobody", "skin": 99, "head": {"item": "crown", "color": "red"}, "top": "polo", "legs": {"item": "pants", "color": Color(3, -1, 0.5, 0.2)}})
	var h: Dictionary = net.looks[1]
	check(h.crew == Cosmetics.default_loadout(0).crew and h.skin == Cosmetics.default_loadout(0).skin and h.head == Cosmetics.default_loadout(0).head and h.legs.color == Color(1, 0, 0.5, 1),
		"unknown crew, items and junk fall back to the defaults; colors are kept in range")
	net._assign_look(1, {"crew": "walt"})
	check(net.looks[1].body == 1 and Cosmetics.clean({"crew": "kit"}, 0).body == 2, "the crew member brings their body type")
	net.roster = {}
	net.looks = {}
	check(PlayableCrew.CAST.size() == 12 and PlayableCrew.on_body(1).size() == 6 and PlayableCrew.on_body(2).size() == 6, "twelve crew to play, six on each body type")

	# The profile keeps picks and unlocks between sessions.
	var path := "user://test_profile.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var prof := Profile.open(path)
	check(prof.name == "" and prof.loadout.is_empty() and prof.has_item("head/cap"), "a new profile owns every default item")
	Cosmetics.info("head", "hard_hat").merge({"unlock": "achievement:test", "hint": "Test hint"}, true)
	Cosmetics.catalogue.append({"slot": "flashlight", "item": "secret_x", "name": "Test secret", "unlock": "secret:test"})
	Cosmetics.catalogue.append({"slot": "walkie", "item": "shop_x", "name": "Test shop", "unlock": "purchase:test"})
	Cosmetics.catalogue.append({"slot": "walkie", "item": "secret_y", "name": "Test hidden", "unlock": "secret:other"})
	check(not prof.has_item("head/hard_hat") and not prof.has_item("flashlight/secret_x"), "locked and secret items start out locked")
	check(prof.earn("secret:test") == ["flashlight/secret_x"] and prof.earn("secret:test").is_empty(), "finding a secret unlocks its items, once")
	check(prof.grant("walkie/shop_x") and not prof.grant("walkie/shop_x") and not prof.grant("walkie/nothing"), "a purchase grants one item")
	prof.name = "Ana"
	prof.loadout = {"crew": "mei", "flashlight": {"item": "secret_x", "color": Color(0.2, 0.4, 0.9)}, "head": {"item": "hard_hat"}}
	prof.save()
	var again := Profile.open(path)
	check(again.name == "Ana" and again.loadout.crew == "mei" and again.loadout.flashlight == {"item": "secret_x", "color": Color(0.2, 0.4, 0.9)} and again.has_item("walkie/shop_x"),
		"name, picks and unlocks load back next time")
	check(not again.loadout.has("head"), "an item you don't own can't be worn by editing the save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# The lobby: Crew, Look and Gear tabs, and your own figure in front of the garage wears your pick.
	net.profile = Profile.new()
	net.profile.earned = ["secret:roster_thu"]
	net.roster = {1: "Host"}
	var lobby: Control = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	lobby.stage.finish_intro()
	var own_rig := func() -> CharacterRig: return lobby.stage.figures[1].get_node("Rig")
	var tabs: TabContainer = lobby.find_child("Customize", true, false)
	check(tabs != null and tabs.get_tab_count() == 4 and tabs.get_tab_title(0) == "Crew" and tabs.get_tab_title(1) == "Look" and tabs.get_tab_title(2) == "Gear" and tabs.get_tab_title(3) == "Achievements", "the picker has Crew, Look, Gear and Achievements tabs")
	lobby.find_child("Skin6", true, false).pressed.emit()
	lobby.find_child("Crew_kit", true, false).pressed.emit()
	var hats: OptionButton = lobby.find_child("Item_head", true, false)
	var hat_names := range(hats.item_count).map(func(i): return hats.get_item_text(i))
	var locked := hat_names.find("Hard hat (locked)")
	check(locked >= 0 and hats.is_item_disabled(locked) and hats.get_item_tooltip(locked) == "Test hint", "an item you haven't unlocked shows as locked, with how to get it")
	var walkies: OptionButton = lobby.find_child("Item_walkie", true, false)
	var jackets: OptionButton = lobby.find_child("Item_jacket", true, false)
	check(range(walkies.item_count).any(func(i): return walkies.get_item_text(i) == "Gold" and not walkies.is_item_disabled(i))
		and not range(jackets.item_count).any(func(i): return jackets.get_item_text(i).begins_with("Press jacket")), "a secret item shows once found, and stays hidden until then")
	var beanie := hat_names.find("Beanie")
	hats.select(beanie)
	hats.item_selected.emit(beanie)
	var tops: ColorPickerButton = lobby.find_child("Color_top", true, false)
	tops.color = Color(0.9, 0.5, 0.1)
	tops.color_changed.emit(tops.color)
	check(own_rig.call().look.shirt == Color(0.9, 0.5, 0.1) and not net.wanted_look.has("top"), "your figure follows the color picker as it moves")
	tops.popup_closed.emit()
	var term: ColorPickerButton = lobby.find_child("Color_terminal", true, false)
	term.color = Color(1, 0.75, 0.2)
	term.popup_closed.emit()
	await process_frame
	var shown: Dictionary = own_rig.call().look
	check(lobby.my_look().crew == "kit" and shown.shirt == Color(0.9, 0.5, 0.1) and shown.skin == CharacterLooks.SKIN_TONES[5] and shown.body == 2 and shown.headwear == "beanie" and shown.tools.terminal.color == Color(1, 0.75, 0.2),
		"crew member, skin, hat, colors and gear show on your figure")
	check(net.profile.loadout == net.wanted_look and net.wanted_look.keys().size() == 5, "and are saved to your profile (only what you changed)")
	check(lobby.find_child("Crew_kit", true, false).text == "Kit", "with who they are on the crew buttons")
	check(lobby.find_child("Color_face", true, false).disabled and not lobby.find_child("Color_head", true, false).disabled, "an empty slot has no color to pick")
	lobby.queue_free()
	net.roster = {}
	net.profile = Profile.new()
	check(net.earn("achievement:test") == ["head/hard_hat"], "earning an achievement unlocks its item")
	Cosmetics.reset()

	# Solo: the main menu's Customize screen has the same picker, and solo play wears it.
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var to_customize: Button = menu.find_child("Customize", true, false)
	check(to_customize != null and to_customize.text == "Customize", "the main menu has a Customize button")
	menu.queue_free()
	net.profile = Profile.new()
	net.wanted_look = {}
	var custom: Control = load("res://scenes/customize.tscn").instantiate()
	root.add_child(custom)
	await process_frame
	var solo_picker: LookPicker = custom.find_child("LookPicker", true, false)
	check(solo_picker != null and custom.find_child("Customize", true, false) is TabContainer and custom.find_child("Back", true, false) is Button,
		"it shows the Crew, Look, Gear and Achievements tabs, with a way back")
	custom.find_child("Crew_mei", true, false).pressed.emit()
	custom.find_child("Skin3", true, false).pressed.emit()
	var solo_term: ColorPickerButton = custom.find_child("Color_terminal", true, false)
	solo_term.color = Color(0.3, 0.8, 1.0)
	solo_term.popup_closed.emit()
	await process_frame
	check(net.profile.loadout.crew == "mei" and net.profile.loadout.skin == 2 and solo_picker._preview_rig.look.skin == CharacterLooks.SKIN_TONES[2],
		"picks show on the figure and are saved to the profile, with nobody connected")
	check(custom.find_child("CrewCaption", true, false).text.begins_with(PlayableCrew.info("mei").name), "with who they are underneath")
	custom.queue_free()
	await process_frame
	_game().new_run(8)
	var solo = load("res://scenes/level_0.tscn").instantiate()
	root.add_child(solo)
	await _frames(5)
	check(NetPlayers.look_for(solo, solo.multiplayer.get_unique_id()).tools.terminal.color == Color(0.3, 0.8, 1.0), "solo play uses the picks")
	solo.terminal_ui.open(solo.desk_terminal, solo.player)
	await _frames(5)
	check(solo.desk_terminal.skin_color == Color(0.3, 0.8, 1.0), "a terminal you sit at alone wears your terminal skin")
	solo.terminal_ui.close()
	solo.queue_free()
	await process_frame
	net.wanted_look = {}

	# In the building, everyone wears what they picked.
	_game().new_run(8)
	var worlds := await _coop_worlds(1)
	var host_id: int = get_multiplayer(worlds[0].get_path()).get_unique_id()
	var c_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()
	net.looks = {
		host_id: Cosmetics.clean({"crew": "june", "skin": 0, "top": {"item": "blouse", "color": Color(0.5, 0.1, 0.4)}, "jacket": {"item": "blazer"},
			"terminal": {"color": Color(1, 0.7, 0.1)}}, 0),
		c_id: Cosmetics.clean({"crew": "sam", "head": {"item": "hard_hat", "color": Color(1, 0.8, 0)}, "flashlight": {"color": Color(0.8, 0.1, 0.1)},
			"terminal": {"color": Color(0.9, 0.9, 0.9)}}, 1),
	}
	var levels := await _coop_load(worlds, "res://scenes/level_0.tscn")
	_lower_chapters_read(levels)  # about something else: no huddle cuts in
	var host_seen: PlayerPuppet = levels[1].players.puppet(host_id)
	var c_seen: PlayerPuppet = levels[0].players.puppet(c_id)
	check(host_seen.rig.look.shirt == Color(0.5, 0.1, 0.4) and host_seen.rig.look.sleeves == "long" and host_seen.rig.look.shoulder_pads and host_seen.rig.look.skin == CharacterLooks.SKIN_TONES[0] and host_seen.rig.look.body == 2
		and c_seen.rig.look.headwear == "hard_hat" and c_seen.rig.look.headwear_color == Color(1, 0.8, 0) and c_seen.rig.look.shirt == Cosmetics.default_loadout(1).top.color,
		"teammates see each other's outfits as they picked them")
	var lamp: MeshInstance3D = c_seen.find_child("Lamp", true, false)
	check(lamp.material_override.albedo_color == Color(0.8, 0.1, 0.1), "and the flashlight in their skin's color")
	# A shared terminal takes the skin of whoever sat down first.
	var screen_h: Terminal = levels[0].desk_terminal
	var screen_c: Terminal = levels[1].desk_terminal
	check(screen_h.skin_color == TerminalScreen.PHOSPHOR, "an unused terminal is green phosphor")
	levels[1].terminal_ui.open(screen_c, levels[1].player)
	await _frames(10)
	levels[0].terminal_ui.open(screen_h, levels[0].player)
	await _frames(10)
	check(screen_h.seated == [c_id, host_id] and screen_h.skin_color == Color(0.9, 0.9, 0.9) and screen_c.skin_color == Color(0.9, 0.9, 0.9), "the shared screen wears the first-seated player's terminal skin on every machine")
	check(net.terminal_color(host_id) == Color(1, 0.7, 0.1), "each player's own prompt color is there for their line")
	levels[1].terminal_ui.close()
	await _frames(10)
	check(screen_h.skin_color == Color(1, 0.7, 0.1) and screen_c.skin_color == Color(1, 0.7, 0.1), "when they leave, it passes to whoever is still there")
	levels[0].terminal_ui.close()
	await _coop_close(worlds)
	net.looks = {}
	net.wanted_look = {}
	net.profile = real_profile


## Deck scripts in co-op (S4): the host runs them, everyone sees the same run,
## anyone can stop one, and what a script changes reaches every copy.
## The pre-game lobby in front of the garage: walk in, pose, customize, ready up.
func test_coop_pregame_lobby() -> void:
	print("Co-op: the pre-game lobby")
	var net := root.get_node("Net")
	var real_profile = net.profile
	net.profile = Profile.new()
	net.wanted_look = {}
	# The host keeps who's ready and how each player stands.
	net.roster = {1: "Host", 55: "Ana", 77: "Bo"}
	net.looks = {}
	net.lobby = {}
	check(net.lobby_of(1) == {"ready": false, "pose": 0} and net.lobby_of(55).pose == 1 and net.lobby_of(77).pose == 2,
		"nobody starts ready, and neighbours stand differently")
	net._assign_lobby(55, {"ready": true})
	net._assign_lobby(77, {"ready": "yes", "pose": 99})
	check(net.lobby_of(55).ready and not net.lobby_of(77).ready and net.lobby_of(77).pose == 99 % net.LOBBY_POSES.size() and not net.all_ready(),
		"the host takes a ready and a pose, ignores junk, and waits for everyone")

	var lobby: Control = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	var stage: LobbyStage = lobby.stage
	check(lobby.find_child("Welcome", true, false).text == "Welcome to Byte-Right IT!" and stage.camera.position.y > 20.0
		and not lobby._side.visible, "it opens on the sky under the welcome, before any menus")
	check(stage.figures.size() == 3 and stage.figures.keys().all(func(id): return stage.figures[id].position.distance_to(stage.mark(net.lobby_index(id))) > 5.0),
		"each player in the session walks in from the edge of the shot")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	lobby._input(key)
	check(stage.intro_done and stage.camera.transform.is_equal_approx(load("res://scripts/levels/home_base.gd").LOBBY_CAMERA) and lobby._side.visible, "a key skips to the garage front, and the menus show")
	Engine.time_scale = 5.0
	await create_timer(7.0).timeout  # game time: walking in from the edge takes a few seconds
	Engine.time_scale = 1.0
	var host_fig: Node3D = stage.figures[1]
	check(stage.figures.keys().all(func(id): return stage.figures[id].position.is_equal_approx(stage.mark(net.lobby_index(id)))),
		"and stops on their own mark, host first")
	check(host_fig.get_node("Rig").action == "wave" and stage.figures[77].get_node("Rig").action == net.lobby_action(77),
		"then strikes their pose")
	check(net.pose_action("sit") == "sit_floor" and net.pose_action("nonsense") == "idle" and net.LOBBY_POSES.all(func(p): return net.pose_action(p) in CharacterRig.ACTIONS),
		"every pose plays something the rig can draw (idle until Graphics draws it)")
	check(stage.figures[55].get_node("Tag").text == "Ana\nReady" and host_fig.get_node("Tag").text == "Host", "a name over each head, and who's ready")
	var open_picker: Button = lobby.find_child("OpenCustomize", true, false)
	check(not lobby.picker.visible and open_picker.text == "Customize", "the picker is folded away behind Customize, so the crew stays in view")
	open_picker.button_pressed = true
	check(lobby.picker.visible, "and opens on a click")
	check(lobby.find_child("Waiting", true, false).text == "Waiting for everyone to get ready (1/3)" and lobby.find_child("Host", true, false).is_visible_in_tree() == false,
		"the menu counts who's ready, and hosting or joining is done")
	lobby.find_child("ChangePose", true, false).pressed.emit()
	check(net.lobby_of(1).pose == 1 and host_fig.get_meta("pose") == net.LOBBY_POSES[1] and host_fig.get_node("Rig").action == net.lobby_action(1),
		"Change pose changes how you stand, straight away")
	var ready: Button = lobby.find_child("Ready", true, false)
	ready.button_pressed = true
	check(net.lobby_of(1).ready and host_fig.get_node("Tag").text == "Host\nReady", "Ready marks you ready for everyone")
	net._assign_lobby(77, {"ready": true})
	check(net.all_ready() and lobby._all_ready_for == 0.0, "once everyone is, the game can start (the host starts it when online)")
	net._on_peer_disconnected(55)
	await process_frame
	check(not stage.figures.has(55) and not net.lobby.has(55) and stage.figures.size() == 2, "a player who leaves goes from the apron")
	ready.button_pressed = false
	check(not net.lobby_of(1).ready and not net.all_ready(), "and you can take your ready back")
	lobby.queue_free()
	await process_frame
	net.roster = {}
	net.looks = {}
	net.lobby = {}

	# Solo gets the same opening: just you, no hosting or joining.
	net.begin_solo_lobby()
	lobby = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	lobby.stage.finish_intro()
	check(lobby.stage.figures.keys() == [1] and not lobby.find_child("Host", true, false).is_visible_in_tree() and lobby.find_child("Ready", true, false).is_visible_in_tree()
		and lobby.find_child("Waiting", true, false).text == "", "solo opens on the garage too, with just you walking in and a Ready button")
	lobby.find_child("Ready", true, false).button_pressed = true
	lobby._process(1.0)
	check(net.all_ready() and lobby._all_ready_for == 1.0, "and Ready starts the game a moment later")
	lobby.find_child("Ready", true, false).button_pressed = false
	lobby.queue_free()
	await process_frame
	net.leave(false)
	check(not net.solo_lobby and net.roster.is_empty() and net.lobby.is_empty(), "leaving clears it")
	net.profile = real_profile


func test_coop_lobby_names() -> void:
	print("Co-op: changing your name in the lobby")
	var net := root.get_node("Net")
	var real_profile = net.profile
	var real_name: String = net.player_name
	net.profile = Profile.new()
	net.roster = {1: "Host", 55: "Bo", 77: "Ana"}
	check(net._unique_name("Bo", 77) == "Bo 2" and net._unique_name("Ana", 77) == "Ana" and net._unique_name("Cy", 77) == "Cy",
		"a name someone else has gets a number, and keeping your own doesn't")
	net._assign_name(77, "  Bo  ")
	check(net.roster[77] == "Bo 2" and net.roster[55] == "Bo", "the host renames a joiner and keeps names apart")
	net.roster = {}

	net.begin_solo_lobby()
	var lobby: Control = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	lobby.stage.finish_intro()
	var field: LineEdit = lobby.picker._name
	check(field.editable, "the name field still takes typing once you're in the lobby")
	field.text = "Wren"
	field.text_changed.emit("Wren")
	await process_frame
	check(net.roster[net.my_id()] == "Wren" and lobby.stage.figures[net.my_id()].get_node("Tag").text.begins_with("Wren"),
		"and the new name goes over your head straight away")
	lobby.queue_free()
	await process_frame
	net.leave(false)
	net.in_game = true
	net.roster = {1: "Wren"}
	net.set_player_name("Late")
	check(net.roster[1] == "Wren", "once the game has started, names stay put")
	net.in_game = false
	net.roster = {}
	net.player_name = real_name
	net.profile = real_profile


func test_coop_patience() -> void:
	print("Co-op: a host frozen loading the building keeps its joiners")
	var net := root.get_node("Net")
	for case in [[net.PATIENCE_LOBBY, false], [net.PATIENCE_LOADING, true]]:
		_next_port += 1
		var host := ENetMultiplayerPeer.new()
		host.create_server(_next_port, 6)
		var client := ENetMultiplayerPeer.new()
		client.create_client("127.0.0.1", _next_port)
		for i in 400:
			host.poll()
			client.poll()
			OS.delay_msec(2)
			if client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				break
		# Messages back and forth, so the client knows how quick the host answers.
		client.set_target_peer(1)
		client.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
		for i in 60:
			client.put_packet(PackedByteArray([1]))
			for k in 3:
				host.poll()
				client.poll()
				OS.delay_msec(2)
			while host.get_available_packet_count() > 0:
				host.get_packet()
		net.patient(client.get_peer(1), case[0])
		client.put_packet(PackedByteArray([2]))
		# The host freezes for 4 s (loading the building); the client carries on.
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 4000 and client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			client.poll()
			OS.delay_msec(20)
		var kept := client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
		if case[1]:
			check(kept, "while the building loads, a joiner waits out a host frozen for 4 s")
		else:
			check(not kept, "(the lobby's quick patience would have dropped them, which is what happened)")
		client.close()
		host.close()


func test_coop_scripts() -> void:
	print("Co-op: deck scripts")
	_game().new_run(31)
	var worlds := await _coop_worlds(1)
	var levels := await _coop_load(worlds, "res://scenes/level_1.tscn")
	_lower_chapters_read(levels)  # about something else: no huddle cuts in
	var terms: Array = levels.map(func(l): return l.find_children("*", "", true, false).filter(func(n): return n is Terminal)[0])
	await _frames(2)
	var rts: Array = terms.map(func(t): return t.get_meta("script_runtime") if t.has_meta("script_runtime") else null)
	check(rts.all(func(r): return r is NetScript), "in co-op every terminal's script is shared")
	var js := ScriptRuntime.for_language("javascript")
	check(rts[1].language() == "javascript" and (not js.has_method("placeholder") or rts[1].placeholder() == js.placeholder()), "and the runner still knows its language")
	# A route that counts what reaches each machine's copy of the building.
	var tallies := [0, 0]
	for i in 2:
		var api := FacilityAPI.new()
		api.route("POST", "/tally", func(_params, _req):
			tallies[i] += 1
			return {"status": 200, "body": {"ok": true}})
		terms[i].api = api
	var code := "console.log('hi');\nawait sleep(500);\nawait api.post('/tally', { n: 1 });\nconsole.log('done');"
	var host_rt: NetScript = rts[0]
	var client_rt: NetScript = rts[1]
	check(client_rt.compile(code).ok, "a client's runner checks the script itself")
	client_rt.start(null)
	await _frames(10)
	check(levels[0].sync.scripts.is_running(terms[0]) and host_rt.is_running() and client_rt.is_running(), "Run on a client runs the script on the host, and both runners show it running")
	check(host_rt.history == [["hi", "log"]] and client_rt.history == [["hi", "log"]], "what it prints shows on every machine")
	check(terms.all(func(t): return t.get_meta("script_code", "") == code), "and the running script is the terminal's saved script everywhere")
	for f in 300:
		await physics_frame
		if not client_rt.is_running():
			break
	await _frames(5)
	check(host_rt.state == ScriptRuntime.State.DONE and client_rt.state == ScriptRuntime.State.DONE and client_rt.history.back() == ["done", "log"],
		"both see it finish")
	check(tallies == [1, 1], "its POST changed the host's building and was replayed on the client's copy (%s)" % [tallies])
	check(client_rt.clock() >= 0.5, "with the host's run time (%.2f s)" % client_rt.clock())
	# Anyone can stop it.
	check(host_rt.compile("while (true) {\n  await sleep(100);\n}").ok, "the host's runner checks a loop")
	host_rt.start(null)
	await _frames(10)
	check(client_rt.is_running(), "a loop the host started runs on the client's screen too")
	client_rt.stop()
	await _frames(10)
	check(not levels[0].sync.scripts.is_running(terms[0]) and host_rt.state == ScriptRuntime.State.STOPPED and client_rt.state == ScriptRuntime.State.STOPPED and client_rt.error.is_empty(),
		"and the client's Stop stops it for everyone")
	# The runner on a client drives the host's run.
	var ed := ScriptEditorUI.new()
	root.add_child(ed)
	ed.open(client_rt, {"code": "console.log('from the runner');"})
	ed.run()
	await _frames(10)
	check(ed.log_text().contains("from the runner") and host_rt.history == [["from the runner", "log"]], "a client's script runner runs on the host and shows its log")
	ed.close()
	ed.queue_free()
	# A teammate who opens the runner mid-run sees the log so far.
	check(client_rt.compile("console.log('first');\nwhile (true) {\n  await sleep(100);\n}").ok, "a client checks a watchdog loop")
	client_rt.start(null)
	await _frames(10)
	var late := ScriptEditorUI.new()
	root.add_child(late)
	late.open(host_rt, {})
	check(late.log_text().begins_with("--- running ---") and late.log_text().contains("first"), "a runner opened mid-run shows the run so far")
	late.stop()
	await _frames(10)
	check(not client_rt.is_running() and late.log_text().contains("--- stopped"), "and its Stop ends it for everyone")
	late.close()
	late.queue_free()
	await _coop_close(worlds)


## Named achievements: a notice when earned, and a list in the lobby.
func test_coop_achievements() -> void:
	print("Co-op: achievements")
	var net := root.get_node("Net")
	var real_profile = net.profile
	Cosmetics.reset()
	var ids := Achievements.LIST.map(func(a): return a.id)
	check(ids.all(func(id): return ids.count(id) == 1 and not Cosmetics.unlocked_by(id).is_empty()),
		"every achievement is one of the unlock ids, each listed once")
	check(Achievements.name_of("achievement:floor_18") == "Filed under F", "floor 18's is called what Augustine approved")
	check(ids.all(func(id): return Achievements.is_secret(id) == (Achievements.hint(id) == "")), "every achievement but a secret says how to earn it")
	net.profile = Profile.new()
	net.profile.earned = ["achievement:floor_18", "secret:roster_thu"]
	var lobby: Control = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	var tabs: TabContainer = lobby.find_child("Customize", true, false)
	var page: Control = lobby.find_child("Achievements", true, false)
	var title := func(id: String) -> String:
		var row := page.find_child("Achievement_" + id, true, false)
		return row.get_node("Name").text if row else ""
	check(tabs.get_tab_title(3) == "Achievements" and title.call("floor_18") == "Filed under F", "the lobby lists what you've earned")
	var g := page.find_child("Achievement_floor_g", true, false)
	check(title.call("floor_g") == Achievements.name_of("achievement:floor_g") + " (locked)" and g.get_node("Hint").text == "Finish the ground floor.",
		"and what you haven't, with how to earn it")
	check(title.call("roster_thu") == Achievements.name_of("secret:roster_thu") and title.call("ending_news") == "" and title.call("mercer_vent_tape") == "",
		"a found secret shows; the others stay hidden")
	lobby.queue_free()
	await process_frame
	# Earning one says its name, then what it unlocks.
	net.profile = Profile.new()
	_game().new_run(21)
	var worlds := await _coop_worlds(1)
	var levels := await _coop_load(worlds, "res://scenes/level_1.tscn")
	_lower_chapters_read(levels)  # about something else: no huddle cuts in
	levels[0].sync.unlock_for([1], "achievement:floor_18")
	check(levels[0].hud._notice.text == Achievements.NOTICE % "Filed under F" + "\nUnlocked: Archive box label", "earning an achievement shows its name, then the sticker it unlocks")
	levels[0].hud._notice.text = ""
	levels[0].sync.unlock_for([1], "achievement:floor_18")
	check(levels[0].hud._notice.text == "", "and only the first time")
	await _coop_close(worlds)
	net.profile = real_profile


func test_coop_unlocks() -> void:
	print("Co-op: unlockable items")
	var net := root.get_node("Net")
	var real_profile = net.profile
	net.profile = Profile.new()
	net.wanted_look = {}
	Cosmetics.reset()
	# Augustine's first ten (plan/approvals/unlocks.md): key, source, name, hint ("" = secret).
	var approved := [
		["notebook/easy_sql", "achievement:book_easy_sql", "Easy SQL cover", "Pick up the crew's first book."],
		["face/reading_glasses", "achievement:easy_sql_half", "Reading glasses", "Finish half of Easy SQL."],
		["top/byte_right_polo", "achievement:easy_sql_done", "Byte-Right polo", "Finish every chapter of Easy SQL."],
		["feet/high_tops", "achievement:first_block", "High-tops", "Block a hit in a real fight."],
		["head/hard_hat", "achievement:floor_g", "Hard hat", "Finish the ground floor."],
		["terminal/amber", "achievement:floor_14", "Amber", "Finish floor 14."],
		["jacket/security", "achievement:floor_22", "Security jacket", "Finish floor 22."],
		["head/mercer_cap", "secret:mercer_vent_tape", "Mercer's cap", ""],
		["walkie/gold", "secret:roster_thu", "Gold", ""],
		["jacket/press", "secret:ending_news", "Press jacket", ""],
		# Floor 18's two (plan/approvals/l3-text.md, 2026-10-21 11:27Z).
		["sticker/archive_label", "achievement:floor_18", "Archive box label", "Finish floor 18."],
		["clip/mercer_floppy", "secret:mercer_floppy_1", "Mercer's floppy", ""],
	]
	var rows_ok := approved.all(func(r):
		var it := Cosmetics.info(r[0].get_slice("/", 0), r[0].get_slice("/", 1))
		return it.get("unlock") == r[1] and it.get("name") == r[2] and str(it.get("hint", "")) == r[3] and Cosmetics.is_secret(it) == (r[3] == ""))
	check(rows_ok, "the approved items are in the catalogue with their sources, names and hints; secrets have no hint")
	check(approved.all(func(r): return not net.profile.has_item(r[0])), "nobody starts with them, the hard hat included")
	# The notebook's sticker and clip go on any cover.
	var fresh := Cosmetics.default_loadout(0)
	check(fresh.sticker.item == "none" and fresh.clip.item == "none", "the notebook starts with no sticker and no clip")
	var owner := Profile.new()
	owner.earned = ["achievement:book_easy_sql", "achievement:floor_18", "secret:mercer_floppy_1"]
	var dressed := Cosmetics.clean(Cosmetics.trim({"notebook": {"item": "easy_sql"}, "sticker": {"item": "archive_label"}, "clip": {"item": "mercer_floppy"}}, owner), 0)
	check(dressed.notebook.item == "easy_sql" and dressed.sticker.item == "archive_label" and dressed.clip.item == "mercer_floppy",
		"the box label and the floppy go on the Easy SQL cover together")
	var lobby: Control = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	var sticker_row: Control = lobby.find_child("Item_sticker", true, false).get_parent()
	check(sticker_row.visible == ("archive_label" in CharacterLooks.TOOL_ITEMS.get("sticker", [])), "the Sticker row shows once Graphics can draw a sticker")
	var texts := func(on: Control, slot: String) -> Array:
		var l: OptionButton = on.find_child("Item_" + slot, true, false)
		return range(l.item_count).map(func(i): return l.get_item_text(i))
	var hats: OptionButton = lobby.find_child("Item_head", true, false)
	var hat: int = texts.call(lobby, "head").find("Hard hat (locked)")
	check(hat >= 0 and hats.is_item_disabled(hat) and hats.get_item_tooltip(hat) == "Finish the ground floor.", "a locked item shows its hint in the lobby")
	check(texts.call(lobby, "terminal").has("Amber (locked)") and not texts.call(lobby, "walkie").has("Gold") and not texts.call(lobby, "head").any(func(t): return t.begins_with("Mercer")),
		"secret items don't show at all")
	lobby.queue_free()

	# In a level, the host unlocks for everyone there.
	_game().new_run(13)
	var worlds := await _coop_worlds(1)
	var levels := await _coop_load(worlds, "res://scenes/level_1.tscn")
	_lower_chapters_read(levels)  # about something else: no huddle cuts in
	levels[1].sync.unlock("achievement:floor_g")
	await _frames(10)
	check(not net.profile.has_item("head/hard_hat"), "a client can't hand out unlocks")
	levels[0].sync.unlock("achievement:floor_g")
	var host_profile: Profile = net.profile
	net.profile = Profile.new()  # the test's machines share one Net, so give the client its own save
	await _frames(10)
	check(host_profile.has_item("head/hard_hat") and net.profile.has_item("head/hard_hat"), "finishing the ground floor unlocks the hard hat for every player")
	check(levels[0].hud._notice.text == (Achievements.NOTICE % Achievements.name_of("achievement:floor_g") + "\nUnlocked: Hard hat") and levels[1].hud._notice.text == (Achievements.NOTICE % Achievements.name_of("achievement:floor_g") + "\nUnlocked: Hard hat"), "and each of them is told")
	levels[0].hud._notice.text = ""
	levels[0].sync.unlock("achievement:floor_g")
	await _frames(5)
	check(levels[0].hud._notice.text == "", "earning it again says nothing")
	# What one player does themselves unlocks for them alone.
	var client_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()
	host_profile = Profile.new()
	net.profile = host_profile
	levels[0].hud._notice.text = ""
	levels[1].hud._notice.text = ""
	levels[1].sync.unlock_for([client_id], "achievement:easy_sql_half")
	levels[0].sync.unlock_for([client_id], "achievement:easy_sql_half")
	var client_profile := Profile.new()
	net.profile = client_profile
	await _frames(5)
	check(client_profile.has_item("face/reading_glasses") and levels[1].hud._notice.text == (Achievements.NOTICE % Achievements.name_of("achievement:easy_sql_half") + "\nUnlocked: Reading glasses"),
		"the client who finished half the book unlocks the reading glasses")
	check(not host_profile.has_item("face/reading_glasses") and levels[0].hud._notice.text == "", "and the host, who didn't, doesn't")
	net.profile = host_profile
	levels[1].hud._notice.text = ""
	levels[0].sync.unlock_for([1], "achievement:first_block")
	net.profile = Profile.new()
	await _frames(5)
	check(host_profile.has_item("feet/high_tops") and levels[0].hud._notice.text == (Achievements.NOTICE % Achievements.name_of("achievement:first_block") + "\nUnlocked: High-tops")
		and not net.profile.has_item("feet/high_tops") and levels[1].hud._notice.text == "", "the host's own block unlocks the high-tops for the host alone")
	Cosmetics.catalogue.append({"slot": "walkie", "item": "undrawn_x", "name": "Test undrawn", "unlock": "achievement:test_undrawn"})
	levels[1].hud._notice.text = ""
	levels[0].sync.unlock_for([client_id], "achievement:test_undrawn")
	net.profile = Profile.new()
	await _frames(5)
	check(net.profile.has_item("walkie/undrawn_x") and levels[1].hud._notice.text == "",
		"an item Graphics can't draw yet is owned quietly, ready for when it can")
	Cosmetics.reset()
	await _coop_close(worlds)
	# Picking a skin that comes in a color uses it.
	net.profile = Profile.new()
	net.profile.earned = ["achievement:floor_14"]
	lobby = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	var screens: OptionButton = lobby.find_child("Item_terminal", true, false)
	var amber: int = texts.call(lobby, "terminal").find("Amber")
	screens.select(amber)
	screens.item_selected.emit(amber)
	await process_frame
	check(lobby.my_look().terminal.item == "amber" and net.terminal_color(1) == CharacterLooks.FIXED_COLORS["terminal/amber"]
		and not lobby.find_child("Color_terminal", true, false).visible, "picking the amber terminal makes the screen amber, a finish with no color to pick")
	var caps: OptionButton = lobby.find_child("Item_head", true, false)
	net.profile.earned.append("secret:mercer_vent_tape")
	lobby.queue_free()
	lobby = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	caps = lobby.find_child("Item_head", true, false)
	var cap: int = texts.call(lobby, "head").find("Mercer's cap")
	caps.select(cap)
	caps.item_selected.emit(cap)
	await process_frame
	check(lobby.my_look().head == {"item": "mercer_cap", "color": CharacterLooks.ITEM_COLORS["head/mercer_cap"]} and lobby.find_child("Color_head", true, false).visible,
		"a found secret shows up in the lobby, starting in its own color")
	lobby.queue_free()
	net.looks = {}
	net.wanted_look = {}
	net.profile = real_profile
	_game().new_run(6)


func test_coop_sitting() -> void:
	print("Co-op: teammates see you sit")
	_game().new_run(12)
	var worlds := await _coop_worlds(1)
	var levels := await _coop_load(worlds, "res://scenes/level_1.tscn")
	_lower_chapters_read(levels)  # about something else: no huddle cuts in
	var c_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()
	var sitter: Player = levels[1].player
	var seen: PlayerPuppet = levels[0].players.puppet(c_id)
	await _frames(20)
	# A chair right where they stand, its seat 0.45 m up.
	var top := sitter.global_position + Vector3(0, 0.45, 0)
	var chair := Seat.create_at(levels[1], top, sitter.rotation.y)
	check(sitter.sit(chair), "the client sits on a chair")
	await _frames(40)
	var hip: Vector3 = seen.rig.joints["r_hip"].global_position
	check(seen.sitting == PlayerPuppet.Sit.CHAIR and seen.rig.action == "sit", "the host sees them sitting on it")
	check(absf(hip.y - (top.y + PlayerPuppet.SEAT_THIGH)) < 0.08, "with their hips on the seat, not floating above it (%.2f m off)" % (hip.y - top.y - PlayerPuppet.SEAT_THIGH))
	sitter.stand_up(true)
	await _frames(20)
	check(seen.sitting == PlayerPuppet.Sit.NONE and seen.rig.action == "idle" and seen.find_child("Body", false, false).position.y == 0.0, "and back on their feet when they stand up")
	check(sitter.sit(null), "the client sits on the floor")
	await _frames(20)
	check(seen.sitting == PlayerPuppet.Sit.FLOOR and seen.find_child("Body", false, false).position.y == 0.0
		and seen.rig.action == "sit_floor", "the host sees them sitting on the floor where they are")
	sitter.stand_up(true)
	chair.queue_free()
	await _coop_close(worlds)


func test_coop_world() -> void:
	print("Co-op: the World with a host and a client")
	_game().new_run(9)
	var worlds := await _coop_worlds(1)
	var machines := await _coop_load(worlds, "res://scenes/world.tscn")
	_lower_chapters_read(machines)  # about something else: no huddle cuts in
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

	lobby_h.sync.event("_leave_lobby")
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
	sra_c.terminal_ui.run("UPDATE doors SET locked = 0, actuator_fault = 0 WHERE id = 'SRA-EXIT'")
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
	_lower_chapters_read(m)  # about something else: no huddle cuts in
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
	check(c.visitor_log.enabled, "the visitor log can be signed as soon as the crew is in, without waiting on Rourke")
	for f in 3000:
		await physics_frame
		if c.sync._gates.has("inside"):
			break
	check(h.sync._gates.has("inside") and c.sync._gates.has("inside"), "a crew walking in one at a time all counts as inside")
	check(c.badges.enabled and c.badges.models.filter(func(n): return n.visible).size() == 2, "a visitor badge for each of the crew waits on the counter")
	c.visitor_log.interact(m[1].player)
	c.badges.interact(m[1].player)
	for f in 600:
		await physics_frame
	check(h.visitor_log.taken_by.size() == 1 and c.badges.taken_by.size() == 1 and not c.desk_terminal.enabled, "one player checked in isn't enough: everyone signs and takes a badge")
	var inv: Inventory = m[1].player.inventory
	check(inv.has("visitor_badge") and not inv.hotbar.has("visitor_badge"), "the badge you take is clipped on rather than on the hotbar")
	inv.remove("visitor_badge")  # both machines share one test process (and Game's inventory)
	c.visitor_log.interact(m[1].player)
	await _frames(10)
	check(h.visitor_log.taken_by.size() == 1, "signing twice still counts once")
	h.visitor_log.interact(m[0].player)
	h.badges.interact(m[0].player)
	_crew_reads([h, c])  # the garage flashback before the desk terminal
	for f in 4000:
		await physics_frame
		if c.desk_terminal.enabled:
			break
	check(h.to_local(h.rourke.global_position).z < 3.0, "Rourke makes it through the front doors to the desk")
	check(h.desk_terminal.enabled and c.desk_terminal.enabled, "once everyone is signed in and badged, the story carries on for everyone")
	check(_game().visitor_badge_no == "VIS-02" and h.badges.taken_by.size() == 2, "badges are numbered in the order they're taken: VIS-01, VIS-02")
	check(h.walkies.enabled and c.walkies.enabled and not m[0].player.inventory.has("radio"), "the walkie-talkies are there to take, but nobody has to")
	await _coop_close(worlds)


func test_coop_level_2() -> void:
	print("Co-op: Level 2 with a host and a client")
	_game().new_run(5)
	_game().rourke_fate = "killed"  # just the security section: Rourke turned before it
	var worlds := await _coop_worlds(1)
	var machines := await _coop_load(worlds, "res://scenes/level_2.tscn")
	_books_read(machines)  # about something else: no huddle cuts in
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
	for l in machines:  # one process plays every machine: give each its own inventory, as on real machines
		l.player.inventory = Inventory.new()
	var drivers: int = host.players.count()
	client.geo.get_node("Screwdriver").interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return l.has_screwdriver and l.screwdrivers.models.filter(func(m): return m.visible).size() == drivers - 1), "a client takes one screwdriver, and everyone sees one gone from the row")
	check(client.player.inventory.has("screwdriver") and not host.player.inventory.has("screwdriver"), "and it's in the taker's inventory, not everyone's")
	host.vent_grate.interact(host.player)
	await _frames(10)
	check(machines.all(func(l): return l.vent_grate.enabled), "someone without a screwdriver can't take the grate off")
	client.vent_grate.interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return not l.vent_grate.enabled), "the grate comes off on every machine")

	check(machines.all(func(l): return l.stair_door.locked and not l.exit_lift.button.enabled), "the stairs are locked and the lift is dead")
	client.type_pin("exit", host.data.pin, client.player)
	await _frames(10)
	check(machines.all(func(l): return l.pin_entered and not l.door_open), "the stairwell PIN goes through for everyone, and the door still jams")
	client.breakers[host.data.breaker].interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return l.door_open and l.doors["SEC-EXIT"].is_open), "a client's breaker reset opens SEC-EXIT for everyone")
	await _frames(100)
	for l in machines:
		l.completed.disconnect(l._on_completed)
	check(machines.all(func(l): return not l.stair_door.locked), "with SEC-EXIT open, the stair door unlocks for everyone")
	client.player.global_transform = Transform3D(Basis(), client.to_global(STAIRS))
	await _frames(20)
	check(not client.player.input_locked, "one player on the stairs isn't the whole team")
	client.seal_button.interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return not l.doors["SEC-EXIT"].is_open), "a client can lock SEC-EXIT behind the team")
	host.player.input_locked = false
	host.player.global_transform = Transform3D(Basis(), host.to_global(STAIRS + Vector3(-0.6, 0, -0.4)))
	await _frames(20)
	check(machines.all(func(l): return l.player.input_locked), "with everyone on the stairs, the wing ends on every machine")
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
	print("Level 2 hints")
	var l2 = load("res://scripts/levels/level_2.gd").new()
	var ok := true
	for s in 20:
		var d := FacilityDB.new()
		var data := Level2Data.build(s)
		d.load_seed(data.sql)
		for p in [l2.pike_puzzle, Puzzle.new("har", l2.har_puzzle.solution_sql, ["pin"], false, l2.pin_hints(data.badge))]:
			ok = ok and p.matches(d, d.execute(_hint_query(p.hints[-1]))) and not p.matches(d, d.execute(_hint_query(p.hints[0])))
	check(ok, "pike and the PIN: the last hint's query solves it on every seed, the first hint's shape doesn't")
	var shapes := true
	for p in [l2.pike_puzzle, Puzzle.new("har", "", [], false, l2.pin_hints("G-123")), l2.door_puzzle, Level2Lab.door_puzzle_for("E")]:
		shapes = shapes and _hint_query(p.hints[0]).contains("?") and p.hints.size() == 3 and not _hint_query(p.hints[-1]).contains("?")
	check(shapes, "first hints give the query's shape with the value as ?, the last hint the exact query")
	check(_hint_query(l2.pin_hints("G-123")[1]).contains("badge_log ORDER BY time"), "the PIN's second hint shows how to find the badge")
	check(_hint_query(l2.cameras_puzzle.hints[0]) == "GET /cameras", "cameras: first hint is GET /cameras (nothing to find)")
	check(_hint_query(l2.door_puzzle.hints[-1]) == "GET /doors/SEC-EXIT", "door: last hint is GET /doors/SEC-EXIT")
	l2.free()


## The badge readers' log leads to the PIN: its last guard badge through SEC-EXIT
## is the night lead, and that badge finds them in guards. The Har sheet and the
## briefing room's roster are other ways to the same guard.
func test_level_2_badge_route() -> void:
	print("Level 2 badge log to the PIN")
	var l2 = load("res://scripts/levels/level_2.gd").new()
	var pin: Puzzle = l2.har_puzzle
	var ok := true
	var unsorted_misleads := true
	var badges := {}
	for s in 50:
		var data := Level2Data.build(s)
		var d := FacilityDB.new()
		d.load_seed(data.sql)
		var exits := d.run_silent("SELECT * FROM badge_log WHERE door = 'SEC-EXIT' ORDER BY time")
		var lead: Dictionary = exits[-1]
		ok = ok and lead["badge_id"] == data.badge and str(lead["badge_id"]).begins_with("G-") and lead["holder"] == "SECURITY STAFF"
		var guard := d.run_silent("SELECT * FROM guards WHERE badge_id = '%s'" % data.badge)
		ok = ok and guard.size() == 1 and guard[0]["name"] == data.name and guard[0]["pin"] == data.pin and guard[0]["shift"] == "night"
		ok = ok and pin.matches(d, d.execute("SELECT * FROM guards WHERE badge_id = '%s'" % data.badge))
		ok = ok and pin.matches(d, d.execute("SELECT pin FROM guards WHERE name = '%s'" % data.name))
		ok = ok and pin.matches(d, d.execute("SELECT * FROM guards WHERE name LIKE 'Har%' AND shift = 'night'"))
		for wrong in data.decoy_badges:
			ok = ok and wrong != data.badge and not pin.matches(d, d.execute("SELECT * FROM guards WHERE badge_id = '%s'" % wrong))
			var g := d.run_silent("SELECT shift, note FROM guards WHERE badge_id = '%s'" % wrong)
			ok = ok and g.size() == 1 and g[0]["shift"] != "night" and str(g[0]["note"]).contains("Clocked out")
		# Read as stored, the last SEC-EXIT swipe is someone who went home.
		var stored := d.run_silent("SELECT * FROM badge_log WHERE door = 'SEC-EXIT'")
		unsorted_misleads = unsorted_misleads and stored[-1]["badge_id"] != data.badge
		# The roster board names the lead with the same badge; the others are crossed out.
		var roster: Array = data.roster
		ok = ok and roster[0] == [data.name, data.badge, "LEAD"] and roster.slice(1).all(func(r): return r[2] != "LEAD" and d.run_silent("SELECT * FROM guards WHERE badge_id = '%s' AND name = '%s'" % [r[1], r[0]]).size() == 1)
		badges[data.badge] = true
	l2.free()
	check(ok, "the last guard badge through SEC-EXIT is the night lead's, and guards finds their PIN by badge, by name or by Har, on every seed")
	check(unsorted_misleads, "without ORDER BY, the last SEC-EXIT row stored is the wrong guard")
	check(badges.size() >= 10, "the lead's badge varies between runs (%d badges)" % badges.size())
	# Vale's swipe matches the server floor's syslog: she was in her lab at 23:12.
	var d2 := FacilityDB.new()
	d2.load_seed(Level2Data.build(3).sql)
	check(d2.run_silent("SELECT * FROM badge_log WHERE badge_id = 'V-0042' AND door = 'SECLAB-B' AND time LIKE '%23:12'").size() == 1, "badge_log has Vale into Secure Lab B at 23:12, as the server floor's syslog says")


func test_level_2_scene() -> void:
	print("Level 2 scene")
	_game().new_run(11)
	_game().rourke_fate = "killed"  # just the security section: Rourke turned before it
	var level = load("res://scenes/level_2.tscn").instantiate()
	root.add_child(level)
	_books_read([level])  # about something else: no huddle cuts in
	for i in 30:
		await physics_frame
	var w: Watcher = level.watcher
	var p: Player = level.player
	check(level.doors["SEC-EXIT"].is_open == false, "stairwell exit starts locked")
	check(level.doors["SEC-OFFICE"].is_open == false, "the Security Office door starts locked")
	check(w.is_on_floor() and not w.active, "the Watcher waits in the office")
	# The side rooms hold leads: Rourke's blank statement, and tonight's roster.
	var statement: Node = _doc(level, "Incident statement")
	var roster: Node = _doc(level, "Night shift roster")
	check(statement != null and statement.plain_text().contains("at __:__") and statement.plain_text().contains("night desk") and AABB(Vector3(-16, -1, 4), Vector3(6, 4, 4)).has_point(level.to_local(statement.global_position)),
		"the interview room's table has Rourke's statement, the time left blank")
	check(roster != null and roster.plain_text().contains(level.data.name + "  " + level.data.badge) and AABB(Vector3(-16, -1, -10), Vector3(6, 4, 6)).has_point(level.to_local(roster.global_position)),
		"the briefing room's board lists the night lead's name by their badge")
	var pin_last: String = _hint_query(level.har_puzzle.hints[-1])
	check(pin_last.contains("'%s'" % level.data.badge) and level.har_puzzle.matches(level.db, level.db.execute(pin_last)),
		"the PIN's last hint, as this run shows it, names this run's badge and solves it (%s)" % pin_last)
	check(level.find_children("CableCoil", "", true, false).is_empty(), "the lab has no cable of its own")
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
	check(level.stair_door.locked, "the stair door stays locked until SEC-EXIT opens")
	level._on_breaker(null, level.data.breaker)
	for i in 5:
		await physics_frame
	check(level.doors["SEC-EXIT"].is_open and level.door_open and level.door_puzzle.solved, "resetting the right breaker opens the door")
	check(level.db.run_silent("SELECT sensor FROM door_status WHERE door_id = 'SEC-EXIT'")[0]["sensor"] == "open", "the sensor now agrees")
	for i in 100:
		await physics_frame
	check(not level.stair_door.locked and not level.exit_lift.button.enabled, "with SEC-EXIT open, the stair door unlocks; the lift beside it stays dead")
	check(level.stair_door.name.ends_with("STAIR-1-22"), "it's the floor 22 stairwell")
	level.seal_exit()
	for i in 5:
		await physics_frame
	check(not level.doors["SEC-EXIT"].is_open and _game().watcher_sealed, "the PIN locks it behind you")
	level.completed.disconnect(level._on_completed)
	for i in 20:  # let WARDEN's line about the jammed door finish first
		if level.hud._subtitle.text == "":
			break
		await create_timer(0.5).timeout
	p.global_transform = Transform3D(Basis(), level.to_global(STAIRS))
	for i in 10:
		await physics_frame
	check(p.input_locked, "on the stairs, the wing is done")
	await create_timer(1.6).timeout
	var taps: Array = level.geo.get_meta("sounds_played", []).filter(func(x): return x.kind == "tap")
	check(taps.size() == 1 and taps[0].pos == level.SEC_EXIT_FRAME and level.hud._subtitle.text == "",
		"leaving, there's one tap on the metal behind SEC-EXIT, and no narration (%d taps, subtitle \"%s\")" % [taps.size(), level.hud._subtitle.text])
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
	_books_read([level])  # about something else: no huddle cuts in
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
	# (Papers lying on a table, like Rourke's statement, are picked up to be read.)
	for d in docs.filter(func(d): return d.read_face != Vector3.UP):
		var wall_sheet: Node3D = d.get_node_or_null("WallSheet")
		var printed: Array = wall_sheet.find_children("Line*", "Label3D", false, false) if wall_sheet else []
		var shown := " ".join(printed.map(func(l): return l.text))
		if d.is_form():
			check(wall_sheet != null and wall_sheet.get_node_or_null("Print") != null, "%s is on the wall as its detailed page" % d.title)
			continue
		check(wall_sheet != null and d.lines().all(func(l): return l.text == "" or shown.contains(l.text) or wall_sheet.find_child("Title", false, false).text == l.text), "%s is on the wall with all its words" % d.title)
		check(printed.all(func(l): return l.font_size >= 20), "%s is printed big enough to read" % d.title)
	# Nothing pinned to a wall overlaps anything else on it, Graphics' posters included.
	var pinned: Array = docs.filter(func(d): return d.has_node("WallSheet"))
	pinned.append_array(level.find_children("Poster*", "Node3D", true, false))
	var clash := []
	for i in pinned.size():
		for j in range(i + 1, pinned.size()):
			if _flat_overlap(_visual_box(pinned[i]), _visual_box(pinned[j])):
				clash.append("%s / %s" % [pinned[i].name, pinned[j].name])
	check(clash.is_empty(), "papers and posters on the walls don't overlap %s" % [clash])
	var facing := func(title: String) -> float:
		var on_wall: Node3D = docs[titles.find(title)].get_node("WallSheet")
		var label: Node3D = on_wall.find_child("Line0", false, false)
		if label == null:
			label = on_wall.get_node("Print")
		return label.global_basis.z.z  # Label3D and the print read from their +Z side
	check(facing.call("NIGHT SHIFT SIGN-IN      DATE: 10/15") < -0.9 and facing.call("Lockdown PIN policy") > 0.9, "wall papers face into the corridor, not into the wall")
	# The break-glass box on the landing: the safe place to learn both.
	check(level.key_glass.get_prompt(p).contains("Strike") and level.ledge_glass.get_prompt(p).contains("Strike"), "breakable glass says to strike it")
	check(level.spawn_point().origin.distance_to(level.key_glass.global_position) < 5.0, "the first breakable glass is on the landing, by the arrival elevator")
	var box_at: Vector3 = level.to_local(level.geo.get_node("KeyBox").global_position)
	check(absf(box_at.z - 8.0) > 0.9 + 0.25, "the break-glass box hangs on the landing's wall, not in the doorway to the night desk")
	# Vent: the grate is screwed shut until someone finds the screwdriver.
	level._on_vent_grate(p)
	await process_frame
	check(is_instance_valid(level.vent_grate) and not level.has_screwdriver, "the vent grate won't come off by hand")
	level.key_glass.take_hit(p)
	await process_frame
	var sd: ItemDock = level.screwdrivers
	check(not is_instance_valid(level.key_glass) and sd.get_prompt(p) == "[E] Take a screwdriver", "strike the box's glass and the screwdrivers are there")
	check(sd.models.filter(func(m): return m.visible).size() == level.players.count(), "one each")
	check(level.spare_walkies.models.filter(func(m): return m.visible).size() == level.players.count(), "and the night desk has spare walkies")
	sd.interact(p)
	await process_frame
	check(p.inventory.has("screwdriver") and sd.get_prompt(p) == sd.already, "take one and the row won't give you a second")
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
	check(level.wind.playing and level.wind.volume_db > -12.0, "out on the ledge the wind is loud (%.0f dB)" % level.wind.volume_db)
	check(absf(p.head.rotation.z) > 0.0005, "and the view sways a little")
	# A step off the edge, 80 m up, is the end of that player: they come to at the floor's checkpoint.
	p.state = Player.Move.WALK  # off the ledge, a step clear of it
	p._ledge = null
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(9.0, 0.5, -2.0)))
	p.velocity = Vector3.ZERO
	check(await _until(func(): return p.health == 100.0 and [level.spawn_point().origin, level.to_global(Vector3(0, 0.1, -10.8))].any(func(c): return p.global_position.distance_to(c) < 1.5), 15.0), "falling off the ledge kills you, and you come to back inside")
	check(await _until(func(): return level.hud._notice.text == level.FALL_NOTICE, 5.0), "and the notice says how you got there")
	check(await _until(func(): return not level.wind.playing, 10.0) and absf(p.head.rotation.z) < 0.002, "back inside, the wind dies away and the view is level")
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
	_books_read([level])  # about something else: no huddle cuts in
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
	root.get_node("Net").profile.earned.erase("achievement:floor_22")
	p.global_transform = Transform3D(Basis(), level.to_global(STAIRS))
	await create_timer(6.0).timeout
	var card: Node = level.get_node_or_null("EndCard")
	check(card != null and card.find_children("*", "Label", true, false).any(func(l): return l.text == "To be continued."), "down the stairs, a black card reads \"To be continued.\"")
	check(root.get_node("Net").profile.earned.has("achievement:floor_22"), "finishing floor 22 earns its achievement")
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
	_books_read([sec])  # about something else: no huddle cuts in
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
	var lab_hints: Array = Level2Lab.door_puzzle_for("E").hints
	check(lab_hints[0].contains("WHERE zone = '?'") and not lab_hints[0].contains("'E'") and lab_hints[0].contains("AND status = 'fault'"), "the first hint is the query's shape, the zone left as ?, a line per keyword")
	check(lab_hints[-1].contains("WHERE zone = 'E' AND status = 'fault'"), "the last hint is the exact query")


## Wait up to `seconds` (game time) for `cond`.
func _until(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0 / Engine.time_scale)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			return false
		await physics_frame
	return true


## A node's drawn extent in world space: every mesh and label under it.
func _visual_box(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for v in n.find_children("*", "VisualInstance3D", true, false) + ([n] if n is VisualInstance3D else []):
		var b: AABB = v.global_transform * v.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Two things hung on a wall overlap: they share more than a few mm of the wall,
## whatever their depth off it (a poster's frame stands proud of a taped sheet).
func _flat_overlap(a: AABB, b: AABB) -> bool:
	var thin := 0.1
	for k in 3:
		var lo := maxf(a.position[k], b.position[k])
		var hi := minf(a.end[k], b.end[k])
		if a.size[k] < thin and b.size[k] < thin:
			if hi < lo - thin:  # on different walls
				return false
		elif hi - lo < 0.004:
			return false
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
	var r_at: Vector3 = level.to_local(r.global_position)
	check(r_at.z < level.to_local(lab.reader.global_position).z - 0.8 and r_at.z < -0.9, "he waits past the door, so the reader is on the crew's side of him, not behind him")
	check(p.inventory.has("visitor_badge") and _game().visitor_badge_no == "VIS-01", "started on its own, Level 2 clips a visitor badge on the player")
	p.inventory.remove("visitor_badge")
	lab.reader.interact(p)
	await _frames(3)
	check(lab.badged.is_empty() and level.db.run_silent("SELECT * FROM badge_log WHERE badge_id LIKE 'VIS-%'").is_empty(), "with no visitor badge on, the reader logs nothing")
	check(level.hud._notice.text == Level2Lab.DENIED_NO_BADGE, "and the reader says why: access denied, no badge read")
	p.inventory.add("visitor_badge")
	lab.reader.interact(p)
	await _frames(3)
	var swipes: Array = level.db.run_silent("SELECT * FROM badge_log WHERE door = 'SECLAB-B' AND badge_id LIKE 'VIS-%'")
	check(swipes.size() == 1 and str(swipes[0]["time"]).begins_with("1997-10-16"), "the swipe is in badge_log: the crew's own badge, at her door, tonight")
	check(swipes.size() == 1 and swipes[0]["badge_id"] == _game().visitor_badge_no, "the reader logs the number on the player's own badge")
	check(await _until(func(): return level.doors["SECLAB-B"].is_open, 10.0), "once everyone has badged, the door opens")
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(-12.5, 0.1, 1.5)))
	check(await _until(func(): return lab.phase == "locked", 40.0), "with everyone inside and Rourke out, the door locks")
	check(level.doors["SECLAB-B"].is_open == false and lab.terminal.locked, "locked in, and her terminal is locked too")
	check(await _until(func(): return level.hud._subtitle.text.contains("Easy SQL"), 40.0), "after the radio call, he gloats through the glass")
	check(await _until(func(): return level.hud._subtitle.text.contains("Nothing personal"), 40.0), "and signs off before he walks away")
	check(await _until(func(): return lab.phase == "fight", 60.0), "he comes back in through the rear door")
	check(not level.doors["SECLAB-B-REAR"].is_open, "and the rear door shuts behind him")
	if outcome == "tied":
		await _check_crew_beaten(level, lab, p, r)
	check(level.player.combat.crew == level.crew and r.wounds.shown() == 0, "he starts the fight unhurt")
	p.health = 100000.0  # this test is about what happens to him
	for i in 30:
		if r.state == Rourke.State.DOWN:
			break
		r.take_hit(p)
		await _frames(2)
	check(r.state == Rourke.State.DOWN, "struck enough times, he goes down")
	check(r.wounds.shown() == Injuries.SPOTS.size(), "beaten, every wound shows on him")
	check(r.get_prompt(p) == "[X] Finish it", "with no cable, there's no way to tie him up")
	r.interact(p)
	check(r.state == Rourke.State.DOWN, "and pressing E does nothing")
	match outcome:
		"killed":
			r.interact_alt(p)
		"tied":
			lab.cable_holders[level.players.id_of(p)] = true  # carried up from the server floor
			check(r.get_prompt(p).contains("Tie him up"), "carrying cable from the server floor, you can tie him up")
			r.interact(p)
		"untied":
			pass
	check(await _until(func(): return lab.fate == outcome, 30.0), "Rourke's fate: %s" % outcome)
	check(_game().rourke_fate == outcome, "the game remembers it, from Level 2")
	check(await _until(func(): return lab.switches.values().all(func(s): return s.enabled) and not lab.terminal.locked, 60.0), "the lockdown starts, and her terminal opens on Rourke's badge")
	var h := _huddle_of(level)
	check(await _until(func(): return h.chapter.get("id", "") == "easy_sql_9", 20.0) and lab.response_left < 0.0, "before the clock starts, the book's review comes back: Under pressure")
	await _crew_reads([level])
	check(await _until(func(): return lab.response_left > 0.0, 20.0) and h.done.has("easy_sql_9"), "then the security response is sent")
	check(_game().current_todo() != "" and not _game().current_todo().contains(level.data.lab_answer) and not _game().current_todo().contains(level.data.lab_zone + "'"), "the to-do names no answer (%s)" % _game().current_todo())
	var screen_text := "\n".join(lab.terminal.transcript)
	check(not screen_text.contains("ORDER BY") and screen_text.contains("badge_log"), "the lockdown screen names badge_log but doesn't give the query")
	check(screen_text.contains("[lb]SYSOP[rb]: two conditions?"), "the two-conditions tip is SYSOP's, not the system's")
	check(lab.response_left > Level2Lab.RESPONSE_TIME - 5.0 and lab.clock.text.begins_with("RESPONSE  "), "WARDEN sends a security response, and the clock over the door counts down")
	check(_game().current_case() == "lab_door" and _game().case_info("lab_door").title == Level2Lab.LAB_CASE, "the lockdown opens the lab door's case page")
	if outcome == "killed":
		# Too slow: the response arrives, and the lab's controllers are re-keyed.
		var old_zone: String = level.data.lab_zone
		lab._card._note_clues()
		check(_game().case_info("lab_door").clues.any(func(k): return k.text.contains("zone " + old_zone)), "reading the lab's door card notes its zone")
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
		var lab_page: Array = _game().case_info("lab_door").clues
		check(lab_page.any(func(k): return k.text.contains("re-keyed")) and not lab_page.any(func(k): return k.text.contains("'%s'" % old_zone) or k.text.contains("zone " + old_zone)),
			"the case page says the zone changed, and nothing on it names the old zone")
		lab._card._note_clues()
		check(_game().case_info("lab_door").clues.any(func(k): return k.text.contains("zone " + new_zone)), "the card read again notes the new one")
	level.terminal_ui.terminal = lab.terminal
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = '%s'" % level.data.lab_zone)
	check(not lab.door_puzzle.solved, "the zone alone isn't enough")
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % level.data.lab_zone)
	check(lab.door_puzzle.solved, "zone AND status finds the lab door's controller")
	check(_game().case_info("lab_door").clues.any(func(k): return k.text.contains(level.data.lab_answer)), "SYSOP's answer goes on the lab door's page")
	level.terminal_ui.run("SELECT * FROM badge_log ORDER BY time")
	check(lab.log_puzzle.solved, "ORDER BY time lays out the visitor log")
	var wrong: String = lab.switches.keys().filter(func(k): return k != level.data.lab_answer)[0]
	lab.switches[wrong].interact(p)
	await _frames(3)
	check(not level.doors["SECLAB-B"].is_open, "the wrong switch doesn't open the door")
	lab.switches_locked_until = 0.0
	lab.switches[level.data.lab_answer].interact(p)
	check(await _until(func(): return level.doors["SECLAB-B"].is_open, 5.0), "the right switch resets it, and the door opens")
	check(_game().case_info("lab_door").solved and _game().case_info("lab_door").how.contains(level.data.lab_answer), "and the lab door's case is solved")
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


## Solo, Rourke downs the player, which is the whole crew: the news says the frame
## worked, then the fight starts over in the lab.
func _check_crew_beaten(level: Node, lab: Level2Lab, p: Player, r: Rourke) -> void:
	r.hits_left -= 2
	await _frames(2)
	check(r.wounds.shown() > 0 and r.wounds.speed_scale() < 1.0, "hit, he shows it: torn jacket, blood, a limp")
	p.health = 10.0
	check(await _until(func(): return level.get_node_or_null("NewsEnding") != null, 20.0), "he downs the crew, and the morning paper comes up")
	var news: NewsEnding = level.get_node("NewsEnding")
	check(news.paper != null and NewsEnding.HEADLINE.contains("IT CONTRACTORS"), "the frame worked: the paper says the crew killed her")
	check(lab.phase == "fight" and _game().rourke_fate == "unknown", "the story doesn't move on")
	var net = root.get_node("Net")
	net.profile.earned.erase("secret:ending_news")
	news.skip()
	check(await _until(func(): return level.get_node_or_null("NewsEnding") == null and p.health == 100.0, 20.0), "then you come to, healed")
	check(await _until(func(): return net.profile.earned.has("secret:ending_news"), 5.0), "seeing the news ending earns its secret")
	check(_in_lab_room(level, p) and r.hits_left == r.max_hits and r.wounds.shown() == 0, "back in the lab, and the fight starts over with him unhurt")
	await _frames(30)


## Co-op fighting: the client's own machine blocks, goes down and gets helped up.
## The Custodian in co-op: the host runs it, its grab lands on the client's own
## machine, a teammate's strike or a power cut (run on every machine) frees them,
## and a client's strike reaches the host.
func test_coop_custodian() -> void:
	print("Co-op: the Custodian")
	_game().new_run(4)
	var worlds := await _coop_worlds(1)
	var machines := await _coop_load(worlds, "res://scenes/level_1.tscn")
	var host = machines[0]
	var client = machines[1]
	var client_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()
	var puppet: Node3D = host.players.puppet(client_id)
	# On the far side of the client from the host, so the client is the nearest.
	var away: Vector3 = puppet.global_position - host.player.global_position
	away.y = 0.0
	var at: Vector3 = puppet.global_position + (away.normalized() if away.length() > 0.1 else Vector3.RIGHT) * 1.2
	var bots := []
	for l in machines:
		var c := Custodian.new()
		c.name = "Custodian"
		c.position = l.to_local(at)
		l.add_child(c)
		c.set_bay(at + Vector3(0, 0, -40))  # far off: this test is about the grab, not the bay
		l.sync.replicate(c, c.sync_properties())
		bots.append(c)
	host.sync._synchronizers.back().set_visibility_for(client_id, true)  # a level's net_setup does this at the start
	var hc: Custodian = bots[0]
	var cc: Custodian = bots[1]
	host.sync.run_on(hc, "activate", [])
	check(await _until(func(): return client.player.combat.grabbed_by == cc, 4.0), "the host's Custodian grabs the client, on the client's own machine")
	check(hc.held == puppet and client.player.input_locked, "held, the client can't move")
	await _frames(30)
	check(client.player.global_position.distance_to(cc.grab_point()) < 0.6, "and is carried where it goes")
	for i in Custodian.STRIKES_TO_FREE:
		hc.take_hit(host.player)
	await _frames(10)
	check(hc.held == null and client.player.combat.grabbed_by == null and not client.player.input_locked, "the host strikes it enough, and the client is free")
	check(await _until(func(): return hc.held == puppet, 6.0), "it shudders, then grabs the client again")
	await _frames(10)
	host.sync.run_on(hc, "set_powered", [false])
	await _frames(10)
	check(not hc.powered and not cc.powered and cc.state == "off", "its power cut by code, it's dead on every machine")
	check(hc.held == null and not client.player.input_locked, "and the client is dropped")
	var before := hc.strikes
	cc.take_hit(client.player)
	await _frames(10)
	check(hc.strikes == before + 1, "a client's strike reaches the host, which runs it")
	check(cc.strikes == hc.strikes and cc.wounds.shown() == hc.wounds.shown(), "and every machine shows the same wounds")
	await _coop_close(worlds)


func test_coop_combat() -> void:
	print("Co-op: blocking, going down and helping each other up")
	_game().new_run(3)
	_game().rourke_fate = "killed"
	var worlds := await _coop_worlds(1)
	var machines := await _coop_load(worlds, "res://scenes/level_2.tscn")
	_books_read(machines)  # about something else: no huddle cuts in
	var host = machines[0]
	var client = machines[1]
	var client_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()
	var host_id: int = get_multiplayer(worlds[0].get_path()).get_unique_id()
	for l in machines:
		l.watcher.active = false
	var puppet = host.players.puppet(client_id)
	puppet.take_damage(22.0, "rourke")
	await _frames(10)
	check(is_equal_approx(client.player.health, 78.0), "a hit from the host's Rourke lands on the client's own machine")
	var blocks := []
	host.crew.hit_blocked.connect(func(id, cause): blocks.append([id, cause]))
	var net: Node = root.get_node("/root/Net")
	var real_profile = net.profile
	net.profile = Profile.new()  # in memory, so tests never touch a real save
	for l in machines:
		l.hud._notice.text = ""
	client.player.combat.raise_guard()
	puppet.take_damage(22.0, "rourke")
	await _frames(10)
	check(is_equal_approx(client.player.health, 78.0), "the client's block, on their own machine, catches it")
	check(blocks == [[client_id, "rourke"]], "and the host hears about it, so he can reel")
	check(client.hud._notice.text == (Achievements.NOTICE % Achievements.name_of("achievement:first_block") + "\nUnlocked: High-tops") and host.hud._notice.text == "",
		"the client's first real block unlocks the High-tops for the client only: the host, in the same fight, gets nothing")
	check(net.profile.earned.has(CrewVitals.FIRST_BLOCK), "into the player's own profile")
	client.hud._notice.text = ""
	net.profile = Profile.new()  # the test's machines share one Net, so give the host its own save
	host.player.combat.raise_guard()
	check(host.player.take_damage(22.0, "rourke") == "blocked", "then the host blocks a swing of their own")
	await _frames(10)
	check(host.hud._notice.text == (Achievements.NOTICE % Achievements.name_of("achievement:first_block") + "\nUnlocked: High-tops") and client.hud._notice.text == "" and net.profile.earned.has(CrewVitals.FIRST_BLOCK),
		"and unlocks the High-tops themselves, the client hearing nothing of it")
	net.profile = real_profile
	puppet.take_damage(1000.0, "watcher")
	await _frames(10)
	check(client.player.downed and client.player.input_locked and client.player.health == 0.0, "knocked out: the client is down, not dead")
	check(machines.all(func(l): return l.crew.downed.has(client_id)), "every machine knows")
	check(host.players.puppet(client_id).downed, "the host sees them lying there")
	check(puppet.get_prompt(host.player) == CrewVitals.REVIVE_PROMPT, "and can help them up")
	puppet.interact(host.player)
	await _frames(10)
	check(not client.player.downed and not client.player.input_locked and client.player.health == PlayerCombat.REVIVE_HEALTH, "helped up, the client is back on their feet")
	check(machines.all(func(l): return l.crew.downed.is_empty()), "and nobody is down anywhere")
	var downs := []
	for l in machines:
		l.crew.crew_down.connect(func(cause): downs.append(cause))
	var client_puppet_on_host = puppet
	client_puppet_on_host.take_damage(1000.0, "watcher")
	await _frames(10)
	check(downs.is_empty() and not host.player.downed, "one down, one standing: the crew isn't beaten")
	host.player.take_damage(1000.0, "watcher")
	await _frames(10)
	check(downs == ["watcher", "watcher"], "the last one standing goes down: every machine hears the crew is down")
	check(await _until(func(): return not host.player.downed and not client.player.downed and host.player.health == 100.0 and client.player.health == 100.0, 10.0),
		"and everyone comes to at the checkpoint")
	check(machines.all(func(l): return l.crew.downed.is_empty()), "with nobody left down")
	puppet.take_damage(1000.0, "watcher")
	await _frames(10)
	client.player.combat.bleed_left = 0.05
	check(await _until(func(): return not client.player.downed and client.player.health == 100.0, 10.0), "left down too long, you come to at the checkpoint by yourself")
	check(machines.all(func(l): return not l.crew.downed.has(client_id)), "and you're off the downed list everywhere (host is %d)" % host_id)
	await _coop_close(worlds)


## Co-op in Vale's lab: everyone has to badge in, and the cable is held by whoever carried it up.
func test_coop_level_2_lab() -> void:
	print("Co-op: Level 2 lab with a host and a client")
	_game().new_run(9)
	var worlds := await _coop_worlds(1)
	var machines := await _coop_load(worlds, "res://scenes/level_2.tscn")
	_books_read(machines)  # about something else: no huddle cuts in
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
	check(machines.all(func(l): return l.db.run_silent("SELECT badge_id FROM badge_log WHERE badge_id LIKE 'VIS-%' ORDER BY badge_id").map(func(r): return r["badge_id"]) == ["VIS-01", "VIS-02"]), "each player's own badge number is logged, in player order")
	for l in machines:
		l.lab.cable_holders[client_id] = true  # the client carried the server floor's coil up
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
	check(_doc_has(level, "door_controllers") and not _doc_has(level, "zone %s" % level.zone), "the rack card names the controller table, never the stuck doors' zone")
	check(_doc_has(level, "'fault'") and _doc_has(level, "'offline'") and _doc_has(level, "- H.M."), "Mercer's note explains fault vs offline")
	check(not level._self_test_lines().any(func(l): return l.contains("door_controllers")), "the self-test no longer names the table: it's on the card")
	check(Array(level.terminal.transcript).all(func(l): return not TerminalUI._plain(l).strip_edges().begins_with("WARDEN:")), "no tips from WARDEN on the Server Room A terminal")
	check(Array(level.terminal.transcript).any(func(l): return TerminalUI._plain(l).begins_with("[SYSOP]: that's the one")), "SYSOP confirms the controller")
	check(_game().current_todo() != "" and not _game().current_todo().contains(level.answer), "the to-do names the task, never the answer (%s)" % _game().current_todo())
	for d in level.find_children("*", "Document", true, false):
		if d.title in ["SERVER ROOM A - DOOR CONTROLLERS", "Reminders"]:
			check(level.terminal.global_position.distance_to(d.global_position) < 1.5, "%s is on the terminal desk" % d.title)
			# A flat paper's page reads from its +Z side up (HeldPaper): the top of the
			# page points at the terminal and wall, the reader stands in the room.
			check((d.global_basis * Vector3.BACK).z > 0.9, "%s reads the right way up from the room, so it isn't spun round as you pick it up" % d.title)
		elif d.title == "SYSLOG PRINTOUT":
			check((d.global_basis * Vector3.BACK).z < -0.9, "the syslog printout reads the right way up from the room, not from the wall")


func _game() -> Node:
	return root.get_node("Game")


func test_wing_seeds_in_order() -> void:
	print("Wing seeds in one database")
	var lobby: String = Level0Data.build(1).sql
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
	db.add_wing("level_0", Level0Data.build(3).sql)
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
	_lower_chapters_read([world])  # about something else: no huddle cuts in
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
	check(root.get_node("/root/Net").profile.earned.has("achievement:floor_g"), "finishing the ground floor earns its unlock")
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
	check(root.get_node("/root/Net").profile.earned.has("achievement:floor_14"), "and finishing floor 14 earns its own")
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
	var archive = world.current
	check(archive != null and archive.wing_id == "level_3" and archive.active and world._field_notes == null, "after the security floor the route goes on to the Records Archive on 18")
	world.wing_finished(archive)
	var plant = world.current
	check(plant != null and plant.wing_id == "level_4" and plant.active and world._field_notes == null, "after the archive the route goes on to the Power Plant on 10")
	world.wing_finished(plant)
	check(world._field_notes != null and world.player.input_locked, "the route ends at Field Notes, in the notebook")
	check(world._field_notes.find_children("*", "NotebookView", true, false).size() == 1, "Field Notes is the notebook's page")
	world.queue_free()
	await process_frame


func test_rourke_leads_in() -> void:
	print("Rourke leads the crew up to Server Room A")
	_game().new_run(8)
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	_lower_chapters_read([world])  # about something else: no huddle cuts in
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
	check(lobby.elevator.button.get_prompt(p).contains("Press 14"), "inside, the button says where it goes")
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
	var l0s = load("res://scripts/levels/level_0.gd")
	var l1s = load("res://scripts/levels/level_1.gd")
	var l0 = l0s.new()
	var every_example_runs := true
	var gives_answer := []
	for seed_value in 20:
		var db := FacilityDB.new()
		db.add_wing("level_0", Level0Data.build(seed_value).sql)
		db.add_wing("level_1", Level1Data.build(seed_value).sql)
		for id in StickyNotes.NOTES:
			for example in StickyNotes.NOTES[id].example.split(";", false):
				if example.strip_edges() == "":
					continue
				var result := db.execute(example + ";")
				if not result.ok:
					every_example_runs = false
					continue
				var data0 := Level0Data.build(seed_value)
				var puzzles: Array = [l0.peek_puzzle, l0.memo_puzzle, l0s.caller_puzzle_for(data0.extension), l0s.visitor_puzzle_for(),
					l1s.controller_puzzle_for(Level1Data.build(seed_value).zone), l1s.hot_rack_puzzle_for()]
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


## The visitor badge is worn: carried and listed, never on the hotbar, numbered by player.
func test_visitor_badge() -> void:
	print("Visitor badge")
	var inv := Inventory.new()
	check(inv.add("visitor_badge") and inv.has("visitor_badge") and not inv.hotbar.has("visitor_badge"), "a visitor badge is carried, not put on the hotbar")
	check(not inv.assign(0, "visitor_badge") and not inv.stowed().has("visitor_badge"), "and the inventory won't put it in your hands")
	check(Inventory.item_name("visitor_badge") == "Visitor badge", "it has a name in the inventory")
	var saved := inv.to_dict()
	saved["hotbar"] = ["visitor_badge", "", "", ""]
	inv.load_dict(saved)
	check(inv.has("visitor_badge") and not inv.hotbar.has("visitor_badge"), "a saved run loads the badge back, still off the hotbar")


## Every lift lobby has emergency stairs beside it, signed, and locked after hours.
func test_mercer_tape_secret() -> void:
	print("Mercer's tape")
	_game().new_run(3)
	var net: Node = root.get_node("/root/Net")
	var level = load("res://scenes/level_0.tscn").instantiate()
	root.add_child(level)
	_lower_chapters_read([level])  # about something else: no huddle cuts in
	await physics_frame
	check(not net.profile.earned.has("secret:mercer_vent_tape"), "the vent closet's secret isn't earned before the tape plays")
	# Someone works the tape from out in the lobby.
	level.player.global_position = level.to_global(Vector3(0, 0.1, 6))
	level._on_tape()
	check(not net.profile.earned.has("secret:mercer_vent_tape") and not level.tape.enabled, "a player outside the vent closet hears the tape but doesn't earn its secret")
	level.player.global_position = level.to_global(Vector3(-17.5, 0.1, 4))
	level._on_tape()
	check(net.profile.earned.has("secret:mercer_vent_tape"), "whoever is in the closet when it plays earns it")
	level.queue_free()
	await process_frame


func test_stairwells() -> void:
	print("Stairwells by the lifts")
	_game().new_run(3)
	for path in ["res://scenes/level_0.tscn", "res://scenes/level_1.tscn"]:
		var level = load(path).instantiate()
		root.add_child(level)
		await physics_frame
		var door: Door = level.stair_door
		var floor_label := "G" if path.contains("level_0") else "14"
		check(door != null and door.locked and door.get_prompt(level.player) == "Locked", "floor %s: the stair door beside the lift is locked tonight" % floor_label)
		check(level.elevator.global_position.distance_to(door.global_position) < 8.0, "floor %s: and it's right by the lift lobby" % floor_label)
		var papers: Array = level.find_children("*", "Document", true, false).filter(func(d): return d.global_position.distance_to(door.global_position) < 1.5)
		var text := "\n".join(papers.map(func(d): return d.plain_text()))
		check(text.contains("STAIR 1 - FLOOR %s" % floor_label) and text.contains("STAIR DOORS LOCK"), "floor %s: the placard beside it says why it's locked" % floor_label)
		if floor_label == "G":
			var seats: Array = level.find_children("*", "Seat", true, false).filter(func(st): return absf(st.global_position.z - 4.5) < 0.1 and absf(st.global_position.y - 0.5) < 0.05)
			check(seats.size() == 4 and seats.all(func(st): return st.get_prompt(level.player) == "[E] Sit down"), "floor G: the lobby's four waiting chairs can be sat on")
		level.queue_free()
		await process_frame


func test_sysop_colors() -> void:
	print("SYSOP's colours")
	var line := TerminalUI.sysop("Sort it with ORDER BY piece_no, or try:\n    [color=#ffffff]SELECT * FROM memo_fragments;[/color]")
	var gold := "[color=%s]" % TerminalUI.KEYWORD
	var amber := "[color=%s]" % TerminalUI.TABLE_HEAD
	check(line.contains(gold + "ORDER BY[/color]") and line.contains(amber + "piece_no[/color]"), "keywords and names in SYSOP's advice are lit like the terminal's own")
	check(line.contains(gold + "SELECT[/color]") and line.contains(amber + "memo_fragments[/color]"), "and so are the ones in its queries")
	check(not line.contains(gold + "or[/color]") and line.begins_with("[color=%s][lb]SYSOP[rb]: " % TerminalUI.HINT), "a lowercase 'or' in a sentence stays plain, and the SYSOP prefix is untouched")
	check(TerminalUI._plain(line) == "[SYSOP]: Sort it with ORDER BY piece_no, or try:\n    SELECT * FROM memo_fragments;", "the colours don't change the words")


func test_dialogue_jots() -> void:
	print("Jots for spoken lines")
	var g := _game()
	g.new_run(5)
	check(not g.jot("plain", {"speaker": "ROURKE", "text": "Lovely night for it."}), "a flavour line with no jot writes nothing")
	g.jot("t", {"speaker": "ROURKE", "text": "...", "jot": "Check in at the front desk (Rourke)", "todo": true})
	check(g.current_todo() == "Check in at the front desk (Rourke)", "a spoken task goes on the work order")
	g.open_case("controller", "Which controller?")
	g.jot("c", {"speaker": "ROURKE", "text": "...", "jot": "Rourke said something about the night shift log...", "case": "controller"})
	check(g.case_info("controller").clues.any(func(k): return k.text.contains("night shift log") and k.from == "Rourke"), "a needed fact goes on its case page, from the speaker")
	g.jot("p", {"speaker": "PA", "text": "...", "jot": "The PA said the building closes at seven.", "case": ""})
	check(g.notebook_written.any(func(w): return w.label == "PA" and w.text.contains("closes at seven") and w.case == ""), "a fact with no case of its own goes under Other notes, not the open case, by the PA's name, never WARDEN's")
	g.jot("w", {"speaker": "WARDEN", "text": "...", "jot": "WARDEN won't reset anything without a badge.", "case": "lab_door"})
	check(g.notebook_written.any(func(w): return w.label == "WARDEN" and w.case == "") and not g.case_info("lab_door").get("clues", []).any(func(k): return k.text.contains("WARDEN")), "a fact whose case isn't open goes under Other notes, so it's never hidden")
	check(not g.jot("s", {"speaker": "VALE", "text": "...", "jot": "Vale said...", "case": "controller", "secret": true}), "a secret line is never jotted")
	var clues: int = g.case_info("controller").clues.size()
	check(not g.jot("c", {"speaker": "ROURKE", "text": "...", "jot": "Rourke said something else", "case": "controller"}) and g.case_info("controller").clues.size() == clues, "a line replayed is jotted only once")
	var saved: Dictionary = g.notebook_data()
	g.new_run(5)
	check(g.jot("c", {"speaker": "ROURKE", "jot": "x", "case": "controller"}), "a new run jots afresh")
	g.load_notebook(saved)
	check(not g.jot("t", {"speaker": "ROURKE", "jot": "y", "todo": true}), "and a loaded save remembers what was jotted")
	for id in VoiceLines.LINES:
		var l: Dictionary = VoiceLines.LINES[id]
		if l.has("jot"):
			check(not (l.get("todo", false) and str(l.get("case", "")) != ""), "%s: a jot goes on the work order or a case page, not both" % id)
	g.new_run(5)


func test_case_pages() -> void:
	print("Case pages")
	_game().new_run(7)
	var g := _game()
	check(not g.add_clue("memo", "a clue read early", "Desk") and g.notebook_cases.size() == 1 and not g.case_info("memo").open, "a clue read before its case opens is kept, but no page shows yet")
	check(g.open_case("memo", "What does the memo say?", ["memo_fragments"]) and g.case_info("memo").clues.size() == 1, "opening the case brings the early clue onto its page")
	check(not g.add_clue("memo", "a clue read early", "Desk"), "the same clue isn't noted twice")
	var pages := NotebookPages.new()
	var text := NotebookPages.text_of(pages._case_items(g))
	check(text.contains("What does the memo say?") and text.contains("a clue read early") and text.contains("Desk") and not text.contains("memo_fragments"), "the page shows the question and the clue with where it came from, and no table the player hasn't found")
	g.discover_table("memo_fragments", ["piece_no", "text"])
	text = NotebookPages.text_of(pages._case_items(g))
	check(text.contains("memo_fragments") and text.contains("piece_no"), "once found, the case's table is on its page")
	g.open_case("caller", "Who called?")
	g.solve_case("memo", "sorted by piece_no.")
	var items := pages._case_items(g)
	text = NotebookPages.text_of(items)
	check(text.find("Who called?") < text.find("[x]  What does the memo say?") and text.contains("Solved: sorted by piece_no."), "open cases come first; a solved one is ticked with how")
	for i in items:
		i.free()
	pages.free()
	var saved: Dictionary = g.notebook_data()
	g.notebook_cases.clear()
	g.load_notebook(saved)
	check(g.case_info("caller").title == "Who called?", "case pages are saved with the notebook")
	g.new_run(7)
	check(g.notebook_cases.is_empty(), "a new run starts with no cases")

	# In the server room: papers and plates fill the controller's page.
	var level = load("res://scenes/level_1.tscn").instantiate()
	root.add_child(level)
	_lower_chapters_read([level])  # about something else: no huddle cuts in
	for i in 10:
		await physics_frame
	level._on_asked()
	check(g.case_info("controller").open, "Rourke's ask opens the controller case")
	for d in level.find_children("*", "Document", true, false):
		if d.title in ["SERVER ROOM A - DOOR CONTROLLERS", "Reminders", "NOC SHIFT LOG"]:
			d._note_clues()
	var page := "\n".join(PackedStringArray(g.case_info("controller").clues.map(func(k): return k.text)))
	check(page.contains("door_controllers") and page.contains("'fault'") and page.contains("Server Room C"), "reading the desk papers and the shift log notes the table, the statuses and the stuck doors")
	check(not page.contains(level.answer), "nothing read so far names the controller")
	var cam := Camera3D.new()
	level.add_child(cam)
	var plate: Node3D = level.geo.get_node("Plate_SRC")
	cam.global_position = plate.global_position + plate.global_basis.z * 1.5
	cam.look_at(plate.global_position)
	cam.make_current()
	for i in 5:
		await process_frame
	check(g.case_info("controller").clues.any(func(k): return k.text == "SRC door: red light (stuck)."), "looking at a stuck door's plate notes it's stuck, without its zone")
	level.terminal_ui.terminal = level.terminal
	level.terminal_ui.run(".hint")
	check(g.case_info("controller").clues.any(func(k): return k.from == "SYSOP hint"), "a hint asked for goes on the case page too")
	level.terminal_ui.run("SELECT id FROM door_controllers WHERE zone = '%s' AND status = 'fault';" % level.zone)
	check(g.case_info("controller").clues.any(func(k): return k.text.contains(level.answer)), "SYSOP's answer is noted once the query finds it")
	level.queue_free()
	await process_frame


## Floor 22's case pages: each puzzle has one, and the wing's papers fill them in.
func test_level_2_book_huddles() -> void:
	print("Floor 22: the book's chapters")
	_game().new_run(5)
	_game().rourke_fate = "killed"  # just the security section: the lab's chapter is in its own test
	var net := root.get_node("Net")
	var test_profile = net.profile
	net.profile = Profile.new()
	var level = load("res://scenes/level_2.tscn").instantiate()
	root.add_child(level)
	await _frames(30)
	level.watcher.active = false
	var p: Player = level.player
	var h := _huddle_of(level)
	var opens := func(id: String) -> bool:
		return await _until(func(): return h.chapter.get("id", "") == id and p.input_locked, 10.0)
	_doc(level, "Camera system card").open_reader(p).close()
	check(await opens.call("easy_sql_10"), "reading the camera card brings back Asking a server, the GET chapter")
	await _crew_reads([level])
	check(await _until(func(): return not h.is_running() and not p.input_locked, 10.0) and h.done.has("easy_sql_10"), "the crew reads it and is back at the booth")
	_doc(level, "NIGHT SHIFT SIGN-IN").open_reader(p).close()
	await _frames(20)
	check(not h.is_running(), "the sign-in sheet read before the cameras are found waits: LIKE is for the Pike search")
	level.terminal_ui.terminal = level.booth
	level.terminal_ui.run("GET /cameras")
	check(await opens.call("easy_sql_11"), "once GET /cameras is solved, the sheet brings back Half a name, the LIKE chapter")
	await _crew_reads([level])
	await _until(func(): return not h.is_running(), 10.0)
	_doc(level, "WARDEN manual").open_reader(p).close()
	await _frames(20)
	check(not h.is_running(), "the WARDEN manual's LIKE page doesn't bring it back again")
	level.terminal_ui.terminal = level.booth
	level.terminal_ui.run("SELECT * FROM guards WHERE name LIKE 'Pike%'")
	check(await opens.call("easy_sql_12"), "Pike's suspended PIN brings back One answer feeds the next")
	check(not level.watcher.active and level.watcher.is_watched(), "it doesn't wake while the crew is in the garage, and is held still")
	await _crew_reads([level])
	check(await _until(func(): return level.watcher.active and level.loose, 10.0), "back from the garage, CAM-2 freezes and it hunts")
	level.watcher.active = false  # the rest is about the chapters, not the chase
	level.terminal_ui.terminal = level.booth
	level.terminal_ui.run(_hint_query(level.har_puzzle.hints[-1]))
	level.enter_pin()
	_doc(level, "Door controller card").open_reader(p).close()
	await _frames(20)
	check(not h.is_running(), "the door card read before SEC-EXIT jams waits for it")
	check(await opens.call("easy_sql_13") and level.door_asked, "when SEC-EXIT doesn't open, the card brings back One door's record, the id in the path")
	await _crew_reads([level])
	await _until(func(): return not h.is_running(), 10.0)
	check(["easy_sql_10", "easy_sql_11", "easy_sql_12", "easy_sql_13"].all(func(id): return net.profile.earned.has("chapter:" + id)), "every floor 22 chapter is on the profile")
	_doc(level, "Camera system card").open_reader(p).close()
	level.panel.opened.emit(p)
	await _frames(20)
	check(not h.is_running(), "reading the papers again repeats nothing")
	net.profile = test_profile
	level.queue_free()
	await process_frame


func test_level_2_cases() -> void:
	print("Floor 22 case pages")
	_game().new_run(5)
	_game().rourke_fate = "killed"  # just the security section
	var g := _game()
	var level = load("res://scenes/level_2.tscn").instantiate()
	root.add_child(level)
	_books_read([level])  # about something else: no huddle cuts in
	for i in 30:
		await physics_frame
	level.watcher.active = false
	check(await _until(func(): return g.current_case() == "cameras", 30.0) and g.case_info("cameras").title == level.CASES.cameras, "at the booth, the cameras case is open")
	for d in level.find_children("*", "Document", true, false):
		d._note_clues()
	var cams := "\n".join(PackedStringArray(g.case_info("cameras").clues.map(func(k): return k.text)))
	check(cams.contains("GET /cameras") and cams.contains("motion"), "the camera card notes how to ask for the cameras")
	var pin_clues: Array = g.case_info("pin").clues.map(func(k): return k.text)
	var pins := "\n".join(PackedStringArray(pin_clues))
	check(not g.case_info("pin").open and pins.contains("NO SHOW") and pins.contains("guards") and pins.contains("LIKE") and pins.contains("badge_log"),
		"the booth papers are already noted on the PIN case, ready for when it opens")
	check(not pins.contains(level.data.name) and not pins.contains(level.data.badge) and not pins.contains("Har%"), "no paper's note gives away the night lead, their badge or the query")
	check(g.case_info("door").clues.any(func(k): return k.text.contains("GET /doors/SEC-EXIT")), "the vestibule's door card is noted on the SEC-EXIT case")
	level.terminal_ui.terminal = level.booth
	level.terminal_ui.run(".hint")
	check(g.case_info("cameras").clues.any(func(k): return k.from == "SYSOP hint"), "a hint asked for goes on the open case")
	level.terminal_ui.run("GET /cameras")
	check(g.case_info("cameras").solved and g.case_info("cameras").how.contains("CAM-2") and g.current_case() == "pin", "GET /cameras solves it; the PIN case opens next")
	level.terminal_ui.run("SELECT * FROM guards WHERE name LIKE 'Pike%'")
	check(g.case_info("pin").clues.any(func(k): return k.text.contains("suspended")) and not g.case_info("pin").solved, "Pike's suspended PIN is noted, and the case stays open")
	level.watcher.active = false  # this test is about the pages, not the chase
	level.terminal_ui.run(".hint")
	check(g.case_info("pin").clues.any(func(k): return k.from == "SYSOP hint"), "the PIN hints are noted on the PIN case")
	level.terminal_ui.run(_hint_query(level.har_puzzle.hints[-1]))
	check(g.case_info("pin").solved and g.case_info("pin").how.contains(level.data.name), "the night lead's PIN solves it")
	level.enter_pin()
	for i in 5:
		await physics_frame
	level._on_door_checked("panel")
	check(g.current_case() == "door" and g.case_info("door").clues.any(func(k): return k.text.contains("sensor says closed")), "checking the stuck door opens its case with what the sensor says")
	level._on_breaker(null, level.data.breaker)
	for i in 5:
		await physics_frame
	check(g.case_info("door").solved and g.case_info("door").how.contains("B-%d" % level.data.breaker), "resetting the breaker solves it")
	check(g.current_case() == "", "every floor 22 case is closed once SEC-EXIT is open")
	level.queue_free()
	await process_frame


func test_notebook() -> void:
	print("Notebook")
	_game().new_run(3)
	var level = load("res://scenes/level_0.tscn").instantiate()
	root.add_child(level)
	_lower_chapters_read([level])  # about something else: no huddle cuts in
	for i in 10:
		await physics_frame
	var nb: Notebook = level.notebook
	level.player.input_locked = false
	check(nb.open() and nb.is_open() and level.player.input_locked, "Tab opens the notebook and holds the player")
	check(nb.pages.current_page() == NotebookPages.Page.WORK_ORDER and NotebookPages.TAB_NAMES == ["Work order", "Cases", "Tables", "Field Notes"], "it opens on the work order, then Cases, Tables and Field Notes: no separate Notes tab")
	nb.close()
	check(not nb.is_open() and not level.player.input_locked, "and closes again")
	level.terminal_ui.open(level.desk_terminal, level.player)
	check(not nb.open(), "the notebook can't be opened while using a terminal")
	# Like a real SQL prompt, Enter only runs a query that ends with ;.
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	level.terminal_ui._input.text = "SELECT * FROM memo_fragments"
	level.terminal_ui._on_input_key(enter)
	check(level.terminal_ui._input.text == "SELECT * FROM memo_fragments\n" and not _game().notebook_tables.has("memo_fragments"), "Enter without a ; doesn't run the query: it carries on to a new line")
	var semi: Label = level.terminal_ui._input.get_node_or_null("MissingSemicolon")
	check(semi != null and semi.visible and semi.text == ";" and semi.get_theme_color("font_color").r > 0.9, "and a red ; flashes where it's missing")
	level.terminal_ui._input.text += ";"
	level.terminal_ui._on_input_key(enter)
	check(level.terminal_ui._input.text == "" and _game().notebook_tables.get("memo_fragments", []) == ["piece_no", "text", "scanned_at"], "with the ; it runs, and the query writes its table and columns on the Tables page")
	check(TerminalUI.is_complete(".tables") and TerminalUI.is_complete("GET /doors") and not TerminalUI.is_complete("SELECT 1"), "dot-commands and requests need no ;")
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
	var notes_text := nb.pages.section_text(NotebookPages.Page.TABLES)
	check(notes_text.contains("ORDER BY") and notes_text.contains("FROM lights") and notes_text.find("Sticky notes") > notes_text.find("memo_fragments"), "sticky notes go on the Tables page after the tables, each with its example")
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
	check(not nb.pages.section_text(NotebookPages.Page.CASES).contains("Find the exit"), "the tasks aren't on the Cases page")
	check(_game().ticket_fill("Find the exit", "stairwell, east side") and nb.pages.section_text(NotebookPages.Page.WORK_ORDER).contains("[x]  Find the exit  - stairwell, east side"), "a done task can be filled in")
	check(_game().ticket().tasks.any(func(t): return t.filled == "stairwell, east side") and _game().ticket().customer == "Halcyon Data Systems", "later levels can read the ticket back")
	level.hud.todo("")
	check(_game().current_todo() == "" and _game().notebook_todo.all(func(t): return t.done), "an empty task ticks off the last one")
	check(_game().notebook_data().todo.map(func(t): return t.text).has("Open the exit door"), "the to-do list is saved with the notebook")
	# .tables wrote down every lobby table; keep two for a short section.
	for k in _game().notebook_tables.keys():
		if not k in ["memo_fragments", "doors"]:
			_game().notebook_tables.erase(k)
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
	var written_text := nb.pages.section_text(NotebookPages.Page.CASES)
	check(written_text.contains("Other notes") and written_text.contains("memo scraps") and written_text.contains("piece_no") and not written_text.contains("Sticky notes"), "lines copied with no case open go under Other notes on the Cases page, with their labels")
	# A long case title wraps on its own page: nothing pushes the pages out over the spine.
	_game().open_case("long_title", "Who signed in last? The book's last page is gone, and nobody owns up to it.")
	_game().add_clue("long_title", "Rourke: the front desk scanner \"ate\" one of Vale's memos. The scanner's card might say where it went.", "Rourke")
	nb.pages.show_page(NotebookPages.Page.CASES)
	await process_frame
	var page_w := (NotebookView.BOOK_SIZE.x - NotebookView.SPINE) / 2.0 - NotebookView.PAGE_INSET.x - 100
	var within := func(page: VBoxContainer) -> bool:
		return page.size.x <= page_w + 0.5 and page.get_children().all(func(c): return c.get_combined_minimum_size().x <= page_w)
	check(within.call(nb.pages.book.left) and within.call(nb.pages.book.right), "a long case title and clue wrap within their page")
	_game().notebook_cases.assign(_game().notebook_cases.filter(func(c): return c.id != "long_title"))
	nb.close()
	var saved: Dictionary = _game().notebook_data()
	_game().new_run(4)
	check(_game().notebook_notes.is_empty(), "a new run starts with an empty notebook")
	_game().load_notebook(saved)
	check(_game().notebook_notes.size() == 2 and _game().notebook_tables.has("memo_fragments") and _game().notebook_written.size() == 3, "a saved notebook loads back")
	# Your own notes: "+ write a note" on the Cases page, typed at the foot of the screen.
	level.player.input_locked = false
	_game().open_case("memo", "What does the memo say?", ["memo_fragments"])
	nb.open(NotebookPages.Page.CASES)
	var write_btn: Button = nb.pages.book.find_child("WriteMine", true, false)
	check(write_btn != null and write_btn.text.contains("write a note"), "the Cases page has a button to write your own note")
	write_btn.pressed.emit()
	check(nb.is_writing() and nb.writer.has_focus() and level.player.input_locked, "it opens a line to type on, and you stand still while you write")
	nb.finish_writing("  PIN for HARDY: 2751 ")
	check(not nb.is_writing() and level.player.input_locked and nb.is_open(), "Enter writes it in and the notebook stays open")
	check(_game().notebook_written[-1].text == "PIN for HARDY: 2751" and _game().notebook_written[-1].kind == "mine", "the note is written as typed")
	var mine_text := nb.pages.section_text(NotebookPages.Page.CASES)
	check(_game().notebook_written[-1].case == "memo" and mine_text.contains("My note") and mine_text.find("PIN for HARDY: 2751") < mine_text.find("Other notes"), "your note goes on the page of the case you're working on")
	check(mine_text.count("PIN for HARDY") == 1, "and isn't listed again under Other notes")
	_game().solve_case("memo", "done")
	_game().write_note("Query result", "a line copied after", "result")
	check(_game().notebook_written[-1].case == "" and nb.pages.section_text(NotebookPages.Page.CASES).contains("a line copied after"), "with every case solved, new notes go under Other notes")
	_game().open_case("caller", "Who called?")
	_game().open_case("last_visitor", "Who signed in last?")
	_game().write_note("Query result", "copied at the desk", "result", "caller")
	check(_game().notebook_written[-1].case == "caller", "a line copied at a terminal goes on the case its hints are for, not just the newest one")
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
	_lower_chapters_read([level])  # about something else: no huddle cuts in
	for i in 10:
		await physics_frame
	var nb: Notebook = level.notebook
	var p: Player = level.player
	level._release_camera(p)  # out of the van intro
	check(nb.held != null and p.held_notebook == nb.held and nb.pages.get_parent() == nb.held.viewport, "the notebook is held in your hands, its pages drawn on it")
	check(nb.open() and p.is_holding_notebook() and not p.input_locked, "Tab raises it without freezing you in place")
	check(nb.pages.current_page() == NotebookPages.Page.WORK_ORDER, "it opens on the work order")
	for i in 90:
		await process_frame  # raised all the way
	var shown := p.reading_rect()
	var screen := root.get_visible_rect().size
	check(shown.has_area() and p.edge_turn(Vector2(screen.x - 3, screen.y / 2), screen, shown).x > 1.0
		and p.edge_turn(Vector2(3, screen.y / 2), screen, shown).x < -1.0 and p.edge_turn(Vector2(screen.x / 2, screen.y - 3), screen, shown).y > 1.0,
		"the cursor at any edge of the screen turns the view, however big the book is (its hands and sleeves don't count)")
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
	check(ui._output.get_theme_font_size("normal_font_size") == TerminalScreen.DISPLAY_FONT and ui._input.get_theme_font_size("font_size") == TerminalScreen.DISPLAY_FONT,
		"sitting down, the screen's text stays the size it was from across the room")
	check(level.hud._subtitle.anchor_top == 0.0 and level.hud._notice.anchor_top == 1.0 and not level.hud._keys.visible, "subtitles and notices move off the glass while you're at it")
	ui.run("SELECT * FROM memo_fragments")
	check(t.transcript.any(func(l): return l.contains("piece_no")), "queries typed on the glass run as usual")
	ui.close()
	await process_frame
	await process_frame
	check(ui.get_parent() == home and not ui.is_on_screen() and t.screen.hosted == null and ui._dim.visible, "stepping away puts the window back and the glass shows the screen again")
	check(level.hud._subtitle.anchor_top == 1.0 and level.hud._keys.visible, "and they come back when you step away")
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
	_lower_chapters_read([level])  # about something else: no huddle cuts in
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
	# The sticky on the desk terminal's bezel is what you aim at, not the terminal.
	var on_bezel: StickyNote = level.find_children("*", "StickyNote", true, false).filter(func(n): return n.on_terminal)[0]
	var term: Node3D = on_bezel.get_parent()
	var stand := term.to_global(Vector3(0, 0, 0.85))
	p.global_position = Vector3(stand.x, 0.1, stand.z)
	for i in 10:
		await physics_frame
	p.camera.look_at(on_bezel.global_position)
	p._ray.force_raycast_update()
	check(p._look_target() == on_bezel, "looking straight at the sticky on the terminal's bezel aims at the sticky")
	p.camera.rotation = Vector3.ZERO
	p.global_position = Vector3(1.0, 0.1, -1.9)
	p.rotation.y = 0.0
	for i in 10:
		await physics_frame
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
	var flaps: Array = reader._hidden.duplicate()
	check(not flaps.is_empty() and flaps.all(func(g): return not g.visible) and hands.page.visible, "the tri-fold comes up opened out flat: its folded panels don't cover the page")
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
	check(flaps.all(func(g): return g.visible), "and back on the desk it's folded as before")
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
	var big_reader: DocumentReader = level.find_children("*", "DocumentReader", true, false)[0]
	var two: Label3D = sheet.get_node("WallSheet/Line1")
	check(not hands.page.visible and two.visible, "a wall sheet in big print is read in that same big print, with no smaller page laid over it")
	var on_two := big_reader.label_rect(two).get_center()
	check(big_reader.line_at(on_two) == 1, "the pointer over a printed line finds that line")
	big_reader._hover(on_two)
	check(big_reader._chip.visible and big_reader._chip_index == 1, "and a \"+ note\" chip shows beside it")
	big_reader._chip.pressed.emit()
	check(big_reader._note_label.visible and not big_reader._chip.visible, "the chip asks for the note's name")
	big_reader._finish_note("")
	check(_game().notebook_written.any(func(n): return n.text == "two" and n.label == "Wall test"), "and copies the line")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	var sheet_reader: DocumentReader = level.find_children("*", "DocumentReader", true, false)[0]
	sheet_reader._input(tab)
	for i in 120:
		if p.held_prop == null:
			break
		await physics_frame
	check(p.held_prop == null and not level.notebook.is_open(), "Tab puts a paper down too, without opening the notebook")
	await physics_frame
	# A form on the wall is printed small and detailed, the same page you read held up.
	var form := Document.place(level.geo, Vector3(1.0, 1.5, -3.2), 180.0, "Form test", [
		{"columns": ["NAME", "IN"], "widths": [3.0, 1.0]},
		{"row": ["PIKE", "22:00"], "hand": true},
	])
	var printed: MeshInstance3D = form.get_node_or_null("WallSheet/Print")
	check(form.is_form() and printed != null and form.find_children("Line*", "Label3D", true, false).is_empty(), "a form on the wall is printed as its detailed page, not in big type")
	form._on_used(p)
	for i in 120:
		if p.is_holding_prop() and p._prop_t >= 1.0:
			break
		await physics_frame
	check(not printed.visible and hands.page.visible, "held, only one copy of its page shows")
	level.find_children("*", "DocumentReader", true, false)[0].close()
	for i in 120:
		if p.held_prop == null:
			break
		await physics_frame
	check(printed.visible, "and back on the wall it's printed again")
	form.queue_free()
	# The sticky by the keyboard can be picked up and read; desk stickies are drawn big.
	var stickies: Array = level.find_children("*", "Document", true, false).filter(func(d): return d.title == "Sticky note")
	check(stickies.filter(func(d): return d.plain_text().contains("ORDER matters.") and d.is_sticky() and d.prompt == "Take the sticky note").size() == 1, "the sticky by the keyboard is a sticky note you take, not a paper you read")
	check(stickies.any(func(d): return d.plain_text().contains("ORDER BY ... DESC") and d.position.distance_to(Vector3(-2.25, 1.102, -0.72)) < 0.5), "and the night desk's DESC reminder sits by the visitor book")
	var desk_sticky: StickyNote = level.find_children("*", "StickyNote", true, false).filter(func(n): return not n.on_terminal)[0]
	check(desk_sticky.find_child("StickyNote", false, false).scale.x > 1.2, "stickies lying on the desk are drawn big enough to read standing up")
	# The notebook: 1-4 turn to its tabs; Tab closes it.
	level.notebook.open()
	var three := InputEventKey.new()
	three.keycode = KEY_3
	three.physical_keycode = KEY_3
	three.pressed = true
	level.notebook._unhandled_input(three)
	check(level.notebook.pages.current_page() == NotebookPages.Page.TABLES, "3 turns the notebook to its third tab")
	level.notebook._unhandled_input(tab)
	check(not level.notebook.is_open(), "and Tab puts it away")
	for i in 40:
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
	# A handwritten sticky goes the same way, never up in your hands as a paper:
	# its clue waits under Other notes until its case opens.
	var order: Document = stickies.filter(func(d): return d.plain_text().contains("ORDER matters."))[0]
	for i in 60:
		if not p.is_filing() and level.notebook.is_open():
			break
		await physics_frame
	level.notebook.close()
	for i in 60:
		await physics_frame
	order._on_used(p)
	check(p.held_prop == null and p.is_filing() and level.notebook.is_open() and level.notebook.pages.current_page() == NotebookPages.Page.CASES, "a handwritten sticky goes onto the Cases page, not up in your hands")
	for i in 240:
		if not p.is_filing():
			break
		await physics_frame
	var noted: Array = _game().notebook_written.filter(func(w): return w.text.contains("ORDER matters."))
	check(noted.size() == 1 and noted[0].case == "memo" and not is_instance_valid(order), "once it lands its clue is in the notebook for the memo case, and it's gone from the desk")
	check(level.notebook.pages.section_text(NotebookPages.Page.CASES).contains("ORDER matters."), "kept under Other notes until the memo case opens")
	_game().open_case("memo", "What does Dr. Vale's shredded memo say?")
	var memo_page: String = level.notebook.pages.section_text(NotebookPages.Page.CASES)
	check(memo_page.contains("ORDER matters.") and memo_page.find("ORDER matters.") > memo_page.find("shredded memo"), "and on the memo's page once it opens")
	# One stuck on a wall stays there; each player copies it.
	var wall := Document.place(level.geo, Vector3(1.0, 1.5, -3.2), 180.0, "Sticky note", [{"text": "Bulb's dead.", "hand": true}], false, "sticky")
	check(wall.prompt == "Copy the sticky note into your notebook", "a sticky on a wall is copied")
	wall.take_sticky(null)
	await physics_frame
	check(is_instance_valid(wall) and wall.visible and wall.get_prompt(p) == "" and _game().notebook_written.any(func(w): return w.text == "Bulb's dead." and w.case == ""), "it stays on the wall, and with no case it goes under Other notes")
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
	check(Elevator.level_of("G") == 0 and Elevator.level_of("B2") == -2 and Elevator.level_of("22") == 22 and Elevator.label_of(-1) == "B1" and Elevator.label_of(14) == "14", "tower floors: G is ground, Bn below it")
	lift.ride(0.3)
	var seen: Array[String] = []
	var arrow := ""
	while lift.riding:
		var f: String = lift.art.call("get_floor")
		if seen.is_empty() or seen[-1] != f:
			seen.append(f)
		if arrow == "":
			arrow = (lift.art.get("_arrows")[0] as Label3D).text
		await process_frame
	check(seen == ["1", "G", "B1", "B2"], "the indicator counts down through every floor on the way (%s)" % [seen])
	check(arrow == "v", "and the arrow points down")
	check(dest.to_local(a.global_position).distance_to(a_local) < 0.01 and dest.contains(b.global_position), "the ride carries everyone to the same spot in the next car")
	check(is_equal_approx(angle_difference(a_yaw + PI / 2, a.rotation.y), 0.0), "facing the same way relative to the car")
	await dest.opened
	check(dest.open_amount == 1.0 and lift.open_amount == 0.0, "the next car's doors open; the old ones stay shut")
	stage.queue_free()
	await process_frame


# --- Floor 18: the Records Archive (Level 3) ----------------------------------------

## Inside floor 18's arrival stairwell (Level 3 local): the landing, clear of the flight.
const L3_LANDING_BOX := AABB(Vector3(-8.2, -0.5, 4.1), Vector3(4.2, 3, 3.8))
## Inside its exit stairwell, past the lobby's east door.
const L3_STAIRS_DOWN := Vector3(6.3, 0.1, 6.0)


## The readers' log points at one side room that night, the reading room over the
## whole log; the catalogue and the slips read the same on every seed.
func test_level_3_data_every_seed() -> void:
	print("Level 3 data, 50 seeds")
	var l3 = load("res://scripts/levels/level_3.gd").new()
	var night: String = "SELECT room, COUNT(*) AS n FROM access_log WHERE time LIKE '%s%%' GROUP BY room ORDER BY n DESC" % Level3Data.NIGHT
	var whole := "SELECT room, COUNT(*) AS n FROM access_log GROUP BY room ORDER BY n DESC"
	var host_wins := true
	var decoy_wins := true
	var no_ties := true
	var wrongs_fail := true
	var tally_route := true
	var sources := true
	var slips_ok := true
	var depts_ok := true
	var nulls_ok := true
	var route_ok := true
	var code_ok := true
	var forms_ok := true
	var window_ok := true
	var cart_ok := true
	var taped_ok := true
	var codes := {}
	var hosts := {}
	for s in 50:
		var data := Level3Data.build(s)
		var db := FacilityDB.new()
		db.load_seed(data.sql)
		# Every correct form passes: the busiest room with its count as one row, a
		# COUNT on a column, an alias; a lone raw row doesn't, nor a one-row total.
		for right in [
			"SELECT room, COUNT(*) FROM access_log WHERE time LIKE '%s%%' GROUP BY room ORDER BY COUNT(*) DESC LIMIT 1" % Level3Data.NIGHT,
			"SELECT room, COUNT(badge_id) AS swipes FROM access_log WHERE time LIKE '%s%%' GROUP BY room ORDER BY swipes DESC LIMIT 1" % Level3Data.NIGHT,
			"SELECT COUNT(*) AS n, room FROM access_log WHERE time LIKE '%s%%' GROUP BY room ORDER BY n DESC" % Level3Data.NIGHT,
		]:
			if not l3.visits_puzzle.matches(db, db.execute(right)):
				forms_ok = false
		for wrong in [
			"SELECT room FROM access_log WHERE time LIKE '%s%%' LIMIT 1" % Level3Data.NIGHT,
			"SELECT room, COUNT(*) FROM access_log WHERE time LIKE '%s%%' LIMIT 1" % Level3Data.NIGHT,
			"SELECT room, COUNT(*) FROM access_log GROUP BY room ORDER BY COUNT(*) DESC LIMIT 1",
		]:
			if l3.visits_puzzle.matches(db, db.execute(wrong)):
				forms_ok = false
		for right in ["SELECT COUNT(slip_no) FROM retrieval_slips WHERE status = 'open'", "SELECT COUNT(*) AS n FROM retrieval_slips WHERE status = 'open'", "SELECT COUNT(*) FROM retrieval_slips WHERE status = 'open'"]:
			if not l3.slips_puzzle.matches(db, db.execute(right)):
				forms_ok = false
		for right in ["SELECT room, COUNT(*) AS swipes FROM access_log GROUP BY room", "SELECT COUNT(badge_id), room FROM access_log GROUP BY room"]:
			if not l3.tally_puzzle.matches(db, db.execute(right)):
				forms_ok = false
		# The night's swipes all fall between 19:00 and 23:00 on the 15th: nothing crosses
		# midnight, and nobody is still swiping once the crew is in the building.
		for row in db.run_silent("SELECT time FROM access_log WHERE time LIKE '%s%%'" % Level3Data.NIGHT):
			var hour := int(str(row["time"]).get_slice(" ", 1).get_slice(":", 0))
			if hour < Level3Data.NIGHT_FROM or hour >= Level3Data.NIGHT_TO:
				window_ok = false
		if not db.run_silent("SELECT time FROM access_log WHERE time LIKE '1997-10-16%'").is_empty() or db.run_silent("SELECT time FROM access_log WHERE time LIKE '%s%%'" % Level3Data.NIGHT).size() < 20:
			window_ok = false
		# The returns cart: every filled slip's box, with its label; the key box is one
		# nobody checked back in, among enough others that opening them all is slow.
		var filled := db.run_silent("SELECT box_id FROM retrieval_slips WHERE status = 'filled' ORDER BY box_id").map(func(r): return r["box_id"])
		var cart: Array = data.cart.duplicate()
		cart.sort()
		if cart != filled or cart.size() < 7 or not data.unreturned.has(data.key_box) or db.run_silent("SELECT status FROM catalogue WHERE box_id = '%s'" % data.key_box)[0]["status"] != "out":
			cart_ok = false
		if db.run_silent("SELECT COUNT(*) AS n FROM catalogue WHERE status = 'returned'")[0]["n"] != cart.size() - data.unreturned.size():
			cart_ok = false
		# No route to the stairs skips the lock, the safe room and the IS NULL query:
		# no box on the cart opens until the note (behind the lock) is read and the
		# query has named it, and then only the unreturned one or two.
		l3.data = data
		for gates in [[false, false], [true, false], [false, true]]:
			l3.note_read = gates[0]
			l3.boxes_named = gates[1]
			if data.cart.any(func(b): return l3._box_openable(b)):
				taped_ok = false
		l3.note_read = true
		l3.boxes_named = true
		for b in data.cart:
			if l3._box_openable(b) != data.unreturned.has(b):
				taped_ok = false
		if not l3._box_openable(data.key_box):
			taped_ok = false
		# The lock's question accepts the raw rows, DISTINCT and a GROUP BY alike.
		for right in ["SELECT * FROM access_log WHERE room = '%s'" % data.host, "SELECT DISTINCT badge_id FROM access_log WHERE room = '%s'" % data.host, "SELECT badge_id, COUNT(*) FROM access_log WHERE room = '%s' GROUP BY badge_id" % data.host]:
			var kp := Puzzle.new("keyholder", "SELECT badge_id FROM access_log WHERE room = '%s'" % data.host, ["badge_id"], false)
			kp.distinct = true
			var r := db.execute(right)
			if not kp.matches(db, r) or kp.matches(db, db.execute("SELECT DISTINCT badge_id FROM access_log")):
				forms_ok = false
		var by_night := db.run_silent(night)
		if by_night.is_empty() or by_night[0]["room"] != data.host or not Level3Data.CANDIDATES.has(data.host):
			host_wins = false
		if db.run_silent(whole)[0]["room"] != "READING ROOM":
			decoy_wins = false
		var counts := {}
		for row in by_night:
			counts[int(row["n"])] = true
		if counts.size() != by_night.size():
			no_ties = false
		if not l3.visits_puzzle.matches(db, db.execute(night)) or not l3.visits_puzzle.matches(db, db.execute(night.replace(" AS n", "").replace("ORDER BY n", "ORDER BY COUNT(*)"))):
			host_wins = false
		for wrong in [
			whole,
			night.replace("DESC", "ASC"),
			"SELECT room FROM access_log WHERE time LIKE '%s%%' GROUP BY room" % Level3Data.NIGHT,
			"SELECT badge_id, COUNT(*) AS n FROM access_log WHERE time LIKE '%s%%' GROUP BY badge_id ORDER BY n DESC" % Level3Data.NIGHT,
			"SELECT * FROM access_log LIMIT 5",
		]:
			if l3.visits_puzzle.matches(db, db.execute(wrong)):
				wrongs_fail = false
		# Reading one badge's rows and tallying by hand gets there too.
		var mine := db.run_silent("SELECT room, COUNT(*) AS n FROM access_log WHERE badge_id = '%s' GROUP BY room ORDER BY n DESC" % data.visitor_badge)
		if mine.is_empty() or mine[0]["room"] != data.host or db.run_silent("SELECT * FROM access_log WHERE badge_id = '%s'" % data.visitor_badge).size() > TerminalUI.MAX_ROWS_SHOWN:
			tally_route = false
		for row in db.run_silent("SELECT DISTINCT room FROM access_log"):
			if not Level3Data.ROOMS.has(row["room"]):
				sources = false  # a row with no reader in the world
		for row in db.run_silent("SELECT DISTINCT room, aisle FROM catalogue"):
			if row["room"] == "STACKS" and not str(row["aisle"]).begins_with("A"):
				sources = false
			if row["room"] != "STACKS" and not Level3Data.CANDIDATES.has(row["room"]):
				sources = false
		var open_n := int(db.run_silent("SELECT COUNT(*) AS n FROM retrieval_slips WHERE status = 'open'")[0]["n"])
		if open_n != data.open_slips or open_n < 3 or open_n > 5 or not l3.slips_puzzle.matches(db, db.execute("SELECT COUNT(*) FROM retrieval_slips WHERE status = 'open'")):
			slips_ok = false
		var depts := db.run_silent("SELECT DISTINCT dept FROM catalogue WHERE room = 'STACKS'").size()
		var all_rows := db.run_silent("SELECT dept FROM catalogue WHERE room = 'STACKS'").size()
		if depts < 2 or depts >= all_rows or not l3.depts_puzzle.matches(db, db.execute("SELECT DISTINCT dept FROM catalogue WHERE room = 'STACKS'")) or l3.depts_puzzle.matches(db, db.execute("SELECT dept FROM catalogue WHERE room = 'STACKS'")):
			depts_ok = false
		for wrong in ["SELECT COUNT(*) FROM retrieval_slips", "SELECT COUNT(*) FROM retrieval_slips WHERE status = 'filled'"]:
			if l3.slips_puzzle.matches(db, db.execute(wrong)):
				slips_ok = false
		for wrong in ["SELECT DISTINCT title FROM catalogue WHERE room = 'STACKS'", "SELECT DISTINCT dept FROM catalogue"]:
			if l3.depts_puzzle.matches(db, db.execute(wrong)):
				depts_ok = false
		# IS NULL: the boxes pulled and never brought back. The cell is a real NULL.
		var out_boxes := db.run_silent("SELECT box_id FROM catalogue WHERE status = 'out' ORDER BY box_id").map(func(r): return r["box_id"])
		var unreturned: Array = data.unreturned.duplicate()
		unreturned.sort()
		if unreturned.is_empty() or unreturned.size() > 2 or out_boxes != unreturned:
			nulls_ok = false
		if int(db.run_silent("SELECT COUNT(*) AS n FROM retrieval_slips WHERE returned_at = '' OR returned_at = 0")[0]["n"]) != 0:
			nulls_ok = false
		for right in ["SELECT box_id FROM retrieval_slips WHERE status = 'filled' AND returned_at IS NULL", "SELECT * FROM retrieval_slips WHERE returned_at IS NULL AND status = 'filled'"]:
			if not l3.unreturned_puzzle.matches(db, db.execute(right)):
				nulls_ok = false
		for wrong in [
			"SELECT box_id FROM retrieval_slips WHERE returned_at = NULL",
			"SELECT box_id FROM retrieval_slips WHERE returned_at = ''",
			"SELECT box_id FROM retrieval_slips WHERE returned_at IS NULL",
			"SELECT box_id FROM retrieval_slips WHERE status = 'filled' AND returned_at IS NOT NULL",
			"SELECT box_id FROM retrieval_slips WHERE status = 'filled'",
		]:
			if l3.unreturned_puzzle.matches(db, db.execute(wrong)):
				nulls_ok = false
		# The catalogue route: Mercer's boxes name the room without the night's log.
		# The LIKE-only route (three repeated rows), DISTINCT, SELECT * and a title match all pass.
		for right in ["SELECT room FROM catalogue WHERE note LIKE '%archivist%'", "SELECT DISTINCT room FROM catalogue WHERE dept = 'EXECUTIVE'", "SELECT * FROM catalogue WHERE dept = 'EXECUTIVE'", "SELECT room FROM catalogue WHERE title LIKE 'Founder%'"]:
			var r := db.execute(right)
			if not l3.mercer_puzzle.matches(db, r) or r.rows[0]["room"] != data.host:
				route_ok = false
		for wrong in ["SELECT DISTINCT room FROM catalogue", "SELECT DISTINCT room FROM catalogue WHERE room != 'STACKS'", "SELECT dept FROM catalogue WHERE dept = 'EXECUTIVE'", "SELECT * FROM access_log WHERE room = '%s'" % data.host]:
			if l3.mercer_puzzle.matches(db, db.execute(wrong)):
				route_ok = false
		if data.mercer_boxes.size() != 3:
			sources = false
		# The lock's code is the night visitor's badge number (Mercer's own, an E- badge
		# in his name), and only that badge used the host room's reader.
		var badges := db.run_silent("SELECT DISTINCT badge_id FROM access_log WHERE room = '%s'" % data.host)
		if data.code.length() != 4 or not data.code.is_valid_int() or data.visitor_badge != "E-" + data.code or badges.size() != 1 or db.run_silent("SELECT DISTINCT holder FROM access_log WHERE badge_id = '%s'" % data.visitor_badge) != [{"holder": "MERCER, H."}] or badges[0]["badge_id"] != data.visitor_badge or Level3Data.DAY_BADGES.any(func(b): return b[0] == data.visitor_badge):
			code_ok = false
		codes[data.code] = true
		hosts[data.host] = true
	check(host_wins, "that night, the host room's reader logged the most visits, and GROUP BY + ORDER BY COUNT(*) DESC ranks it first")
	check(decoy_wins, "over the whole log the reading room wins: the night matters")
	check(no_ties, "no two rooms tie that night, so the order is the same on every machine")
	check(wrongs_fail, "no WHERE, ASC, no ORDER BY, grouping by badge and LIMIT never pass the visits check")
	check(tally_route, "one badge's rows alone point at the room, and fit on one screen to tally by hand")
	check(sources, "every log room has a reader, every box an aisle or a side room, and Mercer's three boxes are in the host room")
	check(slips_ok, "3 to 5 slips are open, and COUNT(*) on them passes the slips check; counting every slip or the filled ones doesn't")
	check(depts_ok, "the stacks' departments repeat: DISTINCT collapses them, and the plain list, the wrong column and every room don't pass")
	check(nulls_ok, "one or two pulled boxes never came back: returned_at IS NULL finds them (and the catalogue says 'out'); = NULL, = '', no status, IS NOT NULL and the filled list don't")
	check(route_ok, "the catalogue route: Mercer's boxes (his department, the archivist note, the title) name the room, with or without DISTINCT; broader lists and the reader's rows don't")
	check(forms_ok, "every correct form passes: the top room with its count, COUNT on a column, aliases, the raw rows for the lock; a lone raw row and the whole log's top room don't")
	check(window_ok, "the night's swipes all fall between 19:00 and 23:00 on the 15th, before the crew signs in; none cross midnight")
	check(cart_ok, "the returns cart holds every filled slip's box (7 or more); the key box is one nobody checked back in, 'out' in the catalogue; the rest are 'returned'")
	check(taped_ok, "every seed: no box on the cart opens before Mercer's note is read and the IS NULL query has named it; then only the unreturned box or two, the key's among them")
	check(hosts.size() == Level3Data.CANDIDATES.size(), "the safe room hides behind a different side room on different runs (%s)" % [hosts.keys()])
	check(code_ok and codes.size() > 40, "the lock's code is the four digits of the one badge that used the host room's reader, and it changes with the seed")
	var building := FacilityDB.new()
	building.load_seed(Level2Data.build(1).sql)
	var doors_before := building.run_silent("SELECT id FROM doors").size()
	var lights_before := building.run_silent("SELECT id FROM lights").size()
	var stacked: bool = building.db.query(Level3Data.build(1).sql)
	check(stacked and building.run_silent("SELECT id FROM doors").size() == doors_before + 6 and building.run_silent("SELECT id FROM lights WHERE floor = 18").size() == 12 and building.run_silent("SELECT id FROM lights").size() == lights_before + 12,
		"the wing's seed loads on top of Level 2's: six ARC- doors and twelve floor-18 lights added")
	check(building.run_silent("SELECT status FROM lights WHERE id = 'L18-STACKS'")[0]["status"] != "ok", "the dark stacks have a cause in the lights table")
	l3.free()


## The floor on its own: arrive on the landing through a wedged-open fire door, the
## stairs down locked, dark stacks with a cause, side rooms whose shelving hides the
## back wall until the crank is turned, and the desk's stations.
func test_level_3_scene() -> void:
	print("Level 3 scene")
	_game().new_run(11)
	var level = load("res://scenes/level_3.tscn").instantiate()
	root.add_child(level)
	for i in 30:
		await physics_frame
	var p: Player = level.player
	check(level.stair_in.is_open and not level.stair_in.locked, "the fire door from the stairs is wedged open")
	check(level.stair_out.locked and not level.stair_out.is_open, "the stairs down are locked after hours")
	check(L3_LANDING_BOX.has_point(level.to_local(p.global_position)) and p.is_on_floor(), "players start on the stairwell landing (%s)" % level.to_local(p.global_position))
	var ids: Array = level.doors.keys()
	ids.sort()
	check(ids == ["ARC-COLD", "ARC-FICHE", "ARC-MAP", "ARC-SHRED", "ARC-SUPPLY", "ARC-VAULT-C"] and level.doors.values().all(func(d): return (d.is_hinged() or d.door_id == "ARC-SHRED") and not d.locked),
		"every side room has an ordinary door that shuts, in the doors table; the shredding room a roll-up (%s)" % [ids])
	check(level.lights["L18-STACKS"].all(func(l): return not l.visible) and level.lights["L18-LOBBY"].all(func(l): return l.visible), "the stacks' sensor lights are off after hours; the lobby's are on")
	check(_doc(level, "Stacks lighting notice") != null and _doc(level, "Facilities memo") != null and _doc(level, "Door sign") != null, "the dark stacks, the dead lifts and the wedged door each have a sign saying why")
	var slips: Node = _doc(level, "Retrieval slips")
	var an_open_slip: String = level.db.run_silent("SELECT slip_no FROM retrieval_slips WHERE status = 'open'")[0]["slip_no"]
	check(slips != null and slips.plain_text().contains(an_open_slip), "the slips on the desk's spike are the open rows of retrieval_slips")
	check(level.stack_units.size() == 5 and level.find_children("*", "MovementVolume", true, false).filter(func(v): return v.kind == MovementVolume.Kind.CLIMB).size() == 10,
		"five shelf units, each climbable from both ends")
	# Standing on a shelf top: solid, with headroom.
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(0, 3.75, -15)))
	for i in 20:
		await physics_frame
	check(p.is_on_floor() and absf(level.to_local(p.global_position).y - 3.6) < 0.15 and p.health > 0.0, "the shelf tops hold a player, 2 m under the ceiling (y %.2f)" % level.to_local(p.global_position).y)
	# Readers: one by every room door, the source of access_log.
	check(level.geo.find_children("Reader*", "", true, false).size() >= 8, "a badge reader beside every room door")
	# The host room: its back wall is behind the shelving until the crank is turned.
	var host: String = level.data.host
	var spec: Dictionary = level.SIDE_ROOMS[host]
	var back: Vector3 = spec.back
	var before: Array = level.shelving[host].map(func(u): return u.position)
	check(not level.back_aisle_open(host) and level.safe_door != null and not level.safe_door.is_open, "the safe room's door starts behind the host room's shelving")
	var rear: Vector3 = spec.center + back * (level.SIDE_ROOM_SIZE.x / 2 - 0.3)
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(level.to_global(spec.center + Vector3(0, 1.0, 0)), level.to_global(rear + Vector3(0, 1.0, 0)))
	check(not space.intersect_ray(q).is_empty(), "before cranking, shelving stands between the room's middle and its back wall")
	level.cranks[host].interact(p)
	for i in 180:
		await physics_frame
	var moved: bool = level.cranked[host] and not level.cranks[host].enabled
	for i in level.shelving[host].size():
		moved = moved and (level.shelving[host][i].position - before[i]).is_equal_approx(-back * level.CRANK_TRAVEL)
	check(moved, "the crank rolls every unit toward the door, once")
	q = PhysicsRayQueryParameters3D.create(level.to_global(rear + Vector3(0, 1.0, 2.5)), level.to_global(rear + Vector3(0, 1.0, -2.5)))
	check(space.intersect_ray(q).is_empty(), "after cranking, the aisle along the back wall is clear")
	check(level.find_children("Door_MERCER", "", false, false).size() == 1 and level.safe_room_box.has_point(spec.center + back * (level.SIDE_ROOM_SIZE.x / 2 + 1.0)),
		"one hidden door, in the host room's back wall, with Mercer's room beyond it")
	# The desk's stations and their ladders (COUNT's is the short review one).
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), level.to_global(Vector3(-0.8, 0.1, 2.6)))
	level.terminal_ui.terminal = level.desk
	check(level.desk.puzzles.size() == 7 and level.desk.puzzles.all(func(pz): return pz.hints.size() >= 2) and level.pc_puzzle.hints.size() >= 2, "seven stations on the desk and one on the PC, each with a hint ladder")
	check(level.desk.puzzles[0] == level.keyholder_puzzle and level.desk.next_hint().contains("access_log WHERE room = '?'"), "with Mercer's door found, .hint starts on the lock's question")
	level.terminal_ui.run("SELECT COUNT(*) FROM access_log")
	check(not level.tally_puzzle.solved, "a count without GROUP BY is one row, and doesn't pass the tally")
	level.terminal_ui.run("SELECT room, COUNT(*) FROM access_log GROUP BY room")
	check(level.tally_puzzle.solved and not level.visits_puzzle.solved, "the tally sheet's whole-log count passes the tally station only")
	check(_doc(level, "Reader tally") != null and _doc(level, "Retention review memo") != null and _doc(level, "Retrieval slips").plain_text().contains(Level3Data.NIGHT) and _doc(level, "Clerk's sticky") != null and _doc(level, "Note by the spike") != null,
		"the tally sheet, the memo on the card catalogue, the COUNT sticky, the spike note and the night's date on the slips are on the floor")
	# The room's question hasn't been asked yet: Security's sheet hangs in the north corridor.
	level.terminal_ui.run("SELECT room, COUNT(*) FROM access_log WHERE time LIKE '%s%%' GROUP BY room ORDER BY COUNT(*) DESC" % Level3Data.NIGHT)
	check(not level.room_asked and not level.visits_puzzle.solved and not _game().case_info("room").get("open", false), "before Security's sheet is read, the night's count isn't a station yet, and the room case isn't open")
	var sheet: Node = _doc(level, "Reader exceptions")
	check(sheet != null and level.to_local(sheet.global_position).z < -22.0, "Security's exceptions sheet hangs in the north corridor")
	sheet.open_reader(p).close()
	await _frames(3)
	check(level.room_asked and _game().case_info("room").get("open", false) and not _game().case_info("room").get("solved", false) and _game().current_todo() == level.TEXT.todo_room, "reading the sheet asks the question: the room case opens unsolved and the to-do says to find the room")
	level.terminal_ui.run("SELECT room, COUNT(*) FROM access_log GROUP BY room ORDER BY COUNT(*) DESC")
	check(not level.visits_puzzle.solved and not _game().case_info("room").get("solved", false), "a count over the whole log doesn't pass: the reading room comes first")
	level.terminal_ui.run("SELECT room FROM catalogue WHERE note LIKE '%archivist%'")
	check(level.mercer_puzzle.solved and _game().case_info("room").solved and _game().case_info("room").how.contains(host), "the catalogue route: Mercer's boxes name the room, and the case page closes with it")
	level.terminal_ui.run("SELECT room, COUNT(*) FROM access_log WHERE time LIKE '%s%%' GROUP BY room ORDER BY COUNT(*) DESC LIMIT 1" % Level3Data.NIGHT)
	check(level.visits_puzzle.solved and _game().case_info("room").solved, "that night's top room with its count passes too; the case stays closed once")
	level.terminal_ui.run("SELECT * FROM access_log WHERE room = '%s'" % host)
	check(level.keyholder_puzzle.solved, "the lock's question: that room's raw rows, read by eye, pass it")
	check(level.slips_puzzle.hints.size() == 2 and level.slips_puzzle.hints[0].contains("counted before") and level.slips_puzzle.hints[0].contains("status = '?'") and not level.slips_puzzle.hints[0].contains("'open'"),
		"the slips ladder is review: a reminder with the shape, then the query")
	level.terminal_ui.run("SELECT * FROM retrieval_slips")
	level.terminal_ui.run("SELECT * FROM retrieval_slips WHERE status = 'open'")
	var counted := Array(level.desk.transcript).filter(func(l): return TerminalUI._plain(l).contains(level.TEXT.tip_count))
	check(counted.size() == 1 and not level.slips_puzzle.solved, "listing the slips instead of counting them gets SYSOP's reminder, once")
	level.terminal_ui.run("SELECT COUNT(slip_no) FROM retrieval_slips WHERE status = 'open'")
	level.terminal_ui.run("SELECT DISTINCT dept FROM catalogue WHERE room = 'STACKS'")
	check(level.slips_puzzle.solved and level.depts_puzzle.solved and _game().case_info("duties").get("solved", false), "the slips and departments stations pass, and the night clerk's list closes")
	level.terminal_ui.run("SELECT box_id FROM retrieval_slips WHERE returned_at = NULL")
	check(not level.unreturned_puzzle.solved, "= NULL finds nothing, so the unreturned station doesn't pass")
	level.terminal_ui.run("SELECT box_id FROM retrieval_slips WHERE status = 'filled' AND returned_at IS NULL")
	check(level.unreturned_puzzle.solved and _game().case_info("key").get("solved", false) and _game().case_info("key").how.contains(level.data.key_box), "IS NULL finds the boxes nobody checked back in; the key case names them")
	check(level.find_children("*", "Terminal", true, false).size() == 2 and level.geo.get_node_or_null("FicheTerminal") == null, "two terminals on 18, the desk and Mercer's PC: the microfiche room has none (the HTML record moved to a later floor)")
	# Mercer's PC: its own little database, off the building's, with the safe IS NULL practice.
	level.terminal_ui.terminal = level.pc
	level.terminal_ui.run("SELECT box_id FROM pulled WHERE back_on IS NULL")
	check(level.pc_puzzle.solved and level.db.run_silent("SELECT name FROM sqlite_master WHERE name = 'pulled'").is_empty(), "the PC's practice passes on its own table, which the building's database doesn't have")
	level.terminal_ui.terminal = level.desk
	level.terminal_ui.run("SELECT box_id FROM pulled WHERE back_on IS NULL")
	check(Array(level.desk.transcript).any(func(l): return str(l).to_lower().contains("no such table")), "the desk terminal has no 'pulled' table: the PC is off the network")

	level.queue_free()
	await process_frame


## Mercer's room: found through the cranked aisle, a hub from then on; the one floppy
## and the stair key go to whoever takes them; the key opens the stairs; everyone on
## the stairs ends the floor.
func test_level_3_safe_room() -> void:
	print("Level 3: Mercer's room and the way down")
	_game().new_run(23)
	var level = load("res://scenes/level_3.tscn").instantiate()
	root.add_child(level)
	for i in 30:
		await physics_frame
	var p: Player = level.player
	var host: String = level.data.host
	var spec: Dictionary = level.SIDE_ROOMS[host]
	var c: Vector3 = level.safe_room_box.get_center()
	check(level.safe_door.is_hinged() and level.safe_door.locked and level.db.run_silent("SELECT * FROM doors WHERE id = 'MERCER'").is_empty(), "Mercer's door is a plain hinged door with a mechanical lock: no badge, nothing in the doors table")
	check(not level.lights.keys().any(func(k): return k.contains("MERCER")) and level.db.run_silent("SELECT * FROM lights WHERE room LIKE '%Mercer%'").is_empty(), "nothing in the safe room is in the lights table: it's off the grid")
	var card := _doc(level, "SQL pocket reference")
	check(card != null and level.safe_room_box.has_point(level.to_local(card.global_position)) and card.plain_text().contains("IS NULL") and not card.plain_text().contains("SELECT") and not card.plain_text().contains("returned_at"), "Mercer's reference card is on his desk: it explains IS NULL on another table, and gives no query")
	level.cranks[host].interact(p)
	level.safe_door.interact(p)
	for i in 60:
		await physics_frame
	check(level.safe_door.locked and not level.safe_door.is_open and level.lock != null and level.lock.get_parent() == level.geo, "cranking only finds the door: it's locked, with a push-button lock beside it")
	level.type_code("0000" if level.data.code != "0000" else "0001", p)
	await _frames(3)
	check(not level.safe_unlocked and level.safe_door.locked and level.lock.screen.text == level.TEXT.lock_wrong, "a wrong code is refused")
	check(_doc(level, "Push-button locks") != null and _doc(level, "Push-button locks").plain_text().contains("badge") and level.db.run_silent("SELECT DISTINCT badge_id FROM access_log WHERE room = '%s'" % host).size() == 1, "the desk's policy sheet says a code is its keyholder's badge number, and that room's reader logged exactly one badge")
	level.type_code(level.data.code, p)
	await _frames(3)
	check(level.safe_unlocked and not level.safe_door.locked and level.lock.screen.text == level.TEXT.lock_open, "the keyholder's badge digits unlock Mercer's door: the coded step on every route in")
	level.safe_door.interact(p)
	for i in 60:
		await physics_frame
	check(level.safe_door.is_open, "E opens the hidden door once it's unlocked")
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(c.x, 0.1, c.z)))
	for i in 10:
		await physics_frame
	check(level.reached_safe and _game().current_todo() == "", "stepping in finds the room: the to-do is ticked off")
	level.floppy.interact(p)
	for i in 5:
		await physics_frame
	check(p.inventory.has("floppy_disk") and level.floppy_taken and not level.floppy.enabled, "the floppy is taken, and there was only one")
	# No key on the hook: Mercer's note says it's in the box nobody checked back in.
	var note: Node = _doc(level, "Mercer's note")
	check(note != null and level.safe_room_box.has_point(level.to_local(note.global_position)) and note.plain_text().contains("checked back in"), "Mercer's note on the cot says where the key went")
	check(level.key_dock != null and level.cart_boxes.size() >= 7 and level.cart_boxes.has(level.data.key_box) and level.cart_boxes[level.data.key_box] == level.key_dock and level.to_local(level.key_dock.global_position).x > 5.0, "the key is in the box on the returns cart that nobody checked back in, among the other returned boxes")
	# Every box is taped until the note is read AND the slips table names the box.
	level.key_dock.interact(p)
	await _frames(3)
	check(not p.inventory.has("stair_key") and not level.key_taken and level.stair_out.locked and level.key_dock.get_prompt(p) == level.TEXT.box_taped and level.key_dock.tape.visible, "before Mercer's note, the key box is taped shut: pressing it does nothing")
	note.open_reader(p).close()
	await _frames(3)
	check(_game().current_todo() == level.TEXT.todo_key_box and _game().case_info("key").get("open", false), "reading it sets the to-do and opens the key case")
	level.key_dock.interact(p)
	await _frames(3)
	check(not p.inventory.has("stair_key") and not level.key_taken and level.key_dock.get_prompt(p) == level.TEXT.box_taped, "after the note but before the query, the key box is still taped")
	level.terminal_ui.terminal = level.desk
	# The note has asked the slips a different question, so listing them (the key
	# ladder's own advice) gets no "you've counted before" from SYSOP.
	level.terminal_ui.run("SELECT * FROM retrieval_slips")
	level.terminal_ui.run("SELECT * FROM retrieval_slips")
	check(not level.slips_puzzle.solved and not Array(level.desk.transcript).any(func(l): return TerminalUI._plain(l).contains(level.TEXT.tip_count)),
		"with Mercer's note read, listing the slips gets no COUNT reminder: the key's question comes first")
	level.terminal_ui.run(level.unreturned_puzzle.solution_sql)
	await _frames(3)
	check(level.unreturned_puzzle.solved and level.boxes_named and not level.key_dock.tape.visible and level.key_dock.get_prompt(p) == "[E] " + level.TEXT.box_tear % level.data.key_box, "the IS NULL query names the box: its tape comes off and it can be torn open")
	var decoy_id: String = level.cart_boxes.keys().filter(func(k): return not level.data.unreturned.has(k))[0]
	level.cart_boxes[decoy_id].interact(p)
	await _frames(3)
	check(not p.inventory.has("stair_key") and level.stair_out.locked and level.cart_boxes[decoy_id].tape.visible and level.cart_boxes[decoy_id].get_prompt(p) == level.TEXT.box_taped, "a box the query didn't name stays taped and gives no key")
	for other in level.data.unreturned:
		if other != level.data.key_box:
			level.cart_boxes[other].interact(p)
			await _frames(3)
			check(not p.inventory.has("stair_key") and level.stair_out.locked and level.cart_boxes[other].has_taken(level.players.id_of(p)), "a second unreturned box opens but holds only papers")
	level.key_dock.interact(p)
	for i in 5:
		await physics_frame
	check(p.inventory.has("stair_key") and level.key_taken and not level.stair_out.locked, "the key ring in the right box unlocks the stairs down")
	check(_game().current_todo() == level.TEXT.todo_key, "the to-do says to get everyone to the stairs")
	# Down: you come to on Mercer's cot now.
	p.take_damage(1000.0, "fall")
	for i in 120:
		await physics_frame
	check(level.safe_room_box.has_point(level.to_local(p.global_position)) and p.health > 0.0, "after the room is found, you come to inside it")
	for i in 60:
		await physics_frame
	# Everyone on the stairs, and the floor is done.
	level.stair_out.interact(p)
	for i in 30:
		await physics_frame
	check(level.stair_out.is_open, "with the key taken, E opens the stair door")
	var done := [false]
	level.completed.connect(func(): done[0] = true)
	p.global_transform = Transform3D(Basis(), level.to_global(L3_STAIRS_DOWN))
	for i in 600:
		await physics_frame
		if done[0]:
			break
	check(done[0] and _game().completed_level == "level_3", "everyone on the stairs completes the floor")
	check(root.get_node("/root/Net").profile.has_item("sticker/archive_label"), "finishing floor 18 unlocks the archive box label")
	level.queue_free()
	await process_frame


## In the World, the crew leaves 22 by the stairs and comes out on 18's landing, with
## play handed to floor 18 and floor 18 kept loaded once Mercer's room is found.
func test_level_3_stairs_from_22() -> void:
	print("World: the stairs from 22 down to 18")
	_game().new_run(5)
	_game().rourke_fate = "killed"  # just the security section: Rourke turned before it
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in 10:
		await physics_frame
	world.enter_wing(world.route_index("level_2"))
	var l2 = world.current
	for i in 30:
		await physics_frame
	check(l2 != null and l2.wing_id == "level_2" and not world.wings.has("level_3"), "floor 22 runs; floor 18 isn't built until the stairs open")
	l2.prepare_next()
	var l3 = world.wings.get("level_3")
	check(l3 != null and not l3.active and l3.global_position.distance_to(l2.global_position) > 30.0, "floor 18 builds apart from 22, behind its stairwell, without starting")
	check(world.db.table_names().has("access_log") and world.db.table_names().has("badge_log"), "both floors share the building's database")
	world.player.global_transform = Transform3D(Basis(), l2.to_global(STAIRS))
	for i in 5:
		await physics_frame
	# This player was downed on the stairs (the trigger counts downed players too). They
	# must still be carried down to 18, or their machine's World stays on 22.
	world.player.health = 0.0
	world.player.combat.down = true
	world.player.combat._lock(true)
	l2.sync.event("_on_exit", [null])
	for i in 600:
		await physics_frame
		if world.current == l3 and l3.active:
			break
	check(world.current == l3 and l3.active, "the stairs hand play to floor 18, even for a player who is down")
	check(L3_LANDING_BOX.has_point(l3.to_local(world.player.global_position)), "the crew steps out on 18's landing (%s)" % l3.to_local(world.player.global_position))
	check(_game().completed_level == "level_2" and _game().next_level == "level_3", "floor 22 is complete, floor 18 is next")
	check(root.get_node("/root/Net").profile.earned.has("achievement:floor_22"), "finishing floor 22 earns its unlock")
	for i in 60:
		await physics_frame
	check(world.player.input_locked and world.player.combat.down and world.current == l3, "a downed player stays down on the landing until revived")
	world.player.combat.revive()
	check(not world.player.input_locked and world.player.health > 0.0, "revived, controls come back on the landing")
	# Mercer's room is a hub: the wing stays loaded from here on.
	l3._enter_safe_room()
	check(world.keep_loaded.has("level_3"), "finding Mercer's room keeps floor 18 loaded for later floors")
	world.queue_free()
	await process_frame


## Co-op: the host decides the crank, the pickups and the exit; every machine sees them.
func test_coop_level_3() -> void:
	print("Co-op: Level 3 with a host and a client")
	_game().new_run(5)
	var worlds := await _coop_worlds(1)
	var machines := await _coop_load(worlds, "res://scenes/level_3.tscn")
	var host = machines[0]
	var client = machines[1]
	var client_id: int = get_multiplayer(worlds[1].get_path()).get_unique_id()
	check(machines.all(func(l): return l.sync._begun and l.players.count() == 2), "both machines start Level 3 with two players")
	check(machines.all(func(l): return l.data.host == host.data.host), "both machines hide the safe room behind the same room")
	var room: String = host.data.host
	client.cranks[room].interact(client.player)
	await _frames(180)
	check(machines.all(func(l): return l.cranked[room]) and client.shelving[room][0].position.is_equal_approx(host.shelving[room][0].position), "a client's crank rolls the shelving on every machine, to the same place")
	check(host.shredder.active and client.shredder.active and client.shredder.global_position.distance_to(host.shredder.global_position) < 0.5, "the crank wakes the Shredder on the host, and clients see it where the host has it")
	# A client types the lock's code: the host checks it, and the door unlocks everywhere.
	client.type_code("1234" if client.data.code != "1234" else "4321", client.player)
	await _frames(3)
	check(machines.all(func(l): return not l.safe_unlocked and l.safe_door.locked and l.lock.screen.text == l.TEXT.lock_wrong), "a wrong code on a client is refused on every machine")
	client.type_code(client.data.code, client.player)
	await _frames(3)
	check(machines.all(func(l): return l.safe_unlocked and not l.safe_door.locked and l.lock.screen.text == l.TEXT.lock_open), "the right code typed by a client unlocks Mercer's door on every machine")
	# A client sprinting: the host hears it from how fast the puppet moves.
	host.shredder.place(host.to_global(Vector3(-8, 0, -23.5)), host.to_global(Vector3(0, 0, -23.5)))
	host.shredder.state = "listening"
	client.player.global_transform = Transform3D(Basis(), client.to_global(Vector3(-1, 0.1, -23.5)))
	await _frames(15)
	for i in 30:
		client.player.global_position += client.global_basis * Vector3(0.1, 0, 0)  # 6 m/s
		await physics_frame
	await _frames(5)
	var puppet_pos: Vector3 = host.players.puppet(client_id).global_position
	check(host.shredder.state != "listening" and host.shredder.target_point.distance_to(puppet_pos) < 4.0, "the host's Shredder hears a client sprint and turns to where they are (state %s)" % host.shredder.state)
	host.shredder.place(host.to_global(host.SHREDDER_HOME), host.to_global(Vector3(-5.5, 0, -20)))
	host.shredder.state = "listening"
	await _frames(5)
	var net: Node = root.get_node("/root/Net")
	var before_floppy: Profile = net.profile
	net.profile = Profile.new()  # the test's machines share one Net: this save is the client's
	client.floppy.interact(client.player)
	client.key_dock.interact(client.player)
	await _frames(20)
	check(machines.all(func(l): return not l.key_taken and l.stair_out.locked), "the key box is taped on every machine until the desk names it")
	host.sync.event("_note_read")
	host.sync.event("_on_solved", ["unreturned", "desk"])
	await _frames(10)
	check(machines.all(func(l): return l.note_read and l.boxes_named and l.key_dock.openable() and not l.key_dock.tape.visible), "the note and the query untape the key box on every machine")
	client.key_dock.interact(client.player)
	await _frames(20)
	# (Every machine in a test shares one Game.inventory, so who took it is read off the dock.)
	var host_id: int = get_multiplayer(worlds[0].get_path()).get_unique_id()
	check(client.player.inventory.has("floppy_disk") and machines.all(func(l): return l.floppy_taken and not l.floppy.enabled and l.floppy.has_taken(client_id) and not l.floppy.has_taken(host_id)), "the one floppy goes to the player who took it")
	check(net.profile.has_item("clip/mercer_floppy"), "and so does Mercer's floppy, for their notebook")
	net.profile = before_floppy
	check(machines.all(func(l): return l.key_taken and not l.stair_out.locked), "the key unlocks the stairs on every machine")
	check(host.players.puppet(client_id) != null, "the host knows the client")
	# The exit waits for everyone.
	host.player.global_transform = Transform3D(Basis(), host.to_global(L3_STAIRS_DOWN))
	await _frames(20)
	check(_game().completed_level != "level_3", "one player on the stairs isn't enough")
	client.player.global_transform = Transform3D(Basis(), client.to_global(L3_STAIRS_DOWN))
	for i in 600:
		await physics_frame
		if _game().completed_level == "level_3":
			break
	check(_game().completed_level == "level_3", "with everyone on the stairs, the floor completes on every machine")
	await _coop_close(worlds)


## The Shredder: asleep among the machines until the first crank, then hunting by
## sound alone; the machines mask their own room; it grabs, holds, and throws.
func test_level_3_shredder() -> void:
	print("Level 3: the Shredder")
	_game().new_run(11)
	var level = load("res://scenes/level_3.tscn").instantiate()
	root.add_child(level)
	for i in 30:
		await physics_frame
	var s: Shredder = level.shredder
	var p: Player = level.player
	check(not s.active and s.state == "dormant" and s.is_on_floor() and level.SHRED_ROOM.has_point(level.to_local(s.global_position)), "it sleeps in the shredding room")
	check(not PlayerCombat.blockable("shredder"), "its throw can't be blocked")
	# Sprinting about before anything loud happens: nothing.
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(0, 0.1, 7)))
	await _frames(5)
	p.local_control = false  # scripted controls, not the keyboard
	p.controls.move = Vector2(0, -1)
	p.controls.sprint = true
	await _frames(45)
	p.controls.move = Vector2.ZERO
	p.controls.sprint = false
	p.local_control = true
	check(level.to_local(p.global_position).z < 4.0 and not s.active and s.state == "dormant", "a sprint through the lobby doesn't wake it: it's asleep (z %.1f, %s)" % [level.to_local(p.global_position).z, s.state])
	# Setting foot in the north corridor wakes it: the question that needs the night's
	# count hangs there, so that count is always typed with the Shredder up.
	check(level.find_children("NorthCorridor", "", true, false).size() == 1 and _doc(level, "Reader exceptions") != null and level.to_local(_doc(level, "Reader exceptions").global_position).z < -22.0, "the corridor has a trigger, and Security's sheet hangs past it")
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(-9.5, 0.1, -23.5)))
	for i in 20:
		await physics_frame
	check(level.shredder_awake and s.active and s.state == "listening" and level.hud._notice.text == level.TEXT.shredder_wakes_near, "setting foot in the north corridor wakes it, and the crew hears the machines stop (%s)" % s.state)
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(0, 0.1, 0)))
	for i in 5:
		await physics_frame
	# The first crank wakes it, and it heads for the sound.
	var host: String = level.data.host
	level.cranks[host].interact(p)
	await _frames(5)
	check(s.active and level.shredder_awake and s.state in ["turning", "investigating"], "the crank wakes it, and it turns toward the sound (%s)" % s.state)
	var crank_at: Vector3 = level.to_global(level.cranks[host].position)
	var d0: float = s.global_position.distance_to(crank_at)
	await _frames(360)
	var d1: float = s.global_position.distance_to(crank_at)
	check(d1 < d0 - 4.0 and level.room_doors["SHRED ROOM"].is_open and not level.room_doors["SHRED ROOM"].is_hinged(), "out through its room's open roll-up door, it walks toward where the crank was turned (%.1f m, then %.1f m)" % [d0, d1])
	# Doors: it pushes a shut door open if it swings away from it, and can't pull one.
	# (A west room whose shelving hasn't been cranked, so there's an aisle by the door.)
	var side: String = "MAP ROOM" if host != "MAP ROOM" else "VAULT C"
	var side_z: float = level.SIDE_ROOMS[side].center.z
	var side_door: Door = level.room_doors[side]
	s.place(level.to_global(Vector3(-9.8, 0, side_z)), level.to_global(Vector3(-13, 0, side_z)))
	s.state = "investigating"
	s.target_point = level.to_global(Vector3(-13, 0, side_z))
	s._timer = 10.0
	await _frames(60)
	check(not side_door.is_open and level.to_local(s.global_position).x > -11.0, "from the hall, a side room's door swings toward it: it can't pull it open, and stays out")
	s.place(level.to_global(Vector3(-12.0, 0, side_z)), level.to_global(Vector3(-9.5, 0, side_z)))
	s.state = "investigating"
	s.target_point = level.to_global(Vector3(-9.5, 0, side_z))
	s._timer = 10.0
	await _frames(60)
	check(side_door.is_open, "from inside, the same door swings away from it: it shoves it open on its way out")
	side_door.set_open(false, true)
	# Hearing: masked by its own machines, fading with distance.
	s.place(level.to_global(Vector3(-9, 0, -31.5)), level.to_global(Vector3(0, 0, -31.5)))
	s.state = "listening"
	check(not s.hear(level.to_global(Vector3(-1.5, 0, -32)), 1.0), "inside the shredding room, the machines drown out a sound 7 m away")
	check(s.hear(level.to_global(Vector3(-1.5, 0, -23.5)), 1.0), "the same sound out in the corridor is heard")
	s.state = "listening"
	var far: Vector3 = level.to_global(Vector3(-9, 0, -24.5))  # 7 m north, out in the corridor
	check(not s.hear(far, 0.15) and s.hear(far, Shredder.SPRINT_LOUDNESS), "seven metres off, footsteps are too quiet to hear and a sprint carries")
	s.state = "listening"
	check(not s.hear(level.to_global(Vector3(-9, 0, -20.5)), Shredder.SPRINT_LOUDNESS) and s.hear(level.to_global(Vector3(-9, 0, -20.5)), level.CRANK_LOUDNESS), "eleven metres off a sprint is lost, but a crank still carries")
	# Typing is loud: a setting, off by default. On, a burst of keys at a terminal is a sound.
	var sounds := []
	level.noise.connect(func(at, loud): sounds.append([at, loud]))
	level.desk.typing[1] = "SELECT room"
	level.desk.screen_changed.emit()
	check(sounds.is_empty() and not level.typing_is_loud, "by default, typing makes no sound")
	level.typing_is_loud = true
	level.desk.typing[1] = "SELECT room, C"
	level.desk.screen_changed.emit()
	check(sounds.is_empty(), "with the setting on, a few keys are still quiet")
	level.desk.typing[1] = "SELECT room, COUNT(*)"
	level.desk.screen_changed.emit()
	check(sounds.size() == 1 and sounds[0][1] == level.TYPING_LOUDNESS and sounds[0][0].distance_to(level.desk.global_position) < 0.5, "a burst of keys is one sound at the terminal")
	s.place(level.to_global(Vector3(-5.5, 0, -22.0)), level.to_global(Vector3(-5.5, 0, -10.0)))  # out in the corridor, clear of its machines
	check(not s.hear(level.desk.global_position, level.TYPING_LOUDNESS) and not s.hear(level.to_global(Vector3(-5.5, 0, -12.0)), level.TYPING_LOUDNESS) and s.hear(level.to_global(Vector3(-5.5, 0, -14.5)), level.TYPING_LOUDNESS), "it carries about half a sprint: not from the desk across the floor or from 10 m, but from a terminal 7.5 m off")
	level.typing_is_loud = false
	# Caught: it holds you, then throws you.
	s.place(level.to_global(Vector3(0, 0, -23.5)), level.to_global(Vector3(5, 0, -23.5)))
	s.state = "listening"
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(1.0, 0.1, -23.5)))
	await _frames(3)
	var start_health: float = p.health
	s.hear(p.global_position, 1.0)
	await _frames(70)
	check(s.state == "grabbing" and p.combat.grabbed_by == s and p.input_locked, "it picks you up and holds you: the tell before the throw (%s)" % s.state)
	await _frames(120)
	check(p.health <= start_health - Shredder.THROW_DAMAGE + 0.01 and p.health > 0.0 and not p.combat.down, "thrown: heavy damage, but one throw doesn't put you down from full health (%.0f)" % p.health)
	check(level.to_local(p.global_position).distance_to(Vector3(1.0, 0.1, -23.5)) > 2.0 and p.combat.grabbed_by == null, "you land well away from it, out of its hands")
	check(s.held == null and s.state != "grabbing", "after the throw it has let go, and goes back to listening for you (%s)" % s.state)
	level.queue_free()
	await process_frame


func test_level_3_book_huddles() -> void:
	print("Level 3: the book's floor 18 chapters")
	_game().new_run(11)
	var net := root.get_node("Net")
	var test_profile = net.profile
	net.profile = Profile.new()
	var level = load("res://scenes/level_3.tscn").instantiate()
	root.add_child(level)
	await _frames(30)
	var p: Player = level.player
	var h := _huddle_of(level)
	_doc(level, "Retention review memo").open_reader(p).close()
	for i in 300:  # the cut to the garage
		if h.is_running():
			break
		await physics_frame
	check(h.chapter.get("id", "") == "easy_sql_distinct" and p.input_locked, "reading the memo on the card catalogue brings back the DISTINCT chapter, round the garage bench")
	check(not level.shredder.is_physics_processing(), "the Shredder stands still while the crew is in the huddle")
	_doc(level, "Reader tally").open_reader(p).close()
	await _frames(5)
	check(h.chapter.get("id", "") == "easy_sql_distinct", "the tally read mid-huddle waits its turn")
	await _crew_reads([level])
	if not h.done.has("easy_sql_group_by"):
		check(not level.shredder.is_physics_processing(), "between the two huddles the Shredder still stands still")
		await _crew_reads([level])
	check(h.done.has("easy_sql_distinct") and h.done.has("easy_sql_group_by"), "then the tally brings back the COUNT and GROUP BY chapter")
	check(net.profile.earned.has("chapter:easy_sql_distinct") and net.profile.earned.has("chapter:easy_sql_group_by"), "both chapters are on the reader's profile")
	for i in 120:  # the cut back to floor 18
		if level.shredder.is_physics_processing():
			break
		await physics_frame
	check(level.shredder.is_physics_processing() and not p.input_locked, "afterwards the Shredder can move again, and so can the crew")
	_doc(level, "Retention review memo").open_reader(p).close()
	await _frames(10)
	check(not h.is_running(), "reading the memo again doesn't repeat the chapter")
	net.profile = test_profile
	level.queue_free()
	await process_frame


func test_level_1_book_huddle() -> void:
	print("Level 1: the book's COUNT chapter")
	_game().new_run(7)
	var net := root.get_node("Net")
	var test_profile = net.profile
	net.profile = Profile.new()
	var level = load("res://scenes/level_1.tscn").instantiate()
	root.add_child(level)
	await _frames(30)
	var p: Player = level.player
	var h := _huddle_of(level)
	var reader = _doc(level, "CONTROLLER RESET - SIGN-OFF").open_reader(p)
	await _frames(20)
	check(not h.is_running() and p.input_locked and reader.is_inside_tree(), "the cut waits while the sign-off form is still being read")
	reader.close()
	for i in 300:  # the cut to the garage
		if h.is_running():
			break
		await physics_frame
	check(h.chapter.get("id", "") == "easy_sql_count" and p.input_locked, "putting the sign-off form down brings back How many?, the COUNT chapter")
	await _crew_reads([level])
	await _frames(60)  # the cut back to floor 14
	check(h.done.has("easy_sql_count") and net.profile.earned.has("chapter:easy_sql_count") and not p.input_locked, "the crew reads it, it's on the profile, and the crew can move again")
	# In the World a paper's reader sits on its wing, under the World's huddle.
	var wing_script := GDScript.new()
	wing_script.source_code = "extends Node\nfunc finish_level() -> void:\n\tpass\n"
	wing_script.reload()
	var wing := Node.new()
	wing.set_script(wing_script)
	level.add_child(wing)
	var wing_reader := DocumentReader.new()
	wing.add_child(wing_reader)
	check(h._papers().has(wing_reader), "the huddle also waits for a paper open on a wing")
	net.profile = test_profile
	level.queue_free()
	await process_frame


func test_level_0_book_huddles() -> void:
	print("Ground floor: the book's chapters")
	_game().new_run(6)
	var net := root.get_node("Net")
	var test_profile = net.profile
	net.profile = Profile.new()
	var level = load("res://scenes/level_0.tscn").instantiate()
	root.add_child(level)
	await _frames(30)
	var p: Player = level.player
	var h := _huddle_of(level)
	_doc(level, "Visitor book").report_open(p)
	await _frames(10)
	check(level._books.get("easy_sql_4", "") == "found" and not h.is_busy(), "the visitor book read before the memo keeps Newest first for later")
	level.desk_terminal.enabled = true
	level.terminal_ui.terminal = level.desk_terminal
	level.terminal_ui.run("SELECT * FROM memo_fragments;")
	var nudged := func(): return Array(level.desk_terminal.transcript).any(func(l): return TerminalUI._plain(l).contains("add ORDER BY"))
	check(await _huddle_opens(level, "easy_sql_2") and not nudged.call(), "the scraps printing out of order bring back Putting things in order, before SYSOP's nudge")
	await _crew_reads([level])
	check(h.done.has("easy_sql_2") and net.profile.earned.has("chapter:easy_sql_2"), "the crew reads it, and it's on the profile")
	check(await _until(nudged, 5.0), "then SYSOP nudges toward ORDER BY")
	level.terminal_ui.terminal = level.desk_terminal
	level.terminal_ui.run("SELECT * FROM memo_fragments ORDER BY piece_no;")
	check(await _huddle_opens(level, "easy_sql_4"), "with the memo sorted, the visitor book's Newest first comes back")
	await _crew_reads([level])
	check(await _huddle_opens(level, "easy_sql_3", 90.0) and not level.caller_asked, "Rourke asks who called, and Just the columns you need comes back before the case opens")
	await _crew_reads([level])
	check(await _until(func(): return level.caller_asked, 10.0) and h.done.has("easy_sql_3") and h.done.has("easy_sql_4"), "then the caller case opens")
	level.queue_free()
	await process_frame
	# Sorted straight off, without the peek: ORDER BY's chapter still comes, once,
	# and there's nothing left for SYSOP to nudge.
	level = load("res://scenes/level_0.tscn").instantiate()
	root.add_child(level)
	await _frames(30)
	level.desk_terminal.enabled = true
	level.terminal_ui.terminal = level.desk_terminal
	level.terminal_ui.run("SELECT * FROM memo_fragments ORDER BY piece_no;")
	check(level.memo_puzzle.solved and await _huddle_opens(level, "easy_sql_2"), "the memo sorted without peeking still brings back the ORDER BY chapter")
	await _crew_reads([level])
	await _frames(30)
	h = _huddle_of(level)
	check(h.chapter.get("id", "") != "easy_sql_2" and not Array(level.desk_terminal.transcript).any(func(l): return TerminalUI._plain(l).contains("add ORDER BY")), "once, with no nudge after it")
	level.queue_free()
	await process_frame
	net.profile = test_profile


func test_level_1_book_huddles() -> void:
	print("Floor 14: the book's chapters")
	_game().new_run(7)
	var level = load("res://scenes/level_1.tscn").instantiate()
	root.add_child(level)
	await _frames(30)
	var p: Player = level.player
	var h := _huddle_of(level)
	_doc(level, "RACK MONITORING").report_open(p)
	await _frames(10)
	check(not h.is_busy() and level._books.get("easy_sql_7", "") == "found", "the rack card read before the self-test waits")
	_doc(level, "NOC SHIFT LOG").report_open(p)
	check(await _huddle_opens(level, "easy_sql_5"), "the NOC shift log brings back Keeping only some rows")
	await _crew_reads([level])
	level._on_asked()
	check(await _huddle_opens(level, "easy_sql_6") and level.terminal.locked, "the self-test brings back Both must be true, before the terminal opens")
	await _crew_reads([level])
	check(await _until(func(): return not level.terminal.locked, 5.0) and h.done.has("easy_sql_5") and h.done.has("easy_sql_6"), "then the terminal opens, the shift log's chapter not read twice")
	_doc(level, "RACK MONITORING").report_open(p)
	check(await _huddle_opens(level, "easy_sql_7"), "the rack card read again brings back More than, less than")
	await _crew_reads([level])
	var dead: Document = level.find_children("*", "Document", true, false).filter(func(d): return d.plain_text().contains("Bulb's dead AGAIN"))[0]
	dead.report_open(p)
	check(await _huddle_opens(level, "easy_sql_8"), "the break room's sticky brings back Either one will do")
	await _crew_reads([level])
	await _until(func(): return not h.is_busy(), 10.0)  # the cut back to floor 14
	_doc(level, "Fire interlock").report_open(p)
	_doc(level, "LIGHTING CIRCUITS").report_open(p)
	await _frames(20)
	check(not h.is_busy() and ["easy_sql_7", "easy_sql_8"].all(func(id): return h.done.has(id)), "each plays once")
	level.queue_free()
	await process_frame
