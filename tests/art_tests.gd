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
	test_outfits()
	test_unlockable_items()
	await test_props()
	test_kits()
	await test_held_items()
	await test_gallery()
	await test_dressed_level_0()
	await test_dressed_level_1()
	await test_dressed_level_2()
	test_skyline_heights()
	await test_dressed_home_base()
	test_sticky_notes()
	test_elevator()
	await test_notebook()
	test_document_props()
	await test_document_view()
	await test_held_notebook()
	await test_terminal_screen()
	test_tool_skins()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func test_materials_are_shared() -> void:
	var a := ArtPalette.surface("carpet")
	check(a == ArtPalette.surface("carpet"), "the same surface returns one shared material")
	check(ArtPalette.surface("drywall", Color(1.3, 1.3, 1.3)) != ArtPalette.surface("drywall"), "a tint brighter than white is its own material, not plain white's")
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
	rig.play("sit_floor")
	for i in 120:
		rig.animate(1.0 / 60.0)
	var seat_y: float = rig.joints["r_hip"].global_position.y
	var floor_feet: float = rig.joints["r_knee"].to_global(Vector3(0, -0.44, 0)).y
	var floor_hand: float = rig.joints["r_elbow"].to_global(Vector3(0, -0.3, 0)).y
	check(seat_y < 0.25 and seat_y > 0.05, "sitting on the floor puts the seat on the floor (%.2f m)" % seat_y)
	check(absf(floor_feet) < 0.12 and absf(floor_hand) < 0.12, "with the feet out in front and the hands behind, both on the floor (feet %.2f, hands %.2f)" % [floor_feet, floor_hand])
	check(rig.joints["r_knee"].global_position.z < holder.global_position.z - 0.25, "the legs stretch out the way the body faces")
	rig.play("not_a_thing")
	check(rig.action == "idle", "unknown actions fall back to idle")
	rig.play("idle")
	rig.speed_override = 0.0
	rig.look_target = holder.global_position + Vector3(3, 1.6, 0)
	for i in 60:
		rig.animate(1.0 / 60.0)
	check(rig.joints["head"].rotation.y < -0.5, "the head turns toward a look target")
	stage.free()


func test_outfits() -> void:
	var most := 0
	for body in CharacterLooks.BODY_TYPES:
		for hair in CharacterLooks.SLOTS.hair:
			for head in CharacterLooks.SLOTS.head:
				for jacket in CharacterLooks.SLOTS.jacket:
					for face in CharacterLooks.SLOTS.face:
						for feet in CharacterLooks.SLOTS.feet:
							var loadout := {"body": body, "hair": {"item": hair}, "head": {"item": head}, "jacket": {"item": jacket},
								"top": {"item": "polo"}, "face": {"item": face}, "feet": {"item": feet}, "ears": {"item": "studs"}, "belt": {"item": "radio"}}
							var rig := CharacterRig.build(Node3D.new(), CharacterLooks.outfit(loadout))
							most = maxi(most, rig.part_count())
							rig.get_parent().free()
	check(most <= 32, "every outfit combination stays within 32 mesh pieces (most: %d)" % most)
	var plain := CharacterLooks.outfit({})
	check(plain.body == 1 and plain.hair_style == "short" and plain.headwear == null and plain.jacket == null and plain.belt_radio, "an empty loadout is a plain crew member with a radio")
	check(CharacterLooks.outfit({"top": {"item": "gold_suit"}}).collar, "an unknown item falls back to the slot's default")
	var red := Color(0.8, 0.1, 0.1)
	var look := CharacterLooks.outfit({"name": "Sam", "body": 2, "skin": 7, "top": {"item": "tee", "color": red},
		"jacket": {"item": "blazer", "color": red}, "head": {"item": "beanie", "color": red}, "face": {"item": "glasses", "color": red}})
	check(look.name == "Sam" and look.body == 2 and look.skin == CharacterLooks.SKIN_TONES[7], "name, body and skin come from the loadout")
	check(look.shirt == red and look.jacket == red and look.shoulder_pads and look.headwear == "beanie" and look.headwear_color == red and look.glasses == red, "each item takes the color the player picked")
	var hatted := CharacterRig.build(Node3D.new(), CharacterLooks.outfit({"hair": {"item": "long"}, "head": {"item": "cap"}}))
	var bare := CharacterRig.build(Node3D.new(), CharacterLooks.outfit({"hair": {"item": "long"}}))
	check(hatted.part_count() == bare.part_count() + 1, "a cap covers the top of the hair, and long hair still shows below it")
	hatted.get_parent().free()
	bare.get_parent().free()
	# Every item looks different from its slot's default, so an unlock is worth wearing.
	var same: Array[String] = []
	for slot in CharacterLooks.SLOTS:
		var plain_look := CharacterLooks.outfit({slot: {"item": CharacterLooks.SLOTS[slot][0]}})
		for item in CharacterLooks.SLOTS[slot].slice(1):
			if CharacterLooks.outfit({slot: {"item": item}}) == plain_look:
				same.append("%s/%s" % [slot, item])
	check(same.is_empty(), "every item changes how the player looks (same as the default: %s)" % [same])


