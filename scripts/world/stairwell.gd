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
## Inside, a flight goes up along one wall and, on every floor but G, a flight goes
## down along the other, so the way down looks like the way the crew came. The door
## swings out into the lobby, always, so the landing behind it stays clear for
## whoever arrives (Augustine, v0.8 playtest: players arrived pinned behind it).

const DOOR_W := 1.0
const DOOR_H := 2.2


## The flight down: STEPS_DOWN steps of STEP_RISE, each STEP_DOWN_RUN deep, from
## DOWN_FROM_Z back to the stairwell's far wall, along the -x side.
const STEPS_DOWN := 6
const STEP_RISE := 0.18
const STEP_DOWN_RUN := 0.3
const DOWN_FROM_Z := -2.3
## The half-wall between the flights, above the landing's floor.
const PARAPET_H := 0.9
## How far the stair door's leaf swings out: negative opens it out of the stairwell.
const DOOR_SWING := -90.0


## Builds the stairwell under `geo` and returns its door (locked), which goes on
## the level itself because it moves. `down` adds the flight down (false on G).
static func build(level: Node3D, geo: Node3D, at: Vector3, yaw_deg: float, floor_label: String, stair := "STAIR 1", down := true) -> Door:
	var holder := Node3D.new()
	holder.name = "Stairwell"
	holder.position = at
	holder.rotation_degrees.y = yaw_deg
	geo.add_child(holder, true)  # a floor's second is "Stairwell2", so dressing finds it too
	var concrete := Color(0.5, 0.5, 0.48)
	Greybox.room(holder, Vector3(0, 0, -2.1), Vector3(3.6, 3.2, 4.0), {"floor": concrete.darkened(0.3), "wall": concrete},
		[{"wall": "s", "at": 0.0, "width": DOOR_W, "height": DOOR_H}])
	# A flight up along one side, with a rail; the landing by the door is clear.
	for i in 8:
		Greybox.box(holder, Vector3(0.85, 0.09 + i * 0.18, -1.45 - i * 0.32), Vector3(1.5, 0.18 + i * 0.36, 0.32), concrete.darkened(0.15), "Stair")
	Greybox.box(holder, Vector3(0.05, 1.3, -2.6), Vector3(0.05, 0.05, 2.6), Color(0.75, 0.6, 0.1), "StairRail")
	if down:
		_flight_down(holder, concrete)
	Greybox.label(holder, Vector3(-1.75, 2.0, -2.1), "%s\nFLOOR %s" % [stair, floor_label], 64, Color(0.1, 0.1, 0.1), 90)

	var door := Door.create(level, "%s-%s" % [stair.replace(" ", "-"), floor_label], holder.transform * Vector3(0, DOOR_H / 2.0, 0), Vector3(DOOR_W, DOOR_H, 0.08))
	door.rotation_degrees.y = yaw_deg
	door.make_hinged(Vector3(-DOOR_W / 2.0, 0, 0), DOOR_SWING)
	door.one_way = true  # out into the lobby, whichever side it's opened from
	door.locked = true
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


## Where the `index`th of up to six arrivals stands on the landing (in the space
## `at` is in), two abreast in three rows beside the flight up: clear of both
## flights, the walls and the door, for the biggest of the crew.
static func landing_slot(at: Vector3, yaw_deg: float, index: int) -> Vector3:
	var holder := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	return holder * Vector3(-0.9 + 0.45 * (index % 2), 0.1, -0.7 - 0.55 * (index / 2))


## The flight down: the floor opens beside the landing and the steps go down to
## the far wall, with a half-wall between them and the flight up. They're solid,
## so you can walk down them; the turn below is out of sight.
static func _flight_down(holder: Node3D, concrete: Color) -> void:
	for c in holder.get_children():
		if c.name.begins_with("Floor"):
			holder.remove_child(c)
			c.free()
	var back := -4.1
	var depth := STEPS_DOWN * STEP_RISE + 0.2
	# The floor: all of the landing, and the strip under the flight up.
	Greybox.box(holder, Vector3(0, -0.1, (DOWN_FROM_Z - 0.1) / 2.0), Vector3(3.6, 0.2, -DOWN_FROM_Z - 0.1), concrete.darkened(0.3), "Floor")
	Greybox.box(holder, Vector3(0.85, -0.1, (DOWN_FROM_Z + back) / 2.0), Vector3(1.9, 0.2, DOWN_FROM_Z - back), concrete.darkened(0.3), "Floor")
	for i in STEPS_DOWN:
		var top := -STEP_RISE * (i + 1)
		var z := DOWN_FROM_Z - STEP_DOWN_RUN * (i + 0.5)
		if i == STEPS_DOWN - 1:
			z = (DOWN_FROM_Z - STEP_DOWN_RUN * i + back) / 2.0  # the last one runs to the wall
		var run := STEP_DOWN_RUN if i < STEPS_DOWN - 1 else DOWN_FROM_Z - STEP_DOWN_RUN * i - back
		Greybox.box(holder, Vector3(-0.9, (top - depth) / 2.0, z), Vector3(1.6, top + depth, run), concrete.darkened(0.15), "StepDown")
	# The well's sides below the floor: the outer wall and the far wall; between the
	# two flights, a concrete half-wall from the well's foot to waist height.
	var mid := (DOWN_FROM_Z + back) / 2.0
	Greybox.box(holder, Vector3(-1.8, -depth / 2.0, mid), Vector3(0.2, depth, DOWN_FROM_Z - back), concrete, "Wall_Well")
	Greybox.box(holder, Vector3(-0.9, -depth / 2.0, back - 0.1), Vector3(1.8, depth, 0.2), concrete, "Wall_Well")
	Greybox.box(holder, Vector3(0.0, (PARAPET_H - depth) / 2.0, mid), Vector3(0.2, PARAPET_H + depth, DOWN_FROM_Z - back), concrete, "Wall_Parapet")
