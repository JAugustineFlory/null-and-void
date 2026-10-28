class_name MenuModal
extends Control
## A panel over a menu screen: the screen behind it dims, the panel scrolls inside
## the window's margins (so nothing lands off the bottom of a short window), and
## Esc or Back closes it. Fill `box` with whatever the panel is for.
##
##   var m := MenuModal.open(self)
##   m.box.add_child(SettingsPanel.audio())

## Where the panel's contents go.
var box: VBoxContainer


## A panel over `parent`, empty and already on screen.
static func open(parent: Node) -> MenuModal:
	var m := MenuModal.new()
	parent.add_child(m)
	return m


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	box = VBoxContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 12)
	column(self, box)


## Puts `box` in the middle of `parent`, inside the window's margins, scrolling when
## it's taller than the window so nothing runs off the bottom. A scroll view keeps
## its contents at the left on its own, so the column sits in a centering box.
static func column(parent: Control, box: Control) -> ScrollContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	parent.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	center.add_child(box)
	return scroll


## Adds the way out, last of all.
func add_back(text: String = "Back") -> Button:
	var back := SettingsPanel.button(text)
	back.name = "Back"
	back.pressed.connect(close)
	box.add_child(back)
	return back


func close() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
