extends LevelBase
## Level 0: The Lobby. The IT van, Rourke's tour, the shredded memo, the walkie-talkies.
## Teaches SELECT, FROM and ORDER BY. Nothing here should look wrong yet:
## the players think this is an ordinary after-hours IT callout.

signal all_ready

const SEED_PATH := "res://data/level_0.sql"

var rourke: Rourke
var desk_terminal: Terminal
var shutter: Door
var walkies: Interactable
var front_doors: Door
var visitor_log: Interactable
## Players ready up by pressing E on their van door. The co-op layer raises this
## to the number of connected players; solo play starts as soon as one is ready.
var players_needed := 1
## player -> the van seat they climb out of
var ready_players := {}
## Each seat: door pivot, door, how far the door swings, and the climb-out path.
var van_seats: Array[Dictionary] = []
var _intro_started := false
var peek_puzzle := Puzzle.new("peek", "SELECT text FROM memo_fragments", ["text"], false, [
	"Type this, then press Enter:\n" +
	"    [color=#ffffff]SELECT * FROM memo_fragments;[/color]\n" +
	"  SELECT *            which columns to show (* means every column)\n" +
	"  FROM memo_fragments which table to read them from",
	"Type exactly SELECT * FROM memo_fragments; and press Enter. Spelling matters, capitals don't.",
])
var memo_puzzle := Puzzle.new("memo", "SELECT text FROM memo_fragments ORDER BY piece_no", ["text"], true, [
	"Type this, then press Enter:\n" +
	"    [color=#ffffff]SELECT * FROM memo_fragments ORDER BY piece_no;[/color]\n" +
	"  SELECT *            every column\n" +
	"  FROM memo_fragments from the scraps table\n" +
	"  ORDER BY piece_no   sorted by the piece_no column, smallest first",
	"Take the query you just ran and add ORDER BY to the end, then the column to sort by. " +
	"Here that's piece_no, the scrap numbers in the first column. " +
	"So: SELECT * FROM memo_fragments, then ORDER BY piece_no, then the semicolon.",
])


