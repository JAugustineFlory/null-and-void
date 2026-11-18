class_name NetPlayers
extends Node
## Everyone's bodies in one level: this machine's Player plus a PlayerPuppet
## for each other player. Sends this player's position to the others.

const SEND_RATE := 20.0
## Someone joined the game while it was going (approved by Augustine 2026-11-18 01:28Z).
const JOINED := "%s joined the crew."
## Died on a Hard floor, left, and came back to it (Augustine's name, 2026-11-18).
const NICE_TRY := "achievement:nice_try"

var level: Node
var player: Node3D  # this machine's Player
var _puppets := {}  # peer id -> PlayerPuppet
var _send_t := 0.0
var _live := false
## Players who joined the game already going, waiting for their name and look.
var _joining := {}
## Host, Hard mode: the names of the dead who left, with the floor they died on.
## Back on that floor they come in as a ghost (plan/hard-mode.md, 10.3).
var _ghosts := {}
## Watching a teammate while dead (Hard mode), or null.
var spectate: Spectate
var _crew: Node


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
	multiplayer.peer_connected.connect(_on_peer_joined)
	if _session():
		get_node("/root/Net").roster_changed.connect(_names_changed)
	var net := get_node_or_null("/root/Net")
	var ids := all_ids()
	for i in ids.size():
		var id: int = ids[i]
		if id != multiplayer.get_unique_id():
			var who: String = net.display_name(id) if net else "Player %d" % id
			# Stand where that player spawns until their first update arrives.
			var at: Transform3D = level.player_spawn(i)
			var p := PlayerPuppet.create(self, id, who, look_for(self, id), at)
			p.players = self
			_puppets[id] = p
	watch_crew.call_deferred()


## Follow the crew's deaths (CrewVitals is made just after this): dead, you
## watch a teammate; back, you see through your own eyes again.
func watch_crew(crew: Node = null) -> void:
	if crew == null:
		crew = CrewVitals.of(level)
	if crew == null or crew == _crew:
		return
	_crew = crew
	if crew.has_signal("died"):
		crew.died.connect(_on_died)
	if crew.has_signal("passed_out"):
		crew.passed_out.connect(_recheck_triggers.unbind(1))  # out cold: nobody waits on them
	if crew.has_signal("came_back"):
		crew.came_back.connect(_on_came_back)
	if crew.has_signal("wiped"):
		crew.wiped.connect(_on_came_back.bind(multiplayer.get_unique_id()))  # everyone down: watch it end from where you lie


## Is player `id` dead (Hard mode)? The dead watch, and don't count for "everyone".
func is_dead(id: int) -> bool:
	var crew = _crew if is_instance_valid(_crew) else CrewVitals.of(level)
	return crew != null and crew.has_method("is_dead") and crew.is_dead(id)


## Counted as there for "everyone present": not dead, and not passed out (down
## but awake still counts: a kit can reach them). CrewVitals.is_present.
func is_present(id: int) -> bool:
	var crew = _crew if is_instance_valid(_crew) else CrewVitals.of(level)
	if crew != null and crew.has_method("is_present"):
		return crew.is_present(id)
	return not is_dead(id)


## Dead (every machine): you watch a teammate, and nobody waits on you.
func _on_died(id: int, _cause = "") -> void:
	if id == multiplayer.get_unique_id() and spectate == null and _puppets.size() > 0:
		spectate = Spectate.create(self)
	_recheck_triggers()


## Whoever was waiting on someone at a door or the stairs needn't any more.
func _recheck_triggers() -> void:
	for t in get_tree().get_nodes_in_group(Trigger.GROUP):
		if t.get_viewport() == get_viewport():
			t.recheck()


func _on_came_back(id: int) -> void:
	if id == multiplayer.get_unique_id():
		stop_watching()


## Back to your own eyes.
func stop_watching() -> void:
	if is_instance_valid(spectate):
		spectate.stop()
	spectate = null


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


## How player `id` looks (a CharacterLooks dictionary, with their tool skins
## under "tools"): what they picked in the lobby, the rest by their place in
## the player order.
static func look_for(from: Node, id: int) -> Dictionary:
	var fallback := index_of(id, from.multiplayer)
	var net := from.get_node_or_null("/root/Net")
	return loadout_look(net.look_of(id, fallback) if net else Cosmetics.default_loadout(fallback))


