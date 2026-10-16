extends RefCounted
## Graphics and animation tests: the character rig animates from movement and
## actions, props and moods build, materials are shared, and the budgets in
## docs/art/style-guide.md hold.

var t: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("Art")
	test_materials_are_shared()
	test_moods()
	await test_rig_walks_from_movement()
	await test_rig_actions()
	await test_rig_budget()
	await test_props()
	await test_held_items()
	await test_gallery()
	await test_dressed_level_0()
	await test_dressed_level_1()
	test_sticky_notes()
	test_elevator()
	await test_notebook()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func test_materials_are_shared() -> void:
	var a := ArtPalette.surface("carpet")
	check(a == ArtPalette.surface("carpet"), "the same surface returns one shared material")
	check(a.albedo_texture != null and a.uv1_world_triplanar, "surfaces are textured in world space")
	check(ArtPalette.flat(Color.RED) == ArtPalette.flat(Color.RED), "flat materials are shared")
	var tex := ArtPalette.texture("tiles")
	var img := tex.get_image()
	check(img.get_width() == ArtPalette.TEX_SIZE and img.get_pixel(0, 0).r < img.get_pixel(64, 64).r, "ceiling tiles have darker grout at the edges")
	var hues := {}
	for c in ArtPalette.CREW_COLORS:
		hues[snappedf(c.h, 0.05)] = true
	check(ArtPalette.CREW_COLORS.size() == 6 and hues.size() == 6, "six crew colors with six different hues")


func test_moods() -> void:
	var env := ArtMood.environment("office")
	var office_ambient := env.ambient_light_energy
	ArtMood.apply(env, "dark")
	check(env.ambient_light_energy < office_ambient * 0.2, "the dark mood is much darker than the office")
	check(ArtMood.get_mood("office").vhs < 0.15, "the office (Level 0) keeps the VHS look faint")
	var l := OmniLight3D.new()
	l.light_energy = 1.5
	ArtMood.apply_to_lights([l], "lockdown")
	check(l.light_color == ArtPalette.LIGHT_EMERGENCY, "lockdown turns ceiling lights red")
	ArtMood.apply_to_lights([l], "office")
	check(is_equal_approx(l.light_energy, 1.5), "going back to the office restores each light's own energy")
	l.free()


func _stage() -> Node3D:
	var n := Node3D.new()
	t.root.add_child(n)
	return n


func _frames(n: int) -> void:
	for i in n:
		await t.physics_frame


func test_rig_walks_from_movement() -> void:
	var stage := _stage()
	var holder := Node3D.new()
	stage.add_child(holder)
	var rig := CharacterRig.build(holder, CharacterLooks.rourke())
	rig.set_process(false)
	for i in 30:
		rig.animate(1.0 / 60.0)
	var still_leg: float = rig.joints["r_hip"].rotation.x
	check(absf(still_leg) < 0.05 and rig.current_speed() < 0.05, "standing still, the legs stay together")
	var max_swing := 0.0
	for i in 90:
		holder.position.z -= 1.9 / 60.0
		rig.animate(1.0 / 60.0)
		max_swing = maxf(max_swing, absf(rig.joints["r_hip"].rotation.x))
	check(rig.current_speed() > 1.6 and rig.current_speed() < 2.2, "the rig measures walking speed from its movement (%.2f m/s)" % rig.current_speed())
	check(max_swing > 0.3, "walking swings the legs")
	holder.position.z -= 50.0
	rig.animate(1.0 / 60.0)
	check(rig.current_speed() < 2.5, "a teleport is not read as a sprint")
	stage.free()


