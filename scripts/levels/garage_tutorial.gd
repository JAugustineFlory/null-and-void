class_name GarageTutorial
extends Node
## The garage lab's practice: two cases at the lab computers, after chapter 0 and
## before the punch bag (plan/garage-lab-v0.10.md). The first is found and built
## with the notebook's help (the van's kit, its table on the kit crate's label);
## the second without it (the jobs, their table on Maddison's job board). Each
## step waits for whoever hasn't done the practice before (Profile.tutorial_done);
## a crew that all has skips it, and the lab stays open. Chapter 1 of Easy SQL
## comes in here, so floor G's front desk doesn't play it again (Huddle.done).
## The data is fixed, not from the run's seed: it teaches, it doesn't test. It's
## in the lab's own database (GarageLab.db), so nothing here touches the building.
## Built by GarageLab; HomeBase.start runs it and passes it the crew's answers.

## Approved by Augustine word for word, 2026-11-21 (plan/approvals/garage-tutorial-text.md:
## M lines are Maddison's, in VoiceLines; T1 is the first to-do. L lines are Teaching's,
## plan/teaching/garage-lab-cases-draft.md).
const INTRO_CASE := "This is a case. Each one gets its own bookmark on the left. Read it, find the pieces it needs, run the query at a terminal, then point at the answer and add it to your notebook."  # L1
const PC_NAME := "lab computer"  # L2
const SIT := "Use a computer in the lab"  # T1, under the first case's question

const KIT_ROWS := [  # L3
	["ladder", 1, "A"], ["drill", 2, "B"], ["cable spool", 3, "B"],
	["crimp tool", 2, "C"], ["zip ties", 40, "C"], ["duct tape", 0, "C"],
]
const KIT_LABEL := [  # L4
	"VAN KIT",
	"In the database as: van_kit",
	{"text": "Count it back in after every job!", "hand": true},
]
const KIT_LABEL_TITLE := "VAN KIT"
const KIT_CLUE := "The van's kit is the table van_kit."  # L5
const KIT_CASE := "Is the van ready for tonight?"  # L6
const KIT_OBJ := "Find what the van's kit has run out of, at a lab computer"  # L7
const KIT_PIECES := [  # L8
	{"id": "table", "label": "The table", "value": "van_kit", "task": "Find the table the van's kit is kept in",
		"where": "A label on the van's kit crate", "seen_in": "van_kit", "blank": "enter_table_name"},
]
const KIT_QUERY := "SELECT * FROM {table};"
const KIT_STEPS := [  # L9
	{"id": "run", "text": "Run it at a lab computer"},
	{"id": "point", "text": "Point at the item there's none of and add it to your notebook"},
]
const KIT_SLOT := "None left in the van"  # L10 (the page adds the colon)
const KIT_ROW_MISS := "That's the right row. The blank wants the item's name."  # L11
const KIT_MISS := "Not that one: the blank wants the item whose qty is 0."  # L12
const KIT_SOLVED := "The van's out of duct tape. Somebody grab a roll."  # L13
const KIT_HINTS := [  # L14 to L16
	"The van's kit crate has a label on it. It names the kit's table.",
	"The shape of it:\n" +
		"    [color=#ffffff]SELECT * FROM van_kit;[/color]\n" +
		"  SELECT *        which columns to show (* means every column)\n" +
		"  FROM van_kit    which table to read them from\n" +
		"  ;               the end of the question\n" +
		"Type it and press Enter.",
	"Type this exactly and press Enter. Spelling matters, capitals don't:\n" +
		"    [color=#ffffff]SELECT * FROM van_kit;[/color]\n" +
		"Then find the item whose qty is 0, point at its name and add it to your notebook.",
]

