class_name ArtMesh
extends RefCounted
## One mesh built out of many coloured boxes, plates and rods, so a shelf of a
## hundred archive boxes, or a card catalogue of a hundred drawers, is a single
## draw. The colours are vertex colours on one shared material (`material()`).
## Visual only: nothing here collides.
##
##   var m := ArtMesh.new()
##   m.box(Vector3(0, 0.15, 0), Vector3(0.4, 0.3, 0.3), Color(0.7, 0.6, 0.45))
##   m.plate(Vector3(0, 0.15, -0.151), Vector3(0.1, 0, 0), Vector3(0, 0.05, 0), Color.WHITE)
##   m.commit(parent, "Boxes")

var _st := SurfaceTool.new()
var _empty := true

static var _materials := {}


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


## A box centred at `center`, turned `yaw_deg` about the vertical. `skip` lists
## faces nobody sees ("bottom", "top", "-x", "+x", "-z", "+z").
func box(center: Vector3, size: Vector3, color: Color, yaw_deg := 0.0, skip: Array = []) -> void:
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var h := size / 2.0
	var x := b.x * h.x
	var y := b.y * h.y
	var z := b.z * h.z
	if not "+x" in skip:
		plate(center + x, -z, y, color)
	if not "-x" in skip:
		plate(center - x, z, y, color)
	if not "+z" in skip:
		plate(center + z, x, y, color)
	if not "-z" in skip:
		plate(center - z, -x, y, color)
	if not "top" in skip:
		plate(center + y, x, -z, color)
	if not "bottom" in skip:
		plate(center - y, x, z, color)


## A flat rectangle: `u` and `v` are its half-extents (along its width and its
## height); it faces u x v.
func plate(center: Vector3, u: Vector3, v: Vector3, color: Color) -> void:
	var n := u.cross(v).normalized()
	_st.set_color(color)
	_st.set_normal(n)
	for p in [center - u - v, center + u + v, center + u - v, center - u - v, center - u + v, center + u + v]:
		_st.add_vertex(p)
	_empty = false


## A round rod from `a` to `b`, `sides` faces round.
func rod(a: Vector3, b: Vector3, radius: float, color: Color, sides := 6, caps := false) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis)
	_st.set_color(color)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := (side * cos(a0) + up * sin(a0)) * radius
		var d1 := (side * cos(a1) + up * sin(a1)) * radius
		var n := (d0 + d1).normalized()
		_tri(a + d0, b + d1, b + d0, n)
		_tri(a + d0, a + d1, b + d1, n)
		if caps:
			_tri(b, b + d0, b + d1, axis)
			_tri(a, a + d1, a + d0, -axis)
	_empty = false


## One triangle facing `n` (Godot's front faces wind clockwise).
func _tri(p0: Vector3, p1: Vector3, p2: Vector3, n: Vector3) -> void:
	_st.set_normal(n)
	if (p1 - p0).cross(p2 - p0).dot(n) > 0.0:
		var t := p1
		p1 = p2
		p2 = t
	_st.add_vertex(p0)
	_st.add_vertex(p1)
	_st.add_vertex(p2)


## Add the mesh under `parent` as one MeshInstance3D (null if nothing was added).
func commit(parent: Node, node_name: String, shadow := false, roughness := 0.85, metallic := 0.0) -> MeshInstance3D:
	if _empty:
		return null
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = _st.commit()
	mi.material_override = material(roughness, metallic)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi, true)
	return mi


## The shared material for vertex-coloured meshes, by finish.
static func material(roughness := 0.85, metallic := 0.0, srgb := true) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [roughness, metallic, srgb]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = srgb
	m.roughness = roughness
	m.metallic = metallic
	_materials[key] = m
	return m
