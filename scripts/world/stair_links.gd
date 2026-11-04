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
## {upper, lower, crew}: `crew` false once the crew is through (seal()); NPCs still ride.
var _links: Array[Dictionary] = []
var _riders: Array[Node3D] = []


static func create(level: LevelBase) -> StairLinks:
	var s := StairLinks.new()
	s.name = "StairLinks"
	s.root = level
	level.add_child(s)
	return s


## Join `upper`'s stairs down to `lower`'s (Stairwell holders), replacing any link
## either had.
func link(upper: Node3D, lower: Node3D) -> void:
	unlink(upper)
	unlink(lower)
	_links.append({"upper": upper, "lower": lower, "crew": true})


func unlink(holder: Node3D) -> void:
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
			if Stairwell.past_turn_down(l.upper, b.global_position):
				_move(b, Stairwell.carry_down(l.upper, l.lower), l.lower)
			elif Stairwell.past_turn_up(l.lower, b.global_position):
				_move(b, Stairwell.carry_down(l.upper, l.lower).affine_inverse(), l.upper)


## Same step, same way facing, same speed, on the other stairs. Where an NPC was
## walking to on the stairs moves with it.
func _move(body: Node3D, by: Transform3D, to: Node3D) -> void:
	body.global_transform = by * body.global_transform
	if body is CharacterBody3D:
		var cb := body as CharacterBody3D
		cb.velocity = by.basis * cb.velocity
	var route = body.get("route")
	if route is Array:
		for i in route.size():
			route[i] = by * (route[i] as Vector3)
	body.reset_physics_interpolation()
	carried.emit(body, to)