func test_unlockable_items() -> void:
	# The first ten unlocks (plan/approvals/unlocks.md): Graphics can draw every one.
	for key in ["notebook/easy_sql", "face/reading_glasses", "top/byte_right_polo", "feet/high_tops", "head/hard_hat",
			"terminal/amber", "jacket/security", "head/mercer_cap", "walkie/gold", "jacket/press"]:
		var parts: PackedStringArray = key.split("/")
		var drawn: Array = CharacterLooks.SLOTS.get(parts[0], CharacterLooks.TOOL_ITEMS.get(parts[0], []))
		check(parts[1] in drawn, "%s can be drawn" % key)
	var red := Color(0.8, 0.1, 0.1)
	var readers := CharacterLooks.outfit({"face": {"item": "reading_glasses", "color": red}})
	check(readers.readers == red and not readers.glasses, "reading glasses are their own half-moon pair, in the picked color")
	var polo := CharacterLooks.outfit({"top": {"item": "byte_right_polo"}})
	check(polo.collar and polo.logo == ArtPalette.BYTERIGHT_BLUE, "the Byte-Right polo has a collar and the company's blue logo")
	check(CharacterLooks.outfit({"feet": {"item": "high_tops"}}).high_tops, "high-tops come up over the ankle")
	var guard := CharacterLooks.outfit({"jacket": {"item": "security", "color": red}})
	check(guard.jacket == red and guard.jacket_closed and guard.jacket_badge is Color, "the security jacket is zipped, takes the picked color, and wears a metal badge")
	var press := CharacterLooks.outfit({"jacket": {"item": "press"}})
	check(press.jacket_closed and press.badge and press.logo == null, "the press jacket is zipped with a press pass clipped on")
	check(CharacterLooks.outfit({"head": {"item": "mercer_cap"}}).headwear == "mercer_cap", "Mercer's cap is a hat of its own")
	var zipped := CharacterRig.build(Node3D.new(), guard)
	var open_jacket := CharacterRig.build(Node3D.new(), CharacterLooks.outfit({"jacket": {"item": "jacket", "color": red}}))
	check(zipped.part_count() <= open_jacket.part_count(), "a zipped jacket and its badge cost no more pieces than an open jacket")
	zipped.get_parent().free()
	open_jacket.get_parent().free()
	# Tool finishes: gold, Easy SQL and amber draw in their own color, whatever was picked.
	var look := CharacterLooks.outfit({})
	look.tools = {"walkie": {"item": "gold", "color": red}, "notebook": {"item": "easy_sql", "color": red},
		"terminal": {"item": "amber", "color": red}, "flashlight": {"item": "standard", "color": red}}
	check(CharacterLooks.tool_color(look, "walkie") == CharacterLooks.FIXED_COLORS["walkie/gold"], "a gold walkie is gold, not the picked color")
	check(CharacterLooks.tool_color(look, "flashlight") == red, "tintable tools still take the picked color")
	check(CharacterLooks.terminal_skin(look.tools.terminal) == CharacterLooks.FIXED_COLORS["terminal/amber"], "an amber terminal draws in amber")
	check(CharacterLooks.terminal_skin({"item": "phosphor"}) == TerminalScreen.PHOSPHOR and CharacterLooks.terminal_skin(null) == TerminalScreen.PHOSPHOR, "with no pick the terminal stays green")
	check(CharacterLooks.tool_item(look, "notebook") == "easy_sql" and CharacterLooks.tool_item({"tools": {"walkie": {"item": "diamond"}}}, "walkie") == "standard", "an unknown tool item falls back to the standard one")
	var stage := _stage()
	var cam := Camera3D.new()
	stage.add_child(cam)
	var held := HeldItems.attach(cam, look)
	var shell := held.walkie.shell.material_override as StandardMaterial3D
	check(shell.albedo_color == CharacterLooks.FIXED_COLORS["walkie/gold"] and shell.metallic > 0.0, "the held gold walkie has a polished finish")
	var book := HeldNotebook.attach(cam, look)
	var view := NotebookView.new()
	book.set_content(view)
	check(view.cover_art == "easy_sql" and view.cover == CharacterLooks.FIXED_COLORS["notebook/easy_sql"], "the Easy SQL notebook wears the book's teal cover and its art")
	var spiral := HeldNotebook.attach(cam, CharacterLooks.outfit({}))
	var plain_view := NotebookView.new()
	spiral.set_content(plain_view)
	check(plain_view.cover_art == "", "a standard notebook has no printed cover")
	stage.free()


func test_rig_budget() -> void:
	var stage := _stage()
	var looks := [CharacterLooks.rourke(), CharacterLooks.vale(), CharacterLooks.mercer(), CharacterLooks.night_guard(), CharacterLooks.maddison(), CharacterLooks.maddison(50)]
	for i in 6:
		looks.append(CharacterLooks.crew(i))
		looks.append(CharacterLooks.crew(i, {"body": 2, "skin": i}))
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
	var one := CharacterRig.build(Node3D.new(), CharacterLooks.crew(0, {"body": 1}))
	var two := CharacterRig.build(Node3D.new(), CharacterLooks.crew(0, {"body": 2}))
	check(two.joints["r_shoulder"].position.x < one.joints["r_shoulder"].position.x and two.joints["r_hip"].position.x > one.joints["r_hip"].position.x, "body type 2 has narrower shoulders and fuller hips than type 1")
	check(CharacterLooks.crew(3, {"skin": 0}).skin == CharacterLooks.SKIN_TONES[0] and CharacterLooks.crew(3, {"skin": 99}).skin == CharacterLooks.SKIN_TONES[-1], "players pick their skin tone, and an out-of-range pick clamps")
	check(CharacterLooks.crew(2) == CharacterLooks.crew(2, {}), "with no picks, a crew look is unchanged")
	one.get_parent().free()
	two.get_parent().free()
	var a := CharacterRig.build(Node3D.new(), CharacterLooks.crew(0))
	var b := CharacterRig.build(Node3D.new(), CharacterLooks.crew(0))
	var ma: MeshInstance3D = a.joints["head"].get_child(0)
	var mb: MeshInstance3D = b.joints["head"].get_child(0)
	check(ma.mesh == mb.mesh and ma.material_override == mb.material_override, "rigs share meshes and materials")
	a.get_parent().free()
	b.get_parent().free()
	stage.free()


