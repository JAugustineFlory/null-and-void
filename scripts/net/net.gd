extends Node
## Co-op session: hosting, joining, the lobby roster and starting a run.
## Autoloaded as `Net`. Solo play never touches the network: the default
## offline peer makes this machine the host, so the same code runs both ways.

signal roster_changed
signal joined
signal session_ended(reason: String)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 6
## How a player stands on their mark in the pre-game lobby (LobbyStage draws them).
const LOBBY_POSES := ["wave", "lean", "sit", "shoulder", "pose"]
## The CharacterRig action each pose plays. One the rig can't draw yet plays "idle".
const LOBBY_POSE_ACTIONS := {"wave": "wave", "lean": "lean", "sit": "sit_floor", "shoulder": "shoulder", "pose": "pose"}
## How long a machine waits on a silent teammate before dropping them, as
## ENet's [retry limit, minimum ms, maximum ms]. In the lobby a client notices a
## vanished host in seconds. Loading the building can freeze a slow machine for
## several seconds, and a host frozen past the lobby's 3 s used to drop every
## joiner, so everyone waits much longer until the game has started and the
## first frames have drawn, then a little longer than the lobby while playing,
## when a wing streams in.
const PATIENCE_LOBBY := [32, 3000, 8000]
const PATIENCE_LOADING := [32, 20000, 45000]
const PATIENCE_PLAYING := [32, 8000, 20000]
## How long after everyone has loaded the building the loading patience lasts.
const SETTLE_TIME := 10.0
const NAMES := ["Ash", "Briggs", "Cole", "Dana", "Ellis", "Frankie", "Gray", "Harper", "Jo", "Kit", "Lane", "Morgan"]

## peer id -> player name, identical on every machine.
var roster := {}
## peer id -> their whole loadout (Cosmetics.clean), identical on every machine:
## crew member (voice and body type), skin, and an item and color per worn slot and tool.
var looks := {}
## peer id -> where they are in the pre-game lobby, identical on every machine:
## {"ready": bool, "pose": index into LOBBY_POSES}. Kept into the game, so the
## garage opens on everyone where the lobby left them (HomeBase).
var lobby := {}
## What this player picked in the lobby: a partial loadout (Cosmetics.trim).
## Anything left out follows their place in the player order, so teammates who
## never open the picker still look different.
var wanted_look := {}
## This player's saved name, picks and unlocks (user://profile.cfg).
var profile: Profile
var player_name := ""
var in_game := false
## The pre-game lobby is for one player: no session, Ready starts a solo game.
var solo_lobby := false
## Why the last session ended, for the menu to show.
var last_message := ""
var transport: NetTransport = NetTransport.Enet.new()


func _ready() -> void:
	profile = Profile.open()
	player_name = profile.name if profile.name != "" else NAMES[randi() % NAMES.size()]
	wanted_look = profile.loadout.duplicate(true)
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


## `peer_id`'s loadout. `fallback` (their place in the player order) fills in
## whatever they never chose.
func look_of(peer_id: int, fallback: int) -> Dictionary:
	if looks.has(peer_id):
		return looks[peer_id]
	return Cosmetics.clean(wanted_look if not is_online() else {}, fallback)


## The color `peer`'s terminal skin draws in: the whole screen when they sat
## down first, and their own prompt line.
func terminal_color(peer: int) -> Color:
	return CharacterLooks.terminal_skin(look_of(peer, maxi(player_ids().find(peer), 0)).terminal)


## Change part of this player's loadout in the lobby, e.g. {"skin": 2},
## {"crew": "dana"} or {"top": {"color": Color.RED}}. Saved to their profile.
## Teammates can pick the same as each other.
func choose_look(change: Dictionary) -> void:
	wanted_look = Cosmetics.trim(Cosmetics.merge(wanted_look, change), profile)
	profile.loadout = wanted_look.duplicate(true)
	profile.save()
	if not is_online():
		roster_changed.emit()
	elif is_host():
		_assign_look(1, wanted_look)
	else:
		_request_look.rpc_id(1, wanted_look)


# --- The pre-game lobby -------------------------------------------------------

## Solo: the pre-game lobby with just this player in it (no connection).
func begin_solo_lobby() -> void:
	leave(false)
	solo_lobby = true
	roster = {my_id(): player_name}
	roster_changed.emit()


