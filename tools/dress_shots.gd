extends SceneTree
## Before/after screenshots of furnished levels, for art PRs. Needs a display:
##   xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 -s tools/dress_shots.gd -- OUT_DIR [l0|l1|l2]

var out_dir := "user://dress_shots"
var only := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	if only in ["", "l0"]:
		await _level_0()
	if only in ["", "l1"]:
		await _level_1()
	quit()


func _level_0() -> void:
	var level = await _load("res://scenes/level_0.tscn")
	level.rourke.global_position = Vector3(-0.5, 0, 0.6)
	await _shot(level, "l0_lobby", Vector3(0, 0.1, 6.2), 0, -6)
	await _shot(level, "l0_reception", Vector3(-3.5, 0.1, 1.5), 35, -12)
	await _shot(level, "l0_behind_desk", Vector3(0, 0.1, -2.0), 160, -10)
	await _shot(level, "l0_lot", Vector3(4.1, 0.05, 14.5), 15, 5)
	await _shot(level, "l0_hall", Vector3(8.5, 0.1, 3), -90, 0)
	await _shot(level, "l0_closet", Vector3(-14.6, 0.1, 4), 90, -10)
	await _shot(level, "l0_van", Vector3(6.2, 0.05, 11.2), 145, -6)
	await _shot(level, "l0_van_rear", Vector3(5.6, 0.05, 21.5), 35, -6)
	await _shot(level, "l0_van_cab", Vector3(2.0, 0.55, 17.5), 0, -8)
	# The rest of the ground floor.
	await _shot(level, "l0_corridor", Vector3(-18.5, 0.1, -8.5), -90, -4)
	await _shot(level, "l0_mailroom", Vector3(-16.5, 0.1, -10.8), 0, -10)
	await _shot(level, "l0_restroom", Vector3(-11.5, 0.1, -10.6), 0, -8)
	await _shot(level, "l0_cafeteria", Vector3(-6.0, 0.1, -10.8), -60, -8)
	await _shot(level, "l0_cafeteria_counter", Vector3(3.0, 0.1, -12.0), 20, -10)
	await _shot(level, "l0_it_closet", Vector3(10.0, 0.1, -10.4), 0, -8)
	await _shot(level, "l0_dark", Vector3(13.0, 0.1, -8.5), -90, -4)
	await _shot(level, "l0_elevators", Vector3(24.8, 0.1, 6.4), -60, -6)
	level.free()


func _level_1() -> void:
	root.get_node("Game").new_run(3)
	var level = await _load("res://scenes/level_1.tscn")
	await _shot(level, "l1_entry", Vector3(0, 0.1, 10.5), 0, 0)
	await _shot(level, "l1_room_a", Vector3(-1.0, 0.1, 7.5), 20, -8)
	await _shot(level, "l1_south_corridor", Vector3(-20.5, 0.1, 11.0), -90, -3)
	await _shot(level, "l1_north_corridor", Vector3(20.5, 0.1, -11.0), 90, -3)
	await _shot(level, "l1_noc", Vector3(-10.0, 0.1, 7.5), 50, -10)
	await _shot(level, "l1_cable_vault", Vector3(-9.5, 0.1, -4.0), 60, -10)
	await _shot(level, "l1_server_b", Vector3(9.0, 0.1, 7.8), -50, -6)
	await _shot(level, "l1_break", Vector3(9.0, 0.1, -4.0), -75, -10)
	await _shot(level, "l1_server_c", Vector3(-12.0, 0.1, -14.0), 0, -8)
	level.free()


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
