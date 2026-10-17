class_name ArtPalette
extends RefCounted
## The game's shared colors and surface materials (see docs/art/style-guide.md).
## Every material is built once and cached, so a whole wing shares a handful of
## materials and the renderer can batch them. Textures are small, generated in
## code and mapped in world space (triplanar), so they line up on Greybox boxes of
## any size without UVs.

# --- Halcyon Data Systems: the "normal office" of Level 0 ----------------------
const OFFICE_WALL := Color(0.71, 0.67, 0.58)  # warm beige paint
const OFFICE_CARPET := Color(0.24, 0.29, 0.31)  # teal-grey commercial carpet tiles
const OFFICE_CEILING := Color(0.86, 0.85, 0.8)  # off-white acoustic tiles
const OFFICE_TRIM := Color(0.36, 0.33, 0.3)  # skirting, door frames
const LAMINATE := Color(0.55, 0.4, 0.27)  # desks, reception counter
const PARTITION := Color(0.46, 0.5, 0.53)  # fabric cubicle panels
const HALCYON_NAVY := Color(0.13, 0.2, 0.36)  # the company's brand color
const HALCYON_GOLD := Color(0.8, 0.66, 0.35)
# --- Back of house: server rooms, stairwells, plant ----------------------------
const CONCRETE := Color(0.42, 0.42, 0.41)
const METAL := Color(0.52, 0.54, 0.56)
const RACK_BLACK := Color(0.08, 0.085, 0.09)
const SAFETY_YELLOW := Color(0.85, 0.68, 0.12)
# --- Plastics and devices ------------------------------------------------------
const BEIGE_PLASTIC := Color(0.78, 0.75, 0.66)  # 90s computer cases
const DARK_PLASTIC := Color(0.1, 0.1, 0.11)
# --- Byte-Right IT Services: the players' company ------------------------------
const BYTERIGHT_BLUE := Color(0.1, 0.3, 0.6)
# --- Light colors --------------------------------------------------------------
const LIGHT_FLUORESCENT := Color(0.94, 0.97, 1.0)  # cool office tubes
const LIGHT_WARM := Color(1.0, 0.9, 0.75)  # lamps, porch, van dome
const LIGHT_SODIUM := Color(1.0, 0.72, 0.42)  # car park
const LIGHT_SICK := Color(0.78, 0.95, 0.72)  # dying tubes after the turn
const LIGHT_EMERGENCY := Color(1.0, 0.16, 0.1)  # lockdown strobes
const LIGHT_MOON := Color(0.45, 0.55, 0.8)  # dark floors, through windows
const LIGHT_SCREEN := Color(0.55, 0.9, 0.65)  # terminal glow
const LIGHT_FLASHLIGHT := Color(1.0, 0.95, 0.85)

## The six players' polo colors: distinct hues at similar brightness, so you can
## tell teammates apart in the dark and on a colorblind screen (blue, orange,
## green, magenta, yellow, cyan).
const CREW_COLORS: Array[Color] = [
	Color(0.12, 0.33, 0.68),
	Color(0.85, 0.42, 0.1),
	Color(0.2, 0.58, 0.3),
	Color(0.68, 0.22, 0.52),
	Color(0.86, 0.74, 0.18),
	Color(0.15, 0.62, 0.68),
]

## Surface kinds `surface()` knows. Each is a color, a roughness, a generated
## texture and the world size one texture tile covers (meters).
const SURFACES := {
	"carpet": {"color": OFFICE_CARPET, "rough": 1.0, "tex": "speckle", "tile": 0.5},
	"ceiling_tile": {"color": OFFICE_CEILING, "rough": 0.95, "tex": "tiles", "tile": 0.6},
	"drywall": {"color": OFFICE_WALL, "rough": 0.9, "tex": "soft", "tile": 2.0},
	"laminate": {"color": LAMINATE, "rough": 0.55, "tex": "grain", "tile": 1.2},
	"partition": {"color": PARTITION, "rough": 1.0, "tex": "speckle", "tile": 0.3},
	"concrete": {"color": CONCRETE, "rough": 0.95, "tex": "blotch", "tile": 3.0},
	"floor_tile": {"color": Color(0.7, 0.69, 0.64), "rough": 0.4, "tex": "tiles", "tile": 0.3},
	"metal": {"color": METAL, "rough": 0.45, "metal": 0.8, "tex": "brushed", "tile": 1.0},
	"rack": {"color": RACK_BLACK, "rough": 0.5, "metal": 0.4, "tex": "brushed", "tile": 1.0},
	"rack_front": {"color": Color(0.11, 0.115, 0.125), "rough": 0.5, "metal": 0.4, "tex": "rackfront", "tile": 0.6},
	"asphalt": {"color": Color(0.13, 0.13, 0.14), "rough": 1.0, "tex": "speckle", "tile": 1.5},
	"plastic": {"color": BEIGE_PLASTIC, "rough": 0.5, "tex": "", "tile": 1.0},
	"dark_plastic": {"color": DARK_PLASTIC, "rough": 0.45, "tex": "", "tile": 1.0},
}

