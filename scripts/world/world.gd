class_name World
extends LevelBase
## The whole building as one continuous map. Each level is a wing scene that is built
## behind a closed door before players reach it, so nobody sees a loading screen and
## co-op peers never have to change scene together.
##
## The World owns the player, HUD, terminal screen and the one FacilityDB for the
## building. Each wing adds its own seed tables when it loads (see LevelBase).
## Co-op: the host decides when to call load_next() and wing_finished(); every peer
## builds the same wing from Game.run_seed, so the geometry and data match.

signal wing_loaded(wing: LevelBase)
signal wing_entered(wing: LevelBase)
signal checkpoint_reached(wing_id: String)

## Play order, and where each wing sits in the building (its origin and facing).
## Server Room A is turned so its antechamber meets the end of the lobby hall at x = 24.
## The security wing faces the same way; its stair landing meets Server Room A's exit corridor at x = 54.
const ROUTE := [
	{"key": "level_0", "scene": "res://scenes/level_0.tscn", "at": Transform3D.IDENTITY},
	{"key": "level_1", "scene": "res://scenes/level_1.tscn", "at": Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(38, 0, 3))},
	{"key": "level_2", "scene": "res://scenes/level_2.tscn", "at": Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(64, 0, -1))},
]
const FIELD_NOTES := "res://scenes/field_notes.tscn"

## Wings that stay loaded once found, like the safe-room hub.
var keep_loaded: Array[String] = []
## Loaded wings by key.
var wings := {}
var current: LevelBase
var _field_notes: CanvasLayer


func start() -> void:
	enter_wing(0)


func route_index(key: String) -> int:
	for i in ROUTE.size():
		if ROUTE[i].key == key:
			return i
	return -1


## Build a wing in place, if it isn't already. Its door stays shut until its story opens it.
func load_wing(index: int) -> LevelBase:
	var entry: Dictionary = ROUTE[index]
	if wings.has(entry.key):
		return wings[entry.key]
	var wing: LevelBase = load(entry.scene).instantiate()
	wing.wing_id = entry.key
	wing.transform = entry.at
	add_child(wing)  # builds its geometry and adds its seed data to the shared database
	wings[entry.key] = wing
	wing_loaded.emit(wing)
	return wing


## Load the wing after `wing`, behind its closed door.
func load_next(wing: LevelBase) -> void:
	var i := route_index(wing.wing_id) + 1
	if i > 0 and i < ROUTE.size():
		load_wing(i)


## Hand play to a wing: its lighting mood and story take over.
func enter_wing(index: int) -> void:
	current = load_wing(index)
	if index == 0:
		players.place_all(current)
	current.activate()
	_unload_behind(index)
	wing_entered.emit(current)


## A wing's story is done: checkpoint, then move on to the next wing, or show
## Field Notes at the end of the route.
func wing_finished(wing: LevelBase) -> void:
	db.checkpoint()
	checkpoint_reached.emit(wing.wing_id)
	var next := route_index(wing.wing_id) + 1
	if next < ROUTE.size():
		enter_wing(next)
	else:
		show_field_notes()


## Close the door players came through. Co-op: call once every player is through.
func seal_behind(wing: LevelBase) -> void:
	var i := route_index(wing.wing_id)
	if i <= 0:
		return
	var prev: LevelBase = wings.get(ROUTE[i - 1].key)
	if prev and prev.exit_door:
		prev.exit_door.set_open(false)


func on_player_died() -> void:
	if current:
		current.on_player_died()
	else:
		super()


## Field Notes as an overlay on the live world, instead of a separate scene.
func show_field_notes() -> void:
	if _field_notes:
		return
	player.input_locked = true
	_field_notes = CanvasLayer.new()
	_field_notes.layer = 25
	add_child(_field_notes)
	_field_notes.add_child(load(FIELD_NOTES).instantiate())


## Free wings two or more behind the current one; players can't get back to them.
func _unload_behind(index: int) -> void:
	for i in range(0, index - 1):
		var key: String = ROUTE[i].key
		if wings.has(key) and not keep_loaded.has(key):
			wings[key].queue_free()
			wings.erase(key)
