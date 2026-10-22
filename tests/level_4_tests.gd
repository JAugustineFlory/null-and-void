extends RefCounted
## Floor 10, the Power Plant (Level 4): its data across seeds, the breaker panel's
## UPDATE ... WHERE (and what forgetting the WHERE does), the read-back, the
## contractor log's INSERT, the main_doors accident, the Custodian, its bay's
## lockout, and the way down. Run in the floor_10 group.

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
	await test_accident()
	await test_gantry()
	await test_custodian_follows()
	await test_world()
	await test_book_huddles()
	await test_coop()


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


## Every query a hint says to type (its white lines).
func _hint_queries(h: String) -> Array:
	var out := []
	var at := h.find("[color=#ffffff]")
	while at >= 0:
		var from := at + "[color=#ffffff]".length()
		out.append(h.substr(from, h.find("[/color]", from) - from).strip_edges())
		at = h.find("[color=#ffffff]", from)
	return out


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
	var ok_doors := true
	var ok_lockout := true
	var ok_gantry := true
	var hatch_bays := {}
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
		# Put back to 'off' rather than the word each had ('tripped'): as back, by the lamps.
		var db3b := _fresh_db(data)
		db3b.execute("UPDATE breakers SET state = 'on'")
		for id in data.decoys:
			r = db3b.execute("UPDATE breakers SET state = 'off' WHERE id = '%s'" % id)
		ok_no_where = ok_no_where and lvl.reset_puzzle.matches(db3b, r)
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
		# main_doors: the night card's door, and its row says what it really is.
		var db8 := _fresh_db(data)
		ok_doors = ok_doors and db8.run_silent("SELECT zone, locked FROM doors WHERE id = 'main_doors'") == [{"zone": "CONTAINMENT", "locked": 1}]
		ok_doors = ok_doors and not lvl.main_doors_puzzle.matches(db8, db8.execute("UPDATE doors SET locked = 0 WHERE id = 'PLANT-CTRL'"))
		ok_doors = ok_doors and not lvl.main_doors_puzzle.matches(db8, db8.execute("SELECT * FROM doors"))
		ok_doors = ok_doors and lvl.main_doors_puzzle.matches(db8, db8.execute(_last_hint_query(lvl.main_doors_puzzle)))
		# The bay's lockout: the right row and the last hint pass; the wrong breaker,
		# the columns swapped and the lift contractor's own row don't.
		var db9 := _fresh_db(data)
		ok_lockout = ok_lockout and not lvl.lockout_puzzle.state_ok(db9) and db9.run_silent("SELECT COUNT(*) AS n FROM lockouts")[0]["n"] == 1
		ok_lockout = ok_lockout and not lvl.lockout_puzzle.matches(db9, db9.execute("INSERT INTO lockouts (breaker, company, job) VALUES ('%s', '%s', '%s')" % [data.target, data.company, data.ticket]))
		ok_lockout = ok_lockout and not lvl.lockout_puzzle.matches(db9, db9.execute("INSERT INTO lockouts (breaker, company, job) VALUES ('%s', '%s', '%s')" % [data.company, data.bay_breaker, data.ticket]))
		ok_lockout = ok_lockout and not lvl.lockout_puzzle.matches(db9, db9.execute("SELECT * FROM lockouts"))
		r = db9.execute(_last_hint_query(lvl.lockout_puzzle))
		ok_lockout = ok_lockout and lvl.lockout_puzzle.matches(db9, r)
		ok_lockout = ok_lockout and lvl.readback_puzzle.matches(db9, db9.execute(_last_hint_query(lvl.readback_puzzle))) \
			and lvl.readback_puzzle.matches(db9, db9.execute("SELECT * FROM lockouts WHERE breaker = '%s'" % data.bay_breaker)) \
			and not lvl.readback_puzzle.matches(db9, db9.execute("SELECT * FROM breakers WHERE id = '%s'" % data.bay_breaker))
		# The gantry: parked at one end, the panel's bay at the other. The parking bay,
		# the card's example bay, a quoted number and a read don't pass; the last hint does.
		hatch_bays[data.hatch_bay] = true
		var db10 := _fresh_db(data)
		ok_gantry = ok_gantry and data.hatch_bay + data.park_bay == 5 and db10.run_silent("SELECT bay, raised FROM gantry WHERE id = 'GA-1'") == [{"bay": data.park_bay, "raised": 0}]
		ok_gantry = ok_gantry and not lvl.gantry_puzzle.matches(db10, db10.execute("UPDATE gantry SET bay = 3 WHERE id = 'GA-1'"))
		ok_gantry = ok_gantry and not lvl.gantry_puzzle.matches(db10, db10.execute("UPDATE gantry SET bay = %d WHERE id = 'GA-1'" % data.park_bay))
		ok_gantry = ok_gantry and not lvl.gantry_puzzle.matches(db10, db10.execute("SELECT * FROM gantry"))
		ok_gantry = ok_gantry and db10.execute("UPDATE gantry SET bay = %d WHERE id = 'GA1'" % data.hatch_bay).changes == 0
		ok_gantry = ok_gantry and lvl.gantry_puzzle.matches(db10, db10.execute(_last_hint_query(lvl.gantry_puzzle)))
		lvl.free()
	check(ok_shape, "twelve breakers every run, one PLANT CONTROL tripped, the work order's example CB-03 always the riser fans")
	check(ok_reasons, "every breaker left off or tripped has a tag saying why (the bay, the lift contractor, floor 11)")
	check(targets.size() >= 6, "tonight's breaker id changes with the seed (%d ids over 60 runs)" % targets.size())
	check(ok_reset and ok_hints, "the right UPDATE and every last hint pass, across 60 seeds")
	check(ok_no_where, "no WHERE flips all twelve and doesn't pass; putting the others back does")
	check(ok_wrong_row, "the bay's breaker, the circuit name as the id, and the example's CB-03 don't pass")
	check(ok_login, "the crew's own log row passes, and so does the last hint, across 60 seeds")
	check(ok_wrong_insert, "wrong column order, an unquoted value, the wrong table, the clipboard's example, no column list and a plain read don't pass")
	check(ok_doors, "main_doors's row says CONTAINMENT; another door or a read doesn't open it, the last hint does")
	check(ok_gantry and hatch_bays.size() == 2, "the gantry parks at one end and the panel's bay is the other (both ways round over 60 runs); only moving it there passes")
	check(ok_lockout, "the bay's lockout row and its last hint pass, and the read-back reads it; the wrong breaker, swapped columns and a read don't")


