class_name HeldPaper
extends Node3D
## Picking a paper up to read it, in first person: your hand reaches out, takes the
## memo, card or clipboard off the desk or wall and brings it up in front of you,
## the other hand coming up to hold the other corner. put_back() returns it to
## where it was. The paper in your hands is drawn by its own DocumentView, so it
## looks the same in flight as it does up close. Visual only: the reader opens the
## close-up DocumentView when lift() finishes and calls put_back() when it closes.
##
##   var held := HeldPaper.attach(player.camera, CharacterLooks.crew(0))
##   await held.lift(document).finished     # a Document: paper_kind(), title, lines()
##   reader.open(document, player)
##   ...
##   await held.put_back().finished

signal lifted
signal put_down

const READ_HEIGHT_FRACTION := 0.8  # of the screen's height, where the close-up takes over
const LIFT_TIME := 0.6
const PUT_TIME := 0.45
const REACH := 0.55  # metres: the arm stretches no further; the paper comes the rest of the way
const MARGIN := Vector2(80, 110)  # DocumentView's own border around its paper, at scale 1

var viewport: SubViewport
var view: DocumentView
var paper: Node3D  # the paper in flight: top level, between the world and your hands
var face: MeshInstance3D
var source: Node3D  # the document it came from
var right_hand: Node3D
var left_hand: Node3D

var _camera: Camera3D
var _from := Transform3D.IDENTITY  # where the paper lay
var _size := Vector2(0.21, 0.28)
var _t := 0.0
var _tween: Tween
var _hidden: Array[Node3D] = []


static func attach(camera: Camera3D, look: Dictionary = {}) -> HeldPaper:
	var h := HeldPaper.new()
	h.name = "HeldPaper"
	h._camera = camera
	h._make(look)
	camera.add_child(h)
	return h


func is_held() -> bool:
	return source != null


## Reaches for `doc` and brings it up to read. Takes its look from the Document
## (paper_kind(), title, lines()) and hides the one in the world while it's held.
func lift(doc: Node3D, time := LIFT_TIME) -> Tween:
	source = doc
	_fill(doc)
	_from = _rest_transform(doc)
	_hide_source(doc)
	visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return _animate(1.0, time, Tween.EASE_IN_OUT, lifted)


## Puts it back where it came from.
func put_back(time := PUT_TIME) -> Tween:
	return _animate(0.0, time, Tween.EASE_IN_OUT, put_down)


## Where the paper sits while you read it: centred, filling READ_HEIGHT_FRACTION
## of the screen's height, leaning back a little.
func reading_transform() -> Transform3D:
	var tan_v := tan(deg_to_rad((_camera.fov if _camera else 75.0) / 2.0))
	var d := (_size.y / 2.0) / (tan_v * READ_HEIGHT_FRACTION)
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(-6.0), 0, 0)), Vector3(0, -0.01, -d))


func _make(look: Dictionary) -> void:
	visible = false
	viewport = SubViewport.new()
	viewport.name = "Paper"
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	paper = Node3D.new()
	paper.name = "Sheet"
	paper.top_level = true
	add_child(paper)
	face = MeshInstance3D.new()
	face.name = "Face"
	face.mesh = QuadMesh.new()
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = _paper_shader()
	m.set_shader_parameter("page", viewport.get_texture())
	face.material_override = m
	paper.add_child(face)
	for side in [1.0, -1.0]:
		var hand := HeldNotebook.make_hand(self, side, look)
		hand.name = "RightHand" if side > 0 else "LeftHand"
		hand.top_level = true
		hand.visible = false
		if side > 0:
			right_hand = hand
		else:
			left_hand = hand


static var _shader: Shader


