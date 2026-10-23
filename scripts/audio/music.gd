class_name Music
extends Node
## The adaptive score. Every layer (MusicSynth) loops together all the time; the
## mood only fades each one up or down, so a change never jumps a beat.
## A level sets the mood from code every machine runs (a sync.event handler or
## a state every machine sees), so the whole team hears the same music:
##   Music.of(self).set_mood("hunted")
##
## A recorded track in audio/music/<layer>.ogg replaces that layer (it must be
## the same length: 16 beats at 96 BPM, 10 seconds).

const DIR := "res://audio/music/"
## How loud each layer is in each mood, 0 to 1. Layers not listed are silent.
const MOODS := {
	"silent": {},
	## Exploring: something low underneath, a chord that won't settle.
	"calm": {"drone": 0.6, "pad": 0.5},
	## WARDEN has turned, or the escort's gone: a pulse comes in.
	"uneasy": {"drone": 0.8, "pad": 0.25, "pulse": 0.6},
	## Something is looking for you.
	"hunted": {"drone": 1.0, "pulse": 0.8, "heart": 0.7, "tension": 0.3},
	## It has seen you. Run.
	"chase": {"drone": 1.0, "pulse": 1.0, "heart": 1.0, "tension": 1.0},
	## Safe for now.
	"checkpoint": {"drone": 0.3, "relief": 0.8},
}
## Seconds for a layer to fade fully in or out. Danger comes in faster than it leaves.
const FADE_IN := 1.5
const FADE_OUT := 4.0
const SILENT_DB := -60.0
## Every layer sits this far down, so a full chase doesn't clip.
const BASE_DB := -6.0

var mood := "silent"
## Layer name -> its player.
var layers := {}
## Layer name -> how loud it is right now, 0 to 1.
var level := {}


## The one Music for this game, made the first time it's asked for.
static func of(node: Node) -> Music:
	var root := node.get_tree().root
	var m := root.get_node_or_null("Music") as Music
	if m == null:
		m = Music.new()
		m.name = "Music"
		root.add_child(m)
	return m


## True once every layer is made and ready to play (it takes half a second, on
## another thread, so the game doesn't stall).
var ready_to_play := false


func _ready() -> void:
	Sfx.ensure_buses()
	for layer in MusicSynth.LAYERS:
		var p := AudioStreamPlayer.new()
		p.name = layer
		p.bus = Sfx.MUSIC
		p.volume_db = SILENT_DB
		add_child(p)
		layers[layer] = p
		level[layer] = 0.0
	WorkerThreadPool.add_task(_make_layers)


func _make_layers() -> void:
	var made := {}
	for layer in MusicSynth.LAYERS:
		made[layer] = _stream(layer)
	_layers_made.call_deferred(made)


func _layers_made(made: Dictionary) -> void:
	for layer in made:
		layers[layer].stream = made[layer]
	ready_to_play = true
	set_mood(mood)


## Changes the mood: "silent", "calm", "uneasy", "hunted", "chase" or "checkpoint".
func set_mood(new_mood: String) -> void:
	if not MOODS.has(new_mood):
		push_error("Music: no mood called '%s'" % new_mood)
		return
	mood = new_mood
	# Start every layer together, at the same point, so they stay in time.
	if ready_to_play and not MOODS[mood].is_empty() and not layers.values().any(func(p): return p.playing):
		for p in layers.values():
			p.play()


## Where `layer` is heading in the current mood, 0 to 1.
func target(layer: String) -> float:
	return MOODS[mood].get(layer, 0.0)


func _process(delta: float) -> void:
	var any := false
	for layer in layers:
		var goal := target(layer)
		var now: float = level[layer]
		if now < goal:
			now = minf(goal, now + delta / FADE_IN)
		elif now > goal:
			now = maxf(goal, now - delta / FADE_OUT)
		level[layer] = now
		layers[layer].volume_db = linear_to_db(now) + BASE_DB if now > 0.001 else SILENT_DB
		any = any or now > 0.0
	if not any and mood == "silent":
		for p in layers.values():
			p.stop()


func _stream(layer: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(DIR + layer + ext):
			var s: AudioStream = load(DIR + layer + ext)
			if s is AudioStreamOggVorbis:
				s.loop = true
			return s
	return MusicSynth.make(layer)
