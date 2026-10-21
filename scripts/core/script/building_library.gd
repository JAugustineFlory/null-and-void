class_name BuildingLibrary
extends RefCounted
## What the building offers a script, in any language: send a request to its
## services, and read its database. Plain Godot data in and out, so each language
## pack binds it under its own names (JavaScript: api.get/post/..., db.query).
## Waiting and writing to the log belong to the runtime itself.
##
## A test bench (Level 7) is the same library pointed at a copy of the building.

## A script tried to change the database while it's read-only (Protocol Epsilon,
## from Level 4). The level plays WARDEN's refusal (l4_write_refused and friends).
signal write_refused(sql: String)
## Every request a script sent, with the reply. Levels and co-op can follow it.
signal requested(method: String, path: String, headers: Dictionary, body: String, reply: Dictionary)

## The printed form of WARDEN's l4_write_refused line (approved 2026-10-21).
const WRITE_REFUSED := "WRITE REFUSED. THE DATABASE IS READ-ONLY UNDER PROTOCOL EPSILON."
const WRITE_WORDS := ["INSERT", "UPDATE", "DELETE", "REPLACE", "CREATE", "DROP", "ALTER", "PRAGMA", "UPSERT"]

var api: FacilityAPI
var db: FacilityDB
## Scripts arrive at Level 6, after Epsilon made the database read-only.
var read_only := true


func _init(p_api: FacilityAPI = null, p_db: FacilityDB = null) -> void:
	api = p_api
	db = p_db


## Sends a request to the building's services: {status, body}.
func request(method: String, path: String, headers := {}, body := "") -> Dictionary:
	var reply: Dictionary
	if api == null:
		reply = {"status": 503, "body": {"error": "This deck can't reach the building's services from here."}}
	else:
		reply = api.send(method, path, headers, body)
		reply.erase("text")
	requested.emit(method.to_upper(), path, headers, body, reply)
	return reply


## Reads the database: {ok, rows, error}. `params` fill the query's ? placeholders
## in order, so values never become part of the SQL text.
func query(sql: String, params := []) -> Dictionary:
	var res := {"ok": false, "rows": [], "error": ""}
	if db == null:
		res.error = "This deck can't reach the building's database from here."
		return res
	var text := sql.strip_edges().trim_suffix(";")
	var bare := _without_text(text)
	if bare.contains(";"):
		res.error = "One query at a time: db.query runs a single statement."
		return res
	if read_only and _is_write(bare):
		write_refused.emit(sql)
		res.error = WRITE_REFUSED
		return res
	var holes := bare.count("?")
	if holes != params.size():
		res.error = "The query has %d ? but %d value%s %s given." % [holes, params.size(), "" if params.size() == 1 else "s", "was" if params.size() == 1 else "were"]
		return res
	if params.is_empty():
		var r := db.execute(text)
		if not r.ok:
			res.error = "%s. %s" % [r.error, FacilityDB.explain_error(r.error)]
			return res
		res.rows = r.rows
	else:
		for word in FacilityDB.BLOCKED:
			if bare.to_upper().contains(word):
				res.error = "%s is disabled on this terminal." % word
				return res
		if not db.db.query_with_bindings(text, params):
			res.error = "%s. %s" % [db.db.error_message, FacilityDB.explain_error(db.db.error_message)]
			return res
		for row in db.db.query_result:
			var clean := {}
			for k in row.keys():
				clean[str(k)] = row[k]
			res.rows.append(clean)
	res.ok = true
	return res


## The SQL with anything in quotes taken out, so a ? or ; inside text doesn't count.
static func _without_text(sql: String) -> String:
	return RegEx.create_from_string("'(?:[^']|'')*'|\"(?:[^\"]|\"\")*\"").sub(sql, "''", true)


static func _is_write(bare: String) -> bool:
	var upper := bare.to_upper()
	for word in WRITE_WORDS:
		if RegEx.create_from_string("\\b%s\\b" % word).search(upper):
			return true
	return false
