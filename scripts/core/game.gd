extends Node
## Global game state and input setup. Autoloaded as `Game`.

## The notebook gained a sticky note or a table.
signal notebook_changed

const LEVELS := {
	"world": "res://scenes/world.tscn",
	"level_0": "res://scenes/level_0.tscn",
	"level_1": "res://scenes/level_1.tscn",
	"level_2": "res://scenes/level_2.tscn",
	"movement_gym": "res://scenes/movement_gym.tscn",
	"field_notes": "res://scenes/field_notes.tscn",
	"menu": "res://scenes/main_menu.tscn",
	"lobby": "res://scenes/lobby.tscn",
}

## How the escort's story went: "unknown", "killed", "tied".
var rourke_fate := "unknown"
var has_walkie := false
## Did the players lock the Watcher in behind them in Level 2?
var watcher_sealed := false
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
## This player's notebook. Each machine keeps its own, so in co-op a note belongs to
## whoever picked it up. Sticky note ids, in the order found (see StickyNotes).
var notebook_notes: Array[String] = []
## Tables this player has discovered: name -> column names.
var notebook_tables := {}
## Lines this player wrote down from a terminal: {label, text, kind}.
var notebook_written: Array[Dictionary] = []
## The crew's Byte-Right job ticket, clipped in the notebook: the call-out they were
## hired for. These lines are printed on it; the tasks are written in by hand.
const TICKET := {
	"company": "BYTE-RIGHT IT SERVICES",
	"customer": "Halcyon Data Systems",
	"problem": "\"database problem\", night call-out",
	"contact": "D. Rourke (night escort)",
}
## The ticket's task list, in the character's hand as tasks come up:
## {text, done, filled}. `filled` is what was written in once it was done.
var notebook_todo: Array[Dictionary] = []


func _ready() -> void:
	_setup_input()
	new_run()


func new_run(seed_value: int = -1) -> void:
	run_seed = seed_value if seed_value >= 0 else randi()
	rourke_fate = "unknown"
	has_walkie = false
	watcher_sealed = false
	cam_lie_learned = false
	completed_level = ""
	next_level = ""
	query_log.clear()
	concepts_learned.clear()
	notebook_notes.clear()
	notebook_tables.clear()
	notebook_written.clear()
	notebook_todo.clear()


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


## Write a terminal line into the notebook, under the player's own label.
func write_note(label: String, text: String, kind: String) -> void:
	notebook_written.append({"label": label, "text": text, "kind": kind})
	notebook_changed.emit()


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
	t["tasks"] = notebook_todo.duplicate(true)
	return t


## The work order number, the same all run.
func ticket_number() -> String:
	return "WO-%05d" % (run_seed % 100000)


## The task the player is on now, or "".
func current_todo() -> String:
	return notebook_todo[-1].text if not notebook_todo.is_empty() and not notebook_todo[-1].done else ""


## The notebook as plain data, for saving.
func notebook_data() -> Dictionary:
	return {"notes": notebook_notes.duplicate(), "tables": notebook_tables.duplicate(true), "written": notebook_written.duplicate(true), "todo": notebook_todo.duplicate(true)}


func load_notebook(data: Dictionary) -> void:
	notebook_notes.assign(data.get("notes", []))
	notebook_tables = data.get("tables", {}).duplicate(true)
	notebook_written.assign(data.get("written", []))
	notebook_todo.assign(data.get("todo", []))
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
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", click)


func _bind_keys(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
