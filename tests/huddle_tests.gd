extends RefCounted
## The garage home base and the crew's book huddles (scripts/huddle/,
## scripts/levels/home_base.gd): the book's data, the opening in the garage,
## a flashback from the building, and a two-player vote.

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	test_books()
	var net := _tree.root.get_node("Net")
	var real_profile = net.profile
	net.profile = Profile.new()  # in memory, so tests never touch a real save
	test_book_unlocks()
	test_garage_front()
	Engine.time_scale = 4.0
	await test_garage_opening()
	await test_flashback()
	await test_coop_huddle()
	await test_coop_spar()
	await test_coop_walk_in()
	Engine.time_scale = 1.0
	net.profile = real_profile


func _game() -> Node:
	return _tree.root.get_node("Game")


## Huddle, HomeBase and HuddleUI aren't named as classes here: they pull in
## LevelBase, which uses the Game autoload by name.
func _huddle_of(node: Node) -> Node:
	return _tree._huddle_of(node)


func _frames(n: int) -> void:
	for i in n:
		await _tree.physics_frame


## Wait until `cond` holds, up to `frames` physics frames. True if it did.
func _until(cond: Callable, frames: int = 2400) -> bool:
	for i in frames:
		if cond.call():
			return true
		await _tree.physics_frame
	return cond.call()


func test_books() -> void:
	print("Books: Easy SQL")
	var ok := true
	var words_ok := true
	for id in Books.chapter_ids():
		var ch := Books.chapter(id)
		words_ok = words_ok and ch.words.size() <= 3
		ok = ok and ch.pages.size() > 0 and ch.quiz.size() == 3 * maxi(1, ch.words.size())
		for q in ch.quiz:
			ok = ok and q.answer >= 0 and q.answer < q.options.size() and q.options.size() == 3
			ok = ok and (ch.words.is_empty() or ch.words.has(q.word))
	_check.call(ok and Books.chapter_ids().size() == 17, "all 17 chapters have pages and three questions for each new word (three for a review)")
	var ids := Books.book_chapter_ids("easy_sql")
	_check.call(ids.slice(15) == ["easy_sql_distinct", "easy_sql_group_by"] and Books.chapter("easy_sql_distinct").number == 15 and Books.chapter("easy_sql_group_by").words == ["GROUP BY"],
		"floor 18's chapters close the book, numbered by their place in it")
	_check.call(ids[9] == "easy_sql_count" and Books.chapter("easy_sql_count").words == ["COUNT(*)"] and Books.chapter("easy_sql_9").number == 10,
		"How many? (COUNT) follows Chapter 8, and the chapters after it move up one")
	_check.call(Books.chapter("easy_sql_4").words == ["DESC", "LIMIT"], "Newest first teaches LIMIT after DESC")
	_check.call(words_ok, "every chapter brings at most three new words")
	var covered := true
	for id in Books.chapter_ids():
		var ch := Books.chapter(id)
		var pages := []
		var qs := []
		for r in Books.rounds(ch):
			pages.append_array(r.pages)
			qs.append_array(r.questions)
		pages.sort()
		qs.sort()
		covered = covered and pages == range(ch.pages.size()) and qs == range(ch.quiz.size())
	_check.call(covered, "every chapter's rounds read each page and ask each question once")
	var r2 := Books.rounds(Books.chapter("easy_sql_2"))
	_check.call(r2.size() == 2 and r2[0].pages == [0] and r2[0].questions == [0, 1, 2] and r2[0].ref == [0] and r2[1].pages == [1] and r2[1].questions == [3, 4, 5],
		"a word's page, then its three questions with the page on show, then the next word")
	var r0 := Books.rounds(Books.chapter("easy_sql_0"))
	_check.call(r0.slice(0, 3).all(func(r): return r.ref == [1] and r.questions.size() == 3) and r0[3].questions.is_empty(),
		"in chapter 0 the jobs table stays on show for every question, and the last page closes the book")
	var ch1 := Books.chapter("easy_sql_1")
	_check.call(ch1.book == "EASY SQL" and ch1.words.has("SELECT") and ch1.required and not Books.chapter("easy_sql_2").required and ch1.pages[0].contains("SELECT columns FROM table;"), "chapter 1 shows the shape of a query and its semicolon")
	var keeps := true
	var spots := {}
	for seed_value in 40:
		for q in ch1.quiz:
			var s := Books.shuffled(q, seed_value, "x")
			keeps = keeps and s.options[s.answer] == q.options[q.answer] and s.options.size() == q.options.size()
			keeps = keeps and JSON.stringify(Books.shuffled(q, seed_value, "x")) == JSON.stringify(s)
			spots[s.answer] = true
	_check.call(keeps, "shuffled answers stay right, and the same run seed always shuffles the same way")
	_check.call(spots.size() == 3, "across runs, the right answer moves between the three places")
	# The building's tables never appear in the book: its examples are its own.
	var leaks := []
	for id in Books.chapter_ids():
		var ch := Books.chapter(id)
		var text := JSON.stringify([ch.pages, ch.quiz])
		for t in ["memo_fragments", "door_controllers", "staff", "visitors", "doors", "guards"]:
			if text.contains(t):
				leaks.append("%s: %s" % [id, t])
	_check.call(leaks.is_empty(), "the book only uses its own example table %s" % [leaks])
	var l0 := FileAccess.get_file_as_string("res://scripts/levels/level_0.gd")
	var at_huddle := l0.find("run(\"easy_sql_1\")")
	_check.call(at_huddle > 0 and at_huddle < l0.find("desk_terminal.enabled = true\n\t_rourke_free"), "Level 0 flashes back to chapter 1 before the desk terminal opens")


