extends RefCounted
## The case in the corner (CaseChip, "CURRENT CASE") on every floor and for every
## player (Augustine, v0.8-beta1 co-op playtest: it disappeared after the first
## floors, and only the host seemed to have the current case).

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	await test_every_floor_shows_its_case()
	await test_coop_cases_shared()


func _game() -> Node:
	return _tree.root.get_node("/root/Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree.physics_frame


## Every paper on every floor that opens a case, read on its own: the corner then
## shows that case, whether or not it has pieces to find. Floor 22 opens its cases
## from the story rather than from a paper, so its first case is opened directly.
func test_every_floor_shows_its_case() -> void:
	print("Every floor's cases show in the corner")
	var missing: Array[String] = []
	var floors := 0
	var cases := 0
	var i := 0
	while ResourceLoader.exists("res://scenes/level_%d.tscn" % i):
		_game().new_run(5)
		var level = load("res://scenes/level_%d.tscn" % i).instantiate()
		_tree.root.add_child(level)
		await _frames(10)
		var chip: CaseChip = level.hud.case_chip
		var openers: Array = level.find_children("*", "Document", true, false).filter(func(d): return d.clues.any(func(k): return k.has("opens")))
		var seen := {}
		for d in openers:
			var opens: Array = d.clues.filter(func(k): return k.has("opens")).map(func(k): return k.case)
			if seen.has(str(opens)):
				continue
			seen[str(opens)] = true
			_game().notebook_cases.clear()
			_game().notebook_changed.emit()
			d.open_reader(level.player).close()
			await _frames(2)
			cases += 1
			if not (chip.chip.visible and chip.case_id in opens and chip.title.text != ""):
				missing.append("level %d \"%s\" (%s)" % [i, d.title, ", ".join(opens)])
		if openers.is_empty() and level.get("CASES") != null:
			var first: String = level.CASES.keys()[0]
			_game().notebook_cases.clear()
			_game().open_case(first, level.CASES[first])
			await _frames(2)
			cases += 1
			if not (chip.chip.visible and chip.case_id == first):
				missing.append("level %d case %s" % [i, first])
		floors += 1
		level.queue_free()
		await _tree.process_frame
		i += 1
	_check.call(floors >= 6 and cases >= 12, "checked the cases on every floor (%d floors, %d cases)" % [floors, cases])
	_check.call(missing.is_empty(), "once a floor's case is open, the corner shows it, pieces or not%s" % ("" if missing.is_empty() else " (not: %s)" % ", ".join(missing)))


## Two machines on floor 14: a paper that opens a case, read by either player,
## opens it on every machine (the host runs it everywhere), and both corners
## show it. Each machine's copy of the paper opens a marker case of its own, so
## the test sees which machines ran it (Game is shared in the test process).
func test_coop_cases_shared() -> void:
	print("Co-op: a case opened by reading a paper opens for everyone")
	_game().new_run(5)
	var worlds: Array = await (_tree as Variant)._coop_worlds(1)
	var levels: Array = await (_tree as Variant)._coop_load(worlds, "res://scenes/level_1.tscn")
	(_tree as Variant)._lower_chapters_read(levels)
	var host = levels[0]
	var c1 = levels[1]
	var host_doc: Document = host.find_children("*", "Document", true, false).filter(func(d): return d.clues.any(func(k): return k.get("case", "") == "dark_room" and k.has("opens")))[0]
	var client_doc: Document = c1.get_node(host.get_path_to(host_doc))
	host_doc.clues.append({"case": "on_host", "opens": "marker", "text": "marker"})
	client_doc.clues.append({"case": "on_client", "opens": "marker", "text": "marker"})
	_game().notebook_cases.clear()
	_game().notebook_changed.emit()
	client_doc.open_reader(c1.player).close()
	await _frames(15)
	_check.call(_game().case_info("on_host").get("open", false), "a paper a client reads opens its case on the host's machine too")
	_check.call(host.hud.case_chip.chip.visible and c1.hud.case_chip.chip.visible and host.hud.case_chip.case_id == c1.hud.case_chip.case_id, "and the host's corner shows the same case as the client's (%s / %s)" % [host.hud.case_chip.case_id, c1.hud.case_chip.case_id])
	_game().notebook_cases.clear()
	_game().notebook_changed.emit()
	host_doc.open_reader(host.player).close()
	await _frames(15)
	_check.call(_game().case_info("on_client").get("open", false), "one the host reads opens on the client's machine")
	_check.call(host.hud.case_chip.chip.visible and c1.hud.case_chip.chip.visible and host.hud.case_chip.case_id == c1.hud.case_chip.case_id, "and both corners show it")
	await (_tree as Variant)._coop_close(worlds)
