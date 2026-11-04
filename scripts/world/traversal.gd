class_name Traversal
extends RefCounted
## Greybox helpers for movement routes: vents, low gates, climbables and narrow
## ledges. Solids go under `parent` (pass `LevelBase.geo`) like any Greybox box.

const DUCT := Color(0.42, 0.44, 0.46)
const RUST := Color(0.45, 0.3, 0.22)
const CONCRETE := Color(0.5, 0.49, 0.46)


## A straight, axis-aligned vent duct from `from` to `to` (points on the duct
## floor). Inside is `inner.x` wide and `inner.y` tall, so players must crouch.
## A metre tall fits the largest crew member crawling (CrewBody); keep it at least that.
## Returns the crawl volume.
static func vent(parent: Node, from: Vector3, to: Vector3, inner := Vector2(1.0, 1.0)) -> MovementVolume:
	var along := to - from
	assert(is_zero_approx(along.y) and (is_zero_approx(along.x) or is_zero_approx(along.z)), "vents run along X or Z")
	var along_x := absf(along.x) > absf(along.z)
	var length := along.length()
	var mid := (from + to) / 2.0
	var t := 0.08
	var w := inner.x
	var h := inner.y
	var size_floor := Vector3(length, t, w + 2 * t) if along_x else Vector3(w + 2 * t, t, length)
	# Floor top sits 1 cm proud of `from` so it never z-fights a room floor under it.
	Greybox.box(parent, mid + Vector3(0, -t / 2 + 0.01, 0), size_floor, DUCT, "VentFloor")
	Greybox.box(parent, mid + Vector3(0, h + t / 2, 0), size_floor, DUCT, "VentTop")
	var side := Vector3(0, 0, w / 2 + t / 2) if along_x else Vector3(w / 2 + t / 2, 0, 0)
	var size_side := Vector3(length, h, t) if along_x else Vector3(t, h, length)
	for s in [-1, 1]:
		Greybox.box(parent, mid + side * s + Vector3(0, h / 2, 0), size_side, DUCT, "VentSide")
	var inside := Vector3(length, h, w) if along_x else Vector3(w, h, length)
	return MovementVolume.create(parent, mid + Vector3(0, h / 2, 0), inside, MovementVolume.Kind.VENT)


## A jammed shutter or broken gate across an opening: solid from `gap` up to
## `height`, so you can only slide, crouch or roll under it.
static func gate(parent: Node, center: Vector3, width: float, gap: float = 1.0, height: float = 3.0, along_x: bool = true) -> StaticBody3D:
	var size := Vector3(width, height - gap, 0.12) if along_x else Vector3(0.12, height - gap, width)
	return Greybox.box(parent, center + Vector3(0, gap + (height - gap) / 2, 0), size, RUST, "Gate")


## Something to climb (a pipe, ladder, shelf face or cable) running up a wall
## from `bottom` to `top`. `out` points away from the wall toward the climber.
static func climbable(parent: Node, bottom: Vector3, top: Vector3, out: Vector3, width: float = 0.7) -> MovementVolume:
	out = Vector3(out.x, 0, out.z).normalized()
	var height := top.y - bottom.y
	var across := out.cross(Vector3.UP).abs()
	var pipe_size := across * 0.12 + Vector3.UP * height + out.abs() * 0.12
	Greybox.box(parent, bottom + out * 0.06 + Vector3.UP * height / 2, pipe_size, RUST, "Climbable")
	var vol_size := across * width + Vector3.UP * (height + 0.4) + out.abs() * 0.9
	var v := MovementVolume.create(parent, bottom + out * 0.55 + Vector3.UP * (height + 0.4) / 2, vol_size, MovementVolume.Kind.CLIMB)
	v.a = bottom
	v.b = top
	v.normal = out
	return v


## A narrow ledge along a wall from `a` to `b` (points on the ledge top, on the
## wall's face). `out` points away from the wall, over the drop.
static func ledge(parent: Node, a: Vector3, b: Vector3, out: Vector3, depth: float = 0.45) -> MovementVolume:
	out = Vector3(out.x, 0, out.z).normalized()
	var mid := (a + b) / 2.0
	var length := a.distance_to(b)
	var along := (b - a).normalized().abs()
	var size := along * length + Vector3.UP * 0.2 + out.abs() * depth
	Greybox.box(parent, mid + out * depth / 2 + Vector3.DOWN * 0.1, size, CONCRETE, "Ledge")
	var vol := MovementVolume.create(parent, mid + out * depth / 2 + Vector3.UP * 0.9, along * length + Vector3.UP * 1.8 + out.abs() * depth, MovementVolume.Kind.LEDGE)
	# Back flat to the wall: the walk line sits just one body radius out.
	vol.a = a + out * 0.34
	vol.b = b + out * 0.34
	vol.normal = out
	return vol
