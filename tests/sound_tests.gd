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
	await test_elevator_sounds()
	await test_monster_sounds()
	test_touch_kinds()
	check(Sfx.KINDS.has(Counterplay.BLAST_SOUND) and Sfx.stream(Counterplay.BLAST_SOUND) != null, "a fire extinguisher's blast has its burst and hiss")
	await test_touch()
	await test_every_interactable_sounds()
	test_surfaces()
	await test_footsteps()
	await test_landing()
	await test_teammate_steps()
	await test_fight_sounds()
	await test_teammate_fight_sounds()
	await test_npc_fight_sounds()
	await test_remembered_voice()
	test_recorded_budget_and_credits()
	test_music_layers()
	await test_music_moods()
	test_npc_danger()
	await test_music_director()
	await test_room_reverb()
	await test_floor_beds()
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
	var monsters := 0
	for kind in SfxCreatures.KINDS:
		var w := SfxCreatures.make(kind)
		monsters += w.data.size()
		var peak := _peak(w)
		check(peak > 0.05 and _clipped(w) < 0.01 and Sfx.KINDS.has(kind) and (w.loop_mode == AudioStreamWAV.LOOP_FORWARD) == (kind in SfxCreatures.LOOPS),
			"monster sound %s is made, audible, not clipped and in Sfx.KINDS (peak %.2f)" % [kind, peak])
	check(monsters < 400_000, "the monsters' sounds stay under 400 KB (%d bytes)" % monsters)


## A loop's last sample runs on into its first: no click each time round.
func test_loops_have_no_seam() -> void:
	for kind in SfxSynth.LOOPS + SfxCreatures.LOOPS:
		var w: AudioStreamWAV = SfxSynth.make(kind) if kind in SfxSynth.LOOPS else SfxCreatures.make(kind)
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
	check(kinds.call().back() == "handle", "a hinged door's handle turns and it creaks open")
	hinged.set_open(false)
	check(kinds.call().back() == "click", "and its latch clicks shut")
	var stair := Door.create(room, "STAIR-1-G", Vector3(12, 1.2, 0), Vector3(0.1, 2.4, 0.9)).make_hinged(Vector3(0, 0, -0.45))
	await t.process_frame
	stair.set_open(true)
	check(kinds.call().back() == "push_bar", "a stair door clanks on its push bar")
	stair.set_open(false)
	stair.locked = true
	var n: int = kinds.call().size()
	stair.interact(null)
	check(kinds.call().size() == n + 1 and kinds.call().back() == "lock" and not stair.is_open, "a locked door's handle rattles and it stays shut")
	var before: int = kinds.call().size()
	slid.set_open(true, true)
	slid.set_open(true)
	check(kinds.call().size() == before, "a door set at once (loading in) or already open makes no sound")
	room.queue_free()
	await t.process_frame


## An elevator: the bell and doors as it opens, the doors meeting as it shuts, the brake
## letting go and the hoist humming through the ride, and the brake catching at the floor.
func test_elevator_sounds() -> void:
	var room := Node3D.new()
	t.root.add_child(room)
	var lift := Elevator.create(room, room, Vector3(0, 0, 0), 0.0, "G", ["14", "G"], "14")
	var kinds := func(): return lift.get_meta("sounds_played", []).map(func(x): return x.kind)
	await t.process_frame
	lift.open()
	await t.process_frame
	await t.process_frame
	check(kinds.call() == ["lift_ding", "door_motor"], "the car's bell rings as its doors part, over their motor (%s)" % [kinds.call()])
	await t.create_timer(Elevator.OPEN_TIME + 0.2).timeout
	lift.close()
	await t.create_timer(Elevator.CLOSE_TIME + 0.2).timeout
	check(kinds.call().slice(2) == ["door_motor", "clunk"], "closing: the motor, then the doors meet (%s)" % [kinds.call().slice(2)])
	lift.ride(2.5)
	await t.process_frame
	await t.process_frame
	var sounds: SfxElevator = lift.get_node("Sounds")
	check(kinds.call().back() == "lift_thunk" and is_instance_valid(sounds.ride_loop) and sounds.ride_loop.playing,
		"the brake lets go and the hoist hums up the shaft")
	await t.create_timer(2.7).timeout
	check(kinds.call().has("cable_creak"), "the cables groan now and then on the way")
	check(kinds.call().back() == "lift_thunk" and sounds.ride_loop == null and not lift.riding, "and the brake catches at the floor; the hum stops")
	var n: int = kinds.call().size()
	var other := Elevator.create(room, room, Vector3(6, 0, 0), 0.0, "14", ["14", "G"], "G")
	other.open(true)
	await t.process_frame
	await t.process_frame
	check(other.get_meta("sounds_played", []).is_empty() and kinds.call().size() == n, "a car already open when a floor loads makes no sound")
	room.queue_free()
	await t.process_frame

