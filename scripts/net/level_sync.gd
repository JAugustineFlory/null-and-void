class_name LevelSync
extends Node
## Keeps one level the same on every machine in a co-op game.
##
## The host decides; everyone plays it out. Story beats, puzzle results and
## button presses are decided on the host and then run on every machine as
## "events" (plain level methods), in the same order. Queries typed at a
## terminal run on the host's database first, then on every copy, so the
## building's tables, doors and lights stay identical everywhere.
## Solo uses the same path: the offline peer is its own host.

signal began
signal gate_opened(key: String)

## Methods a client may ask the host to call on a world node on its behalf.
const FORWARDABLE := ["interact", "interact_alt", "take_hit"]
const READY_TIMEOUT := 20.0

var level: Node
var _ready_peers := {}
var _begun := false
var _start_fn: Callable
var _synchronizers: Array[MultiplayerSynchronizer] = []
var _gates := {}


static func create(for_level: Node) -> LevelSync:
	var s := LevelSync.new()
	s.name = "LevelSync"
	s.level = for_level
	for_level.add_child(s)
	return s


## The LevelSync of the level `node` belongs to.
static func of(node: Node) -> LevelSync:
	var n := node
	while n:
		var s := n.get_node_or_null("LevelSync")
		if s is LevelSync:
			return s
		n = n.get_parent()
	return null


## Give every node built in code a name that is the same on every machine,
## so RPCs and synchronizers can find it. Godot's automatic names ("@Node@12")
## are not guaranteed to match between machines.
static func name_nodes(root: Node) -> void:
	var i := 0
	for n in root.find_children("*", "", true, false):
		if str(n.name).begins_with("@"):
			n.name = "n%d_%s" % [i, n.get_class()]
		i += 1


func is_host() -> bool:
	return multiplayer.is_server()


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and multiplayer.multiplayer_peer != null


# --- Starting together -------------------------------------------------------

## Run `start_fn` on every machine once they have all loaded the level.
func begin_when_ready(start_fn: Callable) -> void:
	_start_fn = start_fn
	if not is_online():
		_begin()
		return
	if is_host():
		_ready_peers[1] = true
		_check_all_ready()
		get_tree().create_timer(READY_TIMEOUT).timeout.connect(func():
			if not _begun:
				_begin_all.rpc())
	else:
		# The host may still be loading, so keep saying so until it starts us.
		# (If it is, the host logs "Node not found" for the early tries. Harmless.)
		while not _begun and is_inside_tree() and is_online():
			_client_ready.rpc_id(1)
			await get_tree().create_timer(0.5).timeout


@rpc("any_peer", "reliable")
func _client_ready() -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	_ready_peers[id] = true
	for s in _synchronizers:
		s.set_visibility_for(id, true)
	if _begun:
		_begin_all.rpc_id(id)  # it missed the start; let it catch up
	_check_all_ready()


func _check_all_ready() -> void:
	if _begun:
		return
	for id in multiplayer.get_peers():
		if not _ready_peers.has(id):
			return
	_begin_all.rpc()


@rpc("authority", "call_local", "reliable")
func _begin_all() -> void:
	_begin()


func _begin() -> void:
	if _begun:
		return
	_begun = true
	began.emit()
	if _start_fn.is_valid():
		_start_fn.call()


# --- Events ------------------------------------------------------------------

## Host: run `level.method(args)` on every machine. Clients can't start events.
func event(method: StringName, args: Array = []) -> void:
	if not is_host():
		return
	_event.rpc(method, args)


@rpc("authority", "call_local", "reliable")
func _event(method: StringName, args: Array) -> void:
	level.callv(method, args)


## Wait, on every machine, until something happens on the host. Story code that
## awaits a trigger, an NPC arriving or a button press uses this, because those
## only fire on the host. `waiter` is a Signal, or a Callable to await.
##     await sync.gate("at_door", rourke.arrived)
func gate(key: String, waiter) -> void:
	if is_host() and not _gates.has(key):
		_host_gate(key, waiter)
	while not _gates.has(key):
		await gate_opened


func _host_gate(key: String, waiter) -> void:
	if waiter is Signal:
		await waiter
	elif waiter is Callable:
		await waiter.call()
	if not _gates.has(key):
		_open_gate.rpc(key)


@rpc("authority", "call_local", "reliable")
func _open_gate(key: String) -> void:
	_gates[key] = true
	gate_opened.emit(key)


## Show a notice on every machine's HUD (host only).
func team_notice(text: String, seconds: float = 3.0) -> void:
	if is_host():
		_team_notice.rpc(text, seconds)


@rpc("authority", "call_local", "reliable")
func _team_notice(text: String, seconds: float) -> void:
	if level.hud:
		level.hud.notice(text, seconds)


# --- Acting on shared things -------------------------------------------------

## Clients: send an interaction or hit to the host instead of acting locally.
## Returns true if it was forwarded, in which case the caller should stop.
func forward(node: Node, method: String) -> bool:
	if is_host():
		return false
	_remote_call.rpc_id(1, level.get_path_to(node), method)
	return true


@rpc("any_peer", "reliable")
func _remote_call(path: NodePath, method: String) -> void:
	if not is_host() or not FORWARDABLE.has(method):
		return
	var node := level.get_node_or_null(path)
	var who: Node = _players().puppet(multiplayer.get_remote_sender_id())
	if node and who and node.has_method(method):
		node.call(method, who)


