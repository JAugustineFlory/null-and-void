extends LevelBase
## Level 2: Security Office, "Who Badged In?"
## Teaches LIKE (with LIMIT and COUNT along the way), a first taste of HTTP with
## GET /cameras, and the first terminal lie: a camera that says "live" but froze.
## The Watcher moves only when nobody, person or working camera, is looking at it.
##
## The stairwell door is the second lie: the keypad says "opened", but a tripped
## breaker jammed its actuator. The vestibule panel's sensor data says so.
##
## Layout (north is -z): stair landing (spawn) > corridor with the security booth >
## Security Office (the Watcher) > exit vestibule > stairwell. Three ways from the
## corridor to the vestibule: through the office, the vent over the crate, or the
## smashed window and the ledge outside. The keypad PIN is needed on every route.

## Fired at the bottom of the stairs: the wing is done. A streamed world can
## take over from here; on its own, the level goes to Field Notes.
signal completed

const CLOCK_START := 41 * 60  # 00:41:00
## Where each camera can see, as boxes. Only working cameras hold the Watcher.
var cam_zones := {
	"CAM-2": [AABB(Vector3(-6, -1, -8), Vector3(12, 6, 10))],
	"CAM-3": [AABB(Vector3(-2.5, -1, -12), Vector3(5, 6, 4))],
	"CAM-5": [AABB(Vector3(6.1, -3, -8.6), Vector3(0.6, 8, 13.2)), AABB(Vector3(2.6, -3, -9.6), Vector3(3.6, 8, 1.6))],
}
var frozen_cams := {}

var data: Dictionary
var watcher: Watcher
var booth: Terminal
var panel: Terminal
var api: FacilityAPI
var breakers := {}
var keypad_ui: Level2Keypad
var exit_keypad: Interactable
var seal_keypad: Interactable
var watcher_home := Vector3(3, 0, -5)
var loose := false  # CAM-2 has frozen and the Watcher is free
var reached_vestibule := false
var pin_entered := false
var door_open := false  # physically open
var door_checked := false
var _clock := 0.0
var _cam_tick := 0.0
var _lie_explained := false
var _warned := {}
var _seal_mode := false
var _glass: Array[RID] = []
var _exit_trigger: Trigger

var cameras_puzzle := Puzzle.new("cameras", "", [], false, [
	"Type this, then press Enter:\n" +
	"    [color=#ffffff]GET /cameras[/color]\n" +
	"  GET       ask the security server to send you something (it only reads, it changes nothing)\n" +
	"  /cameras  the address of the camera list\n" +
	"The answer is JSON: { } holds one camera's fields, [ ] holds a list of them.",
	"Read each camera's status and motion. motion: true means that camera sees something moving.",
])
var pike_puzzle := Puzzle.new("pike", "SELECT name FROM guards WHERE name LIKE 'Pike%'", ["name"], false, [
	"Type this, then press Enter:\n" +
	"    [color=#ffffff]SELECT * FROM guards WHERE name LIKE 'Pike%';[/color]\n" +
	"  SELECT *         every column\n" +
	"  FROM guards      from the guard roster\n" +
	"  WHERE name LIKE  keep rows whose name matches a pattern\n" +
	"  'Pike%'          starts with Pike. % stands for any letters (or none) after it",
	"LIKE ignores capitals, so 'pike%' works too. Text patterns go in 'single quotes'.",
])
var door_puzzle := Puzzle.new("door", "", [], false, [
	"Type this, then press Enter:\n" +
	"    [color=#ffffff]GET /doors/SEC-EXIT[/color]\n" +
	"  GET               ask the security server for data\n" +
	"  /doors/SEC-EXIT   one door's record: what was asked of it, and what its sensor says",
	"locked is what the keypad asked for. sensor and actuator are what the door is actually doing. " +
	"The note says which breaker to reset. The breaker box is on the wall by the vent.",
])
var har_puzzle := Puzzle.new("har", "SELECT pin FROM guards WHERE name LIKE 'Har%' AND shift = 'night'", ["pin"], false, [
	"Type this, then press Enter:\n" +
	"    [color=#ffffff]SELECT * FROM guards WHERE name LIKE 'Har%' AND shift = 'night';[/color]\n" +
	"  SELECT * FROM guards    every column of the guard roster\n" +
	"  WHERE name LIKE 'Har%'  names that START with Har (all you can read on the sheet)\n" +
	"  AND shift = 'night'     ...who ALSO work nights: it's the night-shift sign-in sheet",
	"The pin column is the code for the stairwell keypad, past the far end of the Security Office. " +
	"Other Har- guards work other shifts or are retired: read their note column.",
	"Lost track of it? GET /cameras shows which cameras see motion. Compare each last_frame with server_time: " +
	"a camera whose picture stopped updating can't see anything, whatever its status says.",
])