## The monsters, heard from what they do. Their brains are off here, as on a client's
## machine: only their state and where they are change, as the host sends them.
func test_monster_sounds() -> void:
	var a := Node3D.new()
	t.root.add_child(a)
	Greybox.box(a, Vector3(0, -0.1, 0), Vector3(60, 0.2, 60), Color.GRAY, "Floor")
	var heard := func(): return a.get_meta("sounds_played", []).map(func(x): return x.kind)
	var walk := func(n: Node3D, metres: float):
		for i in int(metres / 0.05):
			n.global_position.x += 0.05
			await t.process_frame
	var sh := Shredder.new()
	sh.position = Vector3(-20, 0, -20)
	a.add_child(sh)
	sh.set_physics_process(false)
	await t.process_frame
	sh.state = "listening"
	await t.process_frame
	check(heard.call().has("shredder_roar"), "the Shredder roars as it wakes")
	await walk.call(sh, 4.5)
	check(heard.call().count("heavy_step") >= 2, "its feet come down heavy as it walks (%d)" % heard.call().count("heavy_step"))
	sh.state = "turning"
	await t.process_frame
	check(heard.call().back() == "shredder_snarl", "it snarls as it turns to a sound")
	sh.state = "stunned"
	await t.process_frame
	check(heard.call().back() == "shredder_roar", "a blast in the face makes it roar")
	var cu := Custodian.new()
	cu.position = Vector3(-10, 0, -10)
	a.add_child(cu)
	cu.set_physics_process(false)
	await t.process_frame
	cu.state = "hunting"
	await t.process_frame
	check(heard.call().back() == "robot_boot", "the Custodian boots up as it leaves its bay")
	var cu_voice: SfxMonster = cu.get_node("Voice")
	await walk.call(cu, 3.0)
	check(heard.call().has("robot_step") and is_instance_valid(cu_voice.loop_player), "it clanks along, its servos whining")
	await t.create_timer(1.0).timeout
	check(cu_voice.loop_player == null, "standing still, the servos stop")
	cu.state = "stunned"
	await t.process_frame
	await t.process_frame
	check(heard.call().back() == "sparks", "stunned, it spits sparks")
	var wa := Watcher.new()
	wa.position = Vector3(0, 0, 10)
	a.add_child(wa)
	wa.set_physics_process(false)
	await t.process_frame
	await walk.call(wa, 2.5)
	check(heard.call().has("watcher_step"), "the Watcher's feet drag as it comes, unseen")
	await t.create_timer(1.0).timeout
	check(heard.call().back() == "watcher_creak", "seen, it stops dead and its joints creak")
	var mi := Mimic.new()
	mi.position = Vector3(10, 0, 10)
	a.add_child(mi)
	mi.set_physics_process(false)
	await t.process_frame
	mi.state = "leaving"
	await t.process_frame
	check(heard.call().back() == "vault", "a Mimic's clothes rustle as it gets up to leave")
	var n: int = heard.call().size()
	mi.global_position += Vector3(10, 0, 0)  # turns up somewhere else
	await t.process_frame
	check(heard.call().size() == n, "and turning up somewhere else makes no footstep")
	var ec := Echo.make(a, "TEST", "Test", Vector3(20, 0, 0), 0.0)
	await t.process_frame
	await t.process_frame
	var ec_voice: SfxMonster = ec.get_node("Voice")
	check(is_instance_valid(ec_voice.loop_player) and ec_voice.loop_player.playing, "an Echo hums, cold and thin, at its row")
	ec.begin_release()
	await t.process_frame
	check(heard.call().back() == "echo_release" and ec_voice.loop_player == null, "punched out, it shimmers up and the hum is gone")
	a.queue_free()
	await t.process_frame


## What each thing you can use sounds like, from what it is and what its prompt says.
func test_touch_kinds() -> void:
	var cases := {"Open your locker": "locker", "Press 22": "button", "Reset breaker B-1": "switch",
		"Reset the lighting circuit": "switch", "Turn the crank": "crank", "Unbuckle (ready up)": "buckle",
		"Badge in": "card", "Prop the stair door open": "push_bar", "Pull the manual release": "lever",
		"Push the vent hatch open": "vent_panel", "Pull the grate off the air return": "vent_panel",
		"Take the spare key": "keys", "Take a screwdriver": "item", "Get in the van": "car_door",
		"Use the computer": "mouse", "Close and lock SEC-EXIT": "lock", "Tear the tape on box 3": "tape_tear",
		"Sign the visitor log": "pen", "Reseat the fan tray (RB-1)": "slot", "Open the door": "handle"}
	var wrong := []
	for prompt in cases:
		var it := Interactable.new()
		it.prompt = prompt
		if SfxTouch.kind_of(it) != cases[prompt]:
			wrong.append("%s: %s" % [prompt, SfxTouch.kind_of(it)])
		it.free()
	check(wrong.is_empty(), "a thing's prompt says what it sounds like (wrong: %s)" % [wrong])
	var key := Interactable.new()
	key.name = "Key_5"
	key.prompt = "Press 5"
	var relay := Interactable.new()
	relay.prompt = ""
	check(SfxTouch.kind_of(key) == "keypad" and SfxTouch.sound_of(SfxTouch.kind_of(relay)) == "",
		"a door keypad's keys sound like a keypad; an unseen relay is silent")
	key.kind = "paper"
	relay.kind = "none"
	relay.prompt = "Open your locker"
	check(SfxTouch.kind_of(key) == "paper" and SfxTouch.sound_of(SfxTouch.kind_of(relay)) == "",
		"a kind set by hand wins, and \"none\" is silent")
	check(SfxTouch.sound_of("slot") == "clunk" and SfxTouch.sound_of("vent_panel") == "rattle"
		and SfxTouch.sound_of("pen") == "pencil" and SfxTouch.sound_of("terminal") == "",
		"some kinds borrow another's sound; a terminal makes its own")
	key.free()
	relay.free()


