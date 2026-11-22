class_name HidingSpot
extends Seat
## Somewhere to hide from an enemy (E7, Counterplay): a locker, under a desk, a
## cabinet. Look at it and press E to tuck yourself in; E again (or Space) gets you out. Inside,
## no enemy sees you and you make no sound, unless one saw (or heard) you get in:
## then it comes and searches here, and pulls you out if you're still inside.
## A locker has slats: from inside you can still see out (a Watcher stays frozen
## while you watch it). Floor builders make the furniture; this is the spot in it.
##
## Getting in and out is your own movement (a Seat); the machine it happens on tells
## the host (Counterplay.report_hide), which decides who saw.

## "locker", "desk" or "cabinet": its sound, and whether you can see out.
var spot_kind := "locker"
## You can see out from inside (a locker's slats).
var see_out := true
## Shown while you're inside (approved 2026-11-22, plan/approvals/v0.10-environment-strings.md).
var leave_prompt := LEAVE_PROMPT
## E gets you out, the way it got you in (Augustine 2026-11-22); Space still does too.
var leave_on_interact := true

const HIDE_PROMPT := "Hide"
const LEAVE_PROMPT := "[E] Get out"


## A hiding spot whose floor is at `floor_point` (level space), facing out `yaw`
## (radians, 0 faces -Z). `size` is the box you look at to get in.
static func make(parent: Node, floor_point: Vector3, yaw: float, what := "locker", size := Vector3(0.7, 1.4, 0.6)) -> HidingSpot:
	var h := HidingSpot.new()
	h.spot_kind = what
	h.see_out = what == "locker"
	h.kind = "seat" if what == "desk" else what  # its sound (Sfx.KINDS)
	h.transform = Transform3D(Basis(Vector3.UP, yaw), floor_point)  # before add_child
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2.0
	h.add_child(shape)
	h.collision_layer = 1
	parent.add_child(h)
	h.add_to_group("interactable")
	return h


func _init() -> void:
	prompt = HIDE_PROMPT
	local_only = true


func interact(player: Node) -> void:
	if not enabled or not player.has_method("sit") or _caught(player) or not player.sit(self):
		return
	used.emit(player)
	var c := Counterplay.of(self)
	if c == null:
		return
	c.report_hide(self, true)
	if player.has_signal("stood_up"):
		player.stood_up.connect(func():
			if is_instance_valid(c) and is_instance_valid(self):
				c.report_hide(self, false), CONNECT_ONE_SHOT)


## Held or thrown by an enemy (or down): too late to hide.
static func _caught(player: Node) -> bool:
	var combat = player.get("combat")
	return combat != null and (combat.grabbed_by != null or combat.thrown or combat.down)
