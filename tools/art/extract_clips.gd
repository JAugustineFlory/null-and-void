extends SceneTree
## Copies the few animation clips the characters use out of the Quaternius
## Universal Animation Library (CC0), so the repo carries a small library
## instead of the whole pack:
##   godot --headless -s tools/art/extract_clips.gd -- PACK_DIR
## PACK_DIR is the unzipped "Universal Animation Library[Standard]" folder. Writes
## assets/art/characters/locomotion.res and prints how fast each clip walks
## (from the pack's root-motion copy), for SkinnedBody.CLIP_SPEEDS.

const CLIPS := ["Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop"]
const OUT := "res://assets/art/characters/locomotion.res"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var pack: String = args[0] if args.size() > 0 else "/mnt/project-files/art/packs/quaternius/Universal Animation Library[Standard]"
	var plain := _player(pack.path_join("Unreal-Godot/UAL1_Standard.glb"))
	var moving := _player(pack.path_join("Unreal-Godot/UAL1_Standard_RM.glb"))
	var lib := AnimationLibrary.new()
	for clip in CLIPS:
		var anim: Animation = plain.get_animation(clip).duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(clip, anim)
		print("%s: %.2f s, %.2f m/s" % [clip, anim.length, _speed(moving.get_animation(clip))])
	var err := ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS)
	print("saved ", OUT, " ", error_string(err))
	quit()


func _player(path: String) -> AnimationPlayer:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_file(path, state)
	var scene := doc.generate_scene(state)
	root.add_child(scene)
	return scene.find_children("*", "AnimationPlayer", true, false)[0]


## Metres per second the root moves over one loop of a root-motion clip.
func _speed(anim: Animation) -> float:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and String(anim.track_get_path(t)).ends_with(":root"):
			var a: Vector3 = anim.position_track_interpolate(t, 0.0)
			var b: Vector3 = anim.position_track_interpolate(t, anim.length)
			return Vector2(b.x - a.x, b.z - a.z).length() / anim.length
	return 0.0