## Using something tells every machine (touched, which the hands hook too) and it
## sounds where it is; something switched off, or silent, doesn't.
func test_touch() -> void:
	var room := Node3D.new()
	t.root.add_child(room)
	var kinds := func(): return room.get_meta("sounds_played", []).map(func(x): return x.kind)
	var locker := Interactable.create(room, Vector3(2, 1, 0), Vector3(0.5, 1.8, 0.5), "Open your locker")
	locker.alt_prompt = "Take the spare key"
	var heard := []
	locker.touched.connect(func(id): heard.append(id))
	var used := [0]
	locker.used.connect(func(_p): used[0] += 1)
	locker.interact(null)
	check(heard == [0] and used[0] == 1 and kinds.call() == ["locker"] and room.get_meta("sounds_played")[0].pos == Vector3(2, 1, 0),
		"using a locker: it's touched, everywhere, and it bangs open where it is")
	locker.interact_alt(null)
	check(heard.size() == 2 and kinds.call().size() == 2, "the other use (X) sounds too")
	locker.enabled = false
	locker.interact(null)
	check(heard.size() == 2 and kinds.call().size() == 2, "something switched off makes no sound")
	var quiet := Interactable.create(room, Vector3(4, 1, 0), Vector3(0.5, 0.5, 0.5), "Press the button")
	quiet.kind = "none"
	var quiet_heard := []
	quiet.touched.connect(func(id): quiet_heard.append(id))
	quiet.interact(null)
	check(quiet_heard.is_empty() and kinds.call().size() == 2, "a silent thing is used without a sound")
	var seat := Seat.create_at(room, Vector3(6, 0.45, 0), 0.0)
	var sat := []
	seat.touched.connect(func(id): sat.append(id))
	seat.used.emit(null)
	var cabinet := FirstAidCabinet.new()
	room.add_child(cabinet)
	check(sat == [0] and kinds.call().back() == "seat" and cabinet.used.is_connected(cabinet._on_touched),
		"kinds with their own setup (a seat, a first aid cabinet) are touched too: a seat creaks")
	room.queue_free()
	await t.process_frame


## The floors' vents and badge readers sound as they work, on every machine (each
## of these runs everywhere).
func _vents_and_readers(scene: String, level: Node) -> void:
	var last := func(n: Node): return n.get_meta("sounds_played", [{}]).back().get("kind", "")
	match scene:
		"level_0":
			level._on_vent_grate()
			check(last.call(level) == "panel_off", "floor G: the air return's grate is worked out of its frame")
			level._on_boost()  # after Rourke's line
			var end := Time.get_ticks_msec() + 15000
			while last.call(level) != "ceiling_tile" and Time.get_ticks_msec() < end:
				await t.create_timer(0.1).timeout
			check(last.call(level) == "ceiling_tile", "the ceiling tile knocks up into the void")
		"level_2":
			level.set_hatch(true)
			check(last.call(level.geo) == "hinge", "floor 22: the vent hatch's hinge squeals open")
			level.set_hatch(false)
			check(last.call(level.geo) == "clunk", "and clunks shut")
			level.open_vent_grate()
			check(last.call(level.geo) == "unscrew", "the grate's screws come out")
			await t.create_timer(0.6).timeout
			check(last.call(level.geo) == "clatter", "and it clatters to the floor as it lands")
			var lab: Level2Lab = level.lab
			level.player.inventory.remove("visitor_badge")
			lab._on_reader(level.player)
			check(last.call(level.geo) == "reader_no", "the lab's reader blats at someone with no badge")
			lab._badged(99, "VIS-09")
			check(last.call(level.geo) == "reader_ok", "and chirps for a visitor badge")
		"level_5":
			level._swipe("VIS-01", "PERS-FRONT", "23:10")
			check(last.call(level) == "reader_ok", "floor 9: a doorway reader chirps as a badge goes by")
		"level_6":
			var vault: String = level.VAULT_ROOMS.keys()[0]
			level._punch("VIS-01", vault, true)
			check(last.call(level) == "reader_ok", "B1: a vault's reader chirps as a card punches in")


## Everything on every floor that can be used makes a sound (or is quiet on purpose).
func test_every_interactable_sounds() -> void:
	var game := t.root.get_node("Game")
	var unsounded := []
	var count := 0
	var kinds := {}
	for scene in load("res://tests/body_tests.gd").FLOORS:
		game.new_run(7)
		var level = load("res://scenes/%s.tscn" % scene).instantiate()
		t.root.add_child(level)
		await t.process_frame
		for n in level.find_children("*", "", true, false):
			if not n is Interactable:
				continue
			count += 1
			var kind := SfxTouch.kind_of(n)
			var sound := SfxTouch.sound_of(kind)
			kinds[kind] = true
			if kind == "" or (sound != "" and not (Sfx.KINDS.has(sound) and Sfx.stream(sound) != null and n.used.is_connected(n._on_touched))):
				unsounded.append("%s %s \"%s\"" % [scene, n.name, n.prompt])
		await _vents_and_readers(scene, level)
		level.queue_free()
		await t.process_frame
	check(count > 300 and unsounded.is_empty(),
		"all %d things you can use on every floor have a sound, %d kinds (none: %s)" % [count, kinds.size(), unsounded])


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
	var steps: Array = p.get_node("Steps").heard.filter(func(h): return h.kind.begins_with("step_") or h.kind == "duct_crawl")
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
	var duct: Array = await _walker("crouch", "vent")
	check(not duct[0].is_empty() and duct[0].all(func(h): return h.kind == "duct_crawl" and h.db == SfxSteps.CRAWL_VENT_DB),
		"crawling a duct, the sheet metal booms under each knee (%d)" % duct[0].size())
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


