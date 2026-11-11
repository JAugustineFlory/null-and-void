extends SceneTree
## Screenshots of the look-down notebook at Server Room A's terminal (TerminalNotebook),
## as built: at the screen, looked down (nothing typed, after SELECT, after FROM),
## Normal, and on a pad. Needs a display; at 2x the game's size:
##   xvfb-run -a -s "-screen 0 3200x1800x24" godot --rendering-driver vulkan \
##     --resolution 3200x1800 -s tools/keyword_button_shots.gd -- OUT_DIR

var out := "user://keyword_button_shots"
var level: Node

func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	var game = root.get_node("Game")
	root.get_node("Net").profile = Profile.new()
	game.new_run(7)
	game.diegetic_ui = true
	level = load("res://scenes/level_1.tscn").instantiate()
	root.add_child(level)
	await _frames(20)
	for id in ["easy_sql_1", "easy_sql_2", "easy_sql_3", "easy_sql_4", "easy_sql_5", "easy_sql_6", "easy_sql_7", "easy_sql_8"]:
		if level.get_node_or_null("Huddle"):
			level.get_node("Huddle").done[id] = true
	game.book_chapters.assign(["easy_sql_1", "easy_sql_2", "easy_sql_3", "easy_sql_4", "easy_sql_5", "easy_sql_6"])
	level.hud.set_process(false)
	var t = level.terminal
	t.locked = false
	game.open_case("controller", "Which door controller keeps faulting?", ["door_controllers", "doors"], level.OBJ_CONTROLLER)
	game.set_pieces("controller", level.controller_pieces(level.zone), level.CONTROLLER_QUERY, level.CONTROLLER_STEPS)
	var p = level.player
	p.global_position = t.stand_point.global_position + Vector3.UP * 0.05
	p.global_rotation = t.stand_point.global_rotation
	await _frames(30)
	for i in 20:
		t._on_used(p)
		if p.is_using_terminal():
			break
		await _frames(3)
	await create_timer(2.5).timeout
	var ui: TerminalUI = level.terminal_ui
	ui.run(".tables")
	ui.run("SELECT * FROM doors;")
	ui.run(".schema door_controllers")
	game.collect_piece("controller", "zone", "doors")
	var hud = level.hud
	hud._subtitle.self_modulate = Color(1, 1, 1, 0)
	hud._notice.self_modulate = Color(1, 1, 1, 0)
	await create_timer(1.0).timeout
	_save("1_at_screen")
	ui.book.look(true)
	await create_timer(1.0).timeout
	_save("2_looked_down")
	ui.insert_word("SELECT")
	await create_timer(0.6).timeout
	_save("3_after_select")
	ui.insert_word("id")
	ui.insert_word("FROM")
	await create_timer(0.6).timeout
	_save("4_after_from")
	KeywordHelp.mode = "normal"
	ui.book.refresh(true)
	await create_timer(0.6).timeout
	_save("5_normal")
	KeywordHelp.mode = "easy"
	InputGlyphs.pad = true
	ui._input.text = ""
	ui.insert_word("SELECT")
	ui.book.refresh(true)
	await create_timer(0.8).timeout
	_save("6_pad")
	quit()

func _save(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(n + ".png"))
	print("saved ", n)
