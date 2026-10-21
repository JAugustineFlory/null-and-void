extends RefCounted
## Floor 10, the Power Plant (Level 4): its data across seeds, the breaker panel's
## UPDATE ... WHERE (and what forgetting the WHERE does), the read-back, and the
## contractor log's INSERT. Run in the floor_10 group.

var t: SceneTree
var _check: Callable
## On the stairwell landing by 10's west-wall door (Level 4 local).
const LANDING_BOX := AABB(Vector3(-7.0, -0.5, 4.0), Vector3(3.2, 2.5, 4.0))


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("Floor 10: the Power Plant")
	test_data_every_seed()
	await test_scene()
	await test_right_first_time()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func _game() -> Node:
	return t.root.get_node("/root/Game")


func _frames(n: int) -> void:
	for i in n:
		await t.physics_frame


func _doc(level: Node, title_part: String) -> Node:
	for d in level.find_children("*", "Document", true, false):
		if d.title.contains(title_part):
			return d
	return null


## The query the last hint says to type: the white line in it.
func _last_hint_query(p: Puzzle) -> String:
	var h: String = p.hints[-1]
	var from := h.find("[color=#ffffff]") + "[color=#ffffff]".length()
	return h.substr(from, h.find("[/color]") - from).strip_edges()


## A level script with its puzzles built for `run_seed`, outside the tree.
func _stations(run_seed: int) -> Node:
	var lvl = load("res://scripts/levels/level_4.gd").new()
	lvl.data = Level4Data.build(run_seed, "WO-%05d" % (run_seed % 100000))
	lvl._make_puzzles()
	return lvl


func _fresh_db(data: Dictionary) -> FacilityDB:
	var db := FacilityDB.new()
	db.load_seed(data.sql)
	return db


