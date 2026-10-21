extends ScriptRuntime
## A toy language pack for the boundary tests: it proves the runner and the
## building library work with a language that isn't JavaScript. One command a line:
##   say <text>     prints the text
##   wait <ms>      waits, in game time
##   get <path>     asks the building and prints the status and body

const WORDS := ["say", "wait", "get"]

var _lines: PackedStringArray
var _at := 0
var _wake := 0.0
var _now := 0.0
var _library: BuildingLibrary


func language() -> String:
	return "lines"


func editor_words() -> Dictionary:
	return {"keywords": WORDS, "line_comment": "#"}


func placeholder() -> String:
	return "say hello"


func compile(code: String) -> Dictionary:
	source = code
	error = {}
	_lines = code.split("\n")
	for i in _lines.size():
		var word := _lines[i].strip_edges().get_slice(" ", 0)
		if word != "" and not word.begins_with("#") and not word in WORDS:
			error = {"line": i + 1, "col": 1, "message": "No command %s. Try say, wait or get." % word}
			state = State.FAILED
			return {"ok": false, "error": error}
	state = State.READY
	return {"ok": true, "error": {}}


func start(library: BuildingLibrary, _seed_value := 0) -> void:
	_library = library
	_at = 0
	_now = 0.0
	_wake = 0.0
	state = State.RUNNING
	started.emit()


func tick(delta: float, _usec := FRAME_USEC) -> void:
	if not is_running():
		return
	_now += delta
	if _now < _wake:
		return
	state = State.RUNNING
	while _at < _lines.size():
		var line := _lines[_at].strip_edges()
		_at += 1
		var word := line.get_slice(" ", 0)
		var rest := line.substr(word.length()).strip_edges()
		if word == "say":
			printed.emit(rest, "log")
		elif word == "get":
			var res := _library.request("GET", rest)
			printed.emit("%d %s" % [res.status, JSON.stringify(res.body)], "log")
		elif word == "wait":
			_wake = _now + rest.to_float() / 1000.0
			state = State.WAITING
			return
	state = State.DONE
	finished.emit(true, {})


func stop() -> void:
	if not is_running():
		return
	state = State.STOPPED
	finished.emit(false, {})


func clock() -> float:
	return _now
