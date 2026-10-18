class_name HeldNotebook
extends Node3D
## The pocket notebook held open in the player's hands, in first person: the
## NotebookView pages are drawn into a SubViewport and shown on the open spread,
## low in the view so the room stays visible above it. Mouse clicks on the pages
## reach the buttons on them (tabs, "+ note", next page). Visual only: what's on
## the pages and when it opens belong to the notebook's own script.
##
##   var held := HeldNotebook.attach(player.camera, CharacterLooks.crew(0))
##   held.set_content(pages)          # a NotebookPages, or any Control holding a NotebookView
##   held.open_book()                 # pulls it out and opens it; close_book() puts it away
##   held.write_in(item)              # after adding a line to a page: it's written in
##   held.follow(player)              # your free hand carries notes in (player.file_into_notebook)
##
## The view is not dimmed and nothing else on screen is covered. Mouse mode must be
## visible while it's open, so the player can click the pages.

signal opened
signal closed

const BOOK_WIDTH := 0.2  # the open spread, metres (a pocket notebook)
const WIDTH_FRACTION := 0.62  # of the screen's width, for the book without its tabs
const MAX_HEIGHT_FRACTION := 0.62  # never more of the screen's height than this
const TILT := 14.0  # top of the book leans away, like holding it to read
const SPREAD_ANGLE := 7.0  # each half tilts up from the spine
const CLOSED_ANGLE := 176.0

var viewport: SubViewport
var view: NotebookView  # the embedded book, found in the content
var book_root: Node3D  # the whole notebook; move this for poses
var left_half: Node3D
var right_half: Node3D
var halves: Array[MeshInstance3D] = []  # the two page quads, for clicking

var _camera: Camera3D
var _open := false
var _open_t := 0.0  # 0 put away, 1 open in hand
var _tween: Tween
var _wiggle := 0.0
var _reach: Node3D  # the free hand that carries sticky notes in
var _player: Node  # whose filing to follow
var _dip := 0.0  # the book lowers out of the way while a note comes in


static func attach(camera: Camera3D, look: Dictionary = {}) -> HeldNotebook:
	var h := HeldNotebook.new()
	h.name = "HeldNotebook"
	h._camera = camera
	h._make(look)
	camera.add_child(h)
	return h


## Puts a Control on the pages: a NotebookPages, or a NotebookView of your own.
## Any NotebookView inside it is switched to embedded (not dimmed, not scaled).
func set_content(content: Control) -> void:
	viewport.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for nb in [content] + content.find_children("*", "NotebookView", true, false):
		if nb is NotebookView:
			nb.embedded = true
			view = nb


func is_open() -> bool:
	return _open


## Pulls the notebook out of the pocket and opens it in front of you.
func open_book() -> Tween:
	_open = true
	visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if view:
		view.visible = true
	return _animate_and_signal(1.0, 0.45, Tween.EASE_OUT, opened)


## Closes it and puts it back in the pocket.
func close_book() -> Tween:
	_open = false
	return _animate_and_signal(0.0, 0.3, Tween.EASE_IN, closed)


## Writes `item` onto its page with the pen, and the hands move with it.
func write_in(item: Control, duration: float = 0.8) -> Tween:
	_wiggle = duration
	if view:
		return view.write_in(item, duration)
	var t := create_tween()
	t.tween_interval(duration)
	return t


## Follow the player's sticky-note filing (player.file_into_notebook, read through
## filing_note() and filing_progress()): while a
## note travels onto the page, your free hand carries it there and the book dips
## out of its way, then the hand goes back to the book.
func follow(player: Node) -> void:
	_player = player


## The note being filed right now, and how far along it is (0..1), or null.
func _filing() -> Array:
	if _player == null or not is_instance_valid(_player):
		return []
	if not _player.has_method("filing_note"):
		return []
	var note = _player.call("filing_note")
	if not (note is Node3D) or not is_instance_valid(note):
		return []
	return [note, float(_player.call("filing_progress"))]


