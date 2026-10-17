class_name ScriptDocs
extends RefCounted
## Builds the Markdown in docs/script/ from VoiceLines, so the script, the
## recording list, the actors' scripts and the game never disagree. Write them with:
##   godot --headless -s tools/write_script_docs.gd

const SCRIPT_PATH := "res://docs/script/script.md"
const RECORDING_LIST_PATH := "res://docs/script/recording-list.md"
## One script per character, for actors who should only see their own lines.
const CHARACTERS_DIR := "res://docs/script/characters/"


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
	md.append("Each actor gets only their own character's script from [characters/](characters/), which has the same recording spec:")
	md.append("")
	md.append_array(_recording_spec())
	md.append("")
	md.append("Returned files go in `audio/voice/<character>/` (for example `audio/voice/rourke/l0_greet_1.wav`); open the project in Godot once so it imports them. The game plays a recording whenever one exists, keeps the subtitle up for as long as it lasts, and falls back to the timed subtitle when it doesn't. Only `<line_id>.wav` is played: to use take 2, rename it.")
	md.append("")
	if VoiceLines.SCENES.any(func(sc): return not sc["wired"]):
		md.append("Lines marked **later** are written ahead for a level that isn't built yet. Record them whenever, or wait until the level is in.")
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
				rows.append("| [%s] | `%s` | %s | %s | %s |" % [_tick(id), id, _cell(l["text"]), _cell(l["note"]), when])
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


## Every actor's script, as {path: Markdown}. Lines that give away a twist go in
## a separate "<character>-later.md" for a later session.
static func character_docs() -> Dictionary:
	var docs := {}
	for sp in VoiceLines.CHARACTERS:
		var slug: String = VoiceLines.CHARACTERS[sp]["slug"]
		for later in [false, true]:
			var md := character_markdown(sp, later)
			if md != "":
				docs[CHARACTERS_DIR.path_join(slug + ("-later" if later else "") + ".md")] = md
	return docs


## One character's script: their card, the recording spec, and their lines grouped
## by moment. Never mentions other characters' lines or the scene's plot.
## Returns "" if the character has no lines in this session.
static func character_markdown(speaker: String, later: bool = false) -> String:
	var c: Dictionary = VoiceLines.CHARACTERS[speaker]
	var body := PackedStringArray()
	var count := 0
	var moment_no := 0
	for s in VoiceLines.SCENES:
		if VoiceLines.held_back(s) != later:
			continue
		var ids := VoiceLines.ids_in_scene(s["id"]).filter(func(id): return VoiceLines.LINES[id]["speaker"] == speaker)
		if ids.is_empty():
			continue
		moment_no += 1
		body.append("### %d. %s" % [moment_no, s.get("moment", "")])
		body.append("")
		for id in ids:
			var l: Dictionary = VoiceLines.LINES[id]
			count += 1
			body.append("- [%s] `%s.wav`  " % [_tick(id), id])
			body.append("  \"%s\"  " % l["text"])
			body.append("  *%s*" % l["note"])
		body.append("")
	if count == 0:
		return ""
	var md := PackedStringArray()
	md.append("# %s: %s" % [c["name"], "later session" if later else "your lines"])
	md.append("")
	md.append("%s" % c["card"])
	md.append("")
	md.append("**How they sound:** %s" % c["voice"])
	md.append("")
	if later:
		md.append("These lines come later in the story. Please keep them to yourself until after you've played that part.")
		md.append("")
	md.append("## Recording")
	md.append("")
	md.append_array(_recording_spec())
	md.append("")
	md.append("Send the files back as they are. They go in `audio/voice/%s/` in the game." % c["slug"])
	md.append("")
	md.append("## Your lines (%d)" % count)
	md.append("")
	md.append("Each line has the file name to save it as, the line, and a note on how to play it. Don't worry about timing: you'll hear it in the game and we can redo any line after the playtest.")
	md.append("")
	md.append_array(body)
	return "\n".join(md).strip_edges() + "\n"


static func _recording_spec() -> PackedStringArray:
	return PackedStringArray([
		"- **Format:** WAV, mono, 48 kHz.",
		"- **Room:** somewhere quiet, with soft things around (a closet or a carpeted room works). Keep the mic a hand's width away.",
		"- **Takes:** two per line, in separate files: `<line_id>.wav` and `<line_id>_take2.wav`.",
		"- **Silence:** half a second at the start and end of every file.",
		"- **Effects:** none. Record dry; the game adds speakers, radio static and so on.",
		"- **Level:** the loudest part should sit around -3 dB, never clipping.",
	])


## "x" once a line has a recording, so the checklists tick themselves.
static func _tick(id: String) -> String:
	return "x" if Voice.path_for(id) != "" else " "


static func _cell(text: String) -> String:
	return text.replace("|", "\\|")


static func write_all() -> Error:
	DirAccess.make_dir_recursive_absolute(CHARACTERS_DIR)
	var docs := character_docs()
	# Drop scripts for characters or sessions that no longer have lines.
	for f in DirAccess.get_files_at(CHARACTERS_DIR):
		if f.ends_with(".md") and not docs.has(CHARACTERS_DIR.path_join(f)):
			DirAccess.remove_absolute(CHARACTERS_DIR.path_join(f))
	docs[SCRIPT_PATH] = script_markdown()
	docs[RECORDING_LIST_PATH] = recording_list_markdown()
	for path in docs:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return FileAccess.get_open_error()
		f.store_string(docs[path])
		f.close()
	return OK
