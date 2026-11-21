class_name CableAnchor
extends Interactable
## E2 (environment play): somewhere at the top of a climb to tie a network cable
## off: a railing post, a pipe bracket, a bolted ring. Whoever gets up there first
## with a cable on them ties it off, and it hangs down the wall to the floor;
## everyone else climbs it like a pipe (W + Space at it). It uses that cable up
## until someone up top unties it and takes it back, which is a real choice,
## since a cable also ties people up. Co-op: the host decides, every machine
## plays it out. Build one with make() and put it at the top of the wall.

## What you tie off.
const ITEM := "cable"
## New words, waiting on Augustine's OK.
const TIE := "Tie the network cable off"
const UNTIE := "Untie the network cable"
## Shown at an anchor with nothing tied to it, to someone with no cable.
const NEED := "Something to tie a cable to."
## Cat5's blue.
const CABLE_COLOR := Color(0.22, 0.42, 0.78)
const POST_COLOR := Color(0.32, 0.33, 0.34)
## Host: presses this soon after a tie or untie are taken as the same press.
const DEBOUNCE_MS := 800
## Its own post stands this far back from the edge (metres): clear of where the
## biggest body climbs onto the top.
const POST_BACK := 1.0

## Every machine: the cable went on (tied) or came off. `peer_id` did it.
signal changed(tied: bool, peer_id: int)

var tied := false
## The anchor keeps its own cable, tied and untied in place by anyone: nobody's
## inventory changes (a floor whose gear stays on it).
var fixed := false
## Who tied it on (their peer id), while it's tied.
var tied_by := 0
## The top of the climb, on the wall's face at the edge, and the floor at its
## foot, in world space; `out` points from the wall toward the climber.
var top := Vector3.ZERO
var bottom := Vector3.ZERO
var out := Vector3.FORWARD
## What you see while it's tied: down the wall and over the edge to the post.
var rope: Node3D
## A fixed anchor's cable lying coiled, while it isn't tied.
var coil: Node3D
## The climb up it, while it's tied.
var volume: MovementVolume
var _changed_at := -100000


## An anchor at `top` (a point on the wall's face, at the edge you climb over),
## for a cable hanging down the wall to the floor `drop` metres below. `out`
## points away from the wall, over the drop. In `parent`'s space, like the
## Traversal helpers (pass the level's geo, at the origin). `fixed`: it has its
## own cable (see `fixed`). `tie_at`: where the cable's tied (a beam overhead,
## say), instead of a short post on the top just back from the edge.
static func make(parent: Node3D, at_top: Vector3, wall_out: Vector3, drop: float, is_fixed := false, tie_at := Vector3(INF, INF, INF)) -> CableAnchor:
	var a := CableAnchor.new()
	a.name = "CableAnchor"
	a.fixed = is_fixed
	a.out = Vector3(wall_out.x, 0, wall_out.z).normalized()
	a.top = at_top
	a.bottom = at_top + Vector3.DOWN * drop
	var own_post := tie_at.x == INF
	a.position = at_top - a.out * POST_BACK + Vector3.UP * 0.3 if own_post else tie_at
	a.prompt = TIE
	a.kind = "none"
	if own_post:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.08, 0.6, 0.08)
		post.mesh = pm
		post.material_override = Greybox.mat(POST_COLOR)
		a.add_child(post)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.25, 0.6, 0.25)
	shape.shape = bs
	a.add_child(shape)
	a.rope = _rope_model(at_top + a.out * 0.03 - a.position, drop)
	a.rope.visible = false
	a.add_child(a.rope)
	if a.fixed:
		a.coil = _coil_model()
		a.add_child(a.coil)
	parent.add_child(a)
	a.add_to_group("interactable")
	a.used.connect(a._on_used)
	return a


