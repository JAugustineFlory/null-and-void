class_name ArtElevator
extends Node3D
## The elevator at the end of every level from Level 1 on: a brushed-steel car
## with center-opening doors, a button panel, a handrail, a ceiling light and a
## floor indicator above the doors inside and out. Visual only: the mechanics
## (who is inside, the button, the checkpoint) own the collision and drive this
## through `open_amount`, `set_floor()`, `set_direction()` and `light_button()`.
##
##   var lift := ArtElevator.build(dressing, Vector3(0, 0, -12), 0.0)
##   lift.open_amount = 1.0         # 0 shut .. 1 fully open; tween it
##   lift.set_floor("B2"); lift.set_direction(-1)
##
## The car's origin is the middle of its doorway at floor level. It faces -Z:
## you walk in along +Z. Interior is `size` (width, height, depth). The landing
## face sits on the corridor side of a Greybox wall centered on z = 0 (front
## face at z = -0.1), so put the origin on the wall's center line.

const FRAME := Color(0.6, 0.62, 0.64)
const DIGITS := Color(1.0, 0.45, 0.1)  # amber LED segments
## Where the landing wall's corridor face is: Greybox walls are 0.2 thick, centered.
const LANDING := -0.1
## The car's front wall stands just inside the landing wall's other face (z = +0.1),
## so nothing on it shares a plane with the wall and flickers through it.
const CAR_FRONT := 0.12
const CAR_FACE := CAR_FRONT + 0.02  # its inside face

var size := Vector3(2.6, 2.5, 2.2)
## 0 = doors shut, 1 = fully open. Each leaf slides behind the jamb.
var open_amount := 0.0:
	set(v):
		open_amount = clampf(v, 0.0, 1.0)
		_place_doors()

var _doors: Array[Node3D] = []  # the two door leaves
var _door_w := 0.55
var _indicators: Array[Label3D] = []
var _arrows: Array[Label3D] = []
var _buttons: Array[MeshInstance3D] = []
var _call_button: MeshInstance3D
var _ceiling_light: OmniLight3D
var _floor_text := ""


## Builds an elevator under `parent`. `floors` labels the car's buttons, top first.
static func build(parent: Node, pos: Vector3, facing_deg: float = 0.0, interior := Vector3(2.6, 2.5, 2.2), floors: Array = ["3", "2", "1", "B1", "B2"]) -> ArtElevator:
	var e := ArtElevator.new()
	e.name = "Elevator"
	e.size = interior
	e.position = pos
	e.rotation_degrees.y = facing_deg
	parent.add_child(e)
	e._build(floors)
	return e


