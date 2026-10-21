extends RefCounted
## Deck scripts: the JavaScript runtime (scripts/core/script/). Programs in
## tests/js/ print what Node 22 printed for them (their .out files); 07 uses the
## building's api and db, which Node doesn't have, so its .out was checked by hand.

var _check: Callable


func run(_tree: SceneTree, check: Callable) -> void:
	_check = check
	print("Deck scripts (JavaScript)")
	test_programs_match_node()
	test_refused_javascript()
	test_run_time_errors()
	test_limits()
	test_waiting_and_frames()
	test_stop_and_leaks()
	test_building_library()
	test_sandbox_and_seed()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


## Runs `code` to the end (or `seconds` of game time) in steps of `delta`.
## Returns {rt, lines, ticks}; lines are what the script printed.
func run_js(code: String, library: BuildingLibrary = null, seconds := 60.0, delta := 0.1, seed_value := 1) -> Dictionary:
	var rt := ScriptRuntime.for_language("javascript")
	var lines: Array = []
	rt.printed.connect(func(text, _kind): lines.append(text))
	var ticks := 0
	if rt.compile(code).ok:
		rt.start(library if library else _building(), seed_value)
		while rt.is_running() and rt.clock() < seconds:
			rt.tick(delta, 1_000_000)
			ticks += 1
	return {"rt": rt, "lines": lines, "ticks": ticks}


## The error a script stops with, as the deck would show it.
func error_of(code: String) -> Dictionary:
	var r := run_js(code)
	return r.rt.error


## Three doors and a service: GET /doors/:id, and PATCH with the "doors" key.
func _building() -> BuildingLibrary:
	var db := FacilityDB.new()
	db.load_seed("""
		INSERT INTO doors (id, name, zone, locked, actuator_fault) VALUES
		('D-12', 'Cold store', 'C', 1, 0), ('D-14', 'Freezer', 'C', 1, 0), ('D-20', 'Lobby', 'A', 0, 0);
	""")
	var api := FacilityAPI.new()
	api.add_key("7f3a-22", ["doors"])
	var door := func(id: String):
		var rows := db.run_silent("SELECT id, locked FROM doors WHERE id = '%s'" % id.to_upper().replace("'", ""))
		return {"id": rows[0].id, "locked": int(rows[0].locked) == 1} if rows else null
	api.route("GET", "/doors/:id", func(p):
		var d = door.call(p[0])
		return {"status": 200, "body": d} if d else {"status": 404, "body": {"error": "No door %s." % p[0]}})
	api.route("PATCH", "/doors/:id", func(p, req):
		var bad := FacilityAPI.check_fields(req.body, {"locked": TYPE_BOOL})
		if bad != "":
			return {"status": 400, "body": {"error": bad}}
		db.run_silent("UPDATE doors SET locked = %d WHERE id = '%s'" % [1 if req.body.locked else 0, str(p[0]).to_upper().replace("'", "")])
		return {"status": 200, "body": door.call(p[0])}, "doors")
	return BuildingLibrary.new(api, db)


func test_programs_match_node() -> void:
	for f in DirAccess.get_files_at("res://tests/js"):
		if not f.ends_with(".js"):
			continue
		var code := FileAccess.get_file_as_string("res://tests/js/" + f)
		var want := FileAccess.get_file_as_string("res://tests/js/" + f.trim_suffix(".js") + ".out").strip_edges()
		var r := run_js(code)
		var got := "\n".join(PackedStringArray(r.lines)).strip_edges()
		check(r.rt.state == ScriptRuntime.State.DONE and got == want, "%s prints what Node printed%s" % [f, "" if got == want else "\n--- got:\n%s\n--- error: %s" % [got, r.rt.error]])


func test_refused_javascript() -> void:
	# Real JavaScript the deck doesn't run is refused before the script starts,
	# on the right line, with what to use instead.
	var cases := [
		["var x = 1;", "Use let", 1],
		["let a = 1;\nclass Door {}", "Classes", 2],
		["const d = new Date();", "new", 1],
		["function f() { return this; }", "this", 1],
		["switch (x) {}", "if / else if", 1],
		["do { } while (true);", "Use while", 1],
		["try { } catch (e) { }", "try / catch", 1],
		["throw 1;", "assert()", 1],
		["const o = {a: 1};\ndelete o.a;", "delete", 2],
		["import x from 'y';", "import", 1],
		["for (const k in obj) {}", "Object.keys", 1],
		["const all = [...list];", "Spreading", 1],
		["let {a} = obj;", "Unpacking", 1],
		["function f(a = 1) {}", "Default values", 1],
		["const o = {[k]: 1};", "Computed keys", 1],
		["const x = 5 & 3;", "&&", 1],
		["function f() { await sleep(1); }", "async function", 1],
		["let x = 1;\nlet x = 2;", "already declared", 2],
		["const n = 1;\nn = 2;", "const", 2],
		["if (x) let y = 1;", "{ }", 1],
		["return 5;", "inside a function", 1],
		["break;", "inside a loop", 1],
		["let s = \"open", "never ends", 1],
		["if (door.locked {\n}", "Close the condition", 1],
		["let total = 0\ntotal = total + 5 total", "missing before total", 2],
	]
	for c in cases:
		var rt := ScriptRuntime.for_language("javascript")
		var res := rt.compile(c[0])
		check(not res.ok and res.error.message.contains(c[1]) and res.error.line == c[2], "refused: %s -> %s" % [c[0].replace("\n", " / "), res.error.get("message", "(it compiled)")])
	var shown := ScriptRuntime.format_error("let x = 1\nif (door.locked {", {"line": 2, "col": 17, "message": "Close the condition with )"})
	check(shown == "Line 2: Close the condition with )\n  2 | if (door.locked {\n    |                 ^", "errors show the line and a ^ under the column")


