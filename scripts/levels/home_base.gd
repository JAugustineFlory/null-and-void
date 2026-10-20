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
## Graphics dresses it; DressHomeBase can hook in at the end of build().

## Where the garage sits in the World: well away from the tower and its car park.
const AT := Transform3D(Basis(), Vector3(-300, 0, -300))
const SCENE := "res://scenes/home_base.tscn"
const BENCH := Vector3(-2.5, 0, -1.0)
const VAN := Vector3(2.8, 0, 0.3)
## Where the crew stand round the bench in a flashback, facing it.
const HUDDLE_SPOTS := [Vector3(-3.2, 0, -0.1), Vector3(-1.8, 0, -0.1), Vector3(-3.2, 0, -1.9),
	Vector3(-1.8, 0, -1.9), Vector3(-4.1, 0, -1.0), Vector3(-0.9, 0, -1.0)]

var fax: Interactable
var book_bag: Interactable
var van_door: Interactable
## The book on the workbench, once someone has brought it over.
var bench_book: Node3D
## The camera a flashback looks through, and the crew it sees round the bench.
var flashback_camera: Camera3D
var _figures: Array[Node3D] = []
## Van seats in boarding order (level-local), and who has climbed in.
var van_seats: Array[Vector3] = []
var boarded: Array = []
signal crew_boarded


func build() -> void:
	var concrete := Color(0.42, 0.42, 0.4)
	var block := Color(0.6, 0.6, 0.56)
	# The garage: x -5.5..5.5, z -4.5..4.5. The roll-up door is the north wall.
	Greybox.room(geo, Vector3.ZERO, Vector3(11, 3.4, 9), {"floor": concrete, "wall": block})
	Greybox.panel(geo, Vector3(1.5, 1.5, -4.38), Vector3(6.0, 3.0, 0.05), Color(0.7, 0.7, 0.68))  # roll-up door
	for i in 6:
		Greybox.panel(geo, Vector3(1.5, 0.25 + i * 0.5, -4.35), Vector3(6.0, 0.03, 0.02), Color(0.5, 0.5, 0.48))
	Greybox.label(geo, Vector3(-2.5, 2.6, 4.38), "BYTE-RIGHT IT SERVICES", 72, Color(0.1, 0.3, 0.6), 180)

	# The workbench in the middle of the floor: where the crew huddles.
	Greybox.box(geo, BENCH + Vector3(0, 0.475, 0), Vector3(2.4, 0.95, 1.0), Color(0.45, 0.33, 0.22), "Workbench")
	bench_book = _book(geo, BENCH + Vector3(0.2, 0.99, 0.1))
	bench_book.name = "BenchBook"
	bench_book.visible = false

	# The office corner: a desk with the fax machine and the radio base station.
	Greybox.box(geo, Vector3(-4.9, 0.4, 2.6), Vector3(0.9, 0.8, 1.8), Color(0.35, 0.3, 0.25), "Desk")
	Greybox.box(geo, Vector3(-4.95, 0.95, 3.2), Vector3(0.45, 0.3, 0.35), Color(0.15, 0.15, 0.16), "Radio")
	fax = Interactable.create(self, Vector3(-4.85, 0.93, 2.3), Vector3(0.45, 0.26, 0.4), "Tear off the work order", Color(0.82, 0.8, 0.74))
	fax.name = "Fax"
	fax.enabled = false
	fax.used.connect(func(_p): sync.event("_on_fax"))

	# The back corner, under a dead bulb: the shelf where the shop bag was left.
	Greybox.box(geo, Vector3(-5.0, 0.5, -3.4), Vector3(0.7, 1.0, 1.6), Color(0.3, 0.3, 0.32), "Shelf")
	Greybox.panel(geo, Vector3(-4.6, 2.75, -3.4), Vector3(0.02, 1.3, 0.02), Color(0.1, 0.1, 0.1))  # the cord
	Greybox.panel(geo, Vector3(-4.6, 2.05, -3.4), Vector3(0.1, 0.14, 0.1), Color(0.35, 0.35, 0.33))  # the dead bulb
	book_bag = Interactable.create(self, Vector3(-4.9, 1.15, -3.3), Vector3(0.4, 0.3, 0.15), "Take the shop bag", Color(0.85, 0.85, 0.8))
	book_bag.name = "BookBag"
	book_bag.enabled = false
	book_bag.used.connect(func(_p): sync.event("_on_bag"))

	_build_van(VAN)

	var bulb := Color(1.0, 0.88, 0.7)
	add_light("garage", BENCH + Vector3(0, 3.4, 0), 3.6, 1.2, bulb)
	add_light("garage", Vector3(-4.0, 3.4, 2.8), 3.5, 1.0, bulb)
	add_light("garage", VAN + Vector3(0, 3.4, 0), 5.0, 1.0, bulb)

	flashback_camera = Camera3D.new()
	flashback_camera.name = "FlashbackCamera"
	add_child(flashback_camera)
	flashback_camera.position = BENCH + Vector3(1.6, 2.3, 3.0)
	flashback_camera.look_at_from_position(flashback_camera.position, BENCH + Vector3(1.2, 0.6, 0), Vector3.UP)
	spawn = Transform3D(Basis(), Vector3(-0.5, 0.1, 3.0))
	DressHomeBase.apply(self)  # furniture and materials (Graphics thread)


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
	env.ambient_light_energy = 0.12
	env.fog_density = 0.01


## The garage's own story: the controls on small chores, the first huddle, the van.
func start() -> void:
	player.flashlight.visible = false
	hud.notice("WASD to walk, the mouse to look around", 6.0)
	await get_tree().create_timer(1.5, false).timeout
	await hud.lines(["l0_garage_1", "l0_garage_2"])
	fax.enabled = true
	hud.todo("Get the work order off the fax")
	hud.notice("Look at the fax machine and press E", 6.0)
	await sync.gate("fax", fax.used)
	await hud.lines(["l0_garage_3", "l0_garage_4"])
	book_bag.enabled = true
	hud.todo("Find the book in the back corner")
	hud.notice("It's dark back there. F turns your flashlight on and off", 6.0)
	await sync.gate("bag", book_bag.used)
	hud.todo("Huddle round the workbench")
	var bench := Trigger.create(self, BENCH + Vector3(0, 1, 0), Vector3(5.5, 2, 4.2))
	bench.require_all = true
	bench.waiting.connect(func(n, total): sync.team_notice("Waiting for the crew at the workbench (%d/%d)" % [n, total]))
	await sync.gate("huddle", bench.entered)
	hud.todo("")
	await Huddle.of(self).run("easy_sql_0", Huddle.HERE)
	await hud.line("l0_garage_5")
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


func _on_fax() -> void:
	fax.enabled = false
	fax.prompt = ""
	hud.todo("")
	hud.notice("Your notebook holds the work order. Tab opens it, and Tab puts it away", 6.0)


func _on_bag() -> void:
	book_bag.visible = false
	book_bag.enabled = false
	bench_book.visible = true
	hud.todo("")


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


## Show the crew round the workbench, as many as are playing, and look through
## the flashback camera.
func start_flashback(crew: int) -> void:
	visible = true
	bench_book.visible = true
	for i in clampi(crew, 1, HUDDLE_SPOTS.size()):
		var spot := Node3D.new()
		spot.name = "Crew%d" % i
		add_child(spot)
		spot.position = HUDDLE_SPOTS[i]
		var to := BENCH - spot.position
		spot.rotation.y = atan2(-to.x, -to.z)
		var rig := CharacterRig.build(spot, CharacterLooks.crew(i))
		rig.play("talk" if i == 0 else "idle")
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