func build() -> void:
	data = Level2Data.build(Game.run_seed)
	db.load_seed(data.sql)
	keypad_ui = Level2Keypad.new()
	add_child(keypad_ui)
	keypad_ui.submitted.connect(_on_pin)

	var floor_c := Color(0.27, 0.27, 0.3)
	var wall_c := Color(0.52, 0.53, 0.5)
	var office_wall := Color(0.46, 0.48, 0.5)
	# Stair landing (spawn): x 2.5..5.5, z 6..10
	Greybox.room(geo, Vector3(4, 0, 8), Vector3(3, 3.2, 4), {"floor": floor_c, "wall": wall_c}, [
		{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4},
	])
	Greybox.label(geo, Vector3(4, 2.7, 9.88), "FROM SERVER ROOM A", 40, Color(0.2, 0.2, 0.2), 180)
	# Corridor: x -6..6, z 2..6
	Greybox.room(geo, Vector3(0, 0, 4), Vector3(12, 3.2, 4), {"floor": floor_c, "wall": wall_c}, [
		{"wall": "s", "at": 4.0, "width": 1.8, "height": 2.4},
		{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "n", "at": -3.0, "width": 2.4, "height": 2.2, "bottom": 1.0},
		{"wall": "w", "at": 0.0, "width": 1.0, "height": 3.0, "bottom": 2.0},
		{"wall": "e", "at": 0.0, "width": 1.1, "height": 1.0},
	])
	# Security Office: x -6..6, z -8..2
	Greybox.room(geo, Vector3(0, 0, -3), Vector3(12, 3.2, 10), {"floor": Color(0.2, 0.22, 0.26), "wall": office_wall}, [
		{"wall": "s", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "s", "at": -3.0, "width": 2.4, "height": 2.2, "bottom": 1.0},
		{"wall": "n", "at": 0.0, "width": 1.6, "height": 2.4},
	])
	Greybox.label(geo, Vector3(0, 2.75, 1.88), "SECURITY OFFICE", 64, Color(0.75, 0.75, 0.7), 180)
	_glass_pane(Vector3(-3, 2.1, 2), Vector3(2.4, 2.2, 0.05))
	# Exit vestibule: x -2.5..2.5, z -12..-8
	Greybox.room(geo, Vector3(0, 0, -10), Vector3(5, 3.2, 4), {"floor": floor_c, "wall": wall_c}, [
		{"wall": "s", "at": 0.0, "width": 1.6, "height": 2.4},
		{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "w", "at": 0.0, "width": 1.0, "height": 3.0, "bottom": 2.0},
		{"wall": "e", "at": 1.25, "width": 1.2, "height": 1.0},
	])
	# Stairwell: x -2..2, z -17..-12
	Greybox.room(geo, Vector3(0, 0, -14.5), Vector3(4, 3.2, 5), {"floor": floor_c, "wall": wall_c}, [
		{"wall": "s", "at": 0.0, "width": 1.8, "height": 2.4},
	])
	Greybox.label(geo, Vector3(0, 2.6, -16.88), "STAIRS  -  RECORDS ARCHIVE", 48, Color(0.1, 0.8, 0.2))
	add_door("SEC-EXIT", Vector3(0, 1.2, -12), Vector3(1.8, 2.4, 0.15))
	Greybox.label(geo, Vector3(0, 2.75, -11.88), "SEC-EXIT", 56, Color(0.85, 0.2, 0.15))

	api = _make_api()
	_build_booth()
	_build_office()
	_build_vent()
	_build_ledge()

	exit_keypad = Interactable.create(geo, Vector3(1.3, 1.3, -11.85), Vector3(0.25, 0.3, 0.06), "Enter guard PIN", Color(0.15, 0.15, 0.12))
	exit_keypad.used.connect(_on_exit_keypad)
	Greybox.label(geo, Vector3(1.3, 1.55, -11.81), "GUARD PIN", 40, Color(0.9, 0.8, 0.3))
	_build_panel()
	seal_keypad = Interactable.create(geo, Vector3(1.3, 1.3, -12.15), Vector3(0.25, 0.3, 0.06), "Lock SEC-EXIT behind you (guard PIN)", Color(0.15, 0.15, 0.12))
	seal_keypad.used.connect(_on_seal_keypad)
	Greybox.label(geo, Vector3(1.3, 1.55, -12.19), "LOCK", 40, Color(0.9, 0.8, 0.3), 180)

	add_light("landing", Vector3(4, 3.2, 8), 6.0, 0.8)
	for x in [-4.0, 0.0, 4.0]:
		add_light("corridor", Vector3(x, 3.2, 4), 6.0, 0.9)
	for p in [Vector3(-3, 3.2, -5.5), Vector3(3, 3.2, -5.5), Vector3(-3, 3.2, -0.5), Vector3(3, 3.2, -0.5)]:
		add_light("office", p, 7.0, 1.0)
	add_light("vestibule", Vector3(0, 3.2, -10), 6.0, 0.9)
	FlickerLight.attach(add_light("stairs", Vector3(0, 3.2, -14.5), 6.0, 0.7), 0.25)

	watcher = Watcher.new()
	watcher.name = "Watcher"
	add_child(watcher)
	watcher.position = watcher_home
	watcher.holders.append(_camera_holds)
	watcher.see_through = _glass
	watcher.caught.connect(_on_caught)
	watcher.started_moving.connect(_on_watcher_moving)
	spawn = Transform3D(Basis(), Vector3(4, 0.1, 9))


