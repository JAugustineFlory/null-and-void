extends Node
## Global game state and input setup. Autoloaded as `Game`.

const LEVELS := {
	"level_0": "res://scenes/level_0.tscn",
	"level_1": "res://scenes/level_1.tscn",
	"field_notes": "res://scenes/field_notes.tscn",
	"menu": "res://scenes/main_menu.tscn",
}

## How the escort's story went: "unknown", "killed", "tied".
var rourke_fate := "unknown"
var has_walkie := false
## Every successful query the players ran, for the Field Notes screen.
var query_log: Array[String] = []
## Concepts the players have used, in the order they first used them.
var concepts_learned: Array[String] = []
## Seed for this run's randomized data (replay scenarios).
var run_seed := 0


func _ready() -> void:
	_setup_input()
	new_run()


func new_run(seed_value: int = -1) -> void:
	run_seed = seed_value if seed_value >= 0 else randi()
	rourke_fate = "unknown"
	has_walkie = false
	query_log.clear()
	concepts_learned.clear()


func goto(level_key: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(LEVELS[level_key])


func log_query(sql: String) -> void:
	query_log.append(sql.strip_edges())
	var upper := sql.to_upper()
	for concept in ["SELECT", "FROM", "ORDER BY", "WHERE", "AND", "OR", "LIKE"]:
		var pattern := RegEx.create_from_string("\\b" + concept.replace(" ", "\\s+") + "\\b")
		if pattern.search(upper) and not concepts_learned.has(concept):
			concepts_learned.append(concept)


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
