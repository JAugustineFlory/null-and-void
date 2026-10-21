class_name BuildingLibrary
extends RefCounted
## What the building offers a script, in any language: send a request to its
## services, and read its database. Plain Godot data in and out, so each language
## pack binds it under its own names (JavaScript: api.get/post/..., db.query).
## Waiting and writing to the log belong to the runtime itself.
##
## A test bench (Level 7) is the same library pointed at a copy of the building.
##
## Queries run through FacilityDB.execute, so the building's own rules hold for
## scripts as at a terminal: under Protocol Epsilon (FacilityDB.read_only, from
## Level 4) a write is refused with the building's read_only_error and its
## write_refused signal fires, which is where the level plays WARDEN's lines.

## Every request a script sent, with the reply. Levels and co-op can follow it.
signal requested(method: String, path: String, headers: Dictionary, body: String, reply: Dictionary)

var api: FacilityAPI
var db: FacilityDB


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


## Reads the database: {ok, rows, error, refused}. `params` fill the query's ?
## placeholders in order, so values never become part of the SQL text. `refused`
## is true when the building refused a write (read-only), and `error` is then its
## refusal as WARDEN says it.
func query(sql: String, params := []) -> Dictionary:
	var res := {"ok": false, "rows": [], "error": "", "refused": false}
	if db == null:
		res.error = "This deck can't reach the building's database from here."
		return res
	var text := sql.strip_edges().trim_suffix(";")
	var bare := _without_text(text)
	if bare.contains(";"):
		res.error = "One query at a time: db.query runs a single statement."
		return res
	var holes := bare.count("?")
	if holes != params.size():
		res.error = "The query has %d ? but %d value%s %s given." % [holes, params.size(), "" if params.size() == 1 else "s", "was" if params.size() == 1 else "were"]
		return res
	var r := db.execute(text, params)
	if not r.ok:
		res.refused = db.read_only and r.error == db.read_only_error
		res.error = r.error if res.refused else "%s. %s" % [r.error, FacilityDB.explain_error(r.error)]
		return res
	res.rows = r.rows
	res.ok = true
	return res


## The SQL with anything in quotes taken out, so a ? or ; inside text doesn't count.
static func _without_text(sql: String) -> String:
	return RegEx.create_from_string("'(?:[^']|'')*'|\"(?:[^\"]|\"\")*\"").sub(sql, "''", true)

