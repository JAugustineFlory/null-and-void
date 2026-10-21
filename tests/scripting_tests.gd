extends RefCounted
## Scripting and services: the facility API's write side (POST, PATCH, JSON
## bodies, API keys, status codes) and the strict JSON reader behind it. Level 2's
## read-only GET routes are tested in run_tests.gd (test_facility_api).

var _check: Callable


func run(_tree: SceneTree, check: Callable) -> void:
	_check = check
	print("StrictJSON")
	test_strict_json()
	print("FacilityAPI writes")
	test_requests_are_recognised()
	test_api_keys()
	test_json_bodies()
	test_body_fields()
	test_created_and_conflict()
	test_wrong_method()
	test_old_routes_unchanged()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


## A small building: two doors (D-12 needs the "doors" scope to change) and a
## badge office (POST needs "hr").
func _api() -> Array:
	var doors := {"D-12": {"id": "D-12", "locked": true}, "D-14": {"id": "D-14", "locked": true}}
	var badges := {"B-1": {"id": "B-1", "holder": "Rourke"}}
	var api := FacilityAPI.new()
	api.add_key("7f3a-22", ["doors"], "facilities")
	api.add_key("hr-0091", ["hr"], "HR clerk")
	api.route("GET", "/doors", func(_p): return {"status": 200, "body": {"doors": doors.values()}})
	api.route("GET", "/doors/:id", func(p):
		var d = doors.get(str(p[0]).to_upper())
		return {"status": 200, "body": d} if d else {"status": 404, "body": {"error": "No door %s." % p[0]}})
	api.route("PATCH", "/doors/:id", func(p, req):
		var d = doors.get(str(p[0]).to_upper())
		if d == null:
			return {"status": 404, "body": {"error": "No door %s." % p[0]}}
		var bad := FacilityAPI.check_fields(req.body, {}, {"locked": TYPE_BOOL, "note": TYPE_STRING})
		if bad != "":
			return {"status": 400, "body": {"error": bad}}
		d.merge(req.body, true)
		return {"status": 200, "body": d}, "doors")
	api.route("POST", "/badges", func(_p, req):
		var bad := FacilityAPI.check_fields(req.body, {"id": TYPE_STRING, "holder": TYPE_STRING})
		if bad != "":
			return {"status": 400, "body": {"error": bad}}
		if badges.has(req.body.id):
			return {"status": 409, "body": {"error": "Badge %s already exists." % req.body.id}}
		badges[req.body.id] = req.body
		return {"status": 201, "body": {"id": req.body.id, "issued_by": req.key.label}}, "hr")
	return [api, doors, badges]


func test_strict_json() -> void:
	var r := StrictJSON.parse('{"locked": false, "n": 3, "x": 2.5, "tags": ["a", null], "o": {}}')
	check(r.ok and r.value.locked == false and r.value.n is int and r.value.x == 2.5 and r.value.tags == ["a", null], "strict JSON reads objects, lists, whole and decimal numbers")
	check(StrictJSON.parse('"caf\\u00e9\\n"').value == "café\n", "strict JSON reads escapes")
	r = StrictJSON.parse("{'locked': false}")
	check(not r.ok and r.message.contains("double quotes") and r.line == 1 and r.col == 2, "single-quoted names are refused, pointing at the quote")
	r = StrictJSON.parse('{\n  "locked": false,\n}')
	check(not r.ok and r.message.contains("extra comma") and r.line == 3, "a trailing comma is refused on its line (Godot's own JSON allows it)")
	r = StrictJSON.parse('{"locked": False}')
	check(not r.ok and r.message.contains("lowercase"), "capitalised False gets its own message")
	r = StrictJSON.parse('{"locked": false "note": "x"}')
	check(not r.ok and r.message.contains("comma is missing"), "a missing comma is named")
	r = StrictJSON.parse('{locked: false}')
	check(not r.ok and r.message.contains("\"locked\""), "an unquoted name is shown quoted")
	r = StrictJSON.parse('{"locked": false} x')
	check(not r.ok and r.message.contains("left over"), "anything after the JSON is refused")
	r = StrictJSON.parse('{"locked": fals')
	check(not r.ok, "a misspelt word is refused")
	r = StrictJSON.parse('{"a": [1, 2}')
	check(not r.ok and r.message.contains("comma"), "a list closed with the wrong bracket is refused")
	for bad in ["", "   ", "{", "[1,]", "01", "1.", ".5", "NaN", "\"open"]:
		check(not StrictJSON.parse(bad).ok, "strict JSON refuses %s" % JSON.stringify(bad))