## Answer the huddle's current question: right, or a wrong option.
func _answer(h, right: bool) -> void:
	var q: Dictionary = h.current_question()
	h.vote(q.answer if right else (q.answer + 1) % q.options.size())


## Read every page and answer every question right (after one wrong answer).
func _finish_chapter(h, id: String) -> bool:
	if not await _until(func(): return h.chapter.get("id", "") == id, 600):
		return false
	while h.question < 0:
		h.turn_page()
		await _frames(2)
	var first_wrong := true
	while not h.done.has(id):
		if h.question < 0 and h.is_running():
			h.turn_page()  # the next round's page
		elif h.question >= 0 and h.result.is_empty() and not h.votes.has(h.multiplayer.get_unique_id()):
			_answer(h, not first_wrong)
			first_wrong = false
		await _frames(2)
	return true


## Co-op's pre-game lobby builds the garage front on its own and holds a shot on
## it; the World's garage opens on the same shot.
func test_garage_front() -> void:
	print("Home base: the garage front for the lobby")
	var hb = load("res://scripts/levels/home_base.gd")
	var stage := Node3D.new()
	_tree.root.add_child(stage)
	var front: Node3D = hb.build_front(stage)
	_check.call(front.get_node_or_null("RollUpDoor") != null and front.get_node_or_null("Driveway") != null, "the garage front builds on its own: walls, driveway and the shut roll-up door")
	_check.call(front.find_children("Maddison", "", true, false).is_empty() and not front.has_method("start"), "with no story in it: no Maddison, no level")
	var cam: Transform3D = hb.LOBBY_CAMERA
	var half_v := deg_to_rad(75.0) / 2.0  # Camera3D's default fov, vertical
	var half_h := atan(tan(half_v) * 16.0 / 9.0)
	var all_in_shot := true
	var all_face := true
	var on_apron := true
	var apron := AABB(hb.APRON_CENTER - hb.APRON_SIZE / 2, hb.APRON_SIZE)
	for i in 6:
		var spot: Dictionary = hb.lobby_spot(i)
		var at: Transform3D = spot.at
		var local := cam.affine_inverse() * (at.origin + Vector3(0, 1.0, 0))
		all_in_shot = all_in_shot and local.z < 0 and absf(atan2(local.x, -local.z)) < half_h * 0.85 and absf(atan2(local.y, -local.z)) < half_v * 0.85
		var to_cam := (cam.origin - at.origin) * Vector3(1, 0, 1)
		all_face = all_face and (-at.basis.z).dot(to_cam.normalized()) > 0.95 and CharacterRig.ACTIONS.has(spot.pose)
		var entry: Vector3 = hb.lobby_entry(i)
		var from_cam := cam.affine_inverse() * (entry + Vector3(0, 1.0, 0))
		on_apron = on_apron and apron.grow(0.01).has_point(Vector3(at.origin.x, 0, at.origin.z)) and apron.grow(0.01).has_point(Vector3(entry.x, 0, entry.z)) and absf(atan2(from_cam.x, -from_cam.z)) > half_h
	_check.call(all_in_shot, "all six lobby spots are in the lobby camera's shot")
	_check.call(all_face, "each lobby spot faces the camera with a pose the rig can play")
	_check.call(on_apron, "players walk in from just off screen, on the driveway, to their spots")
	_check.call(hb.FRONT_DOOR.distance_to(Vector3(hb.DOOR_AT, 0, -hb.SIZE.z / 2)) < 0.01, "the front-door marker is at the foot of the roll-up door")
	var env := Environment.new()
	var mode := env.background_mode
	var dusk: Dictionary = hb.dusk_outside(env, stage)
	_check.call(env.background_mode == Environment.BG_SKY and env.sky != null and stage.get_node_or_null("DuskSun") != null, "dusk out front: the lobby's sky and a low sun, shared by the lobby and the World's garage")
	hb.restore_outside(env, dusk)
	_check.call(env.background_mode == mode and env.sky == null, "and the sky goes back as it was")
	stage.queue_free()


