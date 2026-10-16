class_name VHSOverlay
extends CanvasLayer
## The lo-fi camcorder look: film grain, faint scanlines, a little color bleed,
## a soft vignette and the odd tracking wobble. `intensity` runs from 0 (off,
## costs nothing) to 1 (a chewed-up tape). Level 0 sits near 0.08 so it still
## looks like a normal office; moods raise it (ArtMood "vhs").

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.1;
uniform float time_offset = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME + time_offset;
	// Tracking wobble: a thin band that drifts down the screen and nudges pixels sideways.
	float band = smoothstep(0.02, 0.0, abs(fract(uv.y - t * 0.07) - 0.5));
	uv.x += band * 0.006 * intensity * sin(t * 40.0 + uv.y * 200.0);
	// Color bleed: red and blue sample slightly apart.
	float bleed = 0.0018 * intensity;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(bleed, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(bleed, 0.0)).b;
	// Scanlines.
	float scan = 0.5 + 0.5 * sin(SCREEN_UV.y / SCREEN_PIXEL_SIZE.y * 3.14159);
	col *= 1.0 - 0.12 * intensity * scan;
	// Grain.
	float g = hash(floor(SCREEN_UV / SCREEN_PIXEL_SIZE / 2.0) + fract(t * 7.0) * 100.0) - 0.5;
	col += g * 0.16 * intensity;
	// Vignette.
	vec2 d = SCREEN_UV - 0.5;
	col *= 1.0 - dot(d, d) * (0.35 + 0.9 * intensity);
	COLOR = vec4(col, 1.0);
}
"""

static var _shader: Shader

@export_range(0.0, 1.0) var intensity := 0.08:
	set(v):
		intensity = clampf(v, 0.0, 1.0)
		_refresh()

var rect: ColorRect
var _mat: ShaderMaterial
var _tween: Tween


func _init() -> void:
	layer = 3  # above the 3D view, below the HUD (5), terminal (20) and pause menu (30)
	if not _shader:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	rect = ColorRect.new()
	rect.material = _mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	_refresh()


## Ease to a new intensity, e.g. when the lockdown hits.
func fade_to(target: float, seconds: float = 1.5) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "intensity", target, seconds)


func set_mood(mood: String, seconds: float = 1.5) -> void:
	fade_to(ArtMood.get_mood(mood).vhs, seconds)


func _refresh() -> void:
	if not _mat:
		return
	_mat.set_shader_parameter("intensity", intensity)
	rect.visible = intensity > 0.001
