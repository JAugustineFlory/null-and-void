class_name SightCloud
extends Node3D
## A fire extinguisher's cloud (Counterplay): white powder hanging in the air for a
## few seconds. Nothing sees through it, players or enemies: blocks() says whether a
## line of sight passes through one. It thins out and is gone after `time`.

var radius := 1.4
var time := 4.0
var _age := 0.0
var _mat: StandardMaterial3D


static func make(parent: Node, at: Vector3, r: float, t: float) -> SightCloud:
	var c := SightCloud.new()
	c.radius = r
	c.time = t
	c.position = (parent as Node3D).to_local(at) if parent is Node3D else at
	parent.add_child(c)
	return c


func _ready() -> void:
	add_to_group("sight_cloud")
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 1.6
	mesh.mesh = sphere
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.92, 0.93, 0.95, 0.85)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = _mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


func _process(delta: float) -> void:
	_age += delta
	if _mat:
		_mat.albedo_color.a = 0.85 * clampf(1.0 - (_age - time * 0.6) / (time * 0.4), 0.0, 1.0)
	if _age >= time:
		queue_free()


## Still thick enough to hide what's behind it.
func is_thick() -> bool:
	return _age < time * 0.9 and not is_queued_for_deletion()


## Does the line from `from` to `to` (world space) pass through a cloud in `world`?
static func blocks(world_node: Node, from: Vector3, to: Vector3) -> bool:
	if not world_node.is_inside_tree():
		return false
	for c in world_node.get_tree().get_nodes_in_group("sight_cloud"):
		if not c is SightCloud or not c.is_thick() or c.get_viewport() != world_node.get_viewport():
			continue
		var at: Vector3 = c.global_position
		if Geometry3D.get_closest_point_to_segment(at, from, to).distance_to(at) < c.radius:
			return true
	return false
