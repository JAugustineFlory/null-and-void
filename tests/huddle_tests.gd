extends RefCounted
## The garage home base and the crew's book huddles (scripts/huddle/,
## scripts/levels/home_base.gd): the book's data, the opening in the garage,
## a chapter coming in up in the building, and in co-op.

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
	await test_chapter_in_building()
	test_lead_ins_wired()
	await test_lead_ins()
	await test_coop_huddle()
	await test_coop_spar()
	await test_coop_walk_in()
	await test_coop_van()
	Engine.time_scale = 1.0
	net.profile = real_profile


func _game() -> Node:
	return _tree.root.get_node("Game")


func _net() -> Node:
	return _tree.root.get_node("Net")


## Huddle and HomeBase aren't named as classes here: they pull in
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
	_check.call(ok and Books.book_chapter_ids("easy_sql").size() == 19 and Books.chapter_ids().size() == 24, "all 24 chapters (Easy SQL's 19, Acceptable API's 5) have pages and three questions for each new word (three for a review)")
	var ids := Books.book_chapter_ids("easy_sql")
	_check.call(ids.slice(15, 17) == ["easy_sql_distinct", "easy_sql_group_by"] and Books.chapter("easy_sql_distinct").number == 15 and Books.chapter("easy_sql_group_by").words == ["GROUP BY"],
		"floor 18's chapters come next, numbered by their place in it")
	_check.call(ids.slice(17) == ["easy_sql_update", "easy_sql_insert"] and Books.chapter("easy_sql_update").number == 17 and Books.chapter("easy_sql_insert").number == 18
		and Books.rounds(Books.chapter("easy_sql_update")).size() == 3 and Books.rounds(Books.chapter("easy_sql_insert")).size() == 3,
		"floor 10's UPDATE and INSERT chapters close the book, read a word at a time")
	_check.call(ids[9] == "easy_sql_count" and Books.chapter("easy_sql_count").words == ["COUNT(*)"] and Books.chapter("easy_sql_9").number == 10,
		"How many? (COUNT) follows Chapter 8, and the chapters after it move up one")
	_check.call(Books.chapter("easy_sql_4").words == ["DESC", "LIMIT"], "Newest first teaches LIMIT after DESC")
	_check.call(words_ok, "every chapter brings at most three new words")
	var whys := true
	for id in Books.chapter_ids():
		for q in Books.chapter(id).quiz:
			whys = whys and String(q.why) != ""
	_check.call(whys, "every question says why after an answer, right or wrong")
	var ch0 := Books.chapter("easy_sql_0")
	_check.call(ch0.pages[0].contains("A table's name is all one word") and ch0.quiz[1].why.contains("A space would split the name"),
		"chapter 0 says a table's name is one word before it asks which looks like one, and says why after")
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
	var at_huddle := l0.find("run(\"easy_sql_1\"")
	_check.call(at_huddle > 0 and at_huddle < l0.find("desk_terminal.enabled = true\n\t_rourke_free"), "Level 0 brings in chapter 1 before the desk terminal opens")


