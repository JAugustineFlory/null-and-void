class_name PropWalkie
extends Node3D
## A handheld walkie-talkie: yellow-and-black body, stubby antenna, a little
## green screen and a status LED (red while you talk, green while someone else
## does). Stands upright on its base; the speaker grille faces -Z.

var led: MeshInstance3D
var screen: MeshInstance3D
var transmitting := false
var receiving := false
var _blink := 0.0


static func create(parent: Node) -> PropWalkie:
	var w := PropWalkie.new()
	w.name = "Walkie"
	w._make()
	parent.add_child(w)
	return w


func _make() -> void:
	_box(Vector3(0.06, 0.13, 0.03), Vector3(0, 0.065, 0), ArtPalette.flat(ArtPalette.SAFETY_YELLOW, 0.55))
	_box(Vector3(0.064, 0.05, 0.034), Vector3(0, 0.02, 0), ArtPalette.flat(Color(0.1, 0.1, 0.1), 0.7))  # rubber base
	_box(Vector3(0.045, 0.04, 0.004), Vector3(0, 0.05, -0.016), ArtPalette.flat(Color(0.08, 0.08, 0.08), 0.8))  # grille
	screen = _box(Vector3(0.036, 0.018, 0.004), Vector3(0, 0.1, -0.016), ArtPalette.glow(ArtPalette.LIGHT_SCREEN, 0.8))
	_box(Vector3(0.008, 0.1, 0.008), Vector3(0.018, 0.18, 0.004), ArtPalette.flat(Color(0.08, 0.08, 0.08), 0.6))  # antenna
	_box(Vector3(0.012, 0.012, 0.012), Vector3(-0.016, 0.137, 0.0), ArtPalette.flat(Color(0.15, 0.15, 0.15), 0.6))  # knob
	led = _box(Vector3(0.008, 0.008, 0.008), Vector3(0.0, 0.134, -0.006), ArtPalette.flat(Color(0.2, 0.05, 0.05)))
	_refresh()


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func set_transmitting(value: bool) -> void:
	transmitting = value
	_refresh()


func set_receiving(value: bool) -> void:
	receiving = value
	_refresh()


func _process(delta: float) -> void:
	if not receiving or transmitting:
		return
	_blink += delta
	led.visible = fmod(_blink, 0.5) < 0.3


func _refresh() -> void:
	led.visible = true
	if transmitting:
		led.material_override = ArtPalette.glow(Color(1.0, 0.15, 0.1), 4.0)
	elif receiving:
		led.material_override = ArtPalette.glow(Color(0.2, 1.0, 0.3), 4.0)
	else:
		led.material_override = ArtPalette.flat(Color(0.2, 0.05, 0.05))
