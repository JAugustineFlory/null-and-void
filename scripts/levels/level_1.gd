extends LevelBase
## Level 1: the server floor. No threat: the crew's real job, done safely. Rourke
## asks them to find the door controller that keeps faulting (WHERE and AND on
## door_controllers) and reset it at its rack, which puts the floor's doors and
## elevator back in service. The controller's log points at Dr. Vale's lab, and
## Rourke rides up with the crew to see it.

var rourke: Rourke
var terminal: Terminal
var answer := ""
var rack_panels := {}
var panels_locked_until := 0.0
## Rourke has asked the crew to find the fault: the terminal and the racks work.
var asked := false
var controller_puzzle := Puzzle.new("controller",
	"SELECT id FROM door_controllers WHERE zone = 'A' AND status = 'fault'", ["id"], false, [
	"Type this, then press Enter:\n" +
	"    [color=#ffffff]SELECT * FROM door_controllers WHERE zone = 'A' AND status = 'fault';[/color]\n" +
	"  SELECT *              show every column\n" +
	"  FROM door_controllers from the table of door controllers\n" +
	"  WHERE zone = 'A'      keep only the rows in zone A (this floor's zone)\n" +
	"  AND status = 'fault'  ...that are ALSO faulted. Both must be true.",
	"The id your query returns is the one controller to reset. Every rack in Server Room A has its id " +
	"(DC-1 to DC-8) on the end facing the center aisle. Press E on that rack's panel. " +
	"Other faulted or offline controllers belong to other doors or are off on purpose: read their note column.",
])
## The way up to Level 2. Out of service until the controller is reset.
var elevator: Elevator
## Where the crew arrives from the ground floor (in the World).
var arrival_lift: Elevator
## Server Room C stays shut while its zone-A lock is faulted.
var room_c_door: Door
## The spare coil of network cable in the cable vault.
var cable_coil: Interactable
## Who carries cable up to Level 2: peer id -> true, the same on every machine.
var cable_holders := {}

const ROURKE_IN_LIFT := Vector3(-0.75, 0, 1.6)  # across the car from the buttons
const RESPAWN := Vector3(0, 0.1, 11.0)
## Seconds after Rourke's ask before he tells a slow crew to take their time.
const WAITING_AFTER := 60.0


