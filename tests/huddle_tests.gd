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
	Engine.time_scale = 4.0
	await test_garage_opening()
	await test_flashback()
	await test_coop_huddle()
	await test_coop_spar()
	Engine.time_scale = 1.0


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
	_check.call(ok and Books.chapter_ids().size() == 14, "all 14 chapters have pages and three questions for each new word (three for a review)")
	_check.call(words_ok, "every chapter brings at most three new words")
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
		if h.question >= 0 and h.result.is_empty() and not h.votes.has(h.multiplayer.get_unique_id()):
			_answer(h, not first_wrong)
			first_wrong = false
		await _frames(2)
	return true


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
	_check.call(p.global_position.distance_to(home.spawn_point().origin) < 1.0 and not p.input_locked, "the player starts on the garage floor, free to walk")
	_check.call(not home.fax.enabled and not home.van_door.enabled, "nothing to do until dispatch calls")
	var mad: Node3D = home.maddison
	_check.call(mad != null and mad.get_node_or_null("Look") != null and (_at_mark(home, "door") or home.maddison_mark == "greet"), "Maddison is in the garage in person, in from the side door")
	_check.call(await _until(func(): return home.fax.enabled), "dispatch's call puts the work order on the fax")
	_check.call(await _until(func(): return _at_mark(home, "fax"), 300), "Maddison walks over to the fax as the work order comes through")
	home.fax.interact(p)
	_check.call(await _until(func(): return home.book_bag.enabled), "then the book in the back corner")
	var bag_light := 0.0
	for id in home.lights:
		for l in home.lights[id]:
			var d: float = l.global_position.distance_to(home.book_bag.global_position)
			bag_light = maxf(bag_light, l.omni_range - d)
	_check.call(bag_light < 0.5, "the back corner is out of the lights' reach, under its dead bulb (%.1f m)" % bag_light)
	home.book_bag.interact(p)
	await _frames(5)
	_check.call(home.bench_book.visible and not home.book_bag.visible, "the book ends up on the workbench")
	_check.call(await _until(func(): return _at_mark(home, "bench"), 300), "and round to the end of the workbench while they fetch the book")
	await _spar(home, p)
	p.global_position = home.to_global(home.BENCH + Vector3(0, 0.2, 1.2))
	var h = _huddle_of(home)
	h.reveal_scale = 0.2
	_check.call(await _until(func(): return h.is_running()), "the crew at the workbench opens the book")
	_check.call(h.chapter.id == "easy_sql_0" and h.is_reader() and p.input_locked, "solo, you read the first chapter, standing still")
	var ui = h.get_node_or_null("HuddleUI")
	_check.call(ui != null and not ui.flashback and ui.find_child("Next", true, false).visible, "the book opens over the garage with a page-turn for the reader")
	h.turn_page(-1)
	await _frames(2)
	_check.call(h.page == 0, "the reader can't turn back from the first page")
	while h.question < 0:
		h.turn_page()
		await _frames(2)
	_check.call(h.question == 0 and ui.find_children("Option*", "", true, false).size() == 3, "after the last page, the quiz: three answers to pick from")
	_answer(h, false)
	await _frames(3)
	_check.call(h.result.has("choice") and not h.result.right, "a wrong answer says why")
	_check.call(await _until(func(): return h.result.is_empty()) and h.question == 0, "and the same question comes back")
	_answer(h, true)
	await _frames(3)
	_check.call(h.result.get("right", false), "the right answer is marked right")
	_check.call(await _until(func(): return h.question == 1), "then the next question")
	_check.call(await _finish_chapter(h, "easy_sql_0"), "the crew finishes the chapter")
	_check.call(_game().book_words.has("row"), "its words are learned")
	_check.call(await _until(func(): return not p.input_locked and h.get_node_or_null("HuddleUI") == null), "the book closes and the player can move again")
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
	_check.call(home.find_children("Crew*", "", false, false).size() == 1, "solo, one crew member stands at the bench")
	_check.call(_at_mark(home, "bench"), "Maddison is at the end of the bench, facing it")
	var spots: Array = home.HUDDLE_SPOTS.duplicate()
	spots.append(home.MADDISON_MARKS.bench[0])
	var crowded := false
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			crowded = crowded or spots[i].distance_to(spots[j]) < 0.8
	var bench_box := AABB(home.BENCH - Vector3(1.2, 0, 0.5), Vector3(2.4, 1, 1.0)).grow(0.25)
	_check.call(not crowded and spots.all(func(v): return not bench_box.has_point(v + Vector3(0, 0.5, 0))), "six crew and Maddison all have room round the bench")
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
	var runs := [0]
	for h in [hh, hc]:
		var run_it := func():
			await h.run("easy_sql_0", "here")
			runs[0] += 1
		run_it.call()
	_check.call(await _until(func(): return hc.is_running() and hh.is_running(), 300), "the huddle opens on both machines")
	_check.call(hh.is_reader() and not hc.is_reader(), "one player reads (the host, for chapter 0)")
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
	var ended := await _until(func(): return runs[0] == 2, 600)
	if not ended:
		print("    host q=%d result=%s votes=%s done=%s / client q=%d done=%s runs=%d" % [hh.question, hh.result, hh.votes, hh.done, hc.question, hc.done, runs[0]])
	_check.call(ended, "the chapter ends on both machines")
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
