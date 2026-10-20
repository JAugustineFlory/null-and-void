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
	Engine.time_scale = 1.0


func _game() -> Node:
	return _tree.root.get_node("Game")


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
		ok = ok and ch.pages.size() > 0 and ch.quiz.size() == 3
		for q in ch.quiz:
			ok = ok and q.answer >= 0 and q.answer < q.options.size() and q.why != ""
	_check.call(ok and Books.chapter_ids().size() >= 2, "every chapter has pages and a three-question check with a reason for its answer")
	_check.call(words_ok, "every chapter brings at most three new words")
	var ch1 := Books.chapter("easy_sql_1")
	_check.call(ch1.book == "EASY SQL" and ch1.words.has("SELECT") and ch1.pages[0].contains("SELECT columns FROM table;"), "chapter 1 shows the shape of a query and its semicolon")
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
		var text := JSON.stringify(Books.chapter(id))
		for t in ["memo_fragments", "door_controllers", "staff", "visitors", "doors", "guards"]:
			if text.contains(t):
				leaks.append("%s: %s" % [id, t])
	_check.call(leaks.is_empty(), "the book only uses its own example table %s" % [leaks])
	var l0 := FileAccess.get_file_as_string("res://scripts/levels/level_0.gd")
	var at_huddle := l0.find("run(\"easy_sql_1\")")
	_check.call(at_huddle > 0 and at_huddle < l0.find("desk_terminal.enabled = true\n\t_rourke_free"), "Level 0 flashes back to chapter 1 before the desk terminal opens")


## Answer the huddle's current question: right, or a wrong option.
func _answer(h: Huddle, right: bool) -> void:
	var q := h.current_question()
	h.vote(q.answer if right else (q.answer + 1) % q.options.size())


## Read every page and answer every question right (after one wrong answer).
func _finish_chapter(h: Huddle, id: String) -> bool:
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
	var home: HomeBase = world.home
	var p: Player = world.player
	_check.call(home != null and world.current == home and home.active, "a new game opens in the crew's garage")
	_check.call(home.global_position.distance_to(Vector3.ZERO) > 200.0, "the garage sits far from the tower")
	_check.call(world.wings.has("level_0") and not world.wings["level_0"].active, "the ground floor is built ahead, waiting for the van")
	_check.call(p.global_position.distance_to(home.spawn_point().origin) < 1.0 and not p.input_locked, "the player starts on the garage floor, free to walk")
	_check.call(not home.fax.enabled and not home.van_door.enabled, "nothing to do until dispatch calls")
	_check.call(await _until(func(): return home.fax.enabled), "dispatch's call puts the work order on the fax")
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
	p.global_position = home.to_global(HomeBase.BENCH + Vector3(0, 0.2, 1.2))
	var h: Huddle = Huddle.of(home)
	h.reveal_scale = 0.2
	_check.call(await _until(func(): return h.is_running()), "the crew at the workbench opens the book")
	_check.call(h.chapter.id == "easy_sql_0" and h.is_reader() and p.input_locked, "solo, you read the first chapter, standing still")
	var ui: HuddleUI = h.get_node_or_null("HuddleUI")
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
	home.van_door.interact(p)
	await _frames(3)
	_check.call(p.seated and home.to_local(p.global_position).distance_to(home.van_seats[0]) < 0.3, "the player takes a seat in the van")
	var lobby = world.wings["level_0"]
	_check.call(await _until(func(): return world.current == lobby and lobby.active), "the drive ends at Halcyon: play moves to the ground floor")
	_check.call(p.global_position.z > 14.0 and p.global_position.y > 0.3 and p.seated, "the crew arrives sitting in the van in the car park")
	_check.call(not home.visible and is_instance_valid(home), "the garage stays loaded, out of sight, for flashbacks")
	world.queue_free()
	await _frames(2)


func test_flashback() -> void:
	print("Huddle: a flashback from the building")
	_game().new_run(22)
	var world = load("res://scenes/world.tscn").instantiate()
	_tree.root.add_child(world)
	await _frames(30)
	var p: Player = world.player
	var h: Huddle = Huddle.of(world.current)
	h.reveal_scale = 0.2
	_check.call(world.home == null and h != null, "a game started in the van has no garage until a flashback needs one")
	var done := [false]
	var run_it := func():
		await h.run("easy_sql_1")
		done[0] = true
	run_it.call()
	_check.call(await _until(func(): return h.is_running() and h.get_node_or_null("HuddleUI") != null), "the flashback opens the book")
	var home: HomeBase = world.get_node_or_null("HomeBase")
	_check.call(home != null and home.visible and home.flashback_camera.current, "it cuts to the garage through the flashback camera")
	_check.call(home.find_children("Crew*", "", false, false).size() == 1, "solo, one crew member stands at the bench")
	_check.call(h.get_node("HuddleUI").flashback and p.input_locked, "in sepia, with the player held still")
	_check.call(await _finish_chapter(h, "easy_sql_1"), "the crew reads chapter 1 and answers its check")
	_check.call(await _until(func(): return done[0]), "the flashback ends")
	_check.call(p.camera.current and not home.visible and home.find_children("Crew*", "", false, false).is_empty(), "back to the present: the player's own view, the garage hidden again")
	_check.call(_game().book_words.has("SELECT") and _game().book_words.has(";"), "SELECT, FROM and the semicolon are learned")
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
	_check.call(machines.all(func(w): return w.current is HomeBase), "both machines open in the garage")
	var hh: Huddle = Huddle.of(host)
	var hc: Huddle = Huddle.of(client)
	hh.reveal_scale = 0.2
	var runs := [0]
	for h in [hh, hc]:
		var run_it := func():
			await h.run("easy_sql_0", Huddle.HERE)
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
	var q := hh.current_question()
	_check.call(hh.votes.get(client.multiplayer.get_unique_id(), -1) != q.answer, "a player can change their vote until everyone has voted")
	_answer(hc, true)
	await _frames(10)
	_answer(hh, true)
	_check.call(await _until(func(): return hc.result.get("right", false), 120), "both right: everyone sees it marked right")
	_check.call(await _until(func(): return hh.question == 1 and hc.question == 1, 300), "and both move on together")
	for i in 2:
		await _until(func(): return hh.result.is_empty() and hh.question >= 1, 300)
		_answer(hc, true)
		await _frames(10)
		_answer(hh, true)
		await _until(func(): return not hh.result.is_empty(), 120)
		await _until(func(): return hh.result.is_empty(), 300)
	_check.call(await _until(func(): return runs[0] == 2, 600), "the chapter ends on both machines")
	_tree._coop_close(worlds)
	await _frames(2)
