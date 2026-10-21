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


## Where a sitter's seat is on each chair, above its feet.
const OFFICE_SEAT := 0.52
const CAFE_SEAT := 0.465


## Makes `chair` sittable (a Seat on its seat at height `top`, facing the way
## the chair faces) and returns the chair.
static func sittable(chair: Node3D, top: float, size := Vector2(0.42, 0.4)) -> Node3D:
	Seat.create_at(chair, Vector3(0, top, 0), 0.0, size)
	return chair


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


## A beige 90s keyboard (main block, arrows, number pad), its typing side toward
## +Z, so it sits in front of a monitor facing +Z. `pos` is on the desk top.
static func keyboard(parent: Node, pos: Vector3, facing_deg: float = 0.0) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Keyboard")
	var shell := ArtPalette.surface("plastic", Color(0.98, 0.95, 0.85))
	var keys := ArtPalette.flat(Color(0.86, 0.83, 0.74), 0.7)
	var dark_keys := ArtPalette.flat(Color(0.62, 0.6, 0.55), 0.7)
	var deck := Node3D.new()
	deck.name = "Deck"
	deck.rotation_degrees.x = 4.0  # feet up at the back
	root.add_child(deck)
	_piece(deck, Vector3(0.46, 0.028, 0.17), Vector3(0, 0.016, 0), shell, true)
	# Key rows as strips with gaps (cheap: a few pieces per row, not 101 keys).
	for r in 5:
		var z := -0.06 + r * 0.026
		_piece(deck, Vector3(0.28, 0.012, 0.021), Vector3(-0.075, 0.035, z), keys)
		_piece(deck, Vector3(0.075, 0.012, 0.021), Vector3(0.17, 0.035, z), dark_keys if r == 0 else keys)  # number pad
	_piece(deck, Vector3(0.13, 0.012, 0.021), Vector3(-0.07, 0.036, 0.07), keys)  # space bar
	_piece(deck, Vector3(0.06, 0.012, 0.045), Vector3(0.085, 0.035, 0.057), dark_keys)  # arrows
	_piece(deck, Vector3(0.006, 0.004, 0.003), Vector3(0.19, 0.03, -0.083), ArtPalette.glow(Color(0.3, 1.0, 0.4), 1.5))  # num lock
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
	var diffuser := _piece(light, Vector3(1.16, 0.01, 0.56), Vector3(0, 0.38, 0), ArtPalette.troffer_glow(ArtPalette.LIGHT_FLUORESCENT, 2.2))
	diffuser.name = "Diffuser"
	return light


## A troffer whose tubes have died: the housing, two grey tubes burnt black at
## the ends, no light. `hanging` drops one edge of its diffuser, the way a
## fitting looks after someone gave up changing it. Visual only. The reason a
## patch of ceiling is dark (see ArtDress.explain_dark).
static func dead_troffer(parent: Node, ceiling_pos: Vector3, facing_deg := 0.0, hanging := false) -> Node3D:
	var root := _node(parent, ceiling_pos, facing_deg, "DeadTroffer")
	root.add_to_group("dark_cause")
	_piece(root, Vector3(1.24, 0.03, 0.64), Vector3(0, -0.005, 0), ArtPalette.flat(Color(0.8, 0.8, 0.78), 0.4, 0.3))
	_piece(root, Vector3(1.16, 0.005, 0.56), Vector3(0, -0.022, 0), ArtPalette.flat(Color(0.18, 0.18, 0.19), 0.8))  # the empty reflector
	var tube_mat := ArtPalette.flat(Color(0.62, 0.63, 0.64), 0.3)
	var burnt := ArtPalette.flat(Color(0.08, 0.07, 0.07), 0.8)
	for tz in [-0.14, 0.14]:
		var tube := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.016
		cm.bottom_radius = 0.016
		cm.height = 1.1
		tube.mesh = cm
		tube.material_override = tube_mat
		tube.rotation_degrees.z = 90
		tube.position = Vector3(0, -0.045, tz)
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(tube)
		for tx in [-0.5, 0.5]:
			_piece(root, Vector3(0.1, 0.034, 0.034), Vector3(tx, -0.045, tz), burnt)
	if hanging:
		var hinge := Node3D.new()
		hinge.position = Vector3(0, -0.03, 0.29)
		hinge.rotation_degrees.x = -38
		root.add_child(hinge)
		_piece(hinge, Vector3(1.16, 0.008, 0.56), Vector3(0, 0, -0.28), ArtPalette.flat(Color(0.78, 0.78, 0.76), 0.5))
	return root


## A parked 90s sedan, about 4.5 m long, nose toward -Z. One box collider.
static func car(parent: Node, pos: Vector3, facing_deg: float = 0.0, paint: Color = Color(0.45, 0.12, 0.1)) -> StaticBody3D:
	var body := _body(parent, pos, facing_deg, "Car", Vector3(1.8, 1.4, 4.5), Vector3(0, 0.7, 0))
	var shell := ArtPalette.flat(paint, 0.35, 0.4)
	_piece(body, Vector3(1.8, 0.65, 4.5), Vector3(0, 0.62, 0), shell, true)  # body
	_piece(body, Vector3(1.6, 0.55, 2.3), Vector3(0, 1.2, 0.2), shell, true)  # cabin
	_piece(body, Vector3(1.5, 0.45, 0.02), Vector3(0, 1.2, -0.96), ArtPalette.glass(), false)  # windscreen
	_piece(body, Vector3(1.5, 0.42, 0.02), Vector3(0, 1.2, 1.36), ArtPalette.glass(), false)  # rear window
	for sx in [-1.0, 1.0]:
		_piece(body, Vector3(0.02, 0.4, 2.0), Vector3(sx * 0.81, 1.2, 0.2), ArtPalette.glass(), false)
	var tyre := ArtPalette.flat(Color(0.05, 0.05, 0.05), 0.9)
	for sx in [-0.82, 0.82]:
		for sz in [-1.4, 1.4]:
			_piece(body, Vector3(0.22, 0.6, 0.6), Vector3(sx, 0.3, sz), tyre)
	var lamp := ArtPalette.flat(Color(0.85, 0.85, 0.8), 0.2)
	var tail := ArtPalette.flat(Color(0.5, 0.05, 0.05), 0.3)
	for sx in [-0.65, 0.65]:
		_piece(body, Vector3(0.3, 0.12, 0.02), Vector3(sx, 0.75, -2.26), lamp)
		_piece(body, Vector3(0.3, 0.12, 0.02), Vector3(sx, 0.75, 2.26), tail)
	return body


## A stack of cardboard archive boxes, `count` high (1 to 4).
static func boxes(parent: Node, pos: Vector3, facing_deg: float = 0.0, count: int = 3) -> StaticBody3D:
	var h := 0.3
	count = clampi(count, 1, 4)
	var body := _body(parent, pos, facing_deg, "Boxes", Vector3(0.5, h * count, 0.4), Vector3(0, h * count / 2.0, 0))
	var card := ArtPalette.flat(Color(0.62, 0.48, 0.3), 0.9)
	var label := ArtPalette.flat(Color(0.9, 0.88, 0.8), 0.8)
	for i in count:
		var mi := _piece(body, Vector3(0.48, h - 0.01, 0.38), Vector3(0, h * i + h / 2.0, 0), card, i == 0)
		mi.rotation.y = [0.0, 0.08, -0.05, 0.1][i]
		_piece(body, Vector3(0.14, 0.08, 0.005), Vector3(0, h * i + h / 2.0, -0.193), label)
	return body


