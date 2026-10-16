extends Node3D
## Lookdev room: every character, prop and mood in one place, for checking the
## art without playing through a level. Open scenes/art_gallery.tscn and run it
## (F6 in the editor).
##   Mouse + WASD/QE  fly around (right mouse to look)
##   1-5              office, night_exterior, after_hours, lockdown, dark
##   F                flashlight on/off     T  raise the walkie
##   Space            cycle every character's action

const MOODS := ["office", "night_exterior", "after_hours", "lockdown", "dark"]
const SHOWCASE_ACTIONS := ["idle", "talk", "wave", "point", "radio", "flashlight", "type", "windup", "stagger", "down", "tied", "sit", "crouch"]

var env: Environment
var vhs: VHSOverlay
var camera: Camera3D
var held: HeldItems
var lights: Array = []
var rigs: Array[CharacterRig] = []
var walker: Node3D
var mood := "office"
var _action_i := 0
var _t := 0.0


func _ready() -> void:
	env = ArtMood.environment(mood)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	vhs = VHSOverlay.new()
	add_child(vhs)
	_build_room()
	_build_cast()
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 6.5)
	camera.fov = 75
	add_child(camera)
	camera.make_current()
	held = HeldItems.attach(camera, CharacterLooks.crew(0))
	held.flashlight.set_on(false)
	set_mood("office")


func set_mood(m: String) -> void:
	mood = m
	ArtMood.apply(env, m)
	ArtMood.apply_to_lights(lights, m)
	vhs.intensity = ArtMood.get_mood(m).vhs


func _build_room() -> void:
	# A 16 x 12 office, 3 m ceiling, built from the shared surfaces.
	var w := 16.0
	var d := 12.0
	var h := 3.0
	_slab(Vector3(0, -0.1, 0), Vector3(w, 0.2, d), ArtPalette.surface("carpet"))
	_slab(Vector3(0, h + 0.1, 0), Vector3(w, 0.2, d), ArtPalette.surface("ceiling_tile"))
	_slab(Vector3(0, h / 2, -d / 2), Vector3(w, h, 0.2), ArtPalette.surface("drywall"))
	_slab(Vector3(0, h / 2, d / 2), Vector3(w, h, 0.2), ArtPalette.surface("drywall"))
	_slab(Vector3(-w / 2, h / 2, 0), Vector3(0.2, h, d), ArtPalette.surface("drywall"))
	_slab(Vector3(w / 2, h / 2, 0), Vector3(0.2, h, d), ArtPalette.surface("concrete"))
	_slab(Vector3(0, 0.05, -d / 2 + 0.11), Vector3(w, 0.1, 0.02), ArtPalette.flat(ArtPalette.OFFICE_TRIM))  # skirting
	for x in [-4.8, 0.0, 4.8]:
		for z in [-3.0, 2.0]:
			lights.append(ArtProps.troffer(self, Vector3(x, h, z)))
	# Props along the back wall.
	ArtProps.desk(self, Vector3(-5.5, 0, -4.8), 180)
	ArtProps.crt_monitor(self, Vector3(-5.5, 0.76, -5.0), 180, "green")
	ArtProps.office_chair(self, Vector3(-5.5, 0, -3.9), 180)
	ArtProps.desk(self, Vector3(-3.5, 0, -4.8), 180)
	ArtProps.crt_monitor(self, Vector3(-3.5, 0.76, -5.0), 180, "blue")
	ArtProps.filing_cabinet(self, Vector3(-1.8, 0, -5.5), 180)
	ArtProps.filing_cabinet(self, Vector3(-1.3, 0, -5.5), 180)
	ArtProps.water_cooler(self, Vector3(-0.4, 0, -5.6))
	ArtProps.potted_plant(self, Vector3(0.6, 0, -5.5))
	for i in 4:
		ArtProps.server_rack(self, Vector3(3.0 + i * 0.65, 0, -5.2), 180, i != 2)
	ArtProps.exit_sign(self, Vector3(-7.88, 2.5, 0), -90)
	# Material swatches on the side wall.
	var kinds := ArtPalette.SURFACES.keys()
	for i in kinds.size():
		_slab(Vector3(7.85, 0.5 + (i % 4) * 0.6, -4.5 + (i / 4) * 1.0), Vector3(0.05, 0.5, 0.8), ArtPalette.surface(kinds[i]))


func _build_cast() -> void:
	# Front row: the six crew. Back row: the NPCs. One walker loops the room.
	for i in 6:
		var n := Node3D.new()
		n.position = Vector3(-4.5 + i * 1.3, 0, 1.0)
		n.rotation_degrees.y = 180  # face the camera
		add_child(n)
		var rig := CharacterRig.build(n, CharacterLooks.crew(i))
		rig.play(["idle", "radio", "flashlight", "talk", "wave", "type"][i])
		rigs.append(rig)
	var npcs := [CharacterLooks.rourke(), CharacterLooks.vale(), CharacterLooks.mercer(), CharacterLooks.night_guard()]
	for i in npcs.size():
		var n := Node3D.new()
		n.position = Vector3(-3.0 + i * 2.0, 0, -1.6)
		n.rotation_degrees.y = 180
		add_child(n)
		var rig := CharacterRig.build(n, npcs[i])
		rig.play(["talk", "point", "idle", "idle"][i])
		rigs.append(rig)
	walker = Node3D.new()
	add_child(walker)
	rigs.append(CharacterRig.build(walker, CharacterLooks.rourke()))


func _slab(center: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = center
	mi.material_override = mat
	add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	# The walker strolls a loop, speeding up to a run and back.
	var a := _t * 0.35
	var r := 5.0
	walker.position = Vector3(cos(a) * r, 0, 3.5 + sin(a) * 1.6)
	var ahead := Vector3(cos(a + 0.05) * r, 0, 3.5 + sin(a + 0.05) * 1.6)
	walker.look_at(ahead, Vector3.UP)
	if camera:
		_fly(delta)


func _fly(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move.z -= 1
	if Input.is_key_pressed(KEY_S): move.z += 1
	if Input.is_key_pressed(KEY_A): move.x -= 1
	if Input.is_key_pressed(KEY_D): move.x += 1
	if Input.is_key_pressed(KEY_E): move.y += 1
	if Input.is_key_pressed(KEY_Q): move.y -= 1
	camera.position += camera.global_transform.basis * move * delta * 3.0
	held.raise_walkie(Input.is_key_pressed(KEY_T))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y -= event.relative.x * 0.004
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.004, -1.4, 1.4)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			set_mood(MOODS[event.keycode - KEY_1])
		elif event.keycode == KEY_F:
			held.flashlight.toggle()
		elif event.keycode == KEY_SPACE:
			_action_i = (_action_i + 1) % SHOWCASE_ACTIONS.size()
			for rig in rigs:
				rig.play(SHOWCASE_ACTIONS[_action_i])
		elif event.keycode == KEY_ESCAPE:
			var game := get_node_or_null("/root/Game")
			if game and game.has_method("goto"):
				game.goto("menu")
