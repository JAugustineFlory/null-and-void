class_name Document
extends Interactable
## A paper in the world: a brochure, a laminated card, one of Mercer's notes.
## E opens it to read, and any line can be copied into your notebook with an
## optional name (like "+ note" on a terminal). Reading and copying are each
## player's own business; the host only hears that someone read it (read_by).

## Host: someone picked this up or opened it, on any machine.
signal read_by(player: Node)

## Each look: the prop on the desk or wall (ArtProps) and its paper up close (DocumentView).
const LOOKS := {
	"paper": {"prop": "memo", "paper": "memo"},
	"note": {"prop": "memo", "paper": "memo"},
	"laminated": {"prop": "desk_card", "paper": "card"},
	"brochure": {"prop": "brochure", "paper": "brochure"},
	"manual": {"prop": "binder", "paper": "manual"},
	"clipboard": {"prop": "clipboard", "paper": "clipboard"},
	"sticky": {"prop": "sticky", "paper": "memo"},  # a handwritten sticky: its text is its only line
}

var title := ""
## What's on it, top to bottom. Each line is one of:
##   {"text": String, "hand": bool, "author": "mercer"|"player"}: typed, or handwritten
##   {"before", "filled", "after", "author"}: a printed line with a blank filled in by hand
## Every line also has "text": the whole line as it reads, which is what gets copied.
var doc_lines: Array[Dictionary] = []
var look := "paper"
## Its readable face, for picking it up (player.pick_up): size in metres, and the
## local direction that face points.
var read_size := Vector2(0.21, 0.28)
var read_face := Vector3.BACK
## What reading it adds to the reader's case pages: [{case, text}] (see Game.add_clue).
## A clue with "opens" (a case title, and optional "tables") opens that case too.
var clues: Array = []
## Pieces of cases it holds: [{case, piece}] (see Game.collect_piece). While any
## is still to find, E notes them straight into the case without picking it up,
## and X reads it. Anyone finding them finds them for the whole crew.
var pieces: Array = []
## Lying on a desk rather than up on a wall or a monitor.
var flat := false
## The prompt while it holds pieces still to find (drafts for Augustine's OK).
## A sticky this player has already copied into their notebook.
var _copied := false


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
	d.flat = flat
	# A sticky goes into the notebook like StickyNote's: taken off a desk, copied off a wall.
	if doc_look == "sticky":
		d.prompt = "Take the sticky note" if flat else "Copy the sticky note into your notebook"
	else:
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
	elif d.has("columns") and not d.has("text"):
		d["text"] = "  ".join(d.columns.map(func(c): return str(c)))  # a table's header copies as its names
	elif d.has("row") and not d.has("text"):
		d["text"] = "  ".join(d.row.map(func(c): return str(c)))
	elif d.has("stamp") and not d.has("text"):
		d["text"] = str(d.stamp)
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


## The prop from ArtProps, with a collider sized to its footprint. Sheets and
## cards on a wall are drawn full size instead, with their words readable.
func _build_look(size: Vector2, flat: bool) -> void:
	var prop: String = LOOKS.get(look, LOOKS.paper).prop
	if not flat and prop in ["memo", "desk_card"]:
		_build_wall_sheet(size)
		read_size = size
		read_face = Vector3.FORWARD
		return
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
		"sticky":
			art = ArtProps.sticky_note(self, Vector3.ZERO, 180.0, "\n".join(doc_lines.map(func(l): return l.text)), ArtProps.STICKY_YELLOW, flat)
			art.scale = Vector3.ONE * StickyNote.DESK_SCALE
			var side := 0.076 * StickyNote.DESK_SCALE
			art.set_meta("doc_size", Vector3(side, 0.01, side) if flat else Vector3(side, side, 0.01))
		_:
			art = ArtProps.memo(self, Vector3.ZERO, 180.0, title, flat)
	var footprint: Vector3 = art.get_meta("doc_size", Vector3(size.x, 0.01, size.y) if flat else Vector3(size.x, size.y, 0.01))
	read_size = Vector2(footprint.x, footprint.z) if flat else Vector2(footprint.x, footprint.y)
	read_face = Vector3.UP if flat else Vector3.BACK  # the art is turned to face +Z
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# A little thicker than the paper so it's easy to aim at.
	bs.size = Vector3(footprint.x, maxf(footprint.y, 0.05), maxf(footprint.z, 0.05))
	shape.shape = bs
	# On a desk the prop sits on its spot; on a wall it's centred there.
	shape.position.y = bs.size.y / 2 if flat or prop == "desk_card" else 0.0
	add_child(shape)


