class_name SfxDoor
extends RefCounted
## What a door sounds like, step by step as it moves (Door.moved, which plays on
## every machine because set_open and rattle do):
##   hinged: "unlatch" the handle goes down (a stair door's push bar clanks),
##           "swing" the leaf groans round on its hinges, "stop" it knocks softly
##           against its stop, "close" the closer's arm hisses it back, "latch" it
##           clicks home; "rattle" the handle won't turn.
##   sliding: "unlock" the bolts draw with a clunk, "run" the motor whirs, "stop"
##           it settles, "close" the motor runs it shut, "thud" it bumps home.
## A shove (a monster walking into a door) has no "unlatch": just the swing.
## Trying a locked door near you also tightens the music (MusicDirector.door_tried).
##
## The door sounds made here have their own budget, so the rest of the made
## sounds (SfxSynth) keep theirs.

const RATE := 11025
## Sound kind -> seconds. Made in code at half rate: nothing high in a hinge's groan.
const KINDS := {"door_creak": 0.75, "door_closer": 0.7}
## Each phase's sound (and how much quieter, dB): hinged, then sliding.
const HINGED := {
	&"unlatch": ["handle", 0.0], &"swing": ["door_creak", -6.0], &"stop": ["tap", -14.0],
	&"close": ["door_closer", -8.0], &"latch": ["click", 0.0], &"rattle": ["lock", 0.0],
}
const SLIDING := {
	&"unlock": ["clunk", -6.0], &"run": ["door_motor", 0.0], &"stop": ["click", -10.0],
	&"close": ["door_motor", -2.0], &"thud": ["clunk", 0.0],
}


## Gives `door` its sounds. Door._ready calls it.
static func attach(door: Door) -> void:
	if door.has_meta("sfx_door"):
		return
	door.set_meta("sfx_door", true)
	door.moved.connect(Callable(SfxDoor, "_on_moved").bind(weakref(door)))


## The sound `door` makes at `phase`, as [kind, dB], or [] for none.
static func sound_for(door: Door, phase: StringName) -> Array:
	if door.is_hinged():
		if phase == &"unlatch" and String(door.name).contains("STAIR"):
			return ["push_bar", 0.0]
		return HINGED.get(phase, [])
	return SLIDING.get(phase, [])


static func _on_moved(phase: StringName, ref: WeakRef) -> void:
	var door: Door = ref.get_ref()
	if door == null or not door.is_inside_tree() or not door.get_parent() is Node3D:
		return
	var s := sound_for(door, phase)
	if not s.is_empty():
		Sfx.play(door.get_parent(), s[0], door.position, s[1])
	if phase == &"rattle":
		var d := door.get_tree().root.get_node_or_null("Music/Director")
		if d and d.has_method("door_tried"):
			d.door_tried(door)


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
	var phase := 0.0
	var low := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		match kind:
			"door_creak":
				# A heavy door on dry hinges: a low groan that catches and slips, rising
				# a little as the leaf picks up speed.
				phase += TAU * (180.0 + 90.0 * t / secs + rng.randf_range(-12, 12)) / RATE
				var catch := 0.6 + 0.4 * signf(sin(TAU * 19.0 * t + 2.0 * sin(TAU * 2.0 * t)))
				v = (sin(phase) * 0.35 + sin(phase * 2.0) * 0.25 + sin(phase * 3.0) * 0.12) * catch * sin(PI * t / secs)
			"door_closer":
				# The closer's arm: air hissing out of its cylinder, easing off, and the
				# arm's joint ticking once at the end.
				low = lerpf(low, rng.randf_range(-1, 1), 0.35)
				var ease_off := sin(PI * minf(1.0, t / (secs * 0.85)))
				v = low * 0.5 * ease_off
				if t > secs * 0.86:
					var d := t - secs * 0.86
					v += sin(TAU * 1400.0 * d) * exp(-d * 120.0) * 0.4
		out[i] = v
	return SfxSynth._wav(out, RATE)