## Host: mirror `node`'s properties to every client. Clients stop simulating it.
func replicate(node: Node, properties: Array) -> void:
	var cfg := SceneReplicationConfig.new()
	for p in properties:
		var path := NodePath(p)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
		cfg.property_set_spawn(path, false)
	var s := MultiplayerSynchronizer.new()
	s.name = "Sync_" + str(node.name)
	add_child(s)
	s.root_path = s.get_path_to(node)
	s.replication_config = cfg
	# A wing loads after everyone is in the game, so it can talk to all of them;
	# a standalone level waits for each machine to say it's ready.
	s.public_visibility = level.get("world") != null
	_synchronizers.append(s)
	node.tree_exiting.connect(_drop_synchronizer.bind(s))
	if not is_host():
		node.set_physics_process(false)


## The node is going away: stop sending it to everyone before freeing the
## synchronizer, or the host keeps trying to send a sync that no longer exists.
func _drop_synchronizer(s: MultiplayerSynchronizer) -> void:
	_synchronizers.erase(s)
	var peer := multiplayer.multiplayer_peer
	if peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		s.public_visibility = false
		for id in multiplayer.get_peers():
			s.set_visibility_for(id, false)
	s.queue_free()


# --- Terminals ---------------------------------------------------------------

## Run a query typed at `terminal`. The host runs it, then every machine shows it.
func submit_query(terminal: Node, sql: String) -> void:
	var path := level.get_path_to(terminal)
	if is_host():
		_host_query(path, sql, multiplayer.get_unique_id())
	else:
		_request_query.rpc_id(1, path, sql)


@rpc("any_peer", "reliable")
func _request_query(path: NodePath, sql: String) -> void:
	if is_host():
		_host_query(path, sql, multiplayer.get_remote_sender_id())


func _host_query(path: NodePath, sql: String, from_peer: int) -> void:
	var terminal := level.get_node_or_null(path)
	if terminal == null:
		return
	if terminal.is_locked():
		if from_peer == multiplayer.get_unique_id():
			_query_refused(path)
		else:
			_query_refused.rpc_id(from_peer, path)
		return
	var result: Dictionary = terminal.db.execute(sql)
	_show_query.rpc(path, sql, result, from_peer)
	if result.ok:
		terminal.on_query(sql, result, level.terminal_ui)


@rpc("authority", "reliable")
func _query_refused(path: NodePath) -> void:
	var terminal := level.get_node_or_null(path)
	if terminal:
		terminal.print_line("[color=#ff6655]%s[/color]" % terminal.locked_message)


@rpc("authority", "call_local", "reliable")
func _show_query(path: NodePath, sql: String, result: Dictionary, from_peer: int) -> void:
	var terminal := level.get_node_or_null(path)
	if terminal == null:
		return
	if not is_host() and result.ok:
		terminal.db.execute(sql)  # keep this machine's copy of the building in step
	level.terminal_ui.show_query(terminal, sql, result, from_peer)


## Send a web request typed at `terminal` (e.g. GET /cameras). The host runs
## it, then every machine runs it on its own copy and shows the response.
func submit_request(terminal: Node, line: String) -> void:
	var path := level.get_path_to(terminal)
	if is_host():
		_host_request(path, line, multiplayer.get_unique_id())
	else:
		_request_request.rpc_id(1, path, line)


@rpc("any_peer", "reliable")
func _request_request(path: NodePath, line: String) -> void:
	if is_host():
		_host_request(path, line, multiplayer.get_remote_sender_id())


func _host_request(path: NodePath, line: String, from_peer: int) -> void:
	var terminal := level.get_node_or_null(path)
	if terminal == null:
		return
	if terminal.is_locked():
		if from_peer == multiplayer.get_unique_id():
			_query_refused(path)
		else:
			_query_refused.rpc_id(from_peer, path)
		return
	var res: Dictionary = terminal.api.request(line) if terminal.api else {}
	_show_request.rpc(path, line, res, from_peer)
	if not res.is_empty():
		terminal.on_request(line, res, level.terminal_ui)


@rpc("authority", "call_local", "reliable")
func _show_request(path: NodePath, line: String, res: Dictionary, from_peer: int) -> void:
	var terminal := level.get_node_or_null(path)
	if terminal == null:
		return
	if not is_host() and terminal.api:
		terminal.api.request(line)  # keep this machine's copy of the building in step
	level.terminal_ui.show_request(terminal, line, res, from_peer)


## Restore a terminal's data from backup, on every machine.
func reset_db(terminal: Node) -> void:
	if is_host():
		_reset_db.rpc(level.get_path_to(terminal))
	else:
		_request_reset.rpc_id(1, level.get_path_to(terminal))


@rpc("any_peer", "reliable")
func _request_reset(path: NodePath) -> void:
	if is_host():
		_reset_db.rpc(path)


@rpc("authority", "call_local", "reliable")
func _reset_db(path: NodePath) -> void:
	var terminal := level.get_node_or_null(path)
	if terminal:
		terminal.db.reset()
		terminal.print_line("Backup tape restored. Data is back to how it started.")


func _players() -> NetPlayers:
	return level.players
