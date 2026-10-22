extends SceneTree
## Screenshots of the case board: the HUD's case chip and found card, the Cases
## tab mid-case, a case just solved, Completed cases and the void work order.
## Needs a display:
##   xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 -s tools/case_board_shots.gd -- OUT_DIR

var out_dir := "user://case_board_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	var level_0: GDScript = load("res://scripts/levels/level_0.gd")
	game.new_run(8)
	var back := ColorRect.new()
	back.color = Color(0.11, 0.12, 0.13)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	game.set_todo("Sign the visitor log and take a visitor badge")
	game.set_todo("Find out who called from ext. 4471")
	game.open_case("caller", "Who called from ext. 4471?", ["staff_directory"])
	game.set_pieces("caller", level_0.caller_pieces(4471), level_0.CALLER_QUERY, level_0.CALLER_STEPS)
	game.set_routes("caller", level_0.CALLER_ROUTES)
	game.set_blank("caller", "Ext. 4471 belongs to", ["harold mercer"], "Harold Mercer")
	game.collect_piece("caller", "ext", "the work order")
	game.add_clue("caller", "Name just the columns you want, with commas between them: SELECT column, column FROM table_name;", "SYSOP")

	# The HUD: the chip, and the card for the piece just found.
	var hud := CanvasLayer.new()
	root.add_child(hud)
	var chip := CaseChip.new()
	hud.add_child(chip)
	await _frames(5)
	game.collect_piece("caller", "table", "SYSOP")
	await _frames(10)
	_save("hud_chip")

	# The notebook on the Cases tab, mid-case.
	chip.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 15
	root.add_child(layer)
	var pages := NotebookPages.new()
	layer.add_child(pages)
	pages.showing = true
	await _frames(5)
	pages.show_page(NotebookPages.Page.CASES)
	await _frames(10)
	_save("case_mid")

	# All in and answered: solved, shown before it's filed.
	game.collect_piece("caller", "column", "Tables page")
	game.fill_blank("caller", false)
	game.solve_case("caller", "ext. 4471 is Harold Mercer, Building Services. He left in 03/94.")
	game.find_route("caller", "printout")
	game.open_case("lab", "What happened in the lab?")
	game.set_pieces("lab", [{"id": "door", "label": "The door", "value": "LAB-2", "task": "Find the lab's door", "where": "The keypad"}])
	game.set_endings("lab", [{"id": "lived", "name": "Rourke survived", "hint": ""}, {"id": "died", "name": "???", "hint": "Something on this floor was never opened"}, {"id": "third", "name": "???", "hint": "Not until a later floor"}])
	game.reach_ending("lab", "lived")
	game.solve_case("lab", "he walked out with the crew.")
	pages.show_page(NotebookPages.Page.CASES)
	await _frames(10)
	_save("case_solved")
	pages._show_spread(1)
	await _frames(10)
	_save("case_solved_2")

	# Filed: the Completed cases list.
	pages.file_solved()
	pages.showing_completed = true
	pages.show_page(NotebookPages.Page.CASES)
	await _frames(10)
	_save("completed")

	# The job's over: the work order is void.
	game.end_job()
	pages.showing_completed = false
	pages.show_page(NotebookPages.Page.WORK_ORDER)
	await _frames(10)
	pages._show_spread(1)
	await _frames(10)
	_save("work_order_void")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot + ".png"))
	print("saved ", shot)
