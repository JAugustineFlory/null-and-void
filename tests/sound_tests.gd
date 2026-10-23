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
	await test_terminal_sounds()
	await test_door_sounds()
	test_surfaces()
	await test_footsteps()
	await test_landing()
	await test_teammate_steps()
	test_recorded_budget_and_credits()
	test_music_layers()
	await test_music_moods()
	test_npc_danger()
	await test_music_director()
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
	# Stepped by hand: headless frames can be shorter than a flicker's shortest beat.
	for i in 20:
		f._process(0.2)
	check(f.crackles > 0, "it crackles as it flickers (%d)" % f.crackles)
	# Switched off by the lights table: quiet.
	l.visible = false
	await t.process_frame
	var crackled := f.crackles
	for i in 20:
		f._process(0.2)
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


func test_terminal_sounds() -> void:
	var room := Node3D.new()
	t.root.add_child(room)
	var ui := TerminalUI.new()
	room.add_child(ui)
	var term := Terminal.spawn(room, Vector3(2, 0.8, 0), 0, "TEST", FacilityDB.new(), ui)
	ui.terminal = term
	await t.process_frame
	var whine: AudioStreamPlayer3D = term.get_node("Loop_crt_whine")
	check(whine.playing and whine.bus == Sfx.AMBIENCE and whine.max_distance > 0.0 and whine.max_distance <= 6.0,
		"a terminal's tube whines, only heard up close (%.1f m)" % whine.max_distance)
	ui.run("SELECT 1 AS one;")
	var played: Array = term.get_meta("sounds_played", [])
	check(not played.is_empty() and played.back().kind == "beep" and played.back().pos == term.focus_point.position,
		"a query that works beeps, at the screen")
	ui.run("SELEC 1;")
	check(term.get_meta("sounds_played").back().kind == "error", "a query that fails buzzes")
	ui.visible = true
	ui._input.insert_text_at_caret("S")
	await t.process_frame  # TextEdit says it changed a frame later
	check(term.get_meta("sounds_played").back().kind == "key", "typing clicks the keys")
	room.queue_free()
	await t.process_frame


func test_door_sounds() -> void:
	var room := Node3D.new()
	t.root.add_child(room)
	var slid := Door.create(room, "TEST-SLID", Vector3(4, 1.2, 0), Vector3(1.6, 2.4, 0.2))
	var hinged := Door.create(room, "TEST-HINGED", Vector3(8, 1.2, 0), Vector3(0.1, 2.4, 0.9)).make_hinged(Vector3(0, 0, -0.45))
	await t.process_frame
	var kinds := func(): return room.get_meta("sounds_played", []).map(func(x): return x.kind)
	slid.set_open(true)
	check(kinds.call() == ["door_motor"] and room.get_meta("sounds_played")[0].pos == Vector3(4, 1.2, 0), "a sliding door's motor runs as it opens, at the door")
	slid.set_open(false)
	check(kinds.call().back() == "clunk", "and it thuds shut")
	hinged.set_open(true)
	check(kinds.call().back() == "click", "a hinged door's latch clicks")
	var before: int = kinds.call().size()
	slid.set_open(true, true)
	slid.set_open(true)
	check(kinds.call().size() == before, "a door set at once (loading in) or already open makes no sound")
	room.queue_free()
	await t.process_frame


func test_surfaces() -> void:
	var b := StaticBody3D.new()
	b.name = "VentFloor"
	check(SfxSteps.surface_of(b) == "vent", "a duct's floor sounds like a duct")
	b.name = "Floor"
	check(SfxSteps.surface_of(b) == "concrete", "an ordinary floor is concrete")
	Sfx.mark_surface(b, "carpet")
	check(SfxSteps.surface_of(b) == "carpet", "a level can say a floor is carpet")
	b.free()
	for surface in ["concrete", "carpet", "wood", "metal", "vent"]:
		var st := Sfx.stream("step_" + surface)
		check(st is AudioStreamRandomizer and st.streams_count >= 3, "steps on %s are recorded, with variants" % surface)


## A floor and a player who walks north on it, `how`: "walk", "sprint" or "crouch".
func _walker(how: String, surface := "") -> Array:
	var a := Node3D.new()
	t.root.add_child(a)
	var floor_body := Greybox.box(a, Vector3(0, -0.1, 0), Vector3(40, 0.2, 40), Color.GRAY, "Floor")
	if surface != "":
		Sfx.mark_surface(floor_body, surface)
	var p := Player.new()
	p.local_control = false
	p.position = Vector3(0, 0.1, 10)
	a.add_child(p)
	var noise := []
	p.noise_made.connect(func(_at, l): noise.append(l))
	for i in 5:
		await t.physics_frame
	p.controls.move = Vector2(0, -1)
	p.controls.sprint = how == "sprint"
	p.controls.crouch = how == "crouch"
	for i in 120:
		await t.physics_frame
	var steps: Array = p.get_node("Steps").heard.filter(func(h): return h.kind.begins_with("step_"))
	a.queue_free()
	await t.process_frame
	return [steps, noise]


func test_footsteps() -> void:
	var walk: Array = await _walker("walk")
	var steps: Array = walk[0]
	check(steps.size() >= 2 and steps.all(func(h): return h.kind == "step_concrete" and h.db == SfxSteps.WALK_DB),
		"walking on concrete, you hear soft concrete steps (%d)" % steps.size())
	var sprint: Array = await _walker("sprint")
	check(sprint[0].size() > steps.size() and sprint[0].all(func(h): return h.db == SfxSteps.SPRINT_DB),
		"sprinting, the steps come faster and louder (%d)" % sprint[0].size())
	var crouch: Array = await _walker("crouch")
	check(not crouch[0].is_empty() and crouch[0].all(func(h): return h.db == SfxSteps.CROUCH_DB) and crouch[1].is_empty(),
		"crouching, your steps are barely there, and the Shredder hears nothing either")
	check(sprint[1].size() > 0 and sprint[1].all(func(l): return l >= 0.5), "sprinting is loud to the Shredder too")
	var carpet: Array = await _walker("walk", "carpet")
	check(not carpet[0].is_empty() and carpet[0].all(func(h): return h.kind == "step_carpet"), "on carpet, carpet steps")


func test_landing() -> void:
	var a := Node3D.new()
	t.root.add_child(a)
	Greybox.box(a, Vector3(0, -0.1, 0), Vector3(40, 0.2, 40), Color.GRAY, "Floor")
	var p := Player.new()
	p.local_control = false
	p.position = Vector3(0, 0.1, 0)
	a.add_child(p)
	for i in 10:
		await t.physics_frame
	var steps: SfxSteps = p.get_node("Steps")
	check(steps.heard.is_empty(), "standing still makes no sound")
	p.global_position = Vector3(0, 2.0, 0)
	for i in 90:
		await t.physics_frame
	check(steps.heard.any(func(h): return h.kind == "land"), "dropping from 2 m, you land with a thump")
	p.global_position = Vector3(0, 9.0, 0)
	for i in 120:
		await t.physics_frame
	check(steps.heard.back().kind == "land_hard", "from 9 m, a hard landing (as loud to the Shredder)")
	a.queue_free()
	await t.process_frame


func test_teammate_steps() -> void:
	var a := Node3D.new()
	t.root.add_child(a)
	Greybox.box(a, Vector3(0, -0.1, 0), Vector3(40, 0.2, 40), Color.GRAY, "Floor")
	var mate := PlayerPuppet.create(a, 7, "Mate", {}, Transform3D(Basis(), Vector3(0, 0, 10)))
	var steps: SfxSteps = mate.get_node("Steps")
	for i in 120:
		mate.apply_state(Vector3(0, 0, 10 - i * 0.06), 0.0, 0.0, PlayerPuppet.STAND_HEIGHT, false)
		await t.physics_frame
	check(steps.heard.size() >= 2 and steps.heard.all(func(h): return h.kind == "step_concrete"),
		"a teammate walking past makes steps on your machine too (%d)" % steps.heard.size())
	var n := steps.heard.size()
	mate.set_sitting(PlayerPuppet.Sit.CHAIR)
	for i in 60:
		mate.apply_state(Vector3(i * 0.06, 0, 3), 0.0, 0.0, PlayerPuppet.STAND_HEIGHT, false, PlayerPuppet.Sit.CHAIR)
		await t.physics_frame
	check(steps.heard.size() == n, "carried along sitting down (in the van), no steps")
	mate.set_sitting(PlayerPuppet.Sit.NONE)
	var desk := Node3D.new()
	a.add_child(desk)
	mate.sit_at(desk, 0)
	for i in 60:
		mate.apply_state(Vector3(3 - i * 0.06, 0, 3), 0.0, 0.0, PlayerPuppet.STAND_HEIGHT, false)
		await t.physics_frame
	check(steps.heard.size() == n, "sliding into place at a terminal, no steps")
	mate.at_terminal = null
	mate.set_downed(true)
	for i in 60:
		mate.apply_state(Vector3(-0.6 + i * 0.06, 0, 3), 0.0, 0.0, PlayerPuppet.STAND_HEIGHT, false)
		await t.physics_frame
	check(steps.heard.size() == n, "dragged while down, no steps")
	mate.set_downed(false)
	# Teleports and snaps: one big jump a frame, again and again, never a step.
	for i in 40:
		mate.apply_state(Vector3(0 if i % 2 == 0 else 6, 0, -6), 0.0, 0.0, PlayerPuppet.STAND_HEIGHT, false)
		await t.physics_frame
	check(steps.heard.size() == n, "snapping to a new place (over 4 m), no steps")
	a.queue_free()
	await t.process_frame


