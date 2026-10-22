extends RefCounted
## Floor 9, the Personnel Wing (Level 5): its data across seeds, the HR service's key
## (401, 403), the panel's PATCH under its night limit (409), the work order's POST
## (400, 201) and its read-back, the voice on the radio against the badge log, the
## escort passes (401 for a Mimic's badge, 409 off site), the night lockup, the
## Mimics, the hand reset, the propped door, the Custodian up the dock stairs, the
## book's chapters, co-op, and the handoff from floor 10. Run in the floor_9 group.

var t: SceneTree
var _check: Callable
## On the stairwell landing by 9's east-wall door (Level 5 local).
const LANDING_BOX := AABB(Vector3(3.6, -0.5, 4.0), Vector3(3.4, 2.5, 4.0))


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("Floor 9: the Personnel Wing")
	test_data_every_seed()
	await test_scene()
	await test_floor_hazards()
	await test_book_huddles()
	await test_coop()
	await test_world()


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


func _doc(level: Node, title_part: String) -> Node:
	for d in level.find_children("*", "Document", true, false):
		if d.title.contains(title_part):
			return d
	return null


func _said(term: Terminal, line: String) -> bool:
	return Array(term.transcript).any(func(l): return TerminalUI._plain(l).contains(line))


## Every request a hint says to type (its white blocks).
func _hint_queries(h: String) -> Array:
	var out := []
	var at := h.find("[color=#ffffff]")
	while at >= 0:
		var from := at + "[color=#ffffff]".length()
		out.append(h.substr(from, h.find("[/color]", from) - from).strip_edges())
		at = h.find("[color=#ffffff]", from)
	return out


## The request the last hint says to type (the first white block in it).
func _last_hint_query(p: Puzzle) -> String:
	return _hint_queries(p.hints[-1])[0]


func _key(level: Node, req: String, body := "") -> String:
	var out := "%s\nX-Api-Key: %s" % [req, level.data.keys.hr]
	if body != "":
		out += "\n\n" + body
	return out


## A level script with its data, services and stations built for `run_seed`, outside
## the tree (no doors: those live in the building's tables).
func _stations(run_seed: int, players := 1) -> Node:
	var lvl = load("res://scripts/levels/level_5.gd").new()
	lvl.data = Level5Data.build(run_seed)
	for c in lvl.data.circuits:
		lvl.circuits[c[0]] = {"id": c[0], "circuit": c[1], "amps": int(c[2]), "on": bool(c[3]), "note": c[4]}
	lvl.swipes = lvl.data.swipes.duplicate(true)
	lvl.api = lvl._make_api()
	lvl._make_puzzles()
	lvl.seed_crew(players)
	return lvl


## A request through the level's services, and whether station `p` passes on it.
func _ask(lvl: Node, p: Puzzle, req: String) -> Dictionary:
	var res: Dictionary = lvl.api.request(req)
	res["passes"] = p.request_matches(req, res)
	return res


