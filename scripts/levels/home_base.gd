class_name HomeBase
extends LevelBase
## The crew's garage: Byte-Right IT Services' home base, the evening of the job.
## The game opens here: the crew walks in from the pre-game lobby out front and
## sits facing Maddison's whiteboard. She briefs them, sends them to the punch bag
## and back, points them at the work order in their notebooks, then sends one of
## them for the book, whose first chapter goes in everyone's notebook (Huddle),
## and sees them off in the van. The drive cuts to the van in Halcyon's car park
## (Level 0). The World keeps the garage loaded out of sight, far from the tower.
##
## The punch bag by the roll-up door teaches blocking safely: hit it and it swings
## back at you, and right-clicking as it comes in blocks it. A miss costs nothing.
## Everyone blocks it once before they sit back down.
##
## Maddison, the boss, is on her feet in here: she walks the room in the opening.
##
## Graphics dresses it; DressHomeBase can hook in at the end of build().

## Where the garage sits in the World: well away from the tower and its car park.
const AT := Transform3D(Basis(), Vector3(-300, 0, -300))
const SCENE := "res://scenes/home_base.tscn"
## A converted RV garage (level-local): x -8..8, z -6..6, 5 m to the rafters. The
## roll-up door is in the north wall over the van's lane, with the driveway beyond.
const SIZE := Vector3(16, 5, 12)
const DOOR_AT := 4.6
const DOOR_SIZE := Vector2(4.4, 4.2)
## The briefing corner on the west side: Maddison's whiteboard on the wall, a couch
## and a row of counter stools facing it, so a crew of up to six all face her.
const WHITEBOARD := Vector3(-7.95, 1.6, 0.0)
const COUCH := Vector3(-4.4, 0, 0.0)
const COUNTER := Vector3(-1.9, 0, 0.0)
## Where each crew member sits, in the order they're given out (couch first, from
## the middle), facing the whiteboard. Level-local seat tops.
const CREW_SEATS := [Vector3(-4.55, 0.45, 0.0), Vector3(-4.55, 0.45, -1.0), Vector3(-4.55, 0.45, 1.0),
	Vector3(-2.6, 0.75, 0.0), Vector3(-2.6, 0.75, -1.0), Vector3(-2.6, 0.75, 1.0)]
## Outside: the foot of the roll-up door, and the driveway apron in front of it.
const FRONT_DOOR := Vector3(DOOR_AT, 0, -SIZE.z / 2)
const APRON_CENTER := Vector3(3.6, 0, -11.0)
const APRON_SIZE := Vector3(24, 0.2, 10)
## Co-op's pre-game lobby holds this shot of the garage front (garage-local), and
## the World's garage opens on it, so the cut between them doesn't show.
const LOBBY_CAMERA := Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -0.05), Vector3(3.6, 1.7, -12.2))
## Where each player stands in the lobby (in join order), with a pose that suits
## the spot. Co-op sends each player's own pick.
const LOBBY_SPOTS := [
	{"at": Vector3(3.6, 0, -8.6), "pose": "idle"},
	{"at": Vector3(2.2, 0, -8.3), "pose": "wave"},
	{"at": Vector3(5.0, 0, -8.3), "pose": "idle"},
	{"at": Vector3(0.8, 0, -7.7), "pose": "crouch"},
	{"at": Vector3(6.4, 0, -7.7), "pose": "point"},
	{"at": Vector3(-0.6, 0, -7.2), "pose": "sit_floor"},
]
## How far either side of the shot's centre a walk-in starts: just out of frame.
const LOBBY_ENTRY_SIDE := 9.5
const BENCH := Vector3(0.5, 0, 3.6)
const VAN := Vector3(4.6, 0, -0.6)
## The office desk with the fax and the radio, in the north-west corner.
const DESK := Vector3(-7.4, 0, -4.2)
## The shelf in the back corner by the side door to the house: where the shop bag was left.
const SHELF := Vector3(-6.2, 0, 5.6)
const SIDE_DOOR := Vector3(-7.97, 0, 4.6)
## Where the punch bag hangs (on the floor below it), from its stand's top bar
## BAG_HOOK up, between two posts BAG_STAND_HALF either side, clear of its swing.
const PUNCH_BAG := Vector3(0.8, 0, -3.6)
const BAG_HOOK := 2.5
const BAG_STAND_HALF := 1.3
## Its swing back reaches whoever hit it from within this of it.
const SPAR_REACH := 2.2
## Hit, the bag flies away from you (the tell), then swings back in: right-click during
## the swing in. It's shorter than the guard (Guard.WINDOW), so a press anywhere in it blocks.
const SPAR_TELL := 0.7
const SPAR_SWING := 0.3
## Approved by Augustine word for word, 2026-10-22 01:13Z
## (plan/teaching/garage-playtest-2026-10-22.md, item 3).
const SPAR_TODO := "Hit the punch bag, then block it"
const SPAR_NOTICE := "Hit the bag with left-click. It swings back at you: right-click just as it comes in to raise your guard and block it."
const SPAR_MISS := "It hit you. Right-click just as it swings in to raise your guard."
const SPAR_EARLY := "Too early: your guard dropped before it reached you. Wait for the swing in, then right-click."
const SPAR_BLOCKED := "Blocked! Your guard took the hit."
## Maddison's marks: where she stands for each beat, and the point she faces there.
## She comes in by the side door to the house; "board" is beside her whiteboard,
## facing the crew.
const MADDISON_MARKS := {
	"door": [Vector3(-7.2, 0, 4.6), Vector3(0, 0, 4.6)],
	"greet": [Vector3(-6.4, 0, 2.2), Vector3(-3.0, 0, 0.0)],
	"fax": [Vector3(-6.4, 0, -4.6), Vector3(-7.35, 0, -4.6)],
	"board": [Vector3(-7.1, 0, 1.6), Vector3(-3.0, 0, 0.0)],
	"side": [Vector3(-6.6, 0, 3.4), Vector3(-6.2, 0, 5.6)],  # by the shelf, showing the crew the shop bag
	"bench": [Vector3(2.1, 0, 3.6), BENCH],
	"van": [Vector3(2.4, 0, 0.8), Vector3(3.3, 0, -0.5)],
}
## The walk in from the lobby (garage-local): through the roll-up door, past the
## punch bag, then down to the north end of the couch and the stools.
const WALK_IN := [Vector3(DOOR_AT, 0, -5.0), Vector3(-1.0, 0, -5.0), Vector3(-3.3, 0, -2.4)]
## The book in first person, on the camera: low and to the right, cover up.
const HELD_BOOK := Transform3D(Basis(Vector3.RIGHT, 1.2) * Basis(Vector3.UP, -0.25), Vector3(0.16, -0.2, -0.42))
## Maddison takes her time: she walks at this share of a crew member's pace, and
## lets a beat go by between one thing and the next.
const MADDISON_PACE := 0.7
const BEAT := 1.2