## Until chapter `id` is in the crew's book and Maddison's lines for it are over.
func _finish_chapter(h, id: String) -> bool:
	return await _until(func(): return h.done.has(id) and not h.is_busy(), 1800)


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
	var bar: Node3D = home.geo.get_node_or_null("BagStandBar")
	_check.call(bar != null and home.geo.get_node_or_null("BagStandPostW") != null and absf(home.punch_bag.global_position.y - bar.global_position.y) < 0.1,
		"the punch bag hangs from the top bar of its own stand, not from thin air")
	_check.call(await _until(func(): return _at_mark(home, "board"), 600), "she comes in from the house to her whiteboard")
	var through := []
	for pair in [["door", "board"], ["board", "side"], ["side", "board"], ["board", "van"]]:
		through.append_array(_walks_through(home, home.MADDISON_MARKS[pair[0]][0], home.MADDISON_MARKS[pair[1]][0]))
	_check.call(through.is_empty(), "she walks round the couch, the counter and the bench, never through them %s" % [through])
	_check.call(await _until(func(): return home.hud.current_todo() == home.SPAR_TODO, 2400), "after the brief she sends the crew to the punch bag")
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
	var h = _huddle_of(home)
	var came := await _until(func(): return h.done.has("easy_sql_0"), 1200)
	_check.call(came and home.held_book == null and _game().book_chapters == ["easy_sql_0"], "after Maddison's line, chapter zero goes in your notebook: nobody sits down to read it")
	var popped := false
	var locked := false
	while h.is_busy():
		popped = popped or h.get_node_or_null("HuddleUI") != null or home.flashback_camera.current
		locked = locked or p.input_locked
		await _frames(2)
	_check.call(not popped and not locked, "no book pops up and nobody is held still: you can walk about while she talks")
	_check.call(home.hud._notice.text == h.NOTICE % ["Easy SQL", 0, "Read this first"] or home.hud._notice.text.begins_with("New in Easy SQL"), "a notice says it's new in the book, and where to read it")
	_check.call(_game().book_words.has("row"), "its words are learned")
	_check.call(prof.earned.has("chapter:easy_sql_0") and not prof.earned.has("achievement:easy_sql_half"), "the chapter is remembered on the profile; one chapter isn't half the book")
	await _test_yourself(world)
	_check.call(await _until(func(): return home.van_door.enabled), "then the van")
	_check.call(await _until(func(): return _at_mark(home, "van"), 300), "Maddison sees the crew off at the van door")
	_check.call(home.van_doors.size() == 2 and home.side_door.find_child("SideDoor", true, false) != null, "the garage's van has the same doors as the van at Halcyon: two front doors and a sliding door")
	_check.call(await _until(func(): return home.side_door.position.distance_to(home.SIDE_DOOR_OPEN) < 0.05, 120), "its sliding door slides back to let the crew in")
	home.van_door.interact(p)
	await _frames(3)
	_check.call(p.seated and home.to_local(p.global_position).distance_to(home.van_seats[0]) < 0.3, "the player takes a seat in the van")
	var lobby = world.wings["level_0"]
	_check.call(await _until(func(): return world.current == lobby and lobby.active), "the drive ends at Halcyon: play moves to the ground floor")
	_check.call(p.global_position.z > 14.0 and p.global_position.y > 0.3 and p.seated, "the crew arrives sitting in the van in the car park")
	_check.call(not home.visible and is_instance_valid(home), "the garage stays loaded, out of sight")
	world.queue_free()
	await _frames(2)


## The notebook's Books tab after chapter zero: the chapter to read when you like, and
## its quick checks to test yourself on, with the page beside each question.
func _test_yourself(world) -> void:
	var nb = world.notebook
	_check.call(nb.open(), "the notebook opens after the huddle")
	var pages = nb.pages
	pages.show_page(pages.TAB_NAMES.find("Books"))
	await _frames(2)
	var chap: Button = _book_item(pages, "Chapter_easy_sql_0")
	_check.call(chap != null and _game().book_chapters == ["easy_sql_0"], "the chapter is in the notebook's Books tab")
	chap.pressed.emit()
	await _frames(3)
	_check.call(_book_pages(pages).size() == 3 and _book_item(pages, "TestYourself") != null, "its pages are there to read, with Test yourself under them")
	_check.call(_book_pages(pages)[1].text.contains("job_no") and _book_pages(pages)[1].text.contains("[font_size="), "the jobs table is in typewriter text, sized to fit the page")
	_book_item(pages, "TestYourself").pressed.emit()
	await _frames(3)
	var quiz = pages.quiz
	var refs: String = "\n".join(_book_pages(pages).map(func(b): return b.text))
	_check.call(quiz != null and quiz.at == 0 and _book_items(pages, "Option*").size() == 3, "Test yourself asks the chapter's first quick check, three answers to pick from")
	_check.call(refs.contains("job_no") and refs.contains("ladder | 1"), "\"What are jobs and van_kit?\" shows both tables beside it")
	var right: int = quiz.question().answer
	_book_item(pages, "Option%d" % ((right + 1) % 3)).pressed.emit()
	await _frames(3)
	var said: String = pages.text_of(_book_items(pages, "*"))
	_check.call(not quiz.result.right and said.contains("Not quite. Each is a whole table") and _book_item(pages, "BookNext") == null, "a wrong answer says why, and you pick again")
	var check: Control = _book_item(pages, "QuickCheck")
	_check.call(check != null and check.find_children("Option*", "", true, false).size() == 3 and pages.text_of([check]).contains("Not quite") and pages.text_of([check]).contains("What are jobs"),
		"the question, its options and its why stay together on one page")
	_book_item(pages, "Option%d" % right).pressed.emit()
	await _frames(3)
	_check.call(quiz.result.right and _book_item(pages, "BookNext") != null, "the right one is marked right, with the next question to go to")
	_book_item(pages, "BookNext").pressed.emit()
	await _frames(3)
	refs = "\n".join(_book_pages(pages).map(func(b): return b.text))
	_check.call(quiz.at == 1 and refs.contains("job_no") and not refs.contains("ladder"), "van_kit isn't beside \"Which looks like a table name?\": it would give it away")
	_book_item(pages, "BookBack").pressed.emit()
	await _frames(3)
	_check.call(pages.quiz == null and _book_item(pages, "TestYourself") != null, "and you can leave the test for the chapter any time")
	_book_item(pages, "BookContents").pressed.emit()
	await _frames(3)
	var this_run: Array[String] = _game().book_chapters.duplicate()
	_game().book_chapters.clear()  # a later run, resumed or started on another floor
	var earned: bool = _net().profile.earned.has("chapter:easy_sql_0")
	pages.refresh()
	await _frames(2)
	_check.call(earned and _book_item(pages, "Chapter_easy_sql_0") != null, "a run that starts later still has the chapter, from the player's profile")
	_game().book_chapters = this_run
	nb.close()


