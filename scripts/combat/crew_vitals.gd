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
## Only a first-aid kit gets anyone up (Augustine, 2026-11-18: "No more free
## revives"): a teammate with one in their hands stands by you for KIT_TIME. Left
## down too long you pass out (Normal) or die (hard mode, Game.hard_mode,
## plan/hard-mode.md): either way you're no longer counted as there (`is_present`),
## so the rest of the crew can go on without you, and you come to at the start of
## the next floor. When everyone's down or out, the floor's rule applies: back to
## the checkpoint on Normal, the floor over again in hard mode.
##
## Entities run on the host. To hurt, throw or grab a player, they go through
## here (or the player's take_damage), and it reaches the machine that owns them.

## Every machine: the last one standing went down (everyone else is down or out).
signal crew_down(cause: String)
## Host: a player's block caught a hit from `cause` (the attacker can recoil).
signal hit_blocked(peer_id: int, cause: String)
## Every machine, hard mode: `peer_id` died (or rejoined dead: cause "ghost"). They
## stay in `downed` and `dead` until the next floor.
signal died(peer_id: int, cause: String)
## Every machine: someone left down too long passed out (Normal). Like the dead,
## they're no longer counted as there until a kit or the next floor.
signal passed_out(peer_id: int)
## Every machine: someone dead or out cold came to at the start of a new floor.
signal came_back(peer_id: int)
## Every machine, hard mode: everyone's down; the floor's about to start over.
signal wiped

## Patching someone up with a first-aid kit takes this long, standing by them
## (and patching yourself up, holding still): Augustine 2026-11-18.
const KIT_TIME := 4.0
## Walk further than this from them and you stop.
const REVIVE_RANGE := 2.5
## Hard mode, everyone down: approved by Augustine 2026-11-18, word for word
## (spelled so at his ask, 01:23Z). Then the screen fades and the floor starts over.
const WIPE_NOTICE := "Everyone's down. Déjà vu?"
const WIPE_FADE := 3.0
## Hard mode unlocks (names DRAFT, plan/hard-mode.md): a floor cleared, for whoever's
## still alive; cleared with nobody dead, for everyone; cleared with the dead kept
## silent, for the living; the last floor cleared, for the living.
const HARD_FLOOR := "achievement:hard_floor"
const HARD_FLOOR_ALL := "achievement:hard_floor_all"
const HARD_WATCH_ONLY := "achievement:hard_watch_only"
const HARD_GAME := "achievement:hard_game"
## A player's first block in a real fight: the High-tops, for that player only
## (plan/approvals/unlocks.md). The punch bag's practice swings never count.
const FIRST_BLOCK := "achievement:first_block"

var level: Node
var players: Node  # NetPlayers
## peer id -> what put them down.
var downed := {}
## Peer ids of the downed who have passed out (still in `downed`).
var unconscious := {}
## Hard mode: peer id -> what killed them (still in `downed`, until the next floor).
var dead := {}
## Peer id -> {"by": who's helping them up, "left": seconds to go, "total": of how
## many, "kit": with a first-aid kit}.
var reviving := {}
## Hard mode: the floor's starting over (the fade is running).
var wiping := false
## Tests: called on the host in place of Net's restart, with `new_run`.
var restart_with: Callable
var _fade: ColorRect
## The local player's progress helping someone up (local player only).
var _revive_bar: ProgressBar
## Host: peer ids whose first-block unlock has gone out from this level already.
var _first_blocks := {}


static func create(for_level: Node, net_players: Node) -> CrewVitals:
	var c := CrewVitals.new()
	c.name = "Crew"
	c.level = for_level
	c.players = net_players
	for_level.add_child(c)
	return c


func _ready() -> void:
	# The World: a floor cleared, and the next one entered (hard mode's rewards,
	# and the dead coming back).
	if level and level.has_signal("checkpoint_reached"):
		level.checkpoint_reached.connect(_on_floor_cleared)
	if level and level.has_signal("wing_entered"):
		level.wing_entered.connect(_on_floor_entered)


static func _game() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("Game") if loop else null


