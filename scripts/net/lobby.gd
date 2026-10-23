extends Control
## The pre-game lobby, in front of the crew's garage (LobbyStage). It opens on
## "Welcome to Byte-Right IT!" from the sky down to the garage front. Then:
## host a game or join a friend's (solo: straight on), and each player walks in
## to their mark.
## Everyone picks how they look (and sees it on their own figure), how they
## stand, and says they're ready. Once everyone is, the game starts and the
## garage opens on the same shot.
##
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

var stage: LobbyStage
var picker: LookPicker
var _welcome: Label
var _side: Control
var _address: LineEdit
var _status: Label
var _connect_box: Control
var _session_box: Control
var _ready_btn: Button
var _pose_btn: Button
var _waiting: Label
var _all_ready_for := 0.0


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
	# Folded away until wanted, so the crew on the driveway stays in view.
	var customize := _button("Customize")
	customize.name = "OpenCustomize"
	customize.toggle_mode = true
	right.add_child(customize)
	picker = LookPicker.new()
	picker.with_preview = false
	picker.visible = false
	right.add_child(picker)
	customize.toggled.connect(func(on): picker.visible = on)
	picker.previewed.connect(func(look): stage.preview_own(_net(), look))

	# Solo: just you, Change pose and Ready.
	var solo: bool = _net().solo_lobby
	var title := ThemeUtil.label("CO-OP", 56, ThemeUtil.GREEN)
	title.add_theme_font_override("font", ThemeUtil.mono())
	title.visible = not solo
	left.add_child(title)
	var sub := ThemeUtil.label("Up to %d players. One hosts, the others join by address." % _net().MAX_PLAYERS, 18, ThemeUtil.DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.visible = not solo
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

	_status = ThemeUtil.label("", 18, ThemeUtil.AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_status)
	var back := _button("Back")
	back.name = "Back"
	back.pressed.connect(func():
		_net().leave(false)
		get_node("/root/Game").goto("menu"))
	left.add_child(back)

	_side.visible = false
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


func _on_joined() -> void:
	_status.text = "Joined."


func _on_session_ended(reason: String) -> void:
	_status.text = reason
	_refresh()


func _on_host() -> void:
	if _net().host() != OK:
		_status.text = "Couldn't host on port %d. Is another copy of the game already hosting?" % _net().DEFAULT_PORT
		return
	var ips: Array = _net().local_addresses()
	_status.text = "Hosting. Friends join with %s (port %d). Over the internet, forward that port or use a VPN like Tailscale." % [
		" or ".join(ips) if not ips.is_empty() else "this computer's IP", _net().DEFAULT_PORT]
	_refresh()


func _on_join() -> void:
	if _address.text.strip_edges() == "":
		_status.text = "Type the host's address first."
		return
	if _net().join(_address.text) != OK:
		_status.text = "That address doesn't look right."
		return
	_status.text = "Connecting to %s..." % _address.text.strip_edges()
	_refresh()


## The session changed: who's here, how they look and stand, who's ready.
func _refresh() -> void:
	var net := _net()
	var in_session: bool = not net.roster.is_empty()
	_connect_box.visible = not in_session
	_session_box.visible = in_session
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
	if not ((net.is_online() or net.solo_lobby) and net.is_host() and net.all_ready()):
		_all_ready_for = 0.0
		return
	_all_ready_for += delta
	if _all_ready_for >= START_DELAY:
		_all_ready_for = -INF  # once
		if net.solo_lobby:
			net.start_solo_game()
		else:
			net.start_game()


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
