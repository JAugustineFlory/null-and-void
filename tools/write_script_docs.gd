extends SceneTree
## Regenerates docs/script/ from scripts/audio/voice_lines.gd and lists which
## lines still need recording. Usage:
##   godot --headless -s tools/write_script_docs.gd


func _initialize() -> void:
	var err := ScriptDocs.write_all()
	if err != OK:
		printerr("Couldn't write docs/script/: ", error_string(err))
		quit(1)
		return
	var missing := PackedStringArray()
	for id in VoiceLines.LINES:
		if Voice.path_for(id) == "":
			missing.append(id)
	print("Wrote docs/script/script.md and docs/script/recording-list.md")
	print("%d of %d lines recorded." % [VoiceLines.LINES.size() - missing.size(), VoiceLines.LINES.size()])
	if not missing.is_empty():
		print("Still to record: ", ", ".join(missing))
	quit(0)