## A point on the page image (viewport pixels) in the world, on whichever half shows it.
func page_to_world(px: Vector2) -> Vector3:
	var full := Vector2(NotebookView.EMBED_SIZE)
	var uv := px / full
	for quad in halves:
		var mat := quad.material_override as ShaderMaterial
		var off: Vector2 = mat.get_shader_parameter("uv_offset")
		var sc: Vector2 = mat.get_shader_parameter("uv_scale")
		var local_uv := (uv - off) / sc
		if local_uv.x < 0.0 or local_uv.x > 1.0:
			continue
		var qs: Vector2 = (quad.mesh as QuadMesh).size
		return quad.global_transform * Vector3((local_uv.x - 0.5) * qs.x, (0.5 - local_uv.y) * qs.y, 0.0)
	return halves[1].global_position


## The free hand on the note being filed, the book lowered while it's on its way.
func _carry_note(delta: float) -> void:
	var f := _filing()
	var right := book_root.get_node("RightHand")
	if f.is_empty():
		if _reach.visible:
			_reach.visible = false
			right.visible = true
			_dip = 0.0
		return
	var note: Node3D = f[0]
	var t: float = f[1]
	right.visible = false
	_reach.visible = true
	_dip = move_toward(_dip, sin(PI * clampf(t, 0.0, 1.0)), delta * 6.0)
	# Pinching the note's bottom edge, palm behind it.
	var at := note.global_transform.orthonormalized()
	_reach.global_transform = Transform3D(at.basis, at.origin - at.basis.y * 0.03)


## Where the open book sits in front of the camera, for the camera's field of view
## and the screen's shape: the book (not its tabs) spans WIDTH_FRACTION of the
## width, centred, with its foot just above the bottom edge.
func reading_transform() -> Transform3D:
	var tan_v := tan(deg_to_rad((_camera.fov if _camera else 75.0) / 2.0))
	var rect := get_viewport().get_visible_rect() if is_inside_tree() else Rect2(0, 0, 16, 9)
	var tan_h := tan_v * rect.size.x / maxf(rect.size.y, 1.0)
	var basis := Basis.from_euler(Vector3(deg_to_rad(-TILT), 0, 0))
	var half_w := BOOK_WIDTH / 2.0
	var half_h := _px_to_m(NotebookView.BOOK_SIZE.y) / 2.0
	var d := half_w / (tan_h * WIDTH_FRACTION)
	var y := 0.0
	# Solve on the book's corners as the camera sees them (the tilt brings the foot closer).
	for i in 4:
		var low := basis * Vector3(-half_w, -half_h, 0)
		var high := basis * Vector3(-half_w, half_h, 0)
		var wide := absf(low.x) / (d - low.z)  # the foot is the widest edge on screen
		d *= wide / (tan_h * WIDTH_FRACTION)
		var tall := (high.y / (d - high.z) - low.y / (d - low.z)) / (2.0 * tan_v)
		if tall > MAX_HEIGHT_FRACTION:
			d *= tall / MAX_HEIGHT_FRACTION
		# Foot just above the bottom of the screen.
		y = -0.88 * tan_v * (d - low.z) - low.y
	return Transform3D(basis, Vector3(0, y, -d))  # the origin is the spine, the middle of the book


## The size of the whole page image (book and tabs) in metres.
func page_size() -> Vector2:
	var vs := Vector2(NotebookView.EMBED_SIZE)
	return Vector2(_px_to_m(vs.x), _px_to_m(vs.y))


func _px_to_m(px: float) -> float:
	return px * BOOK_WIDTH / NotebookView.BOOK_SIZE.x


