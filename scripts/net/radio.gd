class_name Radio
extends RefCounted
## A walkie-talkie's rules (game plan section 3): push-to-talk, limited range,
## a battery, and heavy static near entities. Pure logic, so it can be tested.

## Clear reception up to this distance (meters)...
const CLEAR_RANGE := 35.0
## ...fading to nothing but static here.
const MAX_RANGE := 70.0
## Entities closer than this to either radio drown it in static.
const INTERFERENCE_RANGE := 12.0
## Seconds of talk time on a full battery.
const TALK_TIME := 300.0

## 0 (dead) to 1 (full).
var battery := 1.0
var transmitting := false


func can_transmit() -> bool:
	return battery > 0.0


## Drain the battery while the talk button is held.
func tick(delta: float, talking: bool) -> void:
	if talking and can_transmit():
		battery = maxf(0.0, battery - delta / TALK_TIME)
	transmitting = talking and can_transmit()


func recharge(amount: float = 1.0) -> void:
	battery = clampf(battery + amount, 0.0, 1.0)


## How well a message gets through, 0 (only static) to 1 (clear).
static func signal_quality(distance: float, interference: float) -> float:
	var range_q := 1.0 - clampf((distance - CLEAR_RANGE) / (MAX_RANGE - CLEAR_RANGE), 0.0, 1.0)
	return range_q * (1.0 - clampf(interference, 0.0, 1.0))


## Static from entities near `pos`, 0 (none) to 1 (unusable).
static func interference_at(pos: Vector3, sources: Array) -> float:
	var worst := 0.0
	for s in sources:
		var d := pos.distance_to(s)
		worst = maxf(worst, 1.0 - clampf(d / INTERFERENCE_RANGE, 0.0, 1.0))
	return worst


## Mix a received message with static for its signal quality. `rng` makes
## dropouts and noise; pass a seeded one in tests.
static func degrade(frames: PackedVector2Array, quality: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames.size())
	var hiss := 0.04 + 0.5 * (1.0 - quality)
	# Bad signal cuts out in chunks, like a real radio.
	var dropout := rng.randf() < pow(1.0 - quality, 2.0)
	var voice_gain := 0.0 if dropout else quality
	for i in frames.size():
		var n := rng.randf_range(-hiss, hiss)
		var v := frames[i].x * voice_gain + n
		out[i] = Vector2(v, v)
	return out


## A burst of static, for the click at the start and end of a transmission.
static func squelch(length: int, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(length)
	for i in length:
		var fade := 1.0 - float(i) / length
		var v := rng.randf_range(-0.6, 0.6) * fade
		out[i] = Vector2(v, v)
	return out
