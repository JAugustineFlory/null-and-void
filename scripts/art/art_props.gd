class_name ArtProps
extends RefCounted
## Furniture and fittings for dressing a wing: desks, chairs, CRTs, racks,
## cabinets, plants, signs and light fittings, built from boxes like Greybox.
## Pieces you can bump into are StaticBody3D with one simple box collider, so put
## them under LevelBase.geo and navigation bakes around them. Everything faces
## -Z at rotation 0; pass `facing_deg` to turn it.
##
## Budgets (see docs/art/style-guide.md): a prop is at most ~10 mesh pieces, and
## only big pieces cast shadows.


## Office desk with a modesty panel. Top at 0.74 m.
static func desk(parent: Node, pos: Vector3, facing_deg: float = 0.0, width: float = 1.5) -> StaticBody3D:
	var body := _body(parent, pos, facing_deg, "Desk", Vector3(width, 0.76, 0.75), Vector3(0, 0.38, 0))
	var top := ArtPalette.surface("laminate")
	var frame := ArtPalette.flat(Color(0.25, 0.25, 0.26), 0.5, 0.6)
	_piece(body, Vector3(width, 0.04, 0.75), Vector3(0, 0.74, 0), top, true)
	for sx in [-1.0, 1.0]:
		_piece(body, Vector3(0.04, 0.72, 0.7), Vector3(sx * (width / 2 - 0.03), 0.36, 0), frame)
	_piece(body, Vector3(width - 0.08, 0.4, 0.02), Vector3(0, 0.45, 0.3), frame)
	return body


## Swivel office chair.
static func office_chair(parent: Node, pos: Vector3, facing_deg: float = 0.0) -> StaticBody3D:
	var body := _body(parent, pos, facing_deg, "Chair", Vector3(0.5, 1.0, 0.5), Vector3(0, 0.5, 0))
	var fabric := ArtPalette.flat(Color(0.16, 0.17, 0.2), 0.95)
	var black := ArtPalette.flat(ArtPalette.DARK_PLASTIC, 0.5)
	_piece(body, Vector3(0.48, 0.08, 0.46), Vector3(0, 0.48, 0), fabric, true)
	_piece(body, Vector3(0.44, 0.5, 0.07), Vector3(0, 0.82, 0.22), fabric, true)
	_piece(body, Vector3(0.05, 0.38, 0.05), Vector3(0, 0.25, 0), black)
	_piece(body, Vector3(0.6, 0.04, 0.06), Vector3(0, 0.05, 0), black)
	_piece(body, Vector3(0.06, 0.04, 0.6), Vector3(0, 0.05, 0), black)
	return body


## A beige 90s CRT monitor and keyboard. Sits on a desk top: pass the desk-top
## height in pos.y. `screen` is "off", "green" (terminal) or "blue" (desktop).
static func crt_monitor(parent: Node, pos: Vector3, facing_deg: float = 0.0, screen: String = "green") -> Node3D:
	var root := _node(parent, pos, facing_deg, "CRT")
	var shell := ArtPalette.surface("plastic")
	_piece(root, Vector3(0.4, 0.36, 0.38), Vector3(0, 0.22, 0.04), shell, true)
	_piece(root, Vector3(0.28, 0.24, 0.2), Vector3(0, 0.2, 0.28), shell)  # the tube's back
	_piece(root, Vector3(0.2, 0.04, 0.2), Vector3(0, 0.02, 0.05), shell)  # stand
	var glass_mat: Material
	match screen:
		"green": glass_mat = ArtPalette.glow(ArtPalette.LIGHT_SCREEN * 0.5, 1.2)
		"blue": glass_mat = ArtPalette.glow(Color(0.15, 0.3, 0.6), 1.0)
		_: glass_mat = ArtPalette.flat(Color(0.08, 0.1, 0.09), 0.15)
	_piece(root, Vector3(0.32, 0.26, 0.01), Vector3(0, 0.23, -0.151), glass_mat)
	_piece(root, Vector3(0.44, 0.03, 0.15), Vector3(0, 0.015, -0.3), shell)  # keyboard
	return root


