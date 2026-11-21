extends RefCounted
## The terminal security policy (plan/teaching/v0.10-policy.md, builder notes):
## bare SELECT * refused with P2 alone, results capped at 20 with P4, .help and
## the boot screen, SYSOP's P9 after a refusal, scripts too, and a sweep that
## every answer and hint query on a policy terminal passes it.

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	test_rule()
	await test_at_a_terminal()
	await test_sweep()


func _game() -> Node:
	return _tree.root.get_node("/root/Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree.physics_frame


func test_rule() -> void:
	print("Security policy: the rule")
	var refused := [
		"SELECT * FROM doors;", "select * from doors", "SELECT DISTINCT * FROM doors;", "SELECT d.* FROM doors d;",
		"SELECT * FROM doors AS d;", "  SELECT *\n  FROM doors ;  ", "SELECT * FROM doors; -- (WHERE)",
		"SELECT * FROM (SELECT * FROM doors WHERE zone = 'B1');",
	]
	var passed := [
		"SELECT id, zone FROM doors;", "SELECT * FROM doors WHERE zone = 'B1';", "SELECT * FROM doors ORDER BY id;",
		"SELECT * FROM doors LIMIT 5;", "SELECT zone, COUNT(*) FROM doors GROUP BY zone;", "SELECT COUNT(*) FROM doors;",
		"SELECT * FROM doors WHERE 1 = 1;", "SELECT * FROM doors JOIN lights ON lights.zone = doors.zone;",
		"SELECT * FROM doors, lights;", "SELECT * FROM doors WHERE id IN (SELECT id FROM doors);",
		"UPDATE doors SET locked = 0;", "SELECT 'SELECT * FROM doors';", "SELECT * FROM doors d WHERE d.locked = 1;",
	]
	var wrong_refused := passed.filter(func(q): return TerminalPolicy.refuses(q))
	var wrong_passed := refused.filter(func(q): return not TerminalPolicy.refuses(q))
	check(wrong_passed.is_empty(), "bare SELECT * is refused however it's written: DISTINCT, t.*, an alias, a subquery as the table, comments (%s)" % [wrong_passed])
	check(wrong_refused.is_empty(), "named columns, WHERE (even 1 = 1), ORDER BY, LIMIT, GROUP BY, COUNT, a join and writes all pass (%s)" % [wrong_refused])
	var boot := TerminalPolicy.boot_with_line(["HALCYON", "SESSION: GUEST (lockdown mode, read only)", "Type .help"])
	check(boot[2] == TerminalPolicy.BOOT_LINE and boot.size() == 4, "the boot line goes under the session line")


func test_at_a_terminal() -> void:
	print("Security policy: at a terminal")
	var g := _game()
	g.new_run(31)
	var level = load("res://scenes/level_0.tscn").instantiate()
	_tree.root.add_child(level)
	await _frames(12)
	g.mark_floor_start("level_test")
	var term: Node = level.desk_terminal
	var ui: TerminalUI = level.terminal_ui
	term.db.execute("CREATE TABLE big_log (n INTEGER, note TEXT)")
	for i in 30:
		term.db.execute("INSERT INTO big_log VALUES (%d, 'entry %d')" % [i, i])
	term.db.execute("CREATE TABLE one_row (n INTEGER)")
	term.db.execute("INSERT INTO one_row VALUES (1)")
	ui.open(term, level.player)
	# Without the flag, nothing changes.
	ui.run("SELECT * FROM big_log;")
	check(not term.transcript.any(func(l): return l.contains("42501")) and term.transcript.any(func(l): return l.contains("entry 29")), "a terminal without the policy shows every row, as before")
	term.policy = true
	check(term.boot_text().has(TerminalPolicy.BOOT_LINE), "a policy terminal's boot screen says so")
	g.notebook_tables.erase("one_row")
	for t in ["one_row", "big_log"]:
		var at: int = term.transcript.size()
		ui.run("SELECT * FROM %s;" % t)
		var shown: Array = term.transcript.slice(at)
		check(shown.size() == 2 and TerminalUI._plain(shown[1]) == TerminalPolicy.REFUSAL, "SELECT * FROM %s is refused with \"%s\" and nothing else" % [t, TerminalPolicy.REFUSAL])
	check(not g.notebook_tables.has("one_row"), "a refused query notes no table or columns")
	var before: int = term.transcript.size()
	ui.run("SELECT DISTINCT * FROM one_row;")
	check(TerminalUI._plain(term.transcript[-1]) == TerminalPolicy.REFUSAL, "SELECT DISTINCT * is refused too")
	# SYSOP after a refusal: the card first, then plainly once it's been read, once a floor.
	ui.run(".hint")
	check(TerminalUI._plain(term.transcript[-1]).contains(TerminalPolicy.HINT_UNREAD), "the next .hint points at the posted policy (P9a)")
	var card := TerminalPolicy.place_card(level.geo, Vector3(1, 1, 1), 0.0)
	card.report_open(level.player)
	check(g.spot_found(TerminalPolicy.SPOT) and g.notebook_written.any(func(w): return w.text == TerminalPolicy.NOTE), "reading a copy of the card puts the policy in the notebook (P6)")
	ui.run("SELECT * FROM one_row;")
	ui.run(".hint")
	check(TerminalUI._plain(term.transcript[-1]).contains(TerminalPolicy.HINT_READ), "after a copy's been read, it says it plainly (P9b)")
	ui.run("SELECT * FROM one_row;")
	ui.run(".hint")
	check(not TerminalUI._plain(term.transcript[-1]).contains(TerminalPolicy.HINT_READ), "only once a floor: then the case's own hints")
	ui.run(".hint")
	check(not TerminalUI._plain(term.transcript[-1]).contains("policy"), "and .hint without a refusal before it is the case's own")
	# What passes, and the cap.
	before = term.transcript.size()
	ui.run("SELECT n, note FROM big_log;")
	var out: String = "\n".join(term.transcript.slice(before).map(func(l): return TerminalUI._plain(l)))
	check(out.contains("entry 19") and not out.contains("entry 20") and out.contains(TerminalPolicy.CAPPED), "more than 20 rows: the first 20 show, with the policy's footer (P4)")
	before = term.transcript.size()
	ui.run("SELECT * FROM big_log WHERE n > 25;")
	out = "\n".join(term.transcript.slice(before).map(func(l): return TerminalUI._plain(l)))
	check(out.contains("entry 29") and not out.contains(TerminalPolicy.CAPPED) and not out.contains("42501"), "a WHERE passes, and under 20 rows there's no footer")
	ui.run("SELECT * FROM big_log LIMIT 50;")
	check(TerminalUI._plain(term.transcript[-1]) == TerminalPolicy.CAPPED, "a LIMIT over 20 is capped the same")
	ui.run("UPDATE big_log SET note = 'wiped';")
	check(term.db.execute("SELECT COUNT(*) AS c FROM big_log WHERE note = 'wiped'").rows[0].c == 30, "an UPDATE with no WHERE still runs: the policy covers what's shown, not what's changed")
	# .help, .tables and .schema.
	before = term.transcript.size()
	ui.run(".help")
	out = "\n".join(term.transcript.slice(before).map(func(l): return TerminalUI._plain(l)))
	check(not out.contains(".tables") and not out.contains(".schema") and out.contains(TerminalPolicy.HELP_LINE), ".help leaves out .tables and .schema and says the policy is in effect (P7)")
	before = term.transcript.size()
	ui.run(".schema big_log")
	ui.run(".tables")
	out = "\n".join(term.transcript.slice(before).map(func(l): return TerminalUI._plain(l)))
	check(out.contains("note") and out.contains("big_log") and not out.contains("42501"), "but .schema and .tables still work")
	# Scripts at a policy terminal follow it.
	var lib := BuildingLibrary.new(null, term.db, true)
	var r := lib.query("SELECT * FROM big_log")
	check(not r.ok and r.error == TerminalPolicy.REFUSAL, "a script's db.query is refused the same way")
	r = lib.query("SELECT n FROM big_log")
	check(r.ok and r.rows.size() == TerminalPolicy.CAP, "and capped at 20 rows")
	check(BuildingLibrary.new(null, term.db).query("SELECT * FROM big_log").rows.size() == 30, "a script elsewhere isn't")
	ui.close()
	level.queue_free()
	await _tree.process_frame


## Every puzzle answer and every query a hint shows, on every terminal under the
## policy on every floor, passes it (plan/teaching/v0.10-policy.md, part 4).
func test_sweep() -> void:
	print("Security policy: every answer and hint on a policy terminal passes")
	var g := _game()
	var terminals := 0
	var bad: Array[String] = []
	var i := 0
	while ResourceLoader.exists("res://scenes/level_%d.tscn" % i):
		g.new_run(7)
		var level = load("res://scenes/level_%d.tscn" % i).instantiate()
		_tree.root.add_child(level)
		await _frames(4)
		for t in level.find_children("*", "Terminal", true, false):
			if not t.policy:
				continue
			terminals += 1
			for p in t.puzzles:
				var qs: Array = [p.solution_sql]
				for h in p.hints:
					for m in RegEx.create_from_string("(?im)\\bSELECT\\b[^;\\n]*;?").search_all(TerminalUI._plain(str(h))):
						qs.append(m.get_string())
				for q in qs:
					if TerminalPolicy.refuses(q):
						bad.append("level %d %s %s: %s" % [i, t.name, p.id, q])
		level.queue_free()
		await _tree.process_frame
		i += 1
	print("    %d terminals under the policy" % terminals)
	check(bad.is_empty(), "no answer or hint on a policy terminal is a query it refuses (%s)" % ["\n  ".join(bad)])


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)