func _make(look_in: Dictionary) -> void:
	viewport = SubViewport.new()
	viewport.name = "Pages"
	viewport.size = NotebookView.EMBED_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.gui_embed_subwindows = true
	add_child(viewport)
	visible = false

	book_root = Node3D.new()
	book_root.name = "Book"
	add_child(book_root)
	var spine_px := NotebookView.EMBED_MARGIN.x + NotebookView.BOOK_SIZE.x / 2.0
	var full := Vector2(NotebookView.EMBED_SIZE)
	var size := page_size()
	var spine_x := _px_to_m(spine_px)
	var cover := ArtPalette.flat(NotebookView.COVER, 0.7)
	var edges := ArtPalette.flat(NotebookArt.PAPER.darkened(0.08), 0.9)
	var book_h := _px_to_m(NotebookView.BOOK_SIZE.y)
	var book_mid_y := size.y / 2.0 - _px_to_m(NotebookView.EMBED_MARGIN.y + NotebookView.BOOK_SIZE.y / 2.0)
	for side in [-1, 1]:
		var half := Node3D.new()
		half.name = "Left" if side < 0 else "Right"
		book_root.add_child(half)
		var w := spine_x if side < 0 else size.x - spine_x
		var px0 := 0.0 if side < 0 else spine_px
		var px1 := spine_px if side < 0 else full.x
		var quad := MeshInstance3D.new()
		quad.name = "Page"
		var qm := QuadMesh.new()
		qm.size = Vector2(w, size.y)
		quad.mesh = qm
		quad.position = Vector3(side * w / 2.0, 0, 0.0035)
		quad.material_override = _page_material(Vector2(px0 / full.x, 0), Vector2((px1 - px0) / full.x, 1))
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		half.add_child(quad)
		halves.append(quad)
		# The cover board and the paper's edge under the drawn page.
		var bw := _px_to_m(NotebookView.BOOK_SIZE.x / 2.0)
		_box(half, Vector3(bw, book_h, 0.003), Vector3(side * bw / 2.0, book_mid_y, 0.0), cover)
		_box(half, Vector3(bw - 0.004, book_h - 0.006, 0.003), Vector3(side * (bw / 2.0 - 0.001), book_mid_y, 0.0018), edges)
		if side < 0:
			left_half = half
		else:
			right_half = half
	_hands(look_in, size, book_mid_y, book_h)
	_reach = HeldNotebook.make_hand(self, 1.0, look_in)
	_reach.name = "ReachHand"
	_reach.top_level = true
	_reach.visible = false
	_pose(0.0)


