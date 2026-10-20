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

const DOOR_W := 1.0
const DOOR_H := 2.2


## Builds the stairwell under `geo` and returns its door (locked), which goes on
## the level itself because it moves.
static func build(level: Node3D, geo: Node3D, at: Vector3, yaw_deg: float, floor_label: String, stair := "STAIR 1") -> Door:
	var holder := Node3D.new()
	holder.name = "Stairwell"
	holder.position = at
	holder.rotation_degrees.y = yaw_deg
	geo.add_child(holder)
	var concrete := Color(0.5, 0.5, 0.48)
	Greybox.room(holder, Vector3(0, 0, -2.1), Vector3(3.6, 3.2, 4.0), {"floor": concrete.darkened(0.3), "wall": concrete},
		[{"wall": "s", "at": 0.0, "width": DOOR_W, "height": DOOR_H}])
	# A flight up along one side, with a rail; the landing by the door is clear.
	for i in 8:
		Greybox.box(holder, Vector3(0.85, 0.09 + i * 0.18, -1.45 - i * 0.32), Vector3(1.5, 0.18 + i * 0.36, 0.32), concrete.darkened(0.15), "Stair")
	Greybox.box(holder, Vector3(0.05, 1.3, -2.6), Vector3(0.05, 0.05, 2.6), Color(0.75, 0.6, 0.1), "StairRail")
	Greybox.label(holder, Vector3(-1.75, 2.0, -2.1), "%s\nFLOOR %s" % [stair, floor_label], 64, Color(0.1, 0.1, 0.1), 90)

	var door := Door.create(level, "%s-%s" % [stair.replace(" ", "-"), floor_label], holder.transform * Vector3(0, DOOR_H / 2.0, 0), Vector3(DOOR_W, DOOR_H, 0.08))
	door.rotation_degrees.y = yaw_deg
	door.make_hinged(Vector3(-DOOR_W / 2.0, 0, 0), 90.0)
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