func test_garage_opening() -> void:
	print("Home base: the garage opening")
	_game().new_run(21)
	_game().open_at_home = true
	var world = load("res://scenes/world.tscn").instantiate()
	_tree.root.add_child(world)
	await _frames(30)
	var home = world.home
	var p: Player = world.player
	_check.call(home != null and world.current == home and home.active, "a new game opens in the crew's garage")
	_check.call(home.global_position.distance_to(Vector3.ZERO) > 200.0, "the garage sits far from the tower")
	_check.call(world.wings.has("level_0") and not world.wings["level_0"].active, "the ground floor is built ahead, waiting for the van")
	_check.call(home.lobby_camera.current and p.input_locked and not home.find_children("WalkIn*", "", false, false).is_empty(), "it opens on the lobby's shot of the garage, the crew out front")
	_check.call(not home.fax.enabled and not home.van_door.enabled and not home.book_bag.enabled, "nothing to do while the crew walks in")
	_check.call(home.lobby_camera.transform.is_equal_approx(home.LOBBY_CAMERA) and home.roll_up_door.get_parent() == home, "the World's garage has the lobby's shot, and its door is kept out of the floor's navigation")
	_check.call(await _until(func(): return home.roll_up_door.position.y > home.DOOR_SIZE.y), "the roll-up door goes up")
	_check.call(await _until(func(): return home.flashback_camera.current, 600), "and the shot goes inside once they're through it")
	_check.call(home.environment.background_mode != Environment.BG_SKY and home.get_node_or_null("DuskSun") == null, "the dusk sky out front goes with the outside shot")
	_check.call(await _until(func(): return p.camera.current and p.is_sitting() and home._in_a_seat(p) and not p.input_locked, 1200), "then you're in your own seat facing the whiteboard, in first person")
	_check.call(await _until(func(): return home.find_children("WalkIn*", "", false, false).is_empty(), 60), "the walk-in stand-ins are gone")
	var mad: Node3D = home.maddison
	_check.call(mad != null and mad.get_node_or_null("Look") != null, "Maddison is in the garage in person")
	_check.call(await _until(func(): return _at_mark(home, "board"), 600), "she comes in from the house to her whiteboard")
	_check.call(await _until(func(): return home.hud.current_todo() == "Block the punch bag", 2400), "after the brief she sends the crew to the punch bag")
	p.stand_up(true)
	await _frames(2)
	await _spar(home, p)
	_check.call(await _until(func(): return home.hud.current_todo() == "Sit back down facing Maddison", 300), "then back to their seats")
	await _frames(60)
	_check.call(home.read_order.is_empty() and not home.book_bag.enabled, "she waits for everyone to sit down")
	await home._seat_me(home.crew_seats[2])
	_check.call(await _until(func(): return home.hud.current_todo() == "Look at the work order in your notebook", 1200), "seated again, she points them at the work order in their notebooks")
	await _frames(60)
	_check.call(not home.book_bag.enabled, "and waits for everyone to look")
	home.notebook.open()
	_check.call(await _until(func(): return home.read_order.size() == 1, 60), "pulling out the notebook counts as looking")
	home.notebook.close()
	_check.call(await _until(func(): return home.book_bag.enabled, 2400), "then the book on the shelf by the side door")
	var lit := true
	for spot in [home.book_bag.global_position, home.fax.global_position, home.to_global(home.WHITEBOARD), home.to_global(home.VAN)]:
		var reach := 0.0
		for id in home.lights:
			for l in home.lights[id]:
				reach = maxf(reach, l.omni_range - l.global_position.distance_to(spot))
		lit = lit and reach > 1.5
	_check.call(lit and home.environment.ambient_light_energy >= 0.4, "the garage is well lit, the back corner included")
	var prof: Profile = _tree.root.get_node("Net").profile
	_check.call(not prof.earned.has("achievement:book_easy_sql"), "the book's unlock waits until it's picked up")
	p.stand_up(true)
	p.global_position = home.to_global(home.SHELF + Vector3(0, 0.1, -1.2))
	await _frames(2)
	home.book_bag.interact(p)
	await _frames(5)
	_check.call(prof.earned.has("achievement:book_easy_sql"), "picking up Easy SQL earns its notebook cover")
	_check.call(not home.book_bag.visible and home.held_book != null and home.held_book.get_parent() == p.camera, "the book is in your hands, like the notebook")
	await _frames(60)
	_check.call(not _huddle_of(home).is_running(), "the chapter waits for whoever has the book to sit down with it")
	await home._seat_me(home.crew_seats[0])
	var h = _huddle_of(home)
	h.reveal_scale = 0.2
	var opened := await _until(func(): return h.is_running(), 1200)
	if not opened:
		print("    sitting=%s in_seat=%s holder=%s todo=%s gates=%s" % [p.is_sitting(), home._in_a_seat(p), home.book_holder, home.hud.current_todo(), home.sync._gates.keys()])
	_check.call(opened, "sitting down with the book opens chapter zero")
	_check.call(h.chapter.id == "easy_sql_0" and h.is_reader() and p.input_locked and home.held_book == null, "solo, you read the first chapter from your seat")
	var ui = h.get_node_or_null("HuddleUI")
	_check.call(ui != null and not ui.flashback and ui.find_child("Next", true, false).visible, "the book opens over the garage with a page-turn for the reader")
	var book_rect: Rect2 = ui.find_child("Book", true, false).get_global_rect()
	_check.call(not home.hud._subtitle.get_global_rect().intersects(book_rect), "subtitles sit clear of the open book")
	h.turn_page(-1)
	await _frames(2)
	_check.call(h.page == 0, "the reader can't turn back from the first page")
	while h.question < 0:
		h.turn_page()
		await _frames(2)
	_check.call(h.question == 0 and ui.find_children("Option*", "", true, false).size() == 3, "after the first word's pages, its questions: three answers to pick from")
	_check.call(h.reference().size() == 1 and ui.find_child("*", true, false) != null and ui._body.get_parsed_text().contains("job_no"), "the jobs table is on show beside the question")
	_answer(h, false)
	_check.call(await _until(func(): return h.result.has("choice"), 60) and not h.result.right, "a wrong answer says why")
	_check.call(await _until(func(): return h.result.is_empty()) and h.question == 0, "and the same question comes back")
	_answer(h, true)
	await _frames(3)
	_check.call(h.result.get("right", false), "the right answer is marked right")
	_check.call(await _until(func(): return h.question == 1), "then the next question")
	_check.call(await _finish_chapter(h, "easy_sql_0"), "the crew finishes the chapter")
	_check.call(_game().book_words.has("row"), "its words are learned")
	_check.call(prof.earned.has("chapter:easy_sql_0") and not prof.earned.has("achievement:easy_sql_half"), "the chapter is remembered on the profile; one chapter isn't half the book")
	_check.call(await _until(func(): return not p.input_locked and h.get_node_or_null("HuddleUI") == null), "the book closes and the player can move again")
	_check.call(home.hud._subtitle.offset_left < -100, "and the subtitles go back to the middle")
	_check.call(await _until(func(): return home.van_door.enabled), "then the van")
	_check.call(await _until(func(): return _at_mark(home, "van"), 300), "Maddison sees the crew off at the van door")
	home.van_door.interact(p)
	await _frames(3)
	_check.call(p.seated and home.to_local(p.global_position).distance_to(home.van_seats[0]) < 0.3, "the player takes a seat in the van")
	var lobby = world.wings["level_0"]
	_check.call(await _until(func(): return world.current == lobby and lobby.active), "the drive ends at Halcyon: play moves to the ground floor")
	_check.call(p.global_position.z > 14.0 and p.global_position.y > 0.3 and p.seated, "the crew arrives sitting in the van in the car park")
	_check.call(not home.visible and is_instance_valid(home), "the garage stays loaded, out of sight, for flashbacks")
	world.queue_free()
	await _frames(2)


