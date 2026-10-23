class_name Level2FX
## What the security wing does when you act on it, seen and heard instead of told:
## glass bursts into shards, a grate clatters down, a breaker thunks.

const RATE := 22050
## How long the end card holds, after fading in.
const CARD_TIME := 3.5


## A short sound at `pos`: "glass", "clunk" (heavy, a bolt or a motor), "click",
## "clatter" or "tap" (one knock on a metal door). See Sfx for the rest.
static func sound(parent: Node, pos: Vector3, kind: String) -> void:
	Sfx.play(parent, kind, pos)


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


## Wind high up the side of a tower: a looping rush of low noise with slow gusts.
static func wind() -> AudioStreamWAV:
	const SECS := 6.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wind")
	var n := int(SECS * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var low := 0.0
	var lower := 0.0
	for i in n:
		var t := float(i) / RATE
		low = lerpf(low, rng.randf_range(-1, 1), 0.05)
		lower = lerpf(lower, low, 0.02)
		# Whole cycles in SECS, so the loop has no seam.
		var gust := 0.55 + 0.3 * sin(TAU * t / SECS) + 0.15 * sin(TAU * 3.0 * t / SECS + 1.3)
		var v := (lower * 4.0 + low * 0.6) * gust
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w


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