## A 42U server rack with rows of status LEDs on the front. `lit` false = dead rack.
static func server_rack(parent: Node, pos: Vector3, facing_deg: float = 0.0, lit: bool = true) -> StaticBody3D:
	var body := _body(parent, pos, facing_deg, "Rack", Vector3(0.6, 2.0, 1.0), Vector3(0, 1.0, 0))
	_piece(body, Vector3(0.6, 2.0, 1.0), Vector3(0, 1.0, 0), ArtPalette.surface("rack"), true)
	_piece(body, Vector3(0.5, 1.8, 0.01), Vector3(0, 1.0, -0.501), ArtPalette.flat(Color(0.14, 0.15, 0.16), 0.6, 0.5))
	if lit:
		# Two LED strips per rack, as single glowing strips: cheap and readable.
		_piece(body, Vector3(0.03, 1.6, 0.01), Vector3(-0.18, 1.0, -0.507), ArtPalette.glow(Color(0.2, 1.0, 0.35), 1.5))
		_piece(body, Vector3(0.03, 1.2, 0.01), Vector3(0.18, 1.1, -0.507), ArtPalette.glow(Color(1.0, 0.6, 0.1), 1.2))
	return body


## Four-drawer metal filing cabinet.
static func filing_cabinet(parent: Node, pos: Vector3, facing_deg: float = 0.0) -> StaticBody3D:
	var body := _body(parent, pos, facing_deg, "Cabinet", Vector3(0.47, 1.32, 0.62), Vector3(0, 0.66, 0))
	var metal := ArtPalette.flat(Color(0.55, 0.56, 0.52), 0.55, 0.5)
	_piece(body, Vector3(0.47, 1.32, 0.62), Vector3(0, 0.66, 0), metal, true)
	var handle := ArtPalette.flat(Color(0.2, 0.2, 0.2), 0.4, 0.8)
	for i in 4:
		_piece(body, Vector3(0.43, 0.005, 0.01), Vector3(0, 0.33 * i + 0.33, -0.311), handle)
		_piece(body, Vector3(0.12, 0.025, 0.02), Vector3(0, 0.33 * i + 0.24, -0.32), handle)
	return body


## Potted office plant: a pot and a few leafy blobs.
static func potted_plant(parent: Node, pos: Vector3) -> StaticBody3D:
	var body := _body(parent, pos, 0.0, "Plant", Vector3(0.4, 0.45, 0.4), Vector3(0, 0.22, 0))
	_piece(body, Vector3(0.36, 0.42, 0.36), Vector3(0, 0.21, 0), ArtPalette.flat(Color(0.82, 0.8, 0.74), 0.6), true)
	var leaf := ArtPalette.flat(Color(0.16, 0.36, 0.17), 0.8)
	for i in 5:
		var a := TAU * i / 5.0
		var mi := _piece(body, Vector3(0.12, 0.5, 0.05), Vector3(cos(a) * 0.1, 0.7, sin(a) * 0.1), leaf)
		mi.rotation = Vector3(sin(a) * 0.5, -a, cos(a) * 0.5)
	return body


## Office water cooler with a blue bottle.
static func water_cooler(parent: Node, pos: Vector3, facing_deg: float = 0.0) -> StaticBody3D:
	var body := _body(parent, pos, facing_deg, "WaterCooler", Vector3(0.32, 1.35, 0.32), Vector3(0, 0.67, 0))
	_piece(body, Vector3(0.32, 0.95, 0.32), Vector3(0, 0.475, 0), ArtPalette.flat(Color(0.88, 0.88, 0.86), 0.5), true)
	var bottle := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.1
	cy.bottom_radius = 0.13
	cy.height = 0.42
	cy.radial_segments = 12
	bottle.mesh = cy
	bottle.position = Vector3(0, 1.16, 0)
	bottle.material_override = ArtPalette.glass(Color(0.3, 0.55, 0.85))
	bottle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(bottle)
	return body


## Green running-man EXIT sign over a door; it glows on its own (no light).
static func exit_sign(parent: Node, pos: Vector3, facing_deg: float = 0.0) -> Node3D:
	var root := _node(parent, pos, facing_deg, "ExitSign")
	_piece(root, Vector3(0.4, 0.18, 0.06), Vector3.ZERO, ArtPalette.flat(Color(0.9, 0.9, 0.88), 0.5))
	_piece(root, Vector3(0.36, 0.14, 0.01), Vector3(0, 0, -0.031), ArtPalette.glow(Color(0.15, 0.85, 0.3), 2.5))
	var l := Label3D.new()
	l.text = "EXIT"
	l.font_size = 64
	l.pixel_size = 0.0018
	l.modulate = Color(0.95, 1.0, 0.95)
	l.outline_size = 0
	l.position = Vector3(0, 0, -0.037)
	l.rotation_degrees.y = 180
	l.double_sided = false
	root.add_child(l)
	return root