func test_scene() -> void:
	print("Floor 10: the switchgear hall and the control room")
	_game().new_run(31)
	var level = load("res://scenes/level_4.tscn").instantiate()
	t.root.add_child(level)
	await _frames(30)
	_chapters_read([level])
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
	check(level.maint.puzzles.all(func(pz): return pz.hints.size() == 3) and level.controller.puzzles.all(func(pz): return pz.hints.size() == (2 if pz.id == "login_read" else 3)) \
		and level.bay_terminal.puzzles.all(func(pz): return pz.hints.size() == 2), "every new write has a three-step hint ladder; the log's and the bay's read-backs, two-step reviews")
	var ui: TerminalUI = level.terminal_ui
	ui.terminal = level.maint
	check(level.maint.next_hint().contains("UPDATE breakers SET state = 'on' WHERE id = 'enter_breaker_id'"), "the first hint is the UPDATE's shape with the breaker left blank")
	var wo: Node = _doc(level, "Facilities work order")
	check(wo != null and wo.plain_text().contains("UPDATE breakers SET state = 'on' WHERE id = 'CB-03';") and not wo.plain_text().contains(data.target), "the work order shows last month's UPDATE, not tonight's breaker")
	wo.open_reader(p).close()
	await _frames(3)
	check(_game().case_info("power").get("open", false) and _game().current_todo() == level.TEXT.todo_power, "reading the work order opens the power case and sets the to-do")
	ui.run("UPDATE breakers SET state = 'on' WHERE id = 'CB-03'")
	await _frames(2)
	check(not level.alarm and _said(level.maint, level.TEXT.tip_example), "copying the work order's CB-03 changes a row that was already on, and SYSOP says so")
	ui.run("UPDATE breakers SET state = 'on' WHERE id = 'PLANT CONTROL'")
	await _frames(2)
	check(not level.power_back and Array(level.maint.transcript).any(func(l): return TerminalUI._plain(l).contains(level.TEXT.tip_zero)), "the circuit's name in the id's place changes nothing, and SYSOP says to look at the row first")
	check(_said(level.maint, "0 rows changed.") and not _said(level.maint, "(0 rows)"), "a write that matches nothing says 0 rows changed, not an empty read's (0 rows)")
	# One decoy reset on its own (the bay, the likeliest wrong pick): the alarm, said as one.
	ui.run("UPDATE breakers SET state = 'on' WHERE id = '%s'" % data.bay_breaker)
	await _frames(2)
	check(level.alarm and level.alarm_line == level.TEXT.alarm_one and _game().current_todo() == level.TEXT.todo_put_back, "one decoy reset: the alarm says a breaker clunked over, not the whole panel")
	ui.run("UPDATE breakers SET state = 'off' WHERE id = '%s'" % data.bay_breaker)
	await _frames(2)
	check(not level.alarm and _game().current_todo() == level.TEXT.todo_power, "put back, the alarm stops and the to-do is the reset again")
	# No WHERE: loud and costly, never dangerous.
	ui.run("UPDATE breakers SET state = 'on'")
	await _frames(5)
	check(level.alarm and level.bay_powered and not level.reset_puzzle.solved and level.alarm_line == level.TEXT.alarm and _game().current_todo() == level.TEXT.todo_put_back,
		"no WHERE: every breaker flips, the alarm goes, the bay stirs, and the to-do says to put them back")
	check(level.lights["L10-BAY"].all(func(l): return l.visible) and not level.bay_door.is_open and level.db.run_silent("SELECT locked FROM doors WHERE id = 'PLANT-BAY'")[0]["locked"] == 1, "the bay lights up behind its door, which stays shut")
	check(level.power_back and Array(level.maint.transcript).any(func(l): return TerminalUI._plain(l).contains(level.TEXT.tip_no_where)), "the control room gets its power anyway, and SYSOP explains what no WHERE did")
	# While the alarm sounds, .hint is the put-back ladder; its last tier stops it.
	var h1: String = level.maint.next_hint()
	level.maint.next_hint()
	var fixes := _hint_queries(level.maint.next_hint())
	check(h1.contains("SET state = 'off' WHERE id = 'enter_breaker_id'") and fixes.size() == data.decoys.size(), "during the alarm the hints are for putting the others back, ending on one UPDATE per breaker (%d)" % fixes.size())
	ui.run(fixes[0])
	await _frames(2)
	check(level.alarm and _hint_queries(level.maint.next_hint()).size() == data.decoys.size() - 1, "one back isn't all: the alarm goes on, and the last hint lists only the rest")
	# The rest back to 'off', not the words they had: the lamps can't tell, nor can the panel.
	for id in data.decoys:
		ui.run("UPDATE breakers SET state = 'off' WHERE id = '%s'" % id)
	await _frames(5)
	check(not level.alarm and not level.bay_powered and level.reset_puzzle.solved and level.put_back_puzzle.solved, "with the others put back one WHERE at a time (to 'off'), the alarm stops and the reset passes")
	check(_game().current_todo() == level.TEXT.todo_check, "the to-do asks for the read-back")
	await _frames(90)
	check(level.ctrl_door.is_open and level.lights["L10-CTRL"].all(func(l): return l.visible), "the control room's lights are on and its door has opened")
	# Read back: the sign-off.
	ui.run("SELECT state FROM breakers WHERE id = '%s'" % data.bay_breaker)
	check(not level.check_puzzle.solved, "reading back the wrong breaker doesn't sign it off")
	ui.run("SELECT * FROM breakers")
	await _frames(2)
	check(level.check_puzzle.solved and _game().case_info("power").get("solved", false) and _game().case_info("power").how.contains(data.target), "reading the panel back, tonight's breaker on, signs off the work order, and the power case names it")
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
	check(level.login_puzzle.solved and not level.logged_in and _game().current_todo() == level.TEXT.todo_login_read, "the crew's own row goes in, whatever the capitals; it counts once it's read back")
	ui.run("UPDATE doors SET locked = 0 WHERE id = 'PLANT-BAY'")
	await _frames(2)
	check(_said(level.controller, level.TEXT.refused_readback) and level.db.run_silent("SELECT locked FROM doors WHERE id = 'PLANT-BAY'")[0]["locked"] == 1, "a door write before the read-back is refused, and says to read it back")
	ui.run("SELECT * FROM contractor_log")
	await _frames(2)
	check(level.logged_in and level.login_read_puzzle.solved and _game().case_info("login").get("solved", false) and _game().current_todo() == "", "the whole log read back logs the crew in")
	check(_doc(level, "Contractor log").plain_text().contains("read it back, or it doesn't count"), "the clipboard says the log-in counts once it's read back")
	check(level.gantry_puzzle.solved, "with the control room's door open, the gantry station is done (.hint doesn't send the crew up the mast)")
	level.queue_free()
	await t.process_frame


