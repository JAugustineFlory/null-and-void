class_name FacilityAPI
extends RefCounted
## The building's HTTP API, as seen from a terminal. Levels register routes;
## players type real requests like `GET /cameras` and get real JSON back.
##
## Writes (POST, PUT, PATCH, DELETE) carry a JSON body, and a route can require
## an API key sent in an `X-Api-Key` header. A request is typed on one line, or in
## HTTP's own layout (request line, headers, a blank line, then the body):
##
##   PATCH /doors/D-12 {"locked": false}
##
##   PATCH /doors/D-12
##   X-Api-Key: 7f3a-22
##
##   {"locked": false}
##
## The checks run in the order real services use: is there such a route (404),
## does it take this method (405), who's asking (401, 403), is the body JSON (400),
## then the handler, which can still answer 400, 404 or 409 itself.

const METHODS := ["GET", "POST", "PUT", "PATCH", "DELETE"]
const KEY_HEADER := "x-api-key"
const STATUS_TEXT := {200: "OK", 201: "Created", 204: "No Content", 400: "Bad Request",
	401: "Unauthorized", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed", 409: "Conflict", 503: "Service Unavailable"}

## "METHOD /path" -> {handler, scope}. A path segment written as ":name" matches
## anything and is passed in params. The handler is either
## Callable(params: Array) or Callable(params: Array, req: Dictionary), and returns
## {status: int, body: Variant}. req is {method, path, headers, body, key}: headers
## have lower-case names, body is the parsed JSON (or null), key is the caller's
## key record ({key, scopes, label}) on a keyed route.
var _routes := {}
## API key -> {key, scopes, label}.
var _keys := {}


## Adds a route. With `scope`, callers need an API key that has that scope.
func route(method: String, path: String, handler: Callable, scope := "") -> void:
	_routes["%s %s" % [method.to_upper(), path]] = {"handler": handler, "scope": scope}


## Adds an API key that can call routes with any of `scopes`. `label` names
## whose key it is, for the level's own checks (e.g. "HR clerk").
func add_key(key: String, scopes: Array, label := "") -> void:
	_keys[key] = {"key": key, "scopes": scopes, "label": label}


## Is this line an HTTP request rather than SQL?
static func is_request(line: String) -> bool:
	var first_line := line.strip_edges().get_slice("\n", 0)
	var first := first_line.get_slice(" ", 0).to_upper()
	return METHODS.has(first) and first_line.contains("/")


## Handle a request as typed at a terminal. Returns {status, body, text} where
## text is the pretty-printed JSON body.
func request(typed: String) -> Dictionary:
	var lines := typed.strip_edges().replace("\r", "").split("\n")
	var parts := lines[0].strip_edges().split(" ", false, 2)
	var method := parts[0].to_upper()
	var path := parts[1] if parts.size() > 1 else "/"
	var body := parts[2] if parts.size() > 2 else ""
	var headers := {}
	var i := 1
	# Headers run until a blank line or the body's opening { or [.
	while i < lines.size() and body == "":
		var line := lines[i].strip_edges()
		i += 1
		if line == "":
			break
		if line.begins_with("{") or line.begins_with("["):
			i -= 1
			break
		if not line.contains(":"):
			return _reply({"status": 400, "body": {"error": "Line %d isn't a header. Headers look like Name: value (X-Api-Key: ...), then a blank line, then the JSON body." % i}})
		headers[line.get_slice(":", 0).strip_edges()] = line.substr(line.find(":") + 1).strip_edges()
	if body == "" and i < lines.size():
		body = "\n".join(lines.slice(i))
	return send(method, path, headers, body)


## Handle one request. Used by the terminal (through request) and by deck scripts.
func send(method: String, path: String, headers := {}, body := "") -> Dictionary:
	method = method.to_upper()
	path = path.strip_edges().trim_suffix(";").trim_suffix("/")
	if not path.begins_with("/"):
		path = "/" + path
	var lower := {}
	for h in headers:
		lower[str(h).to_lower()] = str(headers[h])
	return _reply(_dispatch(method, path, lower, body.strip_edges().trim_suffix(";")))


static func status_text(code: int) -> String:
	return STATUS_TEXT.get(code, "")


## A JSON body's fields checked against what a route takes, as
## {name: TYPE_BOOL, ...}. Returns "" when the body fits, else what's wrong,
## ready for a 400 reply. Whole-number JSON reads as TYPE_INT; a TYPE_FLOAT field
## takes either.
static func check_fields(body: Variant, required: Dictionary, optional := {}) -> String:
	if not body is Dictionary:
		return "The body should be a JSON object: { \"name\": value }"
	for field in body:
		if not required.has(field) and not optional.has(field):
			return "This service doesn't take \"%s\". It takes: %s" % [field, ", ".join(PackedStringArray(required.keys() + optional.keys()))]
	for field in required:
		if not body.has(field):
			return "The body is missing \"%s\"." % field
	for field in body:
		var want: int = required.get(field, optional.get(field))
		if not _fits(body[field], want):
			return "\"%s\" should be %s." % [field, _type_name(want)]
	return ""


static func _fits(v: Variant, want: int) -> bool:
	if want == TYPE_FLOAT:
		return v is float or v is int
	return typeof(v) == want


static func _type_name(t: int) -> String:
	match t:
		TYPE_BOOL: return "true or false"
		TYPE_INT: return "a whole number"
		TYPE_FLOAT: return "a number"
		TYPE_STRING: return "text in double quotes"
		TYPE_ARRAY: return "a list: [ ... ]"
		TYPE_DICTIONARY: return "an object: { ... }"
	return "something else"


func _reply(res: Dictionary) -> Dictionary:
	res["text"] = JSON.stringify(res.body, "  ", false)
	return res


func _dispatch(method: String, path: String, headers: Dictionary, body: String) -> Dictionary:
	var segs := path.split("/", false)
	var allowed := []
	for key in _routes:
		var k_method: String = key.get_slice(" ", 0)
		var k_segs: PackedStringArray = key.get_slice(" ", 1).split("/", false)
		if k_segs.size() != segs.size():
			continue
		var params := []
		var ok := true
		for i in segs.size():
			if k_segs[i].begins_with(":"):
				params.append(segs[i])
			elif k_segs[i].to_lower() != segs[i].to_lower():
				ok = false
				break
		if not ok:
			continue
		if k_method != method:
			allowed.append(k_method)
			continue
		return _call(_routes[key], params, method, path, headers, body)
	if not allowed.is_empty():
		if not _has_writes():
			return {"status": 405, "body": {"error": "%s is not allowed on %s. This terminal is read-only." % [method, path]}}
		return {"status": 405, "body": {"error": "%s is not allowed on %s. It takes: %s" % [method, path, ", ".join(PackedStringArray(allowed))]}}
	return {"status": 404, "body": {"error": "Nothing at %s. Try GET %s" % [path, _example()]}}


func _call(r: Dictionary, params: Array, method: String, path: String, headers: Dictionary, body: String) -> Dictionary:
	var key_record = null
	if r.scope != "":
		if not headers.has(KEY_HEADER) or headers[KEY_HEADER] == "":
			return {"status": 401, "body": {"error": "This service needs an API key, sent in a header: X-Api-Key: <key>"}}
		key_record = _keys.get(headers[KEY_HEADER])
		if key_record == null:
			return {"status": 401, "body": {"error": "That API key isn't valid. Check it character by character."}}
		if not r.scope in key_record.scopes:
			return {"status": 403, "body": {"error": "That key is valid, but it isn't allowed to do this."}}
	var parsed: Variant = null
	if body != "" and method != "GET":  # a GET's body is ignored, as most servers do
		var j := StrictJSON.parse(body)
		if not j.ok:
			return {"status": 400, "body": {"error": "The body isn't valid JSON (line %d): %s" % [j.line, j.message]}}
		parsed = j.value
	elif method == "POST" or method == "PUT" or method == "PATCH":
		return {"status": 400, "body": {"error": "%s needs a JSON body, like %s %s {\"name\": value}" % [method, method, path]}}
	var handler: Callable = r.handler
	if handler.get_argument_count() < 2:
		return handler.call(params)
	return handler.call(params, {"method": method, "path": path, "headers": headers, "body": parsed, "key": key_record})


func _has_writes() -> bool:
	for key in _routes:
		if not key.begins_with("GET "):
			return true
	return false


func _example() -> String:
	for key in _routes:
		if key.begins_with("GET ") and not key.contains(":"):
			return key.get_slice(" ", 1)
	return "/"
