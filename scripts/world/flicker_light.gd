class_name FlickerLight
extends Node
## Makes a light flicker like a dying fluorescent tube, and sound like one: a
## ballast buzz while it's on, a crackle each time it catches. Switched off (the
## lights table says so), it goes quiet.

var light: Light3D
var base_energy := 1.0
var intensity := 0.15
## How many times it has crackled (tests).
var crackles := 0
var _t := 0.0
var _next := 0.0
var _buzz: AudioStreamPlayer3D


static func attach(target: Light3D, flicker_intensity: float = 0.15) -> FlickerLight:
	var f := FlickerLight.new()
	f.light = target
	f.base_energy = target.light_energy
	f.intensity = flicker_intensity
	f._buzz = Sfx.loop(target, "fluorescent_buzz", Vector3.ZERO)
	target.add_child(f)
	return f


func _notification(what: int) -> void:
	# The buzz hangs on the light, not on this: a mended tube goes quiet.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_buzz):
		_buzz.queue_free()


func _process(delta: float) -> void:
	var on := light.is_visible_in_tree()
	if is_instance_valid(_buzz) and _buzz.playing != on:
		if on:
			_buzz.play(randf() * _buzz.stream.get_length())
		else:
			_buzz.stop()
	_t += delta
	if _t < _next:
		return
	_t = 0.0
	if randf() < intensity:
		light.light_energy = base_energy * randf_range(0.0, 0.4)
		_next = randf_range(0.03, 0.12)
		if on and light.light_energy < base_energy * 0.2:
			crackles += 1
			Sfx.play(light, "flicker", Vector3.ZERO)
	else:
		light.light_energy = base_energy
		_next = randf_range(0.2, 2.0)
