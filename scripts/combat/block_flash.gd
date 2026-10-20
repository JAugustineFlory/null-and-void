class_name BlockFlash
extends Control
## The word that flashes under the crosshair when a block catches a hit. The
## health and stamina bars are Movement's Vitals (scripts/ui/vitals.gd).

var label: Label
var _tween: Tween


func _ready() -> void:
	name = "BlockFlash"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	label = ThemeUtil.label(PlayerCombat.BLOCK_NOTICE, 22, Color(0.85, 0.92, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -100
	label.offset_right = 100
	label.offset_top = 14
	label.offset_bottom = 44
	label.modulate.a = 0.0
	add_child(label)


func flash_block() -> void:
	label.modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(0.4)
	_tween.tween_property(label, "modulate:a", 0.0, 0.4)


func is_showing() -> bool:
	return label.modulate.a > 0.0
