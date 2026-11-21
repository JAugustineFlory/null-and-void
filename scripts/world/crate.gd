class_name Crate
extends Interactable
## E1's solo route (environment play): a crate you pick up, carry in both hands,
## slowly, and set down, on the floor or on another crate. Stack two against a
## wall and you can climb an edge that would otherwise take a teammate's leg-up:
## from a stack c metres high you mantle up to c + Player.MANTLE_MAX and catch
## and climb up to c + Player.HANG_REACH. Co-op: the host decides who has it and
## where it goes, and every machine plays it out. Build one with make(); it
## moves, so it goes under the level, not its geo (navigation bakes from geo).

const SIZE := 0.6
const COLOR := Color(0.46, 0.36, 0.24)
const SLAT := Color(0.36, 0.27, 0.17)
## Words, waiting on Augustine's OK.
const PICK_UP := "Pick up the crate"
const SET_DOWN := "[E] Set the crate down"
## How far in front of your body you set it down, and the highest above your
## feet you can set it (on top of one or two others).
const SET_AHEAD := 0.5
const SET_HIGHEST := 1.25

## Every machine: someone picked it up (`peer_id`), or set it down (0).
signal carried(peer_id: int)

## Who has it (their peer id), 0 when it's on the ground. In a test's own world
## without a co-op session, carrier says who.
var carrier_id := 0
var carrier: Node3D
var _layer := 1


## A crate standing on `at` (a point on the floor under its middle), turned `yaw`.
## `id` names it, the same on every machine (co-op finds it by name).
static func make(parent: Node3D, at: Vector3, yaw: float = 0.0, id: String = "") -> Crate:
	var c := Crate.new()
	c.name = "Crate" + ("_" + id if id != "" else "")
	c.position = at + Vector3.UP * SIZE / 2.0
	c.rotation.y = yaw
	c.prompt = PICK_UP
	c.kind = "none"
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * SIZE
	m.mesh = bm
	m.material_override = Greybox.mat(COLOR)
	c.add_child(m)
	# A slat round each side, so it reads as a crate.
	for sy in [-1.0, 1.0]:
		var s := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(SIZE + 0.01, 0.06, SIZE + 0.01)
		s.mesh = sm
		s.material_override = Greybox.mat(SLAT)
		s.position.y = sy * (SIZE / 2.0 - 0.06)
		c.add_child(s)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3.ONE * SIZE
	shape.shape = bs
	c.add_child(shape)
	parent.add_child(c)
	c.add_to_group("interactable")
	c.used.connect(c._on_used)
	return c


func get_prompt(player: Node) -> String:
	if carrier_id != 0 or carrier or not _can_lift(player):
		return ""
	return super.get_prompt(player)


## The one pressing checks their own hands; on the host, a teammate's press
## arrives as their puppet, already checked on their machine.
func interact(player: Node) -> void:
	if carrier_id == 0 and carrier == null and (_can_lift(player) or player is PlayerPuppet):
		super.interact(player)


## On your feet, hands free, and nothing stacked on it.
func _can_lift(player: Node) -> bool:
	if not (player is Player):
		return false
	var p := player as Player
	return p.state == Player.Move.WALK and p.is_on_floor() and not p.crawling and p.carrying == null and not p._hands_full() and not _loaded()


## Something's standing on it: another crate, or someone.
func _loaded() -> bool:
	if not is_inside_tree():
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(SIZE * 0.9, 0.1, SIZE * 0.9)
	q.shape = bs
	q.transform = Transform3D(global_basis, global_position + Vector3.UP * (SIZE / 2.0 + 0.07))
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Host: someone pressed E on it.
func _on_used(player: Node) -> void:
	if carrier_id != 0 or carrier or _loaded():
		return
	var lvl := _level()
	var id: int = lvl.players.id_of(player) if lvl else 0
	var sync := LevelSync.of(self)
	if sync:
		sync.run_on(self, "pick_up", [id])
	else:
		pick_up(id, player)


## Every machine: `peer_id` picks it up. `who` is their body without a co-op
## session (a test's own players).
func pick_up(peer_id: int, who: Node = null) -> void:
	var body: Node3D = who if who is Node3D else _body_of(peer_id)
	if body == null:
		return
	carrier_id = peer_id
	carrier = body
	_layer = collision_layer
	collision_layer = 0  # not in their way, and not what E aims at
	if body is Player:
		(body as Player).carrying = self  # this machine's own player (a puppet just has it in front of them)
	_follow()
	carried.emit(peer_id)


## Where `by` (carrying it) would set it down: on the floor or a crate just in
## front of them, with room for it (drawn in toward them if a wall's close).
## Vector3(INF...) if there's nowhere.
func set_down_spot(by: Player) -> Vector3:
	var d := SET_AHEAD
	while d >= SET_AHEAD - 0.35:
		var spot := _spot_at(by, d)
		if spot.x != INF:
			return spot
		d -= 0.05
	return Vector3(INF, INF, INF)