func test_kits() -> void:
	var stage := _stage()
	var rail := ArtKit.stair_rail(stage, Vector3.ZERO, Vector3(0, 1.8, 3.0))
	var sign0 := ArtKit.landing_number(stage, Vector3(2, 1.5, 0), 0, 0)
	var sign22 := ArtKit.landing_number(stage, Vector3(3, 1.5, 0), 0, 22)
	var lamp := ArtKit.emergency_light(stage, Vector3(0, 2.4, 0), 0)
	var shapes := 0
	for n in [rail, sign0, sign22, lamp]:
		shapes += n.find_children("*", "CollisionObject3D", true, false).size()
	check(shapes == 0, "stairwell dressing is visual only: nothing for the Watcher's raycasts to hit")
	var numbers := []
	for sgn in [sign0, sign22]:
		for l in sgn.find_children("*", "Label3D", true, false):
			numbers.append(l.text)
	check("G" in numbers and "22" in numbers, "landing numbers match the tower floors (G, 22)")
	check(lamp.get_node_or_null("Lamp") is SpotLight3D and ArtKit.emergency_light(stage, Vector3.ZERO, 0, false).get_node_or_null("Lamp") == null, "a lit emergency light lights the stairs, a dead one doesn't")
	var top_rail: MeshInstance3D = rail.get_child(0)
	check(rail.get_child_count() >= 5 and is_equal_approx(top_rail.position.y, 0.9 + 0.9), "a handrail runs up the flight on posts, 0.9 m over the treads")
	var table := ArtKit.folding_table(stage, Vector3(5, 0, 0))
	var chair := ArtKit.folding_chair(stage, Vector3(5, 0, 1))
	check(table.get_meta("art_prop", false) and chair.get_meta("art_prop", false), "garage tables and chairs are solid props the route checks know about")
	var board := ArtKit.whiteboard(stage, Vector3(7, 1.4, 0), 0, "CLIENTS\n- Halcyon (after hours)")
	var banner := ArtKit.banner(stage, Vector3(7, 2.4, 0), 0)
	check(board.find_children("*", "Label3D", true, false).size() == 1 and "BYTE-RIGHT" in banner.find_children("*", "Label3D", true, false)[0].text, "the whiteboard has writing and the banner names the company")
	check(ArtKit.pizza_box(stage, Vector3(5, 0.76, 0), 0, false, 3).get_child_count() == 3, "shut pizza boxes stack")
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
	var unexplained := ArtDress.unexplained_dark(level, DressLevel0.DARK_CHECK)
	check(unexplained.is_empty(), "Level 0: every dark patch has a cause you can see, a dead fitting (%s)" % str(unexplained.slice(0, 6)))
	var boxes := _prop_boxes(level)
	check(boxes.size() >= 10, "Level 0 is furnished (%d solid props)" % boxes.size())
	var keep_clear := [
		Vector3(0, 0, 8.8), Vector3(-0.5, 0, 0.6), Vector3(10.2, 0, 3), Vector3(0, 0, 5.6),  # Rourke's stops, respawn
		Vector3(1.5, 0, -0.2), Vector3(-1.5, 0, -0.2),  # in front of the terminal and visitor log
		Vector3(-2.5, 0, -4.7), Vector3(0, 0, -2.2),  # walkies, and landing over the desk
		Vector3(-7.4, 0, 4), Vector3(-14.6, 0, 4), Vector3(-18.6, 0, 4.5),  # vent mouth, closet side, the tape
		Vector3(-0.3, 0, 14.8), Vector3(4.3, 0, 14.8), Vector3(4.3, 0, 15.5), Vector3(4.3, 0, 17.9), Vector3(0, 0, 11.5),  # out of the van (front doors, side door), to the doors
		Vector3(-6.5, 0, -8.5), Vector3(0, 0, -8.5), Vector3(10.0, 0, -8.5), Vector3(0, 0, -10.6),  # Rourke's walks along the back corridor
		Vector3(6.2, 0, -11.0), Vector3(6.2, 0, -12.0), Vector3(6.2, 0, -13.2),  # to the vending machines
		Vector3(10.0, 0, -11.0), Vector3(10.2, 0, -12.6),  # into the IT closet, under the ceiling panel
		Vector3(-11.5, 0, -15.2), Vector3(-8.5, 0, -16.9),  # into the restroom stalls
		Vector3(-2.0, 0, -13.75), Vector3(2.0, 0, -13.75),  # between the cafeteria tables
		Vector3(15.5, 0, -8.5), Vector3(18.0, 0, -2.5),  # the dark corridor
		Vector3(25.0, 0, 4.05), Vector3(28.5, 0, 3.0),  # holding the elevator, the car's doors
	]
	var blocked := _blocked(level, boxes, keep_clear)
	check(blocked.is_empty(), "props keep Level 0's routes and puzzles clear %s" % [blocked])
	var floor_mat: Material = null
	for b in level.geo.get_children():
		if b.name.begins_with("Floor") and absf(b.position.x) < 1 and absf(b.position.z) < 1:
			floor_mat = b.get_child(0).material_override
	check(floor_mat == ArtPalette.surface("carpet"), "the lobby floor is carpeted")
	var corridor_floor: Node = null
	var bare_tables := 0
	for b in level.geo.get_children():
		if b.name.begins_with("Floor") and is_equal_approx(b.position.z, -8.5) and is_equal_approx(b.position.x, -4.0):
			corridor_floor = b
		if b.name.begins_with("CafTable") and b.get_node_or_null("TableLook") == null:
			bare_tables += 1
	check(corridor_floor != null and corridor_floor.get_child(0).material_override != Greybox.mat(Color(0.3, 0.31, 0.3)), "the back corridor's floor is dressed too, not just the first room's")
	check(bare_tables == 0, "every cafeteria table has a top and legs")
	var look: NpcLook = level.rourke.get_node_or_null("Look")
	check(look != null and not level.rourke._body.visible, "Rourke wears his character model")
	check(look.pick_action() == "idle", "Rourke stands at ease before the turn")
	var lit := 0
	for l in level.lights["lobby"]:
		if l.get_node_or_null("PanelLink"):
			lit += 1
	check(lit == level.lights["lobby"].size(), "every lobby light panel follows its light")
	_check_polish(level, "Level 0")
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
	_check_skyline(level, "level_0")
	_check_chairs_sittable(level, "Level 0")
	level.free()


