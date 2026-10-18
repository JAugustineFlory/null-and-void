class_name Level2Floor
extends RefCounted
## The rest of the security floor, around the original wing: the night-desk
## reception off the arrival landing, a long patrol corridor running north, Secure
## Lab B and the rooms either side of it, a service passage behind them that loops
## back round, and the camera room. None of it goes down: the security office and
## SEC-EXIT stay the only way off the floor.
##
## Layout (level space, north is -z):
##   reception   x -8..2.5,   z 6..10   (west of the landing)
##   patrol      x -10..-8,   z -18..10
##   west block  x -16..-10:  locker room z -16..-10, briefing z -10..-4,
##               Secure Lab B z -4..4 (see Level2Lab), interview z 4..8
##   service     x -18..-16,  z -16..8, joined to the patrol corridor by halls at
##               z -18..-16 and z 8..10, so a chase can go round in a loop
##   camera room x -7.8..-3,  z -20..-15
## The side rooms have ordinary doors that shut. Their doorways are too narrow for
## the Watcher's navigation, so a closed side room is somewhere to hide.

const FLOOR := Color(0.27, 0.27, 0.3)
const WALL := Color(0.52, 0.53, 0.5)
const SIDE_DOOR := 1.0
## Secure Lab B's shell, for Level2Lab to furnish.
const LAB_CENTER := Vector3(-13, 0, 0)
const LAB_SIZE := Vector3(5.6, 3.2, 7.6)  # inset, so its walls sit beside its neighbours', not inside them
const LAB_BOX := AABB(Vector3(-16, -1, -4), Vector3(6, 4, 8))


