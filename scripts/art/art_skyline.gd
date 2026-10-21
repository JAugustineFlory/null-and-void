class_name ArtSkyline
extends RefCounted
## Halcyon Tower from outside (docs/game-plan.md §2): thirty storeys of concrete and
## glass standing alone over dark woods and car parks, at night in 1997.
##
## The World puts every floor at ground level, side by side, so each wing fakes its
## height. A backdrop round the wing draws the night sky and, below it, the campus at
## that storey's height: car-park lamps, roads, the treeline, a few low buildings.
## The tower's own facade runs down from the wing's outside walls to the ground and
## up to the roof. On the ground floor the tower rises from the front facade instead.
##
## Everything here is visual only: no colliders, so the Watcher's sight, the navmesh
## and movement never meet it. Each piece hides itself while the camera is outside
## its wing's backdrop, so a wing next door never shows another wing's sky.

## Which storey each wing is on (G is 0). The architect's defaults, pending Augustine.
const FLOORS := {"level_0": 0, "level_1": 14, "level_2": 22, "level_3": 18, "level_4": 10}
const STOREYS := 30
## The ground floor's lobby is double height; each storey above it is 3.8 m.
const LOBBY_H := 6.0
const STOREY_H := 3.8
## Where the moon is, in each wing's own space.
const MOON := Vector3(0.75, 0.38, 0.22)

## Each wing's backdrop, in the wing's own xz: its middle and radius (big enough to
## hold the whole wing, small enough to miss the wings beside it in World.ROUTE), and
## the tower's middle and half size, which the campus is laid out round.
const VIEWS := {
	"level_0": {"center": Vector2(2, 0), "radius": 220.0, "tower": Vector2(1.8, -6.1), "half": Vector2(22.4, 12.3)},
	"level_1": {"center": Vector2(0, -5.5), "radius": 34.0, "tower": Vector2(0, -5.5), "half": Vector2(22.2, 18.7)},
	"level_2": {"center": Vector2(-6, -5), "radius": 30.0, "tower": Vector2(-6.1, -5), "half": Vector2(12.2, 15.1)},
	"level_3": {"center": Vector2(0, -12.5), "radius": 32.0, "tower": Vector2(0, -12.5), "half": Vector2(21.0, 20.5)},
	"level_4": {"center": Vector2(0, -5), "radius": 26.0, "tower": Vector2(0, -5), "half": Vector2(14.0, 15.0)},
}

static var _shaders := {}


## Height of `storey`'s floor above the ground.
static func floor_height(storey: int) -> float:
	return 0.0 if storey <= 0 else LOBBY_H + (storey - 1) * STOREY_H


## Height of the roof above the ground.
static func roof_height() -> float:
	return floor_height(STOREYS)


## The sky and the campus far below, round `level` (a wing named in FLOORS). Returns
## the Skyline node; facades and lights for the same wing go under it.
static func backdrop(level: Node3D, wing: String) -> Node3D:
	var storey: int = FLOORS[wing]
	var view: Dictionary = VIEWS[wing]
	var up := floor_height(storey)
	var root := Node3D.new()
	root.name = "Skyline"
	root.position = Vector3(view.center.x, 0, view.center.y)
	root.set_meta("storey", storey)
	root.set_meta("radius", view.radius)
	root.set_meta("materials", [])
	ArtDress.dressing_root(level).add_child(root)
	root.tree_entered.connect(func(): _place(root))

	var top := roof_height() - up + 60.0
	var bottom := -up - 5.0
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = view.radius
	cylinder.bottom_radius = view.radius
	cylinder.height = top - bottom
	cylinder.radial_segments = 48
	cylinder.rings = 1
	var sky := _mesh(root, "Sky", cylinder, Vector3(0, (top + bottom) / 2.0, 0))
	var mat := _material(root, SKY)
	mat.set_shader_parameter("ground_y", -up - sky.position.y)
	mat.set_shader_parameter("tower_center", view.tower - view.center)
	mat.set_shader_parameter("tower_half", view.half)
	sky.material_override = mat
	_place(root)
	return root


