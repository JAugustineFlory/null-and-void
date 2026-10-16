class_name LevelBase
extends Node3D
## Shared setup for every level: database, HUD, terminal screen, player,
## navigation, doors and lights wired to the database.
##
## A level runs in one of two ways. Inside the World (the one continuous map) it is a
## wing: it builds its geometry and adds its seed data when loaded, borrows the World's
## player, HUD and database, and waits for activate() before its story starts. On its
## own (tests, debugging) it creates all of that itself and starts straight away.

var db: FacilityDB
var hud: HUD
var player: Player
var terminal_ui: TerminalUI
var notebook: Notebook
## Static level geometry lives under this node so navigation can bake from it.
var geo: NavigationRegion3D
var doors := {}
var lights := {}  # light id -> Array of Light3D
var spawn := Transform3D.IDENTITY
## The level's WorldEnvironment settings. Levels can brighten or darken it in build().
var environment: Environment
## The World this level is a wing of, or null when it runs on its own.
var world: LevelBase
## This wing's key in Game.LEVELS. Set by the World before the wing is added.
var wing_id := ""
## True once players have reached this level and its story has started.
var active := false
## The door players leave through. The World seals it once they are in the next wing.
var exit_door: Door
## Co-op: keeps this level the same on every machine (see scripts/net/). A wing
## has its own LevelSync for its events; the World's one starts the session.
var sync: LevelSync
var players: NetPlayers
var voice: VoiceChat
var _pause: Control


func _ready() -> void:
	if get_parent() is LevelBase:
		_ready_as_wing(get_parent())
		return
	db = FacilityDB.new()
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
	sync = LevelSync.create(self)

	build()
	_bake_navigation()
	db.sync_world()
	LevelSync.name_nodes(self)

	player = Player.new()
	player.name = "Player"
	player.hud = hud
	# Place it before it enters the world: a body that appears at the origin for
	# even one physics step can set off triggers there.
	player.transform = player_spawn(NetPlayers.index_of(multiplayer.get_unique_id(), multiplayer))
	add_child(player)
	players = NetPlayers.create(self, player)
	player.died.connect(_on_player_died)
	voice = VoiceChat.create(self)
	_build_pause_menu()
	net_setup()
	sync.began.connect(players.go_live)
	# Each player's own notebook: local, never synced, added after node names are fixed.
	notebook = Notebook.new()
	notebook.name = "Notebook"
	notebook.player = player
	notebook.terminal_ui = terminal_ui
	add_child(notebook)
	active = true
	sync.begin_when_ready(start)


func _ready_as_wing(host: LevelBase) -> void:
	world = host
	db = host.db
	hud = host.hud
	terminal_ui = host.terminal_ui
	notebook = host.notebook
	player = host.player
	players = host.players
	voice = host.voice
	environment = host.environment
	sync = LevelSync.create(self)
	geo = NavigationRegion3D.new()
	geo.name = "Geometry"
	add_child(geo)
	db.door_changed.connect(_on_door_changed)
	db.light_changed.connect(_on_light_changed)
	build()
	_bake_navigation()
	db.sync_world()
	LevelSync.name_nodes(self)
	net_setup()


## The World calls this when players reach the wing.
func activate() -> void:
	active = true
	apply_environment(environment)
	start()


## Override: build geometry, doors, terminals and load seed data.
func build() -> void:
	pass


## Override: run the level's story. Usually async.
func start() -> void:
	pass


## Override: share NPCs and other moving things with co-op clients,
## e.g. `sync.replicate(npc, [...])`. Runs after node names are fixed.
func net_setup() -> void:
	pass


## A sync event for any node in the level: call `method(args)` on the node at
## `path` on every machine, e.g. an elevator's doors closing.
func run_on(path: NodePath, method: StringName, args: Array = []) -> void:
	var node := get_node_or_null(path)
	if node:
		node.callv(method, args)


## Override: what happens when the player dies.
func on_player_died() -> void:
	player.respawn(spawn_point())


## Override: lighting mood while players are in this level. Wings share one
## environment, so set every value a level might change.
func apply_environment(env: Environment) -> void:
	env.ambient_light_energy = 0.08
	env.fog_density = 0.035


## Add this level's seed data: to the shared building database in the World, or
## to a fresh database when running on its own.
func load_level_seed(sql: String) -> void:
	if world:
		db.add_wing(wing_id, sql)
	else:
		db.load_seed(sql)


## Where players (re)spawn, in world space. `spawn` is relative to the level.
func spawn_point() -> Transform3D:
	return global_transform * spawn


## Where player number `index` (0 = host) starts, so up to six people don't
## appear inside each other. Levels with set places (the van) override this.
func player_spawn(index: int) -> Transform3D:
	return spawn_point().translated(NetPlayers.spawn_offset(index))


## Ask the World to load the next wing now, behind its closed door.
func prepare_next() -> void:
	if world:
		world.load_next(self)


## The level is done. In the World this is a checkpoint and play moves into the
## next wing; on its own it changes scene to `next_key`.
func finish_level(next_key: String) -> void:
	if world:
		world.wing_finished(self)
	else:
		Game.goto(next_key)


func add_door(id: String, pos: Vector3, size: Vector3) -> Door:
	var d := Door.create(self, id, pos, size)
	doors[id] = d
	return d


func add_light(id: String, pos: Vector3, light_range: float = 8.0, energy: float = 1.4, color: Color = Color(0.92, 0.95, 1.0)) -> OmniLight3D:
	var l := Greybox.ceiling_light(geo, pos, light_range, energy, color)
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
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.07)
	env.glow_enabled = true
	env.glow_intensity = 0.6
	environment = env
	apply_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _bake_navigation() -> void:
	if geo.get_child_count() == 0:
		return
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
		get_node("/root/Net").leave()
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
		if event.is_action_pressed("pause") and not level.terminal_ui.visible and not (level.notebook and level.notebook.is_open()):
			level._toggle_pause()
			get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	var p := not _pause.visible
	# Co-op can't stop time for everyone: the menu opens but the game runs on.
	if not sync.is_online():
		get_tree().paused = p
	player.input_locked = p
	_pause.visible = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED
