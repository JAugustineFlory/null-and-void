extends RefCounted
## B2, the machine room (Level 7): its data across seeds; tokens on FacilityAPI (a key
## alone is 401, a token traded for it works, runs out, can be revoked, and every
## machine hands out the same ones); the floor's lights and lifts services (the
## emergency circuit's 403, the lifts held by WARDEN, the freight lift's out of
## service); the token case at the admin terminal (the key header, the runbook's dead
## example, no Bearer, the bench's token on the floor, a token that ran out, and
## SYSOP's line for each); the test bench (its own fake floor, dark at every run, its
## asserts counted): one zone with a function (no return, no assert, no zone, no
## async) and every zone from a list (one missing, the emergency circuit in it); the
## tested script works on the floor too; the guards (nothing names Mercer or Vale,
## no Rourke, WARDEN gives no tips). Run in the floor_b2 group.

var t: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("B2: the machine room")
	test_data_every_seed()
	test_tokens()
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


func _deck_said(term: Node, text: String) -> bool:
	return term.transcript.any(func(l): return str(l).contains(text.left(30)))


## Runs `code` as a script on `term`, as the runner does (the level listens first, as
## it does once a runner is opened).
func _run(level: Node, term: Node, code: String) -> ScriptRuntime:
	var rt: ScriptRuntime = term.get_meta("script_runtime") if term.has_meta("script_runtime") else ScriptRuntime.for_language("javascript")
	var c := rt.compile(code)
	if not c.ok:
		push_warning("compile failed: %s" % c.error)
		return rt
	term.set_meta("script_runtime", rt)
	level._watch_scripts()
	rt.start(BuildingLibrary.new(term.api, term.db), 1)
	return rt


func _done(rt: ScriptRuntime, frames := 600) -> void:
	await _until(func(): return not rt.is_running(), frames)
	await _frames(2)


func _req(term: Node, line: String) -> Dictionary:
	return term.api.request(line)


func _bearer(req: String, token: String, body := "") -> String:
	var out := "%s\nAuthorization: Bearer %s" % [req, token]
	if body != "":
		out += "\n\n" + body
	return out


func _token(term: Node, key: String) -> String:
	var res := _req(term, "POST /auth/token {\"key\": \"%s\"}" % key)
	return str(res.body.get("token", "")) if res.body is Dictionary else ""


func test_data_every_seed() -> void:
	print("B2: data across seeds")
	var l7_script: Script = load("res://scripts/levels/level_7.gd")
	var ok_zones := true
	var ok_lifts := true
	var ok_sql := true
	var ok_times := true
	var ok_scripts := true
	var keys := {}
	var ids := {}
	var orders := {}
	var decoys := {}
	for s in range(1, 61):
		var d := Level7Data.build(s)
		var zone_ids := {}
		for z in d.zones:
			zone_ids[z.id] = true
		ok_zones = ok_zones and d.zones.size() == 6 and zone_ids.size() == 6 and not zone_ids.has(d.emergency.id)
		ok_zones = ok_zones and d.listed.size() == 7 and d.listed.has(d.emergency.id) and d.first_cut.size() == 2 and d.first_cut.all(func(id): return zone_ids.has(id))
		var cars: Array = d.lifts.filter(func(l): return l.kind == "passenger")
		ok_lifts = ok_lifts and d.lifts.size() == 3 and cars.size() == 2 and d.lifts.filter(func(l): return l.kind == "freight").size() == 1
		ok_lifts = ok_lifts and cars.all(func(l): return int(str(l.id).trim_prefix("LIFT-")) in [1, 2, 3, 4]) and cars[0].id != cars[1].id
		var db := FacilityDB.new()
		db.load_seed(d.sql)
		var ring := db.run_silent("SELECT id FROM lights WHERE floor = -2 AND status = 'ok' AND id LIKE 'B2-Z%'")
		ok_sql = ok_sql and ring.size() == 6 and db.run_silent("SELECT id FROM lights WHERE status = 'standby'").size() == 1
		ok_times = ok_times and d.token_seconds >= 150.0 and d.token_seconds <= 240.0 and d.key != "" and d.example_token.begins_with("tok_")
		keys[d.key] = true
		ids[d.zones[0].id] = true
		orders[",".join(PackedStringArray(d.listed))] = true
		decoys[",".join(PackedStringArray(d.lifts.map(func(l): return l.id)))] = true
		# The hints' scripts compile for every run's key and zones.
		var zone_list: Array = d.zones.map(func(z): return z.id)
		for code in [l7_script._one_script(d.key, zone_list[0]), l7_script._every_script(d.key, zone_list)]:
			ok_scripts = ok_scripts and ScriptRuntime.for_language("javascript").compile(code).ok
	check(ok_zones, "every run has six ring zones with different ids, the emergency circuit apart, all seven listed, two cut first")
	check(ok_lifts, "two of lifts 1 to 4 come down to B2, and the freight lift")
	check(ok_sql, "the lights table has the six zones and the emergency circuit on standby")
	check(ok_times, "a token lasts 150 to 240 s; the runbook's example token is a real-looking one")
	check(ok_scripts, "the hints' scripts compile for every seed's key and zones")
	check(keys.size() > 50 and ids.size() > 30 and orders.size() > 50 and decoys.size() > 6, "keys, zone ids, the listing's order and which lifts come down change with the seed (%d, %d, %d, %d)" % [keys.size(), ids.size(), orders.size(), decoys.size()])


