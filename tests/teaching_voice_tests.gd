extends RefCounted
## Who teaches: every tip and hint comes from inside the world (plan, "Who teaches:
## SYSOP, Mercer's notes and the world"). [SYSOP] gives terminal tips and every .hint;
## Mercer's notes, stickies and documents teach syntax. WARDEN never says what to type
## or do, and HUD notices are only for controls. Objectives are handwritten notebook
## to-dos (Augustine, 2026-10-17) and never name a puzzle's answer.
##
## Scans the scripts that put text in front of players, and WARDEN's spoken lines,
## and fails on every line that breaks this. Owned by the Teaching and UX thread.

const SCANNED := ["res://scripts/levels", "res://scripts/world", "res://scripts/ui/terminal_ui.gd"]
## WARDEN's terminal colour: an amber line with no speaker reads as WARDEN.
const WARDEN_AMBER := "#e0b050"
## Per-run answers in the level scripts: a to-do or objective built from one gives it away.
const ANSWER_VARS := "\\b(answer|data\\.(pin|breaker|name|answer))\\b"

var _check: Callable


func run(_tree: SceneTree, check: Callable) -> void:
	_check = check
	print("Teaching: who teaches")
	var lines := _source_lines()
	check(lines.size() > 100, "the voice scan reads the level and terminal scripts (%d lines)" % lines.size())

	var hint_line := ""
	for l in lines:
		if l.text.contains("next_hint()") and l.text.contains("print_line"):
			hint_line = l.text
	check(hint_line != "", "the scan finds where .hint answers are printed")
	check(is_sysop(hint_line), ".hint answers are spoken by [SYSOP], not WARDEN")

	var warden_tips := []
	var nobody_tips := []
	var notice_tips := []
	var spoilers := []
	var answer_var := RegEx.create_from_string(ANSWER_VARS)
	var last_sysop := ""  # file of the last line SYSOP said, so its indented lines count too
	for l in lines:
		var t: String = l.text
		var file: String = l.where.get_slice(":", 0)
		var speaks := t.contains("print_line(") or t.contains("out.append(")
		var warden := t.contains("WARDEN:") or t.contains(WARDEN_AMBER)
		if is_sysop(t):
			last_sysop = file
		elif speaks and not is_continuation(t):
			last_sysop = ""
		var sysop_says := is_sysop(t) or (is_continuation(t) and last_sysop == file)
		if speaks and warden and (is_tip(t) or t.contains("explain_error") or is_order(t)):
			warden_tips.append(l.where)
		elif speaks and not warden and is_tip(t) and not sysop_says and not is_readout(t) and file.begins_with("scripts/levels"):
			nobody_tips.append(l.where)
		if (t.contains("hud.notice(") or t.contains("team_notice(")) and is_tip(t) and not is_control(t):
			notice_tips.append(l.where)
		if (t.contains("set_objective(") or t.contains("todo(")) and t.contains("%") and answer_var.search(t.substr(t.rfind("%"))):
			spoilers.append(l.where)
	check(warden_tips.is_empty(), "WARDEN never tells the player what to type or do (%d lines: %s)" % [warden_tips.size(), ", ".join(warden_tips)])
	check(nobody_tips.is_empty(), "terminal tips have a speaker: [SYSOP], not an unsigned line (%d lines: %s)" % [nobody_tips.size(), ", ".join(nobody_tips)])
	check(notice_tips.is_empty(), "HUD notices never tell the player what to type (%d: %s)" % [notice_tips.size(), ", ".join(notice_tips)])
	check(spoilers.is_empty(), "to-dos and objectives never name a puzzle's answer (%d: %s)" % [spoilers.size(), ", ".join(spoilers)])

	# WARDEN's spoken lines (subtitled) follow the same rule as its terminal lines.
	var voiced := []
	var lines_db: Dictionary = load("res://scripts/audio/voice_lines.gd").LINES
	for id in lines_db:
		var v: Dictionary = lines_db[id]
		if v.get("speaker", "") == "WARDEN" and is_spoken_tip(v.text):
			voiced.append(id)
	check(lines_db.size() > 20, "the voice scan reads the spoken lines (%d)" % lines_db.size())
	check(voiced.is_empty(), "WARDEN's spoken lines never say what to type or do (%d: %s)" % [voiced.size(), ", ".join(voiced)])


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


## An indented line under the one before it (an example query, a column note): it
## belongs to whoever said that line.
static func is_continuation(text: String) -> bool:
	return RegEx.create_from_string("(print_line|append)\\(\\[?\"   ").search(text) != null


## A device's own readout, named in capitals ("MOTION SENSOR: MOVEMENT 6 m FROM
## YOU"), so words like FROM in it aren't SQL.
static func is_readout(text: String) -> bool:
	var said := RegEx.create_from_string("\\[[^\\]]*\\]").sub(text.get_slice("\"", 1), "", true)
	return RegEx.create_from_string("^>? ?[A-Z][A-Z0-9 -]+: [A-Z]").search(said) != null


## A line SYSOP says: written out, or through TerminalUI.sysop().
static func is_sysop(text: String) -> bool:
	return text.contains("[SYSOP]") or text.contains("sysop(")


## Does this line teach: SQL or a terminal command, or tell the player what to do?
static func is_tip(text: String) -> bool:
	if RegEx.create_from_string("\\b(SELECT|FROM|WHERE|ORDER BY|LIKE|LIMIT|COUNT|DESC)\\b|GET /|\\.(hint|tables|schema)\\b").search(text):
		return true
	return RegEx.create_from_string("(?i)\\b(type|add|leave out|compare|check|look for|look through|read the|reset it)\\b").search(text) != null


## The same for a line spoken in WARDEN's capitals, where WHERE and FROM are just
## English ("PLEASE WAIT WHERE YOU ARE").
static func is_spoken_tip(text: String) -> bool:
	if RegEx.create_from_string("\\b(SELECT|ORDER BY|LIMIT|COUNT|DESC)\\b|LIKE '|GET /|\\.(HINT|TABLES|SCHEMA|hint|tables|schema)\\b").search(text):
		return true
	return RegEx.create_from_string("(?i)\\b(type|add|leave out|compare|look for|look through|read the|reset it)\\b").search(text) != null


## WARDEN giving an order the player should follow ("a manual reset at the rack").
static func is_order(text: String) -> bool:
	return RegEx.create_from_string("(?i)\\b(reset|find|go to|enter|will clear it)\\b").search(text) != null


## Control prompts are the one thing HUD notices may say.
static func is_control(text: String) -> bool:
	return RegEx.create_from_string("(?i)\\b(hold|press) (ctrl|shift|space|tab|e|x)\\b|notebook \\(tab\\)").search(text) != null


func _source_lines() -> Array:
	var out := []
	for path in SCANNED:
		for file in _files(path):
			var text := FileAccess.get_file_as_string(file)
			var n := 0
			for line in text.split("\n"):
				n += 1
				var code := line.strip_edges()
				if code.begins_with("#"):
					continue
				out.append({"where": "%s:%d" % [file.trim_prefix("res://"), n], "text": code})
	return out


func _files(path: String) -> Array:
	if path.ends_with(".gd"):
		return [path]
	var out := []
	for f in DirAccess.get_files_at(path):
		if f.ends_with(".gd"):
			out.append(path + "/" + f)
	return out
