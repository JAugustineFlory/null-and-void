extends SceneTree
## Renders review screenshots of each level. Needs a display (use xvfb-run on servers):
##   xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 -s tools/screenshots.gd -- OUT_DIR

var out_dir := "user://screenshots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var level = await _load("res://scenes/level_0.tscn")
	await _shot(level, "l0_van", Vector3(2.5, 0.55, 15.3), 0, -3)
	await _shot(level, "l0_van_ticket", Vector3(2.0, 0.55, 16.2), 180, -15)
	await _shot(level, "l0_lot", Vector3(4.1, 0.05, 14.5), 15, 5)
	await _shot(level, "l0_spawn", Vector3(0, 0.1, 5.6), 0, -5)
	await _shot(level, "l0_desk", Vector3(1.2, 0.1, 0.4), 10, -18)
	await _shot(level, "l0_hall_shutter", Vector3(8.5, 0.1, 3), -90, 0)
	await _shot(level, "l0_vent", Vector3(-6.5, 0.1, 4), 90, -10)
	level.desk_terminal.enabled = true
	level.terminal_ui.open(level.desk_terminal, level.player)
	level.terminal_ui.run("SELECT * FROM memo_fragments")
	level.terminal_ui.run("SELECT * FROM memo_fragments ORDER BY piece_no")
	await _frames(10)
	_save("l0_terminal")
	level.terminal_ui.close()
	level.free()

	root.get_node("Game").new_run(3)
	var world = await _load("res://scenes/world.tscn")
	world.load_next(world.current)
	world.current.exit_door.set_open(true, true)
	await _shot(world, "world_hall_to_sra", Vector3(19, 0.1, 3), -90, 0)
	world.free()

	level = await _load("res://scenes/level_1.tscn")
	await _shot(level, "l1_entry", Vector3(0, 0.1, 10.5), 0, 0)
	level._on_trapped(null)
	level.rourke.state = Rourke.State.IDLE
	level.rourke.global_position = Vector3(0, 0, 2.5)
	await _shot(level, "l1_betrayal", Vector3(0, 0.1, 6.0), 0, -3)
	await _shot(level, "l1_racks", Vector3(0, 0.1, 5.0), 0, -8)
	level._on_rourke_resolved("tied")
	level.terminal_ui.open(level.terminal, level.player)
	await _frames(10)
	_save("l1_self_test")
	level.terminal_ui.run(".hint")
	await _frames(10)
	_save("l1_hint")
	level.terminal_ui.run(".clear")
	level.terminal_ui.run("SELECT * FROM door_controllers")
	await _frames(10)
	_save("l1_all_controllers")
	level.terminal_ui.run(".clear")
	level.terminal_ui.run("SELECT * FROM door_controllers WHERE zone = 'A' AND status = 'fault'")
	await _frames(10)
	_save("l1_terminal")
	level.terminal_ui.close()
	quit()


func _load(path: String) -> Node:
	var level = load(path).instantiate()
	root.add_child(level)
	await _frames(20)
	level.hud.set_process(false)
	return level


func _shot(level: Node, name: String, pos: Vector3, yaw: float, pitch: float) -> void:
	level.player.global_position = pos
	level.player.rotation_degrees.y = yaw
	level.player.head.rotation_degrees.x = pitch
	await _frames(12)
	_save(name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)
