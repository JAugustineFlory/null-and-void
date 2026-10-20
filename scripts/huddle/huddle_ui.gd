class_name HuddleUI
extends CanvasLayer
## The open book during a huddle: the chapter's page while it's read aloud, then
## the quiz with everyone's votes. It only draws the Huddle's state; every press
## goes back through the Huddle, which asks the host.

const PAPER := Color(0.97, 0.95, 0.88)
const INK := Color(0.13, 0.12, 0.12)
const COVER := Color(0.95, 0.78, 0.1)  # the book's yellow cover
const RIGHT := Color(0.12, 0.5, 0.2)
const WRONG := Color(0.7, 0.15, 0.1)
## Multiplies the flashback's picture towards an old photo's brown.
const SEPIA := Color(1.0, 0.84, 0.62)

var huddle: Huddle
var flashback := false
var _title: Label
var _body: RichTextLabel
var _footer: Label
var _buttons: HBoxContainer
var _back: Button
var _next: Button
var _options: VBoxContainer
var _result: Label


static func create(for_huddle: Huddle, is_flashback: bool) -> HuddleUI:
	var ui := HuddleUI.new()
	ui.name = "HuddleUI"
	ui.huddle = for_huddle
	ui.flashback = is_flashback
	for_huddle.add_child(ui)
	return ui


func _ready() -> void:
	layer = 20
	if flashback:
		var tint := ColorRect.new()
		tint.color = SEPIA
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		tint.material = mat
		add_child(tint)
		var caption := ThemeUtil.label("The garage, earlier that night", 26, Color(1, 0.95, 0.85))
		caption.position = Vector2(40, 30)
		add_child(caption)

	var panel := PanelContainer.new()
	panel.name = "Book"
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -660
	panel.offset_right = -40
	panel.offset_top = 40
	panel.offset_bottom = -40
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = COVER
	sb.set_border_width_all(10)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_title = _ink("", 26)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("default_color", INK)
	_body.add_theme_font_size_override("normal_font_size", 22)
	_body.add_theme_font_size_override("mono_font_size", 20)
	_body.add_theme_font_override("mono_font", ThemeUtil.mono())
	box.add_child(_body)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 8)
	box.add_child(_options)
	_result = _ink("", 21)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_result)
	_footer = _ink("", 18, Color(0.35, 0.33, 0.3))
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_footer)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	box.add_child(_buttons)
	_back = Button.new()
	_back.name = "Back"
	_back.text = "< Back"
	_back.pressed.connect(func(): huddle.turn_page(-1))
	_buttons.add_child(_back)
	_next = Button.new()
	_next.name = "Next"
	_next.text = "Turn the page >"
	_next.pressed.connect(func(): huddle.turn_page(1))
	_buttons.add_child(_next)

	huddle.changed.connect(_redraw)
	_redraw()


func _ink(text: String, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _redraw() -> void:
	var ch := huddle.chapter
	if ch.is_empty():
		_title.text = ""
		_body.text = ""
		_footer.text = "Closing the book..." if not huddle.done.is_empty() else "Opening the book..."
		_buttons.visible = false
		_clear_options()
		_result.text = ""
		return
	_title.text = "%s\nChapter %d: %s" % [ch.book, ch.number, ch.title]
	if huddle.question < 0:
		_draw_page(ch)
	else:
		_draw_question(ch)


func _draw_page(ch: Dictionary) -> void:
	_body.text = _bbcode(ch.pages[huddle.page])
	_clear_options()
	_result.text = ""
	var reader := huddle.player_name(huddle.reader_id)
	var last: bool = huddle.page == ch.pages.size() - 1
	_buttons.visible = huddle.is_reader()
	_back.disabled = huddle.page == 0
	_next.text = "Start the quiz >" if last else "Turn the page >"
	if huddle.is_reader():
		_footer.text = "Page %d of %d. You're reading this one out to the crew." % [huddle.page + 1, ch.pages.size()]
	else:
		_footer.text = "Page %d of %d. %s is reading it out." % [huddle.page + 1, ch.pages.size(), reader]


func _draw_question(ch: Dictionary) -> void:
	var q := huddle.current_question()
	_buttons.visible = false
	var word: String = q.get("word", "")
	_body.text = "[b]Quick check %d of %d[/b]%s\n%s" % [huddle.question + 1, ch.quiz.size(),
		("  " + _escape(word)) if word != "" else "", _escape(q.q)]
	_clear_options()
	var me := multiplayer.get_unique_id()
	for i in q.options.size():
		var b := Button.new()
		b.name = "Option%d" % i
		var who := []
		for id in huddle.votes:
			if huddle.votes[id] == i:
				who.append(huddle.player_name(id))
		var mark := ">  " if huddle.votes.get(me, -1) == i else "    "
		b.text = mark + str(q.options[i]) + ("     (%s)" % ", ".join(who) if not who.is_empty() else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", ThemeUtil.mono())
		b.disabled = not huddle.result.is_empty()
		b.pressed.connect(huddle.vote.bind(i))
		_options.add_child(b)
	var total := NetPlayers.ids_for(multiplayer).size()
	if huddle.result.has("split"):
		_result.text = "The crew is split. Talk it over and vote again."
		_result.add_theme_color_override("font_color", INK)
	elif huddle.result.has("choice"):
		var right: bool = huddle.result.right
		_result.text = ("Right. " if right else "Not quite. ") + str(q.get("why", ""))
		_result.add_theme_color_override("font_color", RIGHT if right else WRONG)
	else:
		_result.text = ""
	if huddle.result.is_empty():
		_footer.text = "Pick an answer. Votes in: %d of %d." % [huddle.votes.size(), total] if total > 1 else "Pick an answer."
	elif huddle.result.get("right", false):
		_footer.text = ""
	else:
		_footer.text = "Same question again in a moment."


func _clear_options() -> void:
	for c in _options.get_children():
		_options.remove_child(c)
		c.queue_free()


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


## Indented lines in a page are code: they show in the typewriter font.
static func _bbcode(text: String) -> String:
	var out := []
	for line in text.split("\n"):
		var safe := line.replace("[", "[lb]")
		out.append("[code]%s[/code]" % safe if line.begins_with("    ") else safe)
	return "\n".join(out)
