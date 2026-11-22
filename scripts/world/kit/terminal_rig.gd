class_name TerminalRig
extends Node3D
## What a terminal needs before it can be used, on a floor that wants it found or
## fixed first (E5). Its query is still the gate; this only stands in front of it.
##   "power"          switched off for the night: press its power button (on the screen's front).
##   "power_cord"     no power cord: carry one here and plug it in at the back.
##   "monitor_cable"  the monitor cable's out at the back: push it back in.
##   "keyboard"       no keyboard on the desk: carry one here and plug it in.
## With `fuse_box`, its socket is on that box's `circuit`: dead circuit, dead terminal.
## Until all's done the screen is dark (or, with only a keyboard missing, lit and
## unreachable); pressing the terminal says why. Co-op: as every kit piece (KitPiece).

## Every machine: everything's fixed and it's on.
signal assembled
## Every machine: `part` was fixed, by player `peer_id`.
signal fixed(part: String, peer_id: int)

const PARTS := ["power", "power_cord", "monitor_cable", "keyboard"]
## What each part takes from the fixer's hands ("" for nothing).
const NEEDS := {"power_cord": "power_cord", "keyboard": "keyboard"}
## Where each part's spot is on the terminal, and its aim box (the terminal's space).
const SPOTS := {
	"power_cord": [Vector3(0.12, 0.2, -0.38), Vector3(0.14, 0.14, 0.1)],
	"monitor_cable": [Vector3(-0.1, 0.2, -0.38), Vector3(0.14, 0.14, 0.1)],
	"keyboard": [Vector3(0, 0.03, 0.4), Vector3(0.48, 0.06, 0.18)],
}

var terminal: Terminal
## Parts still to fix.
var missing: Array = []
var fuse_box: FuseBox
var circuit := ""
var is_assembled := false
## Warming up after it comes on (the tube glows, then its boot lines come up).
var booting := false
## Seconds from the click to the first boot line, and between lines.
const WARM_UP := 0.8
const LINE_GAP := 0.25
var _was_lit := false
var parts := {}
var _cord: Node3D
var _cable: Node3D


## Puts `terminal` behind the parts in `missing_parts` (PARTS), optionally on a fuse
## box's circuit.
static func attach(t: Terminal, missing_parts: Array, on_box: FuseBox = null, on_circuit := "") -> TerminalRig:
	var rig := TerminalRig.new()
	rig.name = "Rig"
	rig.terminal = t
	rig.missing = missing_parts.filter(func(p): return PARTS.has(p))
	rig.fuse_box = on_box
	rig.circuit = on_circuit
	t.add_child(rig)
	t.rig = rig
	for part in SPOTS:
		if rig.missing.has(part):
			rig.parts[part] = RigPart.make(rig, part, SPOTS[part][0], SPOTS[part][1])
	if rig.missing.has("power"):
		# No aim box of its own: pressing the terminal's front presses it (press_terminal).
		rig.parts["power"] = RigPart.make(rig, "power", Vector3(0.17, 0.065, 0.24), Vector3.ZERO)
	# What hangs off the back: the cord (once plugged in) and the monitor cable.
	rig._cord = Node3D.new()
	rig._cord.name = "Cord"
	rig.add_child(rig._cord)
	KitPiece._box(rig._cord, Vector3(0.12, 0.1, -0.36), Vector3(0.02, 0.22, 0.02), Color(0.1, 0.1, 0.1))
	rig._cable = Node3D.new()
	rig._cable.name = "Cable"
	rig.add_child(rig._cable)
	KitPiece._box(rig._cable, Vector3(-0.1, 0.1, -0.36), Vector3(0.02, 0.22, 0.02), Color(0.2, 0.2, 0.25))
	rig._was_lit = rig.lit()  # already on: no boot at the start of the floor
	if on_box:
		on_box.circuit_changed.connect(func(c, _live, _peer): if c == on_circuit: rig._refresh())
	rig._refresh()
	return rig


## There's power at the socket (a cord, and a live circuit if it's on one).
func has_power() -> bool:
	return not missing.has("power_cord") and (fuse_box == null or fuse_box.is_live(circuit))


## The screen shows a picture.
func lit() -> bool:
	return has_power() and not missing.has("power") and not missing.has("monitor_cable")


## It stands in front of the terminal: something's missing, or there's no power.
func blocks() -> bool:
	return not missing.is_empty() or not has_power() or booting


## What the terminal itself says while it's blocked (its front: the power button).
func terminal_prompt(_player: Node) -> String:
	if booting:
		return ""
	if missing.has("power"):
		return "[E] " + KitWords.say("power_on")
	if not has_power():
		return KitWords.say("no_power")
	if missing.has("monitor_cable"):
		return KitWords.say("no_picture")
	if missing.has("keyboard"):
		return KitWords.say("no_keyboard")
	return ""


## Pressing the terminal while it's blocked: its power button, if it's off.
func press_terminal(player: Node) -> void:
	if missing.has("power"):
		(parts["power"] as RigPart).interact(player)


## Every machine: `part` is fixed by `peer`.
func _fix(part: String, peer: int) -> void:
	if not missing.has(part):
		return
	missing.erase(part)
	if parts.has(part):
		(parts[part] as RigPart).done()
	fixed.emit(part, peer)
	_refresh()


func _refresh() -> void:
	_cord.visible = not missing.has("power_cord")
	_cable.visible = not missing.has("monitor_cable")
	var on := lit()
	var screen := terminal.screen
	if screen:
		if screen.glass:
			screen.glass.visible = on
		if screen.keyboard:
			screen.keyboard.visible = not missing.has("keyboard")
	for c in terminal.get_children():
		if c is OmniLight3D:
			c.visible = on
		elif c is AudioStreamPlayer3D and String(c.name).begins_with("Loop_"):
			c.stream_paused = not on
	if on and not _was_lit and is_inside_tree():
		_boot()
	_was_lit = on
	if not blocks() and not is_assembled:
		is_assembled = true
		assembled.emit()
	elif blocks():
		is_assembled = false


## Every machine: it came on. A dark screen warms up, then its usual boot lines
## come up one at a time (the same lines it always boots with), then the prompt.
func _boot() -> void:
	Sfx.play(terminal, "crt_on", terminal.focus_point.position)  # the relay, the degauss thrum, static
	booting = true
	terminal.clear_screen()
	var lines := terminal.boot_text()
	var tw := create_tween()
	tw.tween_interval(WARM_UP)
	for line in lines:
		tw.tween_callback(terminal.print_line.bind(line))
		tw.tween_interval(LINE_GAP)
	tw.tween_callback(func():
		booting = false
		_refresh())
