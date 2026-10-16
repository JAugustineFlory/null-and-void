class_name FlickerLight
extends Node
## Makes a light flicker like a dying fluorescent tube.

var light: Light3D
var base_energy := 1.0
var intensity := 0.15
var _t := 0.0
var _next := 0.0


static func attach(target: Light3D, flicker_intensity: float = 0.15) -> FlickerLight:
	var f := FlickerLight.new()
	f.light = target
	f.base_energy = target.light_energy
	f.intensity = flicker_intensity
	target.add_child(f)
	return f


func _process(delta: float) -> void:
	_t += delta
	if _t < _next:
		return
	_t = 0.0
	if randf() < intensity:
		light.light_energy = base_energy * randf_range(0.0, 0.4)
		_next = randf_range(0.03, 0.12)
	else:
		light.light_energy = base_energy
		_next = randf_range(0.2, 2.0)
