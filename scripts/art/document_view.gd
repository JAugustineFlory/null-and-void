class_name DocumentView
extends Control
## A document up close, readable: the page a player is holding after pressing E
## on a binder, desk card, brochure, memo or clipboard. Pointing at a line lights
## it with a highlighter band and offers "+ add to notebook"; handwriting goes in the margin (Mercer's older fountain-pen
## hand, or a player's) or in a filled-in blank. Drawn in code like NotebookView;
## what's on the page and when it opens belong to the mechanics.
##
##   var doc := DocumentView.new()
##   canvas_layer.add_child(doc)           # layer 15: above VHS (3), below the terminal (20)
##   doc.set_paper("manual")
##   doc.set_title("FACILITIES MANUAL - 4.2 Door control")
##   doc.add_line("Every door has a row in the doors table.")
##   doc.add_margin_note("the badge reader lies. - H.M.")
##   doc.add_blank("Guards' clock-in times live in a table of ", "guards", ".")
##   doc.copy_requested.connect(func(text): notebook.add_line(text))
##   doc.show_doc()
##
## Papers look real: printed stationery (letterhead, form number), ruled tables
## filled in by hand, rubber stamps and coffee stains. A Document's lines go in
## whole with add_lines(); see add_entry() for every kind of line.

signal copy_requested(text: String)
signal closed

const KINDS := ["memo", "manual", "card", "brochure", "clipboard"]
## Design size of each paper, where its text goes (scaled to fit the screen), the
## width of its margin, and "band": the printed header the title sits in (0 for none).
const PAPERS := {
	"memo": {"size": Vector2(760, 960), "body": Rect2(70, 130, 640, 780), "margin": 170.0, "band": 0},
	"manual": {"size": Vector2(800, 980), "body": Rect2(120, 80, 640, 850), "margin": 170.0, "band": 0},
	"card": {"size": Vector2(1000, 620), "body": Rect2(60, 30, 880, 540), "margin": 170.0, "band": 96},
	"brochure": {"size": Vector2(1100, 760), "body": Rect2(590, 30, 480, 690), "margin": 110.0, "band": 106},
	"clipboard": {"size": Vector2(820, 1060), "body": Rect2(100, 190, 640, 800), "margin": 170.0, "band": 0},
}
const MARGIN_WIDTH := 170.0  # the margin slot beside each line, where notes are written
const TYPE_SIZE := 21
const BROCHURE_NAVY := Color(0.13, 0.2, 0.36)
const COFFEE := Color(0.5, 0.31, 0.13)
const STAMP_RED := Color(0.74, 0.13, 0.14)
const STAMP_BLUE := Color(0.16, 0.24, 0.6)
## Other people's pens, for forms filled in by hand: [font, ink]. Each name picks one.
const HANDS := [["hand", Color(0.12, 0.15, 0.32)], ["old", Color(0.08, 0.08, 0.1)], ["hand", Color(0.3, 0.3, 0.33)], ["old", Color(0.12, 0.2, 0.42)]]

var kind := "memo"
var margin_width := MARGIN_WIDTH
var paper: Control  # everything that moves when the page is shown
var body: VBoxContainer
var _title: Label
var _close: Button
var _last_row: HBoxContainer
var _columns: Array[float] = []  # widths of the ruled table being filled in, if any
## Drawn into a texture (paper_texture): just the paper, at scale 1 from the
## top-left corner, with no dimming and no close button.
var flat := false:
	set(v):
		flat = v
		get_node("Dim").visible = not v
		_close.visible = not v
		_fit()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	paper = _PaperDrawing.new()
	paper.name = "Paper"
	add_child(paper)
	body = VBoxContainer.new()
	body.name = "Body"
	body.clip_contents = true
	body.add_theme_constant_override("separation", 6)
	paper.add_child(body)
	_title = Label.new()
	_title.name = "Title"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_override("font", NotebookArt.type_font())
	_title.add_theme_font_size_override("font_size", 28)
	_title.visible = false
	body.add_child(_title)
	_close = Button.new()
	_close.name = "Close"
	_close.text = "close"
	_close.focus_mode = Control.FOCUS_NONE
	_close.tooltip_text = "Put it down"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	for state in ["normal", "hover", "pressed"]:
		var s2: StyleBoxFlat = sb.duplicate()
		if state == "hover":
			s2.bg_color = Color(0.2, 0.2, 0.24, 0.9)
		_close.add_theme_stylebox_override(state, s2)
	_close.add_theme_font_override("font", NotebookArt.hand_font())
	_close.add_theme_font_size_override("font_size", 24)
	_close.add_theme_color_override("font_color", Color(0.95, 0.94, 0.88))
	_close.add_theme_color_override("font_hover_color", Color.WHITE)
	_close.pressed.connect(func(): closed.emit())
	paper.add_child(_close)
	set_paper("memo")
	resized.connect(_fit)


