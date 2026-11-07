extends SceneTree
## Design mock-ups of the terminal's keyword buttons (plan/teaching/keyword-buttons.md),
## drawn on the real Server Room A terminal in Level 1, for Augustine to pick from
## before the build. Four looks (A-D), each with a keyboard and a controller shot.
## Nothing here is wired into the game yet. Needs a display, at 2x the game's size:
##   xvfb-run -a -s "-screen 0 3200x1800x24" godot --rendering-driver vulkan \
##     --resolution 3200x1800 -s tools/keyword_button_shots.gd -- OUT_DIR

var out_dir := "user://keyword_button_shots"
var level: Node
var ui: TerminalUI
## The prototype's pieces, removed between designs.
var _added: Array[Node] = []
var _moved_output := false

## A player partway through Level 1: chapters 1-6 in their book, each word's uses
## so far out of 6 (Training wheels). SELECT and FROM are nearly off.
const WORDS := [["SELECT", 5], ["*", 4], ["FROM", 5], [";", 5], ["ORDER BY", 1], [",", 1],
	[".schema", 0], [".tables", 2], ["DESC", 0], ["LIMIT", 0], ["WHERE", 3], ["=", 3], ["' '", 3], ["AND", 0]]
const USES := 6
const TYPED := "SELECT * FROM door_controllers\nWHERE status = 'fault' AND "

const GOLD := Color("#ffcc59")
const AMBER := Color("#ffd27f")
const GREEN := Color(0.45, 1.0, 0.55)
const PAPER := Color(0.98, 0.93, 0.55)


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
	ui.run("SELECT * FROM doors;")
	ui.run("SELECT id, zone, status, location FROM door_controllers WHERE zone = '%s';" % level.zone)
	await _frames(5)

	for design in ["a", "b", "c", "d"]:
		for pad in [false, true]:
			_clear()
			InputGlyphs.pad = pad
			ui._show_foot()
			_build(design, pad)
			ui._input.text = TYPED
			ui._input.set_caret_line(1)
			ui._input.set_caret_column(ui._input.get_line(1).length())
			await _frames(8)
			_quiet()
			_save("%s_%s" % [design, "controller" if pad else "keyboard"])
	# The moment a word comes off, on design A (the notice is approved text).
	_clear()
	InputGlyphs.pad = false
	ui._show_foot()
	var gone := WORDS.filter(func(w): return w[0] != "SELECT")
	_build("a", false, gone)
	ui._input.text = TYPED
	level.hud.notice("No more training wheels! You've used SELECT 6 times. Now you type it yourself.", 30.0)
	await create_timer(0.6).timeout
	_quiet()
	_save("a_word_comes_off")
	quit()


# --- The designs ----------------------------------------------------------------

func _build(design: String, pad: bool, words: Array = WORDS) -> void:
	match design:
		"a":
			_design_a(pad, words)
		"b":
			_design_b(pad)
		"c":
			_design_c(pad)
		"d":
			_design_d(pad)


## A, keycaps: chunky keys under the input line, a row each for Words, Names and
## Found. Six pips under each word fill as it's used.
func _design_a(pad: bool, words: Array) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var rows := [["WORDS", words.map(func(w): return [w[0], w[1]]), Color(0.86, 0.8, 0.66)],
		["NAMES", _names().map(func(n): return [n, -1]), Color(0.62, 0.72, 0.8)],
		["FOUND", _found().map(func(n): return [n, -1]), PAPER]]
	var focus_at := 10  # WHERE, on a pad
	for r in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var tag := _tag(r[0], 76)
		line.add_child(tag)
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 5)
		flow.add_theme_constant_override("v_separation", 5)
		for i in r[1].size():
			var w: Array = r[1][i]
			flow.add_child(_keycap(w[0], w[1], r[2], pad and r[0] == "WORDS" and i == focus_at))
		line.add_child(flow)
		box.add_child(line)
	_under_input(box)
	if pad:
		_foot("D-pad: pick a word    A: add it    Y: run    B: step away    RB: back to typing")


func _keycap(text: String, used: int, cap: Color, focused: bool) -> Control:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = cap
	s.border_color = cap.darkened(0.45)
	s.border_width_bottom = 5
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.set_corner_radius_all(6)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 2
	s.content_margin_bottom = 3
	if focused:
		s.border_color = Color(1, 1, 1)
		s.set_border_width_all(4)
		s.border_width_bottom = 6
		s.shadow_color = Color(1, 1, 0.6, 0.6)
		s.shadow_size = 8
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	var l := _mono_label(text, 19, Color(0.12, 0.1, 0.08))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if used >= 0:
		var pips := _mono_label("●".repeat(used) + "○".repeat(USES - used), 14, Color(0.75, 0.2, 0.1) if used >= USES - 1 else Color(0.25, 0.22, 0.18))
		pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(pips)
	p.add_child(v)
	return p


## B, word bank card: a column at the screen's right, beside the results, in the
## terminal's own green. A word's text wears thin as it's used; one use left says so.
func _design_b(pad: bool) -> void:
	var hbox := _beside_output()
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 330
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.03, 0.09, 0.05)
	s.border_color = Color(0.2, 0.45, 0.25)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(_mono_label("WORD BANK", 20, AMBER))
	for sec in [["Words", WORDS], ["Names", _names().map(func(n): return [n, -1])], ["Found", _found().map(func(n): return [n, -1])]]:
		v.add_child(_mono_label(sec[0], 16, ThemeUtil.DIM))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 5)
		flow.add_theme_constant_override("v_separation", 5)
		for i in sec[1].size():
			var w: Array = sec[1][i]
			var color := GOLD if sec[0] == "Words" else (AMBER if sec[0] == "Names" else Color.WHITE)
			flow.add_child(_bank_word(w[0], w[1], color, pad and sec[0] == "Words" and i == 10))
		v.add_child(flow)
	card.add_child(v)
	hbox.add_child(card)
	if pad:
		_foot("RB: word bank    D-pad: pick a word    A: add it    Y: run    B: back to typing")


