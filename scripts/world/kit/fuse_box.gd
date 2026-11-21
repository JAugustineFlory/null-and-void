class_name FuseBox
extends Node3D
## A grey fuse box on a wall, its door open: a row of labelled fuses, one circuit
## each ("STAIR DOOR", "VENDING"). A blown fuse kills its circuit. Fit a fuse you
## carry, or pull a working one from a circuit nobody needs to get one: that's the
## choice (lights or the door). Nothing to know beyond reading the labels.
## The floor wires each circuit to what it powers (circuit_changed, is_live).

## Every machine: `circuit` went live or dead, by player `peer_id`.
signal circuit_changed(circuit: String, live: bool, peer_id: int)

const SLOT_GAP := 0.16
var slots: Array[FuseSlot] = []


## A box at `pos` (on a wall, facing +z) with one slot per label in `circuits`; the
## slots in `blown` (indexes) start with a dead fuse, `empty` with none.
static func make(parent: Node, id: String, pos: Vector3, facing_deg: float, circuits: Array, blown: Array = [], empty: Array = []) -> FuseBox:
	var box := FuseBox.new()
	box.name = "FuseBox_" + id
	box.position = pos
	box.rotation_degrees.y = facing_deg
	parent.add_child(box)
	var w := circuits.size() * SLOT_GAP + 0.12
	KitPiece._box(box, Vector3(0, 0, -0.05), Vector3(w, 0.42, 0.1), Color(0.55, 0.57, 0.55))  # the case
	KitPiece._box(box, Vector3(-w / 2.0 - 0.01, 0, 0.06), Vector3(0.015, 0.42, w * 0.6), Color(0.5, 0.52, 0.5)).rotation_degrees.y = -70  # door, swung open
	for i in circuits.size():
		var x := (i - (circuits.size() - 1) / 2.0) * SLOT_GAP
		var state := "blown" if blown.has(i) else ("empty" if empty.has(i) else "good")
		var slot := FuseSlot.make(box, i, Vector3(x, 0.04, 0.02), String(circuits[i]), state)
		box.slots.append(slot)
		Greybox.label(box, Vector3(x, -0.13, 0.004), String(circuits[i]), 22, Color(0.08, 0.08, 0.08))
	return box


## Which of `count` slots is blown this run, for `key` (KitPiece.seeded).
static func seeded_blown(key: String, count: int) -> int:
	return KitPiece.seeded(key, count)


func is_live(circuit: String) -> bool:
	for s in slots:
		if s.circuit == circuit:
			return s.state == "good"
	return false


func slot(circuit: String) -> FuseSlot:
	for s in slots:
		if s.circuit == circuit:
			return s
	return null
