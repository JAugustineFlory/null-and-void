class_name Level2Glass
extends StaticBody3D
## A pane of window glass in the security wing. Players can see through it.
## A breakable pane shatters when someone strikes it. Wired security glass doesn't.

signal broken(by: Node)

var breakable := true
## What a strike on unbreakable glass tells the player.
var refusal := "Wired security glass. It doesn't even crack."
var hud: HUD


static func create(parent: Node, center: Vector3, size: Vector3, can_break: bool) -> Level2Glass:
	var g := Level2Glass.new()
	g.name = "Glass"
	g.breakable = can_break
	g.position = center
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.75, 0.8, 0.18) if can_break else Color(0.55, 0.7, 0.72, 0.24)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	mesh.material_override = m
	g.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	g.add_child(shape)
	parent.add_child(g)
	return g


## Looking at the glass says plainly what to do with it.
func get_prompt(_player: Node) -> String:
	return "[Click] Strike to break the glass" if breakable else "Wired security glass"


func interact(_player: Node) -> void:
	if hud:
		hud.notice("Strike it (click) to break it." if breakable else refusal, 3.0)


## Called by the player's strike.
func take_hit(by: Node) -> void:
	if not breakable:
		if hud:
			hud.notice(refusal, 3.0)
		return
	shatter(by)


func shatter(by: Node = null) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	broken.emit(by)
	queue_free()