## A sheet or laminated card of `size` on the wall, facing -Z: what it says is
## printed on it big enough to read from where you stand. Laminated cards are
## glossy, with the title on a navy band.
func _build_wall_sheet(size: Vector2) -> void:
	var laminated := look == "laminated"
	var face := Node3D.new()
	face.name = "WallSheet"
	face.rotation_degrees.y = 180  # built facing +Z, turned to face -Z like a poster
	add_child(face)
	var paper := Color(0.95, 0.95, 0.92) if laminated else ArtProps.PAPER_WHITE
	var sheet := Greybox.panel(face, Vector3(0, 0, 0.003), Vector3(size.x, size.y, 0.004), paper)
	sheet.name = "Paper"
	if laminated:
		sheet.material_override = Greybox.mat(paper, 0.0, 0.15)  # glossy
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, size.y, 0.05)
	shape.shape = bs
	add_child(shape)
	if is_form():
		_print_form(face, size)
		return
	var margin := minf(size.x, size.y) * 0.07
	var top := size.y / 2 - margin
	var px := 0.0009  # metres per pixel of type
	var lines := doc_lines.duplicate()
	var first := 0  # the doc line the first Line label shows
	if laminated:
		# The card's own heading (its first printed line) goes on the navy band.
		var heading := title.to_upper()
		if not lines.is_empty() and not lines[0].hand:
			heading = lines.pop_front().text
			first = 1
		var band_h := size.y * 0.13
		var band := Greybox.panel(face, Vector3(0, size.y / 2 - band_h / 2 - margin * 0.4, 0.0055), Vector3(size.x - margin * 0.8, band_h, 0.001), ArtPalette.HALCYON_NAVY)
		band.name = "Band"
		var t := _wall_text(face, heading, Vector3(0, band.position.y, 0.0065), size.x - margin * 2, NotebookArt.type_font(), Color(0.95, 0.95, 0.92), px)
		t.name = "Title"
		if first == 1:
			t.set_meta("line_index", 0)
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		while t.font_size > 14 and (t.font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, t.font_size).x > t.width or t.font.get_height(t.font_size) * px > band_h * 0.8):
			t.font_size -= 2
		top = band.position.y - band_h / 2 - margin * 0.5
	# One label per line, typed or in pen, at the biggest size that fits the sheet.
	var width := size.x - margin * 2
	var room := top - (-size.y / 2 + margin)
	var font_size := 44
	while font_size > 14 and _lines_height(lines, font_size, width / px) * px > room:
		font_size -= 2
	var y := top
	var n := 0
	for l in lines:
		var font := _line_font(l)
		# Label3D anchors the text at its position: top left here.
		var label := _wall_text(face, l.text, Vector3(-width / 2, y, 0.0065), width, font, NotebookArt.INK if l.hand else ArtProps.PRINT_INK, px)
		label.name = "Line%d" % n
		label.set_meta("line_index", first + n)
		label.font_size = font_size
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		y -= _line_height(l, font_size, width / px) * px
		n += 1


## A form (a sign-in sheet, a table, a stamped page) is printed small and in
## detail, as it reads in your hands, rather than in big type that can't hold
## its columns.
func is_form() -> bool:
	return doc_lines.any(func(l): return l.has("columns") or l.has("row") or l.has("stamp"))


## The form's page (DocumentView, the same one you read held up) printed on the
## sheet, as big as fits it.
func _print_form(face: Node3D, size: Vector2) -> void:
	var kind := paper_kind()
	var px := Vector2(DocumentView.PAPERS[kind].size)
	var quad := QuadMesh.new()
	var scale_to := minf(size.x / px.x, size.y / px.y)
	quad.size = px * scale_to
	var print_mi := MeshInstance3D.new()
	print_mi.name = "Print"
	print_mi.mesh = quad
	print_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.albedo_texture = DocumentView.paper_texture(self, lines(), kind, title)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.roughness = 0.9
	print_mi.material_override = m
	print_mi.position = Vector3(0, 0, 0.0055)
	face.add_child(print_mi)


