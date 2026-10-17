extends LevelBase
## Level 1: Server Room A. Rourke's betrayal, then WARDEN's self-test.
## Teaches WHERE and AND, and reading test output.

## Least time between Rourke's fight lines.
const BARK_GAP := 3.5
## Rourke turns this long after a player sits down at the terminal.
const ATTACK_DELAY := 4.0

var rourke: Rourke
var terminal: Terminal
var answer := ""
var rack_panels := {}
var panels_locked_until := 0.0
var has_badge := false
var _red := Color(1.0, 0.18, 0.12)
var _last_bark := -100.0
var _trapped := false
## Who is inside Server Room A yet, for sealing the hall behind them.
var crew_in := false
var rourke_in := false
var _sealed := false
var controller_puzzle := Puzzle.new("controller",
	"SELECT id FROM door_controllers WHERE zone = 'A' AND status = 'fault'", ["id"], false, [
	"Type this, then press Enter:\n" +
	"    [color=#ffffff]SELECT * FROM door_controllers WHERE zone = 'A' AND status = 'fault';[/color]\n" +
	"  SELECT *              show every column\n" +
	"  FROM door_controllers from the table of door controllers\n" +
	"  WHERE zone = 'A'      keep only the rows in zone A (the exit's zone)\n" +
	"  AND status = 'fault'  ...that are ALSO faulted. Both must be true.",
	"The id your query returns is the one controller to reset. Every rack in this room has its id " +
	"(DC-1 to DC-8) on the end facing the center aisle. Press E on that rack's panel. " +
	"Other faulted or offline controllers belong to other doors or are off on purpose: read their note column.",
])
var rourke_spawn := Transform3D.IDENTITY
var elevator: Elevator


