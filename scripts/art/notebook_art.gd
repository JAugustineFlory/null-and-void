class_name NotebookArt
extends RefCounted
## The look of the player's notebook and the sticky notes in it: a 1997 spiral
## notebook, the player's notes in handwriting, SQL in a typewriter face so every
## quote and comma stays readable. NotebookView draws the book; these helpers
## make the things you put on its pages. See docs/art/style-guide.md.

const PAPER := Color(0.96, 0.94, 0.86)
const RULE := Color(0.55, 0.68, 0.85, 0.55)  # pale blue ruled lines
const MARGIN := Color(0.85, 0.35, 0.35, 0.6)  # the red margin line
const INK := Color(0.12, 0.15, 0.32)  # blue-black ballpoint
const PENCIL := Color(0.35, 0.35, 0.37)
const RED_PEN := Color(0.7, 0.12, 0.1)
const TAPE := Color(0.95, 0.94, 0.85, 0.55)
const LINE_HEIGHT := 30  # ruled line spacing in the notebook, pixels at 1x

const HAND_FONT_PATH := "res://assets/art/fonts/PatrickHand-Regular.ttf"
const TYPE_FONT_PATH := "res://assets/art/fonts/CourierPrime-Regular.ttf"

static var _hand: Font
static var _type: Font


## The handwriting font (Patrick Hand, OFL): the player's own notes.
static func hand_font() -> Font:
	if _hand == null:
		_hand = _load_font(HAND_FONT_PATH, ["Comic Sans MS", "Segoe Print", "sans-serif"])
	return _hand


## The typewriter font (Courier Prime, OFL): SQL syntax and examples.
static func type_font() -> Font:
	if _type == null:
		_type = _load_font(TYPE_FONT_PATH, ["Courier New", "DejaVu Sans Mono", "monospace"])
	return _type


static func _load_font(path: String, fallback: Array) -> Font:
	# Works before the editor has imported the file (tests on a fresh checkout).
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is Font:
			return f
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(path) == OK:
			return ff
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(fallback)
	return sf


## A line of handwriting, wrapped to the page.
static func hand(text: String, size: int = 26, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", hand_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A page heading: bigger handwriting, underlined twice like you meant it.
static func heading(text: String, color: Color = INK) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(hand(text, 38, color))
	for i in 2:
		var line := ColorRect.new()
		line.color = Color(color, 0.8)
		line.custom_minimum_size = Vector2(0, 2)
		line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		line.custom_minimum_size.x = 40 + text.length() * 14 - i * 30
		box.add_child(line)
		if i == 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 3)
			box.add_child(gap)
	return box


## SQL in typewriter text. Never wraps mid-keyword.
static func code(text: String, size: int = 20, color: Color = Color(0.1, 0.1, 0.12)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_override("font", type_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A sticky note taped to the page: the keyword in big handwriting, then its
## syntax and a worked example in typewriter text. `tilt` in degrees; by default
## each note leans a little its own way.
static func sticky(keyword: String, syntax: String, example: String, paper: Color = ArtProps.STICKY_YELLOW, tilt: float = INF) -> Control:
	var holder := Control.new()  # keeps the layout square while the note leans
	holder.custom_minimum_size = Vector2(380, 212)
	var note := PanelContainer.new()
	note.name = "Note"
	var sb := StyleBoxFlat.new()
	sb.bg_color = paper
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(3, 4)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 18
	sb.content_margin_bottom = 14
	note.add_theme_stylebox_override("panel", sb)
	note.size = Vector2(370, 198)
	note.position = Vector2(5, 6)
	note.pivot_offset = note.size / 2
	note.rotation_degrees = (float(abs(keyword.hash()) % 7) - 3.0) * 0.8 if tilt == INF else tilt
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(hand(keyword, 34))
	if syntax != "":
		box.add_child(code(syntax, 17))
	if example != "":
		var eg := hand("e.g.", 20, PENCIL)
		box.add_child(eg)
		box.add_child(code(example, 16, Color(0.16, 0.16, 0.2)))
	note.add_child(box)
	holder.add_child(note)
	var tape := ColorRect.new()
	tape.name = "Tape"
	tape.color = TAPE
	tape.size = Vector2(110, 26)
	tape.position = Vector2(note.size.x / 2 - 55, -12)
	tape.pivot_offset = tape.size / 2
	tape.rotation_degrees = -4.0
	tape.position += note.position
	tape.rotation_degrees += note.rotation_degrees
	holder.add_child(tape)  # on the holder: a PanelContainer would stretch it over the note
	return holder


## A table you found, written down: its name and columns, one per ruled line.
static func table_card(table_name: String, columns: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var title := hand(table_name, 30, INK)
	box.add_child(title)
	for c in columns:
		var row := HBoxContainer.new()
		var dash := hand("  -", 24, PENCIL)
		dash.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(dash)
		var col := code(str(c), 18)
		col.autowrap_mode = TextServer.AUTOWRAP_OFF
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		box.add_child(row)
	return box


## A scribbled margin note in red pen, for warnings ("this status can lie").
static func margin_note(text: String) -> Label:
	var l := hand(text, 22, RED_PEN)
	l.rotation_degrees = -2.0
	return l
