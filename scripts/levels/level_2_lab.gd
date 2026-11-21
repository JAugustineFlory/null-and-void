class_name Level2Lab
extends Node
## Secure Lab B, Dr. Vale's lab, where Rourke turns. He walks the crew up from the
## elevator and has each of them badge in "for the visitor log". Inside: a tipped
## chair, blood on the desk, her coat on its hook. While they look, he steps out,
## the door locks behind him, and he tells WARDEN the contractors hurt her. Then he
## comes back in through the rear door, and the crew kills him, ties him up (only
## with cable someone carried up from the server floor) or leaves him down. Untied,
## he comes round and gets away sooner. The lockdown starts, and
## the way out is the door-controller query they practised on the server floor,
## on this lab's own zone, against the clock: WARDEN has sent a security response.
## If it arrives first, the crew is caught, the lab's controllers are re-keyed to
## another zone, and they start the escape again.
##
## Co-op: the host decides (badge swipes, Rourke's walks, the fight, the switch
## presses) and plays each result on every machine with sync.run_on(self, ...).

signal _step(key: String)

## The lab door's case page in the notebook (Cases tab).
const LAB_CASE := "What's wrong with the lab door?"
const LINE_GAP := 1.5  # a beat for a line that isn't recorded yet
## Once the crew is locked in: the radio call, then his monologue through the glass (docs/script).
const FRAME_LINES := ["l2_frame", "l2_trap_2", "l2_gloat_1", "l2_gloat_2", "l2_gloat_3", "l2_gloat_4", "l2_gloat_5", "l2_gloat_6", "l2_trap_1"]
## After he frames the crew on the radio, a few beats to let it land before everyone's
## put off the terminal (Augustine, 2026-11-05: "Wait a few beats after we hear him
## framing us"). Then every view turns to him at the lab door for FOCUS_TIME, and the
## crew can move again while the monologue plays on.
const FRAME_BEAT := 2.5
const FOCUS_TIME := 3.0
## How far into the last monologue line he means to be at the rear door: he sneaks
## round while he's still talking, so it opens before he's done.
const SNEAK_IN_BEFORE_END := 1.5
## Left down without cable, Rourke stays down this long before the crew's choice counts.
const UNTIED_AFTER := 15.0
const LOCKOUT := 10.0
## How long the crew has to get the lab door open once the lockdown starts.
const RESPONSE_TIME := 240.0
## When WARDEN's PA calls out the time left.
const RESPONSE_CALLS := [60.0, 30.0]
const RED := Color(1.0, 0.18, 0.12)
const SCREEN_GREEN := Color(0.2, 0.9, 0.35)
## WARDEN doesn't repeat a reaction (a refused switch) within this many seconds.
const WARDEN_REPEAT := 6.0
const WHITE := Color(0.92, 0.95, 1.0)
const FIGHT_BARKS := ["l2_hit_1", "l2_hit_2", "l2_hit_3", "l2_hit_4", "l2_hit_prints"]
const HURT_BARKS := ["l2_hurt_1", "l2_hurt_2", "l2_hurt_3"]
const BARK_GAP := 3.5
## Lines for Augustine's approval: see plan/approvals/combat-strings.md.
const FIGHT_NOTICE := "Click to strike. Right-click as he swings to block."

## Rourke's walk up from the arrival car (level space), and where he stands.
## He stops past the lab door, so the badge reader is on the crew's side of him.
const LEAD_PATH := [Vector3(5.0, 0, 8), Vector3(0, 0, 8), Vector3(-9, 0, 8), Vector3(-9, 0, -1.8)]
const AT_DOOR := Vector3(-9, 0, -1.8)
const BY_COAT := Vector3(-14.6, 0, -2.0)
const OUTSIDE := Vector3(-9.0, 0, -1.4)
const ROUND_BACK := [Vector3(-9, 0, 9), Vector3(-17, 0, 9), Vector3(-17, 0, 0)]
const BEHIND_REAR := Vector3(-17, 0, 0)
const INSIDE_REAR := Vector3(-15, 0, 0)
const RESPAWN := Vector3(-12.2, 0.1, 1.6)
## Well inside the lab, clear of the main doorway's guard: where the whole crew has to
## be before he walks out and the door locks.
const INSIDE_BOX := AABB(Vector3(-16, -1, -4), Vector3(5.7, 4, 8))

var level: Node3D  # the Level 2 wing (untyped: tests load this script)
var data: Dictionary
var rourke: Rourke
var terminal: Terminal
var reader: Interactable
var reader_relay: Interactable
var switches := {}
var zone := ""
## The phase of the betrayal, the same on every machine:
## off, lead, badge, inside, locked, fight, down, escape, caught, done.
var phase := "off"
var badged := {}  # peer id -> true
var cable_holders := {}  # peer id -> true: who carried cable up from the server floor
var fate := ""
var switches_locked_until := 0.0
## Her terminal has taken Rourke's badge: someone sat down at it, or ran a query,
## once the lockdown started. Until then the switches refuse ("badge required").
var logged_in := false
## Host: WARDEN's one-time reactions already said ("found").
var _reacted := {}
## When each WARDEN reaction last played on this machine.
var _warden_at := {}
var _steps := {}
var _last_bark := -100.0
var _down_for := 0.0
## Seconds until the security response arrives; below zero, nobody is coming.
var response_left := -1.0
## How many times the response has caught the crew.
var caught := 0
var clock: Label3D
var _plate: Label3D
var _card: Document
var _stamps := []
## Door id -> a wall in its doorway that only the crew bumps into: up while Rourke
## walks out through it or back in, so nobody slips out after him.
var guards := {}
## True while each machine keeps its own player inside the lab (_keep_crew_in).
var _keeping_in := false
## True while his monologue is still playing on this machine.
var _talking := false