## The cable from where it's tied (this node's origin) to the edge (`edge`, from
## here), then straight down the wall `drop` metres.
static func _rope_model(edge: Vector3, drop: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Cable"
	var mat := Greybox.mat(CABLE_COLOR)
	var knot := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(0.12, 0.05, 0.12)
	knot.mesh = km
	knot.material_override = mat
	root.add_child(knot)
	root.add_child(_strand(Vector3.ZERO, edge, mat))
	root.add_child(_strand(edge, edge + Vector3.DOWN * drop, mat))
	return root


## A cable's straight run from `a` to `b`.
static func _strand(a: Vector3, b: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.016
	cm.bottom_radius = 0.016
	cm.height = maxf(a.distance_to(b), 0.01)
	cm.radial_segments = 6
	m.mesh = cm
	m.material_override = mat
	m.position = (a + b) / 2.0
	var d := b - a
	if d.length() > 0.001:
		var up := d.normalized()
		var side := up.cross(Vector3.FORWARD) if absf(up.dot(Vector3.FORWARD)) < 0.9 else up.cross(Vector3.RIGHT)
		side = side.normalized()
		m.basis = Basis(side, up, side.cross(up))
	return m


## A fixed anchor's own cable, coiled by it while it isn't tied.
static func _coil_model() -> Node3D:
	var m := MeshInstance3D.new()
	m.name = "Coil"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.1
	tm.outer_radius = 0.14
	m.mesh = tm
	m.material_override = Greybox.mat(CABLE_COLOR)
	m.position = Vector3(0, -0.28, 0)
	return m


func get_prompt(player: Node) -> String:
	if not enabled:
		return ""
	if fixed:
		return "[E] " + (UNTIE if tied else TIE)
	if tied:
		return "" if _has_cable(player) else "[E] " + UNTIE  # one cable each: yours first
	return "[E] " + TIE if _has_cable(player) else NEED


## Only someone with a cable ties one on; only someone without takes it off.
## Anyone ties or unties a fixed one.
func interact(player: Node) -> void:
	if fixed or tied != _has_cable(player):
		super.interact(player)


func _has_cable(player: Node) -> bool:
	var inv = player.get("inventory") if player else null
	return inv != null and inv.has(ITEM)


## Host: someone pressed it.
func _on_used(player: Node) -> void:
	var now := Time.get_ticks_msec()
	if now - _changed_at < DEBOUNCE_MS:
		return  # two at once: the first one counts
	_changed_at = now
	var lvl := _level()
	var id: int = lvl.players.id_of(player) if lvl else 0
	var method := "untie" if tied else "tie"
	var sync := LevelSync.of(self)
	if sync:
		sync.run_on(self, method, [id])
	else:
		call(method, id, player)


## Every machine: `peer_id` ties their cable off here. `who` is their body when
## there's no co-op session (a test's own players).
func tie(peer_id: int, who: Node = null) -> void:
	if tied:
		return
	tied = true
	tied_by = peer_id
	rope.visible = true
	if coil:
		coil.visible = false
	_make_volume()
	var me := _taker(peer_id, who)
	if me and not fixed:
		me.inventory.remove(ITEM)
	changed.emit(true, peer_id)


## Every machine: `peer_id` unties it and takes the cable.
func untie(peer_id: int, who: Node = null) -> void:
	if not tied:
		return
	tied = false
	tied_by = 0
	rope.visible = false
	if coil:
		coil.visible = true
	_drop_volume()
	var me := _taker(peer_id, who)
	if me and not fixed:
		me.inventory.add(ITEM)
	changed.emit(false, peer_id)


## The body whose inventory gains or loses the cable on this machine, or null.
func _taker(peer_id: int, who: Node) -> Node:
	if who and who.get("inventory") != null:
		return who
	var lvl := _level()
	if lvl and lvl.get("player") and peer_id == lvl.players.id_of(lvl.player):
		return lvl.player
	return null


func _make_volume() -> void:
	if volume or not is_inside_tree():
		return
	var host: Node3D = get_parent()
	var g_top: Vector3 = host.to_global(top)
	var g_bottom: Vector3 = host.to_global(bottom)
	var g_out: Vector3 = (host.global_basis * out).normalized()
	var height := g_top.y - g_bottom.y
	var across := g_out.cross(Vector3.UP).abs()
	var size := across * 0.7 + Vector3.UP * (height + 0.4) + g_out.abs() * 0.9
	var center := g_bottom + g_out * 0.55 + Vector3.UP * (height + 0.4) / 2.0
	volume = MovementVolume.create(host, host.to_local(center), size, MovementVolume.Kind.CLIMB)
	volume.name = "CableClimb"
	volume.a = g_bottom
	volume.b = g_top
	volume.normal = g_out


## Off the wall: anyone on it drops off it now (the volume's gone, not left).
func _drop_volume() -> void:
	if volume == null:
		return
	for b in volume.get_overlapping_bodies():
		if b.has_method("exit_volume"):
			b.exit_volume(volume)
	volume.queue_free()
	volume = null


## The level this is in (it has the players). Duck-typed, like ItemDock._level.
func _level() -> Node:
	var n := get_parent()
	while n and n.get("players") == null:
		n = n.get_parent()
	return n
