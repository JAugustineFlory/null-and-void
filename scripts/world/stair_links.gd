class_name StairLinks
extends Node
## Makes two floors' stairwells one flight of stairs (Augustine, v0.9: "players
## actually having to walk down the stairs, and open the door"). Floors in the
## World stand side by side, not stacked, but every Stairwell is built alike, a
## storey or two of switchback stairs, so whoever walks down past the turn below
## one floor's landing is carried to the same step on the floor below's stairs,
## where everything around them looks the same; walking back up past the turn
## carries them back. Nothing fades and nothing loads.
##
## Each machine carries its own player (other machines see the puppet jump, which
## snaps); the host carries the NPCs it has asked to ride (carry()). One per run
## (LevelBase.stairs, the World's in the World).

## `body` went from one stairwell to the other: `to` is the one it's in now.
signal carried(body: Node3D, to: Node3D)

var root: LevelBase
## {upper, lower, crew, storeys, down, at}: `crew` false once the crew is through
## (seal()); NPCs still ride. `storeys` between the two floors; `down` when the
## walk starts at `upper` (the start's stairwell is the one the floors in between
## are walked in). `at`: for each body, {e, dest}: how many floors in between it's
## past, and whether it's handed over to the other stairwell.
var _links: Array[Dictionary] = []
var _riders: Array[Node3D] = []


static func create(level: LevelBase) -> StairLinks:
	var s := StairLinks.new()
	s.name = "StairLinks"
	s.root = level
	level.add_child(s)
	return s


## Join `upper`'s stairs down to `lower`'s (Stairwell holders), `storeys` apart,
## replacing any link either had. The walk starts at `upper` if `down`, else at
## `lower`: it's the start's stairwell that the floors in between go past in
## (Augustine, 2026-11-05: "the actual number of stairs"). Whoever walks a storey
## past its landing is carried back a storey on the same stairs, where everything
## looks the same but the landing's number, which counts on; one storey short of
## the end they're carried onto the other floor's stairs.
func link(upper: Node3D, lower: Node3D, storeys := 1, down := true) -> void:
	unlink(upper)
	unlink(lower)
	_links.append({"upper": upper, "lower": lower, "crew": true, "storeys": maxi(1, storeys), "down": down, "at": {}})


func unlink(holder: Node3D) -> void:
	for l in _links:
		if (l.upper == holder or l.lower == holder) and is_instance_valid(_start(l)):
			Stairwell.count_storeys(_start(l), 0)
	_links = _links.filter(func(l): return l.upper != holder and l.lower != holder)


## The crew is through: the door behind them locks, as stair doors do after hours,
## so the stairs back up stop at a shut door. NPCs on their way still come through.
func seal(holder: Node3D) -> void:
	for l in _links:
		if l.upper == holder or l.lower == holder:
			l.crew = false


func is_linked(holder: Node3D) -> bool:
	return _links.any(func(l): return l.upper == holder or l.lower == holder)


## Host: an NPC that walks the stairs too (the Custodian coming down after the crew).
func carry(body: Node3D) -> void:
	if body not in _riders:
		_riders.append(body)


## Where `w`, a point in the start stairwell's space as if the stairs were really
## stacked (y -3 storeys is three floors down), is now for `body`: the stairs it's
## walking repeat, so the place moves as it's carried. For tests and NPC routes.
func place(body: Node3D, holder: Node3D, w: Vector3) -> Vector3:
	for l in _links:
		if l.upper != holder and l.lower != holder:
			continue
		var at: Dictionary = l.at.get(body.get_instance_id(), {"e": 0, "dest": false})
		var e: int = l.storeys - 1 if at.dest else at.e
		var shifted: Vector3 = _start(l).global_transform * (w + Vector3(0, _sign(l) * -e * Stairwell.STOREY, 0))
		if at.dest:
			return _hand_over(l) * shifted
		return shifted
	return holder.global_transform * w