## Every item on the open notebook section's pages, on any spread, named like `pattern`.
func _book_items(pages, pattern: String) -> Array:
	var found := []
	for spread in pages._spreads:
		for side in spread:
			for item in side:
				if String(item.name).match(pattern):
					found.append(item)
				found.append_array(item.find_children(pattern, "", true, false))
	return found


## The book's printed pages on the open notebook section.
func _book_pages(pages) -> Array:
	return _book_items(pages, "*").filter(func(n): return n is RichTextLabel)


func _book_item(pages, node_name: String) -> Node:
	var found := _book_items(pages, node_name)
	return found[0] if not found.is_empty() else null


## The furniture Maddison's walk from `a` to `b` passes through, if any (her body
## is about 0.2 m round).
func _walks_through(home, a: Vector3, b: Vector3) -> Array:
	var things := {"couch": Rect2(home.COUCH.x - 0.45, -1.6, 0.95, 3.2), "counter": Rect2(home.COUNTER.x - 0.3, -1.7, 0.6, 3.4),
		"bench": Rect2(home.BENCH.x - 1.2, home.BENCH.z - 0.5, 2.4, 1.0)}
	for i in home.CREW_SEATS.size():
		var seat: Vector3 = home.CREW_SEATS[i]
		if seat.y > 0.6:
			things["stool %d" % i] = Rect2(seat.x - 0.18, seat.z - 0.18, 0.36, 0.36)
	var hit := []
	var from := a
	for to in home.maddison_route(a, b):
		for i in ceili(from.distance_to(to) / 0.1) + 1:
			var at: Vector3 = from.lerp(to, minf(1.0, i * 0.1 / maxf(from.distance_to(to), 0.001)))
			for k in things:
				if things[k].grow(0.2).has_point(Vector2(at.x, at.z)) and not hit.has(k):
					hit.append(k)
		from = to
	return hit


## Maddison stands on `mark`, facing the way it says.
func _at_mark(home, mark: String) -> bool:
	var m: Array = home.MADDISON_MARKS[mark]
	var mad: Node3D = home.maddison
	var to: Vector3 = m[1] - mad.position
	var facing := -mad.basis.z
	return mad.position.distance_to(m[0]) < 0.1 and Vector2(facing.x, facing.z).normalized().dot(Vector2(to.x, to.z).normalized()) > 0.95