func build() -> void:
	var data := Level1Data.build(Game.run_seed)
	answer = data.answer
	load_level_seed(data.sql)

	var floor_c := Color(0.32, 0.33, 0.35)
	var wall_c := Color(0.5, 0.52, 0.55)
	var office := Color(0.95, 0.93, 0.85)
	var c := {"floor": floor_c, "wall": wall_c}
	var machine := {"floor": floor_c, "wall": wall_c, "ceiling": Color(0.4, 0.4, 0.42)}
	var door := {"width": 1.4, "height": 2.2}
	# Server Room A, the middle of the floor: x -7..7, z -9..9.
	Greybox.room(geo, Vector3.ZERO, Vector3(14, 3.6, 18), machine, [
		{"wall": "s", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4},
	])
	# South corridor: x -22..22, z 9..13. The ground floor's elevator arrives here.
	var south_gaps := [
		{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4},  # Server Room A
		_gap("n", -14.5, door), _gap("n", 14.5, door),  # NOC, Server Room B
	]
	if world:
		south_gaps.append({"wall": "s", "at": 0.0, "width": Elevator.DOORWAY, "height": Elevator.DOOR_H})
	Greybox.room(geo, Vector3(0, 0, 11), Vector3(44, 3, 4), c, south_gaps)
	if world:
		# The ground floor's elevator links to this car and opens it at the end of the ride.
		arrival_lift = Elevator.create(self, geo, Vector3(0, 0, 13), 0, "1", ["G", "1", "2"])
		arrival_lift.name = "ArrivalElevator"
		arrival_lift.button.enabled = false
	# North corridor: x -22..22, z -13..-9. The elevator up, and Server Room C.
	Greybox.room(geo, Vector3(0, 0, -11), Vector3(44, 3, 4), c, [
		{"wall": "s", "at": 0.0, "width": 1.8, "height": 2.4},  # Server Room A's rear door
		_gap("s", -12.0, door), _gap("s", 12.0, door),  # cable vault, break room
		_gap("n", -12.0, door),  # Server Room C
		{"wall": "n", "at": 0.0, "width": Elevator.DOORWAY, "height": Elevator.DOOR_H},
	])
	elevator = Elevator.create(self, geo, Vector3(0, 0, -13), 180, "1", ["G", "1", "2"])
	elevator.button.enabled = false
	for x in [-16.0, -6.0, 6.0, 16.0]:
		add_light("corridor", Vector3(x, 3, 11), 7.0, 1.0, office)
		var l := add_light("corridor", Vector3(x, 3, -11), 7.0, 0.9, office)
		if x == 6.0:
			FlickerLight.attach(l, 0.3)
	add_door("SRA-ENTRY", Vector3(0, 1.2, 9), Vector3(1.8, 2.4, 0.15)).slide_axis = Vector3.UP
	add_door("SRA-EXIT", Vector3(0, 1.2, -9), Vector3(1.8, 2.4, 0.15))
	Greybox.label(geo, Vector3(0, 2.75, 9.12), "SERVER ROOM A", 48, Color(0.15, 0.15, 0.2))
	Greybox.label(geo, Vector3(0, 2.75, -9.12), "SERVER ROOM A", 48, Color(0.15, 0.15, 0.2), 180)
	_build_floor(c, machine, office)

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

	# Terminal desk by the entrance, facing into the room. Rourke's maintenance
	# session opens once he has asked the crew to look.
	Greybox.box(geo, Vector3(-4.5, 0.45, 8.4), Vector3(2.2, 0.9, 0.8), Color(0.4, 0.38, 0.35), "TermDesk")
	terminal = Terminal.spawn(geo, Vector3(-4.5, 0.9, 8.4), 180, "SERVER ROOM A", db, terminal_ui)
	terminal.puzzles = [controller_puzzle]
	terminal.boot_lines = _self_test_lines()
	terminal.locked = true
	terminal.locked_message = "MAINTENANCE SESSION ROURKE_D: WAITING FOR ESCORT."
	terminal.queried.connect(_on_query)
	StickyNote.on_monitor(terminal, "where_and")
	# The room's laminated reference card, and Mercer's note on what the statuses mean.
	Document.place(geo, Vector3(-5.25, 0.902, 8.35), -5.0, "SERVER ROOM A - DOOR CONTROLLERS", [
		"Each rack drives one door lock. Rack ids DC-1 to DC-8 are on the aisle end.",
		{"before": "Every controller is listed in the table ", "filled": "door_controllers", "after": "."},
		"Columns: id, zone, status, location, last_reset, note",
		"This floor's doors and elevator are in zone A.",
		"Faulted lock? Reset it at its own rack. Never reset a healthy one.",
	], true, "laminated", Vector2(0.21, 0.15))
	Document.place(geo, Vector3(-3.55, 0.902, 8.3), 10.0, "Reminders", [
		{"text": "status 'fault' = the lock relay is stuck. Needs a hand reset at the rack.", "hand": true, "author": "mercer"},
		{"text": "status 'offline' = someone switched it off on purpose. Leave it alone.", "hand": true, "author": "mercer"},
		{"text": "Zone first, then status. Plenty of faults in this building aren't yours.", "hand": true, "author": "mercer"},
		{"text": "- H.M.", "hand": true, "author": "mercer"},
	], true, "note", Vector2(0.1, 0.14))

	for p in [Vector3(0, 3.6, -7), Vector3(0, 3.6, -1.5), Vector3(0, 3.6, 4.5), Vector3(-6, 3.6, 8), Vector3(6, 3.6, -8)]:
		add_light("room", p, 9.0, 1.2)

	rourke = Rourke.new()
	rourke.name = "Rourke"
	rourke.position = Vector3(-2.4, 0, 6.4)
	# In the World the ground floor's Rourke rides up with the crew and this one takes
	# his place (start()); until then he mustn't be seen standing in the room.
	rourke.visible = world == null
	add_child(rourke)
	spawn = Transform3D(Basis(), RESPAWN)
	DressLevel1.apply(self)  # furniture and materials (Graphics thread)