## Maddison stands on `mark`, facing the way it says.
func _at_mark(home, mark: String) -> bool:
	var m: Array = home.MADDISON_MARKS[mark]
	var mad: Node3D = home.maddison
	var to: Vector3 = m[1] - mad.position
	var facing := -mad.basis.z
	return mad.position.distance_to(m[0]) < 0.1 and Vector2(facing.x, facing.z).normalized().dot(Vector2(to.x, to.z).normalized()) > 0.95


## The punch bag drill, solo: it only swings at someone standing by it, a miss
## costs nothing, and a block lets the crew move on to the huddle.
func _spar(home, p) -> void:
	var net: Node = _tree.root.get_node("/root/Net")
	var real_profile = net.profile
	net.profile = Profile.new()  # in memory, so tests never touch a real save
	_check.call(home.punch_bag != null and home.spar_blocked.is_empty(), "then the punch bag, before the huddle")
	var swung := await _until(func(): return home.swing_in, 200)
	_check.call(not swung, "the bag leaves you be while you're nowhere near it")
	p.global_position = home.to_global(home.PUNCH_BAG + Vector3(1.0, 0.2, 0.8))
	_check.call(await _until(func(): return home.swing_in, 400), "stand by it and it swings at you")
	var health: float = p.health
	await _until(func(): return not home.swing_in, 120)
	await _frames(3)
	_check.call(p.health == health and home.spar_blocked.is_empty(), "a missed block costs no health, and doesn't count")
	_check.call(not _huddle_of(home).is_running(), "the crew can't huddle until it's blocked")
	_check.call(await _until(func(): return home.swing_in, 400), "the bag swings again")
	await _frames(2)  # partway into the swing
	p.combat.raise_guard()
	_check.call(await _until(func(): return home.spar_blocked.size() == 1, 120), "right-clicking as it swings in blocks it")
	_check.call(p.health == health, "blocking it costs nothing either")
	_check.call(not net.profile.earned.has(CrewVitals.FIRST_BLOCK), "and it's practice: the punch bag never earns the High-tops")
	net.profile = real_profile