func _page_material(offset: Vector2, scale: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _page_shader()
	m.set_shader_parameter("page", viewport.get_texture())
	m.set_shader_parameter("uv_offset", offset)
	m.set_shader_parameter("uv_scale", scale)
	return m


static var _shader: Shader


static func _page_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform sampler2D page : source_color, filter_linear;
uniform vec2 uv_offset = vec2(0.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float brightness = 0.93;
void fragment() {
	vec2 uv = UV * uv_scale + uv_offset;
	vec2 f = fwidth(uv) * 0.4;  // a few taps: the page is drawn smaller than its pixels, with no mipmaps
	vec4 c = (texture(page, uv) * 2.0 + texture(page, uv + f) + texture(page, uv - f)
		+ texture(page, uv + vec2(f.x, -f.y)) + texture(page, uv + vec2(-f.x, f.y))) / 6.0;
	ALBEDO = c.rgb * brightness;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""
	return _shader


func _hands(look_in: Dictionary, size: Vector2, mid_y: float, book_h: float) -> void:
	var bw := _px_to_m(NotebookView.BOOK_SIZE.x / 2.0)
	for side in [-1.0, 1.0]:
		var hand := HeldNotebook.make_hand(book_root, side, look_in)
		hand.name = "LeftHand" if side < 0 else "RightHand"
		hand.position = Vector3(side * (bw - 0.012), mid_y - book_h / 2.0 + 0.012, 0.0)


## A first-person hand (palm, thumb and sleeve) under `parent`, holding something
## by its edge: its origin is where the thumb pinches. `side` -1 left, 1 right.
static func make_hand(parent: Node3D, side: float, look_in: Dictionary = {}) -> Node3D:
	var look := CharacterLooks.base()
	look.merge(look_in, true)
	var skin := ArtPalette.flat(look.skin, 0.7)
	var sleeve := ArtPalette.flat(look.jacket if look.jacket is Color else look.shirt, 0.9)
	var hand := Node3D.new()
	parent.add_child(hand)
	_piece(hand, Vector3(0.05, 0.06, 0.02), Vector3(side * 0.012, -0.02, -0.013), skin)  # palm behind what it holds
	var thumb := _piece(hand, Vector3(0.012, 0.03, 0.009), Vector3(-side * 0.002, 0.0, 0.007), skin)  # thumb in front
	thumb.rotation_degrees.z = side * 35.0
	var arm := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.028
	cm.height = 0.3
	arm.mesh = cm
	arm.material_override = sleeve
	arm.position = Vector3(side * 0.03, -0.12, -0.06)
	arm.rotation_degrees = Vector3(-25, 0, side * 25)
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand.add_child(arm)
	return hand


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	return _piece(parent, size, pos, mat)


static func _piece(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _animate_and_signal(to: float, time: float, easing: Tween.EaseType, done: Signal) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(easing)
	_tween.tween_method(_pose, _open_t, to, time * absf(to - _open_t) + 0.01)
	_tween.tween_callback(func():
		if to <= 0.0:
			visible = false
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		done.emit())
	return _tween


## 0: closed in the pocket (below the bottom-right of the screen); 1: open and readable.
func _pose(t: float) -> void:
	_open_t = t
	var read := reading_transform()
	var pocket := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-60), deg_to_rad(-20), deg_to_rad(35))), read.origin + Vector3(0.12, -0.2, 0.04))
	var lift := clampf(t / 0.7, 0.0, 1.0)  # comes up first, then opens
	var open := clampf((t - 0.45) / 0.55, 0.0, 1.0)
	book_root.transform = pocket.interpolate_with(read, ease(lift, 0.6)).translated(Vector3(0.04 * _dip, -0.1 * _dip, 0.02 * _dip))
	var hinge := lerpf(CLOSED_ANGLE, SPREAD_ANGLE, ease(open, 0.5))
	left_half.rotation_degrees.y = hinge  # the front cover swings open on the spine
	right_half.rotation_degrees.y = -SPREAD_ANGLE
	book_root.get_node("LeftHand").visible = open > 0.6


func _process(delta: float) -> void:
	if not visible:
		return
	_carry_note(delta)
	if _open and (_tween == null or not _tween.is_running()):
		_pose(1.0)  # follow fov and window changes
	if _wiggle > 0.0:
		_wiggle -= delta
		book_root.position += Vector3(sin(_wiggle * 40.0) * 0.0006, cos(_wiggle * 33.0) * 0.0004, 0.0)


## Mouse over the pages reaches the buttons drawn on them.
func _input(event: InputEvent) -> void:
	if not _open or not (event is InputEventMouse) or _camera == null:
		return
	var at := page_point(event.position)
	if at.x < 0.0:
		return
	var ev: InputEventMouse = event.duplicate()
	ev.position = at
	ev.global_position = at
	viewport.push_input(ev)
	get_viewport().set_input_as_handled()


## The point on the page image (viewport pixels) under a screen position, or (-1, -1).
func page_point(screen_pos: Vector2) -> Vector2:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var full := Vector2(NotebookView.EMBED_SIZE)
	for quad in halves:
		var inv := quad.global_transform.affine_inverse()
		var o := inv * origin
		var d := inv.basis * dir
		if absf(d.z) < 0.000001:
			continue
		var k := -o.z / d.z
		if k <= 0.0:
			continue
		var p := o + d * k
		var qs: Vector2 = (quad.mesh as QuadMesh).size
		if absf(p.x) > qs.x / 2.0 or absf(p.y) > qs.y / 2.0:
			continue
		var mat := quad.material_override as ShaderMaterial
		var off: Vector2 = mat.get_shader_parameter("uv_offset")
		var sc: Vector2 = mat.get_shader_parameter("uv_scale")
		var uv := Vector2(p.x / qs.x + 0.5, 0.5 - p.y / qs.y) * sc + off
		return uv * full
	return Vector2(-1, -1)