func test_dressed_level_1() -> void:
	t.root.get_node("Game").new_run(7)
	var level = load("res://scenes/level_1.tscn").instantiate()
	t.root.add_child(level)
	await _frames(10)
	var unexplained := ArtDress.unexplained_dark(level, DressLevel1.DARK_CHECK)
	check(unexplained.is_empty(), "Level 1: every dark patch has a cause you can see, a dead fitting (%s)" % str(unexplained.slice(0, 6)))
	var break_dead := 0
	for c in t.get_nodes_in_group("dark_cause"):
		var at: Vector3 = ArtDress._in(level.get_node("Dressing"), c)
		if level.is_ancestor_of(c) and DressLevel1.BREAK.has_point(Vector3(at.x, 1.0, at.z)):
			break_dead += 1
	check(break_dead > 0, "the break room's dark end has a fitting with a dead tube")
	var facing_table := 0
	var chairs := 0
	for b in level.geo.get_children():
		if b is StaticBody3D and String(b.name).begins_with("CafeChair") and DressLevel1.BREAK.has_point(b.position + Vector3(0, 0.5, 0)):
			chairs += 1
			var to_table: Vector3 = Vector3(17.5, 0, -5.5) - b.position
			if (-b.transform.basis.z).dot(to_table.normalized()) > 0.5:
				facing_table += 1
	check(chairs == 4 and facing_table == 3, "break room chairs face the table, one pushed back askew (%d of %d)" % [facing_table, chairs])
	var keep_clear := [Vector3(0, 0, 12.6), Vector3(0, 0, 6.0), Vector3(-4.5, 0, 7.4), Vector3(0, 0, -8.0), Vector3(0, 0, 10.5)]
	keep_clear.append_array([
		Vector3(-2.4, 0, 6.4), Vector3(0, 0, -11.0), Vector3(0, 0, -12.4),  # Rourke's lead-in, the way to the elevator
		Vector3(-14.5, 0, 8.4), Vector3(-15.0, 0, 5.6),  # into the NOC, reading its shift log
		Vector3(-12.0, 0, -6.0), Vector3(-17.5, 0, -7.4),  # through the cable vault, to the spare coil
		Vector3(12.0, 0, -6.0), Vector3(20.3, 0, -6.0),  # through the break room, to the coffee-fund note
		Vector3(-12.0, 0, -14.0), Vector3(-12.0, 0, -22.4),  # into Server Room C, to the syslog printout
		Vector3(14.5, 0, 8.4), Vector3(15.0, 0, 3.5),  # Server Room B's door and aisle
	])
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
	_check_polish(level, "Level 1")
	_check_skyline(level, "level_1")
	_check_chairs_sittable(level, "Level 1")
	level.free()


func test_dressed_level_2() -> void:
	t.root.get_node("Game").new_run(5)
	var level = load("res://scenes/level_2.tscn").instantiate()
	t.root.add_child(level)
	await _frames(10)
	var unexplained := ArtDress.unexplained_dark(level, DressLevel2.DARK_CHECK)
	check(unexplained.is_empty(), "Level 2: every dark patch has a cause you can see, a dead fitting (%s)" % str(unexplained.slice(0, 6)))
	var dressing: Node = level.get_node("Dressing")
	check(dressing.get_child_count() > 20, "the security floor is furnished")
	check(_prop_boxes(level).is_empty() and dressing.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"nothing the security floor's dressing adds collides: the Watcher's sight lines and paths are unchanged")
	var chair: Node = level.geo.get_node("NightDeskChair")
	check(not (chair.get_child(0) as MeshInstance3D).visible and chair.find_children("*", "CollisionShape3D", false, false).size() == 1,
		"the night desk's chair block shows a chair, and still collides as before")
	var lab_wall: MeshInstance3D = null
	for b in level.geo.get_children():
		if b.name.begins_with("Wall_") and Level2Floor.LAB_BOX.has_point(b.position) and DressLevel2.LAB.has_point(b.position):
			lab_wall = b.get_child(0)
			break
	check(lab_wall != null and (lab_wall.material_override as StandardMaterial3D).albedo_color.b > 0.9, "Secure Lab B is clean and white")
	check(level.lab.rourke.get_node_or_null("Look") != null, "Rourke wears his character model on the security floor too")
	_check_polish(level, "Level 2")
	_check_skyline(level, "level_2")
	level.free()


