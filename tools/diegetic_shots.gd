extends SceneTree
## Lookdev screenshots of the held notebook and the in-world terminal screens. Needs a display:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 -s tools/diegetic_shots.gd -- OUT_DIR

var out_dir := "user://diegetic_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = ArtMood.environment("after_hours")
	world.add_child(env)
	_office(world)
	cam = Camera3D.new()
	cam.fov = 75
	cam.position = Vector3(0, 1.6, -2.2)
	cam.rotation_degrees = Vector3(-4, 180, 0)
	world.add_child(cam)
	cam.make_current()

	# The notebook in your hands.
	var held := HeldNotebook.attach(cam, CharacterLooks.crew(0))
	var book := NotebookView.new()
	held.set_content(book)
	for t in ["Work order", "Tables", "Notes", "Field Notes"]:
		book.add_tab(t)
	book.select_tab("Notes")
	book.left.add_child(NotebookArt.heading("Notes"))
	book.left.add_child(NotebookArt.sticky("SELECT ... FROM", "SELECT columns FROM table;", "SELECT name, floor FROM rooms;"))
	book.left.add_child(NotebookArt.hand("Rourke said the badge office is on B1.", 24))
	book.right.add_child(NotebookArt.table_card("doors", ["door_id", "location", "locked", "badge_level"]))
	book.right.add_child(NotebookArt.note_line("SEC-EXIT  | locked | badge_level 3", "the way out?"))
	book.show_book()
	await _frames(5)
	held.open_book()
	await create_timer(0.2).timeout
	_save("held_pulling_out")
	await create_timer(0.5).timeout
	_save("held_open")
	var line := NotebookArt.note_line("B1-04  | open  | badge_level 1", "storeroom")
	book.right.add_child(line)
	held.write_in(line, 1.2)
	await create_timer(0.6).timeout
	_save("held_writing")
	await create_timer(1.0).timeout
	_save("held_written")
	held.close_book()
	await create_timer(0.5).timeout

	# A terminal on the desk, its text on the glass.
	var term := Node3D.new()
	term.position = Vector3(0, 0.762, -0.45)
	term.rotation_degrees.y = 180
	var grey := MeshInstance3D.new()  # the greybox monitor the art replaces
	grey.mesh = BoxMesh.new()
	term.add_child(grey)
	world.add_child(term)
	var screen := TerminalScreen.attach(term)
	screen.set_title("HALCYON DATA SYSTEMS  //  SERVER ROOM A")
	for l in ["Type .help for commands.", "", "[color=#cfc]> SELECT name, floor FROM rooms;[/color]",
			"name          | floor", "--------------+------", "Server Room A | B1", "Badge Office  | B1", "Storeroom     | B2",
			"(3 rows)", "", "[color=#fc6]SYSOP: B2 is not on the lift panel.[/color]"]:
		screen.add_line(l)
	screen.set_typing("SELECT * FROM doors WHERE floor = 'B2'")
	cam.position = Vector3(0.35, 1.65, -1.6)
	cam.rotation_degrees = Vector3(-18, 172, 0)
	await create_timer(0.3).timeout
	_save("terminal_room")
	cam.position = Vector3(0.0, 1.62, -1.2)
	cam.rotation_degrees = Vector3(-22, 180, 0)
	await create_timer(0.2).timeout
	_save("terminal_over_shoulder")
	cam.global_transform = screen.focus_transform(cam.fov)
	await create_timer(0.2).timeout
	_save("terminal_focused")
	# The interactive terminal, hosted on the glass while someone types.
	var ui := CanvasLayer.new()
	var panel := ColorRect.new()
	panel.color = Color(0.02, 0.05, 0.03)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(panel)
	var out := RichTextLabel.new()
	out.bbcode_enabled = true
	out.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	out.offset_left = 40
	out.offset_top = 40
	out.add_theme_font_override("normal_font", NotebookArt.type_font())
	out.add_theme_font_size_override("normal_font_size", 22)
	out.add_theme_color_override("default_color", Color(0.45, 1.0, 0.55))
	out.text = "HALCYON DATA SYSTEMS  //  SERVER ROOM A\n\n> SELECT door_id, location, locked FROM doors;\n\ndoor_id   | location        | locked\n----------+-----------------+-------\nB1-01     | Server Room A   | 0\nB1-04     | Storeroom       | 1\nSEC-EXIT  | Stairwell east  | 1\n(3 rows)   [color=#fd6][+ note][/color]"
	ui.add_child(out)
	screen.host(ui)
	await create_timer(0.2).timeout
	_save("terminal_hosted")
	quit()


func _office(world: Node3D) -> void:
	_slab(world, Vector3(0, -0.1, -2), Vector3(8, 0.2, 8), ArtPalette.surface("carpet"))
	_slab(world, Vector3(0, 1.5, 0.1), Vector3(8, 3, 0.2), ArtPalette.surface("drywall"))
	_slab(world, Vector3(-4, 1.5, -2), Vector3(0.2, 3, 8), ArtPalette.surface("drywall"))
	ArtMood.apply_to_lights([ArtProps.troffer(world, Vector3(0, 3.0, -1.0)), ArtProps.troffer(world, Vector3(-2, 3.0, -2.5))], "after_hours")
	ArtProps.desk(world, Vector3(0, 0, -0.45), 0, 1.6)
	ArtProps.office_chair(world, Vector3(0, 0, -1.1), 180)
	ArtProps.poster(world, Vector3(-1.8, 1.6, 0.0), 0, "BADGES MUST BE WORN AT ALL TIMES")
	ArtProps.filing_cabinet(world, Vector3(1.6, 0, -0.3), 0)


func _slab(world: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	world.add_child(mi)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot + ".png"))
	print("saved ", shot)
