class_name Level2Document
extends Interactable
## A paper in the world: a sign-in sheet, a laminated card, a manual page. You can
## read it where it hangs, and E copies its key lines into your notebook.
##
## A stand-in for the Playtest fixes thread's shared Document interactable. Swap it
## for that one when it lands.

## Shown in the notebook over the copied lines.
var title := ""
## The lines E writes into the notebook, as on the paper.
var note_lines: Array = []
var copied := false


static func hang(parent: Node, pos: Vector3, size: Vector2, facing_deg: float, doc_title: String, text: String, lines: Array, paper: Color = Color(0.92, 0.9, 0.82), font_size: int = 22, ink: Color = Color(0.1, 0.1, 0.15)) -> Level2Document:
	var d := Level2Document.new()
	d.title = doc_title
	d.note_lines = lines
	d.prompt = "Copy into your notebook: " + doc_title
	# Copying is each player's own business.
	d.local_only = true
	d.position = pos
	d.rotation_degrees.y = facing_deg
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, size.y, 0.06)
	shape.shape = bs
	d.add_child(shape)
	# Paper on the wall, facing local +Z; the text sits just in front of it.
	Greybox.panel(d, Vector3.ZERO, Vector3(size.x, size.y, 0.01), paper)
	Greybox.label(d, Vector3(0, 0, 0.008), text, font_size, ink)
	parent.add_child(d)
	d.add_to_group("interactable")
	d.used.connect(d._on_used)
	return d


func get_prompt(player: Node) -> String:
	if copied:
		return ""
	return super(player)


func _on_used(player: Node) -> void:
	if copied or not _is_local(player):
		return
	copied = true
	var game := get_node("/root/Game")
	for line in note_lines:
		game.write_note(title, line, "document")
	var level := _level()
	if level and level.get("hud"):
		level.hud.notice("Added to your notebook (Tab): %s" % title, 4.0)


func _is_local(player: Node) -> bool:
	var level := _level()
	return level == null or level.get("player") == null or player == level.player


## The level this paper is in. Duck-typed, so the test runner doesn't pull in Game.
func _level() -> Node:
	var n := get_parent()
	while n and not n.has_method("finish_level"):
		n = n.get_parent()
	return n
