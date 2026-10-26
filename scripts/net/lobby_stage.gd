class_name LobbyStage
extends SubViewportContainer
## The pre-game lobby's picture: the front of the crew's garage, held in one
## shot after a short opening from the sky. Each player in the session walks in
## from the edge of the shot to their mark and stands there their way
## (Net.LOBBY_POSES), wearing what they picked, so a change shows on them as it's
## made. When everyone is ready the World opens the garage on the same shot.
## Anyone who leaves walks back off the way they came. Joining a friend's game,
## your own crew walks off first, the shot cuts, and you walk on into theirs
## (hand_off).
##
## The garage front, the held shot, each player's mark and where they walk in
## from are Home base's (HomeBase.build_front, LOBBY_CAMERA, lobby_spot,
## lobby_entry), the same the World's garage opens on, so the cut doesn't show.

## The opening: from the sky down to the held shot, in seconds.
const INTRO_TIME := 4.0
## The cut between your garage and a friend's, to black and back, in seconds.
const CUT_TIME := 0.35
## Where the opening starts, from the held shot: high up and further back, looking at the sky.
const SKY_RISE := Vector3(0, 45, 30)
const SKY_TILT := PI * 25.0 / 180.0
## HomeBase, loaded by path: naming the class would pull LevelBase and Game into
## everything that names LobbyStage, the tests included.
const HOME_BASE := "res://scripts/levels/home_base.gd"

signal intro_finished
## Everyone has walked off and the shot has cut: the next crew walks on.
signal handed_off

var camera: Camera3D
## peer id -> their figure (a Node3D holding a CharacterRig and a name tag).
var figures := {}
var intro_done := false
## Walking off to join a friend: whoever turns up next waits until the cut.
var handing_off := false
## The held shot of the garage front (HomeBase.LOBBY_CAMERA), and where the opening starts.
var lobby_shot: Transform3D
var sky_shot: Transform3D
var _home: Script
var _world: Node3D
var _crew: Node3D
var _intro: Tween
## Figures walking off, still on their way out of the shot.
var _leaving: Array[Node3D] = []
## The session that arrived during a hand-off, shown once it's done.
var _pending: Node


func _ready() -> void:
	name = "Stage"
	stretch = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	add_child(vp)
	_world = Node3D.new()
	vp.add_child(_world)
	_home = load(HOME_BASE)
	lobby_shot = _home.LOBBY_CAMERA
	sky_shot = Transform3D(lobby_shot.basis * Basis(Vector3.RIGHT, SKY_TILT), lobby_shot * SKY_RISE)
	_build_scene()
	_crew = Node3D.new()
	_crew.name = "Crew"
	_world.add_child(_crew)
	camera = Camera3D.new()  # the default field of view, like the World's garage camera
	_world.add_child(camera)
	camera.make_current()
	play_intro()


