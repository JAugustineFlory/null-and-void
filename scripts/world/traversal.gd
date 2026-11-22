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


## E10's crawlable duct network: `runs` are [from, to] pairs, points on the duct
## floor along X or Z, one height for each level. Where a run's end meets another
## run (its side for a T, or its end for a turn), the walls open into each other
## and the outside corner closes; every other end is capped, unless it's in
## `open` (it meets a wall vent or a grille). `holes` are points on a run's centre
## line where its floor (y at the duct floor: a ceiling vent into the room below,
## or a drop) or its top (y at the duct top: a floor vent up into the room above)
## has a duct-wide square opening. At least 1.0 m tall and wide (CrewBody).
## Returns the crawl volumes. Snap points to a few centimetres so ends meet.
static func ducts(parent: Node, runs: Array, inner := Vector2(1.0, 1.0), open: Array = [], holes: Array = []) -> Array[MovementVolume]:
	var w := inner.x
	var h := inner.y
	var t := 0.08
	var rects: Array[Dictionary] = []
	for r in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		assert(absf(a.y - b.y) < 0.001 and (absf(a.x - b.x) < 0.001 or absf(a.z - b.z) < 0.001), "duct runs are level, along X or Z")
		var along_x := absf(b.x - a.x) > absf(b.z - a.z)
		var lo := a if (a.x < b.x if along_x else a.z < b.z) else b
		var hi := b if lo == a else a
		var ext := []
		for end in [lo, hi]:
			var e := 0.0
			if not _near_any(end, open):
				for other in runs:
					if other != r and _on_segment(end, other[0], other[1]):
						e = w / 2.0
			ext.append(e)
		var rect := {"y": a.y, "x": along_x, "lo": lo, "hi": hi, "open_lo": _near_any(lo, open), "open_hi": _near_any(hi, open)}
		if along_x:
			rect.merge({"x0": lo.x - ext[0], "x1": hi.x + ext[1], "z0": a.z - w / 2.0, "z1": a.z + w / 2.0})
		else:
			rect.merge({"x0": a.x - w / 2.0, "x1": a.x + w / 2.0, "z0": lo.z - ext[0], "z1": hi.z + ext[1]})
		rects.append(rect)
	var vols: Array[MovementVolume] = []
	for rect in rects:
		var y: float = rect.y
		var along_x: bool = rect.x
		# Floor and top, each split round its holes.
		for top in [false, true]:
			var cut := []
			for p: Vector3 in holes:
				var on_top := absf(p.y - (y + h)) < 0.12
				var on_floor := absf(p.y - y) < 0.05
				if (on_top if top else on_floor) and _in_rect_line(rect, p, along_x):
					var c := p.x if along_x else p.z
					cut.append(Vector2(c - w / 2.0, c + w / 2.0))
			var s0: float = rect.x0 if along_x else rect.z0
			var s1: float = rect.x1 if along_x else rect.z1
			for piece in _minus(Vector2(s0, s1), cut):
				var length: float = piece.y - piece.x
				var c: float = (piece.x + piece.y) / 2.0
				var mid := Vector3(c, 0, (rect.z0 + rect.z1) / 2.0) if along_x else Vector3((rect.x0 + rect.x1) / 2.0, 0, c)
				mid.y = y + h + t / 2.0 if top else y - t / 2.0 + 0.01
				var size := Vector3(length, t, w + 2 * t) if along_x else Vector3(w + 2 * t, t, length)
				Greybox.box(parent, mid, size, DUCT, "VentTop" if top else "VentFloor")
		# Walls wherever the outside of an edge isn't inside the duct.
		for edge in _edges(rect):
			for wall in _walls(edge, rects, y, t):
				var u0: float = wall.x
				var u1: float = wall.y
				var c: float = (u0 + u1) / 2.0
				var off: float = edge.at + edge.out * t / 2.0
				var mid := Vector3(c, y + h / 2.0, off) if edge.along_x else Vector3(off, y + h / 2.0, c)
				var size := Vector3(u1 - u0, h, t) if edge.along_x else Vector3(t, h, u1 - u0)
				Greybox.box(parent, mid, size, DUCT, "VentSide")
		var inside := Vector3(rect.x1 - rect.x0, h, rect.z1 - rect.z0)
		var centre := Vector3((rect.x0 + rect.x1) / 2.0, y + h / 2.0, (rect.z0 + rect.z1) / 2.0)
		vols.append(MovementVolume.create(parent, centre, inside, MovementVolume.Kind.VENT))
	return vols


