class_name PatchPanel
extends Node3D
## A patch panel on a wall: a top row of ports, each with a short lead, and a bottom
## row of jacks, both labelled ("RM 104", "LOBBY"). The jacks are in another order,
## picked by the run's seed. Take a lead, plug it into the jack with the same label,
## and that line works. Reading labels is all it needs. The floor says which labels
## matter (`required`) and wires what each line does (patched, is_linked).

## Every machine: the lead from port `port_label` went into jack `jack_label` ("" when
## it came out), by player `peer_id`.
signal patched(port_label: String, jack_label: String, peer_id: int)
## Every machine: every required line is patched to its own label.
signal solved

const GAP := 0.14
## Port and jack labels, one each.
var labels: Array = []
## Which label sits at each jack position, left to right.
var jack_labels: Array = []
## Labels that must link for `solved`; all of them if empty.
var required: Array = []
## Port index -> jack index, for leads plugged in.
var plugged := {}
## Peer id -> port index of the lead they're holding.
var holding := {}
var ports: Array[PatchPoint] = []
var jacks: Array[PatchPoint] = []
var is_solved := false
var _leads := {}


## A panel at `pos` (facing +z) with one port and one jack per label in `port_labels`.
## The jacks are shuffled for `key` by the run's seed (never left in the ports' order).
static func make(parent: Node, id: String, pos: Vector3, facing_deg: float, port_labels: Array, key: String = "") -> PatchPanel:
	var p := PatchPanel.new()
	p.name = "Patch_" + id
	p.position = pos
	p.rotation_degrees.y = facing_deg
	p.labels = port_labels.duplicate()
	p.jack_labels = shuffled(port_labels, key if key != "" else id)
	parent.add_child(p)
	var w := port_labels.size() * GAP + 0.1
	KitPiece._box(p, Vector3(0, 0, -0.03), Vector3(w, 0.5, 0.04), Color(0.13, 0.13, 0.15))
	for i in port_labels.size():
		var x := (i - (port_labels.size() - 1) / 2.0) * GAP
		p.ports.append(PatchPoint.make(p, false, i, Vector3(x, 0.15, 0.0)))
		Greybox.label(p, Vector3(x, 0.22, 0.002), String(p.labels[i]), 18, Color(0.92, 0.9, 0.8))
		p.jacks.append(PatchPoint.make(p, true, i, Vector3(x, -0.15, 0.0)))
		Greybox.label(p, Vector3(x, -0.22, 0.002), String(p.jack_labels[i]), 18, Color(0.92, 0.9, 0.8))
		p._leads[i] = KitPiece._box(p, Vector3.ZERO, Vector3(0.012, 0.012, 1.0), Color(0.85, 0.75, 0.15) if i % 2 == 0 else Color(0.2, 0.45, 0.85))
		p._draw_lead(i)
	return p


## `items` in an order picked for `key` by the run's seed, never the same order
## (so a jack is never found under its own port by accident).
static func shuffled(items: Array, key: String) -> Array:
	var out := items.duplicate()
	if out.size() < 2:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = KitPiece.seeded(key, 1 << 30)
	while out == items:
		for i in range(out.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = out[i]
			out[i] = out[j]
			out[j] = tmp
	return out


func is_linked(label: String) -> bool:
	var port := labels.find(label)
	return plugged.has(port) and jack_labels[plugged[port]] == label


## Who holds the lead from `port`: their peer id, or -1.
func held_by(port: int) -> int:
	for peer in holding:
		if holding[peer] == port:
			return peer
	return -1


func jack_lead(jack: int) -> int:
	for port in plugged:
		if plugged[port] == jack:
			return port
	return -1


# --- Every machine (PatchPoint plays these) -------------------------------------

## `peer` picks up the lead from `port` (unplugging it), letting go of any they hold.
func _hold(peer: int, port: int) -> void:
	if holding.has(peer):
		_drop(peer)
	if plugged.has(port):
		plugged.erase(port)
		patched.emit(labels[port], "", peer)
	holding[peer] = port
	_draw_lead(port)
	_check()


## `peer` lets go of the lead they hold: it hangs from its port.
func _drop(peer: int) -> void:
	if not holding.has(peer):
		return
	var port: int = holding[peer]
	holding.erase(peer)
	_draw_lead(port)


## `peer` plugs the lead they hold into `jack`; one already there comes out.
func _plug(peer: int, jack: int) -> void:
	if not holding.has(peer):
		return
	var port: int = holding[peer]
	holding.erase(peer)
	var there := jack_lead(jack)
	if there >= 0:
		plugged.erase(there)
		_draw_lead(there)
	plugged[port] = jack
	_draw_lead(port)
	patched.emit(labels[port], jack_labels[jack], peer)
	_check()


func _check() -> void:
	var need := required if not required.is_empty() else labels
	var now := need.all(func(l): return is_linked(l))
	if now and not is_solved:
		is_solved = true
		solved.emit()
	elif not now:
		is_solved = false


## A lead plugged in runs from its port to its jack; loose, it hangs down a little;
## held, it's in someone's hand (out of sight).
func _draw_lead(port: int) -> void:
	var lead: MeshInstance3D = _leads.get(port)
	if lead == null:
		return
	var from := ports[port].position + Vector3(0, 0, 0.03)
	var to := from + Vector3(0, -0.1, 0.02)
	lead.visible = held_by(port) == -1
	if plugged.has(port):
		to = jacks[plugged[port]].position + Vector3(0, 0, 0.03)
	lead.position = (from + to) / 2.0 + Vector3(0, 0, 0.02)
	var dir := to - from
	var up := Vector3.BACK if absf(dir.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
	lead.basis = Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1, 1, dir.length()))