func _build(floors: Array) -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	var steel := ArtPalette.surface("metal", Color(1.05, 1.05, 1.08))
	var dark := ArtPalette.surface("dark_plastic")
	var frame := ArtPalette.flat(FRAME, 0.35, 0.8)
	var door_h := 2.1
	_door_w = minf(1.2, w * 0.5) / 2.0 + 0.02  # each leaf, a 1.2 m doorway
	var opening := _door_w * 2.0 - 0.04
	# Car shell: floor, ceiling, back and side walls, front wall around the doorway.
	_box(Vector3(w + 0.1, 0.06, d), Vector3(0, -0.03, d / 2), ArtPalette.flat(Color(0.16, 0.16, 0.17), 0.95))  # rubber floor
	_box(Vector3(w, 0.05, d), Vector3(0, h + 0.025, d / 2), steel)
	_box(Vector3(w, h, 0.05), Vector3(0, h / 2, d), steel)
	for sx in [-1, 1]:
		_box(Vector3(0.05, h, d), Vector3(sx * w / 2, h / 2, d / 2), steel)
		var jamb := (w - opening) / 2.0
		_box(Vector3(jamb, h, 0.04), Vector3(sx * (opening / 2 + jamb / 2), h / 2, CAR_FRONT), steel)
	_box(Vector3(opening, h - door_h, 0.04), Vector3(0, door_h + (h - door_h) / 2, CAR_FRONT), steel)
	# Wood-trim handrail on three walls (a nice building, once).
	var rail := ArtPalette.surface("laminate")
	_box(Vector3(w - 0.2, 0.05, 0.05), Vector3(0, 0.95, d - 0.07), rail)
	for sx in [-1, 1]:
		_box(Vector3(0.05, 0.05, d - 0.4), Vector3(sx * (w / 2 - 0.07), 0.95, d / 2 + 0.1), rail)
	# Ceiling light panel and its light (shadowless, like every ceiling light).
	_box(Vector3(w * 0.6, 0.02, d * 0.5), Vector3(0, h - 0.01, d / 2), ArtPalette.glow(ArtPalette.LIGHT_WARM, 1.6))
	_ceiling_light = OmniLight3D.new()
	_ceiling_light.name = "CarLight"
	_ceiling_light.light_color = ArtPalette.LIGHT_WARM
	_ceiling_light.light_energy = 0.9
	_ceiling_light.omni_range = maxf(w, d) + 1.0
	_ceiling_light.position = Vector3(0, h - 0.25, d / 2)
	add_child(_ceiling_light)
	# Landing face: a steel surround with a pocket behind it that the doors slide into.
	# It stands just proud of a 20 cm Greybox wall centered on z = 0 (LANDING).
	var face_side := _door_w + 0.1
	for sx in [-1, 1]:
		_box(Vector3(face_side, door_h + 0.5, 0.02), Vector3(sx * (opening / 2 + face_side / 2), (door_h + 0.5) / 2, LANDING - 0.04), steel)
		_box(Vector3(0.08, door_h + 0.08, 0.03), Vector3(sx * (opening / 2 + 0.04), (door_h + 0.08) / 2, LANDING - 0.065), frame)
	_box(Vector3(opening, 0.5, 0.02), Vector3(0, door_h + 0.25, LANDING - 0.04), steel)
	_box(Vector3(opening + 0.16, 0.08, 0.03), Vector3(0, door_h + 0.04, LANDING - 0.065), frame)
	_box(Vector3(opening + 0.1, 0.02, 0.3), Vector3(0, 0.01, LANDING / 2 - 0.02), frame)  # sill
	# One pair of center-opening doors, between the landing face and the car's front wall.
	for side in [-1, 1]:
		var leaf := Node3D.new()
		leaf.name = "DoorL" if side < 0 else "DoorR"
		leaf.set_meta("side", side)
		add_child(leaf)
		_piece(leaf, Vector3(_door_w, door_h, 0.03), Vector3.ZERO, steel, true)
		_piece(leaf, Vector3(0.012, door_h - 0.1, 0.034), Vector3(-side * (_door_w / 2 - 0.006), 0, 0), dark)  # rubber edge
		_doors.append(leaf)
	# Floor indicators: above the landing frame, and above the doors inside.
	for inside in [false, true]:
		var z := CAR_FACE + 0.01 if inside else LANDING - 0.06
		var y := door_h + 0.24
		var mirror := 1.0 if inside else -1.0  # outside text reads from the other side
		var dz := 0.012 if inside else -0.012
		_piece(self, Vector3(0.42, 0.16, 0.02), Vector3(0, y, z), dark)
		var digits := _label("", 64, Vector3(-0.04 * mirror, y, z + dz), inside)
		digits.modulate = DIGITS
		_indicators.append(digits)
		var arrow := _label("", 56, Vector3(0.13 * mirror, y, z + dz), inside)
		arrow.modulate = DIGITS
		_arrows.append(arrow)
	# Car operating panel, inside to the right of the doors as you face out.
	var px := -(w / 2 - 0.04)
	var panel := Node3D.new()
	panel.name = "ButtonPanel"
	panel.position = Vector3(opening / 2 + 0.25, 1.2, CAR_FACE + 0.008) if (w - opening) / 2 > 0.4 else Vector3(px, 1.2, 0.5)
	panel.rotation_degrees.y = 180 if (w - opening) / 2 > 0.4 else -90
	add_child(panel)
	var n := floors.size()
	var ph := 0.16 + n * 0.09 + 0.1
	_piece(panel, Vector3(0.24, ph, 0.015), Vector3(0, ph / 2 - 0.3, 0), frame)
	for i in n:
		var by := -0.04 + (n - 1 - i) * 0.09
		var b := _piece(panel, Vector3(0.05, 0.05, 0.015), Vector3(0.04, by, -0.012), _button_mat(false))
		b.name = "Button_%s" % floors[i]
		_buttons.append(b)
		var l := _label(str(floors[i]), 44, Vector3(-0.045, by, -0.012), false, panel)
		l.modulate = Color(0.1, 0.1, 0.12)
	# Door-open and door-close under the floors.
	var oy := -0.22
	_label("<|>", 28, Vector3(-0.06, oy, -0.012), false, panel).modulate = Color(0.1, 0.1, 0.12)
	_label(">|<", 28, Vector3(0.06, oy, -0.012), false, panel).modulate = Color(0.1, 0.1, 0.12)
	# Call button beside the landing door.
	var call := Node3D.new()
	call.name = "CallPanel"
	call.position = Vector3(opening / 2 + 0.35, 1.1, LANDING - 0.057)
	add_child(call)
	_piece(call, Vector3(0.12, 0.2, 0.012), Vector3.ZERO, frame)
	_call_button = _piece(call, Vector3(0.05, 0.05, 0.012), Vector3(0, 0, -0.01), _button_mat(false))
	_call_button.name = "CallButton"
	set_floor(str(floors[0]) if floors.size() > 0 else "1")
	_place_doors()


