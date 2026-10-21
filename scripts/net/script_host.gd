class_name ScriptHost
extends Node
## Deck scripts in co-op (S4): every script runs on the host, and every machine
## sees what runs. Each terminal gets a NetScript in its "script_runtime" meta,
## so the runner (.script) talks to that instead of running scripts itself.
##
## - Run and Stop from anyone's runner go to the host, which runs or stops the
##   terminal's script.
## - Started, every printed line and finished go to every machine in order, so
##   every runner shows the same log, and the running code becomes that
##   terminal's saved script everywhere.
## - The host ticks the script with its own frame time, so waits end at the
##   same moment for everyone.
## - A request that changes the building (anything but GET) is sent on to every
##   other machine's copy, as typed requests are (LevelSync.submit_request).
##
## Solo play keeps the plain runtime: nothing is installed while offline.

var sync: LevelSync
## Host only: terminal path -> the runtime running there.
var _running := {}


static func create(for_sync: LevelSync) -> ScriptHost:
	var h := ScriptHost.new()
	h.name = "ScriptHost"
	h.sync = for_sync
	for_sync.add_child(h)
	return h


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_adopt_all.call_deferred()


func _level() -> Node:
	return sync.level


func _adopt_all() -> void:
	for n in _level().find_children("*", "", true, false):
		if n is Terminal:
			adopt(n)


func _on_node_added(n: Node) -> void:
	if n is Terminal and _level().is_ancestor_of(n):
		adopt.call_deferred(n)


## Gives `terminal` a shared script (online only). Safe to call more than once.
func adopt(terminal: Node) -> NetScript:
	# A terminal belongs to its nearest level (a wing inside the World has its own).
	if not is_instance_valid(terminal) or not sync.is_online() or LevelSync.of(terminal) != sync:
		return null
	var have = terminal.get_meta("script_runtime") if terminal.has_meta("script_runtime") else null
	if have is NetScript:
		return have
	var rt := NetScript.new()
	rt.terminal = terminal
	rt.host = self
	terminal.set_meta("script_runtime", rt)
	return rt


func _runtime(path: NodePath) -> NetScript:
	var terminal := _level().get_node_or_null(path)
	return adopt(terminal) if terminal else null


func is_running(terminal: Node) -> bool:
	return _running.has(_level().get_path_to(terminal))


# --- Run and Stop ------------------------------------------------------------

## Runs `code` at `terminal` on the host, unless a script already runs there.
func run(terminal: Node, code: String) -> void:
	var path := _level().get_path_to(terminal)
	if sync.is_host():
		_host_run(path, code)
	else:
		_request_run.rpc_id(1, path, code)


func stop(terminal: Node) -> void:
	var path := _level().get_path_to(terminal)
	if sync.is_host():
		_host_stop(path)
	else:
		_request_stop.rpc_id(1, path)


@rpc("any_peer", "reliable")
func _request_run(path: NodePath, code: String) -> void:
	if sync.is_host():
		_host_run(path, code)


@rpc("any_peer", "reliable")
func _request_stop(path: NodePath) -> void:
	if sync.is_host():
		_host_stop(path)


func _host_run(path: NodePath, code: String) -> void:
	var terminal := _level().get_node_or_null(path)
	if terminal == null or _running.has(path):
		return
	var rt := ScriptRuntime.for_language("javascript")
	var checked := rt.compile(code)
	if not checked.ok:
		_finished.rpc(path, false, checked.error, 0.0)
		return
	var library := BuildingLibrary.new(terminal.api, terminal.db)
	library.requested.connect(func(method: String, req_path: String, headers: Dictionary, body: String, _reply: Dictionary):
		if method != "GET":
			_replay.rpc(path, method, req_path, headers, body))
	rt.printed.connect(func(text: String, kind: String): _printed.rpc(path, text, kind))
	rt.finished.connect(func(ok: bool, err: Dictionary):
		_running.erase(path)
		_finished.rpc(path, ok, err, rt.clock() if rt.has_method("clock") else 0.0))
	_running[path] = rt
	_started.rpc(path, code)
	var game := get_node_or_null("/root/Game")
	rt.start(library, game.run_seed if game else 0)


func _host_stop(path: NodePath) -> void:
	var rt: ScriptRuntime = _running.get(path)
	if rt:
		rt.stop()


func _process(delta: float) -> void:
	for path in _running.keys():
		var rt: ScriptRuntime = _running.get(path)
		if rt:
			rt.tick(delta)


# --- On every machine ----------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _started(path: NodePath, code: String) -> void:
	var rt := _runtime(path)
	if rt:
		rt.terminal.set_meta("script_code", code)
		rt._on_started(code)


@rpc("authority", "call_local", "reliable")
func _printed(path: NodePath, text: String, kind: String) -> void:
	var rt := _runtime(path)
	if rt:
		rt._on_printed(text, kind)


@rpc("authority", "call_local", "reliable")
func _finished(path: NodePath, ok: bool, err: Dictionary, seconds: float) -> void:
	var rt := _runtime(path)
	if rt:
		rt._on_finished(ok, err, seconds)


## A script's change to the building, made on this machine's copy too.
@rpc("authority", "reliable")
func _replay(path: NodePath, method: String, req_path: String, headers: Dictionary, body: String) -> void:
	var terminal := _level().get_node_or_null(path)
	if terminal and terminal.api:
		terminal.api.send(method, req_path, headers, body)