func test_run_time_errors() -> void:
	var cases := [
		["const doors = [1];\nconsole.log(dors.length);", 2, "Did you mean doors?"],
		["let total = 0;\nTotal = 5;", 2, "Did you mean total?"],
		["console.log(nothingLikeIt);", 1, "Check the spelling"],
		["const cam = { id: 'CAM-2' };\nconsole.log(cam.status.motion);", 2, "cam.status is undefined, so it has no .motion"],
		["const door = {};\ndoor.unlock();", 2, "door.unlock isn't a function"],
		["const n = 5;\nn();", 2, "isn't a function"],
		["console.log(x);\nlet x = 1;", 1, "before its let line"],
		["function down(n) { return down(n - 1); }\ndown(5);", 1, "keep calling itself"],
		["assert(1 + 1 === 3, 'maths is broken');", 1, "assert failed: maths is broken"],
		["JSON.parse(\"{'a': 1}\");", 1, "double quotes"],
		["for (const x of 5) {}", 1, "for ... of needs a list"],
		["console = 1;", 1, "built in"],
		["const p = sleep(10);\np.then(() => 1);", 2, "Use await"],
		["[1, 2].map(async x => x).forEach(p => p.toFixed());", 1, "isn't a function"],
	]
	for c in cases:
		var e := error_of(c[0])
		check(e.get("line", 0) == c[1] and str(e.get("message", "")).contains(c[2]), "run-time error on line %d: %s (%s)" % [c[1], c[2], e.get("message", "no error")])


func test_limits() -> void:
	var e := error_of("let i = 0;\nwhile (i < 10) {\n  console.log('checking');\n}")
	check(str(e.get("message", "")).contains("without waiting") and e.line in [2, 3], "a loop that never ends is stopped, naming a line in the loop")
	e = error_of("const all = [];\nfor (let i = 0; i < 400; i++) {\n  all.push('x'.repeat(900).split(''));\n  await sleep(1);\n}")
	check(str(e.get("message", "")).contains("holding too much"), "a script holding too much is stopped (%s)" % e.get("message", ""))
	e = error_of("let s = 'ab';\nwhile (true) { s = s + s; }")
	check(str(e.get("message", "")).contains("too long"), "text can't grow without limit")
	e = error_of("const a = [];\na[20000] = 1;")
	check(str(e.get("message", "")).contains("more than"), "lists can't grow without limit")
	var r := run_js("let n = 0;\nwhile (true) { n++; await sleep(0); }", null, 3.0)
	check(r.rt.is_running(), "a loop that waits each pass may run for as long as it likes")
	r.rt.stop()


func test_waiting_and_frames() -> void:
	var r := run_js("let n = 0;\nwhile (n < 5) {\n  n++;\n  await sleep(1000);\n}\nconsole.log('polled', n);")
	check(r.lines == ["polled 5"] and absf(r.rt.clock() - 5.0) < 0.15, "await sleep(1000) waits a second of game time (done at %.2f s)" % r.rt.clock())
	var rt := ScriptRuntime.for_language("javascript")
	rt.compile("console.log('a');\nawait sleep(500);\nconsole.log('b');")
	rt.start(_building())
	rt.tick(0.1)
	check(rt.state == ScriptRuntime.State.WAITING, "a sleeping script is WAITING, not RUNNING")
	for i in 5:
		rt.tick(0.1)
	check(rt.state == ScriptRuntime.State.DONE, "and finishes once the time has passed")
	# A long loop is spread over frames; no frame runs much past its budget.
	rt = ScriptRuntime.for_language("javascript")
	rt.compile("let sum = 0;\nfor (let i = 0; i < 8000; i++) {\n  sum += i;\n}\nconsole.log(sum);")
	var out := []
	rt.printed.connect(func(t, _k): out.append(t))
	rt.start(_building())
	var frames := 0
	var worst := 0
	while rt.is_running() and frames < 1000:
		var t0 := Time.get_ticks_usec()
		rt.tick(1.0 / 60.0, 2_000)
		worst = maxi(worst, Time.get_ticks_usec() - t0)
		frames += 1
	check(out == ["31996000"] and frames > 1, "an 8,000-pass loop runs across %d frames and gets the right answer (%s)" % [frames, out])
	check(worst < 12_000, "no frame spends much more than its 2 ms on the script (worst %.1f ms)" % (worst / 1000.0))
	r = run_js("let sum = 0;\nfor (let i = 0; i < 1000; i++) {\n  sum += i;\n}")
	check(r.rt.steps() < 12_000, "a 1,000-pass loop takes about ten steps a pass (%d)" % r.rt.steps())