func build() -> void:
	var data := Level1Data.build(Game.run_seed)
	answer = data.answer
	load_level_seed(data.sql)

	var floor_c := Color(0.32, 0.33, 0.35)
	var wall_c := Color(0.5, 0.52, 0.55)
	# Server room: x -7..7, z -9..9
	Greybox.room(geo, Vector3.ZERO, Vector3(14, 3.6, 18), {"floor": floor_c, "wall": wall_c, "ceiling": Color(0.4, 0.4, 0.42)}, [
		{"wall": "s", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4},
	])
	# Antechamber (south) and exit corridor (north)
	var ante_gaps := [{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4}]
	if world:
		ante_gaps.append({"wall": "s", "at": 0.0, "width": 1.8, "height": 2.4})  # from the lobby hall
	Greybox.room(geo, Vector3(0, 0, 11.5), Vector3(3, 3, 5), {"floor": floor_c, "wall": wall_c}, ante_gaps)
	Greybox.room(geo, Vector3(0, 0, -12.5), Vector3(3, 3, 7), {"floor": floor_c, "wall": wall_c}, [
		{"wall": "s", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "n", "at": 0.0, "width": Elevator.DOORWAY, "height": Elevator.DOOR_H},
	])
	# The way out: an elevator at the end of the emergency exit corridor, going down.
	elevator = Elevator.create(self, geo, Vector3(0, 0, -16.0), 180, "1", ["1", "B1", "B2"])
	add_door("SRA-ENTRY", Vector3(0, 1.2, 9), Vector3(1.8, 2.4, 0.15)).slide_axis = Vector3.UP
	add_door("SRA-EXIT", Vector3(0, 1.2, -9), Vector3(1.8, 2.4, 0.15))
	Greybox.label(geo, Vector3(0, 2.8, -8.88), "EMERGENCY EXIT", 64, Color(0.1, 0.8, 0.2))

	# Server racks: 4 rows x 2 columns, labeled DC-1 .. DC-8 on the center-aisle end.
	var n := 1
	for z in [-6.0, -3.0, 0.0, 3.0]:
		for side in [-1, 1]:
			var cx: float = side * 3.8
			Greybox.box(geo, Vector3(cx, 1.05, z), Vector3(4.0, 2.1, 0.9), Color(0.12, 0.12, 0.14), "Rack%d" % n)
			for k in 6:
				var led_color := Color(0.2, 1.0, 0.3) if randf() > 0.25 else Color(1.0, 0.6, 0.1)
				Greybox.panel(geo, Vector3(cx + randf_range(-1.7, 1.7), randf_range(0.3, 1.9), z + 0.46), Vector3(0.04, 0.04, 0.01), led_color, 3.0)
			var end_x: float = side * 1.78
			var face := 90.0 if side == -1 else -90.0
			var id := "DC-%d" % n
			Greybox.label(geo, Vector3(end_x + side * -0.02, 1.75, z), id, 72, Color(1, 1, 1), face)
			var p := Interactable.create(geo, Vector3(end_x + side * -0.04, 1.2, z), Vector3(0.08, 0.35, 0.45), "Reset controller " + id, Color(0.6, 0.55, 0.2))
			p.used.connect(_on_panel.bind(id))
			rack_panels[id] = p
			n += 1

	# Terminal desk by the entrance, facing into the room.
	Greybox.box(geo, Vector3(-4.5, 0.45, 8.4), Vector3(2.2, 0.9, 0.8), Color(0.4, 0.38, 0.35), "TermDesk")
	terminal = Terminal.spawn(geo, Vector3(-4.5, 0.9, 8.4), 180, "SERVER ROOM A", db, terminal_ui)
	terminal.puzzles = [controller_puzzle]
	terminal.boot_lines = [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  SERVER ROOM A",
		"Session: ROURKE_D (escort)",
		"",
		"Loading session history for VALE_I...",
	]
	terminal.queried.connect(_on_query)
	StickyNote.on_monitor(terminal, "where_and")
	# The room's laminated reference card, and Mercer's note on what the statuses mean.
	Document.place(geo, Vector3(-5.25, 0.902, 8.35), 175.0, "SERVER ROOM A - DOOR CONTROLLERS", [
		"Each rack drives one door lock. Rack ids DC-1 to DC-8 are on the aisle end.",
		{"before": "Every controller is listed in the table ", "filled": "door_controllers", "after": "."},
		"Columns: id, zone, status, location, last_reset, note",
		"This room's exit (SRA-EXIT) is in zone A.",
		"Faulted lock? Reset it at its own rack. Never reset a healthy one.",
	], true, "laminated", Vector2(0.21, 0.15))
	Document.place(geo, Vector3(-3.55, 0.902, 8.3), 190.0, "Note taped to the desk", [
		{"text": "status 'fault' = the lock relay is stuck. Needs a hand reset at the rack.", "hand": true, "author": "mercer"},
		{"text": "status 'offline' = someone switched it off on purpose. Leave it alone.", "hand": true, "author": "mercer"},
		{"text": "Zone first, then status. Plenty of faults in this building aren't yours.", "hand": true, "author": "mercer"},
		{"text": "- H.M.", "hand": true, "author": "mercer"},
	], true, "note", Vector2(0.1, 0.14))

	for p in [Vector3(0, 3.6, -7), Vector3(0, 3.6, -1.5), Vector3(0, 3.6, 4.5), Vector3(-6, 3.6, 8), Vector3(6, 3.6, -8)]:
		add_light("room", p, 9.0, 1.2)
	add_light("ante", Vector3(0, 3, 11.5), 5.0, 0.9)
	var ex := add_light("exit", Vector3(0, 3, -12.5), 6.0, 0.8)
	FlickerLight.attach(ex, 0.3)

	rourke = Rourke.new()
	rourke.name = "Rourke"
	add_child(rourke)
	rourke.position = Vector3(0, 0, 7.6)
	rourke_spawn = Transform3D(Basis(), Vector3(0, 0, -2))
	spawn = Transform3D(Basis(), Vector3(0, 0.1, 12.6))
	DressLevel1.apply(self)  # furniture and materials (Graphics thread)


func net_setup() -> void:
	sync.replicate(rourke, rourke.sync_properties())


