extends RefCounted
## Every paper on every floor, picked up and read at 16:9, shows all of what's on
## it: its last line is on the paper (not cut off by the page's edge) and on the
## screen (Augustine, v0.8-beta1 playtest: the records archive's reader tally ran
## off the bottom of its card).

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	await test_every_paper_fits()


func _game() -> Node:
	return _tree.root.get_node("/root/Game")


func test_every_paper_fits() -> void:
	print("Every paper on every floor shows its last line when read")
	var papers := await _every_paper()
	_check.call(papers.size() > 40, "found the papers on every floor (%d different ones)" % papers.size())
	var was_size: Vector2i = _tree.root.size
	_tree.root.size = Vector2i(1600, 900)
	var was_diegetic: bool = _game().diegetic_ui
	_game().new_run(5)
	_game().diegetic_ui = true
	var level = load("res://scenes/level_0.tscn").instantiate()
	_tree.root.add_child(level)
	for i in 10:
		await _tree.physics_frame
	var p: Player = level.player
	level._release_camera(p)
	p.seated = false
	p.global_position = Vector3(1.0, 0.1, -1.9)
	p.rotation.y = 0.0
	for i in 10:
		await _tree.physics_frame
	var cut: Array[String] = []
	var small: Array[String] = []
	var smallest := 1.0
	for spec in papers:
		var doc := Document.place(level.geo, p.global_position + Vector3(0, 0.8 if spec.flat else 1.5, -0.6), 180.0, spec.title, spec.lines, spec.flat, spec.look, spec.size)
		await _tree.physics_frame
		var reader := doc.pick_up(p)
		if reader == null:
			cut.append("%s: couldn't be picked up" % spec.where)
			doc.queue_free()
			continue
		for i in 90:
			if p._prop_settled():
				break
			await _tree.physics_frame
		for i in 4:  # the page lays out, fits and comes closer if it's printed small
			await _tree.process_frame
		await _tree.physics_frame
		var problem := ""
		var screen := Rect2(Vector2.ZERO, Vector2(1600, 900)).grow(1.0)
		if reader._labels.is_empty():
			var view := reader.page_viewport.get_child(0) as DocumentView
			var room: Rect2 = DocumentView.PAPERS[doc.paper_kind()].body
			var rows := view.body.get_children().filter(func(c): return c is Control and c.visible)
			var first: Rect2 = (rows[0] as Control).get_global_rect()
			var last: Rect2 = (rows[-1] as Control).get_global_rect()
			if last.end.y > room.end.y + 1.0:
				problem = "its last line runs %d px past the bottom of the page" % (last.end.y - room.end.y)
			for at in [first.position, Vector2(last.position.x, last.end.y), Vector2(room.end.x, last.end.y)]:
				if problem == "" and not screen.has_point(_page_to_screen(reader, p, at)):
					problem = "its page is off the screen at %s" % _page_to_screen(reader, p, at)
			if view.fit_scale < 0.95:
				small.append("%s (%.2f)" % [spec.where, view.fit_scale])
			smallest = minf(smallest, view.fit_scale)
		else:
			# Big print on a wall sheet: read off its own labels.
			var sheet_bottom := -doc.read_size.y / 2.0
			var last: Label3D = reader._labels[0]
			for l in reader._labels:
				if l.get_meta("line_index") > last.get_meta("line_index"):
					last = l
			var box := last.get_aabb()
			var face: Node3D = doc.get_node("WallSheet")
			for i in 8:
				var corner := last.global_transform * box.get_endpoint(i)
				if problem == "" and (face.global_transform.affine_inverse() * corner).y < sheet_bottom - 0.002:
					problem = "its last line runs off the bottom of the sheet"
				if problem == "" and (p.camera.is_position_behind(corner) or not screen.has_point(p.camera.unproject_position(corner))):
					problem = "its last line is off the screen at %s" % p.camera.unproject_position(corner)
		p.put_down(true)
		for i in 10:
			if p.held_prop == null and not is_instance_valid(reader):
				break
			await _tree.physics_frame
		# The full-screen page (Game.diegetic_ui off) shows it all too.
		if problem == "":
			var full := doc.open_reader(p)
			await _tree.create_timer(0.3).timeout  # it lifts into view
			var rows := full.view.body.get_children().filter(func(c): return c is Control and c.visible)
			var last: Rect2 = (rows[-1] as Control).get_global_rect()
			var page: Rect2 = full.view.paper.get_global_rect()
			var room: Rect2 = DocumentView.PAPERS[doc.paper_kind()].body
			var room_bottom := page.position.y + room.end.y * full.view.paper.scale.y
			if last.end.y > room_bottom + 1.0 or not screen.encloses(page):
				problem = "full screen, its last line ends at %d, past the page's %d (page %s)" % [last.end.y, room_bottom, page]
			full.close()
			await _tree.process_frame
		if problem != "":
			cut.append("%s: %s" % [spec.where, problem])
		doc.queue_free()
	_check.call(cut.is_empty(), "every paper read at 16:9 shows its last line, on the page and on the screen%s" % ("" if cut.is_empty() else " (not: %s)" % "; ".join(cut)))
	_check.call(smallest > 0.6, "a page with too much on it is printed smaller to fit, but stays readable (smallest print %.2f; printed small: %s)" % [smallest, ", ".join(small) if not small.is_empty() else "none"])
	level.queue_free()
	_game().diegetic_ui = was_diegetic
	_tree.root.size = was_size
	await _tree.process_frame


## A point on the held page's image (its DocumentView's pixels) on the screen.
func _page_to_screen(reader: DocumentReader, p: Player, at: Vector2) -> Vector2:
	var px := Vector2(reader.page_viewport.size)
	var quad: Vector2 = (reader.hands.page.mesh as QuadMesh).size
	var local := Vector3((at.x / px.x - 0.5) * quad.x, (0.5 - at.y / px.y) * quad.y, 0.0)
	var world := reader.hands.page.global_transform * local
	if p.camera.is_position_behind(world):
		return Vector2(-1e6, -1e6)
	return p.camera.unproject_position(world)


## What every paper on every floor is, the same paper once (stair placards repeat):
## {where, title, lines, look, flat, size}. Stickies go into the notebook instead.
func _every_paper() -> Array:
	var out: Array = []
	var seen := {}
	var i := 0
	while ResourceLoader.exists("res://scenes/level_%d.tscn" % i):
		var level = load("res://scenes/level_%d.tscn" % i).instantiate()
		_tree.root.add_child(level)
		for f in 5:
			await _tree.physics_frame
		for d in level.find_children("*", "Document", true, false):
			if d.is_sticky():
				continue
			var key := "%s|%s|%s|%s|%s" % [d.look, d.flat, d.read_size, d.title, d.plain_text()]
			if seen.has(key):
				continue
			seen[key] = true
			out.append({"where": "level %d \"%s\"" % [i, d.title], "title": d.title, "lines": d.lines(), "look": d.look, "flat": d.flat, "size": d.read_size})
		level.queue_free()
		for f in 3:
			await _tree.process_frame
		i += 1
	return out
