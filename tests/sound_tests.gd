extends RefCounted
## Sound tests: the buses, the Sfx API, the sounds made in code, swapping in a
## recorded file, and the flickering tubes' buzz and crackle.

var t: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("Sound")
	test_buses()
	test_made_sounds()
	test_loops_have_no_seam()
	test_recorded_files_win()
	await test_play()
	await test_flicker_light()
	await test_hum_on_ambience()
	test_volume_sliders()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func test_buses() -> void:
	Sfx.ensure_buses()
	Sfx.ensure_buses()
	for b in Sfx.BUSES:
		var idx := AudioServer.get_bus_index(b)
		check(idx != -1 and AudioServer.get_bus_send(idx) == &"Master", "bus %s exists and feeds Master" % b)
	var count := 0
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == Sfx.SFX:
			count += 1
	check(count == 1, "ensure_buses never adds a bus twice")
	check(Sfx.bus_for("glass") == Sfx.SFX and Sfx.bus_for("fluorescent_buzz") == Sfx.AMBIENCE, "effects go to SFX, steady electrical noise to Ambience")


func test_made_sounds() -> void:
	var total := 0
	for kind in SfxSynth.KINDS:
		var w := SfxSynth.make(kind)
		if w == null:
			check(false, "%s is made in code" % kind)
			continue
		total += w.data.size()
		var peak := _peak(w)
		var clipped := _clipped(w)
		check(peak > 0.05 and clipped < 0.01, "%s is made in code, audible and not clipped (peak %.2f, %.1f%% clipped)" % [kind, peak, clipped * 100.0])
		var loops := w.loop_mode == AudioStreamWAV.LOOP_FORWARD
		check(loops == (kind in SfxSynth.LOOPS), "%s %s" % [kind, "loops" if loops else "plays once"])
		check(Sfx.KINDS.has(kind), "%s has a bus and loudness in Sfx.KINDS" % kind)
	check(SfxSynth.make("no_such_sound") == null, "an unknown sound is null, not noise")
	check(Sfx.stream("glass") == Sfx.stream("glass"), "each sound is made once and kept")
	# Made at load, never shipped: still, keep them small in memory.
	check(total < 1_000_000, "every made sound together is under 1 MB in memory (%d bytes)" % total)


## A loop's last sample runs on into its first: no click each time round.
func test_loops_have_no_seam() -> void:
	for kind in SfxSynth.LOOPS:
		var w := SfxSynth.make(kind)
		var n := w.loop_end
		var first := w.data.decode_s16(0) / 26000.0
		var last := w.data.decode_s16((n - 1) * 2) / 26000.0
		var before := w.data.decode_s16((n - 2) * 2) / 26000.0
		# The jump across the seam is no bigger than an ordinary step near it, with room.
		var step := absf(last - before)
		check(absf(first - last) <= maxf(step * 3.0, 0.08), "%s loops without a click (seam %.3f, step %.3f)" % [kind, absf(first - last), step])


## A file named after a sound replaces the made one; numbered files become variants.
func test_recorded_files_win() -> void:
	var dir := "user://sfx_test/"
	DirAccess.make_dir_recursive_absolute(dir)
	var tone := SfxSynth.make("beep")
	tone.save_to_wav(dir + "thud.wav")
	check(Sfx._recorded("thud", dir) is AudioStreamWAV, "a file named after the sound is used")
	for i in [1, 2, 3]:
		tone.save_to_wav(dir + "step_%d.wav" % i)
	var r := Sfx._recorded("step", dir)
	check(r is AudioStreamRandomizer and r.streams_count == 3, "step_1..step_3 become one sound picked at random")
	check(Sfx._recorded("nothing", dir) == null, "with no file, nothing is recorded")
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	DirAccess.remove_absolute(dir)
	# The shipped folder has none of the made sounds yet: they all come from code.
	Sfx.clear_cache()
	check(Sfx.stream("glass") is AudioStreamWAV and Sfx.stream("glass").mix_rate == SfxSynth.RATE, "with no recording, glass is made in code")


