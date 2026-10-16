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
}

## How the escort's story went: "unknown", "killed", "tied".
var rourke_fate := "unknown"
var has_walkie := false
## Did the players lock the Watcher in behind them in Level 2?
var watcher_sealed := false
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


func _ready() -> void:
	_setup_input()
	new_run()


func new_run(seed_value: int = -1) -> void:
	run_seed = seed_value if seed_value >= 0 else randi()
	rourke_fate = "unknown"
	has_walkie = false
	watcher_sealed = false
	completed_level = ""
	next_level = ""
	query_log.clear()
	concepts_learned.clear()
	notebook_notes.clear()
	notebook_tables.clear()


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


## The notebook as plain data, for saving.
func notebook_data() -> Dictionary:
	return {"notes": notebook_notes.duplicate(), "tables": notebook_tables.duplicate(true)}


func load_notebook(data: Dictionary) -> void:
	notebook_notes.assign(data.get("notes", []))
	notebook_tables = data.get("tables", {}).duplicate(true)
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