## The punch bag drill, solo: it only swings back at someone who hits it, a miss
## costs nothing and says why, and a block lets the crew move on to the huddle.
func _spar(home, p) -> void:
	var net: Node = _tree.root.get_node("/root/Net")
	var real_profile = net.profile
	net.profile = Profile.new()  # in memory, so tests never touch a real save
	_check.call(home.punch_bag != null and home.spar_blocked.is_empty(), "then the punch bag, before the huddle")
	_check.call(home.hud.current_todo() == "Hit the punch bag, then block it", "the to-do says to hit it, then block it")
	p.global_position = home.to_global(home.PUNCH_BAG + Vector3(1.0, 0.2, 0.8))
	var swung := await _until(func(): return home.spar_target != 0, 200)
	_check.call(not swung, "the bag hangs still until you hit it, even standing by it")
	await _hit_bag(home, p)
	_check.call(home.spar_target != 0 and not home.swing_in, "hit it and it swings away from you")
	_check.call(await _until(func(): return home.swing_in, 120), "then back in at you")
	var health: float = p.health
	await _until(func(): return not home.swing_in, 120)
	await _frames(3)
	_check.call(p.health == health and home.spar_blocked.is_empty(), "a missed block costs no health, and doesn't count")
	_check.call(home.hud._notice.text.contains("It hit you. Right-click just as it swings in"), "no guard up: the notice says when to right-click")
	_check.call(not _huddle_of(home).is_running(), "the crew can't huddle until it's blocked")
	await _frames(40)  # it settles
	await _hit_bag(home, p)
	var early: bool = home.spar_target != 0 and not home.swing_in and p.combat.raise_guard()  # as it flies away, long before it's back
	await _until(func(): return home.spar_target == 0, 120)
	await _frames(3)
	_check.call(early and home.spar_blocked.is_empty() and home.hud._notice.text.begins_with("Too early"), "a guard raised too soon drops before it lands, and the notice says so")
	await _frames(40)
	await _hit_bag(home, p)
	_check.call(await _until(func(): return home.swing_in, 120), "hit again, it swings back again")
	await _frames(2)  # partway into the swing
	p.combat.raise_guard()
	_check.call(await _until(func(): return home.spar_blocked.size() == 1, 120), "right-clicking as it swings in blocks it")
	_check.call(p.health == health, "blocking it costs nothing either")
	_check.call(not net.profile.earned.has(CrewVitals.FIRST_BLOCK), "and it's practice: the punch bag never earns the High-tops")
	net.profile = real_profile


## Player `p` turns to the bag and throws a punch at it.
func _hit_bag(home, p) -> void:
	var at: Vector3 = home.to_global(home.PUNCH_BAG)
	p.look_at(Vector3(at.x, p.global_position.y, at.z))
	p.head.rotation = Vector3.ZERO
	p._strike_cd = 0.0
	await _frames(2)
	p._strike()
	await _frames(2)


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
	_check.call(n == 19, "Easy SQL has 19 chapters to count")
	var me: int = h.multiplayer.get_unique_id()
	var finish := func(id: String):
		h._complete(id, [me])
	h._complete(ids[n - 1], [me + 1])  # given to a crew this player wasn't in
	_check.call(not prof.earned.has("chapter:" + ids[n - 1]), "a chapter given to a crew you weren't in doesn't count for you")
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


func test_chapter_in_building() -> void:
	print("Huddle: a chapter comes in, up in the building")
	_game().new_run(22)
	var world = load("res://scenes/world.tscn").instantiate()
	_tree.root.add_child(world)
	await _frames(30)
	var p: Player = world.player
	var h = _huddle_of(world.current)
	var cam: Camera3D = world.get_viewport().get_camera_3d()
	p.input_locked = false
	var done := [false]
	var run_it := func():
		await h.run("easy_sql_1")
		done[0] = true
	run_it.call()
	_check.call(await _until(func(): return h.is_running()), "the chapter comes in")
	_check.call(_game().book_chapters.has("easy_sql_1") and world.hud._notice.text.begins_with("New in Easy SQL: Ch. 1, Ask for a table"), "it's in the book, and a notice says so")
	var held := false
	var cut := false
	while not done[0]:
		held = held or p.input_locked
		cut = cut or world.get_viewport().get_camera_3d() != cam
		await _frames(2)
	_check.call(not held and not cut and world.get_node_or_null("HomeBase") == null, "no cut to the garage, and nobody is held still while Maddison's lines play")
	_check.call(_game().book_words.has("SELECT") and _game().book_words.has("FROM"), "SELECT, FROM and the semicolon are learned")
	await h.run("easy_sql_1")
	_check.call(not h.is_running() and _game().book_chapters.count("easy_sql_1") == 1, "a chapter comes once per run")
	world.queue_free()
	await _frames(2)


