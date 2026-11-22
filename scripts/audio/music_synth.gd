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
const LAYERS := ["drone", "pad", "pulse", "heart", "tension", "relief", "siren", "lobby", "lobby_off"]
## The lobby's tune runs twice as long as the rest (two loops of theirs, so it stays
## in time with them), and it comes out of a ceiling speaker, so it's made at a
## lower rate: no top end, and half the memory.
const LOBBY_LAYERS := ["lobby", "lobby_off"]
const LOBBY_RATE := 11025
const LOBBY_LOOPS := 2


static func samples() -> int:
	return int(round(LENGTH * RATE))


## How long `layer` runs before it loops, in seconds: always a whole number of the
## others' loops, so every layer comes round together.
static func seconds(layer: String) -> float:
	return LENGTH * (LOBBY_LOOPS if layer in LOBBY_LAYERS else 1)


## The layer called `name`, ready to loop, or null.
static func make(layer: String) -> AudioStreamWAV:
	if layer not in LAYERS:
		return null
	if layer in LOBBY_LAYERS:
		return SfxSynth._loop(SfxSynth._wav(_lobby(layer == "lobby_off"), LOBBY_RATE))
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
		"siren": _siren(out)
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



## The one-off sounds the score plays over its layers, or null: "sealed", as the
## building locks the crew in (a deep boom, and a cluster of low brass that swells
## and won't resolve; four seconds), and "locked", a short stab when a door won't give.
static func sting(kind: String) -> AudioStreamWAV:
	if kind == "locked":
		return _locked_sting()
	if kind != "sealed":
		return null
	var n := int(4.0 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	# A semitone cluster, low: nothing in it agrees with anything else.
	var cluster := [73.4, 77.8, 82.4, 110.0, 116.5]
	for i in n:
		var t := float(i) / RATE
		var boom := sin(TAU * (48.0 - 18.0 * minf(t, 1.0)) * t) * exp(-t * 3.0) * 0.8
		var swell := smoothstep(0.05, 1.4, t) * (1.0 - smoothstep(2.4, 4.0, t))
		var brass := 0.0
		for f in cluster:
			brass += sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.35 + sin(TAU * f * 3.0 * t) * 0.15
		out[i] = boom * clampf(t / 0.004, 0.0, 1.0) + brass * swell * 0.09
	return SfxSynth._wav(out, RATE)


## "locked": a locked door won't give. A low string stab, a tritone, that dies away
## over a second and a half.
static func _locked_sting() -> AudioStreamWAV:
	var n := int(1.5 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := clampf(t / 0.02, 0.0, 1.0) * exp(-t * 2.6)
		var bow := 0.85 + 0.15 * sin(TAU * 5.5 * t)
		var v := 0.0
		for f in [98.0, 138.6, 196.0]:
			v += sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.4 + sin(TAU * f * 3.0 * t) * 0.2
		out[i] = v * env * bow * 0.18
	return SfxSynth._wav(out, RATE)


## An alarm somewhere in the building, two notes a semitone apart trading on the
## beat, through a wall: it isn't the music, but the music won't ignore it.
static func _siren(out: PackedFloat32Array) -> void:
	for i in out.size():
		var t := float(i) / RATE
		var into := fmod(t, BEAT) / BEAT
		# Which note: high on even beats; a quick glide between them, not a click.
		var high := int(t / BEAT) % 2 == 0
		var glide := smoothstep(0.0, 0.08, into)
		var mix := glide if high else 1.0 - glide
		var tone := lerpf(sin(TAU * 493.9 * t) + sin(TAU * 1481.7 * t) * 0.15, sin(TAU * 466.2 * t) + sin(TAU * 1398.6 * t) * 0.15, 1.0 - mix)
		var swell := 0.75 + 0.25 * sin(TAU * t / LENGTH * 4.0)
		out[i] = tone * 0.22 * swell


# --- The lobby -------------------------------------------------------------------
# Music for a lobby: soft electric piano, a vibraphone tune, a walking bass and a
# brushed shaker, in F, through a ceiling speaker. It sounds like any office
# building's hold music. Nearly: the tape wavers a little, and the tune's last note
# sags flat and hangs there. The other layer (lobby_off) is its shadow: the same
# tune a little flat, swelling up behind each note instead of fading, over a chord
# that won't sit still. Quiet under the lobby while things are fine; once they
# aren't, it's most of what's left.

## Eight bars, one chord each (MIDI notes), with the bass's root and fifth. Bar 4
## turns to C7 halfway.
const LOBBY_CHORDS := [
	[[53, 57, 60, 64], 41, 48], [[52, 55, 57, 60], 45, 52], [[50, 53, 57, 60], 38, 45], [[50, 53, 55, 58], 43, 36],
	[[53, 57, 60, 64], 41, 48], [[52, 55, 57, 60], 45, 52], [[50, 53, 57, 58], 46, 41], [[53, 55, 58, 60], 36, 43],
]
## Bar 4's second chord, from its third beat.
const LOBBY_TURN := [52, 55, 58, 60]
## The tune: [bar, beat, MIDI note, beats long].
const LOBBY_TUNE := [
	[0, 0.0, 69, 1.5], [0, 1.5, 72, 0.5], [0, 2.0, 76, 1.0], [0, 3.0, 74, 1.0],
	[1, 0.0, 72, 2.0], [1, 2.0, 69, 1.0], [1, 3.0, 67, 1.0],
	[2, 0.0, 65, 1.0], [2, 1.0, 69, 1.0], [2, 2.0, 72, 1.5], [2, 3.5, 74, 0.5],
	[3, 0.0, 74, 1.5], [3, 1.5, 70, 0.5], [3, 2.0, 67, 2.0],
	[4, 0.0, 69, 1.5], [4, 1.5, 72, 0.5], [4, 2.0, 76, 1.0], [4, 3.0, 79, 1.0],
	[5, 0.0, 76, 2.0], [5, 2.0, 72, 1.0], [5, 3.0, 69, 1.0],
	[6, 0.0, 74, 1.0], [6, 1.0, 77, 1.0], [6, 2.0, 81, 1.0], [6, 3.0, 79, 1.0],
	[7, 0.0, 77, 1.5], [7, 1.5, 76, 0.5], [7, 2.0, 72, 2.0],
]
## The tape's waver: how far the pitch drifts (a fraction) and how fast (Hz, a whole
## number of times a loop, so the loop has no seam).
const WOW_DEPTH := 0.003
const WOW_HZ := 0.35
## The last note sags this many semitones as it hangs.
const SAG := 0.35
## The shadow sits this many semitones under the tune.
const SHADOW := 0.4


static func _midi(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


static func _lobby(shadow: bool) -> PackedFloat32Array:
	var n := int(round(seconds("lobby") * LOBBY_RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var bar := BEAT * 4.0
	if shadow:
		for b in LOBBY_CHORDS.size():
			for note in LOBBY_CHORDS[b][0]:
				_lobby_note(out, "drift", b * bar, bar, _midi(note - 12 - SHADOW), 0.05)
	else:
		for b in LOBBY_CHORDS.size():
			var chord: Array = LOBBY_CHORDS[b][0]
			var turn: Array = LOBBY_TURN if b == 3 else chord
			# Electric piano: on the one, and softer on the and of two.
			for note in chord:
				_lobby_note(out, "keys", b * bar, BEAT * 1.4, _midi(note), 0.085)
			for note in turn:
				_lobby_note(out, "keys", b * bar + BEAT * 1.5, BEAT * 1.0, _midi(note), 0.055)
			_lobby_note(out, "bass", b * bar, BEAT * 1.6, _midi(LOBBY_CHORDS[b][1]), 0.3)
			_lobby_note(out, "bass", b * bar + BEAT * 2.0, BEAT * 1.6, _midi(LOBBY_CHORDS[b][2]), 0.26)
		_shaker(out)
	var last: Array = LOBBY_TUNE.back()
	for note in LOBBY_TUNE:
		var at: float = note[0] * bar + note[1] * BEAT
		var f := _midi(note[2] - (SHADOW if shadow else 0.0))
		var sag: float = SAG if note == last else 0.0
		_lobby_note(out, "ghost" if shadow else "vibes", at, note[3] * BEAT, f, 0.16 if shadow else 0.2, sag)
	return out


## One note into `out`, starting `at` seconds in and held `held` seconds, then let
## go. A tail that runs past the end comes round to the start, so the loop has no
## seam. The tape's waver bends every note the same way at the same moment.
static func _lobby_note(out: PackedFloat32Array, kind: String, at: float, held: float, freq: float, amp: float, sag := 0.0) -> void:
	var n := out.size()
	var tail: float = {"keys": 0.35, "vibes": 0.5, "bass": 0.08, "ghost": 0.12, "drift": 0.6}[kind]
	var length := int((held + tail) * LOBBY_RATE)
	var start := int(at * LOBBY_RATE)
	var phase := 0.0
	for k in length:
		var s := float(k) / LOBBY_RATE
		var t := float(start + k) / LOBBY_RATE
		var bend := pow(2.0, -sag * smoothstep(0.15, 1.1, s) / 12.0) if sag > 0.0 else 1.0
		phase += TAU * freq * bend * (1.0 + WOW_DEPTH * sin(TAU * WOW_HZ * t)) / LOBBY_RATE
		var let_go := 1.0 if s < held else exp(-(s - held) / (tail / 5.0))
		var attack := clampf(s / 0.006, 0.0, 1.0)
		var v := 0.0
		match kind:
			"keys":
				# A struck tine: bright as it's hit, mellowing fast.
				v = sin(phase + 1.3 * exp(-s / 0.35) * sin(phase)) * exp(-s / 1.1)
			"vibes":
				v = (sin(phase) + 0.22 * sin(4.0 * phase) * exp(-s / 0.2)) * exp(-s / 1.4) * (0.82 + 0.18 * sin(TAU * 5.0 * t))
			"bass":
				v = (sin(phase) + 0.3 * sin(2.0 * phase)) * exp(-s / 0.6)
			"ghost":
				# Comes up behind the note instead of fading after it.
				attack = smoothstep(0.0, held, s)
				v = sin(phase) * (0.75 + 0.25 * sin(TAU * 3.0 * t))
			"drift":
				attack = smoothstep(0.0, held * 0.5, s)
				v = sin(phase) + 0.5 * sin(phase * 1.004)
		out[(start + k) % n] += v * amp * attack * let_go


## A soft brushed shaker on every off-beat.
static func _shaker(out: PackedFloat32Array) -> void:
	var n := out.size()
	var hiss := SfxSynth._noise("lobby_shaker", int(0.08 * LOBBY_RATE), 1.0)
	var low := 0.0
	var beats := int(round(seconds("lobby") / BEAT))
	for b in beats:
		var start := int((b + 0.5) * BEAT * LOBBY_RATE)
		var amp := 0.05 if b % 2 == 1 else 0.035
		for k in hiss.size():
			low = lerpf(low, hiss[k], 0.3)
			var s := float(k) / LOBBY_RATE
			out[(start + k) % n] += (hiss[k] - low) * amp * clampf(s / 0.01, 0.0, 1.0) * exp(-s / 0.025)
