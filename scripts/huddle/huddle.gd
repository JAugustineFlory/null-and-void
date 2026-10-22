class_name Huddle
extends Node
## A new chapter of the crew's book. When the job needs a new word, the chapter
## goes into the book in every player's notebook (the Books tab, NotebookPages),
## a notice says so, and Maddison's lines for it play over the radio. Nothing
## takes over the screen and nobody stops: the crew reads it when they like, and
## can test themselves on it there (BookQuiz). Augustine, 2026-10-22: the quick
## checks and the book popping up made co-op "almost unplayable".
##
##   await Huddle.of(self).run("easy_sql_1")
##
## Co-op: story code calls run() on every machine at the same beat. The host
## decides when the chapter is in (and grants it to every player's profile), and
## every machine plays it out. A chapter comes once per run.

signal changed
signal finished(chapter_id: String)
## A chapter's lines are over and the next one can come.
signal idle

## Where a chapter used to be read. Callers can still say; it changes nothing.
const FLASHBACK := "flashback"
const HERE := "here"
## The notice as a chapter goes into the book (a draft for Augustine's word-for-word OK).
const NOTICE := "New in %s: Ch. %d, %s. Press Tab, then Books, to read it."

## The World or standalone level this belongs to.
var level: Node
## The chapter coming in ({} in between).
var chapter := {}
## Who got it (peer ids): the only players whose profiles count the chapter.
var crew: Array = []
## Chapters this run has had.
var done := {}
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


func is_host() -> bool:
	return multiplayer.is_server()


func is_running() -> bool:
	return not chapter.is_empty()


## A chapter is coming in here, or its lines are still playing.
func is_busy() -> bool:
	return _busy


## Put chapter `id` in the crew's book and wait while Maddison's lines for it
## play. The players keep moving the whole time. If one is already playing (two
## papers read close together), this one waits its turn.
func run(id: String, _mode: String = FLASHBACK) -> void:
	while _busy:
		await idle
	if done.has(id) or Books.chapter(id).is_empty():
		return
	_busy = true
	if is_host():
		_complete(id)
	while not done.has(id):
		await finished
	chapter = Books.chapter(id)
	changed.emit()
	var hud = level.get("hud")
	if hud:
		hud.notice(NOTICE % [Books.book_name(chapter.book_id), chapter.number, chapter.title], 6.0)
	# At least a frame, even with no lines: whatever else set this chapter off
	# (one query solving two puzzles) has played out before the level carries on.
	await get_tree().process_frame
	if hud:
		for line in chapter.lines:
			await hud.line(line)
	chapter = {}
	changed.emit()
	_busy = false
	idle.emit()


## Host: chapter `id` is in. Every player (or just `ids`) has it on their own
## profile, and every machine puts it in the book.
func _complete(id: String, ids: Array = []) -> void:
	if ids.is_empty():
		ids = NetPlayers.ids_for(multiplayer)
	LevelSync.of(self).unlock_for(ids, "chapter:" + id)
	_finish.rpc(id, ids)


@rpc("authority", "call_local", "reliable")
func _finish(id: String, in_crew: Array) -> void:
	crew = in_crew
	var game := get_node("/root/Game")
	for w in Books.chapter(id).get("words", []):
		if not game.book_words.has(w):
			game.book_words.append(w)
	if not game.book_chapters.has(id):
		game.book_chapters.append(id)
		game.notebook_changed.emit()
	done[id] = true
	_earn_book(Books.chapter(id).get("book_id", ""))
	finished.emit(id)


# --- Unlocks (plan/approvals/unlocks.md) ---------------------------------------

## Every machine, once a chapter is in: a player who got it and has now had half
## of `book_id`, or all of it, unlocks its item. Chapters stay on each player's own
## profile across runs (the host grants them with unlock_for), so only their own
## machine can count them.
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
