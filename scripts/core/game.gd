extends Node
## Global game state and input setup. Autoloaded as `Game`.

## The notebook gained a sticky note or a table.
signal notebook_changed
## This player added the line that answers a case's blank (add_answer).
signal answer_found(case_id: String)
## A line went into the notebook as a plain note (it answered no blank): a
## terminal row (kind "row") or a paper's line ("document").
signal line_noted(text: String, kind: String)
## One of a case's pieces was found (collect_piece): the HUD shows it.
signal piece_found(case_id: String, piece_id: String)

const LEVELS := {
	"world": "res://scenes/world.tscn",
	"level_0": "res://scenes/level_0.tscn",
	"level_1": "res://scenes/level_1.tscn",
	"level_2": "res://scenes/level_2.tscn",
	"level_3": "res://scenes/level_3.tscn",
	"level_4": "res://scenes/level_4.tscn",
	"level_5": "res://scenes/level_5.tscn",
	"movement_gym": "res://scenes/movement_gym.tscn",
	"field_notes": "res://scenes/field_notes.tscn",
	"menu": "res://scenes/main_menu.tscn",
	"lobby": "res://scenes/lobby.tscn",
}

## How the escort's story went: "unknown", "killed", "tied".
var rourke_fate := "unknown"
var has_walkie := false
## This machine's player's visitor badge, "VIS-01".."VIS-06" ("" before the front desk).
var visitor_badge_no := ""
## This player's inventory and hotbar. Each machine keeps its own (see Inventory).
var inventory := Inventory.new()
## Did the players lock the Watcher in behind them in Level 2?
var watcher_sealed := false
## Did the players lock the Custodian out in its bay on floor 10 (Level 4)? If not,
## it can come back on later floors.
var custodian_sealed := false
## Did the players learn (or get told) that CAM-2's 'live' picture was frozen?
var cam_lie_learned := false
## The level the Field Notes screen is summarizing, and where "Continue" goes.
var completed_level := ""
var next_level := ""
## Every successful query the players ran, for the Field Notes screen.
var query_log: Array[String] = []
## Concepts the players have used, in the order they first used them.
var concepts_learned: Array[String] = []
## Seed for this run's randomized data (replay scenarios).
var run_seed := 0
## Who got into the van at home base, in the order they climbed in (peer ids):
## the n-th one took seat n, and arrives at Halcyon in that same seat.
var van_seating: Array[int] = []
## A new game opens in the crew's garage before the van (the World reads this).
var open_at_home := false
## Words the crew has learned from its books, in order (see Huddle).
var book_words: Array[String] = []
## The crew hasn't got the book yet this run (the garage, before the shop bag):
## chapters earned on earlier runs stay out of the notebook until they have.
var before_book := false
## The chapters the crew has read this run, in order: they're in the notebook's book.
var book_chapters: Array[String] = []
## The notebook is held in your hands and terminals are used on their own screens.
## Off: both open full-screen over the view, as before (a setting in the pause menu).
var diegetic_ui := true
## This player's notebook. Each machine keeps its own, so in co-op a note belongs to
## whoever picked it up. Sticky note ids, in the order found (see StickyNotes).
var notebook_notes: Array[String] = []
## Tables this player has discovered: name -> column names.
var notebook_tables := {}
## Lines this player wrote down from a terminal: {label, text, kind}.
var notebook_written: Array[Dictionary] = []
## The crew's Byte-Right work order, clipped in the notebook: the call-out they
## were hired for, as dispatch printed it (WorkOrderForm draws it). The scope is
## the job they think they're doing; the tasks are written in by hand below it.
const TICKET := {
	"company": "BYTE-RIGHT IT SERVICES",
	"tagline": "Networks - Databases - 24 hr call-outs",
	"priority": "AFTER HOURS",
	"customer": "Halcyon Data Systems",
	"site": "Halcyon main building, front entrance",
	"contact": "D. Rourke, facilities (will escort)",
	"problem": "\"database problem\", night call-out",
	"billing": "Hourly, 2 hr minimum",
	"scope": [
		"Sign in at reception. Wait for site contact.",
		"Diagnose the reported database problem.",
		"Housekeeping: tidy/reorganise tables as directed on site.",
		"Test, write up, get client sign-off.",
	],
}
## Printed lines of the work order the crew marked up in the garage briefing, as
## Maddison talked them through it (WorkOrderForm keys: "contact", "problem",
## "scope_0"...). The same on every copy.
var ticket_marks: Array[String] = []
## The ticket's task list, in the character's hand as tasks come up:
## {text, done, filled}. `filled` is what was written in once it was done.
var notebook_todo: Array[Dictionary] = []
## Case pages: one per puzzle, so everything found about it is in one place.
## {id, title, open, solved, how, tables, clues: [{text, from}]}. Clues read before
## the case opens are kept and show once it does.
var notebook_cases: Array[Dictionary] = []
## Voice line ids already jotted down this run, so a replayed line isn't jotted twice.
var notebook_jotted: Array[String] = []
## The job the crew was hired for is over (end_job): the work order is void, and
## tasks from then on go on the case they're for.
var job_over := false
## What a missing piece shows on its case page and in the query so far.
const PIECE_MISSING := "????"