## From the sky down to the garage front.
func play_intro() -> void:
	intro_done = false
	camera.transform = sky_shot
	_intro = create_tween()
	_intro.tween_method(func(t: float): camera.transform = sky_shot.interpolate_with(lobby_shot, t), 0.0, 1.0, INTRO_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_intro.finished.connect(finish_intro)


## Straight to the held shot (the opening ended, or was skipped).
func finish_intro() -> void:
	if _intro and _intro.is_valid():
		_intro.kill()
	camera.transform = lobby_shot
	if not intro_done:
		intro_done = true
		intro_finished.emit()


## Bring the figures in line with the session: newcomers walk in, leavers go,
## and everyone wears their look and stands their way. `own_look` dresses this
## player's figure instead (a color picker mid-drag).
func sync_crew(net: Node, own_look := {}) -> void:
	if handing_off:
		_pending = net
		return
	for id in figures.keys():
		if not net.roster.has(id):
			walk_off(id)
	for id in net.roster:
		var i: int = net.lobby_index(id)
		var look: Dictionary = own_look if id == net.my_id() and not own_look.is_empty() else net.look_of(id, i)
		var fig: Node3D = figures.get(id)
		if fig == null:
			fig = _add_figure(id, i)
		_dress(fig, look)
		var state: Dictionary = net.lobby_of(id)
		fig.set_meta("pose", net.LOBBY_POSES[state.pose])
		fig.set_meta("spot", i)
		fig.set_meta("ready", state.ready)
		var tag: Label3D = fig.get_node("Tag")
		tag.text = str(net.roster[id]) + ("\nReady" if state.ready else "")
		tag.modulate = Color(0.55, 1.0, 0.6) if state.ready else Color(1, 1, 1)
		_walk_to(fig, mark(i))


## Leaving to join a friend's game: everyone here walks off the way they came,
## then the shot cuts to black and back. The friend's crew (and you, as their
## newest) walk on after that, however soon they turned up. Await it, or wait
## for handed_off.
func hand_off() -> void:
	if handing_off:
		return
	handing_off = true
	for id in figures.keys():
		walk_off(id)
	while not _leaving.is_empty():
		await get_tree().process_frame
	var cut := create_tween()
	cut.tween_property(self, "modulate", Color.BLACK, CUT_TIME)
	cut.tween_property(self, "modulate", Color.WHITE, CUT_TIME)
	await cut.finished
	handing_off = false
	handed_off.emit()
	if _pending:
		var net := _pending
		_pending = null
		sync_crew(net)


## Player `id` walks back off the edge of the shot and is gone.
func walk_off(id: int) -> void:
	var fig: Node3D = figures.get(id)
	if fig == null:
		return
	figures.erase(id)
	_leaving.append(fig)
	var old: Tween = fig.get_meta("walk") if fig.has_meta("walk") else null
	if old and old.is_valid():
		old.kill()
	var to: Vector3 = _home.lobby_entry(fig.get_meta("spot", 0)) - fig.position
	var rig: CharacterRig = fig.get_node("Rig")
	rig.play("idle")
	fig.get_node("Tag").visible = false
	if to.length() > 0.01:
		fig.rotation.y = atan2(-to.x, -to.z)
	var walk := create_tween()
	walk.tween_property(fig, "position", fig.position + to, to.length() / CharacterRig.WALK_SPEED)
	walk.finished.connect(func():
		_leaving.erase(fig)
		fig.queue_free())
	fig.set_meta("walk", walk)


## Someone still walking off the shot.
func is_leaving() -> bool:
	return not _leaving.is_empty()


## This player's figure dressed as `look` while they pick (LookPicker.previewed).
func preview_own(net: Node, look: Dictionary) -> void:
	var fig: Node3D = figures.get(net.my_id())
	if fig:
		_dress(fig, look)


## Where player `i` (host first) stands on the driveway.
func mark(i: int) -> Vector3:
	return _home.lobby_spot(i).at.origin


func _add_figure(id: int, i: int) -> Node3D:
	var fig := Node3D.new()
	fig.name = "Player_%d" % id
	fig.position = _home.lobby_entry(i)
	fig.set_meta("spot", i)
	_crew.add_child(fig)
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.position.y = 2.15
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 40
	tag.pixel_size = 0.005
	tag.outline_size = 8
	fig.add_child(tag)
	figures[id] = fig
	return fig


## Rebuild the figure's body when its look changed.
func _dress(fig: Node3D, look: Dictionary) -> void:
	if fig.get_meta("look", {}) == look:
		return
	fig.set_meta("look", look)
	var old := fig.get_node_or_null("Rig")
	if old:
		fig.remove_child(old)
		old.queue_free()
	var rig := CharacterRig.build(fig, NetPlayers.loadout_look(look))
	rig.play(_pose_action(fig) if fig.get_meta("arrived", false) else "idle")


## Walk to `to_mark` (if not there already), then turn to the camera and strike the pose.
func _walk_to(fig: Node3D, to_mark: Vector3) -> void:
	if fig.get_meta("mark", Vector3.INF) == to_mark:
		_strike(fig)
		return
	fig.set_meta("mark", to_mark)
	fig.set_meta("arrived", false)
	var old: Tween = fig.get_meta("walk") if fig.has_meta("walk") else null
	if old and old.is_valid():
		old.kill()
	var rig: CharacterRig = fig.get_node("Rig")
	rig.play("idle")
	var to := to_mark - fig.position
	if to.length() > 0.01:
		fig.rotation.y = atan2(-to.x, -to.z)
	var walk := create_tween()
	walk.tween_property(fig, "position", to_mark, to.length() / CharacterRig.WALK_SPEED)
	walk.finished.connect(func():
		fig.set_meta("arrived", true)
		_strike(fig))
	fig.set_meta("walk", walk)


func _strike(fig: Node3D) -> void:
	if not fig.get_meta("arrived", false):
		return
	fig.rotation.y = atan2(-(lobby_shot.origin.x - fig.position.x), -(lobby_shot.origin.z - fig.position.z))
	var rig: CharacterRig = fig.get_node("Rig")
	rig.play(_pose_action(fig))


func _pose_action(fig: Node3D) -> String:
	return get_node("/root/Net").pose_action(fig.get_meta("pose", "wave"))


## A dusk sky over Home base's garage front, its roll-up door shut.
func _build_scene() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.16, 0.32)
	sky_mat.sky_horizon_color = Color(0.85, 0.5, 0.35)
	sky_mat.ground_horizon_color = Color(0.3, 0.25, 0.25)
	sky_mat.ground_bottom_color = Color(0.08, 0.08, 0.1)
	sky.sky_material = sky_mat
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment.ambient_light_energy = 0.8
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-20, 35, 0)
	sun.light_color = Color(1.0, 0.8, 0.65)
	sun.light_energy = 1.1
	_world.add_child(sun)
	_home.build_front(_world)
	# The street round the driveway, out to the horizon.
	var street := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	street.mesh = plane
	street.position = Vector3(0, -0.21, 0)
	street.material_override = Greybox.mat(Color(0.16, 0.16, 0.17))
	_world.add_child(street)
