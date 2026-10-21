class_name NetScript
extends ScriptRuntime
## A terminal's script in co-op, as every machine's script runner sees it. The
## host runs the real runtime (ScriptHost ticks it); this stands in for it on
## every machine, the host's included. Run and Stop work from anyone's runner
## and go to the host, and every runner shows the same run: when it started,
## each line it printed and how it ended.

var terminal: Node
var host: ScriptHost
var language_name := "javascript"
## What this run has printed so far, [text, kind] each, for a runner opened
## after it started.
var history: Array = []
var _clock := 0.0


func language() -> String:
	return language_name


# How the runner shows the language, from the language's own runtime.

func display_name() -> String:
	return _language().call("display_name") if _language().has_method("display_name") else language_name.capitalize()


func editor_words() -> Dictionary:
	return _language().call("editor_words") if _language().has_method("editor_words") else {}


func placeholder() -> String:
	return _language().call("placeholder") if _language().has_method("placeholder") else ""


var _lang: ScriptRuntime


func _language() -> ScriptRuntime:
	if _lang == null:
		_lang = ScriptRuntime.for_language(language_name)
	return _lang


## Each machine checks the script itself, so its runner can mark a mistake
## without asking the host. The host checks it again before running it.
func compile(code: String) -> Dictionary:
	var res: Dictionary = ScriptRuntime.for_language(language_name).compile(code)  # a fresh one: compiling sets its state
	if res.ok:
		source = code
		if not is_running():
			state = State.READY
	return res


## Asks the host to run the last script compiled here. The library and seed
## passed in are ignored: the host builds its own from the terminal and the run.
func start(_library: BuildingLibrary, _seed_value := 0) -> void:
	host.run(terminal, source)


## The host ticks the real runtime; nothing to do here.
func tick(_delta: float, _usec := FRAME_USEC) -> void:
	pass


func stop() -> void:
	host.stop(terminal)


## Seconds the run took (once it has ended), as the host's runtime counted them.
func clock() -> float:
	return _clock


func log_history() -> Array:
	return history


# --- From the host, on every machine (ScriptHost) -----------------------------

func _on_started(code: String) -> void:
	source = code
	error = {}
	history.clear()
	state = State.RUNNING
	started.emit()


func _on_printed(text: String, kind: String) -> void:
	history.append([text, kind])
	printed.emit(text, kind)


func _on_finished(ok: bool, err: Dictionary, seconds: float) -> void:
	_clock = seconds
	error = err
	state = State.DONE if ok else (State.STOPPED if err.is_empty() else State.FAILED)
	finished.emit(ok, err)
