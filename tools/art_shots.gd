extends SceneTree
## Renders lookdev screenshots of the art gallery. Needs a display:
##   xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 -s tools/art_shots.gd -- OUT_DIR

var out_dir := "user://art_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var g = load("res://scenes/art_gallery.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	_cam(g, Vector3(0, 1.7, 6.0), 0, -8)
	for mood in ["office", "after_hours", "lockdown"]:
		g.set_mood(mood)
		await _frames(20)
		_save("gallery_" + mood)
	g.set_mood("dark")
	g.held.flashlight.set_on(true)
	_cam(g, Vector3(-1.0, 1.6, 4.0), 0, -10)
	await _frames(20)
	_save("gallery_dark_flashlight")
	g.held.flashlight.set_on(false)
	g.set_mood("office")
	_cam(g, Vector3(-1.2, 1.5, 3.4), 0, -5)
	await _frames(20)
	_save("cast_crew")
	_cam(g, Vector3(0.0, 1.5, 1.6), 0, -8)
	await _frames(20)
	_save("cast_npcs")
	for action in ["windup", "down", "tied", "crouch", "crawl"]:
		for r in g.rigs:
			r.play(action)
		await _frames(60)
		_save("pose_" + action)
	for r in g.rigs:
		r.play("idle")
	_cam(g, Vector3(4.6, 1.6, -2.5), 80, -10)
	await _frames(30)
	_save("props_wall")
	_cam(g, Vector3(-3.0, 1.6, -2.5), 0, -15)
	await _frames(20)
	_save("props_desks")
	g.held.raise_walkie(true)
	_cam(g, Vector3(0, 1.7, 6.0), 0, -8)
	await _frames(40)
	_save("first_person_walkie")
	quit()


func _cam(g, pos: Vector3, yaw: float, pitch: float) -> void:
	g.camera.position = pos
	g.camera.rotation_degrees = Vector3(pitch, yaw, 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot + ".png"))
	print("saved ", shot)