func _gap(wall: String, at: float, size: Dictionary) -> Dictionary:
	return {"wall": wall, "at": at, "width": size.width, "height": size.height}


## The rest of the floor, a loop around Server Room A: the network operations room
## and the cable vault to the west, Server Room B and the break room to the east,
## and Server Room C behind a zone-A lock off the north corridor.
func _build_floor(c: Dictionary, machine: Dictionary, office: Color) -> void:
	var door := {"width": 1.4, "height": 2.2}
	var sign_c := Color(0.15, 0.15, 0.2)
	var desk_c := Color(0.42, 0.4, 0.37)
	var rack_c := Color(0.12, 0.12, 0.14)

	# Network operations room (NOC): x -22..-8, z -3..9. Desks facing a wall of status screens.
	Greybox.room(geo, Vector3(-15, 0, 3), Vector3(14, 3, 12), c, [_gap("s", 0.5, door), _gap("n", 3.0, door)])
	add_door("NOC", Vector3(-14.5, 1.1, 9.0), Vector3(1.35, 2.2, 0.08)).make_hinged(Vector3(-0.675, 0, 0), 90.0)
	Greybox.label(geo, Vector3(-14.5, 2.45, 9.12), "NETWORK OPERATIONS", 36, sign_c)
	Greybox.box(geo, Vector3(-18.5, 1.6, -2.85), Vector3(6.6, 2.0, 0.1), Color(0.08, 0.09, 0.1), "StatusWall")
	for i in 3:
		Greybox.panel(geo, Vector3(-20.6 + i * 2.1, 1.7, -2.78), Vector3(1.7, 1.0, 0.02), Color(0.15, 0.45, 0.6), 1.5)
	for row in [1.0, 4.5]:
		Greybox.box(geo, Vector3(-15, 0.38, row), Vector3(8, 0.76, 1.0), desk_c, "NocDesk")
		for x in [-18.0, -15.0, -12.0]:
			Greybox.panel(geo, Vector3(x, 1.0, row - 0.3), Vector3(0.6, 0.4, 0.04), Color(0.2, 0.7, 0.4), 1.2)
	Document.place(geo, Vector3(-15, 0.762, 4.6), 180.0, "NOC SHIFT LOG", [
		"22:40  Server floor doors sticking again. Lift 1 out of service.",
		"22:41  Facilities (Rourke) informed. Contractor called out.",
		"22:55  Records Archive and Cold Lab faults: not ours, tickets open.",
		{"text": "Contractor: use the terminal in Server Room A.", "hand": true},
	], true, "paper")
	for x in [-18.0, -12.0]:
		add_light("noc", Vector3(x, 3, 3), 7.0, 1.0, office)

	# Cable vault: x -22..-8, z -9..-3. Shelves of cable, patch panels, a spare coil.
	Greybox.room(geo, Vector3(-15, 0, -6), Vector3(14, 3, 6), c, [_gap("s", 3.0, door), _gap("n", 3.0, door)])
	add_door("CABLE-VAULT", Vector3(-12.0, 1.1, -9.0), Vector3(1.35, 2.2, 0.08)).make_hinged(Vector3(-0.675, 0, 0), -90.0)
	Greybox.label(geo, Vector3(-12.0, 2.45, -9.12), "CABLE VAULT", 36, sign_c, 180)
	for x in [-20.5, -17.5]:
		Greybox.box(geo, Vector3(x, 1.0, -8.4), Vector3(2.4, 2.0, 0.6), Color(0.35, 0.36, 0.38), "CableShelf")
	Greybox.box(geo, Vector3(-21.6, 1.0, -5.5), Vector3(0.6, 2.0, 3.0), Color(0.35, 0.36, 0.38), "CableShelf")
	Greybox.box(geo, Vector3(-18.5, 0.4, -5.0), Vector3(2.0, 0.8, 1.0), Color(0.3, 0.28, 0.25), "Spool")
	cable_coil = Interactable.create(geo, Vector3(-17.5, 1.25, -8.3), Vector3(0.6, 0.3, 0.5), "Take the coil of network cable", Color(0.15, 0.3, 0.75))
	cable_coil.used.connect(_on_cable_coil)
	add_light("vault", Vector3(-15, 3, -6), 6.0, 0.7, office)

	# Server Room B: x 8..22, z -3..9. Racks on another zone; nothing to fix here.
	Greybox.room(geo, Vector3(15, 0, 3), Vector3(14, 3.6, 12), machine, [_gap("s", -0.5, door), _gap("n", -3.0, door)])
	add_door("SRB", Vector3(14.5, 1.1, 9.0), Vector3(1.35, 2.2, 0.08)).make_hinged(Vector3(-0.675, 0, 0), 90.0)
	Greybox.label(geo, Vector3(14.5, 2.45, 9.12), "SERVER ROOM B", 36, sign_c)
	for z in [-1.0, 2.0, 5.0]:
		for x in [11.0, 19.0]:
			Greybox.box(geo, Vector3(x, 1.05, z), Vector3(4.0, 2.1, 0.9), rack_c, "RackB")
			for k in 4:
				Greybox.panel(geo, Vector3(x + randf_range(-1.7, 1.7), randf_range(0.3, 1.9), z + 0.46), Vector3(0.04, 0.04, 0.01), Color(0.2, 1.0, 0.3), 3.0)
	for z in [0.0, 6.0]:
		add_light("srb", Vector3(15, 3.6, z), 8.0, 1.0)

	# Break room: x 8..22, z -9..-3. Coffee, a fridge, a table.
	Greybox.room(geo, Vector3(15, 0, -6), Vector3(14, 3, 6), c, [_gap("n", -3.0, door), _gap("s", -3.0, door)])
	add_door("BREAK", Vector3(12.0, 1.1, -9.0), Vector3(1.35, 2.2, 0.08)).make_hinged(Vector3(-0.675, 0, 0), -90.0)
	Greybox.label(geo, Vector3(12.0, 2.45, -9.12), "BREAK ROOM", 36, sign_c, 180)
	Greybox.box(geo, Vector3(17.5, 0.38, -5.5), Vector3(3.0, 0.76, 1.4), desk_c, "BreakTable")
	Greybox.box(geo, Vector3(21.4, 0.45, -6), Vector3(0.8, 0.9, 4.0), Color(0.55, 0.55, 0.5), "Counter")
	Greybox.box(geo, Vector3(21.3, 0.95, -4.0), Vector3(0.6, 1.9, 0.8), Color(0.85, 0.85, 0.82), "Fridge")
	Greybox.box(geo, Vector3(21.5, 1.15, -7.0), Vector3(0.4, 0.5, 0.4), Color(0.15, 0.15, 0.15), "CoffeeMachine")
	Document.place(geo, Vector3(21.0, 0.902, -6.0), 90.0, "Coffee fund", [
		{"text": "Coffee fund is EMPTY. You know who you are.", "hand": true},
		{"text": "- night shift", "hand": true},
	], true, "note", Vector2(0.1, 0.1))
	add_light("break", Vector3(15, 3, -6), 6.0, 1.0, office)

	# Server Room C: x -17..-7, z -24..-13. Its lock is on the faulting zone-A controller.
	Greybox.room(geo, Vector3(-12, 0, -18.5), Vector3(10, 3.6, 11), machine, [_gap("s", 0.0, door)])
	room_c_door = add_door("SRC", Vector3(-12.0, 1.1, -13.0), Vector3(1.35, 2.2, 0.08)).make_hinged(Vector3(-0.675, 0, 0), 90.0)
	room_c_door.locked = true
	Greybox.label(geo, Vector3(-12.0, 2.45, -12.88), "SERVER ROOM C", 36, sign_c)
	for x in [-15.0, -9.0]:
		Greybox.box(geo, Vector3(x, 1.05, -19), Vector3(0.9, 2.1, 6.0), rack_c, "RackC")
	Greybox.box(geo, Vector3(-12, 0.38, -23.2), Vector3(2.0, 0.76, 0.8), desk_c, "PrinterDesk")
	# The floor's syslog printer: the night's events, in-world proof of Vale's override.
	Document.place(geo, Vector3(-12, 0.762, -23.1), 180.0, "SYSLOG PRINTOUT", [
		"SERVER FLOOR  -  SYSLOG  -  15 OCT 1997",
		"23:02  LAB B   badge V-0042 (VALE, I.) door open",
		"23:12  ZONE A  manual override by user VALE_I, from SECURE LAB B",
		"23:14  ZONE A  lock relay stuck",
		"23:31  LAB B   door forced",
		"23:31  LAB B   camera feed lost",
	], true, "paper")
	add_light("src", Vector3(-12, 3.6, -18.5), 7.0, 0.8)