var fax: Interactable
var book_bag: Interactable
var van_door: Interactable
## The seats facing the whiteboard, as CREW_SEATS.
var crew_seats: Array[Seat] = []
## Maddison (CharacterLooks.maddison), and the mark she's at or walking to.
var maddison: Node3D
var maddison_mark := "door"
var _maddison_walk: Tween
## The punch bag's hook: it swings about this point. Hit, it swings back.
var punch_bag: StaticBody3D
## Who the bag is swinging at (0: nobody), and whether it's coming in now.
var spar_target := 0
var swing_in := false
## Who has blocked it (host decides; every machine hears).
var spar_blocked: Array = []
signal crew_sparred
## While the drill is on, and (on the combat clock) when this player's guard last
## went up and when the bag's last swing at them began: a miss says if it was early.
var _sparring := false
var _guard_at := -100.0
var _swing_at := -100.0
var _bag_swing: Tween
## Everyone back in a seat after the punch bag; the book's carrier sat down with it.
signal crew_seated
## Who has pulled out the work order (host decides; every machine hears).
var read_order: Array = []
signal crew_read_order
## Who took the book from the shelf, and the book in their hands.
var book_holder := 0
var held_book: Node3D
## The book on the workbench, once someone has brought it over.
var bench_book: Node3D
## The shot inside, over the seats at Maddison and her whiteboard (the opening cuts to it).
var flashback_camera: Camera3D
## The pre-game lobby's shot of the garage front (LOBBY_CAMERA): the opening starts on it.
var lobby_camera: Camera3D
## Van seats in boarding order (level-local), and who has climbed in.
var van_seats: Array[Vector3] = []
var boarded: Array = []
signal crew_boarded
## The roll-up door: a slatted panel that rolls up into the rafters.
var roll_up_door: AnimatableBody3D