## Halcyon Tower: every wing sees the sky and the campus at its own storey's height,
## and nothing outside collides or shows through into a wing next door.
## The quality pass: ceiling lights cast soft shadows up close and drop them with
## distance, fittings glow through louvres, and the room gets AO and reflections.
func test_dressed_home_base() -> void:
	var level = load("res://scenes/home_base.tscn").instantiate()
	t.root.add_child(level)
	await _frames(10)
	var boxes := _prop_boxes(level)
	check(boxes.size() >= 5, "the garage is furnished (%d solid props)" % boxes.size())
	var blocked := _blocked(level, boxes, DressHomeBase.KEEP_CLEAR)
	check(blocked.is_empty(), "props keep the garage's walk from the door to the fax, the back corner, the bench and the van clear %s" % [blocked])
	var walk := []
	var m: Dictionary = HomeBase.MADDISON_MARKS
	for leg in [[m.door[0], m.greet[0]], [m.greet[0], m.fax[0]], [m.fax[0], HomeBase.BENCH_WAY], [HomeBase.BENCH_WAY, m.bench[0]], [HomeBase.BENCH_WAY, m.van[0]]]:
		var steps := ceili(leg[0].distance_to(leg[1]) / 0.5)
		for i in steps + 1:
			walk.append(leg[0].lerp(leg[1], float(i) / steps))
	var in_her_way := _blocked(level, boxes, walk)
	check(in_her_way.is_empty(), "props keep Maddison's walk between her marks clear %s" % [in_her_way])
	var cover: Node = level.bench_book.get_node_or_null("EasySQL")
	check(cover != null, "the bench copy of Easy SQL wears the real cover")
	var reach := 0.0
	for id in level.lights:
		for l in level.lights[id]:
			reach = maxf(reach, l.omni_range - l.global_position.distance_to(level.book_bag.global_position))
	check(reach < 0.5, "dressing leaves the back corner dark under its dead bulb")
	var banners: Array = level.find_children("Banner*", "Node3D", true, false)
	check(banners.size() == 1, "one Byte-Right banner hangs on the wall")
	var shadowed := true
	for id in level.lights:
		for l in level.lights[id]:
			shadowed = shadowed and l.shadow_enabled and l.get_node_or_null("Hang/Bulb") != null
	check(shadowed and level.environment.ssao_enabled, "the garage hangs bare bulbs that cast shadows, with the floors' polish")
	var chairs: Array = level.find_children("FoldingChair*", "StaticBody3D", true, false)
	var seated := 0
	for chair in chairs:
		for seat in level.find_children("*", "Seat", true, false):
			var off: Vector3 = seat.global_position - chair.global_position
			if Vector2(off.x, off.z).length() < 0.05 and absf(off.y - ArtKit.CHAIR_SEAT) < 0.02 and absf(angle_difference(seat.global_rotation.y, chair.global_rotation.y)) < 0.01:
				seated += 1
	check(chairs.size() >= 3 and seated == chairs.size(), "every garage folding chair can be sat on, facing the way it faces (%d of %d)" % [seated, chairs.size()])
	level.free()


## Every chair Graphics dressed in can be sat on, facing the way it faces.
func _check_chairs_sittable(level: Node3D, label: String) -> void:
	var chairs := 0
	var missing: Array[String] = []
	for b in level.find_children("*", "StaticBody3D", true, false):
		if not b.has_meta("art_prop") or not (String(b.name).begins_with("Chair") or String(b.name).begins_with("CafeChair")):
			continue
		chairs += 1
		var seats: Array = b.find_children("*", "Seat", false, false)
		var top := ArtProps.OFFICE_SEAT if String(b.name).begins_with("Chair") else ArtProps.CAFE_SEAT
		if seats.size() != 1 or not seats[0].position.is_equal_approx(Vector3(0, top, 0)) or seats[0].rotation != Vector3.ZERO:
			missing.append(String(b.name))
	check(chairs > 0 and missing.is_empty(), "%s: all %d dressed chairs can be sat on, facing the way they face (not: %s)" % [label, chairs, missing])


func _check_polish(level: Node3D, label: String) -> void:
	var spill := []
	for poster in level.find_children("Poster*", "Node3D", true, false):
		var paper := ((poster.get_child(1) as MeshInstance3D).mesh as BoxMesh).size
		var l: Label3D = poster.find_children("*", "Label3D", false, false)[0]
		var font: Font = l.font if l.font else ThemeDB.fallback_font
		var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		var text := font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, l.width, l.font_size, -1, flags) * l.pixel_size
		if text.x > paper.x or text.y > paper.y or l.font_size < 16:
			spill.append(l.text.get_slice("\n", 0))
	check(spill.is_empty(), "%s: every poster's text fits on its paper %s" % [label, spill])
	for holder in level.geo.get_children():
		if holder.name.begins_with("Stairwell"):
			var plate: Node = holder.get_node_or_null("LandingNumber")
			var lamp: Node = holder.get_node_or_null("EmergencyLight")
			var colliders: Array = holder.find_children("*", "CollisionObject3D", true, false)
			var ours := 0
			for c in colliders:
				if plate and plate.is_ancestor_of(c) or lamp and lamp.is_ancestor_of(c):
					ours += 1
			check(plate != null and lamp != null and holder.get_node_or_null("Handrail") != null and ours == 0, "%s: the fire stairs have their floor plate, emergency light and handrail, all visual only" % label)
	var lights := 0
	var unshadowed := []
	for id in level.lights:
		for l in level.lights[id]:
			var omni := l as OmniLight3D
			if not omni:
				continue
			lights += 1
			if not (omni.shadow_enabled and omni.distance_fade_enabled and omni.distance_fade_shadow <= ArtDress.SHADOW_NEAR):
				unshadowed.append(str(omni.name))
	check(lights > 0 and unshadowed.is_empty(), "%s: ceiling lights cast shadows that fade out with distance %s" % [label, unshadowed.slice(0, 6)])
	var env: Environment = level.environment
	check(env.ssao_enabled and env.ssr_enabled, "%s: corners get ambient occlusion and polished floors reflect" % label)
	var panel: MeshInstance3D = null
	for id in level.lights:
		for l in level.lights[id]:
			var link = l.get_node_or_null("PanelLink")
			if link and l.visible and l.light_energy > 0.05 and is_instance_valid(link.panel):
				panel = link.panel
	check(panel != null and panel.material_override.emission_texture == ArtPalette.texture("louvre"), "%s: lit fittings show their louvres" % label)


