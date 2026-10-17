class_name Level2FX
## What the security wing does when you act on it, seen and heard instead of told:
## glass bursts into shards, a grate clatters down, a breaker thunks.
## Sounds are made in code until the audio pass brings real ones.

const RATE := 22050
## How long the exit car's drop lasts.
const DROP_TIME := 1.6
## How long the end card holds, after fading in.
const CARD_TIME := 3.5


## A short sound at `pos`: "glass", "clunk" (heavy, a bolt or a motor), "click",
## "clatter" or "tap" (one knock on a metal door).
static func sound(parent: Node, pos: Vector3, kind: String) -> void:
	if not parent.is_inside_tree():
		return
	# What played where, for the tests (a played sound frees itself).
	var played: Array = parent.get_meta("sounds_played", [])
	played.append({"kind": kind, "pos": pos})
	parent.set_meta("sounds_played", played)
	var p := AudioStreamPlayer3D.new()
	p.stream = _make(kind)
	p.name = "Sound_" + kind
	p.position = pos
	p.unit_size = 6.0
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Shards of a pane spill out and drop to the floor, then fade.
static func shards(parent: Node, center: Vector3, size: Vector3, color: Color, floor_y: float = 0.0) -> void:
	if not parent.is_inside_tree():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(center)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	for i in 14:
		var s := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.03, 0.12), rng.randf_range(0.03, 0.12), 0.006)
		s.mesh = bm
		s.material_override = m
		s.position = center + Vector3(rng.randf_range(-0.5, 0.5) * size.x, rng.randf_range(-0.5, 0.5) * size.y, rng.randf_range(-0.5, 0.5) * size.z)
		s.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		parent.add_child(s)
		var land := Vector3(s.position.x + rng.randf_range(-0.35, 0.35), floor_y + 0.01, s.position.z + rng.randf_range(-0.35, 0.35))
		var t := s.create_tween()
		t.tween_property(s, "position", land, rng.randf_range(0.25, 0.5)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t.parallel().tween_property(s, "rotation", Vector3(PI / 2, rng.randf() * TAU, 0), 0.4)
		t.tween_interval(6.0)
		t.tween_callback(s.queue_free)


## Moves `node` to `to_pos` / `to_rot` the way a dropped thing falls.
static func drop(node: Node3D, to_pos: Vector3, to_rot: Vector3, seconds: float = 0.45) -> void:
	if not node.is_inside_tree():
		node.position = to_pos
		node.rotation = to_rot
		return
	var t := node.create_tween()
	t.tween_property(node, "position", to_pos, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(node, "rotation", to_rot, seconds)


static func _make(kind: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var secs: float = {"glass": 0.6, "clunk": 0.35, "click": 0.06, "clatter": 0.7, "tap": 0.9}.get(kind, 0.3)
	var n := int(secs * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var low := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		match kind:
			"glass":
				# Bright noise with high rings, gone fast.
				v = (rng.randf_range(-1, 1) * 0.6 + sin(TAU * 3100 * t) * 0.25 + sin(TAU * 4700 * t) * 0.15) * exp(-t * 9.0)
			"clunk":
				# A low thud: filtered noise and a falling tone.
				low = lerpf(low, rng.randf_range(-1, 1), 0.08)
				v = (low * 1.5 + sin(TAU * (90 - 40 * t) * t) * 0.7) * exp(-t * 14.0)
			"click":
				v = rng.randf_range(-1, 1) * exp(-t * 120.0)
			"clatter":
				# Sheet metal hitting the floor, twice.
				var hit := exp(-t * 12.0) + (exp(-(t - 0.22) * 16.0) * 0.6 if t > 0.22 else 0.0)
				v = (rng.randf_range(-1, 1) * 0.5 + sin(TAU * 620 * t) * 0.3 + sin(TAU * 1330 * t) * 0.2) * hit
			"tap":
				# A knuckle on a steel door: a sharp knock and a long, low ring.
				v = rng.randf_range(-1, 1) * exp(-t * 90.0) * 0.8 + (sin(TAU * 210 * t) * 0.5 + sin(TAU * 537 * t) * 0.25) * exp(-t * 4.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


## The exit car drops: its light stutters and the floor jolts under the player's feet.
static func drop_car(car: Elevator, player: Node3D) -> void:
	if not car.is_inside_tree():
		return
	var t := car.create_tween()
	for e in [0.15, 1.0, 0.05, 0.7, 0.0, 0.4, 0.0]:
		t.tween_method(car._set_car_light, 1.0 if e == 0.15 else e, e, DROP_TIME / 7.0)
	var head: Node3D = player.get("head") if player else null
	if head:
		var rest := head.position
		var j := player.create_tween()
		j.tween_property(head, "position", rest + Vector3(0, -0.12, 0), 0.08)
		j.tween_property(head, "position", rest + Vector3(0, -0.04, 0), 0.25)
		j.tween_property(head, "position", rest, DROP_TIME - 0.33)


## A black card over everything with one line on it. Returns when it has held.
static func end_card(parent: Node, text: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = "EndCard"
	layer.layer = 24  # under Field Notes, over the HUD
	parent.add_child(layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.modulate.a = 0.0
	layer.add_child(black)
	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	black.add_child(label)
	var t := layer.create_tween()
	t.tween_property(black, "modulate:a", 1.0, 0.6)
	t.tween_interval(CARD_TIME)
	await t.finished
