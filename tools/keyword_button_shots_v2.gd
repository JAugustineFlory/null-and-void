extends SceneTree
## Mock-ups of the next-word buttons (plan/teaching/keyword-buttons.md, reworked
## 2026-11-07): only the words that can come next, only what this player has found,
## kept in their notebook with the case's pattern. PC uses design B's side panel,
## console design C's tabs and tiles. Drawn on Server Room A's terminal in Level 1.
## Nothing here is wired into the game yet. Needs a display, at 2x the game's size:
##   xvfb-run -a -s "-screen 0 3200x1800x24" godot --rendering-driver vulkan \
##     --resolution 3200x1800 -s tools/keyword_button_shots_v2.gd -- OUT_DIR

var out_dir := "user://keyword_button_shots_v2"
var level: Node
var ui: TerminalUI
var _added: Array[Node] = []
var _moved_output := false

const USES := 3
## SQL words found so far (chapters 1-6) and how often this player has used each.
const COMMANDS := {"SELECT": 2, "*": 1, "FROM": 2, ";": 2, "ORDER BY": 0, ",": 0, ".schema": 1, ".tables": 1,
	"DESC": 0, "LIMIT": 0, "WHERE": 1, "=": 1, "' '": 1, "AND": 0}
## The words that can start a statement, of those.
const STARTERS := ["SELECT", ".tables", ".schema"]
## What can follow a table, in the book's order.
const AFTER_TABLE := ["WHERE", "ORDER BY", "LIMIT", ";"]

const INK := Color(0.12, 0.15, 0.32)
const PENCIL := Color(0.35, 0.35, 0.37)
const RED_PEN := Color(0.7, 0.12, 0.1)
const PAPER := Color(0.96, 0.94, 0.86)
const STICKY := Color(0.98, 0.93, 0.55)
const CHIP := Color(0.9, 0.88, 0.8)
const GREEN := Color(0.45, 1.0, 0.55)
const GOLD := Color("#ffcc59")

## Tables on the Tables page (.tables), and the columns found: only for tables
## the player ran SELECT * on or .schema'd (Augustine's rule).
var tables: Array = []
var columns := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	game.new_run(7)
	level = load("res://scenes/level_1.tscn").instantiate()
	root.add_child(level)
	await _frames(20)
	level.hud.set_process(false)
	level.terminal.locked = false
	game.open_case("controller", "Which door controller keeps faulting?", ["door_controllers", "doors"], level.OBJ_CONTROLLER)
	game.set_pieces("controller", level.controller_pieces(level.zone), level.CONTROLLER_QUERY, level.CONTROLLER_STEPS)
	var t = level.terminal
	level.player.global_position = t.stand_point.global_position
	level.player.global_rotation = t.stand_point.global_rotation
	await _frames(10)
	t._on_used(level.player)
	await create_timer(2.5).timeout
	ui = level.terminal_ui
	ui.run(".tables")
	ui.run("SELECT * FROM doors;")
	ui.run(".schema door_controllers")
	game.collect_piece("controller", "zone", "doors")
	var db: FacilityDB = t.db
	tables = Array(db.table_names())
	tables.sort()
	for name in ["doors", "door_controllers"]:
		columns[name] = db.table_schema(name).map(func(c): return c["name"])
	await _frames(5)

	# PC, design B's side panel: the notebook down the right of the screen.
	for step in [["pc_1_start", ""], ["pc_2_after_select", "SELECT "], ["pc_3_after_from", "SELECT id FROM "]]:
		await _shot(step[0], step[1], func(): _pc_panel(step[1], true))
	await _shot("pc_4_normal", "SELECT id FROM door_controllers\nWHERE zone = '%s' AND " % level.zone, func(): _pc_panel("", false))

	# Console, design C's tabs and tiles, in the notebook under the input line.
	InputGlyphs.pad = true
	await _shot("console_1_start", "", func(): _console("", "Commands", COMMANDS))
	await _shot("console_2_after_select", "SELECT ", func(): _console("SELECT ", "Columns", COMMANDS))
	await _shot("console_3_after_from", "SELECT id FROM ", func(): _console("SELECT id FROM ", "Tables", COMMANDS))
	# Later on the floor: SELECT, FROM, ; and WHERE have been used 3 times. Their
	# next-word help has come off, so WHERE is found among every word in All words.
	var later := COMMANDS.duplicate()
	for w in ["SELECT", "FROM", ";", "WHERE", "*"]:
		later[w] = USES
	later["="] = 2
	later["' '"] = 2
	await _shot("console_4_all_words", "SELECT * FROM door_controllers ", func(): _console("SELECT * FROM door_controllers ", "All words", later))
	quit()


func _shot(shot: String, typed: String, build: Callable) -> void:
	_clear()
	ui._show_foot()
	build.call()
	ui._input.text = typed
	var last := ui._input.get_line_count() - 1
	ui._input.set_caret_line(last)
	ui._input.set_caret_column(ui._input.get_line(last).length())
	level.hud._subtitle.self_modulate = Color(1, 1, 1, 0)  # no subtitle over the screen
	await _frames(8)
	_save(shot)