## Your own fight: from your PlayerCombat's signals.
func test_fight_sounds() -> void:
	for kind in ["swing", "body_fall"]:
		check(Sfx.stream(kind) is AudioStreamWAV, "%s is made in code" % kind)
	check(Sfx.stream("punch_metal") is AudioStreamRandomizer, "punch_metal is recorded, with variants")
	# Augustine's playtest: the recorded punches were all low thud, too dull to read as
	# a hit on a laptop's speakers, and the guard's belt-buckle rustle jingled like keys.
	for kind in SfxPunches.KINDS:
		var takes: AudioStreamRandomizer = Sfx.stream(kind)
		check(takes.streams_count == SfxPunches.VARIANTS, "%s is made in code, in %d takes" % [kind, SfxPunches.VARIANTS])
		var ok := true
		for v in SfxPunches.VARIANTS:
			var w := SfxPunches.make(kind, v)
			ok = ok and _peak(w) > 0.5 and _clipped(w) < 0.001 and Sfx.KINDS.has(kind)
		check(ok, "every take of %s is loud, unclipped and has a bus" % kind)
	for kind in ["punch_hit", "hurt", "block", "bag_hit"]:
		var bite := _bite(SfxPunches.make(kind))
		check(bite > 0.02, "%s has bite above the low thud, so small speakers play it (%.3f)" % [kind, bite])
	check(_bite(SfxPunches.make("guard")) < 0.5, "the guard going up is a soft swish, not a jingle")
	check(SfxPunches.make("punch_hit").data != SfxPunches.make("punch_hit", 1).data, "the takes differ")
	check(SfxPunches.make("punch_hit").data == SfxPunches.make("punch_hit").data, "and each is the same every run")
	Sfx.clear_cache()
	Sfx._warming = false
	Sfx.warm_fight()
	for i in 300:
		if Sfx._streams.size() == SfxPunches.KINDS.size():
			break
		await t.process_frame
	check(SfxPunches.KINDS.keys().all(func(k): return Sfx._streams.get(k) is AudioStreamRandomizer),
		"a player's fight sounds are made in the background before the first punch")
	var a := Node3D.new()
	t.root.add_child(a)
	var p := Player.new()
	p.local_control = false
	a.add_child(p)
	await t.process_frame
	var fight: SfxCombat = p.get_node("FightSounds")
	p.combat.swung.emit()
	check(fight.heard == ["swing"], "throwing a punch, a whoosh")
	p.combat.take_damage(10.0, "rourke")
	check(fight.heard.back() == "hurt", "taking a punch, a hit")
	p.combat.raise_guard()
	p.combat.take_damage(10.0, "rourke")
	check(fight.heard.slice(-2) == ["guard", "block"], "the guard going up rustles, and a block thuds")
	p.combat.reset()
	p.combat.take_damage(0.0, "spar")
	check(fight.heard.back() == "bag_hit", "the punch bag catching you is the bag's thud, not a fist")
	var n := fight.heard.size()
	p.combat.hurt.emit(30.0, "fall")
	check(fight.heard.size() == n, "a fall's hurt is the landing's sound, not a punch")
	p.combat.went_down.emit("watcher")
	check(fight.heard.back() == "body_fall", "going down, you hit the floor")
	check(a.get_meta("sounds_played", []).any(func(x): return x.kind == "body_fall"), "and it plays where you are")
	a.queue_free()
	await t.process_frame


## A teammate's fight, from the fists their machine sends and from lying down.
func test_teammate_fight_sounds() -> void:
	var a := Node3D.new()
	t.root.add_child(a)
	var mate := PlayerPuppet.create(a, 7, "Mate", {}, Transform3D(Basis(), Vector3(0, 0, 4)))
	var fight: SfxCombat = mate.get_node("FightSounds")
	for action in ["jab", "", "jab", "cross", "guard", "recoil", "flinch", "flinch"]:
		mate.set_fight(action)
		await t.process_frame
	check(fight.heard == ["swing", "swing", "swing", "guard", "block", "hurt"],
		"a teammate's punches, guard, blocks and hits are heard on your machine, once each (%s)" % [fight.heard])
	mate.set_downed(true)
	await t.process_frame
	await t.process_frame
	check(fight.heard.back() == "body_fall" and fight.heard.count("body_fall") == 1, "and going down, once")
	a.queue_free()
	await t.process_frame


## Rourke and the Custodian, from what the host replicates of them.
func test_npc_fight_sounds() -> void:
	var a := Node3D.new()
	t.root.add_child(a)
	var r := Rourke.new()
	r.hits_left = 0
	a.add_child(r)
	r.hits_left = 3
	await t.process_frame
	var fight: SfxCombat = r.get_node("FightSounds")
	check(fight.heard.is_empty(), "his fight starting (hits left going up) makes no sound")
	r.hits_left = 2
	await t.process_frame
	check(fight.heard == ["punch_hit"], "a punch landing on Rourke")
	r.set("_windup", 0.4)
	await t.process_frame
	r.set("_windup", -0.01)
	await t.process_frame
	check(fight.heard.back() == "swing", "his wind-up running out is his swing")
	r.set("_windup", 0.4)
	await t.process_frame
	r.set("_windup", 0.0)
	r.hits_left = 1
	await t.process_frame
	check(fight.heard.slice(1) == ["swing", "punch_hit"], "hit mid-wind-up, he doesn't swing")
	r.hits_left = 0
	await t.process_frame
	check(fight.heard.slice(-2) == ["punch_hit", "body_fall"], "the last punch puts him on the floor")
	var c := Custodian.new()
	a.add_child(c)
	await t.process_frame
	c.strikes += 1
	await t.process_frame
	check(c.get_node("FightSounds").heard == ["punch_metal"], "a punch on the Custodian clangs")
	a.queue_free()
	await t.process_frame


