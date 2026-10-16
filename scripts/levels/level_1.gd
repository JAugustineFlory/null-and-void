extends LevelBase
## Level 1: Server Room A. Rourke's betrayal, then WARDEN's self-test.
## Teaches WHERE and AND, and reading test output.

var rourke: Rourke
var terminal: Terminal
var answer := ""
var rack_panels := {}
var panels_locked_until := 0.0
var has_badge := false
var _red := Color(1.0, 0.18, 0.12)
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


func build() -> void:
	var data := Level1Data.build(Game.run_seed)
	answer = data.answer
	db.load_seed(data.sql)

	var floor_c := Color(0.32, 0.33, 0.35)
	var wall_c := Color(0.5, 0.52, 0.55)
	# Server room: x -7..7, z -9..9
	Greybox.room(geo, Vector3.ZERO, Vector3(14, 3.6, 18), {"floor": floor_c, "wall": wall_c, "ceiling": Color(0.4, 0.4, 0.42)}, [
		{"wall": "s", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4},
	])
	# Antechamber (south) and exit corridor (north)
	Greybox.room(geo, Vector3(0, 0, 11.5), Vector3(3, 3, 5), {"floor": floor_c, "wall": wall_c}, [
		{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4},
	])
	Greybox.room(geo, Vector3(0, 0, -12.5), Vector3(3, 3, 7), {"floor": floor_c, "wall": wall_c}, [
		{"wall": "s", "at": 0.0, "width": 1.8, "height": 2.4},
	])
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
	terminal.boot_lines = ["HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  SERVER ROOM A", "Session: ROURKE_D", "Waiting for escort..."]
	terminal.queried.connect(_on_query)

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


func start() -> void:
	rourke.face(player.global_position)
	hud.set_objective("Follow Rourke inside")
	rourke.walk_to(Vector3(0.0, 0, 1.0))
	hud.say("ROURKE", "Vale's last login came from this room. Come on in.")
	var t := Trigger.create(self, Vector3(0, 1, 6.0), Vector3(3.6, 2, 1.5))
	t.entered.connect(_on_trapped)


func _on_trapped(_b: Node) -> void:
	db.run_silent("UPDATE doors SET locked = 1 WHERE id = 'SRA-ENTRY'")
	db.sync_world()
	hud.notice("> DOOR SRA-ENTRY: LOCKED", 3.0, ThemeUtil.RED)
	set_all_lights_color(_red)
	terminal.locked = true
	terminal.locked_message = "SESSION LOCKED BY USER ROURKE_D. ESCORT BADGE REQUIRED."
	terminal.set_screen_color(Color(1.0, 0.25, 0.2))
	rourke.face(player.global_position)
	await hud.play_lines([
		["ROURKE", "Sorry, kid. Nothing personal."],
		["ROURKE", "Director needs someone to blame for Vale. Contractors break in, Vale goes missing... it writes itself."],
	])
	hud.set_objective("Survive. Stop Rourke. (Click to strike)")
	rourke.downed.connect(_on_rourke_downed)
	rourke.resolved.connect(_on_rourke_resolved)
	rourke.start_chase(player)


func _on_rourke_downed() -> void:
	hud.set_objective("He's down. Decide before he gets up.")


