extends LevelBase
## Level 0: The Lobby. Rourke's tour, the shredded memo, the walkie-talkies.
## Teaches SELECT, FROM and ORDER BY.

const SEED_PATH := "res://data/level_0.sql"

var rourke: Rourke
var desk_terminal: Terminal
var shutter: Door
var walkies: Interactable
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
	"ORDER BY goes at the end of the query. Type exactly SELECT * FROM memo_fragments ORDER BY piece_no; and press Enter.",
])


func build() -> void:
	db.load_seed(FileAccess.get_file_as_string(SEED_PATH))
	var carpet := Color(0.22, 0.2, 0.24)
	var wall := Color(0.62, 0.58, 0.5)
	# Lobby: x -8..8, z -7..7
	Greybox.room(geo, Vector3.ZERO, Vector3(16, 4, 14), {"floor": carpet, "wall": wall}, [
		{"wall": "e", "at": 3.0, "width": 2.0, "height": 3.0},
		{"wall": "w", "at": 4.0, "width": 0.9, "height": 1.05, "bottom": 0.1},
	])
	Greybox.label(geo, Vector3(0, 3.0, -6.88), "HALCYON DATA SYSTEMS", 160, Color(0.15, 0.2, 0.35))
	Greybox.label(geo, Vector3(0, 2.55, -6.88), "Data you can trust.", 64, Color(0.25, 0.25, 0.3))
	# Front doors (sealed behind you)
	Greybox.box(geo, Vector3(0, 1.3, 6.95), Vector3(3.2, 2.6, 0.12), Color(0.25, 0.35, 0.4), "FrontDoors")
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

	# Lights. After hours, so half are off.
	for p in [Vector3(-4, 4, -4), Vector3(4, 4, -4), Vector3(0, 4, 1.5), Vector3(-5, 4, 4.5)]:
		var l := add_light("lobby", p, 9.0, 1.3)
		if p.x < 0:
			FlickerLight.attach(l, 0.12)
	add_light("hall", Vector3(13, 3, 3), 6.0, 1.0)
	var bad := add_light("hall", Vector3(21, 3, 3), 6.0, 0.6)
	FlickerLight.attach(bad, 0.5)

	rourke = Rourke.new()
	rourke.name = "Rourke"
	add_child(rourke)
	rourke.position = Vector3(0, 0, 2.5)
	spawn = Transform3D(Basis(), Vector3(0, 0.1, 5.6))


func start() -> void:
	rourke.face(player.global_position)
	hud.set_objective("Talk to the escort")
	await hud.play_lines([
		["ROURKE", "There you are. Dale Rourke, facilities. I'll be your escort tonight."],
		["ROURKE", "Badge rules after hours. You don't go anywhere I don't take you."],
	])
	rourke.walk_to(Vector3(-0.5, 0, 0.6))
	hud.set_objective("Follow Rourke to reception")
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


func _on_desk_query(_sql: String, result: Dictionary, ui: TerminalUI) -> void:
	if not peek_puzzle.solved and peek_puzzle.matches(db, result):
		peek_puzzle.solved = true
		ui.print_line("")
		ui.print_line("[color=#e0b050]WARDEN: Those scraps are out of order. Each one has a piece_no.[/color]")
		ui.print_line("[color=#e0b050]        Sort rows with ORDER BY. Example: SELECT * FROM visitors ORDER BY checked_in;[/color]")
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