## Half the book and the whole book unlock an item each, counted across runs.
func test_book_unlocks() -> void:
	print("Huddle: Easy SQL unlocks")
	var level := Node.new()
	_tree.root.add_child(level)
	load("res://scripts/net/level_sync.gd").create(level)
	var h = load("res://scripts/huddle/huddle.gd").create(level)
	var net := _tree.root.get_node("Net")
	var test_profile = net.profile
	net.profile = Profile.new()
	var prof: Profile = net.profile
	var ids: Array = Books.book_chapter_ids("easy_sql")
	var n := ids.size()
	var half := ceili(n / 2.0)
	_check.call(n == 17, "Easy SQL has 17 chapters to count")
	var me: int = h.multiplayer.get_unique_id()
	var finish := func(id: String):
		h._begin(id, me, [me])
		h._complete(id)
	h._begin(ids[n - 1], me + 1, [me + 1])  # a huddle this player wasn't in
	h._complete(ids[n - 1])
	_check.call(not prof.earned.has("chapter:" + ids[n - 1]), "a chapter read by a huddle you weren't in doesn't count for you")
	h.done.clear()
	for i in half - 1:
		finish.call(ids[n - 1 - i])  # any order
	_check.call(not prof.earned.has("achievement:easy_sql_half"), "%d chapters isn't half" % (half - 1))
	finish.call(ids[n - half + 1])
	_check.call(not prof.earned.has("achievement:easy_sql_half"), "the same chapter twice counts once")
	h.done.clear()  # a new run: chapters read before still count
	finish.call(ids[0])
	_check.call(prof.earned.has("achievement:easy_sql_half") and not prof.earned.has("achievement:easy_sql_done"), "%d of %d, across runs, is half the book" % [half, n])
	for id in ids:
		finish.call(id)
	_check.call(prof.earned.has("achievement:easy_sql_done"), "all %d finishes the book" % n)
	net.profile = test_profile
	level.free()