## A drop: a shaft down from a hole in a duct's floor (`top`, the hole's middle,
## at that floor) `depth` metres, to a hole in a lower duct's top or out through a
## room's ceiling. Down is a fall. Rungs up the side `toward` (the way the upper
## duct carries on from the shaft) take you back up and out onto its floor.
## Returns the climb.
static func drop(parent: Node, top: Vector3, depth: float, toward: Vector3, inner := Vector2(1.0, 1.0)) -> MovementVolume:
	toward = Vector3(toward.x, 0, toward.z).normalized()
	var w := inner.x
	var t := 0.08
	var across := toward.cross(Vector3.UP).normalized()
	var y := top.y - depth / 2.0
	for s in [-1.0, 1.0]:
		var face := Vector3(t, depth, w + 2 * t) if absf(toward.x) > 0.5 else Vector3(w + 2 * t, depth, t)
		Greybox.box(parent, Vector3(top.x, y, top.z) + toward * s * (w / 2.0 + t / 2.0), face, DUCT, "ShaftSide")
		var side := Vector3(t, depth, w) if absf(across.x) > 0.5 else Vector3(w, depth, t)
		Greybox.box(parent, Vector3(top.x, y, top.z) + across * s * (w / 2.0 + t / 2.0), side, DUCT, "ShaftSide")
	# Rungs on the wall: looks only, so nothing in the shaft catches you as you fall.
	var wall := top + toward * (w / 2.0)
	var rung := BoxMesh.new()
	rung.size = across.abs() * 0.5 + Vector3.UP * 0.03 + toward.abs() * 0.04
	var mat := Greybox.mat(RUST)
	var ry := 0.25
	while ry < depth:
		var m := MeshInstance3D.new()
		m.name = "Rung"
		m.mesh = rung
		m.material_override = mat
		m.position = wall + Vector3.DOWN * ry - toward * 0.02
		parent.add_child(m)
		ry += 0.3
	var v := MovementVolume.create(parent, wall + Vector3.DOWN * (depth - 0.4) / 2.0 - toward * 0.55, across.abs() * 0.6 + Vector3.UP * (depth + 0.4) + toward.abs() * 0.9, MovementVolume.Kind.CLIMB)
	v.name = "ShaftRungs"
	v.a = wall + Vector3.DOWN * depth
	v.b = wall
	v.normal = -toward
	return v


static func _near_any(p: Vector3, points: Array) -> bool:
	for q: Vector3 in points:
		if p.distance_to(q) < 0.05:
			return true
	return false


## Is `p` on the segment a-b (same height, within a few centimetres)?
static func _on_segment(p: Vector3, a: Vector3, b: Vector3) -> bool:
	if absf(p.y - a.y) > 0.05:
		return false
	var ab := b - a
	var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * k) < 0.05


## Is `p` on this run's centre line, within its span?
static func _in_rect_line(rect: Dictionary, p: Vector3, along_x: bool) -> bool:
	if along_x:
		return absf(p.z - (rect.z0 + rect.z1) / 2.0) < 0.05 and p.x > rect.x0 - 0.01 and p.x < rect.x1 + 0.01
	return absf(p.x - (rect.x0 + rect.x1) / 2.0) < 0.05 and p.z > rect.z0 - 0.01 and p.z < rect.z1 + 0.01