func _build_booth() -> void:
	Greybox.box(geo, Vector3(-3, 0.45, 5.5), Vector3(2.0, 0.9, 0.8), Color(0.38, 0.36, 0.33), "BoothDesk")
	booth = Terminal.spawn(geo, Vector3(-3, 0.9, 5.5), 180, "SECURITY BOOTH", db, terminal_ui)
	booth.api = api
	booth.puzzles = [cameras_puzzle, pike_puzzle, har_puzzle]
	booth.boot_lines = [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  SECURITY BOOTH",
		"Session: GUEST (lockdown mode, read only)",
		"",
		"This terminal can also talk to the security server over the network.",
		"A request is a verb and an address. To see every camera, type:",
		"",
		"    [color=#ffffff]GET /cameras[/color]",
		"",
		"Type .help for commands, .hint if you're stuck.",
	]
	booth.queried.connect(_on_query)
	booth.requested.connect(_on_request)
	# Sticky note on the monitor, the sign-in sheet and a poster: found in the world first.
	Greybox.panel(geo, Vector3(-2.55, 1.35, 5.27), Vector3(0.16, 0.16, 0.01), Color(0.95, 0.9, 0.4))
	Greybox.label(geo, Vector3(-2.55, 1.35, 5.26), "cameras:\nGET /cameras", 22, Color(0.1, 0.1, 0.4), 180)
	Greybox.panel(geo, Vector3(-1.4, 1.45, 5.89), Vector3(0.6, 0.8, 0.01), Color(0.9, 0.88, 0.8))
	Greybox.label(geo, Vector3(-1.4, 1.45, 5.88),
		"NIGHT SHIFT SIGN-IN  10/15\n\nPIKE, H.     NO SHOW\nHar[coffee stain]  22:00\n\nPINs on file in the\nguards table.", 22, Color(0.1, 0.1, 0.15), 180)
	Greybox.panel(geo, Vector3(-5.0, 1.6, 5.89), Vector3(1.3, 0.9, 0.01), Color(0.2, 0.25, 0.4))
	Greybox.label(geo, Vector3(-5.0, 1.6, 5.88),
		"ROSTER TIP\nCan't read a whole name?\nname LIKE 'Ro%'\nfinds ROSS, ROURKE...\n% means any letters", 26, Color(0.95, 0.95, 0.9), 180)
	# A crate under the vent, so one person can climb up alone.
	Greybox.box(geo, Vector3(-5.4, 0.45, 4.0), Vector3(0.9, 0.9, 0.9), Color(0.45, 0.35, 0.2), "Crate")
	Greybox.label(geo, Vector3(-5.85, 2.7, 4.0), "VENT", 30, Color(0.7, 0.7, 0.7), 90)
	# Smashed window at the east end, onto the ledge.
	Greybox.label(geo, Vector3(5.85, 1.3, 4.0), "WINDOW SMASHED\nKEEP CLEAR", 26, Color(0.85, 0.2, 0.15), -90)


