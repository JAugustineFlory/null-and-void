extends RefCounted
## The garage's lab (GarageLab): the annex through the west wall, its six
## computers, and the lockers that open each player's Customize panel.

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	var net := _tree.root.get_node("Net")
	var real_profile = net.profile
	var real_look: Dictionary = net.wanted_look.duplicate(true)
	net.profile = Profile.new()  # in memory, so tests never touch a real save
	await test_lab()
	await test_coop_lockers()
	net.profile = real_profile
	net.wanted_look = real_look


func _game() -> Node:
	return _tree.root.get_node("Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree.physics_frame


## Whether the largest crew body, standing, fits at each of `points` (garage-local
## feet positions) and everywhere on the way between them, `step` apart.
func _walkable(level: Node3D, points: Array, step := 0.2) -> String:
	var big := CrewBody.largest()
	var shape := CapsuleShape3D.new()
	shape.radius = big.radius
	shape.height = big.stand - 0.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	var skip: Array[RID] = []
	for n in level.find_children("*", "CharacterBody3D", true, false):
		skip.append(n.get_rid())
	q.exclude = skip
	var space := level.get_world_3d().direct_space_state
	for k in points.size() - 1:
		var a: Vector3 = points[k]
		var b: Vector3 = points[k + 1]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for i in n + 1:
			var at := a.lerp(b, float(i) / n)
			q.transform = Transform3D(Basis(), level.to_global(at + Vector3.UP * (shape.height / 2 + 0.1)))
			var hits := space.intersect_shape(q, 1)
			if not hits.is_empty():
				return "blocked at %s by %s" % [at, hits[0].collider.name]
	return ""


func test_lab() -> void:
	print("Garage: the lab, its computers and lockers")
	_game().new_run(41)
	_game().open_at_home = true
	var world = load("res://scenes/world.tscn").instantiate()
	_tree.root.add_child(world)
	await _frames(30)
	var home = world.home
	var lab: GarageLab = home.lab
	var p: Player = world.player
	_check.call(lab != null and lab.computers.size() == 6 and lab.seats.size() == 6 and lab.lockers.size() == 6, "the lab has six computers, a seat at each, and six lockers")
	_check.call(lab.computers.all(func(c): return not c.enabled and c.prompt == GarageOffice.PC_PROMPT), "the computers wait for the practice cases, with the back office's words")
	var sign: Label3D = home.geo.get_node_or_null("LabSign")
	_check.call(sign != null and sign.text == lab.SIGN, "a sign over the doorway")

	# Every way round it fits the largest body: in through the doorway, along the
	# lockers, down both lanes between the desks and in front of the board.
	var z := GarageLab.DOOR_Z
	var lanes := {
		"in through the doorway": [Vector3(-6.0, 0, z), Vector3(-8.9, 0, z)],
		"up the east side to the lockers": [Vector3(-8.9, 0, z), Vector3(-8.9, 0, -4.85), Vector3(-13.45, 0, -4.85)],
		"down the lane between the rows": [Vector3(-11.25, 0, -4.85), Vector3(-11.25, 0, 1.8)],
		"down the east side": [Vector3(-8.9, 0, z), Vector3(-8.9, 0, 1.8)],
		"in front of the board": [Vector3(-13.45, 0, -4.85), Vector3(-13.45, 0, 1.8)],
		"along the back": [Vector3(-13.45, 0, 1.8), Vector3(-8.9, 0, 1.8)],
	}
	for lane in lanes:
		var why := _walkable(home, lanes[lane])
		_check.call(why == "", "the largest crew body fits %s %s" % [lane, why])
	# A chair is reached from the lane on its east side.
	var reach := []
	for i in GarageLab.DESKS.size():
		var seat: Vector3 = GarageLab.DESKS[i] + GarageLab.DESK_SEAT
		var lane_x := -11.25 if i < 3 else -8.9
		reach.append(_walkable(home, [Vector3(lane_x, 0, seat.z), Vector3(seat.x + 0.6, 0, seat.z)]))
	_check.call(reach.all(func(r): return r == ""), "and up to every chair %s" % [reach])
	_check.call(home.to_local(lab.global_position) == Vector3.ZERO and GarageLab.ROOM.z + GarageLab.ROOM_SIZE.z / 2 < GarageOffice.ROOM.z - GarageOffice.ROOM_SIZE.z / 2,
		"and it stops short of the back office")

	# Lockers: yours has your name and opens; the rest have nobody's.
	var mine := lab.locker_of(p.multiplayer.get_unique_id())
	var net := _tree.root.get_node("Net")
	_check.call(mine == lab.lockers[0] and mine.enabled and mine.local_only and mine.prompt == lab.LOCKER_PROMPT, "your locker is the first, and it opens")
	_check.call(lab.name_cards[0].text == net.player_name and lab.name_cards.slice(1).all(func(c): return c.text == ""), "with your name on it; the empty ones have no name")
	_check.call(lab.lockers.slice(1).all(func(l): return not l.enabled), "and nobody's locker opens")
	var fp_before: Node = p.get_node("FirstPersonBody")
	mine.interact(p)
	await _frames(3)
	var panel: MenuModal = lab.panel
	var picker: LookPicker = panel.find_child("LookPicker", true, false) if panel else null
	var tabs: TabContainer = picker.find_child("Customize", true, false) if picker else null
	_check.call(picker != null and p.input_locked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "opening it shows your Customize panel and holds you still")
	_check.call(tabs != null and tabs.get_node_or_null("Crew") == null and tabs.get_node_or_null("Look") != null and tabs.get_node_or_null("Gear") != null,
		"Look and Gear, without the Crew tab (who you play is set in the lobby)")
	_check.call(panel.is_ancestor_of(_tree.root.gui_get_focus_owner()), "with something picked, so a controller can use it")

	# A pick shows on you straight away, and is saved.
	var skin: int = (int(picker.my_look().skin) + 1) % CharacterLooks.SKIN_TONES.size()
	var crew: String = picker.my_look().crew
	(picker.find_child("Skin%d" % (skin + 1), true, false) as Button).pressed.emit()
	await _frames(3)
	var fp_after: Node = p.get_node_or_null("FirstPersonBody")
	_check.call(int(net.profile.loadout.get("skin", -1)) == skin and int(picker.my_look().skin) == skin, "a new skin is saved to your profile")
	_check.call(fp_after != null and fp_after != fp_before and is_instance_valid(fp_after.rig), "and your body is dressed in it straight away")
	# Mid-run, who you play stays put, even if something asks to change it.
	net.in_game = true
	net.choose_look({"crew": "dana" if crew != "dana" else "walt", "skin": 0})
	net.in_game = false
	await _frames(2)
	_check.call(picker.my_look().crew == crew and int(picker.my_look().skin) == 0, "mid-run, a change of crew is ignored (the rest still applies)")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	_tree.root.push_input(cancel)
	await _frames(3)
	_check.call(not is_instance_valid(panel) and not p.input_locked, "Back closes it and lets you move again")

	world.queue_free()
	await _frames(2)


func test_coop_lockers() -> void:
	print("Garage: co-op, a locker each and changes seen by everyone")
	_game().new_run(43)
	_game().open_at_home = true
	var worlds: Array = await _tree._coop_worlds(1)
	var net := _tree.root.get_node("Net")
	var real_roster: Dictionary = net.roster
	net.roster = {}  # the names the host handed out in the lobby
	for w in worlds:
		net.roster[_tree.get_multiplayer(w.get_path()).get_unique_id()] = "Crew%d" % net.roster.size()
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/world.tscn")
	var labs := machines.map(func(w): return w.home.lab)
	var ids: Array = machines[0].home.players.all_ids()
	var client: int = ids[1]
	_check.call(labs.all(func(l): return l.owners.slice(0, 2) == ids and l.owners.slice(2).all(func(o): return o == 0)),
		"every machine gives the host the first locker and the client the second")
	_check.call(labs[0].lockers[0].enabled and not labs[0].lockers[1].enabled and labs[1].lockers[1].enabled and not labs[1].lockers[0].enabled,
		"and each player's own locker is the one that opens for them")
	_check.call(labs.all(func(l): return l.name_cards[0].text == "Crew0" and l.name_cards[1].text == "Crew1"), "each one's name is on theirs, on every machine")
	# The client's look changes (the host has passed it on): the host sees it on them.
	var puppet: PlayerPuppet = machines[0].home.players.puppet(client)
	var rig_before := puppet.rig
	var look: Dictionary = net.look_of(client, 1).duplicate(true)
	look.skin = (int(look.skin) + 2) % CharacterLooks.SKIN_TONES.size()
	net.looks[client] = look
	net.roster_changed.emit()
	await _frames(2)
	_check.call(puppet.rig != rig_before and is_instance_valid(puppet.rig) and puppet.rig.get_parent() != null, "a teammate's change of look shows on them straight away")
	_check.call(puppet.size == CrewBody.from_look(NetPlayers.look_for(machines[0], client)).size, "in the same body")
	net.looks.erase(client)
	net.roster = real_roster
	_tree._coop_close(worlds)
	await _frames(2)
