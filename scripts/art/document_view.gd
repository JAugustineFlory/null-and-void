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

signal copy_requested(text: String)
signal closed

const KINDS := ["memo", "manual", "card", "brochure", "clipboard"]
## Design size of each paper, where its text goes (scaled to fit the screen), the
## width of its margin, and "band": the printed header the title sits in (0 for none).
const PAPERS := {
	"memo": {"size": Vector2(760, 960), "body": Rect2(70, 80, 640, 830), "margin": 170.0, "band": 0},
	"manual": {"size": Vector2(800, 980), "body": Rect2(120, 80, 640, 850), "margin": 170.0, "band": 0},
	"card": {"size": Vector2(1000, 620), "body": Rect2(60, 30, 880, 540), "margin": 170.0, "band": 96},
	"brochure": {"size": Vector2(1100, 760), "body": Rect2(590, 30, 480, 690), "margin": 110.0, "band": 106},
	"clipboard": {"size": Vector2(820, 1060), "body": Rect2(100, 190, 640, 800), "margin": 170.0, "band": 0},
}
const MARGIN_WIDTH := 170.0  # the margin slot beside each line, where notes are written
const TYPE_SIZE := 21
const BROCHURE_NAVY := Color(0.13, 0.2, 0.36)

var kind := "memo"
var margin_width := MARGIN_WIDTH
var paper: Control  # everything that moves when the page is shown
var body: VBoxContainer
var _title: Label
var _close: Button
var _last_row: HBoxContainer


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


## Empties the page for the next document.
func clear() -> void:
	for c in body.get_children():
		if c != _title:
			body.remove_child(c)
			c.queue_free()
	_last_row = null
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
	if paper == null or size.x <= 0:
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
				var y := sheet.position.y + 150
				while y < sheet.end.y - 20:
					draw_line(Vector2(sheet.position.x + 20, y), Vector2(sheet.end.x - 20, y), Color(0.45, 0.5, 0.65, 0.4), 1.2)
					y += 44
				var clip := Rect2(r.size.x / 2 - 140, 40, 280, 100)
				draw_rect(clip, Color(0.62, 0.63, 0.66))
				draw_rect(Rect2(clip.position + Vector2(0, 70), Vector2(clip.size.x, 30)), Color(0.5, 0.51, 0.54))
				draw_rect(Rect2(clip.position + Vector2(20, 10), Vector2(clip.size.x - 40, 8)), Color(0.85, 0.86, 0.88))
				draw_circle(Vector2(r.size.x / 2, 20), 14, Color(0.2, 0.2, 0.22))  # hanging hole
			_:  # memo
				draw_rect(Rect2(r.position + Vector2(14, 12), r.size), Color(0, 0, 0, 0.35))
				draw_rect(Rect2(r.position + Vector2(6, 5), r.size), Color(0.88, 0.88, 0.85))  # the second sheet
				draw_rect(r, Color(0.98, 0.97, 0.94))
				var s := Vector2(40, 34)
				draw_line(s, s + Vector2(30, 24), Color(0.6, 0.62, 0.65), 4)  # staple
				draw_line(s + Vector2(1, -1), s + Vector2(30, 22), Color(0.88, 0.9, 0.92), 1.5)

	func _shadow(r: Rect2) -> void:
		draw_rect(Rect2(r.position + Vector2(12, 14), r.size), Color(0, 0, 0, 0.35))

	func _sheen(r: Rect2) -> void:
		# A soft diagonal glare across the gloss.
		var pts := PackedVector2Array([Vector2(r.size.x * 0.55, 0), Vector2(r.size.x * 0.7, 0), Vector2(r.size.x * 0.35, r.size.y), Vector2(r.size.x * 0.2, r.size.y)])
		draw_colored_polygon(pts, Color(1, 1, 1, 0.07))

	func _footer(text: String, r: Rect2) -> void:
		draw_string(NotebookArt.type_font(), Vector2(120, r.size.y - 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.4, 0.42))


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
		var on := is_visible_in_tree() and Rect2(Vector2(-6, -2), size + Vector2(6, 4)).has_point(get_local_mouse_position())
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
