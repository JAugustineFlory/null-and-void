extends SceneTree
## Review shots of the twelve playable crew (PlayableCrew), each on their own
## build (CharacterLooks.CREW_BODIES): front and three-quarter, against a height
## chart, labelled with their name, plus everyone in one line-up. The clothes
## and colours are only examples (players pick their own). Needs a display:
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver vulkan --resolution 1280x800 -s tools/crew_shots.gd -- OUT_DIR [plain|shaped] [TURN]
## "plain" shows everyone on the two stock bodies instead, for comparison; TURN
## (degrees, 45 by default) is how far round the second view is.

## Example outfits for the sheet, one per crew member: skin index, then
## slot -> [item, color].
const DRESS := {
	"dana": [5, {"hair": ["short", Color(0.06, 0.05, 0.05)], "top": ["tee", Color(0.36, 0.42, 0.3)], "legs": ["pants", Color(0.22, 0.24, 0.3)]}],
	"priya": [4, {"hair": ["long", Color(0.05, 0.04, 0.04)], "top": ["polo", Color(0.85, 0.35, 0.45)], "ears": ["studs", Color(0.85, 0.75, 0.4)]}],
	"rosa": [3, {"hair": ["bob", Color(0.16, 0.1, 0.07)], "top": ["blouse", Color(0.88, 0.84, 0.76)], "jacket": ["blazer", Color(0.35, 0.22, 0.35)], "face": ["glasses", Color(0.3, 0.12, 0.12)]}],
	"kit": [0, {"hair": ["short", Color(0.85, 0.7, 0.4)], "top": ["tee", Color(0.2, 0.55, 0.75)], "feet": ["high_tops", Color(0.92, 0.92, 0.9)]}],
	"june": [1, {"hair": ["bob", Color(0.78, 0.78, 0.76)], "top": ["longsleeve", Color(0.45, 0.55, 0.62)], "face": ["glasses", Color(0.55, 0.45, 0.3)]}],
	"mei": [1, {"hair": ["long", Color(0.08, 0.06, 0.05)], "top": ["tee", Color(0.9, 0.62, 0.3)], "face": ["glasses", Color(0.12, 0.1, 0.1)]}],
	"marcus": [6, {"hair": ["short", Color(0.06, 0.05, 0.05)], "top": ["polo", Color(0.3, 0.32, 0.36)], "jacket": ["security", Color(0.2, 0.24, 0.32)], "face": ["mustache", Color(0.08, 0.07, 0.06)]}],
	"theo": [2, {"hair": ["short", Color(0.35, 0.22, 0.12)], "head": ["cap", Color(0.6, 0.15, 0.15)], "top": ["tee", Color(0.2, 0.2, 0.22)]}],
	"sam": [7, {"hair": ["bald", Color(0.05, 0.04, 0.04)], "top": ["tee", Color(0.55, 0.32, 0.22)], "legs": ["pants", Color(0.3, 0.3, 0.32)]}],
	"luis": [3, {"hair": ["short", Color(0.55, 0.55, 0.53)], "top": ["polo", Color(0.4, 0.5, 0.35)], "jacket": ["jacket", Color(0.45, 0.33, 0.22)], "face": ["mustache", Color(0.5, 0.5, 0.48)]}],
	"ike": [0, {"hair": ["short", Color(0.55, 0.4, 0.22)], "top": ["longsleeve", Color(0.92, 0.92, 0.9)], "jacket": ["blazer", Color(0.18, 0.2, 0.26)], "face": ["glasses", Color(0.1, 0.1, 0.1)]}],
	"walt": [2, {"hair": ["short", Color(0.4, 0.26, 0.14)], "head": ["hard_hat", Color(0.9, 0.75, 0.15)], "top": ["longsleeve", Color(0.62, 0.3, 0.2)], "jacket": ["jacket", Color(0.24, 0.27, 0.22)]}],
}

