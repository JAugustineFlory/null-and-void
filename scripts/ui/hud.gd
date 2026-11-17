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

## Lines take turns: one speaker on screen at a time, with a breath between them
## (Augustine's v0.9-beta2 note, 2026-11-17: "a LOT of text and dialogue, without
## much space between"; plan/text-spacing-proposal.md, Teaching's numbers).
## NORMAL waits its turn in order. URGENT is a threat starting (a clock, WARDEN
## turning, the cold): it plays at once and cuts across. CAN_WAIT (teases, banter,
## crew barks) waits for a quiet moment, holds while someone is typing at a
## terminal, and is dropped if it would play more than STALE_AFTER late.
enum Turn { NORMAL, URGENT, CAN_WAIT }
## The breath between two lines of one speaker, and between two speakers.
const GAP_SAME := 0.6
const GAP_CHANGE := 1.2
## A line that can wait, held longer than this, is dropped (its notebook jot is kept).
const STALE_AFTER := 15.0
## Lines that can wait hold until the terminal's been quiet this long, or closes.
const TYPING_QUIET := 3.0
## A line has finished (or given up its turn).
signal turn_over
var _ticket := 0
var _serving := 0
var _urgent := 0
var _last_speaker := ""
## Game seconds (pause and time_scale aware), for the gaps and dropping stale lines.
var _clock := 0.0
var _last_end := -1000.0
## STALE_AFTER, shortened by tests.
var stale_after := STALE_AFTER
## Lines that can wait and are waiting now (their ids, or speaker and text): the
## same one asked again meanwhile is dropped, not queued twice.
var _held := {}
## The main case and how many of its pieces are in, top right (CaseChip).
var case_chip: CaseChip


func _process(delta: float) -> void:
	if not get_tree().paused:
		_clock += delta


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
	_prompt.text = InputGlyphs.text(text)  # [E] reads [X] on a gamepad


## Write a task on the player's to-do list in the notebook (it ticks off the one
## before): its `title`, how the crew feels and what's going on, and its `details`,
## what to do (Augustine's rule, 2026-11-05). One string is a task without a title.
## The screen flashes that the notebook changed and, briefly, "Next: <title>". ""
## ticks off the current task. Never name an answer here: it's what the character
## would jot down.
func todo(title: String, details := "") -> void:
	# One string is a task with no title of its own (or "", ticking off the current one).
	var text := details if details != "" else title
	var named := title if details != "" else ""
	if get_node("/root/Game").set_todo(text, named) and text != "":
		notice("Notebook updated (Tab)", 3.0)
		if named != "" and case_chip:
			case_chip.brief_task(named)


## The task on top of the to-do list, or "".
func current_todo() -> String:
	return get_node("/root/Game").current_todo()


## Older name for todo().
func set_objective(text: String) -> void:
	todo(text)


func notice(text: String, seconds: float = 4.0, color: Color = ThemeUtil.AMBER) -> void:
	_notice.text = InputGlyphs.text(text)
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
## `turn` is a Turn. `start`, if given, runs when the line's turn comes and returns
## the length of the recording it started (0.0 for none), so a voice plays in step
## with its subtitle (Commentary's crew barks).
func say(speaker: String, text: String, seconds: float = -1.0, turn: int = Turn.NORMAL, start: Callable = Callable()) -> void:
	if not await _take_turn(turn, speaker, speaker + ": " + text):
		return
	if start.is_valid():
		var played: float = start.call()
		if played > 0.0:
			seconds = played
	await _show(speaker, text, seconds if seconds > 0 else Voice.read_time(text))
	_end_turn(turn, speaker)


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
## It waits its turn (Turn): `turn` overrides the line's own (VoiceLines `turn`).
## The notebook jot is written at once, even if the line is later dropped.
func line(id: String, subtitle: bool = true, remembered := false, who: String = "", voice_dir: String = "", turn: int = -1) -> void:
	var l := VoiceLines.get_line(id)
	if l.is_empty():
		push_warning("No voice line with id '%s'" % id)
		return
	if get_node("/root/Game").jot(VoiceLines.resolve(id), l):
		notice("Notebook updated (Tab)", 3.0)
	if turn < 0:
		turn = turn_of(l)
	var speaker: String = who if who != "" else str(l["speaker"])
	if not await _take_turn(turn, speaker, id):
		return
	var dur := _voice.play(id, voice_dir, remembered)
	var has_audio := dur > 0.0
	if not has_audio:
		dur = Voice.read_time(l["text"])
	if subtitle:
		await _show(speaker, l["text"], dur)
	elif has_audio:
		await get_tree().create_timer(dur, false).timeout
	_end_turn(turn, speaker)


## A line's own turn, from its VoiceLines entry ("urgent", "can_wait", or normal).
static func turn_of(l: Dictionary) -> int:
	match str(l.get("turn", "")):
		"urgent":
			return Turn.URGENT
		"can_wait":
			return Turn.CAN_WAIT
	return Turn.NORMAL


## True while nobody's speaking or waiting to.
func quiet() -> bool:
	return _ticket == _serving and _urgent == 0


## Wait for this line's turn. False: it was a line that could wait, and it waited
## too long, or the same line (`key`) is already waiting (dropped).
func _take_turn(turn: int, speaker: String, key: String = "") -> bool:
	if turn == Turn.URGENT:
		_urgent += 1
		return true
	if turn == Turn.CAN_WAIT:
		if key != "" and _held.has(key):
			return false
		_held[key] = true
		var since := _clock
		while not (quiet() and _gap_left(speaker) <= 0.0 and not _typing()):
			if _clock - since > stale_after or not is_inside_tree():
				_held.erase(key)
				return false
			await get_tree().create_timer(0.2, false).timeout
			if not is_inside_tree():
				return false
		_held.erase(key)
		_ticket += 1  # nobody was waiting, so this ticket is the one being served
		return true
	var mine := _ticket
	_ticket += 1
	while true:
		while mine != _serving or _urgent > 0:
			await turn_over
		var gap := _gap_left(speaker)
		if gap <= 0.0:
			break
		await get_tree().create_timer(gap, false).timeout
	return true


## This line is over: the next one may go (after its breath).
func _end_turn(turn: int, speaker: String) -> void:
	if turn == Turn.URGENT:
		_urgent = maxi(_urgent - 1, 0)
	else:
		_serving += 1
	_last_speaker = speaker
	_last_end = _clock
	turn_over.emit()


## Seconds still to wait before `speaker` may start.
func _gap_left(speaker: String) -> float:
	var gap := GAP_SAME if speaker == _last_speaker else GAP_CHANGE
	return gap - (_clock - _last_end)


## Someone on this machine is typing at a terminal (TerminalUI.last_typed_msec).
func _typing() -> bool:
	var level := get_parent()
	var term = level.get("terminal_ui") if level else null
	if term == null or not is_instance_valid(term) or not term.visible:
		return false
	return Time.get_ticks_msec() - int(term.get("last_typed_msec")) < TYPING_QUIET * 1000.0


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
