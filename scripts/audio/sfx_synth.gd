class_name SfxSynth
## Sounds made in code: the building's electrical noises (tube buzz, flicker crackle,
## CRT whine, server hum, beeps, key clicks, door motors), the security wing's
## knocks and breaks, and a fight's whooshes and falls. Tiny, and nothing to license. Sfx uses these whenever
## audio/sfx/ has no recorded file of the same name.

const RATE := 22050
## The CRT whine sits near 15.7 kHz, above what RATE can hold.
const HI_RATE := 44100

## Every sound this file can make.
const KINDS := ["glass", "clunk", "click", "clatter", "tap", "beep", "error", "key", "flicker",
	"door_motor", "swing", "body_fall", "fluorescent_buzz", "crt_whine", "server_hum"]
## The ones that loop (seamlessly).
const LOOPS := ["fluorescent_buzz", "crt_whine", "server_hum"]


## The sound called `kind`, or null if there's no such sound.
static func make(kind: String) -> AudioStreamWAV:
	match kind:
		"fluorescent_buzz": return _buzz()
		"crt_whine": return _crt()
		"server_hum": return _server()
	if kind not in KINDS:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var secs: float = {"glass": 0.6, "clunk": 0.35, "click": 0.06, "clatter": 0.7, "tap": 0.9,
		"beep": 0.14, "error": 0.42, "key": 0.05, "flicker": 0.22, "door_motor": 1.1,
		"swing": 0.28, "body_fall": 0.7}.get(kind, 0.3)
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var lower := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		match kind:
			"glass":
				# Bright noise with high rings, gone fast.
				v = (rng.randf_range(-1, 1) * 0.6 + sin(TAU * 3100 * t) * 0.25 + sin(TAU * 4700 * t) * 0.15) * exp(-t * 9.0)
			"clunk":
				# A low thud: filtered noise and a falling tone.
				low = lerpf(low, rng.randf_range(-1, 1), 0.08)
				v = (low * 1.5 + sin(TAU * (90 - 40 * t) * t) * 0.7) * exp(-t * 14.0)
			"click":
				v = rng.randf_range(-1, 1) * exp(-t * 120.0)
			"clatter":
				# Sheet metal hitting the floor, twice.
				var hit := exp(-t * 12.0) + (exp(-(t - 0.22) * 16.0) * 0.6 if t > 0.22 else 0.0)
				v = (rng.randf_range(-1, 1) * 0.5 + sin(TAU * 620 * t) * 0.3 + sin(TAU * 1330 * t) * 0.2) * hit
			"tap":
				# A knuckle on a steel door: a sharp knock and a long, low ring.
				v = rng.randf_range(-1, 1) * exp(-t * 90.0) * 0.8 + (sin(TAU * 210 * t) * 0.5 + sin(TAU * 537 * t) * 0.25) * exp(-t * 4.0)
			"beep":
				# An old terminal's beep: a soft square wave, clicked on and off.
				v = signf(sin(TAU * 880 * t)) * 0.35 * _edges(t, secs, 0.004)
			"error":
				# Two low, rough buzzes: no.
				var on := 1.0 if (t < 0.17 or t > 0.24) else 0.0
				v = (signf(sin(TAU * 196 * t)) * 0.3 + sin(TAU * 98 * t) * 0.2) * on * _edges(fmod(t, 0.24), 0.17, 0.006)
			"key":
				# One key of a heavy keyboard: a plastic tick and a short thock under it.
				low = lerpf(low, rng.randf_range(-1, 1), 0.3)
				v = rng.randf_range(-1, 1) * exp(-t * 400.0) * 0.6 + low * exp(-t * 90.0) * 1.2 + sin(TAU * 320 * t) * exp(-t * 120.0) * 0.3
			"flicker":
				# A failing tube catching: a few fast electrical snaps over a stuttering buzz.
				var snaps := 0.0
				for s in [0.0, 0.05, 0.08, 0.15]:
					if t >= s:
						snaps += exp(-(t - s) * 260.0)
				var stutter := 0.5 + 0.5 * signf(sin(TAU * 31 * t))
				v = rng.randf_range(-1, 1) * snaps * 0.7 + _mains(t) * 0.35 * stutter * exp(-t * 6.0)
			"door_motor":
				# A motor spinning up, running, spinning down; gears chatter on top.
				var speed := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.8, secs, t))
				phase += TAU * (40.0 + 70.0 * speed) / RATE
				low = lerpf(low, rng.randf_range(-1, 1), 0.15)
				var gear := 0.5 + 0.5 * sin(phase * 6.0)
				v = (sin(phase) * 0.45 + sin(phase * 2.0) * 0.2 + low * gear * 0.6) * speed
			"swing":
				# A fist through the air: a band of noise that rises in pitch and is gone.
				var k := lerpf(0.04, 0.35, t / secs)
				low = lerpf(low, rng.randf_range(-1, 1), k)
				lower = lerpf(lower, low, k * 0.25)
				v = (low - lower) * 2.2 * sin(PI * t / secs) ** 2
			"body_fall":
				# Someone going down: knees, then the rest of them, and their clothes.
				var hit := exp(-t * 18.0) * 0.6 + (exp(-(t - 0.16) * 11.0) if t > 0.16 else 0.0)
				low = lerpf(low, rng.randf_range(-1, 1), 0.06)
				var cloth := rng.randf_range(-1, 1) * 0.08 * exp(-absf(t - 0.25) * 9.0)
				v = (low * 2.0 + sin(TAU * 70 * t) * 0.5) * hit + cloth
		out[i] = v
	return _wav(out, RATE)