## Maddison's chapter lines out on a floor: a memory of her saying it, not her in the room.
func test_remembered_voice() -> void:
	var real_folder := Voice.folder
	Voice.folder = "user://sound_voice_test/"
	DirAccess.make_dir_recursive_absolute(Voice.folder)
	var path := Voice.folder.path_join("l0_brief_1.wav")
	SfxSynth.make("beep").save_to_wav(path)
	var voice := Voice.new()
	t.root.add_child(voice)
	await t.process_frame
	check(voice.play("l0_brief_1") > 0.0 and voice._player.bus == Sfx.VOICE, "said in the garage, her line plays as it is")
	voice.play("l0_brief_1", "", true)
	check(voice._player.bus == Voice.MEMORY_BUS, "remembered, it plays through the memory sound")
	var bus := AudioServer.get_bus_index(Voice.MEMORY_BUS)
	check(bus > AudioServer.get_bus_index(Sfx.VOICE) and AudioServer.get_bus_send(bus) == Sfx.VOICE,
		"which feeds the Voice bus, so the Voices slider still covers it")
	var fx := []
	for i in AudioServer.get_bus_effect_count(bus):
		fx.append(AudioServer.get_bus_effect(bus, i))
	var low: Array = fx.filter(func(e): return e is AudioEffectLowPassFilter)
	var room: Array = fx.filter(func(e): return e is AudioEffectReverb)
	check(low.size() == 1 and low[0].cutoff_hz < 3000.0 and fx.any(func(e): return e is AudioEffectHighPassFilter),
		"a memory is softer: the top taken off, the boom kept out")
	check(room.size() == 1 and room[0].room_size < 0.6 and room[0].dry > 0.85 and room[0].wet < 0.35,
		"in a small soft room, with every word still clear")
	var pa_room: AudioEffectReverb = null
	var pa := AudioServer.get_bus_index(Voice.PA_BUS)
	for i in AudioServer.get_bus_effect_count(pa):
		if AudioServer.get_bus_effect(pa, i) is AudioEffectReverb:
			pa_room = AudioServer.get_bus_effect(pa, i)
	check(pa_room != null and pa_room.room_size > room[0].room_size, "and nothing like the PA's empty halls")
	voice.queue_free()
	DirAccess.remove_absolute(path)
	Voice.folder = real_folder
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
		var secs := float(w.loop_end) / w.mix_rate if w else 0.0
		var loops := secs / MusicSynth.LENGTH
		check(w != null and w.loop_mode == AudioStreamWAV.LOOP_FORWARD and is_equal_approx(secs, MusicSynth.seconds(layer))
			and loops >= 1.0 and is_equal_approx(loops, roundf(loops)),
			"music layer %s loops, a whole number of the others' loops long (%.2f s)" % [layer, secs])
		var peak := _peak(w, 7)
		check(peak > 0.1 and _clipped(w, 7) < 0.001, "music layer %s is audible and not clipped (peak %.2f)" % [layer, peak])
		var first := w.data.decode_s16(0) / 26000.0
		var last := w.data.decode_s16((w.loop_end - 1) * 2) / 26000.0
		check(absf(first - last) < 0.05, "music layer %s loops without a click (seam %.3f)" % [layer, absf(first - last)])
	print("    (music made in %d ms)" % ms)
	var lobby := MusicSynth.make("lobby")
	check(lobby.mix_rate == MusicSynth.LOBBY_RATE and is_equal_approx(MusicSynth.seconds("lobby"), MusicSynth.LENGTH * 2.0),
		"the lobby's tune runs two of the others' loops, through a ceiling speaker")
	check(MusicSynth.LOBBY_TUNE.back()[2] == 72 and MusicSynth.SAG > 0.0 and MusicSynth.SAG < 0.5,
		"the tune's last note sags, a little: not quite right, not obviously wrong")
	# The shadow is quieter than the tune itself.
	check(_peak(MusicSynth.make("lobby_off"), 7) < _peak(lobby, 7), "the lobby's shadow sits under the tune")
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
	var player: Node3D


## Stands in for a floor: its key, and (Floor 10) its copy of the ground floor.
class FakeWing extends Node3D:
	var wing_id := ""
	var g_root: Node3D


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
	# Close to it, you hear your own heart; the rest of the crew, across the floor, don't.
	var me := Node3D.new()
	floor_wing.add_child(me)
	world.player = me
	s.global_position = Vector3(30, 0, 0)
	me.global_position = Vector3(30 + MusicDirector.NEAR - 2.0, 0, 0)
	check(d.pick() == "close", "a threat a few metres from you: close")
	me.global_position = Vector3(30 + MusicDirector.NEAR + 5.0, 0, 0)
	check(d.pick() == "hunted", "further off: hunted")
	s.state = "grabbing"
	check(d.pick() == "chase", "it has someone: chase")
	me.global_position = Vector3(30 + MusicDirector.NEAR - 2.0, 0, 0)
	check(d.pick() == "chase", "chase wins over close")
	world.player = null
	me.free()
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
	await _alarm_moods(world, d)
	await _sealed_moods(world, d)
	await _lobby_moods(world, d, game)
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


