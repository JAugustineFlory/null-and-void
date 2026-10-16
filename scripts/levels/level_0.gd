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
## Players ready up by pressing E on their seat-belt buckle. The co-op layer raises this
## to the number of connected players; solo play starts as soon as one is ready.
var players_needed := 1
## player -> the van seat they climb out of
var ready_players := {}
## Each seat: spawn transform, seat-belt buckle, which door it exits by, its handle, and the
## climb-out path in world space.
var van_seats: Array[Dictionary] = []
## Front van doors by side ("w", "e"): hinge pivot and swing angle.
var van_doors := {}
var side_door: Node3D
var _side_door_open := false
## Climbing out of the van and hopping the counter move the camera for the player, but
## the mouse can still look around a little from where it points.
const LOOK_YAW := 0.6
const LOOK_PITCH := 0.4
var _look_player: Player
var _look_offset := Vector2.ZERO
var _look_base := Vector2.ZERO
## The front desk: players sit on it and swing their legs over, staff style.
var counter_hop: Interactable
var _intro_started := false
var tape: Interactable
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
	load_level_seed(FileAccess.get_file_as_string(SEED_PATH))
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
	front_doors = Door.create(self, "LOBBY-FRONT", Vector3(0, 1.3, 6.95), Vector3(3.2, 2.6, 0.12), Color(0.25, 0.35, 0.4))
	front_doors.slide_axis = Vector3.RIGHT
	doors["LOBBY-FRONT"] = front_doors
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
	# The west end of the counter is clear of the log and terminal: that's where you hop it.
	counter_hop = Interactable.create(geo, Vector3(-3.6, 1.1, -1.0), Vector3(2.4, 0.06, 0.8), "Hop over the counter", Color(), false)
	counter_hop.enabled = false
	counter_hop.used.connect(hop_counter)

	# Waiting area chairs (cover, atmosphere)
	for x in [-6.0, -4.8, 4.8, 6.0]:
		Greybox.box(geo, Vector3(x, 0.25, 4.5), Vector3(0.9, 0.5, 0.9), Color(0.3, 0.12, 0.12), "Chair")
	Greybox.box(geo, Vector3(-5.4, 0.2, 2.8), Vector3(2.0, 0.4, 0.8), Color(0.35, 0.28, 0.2), "Table")

	# East hall to Server Room A: x 8..24, z 2..4
	Greybox.room(geo, Vector3(16, 0, 3), Vector3(16, 3, 2), {"floor": Color(0.3, 0.3, 0.3), "wall": wall}, [
		{"wall": "w", "at": 0.0, "width": 2.0, "height": 3.0},
		{"wall": "e", "at": 0.0, "width": 1.8, "height": 2.4},  # into Server Room A's antechamber
	])
	Greybox.label(geo, Vector3(23.85, 2.4, 3), "SERVER ROOM A  >", 64, Color(0.7, 0.1, 0.1), -90)
	shutter = add_door("LOBBY-SHUTTER", Vector3(11, 1.5, 3), Vector3(0.15, 3.0, 2.0))
	exit_door = add_door("LOBBY-HALL-END", Vector3(23.9, 1.2, 3), Vector3(0.15, 2.4, 1.8))

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
	tape = Interactable.create(geo, Vector3(-19.3, 1.88, 5.0), Vector3(0.3, 0.12, 0.2), "Play the cassette", Color(0.12, 0.12, 0.12))
	tape.used.connect(_on_tape)
	var closet_light := Greybox.ceiling_light(geo, Vector3(-17, 2.6, 4), 5.0, 0.9)
	FlickerLight.attach(closet_light, 0.35)

	# Lights. An ordinary, well-lit office lobby: every tube works, nothing flickers.
	# The first thing that looks wrong should be Rourke himself, in Server Room A.
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
	spawn = Transform3D(Basis(), Vector3(2.55, 0.55, 15.3))  # passenger seat of the van


## Brighter and clearer than the rest of the building: nothing looks wrong yet.
func apply_environment(env: Environment) -> void:
	env.ambient_light_energy = 0.3
	env.fog_density = 0.01


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