## The right UPDATE first time: no alarm, the station passes, and SYSOP nudges the read-back.
func test_right_first_time() -> void:
	print("Floor 10: the reset done right")
	_game().new_run(8)
	var level = load("res://scenes/level_4.tscn").instantiate()
	t.root.add_child(level)
	await _frames(20)
	_chapters_read([level])
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


func _said(term: Terminal, line: String) -> bool:
	return Array(term.transcript).any(func(l): return TerminalUI._plain(l).contains(line))


## Floor 10's chapters count as read on these levels: the tests here are about the
## stations. The chapters opening at their papers is test_book_huddles.
func _chapters_read(levels: Array) -> void:
	for l in levels:
		for id in ["easy_sql_update", "easy_sql_insert"]:
			l.get_node("Huddle").done[id] = true


func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await t.physics_frame
	return cond.call()


## The bay breaker's state in the table.
func _bay_state(level: Node) -> String:
	return str(level.db.run_silent("SELECT state FROM breakers WHERE id = '%s'" % level.data.bay_breaker)[0]["state"])


## main_doors (refused until the crew logs in), the accident, the Custodian loose,
## its power cut and put back, the bay's lockout (lapsed, then read back), the way down.
func test_accident() -> void:
	print("Floor 10: main_doors, the Custodian and its bay")
	_game().new_run(12)
	var level = load("res://scenes/level_4.tscn").instantiate()
	t.root.add_child(level)
	await _frames(20)
	_chapters_read([level])
	level.completed.disconnect(level._on_completed)
	var p: Player = level.player
	var data: Dictionary = level.data
	var ui: TerminalUI = level.terminal_ui
	var net: Node = t.root.get_node("/root/Net")
	var had: Array = net.profile.earned.duplicate()
	net.profile.earned.erase("achievement:main_doors_warning")
	ui.terminal = level.maint
	ui.run(_last_hint_query(level.reset_puzzle))
	await _frames(3)
	# The floor's rule: no door writes before a contractor has logged in.
	ui.terminal = level.controller
	ui.run(_last_hint_query(level.main_doors_puzzle))
	await _frames(2)
	check(not level.accident and level.db.run_silent("SELECT locked FROM doors WHERE id = 'main_doors'")[0]["locked"] == 1 and _said(level.controller, level.TEXT.refused_login),
		"before the crew logs in, the controller refuses a door write and says why")
	ui.terminal = level.maint
	ui.run("UPDATE doors SET locked = 0 WHERE id = 'PLANT-BAY'")
	await _frames(2)
	check(level.db.run_silent("SELECT locked FROM doors WHERE id = 'PLANT-BAY'")[0]["locked"] == 1 and not level.bay_door.is_open, "so does the plant terminal: the bay stays shut")
	var card: Node = _doc(level, "Facilities notice")
	check(card != null and card.plain_text().contains("main_doors") and card.plain_text().contains("decommissioned") and level.CTRL_ROOM.has_point(level.to_local(card.global_position)), "Facilities' notice in the control room names main_doors as the fire exit (option A)")
	var sticky: Node = level.find_child("EarlyWarning", true, false)
	check(sticky.global_position.distance_to(card.global_position) < 1.0, "the never-open sticky is pinned right beside the notice, for the careful crew")
	# The observant crew's find: the earlier copy of the warning, read before.
	level.find_child("EarlyWarning", true, false).open_reader(p).close()
	await _frames(3)
	check(net.profile.earned.has("achievement:main_doors_warning"), "reading the warning before the accident earns the observant crew's find")
	ui.terminal = level.controller
	ui.run(_last_hint_query(level.login_puzzle))
	ui.run(_last_hint_query(level.login_read_puzzle))
	await _frames(3)
	check(level.logged_in, "the crew logs in and reads the log back")
	# The accident.
	ui.run(_last_hint_query(level.main_doors_puzzle))
	await _frames(5)
	check(level.accident and level.main_doors_puzzle.solved and _game().case_info("main_doors").get("solved", false), "opening main_doors is the accident, and its case page names what it was")
	check(not level.stair_out.locked and _game().current_todo() == level.TEXT.todo_down, "the stairs down release, and the to-do says everyone down")
	check(level.custodian.is_active() and level.custodian.powered and _bay_state(level) == "on" and level.db.run_silent("SELECT locked FROM doors WHERE id = 'PLANT-BAY'")[0]["locked"] == 0,
		"the bay's breaker comes on, its door unlocks, and the Custodian wakes")
	check(level.db.run_silent("SELECT locked FROM doors WHERE id = 'PLANT-CTRL'")[0]["locked"] == 0, "Epsilon leaves the plant's own doors as they were")
	net.profile.earned.erase("achievement:main_doors_warning")
	level.find_child("GuardsWarning", true, false).open_reader(p).close()
	await _frames(3)
	check(not net.profile.earned.has("achievement:main_doors_warning") and _game().case_info("main_doors").get("clues", []).size() >= 0, "the dead guard's copy, read after, earns nothing")
	check(await _until(func(): return level.bay_door.is_open, 120), "the bay's door rolls up")
	level.reminder_every = 0.3  # Epsilon's PA reminder, every so often from now on (checked below)
	# Seen, chased, caught.
	var cust: Custodian = level.custodian
	cust.global_position = level.to_global(Vector3(-5, 0, -15))
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(-5, 0.1, -11.5)))
	check(await _until(func(): return p.combat.grabbed_by == cust, 300), "the Custodian sees a player in the open, follows, and grabs them (state %s)" % cust.state)
	check(cust.state == "dragging" and p.input_locked, "and drags them, helpless")
	var mate := Node3D.new()  # a teammate's strikes (Combat's rule: three while it drags)
	level.add_child(mate)
	for i in cust.STRIKES_TO_FREE:
		cust.take_hit(mate)
	mate.queue_free()
	await _frames(2)
	check(cust.state == "stunned" and p.combat.grabbed_by == null and not p.input_locked, "a teammate's strikes make it let go")
	# Cut its power by code: it drops; WARDEN puts it back.
	level.power_cut_time = 0.5
	check(await _until(func(): return p.combat.grabbed_by == cust, 400), "on its feet again, it grabs them again")
	ui.terminal = level.maint
	ui.run("UPDATE breakers SET state = 'off' WHERE id = '%s'" % data.bay_breaker)
	await _frames(3)
	check(not cust.powered and p.combat.grabbed_by == null, "the CHARGING BAY breaker off: it lets go and stands dead")
	check(await _until(func(): return cust.powered, 120) and _bay_state(level) == "on", "WARDEN puts the bay's power back after a while")
	level.power_cut_time = level.POWER_CUT_TIME
	# Dragged all the way back to its bay: down (solo, back to the landing).
	var docked := [false]
	cust.docked.connect(func(_p): docked[0] = true)
	check(await _until(func(): return docked[0], 900), "left alone, it drags them all the way to its bay (state %s)" % cust.state)
	await _frames(120)
	check(p.combat.grabbed_by == null and p.health > 0.0 and LANDING_BOX.has_point(level.to_local(p.global_position)), "they go down, and come to on the landing")
	check(await _until(func(): return level.adapted, 900), "out of the control room after the accident, WARDEN's upgrade plays")
	var loop_text: String = VoiceLines.get_line("l4_epsilon_loop").get("text", "")
	check(await _until(func(): return level.hud._subtitle.text.contains(loop_text), 900), "Epsilon's reminder comes over the PA every so often")
	level.reminder_every = 1000.0
	# The lockout: logged on the controller, read back at the bay's panel in time.
	level.lockout_window = 0.5
	ui.terminal = level.controller
	ui.run(_last_hint_query(level.lockout_puzzle))
	await _frames(3)
	check(level.lockout_until > 0 and _game().case_info("seal").get("open", false), "the bay's lockout is logged and its clock starts")
	ui.run("SELECT * FROM lockouts")
	check(not level.sealed, "read back at the controller, it doesn't count")
	check(await _until(func(): return level.lockout_until == 0, 120) and not level.lockout_puzzle.state_ok(level.db), "nobody reads it back at the bay in time: it lapses and the row comes out")
	level.lockout_window = level.LOCKOUT_WINDOW
	ui.run(_last_hint_query(level.lockout_puzzle))
	await _frames(3)
	ui.terminal = level.bay_terminal
	ui.run(_last_hint_query(level.readback_puzzle))
	await _frames(3)
	check(level.sealed and _game().custodian_sealed and not cust.powered and _bay_state(level) == "off" and _game().case_info("seal").get("solved", false), "read back at the bay's panel in time: the breaker's held off and the Custodian is dark for good")
	check(not level.db.run_silent("SELECT 1 FROM lockouts WHERE breaker = '%s' AND read_back IS NOT NULL" % data.bay_breaker).is_empty(), "the lockout row is marked read back")
	ui.terminal = level.maint
	ui.run("UPDATE breakers SET state = 'on' WHERE id = '%s'" % data.bay_breaker)
	await _frames(30)
	check(not cust.powered, "sealed, power on its breaker doesn't wake it")
	# The way down: STAIR 1 to the ground floor, where the crew came in.
	p.global_transform = Transform3D(Basis(), level.to_global(level.STAIR_OUT_AT + Vector3(2.4, 0.1, 0)))
	check(await _until(func(): return level.on_ground and not p.input_locked, 300), "everyone on the stairs down: behind a fade, down to G")
	await _frames(10)
	var g_stair: Vector3 = level.g_geo.global_transform * level.G_STAIR_AT
	check(p.global_position.distance_to(g_stair) < 3.0 and p.is_on_floor() and level.g_stair.is_open, "the crew steps out of STAIR 1 by the lifts on G (%.1f m from its door)" % p.global_position.distance_to(g_stair))
	check(_game().current_todo() == level.TEXT.todo_front and level.db.run_silent("SELECT COUNT(*) AS n FROM gates")[0]["n"] == 4, "the to-do says the front doors, and the lockup's gates are in reach")
	var lockup: Node = _doc(level, "Night lockup card")
	check(lockup != null and lockup.plain_text().contains("main_entrance") and lockup.plain_text().contains("WHERE name = 'loading_dock'"), "the night lockup card names main_entrance and shows the dock's UPDATE")
	# The front desk: writes still work, until the lie.
	level.lie_time = 0.3
	ui.terminal = level.front_desk
	ui.run("UPDATE gates SET unlocked = 1 WHERE name = 'loading_dock'")
	await _frames(3)
	check(not level.db.read_only and level.db.run_silent("SELECT unlocked FROM gates WHERE name = 'loading_dock'")[0]["unlocked"] == 1 and not level.entrance_puzzle.solved, "the dock's gate changes (its motor's seized): not the way out, and nothing else happens")
	check(_said(level.front_desk, level.TEXT.tip_dock), "and SYSOP says it's not the front doors, and where the front doors are")
	check(str(level.db.run_silent("SELECT note FROM gates WHERE name = 'car_park_barrier'")[0]["note"]).contains("through the dock"), "the open car park barrier's note says why it's no way out")
	ui.run("DELETE FROM gates WHERE name = 'main_entrance'")
	await _frames(2)
	check(_said(level.front_desk, level.TEXT.gates_fixed) and level.db.run_silent("SELECT 1 FROM gates WHERE name = 'main_entrance'").size() == 1, "the front doors' row can't be deleted")
	ui.run(_last_hint_query(level.entrance_puzzle))
	await _frames(2)
	check(level.entrance_puzzle.solved and not level.db.read_only and level.db.run_silent("SELECT unlocked FROM gates WHERE name = 'main_entrance'")[0]["unlocked"] == 1,
		"main_entrance: 1 row changed and the latch clicks")
	check(await _until(func(): return level.db.read_only, 120), "then Epsilon steps in")
	check(level.db.run_silent("SELECT unlocked FROM gates WHERE name = 'main_entrance'")[0]["unlocked"] == 0 and level.db.run_silent("SELECT unlocked FROM gates WHERE name = 'loading_dock'")[0]["unlocked"] == 0 and not level.front_doors.is_open,
		"it puts every gate back as it was; the front doors never moved")
	check(_game().current_todo() == level.TEXT.todo_check_front, "the to-do says to check the row")
	ui.run(_last_hint_query(level.entrance_puzzle))
	await _frames(2)
	check(_said(level.front_desk, level.TEXT.write_refused) and level.refusals == 1, "a write now: WRITE REFUSED, read-only under Epsilon")
	ui.terminal = level.controller
	ui.run("UPDATE doors SET locked = 0 WHERE id = 'PLANT-BAY'")
	await _frames(2)
	check(_said(level.controller, level.TEXT.write_refused_again) and level.refusals == 2, "at any terminal, and again: STILL READ-ONLY")
	ui.terminal = level.front_desk
	var done := [false]
	level.completed.connect(func(): done[0] = true)
	ui.run("SELECT * FROM gates")
	await _frames(2)
	check(level.verify_puzzle.solved and _game().case_info("entrance").get("solved", false), "the crew's own SELECT shows the lie: main_entrance locked again (the whole table counts, as the panel did upstairs)")
	check(await _until(func(): return done[0], 1500) and _game().completed_level == "level_4" and net.profile.earned.has("achievement:floor_10"), "locked in, the floor ends (WARDEN's stairs lines first)")
	net.profile.earned = had
	level.queue_free()
	await t.process_frame


