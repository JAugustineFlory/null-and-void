class_name ByteRightVan
extends AnimatableBody3D
## The crew's Byte-Right IT van as one node that can move: drive it up, park it,
## drive it off with everyone in it. It's the same van as the dressed greybox
## vans (DressVan draws the details for both), built whole: a hollow body you can
## stand in with its own collision, two hinged front doors, a sliding side door,
## the equipment rack, a dome light, headlights and six seats.
##
##   var van := ByteRightVan.build(level, Transform3D(Basis(), Vector3(2, 0, 16.6)))
##   van.seat(0)              # the driver's spot; 1 is the passenger, 2-5 the rear bench left to right
##   van.open_door("slide")   # "driver", "passenger" or "slide"; close_door() shuts it
##   van.roll(metres)         # turn the wheels for a move that far (forward is +)
##   van.headlights(true)
##
## The origin is the van's middle at ground level, nose to -Z. Move it like any
## node (a Tween on `global_transform`): it's an AnimatableBody3D synced to
## physics, so whoever stands in it rides along. Keep it out of LevelBase.geo so
## navigation never bakes it.

## The cabin floor's height above the ground.
const FLOOR := 0.5
## The seats in order, at floor level (driver first, on the left; the rear bench
## left to right). Seat nodes sit 0.05 above these, where a strapped-in player stands.
const SEATS := [Vector3(-0.55, 0, -1.3), Vector3(0.55, 0, -1.3), Vector3(-0.99, 0, 0.7),
	Vector3(-0.33, 0, 0.7), Vector3(0.33, 0, 0.7), Vector3(0.99, 0, 0.7)]
## A seat cushion's top above its Seat node, for sitting someone on it.
const CUSHION := 0.46
const WHEEL_RADIUS := 0.34
const SIZE := Vector3(2.6, 2.1, 4.4)  # the cabin, inside the walls' middles

## Which side the sliding door is on: 1 is the right (kerb) side, -1 the left.
var slide_side := 1.0
## "driver", "passenger", "slide" -> the door's moving node.
var doors := {}
var _shut := {}
var _paint: Material


## Build the van under `parent` at `at` (set before it enters the tree, so it
## never sits at the origin for a physics step).
static func build(parent: Node, at: Transform3D, slide := 1.0) -> ByteRightVan:
	var van := ByteRightVan.new()
	van.name = "ByteRightVan"
	van.slide_side = slide
	van.transform = at
	van._build()
	parent.add_child(van, true)
	return van


## Seat `i`'s node (Seat0..Seat5), facing forward.
func seat(i: int) -> Node3D:
	return get_node("Seat%d" % clampi(i, 0, SEATS.size() - 1))


## Swing a front door out on its hinge, or slide the side door back. Returns the tween.
func open_door(which: String, seconds := 0.6) -> Tween:
	return _move_door(which, true, seconds)


func close_door(which: String, seconds := 0.6) -> Tween:
	return _move_door(which, false, seconds)


## Turn the wheels as for driving `metres` (negative reverses).
func roll(metres: float) -> void:
	for i in 4:
		var w := get_node_or_null("Wheel%d" % i) as Node3D
		if w:
			w.rotation.x -= metres / WHEEL_RADIUS


func headlights(on: bool) -> void:
	for l in find_children("Headlight*", "SpotLight3D", false, false):
		(l as SpotLight3D).visible = on


