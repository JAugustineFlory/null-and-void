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
## Security Office (the Watcher, behind a locked door) > exit vestibule > stairwell.
##
## The main path: find the PIN, open the office door with it, get past the Watcher,
## enter the PIN at the stairwell, then (optionally) lock it in behind you. The Watcher
## starts out of sight, creeps closer once players find Pike, and from then on hunts
## them, held back only by the locked office door and its glass until the PIN opens it.
## Two side routes have to be discovered: the vent over the crate (its grate needs
## the screwdriver from the break-glass box on the landing) and the corridor's outside
## window (break the glass, then the ledge). Players arrive by elevator and leave by
## the emergency stairs past SEC-EXIT (the lifts are dead), which they can lock behind them. The stairwell PIN is needed on every route.

## Fired once the crew is on the stairs down: the wing is done. In the World that's the
## end of the route (Field Notes); on its own, the level goes to Field Notes too.
signal completed

const CLOCK_START := 41 * 60  # 00:41:00
## Where the SEC-EXIT door's bolt and motor are: its sounds come from here.
const SEC_EXIT_FRAME := Vector3(0, 1.2, -12)
## Where each camera can see, as boxes in the level's own space (see _in()).
## Only working cameras hold the Watcher.
## CAM-3 only watches the vestibule's panel corner, so the Watcher can still come
## through the vestibule after players on the main route.
var cam_zones := {
	"CAM-2": [AABB(Vector3(-6, -1, -8), Vector3(12, 6, 10))],
	"CAM-3": [AABB(Vector3(-2.5, -1, -12), Vector3(2.2, 6, 1.7))],
	"CAM-5": [AABB(Vector3(6.1, -3, -8.6), Vector3(0.6, 8, 13.2)), AABB(Vector3(2.6, -3, -9.6), Vector3(3.6, 8, 1.6))],
}
var frozen_cams := {}
## The whole exit vestibule (level space): reaching it is a checkpoint.
var _vestibule_box := AABB(Vector3(-2.5, -1, -12), Vector3(5, 6, 4))

var data: Dictionary
var watcher: Watcher
var booth: Terminal
var panel: Terminal
var api: FacilityAPI
var breakers := {}
## The breaker box's own status readout: says what a wrong breaker just cut.
var breaker_status: Label3D
## The guard-PIN keypads on the walls: the office door's, and SEC-EXIT's.
var office_pad: Level2Keypad
var exit_pad: Level2Keypad
## On the far side of SEC-EXIT: shuts and locks it behind you. No PIN needed.
var seal_button: Interactable
## Where the Watcher stands as players get closer to the PIN (level space): out of
## sight behind the gear lockers, then mid-office, then at the window staring out.
const STAGES := {
	"hidden": [Vector3(4.3, 0, -7.2), Vector3(4.3, 0, -3)],
	"near": [Vector3(-1.5, 0, -3.5), Vector3(-3, 0, 4)],
	"window": [Vector3(-3, 0, 1.2), Vector3(-3, 0, 5)],
}
var watcher_home: Vector3 = STAGES.hidden[0]
var stage := "hidden"
var _stage_pending := ""
var loose := false  # CAM-2 has frozen: no camera holds the office any more
var office_open := false
var has_screwdriver := false  # anyone has taken one
var screwdrivers: ItemDock
var spare_walkies: ItemDock
var vent_grate: Interactable  # screwed shut, corridor end
var vent_hatch: Interactable  # hinged, vestibule end
var hatch_open := false
var ledge_glass: Level2Glass
var vestibule_glass: Level2Glass
var office_glass: Level2Glass
var reached_vestibule := false
var pin_entered := false
var door_open := false  # physically open
var door_checked := false
var door_asked := false  # the crew has been told SEC-EXIT is still shut
## Host: Easy SQL chapters whose paper or terminal has been found: "found" waits for
## its puzzle to open, "played" has been held.
var _books := {}
var _clock := 0.0
var _cam_tick := 0.0
var _lie_explained := false
var _lie_notice := ""
var _lie_fresh := false  # just explained: someone who died to it hears why
var _warned := {}
var _glass: Array[RID] = []
## Corridor and landing: leaving it another way also wakes the Watcher (level space).
var _corridor_box := AABB(Vector3(-6, -1, 2), Vector3(12, 3, 8.5))
## Just the booth's corridor, not the landing or the night desk.
var _booth_corridor := AABB(Vector3(-6, -1, 2), Vector3(12, 4, 4))
var arrival_lift: Elevator
## Secure Lab B, where Rourke turns (see Level2Lab), and the rooms round it (Level2Floor).
var lab: Level2Lab
var exit_lift: Elevator
var stair_door: Door
## The stair door, in the lift lobby's east wall.
const STAIR_DOOR_AT := Vector3(2, 0, -14.5)
var key_glass: Level2Glass
## The floor's case pages in the notebook (Cases tab), by id.
const CASES := {
	"cameras": "What's moving on the security floor?",
	"pin": "Whose PIN still works tonight?",
	"door": "Why won't SEC-EXIT open?",
}

var cameras_puzzle := Puzzle.new("cameras", "", [], false, [
	"type this, then Enter:\n" +
	"    [color=#ffffff]GET /cameras[/color]\n" +
	"  GET       ask the security server for something. it only reads, it changes nothing\n" +
	"  /cameras  the address of the camera list\n" +
	"the answer is JSON. { } is one camera's fields, [ ] is a list of them.",
	"look down the list for \"motion\": true. its location is the room where something's moving.",
])
## Hints climb from the query's shape, with the value to find left as a named blank, to how
## to find that value, to the exact query.
var pike_puzzle := Puzzle.new("pike", "SELECT name FROM guards WHERE name LIKE 'Pike%'", ["name"], false, [
	"the shape, with the name left blank:\n" +
	"    [color=#ffffff]SELECT * FROM guards WHERE name LIKE 'enter_surname%';[/color]\n" +
	"  SELECT *            every column\n" +
	"  FROM guards         from the guard roster\n" +
	"  WHERE name LIKE     keep rows whose name matches a pattern\n" +
	"  'enter_surname%'    starts with the surname. % = any letters after it, or none\n" +
	"replace enter_surname with the one name you can read clearly on the sign-in sheet.",
	"the sign-in sheet is on the booth wall. the first name on it is marked NO SHOW. " +
	"put that surname in place of enter_surname, with the % straight after it.",
	"type this, then Enter:\n" +
	"    [color=#ffffff]SELECT * FROM guards WHERE name LIKE 'Pike%';[/color]\n" +
	"keep the 'single quotes' round Pike%.",
])
var door_puzzle := Puzzle.new("door", "", [], false, [
	"the shape, with the door left blank:\n" +
	"    [color=#ffffff]GET /doors/enter_door_id[/color]\n" +
	"  GET                     ask the security server for data\n" +
	"  /doors/enter_door_id    one door's record: what was asked of it, and what its sensor says\n" +
	"replace enter_door_id with the id of the door that won't open. if it won't move, the note in the answer says why. which breaker tripped, say.",
	"the stairwell door's id is in red letters over it. GET that, then read the \"note\" line: it names a breaker, like B-2.",
	"type this, then Enter:\n" +
	"    [color=#ffffff]GET /doors/SEC-EXIT[/color]\n" +
	"the note names a breaker. the breaker box is on the wall under the vent. press E on that one.",
])
## Finding the PIN: the main route runs through the badge readers' log. The coffee-
## stained "Har" on the sign-in sheet (LIKE + AND) and the briefing room's roster
## board get there too: any query that comes back with just the night lead's PIN works.
var har_puzzle := Puzzle.new("har", "SELECT pin FROM guards WHERE name LIKE 'Har%' AND shift = 'night'", ["pin"], false, pin_hints("G-1??"))


