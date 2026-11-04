extends RefCounted
## Every paper on every floor shows its printed side to whoever reads it, and
## lifting it to read doesn't flip it over (Augustine, v0.8-beta1: papers faced
## the wall or lay upside down, so they flipped round as you picked them up and
## again as you put them back, and their words couldn't be read where they were).
##
## Where you'd stand to read one: on the floor in front of its printed side (for
## one lying flat, at the foot of its text), with nothing in the way. From there
## the paper must be upright, and the lift up to your eyes (player.read_pose) a
## turn of less than 90°. A paper on a terminal's desk is read from the
## terminal's side.

const SEEDS := [3, 11]
## Eye height above the walkable floor (the navmesh sits a little over it).
const EYE := 1.6
## How far in front of a paper a reader might stand, in metres.
const NEAR := 0.5
const FAR := 1.5

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	await test_papers_face_their_readers()


func _game() -> Node:
	return _tree.root.get_node("/root/Game")


## The paper's printed side and the top of its text, in the world, as it lies or hangs.
static func faces(d: Node3D, player: Node) -> Dictionary:
	var read: Basis = player.read_pose(d.read_size, d.read_face).basis.orthonormalized()
	var gb := d.global_basis.orthonormalized()
	return {"face": gb * (read.inverse() * Vector3.BACK), "up": gb * (read.inverse() * Vector3.UP)}


## Where an eye could be to read `d`, or null: standing in front of its printed
## side (at the foot of its text if it lies flat), within 25° of straight on,
## with a clear view of it.
static func reading_eye(level: Node3D, d: Node3D) -> Variant:
	var f := faces(d, level.player)
	var toward: Vector3 = -f.up if absf(f.face.y) > 0.7 else f.face
	toward.y = 0
	if toward.length() < 0.3:
		return null
	toward = toward.normalized()
	var c := d.global_position
	var map := level.get_world_3d().navigation_map
	var space := level.get_world_3d().direct_space_state
	for a in [0.0, 25.0, -25.0]:
		var dir := toward.rotated(Vector3.UP, deg_to_rad(a))
		var r := NEAR
		while r <= FAR + 0.001:
			var p := c + dir * r
			r += 0.1
			var floor_p := NavigationServer3D.map_get_closest_point(map, Vector3(p.x, c.y - 0.5, p.z))
			if Vector2(floor_p.x - p.x, floor_p.z - p.z).length() > 0.35 or floor_p.y > c.y + 0.3 or floor_p.y < c.y - 2.6:
				continue
			var eye := Vector3(p.x, floor_p.y + EYE, p.z)
			var q := PhysicsRayQueryParameters3D.create(eye, c)
			q.exclude = [d.get_rid()] if d is CollisionObject3D else []
			var hit := space.intersect_ray(q)
			if hit.is_empty() or hit.position.distance_to(c) < 0.08:
				return eye
	return null


## How far the paper turns going from where it is, seen from `eye`, to held up
## to read (degrees).
static func lift_turn(d: Node3D, player: Node, eye: Vector3) -> float:
	var read: Basis = player.read_pose(d.read_size, d.read_face).basis.orthonormalized()
	var cam := Basis.looking_at(d.global_position - eye, Vector3.UP)
	var home := cam.inverse() * d.global_basis.orthonormalized()
	return rad_to_deg((read * home.inverse()).get_rotation_quaternion().get_angle())


## The terminal whose desk a flat paper lies on, or null.
static func desk_terminal(level: Node, d: Node3D) -> Node3D:
	var c := d.global_position
	for t in level.find_children("*", "Terminal", true, false):
		var tp: Vector3 = t.global_position
		if Vector2(tp.x - c.x, tp.z - c.z).length() < 1.6 and absf(tp.y - c.y) < 0.4:
			return t
	return null


func test_papers_face_their_readers() -> void:
	print("Papers face whoever reads them, and lift without flipping")
	var wrong: Array[String] = []
	var papers := 0
	var floors := {}
	for s in SEEDS:
		var i := 0
		while ResourceLoader.exists("res://scenes/level_%d.tscn" % i):
			_game().new_run(s)
			var level = load("res://scenes/level_%d.tscn" % i).instantiate()
			_tree.root.add_child(level)
			for f in 12:
				await _tree.physics_frame
			for d in level.find_children("*", "Document", true, false):
				if not d.is_visible_in_tree():
					continue
				papers += 1
				floors[i] = true
				var why := _wrong(level, d)
				if why != "":
					var line := "level %d \"%s\" at %s: %s" % [i, d.title, d.global_position.snapped(Vector3.ONE * 0.01), why]
					if line not in wrong:
						wrong.append(line)
			level.queue_free()
			await _tree.process_frame
			i += 1
	_check.call(floors.size() >= 6 and papers >= 150, "checked every paper on every floor (%d floors, %d papers over %d seeds)" % [floors.size(), papers, SEEDS.size()])
	_check.call(wrong.is_empty(), "every paper shows its printed side, upright, to where you'd stand to read it, and lifts without flipping%s" % ("" if wrong.is_empty() else " (not:\n  %s)" % "\n  ".join(wrong)))


## What's wrong with how `d` lies or hangs, or "".
func _wrong(level: Node3D, d: Node3D) -> String:
	var f := faces(d, level.player)
	if d.flat and f.face.y < 0.9:
		return "lying on a desk with its printed side down"
	if not d.flat and f.up.y < 0.9:
		return "its words aren't upright"
	var eye = reading_eye(level, d)
	if eye == null:
		return "nowhere to stand in front of its printed side (facing a wall, or the foot of its text toward one): turn it 180°"
	var turn := lift_turn(d, level.player, eye)
	if turn > 90.0:
		return "turns %d° as you lift it to read" % roundi(turn)
	if d.flat:
		var t := desk_terminal(level, d)
		if t:
			var bottom: Vector3 = -f.up
			bottom.y = 0
			var user: Vector3 = t.global_basis * Vector3.BACK
			user.y = 0
			var off := rad_to_deg(bottom.angle_to(user))
			if off > 60.0:
				return "on %s's desk but the foot of its text is %d° away from where you sit at it" % [t.name, roundi(off)]
	return ""