## Fluorescent tubes on a magnetic ballast: a 120 Hz buzz with a rasp in it.
## Two seconds that loop with no seam.
static func _buzz() -> AudioStreamWAV:
	var n := RATE * 2
	var out := _noise("fluorescent_buzz", n, 0.6)
	for i in n:
		out[i] = _mains(float(i) / RATE) * 0.5 + out[i] * 0.04
	return _loop(_wav(out, RATE))


## An old monitor: the thin flyback whine, a little mains hum and a static fizz.
static func _crt() -> AudioStreamWAV:
	var n := HI_RATE
	var out := _noise("crt_whine", n, 1.0)
	for i in n:
		var t := float(i) / HI_RATE
		out[i] = sin(TAU * 15734 * t) * 0.12 + sin(TAU * 60 * t) * 0.18 + sin(TAU * 120 * t) * 0.08 + out[i] * 0.03
	return _loop(_wav(out, HI_RATE))


## A rack of servers: fan rush, a low hum and a slow swell between two fans.
static func _server() -> AudioStreamWAV:
	var n := RATE * 4
	var rush := _noise("server_hum", n, 0.25)
	var deep := _noise("server_hum_deep", n, 0.012)
	for i in n:
		var t := float(i) / RATE
		var beat := 0.8 + 0.2 * sin(TAU * 0.5 * t)
		rush[i] = (rush[i] * 0.35 + deep[i] * 2.5) * beat + sin(TAU * 60 * t) * 0.15 + sin(TAU * 180 * t) * 0.05
	return _loop(_wav(rush, RATE))


## Mains buzz: 120 Hz and its odd-sounding harmonics, slightly clipped like a ballast.
static func _mains(t: float) -> float:
	var v := sin(TAU * 120 * t) + sin(TAU * 240 * t) * 0.5 + sin(TAU * 360 * t) * 0.35 + sin(TAU * 600 * t) * 0.15
	return clampf(v * 0.8, -0.7, 0.7)


## 0 to 1 and back at the ends of a sound `secs` long, so it never clicks on.
static func _edges(t: float, secs: float, ramp: float) -> float:
	return clampf(t / ramp, 0.0, 1.0) * clampf((secs - t) / ramp, 0.0, 1.0)


## `n` samples of noise smoothed by `smooth` (1 = raw, smaller = darker), whose end
## runs on into its start, so it loops with no seam. Tones mixed over it need whole
## cycles in `n` samples.
static func _noise(seed_name: String, n: int, smooth: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_name)
	var fade := n / 10
	var s := PackedFloat32Array()
	s.resize(n + fade)
	var v := 0.0
	for i in s.size():
		v = lerpf(v, rng.randf_range(-1, 1), smooth)
		s[i] = v
	var out := s.slice(0, n)
	for i in fade:
		var w := float(i) / fade
		out[i] = s[i] * w + s[n + i] * (1.0 - w)
	return out


static func _wav(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 26000))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


static func _loop(w: AudioStreamWAV) -> AudioStreamWAV:
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = w.data.size() / 2
	return w