func test_stop_and_leaks() -> void:
	var rt := ScriptRuntime.for_language("javascript")
	rt.compile("while (true) { await sleep(100); }")
	var ended := []
	rt.finished.connect(func(ok, err): ended.append([ok, err]))
	rt.start(_building())
	rt.tick(0.5)
	rt.stop()
	check(rt.state == ScriptRuntime.State.STOPPED and ended == [[false, {}]], "Stop ends a script: not ok, and no error")
	rt.tick(0.5)
	check(rt.state == ScriptRuntime.State.STOPPED, "a stopped script stays stopped")
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var r := run_js("for (let i = 0; i < 300; i++) {\n  const o = { n: i };\n  o.self = o;\n  const f = () => f;\n  o.f = f;\n}")
	r = {}
	var after := Performance.get_monitor(Performance.OBJECT_COUNT)
	check(after - before < 50, "objects that refer to themselves are freed when the script ends (%d left)" % int(after - before))


func test_building_library() -> void:
	var lib := _building()
	var refused := []
	lib.write_refused.connect(func(sql): refused.append(sql))
	var e: Dictionary = run_js("const r = await db.query(\"SELECT id FROM doors\");\nawait db.query(\"UPDATE doors SET locked = 0\");", lib).rt.error
	check(e.get("message") == BuildingLibrary.WRITE_REFUSED and e.line == 2 and refused.size() == 1, "a write through db.query is refused with WARDEN's line, and the level hears about it")
	check(int(lib.db.run_silent("SELECT COUNT(*) AS n FROM doors WHERE locked = 1")[0].n) == 2, "and nothing changed")
	check(lib.query("SELECT 1; DELETE FROM doors").error.contains("One query"), "one statement at a time")
	check(lib.query("SELECT id FROM doors WHERE name = 'a?b;c'").ok, "a ? or ; inside quotes is just text")
	check(lib.query("SELECT id FROM doors WHERE zone = ?", []).error.contains("1 ? but 0 values"), "placeholders and values must match")
	var r := lib.query("SELECT id FROM doors WHERE zone = ? ORDER BY id", ["C"])
	check(r.ok and r.rows.map(func(x): return x.id) == ["D-12", "D-14"], "values fill the ? placeholders")
	check(not lib.query("SELECT * FROM dors").ok and lib.query("SELECT * FROM dors").error.contains(".tables"), "a SQL error comes with the terminal's plain explanation")
	lib.read_only = false
	check(lib.query("UPDATE doors SET locked = 0 WHERE id = 'D-20'").ok, "before Epsilon (a test bench, say) writes go through")
	var sent := []
	lib.requested.connect(func(m, p, _h, _b, reply): sent.append([m, p, reply.status]))
	run_js("await api.patch('/doors/D-12', { locked: false }, { 'X-Api-Key': '7f3a-22' });", lib)
	check(sent == [["PATCH", "/doors/D-12", 200]], "each request a script sends is reported, for the level and co-op")
	var none := BuildingLibrary.new()
	check(none.request("GET", "/doors").status == 503 and not none.query("SELECT 1").ok, "a deck with no building answers 503")
	e = error_of("await api.get(42);")
	check(str(e.get("message", "")).contains("path in quotes"), "api calls check their path")
	e = error_of("await api.get('/doors/D-12', 'X-Api-Key: 1');")
	check(str(e.get("message", "")).contains("Headers go in an object"), "and their headers")


func test_sandbox_and_seed() -> void:
	for name in ["OS", "Engine", "load", "preload", "get_node", "ProjectSettings", "FileAccess", "Game", "fetch", "require", "globalThis", "eval"]:
		var e := error_of("%s;" % name)
		check(str(e.get("message", "")).contains("isn't defined"), "scripts can't reach %s" % name)
	var a: Array = run_js("console.log(Math.random(), Math.random());", null, 60.0, 0.1, 7).lines
	var b: Array = run_js("console.log(Math.random(), Math.random());", null, 60.0, 0.1, 7).lines
	var c: Array = run_js("console.log(Math.random(), Math.random());", null, 60.0, 0.1, 8).lines
	check(a == b and a != c, "Math.random follows the run's seed, so every co-op machine agrees")
