class_name TerminalScreen
extends Node3D
## A terminal's CRT, with its text drawn on the glass: a beige 90s monitor and a
## keyboard, and a SubViewport shown on the screen through a phosphor shader
## (scanlines, a dark vignette, a soft glow). Teammates can walk up and read it.
##
## By itself the screen shows `display`, a big-type copy of the terminal's text
## for anyone standing nearby. While a player is using the terminal, put the
## interactive TerminalUI on it with host(); release() hands the glass back.
## Visual only: the Terminal keeps its collider, glow light and logic.
##
##   var screen := TerminalScreen.attach(terminal)
##   screen.set_title("SERVER ROOM A")
##   screen.add_line("[color=#8f8]3 rows[/color]")       # as the transcript grows
##   camera.global_transform = screen.focus_transform(camera.fov)  # where to look from
##   screen.host(terminal_ui)                              # while someone types at it

const SCREEN_PX := Vector2i(1280, 960)  # 4:3, like the tube
const SCREEN_SIZE := Vector2(0.36, 0.27)  # visible glass, metres
const DISPLAY_FONT := 40  # big enough to read over a teammate's shoulder
const MAX_LINES := 200
const PHOSPHOR := Color(0.45, 1.0, 0.55)

var viewport: SubViewport
var display: TerminalDisplay
var glass: MeshInstance3D
var keyboard: Node3D
var hosted: Node  # what's on the glass instead of `display`, while someone types

var _terminal: Node3D
var _followed: Node


## Dresses a Terminal (or any node with its front along +Z) as a CRT with a live screen.
## Hides the greybox monitor's meshes; keeps its collider and light.
static func attach(terminal: Node3D) -> TerminalScreen:
	var s := TerminalScreen.new()
	s.name = "Screen"
	s._terminal = terminal
	for mi in terminal.get_children():
		if mi is MeshInstance3D:
			mi.visible = false
	s._make()
	terminal.add_child(s)
	return s


## Replaces the screen's text: a whole transcript (bbcode lines).
func set_lines(lines: Array) -> void:
	display.set_lines(lines)
	_redraw()


func add_line(bbcode: String) -> void:
	display.add_line(bbcode)
	_redraw()


func set_title(text: String) -> void:
	display.title.text = text
	_redraw()


## What's being typed at the prompt right now (for teammates watching).
func set_typing(text: String) -> void:
	display.set_typing(text)
	_redraw()


## Keeps the glass in step with a Terminal on every machine: redraws on its
## `screen_changed` from its `transcript`, and shows each seated player's
## half-typed line from `typing` (peer id -> text) as "name> text_".
func follow(terminal: Node) -> void:
	_followed = terminal
	if terminal.has_signal("screen_changed") and not terminal.is_connected("screen_changed", _sync_from_terminal):
		terminal.connect("screen_changed", _sync_from_terminal)
	_sync_from_terminal()


func _sync_from_terminal() -> void:
	var t := _followed
	if t == null or not is_instance_valid(t):
		return
	var lines = t.get("transcript")
	if lines is Array:
		display.set_lines(lines)
	var typing = t.get("typing")
	var seated = t.get("seated")
	var prompts: Array[String] = []
	if typing is Dictionary:
		var order: Array = seated if seated is Array else typing.keys()
		var net := get_node_or_null("/root/Net")
		for peer in order:
			if not typing.has(peer):
				continue
			var who: String = str(net.call("display_name", peer)) if net and net.has_method("display_name") else ""
			prompts.append(("%s> " % who if who != "" else "> ") + str(typing[peer]) + "_")
	display.set_prompts(prompts)
	_redraw()


func clear() -> void:
	display.set_lines([])
	_redraw()


## Tints the phosphor (a locked terminal goes red, a dead one dark).
func set_tint(c: Color) -> void:
	(glass.material_override as ShaderMaterial).set_shader_parameter("tint", c)


