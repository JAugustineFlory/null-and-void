class_name Commentary
extends Node
## The crew thinking out loud: short lines from the player characters when they
## find something, get stuck, make the same mistake twice, or solve a puzzle.
## The words are in VoiceLines (speaker CREW); each playable character records
## them in audio/voice/crew_<character>/, and until then they play as subtitles.
##
## The host decides everything and every machine plays the line. Levels tell it
## what happened:
##     commentary.begin("controller")          # a puzzle is now the crew's job
##     commentary.mistake("table")             # a failed query (see kind_of())
##     commentary.discover("right_rack", peer) # a moment with a discovery line
##     commentary.solved()                     # plays the payoff
## and hold()/pause()/typing() keep it quiet while other dialogue, a cut-scene
## or someone's typing is going on. Reading a paper is picked up on its own
## (watch_documents), and `.hint` should call hinted().
##
## The rules (Teaching owns the numbers): no nudge in the first QUIET_START_S of
## a puzzle, Nudge 1 at NUDGE1_S (skipped under a timer), Nudge 2 after
## NUDGE2_FAILS failed queries or NUDGE2_S, at most MAX_NUDGES per puzzle and
## COOLDOWN_S between lines. Hints stay on demand; nothing here delays them.

const NUDGE1_S := 60.0
const NUDGE2_S := 120.0
## Under a timer Nudge 1 is skipped and Nudge 2 comes sooner.
const NUDGE2_TIMED_S := 60.0
const NUDGE2_FAILS := 2
const COOLDOWN_S := 45.0
const QUIET_START_S := 30.0
const MAX_NUDGES := 2

## Nudge 2 for every puzzle: it points at SYSOP as a person on the screen.
const NUDGE2_FIRST := "cc_nudge2_first"
const NUDGE2 := "cc_nudge2"

## What each puzzle says, by puzzle id (the id given to Puzzle.new):
##   disc: {event: line} plays once, when the event happens. "read:<title>"
##         is a paper with that title being read.
##   n1: {unseen, seen, doc}: Nudge 1. `seen` plays once `doc` (a paper in the
##       room) has been read, `unseen` before that; either may be missing.
##   errors: {kind: line} plays when the same kind of mistake happens twice.
##   pay: lines played in order after the solve.
## Every line points at where to look, never at a value, a table the crew
## hasn't seen, or SQL (script/drafts/commentary-floors-0-2.md).
const NUDGES := {
	# Ground floor
	"peek": {
		"disc": {"read:ScanRight 3000 - Quick Start": "l0_cc_peek_card"},
		"n1": {"unseen": "l0_cc_peek_n1a", "seen": "l0_cc_peek_n1b", "doc": "ScanRight 3000 - Quick Start"},
		"errors": {"table": "l0_cc_peek_err"},
		"pay": ["l0_cc_peek_pay"],
	},
	"memo": {
		"disc": {"memo_scraps": "l0_cc_memo_disc"},
		"n1": {"unseen": "l0_cc_memo_n1a", "seen": "l0_cc_memo_n1b", "doc": "ScanRight 3000 - Quick Start"},
		"errors": {"backwards": "l0_cc_memo_back"},
		"pay": ["l0_cc_memo_pay"],
	},
	"caller": {
		"disc": {"work_order": "l0_cc_caller_order", "read:HALCYON STAFF DIRECTORY": "l0_cc_caller_list"},
		"n1": {"unseen": "l0_cc_caller_n1a", "seen": "l0_cc_caller_n1b", "doc": "HALCYON STAFF DIRECTORY"},
		"errors": {"column": "l0_cc_caller_err"},
		"pay": ["l0_cc_caller_pay"],
	},
	"last_visitor": {
		"disc": {"read:Visitor book": "l0_cc_book_disc"},
		"n1": {"seen": "l0_cc_book_n1", "doc": "Visitor book"},
		"pay": ["l0_cc_book_pay"],
	},
	# Server floor
	"controller": {
		"disc": {"read:NOC SHIFT LOG": "l1_cc_log", "read:SERVER ROOM A - DOOR CONTROLLERS": "l1_cc_sheet",
			"right_rack": "l1_cc_payoff_2"},
		"n1": {"unseen": "l1_cc_nudge1_a", "seen": "l1_cc_nudge1_b", "doc": "NOC SHIFT LOG"},
		"errors": {"table": "l1_cc_err_table", "reset": "l1_cc_err_reset"},
		"pay": ["l1_cc_payoff_1"],
	},
	"hot_rack": {
		"disc": {"read:Fire interlock": "l1_cc_hot_plate"},
		"n1": {"unseen": "l1_cc_hot_n1a", "seen": "l1_cc_hot_n1b", "doc": "SERVER ROOM B - RACK MONITORING"},
		"errors": {"backwards": "l1_cc_hot_err"},
		"pay": ["l1_cc_hot_pay"],
	},
	# Security floor
	"badge_log": {
		"disc": {"read:Badge reader card": "l2_cc_reader_card"},
		"n1": {"seen": "l2_cc_log_n1", "doc": "Badge reader card"},
		"pay": ["l2_cc_log_pay"],
	},
	"lab_door": {
		"disc": {"read:Secure Lab B door card": "l2_cc_doorcard"},
		"errors": {"switch": "l2_cc_switch_err"},
		"pay": ["l2_cc_door_pay"],
	},
	"cameras": {
		"disc": {"read:Camera system card": "l2_cc_camcard"},
		"n1": {"unseen": "l2_cc_cam_n1a", "seen": "l2_cc_cam_n1b", "doc": "Camera system card"},
		"pay": ["l2_cc_cam_pay"],
	},
	"pike": {
		"disc": {"read:NIGHT SHIFT SIGN-IN      DATE: 10/15": "l2_cc_sheet"},
		"n1": {"seen": "l2_cc_pike_n1", "doc": "NIGHT SHIFT SIGN-IN      DATE: 10/15"},
		"errors": {"spelling": "l2_cc_pike_err"},
		"pay": ["l2_cc_pike_pay"],
	},
	"door": {
		"disc": {"door_lie": "l2_cc_lie"},
		"n1": {"unseen": "l2_cc_door_n1", "seen": "l2_cc_door_n1"},
		"pay": ["l2_cc_breaker_pay"],
	},
	"har": {
		"disc": {"read:Night shift roster": "l2_cc_roster"},
		"n1": {"unseen": "l2_cc_pin_n1a", "seen": "l2_cc_pin_n1b", "doc": "Night shift roster"},
		"errors": {"pin": "l2_cc_pin_err"},
		"pay": ["l2_cc_pin_pay"],
	},
}

