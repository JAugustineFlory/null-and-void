class_name TerminalNotebook
extends Node
## At a terminal, your notebook held below the screen (Augustine, 2026-11-07
## 01:45Z; mock-ups in plan/teaching/keyword-buttons-designs/v3/). The screen keeps
## the whole view, with the notebook's top edge peeking in below it. Look down
## (Tab, or View on a pad) and the notebook comes up in your hands: the left page
## has the case and your query so far, the right page tabs of buttons for the
## words that can come next (KeywordHelp). Look up and the screen is yours again.
##
## Easy on a keyboard: the buttons, each SQL word's with its uses out of 3.
## Normal on a keyboard: the case and your query so far, no buttons.
## On a pad the buttons are always there and never come off (bigger tiles, the
## d-pad moves between them); Easy also shows the case's query, Normal doesn't.
##
## Picking a word writes it into the terminal's typing line, exactly as if it
## had been typed (TerminalUI.insert_word). While you look down, the keys to look
## back up and to step away are always on screen (Augustine, 2026-11-09).

## Where the book is held, from where it's read (HeldNotebook.hold_offset): at the
## screen, low enough that only its top edge shows; looked down, a little lower and
## further off than for reading, so the screen's typing line stays in view above it.
const PEEK := Vector3(0, -0.19, 0)
const HOLD := Vector3(0, -0.06, -0.06)
const LOOK_TIME := 0.25
const CHIP := Color(0.93, 0.91, 0.84)
const NAME_CHIP := Color(0.84, 0.88, 0.93)
const FOCUS_CHIP := Color(1.0, 0.95, 0.6)
const FOCUS_EDGE := Color(0.85, 0.35, 0.1)

## Player text: DRAFT for Augustine's word-for-word OK (plan/approvals/keyword-buttons-text.md).
const HINT := "[Tab] Look down: your notebook"
const PROMPTS := "Tab  Look up at the screen        Esc  Step away"
const PAD_PROMPTS := "%s  Look up        %s  Step away        %s  Add the word        %s  Run        %s %s  Turn the tabs"
const CASE_HEAD := "The case"
const QUERY_HEAD := "My query so far"
const NO_CASE := "No case open right now."
const NEXT_HEAD := "Can come next"
const NOTHING_NEXT := "Nothing on this tab can come next."
const TIP := "Click a word to add it to your query. You can still type."
const PAD_TIP := "%s to add a word, %s %s to turn the tabs. %s runs the query."

var ui: TerminalUI
var player: Node
## The notebook in your hands, on a terminal's glass (Game.diegetic_ui).
var held: HeldNotebook
var view: NotebookView
## Looking down at the notebook (or about to be).
var down := false
## 0 looking at the screen, 1 looked down.
var amount := 0.0
## The open tab, and whether it was picked by hand (kept till the query changes).
var tab := "Commands"
var _tab_by_hand := false
## On a pad: which of the open tab's words the d-pad is on.
var focus := 0
## The words on the open tab, in order: {word, replace, box}.
var chips: Array[Dictionary] = []
var _offer := {}
var _layer: CanvasLayer
var _hint: Button
var _prompts: Label
var _prompt_box: PanelContainer
## Full-screen terminals: the notebook over the bottom of the view instead.
var _flat: Control
var _open := false
var _layout := ""  # which tabs the book has now ("buttons", "none")
var _shown_text := "\u0001"


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "TerminalNotebookLayer"
	_layer.layer = 22  # over the terminal (20)
	_layer.visible = false
	add_child(_layer)
	_flat = Control.new()
	_flat.name = "Flat"
	_flat.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flat.anchor_top = 0.42
	_flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flat.visible = false
	_layer.add_child(_flat)
	_hint = Button.new()
	_hint.name = "LookDownHint"
	_hint.flat = true
	_hint.focus_mode = Control.FOCUS_NONE
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -300
	_hint.offset_right = 300
	_hint.offset_top = -46
	_hint.offset_bottom = -10
	_hint.add_theme_font_size_override("font_size", 18)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_hint.add_theme_color_override(c, Color(1, 1, 1, 0.92) if c == "font_color" else Color(1.0, 0.92, 0.55))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.pressed.connect(func(): look(true))
	_layer.add_child(_hint)
	_prompt_box = PanelContainer.new()
	_prompt_box.name = "LookedDownPrompts"
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.8)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_prompt_box.add_theme_stylebox_override("panel", sb)
	_prompt_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_prompt_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_box.offset_top = 10
	_prompts = ThemeUtil.label("", 17, Color(1, 1, 1, 0.95))
	_prompts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_box.add_child(_prompts)
	_layer.add_child(_prompt_box)


