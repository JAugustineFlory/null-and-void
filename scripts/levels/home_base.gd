class_name HomeBase
extends LevelBase
## The crew's garage: Byte-Right IT Services' home base, the evening of the job.
## The game opens here. It teaches the controls on ordinary chores (pull the work
## order off the fax, find the book in the dark back corner), then the crew
## huddles round the workbench for the book's first chapter and gets in the van.
## The drive cuts to the van in Halcyon's car park (Level 0).
##
## Later, when the building needs a new SQL word, the game flashes back here: the
## same workbench, the crew round the book (see Huddle). The garage stays loaded
## out of sight for that, far from the tower.
##
## Before the huddle, the punch bag by the roll-up door teaches blocking safely:
## it swings back at you, and right-clicking as it comes in blocks it. A miss
## costs nothing. Everyone blocks it once before the crew huddles.
##
## Maddison, the boss, is on her feet in here: she walks the crew round the
## chores in the opening and stands at the bench in every flashback.
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
const CREW_SEATS := [Vector3(-4.4, 0.45, 0.0), Vector3(-4.4, 0.45, -1.0), Vector3(-4.4, 0.45, 1.0),
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
## Where the punch bag hangs from its ceiling hook (on the floor below it).
const PUNCH_BAG := Vector3(0.8, 0, -3.6)
## The bag swings at whoever stands within this of it.
const SPAR_REACH := 2.2
## The pull back before a swing (the tell), then the swing in: right-click during the
## swing in. It's shorter than the guard (Guard.WINDOW), so a press anywhere in it blocks.
const SPAR_TELL := 0.7
const SPAR_SWING := 0.3
## Between swings.
const SPAR_GAP := 1.6
## Lines for Augustine's approval: see plan/approvals/home-base-huddles.md.
const SPAR_NOTICE := "The punch bag swings back. Stand by it and right-click just as it comes at you to block"
const SPAR_MISS := "Too early or too late. Right-click as it swings in"
## Maddison's marks: where she stands for each beat, and the point she faces there.
## She comes in by the side door to the house; "board" is beside her whiteboard,
## facing the crew.
const MADDISON_MARKS := {
	"door": [Vector3(-7.2, 0, 4.6), Vector3(0, 0, 4.6)],
	"greet": [Vector3(-6.4, 0, 2.2), Vector3(-3.0, 0, 0.0)],
	"fax": [Vector3(-6.4, 0, -4.6), Vector3(-7.35, 0, -4.6)],
	"board": [Vector3(-7.1, 0, 1.6), Vector3(-3.0, 0, 0.0)],
	"bench": [Vector3(2.1, 0, 3.6), BENCH],
	"van": [Vector3(2.4, 0, 0.8), Vector3(3.3, 0, -0.5)],
}
## Round the bench's west end: the way past it when it's in her way.
const BENCH_WAY := Vector3(-1.4, 0, 2.6)
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
## The punch bag's hook: it swings about this point.
var punch_bag: Node3D
## Who the bag is swinging at (0: nobody), and whether it's coming in now.
var spar_target := 0
var swing_in := false
## Who has blocked it (host decides; every machine hears).
var spar_blocked: Array = []
signal crew_sparred
## The book on the workbench, once someone has brought it over.
var bench_book: Node3D
## The camera a flashback looks through, and the crew it sees in the seats.
var flashback_camera: Camera3D
## The pre-game lobby's shot of the garage front (LOBBY_CAMERA): the opening starts on it.
var lobby_camera: Camera3D
var _figures: Array[Node3D] = []
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
	fax = Interactable.create(self, DESK + Vector3(0.05, 0.93, -0.4), Vector3(0.45, 0.26, 0.4), "Tear off the work order", Color(0.82, 0.8, 0.74))
	fax.name = "Fax"
	fax.enabled = false
	fax.used.connect(func(_p): sync.event("_on_fax"))

	# The back corner by the side door: the shelf where the shop bag was left.
	Greybox.box(geo, SHELF + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 0.7), Color(0.3, 0.3, 0.32), "Shelf")
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
	flashback_camera.position = Vector3(-0.8, 2.4, 2.6)
	flashback_camera.look_at_from_position(flashback_camera.position, Vector3(-6.0, 1.0, 0.0), Vector3.UP)
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
	return front


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


