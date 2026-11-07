extends SceneTree
## Mock-ups of the look-down notebook at a terminal (Augustine, 2026-11-07 01:45Z):
## the terminal keeps the whole screen; looking down shows the notebook in your
## hands below it, with the case's query so far and tabs of next-word buttons
## (Tables, Columns, Commands). Drawn in Server Room A on 14. Nothing here is wired
## into the game yet. Needs a display, at 2x the game's size; one part a run:
##   xvfb-run -a -s "-screen 0 3200x1800x24" godot --rendering-driver vulkan \
##     --resolution 3200x1800 -s tools/keyword_button_shots_v3.gd -- OUT_DIR pc|console|tables

var out_dir := "user://keyword_button_shots_v3"
var level: Node
var ui: TerminalUI
var cam: Camera3D
var held: HeldNotebook
var book: NotebookView
var _base: Transform3D
var _hint_layer: CanvasLayer

const USES := 3
const INK := Color(0.12, 0.15, 0.32)
const PENCIL := Color(0.35, 0.35, 0.37)
const RED_PEN := Color(0.7, 0.12, 0.1)
const CHIP := Color(0.93, 0.91, 0.84)
const NAME_CHIP := Color(0.84, 0.88, 0.93)
## The tabs, in Augustine's order.
const TABS := ["Tables", "Columns", "Commands"]
## How far the head tips down to read the notebook, and leans back.
const LOOK_DOWN := 22.0
const LEAN_BACK := 0.15
## Held a little lower and further off than for reading, so the screen's typing
## line stays in view above it.
const HOLD := Vector3(0, -0.06, -0.06)

var counts := {"SELECT": 2, "*": 1, "FROM": 2, ";": 2, "ORDER BY": 0, ",": 0, ".schema": 1, ".tables": 1,
	"DESC": 0, "LIMIT": 0, "WHERE": 1, "=": 1, "' '": 1, "AND": 0}
var starters := ["SELECT", ".tables", ".schema"]
var after_table := ["WHERE", "ORDER BY", "LIMIT", ";"]
var tables: Array = []
var columns := {}
var case_id := "controller"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred(args[1] if args.size() > 1 else "pc")


func _run(part: String) -> void:
	var game = root.get_node("Game")
	game.new_run(7)
	level = load("res://scenes/level_1.tscn").instantiate()
	root.add_child(level)
	await _frames(20)
	level.hud.set_process(false)
	var t = level.terminal
	t.locked = false
	game.open_case(case_id, "Which door controller keeps faulting?", ["door_controllers", "doors"], level.OBJ_CONTROLLER)
	game.set_pieces(case_id, level.controller_pieces(level.zone), level.CONTROLLER_QUERY, level.CONTROLLER_STEPS)
	await _step_up(t)
	var db: FacilityDB = t.db
	tables = Array(db.table_names())
	tables.sort()
	if part == "tables":
		await _tables_shots(db)
		quit()
		return
	ui.run(".tables")
	ui.run("SELECT * FROM doors;")
	ui.run(".schema door_controllers")
	game.collect_piece(case_id, "zone", "doors")
	columns = {"doors": _cols(db, "doors"), "door_controllers": _cols(db, "door_controllers")}
	await _frames(5)
	await _make_camera()
	var pad := part == "console"
	InputGlyphs.pad = pad
	ui._show_foot()
	if pad:
		await _shot("console_1_looked_down_after_select", "SELECT ", true, func(): _fill("SELECT ", "Columns", true, true))
		await _shot("console_2_looked_down_after_from", "SELECT id FROM ", true, func(): _fill("SELECT id FROM ", "Tables", true, true))
		quit()
		return
	await _hint_shot("pc_1_at_the_terminal")
	await _shot("pc_2_looked_down_start", "", true, func(): _fill("", "Commands", true, false))
	await _shot("pc_3_looked_down_after_select", "SELECT ", true, func(): _fill("SELECT ", "Columns", true, false))
	await _shot("pc_4_looked_down_after_from", "SELECT id FROM ", true, func(): _fill("SELECT id FROM ", "Tables", true, false))
	await _shot("pc_5_normal_looked_down", "SELECT id FROM door_controllers\nWHERE zone = '%s' AND " % level.zone, true, func(): _fill("", "", false, false))
	quit()


