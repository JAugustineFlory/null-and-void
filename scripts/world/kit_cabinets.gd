class_name KitCabinets
extends RefCounted
## First-aid cabinets on every floor's walls (Augustine, 2026-11-18, hard mode call
## 3): on Hard, one on a small floor and more on bigger ones; Normal has twice as
## many. Each holds one kit (FirstAidCabinet), with its own state for the run.
##
## Floors are built in code, so the cabinets find their own walls: a tall, thin box
## in the floor's geometry with walkable floor (the baked navigation) right in front
## of it, clear of doors. They're spread out from a spot picked from the run's seed,
## so every machine puts them in the same places and a walkthrough can't say where.

## Kits on Hard by walkable floor area (m², stairwells left out): one on a small
## floor, a second from SECOND_AT, a third from THIRD_AT.
const SECOND_AT := 1000.0
const THIRD_AT := 1600.0
## Where on a wall: this high, at least this far from its ends, this far apart.
const MOUNT_Y := 1.35
const END_GAP := 0.6
const STEP := 1.5
## Wall: at least this tall, at most this thick, at least this long.
const WALL_MIN_H := 2.2
const WALL_MAX_T := 0.6
const WALL_MIN_L := 1.6
## Keep this far from any door, and this far from the next cabinet.
const DOOR_GAP := 1.6
const MIN_APART := 6.0


## How many kits `level` gets: by its walkable floor area, doubled on Normal.
static func count_for(area: float, hard: bool) -> int:
	var n := 1 + int(area >= SECOND_AT) + int(area >= THIRD_AT)
	return n if hard else n * 2


## Put this floor's cabinets up. Call after its geometry and navigation are built,
## before node names are fixed. Returns the cabinets.
static func place(level: Node3D, key: String) -> Array:
	var geo: NavigationRegion3D = level.get("geo")
	if geo == null or geo.navigation_mesh == null or geo.navigation_mesh.get_polygon_count() == 0:
		return []
	var nav := floor_nav(level, geo)
	var spots := spots_in(level, geo, nav)
	if spots.is_empty():
		return []
	var g := _game()
	var hard: bool = g != null and g.get("hard_mode") == true
	var n := mini(count_for(_area(nav), hard), spots.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [key, int(g.get("run_seed")) if g else 0])
	# A floor with a storey of its own below (floor 10's ground-floor beat) shares
	# its kits out by how much floor each storey has.
	var picked := []
	var shares := _shares(nav, spots, n)
	for band in shares:
		picked.append_array(_spread(spots.filter(func(sp): return sp.band == band), shares[band], rng))
	var out := []
	for i in picked.size():
		var s: Dictionary = picked[i]
		var c := FirstAidCabinet.make(s.pos, s.facing)
		c.name = "KitCabinet%d" % (i + 1)
		c.cabinet_id = "%s:%d" % [key, i + 1]
		level.add_child(c)
		c.refresh()
		out.append(c)
	return out


static func _game() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("Game") if loop else null


## Every place a cabinet could go: {"pos": centre in level space, "facing": degrees
## turning its front (+Z) out from the wall}.
static func spots_in(level: Node3D, geo: NavigationRegion3D, nav: Array) -> Array:
	var boxes := _boxes(level, geo)
	# Anything solid on the floor, not just its walls: furniture, terminals, papers.
	var solid := _boxes(level, level)
	var doors := level.find_children("*", "Door", true, false).map(func(d): return level.to_local(d.global_position))
	var out := []
	for b in boxes:
		var size: Vector3 = b.size
		if size.y < WALL_MIN_H:
			continue
		var along_x := size.x >= size.z
		var thick := size.z if along_x else size.x
		var length := size.x if along_x else size.z
		if thick > WALL_MAX_T or length < WALL_MIN_L:
			continue
		var floor_y: float = b.center.y - size.y / 2.0
		var axis := Vector3.RIGHT if along_x else Vector3.BACK
		var count := int(floor((length - 2.0 * END_GAP) / STEP)) + 1
		for k in count:
			var t := -length / 2.0 + END_GAP + k * STEP + fmod(length - 2.0 * END_GAP, STEP) / 2.0
			for side in [-1.0, 1.0]:
				var normal: Vector3 = (Vector3.BACK if along_x else Vector3.RIGHT) * side
				var face: Vector3 = b.center + axis * t + normal * (thick / 2.0)
				var pos := Vector3(face.x, floor_y + MOUNT_Y, face.z) + normal * (FirstAidCabinet.SIZE.z / 2.0 + 0.005)
				var stand := Vector3(face.x, floor_y, face.z) + normal * 0.8
				if not _on_nav(nav, stand):
					continue
				if doors.any(func(d): return Vector2(d.x - pos.x, d.z - pos.z).length() < DOOR_GAP and absf(d.y - floor_y) < 2.5):
					continue
				if _blocked(solid, b, pos + normal * 0.12, FirstAidCabinet.SIZE * 0.5 + Vector3(0.05, 0.05, 0.12)):
					continue
				# Room to stand in front of it: nothing from knee height up, an arm's length out.
				var reach := Vector3(face.x, floor_y + 1.2, face.z) + normal * 0.55
				var half := (Vector3(0.35, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, 0.35)) + Vector3(0, 0.7, 0) + normal.abs() * 0.4
				if _blocked(solid, b, reach, half):
					continue
				out.append({"pos": pos, "facing": rad_to_deg(atan2(normal.x, normal.z)), "band": _band(floor_y)})
	return out


