extends Control
## The pre-game lobby, in front of the crew's garage (LobbyStage). It opens on
## "Welcome to Byte-Right IT!" from the sky down to the garage front. Then:
## host a game or join a friend's (solo: straight on), and each player walks in
## to their mark.
## Everyone picks how they look (and sees it on their own figure), how they
## stand, and says they're ready. Once everyone is, the game starts and the
## garage opens on the same shot.
##
## Start on the title screen comes here, single-player. A nav bar along the
## bottom switches between Single-player and Co-op (the same lobby, for one or for
## a crew), opens Levels (start straight on a floor) and Customize, or goes Back.
## Left: the session (host or join, then pose and ready). Right: Customize opens
## the LookPicker, without its own figure, since your figure on the driveway is
## the preview.

## How long everyone must stay ready before the game starts.
const START_DELAY := 2.0
## Augustine's opening line.
const WELCOME := "Welcome to Byte-Right IT!"
## Lobby text: drafts awaiting Augustine's OK (plan/pre-game-lobby.md).
const READY := "Ready"
const CHANGE_POSE := "Change pose"
const WAITING := "Waiting for everyone to get ready (%d/%d)"
## The nav bar: drafts awaiting Augustine's OK.
const NAV_SOLO := "Single-player"
const NAV_COOP := "Co-op"
const NAV_LEVELS := "Levels"
const NAV_CUSTOMIZE := "Customize"
const NAV_BACK := "Back"
const FLOOR_PICKED := "Starting on %s once everyone's ready."

