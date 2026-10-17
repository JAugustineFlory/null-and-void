class_name Document
extends Interactable
## A paper in the world: a brochure, a laminated card, one of Mercer's notes.
## E opens it to read, and any line can be copied into your notebook with an
## optional name (like "+ note" on a terminal). Reading and copying are each
## player's own business, so in co-op nothing goes to the host.

const LOOKS := {
	"paper": Color(0.93, 0.91, 0.84),
	"laminated": Color(0.88, 0.93, 0.95),
	"brochure": Color(0.84, 0.9, 0.98),
	"note": Color(0.96, 0.93, 0.78),
}

var title := ""
## What's on it, top to bottom: {"text": String, "hand": bool}. `hand` lines are
## handwritten (someone filled in a blank or wrote in the margin).
var doc_lines: Array[Dictionary] = []
var look := "paper"


## `lines` is an Array of Strings or {text, hand} Dictionaries. Stands like a
## poster facing -Z, or lies flat on a desk with `flat`.
static func place(parent: Node, pos: Vector3, facing_deg: float, doc_title: String, lines: Array, flat: bool = false, doc_look: String = "paper", size := Vector2(0.21, 0.28)) -> Document:
	var d := Document.new()
	d.name = "Doc_" + doc_title.validate_node_name().replace(" ", "")
	d.title = doc_title
	d.look = doc_look
	for l in lines:
		d.doc_lines.append(l if l is Dictionary else {"text": str(l), "hand": false})
	d.prompt = "Read: %s" % doc_title
	d.local_only = true
	d.position = pos
	d.rotation_degrees.y = facing_deg
	d._build_look(size, flat)
	parent.add_child(d)
	d.add_to_group("interactable")
	d.add_to_group("document")
	d.used.connect(d._on_used)
	return d


## The document's text, for the reader and the teaching tests.
func lines() -> Array[Dictionary]:
	return doc_lines.duplicate(true)


func plain_text() -> String:
	return "\n".join(doc_lines.map(func(l): return l.text))


## Greybox look until the art pass: a sheet with its title on it.
func _build_look(size: Vector2, flat: bool) -> void:
	var face := Node3D.new()
	face.name = "Face"
	if flat:
		face.rotation_degrees.x = 90
	add_child(face)
	var paper: Color = LOOKS.get(look, LOOKS.paper)
	var sheet := MeshInstance3D.new()
	sheet.name = "Paper"
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, size.y, 0.002)
	sheet.mesh = bm
	sheet.material_override = ArtProps.sticky_paper(paper)
	face.add_child(sheet)
	var l := Label3D.new()
	l.name = "Title"
	l.text = title
	l.font_size = 40
	l.pixel_size = 0.0005
	l.width = size.x * 0.85 / l.pixel_size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(0.12, 0.14, 0.22)
	l.outline_size = 0
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.position = Vector3(0, size.y * 0.42, -0.0016)
	l.rotation_degrees.y = 180
	l.double_sided = false
	face.add_child(l)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# A little thicker than the paper so it's easy to aim at.
	bs.size = Vector3(size.x, 0.06, size.y) if flat else Vector3(size.x, size.y, 0.06)
	shape.shape = bs
	add_child(shape)


func _on_used(player: Node) -> void:
	var level := _level()
	if level and level.get("player") != null and player != level.player:
		return
	open_reader(player)


## Open this document on this machine's screen. Returns the reader.
func open_reader(player: Node) -> DocumentReader:
	var reader := DocumentReader.new()
	var level := _level()
	(level if level else get_tree().root).add_child(reader)
	reader.open(self, player)
	return reader


## The level this document is in. Duck-typed, like StickyNote, so the test
## runner doesn't pull in the Game autoload at parse time.
func _level() -> Node:
	var n := get_parent()
	while n and not n.has_method("finish_level"):
		n = n.get_parent()
	return n
