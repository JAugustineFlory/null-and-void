class_name FacilityDB
extends RefCounted
## The building's database. A real SQLite database in memory.
## Doors and lights are rows: when players change them, the world changes.

signal door_changed(door_id: String, locked: bool, fault: bool)
signal light_changed(light_id: String, is_on: bool)

const BLOCKED := ["ATTACH", "DETACH", "LOAD_EXTENSION", "VACUUM"]

var db: SQLite
var _seed_sql := ""


func _init() -> void:
	db = SQLite.new()
	db.path = ":memory:"
	db.verbosity_level = 0
	db.open_db()


## Load (or reload) the level's starting data.
func load_seed(sql: String) -> void:
	_seed_sql = sql
	_drop_all()
	db.query(sql)
	sync_world()


## Restore the level's starting data, like restoring from a backup tape.
func reset() -> void:
	load_seed(_seed_sql)


## Run a player's query. Returns {ok, error, columns, rows, changes}.
func execute(sql: String) -> Dictionary:
	var res := {"ok": false, "error": "", "columns": [], "rows": [], "changes": 0}
	var upper := sql.to_upper()
	for word in BLOCKED:
		if upper.contains(word):
			res.error = "%s is disabled on this terminal." % word
			return res
	var before := _total_changes()
	var ok: bool = db.query(sql)
	if not ok:
		res.error = db.error_message
		return res
	var rows := _normalize(db.query_result)
	res.ok = true
	res.rows = rows
	if not rows.is_empty():
		res.columns = rows[0].keys()
	res.changes = _total_changes() - before
	if res.changes > 0:
		sync_world()
	return res


## Run a query for game logic, not shown to players.
func run_silent(sql: String) -> Array:
	if not db.query(sql):
		push_error("FacilityDB query failed: %s\n%s" % [db.error_message, sql])
		return []
	return _normalize(db.query_result)


func table_names() -> Array:
	var names := []
	for row in run_silent("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"):
		names.append(row["name"])
	return names


func table_schema(table: String) -> Array:
	if not table_names().has(table):
		return []
	return run_silent("PRAGMA table_info(%s)" % table)


## Push the current state of doors and lights out to the world.
func sync_world() -> void:
	var names := table_names()
	if names.has("doors"):
		for row in run_silent("SELECT id, locked, actuator_fault FROM doors"):
			door_changed.emit(str(row["id"]), int(row["locked"]) == 1, int(row["actuator_fault"]) == 1)
	if names.has("lights"):
		for row in run_silent("SELECT id, is_on FROM lights"):
			light_changed.emit(str(row["id"]), int(row["is_on"]) == 1)


## A plain-English explanation of a SQLite error, in WARDEN's voice.
static func explain_error(err: String) -> String:
	var e := err.to_lower()
	if e.contains("no such table"):
		return "That table doesn't exist. Type .tables to see the ones that do."
	if e.contains("no such column"):
		return "That column isn't in the table. Type .schema followed by the table name to list its columns."
	if e.contains("incomplete input") or e.contains("unrecognized token"):
		return "The query ends too early. Is a 'quote' or (bracket) left open?"
	if e.contains("syntax error"):
		return "I can't parse that. Check keyword spelling, and put text values in 'single quotes'."
	if e.contains("readonly") or e.contains("read-only"):
		return "This terminal is read-only."
	if e.contains("disabled"):
		return "Nice try."
	return "The database refused that query. Read the error above; it usually says exactly what's wrong."


## Copy rows with plain String column names. Newer godot-sqlite builds return
## StringName keys, which don't compare equal to Strings inside Arrays.
func _normalize(rows: Array) -> Array:
	var out := []
	for row in rows:
		var clean := {}
		for k in row.keys():
			clean[str(k)] = row[k]
		out.append(clean)
	return out


func _total_changes() -> int:
	db.query("SELECT total_changes() AS n")
	return int(db.query_result[0]["n"])


func _drop_all() -> void:
	db.query("PRAGMA foreign_keys = OFF")
	for t in table_names():
		db.query("DROP TABLE IF EXISTS \"%s\"" % t)
