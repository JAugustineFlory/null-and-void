class_name JSRuntime
extends ScriptRuntime
## The JavaScript language pack: JSParser -> JSCompiler -> JSVM, plus the
## building library bound under JavaScript names:
##
##   const res = await api.patch("/doors/D-12", { locked: false }, { "X-Api-Key": key });
##   if (res.status !== 200) console.log(res.body.error);
##   const rows = await db.query("SELECT id FROM doors WHERE zone = ?", ["C"]);
##   await sleep(1000);
##   assert(rows.length > 0, "no doors in zone C");
##
## api calls return { status, body } (a 4xx is a normal answer, as with fetch).

var _main: JSVM.Proto
var _vm: JSVM
var _library: BuildingLibrary


const KEYWORDS := ["let", "const", "function", "return", "if", "else", "while", "for", "of", "break",
	"continue", "async", "await", "true", "false", "null", "undefined", "typeof"]
const BUILT_INS := ["api", "db", "sleep", "assert", "console", "Math", "JSON", "Object", "Array"]


func language() -> String:
	return "javascript"


func display_name() -> String:
	return "JavaScript"


func editor_words() -> Dictionary:
	return {"keywords": KEYWORDS, "built_ins": BUILT_INS, "strings": ["\"", "'"], "multiline_strings": ["`"],
		"line_comment": "//", "block_comment": ["/*", "*/"]}


func placeholder() -> String:
	return "// Write JavaScript here. Ctrl+S saves it, Ctrl+R runs it.\nconsole.log(\"hello\");"


func compile(code: String) -> Dictionary:
	source = code
	error = {}
	var p := JSParser.new(code)
	var tree := p.parse()
	if p.error:
		return _compile_failed(p.error)
	var c := JSCompiler.new()
	_main = c.compile(tree)
	if c.error:
		return _compile_failed(c.error)
	state = State.READY
	return {"ok": true, "error": {}}


func _compile_failed(e: Dictionary) -> Dictionary:
	error = e
	state = State.FAILED
	return {"ok": false, "error": e}


func start(library: BuildingLibrary, seed_value := 0) -> void:
	if state != State.READY:
		push_error("JSRuntime.start needs a script that compiled")
		return
	_library = library
	_vm = JSVM.new()
	_vm.globals["api"] = _api_object()
	_vm.globals["db"] = JSStdlib._host_obj({"query": func(vm: JSVM, a: Array): return _db_query(vm, a)})
	_vm.printed.connect(func(text: String, kind: String): printed.emit(text, kind))
	_vm.start(_main, seed_value)
	state = State.RUNNING
	started.emit()


func tick(delta: float, usec := FRAME_USEC) -> void:
	if not is_running():
		return
	_vm.tick(delta, usec)
	if _vm.error:
		error = _vm.error.duplicate()
		error["col"] = 0
		_end(State.FAILED)
		finished.emit(false, error)
	elif not _vm.busy():
		_end(State.DONE)
		finished.emit(true, {})
	else:
		state = State.RUNNING if _vm.has_work() else State.WAITING


func stop() -> void:
	if not is_running():
		return
	_end(State.STOPPED)
	finished.emit(false, {})


## Seconds of game time the script has run, and the steps it has taken.
func clock() -> float:
	return _vm.now if _vm else 0.0


func steps() -> int:
	return _vm.steps_total if _vm else 0


func _end(new_state: State) -> void:
	state = new_state
	_vm.stop()


# --- the building, under JavaScript names --------------------------------------------

func _api_object() -> JSVM.Obj:
	var fns := {}
	for m in ["get", "delete"]:
		fns[m] = func(vm: JSVM, a: Array): return _api_call(vm, m, a, false)
	for m in ["post", "put", "patch"]:
		fns[m] = func(vm: JSVM, a: Array): return _api_call(vm, m, a, true)
	return JSStdlib._host_obj(fns)


## api.get(path, headers) / api.post(path, body, headers) -> Promise of { status, body }.
func _api_call(vm: JSVM, method: String, a: Array, has_body: bool) -> Variant:
	var path = JSStdlib._a(a, 0)
	if not path is String:
		return vm.fail("api.%s needs a path in quotes first, like api.%s(\"/doors\"%s)" % [method, method, ", {...}" if has_body else ""])
	var body := ""
	var raw_headers = JSStdlib._a(a, 2 if has_body else 1)
	if has_body:
		var b = JSStdlib._a(a, 1)
		if b is String:
			body = b
		elif b != null:
			var json = JSStdlib._stringify(vm, b, "", "", 0)
			if vm.error:
				return null
			body = "" if json == null else json
	var headers := {}
	if raw_headers is JSVM.Obj:
		for k in raw_headers.props:
			headers[k] = JSVM.to_str(raw_headers.props[k])
	elif raw_headers != null:
		return vm.fail("Headers go in an object: { \"X-Api-Key\": key }")
	var reply := _library.request(method, path, headers, body)
	return vm.resolved(vm.make_obj({"status": float(reply.status), "body": JSStdlib.to_js(vm, reply.body)}))


## db.query(sql, params) -> Promise of a list of row objects.
func _db_query(vm: JSVM, a: Array) -> Variant:
	var sql = JSStdlib._a(a, 0)
	if not sql is String:
		return vm.fail("db.query needs SQL in quotes, like db.query(\"SELECT * FROM doors\")")
	var params := []
	var p = JSStdlib._a(a, 1)
	if p is JSVM.Arr:
		for x in p.items:
			params.append(JSStdlib.from_js(x))
	elif p != null:
		return vm.fail("db.query's values go in a list: db.query(\"... WHERE id = ?\", [id])")
	var r := _library.query(sql, params)
	if not r.ok:
		return vm.fail(r.error if r.error == BuildingLibrary.WRITE_REFUSED else "db.query: %s" % r.error)
	return vm.resolved(JSStdlib.to_js(vm, r.rows))
