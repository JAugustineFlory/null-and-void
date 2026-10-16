class_name NetPlayers
extends Node
## Everyone's bodies in one level: this machine's Player plus a PlayerPuppet
## for each other player. Sends this player's position to the others.

const SEND_RATE := 20.0
const COLORS := [Color(0.25, 0.45, 0.7), Color(0.7, 0.35, 0.2), Color(0.3, 0.6, 0.3), Color(0.6, 0.3, 0.6), Color(0.7, 0.6, 0.2), Color(0.3, 0.6, 0.65)]

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
			var p := PlayerPuppet.create(self, id, who, COLORS[i % COLORS.size()])
			p.players = self
			_puppets[id] = p


## Start sending positions (after every machine has loaded the level).
func go_live() -> void:
	_live = true


## Every player's id in this game, sorted, host first.
func all_ids() -> Array:
	var ids := [multiplayer.get_unique_id()]
	ids.append_array(multiplayer.get_peers())
	ids.sort()
	return ids


## This machine's place in the player order (0 = host).
func my_index() -> int:
	return all_ids().find(multiplayer.get_unique_id())


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
	_state.rpc(player.global_position, player.rotation.y, pitch, bool(player.get("crouching")), light_on)


@rpc("any_peer", "unreliable_ordered", "call_remote", 1)
func _state(pos: Vector3, yaw: float, pitch: float, crouch: bool, light_on: bool) -> void:
	var p: PlayerPuppet = _puppets.get(multiplayer.get_remote_sender_id())
	if p:
		p.apply_state(pos, yaw, pitch, crouch, light_on)


func _on_peer_left(id: int) -> void:
	var p: PlayerPuppet = _puppets.get(id)
	if p == null:
		return
	_puppets.erase(id)
	if level.get("hud"):
		level.hud.notice("%s lost contact." % p.display_name, 4.0)
	p.queue_free()
