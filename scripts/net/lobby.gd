extends Control
## Co-op lobby: host a game or join a friend's, pick who you play and how you
## look, see who's in, start together.
##
## Two parts: the LookPicker (a turning figure of your look and the Crew, Look,
## Gear and Achievements tabs) and the session. Picks are saved to your profile.

var picker: LookPicker
var _address: LineEdit
var _status: Label
var _list: VBoxContainer
var _host_btn: Button
var _join_btn: Button
var _start_btn: Button
var _connect_box: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.02)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	center.add_child(columns)
	picker = LookPicker.new()
	columns.add_child(picker)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 14)
	columns.add_child(box)
	var title := ThemeUtil.label("CO-OP", 64, ThemeUtil.GREEN)
	title.add_theme_font_override("font", ThemeUtil.mono())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := ThemeUtil.label("Up to %d players. One hosts, the others join by address." % _net().MAX_PLAYERS, 18, ThemeUtil.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)

	_connect_box = VBoxContainer.new()
	_connect_box.add_theme_constant_override("separation", 10)
	box.add_child(_connect_box)
	_host_btn = _button("Host a game")
	_host_btn.pressed.connect(_on_host)
	_connect_box.add_child(_host_btn)
	_address = _field(_connect_box, "Host address", "127.0.0.1")
	_join_btn = _button("Join")
	_join_btn.pressed.connect(_on_join)
	_connect_box.add_child(_join_btn)

	_status = ThemeUtil.label("", 18, ThemeUtil.AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

	box.add_child(ThemeUtil.label("Players", 24, ThemeUtil.AMBER))
	_list = VBoxContainer.new()
	box.add_child(_list)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_start_btn = _button("Start")
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.pressed.connect(func(): _net().start_game())
	row.add_child(_start_btn)
	var back := _button("Back")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func():
		_net().leave(false)
		get_node("/root/Game").goto("menu"))
	row.add_child(back)

	_net().roster_changed.connect(_refresh)
	_net().joined.connect(_on_joined)
	_net().session_ended.connect(_on_session_ended)
	if _net().last_message != "":
		_status.text = _net().last_message
		_net().last_message = ""
	_refresh()


func _exit_tree() -> void:
	_net().roster_changed.disconnect(_refresh)
	_net().joined.disconnect(_on_joined)
	_net().session_ended.disconnect(_on_session_ended)


func _on_joined() -> void:
	_status.text = "Joined. Waiting for the host to start."


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


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var roster: Dictionary = _net().roster
	var ids := roster.keys()
	ids.sort()
	for id in ids:
		var tag := "  (host)" if id == 1 else ""
		var you := "  (you)" if id == multiplayer.get_unique_id() and _net().is_online() else ""
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(18, 18)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.color = _net().look_of(id, ids.find(id)).top.color
		row.add_child(swatch)
		row.add_child(ThemeUtil.label("%s%s%s" % [roster[id], tag, you], 22))
		_list.add_child(row)
	if ids.is_empty():
		_list.add_child(ThemeUtil.label("  Not connected.", 20, ThemeUtil.DIM))
	var online: bool = _net().is_online()
	_connect_box.visible = not online
	picker.set_name_editable(not online)
	_start_btn.visible = online and _net().is_host()
	_start_btn.text = "Start (%d player%s)" % [ids.size(), "" if ids.size() == 1 else "s"]


## This player's whole loadout now (LookPicker.my_look).
func my_look() -> Dictionary:
	return picker.my_look()


func _field(parent: Control, label_text: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := ThemeUtil.label(label_text, 20)
	l.custom_minimum_size = Vector2(170, 0)
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
