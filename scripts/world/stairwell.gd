class_name Stairwell
extends RefCounted
## The emergency stairs beside each floor's lift lobby: a badge door with its
## stair placard, and a concrete stairwell behind it. (The framed "IN CASE OF FIRE"
## sign by each lift is the art pass's, in scripts/art/dress_level_*.gd.) After hours the stair doors
## lock (the placard says so), so for now they stay shut; later acts open them.
##     Stairwell.build(self, geo, Vector3(27, 0, 7), 180.0, "G")
## `at` is the doorway, on the floor, in the lobby's wall; the stairwell lies
## behind it, facing `yaw_deg` (0 = toward -z). The caller cuts the doorway out of
## its own wall: a gap DOOR_W wide and DOOR_H tall at `at`.
##
## Inside is a real switchback stair, several storeys of it: from each landing a
## flight goes up along the +x wall to a half-landing at the back, and turns back
## along the -x wall to the next landing up; going down is the same in reverse. A
## concrete wall runs up the middle between the flights. Only this floor's landing
## is real; the others, a storey or two up and down, are copies of the floors
## there, down to their shut doors and floor plates. Floors in the World stand side
## by side, not stacked, so StairLinks joins two stairwells into one flight of
## stairs: walk down past the turn below and you're on the floor below's stairs,
## in the same place, without seeing a thing change (Augustine, v0.9). Floors
## that are several storeys apart are walked storey by storey, past every floor in
## between (count_storeys numbers the landings as you go): their doors are shut
## for the night, a red light on each one's badge reader.
## The door swings out into the lobby, always, so the landing behind it stays
## clear for whoever arrives (v0.8 playtest: players arrived pinned behind it).

## Wide enough for the Custodian (1.0 m across) when it follows the crew down.
const DOOR_W := 1.2
const DOOR_H := 2.2
## How far the stair door's leaf swings out: negative opens it out of the stairwell.
const DOOR_SWING := -90.0

## One storey, landing to landing; half of it is one flight. A whole number of
## navmesh cells (0.25 m, LevelBase), so the bake's grid, which starts at the
## lowest geometry, keeps every floor's walkable surfaces where they were.
const STOREY := 3.75
const HALF := STOREY / 2.0
const RISERS := 10
const RISE := HALF / RISERS
const RUN := 0.28
## The landing runs from the door back to LANDING_Z; the flights from there to
## HALF_Z; the half-landing from there to the back wall's face at BACK_Z.
const LANDING_Z := -1.9
const HALF_Z := LANDING_Z - (RISERS - 1) * RUN
const BACK_Z := -5.7
## Inside the walls, either side of the middle; the middle wall is CORE either side of 0.
const INNER := 1.7
const CORE := 0.1
## Storeys of copied stairs above this floor's landing (the rest go below: `below`).
const ABOVE := 1
const CONCRETE := Color(0.5, 0.5, 0.48)
const DOOR_COLOR := Color(0.35, 0.37, 0.4)


