class_name PlayerCombat
extends Node
## A player's side of a fight: health, blocking, going down and being helped up,
## and what the big entities do to you (thrown across a room, grabbed and dragged).
## The Player owns one as its child; `Player.health` stays the number everything
## reads, and this is what changes it.
##
## Every hit names its cause, which decides what it can do:
##   "rourke"     a person swinging at you: right-click just before it lands to block
##   "watcher"    knocks you out: down, not dead
##   "shredder"   picks you up and throws you (see throw)
##   "custodian"  grabs you and drags you off (see grab)
##   "fall"       fatal: straight back to the checkpoint
##   ""           anything else: can't be blocked, puts you down at 0
## Big entities can't be blocked: only causes marked "block" can.
##
## At 0 health you go down. With teammates you lie there until one helps you up
## (E), or until you bleed out and come to at the checkpoint. If the whole crew
## is down, the level decides what happens (CrewVitals). Solo, the crew is just
## you, so going down is the same as the whole crew going down.

signal blocked(cause: String)
signal hurt(amount: float, cause: String)
signal went_down(cause: String)
signal got_up

const MAX_HEALTH := 100.0
const CAUSES := {
	"rourke": {"block": true},
	"watcher": {},
	"shredder": {},
	"custodian": {},
	"fall": {"lethal": true},
	"spar": {"block": true, "practice": true},  # the garage punch bag: a practice swing, no damage
}
## No hits for this long, and health starts creeping back.
const REGEN_DELAY := 8.0
const REGEN_RATE := 5.0
## What a teammate helping you up leaves you with.
const REVIVE_HEALTH := 50.0
## Down with nobody coming: you come to at the checkpoint after this long.
const BLEED_OUT := 45.0
## Eye height while you lie on the floor.
const DOWN_EYE := 0.3
## How far up a throw sends you, on top of its push.
const THROW_LIFT := 3.5
## Lines for Augustine's approval: see plan/approvals/combat-strings.md.
const DOWN_NOTICE := "You're down. Hang on for your crew."
const BLOCK_NOTICE := "Blocked"

var player: Node  # the Player (untyped: tests load this script)
## The level's CrewVitals; null in a world with no level (the movement gym, tests).
var crew: Node
var guard := Guard.new()
var down := false
var down_cause := ""
var bleed_left := 0.0
## Whatever has hold of you (a Custodian), or null.
var grabbed_by: Node3D
## In the air after a throw: the controls come back when you land.
var thrown := false
## The "Blocked" flash under the crosshair (local player only).
var bar: BlockFlash

var _clock := 0.0
var _since_hurt := 100.0
var _left_floor := false
## Input we locked, so we only hand back what we took.
var _locked := false
## Held by something (grabbed_by can be freed under us, so it can't say).
var _held := false


static func create(for_player: Node) -> PlayerCombat:
	var c := PlayerCombat.new()
	c.name = "Combat"
	c.player = for_player
	for_player.add_child(c)
	return c


func _ready() -> void:
	# The health bar itself is Movement's Vitals (scripts/ui/vitals.gd), reading player.health.
	if player.get("hud") and player.local_control:
		bar = BlockFlash.new()
		player.hud.add_child(bar)


## Seconds of game time since this player spawned: the guard's clock.
func now() -> float:
	return _clock


## Right mouse: put your guard up for a moment.
func raise_guard() -> bool:
	if down or thrown or _held:
		return false
	return guard.raise(_clock)


static func blockable(cause: String) -> bool:
	return CAUSES.get(cause, {}).get("block", false)


## A practice swing (the garage punch bag): blocking it earns nothing.
static func practice(cause: String) -> bool:
	return CAUSES.get(cause, {}).get("practice", false)


static func lethal(cause: String) -> bool:
	return CAUSES.get(cause, {}).get("lethal", false)


## A hit for `amount` from `cause`. Returns what came of it:
## "blocked", "hit", "down", "dead" or "ignored" (already down).
func take_damage(amount: float, cause: String = "") -> String:
	if down and not lethal(cause):
		return "ignored"
	if blockable(cause) and guard.catch_hit(_clock):
		blocked.emit(cause)
		if bar:
			bar.flash_block()
		if crew:
			crew.report_blocked(cause)
		return "blocked"
	player.health = maxf(0.0, player.health - amount)
	_since_hurt = 0.0
	if player.hud:
		player.hud.damage_flash(player.health)
	hurt.emit(amount, cause)
	if player.health > 0.0:
		return "hit"
	if lethal(cause) or crew == null:
		die()
		return "dead"
	go_down(cause)
	return "down"


