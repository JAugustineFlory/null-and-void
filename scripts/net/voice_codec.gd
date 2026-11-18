class_name VoiceCodec
extends RefCounted
## Turns microphone audio into small packets and back. Mono, 16 kHz ("HD
## voice": everything up to 8 kHz, so s, f and th stay crisp), 8-bit mu-law (the
## telephone standard): about 16 KB/s per talker. Steam voice can replace it later.
##
## Before it's encoded, the microphone is cleaned up: on its bus (VoiceChat), a
## high-pass takes out rumble and a low-pass takes out hiss the codec can't carry
## (which would otherwise fold back down as harsh noise); here a Gate decides when
## someone is talking and a Leveler evens out loudness without ever clipping.

const RATE := 16000


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
## place between packets, so packet edges don't click 60 times a second. It
## reads between input samples at the exact time of each output sample (the mic
## bus's low-pass has already taken out what 16 kHz can't carry), so high voices
## and s sounds come through steady instead of wobbling.
class Encoder:
	var _pos := 0.0  # where the next output sample falls, in input frames from the start of the pending input
	var _pending := PackedFloat32Array()

	func encode(frames: PackedVector2Array, src_rate: float) -> PackedByteArray:
		for f in frames:
			_pending.append((f.x + f.y) * 0.5)
		var step := src_rate / RATE
		var out := PackedByteArray()
		while _pos + 1.0 < _pending.size():
			var j := int(_pos)
			out.append(VoiceCodec.mulaw_encode(lerpf(_pending[j], _pending[j + 1], _pos - j)))
			_pos += step
		var used := mini(int(_pos), _pending.size() - 1)
		_pending = _pending.slice(used)
		_pos -= used
		return out


## Open mic: decides, a block of audio at a time, whether someone is talking.
## It learns the room's background noise and opens a little above it, so a quiet
## microphone in a quiet room still gets through and a noisy room doesn't hold it
## open; once open, it stays open through the gaps between words.
class Gate:
	## Open this far above the background noise (3 = about 10 dB)...
	const OVER_NOISE := 3.0
	## ...but never for less than this (RMS), or a dead-silent mic would open on breath...
	const MIN_LEVEL := 0.006
	## ...nor need more than this, however noisy the room.
	const MAX_LEVEL := 0.04
	## Stay open this long after the last loud block (seconds).
	const HANG := 0.5
	## Seconds of audio to keep while closed, sent when it opens so a word's first sound isn't cut.
	const PREROLL := 0.1

	var noise := 0.01
	var open := false
	var speech := false  # this block was loud enough to count as talking
	var _hang := 0.0

	func threshold() -> float:
		return clampf(noise * OVER_NOISE, MIN_LEVEL, MAX_LEVEL)

	## `level`: this block's RMS; `dt`: how long it lasts. Returns whether the mic is open.
	func update(level: float, dt: float) -> bool:
		speech = level > threshold()
		if speech:
			_hang = HANG
		else:
			_hang -= dt
		open = _hang > 0.0
		# Background noise: follow quiet stretches quickly, louder ones only
		# slowly (over many seconds), so talking doesn't count as noise.
		var tau := 0.05 if level < noise else 6.0
		noise = lerpf(noise, level, 1.0 - exp(-dt / tau))
		return open


## Brings each talker to the same speaking level and catches peaks, so a quiet
## microphone is easy to hear and a loud voice never crackles.
class Leveler:
	## Speaking level (RMS) it aims for.
	const TARGET := 0.15
	## Never boost a microphone more than this, so room noise stays down.
	const MAX_GAIN := 8.0
	## No sample comes out louder than this.
	const CEILING := 0.9
	## The limiter lets go over this long (seconds).
	const RELEASE := 0.08

	var gain := 1.0
	var _level := -1.0  # recent speaking level (RMS): rises fast, falls slowly
	var _env := 0.0

	## Mic frames to leveled mono frames. `speech`: this block is someone talking
	## (only then does the level it aims for move).
	func process(frames: PackedVector2Array, rate: float, speech: bool) -> PackedVector2Array:
		var n := frames.size()
		var out := PackedVector2Array()
		out.resize(n)
		if n == 0:
			return out
		var from := gain
		if speech:
			var r := VoiceCodec.rms(frames)
			var dt := n / rate
			if _level < 0.0:
				_level = r
			else:
				_level = lerpf(_level, r, 1.0 - exp(-dt / (0.05 if r > _level else 0.8)))
			gain = clampf(TARGET / maxf(_level, 0.0001), 1.0, MAX_GAIN)
		var release := exp(-1.0 / (RELEASE * rate))
		for i in n:
			# The gain glides across the block instead of stepping at its edge.
			var v := (frames[i].x + frames[i].y) * 0.5 * lerpf(from, gain, float(i + 1) / n)
			var a := absf(v)
			_env = a if a > _env else _env * release
			if _env > CEILING:
				v *= CEILING / _env
			out[i] = Vector2(v, v)
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