## Stands in for a floor's doors, which follow the doors table.
class FakeDoor extends Node3D:
	var locked := false


class DoorWing extends Node3D:
	var wing_id := "level_0"
	var doors := {}


func _sealed_moods(world: FakeWorld, d: MusicDirector) -> void:
	var sting := MusicSynth.sting("sealed")
	check(sting != null and sting.loop_mode == AudioStreamWAV.LOOP_DISABLED and _peak(sting) > 0.3 and _clipped(sting) < 0.001,
		"the sealed sting plays once, and doesn't clip (peak %.2f)" % _peak(sting))
	check(MusicSynth.sting("party") == null, "there's no sting that isn't listed")
	var was: Node = world.current
	var g := DoorWing.new()
	world.add_child(g)
	for id in ["LOBBY-FRONT", "LOBBY-HALL-END", "FAR"]:
		var door := FakeDoor.new()
		g.add_child(door)
		g.doors[id] = door
	g.doors["LOBBY-HALL-END"].locked = true  # locked when the floor was built
	g.doors["FAR"].position = Vector3(MusicDirector.SEAL_NEAR + 20.0, 0, 0)
	var me := Node3D.new()
	g.add_child(me)
	me.position = Vector3(2, 0, 2)
	world.player = me
	world.current = g
	d.watch_doors()
	check(d.pick() != "sealed", "a floor's doors locked from the start aren't the building locking you in")
	g.doors["FAR"].locked = true
	d.watch_doors()
	check(d.pick() != "sealed", "a door locking across the floor, far from you, isn't either")
	g.doors["LOBBY-FRONT"].locked = true
	g.doors["LOBBY-HALL-END"].locked = false
	d.watch_doors()
	check(d.pick() == "sealed" and d.sting_player != null and d.sting_player.playing and d.sting_player.bus == Sfx.MUSIC,
		"the front doors lock behind you: the sting, and the music sealed")
	g.doors["LOBBY-HALL-END"].locked = true
	d.watch_doors()
	d._process(0.0)
	check(d._sting_wait > MusicDirector.STING_GAP - 0.5, "a lockdown's doors locking one after another: one sting, not one each")
	d._process(MusicDirector.SEALED_HOLD + 0.1)
	check(d.pick() != "sealed", "after a while, back to the floor's mood")
	# B1's sweeps relock the same door over and over: it shuts you in once.
	g.doors["LOBBY-FRONT"].locked = false
	d.watch_doors()
	g.doors["LOBBY-FRONT"].locked = true
	d.watch_doors()
	check(d.pick() != "sealed", "the same door relocking a minute later doesn't sting again")
	d._process(MusicDirector.DOOR_AGAIN)
	d._process(MusicDirector.STING_GAP)
	g.doors["LOBBY-FRONT"].locked = false
	d.watch_doors()
	g.doors["LOBBY-FRONT"].locked = true
	d.watch_doors()
	check(d.pick() == "sealed", "but long after, it does")
	d._process(MusicDirector.SEALED_HOLD + 0.1)
	d.sting_player.stop()
	world.current = was
	world.player = null
	g.free()
	await t.process_frame


## Stands in for a floor with an alarm (Floor 10) or gas suppression (B2).
class AlarmWing extends Node3D:
	var wing_id := "level_4"
	var alarm := false
	var gas := {"B2-MOTOR": "idle", "B2-UPS": "idle"}


func _alarm_moods(world: FakeWorld, d: MusicDirector) -> void:
	var was: Node = world.current
	var w := AlarmWing.new()
	world.add_child(w)
	world.current = w
	check(d.pick() == "uneasy", "no alarm: the floor's own mood")
	w.alarm = true
	check(d.pick() == "alarm", "the breakers out of place and the alarm going: the music hears it")
	w.alarm = false
	w.gas["B2-UPS"] = "armed"
	check(d.pick() == "alarm", "a gas discharge counting down: alarm")
	var c := Custodian.new()
	w.add_child(c)
	c.set_process(false)
	c.set_physics_process(false)
	c.state = "hunting"
	check(d.pick() == "chase", "something after you wins over the alarm")
	c.free()
	w.gas["B2-UPS"] = "discharged"
	check(d.pick() == "uneasy", "once it's over, back to the floor's mood")
	var m: Music = d.get_parent()
	m.set_mood("alarm")
	m._process(Music.FADE_IN)
	check(m.level["siren"] > 0.6 and m.level["pulse"] == 1.0, "alarm: the siren through the wall, and the pulse driving")
	m.set_mood("silent")
	m._process(Music.FADE_OUT)
	world.current = was
	w.free()
	await t.process_frame