## Host and client: a client's writes go through the floor's rules on the host, and
## the accident, the Custodian and the seal play out on every machine.
## Easy SQL's Ch 17 and 18 come up at their papers: Changing a row on the work order
## or the gantry card (whichever is read first, once), Adding a row on the clipboard.
## Nothing stops for them: the Custodian keeps going.
func test_book_huddles() -> void:
	print("Floor 10: the book's chapters")
	_game().new_run(7)
	var level = load("res://scenes/level_4.tscn").instantiate()
	t.root.add_child(level)
	await _frames(30)
	var p: Player = level.player
	var h: Node = t._huddle_of(level)
	_doc(level, "Gantry card").report_open(p)
	check(await t._huddle_opens(level, "easy_sql_update"), "the gantry card, read first, brings back Changing a row")
	check(level.custodian.is_physics_processing(), "the Custodian keeps going while it comes in")
	await t._crew_reads([level])
	await t._until(func(): return not h.is_busy(), 10.0)
	check(h.done.has("easy_sql_update") and level.custodian.is_physics_processing(), "the chapter is in, and the Custodian is still going")
	_doc(level, "Facilities work order").report_open(p)
	await _frames(20)
	check(not h.is_busy() and _game().case_info("power").get("open", false), "the work order read after doesn't bring the chapter back, and still opens the power case")
	_doc(level, "Contractor log").report_open(p)
	check(await t._huddle_opens(level, "easy_sql_insert"), "the contractor clipboard brings back Adding a row")
	await t._crew_reads([level])
	await t._until(func(): return not h.is_busy(), 10.0)
	check(h.done.has("easy_sql_insert") and _game().case_info("login").get("open", false), "the chapter ends, and the clipboard's case is open")
	level.queue_free()
	await t.process_frame