## How many floors in between `body` is past on the link `holder` is in, and
## whether it's on the other floor's stairs: {e, dest}.
func progress(body: Node3D, holder: Node3D) -> Dictionary:
	for l in _links:
		if l.upper == holder or l.lower == holder:
			return l.at.get(body.get_instance_id(), {"e": 0, "dest": false}).duplicate()
	return {"e": 0, "dest": false}


func _physics_process(_delta: float) -> void:
	if _links.is_empty():
		return
	_links = _links.filter(func(l): return is_instance_valid(l.upper) and is_instance_valid(l.lower) and l.upper.is_inside_tree() and l.lower.is_inside_tree())
	_riders = _riders.filter(func(b): return is_instance_valid(b) and b.is_inside_tree())
	var player: Node3D = root.player if root else null
	for l in _links:
		var bodies: Array[Node3D] = _riders.duplicate()
		if l.crew and player and player.is_inside_tree():
			bodies.append(player)
		for b in bodies:
			_step(l, b, b == player)


## One body on one link: round the turns, a storey at a time.
func _step(l: Dictionary, b: Node3D, counts: bool) -> void:
	var id := b.get_instance_id()
	var at: Dictionary = l.at.get(id, {"e": 0, "dest": false})
	var start := _start(l)
	var last: int = l.storeys - 1
	var s := _sign(l)  # -1 walking down from the start, 1 up
	var pos := b.global_position
	var was: int = at.e
	if s < 0:
		if at.e == last and Stairwell.past_turn_down(l.upper, pos):
			_move(b, _hand_over(l), l.lower)
			at.dest = true
		elif Stairwell.past_turn_up(l.lower, pos):
			_move(b, _hand_over(l).affine_inverse(), l.upper)
			at = {"e": last, "dest": false}
		elif at.e < last and Stairwell.past_turn_down(start, pos, -1):
			_move(b, _shift(start, 1), start)
			at.e += 1
		elif at.e > 0 and Stairwell.past_turn_up(start, pos, -1):
			_move(b, _shift(start, -1), start)
			at.e -= 1
	else:
		if at.e == last and Stairwell.past_turn_up(l.lower, pos):
			_move(b, _hand_over(l), l.upper)
			at.dest = true
		elif Stairwell.past_turn_down(l.upper, pos):
			_move(b, _hand_over(l).affine_inverse(), l.lower)
			at = {"e": last, "dest": false}
		elif at.e < last and Stairwell.past_turn_up(start, pos, 1):
			_move(b, _shift(start, -1), start)
			at.e += 1
		elif at.e > 0 and Stairwell.past_turn_down(start, pos, 1):
			_move(b, _shift(start, 1), start)
			at.e -= 1
	l.at[id] = at
	if counts and at.e != was:
		Stairwell.count_storeys(start, s * at.e)


func _start(l: Dictionary) -> Node3D:
	return l.upper if l.down else l.lower


func _sign(l: Dictionary) -> int:
	return -1 if l.down else 1


## From the start's stairs, one storey short of the end, to the same step on the
## other floor's (its inverse comes back).
func _hand_over(l: Dictionary) -> Transform3D:
	var c := Stairwell.carry_down(l.upper, l.lower)
	return c if l.down else c.affine_inverse()


## Up (1) or down (-1) a storey on the same stairs.
static func _shift(holder: Node3D, storeys: int) -> Transform3D:
	var h := holder.global_transform
	return h * Transform3D(Basis(), Vector3(0, storeys * Stairwell.STOREY, 0)) * h.affine_inverse()


## Same step, same way facing, same speed, on the other stairs. Where an NPC was
## walking to on the stairs moves with it, and so does whatever a player is partway
## through (a mantle or vault over the rail at the turn), or it would pull them back.
func _move(body: Node3D, by: Transform3D, to: Node3D) -> void:
	body.global_transform = by * body.global_transform
	if body is CharacterBody3D:
		var cb := body as CharacterBody3D
		cb.velocity = by.basis * cb.velocity
	var route = body.get("route")
	if route is Array:
		for i in route.size():
			route[i] = by * (route[i] as Vector3)
	if body.has_method("carried_by"):
		body.carried_by(by)
	body.reset_physics_interpolation()
	carried.emit(body, to)
