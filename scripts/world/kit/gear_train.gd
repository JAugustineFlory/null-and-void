class_name GearTrain
extends KitPiece
## Open gears in a housing: a shutter's motor drive, a dumbwaiter's winch, an old
## clock. A screwdriver pushed between the teeth jams them, and whatever they drive
## (`gate`, a Shutter) stops dead where it is. The screwdriver stays in the teeth
## until someone pulls it out, which frees the gears and takes the screwdriver. A
## train can start jammed, a screwdriver already stuck in it ("remove a screwdriver
## from a gear system").

## Every machine: the gears jammed (true) or were freed, by player `peer_id`.
signal jam_changed(jammed: bool, peer_id: int)

## What jams it, and what you get back.
var jam_item := "screwdriver"
var jammed := false
## What the gears drive: it stops while they're jammed. A Shutter, or anything with
## `openness` (0..1) and `set_jammed(on, at)`.
var gate: Node
## Turns per second of the big gear.
var turn_speed := 0.35
var _gears: Array[Node3D] = []
var _stuck: Node3D
var _hum: AudioStreamPlayer3D


## A gear train in a 0.8 x 0.6 m housing on a wall, facing +z, centred at `pos`.
static func make(parent: Node, id: String, pos: Vector3, facing_deg := 0.0, drives: Node = null, starts_jammed := false, jammed_with := "screwdriver") -> GearTrain:
	var g := GearTrain.new()
	g.name = "Gears_" + id
	g.position = pos
	g.rotation_degrees.y = facing_deg
	g.kind = "clatter"
	g.gate = drives
	g.jam_item = jammed_with
	g._shape(Vector3(0.8, 0.6, 0.16))
	KitPiece._box(g, Vector3(0, 0, -0.06), Vector3(0.8, 0.6, 0.04), Color(0.22, 0.23, 0.22))  # backplate
	for spec in [[Vector3(-0.15, 0.0, 0.0), 0.22, 1.0], [Vector3(0.18, 0.08, 0.0), 0.14, -1.6]]:
		g._gears.append(g._gear(spec[0], spec[1], spec[2]))
	# What jams it, wedged where the teeth meet and sticking out.
	g._stuck = Node3D.new()
	g._stuck.name = "Stuck"
	g._stuck.position = Vector3(0.04, 0.05, 0.05)
	g._stuck.rotation_degrees = Vector3(0, -60, 25)
	g.add_child(g._stuck)
	if jammed_with == "screwdriver":
		KitPiece._box(g._stuck, Vector3(0, 0, 0.0), Vector3(0.008, 0.008, 0.12), Color(0.7, 0.7, 0.72))
		KitPiece._box(g._stuck, Vector3(0, 0, 0.1), Vector3(0.03, 0.03, 0.1), Color(0.95, 0.75, 0.1))
	else:
		var m := GearPickup.model_of(jammed_with)
		m.rotation_degrees = Vector3(90, 0, 0)
		g._stuck.add_child(m)
	parent.add_child(g)
	g.add_to_group("interactable")
	g._hum = Sfx.loop(g, "gears", Vector3.ZERO)
	g._set_state(starts_jammed)
	return g


## One gear: a disc with teeth, turning about z at `rate` times the big one's speed.
func _gear(at: Vector3, radius: float, rate: float) -> Node3D:
	var gear := Node3D.new()
	gear.position = at
	gear.set_meta("rate", rate)
	add_child(gear)
	var disc := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = radius
	cy.bottom_radius = radius
	cy.height = 0.04
	cy.radial_segments = 16
	disc.mesh = cy
	disc.rotation_degrees.x = 90
	disc.material_override = Greybox.mat(Color(0.55, 0.5, 0.38), 0.0, 0.4)
	gear.add_child(disc)
	var teeth := int(radius * 60)
	for i in teeth:
		var a := TAU * i / teeth
		var tooth := KitPiece._box(gear, Vector3(cos(a), sin(a), 0) * (radius + 0.015), Vector3(0.03, 0.025, 0.04), Color(0.5, 0.45, 0.34))
		tooth.rotation.z = a
	KitPiece._box(gear, Vector3(0, 0, 0.025), Vector3(0.04, 0.04, 0.02), Color(0.2, 0.2, 0.2))  # the axle
	return gear


func _process(delta: float) -> void:
	if jammed:
		return
	for gear in _gears:
		gear.rotation.z += TAU * turn_speed * float(gear.get_meta("rate")) * delta


func prompt_for(hand: Dictionary) -> String:
	var it := KitWords.item(jam_item)
	if jammed:
		return KitWords.say("jammed_already", [it]) if KitPiece.carries(hand, jam_item) else KitWords.say("unjam", [it])
	return KitWords.say("jam", [it]) if KitPiece.carries(hand, jam_item) else KitWords.say("turning")


## Jam it with one you carry, or pull it out if you've a free hand for one.
func can_use(hand: Dictionary) -> bool:
	return KitPiece.has_room(hand, jam_item) if jammed else KitPiece.carries(hand, jam_item)


func decide(peer: int, _hand: Dictionary) -> void:
	play("_jam", [peer, not jammed, float(gate.get("openness")) if gate else 0.0])


## Every machine: `peer` jams the gears (`on`) or frees them; the gate stops at `at`.
func _jam(peer: int, on: bool, at: float) -> void:
	if on == jammed:
		return
	if on:
		_take(peer, jam_item)
	else:
		_give(peer, jam_item)
	_set_state(on, at)
	_sound_for(peer, "gear_jam" if on else "gear_free")
	jam_changed.emit(on, peer)


func _set_state(on: bool, at := -1.0) -> void:
	jammed = on
	_stuck.visible = on
	if is_instance_valid(_hum):
		_hum.stream_paused = on
	if gate:
		gate.set_jammed(on, at if at >= 0.0 else float(gate.get("openness")))
