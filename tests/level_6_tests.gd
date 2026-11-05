extends RefCounted
## B1, the cold store (Level 6): its data across seeds; the time clock's IS NULL (and
## = NULL, IS NOT NULL, the rack); the first script pairing the earpieces (the dock
## key's 403, no wait's 409, no count's endless loop, too few sets); the watchdog at
## the anteroom (two sweeps held; no if trips the relay guard; no wait stops the
## script) and at the deep freeze from a deck in the cold; the release from Vault C
## over the vaults' network (wired 403, the if forgotten closes the crew's own entry
## and darkens the vault until a punch back in, too short a wait gets 409); stopping
## everything and reading the doors back; the cold that never kills; the guards
## (nothing names Mercer or Vale); and the way down. Run in the floor_b1 group.

var t: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("B1: the cold store")
	test_data_every_seed()
	test_guards()
	await test_floor()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func _game() -> Node:
	return t.root.get_node("/root/Game")


func _frames(n: int) -> void:
	for i in n:
		await t.physics_frame


func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await t.physics_frame
	return cond.call()


## Runs `code` as a script on `term` (a terminal or a deck), as the runner does.
func _run(term: Node, code: String) -> ScriptRuntime:
	var rt := ScriptRuntime.for_language("javascript")
	var c := rt.compile(code)
	if not c.ok:
		push_warning("compile failed: %s" % c.error)
		return rt
	term.set_meta("script_runtime", rt)
	rt.start(BuildingLibrary.new(term.api, term.db), 1)
	return rt


func _req(term: Node, line: String) -> Dictionary:
	return term.api.request(line)


func _key(level: Node, req: String, body := "") -> String:
	var out := "%s\nX-Api-Key: %s" % [req, level.data.key]
	if body != "":
		out += "\n\n" + body
	return out


func _move(level: Node, p: Vector3) -> void:
	level.player.global_position = level.to_global(p)
	level.player.velocity = Vector3.ZERO


func test_data_every_seed() -> void:
	print("B1: data across seeds")
	var ok_six := true
	var ok_whitlow := true
	var ok_open := true
	var ok_rack := true
	var ok_timers := true
	var keys := {}
	var doors := {}
	var sets := {}
	for s in range(1, 61):
		var d := Level6Data.build(s)
		ok_six = ok_six and d.echoes.size() == 6
		ok_whitlow = ok_whitlow and d.echoes.any(func(e): return e.id == "whitlow")
		var ids := {}
		for e in d.echoes:
			ids[e.id] = true
		ok_six = ok_six and ids.size() == 6
		var db := FacilityDB.new()
		db.load_seed(d.sql)
		var open := db.run_silent("SELECT card FROM freezer_log WHERE clock_out IS NULL")
		ok_open = ok_open and open.size() == 6 and open.all(func(r): return d.echoes.any(func(e): return e.card == r.card))
		ok_open = ok_open and db.run_silent("SELECT * FROM freezer_log WHERE clock_out = NULL").is_empty()
		# The rack never matches the log: one card's behind it, two fixed ones still IN.
		ok_rack = ok_rack and d.rack_in.size() == 7 and d.fixed.all(func(f): return d.rack_in.any(func(c): return c.card == f.card))
		ok_rack = ok_rack and not d.rack_in.any(func(c): return c.card == d.behind[0])
		ok_timers = ok_timers and d.sweep >= 6.0 and d.sweep <= 10.0 and d.freezer_timer >= 6.0 and d.freezer_timer <= 10.0 and d.punch_interval >= 15.0 and d.punch_interval <= 25.0
		ok_timers = ok_timers and d.key != d.dock_key
		keys[d.key] = true
		doors[d.doors.ante] = true
		var names: Array = d.echoes.map(func(e): return e.id)
		names.sort()
		sets[",".join(PackedStringArray(names))] = true
	check(ok_six, "every run has six echoes, all different, from the pool of nine")
	check(ok_whitlow, "Agnes Whitlow, the name Ines knows, is in every run")
	check(ok_open, "the log's open visits are exactly the six echoes', and = NULL finds none")
	check(ok_rack, "the card rack always disagrees with the log: a card down the back, two fixed ones still IN")
	check(ok_timers, "the sweep and the freezer timer are 6 to 10 s, a slip 15 to 25 s, the dock's key isn't the cage's")
	check(keys.size() > 50 and doors.size() > 20 and sets.size() > 15, "keys, door ids and which six come change with the seed (%d, %d, %d)" % [keys.size(), doors.size(), sets.size()])