## The crew's IT van, nose to the building. It seats six: two in front and a bench
## of four in the back. Each player readies up by pressing E on their own seat-belt
## buckle; front-seat players climb out of their front door, the rest out of the
## sliding side door. `center` is the middle of the van at ground level.
func _build_van(center: Vector3) -> void:
	var white := Color(0.86, 0.86, 0.83)
	var floor_y := center.y + 0.5
	var cab := Vector3(center.x, floor_y, center.z)
	# Body: a hollow box you can stand in. x center±1.3, z center±2.2.
	Greybox.room(geo, cab, Vector3(2.6, 2.1, 4.4), {"floor": Color(0.2, 0.2, 0.22), "wall": white, "ceiling": white}, [
		{"wall": "n", "at": 0.0, "width": 2.3, "height": 1.95, "bottom": 0.85},  # windscreen
		{"wall": "w", "at": -1.5, "width": 0.9, "height": 1.9},  # driver door
		{"wall": "e", "at": -1.5, "width": 0.9, "height": 1.9},  # passenger door
		{"wall": "e", "at": 0.1, "width": 1.3, "height": 1.9},  # sliding side door
	])
	Greybox.box(geo, center + Vector3(0, 0.2, 0), Vector3(2.7, 0.2, 4.7), Color(0.15, 0.15, 0.15), "Chassis")
	Greybox.box(geo, center + Vector3(0, 0.95, -2.65), Vector3(2.6, 0.9, 0.9), white, "Bonnet")
	for dx in [-1.0, 1.0]:
		for dz in [-1.7, 1.5]:
			Greybox.box(geo, center + Vector3(dx * 1.15, 0.25, dz), Vector3(0.3, 0.5, 0.7), Color(0.05, 0.05, 0.05), "Wheel")
	Greybox.label(geo, center + Vector3(-1.42, 1.7, 0.4), "BYTE-RIGHT IT SERVICES\nWe fix what's broken.", 60, Color(0.1, 0.3, 0.6), -90.0)
	Greybox.label(geo, center + Vector3(1.42, 1.7, 1.5), "BYTE-RIGHT\nIT SERVICES", 50, Color(0.1, 0.3, 0.6), 90.0)
	# Inside: dashboard, the job ticket on the equipment rack, a dome light.
	Greybox.panel(geo, cab + Vector3(0, 0.75, -2.05), Vector3(2.4, 0.2, 0.3), Color(0.12, 0.12, 0.13))
	Greybox.box(geo, cab + Vector3(-0.6, 0.6, 1.85), Vector3(1.0, 1.2, 0.6), Color(0.3, 0.3, 0.32), "Rack")
	Greybox.label(geo, cab + Vector3(-0.6, 0.9, 1.54),
		"JOB TICKET #4471\nHalcyon Data Systems\nAfter-hours callout, 23:00\nRecover lead engineer's systems.\nContact: D. Rourke, facilities.", 22, Color(0.95, 0.95, 0.9), 180)
	var dome := OmniLight3D.new()
	dome.position = cab + Vector3(0, 1.9, 0)
	dome.omni_range = 3.5
	dome.light_energy = 0.6
	dome.light_color = Color(1.0, 0.9, 0.7)
	geo.add_child(dome)

	# Front doors hinge at their front edge and swing outward.
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = cab + Vector3(1.3 * side, 0, -1.95)
		add_child(pivot)
		Greybox.box(pivot, Vector3(0, 0.95, 0.45), Vector3(0.1, 1.9, 0.9), white, "VanDoor")
		van_doors["w" if side < 0 else "e"] = {"pivot": pivot, "swing": deg_to_rad(90.0 * side)}
	# The side door slides back along the outside of the van.
	side_door = Node3D.new()
	side_door.position = cab + Vector3(1.3, 0, 0.1)
	add_child(side_door)
	Greybox.box(side_door, Vector3(0, 0.95, 0), Vector3(0.1, 1.9, 1.3), white, "SideDoor")

	# Seats: two in front (driver, passenger), then the rear bench left to right.
	var seats := [
		[Vector3(-0.55, 0, -1.3), "w"], [Vector3(0.55, 0, -1.3), "e"],
		[Vector3(-0.99, 0, 0.7), "side"], [Vector3(-0.33, 0, 0.7), "side"],
		[Vector3(0.33, 0, 0.7), "side"], [Vector3(0.99, 0, 0.7), "side"],
	]
	var rear := 0
	for seat in seats:
		var at: Vector3 = cab + seat[0]
		Greybox.panel(geo, at + Vector3(0, 0.25, 0.1), Vector3(0.55, 0.5, 0.5), Color(0.15, 0.15, 0.18))
		var buckle := Interactable.create(self, at + Vector3(0.15, 0.3, -0.38), Vector3(0.08, 0.06, 0.08), "Unbuckle (ready up)", Color(0.85, 0.1, 0.1))
		var entry := {
			"spawn": global_transform * Transform3D(Basis(), at + Vector3(0, 0.05, 0)),
			"buckle": buckle,
			"exit": seat[1],
		}
		var handle_side := -1.0 if seat[1] == "w" else 1.0
		var handle_z := -0.45 if seat[1] == "side" else -1.15
		entry["handle"] = to_global(cab + Vector3(1.22 * handle_side, 0.95, handle_z))
		if seat[1] == "side":
			entry["inside"] = to_global(cab + Vector3(0.95, 0.05, 0.1))
			entry["outside"] = to_global(Vector3(cab.x + 2.3, center.y + 0.05, cab.z + 0.1 + (rear - 1.5) * 0.8))
			rear += 1
		else:
			var side := -1.0 if seat[1] == "w" else 1.0
			entry["inside"] = to_global(cab + Vector3(1.05 * side, 0.05, -1.5))
			entry["outside"] = to_global(Vector3(cab.x + 2.3 * side, center.y + 0.05, cab.z - 1.8))
		van_seats.append(entry)
		buckle.used.connect(ready_up.bind(van_seats.size() - 1))