## What the floor indicators show, e.g. "B2". Keep it to two or three characters.
func set_floor(text: String) -> void:
	_floor_text = text
	for l in _indicators:
		l.text = text


func get_floor() -> String:
	return _floor_text


## -1 going down, 1 going up, 0 stopped.
func set_direction(dir: int) -> void:
	for a in _arrows:
		a.text = "" if dir == 0 else ("^" if dir > 0 else "v")


## Lights (or clears) a floor button, by its label.
func light_button(floor_label: String, lit: bool = true) -> void:
	for b in _buttons:
		if b.name == "Button_%s" % floor_label:
			b.material_override = _button_mat(lit)


func is_button_lit(floor_label: String) -> bool:
	for b in _buttons:
		if b.name == "Button_%s" % floor_label:
			return b.material_override == _button_mat(true)
	return false


## The call button outside: lit while the car is on its way.
func light_call(lit: bool = true) -> void:
	_call_button.material_override = _button_mat(lit)


## Dims the car light, or kills it (a power cut mid-ride).
func set_car_light(energy_scale: float) -> void:
	_ceiling_light.visible = energy_scale > 0.01
	_ceiling_light.light_energy = 0.9 * energy_scale


## Door leaves in elevator space: where each one is now (tests and mechanics).
func door_offsets() -> Array[float]:
	var out: Array[float] = []
	for leaf in _doors:
		out.append(leaf.position.x)
	return out


func _place_doors() -> void:
	for leaf in _doors:
		var side: int = leaf.get_meta("side")
		var shut_x := side * _door_w / 2.0
		leaf.position = Vector3(shut_x + side * open_amount * (_door_w - 0.04), 1.05, 0.005)


static var _button_mats := {}


static func _button_mat(lit: bool) -> Material:
	if not _button_mats.has(lit):
		_button_mats[lit] = ArtPalette.glow(Color(1.0, 0.75, 0.35), 2.2) if lit else ArtPalette.flat(Color(0.82, 0.82, 0.8), 0.4, 0.3)
	return _button_mats[lit]


func _label(text: String, font_size: int, pos: Vector3, inside: bool, parent: Node = self) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.0015
	l.outline_size = 0
	l.position = pos
	l.double_sided = false
	l.shaded = false
	# Label3D reads along +Z; landing-side text faces -Z (out to the landing).
	if not inside:
		l.rotation_degrees.y = 180
	parent.add_child(l)
	return l


func _box(box_size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	return _piece(self, box_size, pos, mat, box_size.length() > 1.5)


static func _piece(parent: Node, box_size: Vector3, pos: Vector3, mat: Material, shadow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
