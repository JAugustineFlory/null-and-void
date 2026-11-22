class_name MusicDirector
extends Node
## Picks the music's mood from what's already true in the building, so a new floor
## gets music without adding calls to its level code:
##   - home base, and the ride up after a floor is done: checkpoint;
##   - inside the ground floor (Level 0, and Floor 10's walk out through the same
##     lobby): the lobby's own hold music, gone wrong once Rourke has; outside it,
##     in the van and the car park, the home theme still;
##   - otherwise calm while Rourke still escorts the crew, uneasy once he's gone;
##   - hunted while a threat on the current floor is loose, chase while it's after
##     someone (see danger()).
## Everything it reads is the same on every machine (the World's wing and checkpoint
## signals, Game.rourke_fate, and NPC state the host replicates), so everyone hears
## the same mood. The one exception is where you're standing on the ground floor: a
## player still out by the van hears the home theme while one inside hears the lobby.

## How long the relief plays after a floor's checkpoint, unless danger cuts in.
const CHECKPOINT_HOLD := 20.0
## How often the floor is checked for threats, in seconds.
const POLL := 0.25
const GROUND_FLOOR := "res://scripts/world/ground_floor.gd"

var world: Node
var _hold := 0.0
var _t := 0.0


## Follows `w` (the World) for as long as it exists. One per game.
static func follow(w: Node) -> MusicDirector:
	var music := Music.of(w)
	var d := music.get_node_or_null("Director") as MusicDirector
	if d == null:
		d = MusicDirector.new()
		d.name = "Director"
		music.add_child(d)
	d.world = w
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
	for npc in get_tree().get_nodes_in_group("npc"):
		if here.is_ancestor_of(npc):
			worst = maxi(worst, danger(npc))
	if worst == 2:
		return "chase"
	if worst == 1:
		return "hunted"
	if _hold > 0.0:
		return "checkpoint"
	var game := get_node_or_null("/root/Game")
	var turned: bool = game != null and game.rourke_fate != "unknown"
	var ground := ground_floor(here)
	if ground:
		var me: Node3D = world.get("player")
		if me and indoors(ground.to_local(me.global_position)):
			return "lobby_late" if turned else "lobby"
		if here.get("wing_id") == "level_0":
			return "checkpoint"  # the van and the car park keep the home theme
	return "uneasy" if turned else "calm"


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
	_t += delta
	if _t < POLL:
		return
	_t = 0.0
	var music := get_parent() as Music
	var mood := pick()
	if music and music.mood != mood:
		music.set_mood(mood)


func _on_checkpoint(_wing_id: String) -> void:
	_hold = CHECKPOINT_HOLD