func _ready() -> void:
	_fit()


## Which paper: "memo", "manual" (binder page), "card" (laminated), "brochure" or "clipboard".
func set_paper(paper_kind: String) -> void:
	kind = paper_kind if PAPERS.has(paper_kind) else "memo"
	var p: Dictionary = PAPERS[kind]
	paper.size = p.size
	paper.pivot_offset = paper.size / 2
	body.position = p.body.position
	body.size = p.body.size
	margin_width = p.margin
	_close.position = Vector2(paper.size.x - 110, -46)
	_style_title()
	paper.set("kind", kind)
	paper.queue_redraw()
	_fit()


## The printed heading at the top of the page.
func set_title(text: String) -> void:
	_title.text = text
	_title.visible = text != ""
	paper.set("title", text)
	paper.queue_redraw()


## A typed line. Pointing at it highlights it and offers "+ add to notebook",
## which emits copy_requested(text). Returns the row.
func add_line(text: String) -> Control:
	var row := _row(text)
	var l := _typed(text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.move_child(l, 0)
	return row


## A whole line written by hand (a note in someone's writing), which can be added
## to the notebook like a typed line.
func add_hand_line(text: String, author := "player") -> Control:
	var row := _row(text)
	var l := _handwriting(text, author, 24)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.move_child(l, 0)
	return row


## Handwriting in the margin beside the last line (or on a line of its own).
## author "mercer": his older fountain-pen hand; "player": the crew's ballpoint.
func add_margin_note(text: String, author := "mercer") -> Control:
	var note := _handwriting(text, author, 24 if author == "mercer" else 22)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = margin_width - 10
	note.rotation_degrees = -3.0 if author == "mercer" else -1.5
	note.name = "MarginNote"
	var slot: Control = _last_row.get_node("Margin") if _last_row and _last_row.get_node("Margin").get_child_count() == 0 else null
	if slot == null:
		var row := HBoxContainer.new()
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(gap)
		slot = Control.new()
		slot.name = "Margin"
		slot.custom_minimum_size = Vector2(margin_width, 0)
		row.add_child(slot)
		body.add_child(row)
		_last_row = row
		note.position.y = 6  # clear of the note above
	slot.add_child(note)
	note.position += Vector2(8, -4)
	note.size.x = margin_width - 10
	# Grow the row so a long note doesn't run into the next line.
	slot.custom_minimum_size.y = maxf(slot.custom_minimum_size.y, note.get_minimum_size().y + note.position.y - 6)
	return note


## A printed line with a blank someone filled in by hand: "a table of ___ choice"
## with "guards" written on the line. Adding it to the notebook copies the whole line.
func add_blank(before: String, filled: String, after: String, author := "mercer") -> Control:
	var row := _row(before + filled + after)
	var flow := HFlowContainer.new()
	flow.name = "Sentence"
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 0)
	for word in before.split(" ", false):
		flow.add_child(_typed(word + " ", false))
	var blank := VBoxContainer.new()
	blank.name = "Blank"
	blank.add_theme_constant_override("separation", -8)
	var hand := _handwriting("  " + filled + "  ", author, 30)
	hand.name = "Filled"
	hand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand.rotation_degrees = -2.0
	blank.add_child(hand)
	var rule := ColorRect.new()
	rule.color = Color(ArtProps.PRINT_INK, 0.85)
	rule.custom_minimum_size = Vector2(maxf(110.0, filled.length() * 16.0 + 30.0), 2)
	blank.add_child(rule)
	flow.add_child(blank)
	if not (after.begins_with(".") or after.begins_with(",") or after.begins_with(";")):  # punctuation hugs the blank
		var gap := Control.new()
		gap.custom_minimum_size.x = 12
		flow.add_child(gap)
	var rest := after.split(" ", false)
	for i in rest.size():
		flow.add_child(_typed(rest[i] + (" " if i < rest.size() - 1 else ""), false))
	row.add_child(flow)
	row.move_child(flow, 0)
	return row


## Every line of a Document (Document.doc_lines), top to bottom.
func add_lines(lines: Array) -> void:
	for l in lines:
		add_entry(l)


