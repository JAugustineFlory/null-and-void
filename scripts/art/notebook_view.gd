class_name NotebookView
extends Control
## The open spiral notebook, drawn in code: a cardboard cover, two ruled cream
## pages with a red margin, wire coils down the middle and colored tabs on the
## edge. Fill `left` and `right` with NotebookArt pieces; the mechanics (what's
## on which page, Tab to open) belong to the notebook's own script.
##
##   var book := NotebookView.new()
##   canvas_layer.add_child(book)          # layer 15: above VHS (3), below the terminal (20)
##   book.add_tab("Notes"); book.add_tab("Tables"); book.add_tab("Field Notes")
##   book.left.add_child(NotebookArt.heading("SELECT"))
##   book.show_book()

signal tab_pressed(tab_name: String)

const BOOK_SIZE := Vector2(1240, 780)  # design size; scaled to fit the screen
const PAGE_INSET := Vector2(26, 22)
const SPINE := 56.0
const COVER := Color(0.16, 0.2, 0.3)  # navy pressboard cover
## Size of the SubViewport HeldNotebook renders an embedded book into: the book plus its tabs.
const EMBED_SIZE := Vector2i(1440, 800)
const EMBED_MARGIN := Vector2(12, 10)
const TAB_COLORS: Array[Color] = [Color(0.95, 0.82, 0.35), Color(0.55, 0.78, 0.92), Color(0.92, 0.6, 0.62), Color(0.65, 0.85, 0.58)]

var left: VBoxContainer
var right: VBoxContainer
var book: Control  # everything that moves when the book opens or a page turns
var _tabs: VBoxContainer
var _tab_buttons := {}
## Drawn into HeldNotebook's SubViewport instead of over the screen: no dimming,
## no scaling, and HeldNotebook animates it in and out.
var embedded := false:
	set(v):
		embedded = v
		var dim := get_node_or_null("Dim")
		if dim:
			dim.visible = not v
		_fit()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	book = _BookDrawing.new()
	book.name = "Book"
	book.size = BOOK_SIZE
	book.pivot_offset = BOOK_SIZE / 2
	add_child(book)
	var page_w := (BOOK_SIZE.x - SPINE) / 2.0 - PAGE_INSET.x
	left = _page_box(Vector2(PAGE_INSET.x + 70, PAGE_INSET.y + 60), page_w - 100)
	right = _page_box(Vector2(BOOK_SIZE.x / 2 + SPINE / 2 + 70, PAGE_INSET.y + 60), page_w - 100)
	left.name = "Left"
	right.name = "Right"
	_tabs = VBoxContainer.new()
	_tabs.name = "Tabs"
	_tabs.position = Vector2(BOOK_SIZE.x - 6, 90)
	_tabs.add_theme_constant_override("separation", 6)
	book.add_child(_tabs)
	resized.connect(_fit)


func _ready() -> void:
	_fit()


func _page_box(pos: Vector2, width: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.position = pos
	box.size = Vector2(width, BOOK_SIZE.y - pos.y - PAGE_INSET.y - 30)
	box.clip_contents = true
	box.add_theme_constant_override("separation", 8)
	book.add_child(box)
	return box


## A colored index tab sticking out of the right edge. Returns the button.
func add_tab(tab_name: String) -> Button:
	var b := Button.new()
	b.name = tab_name
	b.text = tab_name
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 54)
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var col: Color = TAB_COLORS[_tab_buttons.size() % TAB_COLORS.size()]
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.lightened(0.12) if state == "hover" else col
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_right = 10
		sb.content_margin_right = 14
		sb.content_margin_left = 30
		sb.shadow_color = Color(0, 0, 0, 0.25)
		sb.shadow_size = 3
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_font_override("font", NotebookArt.hand_font())
	b.add_theme_font_size_override("font_size", 26)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, NotebookArt.INK)
	b.pressed.connect(func(): select_tab(tab_name); tab_pressed.emit(tab_name))
	_tabs.add_child(b)
	_tab_buttons[tab_name] = b
	if _tab_buttons.size() == 1:
		select_tab(tab_name)
	return b


## Pushes the chosen tab further out so you can see which section is open.
func select_tab(tab_name: String) -> void:
	for n in _tab_buttons:
		_tab_buttons[n].custom_minimum_size.x = 172 if n == tab_name else 150


## Empties both pages (before showing another section).
func clear_pages() -> void:
	for page in [left, right]:
		for c in page.get_children():
			page.remove_child(c)
			c.queue_free()


## Slides the book up from the bottom of the screen, already open.
func show_book() -> Tween:
	visible = true
	_fit()
	if embedded:
		modulate.a = 1.0
		var now := create_tween()
		now.tween_interval(0.0)
		return now
	var rest := book.position
	book.position.y = rest.y + size.y
	book.rotation_degrees = -4.0
	modulate.a = 0.0
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(book, "position:y", rest.y, 0.28)
	t.tween_property(book, "rotation_degrees", -0.6, 0.28)
	t.tween_property(self, "modulate:a", 1.0, 0.15)
	return t


## Drops the book back out of view, then hides it.
func hide_book() -> Tween:
	if embedded:
		var held := create_tween()
		held.tween_interval(0.25)  # HeldNotebook puts the book away
		held.tween_callback(func(): visible = false)
		return held
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(book, "position:y", book.position.y + size.y, 0.2)
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.chain().tween_callback(func(): visible = false; _fit())
	return t