func test_data_every_seed() -> void:
	print("Floor 9: data and stations across seeds")
	var ok_shape := true
	var ok_key := true
	var ok_circuits := true
	var ok_decoys := true
	var ok_orders := true
	var ok_swipes := true
	var ok_escorts := true
	var ok_hints := true
	var ok_vale := true
	var hides := {}
	var keys := {}
	var badges := {}
	for s in range(1, 61):
		var lvl = _stations(s, 2)
		var data: Dictionary = lvl.data
		hides[data.night[0].hide.id] = true
		keys[data.keys.hr] = true
		badges[data.night[0].id] = true
		var ids := {}
		for st in data.staff:
			ids[st.id] = true
		ok_shape = ok_shape and data.staff.size() == 8 and ids.size() == 8 and data.keys.hr != data.keys.temp \
			and data.night[0].hide.id != data.night[1].hide.id and data.circuits.size() == 8 \
			and data.staff.any(func(st): return st.id == Level5Data.VALE.id and st.status == "deceased")
		# The key: no key, the temp's key and a wrong key are refused; the manager's answers.
		var r := _ask(lvl, lvl.key_puzzle, "GET /staff")
		ok_key = ok_key and r.status == 401 and not r.passes
		r = _ask(lvl, lvl.key_puzzle, "GET /staff\nX-Api-Key: %s" % data.keys.temp)
		ok_key = ok_key and r.status == 403 and not r.passes
		r = _ask(lvl, lvl.key_puzzle, "GET /staff\nX-Api-Key: 0000-0000")
		ok_key = ok_key and r.status == 401 and not r.passes
		r = _ask(lvl, lvl.key_puzzle, _key(lvl, "GET /staff"))
		ok_key = ok_key and r.status == 200 and r.passes and r.body.staff.size() == 8
		r = _ask(lvl, lvl.key_puzzle, _key(lvl, "GET /staff/%s" % data.example_key_id))
		ok_key = ok_key and r.status == 404 and not r.passes
		# The panel: the lights don't fit under the limit until the copiers go off; the
		# decoys say why; a wrong body is 400; the clipboard's example is another panel's.
		r = _ask(lvl, lvl.circuits_puzzle, _key(lvl, "PATCH /circuits/C9-01", "{\"on\": true}"))
		ok_circuits = ok_circuits and r.status == 409 and str(r.body.error).contains("Turn something off") and not r.passes
		r = _ask(lvl, lvl.circuits_puzzle, _key(lvl, "PATCH /circuits/C9-07", "{\"on\": true}"))
		ok_decoys = ok_decoys and r.status == 409 and str(r.body.error).contains("locked out") and not r.passes
		r = _ask(lvl, lvl.circuits_puzzle, _key(lvl, "PATCH /circuits/C9-06", "{\"on\": true}"))
		ok_decoys = ok_decoys and r.status == 409 and str(r.body.error).contains("work order") and not r.passes
		r = _ask(lvl, lvl.circuits_puzzle, _key(lvl, "PATCH /circuits/C14-03", "{\"on\": false}"))
		ok_decoys = ok_decoys and r.status == 404 and not r.passes
		r = _ask(lvl, lvl.circuits_puzzle, _key(lvl, "PATCH /circuits/C9-03", "{\"on\": \"false\"}"))
		ok_decoys = ok_decoys and r.status == 400 and not r.passes and lvl.circuits["C9-03"].on
		r = _ask(lvl, lvl.circuits_puzzle, "PATCH /circuits/C9-03\n\n{\"on\": false}")
		ok_decoys = ok_decoys and r.status == 401 and lvl.circuits["C9-03"].on
		r = _ask(lvl, lvl.circuits_puzzle, _key(lvl, "PATCH /circuits/C9-03", "{\"on\": false}"))
		ok_circuits = ok_circuits and r.status == 200 and not r.passes and not lvl.circuits["C9-03"].on
		r = _ask(lvl, lvl.circuits_puzzle, _key(lvl, "PATCH /circuits/C9-01", "{\"on\": true}"))
		ok_circuits = ok_circuits and r.status == 200 and not r.passes  # the cage lock is still off
		r = _ask(lvl, lvl.circuits_puzzle, _key(lvl, "PATCH /circuits/C9-04", "{\"on\": true}"))
		ok_circuits = ok_circuits and r.status == 200 and r.passes and lvl._power_ok() and lvl._load() <= data.limit
		r = _ask(lvl, lvl.check_circuits_puzzle, _key(lvl, "GET /circuits"))
		ok_circuits = ok_circuits and r.status == 200 and r.passes and r.body.load_amps == lvl._load()
		# The work order: a missing field, a quoted floor, the carbon copy's unit, then ours.
		r = _ask(lvl, lvl.air_puzzle, _key(lvl, "POST /work_orders", "{\"floor\": 9, \"unit\": \"%s\"}" % data.ahu))
		ok_orders = ok_orders and r.status == 400 and str(r.body.error).contains("fault") and not r.passes
		r = _ask(lvl, lvl.air_puzzle, _key(lvl, "POST /work_orders", "{\"floor\": \"9\", \"unit\": \"%s\", \"fault\": \"no air\"}" % data.ahu))
		ok_orders = ok_orders and r.status == 400 and not r.passes
		r = _ask(lvl, lvl.air_puzzle, _key(lvl, "POST /work_orders", "{\"floor\": %d, \"unit\": \"%s\", \"fault\": \"%s\"}" % [data.example_order.floor, data.example_order.unit, data.example_order.fault]))
		ok_orders = ok_orders and r.status == 201 and not r.passes and not lvl._air_ok()
		r = _ask(lvl, lvl.check_air_puzzle, _key(lvl, "GET /work_orders"))
		ok_orders = ok_orders and r.status == 200 and not r.passes
		r = _ask(lvl, lvl.air_puzzle, _key(lvl, "POST /work_orders", "{\"floor\": 9, \"unit\": \"%s\", \"fault\": \"no air\"}" % data.ahu.to_lower()))
		ok_orders = ok_orders and r.status == 201 and r.passes and lvl._air_ok() and r.body.id.begins_with("WO-9")
		r = _ask(lvl, lvl.check_air_puzzle, _key(lvl, "GET /work_orders/%s" % r.body.id))
		ok_orders = ok_orders and r.status == 200 and r.passes
		# The badge log: each night-shifter's last swipe is their hiding place; the crew's
		# badges were in Vale's lab; a badge never issued is 404.
		for n in data.night:
			r = lvl.api.request(_key(lvl, "GET /swipes/%s" % n.id))
			ok_swipes = ok_swipes and r.status == 200 and r.body.swipes[-1].reader == n.hide.reader and r.body.holder == n.name
		r = lvl.api.request(_key(lvl, "GET /swipes/VIS-01"))
		ok_swipes = ok_swipes and r.status == 200 and r.body.swipes.any(func(sw): return sw.reader == "LAB-B")
		r = lvl.api.request(_key(lvl, "GET /swipes/VIS-03"))
		ok_swipes = ok_swipes and r.status == 404
		r = lvl.api.request(_key(lvl, "GET /swipes/%s" % Level5Data.LOST[0].id))
		ok_swipes = ok_swipes and r.status == 200 and r.body.swipes.is_empty()
		# The radio's claim: once the voice has spoken, its badge read back exposes it.
		lvl.lures = 1
		lvl.lure_badge = "VIS-03"
		lvl._lure_hints()
		ok_swipes = ok_swipes and lvl.swipes_puzzle.request_matches("GET /swipes/VIS-03", {"status": 404, "body": {}}) \
			and lvl.swipes_puzzle.request_matches("GET /swipes", {"status": 200, "body": {}}) \
			and not lvl.swipes_puzzle.request_matches("GET /swipes/VIS-01", {"status": 200, "body": {}})
		# Escort passes: a Mimic's badge (lost, not returned) never answered a reader; the
		# day staff are off site; a made-up escort badge is 400; each real one, once.
		for l in Level5Data.LOST:
			r = _ask(lvl, lvl.passes_puzzle, _key(lvl, "POST /escorts", "{\"badge\": \"%s\", \"escort\": \"VIS-01\"}" % l.id))
			ok_escorts = ok_escorts and r.status == 401 and not r.passes
		r = _ask(lvl, lvl.passes_puzzle, _key(lvl, "POST /escorts", "{\"badge\": \"%s\", \"escort\": \"VIS-01\"}" % data.manager.id))
		ok_escorts = ok_escorts and r.status == 409 and str(r.body.error).contains("off site") and not r.passes
		r = _ask(lvl, lvl.passes_puzzle, _key(lvl, "POST /escorts", "{\"badge\": \"%s\", \"escort\": \"VIS-09\"}" % data.night[0].id))
		ok_escorts = ok_escorts and r.status == 400 and not r.passes
		r = _ask(lvl, lvl.passes_puzzle, _key(lvl, "POST /escorts", "{\"badge\": \"%s\"}" % data.night[0].id))
		ok_escorts = ok_escorts and r.status == 400 and not r.passes
		r = _ask(lvl, lvl.passes_puzzle, _key(lvl, "POST /escorts", "{\"badge\": \"ST-0000\", \"escort\": \"VIS-01\"}"))
		ok_escorts = ok_escorts and r.status == 404 and not r.passes
		r = _ask(lvl, lvl.passes_puzzle, _key(lvl, "POST /escorts", "{\"badge\": \"%s\", \"escort\": \"VIS-01\"}" % data.night[0].id))
		ok_escorts = ok_escorts and r.status == 201 and not r.passes and r.body["from"] == data.night[0].hide.reader
		r = _ask(lvl, lvl.passes_puzzle, _key(lvl, "POST /escorts", "{\"badge\": \"%s\", \"escort\": \"VIS-02\"}" % data.night[0].id))
		ok_escorts = ok_escorts and r.status == 409 and not r.passes
		r = _ask(lvl, lvl.passes_puzzle, _key(lvl, "POST /escorts", "{\"badge\": \"%s\", \"escort\": \"VIS-02\"}" % data.night[1].id.to_lower()))
		ok_escorts = ok_escorts and r.status == 201 and r.passes and lvl._passes_ok() and lvl.escorts.size() == 2
		# Vale's record, at either terminal: deceased, edited after.
		r = _ask(lvl, lvl.vale_puzzle, _key(lvl, "GET /staff/%s" % Level5Data.VALE.id))
		ok_vale = ok_vale and r.status == 200 and r.passes and r.body.status == "deceased" and r.body.edited_by == "EXEC-30" and r.body.last_edited > "10/14/97"
		ok_vale = ok_vale and not _ask(lvl, lvl.vale_puzzle, _key(lvl, "GET /staff/%s" % data.night[0].id)).passes \
			and not lvl.api.request(_key(lvl, "GET /staff/%s" % data.night[0].id)).body.has("last_edited")
		# Every last hint does what its station wants, on a fresh floor.
		var fresh = _stations(s, 1)
		ok_hints = ok_hints and _ask(fresh, fresh.key_puzzle, _last_hint_query(fresh.key_puzzle)).passes
		for q in _hint_queries(fresh.circuits_puzzle.hints[-1]):
			r = _ask(fresh, fresh.circuits_puzzle, q)
		ok_hints = ok_hints and r.passes and fresh.circuits_puzzle.state_ok()
		ok_hints = ok_hints and _ask(fresh, fresh.check_circuits_puzzle, _last_hint_query(fresh.check_circuits_puzzle)).passes
		ok_hints = ok_hints and _ask(fresh, fresh.air_puzzle, _last_hint_query(fresh.air_puzzle)).passes
		ok_hints = ok_hints and _ask(fresh, fresh.check_air_puzzle, _last_hint_query(fresh.check_air_puzzle)).passes
		for q in _hint_queries(fresh.passes_puzzle.hints[-1]):
			r = _ask(fresh, fresh.passes_puzzle, q)
		ok_hints = ok_hints and r.passes
		ok_hints = ok_hints and _ask(fresh, fresh.vale_puzzle, _last_hint_query(fresh.vale_puzzle)).passes
		fresh.lures = 1
		fresh.lure_badge = "VIS-02"
		fresh._lure_hints()
		ok_hints = ok_hints and _ask(fresh, fresh.swipes_puzzle, _last_hint_query(fresh.swipes_puzzle)).passes
		fresh.free()
		lvl.free()
	check(ok_shape, "eight staff records every run, one of them Vale's (deceased), two night-shifters hiding apart, eight circuits, two keys")
	check(hides.size() == 2 and keys.size() >= 50 and badges.size() >= 30, "who hides where, the HR key and the badge numbers change with the seed (%d hides, %d keys, %d badges over 60 runs)" % [hides.size(), keys.size(), badges.size()])
	check(ok_key, "no key is 401, the temp's key 403, a wrong key 401; the manager's key lists the staff and passes; the desk sheet's example record is 404")
	check(ok_circuits, "the lights don't fit under the night limit (409) until the copiers go off; lights and cage lock on together pass, and the panel read back shows it")
	check(ok_decoys, "the locked-out closet and the interlocked fans are 409 with a reason, the clipboard's example 404, a quoted switch 400, no key 401")
	check(ok_orders, "a missing field is 400 and names it, a quoted floor 400; the carbon copy's unit is 201 but not the air; this floor's unit is, and reads back")
	check(ok_swipes, "the log puts each night-shifter at their hiding place, the crew's badges in Vale's lab, a Mimic's badge nowhere, and an unissued badge is 404; the voice's badge read back exposes it")
	check(ok_escorts, "a Mimic's badge is 401, an off-site badge 409, a made-up escort 400, a missing field 400, an unknown badge 404; each real night-shifter passes once (409 twice)")
	check(ok_vale, "Vale's record says deceased, last edited the night after by EXEC-30; nobody else's carries an edit")
	check(ok_hints, "every station's last hint does what it wants, across 60 seeds")


