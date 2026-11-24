class_name DressGroundBack
extends RefCounted
## Furnishing for the ground floor's back of house (GroundFloor's): the kitchen
## behind the cafeteria's serving hatch, the janitor's closet, Building Services
## and receiving, left as the day shift left them. Called from DressLevel0.ground,
## so Level 0 and Level 4's walk out share them. Solid props go in `geo`, the rest
## in `dress`. No words anywhere in here.

const STEEL := Color(0.62, 0.64, 0.66)
const DARK := Color(0.12, 0.12, 0.13)
const CARD := Color(0.62, 0.48, 0.3)
const PAPER := Color(0.93, 0.92, 0.86)


# --- The kitchen ------------------------------------------------------------------

## The roller grille in the kitchen's serving hatch, down for the night: rods and
## links you can see the kitchen through, its guides, and the roll's housing over
## it on the kitchen's side. GroundFloor's solid `ServingGrille` is what stops you.
static func serving_hatch(geo: Node3D, dress: Node3D) -> void:
	if geo.has_node("ServingGrille"):
		ArtDress.hide_block(geo.get_node("ServingGrille"))
	var hatch := GroundFloor.SERVING_HATCH
	var wide := GroundFloor.SERVING_HATCH_WIDE
	var sill: float = GroundFloor.SERVING_COUNTER_SIZE.y
	var head := GroundFloor.SERVING_HATCH_HEAD
	var root := ArtProps._node(dress, Vector3(hatch.x, 0, hatch.y), 0, "ServingGrilleBars")
	var m := ArtMesh.new()
	var pitch := 0.08
	var rows := int((head - sill - 0.06) / pitch)
	for i in rows + 1:
		var y := sill + 0.06 + i * pitch
		m.rod(Vector3(-wide / 2.0, y, 0), Vector3(wide / 2.0, y, 0), 0.006, STEEL, 4)
		if i == rows:
			break
		var x := -wide / 2.0 + (0.2 if i % 2 == 0 else 0.4)
		while x < wide / 2.0 - 0.05:
			m.box(Vector3(x, y + pitch / 2.0, 0), Vector3(0.02, pitch, 0.008), STEEL.darkened(0.2), 0.0, ["top", "bottom"])
			x += 0.4
	m.box(Vector3(0, sill + 0.03, 0), Vector3(wide, 0.06, 0.04), STEEL.darkened(0.3))  # its bottom bar
	for sx in [-1.0, 1.0]:
		m.box(Vector3(sx * (wide / 2.0 - 0.025), (sill + head) / 2.0, 0), Vector3(0.05, head - sill, 0.08), STEEL.darkened(0.35))  # the guides
	m.box(Vector3(0, head + 0.14, -0.23), Vector3(wide + 0.2, 0.28, 0.26), STEEL.darkened(0.25))  # the housing
	m.box(Vector3(0, sill + 0.006, 0), Vector3(wide, 0.012, 0.3), STEEL.lightened(0.1))  # the sill plate
	m.commit(root, "Bars", false, 0.4, 0.7)


## The kitchen, behind the cafeteria: the pass under the hatch, the range and
## fryer under their hood (its light left on), refrigerators, three prep tables,
## the dry store's shelves, the walk-in's door and the dish station.
static func kitchen(geo: Node3D, dress: Node3D) -> void:
	var room := GroundFloor.KITCHEN
	# On the pass: trays, a row of empty serving pans, and the order rail over them.
	var pass_top: Vector3 = GroundFloor.PASS_COUNTER + Vector3(0, GroundFloor.PASS_COUNTER_SIZE.y / 2.0, 0)
	_trays(dress, pass_top + Vector3(-3.3, 0, 0.02), 10)
	_trays(dress, pass_top + Vector3(-2.75, 0, -0.02), 6)
	_serving_pans(dress, pass_top + Vector3(1.6, 0, -0.03))
	_order_rail(dress, Vector3(pass_top.x + 0.4, GroundFloor.SERVING_HATCH_HEAD - 0.12, pass_top.z - 0.1))
	# The line, along the north wall.
	_range(geo, GroundFloor.at(room, 12.4, 0, 0.5))
	_fryer(geo, GroundFloor.at(room, 14.1, 0, 0.5))
	_hood(dress, GroundFloor.at(room, 13.0, 0, 0.6), 3.4)
	for east in [6.3, 7.25]:
		_fridge(geo, GroundFloor.at(room, east, 0, 0.5))
	# Prep, down the middle.
	var prep := [7.5, 12.0, 17.5]
	for i in prep.size():
		_prep_table(geo, GroundFloor.at(room, prep[i], 0, 3.7), 2.4, i)
	_pot_rack(dress, GroundFloor.at(room, prep[1], 0, 3.7))
	# The west end: the dry store's shelves, and a chest freezer.
	_shelving(geo, GroundFloor.at(room, 0.38, 0, 3.6), 3.0, false, "dry", "DryShelves")
	_chest_freezer(geo, GroundFloor.at(room, 4.5, 0, room.size.y - 0.5))
	# The east end: the walk-in, the dish station below it, a bin by the door.
	_walk_in(dress)
	_dish_station(geo, dress, Vector3(GroundFloor.DISH_STATION.x, 0, GroundFloor.DISH_STATION.z))
	_wheelie_bin(geo, GroundFloor.at(room, 23.3, 0, room.size.y - 0.5))
	var tile := ArtPalette.surface("floor_tile", Color(1.3, 1.33, 1.34))
	ArtDress.skirting(dress, GroundFloor.mid(room), GroundFloor.span(room, GroundFloor.BACK_H), GroundFloor.gaps_of(room), 1.5, tile)


## A stack of `count` cafeteria trays. `pos` is the counter top under it.
static func _trays(parent: Node3D, pos: Vector3, count: int) -> void:
	var m := ArtMesh.new()
	var shades := [Color(0.5, 0.33, 0.2), Color(0.45, 0.3, 0.18)]
	for i in count:
		m.box(Vector3(0, 0.008 + i * 0.016, 0), Vector3(0.46, 0.014, 0.34), shades[i % 2], float(i * 7 % 5) - 2.0)
	m.commit(ArtProps._node(parent, pos, 0, "Trays"), "Trays")


