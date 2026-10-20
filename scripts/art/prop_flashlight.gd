class_name PropFlashlight
extends Node3D
## A chunky rubber flashlight with a real spot light. Points down -Z.
## Only the local player's torch should cast shadows (they are the expensive
## part); teammates' torches light the room without them.

signal toggled(is_on: bool)

const RANGE := 18.0
const ENERGY := 2.6
const ANGLE := 24.0

var on := true
var light: SpotLight3D
var lens: MeshInstance3D
var _shell: Array[MeshInstance3D] = []  # body and head: what a skin colors
## 1 = full battery, 0 = dead. Below 0.2 the beam starts to sputter.
var battery := 1.0
var _sputter := 0.0


static func create(parent: Node, cast_shadows: bool = false) -> PropFlashlight:
	var f := PropFlashlight.new()
	f.name = "Flashlight"
	f._make(cast_shadows)
	parent.add_child(f)
	return f


func _make(cast_shadows: bool) -> void:
	var rubber := ArtPalette.flat(Color(0.12, 0.12, 0.13), 0.8)
	var body := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.018
	cy.bottom_radius = 0.018
	cy.height = 0.17
	cy.radial_segments = 10
	body.mesh = cy
	body.rotation.x = PI / 2
	body.position.z = 0.02
	body.material_override = rubber
	_shell.append(body)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	var head := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.024
	hm.bottom_radius = 0.03
	hm.height = 0.05
	hm.radial_segments = 10
	head.mesh = hm
	head.rotation.x = PI / 2
	head.position.z = -0.085
	head.material_override = rubber
	_shell.append(head)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(head)
	lens = MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.026
	lm.bottom_radius = 0.026
	lm.height = 0.004
	lm.radial_segments = 10
	lens.mesh = lm
	lens.rotation.x = PI / 2
	lens.position.z = -0.111
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lens)
	light = SpotLight3D.new()
	light.position.z = -0.12
	light.spot_range = RANGE
	light.spot_angle = ANGLE
	light.spot_angle_attenuation = 0.8
	light.light_energy = ENERGY
	light.light_color = ArtPalette.LIGHT_FLASHLIGHT
	light.shadow_enabled = cast_shadows
	light.distance_fade_enabled = true
	light.distance_fade_begin = 40.0
	add_child(light)
	set_on(on)


## Recolors the rubber body and head (a player's flashlight skin). The lens and beam stay.
func set_skin(color: Color) -> void:
	var m := ArtPalette.flat(color, 0.8)
	for mi in _shell:
		mi.material_override = m


func set_on(value: bool) -> void:
	on = value
	light.visible = on and battery > 0.0
	lens.material_override = ArtPalette.glow(ArtPalette.LIGHT_FLASHLIGHT, 3.0) if light.visible else ArtPalette.flat(Color(0.5, 0.5, 0.45), 0.2)
	toggled.emit(on)


func toggle() -> void:
	set_on(not on)


func _process(delta: float) -> void:
	if not on or battery <= 0.0:
		return
	if battery >= 0.2:
		light.light_energy = ENERGY
		return
	# Low battery: dimmer, and it cuts out for a moment now and then.
	_sputter -= delta
	if _sputter <= 0.0:
		_sputter = randf_range(0.05, 0.8)
		var dim := battery / 0.2
		light.light_energy = ENERGY * dim * (0.1 if randf() < 0.25 else 1.0)