func test_scene() -> void:
	print("Floor 9: the HR front, the panel, the radio, the passes and the lockup")
	_game().new_run(31)
	_game().custodian_sealed = true
	var level = load("res://scenes/level_5.tscn").instantiate()
	t.root.add_child(level)
	await _frames(30)
	_chapters_read([level])
	level.completed.disconnect(level._on_completed)
	var p: Player = level.player
	var data: Dictionary = level.data
	var net: Node = t.root.get_node("/root/Net")
	var had: Array = net.profile.earned.duplicate()
	check(LANDING_BOX.has_point(level.to_local(p.global_position)) and p.is_on_floor(), "players start on 9's stair landing (%s)" % level.to_local(p.global_position))
	check(level.stair_in.is_open and level.stair_out.locked and not level.stair_out.is_open, "the door in from STAIR 1 is open behind the crew; STAIR 2 down is held shut")
	check(level.custodian == null, "sealed on 10, the Custodian isn't on this floor")
	check(level.lights["L9-PAY"].all(func(l): return not l.visible) and level.lights["L9-HR"].all(func(l): return l.visible), "payroll is dark, the HR front is lit")
	check(level.db.run_silent("SELECT locked, actuator_fault FROM doors WHERE id = 'PERS-CAGE'")[0] == {"locked": 1, "actuator_fault": 1} and not level.cage_door.is_open, "the records cage is locked with no power to its lock")
	check(level.mimics.size() == 2 and level.staffers.size() == 2 and level.mimics.all(func(m): return m.visible and m.get_prompt(p).contains(m.face) and m.get_prompt(p).contains("Badge " + m.badge)),
		"two Mimics wear the night-shifters' faces, with somebody else's badge on the lanyard")
	for m in level.mimics:
		check(not level.staffers.values().any(func(st): return st.badge == m.badge) and Level5Data.LOST.any(func(l): return l.id == m.badge), "%s's lanyard carries a lost badge, not the badge the log has hiding" % m.face)
	check(_doc(level, "Personnel request sheet").plain_text().contains("GET /staff/%s" % data.example_key_id) and not _doc(level, "Personnel request sheet").plain_text().contains(data.keys.hr), "the desk sheet shows the header's shape with another floor's record, not the key")
	check(_doc(level, "Key sticky").plain_text().contains(data.keys.hr) and level.OFFICE.has_point(level.to_local(_doc(level, "Key sticky").global_position)), "the HR key is on a sticky in the manager's office")
	check(_doc(level, "Temp key card").plain_text().contains(data.keys.temp), "the temp's key is in the mail tray")
	check(_doc(level, "Facilities clipboard").plain_text().contains("C14-03") and _doc(level, "Facilities clipboard").plain_text().contains("%d A" % data.limit) and _doc(level, "Carbon copy").plain_text().contains(data.example_order.unit),
		"the clipboard shows another panel's PATCH and the limit; the carbon copy is another floor's order")
	check(level.hr.puzzles.map(func(pz): return pz.hints.size()) == [3, 2, 2, 2, 2, 2] and level.panel.puzzles.map(func(pz): return pz.hints.size()) == [3, 2, 3, 2],
		"the key, the panel and the work order have three-step ladders; the reviews two")
	var ui: TerminalUI = level.terminal_ui
	ui.terminal = level.hr
	check(level.hr.next_hint().contains("X-Api-Key: enter_key"), "the first hint is the request's shape with the key as enter_key")
	# The key station.
	_doc(level, "Personnel request sheet").open_reader(p).close()
	await _frames(3)
	check(_game().case_info("key").get("open", false) and _game().current_todo() == level.TEXT.todo_key, "reading the desk sheet opens the key case and sets the to-do")
	ui.run("GET /staff")
	await _frames(2)
	check(not level.key_puzzle.solved and _said(level.hr, level.TEXT.tip_header), "no key: 401, and SYSOP says where a key goes")
	ui.run("GET /staff\nX-Api-Key: %s" % data.keys.temp)
	await _frames(2)
	check(not level.key_puzzle.solved and _said(level.hr, level.TEXT.tip_temp), "the temp's key: 403, and SYSOP says whose key it is")
	ui.run("GET /staff\nX-Api-Key: 1234-abcd")
	await _frames(2)
	check(not level.key_puzzle.solved and _said(level.hr, level.TEXT.tip_wrong_key), "a wrong key: 401 again, and SYSOP says to copy it exactly")
	level.lure_delay = 0.3
	level.lure_again = 0.6
	ui.run(_last_hint_query(level.key_puzzle))
	await _frames(3)
	check(level.key_puzzle.solved and _game().case_info("key").get("solved", false) and _game().current_todo() == level.TEXT.todo_power, "the manager's key: the staff list, the key case solved, the to-do is the power")
	check(_game().case_info("vale").get("open", false), "Vale's row in the list opens her case")
	ui.run(_last_hint_query(level.vale_puzzle))
	await _frames(2)
	check(level.vale_puzzle.solved and _game().case_info("vale").how.contains("EXEC-30"), "her record read on its own: deceased, edited after, and the case says by whom")
	# The radio lies, in Maddison's voice (solo), claiming a badge that was never issued.
	check(await _until(func(): return level.lures == 1, 120) and level.lure_peer == 0 and level.lure_badge == "VIS-02", "once the service answers, a voice on the walkie asks for the loading door: solo, it's Maddison, with the next badge")
	check(not level.swipes_puzzle.solved and _game().current_todo() == level.TEXT.todo_radio and _said(level.hr, level.TEXT.tip_lure), "the radio station opens, the to-do asks who's really there, and SYSOP says a voice isn't a record")
	check(level.hud._subtitle.text.contains(VoiceLines.get_line("l5_mimic_maddison_lure").text), "the subtitle is Maddison's line")
	check(level.hr.next_hint().contains("GET /swipes/enter_badge") and level.hr.next_hint().contains("GET /swipes/VIS-02"), "the radio's ladder: the shape, then the voice's badge")
	ui.run(_last_hint_query(level.swipes_puzzle))
	await _frames(3)
	check(level.swipes_puzzle.solved and _game().case_info("radio").get("solved", false) and _game().case_info("radio").how.contains("VIS-02") and _game().current_todo() == level.TEXT.todo_power, "no such badge: the voice is exposed, the case says so, and the to-do goes back to the power")
	await _frames(40)
	check(level.lures == 1, "exposed, the voice doesn't ask again")
	ui.run(_key(level, "GET /swipes/VIS-01"))
	await _frames(2)
	check(_game().case_info("frame").get("solved", false) and net.profile.earned.has("achievement:framed"), "our own badge's log: swiped into Vale's lab while we were on 14. The frame, on the record")
	# The panel.
	ui.terminal = level.panel
	_doc(level, "Facilities clipboard").open_reader(p).close()
	await _frames(3)
	check(_game().case_info("power").get("open", false) and _game().case_info("air").get("open", false), "the clipboard opens the power and air cases")
	ui.run(_key(level, "PATCH /circuits/C9-01", "{\"on\": true}"))
	await _frames(2)
	check(not level.power_back and _said(level.panel, level.TEXT.tip_load) and not level.circuits["C9-01"].on, "the lights first: 409 over the limit, and SYSOP says something heavy has to go off")
	ui.run(_key(level, "PATCH /circuits/C14-03", "{\"on\": false}"))
	await _frames(2)
	check(_said(level.panel, level.TEXT.tip_example), "the clipboard's example: 404, and SYSOP says it's another panel's")
	ui.run(_key(level, "PATCH /circuits/C9-03", "{\"on\": false}"))
	await _frames(2)
	check(not level.circuits["C9-03"].on and not level.power_back, "the copiers off: not the power yet")
	ui.run(_key(level, "PATCH /circuits/C9-01", "{\"on\": true}"))
	await _frames(3)
	check(level.circuits["C9-01"].on and level.lights["L9-PAY"].all(func(l): return l.visible) and not level.power_back, "the lights come on in payroll; the cage lock is still dead")
	ui.run(_key(level, "PATCH /circuits/C9-04", "{\"on\": true}"))
	await _frames(3)
	check(level.power_back and level.circuits_puzzle.solved and _game().case_info("power").get("solved", false) and _game().current_todo() == level.TEXT.todo_air, "the cage lock back: the power case closes and the to-do is the air")
	check(level.db.run_silent("SELECT actuator_fault FROM doors WHERE id = 'PERS-CAGE'")[0]["actuator_fault"] == 0 and level.lights["L9-CAGE"].all(func(l): return l.visible), "the cage's lock has power and its light is on")
	ui.run(_key(level, "GET /circuits"))
	await _frames(2)
	check(level.check_circuits_puzzle.solved, "the panel read back signs it off")
	# The work order.
	ui.run(_key(level, "POST /work_orders", "{\"floor\": %d, \"unit\": \"%s\", \"fault\": \"%s\"}" % [data.example_order.floor, data.example_order.unit, data.example_order.fault]))
	await _frames(2)
	check(not level.air_on and _said(level.panel, level.TEXT.tip_unit), "the carbon copy's order goes in (201) for the wrong floor, and SYSOP says so")
	ui.run(_key(level, "POST /work_orders", "{\"floor\": 9, \"unit\": \"%s\", \"fault\": \"no air\"}" % data.ahu))
	await _frames(3)
	check(level.air_on and level.air_puzzle.solved and _said(level.panel, level.TEXT.tip_verify) and _game().current_todo() == "", "this floor's order: the air handler spins up, and SYSOP asks whether it did anything")
	ui.run(_key(level, "GET /work_orders"))
	await _frames(2)
	check(level.check_air_puzzle.solved and _game().case_info("air").get("solved", false), "read back, the air case closes")
	# The passes: a Mimic's badge, the manager's, then the real ones, each behind a door.
	ui.terminal = level.hr
	_doc(level, "Escort procedure").open_reader(p).close()
	await _frames(3)
	check(_game().case_info("people").get("open", false) and _game().current_todo() == level.TEXT.todo_people, "the procedure opens the people case and sets the to-do")
	ui.run(_key(level, "POST /escorts", "{\"badge\": \"%s\", \"escort\": \"VIS-01\"}" % level.mimics[0].badge))
	await _frames(2)
	check(level.escorts.is_empty() and _said(level.hr, level.TEXT.tip_mimic), "the badge on a Mimic's lanyard: 401, and SYSOP says a real badge swipes in somewhere")
	ui.run(_key(level, "POST /escorts", "{\"badge\": \"%s\", \"escort\": \"VIS-01\"}" % data.manager.id))
	await _frames(2)
	check(level.escorts.is_empty() and _said(level.hr, level.TEXT.tip_off_site), "the manager's badge: 409 off site")
	var first: Dictionary = data.night[0]
	var second: Dictionary = data.night[1]
	var st1: Staffer = level.staffers[first.id]
	var st2: Staffer = level.staffers[second.id]
	ui.run(_key(level, "POST /escorts", "{\"badge\": \"%s\", \"escort\": \"VIS-01\"}" % first.id))
	await _frames(3)
	check(level.passed.has(first.id) and st1.state == "hiding" and not level.passes_puzzle.solved, "%s's pass is logged; behind a locked door, they stay put" % first.first)
	ui.run(_key(level, "PATCH /doors/%s" % first.hide.door, "{\"locked\": false}"))
	await _frames(3)
	check(level.doors_opened.has(first.hide.door) and st1.state != "hiding" and level._door_unlocked(first.hide.door), "their door opened, they get up and head for the stairs")
	ui.run(_key(level, "PATCH /doors/%s" % second.hide.door, "{\"locked\": false}"))
	await _frames(3)
	check(level.doors_opened.has(second.hide.door) and st2.state == "hiding", "the other door open first: %s waits for a pass" % second.first)
	ui.run(_key(level, "POST /escorts", "{\"badge\": \"%s\", \"escort\": \"VIS-01\"}" % second.id))
	await _frames(3)
	check(level.passes_puzzle.solved and st2.state != "hiding" and not level.lockup_puzzle.solved and _said(level.hr, level.TEXT.tip_lockup), "both passed: the station passes, and SYSOP says every door opened is still open")
	check(await _until(func(): return st1.state == "waiting" and st2.state == "waiting", 1800), "both night-shifters reach the stairs and wait (%s, %s)" % [st1.state, st2.state])
	check(level.hr.next_hint().contains("PATCH /doors/enter_door"), "the lockup ladder: the shape")
	var fixes := _hint_queries(level.hr.next_hint())
	check(fixes.size() == 2 and fixes.all(func(q): return q.contains("\"locked\": true")), "then one PATCH per door still open (%d)" % fixes.size())
	ui.run(fixes[0])
	await _frames(3)
	check(not level.lockup_puzzle.solved and not level.released, "one door locked isn't the lockup")
	ui.run(fixes[1])
	await _frames(3)
	check(level.lockup_puzzle.solved and not level.check_lockup_puzzle.solved and not level.released and level.db.run_silent("SELECT 1 FROM doors WHERE zone = '9' AND locked = 0").is_empty(), "every door locked again: the lockup passes, the read-back is still owed")
	ui.run(_key(level, "GET /doors/%s" % first.hide.door))
	await _frames(2)
	check(not level.check_lockup_puzzle.solved and level.read_back.has(first.hide.door), "one door read back isn't every door, but it counts")
	ui.run(_key(level, "GET /doors/%s" % second.hide.door))
	await _frames(3)
	check(level.check_lockup_puzzle.solved and level.released and not level.stair_out.locked and _game().current_todo() == level.TEXT.todo_down and _game().case_info("people").get("solved", false), "the doors read back: STAIR 2 releases, the to-do says everyone down, and the people case names who was where")
	check(_game().case_info("people").how.contains(first.first) and _game().case_info("people").how.contains(first.hide.place), "the case page puts %s in %s" % [first.first, first.hide.place])
	# Down: the voice has one more thing to say, then the floor ends.
	var done := [false]
	level.completed.connect(func(): done[0] = true)
	p.global_transform = Transform3D(Basis(), level.to_global(level.STAIR_OUT_AT + Vector3(-2.4, 0.1, 0)))
	check(await _until(func(): return level.lures == 3, 300) and level.hud._subtitle.text == "MADDISON: " + VoiceLines.get_line("l5_mimic_maddison_last").text, "everyone on the stairs down: the voice on the walkie asks where you're going")
	check(await _until(func(): return done[0], 900) and _game().completed_level == "level_5" and net.profile.earned.has("achievement:floor_9"), "then the floor ends")
	net.profile.earned = had
	level.queue_free()
	await t.process_frame


