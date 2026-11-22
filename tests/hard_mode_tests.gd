extends RefCounted
## Hard mode (plan/hard-mode.md; Augustine 2026-11-18): left down too long you die
## and stay lying there; only a first-aid kit brings anyone round; when everyone's
## down, "Everyone's down. Déjà vu?", a fade, and the floor starts over. Solo, going
## down starts the floor over. No safety net: falling out of the world kills you.
## The dead come back at the next floor; the living get the floor's reward.

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	await test_kit_cabinets()
	await test_kit_on_yourself()
	await test_solo()
	await test_fall_net()
	await test_coop()


func _game() -> Node:
	return _tree.root.get_node("/root/Game")


func _net() -> Node:
	return _tree.root.get_node("/root/Net")


func _frames(n: int) -> void:
	for i in n:
		await _tree.physics_frame


func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await _tree.physics_frame
	return cond.call()


func _hard(on: bool) -> void:
	_game().hard_mode = on
	_game().dead_watch_only = false
	_game().wipe_new_run = false


## Put `item` in `p`'s hands.
func _hold(p: Player, item: String) -> void:
	if p.inventory.active_item() != item:
		p.inventory.use_slot(p.inventory.hotbar.find(item))


func _solo_level() -> Node:
	_game().new_run(41)
	_game().rourke_fate = "killed"
	var level = load("res://scenes/level_2.tscn").instantiate()
	_tree.root.add_child(level)
	_tree._books_read([level])
	await _frames(30)
	level.watcher.active = false
	return level


## Every floor has first-aid cabinets on its walls, where the crew can get to them:
## twice as many on Normal as on Hard, and one each opens and gives up a kit.
func test_kit_cabinets() -> void:
	print("Hard mode: first-aid cabinets on every floor")
	for hard in [false, true]:
		_hard(hard)
		for k in 8:
			_game().new_run(43 + k)
			var level = load("res://scenes/level_%d.tscn" % k).instantiate()
			_tree.root.add_child(level)
			await _frames(3)
			var cabs: Array = level.find_children("KitCabinet*", "FirstAidCabinet", false, false)
			var area := KitCabinets._area(KitCabinets.floor_nav(level, level.geo))
			var want := KitCabinets.count_for(area, hard)
			_check.call(cabs.size() == want, "%s, %s: %d cabinets for %d m² of floor (want %d)" % ["Hard" if hard else "Normal", level.name, cabs.size(), int(area), want])
			var shut: Array = level.shut_rooms
			_check.call(cabs.all(func(c): return not shut.any(func(room): return room.has_point(c.position))), "%s: none of them in a room nobody can get into" % level.name)
			if k == 4:
				# Floor 10's ground-floor beat is a bigger floor than 10 itself, and still takes no more than half.
				var on_ten: int = cabs.filter(func(c): return c.position.y > -10.0).size()
				_check.call(on_ten == (1 if hard else 3) and cabs.size() - on_ten == (2 if hard else 3), "floor 10 keeps its kits: %d on 10, %d on its ground floor" % [on_ten, cabs.size() - on_ten])
			if not hard:
				# Nothing in front of any of them: from where you'd stand, you see the cabinet itself.
				var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
				var hidden := []
				for c in cabs:
					var q := PhysicsRayQueryParameters3D.create(c.global_transform * Vector3(0, 0.1, 1.0), c.global_position)
					q.collide_with_areas = true
					var hit := space.intersect_ray(q)
					if hit.is_empty() or hit.collider != c:
						hidden.append(c.cabinet_id)
				_check.call(hidden.is_empty(), "%s: every cabinet is out in the open, on a wall you can walk up to (%s)" % [level.name, hidden])
				var ids: Array = cabs.map(func(c): return c.cabinet_id)
				_check.call(ids.size() == cabs.size() and ids.all(func(i): return ids.count(i) == 1), "each with an id of its own")
			level.queue_free()
			await _frames(3)
	_hard(false)
	# Opening one leaves the others sealed, and taking its kit is this run's.
	_game().new_run(50)
	var level = await _solo_level()
	var cabs: Array = level.find_children("KitCabinet*", "FirstAidCabinet", false, false)
	var p: Player = level.player
	var c: FirstAidCabinet = cabs[0]
	c.interact(p)
	await _frames(3)
	c.interact(p)
	await _frames(3)
	_check.call(c.my_state() == FirstAidCabinet.TAKEN and p.inventory.has(FirstAidCabinet.ITEM) and cabs[1].my_state() == FirstAidCabinet.SEALED,
		"open one and take its kit: the others stay sealed")
	_check.call(FirstAidCabinet.state() == FirstAidCabinet.SEALED and cabs[1].get_prompt(p) == "[E] Open the first-aid cabinet", "and STAIR 1's cabinet is its own")
	p.inventory.remove(FirstAidCabinet.ITEM)
	level.queue_free()
	await _frames(5)