func test_coop() -> void:
	print("Co-op: floor 10 with a host and a client")
	_game().new_run(5)
	var worlds: Array = await t._coop_worlds(1)
	var machines: Array = await t._coop_load(worlds, "res://scenes/level_4.tscn")
	_chapters_read(machines)
	var host = machines[0]
	var client = machines[1]
	check(machines.all(func(l): return l.sync._begun and l.players.count() == 2 and l.data.target == host.data.target), "both machines start floor 10 with the same breaker tripped")
	var cui: TerminalUI = client.terminal_ui
	cui.terminal = client.controller
	cui.run("UPDATE doors SET locked = 0 WHERE id = 'main_doors'")
	await _frames(10)
	check(machines.all(func(l): return not l.accident and l.db.run_silent("SELECT locked FROM doors WHERE id = 'main_doors'")[0]["locked"] == 1), "a client's door write before the log-in is refused on every machine")
	cui.run(_last_hint_query(client.login_puzzle))
	await _frames(10)
	cui.run(_last_hint_query(client.login_read_puzzle))
	await _frames(10)
	check(machines.all(func(l): return l.logged_in), "a client's log-in, read back, counts for everyone")
	cui.run(_last_hint_query(client.main_doors_puzzle))
	await _frames(10)
	check(machines.all(func(l): return l.accident and not l.stair_out.locked), "a client opening main_doors is the accident on every machine")
	check(host.custodian.is_active() and host.custodian.powered, "the host's Custodian wakes")
	host.custodian.global_position = host.to_global(Vector3(0, 0, -1))
	await _frames(20)
	check(client.custodian.is_active() and client.custodian.global_position.distance_to(host.custodian.global_position) < 0.6, "clients see the Custodian where the host has it")
	cui.terminal = client.maint
	cui.run("UPDATE breakers SET state = 'off' WHERE id = '%s'" % client.data.bay_breaker)
	await _frames(10)
	check(not host.custodian.powered and machines.all(func(l): return _bay_state(l) == "off"), "a client cutting the bay's breaker drops the host's Custodian")
	cui.terminal = client.controller
	cui.run(_last_hint_query(client.lockout_puzzle))
	await _frames(10)
	cui.terminal = client.bay_terminal
	cui.run(_last_hint_query(client.readback_puzzle))
	await _frames(10)
	check(machines.all(func(l): return l.sealed and not l.custodian.powered), "a client's lockout, read back at the bay, seals the Custodian everywhere")
	var dump := "SELECT * FROM lockouts ORDER BY breaker"
	check(host.db.run_silent(dump) == client.db.run_silent(dump), "the lockouts table matches on both machines")
	# Down to G together; a client's main-entrance write is the lie for everyone.
	for l in machines:
		l.lie_time = 0.3
		l.completed.disconnect(l._on_completed)
	host.sync.event("_on_exit")
	check(await _until(func(): return machines.all(func(l): return l.on_ground and not l.player.input_locked), 300), "both machines go down to G")
	cui.terminal = client.front_desk
	cui.run(_last_hint_query(client.entrance_puzzle))
	check(await _until(func(): return machines.all(func(l): return l.db.read_only), 300), "a client's main-entrance write clicks the latch and Epsilon goes read-only on every machine")
	check(machines.all(func(l): return l.db.run_silent("SELECT unlocked FROM gates WHERE name = 'main_entrance'")[0]["unlocked"] == 0), "and the row is put back everywhere")
	cui.run("UPDATE gates SET unlocked = 1 WHERE name = 'main_entrance'")
	await _frames(10)
	check(machines.all(func(l): return l.refusals == 1 and l.db.run_silent("SELECT unlocked FROM gates WHERE name = 'main_entrance'")[0]["unlocked"] == 0), "a client's write after that is refused, and WARDEN answers on every machine")
	cui.run(_last_hint_query(client.verify_puzzle))
	await _frames(10)
	check(machines.all(func(l): return l.verify_puzzle.solved), "a client's read-back shows the lie for everyone")
	await t._coop_close(worlds)