func _step_up(t: Node) -> void:
	level.player.global_position = t.stand_point.global_position
	level.player.global_rotation = t.stand_point.global_rotation
	await _frames(10)
	t._on_used(level.player)
	await create_timer(2.5).timeout
	ui = level.terminal_ui


## A camera of our own where the player's eyes are at the terminal, with a
## notebook in its hands.
func _make_camera() -> void:
	_base = level.player.camera.global_transform
	cam = Camera3D.new()
	cam.fov = level.player.camera.fov
	level.add_child(cam)
	cam.global_transform = _base
	cam.make_current()
	held = HeldNotebook.attach(cam, NetPlayers.look_for(level, level.multiplayer.get_unique_id()))
	book = NotebookView.new()
	held.set_content(book)
	book.show_book()
	await held.open_book().finished  # or its tween poses the book over ours


## Looking at the screen: the notebook's top edge below it, and a hint.
func _hint_shot(shot: String) -> void:
	cam.global_transform = _base
	_fill("", "Commands", true, false)
	await create_timer(1.5).timeout
	held.set_process(false)
	held.book_root.transform = held.reading_transform().translated(Vector3(0, -0.19, 0))
	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 25
	var l := ThemeUtil.label("▼  Look down: your notebook", 26, Color(1, 1, 1))
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_left = -400
	l.offset_right = 400
	l.offset_top = -64
	l.offset_bottom = -24
	_hint_layer.add_child(l)
	root.add_child(_hint_layer)
	ui._input.text = ""
	_quiet()
	await _frames(8)
	_save(shot)
	_hint_layer.queue_free()
	held.set_process(true)


func _shot(shot: String, typed: String, down: bool, fill: Callable) -> void:
	cam.global_transform = _base.translated_local(Vector3(0, 0, LEAN_BACK)).rotated_local(Vector3.RIGHT, deg_to_rad(-LOOK_DOWN)) if down else _base
	fill.call()
	# The notebook is held over the keyboard, which would poke through its pages.
	level.terminal.screen.keyboard.visible = not down
	held.set_process(false)
	held.book_root.transform = held.reading_transform().translated(HOLD)
	ui._input.text = typed
	var last := ui._input.get_line_count() - 1
	ui._input.set_caret_line(last)
	ui._input.set_caret_column(ui._input.get_line(last).length())
	_quiet()
	await create_timer(1.2).timeout
	_save(shot)


func _quiet() -> void:
	level.hud._subtitle.self_modulate = Color(1, 1, 1, 0)
	level.hud._prompt.self_modulate = Color(1, 1, 1, 0)
	level.hud._notice.self_modulate = Color(1, 1, 1, 0)


# --- The notebook's pages ------------------------------------------------------------

## Left page: the case and its query so far. Right page: the open tab's buttons,
## the words that can follow `typed` (Easy), or nothing (Normal).
func _fill(typed: String, tab: String, easy: bool, pad: bool) -> void:
	book.clear_pages()
	for c in book._tabs.get_children():
		book._tabs.remove_child(c)
		c.free()
	book._tab_buttons.clear()
	if easy:
		for name in TABS:
			book.add_tab(name)
		book.select_tab(tab)
	book.left.add_child(NotebookArt.heading("The case"))
	book.left.add_child(NotebookArt.hand(level.OBJ_CONTROLLER, 30))
	book.left.add_child(NotebookArt.hand("My query so far", 28, PENCIL))
	var q := NotebookArt.code(_pattern().replace(" WHERE", "\nWHERE").replace(" AND", "\n  AND"), 34)
	book.left.add_child(q)
	if not easy:
		return
	book.right.add_child(NotebookArt.heading(tab))
	book.right.add_child(NotebookArt.hand("Can come next" + ("   (LB/RB: tabs)" if pad else ""), 28, PENCIL))
	var groups := {}
	for g in _next(typed):
		groups[g[0]] = g[1]
	var first := pad
	if tab == "Columns":
		for tc in groups.get("Columns", []):
			book.right.add_child(_typed(tc[0], 26, PENCIL))
			book.right.add_child(_chips(tc[1], NAME_CHIP, false, pad, first))
			first = false
	else:
		book.right.add_child(_chips(groups.get(tab, []), CHIP if tab == "Commands" else NAME_CHIP, tab == "Commands", pad, first))