func _build_panel() -> void:
	# A wall terminal in the vestibule, under CAM-3: the place to check your work.
	Greybox.box(geo, Vector3(-1.4, 0.45, -11.4), Vector3(1.4, 0.9, 0.7), Color(0.38, 0.36, 0.33), "PanelDesk")
	panel = Terminal.spawn(geo, Vector3(-1.4, 0.9, -11.4), 0, "VESTIBULE PANEL", db, terminal_ui)
	panel.api = api
	panel.puzzles = [door_puzzle]
	panel.boot_lines = [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  VESTIBULE PANEL",
		"Door and camera status for this vestibule.",
		"",
		"    [color=#ffffff]GET /doors/SEC-EXIT[/color]    the stairwell door",
		"    [color=#ffffff]GET /cameras[/color]           every camera",
		"",
		"Type .help for commands, .hint if you're stuck.",
	]
	panel.queried.connect(_on_query)
	panel.requested.connect(_on_request)
	# Breaker box on the west wall, under the vent. Only one breaker runs the door.
	Greybox.panel(geo, Vector3(-2.37, 1.3, -8.95), Vector3(0.04, 0.6, 1.3), Color(0.3, 0.32, 0.3))
	Greybox.label(geo, Vector3(-2.34, 1.72, -8.95), "BREAKERS", 26, Color(0.9, 0.9, 0.8), 90)
	for i in range(1, 5):
		var z := -9.45 + (i - 1) * 0.33
		var b := Interactable.create(geo, Vector3(-2.33, 1.25, z), Vector3(0.06, 0.18, 0.12), "Reset breaker B-%d" % i, Color(0.1, 0.1, 0.1))
		b.used.connect(_on_breaker.bind(i))
		breakers[i] = b
		Greybox.label(geo, Vector3(-2.3, 1.42, z), "B-%d" % i, 20, Color(0.9, 0.9, 0.8), 90)


func _build_office() -> void:
	# Monitor wall (west) and desks.
	Greybox.box(geo, Vector3(-5.6, 0.4, -3), Vector3(0.7, 0.8, 5), Color(0.3, 0.3, 0.32), "MonitorDesk")
	for i in 5:
		var z := -5.0 + i * 1.0
		var id := "CAM-%d" % (i + 1)
		var live := id in ["CAM-2", "CAM-3", "CAM-5"]
		Greybox.panel(geo, Vector3(-5.86, 1.6, z), Vector3(0.04, 0.6, 0.8), Color(0.3, 0.45, 0.4) if live else Color(0.05, 0.05, 0.06), 1.2 if live else 0.0)
		Greybox.label(geo, Vector3(-5.82, 2.05, z), id, 26, Color(0.8, 0.8, 0.8), 90)
	Greybox.box(geo, Vector3(2.5, 0.4, -1.0), Vector3(2.4, 0.8, 1.0), Color(0.36, 0.3, 0.25), "Desk")
	Greybox.box(geo, Vector3(-2.0, 0.4, -6.0), Vector3(2.4, 0.8, 1.0), Color(0.36, 0.3, 0.25), "Desk")
	# The night desk's answering machine: one new message.
	var machine := Interactable.create(geo, Vector3(2.5, 0.85, -1.0), Vector3(0.3, 0.1, 0.25), "Play message (1 new)", Color(0.12, 0.12, 0.12))
	Greybox.panel(geo, Vector3(2.62, 0.91, -1.0), Vector3(0.03, 0.02, 0.03), Color(1, 0.2, 0.1), 4.0)
	machine.used.connect(func(_p):
		machine.enabled = false
		hud.lines(["l2_vale_1", "l2_vale_2", "l2_vale_3"]))
	# Camera housings with a red light when they're running.
	_camera_box(Vector3(5.7, 3.0, 1.7))
	_camera_box(Vector3(2.2, 3.0, -8.3))


