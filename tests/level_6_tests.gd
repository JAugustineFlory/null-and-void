extends RefCounted
## B1, the cold store (Level 6): its data across seeds; the time clock's IS NULL (and
## = NULL, IS NOT NULL, the rack); the first script pairing the earpieces (the dock
## key's 403, no wait's 409, no count's endless loop, too few sets, and SYSOP's line
## for each, from a script); the listing, warm, that leaves the crew's own entries
## out (!== practised before the cold); the watchdog at
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
	# The open find (V5): whoever's been inside longest, a unique clock_in, the open
	# visits under the policy's cap even with six crew in, and the sorted log's top row
	# a visit that closed on most seeds (the tempting click, V7).
	var ok_first := true
	var ok_cap := true
	var closed_top := 0
	for s in range(1, 41):
		var d := Level6Data.build(s)
		var db := FacilityDB.new()
		db.load_seed(d.sql)
		var first: Dictionary = d.echoes[0]
		var open := db.run_silent("SELECT name, card, clock_in FROM freezer_log WHERE clock_out IS NULL ORDER BY clock_in")
		ok_first = ok_first and str(open[0].card) == str(first.card) and db.run_silent("SELECT id FROM freezer_log WHERE clock_in = '%s'" % first.clock_in).size() == 1
		ok_first = ok_first and db.run_silent("SELECT id FROM freezer_log WHERE name = '%s'" % str(first.name).replace("'", "''")).size() == 1
		ok_cap = ok_cap and open.size() + 6 <= 12
		var sorted := db.run_silent("SELECT clock_out FROM freezer_log ORDER BY clock_in LIMIT 13")
		if sorted[0].clock_out != null:
			closed_top += 1
		ok_first = ok_first and sorted.any(func(r): return r.clock_out == null)
	check(ok_first, "in there longest: the first open visit by clock_in, its name and clock_in on no other row, and it's in a sorted log's first 13 rows")
	check(ok_cap, "the open visits, with six crew punched in, are 12 rows at most: under the policy's cap")
	check(closed_top > 20, "the sorted log's top row is a visit that closed on most seeds (%d of 40): the tempting click" % closed_top)


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
	level.listing_after = 0.5

	await _papers(level)
	await _case_open(level)
	await _case_pair(level)
	await _case_list(level)
	await _case_hold(level)
	await _case_release(level)
	await _case_stop(level)
	await _cold(level)
	await _exit(level)
	level.queue_free()
	await _frames(2)


## The package's papers and screens (plan/approvals/puzzle-flow-floor-b1.md): the
## policy on every B1 screen, the cradle's self-test label, the pairing card on the
## bench, the door signs with their ids, and the warm-up area.
func _papers(level: Node) -> void:
	for term in [level.office, level.it_terminal, level.ante_terminal, level.decks[0]]:
		check(term.policy and term.boot_text().has(TerminalPolicy.BOOT_LINE) and term.boot_text().find(TerminalPolicy.BOOT_LINE) == 1, "%s runs under the security policy, its line second on the boot screen (P1)" % term.terminal_name)
	check(level.find_child("PolicyCard", true, false) != null, "the policy's card is on the supervisor's desk (P5)")
	var label: Document = level.find_child("SelfTestLabel", true, false)
	check(label and label.spot == "self_test" and label.plain_text().contains("SELF-TEST  (pairs one set)") and label.plain_text().contains("^S save, ^R run, ^T stop"), "the cradle's self-test label: one set, the first script (V16)")
	var card: Document = level.find_child("CradleCard", true, false)
	check(card and card.title == "Pairing card" and level.IT_CAGE.has_point(level.to_local(card.global_position)) and card.global_position.distance_to(level.find_child("KeySticky", true, false).global_position) < 1.2, "the cradle card is the pairing card now, at the bench beside the key sticky")
	check(card.clues.all(func(c): return not c.has("opens")), "reading the pairing card early only notes its clue")
	var over_c: Document = level.find_child("VaultCDoorSign", true, false)
	check(over_c and over_c.plain_text().contains("VAULT C  -  DEEP FREEZE  -  " + level.data.doors.vault_c), "the sign over Vault C's door shows its id, as the anteroom's does (V30)")
	var over_a: Document = level.find_child("AnteDoorSign", true, false)
	check(over_a and over_a.plain_text().contains(level.data.doors.ante), "and the anteroom's sign shows its own")
	check(level.find_child("WarmUpSign", true, false) != null and level.WARM_ROOMS.has(level.WARM_UP) and level.AP_ROOMS.has(level.WARM_UP) and not level.CORRIDOR.intersects(level.WARM_UP), "the warm-up area: signed, warm, outside the corridor's cold, and an access point covers it")
	var mid: float = level.WARM_UP.get_center().x
	check(mid > level.ANTE_DOOR_AT.x + 6.0 and mid < level.VAULT_C_DOOR_AT.x - 6.0, "halfway between the anteroom and Vault C (%.1f)" % mid)
	check(level.CRADLE_SLOTS == 8 and level.api.request("GET /earpieces\nX-Api-Key: %s" % level.data.key).body.slots == 8, "the cradle holds eight sets (M2)")


