class_name ScriptDocs
extends RefCounted
## Builds the Markdown in docs/script/ from VoiceLines, so the script, the
## recording list, the actors' scripts and the game never disagree. Write them with:
##   godot --headless -s tools/write_script_docs.gd

const SCRIPT_PATH := "res://docs/script/script.md"
const RECORDING_LIST_PATH := "res://docs/script/recording-list.md"
## One script per character, for actors who should only see their own lines.
const CHARACTERS_DIR := "res://docs/script/characters/"


## The full script in story order, with scene context and acting notes. Lines
## read in one take are grouped under their recording's file name.
static func script_markdown() -> String:
	var md := PackedStringArray()
	md.append("# Null & Void: voice script")
	md.append("")
	md.append("Generated from `scripts/audio/voice_lines.gd`. Edit the lines there, then run `godot --headless -s tools/write_script_docs.gd`.")
	md.append("Each speech is one recording, named after the speaker; lines under the same name are read in one take. See [recording-list.md](recording-list.md) for how to record.")
	md.append("")
	md.append("## Cast")
	md.append("")
	for sp in VoiceLines.CHARACTERS:
		var c: Dictionary = VoiceLines.CHARACTERS[sp]
		md.append("**%s** (%s). %s" % [c["name"], sp, c["who"]])
		md.append("")
		md.append("> %s" % c["voice"])
		md.append("")
	md.append("## Crew barks")
	md.append("")
	md.append("Each playable crew member's own short lines, played by Co-op. Their shared commentary lines are in the scenes below, as CREW.")
	md.append("")
	for slug in VoiceLines.CREW:
		var m: Dictionary = VoiceLines.CREW[slug]
		md.append("**%s** (`%s`, %s). %s" % [m["name"], slug, m["age"], m["bio"]])
		md.append("")
		for bark in VoiceLines.BARKS:
			md.append("- \"%s\" *(%s)* `[%s]`" % [m["barks"][bark], VoiceLines.BARKS[bark].trim_suffix("."), bark])
		md.append("")
	var level := -1
	for s in VoiceLines.SCENES:
		if s["level"] != level:
			level = s["level"]
			md.append("## Level %d" % level)
			md.append("")
		md.append("### %s" % s["title"])
		md.append("")
		if s.get("setting", "") != "":
			md.append("**%s**" % s["setting"])
			md.append("")
		md.append("*%s*%s" % [s["context"], "" if s["wired"] else " *(Written ahead: not in the game yet.)*"])
		md.append("")
		for b in VoiceLines.blocks(s["id"]):
			var first: Dictionary = VoiceLines.LINES[b["lines"][0]]
			md.append("**%s** `%s.wav`  " % [b["speaker"], b["id"]])
			if first.get("cue", "") != "":
				md.append("*Cue: %s*  " % first["cue"].trim_suffix("."))
			var rows := PackedStringArray()
			for id in b["lines"]:
				var l: Dictionary = VoiceLines.LINES[id]
				var action: String = ("*(%s)* " % l["action"].trim_suffix(".")) if l.get("action", "") != "" else ""
				rows.append("%s\"%s\" *%s*%s" % [action, l["text"], l["note"], "" if b["lines"].size() == 1 else " `[%s]`" % id])
			md.append("  \n".join(rows))
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
	md.append("Returned files go in `audio/voice/<character>/` (for example `audio/voice/rourke/l0_greet_1.wav`). Then run `godot --headless -s tools/split_voice_blocks.gd`: it cuts each `_block` recording at its pauses into one file per line, which is what the game plays, so every line keeps its own subtitle and can be redone on its own. Open the project in Godot once so it imports them. The game plays a recording whenever one exists, keeps the subtitle up for as long as it lasts, and falls back to the timed subtitle when it doesn't. Takes named `_take2` are never played: to use take 2, rename it.")
	md.append("")
	if VoiceLines.SCENES.any(func(sc): return not sc["wired"]):
		md.append("Recordings marked **later** are written ahead for a level that isn't built yet. Record them whenever, or wait until the level is in.")
		md.append("")
	var total := 0
	var total_lines := 0
	for sp in VoiceLines.CHARACTERS:
		var c: Dictionary = VoiceLines.CHARACTERS[sp]
		var rows := PackedStringArray()
		var lines := 0
		for s in VoiceLines.SCENES:
			for b in VoiceLines.blocks(s["id"]):
				if b["speaker"] != sp:
					continue
				lines += b["lines"].size()
				var texts: Array = b["lines"].map(func(id): return "\"%s\"" % VoiceLines.LINES[id]["text"])
				var notes: Array = b["lines"].map(func(id): return VoiceLines.LINES[id]["note"])
				var when: String = "Level %d%s" % [s["level"], "" if s["wired"] else ", later"]
				rows.append("| [%s] | `%s` | %s | %s | %s |" % [_tick(b), b["id"], _cell(" ".join(texts)), _cell(" ".join(notes)), when])
		var copies: int = VoiceLines.CREW.size() if sp == "CREW" else 1
		total += rows.size() * copies
		total_lines += lines * copies
		if sp == "CREW":
			md.append("## %s (%d recordings, %d lines, recorded by each of the %d crew members)" % [c["name"], rows.size(), lines, VoiceLines.CREW.size()])
		else:
			md.append("## %s (%d recordings, %d lines)" % [c["name"], rows.size(), lines])
		md.append("")
		md.append("> %s" % c["voice"])
		md.append("")
		md.append("| Done | File | Lines | Direction | Where |")
		md.append("|---|---|---|---|---|")
		md.append_array(rows)
		md.append("")
	var barks := PackedStringArray()
	for slug in VoiceLines.CREW:
		var m: Dictionary = VoiceLines.CREW[slug]
		for bark in VoiceLines.BARKS:
			var id := VoiceLines.bark_id(bark)
			barks.append("| [%s] | `%s/%s.wav` | %s | %s |" % ["x" if Voice.path_for(id, VoiceLines.crew_dir(slug)) != "" else " ", VoiceLines.crew_dir(slug), id, _cell(m["barks"][bark]), _cell(VoiceLines.BARKS[bark])])
	total += barks.size()
	total_lines += barks.size()
	md.append("## Crew barks (%d lines)" % barks.size())
	md.append("")
	md.append("Each crew member's own short lines, in their own folder.")
	md.append("")
	md.append("| Done | File | Line | When it plays |")
	md.append("|---|---|---|---|")
	md.append_array(barks)
	md.append("")
	md.insert(2, "%d recordings in all, %d lines." % [total, total_lines])
	md.insert(3, "")
	return "\n".join(md)