func _on_rourke_resolved(fate: String) -> void:
	Game.rourke_fate = fate
	has_badge = true
	hud.notice("You took Rourke's badge (R-0117).", 4.0)
	terminal.locked = false
	terminal.set_screen_color(Color(0.2, 0.9, 0.35))
	terminal.reboot(_self_test_lines())
	set_all_lights_color(Color(0.92, 0.95, 1.0))
	if fate == "killed":
		await hud.say("WARDEN", "ESCORT R-0117: VITAL SIGNAL LOST. INITIATING FACILITY LOCKDOWN.", 4.5)
		set_all_lights_color(_red)
		hud.notice("WARDEN LOCKDOWN ACTIVE", 5.0, ThemeUtil.RED)
	else:
		await hud.play_lines([
			["ROURKE", "You think a bit of cable holds me?"],
			["ROURKE", "WARDEN will eat you alive in here."],
		])
	hud.set_objective("Log in to the terminal with Rourke's badge and find out why the exit is locked")


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
		"The exit's controller is one row in the table [b]door_controllers[/b]. Only it needs a reset.",
		"Clues from the self-test: it is in [b]zone A[/b] and its status is [b]'fault'[/b].",
		"Filter rows with WHERE. Need two conditions? Join them with AND. Example on another table:",
		"    [color=#ffffff]SELECT * FROM doors WHERE zone = 'A' AND locked = 1;[/color]",
		"      SELECT *          which columns to show (* = all)",
		"      FROM doors        which table to read",
		"      WHERE zone = 'A'  keep only rows where this is true",
		"      AND locked = 1    ...and this is true as well",
		"Text values go in 'single quotes'. Stuck? Type [b].hint[/b]",
	]


func _on_query(_sql: String, result: Dictionary, ui: TerminalUI) -> void:
	if controller_puzzle.solved or not controller_puzzle.matches(db, result):
		return
	controller_puzzle.solved = true
	ui.print_line("")
	ui.print_line("[color=#e0b050]WARDEN: Controller %s is faulted in zone A. A manual reset at the rack will clear it.[/color]" % answer)
	hud.set_objective("Reset controller %s at its rack (look for the labels)" % answer)


func _on_panel(_p: Node, id: String) -> void:
	if not has_badge:
		hud.notice("RESET REFUSED: badge required.", 2.5, ThemeUtil.RED)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < panels_locked_until:
		hud.notice("PANELS LOCKED: tamper lockout, %d s" % int(panels_locked_until - now), 2.0, ThemeUtil.RED)
		return
	if id != answer:
		var row: Dictionary = db.run_silent("SELECT status, zone, note FROM door_controllers WHERE id = '%s'" % id)[0]
		if row["status"] == "ok":
			hud.notice("WARDEN: %s is working normally. Nothing to reset." % id, 4.0)
			return
		panels_locked_until = now + 10.0
		hud.notice("WARDEN: %s (zone %s, %s): %s\nNot the exit's controller. Reset refused. Panels locked for 10 s." % [id, row["zone"], row["status"], row["note"]], 6.0, ThemeUtil.RED)
		return
	db.run_silent("UPDATE door_controllers SET status = 'ok', last_reset = '1997-10-15 23:58' WHERE id = '%s'" % id)
	db.run_silent("UPDATE doors SET locked = 0 WHERE id = 'SRA-EXIT'")
	db.sync_world()
	for p in rack_panels.values():
		p.enabled = false
	hud.notice("> CONTROLLER %s: RESET OK\n> DOOR SRA-EXIT: OPENED" % id, 4.0, ThemeUtil.GREEN)
	hud.set_objective("Get out through the emergency exit")
	var t := Trigger.create(self, Vector3(0, 1, -13.5), Vector3(3, 2, 1.5))
	t.entered.connect(_on_exit)


func _on_exit(_b: Node) -> void:
	player.input_locked = true
	if Game.rourke_fate == "tied":
		await hud.say("", "Behind you, a cut length of network cable lies on the floor. Rourke is gone.", 4.0)
		await hud.say("WARDEN", "LOCKDOWN PROTOCOL ENGAGED. AUTHORIZED BY: ROURKE, D.", 4.0)
	else:
		await hud.say("WARDEN", "ALL EXITS SEALED. HAVE A PRODUCTIVE NIGHT.", 4.0)
	await hud.fade(true, 1.2)
	Game.goto("field_notes")


func on_player_died() -> void:
	player.respawn(Transform3D(Basis(), Vector3(0, 0.1, 7.0)))
	if rourke.state == Rourke.State.CHASE or rourke.state == Rourke.State.STAGGER or rourke.state == Rourke.State.DOWN:
		rourke.reset_fight(rourke_spawn)
