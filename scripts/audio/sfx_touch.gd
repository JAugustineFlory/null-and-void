class_name SfxTouch
## The sound of using something: a paper, a button, a locker, a breaker. Every
## Interactable has a kind (Interactable.kind); when someone uses it, every machine
## hears that kind's sound where it is (Interactable.touched, which the hands'
## animations hook too). A kind nobody set is worked out here from what the thing
## is and what its prompt says, so a new button or locker sounds right with no
## code; set `kind` to pick another sound, or "none" for silence.

## Kinds that play another kind's sound.
const SOUND_OF := {"slot": "clunk", "vent_panel": "rattle", "pen": "pencil"}
## Kinds that are quiet on purpose: they make their own sounds (a terminal's keys),
## or it's a person, not a thing.
const SILENT := ["none", "terminal"]

## What a prompt's words say a thing is, checked in order (lower case). The first
## that the prompt contains wins.
const BY_PROMPT := [
	["vent", "vent_panel"], ["grate", "vent_panel"], ["hatch", "vent_panel"], ["ceiling panel", "ceiling_tile"],
	["locker", "locker"], ["reset", "switch"], ["breaker", "switch"], ["lighting circuit", "switch"],
	["crank", "crank"], ["buckle", "buckle"], ["badge in", "card"], ["swipe", "card"], ["key card", "card"],
	["stair door", "push_bar"], ["push bar", "push_bar"], ["pull", "lever"], ["lock", "lock"],
	["open the door", "handle"], ["tear the tape", "tape_tear"], ["sign", "pen"], ["spare key", "keys"],
	["reseat", "slot"], ["fit a", "slot"], ["the van", "car_door"], ["computer", "mouse"],
	["take", "item"], ["pick up", "item"], ["press", "button"], ["play", "button"], ["buy", "button"],
	["enter", "button"], ["clear", "button"],
]


## The kind of thing `it` is, for its sound: its own `kind` if set, else worked out.
## "" if nothing says (the sweep in tests/sound_tests.gd catches those).
static func kind_of(it: Interactable) -> String:
	if it.kind != "":
		return it.kind
	if it is Terminal:
		return "terminal"
	if it is Seat:
		return "seat"
	if it is FirstAidCabinet:
		return "cabinet"
	if it is Document:
		return "sticky" if it.is_sticky() else "paper"
	if it is StickyNote:
		return "sticky"
	var prompt := it.prompt.to_lower()
	if prompt == "":
		return "none"  # an unseen relay a client's press goes through; the thing pressed sounds
	if String(it.name).begins_with("Key_"):
		return "keypad"  # a door keypad's keys
	for rule in BY_PROMPT:
		if prompt.contains(rule[0]):
			return rule[1]
	return ""


## The sound a kind of thing makes ("" for none).
static func sound_of(kind: String) -> String:
	if kind == "" or kind in SILENT:
		return ""
	return SOUND_OF.get(kind, kind)


## Every machine: a badge reader (any node at the reader) answers a swipe: two chirps
## for yes, three blats for no. Nothing if the reader isn't there.
static func reader(at: Node, ok: bool) -> void:
	if at is Node3D and at.get_parent():
		Sfx.play(at.get_parent(), "reader_ok" if ok else "reader_no", at.position)


## Every machine: someone used `it`; it sounds where it is.
static func play(it: Interactable) -> void:
	var sound := sound_of(kind_of(it))
	var parent := it.get_parent()
	if sound != "" and parent:
		Sfx.play(parent, sound, it.position)