func build() -> void:
	roll_up_door = _build_shell(geo, self)
	Greybox.label(geo, Vector3(-2.5, 3.6, SIZE.z / 2 - 0.12), "BYTE-RIGHT IT SERVICES", 72, Color(0.1, 0.3, 0.6), 180)

	# The briefing corner: the couch and the counter with its stools, facing the
	# whiteboard (DressHomeBase hangs it at WHITEBOARD).
	Greybox.box(geo, COUCH + Vector3(0, 0.22, 0), Vector3(0.9, 0.44, 3.2), Color(0.3, 0.38, 0.5), "Couch")
	Greybox.box(geo, COUCH + Vector3(0.38, 0.62, 0), Vector3(0.18, 0.36, 3.2), Color(0.3, 0.38, 0.5), "CouchBack")
	Greybox.box(geo, COUNTER + Vector3(0, 0.52, 0), Vector3(0.6, 1.04, 3.4), Color(0.5, 0.38, 0.26), "Counter")
	for i in CREW_SEATS.size():
		var top: Vector3 = CREW_SEATS[i]
		if top.y > 0.6:  # a counter stool
			Greybox.box(geo, Vector3(top.x, top.y / 2, top.z), Vector3(0.36, top.y, 0.36), Color(0.2, 0.2, 0.22), "Stool%d" % i)
		var seat := Seat.create_at(self, top, PI / 2, Vector2(0.45, 0.45))  # facing the whiteboard (-X)
		seat.name = "BriefingSeat%d" % i
		crew_seats.append(seat)

	# The workbench in the middle of the floor.
	Greybox.box(geo, BENCH + Vector3(0, 0.475, 0), Vector3(2.4, 0.95, 1.0), Color(0.45, 0.33, 0.22), "Workbench")
	bench_book = _book(geo, BENCH + Vector3(0.2, 0.99, 0.1))
	bench_book.name = "BenchBook"
	bench_book.visible = false

	# The office corner: a desk with the fax machine and the radio base station.
	Greybox.box(geo, DESK + Vector3(0, 0.4, 0), Vector3(0.9, 0.8, 1.8), Color(0.35, 0.3, 0.25), "Desk")
	Greybox.box(geo, DESK + Vector3(-0.05, 0.95, 0.6), Vector3(0.45, 0.3, 0.35), Color(0.15, 0.15, 0.16), "Radio")
	# The fax is set dressing now: the work order is already in everyone's notebook.
	fax = Interactable.create(self, DESK + Vector3(0.05, 0.93, -0.4), Vector3(0.45, 0.26, 0.4), "", Color(0.82, 0.8, 0.74))
	fax.name = "Fax"
	fax.enabled = false

	# The back corner by the side door: the shelf where the shop bag was left.
	Greybox.box(geo, SHELF + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 0.7), Color(0.3, 0.3, 0.32), "Shelf")
	get_node("/root/Game").before_book = true  # the book's still in the bag
	book_bag = Interactable.create(self, SHELF + Vector3(0.3, 1.15, -0.05), Vector3(0.4, 0.3, 0.15), "Take the shop bag", Color(0.85, 0.85, 0.8))
	book_bag.name = "BookBag"
	book_bag.enabled = false
	book_bag.used.connect(func(p): sync.event("_on_bag", [players.id_of(p)]))

	_build_van(VAN)
	_build_punch_bag(PUNCH_BAG)
	Greybox.panel(geo, SIDE_DOOR + Vector3(0.0, 1.05, 0), Vector3(0.05, 2.1, 0.9), Color(0.5, 0.42, 0.32))  # the side door to the house
	maddison = Node3D.new()
	maddison.name = "Maddison"
	maddison.position = MADDISON_MARKS.door[0]
	add_child(maddison)
	_face(maddison, MADDISON_MARKS.door[1])
	NpcLook.attach(maddison, CharacterLooks.maddison(), hud)  # she talks when her line is up

	# A well-lit workshop: rows of bright fittings under the rafters.
	var bulb := Color(1.0, 0.94, 0.84)
	for x in [-5.0, 0.0, DOOR_AT]:
		for z in [-3.0, 2.5]:
			add_light("garage", Vector3(x, SIZE.y, z), 8.0, 1.5, bulb)


	flashback_camera = Camera3D.new()
	flashback_camera.name = "FlashbackCamera"
	add_child(flashback_camera)
	flashback_camera.position = Vector3(-2.0, 2.2, 2.4)
	flashback_camera.look_at_from_position(flashback_camera.position, Vector3(-7.0, 1.3, 0.2), Vector3.UP)
	lobby_camera = Camera3D.new()
	lobby_camera.name = "LobbyCamera"
	lobby_camera.transform = LOBBY_CAMERA
	add_child(lobby_camera)
	spawn = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0.5, 0.1, 0.5))  # facing the briefing corner
	DressHomeBase.apply(self)  # furniture and materials (Graphics thread)


## The garage from outside, with no story in it: Co-op's pre-game lobby builds
## this in its own scene and holds LOBBY_CAMERA on it, then the World's garage
## (built from the same code) opens on the same shot.
static func build_front(parent: Node3D) -> Node3D:
	var front := Node3D.new()
	front.name = "GarageFront"
	parent.add_child(front)
	_build_shell(front, front)
	DressHomeBase.front(front, front)  # the outside dressed (Graphics)
	return front