## A framed poster or notice on a wall, facing -Z. Visual only. The text shrinks
## from `font_size` until it fits on the paper, wrapped, with a small margin.
static func poster(parent: Node, pos: Vector3, facing_deg: float, text: String, size := Vector2(0.6, 0.8), paper := Color(0.93, 0.92, 0.86), font_size := 40) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Poster")
	_piece(root, Vector3(size.x + 0.04, size.y + 0.04, 0.02), Vector3.ZERO, ArtPalette.flat(Color(0.15, 0.14, 0.13), 0.5))
	_piece(root, Vector3(size.x, size.y, 0.005), Vector3(0, 0, -0.012), ArtPalette.flat(paper, 0.8))
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.0016
	l.width = size.x / l.pixel_size * 0.9
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.font_size = fit_font_size(text, ThemeDB.fallback_font, font_size, l.pixel_size, size * 0.9)
	l.modulate = Color(0.15, 0.17, 0.25)
	l.outline_size = 0
	l.position = Vector3(0, 0, -0.016)
	l.rotation_degrees.y = 180
	l.double_sided = false
	root.add_child(l)
	return root


## The largest font size up to `font_size` at which `text`, word-wrapped to
## `box.x` metres, is no taller than `box.y` and has no word wider than `box.x`.
static func fit_font_size(text: String, font: Font, font_size: int, pixel_size: float, box: Vector2) -> int:
	var fs := font_size
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	while fs > 12:
		var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, box.x / pixel_size, fs, -1, flags) * pixel_size
		if sz.x <= box.x + 0.001 and sz.y <= box.y:
			break
		fs -= 2
	return fs


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


## Overhead cable tray: a shallow open channel, visual only.
static func cable_tray(parent: Node, center: Vector3, length: float, along_x: bool = false) -> Node3D:
	var root := _node(parent, center, 90.0 if along_x else 0.0, "CableTray")
	var mat := ArtPalette.surface("metal")
	_piece(root, Vector3(0.4, 0.02, length), Vector3.ZERO, mat)
	for sx in [-0.2, 0.2]:
		_piece(root, Vector3(0.02, 0.08, length), Vector3(sx, 0.04, 0), mat)
	_piece(root, Vector3(0.3, 0.05, length), Vector3(0, 0.035, 0), ArtPalette.flat(Color(0.12, 0.2, 0.45), 0.7))  # the cables
	return root


# --- Fittings -------------------------------------------------------------------
# The ordinary things every office floor has: cafeteria chairs, vending-machine
# fronts, restroom fixtures, an extinguisher on the wall. Fronts and fixtures
# dress Greybox boxes the level already has (visual only, so they never change
# its collision); chairs and buckets are props you bump into.


## A stackable cafeteria chair: tubular legs, moulded plastic seat and back.
static func cafe_chair(parent: Node, pos: Vector3, facing_deg: float = 0.0, shell := Color(0.72, 0.45, 0.2)) -> StaticBody3D:
	var body := _body(parent, pos, facing_deg, "CafeChair", Vector3(0.44, 0.84, 0.44), Vector3(0, 0.42, 0))
	var seat := ArtPalette.flat(shell, 0.45)
	var tube := ArtPalette.flat(Color(0.7, 0.71, 0.72), 0.3, 0.8)
	_piece(body, Vector3(0.42, 0.03, 0.4), Vector3(0, 0.45, 0), seat, true)
	var back := _piece(body, Vector3(0.4, 0.3, 0.025), Vector3(0, 0.66, 0.2), seat, true)
	back.rotation_degrees.x = -8
	for sx in [-0.18, 0.18]:
		for sz in [-0.17, 0.17]:
			_piece(body, Vector3(0.022, 0.45, 0.022), Vector3(sx, 0.225, sz), tube)
	return body


## The front of a vending machine, for a Greybox box: a lit window of rows of
## snacks or cans, a keypad and coin slot, and the pick-up flap. `pos` is the
## middle of the box's front face, `size` that face (width, height).
static func vending_front(parent: Node, pos: Vector3, facing_deg: float, size: Vector2, body_color: Color, drinks := false) -> Node3D:
	var root := _node(parent, pos, facing_deg, "VendingFront")
	var w := size.x
	var h := size.y
	_piece(root, Vector3(w, h, 0.01), Vector3(0, 0, -0.005), ArtPalette.flat(body_color, 0.4, 0.2))
	var win_w := w * 0.62
	var win_h := h * 0.62
	var win_c := Vector3(-w * 0.14, h * 0.08, -0.012)
	_piece(root, Vector3(win_w, win_h, 0.004), win_c, ArtPalette.glow(Color(0.9, 0.92, 0.95), 0.55))
	var rows := 5 if not drinks else 4
	var item_cols: Array[Color] = [Color(0.85, 0.15, 0.1), Color(0.95, 0.75, 0.1), Color(0.2, 0.45, 0.85), Color(0.15, 0.6, 0.25), Color(0.6, 0.25, 0.55)]
	for r in rows:
		var y := win_c.y + win_h / 2.0 - (r + 0.6) * win_h / rows
		_piece(root, Vector3(win_w * 0.96, 0.008, 0.02), Vector3(win_c.x, y - 0.035, -0.02), ArtPalette.flat(Color(0.3, 0.3, 0.32), 0.4, 0.6))
		for c in 5:
			var col: Color = item_cols[(r * 2 + c) % item_cols.size()]
			var item := Vector3(0.06, 0.08 if not drinks else 0.11, 0.03)
			_piece(root, item, Vector3(win_c.x - win_w / 2.0 + (c + 0.5) * win_w / 5.0, y + item.y / 2.0 - 0.03, -0.025), ArtPalette.flat(col, 0.5))
	var dark := ArtPalette.flat(Color(0.08, 0.08, 0.09), 0.4)
	var px := w * 0.36
	_piece(root, Vector3(w * 0.18, h * 0.16, 0.006), Vector3(px, h * 0.22, -0.013), dark)  # keypad
	_piece(root, Vector3(w * 0.12, 0.05, 0.006), Vector3(px, h * 0.34, -0.013), ArtPalette.glow(Color(0.9, 0.2, 0.1), 1.2))  # price display
	_piece(root, Vector3(0.012, 0.05, 0.008), Vector3(px, h * 0.05, -0.014), ArtPalette.flat(Color(0.75, 0.75, 0.76), 0.25, 0.9))  # coin slot
	_piece(root, Vector3(win_w, h * 0.1, 0.01), Vector3(win_c.x, -h * 0.38, -0.012), dark)  # pick-up flap
	return root