## Hard mode, set by the host in the lobby for the whole run.
static func hard_mode() -> bool:
	var g := _game()
	return g != null and g.get("hard_mode") == true


func is_dead(id: int) -> bool:
	return dead.has(id)


## Everyone in the game who isn't dead (down counts as living).
func living_ids() -> Array:
	return players.all_ids().filter(func(i): return not dead.has(i)) if players else []


## Down, and not dead: someone can still bring them round.
func can_help(id: int) -> bool:
	return downed.has(id) and not dead.has(id)


## Counted as there, for "everyone present" (stairs, exits, traps): not dead and
## not passed out. Down but still awake counts: a kit can still reach them.
func is_present(id: int) -> bool:
	return not dead.has(id) and not unconscious.has(id)


func present_ids() -> Array:
	return players.all_ids().filter(is_present) if players else []


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
	elif dead.has(id):
		return  # dead stays down until the next floor
	else:
		downed.erase(id)
		unconscious.erase(id)
		_end_revive(id)
	var body: Node = players.puppet(id)
	if body is PlayerPuppet:
		body.set_downed(is_down)


func _all_down(cause: String) -> void:
	crew_down.emit(cause)
	level.on_crew_down(cause)


## The default end of a crew going down: everyone who's down comes to at the
## checkpoint (the level's on_player_died). In hard mode, the floor starts over.
func send_everyone_back() -> void:
	if hard_mode():
		wipe()
		return
	var c := _local_combat()
	if c and c.down:
		c.die()


## The prompt on a downed teammate's body with empty hands: none. Only a first-aid
## kit brings anyone round (FirstAidCabinet.teammate_prompt).
func revive_prompt(_id: int) -> String:
	return ""


## The local player patches teammate `id` up with a first-aid kit (`instant`):
## KIT_TIME standing by them, even if they've passed out, to full health. Without
## a kit nothing happens.
func revive(id: int, health: float = PlayerCombat.REVIVE_HEALTH, instant: bool = false) -> void:
	if CrewVitals.is_down(players.player):
		return
	if _is_host():
		_host_revive(id, my_id(), health, instant)
	else:
		_ask_revive.rpc_id(1, id, health, instant)


@rpc("any_peer", "reliable")
func _ask_revive(id: int, health: float, instant: bool) -> void:
	if _is_host():
		_host_revive(id, multiplayer.get_remote_sender_id(), health, instant)


## Host: a first-aid kit (`instant`) takes KIT_TIME of `by` standing by them; the
## dead stay dead, and without a kit nothing happens.
func _host_revive(id: int, by: int, _health: float = PlayerCombat.REVIVE_HEALTH, instant: bool = false) -> void:
	if not instant or not can_help(id) or reviving.has(id):
		return
	_run("_begin_revive", [id, by, true])


## `kit_by`: who brought them round with their first-aid kit (0: nobody's, as when
## the stairs bring round whoever's down on them).
func _revived(id: int, health: float = PlayerCombat.REVIVE_HEALTH, kit_by: int = 0) -> void:
	_set_down(id, false, "")  # (ends any revive in progress)
	if id == my_id():
		var c := _local_combat()
		if c:
			c.revive(health)
	if kit_by != 0:
		FirstAidCabinet.patched(self, id, kit_by)


# --- Passing out --------------------------------------------------------------

## The local player passed out (down too long).
func report_unconscious() -> void:
	if _is_host():
		_host_unconscious(my_id())
	else:
		_ask_unconscious.rpc_id(1)


@rpc("any_peer", "reliable")
func _ask_unconscious() -> void:
	if _is_host():
		_host_unconscious(multiplayer.get_remote_sender_id())


func _host_unconscious(id: int) -> void:
	if downed.has(id) and not unconscious.has(id):
		_run("_set_unconscious", [id])


func _set_unconscious(id: int) -> void:
	unconscious[id] = true
	passed_out.emit(id)


func _begin_revive(id: int, by: int, kit: bool = true) -> void:
	reviving[id] = {"by": by, "left": KIT_TIME, "total": KIT_TIME, "kit": kit}
	if by == my_id():
		_show_revive_bar(true)


