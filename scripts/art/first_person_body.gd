class_name FirstPersonBody
extends Node3D
## Your own body, seen from your own eyes: the same CharacterRig your teammates
## see, built from your look, with the head hidden so the camera sits where it
## was. Look down and you see your chest, legs and feet; swing, block or get hit
## and your own arms do it in front of you. (Garage playtest item 14, ground
## floor item 7: one set of animations, played when you do something.)
##
##   FirstPersonBody.attach(player)   # Player._ready, for the local player
##
## Typing at a terminal plays "type" like everywhere else; the camera is on the
## screen by then, so the hands stay out of sight.

## The rig stands this far behind the camera, so looking down shows the chest
## and feet in front of you rather than the inside of your collar.
const BACK := 0.08
## Punching or guarding, the body comes this much further forward under the
## camera, as you lean in behind your fists: they come into view. (Not for a
## hit taken: leaning in then shows the top of the neck.)
const FIGHT_LEAN := 0.3
const FIGHTING := ["jab", "cross", "guard"]
## How long one-shot actions hold before the body goes back to what it was doing.
const JAB_TIME := 0.6
const RECOIL_TIME := 0.3
const FLINCH_TIME := 0.35
## The hip joint is this far above the underside of the thigh (as PlayerPuppet).
const SEAT_THIGH := 0.06

var player: Node3D  # Player
var rig: CharacterRig

## What's playing for a moment, and until when (seconds on _t).
var _moment := ""
var _until := 0.0
var _t := 0.0
var _notebook := false
var _prop := false
var _sit_hip := 0.42
var _lean := 0.0


static func attach(to: Node3D, look: Dictionary = {}) -> FirstPersonBody:
	var fp := FirstPersonBody.new()
	fp.name = "FirstPersonBody"
	fp.player = to
	if look.is_empty():
		look = NetPlayers.look_for(to, to.multiplayer.get_unique_id() if to.is_inside_tree() else 1)
	fp.position = Vector3(0, 0, BACK)
	to.add_child(fp)
	fp.rig = CharacterRig.build(fp, look)
	fp.rig.hide_head = true
	fp._sit_hip = 0.87 * float(look.get("height", 1.0)) - 0.45
	fp._listen()
	return fp


func _listen() -> void:
	var combat = player.get("combat")
	if combat:
		combat.swung.connect(_swing)
		combat.blocked.connect(func(_cause): _hold("recoil", RECOIL_TIME))
		combat.hurt.connect(func(_amount, _cause): _hold("flinch", FLINCH_TIME))
	for pair in [["notebook_raised", func(): _notebook = true], ["notebook_lowered", func(): _notebook = false],
			["prop_raised", func(_p): _prop = true], ["prop_lowered", func(_p): _prop = false]]:
		if player.has_signal(pair[0]):
			player.connect(pair[0], pair[1])


## Swings alternate: a jab, then a cross.
func _swing() -> void:
	_hold("cross" if _moment == "jab" and _t < _until + 0.4 else "jab", JAB_TIME)


func _hold(action: String, seconds: float) -> void:
	_moment = action
	_until = _t + seconds


func _process(delta: float) -> void:
	_t += delta
	var action := current_action()
	# Lying down, the camera is on the floor inside the body: leave it out.
	visible = action != "down"
	rig.play(action)
	var height = player.get("stance_height")
	rig.stance_height = height if height != null else -1.0
	var head = player.get("head")
	rig.head_pitch = head.rotation.x if head else 0.0
	# On a chair the player's origin is the seat top: lower the hips onto it.
	var chair: bool = rig.action == "sit"
	_lean = lerpf(_lean, FIGHT_LEAN if action in FIGHTING else 0.0, 1.0 - exp(-12.0 * delta))
	position = Vector3(0, -(_sit_hip - SEAT_THIGH) if chair else 0.0, BACK - _lean)


## The action the body should be playing now.
func current_action() -> String:
	if _is("is_down") or player.get("downed") == true:
		return "down"
	if _is("is_sitting"):
		return "sit" if player.get("seat") != null else "sit_floor"
	if _is("is_using_terminal"):
		return "type"
	if _notebook or _prop:
		return "idle"  # the notebook or the paper is up in front of you
	if _t < _until:
		return _moment
	var combat = player.get("combat")
	if combat and combat.has_method("guard_up") and combat.guard_up():
		return "guard"
	return "idle"


func _is(method: String) -> bool:
	return player.has_method(method) and player.call(method)
