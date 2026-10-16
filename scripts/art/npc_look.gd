class_name NpcLook
extends Node
## Gives Rourke (or any NPC built like him) a CharacterRig without touching his
## logic: it hides his greybox body, builds the rig beside it and picks the
## rig's action from his state every frame. Because it only reads `state` and
## position, it animates the same on every co-op machine.
##
##   NpcLook.attach(rourke, CharacterLooks.rourke(), hud)

const SPEAKER := "ROURKE"

var npc: Node3D
var rig: CharacterRig
## The HUD, to tell when he is the one talking (optional).
var hud: Node
var speaker := SPEAKER
var _strike := 0.0
var _was_winding := false


static func attach(target: Node3D, look: Dictionary, the_hud: Node = null) -> NpcLook:
	var n := NpcLook.new()
	n.name = "Look"
	n.npc = target
	n.hud = the_hud
	n.speaker = str(look.get("name", "Rourke")).to_upper()
	var old: Node3D = target.get("_body")
	if old:
		old.visible = false
	n.rig = CharacterRig.build(target, look)
	target.add_child(n)
	return n


func _process(delta: float) -> void:
	if not is_instance_valid(npc):
		return
	rig.play(pick_action(delta))
	# Watch whoever is nearest while he's calm; lock on while he's hunting.
	var p := _nearest_player()
	rig.look_target = (p.global_position + Vector3(0, 1.5, 0)) if p else null


## What the rig should be doing for the NPC's current state.
func pick_action(delta: float = 0.0) -> String:
	var state: int = npc.get("state") if npc.get("state") != null else 0
	var winding: bool = float(npc.get("_windup") if npc.get("_windup") != null else 0.0) > 0.0
	if _was_winding and not winding:
		_strike = 0.3  # the hit lands right after the wind-up
	_was_winding = winding
	_strike = maxf(0.0, _strike - delta)
	match state:
		Rourke.State.STAGGER:
			return "stagger"
		Rourke.State.DOWN:
			return "down"
		Rourke.State.TIED:
			return "tied"
		Rourke.State.DEAD:
			return "dead"
		Rourke.State.CHASE:
			if winding:
				return "windup"
			return "strike" if _strike > 0.0 else "idle"
	return "talk" if is_talking() else "idle"


## True while the HUD subtitle shows one of his lines.
func is_talking() -> bool:
	if not hud:
		return false
	var sub: Variant = hud.get("_subtitle")
	return sub is Label and (sub as Label).text.begins_with(speaker + ":")


func _nearest_player() -> Node3D:
	var best: Node3D = null
	var best_d := 12.0
	for p in npc.get_tree().get_nodes_in_group("player"):
		var n := p as Node3D
		if not n:
			continue
		var d := n.global_position.distance_to(npc.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best