func _case_open(level: Node) -> void:
	var ui: TerminalUI = level.terminal_ui
	var game := _game()
	check(level._open_crew_entry("VIS-01", "B1") > 0 and not level.unoccupied.has("B1"), "the landing's reader punched our own card in: one of the open entries is ours, and nothing hangs on it")
	check(not game.case_info("open").get("open", false), "the open case waits for the time clock's sign or the office terminal")
	ui.open(level.office, level.player)
	ui.run("SELECT * FROM freezer_log;")
	await _frames(2)
	check(level.office.transcript.any(func(l): return str(l).contains(TerminalPolicy.REFUSAL)), "a bare SELECT * on the log is refused (P2)")
	check(game.case_info("open").get("open", false), "the first query at the time office opens the case, papers or not")
	check(game.case_query("open").begins_with("SELECT name, clock_in FROM ") and game.case_query("open").contains("IS NULL ORDER BY clock_in;"), "its query on screen names the columns the find needs (V1)")
	ui.run("SELECT * FROM freezer_log WHERE clock_out = NULL;")
	await _frames(2)
	check(not level.open_puzzle.solved and level.tips_sent.has("eq_null"), "= NULL finds nothing, and SYSOP says why: nothing equals NULL")
	ui.run("SELECT * FROM freezer_log WHERE clock_out IS NOT NULL;")
	await _frames(2)
	check(not level.open_puzzle.solved and level.tips_sent.has("not_null"), "IS NOT NULL is the visits that closed: not it")
	var first: Dictionary = level.data.echoes[0]
	var second: Dictionary = level.data.echoes[1]
	# The tempting clicks, each with its pencil line.
	ui.run("SELECT name, clock_in, clock_out FROM freezer_log ORDER BY clock_in LIMIT 13;")
	await _frames(2)
	var closed: Array = level.db.run_silent("SELECT name, clock_in FROM freezer_log WHERE clock_out IS NOT NULL ORDER BY clock_in LIMIT 1")
	_point(ui, "name", str(closed[0].name), str(closed[0].clock_in))
	check(_miss() == level.OPEN_CLOSED and not level.open_puzzle.solved, "a name on a visit that closed: that visit clocked out (V7)")
	ui.run("SELECT card, name, clock_in FROM freezer_log WHERE clock_out IS NULL ORDER BY clock_in;")
	await _frames(2)
	_point(ui, "name", str(second.name))
	check(_miss() == level.OPEN_NOT_FIRST, "another open entry: still in there, but not the longest (V9)")
	_point(ui, "name", "VISITOR")
	check(_miss() == level.OPEN_OURS, "VISITOR: that's us (V8)")
	_point(ui, "clock_in", str(first.clock_in))
	check(_miss() == level.OPEN_ROW, "the right visit's clock_in: the blank wants the name on it (V10)")
	_point(ui, "card", str(second.card))
	check(_miss() == level.OPEN_MISS and not level.open_puzzle.solved, "anything else: not that one (V11)")
	# The rack's line, noted off the paper: the rack is not the record (V6).
	var rack_line := ""
	for l in level.rack.doc_lines:
		if str(l.text).begins_with("C-"):
			rack_line = str(l.text)
	game.write_note("Card rack (IN)", rack_line, "document")
	check(_miss() == level.OPEN_RACK and game.case_info("open").blank.filled == "", "a line off the card rack: that's the rack, not the record (V6), and nothing fills")
	# The right one: the first name in, from the sorted query.
	_point(ui, "name", str(first.name))
	await _frames(3)
	check(level.open_puzzle.solved and game.case_info("open").solved, "the name of whoever's been in there longest: the case closes")
	check(game.case_info("pair").get("open", false), "then the earpieces' case opens: one case at a time")
	check(level.open_puzzle.hints[0].contains("enter_column") and level.open_puzzle.hints[0].contains("ORDER BY clock_in puts whoever went in first at the top"), "hint 1 leaves the column as enter_column and says what ORDER BY does (V13)")
	check(level.open_puzzle.spots[0].text == level.SPOT_CLOCK, "its first tier is the time clock's sign (V12)")
	ui.close()


