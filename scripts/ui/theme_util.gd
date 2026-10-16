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