func _check_skyline(level: Node3D, wing: String) -> void:
	var sky: Node3D = level.get_node_or_null("Dressing/Skyline")
	check(sky != null and sky.get_meta("storey") == ArtSkyline.FLOORS[wing], "%s looks out on the campus from storey %d" % [wing, ArtSkyline.FLOORS[wing]])
	if sky == null:
		return
	check(sky.find_children("*", "CollisionObject3D", true, false).is_empty() and sky.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"%s: nothing outside the windows collides, so the Watcher sees and walks as before" % wing)
	var placed := true
	for mat in sky.get_meta("materials"):
		placed = placed and (mat as ShaderMaterial).get_shader_parameter("view_center") == sky.global_position
	check(placed, "%s: every outside piece knows where its view is" % wing)
	var radius: float = sky.get_meta("radius")
	var inside := true
	var clear := true
	var at: Transform3D = World.ROUTE[World.ROUTE.map(func(r): return r.key).find(wing)].at
	for b in level.geo.get_children():
		if not b is StaticBody3D:
			continue
		var p: Vector3 = b.position
		inside = inside and Vector2(p.x - sky.position.x, p.z - sky.position.z).length() < radius
		for r in World.ROUTE:
			if r.key == wing or r.key == "level_0":
				continue
			var v: Dictionary = ArtSkyline.VIEWS[r.key]
			var c: Vector3 = r.at * Vector3(v.center.x, 0, v.center.y)
			var w: Vector3 = at * p
			clear = clear and Vector2(w.x - c.x, w.z - c.z).length() > v.radius
	check(inside, "%s: the whole floor sits inside its own sky" % wing)
	check(clear, "%s: no other floor's sky reaches into this one in the World" % wing)