static func pin_hints(badge: String) -> Array:
	return [
		"the shape, with the badge left blank:\n" +
		"    [color=#ffffff]SELECT * FROM guards WHERE badge_id = 'enter_badge_id';[/color]\n" +
		"  SELECT * FROM guards                every column of the guard roster, pin too\n" +
		"  WHERE badge_id = 'enter_badge_id'   only the guard with that badge\n" +
		"replace enter_badge_id with the last guard badge (G-) through SEC-EXIT tonight. the readers keep every swipe in [b]badge_log[/b].",
		"sort the swipes by time:\n" +
		"    [color=#ffffff]SELECT * FROM badge_log ORDER BY time;[/color]\n" +
		"read down the door column for SEC-EXIT. the last G- badge there is your guard. put it in place of enter_badge_id.",
		"type this, then Enter:\n" +
		"    [color=#ffffff]SELECT * FROM guards WHERE badge_id = '%s';[/color]\n" % badge +
		"the pin column is the code. office door first, then the SEC-EXIT keypad past it.",
	]

func build() -> void:
	data = Level2Data.build(Game.run_seed)
	load_level_seed(data.sql)
	har_puzzle.hints = pin_hints(data.badge)

	var floor_c := Color(0.27, 0.27, 0.3)
	var wall_c := Color(0.52, 0.53, 0.5)
	var office_wall := Color(0.46, 0.48, 0.5)
	# Elevator landing (spawn): x 2.5..5.5, z 6..10. Server Room A's elevator rides here.
	Greybox.room(geo, Vector3(4, 0, 8), Vector3(3, 3.2, 4), {"floor": floor_c, "wall": wall_c}, [
		{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "w", "at": 0.0, "width": 1.8, "height": 2.4},  # to the night desk
		{"wall": "e", "at": 0.0, "width": Elevator.DOORWAY, "height": Elevator.DOOR_H},  # the arrival elevator
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
	Greybox.label(geo, Vector3(0, 2.75, 2.12), "SECURITY OFFICE", 64, Color(0.75, 0.75, 0.7))
	office_glass = _glass_pane(Vector3(-3, 2.1, 2), Vector3(2.4, 2.2, 0.05), false, "OfficeGlass")
	add_door("SEC-OFFICE", Vector3(0, 1.2, 2), Vector3(1.8, 2.4, 0.15))
	office_pad = Level2Keypad.mount(geo, Vector3(1.3, 1.3, 2.13), 0, "office", "SEC-OFFICE\nENTER GUARD PIN")
	office_pad.key_pressed.connect(_on_pad_key.bind("office"))
	Document.place(geo, Vector3(2.15, 1.35, 2.11), 180, "Lockdown PIN policy", [
		"LOCKDOWN PIN POLICY",
		"In lockdown, doors take only the PINs of NIGHT SHIFT guards who badged in tonight.",
		"Suspended or retired PINs: refused.",
	], false, "laminated", Vector2(0.5, 0.36)).clues = [
		{"case": "pin", "text": "In lockdown, only night-shift guards who badged in tonight have working PINs."},
	]
	# Exit vestibule: x -2.5..2.5, z -12..-8
	Greybox.room(geo, Vector3(0, 0, -10), Vector3(5, 3.2, 4), {"floor": floor_c, "wall": wall_c}, [
		{"wall": "s", "at": 0.0, "width": 1.6, "height": 2.4},
		{"wall": "n", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "w", "at": 0.0, "width": 1.0, "height": 3.0, "bottom": 2.0},
		{"wall": "e", "at": 1.25, "width": 1.2, "height": 1.0},
	])
	# Elevator lobby past SEC-EXIT: x -2..2, z -17..-12
	Greybox.room(geo, Vector3(0, 0, -14.5), Vector3(4, 3.2, 5), {"floor": floor_c, "wall": wall_c}, [
		{"wall": "s", "at": 0.0, "width": 1.8, "height": 2.4},
		{"wall": "n", "at": 0.0, "width": Elevator.DOORWAY, "height": Elevator.DOOR_H},
		{"wall": "e", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},  # the stairs
	])
	# After the frame the lifts are dead (Act 2): the way out is the emergency stairs,
	# down toward the Records Archive on 18. The stairwell PIN unlocks their door too.
	exit_lift = Elevator.create(self, geo, Vector3(0, 0, -17), 180, "22", ["22", "18"], "18")
	exit_lift.name = "ExitElevator"
	exit_lift.hud = hud
	exit_lift.button.enabled = false
	stair_door = Stairwell.build(self, geo, STAIR_DOOR_AT, -90.0, "22")
	# Everyone on the stairs, and the wing is done.
	var down := Trigger.create(self, STAIR_DOOR_AT + Vector3(2.5, 1, 0), Vector3(2.8, 2, 3.2))
	down.name = "StairsDown"
	down.require_all = true
	down.waiting.connect(func(n, total): sync.team_notice("Waiting for everyone on the stairs (%d/%d)" % [n, total]))
	down.entered.connect(func(_b): sync.event("_on_exit", [null]), CONNECT_ONE_SHOT)
	# Server Room A's elevator links to this car and opens it at the end of the ride.
	arrival_lift = Elevator.create(self, geo, Vector3(5.5, 0, 8), 90, "22", ["22", "14", "G", "B1"], "22")
	arrival_lift.name = "ArrivalElevator"
	arrival_lift.button.enabled = false
	add_door("SEC-EXIT", Vector3(0, 1.2, -12), Vector3(1.8, 2.4, 0.15))
	Greybox.label(geo, Vector3(0, 2.75, -11.88), "SEC-EXIT", 56, Color(0.85, 0.2, 0.15))

	api = _make_api()
	_build_booth()
	_build_office()
	_build_vent()
	_build_ledge()
	Level2Floor.build(self)
	lab = Level2Lab.create(self, data)

	exit_pad = Level2Keypad.mount(geo, Vector3(1.3, 1.3, -11.85), 0, "exit", "SEC-EXIT\nENTER GUARD PIN")
	exit_pad.key_pressed.connect(_on_pad_key.bind("exit"))
	_build_panel()
	# Closing a door needs no PIN: a big button on the far side shuts and locks it.
	Greybox.panel(geo, Vector3(1.3, 1.3, -12.13), Vector3(0.16, 0.2, 0.02), Color(0.13, 0.13, 0.12))
	seal_button = Interactable.create(geo, Vector3(1.3, 1.3, -12.16), Vector3(0.09, 0.09, 0.03), "Close and lock SEC-EXIT", Color(0.7, 0.12, 0.1))
	seal_button.name = "SealButton"
	seal_button.used.connect(func(_p): sync.event("_seal_pressed"))

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
	spawn = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(6.7, 0.1, 8))  # in the arrival car, facing out
	DressLevel2.apply(self)  # furniture and materials (Graphics thread)


func _build_booth() -> void:
	Greybox.box(geo, Vector3(-3, 0.45, 5.5), Vector3(2.0, 0.9, 0.8), Color(0.38, 0.36, 0.33), "BoothDesk")
	booth = Terminal.spawn(geo, Vector3(-3, 0.9, 5.5), 180, "SECURITY BOOTH", db, terminal_ui)
	booth.api = api
	booth.puzzles = [cameras_puzzle, pike_puzzle, har_puzzle]
	pike_puzzle.case_id = "pin"  # both searches are after a working PIN
	har_puzzle.case_id = "pin"
	pike_puzzle.givens = ["PIKE, H."]  # the sign-in sheet names him before the search
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
	booth.queried.connect(_on_query.bind("booth"))
	booth.requested.connect(_on_request.bind("booth"))
	booth.opened.connect(func(_p): _book_found("easy_sql_10"))
	# The clues are on the booth's own paperwork: found in the world first.
	StickyNote.on_monitor(booth, "like")
	# Guards badge in at the reader by the booth; it logs them in the guards table.
	# The night lead also keeps a paper sheet, in case the reader goes down.
	# Laid out along the wall so nothing overlaps (the poster at x -1 is Graphics'):
	# manual x -5.3, camera card -4.3, monitor -3, sign-in sheet -2.3, reader and its card -1.6.
	Greybox.panel(geo, Vector3(-1.6, 1.3, 5.9), Vector3(0.1, 0.15, 0.04), Color(0.12, 0.12, 0.13))
	Greybox.panel(geo, Vector3(-1.6, 1.34, 5.875), Vector3(0.02, 0.02, 0.01), Color(0.1, 1.0, 0.2), 3.0)
	Document.place(geo, Vector3(-1.6, 1.0, 5.86), 0, "Badge reader card", [
		"BADGE IN AT THE START OF EVERY SHIFT",
		"The reader logs every swipe in badge_log: the time, your badge, the door.",
		"Reader down? Sign the paper sheet. The night lead keeps it as the backup copy.",
	], false, "laminated", Vector2(0.42, 0.3)).clues = [
		{"case": "pin", "text": "Every badge swipe is kept in badge_log: the time, the badge, the door."},
	]
	# The backup sheet: the names are handwritten, and coffee took most of the second one.
	var sheet := Document.place(geo, Vector3(-2.3, 1.45, 5.86), 0, "NIGHT SHIFT SIGN-IN      DATE: 10/15", [
		"(backup copy)",
		{"columns": ["NAME", "BADGE #", "IN", "OUT", "INIT."], "widths": [3.4, 1.8, 1.3, 1.3, 1.2], "text": "NAME  BADGE #  IN  OUT  INIT."},
		{"row": ["PIKE, H.", "", "", "", ""], "over": "NO SHOW", "text": "PIKE, H.  no show", "hand": true},
		{"row": ["Har", "", "22:00", "", ""], "stain": "coffee", "stain_at": 0, "text": "Har... (coffee stain)   22:00", "hand": true},
		{"row": ["", "", "", "", ""]},
		{"row": ["", "", "", "", ""]},
		"",
		"Guard PINs are kept on file in the table:",
		{"text": "guards", "hand": true},
	], false, "paper", Vector2(0.6, 0.8))
	sheet.read_by.connect(func(_p): _book_found("easy_sql_11"))
	sheet.clues = [
		{"case": "pin", "text": "PIKE, H. is marked NO SHOW. The next name starts \"Har\", under the coffee. Badged in 22:00."},
		{"case": "pin", "text": "Guard PINs are on file in the table guards."},
	]
	var cam_card := Document.place(geo, Vector3(-4.3, 1.5, 5.86), 0, "Camera system card", [
		"OVERWATCH CCTV  -  REMOTE STATUS",
		"From any security terminal:",
		"GET /cameras          every camera",
		"GET /cameras/CAM-2    one camera",
		"motion: true          movement seen",
		"last_frame            time of the last picture",
	], false, "laminated", Vector2(0.62, 0.5))
	cam_card.read_by.connect(func(_p): _book_found("easy_sql_10"))
	cam_card.clues = [
		{"case": "cameras", "text": "GET /cameras lists every camera. \"motion\": true means it sees movement."},
	]
	# A page torn from the WARDEN manual, with the old security chief's pencil in the margin.
	var manual := Document.place(geo, Vector3(-5.3, 1.6, 5.86), 0, "WARDEN manual, p.12", [
		"WARDEN v3.1  -  p.12",
		"GUARD ROSTER: QUICK SEARCH",
		"Only know part of a name? Search a pattern:",
		"WHERE name LIKE 'Ro%'",
		"finds ROSS, ROURKE, ROWE...",
		{"text": "% = any letters, or none.  - H.M.", "hand": true},
	], false, "paper", Vector2(0.8, 0.9))
	manual.read_by.connect(func(_p): _book_found("easy_sql_11"))
	manual.clues = [
		{"case": "pin", "text": "Only know part of a name? WHERE name LIKE 'Ro%' finds every name starting Ro."},
	]
	# A crate under the vent, so one person can climb up alone.
	Greybox.box(geo, Vector3(-5.4, 0.45, 4.0), Vector3(0.9, 0.9, 0.9), Color(0.45, 0.35, 0.2), "Crate")
	# On the landing, safe from anything: a break-glass box with a screwdriver inside.
	# Players learn here that glass breaks with a strike, and pick up the tool the vent needs.
	# On the landing's west wall, beside the doorway to the night desk (not in it).
	Greybox.box(geo, Vector3(2.66, 1.4, 9.4), Vector3(0.12, 0.55, 0.45), Color(0.7, 0.12, 0.1), "KeyBox")
	# One each, hanging in a row: optional, and whoever takes one can open the vent.
	screwdrivers = ItemDock.make(geo, Vector3(2.75, 1.4, 9.4), Vector3(0.38, 0.3, 0.04), "Take a screwdriver", "screwdriver")
	screwdrivers.name = "Screwdriver"
	screwdrivers.rotation_degrees.y = 90.0
	screwdrivers.add_boxes(6, 0.06, Vector3(0.03, 0.24, 0.03), Color(0.95, 0.75, 0.1), -0.12)
	screwdrivers.already = "You already have a screwdriver."
	screwdrivers.taken.connect(_on_screwdriver_taken)
	key_glass = _glass_pane(Vector3(2.79, 1.4, 9.4), Vector3(0.02, 0.45, 0.38), true, "KeyBoxGlass")
	Greybox.label(geo, Vector3(2.62, 1.82, 9.4), "MAINTENANCE\nBREAK GLASS", 26, Color(0.95, 0.95, 0.9), 90)
	# Low outside window at the east end, onto the ledge. Plain glass: it breaks.
	ledge_glass = _glass_pane(Vector3(6.0, 0.5, 4.0), Vector3(0.05, 1.0, 1.1), true, "LedgeGlass")


func _build_panel() -> void:
	# A wall terminal in the vestibule, under CAM-3: the place to check your work.
	Greybox.box(geo, Vector3(-1.4, 0.45, -11.4), Vector3(1.4, 0.9, 0.7), Color(0.38, 0.36, 0.33), "PanelDesk")
	panel = Terminal.spawn(geo, Vector3(-1.4, 0.9, -11.4), 0, "VESTIBULE PANEL", db, terminal_ui)
	panel.api = api
	panel.puzzles = [door_puzzle]
	var door_card := Document.place(geo, Vector3(-2.05, 1.7, -11.86), 180, "Door controller card", [
		"DOOR CONTROLLER  -  QUICK REF",
		"GET /doors/SEC-EXIT    one door's record",
		"sensor      what the door is actually doing",
		"actuator    the motor. fault = it can't move",
		"note        why",
	], false, "laminated", Vector2(0.62, 0.46))
	door_card.read_by.connect(func(_p): _book_found("easy_sql_13"))
	door_card.clues = [
		{"case": "door", "text": "GET /doors/SEC-EXIT shows the door's record. sensor is what it's really doing, and note says why."},
	]
	panel.boot_lines = [
		"HALCYON DATA SYSTEMS  -  WARDEN v3.1  -  VESTIBULE PANEL",
		"Door and camera status for this vestibule.",
		"",
		"    [color=#ffffff]GET /doors/SEC-EXIT[/color]    the stairwell door",
		"    [color=#ffffff]GET /cameras[/color]           every camera",
		"",
		"Type .help for commands, .hint if you're stuck.",
	]
	panel.queried.connect(_on_query.bind("panel"))
	panel.requested.connect(_on_request.bind("panel"))
	panel.opened.connect(func(_p): _book_found("easy_sql_13"))
	# Breaker box on the west wall, under the vent. Only one breaker runs the door.
	# The ledge's way back in: a low window onto the vestibule.
	vestibule_glass = _glass_pane(Vector3(2.5, 0.5, -8.75), Vector3(0.05, 1.0, 1.2), true, "VestibuleGlass")
	Greybox.panel(geo, Vector3(-2.37, 1.3, -8.95), Vector3(0.04, 0.6, 1.3), Color(0.3, 0.32, 0.3))
	Greybox.label(geo, Vector3(-2.34, 1.72, -8.95), "BREAKERS", 26, Color(0.9, 0.9, 0.8), 90)
	breaker_status = Greybox.label(geo, Vector3(-2.34, 1.86, -8.95), "", 22, Color(1.0, 0.4, 0.33), 90)
	breaker_status.name = "BreakerStatus"
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
	# Spare walkies on the night desk for anyone who left theirs downstairs.
	spare_walkies = ItemDock.walkies(geo, Vector3(3.2, 0.9, -1.25))
	spare_walkies.prompt = "Take a spare walkie-talkie"
	Greybox.box(geo, Vector3(-2.0, 0.4, -6.0), Vector3(2.4, 0.8, 1.0), Color(0.36, 0.3, 0.25), "Desk")
	# Gear lockers across the back corner: the window can't see behind them.
	Greybox.box(geo, Vector3(4.2, 1.3, -6.2), Vector3(3.2, 2.6, 0.5), Color(0.3, 0.34, 0.3), "Lockers")
	Greybox.label(geo, Vector3(4.2, 2.3, -5.94), "GEAR", 40, Color(0.85, 0.85, 0.8))
	# The night desk's answering machine: one new message.
	var machine := Interactable.create(geo, Vector3(2.5, 0.85, -1.0), Vector3(0.3, 0.1, 0.25), "Play message (1 new)", Color(0.12, 0.12, 0.12))
	Greybox.panel(geo, Vector3(2.62, 0.91, -1.0), Vector3(0.03, 0.02, 0.03), Color(1, 0.2, 0.1), 4.0)
	machine.name = "AnsweringMachine"
	machine.used.connect(func(_p): sync.event("_play_message"))
	# Camera housings with a red light when they're running.
	_camera_box(Vector3(5.7, 3.0, 1.7))
	_camera_box(Vector3(2.2, 3.0, -8.3))


func _build_vent() -> void:
	# Duct from the corridor's west wall, north past the office, east into the vestibule.
	# Inside it's 1.5 m tall: too low to stand, high enough to climb in from the crate.
	var duct := Color(0.42, 0.44, 0.46)
	Greybox.box(geo, Vector3(-6.6, 1.95, -3.0), Vector3(1.0, 0.1, 15.1), duct, "VentFloor")
	Greybox.box(geo, Vector3(-6.6, 3.55, -3.0), Vector3(1.0, 0.1, 15.1), duct, "VentTop")
	Greybox.box(geo, Vector3(-7.15, 2.75, -3.0), Vector3(0.1, 1.6, 15.2), duct, "VentWall")
	Greybox.box(geo, Vector3(-6.05, 2.75, -8.75), Vector3(0.1, 1.6, 1.5), duct, "VentWall")
	Greybox.box(geo, Vector3(-6.6, 2.75, 4.55), Vector3(1.1, 1.6, 0.1), duct, "VentCap")
	Greybox.box(geo, Vector3(-4.8, 1.95, -10.0), Vector3(4.6, 0.1, 1.0), duct, "VentFloor")
	Greybox.box(geo, Vector3(-4.8, 3.55, -10.0), Vector3(4.6, 0.1, 1.0), duct, "VentTop")
	Greybox.box(geo, Vector3(-4.85, 2.75, -10.55), Vector3(4.7, 1.6, 0.1), duct, "VentWall")
	Greybox.box(geo, Vector3(-4.3, 2.75, -9.45), Vector3(3.6, 1.6, 0.1), duct, "VentWall")
	# Corridor end: a grate screwed shut. Vestibule end: a hinged hatch, opened from inside.
	vent_grate = Interactable.create(geo, Vector3(-5.95, 2.5, 4.0), Vector3(0.06, 1.0, 1.0), "Vent grate (screwed shut: needs a screwdriver)", Color(0.16, 0.17, 0.18))
	_slats(vent_grate)
	vent_grate.used.connect(_on_vent_grate)
	vent_hatch = Interactable.create(geo, Vector3(-2.45, 2.5, -10.0), Vector3(0.06, 1.0, 1.0), "Push the vent hatch open", Color(0.16, 0.17, 0.18))
	_slats(vent_hatch)
	vent_hatch.used.connect(func(_p): sync.event("set_hatch", [not hatch_open]))
	MovementVolume.create(geo, Vector3(-6.6, 2.75, -3.0), Vector3(1.0, 1.5, 15.1), MovementVolume.Kind.VENT)
	MovementVolume.create(geo, Vector3(-4.3, 2.75, -10.0), Vector3(3.6, 1.5, 1.0), MovementVolume.Kind.VENT)
	var l := add_light("vent", Vector3(-6.6, 2.95, -3.0), 4.0, 0.25)
	l.light_color = Color(0.6, 0.7, 0.9)


func _build_ledge() -> void:
	# Half a meter of concrete outside the east wall, and nothing below it.
	# Along the east wall, then west along the office's north wall to a landing by the vestibule window.
	Traversal.ledge(geo, Vector3(6.1, 0, 4.55), Vector3(6.1, 0, -8.55), Vector3(1, 0, 0))
	Traversal.ledge(geo, Vector3(6.55, 0, -8.1), Vector3(3.6, 0, -8.1), Vector3(0, 0, -1))
	Greybox.box(geo, Vector3(3.1, -0.1, -8.85), Vector3(1.0, 0.2, 1.5), Traversal.CONCRETE, "LedgeLanding")
	var moon := add_light("outside", Vector3(9, 4, -2), 12.0, 0.35)
	moon.light_color = Color(0.5, 0.6, 0.9)
	# Twenty-two floors up, the wind never stops. Each machine hears it for its own player.
	wind = AudioStreamPlayer.new()
	wind.name = "LedgeWind"
	wind.stream = Level2FX.wind()
	wind.volume_db = WIND_SILENT
	add_child(wind)


## The ledge is 80 m up: wind that's loud out there and a faint draught by the broken
## window, and a slow sway while you're on it.
const WIND_SILENT := -60.0
const WIND_ON_LEDGE := -6.0
const WIND_BY_WINDOW := -20.0
const SWAY_ROLL := 0.02  # radians at the strongest gust
var wind: AudioStreamPlayer
## What a player sees after falling from the ledge, instead of the usual death notice
## (Augustine's wording, 2026-10-20).
const FALL_NOTICE := "Wind, then nothing. You wake back where you started, shaking."
var _fell := false
var _sway_t := 0.0


func _update_ledge(delta: float) -> void:
	if not player or not wind:
		return
	var at := to_local(player.global_position)
	# Outside the east wall (the arrival car is further south) or the office's north wall.
	var outside := (at.x > 6.05 and at.z < 4.6) or (at.z < -8.5 and at.x > 2.5)
	var on_ledge: bool = player.state == Player.Move.LEDGE or outside
	var target := WIND_SILENT
	if on_ledge:
		target = WIND_ON_LEDGE
	elif not is_instance_valid(ledge_glass) and at.distance_to(Vector3(6.0, 0.5, 4.0)) < 4.0:
		target = WIND_BY_WINDOW
	wind.volume_db = move_toward(wind.volume_db, target, delta * 30.0)
	if wind.volume_db > WIND_SILENT and not wind.playing:
		wind.play()
	elif wind.volume_db <= WIND_SILENT and wind.playing:
		wind.stop()
	_sway_t += delta
	var roll := 0.0
	if player.state == Player.Move.LEDGE:
		roll = SWAY_ROLL * (0.6 * sin(_sway_t * 0.9) + 0.4 * sin(_sway_t * 2.3 + 1.0))
	player.head.rotation.z = lerpf(player.head.rotation.z, roll, clampf(delta * 3.0, 0.0, 1.0))


func _glass_pane(center: Vector3, size: Vector3, can_break: bool, node_name: String) -> Level2Glass:
	var g := Level2Glass.create(geo, center, size, can_break, node_name)
	g.hud = hud
	g.struck.connect(func(_by): sync.event("_glass_broken", [g.name]))
	_glass.append(g.get_rid())
	return g


## Everyone's copy of a pane breaks at once.
func _glass_broken(pane: String) -> void:
	var g := geo.get_node_or_null(pane) as Level2Glass
	if g:
		g.shatter()


## Every machine: someone took their screwdriver (the dock gives it to the taker).
func _on_screwdriver_taken(id: int) -> void:
	has_screwdriver = true
	if id != players.id_of(player):
		return
	if is_instance_valid(vent_grate):
		vent_grate.prompt = "Unscrew the vent grate"
	hud.notice("Picked up a screwdriver.", 3.0)


func _play_message() -> void:
	var machine := geo.get_node_or_null("AnsweringMachine") as Interactable
	if machine:
		machine.enabled = false
	# Left before her last badge swipe: it must not hint that she's alive.
	hud.notice("MESSAGE 1 OF 1 · SUN 10/12 · 1:52 AM", 5.0)
	hud.lines(["l2_vale_1", "l2_vale_2", "l2_vale_3"])


## Louvers across a vent cover, so it reads as a grate. They go with it when it comes off.
func _slats(cover: Node3D) -> void:
	for i in 6:
		Greybox.panel(cover, Vector3(0.04, -0.4 + i * 0.16, 0), Vector3(0.03, 0.06, 0.92), Color(0.62, 0.64, 0.66))
	for z in [-0.42, 0.42]:
		Greybox.panel(cover, Vector3(0.05, 0.42, z), Vector3(0.02, 0.03, 0.03), Color(0.85, 0.82, 0.7))  # screw heads
		Greybox.panel(cover, Vector3(0.05, -0.42, z), Vector3(0.02, 0.03, 0.03), Color(0.85, 0.82, 0.7))


## Host: someone tried the grate.
func _on_vent_grate(p: Node) -> void:
	if not screwdrivers.has_taken(players.id_of(p)):
		return  # its prompt says it needs a screwdriver
	sync.event("open_vent_grate")


func open_vent_grate() -> void:
	if not is_instance_valid(vent_grate) or not vent_grate.enabled:
		return
	# Four screws out and it drops, clattering onto the floor by the crate.
	vent_grate.enabled = false
	vent_grate.prompt = ""
	for c in vent_grate.get_children():
		if c is CollisionShape3D:
			c.disabled = true
	Level2FX.drop(vent_grate, Vector3(-4.75, 0.03, 4.0), Vector3(0, 0, PI / 2))
	Level2FX.sound(geo, Vector3(-5.5, 1.0, 4.0), "clatter")


## The hinged hatch at the vestibule end swings up out of the way, or back down.
func set_hatch(open: bool) -> void:
	hatch_open = open
	vent_hatch.prompt = "Close the vent hatch" if open else "Push the vent hatch open"
	vent_hatch.position = Vector3(-1.95, 2.97, -10.0) if open else Vector3(-2.45, 2.5, -10.0)
	vent_hatch.rotation.z = PI / 2 if open else 0.0


func _camera_box(pos: Vector3) -> void:
	Greybox.panel(geo, pos, Vector3(0.25, 0.18, 0.35), Color(0.2, 0.2, 0.22))
	Greybox.panel(geo, pos + Vector3(0, -0.1, 0), Vector3(0.05, 0.05, 0.05), Color(1, 0.1, 0.1), 4.0)


func net_setup() -> void:
	sync.replicate(watcher, watcher.sync_properties())
	lab.net_setup()


func start() -> void:
	if completed.get_connections().is_empty():
		completed.connect(_on_completed)
	_give_badge()
	screwdrivers.stock(players.count())
	spare_walkies.stock(players.count())
	arrival_lift.open()
	stage = "hidden"
	_place_watcher(STAGES.hidden[0], STAGES.hidden[1])
	if lab.wanted():
		# Rourke is still their escort: he takes them to Vale's lab first, and turns there.
		booth.locked = true
		booth.locked_message = "NIGHT DESK TERMINAL. STAFF LOGIN REQUIRED."
		await lab.run()
		booth.locked = false
		_escape_radio(RADIO_AFTER_UNTIED if Game.rourke_fate == "untied" else -1.0)
		# A quiet stretch: the alarm is over, and nothing moves until they find Pike.
		await sync.gate("back_at_booth", func():
			if not _anyone_in_booth_corridor():
				await _crew_reaches_corridor())
	else:
		lab.skip()
		if Game.rourke_fate == "tied":
			await _escape_radio(0.0)
	_book_check("easy_sql_10")  # the camera card, read on the way to the lab
	hud.todo("Find a way out of the security wing")
	await hud.lines(["l2_arrive", "l2_cameras"])
	if not cameras_puzzle.solved:
		hud.todo("Check the security booth terminal")
		Game.open_case("cameras", CASES.cameras, ["cameras"])


## The lab reader wants the visitor badge from the front desk. Started here on its
## own (no Level 0), each machine clips one on its player, numbered as Level 0 does.
func _give_badge() -> void:
	if player.inventory.has("visitor_badge"):
		return
	Game.visitor_badge_no = lab.badge_no(multiplayer.get_unique_id())
	player.inventory.add("visitor_badge")
	hud.notice("Visitor badge %s clipped on." % Game.visitor_badge_no, 4.0)


## Left untied, Rourke comes round soon after the crew leaves the lab. Tied, it
## takes him a while longer to cut himself loose: he's on the radio once they
## start on the cameras. `after` < 0 waits for that.
const RADIO_AFTER_UNTIED := 15.0
var _radio_played := false


func _escape_radio(after: float) -> void:
	if Game.rourke_fate != "tied" and Game.rourke_fate != "untied":
		return
	if after < 0.0:
		await sync.gate("radio_tied", func():
			while not cameras_puzzle.solved:
				await get_tree().create_timer(0.5, false).timeout
			await get_tree().create_timer(10.0, false).timeout)
	else:
		await get_tree().create_timer(after, false).timeout
	if _radio_played:
		return
	_radio_played = true
	lab.rourke.visible = false
	lab.rourke.process_mode = Node.PROCESS_MODE_DISABLED
	await hud.lines(["l2_rourke_1", "l2_rourke_2", "l2_rourke_3"])


## Host: wait until someone walks back into the booth's corridor.
func _crew_reaches_corridor() -> void:
	while not _anyone_in_booth_corridor():
		await get_tree().create_timer(0.25, false).timeout


func _anyone_in_booth_corridor() -> bool:
	return players.all_players().any(func(p): return _booth_corridor.has_point(to_local(p.global_position) + Vector3.UP * 0.5))


func _process(delta: float) -> void:
	if not active:
		return  # built behind Server Room A's exit, waiting for players
	_clock += delta
	_cam_tick -= delta
	if _cam_tick <= 0.0:
		_cam_tick = 1.0
		update_cameras()
	if player and player.health > 0.0 and player.global_position.y < -6.0:
		_fell = true
		player.take_damage(1000.0, "fall")  # instant: through on_player_died, for the fall notice
	_update_ledge(delta)
	if not reached_vestibule and player and _in([_vestibule_box], player.global_position):
		reached_vestibule = true  # this machine's player respawns here from now on
	if sync.is_host():
		# The host runs the Watcher and decides the story beats, for everyone.
		if loose and not _lie_explained and players.all_players().any(func(p): return _in([_vestibule_box], p.global_position)):
			sync.event("explain_cam_lie", [_cam2_frame()])
		_update_watcher_stage()
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


## Is a world-space point inside any of these level-space boxes?
func _in(boxes: Array, p: Vector3) -> bool:
	var local := to_local(p) + Vector3.UP * 0.5
	for b in boxes:
		if b.has_point(local):
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


## Host: a request went through at `which` terminal ("booth" or "panel").
## What it means plays out on every machine.
func _on_request(line: String, res: Dictionary, _ui: TerminalUI, which: String) -> void:
	if res.status != 200:
		return
	if line.to_lower().contains("/doors"):
		if pin_entered and not door_checked and not door_open:
			sync.event("_on_door_checked", [which])
		return
	if not line.to_lower().contains("/cameras"):
		return
	if not cameras_puzzle.solved:
		sync.event("_on_cameras_found", [which])
	elif loose and not _lie_explained and not _in(cam_zones["CAM-2"], watcher.global_position):
		sync.event("_on_lie_spotted", [which, _cam2_frame()])


## The only nudge on the HUD: there's something to read at a terminal.
const NEW_MESSAGE := "New message on the security terminals."


## A line from SYSOP: someone else on the network, typing to you.
func sysop(t: Terminal, text: String) -> void:
	t.print_line(TerminalUI.sysop(text))


## Lines for both security terminals, so they can go in the notebook: on screen if
## a terminal has been used, otherwise in what it shows when someone sits down.
func _broadcast(lines: Array) -> void:
	for t in [booth, panel]:
		if t.transcript.is_empty():
			t.boot_lines.append_array(lines)
		else:
			for l in lines:
				t.print_line(l)


func _term(which: String) -> Terminal:
	return panel if which == "panel" else booth


func _on_cameras_found(which: String) -> void:
	var t := _term(which)
	if not cameras_puzzle.solved:
		cameras_puzzle.solved = true
		t.print_line("")
		sysop(t, "that's JSON. { } is one camera's fields, [ ] is a list of cameras.")
		sysop(t, "each field is a name and a value, like \"motion\": true.")
		sysop(t, "cam-2 says motion in the security office. look through the window. cam-2 is the only thing watching that room.")
		t.print_line("")
		sysop(t, "doors here want a guard's PIN. they're in the table [b]guards[/b]. long roster. count it, or peek:")
		t.print_line("    [color=#ffffff]SELECT COUNT(*) FROM guards;[/color]     how many rows")
		t.print_line("    [color=#ffffff]SELECT * FROM guards LIMIT 5;[/color]    just the first 5")
		sysop(t, "pike's name is clear on the sign-in sheet. find his row with a pattern:")
		t.print_line("    [color=#ffffff]SELECT * FROM guards WHERE name LIKE 'Pike%';[/color]")
		t.print_line("      LIKE 'Pike%'   names that start with Pike. % = any letters after")
		hud.todo("Look up Officer Pike's PIN")
		Game.open_case("cameras", CASES.cameras, ["cameras"])
		Game.solve_case("cameras", "CAM-2 reports motion in the security office. It's the only camera pointed at that room.")
		Game.open_case("pin", CASES.pin, ["guards", "badge_log"])
		_book_check("easy_sql_11")


## Someone worked out the frozen camera for themselves.
func _on_lie_spotted(which: String, frame: String) -> void:
	if _lie_explained:
		return
	var t := _term(which)
	_lie_explained = true
	Game.cam_lie_learned = true
	t.print_line("")
	sysop(t, "you saw it. cam-2 says 'live', motion in the office. it isn't in the office.")
	sysop(t, "cam-2's last_frame stopped at %s. server_time didn't. hardware fault, the picture froze." % frame)
	sysop(t, "the status says 'live'. the data says otherwise. check the data.")
	Game.add_clue("cameras", CAM_LIE_CLUE % frame, "SYSOP")


const CAM_LIE_CLUE := "CAM-2 froze at %s. It still says 'live', but it sees nothing. Compare last_frame with server_time."


func _cam2_frame() -> String:
	return str(db.run_silent("SELECT last_frame FROM cameras WHERE id = 'CAM-2'")[0]["last_frame"])


## Everyone gets the frozen-camera lesson: the first time it gets someone, or when
## they reach the vestibule without having worked it out. Shown on screen, and
## printed as terminal lines (on both terminals) so it can be written into the notebook.
## Runs on every machine; `frame` is the frozen time, as the host's cameras table has it.
func explain_cam_lie(frame: String) -> void:
	if _lie_explained or not loose:
		return
	_lie_explained = true
	_lie_fresh = true
	Game.cam_lie_learned = true
	var lines := [
		"",
		TerminalUI.sysop("cam-2 froze at %s. it hasn't seen the office since. it still says 'live'." % frame),
		TerminalUI.sysop("a camera can say 'live' and still be stuck. to check one:"),
		"    [color=#ffffff]GET /cameras[/color]",
		TerminalUI.sysop("then compare its last_frame with server_time. if last_frame stopped, it sees nothing."),
	]
	_broadcast(lines)
	Game.add_clue("cameras", CAM_LIE_CLUE % frame, "SYSOP")
	_lie_notice = NEW_MESSAGE
	hud.notice(_lie_notice, 5.0, ThemeUtil.AMBER)
	await get_tree().create_timer(6.0).timeout
	_lie_fresh = false


## Host: a paper or terminal brings back chapter `id` of Easy SQL. Found before its
## puzzle is open, it waits for that (_book_check).
func _book_found(id: String) -> void:
	if sync.is_host() and not _books.has(id):
		_books[id] = "found"
		_book_check(id)


## Host: play chapter `id` if it has been found and its puzzle is open.
func _book_check(id: String) -> void:
	if sync.is_host() and _books.get(id, "") == "found" and _book_ready(id):
		_books[id] = "played"
		sync.event("_book_huddle", [id])


func _book_ready(id: String) -> bool:
	match id:
		"easy_sql_10":
			return lab.phase == "done"  # the cameras come after the lab
		"easy_sql_11":
			return cameras_puzzle.solved  # the Pike search
		"easy_sql_13":
			return (door_asked or door_checked) and not door_open
	return true


## Every machine: a chapter of Easy SQL comes into the crew's book (once per run).
## Nothing stops for it, the Watcher included.
func _book_huddle(id: String) -> void:
	await Huddle.of(self).run(id)


## Host: a query ran at `which` terminal. Puzzle results play out on every machine.
func _on_query(sql: String, result: Dictionary, _ui: TerminalUI, which: String) -> void:
	if not pike_puzzle.solved and pike_puzzle.matches(db, result):
		sync.event("_on_pike_found", [which])
	if not har_puzzle.solved and har_puzzle.matches(db, result):
		sync.event("_on_har_found", [which])
	if sql.to_lower().contains("door_status") and not result.rows.is_empty() and pin_entered and not door_checked and not door_open:
		sync.event("_on_door_checked", [which])


func _on_pike_found(which: String) -> void:
	var t := _term(which)
	if not pike_puzzle.solved:
		pike_puzzle.solved = true
		t.print_line("")
		t.print_line("[color=#e0b050]WARDEN: Officer Pike's PIN is suspended. Nobody has seen him since Tuesday.[/color]")
		sysop(t, "you need a night-shift guard who badged in tonight. the badge readers know who. so does the sign-in sheet, under the coffee.")
		hud.todo("Find out who else has a working PIN")
		Game.add_clue("pin", "Officer Pike's PIN is suspended. Nobody has seen him since Tuesday.", "WARDEN")
		# The answer only leads to the next search: the book's review of that, before it hunts.
		await _book_huddle("easy_sql_12")
		sysop(t, "[color=#ff6655]something in the office is moving. it only moves while nothing is watching it. not you, not a working camera.[/color]")
		hud.line("l2_smudged")
		_set_loose()
		_set_stage("near")
		# From here it hunts, so the Har search is typed under pressure. The locked
		# office door and its glass still stand between it and the booth.
		wake_watcher()


func _on_har_found(which: String) -> void:
	var t := _term(which)
	if not har_puzzle.solved:
		har_puzzle.solved = true
		t.print_line("")
		t.print_line("[color=#e0b050]WARDEN: %s, night shift. Badged in 22:00. PIN on file.[/color]" % data.name)
		sysop(t, "that PIN opens the office door, and the SEC-EXIT keypad past it.")
		sysop(t, "[color=#ff6655]it's on the other side of that door. open it, and keep your eyes on it.[/color]")
		hud.todo("Open the office door. Keep eyes on it")
		Game.solve_case("pin", "%s, night shift, badged in 22:00. That PIN opens the office and the SEC-EXIT keypad." % data.name)
		_set_loose()
		_set_stage("window")


## CAM-2 freezes on its last frame. The Watcher is free, and the camera still says "live".
func _set_loose() -> void:
	if loose:
		return
	loose = true
	frozen_cams["CAM-2"] = true
	for l in lights.get("office", []):
		FlickerLight.attach(l, 0.4)
	# WARDEN's fake-out, broadcast to the security terminals.
	_broadcast(["[color=#e0b050]WARDEN: CAM-2 LIVE. ALL CAMERAS NOMINAL.[/color]"])


## Move the Watcher to its next spot as soon as nobody is looking at it.
## Once it's awake it hunts on its own. The host moves it; clients mirror it.
func _set_stage(next: String) -> void:
	if watcher.active or not sync.is_host():
		return
	_stage_pending = next
	_update_watcher_stage()


func _update_watcher_stage() -> void:
	if not watcher.active and not _stage_pending.is_empty() and not watcher.is_watched():
		stage = _stage_pending
		_stage_pending = ""
		watcher.step_to(to_global(STAGES[stage][0]), to_global(STAGES[stage][1]))
	# It wakes once the office door opens, or once anyone leaves the corridor another way.
	if not watcher.active and (office_open or (loose and players.all_players().any(func(p): return not _corridor_box.has_point(to_local(p.global_position))))):
		wake_watcher()


func wake_watcher() -> void:
	if watcher.active:
		return
	_stage_pending = ""
	watcher.active = true


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


## Host: a key went down on a door's keypad. Every machine plays it in order,
## so the pads show the same digits everywhere and the same PIN opens the door.
func _on_pad_key(key: String, _by: Node, which: String) -> void:
	sync.event("_pad_key", [which, key])


func _pad(which: String) -> Level2Keypad:
	return office_pad if which == "office" else exit_pad


func _pad_key(which: String, key: String) -> void:
	var pad := _pad(which)
	if which == "office" and office_open:
		pad.show_text("SEC-OFFICE\nOPEN", ThemeUtil.GREEN)
		return
	if which == "exit" and pin_entered:
		pad.show_text("SEC-EXIT\n" + ("OPEN" if door_open else "UNLOCKED"), ThemeUtil.GREEN)
		return
	if key != "E":
		pad.press(key)
		return
	var result := check_pin(pad.take_code())
	if not result.ok:
		pad.show_text(result.message, ThemeUtil.RED)
		return
	pad.show_text(result.message, ThemeUtil.GREEN)
	_pin_ok(which)


## Type a PIN on a door's keypad and press Enter, key by key, as a player does.
func type_pin(which: String, pin: String, by: Node = null) -> void:
	var pad := _pad(which)
	var who: Node = by if by else player
	for k in pin.split(""):
		if pad.keys.has(k):
			pad.keys[k].interact(who)
	pad.keys["E"].interact(who)


func _pin_ok(which: String) -> void:
	if which == "office":
		open_office()
	elif not pin_entered:
		enter_pin()


## The button past SEC-EXIT: shuts and locks it. Closing a door needs no PIN.
func _seal_pressed() -> void:
	if door_open:
		seal_exit()


## The office door opens, and whatever is at the window is free to move.
func open_office() -> void:
	if office_open:
		return
	office_open = true
	db.run_silent("UPDATE doors SET locked = 0 WHERE id = 'SEC-OFFICE'")
	db.run_silent("UPDATE door_status SET sensor = 'open', note = 'normal' WHERE door_id = 'SEC-OFFICE'")
	db.sync_world()
	hud.notice("> PIN ACCEPTED: %s\n> DOOR SEC-OFFICE: OPENED" % data.name, 4.0, ThemeUtil.GREEN)
	hud.todo("Get past it to the SEC-EXIT keypad. Keep eyes on it")
	wake_watcher()


## Is this the right PIN? Wrong ones say why, in the building's own words.
func check_pin(pin: String) -> Dictionary:
	if pin.length() != 4 or not pin.is_valid_int():
		return {"ok": false, "message": "A PIN IS 4 DIGITS"}
	if pin == data.pin:
		return {"ok": true, "message": "PIN ACCEPTED\n%s" % data.name}
	var rows := db.run_silent("SELECT name, shift, note FROM guards WHERE pin = '%s'" % pin)
	if rows.is_empty():
		return {"ok": false, "message": "PIN NOT RECOGNIZED"}
	var g: Dictionary = rows[0]
	return {"ok": false, "message": "REFUSED: %s\n%s shift. %s\nLOCKDOWN: NIGHT SHIFT, BADGED IN" % [g["name"], g["shift"], g["note"]]}


## The right PIN unlocks the door in the database. If the actuator is still
## faulted, the door doesn't move, and the keypad says "opened" anyway.
func enter_pin() -> void:
	pin_entered = true
	db.run_silent("UPDATE doors SET locked = 0 WHERE id = 'SEC-EXIT'")
	db.sync_world()
	hud.notice("> PIN ACCEPTED: %s\n> DOOR SEC-EXIT: OPENED" % data.name, 4.0, ThemeUtil.GREEN)
	if _update_door():
		return
	hud.todo("Get through SEC-EXIT")
	await hud.line("l2_door_ok")
	await get_tree().create_timer(5.0).timeout
	if not door_open and not door_checked:
		_broadcast([TerminalUI.sysop("it didn't open. check the door's sensor at the vestibule panel:"), "    [color=#ffffff]GET /doors/SEC-EXIT[/color]"])
		hud.notice(NEW_MESSAGE, 4.0)
		hud.todo("Find out why SEC-EXIT is still shut")
		Game.open_case("door", CASES.door, ["door_status"])
		door_asked = true
		_book_check("easy_sql_13")


func _on_door_checked(which: String) -> void:
	var t := _term(which)
	if not pin_entered or door_checked or door_open:
		return
	door_checked = true
	door_asked = true
	_book_check("easy_sql_13")
	t.print_line("")
	sysop(t, "keypad said OPENED. locked is false, so the request went through.")
	sysop(t, "but sensor says 'closed' and actuator says 'fault'. the door never moved. read the note.")
	sysop(t, "a request going through isn't the thing happening. check the sensor, not the request.")
	hud.todo("Fix whatever jammed the door, then check it again")
	Game.open_case("door", CASES.door, ["door_status"])
	Game.add_clue("door", "The keypad's request went through, but the sensor says closed and the actuator says fault. The note names a breaker.", "SYSOP")
	hud.line("l2_door_fault")


## Host: someone pressed breaker `i`. Everyone sees what it does.
func _on_breaker(_p: Node, i: int) -> void:
	sync.event("_breaker_flipped", [i])


func _breaker_flipped(i: int) -> void:
	if i == data.breaker:
		db.run_silent("UPDATE doors SET actuator_fault = 0 WHERE id = 'SEC-EXIT'")
		db.run_silent("UPDATE door_status SET actuator = 'ok', note = 'normal' WHERE door_id = 'SEC-EXIT'")
		breakers[i].enabled = false
		breakers[i].rotation.z = 0.5  # the switch stays thrown
		hud.notice("> BREAKER B-%d: RESET" % i, 3.5, ThemeUtil.GREEN)
		# The jammed bolt lets go inside the door frame.
		Level2FX.sound(geo, breakers[i].position, "click")
		Level2FX.sound(geo, SEC_EXIT_FRAME, "clunk")
		db.sync_world()
		_update_door()
		return
	# The wrong breaker cuts this room's lights and its camera for a few seconds.
	Level2FX.sound(geo, breakers[i].position, "click")
	frozen_cams["CAM-3"] = true
	_broadcast(["[color=#ff6655]> CAM-3: NO SIGNAL[/color]"])
	breaker_status.text = "> CAM-3: NO SIGNAL"
	for l in lights.get("vestibule", []):
		l.visible = false
	await get_tree().create_timer(6.0).timeout
	frozen_cams.erase("CAM-3")
	_broadcast(["[color=#7fd47f]> CAM-3: SIGNAL RESTORED[/color]"])
	breaker_status.text = ""
	for l in lights.get("vestibule", []):
		l.visible = true


## Is the door physically open now? Keeps door_status in step with the world.
func _update_door() -> bool:
	var row: Dictionary = db.run_silent("SELECT locked, actuator_fault FROM doors WHERE id = 'SEC-EXIT'")[0]
	var open := int(row["locked"]) == 0 and int(row["actuator_fault"]) == 0
	db.run_silent("UPDATE door_status SET sensor = '%s' WHERE door_id = 'SEC-EXIT'" % ("open" if open else "closed"))
	if open:
		door_puzzle.solved = true
	if open and not door_open:
		door_open = true
		hud.todo("Take the stairs down. Lock SEC-EXIT behind us if we can")
		Game.open_case("door", CASES.door, ["door_status"])
		Game.solve_case("door", "Breaker B-%d had tripped and jammed the door. Resetting it let the door open." % data.breaker)
		stair_door.locked = false
		prepare_next()  # floor 18 builds now, behind the stairwell
	return open


func seal_exit() -> void:
	db.run_silent("UPDATE doors SET locked = 1 WHERE id = 'SEC-EXIT'")
	db.sync_world()
	door_open = false
	_update_door()
	Game.watcher_sealed = true
	hud.notice("> DOOR SEC-EXIT: LOCKED", 4.0, ThemeUtil.GREEN)
	Level2FX.sound(geo, SEC_EXIT_FRAME, "clunk")


## Everyone is on the stairs. In the World the crew heads down to floor 18 (Level 3);
## on its own, the slice ends here.
func _on_exit(_b: Node) -> void:
	# Everyone here finished the floor, downed or not.
	get_node("/root/Net").earn("achievement:floor_22", hud)
	if not player:
		return
	# A downed player on the stairs goes down to 18 with everyone else (the trigger
	# counted them), and stays down there until revived: only the card is for the living.
	var up := player.health > 0.0
	var was_locked := player.input_locked
	player.input_locked = true
	# No words: one tap on the metal, from behind SEC-EXIT.
	await get_tree().create_timer(1.0).timeout
	Level2FX.sound(geo, SEC_EXIT_FRAME, "tap")
	await get_tree().create_timer(1.2).timeout
	var next: Node = world.wings.get("level_3") if world else null
	if next and next.has_method("arrive_by_stairs"):
		# Four flights down behind a fade: everyone steps onto 18's landing.
		await hud.fade(true, 1.2)
		Game.completed_level = "level_2"
		Game.next_level = "level_3"
		next.arrive_by_stairs()
		finish_level("level_3")
		player.input_locked = was_locked if not up else false
		hud.fade(false, 0.8)
		return
	if not up:
		player.input_locked = was_locked
		return
	await Level2FX.end_card(self, "To be continued.")
	Game.completed_level = "level_2"
	Game.next_level = ""  # the end of the playable slice, for now
	completed.emit()


## The end of the route: Field Notes, over the live World or as its own scene.
func _on_completed() -> void:
	await hud.fade(true, 1.2)
	finish_level("field_notes")


## Host: it reached someone. The first time, everyone learns why the camera didn't stop it.
func _on_caught(p: Node) -> void:
	if loose and not _lie_explained:
		sync.event("explain_cam_lie", [_cam2_frame()])
	if p.has_method("take_damage") and p.health > 0.0:
		p.take_damage(1000.0, "watcher")  # out cold: teammates can help them up


## Rourke downed the whole crew: the frame worked, and the news says so.
func on_crew_down(cause: String) -> void:
	if cause == "rourke" and lab.phase == "fight":
		lab.crew_beaten()
	else:
		super(cause)


func on_player_died() -> void:
	var solo := not sync.is_online()
	if _fell:
		_fell = false
		if FALL_NOTICE != "":
			# After the usual "You came to", which the level base shows once this returns.
			hud.notice.call_deferred(FALL_NOTICE, 4.0)
	if lab.in_progress():
		player.respawn(lab.respawn_point())
		if solo:
			lab.reset_fight()
		return
	if reached_vestibule:
		player.respawn(global_transform * Transform3D(Basis(), Vector3(0, 0.1, -10.8)))
		if solo:
			_place_watcher(Vector3(-4.5, 0, 4.5), Vector3(0, 0, -10))
	else:
		player.respawn(spawn_point())
		if solo:
			_place_watcher(STAGES[stage][0], STAGES[stage][1])
	# In co-op it keeps hunting the others where it is.
	if loose and not _lie_explained and sync.is_host():
		sync.event("explain_cam_lie", [_cam2_frame()])
	if _lie_fresh:
		_lie_fresh = false
		# Again after "You came to", which replaces it: say why the camera didn't stop it.
		await get_tree().create_timer(2.5).timeout
		hud.notice(_lie_notice, 8.0, ThemeUtil.AMBER)


## Stand the Watcher at a spot in the level's own space, facing another.
func _place_watcher(at: Vector3, look: Vector3) -> void:
	watcher.place(to_global(at), to_global(look))
