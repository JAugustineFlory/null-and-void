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
	test_document_props()
	await test_document_view()
	await test_held_notebook()
	await test_terminal_screen()


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
		Vector3(-0.3, 0, 14.8), Vector3(4.3, 0, 14.8), Vector3(4.3, 0, 15.5), Vector3(4.3, 0, 17.9), Vector3(0, 0, 11.5),  # out of the van (front doors, side door), to the doors
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
	var van: Node3D = level.get_node("Dressing/Van")
	check(van.find_children("Seat*", "Node3D", false, false).size() == 3, "the van has two front seats and a rear bench")
	check(van.find_child("SteeringWheel", true, false) != null, "and a steering wheel")
	var round := 0
	for w in DressVan.wheels(level.geo, Vector3(2, 0, 16.6)):
		round += 1 if not (w.get_child(0) as MeshInstance3D).visible else 0
	check(round == 4, "the van's wheels are round, not greybox blocks")
	for seat in level.van_seats:
		check((seat.buckle as Node3D).visible, "seat-belt buckles stay visible to ready up")
		break
	level.rourke._body.position.y = -0.45  # ducking under the hall's cable tray
	look._process(0.016)
	check(look.rig.stance_height < 1.4, "Rourke's model crouches when he ducks")
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
	var call: Node3D = lift.get_node("CallPanel")
	check(call.position.z < -0.1, "the call button sits in front of a Greybox wall centered on the doorway")
	# Inside the car, nothing above the doorway may sit in that wall either, or it flickers through it.
	var inside_ok := true
	for mi: MeshInstance3D in lift.find_children("*", "MeshInstance3D", true, false):
		var p := lift.to_local(mi.global_position)
		var depth: float = (mi.mesh as BoxMesh).size.z if mi.mesh is BoxMesh else 0.0
		if p.y > 2.1 and p.z > 0.0 and depth < 0.2 and p.z - depth / 2.0 < 0.1 - 0.001:
			inside_ok = false
	for l: Label3D in lift.find_children("*", "Label3D", true, false):
		var p := lift.to_local(l.global_position)
		if p.z > 0.0 and p.z < 0.1:
			inside_ok = false
	check(inside_ok, "the inside floor indicator and car front wall stand clear of the landing wall")
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
	var copied := NotebookArt.note_line("SEC-EXIT | locked | badge 3", "the way out?")
	book.right.add_child(copied)
	var labels := copied.find_children("*", "Label", true, false)
	check(labels.size() == 2 and (labels[0] as Label).text == "the way out?", "a copied terminal line keeps the player's label")
	var pen := NotebookArt.write_button()
	check(pen is Button and pen.focus_mode == Control.FOCUS_NONE, "the write-it-down button never steals the terminal's focus")
	pen.free()
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