## Four steel serving pans in a row, washed and empty. `pos` is the counter top
## under the middle one.
static func _serving_pans(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	for i in 4:
		var x := -0.9 + i * 0.6
		m.box(Vector3(x, 0.05, 0), Vector3(0.52, 0.1, 0.32), STEEL.lightened(0.1))
		m.box(Vector3(x, 0.101, 0), Vector3(0.46, 0.004, 0.26), STEEL.darkened(0.45))  # its inside
	m.commit(ArtProps._node(parent, pos, 0, "ServingPans"), "Pans", false, 0.3, 0.7)


## The order rail over the pass: a steel strip with a few blank slips still in it.
static func _order_rail(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	m.box(Vector3.ZERO, Vector3(2.4, 0.03, 0.03), STEEL)
	for i in 4:
		m.box(Vector3(-0.9 + i * 0.37, -0.09, 0.0), Vector3(0.075, 0.16 - (i % 2) * 0.04, 0.002), PAPER, float(i) * 3.0 - 4.0)
	m.commit(ArtProps._node(parent, pos, 0, "OrderRail"), "Rail")


## A six-burner range with a flat-top, two ovens under it, its front to the south.
## `pos` is the floor under it.
static func _range(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "KitchenRange", Vector3(1.8, 0.9, 0.8), Vector3(0, 0.45, 0))
	var m := ArtMesh.new()
	m.box(Vector3(0, 0.47, 0), Vector3(1.8, 0.86, 0.8), STEEL)
	m.box(Vector3(0, 0.02, -0.02), Vector3(1.7, 0.04, 0.7), DARK)
	m.box(Vector3(0, 1.08, -0.38), Vector3(1.8, 0.36, 0.04), STEEL)  # the back riser
	m.box(Vector3(0, 1.26, -0.28), Vector3(1.8, 0.03, 0.24), STEEL)  # and its shelf
	for i in 6:
		var bx := -0.68 + (i % 3) * 0.38
		var bz := -0.18 + (i / 3) * 0.36
		m.rod(Vector3(bx, 0.9, bz), Vector3(bx, 0.915, bz), 0.14, DARK, 8, true)  # a burner's grate
		m.rod(Vector3(bx, 0.915, bz), Vector3(bx, 0.925, bz), 0.05, Color(0.3, 0.3, 0.32), 6, true)
	m.box(Vector3(0.6, 0.905, 0), Vector3(0.5, 0.012, 0.64), Color(0.2, 0.2, 0.21))  # the flat-top
	for i in 2:
		var ox := -0.45 + i * 0.9
		m.box(Vector3(ox, 0.4, 0.402), Vector3(0.8, 0.5, 0.01), STEEL.darkened(0.12))  # an oven door
		m.box(Vector3(ox, 0.42, 0.409), Vector3(0.45, 0.2, 0.004), DARK)
		m.rod(Vector3(ox - 0.33, 0.68, 0.43), Vector3(ox + 0.33, 0.68, 0.43), 0.012, STEEL.lightened(0.15), 5, true)
	for i in 8:
		m.rod(Vector3(-0.77 + i * 0.22, 0.8, 0.4), Vector3(-0.77 + i * 0.22, 0.8, 0.425), 0.022, DARK, 6, true)  # knobs
	# A stock pot left on a back burner, its lid on.
	m.rod(Vector3(-0.68, 0.925, -0.18), Vector3(-0.68, 1.15, -0.18), 0.15, Color(0.72, 0.73, 0.74), 10, true)
	m.rod(Vector3(-0.68, 1.15, -0.18), Vector3(-0.68, 1.165, -0.18), 0.155, Color(0.66, 0.67, 0.68), 10, true)
	m.rod(Vector3(-0.68, 1.165, -0.18), Vector3(-0.68, 1.19, -0.18), 0.02, DARK, 5, true)
	m.commit(body, "Range", true, 0.4, 0.6)


## A twin-well fryer beside the range, its baskets hung up to drain.
static func _fryer(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "Fryer", Vector3(0.8, 0.9, 0.8), Vector3(0, 0.45, 0))
	var m := ArtMesh.new()
	m.box(Vector3(0, 0.47, 0), Vector3(0.8, 0.86, 0.8), STEEL)
	m.box(Vector3(0, 0.02, -0.02), Vector3(0.7, 0.04, 0.7), DARK)
	m.box(Vector3(0, 1.08, -0.38), Vector3(0.8, 0.36, 0.04), STEEL)
	for sx in [-1.0, 1.0]:
		m.box(Vector3(sx * 0.19, 0.902, 0.02), Vector3(0.3, 0.006, 0.5), Color(0.18, 0.15, 0.1))  # a well
		m.box(Vector3(sx * 0.19, 1.1, -0.3), Vector3(0.26, 0.16, 0.12), Color(0.5, 0.5, 0.52))  # its basket, hung on the riser
		m.rod(Vector3(sx * 0.19, 1.14, -0.24), Vector3(sx * 0.19, 1.2, 0.1), 0.01, DARK, 4, true)  # and the basket's handle
	m.box(Vector3(0, 0.4, 0.402), Vector3(0.7, 0.6, 0.01), STEEL.darkened(0.12))
	for i in 2:
		m.rod(Vector3(-0.15 + i * 0.3, 0.8, 0.4), Vector3(-0.15 + i * 0.3, 0.8, 0.425), 0.022, DARK, 6, true)
	m.commit(body, "Fryer", true, 0.4, 0.6)


## The extraction hood over the line, `wide` metres, with its duct up through the
## ceiling (the kitchen's air goes out here). Its light was left on. `pos` is the
## floor under its middle.
static func _hood(parent: Node3D, pos: Vector3, wide: float) -> void:
	var root := ArtProps._node(parent, pos, 0, "RangeHood")
	var m := ArtMesh.new()
	m.box(Vector3(0, 2.36, -0.02), Vector3(wide, 0.44, 0.96), STEEL)
	m.box(Vector3(0, 2.13, -0.02), Vector3(wide + 0.04, 0.05, 1.0), STEEL.darkened(0.2))  # its lip
	for i in 5:
		m.box(Vector3(-wide / 2.0 + wide * (i + 0.5) / 5.0, 2.115, -0.2), Vector3(wide / 5.0 - 0.06, 0.012, 0.4), STEEL.darkened(0.5))  # the grease filters
	m.box(Vector3(0.3, 2.79, -0.15), Vector3(0.7, 0.42, 0.5), STEEL.darkened(0.1))  # the duct
	m.commit(root, "Hood", true, 0.4, 0.6)
	ArtProps._piece(root, Vector3(wide - 0.8, 0.012, 0.1), Vector3(0, 2.1, 0.3), ArtPalette.glow(Color(1.0, 0.92, 0.75), 1.8))
	var light := OmniLight3D.new()
	light.name = "HoodLight"
	light.position = Vector3(0, 1.95, 0.35)
	light.light_color = Color(1.0, 0.9, 0.72)
	light.light_energy = 0.8
	light.omni_range = 6.5
	light.shadow_enabled = false
	root.add_child(light)


## An upright refrigerator, its door to the south.
static func _fridge(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "Fridge", Vector3(0.85, 2.0, 0.8), Vector3(0, 1.0, 0))
	var m := ArtMesh.new()
	m.box(Vector3(0, 1.03, 0), Vector3(0.85, 1.94, 0.8), STEEL.lightened(0.08))
	m.box(Vector3(0, 0.03, -0.02), Vector3(0.75, 0.06, 0.7), DARK)
	m.box(Vector3(0, 0.95, 0.402), Vector3(0.79, 1.55, 0.012), STEEL.lightened(0.14))  # the door
	m.box(Vector3(0.33, 1.0, 0.42), Vector3(0.025, 0.5, 0.03), STEEL.darkened(0.3))  # its handle
	m.box(Vector3(0, 1.87, 0.402), Vector3(0.79, 0.2, 0.01), DARK)  # the compressor's grille
	m.commit(body, "Fridge", true, 0.35, 0.6)


## A steel prep table `long` metres, east-west, a shelf of pots under it. `k`
## picks what was left out on it.
static func _prep_table(geo: Node3D, pos: Vector3, long: float, k: int) -> void:
	var deep := 0.8
	var top := 0.9
	var body := ArtProps._body(geo, pos, 0, "PrepTable", Vector3(long, top, deep), Vector3(0, top / 2.0, 0))
	var m := ArtMesh.new()
	m.box(Vector3(0, top - 0.02, 0), Vector3(long, 0.04, deep), STEEL.lightened(0.1))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			m.rod(Vector3(sx * (long / 2.0 - 0.06), 0, sz * (deep / 2.0 - 0.06)), Vector3(sx * (long / 2.0 - 0.06), top - 0.04, sz * (deep / 2.0 - 0.06)), 0.022, STEEL, 6)
	m.box(Vector3(0, 0.25, 0), Vector3(long - 0.1, 0.025, deep - 0.1), STEEL)
	for i in 3:  # pots on the shelf
		var px := -long / 2.0 + 0.4 + i * 0.6 + (k % 2) * 0.2
		m.rod(Vector3(px, 0.263, 0.05), Vector3(px, 0.42 + (i % 2) * 0.08, 0.05), 0.15 - i * 0.02, Color(0.7, 0.71, 0.72), 10, true)
	match k:
		0:  # a chopping board and a knife, a tub of ladles
			m.box(Vector3(-0.4, top + 0.012, 0.05), Vector3(0.5, 0.024, 0.34), Color(0.85, 0.8, 0.66), 5.0)
			m.box(Vector3(-0.3, top + 0.027, 0.02), Vector3(0.2, 0.003, 0.035), Color(0.82, 0.84, 0.86), 28.0)
			m.box(Vector3(-0.44, top + 0.03, 0.09), Vector3(0.11, 0.016, 0.025), DARK, 28.0)
			m.rod(Vector3(0.7, top, -0.1), Vector3(0.7, top + 0.18, -0.1), 0.08, STEEL, 8, true)
			for a in 3:
				m.rod(Vector3(0.7, top + 0.1, -0.1), Vector3(0.66 + a * 0.05, top + 0.36, -0.14 + a * 0.04), 0.008, STEEL.lightened(0.2), 4, true)
		1:  # mixing bowls nested, sheet pans stacked
			for a in 3:
				m.rod(Vector3(-0.6, top + a * 0.02, 0), Vector3(-0.6, top + 0.12 + a * 0.02, 0), 0.2 - a * 0.03, Color(0.76, 0.77, 0.78), 12, true)
			for a in 5:
				m.box(Vector3(0.5, top + 0.008 + a * 0.014, 0.0), Vector3(0.66, 0.012, 0.46), Color(0.55, 0.56, 0.57), float(a % 3) - 1.0)
		_:  # tubs with their lids on, a roll of film
			for a in 3:
				m.box(Vector3(-0.5 + a * 0.36, top + 0.08, -0.08), Vector3(0.3, 0.16, 0.36), Color(0.86, 0.88, 0.86))
				m.box(Vector3(-0.5 + a * 0.36, top + 0.168, -0.08), Vector3(0.32, 0.016, 0.38), [Color(0.2, 0.4, 0.65), Color(0.65, 0.2, 0.18), Color(0.2, 0.4, 0.65)][a])
			m.box(Vector3(0.75, top + 0.05, 0.1), Vector3(0.12, 0.1, 0.5), Color(0.25, 0.3, 0.55), 6.0)
	m.commit(body, "Table", true, 0.35, 0.6)


## A rack hung from the ceiling over a prep table, pans on its hooks.
static func _pot_rack(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	var y := 2.35
	for sx in [-1.0, 1.0]:
		m.rod(Vector3(sx * 0.9, y, 0), Vector3(sx * 0.9, GroundFloor.BACK_H, 0), 0.008, DARK, 4)
	for sz in [-1.0, 1.0]:
		m.rod(Vector3(-1.0, y, sz * 0.18), Vector3(1.0, y, sz * 0.18), 0.012, DARK, 5, true)
	for sx in [-1.0, 1.0]:
		m.rod(Vector3(sx * 1.0, y, -0.18), Vector3(sx * 1.0, y, 0.18), 0.012, DARK, 5, true)
	for i in 5:
		var x := -0.8 + i * 0.4
		var sz := -0.18 if i % 2 == 0 else 0.18
		var r := 0.15 - (i % 3) * 0.02
		m.rod(Vector3(x, y, sz), Vector3(x, y - 0.22, sz), 0.006, STEEL, 4)  # the hook and the pan's handle
		m.rod(Vector3(x, y - 0.22 - r, sz - 0.02), Vector3(x, y - 0.22 - r, sz + 0.02), r, [Color(0.15, 0.15, 0.16), Color(0.7, 0.45, 0.25), Color(0.72, 0.73, 0.74)][i % 3], 10, true)
	m.commit(ArtProps._node(parent, pos, 0, "PotRack"), "Rack", false, 0.5, 0.5)


## A chest freezer against the south wall, its lid shut.
static func _chest_freezer(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "ChestFreezer", Vector3(1.6, 0.9, 0.7), Vector3(0, 0.45, 0))
	var m := ArtMesh.new()
	var white := Color(0.9, 0.9, 0.88)
	m.box(Vector3(0, 0.41, 0), Vector3(1.6, 0.78, 0.7), white)
	m.box(Vector3(0, 0.85, -0.01), Vector3(1.62, 0.1, 0.72), white.lightened(0.04))  # the lid
	m.box(Vector3(0, 0.795, -0.01), Vector3(1.6, 0.012, 0.7), DARK)  # its seal
	m.box(Vector3(0, 0.84, -0.375), Vector3(0.3, 0.03, 0.03), STEEL)  # the handle
	m.box(Vector3(0.6, 0.15, -0.352), Vector3(0.3, 0.16, 0.004), DARK)  # the vent
	m.commit(body, "Freezer", true, 0.4)


## The walk-in cold room's door furniture, on GroundFloor's `WalkIn` panels: the
## door's frame, its lever and hinges, a kick plate, and the dial beside it.
static func _walk_in(parent: Node3D) -> void:
	var door: Vector3 = GroundFloor.WALK_IN_DOOR
	var size: Vector3 = GroundFloor.WALK_IN_DOOR_SIZE
	var m := ArtMesh.new()
	var x := -0.012  # just proud of the panels' west face
	for sz in [-1.0, 1.0]:
		m.box(Vector3(x, 0, sz * (size.z / 2.0 + 0.03)), Vector3(0.03, size.y + 0.06, 0.06), STEEL.darkened(0.2))
	m.box(Vector3(x, size.y / 2.0 + 0.03, 0), Vector3(0.03, 0.06, size.z + 0.12), STEEL.darkened(0.2))
	m.box(Vector3(x, -size.y / 2.0 + 0.15, 0), Vector3(0.012, 0.3, size.z - 0.04), STEEL)  # kick plate
	for y in [-0.7, 0.0, 0.7]:
		m.box(Vector3(x - 0.01, y, -size.z / 2.0 - 0.03), Vector3(0.04, 0.16, 0.07), STEEL.lightened(0.1))  # hinges
	m.box(Vector3(x - 0.03, 0.05, size.z / 2.0 - 0.1), Vector3(0.05, 0.3, 0.06), STEEL.lightened(0.1))  # the latch
	m.rod(Vector3(x - 0.06, 0.1, size.z / 2.0 - 0.1), Vector3(x - 0.06, 0.1, size.z / 2.0 - 0.38), 0.014, STEEL.lightened(0.2), 6, true)  # its lever
	m.rod(Vector3(x, 0.55, size.z / 2.0 + 0.32), Vector3(x - 0.02, 0.55, size.z / 2.0 + 0.32), 0.07, DARK, 10, true)  # the dial
	m.rod(Vector3(x - 0.02, 0.55, size.z / 2.0 + 0.32), Vector3(x - 0.024, 0.55, size.z / 2.0 + 0.32), 0.06, Color(0.92, 0.92, 0.9), 10, true)
	m.commit(ArtProps._node(parent, door, 0, "WalkInFittings"), "Fittings", false, 0.4, 0.6)


## The dish station along the east wall: two sinks and a drainboard with a rack
## of plates, the sprayer over the first sink, a shelf of clean plates above.
## `pos` is the floor under its middle; its front is to the west.
static func _dish_station(geo: Node3D, dress: Node3D, pos: Vector3) -> void:
	var deep := 0.8
	var long := 2.6
	var top := 0.9
	var body := ArtProps._body(geo, pos, 0, "DishStation", Vector3(deep, top, long), Vector3(0, top / 2.0, 0))
	var m := ArtMesh.new()
	m.box(Vector3(0, top - 0.02, 0), Vector3(deep, 0.04, long), STEEL.lightened(0.1))
	m.box(Vector3(deep / 2.0 - 0.01, top + 0.2, 0), Vector3(0.02, 0.4, long), STEEL)  # the splashback
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 0.0, 1.0]:
			m.rod(Vector3(sx * (deep / 2.0 - 0.06), 0, sz * (long / 2.0 - 0.06)), Vector3(sx * (deep / 2.0 - 0.06), top - 0.04, sz * (long / 2.0 - 0.06)), 0.022, STEEL, 6)
	m.box(Vector3(0, 0.25, 0), Vector3(deep - 0.1, 0.025, long - 0.1), STEEL)
	for i in 2:  # the sinks
		var z := -0.9 + i * 0.7
		m.box(Vector3(-0.03, top - 0.16, z), Vector3(0.56, 0.3, 0.6), STEEL.darkened(0.1), 0.0, ["top"])
		m.box(Vector3(-0.03, top + 0.001, z), Vector3(0.5, 0.004, 0.54), STEEL.darkened(0.55))
	# The sprayer: up from the back of the first sink, over, and down on its hose.
	m.rod(Vector3(0.3, top, -0.9), Vector3(0.3, top + 0.75, -0.9), 0.014, STEEL.lightened(0.2), 6)
	m.rod(Vector3(0.3, top + 0.75, -0.9), Vector3(0.0, top + 0.8, -0.9), 0.014, STEEL.lightened(0.2), 6, true)
	m.rod(Vector3(0.0, top + 0.8, -0.9), Vector3(-0.02, top + 0.4, -0.9), 0.01, DARK, 5)
	m.rod(Vector3(-0.02, top + 0.4, -0.9), Vector3(-0.02, top + 0.3, -0.9), 0.022, STEEL.lightened(0.2), 6, true)
	m.rod(Vector3(0.3, top, -0.2), Vector3(0.3, top + 0.28, -0.2), 0.014, STEEL.lightened(0.2), 6)  # the second sink's tap
	m.rod(Vector3(0.3, top + 0.28, -0.2), Vector3(0.08, top + 0.26, -0.2), 0.012, STEEL.lightened(0.2), 6, true)
	# The drainboard: a rack with plates stood in it.
	m.box(Vector3(-0.02, top + 0.03, 0.75), Vector3(0.5, 0.06, 0.5), Color(0.25, 0.45, 0.4))
	for i in 7:
		m.rod(Vector3(-0.02, top + 0.16, 0.56 + i * 0.062), Vector3(-0.02, top + 0.16, 0.57 + i * 0.062), 0.12, Color(0.94, 0.94, 0.92), 12, true)
	m.commit(body, "Station", true, 0.35, 0.6)
	var shelf := ArtMesh.new()
	shelf.box(Vector3(0, 0, 0), Vector3(0.34, 0.03, 2.2), STEEL)
	for i in 4:
		var z := -0.8 + i * 0.5
		shelf.rod(Vector3(0, 0.015, z), Vector3(0, 0.1 + (i % 2) * 0.07, z), 0.125, Color(0.94, 0.94, 0.92), 12, true)
	for sz in [-1.0, 1.0]:
		shelf.box(Vector3(0.08, -0.1, sz * 0.9), Vector3(0.18, 0.2, 0.02), STEEL.darkened(0.2))  # brackets
	shelf.commit(ArtProps._node(dress, pos + Vector3(deep / 2.0 - 0.2, 1.6, 0), 0, "PlateShelf"), "Shelf", false, 0.4, 0.5)


## A grey bin on wheels, its lid down.
static func _wheelie_bin(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "KitchenBin", Vector3(0.5, 0.9, 0.5), Vector3(0, 0.45, 0))
	var m := ArtMesh.new()
	var grey := Color(0.35, 0.37, 0.38)
	m.box(Vector3(0, 0.46, 0), Vector3(0.48, 0.8, 0.48), grey)
	m.box(Vector3(0, 0.88, -0.01), Vector3(0.52, 0.05, 0.54), grey.darkened(0.2))
	for sx in [-1.0, 1.0]:
		m.rod(Vector3(sx * 0.2, 0.06, 0.2), Vector3(sx * 0.26, 0.06, 0.2), 0.06, DARK, 8, true)
	m.commit(body, "Bin", true)


# --- The janitor's closet -----------------------------------------------------------

## The janitor's closet, between the restrooms: the mop sink in the corner, shelves
## of supplies on the north wall, the cart, a bucket and wringer, brooms on hooks.
static func janitors_closet(geo: Node3D, dress: Node3D) -> void:
	var room := GroundFloor.JANITOR
	_mop_sink(geo, GroundFloor.at(room, 0.5, 0, 0.5))
	_shelving(geo, GroundFloor.JANITOR_SHELVES, 1.4, true, "clean", "JanitorShelves", 0.4)
	_janitor_cart(geo, GroundFloor.at(room, 0.45, 0, 2.3))
	_mop_bucket(geo, GroundFloor.at(room, 2.05, 0, 1.5))
	_broom_hooks(dress, GroundFloor.at(room, room.size.x - 0.11, 1.55, 2.7))
	var tile := ArtPalette.surface("floor_tile", Color(1.3, 1.33, 1.34))
	ArtDress.skirting(dress, GroundFloor.mid(room), GroundFloor.span(room, GroundFloor.BACK_H), GroundFloor.gaps_of(room), 1.2, tile)


## A floor-level mop sink in the north-west corner, its tap on the wall, a mop
## stood in it.
static func _mop_sink(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "MopSink", Vector3(0.7, 0.3, 0.7), Vector3(0, 0.15, 0))
	var m := ArtMesh.new()
	var stone := Color(0.8, 0.8, 0.76)
	m.box(Vector3(0, 0.15, 0), Vector3(0.7, 0.3, 0.7), stone)
	m.box(Vector3(0, 0.301, 0), Vector3(0.56, 0.004, 0.56), stone.darkened(0.45))
	m.rod(Vector3(0, 1.0, -0.38), Vector3(0, 1.0, -0.2), 0.016, STEEL.lightened(0.2), 6, true)  # the tap
	m.rod(Vector3(0, 1.0, -0.2), Vector3(0, 0.9, -0.2), 0.014, STEEL.lightened(0.2), 6, true)
	m.rod(Vector3(-0.1, 0.32, 0.1), Vector3(-0.3, 1.6, -0.3), 0.014, Color(0.7, 0.6, 0.4), 5, true)  # the mop
	m.box(Vector3(-0.09, 0.38, 0.11), Vector3(0.26, 0.14, 0.12), Color(0.8, 0.78, 0.7), 20.0)
	m.commit(body, "MopSink", true)


## The janitor's cart, against the west wall: a bag at one end, shelves of supplies.
static func _janitor_cart(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "JanitorCart", Vector3(0.55, 1.0, 1.0), Vector3(0, 0.5, 0))
	var m := ArtMesh.new()
	var grey := Color(0.4, 0.42, 0.44)
	for y in [0.16, 0.5, 0.84]:
		m.box(Vector3(0, y, -0.15), Vector3(0.5, 0.03, 0.66), grey)
	for sx in [-1.0, 1.0]:
		for sz in [-0.46, 0.16]:
			m.box(Vector3(sx * 0.24, 0.5, sz), Vector3(0.03, 0.9, 0.03), grey.darkened(0.2))
		m.rod(Vector3(sx * 0.2, 0.05, -0.38), Vector3(sx * 0.25, 0.05, -0.38), 0.05, DARK, 8, true)
		m.rod(Vector3(sx * 0.2, 0.05, 0.38), Vector3(sx * 0.25, 0.05, 0.38), 0.05, DARK, 8, true)
	m.box(Vector3(0, 0.55, 0.34), Vector3(0.46, 0.8, 0.3), Color(0.85, 0.75, 0.2))  # the bag
	m.box(Vector3(0, 0.97, 0.34), Vector3(0.5, 0.03, 0.34), grey.darkened(0.2))
	for i in 3:
		m.rod(Vector3(-0.14 + i * 0.14, 0.515, -0.3), Vector3(-0.14 + i * 0.14, 0.74, -0.3), 0.045, [Color(0.2, 0.45, 0.7), Color(0.85, 0.85, 0.82), Color(0.3, 0.6, 0.3)][i], 7, true)
	m.box(Vector3(0, 0.26, -0.15), Vector3(0.36, 0.17, 0.4), Color(0.9, 0.9, 0.86))  # a case of paper towels
	m.commit(body, "Cart", true)


## A mop bucket on castors with its wringer.
static func _mop_bucket(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "MopBucket", Vector3(0.36, 0.45, 0.5), Vector3(0, 0.225, 0))
	var m := ArtMesh.new()
	var yellow := Color(0.9, 0.75, 0.12)
	m.box(Vector3(0, 0.22, 0), Vector3(0.34, 0.32, 0.48), yellow)
	m.box(Vector3(0, 0.381, 0.06), Vector3(0.28, 0.004, 0.3), yellow.darkened(0.6))
	m.box(Vector3(0, 0.42, -0.14), Vector3(0.3, 0.14, 0.18), yellow.darkened(0.15))  # the wringer
	m.rod(Vector3(0.16, 0.44, -0.14), Vector3(0.2, 0.75, -0.2), 0.012, DARK, 5, true)  # its lever
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			m.rod(Vector3(sx * 0.13, 0, sz * 0.2), Vector3(sx * 0.13, 0.06, sz * 0.2), 0.03, DARK, 6, true)
	m.commit(body, "Bucket", true)


## Hooks on the east wall (facing west): a broom, a dust mop and a dustpan.
static func _broom_hooks(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	m.box(Vector3(-0.01, 0, 0), Vector3(0.02, 0.06, 1.0), STEEL.darkened(0.2))
	var wood := Color(0.7, 0.6, 0.4)
	m.rod(Vector3(-0.05, 0.1, -0.3), Vector3(-0.05, -1.25, -0.3), 0.013, wood, 5, true)  # the broom
	m.box(Vector3(-0.06, -1.33, -0.3), Vector3(0.07, 0.16, 0.32), Color(0.25, 0.2, 0.15))
	m.rod(Vector3(-0.05, 0.1, 0.0), Vector3(-0.05, -1.3, 0.0), 0.013, wood, 5, true)  # the dust mop
	m.box(Vector3(-0.06, -1.33, 0.0), Vector3(0.1, 0.05, 0.5), Color(0.75, 0.3, 0.25))
	m.box(Vector3(-0.03, -0.25, 0.32), Vector3(0.03, 0.26, 0.24), Color(0.25, 0.3, 0.5))  # the dustpan
	m.rod(Vector3(-0.04, -0.12, 0.32), Vector3(-0.04, 0.0, 0.32), 0.01, Color(0.25, 0.3, 0.5), 5, true)
	m.commit(ArtProps._node(parent, pos, 0, "BroomHooks"), "Hooks")


# --- Building Services ----------------------------------------------------------------

## Building Services, off the dark corridor: the building engineer's workshop.
## The air handler and the hot water tank on the west side, his bench and tool
## board along the east wall with the parts racks, pipe on the north wall, and
## his desk inside the door.
static func building_services(geo: Node3D, dress: Node3D) -> void:
	var room := GroundFloor.BUILDING_SERVICES
	_air_handler(dress)
	_water_tank(geo, GroundFloor.at(room, 1.3, 0, 1.3))
	var bench: Vector3 = GroundFloor.ENGINEERS_BENCH
	_workbench(geo, Vector3(bench.x, 0, bench.z), GroundFloor.ENGINEERS_BENCH_LONG)
	_tool_board(dress, Vector3(room.end.x - 0.11, 1.7, bench.z - 0.4))
	ArtProps.bar_stool(dress, Vector3(bench.x - 0.95, 0, bench.z + 0.5), 0.62, Color(0.14, 0.15, 0.18))
	for south in [1.4, 4.0]:
		_shelving(geo, GroundFloor.at(room, room.size.x - 0.42, 0, south), 2.4, false, "parts", "PartsRack", 0.6, 2.0)
	_pipe_rack(geo, GroundFloor.at(room, 8.3, 0, 0.36))
	_gas_cylinders(geo, GroundFloor.at(room, 5.2, 0, 0.3))
	_step_ladder(geo, GroundFloor.at(room, 11.3, 0, 0.28))
	# The engineer's desk, against the south wall east of the door: the plant log
	# open on it, his screen off.
	var desk := GroundFloor.at(room, 10.4, 0, room.size.y - 0.5)
	ArtProps.desk(geo, desk, 0, 1.6)
	ArtProps.crt_monitor(dress, desk + Vector3(-0.45, 0.76, 0.08), -14, "off")
	DressGroundRooms._logbook(dress, desk + Vector3(0.25, 0.76, -0.06))
	DressGroundRooms._mug(dress, desk + Vector3(0.66, 0.76, 0.12), Color(0.75, 0.5, 0.15))
	ArtProps.sittable(ArtProps.office_chair(geo, desk + Vector3(0.1, 0, -0.85), 186), ArtProps.OFFICE_SEAT)
	DressLevel0._bin(dress, desk + Vector3(-0.98, 0, -0.2))
	ArtProps.filing_cabinet(geo, GroundFloor.at(room, 12.0, 0, room.size.y - 0.42), 0)
	ArtProps.corkboard(dress, GroundFloor.at(room, 10.4, 1.6, room.size.y - 0.11), 0, Vector2(1.2, 0.8))
	ArtDress.skirting(dress, GroundFloor.mid(room), GroundFloor.span(room, GroundFloor.BACK_H), GroundFloor.gaps_of(room))


## The air handler's casing, on GroundFloor's `AirHandler` block: a base rail,
## four access doors along its east side with their latches, two gauges, the
## control box, and the chilled and hot water pipes from its north end to the wall.
static func _air_handler(parent: Node3D) -> void:
	var ah := GroundFloor.AIR_HANDLER
	var h := GroundFloor.AIR_HANDLER_H
	var long := ah.size.y
	var e := ah.size.x / 2.0 + 0.005
	var paint := Color(0.5, 0.56, 0.58)
	var m := ArtMesh.new()
	m.box(Vector3(0, 0.06, 0), Vector3(ah.size.x + 0.06, 0.12, long + 0.06), paint.darkened(0.55))
	for i in 4:
		var z := -long / 2.0 + long * (i + 0.5) / 4.0
		m.box(Vector3(e, h / 2.0 + 0.06, z), Vector3(0.01, h - 0.36, long / 4.0 - 0.1), paint.lightened(0.07))
		for y in [0.6, 1.45]:
			m.box(Vector3(e + 0.02, y, z + long / 8.0 - 0.14), Vector3(0.03, 0.14, 0.04), DARK)  # a latch
		for y in [0.45, 1.6]:
			m.box(Vector3(e + 0.012, y, z - long / 8.0 + 0.08), Vector3(0.02, 0.1, 0.03), STEEL.darkened(0.3))  # a hinge
	for k in 2:
		var gz := -long / 8.0 - 0.14 + k * 0.24
		m.rod(Vector3(e, 1.1, gz), Vector3(e + 0.03, 1.1, gz), 0.075, DARK, 10, true)  # a gauge
		m.rod(Vector3(e + 0.03, 1.1, gz), Vector3(e + 0.034, 1.1, gz), 0.064, Color(0.92, 0.92, 0.88), 10, true)
		m.box(Vector3(e + 0.036, 1.115, gz + 0.012 - k * 0.03), Vector3(0.002, 0.05, 0.006), Color(0.7, 0.1, 0.1))
	m.box(Vector3(e + 0.08, 1.3, long / 2.0 - 0.4), Vector3(0.16, 0.5, 0.42), Color(0.4, 0.42, 0.44))  # the control box
	m.box(Vector3(e + 0.162, 1.3, long / 2.0 - 0.4), Vector3(0.004, 0.44, 0.36), Color(0.46, 0.48, 0.5))
	m.rod(Vector3(e + 0.16, 1.42, long / 2.0 - 0.5), Vector3(e + 0.18, 1.42, long / 2.0 - 0.5), 0.02, DARK, 6, true)  # its isolator
	# The pipes, lagged: out of the north end, back to the wall.
	var wall := GroundFloor.BUILDING_SERVICES.position.y + 0.1 - ah.get_center().y
	for k in 2:
		var px := 0.5 + k * 0.36
		var py := 1.15 + k * 0.3
		var lag: Color = [Color(0.3, 0.42, 0.62), Color(0.62, 0.3, 0.26)][k]
		m.rod(Vector3(px, py, -long / 2.0), Vector3(px, py, wall), 0.06, lag, 8)
		m.rod(Vector3(px, py, wall + 1.4), Vector3(px, py + 0.2, wall + 1.4), 0.02, STEEL, 5, true)  # a valve
		m.rod(Vector3(px - 0.09, py + 0.2, wall + 1.4), Vector3(px + 0.09, py + 0.2, wall + 1.4), 0.012, Color(0.7, 0.15, 0.1), 5, true)
	m.commit(ArtProps._node(parent, GroundFloor.mid(ah), 0, "AirHandlerCasing"), "Casing", true, 0.5, 0.4)


## The hot water tank, in the corner north of the air handler.
static func _water_tank(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "WaterTank", Vector3(1.0, 1.9, 1.0), Vector3(0, 0.95, 0))
	var m := ArtMesh.new()
	var cream := Color(0.82, 0.8, 0.7)
	for i in 3:
		var a := TAU * i / 3.0
		m.rod(Vector3(cos(a) * 0.36, 0, sin(a) * 0.36), Vector3(cos(a) * 0.36, 0.14, sin(a) * 0.36), 0.03, DARK, 5)
	m.rod(Vector3(0, 0.12, 0), Vector3(0, 1.7, 0), 0.5, cream, 14, true)
	m.rod(Vector3(0, 1.7, 0), Vector3(0, 1.82, 0), 0.38, cream.darkened(0.08), 14, true)
	var copper := Color(0.7, 0.42, 0.25)
	for sx in [-1.0, 1.0]:
		m.rod(Vector3(sx * 0.18, 1.82, 0), Vector3(sx * 0.18, GroundFloor.BACK_H, 0), 0.025, copper, 6)
	m.rod(Vector3(0, 1.1, 0.5), Vector3(0, 1.1, 0.53), 0.06, DARK, 8, true)  # its thermometer
	m.rod(Vector3(0, 1.1, 0.53), Vector3(0, 1.1, 0.534), 0.05, Color(0.92, 0.92, 0.88), 8, true)
	m.rod(Vector3(0.2, 0.3, 0.46), Vector3(0.2, 0.3, 0.6), 0.018, copper, 5, true)  # the drain cock
	m.commit(body, "Tank", true, 0.6, 0.2)


## The engineer's bench along the east wall, `long` metres: a timber top on a
## steel frame, drawers under one end, a vise, his toolbox, and a pump motor
## stripped down on a rag. `pos` is the floor under its middle.
static func _workbench(geo: Node3D, pos: Vector3, long: float) -> void:
	var deep := 0.8
	var top := GroundFloor.ENGINEERS_BENCH.y
	var body := ArtProps._body(geo, pos, 0, "EngineersBench", Vector3(deep, top, long), Vector3(0, top / 2.0, 0))
	var m := ArtMesh.new()
	var wood := Color(0.55, 0.42, 0.28)
	var frame := Color(0.25, 0.3, 0.33)
	m.box(Vector3(0, top - 0.03, 0), Vector3(deep, 0.06, long), wood)
	for sz in [-1.0, 0.0, 1.0]:
		for sx in [-1.0, 1.0]:
			m.box(Vector3(sx * (deep / 2.0 - 0.05), (top - 0.06) / 2.0, sz * (long / 2.0 - 0.05)), Vector3(0.06, top - 0.06, 0.06), frame)
	m.box(Vector3(0, 0.2, 0), Vector3(deep - 0.08, 0.03, long - 0.08), frame.lightened(0.1))
	# Drawers under the south end, their fronts to the west.
	m.box(Vector3(0, 0.56, long / 2.0 - 0.45), Vector3(deep - 0.1, 0.56, 0.7), frame.lightened(0.05))
	for i in 3:
		m.box(Vector3(-deep / 2.0 + 0.046, 0.38 + i * 0.18, long / 2.0 - 0.45), Vector3(0.008, 0.15, 0.64), frame.lightened(0.14))
		m.box(Vector3(-deep / 2.0 + 0.036, 0.38 + i * 0.18, long / 2.0 - 0.45), Vector3(0.014, 0.02, 0.2), STEEL)
	# The vise, at the south end.
	var vz := long / 2.0 - 0.5
	var blue := Color(0.15, 0.25, 0.42)
	m.box(Vector3(-0.22, top + 0.05, vz), Vector3(0.2, 0.1, 0.16), blue)
	m.box(Vector3(-0.2, top + 0.15, vz), Vector3(0.12, 0.1, 0.18), blue)
	m.box(Vector3(-0.3, top + 0.15, vz), Vector3(0.05, 0.12, 0.18), blue.lightened(0.1))
	m.rod(Vector3(-0.36, top + 0.1, vz - 0.12), Vector3(-0.36, top + 0.1, vz + 0.12), 0.008, STEEL.lightened(0.2), 5, true)
	# His toolbox, shut.
	m.box(Vector3(0.12, top + 0.1, 0.4), Vector3(0.24, 0.2, 0.52), Color(0.62, 0.14, 0.1))
	m.rod(Vector3(0.12, top + 0.22, 0.26), Vector3(0.12, top + 0.22, 0.54), 0.012, DARK, 5, true)
	# The pump motor, its end cap off beside it, on a rag; an oil can.
	m.box(Vector3(0.0, top + 0.004, -0.9), Vector3(0.5, 0.008, 0.6), Color(0.6, 0.56, 0.5), 8.0)
	m.rod(Vector3(0.02, top + 0.12, -1.05), Vector3(0.02, top + 0.12, -0.75), 0.11, Color(0.2, 0.36, 0.3), 10, true)
	m.rod(Vector3(0.02, top + 0.12, -0.75), Vector3(0.02, top + 0.12, -0.66), 0.014, STEEL.lightened(0.2), 5, true)  # its shaft
	m.rod(Vector3(-0.16, top + 0.008, -0.62), Vector3(-0.16, top + 0.04, -0.62), 0.1, Color(0.2, 0.36, 0.3), 10, true)  # the cap
	m.rod(Vector3(0.22, top, -1.5), Vector3(0.22, top + 0.1, -1.5), 0.045, Color(0.7, 0.55, 0.15), 8, true)
	m.rod(Vector3(0.22, top + 0.1, -1.5), Vector3(0.12, top + 0.22, -1.5), 0.006, Color(0.7, 0.55, 0.15), 4, true)
	# Under it: paint tins and a fuel can on the shelf.
	for i in 4:
		m.rod(Vector3(0.05, 0.215, -1.6 + i * 0.26), Vector3(0.05, 0.4, -1.6 + i * 0.26), 0.09, [Color(0.75, 0.75, 0.72), Color(0.3, 0.4, 0.55), Color(0.75, 0.75, 0.72), Color(0.55, 0.2, 0.15)][i], 8, true)
	m.box(Vector3(0.05, 0.37, -0.3), Vector3(0.18, 0.3, 0.34), Color(0.6, 0.12, 0.1))
	m.commit(body, "Bench", true)


## The tool board on the east wall over the bench (its face to the west): a
## hammer, spanners by size, a hacksaw, a level, a tape. `pos` is its middle.
static func _tool_board(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	m.box(Vector3(-0.01, 0, 0), Vector3(0.02, 0.9, 2.4), Color(0.6, 0.5, 0.36))
	var x := -0.035
	var metal := STEEL.lightened(0.1)
	m.box(Vector3(x, 0.05, -1.0), Vector3(0.02, 0.32, 0.03), Color(0.6, 0.45, 0.25))  # the hammer
	m.box(Vector3(x, 0.23, -1.0), Vector3(0.03, 0.05, 0.13), DARK)
	for i in 5:  # spanners, biggest first
		var long := 0.34 - i * 0.04
		var z := -0.7 + i * 0.13
		m.box(Vector3(x, 0.3 - long / 2.0, z), Vector3(0.008, long, 0.024), metal)
		m.rod(Vector3(x - 0.004, 0.3, z), Vector3(x + 0.004, 0.3, z), 0.026 - i * 0.002, metal, 6, true)
		m.rod(Vector3(x - 0.004, 0.3 - long, z), Vector3(x + 0.004, 0.3 - long, z), 0.022 - i * 0.002, metal, 6, true)
	# The hacksaw: its frame and blade.
	m.box(Vector3(x, 0.24, 0.3), Vector3(0.012, 0.02, 0.42), Color(0.75, 0.3, 0.1))
	for sz in [-1.0, 1.0]:
		m.box(Vector3(x, 0.17, 0.3 + sz * 0.2), Vector3(0.012, 0.14, 0.02), Color(0.75, 0.3, 0.1))
	m.box(Vector3(x, 0.11, 0.3), Vector3(0.003, 0.014, 0.4), metal)
	m.box(Vector3(x, 0.16, 0.56), Vector3(0.03, 0.12, 0.04), DARK)
	m.box(Vector3(x, -0.2, 0.2), Vector3(0.024, 0.06, 0.7), Color(0.85, 0.7, 0.1))  # the level
	m.rod(Vector3(x - 0.012, -0.2, 0.2), Vector3(x - 0.014, -0.2, 0.2), 0.018, Color(0.6, 0.85, 0.5), 8, true)
	m.rod(Vector3(x - 0.02, 0.2, 0.9), Vector3(x + 0.02, 0.2, 0.9), 0.045, Color(0.85, 0.7, 0.1), 8, true)  # the tape
	for i in 3:  # pliers and cutters: two handles each, crossed
		var z := 0.75 + i * 0.14
		m.rod(Vector3(x, -0.05, z - 0.02), Vector3(x, -0.28, z + 0.025), 0.007, Color(0.6, 0.15, 0.1), 4, true)
		m.rod(Vector3(x, -0.05, z + 0.02), Vector3(x, -0.28, z - 0.025), 0.007, Color(0.6, 0.15, 0.1), 4, true)
		m.box(Vector3(x, -0.02, z), Vector3(0.008, 0.08, 0.02), metal)
	m.commit(ArtProps._node(parent, pos, 0, "ToolBoard"), "Board")


## A pipe rack against the north wall: three uprights with arms, and lengths of
## pipe laid along them (copper, steel, plastic). `pos` is the floor under its middle.
static func _pipe_rack(geo: Node3D, pos: Vector3) -> void:
	var long := 3.6
	var body := ArtProps._body(geo, pos, 0, "PipeRack", Vector3(long, 1.8, 0.5), Vector3(0, 0.9, 0))
	var m := ArtMesh.new()
	var frame := Color(0.25, 0.3, 0.33)
	for sx in [-1.0, 0.0, 1.0]:
		m.box(Vector3(sx * (long / 2.0 - 0.3), 0.9, -0.2), Vector3(0.06, 1.8, 0.06), frame)
		for y in [0.45, 0.95, 1.45]:
			m.box(Vector3(sx * (long / 2.0 - 0.3), y, 0.02), Vector3(0.05, 0.05, 0.42), frame)
			m.box(Vector3(sx * (long / 2.0 - 0.3), y + 0.05, 0.215), Vector3(0.05, 0.06, 0.03), frame)  # the arm's lip
	var kinds := [[Color(0.7, 0.42, 0.25), 0.02], [Color(0.5, 0.52, 0.54), 0.035], [Color(0.88, 0.88, 0.85), 0.05], [Color(0.5, 0.52, 0.54), 0.025]]
	var n := 0
	for row in 3:
		var y := 0.475 + row * 0.5
		var z := -0.12
		while z < 0.16:
			var kind: Array = kinds[(n + row) % kinds.size()]
			var r: float = kind[1]
			var short := float(n % 3) * 0.25
			m.rod(Vector3(-long / 2.0 + 0.05 + short, y + r, z + r), Vector3(long / 2.0 - 0.05 - float((n + 1) % 2) * 0.3, y + r, z + r), r, kind[0], 7, true)
			z += r * 2.0 + 0.012
			n += 1
	m.commit(body, "Rack", true, 0.5, 0.4)


## Two gas cylinders chained to the north wall.
static func _gas_cylinders(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "GasCylinders", Vector3(0.7, 1.5, 0.36), Vector3(0, 0.75, 0))
	var m := ArtMesh.new()
	var paints := [Color(0.45, 0.14, 0.12), Color(0.3, 0.36, 0.42)]
	for i in 2:
		var x := -0.17 + i * 0.34
		m.rod(Vector3(x, 0, 0), Vector3(x, 1.25, 0), 0.13, paints[i], 10, true)
		m.rod(Vector3(x, 1.25, 0), Vector3(x, 1.36, 0), 0.07, paints[i].darkened(0.1), 8, true)
		m.rod(Vector3(x, 1.36, 0), Vector3(x, 1.48, 0), 0.05, DARK, 8, true)  # the cap
	m.rod(Vector3(-0.34, 0.9, 0.14), Vector3(0.34, 0.9, 0.14), 0.008, STEEL, 4, true)  # the chain
	for sx in [-1.0, 1.0]:
		m.rod(Vector3(sx * 0.34, 0.9, 0.14), Vector3(sx * 0.34, 0.9, -0.2), 0.008, STEEL, 4)
	m.commit(body, "Cylinders", true, 0.5, 0.3)


## A step ladder, folded and leant against the north wall.
static func _step_ladder(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "StepLadder", Vector3(0.5, 1.8, 0.3), Vector3(0, 0.9, 0))
	var m := ArtMesh.new()
	var alu := Color(0.72, 0.73, 0.74)
	for sx in [-1.0, 1.0]:
		m.rod(Vector3(sx * 0.21, 0, 0.12), Vector3(sx * 0.19, 1.8, -0.1), 0.016, alu, 5, true)
		m.rod(Vector3(sx * 0.21, 0, 0.06), Vector3(sx * 0.19, 1.7, -0.14), 0.012, alu.darkened(0.15), 5, true)
	for i in 6:
		var t := (i + 0.6) / 6.5
		m.box(Vector3(0, t * 1.8, 0.12 - t * 0.22), Vector3(0.4, 0.02, 0.07), alu)
	m.box(Vector3(0, 1.8, -0.1), Vector3(0.44, 0.04, 0.12), Color(0.7, 0.25, 0.1))  # its top
	m.commit(body, "Ladder", true, 0.4, 0.6)


# --- Receiving --------------------------------------------------------------------------

## Receiving, behind the mailroom: the roll-up door to the dock (down), pallet
## racking along the west wall, the parcel cage, the receiving desk, the scale,
## a hand truck and pallets waiting to be put away.
static func receiving(geo: Node3D, dress: Node3D) -> void:
	var room := GroundFloor.RECEIVING
	_rollup_door(dress)
	_racking(geo, dress)
	_parcel_cage(geo, dress)
	# The receiving desk, against the south wall: the delivery book, a tray of
	# dockets, a tape gun.
	var desk := GroundFloor.at(room, 9.4, 0, room.size.y - 0.5)
	ArtProps.desk(geo, desk, 0, 1.6)
	DressGroundRooms._logbook(dress, desk + Vector3(-0.3, 0.76, -0.05))
	DressLevel0._in_tray(dress, desk + Vector3(0.45, 0.76, 0.05), 3)
	_tape_gun(dress, desk + Vector3(0.08, 0.76, 0.14))
	ArtProps.sittable(ArtProps.office_chair(geo, desk + Vector3(-0.1, 0, -0.85), 174), ArtProps.OFFICE_SEAT)
	_scale(geo, GroundFloor.at(room, 3.3, 0, room.size.y - 1.4))
	_hand_truck(geo, GroundFloor.at(room, 4.7, 0, room.size.y - 0.3))
	_pallet(geo, GroundFloor.at(room, 7.9, 0, 5.4), 6.0, 3)
	_pallet(geo, GroundFloor.at(room, 10.7, 0, 5.3), -4.0, 0)
	ArtDress.skirting(dress, GroundFloor.mid(room), GroundFloor.span(room, GroundFloor.BACK_H), GroundFloor.gaps_of(room))


## The roll-up door's slats, guides, bottom bar and the drum's housing over it,
## on GroundFloor's `RollUpDoor` slab.
static func _rollup_door(parent: Node3D) -> void:
	var size: Vector3 = GroundFloor.ROLLUP_DOOR_SIZE
	var m := ArtMesh.new()
	var face := size.z / 2.0 + 0.003
	var paint := Color(0.6, 0.64, 0.6)
	var slats := int(size.y / 0.1)
	for i in slats:
		m.box(Vector3(0, -size.y / 2.0 + 0.1 * i + 0.05, face), Vector3(size.x, 0.006, 0.004), paint.darkened(0.4))
	m.box(Vector3(0, -size.y / 2.0 + 0.05, face + 0.03), Vector3(size.x, 0.1, 0.07), Color(0.2, 0.2, 0.21))  # the bottom bar
	m.box(Vector3(0, -size.y / 2.0 + 0.3, face + 0.02), Vector3(0.3, 0.03, 0.04), STEEL)  # the lift handle
	for sx in [-1.0, 1.0]:
		m.box(Vector3(sx * (size.x / 2.0 + 0.04), 0.05, face + 0.03), Vector3(0.1, size.y + 0.1, 0.14), STEEL.darkened(0.3))  # a guide
	m.box(Vector3(0, size.y / 2.0 + 0.2, face + 0.12), Vector3(size.x + 0.4, 0.34, 0.32), STEEL.darkened(0.2))  # the housing
	m.commit(ArtProps._node(parent, GroundFloor.ROLLUP_DOOR, 0, "RollUpDoorSlats"), "Slats", false, 0.5, 0.5)


## The racking's beams and braces (on GroundFloor's `RackDeck` and `RackPost`),
## and what's stored on it: cartons and crates on the floor under it and on its
## lower deck. The top deck is nearly bare.
static func _racking(geo: Node3D, dress: Node3D) -> void:
	var rk := GroundFloor.RACKING
	var decks: Array = GroundFloor.RACK_DECKS
	var c := GroundFloor.mid(rk)
	var m := ArtMesh.new()
	var orange := Color(0.85, 0.42, 0.1)
	var blue := Color(0.16, 0.28, 0.5)
	for top in decks:
		for sx in [-1.0, 1.0]:
			m.box(Vector3(sx * (rk.size.x / 2.0 - 0.02), top - 0.13, 0), Vector3(0.05, 0.1, rk.size.y - 0.1), orange)
	for k in 3:
		var z := -rk.size.y / 2.0 + 0.04 + k * (rk.size.y - 0.08) / 2.0
		var w := rk.size.x / 2.0 - 0.04
		m.rod(Vector3(-w, 0.15, z), Vector3(w, 0.75, z), 0.012, blue, 4)
		m.rod(Vector3(w, 0.75, z), Vector3(-w, 1.35, z), 0.012, blue, 4)
		for y in [0.15, 0.75, 1.35]:
			m.rod(Vector3(-w, y, z), Vector3(w, y, z), 0.012, blue, 4)
	m.commit(ArtProps._node(dress, c, 0, "RackingBeams"), "Beams", true, 0.5, 0.4)
	# Stored: [south of the racking's north end, on which level (0 the floor, 1 the
	# lower deck, 2 the top), what].
	var x := rk.get_center().x
	var north := rk.position.y
	for s in [[0.6, 0, "crate"], [1.6, 0, "boxes2"], [2.9, 0, "crate"], [4.4, 0, "boxes2"], [5.3, 0, "boxes1"], [6.5, 0, "crate"],
			[0.7, 1, "boxes2"], [1.3, 1, "boxes2"], [2.7, 1, "boxes1"], [4.6, 1, "boxes2"], [5.9, 1, "boxes1"], [6.6, 1, "boxes2"],
			[0.5, 2, "boxes1"]]:
		var y: float = 0.0 if s[1] == 0 else decks[s[1] - 1]
		var at := Vector3(x, y, north + s[0])
		if s[2] == "crate":
			_crate(geo, at, 0.8, 0.6)
		else:
			ArtProps.boxes(geo, at + Vector3(0.1 * (int(s[0] * 10.0) % 3 - 1), 0, 0), 90.0 + float(int(s[0] * 10.0) % 5) * 3.0 - 6.0, int(str(s[2]).right(1)))


## A slatted wooden crate, `w` square and `h` tall, standing on `pos`.
static func _crate(geo: Node3D, pos: Vector3, w: float, h: float) -> void:
	var body := ArtProps._body(geo, pos, 0, "WoodCrate", Vector3(w, h, w), Vector3(0, h / 2.0, 0))
	var m := ArtMesh.new()
	var wood := Color(0.66, 0.54, 0.36)
	m.box(Vector3(0, h / 2.0, 0), Vector3(w - 0.04, h - 0.02, w - 0.04), wood.darkened(0.12))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			m.box(Vector3(sx * (w / 2.0 - 0.03), h / 2.0, sz * (w / 2.0 - 0.03)), Vector3(0.06, h, 0.06), wood)
	for y in [0.05, h - 0.05]:
		m.box(Vector3(0, y, 0), Vector3(w, 0.08, w), wood, 0.0, ["top", "bottom"] if y < h / 2.0 else ["bottom"])
	m.commit(body, "Crate", true)


## The parcel cage's mesh and frame (on GroundFloor's `CagePanel` and `CageGate`,
## which are what stop you), and what's locked in it overnight: shelves of parcels
## along the east wall, more on the floor.
static func _parcel_cage(geo: Node3D, dress: Node3D) -> void:
	for body in geo.get_children():
		if ArtDress._name_matches(body.name, ["CagePanel", "CageGate"]):
			ArtDress.hide_block(body)
	var cg := GroundFloor.PARCEL_CAGE
	var gate: Vector3 = GroundFloor.CAGE_GATE
	var gate_size: Vector3 = GroundFloor.CAGE_GATE_SIZE
	var h := GroundFloor.BACK_H
	var m := ArtMesh.new()
	var g0 := gate.z - gate_size.z / 2.0
	var g1 := gate.z + gate_size.z / 2.0
	_mesh_panel(m, Vector3(cg.position.x, 0, cg.end.y), Vector3(cg.end.x, 0, cg.end.y), 0.0, h)  # the south side
	_mesh_panel(m, Vector3(cg.position.x, 0, cg.position.y), Vector3(cg.position.x, 0, g0), 0.0, h)  # the west side, round the gateway
	_mesh_panel(m, Vector3(cg.position.x, 0, g1), Vector3(cg.position.x, 0, cg.end.y), 0.0, h)
	_mesh_panel(m, Vector3(cg.position.x, 0, g0), Vector3(cg.position.x, 0, g1), gate_size.y, h)
	_mesh_panel(m, Vector3(gate.x - 0.06, 0, g0 - gate_size.z), Vector3(gate.x - 0.06, 0, g0), 0.0, gate_size.y)  # the gate, swung back
	m.box(Vector3(gate.x - 0.09, 1.05, g0 - gate_size.z + 0.1), Vector3(0.05, 0.1, 0.12), DARK)  # its hasp
	m.commit(ArtProps._node(dress, Vector3.ZERO, 0, "ParcelCageMesh"), "Mesh", false, 0.5, 0.6)
	_shelving(geo, Vector3(cg.end.x - 0.38, 0, cg.get_center().y), 3.2, false, "parcels", "CageShelves")
	ArtProps.boxes(geo, Vector3(cg.position.x + 0.9, 0, cg.position.y + 0.55), 10, 2)
	ArtProps.boxes(geo, Vector3(cg.position.x + 1.5, 0, cg.position.y + 0.5), -6, 1)


## A framed panel of welded mesh from `a` to `b` (on the floor, along x or along
## z), from height `y0` to `y1`.
static func _mesh_panel(m: ArtMesh, a: Vector3, b: Vector3, y0: float, y1: float) -> void:
	var wire := Color(0.5, 0.52, 0.55)
	var frame := Color(0.3, 0.32, 0.35)
	var run := b - a
	var long := run.length()
	if long < 0.05:
		return
	var dir := run / long
	var pitch := 0.12
	var n := int(long / pitch)
	for i in range(1, n):
		var p := a + dir * (long * i / n)
		m.rod(p + Vector3(0, y0, 0), p + Vector3(0, y1, 0), 0.004, wire, 3)
	var rows := int((y1 - y0) / pitch)
	for i in range(1, rows):
		var y := y0 + (y1 - y0) * i / rows
		m.rod(a + Vector3(0, y, 0), b + Vector3(0, y, 0), 0.004, wire, 3)
	for p in [a, b]:
		m.box(p + Vector3(0, (y0 + y1) / 2.0, 0), Vector3(0.05, y1 - y0, 0.05), frame)
	var mid := (a + b) / 2.0
	var rail := Vector3(absf(run.x) + 0.05, 0.05, absf(run.z) + 0.05)
	m.box(mid + Vector3(0, y0 + 0.025, 0), rail, frame)
	m.box(mid + Vector3(0, y1 - 0.025, 0), rail, frame)


## A tape gun, left on the desk.
static func _tape_gun(parent: Node3D, pos: Vector3) -> void:
	var m := ArtMesh.new()
	m.rod(Vector3(-0.012, 0.05, 0), Vector3(0.012, 0.05, 0), 0.05, Color(0.75, 0.62, 0.4), 10, true)  # the roll
	m.box(Vector3(0, 0.04, 0.09), Vector3(0.03, 0.05, 0.12), Color(0.7, 0.15, 0.1))
	m.box(Vector3(0, 0.02, 0.17), Vector3(0.028, 0.09, 0.03), Color(0.7, 0.15, 0.1), 0.0)  # its grip
	m.commit(ArtProps._node(parent, pos, 35, "TapeGun"), "TapeGun")


## A platform scale: a low steel deck you wheel a parcel onto, and its dial on a
## column, read from the north.
static func _scale(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "ParcelScale", Vector3(0.7, 0.1, 0.9), Vector3(0, 0.05, 0))
	var m := ArtMesh.new()
	var green := Color(0.25, 0.38, 0.32)
	m.box(Vector3(0, 0.04, 0), Vector3(0.7, 0.08, 0.9), green)
	m.box(Vector3(0, 0.09, -0.05), Vector3(0.62, 0.02, 0.72), STEEL)
	m.box(Vector3(0, 0.6, 0.4), Vector3(0.08, 1.1, 0.06), green)
	m.rod(Vector3(0, 1.25, 0.43), Vector3(0, 1.25, 0.36), 0.17, green.darkened(0.2), 12, true)
	m.rod(Vector3(0, 1.25, 0.36), Vector3(0, 1.25, 0.355), 0.15, Color(0.93, 0.93, 0.88), 12, true)
	m.box(Vector3(0.03, 1.3, 0.352), Vector3(0.006, 0.12, 0.002), Color(0.7, 0.1, 0.1), 0.0)
	m.commit(body, "Scale", true, 0.5, 0.3)


## A hand truck, stood against the south wall.
static func _hand_truck(geo: Node3D, pos: Vector3) -> void:
	var body := ArtProps._body(geo, pos, 0, "HandTruck", Vector3(0.5, 1.25, 0.36), Vector3(0, 0.625, -0.05))
	var m := ArtMesh.new()
	var red := Color(0.65, 0.14, 0.1)
	for sx in [-1.0, 1.0]:
		m.rod(Vector3(sx * 0.17, 0.1, -0.1), Vector3(sx * 0.17, 1.2, 0.08), 0.016, red, 5, true)
		m.rod(Vector3(sx * 0.21, 0.13, 0.0), Vector3(sx * 0.26, 0.13, 0.0), 0.13, DARK, 10, true)  # a wheel
	for i in 4:
		var t := 0.15 + i * 0.27
		m.rod(Vector3(-0.17, 0.1 + t * 1.1, -0.1 + t * 0.18), Vector3(0.17, 0.1 + t * 1.1, -0.1 + t * 0.18), 0.012, red, 4)
	m.box(Vector3(0, 0.02, -0.2), Vector3(0.4, 0.012, 0.24), STEEL.darkened(0.2))  # the toe plate
	m.commit(body, "HandTruck", true, 0.5, 0.4)


## A pallet, turned `yaw` degrees: `layers` of shrink-wrapped cartons on it, or
## with none, a stack of four empties.
static func _pallet(geo: Node3D, pos: Vector3, yaw: float, layers: int) -> void:
	var tall := 0.14 + layers * 0.34 if layers > 0 else 0.56
	var body := ArtProps._body(geo, pos, yaw, "Pallet", Vector3(1.2, tall, 1.0), Vector3(0, tall / 2.0, 0))
	var m := ArtMesh.new()
	var wood := Color(0.68, 0.57, 0.4)
	for k in (1 if layers > 0 else 4):
		var y := k * 0.14
		for sz in [-1.0, 0.0, 1.0]:
			m.box(Vector3(0, y + 0.06, sz * 0.45), Vector3(1.2, 0.08, 0.09), wood.darkened(0.15))
		for i in 5:
			m.box(Vector3(-0.54 + i * 0.27, y + 0.115, 0), Vector3(0.12, 0.022, 1.0), wood.darkened(0.04 * (k % 2)))
	for layer in layers:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				if layer == layers - 1 and sx > 0.0 and sz > 0.0:
					continue  # one carton short on top
				m.box(Vector3(sx * 0.29, 0.14 + layer * 0.34 + 0.165, sz * 0.24), Vector3(0.56, 0.33, 0.46), CARD.lightened(0.04 * ((layer + int(sx)) % 2)))
				m.box(Vector3(sx * 0.29, 0.14 + layer * 0.34 + 0.331, sz * 0.24), Vector3(0.06, 0.002, 0.46), PAPER.darkened(0.2))  # its tape
	m.commit(body, "Pallet", true)


# --- Shelving, used in every room here ----------------------------------------------------

## Open steel shelving `long` metres, `deep` front to back and `tall` high, its
## middle on `pos` (the floor), along x or along z, with four shelves of `kind`
## of goods: "dry" (the kitchen's dry store), "clean" (the janitor's supplies),
## "parts" (the engineer's spares) or "parcels".
static func _shelving(geo: Node3D, pos: Vector3, long: float, along_x: bool, kind: String, node_name: String, deep := 0.5, tall := 1.8) -> void:
	var body := ArtProps._body(geo, pos, 0.0 if along_x else 90.0, node_name, Vector3(long, tall, deep), Vector3(0, tall / 2.0, 0))
	var m := ArtMesh.new()
	var post := Color(0.42, 0.44, 0.46)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			m.box(Vector3(sx * (long / 2.0 - 0.02), tall / 2.0, sz * (deep / 2.0 - 0.02)), Vector3(0.04, tall, 0.04), post)
	var rows := 4
	for row in rows:
		var y := 0.15 + row * (tall - 0.5) / (rows - 1)
		m.box(Vector3(0, y, 0), Vector3(long - 0.04, 0.03, deep - 0.02), post.lightened(0.15))
		var x := -long / 2.0 + 0.08
		var i := 0
		while x < long / 2.0 - 0.5:
			x += _goods(m, kind, row, i, Vector3(x, y + 0.015, 0), deep)
			i += 1
	m.commit(body, "Shelving", true, 0.6, 0.3)


## One thing on a shelf, its west edge at `at` (on the shelf's top, on its centre
## line). Returns how far along the shelf the next one starts.
static func _goods(m: ArtMesh, kind: String, row: int, i: int, at: Vector3, deep: float) -> float:
	var pick := (row * 5 + i * 3) % 7
	if pick == 6:
		return 0.3  # a gap
	var d := deep - 0.14
	match kind:
		"dry":
			match row:
				0:  # sacks
					m.box(at + Vector3(0.25, 0.1, 0), Vector3(0.46, 0.2, d), Color(0.8, 0.74, 0.6), float(pick) * 2.0 - 5.0)
					if pick % 2 == 0:
						m.box(at + Vector3(0.25, 0.29, 0.01), Vector3(0.44, 0.18, d - 0.02), Color(0.76, 0.7, 0.56), 4.0)
					return 0.52
				1:  # catering tins, two deep
					var tin: Color = [Color(0.75, 0.76, 0.77), Color(0.65, 0.2, 0.15), Color(0.25, 0.45, 0.25)][pick % 3]
					for k in 2:
						m.rod(at + Vector3(0.09, 0, -0.09 + k * 0.18), at + Vector3(0.09, 0.2, -0.09 + k * 0.18), 0.08, tin, 8, true)
					return 0.19
				2:  # cartons
					m.box(at + Vector3(0.2, 0.13, 0), Vector3(0.38, 0.26, d), CARD, float(pick) - 3.0)
					return 0.44
				_:  # tubs
					m.rod(at + Vector3(0.12, 0, 0), at + Vector3(0.12, 0.22, 0), 0.1, Color(0.9, 0.9, 0.86), 8, true)
					m.rod(at + Vector3(0.12, 0.22, 0), at + Vector3(0.12, 0.24, 0), 0.105, Color(0.2, 0.35, 0.6), 8, true)
					return 0.27
		"clean":
			match row:
				0:  # big jugs
					var jug: Color = [Color(0.2, 0.4, 0.7), Color(0.9, 0.9, 0.86), Color(0.85, 0.75, 0.2)][pick % 3]
					m.box(at + Vector3(0.1, 0.15, 0), Vector3(0.18, 0.3, 0.26), jug)
					m.rod(at + Vector3(0.1, 0.3, 0.06), at + Vector3(0.1, 0.35, 0.06), 0.03, jug.darkened(0.3), 6, true)
					return 0.23
				1:  # spray bottles
					var spray: Color = [Color(0.3, 0.6, 0.8), Color(0.8, 0.4, 0.6), Color(0.4, 0.7, 0.4)][pick % 3]
					m.rod(at + Vector3(0.05, 0, 0.02), at + Vector3(0.05, 0.18, 0.02), 0.04, spray, 7, true)
					m.box(at + Vector3(0.05, 0.22, 0.0), Vector3(0.03, 0.07, 0.09), Color(0.9, 0.9, 0.88))
					return 0.13
				2:  # paper towel rolls, stacked two high
					for k in 2:
						m.rod(at + Vector3(0.09, k * 0.13, 0), at + Vector3(0.09, 0.12 + k * 0.13, 0), 0.085, Color(0.94, 0.94, 0.9), 8, true)
					return 0.2
				_:  # boxes of bin bags
					m.box(at + Vector3(0.17, 0.09, 0), Vector3(0.32, 0.18, d), [Color(0.2, 0.2, 0.22), CARD][pick % 2], float(pick) - 3.0)
					return 0.37
		"parts":
			match row:
				0:  # a motor on its feet, or a carton
					if pick % 3 == 0:
						m.rod(at + Vector3(0.06, 0.15, 0), at + Vector3(0.4, 0.15, 0), 0.14, Color(0.2, 0.36, 0.3), 10, true)
						m.box(at + Vector3(0.23, 0.015, 0), Vector3(0.26, 0.03, 0.3), DARK)
						return 0.5
					m.box(at + Vector3(0.22, 0.14, 0), Vector3(0.42, 0.28, d), CARD, float(pick) - 3.0)
					return 0.48
				1:  # air filters, stacked flat
					for k in 4:
						m.box(at + Vector3(0.27, 0.027 + k * 0.055, 0), Vector3(0.5, 0.05, d), [Color(0.9, 0.9, 0.86), Color(0.3, 0.45, 0.6)][k % 2], float(k) - 1.5)
					return 0.58
				2:  # parts bins
					var bin: Color = [Color(0.7, 0.15, 0.1), Color(0.85, 0.7, 0.1), Color(0.15, 0.3, 0.6)][pick % 3]
					m.box(at + Vector3(0.08, 0.06, 0.05), Vector3(0.15, 0.12, d - 0.1), bin)
					return 0.17
				_:  # drive belts in their sleeves, boxed lamps
					m.box(at + Vector3(0.15, 0.06, 0), Vector3(0.28, 0.12, d), [CARD, Color(0.85, 0.85, 0.8)][pick % 2], float(pick) - 3.0)
					return 0.33
		_:  # parcels
			var w := 0.24 + float(pick % 3) * 0.1
			var hgt := 0.12 + float((pick + row) % 3) * 0.08
			m.box(at + Vector3(w / 2.0, hgt / 2.0, 0), Vector3(w, hgt, d - float(pick % 2) * 0.1), [CARD, CARD.lightened(0.12), Color(0.8, 0.72, 0.5)][pick % 3], float(pick) * 2.0 - 5.0)
			if pick % 2 == 1:
				m.box(at + Vector3(w / 2.0, hgt + 0.02, 0.02), Vector3(w - 0.06, 0.04, d - 0.2), Color(0.85, 0.8, 0.6), 7.0)  # a padded envelope on top
			return w + 0.06
	return 0.3