func test_skyline_heights() -> void:
	check(is_equal_approx(ArtSkyline.floor_height(0), 0.0) and is_equal_approx(ArtSkyline.floor_height(14), 55.4) and is_equal_approx(ArtSkyline.floor_height(22), 85.8),
		"the server floor is 55 m up and the security floor 86 m")
	check(ArtSkyline.roof_height() > 110.0, "the tower's roof is over 110 m up")


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
	# A printed form, filled in by hand, as a Document's lines.
	doc.set_paper("clipboard")
	doc.add_lines([
		{"columns": ["NAME", "BADGE #", "IN"], "widths": [3, 2, 1]},
		{"row": ["PIKE, H.", "", ""], "over": "NO SHOW", "text": "PIKE, H.  no show"},
		{"row": ["Har", "", "22:00"], "stain": "coffee", "stain_at": 0, "text": "Har... (coffee stain)  22:00"},
		{"row": ["", "", ""]},
		"",
		"Guard PINs are kept on file.",
		{"text": "guards", "hand": true},
		{"before": "Date: ", "filled": "10/15", "after": ""},
		{"stamp": "RECEIVED"},
	])
	await t.process_frame
	await t.process_frame
	var rows := doc.body.get_children().filter(func(c): return c.get("copy_text") != null)
	check(rows.size() == 6, "every line of a form that can be read becomes a row (%d)" % rows.size())
	var head: Control = doc.body.get_node("TableHead")
	check(head != null and head.find_children("*", "Label", true, false).size() == 3, "a table starts with its printed column names")
	var pike: Control = rows[0]
	check(pike.find_child("Over", true, false) is Label and (pike.find_child("Over", true, false) as Label).get_theme_color("font_color") == NotebookArt.RED_PEN, "NO SHOW is written across Pike's row in red pen")
	var widths := []
	for c in head.get_child(0).get_children():
		widths.append(roundi(c.size.x))
	var row_widths := []
	for c in pike.get_child(0).get_children():
		row_widths.append(roundi(c.size.x))
	check(widths == row_widths and absf(widths[0] - widths[1] * 1.5) < 2, "the rows' cells line up under the column names at their widths")
	var har: Control = rows[1]
	var stain: Control = null
	for c in har.find_children("*", "Control", true, false):
		if c.get("seed_text") != null:
			stain = c
	check(stain != null and stain.z_index > 0, "the coffee stain lies over the Har row's writing")
	var har_name: Label = har.get_child(0).get_child(0).get_child(0)
	check(har_name.text == "Har", "only the first letters of the stained name are written out")
	(har.find_child("AddChip", true, false) as Button).pressed.emit()
	check(copied.back() == "Har... (coffee stain)  22:00", "adding the stained row copies what can be read")
	var empty: Control = rows[2]
	empty.call("_process", 0.0)
	empty.call("set_hovered", false)
	check(not (empty.find_child("AddChip", true, false) as Button).visible, "an empty row has nothing to add")
	check(doc.body.get_node("Stamp") != null, "a rubber stamp goes on the page")
	doc.clear()
	await t.process_frame
	check(doc.get("_columns").is_empty(), "clear forgets the last table")
	# The same page as a texture, for a sheet on a wall.
	var holder := Node.new()
	layer.add_child(holder)
	var tex := DocumentView.paper_texture(holder, [{"columns": ["NAME", "IN"]}, {"row": ["Har", "22:00"], "stain": "coffee", "stain_at": 0, "text": "Har...  22:00"}], "clipboard", "NIGHT SHIFT SIGN-IN")
	var vp: SubViewport = holder.get_node("PaperTexture")
	var drawn: DocumentView = vp.get_child(0)
	check(tex is ViewportTexture and vp.size == Vector2i(DocumentView.PAPERS.clipboard.size), "a paper drawn to a texture is its design size")
	check(drawn.flat and not drawn.get_node("Dim").visible and drawn.paper.position == Vector2.ZERO, "drawn flat: just the paper, no dimming")
	check(drawn.plain_text() == "NIGHT SHIFT SIGN-IN\nNAME  IN\nHar...  22:00", "what's on it can be read back (%s)" % drawn.plain_text().c_escape())
	for i in 10:
		await t.process_frame
	check(vp.render_target_update_mode != SubViewport.UPDATE_ALWAYS, "once drawn, it stops redrawing")
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
	for i in 2:
		var page: MeshInstance3D = held.halves[i]
		var thumb: MeshInstance3D = page.get_parent().get_node("LeftHand" if i == 0 else "RightHand").get_node("Thumb")
		var pad := page.global_transform.affine_inverse() * thumb.global_transform * thumb.get_aabb()
		check(pad.position.z > 0.0, "%s: the thumb lies on the open page, not through it" % thumb.get_parent().name)
	var line := NotebookArt.hand("B1-04 storeroom")
	book.right.add_child(line)
	held.write_in(line, 0.3)
	await t.create_timer(0.15).timeout
	check(book.book.get_node_or_null("Unwritten") != null and book.book.get_node_or_null("Pen") != null, "a new line is written in with a pen")
	await t.create_timer(0.3).timeout
	check(book.book.get_node_or_null("Unwritten") == null, "and is all there once written")
	check(held.page_to_world(px).distance_to(world) < 0.002, "a spot on the page image has its place in the world")
	# A sticky note being filed (Movement moves it): your free hand carries it in.
	var filer := _FakePlayer.new()
	stage.add_child(filer)
	held.follow(filer)
	var note := ArtProps.sticky_note(cam, Vector3(0.05, -0.1, -0.3), 0, "LIKE")
	filer.note = note
	filer.t = 0.5
	await t.process_frame
	await t.process_frame
	check(held.get_node("ReachHand").visible and not held.right_half.get_node("RightHand").visible, "your free hand carries a sticky note in while the other holds the book")
	check(held.get_node("ReachHand").global_position.distance_to(note.global_position) < 0.05, "the hand is on the note")
	filer.note = null
	await t.process_frame
	check(not held.get_node("ReachHand").visible and held.right_half.get_node("RightHand").visible, "filed, the hand goes back to the book")
	held.close_book()
	await t.create_timer(0.45).timeout
	check(not held.is_open() and not held.visible and held.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "the notebook goes back in the pocket")
	stage.free()


