class_name PadFocus
extends Node
## Menus a controller can drive: a bright outline on whatever has focus, and
## somewhere for focus to be. Add one to a menu's root (PadFocus.attach): when a
## d-pad, stick or A press arrives and nothing in the menu has focus (a mouse
## click took it, or the button that had it was hidden), the menu's first
## button takes it, so the press is never lost. Godot's ui_* actions do the rest:
## ui_up/down/left/right move between controls, ui_accept presses, ui_cancel goes back.

## The outline round the focused control.
const RING := Color(1.0, 0.75, 0.3)  # ThemeUtil.AMBER
const RING_WIDTH := 3

## The menu this keeps focus in.
var root: Control
## A panel over another screen (MenuModal, the pause menu): while it's up, focus
## can't wander off it to the buttons behind.
var trap := false
var _last: Control
## Every trap that's up, oldest first: only the newest one (the panel on top) holds focus.
static var _traps: Array[PadFocus] = []


## Give `menu` the focus outline and keep focus in it (`trap`: and on it). Returns the helper.
static func attach(menu: Control, trap_focus := false) -> PadFocus:
	menu.theme = theme()
	var pf := PadFocus.new()
	pf.name = "PadFocus"
	pf.root = menu
	pf.trap = trap_focus
	pf.process_mode = Node.PROCESS_MODE_ALWAYS  # the pause menu runs while the game is paused
	menu.add_child(pf)
	return pf


## Only the focus look, so every other part of a control keeps its own (or the
## default) style.
static func theme() -> Theme:
	var t := Theme.new()
	var ring := StyleBoxFlat.new()
	ring.draw_center = true
	ring.bg_color = Color(RING, 0.12)
	ring.border_color = RING
	ring.set_border_width_all(RING_WIDTH)
	ring.set_corner_radius_all(4)
	ring.set_expand_margin_all(2)
	for type in ["Button", "CheckButton", "CheckBox", "OptionButton", "ColorPickerButton", "MenuButton", "LinkButton"]:
		t.set_stylebox("focus", type, ring)
	for type in ["HSlider", "VSlider", "LineEdit", "TabContainer", "TabBar", "ItemList", "ScrollContainer"]:
		var edge := ring.duplicate()
		edge.draw_center = false
		t.set_stylebox("focus", type, edge)
	return t


## The first control under `menu` that can take focus right now, in tree order.
static func first(menu: Node) -> Control:
	for c in menu.get_children():
		if c is Control and not (c as Control).is_visible_in_tree():
			continue
		if _can_focus(c):
			return c
		var inner := first(c)
		if inner:
			return inner
	return null


## Focus `menu`'s first control, once it's laid out (call it as a menu opens).
static func focus_first(menu: Node) -> void:
	var c := first(menu)
	if c:
		c.call_deferred("grab_focus")


static func _can_focus(c: Node) -> bool:
	if not (c is Control) or (c as Control).focus_mode != Control.FOCUS_ALL:
		return false
	if c is BaseButton and (c as BaseButton).disabled:
		return false
	return (c as Control).is_visible_in_tree()


func _ready() -> void:
	if trap:
		_traps.append(self)
		get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _exit_tree() -> void:
	_traps.erase(self)


## The panel on top: the newest trap still on screen.
static func _top() -> PadFocus:
	for i in range(_traps.size() - 1, -1, -1):
		var t := _traps[i]
		if is_instance_valid(t) and t.root.is_visible_in_tree() and not t.root.is_queued_for_deletion():
			return t
	return null


## A trap: focus moved off the panel (a d-pad press found a button behind it), so it goes back.
func _on_focus_changed(c: Control) -> void:
	if _top() != self or _outside_menu(c):
		return
	if root.is_ancestor_of(c):
		_last = c
	elif is_instance_valid(_last) and _last.is_visible_in_tree():
		_last.call_deferred("grab_focus")
	else:
		focus_first(root)


func _input(event: InputEvent) -> void:
	if not root or not root.is_visible_in_tree() or not _is_nav(event):
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner and owner.is_visible_in_tree() and (root.is_ancestor_of(owner) or _outside_menu(owner)):
		return
	var c := first(root)
	if c:
		c.grab_focus()
		get_viewport().set_input_as_handled()  # this press lands the focus; the next one moves it


## Focus is on something that isn't part of this menu, e.g. a popup list it opened.
func _outside_menu(owner: Control) -> bool:
	return owner.get_window() != root.get_window()


static func _is_nav(event: InputEvent) -> bool:
	if event is InputEventMouse:
		return false
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_focus_next", "ui_focus_prev"]:
		if event.is_action_pressed(action):
			return true
	return false
