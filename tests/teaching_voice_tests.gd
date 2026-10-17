extends RefCounted
## Who teaches: every tip and hint comes from inside the world (plan, "Who teaches:
## SYSOP, Mercer's notes and the world"). [SYSOP] gives terminal tips and every .hint;
## Mercer's notes, stickies and documents teach syntax. WARDEN never says what to type
## or do, and HUD notices are only for controls.
##
## Scans the scripts that put text in front of players and lists every line that
## breaks this. Known breaks print as GAP until the owning thread fixes them, then
## FIXED: promote them to normal checks then. Owned by the Teaching and UX thread.

const SCANNED := ["res://scripts/levels", "res://scripts/world", "res://scripts/ui/terminal_ui.gd"]
## WARDEN's terminal colour: an amber line with no speaker reads as WARDEN.
const WARDEN_AMBER := "#e0b050"

var _check: Callable
var gaps := 0


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
	gap(hint_line.contains("[SYSOP]"), ".hint answers are spoken by [SYSOP], not WARDEN")

	var warden_tips := []
	var nobody_tips := []
	var notice_tips := []
	for l in lines:
		var t: String = l.text
		var speaks := t.contains("print_line(") or t.contains("out.append(")
		var warden := t.contains("WARDEN:") or t.contains(WARDEN_AMBER)
		if speaks and warden and (is_tip(t) or t.contains("explain_error") or is_order(t)):
			warden_tips.append(l.where)
		elif speaks and not warden and is_tip(t) and not t.contains("[SYSOP]") and str(l.where).begins_with("scripts/levels"):
			nobody_tips.append(l.where)
		if (t.contains("hud.notice(") or t.contains("team_notice(")) and is_tip(t) and not is_control(t):
			notice_tips.append(l.where)
	gap(warden_tips.is_empty(), "WARDEN never tells the player what to type or do (%d lines: %s)" % [warden_tips.size(), ", ".join(warden_tips)])
	gap(nobody_tips.is_empty(), "terminal tips have a speaker: [SYSOP], not an unsigned line (%d lines: %s)" % [nobody_tips.size(), ", ".join(nobody_tips)])
	gap(notice_tips.is_empty(), "HUD notices never tell the player what to type (%d: %s)" % [notice_tips.size(), ", ".join(notice_tips)])
	if gaps > 0:
		print("  (%d voice gap%s, see docs/teaching/rubric.md, \"Who teaches\")" % [gaps, "" if gaps == 1 else "s"])


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func gap(ok: bool, name: String) -> void:
	if ok:
		print("  FIXED ", name, "  (promote this to a normal check)")
	else:
		gaps += 1
		print("  GAP   ", name)


## Does this line teach: SQL or a terminal command, or tell the player what to do?
static func is_tip(text: String) -> bool:
	if RegEx.create_from_string("\\b(SELECT|FROM|WHERE|ORDER BY|LIKE|LIMIT|COUNT|DESC)\\b|GET /|\\.(hint|tables|schema)\\b").search(text):
		return true
	return RegEx.create_from_string("(?i)\\b(type|add|leave out|compare|check|look for|look through|read the|reset it)\\b").search(text) != null


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
