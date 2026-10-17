class_name Document
extends Interactable
## A paper in the world: a brochure, a laminated card, one of Mercer's notes.
## E opens it to read, and any line can be copied into your notebook with an
## optional name (like "+ note" on a terminal). Reading and copying are each
## player's own business, so in co-op nothing goes to the host.

## Each look: the prop on the desk or wall (ArtProps) and its paper up close (DocumentView).
const LOOKS := {
	"paper": {"prop": "memo", "paper": "memo"},
	"note": {"prop": "memo", "paper": "memo"},
	"laminated": {"prop": "desk_card", "paper": "card"},
	"brochure": {"prop": "brochure", "paper": "brochure"},
	"manual": {"prop": "binder", "paper": "manual"},
	"clipboard": {"prop": "clipboard", "paper": "clipboard"},
}

var title := ""
## What's on it, top to bottom. Each line is one of:
##   {"text": String, "hand": bool, "author": "mercer"|"player"}: typed, or handwritten
##   {"before", "filled", "after", "author"}: a printed line with a blank filled in by hand
## Every line also has "text": the whole line as it reads, which is what gets copied.
var doc_lines: Array[Dictionary] = []
var look := "paper"


## `lines` is an Array of Strings (typed lines) or Dictionaries (see doc_lines).
## Stands like a poster facing -Z, or lies flat on a desk with `flat`; on a desk,
## `pos` is the desk-top spot. `size` is only a fallback for an unknown look.
static func place(parent: Node, pos: Vector3, facing_deg: float, doc_title: String, lines: Array, flat: bool = false, doc_look: String = "paper", size := Vector2(0.21, 0.28)) -> Document:
	var d := Document.new()
	d.name = "Doc_" + doc_title.validate_node_name().replace(" ", "")
	d.title = doc_title
	d.look = doc_look
	for l in lines:
		d.doc_lines.append(_line(l))
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


static func _line(l: Variant) -> Dictionary:
	if not l is Dictionary:
		return {"text": str(l), "hand": false}
	var d: Dictionary = l.duplicate()
	if d.has("filled"):
		d["text"] = "%s%s%s" % [d.get("before", ""), d.filled, d.get("after", "")]
	d["hand"] = d.get("hand", false)
	return d


## The document's text, for the reader and the teaching tests.
func lines() -> Array[Dictionary]:
	return doc_lines.duplicate(true)


func plain_text() -> String:
	return "\n".join(doc_lines.map(func(l): return l.text))


## Which DocumentView paper it reads on.
func paper_kind() -> String:
	return LOOKS.get(look, LOOKS.paper).paper


## The prop from ArtProps, with a collider sized to its footprint.
func _build_look(size: Vector2, flat: bool) -> void:
	var prop: String = LOOKS.get(look, LOOKS.paper).prop
	# Props face -Z like a poster; turn them to face out, as StickyNote does.
	var art: Node3D
	match prop:
		"desk_card":
			art = ArtProps.desk_card(self, Vector3.ZERO, 180.0, title)
		"brochure":
			art = ArtProps.brochure(self, Vector3.ZERO, 180.0, title, flat)
		"binder":
			art = ArtProps.binder(self, Vector3.ZERO, 180.0, title, flat)
		"clipboard":
			art = ArtProps.clipboard(self, Vector3.ZERO, 180.0, title, flat)
		_:
			art = ArtProps.memo(self, Vector3.ZERO, 180.0, title, flat)
	var footprint: Vector3 = art.get_meta("doc_size", Vector3(size.x, 0.01, size.y) if flat else Vector3(size.x, size.y, 0.01))
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# A little thicker than the paper so it's easy to aim at.
	bs.size = Vector3(footprint.x, maxf(footprint.y, 0.05), maxf(footprint.z, 0.05))
	shape.shape = bs
	# On a desk the prop sits on its spot; on a wall it's centred there.
	shape.position.y = bs.size.y / 2 if flat or prop == "desk_card" else 0.0
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