## The tower's facade along `outline` (points in the wing's own xz, walked with the
## outside on your left), from `from_y` up to `to_y` above this wing's floor: bands
## of concrete at each slab, ribbon windows between, some lit. `cap` roofs it over.
static func facade(skyline: Node3D, outline: PackedVector2Array, from_y: float, to_y: float, node_name := "Facade", cap := false) -> MeshInstance3D:
	var o := Vector2(skyline.position.x, skyline.position.z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size() - 1:
		var a := outline[i] - o
		var b := outline[i + 1] - o
		var along := Vector3(b.x - a.x, 0, b.y - a.y)
		if along.length() < 0.001:
			continue
		var n := Vector3(along.z, 0, -along.x).normalized()
		var quad := [Vector3(a.x, from_y, a.y), Vector3(b.x, from_y, b.y), Vector3(b.x, to_y, b.y), Vector3(a.x, to_y, a.y)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.add_vertex(quad[k])
	if cap:
		var poly := PackedVector2Array()
		for p in outline:
			poly.append(p - o)
		var tris := Geometry2D.triangulate_polygon(poly)
		for k in tris:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(poly[k].x, to_y, poly[k].y))
	var m := _mesh(skyline, node_name, st.commit(), Vector3.ZERO)
	var mat := _material(skyline, FACADE)
	mat.set_shader_parameter("ground_y", -floor_height(skyline.get_meta("storey")))
	m.material_override = mat
	_place(skyline)
	return m


## A red obstruction light, flashing (or steady, the ones partway up).
static func beacon(skyline: Node3D, pos: Vector3, flashing := true, phase := 0.0) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 2.6)
	var m := _mesh(skyline, "Beacon", quad, pos - Vector3(skyline.position.x, 0, skyline.position.z))
	var mat := _material(skyline, BEACON)
	mat.set_shader_parameter("flashing", 1.0 if flashing else 0.0)
	mat.set_shader_parameter("phase", phase)
	m.material_override = mat
	_place(skyline)
	return m


## A plain piece outside (a mast, a gondola, a cable), drawn in the moonlight. `flutter`
## shakes its vertices in the wind, more the further they hang below its top.
static func piece(skyline: Node3D, mesh: Mesh, pos: Vector3, color: Color, flutter := 0.0, node_name := "Piece") -> MeshInstance3D:
	var m := _mesh(skyline, node_name, mesh, pos - Vector3(skyline.position.x, 0, skyline.position.z))
	var mat := _material(skyline, PIECE)
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("flutter", flutter)
	m.material_override = mat
	_place(skyline)
	return m


## A material for `skyline`'s pieces: hidden while the camera is outside its view.
static func material(skyline: Node3D, code: String) -> ShaderMaterial:
	var mat := _material(skyline, code)
	_place(skyline)
	return mat


static func _mesh(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = node_name
	m.mesh = mesh
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m, true)
	return m


static func _material(skyline: Node3D, code: String) -> ShaderMaterial:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code.replace("#COMMON", COMMON)
		_shaders[code] = s
	var mat := ShaderMaterial.new()
	mat.shader = _shaders[code]
	mat.set_shader_parameter("view_radius", skyline.get_meta("radius"))
	mat.set_shader_parameter("moon_dir", MOON.normalized())
	(skyline.get_meta("materials") as Array).append(mat)
	return mat


## Tell every material where its view is, once the wing knows where it stands.
static func _place(skyline: Node3D) -> void:
	if not skyline.is_inside_tree():
		return
	for mat in skyline.get_meta("materials"):
		(mat as ShaderMaterial).set_shader_parameter("view_center", skyline.global_position)


