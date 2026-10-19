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
## peer id -> the crew look they picked (CharacterLooks.crew index), identical
## on every machine. No two players share one.
var looks := {}
## The look this player picks in the lobby; the host gives it to them if it's free.
var wanted_look := -1
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


## Which crew look `peer_id` wears. `fallback` (their place in the player order)
## is used when they never picked one.
func look_of(peer_id: int, fallback: int) -> int:
	if looks.has(peer_id):
		return int(looks[peer_id])
	if not is_online() and wanted_look >= 0:
		return wanted_look
	return fallback


## The look `peer` gets: `wanted` if no one else has it, else the first free one.
static func free_look(taken_looks: Dictionary, peer: int, wanted: int) -> int:
	var taken := []
	for id in taken_looks:
		if id != peer:
			taken.append(int(taken_looks[id]))
	if wanted >= 0 and wanted < MAX_PLAYERS and not taken.has(wanted):
		return wanted
	for i in MAX_PLAYERS:
		if not taken.has(i):
			return i
	return 0


## Pick look `index` in the lobby. Refused if a teammate already has it.
func choose_look(index: int) -> void:
	wanted_look = index
	if not is_online():
		roster_changed.emit()
	elif is_host():
		_assign_look(1, index)
	else:
		_request_look.rpc_id(1, index)


@rpc("any_peer", "reliable")
func _request_look(index: int) -> void:
	if is_host() and not in_game and roster.has(multiplayer.get_remote_sender_id()):
		_assign_look(multiplayer.get_remote_sender_id(), index)


func _assign_look(peer: int, index: int) -> void:
	if free_look(looks, peer, index) != index:
		return
	looks[peer] = index
	_set_roster.rpc(roster, looks)
	roster_changed.emit()


func host(port: int = DEFAULT_PORT) -> Error:
	leave(false)
	var peer := transport.create_host(port, MAX_PLAYERS - 1)
	if peer == null:
		return ERR_CANT_CREATE
	multiplayer.multiplayer_peer = peer
	roster = {1: player_name}
	looks = {1: free_look({}, 1, wanted_look)}
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
	looks = {}
	in_game = false
	if was_online and notify:
		last_message = reason
		session_ended.emit(reason)


## Host only: everyone loads the building with the same run seed.
func start_game() -> void:
	if not is_host():
		return
	_start.rpc(randi(), roster, looks)


@rpc("authority", "call_local", "reliable")
func _start(seed_value: int, names: Dictionary, picked: Dictionary) -> void:
	roster = names
	looks = picked
	in_game = true
	var game := get_node("/root/Game")
	game.new_run(seed_value)
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
	_register.rpc_id(1, player_name, wanted_look)


@rpc("any_peer", "reliable")
func _register(wanted: String, look: int) -> void:
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
	looks[id] = free_look(looks, id, look)
	_set_roster.rpc(roster, looks)
	roster_changed.emit()


@rpc("authority", "reliable")
func _set_roster(names: Dictionary, picked: Dictionary) -> void:
	var first := roster.is_empty()
	roster = names
	looks = picked
	if looks.has(multiplayer.get_unique_id()):
		wanted_look = int(looks[multiplayer.get_unique_id()])
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
	looks.erase(id)
	roster_changed.emit()
	if is_host():
		_set_roster.rpc(roster, looks)


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
