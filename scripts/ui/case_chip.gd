class_name CaseChip
extends Control
## The main case on screen (top right): what to do about it, how many of its pieces are
## in ("3/4"), a bar of one segment per piece, and what to do next. Only the main
## case counts (Game.main_case): side cases and other ways in stay off the screen.
## Built by the HUD; follows Game.notebook_changed and Game.piece_found. The
## next step shows only briefly: after a piece is found and after the notebook
## closes (brief_next), then the chip is just the case and its count.
##
## Under it, the selected case's query with blanks (Game.case_query, colored by
## kind: PieceKind), while a paper of that case is held (hold_query) and for a
## few seconds after one of its pieces is found (show_query). At a terminal the
## typing line shows it instead (TerminalUI).
##
## A piece or an answer found slides up at the screen's bottom edge, everywhere,
## with the pencil's sound, then writes itself into the query (puzzle-flow spec,
## section 5). In co-op a crewmate's find says who found it. A click puts it away.

## The words on screen (drafts for Augustine's word-for-word OK).
const HEADER := "CURRENT CASE"
const NEXT := "Next: %s"
const FOUND := "PIECE FOUND  ·  %d OF %d"
const FOUND_SIDE := "PIECE FOUND  ·  SIDE CASE"
const ADDED := "Added to the case. Checklist updated (Tab)."
## How long the slide-up stays up, and how long it takes to slide.
const TOAST_TIME := 3.0
const SLIDE_TIME := 0.35
## The slide-up's credit line in co-op (G21).
const FOUND_BY := "Found by %s"
## How long the query stays under the chip after a piece of it is found.
const QUERY_TIME := 4.0
## How long the next step stays up.
const NEXT_TIME := 6.0
## Widths: the chip and its wrapped lines, then narrower at a terminal, so it
## fits in the margin beside the glass (TerminalScreen fills 85% of the height).
const WIDE := 340
const NARROW := 220

const PANEL := Color(0.04, 0.05, 0.055, 0.85)
const EDGE := Color(0.29, 0.31, 0.33)
const AMBER := Color(0.91, 0.69, 0.29)
const DIM := Color(0.79, 0.76, 0.71)
const EMPTY := Color(0.24, 0.26, 0.27)
const PAPER := Color(0.94, 0.91, 0.85)

var chip: PanelContainer
var title: Label
var count: Label
var bar: HBoxContainer
var next: Label
var column: VBoxContainer
## The slide-up (its old name: it was a card in the top left).
var toast: PanelContainer
var toast_head: Label
var toast_value: RichTextLabel
var toast_by: Label
var _toast_tween: Tween
## The selected case's query with blanks, under the chip.
var query_panel: PanelContainer
var query: RichTextLabel
## A paper of the selected case is held: the query stays up.
var query_held := false
## The piece just written in, drawn brighter while the query's up for it.
var _fresh_piece := ""
var _query_turn := 0
var _query_on := false
var _query_tween: Tween
## The case shown, "" for none.
var case_id := ""
## Off while a terminal fills the view: the chip narrows to sit beside the
## glass, and the query under it gives way to the one above the typing line.
var allowed := true
## The next step is up for now (brief_next).
var next_up := false
## The task just put on the list, shown as the next step instead (brief_task): its title.
var task := ""
var _head: Label
var _next_turn := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_chip()
	_build_query()
	_build_toast()
	var game := get_node_or_null("/root/Game")
	if game:
		game.notebook_changed.connect(refresh)
		game.piece_found.connect(show_found)
		game.answer_found.connect(show_answer)
		game.answer_shared.connect(show_answer)
	refresh()


func _build_chip() -> void:
	column = VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.offset_right = -24
	column.offset_top = 24
	add_child(column)
	chip = _panel(PANEL, EDGE)
	chip.name = "Chip"
	column.add_child(chip)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	chip.add_child(box)
	var top := HBoxContainer.new()
	var head := ThemeUtil.label(HEADER, 13, DIM)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	_head = head
	count = ThemeUtil.label("", 22, AMBER)
	count.name = "Count"
	top.add_child(count)
	box.add_child(top)
	title = ThemeUtil.label("", 18, Color.WHITE)
	title.name = "Title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	bar = HBoxContainer.new()
	bar.name = "Bar"
	bar.add_theme_constant_override("separation", 6)
	box.add_child(bar)
	next = ThemeUtil.label("", 15, DIM)
	next.name = "Next"
	next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(next)
	_fit(WIDE)


## Lay the chip out `width` px wide.
func _fit(width: int) -> void:
	chip.custom_minimum_size.x = width
	title.custom_minimum_size.x = width - 40
	next.custom_minimum_size.x = width - 40
	if query:
		query.custom_minimum_size.x = width - 32
	# Down to nothing: it grows back to fit, leftward from the right edge.
	column.offset_left = column.offset_right
	column.offset_bottom = column.offset_top


