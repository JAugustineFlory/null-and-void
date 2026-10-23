class_name Terminal
extends Interactable
## A CRT terminal in the world. It shares the level's database.

signal queried(sql: String, result: Dictionary, ui: TerminalUI)
signal requested(line: String, response: Dictionary, ui: TerminalUI)
## Someone sat down at this terminal. Fires on the host (in co-op a client's
## opening is reported there), so story code can react to it.
signal opened(by: Node)
## What the screen shows changed: a line, a clear, a seat or a typed character.
## The in-world screen redraws from transcript, seated and typing.
signal screen_changed

## How much of a teammate's half-typed line shows when you look at the terminal.
const TYPING_SHOWN := 60

var terminal_name := "TERMINAL"
var db: FacilityDB
## Optional HTTP API this terminal can reach (`GET /cameras`). Null means SQL only.
var api: FacilityAPI
var ui: TerminalUI
## Lines shown when the terminal boots. Levels can replace these.
var boot_lines: Array = []
## Puzzles this terminal gives hints for, in order.
var puzzles: Array = []
## Placeholders shown on this screen (like "table_name") -> what SYSOP says when a
## player types one literally.
var blanks := {}
var locked := false
var locked_message := "ACCESS DENIED."
var _fresh_boot := false
var _screen: MeshInstance3D
## Hooks for walking up to use it (Player.use_terminal): where the player stands,
## its -Z facing the terminal (only its floor position and facing are used), and
## the middle of the screen, +Z out of it, that the camera focuses on. Move them if
## a level's desk or a new screen model needs it.
var stand_point: Marker3D
var focus_point: Marker3D
## The CRT with the screen's text on its glass (TerminalScreen). The terminal
## window opens on it when the player steps up (Game.diegetic_ui).
var screen: TerminalScreen
## The player walking up to this terminal, until the camera settles on the glass.
var _stepping_up: Node
## What this machine's copy of the screen shows. In co-op everyone's queries
## appear here, so players can work one terminal together.
var transcript: Array[String] = []
## What each transcript line is ("echo", "result", "hint"...), for the notebook.
var transcript_kinds: Array[String] = []
## Peer ids of the players sitting at this terminal, in the order they sat.
var seated: Array[int] = []
## What each seated player has typed but not yet entered: peer id -> text.
var typing := {}
## The screen's color: the terminal skin of whoever sat down first (Augustine:
## "whoever got there first"), kept after they leave. TerminalMirror sets it;
## the screen redraws on screen_changed.
var skin_color: Color = TerminalScreen.PHOSPHOR


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
	t.focus_point = Marker3D.new()
	t.focus_point.name = "FocusPoint"
	t.focus_point.position = Vector3(0, 0.23, 0.24)
	t.add_child(t.focus_point)
	t.stand_point = Marker3D.new()
	t.stand_point.name = "StandPoint"
	t.stand_point.position = Vector3(0, 0, 0.8)  # clear of a 0.8 m deep desk
	t.add_child(t.stand_point)
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
	# The tube's thin whine, only heard up close.
	Sfx.loop(t, "crt_whine", t.focus_point.position)
	t.screen = TerminalScreen.attach(t)
	t.screen.set_title(name_text)
	t.screen.follow(t)
	parent.add_child(t)
	t.add_to_group("interactable")
	t.used.connect(t._on_used)
	return t


func _on_used(player: Node) -> void:
	if ui.visible:
		return
	var game := get_node_or_null("/root/Game")
	if game and game.diegetic_ui and screen and player.has_method("use_terminal"):
		# Step up to the desk; the window opens on the glass once the camera settles.
		if player.use_terminal(stand_point, screen):
			_stepping_up = player
			if not player.terminal_focused.is_connected(_on_focused):
				player.terminal_focused.connect(_on_focused)
				player.terminal_left.connect(_on_walked_off)
		return
	ui.open(self, player)


func _on_focused() -> void:
	var player := _stepping_up
	_stepping_up = null
	if player and not ui.visible:
		ui.open_on_screen(self, player, screen)


## They stepped back (or respawned) before it opened: don't open it later.
func _on_walked_off() -> void:
	_stepping_up = null


## Looking at the terminal also shows what teammates sitting at it are typing,
## big enough to read when their body is between you and the glass.
func get_prompt(player: Node) -> String:
	var p := super(player)
	var me := multiplayer.get_unique_id()
	var net := get_node_or_null("/root/Net")
	for peer in seated:
		var text: String = typing.get(peer, "").replace("\n", " ").strip_edges()
		if peer == me or text == "":
			continue
		if text.length() > TYPING_SHOWN:
			text = "..." + text.right(TYPING_SHOWN)
		var who: String = net.display_name(peer) if net else "Player %d" % peer
		p = "%s> %s_\n%s" % [who, text, p]
	return p


## Opening a terminal is local to each player; the host only hears that it happened.
func interact(player: Node) -> void:
	if enabled:
		used.emit(player)
		if not _forwarded("report_open"):
			opened.emit(player)


## Host: a client sat down at this terminal.
func report_open(player: Node) -> void:
	opened.emit(player)


## Add a line to the screen (and to the open terminal window, if it shows this terminal).
func print_line(bbcode: String, kind: String = "") -> void:
	transcript.append(bbcode)
	transcript_kinds.append(kind)
	if kind == "hint":
		_note_hint_pieces(bbcode)
	if ui:
		ui.on_terminal_line(self, bbcode, kind)
	screen_changed.emit()


## One of this terminal's puzzle hints is on the screen (every machine's copy):
## the case pieces its query shows are found for everyone looking at it.
func _note_hint_pieces(bbcode: String) -> void:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	var shown := TerminalUI._plain(bbcode)
	for p in puzzles:
		if p.case_id == "":
			continue
		for h in p.hints:
			if TerminalUI._plain(TerminalUI.sysop(h)) == shown:
				game.note_hint(p.case_id, h)
				return


func clear_screen() -> void:
	transcript.clear()
	transcript_kinds.clear()
	if ui:
		ui.on_terminal_cleared(self)
	screen_changed.emit()


## Put the boot text up if the screen is blank or was rebooted. Every machine
## does this when someone sits down, so every copy of the screen matches.
func ensure_booted() -> void:
	var fresh := consume_fresh_boot()
	if transcript.is_empty() or fresh:
		clear_screen()
		for line in boot_text():
			print_line(line)


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


## A sound from the screen: "key", "beep" or "error". Every machine that runs the
## query plays it, at this terminal.
func sound(kind: String) -> void:
	Sfx.play(self, kind, focus_point.position)


func on_query(sql: String, result: Dictionary, terminal_ui: TerminalUI) -> void:
	queried.emit(sql, result, terminal_ui)


func on_request(line: String, response: Dictionary, terminal_ui: TerminalUI) -> void:
	requested.emit(line, response, terminal_ui)


## The case page the next hint is for, or "".
func hint_case() -> String:
	if locked:
		return ""
	for p in puzzles:
		if not p.solved:
			return p.case_id
	return ""


func next_hint() -> String:
	if locked:
		return "This terminal is locked. Find a way to authorize it."
	for p in puzzles:
		if not p.solved:
			return p.next_hint()
	return "Nothing left to solve here. Keep moving."