const COMMON := """
uniform vec3 view_center = vec3(0.0);
uniform float view_radius = 30.0;
uniform vec3 moon_dir = vec3(0.8, 0.4, 0.2);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return s;
}

// How much of a pixel lies inside a shape, from its signed distance.
float cover(float d, float fw) {
	return clamp(0.5 - d / max(fw, 0.0001), 0.0, 1.0);
}

float sd_box(vec2 q, vec2 h) {
	vec2 e = abs(q) - h;
	return length(max(e, 0.0)) + min(max(e.x, e.y), 0.0);
}

bool outside_view(vec3 cam) {
	return length(cam.xz - view_center.xz) > view_radius;
}

const vec3 HAZE = vec3(0.025, 0.03, 0.045);

// The colours here are picked by eye as sRGB. Forward+ (the game) draws in linear
// light, so convert (a little short of the full 2.2, so the moonlit ground still
// reads); the Compatibility renderer draws them as they are.
vec3 out_color(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	// Past 1.0 (lamps, lit windows) keep the value, so glow doesn't run away.
	return mix(pow(max(c, vec3(0.0)), vec3(1.7)), c, step(vec3(1.0), c));
#endif
}
"""

## The backdrop: night sky above, the campus below at the ground's height.
const SKY := """
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;
#COMMON
// In this mesh's own space.
uniform float ground_y = -50.0;
uniform vec2 tower_center = vec2(0.0);
uniform vec2 tower_half = vec2(20.0, 12.0);

varying vec3 v_pos;
varying vec3 v_cam;

const vec3 SODIUM = vec3(1.0, 0.62, 0.28);
const float RING = 122.0;
// Car parks and low buildings round the tower: centre xz, half size.
const vec4 LOTS[4] = vec4[4](vec4(0.0, 50.0, 36.0, 15.0), vec4(-80.0, 8.0, 20.0, 32.0), vec4(74.0, -44.0, 26.0, 20.0), vec4(-30.0, -86.0, 32.0, 14.0));
const vec4 BLDG[5] = vec4[5](vec4(64.0, 28.0, 18.0, 11.0), vec4(-74.0, -56.0, 15.0, 20.0), vec4(42.0, -98.0, 25.0, 10.0), vec4(-112.0, 62.0, 12.0, 12.0), vec4(9.0, 160.0, 3.0, 3.0));

void vertex() {
	v_pos = VERTEX;
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

vec3 sky(vec3 d, float time) {
	float el = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(vec3(0.05, 0.06, 0.085), vec3(0.003, 0.005, 0.012), pow(el, 0.4));
	vec2 flat_d = normalize(d.xz + vec2(0.0001));
	// The town over the hills, to one side: a sodium glow on the horizon.
	float town = pow(max(0.0, dot(flat_d, vec2(-0.67, 0.74))), 8.0);
	col += vec3(0.08, 0.045, 0.02) * town * exp(-el * 14.0);
	float md = dot(d, moon_dir);
	col += vec3(0.05, 0.06, 0.08) * pow(max(md, 0.0), 60.0);
	vec3 sd = d * 160.0;
	vec3 cell = floor(sd);
	float h = hash13(cell);
	vec3 off = vec3(hash13(cell + 1.7), hash13(cell + 4.1), hash13(cell + 8.3)) * 0.5 + 0.25;
	float star = step(0.992, h) * smoothstep(0.22, 0.0, length(fract(sd) - off));
	col += vec3(0.75, 0.8, 1.0) * star * (0.6 + 2.0 * fract(h * 37.0)) * smoothstep(0.03, 0.25, el);
	vec2 cp = d.xz / (d.y + 0.12);
	float c = smoothstep(0.52, 0.85, fbm(cp * 0.9 + vec2(time * 0.004, 0.0))) * smoothstep(0.0, 0.12, el);
	col = mix(col, vec3(0.022, 0.025, 0.032) + vec3(0.05, 0.03, 0.012) * town, c * 0.8);
	col = mix(col, vec3(1.3, 1.28, 1.15), smoothstep(0.99955, 0.9997, md) * (1.0 - c * 0.85));
	return col;
}

vec3 lamp(vec2 q, float fw, float on) {
	float d = length(q);
	float r = max(0.3, fw * 0.9);
	float core = smoothstep(r, 0.0, d) * min(4.0, 4.0 * (0.09 / (r * r)) + 1.6);
	return SODIUM * (core + exp(-d * d / 80.0) * 0.16) * on;
}

vec3 campus(vec2 p, float fw, float time) {
	float r = length(p);
	vec3 col = vec3(0.03, 0.04, 0.034) * (0.7 + 0.6 * fbm(p * 0.04));
	vec3 light = vec3(0.0);
	// Woods all round, and clumps of trees between the car parks.
	float edge = 235.0 + 60.0 * (fbm(p * 0.01) - 0.5);
	float wood = smoothstep(0.0, 12.0, r - edge);
	wood = max(wood, smoothstep(0.6, 0.66, fbm(p * 0.018 + 3.7)) * smoothstep(70.0, 90.0, r));
	col = mix(col, vec3(0.012, 0.019, 0.015) * (0.4 + 1.4 * fbm(p * 0.3)), wood);
	// Roads: the ring, the drive south to the gatehouse and on, a spur west.
	float road = abs(r - RING) - 4.0;
	road = min(road, max(abs(p.x) - 4.0, 18.0 - p.y));
	road = min(road, max(abs(p.y + 8.0) - 3.5, p.x + 30.0));
	col = mix(col, vec3(0.055, 0.055, 0.06), cover(road, fw));
	col = mix(col, vec3(0.09, 0.09, 0.086), cover(sd_box(p, tower_half + vec2(14.0)), fw));
	float stp = 26.0 / RING;
	float ai = (floor(atan(p.y, p.x) / stp) + 0.5) * stp;
	light += lamp(p - vec2(cos(ai), sin(ai)) * (RING + 5.5), fw, step(0.12, hash12(vec2(ai * 10.0, 1.0))));
	light += lamp(p - vec2(5.5, max(34.0, floor(p.y / 32.0) * 32.0 + 16.0)), fw, 1.0);
	light += lamp(p - vec2(min(-40.0, floor(p.x / 32.0) * 32.0 + 16.0), -13.0), fw, 1.0);
	for (int i = 0; i < 4; i++) {
		vec4 L = LOTS[i];
		vec2 q = p - L.xy;
		float box = sd_box(q, L.zw);
		vec3 lot = vec3(0.07, 0.07, 0.074);
		// Rows of stalls 5 m deep either side of 6 m aisles.
		float m = mod(q.y + L.w, 16.0);
		float row_b = step(8.0, m);
		float in_row = step(m, 5.0) + step(11.0, m);
		float sx = fract(q.x / 2.6);
		lot = mix(lot, vec3(0.22, 0.22, 0.2), cover(min(sx, 1.0 - sx) * 2.6 - 0.06, fw) * in_row * 0.6);
		float hc = hash12(vec2(floor(q.x / 2.6), floor((q.y + L.w) / 16.0) * 2.0 + row_b) + float(i) * 31.0);
		vec2 cq = vec2((sx - 0.5) * 2.6, m - mix(2.5, 13.5, row_b));
		float car = cover(sd_box(cq, vec2(0.85, 2.1)), fw) * step(0.74, hc) * in_row;
		lot = mix(lot, vec3(0.05 + 0.1 * fract(hc * 7.0), 0.05 + 0.08 * fract(hc * 13.0), 0.06 + 0.1 * fract(hc * 3.0)), car);
		col = mix(col, lot, cover(box, fw));
		// Lamp posts on an 18 m grid; a few are out.
		vec2 n = floor(L.zw / 18.0);
		vec2 g = clamp(floor(q / 18.0 + 0.5), -n, n);
		light += lamp(q - g * 18.0, fw, step(0.18, hash12(g + float(i) * 5.0 + 0.5))) * step(box, 20.0);
	}
	for (int i = 0; i < 5; i++) {
		vec4 B = BLDG[i];
		vec2 q = p - B.xy;
		float d = sd_box(q, B.zw);
		vec3 roof = vec3(0.06, 0.062, 0.068) * (0.85 + 0.3 * vnoise(q * 0.6));
		roof = mix(roof, vec3(0.12, 0.12, 0.125), cover(abs(d + 0.4) - 0.3, fw));
		roof = mix(roof, vec3(0.1, 0.104, 0.11), cover(sd_box(q - B.zw * vec2(0.3, -0.2), vec2(2.0, 1.4)), fw));
		col = mix(col, roof, cover(d, fw));
		// Light from its windows on the grass round it.
		light += vec3(1.0, 0.85, 0.6) * exp(-max(d, 0.0) / 2.5) * step(0.0, d) * 0.05 * (0.4 + hash12(vec2(float(i), 3.0)));
	}
	// A patrol car going round the ring road.
	float ca = time * 0.035;
	vec2 cpos = vec2(cos(ca), sin(ca)) * (RING - 2.0);
	vec2 fwd = vec2(-sin(ca), cos(ca));
	light += vec3(1.0, 0.95, 0.85) * (smoothstep(max(0.3, fw), 0.0, length(p - cpos - fwd * 2.0)) * 2.0 + exp(-pow(length(p - cpos - fwd * 9.0), 2.0) / 30.0) * 0.06);
	light += vec3(1.0, 0.1, 0.05) * smoothstep(max(0.25, fw), 0.0, length(p - cpos + fwd * 2.1)) * 1.2;
	return col + light;
}

void fragment() {
	if (outside_view(CAMERA_POSITION_WORLD)) {
		discard;
	}
	vec3 d = normalize(v_pos - v_cam);
	vec3 col;
	vec3 horizon = sky(normalize(vec3(d.x, 0.0005, d.z)), TIME);
	if (d.y < -0.0005) {
		float t = (ground_y - v_cam.y) / d.y;
		vec3 hit = v_cam + d * t;
		float fw = max(length(fwidth(hit.xz)), 0.02);
		col = mix(campus(hit.xz - tower_center, fw, TIME), horizon, 1.0 - exp(-t * 0.0018));
	} else {
		col = sky(d, TIME);
	}
	// From near the ground, the treeline stands up against the sky.
	float tree_top = (14.0 + 9.0 * fbm(normalize(d.xz + vec2(0.0001)) * 9.0) - (v_cam.y - ground_y)) / 240.0;
	float trees = smoothstep(0.002, -0.002, d.y / max(length(d.xz), 0.001) - tree_top) * step(-0.02, d.y);
	col = mix(col, mix(vec3(0.006, 0.009, 0.008), horizon, 0.3), trees);
	ALBEDO = out_color(col);
}
"""

