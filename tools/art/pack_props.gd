extends SceneTree
## Packs the props tools/art/build_props.py wrote (.glb) into the meshes the game
## loads (assets/art/props/<id>.res): one compressed ArrayMesh each, about a
## quarter of the glb's size (positions and normals in 16 bits, colours in 8).
##   godot --headless -s tools/art/pack_props.gd -- GLB_DIR [OUT_DIR]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0]
	var out: String = args[1] if args.size() > 1 else "res://assets/art/props"
	DirAccess.make_dir_recursive_absolute(out)
	for f in DirAccess.get_files_at(src):
		if not f.ends_with(".glb"):
			continue
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(src.path_join(f), state) != OK:
			push_error("can't read " + f)
			continue
		var scene := doc.generate_scene(state)
		var mi := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var arrays := mi.mesh.surface_get_arrays(0)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		var path := out.path_join(f.get_basename() + ".res")
		ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		print("%-16s %6.1f KB" % [f.get_basename(), FileAccess.get_file_as_bytes(path).size() / 1024.0])
		scene.free()
	quit()
