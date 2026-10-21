class_name CrewVitals
extends Node
## Who in the crew is down, the same on every machine, and what entities do to
## players on other machines. Each level has one ("Crew"), made next to its
## NetPlayers.
##
## A player's own machine decides when they go down (it has their health and
## their guard) and tells the host; the host plays it out everywhere. When the
## last one standing goes down, the host calls the level's on_crew_down(cause) on
## every machine (by default, everyone comes to at the checkpoint).
## Solo, the crew is one player, so going down is the whole crew going down.
##
## Entities run on the host. To hurt, throw or grab a player, they go through
## here (or the player's take_damage), and it reaches the machine that owns them.

## Every machine: the last one standing went down.
signal crew_down(cause: String)
## Host: a player's block caught a hit from `cause` (the attacker can recoil).
signal hit_blocked(peer_id: int, cause: String)
## Every machine: the crew earned an unlock (`source` is a Profile.earn id).
signal unlocked(source: String)

## Lines for Augustine's approval: see plan/approvals/combat-strings.md.
const REVIVE_PROMPT := "[E] Help them up"
## Anyone's first block in a real fight: the High-tops, for everyone present
## (plan/approvals/unlocks.md). The punch bag's practice swings never count.
const FIRST_BLOCK := "achievement:first_block"

var level: Node
var players: Node  # NetPlayers
## peer id -> what put them down.
var downed := {}
## Host: the first-block unlock has gone out from this level already.
var _first_block_sent := false


static func create(for_level: Node, net_players: Node) -> CrewVitals:
	var c := CrewVitals.new()
	c.name = "Crew"
	c.level = for_level
	c.players = net_players
	for_level.add_child(c)
	return c


## The CrewVitals of the level `node` is in, or null.
static func of(node: Node) -> CrewVitals:
	var n := node
	while n:
		var c := n.get_node_or_null("Crew")
		if c is CrewVitals:
			return c
		n = n.get_parent()
	return null


## Is this body (a Player or a teammate's puppet) lying down?
static func is_down(body: Node) -> bool:
	return body != null and body.get("downed") == true


func _sync() -> LevelSync:
	return level.get("sync")


func is_online() -> bool:
	var s := _sync()
	return s != null and s.is_online()


func _is_host() -> bool:
	var s := _sync()
	return s == null or s.is_host()


func my_id() -> int:
	return multiplayer.get_unique_id()


func _local_combat() -> PlayerCombat:
	var p: Node = players.player if players else null
	return p.get("combat") if p else null


# --- Going down and getting up -----------------------------------------------

## The local player went down (or came out of it).
func report_down(is_down: bool, cause: String) -> void:
	if _is_host():
		_host_down(my_id(), is_down, cause)
	else:
		_ask_down.rpc_id(1, is_down, cause)


@rpc("any_peer", "reliable")
func _ask_down(is_down: bool, cause: String) -> void:
	if _is_host():
		_host_down(multiplayer.get_remote_sender_id(), is_down, cause)


func _host_down(id: int, is_down: bool, cause: String) -> void:
	_run("_set_down", [id, is_down, cause])
	if is_down and players.all_ids().all(func(i): return downed.has(i)):
		_run("_all_down", [cause])


func _set_down(id: int, is_down: bool, cause: String) -> void:
	if is_down:
		downed[id] = cause
	else:
		downed.erase(id)
	var body: Node = players.puppet(id)
	if body is PlayerPuppet:
		body.set_downed(is_down)


func _all_down(cause: String) -> void:
	crew_down.emit(cause)
	level.on_crew_down(cause)


## The default end of a crew going down: everyone who's down comes to at the
## checkpoint (the level's on_player_died).
func send_everyone_back() -> void:
	var c := _local_combat()
	if c and c.down:
		c.die()


## The prompt on a teammate's body.
func revive_prompt(id: int) -> String:
	return REVIVE_PROMPT if downed.has(id) and not CrewVitals.is_down(players.player) else ""


## The local player helps teammate `id` up.
func revive(id: int) -> void:
	if CrewVitals.is_down(players.player):
		return
	if _is_host():
		_host_revive(id)
	else:
		_ask_revive.rpc_id(1, id)


@rpc("any_peer", "reliable")
func _ask_revive(id: int) -> void:
	if _is_host():
		_host_revive(id)


func _host_revive(id: int) -> void:
	if downed.has(id):
		_run("_revived", [id])


func _revived(id: int) -> void:
	_set_down(id, false, "")
	if id == my_id():
		var c := _local_combat()
		if c:
			c.revive()


## Host: run on every machine (or just here, with no LevelSync).
func _run(method: StringName, args: Array) -> void:
	var s := _sync()
	if s:
		s.run_on(self, method, args)
	else:
		callv(method, args)


# --- Blocks ------------------------------------------------------------------

## The local player blocked a hit from `cause`: tell the host, which runs the attacker.
func report_blocked(cause: String) -> void:
	if _is_host():
		_host_blocked(my_id(), cause)
	else:
		_ask_blocked.rpc_id(1, cause)


@rpc("any_peer", "reliable")
func _ask_blocked(cause: String) -> void:
	if _is_host():
		_host_blocked(multiplayer.get_remote_sender_id(), cause)


func _host_blocked(id: int, cause: String) -> void:
	hit_blocked.emit(id, cause)
	if not PlayerCombat.practice(cause) and not _first_block_sent:
		_first_block_sent = true
		_run("_earn", [FIRST_BLOCK])


## Every machine: everyone present earns `source` on their own profile (Net
## says "Unlocked: ..." the first time; after that it's a no-op).
func _earn(source: String) -> void:
	var net := get_node_or_null("/root/Net")
	if net:
		net.earn(source, level.get("hud"))
	unlocked.emit(source)


# --- What entities do to players (host) ---------------------------------------

## Throw `body` away from `from` (see PlayerCombat.throw), on whichever machine owns it.
func throw(body: Node, from: Vector3, force: float, damage: float, cause: String = "shredder") -> void:
	if body == players.player:
		_local_combat().throw(from, force, damage, cause)
	elif body is PlayerPuppet and _is_host():
		_throw.rpc_id(body.peer_id, from, force, damage, cause)


@rpc("authority", "reliable")
func _throw(from: Vector3, force: float, damage: float, cause: String) -> void:
	_local_combat().throw(from, force, damage, cause)


## `grabber` takes hold of `body` (see PlayerCombat.grab).
func grab(body: Node, grabber: Node3D) -> void:
	if body == players.player:
		_local_combat().grab(grabber)
	elif body is PlayerPuppet and _is_host():
		_grab.rpc_id(body.peer_id, level.get_path_to(grabber))


@rpc("authority", "reliable")
func _grab(path: NodePath) -> void:
	var g := level.get_node_or_null(path) as Node3D
	if g:
		_local_combat().grab(g)


## Let go of `body`.
func release(body: Node) -> void:
	if body == players.player:
		_local_combat().release()
	elif body is PlayerPuppet and _is_host():
		_release.rpc_id(body.peer_id)


@rpc("authority", "reliable")
func _release() -> void:
	_local_combat().release()