func build() -> void:
	db.load_seed(FileAccess.get_file_as_string(SEED_PATH))
	var carpet := Color(0.22, 0.2, 0.24)
	var wall := Color(0.62, 0.58, 0.5)
	# Lobby: x -8..8, z -7..7
	Greybox.room(geo, Vector3.ZERO, Vector3(16, 4, 14), {"floor": carpet, "wall": wall}, [
		{"wall": "e", "at": 3.0, "width": 2.0, "height": 3.0},
		{"wall": "s", "at": 0.0, "width": 3.2, "height": 2.6},
		{"wall": "w", "at": 4.0, "width": 0.9, "height": 1.05, "bottom": 0.1},
	])
	Greybox.label(geo, Vector3(0, 3.0, -6.88), "HALCYON DATA SYSTEMS", 160, Color(0.15, 0.2, 0.35))
	Greybox.label(geo, Vector3(0, 2.55, -6.88), "Data you can trust.", 64, Color(0.25, 0.25, 0.3))
	# Front doors: Rourke lets the crew in, then they lock behind them.
	front_doors = Door.create(self, "FRONT-DOORS", Vector3(0, 1.3, 6.95), Vector3(3.2, 2.6, 0.12), Color(0.25, 0.35, 0.4))
	front_doors.slide_axis = Vector3.RIGHT
	doors["FRONT-DOORS"] = front_doors
	Greybox.label(geo, Vector3(0, 2.8, 6.85), "EXIT", 72, Color(0.8, 0.15, 0.1), 180)

	# Reception desk with side partitions: the only way behind it is over the desk.
	Greybox.box(geo, Vector3(0, 0.55, -1.0), Vector3(10, 1.1, 0.8), Color(0.42, 0.3, 0.22), "Desk")
	Greybox.box(geo, Vector3(-5.0, 1.1, -4.2), Vector3(0.15, 2.2, 5.6), Color(0.5, 0.55, 0.6), "PartitionW")
	Greybox.box(geo, Vector3(5.0, 1.1, -4.2), Vector3(0.15, 2.2, 5.6), Color(0.5, 0.55, 0.6), "PartitionE")
	Greybox.label(geo, Vector3(0, 1.3, -0.58), "RECEPTION", 64, Color(0.85, 0.8, 0.6))
	desk_terminal = Terminal.spawn(geo, Vector3(1.5, 1.1, -1.0), 0, "FRONT DESK", db, terminal_ui)
	desk_terminal.boot_lines = [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  FRONT DESK",
		"Visitor session opened 23:04.",
		"",
		"Shredded documents are scanned into the table [b]memo_fragments[/b].",
		"To see every row of a table, type this and press Enter:",
		"",
		"    [color=#ffffff]SELECT * FROM memo_fragments;[/color]",
		"",
		"Type .help for commands, .hint if you're stuck.",
	]
	desk_terminal.puzzles = [peek_puzzle, memo_puzzle]
	desk_terminal.enabled = false
	desk_terminal.queried.connect(_on_desk_query)
	Greybox.label(geo, Vector3(1.86, 1.2, -0.76), "ORDER matters.\n  - I.", 30, Color(0.1, 0.1, 0.4), 0)
	Greybox.panel(geo, Vector3(1.86, 1.2, -0.78), Vector3(0.16, 0.16, 0.01), Color(0.95, 0.9, 0.4))
	visitor_log = Interactable.create(geo, Vector3(-1.5, 1.13, -0.8), Vector3(0.35, 0.05, 0.26), "Sign the visitor log", Color(0.92, 0.9, 0.82))
	Greybox.label(geo, Vector3(-1.5, 1.2, -0.66), "VISITOR LOG", 24, Color(0.15, 0.15, 0.2), 0)
	visitor_log.enabled = false

	# Lost & found behind the desk.
	Greybox.box(geo, Vector3(-2.5, 0.35, -5.5), Vector3(1.2, 0.7, 0.8), Color(0.45, 0.35, 0.2), "LostFound")
	Greybox.label(geo, Vector3(-2.5, 0.85, -5.08), "LOST & FOUND", 40, Color(0.1, 0.1, 0.1))
	walkies = Interactable.create(geo, Vector3(-2.5, 0.8, -5.5), Vector3(0.5, 0.2, 0.3), "Take walkie-talkies", Color(0.1, 0.1, 0.1))
	walkies.enabled = false
	walkies.used.connect(_on_walkies)

	# Waiting area chairs (cover, atmosphere)
	for x in [-6.0, -4.8, 4.8, 6.0]:
		Greybox.box(geo, Vector3(x, 0.25, 4.5), Vector3(0.9, 0.5, 0.9), Color(0.3, 0.12, 0.12), "Chair")
	Greybox.box(geo, Vector3(-5.4, 0.2, 2.8), Vector3(2.0, 0.4, 0.8), Color(0.35, 0.28, 0.2), "Table")

	# East hall to Server Room A: x 8..24, z 2..4
	Greybox.room(geo, Vector3(16, 0, 3), Vector3(16, 3, 2), {"floor": Color(0.3, 0.3, 0.3), "wall": wall}, [
		{"wall": "w", "at": 0.0, "width": 2.0, "height": 3.0},
	])
	Greybox.label(geo, Vector3(23.85, 2.4, 3), "SERVER ROOM A  >", 64, Color(0.7, 0.1, 0.1), -90)
	shutter = add_door("LOBBY-SHUTTER", Vector3(11, 1.5, 3), Vector3(0.15, 3.0, 2.0))
	var serverroom_door := add_door("SRA-ENTRY", Vector3(23.9, 1.2, 3), Vector3(0.15, 2.4, 1.8))
	serverroom_door.set_open(false, true)

	# The vent in the west wall leads to a forgotten storage closet: x -14..-8, z 3.5..4.5 duct
	Greybox.box(geo, Vector3(-11, 0.05, 4), Vector3(6, 0.1, 1.0), Color(0.5, 0.5, 0.52), "VentFloor")
	Greybox.box(geo, Vector3(-11, 1.1, 4), Vector3(6, 0.1, 1.0), Color(0.5, 0.5, 0.52), "VentTop")
	Greybox.box(geo, Vector3(-11, 0.6, 3.45), Vector3(6, 1.2, 0.1), Color(0.5, 0.5, 0.52), "VentSideN")
	Greybox.box(geo, Vector3(-11, 0.6, 4.55), Vector3(6, 1.2, 0.1), Color(0.5, 0.5, 0.52), "VentSideS")
	Greybox.label(geo, Vector3(-7.88, 1.25, 4), "AIR RETURN", 30, Color(0.2, 0.2, 0.2), 90)
	Greybox.room(geo, Vector3(-17, 0, 4), Vector3(6, 2.6, 6), {"floor": Color(0.2, 0.2, 0.2), "wall": Color(0.4, 0.38, 0.33)}, [
		{"wall": "e", "at": 0.0, "width": 0.9, "height": 1.05, "bottom": 0.1},
	])
	Greybox.box(geo, Vector3(-19.5, 0.9, 4), Vector3(0.8, 1.8, 3), Color(0.35, 0.35, 0.35), "Shelf")
	Greybox.label(geo, Vector3(-19.05, 1.4, 4),
		"THE HALCYON LEDGER - March 1994\nFOUNDER OUSTED OVER 'WARDEN' PLAN\nHarold Mercer, who built Halcyon from a garage,\nwas removed by the board after refusing to let an\nautomated system run the campus. 'You don't hand\nthe keys to something that can't be locked out,'\nhe told staff on his last day.",
		26, Color(0.9, 0.88, 0.8), 90)
	var closet_light := Greybox.ceiling_light(geo, Vector3(-17, 2.6, 4), 5.0, 0.9)
	FlickerLight.attach(closet_light, 0.35)

	# Lights. An ordinary, well-lit office lobby: every tube works, nothing flickers.
	# The first thing that looks wrong should be Rourke himself, in Server Room A.
	environment.ambient_light_energy = 0.3
	environment.fog_density = 0.01
	var office := Color(1.0, 0.95, 0.86)
	for p in [Vector3(-4, 4, -4), Vector3(4, 4, -4), Vector3(-4, 4, 1.5), Vector3(4, 4, 1.5), Vector3(-4, 4, 5), Vector3(4, 4, 5)]:
		add_light("lobby", p, 9.0, 1.4, office)
	add_light("hall", Vector3(13, 3, 3), 6.0, 1.1, office)
	add_light("hall", Vector3(20, 3, 3), 6.0, 1.1, office)

	_build_parking_lot()
	_build_van(Vector3(2, 0, 16.6))

	rourke = Rourke.new()
	rourke.name = "Rourke"
	add_child(rourke)
	rourke.position = Vector3(0, 0, 4.8)
	spawn = Transform3D(Basis(), Vector3(2.5, 0.55, 15.3))  # passenger seat of the van