func start() -> void:
	if world:
		# The lobby's Rourke walked the crew here: this one takes his place, where he stands.
		var lobby: LevelBase = world.wings.get("level_0")
		var guide = lobby.get("rourke") if lobby else null
		if is_instance_valid(guide):
			rourke.global_transform = guide.global_transform
			guide.queue_free()
		else:
			rourke.position = Vector3(0, 0, 10.5)
		# Seal the hall only once the whole team is through, and Rourke with them.
		var through := Trigger.create(self, Vector3(0, 1, 5.0), Vector3(14, 2, 18))
		through.require_all = true
		through.entered.connect(func(_b): crew_through())
	hud.todo("Follow Rourke inside")
	if sync.is_host():
		terminal.opened.connect(_on_terminal_opened, CONNECT_ONE_SHOT)
	var led_in := _lead_in()
	await hud.line("l1_enter")
	await sync.gate("rourke_at_desk", func():
		if not led_in.finished:
			await led_in.done)
	rourke_in = true
	_try_seal()
	rourke.face(player.global_position)
	await hud.line("l1_terminal")
	if not _trapped:
		hud.todo("Start work at the Server Room A terminal")


## Host: the crew is all inside Server Room A.
func crew_through() -> void:
	crew_in = true
	_try_seal()


## Host: the hall door shuts only once the crew and Rourke are both inside, so
## nobody (Rourke included) is shut out in the hall.
func _try_seal() -> void:
	if sync.is_host() and crew_in and rourke_in and not _sealed:
		_sealed = true
		sync.event("_on_all_through")


## Rourke leads the crew in: through the antechamber and the door, then to
## the terminal desk. Waypoints, so he never walks into a wall from the hall.
class LeadIn:
	signal done
	var finished := false


func _lead_in() -> LeadIn:
	var lead := LeadIn.new()
	var walk := func():
		for p in [Vector3(0, 0, 12.6), Vector3(0, 0, 7.8), Vector3(-2.4, 0, 6.4)]:
			if p.z > to_local(rourke.global_position).z:
				continue  # already past this one
			rourke.walk_to(to_global(p))
			await rourke.arrived
		lead.finished = true
		lead.done.emit()
	walk.call()
	return lead


func _on_all_through() -> void:
	world.seal_behind(self)


## Host: nothing is wrong until someone sits down to work. Then Rourke turns,
## once the whole team is inside, so nobody is locked out of the fight.
func _on_terminal_opened(p: Node) -> void:
	rourke.walk_to(p.global_position)  # drifting up behind them
	await get_tree().create_timer(ATTACK_DELAY).timeout
	var inside := Trigger.create(self, Vector3(0, 1, 2.0), Vector3(14, 2, 12))
	inside.require_all = true
	inside.entered.connect(func(_b): sync.event("_on_trapped", [null]), CONNECT_ONE_SHOT)


func _on_trapped(_b: Node) -> void:
	if _trapped:
		return
	_trapped = true
	if terminal_ui.terminal == terminal:
		terminal_ui.close()
	db.run_silent("UPDATE doors SET locked = 1 WHERE id = 'SRA-ENTRY'")
	db.sync_world()
	hud.notice("> DOOR SRA-ENTRY: LOCKED", 3.0, ThemeUtil.RED)
	set_all_lights_color(_red)
	rourke.add_to_group(VoiceChat.INTERFERENCE_GROUP)
	terminal.locked = true
	terminal.locked_message = "SESSION LOCKED BY USER ROURKE_D. ESCORT BADGE REQUIRED."
	terminal.set_screen_color(Color(1.0, 0.25, 0.2))
	rourke.face(player.global_position)
	# Tougher with more people swinging at him.
	rourke.max_hits = Rourke.MAX_HITS + 2 * (players.count() - 1)
	rourke.hits_left = rourke.max_hits
	await hud.lines(["l1_trap_1", "l1_trap_2"])
	hud.todo("Stop Rourke")
	hud.notice("Click to strike", 6.0)
	if sync.is_host():
		rourke.downed.connect(func(): sync.event("_on_rourke_downed"))
		rourke.resolved.connect(func(fate): sync.event("_on_rourke_resolved", [fate]))
		rourke.hit_player.connect(_bark.bind(["l1_hit_1", "l1_hit_2", "l1_hit_3", "l1_hit_4"]))
		rourke.struck.connect(_bark.bind(["l1_hurt_1", "l1_hurt_2", "l1_hurt_3"]))
		rourke.start_chase(players.nearest(rourke.global_position))


