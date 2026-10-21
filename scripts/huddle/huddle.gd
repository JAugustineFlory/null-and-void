class_name Huddle
extends Node
## The crew huddles round the book: one player reads a chapter's pages aloud, then
## everyone votes on its quiz together. The crew's answer is the most votes; a
## wrong answer explains why and the crew votes again, so nobody is stuck.
##
## Two ways to hold one:
##   await Huddle.of(self).run("easy_sql_1")              # a flashback to the garage
##   await Huddle.of(self).run("html_1", Huddle.HERE)     # on the spot, e.g. in the elevator
## A flashback cuts to the crew round the workbench in the garage (HomeBase), then
## back. On the spot, the book opens over the live view and everyone stands still.
##
## Co-op: story code calls run() on every machine at the same beat. The host
## decides (which player reads, page turns, votes, the result) and every machine
## shows it. A chapter is only read once per run.

signal changed
signal finished(chapter_id: String)

const FLASHBACK := "flashback"
const HERE := "here"
## How long a result stays up before the next question, at least.
const REVEAL_MIN := 2.5

## The World or standalone level this belongs to.
var level: Node
## The chapter being read ("" between huddles) and where the crew is in it.
var chapter := {}
var page := 0
## -1 while reading the pages, then the quiz question being voted on.
var question := -1
var reader_id := 1
## peer id -> option index, for the current question.
var votes := {}
## After a vote: {choice, right} until the next question; {split: true} on a tie.
var result := {}
## Chapters this run has finished.
var done := {}
## Shorter waits in tests.
var reveal_scale := 1.0
## Where this machine's unlocks are recorded: the player's own profile (Net's)
## unless set. Co-op tests give each machine its own.
var profile: Profile
var _ui: HuddleUI
var _mode := ""
var _home: Node3D
var _mouse_was := Input.MOUSE_MODE_VISIBLE


static func create(for_level: Node) -> Huddle:
	var h := Huddle.new()
	h.name = "Huddle"
	h.level = for_level
	for_level.add_child(h)
	return h


## The huddle for whatever level or wing `node` is in.
static func of(node: Node) -> Huddle:
	var n := node
	while n:
		var h := n.get_node_or_null("Huddle")
		if h is Huddle:
			return h
		n = n.get_parent()
	return null


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_left)


func is_host() -> bool:
	return multiplayer.is_server()


func is_running() -> bool:
	return not chapter.is_empty()


## Hold a huddle for chapter `id` and wait until the crew has finished it.
func run(id: String, mode: String = FLASHBACK) -> void:
	if done.has(id) or Books.chapter(id).is_empty():
		return
	var lines: Array = Books.chapter(id).lines
	var hud = level.get("hud")
	await _present(mode)
	if hud and lines.size() > 0:
		hud.line(lines[0])  # over the radio as the book opens
	if is_host() and chapter.get("id", "") != id:
		var ids := NetPlayers.ids_for(multiplayer)
		_begin.rpc(id, ids[Books.chapter(id).number % ids.size()])
	while not done.has(id):
		await finished
	if hud and lines.size() > 1:
		await hud.line(lines[1])
	await _dismiss()


## Every machine: the host has opened a chapter.
@rpc("authority", "call_local", "reliable")
func _begin(id: String, reader: int) -> void:
	chapter = Books.chapter(id)
	reader_id = reader
	page = 0
	question = -1
	votes.clear()
	result.clear()
	changed.emit()


# --- Reading -------------------------------------------------------------------

func is_reader() -> bool:
	return reader_id == multiplayer.get_unique_id()


## The reader turns the page (`step` 1 forward, -1 back). Past the last page, the quiz starts.
func turn_page(step: int = 1) -> void:
	if not is_reader() or question >= 0 or not is_running():
		return
	if is_host():
		_turn(step, multiplayer.get_unique_id())
	else:
		_ask_turn.rpc_id(1, step)


@rpc("any_peer", "reliable")
func _ask_turn(step: int) -> void:
	if is_host():
		_turn(step, multiplayer.get_remote_sender_id())


func _turn(step: int, by: int) -> void:
	if by != reader_id or question >= 0 or not is_running():
		return
	var to := clampi(page + step, 0, chapter.pages.size())
	if to == chapter.pages.size():
		_set_question.rpc(0)
	elif to != page:
		_set_page.rpc(to)


@rpc("authority", "call_local", "reliable")
func _set_page(p: int) -> void:
	page = p
	changed.emit()


# --- The quiz ------------------------------------------------------------------

## The current question with its options in this run's order: {q, options, answer, why}.
func current_question() -> Dictionary:
	if question < 0 or question >= chapter.get("quiz", []).size():
		return {}
	var q: Dictionary = chapter.quiz[question].duplicate()
	q.merge(Books.shuffled(q, get_node("/root/Game").run_seed, "%s/%d" % [chapter.id, question]), true)
	return q


## This player votes for option `option` (in the order shown). They can change
## their mind until everyone has voted.
func vote(option: int) -> void:
	if question < 0 or not result.is_empty():
		return
	if is_host():
		_cast(option, multiplayer.get_unique_id())
	else:
		_ask_vote.rpc_id(1, option, question)


@rpc("any_peer", "reliable")
func _ask_vote(option: int, for_question: int) -> void:
	if is_host() and for_question == question:
		_cast(option, multiplayer.get_remote_sender_id())


func _cast(option: int, by: int) -> void:
	if question < 0 or not result.is_empty() or option < 0 or option >= chapter.quiz[question].options.size():
		return
	var v := votes.duplicate()
	v[by] = option
	_set_votes.rpc(v)
	_count()