func test_data_every_seed() -> void:
	print("Floor 10: data and stations across seeds")
	var ok_shape := true
	var ok_reasons := true
	var ok_reset := true
	var ok_no_where := true
	var ok_wrong_row := true
	var ok_login := true
	var ok_wrong_insert := true
	var ok_hints := true
	var targets := {}
	for s in range(1, 61):
		var lvl = _stations(s)
		var data: Dictionary = lvl.data
		var db := _fresh_db(data)
		targets[data.target] = true
		var rows := db.run_silent("SELECT * FROM breakers")
		var ids := {}
		for r in rows:
			ids[r["id"]] = true
		var tripped := db.run_silent("SELECT id FROM breakers WHERE circuit = 'PLANT CONTROL' AND state = 'tripped'")
		ok_shape = ok_shape and rows.size() == 12 and ids.size() == 12 and tripped.size() == 1 and tripped[0]["id"] == data.target \
			and db.run_silent("SELECT state FROM breakers WHERE id = 'CB-03' AND circuit = 'RISER FANS'")[0]["state"] == "on"
		# Every other breaker that isn't on says why, so SELECT * rules it out.
		ok_reasons = ok_reasons and db.run_silent("SELECT id FROM breakers WHERE state != 'on' AND id != '%s' AND (note IS NULL OR note = '')" % data.target).is_empty() \
			and db.run_silent("SELECT id FROM breakers WHERE state != 'on'").size() == 4
		# The right UPDATE passes, and so does its last hint.
		var r := db.execute(lvl.reset_puzzle.solution_sql)
		ok_reset = ok_reset and lvl.reset_puzzle.matches(db, r)
		var db2 := _fresh_db(data)
		ok_hints = ok_hints and lvl.reset_puzzle.matches(db2, db2.execute(_last_hint_query(lvl.reset_puzzle)))
		ok_hints = ok_hints and lvl.check_puzzle.matches(db2, db2.execute(_last_hint_query(lvl.check_puzzle)))
		# No WHERE: every breaker goes on. Not the answer, until the others go back.
		var db3 := _fresh_db(data)
		r = db3.execute("UPDATE breakers SET state = 'on'")
		ok_no_where = ok_no_where and r.changes == 12 and not lvl.reset_puzzle.matches(db3, r)
		for row in data.breakers:
			if row[0] != data.target and row[3] != "on":
				r = db3.execute("UPDATE breakers SET state = '%s' WHERE id = '%s'" % [row[3], row[0]])
		ok_no_where = ok_no_where and lvl.reset_puzzle.matches(db3, r)
		# The tempting wrong rows: the bay's tripped breaker, the circuit name in the
		# id's place (matches nothing), and the work order's own example.
		var db4 := _fresh_db(data)
		ok_wrong_row = ok_wrong_row and not lvl.reset_puzzle.matches(db4, db4.execute("UPDATE breakers SET state = 'on' WHERE id = '%s'" % data.bay_breaker))
		ok_wrong_row = ok_wrong_row and db4.execute("UPDATE breakers SET state = 'on' WHERE id = 'PLANT CONTROL'").changes == 0
		ok_wrong_row = ok_wrong_row and not lvl.reset_puzzle.matches(db4, db4.execute("UPDATE breakers SET state = 'on' WHERE id = 'CB-03'"))
		# The contractor log: the right row passes, and so does its last hint.
		var db5 := _fresh_db(data)
		r = db5.execute(lvl.login_puzzle.solution_sql)
		ok_login = ok_login and lvl.login_puzzle.matches(db5, r)
		var db6 := _fresh_db(data)
		ok_login = ok_login and lvl.login_puzzle.matches(db6, db6.execute(_last_hint_query(lvl.login_puzzle)))
		# Wrong order, no quotes, the wrong table, the clipboard's example copied, no column list.
		var db7 := _fresh_db(data)
		r = db7.execute("INSERT INTO contractor_log (company, job, time_in) VALUES ('%s', '%s', '%s')" % [data.ticket, data.company, data.time_in])
		ok_wrong_insert = ok_wrong_insert and r.ok and not lvl.login_puzzle.matches(db7, r)
		r = db7.execute("INSERT INTO contractor_log (company, job, time_in) VALUES ('%s', %s, '%s')" % [data.company, data.ticket.replace("-", ""), data.time_in])
		ok_wrong_insert = ok_wrong_insert and not r.ok
		r = db7.execute("INSERT INTO contractors VALUES ('%s', '%s', '%s')" % [data.company, data.ticket, data.time_in])
		ok_wrong_insert = ok_wrong_insert and not r.ok
		r = db7.execute("INSERT INTO contractor_log (company, job, time_in) VALUES ('%s', '%s', '%s')" % data.example_log)
		ok_wrong_insert = ok_wrong_insert and r.ok and not lvl.login_puzzle.matches(db7, r)
		# The plain VALUES form is a value short: log_no is the fourth column.
		r = db7.execute("INSERT INTO contractor_log VALUES ('%s', '%s', '%s')" % [data.company, data.ticket, data.time_in])
		ok_wrong_insert = ok_wrong_insert and not r.ok
		r = db7.execute("SELECT * FROM contractor_log")
		ok_wrong_insert = ok_wrong_insert and not lvl.login_puzzle.matches(db7, r)
		lvl.free()
	check(ok_shape, "twelve breakers every run, one PLANT CONTROL tripped, the work order's example CB-03 always the riser fans")
	check(ok_reasons, "every breaker left off or tripped has a tag saying why (the bay, the lift contractor, floor 11)")
	check(targets.size() >= 6, "tonight's breaker id changes with the seed (%d ids over 60 runs)" % targets.size())
	check(ok_reset and ok_hints, "the right UPDATE and every last hint pass, across 60 seeds")
	check(ok_no_where, "no WHERE flips all twelve and doesn't pass; putting the others back does")
	check(ok_wrong_row, "the bay's breaker, the circuit name as the id, and the example's CB-03 don't pass")
	check(ok_login, "the crew's own log row passes, and so does the last hint, across 60 seeds")
	check(ok_wrong_insert, "wrong column order, an unquoted value, the wrong table, the clipboard's example, no column list and a plain read don't pass")