## Tokens on FacilityAPI, with no level: a route with auth "token" takes a bearer
## token traded for a key; a key alone, a bad header, an unknown, expired or revoked
## token is 401, each saying what to do; scopes still hold (403).
func test_tokens() -> void:
	print("B2: tokens on FacilityAPI")
	var a := FacilityAPI.new()
	a.add_key("7f3a-2201", ["lights"], "admin")
	a.add_key("0000-1111", ["doors"], "doors only")
	a.enable_tokens(120.0, 99)
	a.route("GET", "/lights", func(_p): return {"status": 200, "body": {"zones": []}}, "lights", "token")
	a.route("GET", "/doors", func(_p): return {"status": 200, "body": {}}, "doors", "token")
	var issued := []
	a.token_issued.connect(func(tok, secs): issued.append([tok, secs]))
	var res := a.request("GET /lights")
	check(res.status == 401 and str(res.body.error).contains("Authorization: Bearer"), "no token: 401, and how to send one")
	res = a.request("GET /lights\nX-Api-Key: 7f3a-2201")
	check(res.status == 401 and str(res.body.error).begins_with("This service takes tokens"), "the key header alone: 401, tokens not keys (%s)" % res.body)
	res = a.request("POST /auth/token {\"key\": \"7f3a-2200\"}")
	check(res.status == 401 and issued.is_empty(), "a wrong key gets no token")
	res = a.request("POST /auth/token {\"secret\": \"7f3a-2201\"}")
	check(res.status == 400 and str(res.body.error).contains("{\"key\""), "a body without the key field is 400, with the shape")
	res = a.request("POST /auth/token {\"key\": \"7f3a-2201\"}")
	var tok: String = str(res.body.get("token", ""))
	check(res.status == 201 and tok.begins_with("tok_") and tok.length() == 16 and res.body.expires_in == 120 and issued == [[tok, 120.0]], "the key trades for a token, good for its seconds (%s)" % res.body)
	res = a.request("GET /lights\nAuthorization: Bearer " + tok)
	check(res.status == 200, "the token works")
	res = a.request("GET /lights\nauthorization: bearer " + tok)
	check(res.status == 200, "header names and the word Bearer in any case")
	res = a.request("GET /lights\nAuthorization: " + tok)
	check(res.status == 401 and str(res.body.error).begins_with("Send the token after the word Bearer"), "no Bearer: 401, and how it's written")
	res = a.request("GET /lights\nAuthorization: Bearer tok_000000000000")
	check(res.status == 401 and str(res.body.error).begins_with("That token isn't one"), "a token this service never gave out: 401")
	res = a.request("POST /auth/token {\"key\": \"0000-1111\"}")
	var doors_tok: String = str(res.body.get("token", ""))
	res = a.request("GET /lights\nAuthorization: Bearer " + doors_tok)
	check(res.status == 403 and a.request("GET /doors\nAuthorization: Bearer " + doors_tok).status == 200, "a token carries its key's scopes: 403 elsewhere")
	a.expire_token(tok)
	res = a.request("GET /lights\nAuthorization: Bearer " + tok)
	check(res.status == 401 and res.body.get("expired", false) and a.token_state(tok) == "expired", "once it's run out: 401, expired")
	res = a.request("POST /auth/revoke\nAuthorization: Bearer %s\n\n{\"token\": \"%s\"}" % [doors_tok, doors_tok])
	check(res.status == 200 and a.token_state(doors_tok) == "revoked" and a.request("GET /doors\nAuthorization: Bearer " + doors_tok).status == 401, "a token can revoke itself, and is refused after")
	a.add_token("tok_aaaaaaaaaaaa", "7f3a-2201", true)
	check(a.request("GET /lights\nAuthorization: Bearer tok_aaaaaaaaaaaa").status == 401 and a.token_label("tok_aaaaaaaaaaaa") == "admin", "a token added as expired (a runbook's example) is refused")
	# Every machine hands out the same tokens, in the same order, from the same seed.
	var b := FacilityAPI.new()
	b.add_key("7f3a-2201", ["lights"])
	b.enable_tokens(120.0, 99)
	var c := FacilityAPI.new()
	c.add_key("7f3a-2201", ["lights"])
	c.enable_tokens(120.0, 99)
	var same := true
	for i in 5:
		same = same and b.request("POST /auth/token {\"key\": \"7f3a-2201\"}").body.token == c.request("POST /auth/token {\"key\": \"7f3a-2201\"}").body.token
	check(same, "two copies of a service hand out the same tokens in the same order (co-op)")
	check(FacilityAPI.status_text(423) == "Locked", "423 reads Locked")


