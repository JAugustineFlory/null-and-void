class_name LevelBase
extends Node3D
## Shared setup for every level: database, HUD, terminal screen, player,
## navigation, doors and lights wired to the database.

var db := FacilityDB.new()
var hud: HUD
var player: Player
var terminal_ui: TerminalUI
## Static level geometry lives under this node so navigation can bake from it.
var geo: NavigationRegion3D
var doors := {}
var lights := {}  # light id -> Array of Light3D
var spawn := Transform3D.IDENTITY
var _pause: Control


func _ready() -> void:
	_environment()
	geo = NavigationRegion3D.new()
	geo.name = "Geometry"
	add_child(geo)
	hud = HUD.new()
	add_child(hud)
	terminal_ui = TerminalUI.new()
	add_child(terminal_ui)
	db.door_changed.connect(_on_door_changed)
	db.light_changed.connect(_on_light_changed)

	build()
	_bake_navigation()
	db.sync_world()

	player = Player.new()
	player.name = "Player"
	player.hud = hud
	add_child(player)
	player.global_transform = spawn
	player.died.connect(_on_player_died)
	_build_pause_menu()
	start()


## Override: build geometry, doors, terminals and load seed data.
func build() -> void:
	pass


## Override: run the level's story. Usually async.
func start() -> void:
	pass


## Override: what happens when the player dies.
func on_player_died() -> void:
	player.respawn(spawn)


func add_door(id: String, pos: Vector3, size: Vector3) -> Door:
	var d := Door.create(self, id, pos, size)
	doors[id] = d
	return d


func add_light(id: String, pos: Vector3, light_range: float = 8.0, energy: float = 1.4) -> OmniLight3D:
	var l := Greybox.ceiling_light(geo, pos, light_range, energy)
	if not lights.has(id):
		lights[id] = []
	lights[id].append(l)
	return l


func set_all_lights_color(c: Color) -> void:
	for id in lights:
		for l in lights[id]:
			l.light_color = c


func _on_door_changed(id: String, locked: bool, fault: bool) -> void:
	if doors.has(id):
		doors[id].apply_db_state(locked, fault)


func _on_light_changed(id: String, is_on: bool) -> void:
	for l in lights.get(id, []):
		l.visible = is_on


func _on_player_died() -> void:
	player.input_locked = true
	terminal_ui.close()
	await hud.fade(true, 0.6)
	on_player_died()
	player.input_locked = false
	hud.notice("You came to. Everything hurts.", 3.0)
	await hud.fade(false, 0.8)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.45)
	env.ambient_light_energy = 0.08
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.07)
	env.fog_density = 0.035
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.25
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	geo.navigation_mesh = nm
	geo.bake_navigation_mesh(false)


func _build_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_pause = ColorRect.new()
	_pause.color = Color(0, 0, 0, 0.7)
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	layer.add_child(_pause)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := ThemeUtil.label("PAUSED", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var menu := Button.new()
	menu.text = "Quit to menu"
	menu.pressed.connect(func():
		get_tree().paused = false
		Game.goto("menu"))
	box.add_child(menu)
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var catcher := PauseCatcher.new()
	catcher.level = self
	catcher.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(catcher)


class PauseCatcher:
	extends Node
	var level: LevelBase

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("pause") and not level.terminal_ui.visible:
			level._toggle_pause()
			get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_pause.visible = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED
