class_name HeldPaper
extends Node3D
## Your hands on a paper you've picked up to read, in first person. Movement moves
## the paper itself (player.pick_up / put_down, which carry it from the desk or wall
## up to read_pose and back); these hands follow it: the right one reaches out and
## takes it, the left comes up to hold the other corner once it's close, and both
## go back down when it's put back. hold() also lays the document's real page over
## a prop that only shows grey lines from a distance, so what comes up to your eyes
## is the same paper as the close-up. Visual only.
##
##   var held := HeldPaper.attach(player.camera, CharacterLooks.crew(0))
##   held.follow(player)                       # hands track player.held_prop
##   player.pick_up(doc, size, face)
##   held.hold(doc, size, face, doc)           # the readable rect; with a Document, its page too

const REACH := 0.55  # metres: the arm stretches no further; the paper comes the rest of the way
const TWO_HANDS := 0.7  # the left hand takes the other corner once the paper is this close
const FOLLOW := 14.0  # how quickly the hands catch up with where they're going

var right_hand: Node3D
var left_hand: Node3D
var page: MeshInstance3D  # the document's page over the held prop's face, while it's held
var prop: Node3D  # what's in your hands

var _camera: Camera3D
var _player: Node
var _size := Vector2(0.21, 0.28)
var _face := Vector3.BACK
var _sized := false  # hold() said how big it is; otherwise guessed from the prop


static func attach(camera: Camera3D, look: Dictionary = {}) -> HeldPaper:
	var h := HeldPaper.new()
	h.name = "HeldPaper"
	h._camera = camera
	h._make(look)
	camera.add_child(h)
	return h


## Follow `player.held_prop`: hands out when something is picked up, back down when
## it's put away (prop_lowered).
func follow(player: Node) -> void:
	_player = player
	if player.has_signal("prop_lowered"):
		player.prop_lowered.connect(func(_p): release())


## The paper in your hands is `size` metres, its readable side along its local
## `face` (as given to player.pick_up). With `document` (anything with
## paper_kind(), title and lines()), its page is drawn over the prop's face.
func hold(held: Node3D, size: Vector2, face := Vector3.BACK, document: Node = null) -> void:
	prop = held
	_size = size
	_face = face.normalized()
	_sized = true
	_clear_page()
	if document and document.has_method("lines"):
		var kind: String = document.call("paper_kind") if document.has_method("paper_kind") else "memo"
		var title := str(document.get("title")) if document.get("title") != null else ""
		var tex := DocumentView.paper_texture(self, document.call("lines"), kind, title)
		page = MeshInstance3D.new()
		page.name = "Page"
		var qm := QuadMesh.new()
		var px := Vector2(DocumentView.PAPERS[kind].size)
		# The page's own shape, as tall as the prop's face.
		qm.size = Vector2(size.y * px.x / px.y, size.y)
		page.mesh = qm
		page.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = _paper_shader()
		m.set_shader_parameter("page", tex)
		page.material_override = m
		page.transform = _face_transform().translated_local(Vector3(0, 0, 0.006))
		held.add_child(page)


## Hands back down and the page off the prop.
func release() -> void:
	prop = null
	_sized = false
	_clear_page()


func _clear_page() -> void:
	if page and is_instance_valid(page):
		page.queue_free()
	page = null
	for vp in get_children():
		if vp is SubViewport:
			vp.queue_free()


func _make(look: Dictionary) -> void:
	for side in [1.0, -1.0]:
		var hand := HeldNotebook.make_hand(self, side, look)
		hand.name = "RightHand" if side > 0 else "LeftHand"
		hand.top_level = true
		hand.visible = false
		if side > 0:
			right_hand = hand
		else:
			left_hand = hand


## Where the readable face sits on the prop, in its own space: x across it, y up
## the page as you read it, z out of it.
func _face_transform() -> Transform3D:
	var turn := Basis.IDENTITY
	if _face.is_equal_approx(Vector3.UP):
		turn = Basis(Vector3.RIGHT, -PI / 2)
	elif not _face.is_equal_approx(Vector3.BACK):
		turn = Basis(Quaternion(Vector3.BACK, _face))
	return Transform3D(turn, Vector3.ZERO)


func _process(delta: float) -> void:
	if _camera == null:
		return
	if _player and prop == null:
		var p = _player.get("held_prop")
		if p is Node3D and is_instance_valid(p):
			prop = p
			if not _sized:
				_guess_size(p)
	if prop and not is_instance_valid(prop):
		release()
	var cam := _camera.global_transform
	var rest_r := cam * Transform3D(Basis.IDENTITY, Vector3(0.24, -0.5, -0.3))
	var rest_l := cam * Transform3D(Basis.IDENTITY, Vector3(-0.24, -0.5, -0.3))
	var target_r := rest_r
	var target_l := rest_l
	if prop:
		var face := prop.global_transform * _face_transform()
		var grip_r := face * Transform3D(Basis.IDENTITY, Vector3(_size.x / 2.0 - 0.02, -_size.y / 2.0 + 0.03, 0.0))
		var grip_l := face * Transform3D(Basis.IDENTITY, Vector3(-_size.x / 2.0 + 0.02, -_size.y / 2.0 + 0.03, 0.0))
		target_r = grip_r
		var to := grip_r.origin - cam.origin
		if to.length() > REACH:
			target_r = Transform3D(grip_r.basis, cam.origin + to.normalized() * REACH)
		if (grip_l.origin - cam.origin).length() < TWO_HANDS:
			target_l = grip_l
	var k := 1.0 - exp(-FOLLOW * delta)
	_move(right_hand, target_r, rest_r, k)
	_move(left_hand, target_l, rest_l, k)


func _move(hand: Node3D, target: Transform3D, rest: Transform3D, k: float) -> void:
	if not hand.visible:
		if target.origin.is_equal_approx(rest.origin):
			return
		hand.global_transform = rest
		hand.visible = true
	var now := hand.global_transform.interpolate_with(target, k)
	hand.global_transform = now
	# Back at rest below the screen: put it away.
	if target.origin.is_equal_approx(rest.origin) and now.origin.distance_to(rest.origin) < 0.01:
		hand.visible = false


## Without hold(): the prop's longest two sides, readable side towards you.
func _guess_size(p: Node3D) -> void:
	var box := AABB()
	var first := true
	for n in p.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var b := mi.transform * mi.get_aabb() if mi.get_parent() == p else p.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	var s := box.size
	if s.y < minf(s.x, s.z):
		_face = Vector3.UP
		_size = Vector2(s.x, s.z)
	else:
		_face = Vector3.BACK
		_size = Vector2(s.x, s.y)


static var _shader: Shader


## Lit by the room like the paper it lies on (a little light of its own so it never
## goes black), with the same few-tap smoothing as the notebook's pages.
static func _paper_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
render_mode cull_back, shadows_disabled;
uniform sampler2D page : source_color, filter_linear;
void fragment() {
	vec2 f = fwidth(UV) * 0.4;
	vec4 c = (texture(page, UV) * 2.0 + texture(page, UV + f) + texture(page, UV - f)
		+ texture(page, UV + vec2(f.x, -f.y)) + texture(page, UV + vec2(-f.x, f.y))) / 6.0;
	ALBEDO = c.rgb;
	EMISSION = c.rgb * 0.18;
	ROUGHNESS = 0.9;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""
	return _shader