## One line of a Document. A String is a typed line. A Dictionary is one of:
##   {"text", "hand": true, "author"}                handwriting ("" text: a gap)
##   {"before", "filled", "after", "author"}         a printed blank filled in by hand
##   {"columns": ["NAME", "BADGE", ...], "widths"}   starts a ruled printed table (add "text": the names joined)
##   {"row": ["PIKE, H.", "", "22:00"], "text", "over"}  a table row filled in by hand;
##       "over" is written across it in red pen ("NO SHOW")
##   {"stamp": "RECEIVED 10/15", "color": "blue"}    a rubber stamp over the lines above
## Any line can add "stain": "coffee" (with "stain_at": a cell index on a row): a
## spill over it that hides what's under it. Copying a line copies its "text".
func add_entry(l: Variant) -> Control:
	var d: Dictionary = l if l is Dictionary else {"text": str(l)}
	var row: Control
	if d.has("columns"):
		row = add_columns(d.columns, d.get("widths", []))
	elif d.has("row"):
		row = add_table_row(d.row, str(d.get("text", "")), str(d.get("over", "")))
	elif d.has("stamp"):
		row = add_stamp(str(d.stamp), STAMP_BLUE if d.get("color", "") == "blue" else STAMP_RED)
	elif d.has("filled"):
		row = add_blank(d.get("before", ""), d.filled, d.get("after", ""), d.get("author", "player"))
	elif str(d.get("text", "")).strip_edges() == "":
		row = Control.new()  # a gap between paragraphs
		row.custom_minimum_size.y = 10
		body.add_child(row)
	elif d.get("hand", false):
		row = add_hand_line(d.text, d.get("author", "player"))
	else:
		row = add_line(d.text)
	if d.has("stain"):
		add_stain(row, int(d.get("stain_at", -1)))
	return row


## The printed header of a ruled table: the column names in small type on a grey
## band, with the column rules running down through the rows that follow.
## `widths` are fractions of the table's width; by default the names share it.
func add_columns(names: Array, widths: Array = []) -> Control:
	var total := _table_width()
	_columns.clear()
	var sum := 0.0
	for i in names.size():
		var f: float = widths[i] if i < widths.size() else maxf(4.0, str(names[i]).length())
		_columns.append(f)
		sum += f
	for i in _columns.size():
		_columns[i] = _columns[i] / sum * total
	var row := HBoxContainer.new()
	row.name = "TableHead"
	row.add_theme_constant_override("separation", 10)
	var cells := _Cells.new()
	cells.header = true
	cells.widths = _columns.duplicate()
	for i in names.size():
		var l := NotebookArt.code(str(names[i]), 15, ArtProps.PRINT_INK)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		cells.add_cell(l, 22.0)
	row.add_child(cells)
	var slot := Control.new()
	slot.name = "Margin"
	slot.custom_minimum_size = Vector2(margin_width, 0)
	row.add_child(slot)
	body.add_child(row)
	_last_row = row
	return row


## A row of the table, filled in by hand: each name in its own pen, with blank
## cells left empty. `over` is written across the row in red ("NO SHOW").
func add_table_row(values: Array, copy_text := "", over := "") -> Control:
	if _columns.is_empty():
		add_columns(values.map(func(_v): return ""))
	var text := copy_text if copy_text != "" else "  ".join(values.filter(func(v): return str(v) != ""))
	var row := _row(text)
	var cells := _Cells.new()
	cells.widths = _columns.duplicate()
	var pen: Array = HANDS[absi(str(values[0] if values.size() > 0 else "").hash()) % HANDS.size()]
	for i in _columns.size():
		var v := str(values[i]) if i < values.size() else ""
		var l := NotebookArt.hand(v, 25, pen[1])
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		if pen[0] == "old":
			l.add_theme_font_override("font", NotebookArt.old_hand_font())
			l.add_theme_font_size_override("font_size", 30)
		l.rotation_degrees = _jitter(v + str(i), 1.6)
		cells.add_cell(l, 46.0)
	if over != "":
		var red := NotebookArt.hand(over, 30, NotebookArt.RED_PEN)
		red.name = "Over"
		red.autowrap_mode = TextServer.AUTOWRAP_OFF
		red.rotation_degrees = -4.0
		cells.over = red
		cells.get_child(mini(1, cells.get_child_count() - 1)).add_child(red)  # from the second column on
	row.add_child(cells)
	row.move_child(cells, 0)
	return row


## A rubber stamp, inked at an angle over the right of the lines above it.
func add_stamp(text: String, ink: Color = STAMP_RED) -> Control:
	var holder := Control.new()
	holder.name = "Stamp"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stamp := _Stamp.new()
	stamp.text = text
	stamp.ink = ink
	stamp.rotation_degrees = -8.0 + _jitter(text, 4.0)
	stamp.position = Vector2(body.size.x - stamp.get_minimum_size().x - 6, -60)  # over the margin, clear of the text
	stamp.z_index = 1
	holder.add_child(stamp)
	body.add_child(holder)
	return holder


