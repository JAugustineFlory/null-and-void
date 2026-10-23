class_name SfxVolume
## The pause menu's volume sliders: everything, then music, effects, ambience and
## voices on their own. Each change is saved for next time.

const ROWS := [
	[&"Master", "Volume", 2.0],
	[Sfx.MUSIC, "Music", 1.0],
	[Sfx.SFX, "Effects", 1.0],
	[Sfx.AMBIENCE, "Ambience", 1.0],
	[Sfx.VOICE, "Voices", 1.0],
]


static func sliders() -> VBoxContainer:
	Sfx.ensure_buses()
	var box := VBoxContainer.new()
	box.name = "Volume"
	box.add_theme_constant_override("separation", 4)
	for row in ROWS:
		var bus: StringName = row[0]
		box.add_child(ThemeUtil.label(row[1], 20 if bus == &"Master" else 16))
		var s := HSlider.new()
		s.name = String(bus)
		s.min_value = 0.0
		s.max_value = row[2]
		s.step = 0.05
		s.value = Sfx.volume(bus)
		s.custom_minimum_size = Vector2(300, 20)
		s.value_changed.connect(func(v): Sfx.set_volume(bus, v))
		box.add_child(s)
	return box