## Solo: everyone (that's you) is ready, so the game starts. The lobby's state
## stays for the garage to open on.
func start_solo_game() -> void:
	solo_lobby = false
	var game := get_node("/root/Game")
	game.new_run()
	game.open_at_home = true
	game.goto("world")


## This player is ready to start (or not any more).
func set_ready(on: bool) -> void:
	_lobby_change({"ready": on})


## This player stands on their mark the next way (LOBBY_POSES).
func next_pose() -> void:
	_lobby_change({"pose": lobby_of(my_id()).pose + 1})


## `peer`'s place in the lobby. Until they change it: not ready, and a pose
## by their place in the player order, so a full crew doesn't all stand alike.
func lobby_of(peer: int) -> Dictionary:
	if lobby.has(peer):
		return lobby[peer]
	return {"ready": false, "pose": maxi(lobby_index(peer), 0) % LOBBY_POSES.size()}


## The CharacterRig action `peer` shows on their mark (HomeBase opens on it).
func lobby_action(peer: int) -> String:
	return pose_action(LOBBY_POSES[lobby_of(peer).pose])


static func pose_action(pose: String) -> String:
	var action: String = LOBBY_POSE_ACTIONS.get(pose, "idle")
	return action if action in CharacterRig.ACTIONS else "idle"


## `peer`'s place in the player order (host first), which is their lobby mark.
func lobby_index(peer: int) -> int:
	var ids := roster.keys()
	ids.sort()
	return ids.find(peer)


## Everyone in the session is ready.
func all_ready() -> bool:
	return not roster.is_empty() and roster.keys().all(func(id): return lobby_of(id).ready)


func _lobby_change(change: Dictionary) -> void:
	if is_host():
		_assign_lobby(my_id(), change)
	else:
		_request_lobby.rpc_id(1, change)


@rpc("any_peer", "reliable")
func _request_lobby(change: Dictionary) -> void:
	if is_host() and not in_game and roster.has(multiplayer.get_remote_sender_id()):
		_assign_lobby(multiplayer.get_remote_sender_id(), change)


## The host takes the change (junk is ignored) and tells everyone.
func _assign_lobby(peer: int, change: Dictionary) -> void:
	var state := lobby_of(peer).duplicate()
	if change.get("ready") is bool:
		state.ready = change.ready
	if change.get("pose") is int:
		state.pose = posmod(change.pose, LOBBY_POSES.size())
	lobby[peer] = state
	_set_roster.rpc(roster, looks, lobby)
	roster_changed.emit()


## The name teammates see, saved to the profile. In the lobby it changes for
## everyone (the host keeps names apart).
func set_player_name(n: String) -> void:
	player_name = n.strip_edges().left(16) if n.strip_edges() != "" else "Player"
	profile.name = n.strip_edges().left(16)
	profile.save()
	if in_game or not roster.has(my_id()):
		return
	if not is_online():
		roster[my_id()] = player_name
		roster_changed.emit()
	elif is_host():
		_assign_name(1, player_name)
	else:
		_request_name.rpc_id(1, player_name)


@rpc("any_peer", "reliable")
func _request_name(wanted: String) -> void:
	if is_host() and not in_game and roster.has(multiplayer.get_remote_sender_id()):
		_assign_name(multiplayer.get_remote_sender_id(), wanted)


func _assign_name(peer: int, wanted: String) -> void:
	roster[peer] = _unique_name(wanted.strip_edges().left(16), peer)
	_set_roster.rpc(roster, looks, lobby)
	roster_changed.emit()


## This player earned an achievement or found a secret ("secret:<id>"): own
## what it unlocks and say so on `hud`, the achievement's name (Achievements)
## first. Each machine calls it for its own player (LevelSync.unlock_for, or
## LevelSync.unlock for a floor finished together). Items Graphics can't draw
## yet are owned quietly, and simply appear in the lobby once they can be.
func earn(source: String, hud: Node = null) -> Array:
	var fresh := not profile.earned.has(source)
	var got := profile.earn(source)
	var lines := []
	if fresh and Achievements.name_of(source) != "":
		lines.append(Achievements.NOTICE % Achievements.name_of(source))
	for k in got:
		var slot: String = k.get_slice("/", 0)
		var item: String = k.get_slice("/", 1)
		if Cosmetics.drawable(slot, item):
			lines.append("Unlocked: %s" % Cosmetics.info(slot, item).name)
	if hud and not lines.is_empty():
		hud.notice("\n".join(lines), 3.0 + 1.5 * lines.size())
	return got