## The groups of words that can follow `typed`: [[group, words]], where a Columns
## group's words are [[table, [columns]]]. Words used 3 times are off.
func _next(typed: String) -> Array:
	var t := typed.strip_edges().to_upper()
	var cmds := func(list: Array) -> Array:
		return list.filter(func(w): return counts.has(w) and counts[w] < USES)
	if t == "":
		return [["Commands", cmds.call(starters)]]
	if t.ends_with("SELECT"):
		var cols := []
		for name in columns:
			cols.append([name, columns[name]])
		return [["Commands", cmds.call(["*"])], ["Columns", cols]]
	if t.ends_with("FROM"):
		return [["Tables", tables]]
	return [["Commands", cmds.call(after_table)]]


## Word buttons on the page. Commands show their uses out of 3 (red on the last).
## On a pad they're bigger tiles, and the first is the one the d-pad is on.
func _chips(words: Array, paper: Color, counted: bool, pad: bool, focus_first: bool) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10 if pad else 8)
	flow.add_theme_constant_override("v_separation", 10 if pad else 8)
	for i in words.size():
		var w: String = words[i]
		var p := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = paper
		s.border_color = INK
		s.set_border_width_all(2 if pad else 1)
		s.border_width_bottom = 4
		s.set_corner_radius_all(8 if pad else 5)
		s.content_margin_left = 14 if pad else 10
		s.content_margin_right = 14 if pad else 10
		s.content_margin_top = 3 if pad else 2
		s.content_margin_bottom = 3 if pad else 2
		if focus_first and i == 0:
			s.bg_color = Color(1.0, 0.95, 0.6)
			s.border_color = Color(0.85, 0.35, 0.1)
			s.set_border_width_all(5)
		p.add_theme_stylebox_override("panel", s)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(_typed(w, 36 if pad else 38, INK))
		if counted:
			var used: int = counts.get(w, 0)
			h.add_child(_typed("●".repeat(used) + "○".repeat(USES - used), 24, RED_PEN if used >= USES - 1 else PENCIL))
		p.add_child(h)
		flow.add_child(p)
	return flow


# --- The Tables page under Augustine's rule ---------------------------------------------

## .tables writes only names; a table's columns come in with .schema or SELECT *.
func _tables_shots(db: FacilityDB) -> void:
	var game = root.get_node("Game")
	ui.run(".tables")
	for name in db.table_names():
		game.notebook_tables[name] = []
	await _tables_page("tables_1_before_schema")
	await _step_up(level.terminal)
	ui.run(".schema door_controllers")
	game.notebook_tables["door_controllers"] = _cols(db, "door_controllers")
	await _tables_page("tables_2_after_schema")


func _tables_page(shot: String) -> void:
	ui.close()
	await create_timer(1.5).timeout
	level.player.input_locked = false
	level.notebook.open()
	await create_timer(1.2).timeout
	level.notebook.pages.show_page(NotebookPages.Page.TABLES)
	_quiet()
	await create_timer(0.8).timeout
	_save(shot)
	level.notebook.close()
	await create_timer(1.0).timeout


# --- Helpers -------------------------------------------------------------------------

func _cols(db: FacilityDB, table: String) -> Array:
	return db.table_schema(table).map(func(c): return c["name"])


func _pattern() -> String:
	return root.get_node("Game").case_query(case_id)


func _typed(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", NotebookArt.type_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot + ".png"))
	print("saved ", shot)