## The ground floor plays its own hold music inside; out by the van, the home theme.
func _lobby_moods(world: FakeWorld, d: MusicDirector, game: Node) -> void:
	var gf: Script = load(MusicDirector.GROUND_FLOOR)
	var was: Node = world.current
	var g := FakeWing.new()
	g.wing_id = "level_0"
	world.add_child(g)
	world.current = g
	var me := Node3D.new()
	world.add_child(me)
	world.player = me
	game.rourke_fate = "unknown"
	me.global_position = Vector3(gf.DESK.x, 0, gf.DESK.z + 2.0)
	check(d.pick() == "lobby", "in the lobby, its own hold music")
	me.global_position = gf.mid(gf.LIFT_HALL)
	check(d.pick() == "lobby", "all the way through the ground floor, to the lifts")
	me.global_position = Vector3(gf.FRONT_AT.x, 0, gf.LOBBY.end.y + 9.0)
	check(d.pick() == "checkpoint", "out in the car park, by the van, the home theme still")
	me.global_position = Vector3(gf.DESK.x, 0, gf.DESK.z + 2.0)
	var s := Shredder.new()
	s.position = gf.mid(gf.LIFT_HALL)  # down the hall, not on top of you
	g.add_child(s)
	s.set_process(false)
	s.set_physics_process(false)
	s.active = true
	s.state = "roaming"
	check(d.pick() == "hunted", "danger in the lobby hands over to the score")
	s.free()
	# Floor 10's walk out, through the same lobby, built somewhere else entirely.
	var f10 := FakeWing.new()
	f10.wing_id = "level_4"
	world.add_child(f10)
	f10.position = Vector3(74, 0, -140)
	f10.g_root = Node3D.new()
	f10.add_child(f10.g_root)
	f10.g_root.position = Vector3(0, -40, 0)
	world.current = f10
	game.rourke_fate = "tied"
	me.global_position = f10.g_root.to_global(Vector3(gf.DESK.x, 0, gf.DESK.z + 2.0))
	check(d.pick() == "lobby_late", "the same lobby on the way out, after Rourke: the tune gone wrong")
	me.global_position = f10.to_global(Vector3(0, 0, 0))
	check(d.pick() == "uneasy", "the rest of floor 10 is floor 10")
	game.rourke_fate = "unknown"
	me.global_position = f10.g_root.to_global(Vector3(gf.DESK.x, 0, gf.DESK.z + 2.0))
	check(d.pick() == "lobby", "(the lobby itself, if Rourke hadn't turned)")
	world.current = was
	world.player = null
	for n in [g, f10, me]:
		n.free()
	game.rourke_fate = "tied"
	var m: Music = d.get_parent()
	m.set_mood("lobby")
	m._process(Music.FADE_IN)
	check(m.level["lobby"] > 0.7 and m.level["lobby_off"] < 0.2 and m.level["drone"] == 0.0, "lobby: the tune, its shadow just under it")
	m.set_mood("lobby_late")
	m._process(Music.FADE_OUT)
	check(m.level["lobby_off"] > m.level["lobby"] and m.level["drone"] > 0.0, "lobby_late: the shadow over the tune, and the drone back")
	await t.process_frame


## A closed box of walls, floor and ceiling, `size` across, centred on `at` (its floor at at.y).
func _box_room(parent: Node3D, at: Vector3, size: Vector3, roof := true) -> void:
	var slabs := [
		[Vector3(0, -0.1, 0), Vector3(size.x, 0.2, size.z)],
		[Vector3(-size.x / 2 - 0.1, size.y / 2, 0), Vector3(0.2, size.y, size.z)],
		[Vector3(size.x / 2 + 0.1, size.y / 2, 0), Vector3(0.2, size.y, size.z)],
		[Vector3(0, size.y / 2, -size.z / 2 - 0.1), Vector3(size.x, size.y, 0.2)],
		[Vector3(0, size.y / 2, size.z / 2 + 0.1), Vector3(size.x, size.y, 0.2)],
	]
	if roof:
		slabs.append([Vector3(0, size.y + 0.1, 0), Vector3(size.x, 0.2, size.z)])
	for s in slabs:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = s[1]
		body.add_child(shape)
		body.position = at + s[0]
		parent.add_child(body)


