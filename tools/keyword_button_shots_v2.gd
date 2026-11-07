extends SceneTree
## Mock-ups of the next-word buttons (plan/teaching/keyword-buttons.md, reworked
## 2026-11-07): only the words that can come next, only what this player has found,
## kept in their notebook with the case's pattern. PC uses design B's side panel,
## console design C's tabs and tiles. Nothing here is wired into the game yet.
## Needs a display, at 2x the game's size:
##   xvfb-run -a -s "-screen 0 3200x1800x24" godot --rendering-driver vulkan \
##     --resolution 3200x1800 -s tools/keyword_button_shots_v2.gd -- OUT_DIR

var out_dir := "user://keyword_button_shots_v2"
var level: Node
var ui: TerminalUI
var _added: Array[Node] = []
var _moved_output := false

const USES := 3

const INK := Color(0.12, 0.15, 0.32)
const PENCIL := Color(0.35, 0.35, 0.37)
const RED_PEN := Color(0.7, 0.12, 0.1)
const PAPER := Color(0.96, 0.94, 0.86)
const CHIP := Color(0.9, 0.88, 0.8)
const NAME_CHIP := Color(0.81, 0.85, 0.88)

## The player in the shot: SQL words found and how often each was used, the words
## that can start a statement, what can follow a table, the tables on their
## Tables page, the columns found (Augustine's rule: SELECT * or .schema), and the
## case whose pattern the notebook shows.
var counts := {}
var starters: Array = []
var after_table: Array = []
var tables: Array = []
var columns := {}
var case_id := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	# A part at a time ("g" or "14"), as one run of both takes too long.
	var part: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "g"
	if part == "g":
		await _floor_g()
	else:
		await _floor_14(part == "console")
	quit()


## PC on Easy, Normal and the word coming off, at the front desk on G: the player
## has Easy SQL's first two chapters and has run one query.
func _floor_g() -> void:
	var game = root.get_node("Game")
	game.new_run(7)
	level = load("res://scenes/level_0.tscn").instantiate()
	root.add_child(level)
	await _frames(20)
	level.hud.set_process(false)
	# Out of the van and at the front desk, as the tests do it.
	var p: Player = level.player
	level._release_camera(p)
	p.seated = false
	p.sit_held = false
	if p.is_sitting():
		p.stand_up(true)
	p.global_position = Vector3(1.0, 0.1, -1.9)
	for i in 10:
		await physics_frame
	var t = level.desk_terminal
	t.enabled = true
	t.locked = false
	await _step_up(t)
	ui.run("SELECT * FROM memo_fragments;")
	case_id = "memo_order"
	game.open_case(case_id, "Which scrap comes first?", ["memo_fragments"], level.OBJ_ORDER)
	game.set_pieces(case_id, level.ORDER_PIECES, level.ORDER_QUERY, level.ORDER_STEPS)
	counts = {"SELECT": 1, "*": 1, "FROM": 1, ";": 1, "ORDER BY": 0}
	starters = ["SELECT"]
	after_table = ["ORDER BY", ";"]
	tables = ["memo_fragments"]
	columns = {"memo_fragments": _cols(t.db, "memo_fragments")}
	await _frames(5)
	level.hud._notice.visible = false  # Ch. 2's arrival, on the real floor; not what these show

	await _shot("pc_1_easy_start", "", func(): _pc_panel("", true))
	await _shot("pc_2_easy_after_select", "SELECT ", func(): _pc_panel("SELECT ", true))
	await _shot("pc_3_easy_after_from", "SELECT * FROM ", func(): _pc_panel("SELECT * FROM ", true))
	await _shot("pc_5_normal", "SELECT * FROM memo_fragments ", func(): _pc_panel("", false))

	# The third query: SELECT, *, FROM and ; reach 3 together and come off. The
	# player types SELECT; the columns are still buttons.
	ui.run("SELECT * FROM memo_fragments ORDER BY piece_no;")
	for w in ["SELECT", "*", "FROM", ";"]:
		counts[w] = USES
	counts["ORDER BY"] = 1
	keep_notice = true
	level.hud._notice.visible = true
	level.hud._notice.grow_vertical = Control.GROW_DIRECTION_BEGIN
	level.hud._notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	level.hud._notice.custom_minimum_size.x = 1200
	level.hud.notice("No more training wheels! You've used SELECT, FROM, * and ; 3 times or more. Now you type them yourself.", 60.0)
	await create_timer(0.6).timeout
	await _shot("pc_4_easy_words_came_off", "SELECT ", func(): _pc_panel("SELECT ", true))
	keep_notice = false
	_clear()
	ui.close()
	level.queue_free()
	await _frames(5)