## Shows the subtitle: anything with say(speaker, text, seconds), like the HUD.
var hud: Node
## Set by the level for co-op; without it everything plays on this machine.
var sync: LevelSync
## Who says a nudge or error line: peer id for the puzzle id. Co-op sets this to
## a random player near the puzzle; alone it's always you.
var speaker_for: Callable
## The subtitle name for a peer (players type their own).
var name_of: Callable
## The recordings folder for a peer's character, like "crew_dana"; "" for none.
var voice_dir_of: Callable

## The puzzle the crew is on, and how long they've been stuck on it.
var case_id := ""
var timed := false
var clock := 0.0
var since_line := INF
var nudges := 0
var fails := 0
var _n1_done := false
var _n2_done := false
var _mistakes := {}
## Lines already played this run (discoveries and errors play once).
var played := {}
## Titles of papers someone in the crew has read.
var seen := {}
var sysop_helped := false
var _first_nudge2_used := false

var _paused := false
var _typing := false
var _held := false
var _speaking := false
## At most one line waits while another is playing; nudges are dropped instead.
var _queued: Array = []
var _voice: Voice


func _init() -> void:
	speaker_for = func(_case: String) -> int: return _my_id()
	name_of = _default_name
	voice_dir_of = func(_peer: int) -> String: return ""


func _ready() -> void:
	name = "Commentary"
	_voice = Voice.new()
	add_child(_voice)


func _process(delta: float) -> void:
	tick(delta)


# --- What the level tells it (host) -----------------------------------------

## A puzzle becomes the crew's current job. `is_timed` puzzles skip Nudge 1.
func begin(id: String, is_timed: bool = false) -> void:
	case_id = id if NUDGES.has(id) else ""
	timed = is_timed
	clock = 0.0
	nudges = 0
	fails = 0
	_n1_done = false
	_n2_done = false
	_mistakes.clear()


## The current puzzle is solved: play its payoff and stop nudging.
func solved(id: String = "") -> void:
	if id == "":
		id = case_id
	if id == case_id:
		case_id = ""
	for line in NUDGES.get(id, {}).get("pay", []):
		_say(line, speaker_for.call(id), true)


## Something happened that may have a discovery line. `by` is the peer who
## found it, and they say it.
func discover(event: String, by: int = -1) -> void:
	if by < 0:
		by = _my_id()
	var ids := []
	if NUDGES.has(case_id):
		ids.append(case_id)
	ids.append_array(NUDGES.keys())
	for id in ids:
		var line: String = NUDGES[id].get("disc", {}).get(event, "")
		if line != "" and not played.has(line):
			_say(line, by, true)
			return


## A paper was read.
func read(title: String, by: int = -1) -> void:
	seen[title] = true
	discover("read:" + title, by)