var door_puzzle: Puzzle
## The terminal has found the latched controller (pointed at it): the reset
## switches have power (M3). Off again after a re-key.
var powered := false
## The response clock starts at the crew's first query in the lockdown, and after
## a re-key at the next one (M2).
var clock_waiting := false
## Host: the lab door's controller is on screen (the query found it): pointing at
## it is the step.
var door_listed := false

## The lab door's case (approvals/puzzle-flow-floor-22.md, T2-T13).
const LAB_QUERY := "SELECT id FROM {table} WHERE zone = '{zone}' AND status = '{status}';"
const LAB_SLOT := "The lab door's controller:"
const LAB_ROW := "That's the right row. The blank wants its id."
const LAB_OFFLINE := "That one's 'offline': switched off on purpose. The blank wants the one that's 'fault'."
const LAB_ELSEWHERE := "That one's faulted, but in another zone. The blank wants the lab's zone."
const LAB_OTHER := "Not that one: the blank wants the controller in the lab's zone with status 'fault'."
## T11: a switch pressed before the terminal finds the latched controller.
const NO_POWER := "> %s: NO POWER TO THE RESET CIRCUIT.\n> It powers up once the terminal finds the latched controller."
## The hint spot the door card is (Document.spot): its tier comes first, and goes once it's read (M4).
const CARD_SPOT := "lab_door_card"
const CARD_TIER := "the door card hangs over the bench. it says \"controller zone\" and a letter. put that letter in place of enter_zone."
## Where the lab's screen pieces were found.
const SCREEN := "Dr. Vale's screen"
## Her terminal once the lab door is open: Rourke's session is over (part 2).
const AFTER_LINES := [
	"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  SECURE LAB B",
	"Session: GUEST (lockdown mode, read only)",
	TerminalPolicy.BOOT_LINE,
]


static func lab_pieces(z: String) -> Array:
	return [
		{"id": "table", "label": "The table of controllers", "value": "door_controllers", "task": "Find the table of door controllers", "where": SCREEN, "seen_in": "door_controllers", "blank": "enter_table_name"},
		{"id": "zone", "label": "The lab's zone", "value": z, "task": "Find the zone the lab's doors are on", "where": "The door card over the bench", "blank": "enter_zone"},
		{"id": "status", "label": "What a stuck lock reads", "value": "fault", "task": "Find the status a stuck lock shows", "where": SCREEN, "blank": "enter_status"},
	]


static func create(for_level: Node3D, level_data: Dictionary) -> Level2Lab:
	var lab := Level2Lab.new()
	lab.name = "Lab"
	lab.level = for_level
	lab.data = level_data
	lab.zone = level_data.lab_zone
	for_level.add_child(lab)
	lab._build()
	return lab


## The lab door's query: its own zone, and status 'fault'. Both conditions matter.
## Hints: the door card first (a spot, M4), then the shape with the zone left as
## 'enter_zone' (T12), then the query (T13).
static func door_puzzle_for(zone: String) -> Puzzle:
	var p := Puzzle.new("lab_door", "SELECT id FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % zone, ["id"], false, [
		"the shape, with the zone left blank:\n" +
		"    [color=#ffffff]SELECT id FROM door_controllers WHERE zone = 'enter_zone' AND status = 'fault';[/color]\n" +
		"  SELECT id                  just the controller's id\n" +
		"  FROM door_controllers      the building's door controllers\n" +
		"  WHERE zone = 'enter_zone'  only this lab's zone\n" +
		"  AND status = 'fault'       ...that are ALSO faulted. both must be true\n" +
		"replace enter_zone with this lab's controller zone. it's on the door card over the bench.",
		"type this, then Enter:\n" +
		"    [color=#ffffff]SELECT id FROM door_controllers WHERE zone = '%s' AND status = 'fault';[/color]\n" % zone +
		"point at the id it gives you and add it to your notebook: that's the one to reset. " +
		"the switches are on this lab's wall, by the coat. press E on the one with that id.",
	])
	p.spots = [{"id": CARD_SPOT, "text": CARD_TIER, "piece": "zone"}]
	return p