## Keyboard or pad, whichever was used last: the prompts and the buttons follow.
## Listened for only while the terminal's open.
func _on_device(_pad: bool) -> void:
	_show_prompts()
	refresh(true)


## The terminal is open: the notebook's top edge below the screen (or, on a
## full-screen terminal, only the hint), ready to look down at.
func open(terminal_ui: TerminalUI, by: Node) -> void:
	ui = terminal_ui
	_open = true
	down = false
	amount = 0.0
	_tab_by_hand = false
	var on_glass := ui.is_on_screen() and by != null and by.get("camera") is Camera3D
	if by != player or (held == null) != (not on_glass):
		_drop_book()
	player = by
	if view == null:
		view = NotebookView.new()
		view.tab_pressed.connect(_on_tab)
		if on_glass:
			var look := NetPlayers.look_for(ui, ui.multiplayer.get_unique_id())
			held = HeldNotebook.attach(player.camera, look)
			held.name = "TerminalNotebook"
			held.set_content(view)
			held.hold_offset = PEEK
		else:
			_flat.add_child(view)
			view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var dim := view.get_node_or_null("Dim")
			if dim:
				dim.visible = false
	_layout = ""
	_shown_text = "\u0001"
	refresh(true)
	if held:
		held.visible = true
		held.set_process_input(false)  # the pages take clicks only once you look down
		held.open_book()
	_layer.visible = true
	var watch := InputGlyphs.watch(self)
	if not watch.changed.is_connected(_on_device):
		watch.changed.connect(_on_device)
	_apply()


## Stepping away: straight back to the screen, and the notebook goes.
func close() -> void:
	if not _open:
		return
	_open = false
	down = false  # the view comes back up as you step back (_process)
	_apply()
	_layer.visible = false
	var watch := InputGlyphs.watch(self)
	if watch.changed.is_connected(_on_device):
		watch.changed.disconnect(_on_device)
	if held and is_instance_valid(held):
		held.close_book()


func is_open() -> bool:
	return _open


func _drop_book() -> void:
	if held and is_instance_valid(held):
		held.queue_free()
	elif view and is_instance_valid(view):
		view.queue_free()
	held = null
	view = null


## Look down at the notebook (true) or back up at the screen (false).
func look(on: bool) -> void:
	if not _open or on == down:
		return
	down = on
	focus = 0
	if held:
		held.set_process_input(on)
	refresh(true)
	if on:
		_first_tip()


func toggle() -> void:
	look(not down)


func _process(delta: float) -> void:
	if not _open and amount <= 0.0:
		return
	var target := 1.0 if down else 0.0
	if amount != target:
		amount = move_toward(amount, target, delta / LOOK_TIME)
		_apply()


## Pose the view and the book for `amount`, and show the right prompts.
func _apply() -> void:
	var k := smoothstep(0.0, 1.0, amount)
	if player and is_instance_valid(player) and "terminal_look" in player:
		player.terminal_look = k if held else 0.0
	if held and is_instance_valid(held):
		held.hold_offset = PEEK.lerp(HOLD, k)
	# Held at that distance, the book would sit inside the terminal's keyboard.
	var screen = ui.terminal.get("screen") if ui and ui.terminal and is_instance_valid(ui.terminal) else null
	if screen and screen.get("keyboard"):
		screen.keyboard.visible = not (_open and held and k > 0.3)
	_flat.visible = _open and held == null and down
	if ui:
		ui.make_room(0.42 if _flat.visible else 1.0)
	_hint.visible = _open and not down
	_prompt_box.visible = _open and down
	_show_prompts()


func _show_prompts() -> void:
	_hint.text = InputGlyphs.text(HINT)
	if InputGlyphs.pad:
		_prompts.text = PAD_PROMPTS % [InputGlyphs.of("notebook"), InputGlyphs.of("ui_cancel"), InputGlyphs.of("ui_accept"),
			InputGlyphs.of("alt_interact"), InputGlyphs.of("ui_tab_prev"), InputGlyphs.of("ui_tab_next")]
	else:
		_prompts.text = PROMPTS


