class_name GuardedDB
extends FacilityDB
## The building's database as a terminal on floor 10 sees it: the same SQLite, with
## a rule in front of the player's writes. The controller won't take a door write
## until a contractor has logged in (the clipboard's rule), and once Protocol
## Epsilon makes the database read-only no terminal takes any write at all.
##
## `guard` is called with each query before it runs and returns the refusal to print
## (as the query's error), or "" to let it through. Game logic (run_silent) and every
## other method act on the building's database directly, so doors and lights still
## follow the shared rows, and .reset restores the building's own checkpoint.

## UPDATE, INSERT and the rest: the statements that change something.
const WRITE_WORDS := ["INSERT", "UPDATE", "DELETE", "REPLACE", "CREATE", "DROP", "ALTER", "PRAGMA", "UPSERT"]

var base: FacilityDB
var guard: Callable


static func over(building: FacilityDB, p_guard: Callable) -> GuardedDB:
	var g := GuardedDB.new()
	g.db.close_db()  # its own empty database: everything goes to the building's
	g.db = building.db
	g.base = building
	g.guard = p_guard
	return g


## The statement's first word changes something.
static func is_write(sql: String) -> bool:
	var words := sql.strip_edges().split(" ", false, 1)
	return not words.is_empty() and WRITE_WORDS.has(words[0].to_upper())


func execute(sql: String) -> Dictionary:
	if guard.is_valid():
		var refused: String = guard.call(sql)
		if refused != "":
			return {"ok": false, "error": refused, "columns": [], "rows": [], "changes": 0}
	return base.execute(sql)


func load_seed(sql: String) -> void:
	base.load_seed(sql)


func add_wing(wing_id: String, sql: String) -> bool:
	return base.add_wing(wing_id, sql)


func checkpoint() -> void:
	base.checkpoint()


func reset() -> void:
	base.reset()


func sync_world() -> void:
	base.sync_world()