## Where a camera should be to read the screen: straight in front of the glass,
## close enough that it fills `fill` of the view's height.
func focus_transform(fov: float = 75.0, fill: float = 0.85) -> Transform3D:
	var d := (SCREEN_SIZE.y / 2.0) / (tan(deg_to_rad(fov / 2.0)) * fill)
	var at := glass.global_transform
	var eye := at.origin + at.basis.z.normalized() * d
	return Transform3D(Basis.looking_at(at.origin - eye, at.basis.y.normalized()), eye)


## Puts `node` (the TerminalUI, or any Control or CanvasLayer) on the glass in
## place of the big-type display. Keys and mouse clicks on the glass reach it.
func host(node: Node) -> void:
	if hosted == node:
		return
	release()
	hosted = node
	if node.get_parent():
		node.get_parent().remove_child(node)
	viewport.add_child(node)
	display.visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Takes the hosted node off the glass (it's returned, unparented) and shows the display again.
func release() -> Node:
	var n := hosted
	if n:
		viewport.remove_child(n)
	hosted = null
	display.visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return n


func _redraw() -> void:
	if hosted == null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _make() -> void:
	viewport = SubViewport.new()
	viewport.name = "Glass"
	viewport.size = SCREEN_PX
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.gui_embed_subwindows = true
	add_child(viewport)
	display = TerminalDisplay.new()
	viewport.add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The monitor, set back a little so the keyboard fits on the desk in front.
	var shell := ArtPalette.surface("plastic", Color(0.98, 0.95, 0.85))
	var dark := ArtPalette.flat(Color(0.12, 0.12, 0.12), 0.6)
	var body := Node3D.new()
	body.name = "CRT"
	body.position = Vector3(0, 0, -0.06)
	add_child(body)
	_box(body, Vector3(0.5, 0.4, 0.3), Vector3(0, 0.25, 0.08), shell, true)  # the case around the tube
	_box(body, Vector3(0.36, 0.3, 0.22), Vector3(0, 0.24, -0.16), shell, true)  # the tube's back
	_box(body, Vector3(0.26, 0.05, 0.24), Vector3(0, 0.025, 0.05), shell)  # swivel stand
	_box(body, Vector3(0.42, 0.33, 0.02), Vector3(0, 0.255, 0.235), dark)  # bezel shadow round the glass
	_box(body, Vector3(0.05, 0.012, 0.01), Vector3(0.17, 0.065, 0.236), dark)  # power switch
	_box(body, Vector3(0.008, 0.008, 0.004), Vector3(0.12, 0.066, 0.24), ArtPalette.glow(Color(0.3, 1.0, 0.4), 2.0))  # power LED
	_box(body, Vector3(0.1, 0.016, 0.004), Vector3(-0.13, 0.066, 0.24), ArtPalette.flat(ArtPalette.HALCYON_GOLD, 0.4))  # badge
	glass = MeshInstance3D.new()
	glass.name = "GlassFace"
	var qm := QuadMesh.new()
	qm.size = SCREEN_SIZE
	glass.mesh = qm
	glass.position = Vector3(0, 0.255, 0.247)
	glass.material_override = _glass_material()
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(glass)
	keyboard = ArtProps.keyboard(self, Vector3(0, 0, 0.3), 0)


func _glass_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader()
	m.set_shader_parameter("screen", viewport.get_texture())
	m.set_shader_parameter("tint", Color.WHITE)
	return m


static var _crt_shader: Shader


static func _shader() -> Shader:
	if _crt_shader == null:
		_crt_shader = Shader.new()
		_crt_shader.code = """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform sampler2D screen : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	// Several taps across the pixel's footprint: the glass is often seen from a few
	// steps away, and a viewport texture has no mipmaps to smooth the small text.
	vec2 f = fwidth(UV) * 0.4;
	vec3 c = (texture(screen, UV).rgb * 2.0 + texture(screen, UV + vec2(f.x, f.y)).rgb
		+ texture(screen, UV + vec2(-f.x, f.y)).rgb + texture(screen, UV + vec2(f.x, -f.y)).rgb
		+ texture(screen, UV - f).rgb) / 6.0;
	// scanlines, a darker edge, and a little bloom-ish lift on the phosphor
	float scan = 0.9 + 0.1 * sin(UV.y * 960.0 * 3.14159);
	vec2 e = UV * (1.0 - UV.yx);
	float vig = clamp(pow(e.x * e.y * 18.0, 0.22), 0.0, 1.0);
	c = c * scan * vig * tint.rgb;
	ALBEDO = c * 1.15 + vec3(0.01, 0.025, 0.015) * vig;
}
"""
	return _crt_shader


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, shadow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## While someone is typing at it, keys and clicks on the glass go to the hosted UI.
func _input(event: InputEvent) -> void:
	if hosted == null:
		return
	if event is InputEventMouse:
		var cam := get_viewport().get_camera_3d()
		var at := screen_point(cam, event.position) if cam else Vector2(-1, -1)
		if at.x < 0.0:
			return
		var ev: InputEventMouse = event.duplicate()
		ev.position = at
		ev.global_position = at
		viewport.push_input(ev)
	elif event is InputEventKey:
		viewport.push_input(event)
	else:
		return
	get_viewport().set_input_as_handled()


## The pixel on the screen image under a point on the player's screen, or (-1, -1).
func screen_point(cam: Camera3D, screen_pos: Vector2) -> Vector2:
	var inv := glass.global_transform.affine_inverse()
	var o := inv * cam.project_ray_origin(screen_pos)
	var d := inv.basis * cam.project_ray_normal(screen_pos)
	if absf(d.z) < 0.000001:
		return Vector2(-1, -1)
	var k := -o.z / d.z
	var p := o + d * k
	if k <= 0.0 or absf(p.x) > SCREEN_SIZE.x / 2.0 or absf(p.y) > SCREEN_SIZE.y / 2.0:
		return Vector2(-1, -1)
	return Vector2(p.x / SCREEN_SIZE.x + 0.5, 0.5 - p.y / SCREEN_SIZE.y) * Vector2(SCREEN_PX)


## The terminal's text in big phosphor type, for everyone in the room.
class TerminalDisplay extends Control:
	var title: Label
	var text: RichTextLabel
	var prompt: Label
	var _lines: Array = []
	var _typing := ""

	func _init() -> void:
		var bg := ColorRect.new()
		bg.color = Color(0.015, 0.04, 0.02)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 56
		box.offset_right = -56
		box.offset_top = 44
		box.offset_bottom = -44
		box.add_theme_constant_override("separation", 6)
		add_child(box)
		var mono := NotebookArt.type_font()
		title = Label.new()
		title.add_theme_font_override("font", mono)
		title.add_theme_font_size_override("font_size", 30)
		title.add_theme_color_override("font_color", Color(TerminalScreen.PHOSPHOR, 0.55))
		box.add_child(title)
		text = RichTextLabel.new()
		text.bbcode_enabled = true
		text.scroll_following = true
		text.scroll_active = false
		text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for f in ["normal_font", "bold_font", "italics_font", "mono_font"]:
			text.add_theme_font_override(f, mono)
		for f in ["normal_font_size", "bold_font_size", "italics_font_size", "mono_font_size"]:
			text.add_theme_font_size_override(f, TerminalScreen.DISPLAY_FONT)
		text.add_theme_color_override("default_color", TerminalScreen.PHOSPHOR)
		box.add_child(text)
		prompt = Label.new()
		prompt.add_theme_font_override("font", mono)
		prompt.add_theme_font_size_override("font_size", TerminalScreen.DISPLAY_FONT)
		prompt.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
		prompt.clip_text = true
		box.add_child(prompt)
		set_typing("")

	func set_lines(lines: Array) -> void:
		_lines = lines.slice(maxi(0, lines.size() - TerminalScreen.MAX_LINES))
		text.text = "\n".join(_lines)

	func add_line(bbcode: String) -> void:
		_lines.append(bbcode)
		if _lines.size() > TerminalScreen.MAX_LINES:
			_lines.pop_front()
		text.text = "\n".join(_lines)

	func set_typing(t: String) -> void:
		_typing = t
		prompt.text = "> " + t + "_"

	## One prompt line per player typing at this terminal; none shows a bare cursor.
	func set_prompts(lines: Array[String]) -> void:
		prompt.text = "\n".join(lines) if not lines.is_empty() else "> _"