## The first time the buttons show, a word on how they work.
func _first_tip() -> void:
	var net := get_node_or_null("/root/Net")
	if not _buttons() or net == null or net.get("profile") == null or net.profile.buttons_tip:
		return
	net.profile.buttons_tip = true
	net.profile.save()
	var hud = ui._hud() if ui else null
	if hud:
		var tip := PAD_TIP % [InputGlyphs.of("ui_accept"), InputGlyphs.of("ui_tab_prev"), InputGlyphs.of("ui_tab_next"), InputGlyphs.of("alt_interact")] if InputGlyphs.pad else TIP
		hud.notice(tip, 5.0)


# --- What's on the pages -------------------------------------------------------------

## Are there buttons? Always on a pad; on a keyboard, on Easy.
static func _buttons() -> bool:
	KeywordHelp.load_settings()
	return InputGlyphs.pad or KeywordHelp.mode == "easy"


## Does the left page show the case's query? Always on a keyboard; on a pad, on Easy.
static func _shows_query() -> bool:
	KeywordHelp.load_settings()
	return not InputGlyphs.pad or KeywordHelp.mode == "easy"


## The query changed (or what's been found did): redraw the pages. `force` redraws
## even if the text is the same.
func refresh(force := false) -> void:
	if view == null or ui == null:
		return
	_show_prompts()
	var before := ui.button_text()
	if before == _shown_text and not force:
		return
	if before != _shown_text:
		_tab_by_hand = false
		focus = 0
	_shown_text = before
	var game := get_node_or_null("/root/Game")
	var buttons := _buttons()
	var layout := ("pad" if InputGlyphs.pad else "keys") if buttons else "none"
	if layout != _layout:
		_layout = layout
		for c in view._tabs.get_children():
			view._tabs.remove_child(c)
			c.free()
		view._tab_buttons.clear()
		if buttons:
			for name in KeywordHelp.TABS:
				view.add_tab(name)
	_offer = KeywordHelp.next_words(before, _found(game)) if game and buttons else {}
	if buttons and not _tab_by_hand:
		tab = KeywordHelp.best_tab(_offer)
	if buttons:
		view.select_tab(tab)
	view.clear_pages()
	chips.clear()
	_left_page(game)
	if buttons:
		_right_page()


## What this player has found, with the words that have come off taken out.
func _found(game: Node) -> Dictionary:
	var have := KeywordHelp.found(game)
	var net := get_node_or_null("/root/Net")
	if not InputGlyphs.pad and net and net.get("profile") != null:
		have.commands = have.commands.filter(func(w): return not net.profile.words_off.has(w))
	return have


func _left_page(game: Node) -> void:
	view.left.add_child(NotebookArt.heading(CASE_HEAD))
	var id := ""
	if game:
		id = ui.terminal.hint_case() if ui.terminal and ui.terminal.has_method("hint_case") else ""
		if id == "" or not game.case_info(id).get("open", false):
			id = game.current_case()
	if id == "":
		view.left.add_child(NotebookArt.hand(NO_CASE, 28, NotebookArt.PENCIL))
		return
	var objective: String = game.case_objective(id)
	var title := str(game.case_info(id).get("title", ""))
	view.left.add_child(NotebookArt.hand(objective if objective != "" else title, 28))
	var q: String = game.case_query(id)
	if q == "" or not _shows_query():
		return
	view.left.add_child(NotebookArt.hand(QUERY_HEAD, 26, NotebookArt.PENCIL))
	view.left.add_child(NotebookArt.code(_lines(q), 32))


## A query on the page a clause to a line, as the case page writes it.
static func _lines(q: String) -> String:
	for w in [" WHERE ", " ORDER BY ", " GROUP BY ", " LIMIT ", " SET "]:
		q = q.replace(w, "\n" + w.strip_edges() + " ")
	return q.replace(" AND ", "\n  AND ").replace(" OR ", "\n  OR ")


func _right_page() -> void:
	var pad := InputGlyphs.pad
	view.right.add_child(NotebookArt.heading(tab))
	view.right.add_child(NotebookArt.hand(NEXT_HEAD, 26, NotebookArt.PENCIL))
	var replace: int = _offer.get("replace", 0)
	var words: Array = []
	if tab == "Columns":
		for g in _offer.get("Columns", []):
			for c in g[1]:
				words.append(c)
	else:
		words = _offer.get(tab, [])
	if words.is_empty():
		view.right.add_child(NotebookArt.hand(NOTHING_NEXT, 24, NotebookArt.PENCIL))
		return
	var small := words.size() > 12
	if tab == "Columns":
		for g in _offer.get("Columns", []):
			view.right.add_child(_type(str(g[0]), 24, NotebookArt.PENCIL))
			view.right.add_child(_flow(g[1], replace, false, pad, small))
	else:
		view.right.add_child(_flow(words, replace, tab == "Commands" and not pad, pad, small))
	focus = clampi(focus, 0, chips.size() - 1)
	_show_focus()