## Every actor's script, as {path: Markdown}. Lines that give away a twist go in
## a separate "<character>-later.md" for a later session.
static func character_docs() -> Dictionary:
	var docs := {}
	for sp in VoiceLines.CHARACTERS:
		# Every playable crew member records the CREW lines, so each gets their own script.
		var crew: Array = VoiceLines.CREW.keys() if sp == "CREW" else [""]
		for member in crew:
			var slug: String = VoiceLines.crew_dir(member) if member != "" else VoiceLines.CHARACTERS[sp]["slug"]
			for later in [false, true]:
				var md := character_markdown(sp, later, member)
				if md != "":
					docs[CHARACTERS_DIR.path_join(slug + ("-later" if later else "") + ".md")] = md
	return docs


## One character's script, laid out like a play: who you are, how to read it, the
## recording spec, then each scene with where you are and what's going on. Each
## recording has its file name on top, then what you're doing in italics and the
## words in quotes; a speech of several lines is one recording, with the actions
## between its lines. Never shows the team-only character notes or scene plot.
## Returns "" if the character has no lines in this session. `member` is a
## playable crew member's slug, for the CREW lines plus that member's own lines.
static func character_markdown(speaker: String, later: bool = false, member: String = "") -> String:
	var c: Dictionary = VoiceLines.CHARACTERS[speaker]
	var folder: String = VoiceLines.crew_dir(member) if member != "" else c["slug"]
	var body := PackedStringArray()
	var count := 0
	var scene_no := 0
	if member != "" and not later:
		body.append("## Your own lines")
		body.append("")
		body.append("Short lines only you say. The game plays them at lots of different moments, so each one is its own recording and has to work with no lead-in.")
		body.append("")
		for bark in VoiceLines.BARKS:
			count += 1
			var id := VoiceLines.bark_id(bark)
			body.append("**[%s] `%s.wav`**" % ["x" if Voice.path_for(id, folder) != "" else " ", id])
			body.append("")
			body.append("*%s*" % VoiceLines.BARKS[bark])
			body.append("")
			body.append("\"%s\"" % VoiceLines.CREW[member]["barks"][bark])
			body.append("")
	for s in VoiceLines.SCENES:
		if VoiceLines.held_back(s) != later:
			continue
		var mine := VoiceLines.blocks(s["id"]).filter(func(b): return b["speaker"] == speaker)
		if mine.is_empty():
			continue
		scene_no += 1
		body.append("## Scene %d: %s" % [scene_no, s["title"]])
		body.append("")
		if s.get("setting", "") != "":
			body.append("**%s**" % s["setting"])
			body.append("")
		body.append("> %s" % s.get("setup", s.get("moment", "")))
		body.append("")
		var all_ids := VoiceLines.ids_in_scene(s["id"])
		for b in mine:
			count += 1
			body.append("**[%s] `%s.wav`**" % [_tick(b, folder if member != "" else ""), b["id"]])
			body.append("")
			# In a conversation, the line just before yours, if someone else says it.
			var first: String = b["lines"][0]
			if s.get("in_order", false):
				var before := all_ids.slice(0, all_ids.find(first)).filter(func(id): return not id.ends_with("_solo") or first.ends_with("_solo"))
				if not before.is_empty() and VoiceLines.LINES[before[-1]]["speaker"] != speaker:
					var prev: Dictionary = VoiceLines.LINES[before[-1]]
					body.append("> %s: \"%s\"" % [_label(prev["speaker"]), prev["text"]])
					body.append("")
			for id in b["lines"]:
				var l: Dictionary = VoiceLines.LINES[id]
				var direction := PackedStringArray()
				for part in [l.get("cue", ""), l.get("action", ""), l["note"]]:
					if part != "":
						direction.append(part + ("." if part.right(1).is_valid_identifier() or part.right(1).is_valid_int() else ""))
				body.append("*%s*" % " ".join(direction))
				body.append("")
				body.append("\"%s\"" % l["text"])
				body.append("")
	if count == 0:
		return ""
	var md := PackedStringArray()
	var title: String = VoiceLines.CREW[member]["name"] if member != "" else c["name"]
	md.append("# %s" % title)
	md.append("")
	md.append("*Your %sscript for Null & Void: %d recording%s.*" % ["later-session " if later else "", count, "" if count == 1 else "s"])
	md.append("")
	if later:
		md.append("**These lines come later in the story. Please keep them to yourself until you've played that part.**")
		md.append("")
	md.append_array(_who_you_are(c, member))
	md.append("## How to read this script")
	md.append("")
	md.append("- It runs in story order, scene by scene, like a play. Each scene opens with where you are and what's going on.")
	md.append("- Each file name is one recording. Read everything under it in one take, top to bottom.")
	md.append("- What you say is in \"quotes\". *Italics* say what's happening, what you're doing and how to say it: don't read them out.")
	md.append("- When a recording has more than one line, stop for a full second wherever italics come between them. The game cuts the recording at those pauses.")
	md.append("- A boxed quote is someone else's line, just before yours.")
	md.append("")
	md.append("## Recording")
	md.append("")
	md.append_array(_recording_spec())
	md.append("")
	md.append("Send the files back as they are. They go in `audio/voice/%s/` in the game." % folder)
	md.append("")
	md.append_array(body)
	return "\n".join(md).strip_edges() + "\n"