## Dusk out front, as the pre-game lobby shows it (Co-op's colours): a sky and
## ambient light on `env`, and a low warm sun added under `parent`. Returns what
## it changed, for restore_outside().
static func dusk_outside(env: Environment, parent: Node) -> Dictionary:
	var before := {}
	for k in ["background_mode", "sky", "ambient_light_source", "ambient_light_energy", "fog_enabled"]:
		before[k] = env.get(k)
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.12, 0.16, 0.32)
	mat.sky_horizon_color = Color(0.85, 0.5, 0.35)
	mat.ground_horizon_color = Color(0.3, 0.25, 0.25)
	mat.ground_bottom_color = Color(0.08, 0.08, 0.1)
	var sky := Sky.new()
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.fog_enabled = false
	var sun := DirectionalLight3D.new()
	sun.name = "DuskSun"
	sun.rotation_degrees = Vector3(-20, 35, 0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.1
	parent.add_child(sun)
	before["sun"] = sun
	return before


## Put `env` back as it was before dusk_outside(), and the sun away.
static func restore_outside(env: Environment, before: Dictionary) -> void:
	for k in before:
		if k != "sun":
			env.set(k, before[k])
	(before.sun as Node).queue_free()


## The walls, the driveway out front, the outside sign and lamps under `solid`,
## and the shut roll-up door under `door_parent` (kept out of geo, so the floor's
## navigation runs out through the doorway). Returns the door.
static func _build_shell(solid: Node3D, door_parent: Node3D) -> AnimatableBody3D:
	var concrete := Color(0.55, 0.55, 0.52)
	var block := Color(0.82, 0.8, 0.74)
	Greybox.room(solid, Vector3.ZERO, SIZE, {"floor": concrete, "wall": block, "ceiling": Color(0.85, 0.84, 0.8)}, [
		{"wall": "n", "at": DOOR_AT, "width": DOOR_SIZE.x, "height": DOOR_SIZE.y},
		{"wall": "w", "at": SIDE_DOOR.z, "width": 0.9, "height": 2.1},
	])
	# The driveway out front, wide enough for the crew to walk in from either side.
	Greybox.box(solid, APRON_CENTER + Vector3(0, -0.1, 0), APRON_SIZE, Color(0.4, 0.4, 0.4), "Driveway")
	var street := MeshInstance3D.new()  # the dark street the driveway meets
	street.name = "Street"
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	street.mesh = plane
	street.material_override = Greybox.mat(Color(0.12, 0.12, 0.13))
	street.position = APRON_CENTER + Vector3(0, -0.21, 0)
	solid.add_child(street)
	Greybox.label(solid, Vector3(DOOR_AT, 4.6, -SIZE.z / 2 - 0.12), "BYTE-RIGHT IT", 140, Color(0.1, 0.3, 0.6), 180)  # over the roll-up door
	for x in [DOOR_AT - 2.8, DOOR_AT + 2.8]:
		var lamp := OmniLight3D.new()
		lamp.name = "FrontLamp"
		lamp.position = Vector3(x, 3.8, -SIZE.z / 2 - 0.6)
		lamp.light_color = Color(1.0, 0.9, 0.75)
		lamp.light_energy = 1.4
		lamp.omni_range = 7.0
		solid.add_child(lamp)
	return _build_roll_up_door(door_parent)


## The roll-up door, shut: a panel filling the doorway, slats and all.
static func _build_roll_up_door(parent: Node3D) -> AnimatableBody3D:
	var door := AnimatableBody3D.new()
	door.name = "RollUpDoor"
	door.position = Vector3(DOOR_AT, DOOR_SIZE.y / 2, -SIZE.z / 2)
	parent.add_child(door)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(DOOR_SIZE.x, DOOR_SIZE.y, 0.08)
	shape.shape = box
	door.add_child(shape)
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = box.size
	panel.mesh = pm
	panel.material_override = Greybox.mat(Color(0.78, 0.78, 0.75))
	door.add_child(panel)
	for i in 8:
		var slat := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(DOOR_SIZE.x, 0.03, 0.1)
		slat.mesh = sm
		slat.position = Vector3(0, -DOOR_SIZE.y / 2 + 0.25 + i * 0.5, 0)
		slat.material_override = Greybox.mat(Color(0.6, 0.6, 0.58))
		door.add_child(slat)
	return door


## Roll the door up into the rafters (or down again), over `seconds`.
func roll_door(up: bool, seconds: float = 2.5) -> void:
	var to := DOOR_SIZE.y / 2 + (DOOR_SIZE.y - 0.2 if up else 0.0)
	var t := create_tween()
	t.tween_property(roll_up_door, "position:y", to, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## The crew's van, parked nose to the roll-up door: a hollow body with a sliding
## side door facing the workbench, and six seats inside.
func _build_van(center: Vector3) -> void:
	var white := Color(0.86, 0.86, 0.83)
	var cab := center + Vector3(0, 0.5, 0)
	Greybox.room(geo, cab, Vector3(2.6, 2.1, 4.4), {"floor": Color(0.2, 0.2, 0.22), "wall": white, "ceiling": white}, [
		{"wall": "n", "at": 0.0, "width": 2.3, "height": 1.95, "bottom": 0.85},
		{"wall": "w", "at": 0.1, "width": 1.3, "height": 1.9},
	])
	Greybox.box(geo, center + Vector3(0, 0.2, 0), Vector3(2.7, 0.2, 4.7), Color(0.15, 0.15, 0.15), "Chassis")
	Greybox.box(geo, center + Vector3(0, 0.95, -2.65), Vector3(2.6, 0.9, 0.9), white, "Bonnet")
	Greybox.label(geo, center + Vector3(-1.42, 1.7, 1.5), "BYTE-RIGHT\nIT SERVICES", 50, Color(0.1, 0.3, 0.6), -90.0)
	van_door = Interactable.create(self, cab + Vector3(-1.25, 0.95, 0.1), Vector3(0.1, 1.9, 1.3), "Get in the van", white, false)
	van_door.name = "VanDoor"
	van_door.enabled = false
	van_door.used.connect(_on_van_door)
	# Front seats, then the rear bench, as in the van at Halcyon.
	for at in [Vector3(-0.55, 0, -1.3), Vector3(0.55, 0, -1.3), Vector3(-0.99, 0, 0.7),
			Vector3(-0.33, 0, 0.7), Vector3(0.33, 0, 0.7), Vector3(0.99, 0, 0.7)]:
		Greybox.panel(geo, cab + at + Vector3(0, 0.25, 0.1), Vector3(0.55, 0.5, 0.5), Color(0.15, 0.15, 0.18))
		van_seats.append(cab + at + Vector3(0, 0.05, 0))


static func _face(node: Node3D, point: Vector3) -> void:
	var to := point - node.position
	if Vector2(to.x, to.z).length() > 0.01:
		node.rotation.y = atan2(-to.x, -to.z)


## Lobby spot `i` (garage-local): {"at": Transform3D facing the camera, "pose": a CharacterRig action}.
static func lobby_spot(i: int) -> Dictionary:
	var spot: Dictionary = LOBBY_SPOTS[clampi(i, 0, LOBBY_SPOTS.size() - 1)]
	var at: Vector3 = spot.at
	var to_camera := LOBBY_CAMERA.origin - at
	var yaw := atan2(-to_camera.x, -to_camera.z)  # a rig faces -Z at yaw 0
	return {"at": Transform3D(Basis(Vector3.UP, yaw), at), "pose": spot.pose}


## Where the player for lobby spot `i` walks in from: off the edge of the shot on
## the spot's side, level with it.
static func lobby_entry(i: int) -> Vector3:
	var at: Vector3 = LOBBY_SPOTS[clampi(i, 0, LOBBY_SPOTS.size() - 1)].at
	var side := -1.0 if at.x <= LOBBY_CAMERA.origin.x else 1.0
	return Vector3(LOBBY_CAMERA.origin.x + side * LOBBY_ENTRY_SIDE, 0, at.z)


## Maddison walks to `mark` (see MADDISON_MARKS), round whatever is in the way
## (maddison_route), at her unhurried pace. Await it to wait until she's there.
func maddison_to(mark: String) -> void:
	if _maddison_walk:
		_maddison_walk.kill()
	var route := maddison_route(maddison.position, MADDISON_MARKS[mark][0])
	maddison_mark = mark
	_maddison_walk = create_tween()
	var from := maddison.position
	for to in route:
		_maddison_walk.tween_callback(_face.bind(maddison, to))
		_maddison_walk.tween_property(maddison, "position", to, from.distance_to(to) / (CharacterRig.WALK_SPEED * MADDISON_PACE))
		from = to
	_maddison_walk.tween_callback(_face.bind(maddison, MADDISON_MARKS[mark][1]))
	await _maddison_walk.finished


## Maddison's way from `from` to `to` (garage-local, on the floor): round the
## couch, the counter, the bench and the rest on the garage's navigation mesh, then
## the last step onto her mark (marks by a wall sit just off the mesh).
func maddison_route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var route: Array[Vector3] = []
	var map := geo.get_navigation_map()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		var path := NavigationServer3D.map_get_path(map, to_global(from), to_global(to), true)
		for i in range(1, path.size()):
			var at := to_local(path[i])
			route.append(Vector3(at.x, 0, at.z))
	if route.is_empty() or Vector2(route[-1].x - to.x, route[-1].z - to.z).length() > 0.05:
		route.append(to)
	return route


## A breath between one beat and the next.
func _beat(scale: float = 1.0) -> void:
	await get_tree().create_timer(BEAT * scale, false).timeout


## Maddison straight onto `mark`, no walk (a cut).
func maddison_at(mark: String) -> void:
	if _maddison_walk:
		_maddison_walk.kill()
	maddison_mark = mark
	maddison.position = MADDISON_MARKS[mark][0]
	_face(maddison, MADDISON_MARKS[mark][1])


## A heavy bag on a short chain from a free-standing steel stand, out of the way
## by the roll-up door (playtest 2026-10-22: hung from nothing, it floated). The
## stand is solid, under geo; the bag isn't: it moves, and nobody should bump into it.
func _build_punch_bag(at: Vector3) -> void:
	var steel := Color(0.22, 0.23, 0.25)
	for side in [-1, 1]:
		var x: float = at.x + side * BAG_STAND_HALF
		var end := "W" if side < 0 else "E"
		Greybox.box(geo, Vector3(x, BAG_HOOK / 2 + 0.05, at.z), Vector3(0.08, BAG_HOOK + 0.1, 0.08), steel, "BagStandPost" + end)
		Greybox.box(geo, Vector3(x, 0.04, at.z), Vector3(0.1, 0.08, 1.1), steel, "BagStandFoot" + end)
	Greybox.box(geo, Vector3(at.x, BAG_HOOK + 0.06, at.z), Vector3(BAG_STAND_HALF * 2 + 0.08, 0.1, 0.1), steel, "BagStandBar")
	punch_bag = preload("res://scripts/levels/home_base_bag.gd").new()
	punch_bag.name = "PunchBag"
	punch_bag.position = at + Vector3(0, BAG_HOOK, 0)
	add_child(punch_bag)
	var chain := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.03, 0.55, 0.03)
	chain.mesh = cm
	chain.position = Vector3(0, -0.275, 0)
	chain.material_override = Greybox.mat(Color(0.3, 0.3, 0.3))
	punch_bag.add_child(chain)
	var bag := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.22
	bm.bottom_radius = 0.22
	bm.height = 1.1
	bag.mesh = bm
	bag.position = Vector3(0, -1.1, 0)  # chest height: 0.85 m to 1.95 m off the floor
	bag.material_override = Greybox.mat(Color(0.55, 0.12, 0.1))
	punch_bag.add_child(bag)
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.22
	cs.height = 1.1
	shape.shape = cs
	shape.position = bag.position
	punch_bag.add_child(shape)


## A paperback with the teal cover: Easy SQL. Graphics swaps in ArtKit.easy_sql_book via DressHomeBase.
static func _book(parent: Node3D, at: Vector3) -> Node3D:
	var book := Node3D.new()
	book.position = at
	parent.add_child(book)
	var cover := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.19, 0.03, 0.25)
	cover.mesh = bm
	cover.material_override = Greybox.mat(Books.COVER)
	book.add_child(cover)
	var title := Label3D.new()
	title.text = "Easy\nSQL"
	title.font_size = 40
	title.modulate = Color.WHITE
	title.outline_size = 0
	title.pixel_size = 0.002
	title.rotation.x = -PI / 2
	title.position = Vector3(0, 0.017, 0)
	book.add_child(title)
	return book


