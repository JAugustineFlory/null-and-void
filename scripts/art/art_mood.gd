class_name ArtMood
extends RefCounted
## Lighting moods for the building (see docs/art/style-guide.md). A mood is the
## WorldEnvironment plus what the ceiling lights, flicker and VHS overlay should
## do, so a wing (or the lockdown) can change the whole feel in one call.
##
##   var env := ArtMood.environment("office")
##   world_env.environment = env
##   ArtMood.apply(env, "lockdown")     # later, on the same Environment
##   var look := ArtMood.get_mood("lockdown")  # light_color, light_energy, flicker, vhs

const MOODS := {
	# Level 0 before the turn: a normal, well-lit office at night. Nothing scary.
	"office": {
		"ambient": Color(0.72, 0.74, 0.78), "ambient_energy": 0.45,
		"fog": Color(0.08, 0.09, 0.1), "fog_density": 0.004,
		"exposure": 1.05, "glow": 0.35,
		"light_color": ArtPalette.LIGHT_FLUORESCENT, "light_energy": 1.0,
		"flicker": 0.0, "vhs": 0.08,
	},
	# The car park and anywhere outside: sodium lamps and a cold night.
	"night_exterior": {
		"ambient": Color(0.35, 0.42, 0.6), "ambient_energy": 0.18,
		"fog": Color(0.05, 0.06, 0.09), "fog_density": 0.012,
		"exposure": 1.0, "glow": 0.6,
		"light_color": ArtPalette.LIGHT_SODIUM, "light_energy": 1.0,
		"flicker": 0.0, "vhs": 0.12,
	},
	# After the turn: the same office, but tubes are dying and the air is thick.
	"after_hours": {
		"ambient": Color(0.45, 0.52, 0.5), "ambient_energy": 0.12,
		"fog": Color(0.05, 0.06, 0.06), "fog_density": 0.025,
		"exposure": 0.95, "glow": 0.6,
		"light_color": ArtPalette.LIGHT_SICK, "light_energy": 0.8,
		"flicker": 0.12, "vhs": 0.3,
	},
	# WARDEN's lockdown: red emergency light, everything else off.
	"lockdown": {
		"ambient": Color(0.6, 0.12, 0.1), "ambient_energy": 0.1,
		"fog": Color(0.12, 0.02, 0.02), "fog_density": 0.03,
		"exposure": 1.0, "glow": 0.9,
		"light_color": ArtPalette.LIGHT_EMERGENCY, "light_energy": 0.9,
		"flicker": 0.05, "vhs": 0.45,
	},
	# Lights-out levels: flashlights and screens only. Ambient stays just above
	# black so the floor reads and nobody gets lost staring at nothing.
	"dark": {
		"ambient": Color(0.3, 0.38, 0.55), "ambient_energy": 0.025,
		"fog": Color(0.0, 0.0, 0.01), "fog_density": 0.05,
		"exposure": 1.1, "glow": 0.8,
		"light_color": ArtPalette.LIGHT_MOON, "light_energy": 0.0,
		"flicker": 0.0, "vhs": 0.5,
	},
}


static func get_mood(mood: String) -> Dictionary:
	assert(MOODS.has(mood), "Unknown mood " + mood)
	return MOODS.get(mood, MOODS["office"])


## A new Environment set up for `mood`.
static func environment(mood: String) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.glow_enabled = true
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	apply(env, mood)
	return env


## Switch an existing Environment to `mood`.
static func apply(env: Environment, mood: String) -> void:
	var m := get_mood(mood)
	env.ambient_light_color = m.ambient
	env.ambient_light_energy = m.ambient_energy
	env.fog_light_color = m.fog
	env.fog_density = m.fog_density
	env.tonemap_exposure = m.exposure
	env.glow_intensity = m.glow
	# Lo-fi grade: a touch less saturation once things go wrong.
	env.adjustment_saturation = lerpf(1.0, 0.8, m.vhs)
	env.adjustment_contrast = lerpf(1.0, 1.1, m.vhs)


## Recolor and dim a set of ceiling lights for `mood`, keeping each light's own
## design energy (stored in its "base_energy" meta the first time).
static func apply_to_lights(lights: Array, mood: String) -> void:
	var m := get_mood(mood)
	for l in lights:
		var light := l as Light3D
		if not light:
			continue
		if not light.has_meta("base_energy"):
			light.set_meta("base_energy", light.light_energy)
		light.light_color = m.light_color
		light.light_energy = float(light.get_meta("base_energy")) * m.light_energy
		# A fitting's glowing panel (ArtProps.troffer) follows its light.
		var panel := light.get_node_or_null("Diffuser") as MeshInstance3D
		if panel:
			panel.material_override = ArtPalette.glow(m.light_color, 2.2) if m.light_energy > 0.0 else ArtPalette.flat(Color(0.35, 0.36, 0.36), 0.3)
