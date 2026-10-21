extends Node
## Global game state and input setup. Autoloaded as `Game`.

## The notebook gained a sticky note or a table.
signal notebook_changed
## This player added the line that answers a case's blank (add_answer).
signal answer_found(case_id: String)
## A line went into the notebook as a plain note (it answered no blank): a
## terminal row (kind "row") or a paper's line ("document").
signal line_noted(text: String, kind: String)

const LEVELS := {
	"world": "res://scenes/world.tscn",
	"level_0": "res://scenes/level_0.tscn",
	"level_1": "res://scenes/level_1.tscn",
	"level_2": "res://scenes/level_2.tscn",
	"level_3": "res://scenes/level_3.tscn",
	"level_4": "res://scenes/level_4.tscn",
	"movement_gym": "res://scenes/movement_gym.tscn",
	"field_notes": "res://scenes/field_notes.tscn",
	"menu": "res://scenes/main_menu.tscn",
	"lobby": "res://scenes/lobby.tscn",
	"customize": "res://scenes/customize.tscn",
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
## The ticket's task list, in the character's hand as tasks come up:
## {text, done, filled}. `filled` is what was written in once it was done.
var notebook_todo: Array[Dictionary] = []
## Case pages: one per puzzle, so everything found about it is in one place.
## {id, title, open, solved, how, tables, clues: [{text, from}]}. Clues read before
## the case opens are kept and show once it does.
var notebook_cases: Array[Dictionary] = []
## Voice line ids already jotted down this run, so a replayed line isn't jotted twice.
var notebook_jotted: Array[String] = []


func _ready() -> void:
	_setup_input()
	new_run()


func new_run(seed_value: int = -1) -> void:
	run_seed = seed_value if seed_value >= 0 else randi()
	open_at_home = false
	book_words.clear()
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
	notebook_cases.clear()
	notebook_jotted.clear()
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


## The case being worked on: the newest open one not yet solved, or "".
func current_case() -> String:
	for c in notebook_cases:
		if c.open and not c.solved:
			return c.id
	return ""


## A new task on the job ticket; the one before it is ticked off. "" ticks off
## the current task and adds nothing. False if nothing changed.
func set_todo(text: String) -> bool:
	if text != "" and current_todo() == text:
		return false
	var changed := false
	for t in notebook_todo:
		if not t.done:
			t.done = true
			changed = true
	if text != "":
		notebook_todo.append({"text": text, "done": false, "filled": ""})
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
	return t


## The work order number, the same all run.
func ticket_number() -> String:
	return "WO-%05d" % (run_seed % 100000)


func _case(id: String) -> Dictionary:
	for c in notebook_cases:
		if c.id == id:
			return c
	var c := {"id": id, "title": "", "open": false, "solved": false, "how": "", "tables": [], "clues": []}
	notebook_cases.append(c)
	return c


## Open a case page: `title` is the question, never its answer; `tables` are the
## ones that matter (the page only names those this player has found). True if new.
func open_case(id: String, title: String, tables: Array = []) -> bool:
	var c := _case(id)
	if c.open:
		return false
	c.title = title
	c.open = true
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
func add_answer(text: String) -> bool:
	var id := answers(text)
	if id == "" or not fill_blank(id):
		return false
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


## The task the player is on now, or "".
func current_todo() -> String:
	return notebook_todo[-1].text if not notebook_todo.is_empty() and not notebook_todo[-1].done else ""


## The notebook as plain data, for saving.
func notebook_data() -> Dictionary:
	return {"notes": notebook_notes.duplicate(), "tables": notebook_tables.duplicate(true), "written": notebook_written.duplicate(true), "todo": notebook_todo.duplicate(true), "cases": notebook_cases.duplicate(true), "jotted": notebook_jotted.duplicate()}


func load_notebook(data: Dictionary) -> void:
	notebook_notes.assign(data.get("notes", []))
	notebook_tables = data.get("tables", {}).duplicate(true)
	notebook_written.assign(data.get("written", []))
	notebook_todo.assign(data.get("todo", []))
	notebook_cases.assign(data.get("cases", []))
	notebook_jotted.assign(data.get("jotted", []))
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
