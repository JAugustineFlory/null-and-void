class_name SfxCreatures
## The monsters' voices and bodies, made in code at half rate (nothing in them needs
## more): the Shredder's breath, roar, snarl and footfalls; the Custodian's servos,
## clanking feet, boot-up, alarm, sparks and power-down; the Watcher's dragging steps
## and creaking joints; an Echo's cold hum and its release. SfxMonster plays them.
## A recorded file of the same name in audio/sfx/ wins, as for every Sfx kind.

const RATE := 11025

## Every sound this file makes, and how long each is (seconds).
const KINDS := {"shredder_breath": 1.6, "shredder_roar": 1.4, "shredder_snarl": 0.6, "heavy_step": 0.35,
	"servo": 1.0, "robot_step": 0.4, "robot_boot": 1.2, "robot_alert": 0.5, "robot_down": 1.0, "sparks": 0.5,
	"watcher_step": 0.5, "watcher_creak": 0.7, "echo_hum": 2.0, "echo_release": 2.2}
## The ones that loop (seamlessly).
const LOOPS := ["servo", "echo_hum"]


## The sound called `kind`, or null if it isn't one of these.
static func make(kind: String) -> AudioStreamWAV:
	if not KINDS.has(kind):
		return null
	match kind:
		"servo": return _servo()
		"echo_hum": return _echo_hum()
	var secs: float = KINDS[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
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
			"shredder_breath":
				# A big, blind thing breathing: a long wet draw in through the throat, and out.
				low = lerpf(low, rng.randf_range(-1, 1), 0.12)
				lower = lerpf(lower, low, 0.05)
				var draw := smoothstep(0.0, 0.6, t) * (1.0 - smoothstep(0.6, 0.75, t)) * 0.7
				var out_breath := smoothstep(0.75, 0.9, t) * (1.0 - smoothstep(1.0, secs, t))
				var throat := 0.6 + 0.4 * absf(sin(TAU * 23.0 * t))
				v = ((low - lower) * 1.6 * throat + sin(TAU * 52 * t) * 0.12) * (draw + out_breath)
			"shredder_roar":
				# Woken: a growl that rises out of its chest, rough and torn, and dies away.
				var f := 70.0 + 45.0 * sin(PI * minf(t / 0.9, 1.0)) - 15.0 * maxf(0.0, t - 0.9)
				phase += TAU * f / RATE
				low = lerpf(low, rng.randf_range(-1, 1), 0.2)
				var rough := 0.6 + 0.4 * signf(sin(phase * 0.5)) * (0.5 + 0.5 * rng.randf())
				var saw := fposmod(phase / TAU, 1.0) * 2.0 - 1.0
				var env := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.8, secs, t))
				v = (saw * 0.45 * rough + sin(phase * 2.0) * 0.15 + low * 0.5) * env
			"shredder_snarl":
				# Something heard: a short, wet snarl as it turns.
				phase += TAU * (120.0 + 30.0 * sin(TAU * 3.0 * t)) / RATE
				low = lerpf(low, rng.randf_range(-1, 1), 0.3)
				var gurgle := 0.5 + 0.5 * sin(TAU * 31.0 * t)
				var saw := fposmod(phase / TAU, 1.0) * 2.0 - 1.0
				v = (saw * 0.4 * gurgle + low * 0.45) * smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.3, secs, t))
			"heavy_step":
				# One of its feet coming down: a deep thud through the floor.
				low = lerpf(low, rng.randf_range(-1, 1), 0.08)
				v = (low * 2.0 + sin(TAU * 45 * t) * 0.7) * exp(-t * 14.0)
			"robot_step":
				# A steel foot set down: a thud, and the frame ringing over it.
				low = lerpf(low, rng.randf_range(-1, 1), 0.1)
				v = low * 1.6 * exp(-t * 20.0) + (sin(TAU * 310 * t) * 0.3 + sin(TAU * 740 * t) * 0.15) * exp(-t * 9.0)
			"robot_boot":
				# Powering up: relays clacking in, then a motor whine climbing to speed.
				for c in [0.0, 0.1, 0.18]:
					if t >= c:
						v += rng.randf_range(-1, 1) * exp(-(t - c) * 120.0) * 0.6
				if t > 0.25:
					var k := minf((t - 0.25) / 0.7, 1.0)
					phase += TAU * (200.0 + 700.0 * k * k) / RATE
					v += (sin(phase) * 0.3 + sin(phase * 2.0) * 0.1) * smoothstep(0.25, 0.4, t) * (1.0 - smoothstep(1.0, secs, t))
			"robot_alert":
				# It has someone: two hard blips, high then low.
				var f := 880.0 if t < 0.2 else 660.0
				var on := _edges(t, 0.18, 0.004) if t < 0.2 else _edges(t - 0.24, 0.22, 0.004)
				v = (signf(sin(TAU * f * t)) * 0.25 + sin(TAU * f * t) * 0.15) * on
			"robot_down":
				# Its power going: the whine falling away, and a last sputter.
				var k := t / secs
				phase += TAU * (900.0 - 750.0 * k) / RATE
				var sputter := 1.0 if rng.randf() > 0.15 * k * 5.0 else 0.2
				v = (sin(phase) * 0.3 + sin(phase * 2.0) * 0.1) * (1.0 - k) * sputter
			"sparks":
				# Shorted: a spit of sparks, fast hard crackles thinning out.
				var spark := rng.randf_range(-1, 1) if rng.randf() > 0.6 + t else 0.0
				v = spark * 0.7 * exp(-t * 5.0)
			"watcher_step":
				# A bare foot dragged a step across the floor, slow and quiet.
				low = lerpf(low, rng.randf_range(-1, 1), 0.35)
				lower = lerpf(lower, low, 0.08)
				v = (low - lower) * 1.5 * sin(PI * t / secs) ** 2 * (0.7 + 0.3 * sin(TAU * 17.0 * t))
			"watcher_creak":
				# Caught: it stops dead, and its joints creak as they lock, with a crack.
				phase += TAU * (210.0 + 30.0 * sin(TAU * 2.0 * t) + rng.randf_range(-20, 20)) / RATE
				var slip := 0.55 + 0.45 * signf(sin(TAU * 27.0 * t + sin(TAU * 4.0 * t)))
				v = (sin(phase) * 0.3 + sin(phase * 2.0) * 0.18 + sin(phase * 3.0) * 0.1) * slip * sin(PI * minf(t / 0.55, 1.0))
				if t > 0.58:
					v += rng.randf_range(-1, 1) * exp(-(t - 0.58) * 90.0) * 0.6
			"echo_release":
				# Punched out at last: a thin shimmer rising and opening out, then gone.
				var k := t / secs
				var f := 440.0 * pow(2.0, k)
				phase += TAU * f / RATE
				var env := smoothstep(0.0, 0.4, k) * (1.0 - smoothstep(0.6, 1.0, k))
				v = (sin(phase) * 0.25 + sin(phase * 1.5) * 0.12 + sin(phase * 2.0) * 0.08) * env * (0.8 + 0.2 * sin(TAU * 6.0 * t))
		out[i] = v
	return SfxSynth._wav(out, RATE)


