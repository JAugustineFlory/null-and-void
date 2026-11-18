class_name Spectate
extends Camera3D
## Hard mode, dead: you watch a living teammate from over their shoulder
## (plan/hard-mode.md, call 4). LB / RB, or the mouse buttons, switch who. You
## can't touch anything; your body stays lying where you died. NetPlayers starts
## and stops it when CrewVitals says you died or came back.

## Approved word for word by Augustine, 2026-11-18 00:04Z (plan/hard-mode.md, 12).
const WATCHING := "You're dead. Watching %s."
const SWITCH := "LB / RB to switch"
## Over the shoulder: this far behind their head, to the right, and above it.
const BACK := 2.2
const SIDE := 0.45
const UP := 0.3
## Keep this far off any wall the camera would sit in.
const WALL_GAP := 0.2
const FOLLOW_RATE := 10.0

var players: Node  # NetPlayers
## The peer id being watched (0: nobody left standing).
var watching := 0
var _layer: CanvasLayer
var _who: Label
var _snap := true


static func create(net_players: Node) -> Spectate:
	var s := Spectate.new()
	s.name = "Spectate"
	s.players = net_players
	s.near = 0.05
	s.far = 400.0
	net_players.add_child(s)
	return s


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_top = -96.0
	box.offset_bottom = -40.0
	box.offset_left = -300.0
	box.offset_right = 300.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(box)
	_who = _label(22, Color(1, 1, 1, 0.92))
	box.add_child(_who)
	box.add_child(_label(16, Color(1, 1, 1, 0.6), SWITCH))
	watch(_first())
	make_current()


func _label(font_size: int, color: Color, text := "") -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Who can be watched: everyone else still alive, in player order.
func candidates() -> Array:
	var me := multiplayer.get_unique_id()
	return players.all_ids().filter(func(id): return id != me and players.puppet(id) != null and not players.is_dead(id))


func _first() -> int:
	var c := candidates()
	return c[0] if not c.is_empty() else 0


## Watch player `id` (0: nobody).
func watch(id: int) -> void:
	if id == watching and _who.text != "":
		return
	watching = id
	_snap = true
	var body: Node = players.puppet(id) if id != 0 else null
	_who.text = WATCHING % body.get("display_name") if body else ""


## Next (1) or previous (-1) living teammate.
func cycle(step: int) -> void:
	var c := candidates()
	if c.is_empty():
		watch(0)
		return
	var at := c.find(watching)
	watch(c[posmod(at + step, c.size())] if at != -1 else c[0])


## Back to your own eyes (you came back, or the floor starts over).
func stop() -> void:
	var cam: Camera3D = players.player.get("camera") if is_instance_valid(players.player) else null
	if cam:
		cam.make_current()
	clear_current(false)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var step := 0
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			step = 1
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			step = -1
	if step != 0:
		cycle(step)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var body: Node3D = players.puppet(watching) if watching != 0 else null
	if body == null or players.is_dead(watching):
		cycle(1)  # they died or left: on to someone still standing
		body = players.puppet(watching) if watching != 0 else null
		if body == null:
			return
	var want := shoulder_of(body)
	if _snap:
		global_transform = want
		_snap = false
	else:
		var k := clampf(delta * FOLLOW_RATE, 0.0, 1.0)
		global_transform = global_transform.interpolate_with(want, k)


## Where the camera sits to watch `body`: behind and above their head, looking
## the way they look, pulled in short of any wall in between.
func shoulder_of(body: Node3D) -> Transform3D:
	var height: float = body.get("stance_height") if body.get("stance_height") != null else 1.8
	var size: float = body.get("size") if body.get("size") != null else 1.0
	var head := body.global_position + Vector3.UP * (height - 0.18) * size
	var turn := Basis(Vector3.UP, body.global_rotation.y)
	var rig = body.get("rig")
	var pitch: float = rig.head_pitch if rig else 0.0
	var spot := head + turn * Vector3(SIDE, UP, BACK)
	var hit := _wall_between(head, spot, body)
	if not hit.is_empty():
		spot = hit.position + (head - spot).normalized() * WALL_GAP
	var ahead: Vector3 = head + turn * Basis(Vector3.RIGHT, pitch * 0.6) * Vector3(0, 0, -6.0)
	return Transform3D(Basis.looking_at(ahead - spot, Vector3.UP), spot)


func _wall_between(from: Vector3, to: Vector3, body: Node3D) -> Dictionary:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var skip: Array[RID] = []
	for b in players.all_players():
		if b is CollisionObject3D:
			skip.append(b.get_rid())
	q.exclude = skip
	return space.intersect_ray(q)
