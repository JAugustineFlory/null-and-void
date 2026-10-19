class_name NetPlayers
extends Node
## Everyone's bodies in one level: this machine's Player plus a PlayerPuppet
## for each other player. Sends this player's position to the others.

const SEND_RATE := 20.0

var level: Node
var player: Node3D  # this machine's Player
var _puppets := {}  # peer id -> PlayerPuppet
var _send_t := 0.0
var _live := false


static func create(for_level: Node, local_player: Node3D) -> NetPlayers:
	var np := NetPlayers.new()
	np.name = "NetPlayers"
	np.level = for_level
	np.player = local_player
	np.add_to_group("net_players")
	for_level.add_child(np)
	return np


## Where player number `index` (0 = host) stands at a spawn point, so up to six
## people don't appear inside each other.
static func spawn_offset(index: int) -> Vector3:
	var slots := [Vector3.ZERO, Vector3(1.0, 0, 0), Vector3(-1.0, 0, 0), Vector3(0, 0, 1.0), Vector3(1.0, 0, 1.0), Vector3(-1.0, 0, 1.0)]
	return slots[index % slots.size()]


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_left)
	var ids := all_ids()
	for i in ids.size():
		var id: int = ids[i]
		if id != multiplayer.get_unique_id():
			var net := get_node_or_null("/root/Net")
			var who: String = net.display_name(id) if net else "Player %d" % id
			# Stand where that player spawns until their first update arrives.
			var at: Transform3D = level.player_spawn(i)
			var p := PlayerPuppet.create(self, id, who, i, at)
			p.players = self
			_puppets[id] = p


## Start sending positions (after every machine has loaded the level).
func go_live() -> void:
	_live = true


## Every player's id in this game, sorted, host first.
func all_ids() -> Array:
	return ids_for(multiplayer)


static func ids_for(mp: MultiplayerAPI) -> Array:
	var ids := [mp.get_unique_id()]
	ids.append_array(mp.get_peers())
	ids.sort()
	return ids


## A player's place in the player order (0 = host).
static func index_of(id: int, mp: MultiplayerAPI) -> int:
	return ids_for(mp).find(id)


func my_index() -> int:
	return index_of(multiplayer.get_unique_id(), multiplayer)


## Put everyone at their start spot in `in_level` (puppets until their next update).
func place_all(in_level: Node) -> void:
	var ids := all_ids()
	for i in ids.size():
		var body := puppet(ids[i])
		if body:
			body.global_transform = in_level.player_spawn(i)


## The peer id behind a body: the local Player or a puppet.
func id_of(body: Node) -> int:
	if body == player:
		return multiplayer.get_unique_id()
	return body.get("peer_id") if body.get("peer_id") != null else 0


func count() -> int:
	return 1 + _puppets.size()


## The body for player `id`: the local Player or a puppet.
func puppet(id: int) -> Node3D:
	if id == multiplayer.get_unique_id():
		return player
	return _puppets.get(id)


func all_players() -> Array:
	var out := [player]
	out.append_array(_puppets.values())
	return out


func nearest(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p in all_players():
		var d: float = p.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = p
	return best


func names() -> Dictionary:
	var out := {}
	for id in _puppets:
		out[id] = _puppets[id].display_name
	return out


## Deal damage to player `id`, on whichever machine owns that player.
func hurt(id: int, amount: float) -> void:
	if id == multiplayer.get_unique_id():
		player.take_damage(amount)
	elif multiplayer.is_server():
		_hurt.rpc_id(id, amount)


@rpc("authority", "reliable")
func _hurt(amount: float) -> void:
	player.take_damage(amount)


func _physics_process(delta: float) -> void:
	if not _live or _puppets.is_empty() or not is_instance_valid(player):
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_send_t += delta
	if _send_t < 1.0 / SEND_RATE:
		return
	_send_t = 0.0
	var pitch: float = player.head.rotation.x if player.get("head") else 0.0
	var light_on: bool = player.flashlight.visible if player.get("flashlight") else false
	# Stance height covers standing, crouching and crawling in vents alike.
	var height: float = player.get("stance_height") if player.get("stance_height") != null else PlayerPuppet.STAND_HEIGHT
	_state.rpc(player.global_position, player.rotation.y, pitch, height, light_on)


@rpc("any_peer", "unreliable_ordered", "call_remote", 1)
func _state(pos: Vector3, yaw: float, pitch: float, height: float, light_on: bool) -> void:
	var p: PlayerPuppet = _puppets.get(multiplayer.get_remote_sender_id())
	if p:
		p.apply_state(pos, yaw, pitch, height, light_on)


# --- Shared notes ---------------------------------------------------------------

## The NetPlayers of the game in progress, if it's co-op (for the notebook).
static func of_session(tree: SceneTree) -> NetPlayers:
	for np in tree.get_nodes_in_group("net_players"):
		if np.is_inside_tree() and np.multiplayer.has_multiplayer_peer() and np.multiplayer.get_peers().size() > 0:
			return np
	return null


## Copy `entry` (one of this player's notebook_written lines) into every
## teammate's notebook. It's marked shared here so it isn't sent twice.
func share_note(entry: Dictionary) -> void:
	if entry.get("shared", false):
		return
	entry["shared"] = true
	_note.rpc({"label": entry.get("label", ""), "text": entry.get("text", ""), "kind": entry.get("kind", "")})
	get_node("/root/Game").notebook_changed.emit()


@rpc("any_peer", "reliable")
func _note(entry: Dictionary) -> void:
	var from := multiplayer.get_remote_sender_id()
	var p: PlayerPuppet = _puppets.get(from)
	var who: String = p.display_name if p else "Player %d" % from
	get_node("/root/Game").receive_shared(who, entry)
	if level.get("hud"):
		level.hud.notice("%s shared a note (Tab)" % who, 3.0)


func _on_peer_left(id: int) -> void:
	var p: PlayerPuppet = _puppets.get(id)
	if p == null:
		return
	_puppets.erase(id)
	if level.get("hud"):
		level.hud.notice("%s lost contact." % p.display_name, 4.0)
	p.queue_free()