## The character sheet at the top of a script.
static func _who_you_are(c: Dictionary, member: String) -> PackedStringArray:
	var md := PackedStringArray()
	md.append("## Who you are")
	md.append("")
	if member != "":
		var m: Dictionary = VoiceLines.CREW[member]
		md.append("**%s, %s.** %s %s" % [m["name"], m["age"], m["bio"], m.get("background", "")])
		md.append("")
		for field in [["With the crew", m.get("with_crew", "")], ["Tonight", c.get("tonight", "")], ["How you sound", c["voice"]], ["Think of", m.get("inspiration", "")]]:
			if field[1] != "":
				md.append("**%s.** %s" % field)
				md.append("")
		md.append("**Your name.** Players type their own name, so nobody in the game calls you %s, and none of your lines says anyone's name." % m["name"].get_slice(" ", 0))
		md.append("")
		return md
	md.append(c["card"])
	md.append("")
	for field in [["Background", "background"], ["Tonight", "tonight"], ["How you sound", "voice"], ["Think of", "inspiration"]]:
		if c.get(field[1], "") != "":
			md.append("**%s.** %s" % [field[0], c[field[1]]])
			md.append("")
	return md


## A speaker's name as it appears in someone else's script.
static func _label(speaker: String) -> String:
	if speaker == "CREW":
		return "A TEAMMATE"
	if speaker == "PA":
		return "PA (TAPE)"
	return speaker


static func _recording_spec() -> PackedStringArray:
	return PackedStringArray([
		"- **Format:** WAV, mono, 48 kHz, 16- or 24-bit.",
		"- **Room:** somewhere quiet, with soft things around (a closet or a carpeted room works). Keep the mic a hand's width away.",
		"- **Takes:** two of each recording, in separate files: `<file name>.wav` and `<file name>_take2.wav`.",
		"- **Silence:** half a second at the start and end of every file.",
		"- **Pauses:** in a recording with more than one line, a full second of silence between the lines, longer than any pause inside a line.",
		"- **Effects:** none. Record dry; the game adds speakers, radio static and so on.",
		"- **Level:** the loudest part should sit around -3 dB, never clipping.",
	])


## "x" once a recording is in, so the checklists tick themselves: every line of
## it has its own file, or the whole take is waiting to be split.
static func _tick(block: Dictionary, own_dir: String = "") -> String:
	if block["lines"].all(func(id): return Voice.path_for(id, own_dir) != ""):
		return "x"
	var dir: String = own_dir if own_dir != "" else VoiceLines.CHARACTERS[block["speaker"]]["slug"]
	return "x" if FileAccess.file_exists(Voice.folder.path_join(dir).path_join(block["id"] + ".wav")) else " "


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