## Every floor's chapters come in REMEMBERED; the garage's don't (Augustine,
## 2026-10-27: up on the floors Maddison isn't there).
func test_lead_ins_wired() -> void:
	print("Huddle: a crew lead-in before Maddison on every floor, never in the garage")
	var run_re := RegEx.create_from_string("Huddle\\.of\\([^)]*\\)\\.run\\(([^\\n]*)\\)")
	var plain := []
	for f in DirAccess.get_files_at("res://scripts/levels/"):
		if not f.ends_with(".gd"):
			continue
		for m in run_re.search_all(FileAccess.get_file_as_string("res://scripts/levels/" + f)):
			var remembered := m.get_string(1).contains("REMEMBERED")
			if remembered == f.begins_with("home_base"):
				plain.append("%s: run(%s)" % [f, m.get_string(1)])
	_check.call(plain.is_empty(), "every floor level brings its chapters in remembered, and the garage doesn't %s" % [plain])
	var lead_ins: Array = _huddle_class().LEAD_INS
	_check.call(lead_ins.size() == 3 and lead_ins.all(func(id): return VoiceLines.get_line(id).get("speaker") == "CREW"), "three lead-ins, each a crew line every crew member records")


func _huddle_class() -> Script:
	return load("res://scripts/huddle/huddle.gd")


## The subtitles that come up while `run` plays, in order.
func _subtitles(hud, run: Callable) -> Array:
	var seen := []
	var done := [false]
	var go := func():
		await run.call()
		done[0] = true
	go.call()
	while not done[0]:
		var t: String = hud._subtitle.text
		if t != "" and (seen.is_empty() or seen.back() != t):
			seen.append(t)
		await _tree.process_frame
	return seen


## Just the chapters' lines and their lead-ins, from `subtitles` (the van radio
## can be talking at the same time).
func _huddle_lines(subtitles: Array) -> Array:
	var texts := []
	for id in _huddle_class().LEAD_INS:
		texts.append(VoiceLines.get_line(id).text)
	for ch in Books.chapter_ids():
		for id in Books.chapter(ch).lines:
			texts.append(VoiceLines.get_line(id).text)
	return subtitles.filter(func(t): return texts.any(func(x): return t.ends_with(": " + x)))


func test_lead_ins() -> void:
	print("Huddle: up on a floor, one of the crew remembers Maddison's lines")
	_game().new_run(25)
	var world = load("res://scenes/world.tscn").instantiate()
	_tree.root.add_child(world)
	await _frames(30)
	var h = _huddle_of(world.current)
	var hud = world.hud
	var me: String = _net().display_name(world.multiplayer.get_unique_id())
	var remembered: String = _huddle_class().REMEMBERED
	var said := _huddle_lines(await _subtitles(hud, func(): await h.run("easy_sql_1", remembered)))
	var lead: Dictionary = h.leads.get("easy_sql_1", {})
	var first: String = VoiceLines.get_line(lead.get("line", "")).get("text", "?")
	_check.call(said.size() == 3 and said[0] == "%s: %s" % [me, first], "a crew lead-in comes first, in the player's own name %s" % [said])
	_check.call(said.size() == 3 and said[1].begins_with("MADDISON: Chapter one.") and said[2].begins_with("MADDISON: Book says"), "then both of her lines")
	await h.run("easy_sql_2", remembered)
	await h.run("easy_sql_5", remembered)
	var used := ["easy_sql_1", "easy_sql_2", "easy_sql_5"].map(func(id): return h.leads.get(id, {}).get("line", ""))
	_check.call(used[0] != used[1] and used[1] != used[2] and used[0] != used[2] and not used.has(""), "the three lead-ins take turns %s" % [used])
	await h.run("api_codes", remembered)
	_check.call(not h.leads.has("api_codes"), "a chapter without her lines (the crew reads Acceptable API's themselves) gets no lead-in")
	said = _huddle_lines(await _subtitles(hud, func(): await h.run("easy_sql_7")))
	_check.call(not h.leads.has("easy_sql_7") and said.size() == 2 and said.all(func(t): return t.begins_with("MADDISON: ")), "brought in as if she's there (the garage), her lines play with no lead-in")
	world.queue_free()
	await _frames(2)


