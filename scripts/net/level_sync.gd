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
const FORWARDABLE := ["interact", "interact_alt", "take_hit", "report_open"]
const READY_TIMEOUT := 20.0
## Host: the NPCs it simulates for everyone. Teammates' bodies here (PlayerPuppet)
## don't push them: a puppet is only placed where its player's machine says, so a
## client walking into an NPC would shove it on the host (and so for everyone).
const SHOVE_PROOF := "shove_proof_npc"

var level: Node
var _ready_peers := {}
var _begun := false
var _start_fn: Callable
var _synchronizers: Array[MultiplayerSynchronizer] = []
var _gates := {}
## Host, on the World's (or a stand-alone level's) LevelSync: everything shared
## that happened on this floor since the crew walked onto it, in order, so a
## player who joins mid-run can catch up (replay_to). Each entry is
## [path from this level to the LevelSync it ran on, kind, args].
var history: Array = []
## (On the top LevelSync) this machine is catching up on what happened before it
## joined: story beats run quietly (no lines, no notices), to arrive where
## everyone else is.
var catching_up := false
var _caught_up := {}
## Shares what's on each terminal's screen: seats, typed lines, commands.
var mirror: TerminalMirror
var huddle: NotesHuddle
## Deck scripts: run on the host, seen by everyone.
var scripts: ScriptHost


static func create(for_level: Node) -> LevelSync:
	var s := LevelSync.new()
	s.name = "LevelSync"
	s.level = for_level
	for_level.add_child(s)
	s.mirror = TerminalMirror.create(s)
	s.huddle = NotesHuddle.create(s)
	s.scripts = ScriptHost.create(s)
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
		if top() == self and not _caught_up.has(id):
			_caught_up[id] = true
			replay_to(id)  # and on what's happened since (a late joiner)
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
	var net := get_node_or_null("/root/Net")
	if net and net.multiplayer == multiplayer and is_online():
		net.world_began()  # everyone has loaded: the long wait for a frozen machine can end
	if _start_fn.is_valid():
		_start_fn.call()


# --- Catching up a late joiner ----------------------------------------------

## The LevelSync that keeps the floor's history: the World's, or a stand-alone level's own.
func top() -> LevelSync:
	var w = level.get("world")
	return w.sync if w and w != level and w.get("sync") else self


## Host: note something shared that just ran here, for anyone joining later.
func _record(kind: String, args: Array) -> void:
	if not is_host():
		return
	var t := top()
	t.history.append([t.level.get_path_to(self), kind, args])


## The crew walked onto a new floor (World.enter_wing): what happened before it
## no longer matters to someone joining, who starts on this floor.
func clear_history() -> void:
	top().history.clear()


## Host: send player `id` everything shared that happened on this floor so far.
## Their machine replays it, quietly and in order, to be where everyone is.
func replay_to(id: int) -> void:
	if is_host():
		_replay.rpc_id(id, top().history)


## Something shared outside LevelSync's own calls (a call_local RPC on another
## node, e.g. a chapter coming into the book) just ran: note it for late joiners,
## who replay it as `node.method(args)`. Call it from inside that RPC; only the
## host's call is kept.
func note(node: Node, method: StringName, args: Array) -> void:
	if is_host():
		var t := top()
		t.history.append([t.level.get_path_to(node), "call", [method, args]])


## How long story code keeps running quietly after a catch-up, so beats that
## were waiting on what was replayed play through instead of all being heard.
const CATCH_UP_SETTLE := 2.0


@rpc("authority", "reliable")
func _replay(entries: Array) -> void:
	catching_up = true
	var hud = level.get("hud")
	if hud:
		hud.catching_up = true
	for e in entries:
		if e[1] == "call":
			var target := level.get_node_or_null(e[0])
			if target:
				target.callv(e[2][0], e[2][1])
			continue
		var s := level.get_node_or_null(e[0]) as LevelSync
		if s == null:
			continue  # on a floor this machine never built
		match e[1]:
			"event": s._event.callv(e[2])
			"run_on": s._run_on.callv(e[2])
			"gate": s._open_gate.callv(e[2])
			"query": s._show_query.callv(e[2])
			"request": s._show_request.callv(e[2])
			"reset_db": s._reset_db.callv(e[2])
	await get_tree().create_timer(CATCH_UP_SETTLE).timeout
	catching_up = false
	if hud and is_instance_valid(hud):
		hud.catching_up = false


## This machine is catching up on an earlier part of the floor (late join).
func is_catching_up() -> bool:
	return top().catching_up


# --- Events ------------------------------------------------------------------

