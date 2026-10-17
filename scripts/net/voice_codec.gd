class_name VoiceCodec
extends RefCounted
## Turns microphone audio into small packets and back. Mono, 12 kHz, 8-bit
## mu-law (the old telephone standard): about 12 KB/s per talker, and lo-fi
## enough to suit a 1997 walkie-talkie. Steam voice can replace it later.

const RATE := 12000


## Microphone frames (stereo, at `src_rate`) to a packet.
static func encode(frames: PackedVector2Array, src_rate: float) -> PackedByteArray:
	var out := PackedByteArray()
	if frames.is_empty():
		return out
	var step := src_rate / RATE
	var n := int(frames.size() / step)
	out.resize(n)
	for i in n:
		var pos := i * step
		var j := int(pos)
		var t := pos - j
		var a := (frames[j].x + frames[j].y) * 0.5
		var b := a
		if j + 1 < frames.size():
			b = (frames[j + 1].x + frames[j + 1].y) * 0.5
		out[i] = mulaw_encode(lerpf(a, b, t))
	return out


## Encodes a continuous microphone stream. Unlike encode(), it carries its
## place between packets (so packet edges don't click 60 times a second) and
## averages the samples it skips (so hiss above 6 kHz doesn't fold down into
## the voice).
class Encoder:
	var _pos := 0.0  # where the next output sample falls, in input frames from the start of the pending input
	var _pending := PackedFloat32Array()

	func encode(frames: PackedVector2Array, src_rate: float) -> PackedByteArray:
		for f in frames:
			_pending.append((f.x + f.y) * 0.5)
		var step := src_rate / RATE
		var out := PackedByteArray()
		while _pos + step <= _pending.size():
			# Average the input frames this output sample stands for.
			var from := int(_pos)
			var to := mini(int(_pos + step), _pending.size())
			var sum := 0.0
			for j in range(from, to):
				sum += _pending[j]
			out.append(VoiceCodec.mulaw_encode(sum / maxi(1, to - from)))
			_pos += step
		var used := int(_pos)
		_pending = _pending.slice(used)
		_pos -= used
		return out


## Bring quiet microphones up to a speaking level. Returns the frames scaled by
## `gain` with a soft limit, so loud voices round off instead of crackling.
static func amplify(frames: PackedVector2Array, gain: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames.size())
	for i in frames.size():
		var v := soft_clip(frames[i].x * gain)
		var w := soft_clip(frames[i].y * gain)
		out[i] = Vector2(v, w)
	return out


static func soft_clip(v: float) -> float:
	if absf(v) < 0.6:
		return v
	return signf(v) * (0.6 + 0.4 * tanh((absf(v) - 0.6) / 0.4))


## A packet back to playable frames at RATE.
static func decode(data: PackedByteArray) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(data.size())
	for i in data.size():
		var v := mulaw_decode(data[i])
		out[i] = Vector2(v, v)
	return out


## Loudness of some frames, 0 (silence) to about 1.
static func rms(frames: PackedVector2Array) -> float:
	if frames.is_empty():
		return 0.0
	var sum := 0.0
	for f in frames:
		var m := (f.x + f.y) * 0.5
		sum += m * m
	return sqrt(sum / frames.size())


const _BIAS := 0x84
const _CLIP := 32635


static func mulaw_encode(sample: float) -> int:
	var s := int(clampf(sample, -1.0, 1.0) * 32767.0)
	var sign := 0
	if s < 0:
		sign = 0x80
		s = -s
	s = mini(s, _CLIP) + _BIAS
	var exponent := 7
	var mask := 0x4000
	while exponent > 0 and (s & mask) == 0:
		exponent -= 1
		mask >>= 1
	var mantissa := (s >> (exponent + 3)) & 0x0F
	return ~(sign | (exponent << 4) | mantissa) & 0xFF


static func mulaw_decode(byte: int) -> float:
	var u := ~byte & 0xFF
	var sign := u & 0x80
	var exponent := (u >> 4) & 0x07
	var mantissa := u & 0x0F
	var s := (((mantissa << 3) + _BIAS) << exponent) - _BIAS
	return (-s if sign != 0 else s) / 32767.0