## A row of word buttons. `counted`: each shows its uses out of 3 (red on the last).
func _flow(words: Array, replace: int, counted: bool, pad: bool, small: bool) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10 if pad else 8)
	flow.add_theme_constant_override("v_separation", 10 if pad else 8)
	var net := get_node_or_null("/root/Net")
	for w in words:
		var box := PanelContainer.new()
		box.name = "Word"
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		box.set_meta("word", w)
		box.add_theme_stylebox_override("panel", _chip_style(CHIP if tab == "Commands" else NAME_CHIP, pad, false))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var size := (30 if small else 36) if pad else (30 if small else 38)
		h.add_child(_type(str(w), size, NotebookArt.INK))
		if counted and KeywordHelp.is_counted(str(w)) and net and net.get("profile") != null:
			var used := mini(net.profile.uses_of(w), KeywordHelp.USES)
			var dots := _type("●".repeat(used) + "○".repeat(KeywordHelp.USES - used), 22, NotebookArt.RED_PEN if used >= KeywordHelp.USES - 1 else NotebookArt.PENCIL)
			dots.name = "Uses"
			h.add_child(dots)
		box.add_child(h)
		var i := chips.size()
		box.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				pick(i))
		box.mouse_entered.connect(func(): if not InputGlyphs.pad: box.add_theme_stylebox_override("panel", _chip_style(CHIP if tab == "Commands" else NAME_CHIP, false, true)))
		box.mouse_exited.connect(func(): if not InputGlyphs.pad: box.add_theme_stylebox_override("panel", _chip_style(CHIP if tab == "Commands" else NAME_CHIP, false, false)))
		flow.add_child(box)
		chips.append({"word": w, "replace": replace, "box": box})
	return flow


static func _chip_style(paper: Color, pad: bool, lit: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = FOCUS_CHIP if lit else paper
	s.border_color = FOCUS_EDGE if lit and pad else NotebookArt.INK
	s.set_border_width_all((5 if lit else 2) if pad else 1)
	s.border_width_bottom = maxi(s.border_width_bottom, 4)
	s.set_corner_radius_all(8 if pad else 5)
	s.content_margin_left = 14 if pad else 10
	s.content_margin_right = 14 if pad else 10
	s.content_margin_top = 3 if pad else 2
	s.content_margin_bottom = 3 if pad else 2
	return s


static func _type(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", NotebookArt.type_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## On a pad, light up the word the d-pad is on.
func _show_focus() -> void:
	if not InputGlyphs.pad:
		return
	for i in chips.size():
		var paper := CHIP if tab == "Commands" else NAME_CHIP
		chips[i].box.add_theme_stylebox_override("panel", _chip_style(paper, true, i == focus))


## Write word `i` of the open tab into the typing line.
func pick(i: int) -> void:
	if i < 0 or i >= chips.size() or ui == null:
		return
	ui.insert_word(str(chips[i].word), int(chips[i].replace))


## The words on the open tab, as written (for tests).
func words() -> Array:
	return chips.map(func(c): return c.word)


func _on_tab(name: String) -> void:
	tab = name
	_tab_by_hand = true
	focus = 0
	refresh(true)
	_tab_by_hand = true


## Turn to the next (+1) or previous (-1) tab.
func turn_tab(step: int) -> void:
	var at := KeywordHelp.TABS.find(tab)
	_on_tab(KeywordHelp.TABS[wrapi(at + step, 0, KeywordHelp.TABS.size())])


## A pad press at the terminal (TerminalUI._on_pad asks first). True if used.
func on_pad(event: InputEvent) -> bool:
	if not _open:
		return false
	if event.is_action_pressed("notebook"):
		toggle()
		return true
	if not down:
		return false
	if event.is_action_pressed("ui_tab_prev"):
		turn_tab(-1)
	elif event.is_action_pressed("ui_tab_next"):
		turn_tab(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		focus = maxi(focus - 1, 0)
		_show_focus()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		focus = mini(focus + 1, maxi(chips.size() - 1, 0))
		_show_focus()
	elif event.is_action_pressed("ui_accept"):
		pick(focus)
	else:
		return false
	return true


## A click on the notebook's edge below the screen looks down at it.
func _input(event: InputEvent) -> void:
	if not _open or down or held == null or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if held.page_point(event.position).x >= 0.0:
		look(true)
		get_viewport().set_input_as_handled()
