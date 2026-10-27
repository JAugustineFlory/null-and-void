class_name ThemeUtil
extends RefCounted
## Shared fonts and colors for the CRT look.

const GREEN := Color(0.45, 1.0, 0.55)
const AMBER := Color(1.0, 0.75, 0.3)
const RED := Color(1.0, 0.35, 0.3)
const DIM := Color(0.35, 0.6, 0.4)

static var _mono: SystemFont


static func mono() -> SystemFont:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "Courier New", "monospace"])
	return _mono


static func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


## The game's version (project.godot's application/config/version), as "v0.7.1",
## small in the bottom-right corner of whatever it's added to, so every
## screenshot and playtest note names its build.
static func version_tag() -> Label:
	var l := label("v%s" % ProjectSettings.get_setting("application/config/version", "?"), 14, Color(1, 1, 1, 0.55))
	l.name = "Version"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_right = -12
	l.offset_bottom = -8
	return l
