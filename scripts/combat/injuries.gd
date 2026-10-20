class_name Injuries
extends Node3D
## Damage you can see, instead of a health bar. As an entity gets hurt it shows
## it: torn clothing and blood on a person, scorch marks and sparks on a machine,
## and a limp that slows it down. `severity` runs 0 (unhurt) to 1 (nearly beaten).
##
## The marks hang off the entity's CharacterRig joints when it has one, so they
## move with the pose (and lie down with it); otherwise off its `_body`. They
## appear in a fixed order, so every co-op machine shows the same ones for the
## same severity: entities only need to sync whatever severity comes from.
##
##   var wounds := Injuries.attach(self, Injuries.Kind.FLESH)
##   wounds.severity = 1.0 - float(hits_left) / max_hits
##   velocity *= wounds.speed_scale()

enum Kind { FLESH, MACHINE }

## How much slower it moves at full severity.
const LIMP := 0.4
## How far its hips dip and tilt on the bad leg at full severity (radians).
const LIMP_TILT := 0.14
## Where wounds show, in order: [joint, offset from it, size]. Joints are a
## CharacterRig's; the offsets are for a body facing -Z.
const SPOTS := [
	["spine", Vector3(0.1, 0.28, -0.135), Vector2(0.12, 0.09)],
	["r_hip", Vector3(0.0, -0.22, -0.08), Vector2(0.09, 0.12)],
	["l_shoulder", Vector3(0.02, -0.12, -0.06), Vector2(0.08, 0.1)],
	["spine", Vector3(-0.12, 0.12, -0.13), Vector2(0.1, 0.07)],
	["r_knee", Vector3(0.0, -0.15, -0.065), Vector2(0.08, 0.1)],
	["head", Vector3(0.06, 0.12, -0.1), Vector2(0.05, 0.03)],
]
## The same spots on a body with no rig (from the feet, facing -Z).
const BODY_SPOTS := [
	Vector3(0.1, 1.3, -0.3), Vector3(0.08, 0.6, -0.25), Vector3(-0.2, 1.4, -0.22),
	Vector3(-0.12, 1.15, -0.3), Vector3(0.1, 0.35, -0.2), Vector3(0.05, 1.75, -0.22),
]
const CLOTH := Color(0.06, 0.05, 0.05)
const BLOOD := Color(0.42, 0.04, 0.03)
const SCORCH := Color(0.03, 0.03, 0.03)
const SPARK := Color(1.0, 0.8, 0.35)

var kind := Kind.FLESH
## 0 unhurt .. 1 nearly beaten. Set it as the entity takes damage.
var severity := 0.0:
	set(v):
		severity = clampf(v, 0.0, 1.0)
		_update()

var entity: Node3D
var _marks: Array[Node3D] = []
var _sparks: CPUParticles3D
var _built_on: Node


static func attach(to: Node3D, wound_kind: Kind = Kind.FLESH) -> Injuries:
	var w := Injuries.new()
	w.name = "Injuries"
	w.kind = wound_kind
	w.entity = to
	to.add_child(w)
	return w


func _ready() -> void:
	# After the rig has posed for this frame, so the limp lands on top of it.
	process_priority = 10


## How fast it can move now, as a share of its full speed.
func speed_scale() -> float:
	return 1.0 - LIMP * severity


## How many marks show at this severity.
func shown() -> int:
	return _marks.filter(func(m): return m.visible).size()


func _rig() -> Node:
	return entity.get_node_or_null("Rig") if entity else null


## Make the marks on whatever the entity is drawn with right now (a rig can be
## added after the entity is built, by its level's dressing).
func _build() -> void:
	var rig := _rig()
	var on: Node = rig if rig else entity.get("_body")
	if on == null or on == _built_on:
		return
	for m in _marks:
		m.queue_free()
	_marks.clear()
	_built_on = on
	for i in SPOTS.size():
		var parent: Node3D
		var at: Vector3
		if rig:
			parent = rig.joints.get(SPOTS[i][0])
			at = SPOTS[i][1]
		else:
			parent = on
			at = BODY_SPOTS[i]
		if parent == null:
			continue
		_marks.append(_mark(parent, at, SPOTS[i][2], i))
	if kind == Kind.MACHINE:
		_sparks = _make_sparks(_marks[0].get_parent() if not _marks.is_empty() else entity)


## One wound: a dark tear (or scorch) with blood around it on a person.
func _mark(parent: Node3D, at: Vector3, size: Vector2, i: int) -> Node3D:
	var m := Node3D.new()
	m.name = "Wound%d" % i
	m.position = at
	m.visible = false
	parent.add_child(m)
	var tear := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	tear.mesh = q
	tear.rotation = Vector3(0, PI, 0.6 * (i % 3 - 1))  # face out the front, each at its own slant
	tear.material_override = Greybox.mat(SCORCH if kind == Kind.MACHINE else CLOTH, 0.0, 1.0)
	m.add_child(tear)
	if kind == Kind.FLESH:
		var blood := MeshInstance3D.new()
		var b := QuadMesh.new()
		b.size = size * 0.6
		blood.mesh = b
		blood.position = Vector3(0.012, -size.y * 0.35, -0.004)
		blood.rotation = tear.rotation
		blood.material_override = Greybox.mat(BLOOD, 0.0, 0.4)
		m.add_child(blood)
	return m


func _make_sparks(parent: Node3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Sparks"
	p.emitting = false
	p.amount = 24
	p.lifetime = 0.5
	p.explosiveness = 0.6
	p.direction = Vector3(0, 1, -1)
	p.spread = 50.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = SPARK
	mat.emission_enabled = true
	mat.emission = SPARK
	p.material_override = mat
	parent.add_child(p)
	return p


func _update() -> void:
	if not is_inside_tree():
		return
	_build()
	# Marks come in at even steps: the first at a light hit, all of them near the end.
	var n := int(floor(severity * (_marks.size() + 0.5)))
	for i in _marks.size():
		_marks[i].visible = i < n
	if _sparks:
		_sparks.emitting = severity > 0.25
		_sparks.amount = 8 + int(32 * severity)


func _process(_delta: float) -> void:
	if severity <= 0.0:
		return
	if _built_on == null or not is_instance_valid(_built_on) or (_rig() and _built_on != _rig()):
		_update()
	_limp()


## The bad leg: the hips drop and tilt on its step, more as it gets worse. Only
## while walking, and set from the rig's own pose so it never adds up.
func _limp() -> void:
	var rig := _rig()
	if rig == null or rig.is_full_body():
		return
	var speed: float = rig.current_speed()
	if speed < 0.3:
		return
	var step := maxf(0.0, sin(rig._phase))
	var hips: Node3D = rig.joints.get("hips")
	if hips:
		var base: Vector3 = rig._pose.get("hips", Vector3.ZERO)
		hips.rotation = base + Vector3(0, 0, LIMP_TILT * severity * step)
	rig.position.y = rig._root_pos.y - 0.05 * severity * step