## Both modes: a kit on yourself takes a few seconds, holding still; a hit stops it.
func test_kit_on_yourself() -> void:
	print("Hard mode: a first-aid kit takes a moment")
	_hard(false)
	var level = await _solo_level()
	var p: Player = level.player
	p.inventory.add(FirstAidCabinet.ITEM)
	_hold(p, FirstAidCabinet.ITEM)
	p.health = 40.0
	_check.call(FirstAidCabinet.use_on_self(p) and p.combat.patch_left > 0.0 and p.input_locked and p.health == 40.0,
		"patching yourself up takes a moment, holding still")
	await _frames(30)
	p.take_damage(5.0, "watcher")
	_check.call(p.combat.patch_left == 0.0 and not p.input_locked and p.inventory.has(FirstAidCabinet.ITEM), "a hit stops it, and you keep the kit")
	FirstAidCabinet.use_on_self(p)
	_check.call(not await _until(func(): return p.health == PlayerCombat.MAX_HEALTH, int(CrewVitals.KIT_TIME * 60 * 0.8)), "not done in much under %d s" % int(CrewVitals.KIT_TIME))
	_check.call(await _until(func(): return p.health == PlayerCombat.MAX_HEALTH, 60), "then you're at full health")
	_check.call(not p.inventory.has(FirstAidCabinet.ITEM) and not p.input_locked and level.hud._notice.text == FirstAidCabinet.PATCHED_SELF,
		"the kit's used up, and you can move again")
	level.queue_free()
	await _frames(5)


func test_solo() -> void:
	print("Hard mode: solo")
	_hard(true)
	var level = await _solo_level()
	var p: Player = level.player
	var crew: CrewVitals = level.crew
	var restarts := []
	crew.restart_with = func(new_run): restarts.append(new_run)
	var at := p.global_position
	p.take_damage(1000.0, "watcher")
	await _frames(5)
	_check.call(crew.wiping and p.combat.down and p.input_locked, "solo, going down is the end of the floor")
	_check.call(level.hud._notice.text == "Everyone's down. Déjà vu?", "\"Everyone's down. Déjà vu?\"")
	var fade: ColorRect = level.hud.find_child("WipeFade", true, false)
	await _frames(60)
	_check.call(fade != null and fade.color.a > 0.1 and restarts.is_empty(), "the screen fades out first")
	_check.call(await _until(func(): return restarts == [false], int((CrewVitals.WIPE_FADE + 1.0) * 60)), "then the floor starts over")
	_check.call(p.global_position.distance_to(at) < 0.5, "with no trip back to the checkpoint on the way")
	# Without Co-op's restart, the old way back stands in.
	crew._back_after_wipe()
	await _until(func(): return p.health > 0.0, 400)  # the level's own fade back to the checkpoint
	_check.call(not crew.wiping and not p.combat.down and crew.downed.is_empty(), "(the stand-in: back on your feet at the checkpoint)")
	# Fall out of the world: no net in hard mode.
	var real_profile = _net().profile
	_net().profile = Profile.new()
	restarts.clear()
	_check.call(p.combat.fell_out() and _net().profile.earned.has(PlayerCombat.WAY_OUT), "fall out of the world: \"I think I found the way out!\"")
	_check.call(await _until(func(): return restarts == [false], int((CrewVitals.WIPE_FADE + 1.0) * 60)), "and you're dead: the floor starts over")
	crew._back_after_wipe()
	await _until(func(): return p.health > 0.0, 400)  # the level's own fade back to the checkpoint
	_hard(false)
	_check.call(not p.combat.fell_out() and not p.combat.down, "on Normal, the safety net catches you as usual")
	_net().profile = real_profile
	level.queue_free()
	await _frames(5)