const JOB_ROWS := [  # L17
	[1, "Kemp Dental", "Ashford", "done", 80], [2, "Bexley Library", "Bexley", "done", 120],
	[3, "Ashford Bowl-O-Rama", "Ashford", "done", 95], [4, "Zebulon Feed & Seed", "Zebulon", "open", 60],
	[5, "Dale's Discount Tires", "Bexley", "done", 40],
]
const OPEN_JOB := "Zebulon Feed & Seed"
const BOARD := [  # L18
	"JOB BOARD",
	{"text": "Retired! Every job is on the computer now,", "hand": true},
	{"text": "in the table: jobs", "hand": true},
	{"text": "   - Maddison", "hand": true},
]
const BOARD_TITLE := "JOB BOARD"
const BOARD_CLUE := "The jobs are the table jobs."  # L19
const JOBS_CASE := "Did we leave a job hanging?"  # L20
const JOBS_OBJ := "Find the job that's still open, at a lab computer"  # L21
const JOBS_PIECES := [  # L22
	{"id": "table", "label": "The table", "value": "jobs", "task": "Find the table the jobs are kept in",
		"where": "Maddison's job board, in the lab", "seen_in": "jobs", "blank": "enter_table_name"},
]
const JOBS_STEPS := [  # L23
	{"id": "run", "text": "Run it at a lab computer"},
	{"id": "point", "text": "Point at the open job's client and add it to your notebook"},
]
const JOBS_SLOT := "Still open"  # L24
const JOBS_ROW_MISS := "That's the right job. The blank wants the client's name."  # L25
const JOBS_DONE_MISS := "That one's done. The blank wants the job that's still open."  # L26
const JOBS_MISS := "Not that one: the blank wants the client of the job whose status is open."  # L27
const JOBS_SOLVED := "Zebulon Feed & Seed is still open. It'll have to wait."  # L28
const JOBS_HINTS := [  # L29 to L31
	"Maddison's job board hangs in the lab. It says where the jobs went.",
	"The shape of it:\n" +
		"    [color=#ffffff]SELECT * FROM enter_table_name;[/color]\n" +
		"  SELECT *                which columns to show (* means every column)\n" +
		"  FROM enter_table_name   which table to read them from\n" +
		"Replace enter_table_name with the table's name. It's on Maddison's job board.",
	"Type this exactly and press Enter. Spelling matters, capitals don't:\n" +
		"    [color=#ffffff]SELECT * FROM jobs;[/color]\n" +
		"Then find the job whose status is open, point at its client and add it to your notebook.",
]

## The kit crate, behind the van (garage-local), and the job board on the lab's
## south wall, facing in.
const CRATE := Vector3(5.2, 0, 2.55)
const CRATE_SIZE := Vector3(0.8, 0.5, 0.5)
const BOARD_AT := Vector3(-11.2, 1.5, 2.28)
## How long the host waits to hear whether each player has done the practice
## before (a machine that never says is counted as new to it).
const ASK_TIMEOUT := 5.0
## The label's and the board's hint spots.
const KIT_SPOT := "lab_kit_label"
const BOARD_SPOT := "lab_job_board"

var lab: GarageLab
var home: Node3D
var label: Document
var board: Document
## Each case's first tier (L14, L29) is a hint spot (Puzzle.spots): `.hint` sends
## the crew to the label or the board until it's read or its table is in hand.
var kit_puzzle := Puzzle.new("lab_kit", "SELECT item, qty FROM van_kit", ["item", "qty"], false, KIT_HINTS.slice(1))
var jobs_puzzle := Puzzle.new("lab_jobs", "SELECT client, status FROM jobs", ["client", "status"], false, JOBS_HINTS.slice(1))
## Peer ids of the players new to the practice: each step waits for them.
var learners: Array = []
## Whether the practice is running, and whether it has run (or been skipped).
var running := false
var finished := false
## Host: who has said whether they've done it before, who has sat at a lab
## computer, and how far the crew has got.
var _done_before := {}
var _sat := {}
var _kit_listed := false
var _kit_found := false
var _jobs_found := false


static func build(on_lab: GarageLab) -> GarageTutorial:
	var t := GarageTutorial.new()
	t.name = "Tutorial"
	t.lab = on_lab
	t.home = on_lab.home
	on_lab.add_child(t)
	t._build()
	return t


## The practice tables, as SQL for the lab's database.
static func seed_sql() -> String:
	var sql := "CREATE TABLE van_kit (item TEXT, qty INTEGER, shelf TEXT);\n"
	for r in KIT_ROWS:
		sql += "INSERT INTO van_kit VALUES (%s);\n" % ", ".join(r.map(func(v): return FacilityDB._sql_literal(v)))
	sql += "CREATE TABLE jobs (job_no INTEGER, client TEXT, town TEXT, status TEXT, fee INTEGER);\n"
	for r in JOB_ROWS:
		sql += "INSERT INTO jobs VALUES (%s);\n" % ", ".join(r.map(func(v): return FacilityDB._sql_literal(v)))
	return sql


