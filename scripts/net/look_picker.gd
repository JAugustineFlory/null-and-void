class_name LookPicker
extends HBoxContainer
## Who you play and how you look: a turning figure of your pick, your name, and
## the Crew, Look and Gear tabs, with what you've earned under Achievements.
## Picks go through Net.choose_look, so they're saved to your profile and, in a
## co-op session, sent to the host. The co-op lobby and the main menu's
## Customize screen both show one.

## How fast the look preview turns, in degrees a second.
const PREVIEW_TURN := 30.0

var _name: LineEdit
## One per CharacterLooks.SKIN_TONES.
var _skin_buttons: Array[Button] = []
## One per crew member, by PlayableCrew slug.
var _crew_buttons := {}
## Per slot (Cosmetics.all_slots): the item list and its color.
var _item_lists := {}
var _color_buttons := {}
## Who you're playing, under the preview.
var _crew_caption: Label
var _preview_pivot: Node3D
var _preview_rig: CharacterRig
var _preview_look := {}


func _ready() -> void:
	name = "LookPicker"
	add_theme_constant_override("separation", 28)
	add_child(_build_preview())
	var picker := VBoxContainer.new()
	picker.custom_minimum_size = Vector2(540, 0)
	picker.add_theme_constant_override("separation", 14)
	add_child(picker)
	_name = _field(picker, "Your name", _net().player_name)
	_name.max_length = 16
	_name.text_changed.connect(func(t): _net().set_player_name(t))
	_build_tabs(picker)
	_net().roster_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	_net().roster_changed.disconnect(refresh)


## Your name is fixed once you're in a session: teammates already see it.
func set_name_editable(on: bool) -> void:
	_name.editable = on


## This player's whole loadout now: the host's say once connected, else their
## picks with the rest filled in (Cosmetics.clean).
func my_look() -> Dictionary:
	var me := multiplayer.get_unique_id()
	return _net().look_of(me, maxi(_net().roster.keys().find(me), 0))


## Crew: who you play (voice and body type). Look: skin and what you wear.
## Gear: your tools' skins.
func _build_tabs(parent: Control) -> void:
	var tabs := TabContainer.new()
	tabs.name = "Customize"
	tabs.add_theme_font_size_override("font_size", 20)
	parent.add_child(tabs)
	var crew := _tab(tabs, "Crew")
	for body in [1, 2]:
		crew.add_child(ThemeUtil.label("Body %d" % body, 20))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		crew.add_child(row)
		for slug in PlayableCrew.on_body(body):
			var b := _swatch("Crew_" + slug, {"crew": slug})
			b.text = PlayableCrew.info(slug).name.get_slice(" ", 0)
			b.custom_minimum_size = Vector2(76, 40)
			b.add_theme_font_size_override("font_size", 17)
			_crew_buttons[slug] = b
			row.add_child(b)
	var look := _tab(tabs, "Look")
	var skins := _row(look, "Skin")
	for i in CharacterLooks.SKIN_TONES.size():
		var b := _swatch("Skin%d" % (i + 1), {"skin": i})
		b.custom_minimum_size = Vector2(40, 40)
		_skin_buttons.append(b)
		skins.add_child(b)
	for slot in Cosmetics.WORN_SLOTS:
		_slot_row(look, slot)
	var gear := _tab(tabs, "Gear")
	for slot in Cosmetics.TOOL_SLOTS:
		_slot_row(gear, slot)
	_achievements_tab(tabs)


## What you've earned, and how to earn the rest. Secrets show once found.
func _achievements_tab(tabs: TabContainer) -> void:
	var page := _tab(tabs, "Achievements")
	for a in Achievements.shown_to(_net().profile):
		var row := VBoxContainer.new()
		row.name = "Achievement_" + a.id.get_slice(":", 1)
		row.add_theme_constant_override("separation", 0)
		var title := ThemeUtil.label(a.name if a.earned else "%s (locked)" % a.name, 20, ThemeUtil.AMBER if a.earned else ThemeUtil.DIM)
		title.name = "Name"
		row.add_child(title)
		if not a.earned and a.hint != "":
			var how := ThemeUtil.label(a.hint, 16, ThemeUtil.DIM)
			how.name = "Hint"
			row.add_child(how)
		page.add_child(row)