## Builds the stairwell under `geo` and returns its door (locked), which goes on
## the level itself because it moves. `below` is how many storeys of stairs go
## down from here: 2 on most floors, 1 on the floor over G, 0 on G (no way down).
## The copied landings are named for the floors above and below by number; a
## floor whose stairs skip floors (22 down to 18) says so with relabel().
static func build(level: Node3D, geo: Node3D, at: Vector3, yaw_deg: float, floor_label: String, stair := "STAIR 1", below := 2) -> Door:
	var holder := Node3D.new()
	holder.name = "Stairwell"
	holder.position = at
	holder.rotation_degrees.y = yaw_deg
	geo.add_child(holder, true)  # a floor's second is "Stairwell2", so dressing finds it too
	holder.set_meta("stair", stair)
	holder.set_meta("floor", floor_label)
	holder.set_meta("below", below)
	var lo := -below * STOREY
	var hi := (ABOVE + 1) * STOREY
	_shell(holder, lo, hi)
	var flights := []
	for k in range(-below, ABOVE + 1):
		var y0 := k * STOREY
		flights.append(_flight(holder, "StairA", 1, y0, y0 + HALF))
		_slab(holder, Vector3(0, y0 + HALF, (HALF_Z + BACK_Z - 0.2) / 2.0), Vector3(2 * INNER + 0.2, 0.2, HALF_Z - BACK_Z + 0.2), "Floor")
		flights.append(_flight(holder, "StairB", -1, y0 + STOREY, y0 + HALF))
	holder.set_meta("flights", flights)
	for k in range(-below, ABOVE + 2):
		var y0 := k * STOREY
		if k == -below:
			# The bottom of the shaft: a floor under everything.
			_slab(holder, Vector3(0, y0, (BACK_Z - 0.2) / 2.0), Vector3(2 * INNER + 0.2, 0.2, -BACK_Z + 0.2), "Floor")
		else:
			_slab(holder, Vector3(0, y0, LANDING_Z / 2.0), Vector3(2 * INNER + 0.2, 0.2, -LANDING_Z), "Floor")
		var label := Greybox.label(holder, Vector3(-INNER - 0.05, y0 + 2.0, -1.0), "%s\nFLOOR %s" % [stair, _floor_name(floor_label, k)], 64, Color(0.1, 0.1, 0.1), 90)
		label.name = "FloorLabel_%s" % _k_name(k)
		label.set_meta("storey", k)
		if k != 0:
			_copy_door(holder, y0)
	if stair == "STAIR 1":
		add_extra(holder, "13", _taped_plate())  # (Augustine, 2026-11-05: an oddity on 13)

	var door := Door.create(level, "%s-%s" % [stair.replace(" ", "-"), floor_label], holder.transform * Vector3(0, DOOR_H / 2.0, 0), Vector3(DOOR_W, DOOR_H, 0.08))
	door.rotation_degrees.y = yaw_deg
	door.make_hinged(Vector3(-DOOR_W / 2.0, 0, 0), DOOR_SWING)
	door.one_way = true  # out into the lobby, whichever side it's opened from
	door.locked = true
	door.set_meta("stairwell", holder)
	# On the lobby side: the stair's name over the door, and beside it the placard
	# that says why it won't open tonight.
	var face := holder.transform  # papers face the other way from labels (Document.place)
	Greybox.label(geo, face * Vector3(0, DOOR_H + 0.25, 0.12), stair, 48, Color(0.75, 0.1, 0.1), yaw_deg)
	Document.place(geo, face * Vector3(0.9, 1.45, 0.11), yaw_deg + 180.0, "%s placard" % stair, [
		"%s - FLOOR %s" % [stair, floor_label],
		"NO ROOF ACCESS",
		"EXIT TO STREET AT FLOOR G",
		"AFTER 19:00 STAIR DOORS LOCK. RE-ENTRY BY STAFF BADGE ONLY.",
	], false, "laminated", Vector2(0.3, 0.3))
	return door


## The stairwell behind a stair door (from build()).
static func of(door: Door) -> Node3D:
	return door.get_meta("stairwell") if door and door.has_meta("stairwell") else null


## Name the copied landing `k` storeys from this floor (-1 is the one below) for
## the floor it stands in for, plate and all. The stairs from 22 go down to 18.
static func relabel(holder: Node3D, k: int, floor_name: String) -> void:
	var label: Label3D = holder.get_node_or_null("FloorLabel_%s" % _k_name(k))
	if label == null:
		return
	label.text = "%s\nFLOOR %s" % [holder.get_meta("stair", "STAIR 1"), floor_name]
	if label.has_meta("plate"):
		var plate: Node3D = label.get_meta("plate")
		var at := plate.position
		var facing := plate.rotation_degrees.y
		plate.free()
		label.set_meta("plate", ArtKit.landing_number(holder, at, facing, 0 if floor_name == "G" else int(floor_name)))