func apply_environment(env: Environment) -> void:
	env.ambient_light_energy = 0.45
	env.fog_density = 0.0


## The garage's own story (Augustine's order, playtest 2026-10-21): the crew
## walks in from the lobby and sits facing Maddison; she briefs them, sends them
## to the punch bag to blow off steam, then back to their seats; the work order
## in every notebook; the book; chapter zero together; the van.
func start() -> void:
	player.flashlight.visible = false
	await open_for_crew()
	await _beat()
	maddison_to("board")  # in from the house, all smiles
	await _beat(1.5)
	await _say("l0_brief_1", "l0_brief_1_solo")
	await _beat(0.5)
	await hud.lines(["l0_brief_2", "l0_brief_3"])
	await _beat(0.5)
	await hud.lines(["l0_brief_4", "l0_brief_5"])
	await _beat()

	# Blow off some steam: everyone blocks the punch bag once, then sits back down.
	await _say("l0_bag", "l0_bag_solo")
	hud.notice("Space stands you up. WASD to walk, the mouse to look around", 7.0)
	await _spar_drill()
	hud.todo("Sit back down facing Maddison")
	hud.notice("Look at a seat and press E to sit", 6.0)
	if sync.is_host():
		_watch_seated(players.all_ids(), crew_seated)
	await sync.gate("seated", crew_seated)
	hud.todo("")
	await _beat()
	await _say("l0_bag_back", "l0_bag_back_solo")
	await _beat(0.5)

	# The work order is already in everyone's notebook: each player pulls theirs out.
	await _say("l0_workorder", "l0_workorder_solo")
	hud.todo("Look at the work order in your notebook")
	hud.notice("Press Tab to pull out your notebook", 8.0)
	notebook.opened.connect(_on_notebook_opened, CONNECT_ONE_SHOT)
	await sync.gate("work_order", crew_read_order)
	hud.todo("")
	await _beat(1.5)

	await _say("l0_book_catch", "l0_book_catch_solo")
	await _beat()  # she leaves it hanging; nobody does
	await hud.line("l0_bookstore")
	await _beat(0.5)
	maddison_to("side")  # pointing the way to the shelf
	await _say("l0_grab", "l0_grab_solo")
	book_bag.enabled = true
	hud.todo("Get the book from the shelf by the side door")
	await sync.gate("bag", book_bag.used)
	maddison_to("board")
	hud.todo("")
	await _beat()  # the book in your hands a moment, then chapter zero
	_put_book_down()
	# Chapter zero goes in everyone's notebook; nobody has to stop to read it.
	await Huddle.of(self).run("easy_sql_0")
	await _beat()
	await _say("l0_garage_5", "l0_garage_5_solo")
	maddison_to("van")  # she sees them off at the van door, then stays behind
	van_door.enabled = true
	hud.todo("Get in the van")
	await sync.gate("boarded", crew_boarded)
	await hud.line("l0_garage_6")
	await hud.fade(true, 1.2)
	hud.notice("Halcyon Data Systems. 11:02 p.m.", 3.5, Color(0.9, 0.9, 0.85))
	await get_tree().create_timer(2.5, false).timeout
	player.seated = false
	player.input_locked = false
	_leave()
	await hud.fade(false, 1.0)