## A wall-hung red fire extinguisher on its bracket, with a small sign above.
static func fire_extinguisher(parent: Node, pos: Vector3, facing_deg: float) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Extinguisher")
	var red := ArtPalette.flat(Color(0.72, 0.08, 0.06), 0.35)
	var can := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.075
	cy.bottom_radius = 0.075
	cy.height = 0.5
	cy.radial_segments = 12
	can.mesh = cy
	can.position = Vector3(0, 0, -0.09)
	can.material_override = red
	root.add_child(can)
	_piece(root, Vector3(0.05, 0.07, 0.05), Vector3(0, 0.28, -0.09), ArtPalette.flat(Color(0.15, 0.15, 0.15), 0.4))  # valve
	_piece(root, Vector3(0.1, 0.04, 0.02), Vector3(0, 0.1, -0.01), ArtPalette.flat(Color(0.2, 0.2, 0.2), 0.4, 0.6))  # bracket
	_piece(root, Vector3(0.2, 0.2, 0.004), Vector3(0, 0.5, -0.002), ArtPalette.flat(Color(0.75, 0.1, 0.08), 0.6))
	var l := _print(root, "FIRE\nEXTINGUISHER", Vector3(0, 0.5, -0.005), 0.18, NotebookArt.type_font(), 40, Color(0.97, 0.95, 0.9))
	l.pixel_size = 0.0004
	l.width = 0.19 / l.pixel_size
	return root


## A yellow folding wet-floor sign. `knocked` lays it on its side.
static func wet_floor_sign(parent: Node, pos: Vector3, facing_deg: float = 0.0, knocked := false) -> Node3D:
	var root := _node(parent, pos, facing_deg, "WetFloor")
	var yellow := ArtPalette.flat(Color(0.95, 0.78, 0.1), 0.45)
	var hold := Node3D.new()
	if knocked:
		hold.rotation_degrees.z = 90
		hold.position.y = 0.15
	root.add_child(hold)
	for side in [-1.0, 1.0]:
		var leaf := _piece(hold, Vector3(0.3, 0.6, 0.012), Vector3(0, 0.3, side * 0.09), yellow, true)
		leaf.rotation_degrees.x = -side * 15.0  # an A: the leaves meet at the top
	var l := _print(hold, "CAUTION\nWET FLOOR", Vector3(0, 0.36, -0.084), 0.26, NotebookArt.type_font(), 48, Color(0.1, 0.1, 0.1))
	l.pixel_size = 0.0005
	l.width = 0.27 / l.pixel_size
	l.rotation_degrees.x = -15  # turned to face out, so this leans it with its leaf
	return root


## A wall-hung toilet and its cistern, against a wall behind it (+Z). Visual only.
static func toilet(parent: Node, pos: Vector3, facing_deg: float) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Toilet")
	var china := ArtPalette.flat(Color(0.93, 0.93, 0.91), 0.15)
	_piece(root, Vector3(0.38, 0.35, 0.55), Vector3(0, 0.25, -0.1), china, true)
	_piece(root, Vector3(0.4, 0.04, 0.5), Vector3(0, 0.44, -0.12), ArtPalette.flat(Color(0.85, 0.85, 0.83), 0.3))  # seat
	_piece(root, Vector3(0.45, 0.4, 0.16), Vector3(0, 0.7, 0.16), china, true)
	_piece(root, Vector3(0.012, 0.18, 0.012), Vector3(0.24, 0.85, 0.2), ArtPalette.flat(Color(0.72, 0.73, 0.75), 0.25, 0.9))  # pipe
	return root


## A restroom mirror with a steel frame and a hot-air hand dryer.
static func restroom_mirror(parent: Node, pos: Vector3, facing_deg: float, width := 0.9) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Mirror")
	_piece(root, Vector3(width + 0.03, 0.73, 0.015), Vector3.ZERO, ArtPalette.flat(Color(0.7, 0.71, 0.72), 0.25, 0.9))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.6, 0.62)
	glass.metallic = 1.0
	glass.roughness = 0.04
	_piece(root, Vector3(width, 0.7, 0.004), Vector3(0, 0, -0.009), glass)
	return root


static func hand_dryer(parent: Node, pos: Vector3, facing_deg: float) -> Node3D:
	var root := _node(parent, pos, facing_deg, "HandDryer")
	_piece(root, Vector3(0.26, 0.24, 0.16), Vector3(0, 0, -0.08), ArtPalette.flat(Color(0.88, 0.88, 0.86), 0.35), true)
	_piece(root, Vector3(0.06, 0.04, 0.06), Vector3(0, -0.13, -0.11), ArtPalette.flat(Color(0.7, 0.71, 0.72), 0.25, 0.9))  # nozzle
	_piece(root, Vector3(0.05, 0.05, 0.01), Vector3(0, 0.03, -0.162), ArtPalette.flat(Color(0.3, 0.3, 0.32), 0.5))  # button
	return root


## A microwave on a counter (sitting on `pos`).
static func microwave(parent: Node, pos: Vector3, facing_deg: float = 0.0) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Microwave")
	_piece(root, Vector3(0.5, 0.3, 0.38), Vector3(0, 0.15, 0), ArtPalette.flat(Color(0.88, 0.87, 0.84), 0.4), true)
	_piece(root, Vector3(0.32, 0.22, 0.005), Vector3(-0.06, 0.15, -0.191), ArtPalette.glass(Color(0.05, 0.05, 0.05)))
	_piece(root, Vector3(0.08, 0.22, 0.005), Vector3(0.19, 0.15, -0.191), ArtPalette.flat(Color(0.25, 0.25, 0.27), 0.5))
	_piece(root, Vector3(0.05, 0.015, 0.003), Vector3(0.19, 0.24, -0.194), ArtPalette.glow(Color(0.2, 1.0, 0.4), 1.2))  # the clock
	return root


## A grid of wooden pigeonholes for a Greybox box's front face (`size`), about
## half of them with mail in. A big fitting: dividers and envelopes go past the
## usual prop budget, so use it once a room.
static func pigeonhole_front(parent: Node, pos: Vector3, facing_deg: float, size: Vector2, cols := 10, rows := 6) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Pigeonholes")
	var wood := ArtPalette.flat(Color(0.52, 0.38, 0.24), 0.7)
	_piece(root, Vector3(size.x, size.y, 0.01), Vector3(0, 0, -0.005), ArtPalette.flat(Color(0.16, 0.12, 0.08), 0.9))  # the dark insides
	for c in cols + 1:
		_piece(root, Vector3(0.02, size.y, 0.06), Vector3(-size.x / 2.0 + c * size.x / cols, 0, -0.03), wood)
	for r in rows + 1:
		_piece(root, Vector3(size.x, 0.02, 0.06), Vector3(0, -size.y / 2.0 + r * size.y / rows, -0.03), wood)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var env := ArtPalette.flat(PAPER_WHITE, 0.9)
	var manila := ArtPalette.flat(Color(0.85, 0.72, 0.48), 0.9)
	for i in int(cols * rows * 0.45):
		var c := rng.randi_range(0, cols - 1)
		var r := rng.randi_range(0, rows - 1)
		var cx := -size.x / 2.0 + (c + 0.5) * size.x / cols
		var cy := -size.y / 2.0 + r * size.y / rows + 0.04
		var e := _piece(root, Vector3(size.x / cols * 0.75, 0.05, 0.004), Vector3(cx, cy, -0.035 - rng.randf() * 0.01), env if rng.randf() < 0.7 else manila)
		e.rotation_degrees.x = -70
	return root