## Health to 0 and on the floor. The crew hears about it; if nobody is left
## standing, the level decides what happens next.
func go_down(cause: String) -> void:
	release()
	thrown = false
	player.health = 0.0
	down = true
	down_cause = cause
	bleed_left = BLEED_OUT
	_lock(true)
	player.lower_notebook(true)
	player.put_down(true)
	if player.is_using_terminal():
		player.leave_terminal()
	if player.has_method("knock_down"):
		player.knock_down(INF)  # Movement's lying-down state, until get_up()
	went_down.emit(cause)
	if player.hud and crew and crew.is_online():
		player.hud.notice(DOWN_NOTICE, 5.0)
	if crew:
		crew.report_down(true, cause)
	else:
		die()


## A teammate helped you up.
func revive() -> void:
	if not down:
		return
	down = false
	down_cause = ""
	player.health = REVIVE_HEALTH
	_since_hurt = 0.0
	if player.has_method("get_up"):
		player.get_up()
	_lock(false)
	if player.hud:
		player.hud.damage_flash(player.health)
	got_up.emit()


## Out for real: back to the checkpoint, through the level's usual death.
func die() -> void:
	var was_down := down
	release()
	thrown = false
	down = false
	down_cause = ""
	player.health = 0.0
	_lock(false)  # the level's own death fade locks and unlocks from here
	if was_down and crew:
		crew.report_down(false, "")
	player.died.emit()


## Respawned at a checkpoint: a clean slate.
func reset() -> void:
	release()
	thrown = false
	down = false
	down_cause = ""
	_since_hurt = 100.0
	_lock(false)
	guard = Guard.new()


## Something big picked you up and threw you away from `from`: `damage` (can't be
## blocked), then you fly with `force` m/s of push, controls gone until you land.
## Thrown off a high shelf, you fall the rest of the way yourself.
func throw(from: Vector3, force: float, damage: float, cause: String = "shredder") -> void:
	var result := take_damage(damage, cause)
	if result == "dead":
		return
	release()
	if player.is_using_terminal():
		player.leave_terminal()
	player.lower_notebook(true)
	player.put_down(true)
	player.state = Player.Move.WALK
	var dir: Vector3 = player.global_position - from
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = player.global_basis.z
	var impulse: Vector3 = dir.normalized() * force + Vector3.UP * THROW_LIFT
	if player.has_method("knock_back"):
		player.velocity = Vector3.ZERO
		player.knock_back(impulse)  # Movement's: drops whatever you were doing
	else:
		player.velocity = impulse
	if down:
		return  # knocked out by it: you land where you land and stay there
	thrown = true
	_left_floor = false
	_lock(true)


## Held by `by`: you go where it goes (its grab_point(), if it has one) until it
## lets go, or your crew makes it.
func grab(by: Node3D) -> void:
	if grabbed_by == by:
		return
	if player.is_using_terminal():
		player.leave_terminal()
	player.lower_notebook(true)
	player.put_down(true)
	player.state = Player.Move.WALK
	grabbed_by = by
	_held = true
	_lock(true)


func release() -> void:
	if not _held:
		return
	_held = false
	grabbed_by = null
	if not down and not thrown:
		_lock(false)


func _lock(on: bool) -> void:
	if on and not _locked:
		_locked = true
		player.input_locked = true
	elif not on and _locked:
		_locked = false
		player.input_locked = false


func _physics_process(delta: float) -> void:
	_clock += delta
	_since_hurt += delta
	if down:
		if crew and crew.is_online():
			bleed_left -= delta
			if bleed_left <= 0.0:
				die()
		return
	if player.health > 0.0 and player.health < MAX_HEALTH and _since_hurt > REGEN_DELAY:
		player.health = minf(MAX_HEALTH, player.health + REGEN_RATE * delta)
	if _held:
		if not is_instance_valid(grabbed_by) or not grabbed_by.is_inside_tree():
			release()
		else:
			var at: Vector3 = grabbed_by.grab_point() if grabbed_by.has_method("grab_point") else grabbed_by.global_position + grabbed_by.global_basis.z * -0.8
			player.global_position = at
			player.velocity = Vector3.ZERO
	if thrown:
		if not player.is_on_floor():
			_left_floor = true
		elif _left_floor:
			thrown = false
			_lock(false)
