class_name DocumentReader
extends CanvasLayer
## A document held up to read (see Document), drawn by DocumentView. Each line has
## a "+ note" button that copies it into this player's notebook, with an optional
## name. E, Esc or Tab puts it down.
## Two ways to read: open() shows it full screen; hold() (Game.diegetic_ui) lifts
## the paper itself up to your eyes in your hands (player.pick_up, HeldPaper), and
## the cursor reaches the chips on its page (or, on a wall sheet in big print, a
## chip beside the line it's over).

signal closed

var document: Node
var player: Node
var view: DocumentView
var _note_label: LineEdit
var _note_index := -1
var _opened_frame := -1
## Held in the player's hands rather than full screen.
var held := false
var hands: HeldPaper
## The page drawn on the held paper, whose chips the pointer reaches.
var page_viewport: SubViewport
var _closing := false
var _hidden: Array[Node3D] = []  # the prop's own look, while its page is held up instead
## A wall sheet in big print is read off its own labels (the text doesn't shrink
## when you pick it up); this chip copies the line under the pointer.
var _labels: Array[Label3D] = []
var _chip: Button
var _chip_index := -1


func _ready() -> void:
	layer = 20
	view = DocumentView.new()
	add_child(view)
	view.copy_requested.connect(func(text): _start_note(_index_of(text)))
	view.closed.connect(close)
	_note_label = LineEdit.new()
	_note_label.visible = false
	_note_label.placeholder_text = "Name this note (optional), then Enter. Esc to cancel."
	_note_label.max_length = 40
	_note_label.custom_minimum_size = Vector2(520, 0)
	_note_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_note_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_note_label.offset_top = -64
	_note_label.offset_bottom = -24
	_note_label.text_submitted.connect(func(t): _finish_note(t))
	add_child(_note_label)


func open(doc: Node, by_player: Node) -> void:
	document = doc
	player = by_player
	_opened_frame = Engine.get_process_frames()
	if player and "input_locked" in player:
		player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view.clear()
	view.set_paper(document.paper_kind())
	view.set_title(document.title)
	view.add_lines(document.lines())
	view.show_doc()


## Pick the document up and read it in your hands. False if the player's hands
## are busy (the reader then frees itself).
func hold(doc: Node, by_player: Node) -> bool:
	document = doc
	player = by_player
	held = true
	view.visible = false
	_opened_frame = Engine.get_process_frames()
	if not player.pick_up(doc, doc.read_size, doc.read_face):
		queue_free()
		return false
	hands = player.camera.get_node_or_null("HeldPaper") as HeldPaper
	if hands == null:
		hands = HeldPaper.attach(player.camera)
		hands.follow(player)
	hands.hold(doc, doc.read_size, doc.read_face, doc)
	if doc.paper_kind() == "brochure":
		# Its side panels fold up in front of the page; held, you see it opened out flat.
		for mi in doc.find_children("*", "GeometryInstance3D", true, false):
			if mi != hands.page and mi.visible:
				mi.visible = false
				_hidden.append(mi)
	var sheet: Node = doc.get_node_or_null("WallSheet")
	if sheet:
		var printed := sheet.get_node_or_null("Print") as GeometryInstance3D
		if printed:
			# A form: the page laid over it is the same print, so only one shows.
			printed.visible = false
			_hidden.append(printed)
		else:
			# Big print: read the words on the sheet itself, not a smaller page over them.
			hands.page.visible = false
			for l in sheet.get_children():
				if l is Label3D and l.has_meta("line_index"):
					_labels.append(l)
			_make_chip()
			return _finish_hold()
	for vp in hands.get_children():
		if vp is SubViewport and not vp.is_queued_for_deletion():
			page_viewport = vp
	if page_viewport:
		# Kept drawing while held, so a chip shows under the pointer.
		page_viewport.set_process(false)
		page_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var page_view := page_viewport.get_child(0) as DocumentView
		if page_view:
			page_view.copy_requested.connect(func(text): _start_note(_index_of(text)))
	return _finish_hold()


func _finish_hold() -> bool:
	player.prop_lowered.connect(_on_lowered, CONNECT_ONE_SHOT)
	return true


func _make_chip() -> void:
	_chip = Button.new()
	_chip.name = "NoteChip"
	_chip.text = "+ note"
	_chip.visible = false
	_chip.focus_mode = Control.FOCUS_NONE
	_chip.pressed.connect(func(): _start_note(_chip_index))
	add_child(_chip)


## The screen rect a held label covers, or an empty rect when it's off screen.
func label_rect(l: Label3D) -> Rect2:
	var cam: Camera3D = player.camera
	var box := l.get_aabb()
	var r := Rect2()
	var first := true
	for i in 8:
		var at := l.global_transform * box.get_endpoint(i)
		if cam.is_position_behind(at):
			return Rect2()
		var p := cam.unproject_position(at)
		if first:
			r = Rect2(p, Vector2.ZERO)
			first = false
		else:
			r = r.expand(p)
	return r


## Big print: the line under the pointer (its doc index), or -1.
func line_at(screen_pos: Vector2) -> int:
	for l in _labels:
		if is_instance_valid(l) and l.text.strip_edges() != "" and label_rect(l).grow(4).has_point(screen_pos):
			return l.get_meta("line_index")
	return -1