func _stop_revive(id: int) -> void:
	_end_revive(id)


func _end_revive(id: int) -> void:
	var r: Dictionary = reviving.get(id, {})
	reviving.erase(id)
	if r.get("by", -1) == my_id():
		_show_revive_bar(false)


## The body on this machine for peer `id`: the local player or a puppet.
func _body(id: int) -> Node3D:
	if players == null:
		return null
	return players.player if id == my_id() else players.puppet(id)


## Every machine counts revives down (for the bar); the host decides when one
## finishes or stops (the helper walked off, or went down themselves).
func _physics_process(delta: float) -> void:
	if reviving.is_empty():
		return
	for id in reviving.keys():
		var r: Dictionary = reviving[id]
		r.left = maxf(0.0, r.left - delta)
		if r.by == my_id():
			_show_revive_bar(true, 1.0 - r.left / r.total)
		if not _is_host():
			continue
		var helper := _body(r.by)
		var body := _body(id)
		if helper == null or body == null or CrewVitals.is_down(helper) \
				or helper.global_position.distance_to(body.global_position) > REVIVE_RANGE:
			_run("_stop_revive", [id])
		elif r.left <= 0.0:
			_run("_revived", [id, PlayerCombat.MAX_HEALTH, r.by])


## A bar under the crosshair while you help someone up (no words).
func _show_revive_bar(on: bool, progress: float = 0.0) -> void:
	var hud: Node = players.player.get("hud") if players and players.player else null
	if hud == null:
		return
	if _revive_bar == null:
		_revive_bar = ProgressBar.new()
		_revive_bar.name = "ReviveBar"
		_revive_bar.show_percentage = false
		_revive_bar.max_value = 1.0
		_revive_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_revive_bar.anchor_left = 0.5
		_revive_bar.anchor_right = 0.5
		_revive_bar.anchor_top = 0.5
		_revive_bar.anchor_bottom = 0.5
		_revive_bar.offset_left = -70
		_revive_bar.offset_right = 70
		_revive_bar.offset_top = 48
		_revive_bar.offset_bottom = 56
		hud.add_child(_revive_bar)
	_revive_bar.visible = on
	_revive_bar.value = progress


## Host: run on every machine (or just here, with no LevelSync).
func _run(method: StringName, args: Array) -> void:
	var s := _sync()
	if s:
		s.run_on(self, method, args)
	else:
		callv(method, args)


# --- Hard mode: dying, the floor starting over, coming back -----------------

## The local player died (hard mode: down too long, or a fatal fall).
func report_dead(cause: String) -> void:
	if _is_host():
		_host_dead(my_id(), cause)
	else:
		_ask_dead.rpc_id(1, cause)


@rpc("any_peer", "reliable")
func _ask_dead(cause: String) -> void:
	if _is_host():
		_host_dead(multiplayer.get_remote_sender_id(), cause)


## Host: `id` is dead on every machine. Co-op calls this for a dead player who
## rejoins (cause "ghost"): they come back in watching.
func mark_dead(id: int, cause: String = "ghost") -> void:
	if _is_host():
		_host_dead(id, cause)


func _host_dead(id: int, cause: String) -> void:
	if dead.has(id):
		return
	_run("_set_dead", [id, cause])
	if not wiping and players.all_ids().all(func(i): return downed.has(i)):
		_run("_all_down", [cause])


func _set_dead(id: int, cause: String) -> void:
	dead[id] = cause
	downed[id] = cause
	unconscious.erase(id)
	_end_revive(id)
	var body: Node = players.puppet(id) if players else null
	if body is PlayerPuppet:
		body.set_downed(true)
	died.emit(id, cause)


