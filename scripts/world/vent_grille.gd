class_name VentGrille
extends RefCounted
## E10: a vent's grille, screwed on over a duct-wide opening (a floor vent, a
## ceiling vent, a wall vent, or a hole in a duct's own floor). Unscrew it with the
## screwdriver and it swings open on one edge; the way's open. Built on the kit's
## ItemLock, so co-op plays it as every kit piece: the host decides, every
## machine swings it. Never labeled: its prompt shows only when you look at it.

const ITEM := "screwdriver"
## New words, waiting on Augustine's OK.
const UNSCREW := "Unscrew the vent grille"
const SCREWED := "It's screwed shut."
const COLOR := Color(0.16, 0.17, 0.18)


## A grille over the opening centred at `center`, facing `normal` (out of the duct,
## toward whoever unscrews it: up for a floor vent, down for a ceiling vent, out of
## the wall for a wall vent). `inner` is the duct's inside (width, height). `id`
## names it the same on every machine. In `parent`'s space; it isn't geo (it moves).
static func make(parent: Node, id: String, center: Vector3, normal: Vector3, inner := Vector2(1.0, 1.0)) -> ItemLock:
	normal = normal.normalized()
	var flat := absf(normal.y) > 0.5
	# Across the opening: `side` is where its hinge is, `span` the other way.
	var side := Vector3.RIGHT if flat or absf(normal.x) < 0.5 else Vector3.BACK
	var span := normal.cross(side).normalized()
	var w := inner.x
	var tall := inner.x if flat else inner.y
	var thick := 0.04
	var size := (side * w + span * tall).abs() + normal.abs() * thick
	var g := ItemLock.make(parent, "grille_" + id, center, size, ITEM, UNSCREW, SCREWED)
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = -side * w / 2.0
	g.add_child(hinge)
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = size
	frame.mesh = fm
	frame.material_override = Greybox.mat(COLOR)
	frame.position = side * w / 2.0
	hinge.add_child(frame)
	# Its slats, across it, so it reads as a vent.
	var n := int(tall / 0.12)
	for i in n:
		var s := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = (side * (w - 0.08)).abs() + span.abs() * 0.03 + normal.abs() * 0.02
		s.mesh = sm
		s.material_override = Greybox.mat(COLOR.darkened(0.4))
		s.position = side * w / 2.0 + span * (-tall / 2.0 + 0.06 + i * (tall - 0.12) / maxf(n - 1, 1)) + normal * (thick / 2.0 + 0.005)
		hinge.add_child(s)
	g.opened.connect(func(_peer):
		for c in g.get_children():
			if c is CollisionShape3D:
				c.set_deferred("disabled", true)
		# Off its screws, it swings out on the hinge edge.
		hinge.basis = Basis(span, -PI / 2.0))
	return g
