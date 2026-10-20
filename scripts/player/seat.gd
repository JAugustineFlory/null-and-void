class_name Seat
extends Interactable
## Somewhere to sit: a chair, a bench, a stool. Look at it and press E to sit
## (Player.sit); Space or Z stands you back up. The node sits on the seat's top
## surface, facing the way a sitter faces (-Z). One sitter at a time.
##
## Sitting is your own movement, like crouching: it plays out on your machine and
## teammates see where you are, so a seat never asks the host.

## Whoever is sitting here on this machine, or null.
var occupant: Node3D


## An invisible seat over a chair's top at `top` (the middle of the seat, on its
## surface), facing `yaw` (radians, 0 faces -Z). `size` is the seat's width and depth.
static func create_at(parent: Node, top: Vector3, yaw: float = 0.0, size := Vector2(0.5, 0.5)) -> Seat:
	var s := Seat.new()
	s.prompt = "Sit down"
	s.local_only = true
	s.transform = Transform3D(Basis(Vector3.UP, yaw), top)  # before add_child, so it never sits at the origin
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 0.4, size.y)
	shape.shape = box
	shape.position.y = 0.2  # the space just above the seat, where you look to sit
	s.add_child(shape)
	parent.add_child(s)
	s.add_to_group("interactable")
	return s


func _init() -> void:
	prompt = "Sit down"
	local_only = true


func get_prompt(player: Node) -> String:
	if not is_free(player):
		return ""
	return super.get_prompt(player)


func interact(player: Node) -> void:
	if enabled and player.has_method("sit") and player.sit(self):
		used.emit(player)


## Nobody else is on it: not on this machine, and no teammate is sitting there.
func is_free(for_player: Node = null) -> bool:
	if not enabled:
		return false
	if occupant and is_instance_valid(occupant) and occupant != for_player:
		return false
	for p in get_tree().get_nodes_in_group("player") if is_inside_tree() else []:
		if p == for_player or not p is Node3D:
			continue
		var off: Vector3 = (p as Node3D).global_position - global_position
		if Vector2(off.x, off.z).length() < 0.3 and absf(off.y) < 0.3:
			return false
	return true