func test_flashback() -> void:
	print("Huddle: a flashback from the building")
	_game().new_run(22)
	var world = load("res://scenes/world.tscn").instantiate()
	_tree.root.add_child(world)
	await _frames(30)
	var p: Player = world.player
	var h = _huddle_of(world.current)
	h.reveal_scale = 0.2
	_check.call(world.home == null and h != null, "a game started in the van has no garage until a flashback needs one")
	var done := [false]
	var run_it := func():
		await h.run("easy_sql_1")
		done[0] = true
	run_it.call()
	_check.call(await _until(func(): return h.is_running() and h.get_node_or_null("HuddleUI") != null), "the flashback opens the book")
	var home = world.get_node_or_null("HomeBase")
	_check.call(home != null and home.visible and home.flashback_camera.current, "it cuts to the garage through the flashback camera")
	var cam: Camera3D = home.flashback_camera
	_check.call(not cam.is_position_behind(home.to_global(home.WHITEBOARD)) and not cam.is_position_behind(home.maddison.global_position), "the camera looks over the crew at Maddison and her whiteboard")
	var figures: Array = home.find_children("Crew*", "", false, false)
	_check.call(figures.size() == 1 and figures[0].get_children().any(func(c): return c.get("action") == "sit"), "solo, one crew member sits facing the whiteboard")
	_check.call(_at_mark(home, "board"), "Maddison is at her whiteboard, facing the crew")
	_check.call(home.crew_seats.size() == 6 and home.CREW_SEATS.all(func(v): return v.x > home.WHITEBOARD.x + 2.5 and absf(v.z - home.WHITEBOARD.z) < 1.5), "six seats, all in front of the whiteboard")
	_check.call(h.get_node("HuddleUI").flashback and p.input_locked, "in sepia, with the player held still")
	_check.call(await _finish_chapter(h, "easy_sql_1"), "the crew reads chapter 1 and answers its check")
	_check.call(await _until(func(): return done[0]), "the flashback ends")
	_check.call(p.camera.current and not home.visible and home.find_children("Crew*", "", false, false).is_empty(), "back to the present: the player's own view, the garage hidden again")
	_check.call(_game().book_words.has("SELECT") and _game().book_words.has("FROM"), "SELECT, FROM and the semicolon are learned")
	await h.run("easy_sql_1")
	_check.call(not h.is_running(), "a chapter is only read once per run")
	world.queue_free()
	await _frames(2)