static func build(level: Node3D) -> void:
	var geo: Node3D = level.geo
	var colors := {"floor": FLOOR, "wall": WALL}
	# Night-desk reception, through the landing's west wall.
	Greybox.room(geo, Vector3(-2.75, 0, 8), Vector3(10.5, 3.2, 4), colors, [
		{"wall": "e", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "w", "at": 0.0, "width": 1.6, "height": 2.4},
	])
	Greybox.box(geo, Vector3(-3.5, 0.55, 7.2), Vector3(3.6, 1.1, 0.7), Color(0.4, 0.36, 0.3), "NightDesk")
	Greybox.box(geo, Vector3(-3.5, 0.4, 8.6), Vector3(1.0, 0.8, 0.6), Color(0.3, 0.3, 0.32), "NightDeskChair")
	Greybox.label(geo, Vector3(-3.5, 2.6, 6.12), "NIGHT DESK", 48, Color(0.75, 0.75, 0.7))
	# The patrol corridor: long and straight, for a chase.
	Greybox.room(geo, Vector3(-9, 0, -4), Vector3(2, 3.2, 28), colors, [
		{"wall": "e", "at": 12.0, "width": 1.6, "height": 2.4},  # reception
		{"wall": "e", "at": -13.0, "width": 1.2, "height": 2.4},  # camera room
		{"wall": "w", "at": 13.0, "width": 1.6, "height": 2.4},  # south hall
		{"wall": "w", "at": 10.0, "width": SIDE_DOOR, "height": 2.3},  # interview room
		{"wall": "w", "at": 4.0, "width": 1.8, "height": 2.4},  # Secure Lab B
		{"wall": "w", "at": -3.0, "width": SIDE_DOOR, "height": 2.3},  # briefing room
		{"wall": "w", "at": -9.0, "width": SIDE_DOOR, "height": 2.3},  # locker room
		{"wall": "w", "at": -13.0, "width": 1.6, "height": 2.4},  # north hall
	])
	_room(level, "Interview", Vector3(-13, 0, 6), Vector3(6, 3.2, 4))
	Greybox.box(geo, Vector3(-13.5, 0.38, 6), Vector3(1.6, 0.76, 0.9), Color(0.36, 0.3, 0.25), "InterviewTable")
	for x in [-14.8, -12.2]:
		Greybox.box(geo, Vector3(x, 0.25, 6), Vector3(0.45, 0.5, 0.45), Color(0.25, 0.25, 0.27), "Chair")
	Greybox.panel(geo, Vector3(-13, 1.6, 7.88), Vector3(2.0, 1.0, 0.03), Color(0.08, 0.09, 0.1), 0.2)  # the one-way glass
	_room(level, "Briefing", Vector3(-13, 0, -7), Vector3(6, 3.2, 6))
	Greybox.box(geo, Vector3(-13.2, 0.38, -7), Vector3(1.2, 0.76, 3.6), Color(0.36, 0.3, 0.25), "BriefingTable")
	Greybox.panel(geo, Vector3(-15.88, 1.5, -7), Vector3(0.03, 1.1, 2.2), Color(0.9, 0.9, 0.88))  # whiteboard
	_room(level, "Lockers", Vector3(-13, 0, -13), Vector3(6, 3.2, 6))
	# Two rows of lockers, with room to crouch behind the far row.
	for z in [-14.5, -11.8]:
		Greybox.box(geo, Vector3(-13.6, 1.0, z), Vector3(3.6, 2.0, 0.5), Color(0.3, 0.34, 0.3), "LockerRow")
	Greybox.box(geo, Vector3(-13.6, 0.22, -13.15), Vector3(2.4, 0.44, 0.4), Color(0.4, 0.33, 0.24), "Bench")
	# Lab shell: Level2Lab adds its doors, furniture and the scene of the struggle.
	Greybox.room(geo, LAB_CENTER, LAB_SIZE, {"floor": Color(0.62, 0.63, 0.62), "wall": Color(0.78, 0.8, 0.78)}, [
		{"wall": "e", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "w", "at": 0.0, "width": 1.8, "height": 2.4},
	])
	# The lab sits a little inside its neighbours: floor under its two doorways.
	for x in [-10.1, -15.9]:
		Greybox.box(geo, Vector3(x, -0.1, 0), Vector3(0.2, 0.2, 1.8), FLOOR, "LabSill")
	# The service passage behind the west rooms, and the halls joining it to the patrol corridor.
	Greybox.room(geo, Vector3(-17, 0, -4), Vector3(2, 3.2, 24), colors, [
		{"wall": "n", "at": 0.0, "width": 1.6, "height": 2.4},
		{"wall": "s", "at": 0.0, "width": 1.6, "height": 2.4},
		{"wall": "e", "at": 4.0, "width": 1.8, "height": 2.4},  # the lab's rear door
	])
	Greybox.room(geo, Vector3(-14, 0, 9), Vector3(8, 3.2, 2), colors, [
		{"wall": "e", "at": 0.0, "width": 1.6, "height": 2.4},
		{"wall": "n", "at": -3.0, "width": 1.6, "height": 2.4},
	])
	Greybox.room(geo, Vector3(-14, 0, -17), Vector3(8, 3.2, 2), colors, [
		{"wall": "e", "at": 0.0, "width": 1.6, "height": 2.4},
		{"wall": "s", "at": -3.0, "width": 1.6, "height": 2.4},
	])
	# The camera room: the recorders, and the tapes nobody pulled.
	Greybox.room(geo, Vector3(-5.4, 0, -17.5), Vector3(4.8, 3.2, 5), colors, [
		{"wall": "w", "at": 0.5, "width": 1.2, "height": 2.3},
	])
	var door := Door.create(level, "CAMERA-ROOM", Vector3(-7.8, 1.15, -17), Vector3(0.1, 2.3, 1.2)).make_hinged(Vector3(0, 0, -0.6), -90.0)
	door.name = "Door_CameraRoom"
	Greybox.box(geo, Vector3(-3.5, 0.4, -17.5), Vector3(0.8, 0.8, 3.6), Color(0.3, 0.3, 0.32), "RecorderDesk")
	for i in 3:
		Greybox.panel(geo, Vector3(-3.14, 1.5, -18.6 + i * 1.1), Vector3(0.04, 0.6, 0.9), Color(0.1, 0.12, 0.12), 0.3)
	Greybox.box(geo, Vector3(-5.4, 1.0, -19.6), Vector3(3.0, 2.0, 0.5), Color(0.25, 0.25, 0.26), "TapeRack")

	for z in [7.0, 1.0, -5.0, -11.0, -16.5]:
		level.add_light("patrol", Vector3(-9, 3.2, z), 6.0, 0.7)
	level.add_light("reception", Vector3(-3, 3.2, 8), 7.0, 0.9)
	level.add_light("service", Vector3(-17, 3.2, -10), 6.0, 0.4)
	level.add_light("service", Vector3(-17, 3.2, 2), 6.0, 0.4)
	for c in [Vector3(-13, 3.2, 6), Vector3(-13, 3.2, -7), Vector3(-13, 3.2, -13), Vector3(-5.4, 3.2, -17.5)]:
		level.add_light("side_rooms", c, 5.0, 0.7)
	FlickerLight.attach(level.lights["service"][0], 0.3)


## A side room off the patrol corridor, with an ordinary door that shuts.
static func _room(level: Node3D, room_name: String, center: Vector3, size: Vector3) -> void:
	Greybox.room(level.geo, center, size, {"floor": FLOOR, "wall": WALL}, [
		{"wall": "e", "at": 0.0, "width": SIDE_DOOR, "height": 2.3},
	])
	var at := Vector3(center.x + size.x / 2, 1.15, center.z)
	var door := Door.create(level, room_name.to_upper(), at, Vector3(0.1, 2.3, SIDE_DOOR)).make_hinged(Vector3(0, 0, -SIDE_DOOR / 2), 90.0)
	door.name = "Door_" + room_name
