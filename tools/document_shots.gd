extends SceneTree
## Lookdev screenshots of the document props and the close-up reading view. Needs a display:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 -s tools/document_shots.gd -- OUT_DIR

var out_dir := "user://document_shots"
## Level 2's night-shift sheet as a Document's lines (see DocumentView.add_entry).
const SIGN_IN := [
	{"columns": ["NAME", "BADGE #", "IN", "OUT", "INIT."], "widths": [3.4, 1.8, 1.3, 1.3, 1.2]},
	{"row": ["PIKE, H.", "", "", "", ""], "over": "NO SHOW", "text": "PIKE, H.  no show"},
	{"row": ["Har", "", "22:00", "", ""], "stain": "coffee", "stain_at": 0, "text": "Har... (coffee stain)  22:00"},
	{"row": ["", "", "", "", ""]},
	{"row": ["", "", "", "", ""]},
	{"row": ["", "", "", "", ""]},
	"",
	"Guard PINs are kept on file in the table:",
	{"text": "guards", "hand": true},
	{"stamp": "WARDEN  LOGGED", "color": "blue"},
]
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = ArtMood.environment("office")
	world.add_child(env)
	_office(world)
	cam = Camera3D.new()
	cam.fov = 60
	world.add_child(cam)
	cam.make_current()

	# A reception desk with everything on it, from where a player stands.
	_cam(Vector3(0, 1.55, -1.25), 180, -42)
	await _frames(20)
	_save("doc_desk")
	_cam(Vector3(0.45, 1.2, -0.75), 180, -50)
	await _frames(10)
	_save("doc_desk_close")
	# The noticeboard and the clipboard by the door.
	_cam(Vector3(-2.2, 1.55, -1.6), 180, -6)
	await _frames(10)
	_save("doc_wall")

	# The reading view, one per paper.
	var layer := CanvasLayer.new()
	layer.layer = 15
	root.add_child(layer)
	var doc := DocumentView.new()
	layer.add_child(doc)
	doc.set_paper("manual")
	doc.set_title("FACILITIES MANUAL\nSection 4.2: Door control")
	doc.add_line("Every door in the building has one row in the doors table.")
	doc.add_line("The locked column is 1 for locked, 0 for open.")
	doc.add_margin_note("not every door! the old wing isn't in it. - H.M.")
	doc.add_line("To list them all: SELECT * FROM doors;")
	doc.add_line("Badge readers check badge_level before they unlock.")
	doc.add_margin_note("readers can be wrong. check the log.")
	doc.add_blank("Guards' clock-in times are kept in a table of ", "guards", ".")
	doc.add_line("Report faults to Facilities, ext. 4410.")
	doc.add_margin_note("don't. ask me.\n- H.M.")
	doc.add_margin_note("who is H.M.??", "player")
	doc.show_doc()
	await _frames(30)
	_save("doc_view_manual")

	doc.clear()
	doc.set_paper("card")
	doc.set_title("NIGHT GUARDS - CLOCK IN HERE")
	doc.add_blank("Your clock-in time is saved in the ", "guards", " table.", "player")
	doc.add_line("Swipe your badge at the start and end of every round.")
	doc.add_line("Missed rounds are reported to the shift lead.")
	await _frames(10)
	_save("doc_view_card")

	doc.clear()
	doc.set_paper("brochure")
	doc.set_title("WELCOME TO HALCYON")
	doc.add_line("Your badge opens the doors your job needs.")
	doc.add_line("Every visit is logged for your safety.")
	doc.add_blank("Halcyon stores times in a table of ", "guards", " choice.")
	doc.add_line("Questions? Ask at the front desk.")
	await _frames(10)
	_save("doc_view_brochure")

	doc.clear()
	doc.set_paper("clipboard")
	doc.set_title("NIGHT ROSTER - Wing B")
	for l in ["22:00  R. Rourke     B1, B2", "23:30  D. Okafor     lobby", "01:00  R. Rourke     B1, B2", "02:30  (nobody)"]:
		doc.add_line(l)
	doc.add_margin_note("why is Rourke always on B?", "player")
	await _frames(10)
	_save("doc_view_clipboard")

	# A printed form on a clipboard, filled in by hand, coffee over one name.
	doc.clear()
	doc.set_paper("clipboard")
	doc.set_title("NIGHT SHIFT SIGN-IN      DATE: 10/15")
	doc.add_lines(SIGN_IN)
	await _frames(10)
	_save("doc_view_signin")

	doc.clear()
	doc.set_paper("memo")
	doc.set_title("MEMO\nTo: all staff   Re: badge audit")
	doc.add_line("The badge audit runs Friday night. Leave terminals logged in.")
	doc.add_line("Do not unplug the Warden console under any circumstances.")
	doc.add_margin_note("unplug it. - H.M.")
	await _frames(10)
	_save("doc_view_memo")
	quit()


func _office(world: Node3D) -> void:
	_slab(world, Vector3(0, -0.1, -2), Vector3(8, 0.2, 8), ArtPalette.surface("carpet"))
	_slab(world, Vector3(0, 1.5, 0.1), Vector3(8, 3, 0.2), ArtPalette.surface("drywall"))
	_slab(world, Vector3(-4, 1.5, -2), Vector3(0.2, 3, 8), ArtPalette.surface("drywall"))
	ArtMood.apply_to_lights([ArtProps.troffer(world, Vector3(0, 3.0, -1.0)), ArtProps.troffer(world, Vector3(-2, 3.0, -1.5))], "office")
	ArtProps.desk(world, Vector3(0, 0, -0.45), 0, 1.8)
	var top := 0.762
	ArtProps.binder(world, Vector3(-0.45, top, -0.45), 8, "FACILITIES MANUAL")
	ArtProps.desk_card(world, Vector3(0.45, top, -0.75), 10, "NIGHT GUARDS: CLOCK IN")
	ArtProps.brochure(world, Vector3(0.25, top, -0.4), -12, "WELCOME TO HALCYON")
	ArtProps.brochure(world, Vector3(0.72, top, -0.25), 15, "VISITOR GUIDE", false)
	ArtProps.memo(world, Vector3(0.6, top, -0.5), 25, "MEMO: badge audit", true)
	ArtProps.clipboard(world, Vector3(-0.05, top, -0.55), -6, "NIGHT ROSTER")
	ArtProps.sticky_note(world, Vector3(-0.2, top, -0.75), 0, "WHERE", ArtProps.STICKY_YELLOW, true)
	# On the wall: a noticeboard with memos pinned to it, and a clipboard on a hook.
	var board := ArtProps.corkboard(world, Vector3(-2.2, 1.55, 0.0), 0, Vector2(1.2, 0.9))
	ArtProps.memo(board, Vector3(-0.3, 0.1, -0.017), 0, "FIRE DRILL - FRIDAY")
	ArtProps.memo(board, Vector3(0.25, -0.05, -0.017), 0, "MEMO: badge audit")
	ArtProps.sticky_note(board, Vector3(0.45, 0.3, -0.017), 0, "JOIN", ArtProps.STICKY_COLORS[2])
	ArtProps.clipboard(world, Vector3(-1.3, 1.35, 0.0), 0, "SIGN IN", false)
	ArtProps.poster(world, Vector3(-3.2, 1.6, 0.0), 0, "BADGES MUST BE WORN AT ALL TIMES")


func _slab(world: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	world.add_child(mi)


func _cam(pos: Vector3, yaw: float, pitch: float) -> void:
	cam.position = pos
	cam.rotation_degrees = Vector3(pitch, yaw, 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot + ".png"))
	print("saved ", shot)