## The gantry: moved by UPDATE, refused by its own controller when it can't, docked
## under the access panel; climbed solo when raised; and the control room's manual
## release lets the crew out from inside.
func test_gantry() -> void:
	print("Floor 10: the gantry arm and the access panel")
	_game().new_run(21)
	var level = load("res://scenes/level_4.tscn").instantiate()
	t.root.add_child(level)
	await _frames(20)
	_chapters_read([level])
	var p: Player = level.player
	var data: Dictionary = level.data
	var ui: TerminalUI = level.terminal_ui
	var g: AnimatableBody3D = level.gantry
	var card: Node = _doc(level, "Gantry card")
	check(card != null and card.plain_text().contains("Bay %d: the access panel" % data.hatch_bay) and card.plain_text().contains("UPDATE gantry SET bay = 3 WHERE id = 'GA-1';"),
		"the gantry card names the panel's bay and shows another bay's UPDATE")
	check(is_equal_approx(g.position.x, level._bay_x(data.park_bay)) and not level.hatch.is_open, "the arm is parked at its end of the rail; the access panel is shut")
	ui.terminal = level.maint
	ui.run("UPDATE gantry SET bay = 7 WHERE id = 'GA-1'")
	await _frames(2)
	check(_said(level.maint, level.TEXT.gantry_no_bay) and level.db.run_silent("SELECT bay FROM gantry")[0]["bay"] == data.park_bay, "a bay that isn't there: the controller refuses it and the row stays as it was")
	ui.run("DELETE FROM gantry")
	await _frames(2)
	check(_said(level.maint, level.TEXT.gantry_bolted) and level.db.run_silent("SELECT COUNT(*) AS n FROM gantry")[0]["n"] == 1, "deleting the arm's row is refused")
	# Raised where it parks, it won't travel: lower it first.
	ui.run("UPDATE gantry SET raised = 1 WHERE id = 'GA-1'")
	check(await _until(func(): return g.position.y > level.GANTRY_HIGH - 0.05, 300), "raised = 1 lifts the platform to the rail")
	ui.run(_last_hint_query(level.gantry_puzzle))
	await _frames(2)
	check(_said(level.maint, level.TEXT.gantry_interlock) and level.db.run_silent("SELECT bay FROM gantry")[0]["bay"] == data.park_bay and not level.gantry_puzzle.solved,
		"raised, it won't travel: the interlock refuses and the row stays put")
	# The advanced coder: lower and travel back is refused, so: down, then across and up in one row change.
	ui.run("UPDATE gantry SET raised = 0 WHERE id = 'GA-1'")
	check(await _until(func(): return g.position.y < level.GANTRY_LOW + 0.05, 300), "lowered, it comes back down")
	ui.run("UPDATE gantry SET bay = %d, raised = 1 WHERE id = 'GA-1'" % data.hatch_bay)
	check(await _until(func(): return level.hatch.is_open, 900), "moved and raised in one row change, it travels, lifts, and docks: the panel opens")
	check(level.gantry_puzzle.solved and is_equal_approx(g.position.x, level._bay_x(data.hatch_bay)) and g.position.y > level.GANTRY_HIGH - 0.05, "the arm is under the panel, at the top")
	# Solo: climb the mast, step off on the platform, through the panel and down into the control room.
	p.local_control = false
	p.global_transform = Transform3D(Basis(), g.global_transform * Vector3(0, -level.GANTRY_HIGH + 0.05, 1.4))
	await _frames(5)
	p.controls.move = Vector2(0, -1)
	var climbed := false
	for i in 900:
		p.controls.jump = not climbed and p.global_position.distance_to(level.to_global(Vector3(g.position.x, 0, level.GANTRY_Z + 0.6))) < 1.2
		await t.physics_frame
		climbed = climbed or p.state == Player.Move.CLIMB
		p.controls.crouch = climbed and p.is_on_floor() and p.global_position.y > level.GANTRY_HIGH - 0.2  # duck through the panel
		if level.CTRL_ROOM.has_point(level.to_local(p.global_position)) and p.is_on_floor():
			break
	p.controls.move = Vector2.ZERO
	p.controls.jump = false
	p.controls.crouch = false
	await _frames(10)
	check(climbed and level.CTRL_ROOM.has_point(level.to_local(p.global_position)), "climb the mast, cross the platform, through the panel and down into the control room (at %s)" % level.to_local(p.global_position))
	check(not level.ctrl_door.is_open and not level.power_back, "in without the power: the room's still dark and its door shut")
	level.release.used.emit(p)
	await _frames(90)
	check(level.ctrl_door.is_open, "the door's manual release lets the crew out from inside")
	# Moving away again shuts the panel.
	ui.run("UPDATE gantry SET raised = 0 WHERE id = 'GA-1'")
	await _frames(5)
	ui.run("UPDATE gantry SET bay = %d WHERE id = 'GA-1'" % data.park_bay)
	check(await _until(func(): return not level.hatch.is_open, 300), "the arm leaving its bay drops the panel shut")
	p.local_control = true
	level.queue_free()
	await t.process_frame


