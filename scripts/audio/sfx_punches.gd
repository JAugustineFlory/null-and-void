class_name SfxPunches
## A fight's impacts, made in code: punches landing, hits taken, blocks, the punch
## bag and the guard going up. Augustine's playtest: the recorded punches were all
## low thud (nothing a laptop speaker can play, so they sounded weak), and the
## guard's rustle was a belt buckle that jingled like keys on every block.
##
## Each is built the way Foley punches are, from layers:
##   crack  a few milliseconds of bright noise: skin on skin, what reads as "a hit";
##   slap   a band of mid noise: the meat of it, and what small speakers carry;
##   body   a low thump that drops in pitch: the weight;
##   cloth  a soft fabric snap or swish (blocks, the guard).
## Every kind comes in VARIANTS takes, so a flurry of punches doesn't repeat.
## A recorded file in audio/sfx/ still replaces any of them (Sfx.stream).

const RATE := 44100
const VARIANTS := 4
## How loud each layer is (each is made at full scale, then mixed), how long the
## sound is, the slap's band (higher k is brighter), and the body's pitch drop and fade.
const KINDS := {
	"punch_hit": {"secs": 0.3, "crack": 0.5, "slap": 1.0, "slap_k": 0.17, "body": 0.5, "from": 170.0, "to": 80.0, "decay": 32.0},
	"hurt": {"secs": 0.4, "crack": 0.5, "slap": 1.0, "slap_k": 0.14, "body": 0.7, "from": 140.0, "to": 55.0, "decay": 20.0},
	"block": {"secs": 0.22, "slap": 0.8, "slap_k": 0.07, "body": 0.6, "from": 210.0, "to": 140.0, "decay": 34.0, "cloth": 0.45},
	"bag_hit": {"secs": 0.45, "crack": 0.25, "slap": 1.0, "slap_k": 0.1, "body": 0.8, "from": 100.0, "to": 55.0, "decay": 14.0},
	"guard": {"secs": 0.2, "swish": 1.0},
}


## Take `variant` of `kind`, or null if this file doesn't make it.
static func make(kind: String, variant := 0) -> AudioStreamWAV:
	if not KINDS.has(kind):
		return null
	var p: Dictionary = KINDS[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + variant * 7919
	var jitter := func(v: float, by: float) -> float: return v * rng.randf_range(1.0 - by, 1.0 + by)
	var secs: float = p.secs
	var n := int(secs * RATE)
	var layers := {}
	if p.has("crack"):
		layers["crack"] = _crack(rng, n)
	if p.has("slap"):
		layers["slap"] = _slap(rng, n, jitter.call(p.slap_k, 0.2))
	if p.has("body"):
		layers["body"] = _body(rng, n, jitter.call(p.from, 0.12), jitter.call(p.to, 0.12), jitter.call(p.decay, 0.15))
	if p.has("cloth"):
		layers["cloth"] = _cloth(rng, n, false)
	if p.has("swish"):
		layers["swish"] = _cloth(rng, n, true)
	var out := PackedFloat32Array()
	out.resize(n)
	for layer in layers:
		var s: PackedFloat32Array = layers[layer]
		var gain: float = p[layer] / maxf(_peak(s), 0.0001)
		for i in n:
			out[i] += s[i] * gain
	# Full scale, with a short fade at the end so nothing clicks off.
	var scale := 0.95 / maxf(_peak(out), 0.0001)
	for i in n:
		out[i] *= scale * clampf(float(n - i) / (RATE * 0.01), 0.0, 1.0)
	return SfxSynth._wav(out, RATE)


## Every take of `kind`, picked at random each time it plays.
static func takes(kind: String) -> AudioStreamRandomizer:
	var r := AudioStreamRandomizer.new()
	r.random_pitch = 1.0
	for v in VARIANTS:
		r.add_stream(-1, make(kind, v))
	return r


## Bright noise, gone in a few milliseconds.
static func _crack(rng: RandomNumberGenerator, n: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	var low := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := rng.randf_range(-1, 1)
		low = lerpf(low, x, 0.3)
		s[i] = (x - low) * _attack(t, 0.0008) * exp(-t * 260.0)
	return s


## A band of noise (between two smoothings of it), quick in and fading fast.
static func _slap(rng: RandomNumberGenerator, n: int, k: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	var a := 0.0
	var b := 0.0
	for i in n:
		var t := float(i) / RATE
		a = lerpf(a, rng.randf_range(-1, 1), k)
		b = lerpf(b, a, k * 0.2)
		s[i] = (a - b) * _attack(t, 0.0015) * exp(-t * 38.0)
	return s


## A thump whose pitch drops from `from` to `to` Hz, with an octave above it so a
## small speaker still gives it some weight, and dark noise for texture.
static func _body(rng: RandomNumberGenerator, n: int, from: float, to: float, decay: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	var low := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (to + (from - to) * exp(-t * 30.0)) / RATE
		low = lerpf(low, rng.randf_range(-1, 1), 0.02)
		s[i] = (sin(phase) + sin(phase * 2.0) * 0.3 + low * 3.0) * _attack(t, 0.003) * exp(-t * decay)
	return s


## Fabric: a short snap (a block's sleeves), or a swell and fade (`swish`, the guard going up).
static func _cloth(rng: RandomNumberGenerator, n: int, swish: bool) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	var a := 0.0
	var b := 0.0
	var secs := float(n) / RATE
	for i in n:
		var t := float(i) / RATE
		# A sleeve snapping is brighter than a sleeve sweeping up.
		a = lerpf(a, rng.randf_range(-1, 1), 0.15 if swish else 0.4)
		b = lerpf(b, a, 0.03 if swish else 0.1)
		var env := sin(PI * t / secs) ** 2 if swish else _attack(t, 0.002) * exp(-t * 70.0)
		s[i] = (a - b) * env
	return s


static func _attack(t: float, ramp: float) -> float:
	return minf(t / ramp, 1.0)


static func _peak(s: PackedFloat32Array) -> float:
	var peak := 0.0
	for v in s:
		peak = maxf(peak, absf(v))
	return peak