## Maddison walks to `mark` (see MADDISON_MARKS), round the bench if it's in the
## way, at her unhurried pace. Await it to wait until she's there.
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


func maddison_to(mark: String) -> void:
	if _maddison_walk:
		_maddison_walk.kill()
	var to_mark: Vector3 = MADDISON_MARKS[mark][0]
	var route: Array[Vector3] = []
	if _crosses_bench(maddison.position, to_mark):
		route.append(BENCH_WAY)
	route.append(to_mark)
	maddison_mark = mark
	_maddison_walk = create_tween()
	var from := maddison.position
	for to in route:
		_maddison_walk.tween_callback(_face.bind(maddison, to))
		_maddison_walk.tween_property(maddison, "position", to, from.distance_to(to) / (CharacterRig.WALK_SPEED * MADDISON_PACE))
		from = to
	_maddison_walk.tween_callback(_face.bind(maddison, MADDISON_MARKS[mark][1]))
	await _maddison_walk.finished


## Whether a straight walk from `a` to `b` would go through the workbench.
static func _crosses_bench(a: Vector3, b: Vector3) -> bool:
	var box := Rect2(BENCH.x - 1.5, BENCH.z - 0.8, 3.0, 1.6)
	for i in 21:
		var at := a.lerp(b, i / 20.0)
		if box.has_point(Vector2(at.x, at.z)):
			return true
	return false


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


## A heavy bag on a chain from a ceiling hook, out of the way by the roll-up door.
## It isn't under geo: it moves, and nobody should bump into it.
func _build_punch_bag(at: Vector3) -> void:
	punch_bag = Node3D.new()
	punch_bag.name = "PunchBag"
	punch_bag.position = at + Vector3(0, 3.35, 0)
	add_child(punch_bag)
	var chain := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.03, 1.4, 0.03)
	chain.mesh = cm
	chain.position = Vector3(0, -0.7, 0)
	chain.material_override = Greybox.mat(Color(0.3, 0.3, 0.3))
	punch_bag.add_child(chain)
	var bag := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.22
	bm.bottom_radius = 0.22
	bm.height = 1.1
	bag.mesh = bm
	bag.position = Vector3(0, -1.95, 0)  # chest height: 0.85 m to 1.95 m off the floor
	bag.material_override = Greybox.mat(Color(0.55, 0.12, 0.1))
	punch_bag.add_child(bag)


## A paperback with the teal cover: Easy SQL. Graphics swaps in ArtKit.easy_sql_book via DressHomeBase.
static func _book(parent: Node3D, at: Vector3) -> Node3D:
	var book := Node3D.new()
	book.position = at
	parent.add_child(book)
	var cover := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.19, 0.03, 0.25)
	cover.mesh = bm
	cover.material_override = Greybox.mat(HuddleUI.COVER)
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


## The garage's own story: the controls on small chores, the first huddle, the van.
func start() -> void:
	player.flashlight.visible = false
	hud.notice("WASD to walk, the mouse to look around", 6.0)
	await _beat(1.5)
	await maddison_to("greet")  # in from the house, waving the printout
	await hud.line("l0_garage_1")
	await _beat()
	maddison_to("fax")
	await hud.line("l0_garage_2")
	await _beat(0.5)
	fax.enabled = true
	hud.todo("Get the work order off the fax")
	hud.notice("Look at the fax machine and press E", 6.0)
	await sync.gate("fax", fax.used)
	await _beat()
	maddison_to("bench")
	await hud.lines(["l0_garage_3", "l0_garage_4"])
	await _beat(0.5)
	book_bag.enabled = true
	hud.todo("Find the book in the back corner")
	await sync.gate("bag", book_bag.used)
	await _beat()
	await _spar_drill()
	await _beat()
	hud.todo("Huddle round the workbench")
	var bench := Trigger.create(self, BENCH + Vector3(0, 1, 0), Vector3(5.5, 2, 4.2))
	bench.require_all = true
	bench.waiting.connect(func(n, total): sync.team_notice("Waiting for the crew at the workbench (%d/%d)" % [n, total]))
	await sync.gate("huddle", bench.entered)
	hud.todo("")
	await Huddle.of(self).run("easy_sql_0", Huddle.HERE)
	await _beat()
	await hud.line("l0_garage_5")
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