## Nothing on B1 names, shows or hints at Mercer or Vale (his fate is undecided; her
## reveal is Level 10).
func test_guards() -> void:
	var s: Script = load("res://scripts/levels/level_6.gd")
	var consts := s.get_script_constant_map()
	var text := JSON.stringify([consts.TEXT, consts.ECHO_LINES, consts.ECHO_LEAVES, consts.CLOCK_SIGN_LINES, consts.SUPERVISOR_LINES,
		consts.WHITEBOARD_LINES, consts.CRADLE_CARD, consts.TECH_NOTE, consts.VAULT_C_SIGN, consts.SERVICE_PAGE, consts.BENCH_LINES, Level6Data.POOL, Level6Data.STAFF])
	var low := text.to_lower()
	check(not low.contains("mercer") and not low.contains("vale") and not low.contains("h.m.") and not low.contains("iris"), "nothing on B1 names Mercer or Vale")
	check(not low.contains("rourke"), "and no Rourke lines")
	check(not JSON.stringify(Level6Data.POOL).contains("22"), "no echo's paper points at floor 22")


func test_floor() -> void:
	print("B1: the floor")
	_game().new_run(4242)
	_game().custodian_sealed = false
	var level: Node = load("res://scenes/level_6.tscn").instantiate()
	t.root.add_child(level)
	await _frames(5)
	check(level.db.read_only, "the database only reads (Epsilon)")
	check(level.echoes.size() == 6 and level.decks.size() == 6, "six echoes at their rows, a deck for every player slot")
	check(level.stair_gate and not level.stair_gate.is_open, "STAIR 2's way on down is gated")
	check(level.staffers.size() == 2, "the two night-shifters from 9 wait on the landing")
	level.sweep_every = 1.0
	level.freezer_timer = 1.5
	level.punch_interval = 0.4
	level.guard_hold = 2.0

	await _case_open(level)
	await _case_pair(level)
	await _case_hold(level)
	await _case_release(level)
	await _case_stop(level)
	await _cold(level)
	await _exit(level)
	level.queue_free()
	await _frames(2)


func _case_open(level: Node) -> void:
	var ui: TerminalUI = level.terminal_ui
	ui.open(level.office, level.player)
	ui.run("SELECT * FROM freezer_log WHERE clock_out = NULL;")
	await _frames(2)
	check(not level.open_puzzle.solved and level.tips_sent.has("eq_null"), "= NULL finds nothing, and SYSOP says why: nothing equals NULL")
	ui.run("SELECT * FROM freezer_log WHERE clock_out IS NOT NULL;")
	await _frames(2)
	check(not level.open_puzzle.solved and level.tips_sent.has("not_null"), "IS NOT NULL is the visits that closed: not it")
	ui.run("SELECT name FROM freezer_log WHERE clock_out IS NULL AND vault = 'A';")
	await _frames(2)
	check(not level.open_puzzle.solved, "one vault's open visits aren't all of them")
	ui.run(level.open_puzzle.hints[-1].get_slice("[color=#ffffff]", 1).get_slice("[/color]", 0))
	await _frames(2)
	check(level.open_puzzle.solved and _game().case_info("open").solved, "the last hint's query finds the six open visits and closes the case")
	var p: Puzzle = level.open_puzzle
	check(p.matches(level.db, level.db.execute("SELECT name FROM freezer_log WHERE clock_out IS NULL")), "names alone are right too: who's still in")
	check(_game().case_info("pair").get("open", false), "then the earpieces' case opens: one case at a time")
	check(level.open_puzzle.hints[0].contains("enter_column"), "hint 1 leaves the column as enter_column (the review ladder)")
	ui.close()


func _case_pair(level: Node) -> void:
	var turn: int = level._static_turn
	level._static_whisper()
	level._static_whisper()
	check(level._static_turn == turn + 2 and level.data.echoes.size() == 6, "under the walkie's static, a few words from one of tonight's rows, a different one each time")
	var it: Terminal = level.it_terminal
	# The card's key is the dock cradle's: 403, nothing paired.
	var rt := _run(it, level._pair_script(level.data.dock_key, "1"))
	var said := []
	rt.printed.connect(func(text, _k): said.append(text))
	await _until(func(): return not rt.is_running(), 120)
	check(level.paired == 0 and said.has("403"), "the card's own key is the dock cradle's: 403, nothing pairs (%s)" % [said])
	# No wait: the cradle's busy, one set pairs.
	level.crew_size = 3
	rt = _run(it, level._pair_script(level.data.key, "3").replace("  await sleep(1000);\n", ""))
	await _until(func(): return not rt.is_running(), 120)
	check(level.paired == 1 and level.pair_409s >= 2 and not level.pair_puzzle.solved, "no wait in the loop: the cradle is busy (409) and one set pairs")
	# Too few: count 1 for a crew of three.
	await _until(func(): return not level.pair_busy, 120)
	rt = _run(it, level._pair_script(level.data.key, "1"))
	await _until(func(): return not rt.is_running(), 200)
	check(level.paired == 2 and not level.pair_puzzle.solved, "count too low: one more set, two of three, not done")
	# No count up: it never ends, and keeps asking (409s) until Stop.
	rt = _run(it, level._pair_script(level.data.key, "3").replace("  paired = paired + 1;\n", ""))
	await _until(func(): return level.paired >= 3, 400)
	check(level.pair_puzzle.solved and _game().case_info("pair").solved and level.earpieces, "one set each and the case closes; the earpieces go in")
	var asked: int = level.pair_requests
	await _until(func(): return level.pair_requests > asked + 1, 400)
	check(rt.is_running(), "without paired = paired + 1 the loop never ends: it keeps asking")
	rt.stop()
	check(not rt.is_running(), "and Stop ends it")
	level.crew_size = 0