func test_coop_huddle() -> void:
	print("Huddle: co-op, two players vote together")
	_game().new_run(23)
	_game().open_at_home = true
	var worlds: Array = await _tree._coop_worlds(1)
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/world.tscn")
	var host = machines[0]
	var client = machines[1]
	_check.call(machines.all(func(w): return w.current == w.home), "both machines open in the garage")
	var hh = _huddle_of(host)
	var hc = _huddle_of(client)
	hh.reveal_scale = 0.2
	# One Net autoload serves both machines here: whatever the host grants itself lands
	# straight away, so swap in the client's profile before its grant arrives.
	var net := _tree.root.get_node("Net")
	var test_profile = net.profile
	var host_prof := Profile.new()
	var client_prof := Profile.new()
	net.profile = host_prof
	host.home.sync.event("_on_bag", [client.multiplayer.get_unique_id()])
	net.profile = client_prof
	_check.call(await _until(func(): return not client.home.book_bag.visible, 120) and client_prof.earned.has("achievement:book_easy_sql"), "the player who picks up the book earns its cover")
	_check.call(not host_prof.earned.has("achievement:book_easy_sql") and not host.home.book_bag.visible, "a teammate who didn't pick it up doesn't, and the bag is gone for them too")
	net.profile = Profile.new()
	var runs := [0]
	for h in [hh, hc]:
		var run_it := func():
			await h.run("easy_sql_0", "here")
			runs[0] += 1
		run_it.call()
	_check.call(await _until(func(): return hc.is_running() and hh.is_running(), 300), "the huddle opens on both machines")
	_check.call(hh.is_reader() and not hc.is_reader(), "one player reads (the host, for chapter 0)")
	_check.call(hh.crew.size() == 2 and hc.crew == hh.crew, "the whole crew is in the huddle")
	_check.call(host.player.input_locked and client.player.input_locked, "nobody can walk out of it: everyone is held at the book")
	hc.turn_page()
	await _frames(10)
	_check.call(hh.page == 0, "only the reader turns the page")
	while hh.question < 0:
		hh.turn_page()
		await _frames(5)
	await _frames(5)
	_check.call(hc.question == 0, "both see the quiz start")
	_answer(hh, true)
	await _frames(10)
	_check.call(hh.result.is_empty() and hc.votes.size() == 1, "one vote in of two: the crew waits for the other")
	_answer(hc, false)
	_check.call(await _until(func(): return hc.result.has("split"), 120), "a one-one split asks the crew to talk it over")
	_check.call(await _until(func(): return hc.result.is_empty() and hc.votes.is_empty(), 300) and hc.question == 0, "and vote again")
	_answer(hc, true)
	await _frames(10)
	_answer(hc, false)  # changes their mind before everyone's in
	await _frames(10)
	var q: Dictionary = hh.current_question()
	_check.call(hh.votes.get(client.multiplayer.get_unique_id(), -1) != q.answer, "a player can change their vote until everyone has voted")
	_answer(hc, true)
	await _frames(10)
	_answer(hh, true)
	_check.call(await _until(func(): return hc.result.get("right", false), 120), "both right: everyone sees it marked right")
	_check.call(await _until(func(): return hh.question == 1 and hc.question == 1, 300), "and both move on together")
	for i in hh.chapter.quiz.size() - 1:
		await _until(func(): return hh.result.is_empty() and hc.result.is_empty() and hc.question == hh.question and hh.question >= 1, 300)
		_answer(hc, true)
		await _frames(10)
		_answer(hh, true)
		await _until(func(): return not hh.result.is_empty(), 120)
		await _until(func(): return hh.result.is_empty(), 300)
	# The chapter's closing page, turned by whoever is reading.
	for i in 20:
		for h in [hh, hc]:
			if h.is_running() and h.question < 0:
				h.turn_page()
		await _frames(5)
	var ended := await _until(func(): return runs[0] == 2, 600)
	if not ended:
		print("    host q=%d result=%s votes=%s done=%s / client q=%d done=%s runs=%d" % [hh.question, hh.result, hh.votes, hh.done, hc.question, hc.done, runs[0]])
	_check.call(ended, "the chapter ends on both machines")
	_check.call(net.profile.earned.has("chapter:easy_sql_0"), "the players in the huddle have the chapter on their profiles")
	net.profile = test_profile
	_tree._coop_close(worlds)
	await _frames(2)