## Maddison's line for a crew, or its version for one player.
func _say(crew_id: String, solo_id: String = "") -> void:
	await hud.line(solo_id if solo_id != "" and players.count() == 1 else crew_id)


# --- The walk in -----------------------------------------------------------------

## Every machine: the opening shot. The crew stands where the pre-game lobby left
## them (lobby_spot), the roll-up door goes up, and they walk in and take the
## seats facing the whiteboard; then each player is in their own seat, in first
## person. The figures are stand-ins for the players' own bodies, which wait
## out of sight in their seats.
func open_for_crew() -> void:
	player.input_locked = true
	var ids := players.all_ids()
	for id in ids:
		var body := players.puppet(id)
		if body and body != player:
			body.visible = false
	var walkers: Array[Node3D] = []
	for id in ids:
		var i := NetPlayers.index_of(id, multiplayer)
		var spot := lobby_spot(i)
		var fig := Node3D.new()
		fig.name = "WalkIn%d" % i
		fig.transform = spot.at
		add_child(fig)
		var rig := CharacterRig.build(fig, NetPlayers.look_for(self, id))
		rig.play(_lobby_action(id, spot.pose))
		fig.set_meta("seat", mini(i, crew_seats.size() - 1))
		walkers.append(fig)
	var outside := dusk_outside(environment, self)  # the lobby's sky, so the cut from it doesn't show
	lobby_camera.make_current()
	_prewarm_inside()
	await _beat()
	await roll_door(true)
	var walks: Array[Tween] = []
	for k in walkers.size():
		var fig := walkers[k]
		(fig.get_child(0) as CharacterRig).play("idle")
		walks.append(_walk_in(fig, fig.get_meta("seat"), k * 0.7))
	# Inside once the first of them is through the door.
	await get_tree().create_timer((walkers[0].position.distance_to(WALK_IN[0]) + 1.0) / CharacterRig.WALK_SPEED, false).timeout
	flashback_camera.make_current()
	restore_outside(environment, outside)
	for t in walks:
		if t.is_running():
			await t.finished
	await _beat()
	await hud.fade(true, 0.6)
	for fig in walkers:
		fig.queue_free()
	for id in ids:
		var body := players.puppet(id)
		if body:
			body.visible = true
	await _seat_me(crew_seats[mini(players.my_index(), crew_seats.size() - 1)])
	player.camera.make_current()
	player.input_locked = false
	await hud.fade(false, 0.6)


## Draw the inside of the garage once, off screen, while the lobby shot holds: the
## first time a material is drawn its shaders are built, which stalled the cut
## inside for a few seconds (playtest 2026-10-22). From where the crew watches it
## and from a seat.
func _prewarm_inside() -> void:
	var views: Array[Transform3D] = [flashback_camera.global_transform, crew_seats[0].global_transform.translated(Vector3.UP * 0.75)]
	var shots: Array[SubViewport] = []
	for view in views:
		var shot := SubViewport.new()
		shot.name = "Prewarm"
		shot.size = Vector2i(320, 180)
		shot.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(shot)
		var cam := Camera3D.new()
		shot.add_child(cam)
		cam.global_transform = view
		cam.make_current()
		shots.append(shot)
	for i in 2:
		await RenderingServer.frame_post_draw
	for shot in shots:
		shot.queue_free()


