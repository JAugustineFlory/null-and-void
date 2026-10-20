extends Node
## Co-op session: hosting, joining, the lobby roster and starting a run.
## Autoloaded as `Net`. Solo play never touches the network: the default
## offline peer makes this machine the host, so the same code runs both ways.

signal roster_changed
signal joined
signal session_ended(reason: String)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 6
const NAMES := ["Ash", "Briggs", "Cole", "Dana", "Ellis", "Frankie", "Gray", "Harper", "Jo", "Kit", "Lane", "Morgan"]

## peer id -> player name, identical on every machine.
var roster := {}
var player_name := ""
var in_game := false
## Why the last session ended, for the menu to show.
var last_message := ""
var transport: NetTransport = NetTransport.Enet.new()


func _ready() -> void:
	player_name = NAMES[randi() % NAMES.size()]
	_bind_key("radio_talk", KEY_V)
	_bind_key("voice_toggle", KEY_B)
	var mp := get_tree().get_multiplayer()
	mp.peer_disconnected.connect(_on_peer_disconnected)
	mp.connected_to_server.connect(_on_connected)
	mp.connection_failed.connect(_on_connection_failed)
	mp.server_disconnected.connect(_on_server_disconnected)


## True when other machines are (or may be) connected.
func is_online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func display_name(peer_id: int) -> String:
	return str(roster.get(peer_id, "Player %d" % peer_id))


func host(port: int = DEFAULT_PORT) -> Error:
	leave(false)
	var peer := transport.create_host(port, MAX_PLAYERS - 1)
	if peer == null:
		return ERR_CANT_CREATE
	multiplayer.multiplayer_peer = peer
	roster = {1: player_name}
	roster_changed.emit()
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	leave(false)
	var peer := transport.create_client(address.strip_edges(), port)
	if peer == null:
		return ERR_CANT_CONNECT
	multiplayer.multiplayer_peer = peer
	return OK


## Close the connection and go back to solo.
func leave(notify: bool = true, reason: String = "") -> void:
	var was_online := is_online()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster = {}
	in_game = false
	if was_online and notify:
		last_message = reason
		session_ended.emit(reason)


## Host only: everyone loads the building with the same run seed.
func start_game() -> void:
	if not is_host():
		return
	_start.rpc(randi(), roster)


@rpc("authority", "call_local", "reliable")
func _start(seed_value: int, names: Dictionary) -> void:
	roster = names
	in_game = true
	var game := get_node("/root/Game")
	game.new_run(seed_value)
	game.open_at_home = true
	game.goto("world")


## Host only: everyone goes to the same screen (e.g. on from the field notes).
func goto_all(key: String) -> void:
	if is_host():
		_goto.rpc(key)


@rpc("authority", "call_local", "reliable")
func _goto(key: String) -> void:
	get_node("/root/Game").goto(key)


## Every machine's player ids, sorted, host first. Solo: just this one.
func player_ids() -> Array:
	var ids := [multiplayer.get_unique_id()]
	ids.append_array(multiplayer.get_peers())
	ids.sort()
	return ids


## Local IPv4 addresses a friend could join, for the lobby screen.
static func local_addresses() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.contains(".") and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


func _exit_tree() -> void:
	# Tell the others we're gone instead of letting them time out.
	if is_online():
		multiplayer.multiplayer_peer.close()


func _on_connected() -> void:
	# Notice a vanished host in seconds rather than half a minute.
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.get_peer(1).set_timeout(32, 3000, 8000)
	_register.rpc_id(1, player_name)


@rpc("any_peer", "reliable")
func _register(wanted: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_game:
		_refused.rpc_id(id, "That game has already started.")
		return
	if roster.size() >= MAX_PLAYERS:
		_refused.rpc_id(id, "That lobby is full (%d players)." % MAX_PLAYERS)
		return
	roster[id] = _unique_name(wanted.strip_edges().left(16))
	_set_roster.rpc(roster)
	roster_changed.emit()


@rpc("authority", "reliable")
func _set_roster(names: Dictionary) -> void:
	var first := roster.is_empty()
	roster = names
	roster_changed.emit()
	if first:
		joined.emit()


@rpc("authority", "reliable")
func _refused(reason: String) -> void:
	leave(true, reason)


func _unique_name(wanted: String) -> String:
	var base := wanted if wanted != "" else "Player"
	var n := base
	var i := 2
	while roster.values().has(n):
		n = "%s %d" % [base, i]
		i += 1
	return n


func _on_peer_disconnected(id: int) -> void:
	if not roster.has(id):
		return
	roster.erase(id)
	roster_changed.emit()
	if is_host():
		_set_roster.rpc(roster)


func _on_connection_failed() -> void:
	leave(true, "Couldn't reach the host. Check the address, and that the host's port %d is open." % DEFAULT_PORT)


func _on_server_disconnected() -> void:
	var was_in_game := in_game
	leave(true, "The host closed the game.")
	if was_in_game:
		get_node("/root/Game").goto("menu")


func _bind_key(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