## A Label3D for a wall sheet, facing +Z, wrapping at `width_m`.
func _wall_text(parent: Node3D, text: String, pos: Vector3, width_m: float, font: Font, color: Color, px: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 44
	l.pixel_size = px
	l.width = width_m / px
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.double_sided = false
	l.shaded = true  # lit by the room, like the paper it's on
	parent.add_child(l)
	return l


static func _line_font(l: Dictionary) -> Font:
	return NotebookArt.hand_font() if l.hand else NotebookArt.type_font()


## How tall one line is in pixels of type, word-wrapped at `width_px`.
static func _line_height(l: Dictionary, font_size: int, width_px: float) -> float:
	var font := _line_font(l)
	var para := TextParagraph.new()
	para.width = width_px
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.add_string(l.text if l.text != "" else " ", font, font_size)
	return maxf(para.get_size().y, font.get_height(font_size))


static func _lines_height(lines: Array, font_size: int, width_px: float) -> float:
	var h := 0.0
	for l in lines:
		h += _line_height(l, font_size, width_px)
	return h


func get_prompt(player: Node) -> String:
	_seen_shining(player)
	if is_sticky() and _copied:
		return ""
	return super(player)


## Its pieces nobody has found yet.
func uncollected() -> Array:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return []
	return pieces.filter(func(p): return not game.has_piece(p.case, p.piece))


## A handwritten sticky note: it goes into the notebook, never up in your hands.
func is_sticky() -> bool:
	return look == "sticky"


func _on_used(player: Node) -> void:
	var level := _level()
	if level and level.get("player") != null and player != level.player:
		return
	if is_sticky():
		take_sticky(player)
		return
	_read(player)


## E picks it up to read, and reading it puts its pieces in their cases
## (report_open): with one case on the page and a shine on what it needs, the
## crew reads the paper rather than filing it unseen (Augustine, v0.7.1 playtest).
func _read(player: Node) -> void:
	if get_node("/root/Game").diegetic_ui and player.has_method("pick_up"):
		pick_up(player)
	else:
		open_reader(player)


## Every machine: this paper's pieces are found.
func _collect_pieces() -> void:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	for p in pieces:
		game.collect_piece(p.case, p.piece, title)


## Lift it up off the desk or wall to read it in your hands (Game.diegetic_ui).
## Returns the reader, or null if the player's hands are busy.
func pick_up(player: Node) -> DocumentReader:
	var reader := DocumentReader.new()
	var level := _level()
	(level if level else get_tree().root).add_child(reader)
	if not reader.hold(self, player):
		return null
	_note_clues()
	_report_read(player)
	return reader


## A sticky note goes into this player's notebook, as StickyNote's do: held in
## your hands (Game.diegetic_ui) you watch it go onto the Cases page first, and
## it's written down when it lands. Its clues go on their case pages; one with
## no case is kept under Other notes. A loose one is taken off the desk for
## everyone; one stuck to a wall or a monitor stays, and each player copies it.
func take_sticky(player: Node) -> void:
	if _copied:
		return
	_copied = true
	var game := get_node("/root/Game")
	var level := _level()
	var hud = level.hud if level and level.get("hud") else null
	var write := StickyNote.write_sticky.bind(game, hud, clues.duplicate(true), title, plain_text())
	var filed := false
	if game.diegetic_ui and player and player.has_method("file_into_notebook"):
		if level and level.get("notebook") and not level.notebook.is_open():
			level.notebook.open(NotebookPages.Page.CASES)  # where it's written down
		filed = player.file_into_notebook(self, not flat)
	if filed:
		player.sticky_filed.connect(func(_p): write.call(), CONNECT_ONE_SHOT)
	else:
		write.call()  # hands busy: it still goes in
	_report_read(player)


## Every machine: a loose sticky has been taken. While it's still flying onto
## the taker's page it's only hidden, and freed once it lands.
func _take_away() -> void:
	remove_from_group("interactable")
	visible = false
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	var level := _level()
	var p: Node = level.player if level else null
	if p and p.has_method("is_filing") and p.is_filing() and p.has_signal("sticky_filed"):
		p.sticky_filed.connect(func(_n): queue_free(), CONNECT_ONE_SHOT)
	else:
		queue_free()


## Open this document on this machine's screen. Returns the reader.
func open_reader(player: Node) -> DocumentReader:
	var reader := DocumentReader.new()
	var level := _level()
	(level if level else get_tree().root).add_child(reader)
	reader.open(self, player)
	_note_clues()
	_report_read(player)
	return reader


## Reading it puts its clues on this player's case pages. `quiet`: no notice.
func _note_clues(quiet: bool = false) -> void:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	var noted := ""
	for k in clues:
		if k.has("opens"):
			game.open_case(k.case, k.opens, k.get("tables", []))
		if game.add_clue(k.case, k.text, title):
			noted = game.case_info(k.case).title
	var level := _level()
	if noted != "" and not quiet and level and level.get("hud"):
		level.hud.notice("Noted on the case page: %s (Tab)" % noted, 3.0)


## Tell the host this was read (a story step may wait on a paper being found).
func _report_read(player: Node) -> void:
	shine(false)  # this player has read it, so it stops asking to be read
	var sync := LevelSync.of(self)
	if sync == null or not sync.forward(self, "report_open"):
		report_open(player)


## Host: someone read it (or took it, if it's a loose sticky). Its pieces are
## found for everyone.
func report_open(player: Node) -> void:
	if not pieces.is_empty():
		var s := LevelSync.of(self)
		if s:
			s.run_on(self, "_collect_pieces")
		else:
			_collect_pieces()
	read_by.emit(player)
	if is_sticky() and flat and is_in_group("interactable"):
		var sync := LevelSync.of(self)
		if sync:
			sync.run_on(self, "_take_away")
		else:
			_take_away()


## The level this document is in. Duck-typed, like StickyNote, so the test
## runner doesn't pull in the Game autoload at parse time.
func _level() -> Node:
	var n := get_parent()
	while n and not n.has_method("finish_level"):
		n = n.get_parent()
	return n
