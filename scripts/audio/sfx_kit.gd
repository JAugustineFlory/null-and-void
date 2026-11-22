class_name SfxKit
extends RefCounted
## The sounds of the environment kit and the parkour pieces around it, made in code
## with their own budget (so SfxSynth keeps its). Each piece plays its own where it
## is, from code that runs on every machine: KitPiece._sound_for for the kit, and
## the hooks here for crates, the cable rope and the stuck elevator.
##
##   gear_jam / gear_free   a crowbar into the teeth, the train grinding to a stop /
##                          pulled out, the gears catching and spinning back up
##   fuse_pull / fuse_fit   a cartridge fuse drawn out of its clips / snapped in
##   fuse_pop               a fuse blowing: a crack and a fizz
##   patch_plug             a patch lead's plug seated in (or out of) its jack
##   plug_in                a cord or a keyboard's plug pushed home
##   power_button           a terminal's heavy power switch
##   crt_on                 an old monitor coming on: the relay, the degauss thrum,
##                          static crawling over the glass (the whine follows)
##   crate_lift / crate_down  a crate hefted up / set down, scraping a little
##   rope_tie / rope_untie  a cable knotted round a post, pulled tight / worked loose
##   rope_creak             the cable taking weight as someone climbs it
##   climb_rung             a hand or a boot on a steel rung
##   effort / boot_scuff    a leg-up: the lifter's grunt, the climber's boot on them
##   lift_stall             the car lurching to a stop between floors, motor dying
##   hatch_lid              the roof hatch's lid forced up and falling open
##   landing_release        a landing door's release: the latch, the doors rolling apart

const RATE := 11025
## Kind -> seconds.
const KINDS := {
	"gear_jam": 0.8, "gear_free": 0.9, "fuse_pull": 0.35, "fuse_fit": 0.3, "fuse_pop": 0.6,
	"patch_plug": 0.2, "plug_in": 0.3, "power_button": 0.15, "crt_on": 1.6,
	"crate_lift": 0.5, "crate_down": 0.55, "rope_tie": 0.9, "rope_untie": 0.7, "rope_creak": 0.6,
	"climb_rung": 0.25, "effort": 0.4, "boot_scuff": 0.35,
	"lift_stall": 1.8, "hatch_lid": 1.0, "landing_release": 1.4,
}
## A climb this fast or slower (m/s, up or down) at a steady speed is climbing, not falling.
const CLIMB_SPEED := 3.0
## Climbing: a rung (or the rope's creak) every this many metres.
const RUNG := 0.35


## A crate's sounds: lifted, set down.
static func attach_crate(c: Node3D) -> void:
	c.connect("carried", func(peer_id: int):
		if c.is_inside_tree() and c.get_parent() is Node3D:
			Sfx.play(c.get_parent(), "crate_lift" if peer_id != 0 else "crate_down", c.position))


## A cable anchor's sounds: tied off, untied.
static func attach_anchor(a: Node3D) -> void:
	a.connect("changed", func(tied: bool, _peer_id: int):
		if a.is_inside_tree() and a.get_parent() is Node3D:
			Sfx.play(a.get_parent(), "rope_tie" if tied else "rope_untie", a.position))


## A leg-up, on every machine: the one giving it takes the weight and grunts, and the
## climber's boot scuffs on them.
static func leg_up(base: Node3D) -> void:
	if base == null or not base.is_inside_tree() or not base.get_parent() is Node3D:
		return
	var at := base.position + Vector3.UP * 1.2
	Sfx.play(base.get_parent(), "effort", at, -4.0)
	Sfx.play_later(base.get_parent(), "boot_scuff", at, 0.12, -6.0)


## What climbing at `at` (world) sounds like: the cable creaking if it's a tied-off
## cable, otherwise a steel rung.
## (Duck-typed: naming CableAnchor here would pull the world into the test runner.)
static func climb_sound(tree: SceneTree, at: Vector3) -> String:
	for a in tree.get_nodes_in_group("interactable"):
		var v = a.get("volume") if a.get("tied") == true else null
		if v is Node3D and is_instance_valid(v):
			var bottom: Vector3 = v.get("a")
			var top: Vector3 = v.get("b")
			var off := Vector2(at.x - bottom.x, at.z - bottom.z).length()
			if off < 1.0 and at.y > bottom.y - 0.5 and at.y < top.y + 2.0:
				return "rope_creak"
	return "climb_rung"


