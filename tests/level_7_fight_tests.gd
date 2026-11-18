extends RefCounted
## B2's fight and its end (Level 7, cases 4 and 5; Augustine's calls 2026-11-06): the
## three routes that beat WARDEN, each with its stage-2 step and its last stand, and
## the tempting wrong ones (the controller before the uplink's pulled, his token
## before he's logged in, a watchdog that never waits, one that never asserts); his
## beat stretching as stages fall; the hunters (a Watcher every run, held by the
## light; the Custodian and Rourke only if loose); Ines and Tomas sheltering, locked
## in, saved or lost to the gas, and the achievement each ending earns; the lifts
## (423 before, the freight lift's 409, each car in service), the ride up to 18 and
## the book in the car; his 4.0 rule rows naming the crew. Run in the floor_b2 group.

var t: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("B2: the fight")
	test_scripts_compile()
	await test_hunters()
	await test_lockout()
	await test_revoke()
	await test_watchdog()


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


func _hint_code(hint: String, n := 0) -> String:
	return hint.split("[color=#ffffff]")[n + 1].get_slice("[/color]", 0)


func _said(term: Node, text: String) -> bool:
	return term.transcript.any(func(l): return str(l).contains(text.left(30)))


## A fresh B2 with quick clocks, taken straight to the fight's second stage: the
## bench's three cases passed, and the whole ring lit once.
func _to_stage2(seed_value: int, rourke_fate := "unknown", custodian_sealed := false) -> Node:
	_game().new_run(seed_value)
	_game().rourke_fate = rourke_fate
	_game().custodian_sealed = custodian_sealed
	var level: Node = load("res://scenes/level_7.tscn").instantiate()
	level.first_cut_after = 999.0
	level.cut_every = 0.4
	level.failover_after = 0.3
	level.mint_after = 0.3
	level.lift_start = 0.2
	level.car_after = 0.2
	level.ride_time = 0.5
	level.gas_seconds = {"B2-MOTOR": 60.0, "B2-UPS": 60.0}
	t.root.add_child(level)
	await _frames(3)
	for id in ["token", "restore", "zones"]:
		level._on_solved(id)
	for z in level.data.zones:
		level._set_zone(z.id, true)
	await _frames(2)
	return level


func _free(level: Node) -> void:
	for term in [level.admin_terminal] + level.decks:
		if term.has_meta("script_runtime"):
			term.get_meta("script_runtime").stop()
	level.queue_free()
	await _frames(2)


func test_scripts_compile() -> void:
	var l7: Script = load("res://scripts/levels/level_7.gd")
	var ok := true
	for s in range(1, 41):
		var d := Level7Data.build(s)
		var ids: Array = d.zones.map(func(z): return z.id)
		var cars: Array = d.lifts.filter(func(l): return l.kind == "passenger").map(func(l): return l.id)
		for code in [l7._watchdog_script(d.key, ids), l7._revoke_script(d.key), l7._lifts_script(d.key, cars)]:
			ok = ok and ScriptRuntime.for_language("javascript").compile(code).ok
		ok = ok and d.auth_log.filter(func(e): return e.holder == "WARDEN").size() == 1 and d.auth_log.size() >= 23
		ok = ok and d.warden_minted.size() >= 4 and d.held_zone != d.zones[0].id and ids.has(d.held_zone) and not d.first_cut.has(d.zones[0].id)
		ok = ok and cars.has(d.car)
	check(ok, "the fight's hint scripts (watchdog, revoke, lifts) compile for every seed; his token is one line of a long log; the held zone and the first cut are never the closet's")