func _on_rourke_downed() -> void:
	hud.todo("Deal with Rourke before he gets up")
	_last_bark = Time.get_ticks_msec() / 1000.0
	hud.line("l1_downed")


## A short fight line, at most one every few seconds so they don't pile up.
## The host picks it so everyone hears the same one.
func _bark(ids: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_bark < BARK_GAP:
		return
	_last_bark = now
	sync.event("_on_bark", [ids.pick_random()])


func _on_bark(id: String) -> void:
	hud.line(id)


func _on_rourke_resolved(fate: String) -> void:
	Game.rourke_fate = fate
	has_badge = true
	hud.notice("You took Rourke's badge (R-0117).", 4.0)
	terminal.locked = false
	terminal.set_screen_color(Color(0.2, 0.9, 0.35))
	terminal.reboot(_self_test_lines())
	set_all_lights_color(Color(0.92, 0.95, 1.0))
	if fate == "killed":
		await hud.line("l1_killed")
		set_all_lights_color(_red)
		hud.notice("WARDEN LOCKDOWN ACTIVE", 5.0, ThemeUtil.RED)
	else:
		await hud.lines(["l1_tied_1", "l1_tied_2"])
	# WARDEN starts containment, and its own shredder tape talks over it. It waits, then
	# starts again from the top.
	await hud.line("l1_contain_1")
	await hud.line("l0_sort_hint")
	await get_tree().create_timer(2.0).timeout
	await hud.line("l1_contain_2")
	hud.todo("Find out why the exit is locked (Rourke's badge works on the terminal)")
	hud.lines(["l1_login", "l1_selftest"])


func _self_test_lines() -> Array:
	return [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  SERVER ROOM A",
		"Badge R-0117 accepted (ROURKE, D.)",
		"",
		"[b]WARDEN SELF-TEST[/b]  23:51:07",
		"  [color=#7dff8c]PASS[/color]  power.main_feed",
		"  [color=#7dff8c]PASS[/color]  hvac.zone_a",
		"  [color=#ff6655]FAIL[/color]  doors.server_room_a.exit    expected: unlocked   got: controller fault (zone A)",
		"  [color=#7dff8c]PASS[/color]  network.uplink",
		"  [color=#ff6655]FAIL[/color]  doors.cold_lab              expected: unlocked   got: controller fault (zone C)",
		"  [color=#7dff8c]PASS[/color]  cameras.lobby",
		"2 failed, 4 passed.",
		"",
		"The exit's controller is one row in the controller table (see the reference card at this desk).",
		"Clues from the self-test: it is in [b]zone A[/b] and its status is [b]'fault'[/b].",
		"Filter rows with WHERE. Need two conditions? Join them with AND. Example on another table:",
		"    [color=#ffffff]SELECT * FROM doors WHERE zone = 'A' AND locked = 1;[/color]",
		"      SELECT *          which columns to show (* = all)",
		"      FROM doors        which table to read",
		"      WHERE zone = 'A'  keep only rows where this is true",
		"      AND locked = 1    ...and this is true as well",
		"Text values go in 'single quotes'. Stuck? Type [b].hint[/b]",
	]


## Runs on the host; the result plays out on every machine.
func _on_query(_sql: String, result: Dictionary, _ui: TerminalUI) -> void:
	if not has_badge or controller_puzzle.solved or not controller_puzzle.matches(db, result):
		return
	sync.event("_on_controller_found")


func _on_controller_found() -> void:
	controller_puzzle.solved = true
	terminal.print_line("")
	terminal.print_line(TerminalUI.sysop("that's the one. %s, zone A, 'fault'. reset it by hand at its rack." % answer))
	hud.todo("Reset the faulted controller at its rack")
	hud.line("l1_found")


## Runs on the host when anyone presses a rack panel. It decides, then
## everyone sees the outcome, so the lockout timer is the same for all.
func _on_panel(_p: Node, id: String) -> void:
	if not has_badge:
		sync.event("_on_panel_result", [id, "no_badge", 0.0])
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < panels_locked_until:
		sync.event("_on_panel_result", [id, "locked", panels_locked_until - now])
		return
	if id != answer:
		var row: Dictionary = db.run_silent("SELECT status FROM door_controllers WHERE id = '%s'" % id)[0]
		sync.event("_on_panel_result", [id, "healthy" if row["status"] == "ok" else "wrong", 10.0])
		return
	sync.event("_on_panel_result", [id, "reset", 0.0])


func _on_panel_result(id: String, outcome: String, seconds: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	match outcome:
		"no_badge":
			hud.notice("RESET REFUSED: badge required.", 2.5, ThemeUtil.RED)
			hud.line("l1_no_badge", false)
			return
		"locked":
			panels_locked_until = now + seconds
			hud.notice("PANELS LOCKED: tamper lockout, %d s" % int(seconds), 2.0, ThemeUtil.RED)
			return
		"healthy":
			var zone: String = db.run_silent("SELECT zone FROM door_controllers WHERE id = '%s'" % id)[0]["zone"]
			hud.notice("> CONTROLLER %s: ZONE %s, OK. NOTHING TO RESET." % [id, zone], 4.0)
			terminal.print_line(TerminalUI.sysop("%s is healthy. you want the one in zone A with status 'fault'." % id))
			hud.line("l1_panel_ok", false)
			return
		"wrong":
			var row: Dictionary = db.run_silent("SELECT status, zone, note FROM door_controllers WHERE id = '%s'" % id)[0]
			panels_locked_until = now + seconds
			# The rack's own readout shows why, right where the player made the mistake.
			hud.notice("> %s: ZONE %s, '%s': %s\n> RESET REFUSED. PANELS LOCKED: %d s" % [id, row["zone"], row["status"], row["note"], int(seconds)], 6.0, ThemeUtil.RED)
			terminal.print_line(TerminalUI.sysop("not that one. %s is zone %s, '%s': %s" % [id, row["zone"], row["status"], row["note"]]))
			hud.line("l1_panel_wrong", false)
			return
	db.run_silent("UPDATE door_controllers SET status = 'ok', last_reset = '1997-10-15 23:58' WHERE id = '%s'" % id)
	db.run_silent("UPDATE doors SET locked = 0 WHERE id = 'SRA-EXIT'")
	db.sync_world()
	for p in rack_panels.values():
		p.enabled = false
	hud.notice("> CONTROLLER %s: RESET OK\n> DOOR SRA-EXIT: OPENED" % id, 4.0, ThemeUtil.GREEN)
	hud.todo("Get out through the emergency exit to the elevator")
	hud.line("l1_exit_open", false)
	var t := Trigger.create(self, Vector3(0, 1, -13.5), Vector3(3, 2, 1.5))
	t.entered.connect(func(_b): sync.event("_on_exit", [null]))


func _on_exit(_b: Node) -> void:
	elevator.hud = hud
	elevator.open()
	elevator.closed.connect(_on_elevator_closed, CONNECT_ONE_SHOT)
	if Game.rourke_fate == "tied":
		await hud.say("", "Behind you, a cut length of network cable lies on the floor. Rourke is gone.", 4.0)
		await hud.line("l1_lockdown_tied")
	if not elevator.is_closing and not elevator.riding:
		hud.todo("Everyone into the elevator, then press B2")


## The doors are shut: this is the checkpoint and the seal. The next wing loads
## during the ride, and the crew steps out of its arrival car.
func _on_elevator_closed() -> void:
	hud.todo("")
	if world:
		db.checkpoint()
	prepare_next()
	var next: Node = world.wings.get("level_2") if world else null
	if next and next.get("arrival_lift") is Elevator:
		elevator.link_to(next.arrival_lift)
	hud.line("l1_sealed")
	await elevator.ride()
	Game.completed_level = "level_1"
	Game.next_level = "level_2"
	if not world:
		player.input_locked = true
		await hud.fade(true, 1.2)
	finish_level("field_notes")


func on_player_died() -> void:
	player.respawn(global_transform * Transform3D(Basis(), Vector3(0, 0.1, 7.0)))
	# Solo, the fight starts over. In co-op he just turns on whoever is closest.
	if sync.is_online():
		return
	if rourke.state == Rourke.State.CHASE or rourke.state == Rourke.State.STAGGER or rourke.state == Rourke.State.DOWN:
		rourke.reset_fight(global_transform * rourke_spawn)