## The sound called `kind`, or null.
static func make(kind: String) -> AudioStreamWAV:
	if not KINDS.has(kind):
		return null
	var secs: float = KINDS[kind]
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var low := 0.0
	var lower := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1, 1)
		low = lerpf(low, noise, 0.25)
		lower = lerpf(lower, noise, 0.04)
		var v := 0.0
		match kind:
			"gear_jam":
				# Steel caught in the teeth: a grinding screech that slows and binds,
				# then a hard clank as it locks.
				var slow := 1.0 - t / 0.6
				if t < 0.6:
					phase += TAU * (520.0 * slow + 120.0) / RATE
					var tooth := 0.5 + 0.5 * signf(sin(TAU * (30.0 * slow + 4.0) * t))
					v = (sin(phase) * 0.3 + sin(phase * 2.7) * 0.15 + low * 0.5) * tooth * slow
				if t > 0.58:
					v += _knock(t - 0.58, 380.0, 990.0, rng) * 0.9
			"gear_free":
				# The bar pulled out with a clank, the train catching, then ticking
				# back up to speed.
				v = _knock(t, 420.0, 1100.0, rng) * 0.8
				if t > 0.15:
					var s := t - 0.15
					var rate := 4.0 + 12.0 * minf(1.0, s / 0.6)
					var into := fmod(s * rate, 1.0) / rate
					v += (low * 0.8 + sin(TAU * 700.0 * into) * 0.2) * exp(-into * 90.0) * minf(1.0, s * 3.0)
			"fuse_pull":
				# Drawn out of its spring clips: a scrape, then a metal snick as it frees.
				var scrape := sin(PI * minf(1.0, t / 0.25))
				v = (low - lower) * 1.2 * scrape * (0.6 + 0.4 * absf(sin(TAU * 41.0 * t)))
				if t > 0.24:
					v += sin(TAU * 2300.0 * (t - 0.24)) * exp(-(t - 0.24) * 160.0) * 0.5
			"fuse_fit":
				# Pressed in: a short slide and a sharp snap of the clips.
				if t < 0.1:
					v = (low - lower) * sin(PI * t / 0.1) * 0.8
				else:
					var s := t - 0.1
					v = (noise * exp(-s * 250.0) * 0.9 + sin(TAU * 1800.0 * s) * exp(-s * 70.0) * 0.4)
			"fuse_pop":
				# It blows: a crack, then a fizz that dies away.
				v = noise * exp(-t * 120.0) * 1.0 + low * exp(-t * 8.0) * 0.6 * (0.5 + 0.5 * absf(sin(TAU * 60.0 * t)))
			"patch_plug":
				# A quarter-inch plug: the barrel sliding in, the tip clicking home.
				if t < 0.08:
					v = (low - lower) * 0.9 * sin(PI * t / 0.08)
				else:
					var s := t - 0.08
					v = noise * exp(-s * 300.0) * 0.8 + sin(TAU * 2600.0 * s) * exp(-s * 90.0) * 0.3
			"plug_in":
				# A mains plug or a keyboard's DIN pushed in: a scrape and a solid seat.
				if t < 0.14:
					v = (low - lower) * 1.1 * sin(PI * t / 0.14)
				else:
					v = _knock(t - 0.14, 300.0, 820.0, rng) * 0.8
			"power_button":
				# A heavy rocker: a plastic thock and the switch's snap.
				v = noise * exp(-t * 200.0) * 0.7 + (sin(TAU * 240.0 * t) * 0.5 + sin(TAU * 1500.0 * t) * 0.2) * exp(-t * 45.0)
			"crt_on":
				# The relay, then the degauss coil's thrum (hum beating as it dies),
				# then static crawling across the glass.
				v = _knock(t, 180.0, 700.0, rng) * 0.6
				if t > 0.05:
					var s := t - 0.05
					var hum := sin(TAU * 60.0 * s) + sin(TAU * 120.0 * s) * 0.6 + sin(TAU * 180.0 * s) * 0.3
					v += clampf(hum, -1.2, 1.2) * 0.45 * exp(-s * 2.6) * (0.75 + 0.25 * sin(TAU * 7.0 * s))
				if t > 0.4:
					var crackle := noise if rng.randf() > 0.985 else 0.0
					v += (crackle * 0.6 + (noise - low) * 0.08) * exp(-(t - 0.4) * 2.0)
			"crate_lift":
				# Hefted: the wood creaks, the contents shift.
				phase += TAU * (140.0 + rng.randf_range(-15, 15)) / RATE
				var creak := sin(phase) * 0.3 * (0.5 + 0.5 * signf(sin(TAU * 23.0 * t))) * sin(PI * minf(1.0, t / 0.35))
				v = creak + low * 0.3 * exp(-absf(t - 0.25) * 12.0)
			"crate_down":
				# Set down: a wooden thud and a short scrape as it's pushed square.
				v = lower * 3.0 * exp(-t * 18.0) + sin(TAU * 95.0 * t) * 0.5 * exp(-t * 22.0)
				if t > 0.18 and t < 0.5:
					v += (low - lower) * 0.7 * sin(PI * (t - 0.18) / 0.32)
			"rope_tie":
				# Cable thrown round a post, hissing through the hands, then cinched tight.
				v = (noise - low) * 0.35 * sin(PI * minf(1.0, t / 0.6))
				if t > 0.6:
					var s := t - 0.6
					v += low * 1.2 * exp(-s * 25.0) + sin(TAU * 150.0 * s) * 0.3 * exp(-s * 30.0)
			"rope_untie":
				# The knot worked loose, the cable slithering off the post.
				v = (noise - low) * 0.3 * sin(PI * t / secs) + low * 0.8 * exp(-t * 20.0)
			"rope_creak":
				# Plastic-jacketed cable taking weight: a stretched creak against the edge.
				phase += TAU * (90.0 + 40.0 * sin(PI * t / secs) + rng.randf_range(-6, 6)) / RATE
				var catch := 0.55 + 0.45 * signf(sin(TAU * 13.0 * t + sin(TAU * 2.0 * t)))
				v = (sin(phase) * 0.3 + sin(phase * 2.0) * 0.2 + (noise - low) * 0.05) * catch * sin(PI * t / secs)
			"climb_rung":
				# A hand or a boot on a steel rung: a dull ring.
				v = _knock(t, 520.0, 1340.0, rng) * 0.6
			"effort":
				# A short grunt taking someone's weight: breath through the throat,
				# a little voice in it.
				var shape := sin(PI * minf(1.0, t / secs)) * exp(-t * 2.0)
				phase += TAU * (115.0 - 25.0 * t) / RATE
				var voice := (sin(phase) + sin(phase * 2.0) * 0.5 + sin(phase * 5.0) * 0.25) * 0.25
				v = (voice * (0.6 + 0.4 * absf(sin(phase * 0.5))) + (low - lower) * 1.6) * shape
			"boot_scuff":
				# A rubber sole scraping on a shoulder or a knee: a brush and a squeak.
				v = (noise - low) * 0.4 * sin(PI * t / secs)
				if t > 0.12 and t < 0.22:
					v += sin(TAU * 1100.0 * t) * 0.25 * sin(PI * (t - 0.12) / 0.1)
			"lift_stall":
				# The car jolts, the cables twang, and the hoist motor winds down to nothing.
				v = lower * 4.0 * exp(-t * 6.0) + _knock(t, 70.0, 210.0, rng) * 0.9
				var twang := t - 0.08
				if twang > 0.0:
					v += sin(TAU * 62.0 * twang + 3.0 * sin(TAU * 4.0 * twang)) * 0.35 * exp(-twang * 2.5)
				phase += TAU * (100.0 * maxf(0.0, 1.0 - t / secs) + 10.0) / RATE
				v += sin(phase) * 0.2 * maxf(0.0, 1.0 - t / secs)
			"hatch_lid":
				# Shoved up: the hinge squeals, then the steel lid falls open with a clang.
				if t < 0.55:
					phase += TAU * (600.0 + 300.0 * t + rng.randf_range(-30, 30)) / RATE
					v = (sin(phase) * 0.25 + sin(phase * 2.0) * 0.12) * sin(PI * t / 0.55) * (0.5 + 0.5 * signf(sin(TAU * 27.0 * t)))
				else:
					v = _knock(t - 0.55, 260.0, 735.0, rng) * 1.0
			"landing_release":
				# A latch knocked off, then the landing doors' rollers rumbling apart.
				v = _knock(t, 340.0, 900.0, rng) * 0.7
				if t > 0.2:
					var s := t - 0.2
					v += lower * 3.5 * sin(PI * minf(1.0, s / 1.1)) * (0.8 + 0.2 * sin(TAU * 18.0 * s))
					if t > 1.25:
						v += _knock(t - 1.25, 200.0, 560.0, rng) * 0.5
		out[i] = v
	var w := SfxSynth._wav(_fit(out), RATE)
	return w


## A hit on metal: a click of noise and two ringing partials, dying fast.
static func _knock(s: float, a: float, b: float, rng: RandomNumberGenerator) -> float:
	if s < 0.0:
		return 0.0
	return rng.randf_range(-1, 1) * exp(-s * 160.0) * 0.6 + (sin(TAU * a * s) * 0.5 + sin(TAU * b * s) * 0.25) * exp(-s * 14.0)


## Brought to a sensible peak, never clipping.
static func _fit(out: PackedFloat32Array) -> PackedFloat32Array:
	var top := 0.0
	for v in out:
		top = maxf(top, absf(v))
	if top > 0.85:
		for i in out.size():
			out[i] *= 0.85 / top
	return out
