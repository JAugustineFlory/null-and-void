class_name Terminal
extends Interactable
## A CRT terminal in the world. It shares the level's database.

signal queried(sql: String, result: Dictionary, ui: TerminalUI)
signal requested(line: String, response: Dictionary, ui: TerminalUI)

var terminal_name := "TERMINAL"
var db: FacilityDB
## Optional HTTP API this terminal can reach (`GET /cameras`). Null means SQL only.
var api: FacilityAPI
var ui: TerminalUI
## Lines shown when the terminal boots. Levels can replace these.
var boot_lines: Array = []
## Puzzles this terminal gives hints for, in order.
var puzzles: Array = []
var locked := false
var locked_message := "ACCESS DENIED."
var _fresh_boot := false
var _screen: MeshInstance3D


static func spawn(parent: Node, pos: Vector3, facing_deg: float, name_text: String, facility_db: FacilityDB, terminal_ui: TerminalUI) -> Terminal:
	var t := Terminal.new()
	t.position = pos
	t.rotation_degrees.y = facing_deg
	t.terminal_name = name_text
	t.prompt = "Use terminal"
	t.db = facility_db
	t.ui = terminal_ui
	# Beige CRT monitor with a glowing green screen, facing +Z.
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.42, 0.45)
	body.mesh = bm
	body.material_override = Greybox.mat(Color(0.78, 0.74, 0.62), 0.0, 0.6)
	body.position.y = 0.21
	t.add_child(body)
	t._screen = MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.4, 0.3, 0.02)
	t._screen.mesh = sm
	t._screen.material_override = Greybox.mat(Color(0.2, 0.9, 0.35), 1.6)
	t._screen.position = Vector3(0, 0.23, 0.23)
	t.add_child(t._screen)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.3, 1.0, 0.45)
	glow.omni_range = 1.8
	glow.light_energy = 0.6
	glow.position = Vector3(0, 0.25, 0.5)
	t.add_child(glow)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, 0.5, 0.6)
	shape.shape = bs
	shape.position.y = 0.25
	t.add_child(shape)
	parent.add_child(t)
	t.add_to_group("interactable")
	t.used.connect(t._on_used)
	return t


func _on_used(player: Node) -> void:
	ui.open(self, player)


func boot_text() -> Array:
	if not boot_lines.is_empty():
		return boot_lines
	return ["HALCYON DATA SYSTEMS  -  WARDEN v3.1", "Type .help for commands."]


## Replace the boot text and wipe the screen the next time it is opened.
func reboot(lines: Array) -> void:
	boot_lines = lines
	_fresh_boot = true


func consume_fresh_boot() -> bool:
	var f := _fresh_boot
	_fresh_boot = false
	return f


func is_locked() -> bool:
	return locked


func set_screen_color(c: Color) -> void:
	_screen.material_override = Greybox.mat(c, 1.6)


func on_query(sql: String, result: Dictionary, terminal_ui: TerminalUI) -> void:
	queried.emit(sql, result, terminal_ui)


func on_request(line: String, response: Dictionary, terminal_ui: TerminalUI) -> void:
	requested.emit(line, response, terminal_ui)


func next_hint() -> String:
	if locked:
		return "This terminal is locked. Find a way to authorize it."
	for p in puzzles:
		if not p.solved:
			return p.next_hint()
	return "Nothing left to solve here. Keep moving."