## The Tables page, a wide table, the setting, and the console shots, in Server
## Room A on 14.
func _floor_14(console: bool) -> void:
	var game = root.get_node("Game")
	game.new_run(7)
	level = load("res://scenes/level_1.tscn").instantiate()
	root.add_child(level)
	await _frames(20)
	level.hud.set_process(false)
	var t = level.terminal
	t.locked = false
	case_id = "controller"
	game.open_case(case_id, "Which door controller keeps faulting?", ["door_controllers", "doors"], level.OBJ_CONTROLLER)
	game.set_pieces(case_id, level.controller_pieces(level.zone), level.CONTROLLER_QUERY, level.CONTROLLER_STEPS)
	await _step_up(t)
	var db: FacilityDB = t.db
	counts = {"SELECT": 2, "*": 1, "FROM": 2, ";": 2, "ORDER BY": 0, ",": 0, ".schema": 1, ".tables": 1,
		"DESC": 0, "LIMIT": 0, "WHERE": 1, "=": 1, "' '": 1, "AND": 0}
	starters = ["SELECT", ".tables", ".schema"]
	after_table = ["WHERE", "ORDER BY", "LIMIT", ";"]
	tables = Array(db.table_names())
	tables.sort()
	columns = {"doors": _cols(db, "doors"), "door_controllers": _cols(db, "door_controllers")}
	if console:
		await _console_shots()
		return

	# The Tables page under Augustine's rule: .tables writes the names, and a table's
	# columns come in with .schema or SELECT * on it.
	ui.run(".tables")
	for name in db.table_names():
		game.notebook_tables[name] = []
	await _tables_page("pc_6_tables_before_schema")
	await _step_up(t)
	ui.run(".schema door_controllers")
	game.notebook_tables["door_controllers"] = _cols(db, "door_controllers")
	await _tables_page("pc_7_tables_after_schema")
	await _step_up(t)

	# A wide result with the notebook open, then folded away.
	ui.run("SELECT * FROM doors;")
	game.collect_piece(case_id, "zone", "doors")
	ui.run("SELECT * FROM door_controllers;")
	await _shot("pc_8_wide_table_open", "", func(): _pc_panel("", true))
	await _shot("pc_9_wide_table_folded", "", func(): _pc_folded())

	# The setting, in the pause menu's Controls page.
	await _settings_shot("pc_10_setting_keep_the_buttons")


## Console: the buttons never come off; Easy shows the pattern, Normal doesn't.
func _console_shots() -> void:
	ui.run(".tables")
	ui.run("SELECT * FROM doors;")
	ui.run(".schema door_controllers")
	root.get_node("Game").collect_piece(case_id, "zone", "doors")
	InputGlyphs.pad = true
	await _shot("console_1_easy_start", "", func(): _console("", "Commands", true))
	await _shot("console_2_easy_after_select", "SELECT ", func(): _console("SELECT ", "Columns", true))
	await _shot("console_3_easy_after_from", "SELECT id FROM ", func(): _console("SELECT id FROM ", "Tables", true))
	await _shot("console_4_normal_after_select", "SELECT ", func(): _console("SELECT ", "Columns", false))
	InputGlyphs.pad = false


func _step_up(t: Node) -> void:
	level.player.global_position = t.stand_point.global_position
	level.player.global_rotation = t.stand_point.global_rotation
	await _frames(10)
	t._on_used(level.player)
	await create_timer(2.5).timeout
	ui = level.terminal_ui


func _shot(shot: String, typed: String, build: Callable) -> void:
	_clear()
	ui._show_foot()
	build.call()
	ui._input.text = typed
	var last := ui._input.get_line_count() - 1
	ui._input.set_caret_line(last)
	ui._input.set_caret_column(ui._input.get_line(last).length())
	_hide_subtitle()
	await _frames(8)
	_save(shot)


## No subtitle, prompt or notice over the shot (except a notice it's about).
var keep_notice := false


func _hide_subtitle() -> void:
	level.hud._subtitle.self_modulate = Color(1, 1, 1, 0)
	level.hud._prompt.self_modulate = Color(1, 1, 1, 0)
	level.hud._notice.self_modulate = Color(1, 1, 1, 1 if keep_notice else 0)


## Step back from the terminal and open the notebook on its Tables page.
func _tables_page(shot: String) -> void:
	_clear()
	ui.close()
	await create_timer(1.5).timeout
	level.player.input_locked = false
	level.notebook.open()
	await create_timer(1.2).timeout
	level.notebook.pages.show_page(NotebookPages.Page.TABLES)
	_hide_subtitle()
	await create_timer(0.8).timeout
	_save(shot)
	level.notebook.close()
	await create_timer(1.0).timeout


func _settings_shot(shot: String) -> void:
	_clear()
	ui.close()
	await create_timer(1.5).timeout
	level._pause.visible = true
	level._show_pause_page("controls")
	var page: VBoxContainer = level._pause_pages["controls"]
	var settings := page.get_child(0)
	var section := _terminal_help_settings()
	settings.add_child(section)
	settings.move_child(section, 1)
	_hide_subtitle()
	await _frames(10)
	_save(shot)
	settings.remove_child(section)
	section.free()
	level._pause.visible = false
	await _step_up(level.terminal)


## The draft "Terminal help" setting (spec section 8), at the top of Controls.
func _terminal_help_settings() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ThemeUtil.label("Terminal help", 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for pick in [["Easy", true], ["Normal", false]]:
		var b := Button.new()
		b.text = pick[0]
		b.toggle_mode = true
		b.button_pressed = pick[1]
		b.custom_minimum_size = Vector2(150, 40)
		b.add_theme_font_size_override("font_size", 20)
		row.add_child(b)
	box.add_child(row)
	var why := ThemeUtil.label("Buttons offer the words that can come next. Use one 3 times and you type it yourself.", 16, Color(0.85, 0.85, 0.85))
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size.x = 520
	box.add_child(why)
	var keep := CheckButton.new()
	keep.text = "Keep the buttons"
	keep.add_theme_font_size_override("font_size", 18)
	box.add_child(keep)
	var keep_why := ThemeUtil.label("Words stay as buttons, however often you use them.", 16, Color(0.85, 0.85, 0.85))
	keep_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keep_why.custom_minimum_size.x = 520
	box.add_child(keep_why)
	var reset := Button.new()
	reset.text = "Put the training wheels back on"
	reset.add_theme_font_size_override("font_size", 18)
	box.add_child(reset)
	return box


# --- What can come next -----------------------------------------------------------

## The groups of words that can follow `typed`: [[group, words]], where a Columns
## group's words are [[table, [columns]]]. `retire`: words used 3 times are off.
func _next(typed: String, retire: bool) -> Array:
	var t := typed.strip_edges().to_upper()
	var cmds := func(list: Array) -> Array:
		return list.filter(func(w): return counts.has(w) and (not retire or counts[w] < USES))
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


# --- PC: the notebook down the right (design B) -------------------------------------

func _pc_panel(typed: String, easy: bool) -> void:
	var hbox := _beside_output()
	var card := _paper_card()
	card.custom_minimum_size.x = 380
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_child(_hand("Notebook", 32, INK))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	head.add_child(_hand("fold ▸", 24, PENCIL))
	v.add_child(head)
	v.add_child(_hand("The case's pattern", 26, PENCIL))
	var pattern := _typed(_pattern(), 21, INK)
	pattern.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pattern)
	if easy:
		v.add_child(_rule())
		v.add_child(_hand("Can come next", 26, PENCIL))
		for g in _next(typed, true):
			if g[1].is_empty():
				continue
			v.add_child(_hand(g[0], 23, PENCIL))
			if g[0] == "Columns":
				for tc in g[1]:
					v.add_child(_typed(tc[0] + ":", 18, PENCIL))
					v.add_child(_chips(tc[1], NAME_CHIP, false))
			else:
				v.add_child(_chips(g[1], CHIP if g[0] == "Commands" else NAME_CHIP, g[0] == "Commands"))
	card.add_child(v)
	hbox.add_child(card)


## The notebook folded away: a tab at the screen's edge, and the results get the width.
func _pc_folded() -> void:
	var hbox := _beside_output()
	var tab := _paper_card()
	tab.custom_minimum_size.x = 44
	var l := _hand("◂ Notebook", 26, INK)
	l.rotation_degrees = -90
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(30, 180)
	l.position = Vector2(2, 170)
	holder.add_child(l)
	tab.add_child(holder)
	tab.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(tab)


func _paper_card() -> PanelContainer:
	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = PAPER
	s.border_color = Color(0.55, 0.68, 0.85)
	s.border_width_left = 3
	s.set_corner_radius_all(4)
	s.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", s)
	return card


## Word buttons. Commands show their uses out of 3 (red on the last one).
func _chips(words: Array, paper: Color, counted: bool) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for w in words:
		var p := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = paper
		s.border_color = INK
		s.set_border_width_all(1)
		s.border_width_bottom = 3
		s.set_corner_radius_all(4)
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 1
		s.content_margin_bottom = 1
		p.add_theme_stylebox_override("panel", s)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.add_child(_typed(w, 23, INK))
		if counted:
			var used: int = counts.get(w, 0)
			h.add_child(_typed("●".repeat(used) + "○".repeat(USES - used), 14, RED_PEN if used >= USES - 1 else PENCIL))
		p.add_child(h)
		flow.add_child(p)
	return flow