func _build_vent() -> void:
	# Duct from the corridor's west wall, north past the office, east into the vestibule.
	# Inside it's 1 m tall: crawl height. The ceiling is thick so nobody stands up in it.
	var duct := Color(0.42, 0.44, 0.46)
	Greybox.box(geo, Vector3(-6.6, 1.95, -3.0), Vector3(1.0, 0.1, 15.1), duct, "VentFloor")
	Greybox.box(geo, Vector3(-6.6, 3.6, -3.0), Vector3(1.0, 1.2, 15.1), duct, "VentTop")
	Greybox.box(geo, Vector3(-7.15, 2.5, -3.0), Vector3(0.1, 1.2, 15.2), duct, "VentWall")
	Greybox.box(geo, Vector3(-6.05, 2.5, -8.75), Vector3(0.1, 1.2, 1.5), duct, "VentWall")
	Greybox.box(geo, Vector3(-6.6, 2.5, 4.55), Vector3(1.1, 1.2, 0.1), duct, "VentCap")
	Greybox.box(geo, Vector3(-4.8, 1.95, -10.0), Vector3(4.6, 0.1, 1.0), duct, "VentFloor")
	Greybox.box(geo, Vector3(-4.8, 3.6, -10.0), Vector3(4.6, 1.2, 1.0), duct, "VentTop")
	Greybox.box(geo, Vector3(-4.85, 2.5, -10.55), Vector3(4.7, 1.2, 0.1), duct, "VentWall")
	Greybox.box(geo, Vector3(-4.3, 2.5, -9.45), Vector3(3.6, 1.2, 0.1), duct, "VentWall")
	var l := add_light("vent", Vector3(-6.6, 2.95, -3.0), 4.0, 0.25)
	l.light_color = Color(0.6, 0.7, 0.9)


func _build_ledge() -> void:
	# Half a meter of concrete outside the east wall, and nothing below it.
	var concrete := Color(0.4, 0.4, 0.38)
	Greybox.box(geo, Vector3(6.35, -0.1, -2.0), Vector3(0.5, 0.2, 13.1), concrete, "Ledge")
	Greybox.box(geo, Vector3(4.35, -0.1, -8.325), Vector3(3.5, 0.2, 0.45), concrete, "Ledge")
	Greybox.box(geo, Vector3(3.1, -0.1, -8.85), Vector3(1.0, 0.2, 1.5), concrete, "LedgeLanding")
	Greybox.box(geo, Vector3(5, -40, -3), Vector3(30, 1, 40), Color(0.05, 0.05, 0.05), "FarBelow")
	var moon := add_light("outside", Vector3(9, 4, -2), 12.0, 0.35)
	moon.light_color = Color(0.5, 0.6, 0.9)


func _glass_pane(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Glass"
	body.position = center
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.75, 0.8, 0.18)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	mesh.material_override = m
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	geo.add_child(body)
	_glass.append(body.get_rid())


func _camera_box(pos: Vector3) -> void:
	Greybox.panel(geo, pos, Vector3(0.25, 0.18, 0.35), Color(0.2, 0.2, 0.22))
	Greybox.panel(geo, pos + Vector3(0, -0.1, 0), Vector3(0.05, 0.05, 0.05), Color(1, 0.1, 0.1), 4.0)


func start() -> void:
	if completed.get_connections().is_empty():
		completed.connect(_end_standalone)
	watcher.place(watcher_home, Vector3(-3, 0, 2))
	watcher.active = true
	hud.set_objective("Find a way out of the security wing")
	if Game.rourke_fate == "tied":
		await hud.lines(["l2_rourke_1", "l2_rourke_2", "l2_rourke_3"])
	elif Game.rourke_fate == "killed":
		await hud.line("l2_dead_escort")
	await hud.lines(["l2_arrive", "l2_cameras"])
	if not cameras_puzzle.solved:
		hud.set_objective("Use the security booth terminal")


func _process(delta: float) -> void:
	_clock += delta
	_cam_tick -= delta
	if _cam_tick <= 0.0:
		_cam_tick = 1.0
		update_cameras()
	if player and player.health > 0.0 and player.global_position.y < -6.0:
		player.take_damage(1000.0)
	if not reached_vestibule and player and _in(cam_zones["CAM-3"], player.global_position):
		reached_vestibule = true
	_motion_warnings()


## The building's clock, as the security server reports it.
func server_time() -> String:
	var s := CLOCK_START + int(_clock)
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


## Working cameras refresh their picture every second. A frozen one keeps its last frame.
func update_cameras() -> void:
	var now := server_time()
	for id in cam_zones:
		if frozen_cams.has(id):
			continue
		var sees := 1 if _in(cam_zones[id], watcher.global_position) else 0
		db.run_silent("UPDATE cameras SET last_frame = '%s', motion = %d WHERE id = '%s'" % [now, sees, id])


func _camera_holds(w: Watcher) -> bool:
	for id in cam_zones:
		if not frozen_cams.has(id) and _in(cam_zones[id], w.global_position):
			return true
	return false