func test_scene() -> void:
	print("Floor 10: the switchgear hall and the control room")
	_game().new_run(31)
	var level = load("res://scenes/level_4.tscn").instantiate()
	t.root.add_child(level)
	await _frames(30)
	var p: Player = level.player
	var data: Dictionary = level.data
	check(LANDING_BOX.has_point(level.to_local(p.global_position)) and p.is_on_floor(), "players start on 10's stair landing (%s)" % level.to_local(p.global_position))
	check(level.stair_in.is_open and level.stair_out.locked and not level.stair_out.is_open, "the door in from the stairs is wedged; the stairs down are held shut")
	check(_doc(level, "Stair notice") != null and _doc(level, "Stair notice").plain_text().contains("CLOSED BELOW 10"), "a notice by the stairs down says why they're shut")
	check(not level.ctrl_door.is_open and level.lights["L10-CTRL"].all(func(l): return not l.visible), "the control room is dark and its door shut")
	check(level.db.run_silent("SELECT locked, actuator_fault FROM doors WHERE id = 'PLANT-CTRL'")[0] == {"locked": 0, "actuator_fault": 1},
		"the doors table says the control room is unlocked, with its actuator faulted: no power")
	check(level.lamps.size() == 12 and level.find_children("*", "Document", true, false).filter(func(d): return d.title == "Breaker tag").size() == 5,
		"a box with a lamp for every breaker, and a tag on each one with a note")
	check(level.maint.puzzles.all(func(pz): return pz.hints.size() == 3) and level.controller.puzzles.all(func(pz): return pz.hints.size() == 3), "every station has a three-step hint ladder")
	var ui: TerminalUI = level.terminal_ui
	ui.terminal = level.maint
	check(level.maint.next_hint().contains("UPDATE breakers SET state = 'on' WHERE id = '?'"), "the first hint is the UPDATE's shape with the breaker as ?")
	var wo: Node = _doc(level, "Facilities work order")
	check(wo != null and wo.plain_text().contains("UPDATE breakers SET state = 'on' WHERE id = 'CB-03';") and not wo.plain_text().contains(data.target), "the work order shows last month's UPDATE, not tonight's breaker")
	wo.open_reader(p).close()
	await _frames(3)
	check(_game().case_info("power").get("open", false) and _game().current_todo() == level.TEXT.todo_power, "reading the work order opens the power case and sets the to-do")
	ui.run("UPDATE breakers SET state = 'on' WHERE id = 'PLANT CONTROL'")
	await _frames(2)
	check(not level.power_back and Array(level.maint.transcript).any(func(l): return TerminalUI._plain(l).contains(level.TEXT.tip_zero)), "the circuit's name in the id's place changes nothing, and SYSOP says to look at the row first")
	# No WHERE: loud and costly, never dangerous.
	ui.run("UPDATE breakers SET state = 'on'")
	await _frames(5)
	check(level.alarm and level.bay_powered and not level.reset_puzzle.solved and _game().current_todo() == level.TEXT.todo_put_back,
		"no WHERE: every breaker flips, the alarm goes, the bay stirs, and the to-do says to put them back")
	check(level.lights["L10-BAY"].all(func(l): return l.visible) and not level.bay_door.is_open and level.db.run_silent("SELECT locked FROM doors WHERE id = 'PLANT-BAY'")[0]["locked"] == 1, "the bay lights up behind its door, which stays shut")
	check(level.power_back and Array(level.maint.transcript).any(func(l): return TerminalUI._plain(l).contains(level.TEXT.tip_no_where)), "the control room gets its power anyway, and SYSOP explains what no WHERE did")
	for row in data.breakers:
		if row[0] != data.target and row[3] != "on":
			ui.run("UPDATE breakers SET state = '%s' WHERE id = '%s'" % [row[3], row[0]])
	await _frames(5)
	check(not level.alarm and not level.bay_powered and level.reset_puzzle.solved, "with the others put back one WHERE at a time, the alarm stops and the reset passes")
	await _frames(90)
	check(level.ctrl_door.is_open and level.lights["L10-CTRL"].all(func(l): return l.visible), "the control room's lights are on and its door has opened")
	# Read back: the sign-off.
	ui.run("SELECT state FROM breakers WHERE id = '%s'" % data.bay_breaker)
	check(not level.check_puzzle.solved, "reading back the wrong breaker doesn't sign it off")
	ui.run("SELECT * FROM breakers WHERE id = '%s'" % data.target)
	await _frames(2)
	check(level.check_puzzle.solved and _game().case_info("power").get("solved", false) and _game().case_info("power").how.contains(data.target), "reading tonight's breaker back signs off the work order, and the power case names it")
	# The control room: the contractor log.
	ui.terminal = level.controller
	var board: Node = _doc(level, "Contractor log")
	check(board != null and board.plain_text().contains("INSERT INTO contractor_log (company, job, time_in) VALUES") and not board.plain_text().contains(data.ticket), "the clipboard shows another contractor's INSERT, not the crew's")
	check(level.CTRL_ROOM.has_point(level.to_local(board.global_position)) and level.find_children("Clock", "Label3D", true, false).size() == 1, "the clipboard and the clock are in the control room")
	board.open_reader(p).close()
	await _frames(3)
	check(_game().current_todo() == level.TEXT.todo_login, "reading the clipboard sets the log-in to-do")
	ui.run("INSERT INTO contractor_log VALUES ('%s', '%s', '%s')" % [data.company, data.ticket, data.time_in])
	check(not level.login_puzzle.solved and Array(level.controller.transcript).any(func(l): return TerminalUI._plain(l).contains(level.TEXT.tip_count)), "without the column list it's a value short, and SYSOP says to name the columns")
	ui.run("INSERT INTO contractor_log (company, job, time_in) VALUES ('%s', '%s', '%s')" % [data.ticket, data.company, data.time_in])
	await _frames(2)
	check(not level.login_puzzle.solved and Array(level.controller.transcript).any(func(l): return TerminalUI._plain(l).contains(level.TEXT.tip_order)), "values in the wrong columns go in, don't count, and SYSOP says the column order")
	ui.run("INSERT INTO contractor_log (company, job, time_in) VALUES ('Byte-Right IT Services', %s, '%s')" % [data.ticket.replace("-", ""), data.time_in])
	await _frames(2)
	check(not level.login_puzzle.solved and Array(level.controller.transcript).any(func(l): return TerminalUI._plain(l).contains(level.TEXT.tip_quotes)), "an unquoted value is an error, and SYSOP says to quote it")
	ui.run("INSERT INTO visitors VALUES ('%s', '%s', '%s')" % [data.company, data.ticket, data.time_in])
	check(not level.login_puzzle.solved, "the wrong table doesn't count")
	ui.run("insert into contractor_log (company, job, time_in) values ('byte-right it services', '%s', '%s')" % [data.ticket.to_lower(), data.time_in])
	await _frames(2)
	check(level.login_puzzle.solved and level.logged_in and _game().case_info("login").get("solved", false), "the crew's own row logs it in, whatever the capitals")
	level.queue_free()
	await t.process_frame


## The right UPDATE first time: no alarm, the station passes, and SYSOP nudges the read-back.
func test_right_first_time() -> void:
	print("Floor 10: the reset done right")
	_game().new_run(8)
	var level = load("res://scenes/level_4.tscn").instantiate()
	t.root.add_child(level)
	await _frames(20)
	var ui: TerminalUI = level.terminal_ui
	ui.terminal = level.maint
	ui.run(_last_hint_query(level.reset_puzzle))
	await _frames(3)
	check(level.reset_puzzle.solved and level.power_back and not level.alarm and not level.bay_powered, "the right breaker, first time: no alarm, the bay stays dark, the power's back")
	check(Array(level.maint.transcript).any(func(l): return TerminalUI._plain(l).contains(level.TEXT.tip_verify)) and not level.check_puzzle.solved, "SYSOP asks whether it took; the sign-off is still open")
	ui.run(_last_hint_query(level.check_puzzle))
	check(level.check_puzzle.solved, "the last hint's read-back signs it off")
	level.queue_free()
	await t.process_frame