## Everyone blocks the punch bag once. The host picks who it swings at; every
## machine sees the swing, and each player's own machine decides their block.
func _spar_drill() -> void:
	hud.todo("Block the punch bag")
	hud.notice(SPAR_NOTICE, 8.0)
	if sync.is_host():
		_run_bag()
	await sync.gate("sparred", crew_sparred)
	hud.todo("")


## Host: swing at someone by the bag who hasn't blocked it yet, until everyone has.
func _run_bag() -> void:
	crew.hit_blocked.connect(_on_hit_blocked)
	while spar_blocked.size() < players.count():
		await get_tree().create_timer(SPAR_GAP, false).timeout
		if not is_inside_tree():
			return
		var id := _spar_pick()
		if id != 0:
			sync.event("_swing_bag", [id])
			await get_tree().create_timer(SPAR_TELL + SPAR_SWING * 2.0, false).timeout
	crew.hit_blocked.disconnect(_on_hit_blocked)
	crew_sparred.emit()


func _spar_pick() -> int:
	var best := 0
	var best_d := SPAR_REACH
	for id in players.all_ids():
		var body := players.puppet(id)
		if spar_blocked.has(id) or body == null:
			continue
		var d := _flat_distance(body.global_position, to_global(PUNCH_BAG))
		if d < best_d:
			best = id
			best_d = d
	return best


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Every machine: the bag pulls back away from player `id`, then swings in at them.
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
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # on the guard's clock
	t.tween_method(tilt, 0.0, -0.45, SPAR_TELL).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): swing_in = true)
	t.tween_method(tilt, -0.45, 0.3, SPAR_SWING).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(_bag_lands.bind(id))
	t.tween_method(tilt, 0.3, 0.0, SPAR_SWING * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Every machine: the bag reaches player `id`. Only their own machine decides the block.
func _bag_lands(id: int) -> void:
	swing_in = false
	spar_target = 0
	if body_is_mine(id) and _flat_distance(player.global_position, to_global(PUNCH_BAG)) < SPAR_REACH + 0.5:
		if player.take_damage(0.0, "spar") == "hit":
			hud.notice(SPAR_MISS, 3.0)


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
	if spar_blocked.size() < total and body_is_mine(id):
		hud.notice("Waiting for the crew at the punch bag (%d/%d)" % [spar_blocked.size(), total], 4.0)


func _on_fax() -> void:
	fax.enabled = false
	fax.prompt = ""
	hud.todo("")
	hud.notice("Your notebook holds the work order. Tab opens it, and Tab puts it away", 6.0)


## Every machine: player `id` took the shop bag with the book in it.
func _on_bag(id: int) -> void:
	book_bag.visible = false
	book_bag.enabled = false
	bench_book.visible = true
	hud.todo("")
	sync.unlock_for([id], "achievement:book_easy_sql")  # its notebook cover, for whoever picked it up (host)


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
		player.global_position = seat
		player.velocity = Vector3.ZERO
		player.rotation.y = global_rotation.y  # facing the windscreen
		player.seated = true
		van_door.enabled = false
	elif body:
		body.global_position = seat
	var total := players.count()
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


# --- Flashbacks -----------------------------------------------------------------

## The garage a flashback cuts to: the World's, or one built for `level` if it
## has none (a level run on its own).
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


## Show the crew in the seats facing Maddison at her whiteboard, as many as are
## playing, and look through the flashback camera.
func start_flashback(crew: int) -> void:
	visible = true
	maddison_at("board")
	for i in clampi(crew, 1, CREW_SEATS.size()):
		var spot := Node3D.new()
		spot.name = "Crew%d" % i
		var top: Vector3 = CREW_SEATS[i]
		spot.position = Vector3(top.x, top.y - 0.45, top.z)  # the rig sits 0.45 m up
		spot.rotation.y = PI / 2  # facing the whiteboard
		add_child(spot)
		var rig := CharacterRig.build(spot, CharacterLooks.crew(i))
		rig.play("sit")
		_figures.append(spot)
	flashback_camera.make_current()


## Back to the present: the figures go and `camera` takes over again.
func end_flashback(camera: Camera3D) -> void:
	for f in _figures:
		f.queue_free()
	_figures.clear()
	flashback_camera.clear_current(false)
	if camera:
		camera.make_current()
	visible = active and not (world and world.get("current") != self)