## A 90s dot-matrix printer on a desk (sitting on `pos`), green-bar paper
## feeding in from a box underneath and folding out over the back.
static func dot_matrix_printer(parent: Node, pos: Vector3, facing_deg: float = 0.0) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Printer")
	var shell := ArtPalette.surface("plastic")
	_piece(root, Vector3(0.46, 0.13, 0.32), Vector3(0, 0.065, 0), shell, true)
	_piece(root, Vector3(0.4, 0.04, 0.12), Vector3(0, 0.15, 0.06), ArtPalette.flat(Color(0.3, 0.3, 0.3), 0.4))  # the lid
	_piece(root, Vector3(0.05, 0.012, 0.004), Vector3(0.17, 0.09, -0.161), ArtPalette.glow(Color(0.2, 1.0, 0.4), 1.2))  # on-line light
	var paper := ArtPalette.flat(Color(0.92, 0.95, 0.88), 0.9)
	var bars := ArtPalette.flat(Color(0.7, 0.86, 0.72), 0.9)
	var out := _piece(root, Vector3(0.38, 0.002, 0.3), Vector3(0, 0.2, 0.2), paper)
	out.rotation_degrees.x = -50
	for i in 3:
		var bar := _piece(root, Vector3(0.38, 0.0025, 0.03), Vector3(0, 0.2 + i * 0.05 * 0.77, 0.12 + i * 0.05 * 0.64), bars)
		bar.rotation_degrees.x = -50
	return root


## A 90s plain-paper fax with a handset: warm grey shell, a sloping keypad with
## its LCD, the paper feeder at the back with a stack of sheets, and the end of
## the last fax curling out of the front slot. One mesh. `pos` is on the desk top
## under its middle; it faces -Z (about 0.4 wide, 0.44 deep).
static func fax_machine(parent: Node, pos: Vector3, facing_deg: float = 0.0) -> Node3D:
	var root := _node(parent, pos, facing_deg, "FaxMachine")
	var m := ArtMesh.new()
	var shell := Color(0.8, 0.78, 0.72)
	var dark := Color(0.2, 0.2, 0.22)
	var key := Color(0.88, 0.87, 0.83)
	var paper := Color(0.95, 0.95, 0.91)
	# Body: the low front, the taller printer hump behind, rubber feet.
	m.box(Vector3(0.02, 0.05, -0.06), Vector3(0.36, 0.1, 0.3), shell, 0.0, ["bottom"])
	m.box(Vector3(0.02, 0.08, 0.13), Vector3(0.36, 0.16, 0.14), shell, 0.0, ["bottom"])
	for x in [-0.14, 0.18]:
		for z in [-0.18, 0.16]:
			m.box(Vector3(x, 0.004, z), Vector3(0.03, 0.008, 0.03), dark)
	# The control panel, sloping up to the hump: LCD, a 3 x 4 keypad, Start and Stop.
	var slope := Basis(Vector3.RIGHT, deg_to_rad(-22.0))
	var panel := Vector3(0.05, 0.118, -0.03)
	m.oriented_box(panel, Vector3(0.26, 0.014, 0.12), shell.darkened(0.08), slope)
	m.oriented_box(panel + slope * Vector3(-0.05, 0.008, 0.03), Vector3(0.11, 0.004, 0.028), Color(0.52, 0.6, 0.48), slope)  # the LCD
	for r in 4:
		for c in 3:
			m.oriented_box(panel + slope * Vector3(0.035 + c * 0.024, 0.009, -0.035 + r * 0.02), Vector3(0.018, 0.006, 0.013), key, slope)
	m.oriented_box(panel + slope * Vector3(-0.09, 0.009, -0.025), Vector3(0.03, 0.006, 0.018), Color(0.25, 0.6, 0.3), slope)  # Start
	m.oriented_box(panel + slope * Vector3(-0.05, 0.009, -0.025), Vector3(0.03, 0.006, 0.018), Color(0.7, 0.2, 0.18), slope)  # Stop
	# The handset in its cradle on the left, with a coiled cord into the side.
	m.box(Vector3(-0.17, 0.1, -0.02), Vector3(0.09, 0.012, 0.3), shell.darkened(0.1))  # cradle
	m.box(Vector3(-0.17, 0.125, -0.02), Vector3(0.05, 0.03, 0.2), dark)  # the grip
	for end in [-1.0, 1.0]:
		m.box(Vector3(-0.17, 0.122, -0.02 + end * 0.11), Vector3(0.065, 0.035, 0.06), dark)  # ear and mouthpiece
	for k in 7:
		var a := float(k) * 0.9
		m.rod(Vector3(-0.205, 0.07 + sin(a) * 0.012, 0.06 + k * 0.012), Vector3(-0.205, 0.07 + sin(a + 0.9) * 0.012, 0.072 + k * 0.012), 0.005, dark, 4)
	# The feeder at the back, leaning away, with sheets in it and its guides.
	var lean := Basis(Vector3.RIGHT, deg_to_rad(-62.0))
	var tray := Vector3(0.04, 0.2, 0.24)
	m.oriented_box(tray, Vector3(0.3, 0.008, 0.2), dark, lean)
	m.oriented_box(tray + lean * Vector3(0, 0.008, 0.01), Vector3(0.21, 0.006, 0.18), paper, lean)
	for x in [-0.115, 0.115]:
		m.oriented_box(tray + lean * Vector3(x, 0.018, 0), Vector3(0.008, 0.03, 0.18), dark, lean)
	# The output slot and the end of the last fax, curling out over the front.
	m.box(Vector3(0.02, 0.07, -0.211), Vector3(0.26, 0.012, 0.004), Color(0.05, 0.05, 0.05))
	var curl := [Vector3(0, 0.07, -0.214), Vector3(0, 0.06, -0.25), Vector3(0, 0.035, -0.275), Vector3(0, 0.012, -0.28)]
	for i in curl.size() - 1:
		var a: Vector3 = curl[i] + Vector3(0.02, 0, 0)
		var b: Vector3 = curl[i + 1] + Vector3(0.02, 0, 0)
		var mid := (a + b) / 2.0
		var along := (b - a)
		var normal := Vector3(1, 0, 0).cross(along).normalized()
		m.plate(mid, Vector3(0.11, 0, 0), along / 2.0, paper)
		m.plate(mid - normal * 0.0005, Vector3(-0.11, 0, 0), along / 2.0, paper)
	m.box(Vector3(-0.08, 0.06, -0.212), Vector3(0.05, 0.012, 0.003), Color(0.25, 0.45, 0.7))  # the maker's badge
	m.commit(root, "Mesh", true, 0.6)
	return root