## Host: run `level.method(args)` on every machine. Clients can't start events.
func event(method: StringName, args: Array = []) -> void:
	if not is_host():
		return
	_event.rpc(method, args)


@rpc("authority", "call_local", "reliable")
func _event(method: StringName, args: Array) -> void:
	_record("event", [method, args])
	level.callv(method, args)


## Host: call `node.method(args)` on every machine, e.g. an elevator's doors
## closing. The path is relative to the level, so it works inside wings.
func run_on(node: Node, method: StringName, args: Array = []) -> void:
	if is_host():
		_run_on.rpc(level.get_path_to(node), method, args)


@rpc("authority", "call_local", "reliable")
func _run_on(path: NodePath, method: StringName, args: Array) -> void:
	_record("run_on", [path, method, args])
	var node := level.get_node_or_null(path)
	if node:
		node.callv(method, args)


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
	_record("gate", [key])
	_gates[key] = true
	gate_opened.emit(key)


## Show a notice on every machine's HUD (host only).
func team_notice(text: String, seconds: float = 3.0) -> void:
	if is_host():
		_team_notice.rpc(text, seconds)


@rpc("authority", "call_local", "reliable")
func _team_notice(text: String, seconds: float) -> void:
	if level.hud:
		level.hud.notice(text, seconds, ThemeUtil.AMBER, HUD.Turn.NORMAL)  # news, not an answer: it waits its turn


## Host only: every player here earns `source` ("achievement:floor_g"...), owns
## the items it unlocks (Cosmetics) and sees "Unlocked: <item>". Only for what
## the crew finishes together: a floor or an ending. Anything one player does
## or finds themselves (a book, a block, a secret) goes through unlock_for, as
## each player has to earn those on their own (Augustine, 2026-10-21). Safe to
## call from a handler that runs on every machine: only the host's call goes
## out, and earning twice does nothing.
func unlock(source: String) -> void:
	if is_host():
		_unlock.rpc(source)


## Host only: just the players in `peer_ids` (the one who did the task or
## found the secret) earn `source`, each on their own machine.
func unlock_for(peer_ids: Array, source: String) -> void:
	if not is_host():
		return
	for id in peer_ids:
		if int(id) == multiplayer.get_unique_id():
			_unlock(source)
		elif multiplayer.get_peers().has(int(id)):
			_unlock.rpc_id(int(id), source)


@rpc("authority", "call_local", "reliable")
func _unlock(source: String) -> void:
	var net := get_node_or_null("/root/Net")
	if net:
		net.earn(source, level.get("hud"))


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


## This player answered case `id` (Game.answer_found): the host's level hears who
## (level.case_answered(id, peer_id)) and decides what happens next. With `missed`,
## they added a line that doesn't answer it, and the level hears what it held
## instead (level.case_missed(id, peer_id, missed)).
func report_answer(id: String, missed: String = "") -> void:
	if is_host():
		_host_answer(id, multiplayer.get_unique_id(), missed)
	else:
		_request_answer.rpc_id(1, id, missed)


@rpc("any_peer", "reliable")
func _request_answer(id: String, missed: String) -> void:
	if is_host():
		_host_answer(id, multiplayer.get_remote_sender_id(), missed)


func _host_answer(id: String, peer: int, missed: String) -> void:
	if missed == "":
		event("_crew_answered", [id, peer])  # the answer goes in everyone's slot
	if missed == "" and level.has_method("case_answered"):
		level.case_answered(id, peer)
	elif missed != "" and level.has_method("case_missed"):
		level.case_missed(id, peer, missed)


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
	elif node is PhysicsBody3D:
		node.add_to_group(SHOVE_PROOF)
		for p in get_tree().get_nodes_in_group("puppet"):
			LevelSync.keep_apart(node, p)


## `npc` (one the host simulates) moves as if `puppet` (a teammate's body on
## this machine) weren't there, if they share a world.
static func keep_apart(npc: Node, puppet: Node) -> void:
	if npc is PhysicsBody3D and puppet is PhysicsBody3D and npc.is_inside_tree() and puppet.is_inside_tree() \
			and npc.get_viewport() == puppet.get_viewport():
		npc.add_collision_exception_with(puppet)


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
	_record("query", [path, sql, result, from_peer])
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
	_record("request", [path, line, res, from_peer])
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
	_record("reset_db", [path])
	var terminal := level.get_node_or_null(path)
	if terminal:
		terminal.db.reset()
		terminal.print_line("Backup tape restored. Data is back to how it started.")


func _players() -> NetPlayers:
	return level.players
