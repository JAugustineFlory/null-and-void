class_name ScriptDocs
extends RefCounted
## Builds the Markdown in docs/script/ from VoiceLines, so the script, the
## recording list and the game never disagree. Write them with:
##   godot --headless -s tools/write_script_docs.gd

const SCRIPT_PATH := "res://docs/script/script.md"
const RECORDING_LIST_PATH := "res://docs/script/recording-list.md"


## The full script in story order, with scene context and acting notes.
static func script_markdown() -> String:
	var md := PackedStringArray()
	md.append("# Null & Void: voice script")
	md.append("")
	md.append("Generated from `scripts/audio/voice_lines.gd`. Edit the lines there, then run `godot --headless -s tools/write_script_docs.gd`.")
	md.append("Each line's file name is in brackets; see [recording-list.md](recording-list.md) for how to record.")
	md.append("")
	md.append("## Cast")
	md.append("")
	for sp in VoiceLines.CHARACTERS:
		var c: Dictionary = VoiceLines.CHARACTERS[sp]
		md.append("**%s** (%s). %s" % [c["name"], sp, c["who"]])
		md.append("")
		md.append("> %s" % c["voice"])
		md.append("")
	var level := -1
	for s in VoiceLines.SCENES:
		if s["level"] != level:
			level = s["level"]
			md.append("## Level %d" % level)
			md.append("")
		md.append("### %s" % s["title"])
		md.append("")
		md.append("*%s*%s" % [s["context"], "" if s["wired"] else " *(Written ahead: not in the game yet.)*"])
		md.append("")
		for id in VoiceLines.ids_in_scene(s["id"]):
			var l: Dictionary = VoiceLines.LINES[id]
			var note: String = (" *(%s)*" % l["note"]) if l["note"] != "" else ""
			md.append("**%s:**%s %s `[%s]`" % [l["speaker"], note, l["text"], id])
			md.append("")
	return "\n".join(md)


## What to record, grouped by character so each one is a single session.
static func recording_list_markdown() -> String:
	var md := PackedStringArray()
	md.append("# Recording list")
	md.append("")
	md.append("Generated from `scripts/audio/voice_lines.gd`. The full script with scene context is in [script.md](script.md).")
	md.append("")
	md.append("## How to record")
	md.append("")
	md.append("1. Record each line as its own file, named exactly as the **File** column plus `.wav` or `.ogg` (for example `l0_greet_1.wav`).")
	md.append("2. Mono, 44.1 or 48 kHz. Leave about a quarter second of silence at the start and end, and keep the loudest part around -3 dB.")
	md.append("3. Record dry: no reverb or radio effect. The game puts WARDEN through a PA speaker sound, and walkie lines will get radio static once the radio is built.")
	md.append("4. Do two or three takes and keep the best one. Lines can be any length; the subtitle stays up as long as the recording plays.")
	md.append("5. Put the files in `audio/voice/` and open the project in Godot once so it imports them. That's it: the game plays a recording whenever one exists and falls back to the timed subtitle when it doesn't.")
	md.append("")
	md.append("WARDEN's subtitles are in capitals because that is how WARDEN prints. Say them at normal volume.")
	md.append("")
	md.append("Lines marked **later** are written for Level 2, which isn't built yet. Record them whenever, or wait until the level is in.")
	md.append("")
	var total := 0
	for sp in VoiceLines.CHARACTERS:
		var c: Dictionary = VoiceLines.CHARACTERS[sp]
		var rows := PackedStringArray()
		for s in VoiceLines.SCENES:
			for id in VoiceLines.ids_in_scene(s["id"]):
				var l: Dictionary = VoiceLines.LINES[id]
				if l["speaker"] != sp:
					continue
				var when: String = "Level %d%s" % [s["level"], "" if s["wired"] else ", later"]
				rows.append("| [ ] | `%s` | %s | %s | %s |" % [id, _cell(l["text"]), _cell(l["note"]), when])
		total += rows.size()
		md.append("## %s (%d lines)" % [c["name"], rows.size()])
		md.append("")
		md.append("> %s" % c["voice"])
		md.append("")
		md.append("| Done | File | Line | Direction | Where |")
		md.append("|---|---|---|---|---|")
		md.append_array(rows)
		md.append("")
	md.insert(2, "%d lines in all." % total)
	md.insert(3, "")
	return "\n".join(md)


static func _cell(text: String) -> String:
	return text.replace("|", "\\|")


static func write_all() -> Error:
	for pair in [[SCRIPT_PATH, script_markdown()], [RECORDING_LIST_PATH, recording_list_markdown()]]:
		var f := FileAccess.open(pair[0], FileAccess.WRITE)
		if f == null:
			return FileAccess.get_open_error()
		f.store_string(pair[1])
		f.close()
	return OK