func _build() -> void:
	var geo: Node3D = home.geo
	kit_puzzle.case_id = "lab_kit"
	jobs_puzzle.case_id = "lab_jobs"
	kit_puzzle.spots = [{"id": KIT_SPOT, "text": KIT_HINTS[0], "piece": "table"}]
	jobs_puzzle.spots = [{"id": BOARD_SPOT, "text": JOBS_HINTS[0], "piece": "table"}]
	Greybox.box(geo, CRATE + Vector3(0, CRATE_SIZE.y / 2, 0), CRATE_SIZE, Color(0.42, 0.34, 0.22), "KitCrate")
	label = Document.place(geo, CRATE + Vector3(0, CRATE_SIZE.y + 0.002, 0), -90.0, KIT_LABEL_TITLE, KIT_LABEL, true, "laminated")
	label.name = "KitLabel"
	label.pieces = [{"case": "lab_kit", "piece": "table"}]
	label.clues = [{"case": "lab_kit", "text": KIT_CLUE}]
	label.spot = KIT_SPOT
	label.shine_seen.connect(_on_shine_seen)
	board = Document.place(geo, BOARD_AT, 0.0, BOARD_TITLE, BOARD)
	board.name = "JobBoard"
	board.pieces = [{"case": "lab_jobs", "piece": "table"}]
	board.clues = [{"case": "lab_jobs", "text": BOARD_CLUE}]
	board.spot = BOARD_SPOT
	for pc in lab.computers:
		pc.puzzles = [kit_puzzle, jobs_puzzle]
		pc.opened.connect(_on_sat)
		pc.queried.connect(_on_query)
	var game := _game()
	game.cell_missed.connect(_on_cell)
	game.answer_found.connect(_on_answer_found)


## Every machine, in the garage's story (HomeBase.start): the practice, or, for a
## crew that has all done it, a word from Maddison and the lab left open.
func run() -> void:
	await _who_learns()
	if learners.is_empty():
		await home._say("l0_lab_skip", "l0_lab_skip_solo")
		open_lab()
		finished = true
		return
	running = true
	open_lab()
	home.maddison_to("lab")
	await home._say("l0_lab_go", "l0_lab_go_solo")
	home.hud.todo(KIT_CASE, SIT)
	await home.sync.gate("lab_sat", _learners_sat)

	# The first case, with the notebook's help.
	_open_kit()
	await home._say("l0_lab_cases", "l0_lab_cases_solo")
	await home._beat(0.5)
	await home._say("l0_lab_label")
	await home.sync.gate("lab_label", func():
		while not _game().has_piece("lab_kit", "table"):
			await get_tree().create_timer(0.2, false).timeout)
	await home._say("l0_lab_query")
	await Huddle.of(home).run("easy_sql_1")  # the book's first query, here and not at the front desk
	await home.sync.gate("lab_listed", func():
		while not _kit_listed:
			await get_tree().create_timer(0.2, false).timeout)
	_game().tick_step("lab_kit", "run")
	await home._say("l0_lab_click")
	await home.sync.gate("lab_kit_found", func():
		while not _kit_found:
			await get_tree().create_timer(0.2, false).timeout)
	_solve("lab_kit", kit_puzzle, KIT_SOLVED)
	await home._beat()

	# The second, without it.
	_open_jobs()
	await home._say("l0_lab_case2", "l0_lab_case2_solo")
	await home.sync.gate("lab_jobs_found", func():
		while not _jobs_found:
			await get_tree().create_timer(0.2, false).timeout)
	_solve("lab_jobs", jobs_puzzle, JOBS_SOLVED)
	home.hud.todo("")
	await home._say("l0_lab_case2_done")
	_game().practiced = true
	var net := get_node_or_null("/root/Net")
	if net and net.profile:
		net.profile.tutorial_done = true
		net.profile.save()
	await home._beat(0.5)
	await home._say("l0_lab_lockers", "l0_lab_lockers_solo")
	running = false
	finished = true


## The computers on: for the practice, or for anyone who wants it.
func open_lab() -> void:
	for pc in lab.computers:
		pc.enabled = true


## Every machine: who's new to the practice. Each machine says, and the host decides.
func _who_learns() -> void:
	var done := _done_here()
	if multiplayer.is_server():
		_done_before[multiplayer.get_unique_id()] = done
	else:
		_said_done.rpc_id(1, done)
	await home.sync.gate("lab_who", _decide_learners)


func _done_here() -> bool:
	var net := get_node_or_null("/root/Net")
	return net != null and net.profile != null and net.profile.tutorial_done


## Host: a player says whether they've done the practice before.
@rpc("any_peer", "reliable")
func _said_done(done: bool) -> void:
	if multiplayer.is_server():
		_done_before[multiplayer.get_remote_sender_id()] = done


## Host: once everyone has said (or a moment has passed), tell every machine who's new.
func _decide_learners() -> void:
	var waited := 0.0
	var ids: Array = home.players.all_ids()
	while waited < ASK_TIMEOUT and not ids.all(func(id): return _done_before.has(id)):
		await get_tree().create_timer(0.1, false).timeout
		waited += 0.1
	home.sync.run_on(self, "_set_learners", [ids.filter(func(id): return not _done_before.get(id, false))])


## Every machine: the players the practice waits for.
func _set_learners(ids: Array) -> void:
	learners = ids


