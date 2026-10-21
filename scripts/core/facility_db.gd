class_name FacilityDB
extends RefCounted
## The building's database. A real SQLite database in memory.
## Doors and lights are rows: when players change them, the world changes.

signal door_changed(door_id: String, locked: bool, fault: bool)
signal light_changed(light_id: String, is_on: bool)
## A direct write was refused because the database is read-only (on the machine
## that ran it: in co-op, the host).
signal write_refused(sql: String)

const BLOCKED := ["ATTACH", "DETACH", "LOAD_EXTENSION", "VACUUM"]
## The statements that change something, by their first word.
const WRITE_WORDS := ["INSERT", "UPDATE", "DELETE", "REPLACE", "CREATE", "DROP", "ALTER", "PRAGMA", "UPSERT"]
## Building-wide tables. They exist before any wing loads; wings only INSERT their
## own rows, with ids prefixed by the wing (LOBBY-, SRA-, SEC-). The primary keys
## make a clash between two wings fail loudly instead of duplicating a door.
const SHARED_SCHEMA := """
CREATE TABLE IF NOT EXISTS doors (
	id TEXT PRIMARY KEY,
	name TEXT,
	zone TEXT,
	locked INTEGER,
	actuator_fault INTEGER
);
CREATE TABLE IF NOT EXISTS lights (
	id TEXT PRIMARY KEY,
	room TEXT,
	floor INTEGER,
	is_on INTEGER,
	status TEXT
);
CREATE TABLE IF NOT EXISTS badges (
	badge_id TEXT PRIMARY KEY,
	holder TEXT,
	clearance TEXT,
	last_seen TEXT
);
"""

var db: SQLite
## The whole database as SQL, as of the last checkpoint. `.reset` restores it.
var _checkpoint_sql := ""
## Wings whose seed data has been added, in load order.
var wings: Array[String] = []
## Containment protocol Epsilon (from Level 4 on): direct SQL writes (a terminal, a
## deck script's db.query) are refused with `read_only_error`. Reads still work, and
## so does game logic (run_silent) and the building's services (FacilityAPI routes),
## which don't go through execute. Shared state: set it from a sync.event handler.
## It belongs to the building, not its tables, so a checkpoint reload keeps it.
var read_only := false
var read_only_error := "WRITE REFUSED. THE DATABASE IS READ-ONLY UNDER PROTOCOL EPSILON."


func _init() -> void:
	db = SQLite.new()
	db.path = ":memory:"
	db.verbosity_level = 0
	db.open_db()


## Start a fresh building with one wing's data. Used when a level runs on its own.
func load_seed(sql: String) -> void:
	_drop_all()
	wings.clear()
	add_wing("", sql)


## Add a wing's seed data to the building and checkpoint. Returns false if the seed
## failed, for example because it reused another wing's door id.
func add_wing(wing_id: String, sql: String) -> bool:
	db.query(SHARED_SCHEMA)
	var ok: bool = db.query(sql)
	if not ok:
		push_error("FacilityDB: seed for wing '%s' failed: %s" % [wing_id, db.error_message])
	if wing_id != "":
		wings.append(wing_id)
	checkpoint()
	sync_world()
	return ok


## Remember the whole building's state. Called when a wing loads and at level checkpoints.
func checkpoint() -> void:
	_checkpoint_sql = dump()


## Restore the building to the last checkpoint, like restoring from a backup tape.
## Earlier wings keep the state they had at that checkpoint.
func reset() -> void:
	_drop_all()
	db.query(_checkpoint_sql)
	sync_world()


## Every table's schema and rows as SQL that rebuilds them.
func dump() -> String:
	var out := PackedStringArray()
	for t in run_silent("SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY rowid"):
		out.append(str(t["sql"]) + ";")
		for row in run_silent("SELECT * FROM \"%s\"" % t["name"]):
			var vals := PackedStringArray()
			for v in row.values():
				vals.append(_sql_literal(v))
			out.append("INSERT INTO \"%s\" VALUES (%s);" % [t["name"], ", ".join(vals)])
	return "\n".join(out)


static func _sql_literal(v: Variant) -> String:
	if v == null:
		return "NULL"
	if v is int or v is float:
		return str(v)
	if v is PackedByteArray:
		return "X'%s'" % v.hex_encode()
	return "'%s'" % str(v).replace("'", "''")


## Run a player's query. Returns {ok, error, columns, rows, changes}. `params` fill
## the query's ? placeholders in order (a deck script's db.query), so values never
## become part of the SQL text.
func execute(sql: String, params := []) -> Dictionary:
	var res := {"ok": false, "error": "", "columns": [], "rows": [], "changes": 0}
	var upper := sql.to_upper()
	for word in BLOCKED:
		if upper.contains(word):
			res.error = "%s is disabled on this terminal." % word
			return res
	if read_only and is_write(sql):
		return _refuse(res, sql)
	var before := _total_changes()
	if read_only:
		db.query("SAVEPOINT read_only")
	var ok: bool = db.query_with_bindings(sql, params) if params else db.query(sql)
	var raw: Array = db.query_result.duplicate() if ok else []
	var error: String = db.error_message
	res.changes = _total_changes() - before
	if read_only:
		if res.changes > 0:
			db.query("ROLLBACK TO read_only")
		db.query("RELEASE read_only")
		if res.changes > 0:
			res.changes = 0
			return _refuse(res, sql)
	if not ok:
		res.error = error
		res.changes = 0
		return res
	var rows := _normalize(raw)
	res.ok = true
	res.rows = rows
	if not rows.is_empty():
		res.columns = rows[0].keys()
	if res.changes > 0:
		sync_world()
	return res


## The statement changes something, by its first word. (A write hidden behind a WITH
## is caught by execute under read-only: it's rolled back when it changed rows.)
static func is_write(sql: String) -> bool:
	var words := sql.strip_edges().replace("\n", " ").replace("\t", " ").split(" ", false, 1)
	return not words.is_empty() and WRITE_WORDS.has(words[0].to_upper())


func _refuse(res: Dictionary, sql: String) -> Dictionary:
	res.error = read_only_error
	write_refused.emit(sql)
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
		for row in run_silent("SELECT id, is_on, status FROM lights"):
			light_changed.emit(str(row["id"]), int(row["is_on"]) == 1 and str(row["status"]) != "dead")


## A plain-English explanation of a SQLite error. The terminal prints it as SYSOP.
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