var stage: LobbyStage
var picker: LookPicker
var _welcome: Label
var _side: Control
var _nav: Control
var _solo_btn: Button
var _coop_btn: Button
var _levels_btn: Button
var _customize_btn: Button
var _coop_title: Control
var _coop_sub: Control
var _right: Control
## The Co-op tab is showing (host or join), whether or not you're in a session yet.
var _coop_view := false
## Host: where the game starts (a Game.LEVELS key), picked from Levels.
var start_level := "world"
var _address: LineEdit
var _status: Label
var _connect_box: Control
var _session_box: Control
var _ready_btn: Button
var _pose_btn: Button
var _waiting: Label
var _floor_note: Label
var _all_ready_for := 0.0
## Joining from your own garage (solo lobby): if it doesn't work out, or the
## host leaves, you walk back into it.
var _left_garage := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = LobbyStage.new()
	add_child(stage)
	stage.intro_finished.connect(_on_intro_finished)

	_welcome = ThemeUtil.label(WELCOME, 64, ThemeUtil.AMBER)
	_welcome.name = "Welcome"
	_welcome.add_theme_font_override("font", ThemeUtil.mono())
	_welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_welcome.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_welcome.offset_top = 80
	_welcome.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_welcome)

	_side = HBoxContainer.new()
	_side.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_side.add_theme_constant_override("separation", 0)
	add_child(_side)
	var left := _panel(_side, 460)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side.add_child(gap)
	var right := _panel(_side, 600)
	_right = right.get_parent()
	# Folded away until wanted (Customize on the nav bar), so the crew on the
	# driveway stays in view.
	picker = LookPicker.new()
	picker.with_preview = false
	right.add_child(picker)
	_right.visible = false
	picker.previewed.connect(func(look): stage.preview_own(_net(), look))

	# Solo: just you, Change pose and Ready.
	_coop_title = ThemeUtil.label("CO-OP", 56, ThemeUtil.GREEN)
	_coop_title.add_theme_font_override("font", ThemeUtil.mono())
	left.add_child(_coop_title)
	var sub := ThemeUtil.label("Up to %d players. One hosts, the others join by address." % _net().MAX_PLAYERS, 18, ThemeUtil.DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coop_sub = sub
	left.add_child(sub)

	_connect_box = VBoxContainer.new()
	_connect_box.add_theme_constant_override("separation", 10)
	left.add_child(_connect_box)
	var host_btn := _button("Host a game")
	host_btn.name = "Host"
	host_btn.pressed.connect(_on_host)
	_connect_box.add_child(host_btn)
	_address = _field(_connect_box, "Host address", "127.0.0.1")
	var join_btn := _button("Join")
	join_btn.name = "Join"
	join_btn.pressed.connect(_on_join)
	_connect_box.add_child(join_btn)

	_session_box = VBoxContainer.new()
	_session_box.add_theme_constant_override("separation", 10)
	left.add_child(_session_box)
	_pose_btn = _button(CHANGE_POSE)
	_pose_btn.name = "ChangePose"
	_pose_btn.pressed.connect(func(): _net().next_pose())
	_session_box.add_child(_pose_btn)
	_ready_btn = _button(READY)
	_ready_btn.name = "Ready"
	_ready_btn.toggle_mode = true
	_ready_btn.toggled.connect(func(on): _net().set_ready(on))
	_session_box.add_child(_ready_btn)
	_waiting = ThemeUtil.label("", 20, ThemeUtil.AMBER)
	_waiting.name = "Waiting"
	_session_box.add_child(_waiting)
	_floor_note = ThemeUtil.label("", 20, ThemeUtil.GREEN)
	_floor_note.name = "FloorPicked"
	_floor_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_session_box.add_child(_floor_note)

	_status = ThemeUtil.label("", 18, ThemeUtil.AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_status)
	_build_nav()
	_side.visible = false
	_nav.visible = false
	_net().roster_changed.connect(_refresh)
	_net().joined.connect(_on_joined)
	_net().session_ended.connect(_on_session_ended)
	if _net().last_message != "":
		_status.text = _net().last_message
		_net().last_message = ""
	add_child(ThemeUtil.version_tag())  # last, so it's drawn over the panels
	_refresh()


func _exit_tree() -> void:
	_net().roster_changed.disconnect(_refresh)
	_net().joined.disconnect(_on_joined)
	_net().session_ended.disconnect(_on_session_ended)


## A click or a key skips the opening.
func _input(event: InputEvent) -> void:
	if stage.intro_done:
		return
	if (event is InputEventMouseButton or event is InputEventKey) and event.pressed:
		stage.finish_intro()
		get_viewport().set_input_as_handled()


func _on_intro_finished() -> void:
	var fade := create_tween()
	fade.tween_property(_welcome, "modulate:a", 0.0, 0.6)
	_side.visible = true
	_nav.visible = true


## The bar along the bottom: Back, then Single-player | Co-op, Levels, Customize.
func _build_nav() -> void:
	var bar := PanelContainer.new()
	bar.name = "Nav"
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.01, 0.015, 0.02, 0.82)
	bg.set_content_margin_all(12)
	bar.add_theme_stylebox_override("panel", bg)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bar)
	_nav = bar
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	var back := _nav_button(row, NAV_BACK, "Back")
	back.pressed.connect(func():
		_net().leave(false)
		get_node("/root/Game").goto("menu"))
	row.add_child(VSeparator.new())
	var modes := ButtonGroup.new()
	_solo_btn = _nav_button(row, NAV_SOLO, "NavSolo")
	_solo_btn.toggle_mode = true
	_solo_btn.button_group = modes
	_solo_btn.pressed.connect(_to_solo)
	_coop_btn = _nav_button(row, NAV_COOP, "NavCoop")
	_coop_btn.toggle_mode = true
	_coop_btn.button_group = modes
	_coop_btn.pressed.connect(_to_coop)
	_levels_btn = _nav_button(row, NAV_LEVELS, "NavLevels")
	_levels_btn.pressed.connect(open_levels)
	_customize_btn = _nav_button(row, NAV_CUSTOMIZE, "NavCustomize")
	_customize_btn.toggle_mode = true
	_customize_btn.toggled.connect(func(on): _right.visible = on)


func _nav_button(row: Control, text: String, node_name: String) -> Button:
	var b := _button(text)
	b.name = node_name
	b.custom_minimum_size = Vector2(170, 50)
	row.add_child(b)
	return b


## Single-player: leave any co-op session and stand in the garage on your own.
func _to_solo() -> void:
	_coop_view = false
	start_level = "world"
	_floor_note.text = ""
	if not _net().solo_lobby:
		_left_garage = false
		_net().begin_solo_lobby()
	_status.text = ""
	_refresh()


## Co-op: the same garage, to host a crew or join one. You stay on your mark
## until you join someone else's.
func _to_coop() -> void:
	_coop_view = true
	if _net().solo_lobby:
		_net().set_ready(false)  # single-player's Ready doesn't start anything from here
	_status.text = ""
	_refresh()


## Levels opens the title screen's Levels screen (Playtest's LevelSelect, coming
## to this branch from main), picking with `pick_level`. Until it's here, nothing.
const LEVEL_SELECT := "res://scripts/ui/level_select.gd"