# --- Console: tabs and tiles under the input (design C) ------------------------------

## On console the buttons never come off. `easy` shows the case's pattern.
func _console(typed: String, active: String, easy: bool) -> void:
	var tray := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = PAPER
	s.border_color = Color(0.55, 0.68, 0.85)
	s.border_width_top = 3
	s.set_corner_radius_all(4)
	s.set_content_margin_all(8)
	tray.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if easy:
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		top.add_child(_hand("Pattern:", 26, PENCIL))
		top.add_child(_typed(_pattern(), 21, INK))
		v.add_child(top)

	var groups := {}
	for g in _next(typed, false):
		groups[g[0]] = g[1]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	tabs.add_child(_typed("LB ", 18, PENCIL))
	for name in ["Commands", "Tables", "Columns", "Found"]:
		var n := 0
		if groups.has(name):
			n = groups[name].size() if name != "Columns" else groups[name].reduce(func(a, tc): return a + tc[1].size(), 0)
		tabs.add_child(_tab(name, n, name == active))
	tabs.add_child(_typed(" RB", 18, PENCIL))
	v.add_child(tabs)

	var focus_first := true
	if active == "Columns":
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 6)
		for tc in groups.get("Columns", []):
			var row := HFlowContainer.new()
			row.add_theme_constant_override("h_separation", 8)
			var tag := _typed(tc[0] + ":", 19, PENCIL)
			tag.custom_minimum_size.x = 210
			row.add_child(tag)
			for c in tc[1]:
				row.add_child(_tile(c, focus_first))
				focus_first = false
			rows.add_child(row)
		v.add_child(rows)
	else:
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for w in groups.get(active, []):
			grid.add_child(_tile(w, focus_first))
			focus_first = false
		v.add_child(grid)
	tray.add_child(v)
	_under_input(tray)
	ui._foot.text = "LB/RB: tabs    D-pad: pick    A: add it    Y: run    B: step away"


func _tab(name: String, n: int, on: bool) -> Control:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1) if on else Color(0.88, 0.86, 0.78)
	s.border_color = INK if on else Color(0.6, 0.6, 0.6)
	s.set_border_width_all(2)
	s.border_width_bottom = 0
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(_hand(name, 27, PENCIL if n == 0 and not on else INK))
	if n > 0:
		h.add_child(_typed(str(n), 19, RED_PEN if not on else PENCIL))
	p.add_child(h)
	return p


func _tile(text: String, focused: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = 112
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1)
	s.border_color = INK
	s.set_border_width_all(2)
	s.border_width_bottom = 4
	s.set_corner_radius_all(8)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	if focused:
		s.bg_color = Color(1.0, 0.95, 0.6)
		s.border_color = Color(0.85, 0.35, 0.1)
		s.set_border_width_all(4)
	p.add_theme_stylebox_override("panel", s)
	var l := _typed(text, 24, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


# --- Helpers -------------------------------------------------------------------------

func _cols(db: FacilityDB, table: String) -> Array:
	return db.table_schema(table).map(func(c): return c["name"])


## The case page's code block as it stands: found pieces filled in, the rest as blanks.
func _pattern() -> String:
	return root.get_node("Game").case_query(case_id)


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.55, 0.68, 0.85, 0.7)
	r.custom_minimum_size = Vector2(0, 2)
	return r


func _hand(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", NotebookArt.hand_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _typed(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", NotebookArt.type_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _under_input(node: Control) -> void:
	var vbox := ui._input.get_parent()
	vbox.add_child(node)
	vbox.move_child(node, ui._input.get_index() + 1)
	_added.append(node)


func _beside_output() -> HBoxContainer:
	var vbox := ui._output.get_parent()
	var at := ui._output.get_index()
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)
	vbox.move_child(hbox, at)
	ui._output.reparent(hbox, false)
	ui._output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_moved_output = true
	_added.append(hbox)
	return hbox


func _clear() -> void:
	if _moved_output:
		var hbox := ui._output.get_parent()
		var vbox := hbox.get_parent()
		ui._output.reparent(vbox, false)
		vbox.move_child(ui._output, hbox.get_index())
		_moved_output = false
	for n in _added:
		n.get_parent().remove_child(n)
		n.free()
	_added.clear()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot + ".png"))
	print("saved ", shot)