## Floor 9's chapters count as read on these levels: the tests here are about the
## stations. The chapters opening at their papers is test_book_huddles.
func _chapters_read(levels: Array) -> void:
	for l in levels:
		for id in Books.book_chapter_ids("acceptable_apis"):
			l.get_node("Huddle").done[id] = true


## The Mimics (looked at, they leave; unseen, they turn up again), the air going bad
## and the stair door propped, the breaker reset by hand, the loading door opened for
## the voice, the shaft, and the Custodian up the dock stairs when it wasn't sealed.
func test_floor_hazards() -> void:
	print("Floor 9: the Mimics, the air, the hand reset, the dock and the Custodian")
	_game().new_run(12)
	_game().custodian_sealed = false
	var level = load("res://scenes/level_5.tscn").instantiate()
	t.root.add_child(level)
	await _frames(30)
	_chapters_read([level])
	level.completed.disconnect(level._on_completed)
	var p: Player = level.player
	var data: Dictionary = level.data
	var ui: TerminalUI = level.terminal_ui
	check(level.custodian != null and not level.custodian.is_active() and not level.custodian_here, "not sealed on 10, the Custodian is below the dock stairs, not here yet")
	# A Mimic, looked at from close: it walks off, out of sight, and turns up elsewhere.
	var m: Mimic = level.mimics[0]
	var seated: Mimic = level.mimics.filter(func(x): return x.state == "seated")[0]
	check(seated.dept == "Payroll" and level.PAYROLL.has_point(level.to_local(seated.global_position)), "the payroll clerk's face sits at their desk in payroll, back to the room")
	var standing: Mimic = level.mimics.filter(func(x): return x.state == "standing")[0]
	m = standing
	var from: Vector3 = m.global_position + (level.to_global(Vector3(-5, 0, -4)) - m.global_position).normalized() * 4.0
	p.global_transform = Transform3D(Basis(), from + Vector3(0, 0.1, 0)).looking_at(m.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	p.global_rotation = Vector3(0, p.global_rotation.y, 0)
	check(await _until(func(): return m.state != "standing", 300), "looked at from close, the Mimic walks away (state %s)" % m.state)
	await _frames(2)
	check(level.hud._notice.text.contains(level.TEXT.mimic_leaves), "and the notice says it walked off")
	check(await _until(func(): return m.state == "gone" and not m.visible, 1200), "out of sight, it's gone (state %s)" % m.state)
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(0, 0.1, 6)))
	m._wait = 0.05
	check(await _until(func(): return m.visible and m.state == "standing", 120), "with nobody near, it turns up again somewhere else, back turned")
	check(level.to_local(m.global_position).distance_to(Vector3(-9, 0, -7)) > 2.0, "not where it was")
	# The air: after the grace it hurts a little, each tick; the stair door propped clears it.
	var hp: float = p.health
	level._air_hurts()
	check(p.health < hp and p.health > 0.0, "the air off hurts a little (%.0f)" % p.health)
	level.prop_time = 0.3
	level.prop.used.emit(p)
	await _frames(3)
	check(level.propped and not level.prop.enabled, "the stair door is propped")
	check(await _until(func(): return level.air_cleared, 120), "and the floor's air clears, slowly")
	hp = p.health
	level._air_hurts()
	check(p.health == hp, "cleared, the air doesn't hurt")
	# The breaker cupboard, by hand: the main trips the copiers, the lights come on.
	level.hand_reset_time = 0.3
	level.cupboard.used.emit(p)
	check(await _until(func(): return level.hand_reset, 120) and level.circuits["C9-01"].on and not level.circuits["C9-03"].on and not level.power_back, "the hand reset: copiers off, lights on, the cage lock still wants the service")
	check(level.lights["L9-PAY"].all(func(l): return l.visible) and not level.cupboard.enabled, "payroll's lights are on")
	ui.terminal = level.hr
	ui.run(_last_hint_query(level.key_puzzle))
	await _frames(3)
	ui.terminal = level.panel
	ui.run(_key(level, "PATCH /circuits/C9-04", "{\"on\": true}"))
	await _frames(3)
	check(level.power_back and level.circuits_puzzle.solved, "the cage lock through the service: the power's back")
	# The loading door, opened for the voice: nobody there, and the Custodian comes up.
	ui.terminal = level.hr
	ui.run(_key(level, "PATCH /doors/PERS-DOCK", "{\"locked\": false}"))
	await _frames(5)
	check(level.dock_opened and level.doors_opened.has("PERS-DOCK") and level.dock_door.is_open, "the loading door opens on a black shaft")
	check(level.custodian_here and level.custodian.is_active() and (level.PAYROLL.has_point(level.to_local(level.custodian.global_position)) or level.DOCK.has_point(level.to_local(level.custodian.global_position))), "and the Custodian comes up the dock stairs onto the floor")
	# The shaft: step past the landing and you fall, and come to on the landing.
	hp = p.health
	p.global_transform = Transform3D(Basis(), level.to_global(level.SHAFT_AT + Vector3(0, 0.3, 0)))
	await _frames(3)
	check(p.health < hp and level.PAYROLL.has_point(level.to_local(p.global_position)) and p.global_position.y > -0.5, "the dock stairs are gone: a fall, and back on payroll's side of the door (%s)" % level.to_local(p.global_position))
	# The lockup counts the loading door too.
	for s in data.night:
		ui.run(_key(level, "PATCH /doors/%s" % s.hide.door, "{\"locked\": false}"))
		await _frames(2)
		ui.run(_key(level, "POST /escorts", "{\"badge\": \"%s\", \"escort\": \"VIS-01\"}" % s.id))
		await _frames(2)
	check(level.passes_puzzle.solved and _hint_queries(level.lockup_puzzle.hints[-1]).size() == 3, "both passed; the lockup's last hint lists three doors, the loading door among them")
	for q in _hint_queries(level.lockup_puzzle.hints[-1]):
		ui.run(q)
		await _frames(2)
	ui.run("SELECT * FROM doors")
	await _frames(3)
	check(level.lockup_puzzle.solved and level.check_lockup_puzzle.solved and level.released, "every door locked and the table read back with SELECT counts as the read-back: the stairs release")
	level.queue_free()
	await t.process_frame