## Nothing on B2 names, shows or hints at Mercer or Vale (his fate is undecided; her
## reveal is Level 10), Rourke isn't on this floor yet, and WARDEN gives no tips.
func test_guards() -> void:
	var s: Script = load("res://scripts/levels/level_7.gd")
	var consts := s.get_script_constant_map()
	var text := JSON.stringify([consts.TEXT, consts.TASK_TITLES, consts.RUNBOOK, consts.KEY_STICKY, consts.BENCH_CARD, consts.PRINTOUT,
		consts.EM_LABEL, consts.MEMO_LINES, consts.STAND_LINES, consts.FREIGHT_SIGN, Level7Data.ZONE_NAMES])
	var low := text.to_lower()
	check(not low.contains("mercer") and not low.contains("vale") and not low.contains("h.m.") and not low.contains("iris"), "nothing on B2 names Mercer or Vale")
	check(not low.contains("rourke"), "and no Rourke lines")
	var warden := VoiceLines.ids_in_scene("l7_floor_b2").map(func(id): return str(VoiceLines.get_line(id).text).to_lower())
	check(warden.size() >= 2 and warden.all(func(l): return not l.contains("token") and not l.contains("bench") and not l.contains("assert") and not l.contains("function")),
		"WARDEN's lines on B2 never give a tip (%d lines)" % warden.size())
	var tips: Array = consts.TEXT.keys().filter(func(k): return str(k).begins_with("tip_"))
	check(tips.size() >= 10, "SYSOP has a line for each mistake (%d)" % tips.size())


func test_floor() -> void:
	print("B2: the floor")
	_game().new_run(4242)
	var level: Node = load("res://scenes/level_7.tscn").instantiate()
	level.first_cut_after = 0.5
	t.root.add_child(level)
	await _frames(5)
	check(level.db.read_only, "the database only reads (Epsilon)")
	check(level.decks.size() == 6 and level.admin_terminal and level.bench_terminal, "a deck for every player slot, the admin terminal and the bench")
	check(level.lights.has(level.data.zones[0].id) and level.lights[level.data.zones[0].id].size() == 2, "each ring zone has its lights")
	check(_game().current_todo() == level.TEXT.todo_arrive, "the to-do: find the IT admin office")
	await _until(func(): return level.cut_zones.size() == 2, 120)
	var cut: Array = level.data.first_cut
	check(cut.all(func(id): return not level.zone_on(id) and not level.lights[id][0].visible), "WARDEN cuts two zones of the ring: dark in the lights table, and their lights out")

	await _case_token(level)
	await _services(level)
	await _case_restore(level)
	await _case_zones(level)
	await _on_the_floor(level)
	level.queue_free()
	await _frames(2)