## A wooden cable drum, lying on its side with blue network cable wound on it.
## For a Greybox spool box: `pos` is the floor under its middle; visual only.
static func cable_drum(parent: Node, pos: Vector3, facing_deg: float, radius := 0.4, width := 0.7) -> Node3D:
	var root := _node(parent, pos, facing_deg, "CableDrum")
	var wood := ArtPalette.flat(Color(0.55, 0.4, 0.25), 0.9)
	for side in [-1.0, 1.0]:
		var flange := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = radius
		cy.bottom_radius = radius
		cy.height = 0.04
		cy.radial_segments = 16
		flange.mesh = cy
		flange.material_override = wood
		flange.rotation_degrees.z = 90
		flange.position = Vector3(side * width / 2.0, radius, 0)
		root.add_child(flange)
	var core := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = radius * 0.8
	cc.bottom_radius = radius * 0.8
	cc.height = width - 0.04
	cc.radial_segments = 16
	core.mesh = cc
	core.material_override = ArtPalette.flat(Color(0.12, 0.25, 0.6), 0.6)
	core.rotation_degrees.z = 90
	core.position = Vector3(0, radius, 0)
	root.add_child(core)
	return root


## A coil of cable hung on a shelf edge or hook, facing -Z.
static func cable_coil(parent: Node, pos: Vector3, facing_deg: float, color := Color(0.85, 0.75, 0.15)) -> Node3D:
	var root := _node(parent, pos, facing_deg, "CableCoil")
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.11
	tm.outer_radius = 0.15
	tm.rings = 14
	tm.ring_segments = 6
	mi.mesh = tm
	mi.rotation_degrees.x = 90
	mi.position = Vector3(0, -0.15, -0.03)
	mi.material_override = ArtPalette.flat(color, 0.6)
	root.add_child(mi)
	return root


# --- Documents -------------------------------------------------------------------
# Paper the players read: binders, desk cards, brochures, memos, corkboards and
# clipboards. Visual only, facing -Z like a poster; the mechanics put an
# Interactable around them and open DocumentView to read them up close. Each sets
# meta "doc_size" (its footprint, Vector3) so a collider can be sized to it. On a
# desk, `pos` is the spot on the desk top it rests on; on a wall, its center.

const PAPER_WHITE := Color(0.95, 0.94, 0.9)
const PAPER_CREAM := Color(0.93, 0.89, 0.78)
const PRINT_INK := Color(0.16, 0.16, 0.2)


## A three-ring binder: open on a desk to a manual page with typed lines and
## Mercer's fountain-pen notes in the margin ("- H.M."), or closed and standing
## with its title on the spine.
static func binder(parent: Node, pos: Vector3, facing_deg: float, title: String, open := true) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Binder")
	var vinyl := ArtPalette.flat(ArtPalette.HALCYON_NAVY, 0.45)
	if not open:
		root.set_meta("doc_size", Vector3(0.06, 0.3, 0.27))
		_piece(root, Vector3(0.06, 0.3, 0.27), Vector3(0, 0.15, 0), vinyl, true)
		_piece(root, Vector3(0.046, 0.288, 0.262), Vector3(0, 0.15, 0.006), ArtPalette.flat(PAPER_CREAM, 0.9))  # page edges
		_piece(root, Vector3(0.04, 0.16, 0.002), Vector3(0, 0.17, -0.136), ArtPalette.flat(PAPER_WHITE, 0.8))  # spine label
		var spine := _print(root, title, Vector3(0, 0.17, -0.138), 0.15, NotebookArt.type_font(), 26, PRINT_INK)
		spine.rotation_degrees.z = -90
		return root
	root.set_meta("doc_size", Vector3(0.58, 0.03, 0.31))
	var face := _flat_face(root, true, 0.0)
	face.position.y = 0.007  # the covers lie on the desk, the pages on them
	for side in [-1, 1]:
		_piece(face, Vector3(0.29, 0.31, 0.006), Vector3(side * 0.145, 0, 0.003), vinyl, true)
		_piece(face, Vector3(0.215, 0.28, 0.01 if side < 0 else 0.016), Vector3(side * 0.142, 0, -0.005 if side < 0 else -0.008), ArtPalette.flat(PAPER_CREAM, 0.9))
	var page := Node3D.new()
	page.name = "Page"
	page.position = Vector3(0.142, 0, -0.0165)
	face.add_child(page)
	var ring := ArtPalette.flat(Color(0.75, 0.76, 0.78), 0.25, 0.9)
	for y in [-0.09, 0.0, 0.09]:
		_piece(face, Vector3(0.022, 0.012, 0.012), Vector3(0.0, y, -0.012), ring)
		page.add_child(_hole(Vector3(-0.09, y, -0.0002)))
	var title_l := _print(page, title, Vector3(0.0, 0.118, -0.0003), 0.17, NotebookArt.type_font(), 30, PRINT_INK)
	title_l.name = "Title"
	_lines(page, Vector3(-0.005, 0.09, -0.0003), 0.15, 9, 0.019)
	_lines(face, Vector3(-0.142, 0.1, -0.0103), 0.16, 11, 0.019)
	var hm := _print(page, "check the timestamps!\n- H.M.", Vector3(0.062, -0.1, -0.0004), 0.08, NotebookArt.old_hand_font(), 30, NotebookArt.FOUNTAIN_INK)
	hm.name = "Margin"
	hm.rotation_degrees.z = 6
	return root


## A laminated tent card standing on a desk (the guard clock-in card, the visitor
## rules): glossy, leaning back, its title and a few printed lines on the front.
static func desk_card(parent: Node, pos: Vector3, facing_deg: float, title: String) -> Node3D:
	var root := _node(parent, pos, facing_deg, "DeskCard")
	root.set_meta("doc_size", Vector3(0.22, 0.13, 0.1))
	var gloss := ArtPalette.flat(PAPER_WHITE, 0.12)
	var lean := 20.0
	var foot := 0.13 * sin(deg_to_rad(lean))  # the two panels meet at the top
	for side in [-1, 1]:
		var panel := Node3D.new()
		panel.position = Vector3(0, 0, -side * foot)
		panel.rotation_degrees.x = lean * side
		root.add_child(panel)
		_piece(panel, Vector3(0.21, 0.13, 0.002), Vector3(0, 0.065, 0), gloss, true)
		if side == 1:
			panel.name = "Front"
			_piece(panel, Vector3(0.21, 0.026, 0.0005), Vector3(0, 0.115, -0.0012), ArtPalette.flat(ArtPalette.HALCYON_NAVY, 0.15))
			var l := _print(panel, title, Vector3(0, 0.115, -0.0016), 0.19, NotebookArt.type_font(), 22, Color(0.95, 0.95, 0.92))
			l.name = "Title"
			_lines(panel, Vector3(0, 0.088, -0.0013), 0.17, 4, 0.016)
			_piece(panel, Vector3(0.05, 0.004, 0.0005), Vector3(0.035, 0.024, -0.0014), ArtPalette.flat(NotebookArt.INK, 0.5))  # a handwritten fill-in
	return root