## Acceptable API's: picked up off the training shelf, its chapters come up at their
## papers, on the spot. A paper read before the book waits for it. The Mimics stand
## still while the crew reads.
func test_book_huddles() -> void:
	print("Floor 9: the book's chapters")
	_game().new_run(7)
	_game().custodian_sealed = true
	var level = load("res://scenes/level_5.tscn").instantiate()
	t.root.add_child(level)
	await _frames(30)
	var p: Player = level.player
	var h: Node = t._huddle_of(level)
	var net: Node = t.root.get_node("/root/Net")
	var had: Array = net.profile.earned.duplicate()
	net.profile.earned.erase("achievement:acceptable_apis_pickup")
	_doc(level, "Facilities clipboard").report_open(p)
	await _frames(20)
	check(not h.is_busy() and level.pending_chapters == ["api_patch"] and _game().case_info("power").get("open", false), "the clipboard read before the book: its chapter waits, the case opens")
	check(level.book.enabled and level.book.visible and level.book.prompt.contains("Acceptable API's"), "the book is on the training shelf")
	level.book.used.emit(p)
	check(await _until(func(): return level.book_found, 30) and not level.book.visible and net.profile.earned.has("achievement:acceptable_apis_pickup"), "picked up: it's gone from the shelf, and the find is the player's")
	check(await t._huddle_opens(level, "api_patch"), "the waiting chapter, Changing one thing, opens on the spot")
	check(h.chapter.book == "ACCEPTABLE API'S" and level.mimics.all(func(m): return not m.is_physics_processing()), "from Acceptable API's; the Mimics stand still while the crew reads")
	await t._crew_reads([level])
	await t._until(func(): return not h.is_busy(), 10.0)
	check(h.done.has("api_patch") and level.mimics.all(func(m): return m.is_physics_processing()), "the chapter ends, and the Mimics move again")
	_doc(level, "Facilities clipboard").report_open(p)
	await _frames(20)
	check(not h.is_busy(), "read again, the clipboard doesn't bring the chapter back")
	_doc(level, "Personnel request sheet").report_open(p)
	check(await t._huddle_opens(level, "api_codes"), "the desk sheet brings up Read the number")
	await t._crew_reads([level])
	if not h.done.has("api_keys"):
		check(await t._huddle_opens(level, "api_keys"), "then A key with every request")
		await t._crew_reads([level])
	await t._until(func(): return not h.is_busy(), 10.0)
	check(h.done.has("api_codes") and h.done.has("api_keys") and _game().case_info("key").get("open", false), "both read (Read the number, then A key with every request), and the key case is open")
	_doc(level, "Carbon copy").report_open(p)
	check(await t._huddle_opens(level, "api_post"), "the carbon copy brings up Making something new")
	await t._crew_reads([level])
	await t._until(func(): return not h.is_busy(), 10.0)
	_doc(level, "Escort procedure").report_open(p)
	check(await t._huddle_opens(level, "api_check"), "the procedure brings up Ask again")
	await t._crew_reads([level])
	await t._until(func(): return not h.is_busy(), 10.0)
	check(Books.book_chapter_ids("acceptable_apis").all(func(id): return h.done.has(id)) and net.profile.earned.has("achievement:acceptable_apis_done"), "every chapter read: the book is done")
	net.profile.earned = had
	level.queue_free()
	await t.process_frame