func _in(boxes: Array, p: Vector3) -> bool:
	for b in boxes:
		if b.has_point(p + Vector3.UP * 0.5):
			return true
	return false


func _make_api() -> FacilityAPI:
	var a := FacilityAPI.new()
	a.route("GET", "/cameras", func(_p):
		update_cameras()
		var cams := []
		for row in db.run_silent("SELECT * FROM cameras ORDER BY id"):
			cams.append(_camera_json(row))
		return {"status": 200, "body": {"server_time": server_time(), "cameras": cams}})
	a.route("GET", "/cameras/:id", func(p):
		update_cameras()
		var rows := db.run_silent("SELECT * FROM cameras WHERE id = '%s'" % str(p[0]).to_upper().replace("'", ""))
		if rows.is_empty():
			return {"status": 404, "body": {"error": "No camera called %s. GET /cameras lists them." % p[0]}}
		var cam := _camera_json(rows[0])
		cam["server_time"] = server_time()
		return {"status": 200, "body": cam})
	a.route("GET", "/doors", func(_p):
		var list := []
		for row in db.run_silent("SELECT * FROM doors JOIN door_status ON door_status.door_id = doors.id ORDER BY id"):
			list.append(_door_json(row))
		return {"status": 200, "body": {"doors": list}})
	a.route("GET", "/doors/:id", func(p):
		var rows := db.run_silent("SELECT * FROM doors JOIN door_status ON door_status.door_id = doors.id WHERE id = '%s'" % str(p[0]).to_upper().replace("'", ""))
		if rows.is_empty():
			return {"status": 404, "body": {"error": "No door called %s. GET /doors lists them." % p[0]}}
		return {"status": 200, "body": _door_json(rows[0])})
	return a


func _door_json(row: Dictionary) -> Dictionary:
	return {
		"id": row["id"],
		"name": row["name"],
		"locked": int(row["locked"]) == 1,
		"sensor": row["sensor"],
		"actuator": row["actuator"],
		"note": row["note"],
	}


func _camera_json(row: Dictionary) -> Dictionary:
	return {
		"id": row["id"],
		"location": row["location"],
		"status": row["status"],
		"last_frame": row["last_frame"],
		"motion": int(row["motion"]) == 1,
		"note": row["note"],
	}


func _on_request(line: String, res: Dictionary, ui: TerminalUI) -> void:
	if res.status != 200:
		return
	if line.to_lower().contains("/doors"):
		_on_door_checked(ui)
		return
	if not line.to_lower().contains("/cameras"):
		return
	if not cameras_puzzle.solved:
		cameras_puzzle.solved = true
		ui.print_line("")
		ui.print_line("[color=#e0b050]WARDEN: CAM-2 reports motion in the Security Office. Look through the window.[/color]")
		ui.print_line("[color=#e0b050]It can only move while nothing is watching it: not you, not a working camera.[/color]")
		ui.print_line("")
		ui.print_line("The stairwell keypad wants a guard's PIN. PINs are in the table [b]guards[/b].")
		ui.print_line("It's a long roster. Count it, or peek at the first few rows:")
		ui.print_line("    [color=#ffffff]SELECT COUNT(*) FROM guards;[/color]     how many rows")
		ui.print_line("    [color=#ffffff]SELECT * FROM guards LIMIT 5;[/color]    only the first 5")
		ui.print_line("Officer Pike's name is clear on the sign-in sheet. Find his row with a pattern:")
		ui.print_line("    [color=#ffffff]SELECT * FROM guards WHERE name LIKE 'Pike%';[/color]")
		ui.print_line("      LIKE 'Pike%'   names that start with Pike (% = any letters after)")
		hud.set_objective("Look up Officer Pike in the guards table")
	elif loose and not _lie_explained and not _in(cam_zones["CAM-2"], watcher.global_position):
		_lie_explained = true
		ui.print_line("")
		ui.print_line("[color=#ff6655]CAM-2 says 'live' with motion in the office. It isn't in the office.[/color]")
		ui.print_line("[color=#e0b050]Compare CAM-2's last_frame with server_time: its picture stopped at %s. A hardware fault froze it." % db.run_silent("SELECT last_frame FROM cameras WHERE id = 'CAM-2'")[0]["last_frame"])
		ui.print_line("The status said 'live'. The data says otherwise. Trust the data, and check it.[/color]")


