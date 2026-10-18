class_name InventoryScreen
extends CanvasLayer
## The hotbar along the bottom of the screen (F flashlight, Tab notebook, then the
## four item slots on 1-4) and the inventory, opened with I, where you choose what
## sits on the hotbar: click an item, then the slot to put it in.

const SLOT_SIZE := Vector2(104, 50)
const LIT := Color(1.0, 0.75, 0.3)
const DULL := Color(0.75, 0.75, 0.75, 0.75)

var player: Player
var hud: HUD
var inventory: Inventory:
	set(inv):
		if inventory and inventory.changed.is_connected(_refresh):
			inventory.changed.disconnect(_refresh)
			inventory.selected.disconnect(_on_selected)
		inventory = inv
		if inv:
			inv.changed.connect(_refresh)
			inv.selected.connect(_on_selected)
		if is_inside_tree():
			_refresh()
## The item picked up in the inventory, waiting for a slot; "" for none.
var picked := ""

var _bar: HBoxContainer
var _slots: Array[PanelContainer] = []
var _panel: PanelContainer
var _bag: VBoxContainer
var _panel_slots: HBoxContainer
var _help: Label
var _hint: Label  # above the hotbar: how to use something that just arrived
var _hint_tween: Tween
var _open := false
var _seen := {}  # items already shown arriving on the bar


static func create(parent: Node, for_player: Player, for_hud: HUD) -> InventoryScreen:
	var s := InventoryScreen.new()
	s.name = "InventoryScreen"
	s.player = for_player
	s.hud = for_hud
	parent.add_child(s)
	s.inventory = for_player.inventory
	return s


func _ready() -> void:
	layer = 6
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 6)
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.position.y = -100  # above the keys line, below subtitles
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bar)

	_hint = ThemeUtil.label("", 18, LIT)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size = Vector2(900, 0)
	_hint.position = Vector2(-450, -128)
	_hint.modulate.a = 0.0
	root.add_child(_hint)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.05, 0.06, 0.94), LIT))
	_panel.visible = false
	root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(620, 0)
	_panel.add_child(col)
	col.add_child(ThemeUtil.label("INVENTORY", 30, LIT))
	_bag = VBoxContainer.new()
	_bag.add_theme_constant_override("separation", 6)
	col.add_child(_bag)
	col.add_child(ThemeUtil.label("HOTBAR", 20, LIT))
	_panel_slots = HBoxContainer.new()
	_panel_slots.add_theme_constant_override("separation", 6)
	col.add_child(_panel_slots)
	_help = ThemeUtil.label("", 17, DULL)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_help)
	_refresh()


func _process(_delta: float) -> void:
	# At a terminal the screen is the whole view: the hotbar steps aside.
	var show := player != null and is_instance_valid(player) and not player.is_using_terminal()
	_bar.visible = show
	_hint.visible = show


func is_open() -> bool:
	return _open


## Opens the inventory. False if you're busy: at a terminal, reading, or in a menu.
func open() -> bool:
	if _open or not player or player.input_locked or player.is_using_terminal() or player.is_holding_notebook() or player.is_holding_prop():
		return false
	_open = true
	picked = ""
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	picked = ""
	player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh()


## Inventory: click an item to pick it, or a filled slot to pick what's in it.
func pick(item: String) -> void:
	picked = "" if picked == item else item
	_refresh()


## Inventory: put the picked item in `slot` (swapping with whatever's there), or
## pick up the slot's item if nothing is picked.
func choose_slot(slot: int) -> void:
	if picked != "":
		inventory.assign(slot, picked)
		picked = ""
	else:
		picked = inventory.hotbar[slot]
	_refresh()


## Inventory: take the picked item off the hotbar and back into the bag.
func stow_picked() -> void:
	var slot := inventory.hotbar.find(picked)
	if slot >= 0:
		inventory.assign(slot, "")
	picked = ""
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not player or not player.local_control:
		return
	if event.is_action_pressed("inventory") or (_open and event.is_action_pressed("pause")):
		if _open:
			close()
		elif not open():
			return
		get_viewport().set_input_as_handled()
	elif _open and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_4:
		choose_slot(event.physical_keycode - KEY_1)
		get_viewport().set_input_as_handled()