## Who's in the dark: a Watcher every run, held still wherever it's lit; the Custodian
## only if floor 10 left it unsealed, Rourke only if 22 didn't kill him.
func test_hunters() -> void:
	print("B2: the hunters")
	var level := await _to_stage2(711, "killed", true)
	check(level.watcher != null and level.rourke == null and level.custodian == null, "a Watcher every run; no Custodian once sealed on 10, no Rourke once killed on 22")
	var zone_box: AABB = level.ZONE_BOXES[3]
	level.watcher.global_position = level.to_global(zone_box.get_center() * Vector3(1, 0, 1))
	level._set_zone(level.data.zones[3].id, true)
	check(level._held_by_light(level.watcher), "in a lit zone the Watcher can't move")
	level._set_zone(level.data.zones[3].id, false)
	check(not level._held_by_light(level.watcher), "in the dark it can")
	level.watcher.global_position = level.to_global(Vector3(0, 0, -1))
	check(level._held_by_light(level.watcher), "and the lobby is always lit")
	await _free(level)
	level = await _to_stage2(712, "tied", false)
	check(level.rourke != null and level.custodian != null and not level.rourke.visible, "left loose, the Custodian and Rourke are on B2 too, Rourke out of sight until he comes down")
	await _until(func(): return level.rourke.visible, 400)
	check(level.rourke.visible and level.rourke.state == Rourke.State.CHASE and level.rourke.get_node("Torch") is SpotLight3D and level.said.has("l7_rourke_arrive"),
		"once WARDEN fights back, Rourke comes down STAIR 2 with a torch, hunting, and says why")
	check(level.custodian.is_active(), "and the Custodian is out of its bay")
	level._rourke_resolved("killed")
	check(_game().rourke_fate == "killed", "whatever the crew does with him here is his fate from now on")
	await _free(level)


## Lockout: the closet opens in the dark; the controller won't move while his uplink
## is in; pull it, he fails over to the backup; move the ring to local and he's beaten.
## Ines saved, Tomas lost: the achievement for her alone.
func test_lockout() -> void:
	print("B2: lockout")
	var level := await _to_stage2(721)
	var deck: Terminal = level.decks[0]
	var key: String = level.data.key
	check(level.fight_stage == 2 and not level.closet_open, "the ring lit: he fights back, the closet still shut")
	await _until(func(): return level.closet_open, 300)
	check(level.closet_open and not level.zone_on(level.data.zones[0].id) and level.db.run_silent("SELECT locked FROM doors WHERE id = 'B2-NETCL'")[0].locked == 0,
		"his first cut takes the closet's zone, and its maglock fails open in the dark")
	var res := _req(deck, _bearer("PATCH /controller", _token(deck, key), "{\"source\": \"local\"}"))
	check(res.status == 409 and _said(deck, level.TEXT.tip_controller), "the controller won't go local while his uplink's in: 409, and SYSOP says where it's patched")
	# The night-shifters are in their rooms by now; Ines's gas is counting.
	level._trap("ines")
	level._trap("tomas")
	check(level.shift_state.ines == "trapped" and level.shift_state.tomas == "trapped" and level.said.has("l7_trap_pa"), "WARDEN locks Ines and Tomas in the plant rooms")
	res = _req(deck, _bearer("POST /suppression/B2-UPS/abort", _token(deck, key), "{}"))
	check(res.status == 409, "nothing to abort in the battery room yet")
	res = _req(deck, _bearer("POST /suppression/B2-MOTOR/abort", _token(deck, key), "{}"))
	check(res.status == 200 and level.gas["B2-MOTOR"] == "aborted" and level.shift_state.ines == "trapped", "the motor room's gas aborted: Ines is safe, still locked in")
	var before: float = level.cut_interval()
	level.uplink.interact(null)
	await _frames(2)
	check(level.uplink_pulled and level.controller_source == "none" and level.route_done.lockout == 1 and level.fight_stage == 3, "pull the uplink: the ring stops taking his orders, and it's the last stand")
	check(level.cut_interval() > before and level.gas["B2-UPS"] == "armed", "every stage done stretches his beat; and he arms the battery room's gas")
	await _until(func(): return level.controller_source == "uplink-b", 120)
	check(level.controller_source == "uplink-b" and level.warden_can_cut(), "he fails over to the backup uplink, and cuts again")
	res = _req(deck, _bearer("PATCH /controller", _token(deck, key), "{\"source\": \"uplink\"}"))
	check(res.status == 400 and level.fight_stage == 3, "only local: 400")
	level._discharge("B2-UPS")
	check(level.shift_state.tomas == "dead" and level.staffers.tomas.state == "dead", "nobody aborted the battery room: Tomas is gone")
	res = _req(deck, _bearer("PATCH /controller", _token(deck, key), "{\"source\": \"local\"}"))
	await _frames(2)
	check(res.status == 200 and level.fight_stage == 4 and _game().warden_route == "lockout" and level.ring_lit() and not level.warden_holds and not level.watcher.active,
		"the ring on local control beats him: every light on, the lift controller free, the Watcher still")
	var rules: Array = level.db.run_silent("SELECT rule FROM warden_protocols WHERE version = '4.0' ORDER BY rule_no").map(func(r): return str(r.rule))
	check(rules.size() >= 3 and rules[0].contains("choosing") and rules.size() >= 3 and rules[-1] == level.RULES_4.lockout,
		"his 4.0 rows: rule 51, the crew by name, and the route that beat him (%s)" % [rules])
	check(level.shift_state.ines == "out" and _game().case_info("warden").solved and not _game().case_info("lifts").is_empty(), "Ines comes out; the lifts are next")
	await _lifts(level, deck, "achievement:b2_ines_only")
	await _free(level)