## Recorded sounds stay small, mono-ish and credited.
func test_recorded_budget_and_credits() -> void:
	var total := 0
	var credits := FileAccess.get_file_as_string("res://audio/sfx/CREDITS.md")
	var uncredited := []
	for dir in ["res://audio/sfx/", "res://audio/music/"]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			if not (f.ends_with(".ogg") or f.ends_with(".wav")):
				continue
			total += FileAccess.get_file_as_bytes(dir + f).size()
			var kind := f.get_basename()
			var digits := kind.get_slice("_", kind.get_slice_count("_") - 1)
			if digits.is_valid_int():
				kind = kind.trim_suffix("_" + digits)
			if not credits.contains("`%s" % kind):
				uncredited.append(f)
	check(total < 5_000_000, "recorded effects and music stay under 5 MB (%d KB)" % (total / 1024))
	check(uncredited.is_empty(), "every recorded sound is in audio/sfx/CREDITS.md (missing: %s)" % [uncredited])


func test_music_layers() -> void:
	var ms := 0
	for layer in MusicSynth.LAYERS:
		var start := Time.get_ticks_msec()
		var w := MusicSynth.make(layer)
		ms += Time.get_ticks_msec() - start
		check(w != null and w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.loop_end == MusicSynth.samples(),
			"music layer %s loops, the same length as the rest" % layer)
		var peak := _peak(w, 7)
		check(peak > 0.1 and _clipped(w, 7) < 0.001, "music layer %s is audible and not clipped (peak %.2f)" % [layer, peak])
		var first := w.data.decode_s16(0) / 26000.0
		var last := w.data.decode_s16((w.loop_end - 1) * 2) / 26000.0
		check(absf(first - last) < 0.05, "music layer %s loops without a click (seam %.3f)" % [layer, absf(first - last)])
	print("    (music made in %d ms)" % ms)
	check(MusicSynth.make("kazoo") == null, "there's no layer that isn't listed")
	for m in Music.MOODS:
		for layer in Music.MOODS[m]:
			check(layer in MusicSynth.LAYERS, "mood %s only uses real layers (%s)" % [m, layer])


func test_music_moods() -> void:
	var m := Music.of(t.root)
	check(Music.of(t.root) == m, "there's only ever one Music")
	m.set_mood("calm")
	check(not m.layers.values().any(func(p): return p.playing), "before its layers are made, nothing plays")
	for i in 200:
		if m.ready_to_play:
			break
		await t.create_timer(0.05).timeout
	check(m.ready_to_play, "the layers are made in the background")
	check(m.layers.size() == MusicSynth.LAYERS.size() and m.layers.values().all(func(p): return p.bus == Sfx.MUSIC),
		"every layer plays on the Music bus")
	m.set_mood("calm")
	check(m.layers.values().all(func(p): return p.playing), "every layer starts together, so they stay in time")
	m._process(Music.FADE_IN)
	check(is_equal_approx(m.level["drone"], 0.6) and m.level["heart"] == 0.0, "calm: the drone and pad, nothing chasing")
	m.set_mood("chase")
	m._process(0.5)
	check(m.level["heart"] > 0.0 and m.level["heart"] < 1.0, "danger fades in over a moment, not all at once")
	m._process(Music.FADE_IN)
	check(m.level["tension"] == 1.0 and m.level["heart"] == 1.0, "chase: everything")
	m.set_mood("checkpoint")
	m._process(Music.FADE_IN)
	check(m.level["tension"] > 0.0 and m.level["relief"] > 0.7, "at a checkpoint the relief comes in quickly while the chase lingers")
	m._process(Music.FADE_OUT)
	check(m.level["tension"] == 0.0, "then the chase is gone")
	m.set_mood("silent")
	m._process(Music.FADE_OUT)
	m._process(0.1)
	check(m.layers.values().all(func(p): return not p.playing), "silent: it stops")
	m.queue_free()
	await t.process_frame