func _on_selected(item: String) -> void:
	_refresh()
	if item != "" and hud:
		hud.set_prompt("")
		hud.notice(Inventory.item_name(item), 1.2, LIT)


func _refresh() -> void:
	if not is_inside_tree() or _bar == null or inventory == null:
		return
	_panel.visible = _open
	_build_bar()
	if _open:
		_build_panel()


func _build_bar() -> void:
	for c in _bar.get_children():
		c.queue_free()
	_slots.clear()
	_bar.add_child(_slot_view("F", "Flashlight", false, false))
	_bar.add_child(_slot_view("Tab", "Notebook", false, false))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(14, 0)
	_bar.add_child(gap)
	for i in Inventory.HOTBAR_SIZE:
		var item := inventory.hotbar[i]
		var fresh := item != "" and not _seen.has(item)
		var v := _slot_view(str(i + 1), Inventory.item_name(item) if item != "" else "", i == inventory.active, fresh)
		_bar.add_child(v)
		_slots.append(v)
		if fresh:
			_seen[item] = true
			_announce(item, i)


## A new item lands on the hotbar: its slot glows for a moment, and the first time
## anything arrives, a line says how to rearrange them.
func _announce(item: String, slot: int) -> void:
	var v := _slots[slot]
	var t := v.create_tween()
	t.tween_property(v, "modulate", Color(1.6, 1.4, 1.0), 0.25)
	t.tween_property(v, "modulate", Color.WHITE, 0.9)
	_hint.text = "%s on your hotbar: press %d to take it out." % [Inventory.item_name(item), slot + 1]
	if _seen.size() == 1:
		_hint.text += " I opens your inventory."
	if _hint_tween:
		_hint_tween.kill()
	var h := _hint.create_tween()
	_hint_tween = h
	h.tween_property(_hint, "modulate:a", 1.0, 0.3)
	h.tween_interval(5.0)
	h.tween_property(_hint, "modulate:a", 0.0, 0.8)


func _slot_view(key: String, text: String, active: bool, _fresh: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = SLOT_SIZE
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.55), LIT if active else Color(1, 1, 1, 0.25)))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	v.add_child(ThemeUtil.label(key, 15, LIT if active else DULL))
	var name_label := ThemeUtil.label(text, 16, Color.WHITE if text != "" else DULL)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_label)
	return p


func _build_panel() -> void:
	for c in _bag.get_children():
		c.queue_free()
	for c in _panel_slots.get_children():
		c.queue_free()
	for item in inventory.items:
		var info: Dictionary = Inventory.ITEMS.get(item, {})
		var fixed := Inventory.FIXED.has(item)
		var where := "always at hand (%s)" % info.get("key", "") if fixed else \
				("hotbar %d" % (inventory.hotbar.find(item) + 1) if inventory.hotbar.has(item) else "in your bag")
		var b := Button.new()
		b.text = "%s  -  %s\n%s" % [Inventory.item_name(item), where, info.get("about", "")]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = fixed
		b.toggle_mode = true
		b.button_pressed = item == picked
		b.pressed.connect(pick.bind(item))
		_bag.add_child(b)
	for i in Inventory.HOTBAR_SIZE:
		var item := inventory.hotbar[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(146, 56)
		b.text = "%d\n%s" % [i + 1, Inventory.item_name(item) if item != "" else "(empty)"]
		b.pressed.connect(choose_slot.bind(i))
		_panel_slots.add_child(b)
	if picked != "" and inventory.hotbar.has(picked):
		var off := Button.new()
		off.text = "Take %s off the hotbar" % Inventory.item_name(picked)
		off.pressed.connect(stow_picked)
		_panel_slots.add_child(off)
	if picked == "":
		_help.text = "Click an item, then the hotbar slot to put it in. I or Esc to close."
	else:
		_help.text = "Now click a hotbar slot (or press 1-4) for the %s." % Inventory.item_name(picked)


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(8)
	return s