## The car park in front of the building, at night.
func _build_parking_lot() -> void:
	var asphalt := Color(0.12, 0.12, 0.13)
	var facade := Color(0.5, 0.48, 0.44)
	# Lot: x -20..24, z 7..28, fenced on three sides; the building closes the fourth.
	Greybox.box(geo, Vector3(2, -0.1, 17.5), Vector3(44, 0.2, 21), asphalt, "Asphalt")
	Greybox.box(geo, Vector3(-20, 1.5, 17.5), Vector3(0.2, 3, 21), Color(0.2, 0.22, 0.2), "FenceW")
	Greybox.box(geo, Vector3(24, 1.5, 17.5), Vector3(0.2, 3, 21), Color(0.2, 0.22, 0.2), "FenceE")
	Greybox.box(geo, Vector3(2, 1.5, 28), Vector3(44, 3, 0.2), Color(0.2, 0.22, 0.2), "FenceS")
	# Building front, with a gap for the doors and a canopy over them.
	Greybox.box(geo, Vector3(-10.8, 3, 7.25), Vector3(18.4, 6, 0.3), facade, "Facade")
	Greybox.box(geo, Vector3(12.8, 3, 7.25), Vector3(22.4, 6, 0.3), facade, "Facade")
	Greybox.box(geo, Vector3(0, 4.3, 7.25), Vector3(3.2, 3.4, 0.3), facade, "Facade")
	Greybox.box(geo, Vector3(0, 3.0, 8.5), Vector3(5, 0.2, 2.2), Color(0.3, 0.3, 0.32), "Canopy")
	Greybox.label(geo, Vector3(0, 4.9, 7.42), "HALCYON DATA SYSTEMS", 200, Color(0.75, 0.8, 0.9))
	Greybox.label(geo, Vector3(3.2, 1.6, 7.42), "Visitors after 18:00:\nplease wait for your escort.", 36, Color(0.9, 0.9, 0.85))
	var porch := Greybox.ceiling_light(geo, Vector3(0, 2.9, 8.5), 7.0, 1.2, Color(1.0, 0.95, 0.86))
	porch.name = "PorchLight"
	# Painted bays and two sodium lamps.
	for x in [-6.0, -2.0, 6.0, 10.0]:
		Greybox.panel(geo, Vector3(x, 0.01, 16.6), Vector3(0.12, 0.01, 5), Color(0.8, 0.8, 0.7))
	Greybox.panel(geo, Vector3(2, 0.01, 8.6), Vector3(44, 0.01, 2.6), Color(0.35, 0.35, 0.34))  # sidewalk
	for x in [-8.0, 12.0]:
		Greybox.box(geo, Vector3(x, 2.5, 20), Vector3(0.2, 5, 0.2), Color(0.25, 0.25, 0.25), "LampPost")
		Greybox.panel(geo, Vector3(x, 5.0, 20), Vector3(0.8, 0.12, 0.4), Color(1.0, 0.75, 0.45), 3.0)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 4.7, 20)
		lamp.omni_range = 14.0
		lamp.light_energy = 1.3
		lamp.light_color = Color(1.0, 0.72, 0.42)
		geo.add_child(lamp)


