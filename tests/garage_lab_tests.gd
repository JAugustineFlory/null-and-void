extends RefCounted
## The garage's lab (GarageLab): the annex through the west wall, its six
## computers, and the lockers that open each player's Customize panel.

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	var net := _tree.root.get_node("Net")
	var real_profile = net.profile
	var real_look: Dictionary = net.wanted_look.duplicate(true)
	net.profile = Profile.new()  # in memory, so tests never touch a real save
	await test_lab()
	await test_coop_lockers()
	Engine.time_scale = 4.0
	await test_tutorial()
	await test_coop_tutorial()
	Engine.time_scale = 1.0
	net.profile = real_profile
	net.wanted_look = real_look


func _game() -> Node:
	return _tree.root.get_node("Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree.physics_frame


func _until(cond: Callable, frames: int = 2400) -> bool:
	for i in frames:
		if cond.call():
			return true
		await _tree.physics_frame
	return cond.call()


## Through the garage's opening, as quickly as it goes: the work order looked at,
## the book picked up, chapter zero in.
func _to_the_lab(home, p: Player) -> bool:
	if not await _until(func(): return home.hud.current_todo() == "Read the work order in your notebook", 6000):
		return false
	home.notebook.open()
	await _frames(2)
	home.notebook.close()
	if not await _until(func(): return home.book_bag.enabled, 6000):
		return false
	p.stand_up(true)
	p.global_position = home.to_global(home.SHELF + Vector3(0, 0.1, -1.2))
	await _frames(2)
	home.book_bag.interact(p)
	return true


## A query typed at a lab computer, the screen open on it.
func _type(ui: TerminalUI, sql: String) -> void:
	ui._input.text = sql
	ui._submit()
	await _frames(3)


## Whether the largest crew body, standing, fits at each of `points` (garage-local
## feet positions) and everywhere on the way between them, `step` apart.
func _walkable(level: Node3D, points: Array, step := 0.2) -> String:
	var big := CrewBody.largest()
	var shape := CapsuleShape3D.new()
	shape.radius = big.radius
	shape.height = big.stand - 0.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	var skip: Array[RID] = []
	for n in level.find_children("*", "CharacterBody3D", true, false):
		skip.append(n.get_rid())
	q.exclude = skip
	var space := level.get_world_3d().direct_space_state
	for k in points.size() - 1:
		var a: Vector3 = points[k]
		var b: Vector3 = points[k + 1]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for i in n + 1:
			var at := a.lerp(b, float(i) / n)
			q.transform = Transform3D(Basis(), level.to_global(at + Vector3.UP * (shape.height / 2 + 0.1)))
			var hits := space.intersect_shape(q, 1)
			if not hits.is_empty():
				return "blocked at %s by %s" % [at, hits[0].collider.name]
	return ""


func test_lab() -> void:
	print("Garage: the lab, its computers and lockers")
	_game().new_run(41)
	_game().open_at_home = true
	var world = load("res://scenes/world.tscn").instantiate()
	_tree.root.add_child(world)
	await _frames(30)
	var home = world.home
	var lab: GarageLab = home.lab
	var p: Player = world.player
	_check.call(lab != null and lab.computers.size() == 6 and lab.lockers.size() == 6, "the lab has six computers and six lockers")
	_check.call(lab.computers.all(func(c): return c is Terminal and c.practice and c.db == lab.db and c.prompt == GarageOffice.PC_PROMPT), "the computers are practice terminals on the lab's own database, with the back office's words")
	_check.call(lab.db != home.db and lab.db.table_names().has("van_kit") and lab.db.table_names().has("jobs"), "that database is the practice's, not the building's")
	var sign: Label3D = home.geo.get_node_or_null("LabSign")
	_check.call(sign != null and sign.text == lab.SIGN, "a sign over the doorway")

	# Every way round it fits the largest body: in through the doorway, along the
	# lockers, down both lanes between the desks and in front of the board.
	var z := GarageLab.DOOR_Z
	var lanes := {
		"in through the doorway": [Vector3(-6.0, 0, z), Vector3(-8.9, 0, z)],
		"up the east side to the lockers": [Vector3(-8.9, 0, z), Vector3(-8.9, 0, -4.85), Vector3(-13.45, 0, -4.85)],
		"down the lane between the rows": [Vector3(-11.25, 0, -4.85), Vector3(-11.25, 0, 1.8)],
		"down the east side": [Vector3(-8.9, 0, z), Vector3(-8.9, 0, 1.8)],
		"in front of the board": [Vector3(-13.45, 0, -4.85), Vector3(-13.45, 0, 1.8)],
		"along the back": [Vector3(-13.45, 0, 1.8), Vector3(-8.9, 0, 1.8)],
	}
	for lane in lanes:
		var why := _walkable(home, lanes[lane])
		_check.call(why == "", "the largest crew body fits %s %s" % [lane, why])
	# Each computer is reached from the lane on its east side, to where you stand at it.
	var reach := []
	for i in lab.computers.size():
		var stand: Vector3 = home.to_local(lab.computers[i].stand_point.global_position)
		var lane_x := -11.25 if i < 3 else -8.9
		reach.append(_walkable(home, [Vector3(lane_x, 0, stand.z), Vector3(stand.x, 0, stand.z)]))
	_check.call(reach.all(func(r): return r == ""), "and up to every computer %s" % [reach])
	_check.call(home.to_local(lab.global_position) == Vector3.ZERO and GarageLab.ROOM.z + GarageLab.ROOM_SIZE.z / 2 < GarageOffice.ROOM.z - GarageOffice.ROOM_SIZE.z / 2,
		"and it stops short of the back office")

	# Lockers: yours has your name and opens; the rest have nobody's.
	var mine := lab.locker_of(p.multiplayer.get_unique_id())
	var net := _tree.root.get_node("Net")
	_check.call(mine == lab.lockers[0] and mine.enabled and mine.local_only and mine.prompt == lab.LOCKER_PROMPT, "your locker is the first, and it opens")
	_check.call(lab.name_cards[0].text == net.player_name and lab.name_cards.slice(1).all(func(c): return c.text == ""), "with your name on it; the empty ones have no name")
	_check.call(lab.lockers.slice(1).all(func(l): return not l.enabled), "and nobody's locker opens")
	var fp_before: Node = p.get_node("FirstPersonBody")
	mine.interact(p)
	await _frames(3)
	var panel: MenuModal = lab.panel
	var picker: LookPicker = panel.find_child("LookPicker", true, false) if panel else null
	var tabs: TabContainer = picker.find_child("Customize", true, false) if picker else null
	_check.call(picker != null and p.input_locked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "opening it shows your Customize panel and holds you still")
	_check.call(tabs != null and tabs.get_node_or_null("Crew") == null and tabs.get_node_or_null("Look") != null and tabs.get_node_or_null("Gear") != null,
		"Look and Gear, without the Crew tab (who you play is set in the lobby)")
	_check.call(panel.is_ancestor_of(_tree.root.gui_get_focus_owner()), "with something picked, so a controller can use it")

	# A pick shows on you straight away, and is saved.
	var skin: int = (int(picker.my_look().skin) + 1) % CharacterLooks.SKIN_TONES.size()
	var crew: String = picker.my_look().crew
	(picker.find_child("Skin%d" % (skin + 1), true, false) as Button).pressed.emit()
	await _frames(3)
	var fp_after: Node = p.get_node_or_null("FirstPersonBody")
	_check.call(int(net.profile.loadout.get("skin", -1)) == skin and int(picker.my_look().skin) == skin, "a new skin is saved to your profile")
	_check.call(fp_after != null and fp_after != fp_before and is_instance_valid(fp_after.rig), "and your body is dressed in it straight away")
	# Mid-run, who you play stays put, even if something asks to change it.
	net.in_game = true
	net.choose_look({"crew": "dana" if crew != "dana" else "walt", "skin": 0})
	net.in_game = false
	await _frames(2)
	_check.call(picker.my_look().crew == crew and int(picker.my_look().skin) == 0, "mid-run, a change of crew is ignored (the rest still applies)")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	_tree.root.push_input(cancel)
	await _frames(3)
	_check.call(not is_instance_valid(panel) and not p.input_locked, "Back closes it and lets you move again")

	world.queue_free()
	await _frames(2)


## The practice, solo, for someone who's never done it: sit at a lab computer,
## the kit's case with the notebook's help (its table on the crate's label), then
## the jobs' case without it; wrong clicks say why; practice doesn't wear the word
## buttons down; chapter 1 comes in here, once.
func test_tutorial() -> void:
	print("Garage: the lab's practice cases, solo")
	var net := _tree.root.get_node("Net")
	net.profile = Profile.new()
	var prof: Profile = net.profile
	_game().new_run(47)
	_game().open_at_home = true
	var world = load("res://scenes/world.tscn").instantiate()
	_tree.root.add_child(world)
	await _frames(30)
	var home = world.home
	var lab: GarageLab = home.lab
	var tut: GarageTutorial = lab.tutorial
	var p: Player = world.player
	var g: Node = _game()
	_check.call(not tut.running and not tut.finished and lab.computers.all(func(c): return not c.enabled), "the lab's computers are off until the practice")
	_check.call(await _to_the_lab(home, p), "through the opening to the book")
	_check.call(await _until(func(): return g.book_chapters.has("easy_sql_0") and tut.running, 2400), "after chapter zero, the practice starts")
	_check.call(tut.learners == [p.multiplayer.get_unique_id()], "for the one player who hasn't done it")
	_check.call(await _until(func(): return home.hud.current_todo() == GarageTutorial.SIT, 2400) and lab.computers.all(func(c): return c.enabled),
		"she sends them to a lab computer, and the computers are on")
	_check.call(await _until(func(): return home.maddison_mark == "lab"), "Maddison heads for the lab")
	await _frames(60)
	_check.call(g.case_info("lab_kit").is_empty(), "nothing goes on while nobody's sat down")

	var pc: Terminal = lab.computers[1]
	var ui: TerminalUI = home.terminal_ui
	p.global_position = pc.stand_point.global_position
	pc.interact(p)
	await _frames(3)
	_check.call(ui.visible and ui.terminal == pc, "a lab computer opens like any terminal")
	_check.call(await _until(func(): return g.case_info("lab_kit").get("open", false)), "sitting down opens the first case")
	var kit: Dictionary = g.case_info("lab_kit")
	_check.call(kit.get("title", "") == GarageTutorial.KIT_CASE and home.hud.current_todo() == GarageTutorial.KIT_OBJ, "the kit's case, its question and what to do")
	_check.call(kit.get("note", "") == GarageTutorial.INTRO_CASE, "its page says how a case works")
	_check.call(not g.book_chapters.has("easy_sql_1"), "chapter 1 waits for the table's name")
	_check.call(pc.hint_case() == "lab_kit" and pc.next_hint() == GarageTutorial.KIT_HINTS[0], "the computer's first hint points at the crate's label")
	tut.kit_puzzle.hint_index = 0
	ui.close()
	await _frames(2)

	tut.label.interact(p)
	await _frames(3)
	for r in _tree.root.find_children("*", "DocumentReader", true, false):
		r.queue_free()
	p.input_locked = false
	_check.call(await _until(func(): return g.has_piece("lab_kit", "table"), 120), "reading the crate's label finds the table's name")
	_check.call(tut.kit_puzzle.hint_index >= 1, "and the hints skip past where to look")
	_check.call(await _until(func(): return g.book_chapters.has("easy_sql_1"), 2400), "then chapter 1 comes in, the book's first query")

	var select_before := prof.uses_of("SELECT")
	ui.open(pc, p)
	await _frames(2)
	await _type(ui, "SELECT * FROM jobs;")
	_check.call(not tut._kit_listed, "the wrong table isn't the kit")
	await _type(ui, "SELECT item FROM van_kit;")
	_check.call(tut._kit_listed, "SELECT item FROM van_kit; lists the kit too, not just the shape on the page")
	_check.call(await _until(func(): return g.case_info("lab_kit").steps.any(func(st): return st.id == "run" and st.done)), "and the run step is ticked")
	_check.call(prof.uses_of("SELECT") == select_before, "practice doesn't count towards retiring a word's button")
	_check.call(not home.db.table_names().has("van_kit") and not home.db.table_names().has("jobs"), "the practice tables stay out of the building's database")

	# Pointing at the wrong cell says why; the right one answers it.
	_check.call(not g.add_cell("qty", "0", {"item": "duct tape", "qty": "0"}), "the right row's qty doesn't answer it")
	_check.call(g.case_info("lab_kit").blank.get("miss", "") == GarageTutorial.KIT_ROW_MISS, "the page says the blank wants the item's name")
	_check.call(not g.add_cell("item", "ladder", {"item": "ladder", "qty": "1"}), "an item there's some of doesn't")
	_check.call(g.add_cell("item", "duct tape", {"item": "duct tape", "qty": "0"}), "duct tape, with none left, answers it")
	_check.call(await _until(func(): return g.case_info("lab_kit").get("solved", false)), "the kit's case is solved")

	# The second case: no shape on the page, the table on the job board.
	_check.call(await _until(func(): return g.case_info("lab_jobs").get("open", false), 1200), "then the jobs' case")
	_check.call(g.case_info("lab_jobs").get("query", "x") == "" and home.hud.current_todo() == GarageTutorial.JOBS_OBJ, "with no query to fill in this time")
	tut.board.interact(p)
	await _frames(3)
	for r in _tree.root.find_children("*", "DocumentReader", true, false):
		r.queue_free()
	p.input_locked = false
	_check.call(await _until(func(): return g.has_piece("lab_jobs", "table"), 120), "the job board gives the table's name")
	ui.open(pc, p)
	await _frames(2)
	await _type(ui, "SELECT * FROM jobs;")
	ui.close()
	_check.call(not g.add_cell("client", "Kemp Dental", {"client": "Kemp Dental", "status": "done"}), "a finished job doesn't answer it")
	_check.call(g.case_info("lab_jobs").blank.get("miss", "") == GarageTutorial.JOBS_DONE_MISS, "the page says that one's done")
	_check.call(g.add_cell("client", GarageTutorial.OPEN_JOB, {"client": GarageTutorial.OPEN_JOB, "status": "open"}), "the open job's client answers it")
	_check.call(await _until(func(): return g.case_info("lab_jobs").get("solved", false)), "the jobs' case is solved")
	_check.call(await _until(func(): return tut.finished, 2400) and not tut.running, "the practice is over")
	_check.call(g.practiced and prof.tutorial_done, "it's remembered for the run and on the profile")
	_check.call(lab.computers.all(func(c): return c.enabled), "and the lab stays open")
	_check.call(await _until(func(): return home.hud.current_todo() == home.SPAR_TODO, 2400), "then the punch bag, as before")
	await Huddle.of(home).run("easy_sql_1", Huddle.REMEMBERED)
	_check.call(g.book_chapters.count("easy_sql_1") == 1, "chapter 1 is in once: floor G's front desk won't bring it in again")
	tut.forget_tables()
	_check.call(not g.notebook_tables.has("van_kit") and not g.notebook_tables.has("jobs"), "leaving, the practice tables come off the Tables page")
	world.queue_free()
	await _frames(2)


## Co-op: each machine says whether its player has done the practice, the host
## decides who it waits for, and a client's seat and answers reach the host.
func test_coop_tutorial() -> void:
	print("Garage: co-op, the practice waits for whoever's new to it")
	_game().new_run(49)
	_game().open_at_home = true
	var worlds: Array = await _tree._coop_worlds(1)
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/world.tscn")
	var tuts: Array = machines.map(func(w): return w.home.lab.tutorial)
	var ids: Array = machines[0].home.players.all_ids()
	var host: int = ids[0]
	var client: int = ids[1]
	tuts[0]._done_before[host] = false
	tuts[1]._said_done.rpc_id(1, true)  # the client's player has done it before
	_check.call(await _until(func(): return tuts[0]._done_before.has(client), 120) and tuts[0]._done_before[client], "the client says it has done the practice")
	await tuts[0]._decide_learners()
	_check.call(await _until(func(): return tuts.all(func(t): return t.learners == [host]), 120), "every machine waits only for the host, the one new to it")
	var pc: Terminal = machines[1].home.lab.computers[3]
	pc.enabled = true
	pc.interact(machines[1].player)
	_check.call(await _until(func(): return tuts[0]._sat.has(client), 120), "a client sitting at a lab computer is seen by the host")
	machines[1].terminal_ui.close()
	tuts[1]._on_answer_found("lab_kit")
	_check.call(await _until(func(): return tuts[0]._kit_found, 120), "a client's practice answer reaches the host")
	_tree._coop_close(worlds)
	await _frames(2)


func test_coop_lockers() -> void:
	print("Garage: co-op, a locker each and changes seen by everyone")
	_game().new_run(43)
	_game().open_at_home = true
	var worlds: Array = await _tree._coop_worlds(1)
	var net := _tree.root.get_node("Net")
	var real_roster: Dictionary = net.roster
	net.roster = {}  # the names the host handed out in the lobby
	for w in worlds:
		net.roster[_tree.get_multiplayer(w.get_path()).get_unique_id()] = "Crew%d" % net.roster.size()
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/world.tscn")
	var labs := machines.map(func(w): return w.home.lab)
	var ids: Array = machines[0].home.players.all_ids()
	var client: int = ids[1]
	_check.call(labs.all(func(l): return l.owners.slice(0, 2) == ids and l.owners.slice(2).all(func(o): return o == 0)),
		"every machine gives the host the first locker and the client the second")
	_check.call(labs[0].lockers[0].enabled and not labs[0].lockers[1].enabled and labs[1].lockers[1].enabled and not labs[1].lockers[0].enabled,
		"and each player's own locker is the one that opens for them")
	_check.call(labs.all(func(l): return l.name_cards[0].text == "Crew0" and l.name_cards[1].text == "Crew1"), "each one's name is on theirs, on every machine")
	# The client's look changes (the host has passed it on): the host sees it on them.
	var puppet: PlayerPuppet = machines[0].home.players.puppet(client)
	var rig_before := puppet.rig
	var look: Dictionary = net.look_of(client, 1).duplicate(true)
	look.skin = (int(look.skin) + 2) % CharacterLooks.SKIN_TONES.size()
	net.looks[client] = look
	net.roster_changed.emit()
	await _frames(2)
	_check.call(puppet.rig != rig_before and is_instance_valid(puppet.rig) and puppet.rig.get_parent() != null, "a teammate's change of look shows on them straight away")
	_check.call(puppet.size == CrewBody.from_look(NetPlayers.look_for(machines[0], client)).size, "in the same body")
	net.looks.erase(client)
	net.roster = real_roster
	_tree._coop_close(worlds)
	await _frames(2)
