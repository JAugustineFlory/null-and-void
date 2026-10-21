extends SceneTree
## Clean screenshots for the README store page and cover art: no HUD, no subtitles.
## Needs a display:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --rendering-driver vulkan --resolution 1920x1080 -s tools/store_shots.gd -- OUT_DIR
## The README images in docs/store/ come from these: tools/make_cover.py composes the
## cover from cover_tower_up.png, and the store_*.png shots are resized to 1280x720 JPGs.

var out_dir := "user://store_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var level = await _load("res://scenes/level_0.tscn")
	level.rourke.global_position = Vector3(-0.5, 0, 0.6)
	await _shot(level, "cover_tower", Vector3(6.0, 0.05, 25.0), 10, 32)
	await _shot(level, "cover_tower_up", Vector3(-14.0, 0.05, 26.0), -25, 62)
	await _shot(level, "cover_tower_lot", Vector3(8.0, 0.05, 24.0), 0, 20)
	await _shot(level, "store_van", Vector3(6.2, 0.05, 11.2), 145, -6)
	await _shot(level, "store_lobby", Vector3(0, 0.1, 6.2), 0, -6)
	level.free()

	root.get_node("Game").new_run(3)
	level = await _load("res://scenes/level_1.tscn")
	await _shot(level, "store_noc", Vector3(-10.0, 0.1, 7.5), 50, -10)
	await _shot(level, "store_servers", Vector3(9.0, 0.1, 7.8), -50, -6, true)
	level.free()

	root.get_node("Game").new_run(3)
	level = await _load("res://scenes/level_2.tscn")
	await _shot(level, "store_ledge", Vector3(6.33, 0.05, -2.0), -110, -12)
	await _shot(level, "store_service", Vector3(-17.0, 0.1, 7.5), 0, -3, true)
	await _shot(level, "store_lockers", Vector3(-10.6, 0.1, -13.0), 90, -6)
	level.free()

	level = await _load("res://scenes/home_base.tscn")
	level.bench_book.visible = true
	await _shot(level, "store_garage", Vector3(0.5, 0.1, 0.8), 70, -15)
	level.free()
	quit()


func _load(path: String) -> Node:
	var level = load(path).instantiate()
	root.add_child(level)
	await _frames(20)
	level.hud.set_process(false)
	level.hud.visible = false
	return level


func _shot(level: Node, shot: String, pos: Vector3, yaw: float, pitch: float, torch := false) -> void:
	level.player.global_position = pos
	level.player.rotation_degrees.y = yaw
	level.player.head.rotation_degrees.x = pitch
	level.player.flashlight.visible = torch
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	await _frames(12)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot + ".png"))
	print("saved ", shot)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