## The floor's own safety net (FallNet) asks hard mode first: no put-back, you die.
func test_fall_net() -> void:
	print("Hard mode: no safety net")
	_hard(true)
	_game().new_run(41)
	var level = load("res://scenes/level_3.tscn").instantiate()
	_tree.root.add_child(level)
	_tree._books_read([level])
	var p: Player = level.player
	var crew: CrewVitals = level.crew
	var net: FallNet = level.get_node_or_null("FallNet")
	var restarts := []
	crew.restart_with = func(new_run): restarts.append(new_run)
	var real_profile = _net().profile
	_net().profile = Profile.new()
	await _until(func(): return p.is_on_floor() and net != null and net.has_safe_spot, 240)
	var home := p.global_position
	p.global_position = home + Vector3.DOWN * 200.0
	p.velocity = Vector3.ZERO
	_check.call(net != null and await _until(func(): return p.combat.dead, 120), "falling out of the world in hard mode: you die")
	_check.call(p.global_position.distance_to(home) > 150.0 and _net().profile.earned.has(PlayerCombat.WAY_OUT), "with no put-back, and \"I think I found the way out!\"")
	_check.call(await _until(func(): return restarts == [false], int((CrewVitals.WIPE_FADE + 1.0) * 60)), "and the floor starts over")
	_hard(false)
	_net().profile = real_profile
	level.queue_free()
	await _frames(5)