func _build() -> void:
	var geo: Node3D = level.geo
	door_puzzle = door_puzzle_for(zone)
	level.add_door("SECLAB-B", Vector3(-10.2, 1.2, 0), Vector3(0.15, 2.4, 1.8))
	level.add_door("SECLAB-B-REAR", Vector3(-15.8, 1.2, 0), Vector3(0.15, 2.4, 1.8))
	# Outside, in the patrol corridor: the room's name, its door plate, and the badge reader.
	Greybox.label(geo, Vector3(-9.88, 2.7, 0), "SECURE LAB B", 48, Color(0.75, 0.75, 0.7), 90)
	Greybox.panel(geo, Vector3(-9.89, 1.75, -1.25), Vector3(0.01, 0.16, 0.36), Color(0.75, 0.72, 0.6))
	Greybox.panel(geo, Vector3(-9.88, 1.3, 1.2), Vector3(0.02, 0.16, 0.1), Color(0.12, 0.12, 0.13))
	reader = Interactable.create(geo, Vector3(-9.86, 1.3, 1.2), Vector3(0.02, 0.07, 0.07), "Badge in", Color(0.1, 0.6, 0.2))
	reader.name = "LabReader"
	reader.enabled = false
	reader.local_only = true  # the badge is on the presser's machine: check it there first
	reader.used.connect(_on_reader)
	# What a badged press tells the host: a reader nobody can see or aim at, which a
	# client's press is forwarded through like any other.
	reader_relay = Interactable.create(geo, Vector3(-9.95, 1.3, 1.2), Vector3(0.02, 0.07, 0.07), "", Color.BLACK, false)
	reader_relay.name = "LabReaderRelay"
	reader_relay.remove_from_group("interactable")
	reader_relay.collision_layer = 0
	reader_relay.used.connect(_on_badge_swiped)

	# Inside: her desk and terminal on the north wall, the bench along the south.
	Greybox.box(geo, Vector3(-13, 0.4, -3.2), Vector3(2.4, 0.8, 0.9), Color(0.4, 0.4, 0.42), "ValeDesk")
	terminal = Terminal.spawn(geo, Vector3(-13.4, 0.8, -3.2), 0, "VALE_I  -  SECURE LAB B", level.db, level.terminal_ui)
	terminal.puzzles = [door_puzzle]
	terminal.boot_lines = [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  SECURE LAB B",
		"Session: VALE_I",
		"",
		"> notes/batch_7.txt",
		"  Cold storage still logging the wrong temperatures. Not the sensors.",
		"  Someone is editing the records after I sign them.",
	]
	terminal.queried.connect(_on_query)
	terminal.query_failed.connect(_on_query_failed)
	terminal.opened.connect(_on_opened)
	# The struggle: blood on the desk's edge and on the floor, the chair on its side, the coat.
	Greybox.panel(geo, Vector3(-12.3, 0.81, -2.78), Vector3(0.35, 0.01, 0.08), Color(0.35, 0.02, 0.02))
	Greybox.panel(geo, Vector3(-12.1, 0.005, -2.2), Vector3(0.6, 0.01, 0.4), Color(0.3, 0.02, 0.02))
	var chair := Greybox.box(geo, Vector3(-11.8, 0.25, -1.7), Vector3(0.45, 0.5, 0.45), Color(0.25, 0.25, 0.27), "TippedChair")
	chair.rotation_degrees = Vector3(0, 25, 90)
	Greybox.panel(geo, Vector3(-15.66, 1.5, -2.6), Vector3(0.04, 0.05, 0.12), Color(0.5, 0.5, 0.5))  # hook
	Greybox.panel(geo, Vector3(-15.62, 1.0, -2.6), Vector3(0.1, 0.95, 0.45), Color(0.7, 0.62, 0.48))  # her coat
	Greybox.box(geo, Vector3(-13, 0.45, 3.25), Vector3(4.2, 0.9, 0.8), Color(0.4, 0.4, 0.42), "LabBench")
	# No cable in here: only a coil carried up from the server floor ties him up.
	# The reset switches for this zone's controllers, on the west wall. No sign: the
	# card says they're here, and the hint says where.
	Greybox.panel(geo, Vector3(-15.68, 1.3, -1.6), Vector3(0.05, 0.5, 0.75), Color(0.3, 0.32, 0.3))
	_place_zone()
	# The response clock, over the main door on the inside.
	clock = Greybox.label(geo, Vector3(-10.32, 2.75, 0), "", 40, RED, -90)
	clock.name = "ResponseClock"
	level.add_light("lab", Vector3(-13, 3.2, -1.5), 7.0, 1.1)
	level.add_light("lab", Vector3(-13, 3.2, 2.5), 7.0, 0.9)

	rourke = Rourke.new()
	rourke.name = "LabRourke"
	rourke.visible = false
	rourke.position = Vector3(6.9, 0, 7.2)
	rourke.down_time = 1.0e9  # in the lab he stays down: the crew decides what happens to him
	rourke.can_tie = func(p): return cable_holders.has(level.players.id_of(p))
	level.add_child(rourke)
	for id in ["SECLAB-B", "SECLAB-B-REAR"]:
		var g := StaticBody3D.new()
		g.name = "Guard_" + id
		g.position = level.doors[id].position
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = level.doors[id].size
		shape.shape = box
		g.add_child(shape)
		level.add_child(g)
		rourke.add_collision_exception_with(g)  # he walks through; the crew can't
		guards[id] = g
		_guard(id, false)


## Everything that names the lab's zone or its controllers: the door plate, the
## card inside, and the reset switches with their stamped ids. Rebuilt when the
## controllers are re-keyed.
func _place_zone() -> void:
	var geo: Node3D = level.geo
	for n in [_plate, _card] + _stamps + switches.values():
		if is_instance_valid(n):
			n.queue_free()
	_stamps.clear()
	switches.clear()
	_plate = Greybox.label(geo, Vector3(-9.88, 1.75, -1.25), "SECLAB-B\nCTRL ZONE %s" % zone, 22, Color(0.2, 0.2, 0.2), 90)
	_card = Document.place(geo, Vector3(-12.2, 1.4, 3.68), 0, "Secure Lab B door card", [
		"SECURE LAB B  -  DOORS",
		"Main and rear doors: controller zone %s" % zone,
		"Lockdown latches the main door's controller.",
		"It has to be reset by hand, here, in the lab.",
	], false, "laminated", Vector2(0.42, 0.3))
	_card.clues = [{"case": "lab_door", "text": "Lab B's main and rear doors: controller zone %s. Lockdown latches it; reset it by hand in the lab." % zone}]
	_card.pieces = [{"case": "lab_door", "piece": "zone", "text": "controller zone %s" % zone, "kind": "value"}]
	_card.spot = CARD_SPOT
	var ids: Array = data.lab_switches
	for i in ids.size():
		var z := -1.85 + i * 0.25
		var s := Interactable.create(geo, Vector3(-15.64, 1.25, z), Vector3(0.05, 0.14, 0.08), "Reset %s" % ids[i], Color(0.1, 0.1, 0.1))
		s.name = "Switch_" + str(ids[i])
		s.enabled = false
		s.used.connect(_on_switch.bind(ids[i]))
		switches[ids[i]] = s
		var stamp := Greybox.label(geo, Vector3(-15.62, 1.42, z), str(ids[i]), 16, Color(0.9, 0.9, 0.8), 90)
		stamp.name = "Stamp_" + str(ids[i])
		_stamps.append(stamp)


## Is there a betrayal to play? Only while Rourke is still the crew's friendly escort.
func wanted() -> bool:
	return _game().rourke_fate == "unknown"


func _game() -> Node:
	return get_node("/root/Game")


func _net() -> Node:
	return get_node("/root/Net")