func test_document_props() -> void:
	var stage := _stage()
	var docs := [
		ArtProps.binder(stage, Vector3(0, 0, 0), 0, "FACILITIES MANUAL"),
		ArtProps.binder(stage, Vector3(1, 0, 0), 0, "FACILITIES MANUAL", false),
		ArtProps.desk_card(stage, Vector3(2, 0, 0), 0, "GUARD CLOCK-IN"),
		ArtProps.brochure(stage, Vector3(3, 0, 0), 0, "WELCOME TO HALCYON"),
		ArtProps.brochure(stage, Vector3(4, 0, 0), 0, "WELCOME TO HALCYON", false),
		ArtProps.memo(stage, Vector3(5, 1, 0), 0, "MEMO: badge audit"),
		ArtProps.memo(stage, Vector3(6, 0, 0), 0, "MEMO: badge audit", true),
		ArtProps.corkboard(stage, Vector3(7, 1.4, 0), 0),
		ArtProps.clipboard(stage, Vector3(8, 0, 0), 0, "NIGHT ROSTER"),
		ArtProps.clipboard(stage, Vector3(9, 1.2, 0), 0, "NIGHT ROSTER", false),
	]
	for d in docs:
		check(d.get_meta("doc_size", null) is Vector3, "%s has a footprint for its collider" % d.name)
		check(d.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s adds no collision (mechanics own it)" % d.name)
	for d in [docs[0], docs[3], docs[6], docs[8]]:
		var title: Label3D = d.find_child("Title", true, false)
		var up := (title.global_transform.basis * Vector3(0, 0, 1)).normalized()
		check(title != null and up.y > 0.9, "a %s lying on a desk reads facing up" % d.name)
		var low := INF
		for mi in d.find_children("*", "MeshInstance3D", true, false):
			low = minf(low, _lowest(mi))
		check(low > -0.002, "a %s rests on the desk, not in it (%.3f)" % [d.name, low])
	var memo_title: Label3D = docs[5].find_child("Title", true, false)
	check(memo_title.text == "MEMO: badge audit" and (memo_title.global_transform.basis * Vector3(0, 0, 1)).z < -0.9, "a memo on a wall faces out of it, like a poster")
	var hm: Label3D = docs[0].find_child("Margin", true, false)
	check(hm.font == NotebookArt.old_hand_font() and hm.text.ends_with("- H.M."), "Mercer signs his margin notes in his own hand")
	check(NotebookArt.old_hand_font() is FontFile and NotebookArt.old_hand_font() != NotebookArt.hand_font(), "Mercer's handwriting ships with the game and differs from the players'")
	var front: Node3D = docs[2].get_node("Front")
	check(front.rotation_degrees.x > 10, "the desk card leans back")
	stage.free()


func _lowest(mi: MeshInstance3D) -> float:
	var box := mi.get_aabb()
	var low := INF
	for i in 8:
		low = minf(low, (mi.global_transform * box.get_endpoint(i)).y)
	return low


func test_document_view() -> void:
	var layer := CanvasLayer.new()
	t.root.add_child(layer)
	var doc := DocumentView.new()
	layer.add_child(doc)
	var copied := []
	doc.copy_requested.connect(func(text): copied.append(text))
	var was_closed := [false]
	doc.closed.connect(func(): was_closed[0] = true)
	doc.set_paper("manual")
	doc.set_title("FACILITIES MANUAL - 4.2")
	var line := doc.add_line("Every door has a row in the doors table.")
	var chip: Button = line.find_child("AddChip", true, false)
	check(chip != null and not chip.visible and line.find_child("WriteNote", true, false) == null, "document lines have no buttons until you point at one")
	line.call("set_hovered", true)
	check(chip.visible and chip.text == "+ add to notebook" and line.get("hovered"), "pointing at a line highlights it and offers to add it to the notebook")
	chip.pressed.emit()
	check(copied == ["Every door has a row in the doors table."], "adding a document line copies that line")
	var note := doc.add_margin_note("check the timestamps! - H.M.")
	check(note.get_theme_font("font") == NotebookArt.old_hand_font(), "Mercer's margin notes are in his handwriting")
	check(line.is_ancestor_of(note), "a margin note sits beside the line it's about")
	var mine := doc.add_margin_note("ask Dee", "player")
	check(mine.get_theme_font("font") == NotebookArt.hand_font(), "a player's margin note is in the crew's handwriting")
	var blank := doc.add_blank("Clock-in times are stored in a table of ", "guards", " choice.")
	var filled: Label = blank.find_child("Filled", true, false)
	check(filled.text.strip_edges() == "guards" and filled.get_theme_font("font") == NotebookArt.old_hand_font(), "the blank is filled in by hand")
	(blank.find_child("AddChip", true, false) as Button).pressed.emit()
	check(copied.back() == "Clock-in times are stored in a table of guards choice.", "adding a filled-in line copies the whole sentence")
	doc.show_doc()
	await t.create_timer(0.35).timeout
	check(doc.visible and doc.modulate.a > 0.99, "the document opens")
	for k in DocumentView.KINDS:
		doc.set_paper(k)
		var r := doc.paper.get_global_rect()
		var screen := doc.get_viewport_rect()
		check(r.size.x <= screen.size.x + 1 and r.size.y <= screen.size.y + 1, "a %s fits on screen" % k)
	(doc.get_node("Paper/Close") as Button).pressed.emit()
	check(was_closed[0], "the close button asks to put the document down")
	doc.clear()
	await t.process_frame
	check(doc.body.get_child_count() == 1 and not doc.get_node("Paper/Body/Title").visible, "clear leaves a blank page")
	doc.hide_doc()
	await t.create_timer(0.3).timeout
	check(not doc.visible, "the document closes")
	layer.free()


func test_held_notebook() -> void:
	var stage := _stage()
	var cam := Camera3D.new()
	cam.fov = 75
	stage.add_child(cam)
	cam.make_current()
	var held := HeldNotebook.attach(cam, CharacterLooks.crew(1))
	var book := NotebookView.new()
	held.set_content(book)
	book.add_tab("Notes")
	check(held.view == book and book.embedded and not book.get_node("Dim").visible, "the notebook in your hands draws the pages without dimming the screen")
	check(not held.visible and held.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "a put-away notebook costs nothing to draw")
	held.open_book()
	await t.create_timer(0.6).timeout
	check(held.is_open() and held.visible and held.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "the notebook comes out and opens")
	var screen := t.root.get_visible_rect().size
	var spine := cam.unproject_position(held.book_root.global_position)
	check(absf(spine.x - screen.x / 2.0) < 4.0 and spine.y > screen.y * 0.5, "it's held centred, low in the view (%s)" % spine)
	var top := cam.unproject_position(held.book_root.global_transform * Vector3(0, held.page_size().y / 2.0, 0))
	check(top.y > screen.y * 0.3, "the top of the room stays in view above the book")
	# A pixel on the right page, found again from where it shows on the screen.
	var quad: MeshInstance3D = held.halves[1]
	var full := Vector2(NotebookView.EMBED_SIZE)
	var px := Vector2(1000, 300)
	var qs: Vector2 = (quad.mesh as QuadMesh).size
	var mat := quad.material_override as ShaderMaterial
	var uv: Vector2 = (px / full - (mat.get_shader_parameter("uv_offset") as Vector2)) / (mat.get_shader_parameter("uv_scale") as Vector2)
	var world := quad.global_transform * Vector3((uv.x - 0.5) * qs.x, (0.5 - uv.y) * qs.y, 0)
	var back := held.page_point(cam.unproject_position(world))
	check(back.distance_to(px) < 3.0, "clicks on the pages land on the right spot of the page (%s)" % back)
	check(held.page_point(Vector2(screen.x / 2.0, 5)).x < 0, "clicks above the book don't reach it")
	var line := NotebookArt.hand("B1-04 storeroom")
	book.right.add_child(line)
	held.write_in(line, 0.3)
	await t.create_timer(0.15).timeout
	check(book.book.get_node_or_null("Unwritten") != null and book.book.get_node_or_null("Pen") != null, "a new line is written in with a pen")
	await t.create_timer(0.3).timeout
	check(book.book.get_node_or_null("Unwritten") == null, "and is all there once written")
	held.close_book()
	await t.create_timer(0.45).timeout
	check(not held.is_open() and not held.visible and held.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "the notebook goes back in the pocket")
	stage.free()


func test_terminal_screen() -> void:
	var stage := _stage()
	var cam := Camera3D.new()
	cam.fov = 75
	stage.add_child(cam)
	cam.make_current()
	var term := Node3D.new()
	term.position = Vector3(2, 0.9, -1)
	term.rotation_degrees.y = 180
	var grey := MeshInstance3D.new()
	grey.mesh = BoxMesh.new()
	term.add_child(grey)
	var shape := CollisionShape3D.new()
	term.add_child(shape)
	stage.add_child(term)
	var screen := TerminalScreen.attach(term)
	check(not grey.visible and shape.get_parent() == term, "the CRT replaces the greybox monitor's look and keeps its collider")
	check(screen.keyboard != null and screen.keyboard.global_position.distance_to(screen.glass.global_position) < 0.5, "every terminal gets a keyboard in front of it")
	var kb_front := (screen.keyboard.global_transform.basis * Vector3(0, 0, 1)).dot(screen.glass.global_transform.basis * Vector3(0, 0, 1))
	check(kb_front > 0.9, "the keyboard faces the same way as the screen")
	for i in 230:
		screen.add_line("row %d" % i)
	check(screen.display.text.text.contains("row 229") and not screen.display.text.text.contains("row 5\n"), "the screen keeps the latest lines")
	screen.set_typing("SELECT")
	check(screen.display.prompt.text.begins_with("> SELECT"), "teammates see what's being typed")
	cam.global_transform = screen.focus_transform(cam.fov)
	var screen_size := t.root.get_visible_rect().size
	var mid := cam.unproject_position(screen.glass.global_position)
	check(mid.distance_to(screen_size / 2.0) < 3.0, "the focused camera looks straight at the screen")
	var top := cam.unproject_position(screen.glass.global_transform * Vector3(0, TerminalScreen.SCREEN_SIZE.y / 2.0, 0))
	check(absf((mid.y - top.y) * 2.0 / screen_size.y - 0.85) < 0.03, "focused, the screen fills most of the view")
	var px := screen.screen_point(cam, screen_size / 2.0)
	check(px.distance_to(Vector2(TerminalScreen.SCREEN_PX) / 2.0) < 3.0, "a click in the middle of the view lands in the middle of the glass")
	# Following a Terminal: its transcript and everyone's half-typed lines.
	var source := _FakeTerminal.new()
	stage.add_child(source)
	screen.follow(source)
	source.transcript = ["BOOT", "> SELECT 1;"]
	source.seated = [1]
	source.typing = {1: "SELECT * FROM do"}
	source.screen_changed.emit()
	check(screen.display.text.text.ends_with("> SELECT 1;") and screen.display.prompt.text.contains("SELECT * FROM do_"), "the glass follows its terminal's text and what's being typed")
	var ui := CanvasLayer.new()
	screen.host(ui)
	check(ui.get_parent() == screen.viewport and not screen.display.visible and screen.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "the terminal UI can be put on the glass")
	check(screen.release() == ui and screen.display.visible and ui.get_parent() == null, "and taken off again")
	ui.free()
	stage.free()


## Stands in for a Terminal's screen fields (co-op keeps them the same on every machine).
class _FakeTerminal extends Node:
	signal screen_changed
	var transcript: Array[String] = []
	var seated: Array[int] = []
	var typing := {}