func _bank_word(text: String, used: int, color: Color, focused: bool) -> Control:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.16, 0.08)
	s.border_color = Color(0.25, 0.55, 0.3)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	if focused:
		s.border_color = Color(1, 1, 1)
		s.set_border_width_all(3)
		s.bg_color = Color(0.1, 0.3, 0.14)
	p.add_theme_stylebox_override("panel", s)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var fade := 1.0 if used < 0 else lerpf(1.0, 0.4, float(used) / USES)
	h.add_child(_mono_label(text, 20, Color(color, fade)))
	if used == USES - 1:
		h.add_child(_mono_label("1 left", 16, Color(1.0, 0.45, 0.35)))
	p.add_child(h)
	return p


## C, tabs and tiles: Augustine's "tab between the keyboard and the word buttons".
## A tab strip above the input picks Type, Words, Names or Found; the picked set
## shows as big tiles under it. A bar under each word counts its six uses.
func _design_c(pad: bool) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	if pad:
		tabs.add_child(_mono_label("LB ", 18, ThemeUtil.DIM))
	for name in ["Type", "Words", "Names", "Found"]:
		tabs.add_child(_tab(name, name == "Words"))
	if pad:
		tabs.add_child(_mono_label(" RB", 18, ThemeUtil.DIM))
	_above_input(tabs)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i in WORDS.size():
		grid.add_child(_tile(WORDS[i][0], WORDS[i][1], pad and i == 10))
	_under_input(grid)
	if pad:
		_foot("LB/RB: Type, Words, Names, Found    D-pad: pick    A: add it    Y: run    B: step away")


func _tab(name: String, on: bool) -> Control:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.32, 0.15) if on else Color(0.03, 0.09, 0.05)
	s.border_color = GREEN if on else Color(0.2, 0.45, 0.25)
	s.set_border_width_all(2)
	s.border_width_bottom = 0
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	p.add_child(_mono_label(name, 20, Color.WHITE if on else ThemeUtil.DIM))
	return p


func _tile(text: String, used: int, focused: bool) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.2, 0.1)
	s.border_color = Color(0.3, 0.6, 0.35)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 6
	s.content_margin_bottom = 4
	if focused:
		s.border_color = Color(1, 1, 1)
		s.set_border_width_all(4)
		s.bg_color = Color(0.12, 0.36, 0.18)
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var l := _mono_label(text, 24, GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	for i in USES:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(0, 5)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.color = (Color(1.0, 0.55, 0.3) if used >= USES - 1 else GREEN) if i < used else Color(0.15, 0.3, 0.18)
		bar.add_child(seg)
	v.add_child(bar)
	p.add_child(v)
	return p


## D, screen text: the words as plain terminal text in one strip under the input,
## [SELECT] [FROM], coloured as the screen colours them. Nothing counts on show
## until a word's last use, when it reads "1 left".
func _design_d(pad: bool) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 0)
	var items: Array = WORDS.map(func(w): return [w[0], w[1], GOLD])
	items.append(["|", -2, ThemeUtil.DIM])
	items += _names().map(func(n): return [n, -1, AMBER])
	items.append(["|", -2, ThemeUtil.DIM])
	items += _found().map(func(n): return [n, -1, Color.WHITE])
	for i in items.size():
		var it: Array = items[i]
		if it[1] == -2:
			flow.add_child(_mono_label(" │ ", 20, it[2]))
			continue
		var focused: bool = pad and i == 10
		var text: String = "[%s]" % it[0]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 0)
		var l := _mono_label(text, 21, Color.BLACK if focused else it[2])
		if focused:
			var bg := StyleBoxFlat.new()
			bg.bg_color = GOLD
			l.add_theme_stylebox_override("normal", bg)
		h.add_child(l)
		if it[1] == USES - 1:
			h.add_child(_mono_label("1 left ", 16, Color(1.0, 0.45, 0.35)))
		flow.add_child(h)
	_under_input(flow)
	if pad:
		_foot("RB: words    D-pad: pick    A: add it    Y: run    B: back to typing")


# --- Helpers --------------------------------------------------------------------

## Columns on this player's Tables page: door_controllers, found by now.
func _names() -> Array:
	var out := ["door_controllers", "doors"]
	for c in level.terminal.db.table_schema("door_controllers"):
		out.append(c["name"])
	return out


## Case board pieces found so far.
func _found() -> Array:
	return ["'fault'", "'%s'" % level.zone]


func _tag(text: String, width: int) -> Label:
	var l := _mono_label(text, 15, ThemeUtil.DIM)
	l.custom_minimum_size.x = width
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _mono_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", ThemeUtil.mono())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _under_input(node: Control) -> void:
	var vbox := ui._input.get_parent()
	vbox.add_child(node)
	vbox.move_child(node, ui._input.get_index() + 1)
	_added.append(node)


func _above_input(node: Control) -> void:
	var vbox := ui._input.get_parent()
	vbox.add_child(node)
	vbox.move_child(node, ui._input.get_index())
	_added.append(node)


## Put the screen's output in a row, so something can sit to its right.
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


func _foot(text: String) -> void:
	ui._foot.text = text


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


## No subtitle over the screen.
func _quiet() -> void:
	level.hud._subtitle.self_modulate = Color(1, 1, 1, 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot + ".png"))
	print("saved ", shot)