## The lifts: the freight lift's 409, each car restarted and in service, the car
## comes, the ride, the book, 18, and the night shift's achievement.
func _lifts(level: Node, deck: Terminal, achievement: String) -> void:
	var key: String = level.data.key
	var tok := _token(deck, key)
	var res := _req(deck, _bearer("POST /lifts/LIFT-F/restart", tok, "{}"))
	check(res.status == 409, "the freight lift still won't: out of service, as its sign says")
	var code := _hint_code(level.lifts_puzzle.hints[-1])
	var rt := _run(level, deck, code)
	await _until(func(): return not rt.is_running(), 900)
	check(rt.state == ScriptRuntime.State.DONE and _game().case_info("lifts").solved, "the last hint's script restarts both cars and checks each one's in service")
	await _until(func(): return level.car_here, 120)
	check(level.car_here and level.car_door.is_open, "the car comes down, and opens on the lobby")
	level._ride()
	await _until(func(): return level.arrived_18, 200)
	check(level.arrived_18 and level.car_rear.is_open and not level.car_door.is_open and level._car_floor.text == "18" and level.hello_book.enabled, "the ride up: B2 to 18, the back doors open, and a book behind the handrail")
	level._book_taken(1)
	check(level.book_found and not level.hello_book.visible, "Hello HTML! picked up")
	t.root.get_node("/root/Net").profile = Profile.new()  # a fresh save: only this ending's rewards
	check(level.night_shift_achievement() == achievement, "the night shift's ending earns %s" % achievement)
	for c in level.completed.get_connections():
		level.completed.disconnect(c.callable)
	await level._act2_end()
	check(_game().completed_level == "level_7" and _game().night_shift_alive == level.NIGHT_SHIFT.keys().filter(func(k): return level.shift_state[k] != "dead"), "End of Act 2: the level's done, and the game remembers who lived")
	_check_rewards(achievement)


## Each ending's rewards, on the profile of every machine present (Augustine, 2026-11-06):
## a survivor alone gives their own terminal theme; both alive gives the combined
## theme and one for every other tool slot, never the two individual themes.
func _check_rewards(achievement: String) -> void:
	var prof: Profile = t.root.get_node("/root/Net").profile
	var own := {"achievement:b2_ines_only": ["terminal/microfiche"], "achievement:b2_tomas_only": ["terminal/greenbar"],
		"achievement:b2_both_lost": ["notebook/haunted_past"],
		"achievement:b2_both_saved": ["terminal/night_shift", "flashlight/night_shift", "walkie/night_shift", "notebook/ledger", "sticker/records_tab", "clip/pay_stub"]}
	var every: Array = []
	for k in own:
		every.append_array(own[k])
	check(prof.earned.has(achievement) and every.all(func(key): return prof.has_item(key) == (key in own[achievement])),
		"%s unlocks its own items and no others (%s)" % [achievement, every.filter(func(key): return prof.has_item(key))])
	if achievement == "achievement:b2_both_saved":
		check(Cosmetics.TOOL_SLOTS.all(func(slot): return own[achievement].any(func(key): return key.begins_with(slot + "/"))),
			"both alive: a theme for every tool slot")
		check(not prof.has_item("terminal/microfiche") and not prof.has_item("terminal/greenbar"),
			"but not Ines's or Tomas's own: play it again for those")


