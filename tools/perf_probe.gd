extends SceneTree
## Measures what the renderer draws from fixed views of each level and the cast,
## for the art budgets in docs/art/style-guide.md (about 1,500 draw calls per view).
## Needs a display (use xvfb-run on servers):
##   xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver vulkan -s tools/perf_probe.gd
## Add `-- old` to measure the primitive characters instead of the skinned ones,
## for a pull request's before and after numbers, and `shots=DIR` to save a
## screenshot of each view there.
##
## Levels load with the primitive characters either way, and the skinned ones
## replace them once the level has settled. Which lamps get a slot in the shadow
## atlas depends on the first frames after loading, and that alone moves a view
## by hundreds of draws, so loading both runs the same way keeps the comparison
## about the characters.

const LEVEL_VIEWS := {
	"res://scenes/level_0.tscn": [
		["l0_spawn", Vector3(0, 0.1, 5.6), 0, -5],
		["l0_desk", Vector3(1.2, 0.1, 0.4), 10, -18],
		["l0_hall", Vector3(8.5, 0.1, 3), -90, 0],
	],
	"res://scenes/level_1.tscn": [
		["l1_entry", Vector3(0, 0.1, 10.5), 0, 0],
		["l1_racks", Vector3(0, 0.1, 5.0), 0, -8],
	],
	"res://scenes/level_2.tscn": [
		["l2_night_desk", Vector3(1.6, 0.1, 8), 90, -5],
		["l2_patrol", Vector3(-9, 0.1, 9.4), 0, 0],
		["l2_lab", Vector3(-10.6, 0.1, 2.8), 50, -12],
		["l2_office", Vector3(0, 0.1, 1.0), 0, -5],
	],
}

var rows: Array[String] = []
var shots := ""
var skinned := true


func _initialize() -> void:
	skinned = not OS.get_cmdline_user_args().has("old")
	CharacterRig.skinned = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shots = a.trim_prefix("shots=")
	_run.call_deferred()


func _run() -> void:
	print("Characters: ", "skinned" if skinned else "primitives")
	rows.append("| View | Draw calls | Objects | Triangles |")
	rows.append("|---|---:|---:|---:|")
	for path in LEVEL_VIEWS:
		var level = load(path).instantiate()
		root.add_child(level)
		await _frames(20)
		level.hud.set_process(false)
		if skinned:
			await _swap_rigs(level)
		for v in LEVEL_VIEWS[path]:
			level.player.global_position = v[1]
			level.player.rotation_degrees.y = v[2]
			level.player.head.rotation_degrees.x = v[3]
			await _measure(v[0])
		level.free()
		await _frames(2)
	# The whole cast at once: twelve crew and the NPCs, the most characters any view shows.
	CharacterRig.skinned = skinned
	var g = load("res://scenes/art_gallery.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	g.camera.position = Vector3(0, 1.7, 6.0)
	g.camera.rotation_degrees = Vector3(-8, 0, 0)
	await _measure("gallery_cast")
	g.free()
	# One character alone, against an empty frame.
	var empty := Node3D.new()
	root.add_child(empty)
	var cam := Camera3D.new()
	empty.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.0, 3.0), Vector3(0, 0.9, 0))
	await _frames(5)
	var base := _info()
	var holder := Node3D.new()
	empty.add_child(holder)
	CharacterRig.build(holder, CharacterLooks.rourke())
	await _frames(5)
	var one := _info()
	rows.append("| one character (Rourke) | %d | %d | %d |" % [one[0] - base[0], one[1] - base[1], one[2] - base[2]])
	print("\n".join(rows))
	quit()


## Settles for 120 frames, then averages over 20: moving characters make lights
## redraw their shadows on some frames and not others.
func _measure(view: String) -> void:
	await _frames(120)
	var sum := [0, 0, 0]
	for f in 20:
		await process_frame
		var i := _info()
		for k in 3:
			sum[k] += i[k]
	rows.append("| %s | %d | %d | %d |" % [view, sum[0] / 20, sum[1] / 20, sum[2] / 20])
	if shots != "":
		root.get_texture().get_image().save_jpg(shots.path_join(view + ".jpg"), 0.85)


## Rebuilds every character in `level` with the skinned body, in place.
func _swap_rigs(level: Node) -> void:
	CharacterRig.skinned = true
	for rig: CharacterRig in level.find_children("*", "", true, false).filter(func(n): return n is CharacterRig):
		var host: Node3D = rig.get_parent()
		var fresh := CharacterRig.build(host, rig.look)
		for n in host.get_children():
			if n.get("rig") == rig:
				n.rig = fresh  # NpcLook and the like keep driving it
		host.remove_child(rig)
		rig.queue_free()
	CharacterRig.skinned = false
	await _frames(2)


func _info() -> Array:
	return [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	]


func _frames(n: int) -> void:
	for i in n:
		await process_frame