const TEX_SIZE := 128

static var _cache := {}
static var _textures := {}


## A shared, textured material for a kind of surface, e.g. surface("carpet").
## `tint` multiplies the base color, for a stained or sun-faded variant.
static func surface(kind: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "%s|%s" % [kind, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var s: Dictionary = SURFACES.get(kind, SURFACES["plastic"])
	var m := StandardMaterial3D.new()
	m.albedo_color = (s.color as Color) * tint
	m.roughness = s.rough
	m.metallic = s.get("metal", 0.0)
	if s.tex != "":
		m.albedo_texture = texture(s.tex)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / float(s.tile)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m


## A plain shared material (no texture): cloth, skin, small parts.
static func flat(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "flat|%s|%s|%s" % [color.to_html(), roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_cache[key] = m
	return m


## A glowing material: screens, LEDs, light panels, exit signs.
static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "glow|%s|%s" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


## Dark glass for windows, screens that are off, the van's windscreen.
static func glass(tint: Color = Color(0.1, 0.13, 0.15)) -> StandardMaterial3D:
	var key := "glass|%s" % tint.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(tint, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.3
	_cache[key] = m
	return m


## How many materials have been built (tests use this to prove they are shared).
static func material_count() -> int:
	return _cache.size()


## A small grayscale texture, generated once. Kinds: speckle, tiles, soft,
## grain, blotch, brushed, rackfront. Values sit around 0.85 so the albedo color still reads.
static func texture(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_L8)
	var noise := FastNoiseLite.new()
	noise.seed = kind.hash()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var n := TEX_SIZE
	for y in n:
		for x in n:
			var v := 0.85
			match kind:
				"speckle":
					noise.frequency = 0.5
					v = 0.8 + 0.2 * _tile_noise(noise, x, y, n)
				"soft":
					noise.frequency = 0.04
					v = 0.92 + 0.08 * _tile_noise(noise, x, y, n)
				"blotch":
					noise.frequency = 0.03
					var big := _tile_noise(noise, x, y, n)
					noise.frequency = 0.4
					v = 0.72 + 0.16 * big + 0.1 * _tile_noise(noise, x, y, n)
				"grain":
					noise.frequency = 0.02
					var warp := _tile_noise(noise, x, y, n)
					v = 0.87 + 0.06 * (0.5 + 0.5 * sin((float(y) / n) * TAU * 12.0 + warp * 3.0))
				"brushed":
					noise.frequency = 0.6
					v = 0.86 + 0.1 * _tile_noise(noise, x, 0, n)
				"rackfront":
					# One cabinet per tile: dark seams down each side, a vented door between.
					v = 0.9 + 0.06 * (1.0 if (y / 3) % 2 == 0 else 0.0)
					if mini(x, n - 1 - x) < 3:
						v = 0.35
				"tiles":
					noise.frequency = 0.45
					v = 0.86 + 0.1 * _tile_noise(noise, x, y, n)
					var edge := mini(mini(x, n - 1 - x), mini(y, n - 1 - y))
					if edge < 2:
						v = 0.55
					elif edge < 4:
						v *= 0.92
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[kind] = tex
	return tex


## Noise that wraps at the texture edge, so tiles don't show seams. Returns 0..1.
static func _tile_noise(noise: FastNoiseLite, x: int, y: int, n: int) -> float:
	var fx := float(x) / n
	var fy := float(y) / n
	var a := noise.get_noise_2d(x, y)
	var b := noise.get_noise_2d(x - n, y)
	var c := noise.get_noise_2d(x, y - n)
	var d := noise.get_noise_2d(x - n, y - n)
	var v := lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)
	return clampf(v * 0.5 + 0.5, 0.0, 1.0)
