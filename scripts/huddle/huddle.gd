class_name Huddle
extends Node
## The crew huddles round the book: one player reads a chapter's pages aloud, the
## crew turns each page when everyone's ready, and everyone votes on its quiz
## together. The crew's answer is the most votes; a wrong answer explains why and
## the crew votes again, so nobody is stuck.
##
## Two ways to hold one:
##   await Huddle.of(self).run("easy_sql_1")              # a flashback to the garage
##   await Huddle.of(self).run("html_1", Huddle.HERE)     # on the spot, e.g. in the elevator
## A flashback cuts to the crew in their seats in the garage (HomeBase), facing
## Maddison at her whiteboard, then back. In the garage itself (the opening's
## chapter zero) the same shot plays live, with the crew in their real seats. Either
## way the whiteboard shows where the crew is in the chapter. Anywhere else, the
## book opens over the live view and everyone stands still.
##
## Co-op: story code calls run() on every machine at the same beat. The host
## decides (which player reads, page turns, votes, the result) and every machine
## shows it. A chapter is only read once per run.

signal changed
signal finished(chapter_id: String)
## A huddle has closed and the next one can open.
signal idle

const FLASHBACK := "flashback"
const HERE := "here"
## How long a result stays up before the next question, at least.
const REVEAL_MIN := 2.5
## How long the cut waits for a player to finish reading a paper, at most.
const PAPER_WAIT := 30.0

## The World or standalone level this belongs to.
var level: Node
## The chapter being read ("" between huddles) and where the crew is in it.
var chapter := {}
## The chapter is read in rounds (Books.rounds): a word's page, then its questions.
var rounds: Array = []
var round_index := 0
var page := 0
## -1 while reading the pages, then the quiz question being voted on.
var question := -1
var reader_id := 1
## Who is in this huddle (peer ids, set as it opens): the players who can vote,
## and the only ones whose profiles count the chapter.
var crew: Array = []
## peer id -> option index, for the current question.
var votes := {}
## Who is ready to turn the page, by peer id (the host decides; everyone sees).
var turn_votes := {}
## After a vote: {choice, right} until the next question; {split: true} on a tie.
var result := {}
## Chapters this run has finished.
var done := {}
## Shorter waits in tests.
var reveal_scale := 1.0
var _ui: HuddleUI
var _mode := ""
var _home: Node3D
var _mouse_was := Input.MOUSE_MODE_VISIBLE
var _busy := false


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


## A huddle is open here, or still closing.
func is_busy() -> bool:
	return _busy


## Hold a huddle for chapter `id` and wait until the crew has finished it. If one
## is already open (two papers read close together), this one waits its turn.
func run(id: String, mode: String = FLASHBACK) -> void:
	while _busy:
		await idle
	if done.has(id) or Books.chapter(id).is_empty():
		return
	_busy = true
	var lines: Array = Books.chapter(id).lines
	var hud = level.get("hud")
	await _present(mode)
	if hud and lines.size() > 0:
		hud.line(lines[0])  # over the radio as the book opens
	if is_host() and chapter.get("id", "") != id:
		var ids := NetPlayers.ids_for(multiplayer)
		_begin.rpc(id, ids[Books.chapter(id).number % ids.size()], ids)
	while not done.has(id):
		await finished
	if hud and lines.size() > 1:
		await hud.line(lines[1])
	await _dismiss()
	_busy = false
	idle.emit()


## Every machine: the host has opened a chapter.
@rpc("authority", "call_local", "reliable")
func _begin(id: String, reader: int, in_huddle: Array) -> void:
	chapter = Books.chapter(id)
	rounds = Books.rounds(chapter)
	reader_id = reader
	crew = in_huddle
	round_index = 0
	page = rounds[0].pages[0] if not rounds[0].pages.is_empty() else 0
	question = -1 if not rounds[0].pages.is_empty() else rounds[0].questions[0]
	turn_votes.clear()
	votes.clear()
	result.clear()
	changed.emit()


