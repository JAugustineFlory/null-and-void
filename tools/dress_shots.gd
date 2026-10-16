extends SceneTree
## Before/after screenshots of furnished levels, for art PRs. Needs a display:
##   xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 -s tools/dress_shots.gd -- OUT_DIR

var out_dir := "user://dress_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var level = await _load("res://scenes/level_0.tscn")
	level.rourke.global_position = Vector3(-0.5, 0, 0.6)
	await _shot(level, "l0_lobby", Vector3(0, 0.1, 6.2), 0, -6)
	await _shot(level, "l0_reception", Vector3(-3.5, 0.1, 1.5), 35, -12)
	await _shot(level, "l0_behind_desk", Vector3(0, 0.1, -2.0), 160, -10)
	await _shot(level, "l0_lot", Vector3(4.1, 0.05, 14.5), 15, 5)
	await _shot(level, "l0_hall", Vector3(8.5, 0.1, 3), -90, 0)
	await _shot(level, "l0_closet", Vector3(-14.6, 0.1, 4), 90, -10)
	level.free()

	root.get_node("Game").new_run(3)
	level = await _load("res://scenes/level_1.tscn")
	await _shot(level, "l1_entry", Vector3(0, 0.1, 10.5), 0, 0)
	level._on_trapped(null)
	level.rourke.state = Rourke.State.IDLE
	level.rourke.global_position = Vector3(0, 0, 2.5)
	await _shot(level, "l1_betrayal", Vector3(0, 0.1, 6.0), 0, -3)
	quit()


func _load(path: String) -> Node:
	var level = load(path).instantiate()
	root.add_child(level)
	await _frames(20)
	level.hud.set_process(false)
	return level


func _shot(level: Node, shot: String, pos: Vector3, yaw: float, pitch: float) -> void:
	level.player.global_position = pos
	level.player.rotation_degrees.y = yaw
	level.player.head.rotation_degrees.x = pitch
	await _frames(12)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot + ".png"))
	print("saved ", shot)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