func net_setup() -> void:
	sync.replicate(rourke, rourke.sync_properties())


func start() -> void:
	if world:
		# The ground floor's Rourke rode up with the crew: this one takes his place,
		# where he stands in the arrival car.
		var lobby: LevelBase = world.wings.get("level_0")
		var guide = lobby.get("rourke") if lobby else null
		if is_instance_valid(guide):
			rourke.global_transform = guide.global_transform
			guide.queue_free()
		else:
			rourke.global_transform = arrival_lift.global_transform * Transform3D(Basis(), ROURKE_IN_LIFT)
		rourke.visible = true
	hud.todo("Follow Rourke to Server Room A")
	rourke.watch = null
	var led_in := _lead_in()
	if world:
		await hud.line("l0_sra")  # off the elevator, at the server room door
	await hud.line("l1_enter")
	await sync.gate("rourke_at_desk", func():
		if not led_in.finished:
			await led_in.done)
	_watch_nearest()
	await hud.line("l1_terminal")
	_on_asked()


## Rourke has asked: his maintenance session opens on the terminal.
func _on_asked() -> void:
	if asked:
		return
	asked = true
	terminal.locked = false
	if not controller_puzzle.solved:
		hud.todo("Find the door controller that keeps faulting, and reset it")
	if sync.is_host():
		await get_tree().create_timer(WAITING_AFTER, false).timeout
		if not controller_puzzle.solved:
			sync.event("_on_rourke_waiting")


