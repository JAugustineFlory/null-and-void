class_name HUD
extends CanvasLayer
## On-screen info: crosshair, prompts, subtitles, objective, notices, damage,
## and the main case's pieces (CaseChip).

var _prompt: Label
var _subtitle: Label
var _notice: Label
var _keys: Label
var _damage: ColorRect
var _fade: ColorRect
var _crosshair: Label
var _notice_tween: Tween
var _line_id := 0
var _voice: Voice
## The main case and how many of its pieces are in, top right (CaseChip).
var case_chip: CaseChip


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_damage = ColorRect.new()
	_damage.color = Color(0.6, 0, 0, 0)
	_damage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage)

	_crosshair = ThemeUtil.label("·", 32, Color(1, 1, 1, 0.8))
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.position -= Vector2(10, 22)
	root.add_child(_crosshair)

	_prompt = ThemeUtil.label("", 22, Color(1, 1, 0.85))
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.custom_minimum_size = Vector2(900, 0)
	_prompt.position = Vector2(-450, 40)
	root.add_child(_prompt)

	_subtitle = ThemeUtil.label("", 26, Color.WHITE)
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size = Vector2(1100, 0)
	root.add_child(_subtitle)

	_notice = ThemeUtil.label("", 26, ThemeUtil.AMBER)
	_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.custom_minimum_size = Vector2(1200, 0)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.position = Vector2(-600, 70)
	root.add_child(_notice)

	_keys = ThemeUtil.label("WASD move · Shift sprint · Ctrl crouch · Space jump · E use · F flashlight · Tab notebook · 1-4 items · I inventory · Esc menu and all controls", 17, Color(1, 1, 1, 0.7))
	_keys.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_keys.position = Vector2(28, -36)
	root.add_child(_keys)
	case_chip = CaseChip.new()
	case_chip.name = "CaseChip"
	root.add_child(case_chip)
	subtitles_on_top(false)  # lays out the subtitle and notice

	_voice = Voice.new()
	_voice.name = "Voice"
	add_child(_voice)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)


## The dot in the middle of the view; hidden while a mouse pointer is out instead.
func set_crosshair(on: bool) -> void:
	_crosshair.visible = on


func set_prompt(text: String) -> void:
	_prompt.text = text


## Write a task on the player's to-do list in the notebook (it ticks off the one
## before). The screen only flashes that the notebook changed. "" ticks off the
## current task. Never name an answer here: it's what the character would jot down.
func todo(text: String) -> void:
	if get_node("/root/Game").set_todo(text) and text != "":
		notice("Notebook updated (Tab)", 3.0)


## The task on top of the to-do list, or "".
func current_todo() -> String:
	return get_node("/root/Game").current_todo()


## Older name for todo().
func set_objective(text: String) -> void:
	todo(text)


func notice(text: String, seconds: float = 4.0, color: Color = ThemeUtil.AMBER) -> void:
	_notice.text = text
	_notice.add_theme_color_override("font_color", color)
	_notice.modulate.a = 1.0
	if _notice_tween:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(seconds)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.8)


## Show one line of dialogue. Await it to wait until it has been read.
## For character lines use line(id) so the recording plays; this is for
## narration and other text nobody speaks.
func say(speaker: String, text: String, seconds: float = -1.0) -> void:
	await _show(speaker, text, seconds if seconds > 0 else Voice.read_time(text))


## Play several unvoiced lines in order: [[speaker, text], ...]
func play_lines(lines: Array) -> void:
	for line in lines:
		await say(line[0], line[1])


## While a terminal's glass fills the view, subtitles go above it and notices
## below it (where the walking keys were), so neither covers its text.
## Subtitles at the top (at a terminal) or the bottom. At the bottom a long line
## grows upward, so it never runs under the hotbar.
func subtitles_on_top(on: bool) -> void:
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP if on else Control.PRESET_CENTER_BOTTOM)
	_subtitle.offset_left = -550
	_subtitle.offset_right = 550
	_subtitle.grow_vertical = Control.GROW_DIRECTION_END if on else Control.GROW_DIRECTION_BEGIN
	_subtitle.offset_top = 8 if on else -180
	_subtitle.offset_bottom = _subtitle.offset_top
	_notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM if on else Control.PRESET_CENTER_TOP)
	_notice.offset_left = -600
	_notice.offset_right = 600
	_notice.offset_top = -46 if on else 70
	_notice.offset_bottom = _notice.offset_top
	_keys.visible = not on
	if case_chip:
		case_chip.set_allowed(not on)


## Keep subtitles clear of a panel `width` px wide down the right of the screen
## (the open Easy SQL book), low on the left instead of in the middle. 0 puts
## them back.
func subtitles_clear_of_right(width: float) -> void:
	_subtitle.custom_minimum_size.x = 1100 if width <= 0.0 else 0
	if width <= 0.0:
		subtitles_on_top(false)
		return
	_subtitle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle.offset_left = 40
	_subtitle.offset_right = -width - 20
	_subtitle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle.offset_top = -180
	_subtitle.offset_bottom = -180


## Speak a line from VoiceLines by id. Plays its recording if there is one
## and keeps the subtitle up for as long as it lasts; otherwise the subtitle
## is timed from the text. Await it to wait until the line is over.
## subtitle = false plays the voice only, for lines the screen already shows.
## remembered = true plays it as a memory of the line, not someone saying it here (Voice.MEMORY_BUS).
## A crew line can name who says it (`who`, on the subtitle) and use their
## recordings (`voice_dir`, "crew_dana").
func line(id: String, subtitle: bool = true, remembered := false, who: String = "", voice_dir: String = "") -> void:
	var l := VoiceLines.get_line(id)
	if l.is_empty():
		push_warning("No voice line with id '%s'" % id)
		return
	if get_node("/root/Game").jot(VoiceLines.resolve(id), l):
		notice("Notebook updated (Tab)", 3.0)
	var dur := _voice.play(id, voice_dir, remembered)
	var has_audio := dur > 0.0
	if not has_audio:
		dur = Voice.read_time(l["text"])
	if subtitle:
		await _show(who if who != "" else l["speaker"], l["text"], dur)
	elif has_audio:
		await get_tree().create_timer(dur, false).timeout


## Speak several lines in order.
func lines(ids: Array) -> void:
	for id in ids:
		await line(id)


func _show(speaker: String, text: String, dur: float) -> void:
	_line_id += 1
	var my_id := _line_id
	_subtitle.text = ("%s: %s" % [speaker, text]) if speaker != "" else text
	await get_tree().create_timer(dur, false).timeout
	if my_id == _line_id:
		_subtitle.text = ""


func damage_flash(health: float) -> void:
	var base := (1.0 - health / 100.0) * 0.35
	_damage.color.a = base + 0.35
	var tw := create_tween()
	tw.tween_property(_damage, "color:a", base, 0.4)


func strike_swing() -> void:
	_crosshair.modulate = Color(1, 0.6, 0.4)
	var tw := create_tween()
	tw.tween_property(_crosshair, "modulate", Color.WHITE, 0.25)


func fade(to_black: bool, seconds: float = 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0 if to_black else 0.0, seconds)
	await tw.finished