## Points at the newest cell on screen in `column` holding `value` (in a row showing
## `row_has`), as a click does. True if it filled a slot.
func _point(ui: TerminalUI, column: String, value: String, row_has := "") -> bool:
	var lines: Array = ui.noteable_lines()
	for i in range(lines.size() - 1, -1, -1):
		if row_has != "" and not str(lines[i].text).contains(row_has):
			continue
		var cells: Array = lines[i].get("cells", [])
		for j in cells.size():
			if str(cells[j].column).to_lower() == column.to_lower() and str(cells[j].value) == value:
				return ui.use_cell(i, j)
	check(false, "a %s cell holding %s is on screen" % [column, value])
	return false


func _miss() -> String:
	return str(_game().case_info("open").get("blank", {}).get("miss", ""))


func _case_pair(level: Node) -> void:
	var game := _game()
	var h: Node = t._huddle_of(level)
	var turn: int = level._static_turn
	level._static_whisper()
	level._static_whisper()
	check(level._static_turn == turn + 2 and level.data.echoes.size() == 6, "under the walkie's static, a few words from one of tonight's rows, a different one each time")
	var steps: Array = game.case_info("pair").get("steps", [])
	check(steps.size() == 2 and steps[0].text == "Test the cradle with one set" and steps[1].text == level.TEXT.case_pair_do, "the pair case is two steps: the try with one set, then the case's own details (M1, V15)")
	check(game.case_query("pair").begins_with("let key = \"enter_key\";\nlet res = await api.post(") and not game.case_query("pair").contains("while"), "step 1's shape on screen is the try, its key a piece (V2)")
	check(level.pending_chapters == ["js_if"] and not h.done.has("js_if"), "A box and a fork waits for the book: it came with the pair case (M3)")
	check(level.it_terminal.puzzles[0] == level.try_puzzle and level.try_puzzle.spots[0].text == level.SPOT_SELF_TEST and level.pair_puzzle.spots[0].text == level.SPOT_CARD, ".hint at the cage: the try first (the cradle's label), then the pairing (the card on the bench)")
	check(level.try_puzzle.hints[0].contains("enter_key is this cradle's own key, on the sticky on the bench.") and level.try_puzzle.hints[-1].contains(level.data.key), "the try's shape and its last tier, with this run's key (V19, V20)")
	check(level.pair_puzzle.hints[0].contains("one for each of you, and one each for Ines and Tomas."), "the pairing's hint 1 counts Ines and Tomas (V22)")
	var it: Terminal = level.it_terminal
	# The card's key is the dock cradle's: 403, nothing paired.
	var rt := _run(it, level._pair_script(level.data.dock_key, "1"))
	var said := []
	rt.printed.connect(func(text, _k): said.append(text))
	await _until(func(): return not rt.is_running(), 120)
	check(level.paired == 0 and said.has("403"), "the card's own key is the dock cradle's: 403, nothing pairs (%s)" % [said])
	check(level.tips_sent.has("pair_key") and not level.tips_sent.has("pair_busy"), "and SYSOP says so on the cage's screen, for a script's request too")
	# The try: the label's script with the IT key. One set, step 1 done, no "too few".
	level.crew_size = 3
	rt = _run(it, level._try_script(level.data.key))
	await _until(func(): return not rt.is_running(), 120)
	await _frames(3)
	check(level.paired == 1 and level.try_puzzle.solved and game.case_info("pair").steps[0].done and not level.pair_puzzle.solved, "the try pairs one set: step 1 is done, the case isn't")
	check(not level.tips_sent.has("pair_short"), "one set from the try isn't too few: it was only the test")
	check(game.case_query("pair").contains("while (paired < count)") and game.case_query("pair").contains("let count = enter_count;"), "step 2's shape on screen: the pairing loop, its count a blank")
	check(level.pending_chapters == ["js_if", "js_loops"], "Again, and wait joins the wait, behind A box and a fork: one per step (M3)")
	# No wait: the cradle's busy, one set pairs.
	await _until(func(): return not level.pair_busy, 120)
	rt = _run(it, level._pair_script(level.data.key, "5").replace("  await sleep(1000);\n", ""))
	await _until(func(): return not rt.is_running(), 120)
	check(level.paired == 2 and level.pair_409s >= 2 and not level.pair_puzzle.solved, "no wait in the loop: the cradle is busy (409) and one set pairs")
	await _frames(3)
	check(level.tips_sent.has("pair_busy") and not level.tips_sent.has("pair_short"), "SYSOP: wait inside the loop (and not \"too few\": the 409s were the trouble)")
	# Too few: count 1 for a crew of three and the two night-shifters.
	await _until(func(): return not level.pair_busy, 120)
	rt = _run(it, level._pair_script(level.data.key, "1"))
	await _until(func(): return not rt.is_running(), 200)
	check(level.paired == 3 and not level.pair_puzzle.solved, "count too low: one more set, three of five, not done")
	await _frames(3)
	check(level.tips_sent.has("pair_short") and it.transcript.any(func(l): return str(l).contains("3 paired, and there are 5 of you with Ines and Tomas.")), "SYSOP: 3 paired, and there are 5 of us with Ines and Tomas (V23)")
	# No count up: it never ends, and keeps asking (409s) until Stop.
	rt = _run(it, level._pair_script(level.data.key, "5").replace("  paired = paired + 1;\n", ""))
	await _until(func(): return level.paired >= 5, 600)
	check(level.pair_puzzle.solved and game.case_info("pair").solved and level.earpieces, "a set each, and one each for Ines and Tomas: the case closes; the earpieces go in (M2)")
	check(game.case_info("pair").how == level.TEXT.pair_done % 5 and level.TEXT.pair_done.contains("two of them for Ines and Tomas"), "the solved line counts their two sets (V24)")
	check(not game.case_info("list").get("open", false), "the listing waits for the voice in the ear (M4)")
	var asked: int = level.pair_requests
	await _until(func(): return level.tips_sent.has("pair_endless"), 600)
	check(rt.is_running() and level.pair_requests > asked + 1 and level.tips_sent.has("pair_endless"), "without paired = paired + 1 the loop never ends: it keeps asking, and SYSOP says count paired up")
	rt.stop()
	check(not rt.is_running(), "and Stop ends it")
	level.crew_size = 0
	await _until(func(): return game.case_info("list").get("open", false), 300)
	check(game.case_info("list").get("open", false) and not game.case_info("hold").get("open", false), "then the listing opens, warm, before the doors")
	check(level.tips_sent.has("list_try") and it.transcript.any(func(l): return str(l).contains("try it here, where it's warm")), "with SYSOP's warm try on the cage's screen")
	check(level.pending_chapters == ["js_if", "js_loops", "js_each"], "Once for each joins the wait with the listing")
	# The book, picked up now: the earliest waiting chapter lands, the rest one per step.
	level._book_found(1)
	check(await t._huddle_opens(level, "js_if", 90.0) and not h.done.has("js_loops"), "the book picked up: A box and a fork lands, and only it")


