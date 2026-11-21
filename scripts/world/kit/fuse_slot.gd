class_name FuseSlot
extends KitPiece
## One fuse in a FuseBox: "good", "blown" (dark, its wire gone) or "empty".
## Pull a good one and you carry it (its circuit dies); fit one you carry into an
## empty or blown slot and its circuit comes back. A blown fuse you swap out is spent.

var box: FuseBox
var index := 0
var circuit := ""
var state := "good"
var _fuse: Node3D
var _wire: MeshInstance3D


static func make(fuse_box: FuseBox, slot_index: int, at: Vector3, label: String, start: String) -> FuseSlot:
	var s := FuseSlot.new()
	s.name = "Fuse%d" % slot_index
	s.box = fuse_box
	s.index = slot_index
	s.circuit = label
	s.position = at
	s.kind = "slot"
	s._shape(Vector3(0.12, 0.2, 0.08))
	KitPiece._box(s, Vector3(0, 0, -0.02), Vector3(0.05, 0.16, 0.03), Color(0.12, 0.12, 0.12))  # the holder
	s._fuse = Node3D.new()
	s._fuse.name = "Cartridge"
	s.add_child(s._fuse)
	var glass := KitPiece._box(s._fuse, Vector3(0, 0, 0.005), Vector3(0.026, 0.09, 0.026), Color(0.8, 0.85, 0.9))
	glass.material_override = Greybox.mat(Color(0.8, 0.85, 0.9), 0.0, 0.15)
	for y in [-0.05, 0.05]:
		KitPiece._box(s._fuse, Vector3(0, y, 0.005), Vector3(0.03, 0.02, 0.03), Color(0.75, 0.72, 0.65))
	s._wire = KitPiece._box(s._fuse, Vector3(0, 0, 0.019), Vector3(0.003, 0.08, 0.003), Color(0.9, 0.85, 0.7))
	fuse_box.add_child(s)
	s.add_to_group("interactable")
	s._show(start)
	return s


func prompt_for(hand: Dictionary) -> String:
	var has := KitPiece.carries(hand, "fuse")
	match state:
		"good":
			return KitWords.say("fuse_works", [circuit]) if has else KitWords.say("fuse_pull", [circuit])
		"blown":
			return KitWords.say("fuse_swap", [circuit]) if has else KitWords.say("fuse_blown", [circuit])
	return KitWords.say("fuse_fit", [circuit]) if has else KitWords.say("fuse_empty", [circuit])


func can_use(hand: Dictionary) -> bool:
	var has := KitPiece.carries(hand, "fuse")
	return (state == "good" and KitPiece.has_room(hand, "fuse")) or (state != "good" and has)


func decide(peer: int, _hand: Dictionary) -> void:
	play("_set_state", [peer, "empty" if state == "good" else "good"])


## Every machine: `peer` pulls the fuse (to "empty") or fits theirs (to "good").
func _set_state(peer: int, to: String) -> void:
	if to == state:
		return
	if to == "empty":
		_give(peer, "fuse")
	else:
		_take(peer, "fuse")
	_show(to)
	_sound(peer, "clunk")
	if box:
		box.circuit_changed.emit(circuit, to == "good", peer)


func _show(to: String) -> void:
	state = to
	_fuse.visible = to != "empty"
	_wire.visible = to == "good"
	var glass := _fuse.get_child(0) as MeshInstance3D
	glass.material_override = Greybox.mat(Color(0.8, 0.85, 0.9) if to == "good" else Color(0.25, 0.22, 0.2), 0.0, 0.15)