func _case_token(level: Node) -> void:
	var admin: Terminal = level.admin_terminal
	var key: String = level.data.key
	check(not _game().case_info("token").get("open", false), "no case yet: nothing's been asked of B2")
	var res := _req(admin, "GET /lights\nX-Api-Key: " + key)
	check(res.status == 401 and level.tips_sent.has("key_not_token") and not level.token_puzzle.solved, "the key on its own: 401, and SYSOP says B2 takes tokens")
	check(_game().case_info("token").get("open", false), "the first 401 opens the token case")
	res = _req(admin, _bearer("GET /lights", level.data.example_token))
	check(res.status == 401 and level.tips_sent.has("example_token"), "the runbook's example token ran out long ago: 401, and SYSOP says whose it was")
	res = _req(admin, "POST /auth/token {\"key\": \"%s\"}" % key)
	var tok: String = res.body.get("token", "")
	check(res.status == 201 and level.api.token_state(tok) == "ok" and not level.token_puzzle.solved, "the key trades for a token (not the case yet: nothing's been read with it)")
	res = _req(admin, "GET /lights\nAuthorization: " + tok)
	check(res.status == 401 and level.tips_sent.has("bearer"), "the token without the word Bearer: 401, and how it's written")
	var bench_tok := _token(level.bench_terminal, key)
	res = _req(admin, _bearer("GET /lights", bench_tok))
	check(res.status == 401 and level.tips_sent.has("other_service"), "the bench's token on the floor: 401, each service gives out its own")
	check(not level.token_puzzle.solved, "nothing yet")
	res = _req(admin, _bearer("GET /lights", tok))
	check(res.status == 200 and res.body.zones.size() == 7 and level.token_puzzle.solved and _game().case_info("token").solved, "GET /lights with the token: the six zones and the emergency circuit, and the case closes")
	check(_game().case_info("restore").get("open", false), "then the bench's case opens: one case at a time")
	await _frames(2)
	level._expire(false, tok)
	res = _req(admin, _bearer("GET /lights", tok))
	check(res.status == 401 and res.body.get("expired", false) and level.tips_sent.has("expired"), "once it's run out: 401 expired, and SYSOP says get a fresh one")
	# The last hint does it: its first line, then a GET with what it answered.
	var hint: String = level.token_puzzle.hints[-1]
	check(hint.contains("POST /auth/token {\"key\": \"%s\"}" % key) and hint.contains("Authorization: Bearer"), "the last hint says exactly what to type")
	check(level.token_puzzle.hints[0].contains("enter_key") and not level.token_puzzle.hints[0].contains(key), "hint 1 leaves the key as enter_key")


func _services(level: Node) -> void:
	var admin: Terminal = level.admin_terminal
	var tok := _token(admin, level.data.key)
	var res := _req(admin, _bearer("GET /lifts", tok))
	check(res.status == 200 and res.body.lifts.size() == 3, "GET /lifts: two cars and the freight lift")
	var car: Dictionary = level.data.lifts.filter(func(l): return l.kind == "passenger")[0]
	res = _req(admin, _bearer("POST /lifts/%s/restart" % car.id, tok, "{}"))
	check(res.status == 423 and level.tips_sent.has("lifts_held"), "a car won't restart while WARDEN holds the lights: 423 Locked")
	res = _req(admin, _bearer("POST /lifts/LIFT-F/restart", tok, "{}"))
	check(res.status == 409 and str(res.body.error).contains("Tue 10/14"), "the freight lift's out of service since Tuesday, as its sign says")
	check(_req(admin, _bearer("POST /lifts/LIFT-9/restart", tok, "{}")).status == 404, "a lift that doesn't come down here: 404")
	var em: String = level.data.emergency.id
	res = _req(admin, _bearer("PATCH /lights/" + em, tok, "{\"on\": true}"))
	check(res.status == 403 and level.tips_sent.has("em"), "the emergency circuit is life safety: 403, not ours")
	var z: String = level.data.first_cut[0]
	res = _req(admin, _bearer("PATCH /lights/" + z, tok, "{\"on\": true}"))
	check(res.status == 200 and res.body.on and level.zone_on(z) and level.lights[z][0].visible, "PATCH a zone on by hand: lit in the table and in the ring")
	_req(admin, _bearer("PATCH /lights/" + z, tok, "{\"on\": false}"))
	check(not level.zone_on(z) and not level.lights[z][0].visible, "and off again")
	check(_req(admin, _bearer("PATCH /lights/" + z, tok, "{\"on\": \"yes\"}")).status == 400, "on takes true or false")