func test_room_reverb() -> void:
	check(SfxRooms.ensure_reverb() == SfxRooms.ensure_reverb(), "the SFX bus gets one reverb, never two")
	var bus := AudioServer.get_bus_index(Sfx.SFX)
	var on_sfx := false
	for i in AudioServer.get_bus_effect_count(bus):
		on_sfx = on_sfx or AudioServer.get_bus_effect(bus, i) == SfxRooms.ensure_reverb()
	check(on_sfx, "it sits on the SFX bus, so footsteps, doors and monsters all go through it")
	var site := Node3D.new()
	t.root.add_child(site)
	var office := Vector3(500, 0, 0)
	var hall := Vector3(600, 0, 0)
	var duct := Vector3(700, 0, 0)
	var yard := Vector3(800, 0, 0)
	_box_room(site, office, Vector3(4, 2.7, 4))
	_box_room(site, hall, Vector3(24, 8, 24))
	_box_room(site, duct, Vector3(1.0, 1.0, 1.0))
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(80, 0.2, 80)
	ground.add_child(shape)
	ground.position = yard + Vector3(0, -0.1, 0)
	site.add_child(ground)
	await t.physics_frame
	await t.physics_frame
	var space := site.get_world_3d().direct_space_state
	var none: Array[RID] = []
	var m := {}
	for room in [["office", office, 1.6], ["hall", hall, 1.6], ["duct", duct, 0.4], ["yard", yard, 1.6]]:
		m[room[0]] = SfxRooms.measure(space, room[1] + Vector3(0, room[2], 0), 0xFFFFFFFF, none)
	check(absf(m.office.across - 4.0) < 0.6 and absf(m.office.up - 1.1) < 0.2, "it measures an office: walls 4 m apart, ceiling a metre up (%.1f, %.1f)" % [m.office.across, m.office.up])
	check(m.hall.across > 20.0 and m.hall.up > 6.0, "and a hall (%.1f, %.1f)" % [m.hall.across, m.hall.up])
	check(m.yard.open > 0.9, "out in the open, there's nothing to bounce off (%.2f)" % m.yard.open)
	var f := {}
	for k in m:
		f[k] = SfxRooms.feel(m[k].across, m[k].up, m[k].open)
	check(f.hall.wet > f.office.wet + 0.1 and f.hall.room_size > f.office.room_size + 0.3, "a hall rings on, an office is nearly dry")
	check(f.hall.predelay_msec > f.office.predelay_msec, "and its far wall answers later")
	check(f.duct.room_size < 0.2 and f.duct.damping < 0.2 and f.duct.predelay_msec < 5.0 and f.duct.wet >= f.office.wet,
		"inside a duct it's close and tinny")
	check(f.yard.wet < 0.05, "outside, no echo")
	# It follows this machine's player from room to room.
	var world := FakeWorld.new()
	t.root.add_child(world)
	var me := Node3D.new()
	site.add_child(me)
	me.global_position = office
	world.player = me
	var r := SfxRooms.follow(world)
	check(SfxRooms.follow(world) == r, "one room-follower per game")
	r._measure()
	for i in 60:
		r._process(0.05)
	var was_wet := r.reverb.wet
	check(absf(was_wet - f.office.wet) < 0.03, "standing in the office, the reverb is the office's (%.2f)" % was_wet)
	me.global_position = hall
	r._measure()
	r._process(0.1)
	check(r.reverb.wet > was_wet and r.reverb.wet < f.hall.wet - 0.02, "walking into the hall, it opens up over a moment, not with a jump")
	for i in 60:
		r._process(0.05)
	check(absf(r.reverb.wet - f.hall.wet) < 0.03 and absf(r.reverb.room_size - f.hall.room_size) < 0.03, "then it's the hall's")
	world.queue_free()
	site.queue_free()
	r.queue_free()
	await t.process_frame


func test_floor_beds() -> void:
	var route: Array = load("res://scripts/world/world.gd").ROUTE
	for entry in route:
		check(SfxBeds.FLOORS.get(entry.key, "") in SfxBeds.BEDS, "floor %s has its own room tone" % entry.key)
	var made := {}
	for kind in SfxBeds.BEDS:
		var w := SfxBeds.make(kind)
		made[kind] = w
		check(w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.data.size() < 200_000, "%s loops, and is small (%d KB)" % [kind, w.data.size() / 1024])
		var peak := _peak(w)
		check(peak > 0.3 and _clipped(w) == 0.0, "%s is there and doesn't clip (peak %.2f)" % [kind, peak])
		var n := w.loop_end
		var first := w.data.decode_s16(0) / 26000.0
		var last := w.data.decode_s16((n - 1) * 2) / 26000.0
		var before := w.data.decode_s16((n - 2) * 2) / 26000.0
		check(absf(first - last) <= maxf(absf(last - before) * 3.0, 0.05), "%s loops without a click (seam %.3f)" % [kind, absf(first - last)])
	check(SfxBeds.make("disco") == null, "there's no bed that isn't listed")
	check(_bite(made["archive"]) < _bite(made["server_floor"]), "the archive is stiller than the server floor")
	# It follows the floor the crew is on.
	var world := FakeWorld.new()
	t.root.add_child(world)
	var b6 := FakeWing.new()
	b6.wing_id = "level_6"
	world.add_child(b6)
	world.current = b6
	var beds := SfxBeds.follow(world)
	check(SfxBeds.follow(world) == beds, "one set of beds per game")
	beds._process(0.1)
	check(beds.bed == "cold_store" and beds._players.has("cold_store") and beds._players.cold_store.bus == Sfx.AMBIENCE,
		"in the cold store, its compressors, on the Ambience bus")
	var cold: AudioStreamPlayer = beds._players.cold_store
	check(cold.volume_db < SfxBeds.DB.cold_store, "fading in, not starting loud")
	for i in 40:
		beds._process(0.1)
	check(is_equal_approx(cold.volume_db, SfxBeds.DB.cold_store), "then at its level")
	var b7 := FakeWing.new()
	b7.wing_id = "level_7"
	world.add_child(b7)
	world.current = b7
	beds._process(1.0)
	check(beds.bed == "machine_room" and beds._players.has("cold_store") and beds._players.has("machine_room"), "down the stairs, one floor fades into the next")
	for i in 40:
		beds._process(0.1)
	check(not beds._players.has("cold_store") and not beds._streams.has("cold_store"), "and the last floor's is let go")
	world.home = Node3D.new()
	world.add_child(world.home)
	world.current = world.home
	for i in 40:
		beds._process(0.1)
	check(beds.bed == "" and beds._players.is_empty(), "the garage is quiet")
	world.queue_free()
	beds.queue_free()
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
## How much of a sound is in its edges: sample-to-sample change against its level.
## A low thud is near 0; something with a slap or a crack in it is well above.
func _bite(w: AudioStreamWAV) -> float:
	var level := 0.0
	var change := 0.0
	var last := 0.0
	for i in w.data.size() / 2:
		var v := w.data.decode_s16(i * 2) / 26000.0
		level += v * v
		change += (v - last) * (v - last)
		last = v
	return change / maxf(level, 0.0001)


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