func test_rig_actions() -> void:
	var stage := _stage()
	var holder := Node3D.new()
	stage.add_child(holder)
	var rig := CharacterRig.build(holder, CharacterLooks.crew(0))
	rig.set_process(false)
	rig.play("wave")
	for i in 40:
		rig.animate(1.0 / 60.0)
	check(rig.joints["r_shoulder"].rotation.z > 2.0, "wave raises the right arm")
	rig.play("down")
	for i in 90:
		rig.animate(1.0 / 60.0)
	check(rig.rotation.x > 1.4 and rig.position.y < 0.3, "down lays the body flat")
	check(rig.is_full_body(), "down is a full-body action")
	rig.play("talk")
	rig.speed_override = 1.9
	for i in 90:
		rig.animate(1.0 / 60.0)
	check(absf(rig.rotation.x) < 0.1, "getting up stands the body back up")
	var swing := 0.0
	for i in 60:
		rig.animate(1.0 / 60.0)
		swing = maxf(swing, absf(rig.joints["l_hip"].rotation.x))
	check(swing > 0.3, "upper-body actions keep the legs walking")
	rig.play("idle")
	rig.speed_override = 0.0
	rig.crouching = true
	for i in 90:
		rig.animate(1.0 / 60.0)
	var crouch_top: float = rig.joints["head"].global_position.y + 0.25 * rig.scale.y
	check(absf(crouch_top - 1.25) < 0.12, "crouching stands 1.25 m tall, like the player (%.2f m)" % crouch_top)
	var feet: float = rig.joints["r_knee"].to_global(Vector3(0, -0.44, 0)).y
	check(absf(feet) < 0.1, "and keeps the feet on the floor (%.2f m)" % feet)
	rig.crouching = false
	rig.crawling = true
	for i in 90:
		rig.animate(1.0 / 60.0)
	var head_y: float = rig.joints["head"].global_position.y
	check(head_y < 0.9 and rig.joints["r_elbow"].to_global(Vector3(0, -0.3, 0)).y < 0.15, "crawling puts him on hands and knees, low enough for a vent (head %.2f m)" % head_y)
	rig.crawling = false
	# Movement's crouch height follows the clearance overhead: the pose follows it smoothly.
	var tops: Array[float] = []
	var lowest := 0.0
	for h in [1.8, 1.6, 1.4, 1.25, 1.15, 1.05, 0.95, 0.85]:
		rig.stance_height = h
		for i in 120:
			rig.animate(1.0 / 60.0)
		var top := -INF
		for j in rig.joints:
			var n: Node3D = rig.joints[j]
			top = maxf(top, n.global_position.y)
			lowest = minf(lowest, n.global_position.y)
		top = maxf(top, rig.joints["head"].to_global(Vector3(0, 0.25, 0)).y)
		tops.append(top)
	var shrinking := true
	for i in range(1, tops.size()):
		shrinking = shrinking and tops[i] <= tops[i - 1] + 0.03
	check(shrinking, "as the gap gets lower, the body gets lower, with no pop between crouch and crawl")
	var fits := true
	for i in tops.size():
		fits = fits and tops[i] <= [1.8, 1.6, 1.4, 1.25, 1.15, 1.05, 0.95, 0.85][i] + 0.15
	check(fits, "at every height in between, the body fits the space it's under")
	check(lowest > -0.12, "and never sinks into the floor (%.2f m)" % lowest)
	rig.stance_height = -1.0
	rig.play("not_a_thing")
	check(rig.action == "idle", "unknown actions fall back to idle")
	rig.play("idle")
	rig.speed_override = 0.0
	rig.look_target = holder.global_position + Vector3(3, 1.6, 0)
	for i in 60:
		rig.animate(1.0 / 60.0)
	check(rig.joints["head"].rotation.y < -0.5, "the head turns toward a look target")
	stage.free()