func _case_restore(level: Node) -> void:
	var bench: Terminal = level.bench_terminal
	var key: String = level.data.key
	var zone: String = level.data.zones[0].id
	var floor_before: Array = level.data.zones.map(func(zz): return level.zone_on(zz.id))
	# The printout as it is: no return. The zone lights, the test fails on undefined.
	var printout := "\n".join(PackedStringArray(level._printout().map(func(l): return str(l.text) if l is Dictionary else str(l)).slice(0, 15))).replace("<the key>", key)
	var rt := _run(level, bench, printout)
	await _done(rt)
	check(rt.state == ScriptRuntime.State.FAILED and str(rt.error.message).contains("undefined"), "the admin's printout: the function never returns, so the test fails on undefined (%s)" % rt.error)
	check(level.bench_on[zone] and level.tips_sent.has("no_return") and not level.restore_puzzle.solved, "it did light the bench's zone; SYSOP: hand the answer back with return")
	check(bench.transcript.any(func(l): return l.contains("BENCH: 1 of 6 zones lit")), "the bench prints how it went")
	# No assert: it lights, but nothing checked it.
	rt = _run(level, bench, level._restore_fn(key) + "\nawait restore(\"%s\");" % zone)
	await _done(rt)
	check(rt.state == ScriptRuntime.State.DONE and level.bench_lit() == 1 and level.bench_passes == 0 and level.tips_sent.has("no_assert") and not level.restore_puzzle.solved, "no assert: the zone lights, but no test passed, so it doesn't count")
	# No zone in the call: zone is undefined, /lights/undefined is 404, the test fails.
	rt = _run(level, bench, level._restore_fn(key) + "\nlet answer = await restore();\nassert(answer.body.on, \"lit\");")
	await _done(rt)
	check(rt.state == ScriptRuntime.State.FAILED and level.tips_sent.has("no_zone") and level.bench_lit() == 0, "restore() with nothing in the brackets: zone is undefined, nothing lights, SYSOP says so")
	# No async: await inside a plain function doesn't compile.
	var plain := ScriptRuntime.for_language("javascript")
	var c := plain.compile(level._one_script(key, zone).replace("async function", "function"))
	check(not c.ok and str(c.error.message).contains("async"), "no async: the runner says await only works inside an async function")
	# Every run starts with the mock dark.
	check(not level.restore_puzzle.solved, "nothing's passed yet")
	# The last hint: one zone, returned and asserted.
	var code: String = level.restore_puzzle.hints[-1].get_slice("[color=#ffffff]", 1).get_slice("[/color]", 0)
	var said := []
	rt = _run(level, bench, code)
	rt.printed.connect(func(text, kind): said.append([text, kind]))
	await _done(rt)
	check(rt.state == ScriptRuntime.State.DONE and said.has(["PASS  %s is lit" % zone, "pass"]), "the last hint's script: the bench logs PASS for its assert (%s)" % [said])
	check(level.restore_puzzle.solved and _game().case_info("restore").solved and level.bench_passes == 1 and level.bench_lit() == 1, "one zone lit and tested: the case closes")
	check(_game().case_info("zones").get("open", false), "then every zone's case opens")
	check(level.data.zones.map(func(zz): return level.zone_on(zz.id)) == floor_before, "nothing on the bench touched the building's lights")
	check(level.restore_puzzle.hints[0].contains("enter_zone") and level.restore_puzzle.hints[0].contains("return") and level.restore_puzzle.hints[0].contains("assert"), "hint 1: the shape, with a line for each new word")