## Host and client: a client's requests go through the services on the host, and the
## power, the radio (a teammate's voice, with their name), the passes and the lockup
## play out on every machine; the Mimics and the staffers mirror the host's.
func test_coop() -> void:
	print("Co-op: floor 9 with a host and a client")
	_game().new_run(5)
	_game().custodian_sealed = true
	var worlds: Array = await t._coop_worlds(1)
	var machines: Array = await t._coop_load(worlds, "res://scenes/level_5.tscn")
	_chapters_read(machines)
	var host = machines[0]
	var client = machines[1]
	check(machines.all(func(l): return l.sync._begun and l.players.count() == 2 and l.data.keys.hr == host.data.keys.hr and l.issued == ["VIS-01", "VIS-02"]), "both machines start floor 9 with the same key and two visitor badges")
	for l in machines:
		l.lure_delay = 0.3
		l.lure_again = 0.5
	var cui: TerminalUI = client.terminal_ui
	cui.terminal = client.hr
	cui.run("GET /staff")
	await _frames(10)
	check(machines.all(func(l): return not l.key_puzzle.solved and l.tips_sent.has("header")), "a client's keyless request is 401 on the host, and SYSOP's tip shows on both")
	cui.run(_last_hint_query(client.key_puzzle))
	await _frames(10)
	check(machines.all(func(l): return l.key_puzzle.solved), "a client's keyed request solves the key station everywhere")
	check(await _until(func(): return machines.all(func(l): return l.lures == 1), 120), "the radio lies on every machine")
	var peer: int = host.lure_peer
	check(peer > 0 and machines.all(func(l): return l.lure_peer == peer and l.lure_badge == host.lure_badge) and host.players.all_ids().has(peer), "in co-op the voice is a teammate's (%s), the same one everywhere" % host._name_of(peer))
	check(client.hud._subtitle.text == "%s: %s" % [client._name_of(peer), VoiceLines.get_line("l5_mimic_lure").text] and client._name_of(peer) == host._name_of(peer), "with their name on the subtitle (%s)" % client.hud._subtitle.text)
	cui.run(_key(client, "GET /swipes/%s" % client.lure_badge))
	await _frames(10)
	check(machines.all(func(l): return l.swipes_puzzle.solved and _game().case_info("radio").get("solved", false)), "a client reading the voice's badge back exposes it for everyone: that badge is on the floor, not at the loading door")
	cui.terminal = client.panel
	for q in _hint_queries(client.circuits_puzzle.hints[-1]):
		cui.run(q)
		await _frames(6)
	check(machines.all(func(l): return l.power_back and l.circuits["C9-03"].on == false and l.lights["L9-PAY"].all(func(x): return x.visible)), "a client's PATCHes bring the power back on every machine, copies in step")
	cui.run(_last_hint_query(client.air_puzzle))
	await _frames(10)
	check(machines.all(func(l): return l.air_on and l.orders.size() == 1 and l.orders[0].id == host.orders[0].id), "a client's work order starts the air everywhere, with the same number")
	cui.terminal = client.hr
	host.mimics[0].global_position = host.to_global(Vector3(2, 0, -3))
	await _frames(20)
	check(client.mimics[0].global_position.distance_to(host.mimics[0].global_position) < 0.6, "clients see the Mimics where the host has them")
	for s in client.data.night:
		cui.run(_key(client, "PATCH /doors/%s" % s.hide.door, "{\"locked\": false}"))
		await _frames(6)
		cui.run(_key(client, "POST /escorts", "{\"badge\": \"%s\", \"escort\": \"VIS-02\"}" % s.id))
		await _frames(6)
	check(machines.all(func(l): return l.passes_puzzle.solved and l.escorts.size() == 2 and l.staffers.values().all(func(st): return st.state != "hiding")), "a client's passes send both night-shifters out on every machine")
	for q in _hint_queries(client.lockup_puzzle.hints[-1]):
		cui.run(q)
		await _frames(6)
	cui.run(_key(client, "GET /doors"))
	await _frames(10)
	check(machines.all(func(l): return l.released and not l.stair_out.locked), "a client's lockup, read back, releases STAIR 2 everywhere")
	for l in machines:
		l.completed.disconnect(l._on_completed)
	host.sync.event("_on_exit")
	check(await _until(func(): return machines.all(func(l): return l.lures == 3), 120), "leaving, the voice has one more thing to say on every machine")
	await t._coop_close(worlds)


## In the World: locked in on G, up STAIR 1 from floor 10, out on 9's landing.
func test_world() -> void:
	print("Floor 9 in the World")
	_game().new_run(9)
	var world = load("res://scenes/world.tscn").instantiate()
	t.root.add_child(world)
	await _frames(10)
	world.enter_wing(world.route_index("level_4"))
	var l4 = world.current
	await _frames(20)
	check(not world.wings.has("level_5"), "floor 9 isn't built until the lie on G")
	l4.prepare_next()
	var l5 = world.wings.get("level_5")
	check(l5 != null and not l5.active and l5.global_position.distance_to(l4.global_position) > 40.0, "floor 9 builds apart from 10, without starting")
	l4.sync.event("_finish")
	for i in 1500:
		await t.physics_frame
		if world.current == l5 and l5.active:
			break
	await _frames(10)
	check(world.current == l5 and l5.active and LANDING_BOX.has_point(l5.to_local(world.player.global_position)), "the stairs hand play to floor 9, on its landing (%s)" % l5.to_local(world.player.global_position))
	check(_game().completed_level == "level_4" and _game().next_level == "level_5" and not world.player.input_locked, "floor 10 is complete, floor 9 is next, and the crew can move")
	world.queue_free()
	await t.process_frame
