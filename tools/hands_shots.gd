extends "res://tools/diegetic_shots.gd"
## Lookdev screenshots of the hands: picking up a paper to read it (HeldPaper) and
## taking a sticky note into the notebook (HeldNotebook.take_sticky). Needs a display:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 -s tools/hands_shots.gd -- OUT_DIR

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = ArtMood.environment("after_hours")
	world.add_child(env)
	_office(world)
	cam = Camera3D.new()
	cam.fov = 75
	world.add_child(cam)
	cam.make_current()
	var lines := [
		{"columns": ["NAME", "BADGE #", "IN", "OUT", "INIT."], "widths": [3.4, 1.8, 1.3, 1.3, 1.2]},
		{"row": ["PIKE, H.", "", "", "", ""], "over": "NO SHOW", "text": "PIKE, H.  no show"},
		{"row": ["Har", "", "22:00", "", ""], "stain": "coffee", "stain_at": 0, "text": "Har... (coffee stain)  22:00"},
		{"row": ["", "", "", "", ""]},
		"",
		"Guard PINs are kept on file in the table:",
		{"text": "guards", "hand": true},
	]
	var wall_doc := Document.place(world, Vector3(-1.0, 1.45, -0.05), 180, "NIGHT SHIFT SIGN-IN   DATE: 10/15", lines, false, "clipboard")
	var desk_doc := Document.place(world, Vector3(0.3, 0.762, -0.5), 180, "MEMO: badge audit", ["The badge audit runs Friday night.", {"text": "unplug it. - H.M.", "hand": true, "author": "mercer"}], true, "paper")
	var held := HeldPaper.attach(cam, CharacterLooks.crew(0))
	# The wall: from where you stand to read it.
	cam.position = Vector3(-1.0, 1.6, -1.1)
	cam.rotation_degrees = Vector3(-5, 180, 0)
	await _frames(5)
	_save("paper_wall_before")
	var tw := held.lift(wall_doc)
	await create_timer(0.2).timeout
	_save("paper_wall_reach")
	await create_timer(0.2).timeout
	_save("paper_wall_bring")
	await tw.finished
	await _frames(3)
	_save("paper_wall_held")
	await held.put_back().finished
	await _frames(3)
	_save("paper_wall_after")
	# The desk.
	cam.position = Vector3(0.3, 1.55, -1.25)
	cam.rotation_degrees = Vector3(-50, 180, 0)
	await _frames(3)
	tw = held.lift(desk_doc)
	await create_timer(0.25).timeout
	_save("paper_desk_reach")
	await tw.finished
	await _frames(3)
	_save("paper_desk_held")
	await held.put_back().finished
	# A sticky note on the wall, into the open notebook.
	var note := ArtProps.sticky_note(world, Vector3(-0.4, 1.35, -0.02), 180, "LIKE 'Dale%'")
	var nb := HeldNotebook.attach(cam, CharacterLooks.crew(0))
	var book := NotebookView.new()
	nb.set_content(book)
	book.add_tab("Notes")
	book.select_tab("Notes")
	book.left.add_child(NotebookArt.heading("Notes"))
	cam.position = Vector3(-0.4, 1.6, -0.8)
	cam.rotation_degrees = Vector3(-8, 180, 0)
	await nb.open_book().finished
	var item := NotebookArt.sticky("LIKE", "WHERE col LIKE 'Ab%';", "WHERE name LIKE 'Dale%';")
	book.right.add_child(item)
	await _frames(3)
	tw = nb.take_sticky(note, item)
	await create_timer(0.25).timeout
	_save("sticky_reach")
	await create_timer(0.3).timeout
	_save("sticky_carry")
	await create_timer(0.25).timeout
	_save("sticky_press")
	await tw.finished
	await _frames(3)
	_save("sticky_done")
	quit()
