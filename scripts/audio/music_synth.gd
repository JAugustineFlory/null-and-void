class_name MusicSynth
## The score, made in code: a handful of layers the same length that loop together
## and fade in and out with the mood (Music). Dark, slow and mostly low: a building
## at night that might be listening.
##
## Everything sits on one 96 BPM grid, 16 beats (10 seconds) to a loop, and every
## tone is a whole number of cycles in that loop, so the layers never drift apart
## and the loop has no seam.

const RATE := 22050
const BPM := 96.0
const BEATS := 16
const BEAT := 60.0 / BPM
const LENGTH := BEAT * BEATS

## Every layer, quietest mood first.
const LAYERS := ["drone", "pad", "pulse", "heart", "tension", "relief"]


static func samples() -> int:
	return int(round(LENGTH * RATE))


## The layer called `name`, ready to loop, or null.
static func make(layer: String) -> AudioStreamWAV:
	if layer not in LAYERS:
		return null
	var n := samples()
	var out := PackedFloat32Array()
	out.resize(n)
	match layer:
		"drone": _drone(out)
		"pad": _pad(out)
		"pulse": _pulse(out)
		"heart": _heart(out)
		"tension": _tension(out)
		"relief": _relief(out)
	return SfxSynth._loop(SfxSynth._wav(out, RATE))


## Low A, two detuned voices beating slowly, and a fifth that swells in and out.
static func _drone(out: PackedFloat32Array) -> void:
	for i in out.size():
		var t := float(i) / RATE
		var swell := 0.5 - 0.5 * cos(TAU * t / LENGTH)
		out[i] = (sin(TAU * 55.0 * t) * 0.32 + sin(TAU * 55.2 * t) * 0.26 + sin(TAU * 110.0 * t) * 0.08
			+ sin(TAU * 82.4 * t) * 0.12 * swell)


## A minor chord that drifts down to F and back, soft-edged.
static func _pad(out: PackedFloat32Array) -> void:
	# Two chords, half the loop each: A minor (A C E), then F (F A C).
	var chords := [[220.0, 261.6, 329.6], [174.6, 220.0, 261.6]]
	var half := out.size() / 2
	for i in out.size():
		var t := float(i) / RATE
		var c: Array = chords[0 if i < half else 1]
		var into := float(i % half) / half
		var env := smoothstep(0.0, 0.15, into) * (1.0 - smoothstep(0.85, 1.0, into))
		var v := 0.0
		for f in c:
			v += sin(TAU * f * t) * 0.6 + sin(TAU * f * 1.003 * t) * 0.4
		out[i] = v * 0.1 * env


## A low pulse on every beat, the off-beat a little softer: something's ticking.
static func _pulse(out: PackedFloat32Array) -> void:
	for i in out.size():
		var t := float(i) / RATE
		var into := fmod(t, BEAT / 2.0)
		var on_beat := fmod(t, BEAT) < BEAT / 2.0
		var env := exp(-into * 18.0) * (1.0 if on_beat else 0.55)
		out[i] = (sin(TAU * 110.0 * t) * 0.5 + sin(TAU * 220.0 * t) * 0.2) * env * 0.7


## A heartbeat: two thumps a beat apart, every other beat.
static func _heart(out: PackedFloat32Array) -> void:
	for i in out.size():
		var t := float(i) / RATE
		var into := fmod(t, BEAT * 2.0)
		var v := 0.0
		for at in [0.0, 0.22]:
			if into >= at:
				var k: float = into - at
				v += sin(TAU * (60.0 - 25.0 * k) * k) * exp(-k * 14.0) * (1.0 if at == 0.0 else 0.7)
		out[i] = v * 0.85


## High, close, wavering strings a semitone apart: don't stop.
static func _tension(out: PackedFloat32Array) -> void:
	for i in out.size():
		var t := float(i) / RATE
		var tremolo := 0.6 + 0.4 * sin(TAU * 6.4 * t)
		var rise := 0.8 - 0.2 * cos(TAU * t / LENGTH)
		out[i] = (sin(TAU * 880.0 * t) + sin(TAU * 932.3 * t) * 0.8 + sin(TAU * 1318.5 * t) * 0.3) * 0.09 * tremolo * rise


## Relief at a checkpoint: an open A major chord, high and quiet, like a breath out.
static func _relief(out: PackedFloat32Array) -> void:
	for i in out.size():
		var t := float(i) / RATE
		var breathe := 0.7 + 0.3 * sin(TAU * t / LENGTH * 2.0)
		out[i] = (sin(TAU * 440.0 * t) + sin(TAU * 554.4 * t) * 0.8 + sin(TAU * 659.3 * t) * 0.7 + sin(TAU * 220.0 * t) * 0.5) * 0.09 * breathe
