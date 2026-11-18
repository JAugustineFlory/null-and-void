class_name Echo
extends Node3D
## One of the ones who never left (Level 6, B1): a member of staff whose cold-store
## entry never closed, held at their row as a flickering figure. They loop their
## last moment, whisper when someone comes close, and watch. They never touch or
## block anyone: no collision at all. Once their entry is punched out they play
## their story, brighten, and fade, leaving what they kept behind.
##
## The level decides everything (when a punch frees them) through sync.event, so
## every machine plays the same echo at the same moment; nothing here is synced.

signal whispered(echo: Echo)

## How close a player has to be to hear the whisper, and how often it repeats.
const HEAR := 3.2
const WHISPER_EVERY := 24.0
const HEIGHT := 1.7
const COLOR := Color(0.62, 0.82, 1.0)

var echo_id := ""
var echo_name := ""
## "bound" at the row, "releasing" while the story plays, "free" once gone.
var state := "bound"
## Seconds until it can whisper again.
var _cooldown := 0.0
var _t := 0.0
var _parts: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _fade := 1.0
## A seeded phase, so the six don't flicker in step.
var phase := 0.0


static func make(parent: Node, id: String, display_name: String, pos: Vector3, facing_deg: float, seed_phase := 0.0) -> Echo:
	var e := Echo.new()
	e.name = "Echo_" + id
	e.echo_id = id
	e.echo_name = display_name
	e.phase = seed_phase
	e.position = pos
	e.rotation_degrees.y = facing_deg
	parent.add_child(e)
	return e


func _ready() -> void:
	add_to_group("echo")
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(COLOR, 0.35)
	_mat.emission_enabled = true
	_mat.emission = COLOR
	_mat.emission_energy_multiplier = 0.6
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# A standing figure, head a little bowed, as if looking at a shelf.
	_part(CapsuleMesh.new(), Vector3(0, 1.1, 0), Vector3(0.42, 0.5, 0.28))
	for side in [-1, 1]:
		_part(CapsuleMesh.new(), Vector3(side * 0.11, 0.42, 0), Vector3(0.14, 0.44, 0.14))
		_part(CapsuleMesh.new(), Vector3(side * 0.27, 1.08, -0.05), Vector3(0.09, 0.38, 0.09))
	var head := _part(SphereMesh.new(), Vector3(0, 1.57, -0.04), Vector3(0.22, 0.24, 0.22))
	head.rotation_degrees.x = 12.0
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = 2.2
	_light.light_energy = 0.25
	_light.position = Vector3(0, 1.3, 0)
	add_child(_light)


func _part(mesh: PrimitiveMesh, pos: Vector3, scale_v: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_parts.append(mi)
	return mi


## Every machine: the punch went through. Brighter while the story plays.
func begin_release() -> void:
	if state != "bound":
		return
	state = "releasing"


## Every machine: the story is over. It fades and is gone.
func set_free() -> void:
	if state == "free":
		return
	state = "free"
	var tw := create_tween()
	tw.tween_property(self, "_fade", 0.0, 3.0)
	tw.tween_callback(func(): visible = false)


func is_bound() -> bool:
	return state == "bound"


func _process(delta: float) -> void:
	_t += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	# The flicker: mostly there, now and then nearly gone, never steady.
	var f := 0.55 + 0.25 * sin(_t * 1.7 + phase) + 0.15 * sin(_t * 11.0 + phase * 3.0)
	if fmod(_t + phase, 7.3) < 0.18:
		f *= 0.2
	var a := 0.35
	if state == "releasing":
		a = 0.6
		f = 0.85 + 0.15 * sin(_t * 3.0)
	_mat.albedo_color.a = clampf(a * f, 0.0, 1.0) * _fade
	_light.light_energy = (0.25 if state == "bound" else 0.8) * f * _fade
	# The loop: a small reach to the shelf and back, over and over.
	if _parts.size() > 4:
		_parts[4].rotation_degrees.x = -30.0 * maxf(0.0, sin(_t * 0.9 + phase))
	if state == "bound" and _cooldown <= 0.0 and _near_player():
		_cooldown = WHISPER_EVERY
		whispered.emit(self)


## This machine's player is close enough to hear it.
func _near_player() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and p.get_viewport() == get_viewport():
			if p.global_position.distance_to(global_position) < HEAR:
				return true
	return false
