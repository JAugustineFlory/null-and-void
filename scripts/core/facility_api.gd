class_name FacilityAPI
extends RefCounted
## The building's HTTP API, as seen from a terminal. Levels register routes;
## players type real requests like `GET /cameras` and get real JSON back.
## Later levels add POST and PATCH routes the same way.

const METHODS := ["GET", "POST", "PUT", "PATCH", "DELETE"]

## "METHOD /path" -> Callable(params: Array) -> {status: int, body: Variant}.
## A path segment written as ":name" matches anything and is passed in params.
var _routes := {}


func route(method: String, path: String, handler: Callable) -> void:
	_routes["%s %s" % [method.to_upper(), path]] = handler


## Is this line an HTTP request rather than SQL?
static func is_request(line: String) -> bool:
	var first := line.strip_edges().get_slice(" ", 0).to_upper()
	return METHODS.has(first) and line.strip_edges().contains("/")


## Handle one request line, e.g. "GET /cameras". Returns {status, body, text}
## where text is the pretty-printed JSON body.
func request(line: String) -> Dictionary:
	var parts := line.strip_edges().split(" ", false)
	var method := parts[0].to_upper()
	var path := parts[1] if parts.size() > 1 else "/"
	path = path.trim_suffix(";").trim_suffix("/")
	if not path.begins_with("/"):
		path = "/" + path
	var res := _dispatch(method, path)
	res["text"] = JSON.stringify(res.body, "  ", false)
	return res


static func status_text(code: int) -> String:
	return {200: "OK", 201: "Created", 400: "Bad Request", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed"}.get(code, "")


func _dispatch(method: String, path: String) -> Dictionary:
	var segs := path.split("/", false)
	var path_known := false
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
		path_known = true
		if k_method == method:
			return _routes[key].call(params)
	if path_known:
		return {"status": 405, "body": {"error": "%s is not allowed on %s. This terminal is read-only." % [method, path]}}
	return {"status": 404, "body": {"error": "Nothing at %s. Try GET %s" % [path, _example()]}}


func _example() -> String:
	for key in _routes:
		if key.begins_with("GET ") and not key.contains(":"):
			return key.get_slice(" ", 1)
	return "/"