func open_levels() -> Node:
	if not ResourceLoader.exists(LEVEL_SELECT):
		return null
	return load(LEVEL_SELECT).open(self, pick_level)


## A floor (or the gym) was picked. Single-player starts straight on it; a host
## starts everyone on it once they're ready.
func pick_level(key: String) -> void:
	var net := _net()
	if net.is_online() and net.is_host():
		start_level = key
		_floor_note.text = FLOOR_PICKED % _level_name(key)
		return
	net.leave(false)
	var game := get_node("/root/Game")
	game.new_run()
	game.goto(key)


## What the Levels screen calls floor `key`.
func _level_name(key: String) -> String:
	if ResourceLoader.exists(LEVEL_SELECT):
		for f in load(LEVEL_SELECT).FLOORS:
			if f.key == key:
				return f.name
	return key


func _on_joined() -> void:
	_status.text = "Joined."


func _on_session_ended(reason: String) -> void:
	_status.text = reason
	if _left_garage:
		_left_garage = false
		_net().begin_solo_lobby()  # roster_changed: you walk back in
	_refresh()


func _on_host() -> void:
	if _net().host() != OK:
		_status.text = "Couldn't host on port %d. Is another copy of the game already hosting?" % _net().DEFAULT_PORT
		_net().begin_solo_lobby()  # back on your own mark
		_refresh()
		return
	var ips: Array = _net().local_addresses()
	_status.text = "Hosting. Friends join with %s (port %d). Over the internet, forward that port or use a VPN like Tailscale." % [
		" or ".join(ips) if not ips.is_empty() else "this computer's IP", _net().DEFAULT_PORT]
	_refresh()


func _on_join() -> void:
	if _address.text.strip_edges() == "":
		_status.text = "Type the host's address first."
		return
	var from_garage: bool = _net().solo_lobby
	if _net().join(_address.text) != OK:
		_status.text = "That address doesn't look right."
		return
	if from_garage:
		# Out of your own garage; you walk on into theirs once you're in.
		_left_garage = true
		stage.hand_off()
	_status.text = "Connecting to %s..." % _address.text.strip_edges()
	_refresh()


## The session changed: who's here, how they look and stand, who's ready.
func _refresh() -> void:
	var net := _net()
	var in_session: bool = not net.roster.is_empty()
	var online: bool = in_session and not net.solo_lobby
	var coop: bool = _coop_view or not net.solo_lobby
	# Co-op: Host or Join until you're in a session; single-player: pose and Ready.
	_connect_box.visible = coop and (net.solo_lobby or not in_session)
	_session_box.visible = online or (in_session and not coop)
	_coop_title.visible = coop
	_coop_sub.visible = coop
	_solo_btn.set_pressed_no_signal(not coop)
	_coop_btn.set_pressed_no_signal(coop)
	# In co-op only the host picks the floor.
	_levels_btn.disabled = coop and not (online and net.is_host())
	stage.sync_crew(net)
	var ready_count: int = net.roster.keys().filter(func(id): return net.lobby_of(id).ready).size()
	_waiting.text = WAITING % [ready_count, net.roster.size()] if in_session and not net.solo_lobby else ""
	_ready_btn.set_pressed_no_signal(net.lobby_of(net.my_id()).ready)


## This player's whole loadout now (LookPicker.my_look).
func my_look() -> Dictionary:
	return picker.my_look()


## The host starts the game once everyone has been ready for a moment (solo:
## once you have).
func _process(delta: float) -> void:
	var net := _net()
	var solo_ready: bool = net.solo_lobby and not _coop_view
	if not ((net.is_online() or solo_ready) and net.is_host() and net.all_ready()):
		_all_ready_for = 0.0
		return
	_all_ready_for += delta
	if _all_ready_for >= START_DELAY:
		_all_ready_for = -INF  # once
		if net.solo_lobby:
			net.start_solo_game()
		else:
			net.start_game(start_level)


func _panel(parent: Control, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.01, 0.015, 0.02, 0.82)
	bg.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", bg)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box


func _field(parent: Control, label_text: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := ThemeUtil.label(label_text, 20)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.custom_minimum_size = Vector2(0, 44)
	e.add_theme_font_size_override("font_size", 20)
	row.add_child(e)
	return e


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 22)
	return b


func _net() -> Node:
	return get_node("/root/Net")
