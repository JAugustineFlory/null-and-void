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
## Left down without cable, Rourke stays down this long before the crew's choice counts.
const UNTIED_AFTER := 15.0
const LOCKOUT := 10.0
## How long the crew has to get the lab door open once the lockdown starts.
const RESPONSE_TIME := 240.0
## When WARDEN's PA calls out the time left.
const RESPONSE_CALLS := [60.0, 30.0]
const RED := Color(1.0, 0.18, 0.12)
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

var door_puzzle: Puzzle
var log_puzzle := Puzzle.new("badge_log", "SELECT time, badge_id FROM badge_log ORDER BY time", ["time", "badge_id"], true, [
	"type this, then Enter:\n" +
	"    [color=#ffffff]SELECT * FROM badge_log ORDER BY time;[/color]\n" +
	"  SELECT * FROM badge_log  every swipe at every reader on this floor\n" +
	"  ORDER BY time            sorted by when it happened, earliest first",
	"read down the door column for SECLAB-B. who came in, and when?",
])


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
## Hints: the shape with the zone left as '?', then where the zone is, then the query.
static func door_puzzle_for(zone: String) -> Puzzle:
	return Puzzle.new("lab_door", "SELECT id FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % zone, ["id"], false, [
		"the shape, with the zone left as ?:\n" +
		"    [color=#ffffff]SELECT * FROM door_controllers WHERE zone = '?' AND status = 'fault';[/color]\n" +
		"  SELECT *               every column\n" +
		"  FROM door_controllers  the building's door controllers\n" +
		"  WHERE zone = '?'       only this lab's zone\n" +
		"  AND status = 'fault'   ...that are ALSO faulted. both must be true\n" +
		"? is this lab's controller zone. it's on the plate by the door, and on a card in here.",
		"the door card hangs over the bench. it says \"controller zone\" and a letter. put that letter where the ? is.",
		"type this, then Enter:\n" +
		"    [color=#ffffff]SELECT * FROM door_controllers WHERE zone = '%s' AND status = 'fault';[/color]\n" % zone +
		"the id it gives you is the one to reset. the switches are on this lab's wall, by the coat. " +
		"press E on the one with that id. the others in zone %s are offline or ok: read their note column." % zone,
	])

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
	terminal.puzzles = [door_puzzle, log_puzzle]
	terminal.boot_lines = [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  SECURE LAB B",
		"Session: VALE_I",
		"",
		"> notes/batch_7.txt",
		"  Cold storage still logging the wrong temperatures. Not the sensors.",
		"  Someone is editing the records after I sign them.",
	]
	terminal.queried.connect(_on_query)
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
	_boot_lockdown()
	for s in switches.values():
		s.enabled = true


func net_setup() -> void:
	level.sync.replicate(rourke, rourke.sync_properties())


## The whole betrayal, on every machine. Returns once the crew is out of the lab.
func run() -> void:
	var sync: LevelSync = level.sync
	var hud: HUD = level.hud
	phase = "lead"
	_take_over_guide()
	rourke.visible = true
	hud.todo("Follow Rourke to Dr. Vale's lab")
	if sync.is_host():
		_walk_path(LEAD_PATH, "at_door")
	await _gate("at_door")
	if sync.is_host():
		rourke.watch = level.players.nearest(rourke.global_position)
	await _line("l2_lab_arrive")
	await _line("l2_lab_badge_1")
	phase = "badge"
	reader.enabled = true
	hud.todo("Badge in at the lab door")
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
	hud.todo("Check Dr. Vale's terminal")
	if sync.is_host():
		_walk_path([Vector3(-11.5, 0, 0), Vector3(-9, 0, 0), OUTSIDE], "outside")
	await _gate("outside")
	await _gate("trapped")
	_keeping_in = false
	_lock_in()
	# On the radio, then through the glass: why, how long he knew, and goodbye.
	for id in FRAME_LINES:
		await _line(id)
	# Round through the service passage to the rear door.
	if sync.is_host():
		_walk_path(ROUND_BACK, "round_back")
	await _gate("round_back")
	_guard("SECLAB-B-REAR", true)
	_keep_crew_in()
	_set_door("SECLAB-B-REAR", false)
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
	level.hud.todo("Get out of the lab")


func _lab_lights(c: Color) -> void:
	for id in ["lab", "patrol"]:
		for l in level.lights.get(id, []):
			l.light_color = c