func test_rig_budget() -> void:
	var stage := _stage()
	var looks := [CharacterLooks.rourke(), CharacterLooks.vale(), CharacterLooks.mercer(), CharacterLooks.night_guard()]
	for i in 6:
		looks.append(CharacterLooks.crew(i))
	var most := 0
	var shadow_parts := 0
	for look in looks:
		var n := Node3D.new()
		stage.add_child(n)
		var rig := CharacterRig.build(n, look)
		most = maxi(most, rig.part_count())
		for mi in rig.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadow_parts += 1
	check(most <= 32, "every character stays within 32 mesh pieces (most: %d)" % most)
	check(shadow_parts <= looks.size() * 12, "only the big body parts cast shadows")
	var a := CharacterRig.build(Node3D.new(), CharacterLooks.crew(0))
	var b := CharacterRig.build(Node3D.new(), CharacterLooks.crew(0))
	var ma: MeshInstance3D = a.joints["head"].get_child(0)
	var mb: MeshInstance3D = b.joints["head"].get_child(0)
	check(ma.mesh == mb.mesh and ma.material_override == mb.material_override, "rigs share meshes and materials")
	a.get_parent().free()
	b.get_parent().free()
	stage.free()


func test_props() -> void:
	var stage := _stage()
	var desk := ArtProps.desk(stage, Vector3.ZERO)
	check(desk is StaticBody3D and desk.get_child_count() > 1, "a desk is solid")
	var rack := ArtProps.server_rack(stage, Vector3(2, 0, 0), 90)
	check(is_equal_approx(rack.rotation_degrees.y, 90.0), "props turn to face the way they're placed")
	var light := ArtProps.troffer(stage, Vector3(0, 3, 0))
	var diffuser: MeshInstance3D = light.get_node("Diffuser")
	ArtMood.apply_to_lights([light], "dark")
	check(not (diffuser.material_override as StandardMaterial3D).emission_enabled, "in the dark mood, light panels stop glowing")
	ArtMood.apply_to_lights([light], "office")
	light.visible = false
	check(not diffuser.is_visible_in_tree(), "a troffer's glow goes dark with its light")
	var f := PropFlashlight.create(stage)
	check(f.light.visible and not f.light.shadow_enabled, "teammates' flashlights skip shadows")
	f.toggle()
	check(not f.light.visible, "the flashlight switches off")
	var w := PropWalkie.create(stage)
	w.set_transmitting(true)
	check((w.led.material_override as StandardMaterial3D).emission_enabled, "the walkie's LED lights while talking")
	stage.free()


func test_held_items() -> void:
	var stage := _stage()
	var cam := Camera3D.new()
	stage.add_child(cam)
	var held := HeldItems.attach(cam, CharacterLooks.crew(1))
	check(held.flashlight.light.shadow_enabled, "your own flashlight casts shadows")
	held.raise_walkie(true)
	for i in 30:
		await t.process_frame
	check(held.left_hand.visible and held.left_hand.position.y > -0.2, "the walkie comes up while you talk")
	held.raise_walkie(false)
	for i in 30:
		await t.process_frame
	check(not held.left_hand.visible, "and goes back down after")
	stage.free()


func test_gallery() -> void:
	var g: Node3D = load("res://scenes/art_gallery.tscn").instantiate()
	t.root.add_child(g)
	await _frames(5)
	check(g.rigs.size() == 11, "the art gallery shows the whole cast")
	g.set_mood("lockdown")
	check(is_equal_approx(g.vhs.intensity, ArtMood.get_mood("lockdown").vhs), "gallery moods drive the VHS overlay")
	g.vhs.intensity = 0.0
	check(not g.vhs.rect.visible, "a VHS intensity of 0 turns the overlay off entirely")
	g.free()


## Every prop the dressing added, as world-space boxes.
func _prop_boxes(level: Node) -> Array[AABB]:
	var out: Array[AABB] = []
	for body in level.geo.get_children():
		if not body.has_meta("art_prop"):
			continue
		for c in body.get_children():
			if c is CollisionShape3D:
				var size: Vector3 = (c.shape as BoxShape3D).size
				var xf: Transform3D = c.global_transform
				out.append(xf * AABB(-size / 2.0, size))
	return out


## Points (level-local) that must stay clear of props, with room to stand.
func _blocked(level: Node, boxes: Array[AABB], points: Array) -> Array:
	var hits := []
	for p in points:
		var gp: Vector3 = level.to_global(p)
		var probe := AABB(gp - Vector3(0.45, 0, 0.45), Vector3(0.9, 1.6, 0.9))
		for b in boxes:
			if b.intersects(probe):
				hits.append(p)
				break
	return hits