## The tower's walls: a concrete band at each slab, ribbon windows, some lit.
const FACADE := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
#COMMON
uniform float ground_y = 0.0;

varying vec3 v_pos;
varying vec3 v_nrm;
varying vec3 v_cam;

const float LOBBY = 6.0;
const float STOREY = 3.8;
const float BAY = 1.6;

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

void fragment() {
	if (outside_view(CAMERA_POSITION_WORLD)) {
		discard;
	}
	vec3 n = normalize(v_nrm);
	float h = v_pos.y - ground_y;
	vec3 col;
	float lit = 0.0;
	if (abs(n.y) > 0.5) {
		col = vec3(0.045, 0.045, 0.046) * (0.8 + 0.4 * vnoise(v_pos.xz * 2.0));
	} else {
		float u = abs(n.x) > 0.5 ? v_pos.z * sign(n.x) : -v_pos.x * sign(n.z);
		float face = abs(n.x) > 0.5 ? 1.0 + sign(n.x) : 4.0 + sign(n.z);
		float storey = h < LOBBY ? 0.0 : floor((h - LOBBY) / STOREY) + 1.0;
		float fy = h < LOBBY ? h / LOBBY : fract((h - LOBBY) / STOREY);
		float bay = floor(u / BAY);
		float fx = fract(u / BAY);
		vec3 concrete = vec3(0.19, 0.185, 0.175) * (0.8 + 0.35 * vnoise(vec2(u, h) * 1.3));
		concrete *= 0.75 + 0.5 * max(dot(n, moon_dir), 0.0);
		vec3 glass = mix(vec3(0.02, 0.026, 0.04), vec3(0.06, 0.07, 0.095), fy);
		// Some floors are dark, a few have the cleaners in; the rest, a window here and there.
		float fl = hash12(vec2(storey, face * 3.1));
		float on = hash12(vec2(bay, storey * 1.7 + face * 11.0));
		float chance = fl < 0.22 ? 0.0 : (fl > 0.93 ? 0.8 : 0.14);
		// The server floor is up all night; the security floor shows a couple of desk lamps.
		chance = storey == 14.0 ? 0.75 : (storey == 22.0 ? 0.06 : chance);
		lit = step(on, chance);
		vec3 lamp = mix(vec3(1.0, 0.85, 0.6), vec3(0.75, 0.86, 1.0), step(0.55, fract(on * 13.1))) * (1.1 + 0.9 * fract(on * 7.3));
		lamp *= mix(1.0, 0.45 + 0.55 * step(0.45, fract(fy * 22.0)), step(0.65, fract(on * 29.7)));
		float fwy = fwidth(h) / (h < LOBBY ? LOBBY : STOREY);
		float fwx = fwidth(u) / BAY;
		float solid = max(cover(fy - 0.36, fwy), cover(min(fx, 1.0 - fx) - 0.035, fwx));
		col = mix(glass + lamp * lit, concrete, solid);
		lit *= 1.0 - solid;
		// Sodium light from the car park on the lowest floors.
		col += vec3(0.07, 0.04, 0.015) * exp(-h / 9.0) * (1.0 - lit);
	}
	float dist = length(v_pos - v_cam);
	col = mix(col, HAZE, (1.0 - exp(-dist * 0.003)) * (1.0 - lit * 0.5));
	ALBEDO = out_color(col);
}
"""

## A red obstruction light: a glow that always faces the camera.
const BEACON := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
#COMMON
uniform float flashing = 1.0;
uniform float phase = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	if (outside_view(CAMERA_POSITION_WORLD)) {
		discard;
	}
	float r = length(UV - 0.5) * 2.0;
	float t = fract(TIME * 0.5 + phase);
	float on = mix(1.0, smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.35, 0.45, t)), flashing);
	float g = exp(-r * r * 40.0) * 4.0 + exp(-r * 4.0) * 0.35;
	ALBEDO = out_color(vec3(1.0, 0.12, 0.06) * g * on * (1.0 - smoothstep(0.85, 1.0, r)));
}
"""

## Anything else outside: moonlit on one side, and shaken by the wind if it flutters.
const PIECE := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
#COMMON
uniform vec4 albedo : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float flutter = 0.0;

varying vec3 v_nrm;

void vertex() {
	float hang = max(0.0, -VERTEX.y);
	VERTEX.z += flutter * hang * (sin(TIME * 5.3 + VERTEX.y * 3.1 + VERTEX.x * 2.0) + 0.5 * sin(TIME * 11.7 + VERTEX.x * 5.0));
	VERTEX.x += flutter * hang * 0.4 * sin(TIME * 3.7 + VERTEX.y * 2.3);
	v_nrm = NORMAL;
}

void fragment() {
	if (outside_view(CAMERA_POSITION_WORLD)) {
		discard;
	}
	float lit = abs(dot(normalize(v_nrm), moon_dir));
	ALBEDO = albedo.rgb * COLOR.rgb * (0.35 + 0.65 * lit);
}
"""