## The warm first use of for ... of and db.query (Teaching's audit, item 1): the
## service page's loop with only a log in it, at the IT cage. Checked by what the
## log says, never by the code.
func _case_list(level: Node) -> void:
	var it: Terminal = level.it_terminal
	var names: Array = level._open_names()
	check(names.size() == 6 and not Books.chapter("js_each").is_empty(), "six open names to read, and a chapter to read them with")
	check(level.list_puzzle.hints[0].contains("enter_condition") and level.list_puzzle.hints[0].contains("const") and level.list_puzzle.hints[0].contains("!=="), "hint 1 leaves the query's test as enter_condition and explains for, const, db.query, the if with !== and the log")
	check(level._list_script("x").contains("!== \"VISITOR\""), "the listing's answer leaves ours out with !== on the name column: practised warm, before the release")
	check(level.TEXT.tip_list_try.contains("if (entry.name !== \"VISITOR\")"), "SYSOP's line at the IT cage shows the if before any hint does: found in the world first")
	# The whole list in one line: not a name a line.
	var rt := _run(it, "let open = await db.query(\"SELECT * FROM freezer_log WHERE clock_out IS NULL\");\nconsole.log(open);")
	await _until(func(): return not rt.is_running(), 200)
	check(not level.list_puzzle.solved and level.tips_sent.has("list_row"), "the whole list in one line isn't it, and SYSOP says one name a line")
	# The page's own query: vault A's names only.
	rt = _run(it, level._list_script("clock_out IS NULL AND vault = 'A'"))
	await _until(func(): return not rt.is_running(), 200)
	check(not level.list_puzzle.solved and level.tips_sent.has("list_vault"), "the page's query is vault A's: some names, not all, and SYSOP says drop the AND")
	# The cards, not the names.
	rt = _run(it, level._list_script("clock_out IS NULL").replace("entry.name", "entry.card"))
	await _until(func(): return not rt.is_running(), 200)
	check(not level.list_puzzle.solved, "the cards aren't the names")
	# No if: our own VISITOR line is logged with the six.
	var no_if: String = level._list_script("clock_out IS NULL").replace("  if (entry.name !== \"VISITOR\") {\n    console.log(entry.name);\n  }\n", "  console.log(entry.name);\n")
	check(not no_if.contains("if ("), "the loop without its if")
	rt = _run(it, no_if)
	await _until(func(): return not rt.is_running(), 200)
	await _frames(3)
	check(not level.list_puzzle.solved and level.tips_sent.has("list_ours"), "every name and VISITOR too isn't it: ours stay out, and SYSOP says an if around the log")
	# The last hint's script: every open name, one a line, and the case closes.
	var said := []
	rt = _run(it, level.list_puzzle.hints[-1].get_slice("[color=#ffffff]", 1).get_slice("[/color]", 0))
	rt.printed.connect(func(text, _k): said.append(text))
	await _until(func(): return level.list_puzzle.solved, 200)
	check(level.list_puzzle.solved and _game().case_info("list").solved and said.size() >= 6 and names.all(func(n): return said.has(n)) and not said.has("VISITOR"), "every open name logged, one a line, none of ours: the case closes (%s)" % [said])
	check(_game().case_info("list").how.contains(names[0]), "the board reads the names back")
	check(level.list_puzzle.spots[0].text == level.SPOT_PAGE_LIST and level.release_puzzle.spots[0].text == level.SPOT_PAGE_RELEASE, "the listing's and the release's first tiers are the service page (V25, V31)")
	check(await t._huddle_opens(level, "js_loops", 30.0), "the listing done is a gate: Again, and wait lands")