func test_dressed_level_0() -> void:
	var level = load("res://scenes/level_0.tscn").instantiate()
	t.root.add_child(level)
	await _frames(10)
	var boxes := _prop_boxes(level)
	check(boxes.size() >= 10, "Level 0 is furnished (%d solid props)" % boxes.size())
	var keep_clear := [
		Vector3(0, 0, 8.8), Vector3(-0.5, 0, 0.6), Vector3(10.2, 0, 3), Vector3(0, 0, 5.6),  # Rourke's stops, respawn
		Vector3(1.5, 0, -0.2), Vector3(-1.5, 0, -0.2),  # in front of the terminal and visitor log
		Vector3(-2.5, 0, -4.7), Vector3(0, 0, -2.2),  # walkies, and landing over the desk
		Vector3(-7.4, 0, 4), Vector3(-14.6, 0, 4), Vector3(-18.6, 0, 4.5),  # vent mouth, closet side, the tape
		Vector3(-0.1, 0, 14.8), Vector3(4.1, 0, 14.8), Vector3(0, 0, 11.5),  # out of the van, to the doors
	]
	var blocked := _blocked(level, boxes, keep_clear)
	check(blocked.is_empty(), "props keep Level 0's routes and puzzles clear %s" % [blocked])
	var floor_mat: Material = null
	for b in level.geo.get_children():
		if b.name.begins_with("Floor") and absf(b.position.x) < 1 and absf(b.position.z) < 1:
			floor_mat = b.get_child(0).material_override
	check(floor_mat == ArtPalette.surface("carpet"), "the lobby floor is carpeted")
	var look: NpcLook = level.rourke.get_node_or_null("Look")
	check(look != null and not level.rourke._body.visible, "Rourke wears his character model")
	check(look.pick_action() == "idle", "Rourke stands at ease before the turn")
	var lit := 0
	for l in level.lights["lobby"]:
		if l.get_node_or_null("PanelLink"):
			lit += 1
	check(lit == level.lights["lobby"].size(), "every lobby light panel follows its light")
	level.free()


func test_dressed_level_1() -> void:
	t.root.get_node("Game").new_run(7)
	var level = load("res://scenes/level_1.tscn").instantiate()
	t.root.add_child(level)
	await _frames(10)
	var keep_clear := [Vector3(0, 0, 12.6), Vector3(0, 0, 6.0), Vector3(-4.5, 0, 7.4), Vector3(0, 0, -8.0), Vector3(0, 0, 10.5)]
	for z in [-6.0, -3.0, 0.0, 3.0]:
		for side in [-1, 1]:
			keep_clear.append(Vector3(side * 1.3, 0, z))  # in front of every reset panel
	var blocked := _blocked(level, _prop_boxes(level), keep_clear)
	check(blocked.is_empty(), "props keep Server Room A's aisles, panels and terminal clear %s" % [blocked])
	var light: OmniLight3D = level.lights["room"][0]
	var panel: MeshInstance3D = light.get_node("PanelLink").panel
	level.set_all_lights_color(Color(1.0, 0.18, 0.12))
	light.get_node("PanelLink").refresh()
	var m := panel.material_override as StandardMaterial3D
	check(m.emission_enabled and m.emission.r > 0.9 and m.emission.g < 0.3, "light panels turn red with the lockdown")
	light.visible = false
	light.get_node("PanelLink").refresh()
	check(not (panel.material_override as StandardMaterial3D).emission_enabled, "a light switched off in the lights table goes dark")
	var look: NpcLook = level.rourke.get_node("Look")
	level.rourke.state = Rourke.State.CHASE
	level.rourke._go_down()
	check(look.pick_action() == "down", "Rourke's model falls when he goes down")
	level.rourke.state = Rourke.State.TIED
	check(look.pick_action() == "tied", "and shows him tied up")
	level.free()