func _build() -> void:
	sync_to_physics = true
	_paint = ArtPalette.flat(DressVan.PAINT, 0.35, 0.15)
	var mat := ArtPalette.surface("dark_plastic")  # ribbed rubber mat
	var half := SIZE / 2
	var t := 0.2
	var top := FLOOR + SIZE.y
	# The shell: floor, roof, chassis and bonnet, the back and the front under and
	# over the windscreen (whose glass is solid).
	_solid(Vector3(0, FLOOR - t / 2, 0), Vector3(SIZE.x, t, SIZE.z), mat)
	_solid(Vector3(0, top + t / 2, 0), Vector3(SIZE.x, t, SIZE.z), _paint)
	_solid(Vector3(0, 0.2, 0), Vector3(2.7, 0.2, 4.7), ArtPalette.flat(Color(0.12, 0.12, 0.13), 0.6, 0.2))
	_solid(Vector3(0, 0.95, -half.z - 0.45), Vector3(2.6, 0.9, 0.9), _paint)
	_solid(Vector3(0, FLOOR + SIZE.y / 2, half.z), Vector3(SIZE.x, SIZE.y, t), _paint)
	_solid(Vector3(0, FLOOR + 0.425, -half.z), Vector3(SIZE.x, 0.85, t), _paint)
	_solid(Vector3(0, top - 0.075, -half.z), Vector3(SIZE.x, 0.15, t), _paint)
	for sx in [-1.0, 1.0]:
		_solid(Vector3(sx * 1.225, FLOOR + 1.4, -half.z), Vector3(0.15, 1.1, t), _paint)  # the pillars
	_solid(Vector3(0, FLOOR + 1.4, -half.z), Vector3(2.3, 1.1, 0.06), null)  # the glass (DressVan draws it)
	# The sides, round their door openings: front doors at z -1.95..-1.05 both
	# sides, the sliding door at -0.55..0.75 on its side. Lintels over each.
	for sx in [-1.0, 1.0]:
		var spans := [[-half.z, -1.95], [-1.05, -0.55], [0.75, half.z]] if sx == slide_side else [[-half.z, -1.95], [-1.05, half.z]]
		for s in spans:
			_solid(Vector3(sx * half.x, FLOOR + SIZE.y / 2, (s[0] + s[1]) / 2), Vector3(t, SIZE.y, s[1] - s[0]), _paint)
		var gaps := [[-1.95, -1.05], [-0.55, 0.75]] if sx == slide_side else [[-1.95, -1.05]]
		for g in gaps:
			_solid(Vector3(sx * half.x, FLOOR + 2.0, (g[0] + g[1]) / 2), Vector3(t, 0.2, g[1] - g[0]), _paint)
	# The equipment rack against the back, and the dome light.
	_solid(Vector3(-0.6, FLOOR + 0.6, 1.85), Vector3(1.0, 1.2, 0.6), ArtPalette.surface("metal"))
	var dome := OmniLight3D.new()
	dome.name = "DomeLight"
	dome.position = Vector3(0, FLOOR + 1.9, 0)
	dome.omni_range = 3.5
	dome.light_energy = 0.6
	dome.light_color = Color(1.0, 0.9, 0.7)
	add_child(dome)
	# The doors.
	for side in [-1.0, 1.0]:
		var which := "driver" if side < 0 else "passenger"
		var pivot := Node3D.new()
		pivot.name = which.capitalize() + "Door"
		pivot.position = Vector3(side * half.x, FLOOR, -1.95)
		add_child(pivot)
		var door := _door(pivot, Vector3(0, 0.95, 0.45), Vector3(0.1, 1.9, 0.9))
		ArtDress.trim(door, Vector3(side * 0.06, 0.0, 0.32), Vector3(0.02, 0.04, 0.12), ArtPalette.flat(Color(0.72, 0.73, 0.75), 0.25, 0.9))
		doors[which] = pivot
		_shut[which] = pivot.transform
	var slider := Node3D.new()
	slider.name = "SlideDoor"
	slider.position = Vector3(slide_side * half.x, FLOOR, 0.1)
	add_child(slider)
	_door(slider, Vector3(0, 0.95, 0), Vector3(0.1, 1.9, 1.3))
	doors["slide"] = slider
	_shut["slide"] = slider.transform
	# The livery: the company line along the driver's side, the name behind the sliding door.
	var blue := ArtPalette.BYTERIGHT_BLUE
	Greybox.label(self, Vector3(-slide_side * (half.x + 0.12), 1.7, 0.4), "BYTE-RIGHT IT SERVICES\nWe fix what's broken.", 60, blue, -90.0 * slide_side)
	Greybox.label(self, Vector3(slide_side * (half.x + 0.12), 1.7, 1.5), "BYTE-RIGHT\nIT SERVICES", 50, blue, 90.0 * slide_side)
	for sx in [-1.0, 1.0]:
		var lamp := SpotLight3D.new()
		lamp.name = "Headlight%s" % ("L" if sx < 0 else "R")
		lamp.position = Vector3(sx * 0.95, 0.98, -half.z - 0.95)
		lamp.light_color = Color(1.0, 0.95, 0.8)
		lamp.light_energy = 3.0
		lamp.spot_range = 16.0
		lamp.spot_angle = 28.0
		lamp.visible = false
		add_child(lamp)
		lamp.rotation.x = -0.08  # dipped
	for i in SEATS.size():
		var s := Node3D.new()
		s.name = "Seat%d" % i
		s.position = SEATS[i] + Vector3(0, FLOOR + 0.05, 0)
		add_child(s)
	var wheels: Array[Vector3] = []
	for dz in [-1.7, 1.5]:
		for dx in [-1.15, 1.15]:
			wheels.append(Vector3(dx, 0.25, dz))
	DressVan.details(self, slide_side, wheels, false, slider)


## A box of the body: its collider, and its look unless `mat` is null.
func _solid(center: Vector3, size: Vector3, mat: Material) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	add_child(shape)
	if mat:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		mi.position = center
		add_child(mi)


## A door panel on `holder` (it moves with it): its own body, painted.
func _door(holder: Node3D, center: Vector3, size: Vector3) -> AnimatableBody3D:
	var door := AnimatableBody3D.new()
	door.name = "Panel"
	door.position = center
	holder.add_child(door)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	door.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _paint
	door.add_child(mi)
	return door


func _move_door(which: String, open: bool, seconds: float) -> Tween:
	var door: Node3D = doors.get(which)
	if door == null:
		return null
	var to: Transform3D = _shut[which]
	if open:
		if which == "slide":
			to.origin += Vector3(slide_side * 0.16, 0, 1.35)  # out from the side, then back along it
		else:
			to = to.rotated_local(Vector3.UP, deg_to_rad(80.0) * signf(to.origin.x))
	var tw := create_tween()
	tw.tween_property(door, "transform", to, seconds).set_trans(Tween.TRANS_SINE)
	return tw