# --- Reading -------------------------------------------------------------------

func is_reader() -> bool:
	return reader_id == multiplayer.get_unique_id()


## This player is ready to turn the page (`step` 1), or turns back to the one
## before (-1), within this round's pages. The page turns forward once the whole
## crew is ready; past a round's last page come its questions.
func turn_page(step: int = 1) -> void:
	if question >= 0 or not is_running():
		return
	if is_host():
		_turn(step, multiplayer.get_unique_id(), page)
	else:
		_ask_turn.rpc_id(1, step, page)


@rpc("any_peer", "reliable")
func _ask_turn(step: int, at_page: int) -> void:
	if is_host():
		_turn(step, multiplayer.get_remote_sender_id(), at_page)


func _turn(step: int, by: int, at_page: int) -> void:
	if at_page != page or question >= 0 or not is_running():
		return
	if step > 0:
		if turn_votes.has(by):
			return
		var ready := turn_votes.duplicate()
		ready[by] = true
		_set_turn_votes.rpc(ready)
		if NetPlayers.ids_for(multiplayer).any(func(id): return not ready.has(id)):
			return
	_advance(step)


## Host: turn the page `step` (1 or -1) within this round, or on to its questions.
func _advance(step: int) -> void:
	var pages: Array = rounds[round_index].pages
	var to := clampi(pages.find(page) + step, 0, pages.size())
	if to == pages.size():
		if rounds[round_index].questions.is_empty():
			_next_round()
		else:
			_set_step.rpc(round_index, page, rounds[round_index].questions[0])
	elif pages[to] != page:
		_set_step.rpc(round_index, pages[to], -1)


## Host: on to the next round's pages (or straight to its questions), or the end.
func _next_round() -> void:
	var r := round_index + 1
	while r < rounds.size() and rounds[r].pages.is_empty() and rounds[r].questions.is_empty():
		r += 1
	if r >= rounds.size():
		_complete(chapter.id)
	elif rounds[r].pages.is_empty():
		_set_step.rpc(r, page, rounds[r].questions[0])
	else:
		_set_step.rpc(r, rounds[r].pages[0], -1)


@rpc("authority", "call_local", "reliable")
func _set_turn_votes(v: Dictionary) -> void:
	turn_votes = v
	changed.emit()


## Whether this player is ready to turn the page.
func ready_to_turn() -> bool:
	return turn_votes.has(multiplayer.get_unique_id())


@rpc("authority", "call_local", "reliable")
func _set_step(r: int, p: int, q: int) -> void:
	round_index = r
	page = p
	question = q
	turn_votes.clear()
	votes.clear()
	result.clear()
	changed.emit()


## The first page of this round, and whether this is its last.
func first_page_of_round() -> bool:
	return rounds[round_index].pages.find(page) <= 0


func last_page_of_round() -> bool:
	var pages: Array = rounds[round_index].pages
	return pages.find(page) == pages.size() - 1


## The pages on show beside the current question (none for a memory question).
func reference() -> Array:
	if question < 0 or chapter.quiz[question].get("closed", false):
		return []
	return rounds[round_index].ref.map(func(i): return chapter.pages[i])


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
	var qs: Array = rounds[round_index].questions
	if not right:
		_set_question.rpc(asked)
	elif qs.find(asked) + 1 < qs.size():
		_set_question.rpc(qs[qs.find(asked) + 1])
	else:
		_next_round()


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


## Host: the crew has finished chapter `id`. Only the players in the huddle get
## it, each on their own profile; then every machine closes the book.
func _complete(id: String) -> void:
	LevelSync.of(self).unlock_for(crew, "chapter:" + id)
	_finish.rpc(id)