## The crew's IT van, nose to the building. Each seat has its own door; pressing E on
## your door readies you up. center is the middle of the van at ground level.
func _build_van(center: Vector3) -> void:
	var white := Color(0.86, 0.86, 0.83)
	var floor_y := center.y + 0.5
	var cab := Vector3(center.x, floor_y, center.z)
	# Body: a hollow box you can stand in. x center±1.1, z center±2.1.
	Greybox.room(geo, cab, Vector3(2.2, 2.1, 4.2), {"floor": Color(0.2, 0.2, 0.22), "wall": white, "ceiling": white}, [
		{"wall": "n", "at": 0.0, "width": 1.9, "height": 1.95, "bottom": 0.85},  # windscreen
		{"wall": "w", "at": -1.5, "width": 0.9, "height": 1.9},  # driver door
		{"wall": "e", "at": -1.5, "width": 0.9, "height": 1.9},  # passenger door
	])
	Greybox.box(geo, center + Vector3(0, 0.2, 0), Vector3(2.3, 0.2, 4.5), Color(0.15, 0.15, 0.15), "Chassis")
	Greybox.box(geo, center + Vector3(0, 0.95, -2.55), Vector3(2.2, 0.9, 0.9), white, "Bonnet")
	for dx in [-1.0, 1.0]:
		for dz in [-1.6, 1.4]:
			Greybox.box(geo, center + Vector3(dx * 1.05, 0.25, dz), Vector3(0.3, 0.5, 0.7), Color(0.05, 0.05, 0.05), "Wheel")
	for side in [-1.0, 1.0]:
		Greybox.label(geo, center + Vector3(1.22 * side, 1.7, 0.6), "BYTE-RIGHT IT SERVICES\nWe fix what's broken.", 60, Color(0.1, 0.3, 0.6), 90.0 * side)
	# Inside: seats, dashboard, the job ticket, a dome light.
	for dx in [-0.55, 0.55]:
		Greybox.panel(geo, cab + Vector3(dx, 0.25, -1.3), Vector3(0.6, 0.5, 0.55), Color(0.15, 0.15, 0.18))
	Greybox.panel(geo, cab + Vector3(0, 0.75, -1.95), Vector3(2.0, 0.2, 0.3), Color(0.12, 0.12, 0.13))
	Greybox.box(geo, cab + Vector3(0.6, 0.6, 1.5), Vector3(0.8, 1.2, 0.8), Color(0.3, 0.3, 0.32), "Rack")
	Greybox.label(geo, cab + Vector3(0.6, 0.9, 1.09),
		"JOB TICKET #4471\nHalcyon Data Systems\nAfter-hours callout, 23:00\nRecover lead engineer's systems.\nContact: D. Rourke, facilities.", 22, Color(0.95, 0.95, 0.9), 180)
	var dome := OmniLight3D.new()
	dome.position = cab + Vector3(0, 1.9, 0)
	dome.omni_range = 3.0
	dome.light_energy = 0.6
	dome.light_color = Color(1.0, 0.9, 0.7)
	geo.add_child(dome)

	# Doors hinge at their front edge and swing outward.
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = cab + Vector3(1.1 * side, 0, -2.05)
		add_child(pivot)
		var door := Interactable.create(pivot, Vector3(0, 0.95, 0.45), Vector3(0.1, 1.9, 0.9), "Open your door (ready up)", white)
		van_seats.append({
			"pivot": pivot,
			"door": door,
			"swing": deg_to_rad(90.0 * side),
			"inside": Vector3(cab.x + 0.85 * side, floor_y + 0.05, cab.z - 1.5),
			"outside": Vector3(cab.x + 2.1 * side, center.y + 0.05, cab.z - 1.8),
		})
		door.used.connect(ready_up.bind(van_seats.size() - 1))


