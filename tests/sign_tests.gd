extends RefCounted
## Every sign, label and paper on a wall, on every floor, faces into the room it's
## in, not into the wall behind it (Augustine, v0.8-beta1 playtest: floor 10's
## clock over the control room door couldn't be seen). A Label3D reads from its +Z
## side and isn't drawn from behind, so one turned the wrong way is invisible.

var _tree: SceneTree
var _check: Callable

## How close in front of a sign a surface has to be to count as the wall it's on.
const FACE_GAP := 0.06


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	await test_signs_face_their_rooms()


func test_signs_face_their_rooms() -> void:
	print("Every sign on every floor faces into its room")
	var backwards: Array[String] = []
	var count := 0
	var i := 0
	while ResourceLoader.exists("res://scenes/level_%d.tscn" % i):
		for run_seed in [3, 11]:  # papers like the breaker tags move with the seed
			_tree.root.get_node("/root/Game").new_run(run_seed)
			var level = load("res://scenes/level_%d.tscn" % i).instantiate()
			_tree.root.add_child(level)
			for f in 8:
				await _tree.physics_frame
			var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
			for l in level.find_children("*", "Label3D", true, false):
				if not l.is_visible_in_tree() or l.double_sided or l.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
					continue
				count += 1
				var front: Vector3 = l.global_basis.z.normalized()
				var ahead := space.intersect_ray(PhysicsRayQueryParameters3D.create(l.global_position, l.global_position + front * FACE_GAP))
				var behind := space.intersect_ray(PhysicsRayQueryParameters3D.create(l.global_position, l.global_position - front * FACE_GAP))
				if not ahead.is_empty() and behind.is_empty():
					var what := "level %d \"%s\"" % [i, l.text.replace("\n", " ").left(30)]
					if what not in backwards:
						backwards.append(what)
			level.queue_free()
			for f in 3:
				await _tree.process_frame
		i += 1
	_check.call(count > 200, "found the signs on every floor (%d)" % count)
	_check.call(backwards.is_empty(), "no sign or paper faces into the wall it's on%s" % ("" if backwards.is_empty() else " (backwards: %s)" % ", ".join(backwards)))
