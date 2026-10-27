extends SceneTree
## Cuts each block recording in audio/voice/ (several lines read in one take)
## into one file per line, then refreshes docs/script/. Usage:
##   godot --headless -s tools/split_voice_blocks.gd


func _initialize() -> void:
	var log := VoiceSplit.split_all()
	for entry in log:
		print(entry)
	if log.is_empty():
		print("No block recordings to split.")
	ScriptDocs.write_all()
	quit(0)