func _start_fight() -> void:
	phase = "fight"
	rourke.add_to_group(VoiceChat.INTERFERENCE_GROUP)
	rourke.max_hits = Rourke.MAX_HITS + 2 * (level.players.count() - 1)
	rourke.hits_left = rourke.max_hits
	level.hud.todo("Deal with Rourke")
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
	terminal.locked = false
	terminal.set_screen_color(Color(0.2, 0.9, 0.35))
	_boot_lockdown()
	for s in switches.values():
		s.enabled = true
	level.hud.todo("Find out what's wrong with the lab door")
	_game().open_case("lab_door", LAB_CASE, ["door_controllers"])
	# The book's review, before the clock starts: same tools as the server floor.
	await level._book_huddle("easy_sql_9")
	_start_response()


## Her terminal's lockdown screen, then SYSOP's tip under it. Put on the screen now,
## on every machine, so the tip isn't wiped when someone sits down.
func _boot_lockdown() -> void:
	terminal.reboot(_lockdown_lines())
	terminal.ensure_booted()
	terminal.print_line(TerminalUI.sysop("two conditions? WHERE the first, AND the second. same as the server floor."))


func _lockdown_lines() -> Array:
	return [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  SECURE LAB B",
		"Badge R-0117 accepted (ROURKE, D.)",
		"",
		"[color=#ff6655]LOCKDOWN: INCIDENT IN SECURE LAB B. REPORTED BY R-0117.[/color]",
		"[color=#ff6655]DOOR SECLAB-B: CONTROLLER LATCHED. MANUAL RESET REQUIRED.[/color]",
		"",
		"Door controllers are rows in [b]door_controllers[/b]. This lab's zone is on its door plate.",
		"Every badge swipe on this floor is in [b]badge_log[/b]: the time, the badge, the door.",
		"Type .help for commands, .hint if you're stuck.",
	]


# --- The security response ---------------------------------------------------

## Every machine: WARDEN sends a security response, and the clock over the door starts.
func _start_response() -> void:
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
	terminal.puzzles = [door_puzzle, log_puzzle]
	switches_locked_until = 0.0
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
	phase = "escape"
	_boot_lockdown()
	for s in switches.values():
		s.enabled = true
	level.hud.todo("Find out what's wrong with the lab door")
	_game().open_case("lab_door", LAB_CASE, ["door_controllers"])
	_start_response()


# --- The way out -------------------------------------------------------------

## Host: a query ran at her terminal.
func _on_query(_sql: String, result: Dictionary, _ui: TerminalUI) -> void:
	if not door_puzzle.solved and phase == "escape" and door_puzzle.matches(level.db, result):
		level.sync.run_on(self, "_door_found")
	if not log_puzzle.solved and log_puzzle.matches(level.db, result):
		level.sync.run_on(self, "_log_read")


func _door_found() -> void:
	door_puzzle.solved = true
	terminal.print_line("")
	terminal.print_line(TerminalUI.sysop("that's the lab door's controller. zone %s, 'fault'. its switch is on the wall in there." % zone))
	level.hud.todo("Reset the lab door's controller")
	_game().add_clue("lab_door", "%s is the lab door's controller: zone %s, 'fault'. Its reset switch is on the lab wall." % [data.lab_answer, zone], "SYSOP")


## The visitor log, sorted: the crew's own badges, at the scene, minutes ago. Nobody
## says what it means: Vale's 23:12, Rourke's rear door at 23:40, and the server
## floor's syslog are for the players to put together.
func _log_read() -> void:
	log_puzzle.solved = true


## Host: someone pressed a reset switch. The host decides; everyone sees it.
func _on_switch(_p: Node, id: String) -> void:
	if phase != "escape" or _steps.has("door_reset"):
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
		"locked":
			switches_locked_until = now + seconds
			level.hud.notice("SWITCHES LOCKED: tamper lockout, %d s" % int(seconds), 2.0, ThemeUtil.RED)
			return
		"healthy":
			level.hud.notice("> %s: %s, OK. NOTHING TO RESET." % [id, row["location"]], 4.0)
			return
		"wrong":
			switches_locked_until = now + seconds
			level.hud.notice("> %s: %s, '%s': %s\n> RESET REFUSED. SWITCHES LOCKED: %d s" % [id, row["location"], row["status"], row["note"], int(seconds)], 6.0, ThemeUtil.RED)
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
	_game().solve_case("lab_door", "%s, reset by hand at its switch. The lab door opened." % id)
	_mark_everywhere("door_reset")
	if level.sync.is_host():
		_mark("door_reset")


## Where someone who dies in the lab comes to.
func respawn_point() -> Transform3D:
	return level.global_transform * Transform3D(Basis(), RESPAWN)


## Solo, a lost fight starts over from the rear door.
func reset_fight() -> void:
	if phase == "fight":
		rourke.reset_fight(level.global_transform * Transform3D(Basis(Vector3.UP, -PI / 2), INSIDE_REAR))


func in_progress() -> bool:
	return phase in ["locked", "fight", "down", "escape", "caught"] and not _steps.has("crew_out")
