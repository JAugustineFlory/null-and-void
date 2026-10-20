class_name NewsEnding
extends CanvasLayer
## The ending if Rourke downs the whole crew in Vale's lab: the frame worked.
## Black, then the next morning's paper on a kitchen table while the radio reads
## the story, then "try again" (back into the fight).
##
## Words: Voice's draft, script/drafts/news-ending.md, waiting for Augustine's
## word-for-word approval. The radio lines play from VoiceLines once Voice wires
## them (l2_news_1..5); until then their draft text shows, timed for reading.

signal finished

## Lines for Augustine's approval: see plan/approvals/combat-strings.md.
const MASTHEAD := "THE HALCYON COURIER"
const DATELINE := "FRIDAY, OCTOBER 17, 1997"
const HEADLINE := "IT CONTRACTORS SOUGHT IN DEATH OF HALCYON SCIENTIST"
const SUBHEAD := "Byte-Right crew vanished after overnight call; badge records place them in victim's lab"
const TEASER := "Facilities manager hurt trying to stop them · Page 3"
const RETRY := "Press E to try again"
const SPEAKER := "RADIO"
## The radio report, in order, with Voice's draft text for lines not wired yet.
const RADIO := [
	["l2_news_1", "Police are searching for the crew of Byte-Right IT Services, a small firm hired for overnight repairs at Halcyon Data Systems."],
	["l2_news_2", "Badge records place the crew inside the laboratory of Dr. Iris Vale, who police now believe was murdered."],
	["l2_news_3", "A facilities manager who tried to stop them described the crew as, quote, 'nice enough. Nervous. Not who they said they were.'"],
	["l2_news_4", "Byte-Right's only office, a rented garage, was found empty. The crew has not been seen since."],
	["l2_news_5", "Halcyon says the building is safe, and will reopen as normal on Monday. And now, the weather."],
]
const PAPER := Color(0.9, 0.87, 0.78)
const INK := Color(0.12, 0.11, 0.1)
const TABLE := Color(0.24, 0.16, 0.1)
## Without a key press, it moves on by itself after this long.
const RETRY_WAIT := 20.0

var hud: Node
var paper: Control
var radio: Label
var retry: Label
var _black: ColorRect
var _waiting := false
var _skip := false


## Show it over `parent` and return when the player is ready to try again.
static func play(parent: Node, the_hud: Node) -> void:
	var n := NewsEnding.new()
	n.hud = the_hud
	parent.add_child(n)
	await n.run()
	n.queue_free()


func _ready() -> void:
	name = "NewsEnding"
	layer = 24  # over the HUD, like the end card
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.modulate.a = 0.0
	add_child(_black)

	var table := ColorRect.new()
	table.color = TABLE
	table.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.add_child(table)
	paper = _make_paper()
	paper.modulate.a = 0.0
	table.add_child(paper)

	radio = ThemeUtil.label("", 26, Color.WHITE)
	radio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	radio.offset_left = -560
	radio.offset_right = 560
	radio.offset_top = -150
	radio.offset_bottom = -60
	_black.add_child(radio)

	retry = ThemeUtil.label(RETRY, 22, ThemeUtil.AMBER)
	retry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retry.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	retry.offset_left = -300
	retry.offset_right = 300
	retry.offset_top = -48
	retry.offset_bottom = -20
	retry.visible = false
	_black.add_child(retry)


## A front page, tilted a little on the table.
func _make_paper() -> Control:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.content_margin_left = 40
	box.content_margin_right = 40
	box.content_margin_top = 28
	box.content_margin_bottom = 28
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 18
	p.add_theme_stylebox_override("panel", box)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -430
	p.offset_right = 430
	p.offset_top = -300
	p.offset_bottom = 170
	p.pivot_offset = Vector2(430, 235)
	p.rotation = -0.03
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	p.add_child(col)
	col.add_child(_text(MASTHEAD, 44, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_rule())
	col.add_child(_text(DATELINE, 15, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_rule())
	col.add_child(_text(HEADLINE, 38, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(_text(SUBHEAD, 21, HORIZONTAL_ALIGNMENT_LEFT))
	# A grey box where the photo of the crew's van would go, and the teaser.
	var photo := ColorRect.new()
	photo.color = Color(0.55, 0.53, 0.5)
	photo.custom_minimum_size = Vector2(0, 110)
	col.add_child(photo)
	col.add_child(_text(TEASER, 16, HORIZONTAL_ALIGNMENT_LEFT))
	return p


func _text(t: String, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	return l


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = INK
	r.custom_minimum_size = Vector2(0, 2)
	return r


## The whole thing: fade, paper, radio, then wait for the player.
func run() -> void:
	var t := create_tween()
	t.tween_property(_black, "modulate:a", 1.0, 0.8)
	t.tween_interval(0.8)
	t.tween_property(paper, "modulate:a", 1.0, 1.2)
	await t.finished
	for line in RADIO:
		if _skip:
			break
		await _radio(line[0], line[1])
	radio.text = ""
	retry.visible = true
	_waiting = not _skip
	var left := RETRY_WAIT
	while _waiting and left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
	_waiting = false
	finished.emit()


## One radio line: the recording if Voice has wired it, otherwise its draft text,
## held at least long enough to read.
func _radio(id: String, draft: String) -> void:
	var l := VoiceLines.get_line(id)
	radio.text = "%s: %s" % [SPEAKER, l.get("text", draft)]
	var dur := Voice.read_time(radio.text)
	var voice: Node = hud.get("_voice") if hud and not l.is_empty() else null
	if voice:
		dur = maxf(dur, voice.play(id))
	var left := dur
	while left > 0.0 and not _skip:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _unhandled_input(event: InputEvent) -> void:
	if _waiting and event.is_action_pressed("interact"):
		_waiting = false
		get_viewport().set_input_as_handled()


## Tests: run straight to the end.
func skip() -> void:
	_skip = true
	_waiting = false