## Rourke already turned somewhere else: the lab is just a lab, open, with her terminal.
func skip() -> void:
	phase = "done"
	rourke.visible = false
	rourke.process_mode = Node.PROCESS_MODE_DISABLED
	rourke.position = Vector3(-13, -20, 0)
	_set_door("SECLAB-B", false)
	powered = true
	for s in switches.values():
		s.enabled = true
	_after_lab()
	level.lab_door_opened()


func net_setup() -> void:
	level.sync.replicate(rourke, rourke.sync_properties())


## The whole betrayal, on every machine. Returns once the crew is out of the lab.
func run() -> void:
	var sync: LevelSync = level.sync
	var hud: HUD = level.hud
	phase = "lead"
	_take_over_guide()
	rourke.visible = true
	hud.todo("Last stop: the lab", "Follow Rourke to Dr. Vale's lab")
	# The book's review, on the quiet walk up: same tools as the server floor (M1).
	level._book_huddle("easy_sql_9")
	if sync.is_host():
		_walk_path(LEAD_PATH, "at_door")
	await _gate("at_door")
	if sync.is_host():
		rourke.watch = level.players.nearest(rourke.global_position)
	await _line("l2_lab_arrive")
	await _line("l2_lab_badge_1")
	phase = "badge"
	reader.enabled = true
	hud.todo("Don't fail us now, badges", "Badge in at the lab door")
	await _gate("badged")
	reader.enabled = false
	hud.todo("")
	_log_swipe("R-0117", "ROURKE, D.")
	_set_door("SECLAB-B", false)
	await _line("l2_lab_badge_2")
	# He goes in first, over to her coat.
	phase = "inside"
	rourke.watch = null
	if sync.is_host():
		_walk_path([Vector3(-9, 0, 0), Vector3(-11.5, 0, 0), BY_COAT], "by_coat")
	await _gate("crew_in")
	# From here he's the only one who leaves: the doorway holds the crew in.
	_guard("SECLAB-B", true)
	_keep_crew_in()
	await _gate("by_coat")
	await _line("l2_lab_shock_1")
	await _line("l2_lab_shock_2")
	await _line("l2_lab_terminal")
	hud.todo("What's on her screen?", "Check Dr. Vale's terminal")
	if sync.is_host():
		_walk_path([Vector3(-11.5, 0, 0), Vector3(-9, 0, 0), OUTSIDE], "outside")
	await _gate("outside")
	await _gate("trapped")
	_keeping_in = false
	_lock_in()
	# On the radio first. A few beats for it to land, then nobody's at a terminal.
	await _line(FRAME_LINES[0])
	if sync.is_host():
		_after(FRAME_BEAT, "framed")
	await _gate("framed")
	await _off_terminals()
	# Then through the glass: why, how long he knew, and goodbye. Every view turns to
	# him at the door for a moment, then the crew can move while he talks; before he's
	# done, he's round through the service passage to the rear door.
	_monologue()
	await _face(level.to_global(OUTSIDE) + Vector3.UP * 1.6, FOCUS_TIME)
	await _gate("round_back")
	_guard("SECLAB-B-REAR", true)
	_keep_crew_in()
	_set_door("SECLAB-B-REAR", false)
	while _talking and is_inside_tree():
		await get_tree().process_frame
	await _line("l2_return")
	if sync.is_host():
		_walk_path([INSIDE_REAR], "in_rear")
	await _gate("in_rear")
	_keeping_in = false
	_pull_in()
	_set_door("SECLAB-B-REAR", true)
	_guard("SECLAB-B-REAR", false)
	_start_fight()
	await _gate("resolved")
	await _lockdown()
	await _gate("door_reset")
	await _gate("crew_out")
	# WARDEN seals the floor around them. Tied up, Rourke has cut himself loose and
	# signed the lockdown himself (they hear him on the radio later).
	if fate == "tied":
		level.hud.line("l2_lockdown_tied")
	level.hud.line("l2_sealed")
	phase = "done"


func _process(delta: float) -> void:
	if not level.active:
		return
	_run_clock(delta)
	if not level.sync.is_host():
		return
	# Everyone well inside, clear of the doorway (its guard goes up once they are).
	var inside: bool = level.players.all_players().all(func(p): return _crew_inside(p.global_position))
	if inside and phase == "inside":
		_mark("crew_in")
		if _steps.has("outside"):
			_mark("trapped")
	if phase == "escape" and _steps.has("door_reset") and not _steps.has("crew_out") and level.players.all_players().all(func(p): return not _in_lab(p.global_position)):
		_mark("crew_out")
	if phase == "down" and fate == "":
		_down_for += delta
		if _down_for >= UNTIED_AFTER:
			level.sync.run_on(self, "_resolve", ["untied"])


func _in_lab(p: Vector3) -> bool:
	return Level2Floor.LAB_BOX.has_point(level.to_local(p) + Vector3.UP * 0.5)


func _crew_inside(p: Vector3) -> bool:
	return INSIDE_BOX.has_point(level.to_local(p) + Vector3.UP * 0.5)


## Raise or drop the crew-only wall in a lab doorway, on this machine.
func _guard(id: String, up: bool) -> void:
	guards[id].collision_layer = 1 if up else 0


## Every machine, while Rourke walks out or back in: if this machine's player got out
## of the lab anyway (squeezed past him, or lag), they're back inside, so the doors can
## lock and the frame and the fight can't stall on someone left outside.
func _keep_crew_in() -> void:
	_keeping_in = true
	while _keeping_in and is_inside_tree():
		_pull_in()
		await get_tree().create_timer(0.5, false).timeout


func _pull_in() -> void:
	var p: Node3D = level.player
	if p and not _in_lab(p.global_position):
		p.respawn(respawn_point())


## In the World, the Rourke who walked the crew up from the server floor takes this one's place.
func _take_over_guide() -> void:
	if level.world:
		var prev: Node = level.world.wings.get("level_1")
		var guide = prev.get("rourke") if prev else null
		if is_instance_valid(guide):
			rourke.global_transform = guide.global_transform
			guide.queue_free()
		var held = prev.get("cable_holders") if prev else null
		if held is Dictionary:
			cable_holders.merge(held)