## Host: someone sat down at a lab computer.
func _on_sat(by: Node) -> void:
	_sat[home.players.id_of(by)] = true


func _learners_sat() -> void:
	while not learners.all(func(id): return _sat.has(id) or home.players.puppet(id) == null):
		await get_tree().create_timer(0.2, false).timeout


## Host: a query ran at a lab computer. The kit is on screen once it shows its items.
func _on_query(_sql: String, result: Dictionary, _ui: TerminalUI) -> void:
	if running and not _kit_listed and kit_puzzle.matches(lab.db, result):
		_kit_listed = true
	if running and not _kit_listed and result.get("ok", false) and result.rows.any(func(r): return r.values().map(func(v): return str(v).to_lower()).has("duct tape")):
		_kit_listed = true


func _open_kit() -> void:
	var game := _game()
	home.hud.todo(KIT_CASE, KIT_OBJ)
	game.open_case("lab_kit", KIT_CASE, ["van_kit"], KIT_OBJ)
	game.set_pieces("lab_kit", KIT_PIECES, KIT_QUERY, KIT_STEPS)
	game.set_case_note("lab_kit", INTRO_CASE, "", PC_NAME)
	game.set_blank("lab_kit", KIT_SLOT, ["duct tape"], "duct tape", {"column": "item", "values": ["duct tape"], "rows": [{"qty": 0}]})
	label.shine()  # the crew's first paper with a piece on it: what to do with one (_on_shine_seen)


func _open_jobs() -> void:
	var game := _game()
	home.hud.todo(JOBS_CASE, JOBS_OBJ)
	game.open_case("lab_jobs", JOBS_CASE, ["jobs"], JOBS_OBJ)
	game.set_pieces("lab_jobs", JOBS_PIECES, "", JOBS_STEPS)  # no shape this time: they type it all
	game.set_case_note("lab_jobs", "", "", PC_NAME)
	game.set_blank("lab_jobs", JOBS_SLOT, ["zebulon"], OPEN_JOB, {"column": "client", "values": [OPEN_JOB], "rows": [{"status": "open"}]})


## Every machine: case `id` is solved, on everyone's page.
func _solve(id: String, puzzle: Puzzle, how: String) -> void:
	puzzle.solved = true
	var game := _game()
	game.fill_blank(id, false)
	game.solve_case(id, how)


## This player looked at the shining label: floor G's words for what a shine is
## and how a piece is taken off a paper (approved there; G says it again).
func _on_shine_seen(_player: Node) -> void:
	home.hud.notice(load("res://scripts/levels/level_0.gd").INTRO_SHINE, 8.0)


## This player found a practice answer: tell the host.
func _on_answer_found(id: String) -> void:
	if id in ["lab_kit", "lab_jobs"]:
		home.sync.report_answer(id)


## Host (HomeBase.case_answered): a player wrote a practice answer in.
func answered(id: String) -> void:
	if id == "lab_kit":
		_kit_found = true
	elif id == "lab_jobs":
		_jobs_found = true


## This player pointed at a cell that didn't answer a practice case: pencil why,
## under its blank (their own page; once each, Game.blank_miss).
func _on_cell(_column: String, _value: String, row: Dictionary) -> void:
	var game := _game()
	var cells := {}
	for k in row:
		cells[str(k).to_lower()] = str(row[k]).to_lower()
	var kit: Dictionary = game.case_info("lab_kit")
	var jobs: Dictionary = game.case_info("lab_jobs")
	if jobs.get("open", false) and not jobs.get("solved", false):
		if cells.get("client", "") == OPEN_JOB.to_lower() or (cells.get("status", "") == "open" and not cells.has("client")):
			game.blank_miss("lab_jobs", JOBS_ROW_MISS)
		elif cells.get("status", "") == "done" or (cells.has("client") and cells.client != OPEN_JOB.to_lower()):
			game.blank_miss("lab_jobs", JOBS_DONE_MISS)
		else:
			game.blank_miss("lab_jobs", JOBS_MISS)
	elif kit.get("open", false) and not kit.get("solved", false):
		if cells.get("item", "") == "duct tape" or (cells.get("qty", "") == "0" and not cells.has("item")):
			game.blank_miss("lab_kit", KIT_ROW_MISS)
		else:
			game.blank_miss("lab_kit", KIT_MISS)


## Leaving for Halcyon: the practice tables aren't the building's, so they come
## off the notebook's Tables page.
func forget_tables() -> void:
	var game := _game()
	for t in ["van_kit", "jobs"]:
		game.notebook_tables.erase(t)
	game.notebook_changed.emit()


func _game() -> Node:
	return get_node("/root/Game")