## Not locked out, the Custodian comes down to G after the crew.
func test_custodian_follows() -> void:
	print("Floor 10: the Custodian follows the crew down")
	_game().new_run(40)
	var level = load("res://scenes/level_4.tscn").instantiate()
	t.root.add_child(level)
	await _frames(20)
	_chapters_read([level])
	level.completed.disconnect(level._on_completed)
	level.follow_time = 0.3
	level.sync.event("_on_solved", ["main_doors"])
	await _frames(5)
	var p: Player = level.player
	p.global_transform = Transform3D(Basis(), level.to_global(level.STAIR_OUT_AT + Vector3(2.4, 0.1, 0)))
	check(await _until(func(): return level.on_ground, 300), "down to G")
	var at: Vector3 = level.g_geo.global_transform * level.G_STAIR_AT
	check(await _until(func(): return level.custodian.global_position.distance_to(at) < 6.0 and level.custodian.bay_point.distance_to(at) < 4.0, 120), "it comes out of STAIR 1 on G and hunts there")
	level.queue_free()
	await t.process_frame


## In the World: down the stairs from 18, out on 10's landing; G where Level 0 stands.
func test_world() -> void:
	print("Floor 10 in the World")
	_game().new_run(9)
	var world = load("res://scenes/world.tscn").instantiate()
	t.root.add_child(world)
	await _frames(10)
	world.enter_wing(world.route_index("level_3"))
	var l3 = world.current
	await _frames(20)
	check(not world.wings.has("level_4"), "floor 10 isn't built until 18's stairs open")
	l3.prepare_next()
	var l4 = world.wings.get("level_4")
	check(l4 != null and not l4.active and l4.global_position.distance_to(l3.global_position) > 40.0, "floor 10 builds apart from 18, without starting")
	check(l4.g_geo.global_transform.origin.distance_to(world.ROUTE[0].at.origin) < 0.01, "its ground floor stands where Level 0's lobby does")
	l3.sync.event("_on_exit")
	for i in 600:
		await t.physics_frame
		if world.current == l4 and l4.active:
			break
	await _frames(10)
	check(world.current == l4 and l4.active and LANDING_BOX.has_point(l4.to_local(world.player.global_position)), "the stairs hand play to floor 10, on its landing (%s)" % l4.to_local(world.player.global_position))
	check(_game().completed_level == "level_3" and _game().next_level == "level_4", "floor 18 is complete, floor 10 is next")
	world.queue_free()
	await t.process_frame