## Number every landing as if the stairs were `by` storeys further up (-3: three
## floors down): StairLinks counts the floors in between on the same stairs as
## they're walked past. 0 puts the floor's own numbers back.
static func count_storeys(holder: Node3D, by: int) -> void:
	if holder.get_meta("counted", 0) == by:
		return
	holder.set_meta("counted", by)
	var labels := holder.get_children().filter(func(c): return c is Label3D and c.has_meta("storey"))
	for label in labels:  # (relabel swaps the plates, which are children too)
		var k: int = label.get_meta("storey")
		relabel(holder, k, _floor_name(holder.get_meta("floor"), k + by))
	_place_extras(holder)


## Something that belongs on floor `floor_name`'s landing in this stairwell (a
## dropped card, a first-aid cabinet), built as if that landing were this floor's
## own (y 0): it stands on whichever landing is numbered `floor_name` right now
## (count_storeys), and is put away while none is.
static func add_extra(holder: Node3D, floor_name: String, node: Node3D) -> Node3D:
	node.set_meta("extra_floor", floor_name)
	node.set_meta("extra_y", node.position.y)
	holder.add_child(node, true)
	var extras: Array = holder.get_meta("extras", [])
	extras.append(node)
	holder.set_meta("extras", extras)
	_place_extras(holder)
	return node


## The landing numbered `floor_name` now, as storeys from this floor's own (k), or
## null if none of this stairwell's landings is.
static func landing_for(holder: Node3D, floor_name: String) -> Variant:
	var by: int = holder.get_meta("counted", 0)
	for k in range(-int(holder.get_meta("below", 2)), ABOVE + 2):
		if _floor_name(holder.get_meta("floor"), k + by) == floor_name:
			return k
	return null


static func _place_extras(holder: Node3D) -> void:
	for node in holder.get_meta("extras", []):
		if not is_instance_valid(node):
			continue
		var k = landing_for(holder, node.get_meta("extra_floor"))
		var here: bool = k != null
		node.visible = here
		node.process_mode = Node.PROCESS_MODE_INHERIT if here else Node.PROCESS_MODE_DISABLED  # (and out of physics)
		if here:
			node.position.y = node.get_meta("extra_y") + k * STOREY


## Storeys from one floor to another, by their numbers (G is 0).
static func storeys_between(from_floor: String, to_floor: String) -> int:
	return absi(_floor_number(from_floor) - _floor_number(to_floor))


static func _floor_number(floor_label: String) -> int:
	return 0 if floor_label == "G" else int(floor_label)


## Where the `index`th of up to six arrivals stands on the landing (in the space
## `at` is in), three abreast in two rows between the door and the flights: clear
## of both flights, the walls and the door, for the biggest of the crew.
static func landing_slot(at: Vector3, yaw_deg: float, index: int) -> Vector3:
	var holder := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	return holder * Vector3(-1.1 + 1.1 * (index % 3), 0.1, -0.65 - 0.8 * (index / 3))


## Feet at `pos` (world space) are past this floor's turn down: on the half-landing
## below, on its +x half (the side the flight down goes on from), or anywhere lower.
## StairLinks carries whoever steps there onto the floor below's stairs, where
## the half-landing is the one above its landing. The half-landing is shared down
## its middle (the end of the wall between the flights): its -x half stays this
## floor's, so whoever is there is in one stairwell only, and can be found.
## `storeys` moves the turn that many storeys up (negative: down).
static func past_turn_down(holder: Node3D, pos: Vector3, storeys := 0) -> bool:
	var p := holder.global_transform.affine_inverse() * pos - Vector3(0, storeys * STOREY, 0)
	return _in_shaft(p) and p.y > -STOREY - 0.5 and p.y < -HALF + 0.3 and (p.x > CORE or p.y < -HALF - 0.3)


## The same going up: on the half-landing above on its -x half (the flight up's
## side), or anywhere higher.
static func past_turn_up(holder: Node3D, pos: Vector3, storeys := 0) -> bool:
	var p := holder.global_transform.affine_inverse() * pos - Vector3(0, storeys * STOREY, 0)
	return _in_shaft(p) and p.y < STOREY + 0.5 and p.y > HALF - 0.1 and (p.x < -CORE or p.y > HALF + 0.3)


static func _in_shaft(p: Vector3) -> bool:
	return absf(p.x) < INNER + 0.1 and p.z < 0.0 and p.z > BACK_Z - 0.1


