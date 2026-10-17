extends SceneTree
## Lookdev screenshots of the notebook, sticky notes and the elevator. Needs a display:
##   xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 -s tools/notebook_shots.gd -- OUT_DIR

var out_dir := "user://notebook_shots"
var cam: Camera3D
var lift: ArtElevator


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
	_landing(world)
	cam = Camera3D.new()
	cam.fov = 70
	world.add_child(cam)
	cam.make_current()

	# The elevator from the corridor, shut and open, then from inside.
	_cam(Vector3(1.2, 1.6, -4.2), 165, -6)
	await _frames(20)
	_save("elevator_shut")
	lift.light_call(true)
	lift.open_amount = 1.0
	await _frames(10)
	_save("elevator_open")
	lift.light_button("B2")
	lift.set_floor("B1")
	lift.set_direction(-1)
	_cam(Vector3(-0.6, 1.6, 1.9), -15, -4)
	await _frames(10)
	_save("elevator_inside")
	lift.open_amount = 0.5
	_cam(Vector3(0.4, 1.6, -2.8), 180, -4)
	await _frames(10)
	_save("elevator_closing")

	# Sticky notes on a desk and a terminal, close up.
	_cam(Vector3(-4.2, 1.25, -1.45), 180, -32)
	await _frames(10)
	_save("sticky_desk")

	# The notebook UI over the darkened corridor.
	var layer := CanvasLayer.new()
	layer.layer = 15
	root.add_child(layer)
	var book := NotebookView.new()
	layer.add_child(book)
	for t in ["Notes", "Tables", "Field Notes"]:
		book.add_tab(t)
	book.left.add_child(NotebookArt.heading("SQL notes"))
	book.left.add_child(NotebookArt.hand("Found these stuck around the building. Ask the others what they found!", 24))
	book.left.add_child(NotebookArt.sticky("SELECT ... FROM", "SELECT columns FROM table;", "SELECT name, floor FROM rooms;"))
	book.left.add_child(NotebookArt.sticky("WHERE", "... WHERE column = value", "SELECT * FROM rooms\n WHERE floor = 2;", ArtProps.STICKY_COLORS[2]))
	book.right.add_child(NotebookArt.heading("Tables"))
	book.right.add_child(NotebookArt.table_card("doors", ["door_id", "location", "locked", "badge_level"]))
	book.right.add_child(NotebookArt.table_card("lights", ["light_id", "zone", "on"]))
	book.right.add_child(NotebookArt.note_line("SEC-EXIT  | locked | badge_level 3", "the way out?"))
	book.right.add_child(NotebookArt.margin_note("status can lie. check the sensor!"))
	book.show_book()
	await _frames(30)
	_save("notebook")
	quit()


func _landing(world: Node3D) -> void:
	# A corridor that ends at the elevator: a 20 cm wall centered on z = 0, as Greybox builds them.
	var floor_mat := ArtPalette.surface("floor_tile")
	_slab(world, Vector3(0, -0.1, -4), Vector3(12, 0.2, 10), floor_mat)
	_slab(world, Vector3(0, 3.1, -4), Vector3(12, 0.2, 10), ArtPalette.surface("ceiling_tile"))
	# wall around the shaft opening (doorway 1.2 m, car 2.6 m wide)
	_slab(world, Vector3(-3.65, 1.5, 0.0), Vector3(4.7, 3, 0.2), ArtPalette.surface("drywall"))
	_slab(world, Vector3(3.65, 1.5, 0.0), Vector3(4.7, 3, 0.2), ArtPalette.surface("drywall"))
	_slab(world, Vector3(0, 2.8, 0.0), Vector3(2.6, 0.4, 0.2), ArtPalette.surface("drywall"))
	_slab(world, Vector3(-6, 1.5, -4), Vector3(0.2, 3, 10), ArtPalette.surface("drywall"))
	_slab(world, Vector3(6, 1.5, -4), Vector3(0.2, 3, 10), ArtPalette.surface("drywall"))
	lift = ArtElevator.build(world, Vector3.ZERO, 0.0)
	var lights: Array = []
	for z in [-1.5, -5.0]:
		lights.append(ArtProps.troffer(world, Vector3(0, 3.0, z)))
	ArtMood.apply_to_lights(lights, "after_hours")
	# a desk with a terminal and sticky notes, off to one side
	ArtProps.desk(world, Vector3(-4.0, 0, -0.45), 0)
	ArtProps.crt_monitor(world, Vector3(-4.0, 0.76, -0.4), 0, "green")
	ArtProps.sticky_note(world, Vector3(-3.83, 1.08, -0.56), 0, "LIKE", ArtProps.STICKY_COLORS[1])
	ArtProps.sticky_note(world, Vector3(-4.5, 0.762, -0.62), 0, "ORDER BY", ArtProps.STICKY_YELLOW, true)


func _slab(world: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	world.add_child(mi)


func _cam(pos: Vector3, yaw: float, pitch: float) -> void:
	cam.position = pos
	cam.rotation_degrees = Vector3(pitch, yaw, 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot + ".png"))
	print("saved ", shot)