@rpc("authority", "call_local", "reliable")
func _finish(id: String) -> void:
	var game := get_node("/root/Game")
	for w in chapter.get("words", []):
		if not game.book_words.has(w):
			game.book_words.append(w)
	done[id] = true
	_earn_book(Books.chapter(id).get("book_id", ""))
	chapter = {}
	rounds = []
	question = -1
	votes.clear()
	result.clear()
	changed.emit()
	finished.emit(id)


# --- Unlocks (plan/approvals/unlocks.md) ---------------------------------------

## Every machine, once a chapter is finished: a player in the huddle who has now
## read half of `book_id`, or all of it, unlocks its item. Chapters stay on each
## player's own profile across runs (the host grants them with unlock_for), so
## only their own machine can count them.
func _earn_book(book_id: String) -> void:
	var net = get_node_or_null("/root/Net")
	if net == null or not crew.has(multiplayer.get_unique_id()):
		return
	var ids := Books.book_chapter_ids(book_id)
	var read := ids.filter(func(c): return net.profile.earned.has("chapter:" + c)).size()
	if read * 2 >= ids.size():
		net.earn("achievement:%s_half" % book_id, level.get("hud"))
	if read == ids.size():
		net.earn("achievement:%s_done" % book_id, level.get("hud"))


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
	if question < 0 and not turn_votes.is_empty():
		var t := turn_votes.duplicate()
		t.erase(id)
		_set_turn_votes.rpc(t)
		if not t.is_empty() and NetPlayers.ids_for(multiplayer).all(func(p): return t.has(p)):
			_advance(1)


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
	# A paper still open here (often the one that brought the chapter back) is read
	# to the end first; after a while it's put away. Closing it frees the player, so
	# the lock comes after.
	var waited := 0.0
	while waited < PAPER_WAIT and not _papers().is_empty():
		await get_tree().process_frame
		waited += get_process_delta_time()
	for r in _papers():
		r.close()
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
	elif _garage_here():  # in the garage itself: the crew's real seats
		_home = _garage_here()
		_home.start_whiteboard()
	if _home:
		changed.connect(_write_board)
	_ui = HuddleUI.create(self, mode == FLASHBACK)
	_mouse_was = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if mode == FLASHBACK and hud:
		await hud.fade(false, 0.6)


## The garage, if the crew is in it now (the opening): the level itself, or the
## World's home while it's the current wing.
func _garage_here() -> Node:
	if level.has_method("start_whiteboard"):
		return level
	var home = level.get("home")
	if home and level.get("current") == home:
		return home
	return null


## The document readers open on this machine's screen. A reader sits on the level
## its paper is in, which in the World is a wing under this huddle's level.
func _papers() -> Array:
	var found := []
	for n in [level] + level.get_children().filter(func(c): return c.has_method("finish_level")):
		for c in n.get_children():
			if c is DocumentReader and not c.is_queued_for_deletion():
				found.append(c)
	return found


func _dismiss() -> void:
	var hud = level.get("hud")
	if _mode == FLASHBACK and hud:
		await hud.fade(true, 0.5)
	if _ui:
		_ui.queue_free()
		_ui = null
	var player: Player = level.get("player")
	if _home:
		changed.disconnect(_write_board)
		_home.write_board("")
		_home.end_flashback(player.camera if player else null)
		_home = null
	if player:
		player.input_locked = false
	Input.mouse_mode = _mouse_was
	if _mode == FLASHBACK and hud:
		await hud.fade(false, 0.6)


## What Maddison has up on the whiteboard: the page's heading while it's read,
## the quick check's word during the quiz.
func _write_board() -> void:
	if chapter.is_empty():
		_home.write_board("")
	elif question < 0:
		_home.write_board("Ch. %d: %s\n%s" % [chapter.number, chapter.title, str(chapter.pages[page]).get_slice("\n", 0)])
	else:
		_home.write_board("Quick check %d of %d\n%s" % [question + 1, chapter.quiz.size(), str(chapter.quiz[question].get("word", ""))])
