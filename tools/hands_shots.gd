extends "res://tools/diegetic_shots.gd"
## Lookdev screenshots of the hands: on a paper picked up to read (HeldPaper) and
## carrying a sticky note into the notebook (HeldNotebook.follow). Movement moves
## the paper and the note; a stand-in does it here. Needs a display:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 -s tools/hands_shots.gd -- OUT_DIR

const SIGN_IN := [
	{"columns": ["NAME", "BADGE #", "IN", "OUT", "INIT."], "widths": [3.4, 1.8, 1.3, 1.3, 1.2], "text": "NAME  BADGE #  IN  OUT  INIT."},
	{"row": ["PIKE, H.", "", "", "", ""], "over": "NO SHOW", "text": "PIKE, H.  no show"},
	{"row": ["Har", "", "22:00", "", ""], "stain": "coffee", "stain_at": 0, "text": "Har... (coffee stain)  22:00"},
	{"row": ["", "", "", "", ""]},
	"",
	"Guard PINs are kept on file in the table:",
	{"text": "guards", "hand": true},
]


## The bits of the Player the hands read.
class StandIn extends Node3D:
	signal prop_lowered(prop: Node3D)
	var held_prop: Node3D
	var _filing := {}


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = ArtMood.environment("after_hours")
	world.add_child(env)
	_office(world)
	cam = Camera3D.new()
	cam.fov = 75
	world.add_child(cam)
	cam.make_current()
	var player := StandIn.new()
	world.add_child(player)
	var doc := _FakeDoc.new()
	doc.position = Vector3(-1.0, 1.45, -0.03)
	doc.rotation_degrees.y = 180
	world.add_child(doc)
	ArtProps.clipboard(doc, Vector3.ZERO, 180.0, doc.title, false)
	var held := HeldPaper.attach(cam, CharacterLooks.crew(0))
	held.follow(player)
	cam.position = Vector3(-1.0, 1.6, -1.0)
	cam.rotation_degrees = Vector3(-5, 180, 0)
	await _frames(5)
	_save("paper_wall_before")
	# Picked up: the hand goes for it, then the paper comes up to read.
	player.held_prop = doc
	held.hold(doc, Vector2(0.23, 0.32), Vector3.BACK, doc)
	await create_timer(0.25).timeout
	_save("paper_wall_reach")
	var from := cam.global_transform.affine_inverse() * doc.global_transform
	doc.reparent(cam, true)
	var read := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-8.0)), Vector3(0, -0.01, -0.32))
	var tw := create_tween()
	tw.tween_method(func(k: float): doc.transform = from.interpolate_with(read, smoothstep(0.0, 1.0, k)), 0.0, 1.0, 0.4)
	await create_timer(0.2).timeout
	_save("paper_wall_bring")
	await tw.finished
	await create_timer(0.4).timeout
	_save("paper_wall_held")
	# A sticky note filed into the open notebook.
	var nb := HeldNotebook.attach(cam, CharacterLooks.crew(0))
	nb.follow(player)
	var book := NotebookView.new()
	nb.set_content(book)
	book.add_tab("Notes")
	book.select_tab("Notes")
	book.left.add_child(NotebookArt.heading("Notes"))
	doc.visible = false
	player.held_prop = null
	player.prop_lowered.emit(doc)
	await nb.open_book().finished
	var note := ArtProps.sticky_note(cam, Vector3(0.1, -0.05, -0.35), 180, "LIKE 'Dale%'")
	player._filing = {"copy": note, "t": 0.5}
	await create_timer(0.3).timeout
	_save("sticky_carry")
	player._filing = {}
	note.queue_free()
	await create_timer(0.3).timeout
	_save("sticky_done")
	quit()


class _FakeDoc extends Node3D:
	var title := "NIGHT SHIFT SIGN-IN   DATE: 10/15"

	func paper_kind() -> String:
		return "clipboard"

	func lines() -> Array:
		return SIGN_IN