## Hear about every paper in `root` being read. Documents report reads to the
## host, so this works for every player's reads.
func watch_documents(root: Node) -> void:
	for d in root.find_children("*", "Document", true, false):
		if not d.read_by.is_connected(_on_read):
			d.read_by.connect(_on_read.bind(d))


## A failed query or wrong action on the current puzzle. `kind` names the
## mistake ("table", "column", or the puzzle's own, like "reset"); the same
## kind twice plays its error line.
func mistake(kind: String = "") -> void:
	if case_id == "":
		return
	fails += 1
	if kind == "":
		return
	_mistakes[kind] = _mistakes.get(kind, 0) + 1
	var line: String = NUDGES[case_id].get("errors", {}).get(kind, "")
	if _mistakes[kind] >= 2 and line != "" and not played.has(line) and not _held:
		_say(line, speaker_for.call(case_id))


## SYSOP has helped the crew (they used `.hint`).
func hinted() -> void:
	sysop_helped = true


## The kind of mistake a failed query result shows, for mistake().
static func kind_of(result: Dictionary) -> String:
	if result.get("ok", true):
		return ""
	var err := str(result.get("error", "")).to_lower()
	if err.contains("no such table"):
		return "table"
	if err.contains("no such column"):
		return "column"
	return ""


## Other dialogue (Rourke, WARDEN, the PA, a huddle) is playing: commentary
## stops and waits. Call on every machine, like the dialogue itself.
func hold(on: bool) -> void:
	_held = on
	if on and _speaking:
		_voice.stop()
	if not on:
		_play_queued()


## A cut-scene: the nudge clock stops.
func pause(on: bool) -> void:
	_paused = on


## Someone is typing at a terminal: the nudge clock stops.
func typing(on: bool) -> void:
	_typing = on


# --- The nudge clock ----------------------------------------------------------

func tick(delta: float) -> void:
	if not _is_host() or case_id == "" or _paused or _typing or _held:
		return
	clock += delta
	since_line += delta
	if _speaking or nudges >= MAX_NUDGES or clock < QUIET_START_S or since_line < COOLDOWN_S:
		return
	var data: Dictionary = NUDGES[case_id]
	if not _n1_done and (timed or not data.has("n1")):
		_n1_done = true
	if not _n1_done and clock >= NUDGE1_S:
		_n1_done = true
		var n1: Dictionary = data["n1"]
		var line: String = n1.get("seen" if seen.has(n1.get("doc", "")) else "unseen", "")
		if line != "":
			nudges += 1
			_say(line, speaker_for.call(case_id))
			return
	var due := fails >= NUDGE2_FAILS or clock >= (NUDGE2_TIMED_S if timed else NUDGE2_S)
	if not _n2_done and due:
		_n2_done = true
		nudges += 1
		var line := NUDGE2 if sysop_helped or _first_nudge2_used else NUDGE2_FIRST
		_first_nudge2_used = true
		_say(line, speaker_for.call(case_id))


# --- Playing --------------------------------------------------------------------

## Host: play a line everywhere. Discoveries and payoffs wait their turn if
## something is playing; nudges and errors would be stale, so they drop.
func _say(id: String, peer: int, can_wait: bool = false) -> void:
	played[id] = true
	since_line = 0.0
	if _speaking or _held:
		if can_wait:
			_queued = [id, peer]
		return
	if sync and sync.is_online():
		sync.run_on(self, "play_line", [id, peer])
	else:
		play_line(id, peer)


## Every machine: say the line as `peer`'s character.
func play_line(id: String, peer: int) -> void:
	var l := VoiceLines.get_line(id)
	if l.is_empty():
		push_warning("No crew line with id '%s'" % id)
		return
	_speaking = true
	var dur: float = _voice.play(id, voice_dir_of.call(peer)) if _voice else 0.0
	if dur <= 0.0:
		dur = Voice.read_time(l["text"])
	if hud and hud.has_method("say"):
		await hud.say(name_of.call(peer), l["text"], dur)
	else:
		await get_tree().create_timer(dur, false).timeout
	_speaking = false
	_play_queued()


func _play_queued() -> void:
	if _queued.is_empty() or _speaking or _held or not _is_host():
		return
	var next: Array = _queued
	_queued = []
	_say(next[0], next[1], true)


func _on_read(player: Node, doc: Node) -> void:
	var peer := _my_id()
	if player and player.get("peer_id") != null:
		peer = player.peer_id
	read(doc.title, peer)


func _is_host() -> bool:
	return sync == null or sync.is_host()


func _my_id() -> int:
	return multiplayer.get_unique_id() if is_inside_tree() and multiplayer.has_multiplayer_peer() else 1


func _default_name(peer: int) -> String:
	var net := get_node_or_null("/root/Net")
	if net and net.has_method("display_name"):
		var who: String = net.display_name(peer)
		if who != "":
			return who
	return "You"
