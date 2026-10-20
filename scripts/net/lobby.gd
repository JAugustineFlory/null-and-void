extends Control
## Co-op lobby: host a game or join a friend's, pick your look, see who's in,
## start together.

## How fast the look preview turns, in degrees a second.
const PREVIEW_TURN := 30.0

var _name: LineEdit
var _address: LineEdit
var _status: Label
var _list: VBoxContainer
var _host_btn: Button
var _join_btn: Button
var _start_btn: Button
var _connect_box: Control
## One button per crew polo color, in CharacterLooks.crew order.
var _look_buttons: Array[Button] = []
## One per CharacterLooks.SKIN_TONES.
var _skin_buttons: Array[Button] = []
## One per crew member, by PlayableCrew slug.
var _crew_buttons := {}
## Who you're playing, under the preview.
var _crew_caption: Label
var _preview_pivot: Node3D
var _preview_rig: CharacterRig
var _preview_look := {}


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
	columns.add_theme_constant_override("separation", 32)
	center.add_child(columns)
	columns.add_child(_build_preview())
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 14)
	columns.add_child(box)

	var title := ThemeUtil.label("CO-OP", 64, ThemeUtil.GREEN)
	title.add_theme_font_override("font", ThemeUtil.mono())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := ThemeUtil.label("Up to %d players. One hosts, the others join by address." % _net().MAX_PLAYERS, 18, ThemeUtil.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	_name = _field(box, "Your name", _net().player_name)
	_name.max_length = 16
	_name.text_changed.connect(func(t): _net().player_name = t.strip_edges() if t.strip_edges() != "" else "Player")
	_build_look_row(box)

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
		swatch.color = _look_color(_net().look_of(id, ids.find(id)).color)
		row.add_child(swatch)
		row.add_child(ThemeUtil.label("%s%s%s" % [roster[id], tag, you], 22))
		_list.add_child(row)
	if ids.is_empty():
		_list.add_child(ThemeUtil.label("  Not connected.", 20, ThemeUtil.DIM))
	var online: bool = _net().is_online()
	_connect_box.visible = not online
	_name.editable = not online
	_start_btn.visible = online and _net().is_host()
	_start_btn.text = "Start (%d player%s)" % [ids.size(), "" if ids.size() == 1 else "s"]
	_refresh_looks()


## This player's look now ({color, skin, crew, body}): the host's say once
## connected, else their pick. A skin of -1 is shown as the polo color's own.
func my_look() -> Dictionary:
	var look: Dictionary = _net().look_of(multiplayer.get_unique_id(), maxi(int(_net().wanted_look.color), 0)).duplicate()
	if look.skin < 0:
		look.skin = CharacterLooks.SKIN_TONES.find(CharacterLooks.crew(look.color).skin)
	return look


## Who you play (one row per body type, 1 and 2), then the polo color (one
## each) and skin tone.
func _build_look_row(parent: Control) -> void:
	for body in [1, 2]:
		var row: Array[Button] = []
		for slug in PlayableCrew.on_body(body):
			var b := _swatch("Crew_" + slug, {"crew": slug})
			b.text = PlayableCrew.info(slug).name.get_slice(" ", 0)
			b.custom_minimum_size = Vector2(88, 40)
			b.add_theme_font_size_override("font_size", 18)
			_crew_buttons[slug] = b
			row.append(b)
		_look_row(parent, "Body %d" % body, row)
	for i in _net().MAX_PLAYERS:
		_look_buttons.append(_swatch("Look%d" % (i + 1), {"color": i}))
	for i in CharacterLooks.SKIN_TONES.size():
		_skin_buttons.append(_swatch("Skin%d" % (i + 1), {"skin": i}))
	_look_row(parent, "Your color", _look_buttons)
	_look_row(parent, "Skin", _skin_buttons)


func _look_row(parent: Control, label_text: String, buttons: Array[Button]) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := ThemeUtil.label(label_text, 20)
	l.custom_minimum_size = Vector2(170, 0)
	row.add_child(l)
	for b in buttons:
		row.add_child(b)


func _swatch(button_name: String, change: Dictionary) -> Button:
	var b := Button.new()
	b.name = button_name
	b.custom_minimum_size = Vector2(52, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_net().choose_look.bind(change))
	return b


func _refresh_looks() -> void:
	var mine := my_look()
	for i in _look_buttons.size():
		_paint(_look_buttons[i], _look_color(i), i == mine.color)
	for i in _skin_buttons.size():
		_paint(_skin_buttons[i], CharacterLooks.SKIN_TONES[i], i == mine.skin)
	for slug in _crew_buttons:
		var b: Button = _crew_buttons[slug]
		_paint(b, Color(0.15, 0.17, 0.18), slug == mine.crew)
	var who := PlayableCrew.info(mine.crew)
	_crew_caption.text = "%s, %s\n%s" % [who.name, who.age, who.about] if not who.is_empty() else ""
	_show_look(mine)


func _paint(b: Button, color: Color, picked: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.set_border_width_all(4 if picked else 0)
	style.border_color = Color(0.95, 0.95, 0.9)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, style)


func _look_color(index: int) -> Color:
	return ArtPalette.CREW_COLORS[posmod(index, ArtPalette.CREW_COLORS.size())]


## A turning figure of the picked look, left of the form.
func _build_preview() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	var frame := SubViewportContainer.new()
	frame.name = "LookPreview"
	frame.stretch = true
	frame.custom_minimum_size = Vector2(300, 480)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	frame.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.55, 0.6)
	env.environment.ambient_light_energy = 0.6
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.8)
	cam.rotation_degrees.x = -6
	cam.fov = 40
	vp.add_child(cam)
	_preview_pivot = Node3D.new()
	vp.add_child(_preview_pivot)
	var floor_disc := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.02
	floor_disc.mesh = disc
	floor_disc.position.y = -0.01
	floor_disc.material_override = Greybox.mat(Color(0.12, 0.13, 0.14))
	vp.add_child(floor_disc)
	column.add_child(frame)
	_crew_caption = ThemeUtil.label("", 20)
	_crew_caption.name = "CrewCaption"
	_crew_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crew_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crew_caption.custom_minimum_size = Vector2(300, 0)
	column.add_child(_crew_caption)
	return column


func _show_look(look: Dictionary) -> void:
	if look == _preview_look:
		return
	_preview_look = look
	if _preview_rig:
		_preview_rig.queue_free()
	_preview_rig = CharacterRig.build(_preview_pivot, NetPlayers.crew_look(look))
	_preview_rig.play("idle")


func _process(delta: float) -> void:
	if _preview_pivot:
		_preview_pivot.rotation_degrees.y = fmod(_preview_pivot.rotation_degrees.y + PREVIEW_TURN * delta, 360.0)


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