## The span `s` (x..y) with the `cuts` taken out of it.
static func _minus(s: Vector2, cuts: Array) -> Array:
	var out := [s]
	for c: Vector2 in cuts:
		var next := []
		for piece: Vector2 in out:
			if c.y <= piece.x or c.x >= piece.y:
				next.append(piece)
				continue
			if c.x > piece.x + 0.01:
				next.append(Vector2(piece.x, c.x))
			if c.y < piece.y - 0.01:
				next.append(Vector2(c.y, piece.y))
		out = next
	return out


## A run's four edges (open ends left out): each runs along X or Z at `at`, from
## u0 to u1, with `out` (+1 or -1) the way out of the duct.
static func _edges(rect: Dictionary) -> Array:
	var e := [
		{"along_x": true, "at": rect.z0, "out": -1.0, "u0": rect.x0, "u1": rect.x1},
		{"along_x": true, "at": rect.z1, "out": 1.0, "u0": rect.x0, "u1": rect.x1},
		{"along_x": false, "at": rect.x0, "out": -1.0, "u0": rect.z0, "u1": rect.z1},
		{"along_x": false, "at": rect.x1, "out": 1.0, "u0": rect.z0, "u1": rect.z1},
	]
	# The ends: along X, the x0 / x1 edges; along Z, the z0 / z1 edges.
	var ends := [2, 3] if rect.x else [0, 1]
	var keep := []
	for i in 4:
		if i == ends[0] and rect.open_lo or i == ends[1] and rect.open_hi:
			continue
		keep.append(e[i])
	return keep


static func _inside(rects: Array, x: float, z: float, y: float) -> bool:
	for r in rects:
		if absf(r.y - y) < 0.05 and x > r.x0 and x < r.x1 and z > r.z0 and z < r.z1:
			return true
	return false


## The stretches of `edge` with no duct on its outside: walls, each grown by the
## wall's thickness at an outside corner so the corner closes.
static func _walls(edge: Dictionary, rects: Array, y: float, t: float) -> Array:
	var cuts := [edge.u0, edge.u1]
	for r in rects:
		if absf(r.y - y) > 0.05:
			continue
		for c in ([r.x0, r.x1] if edge.along_x else [r.z0, r.z1]):
			if c > edge.u0 and c < edge.u1:
				cuts.append(c)
	cuts.sort()
	var probe := func(u: float, off: float) -> bool:
		var v: float = edge.at + edge.out * off
		return _inside(rects, u, v, y) if edge.along_x else _inside(rects, v, u, y)
	var walls := []
	for i in cuts.size() - 1:
		var u0: float = cuts[i]
		var u1: float = cuts[i + 1]
		if u1 - u0 < 0.005 or probe.call((u0 + u1) / 2.0, 0.01):
			continue
		if not walls.is_empty() and absf(walls[-1].y - u0) < 0.005:
			walls[-1].y = u1
		else:
			walls.append(Vector2(u0, u1))
	for i in walls.size():
		# An outside corner: the duct stops just past this end of the wall.
		var wall: Vector2 = walls[i]
		if not probe.call(wall.x - 0.01, -0.01):
			wall.x -= t
		if not probe.call(wall.y + 0.01, -0.01):
			wall.y += t
		walls[i] = wall
	return walls


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


## A hatch in a ceiling (a lift car's roof hatch): the opening's rim is at
## `rim` (the middle of it), `size` across (x and z); `out` is where you stand
## on top once you've pulled yourself up through it. Space under it (or a jump,
## if the rim's out of reach: it catches it) takes you up. Set the volume's
## `active` false while the hatch is shut. At least 0.8 m square fits everyone.
static func hatch(parent: Node, rim: Vector3, size: Vector2, out: Vector3) -> MovementVolume:
	var v := MovementVolume.create(parent, rim + Vector3.DOWN * 1.3, Vector3(size.x, 2.6, size.y), MovementVolume.Kind.HATCH)
	v.name = "Hatch"
	v.a = rim
	v.b = out
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