## Moves from `upper`'s stairs to the same place one storey down `lower`'s (its
## inverse goes back up): the two stairwells are built alike, so nothing changes.
static func carry_down(upper: Node3D, lower: Node3D) -> Transform3D:
	return lower.global_transform * Transform3D(Basis(), Vector3(0, STOREY, 0)) * upper.global_transform.affine_inverse()


## The landing, as a box in the stairwell's space: where the crew gathers.
static func landing_box() -> AABB:
	return AABB(Vector3(-INNER, -0.1, LANDING_Z), Vector3(2 * INNER, 2.1, -LANDING_Z - 0.2))


static func _floor_name(floor_label: String, k: int) -> String:
	if k == 0:
		return floor_label
	var n := _floor_number(floor_label)
	return "G" if n + k == 0 else str(n + k)


static func _k_name(k: int) -> String:
	return str(k) if k >= 0 else "m%d" % -k


## The walls round the shaft, the wall up the middle between the flights, and the
## roof; the door's gap in the front wall at this floor's landing.
static func _shell(holder: Node3D, lo: float, hi: float) -> void:
	var bottom := lo - 0.2
	var top := hi + 3.2
	var tall := top - bottom
	var mid := (bottom + top) / 2.0
	var deep := -BACK_Z + 0.2
	Greybox.box(holder, Vector3(-INNER - 0.1, mid, -deep / 2.0), Vector3(0.2, tall, deep), CONCRETE, "Wall_w")
	Greybox.box(holder, Vector3(INNER + 0.1, mid, -deep / 2.0), Vector3(0.2, tall, deep), CONCRETE, "Wall_e")
	Greybox.box(holder, Vector3(0, mid, BACK_Z - 0.1), Vector3(2 * INNER + 0.4, tall, 0.2), CONCRETE, "Wall_n")
	Greybox.box(holder, Vector3(0, mid, (LANDING_Z + HALF_Z) / 2.0), Vector3(2 * CORE, tall, LANDING_Z - HALF_Z), CONCRETE, "Wall_core")
	Greybox.box(holder, Vector3(0, top + 0.1, -deep / 2.0), Vector3(2 * INNER + 0.4, 0.2, deep), CONCRETE.lightened(0.1), "Ceiling")
	# The front wall, round this floor's doorway; the copied landings' doors stand
	# in gaps of their own (_copy_door).
	var side := (INNER + 0.2 - DOOR_W / 2.0)
	var sx := DOOR_W / 2.0 + side / 2.0
	var gaps := []
	for k in range(int(round(lo / STOREY)), int(round(hi / STOREY)) + 1):
		gaps.append(k * STOREY)
	var y := bottom
	for g in gaps:
		if g > y:
			Greybox.box(holder, Vector3(0, (y + g) / 2.0, -0.1), Vector3(2 * INNER + 0.4, g - y, 0.2), CONCRETE, "Wall_s")
		for s in [-1, 1]:
			Greybox.box(holder, Vector3(s * sx, g + DOOR_H / 2.0, -0.1), Vector3(side, DOOR_H, 0.2), CONCRETE, "Wall_s")
		y = g + DOOR_H
	Greybox.box(holder, Vector3(0, (y + top) / 2.0, -0.1), Vector3(2 * INNER + 0.4, top - y, 0.2), CONCRETE, "Wall_s")