func test_play() -> void:
	var room := Node3D.new()
	t.root.add_child(room)
	var p := Sfx.play(room, "clunk", Vector3(1, 2, 3))
	check(p != null and p.playing and p.bus == Sfx.SFX and p.position == Vector3(1, 2, 3), "Sfx.play plays where it's told, on SFX")
	check(room.get_meta("sounds_played")[0] == {"kind": "clunk", "pos": Vector3(1, 2, 3)}, "what played is noted for the tests")
	for i in 40:
		Sfx.play(room, "click", Vector3.ZERO)
	check(room.get_meta("sounds_played").size() <= 32, "the note keeps only the last few, so a busy sound doesn't pile up")
	var flat := Sfx.play_flat(room, "beep")
	check(flat != null and flat.playing, "Sfx.play_flat plays with no position")
	var hum := Sfx.loop(room, "server_hum", Vector3.ZERO)
	check(hum.playing and hum.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Sfx.loop keeps playing")
	var off := Node3D.new()
	check(Sfx.play(off, "glass", Vector3.ZERO) == null, "nothing plays outside the tree")
	off.free()
	# Level2FX.sound still works, through Sfx.
	Level2FX.sound(room, Vector3.ONE, "tap")
	check(room.get_meta("sounds_played").back().kind == "tap", "Level2FX.sound plays through Sfx")
	for i in 60:
		if not is_instance_valid(p):
			break
		await t.create_timer(0.05).timeout
	check(not is_instance_valid(p), "a played sound frees itself when it ends")
	room.queue_free()
	await t.process_frame


func test_flicker_light() -> void:
	var room := Node3D.new()
	t.root.add_child(room)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 3, 0)
	room.add_child(l)
	var f := FlickerLight.attach(l, 1.0)  # flickers every time it can
	await t.process_frame
	var buzz: AudioStreamPlayer3D = l.get_node("Loop_fluorescent_buzz")
	check(buzz != null and buzz.playing and buzz.bus == Sfx.AMBIENCE and buzz.global_position == l.global_position,
		"a flickering tube buzzes, at the tube, on Ambience")
	for i in 30:
		await t.process_frame
	check(f.crackles > 0, "it crackles as it flickers (%d)" % f.crackles)
	# Switched off by the lights table: quiet.
	l.visible = false
	await t.process_frame
	var crackled := f.crackles
	for i in 20:
		await t.process_frame
	check(not buzz.playing and f.crackles == crackled, "switched off, it neither buzzes nor crackles")
	l.visible = true
	await t.process_frame
	check(buzz.playing, "switched back on, it buzzes again")
	# Mended: the FlickerLight goes, and its buzz with it.
	f.queue_free()
	await t.process_frame
	await t.process_frame
	check(not is_instance_valid(buzz), "a mended tube goes quiet")
	room.queue_free()
	await t.process_frame


func test_hum_on_ambience() -> void:
	var room := Node3D.new()
	t.root.add_child(room)
	var h := Hum.create(room, AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2)))
	h.listener = room
	await t.process_frame
	check(h._player.bus == Sfx.AMBIENCE, "the Hum plays on Ambience")
	room.queue_free()
	await t.process_frame


func test_volume_sliders() -> void:
	var box := SfxVolume.sliders()
	var names := []
	for c in box.get_children():
		if c is HSlider:
			names.append(str(c.name))
	check(names == ["Master", "Music", "SFX", "Ambience", "Voice"], "the pause menu has a slider for everything, music, effects, ambience and voices (%s)" % [names])
	check(is_equal_approx(box.get_node("SFX").value, Sfx.volume(Sfx.SFX)), "each slider starts at its bus's volume")
	box.free()


func _peak(w: AudioStreamWAV) -> float:
	var peak := 0
	for i in range(0, w.data.size(), 2):
		peak = maxi(peak, absi(w.data.decode_s16(i)))
	return peak / 32767.0


## The share of samples pinned at SfxSynth's ceiling.
func _clipped(w: AudioStreamWAV) -> float:
	var n := 0
	for i in range(0, w.data.size(), 2):
		if absi(w.data.decode_s16(i)) >= 26000:
			n += 1
	return float(n) / (w.data.size() / 2)