func _spot_at(by: Player, ahead: float) -> Vector3:
	var none := Vector3(INF, INF, INF)
	var fwd := -by.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := by.global_position + fwd * (by.body.radius + ahead)
	var space := by.get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid(), by.get_rid()]
	# Nothing between you and there (no setting it down through a wall).
	var eye := by.global_position + Vector3.UP * 0.9
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, Vector3(at.x, eye.y, at.z) + fwd * (SIZE / 2.0 - 0.05), by.collision_mask, exclude)).is_empty():
		return none
	var from := Vector3(at.x, by.global_position.y + SET_HIGHEST + SIZE + 0.1, at.z)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (SET_HIGHEST + SIZE + 1.0), by.collision_mask, exclude))
	if hit.is_empty() or hit.normal.y < 0.9:
		return none
	var spot: Vector3 = hit.position
	var yaw := by.rotation.y
	if hit.collider is Crate:
		var below: Crate = hit.collider
		spot = below.global_position + Vector3.UP * SIZE / 2.0  # squared up on it
		yaw = below.rotation.y
	if spot.y - by.global_position.y > SET_HIGHEST:
		return none
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3.ONE * (SIZE - 0.04)
	q.shape = bs
	q.transform = Transform3D(Basis(Vector3.UP, yaw), spot + Vector3.UP * (SIZE / 2.0 + 0.01))
	q.exclude = exclude
	if not space.intersect_shape(q, 1).is_empty():
		return none
	return spot


## The crate this one would go on at `spot`, if any (for its turn).
func _crate_under(spot: Vector3) -> Crate:
	var space := get_world_3d().direct_space_state
	var from := spot + Vector3.UP * 0.05
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.2, 0xFFFFFFFF, [get_rid()]))
	return hit.collider if not hit.is_empty() and hit.collider is Crate else null


## E while carrying it (on the carrier's machine): set it down in front of you,
## if there's room. False if not.
func set_down(by: Player) -> bool:
	var spot := set_down_spot(by)
	if spot.x == INF:
		return false
	var below := _crate_under(spot)
	var yaw: float = below.rotation.y if below else by.rotation.y
	var sync := LevelSync.of(self)
	if sync and not sync.is_host():
		_ask_place.rpc_id(1, spot, yaw)
	else:
		_host_place(carrier_id, spot, yaw)
	return true


@rpc("any_peer", "reliable")
func _ask_place(spot: Vector3, yaw: float) -> void:
	_host_place(multiplayer.get_remote_sender_id(), spot, yaw)


## Host: the one carrying it puts it down at `spot`.
func _host_place(peer_id: int, spot: Vector3, yaw: float) -> void:
	if peer_id != carrier_id or carrier == null:
		return
	var sync := LevelSync.of(self)
	if sync:
		sync.run_on(self, "place", [spot, yaw])
	else:
		place(spot, yaw)


## Every machine: it's down at `spot` (a point under its middle), turned `yaw`.
func place(spot: Vector3, yaw: float) -> void:
	if carrier is Player and (carrier as Player).carrying == self:
		(carrier as Player).carrying = null
	carrier = null
	carrier_id = 0
	global_transform = Transform3D(Basis(Vector3.UP, yaw), spot + Vector3.UP * SIZE / 2.0)
	collision_layer = _layer
	carried.emit(0)


## Dropped where they stand (they went down, or left): at their feet.
func drop_here() -> void:
	if carrier == null or not is_instance_valid(carrier):
		carrier = null
		carrier_id = 0
		collision_layer = _layer
		return
	var at := carrier.global_position
	place(at, carrier.rotation.y)


func _physics_process(_delta: float) -> void:
	if carrier == null:
		return
	if not is_instance_valid(carrier):
		drop_here()
		return
	_follow()


## In front of whoever carries it, chest high, turned with them.
func _follow() -> void:
	var size := 1.0
	var radius := Player.RADIUS
	if carrier is Player:
		size = (carrier as Player).body.size
		radius = (carrier as Player).body.radius
	elif carrier.get("size") != null:
		size = float(carrier.get("size"))
		radius = Player.RADIUS * size
	var fwd := -carrier.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	global_transform = Transform3D(Basis(Vector3.UP, carrier.global_rotation.y), carrier.global_position + Vector3.UP * 0.95 * size + fwd * (radius + SIZE / 2.0 + 0.05))


func _body_of(peer_id: int) -> Node3D:
	var lvl := _level()
	return lvl.players.puppet(peer_id) if lvl and lvl.get("players") else null


## The level this is in (it has the players). Duck-typed, like ItemDock._level.
func _level() -> Node:
	var n := get_parent()
	while n and n.get("players") == null:
		n = n.get_parent()
	return n
