class_name ClueSpot
extends Node3D
## Something read by looking at it rather than picking it up, like a door's zone
## plate: once this player looks at it from close by, its clue goes on their case
## page (Game.add_clue). Each machine notes it for its own player.

const REACH := 2.5
const FACING := 0.9  # how squarely the view has to point at it

var case_id := ""
var text := ""
var from := ""


static func watch(parent: Node3D, pos: Vector3, p_case: String, p_text: String, p_from: String) -> ClueSpot:
	var s := ClueSpot.new()
	s.name = "ClueSpot"
	s.position = pos
	s.case_id = p_case
	s.text = p_text
	s.from = p_from
	parent.add_child(s)
	return s


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to := global_position - cam.global_position
	if to.length() > REACH or (-cam.global_basis.z).dot(to.normalized()) < FACING:
		return
	set_process(false)
	var game := get_node_or_null("/root/Game")
	if game and game.add_clue(case_id, text, from):
		var n := get_parent()
		while n and n.get("hud") == null:
			n = n.get_parent()
		if n:
			n.hud.notice("Noted on the case page: %s (Tab)" % game.case_info(case_id).title, 3.0)