## A player pressed E on a seat-belt buckle. The co-op layer can call this too.
func ready_up(p: Node, seat_index: int) -> void:
	if ready_players.has(p) or _intro_started or ready_players.values().has(seat_index):
		return
	ready_players[p] = seat_index
	van_seats[seat_index].buckle.enabled = false
	if ready_players.size() >= players_needed:
		_intro_started = true
		all_ready.emit()
	else:
		hud.set_objective("Ready. Waiting for your team (%d/%d)" % [ready_players.size(), players_needed])


## Open the door by this seat and step down onto the tarmac, facing the building.
## The camera looks at the door handle, then out of the door, and the mouse can still
## look around a little. Rear-bench players leave one after another through the side door.
func climb_out(p: Player, seat: Dictionary, order: int = 0) -> void:
	_hold_camera(p)
	if order > 0:
		await get_tree().create_timer(0.8 * order).timeout
	var eye: Vector3 = seat.spawn.origin + Vector3.UP * p.head.position.y
	var start := _view(p)
	var at_handle := _view_at(eye, seat.handle, start.x)
	var out_yaw := PI / 2 if seat.exit == "w" else -PI / 2
	var out := Vector2(_near(at_handle.x, out_yaw), -0.1)
	var ahead := Vector2(_near(out.x, 0.0), 0.0)
	var tw := create_tween()
	if seat.exit == "side" and _side_door_open:
		out = Vector2(_near(start.x, out_yaw), -0.1)
		ahead = Vector2(_near(out.x, 0.0), 0.0)
		tw.tween_method(_aim.bind(p), start, out, 0.5).set_trans(Tween.TRANS_SINE)
	else:
		tw.tween_method(_aim.bind(p), start, at_handle, 0.5).set_trans(Tween.TRANS_SINE)
		if seat.exit == "side":
			_side_door_open = true
			tw.tween_property(side_door, "position", side_door.position + Vector3(0.15, 0, 1.3), 0.7).set_trans(Tween.TRANS_QUAD)
		else:
			var door: Dictionary = van_doors[seat.exit]
			tw.tween_property(door.pivot, "rotation:y", door.swing, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_aim.bind(p), at_handle, out, 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(p, "global_position", seat.inside, 0.7)
	tw.tween_property(p, "global_position", seat.outside, 0.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_method(_aim.bind(p), out, ahead, 0.8).set_trans(Tween.TRANS_SINE)
	if seat.exit != "side":
		tw.tween_property(van_doors[seat.exit].pivot, "rotation:y", 0.0, 0.4).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	if is_instance_valid(p):
		_release_camera(p)


## Sit on the counter and swing your legs over, the way the front desk staff do it.
## Works from either side.
func hop_counter(p: Node) -> void:
	if not p is Player or p == _look_player:
		return
	var pl: Player = p
	var here := to_local(pl.global_position)
	var x := clampf(here.x, -4.6, -2.6)
	var dir := -1.0 if here.z > -1.0 else 1.0  # which way along z we're going
	var face := 0.0 if dir < 0.0 else PI  # facing -z is yaw 0
	_hold_camera(pl)
	var start := _view(pl)
	var at_desk := Vector2(_near(start.x, face), -0.55)
	var sitting := Vector2(_near(at_desk.x, face + PI / 2), -0.15)
	var over := Vector2(_near(sitting.x, face), -0.3)
	var tw := create_tween()
	tw.tween_property(pl, "global_position", to_global(Vector3(x, 0.1, -1.0 - dir * 0.75)), 0.3)
	tw.parallel().tween_method(_aim.bind(pl), start, at_desk, 0.3)
	# Up onto the counter, sitting sideways on its edge.
	tw.tween_property(pl, "global_position", to_global(Vector3(x, 0.22, -1.0 - dir * 0.2)), 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_method(_aim.bind(pl), at_desk, sitting, 0.45).set_trans(Tween.TRANS_SINE)
	# Swing the legs over and turn to face the far side.
	tw.tween_property(pl, "global_position", to_global(Vector3(x, 0.22, -1.0 + dir * 0.3)), 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_method(_aim.bind(pl), sitting, over, 0.45).set_trans(Tween.TRANS_SINE)
	# Drop down.
	tw.tween_property(pl, "global_position", to_global(Vector3(x, 0.1, -1.0 + dir * 0.85)), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_aim.bind(pl), over, Vector2(over.x, 0.0), 0.3)
	await tw.finished
	_release_camera(pl)


## A scripted move takes over the player's body and camera.
func _hold_camera(p: Player) -> void:
	p.input_locked = true
	p.velocity = Vector3.ZERO
	p.process_mode = Node.PROCESS_MODE_DISABLED
	if p == player:
		_look_player = p
		_look_offset = Vector2.ZERO
		_look_base = _view(p)


func _release_camera(p: Node) -> void:
	p.process_mode = Node.PROCESS_MODE_INHERIT
	p.input_locked = false
	if p == _look_player:
		_look_player = null
		_look_offset = Vector2.ZERO


## Where the camera points: x is body yaw, y is head pitch.
func _view(p: Player) -> Vector2:
	return Vector2(p.rotation.y, p.head.rotation.x)


## The view from `eye` looking at `target`, turning the short way from `from_yaw`.
func _view_at(eye: Vector3, target: Vector3, from_yaw: float) -> Vector2:
	var d := target - eye
	return Vector2(_near(from_yaw, atan2(-d.x, -d.z)), atan2(d.y, Vector2(d.x, d.z).length()))


func _near(from_yaw: float, to_yaw: float) -> float:
	return from_yaw + angle_difference(from_yaw, to_yaw)


## Point the camera, plus however far the local player has looked away with the mouse.
func _aim(v: Vector2, p: Player) -> void:
	var o := _look_offset if p == _look_player else Vector2.ZERO
	p.rotation.y = v.x + o.x
	p.head.rotation.x = clampf(v.y + o.y, -1.45, 1.45)
	if p == _look_player:
		_look_base = v


func _unhandled_input(event: InputEvent) -> void:
	if _look_player and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_offset.x = clampf(_look_offset.x - event.relative.x * Player.MOUSE_SENS, -LOOK_YAW, LOOK_YAW)
		_look_offset.y = clampf(_look_offset.y - event.relative.y * Player.MOUSE_SENS, -LOOK_PITCH, LOOK_PITCH)
		_aim(_look_base, _look_player)


## Where a player sits at the start. Solo play uses the passenger seat.
func seat_spawn(index: int) -> Transform3D:
	return van_seats[index].spawn


func start() -> void:
	player.flashlight.visible = false  # the lights are on; nobody needs a torch yet
	hud.set_objective("Look down at your seat belt and press E to unbuckle when you're ready")
	_dispatch_chatter()
	await all_ready
	var rear := 0
	for p in ready_players:
		var seat: Dictionary = van_seats[ready_players[p]]
		climb_out(p, seat, rear if seat.exit == "side" else 0)
		if seat.exit == "side":
			rear += 1
	await get_tree().create_timer(2.0).timeout
	hud.set_objective("Meet your contact at the front doors")
	var approach := Trigger.create(self, Vector3(0, 1, 11.5), Vector3(16, 2, 2))
	await approach.entered

	_set_front_doors_locked(false)
	rourke.walk_to(Vector3(0, 0, 8.8))
	await rourke.arrived
	rourke.face(player.global_position)
	await hud.lines(["l0_pa_1", "l0_pa_2", "l0_greet_1", "l0_greet_2", "l0_greet_3"])
	await hud.line("l0_greet_4")
	var inside := Trigger.create(self, Vector3(0, 1, 4.5), Vector3(10, 2, 2))
	rourke.walk_to(Vector3(-0.5, 0, 0.6))
	hud.set_objective("Follow Rourke to the front desk")
	await inside.entered
	_set_front_doors_locked(true)
	spawn = Transform3D(Basis(), Vector3(0, 0.1, 5.6))
	if rourke.state == Rourke.State.WALK:
		await rourke.arrived
	rourke.face(player.global_position)
	await hud.line("l0_signin")
	visitor_log.enabled = true
	hud.set_objective("Sign the visitor log on the front desk")
	await visitor_log.used
	visitor_log.enabled = false
	hud.notice("Signed in: BYTE-RIGHT IT SERVICES, 23:04", 4.0)
	hud.set_objective("")
	await hud.lines(["l0_tour_1", "l0_tour_2"])
	rourke.face(player.global_position)
	await hud.lines(["l0_desk_1", "l0_desk_2"])
	desk_terminal.enabled = true
	hud.set_objective("Read Dr. Vale's shredded memo at the front desk terminal")


func _set_front_doors_locked(locked: bool) -> void:
	db.run_silent("UPDATE doors SET locked = %d WHERE id = 'LOBBY-FRONT'" % int(locked))
	db.sync_world()


## The van radio, until the crew is ready.
func _dispatch_chatter() -> void:
	for id in ["l0_dispatch_1", "l0_dispatch_2", "l0_dispatch_3"]:
		if _intro_started:
			return
		await hud.line(id)


func _on_desk_query(_sql: String, result: Dictionary, ui: TerminalUI) -> void:
	if not peek_puzzle.solved and peek_puzzle.matches(db, result):
		peek_puzzle.solved = true
		ui.print_line("")
		ui.print_line("[color=#e0b050]WARDEN: Those scraps are out of order. Each one has a number in the piece_no column.[/color]")
		ui.print_line("[color=#e0b050]        To sort them, add ORDER BY to the end of your query, then the column to sort by: piece_no[/color]")
		hud.set_objective("Put the memo back in order")
		hud.line("l0_sort_hint", false)
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
	await get_tree().create_timer(1.0).timeout
	await hud.lines(["l0_memo_flag", "l0_memo_1", "l0_memo_2", "l0_memo_3", "l0_memo_4"])
	walkies.enabled = true
	counter_hop.enabled = true
	hud.set_objective("Hop over the counter (press E on its left end) and grab the walkie-talkies")


func _on_walkies(_p: Node) -> void:
	walkies.queue_free()
	Game.has_walkie = true
	hud.notice("Picked up walkie-talkies. Channel 1. (Co-op radio arrives in the next build.)", 5.0)
	prepare_next()
	hud.line("l0_walkie")
	hud.set_objective("Hop back over and follow Rourke")
	_walk_to_server_room()


## Rourke walks the crew down the hall himself, making small talk. Nothing is wrong yet.
func _walk_to_server_room() -> void:
	rourke.walk_to(Vector3(9.6, 0, 3))
	await rourke.arrived
	rourke.face(player.global_position)
	shutter.set_open(true)  # he badges it, and it opens like any other door
	hud.set_objective("Follow Rourke to Server Room A")
	var hall := Trigger.create(self, Vector3(8.2, 1, 3), Vector3(1.2, 2, 2))
	await hall.entered
	rourke.walk_to(Vector3(22.4, 0, 3))
	await hud.lines(["l0_tour_3", "l0_tour_4", "l0_tour_5", "l0_tour_6"])
	if rourke.state == Rourke.State.WALK:
		await rourke.arrived
	var near := Trigger.create(self, Vector3(20.6, 1, 3), Vector3(2.4, 2, 2))
	near.entered.connect(_on_reach_server_room)


func _on_reach_server_room(_b: Node) -> void:
	exit_door.set_open(true)
	rourke.face(player.global_position)
	await hud.line("l0_sra")
	if world:
		# Server Room A is already built behind this door. Its own Rourke takes over
		# from this one where he stands and leads the crew in.
		finish_level("level_1")
		return
	player.input_locked = true
	await hud.fade(true, 1.0)
	finish_level("level_1")


## Optional: Mercer's cassette in the forgotten closet.
func _on_tape(_p: Node) -> void:
	tape.enabled = false
	await hud.lines(VoiceLines.ids_in_scene("l0_tape"))
