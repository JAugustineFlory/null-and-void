class_name MusicDirector
extends Node
## Picks the music's mood from what's already true in the building, so a new floor
## gets music without adding calls to its level code:
##   - home base, and the ride up after a floor is done: checkpoint;
##   - otherwise calm while Rourke still escorts the crew, uneasy once he's gone;
##   - hunted while a threat on the current floor is loose, chase while it's after
##     someone (see danger()).
## Everything it reads is the same on every machine (the World's wing and checkpoint
## signals, Game.rourke_fate, and NPC state the host replicates), so everyone hears
## the same mood.

## How long the relief plays after a floor's checkpoint, unless danger cuts in.
const CHECKPOINT_HOLD := 20.0
## How often the floor is checked for threats, in seconds.
const POLL := 0.25

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
	return "uneasy" if game and game.rourke_fate != "unknown" else "calm"


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