func test_requests_are_recognised() -> void:
	check(FacilityAPI.is_request("PATCH /doors/D-12\nX-Api-Key: k\n\n{\"locked\": false}"), "a request typed over several lines is still a request")
	check(FacilityAPI.is_request("post /badges {\"id\": \"B-2\"}"), "a one-line POST with a body is a request")
	check(not FacilityAPI.is_request("UPDATE doors SET locked = 0\nWHERE id = '/x'"), "SQL with a slash on a later line isn't a request")


func test_api_keys() -> void:
	var setup := _api()
	var api: FacilityAPI = setup[0]
	var doors: Dictionary = setup[1]
	var r := api.request("PATCH /doors/D-12 {\"locked\": false}")
	check(r.status == 401 and r.body.error.contains("X-Api-Key"), "no key: 401, and the error says which header to send")
	check(doors["D-12"].locked == true, "a refused request changes nothing")
	r = api.request("PATCH /doors/D-12\nX-Api-Key: 7f3a-23\n\n{\"locked\": false}")
	check(r.status == 401 and r.body.error.contains("isn't valid"), "a wrong key: 401")
	r = api.request("PATCH /doors/D-12\nX-Api-Key: hr-0091\n\n{\"locked\": false}")
	check(r.status == 403, "a real key without the right scope: 403")
	check(doors["D-12"].locked == true, "a forbidden request changes nothing")
	r = api.request("PATCH /doors/D-12\nX-Api-Key: 7f3a-22\n\n{\"locked\": false}")
	check(r.status == 200 and r.body.locked == false and doors["D-12"].locked == false, "the right key: 200 and the door unlocks")
	check(api.request("GET /doors/D-12").body.locked == false, "a GET afterwards shows the change")
	r = api.request("PATCH /doors/D-14\nx-api-key:   7f3a-22  \n{\n  \"locked\": false\n}")
	check(r.status == 200 and doors["D-14"].locked == false, "header names ignore case, values are trimmed, and the blank line is optional")
	r = api.request("PATCH /doors/D-14\nX-Api-Key: \n\n{\"locked\": true}")
	check(r.status == 401 and r.body.error.contains("needs an API key"), "an empty key counts as no key")
	r = api.send("PATCH", "/doors/D-14", {"X-Api-Key": "7f3a-22"}, "{\"locked\": true}")
	check(r.status == 200 and doors["D-14"].locked == true and JSON.parse_string(r.text).locked == true, "send() takes the same request in parts, as scripts will")
	r = api.request("PATCH /doors/D-14 {bad json")
	check(r.status == 401, "the key is checked before the body (401 before 400)")
	r = api.request("PATCH /doors/D-14\nApi key 7f3a-22\n\n{\"locked\": true}")
	check(r.status == 400 and r.body.error.contains("isn't a header"), "a line that isn't Name: value is refused as a header")


func test_json_bodies() -> void:
	var api: FacilityAPI = _api()[0]
	var head := "PATCH /doors/D-12\nX-Api-Key: 7f3a-22\n\n"
	var r := api.request(head + "{'locked': false}")
	check(r.status == 400 and r.body.error.contains("double quotes"), "single quotes: 400 that names the quotes")
	r = api.request(head + "{\n  \"locked\": false,\n}")
	check(r.status == 400 and r.body.error.contains("line 3") and r.body.error.contains("extra comma"), "a trailing comma: 400 that names the line")
	r = api.request("PATCH /doors/D-12\nX-Api-Key: 7f3a-22")
	check(r.status == 400 and r.body.error.contains("needs a JSON body"), "no body at all: 400")
	r = api.request(head + "locked = false")
	check(r.status == 400 and r.body.error.contains("isn't valid JSON"), "SQL-style text in a body: 400")
	check(api.request("GET /doors/D-12 please").status == 200, "a GET ignores anything after the path, as before")


