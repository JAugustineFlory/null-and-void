class_name PryGrip
extends Interactable
## One door's edge on a stuck lift (PryDoors): hold E on it to pull.

var doors: PryDoors
var index := 0


func get_prompt(player: Node) -> String:
	_seen_shining(player)
	if not enabled or doors == null:
		return ""
	return doors.prompt_for(index, player)


## Asks the host for this grip; you take hold when it says so (PryDoors.set_holders).
func interact(player: Node) -> void:
	if enabled and doors and player is Player and (player as Player).can_grip():
		doors.ask_hold(index, player)