## Hard mode, everyone's down (every machine): "Everyone's down. Déjà vu?", the
## screen fades, and the host starts the floor over (or the whole run, if the
## lobby said so).
func wipe() -> void:
	if wiping:
		return
	wiping = true
	wiped.emit()
	var p: Node = players.player if players else null
	var hud: Node = p.get("hud") if p else null
	if p:
		p.input_locked = true
	if hud:
		hud.notice(WIPE_NOTICE, WIPE_FADE + 2.0)
		_fade = ColorRect.new()
		_fade.name = "WipeFade"
		_fade.color = Color(0, 0, 0, 0)
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var words = hud.get("_notice")
		if words is Control:
			words.add_sibling(_fade)
			words.get_parent().move_child(_fade, words.get_index())  # the words stay on top
		else:
			hud.add_child(_fade)
		_fade.create_tween().tween_property(_fade, "color:a", 1.0, WIPE_FADE)
	await get_tree().create_timer(WIPE_FADE + 0.5).timeout
	if _is_host():
		_restart()


## Host: start the floor over through Co-op's restart (every machine reloads it as
## it was when the crew walked in, notebooks kept), or the whole run with a new seed.
func _restart() -> void:
	var g := _game()
	var new_run: bool = g != null and g.get("wipe_new_run") == true
	if restart_with.is_valid():
		restart_with.call(new_run)
		return
	var net := get_node_or_null("/root/Net")
	if net and new_run and net.has_method("restart_run"):
		net.restart_run()
	elif net and net.has_method("restart_floor"):
		# Notebooks kept (plan 6A), once Co-op's restart takes that flag.
		if net.get_method_argument_count("restart_floor") > 0:
			net.call("restart_floor", true)
		else:
			net.restart_floor()
	else:
		# No restart to call yet (Co-op's lands separately): back to the checkpoint.
		_run("_back_after_wipe", [])


func _back_after_wipe() -> void:
	wiping = false
	if _fade:
		_fade.queue_free()
		_fade = null
	dead.clear()  # now everyone down can come to
	var c := _local_combat()
	if c and c.down:
		c.die()
	elif players and players.player:
		players.player.input_locked = false


## Hard mode, every machine: a floor's cleared. The host hands out its rewards.
func _on_floor_cleared(wing_id: String) -> void:
	if not hard_mode() or not _is_host() or players == null:
		return
	var living := living_ids()
	_unlock(living, HARD_FLOOR)
	if dead.is_empty():
		_unlock(living, HARD_FLOOR_ALL)
	var g := _game()
	if g and g.get("dead_watch_only") == true:
		_unlock(living, HARD_WATCH_ONLY)
	if level.has_method("route_index"):
		var route: Array = level.get_script().get_script_constant_map().get("ROUTE", [])
		if level.route_index(wing_id) == route.size() - 1:
			_unlock(living, HARD_GAME)


func _unlock(ids: Array, source: String) -> void:
	for id in ids:
		_earn_for(id, source)


## Every machine: the crew's on a new floor, and anyone still down, out cold or
## dead comes to at its start.
func _on_floor_entered(wing: Node) -> void:
	for id in downed.keys():
		_came_back(id, wing)


func _came_back(id: int, wing: Node = null) -> void:
	dead.erase(id)
	downed.erase(id)
	unconscious.erase(id)
	_end_revive(id)
	if id == my_id():
		var c := _local_combat()
		var p: Node = players.player
		if c:
			c.reset()
		p.health = PlayerCombat.MAX_HEALTH
		if wing and wing.has_method("player_spawn"):
			p.respawn(wing.player_spawn(NetPlayers.index_of(id, multiplayer)))
	else:
		var body: Node = players.puppet(id) if players else null
		if body is PlayerPuppet:
			body.set_downed(false)
	came_back.emit(id)


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
	if not PlayerCombat.practice(cause) and not _first_blocks.has(id):
		_first_blocks[id] = true
		_earn_for(id, FIRST_BLOCK)


## Host: just player `id` earns `source`, on their own machine; teammates get
## nothing. With no LevelSync (a bare world), the one player here earns it.
func _earn_for(id: int, source: String) -> void:
	var s := _sync()
	if s:
		s.unlock_for([id], source)
		return
	var net := get_node_or_null("/root/Net")
	if net:
		net.earn(source, level.get("hud"))


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
