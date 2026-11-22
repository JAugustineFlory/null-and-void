class_name SfxMonster
extends Node
## A monster's sounds, from where it is and what it's doing, on every machine. The
## host runs the monsters and every machine gets their position and state
## (sync_properties), or plays them out together (an Echo), so each machine works out
## the same sounds by watching: its footfalls as it covers ground, a voice as it
## changes state (the Shredder roars as it wakes; the Custodian boots, alarms, sparks
## and powers down), now and then a breath, and a loop while it works (servos, an
## Echo's hum). The Watcher has no state to watch: it moves or it's still.

## Each kind of monster: what its feet sound like and how far apart they fall
## (step, stride), what it says entering a state ("from>to" or just "to"), a sound
## it makes now and then in some states (idle: sound, seconds between, states), and
## a loop it keeps up while in some states (and moving, if `loop_moving`).
const VOICES := {
	"shredder": {"step": "heavy_step", "stride": 1.4,
		"enter": {"dormant>listening": "shredder_roar", "turning": "shredder_snarl", "grabbing": "shredder_roar", "stunned": "shredder_roar", "recovering": "shredder_breath"},
		"idle": ["shredder_breath", Vector2(3.0, 6.0), ["listening", "roaming", "investigating"]]},
	"custodian": {"step": "robot_step", "stride": 1.1,
		"enter": {"bay>hunting": "robot_boot", "hunting": "robot_alert", "dragging": "robot_alert", "stunned": "sparks", "recharging": "robot_down", "off": "robot_down", "caged": "clunk"},
		"loop": ["servo", ["hunting", "dragging"]], "loop_moving": true},
	"watcher": {"step": "watcher_step", "stride": 0.9, "enter": {"moving>still": "watcher_creak"}},
	"mimic": {"step": "step_carpet", "stride": 0.75, "step_db": -4.0, "enter": {"leaving": "vault"}},
	"echo": {"enter": {"releasing": "echo_release"}, "loop": ["echo_hum", ["bound"]]},
}
## Faster than this (m/s) counts as moving; a jump further than TELEPORT in a frame is
## being put somewhere, not walking.
const MOVING := 0.25
const TELEPORT := 3.0

var npc: Node3D
var kind := ""
## What it's heard doing, for the tests: the last few states.
var state := ""
var loop_player: AudioStreamPlayer3D
var _last := Vector3.ZERO
var _walked := 0.0
var _speed := 0.0
var _idle_in := 0.0
var _dip := false


## Gives `npc` its sounds (if it's a kind with any). Call from its _ready.
static func attach(n: Node3D) -> SfxMonster:
	var k := kind_of(n)
	if k == "":
		return null
	var s := SfxMonster.new()
	s.name = "Voice"
	s.npc = n
	s.kind = k
	n.add_child(s)
	return s


static func kind_of(n: Node) -> String:
	if n is Shredder:
		return "shredder"
	if n is Custodian:
		return "custodian"
	if n is Watcher:
		return "watcher"
	if n is Mimic:
		return "mimic"
	if n is Echo:
		return "echo"
	return ""


func _ready() -> void:
	_last = npc.global_position
	state = _state_now()
	_idle_in = randf_range(1.0, 3.0)


func _process(delta: float) -> void:
	if delta <= 0.0 or not is_instance_valid(npc) or not npc.is_inside_tree():
		return
	var voice: Dictionary = VOICES[kind]
	var pos := npc.global_position
	var moved := Vector2(pos.x - _last.x, pos.z - _last.z).length()
	_last = pos
	if moved > TELEPORT:
		moved = 0.0
		_walked = 0.0
	# Positions arrive in steps over the network: smooth the speed over a moment.
	_speed = lerpf(_speed, moved / delta, minf(delta * 6.0, 1.0))
	var now := _state_now()
	if now != state:
		var said: String = voice.get("enter", {}).get(state + ">" + now, voice.get("enter", {}).get(now, ""))
		if said != "":
			_play(said)
		state = now
	if voice.has("step") and npc.visible:
		_walked += moved
		if _walked >= voice.stride:
			_walked = 0.0
			Sfx.play(npc.get_parent(), voice.step, npc.position, voice.get("step_db", 0.0))
	if voice.has("idle") and state in voice.idle[2]:
		_idle_in -= delta
		if _idle_in <= 0.0:
			_idle_in = randf_range(voice.idle[1].x, voice.idle[1].y)
			_play(voice.idle[0])
	if voice.has("loop"):
		var on: bool = state in voice.loop[1] and (not voice.get("loop_moving", false) or _speed > MOVING) and npc.visible
		if on and not is_instance_valid(loop_player):
			loop_player = Sfx.loop(npc, voice.loop[0], Vector3(0, 1.2, 0))
		elif not on and is_instance_valid(loop_player):
			loop_player.queue_free()
			loop_player = null
	if kind == "echo":
		# Its flicker nearly going out: a crackle of static with it.
		var dip: bool = fmod(npc.get("_t") + npc.get("phase"), 7.3) < 0.18 and state == "bound"
		if dip and not _dip:
			_play("flicker", -10.0)
		_dip = dip


## The state it's in, or for the Watcher, whether it's moving.
func _state_now() -> String:
	if kind == "watcher":
		return "moving" if _speed > MOVING else "still"
	return str(npc.get("state"))


func _play(sound: String, db := 0.0) -> void:
	Sfx.play(npc.get_parent(), sound, npc.position + Vector3(0, 1.4, 0), db)