## A coffee spill over a line: the ring of a mug and a blot that hides the writing
## under it. On a table row, `cell` is the column it covers from the middle on
## (only the start of that cell stays readable).
func add_stain(row: Control, cell: int = -1) -> Control:
	var stain := _Stain.new()
	stain.seed_text = row.get("copy_text") if row.get("copy_text") != null else row.name
	stain.z_index = 1
	var cells: _Cells = null
	for c in row.get_children():
		if c is _Cells:
			cells = c
	if cells and cell >= 0 and cell < cells.get_child_count():
		stain.cell = cells.get_child(cell)
	stain.row = row
	# Rows are containers: the stain goes in a plain slot so the layout leaves it alone.
	var slot: Control = row.get_node_or_null("ChipSlot") if row is Container else row
	if slot == null:
		slot = Control.new()
		slot.name = "StainSlot"
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slot)
	slot.add_child(stain)
	return stain


func _table_width() -> float:
	return body.size.x - margin_width - 10.0


## A small steady wobble for something written by hand, the same every time.
static func _jitter(key: String, degrees: float) -> float:
	return (float(absi(key.hash()) % 1000) / 1000.0 - 0.5) * 2.0 * degrees


## A Document's page as a texture, for a sheet on a wall or the paper in your
## hands: the same paper, letterhead, table and coffee as the close-up. Its
## SubViewport goes under `owner` (named "PaperTexture"), draws for a few frames
## while the page lays out, then keeps the picture and stops drawing. The texture
## is the paper's design size (PAPERS[kind].size); its DocumentView is the
## viewport's child, so `plain_text()` there says what's on it.
static func paper_texture(owner: Node, lines: Array, kind := "memo", title := "") -> ViewportTexture:
	var vp := _RenderOnce.new()
	vp.name = "PaperTexture"
	vp.transparent_bg = true
	var view := DocumentView.new()
	vp.add_child(view)
	view.flat = true
	view.set_paper(kind)
	view.set_title(title)
	view.add_lines(lines)
	vp.size = Vector2i(view.paper.size)
	view.size = view.paper.size
	owner.add_child(vp)
	return vp.get_texture()


## Everything written on the page, top to bottom: the title, then each line as
## it would be copied (a table's column names joined).
func plain_text() -> String:
	var out: Array[String] = []
	if _title.text != "":
		out.append(_title.text)
	for c in body.get_children():
		if c.get("copy_text") != null and str(c.copy_text) != "":
			out.append(str(c.copy_text))
		elif c.name.begins_with("TableHead"):
			out.append("  ".join(c.find_children("*", "Label", true, false).map(func(l): return l.text)))
	return "\n".join(out)


## Empties the page for the next document.
func clear() -> void:
	for c in body.get_children():
		if c != _title:
			body.remove_child(c)
			c.queue_free()
	_last_row = null
	_columns.clear()
	set_title("")


## Lifts the page up into view, like picking it up off the desk.
func show_doc() -> Tween:
	visible = true
	_fit()
	var rest := paper.position
	paper.position.y = rest.y + size.y * 0.6
	paper.rotation_degrees = 5.0
	paper.scale *= 0.9
	var full := paper.scale / 0.9
	modulate.a = 0.0
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(paper, "position:y", rest.y, 0.26)
	t.tween_property(paper, "rotation_degrees", -0.8, 0.26)
	t.tween_property(paper, "scale", full, 0.26)
	t.tween_property(self, "modulate:a", 1.0, 0.14)
	return t


## Puts it back down, then hides.
func hide_doc() -> Tween:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(paper, "position:y", paper.position.y + size.y * 0.6, 0.18)
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.chain().tween_callback(func(): visible = false; _fit())
	return t


func _row(copy_text: String) -> HBoxContainer:
	var row := _Row.new()
	row.add_theme_constant_override("separation", 10)
	row.copy_text = copy_text
	row.margin_width = margin_width
	# The chip is drawn in the margin while the line is pointed at, so it takes no room from the text.
	var slot := Control.new()
	slot.name = "Margin"
	slot.custom_minimum_size = Vector2(margin_width, 0)
	row.add_child(slot)
	var anchor := Control.new()  # last, so the chip draws over any margin note
	anchor.name = "ChipSlot"
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(anchor)
	var chip := add_chip()
	chip.pressed.connect(func(): copy_requested.emit(copy_text))
	anchor.add_child(chip)
	row.chip = chip
	body.add_child(row)
	_last_row = row
	return row


