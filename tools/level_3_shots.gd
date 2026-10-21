extends SceneTree
## A screenshot tour of floor 18 (Level 3) for a morning look: no HUD, lights on.
## Needs a display. With no Vulkan driver on the machine, the Compatibility renderer
## lights the scene well enough:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 -s tools/level_3_shots.gd -- OUT_DIR
## The shots go to OUT_DIR as l3_*.png, in tour order; captions are in the tour's
## folder under /mnt/project-files/level3/shots/.

var out_dir := "user://level_3_shots"
var level: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	root.get_node("Game").new_run(3)
	level = load("res://scenes/level_3.tscn").instantiate()
	root.add_child(level)
	await _frames(20)
	level.hud.set_process(false)
	level.hud.visible = false
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	level.desk.ensure_booted()
	level.fiche.ensure_booted()
	var host: String = level.data.host
	var spec: Dictionary = level.SIDE_ROOMS[host]
	var c: Vector3 = spec.center
	var back: Vector3 = spec.back
	var wall_x: float = c.x + back.x * level.SIDE_ROOM_SIZE.x / 2

	# 1. Arriving: the wedged fire door from the lobby side, the stairs from 22 beyond it.
	await _shot("01_arrival", Vector3(-0.6, 0.05, 6.2), level.STAIR_IN_AT + Vector3(0, 1.2, 0))
	# 2. The dead lifts and the facilities memo.
	await _shot("02_lifts", Vector3(0.5, 0.05, 4.6), Vector3(-0.5, 1.4, 8.0))
	# 3. The records desk: terminal, slips on the spike, the policy sheet.
	await _shot("03_records_desk", Vector3(0, 0.05, 3.3), Vector3(0, 1.1, 1.0))
	# 4. The reading room from its west side: tables to hide under, the card drawers.
	await _shot("04_reading_room", Vector3(-7.0, 0.05, 3.2), Vector3(2.0, 1.2, -3.0))
	# 5. The stacks as the crew finds them: dark after 19:00, by flashlight.
	await _shot("05_stacks_dark", Vector3(-4.0, 0.05, -5.6), Vector3(-4.0, 1.4, -14.0), true)
	# 6. From a shelf top, with the stacks' sensor lights forced on for the picture.
	for l in level.lights["L18-STACKS"]:
		l.visible = true
	var mid: Vector3 = level.stack_units[2].position
	await _shot("06_shelf_tops", Vector3(mid.x, 3.65, -10.5), Vector3(mid.x + 3.0, 2.8, -20.0))
	for l in level.lights["L18-STACKS"]:
		l.visible = false
	# 7. The west hall, looking north: side room doors, badge readers beside them.
	await _shot("07_west_hall", Vector3(-9.5, 0.05, -2.5), Vector3(-9.5, 1.3, -20.0))
	# 8. A crank room (not the one hiding the safe room): rolling units on rails, the crank.
	var other: String = "MAP ROOM" if host != "MAP ROOM" else "VAULT C"
	var ospec: Dictionary = level.SIDE_ROOMS[other]
	var odoor_x: float = ospec.center.x - ospec.back.x * level.SIDE_ROOM_SIZE.x / 2
	level.room_doors[other].set_open(true, true)
	await _frames(30)
	await _shot("08_crank_room", Vector3(odoor_x - ospec.back.x * 1.9, 0.05, ospec.center.z + 0.3), ospec.center + Vector3(0, 1.0, 0), true)
	level.room_doors[other].set_open(false, true)
	# 9. The shredding room from its roll-up door: the machines, the bale, the Shredder asleep.
	await _shot("09_shredding_room", Vector3(-5.5, 0.05, -24.5), level.SHREDDER_HOME + Vector3(-1.2, 1.1, -1.8))
	# 10. The microfiche room and the intranet terminal (its tube is out: dark).
	await _shot("10_microfiche", Vector3(6.5, 0.05, -25.4), level.fiche.global_position + Vector3(0, 0.2, 0), true)
	# 11. The host room cranked: the aisle along the back wall, Mercer's door and its lock.
	level._crank(host)
	await _frames(120)
	await _shot("11_mercer_door", Vector3(wall_x - back.x * 1.0, 0.05, c.z - 0.8), Vector3(wall_x, 1.3, c.z + 1.6), true)
	# 12. Inside the safe room: generator and batteries, the cot, the desk with the lantern,
	#     the floppy and the reference card.
	level.safe_door.set_open(true, true)
	await _frames(30)
	var sc: Vector3 = level.safe_room_box.get_center()
	await _shot("12_safe_room", Vector3(wall_x + back.x * 0.7, 0.05, c.z + 1.0), Vector3(sc.x - back.x * 0.4, 0.9, sc.z - 1.0))
	# 13. The way out: STAIR 1 down, locked until the key ring.
	await _shot("13_exit_stairs", Vector3(0.8, 0.05, 6.0), level.STAIR_OUT_AT + Vector3(0, 1.3, 0))
	level.free()
	quit()


## Stand at `pos` (level space) and look at `target` (level space).
func _shot(shot: String, pos: Vector3, target: Vector3, torch := false) -> void:
	var p: Player = level.player
	p.global_position = level.to_global(pos)
	var eye := pos + Vector3(0, 1.6, 0)
	var d := target - eye
	p.rotation_degrees.y = rad_to_deg(atan2(-d.x, -d.z))
	p.head.rotation_degrees.x = rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
	p.flashlight.visible = torch
	await _frames(12)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join("l3_" + shot + ".png"))
	print("saved ", shot)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