## A player pressed E on their van door.
func ready_up(p: Node, seat_index: int) -> void:
	if ready_players.has(p) or _intro_started:
		return
	ready_players[p] = seat_index
	van_seats[seat_index].door.enabled = false
	if ready_players.size() >= players_needed:
		_intro_started = true
		all_ready.emit()
	else:
		hud.set_objective("Ready. Waiting for your team (%d/%d)" % [ready_players.size(), players_needed])


## Swing the door open and step down onto the tarmac, facing the building.
func climb_out(p: Player, seat: Dictionary) -> void:
	p.input_locked = true
	p.velocity = Vector3.ZERO
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var face := p.rotation.y + angle_difference(p.rotation.y, 0.0)
	var tw := create_tween()
	tw.tween_property(seat.pivot, "rotation:y", seat.swing, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "global_position", seat.inside, 0.7)
	tw.parallel().tween_property(p.head, "rotation:x", 0.0, 0.7)
	tw.tween_property(p, "global_position", seat.outside, 0.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(p, "rotation:y", face, 0.8)
	tw.tween_property(seat.pivot, "rotation:y", 0.0, 0.4).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	p.process_mode = Node.PROCESS_MODE_INHERIT
	p.input_locked = false


func start() -> void:
	player.flashlight.visible = false  # the lights are on; nobody needs a torch yet
	hud.set_objective("Press E on your van door when you're ready")
	_dispatch_chatter()
	await all_ready
	for p in ready_players:
		climb_out(p, van_seats[ready_players[p]])
	await get_tree().create_timer(2.0).timeout
	hud.set_objective("Meet your contact at the front doors")
	var approach := Trigger.create(self, Vector3(0, 1, 11.5), Vector3(16, 2, 2))
	await approach.entered

	front_doors.set_open(true)
	rourke.walk_to(Vector3(0, 0, 8.8))
	await rourke.arrived
	rourke.face(player.global_position)
	await hud.play_lines([
		["ROURKE", "You must be the IT crew. Dale Rourke, facilities. I'll be your escort tonight."],
		["ROURKE", "Badge rules after hours. You don't go anywhere I don't take you. Come on in, I'll sign you in."],
	])
	var inside := Trigger.create(self, Vector3(0, 1, 4.5), Vector3(10, 2, 2))
	rourke.walk_to(Vector3(-0.5, 0, 0.6))
	hud.set_objective("Follow Rourke to the front desk")
	await inside.entered
	front_doors.set_open(false)
	spawn = Transform3D(Basis(), Vector3(0, 0.1, 5.6))
	if rourke.state == Rourke.State.WALK:
		await rourke.arrived
	rourke.face(player.global_position)
	await hud.say("ROURKE", "Doors lock themselves after hours. Don't worry, I've got the badge. Sign the visitor log for me.")
	visitor_log.enabled = true
	hud.set_objective("Sign the visitor log on the front desk")
	await visitor_log.used
	visitor_log.enabled = false
	hud.notice("Signed in: BYTE-RIGHT IT SERVICES, 23:04", 4.0)
	hud.set_objective("")
	await hud.play_lines([
		["ROURKE", "Here's the job. Dr. Vale, our lead engineer, went missing three nights ago."],
		["ROURKE", "Her systems are a mess and the director wants them recovered by morning. Quietly."],
		["ROURKE", "Fun fact: the man who founded this place, Harold Mercer, hated computers running buildings."],
		["ROURKE", "Board fired him when they installed WARDEN. That's the AI that runs the campus now."],
		["ROURKE", "Old-timers say Mercer built himself a safe room somewhere in here. Off the grid. Unhackable."],
		["ROURKE", "Ghost stories. Anyway."],
	])
	rourke.face(player.global_position)
	await hud.say("ROURKE", "The front desk scanner ate one of Vale's memos. The scraps went into a table. Director wants to know what it said. Go ahead, terminal's on the desk.")
	desk_terminal.enabled = true
	hud.set_objective("Read Dr. Vale's shredded memo at the front desk terminal")


## The van radio, until the crew is ready.
func _dispatch_chatter() -> void:
	for line in [
		["DISPATCH", "Van three, you're on site at Halcyon Data Systems. After-hours callout."],
		["DISPATCH", "Their lead engineer's systems are down. Contact is Dale Rourke, facilities. He'll meet you at the front doors."],
		["DISPATCH", "Hop out when you're ready. Dispatch out."],
	]:
		if _intro_started:
			return
		await hud.say(line[0], line[1])


func _on_desk_query(_sql: String, result: Dictionary, ui: TerminalUI) -> void:
	if not peek_puzzle.solved and peek_puzzle.matches(db, result):
		peek_puzzle.solved = true
		ui.print_line("")
		ui.print_line("[color=#e0b050]WARDEN: Those scraps are out of order. Each one has a number in the piece_no column.[/color]")
		ui.print_line("[color=#e0b050]        To sort them, add ORDER BY to the end of your query, then the column to sort by: piece_no[/color]")
		hud.set_objective("Put the memo back in order")
	if not memo_puzzle.solved and memo_puzzle.matches(db, result):
		memo_puzzle.solved = true
		peek_puzzle.solved = true
		ui.print_line("")
		ui.print_line("[color=#ffcc66]-- RECONSTRUCTED --[/color]")
		for row in db.run_silent("SELECT text FROM memo_fragments ORDER BY piece_no"):
			ui.print_line("[color=#ffcc66]%s[/color]" % row["text"])
		_after_memo()


func _after_memo() -> void:
	hud.set_objective("")
	await get_tree().create_timer(1.5).timeout
	await hud.play_lines([
		["ROURKE", "...Huh. She always was dramatic."],
		["ROURKE", "Grab the walkie-talkies from lost and found behind the desk. Over the counter, it's fine."],
	])
	walkies.enabled = true
	hud.set_objective("Get the walkie-talkies (behind the desk. Space to climb over)")


func _on_walkies(_p: Node) -> void:
	walkies.queue_free()
	Game.has_walkie = true
	hud.notice("Picked up walkie-talkies. Channel 1. (Co-op radio arrives in the next build.)", 5.0)
	hud.set_objective("Follow Rourke to Server Room A")
	rourke.walk_to(Vector3(10.2, 0, 3))
	await rourke.arrived
	rourke.face(player.global_position)
	# Rourke badges the shutter. It jams halfway.
	var tw := create_tween()
	tw.tween_property(shutter, "position:y", shutter.position.y + 2.1, 1.6).set_trans(Tween.TRANS_BOUNCE)
	await hud.say("ROURKE", "Jammed again. You'll have to duck under. Hold Ctrl, or sprint and slide.")
	await hud.say("ROURKE", "I'll take the staff door and meet you at the server room.")
	rourke.visible = false
	rourke.process_mode = Node.PROCESS_MODE_DISABLED
	rourke.position = Vector3(22.5, 0, 3)
	var t := Trigger.create(self, Vector3(21.5, 1, 3), Vector3(1.5, 2, 2))
	t.entered.connect(_on_reach_server_room)


func _on_reach_server_room(_b: Node) -> void:
	rourke.visible = true
	rourke.process_mode = Node.PROCESS_MODE_INHERIT
	rourke.face(player.global_position)
	doors["SRA-ENTRY"].set_open(true)
	await hud.say("ROURKE", "Server Room A. After you.")
	player.input_locked = true
	await hud.fade(true, 1.0)
	Game.goto("level_1")