func test_held_paper() -> void:
	var stage := _stage()
	var cam := Camera3D.new()
	cam.fov = 75
	stage.add_child(cam)
	cam.make_current()
	var held := HeldPaper.attach(cam, CharacterLooks.crew(2))
	var player := _FakePlayer.new()
	stage.add_child(player)
	held.follow(player)
	await t.process_frame
	check(not held.right_hand.visible and not held.left_hand.visible, "empty hands stay out of view")
	var doc := _FakeDocument.new()
	doc.position = Vector3(0.3, -0.4, -1.5)
	stage.add_child(doc)
	ArtProps.clipboard(doc, Vector3.ZERO, 180.0, doc.title, false)
	player.held_prop = doc
	held.hold(doc, Vector2(0.23, 0.32), Vector3.BACK, doc)
	for i in 30:
		await t.process_frame
	check(held.right_hand.visible and held.right_hand.global_position.distance_to(cam.global_position) <= HeldPaper.REACH + 0.01, "the right hand reaches out for the paper, only as far as an arm goes")
	check(not held.left_hand.visible, "the other hand waits until the paper is close")
	var page_view: DocumentView = held.find_child("PaperTexture", true, false).get_child(0)
	check(held.page != null and doc.is_ancestor_of(held.page) and page_view.plain_text().contains("PIKE, H."), "the document's real page lies over the prop you picked up")
	# Movement brings it up to read; the hands hold its bottom corners.
	doc.reparent(cam, false)
	doc.transform = Transform3D(Basis.IDENTITY, Vector3(0, -0.01, -0.3))
	for i in 40:
		await t.process_frame
	var corner := doc.global_transform * Vector3(0.23 / 2.0, -0.32 / 2.0 + 0.03, held.page.position.z)
	check(held.right_hand.global_position.distance_to(corner) < 0.01 and held.left_hand.visible, "held up to read, both hands hold it by the bottom corners, on its face at the edge")
	# Thumbs on the page, never through it; palms and sleeves behind the board, never above the hands.
	var to_doc := doc.global_transform.affine_inverse()
	var back_z := INF
	for n in doc.find_children("*", "MeshInstance3D", true, false):
		if n != held.page:
			back_z = minf(back_z, (to_doc * (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()).position.z)
	for hand in [held.right_hand, held.left_hand]:
		var thumb: MeshInstance3D = hand.get_node("Thumb")
		var palm: MeshInstance3D = hand.get_node("Palm")
		var sleeve: MeshInstance3D = hand.get_node("Sleeve")
		var tb := to_doc * thumb.global_transform * thumb.get_aabb()
		var pb := to_doc * palm.global_transform * palm.get_aabb()
		var sb := to_doc * sleeve.global_transform * sleeve.get_aabb()
		check(tb.position.z > held.page.position.z, "%s: the thumb lies on the page, not through it" % hand.name)
		check(pb.end.z < back_z, "%s: the palm stays behind the clipboard" % hand.name)
		check(sb.end.y < pb.end.y, "%s: the sleeve hangs below the hand, not past it" % hand.name)
	player.prop_lowered.emit(doc)
	player.held_prop = null
	for i in 60:
		await t.process_frame
	check(held.page == null and not held.right_hand.visible and not held.left_hand.visible, "put back, the page comes off and the hands go down")
	stage.free()


## Stands in for a Document (scripts/world), which the art tests don't load.
class _FakeDocument extends Node3D:
	var title := "NIGHT SHIFT SIGN-IN"

	func paper_kind() -> String:
		return "clipboard"

	func lines() -> Array:
		return [{"columns": ["NAME", "IN"]}, {"row": ["PIKE, H.", ""], "over": "NO SHOW", "text": "PIKE, H.  no show"}]


## Stands in for the Player's pick-up and filing state (scripts/player).
class _FakePlayer extends Node3D:
	signal prop_lowered(prop: Node3D)
	var held_prop: Node3D
	var note: Node3D  # the sticky note being filed
	var t := 0.0

	func filing_note() -> Node3D:
		return note

	func filing_progress() -> float:
		return t if note else 0.0


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
	var amber := Color(1.0, 0.7, 0.2)
	source.transcript = ["[color=#7dff8c]3 rows[/color]", "[color=#ff6655]ERROR[/color]", "plain"]
	source.skin_color = amber
	source.screen_changed.emit()
	var shown := screen.display.text.text
	check(screen.display.skin == amber and screen.display.text.get_theme_color("default_color").is_equal_approx(amber), "a terminal skin recolors the phosphor")
	check(not shown.contains("7dff8c") and shown.contains("ff6655") and shown.contains("3 rows"), "green highlights take the skin's color, red errors stay red")
	source.skin_color = null
	source.screen_changed.emit()
	check(screen.display.text.text.contains("7dff8c") and screen.display.text.get_theme_color("default_color") == TerminalScreen.PHOSPHOR, "with nobody's skin the screen is green phosphor again")
	var ui := CanvasLayer.new()
	screen.host(ui)
	check(ui.get_parent() == screen.viewport and not screen.display.visible and screen.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "the terminal UI can be put on the glass")
	check(screen.release() == ui and screen.display.visible and ui.get_parent() == null, "and taken off again")
	ui.free()
	stage.free()


func test_tool_skins() -> void:
	var amber := Color(1.0, 0.7, 0.2)
	var red := Color(1.0, 0.4, 0.33)
	check(TerminalScreen.reskin(TerminalScreen.PHOSPHOR, amber).is_equal_approx(amber), "the phosphor green becomes the skin color")
	check(TerminalScreen.reskin(red, amber) == red and TerminalScreen.reskin(Color.WHITE, amber) == Color.WHITE, "red and white text keep their color on any skin")
	check(TerminalScreen.TerminalDisplay.colored("> a[1]_", red).contains("a[lb]1]"), "a typed [ shows as typed, not as bbcode")
	var pink := Color(0.9, 0.3, 0.6)
	var teal := Color(0.1, 0.6, 0.6)
	var navy := Color(0.1, 0.1, 0.4)
	var look := CharacterLooks.outfit({})
	look.tools = {"flashlight": {"item": "standard", "color": pink}, "walkie": {"item": "standard", "color": teal}, "notebook": {"item": "spiral", "color": navy}}
	var stage := _stage()
	var cam := Camera3D.new()
	stage.add_child(cam)
	var held := HeldItems.attach(cam, look)
	var lamp: MeshInstance3D = held.flashlight._shell[0]
	check((lamp.material_override as StandardMaterial3D).albedo_color == pink and (held.walkie.shell.material_override as StandardMaterial3D).albedo_color == teal, "the flashlight and walkie wear the player's skins")
	var plain := HeldItems.attach(cam, CharacterLooks.outfit({}))
	check((plain.walkie.shell.material_override as StandardMaterial3D).albedo_color == ArtPalette.SAFETY_YELLOW, "with no skin the walkie is safety yellow")
	var book := HeldNotebook.attach(cam, look)
	var view := NotebookView.new()
	book.set_content(view)
	check(book.cover_color == navy and view.cover == navy, "the notebook's cover is the player's pick, on the board and the drawn book")
	var bare := NotebookView.new()
	check(bare.cover == NotebookView.COVER, "a notebook with no skin keeps the navy cover")
	bare.free()
	stage.free()


## Stands in for a Terminal's screen fields (co-op keeps them the same on every machine).
class _FakeTerminal extends Node:
	signal screen_changed
	var transcript: Array[String] = []
	var seated: Array[int] = []
	var typing := {}
	var skin_color: Variant = null