## A loadout (Cosmetics.clean) as a CharacterLooks dictionary. `tools` holds
## {flashlight, walkie, notebook, terminal: {item, color}} for the held items.
static func loadout_look(loadout: Dictionary) -> Dictionary:
	var look := CharacterLooks.outfit(loadout)
	look.tools = {}
	for slot in Cosmetics.TOOL_SLOTS:
		look.tools[slot] = loadout.get(slot, {})
	return look


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


## Deal damage to player `id`, on whichever machine owns that player. `cause`
## says what hit them (see PlayerCombat.CAUSES): their own machine decides
## whether they blocked it.
func hurt(id: int, amount: float, cause: String = "") -> void:
	if id == multiplayer.get_unique_id():
		player.take_damage(amount, cause)
	elif multiplayer.is_server():
		_hurt.rpc_id(id, amount, cause)


@rpc("authority", "reliable")
func _hurt(amount: float, cause: String) -> void:
	player.take_damage(amount, cause)


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
	var sit := PlayerPuppet.Sit.NONE
	if player.has_method("is_sitting") and player.is_sitting():
		sit = PlayerPuppet.Sit.CHAIR if player.get("seat") != null else PlayerPuppet.Sit.FLOOR
	_state.rpc(player.global_position, player.rotation.y, pitch, height, light_on, sit, fight_action())


## What this player's fists are doing (FirstPersonBody: "jab", "cross", "guard",
## "recoil", "flinch"), or "" when they aren't fighting.
func fight_action() -> String:
	var fp := player.get_node_or_null("FirstPersonBody")
	var action: String = fp.current_action() if fp and fp.has_method("current_action") else ""
	return action if action in PlayerPuppet.FIGHT_ACTIONS else ""


@rpc("any_peer", "unreliable_ordered", "call_remote", 1)
func _state(pos: Vector3, yaw: float, pitch: float, height: float, light_on: bool, sit: int, fight := "") -> void:
	var p: PlayerPuppet = _puppets.get(multiplayer.get_remote_sender_id())
	if p:
		p.apply_state(pos, yaw, pitch, height, light_on, sit)
		p.set_fight(fight)


## A player joined the game already going: once their name and look arrive
## (the roster, just after they connect), they appear at the start of the floor
## the crew is on, where their own machine puts them.
func _on_peer_joined(id: int) -> void:
	if _puppets.has(id) or id == multiplayer.get_unique_id():
		return
	if not _session():
		_add_joiner(id, "Player %d" % id)  # no roster to wait for (tests, a session without Net)
		return
	_joining[id] = true
	_names_changed()


## This level's players are Net's session (not a test's own machines).
func _session() -> bool:
	var net := get_node_or_null("/root/Net")
	return net != null and net.multiplayer == multiplayer


func _names_changed() -> void:
	var net := get_node("/root/Net")
	for id in _joining.keys():
		if net.roster.has(id) and net.looks.has(id):
			_joining.erase(id)
			_add_joiner(id, net.display_name(id))


func _add_joiner(id: int, who: String) -> void:
	if _puppets.has(id) or not multiplayer.get_peers().has(id):
		return
	var here: Node = level.get("current") if level.get("current") else level
	var p := PlayerPuppet.create(self, id, who, look_for(self, id), here.player_spawn(all_ids().find(id)))
	p.players = self
	_puppets[id] = p
	if level.get("hud"):
		level.hud.notice(JOINED % who, 4.0)
	if multiplayer.is_server() and _ghosts.get(who, "") == _floor_key():
		# Died here, left, and came back: they watch, as before ("Nice Try").
		_ghosts.erase(who)
		if _crew and _crew.has_method("mark_dead"):
			_crew.mark_dead(id)
		var sync := LevelSync.of(self)
		if sync:
			sync.unlock_for([id], NICE_TRY)


func _floor_key() -> String:
	var game := get_node_or_null("/root/Game")
	return str(game.floor_start.get("key", "")) if game else ""


func _on_peer_left(id: int) -> void:
	var p: PlayerPuppet = _puppets.get(id)
	if p == null:
		return
	_puppets.erase(id)
	if multiplayer.is_server() and is_dead(id):
		_ghosts[p.display_name] = _floor_key()
	if level.get("hud"):
		level.hud.notice("%s lost contact." % p.display_name, 4.0)
	p.queue_free()