func _ready() -> void:
	_setup_input()
	new_run()


func new_run(seed_value: int = -1) -> void:
	run_seed = seed_value if seed_value >= 0 else randi()
	open_at_home = false
	book_words.clear()
	book_chapters.clear()
	before_book = false
	rourke_fate = "unknown"
	has_walkie = false
	visitor_badge_no = ""
	watcher_sealed = false
	custodian_sealed = false
	cam_lie_learned = false
	completed_level = ""
	next_level = ""
	query_log.clear()
	concepts_learned.clear()
	notebook_notes.clear()
	notebook_tables.clear()
	notebook_written.clear()
	notebook_todo.clear()
	ticket_marks.clear()
	notebook_cases.clear()
	notebook_jotted.clear()
	job_over = false
	inventory.clear()
	van_seating.clear()


func goto(level_key: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(LEVELS[level_key])


func log_query(sql: String) -> void:
	query_log.append(sql.strip_edges())
	var upper := sql.to_upper()
	for concept in ["SELECT", "FROM", "ORDER BY", "WHERE", "AND", "OR", "LIKE", "LIMIT", "COUNT", "GET"]:
		var pattern := RegEx.create_from_string("\\b" + concept.replace(" ", "\\s+") + "\\b")
		if pattern.search(upper) and not concepts_learned.has(concept):
			concepts_learned.append(concept)


## Add a sticky note to the notebook. False if it was already there.
func add_note(id: String) -> bool:
	if notebook_notes.has(id):
		return false
	notebook_notes.append(id)
	notebook_changed.emit()
	return true


## Record a table and its columns on the notebook's Tables page.
func discover_table(table: String, columns: Array) -> void:
	if notebook_tables.has(table) and notebook_tables[table] == columns:
		return
	notebook_tables[table] = columns
	_seen_tables()
	notebook_changed.emit()


## Write a terminal line into the notebook, under the player's own label. It goes
## on `case_id`'s page (at a terminal: the case its hints are for), else on the
## case being worked on (current_case), or under Other notes.
func write_note(label: String, text: String, kind: String, case_id: String = "") -> void:
	if case_id == "" or not case_info(case_id).get("open", false):
		case_id = current_case()
	notebook_written.append({"label": label, "text": text, "kind": kind, "case": case_id})
	notebook_changed.emit()
	line_noted.emit(text, kind)


## Keep a note under Other notes on the Cases page, whatever case is open: a fact
## with no case of its own, or (with `case_id`) for a case that isn't open yet,
## whose page it moves to once it opens.
func note_aside(label: String, text: String, kind: String, case_id: String = "") -> void:
	notebook_written.append({"label": label, "text": text, "kind": kind, "case": case_id})
	notebook_changed.emit()


## The case being worked on, and the only one the notebook shows: the newest open,
## unsolved case, a real one before a side case. "" when there's nothing open.
func current_case() -> String:
	for c in notebook_cases:
		if c.open and not c.solved and not c.get("optional", false):
			return c.id
	for c in notebook_cases:
		if c.open and not c.solved:
			return c.id
	return ""


## Side cases open alongside the current one, newest first: optional ones the crew
## can look into, which never take the page from the case they're on.
func side_cases() -> Array:
	var on := current_case()
	return notebook_cases.filter(func(c): return c.open and not c.solved and c.id != on)


## A line under the case's question, in pencil: how the case board itself works,
## for the floor that teaches it. Rare: most cases explain themselves. `hunt` goes
## under its pieces until one is found; `terminal` names where the finished query
## is typed ("the terminal" if not given).
func set_case_note(id: String, text: String, hunt := "", terminal := "") -> void:
	var c := _case(id)
	c["note"] = text
	c["hunt"] = hunt
	c["terminal"] = terminal
	notebook_changed.emit()


## What to do about case `id`, in the imperative, or "" if it was never said.
func case_objective(id: String) -> String:
	return str(case_info(id).get("objective", ""))


## A new task on the job ticket; the one before it is ticked off. "" ticks off
## the current task and adds nothing. False if nothing changed. Once the job is
## over (end_job), a task is the current case's: it goes on that case's
## checklist, not the void work order.
func set_todo(text: String) -> bool:
	if text != "" and current_todo() == text:
		return false
	var changed := false
	for t in notebook_todo:
		if not t.done:
			t.done = true
			changed = true
	if text != "":
		notebook_todo.append({"text": text, "done": false, "filled": "", "case": current_case() if job_over else ""})
		changed = true
	if changed:
		notebook_changed.emit()
	return changed


## Write something in beside a task once it's done ("used memo_fragments"), so
## later levels can read back what the crew did. False if there's no such task.
func ticket_fill(task: String, filled: String) -> bool:
	for i in range(notebook_todo.size() - 1, -1, -1):
		if notebook_todo[i].text == task:
			notebook_todo[i].filled = filled
			notebook_changed.emit()
			return true
	return false


## The whole job ticket as data: the printed lines, its work order number and the
## tasks. For later levels to reverse-engineer.
func ticket() -> Dictionary:
	var t := TICKET.duplicate()
	t["order"] = ticket_number()
	t["caller"] = Level0Data.caller_line(run_seed)  # who placed the call: not the contact
	t["tasks"] = notebook_todo.duplicate(true)
	t["void"] = job_over
	t["marks"] = ticket_marks.duplicate()
	return t


## Mark a printed line of the work order (a ticket_marks key). False if it already was.
func mark_ticket(key: String) -> bool:
	if ticket_marks.has(key):
		return false
	ticket_marks.append(key)
	notebook_changed.emit()
	return true


## The work order number, the same all run.
func ticket_number() -> String:
	return "WO-%05d" % (run_seed % 100000)


## Everything a case page can have, for a case made before it could (an old save).
const CASE_DEFAULTS := {"pieces": [], "query": "", "steps": [], "optional": false, "early": {}, "endings": [], "ending": "", "routes": [], "assemble": true, "objective": "", "note": "", "hunt": "", "terminal": ""}


func _case(id: String) -> Dictionary:
	for c in notebook_cases:
		if c.id == id:
			for k in CASE_DEFAULTS:
				if not c.has(k):
					c[k] = CASE_DEFAULTS[k].duplicate() if CASE_DEFAULTS[k] is Array or CASE_DEFAULTS[k] is Dictionary else CASE_DEFAULTS[k]
			return c
	var c := {"id": id, "title": "", "open": false, "solved": false, "how": "", "tables": [], "clues": [],
		"pieces": [], "query": "", "steps": [], "optional": false, "early": {}, "endings": [], "ending": "", "routes": [], "assemble": true,
		"objective": "", "note": "", "hunt": "", "terminal": ""}
	notebook_cases.append(c)
	return c


## Open a case page: `title` is the question, never its answer; `tables` are the
## ones that matter (the page only names those this player has found); `objective`
## is the one thing to do about it, in the imperative, which the HUD and the top of
## the case page both show. True if new.
func open_case(id: String, title: String, tables: Array = [], objective: String = "") -> bool:
	var c := _case(id)
	if c.open:
		return false
	c.title = title
	c.open = true
	c.objective = objective
	c.tables = tables.duplicate()
	# The newest open case goes on top.
	notebook_cases.erase(c)
	notebook_cases.insert(0, c)
	notebook_changed.emit()
	return true


## Note a clue on a case page (once). `from` says where it was read. True if new.
func add_clue(id: String, text: String, from: String) -> bool:
	var c := _case(id)
	for k in c.clues:
		if k.text == text:
			return false
	c.clues.append({"text": text, "from": from})
	if c.open:
		notebook_changed.emit()
	return c.open


## Close a case: solved, with what was found written in.
func solve_case(id: String, how: String) -> void:
	var c := _case(id)
	if c.solved:
		return
	c.solved = true
	c.how = how
	# However they got there, the board is complete: what they didn't pick up on
	# the way, they knew.
	for p in c.get("pieces", []):
		p.found = true
	for st in c.get("steps", []):
		st.done = true
	c["fresh_solve"] = true  # the notebook shows it solved, once, before filing it
	notebook_changed.emit()


## Give case `id` a blank for its answer, under its question: "Ext. 4815 belongs
## to: ______". It's filled by adding the line that answers it to the notebook (a
## terminal row, a line on a paper) with every one of `needles` in it; `value` is
## what's written in.
func set_blank(id: String, prompt: String, needles: Array, value: String) -> void:
	var c := _case(id)
	c["blank"] = {"prompt": prompt, "needles": needles.map(func(n): return str(n).to_lower()), "value": value, "filled": "", "fresh": false}
	if c.open:
		notebook_changed.emit()


## The open, unsolved case whose empty blank `text` answers, or "".
func answers(text: String) -> String:
	var low := text.to_lower()
	for c in notebook_cases:
		var b: Dictionary = c.get("blank", {})
		if c.open and not c.solved and not b.is_empty() and b.filled == "" and b.needles.all(func(n): return low.contains(n)):
			return c.id
	return ""


## Write case `id`'s answer into its blank. `fresh`: the notebook writes it in
## before your eyes the next time it shows the page. True if it was empty.
func fill_blank(id: String, fresh := true) -> bool:
	var b: Dictionary = case_info(id).get("blank", {})
	if b.is_empty() or b.filled != "":
		return false
	b.filled = b.value
	b.fresh = fresh
	notebook_changed.emit()
	return true


## Pencil `text` under case `id`'s empty blank: why the line just added didn't
## fill it. Once per run; false if it was already said or the blank is filled.
func blank_miss(id: String, text: String) -> bool:
	var b: Dictionary = case_info(id).get("blank", {})
	if b.is_empty() or b.filled != "" or b.has("miss"):
		return false
	b["miss"] = text
	notebook_changed.emit()
	return true


## The player is adding `text` to their notebook: if it answers a case's blank,
## it goes in that blank instead, and answer_found fires. True if it did.
## `source` says where the line was ("document", "terminal"): a level can tell
## which way the crew found it (find_route).
func add_answer(text: String, source: String = "") -> bool:
	var id := answers(text)
	if id == "" or not fill_blank(id):
		return false
	case_info(id).blank["source"] = source
	answer_found.emit(id)
	return true


func case_info(id: String) -> Dictionary:
	for c in notebook_cases:
		if c.id == id:
			return c
	return {}


## The crew jots down a spoken line that sets a task or states a needed fact, so a
## player who missed it can read it back (plan/teaching/dialogue-notes-and-commentary.md).
## `line` is its VoiceLines entry: "jot" is the paraphrase; "todo": true puts it on the
## work order, "case" on that case page if it's open, otherwise under Other notes.
## Secret lines are never jotted, and each line only once a run. True if jotted.
func jot(id: String, line: Dictionary) -> bool:
	var text := str(line.get("jot", ""))
	if text == "" or line.get("secret", false) or id in notebook_jotted:
		return false
	notebook_jotted.append(id)
	var who := str(line.get("speaker", ""))
	if not who in ["PA", "WARDEN"]:
		who = who.capitalize()  # as the subtitle names them, never the cast list's "who"
	if line.get("todo", false):
		set_todo(text)
	elif case_info(str(line.get("case", ""))).get("open", false):
		add_clue(line["case"], text, who)
	else:
		# A fact with no case of its own, or whose case isn't open (yet, or on a floor
		# that opens none), goes under Other notes, whatever case is open.
		note_aside(who, text, "jot")
	return true


# --- Case pieces ------------------------------------------------------------
# A case says up front which pieces its main route needs (a table, a column, a
# value, a word from the book), each found somewhere on the floor. Found ones
# fill in on its page and in its query; the HUD counts them. Other ways in
# (routes) and endings are listed but hidden until found.

## Give case `id` its pieces: [{id, label, value, task, where, seen_in?}].
## `task` is its line on the case's checklist, `where` the vague nudge shown
## while it's missing, `seen_in` a table whose columns (on the Tables page) show
## it. `query` is the query with {piece_id} where each piece goes. `steps` are
## the checklist's lines after the pieces: [{id, text}], ticked by tick_step
## and all ticked when it's solved. An `optional` case is a side case: the HUD
## counts only the main one. Calling it again (a case that grows) keeps the
## pieces and steps already found or ticked, and so do pieces found before it.
## A value piece's `blank` names its slot while it's missing, as the hint does
## (enter_column_name); a word from the book stays ????.
func set_pieces(id: String, pieces: Array, query: String = "", steps: Array = [], optional: bool = false) -> void:
	var c := _case(id)
	var old: Array = c.pieces
	c.pieces = []
	for p in pieces:
		var piece: Dictionary = p.duplicate()
		var was := {}
		for o in old:
			if o.id == piece.id and o.found:
				was = o
		piece["found"] = c.solved or c.early.has(piece.id) or not was.is_empty()
		piece["from"] = str(was.from) if not was.is_empty() else str(c.early.get(piece.id, ""))
		c.pieces.append(piece)
	c.query = query
	var ticked: Array = c.steps.filter(func(st): return st.done).map(func(st): return st.id)
	c.steps = steps.map(func(st): return {"id": st.id, "text": st.text, "done": c.solved or ticked.has(st.id)})
	c.optional = optional
	_seen_tables()
	notebook_changed.emit()


## Case `id`'s piece `piece_id` is found; `from` says where. One found before its
## case says what pieces it has is kept for then. True if it's newly found.
func collect_piece(id: String, piece_id: String, from: String = "") -> bool:
	var c := _case(id)
	var p := _piece(c, piece_id)
	if p.is_empty():
		if c.early.has(piece_id):
			return false
		c.early[piece_id] = from
		return true
	if p.found:
		return false
	p.found = true
	p.from = from
	notebook_changed.emit()
	piece_found.emit(id, piece_id)
	return true


func _piece(c: Dictionary, piece_id: String) -> Dictionary:
	for p in c.get("pieces", []):
		if p.id == piece_id:
			return p
	return {}


## Is case `id`'s piece `piece_id` found (or was it found before the case said)?
func has_piece(id: String, piece_id: String) -> bool:
	var c := case_info(id)
	if c.is_empty():
		return false
	var p := _piece(c, piece_id)
	return p.found if not p.is_empty() else c.get("early", {}).has(piece_id)


## Pieces whose table has turned up on the Tables page are found.
func _seen_tables() -> void:
	for c in notebook_cases:
		for p in c.get("pieces", []):
			if not p.found and notebook_tables.has(p.get("seen_in", "")):
				collect_piece(c.id, p.id, "Tables page")


## A crewmate's query read `table`: pieces seen in it are found for this player
## too (it's one crew), without it going on this player's Tables page.
func see_table_pieces(table: String, from: String) -> void:
	for c in notebook_cases:
		for p in c.get("pieces", []):
			if not p.found and p.get("seen_in", "") == table:
				collect_piece(c.id, p.id, from)


func pieces_found(id: String) -> int:
	return case_info(id).get("pieces", []).filter(func(p): return p.found).size()


func pieces_total(id: String) -> int:
	return case_info(id).get("pieces", []).size()


## Tick a step on case `id`'s checklist. True if it was unticked.
func tick_step(id: String, step_id: String) -> bool:
	for st in case_info(id).get("steps", []):
		if st.id == step_id and not st.done:
			st.done = true
			notebook_changed.emit()
			return true
	return false


## Case `id`'s query so far: each found piece written in, each missing one
## named as its hint names it (enter_column_name), or ???? for a word. A case
## that doesn't assemble (see set_assemble) stays the bare shape.
func case_query(id: String) -> String:
	var c := case_info(id)
	var q: String = c.get("query", "")
	var assemble: bool = c.get("assemble", true)
	for p in c.get("pieces", []):
		q = q.replace("{%s}" % p.id, str(p.value) if p.found and assemble else str(p.get("blank", PIECE_MISSING)))
	return q


## A puzzle under pressure is put together by the crew, not the notebook: with
## `on` false, case `id`'s page still lists the pieces found, but its query so
## far never writes them in.
func set_assemble(id: String, on: bool) -> void:
	_case(id).assemble = on
	notebook_changed.emit()


## A hint for case `id` just printed `text`: each piece whose value the query
## in it shows (white on the screen) is found, from SYSOP. Prose doesn't count.
func note_hint(id: String, text: String) -> void:
	var c := case_info(id)
	if not c.get("open", false) or c.solved:
		return
	var shown := ""
	for m in RegEx.create_from_string("\\[color=#ffffff\\]([\\s\\S]*?)\\[/color\\]").search_all(text):
		shown += m.get_string(1) + "\n"
	for p in c.get("pieces", []):
		if not p.found and hint_shows(shown, str(p.value)):
			collect_piece(id, p.id, "SYSOP")


## Does `text` show `value`? Names match as whole words, any case; signs (>) as is.
static func hint_shows(text: String, value: String) -> bool:
	if value == "":
		return false
	var low := text.to_lower()
	var v := value.to_lower()
	if not v.substr(0, 1).is_valid_identifier() and not v.substr(0, 1).is_valid_int():
		return low.contains(v)
	var re := RegEx.create_from_string("(?<![A-Za-z0-9_])" + _regex_escape(v) + "(?![A-Za-z0-9_])")
	return re.search(low) != null


static func _regex_escape(s: String) -> String:
	var out := ""
	for ch in s:
		out += ("\\" + ch) if "\\.^$|?*+()[]{}'".contains(ch) else ch
	return out


## Case `id`'s checklist, in order: [{text, done}]. Its pieces' tasks, then its
## steps, then (once the job is over) the tasks set while on it.
func case_checklist(id: String) -> Array:
	var c := case_info(id)
	var out: Array = []
	for p in c.get("pieces", []):
		out.append({"text": str(p.get("task", p.label)), "done": p.found})
	for st in c.get("steps", []):
		out.append({"text": st.text, "done": st.done})
	for t in notebook_todo:
		if t.get("case", "") == id and id != "":
			out.append({"text": t.text, "done": t.done or c.get("solved", false)})
	return out


## What to do next on case `id`: the first unticked line of its checklist, or "".
func case_next(id: String) -> String:
	for line in case_checklist(id):
		if not line.done:
			return line.text
	return ""


## The main case being worked on, with pieces to find: the newest open, unsolved,
## not optional one. "" if none. The HUD counts its pieces.
func main_case() -> String:
	for c in notebook_cases:
		if c.open and not c.solved and not c.get("optional", false) and not c.get("pieces", []).is_empty():
			return c.id
	return ""


## Solved cases, newest first: the notebook keeps them under Completed cases.
func completed_cases() -> Array:
	return notebook_cases.filter(func(c): return c.open and c.solved)


## The endings case `id` can have: [{id, name, hint}]. `hint` is the vague line
## shown for one not found yet.
func set_endings(id: String, endings: Array) -> void:
	_case(id).endings = endings.duplicate(true)
	notebook_changed.emit()


## How case `id` ended this time. Each ending found is kept on the player's
## profile ("ending:<case>:<ending>"), so the case shows it as found on later runs.
func reach_ending(id: String, ending_id: String) -> void:
	_case(id).ending = ending_id
	_earn("ending:%s:%s" % [id, ending_id])
	notebook_changed.emit()


## The other ways into case `id` (besides its main route): [{id, name}].
func set_routes(id: String, routes: Array) -> void:
	var c := _case(id)
	c.routes = routes.map(func(r): return {"id": r.id, "name": r.name, "found": c.get("routes_found", []).has(r.id)})
	notebook_changed.emit()


## This player found another way into case `id`. Kept on their profile like an
## ending. True if it's new this run.
func find_route(id: String, route_id: String) -> bool:
	var c := _case(id)
	var found: Array = c.get("routes_found", [])
	if found.has(route_id):
		return false
	found.append(route_id)
	c["routes_found"] = found
	for r in c.routes:
		if r.id == route_id:
			r.found = true
	_earn("route:%s:%s" % [id, route_id])
	notebook_changed.emit()
	return true


## Has this player ever found `source` ("ending:..."/"route:..."), this run or an earlier one?
func ever_found(source: String) -> bool:
	var net := get_node_or_null("/root/Net")
	return net != null and net.get("profile") != null and net.profile.earned.has(source)


func _earn(source: String) -> void:
	var net := get_node_or_null("/root/Net")
	if net and net.get("profile") != null:
		net.earn(source)


## The job the crew was hired for is over: the work order is void from now on
## and Tab opens on the case instead.
func end_job() -> void:
	if job_over:
		return
	job_over = true
	notebook_changed.emit()


## The task the player is on now, or "".
func current_todo() -> String:
	return notebook_todo[-1].text if not notebook_todo.is_empty() and not notebook_todo[-1].done else ""


## The notebook as plain data, for saving.
func notebook_data() -> Dictionary:
	return {"notes": notebook_notes.duplicate(), "tables": notebook_tables.duplicate(true), "written": notebook_written.duplicate(true), "todo": notebook_todo.duplicate(true), "cases": notebook_cases.duplicate(true), "jotted": notebook_jotted.duplicate(), "job_over": job_over}


func load_notebook(data: Dictionary) -> void:
	notebook_notes.assign(data.get("notes", []))
	notebook_tables = data.get("tables", {}).duplicate(true)
	notebook_written.assign(data.get("written", []))
	notebook_todo.assign(data.get("todo", []))
	notebook_cases.assign(data.get("cases", []))
	notebook_jotted.assign(data.get("jotted", []))
	job_over = data.get("job_over", false)
	notebook_changed.emit()


func _setup_input() -> void:
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_back", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("sprint", [KEY_SHIFT])
	_bind_keys("crouch", [KEY_CTRL, KEY_C])
	_bind_keys("jump", [KEY_SPACE])
	_bind_keys("interact", [KEY_E])
	_bind_keys("alt_interact", [KEY_X])
	_bind_keys("flashlight", [KEY_F])
	_bind_keys("pause", [KEY_ESCAPE])
	_bind_keys("notebook", [KEY_TAB])
	_bind_keys("inventory", [KEY_I])
	_bind_keys("sit", [KEY_Z])
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", click)
	if not InputMap.has_action("block"):
		InputMap.add_action("block")
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("block", right)


func _bind_keys(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
