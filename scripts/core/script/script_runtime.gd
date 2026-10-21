class_name ScriptRuntime
extends RefCounted
## One player script running on the building, in some language. The deck's
## script editor and the co-op host only ever talk to this; each language pack
## (js/ now, Python later) implements it. The building itself is reached only
## through the BuildingLibrary handed to start().
##
## var rt := ScriptRuntime.for_language("javascript")
## var c := rt.compile(source)       # {ok, error: {line, col, message}}
## rt.start(library, Game.run_seed)
## rt.tick(delta)                    # every frame, by whoever owns the script
## rt.stop()                         # anyone may press Stop

## A line the script wrote: kind is "log", "warn" or "error".
signal printed(text: String, kind: String)
## The script ended by itself (ok), failed (error is set), or was stopped (neither).
signal finished(ok: bool, error: Dictionary)

enum State { IDLE, READY, RUNNING, WAITING, DONE, FAILED, STOPPED }

## How long a script may run each frame, in microseconds.
const FRAME_USEC := 2_000

var state := State.IDLE
var error := {}  # {line, col, message}; col is 0 when only the line is known
var source := ""


static func for_language(language: String) -> ScriptRuntime:
	match language:
		"javascript":
			return JSRuntime.new()
	return null


func language() -> String:
	return ""


## Checks the script without running it. On success the runtime is READY.
func compile(_source: String) -> Dictionary:
	push_error("ScriptRuntime.compile is implemented by each language")
	return {"ok": false, "error": {"line": 0, "col": 0, "message": "No language."}}


func start(_library: BuildingLibrary, _seed_value := 0) -> void:
	push_error("ScriptRuntime.start is implemented by each language")


## Advances game time by `delta` seconds and runs for at most `usec`.
func tick(_delta: float, _usec := FRAME_USEC) -> void:
	pass


func stop() -> void:
	pass


func is_running() -> bool:
	return state == State.RUNNING or state == State.WAITING


## An error as the deck shows it: the message, the line of code, and a ^ under
## the column when it's known.
##   Line 2: Close the condition with )
##     2 | if (door.locked {
##       |                 ^
static func format_error(code: String, e: Dictionary) -> String:
	var line: int = e.get("line", 0)
	if line < 1:
		return e.get("message", "")
	var lines := code.split("\n")
	var text := lines[line - 1] if line <= lines.size() else ""
	var out := "Line %d: %s\n  %d | %s" % [line, e.message, line, text]
	if e.get("col", 0) > 0:
		out += "\n  %s | %s^" % [" ".repeat(str(line).length()), " ".repeat(e.col - 1)]
	return out