func test_coop() -> void:
	print("Hard mode: co-op")
	_hard(true)
	_game().new_run(42)
	_game().rourke_fate = "killed"
	var worlds: Array = await _tree._coop_worlds(1)
	var machines: Array = await _tree._coop_load(worlds, "res://scenes/level_2.tscn")
	_tree._books_read(machines)
	var host = machines[0]
	var client = machines[1]
	var client_id: int = _tree.get_multiplayer(worlds[1].get_path()).get_unique_id()
	var host_id: int = _tree.get_multiplayer(worlds[0].get_path()).get_unique_id()
	for l in machines:
		l.watcher.active = false
	var hp: Player = host.player
	var cp: Player = client.player
	var crew: CrewVitals = host.crew
	var restarts := []
	crew.restart_with = func(new_run): restarts.append(new_run)
	await _until(func(): return host.players.puppet(client_id) != null, 240)  # the teammate has arrived on the host
	var puppet = host.players.puppet(client_id)
	var deaths := []
	client.crew.died.connect(func(id, cause): deaths.append([id, cause]))
	puppet.take_damage(1000.0, "watcher")
	await _until(func(): return machines.all(func(l): return l.crew.downed.has(client_id)), 60)
	_check.call(cp.combat.down and cp.combat.bleed_left <= PlayerCombat.BLEED_OUT_HARD, "down, you have %d s, not %d" % [int(PlayerCombat.BLEED_OUT_HARD), int(PlayerCombat.BLEED_OUT)])
	hp.global_position = puppet.global_position + Vector3(-0.8, 0.1, 0)
	await _frames(5)
	_check.call(puppet.get_prompt(hp) == "", "nobody can help you up by hand")
	puppet.interact(hp)
	await _frames(20)
	_check.call(cp.combat.down and crew.reviving.is_empty(), "pressing E does nothing")
	hp.inventory.add(FirstAidCabinet.ITEM)
	_hold(hp, FirstAidCabinet.ITEM)
	_check.call(puppet.get_prompt(hp) == FirstAidCabinet.PATCH_PROMPT, "with a first-aid kit in your hands, you can patch them up")
	hp.global_position = puppet.global_position + Vector3(-0.8, 0.1, 0)
	await _frames(5)
	puppet.interact(hp)
	await _frames(20)
	_check.call(cp.combat.down and machines.all(func(l): return l.crew.reviving.has(client_id)), "it takes a moment, standing by them")

	_check.call(await _until(func(): return not cp.combat.down, int((CrewVitals.KIT_TIME + 1.0) * 60)) and cp.health == PlayerCombat.MAX_HEALTH, "then they're up, at full health")
	_check.call(not hp.inventory.has(FirstAidCabinet.ITEM), "and the kit's used up")
	# Left down too long, you die.
	puppet.take_damage(1000.0, "watcher")
	await _frames(10)
	cp.combat.bleed_left = 0.05
	_check.call(await _until(func(): return machines.all(func(l): return l.crew.is_dead(client_id)), 120), "left down too long, you die, and every machine knows")
	_check.call(deaths == [[client_id, "watcher"]] and cp.combat.dead and cp.combat.down and puppet.downed, "you stay lying there")
	_check.call(not cp.combat.unconscious and cp.combat.bleed_left == 0.0, "(not passed out: dead)")
	hp.inventory.add(FirstAidCabinet.ITEM)
	_hold(hp, FirstAidCabinet.ITEM)
	_check.call(puppet.get_prompt(hp) == "" and not FirstAidCabinet.patch(hp, crew, client_id), "not even a kit brings back the dead")
	_check.call(crew.living_ids() == [host_id] and not crew.wiping, "one dead, one standing: the floor goes on")
	# The floor's cleared: the living get its reward; the dead don't.
	for l in machines:
		l.hud._notice.text = ""
	var real_profile = _net().profile
	_net().profile = Profile.new()
	crew._on_floor_cleared("test")
	await _frames(10)
	var still := Achievements.NOTICE % Achievements.name_of(CrewVitals.HARD_FLOOR)
	_check.call(host.hud._notice.text.contains(still) and not client.hud._notice.text.contains(still), "clearing a floor rewards whoever's still alive (%s / %s)" % [host.hud._notice.text, client.hud._notice.text])
	_check.call(not host.hud._notice.text.contains(Achievements.name_of(CrewVitals.HARD_FLOOR_ALL)), "but not \"nobody died\"")
	_net().profile = real_profile
	# On to the next floor: the dead come back.
	var came := []
	host.crew.came_back.connect(func(id): came.append(id))
	for l in machines:
		l.crew._on_floor_entered(l)
	await _frames(10)
	_check.call(came == [client_id] and not cp.combat.dead and not cp.combat.down and cp.health == PlayerCombat.MAX_HEALTH and not cp.input_locked,
		"at the next floor, the dead come back on their feet")
	_check.call(machines.all(func(l): return l.crew.dead.is_empty() and l.crew.downed.is_empty()) and not puppet.downed, "everywhere")
	# A fatal fall kills at once; then the last one standing goes down.
	cp.take_damage(1000.0, "fall")
	_check.call(await _until(func(): return machines.all(func(l): return l.crew.is_dead(client_id)), 120), "a fatal fall kills you outright")
	hp.take_damage(1000.0, "watcher")
	_check.call(await _until(func(): return machines.all(func(l): return l.crew.wiping), 60), "the last one standing goes down: everyone's down, on every machine")
	_check.call(host.hud._notice.text == CrewVitals.WIPE_NOTICE and client.hud._notice.text == CrewVitals.WIPE_NOTICE, "\"Everyone's down. Déjà vu?\" for everyone")
	_check.call(await _until(func(): return restarts == [false], int((CrewVitals.WIPE_FADE + 1.0) * 60)), "and the host starts the floor over, once")
	_hard(false)
	await _tree._coop_close(worlds)