func _build_query() -> void:
	query_panel = _panel(PANEL, EDGE)
	query_panel.name = "Query"
	query_panel.visible = false
	column.add_child(query_panel)
	query = RichTextLabel.new()
	query.name = "Text"
	query.bbcode_enabled = true
	query.fit_content = true
	query.scroll_active = false
	query.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	query.mouse_filter = Control.MOUSE_FILTER_IGNORE
	query.add_theme_font_override("normal_font", ThemeUtil.mono())
	for f in ["bold_font", "italics_font"]:
		query.add_theme_font_override(f, ThemeUtil.mono())
	for f in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		query.add_theme_font_size_override(f, 17)
	query.add_theme_color_override("default_color", PAPER)
	query.custom_minimum_size.x = WIDE - 32
	query_panel.add_child(query)


func _build_toast() -> void:
	toast = _panel(PANEL, EDGE)
	toast.name = "Found"
	toast.mouse_filter = Control.MOUSE_FILTER_STOP  # a click puts it away
	toast.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			dismiss())
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_END
	toast.custom_minimum_size.x = 440
	toast.offset_left = -220
	toast.offset_right = 220
	toast.visible = false
	add_child(toast)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	toast.add_child(row)
	var plus := _on_paper("+1", 20, PANEL)
	var badge := _panel(AMBER, AMBER)
	badge.custom_minimum_size = Vector2(52, 52)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(plus)
	row.add_child(badge)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_theme_constant_override("separation", 4)
	toast_head = ThemeUtil.label("", 13, DIM)
	box.add_child(toast_head)
	toast_value = RichTextLabel.new()
	toast_value.name = "Value"
	toast_value.bbcode_enabled = true
	toast_value.fit_content = true
	toast_value.scroll_active = false
	toast_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	toast_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_value.add_theme_font_override("normal_font", ThemeUtil.mono())
	for f in ["bold_font", "italics_font"]:
		toast_value.add_theme_font_override(f, ThemeUtil.mono())
	for f in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		toast_value.add_theme_font_size_override(f, 20)
	toast_value.add_theme_color_override("default_color", PAPER)
	box.add_child(toast_value)
	toast_by = ThemeUtil.label("", 13, AMBER)
	toast_by.name = "By"
	toast_by.visible = false
	box.add_child(toast_by)
	box.add_child(ThemeUtil.label(ADDED, 13, DIM))
	row.add_child(box)


