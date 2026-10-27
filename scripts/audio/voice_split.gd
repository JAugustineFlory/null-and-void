class_name VoiceSplit
extends RefCounted
## Cuts a block recording (several lines read in one take, with a pause between
## them) into one file per line, so the game can still play each line on its own.
## Actors record `<first line>_block.wav`; run this once the files are in:
##   godot --headless -s tools/split_voice_blocks.gd
## Only uncompressed WAV (16- or 24-bit) is split, as the recording spec asks for.

## Seconds of sound per loudness window.
const WINDOW := 0.02
## A window is part of a pause when it is quieter than this share of the take's
## loudest window.
const QUIET := 0.1


## Splits every block recording under `folder` whose line files aren't there yet,
## then moves the take to `<folder>_takes/`, which Godot neither imports nor
## exports, so the game only carries the per-line files.
## Returns one message per block it found: what it wrote, or why it couldn't.
static func split_all(folder: String = Voice.folder) -> PackedStringArray:
	var log := PackedStringArray()
	var takes := folder.trim_suffix("/") + "_takes"
	for s in VoiceLines.SCENES:
		for b in VoiceLines.blocks(s["id"]):
			if b["lines"].size() < 2:
				continue
			var dirs: Array = VoiceLines.CREW.keys().map(func(m): return VoiceLines.crew_dir(m)) if b["speaker"] == "CREW" else [VoiceLines.CHARACTERS[b["speaker"]]["slug"]]
			for dir in dirs:
				var path: String = folder.path_join(dir).path_join(b["id"] + ".wav")
				if not FileAccess.file_exists(path):
					continue
				var outs: Array = b["lines"].map(func(id): return folder.path_join(dir).path_join(id + ".wav"))
				if outs.all(func(p): return FileAccess.file_exists(p)):
					continue
				var err := split_file(path, outs)
				if err == "":
					err = _put_away(path, takes.path_join(dir))
				log.append("%s: %s" % [path, err if err != "" else "split into %d lines" % outs.size()])
	return log


## Cuts the take at `path` into `outs.size()` files at its longest pauses, halfway
## through each, so every piece keeps some silence at both ends.
## Returns "" on success, or what went wrong.
static func split_file(path: String, outs: Array) -> String:
	var wav := _read(path)
	if wav.has("error"):
		return wav["error"]
	var data: PackedByteArray = wav["data"]
	var frame_bytes: int = wav["channels"] * wav["bits"] / 8
	var frames: int = data.size() / frame_bytes
	var window: int = maxi(1, int(WINDOW * wav["rate"]))
	var levels := PackedFloat32Array()
	var loudest := 0.0
	for start in range(0, frames, window):
		var sum := 0.0
		var count := mini(window, frames - start)
		for f in count:
			var v := _sample(data, (start + f) * frame_bytes, wav["bits"])
			sum += v * v
		var level := sqrt(sum / count)
		levels.append(level)
		loudest = maxf(loudest, level)
	# Pauses between words: runs of quiet windows, not counting the silence at either end.
	var pauses := []
	var run_start := -1
	for i in levels.size():
		var quiet := levels[i] < loudest * QUIET
		if quiet and run_start == -1:
			run_start = i
		elif not quiet and run_start != -1:
			if run_start > 0:
				pauses.append([run_start, i])
			run_start = -1
	var needed := outs.size() - 1
	if loudest == 0.0 or pauses.size() < needed:
		return "found %d pauses but needs %d: leave a clear pause between the lines" % [pauses.size(), needed]
	pauses.sort_custom(func(a, b): return a[1] - a[0] > b[1] - b[0])
	var cuts: Array = pauses.slice(0, needed).map(func(p): return (p[0] + p[1]) / 2 * window)
	cuts.sort()
	cuts.push_front(0)
	cuts.append(frames)
	for i in outs.size():
		var err := _write(outs[i], wav, data.slice(cuts[i] * frame_bytes, cuts[i + 1] * frame_bytes))
		if err != "":
			return err
	return ""


## Moves a split take out of the game's folders, keeping it for re-cuts.
static func _put_away(path: String, dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var ignore := dir.get_base_dir().path_join(".gdignore")
	if not FileAccess.file_exists(ignore):
		FileAccess.open(ignore, FileAccess.WRITE).close()
	var err := DirAccess.rename_absolute(path, dir.path_join(path.get_file()))
	if FileAccess.file_exists(path + ".import"):
		DirAccess.remove_absolute(path + ".import")
	return "" if err == OK else "split, but couldn't move the take: %s" % error_string(err)


## Reads a WAV file's format and sample data. Returns {"error": ...} if it can't.
static func _read(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return {"error": "not a WAV file"}
	var wav := {}
	var at := 12
	while at + 8 <= bytes.size():
		var tag := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		if tag == "fmt ":
			var format := bytes.decode_u16(at + 8)
			wav["channels"] = bytes.decode_u16(at + 10)
			wav["rate"] = bytes.decode_u32(at + 12)
			wav["bits"] = bytes.decode_u16(at + 22)
			# 1 is plain PCM; 0xFFFE is "extensible", which recorders use for 24-bit.
			if format != 1 and format != 0xFFFE:
				return {"error": "only uncompressed WAV can be split"}
		elif tag == "data":
			wav["data"] = bytes.slice(at + 8, at + 8 + size)
		at += 8 + size + size % 2
	if not wav.has("data") or not wav.has("bits"):
		return {"error": "WAV file has no sound data"}
	if wav["bits"] != 16 and wav["bits"] != 24:
		return {"error": "only 16- or 24-bit WAV can be split"}
	return wav


## One sample from the first channel, from -1 to 1.
static func _sample(data: PackedByteArray, at: int, bits: int) -> float:
	if bits == 16:
		return data.decode_s16(at) / 32768.0
	var v := data[at] | (data[at + 1] << 8) | (data[at + 2] << 16)
	if v & 0x800000:
		v -= 0x1000000
	return v / 8388608.0


static func _write(path: String, wav: Dictionary, data: PackedByteArray) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "couldn't write %s: %s" % [path, error_string(FileAccess.get_open_error())]
	var block_align: int = wav["channels"] * wav["bits"] / 8
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(wav["channels"])
	f.store_32(wav["rate"])
	f.store_32(wav["rate"] * block_align)
	f.store_16(block_align)
	f.store_16(wav["bits"])
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
	return ""