## A trifold brochure: open flat on a desk with its side panels curling up, or
## folded and standing in a clear acrylic holder on a counter.
static func brochure(parent: Node, pos: Vector3, facing_deg: float, title: String, flat_on_desk := true) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Brochure")
	var gloss := ArtPalette.flat(PAPER_WHITE, 0.2)
	var navy := ArtPalette.flat(ArtPalette.HALCYON_NAVY, 0.2)
	var w := 0.093
	var h := 0.216
	if not flat_on_desk:
		root.set_meta("doc_size", Vector3(0.12, 0.2, 0.08))
		var acrylic := ArtPalette.glass(Color(0.85, 0.9, 0.92))
		_piece(root, Vector3(0.11, 0.004, 0.07), Vector3(0, 0.002, 0), acrylic)
		_piece(root, Vector3(0.11, 0.08, 0.003), Vector3(0, 0.04, -0.03), acrylic)
		var lean := Node3D.new()
		lean.position = Vector3(0, 0.004, 0.0)
		lean.rotation_degrees.x = -15
		root.add_child(lean)
		var front := Node3D.new()
		front.name = "Front"
		front.position = Vector3(0, h / 2, 0)
		lean.add_child(front)
		_piece(front, Vector3(w, h, 0.004), Vector3.ZERO, gloss, true)
		_panel_print(front, title, w, h, navy, true)
		return root
	root.set_meta("doc_size", Vector3(w * 3, 0.02, h))
	var face := _flat_face(root, true, 0.0)
	for i in 3:
		var panel := Node3D.new()
		panel.position = Vector3((i - 1) * w, 0, 0)
		if i != 1:  # side panels hinge on the folds and curl up a little
			var hinge := Node3D.new()
			hinge.position = Vector3((i - 1) * w * 0.5, 0, 0)
			hinge.rotation_degrees.y = (i - 1) * 10.0
			face.add_child(hinge)
			panel.position = Vector3((i - 1) * w * 0.5, 0, 0)
			hinge.add_child(panel)
		else:
			panel.name = "Front"
			face.add_child(panel)
		_piece(panel, Vector3(w, h, 0.0006), Vector3.ZERO, gloss)
		_panel_print(panel, title if i == 1 else "", w, h, navy, i == 1)
	return root


## Two stapled sheets: pinned to a wall or a corkboard, or lying on a desk.
static func memo(parent: Node, pos: Vector3, facing_deg: float, title: String, flat_on_desk := false) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Memo")
	root.set_meta("doc_size", Vector3(0.21, 0.297, 0.01) if not flat_on_desk else Vector3(0.21, 0.01, 0.297))
	var face := _flat_face(root, flat_on_desk, float(abs(title.hash()) % 7 - 3) * 0.8)
	var paper := sticky_paper(PAPER_WHITE)
	var under := _piece(face, Vector3(0.21, 0.297, 0.0004), Vector3(0.004, -0.004, 0), ArtPalette.flat(PAPER_WHITE.darkened(0.05), 0.9))
	under.rotation_degrees.z = -2.0
	var sheet := _piece(face, Vector3(0.21, 0.297, 0.0004), Vector3(0, 0, -0.0006), paper)
	sheet.name = "Paper"
	var l := _print(face, title, Vector3(0, 0.12, -0.001), 0.18, NotebookArt.type_font(), 26, PRINT_INK)
	l.name = "Title"
	_lines(face, Vector3(0, 0.09, -0.0009), 0.17, 12, 0.017)
	# Company stationery: the gold letterhead rule and Halcyon's mark, as on the page up close.
	_piece(face, Vector3(0.17, 0.0016, 0.0002), Vector3(0, 0.104, -0.0009), ArtPalette.flat(ArtPalette.HALCYON_GOLD, 0.5))
	var mark := _piece(face, Vector3(0.011, 0.011, 0.0002), Vector3(0.078, 0.128, -0.0009), ArtPalette.flat(ArtPalette.HALCYON_GOLD, 0.5))
	mark.rotation_degrees.z = 45
	var staple := _piece(face, Vector3(0.014, 0.0016, 0.0008), Vector3(-0.088, 0.13, -0.0012), ArtPalette.flat(Color(0.78, 0.79, 0.8), 0.25, 0.9))
	staple.rotation_degrees.z = 40
	return root