func _case_hold(level: Node) -> void:
	check(_game().case_info("hold").get("open", false), "the doors' case opens once the earpieces are in")
	var ante: Terminal = level.ante_terminal
	var door: String = level.data.doors.ante
	# No if: needless writes to the open door trip the relay guard.
	var no_if: String = level._watchdog(level.data.key, door).replace("  if (res.body.locked) {\n", "").replace("    console.log(door + \" opened\");\n  }\n", "    console.log(door + \" opened\");\n")
	level.sweep_every = 8.0
	var rt := _run(ante, no_if)
	await _until(func(): return level.guarded.has(door), 900)
	check(level.guarded.has(door) and level._door_locked(door), "no if: writing to the open door trips the relay guard, and it's held shut")
	rt.stop()
	level.sweep_every = 1.0
	await _until(func(): return not level.guarded.has(door), 300)
	# No wait: it runs too long without waiting and stops itself.
	rt = _run(ante, level._watchdog(level.data.key, door).replace("  await sleep(1000);\n", ""))
	await _until(func(): return not rt.is_running(), 400)
	check(rt.state == ScriptRuntime.State.FAILED and str(rt.error.get("message", "")).contains("without waiting"), "no wait: the runtime stops it, and says a loop needs await sleep")
	level.guarded.clear()
	# The real watchdog holds it through the sweeps.
	rt = _run(ante, level._watchdog(level.data.key, door))
	await _until(func(): return level.practice_puzzle.solved, 600)
	check(level.practice_puzzle.solved and rt.is_running() and not level.guarded.has(door), "the watchdog holds the anteroom door through two sweeps, and the guard stays quiet")
	# Rerun without changing door: the deep freeze still latches.
	var deck: Terminal = level.decks[0]
	_move(level, Vector3(10, 0.1, -14))  # the cold corridor, by its access point
	level.player.inventory.add("deck")
	level._bench_used(1)
	await _frames(3)
	check(level.deck_net[0] == "vault" and deck.get_meta("scripts", false), "a fitted deck in the corridor is on the vaults' network, and runs scripts")
	check(level.find_children("RowLabel_*", "", true, false).size() == level.ROWS.size(), "every row has its label over the shelf, so a name in the log can be found at its row")
	var c_door: String = level.data.doors.vault_c
	var hold := _run(deck, level._watchdog(level.data.key, c_door))
	await _until(func(): return not level._door_locked(c_door), 200)
	check(not level._door_locked(c_door), "the deck's watchdog opens the deep freeze door")
	await _until(func(): return level.watchdog_used, int(level.freezer_timer * 60) * 3 + 60)
	await _until(func(): return not level._door_locked(c_door), 200)
	check(level.watchdog_used and not level._door_locked(c_door), "and keeps it open past its safety timer")
	_move(level, Vector3(25, 0.1, -14))
	await _until(func(): return level.crossed, 120)
	check(level.crossed and level.hold_puzzle.solved and _game().case_info("hold").solved, "everyone across into Vault C: the doors' case closes")
	check(_game().case_info("release").get("open", false), "and the release opens")
	level.set_meta("hold_rt", hold)


