class_name FallNet
extends Node
## The safety net under every floor: a player who falls out of the world (off the
## end of a driveway, through a gap in a wall) is put back where they last stood
## on solid ground, with no damage, instead of falling forever.
##
## "Out of the world" means falling with nothing at all underneath (a downward
## ray finds no floor), or falling for longer than any drop in the building.
## Each machine watches its own player, the way it owns that player's position;
## teammates see the move through the usual position sync, as with the stairs.
## LevelBase makes one for the player it creates (a level on its own, or the World).

## Falling this long with nothing underneath: out of the world.
const NOTHING_BELOW_TIME := 0.35
## Falling this long whatever is underneath: no drop in the building is this long.
const LONGEST_FALL := 3.0
## How far down the ray looks for a floor.
const LOOK_DOWN := 300.0
## How often the last safe spot is updated while you stand somewhere solid.
const SAFE_EVERY := 0.25
## A safe spot has floor all round it, this far out from your feet, so you're not
## put back on the very edge you went over.
const SAFE_MARGIN := 0.35
## A move this big in one tick is a teleport (stairs, elevator, checkpoint): the
## old safe spot no longer applies.
const TELEPORT := 2.0

## Emitted on this machine when its player has been put back.
signal caught(from: Vector3, to: Vector3)

var level: LevelBase
var player: Player
## Where the player last stood with solid floor all round (world space), if anywhere.
var safe_spot := Vector3.ZERO
var has_safe_spot := false
var _fall_time := 0.0
var _since_safe := 0.0
var _last_pos := Vector3.ZERO


static func create(for_level: LevelBase, for_player: Player) -> FallNet:
	var n := FallNet.new()
	n.name = "FallNet"
	n.level = for_level
	n.player = for_player
	for_level.add_child(n)
	return n


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return
	var pos := player.global_position
	if pos.distance_to(_last_pos) > TELEPORT:
		has_safe_spot = false  # moved by the game: wait for a fresh spot
		_fall_time = 0.0
	_last_pos = pos
	if _driven():
		_fall_time = 0.0
		return
	if player.is_on_floor():
		_fall_time = 0.0
		_since_safe += delta
		if _since_safe >= SAFE_EVERY:
			_since_safe = 0.0
			if _ground_all_round(pos):
				safe_spot = pos
				has_safe_spot = true
		return
	if player.velocity.y >= -0.5:
		return  # going up, or at the top of a jump
	_fall_time += delta
	if _fall_time >= LONGEST_FALL or (_fall_time >= NOTHING_BELOW_TIME and not _floor_below(pos)):
		if not _here().owns_falls():
			_fall_time = 0.0
			# Hard mode has no net: falling out of the building is death (PlayerCombat.fell_out).
			if not player.combat.fell_out():
				put_back()


## Moves that place the body themselves (climbing, riding, at a terminal): not a fall.
func _driven() -> bool:
	return player.state in [Player.Move.RIDE, Player.Move.TERMINAL, Player.Move.MANTLE, Player.Move.HANG,
		Player.Move.CLIMB, Player.Move.VAULT, Player.Move.LEDGE, Player.Move.SIT] or player.seated


## Back onto solid ground: the last safe spot, or the floor's checkpoint.
func put_back() -> void:
	var from := player.global_position
	var to := safe_spot if has_safe_spot else _checkpoint().origin
	player.global_position = to + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	_fall_time = 0.0
	_last_pos = player.global_position
	caught.emit(from, to)


func _checkpoint() -> Transform3D:
	return _here().spawn_point()


## The floor in play: the World's current wing, or the level itself.
func _here() -> LevelBase:
	var current = level.get("current")
	return current if current is LevelBase else level


func _space() -> PhysicsDirectSpaceState3D:
	return player.get_world_3d().direct_space_state


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, player.collision_mask, [player.get_rid()])
	return _space().intersect_ray(q)


func _floor_below(pos: Vector3) -> bool:
	return not _ray(pos + Vector3.UP * 0.2, pos + Vector3.DOWN * LOOK_DOWN).is_empty()


## Solid, unmoving floor under your feet and a little way out on every side.
func _ground_all_round(pos: Vector3) -> bool:
	for off in [Vector3.ZERO, Vector3(SAFE_MARGIN, 0, 0), Vector3(-SAFE_MARGIN, 0, 0), Vector3(0, 0, SAFE_MARGIN), Vector3(0, 0, -SAFE_MARGIN)]:
		var hit := _ray(pos + off + Vector3.UP * 0.3, pos + off + Vector3.DOWN * 0.4)
		if hit.is_empty() or not (hit.collider is StaticBody3D) or hit.collider is AnimatableBody3D:
			return false
	return true
