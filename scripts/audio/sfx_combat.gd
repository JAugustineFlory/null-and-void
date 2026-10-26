class_name SfxCombat
extends Node
## A fight's sounds for one body: punches thrown and landing, blocks, hits taken,
## the guard going up and going down. Every machine hears the same fight, each
## worked out from something every machine already has:
##   your own player: its PlayerCombat's signals (swung, blocked, hurt ...);
##   a teammate's puppet: the fists their machine sends (PlayerPuppet.fighting)
##     and lying down (CrewVitals sets that everywhere);
##   Rourke and the Custodian (watch): what the host replicates of them
##     (hits_left, strikes, Rourke's wind-up), so a punch landing on them is heard
##     by the whole crew, not just whoever threw it.

## A teammate's fists, as their machine sends them, and what you hear.
const PUPPET := {"jab": "swing", "cross": "swing", "guard": "guard", "recoil": "block", "flinch": "hurt"}
## Where on a body a fight is heard from.
const CHEST := Vector3(0, 1.2, 0)

var body: Node3D
## What played, newest last (tests). The last few only.
var heard: Array = []
var _fists := ""
var _down := false
## Rourke's hits left, or the Custodian's strikes taken.
var _hits := 0
var _windup := 0.0


## Fight sounds for a player or a teammate's puppet (SfxSteps.attach adds these).
static func attach(b: Node3D) -> SfxCombat:
	var s := SfxCombat.new()
	s.name = "FightSounds"
	s.body = b
	b.add_child(s)
	return s


## Rourke or the Custodian: punches landing on them, Rourke's swings and his going down.
static func watch(npc: Node3D) -> SfxCombat:
	return attach(npc)


func _ready() -> void:
	var combat = body.get("combat")
	if combat is PlayerCombat:
		Sfx.warm_fight()
		combat.swung.connect(_play.bind("swing"))
		combat.guard_raised.connect(_play.bind("guard"))
		combat.blocked.connect(func(_cause): _play("block"))
		combat.hurt.connect(_on_hurt)
		combat.went_down.connect(func(_cause): _play("body_fall"))
		set_process(false)
		return
	if body is Rourke:
		_hits = body.hits_left
		_windup = body.get("_windup")
	elif body is Custodian:
		_hits = body.strikes
	elif "fighting" in body:
		_fists = body.fighting
		_down = body.downed


## The punch bag's hits are its own thud; a fall's landing is the steps' to play.
func _on_hurt(_amount: float, cause: String) -> void:
	if cause == "spar":
		_play("bag_hit")
	elif cause != "fall":
		_play("hurt")


func _process(_delta: float) -> void:
	if not is_instance_valid(body):
		return
	if body is Rourke:
		_rourke()
	elif body is Custodian:
		var strikes: int = body.strikes
		if strikes > _hits:
			_play("punch_metal")
		_hits = strikes
	elif "fighting" in body:
		_puppet()


## A teammate's fists change, or they hit the floor.
func _puppet() -> void:
	var fists: String = body.fighting
	if fists != _fists and PUPPET.has(fists):
		_play(PUPPET[fists])
	_fists = fists
	var down: bool = body.downed
	if down and not _down:
		_play("body_fall")
	_down = down


## A punch lands on him (his hits left drop), the last one puts him down, and a
## wind-up that runs out without him being hit is his swing.
func _rourke() -> void:
	var left: int = body.hits_left
	var windup: float = body.get("_windup")
	if left < _hits:
		_play("punch_hit")
		if left <= 0:
			_play("body_fall")
	elif _windup > 0.0 and windup <= 0.0:
		_play("swing")
	_hits = left
	_windup = windup


func _play(kind: String) -> void:
	heard.append(kind)
	if heard.size() > 16:
		heard.pop_front()
	Sfx.play(body.get_parent(), kind, body.position + CHEST)