func _on_query(sql: String, result: Dictionary, ui: TerminalUI) -> void:
	if not pike_puzzle.solved and pike_puzzle.matches(db, result):
		pike_puzzle.solved = true
		ui.print_line("")
		ui.print_line("[color=#e0b050]WARDEN: Officer Pike's PIN is suspended. Nobody has seen him since Tuesday.[/color]")
		ui.print_line("The other name on the sign-in sheet is under a coffee stain. Only [b]Har[/b] is readable.")
		ui.print_line("It's the NIGHT SHIFT sheet. The guard you want starts with Har and works nights.")
		hud.set_objective("Find the PIN of the night-shift guard whose name starts with Har")
		hud.line("l2_smudged")
		_set_loose()
	if not har_puzzle.solved and har_puzzle.matches(db, result):
		har_puzzle.solved = true
		ui.print_line("")
		ui.print_line("[color=#e0b050]WARDEN: %s, night shift. Signed in 22:00. PIN on file.[/color]" % data.name)
		hud.set_objective("Enter %s's PIN at the stairwell keypad, past the Security Office" % data.name)
		hud.notice("Three ways there: through the office, the vent over the crate, or out the smashed window.", 6.0)
		_set_loose()
	if sql.to_lower().contains("door_status") and not result.rows.is_empty():
		_on_door_checked(ui)


## CAM-2 freezes on its last frame. The Watcher is free, and the camera still says "live".
func _set_loose() -> void:
	if loose:
		return
	loose = true
	frozen_cams["CAM-2"] = true
	for l in lights.get("office", []):
		FlickerLight.attach(l, 0.4)
	hud.notice("> CAM-2: LIVE. ALL CAMERAS NOMINAL.", 3.5)


func _on_watcher_moving() -> void:
	_warned.clear()


## While someone is typing, the booth's door sensor says how close it's getting.
func _motion_warnings() -> void:
	if not loose or not terminal_ui.visible or watcher.seen or not player:
		return
	var d := watcher.global_position.distance_to(player.global_position)
	for limit in [10, 6, 3]:
		if d < limit and not _warned.has(limit):
			_warned[limit] = true
			terminal_ui.print_line("[color=#ff6655]MOTION SENSOR: MOVEMENT %d m FROM YOU[/color]" % limit)


func _on_exit_keypad(p: Node) -> void:
	_seal_mode = false
	if pin_entered:
		hud.notice("KEYPAD: SEC-EXIT IS UNLOCKED." if not door_open else "SEC-EXIT is open.", 2.5)
		return
	keypad_ui.open(p, "SEC-EXIT  -  ENTER GUARD PIN", "Lockdown: only guards on tonight's night-shift sheet.")


func _on_seal_keypad(p: Node) -> void:
	if not door_open:
		hud.notice("SEC-EXIT is already shut.", 2.0)
		return
	_seal_mode = true
	keypad_ui.open(p, "LOCK SEC-EXIT BEHIND YOU", "Same PIN. Whatever is on the other side stays there.")


func _on_pin(pin: String) -> void:
	var result := check_pin(pin)
	if not result.ok:
		keypad_ui.show_status(result.message, ThemeUtil.RED)
		return
	keypad_ui.close()
	if _seal_mode:
		seal_exit()
		return
	enter_pin()


## Is this the right PIN? Wrong ones say why, in the building's own words.
func check_pin(pin: String) -> Dictionary:
	if pin.length() != 4 or not pin.is_valid_int():
		return {"ok": false, "message": "A PIN is 4 digits."}
	if pin == data.pin:
		return {"ok": true, "message": "PIN ACCEPTED: %s" % data.name}
	var rows := db.run_silent("SELECT name, shift, note FROM guards WHERE pin = '%s'" % pin)
	if rows.is_empty():
		return {"ok": false, "message": "PIN NOT RECOGNIZED."}
	var g: Dictionary = rows[0]
	return {"ok": false, "message": "REFUSED: that is %s's PIN (%s shift: %s). Lockdown accepts only guards on tonight's night-shift sign-in sheet." % [g["name"], g["shift"], g["note"]]}


## The right PIN unlocks the door in the database. If the actuator is still
## faulted, the door doesn't move, and the keypad says "opened" anyway.
func enter_pin() -> void:
	pin_entered = true
	db.run_silent("UPDATE doors SET locked = 0 WHERE id = 'SEC-EXIT'")
	db.sync_world()
	hud.notice("> PIN ACCEPTED: %s\n> DOOR SEC-EXIT: OPENED" % data.name, 4.0, ThemeUtil.GREEN)
	if _update_door():
		return
	hud.set_objective("Get through SEC-EXIT")
	await hud.line("l2_door_ok")
	await get_tree().create_timer(5.0).timeout
	if not door_open and not door_checked:
		hud.notice("It didn't open. Check the door's sensor at the vestibule panel:  GET /doors/SEC-EXIT", 7.0)
		hud.set_objective("Find out why SEC-EXIT is still shut (vestibule panel)")