## The "+ add to notebook" chip that appears on the line under the pointer: the
## same words and place as on terminal lines, in typewriter ink for paper.
static func add_chip() -> Button:
	var chip := Button.new()
	chip.name = "AddChip"
	chip.text = "+ add to notebook"
	chip.focus_mode = Control.FOCUS_NONE
	chip.tooltip_text = "Copy this line into your notebook"
	chip.add_theme_font_override("font", NotebookArt.type_font())
	chip.add_theme_font_size_override("font_size", 15)
	chip.add_theme_color_override("font_color", Color(NotebookArt.INK, 0.7))
	chip.add_theme_color_override("font_hover_color", NotebookArt.RED_PEN)
	chip.add_theme_color_override("font_pressed_color", NotebookArt.RED_PEN.darkened(0.2))
	var sb := StyleBoxFlat.new()
	sb.bg_color = ArtProps.STICKY_YELLOW
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.shadow_size = 2
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	for state in ["normal", "hover", "pressed"]:
		chip.add_theme_stylebox_override(state, sb)
	chip.visible = false
	return chip


func _typed(text: String, wrap := true) -> Label:
	var l := NotebookArt.code(text, TYPE_SIZE, ArtProps.PRINT_INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return l


func _handwriting(text: String, author: String, font_size: int) -> Label:
	var mercer := author == "mercer"
	var l := NotebookArt.hand(text, font_size, NotebookArt.FOUNTAIN_INK if mercer else NotebookArt.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	if mercer:
		l.add_theme_font_override("font", NotebookArt.old_hand_font())
		l.add_theme_font_size_override("font_size", font_size + 4)  # Caveat runs small
	return l


func _style_title() -> void:
	var on_navy := kind == "brochure" or kind == "card"
	_title.add_theme_color_override("font_color", Color(0.97, 0.96, 0.9) if on_navy else Color(0.1, 0.1, 0.13))
	_title.custom_minimum_size.y = PAPERS[kind].band
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _fit() -> void:
	if paper == null:
		return
	if flat:
		paper.scale = Vector2.ONE
		paper.position = Vector2.ZERO
		paper.rotation = 0.0
		return
	if size.x <= 0:
		return
	var s := minf((size.x - 80) / paper.size.x, (size.y - 110) / paper.size.y)
	s = clampf(s, 0.4, 1.4)
	paper.scale = Vector2(s, s)
	paper.position = (size - paper.size) / 2 + Vector2(0, 20)


## The paper itself for each kind, drawn in one pass.
class _PaperDrawing extends Control:
	var kind := "memo"
	var title := ""

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		match kind:
			"manual":
				_shadow(r)
				draw_rect(r, Color(0.95, 0.92, 0.83))
				_paper_age(r)
				draw_rect(Rect2(r.position + Vector2(r.size.x - 4, 0), Vector2(4, r.size.y)), Color(0.88, 0.85, 0.76))
				for i in 3:  # three-ring punches with reinforced edges
					var c := Vector2(48, r.size.y * (0.18 + 0.32 * i))
					draw_circle(c, 17, Color(0.86, 0.83, 0.74))
					draw_circle(c, 12, Color(0.1, 0.1, 0.12))
				var mx := r.size.x - DocumentView.PAPERS.manual.margin - 30
				draw_line(Vector2(mx, 40), Vector2(mx, r.size.y - 40), Color(0.6, 0.62, 0.7, 0.35), 1.5)
				_footer("HALCYON SYSTEMS  -  internal use", r)
			"card":
				draw_rect(Rect2(r.position + Vector2(8, 12), r.size), Color(0, 0, 0, 0.35))
				draw_rect(r.grow(10), Color(0.92, 0.95, 0.96, 0.55))  # the laminate edge
				draw_rect(r, Color(0.97, 0.97, 0.95))
				var band: float = 30 + DocumentView.PAPERS.card.band
				draw_rect(Rect2(0, 0, r.size.x, band), DocumentView.BROCHURE_NAVY)
				draw_rect(Rect2(0, band, r.size.x, 6), ArtPalette.HALCYON_GOLD)
				_sheen(r)
			"brochure":
				_shadow(r)
				var half := r.size.x / 2
				draw_rect(Rect2(half, 0, half, r.size.y), Color(0.98, 0.97, 0.95))
				draw_rect(Rect2(0, 0, half, r.size.y), DocumentView.BROCHURE_NAVY)  # the cover
				var band: float = 30 + DocumentView.PAPERS.brochure.band
				draw_rect(Rect2(half, 0, half, band), DocumentView.BROCHURE_NAVY)
				draw_rect(Rect2(half, band, half, 5), ArtPalette.HALCYON_GOLD)
				var font := NotebookArt.type_font()
				draw_string(font, Vector2(60, 300), "HALCYON", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, ArtPalette.HALCYON_GOLD)
				draw_string(font, Vector2(64, 340), "SYSTEMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.9, 0.9, 0.88))
				draw_rect(Rect2(60, 380, half - 120, 3), ArtPalette.HALCYON_GOLD)
				draw_multiline_string(font, Vector2(60, 440), title, HORIZONTAL_ALIGNMENT_LEFT, half - 120, 26, -1, Color(0.95, 0.95, 0.92))
				draw_line(Vector2(half, 0), Vector2(half, r.size.y), Color(0, 0, 0, 0.3), 3)  # the fold
				_sheen(r)
			"clipboard":
				draw_rect(Rect2(r.position + Vector2(10, 14), r.size), Color(0, 0, 0, 0.35))
				draw_rect(r, Color(0.45, 0.31, 0.19))  # masonite
				var sheet := Rect2(50, 110, r.size.x - 100, r.size.y - 150)
				draw_rect(sheet, Color(0.97, 0.96, 0.92))
				_paper_age(sheet)
				# A printed form: the company's mark under the clip, its form number at the foot.
				_logo(Vector2(sheet.position.x + 32, sheet.position.y + 44), 0.7)
				var font := NotebookArt.type_font()
				draw_string(font, Vector2(sheet.position.x + 62, sheet.position.y + 52), "HALCYON SYSTEMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DocumentView.BROCHURE_NAVY)
				draw_string(font, Vector2(sheet.end.x - 220, sheet.position.y + 52), "BUILDING SECURITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DocumentView.BROCHURE_NAVY)
				draw_string(font, Vector2(sheet.position.x + 30, sheet.end.y - 18), "FORM HS-114   rev. 3/91", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.4, 0.42))
				draw_string(font, Vector2(sheet.end.x - 140, sheet.end.y - 18), "page 1 of 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.4, 0.42))
				var clip := Rect2(r.size.x / 2 - 140, 40, 280, 100)
				draw_rect(clip, Color(0.62, 0.63, 0.66))
				draw_rect(Rect2(clip.position + Vector2(0, 70), Vector2(clip.size.x, 30)), Color(0.5, 0.51, 0.54))
				draw_rect(Rect2(clip.position + Vector2(20, 10), Vector2(clip.size.x - 40, 8)), Color(0.85, 0.86, 0.88))
				draw_circle(Vector2(r.size.x / 2, 20), 14, Color(0.2, 0.2, 0.22))  # hanging hole
			_:  # memo
				draw_rect(Rect2(r.position + Vector2(14, 12), r.size), Color(0, 0, 0, 0.35))
				draw_rect(Rect2(r.position + Vector2(6, 5), r.size), Color(0.88, 0.88, 0.85))  # the second sheet
				draw_rect(r, Color(0.98, 0.97, 0.94))
				_paper_age(r)
				# Folded in three to fit an envelope, then flattened out again.
				for k in [1, 2]:
					var fy: float = r.size.y * k / 3.0
					draw_line(Vector2(0, fy), Vector2(r.size.x, fy), Color(0, 0, 0, 0.06), 3.0)
					draw_line(Vector2(0, fy + 2), Vector2(r.size.x, fy + 2), Color(1, 1, 1, 0.35), 1.0)
				# Company stationery: the letterhead.
				var font := NotebookArt.type_font()
				_logo(Vector2(112, 62), 1.0)
				draw_string(font, Vector2(148, 62), "HALCYON SYSTEMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, DocumentView.BROCHURE_NAVY)
				draw_string(font, Vector2(150, 86), "Research & Data Services  -  Building 4", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.4, 0.44))
				draw_line(Vector2(92, 104), Vector2(r.size.x - 70, 104), ArtPalette.HALCYON_GOLD, 3.0, true)
				draw_line(Vector2(92, 110), Vector2(r.size.x - 70, 110), Color(DocumentView.BROCHURE_NAVY, 0.6), 1.6, true)
				var s := Vector2(40, 34)
				draw_line(s, s + Vector2(30, 24), Color(0.6, 0.62, 0.65), 4)  # staple
				draw_line(s + Vector2(1, -1), s + Vector2(30, 22), Color(0.88, 0.9, 0.92), 1.5)

	## Old office paper: fibres and specks, and edges gone a little yellow with handling.
	func _paper_age(r: Rect2) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4410 + kind.hash()
		for i in 7:
			draw_rect(r.grow(-i * 3.0), Color(0.55, 0.45, 0.2, 0.025), false, 3.0)
		for i in 500:
			var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
			draw_rect(Rect2(p, Vector2(rng.randf_range(1.0, 3.0), 1.0)), Color(0.3, 0.27, 0.2, rng.randf_range(0.03, 0.08)))

	## Halcyon's mark: a gold diamond with an H cut through it.
	func _logo(c: Vector2, k: float) -> void:
		var d := 20.0 * k
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), ArtPalette.HALCYON_GOLD)
		var navy := DocumentView.BROCHURE_NAVY
		draw_rect(Rect2(c + Vector2(-8, -9) * k, Vector2(3.5, 18) * k), navy)
		draw_rect(Rect2(c + Vector2(4.5, -9) * k, Vector2(3.5, 18) * k), navy)
		draw_rect(Rect2(c + Vector2(-8, -1.5) * k, Vector2(16, 3) * k), navy)

	func _shadow(r: Rect2) -> void:
		draw_rect(Rect2(r.position + Vector2(12, 14), r.size), Color(0, 0, 0, 0.35))

	func _sheen(r: Rect2) -> void:
		# A soft diagonal glare across the gloss.
		var pts := PackedVector2Array([Vector2(r.size.x * 0.55, 0), Vector2(r.size.x * 0.7, 0), Vector2(r.size.x * 0.35, r.size.y), Vector2(r.size.x * 0.2, r.size.y)])
		draw_colored_polygon(pts, Color(1, 1, 1, 0.07))

	func _footer(text: String, r: Rect2) -> void:
		draw_string(NotebookArt.type_font(), Vector2(120, r.size.y - 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.4, 0.42))


## A SubViewport that draws for a few frames, then keeps its last picture.
class _RenderOnce extends SubViewport:
	var _frames := 0

	func _init() -> void:
		render_target_update_mode = SubViewport.UPDATE_ALWAYS

	func _process(_delta: float) -> void:
		_frames += 1
		if _frames == 8:
			render_target_update_mode = SubViewport.UPDATE_ONCE
			set_process(false)


## The cells of a ruled table row, with the printed rules drawn under the writing.
class _Cells extends HBoxContainer:
	var widths: Array[float] = []
	var header := false
	var over: Label  # red pen across the row

	func _init() -> void:
		add_theme_constant_override("separation", 0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func add_cell(content: Label, height: float) -> void:
		var cell := Control.new()
		cell.name = "Cell%d" % get_child_count()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.custom_minimum_size = Vector2(widths[get_child_count()] if get_child_count() < widths.size() else 80.0, height)
		cell.add_child(content)
		add_child(cell)

	func _process(_delta: float) -> void:
		for cell in get_children():
			for l in cell.get_children():
				if l is Label and l != over:
					l.reset_size()
					l.position = Vector2(8, (cell.size.y - l.size.y) / 2.0)
		if over:
			over.reset_size()
			over.position = Vector2(14, (over.get_parent().size.y - over.size.y) / 2.0)

	func _draw() -> void:
		var rule := Color(ArtProps.PRINT_INK, 0.55)
		if header:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.2, 0.25, 0.1))
			draw_line(Vector2(0, 0), Vector2(size.x, 0), rule, 1.8, true)
		draw_line(Vector2(0, size.y), Vector2(size.x, size.y), rule, 2.4 if header else 1.6, true)
		var x := 1.0  # inside the body's clip
		var top := 0.0 if header else -7.0  # meet the rule of the row above
		draw_line(Vector2(x, top), Vector2(x, size.y), rule, 1.6, true)
		for w in widths:
			x += w
			draw_line(Vector2(x, top), Vector2(x, size.y), rule, 1.6, true)


## Spilled coffee over a line: a blot that hides what's under it, its dark edge, the
## ring the mug left, and the ink it dissolved. Drawn in the row's own space.
class _Stain extends Control:
	var row: Control
	var cell: Control
	var seed_text := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		var at := -(get_parent() as Control).position if get_parent() != row else Vector2.ZERO
		if at != position or size != row.size:
			position = at
			size = row.size
			queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(seed_text.hash())
		var r := clampf(size.y * 0.85, 26.0, 44.0)
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		if cell:
			# Centred just past the first letters, so only they stay readable.
			var cr := Rect2(cell.get_parent().position + cell.position, cell.size)
			var lead := 0.0
			for l in cell.get_children():
				if l is Label:
					lead = l.position.x + l.size.x
			c = Vector2(cr.position.x + lead + r * 1.75, cr.get_center().y + rng.randf_range(-3, 3))
			# The rest of the name, dissolved: blue ink bled into the coffee.
			var x := cr.position.x + lead + 3.0
			var pts := PackedVector2Array()
			while x < c.x + r * 0.9:
				pts.append(Vector2(x, c.y + 4.0 + sin(x * 0.5) * 6.0 + rng.randf_range(-1.5, 1.5)))
				x += 2.5
			draw_polyline(pts, Color(0.2, 0.25, 0.45, 0.35), 4.0, true)
		# The spill: soaked paper, darker where it dried at the edge.
		var blot := _blob(rng, c, r, 0.22)
		draw_colored_polygon(blot, Color(0.7, 0.5, 0.28, 0.55))
		draw_colored_polygon(_blob(rng, c + Vector2(rng.randf_range(-5, 5), rng.randf_range(-3, 3)), r * 0.75, 0.25), Color(0.72, 0.53, 0.3, 0.35))
		var edge := blot.duplicate()
		edge.append(blot[0])
		draw_polyline(edge, Color(DocumentView.COFFEE, 0.3), 3.0, true)
		draw_polyline(edge, Color(DocumentView.COFFEE.darkened(0.3), 0.22), 1.2, true)
		# The mug's ring, half-dry, a little off from the spill.
		var mc := c + Vector2(rng.randf_range(-r, r) * 0.8, rng.randf_range(-r, r) * 0.4)
		var start := rng.randf_range(0.0, TAU)
		draw_arc(mc, r * 1.5, start, start + rng.randf_range(3.4, 5.0), 56, Color(DocumentView.COFFEE, 0.32), 3.0, true)
		draw_arc(mc, r * 1.5 - 3.0, start + 0.5, start + 2.0, 24, Color(DocumentView.COFFEE, 0.15), 1.5, true)
		for i in 3:
			var a := rng.randf_range(0.0, TAU)
			draw_circle(c + Vector2(cos(a) * 1.9, sin(a)) * r * rng.randf_range(1.15, 1.4), rng.randf_range(1.5, 3.5), Color(0.6, 0.4, 0.2, 0.4))

	static func _blob(rng: RandomNumberGenerator, c: Vector2, r: float, wobble: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var n := 28
		var phase := rng.randf_range(0.0, TAU)
		for i in n:
			var a := TAU * i / n
			var k := 1.0 + wobble * (sin(a * 3.0 + phase) * 0.6 + rng.randf_range(-0.5, 0.5))
			pts.append(c + Vector2(cos(a) * r * 1.7, sin(a) * r * 0.85) * k)
		return pts


## A rubber stamp: a double-ruled box of capitals, the ink uneven and broken.
class _Stamp extends Control:
	const FONT_SIZE := 30
	var text := ""
	var ink := DocumentView.STAMP_RED

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _get_minimum_size() -> Vector2:
		var w := NotebookArt.type_font().get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		return Vector2(w + 44, 66)

	func _ready() -> void:
		size = get_minimum_size()
		pivot_offset = size / 2

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, get_minimum_size())
		var c := Color(ink, 0.78)
		draw_rect(r, c, false, 3.0)
		draw_rect(r.grow(-6), c, false, 1.5)
		var font := NotebookArt.type_font()
		var base := Vector2(22, r.size.y / 2 + FONT_SIZE * 0.33)
		draw_string(font, base, text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, c)
		draw_string(font, base + Vector2(0.8, 0.4), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(ink, 0.35))
		# Where the stamp didn't take: flecks of paper through the ink.
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(text.hash())
		for i in 70:
			var p := Vector2(rng.randf_range(0, r.size.x), rng.randf_range(0, r.size.y))
			draw_rect(Rect2(p, Vector2(rng.randf_range(1.5, 5.0), rng.randf_range(1.0, 2.5))), Color(0.97, 0.96, 0.92, 0.85))


## A line on the page: a highlighter band and the add chip while the pointer is on it.
class _Row extends HBoxContainer:
	const BAND := Color(0.98, 0.9, 0.42, 0.38)  # yellow highlighter: yellow means "notebook"
	var copy_text := ""
	var margin_width := 0.0
	var chip: Button
	var hovered := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _process(_delta: float) -> void:
		var on := copy_text.strip_edges() != "" and is_visible_in_tree() and Rect2(Vector2(-6, -2), size + Vector2(6, 4)).has_point(get_local_mouse_position())
		if on != hovered:
			set_hovered(on)
		elif hovered:
			_place_chip()

	func set_hovered(on: bool) -> void:
		hovered = on
		if chip:
			chip.visible = on
			_place_chip()
		queue_redraw()

	## In the margin beside the line, like a tab: the line's own text stays clear.
	func _place_chip() -> void:
		if chip == null or not chip.visible:
			return
		chip.reset_size()
		var anchor := chip.get_parent() as Control
		chip.position = Vector2(size.x - chip.size.x, (size.y - chip.size.y) / 2.0) - anchor.position

	func _text_rect() -> Rect2:
		return Rect2(Vector2(-6, -2), Vector2(size.x - margin_width + 2, size.y + 4))

	func _draw() -> void:
		if hovered:
			draw_rect(_text_rect(), BAND)