## The rig action a player picked in the lobby (Co-op's Net.lobby_action), or `fallback`.
func _lobby_action(id: int, fallback: String) -> String:
	var net := get_node_or_null("/root/Net")
	if net and net.has_method("lobby_action"):
		return net.lobby_action(id)
	return fallback


## Walk figure `fig` from its lobby spot in through the door to briefing seat
## `seat_i`, starting after `delay` seconds, and sit it down.
func _walk_in(fig: Node3D, seat_i: int, delay: float) -> Tween:
	var top: Vector3 = CREW_SEATS[seat_i]
	var route: Array = WALK_IN.duplicate()
	if top.y < 0.6:  # the couch: round its north end to the front
		route.append(Vector3(COUCH.x - 0.9, 0, WALK_IN[-1].z))
		route.append(Vector3(COUCH.x - 0.9, 0, top.z))
	else:  # a stool: between the stools and the couch's back
		route.append(Vector3(top.x - 0.6, 0, top.z))
	var t := create_tween()
	t.tween_interval(delay)
	var from := fig.position
	for to in route:
		t.tween_callback(_face.bind(fig, to))
		t.tween_property(fig, "position", to, from.distance_to(to) / CharacterRig.WALK_SPEED)
		from = to
	var sat := Vector3(top.x, top.y - 0.45, top.z)  # the rig sits 0.45 m up
	t.tween_callback(func():
		fig.rotation.y = PI / 2  # facing the whiteboard
		(fig.get_child(0) as CharacterRig).play("sit"))
	t.tween_property(fig, "position", sat, 0.4)
	return t


## Sit this machine's player in `seat`, facing the whiteboard.
func _seat_me(seat: Seat) -> void:
	if player.is_sitting():
		player.stand_up(true)
	player.velocity = Vector3.ZERO
	var front := seat.global_position - seat.global_basis.z * 0.55  # just in front of it, where you'd stand to sit
	player.global_transform = Transform3D(seat.global_basis, Vector3(front.x, seat.global_position.y - CREW_SEATS[0].y + 0.05, front.z))
	for i in 30:
		await get_tree().physics_frame
		if player.sit(seat):
			return


# --- Back in their seats ------------------------------------------------------------

## Host: emit `done` once every player in `ids` is sitting in a briefing seat.
func _watch_seated(ids: Array, done: Signal) -> void:
	await get_tree().process_frame  # the story's gate is listening by then
	var shown := -1
	while is_inside_tree():
		var n := 0
		for id in ids:
			if _in_a_seat(players.puppet(id)):
				n += 1
		if n >= ids.size():
			done.emit()
			return
		if n != shown and ids.size() > 1:
			shown = n
			sync.team_notice("Waiting for the crew to sit down (%d/%d)" % [n, ids.size()], 4.0)
		await get_tree().create_timer(0.25, false).timeout


func _in_a_seat(body: Node3D) -> bool:
	if body == null:
		return false
	for seat in crew_seats:
		var off := body.global_position - seat.global_position
		if Vector2(off.x, off.z).length() < 0.3 and absf(off.y) < 0.3:
			return true
	return false


## This machine's player pulled out their notebook: tell the host.
func _on_notebook_opened() -> void:
	if not sync.forward(self, "report_open"):
		report_open(player)


## Host: `who` has looked at the work order.
func report_open(who: Node) -> void:
	var id := players.id_of(who)
	if id != 0 and not read_order.has(id):
		sync.event("_on_read_order", [id])


func _on_read_order(id: int) -> void:
	if read_order.has(id):
		return
	read_order.append(id)
	var total := players.count()
	if read_order.size() < total and body_is_mine(id):
		hud.notice("Waiting for the crew to read it (%d/%d)" % [read_order.size(), total], 4.0)
	if read_order.size() >= total and sync.is_host():
		crew_read_order.emit()


## Everyone blocks the punch bag once: hit it, and it swings back at you. The host
## hears the hit and starts the swing; every machine sees it, and each player's own
## machine decides their block.
func _spar_drill() -> void:
	hud.todo(SPAR_TODO)
	hud.notice(SPAR_NOTICE, 8.0)
	_sparring = true
	player.combat.guard_raised.connect(_on_guard_raised)
	if sync.is_host():
		_run_bag()
	await sync.gate("sparred", crew_sparred)
	_sparring = false
	player.combat.guard_raised.disconnect(_on_guard_raised)
	hud.todo("")


## Host: until everyone has blocked it, a hit sends the bag back at whoever hit it.
func _run_bag() -> void:
	crew.hit_blocked.connect(_on_hit_blocked)
	punch_bag.struck.connect(_on_bag_struck)
	while spar_blocked.size() < players.count():
		await get_tree().create_timer(0.25, false).timeout
		if not is_inside_tree():
			return
	punch_bag.struck.disconnect(_on_bag_struck)
	crew.hit_blocked.disconnect(_on_hit_blocked)
	crew_sparred.emit()


## Host: someone hit the bag. Unless it's mid-swing, it swings back at them.
func _on_bag_struck(by: Node) -> void:
	var id := players.id_of(by)
	if id == 0 or spar_target != 0 or spar_blocked.has(id):
		return
	sync.event("_swing_bag", [id])