func test_coop_huddle() -> void:
	print("Huddle: co-op, a chapter comes in for the whole crew")
	_game().new_run(23)
	_game().open_at_home = true
	var worlds: Array = await _tree._coop_worlds(1)
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/world.tscn")
	var host = machines[0]
	var client = machines[1]
	_check.call(machines.all(func(w): return w.current == w.home), "both machines open in the garage")
	var hh = _huddle_of(host)
	var hc = _huddle_of(client)
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
	var held := [host.player.input_locked, client.player.input_locked]
	var runs := [0]
	for h in [hc, hh]:  # the client gets there first: it waits for the host
		var run_it := func():
			await h.run("easy_sql_0")
			runs[0] += 1
		run_it.call()
	_check.call(await _until(func(): return hh.done.has("easy_sql_0") and hc.done.has("easy_sql_0"), 300), "the chapter comes in on both machines")
	_check.call(hh.crew.size() == 2 and hc.crew == hh.crew, "for the whole crew")
	_check.call([host.player.input_locked, client.player.input_locked] == held and hh.get_node_or_null("HuddleUI") == null, "no book pops up, and it holds nobody")
	_check.call(await _until(func(): return runs[0] == 2, 1800), "and both machines carry on once Maddison's lines are over")
	_check.call(net.profile.earned.has("chapter:easy_sql_0"), "the players have the chapter on their profiles")
	_check.call(not hh.leads.has("easy_sql_0") and not hc.leads.has("easy_sql_0"), "in the garage, nobody says a lead-in")
	var remembered: String = _huddle_class().REMEMBERED
	for h in [hc, hh]:
		h.run("easy_sql_1", remembered)
	_check.call(await _until(func(): return hh.leads.has("easy_sql_1") and hc.leads.has("easy_sql_1"), 300), "up on a floor, both machines get the lead-in")
	_check.call(hc.leads["easy_sql_1"] == hh.leads["easy_sql_1"] and hh.crew.has(hh.leads["easy_sql_1"].peer), "the same crew member says the same one on every machine")
	await _until(func(): return not hh.is_busy() and not hc.is_busy(), 1800)
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
	await _hit_bag(homes[0], ph)
	_check.call(await _until(func(): return homes[1].spar_target == host_id, 400), "the host hits the bag, and the client sees it swing back at the host")
	_check.call(homes.all(func(h): return h.punch_bag.get_meta("sounds_played", []).any(func(x): return x.kind == "bag_hit")), "and both machines hear the punch land on it")
	await _until(func(): return homes[0].swing_in, 120)
	await _frames(2)
	ph.combat.raise_guard()
	_check.call(await _until(func(): return homes[1].spar_blocked.has(host_id), 200), "the host's block counts on both machines")
	await _frames(60)
	_check.call(done[0] == 0, "one block isn't enough: the drill waits for the whole crew")
	pc.global_position = homes[1].to_global(homes[1].PUNCH_BAG + Vector3(-1.0, 0.2, 0.8))
	await _frames(30)
	_check.call(homes[1].spar_target == 0, "it doesn't swing at the client until they hit it")
	await _hit_bag(homes[1], pc)
	_check.call(await _until(func(): return homes[1].spar_target == client_id and homes[1].swing_in, 600), "the client's hit reaches the host, and the bag swings back at them")
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


func test_coop_van() -> void:
	print("Home base: co-op, the whole crew gets in the van")
	_game().new_run(26)
	_game().open_at_home = true
	var worlds: Array = await _tree._coop_worlds(1)
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/world.tscn")
	var homes := machines.map(func(w): return w.home)
	var ph = machines[0].player
	var pc = machines[1].player
	var boarded := [false]
	homes[1].crew_boarded.connect(func(): boarded[0] = true)
	homes[0].crew_boarded.connect(func(): boarded[0] = true)
	for home in homes:
		home.van_door.enabled = true
	homes[0].van_door.interact(ph)
	_check.call(await _until(func(): return homes[1].boarded.size() == 1, 120), "the host climbs in first")
	homes[1].van_door.interact(pc)
	_check.call(await _until(func(): return homes[0].boarded.size() == 2 and homes[1].boarded.size() == 2, 120),
		"and the client still can after them")
	_check.call(boarded[0] and not homes[0].van_door.enabled and not homes[1].van_door.enabled, "then the van leaves with everyone")
	_tree._coop_close(worlds)
	await _frames(2)
