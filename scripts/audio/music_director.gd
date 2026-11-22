class_name MusicDirector
extends Node
## Picks the music's mood from what's already true in the building, so a new floor
## gets music without adding calls to its level code:
##   - home base, and the ride up after a floor is done: checkpoint;
##   - inside the ground floor (Level 0, and Floor 10's walk out through the same
##     lobby): the lobby's own hold music, gone wrong once Rourke has; outside it,
##     in the van and the car park, the home theme still;
##   - otherwise calm while Rourke still escorts the crew, uneasy once he's gone;
##   - hunted while a threat on the current floor is loose, close when one is near
##     you, chase while it's after someone (see danger());
##   - alarm while the floor's alarm is going (Floor 10's breakers out of place, a
##     plant room's gas suppression counting down on B2);
##   - sealed for a while after the building locks a door near you (a door in the
##     `doors` table going locked: floor G's lockdown, B2's plant rooms as the gas
##     arms), with a sting as it shuts you in.
## Everything it reads is the same on every machine (the World's wing and checkpoint
## signals, Game.rourke_fate, and NPC state the host replicates), so everyone hears
## the same mood. The exceptions are where you are: a threat close to you is close for
## you, not for the rest of the crew across the floor, and on the ground floor a
## player still out by the van hears the home theme while one inside hears the lobby.

## How long the relief plays after a floor's checkpoint, unless danger cuts in.
const CHECKPOINT_HOLD := 20.0
## How often the floor is checked for threats, in seconds.
const POLL := 0.25
const GROUND_FLOOR := "res://scripts/world/ground_floor.gd"
## A loose threat closer than this (metres) to you is close.
const NEAR := 8.0
## A door locking closer than this (metres) to you shuts you in.
const SEAL_NEAR := 30.0
## Trying a locked door this close to you (metres) gets a stab from the score, at
## most once every TRIED_GAP seconds.
const TRIED_NEAR := 8.0
const TRIED_GAP := 20.0
## How long the music stays sealed after a door locks, unless danger cuts in.
const SEALED_HOLD := 12.0
## A lockdown locks several doors at once: one sting, not one a door.
const STING_GAP := 6.0
## A door that keeps relocking (B1's sweeps, its freezer latches) shuts you in once,
## not every time: it can't again for this long (seconds).
const DOOR_AGAIN := 120.0

var world: Node
var _hold := 0.0
var _t := 0.0
## Sealed: seconds left, and seconds until another sting may play.
var _sealed := 0.0
var _sting_wait := 0.0
## The current floor's doors' locks as last seen, by door id, and which floor.
var _locks := {}
var _locks_on: Node
## When each door last shut you in (on _clock), by door id.
var _shut_at := {}
var _clock := 0.0
## The sting's player, made the first time a door locks on you.
var sting_player: AudioStreamPlayer
## Trying a locked door: its own short sting, and the wait before it can play again.
var tried_player: AudioStreamPlayer
var _tried_wait := 0.0


## Follows `w` (the World) for as long as it exists. One per game.
static func follow(w: Node) -> MusicDirector:
	var music := Music.of(w)
	var d := music.get_node_or_null("Director") as MusicDirector
	if d == null:
		d = MusicDirector.new()
		d.name = "Director"
		music.add_child(d)
	d.world = w
	SfxRooms.follow(w)  # the reverb follows the room you're standing in
	SfxBeds.follow(w)  # and each floor's own room tone plays under everything
	if not w.checkpoint_reached.is_connected(d._on_checkpoint):
		w.checkpoint_reached.connect(d._on_checkpoint)
	return d


## How dangerous `npc` is right now: 0 not at all, 1 loose (hunted), 2 after
## someone (chase). Reads only what its level replicates to every machine.
static func danger(npc: Node) -> int:
	if npc is Watcher:
		# It only moves while nobody's looking: unseen, it's coming.
		return 0 if not npc.active else (1 if npc.seen else 2)
	if npc is Shredder:
		if not npc.active or npc.state == "dormant":
			return 0
		return 2 if npc.state in ["investigating", "grabbing"] else 1
	if npc is Custodian:
		match npc.state:
			"hunting", "dragging": return 2
			"stunned", "recharging": return 1
		return 0
	if npc is Mimic:
		return 1 if npc.visible and npc.state in ["seated", "standing"] else 0
	if npc is Rourke:
		return 2 if npc.state == Rourke.State.CHASE else 0
	return 0


## The mood right now, from the current floor's threats and the story so far.
func pick() -> String:
	if not is_instance_valid(world):
		return "silent"
	var here: Node = world.get("current")
	if here == null:
		return "silent"
	if here == world.get("home"):
		return "checkpoint"
	var worst := 0
	var nearest := INF
	var me: Node3D = world.get("player")
	for npc in get_tree().get_nodes_in_group("npc"):
		if here.is_ancestor_of(npc):
			var level := danger(npc)
			worst = maxi(worst, level)
			if level > 0 and me and npc is Node3D:
				nearest = minf(nearest, me.global_position.distance_to(npc.global_position))
	if worst == 2:
		return "chase"
	if nearest < NEAR:
		return "close"
	if alarm_on(here):
		return "alarm"
	if _sealed > 0.0:
		return "sealed"
	if worst == 1:
		return "hunted"
	if _hold > 0.0:
		return "checkpoint"
	var game := get_node_or_null("/root/Game")
	var turned: bool = game != null and game.rourke_fate != "unknown"
	var ground := ground_floor(here)
	if ground:
		if me and indoors(ground.to_local(me.global_position)):
			return "lobby_late" if turned else "lobby"
		if here.get("wing_id") == "level_0":
			return "checkpoint"  # the van and the car park keep the home theme
	return "uneasy" if turned else "calm"