func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title
	page.add_theme_constant_override("separation", 8)
	var pad := MarginContainer.new()
	pad.name = title
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_child(page)
	tabs.add_child(pad)
	return page


func _row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := ThemeUtil.label(label_text, 20)
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	return row


## One slot: the items you can pick and a color for it. Items you don't own
## yet show as locked with how to unlock them; secret ones don't show at all.
func _slot_row(parent: Control, slot: String) -> void:
	var row := _row(parent, Cosmetics.SLOT_NAMES[slot])
	var list := OptionButton.new()
	list.name = "Item_" + slot
	list.custom_minimum_size = Vector2(260, 40)
	list.add_theme_font_size_override("font_size", 18)
	list.focus_mode = Control.FOCUS_NONE
	var profile: Profile = _net().profile
	for it in Cosmetics.items_in(slot):
		var owned := profile.has_item(Cosmetics.key(slot, it.item))
		if not owned and Cosmetics.is_secret(it):
			continue
		var i := list.item_count
		list.add_item(it.name if owned else "%s (locked)" % it.name)
		list.set_item_metadata(i, it.item)
		list.set_item_disabled(i, not owned)
		if not owned:
			list.set_item_tooltip(i, str(it.get("hint", "")))
	list.item_selected.connect(func(i):
		var pick := {"item": list.get_item_metadata(i)}
		var first = CharacterLooks.ITEM_COLORS.get(Cosmetics.key(slot, pick.item))
		if first is Color:
			pick.color = first  # Graphics' suggested first color, e.g. olive for Mercer's cap
		_net().choose_look({slot: pick}))
	row.add_child(list)
	_item_lists[slot] = list
	# An add-on Graphics can't draw yet would offer only "None": leave the row out until it can.
	row.visible = not (list.item_count == 1 and list.get_item_metadata(0) == "none")
	var color := ColorPickerButton.new()
	color.name = "Color_" + slot
	color.custom_minimum_size = Vector2(64, 40)
	color.edit_alpha = false
	color.focus_mode = Control.FOCUS_NONE
	# The figure follows the picker as it moves; the pick is kept when it closes.
	color.color_changed.connect(func(c): _show_look(Cosmetics.merge(my_look(), {slot: {"color": c}})))
	color.popup_closed.connect(func(): _net().choose_look({slot: {"color": color.color}}))
	row.add_child(color)
	_color_buttons[slot] = color


func _swatch(button_name: String, change: Dictionary) -> Button:
	var b := Button.new()
	b.name = button_name
	b.custom_minimum_size = Vector2(52, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_net().choose_look.bind(change))
	return b


## Marks the current picks and shows them on the figure.
func refresh() -> void:
	var mine := my_look()
	for i in _skin_buttons.size():
		_paint(_skin_buttons[i], CharacterLooks.SKIN_TONES[i], i == mine.skin)
	for slug in _crew_buttons:
		var b: Button = _crew_buttons[slug]
		_paint(b, Color(0.15, 0.17, 0.18), slug == mine.crew)
	for slot in _item_lists:
		var list: OptionButton = _item_lists[slot]
		for i in list.item_count:
			if list.get_item_metadata(i) == mine[slot].item:
				list.select(i)
		_color_buttons[slot].color = mine[slot].color
		# Nothing to color in an empty slot; a fixed finish (gold, amber) has no picker.
		var empty: bool = mine[slot].item == "none"
		_color_buttons[slot].disabled = empty
		_color_buttons[slot].modulate.a = 0.25 if empty else 1.0
		_color_buttons[slot].visible = not Cosmetics.fixed_color(slot, mine[slot].item)
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
	_preview_rig = CharacterRig.build(_preview_pivot, NetPlayers.loadout_look(look))
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


func _net() -> Node:
	return get_node("/root/Net")