# --- Steps -------------------------------------------------------------------

## Host: a story step happened. Every machine waiting on it carries on.
func _mark(key: String) -> void:
	if _steps.has(key):
		return
	_steps[key] = true
	_step.emit(key)


## Wait, on every machine, for the host to mark a step.
func _gate(key: String) -> void:
	await level.sync.gate("lab_" + key, func():
		if not _steps.has(key):
			while await _step != key:
				pass)


## Host: Rourke walks a route of straight steps, then marks `key`.
func _walk_path(points: Array, key: String) -> void:
	for p in points:
		rourke.walk_to(level.to_global(p), true)
		await rourke.arrived
	_mark(key)


## Host: mark `key` after `seconds`.
func _after(seconds: float, key: String) -> void:
	await get_tree().create_timer(seconds, false).timeout
	_mark(key)


## Every machine: the monologue through the glass, the lines after the radio call.
## The host sends him round to the rear door partway through, timed to get there
## just before the last line ends (on the last line at the latest, he sets off at once).
func _monologue() -> void:
	_talking = true
	var lines := FRAME_LINES.slice(1)
	var walk := _path_length(OUTSIDE, ROUND_BACK) / Rourke.WALK_SPEED
	var sneaking := false
	for i in lines.size():
		var left := 0.0
		for id in lines.slice(i):
			left += line_time(id) + HUD.GAP_SAME  # each line waits its breath after the last (HUD)
		if level.sync.is_host() and not sneaking and left - SNEAK_IN_BEFORE_END <= walk + line_time(lines[i]):
			sneaking = true
			_sneak_round(maxf(0.0, left - SNEAK_IN_BEFORE_END - walk))
		await _line(lines[i])
	_talking = false