# --- What can come next -----------------------------------------------------------

## The groups of words that can follow `typed`: [[group, [words]]] (a Columns group
## is [[table, [columns]]]). Only what this player has found.
func _next(typed: String, counts: Dictionary) -> Array:
	var t := typed.strip_edges().to_upper()
	var cmds := func(list: Array) -> Array:
		return list.filter(func(w): return counts.has(w) and counts[w] < USES)
	if t == "":
		return [["Commands", cmds.call(STARTERS)]]
	if t.ends_with("SELECT"):
		var cols := []
		for name in columns:
			cols.append([name, columns[name]])
		return [["Commands", cmds.call(["*"])], ["Columns", cols]]
	if t.ends_with("FROM"):
		return [["Tables", tables]]
	return [["Commands", cmds.call(AFTER_TABLE)]]


# --- PC: the notebook down the right (design B) -------------------------------------

func _pc_panel(typed: String, easy: bool) -> void:
	var hbox := _beside_output()
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 360
	var s := StyleBoxFlat.new()
	s.bg_color = PAPER
	s.border_color = Color(0.55, 0.68, 0.85)
	s.border_width_left = 3
	s.set_corner_radius_all(4)
	s.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", s)
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
		for g in _next(typed, COMMANDS):
			v.add_child(_hand(g[0], 23, PENCIL))
			if g[0] == "Columns":
				for tc in g[1]:
					v.add_child(_typed(tc[0] + ":", 18, PENCIL))
					v.add_child(_chips(tc[1], CHIP.lerp(Color(0.75, 0.82, 0.92), 0.6), {}))
			else:
				var paper := CHIP if g[0] == "Commands" else CHIP.lerp(Color(0.75, 0.82, 0.92), 0.6)
				v.add_child(_chips(g[1], paper, COMMANDS if g[0] == "Commands" else {}))
	card.add_child(v)
	hbox.add_child(card)


func _chips(words: Array, paper: Color, counts: Dictionary) -> HFlowContainer:
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
		var used: int = counts.get(w, -1)
		var fade := 1.0 if used < 0 else lerpf(1.0, 0.55, float(used) / USES)
		h.add_child(_typed(w, 23, Color(INK, fade)))
		if used == USES - 1:
			h.add_child(_hand("1 left", 22, RED_PEN))
		p.add_child(h)
		flow.add_child(p)
	return flow


# --- Console: tabs and tiles under the input (design C) ------------------------------

func _console(typed: String, active: String, counts: Dictionary) -> void:
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
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_hand("Pattern:", 26, PENCIL))
	top.add_child(_typed(_pattern(), 21, INK))
	v.add_child(top)

	var groups := {}
	for g in _next(typed, counts):
		groups[g[0]] = g[1]
	var all_words := counts.keys()
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	tabs.add_child(_typed("LB ", 18, PENCIL))
	for name in ["Commands", "Tables", "Columns", "Found", "All words"]:
		var n := 0
		if name == "All words":
			n = all_words.size()
		elif name == "Found":
			n = 0  # nothing valid here at these steps
		elif groups.has(name):
			n = groups[name].size() if name != "Columns" else groups[name].reduce(func(a, tc): return a + tc[1].size(), 0)
		tabs.add_child(_tab(name, n, name == active))
	tabs.add_child(_typed(" RB", 18, PENCIL))
	v.add_child(tabs)

	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var focus_first := true
	if active == "All words":
		for w in all_words:
			grid.add_child(_tile(w, -1, w == "WHERE"))
	elif active == "Columns":
		# One row per table, under its name.
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 6)
		for tc in groups.get("Columns", []):
			var row := HFlowContainer.new()
			row.add_theme_constant_override("h_separation", 8)
			var tag := _typed(tc[0] + ":", 19, PENCIL)
			tag.custom_minimum_size.x = 210
			row.add_child(tag)
			for c in tc[1]:
				row.add_child(_tile(c, -1, focus_first))
				focus_first = false
			rows.add_child(row)
		v.add_child(rows)
	else:
		for w in groups.get(active, []):
			grid.add_child(_tile(w, counts.get(w, -1), focus_first))
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
	var dim := n == 0 and not on
	h.add_child(_hand(name, 27, PENCIL if dim else INK))
	if n > 0:
		h.add_child(_typed(str(n), 19, RED_PEN if not on else PENCIL))
	p.add_child(h)
	return p


func _tile(text: String, used: int, focused: bool) -> Control:
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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var l := _typed(text, 24, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if used >= 0:
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 3)
		for i in USES:
			var seg := ColorRect.new()
			seg.custom_minimum_size = Vector2(0, 5)
			seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			seg.color = (RED_PEN if used >= USES - 1 else INK) if i < used else Color(0.8, 0.8, 0.78)
			bar.add_child(seg)
		v.add_child(bar)
	p.add_child(v)
	return p


# --- Helpers -------------------------------------------------------------------------

## The case page's code block as it stands: found pieces filled in, the rest as blanks.
func _pattern() -> String:
	return root.get_node("Game").case_query("controller")


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