## Is an alarm going on this floor? Reads what the floor already keeps, the same on
## every machine: its `alarm` (Floor 10), or a plant room's suppression armed (B2).
static func alarm_on(here: Node) -> bool:
	if here.get("alarm") == true:
		return true
	var gas = here.get("gas")
	return gas is Dictionary and "armed" in gas.values()


## The ground floor's frame on this floor, in GroundFloor's coordinates: Level 0
## itself, or Floor 10's copy of it (its g_root). Null on any other floor.
static func ground_floor(here: Node) -> Node3D:
	if here.get("wing_id") == "level_0":
		return here as Node3D
	var g = here.get("g_root")
	return g as Node3D if g is Node3D else null


## Is `at` (GroundFloor's coordinates) inside the building, not out in the car park?
## (GroundFloor is loaded when it's needed: naming it here would pull the levels
## into everything that loads the music.)
static func indoors(at: Vector3) -> bool:
	var g: Script = load(GROUND_FLOOR)
	var west: float = g.CORRIDOR.position.x
	var north: float = g.MAILROOM.position.y
	var inside := Rect2(west, north, g.LIFT_HALL.end.x - west, g.LOBBY.end.y - north)
	return inside.has_point(Vector2(at.x, at.z)) and at.y > -1.0 and at.y < g.LOBBY_H + 1.0


func _process(delta: float) -> void:
	_hold = maxf(0.0, _hold - delta)
	_sealed = maxf(0.0, _sealed - delta)
	_sting_wait = maxf(0.0, _sting_wait - delta)
	_tried_wait = maxf(0.0, _tried_wait - delta)
	_clock += delta
	_t += delta
	if _t < POLL:
		return
	_t = 0.0
	watch_doors()
	var music := get_parent() as Music
	var mood := pick()
	if music and music.mood != mood:
		music.set_mood(mood)


func _on_checkpoint(_wing_id: String) -> void:
	_hold = CHECKPOINT_HOLD
	_sealed = 0.0


## Looks at the current floor's doors (they follow the shared `doors` table, so every
## machine sees the same locks) for one that has just gone locked near you. A floor's
## doors as it's first seen are where they start, not something locking.
func watch_doors() -> void:
	var here = world.get("current") if is_instance_valid(world) else null
	var doors = here.get("doors") if is_instance_valid(here) else null
	if not doors is Dictionary:
		return
	var fresh: bool = here != _locks_on
	_locks_on = here
	if fresh:
		_locks.clear()
		_shut_at.clear()
	var me: Node3D = world.get("player")
	var shut_in := false
	for id in doors:
		var door = doors[id]
		if not is_instance_valid(door) or not door is Node3D:
			continue
		var locked: bool = door.get("locked") == true
		if not fresh and _locks.get(id, true) == false and locked:
			var again: bool = _shut_at.has(id) and _clock - _shut_at[id] < DOOR_AGAIN
			if not again and (me == null or me.global_position.distance_to(door.global_position) < SEAL_NEAR):
				shut_in = true
				_shut_at[id] = _clock
		_locks[id] = locked
	if shut_in:
		sealed()


## Someone tried a locked door (SfxDoor, on its "rattle", on every machine). Close
## enough that you heard it, the score answers with a short stab; not again for a while,
## or a crew trying every door on a corridor gets a stab at each.
func door_tried(door: Node3D) -> void:
	var me: Node3D = world.get("player") if is_instance_valid(world) else null
	if _tried_wait > 0.0 or me == null or me.global_position.distance_to(door.global_position) > TRIED_NEAR:
		return
	_tried_wait = TRIED_GAP
	if tried_player == null:
		tried_player = AudioStreamPlayer.new()
		tried_player.name = "Tried"
		tried_player.bus = Sfx.MUSIC
		tried_player.volume_db = Music.BASE_DB - 4.0
		tried_player.stream = MusicSynth.sting("locked")
		add_child(tried_player)
	tried_player.play()


## The building has shut you in: the sting, and the music stays sealed a while.
func sealed() -> void:
	_sealed = SEALED_HOLD
	_hold = 0.0
	if _sting_wait > 0.0:
		return
	_sting_wait = STING_GAP
	if sting_player == null:
		sting_player = AudioStreamPlayer.new()
		sting_player.name = "Sting"
		sting_player.bus = Sfx.MUSIC
		sting_player.volume_db = Music.BASE_DB
		sting_player.stream = MusicSynth.sting("sealed")
		add_child(sting_player)
	sting_player.play()