func _case_release(level: Node) -> void:
	var deck: Terminal = level.decks[0]
	var office: Terminal = level.office
	check(level.crew_in.get("VIS-01", "") == "C" and level._open_crew_entry("VIS-01", "C") > 0, "Vault C's reader punched the crew in too")
	var res := _req(office, _key(level, "POST /clock_outs", "{\"entry\": %d}" % level.data.echoes[0].entry))
	check(res.status == 403, "a punch from the wired terminals is refused (403)")
	# The if forgotten: the crew's own entry closes too, and Vault C goes dark.
	var ms := int(level.punch_interval * 1000) + 300
	var no_if: String = level._release_script(level.data.key, "true", ms)
	var rt := _run(deck, no_if)
	await _until(func(): return not rt.is_running(), 2400)
	check(level.all_free, "the release frees every echo")
	check(level.unoccupied.has("C") and level._door_locked(level.data.doors.vault_c), "but without the if it closes our own entry: the clock thinks Vault C is empty, dark and latched")
	res = _req(deck, _key(level, "PATCH /doors/" + level.data.doors.vault_c, "{\"locked\": false}"))
	check(res.status == 409, "the watchdog can't unlatch an empty vault (409)")
	await _until(func(): return not level.printing, 120)
	res = _req(deck, _key(level, "POST /clock_ins", "{\"card\": \"VIS-01\", \"vault\": \"C\"}"))
	check(res.status == 201 and not level.unoccupied.has("C"), "punched back in from the deck: Vault C's lights come back")
	check(_game().case_info("release").solved and level.stairs_open, "everyone's free: the case closes and STAIR 2's gate opens")
	await _until(func(): return level.find_children("Left_*", "", true, false).size() == 6, 2400)
	check(level.find_children("Left_*", "", true, false).size() == 6, "each one told their story and left a memory or a piece of evidence at their row")
	await _until(func(): return level.find_children("Slip_*", "", true, false).size() >= 6, 600)
	var slips: Array = level.find_children("Slip_*", "", true, false)
	var years := slips.filter(func(d): return d.doc_lines.any(func(l): return str(l.text).begins_with("INSIDE:") and str(l.text).contains("years")))
	check(slips.size() >= 6 and years.size() == 6 and slips.all(func(d): return level.OFFICE.has_point(level.to_local(d.global_position))),
		"the clock printed an out slip for each of them, years inside, on the tray in the time office (%d slips, %d in years)" % [slips.size(), years.size()])
	check(level.inside_for("1982-03-04 02:12", "1997-10-16 01:17") == "15 years, 7 months" and level.inside_for("1997-10-16 01:02", "1997-10-16 01:17") == "0 h 15 min",
		"a slip says how long they were inside, in years and months, or minutes for one of us")
	_move(level, Vector3(0, 0.1, 6))
	await _until(func(): return level.landing_said, 300)
	check(level.landing_said, "back on the landing, the night-shifters ask about them")


func _case_stop(level: Node) -> void:
	check(_game().case_info("stop").get("open", false), "once they're free, leaving it tidy opens (optional)")
	var deck: Terminal = level.decks[0]
	var ui: TerminalUI = level.terminal_ui
	ui.open(deck, level.player)
	ui.run(_key(level, "GET /doors"))
	await _frames(2)
	check(not level.stop_puzzle.solved, "reading the doors back with a watchdog still running isn't it")
	for term in level._script_terminals():
		var rt = term.get_meta("script_runtime") if term.has_meta("script_runtime") else null
		if rt and rt.is_running():
			rt.stop()
	for id in [level.data.doors.vault_c, level.data.doors.ante]:
		ui.run(_key(level, "PATCH /doors/" + id, "{\"locked\": true}"))
		await _frames(1)
	ui.run(_key(level, "GET /doors"))
	await _frames(2)
	check(level.stop_puzzle.solved and _game().case_info("stop").solved, "every script stopped, both doors locked and read back: tidy")
	ui.close()


func _cold(level: Node) -> void:
	var p: Player = level.player
	_move(level, Vector3(25, 0.1, -14))
	p.health = 30.0
	p.stamina = 0.0
	level.unoccupied["C"] = true
	await _frames(600)
	check(p.health >= level.COLD_FLOOR - 0.01 and p.health <= 30.0 and p.health > 0.0, "the cold hurts but never kills: it stops at %d health (%.1f)" % [level.COLD_FLOOR, p.health])
	level.unoccupied.erase("C")
	_move(level, Vector3(-8, 0.1, -2))
	var before := p.health
	await _frames(120)
	check(p.health > before, "the warm office brings you back")


func _exit(level: Node) -> void:
	var done := [false]
	level.completed.connect(func(): done[0] = true)
	for c in level.completed.get_connections():
		if c.callable.get_method() == "_on_completed":
			level.completed.disconnect(c.callable)
	var holder: Node3D = Stairwell.of(level.stair_in)
	await _until(func(): return level.stair_gate.is_open, 120)
	level.player.global_position = holder.global_transform * (Stairwell.landing_box().get_center() - Vector3(0, Stairwell.STOREY - 0.2, 0))
	await _until(func(): return done[0], 600)
	check(done[0], "everyone a storey down STAIR 2: the floor is done")