## Print on the found card's paper: no drop shadow, unlike the HUD's own labels.
static func _on_paper(text: String, size: int, color: Color) -> Label:
	var l := ThemeUtil.label(text, size, color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l


static func _panel(bg: Color, edge: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	return p


## Show (or hide) the main case as it stands now.
func refresh() -> void:
	var game := get_node_or_null("/root/Game")
	case_id = game.main_case() if game else ""
	# With no case open, a new task still shows its title for a moment, on its own.
	var task_only := case_id == "" and next_up and task != ""
	chip.visible = case_id != "" or task_only
	_head.visible = case_id != ""
	title.visible = case_id != ""
	if case_id == "":
		count.visible = false
		bar.visible = false
		next.text = NEXT % task if task_only else ""
		next.visible = task_only
		if query:
			_draw_query()
		return
	var c: Dictionary = game.case_info(case_id)
	var found: int = game.pieces_found(case_id)
	var total: int = game.pieces_total(case_id)
	# What to do about it, which is what the case page's top line says too.
	title.text = str(c.get("objective", "")) if str(c.get("objective", "")) != "" else c.title
	count.text = "%d/%d" % [found, total]
	count.visible = total > 0  # a case with no pieces to find: just what to do
	bar.visible = total > 0
	for s in bar.get_children():
		bar.remove_child(s)
		s.queue_free()
	for i in total:
		var seg := ColorRect.new()
		seg.color = AMBER if i < found else EMPTY
		seg.custom_minimum_size = Vector2(0, 10)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(seg)
	var step: String = task if task != "" else game.case_next(case_id)
	next.text = NEXT % step if step != "" else ""
	next.visible = next_up and step != ""
	if query:
		_draw_query()


## Case `id`'s piece `piece_id` was just found: it slides up, saying what it was.
func show_found(id: String, piece_id: String) -> void:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	var c: Dictionary = game.case_info(id)
	if not c.get("open", false):
		return  # kept for when its case opens: nothing to count yet
	var piece := {}
	for p in c.get("pieces", []):
		if p.id == piece_id:
			piece = p
	if piece.is_empty():
		return
	brief_next()
	var head: String = FOUND_SIDE if c.get("optional", false) else FOUND % [game.pieces_found(id), game.pieces_total(id)]
	_slide_up(head, "%s: %s" % [str(piece.label).replace("[", "[lb]"), PieceKind.bbcode(str(piece.value), PieceKind.of_piece(piece))], str(piece.get("by", "")))
	if id == game.case_selected():
		_fresh_piece = piece_id
		show_query()


## Case `id`'s slot was just answered, by this player or (with `by`) a crewmate:
## it slides up, the case's question over the answer.
func show_answer(id: String, by: String = "") -> void:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	var b: Dictionary = game.case_info(id).get("blank", {})
	if b.is_empty() or str(b.get("filled", "")) == "":
		return
	_slide_up(str(b.get("prompt", "")), PieceKind.bbcode(str(b.filled), PieceKind.VALUE), by)


## Slide `head` over `value` (BBCode) up from the screen's bottom edge, with
## the pencil's sound; `by` names the crewmate who found it.
func _slide_up(head: String, value: String, by: String) -> void:
	toast_head.text = head
	toast_head.visible = head != ""
	toast_value.text = value
	toast_by.text = FOUND_BY % by if by != "" else ""
	toast_by.visible = by != ""
	toast.visible = true
	toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	if not is_inside_tree():
		return
	Sfx.play_flat(self, "pencil")
	toast.reset_size()
	var h: float = maxf(toast.get_combined_minimum_size().y, 60.0)
	toast.offset_top = 0.0
	toast.offset_bottom = h
	_toast_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(toast, "offset_top", -h - 24.0, SLIDE_TIME)
	_toast_tween.parallel().tween_property(toast, "offset_bottom", -24.0, SLIDE_TIME)
	_toast_tween.tween_interval(TOAST_TIME)
	_toast_tween.tween_callback(dismiss)


## Put the slide-up away, back down past the bottom edge.
func dismiss() -> void:
	if not toast.visible:
		return
	if _toast_tween:
		_toast_tween.kill()
	if not is_inside_tree():
		toast.visible = false
		return
	var h: float = toast.offset_bottom - toast.offset_top
	_toast_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_toast_tween.tween_property(toast, "offset_top", 0.0, SLIDE_TIME)
	_toast_tween.parallel().tween_property(toast, "offset_bottom", h, SLIDE_TIME)
	_toast_tween.tween_callback(func(): toast.visible = false)


## The selected case's query, under the chip for QUERY_TIME seconds.
func show_query() -> void:
	_query_turn += 1
	_set_query(true)
	if not is_inside_tree():
		return
	var turn := _query_turn
	get_tree().create_timer(QUERY_TIME).timeout.connect(func():
		if turn == _query_turn:
			_fresh_piece = ""
			_set_query(false))


## A paper of the selected case is in this player's hands (`on`), or put down:
## the query stays up while it's held.
func hold_query(on: bool) -> void:
	query_held = on
	_set_query(on)


## Fade the query under the chip in (`on`) or out, unless it's still held.
func _set_query(on: bool) -> void:
	on = on or query_held
	_query_on = on
	_draw_query()
	var shown := query_panel.visible and query_panel.modulate.a > 0.99
	var want: bool = on and _query_text() != "" and allowed
	if want == shown and (want or not query_panel.visible):
		return
	if _query_tween:
		_query_tween.kill()
	if not is_inside_tree():
		query_panel.visible = want
		query_panel.modulate.a = 1.0
		return
	query_panel.visible = true
	_query_tween = create_tween()
	_query_tween.tween_property(query_panel, "modulate:a", 1.0 if want else 0.0, 0.3)
	if not want:
		_query_tween.tween_callback(func(): query_panel.visible = false)


## The selected case's query as BBCode, "" if it has none.
func _query_text() -> String:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return ""
	var id: String = game.case_selected()
	if id == "" or game.case_query(id) == "":
		return ""
	return PieceKind.query_bbcode(game.case_info(id), game.PIECE_MISSING, _fresh_piece)


func _draw_query() -> void:
	var text := _query_text()
	if query.text != text:
		query.text = text
	if text == "" or not allowed:
		query_panel.visible = false


## While a terminal's glass fills the view the chip stays, narrowed to fit
## beside it, so the task is still in sight; the query under it gives way to
## the one above the typing line.
func set_allowed(on: bool) -> void:
	allowed = on
	_fit(WIDE if on else NARROW)
	refresh()
	_set_query(_query_on)


## A task just went on the list (HUD.todo): "Next: <its title>" for NEXT_TIME seconds.
func brief_task(task_title: String) -> void:
	brief_next(task_title)


## Show the next step for NEXT_TIME seconds, then just the case and its count.
## `task_title`: a new task's title to show as the next step instead.
func brief_next(task_title := "") -> void:
	task = task_title
	next_up = true
	_next_turn += 1
	refresh()
	if not is_inside_tree():
		return
	var turn := _next_turn
	get_tree().create_timer(NEXT_TIME).timeout.connect(_end_next.bind(turn))


## The next step's time is up, unless a newer one has started since.
func _end_next(turn: int) -> void:
	if turn == _next_turn:
		next_up = false
		task = ""
		refresh()