## One flight: nine treads between the landing's edge (at `y_front`) and the
## half-landing's (at `y_back`), on the +x side (`side` 1) or the -x side. Each
## tread is a slab, so there's headroom under the flight above. What you walk on
## is a ramp from edge to edge, hidden in the treads: nobody's body steps up
## (Player, the Custodian), so a step would stop them. Returns where its handrail
## runs, along the middle wall: [from, to], in the stairwell's space.
static func _flight(holder: Node3D, flight_name: String, side: int, y_front: float, y_back: float) -> Array:
	var x := side * (CORE + INNER) / 2.0
	var width := INNER - CORE
	var first := Vector3.ZERO
	var last := Vector3.ZERO
	for i in RISERS - 1:
		var top := y_front + (y_back - y_front) * float(i + 1) / RISERS
		var z := LANDING_Z - RUN * (i + 0.5)
		var tread := Greybox.box(holder, Vector3(x, top - 0.2, z), Vector3(width, 0.4, RUN), CONCRETE.darkened(0.15), flight_name)
		for c in tread.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = true
		var rail := Vector3(side * (CORE + 0.05), top, z)
		if i == 0:
			first = rail
		last = rail
	var front := Vector3(x, y_front, LANDING_Z)
	var back := Vector3(x, y_back, HALF_Z)
	var along := (back - front).normalized()
	var up := along.cross(Vector3.RIGHT)
	if up.y < 0.0:
		up = -up
	var ramp := StaticBody3D.new()
	ramp.name = "Ramp" + flight_name.trim_prefix("Stair")
	ramp.transform = Transform3D(Basis(Vector3.RIGHT, up, Vector3.RIGHT.cross(up)), (front + back) / 2.0 - up * 0.05)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.1, front.distance_to(back))
	shape.shape = box
	ramp.add_child(shape)
	holder.add_child(ramp, true)
	return [first, last]


static func _slab(holder: Node3D, top_mid: Vector3, size: Vector3, slab_name: String) -> void:
	Greybox.box(holder, top_mid - Vector3(0, size.y / 2.0, 0), size, CONCRETE.darkened(0.3), slab_name)


## A copied landing's door, shut for good: it looks like the real one (Door.create).
static func _copy_door(holder: Node3D, y0: float) -> void:
	var body := Greybox.box(holder, Vector3(0, y0 + DOOR_H / 2.0, 0), Vector3(DOOR_W, DOOR_H, 0.08), DOOR_COLOR, "CopyDoor")
	for c in body.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = Greybox.mat(DOOR_COLOR, 0.0, 0.5)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(DOOR_W * 0.9, 0.12, 0.1)
	stripe.mesh = sm
	stripe.material_override = Greybox.mat(Color(0.8, 0.6, 0.1))
	stripe.position.y = DOOR_H * 0.25
	body.add_child(stripe)
	# Beside it, on the latch side, the badge reader that keeps it shut at night:
	# its light red (the lobby side's placard says why).
	var reader := Greybox.box(holder, Vector3(DOOR_W / 2.0 + 0.22, y0 + 1.2, -0.22), Vector3(0.09, 0.14, 0.04), Color(0.12, 0.12, 0.13), "BadgeReader")
	for c in reader.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true
	var led := MeshInstance3D.new()
	led.name = "Locked"
	var lm := BoxMesh.new()
	lm.size = Vector3(0.025, 0.025, 0.01)
	led.mesh = lm
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.08, 0.05)
	red.emission_enabled = true
	red.emission = Color(1.0, 0.1, 0.05)
	red.emission_energy_multiplier = 2.0
	led.material_override = red
	led.position = Vector3(0, 0.04, -0.025)
	reader.add_child(led)


## Floor 13's plate on STAIR 1, with masking tape over its number and "12A"
## written on the tape in marker: something for the observant (nothing behind it yet).
static func _taped_plate() -> Node3D:
	var n := Node3D.new()
	n.name = "Tape12A"
	# Over the big number on the landing plate (ArtKit.landing_number, on the -x wall).
	n.position = Vector3(-INNER + 0.025, 1.66, -1.0)
	n.rotation_degrees.y = 90.0  # its face looks along +x, into the stairwell
	var strip := MeshInstance3D.new()
	strip.name = "Tape"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.36, 0.004)
	strip.mesh = bm
	strip.material_override = Greybox.mat(Color(0.86, 0.8, 0.62), 0.0, 0.9)
	n.add_child(strip)
	var marker := Label3D.new()
	marker.name = "Marker"
	marker.text = "12A"
	marker.font = NotebookArt.hand_font()
	marker.font_size = 160
	marker.pixel_size = 0.0016
	marker.modulate = Color(0.06, 0.06, 0.08)
	marker.outline_size = 0
	marker.position.z = 0.004
	n.add_child(marker)
	return n