## Revoke: his token in the auth log, revoked; he mints more; the last hint's loop
## revokes every one. Both night-shifters lost: "Remember those left behind".
func test_revoke() -> void:
	print("B2: revoke")
	var level := await _to_stage2(731)
	var deck: Terminal = level.decks[1]
	var res := _req(deck, _bearer("GET /auth/log", _token(deck, level.data.key)))
	var his: Array = res.body.entries.filter(func(e): return e.holder == "WARDEN")
	check(his.size() == 1 and his[0].token == level.data.warden_token and res.body.entries.size() > 20, "the auth log is long, and one line of it is his")
	var code := _hint_code(level.warden_puzzle.hints[-1], 0)
	var rt := _run(level, deck, code)
	await _until(func(): return level.route_done.revoke >= 1, 300)
	check(level.route_done.revoke == 1 and level.api.token_state(level.data.warden_token) == "revoked" and not level.warden_can_cut(), "the loop revokes his token: he can't switch a thing")
	await _until(func(): return level.minted, 120)
	check(level.minted and level.warden_can_cut(), "then he mints more off a backup key, and cuts again")
	await _until(func(): return level.fight_stage == 4, 600)
	rt.stop()
	check(level.fight_stage == 4 and _game().warden_route == "revoke" and level.data.warden_minted.all(func(tk): return level.api.token_state(tk) == "revoked"),
		"the same loop finds every token he minted and revokes them: beaten (%s)" % _game().warden_route)
	for room in ["B2-MOTOR", "B2-UPS"]:
		level.gas[room] = "armed"
		level._discharge(room)
	check(level.night_shift_achievement() == "achievement:b2_both_lost", "both rooms discharged: Remember those left behind")
	await _lifts(level, deck, "achievement:b2_both_lost")
	await _free(level)


## Watchdog: a loop that never waits fails, and SYSOP says why; the last hint's
## watchdog relights his cuts; he holds a zone; its assert catches it, and the fault
## beats him. Both night-shifters saved.
func test_watchdog() -> void:
	print("B2: watchdog")
	var level := await _to_stage2(741)
	var deck: Terminal = level.decks[2]
	var ids: Array = level.data.zones.map(func(z): return z.id)
	var busy := "let x = 0;\nwhile (true) {\n  x = x + 1;\n}"
	var rt := _run(level, deck, busy)
	await _until(func(): return not rt.is_running(), 300)
	check(rt.state == ScriptRuntime.State.FAILED and _said(deck, level.TEXT.tip_no_sleep) and level.route_done.watchdog == 0, "a loop that never waits fails, and SYSOP says put a sleep in it")
	# Without an assert it relights his cuts, and never notices the zone he holds.
	var quiet: String = level._watchdog_script(level.data.key, ids).replace("    assert(answer.body.on, zone + \" is lit\");\n", "")
	rt = _run(level, deck, quiet)
	await _until(func(): return level.route_done.watchdog >= 1, 900)
	check(level.route_done.watchdog == 1 and level.held_zone == level.data.held_zone and level.fight_stage == 3, "a watchdog relights what he cuts; then he holds one zone dark")
	await _frames(120)
	check(rt.is_running() and level.fight_stage == 3 and not level.zone_on(level.held_zone), "with no assert, the watchdog runs on and never sees the zone he's holding")
	rt.stop()
	await _frames(2)
	rt = _run(level, deck, _hint_code(level.warden_puzzle.hints[-1], 1))
	await _until(func(): return level.fight_stage == 4, 300)
	check(level.fight_stage == 4 and _game().warden_route == "watchdog" and level.ring_lit(), "the last hint's watchdog asserts every zone: the held one fails its check, the fault beats him")
	for room in ["B2-MOTOR", "B2-UPS"]:
		level._abort_gas(room, {"body": {}})
	check(level.night_shift_achievement() == "achievement:b2_both_saved", "both rooms aborted: nobody left behind")
	await _lifts(level, deck, "achievement:b2_both_saved")
	await _free(level)