func _case_hold(level: Node) -> void:
	check(_game().case_info("hold").get("open", false), "the doors' case opens once the names are read")
	check(await t._huddle_opens(level, "js_each", 30.0) and level.pending_chapters.is_empty(), "and the doors' case opening is the next gate: Once for each lands, nothing else waits")
	check(_game().case_query("hold").contains("let door = \"%s\";" % level.data.doors.ante) or _game().case_query("hold").contains("let door = \"enter_door\";"), "the practice's shape on screen: the watchdog, its door the anteroom's piece")
	check(level.practice_puzzle.spots[0].text == level.SPOT_NOTE and level.hold_puzzle.spots[0].text == level.SPOT_VAULT_C, "the practice's first tier is the tech's note, the deep freeze's the sign on Vault C's door (V28, V29)")
	check(level.practice_puzzle.hints[0].contains("api.get(\"/doors/\" + door") and level.practice_puzzle.hints[0].contains("a GET has no body"), "practice's hint 1 has a line for the GET, like every other new word")
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
	_game().collect_piece("hold", "freezer_door", "test")
	_game().collect_piece("hold", "key", "test")
	check(_game().case_query("hold").contains("let door = \"enter_door\";") and _game().case_query("hold").contains("let key = \"enter_key\";"), "the deep freeze's shape on screen is bare, its pieces never filled in: under pressure")
	# Rerun without changing door: the deep freeze still latches.
	var deck: Terminal = level.decks[0]
	_move(level, Vector3(10, 0.1, -14))  # the cold corridor, by its access point
	level.player.inventory.add("deck")
	level._bench_used(1)
	await _frames(3)
	check(level.deck_net[0] == "vault" and deck.get_meta("scripts", false), "a fitted deck in the corridor is on the vaults' network, and runs scripts")
	check(level.find_children("RowLabel_*", "", true, false).size() == level.ROWS.size(), "every row has its label over the shelf, so a name in the log can be found at its row")
	# The anteroom's watchdog again, on the deck: SYSOP says change door.
	var same := _run(deck, level._watchdog(level.data.key, door))
	await _until(func(): return level.tips_sent.has("same_door"), 200)
	check(level.tips_sent.has("same_door"), "the same door twice, from the deck: SYSOP says the deep freeze is the other one")
	same.stop()
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
	var ms := int(level.punch_interval * 1000) + 300
	check(level.release_puzzle.hints[2].contains("entry.name !== \"VISITOR\"") and not level.release_puzzle.hints[2].contains("startsWith"), "the release's last tier uses what the book teaches: !== on the name column, not startsWith")
	# The release as the book teaches it: !== on the name column frees every echo and
	# leaves our own entry open.
	var good := _run(deck, level._release_script(level.data.key, "visitor", ms))
	await _until(func(): return not good.is_running(), 2400)
	check(level.all_free and not level.unoccupied.has("C") and level._open_crew_entry("VIS-01", "C") > 0, "the release with its if frees every echo and leaves our own entry open")
	await _frames(5)
	check(not _game().case_info("stop").get("open", false) and level.stop_waiting, "every entry closed, in the cold: leaving it tidy waits for the warm (M5)")
	# The if forgotten: it closes our own entry too, and Vault C goes dark.
	var no_if: String = level._release_script(level.data.key, "true", ms)
	var rt := _run(deck, no_if)
	await _until(func(): return not rt.is_running(), 2400)
	check(level.unoccupied.has("C") and level._door_locked(level.data.doors.vault_c), "but without the if it closes our own entry: the clock thinks Vault C is empty, dark and latched")
	res = _req(deck, _key(level, "PATCH /doors/" + level.data.doors.vault_c, "{\"locked\": false}"))
	check(res.status == 409, "the watchdog can't unlatch an empty vault (409)")
	await _until(func(): return not level.printing, 120)
	res = _req(deck, _key(level, "POST /clock_ins", "{\"card\": \"VIS-01\", \"vault\": \"C\"}"))
	check(res.status == 201 and not level.unoccupied.has("C"), "punched back in from the deck: Vault C's lights come back")
	check(_game().case_info("release").solved and level.stairs_open, "everyone's free: the case closes and STAIR 2's gate opens")
	check(_game().current_todo() == level.TEXT.todo_down and level.TASK_TITLES.todo_down == "Let them rest", "the to-do says back to the landing and down, under its own title")
	# They tell their stories one at a time now (HUD turns), so this takes a couple of minutes.
	Engine.time_scale = 4.0
	await _until(func(): return level.find_children("Left_*", "", true, false).size() == 6, 12000)
	Engine.time_scale = 1.0
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
