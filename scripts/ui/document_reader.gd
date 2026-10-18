class_name DocumentReader
extends CanvasLayer
## A document held up to read (see Document), drawn by DocumentView. Each line has
## a "+ note" button that copies it into this player's notebook, with an optional
## name. E or Esc puts it down.
## Two ways to read: open() shows it full screen; hold() (Game.diegetic_ui) lifts
## the paper itself up to your eyes in your hands (player.pick_up, HeldPaper), and
## with the cursor out (right mouse) the pointer reaches the chips on its page.

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
	player.prop_lowered.connect(_on_lowered, CONNECT_ONE_SHOT)
	return true


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


func _start_note(index: int) -> void:
	if index < 0:
		return
	_note_index = index
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
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()


## Held: the pointer over the paper reaches its page, so "+ note" chips work there.
func _forward_mouse(event: InputEventMouse) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or _note_label.visible:
		return
	var at := page_point(event.position)
	if at.x < 0.0:
		return
	var ev: InputEventMouse = event.duplicate()
	ev.position = at
	ev.global_position = at
	page_viewport.push_input(ev)
	get_viewport().set_input_as_handled()