func test_sticky_notes() -> void:
	var stage := _stage()
	var a := ArtProps.sticky_note(stage, Vector3.ZERO, 0, "WHERE")
	var b := ArtProps.sticky_note(stage, Vector3(1, 0, 0), 0, "ORDER BY", ArtProps.STICKY_YELLOW, true)
	var paper: MeshInstance3D = a.find_child("Paper", true, false)
	check(paper != null and (paper.mesh as BoxMesh).size.x < 0.08, "a sticky note is sticky-note sized")
	check(paper.material_override == (b.find_child("Paper", true, false) as MeshInstance3D).material_override, "sticky notes of one color share a material")
	check((paper.material_override as StandardMaterial3D).emission_enabled, "sticky notes glow faintly so they can be spotted")
	var label: Label3D = b.find_child("Text", true, false)
	check(label.text == "ORDER BY" and label.font != null, "a sticky note shows its keyword in handwriting")
	var up := (label.global_transform.basis * Vector3(0, 0, 1)).normalized()
	check(up.y > 0.9, "a note laid on a desk faces up")
	stage.free()


func test_elevator() -> void:
	var stage := _stage()
	var lift := ArtElevator.build(stage, Vector3.ZERO, 0.0, Vector3(2.6, 2.5, 2.2), ["2", "1", "B1"])
	var shut := lift.door_offsets()
	check(shut.size() == 2 and absf(shut[0] - shut[1]) < 0.7, "the elevator doors meet in the middle when shut")
	lift.open_amount = 1.0
	var open := lift.door_offsets()
	check(absf(open[0]) > 0.8 and absf(open[1]) > 0.8, "open, both doors slide clear of the 1.2 m doorway")
	lift.open_amount = 3.0
	check(lift.open_amount == 1.0, "open_amount stays between 0 and 1")
	lift.set_floor("B1")
	lift.set_direction(-1)
	check(lift.get_floor() == "B1", "the floor indicator shows the floor")
	lift.light_button("B1")
	check(lift.is_button_lit("B1") and not lift.is_button_lit("2"), "pressing a floor lights only its button")
	var pieces := 0
	for n in lift.find_children("*", "MeshInstance3D", true, false):
		pieces += 1
	check(pieces <= 48, "the elevator stays within its piece budget (%d)" % pieces)
	check(lift.find_children("*", "CollisionShape3D", true, false).is_empty(), "the elevator model adds no collision (mechanics own it)")
	lift.set_car_light(0.0)
	check(not (lift.get_node("CarLight") as OmniLight3D).visible, "the car light can be cut")
	stage.free()


func test_notebook() -> void:
	check(NotebookArt.hand_font() is Font and NotebookArt.type_font() is Font, "the notebook fonts load")
	check(NotebookArt.hand_font() is FontFile, "the handwriting font ships with the game, not the system")
	var layer := CanvasLayer.new()
	t.root.add_child(layer)
	var book := NotebookView.new()
	layer.add_child(book)
	var pressed := []
	book.tab_pressed.connect(func(n): pressed.append(n))
	book.add_tab("Notes")
	var tables := book.add_tab("Tables")
	tables.pressed.emit()
	check(pressed == ["Tables"], "notebook tabs report which one was clicked")
	book.left.add_child(NotebookArt.sticky("SELECT", "SELECT columns FROM table;", "SELECT name FROM rooms;"))
	book.right.add_child(NotebookArt.table_card("doors", ["door_id", "locked"]))
	book.show_book()
	await t.create_timer(0.4).timeout
	check(book.visible and book.modulate.a > 0.99, "the notebook opens")
	check(book.book.get_global_rect().size.x <= book.get_viewport_rect().size.x + 1, "the open book fits on screen")
	book.clear_pages()
	await t.process_frame
	check(book.left.get_child_count() == 0 and book.right.get_child_count() == 0, "pages clear for the next section")
	book.hide_book()
	await t.create_timer(0.3).timeout
	check(not book.visible, "the notebook closes")
	layer.free()