@rpc("any_peer", "reliable")
func _request_look(choice: Dictionary) -> void:
	if is_host() and not in_game and roster.has(multiplayer.get_remote_sender_id()):
		_assign_look(multiplayer.get_remote_sender_id(), choice)


## The host checks a loadout against the catalogue (it trusts what they own)
## and tells everyone.
func _assign_look(peer: int, choice: Dictionary) -> void:
	looks[peer] = Cosmetics.clean(choice, maxi(roster.keys().find(peer), 0))
	_set_roster.rpc(roster, looks, lobby)
	roster_changed.emit()


func host(port: int = DEFAULT_PORT) -> Error:
	leave(false)
	var peer := transport.create_host(port, MAX_PLAYERS - 1)
	if peer == null:
		return ERR_CANT_CREATE
	multiplayer.multiplayer_peer = peer
	roster = {1: player_name}
	looks = {}
	lobby = {}
	_assign_look(1, wanted_look)
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
	lobby = {}
	in_game = false
	solo_lobby = false
	if was_online and notify:
		last_message = reason
		session_ended.emit(reason)


## Host only: everyone loads the building with the same run seed, at `level`
## (a Game.LEVELS key; "world" opens on the garage).
func start_game(level := "world") -> void:
	if not is_host():
		return
	_start.rpc(randi(), roster, looks, level)


@rpc("authority", "call_local", "reliable")
func _start(seed_value: int, names: Dictionary, picked: Dictionary, level := "world") -> void:
	roster = names
	looks = picked
	in_game = true
	set_patience(PATIENCE_LOADING)
	var game := get_node("/root/Game")
	game.new_run(seed_value)
	var key: String = level if game.LEVELS.has(level) else "world"
	game.open_at_home = key == "world"
	game.goto(key)


## The building has loaded on every machine (LevelSync, once it begins): after
## the first frames have drawn, back to the patience for playing.
func world_began() -> void:
	await get_tree().create_timer(SETTLE_TIME).timeout
	if in_game:
		set_patience(PATIENCE_PLAYING)


## How long this machine waits on each teammate (PATIENCE_*). Solo: nothing.
func set_patience(patience: Array) -> void:
	var peer := multiplayer.multiplayer_peer
	if not peer is ENetMultiplayerPeer:
		return
	for id in multiplayer.get_peers():
		patient(peer.get_peer(id), patience)


static func patient(link: ENetPacketPeer, patience: Array) -> void:
	if link:
		link.set_timeout(patience[0], patience[1], patience[2])


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
	set_patience(PATIENCE_LOBBY)
	_register.rpc_id(1, player_name, wanted_look)


@rpc("any_peer", "reliable")
func _register(wanted: String, look: Dictionary) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_game:
		_refused.rpc_id(id, "That game has already started.")
		return
	if roster.size() >= MAX_PLAYERS:
		_refused.rpc_id(id, "That lobby is full (%d players)." % MAX_PLAYERS)
		return
	roster[id] = _unique_name(wanted.strip_edges().left(16), id)
	_assign_look(id, look)
	roster_changed.emit()


@rpc("authority", "reliable")
func _set_roster(names: Dictionary, picked: Dictionary, waiting := {}) -> void:
	var first := roster.is_empty()
	roster = names
	looks = picked
	lobby = waiting
	roster_changed.emit()
	if first:
		joined.emit()


@rpc("authority", "reliable")
func _refused(reason: String) -> void:
	leave(true, reason)


## `wanted`, or numbered if someone other than `peer` already has it.
func _unique_name(wanted: String, peer := 0) -> String:
	var base := wanted if wanted != "" else "Player"
	var taken := roster.keys().filter(func(id): return id != peer).map(func(id): return roster[id])
	var n := base
	var i := 2
	while taken.has(n):
		n = "%s %d" % [base, i]
		i += 1
	return n


func _on_peer_disconnected(id: int) -> void:
	if not roster.has(id):
		return
	roster.erase(id)
	looks.erase(id)
	lobby.erase(id)
	roster_changed.emit()
	if is_host():
		_set_roster.rpc(roster, looks, lobby)


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
