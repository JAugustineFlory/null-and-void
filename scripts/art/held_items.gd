class_name HeldItems
extends Node3D
## What you see in your own hands in first person: the flashlight in your right
## hand, and the walkie-talkie that comes up in your left while you talk. It
## sways when you turn and bobs when you walk. Attach it to the player's camera:
##
##   var held := HeldItems.attach(player.camera, CharacterLooks.crew(0))
##   held.flashlight.toggle()
##   held.raise_walkie(true)   # while push-to-talk is held

const REST_RIGHT := Vector3(0.24, -0.24, -0.5)
const REST_LEFT_DOWN := Vector3(-0.22, -0.5, -0.32)
const REST_LEFT_UP := Vector3(-0.13, -0.13, -0.3)

var flashlight: PropFlashlight
var walkie: PropWalkie
var right_hand: Node3D
var left_hand: Node3D
var walkie_up := false

var _camera: Camera3D
var _last_basis := Basis.IDENTITY
var _sway := Vector2.ZERO
var _bob := 0.0
var _last_pos := Vector3.ZERO
var _left_t := 0.0


static func attach(camera: Camera3D, look: Dictionary = {}) -> HeldItems:
	var h := HeldItems.new()
	h.name = "HeldItems"
	h._camera = camera
	h._make(look)
	camera.add_child(h)
	return h


func _make(look_in: Dictionary) -> void:
	var look := CharacterLooks.base()
	look.merge(look_in, true)
	var skin := ArtPalette.flat(look.skin, 0.7)
	var sleeve := ArtPalette.flat(look.jacket if look.jacket is Color else look.shirt, 0.9)
	right_hand = Node3D.new()
	right_hand.position = REST_RIGHT
	add_child(right_hand)
	_arm(right_hand, skin, sleeve)
	flashlight = PropFlashlight.create(right_hand, true)
	flashlight.position = Vector3(0, 0.0, -0.03)

	left_hand = Node3D.new()
	left_hand.position = REST_LEFT_DOWN
	left_hand.visible = false
	add_child(left_hand)
	_arm(left_hand, skin, sleeve)
	walkie = PropWalkie.create(left_hand)
	walkie.position = Vector3(0, -0.02, -0.03)
	walkie.rotation_degrees = Vector3(10, 25, 0)


func _arm(hand: Node3D, skin: Material, sleeve: Material) -> void:
	var fist := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.055, 0.075)
	fist.mesh = bm
	fist.material_override = skin
	fist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand.add_child(fist)
	var arm := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.032
	cm.height = 0.4
	arm.mesh = cm
	# The forearm runs back and down out of the bottom corner of the screen.
	arm.rotation = Vector3(PI / 2 - 0.7, 0, 0)
	arm.position = Vector3(0, -0.11, 0.16)
	arm.material_override = sleeve
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand.add_child(arm)


func raise_walkie(up: bool) -> void:
	walkie_up = up
	walkie.set_transmitting(up)
	if up:
		left_hand.visible = true


func _process(delta: float) -> void:
	if not _camera:
		return
	# Sway: the hands lag a little behind the turn.
	var b := _camera.global_transform.basis
	var turn := Vector2(
		_last_basis.z.cross(b.z).dot(b.y),
		_last_basis.z.cross(b.z).dot(b.x))
	_last_basis = b
	_sway = _sway.lerp(Vector2(clampf(turn.x * 2.5, -0.05, 0.05), clampf(turn.y * 2.5, -0.05, 0.05)), 1.0 - exp(-10.0 * delta))
	# Bob: follows walking speed.
	var p := _camera.global_position
	var flat := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length() / maxf(delta, 0.0001)
	_last_pos = p
	if flat > 20.0:
		flat = 0.0
	var walk := clampf(flat / 4.0, 0.0, 1.5)
	_bob += delta * (6.0 + 4.0 * walk) * (1.0 if walk > 0.05 else 0.3)
	var bob := Vector3(cos(_bob) * 0.008, -absf(sin(_bob)) * 0.012, 0.0) * (0.3 + walk)
	right_hand.position = REST_RIGHT + Vector3(-_sway.x, -_sway.y, 0) + bob
	# The walkie comes up to the mouth, and goes back down out of view.
	_left_t = move_toward(_left_t, 1.0 if walkie_up else 0.0, delta * 5.0)
	var e := ease(_left_t, -2.0)
	left_hand.position = REST_LEFT_DOWN.lerp(REST_LEFT_UP, e) + Vector3(-_sway.x, -_sway.y, 0) + bob * 0.6
	left_hand.visible = _left_t > 0.01