## A cork noticeboard in a wood frame, with a few pushpins. Hang it on a wall and
## pin memos to it: its cork face is 1.5 cm in front of `pos` (z = -0.015).
static func corkboard(parent: Node, pos: Vector3, facing_deg: float, size := Vector2(1.2, 0.9)) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Corkboard")
	root.set_meta("doc_size", Vector3(size.x, size.y, 0.03))
	var wood := ArtPalette.flat(Color(0.48, 0.33, 0.2), 0.6)
	_piece(root, Vector3(size.x, size.y, 0.02), Vector3(0, 0, -0.005), ArtPalette.flat(Color(0.64, 0.47, 0.3), 0.95))
	for sy in [-1, 1]:
		_piece(root, Vector3(size.x + 0.04, 0.04, 0.03), Vector3(0, sy * (size.y / 2 + 0.01), -0.005), wood, true)
	for sx in [-1, 1]:
		_piece(root, Vector3(0.04, size.y, 0.03), Vector3(sx * (size.x / 2 + 0.01), 0, -0.005), wood, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1994
	var speck := ArtPalette.flat(Color(0.45, 0.31, 0.19), 0.95)
	for i in 14:  # darker flecks so it reads as cork
		_piece(root, Vector3(0.012, 0.008, 0.001), Vector3(rng.randf_range(-0.45, 0.45) * size.x, rng.randf_range(-0.43, 0.43) * size.y, -0.0155), speck)
	for i in 4:  # spare pins
		var col: Color = STICKY_COLORS[i % STICKY_COLORS.size()].darkened(0.25)
		_piece(root, Vector3(0.012, 0.012, 0.014), Vector3(rng.randf_range(-0.4, 0.4) * size.x, rng.randf_range(-0.4, 0.4) * size.y, -0.022), ArtPalette.flat(col, 0.3))
	return root


## A clipboard with a ruled roster or sign-in sheet under its metal clip: on a
## desk, or hanging on a wall hook by the door.
static func clipboard(parent: Node, pos: Vector3, facing_deg: float, title: String, flat_on_desk := true) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Clipboard")
	root.set_meta("doc_size", Vector3(0.23, 0.02, 0.32) if flat_on_desk else Vector3(0.23, 0.32, 0.02))
	var face := _flat_face(root, flat_on_desk, float(abs(title.hash()) % 5 - 2) * 1.2)
	if flat_on_desk:
		face.position.y = 0.003
	_piece(face, Vector3(0.23, 0.32, 0.004), Vector3.ZERO, ArtPalette.flat(Color(0.42, 0.29, 0.18), 0.55), true)
	var sheet := _piece(face, Vector3(0.21, 0.28, 0.0004), Vector3(0, -0.012, -0.0024), sticky_paper(PAPER_WHITE))
	sheet.name = "Paper"
	var metal := ArtPalette.flat(Color(0.74, 0.75, 0.77), 0.25, 0.9)
	_piece(face, Vector3(0.1, 0.035, 0.012), Vector3(0, 0.14, -0.007), metal, true)
	_piece(face, Vector3(0.03, 0.012, 0.02), Vector3(0, 0.155, -0.012), metal)
	var l := _print(face, title, Vector3(0, 0.1, -0.0028), 0.18, NotebookArt.type_font(), 24, PRINT_INK)
	l.name = "Title"
	# The roster grid: header rule, rows, and a column line for the time.
	var grid := ArtPalette.flat(Color(0.35, 0.4, 0.55), 0.9)
	_piece(face, Vector3(0.19, 0.008, 0.0002), Vector3(0, 0.084, -0.0026), ArtPalette.flat(Color(0.82, 0.82, 0.84), 0.9))  # the printed header band
	for r in 11:
		_piece(face, Vector3(0.19, 0.0008, 0.0002), Vector3(0, 0.08 - r * 0.02, -0.0027), grid)
	for x in [-0.03, 0.05]:
		_piece(face, Vector3(0.0008, 0.2, 0.0002), Vector3(x, -0.02, -0.0027), grid)
	for r in 4:  # names signed in so far
		_piece(face, Vector3(0.05 + float(r % 2) * 0.02, 0.004, 0.0002), Vector3(-0.07, 0.07 - r * 0.02, -0.0029), ArtPalette.flat(NotebookArt.INK, 0.5))
	return root


## The node a document is drawn on: flat on the desk (facing up) or upright.
static func _flat_face(root: Node3D, flat: bool, tilt_deg: float) -> Node3D:
	var face := Node3D.new()
	face.name = "Face"
	if flat:
		face.rotation_degrees.x = 90
		face.position.y = 0.002
	face.rotation_degrees.z = tilt_deg
	root.add_child(face)
	return face


## Printed (or handwritten) words on a document, facing -Z.
static func _print(parent: Node3D, text: String, pos: Vector3, width_m: float, font: Font, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = font_size
	l.pixel_size = 0.00025
	l.width = width_m / l.pixel_size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees.y = 180
	l.double_sided = false
	parent.add_child(l)
	return l


## Grey bars standing in for body text too small to read from arm's length.
static func _lines(parent: Node3D, top: Vector3, width: float, count: int, spacing: float) -> void:
	var mat := ArtPalette.flat(Color(0.55, 0.55, 0.58), 0.9)
	for i in count:
		var w := width * (0.62 if i % 4 == 3 else 1.0)
		_piece(parent, Vector3(w, 0.003, 0.0002), top + Vector3(-(width - w) / 2, -i * spacing, 0), mat)


static func _hole(pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.004
	cm.bottom_radius = 0.004
	cm.height = 0.0004
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = ArtPalette.flat(Color(0.2, 0.2, 0.22), 0.9)
	mi.position = pos
	mi.rotation_degrees.x = 90
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## One brochure panel's print: a navy band with the title, then body lines.
static func _panel_print(panel: Node3D, title: String, w: float, h: float, navy: Material, header: bool) -> void:
	var z := -0.0008 if header else -0.0005
	if header:
		_piece(panel, Vector3(w, 0.05, 0.0002), Vector3(0, h / 2 - 0.025, z + 0.0003), navy)
		var l := _print(panel, title, Vector3(0, h / 2 - 0.025, z - 0.0003), w * 0.9, NotebookArt.type_font(), 22, Color(0.96, 0.95, 0.9))
		l.name = "Title"
		_lines(panel, Vector3(0, h / 2 - 0.07, z), w * 0.8, 6, 0.014)
		_piece(panel, Vector3(0.045, 0.004, 0.0002), Vector3(0.008, -0.04, z - 0.0002), ArtPalette.flat(NotebookArt.INK, 0.5))  # the handwritten fill-in
	else:
		_piece(panel, Vector3(w * 0.8, 0.05, 0.0002), Vector3(0, h / 2 - 0.05, z), ArtPalette.flat(ArtPalette.HALCYON_GOLD, 0.4))
		_lines(panel, Vector3(0, h / 2 - 0.1, z), w * 0.8, 6, 0.014)


## How each pack model's surface reads: [roughness, metallic].
const MODEL_FINISH := {
	"generator": [0.6, 0.3], "hand_truck": [0.5, 0.6], "metal_desk": [0.55, 0.4],
	"metal_rack": [0.6, 0.5], "utility_box": [0.6, 0.4], "wall_clock": [0.4, 0.0],
	"wheelie_bin": [0.6, 0.0], "desk_lamp": [0.45, 0.3],
}


## A furniture model from the packs, by id (ArtModels "prop/<id>", built by
## tools/art/build_props.py): one mesh, one draw, no collision. It faces -Z at
## rotation 0 with its origin on the floor under its middle; `stretch` fits it to
## a block it stands in for.
static func model(parent: Node, id: String, pos: Vector3, facing_deg := 0.0, stretch := Vector3.ONE, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = id.to_pascal_case()
	mi.mesh = ArtModels.load_resource("prop/" + id) as Mesh
	var finish: Array = MODEL_FINISH.get(id, [0.8, 0.0])
	mi.material_override = ArtMesh.material(finish[0], finish[1], false)  # the packs' colours are linear
	mi.position = pos
	mi.rotation_degrees.y = facing_deg
	mi.scale = stretch
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi, true)
	return mi


# --- Helpers -------------------------------------------------------------------

static func _node(parent: Node, pos: Vector3, facing_deg: float, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	n.rotation_degrees.y = facing_deg
	parent.add_child(n, true)
	return n


## A static body with one box collider (size, centered at offset).
static func _body(parent: Node, pos: Vector3, facing_deg: float, node_name: String, size: Vector3, offset: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.set_meta("art_prop", true)  # tests check dressing keeps routes clear
	body.position = pos
	body.rotation_degrees.y = facing_deg
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.position = offset
	body.add_child(shape)
	parent.add_child(body, true)  # "CafeChair2", not "@StaticBody3D@7", like Greybox
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


## A hand-me-down three-seat couch: a low frame on stubby legs, rolled arms,
## three seat cushions (the middle one sat flatter) and three back cushions
## leaning back. For a Greybox couch: `pos` is the floor under its middle, its
## front faces -Z at facing 0, seat tops at 0.45; visual only.
static func sofa(parent: Node, pos: Vector3, facing_deg: float, length := 3.2, depth := 0.9, cloth := Color(0.42, 0.43, 0.28)) -> Node3D:
	var root := _node(parent, pos, facing_deg, "Sofa")
	var m := ArtMesh.new()
	var frame := cloth.darkened(0.15)
	var arm := 0.2
	var inner := length - arm * 2.0
	var hz := depth / 2.0
	for x in [-length / 2 + 0.08, length / 2 - 0.08]:
		for z in [-hz + 0.08, hz - 0.08]:
			m.box(Vector3(x, 0.04, z), Vector3(0.05, 0.08, 0.05), Color(0.25, 0.17, 0.1))
	m.box(Vector3(0, 0.19, 0), Vector3(inner, 0.22, depth - 0.02), frame, 0.0, ["bottom"])  # the deck under the cushions
	for side in [-1.0, 1.0]:
		var x: float = side * (length / 2 - arm / 2)
		m.box(Vector3(x, 0.33, 0), Vector3(arm, 0.5, depth), frame, 0.0, ["bottom"])
		m.rod(Vector3(x, 0.6, -hz - 0.01), Vector3(x, 0.6, hz), arm * 0.58, cloth, 10, true)  # the roll
	m.box(Vector3(0, 0.55, hz - 0.08), Vector3(inner, 0.6, 0.16), frame, 0.0, ["bottom"])
	var seat_w := inner / 3.0
	var lean := Basis(Vector3.RIGHT, deg_to_rad(12.0))
	for i in 3:
		var x := -inner / 2 + seat_w * (i + 0.5)
		var sag := 0.02 if i == 1 else 0.0
		var tone := cloth.lightened(0.04) if i == 1 else cloth
		m.box(Vector3(x, 0.375 - sag / 2, -0.06), Vector3(seat_w - 0.015, 0.15 - sag, depth - 0.18), tone)
		m.oriented_box(Vector3(x, 0.66, hz - 0.22), Vector3(seat_w - 0.02, 0.4, 0.16), tone, lean)
	# A mustard throw pillow tucked in the far corner.
	m.oriented_box(Vector3(inner / 2 - 0.16, 0.6, 0.05), Vector3(0.36, 0.34, 0.12), Color(0.72, 0.55, 0.18),
		Basis(Vector3.UP, deg_to_rad(-60.0)) * Basis(Vector3.RIGHT, deg_to_rad(15.0)))
	m.commit(root, "Mesh", true, 0.95)
	return root


## A diner counter stool: a chrome base, post and foot ring, a padded vinyl seat
## with a chrome band and its top at `height`. `taped` patches a split in the
## vinyl with duct tape. `pos` is the floor under it; visual only.
static func bar_stool(parent: Node, pos: Vector3, height := 0.75, vinyl := Color(0.55, 0.12, 0.1), taped := false) -> Node3D:
	var root := _node(parent, pos, 0.0, "BarStool")
	var chrome := ArtMesh.new()
	var steel := Color(0.8, 0.81, 0.82)
	chrome.rod(Vector3.ZERO, Vector3(0, 0.025, 0), 0.2, steel, 16, true)
	chrome.rod(Vector3(0, 0.025, 0), Vector3(0, height - 0.08, 0), 0.025, steel, 8)
	chrome.rod(Vector3(0, height - 0.09, 0), Vector3(0, height - 0.065, 0), 0.12, steel, 12, true)
	chrome.rod(Vector3(0, height - 0.06, 0), Vector3(0, height - 0.035, 0), 0.193, steel, 16)  # the band round the seat
	var ring := 0.17
	var y := 0.3
	for i in 12:
		var a := TAU * i / 12.0
		var b := TAU * (i + 1) / 12.0
		chrome.rod(Vector3(cos(a) * ring, y, sin(a) * ring), Vector3(cos(b) * ring, y, sin(b) * ring), 0.01, steel, 4)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		chrome.rod(Vector3(0, y, 0), Vector3(cos(a) * ring, y, sin(a) * ring), 0.008, steel, 4)
	chrome.commit(root, "Chrome", true, 0.25, 0.9)
	var seat := ArtMesh.new()
	seat.rod(Vector3(0, height - 0.065, 0), Vector3(0, height - 0.008, 0), 0.19, vinyl, 16, true)
	seat.rod(Vector3(0, height - 0.008, 0), Vector3(0, height, 0), 0.165, vinyl.lightened(0.05), 16, true)
	if taped:
		var tape := Color(0.62, 0.63, 0.64)
		seat.box(Vector3(0.03, height + 0.0008, 0.02), Vector3(0.2, 0.0015, 0.045), tape, 35.0)
		seat.box(Vector3(0.02, height + 0.0012, 0.03), Vector3(0.16, 0.0015, 0.045), tape, -40.0)
	seat.commit(root, "Seat", true, 0.4)
	return root


## A run of kitchen base cabinets under a laminate top: a drawer over a door in
## each bay, handles, a dark kick plate set back. For a Greybox counter: `pos` is
## the floor under its middle, the doors face -Z at facing 0; visual only.
static func kitchen_counter(parent: Node, pos: Vector3, facing_deg: float, length: float, depth: float, height: float,
		wood := Color(0.58, 0.42, 0.27), top := Color(0.86, 0.83, 0.75)) -> Node3D:
	var root := _node(parent, pos, facing_deg, "KitchenCounter")
	var m := ArtMesh.new()
	var top_t := 0.04
	var body_h := height - top_t
	var front := -depth / 2 + 0.004
	var metal := Color(0.7, 0.68, 0.62)
	m.box(Vector3(0, 0.05, 0.03), Vector3(length - 0.02, 0.1, depth - 0.08), Color(0.12, 0.11, 0.1), 0.0, ["bottom"])
	m.box(Vector3(0, 0.1 + (body_h - 0.1) / 2, 0), Vector3(length - 0.02, body_h - 0.1, depth - 0.02), wood.darkened(0.12), 0.0, ["bottom"])
	m.box(Vector3(0, height - top_t / 2, -0.02), Vector3(length + 0.04, top_t, depth + 0.04), top)
	m.box(Vector3(0, height - top_t - 0.004, -depth / 2 - 0.01), Vector3(length + 0.04, 0.008, 0.02), top.darkened(0.3))  # the edge band
	var bays := maxi(1, roundi(length / 0.6))
	var w := (length - 0.04) / bays
	for i in bays:
		var x := -length / 2 + 0.02 + w * (i + 0.5)
		m.box(Vector3(x, body_h - 0.1, front), Vector3(w - 0.025, 0.15, 0.012), wood)
		m.box(Vector3(x, body_h - 0.1, front - 0.012), Vector3(0.1, 0.012, 0.012), metal)
		var door_h := body_h - 0.34
		m.box(Vector3(x, 0.12 + door_h / 2, front), Vector3(w - 0.025, door_h, 0.012), wood)
		var hinge := -1.0 if i % 2 == 0 else 1.0
		m.box(Vector3(x - hinge * (w / 2 - 0.06), 0.12 + door_h - 0.1, front - 0.012), Vector3(0.012, 0.09, 0.012), metal)
	m.commit(root, "Mesh", true, 0.6)
	return root


## A drip coffee maker with the jug half full. `pos` is the counter top under it,
## the jug faces -Z at facing 0.
static func coffee_maker(parent: Node, pos: Vector3, facing_deg: float = 0.0) -> Node3D:
	var root := _node(parent, pos, facing_deg, "CoffeeMaker")
	var m := ArtMesh.new()
	var black := Color(0.08, 0.08, 0.09)
	m.box(Vector3(0, 0.015, -0.02), Vector3(0.2, 0.03, 0.24), black, 0.0, ["bottom"])  # the hot plate
	m.box(Vector3(0, 0.17, 0.07), Vector3(0.2, 0.34, 0.1), black, 0.0, ["bottom"])  # the water tower
	m.box(Vector3(0, 0.3, -0.03), Vector3(0.2, 0.08, 0.2), black)  # the filter basket
	m.box(Vector3(0.07, 0.02, -0.141), Vector3(0.012, 0.008, 0.004), Color(0.9, 0.15, 0.1))  # on
	m.rod(Vector3(0, 0.03, -0.06), Vector3(0, 0.11, -0.06), 0.065, Color(0.2, 0.11, 0.05), 10, true)
	m.rod(Vector3(0, 0.11, -0.06), Vector3(0, 0.2, -0.06), 0.063, Color(0.55, 0.58, 0.6), 10, true)  # the glass above it
	m.rod(Vector3(0, 0.2, -0.06), Vector3(0, 0.235, -0.06), 0.05, black, 10, true)
	m.box(Vector3(0, 0.13, -0.14), Vector3(0.02, 0.12, 0.03), black)  # the jug's handle
	m.commit(root, "Mesh", true, 0.35)
	return root
