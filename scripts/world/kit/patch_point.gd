class_name PatchPoint
extends KitPiece
## A port (with its lead) or a jack on a PatchPanel.

var panel: PatchPanel
var is_jack := false
var index := 0


static func make(on: PatchPanel, jack: bool, i: int, at: Vector3) -> PatchPoint:
	var p := PatchPoint.new()
	p.name = ("Jack%d" if jack else "Port%d") % i
	p.panel = on
	p.is_jack = jack
	p.index = i
	p.position = at
	p.kind = "click"
	p._shape(Vector3(0.1, 0.12, 0.06))
	KitPiece._box(p, Vector3(0, 0, -0.005), Vector3(0.05, 0.04, 0.02), Color(0.05, 0.05, 0.05))  # the socket
	on.add_child(p)
	p.add_to_group("interactable")
	return p


func _label() -> String:
	return String(panel.jack_labels[index] if is_jack else panel.labels[index])


func prompt_for(hand: Dictionary) -> String:
	var me: int = hand.get("peer", 0)
	var mine: int = panel.holding.get(me, -1)
	if is_jack:
		if mine >= 0:
			return KitWords.say("lead_plug", [panel.labels[mine]])
		var lead := panel.jack_lead(index)
		return KitWords.say("lead_unplug", [panel.labels[lead]]) if lead >= 0 else _label()
	if mine == index:
		return KitWords.say("lead_back", [_label()])
	if panel.held_by(index) != -1:
		return KitWords.say("lead_busy", [_label()])
	return KitWords.say("lead_take", [_label()])


func can_use(hand: Dictionary) -> bool:
	var me: int = hand.get("peer", 0)
	var mine: int = panel.holding.get(me, -1)
	if is_jack:
		return mine >= 0 or panel.jack_lead(index) >= 0
	return mine == index or panel.held_by(index) == -1


func decide(peer: int, _hand: Dictionary) -> void:
	var mine: int = panel.holding.get(peer, -1)
	if is_jack:
		if mine >= 0:
			play("_act", [peer, "plug"])
		elif panel.jack_lead(index) >= 0:
			play("_act", [peer, "unplug"])
	elif mine == index:
		play("_act", [peer, "drop"])
	elif panel.held_by(index) == -1:
		play("_act", [peer, "hold"])


## Every machine.
func _act(peer: int, what: String) -> void:
	match what:
		"plug": panel._plug(peer, index)
		"unplug": panel._hold(peer, panel.jack_lead(index))
		"drop": panel._drop(peer)
		"hold": panel._hold(peer, index)
	_sound_for(peer, "patch_plug" if what in ["plug", "unplug"] else "click")