## A recessed 2x4 fluorescent troffer with a real light. Its tube glow follows
## the light: hide the light (as LevelBase does for the `lights` table) and the
## panel goes dark too. Returns the light so levels can register it.
static func troffer(parent: Node, ceiling_pos: Vector3, light_range: float = 8.0, energy: float = 1.3) -> OmniLight3D:
	var root := _node(parent, ceiling_pos, 0.0, "Troffer")
	_piece(root, Vector3(1.24, 0.03, 0.64), Vector3(0, -0.005, 0), ArtPalette.flat(Color(0.8, 0.8, 0.78), 0.4, 0.3))
	var light := OmniLight3D.new()
	light.position = Vector3(0, -0.4, 0)
	light.omni_range = light_range
	light.light_energy = energy
	light.light_color = ArtPalette.LIGHT_FLUORESCENT
	root.add_child(light)
	var diffuser := _piece(light, Vector3(1.16, 0.01, 0.56), Vector3(0, 0.38, 0), ArtPalette.glow(ArtPalette.LIGHT_FLUORESCENT, 2.2))
	diffuser.name = "Diffuser"
	return light


## A sticky note: 7.6 cm square of paper with a strip of tape, one SQL keyword
## handwritten on it. Faces -Z like a poster, so stick it to a wall or a monitor
## bezel; pass `flat` to lay it on a desk instead. The paper glows very faintly
## so it can be spotted on a dark desk (found in the world). Visual only: the
## mechanics that pick it up or copy it parent this under their Interactable.
static func sticky_note(parent: Node, pos: Vector3, facing_deg: float, text: String, paper := STICKY_YELLOW, flat_on_desk := false) -> Node3D:
	var root := _node(parent, pos, facing_deg, "StickyNote")
	var face := Node3D.new()
	if flat_on_desk:
		face.rotation_degrees.x = 90
	face.rotation_degrees.z = float(abs(text.hash()) % 13 - 6)  # never stuck on quite straight
	root.add_child(face)
	var sheet := _piece(face, Vector3(0.076, 0.076, 0.002), Vector3.ZERO, sticky_paper(paper))
	sheet.name = "Paper"
	_piece(face, Vector3(0.05, 0.016, 0.001), Vector3(0, 0.036, -0.0015), ArtPalette.flat(Color(0.9, 0.9, 0.85, 1.0), 0.3))  # tape
	var l := Label3D.new()
	l.name = "Text"
	l.text = text
	l.font = NotebookArt.hand_font()
	l.font_size = clampi(int(48.0 * 7.0 / maxf(7.0, text.length())), 22, 48)  # long keywords write smaller
	l.pixel_size = 0.0005
	l.width = 0.068 / l.pixel_size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = NotebookArt.INK
	l.outline_size = 0
	l.position = Vector3(0, -0.004, -0.0016)
	l.rotation_degrees.y = 180
	l.double_sided = false
	face.add_child(l)
	return root


## The sticky-note colors (canary, pink, blue, green), as in any 90s office.
const STICKY_YELLOW := Color(0.98, 0.9, 0.42)
const STICKY_COLORS: Array[Color] = [STICKY_YELLOW, Color(0.98, 0.66, 0.74), Color(0.6, 0.82, 0.96), Color(0.7, 0.92, 0.6)]


## Paper with a faint glow so a note reads in the dark without a flashlight.
static var _sticky_mats := {}


static func sticky_paper(paper: Color) -> StandardMaterial3D:
	if _sticky_mats.has(paper):
		return _sticky_mats[paper]
	var m: StandardMaterial3D = ArtPalette.flat(paper, 0.9).duplicate()
	m.emission_enabled = true
	m.emission = paper
	m.emission_energy_multiplier = 0.2
	_sticky_mats[paper] = m
	return m


# --- Helpers -------------------------------------------------------------------

static func _node(parent: Node, pos: Vector3, facing_deg: float, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	n.rotation_degrees.y = facing_deg
	parent.add_child(n)
	return n


## A static body with one box collider (size, centered at offset).
static func _body(parent: Node, pos: Vector3, facing_deg: float, node_name: String, size: Vector3, offset: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees.y = facing_deg
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.position = offset
	body.add_child(shape)
	parent.add_child(body)
	return body


static func _piece(parent: Node, size: Vector3, pos: Vector3, mat: Material, shadow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