## Host: wait `delay`, then round through the service passage to the rear door.
func _sneak_round(delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	_walk_path(ROUND_BACK, "round_back")


## How long a line takes: its recording, or the time to read it.
static func line_time(id: String) -> float:
	var stream := Voice.stream_for(id)
	if stream:
		return stream.get_length()
	var l := VoiceLines.get_line(id)
	return Voice.read_time(l["text"]) if not l.is_empty() else LINE_GAP


static func _path_length(from: Vector3, points: Array) -> float:
	var total := 0.0
	var at := from
	for p in points:
		total += at.distance_to(p)
		at = p
	return total


## Every machine: this machine's player comes off any terminal, and its screen closes.
func _off_terminals() -> void:
	var p: Player = level.player
	if not p:
		return
	if p.is_using_terminal():
		p.leave_terminal()
	var ui = level.get("terminal_ui")
	if ui and ui.visible:
		ui.close()
	var t := 0.0
	while p.is_using_terminal() and t < 2.0 and is_inside_tree():
		t += get_physics_process_delta_time()
		await get_tree().physics_frame


## Every machine: this machine's player can't move or look away while their view
## turns to `point` and holds there for `seconds`; then it's theirs again.
func _face(point: Vector3, seconds: float) -> void:
	var p: Player = level.player
	if not p:
		return
	var was := p.input_locked
	p.input_locked = true
	var t := 0.0
	while t < seconds and is_inside_tree() and is_instance_valid(p):
		var d := point - p.head.global_position
		var k := clampf(get_physics_process_delta_time() * 6.0, 0.0, 1.0)
		p.rotation.y = lerp_angle(p.rotation.y, atan2(-d.x, -d.z), k)
		var pitch := atan2(d.y, Vector2(d.x, d.z).length())
		p.head.rotation.x = lerp_angle(p.head.rotation.x, clampf(pitch, -1.2, 1.2), k)
		t += get_physics_process_delta_time()
		await get_tree().physics_frame
	if is_instance_valid(p):
		p.input_locked = was


## A line, or a beat in its place if Voice hasn't recorded it yet.
func _line(id: String) -> void:
	if VoiceLines.get_line(id).is_empty():
		await get_tree().create_timer(LINE_GAP, false).timeout
	else:
		await level.hud.line(id)


func _set_door(id: String, locked: bool) -> void:
	level.db.run_silent("UPDATE doors SET locked = %d WHERE id = '%s'" % [1 if locked else 0, id])
	level.db.sync_world()


# --- Badges ------------------------------------------------------------------

## What a card reader shows when it turns someone away: no badge on them, or a badge
## without clearance for that door (Augustine's wording, 2026-10-19).
const DENIED_NO_BADGE := "> ACCESS DENIED: NO BADGE READ"
const DENIED_NOT_AUTHORIZED := "> ACCESS DENIED: NOT AUTHORIZED"


## The presser's machine: the reader wants the visitor badge Rourke clipped on them.
func _on_reader(p: Node) -> void:
	if not p.inventory.has("visitor_badge"):
		level.hud.notice(DENIED_NO_BADGE, 2.5, ThemeUtil.RED)
		return
	reader_relay.interact(p)


## Host: someone swiped their visitor badge.
func _on_badge_swiped(p: Node) -> void:
	var id: int = level.players.id_of(p)
	if phase != "badge" or badged.has(id):
		return
	level.sync.run_on(self, "_badged", [id, badge_no(id)])


## A player's visitor badge number, the same on every machine: Level 0 numbers them
## in player order (Game.visitor_badge_no is this machine's). If the order can't
## place them, the next free number.
func badge_no(id: int) -> String:
	var i := NetPlayers.index_of(id, multiplayer)
	return "VIS-%02d" % (i + 1 if i >= 0 else badged.size() + 1)


## Every machine: one more crew member is on the visitor log.
func _badged(id: int, badge: String) -> void:
	if badged.has(id):
		return
	badged[id] = true
	_log_swipe(badge, "BYTE-RIGHT IT (VISITOR)")
	level.hud.notice("> BADGE %s: VISITOR LOGGED, SECLAB-B" % badge, 2.5, ThemeUtil.GREEN)
	if level.sync.is_host() and badged.size() >= level.players.count():
		_mark("badged")


func _log_swipe(badge: String, holder: String) -> void:
	level.db.run_silent("INSERT INTO badge_log VALUES ('1997-10-16 %s', '%s', '%s', 'SECLAB-B')" % [level.server_time(), badge, holder])


# --- The frame and the fight -------------------------------------------------

## The door locks with the crew inside. Red light, and her terminal locks too.
func _lock_in() -> void:
	phase = "locked"
	_set_door("SECLAB-B", true)
	_guard("SECLAB-B", false)
	level.db.run_silent("UPDATE door_status SET note = 'lockdown: controller latched' WHERE door_id = 'SECLAB-B'")
	level.hud.notice("> DOOR SECLAB-B: LOCKED", 3.0, ThemeUtil.RED)
	_lab_lights(RED)
	if level.terminal_ui.terminal == terminal:
		level.terminal_ui.close()
	terminal.locked = true
	terminal.locked_message = "SESSION LOCKED BY USER ROURKE_D."
	terminal.set_screen_color(Color(1.0, 0.25, 0.2))
	level.hud.todo("Locked in. This is no glitch.", "Get out of the lab")


func _lab_lights(c: Color) -> void:
	for id in ["lab", "patrol"]:
		for l in level.lights.get(id, []):
			l.light_color = c


func _start_fight() -> void:
	phase = "fight"
	rourke.add_to_group(VoiceChat.INTERFERENCE_GROUP)
	rourke.max_hits = Rourke.MAX_HITS + 2 * (level.players.count() - 1)
	rourke.hits_left = rourke.max_hits
	level.hud.todo("He set us up!", "Fight Rourke off, then decide what to do with him")
	level.hud.notice(FIGHT_NOTICE, 6.0)
	if level.sync.is_host():
		if not level.crew.hit_blocked.is_connected(_on_blocked):
			level.crew.hit_blocked.connect(_on_blocked)
		rourke.downed.connect(func(): level.sync.run_on(self, "_on_downed"))
		rourke.resolved.connect(func(f): level.sync.run_on(self, "_resolve", [f]))
		rourke.hit_player.connect(_bark.bind(FIGHT_BARKS))
		rourke.struck.connect(_bark.bind(HURT_BARKS))
		rourke.start_chase(level.players.nearest(rourke.global_position))


## Host: someone blocked his swing, and he reels.
func _on_blocked(_id: int, cause: String) -> void:
	if cause == "rourke" and phase == "fight":
		rourke.recoil()


## Every machine: Rourke downed the whole crew. The frame worked: the next
## morning's paper and the radio say so (NewsEnding), then everyone comes to in
## the lab and the fight starts over.
func crew_beaten() -> void:
	var news := NewsEnding.new()
	news.hud = level.hud
	level.add_child(news)
	await news.run()
	level.crew.send_everyone_back()
	await level.get_tree().create_timer(0.7).timeout  # under the death fade
	news.queue_free()
	# A secret ending: whoever saw it keeps what it unlocks (shown once they're back up).
	_net().earn("secret:ending_news", level.hud)
	if level.sync.is_host():
		reset_fight()


## Host: a short fight line, at most one every few seconds.
func _bark(ids: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_bark < BARK_GAP:
		return
	_last_bark = now
	level.sync.run_on(self, "_say", [ids.pick_random()])


func _say(id: String) -> void:
	level.hud.line(id)


func _on_downed() -> void:
	phase = "down"
	_down_for = 0.0
	_last_bark = Time.get_ticks_msec() / 1000.0
	level.hud.line("l2_downed")


## Every machine: what the crew did with him. Left untied, they can still come
## back and tie him (with cable) or finish it while he's lying there.
func _resolve(f: String) -> void:
	if fate != "" and not (fate == "untied" and f != "untied"):
		return
	var first := fate == ""
	fate = f
	_game().rourke_fate = f
	if f == "untied":
		phase = "escape"
	else:
		rourke.remove_from_group("interactable")
	if first:
		level.hud.notice("You took Rourke's badge (R-0117).", 4.0)
		_mark_everywhere("resolved")
	if f == "killed":
		await level.hud.line("l2_killed")
	elif f == "tied":
		await level.hud.lines(["l2_tied_1", "l2_tied_2"])
		await _line("l2_tied_3")


## Steps that every machine reaches together anyway don't need the host to mark them.
func _mark_everywhere(key: String) -> void:
	_steps[key] = true
	_step.emit(key)


## WARDEN starts containment, its PA talks over it, and her terminal unlocks on
## Rourke's badge, showing what it takes to get the door open.
func _lockdown() -> void:
	phase = "escape"
	level.set_all_lights_color(RED)
	level.hud.notice("WARDEN LOCKDOWN ACTIVE", 5.0, ThemeUtil.RED)
	await _line("l2_contain_1")
	await level.hud.line("l0_sort_hint")
	await get_tree().create_timer(2.0, false).timeout
	await _line("l2_contain_2")
	# Unlocked, but still red: it turns green when someone sits down on Rourke's badge.
	terminal.locked = false
	_boot_lockdown()
	for s in switches.values():
		s.enabled = true
	level.hud.todo("Still trapped. Think fast.", "Find out what's wrong with the lab door, at Dr. Vale's terminal")
	_open_door_case()
	# The clock waits for the first query (M2).
	clock_waiting = true


## Her terminal's lockdown screen, then SYSOP's tip under it. Put on the screen now,
## on every machine, so the tip isn't wiped when someone sits down.
func _boot_lockdown() -> void:
	terminal.reboot(_lockdown_lines())
	terminal.ensure_booted()
	terminal.print_line(TerminalUI.sysop("two conditions? WHERE the first, AND the second. same as the server floor."))


## T1: the lockdown screen, six lines.
func _lockdown_lines() -> Array:
	return [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  SECURE LAB B",
		"Badge R-0117 accepted (ROURKE, D.)",
		"[color=#ff6655]LOCKDOWN: INCIDENT IN SECURE LAB B. REPORTED BY R-0117.[/color]",
		"[color=#ff6655]DOOR SECLAB-B: CONTROLLER LATCHED, STATUS 'fault'. MANUAL RESET REQUIRED.[/color]",
		"Door controllers are rows in [b]door_controllers[/b]. This lab's zone is on the door card over the bench.",
		"Stuck? Type [b].hint[/b]",
	]


## Every machine: the lab door's case is open, with its pieces, its query and its
## slot: the controller, pointed at on screen.
func _open_door_case() -> void:
	var game := _game()
	game.open_case("lab_door", LAB_CASE, ["door_controllers"])
	game.set_pieces("lab_door", lab_pieces(zone), LAB_QUERY)
	game.set_blank("lab_door", LAB_SLOT, ["\u0001"], data.lab_answer, {"column": "id", "values": [data.lab_answer], "rows": [{"id": data.lab_answer}]})


## The pencil note for a pointed-at cell that isn't the lab door's controller, or
## "" when the cell isn't about the door controllers.
func door_miss(shown: Dictionary) -> String:
	var rows: Array = level.rows_like("door_controllers", shown)
	if rows.is_empty():
		return ""
	if rows.all(func(r): return r.id == data.lab_answer):
		return LAB_ROW
	if rows.all(func(r): return r.zone == zone and r.status == "offline"):
		return LAB_OFFLINE
	if rows.all(func(r): return r.zone != zone and r.status == "fault"):
		return LAB_ELSEWHERE
	return LAB_OTHER


## Every machine: the lab door is open. Rourke's session is over: her terminal
## reboots as a guest's, under the policy (part 2).
func _after_lab() -> void:
	terminal.policy = true
	terminal.locked = false
	terminal.set_screen_color(SCREEN_GREEN)
	terminal.reboot(AFTER_LINES)


# --- The security response ---------------------------------------------------

## Every machine: WARDEN sends a security response, and the clock over the door starts.
func _start_response() -> void:
	clock_waiting = false
	response_left = RESPONSE_TIME
	_show_clock()
	level.hud.notice("WARDEN (PA): SECURITY RESPONSE TO SECURE LAB B: %d MINUTES" % int(RESPONSE_TIME / 60.0), 6.0, ThemeUtil.RED)


## Every machine counts down; the host decides when the response arrives.
func _run_clock(delta: float) -> void:
	if response_left < 0.0 or phase != "escape":
		return
	var before := response_left
	response_left = maxf(0.0, response_left - delta)
	for t in RESPONSE_CALLS:
		if before > t and response_left <= t:
			level.hud.notice("WARDEN (PA): SECURITY RESPONSE TO SECURE LAB B: %d SECONDS" % int(t), 4.0, ThemeUtil.RED)
	_show_clock()
	if response_left <= 0.0 and level.sync.is_host():
		response_left = -1.0
		level.sync.run_on(self, "_caught")


func _show_clock() -> void:
	if response_left < 0.0:
		clock.text = ""
		return
	var s := int(ceilf(response_left))
	clock.text = "RESPONSE  %d:%02d" % [s / 60, s % 60]


## Every machine: the response arrived first. The crew is dragged back into the lab,
## WARDEN re-keys its controllers to another zone, and the escape starts over.
func _caught() -> void:
	phase = "caught"
	response_left = -1.0
	_show_clock()
	for s in switches.values():
		s.enabled = false
	if level.terminal_ui.terminal == terminal:
		level.terminal_ui.close()
	level.hud.notice("SECURITY RESPONSE ON SITE. OCCUPANTS DETAINED.", 4.0, ThemeUtil.RED)
	await level.hud.fade(true, 1.0)
	caught += 1
	var k := Level2Data.lab_rekey(_game().run_seed, caught, zone)
	level.db.run_silent(k.sql)
	level.db.run_silent("UPDATE door_status SET note = 'lockdown: controller latched' WHERE door_id = 'SECLAB-B'")
	zone = k.zone
	data.lab_zone = k.zone
	data.lab_answer = k.answer
	data.lab_switches = k.switches
	door_puzzle = door_puzzle_for(zone)
	terminal.puzzles = [door_puzzle]
	switches_locked_until = 0.0
	powered = false
	door_listed = false
	_place_zone()
	level.player.respawn(respawn_point())
	await get_tree().create_timer(1.5, false).timeout
	await level.hud.fade(false, 1.0)
	level.hud.notice("WARDEN (PA): SECURE LAB B CONTROLLERS RE-KEYED. OCCUPANTS HELD FOR QUESTIONING.", 5.0, ThemeUtil.RED)
	# Everything noted on the lab door's page named the old zone (the card, SYSOP's
	# hints and answer): only the re-key is left, so nobody skims a stale zone.
	var page: Dictionary = _game().case_info("lab_door")
	if not page.is_empty():
		page.clues.clear()
	_game().add_clue("lab_door", "WARDEN re-keyed the lab's controllers. The zone on the door card has changed.", "WARDEN")
	# The zone piece and the slot empty; the card's new zone fills the piece again.
	_game().forget("lab_door", ["zone"])
	phase = "escape"
	_boot_lockdown()
	for s in switches.values():
		s.enabled = true
	level.hud.todo("Still trapped. Think fast.", "Find out what's wrong with the lab door, at Dr. Vale's terminal")
	_open_door_case()
	clock_waiting = true


# --- The way out -------------------------------------------------------------

## Host: someone sat down at her terminal.
func _on_opened(_by: Node) -> void:
	if phase == "escape" and not logged_in:
		level.sync.run_on(self, "_log_in")


## Every machine: Rourke's badge logs her terminal in. WARDEN greets him, and the
## crew reads its self-test: two faults on the floor, neither its problem.
func _log_in() -> void:
	if logged_in:
		return
	logged_in = true
	terminal.set_screen_color(SCREEN_GREEN)
	# Her screen names the table and the status: both are found reading it (T1).
	_game().collect_piece("lab_door", "table", SCREEN)
	_game().collect_piece("lab_door", "status", SCREEN)
	level.hud.line("l2_login")
	level.hud.line("l2_selftest")


## Does this result show door controllers (any of their ids, or their zone and status)?
func _shows_controllers(result: Dictionary) -> bool:
	if not result.get("ok", false) or result.get("rows", []).is_empty():
		return false
	var cols: Array = result.get("columns", [])
	if cols.has("zone") and cols.has("status"):
		return true
	var ids := {}
	for r in level.db.run_silent("SELECT id FROM door_controllers"):
		ids[str(r["id"])] = true
	return result.rows.any(func(row): return row.values().any(func(v): return ids.has(str(v))))


## Host: a query ran at her terminal (or failed there: the clock starts either way).
func _on_query(_sql: String, result: Dictionary, _ui: TerminalUI = null) -> void:
	if phase == "escape":
		if not logged_in:
			level.sync.run_on(self, "_log_in")
		if clock_waiting:
			level.sync.run_on(self, "_start_response")
		if not _reacted.has("found") and _shows_controllers(result):
			_reacted["found"] = true
			level.sync.run_on(self, "_say", ["l2_found"])
	if not door_puzzle.solved and not door_listed and phase == "escape" and door_puzzle.matches(level.db, result):
		door_listed = true  # the step waits for the crew to point at its id


## Host: a refused or failed query at her terminal.
func _on_query_failed(sql: String, result: Dictionary) -> void:
	if level.sync.is_host():
		_on_query(sql, result)


## Every machine: the crew pointed at the latched controller. The switches have power.
func _door_found() -> void:
	if door_puzzle.solved:
		return
	door_puzzle.solved = true
	powered = true
	terminal.print_line("")
	terminal.print_line(TerminalUI.sysop("that's the lab door's controller. zone %s, 'fault'. its switch is on the wall in there." % zone))
	level.hud.todo("Same trick as the server floor", "Reset the lab door's controller at its switch on the lab wall")
	_game().add_clue("lab_door", "%s is the lab door's controller: zone %s, 'fault'. Its reset switch is on the lab wall." % [data.lab_answer, zone], "SYSOP")


## Host: someone pressed a reset switch. The host decides; everyone sees it.
func _on_switch(_p: Node, id: String) -> void:
	if phase != "escape" or _steps.has("door_reset"):
		return
	if not powered:
		level.sync.run_on(self, "_switch_result", [id, "no_power", 0.0])
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < switches_locked_until:
		level.sync.run_on(self, "_switch_result", [id, "locked", switches_locked_until - now])
		return
	if id != data.lab_answer:
		var row: Dictionary = level.db.run_silent("SELECT status FROM door_controllers WHERE id = '%s'" % id)[0]
		level.sync.run_on(self, "_switch_result", [id, "healthy" if row["status"] == "ok" else "wrong", LOCKOUT])
		return
	level.sync.run_on(self, "_switch_result", [id, "reset", 0.0])


func _switch_result(id: String, outcome: String, seconds: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var row: Dictionary = level.db.run_silent("SELECT status, zone, location, note FROM door_controllers WHERE id = '%s'" % id)[0]
	match outcome:
		"no_power":
			level.hud.notice(NO_POWER % id, 4.0, ThemeUtil.RED)
			return
		"locked":
			switches_locked_until = now + seconds
			level.hud.notice("SWITCHES LOCKED: tamper lockout, %d s" % int(seconds), 2.0, ThemeUtil.RED)
			return
		"healthy":
			level.hud.notice("> %s: %s, OK. NOTHING TO RESET." % [id, row["location"]], 4.0)
			_warden("l2_panel_ok")
			return
		"wrong":
			switches_locked_until = now + seconds
			level.hud.notice("> %s: %s, '%s': %s\n> RESET REFUSED. SWITCHES LOCKED: %d s" % [id, row["location"], row["status"], row["note"], int(seconds)], 6.0, ThemeUtil.RED)
			_warden("l2_panel_wrong")
			level.comment_mistake("switch")
			return
	level.db.run_silent("UPDATE door_controllers SET status = 'ok', last_reset = '1997-10-16 %s' WHERE id = '%s'" % [level.server_time().left(5), id])
	_set_door("SECLAB-B", false)
	for s in switches.values():
		s.enabled = false
	response_left = -1.0
	_show_clock()
	# The alarm ends. Whatever comes next, it's quiet for a while.
	level.set_all_lights_color(WHITE)
	level.hud.notice("> CONTROLLER %s: RESET OK\n> DOOR SECLAB-B: OPENED" % id, 4.0, ThemeUtil.GREEN)
	level.hud.line("l2_exit_open")
	_game().solve_case("lab_door", "%s, reset by hand at its switch. The lab door opened." % id)
	_after_lab()
	level.lab_door_opened()
	_mark_everywhere("door_reset")
	if level.sync.is_host():
		_mark("door_reset")


## WARDEN reacting to a switch, unless it just said the same thing.
func _warden(id: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _warden_at.get(id, -100.0) < WARDEN_REPEAT:
		return
	_warden_at[id] = now
	level.hud.line(id)


## Where someone who dies in the lab comes to.
func respawn_point() -> Transform3D:
	return level.global_transform * Transform3D(Basis(), RESPAWN)


## Solo, a lost fight starts over from the rear door.
func reset_fight() -> void:
	if phase == "fight":
		rourke.reset_fight(level.global_transform * Transform3D(Basis(Vector3.UP, -PI / 2), INSIDE_REAR))


func in_progress() -> bool:
	return phase in ["locked", "fight", "down", "escape", "caught"] and not _steps.has("crew_out")