var out_dir := "user://crew_shots"
var turned := 45.0
static var plain := false
var cam: Camera3D
var label: Label
var world: Node3D
var chart: Array[Node3D] = []  # the height marks and their labels


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	plain = args.size() > 1 and args[1] == "plain"
	if args.size() > 2:
		turned = float(args[2])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_studio()
	cam = Camera3D.new()
	cam.fov = 30
	world.add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(24, 16)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.14))
	layer.add_child(label)
	var i := 0
	for slug in PlayableCrew.slugs():
		var who := PlayableCrew.info(slug)
		var pair := []
		for turn in [0.0, turned]:
			var n := Node3D.new()
			n.position = Vector3(-0.55 if turn == 0.0 else 0.55, 0, 0)
			n.rotation_degrees.y = 180.0 + turn  # the models face -z
			world.add_child(n)
			CharacterRig.build(n, look_of(slug, i))
			pair.append(n)
		cam.position = Vector3(0, 1.0, 5.2)
		cam.look_at(Vector3(0, 0.95, 0))
		label.text = "%s, %s\n%s  ·  %.2f m" % [who.name, who.age, who.about, height_of(slug)]
		await _frames(40)
		_save(slug)
		for n in pair:
			n.queue_free()
		i += 1
	# Everyone in a row, shortest to tallest.
	var order := PlayableCrew.slugs()
	order.sort_custom(func(a, b): return height_of(a) < height_of(b))
	var names := []
	for k in order.size():
		var n := Node3D.new()
		n.position = Vector3((k - (order.size() - 1) / 2.0) * 0.62, 0, 0)
		n.rotation_degrees.y = 180.0
		world.add_child(n)
		CharacterRig.build(n, look_of(order[k], PlayableCrew.slugs().find(order[k])))
		names.append(PlayableCrew.info(order[k]).name.get_slice(" ", 0))
	for n in chart:
		n.position.x += signf(n.position.x) * 2.6  # out past the ends of the line
	cam.fov = 40
	cam.position = Vector3(0, 1.0, 7.8)
	cam.look_at(Vector3(0, 0.95, 0))
	label.text = "The crew, shortest to tallest: " + ", ".join(names)
	await _frames(40)
	_save("lineup")
	quit()


static func look_of(slug: String, index: int) -> Dictionary:
	var dress: Array = DRESS.get(slug, [2, {}])
	var choice := {"crew": slug, "skin": dress[0], "head": {"item": "none"}, "face": {"item": "none"}}
	for slot in dress[1]:
		choice[slot] = {"item": dress[1][slot][0], "color": dress[1][slot][1]}
	var look := CharacterLooks.outfit(Cosmetics.clean(choice, index))
	if plain:
		look.merge({"height": 1.0, "build": 0.95 if look.body == 2 else 1.0, "shape": {}, "stoop": 0.0}, true)
	return look


## Standing height in metres: the model's (body 1 is 1.81 m, body 2 1.77 m) times theirs.
static func height_of(slug: String) -> float:
	var info := PlayableCrew.info(slug)
	return (1.81 if info.body == 1 else 1.77) * (1.0 if plain else float(CharacterLooks.CREW_BODIES.get(slug, {}).get("height", 1.0)))


func _studio() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.86, 0.86, 0.84)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.78)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.1
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -140, 0)
	fill.light_energy = 0.35
	world.add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 6)
	floor_mi.mesh = pm
	floor_mi.material_override = ArtPalette.flat(Color(0.72, 0.72, 0.7), 0.9)
	world.add_child(floor_mi)
	# A height ruler on each side, standing on the floor level with them: a
	# tick every 10 cm up to 2 m, longer every 50 cm, labelled on the left.
	var ink := ArtPalette.flat(Color(0.35, 0.35, 0.4), 0.9)
	for x in [-1.25, 1.25]:
		var post := MeshInstance3D.new()
		var pm2 := BoxMesh.new()
		pm2.size = Vector3(0.01, 2.0, 0.01)
		post.mesh = pm2
		post.position = Vector3(x, 1.0, 0)
		post.material_override = ink
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(post)
		chart.append(post)
		for k in 21:
			var h := k * 0.1
			var major := k % 5 == 0
			var mark := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.2 if major else 0.1, 0.006, 0.006)
			mark.mesh = lm
			mark.position = Vector3(x + signf(x) * lm.size.x / 2.0, h, 0)
			mark.material_override = ink
			mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(mark)
			chart.append(mark)
			if x > 0 or k == 0 or (k < 14 and not major):
				continue
			var tag := Label3D.new()
			tag.text = "%.1f m" % h
			tag.pixel_size = 0.002
			tag.font_size = 40
			tag.outline_size = 0
			tag.modulate = Color(0.3, 0.3, 0.34)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			tag.position = Vector3(x - 0.24, h, 0)
			world.add_child(tag)
			chart.append(tag)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(shot: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot + ".png"))
	print("saved ", shot)
