class_name GuardedDB
extends FacilityDB
## The building's database as a terminal on floor 10 sees it: the same SQLite, with
## a rule in front of the player's writes. The controller won't take a door write
## until a contractor has logged in (the clipboard's rule). (Epsilon's read-only is
## the building's own, FacilityDB.read_only: the base refuses those.)
##
## `guard` is called with each query before it runs and returns the refusal to print
## (as the query's error), or "" to let it through. `check` is called after a write
## has run, inside a savepoint: a refusal from it rolls the write back, as a machine's
## own controller refusing a command it can't carry out (the gantry's interlock). Game logic (run_silent) and every
## other method act on the building's database directly, so doors and lights still
## follow the shared rows, and .reset restores the building's own checkpoint.

var base: FacilityDB
var guard: Callable
var check: Callable


static func over(building: FacilityDB, p_guard: Callable, p_check := Callable()) -> GuardedDB:
	var g := GuardedDB.new()
	g.db.close_db()  # its own empty database: everything goes to the building's
	g.db = building.db
	g.base = building
	g.guard = p_guard
	g.check = p_check
	return g


func execute(sql: String, params := []) -> Dictionary:
	if guard.is_valid():
		var refused: String = guard.call(sql)
		if refused != "":
			return _refusal(refused)
	if not check.is_valid() or base.read_only or not is_write(sql):
		return base.execute(sql, params)
	db.query("SAVEPOINT guarded")
	var res := base.execute(sql, params)
	if res.ok and int(res.changes) > 0:
		var refused: String = check.call()
		if refused != "":
			db.query("ROLLBACK TO guarded")
			db.query("RELEASE guarded")
			base.sync_world()
			return _refusal(refused)
	db.query("RELEASE guarded")
	return res


static func _refusal(text: String) -> Dictionary:
	return {"ok": false, "error": text, "columns": [], "rows": [], "changes": 0}


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
