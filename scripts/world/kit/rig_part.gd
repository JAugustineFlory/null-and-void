class_name RigPart
extends KitPiece
## One thing a TerminalRig is missing, at its spot on the terminal: the keyboard's
## place on the desk, the power socket or the monitor cable at the back. The power
## button has no spot of its own: the terminal's front plays it (TerminalRig).

var rig: TerminalRig
var part := ""


static func make(on: TerminalRig, part_id: String, at: Vector3, size: Vector3) -> RigPart:
	var p := RigPart.new()
	p.name = "Part_" + part_id
	p.rig = on
	p.part = part_id
	p.position = at
	p.kind = {"power": "button", "keyboard": "slot", "power_cord": "slot", "monitor_cable": "slot"}[part_id]
	if size != Vector3.ZERO:
		p._shape(size)
		p.add_to_group("interactable")
	on.add_child(p)
	return p


## Fixed: nothing left to press here.
func done() -> void:
	enabled = false
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = true


func _needs() -> String:
	return TerminalRig.NEEDS.get(part, "")


func prompt_for(hand: Dictionary) -> String:
	if not rig.missing.has(part):
		return ""
	match part:
		"power":
			return KitWords.say("power_on")
		"monitor_cable":
			return KitWords.say("reseat_cable")
		"power_cord":
			return KitWords.say("fit_cord") if KitPiece.carries(hand, _needs()) else KitWords.say("no_cord")
		"keyboard":
			return KitWords.say("fit_keyboard") if KitPiece.carries(hand, _needs()) else KitWords.say("no_keyboard")
	return ""


func can_use(hand: Dictionary) -> bool:
	return rig.missing.has(part) and (_needs() == "" or KitPiece.carries(hand, _needs()))


func decide(peer: int, _hand: Dictionary) -> void:
	play("_done_by", [peer])


## Every machine. The power button with no power behind it only clicks.
func _done_by(peer: int) -> void:
	if part == "power" and not rig.has_power():
		_sound(peer, "button")
		_tell(peer, KitWords.say("no_power"))
		return
	if _needs() != "":
		_take(peer, _needs())
	_sound(peer, "button" if part == "power" else "clunk")
	rig._fix(part, peer)
