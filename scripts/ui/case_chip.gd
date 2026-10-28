class_name CaseChip
extends Control
## The main case on screen (top right): what to do about it, how many of its pieces are
## in ("3/4"), a bar of one segment per piece, and what to do next. Finding a
## piece pops a card in the top left saying what it was. Only the main case
## counts (Game.main_case): side cases and other ways in stay off the screen.
## Built by the HUD; follows Game.notebook_changed and Game.piece_found. The
## next step shows only briefly: after a piece is found and after the notebook
## closes (brief_next), then the chip is just the case and its count.

## The words on screen (drafts for Augustine's word-for-word OK).
const HEADER := "CURRENT CASE"
const NEXT := "Next: %s"
const FOUND := "PIECE FOUND  ·  %d OF %d"
const FOUND_SIDE := "PIECE FOUND  ·  SIDE CASE"
const ADDED := "Added to the case. Checklist updated (Tab)."
## How long the found card stays up.
const TOAST_TIME := 4.0
## How long the next step stays up.
const NEXT_TIME := 6.0

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
var toast: PanelContainer
var toast_head: Label
var toast_value: Label
var _toast_tween: Tween
## The case shown, "" for none.
var case_id := ""
## Off while a terminal fills the view.
var allowed := true
## Pieces found while it was off: [case_id, piece_id] each, shown once it's back.
var waiting: Array = []
## The next step is up for now (brief_next).
var next_up := false
var _next_turn := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_chip()
	_build_toast()
	var game := get_node_or_null("/root/Game")
	if game:
		game.notebook_changed.connect(refresh)
		game.piece_found.connect(show_found)
	refresh()


func _build_chip() -> void:
	chip = _panel(PANEL, EDGE)
	chip.name = "Chip"
	chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chip.offset_right = -24
	chip.offset_top = 24
	chip.custom_minimum_size.x = 340
	add_child(chip)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	chip.add_child(box)
	var top := HBoxContainer.new()
	var head := ThemeUtil.label(HEADER, 13, DIM)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	count = ThemeUtil.label("", 22, AMBER)
	count.name = "Count"
	top.add_child(count)
	box.add_child(top)
	title = ThemeUtil.label("", 18, Color.WHITE)
	title.name = "Title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 300
	box.add_child(title)
	bar = HBoxContainer.new()
	bar.name = "Bar"
	bar.add_theme_constant_override("separation", 6)
	box.add_child(bar)
	next = ThemeUtil.label("", 15, DIM)
	next.name = "Next"
	next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next.custom_minimum_size.x = 300
	box.add_child(next)


func _build_toast() -> void:
	toast = _panel(PAPER, PAPER)
	toast.name = "Found"
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	toast.offset_left = 24
	toast.offset_top = 24
	toast.custom_minimum_size.x = 380
	toast.visible = false
	add_child(toast)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	toast.add_child(row)
	var plus := _on_paper("+1", 20, Color(0.1, 0.12, 0.13))
	var badge := _panel(AMBER, AMBER)
	badge.custom_minimum_size = Vector2(52, 52)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(plus)
	row.add_child(badge)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	toast_head = _on_paper("", 13, Color(0.42, 0.42, 0.42))
	box.add_child(toast_head)
	toast_value = NotebookArt.hand("", 28, NotebookArt.INK)
	toast_value.name = "Value"
	toast_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(toast_value)
	box.add_child(_on_paper(ADDED, 13, Color(0.42, 0.42, 0.42)))
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
	chip.visible = allowed and case_id != ""
	if case_id == "":
		return
	var c: Dictionary = game.case_info(case_id)
	var found: int = game.pieces_found(case_id)
	var total: int = game.pieces_total(case_id)
	# What to do about it, which is what the case page's top line says too.
	title.text = str(c.get("objective", "")) if str(c.get("objective", "")) != "" else c.title
	count.text = "%d/%d" % [found, total]
	for s in bar.get_children():
		bar.remove_child(s)
		s.queue_free()
	for i in total:
		var seg := ColorRect.new()
		seg.color = AMBER if i < found else EMPTY
		seg.custom_minimum_size = Vector2(0, 10)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(seg)
	var step: String = game.case_next(case_id)
	next.text = NEXT % step if step != "" else ""
	next.visible = next_up and step != ""


## Case `id`'s piece `piece_id` was just found: say what it was, top left.
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
	if not allowed:
		waiting.append([id, piece_id])  # said when the terminal's put away
		return
	brief_next()
	toast_head.text = FOUND_SIDE if c.get("optional", false) else FOUND % [game.pieces_found(id), game.pieces_total(id)]
	toast_value.text = "%s: %s" % [piece.label, piece.value]
	toast.visible = true
	toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	if not is_inside_tree():
		return
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_TIME)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func(): toast.visible = false)


## Hide both while a terminal's glass fills the view (they'd cover its text). A
## piece found meanwhile is shown once it's back.
func set_allowed(on: bool) -> void:
	allowed = on
	if not on:
		toast.visible = false
	refresh()
	if on and not waiting.is_empty():
		var last: Array = waiting.pop_back()  # the newest says the count as it is now
		waiting.clear()
		show_found(last[0], last[1])


## Show the next step for NEXT_TIME seconds, then just the case and its count.
func brief_next() -> void:
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
		refresh()
