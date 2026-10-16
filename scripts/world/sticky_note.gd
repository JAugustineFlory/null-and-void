class_name StickyNote
extends Interactable
## A sticky note with one piece of SQL on it (see StickyNotes). A loose note is taken
## by whoever picks it up. A note stuck to a terminal stays put, and anyone can copy
## it into their notebook.

signal taken(player: Node)

var note_id := ""
## Stuck to a terminal: copied, not taken.
var on_terminal := false


## Stick a note on a terminal's monitor, bottom-left of the screen.
static func on_monitor(terminal: Node3D, id: String) -> StickyNote:
	return place(terminal, Vector3(-0.17, 0.09, 0.237), id, true)


static func place(parent: Node, pos: Vector3, id: String, stuck_to_terminal: bool, facing_deg: float = 0.0) -> StickyNote:
	var n := StickyNote.new()
	n.note_id = id
	n.on_terminal = stuck_to_terminal
	n.prompt = "Copy the sticky note into your notebook" if stuck_to_terminal else "Take the sticky note"
	n.position = pos
	n.rotation_degrees.y = facing_deg
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.16, 0.01)
	mesh.mesh = bm
	mesh.material_override = Greybox.mat(NotebookView.STICKY)
	n.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# Deeper than the paper and pushed forward, so it wins over a terminal behind it.
	bs.size = Vector3(0.18, 0.18, 0.16)
	shape.shape = bs
	shape.position.z = 0.07
	n.add_child(shape)
	var text := Label3D.new()
	text.text = StickyNotes.get_note(id).get("label", "")
	text.font_size = 22
	text.pixel_size = 0.002
	text.modulate = Color(0.1, 0.1, 0.35)
	text.outline_size = 0
	text.position = Vector3(0, 0, 0.007)
	n.add_child(text)
	parent.add_child(n)
	n.add_to_group("interactable")
	n.used.connect(n._on_used)
	return n


func get_prompt(player: Node) -> String:
	if on_terminal and _is_local(player) and get_node("/root/Game").notebook_notes.has(note_id):
		return ""
	return super(player)


func _on_used(player: Node) -> void:
	if _is_local(player):
		var title: String = StickyNotes.get_note(note_id).get("title", "")
		var level := _level()
		if get_node("/root/Game").add_note(note_id) and level and level.hud:
			level.hud.notice("Added to your notebook (Tab): %s" % title, 4.0)
	taken.emit(player)
	if not on_terminal:
		queue_free()


## Only the local player's pickups go in this machine's notebook.
func _is_local(player: Node) -> bool:
	var level := _level()
	return level == null or level.player == null or player == level.player


## The level this note is in. Duck-typed: naming LevelBase here would pull the Game
## autoload into the test runner at parse time.
func _level() -> Node:
	var n := get_parent()
	while n and not n.has_method("finish_level"):
		n = n.get_parent()
	return n