## A quick page turn: squash, swap content in `between`, spring back.
func turn_page(between: Callable = Callable()) -> Tween:
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(book, "scale:x", book.scale.x * 0.96, 0.08)
	if between.is_valid():
		t.tween_callback(between)
	t.tween_property(book, "scale:x", book.scale.x, 0.1)
	return t


## Writes `item` onto the page: it appears left to right behind a moving pen nib,
## as if the player were writing it down. Call after adding it to a page.
func write_in(item: Control, duration: float = 0.8) -> Tween:
	var cover := ColorRect.new()
	cover.name = "Unwritten"
	cover.color = NotebookArt.PAPER
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pen := _Pen.new()
	pen.name = "Pen"
	pen.visible = false
	book.add_child(cover)
	book.add_child(pen)
	var span := {"x": 0.0, "w": 0.0, "y": 0.0}
	var t := create_tween()
	t.tween_interval(0.03)  # let the page lay the item out first
	t.tween_callback(func():
		var at := book.get_global_transform().affine_inverse() * item.global_position
		span.x = at.x - 2
		span.w = item.size.x + 6
		span.y = at.y + item.size.y * 0.7
		cover.position = Vector2(span.x, at.y - 2)
		cover.size = Vector2(span.w, item.size.y + 4)
		pen.visible = true)
	t.tween_method(func(k: float):
		cover.position.x = span.x + span.w * k
		cover.size.x = span.w * (1.0 - k)
		pen.position = Vector2(span.x + span.w * k, span.y + sin(k * 60.0) * 3.0), 0.0, 1.0, duration)
	t.tween_callback(func():
		cover.queue_free()
		pen.queue_free())
	return t


func _fit() -> void:
	if book == null or size.x <= 0:
		return
	if embedded:
		book.scale = Vector2.ONE
		book.position = EMBED_MARGIN
		return
	var s := minf((size.x - 80) / (BOOK_SIZE.x + 180), (size.y - 60) / BOOK_SIZE.y)
	s = clampf(s, 0.4, 1.4)
	book.scale = Vector2(s, s)
	book.position = (size - BOOK_SIZE) / 2 - Vector2(60 * s, 0)


## The paper, lines and coils, drawn in one pass.
class _BookDrawing extends Control:
	func _draw() -> void:
		var bs := NotebookView.BOOK_SIZE
		draw_rect(Rect2(Vector2(10, 14), bs), Color(0, 0, 0, 0.35))  # shadow on the desk
		draw_rect(Rect2(Vector2.ZERO, bs), NotebookView.COVER)
		var inset := NotebookView.PAGE_INSET
		var half := (bs.x - NotebookView.SPINE) / 2.0
		for side in 2:
			var x0 := inset.x if side == 0 else bs.x / 2 + NotebookView.SPINE / 2
			var page := Rect2(Vector2(x0, inset.y), Vector2(half - inset.x, bs.y - inset.y * 2))
			# a couple of page edges peeking out underneath
			for k in [2, 1]:
				draw_rect(Rect2(page.position + Vector2(0, k * 3), page.size), NotebookArt.PAPER.darkened(0.06 * k))
			draw_rect(page, NotebookArt.PAPER)
			var y := page.position.y + 80
			while y < page.end.y - 10:
				draw_line(Vector2(page.position.x + 6, y), Vector2(page.end.x - 6, y), NotebookArt.RULE, 1.5)
				y += NotebookArt.LINE_HEIGHT
			var mx := page.position.x + 56
			draw_line(Vector2(mx, page.position.y), Vector2(mx, page.end.y), NotebookArt.MARGIN, 2.0)
			# punched holes along the spine edge
			var hx := page.end.x - 16 if side == 0 else page.position.x + 16
			var hy := page.position.y + 28
			while hy < page.end.y - 20:
				draw_circle(Vector2(hx, hy), 6, NotebookView.COVER.darkened(0.3))
				hy += 34
		# the wire coil
		var cx := bs.x / 2
		var cy := inset.y + 28
		while cy < bs.y - inset.y - 20:
			var a := Vector2(cx - NotebookView.SPINE / 2 - 16, cy)
			var b := Vector2(cx + NotebookView.SPINE / 2 + 16, cy)
			draw_line(a + Vector2(0, 2), b + Vector2(0, 2), Color(0, 0, 0, 0.35), 5)
			draw_line(a, b, Color(0.72, 0.73, 0.76), 4)
			draw_line(a + Vector2(4, -1), b + Vector2(-4, -1), Color(0.92, 0.93, 0.95), 1.5)
			cy += 34


## A ballpoint pen nib, drawn while a line is being written in.
class _Pen extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_line(Vector2(0, 0), Vector2(70, -110), Color(0, 0, 0, 0.25), 16)  # shadow
		draw_line(Vector2(4, -6), Vector2(66, -118), Color(0.16, 0.2, 0.42), 12)  # barrel
		draw_line(Vector2(0, 0), Vector2(8, -14), Color(0.75, 0.76, 0.78), 6)  # tip
		draw_circle(Vector2(0, 0), 2.5, NotebookArt.INK)