func test_coop_spar() -> void:
	print("Home base: co-op, everyone blocks the punch bag")
	_game().new_run(24)
	_game().open_at_home = true
	var worlds: Array = await _tree._coop_worlds(1)
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/world.tscn")
	var homes := machines.map(func(w): return w.home)
	var done := [0]
	for home in homes:
		var drill := func():
			await home._spar_drill()
			done[0] += 1
		drill.call()
	var ph = machines[0].player
	var pc = machines[1].player
	var host_id: int = machines[0].multiplayer.get_unique_id()
	var client_id: int = machines[1].multiplayer.get_unique_id()
	ph.global_position = homes[0].to_global(homes[0].PUNCH_BAG + Vector3(1.0, 0.2, 0.8))
	_check.call(await _until(func(): return homes[1].spar_target == host_id, 400), "the client sees the bag swing at the host")
	await _until(func(): return homes[0].swing_in, 120)
	await _frames(2)
	ph.combat.raise_guard()
	_check.call(await _until(func(): return homes[1].spar_blocked.has(host_id), 200), "the host's block counts on both machines")
	await _frames(60)
	_check.call(done[0] == 0, "one block isn't enough: the drill waits for the whole crew")
	pc.global_position = homes[1].to_global(homes[1].PUNCH_BAG + Vector3(-1.0, 0.2, 0.8))
	_check.call(await _until(func(): return homes[1].spar_target == client_id and homes[1].swing_in, 600), "then it swings at the client")
	await _frames(2)
	pc.combat.raise_guard()
	_check.call(await _until(func(): return done[0] == 2, 400), "the client blocks it, and both machines move on")
	_tree._coop_close(worlds)
	await _frames(2)


func test_coop_walk_in() -> void:
	print("Home base: co-op, the crew walks in and reads the work order")
	_game().new_run(25)
	_game().open_at_home = true
	var worlds: Array = await _tree._coop_worlds(1)
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/world.tscn")
	var homes := machines.map(func(w): return w.home)
	var ph = machines[0].player
	var pc = machines[1].player
	_check.call(homes[1].find_children("WalkIn*", "", false, false).size() == 2, "every machine sees the whole crew out front")
	_check.call(await _until(func(): return ph.is_sitting() and pc.is_sitting(), 1500), "everyone walks in and ends up seated")
	_check.call(ph.seat == homes[0].crew_seats[0] and pc.seat == homes[1].crew_seats[1], "each player in a seat of their own")
	var client_id: int = machines[1].multiplayer.get_unique_id()
	homes[1]._on_notebook_opened()  # as at the work-order beat, when the notebook comes out
	_check.call(await _until(func(): return homes[0].read_order.has(client_id) and homes[1].read_order.has(client_id), 120), "a client pulling out their notebook counts on every machine")
	_check.call(homes[0].read_order.size() == 1, "one look isn't the whole crew")
	homes[0]._on_notebook_opened()
	_check.call(await _until(func(): return homes[1].read_order.size() == 2, 120), "then the host's look completes it")
	_tree._coop_close(worlds)
	await _frames(2)