## The chip sits just right of the line under the pointer, and stays while the
## pointer moves onto it.
func _hover(screen_pos: Vector2) -> void:
	if _chip == null:
		return
	if _chip.visible and _chip.get_global_rect().grow(6).has_point(screen_pos):
		return
	var index := line_at(screen_pos) if not _note_label.visible else -1
	_chip_index = index
	_chip.visible = index >= 0
	if index < 0:
		return
	for l in _labels:
		if is_instance_valid(l) and l.get_meta("line_index") == index:
			var r := label_rect(l)
			_chip.reset_size()
			var at := Vector2(r.end.x + 6, r.position.y + r.size.y / 2 - _chip.size.y / 2)
			var screen := get_viewport().get_visible_rect().size
			at.x = minf(at.x, screen.x - _chip.size.x - 4)
			_chip.position = at


## The point on the held page's image (viewport pixels) under a screen position,
## or (-1, -1) when the pointer is off the paper.
func page_point(screen_pos: Vector2) -> Vector2:
	if hands == null or not is_instance_valid(hands.page) or page_viewport == null:
		return Vector2(-1, -1)
	var cam: Camera3D = player.camera
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var plane := Plane(hands.page.global_basis.z.normalized(), hands.page.global_position)
	var hit = plane.intersects_ray(origin, dir)
	if hit == null:
		return Vector2(-1, -1)
	var local: Vector3 = hands.page.global_transform.affine_inverse() * (hit as Vector3)
	var quad: Vector2 = (hands.page.mesh as QuadMesh).size
	var uv := Vector2(local.x / quad.x + 0.5, 0.5 - local.y / quad.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2(-1, -1)
	return uv * Vector2(page_viewport.size)


func _on_lowered(_prop: Node) -> void:
	_finish_close()


func close() -> void:
	if not is_inside_tree():
		return
	if held:
		# Put it back where it came from; the reader goes once it's down.
		if _closing:
			return
		_closing = true
		_cancel_note()
		if player and is_instance_valid(player) and player.held_prop == document:
			player.put_down()
		else:
			_finish_close()
		return
	_finish_close()


func _finish_close() -> void:
	if not is_inside_tree():
		return
	if held:
		for mi in _hidden:
			if is_instance_valid(mi):
				mi.visible = true
		if player and player.prop_lowered.is_connected(_on_lowered):
			player.prop_lowered.disconnect(_on_lowered)
		closed.emit()
		queue_free()
		return
	if player and is_instance_valid(player) and "input_locked" in player:
		player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


## Copy line `index` into this player's notebook. A blank name uses the
## document's title, so the note says where it came from.
func write_note(index: int, label: String = "") -> bool:
	var all: Array[Dictionary] = document.lines()
	if index < 0 or index >= all.size() or str(all[index].text).strip_edges() == "":
		return false
	if answer(index):
		return true
	var name_it := label.strip_edges()
	get_node("/root/Game").write_note(name_it if name_it != "" else document.title, str(all[index].text).strip_edges(), "document")
	var level: Node = document._level()
	if level and level.get("hud"):
		level.hud.notice("Added to your notebook (Tab)", 3.0)
	return true


func _index_of(text: String) -> int:
	var all: Array[Dictionary] = document.lines()
	for i in all.size():
		if all[i].text == text:
			return i
	return -1


## Line `index` answers a case's blank (Game.add_answer): it's written in there,
## with no name to give it, and the paper goes back down while the notebook comes
## up to show it written in (Notebook). False if it answers nothing.
func answer(index: int) -> bool:
	var all: Array[Dictionary] = document.lines()
	if index < 0 or index >= all.size() or not get_node("/root/Game").add_answer(str(all[index].text), "document"):
		return false
	close()
	return true


func _start_note(index: int) -> void:
	if index < 0:
		return
	if answer(index):
		return
	_note_index = index
	if _chip:
		_chip.visible = false
	_note_label.text = ""
	_note_label.visible = true
	_note_label.grab_focus()
	if held and "input_locked" in player:
		player.input_locked = true  # stand still while you name it


func _finish_note(label: String) -> void:
	write_note(_note_index, label)
	_cancel_note()


func _cancel_note() -> void:
	if held and _note_label.visible and player and is_instance_valid(player) and "input_locked" in player:
		player.input_locked = false
	_note_index = -1
	_note_label.visible = false
	_note_label.release_focus()


func _input(event: InputEvent) -> void:
	if held and event is InputEventMouse:
		_forward_mouse(event)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _note_label.visible:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_cancel_note()
		return
	# The E that opened it mustn't also put it down.
	if Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("interact") or event.is_action_pressed("notebook"):
		get_viewport().set_input_as_handled()
		close()


## Held: the pointer over the paper reaches its page, so "+ note" chips work there.
func _forward_mouse(event: InputEventMouse) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or _note_label.visible:
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return  # only the left button clicks the page (see HeldNotebook._input)
	if _chip:
		_hover(event.position)  # the chip is a button on this layer; the click reaches it
		return
	var at := page_point(event.position)
	if at.x < 0.0:
		return
	var ev: InputEventMouse = event.duplicate()
	ev.position = at
	ev.global_position = at
	page_viewport.push_input(ev)
	get_viewport().set_input_as_handled()