func _case_zones(level: Node) -> void:
	var bench: Terminal = level.bench_terminal
	var key: String = level.data.key
	var ids: Array = level.data.zones.map(func(z): return z.id)
	# A list missing a zone: five lit and tested, the bench names the sixth.
	var rt := _run(level, bench, level._every_script(key, ids.slice(0, 5)))
	await _done(rt)
	check(rt.state == ScriptRuntime.State.DONE and level.bench_lit() == 5 and level.bench_passes == 5 and not level.zones_puzzle.solved, "a list one zone short: five lit, not done")
	check(bench.transcript.any(func(l): return l.contains("still dark") and l.contains(ids[5])), "the bench names the zone still dark")
	# The service's whole list, emergency circuit and all: 403 on it, and its test fails.
	var all: String = level._restore_fn(key) + "\nlet all = await api.get(\"/lights\", auth);\nfor (const z of all.body.zones) {\n  let answer = await restore(z.id);\n  assert(answer.body.on, z.id + \" is lit\");\n}"
	rt = _run(level, bench, all)
	await _done(rt)
	check(rt.state == ScriptRuntime.State.FAILED and level._bench_em and not level.zones_puzzle.solved, "the emergency circuit in the list: 403, its test fails, not done")
	check(bench.transcript.any(func(l): return l.contains("emergency circuit refused")), "the bench says leave it out")
	check(level.bench_lit() < 6 or not level.zones_puzzle.solved, "nothing passes on a failed run")
	# The last hint: every zone from a list, each asserted.
	var code: String = level.zones_puzzle.hints[-1].get_slice("[color=#ffffff]", 1).get_slice("[/color]", 0)
	rt = _run(level, bench, code)
	await _done(rt)
	check(rt.state == ScriptRuntime.State.DONE and level.bench_lit() == 6 and level.bench_passes == 6, "the last hint's script lights all six on the bench, six tests passed")
	check(level.zones_puzzle.solved and _game().case_info("zones").solved and level.fight_stage == 1 and not _game().case_info("lights_out").is_empty()
		and _game().current_todo() == level.TEXT.case_lights_do, "every zone, tested: the case closes, and the fight opens: run it on the real floor")
	check(level._bench_readout.text.contains("6 / 6") and level._bench_lamps[ids[0]].material_override == Greybox.mat(level.LAMP_ON, 2.0), "the mock panel shows every lamp lit")
	rt = _run(level, bench, "console.log(\"again\");")
	await _done(rt)
	check(level.bench_lit() == 0 and level.bench_passes == 0, "the next run starts with the mock dark again")


## The script tested on the bench works on the floor: the same paths and zone ids.
func _on_the_floor(level: Node) -> void:
	var deck: Terminal = level.decks[0]
	# WARDEN's answer to the plan: every token the crew held is revoked.
	var old: String = level.api.tokens().filter(func(tk): return level.api.token_state(tk) == "revoked")[0]
	var res := _req(deck, _bearer("GET /lights", old))
	check(res.status == 401 and str(res.body.error).begins_with("That token was revoked") and _deck_said(deck, level.TEXT.tip_revoked), "WARDEN revoked the crew's tokens: an old one is 401 revoked, and SYSOP says get a fresh one")
	check(level.watcher.active and level.fight_stage == 1, "the Watcher's loose")
	res = _req(deck, _bearer("GET /auth/log", _token(deck, level.data.key)))
	check(res.status == 200 and not res.body.entries.any(func(e): return e.holder == "WARDEN"), "the auth log doesn't list WARDEN yet: he works through security control")
	check(_req(deck, _bearer("POST /auth/revoke", _token(deck, level.data.key), "{\"token\": \"%s\"}" % level.data.warden_token)).status == 404, "so his token can't be revoked yet")
	var code: String = level.zones_puzzle.hints[-1].get_slice("[color=#ffffff]", 1).get_slice("[/color]", 0)
	var rt := _run(level, deck, code)
	await _done(rt)
	check(rt.state == ScriptRuntime.State.DONE and level.data.zones.all(func(z): return level.zone_on(z.id)) and level.cut_zones.is_empty(), "the bench's script, run from a deck on the floor, lights every zone WARDEN cut")
	check(level.bench_lit() == 0, "and the bench's mock is untouched")
	check(level.fight_stage == 2 and _game().case_info("lights_out").solved and not _game().case_info("warden").is_empty() and level.gas["B2-MOTOR"] == "armed",
		"the whole ring lit at once: he fights back (the next case), and arms the motor room's gas")
	res = _req(deck, _bearer("GET /auth/log", _token(deck, level.data.key)))
	check(res.status == 200 and res.body.entries.filter(func(e): return e.holder == "WARDEN" and e.state == "ok").size() == 1, "now his token is in the auth log")