func _on_guard_raised() -> void:
	_guard_at = player.combat.now()


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Every machine: hit by player `id`, the bag flies away from them, then swings back in at them.
func _swing_bag(id: int) -> void:
	var body := players.puppet(id)
	if body == null:
		return
	var to := body.global_position - punch_bag.global_position
	var dir := Vector3(to.x, 0, to.z).normalized()
	if dir == Vector3.ZERO:
		dir = Vector3.FORWARD
	var axis := (global_basis.inverse() * dir).cross(Vector3.UP).normalized()
	var tilt := func(a: float): punch_bag.basis = Basis(axis, a)
	spar_target = id
	Sfx.play(punch_bag, "bag_hit", Vector3(0, -1.1, 0))  # the punch landing, heard by everyone
	if body_is_mine(id):
		_swing_at = player.combat.now()
	if _bag_swing:
		_bag_swing.kill()  # hit again while it settles: this swing takes over
	var t := create_tween()
	_bag_swing = t
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # on the guard's clock
	t.tween_method(tilt, 0.0, -0.6, SPAR_TELL).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): swing_in = true)
	t.tween_method(tilt, -0.6, 0.45, SPAR_SWING).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(_bag_lands.bind(id))
	t.tween_method(tilt, 0.45, 0.0, SPAR_SWING * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Every machine: the bag reaches player `id`. Only their own machine decides the block.
func _bag_lands(id: int) -> void:
	swing_in = false
	spar_target = 0
	if body_is_mine(id) and _flat_distance(player.global_position, to_global(PUNCH_BAG)) < SPAR_REACH + 0.5:
		if player.take_damage(0.0, "spar") == "hit" and _sparring:
			hud.notice(SPAR_EARLY if _guard_at >= _swing_at else SPAR_MISS, 4.0)


func body_is_mine(id: int) -> bool:
	return players.puppet(id) == player


## Host: someone blocked. The bag leaves them be from now on.
func _on_hit_blocked(id: int, cause: String) -> void:
	if cause == "spar" and not spar_blocked.has(id):
		sync.event("_on_sparred", [id])


func _on_sparred(id: int) -> void:
	if not spar_blocked.has(id):
		spar_blocked.append(id)
	var total := players.count()
	if body_is_mine(id):  # so you know it landed (playtest: blocks went unnoticed)
		if spar_blocked.size() < total:
			hud.notice(SPAR_BLOCKED + " Waiting for the crew at the punch bag (%d/%d)" % [spar_blocked.size(), total], 4.0)
		else:
			hud.notice(SPAR_BLOCKED, 2.5)


## Every machine: player `id` took the shop bag with the book in it.
func _on_bag(id: int) -> void:
	book_bag.visible = false
	book_bag.enabled = false
	book_holder = id
	get_node("/root/Game").before_book = false
	get_node("/root/Game").notebook_changed.emit()
	sync.unlock_for([id], "achievement:book_easy_sql")  # its notebook cover, for whoever picked it up (host)
	# The book in their hands, as the notebook is: in first person for them, at
	# chest height for everyone else.
	if body_is_mine(id):
		held_book = _book(player.camera, HELD_BOOK.origin)
		held_book.basis = HELD_BOOK.basis
		held_book.add_to_group("carried")  # held in your own hands (FirstPersonBody)
		hud.todo("Sit down with the book")
	else:
		var body := players.puppet(id)
		if body:
			held_book = _book(body, Vector3(0, 1.1, -0.32))
			held_book.rotation.x = 1.1
		hud.todo("Wait for the book")


## Every machine: the book's on Maddison's whiteboard now, out of their hands.
func _put_book_down() -> void:
	if held_book:
		held_book.queue_free()
		held_book = null


## Host: a player climbs into the van. Everyone sees them take the next seat.
func _on_van_door(p: Node) -> void:
	var id := players.id_of(p)
	if boarded.has(id):
		return
	sync.event("_on_boarded", [id])


func _on_boarded(id: int) -> void:
	if boarded.has(id):
		return
	boarded.append(id)
	get_node("/root/Game").van_seating.append(id)  # Level 0 seats them the same way
	var body := players.puppet(id)
	var seat := to_global(van_seats[(boarded.size() - 1) % van_seats.size()])
	if body == player:
		player.stand_up(true)  # off a briefing seat, if they climbed in from one
		player.global_position = seat
		player.velocity = Vector3.ZERO
		player.rotation.y = global_rotation.y  # facing the windscreen
		player.seated = true
		if not sync.is_host():
			van_door.enabled = false  # the host's door still takes the others' climbs (forwarded)
	elif body:
		body.global_position = seat
	var total := players.count()
	if boarded.size() >= total:
		van_door.enabled = false
	if boarded.size() < total:
		hud.notice("In the van. Waiting for the crew (%d/%d)" % [boarded.size(), total], 600.0)
	elif sync.is_host():
		crew_boarded.emit()


## Off to the job. In the World the van pulls up at Halcyon (Level 0); on its own,
## the garage starts the World there.
func _leave() -> void:
	if world:
		world.call("leave_home")
	else:
		get_node("/root/Game").open_at_home = false
		get_node("/root/Game").goto("world")


# --- The World's garage ------------------------------------------------------------

## The garage `level` keeps out of sight: its own, or one built for it.
static func for_flashback(level: Node) -> HomeBase:
	var home := level.get_node_or_null("HomeBase")
	if home is HomeBase:
		return home
	home = load(SCENE).instantiate()
	home.name = "HomeBase"
	home.transform = AT
	level.add_child(home)
	home.visible = false
	return home