## A while in and still looking: Rourke tells them to take their time.
func _on_rourke_waiting() -> void:
	if not controller_puzzle.solved:
		hud.line("l1_waiting")


## Rourke leads the crew in: out of the car, along the corridor and through Server
## Room A's door, then to the terminal desk. Straight walks between waypoints, so
## he never depends on a navigation path across the wing's seam.
class LeadIn:
	signal done
	var finished := false


func _lead_in() -> LeadIn:
	var lead := LeadIn.new()
	var walk := func():
		for p in [Vector3(0, 0, 13.6), Vector3(0, 0, 11), Vector3(0, 0, 7.8), Vector3(-2.4, 0, 6.4)]:
			if p.z > to_local(rourke.global_position).z + 0.3:
				continue  # already past this one
			rourke.walk_to(to_global(p), true)
			await rourke.arrived
		lead.finished = true
		lead.done.emit()
	walk.call()
	return lead


## Host: Rourke turns to whoever is closest when he talks.
func _watch_nearest() -> void:
	if sync.is_host():
		rourke.watch = players.nearest(rourke.global_position)


func _self_test_lines() -> Array:
	return [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  SERVER ROOM A",
		"Session: ROURKE_D (facilities)  -  maintenance window open until 06:00",
		"",
		"[b]WARDEN SELF-TEST[/b]  23:51:07",
		"  [color=#7dff8c]PASS[/color]  power.main_feed",
		"  [color=#7dff8c]PASS[/color]  hvac.zone_a",
		"  [color=#ff6655]FAIL[/color]  doors.server_room_a.exit    expected: unlocked     got: controller fault (zone A)",
		"  [color=#ff6655]FAIL[/color]  lift.server_floor           expected: in service   got: controller fault (zone A)",
		"  [color=#7dff8c]PASS[/color]  network.uplink",
		"  [color=#ff6655]FAIL[/color]  doors.cold_lab              expected: unlocked     got: controller fault (zone C)",
		"  [color=#7dff8c]PASS[/color]  cameras.lobby",
		"3 failed, 4 passed.",
		"",
		"The faulting controller is one row in the controller table (see the reference card at this desk).",
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
	if not asked or controller_puzzle.solved or not controller_puzzle.matches(db, result):
		return
	sync.event("_on_controller_found")


func _on_controller_found() -> void:
	controller_puzzle.solved = true
	terminal.print_line("")
	terminal.print_line(TerminalUI.sysop("that's the one. %s, zone A, 'fault'. reset it by hand at its rack." % answer))
	hud.todo("Reset the faulted controller at its rack")


## Runs on the host when anyone presses a rack panel. It decides, then
## everyone sees the outcome, so the lockout timer is the same for all.
func _on_panel(_p: Node, id: String) -> void:
	if not asked:
		sync.event("_on_panel_result", [id, "not_yet", 0.0])
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
		"not_yet":
			hud.notice("RESET REFUSED: no maintenance session open.", 2.5, ThemeUtil.RED)
			return
		"locked":
			panels_locked_until = now + seconds
			hud.notice("PANELS LOCKED: tamper lockout, %d s" % int(seconds), 2.0, ThemeUtil.RED)
			return
		"healthy":
			var zone: String = db.run_silent("SELECT zone FROM door_controllers WHERE id = '%s'" % id)[0]["zone"]
			hud.notice("> CONTROLLER %s: ZONE %s, OK. NOTHING TO RESET." % [id, zone], 4.0)
			terminal.print_line(TerminalUI.sysop("%s is healthy. you want the one in zone A with status 'fault'." % id))
			hud.line("l1_wrong_panel", false)
			return
		"wrong":
			var row: Dictionary = db.run_silent("SELECT status, zone, note FROM door_controllers WHERE id = '%s'" % id)[0]
			panels_locked_until = now + seconds
			# The rack's own readout shows why, right where the player made the mistake.
			hud.notice("> %s: ZONE %s, '%s': %s\n> RESET REFUSED. PANELS LOCKED: %d s" % [id, row["zone"], row["status"], row["note"], int(seconds)], 6.0, ThemeUtil.RED)
			terminal.print_line(TerminalUI.sysop("not that one. %s is zone %s, '%s': %s" % [id, row["zone"], row["status"], row["note"]]))
			hud.line("l1_wrong_panel", false)
			return
	_on_reset(id)


## The right rack: the floor's zone-A doors and the elevator come back, and the
## controller's log shows who caused the fault.
func _on_reset(id: String) -> void:
	controller_puzzle.solved = true
	for p in rack_panels.values():
		p.enabled = false
	# The reset wants a badge: Rourke lends his own.
	if sync.is_host():
		var at := to_local(rack_panels[id].global_position)
		rourke.watch = null
		rourke.walk_to(to_global(Vector3(0, 0, 5)), true)
		await rourke.arrived
		rourke.walk_to(to_global(Vector3(signf(at.x) * 1.2, 0, at.z)), true)
	await sync.gate("rourke_badges_in", func():
		if rourke.state == Rourke.State.WALK:
			await rourke.arrived)
	await hud.line("l1_badge_help")
	db.run_silent("UPDATE door_controllers SET status = 'ok', last_reset = '1997-10-15 23:58' WHERE id = '%s'" % id)
	db.run_silent("UPDATE doors SET locked = 0 WHERE id = 'SRA-EXIT'")
	db.sync_world()
	room_c_door.locked = false
	hud.notice("> CONTROLLER %s: RESET OK\n> ZONE A DOORS: OK\n> LIFT 1: IN SERVICE" % id, 4.0, ThemeUtil.GREEN)
	terminal.print_line("")
	for line in _controller_log(id):
		terminal.print_line(line)
	hud.todo("")
	_watch_nearest()
	await hud.lines(["l1_fixed_1", "l1_fixed_2", "l1_pivot_1", "l1_pivot_2", "l1_pivot_3"])
	hud.todo("Follow Rourke to the elevator")
	rourke.watch = null
	await sync.gate("rourke_at_lift", func():
		for p in [Vector3(0, 0, to_local(rourke.global_position).z), Vector3(0, 0, -7.8), Vector3(0, 0, -10.5), Vector3(1.8, 0, -11)]:
			rourke.walk_to(to_global(p), true)
			await rourke.arrived)
	_watch_nearest()
	# The elevator opens once the whole crew is with him in the north corridor.
	var t := Trigger.create(self, Vector3(0, 1, -11), Vector3(8, 2, 4))
	t.require_all = true
	t.waiting.connect(func(n, total): sync.team_notice("Rourke is waiting at the elevator for everyone (%d/%d)" % [n, total]))
	t.entered.connect(func(_b): sync.event("_on_crew_at_lift"), CONNECT_ONE_SHOT)


func _controller_log(id: String) -> Array:
	return [
		"> %s FAULT LOG" % id,
		"  10/13 22:51  RESET            user VALE_I   from SECURE LAB B",
		"  10/14 23:40  RESET            user VALE_I   from SECURE LAB B",
		"  10/15 23:12  RESET            user VALE_I   from SECURE LAB B",
		"  10/15 23:14  LOCK RELAY STUCK",
		"  10/15 23:58  RESET            at rack, badge R-0117 (ROURKE, D.)",
	]


## Everyone is with Rourke: the elevator opens and he steps in first.
func _on_crew_at_lift() -> void:
	elevator.hud = hud
	elevator.open()
	elevator.closed.connect(_on_elevator_closed, CONNECT_ONE_SHOT)
	elevator.button.enabled = true
	prepare_next()
	rourke.watch = null
	await sync.gate("rourke_in_lift", func():
		await get_tree().create_timer(0.6, false).timeout
		rourke.walk_to(elevator.to_global(Vector3(0, 0, 0.6)), true)
		await rourke.arrived
		rourke.walk_to(elevator.to_global(ROURKE_IN_LIFT), true)
		await rourke.arrived)
	_watch_nearest()
	if not elevator.is_closing and not elevator.riding:
		hud.todo("Everyone into the elevator, then press 2")
		hud.line("l1_lift_button")


## Host: someone took the spare cable. Everyone sees it go, and Level 2 knows who has it.
func _on_cable_coil(p: Node) -> void:
	if cable_holders.is_empty():
		sync.event("_on_cable_taken", [players.id_of(p)])


func _on_cable_taken(id: int) -> void:
	cable_holders[id] = true
	cable_coil.enabled = false
	cable_coil.visible = false
	if id == players.id_of(player):
		player.inventory.add("cable")
		hud.notice("You sling the coil of network cable over your shoulder.", 3.0)


## The doors are shut: this is the checkpoint. The next floor loads during the ride,
## and the crew (Rourke too) steps out of its arrival car.
func _on_elevator_closed() -> void:
	hud.todo("")
	if world:
		db.checkpoint()
	prepare_next()
	var next: Node = world.wings.get("level_2") if world else null
	if next and next.get("arrival_lift") is Elevator:
		elevator.link_to(next.arrival_lift)
	await elevator.ride()
	if elevator.destination:
		var into := elevator.destination.global_transform * elevator.global_transform.affine_inverse()
		rourke.global_transform = into * rourke.global_transform
	Game.completed_level = "level_1"
	Game.next_level = "level_2"
	if not world:
		player.input_locked = true
		await hud.fade(true, 1.2)
	finish_level("field_notes")


func on_player_died() -> void:
	player.respawn(global_transform * Transform3D(Basis(), RESPAWN))