## Lit by the room like the paper it was on the desk (a little light of its own so
## it never goes black), with the same few-tap smoothing as the notebook's pages.
static func _paper_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform sampler2D page : source_color, filter_linear;
uniform vec2 uv_offset = vec2(0.0);
uniform vec2 uv_scale = vec2(1.0);
void fragment() {
	vec2 uv = UV * uv_scale + uv_offset;
	vec2 f = fwidth(uv) * 0.4;
	vec4 c = (texture(page, uv) * 2.0 + texture(page, uv + f) + texture(page, uv - f)
		+ texture(page, uv + vec2(f.x, -f.y)) + texture(page, uv + vec2(-f.x, f.y))) / 6.0;
	vec3 col = FRONT_FACING ? c.rgb : vec3(0.93, 0.92, 0.88);
	ALBEDO = col;
	EMISSION = col * 0.18;
	ROUGHNESS = 0.9;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""
	return _shader


## Draws the document onto the paper in your hands.
func _fill(doc: Node) -> void:
	if view:
		view.queue_free()
	view = DocumentView.new()
	viewport.add_child(view)
	view.get_node("Dim").visible = false
	view.get_node("Paper/Close").visible = false
	var kind: String = doc.call("paper_kind") if doc.has_method("paper_kind") else "memo"
	view.set_paper(kind)
	view.set_title(str(doc.get("title")) if doc.get("title") != null else "")
	if doc.has_method("lines"):
		view.add_lines(doc.call("lines"))
	var px: Vector2 = view.paper.size
	viewport.size = Vector2i(px + MARGIN)
	view.size = Vector2(viewport.size)
	view.call("_fit")
	# The quad shows just the paper: DocumentView centres it at scale 1 in this viewport.
	var at: Vector2 = view.paper.position
	var mat := face.material_override as ShaderMaterial
	mat.set_shader_parameter("uv_offset", at / Vector2(viewport.size))
	mat.set_shader_parameter("uv_scale", px / Vector2(viewport.size))
	# As tall as the prop it came from, in the paper's own shape.
	var h := clampf(_prop_height(doc), 0.12, 0.5)
	_size = Vector2(h * px.x / px.y, h)
	(face.mesh as QuadMesh).size = _size


## The paper where it lay in the world: on a wall, facing you; on a desk, face up
## with its top away from you.
func _rest_transform(doc: Node3D) -> Transform3D:
	var box := _visual_box(doc)
	var centre := box.get_center() if box.size != Vector3.ZERO else doc.global_position
	var to_you := _camera.global_position - centre if _camera else Vector3.BACK
	var flat := box.size.y < minf(box.size.x, box.size.z) * 0.5 if box.size != Vector3.ZERO else false
	var normal: Vector3
	var up: Vector3
	if flat:
		normal = Vector3.UP
		up = Vector3(-to_you.x, 0, -to_you.z).normalized()
		if up.length() < 0.5:
			up = Vector3.FORWARD
	else:
		normal = doc.global_basis.z.normalized()
		if normal.dot(to_you) < 0.0:
			normal = -normal
		up = Vector3.UP
	var x := up.cross(normal).normalized()
	return Transform3D(Basis(x, normal.cross(x), normal), centre + normal * 0.004)


func _hide_source(doc: Node3D) -> void:
	_hidden.clear()
	for n in doc.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if vi.visible:
			vi.visible = false
			_hidden.append(vi)


func _show_source() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()


func _prop_height(doc: Node3D) -> float:
	var box := _visual_box(doc)
	var dims := [box.size.x, box.size.y, box.size.z]
	dims.sort()
	return dims[2] if dims[2] > 0.0 else 0.28


## The world-space box around what the document draws.
func _visual_box(doc: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in doc.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _animate(to: float, time: float, easing: Tween.EaseType, done: Signal) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(easing)
	_tween.tween_method(_pose, _t, to, time * absf(to - _t) + 0.01)
	_tween.tween_callback(func():
		if to <= 0.0:
			_show_source()
			source = null
			visible = false
			right_hand.visible = false
			left_hand.visible = false
			paper.visible = false
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		done.emit())
	return _tween


## 0: the hand at rest below the screen, the paper where it lay; 0.35: the hand
## has it; 1: held up in both hands to read.
func _pose(t: float) -> void:
	_t = t
	if _camera == null:
		return
	var cam := _camera.global_transform
	var reach := clampf(t / 0.35, 0.0, 1.0)
	var bring := clampf((t - 0.35) / 0.65, 0.0, 1.0)
	var read := cam * reading_transform()
	var sheet := _from.interpolate_with(read, ease(bring, -1.8)) if bring > 0.0 else _from
	paper.visible = true
	paper.global_transform = sheet
	# Thumbs pinch the bottom corners, a little in from the edge.
	var grip_r := sheet * Transform3D(Basis.IDENTITY, Vector3(_size.x / 2.0 - 0.02, -_size.y / 2.0 + 0.03, 0.0))
	var grip_l := sheet * Transform3D(Basis.IDENTITY, Vector3(-_size.x / 2.0 + 0.02, -_size.y / 2.0 + 0.03, 0.0))
	var rest_r := cam * Transform3D(Basis.IDENTITY, Vector3(0.24, -0.45, -0.3))
	var rest_l := cam * Transform3D(Basis.IDENTITY, Vector3(-0.24, -0.45, -0.3))
	var reach_to := grip_r.origin
	if (reach_to - cam.origin).length() > REACH:
		reach_to = cam.origin + (reach_to - cam.origin).normalized() * REACH
	var out := Transform3D(sheet.basis, reach_to)
	right_hand.visible = t > 0.0
	if bring <= 0.0:
		right_hand.global_transform = rest_r.interpolate_with(out, ease(reach, -1.6))
	else:
		right_hand.global_transform = out.interpolate_with(grip_r, ease(bring, -1.6))
	left_hand.visible = bring > 0.4
	left_hand.global_transform = rest_l.interpolate_with(grip_l, ease(clampf((bring - 0.4) / 0.6, 0.0, 1.0), -1.6))


func _process(_delta: float) -> void:
	if source and (_tween == null or not _tween.is_running()) and _t >= 1.0:
		_pose(1.0)  # follow the camera while it's held