## The Custodian's drive: a motor's whine and its gears chattering, steady. One
## second that loops with no seam.
static func _servo() -> AudioStreamWAV:
	var n := RATE
	var gear := SfxSynth._noise("servo", n, 0.15)
	for i in n:
		var t := float(i) / RATE
		var teeth := 0.5 + 0.5 * sin(TAU * 24.0 * t)
		gear[i] = sin(TAU * 440 * t) * 0.18 + sin(TAU * 880 * t) * 0.06 + sin(TAU * 110 * t) * 0.12 + gear[i] * 0.35 * teeth
	return SfxSynth._loop(SfxSynth._wav(gear, RATE))


## An Echo held at its row: a cold, thin drone, two tones beating against each other
## over a breath of air. Two seconds that loop with no seam.
static func _echo_hum() -> AudioStreamWAV:
	var n := RATE * 2
	var air := SfxSynth._noise("echo_hum", n, 0.1)
	for i in n:
		var t := float(i) / RATE
		var swell := 0.8 + 0.2 * sin(TAU * 0.5 * t)
		air[i] = (sin(TAU * 220.0 * t) * 0.2 + sin(TAU * 221.5 * t) * 0.2 + sin(TAU * 330.0 * t) * 0.05) * swell + air[i] * 0.15
	return SfxSynth._loop(SfxSynth._wav(air, RATE))


## 0 to 1 and back at the ends of a sound `secs` long, so it never clicks on.
static func _edges(t: float, secs: float, ramp: float) -> float:
	return clampf(t / ramp, 0.0, 1.0) * clampf((secs - t) / ramp, 0.0, 1.0)
