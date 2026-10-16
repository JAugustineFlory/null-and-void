class_name HUD
extends CanvasLayer
## On-screen info: crosshair, prompts, subtitles, objective, notices, damage.

var _prompt: Label
var _subtitle: Label
var _objective: Label
var _notice: Label
var _damage: ColorRect
var _fade: ColorRect
var _crosshair: Label
var _notice_tween: Tween
var _line_id := 0
var _voice: Voice


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
	_subtitle.position = Vector2(-550, -170)
	root.add_child(_subtitle)

	_objective = ThemeUtil.label("", 22, Color(0.85, 0.9, 1.0))
	_objective.position = Vector2(28, 24)
	root.add_child(_objective)

	_notice = ThemeUtil.label("", 26, ThemeUtil.AMBER)
	_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.custom_minimum_size = Vector2(1200, 0)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.position = Vector2(-600, 70)
	root.add_child(_notice)

	var keys := ThemeUtil.label("WASD move · Shift sprint · Ctrl crouch/slide/roll · Space jump/mantle/grab · E use/boost · F flashlight · Click strike", 15, Color(1, 1, 1, 0.45))
	keys.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	keys.position = Vector2(28, -36)
	root.add_child(keys)

	_voice = Voice.new()
	_voice.name = "Voice"
	add_child(_voice)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_objective(text: String) -> void:
	_objective.text = "OBJECTIVE: " + text if text != "" else ""


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


## Speak a line from VoiceLines by id. Plays its recording if there is one
## and keeps the subtitle up for as long as it lasts; otherwise the subtitle
## is timed from the text. Await it to wait until the line is over.
## subtitle = false plays the voice only, for lines the screen already shows.
func line(id: String, subtitle: bool = true) -> void:
	var l := VoiceLines.get_line(id)
	if l.is_empty():
		push_warning("No voice line with id '%s'" % id)
		return
	var dur := _voice.play(id)
	var has_audio := dur > 0.0
	if not has_audio:
		dur = Voice.read_time(l["text"])
	if subtitle:
		await _show(l["speaker"], l["text"], dur)
	elif has_audio:
		await get_tree().create_timer(dur).timeout


## Speak several lines in order.
func lines(ids: Array) -> void:
	for id in ids:
		await line(id)


func _show(speaker: String, text: String, dur: float) -> void:
	_line_id += 1
	var my_id := _line_id
	_subtitle.text = ("%s: %s" % [speaker, text]) if speaker != "" else text
	await get_tree().create_timer(dur).timeout
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