## Stands in for the World: its current wing, and its checkpoint signal.
class FakeWorld extends Node:
	signal checkpoint_reached(wing_id: String)
	var current: Node
	var home: Node


func test_npc_danger() -> void:
	var w := Watcher.new()
	check(MusicDirector.danger(w) == 0, "a Watcher not yet let loose is no danger")
	w.active = true
	w.seen = true
	check(MusicDirector.danger(w) == 1, "loose but watched: hunted")
	w.seen = false
	check(MusicDirector.danger(w) == 2, "loose and unwatched, it's coming: chase")
	w.free()
	var s := Shredder.new()
	check(MusicDirector.danger(s) == 0, "a sleeping Shredder is no danger")
	s.active = true
	s.state = "roaming"
	check(MusicDirector.danger(s) == 1, "an awake Shredder roaming: hunted")
	s.state = "investigating"
	check(MusicDirector.danger(s) == 2, "a Shredder walking to a sound it heard: chase")
	s.free()
	var c := Custodian.new()
	c.state = "bay"
	check(MusicDirector.danger(c) == 0, "the Custodian in its bay is no danger")
	c.state = "hunting"
	check(MusicDirector.danger(c) == 2, "the Custodian hunting: chase")
	c.free()
	var m := Mimic.new()
	m.state = "standing"
	check(MusicDirector.danger(m) == 1, "a Mimic standing where you can find it: hunted")
	m.state = "gone"
	check(MusicDirector.danger(m) == 0, "a Mimic that's gone: nothing")
	m.free()
	check(MusicDirector.danger(Node.new()) == 0, "anything else is no danger")


func test_music_director() -> void:
	var game := t.root.get_node("Game")
	var fate: String = game.rourke_fate
	var world := FakeWorld.new()
	t.root.add_child(world)
	var floor_wing := Node3D.new()
	world.add_child(floor_wing)
	world.current = floor_wing
	var d := MusicDirector.follow(world)
	check(MusicDirector.follow(world) == d, "one director per game")
	game.rourke_fate = "unknown"
	check(d.pick() == "calm", "with Rourke still escorting, calm")
	game.rourke_fate = "tied"
	check(d.pick() == "uneasy", "once the escort's gone, uneasy")
	var s := Shredder.new()
	floor_wing.add_child(s)
	s.set_process(false)
	s.set_physics_process(false)
	s.active = true
	s.state = "roaming"
	check(d.pick() == "hunted", "a threat loose on this floor: hunted")
	s.state = "grabbing"
	check(d.pick() == "chase", "it has someone: chase")
	s.active = false
	world.checkpoint_reached.emit("level_3")
	check(d.pick() == "checkpoint", "a floor done: relief")
	d._process(MusicDirector.CHECKPOINT_HOLD + 0.1)
	check(d.pick() == "uneasy" and d.get_parent().mood == "uneasy", "after the ride up, back to the floor's own mood, and Music follows")
	# Another floor's threat isn't this floor's.
	var other := Node3D.new()
	world.add_child(other)
	s.reparent(other)
	s.active = true
	check(d.pick() == "uneasy", "a threat on another floor doesn't count")
	world.home = Node3D.new()
	world.current = world.home
	check(d.pick() == "checkpoint", "at home base, relief")
	world.home.free()
	world.queue_free()
	await t.process_frame
	check(d.pick() == "silent", "with no world, silence")
	game.rourke_fate = fate
	d.get_parent().queue_free()
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


## Looks at every `stride`th sample (a music layer is long).
func _peak(w: AudioStreamWAV, stride := 1) -> float:
	var peak := 0
	for i in range(0, w.data.size(), 2 * stride):
		peak = maxi(peak, absi(w.data.decode_s16(i)))
	return peak / 32767.0


## The share of samples pinned at SfxSynth's ceiling.
func _clipped(w: AudioStreamWAV, stride := 1) -> float:
	var n := 0
	for i in range(0, w.data.size(), 2 * stride):
		if absi(w.data.decode_s16(i)) >= 26000:
			n += 1
	return float(n) / (w.data.size() / (2 * stride))