## The floor's walkable navigation, stairwells left out (they're for getting
## between floors, and STAIR 1 has its own cabinet).
static func floor_nav(level: Node3D, geo: NavigationRegion3D) -> Array:
	var wells := _stairwells(level, geo)
	return _nav_polys(level, geo).filter(func(poly):
		var c := Vector3.ZERO
		for v in poly:
			c += v
		c /= poly.size()
		return not wells.any(func(w): return w.grow(0.3).has_point(c)))


## Each stairwell's bounds in level space.
static func _stairwells(level: Node3D, geo: Node) -> Array:
	var out := []
	for holder in geo.find_children("Stairwell*", "Node3D", false, false):
		if not holder.has_meta("stair"):
			continue
		var bounds := AABB()
		var first := true
		for b in _boxes(level, holder, true):
			var a := AABB(b.center - b.size / 2.0, b.size)
			bounds = a if first else bounds.merge(a)
			first = false
		if not first:
			out.append(bounds)
	return out


static func _in_stairwell(body: Node, geo: Node) -> bool:
	var n := body.get_parent()
	while n and n != geo:
		if n.has_meta("stair"):
			return true
		n = n.get_parent()
	return false


## The floor's solid boxes in level space: {"center", "size"} (axis-aligned only),
## leaving out stairwells unless `stairs`.
static func _boxes(level: Node3D, geo: Node, stairs := false) -> Array:
	var out := []
	var inv := level.global_transform.affine_inverse()
	for body in geo.find_children("*", "StaticBody3D", true, false):
		if not stairs and _in_stairwell(body, geo):
			continue
		for shape in body.get_children():
			if not (shape is CollisionShape3D and shape.shape is BoxShape3D):
				continue
			var xf: Transform3D = inv * shape.global_transform
			# Square to the level, or turned a quarter: anything else isn't a wall to hang on.
			var square := true
			for col in [xf.basis.x, xf.basis.y, xf.basis.z]:
				var a: Vector3 = col.normalized().abs()
				if maxf(a.x, maxf(a.y, a.z)) < 0.999:
					square = false
			if not square:
				continue
			var size: Vector3 = shape.shape.size
			var aabb := xf * AABB(-size / 2.0, size)
			out.append({"center": aabb.get_center(), "size": aabb.size})
	return out


static func _blocked(boxes: Array, wall: Dictionary, at: Vector3, half: Vector3) -> bool:
	for b in boxes:
		if b == wall:
			continue
		var d: Vector3 = (at - b.center).abs()
		var h: Vector3 = b.size / 2.0 + half
		if d.x < h.x and d.y < h.y and d.z < h.z:
			return true
	return false


## The navigation mesh's polygons in level space, as arrays of Vector3.
static func _nav_polys(level: Node3D, geo: NavigationRegion3D) -> Array:
	var nm := geo.navigation_mesh
	var xf := level.global_transform.affine_inverse() * geo.global_transform
	var verts := nm.get_vertices()
	var out := []
	for i in nm.get_polygon_count():
		var poly := []
		for vi in nm.get_polygon(i):
			poly.append(xf * verts[vi])
		out.append(poly)
	return out


static func _on_nav(nav: Array, p: Vector3) -> bool:
	var q := Vector2(p.x, p.z)
	for poly in nav:
		var pts := PackedVector2Array()
		var y := 0.0
		for v in poly:
			pts.append(Vector2(v.x, v.z))
			y += v.y
		y /= poly.size()
		if absf(y - p.y) < 0.6 and Geometry2D.is_point_in_polygon(q, pts):
			return true
	return false


## Which storey a height is on (a floor's own levels are within a few metres).
static func _band(y: float) -> int:
	return roundi(y / 4.0)


## Storey -> how many of `n` kits it gets, by its walkable area (largest
## remainder), only storeys with somewhere to put one.
static func _shares(nav: Array, spots: Array, n: int) -> Dictionary:
	var area := {}
	for poly in nav:
		var y := 0.0
		for v in poly:
			y += v.y
		var band := _band(y / poly.size())
		if spots.any(func(sp): return sp.band == band):
			area[band] = area.get(band, 0.0) + _area([poly])
	var total := 0.0
	for b in area:
		total += area[b]
	var out := {}
	var rest := []
	var given := 0
	for b in area:
		var exact: float = n * area[b] / total
		out[b] = int(floor(exact))
		given += out[b]
		rest.append([exact - floor(exact), b])
	rest.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and x[1] > y[1]))
	for i in n - given:
		out[rest[i][1]] += 1
	for b in out.keys():
		if out[b] == 0:
			out.erase(b)
	return out


static func _area(nav: Array) -> float:
	var total := 0.0
	for poly in nav:
		var pts := PackedVector2Array()
		for v in poly:
			pts.append(Vector2(v.x, v.z))
		var a := 0.0
		for i in pts.size():
			a += pts[i].cross(pts[(i + 1) % pts.size()])
		total += absf(a) / 2.0
	return total


## `n` spots spread across the floor: the first from the seed, then each the one
## furthest from those already picked (and never within MIN_APART of one).
static func _spread(spots: Array, n: int, rng: RandomNumberGenerator) -> Array:
	if spots.is_empty() or n <= 0:
		return []
	var picked := [spots[rng.randi_range(0, spots.size() - 1)]]
	while picked.size() < n:
		var best: Dictionary = {}
		var best_d := -1.0
		for s in spots:
			var d := INF
			for p in picked:
				d = minf(d, s.pos.distance_to(p.pos))
			if d > best_d:
				best_d = d
				best = s
		if best_d < MIN_APART:
			break
		picked.append(best)
	return picked