func _on_door_checked(ui: TerminalUI) -> void:
	door_puzzle.solved = true
	if not pin_entered or door_checked or door_open:
		return
	door_checked = true
	ui.print_line("")
	ui.print_line("[color=#ff6655]The keypad said OPENED. locked is false, so the request went through.[/color]")
	ui.print_line("[color=#e0b050]But sensor says 'closed' and actuator says 'fault': the door never moved. Read the note.[/color]")
	ui.print_line("A request being accepted isn't the same as the thing happening. Check the sensor, not the request.")
	hud.set_objective("Reset breaker B-%d (the box under the vent), then check the door again" % data.breaker)
	hud.line("l2_door_fault")


func _on_breaker(_p: Node, i: int) -> void:
	if i == data.breaker:
		db.run_silent("UPDATE doors SET actuator_fault = 0 WHERE id = 'SEC-EXIT'")
		db.run_silent("UPDATE door_status SET actuator = 'ok', note = 'normal' WHERE door_id = 'SEC-EXIT'")
		breakers[i].enabled = false
		hud.notice("> BREAKER B-%d: RESET. Something clunks inside the door frame." % i, 3.5, ThemeUtil.GREEN)
		db.sync_world()
		_update_door()
		return
	# The wrong breaker cuts this room's lights and its camera for a few seconds.
	hud.notice("B-%d runs the vestibule lights and CAM-3. Everything goes dark." % i, 4.0, ThemeUtil.RED)
	frozen_cams["CAM-3"] = true
	for l in lights.get("vestibule", []):
		l.visible = false
	await get_tree().create_timer(6.0).timeout
	frozen_cams.erase("CAM-3")
	for l in lights.get("vestibule", []):
		l.visible = true


## Is the door physically open now? Keeps door_status in step with the world.
func _update_door() -> bool:
	var row: Dictionary = db.run_silent("SELECT locked, actuator_fault FROM doors WHERE id = 'SEC-EXIT'")[0]
	var open := int(row["locked"]) == 0 and int(row["actuator_fault"]) == 0
	db.run_silent("UPDATE door_status SET sensor = '%s' WHERE door_id = 'SEC-EXIT'" % ("open" if open else "closed"))
	if open and not door_open:
		door_open = true
		hud.set_objective("Take the stairs down. (Lock the door behind you, if you can)")
		if _exit_trigger == null:
			_exit_trigger = Trigger.create(self, Vector3(0, 1, -16), Vector3(3.6, 2, 1.5))
			_exit_trigger.entered.connect(_on_exit)
	return open


func seal_exit() -> void:
	db.run_silent("UPDATE doors SET locked = 1 WHERE id = 'SEC-EXIT'")
	db.sync_world()
	door_open = false
	_update_door()
	Game.watcher_sealed = true
	hud.notice("> DOOR SEC-EXIT: LOCKED\nIt held. Whatever follows you stays in the security wing.", 4.0, ThemeUtil.GREEN)


func _on_exit(_b: Node) -> void:
	player.input_locked = true
	if Game.watcher_sealed:
		await hud.say("", "Behind the locked door, something taps on the metal. Once.", 4.0)
	else:
		await hud.say("", "The door behind you is still open. You don't look back. You know better.", 4.5)
	Game.completed_level = "level_2"
	Game.next_level = ""
	completed.emit()


## Played as its own scene (until wings stream into one world), the level ends on Field Notes.
func _end_standalone() -> void:
	await hud.fade(true, 1.2)
	Game.goto("field_notes")


func _on_caught(p: Node) -> void:
	if p.has_method("take_damage") and p.health > 0.0:
		p.take_damage(1000.0)


func on_player_died() -> void:
	keypad_ui.close()
	if reached_vestibule:
		player.respawn(Transform3D(Basis(), Vector3(0, 0.1, -10.8)))
		watcher.place(Vector3(-4.5, 0, 4.5), Vector3(0, 0, -10))
	else:
		player.respawn(spawn)
		watcher.place(watcher_home, Vector3(-3, 0, 2))
