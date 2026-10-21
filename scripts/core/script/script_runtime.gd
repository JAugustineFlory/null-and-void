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
##
## A language pack is a script that extends ScriptRuntime and overrides the
## methods below marked "each language". JavaScript is built in; a pack added
## later (the Python DLC) registers itself before it's used:
##
## ScriptRuntime.register("python", preload("res://scripts/core/script/py/py_runtime.gd"))

## The script began running (Run was pressed, on whichever machine runs it).
signal started
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


## Language name -> the pack's script. JavaScript is the base language.
static var _packs := {}


static func register(language_name: String, pack: Script) -> void:
	_packs[language_name] = pack


## A new runtime for `language_name`, or null when no pack speaks it.
static func for_language(language_name: String) -> ScriptRuntime:
	if language_name == "javascript" and not _packs.has(language_name):
		return JSRuntime.new()
	return _packs[language_name].new() if _packs.has(language_name) else null


static func languages() -> Array:
	var all := _packs.keys()
	if not "javascript" in all:
		all.push_front("javascript")
	return all


## Each language: its name in code ("javascript"), and as players read it ("JavaScript").
func language() -> String:
	return ""


func display_name() -> String:
	return language().capitalize()


## Each language: how the editor colors it.
## {keywords: [...], built_ins: [...], strings: ["\"", ...] (one line),
##  multiline_strings: ["`"], line_comment: "//", block_comment: ["/*", "*/"]}
## Missing keys mean none.
func editor_words() -> Dictionary:
	return {}


## Each language: the greyed text in an empty editor, a first line to try.
func placeholder() -> String:
	return ""


## Seconds of game time the script has run.
func clock() -> float:
	return 0.0


## Each language: checks the script without running it. On success the runtime
## is READY; on a mistake it is FAILED and `error` says where.
func compile(_source: String) -> Dictionary:
	push_error("ScriptRuntime.compile is implemented by each language")
	return {"ok": false, "error": {"line": 0, "col": 0, "message": "No language."}}


## Each language: runs the compiled script against the building, emitting
## started. Math.random (or its like) follows `seed_value`.
func start(_library: BuildingLibrary, _seed_value := 0) -> void:
	push_error("ScriptRuntime.start is implemented by each language")


## Each language: advances game time by `delta` seconds and runs for at most
## `usec`. Waits end by game time, so the host decides them in co-op.
func tick(_delta: float, _usec := FRAME_USEC) -> void:
	pass


## Each language: ends a running script and emits finished(false, {}).
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