func test_body_fields() -> void:
	var api: FacilityAPI = _api()[0]
	var head := "PATCH /doors/D-12\nX-Api-Key: 7f3a-22\n\n"
	var r := api.request(head + "{\"lockd\": false}")
	check(r.status == 400 and r.body.error.contains("\"lockd\"") and r.body.error.contains("locked"), "a misspelt field: 400 that lists the right ones")
	r = api.request(head + "{\"locked\": \"false\"}")
	check(r.status == 400 and r.body.error.contains("true or false"), "\"false\" in quotes is text, not false: 400")
	r = api.request(head + "[{\"locked\": false}]")
	check(r.status == 400 and r.body.error.contains("JSON object"), "a list where an object belongs: 400")
	r = api.request(head + "{\"locked\": false, \"note\": \"crew\"}")
	check(r.status == 200 and r.body.note == "crew", "optional fields are taken")
	check(FacilityAPI.check_fields({"n": 2}, {"n": TYPE_FLOAT}) == "" and FacilityAPI.check_fields({"n": 2.5}, {"n": TYPE_INT}) != "", "whole numbers fit number fields; decimals don't fit whole-number fields")
	check(FacilityAPI.check_fields({}, {"id": TYPE_STRING}).contains("missing \"id\""), "a missing field is named")


func test_created_and_conflict() -> void:
	var setup := _api()
	var api: FacilityAPI = setup[0]
	var badges: Dictionary = setup[2]
	var post := "POST /badges\nX-Api-Key: hr-0091\n\n{\"id\": \"B-2\", \"holder\": \"Crew\"}"
	var r := api.request(post)
	check(r.status == 201 and FacilityAPI.status_text(r.status) == "Created" and badges.has("B-2"), "POST creates: 201 Created")
	check(r.body.issued_by == "HR clerk", "handlers can see whose key was used")
	r = api.request(post)
	check(r.status == 409 and FacilityAPI.status_text(409) == "Conflict" and r.body.error.contains("already exists"), "the same POST again: 409 Conflict")
	r = api.request("POST /badges\nX-Api-Key: 7f3a-22\n\n{\"id\": \"B-3\", \"holder\": \"Crew\"}")
	check(r.status == 403 and not badges.has("B-3"), "a door key can't issue badges: 403")
	r = api.request("POST /badges\nX-Api-Key: hr-0091\n\n{\"id\": \"B-3\"}")
	check(r.status == 400 and not badges.has("B-3"), "a POST missing a field: 400, nothing created")
	check(FacilityAPI.status_text(401) == "Unauthorized" and FacilityAPI.status_text(400) == "Bad Request", "every new status has its reason phrase")


func test_wrong_method() -> void:
	var api: FacilityAPI = _api()[0]
	var r := api.request("DELETE /doors/D-12")
	check(r.status == 405 and r.body.error.contains("GET") and r.body.error.contains("PATCH"), "with write routes, 405 lists the methods the path takes")
	r = api.request("PUT /doors/D-12 {\"locked\": false}")
	check(r.status == 405, "PUT isn't PATCH")
	check(api.request("PATCH /lifts/1 {\"floor\": 3}").status == 404, "an unknown path is still 404, before any key check")


func test_old_routes_unchanged() -> void:
	var api := FacilityAPI.new()
	api.route("GET", "/cameras", func(_p): return {"status": 200, "body": {"cameras": []}})
	var r := api.request("PATCH /cameras {\"x\": 1}")
	check(r.status == 405 and r.body.error.contains("read-only"), "a read-only API keeps Level 2's read-only message")
	check(api.request("get /Cameras/;").status == 200, "one-argument handlers still work")