@rpc("authority", "call_local", "reliable")
func _set_votes(v: Dictionary) -> void:
	votes = v
	changed.emit()


## Host: once everyone has voted, the most votes is the crew's answer.
func _count() -> void:
	var ids := NetPlayers.ids_for(multiplayer)
	if ids.any(func(id): return not votes.has(id)):
		return
	var tally := {}
	for id in ids:
		tally[votes[id]] = tally.get(votes[id], 0) + 1
	var top: int = tally.values().max()
	var leaders := tally.keys().filter(func(o): return tally[o] == top)
	var asked := question
	if leaders.size() > 1:
		_show_result.rpc({"split": true})
		await get_tree().create_timer(REVEAL_MIN * reveal_scale, false).timeout
		if question == asked:
			_set_question.rpc(asked)  # the same question, fresh votes
		return
	var right: bool = leaders[0] == current_question().answer
	_show_result.rpc({"choice": leaders[0], "right": right})
	var why: String = chapter.quiz[asked].get("why", "")
	var wait := (maxf(REVEAL_MIN, Voice.read_time(why)) if why != "" else REVEAL_MIN) * reveal_scale
	await get_tree().create_timer(wait, false).timeout
	if question != asked or not is_running():
		return
	if not right:
		_set_question.rpc(asked)
	elif asked + 1 < chapter.quiz.size():
		_set_question.rpc(asked + 1)
	else:
		_finish.rpc(chapter.id)


@rpc("authority", "call_local", "reliable")
func _show_result(r: Dictionary) -> void:
	result = r
	changed.emit()


@rpc("authority", "call_local", "reliable")
func _set_question(q: int) -> void:
	question = q
	votes.clear()
	result.clear()
	changed.emit()


@rpc("authority", "call_local", "reliable")
func _finish(id: String) -> void:
	var game := get_node("/root/Game")
	for w in chapter.get("words", []):
		if not game.book_words.has(w):
			game.book_words.append(w)
	done[id] = true
	_earn_chapter(id)
	chapter = {}
	question = -1
	votes.clear()
	result.clear()
	changed.emit()
	finished.emit(id)


# --- Unlocks (plan/approvals/unlocks.md) ---------------------------------------

## Record an unlock for this machine's player, through Net.earn (which owns the
## items and says "Unlocked: ..."). Call it on every machine (from a sync.event
## handler or an RPC to everyone), so everyone there earns it.
func earn(source: String) -> Array:
	if profile:
		return profile.earn(source)
	var net = get_node_or_null("/root/Net")
	return net.earn(source, level.get("hud")) if net else []


func _profile() -> Profile:
	if profile:
		return profile
	var net = get_node_or_null("/root/Net")
	return net.profile if net else null


## Every machine: a chapter is finished. Each one is remembered on the player's
## profile, across runs; half the book and the whole book unlock an item each.
func _earn_chapter(id: String) -> void:
	var book_id: String = Books.chapter(id).get("book_id", "")
	earn("chapter:" + id)
	var p := _profile()
	if p == null:
		return
	var ids := Books.book_chapter_ids(book_id)
	var read := ids.filter(func(c): return p.earned.has("chapter:" + c)).size()
	if read * 2 >= ids.size():
		earn("achievement:%s_half" % book_id)
	if read == ids.size():
		earn("achievement:%s_done" % book_id)


## Host: a player left. Someone else reads, and the vote doesn't wait for them.
func _on_peer_left(id: int) -> void:
	if not is_host() or not is_running():
		return
	if id == reader_id:
		_begin_reader.rpc(1)
	if votes.has(id):
		var v := votes.duplicate()
		v.erase(id)
		_set_votes.rpc(v)
	if question >= 0 and result.is_empty() and not votes.is_empty():
		_count()


@rpc("authority", "call_local", "reliable")
func _begin_reader(id: int) -> void:
	reader_id = id
	changed.emit()


## Who's who, for the page: "You" for this player, otherwise their name.
func player_name(id: int) -> String:
	if id == multiplayer.get_unique_id():
		return "You"
	var players = level.get("players")
	if players:
		return players.names().get(id, "Crew")
	return "Crew"


# --- Showing it ----------------------------------------------------------------

func _present(mode: String) -> void:
	_mode = mode
	var player: Player = level.get("player")
	if player:
		player.input_locked = true
	if level.get("terminal_ui") and level.terminal_ui.visible:
		level.terminal_ui.close()
	if level.get("notebook") and level.notebook.is_open():
		level.notebook.close()
	var hud = level.get("hud")
	if mode == FLASHBACK:
		if hud:
			await hud.fade(true, 0.5)
		_home = load("res://scripts/levels/home_base.gd").for_flashback(level)  # loaded late: home_base pulls in LevelBase
		_home.start_flashback(NetPlayers.ids_for(multiplayer).size())
	_ui = HuddleUI.create(self, mode == FLASHBACK)
	_mouse_was = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if mode == FLASHBACK and hud:
		await hud.fade(false, 0.6)


func _dismiss() -> void:
	var hud = level.get("hud")
	if _mode == FLASHBACK and hud:
		await hud.fade(true, 0.5)
	if _ui:
		_ui.queue_free()
		_ui = null
	var player: Player = level.get("player")
	if _home:
		_home.end_flashback(player.camera if player else null)
		_home = null
	if player:
		player.input_locked = false
	Input.mouse_mode = _mouse_was
	if _mode == FLASHBACK and hud:
		await hud.fade(false, 0.6)
