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
