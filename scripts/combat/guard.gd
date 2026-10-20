class_name Guard
extends RefCounted
## Blocking: right-click just before a hit lands and it does nothing. The guard
## is only up for a moment, so it's about timing, not holding the button down:
## an attacker's tell (Rourke leans in) is the cue. A press that catches nothing
## leaves you open for a beat before the next one counts, so mashing doesn't work.
## Time is passed in, so the clock is whatever the owner keeps (scaled game time).

## How long the guard stays up after the press. Tune in playtests. As long as
## Rourke's lean before a swing, so a press anywhere in the lean blocks it.
const WINDOW := 0.4
## After a press that blocked nothing: how long before another press raises it.
const RECOVER := 0.45

var _raised_at := -100.0
var _open_until := -100.0


## Right mouse pressed. False if you're still recovering from a missed one.
func raise(now: float) -> bool:
	if now < _open_until:
		return false
	_raised_at = now
	_open_until = now + WINDOW + RECOVER
	return true


func is_up(now: float) -> bool:
	return now >= _raised_at and now - _raised_at <= WINDOW


## A hit is landing now: true if the guard catches it. A caught hit drops the
## guard and frees you to raise it again straight away for the next one.
func catch_hit(now: float) -> bool:
	if not is_up(now):
		return false
	_raised_at = -100.0
	_open_until = -100.0
	return true
