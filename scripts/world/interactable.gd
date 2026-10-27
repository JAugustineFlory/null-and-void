class_name Interactable
extends StaticBody3D
## Something the player can look at and press E (or X) on.

signal used(player: Node)
signal alt_used(player: Node)
## A player aimed at it while it shone (once): the moment to say what the shine means.
signal shine_seen(player: Node)

var prompt := "Use"
var alt_prompt := ""
var enabled := true
## Co-op: act on this machine only, instead of asking the host (e.g. hopping a counter).
var local_only := false
## The shine over something still worth reading (see shine()).
const SHINE_COLOR := Color(1.0, 0.86, 0.45, 0.3)
## How much wider than the thing itself the shine spreads.
const SHINE_GROW := 1.35
## Seconds for the shine to fade down, and back up again.
const SHINE_BREATH := 1.1
var _shine: MeshInstance3D
## It has been read: no shine comes back.
var _shine_spent := false
## shine_seen has gone out.
var _shine_seen := false


static func create(parent: Node, center: Vector3, size: Vector3, prompt_text: String, color: Color = Color(0.3, 0.3, 0.3), visible_mesh: bool = true) -> Interactable:
	var it := Interactable.new()
	it.position = center
	it.prompt = prompt_text
	if visible_mesh:
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mesh.mesh = bm
		mesh.material_override = Greybox.mat(color)
		it.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	it.add_child(shape)
	parent.add_child(it)
	it.add_to_group("interactable")
	return it


## A shine over it while it still holds something this player needs, so a first-time
## player can see which things in the room are worth reading (Augustine, 2026-10-26:
## "showing how to find clues by making the papers/hints glow"). It's a soft panel
## just off the surface, breathing in and out; `shine(false)` takes it away, which is
## what reading the thing does. Each machine shines its own: it follows what this
## player has read, not the crew.
func shine(on: bool = true) -> void:
	if not on:
		if is_instance_valid(_shine):
			_shine.queue_free()
		_shine = null
		_shine_spent = true  # read once, so it never asks again
		return
	if is_instance_valid(_shine) or _shine_spent:
		return
	var box := _shine_box()
	var mesh := MeshInstance3D.new()
	mesh.name = "Shine"
	var quad := QuadMesh.new()
	# Flat on a desk: a panel over it. Standing up: a panel in front of it.
	var flat_up: bool = box.y <= box.x * 0.5 and box.y <= box.z * 0.5
	quad.size = Vector2(box.x, box.z) * SHINE_GROW if flat_up else Vector2(box.x, box.y) * SHINE_GROW
	mesh.mesh = quad
	if flat_up:
		mesh.rotation_degrees.x = -90.0
		mesh.position.y = box.y * 0.5 + 0.004
	else:
		mesh.position.z = box.z * 0.5 + 0.004
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = SHINE_COLOR
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = m
	add_child(mesh)
	_shine = mesh
	var tw := create_tween().set_loops()
	tw.tween_method(func(a: float): m.albedo_color.a = a, SHINE_COLOR.a, SHINE_COLOR.a * 0.35, SHINE_BREATH).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(a: float): m.albedo_color.a = a, SHINE_COLOR.a * 0.35, SHINE_COLOR.a, SHINE_BREATH).set_trans(Tween.TRANS_SINE)


## True while it's shining.
func shining() -> bool:
	return is_instance_valid(_shine)


## The prompt is only asked for by the player aiming at it, on their own machine, so
## that's when this player has seen it shine.
func _seen_shining(player: Node) -> void:
	if shining() and not _shine_seen:
		_shine_seen = true
		shine_seen.emit(player)


## The size of what's being shone on: its aim box.
func _shine_box() -> Vector3:
	for c in get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D:
			return (c.shape as BoxShape3D).size
	return Vector3(0.2, 0.2, 0.02)


func get_prompt(player: Node) -> String:
	_seen_shining(player)
	if not enabled:
		return ""
	var p := "[E] " + prompt
	if alt_prompt != "":
		p += "    [X] " + alt_prompt
	return p


## In co-op, a client's press is sent to the host, which decides what happens.
func interact(player: Node) -> void:
	if enabled and not _forwarded("interact"):
		used.emit(player)


func interact_alt(player: Node) -> void:
	if enabled and alt_prompt != "" and not _forwarded("interact_alt"):
		alt_used.emit(player)


func _forwarded(method: String) -> bool:
	if local_only:
		return false
	var sync := LevelSync.of(self)
	return sync != null and sync.forward(self, method)
