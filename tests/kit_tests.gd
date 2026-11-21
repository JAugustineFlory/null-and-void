extends RefCounted
## The environment kit (scripts/world/kit/): gear and the 4-piece carry limit, gear
## trains jamming shutters, fuse boxes, patch panels, crowbar locks and terminals that
## start switched off or missing parts. Each piece's right use and its tempting wrong
## ones, seeded spots across many runs, and the same in co-op.

var t: SceneTree
var _check: Callable
const BENCH := "res://tests/kit/kit_bench.tscn"


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("Environment kit")
	test_gear_limit()
	test_seeded_spots()
	await test_pickups()
	await test_gears_and_shutter()
	await test_fuses()
	await test_patch_panel()
	await test_terminal_rig()
	await test_item_lock()
	await test_rollup_door()
	await test_elevator_stall()
	await test_every_piece_sounds()
	await test_coop()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func _game() -> Node:
	return t.root.get_node("Game")


func _frames(n: int) -> void:
	for i in n:
		await t.physics_frame


func _bench(run_seed := 3) -> Node:
	_game().new_run(run_seed)
	var level = load(BENCH).instantiate()
	t.root.add_child(level)
	await _frames(3)
	level.player.inventory = Inventory.new()
	return level


func _free(level: Node) -> void:
	level.queue_free()
	await t.process_frame


func _press(level: Node, piece: Node) -> void:
	piece.interact(level.player)
	await _frames(2)


func test_gear_limit() -> void:
	var inv := Inventory.new()
	for item in ["radio", "screwdriver", "cable", "deck"]:
		inv.add(item)
	check(not inv.hotbar.has(""), "four small things fill the hotbar")
	check(inv.add("keyboard") and inv.hotbar.has("keyboard") and inv.items.has("deck") and inv.stowed().size() == 1,
		"gear always gets a hotbar slot: a small thing moves to the bag, still carried")
	for item in ["power_cord", "fuse", "crowbar"]:
		inv.add(item)
	check(inv.hotbar.all(func(i): return Inventory.GEAR.has(i)) and Inventory.gear_count(inv.items) == 4, "four pieces of gear fill your hands")
	check(not inv.room_for("fire_extinguisher") and not inv.add("fire_extinguisher") and not inv.has("fire_extinguisher"),
		"a fifth piece of gear doesn't fit: carrying gear is a choice")
	check(inv.room_for("first_aid_kit") and inv.add("first_aid_kit"), "small things still go in the bag with your hands full")
	inv.remove("fuse")
	check(inv.room_for("fire_extinguisher") and inv.add("fire_extinguisher"), "put one down and there's room again")
	check(Inventory.GEAR.all(func(i): return Inventory.ITEMS.has(i)), "every piece of gear has a name and a line about it")


func test_seeded_spots() -> void:
	var spots := [Vector3(1, 0, 0), Vector3(2, 0, 0), Vector3(3, 0, 0)]
	var seen := {}
	var all_ok := true
	var holder := Node3D.new()
	t.root.add_child(holder)
	for s in 40:
		_game().run_seed = s
		var g := GearPickup.place(holder, "fuse", spots, "test_fuse")
		all_ok = all_ok and spots.has(g.position)
		seen[g.position] = true
		var again := GearPickup.place(holder, "fuse", spots, "test_fuse")
		all_ok = all_ok and again.position == g.position
		g.free()
		again.free()
	holder.free()
	check(all_ok and seen.size() == 3, "seeded gear lands on one of its spots, the same for a seed every time, and every spot gets used across 40 runs (%d)" % seen.size())
	var blown := {}
	var orders := {}
	var shuffled_ok := true
	var labels := ["RM 101", "RM 102", "RM 103", "LOBBY"]
	for s in 40:
		_game().run_seed = s
		blown[FuseBox.seeded_blown("bench", 4)] = true
		var order := PatchPanel.shuffled(labels, "bench")
		shuffled_ok = shuffled_ok and order != labels and order.size() == 4 and labels.all(func(l): return order.has(l))
		orders[str(order)] = true
	check(blown.size() >= 3 and blown.keys().all(func(i): return i >= 0 and i < 4), "the blown fuse moves between runs (%d slots seen)" % blown.size())
	check(shuffled_ok and orders.size() >= 5, "patch-panel jacks are shuffled each run, never in the ports' own order (%d orders)" % orders.size())


func test_pickups() -> void:
	var level = await _bench()
	var inv: Inventory = level.player.inventory
	var kb: GearPickup = level.gear["keyboard"]
	check(kb.get_prompt(level.player) == "[E] Pick up the keyboard", "gear on the floor offers itself by name")
	await _press(level, kb)
	check(inv.has("keyboard") and inv.hotbar.has("keyboard") and kb.taken and not kb.visible and kb.get_prompt(level.player) == "",
		"taking it puts it in your hands, and it's gone from the floor")
	for item in ["power_cord", "fuse", "crowbar"]:
		await _press(level, level.gear[item])
	var ext: GearPickup = level.gear["fire_extinguisher"]
	check(ext.get_prompt(level.player).begins_with("Your hands are full"), "with four pieces of gear, a fifth says your hands are full (no [E])")
	await _press(level, ext)
	check(not inv.has("fire_extinguisher") and not ext.taken, "and pressing it takes nothing")
	inv.use_slot(inv.hotbar.find("crowbar"))
	check(ext.get_prompt(level.player) == "[E] Swap your crowbar for the fire extinguisher", "holding a piece of gear (1-4), it offers a swap")
	await _press(level, ext)
	check(inv.has("fire_extinguisher") and not inv.has("crowbar") and ext.item == "crowbar" and ext.visible and not ext.taken,
		"swapping leaves the crowbar where the extinguisher was")
	inv.use_slot(inv.hotbar.find("fire_extinguisher"))
	await _press(level, ext)
	check(inv.has("crowbar") and ext.item == "fire_extinguisher", "and you can swap straight back")
	await _free(level)


func test_gears_and_shutter() -> void:
	var level = await _bench()
	var inv: Inventory = level.player.inventory
	var gears: GearTrain = level.gears
	var shutter: Shutter = level.shutter
	check(not gears.jammed and gears.get_prompt(level.player).begins_with("The gears are turning") and not gears.can_use(KitPiece.hand_of(level.player)),
		"turning gears say so, and with nothing to jam them you can't")
	var opened := false
	for i in 200:
		await t.physics_frame
		if shutter.openness > 0.6 and shutter.target == 1.0:
			opened = true
			break
	check(opened, "the shutter opens and shuts on its own cycle")
	inv.add("screwdriver")
	check(gears.get_prompt(level.player) == "[E] Jam the gears with your screwdriver", "with a screwdriver, you can jam them")
	await _press(level, gears)
	var held := shutter.openness
	await _frames(90)
	check(gears.jammed and not inv.has("screwdriver") and shutter.jammed and is_equal_approx(shutter.openness, held) and shutter.gap() > 1.0,
		"jammed open: the screwdriver stays in the teeth and the shutter stops dead, with room to get under (%.2f m)" % shutter.gap())
	check(gears.get_prompt(level.player) == "[E] Pull the screwdriver out of the gears", "and it can be pulled back out")
	await _press(level, gears)
	check(not gears.jammed and inv.has("screwdriver") and not shutter.jammed, "pulling it out frees the gears and gives the screwdriver back")
	# The tempting wrong one: jam it while it's shut.
	var shut := false
	for i in 200:
		await t.physics_frame
		if shutter.openness == 0.0:
			shut = true
			break
	await _press(level, gears)
	await _frames(90)
	check(shut and gears.jammed and shutter.gap() == 0.0, "jammed while shut, it stays shut: timing matters")
	await _press(level, gears)
	# A train that starts with a screwdriver stuck in it.
	var stuck: GearTrain = level.stuck_gears
	check(stuck.jammed and stuck.get_prompt(level.player) == "Something's jammed in the gears: a screwdriver.", "a train can start jammed; carrying a screwdriver, you've no hand for a second")
	inv.remove("screwdriver")
	await _press(level, stuck)
	check(not stuck.jammed and inv.has("screwdriver"), "without one, pulling it out gives you a screwdriver and the gears run")
	await _free(level)


func test_fuses() -> void:
	var level = await _bench()
	var inv: Inventory = level.player.inventory
	var box: FuseBox = level.fuses
	var changes := []
	box.circuit_changed.connect(func(c, live, _p): changes.append([c, live]))
	var lights := box.slot("LIGHTS")
	var terms := box.slot("TERMINALS")
	check(box.is_live("LIGHTS") and not box.is_live("TERMINALS") and terms.state == "blown", "a blown fuse kills its circuit")
	check(terms.get_prompt(level.player) == "The TERMINALS fuse has blown." and not terms.can_use(KitPiece.hand_of(level.player)), "with no fuse, a blown one only says so")
	check(lights.get_prompt(level.player) == "[E] Pull the LIGHTS fuse", "a working fuse can be pulled")
	await _press(level, lights)
	check(inv.has("fuse") and not box.is_live("LIGHTS") and changes == [["LIGHTS", false]], "pulling it: you carry the fuse, its circuit dies")
	check(lights.get_prompt(level.player) == "[E] Fit your fuse in LIGHTS" and terms.get_prompt(level.player) == "[E] Swap your fuse for the blown TERMINALS fuse",
		"carrying it, you choose where it goes")
	await _press(level, lights)
	check(box.is_live("LIGHTS") and not box.is_live("TERMINALS") and not inv.has("fuse"), "the wrong slot: putting it back only brings the lights back")
	await _press(level, lights)
	await _press(level, terms)
	check(box.is_live("TERMINALS") and not box.is_live("LIGHTS") and not inv.has("fuse") and terms.state == "good", "in the blown slot, it brings TERMINALS back (the blown one is spent)")
	await _free(level)


func test_patch_panel() -> void:
	var level = await _bench()
	var p: PatchPanel = level.patch
	var me: int = level.players.id_of(level.player)
	# Tempting wrong: each lead into the jack right below it.
	for i in p.labels.size():
		await _press(level, p.ports[i])
		await _press(level, p.jacks[i])
	check(p.plugged.size() == 4 and not p.is_solved, "every lead into the jack below it doesn't work: the jacks are in another order")
	check(p.jacks[0].get_prompt(level.player) == "[E] Unplug the %s lead" % p.labels[0], "a plugged jack offers to unplug its lead")
	# The right way: match the labels.
	var solved := []
	p.solved.connect(func(): solved.append(true))
	for i in p.labels.size():
		await _press(level, p.ports[i])
		check(p.holding.get(me, -1) == i and p.ports[i].get_prompt(level.player) == "[E] Let go of the %s lead" % p.labels[i], "taking a lead puts it in your hand (%s)" % p.labels[i])
		await _press(level, p.jacks[p.jack_labels.find(p.labels[i])])
	check(p.is_solved and solved.size() == 1 and p.labels.all(func(l): return p.is_linked(l)), "each lead into the jack with its own label: every line works")
	await _press(level, p.jacks[p.jack_labels.find("LOBBY")])
	check(not p.is_solved and not p.is_linked("LOBBY") and p.holding.get(me, -1) == p.labels.find("LOBBY"), "unplugging one breaks it again, and the lead is in your hand")
	await _press(level, p.ports[p.labels.find("LOBBY")])
	check(not p.holding.has(me), "pressing its port again lets go of it")
	await _free(level)


func test_terminal_rig() -> void:
	var level = await _bench()
	var inv: Inventory = level.player.inventory
	var term: Terminal = level.terminal
	var rig: TerminalRig = level.rig
	var opens := []
	term.used.connect(func(_p): opens.append(true))
	check(rig.blocks() and not term.screen.glass.visible and term.get_prompt(level.player) == "[E] Press the power button", "a terminal off for the night is dark, and offers its power button")
	await _press(level, term)
	check(rig.missing.has("power") and opens.is_empty(), "with no power behind it, the button only clicks")
	# Power: a cord at the back, and the TERMINALS fuse.
	var cord: RigPart = rig.parts["power_cord"]
	check(cord.get_prompt(level.player) == "The power cord is missing.", "no cord: the socket says so")
	await _press(level, level.gear["power_cord"])
	await _press(level, cord)
	check(not rig.missing.has("power_cord") and not inv.has("power_cord") and not rig.has_power(), "the cord plugged in, but its circuit's still dead")
	await _press(level, level.fuses.slot("VENDING"))
	await _press(level, level.fuses.slot("TERMINALS"))
	check(rig.has_power(), "a fuse from VENDING brings it power")
	await _press(level, term)
	check(not rig.missing.has("power") and not term.screen.glass.visible and term.get_prompt(level.player) == "The power light's on, but there's no picture.",
		"switched on, it's still dark: the monitor cable")
	await _press(level, rig.parts["monitor_cable"])
	check(rig.booting and term.get_prompt(level.player) == "" and term.transcript.is_empty(), "a picture at last: it warms up first, the screen still blank")
	await _until(func(): return not rig.booting, 240)
	check(term.transcript == term.boot_text(), "then its boot lines come up, one at a time")
	check(rig.lit() and term.screen.glass.visible and term.get_prompt(level.player) == "There's no keyboard." and rig.blocks(), "booted: a picture, but no keyboard")
	var kb: RigPart = rig.parts["keyboard"]
	check(not kb.can_use(KitPiece.hand_of(level.player)) and not term.screen.keyboard.visible, "no keyboard to plug in yet")
	await _press(level, level.gear["keyboard"])
	var done := []
	rig.assembled.connect(func(): done.append(true))
	await _press(level, kb)
	check(not rig.blocks() and done.size() == 1 and not inv.has("keyboard") and term.screen.keyboard.visible and term.get_prompt(level.player).contains("Use terminal"),
		"keyboard plugged in: it's a terminal again (its query is still the gate)")
	await _press(level, level.fuses.slot("TERMINALS"))
	check(rig.blocks() and not term.screen.glass.visible and term.get_prompt(level.player) == "Nothing. It isn't getting any power.", "pull its fuse and it goes dark again")
	await _free(level)


func test_item_lock() -> void:
	var level = await _bench()
	var hatch: ItemLock = level.hatch
	check(hatch.get_prompt(level.player) == "The hatch is stuck." and not hatch.can_use(KitPiece.hand_of(level.player)), "a stuck hatch says so")
	await _press(level, hatch)
	check(not hatch.is_open, "and won't open bare-handed")
	await _press(level, level.gear["crowbar"])
	check(hatch.get_prompt(level.player) == "[E] Pry the hatch open", "with the crowbar it offers to pry")
	await _press(level, hatch)
	check(hatch.is_open and level.player.inventory.has("crowbar") and hatch.get_prompt(level.player) == "", "it opens, and you keep the crowbar")
	await _free(level)


## Floor G's receiving door: a crowbar left in its chain gear; pull it out, then the
## hand chain lifts the door to a 1.0 m gap, the least every body fits under.
func test_rollup_door() -> void:
	var level = await _bench()
	var gears: GearTrain = level.rollup_gears
	var door: Shutter = level.rollup
	check(gears.jammed and door.jammed and not level.chain.enabled and door.gap() == 0.0, "the roll-up door's gear starts jammed, and its chain does nothing")
	await _press(level, level.chain)
	check(not level.chain.is_open, "pulling the chain while it's jammed does nothing")
	check(gears.get_prompt(level.player) == "[E] Pull the crowbar out of the gears", "something other than a screwdriver can jam a gear")
	await _press(level, gears)
	check(not gears.jammed and level.player.inventory.has("crowbar") and level.chain.enabled, "pulling it out frees the chain, and you keep the crowbar")
	await _press(level, level.chain)
	await _frames(120)
	check(level.chain.is_open and absf(door.gap() - 1.0) < 0.01 and not door.is_open(), "the chain lifts the door to exactly 1.0 m (%.2f): crawl under" % door.gap())
	await _free(level)


## E9: a stuck elevator. Out through the roof hatch and the landing door's release,
## or by prying the doors (Movement's, which calls release("pry")).
func test_elevator_stall() -> void:
	var level = await _bench()
	var lift: Elevator = level.lift
	var stall: ElevatorStall = level.stall
	var p: Player = level.player
	check(stall.stop_at >= 0.3 and stall.stop_at <= 0.7, "the seed picks where between floors it sticks (%.2f)" % stall.stop_at)
	var hole := ElevatorStall.HATCH.size
	check(hole.x >= 1.0 and hole.y >= 1.0 and ElevatorStall.TO_LANDING + 0.1 < ElevatorStall.SHAFT_H - Elevator.DOOR_H + 1.0, "the hatch is at least 1.0 m square, room for every body")
	# Unarmed, a ride is a ride.
	p.global_position = lift.to_global(Vector3(0, 0.1, 1.0))
	lift.open(true)
	await _frames(2)
	level._ride()
	await _until(func(): return level.rides == 1, 600)
	check(level.rides == 1 and lift_contains(level.lift_to, p) and not stall.stalled, "unarmed, the lift rides to its floor as always")
	# Armed: it sticks.
	p.global_position = lift.to_global(Vector3(0, 0.1, 1.0))
	lift.riding = false
	lift.open(true)
	level._arm_stall()
	await _frames(2)
	level._ride()
	await _until(func(): return stall.stalled, 600)
	await _frames(240)
	check(stall.stalled and level.rides == 1 and lift.contains(p.global_position), "armed, it jolts to a stop between floors and stays there")
	check(not lift.press(p) and lift.refusal == "The buttons do nothing.", "the buttons do nothing")
	check(stall.hatch.enabled and stall.hatch.get_prompt(p) == "[E] Push the hatch open", "the roof hatch can be pushed open")
	await _press(level, stall.hatch)
	check(stall.hatch.is_open and stall.hatch.get_children().filter(func(c): return c is CollisionShape3D and not c.disabled).is_empty(), "pushed open, the hatch is a way out")
	# Up through it (Movement's boost or climb), up the ladder, to the release.
	p.global_position = lift.to_global(Vector3(-1.0, stall.roof_y() + 0.1, 1.0))
	await _frames(10)
	check(lift.to_local(p.global_position).y > Elevator.SIZE.y, "the car's roof holds you")
	p.global_position = lift.to_global(Vector3(-1.0, stall.roof_y() + ElevatorStall.TO_LANDING - 0.4, 0.45))
	check(stall.door_release.get_prompt(p) == "[E] Pull the door release", "at the top of the ladder: the landing door's release")
	await _press(level, stall.door_release)
	await _until(func(): return level.rides == 2, 300)
	check(level.rides == 2 and not stall.stalled and lift_contains(level.lift_to, p), "pulling it ends the ride: everyone, even up in the shaft, steps out at the floor")
	# Once only: the next ride runs.
	check(not stall.should_stall(), "it stalls once, then rides normally")
	# The pry: Movement's PryDoors, stood in by a stub with its signal and `enabled`.
	var pry := PryStub.new()
	var climb := ClimbStub.new()
	stall.link_pry(pry)
	stall.link_hatch_climb(climb)
	check(not pry.enabled and not climb.active, "Movement's pry and hatch climb are off while the lift isn't stuck")
	stall.arm()
	lift.riding = false
	p.global_position = lift.to_global(Vector3(0, 0.1, 1.0))
	lift.open(true)
	await _frames(2)
	var hows := []
	stall.released_by.connect(func(how): hows.append(how))
	level._ride()
	await _until(func(): return stall.stalled, 600)
	check(pry.enabled and climb.active, "stuck: the pry is on, and the hatch (still open from before) can be climbed")
	pry.pried_open.emit()
	await _until(func(): return level.rides == 3, 300)
	check(level.rides == 3 and hows == ["pry"] and lift_contains(level.lift_to, p), "prying the doors open ends it the same way")
	check(not pry.enabled and not climb.active, "and the pry and climb switch off again")
	pry.free()
	climb.free()
	# A condition from the run's choices: its fuse pulled for another puzzle.
	stall.when(func(): return not level.fuses.is_live("VENDING"))
	check(not stall.should_stall(), "a condition stalls it only when the run's choices say so")
	await _press(level, level.fuses.slot("VENDING"))
	check(stall.should_stall(), "pull that fuse, and the next ride sticks")
	await _free(level)


class PryStub extends Node:
	signal pried_open
	var enabled := true


class ClimbStub extends Node:
	var active := true


func lift_contains(e: Elevator, p: Node3D) -> bool:
	return e.contains(p.global_position)


func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await t.physics_frame
	return cond.call()


func test_every_piece_sounds() -> void:
	var level = await _bench()
	var bad := []
	var count := 0
	for n in level.find_children("*", "", true, false):
		if n is KitPiece:
			count += 1
			var sound := SfxTouch.sound_of(SfxTouch.kind_of(n))
			if sound == "" or not Sfx.KINDS.has(sound) or Sfx.stream(sound) == null:
				bad.append(n.name)
	check(count >= 20 and bad.is_empty(), "all %d kit pieces have a sound (none: %s)" % [count, bad])
	level.player.inventory.add("screwdriver")
	level.kit.set_meta("sounds_played", [])
	await _press(level, level.gears)
	var played: Array = level.kit.get_meta("sounds_played", [])
	check(played.any(func(s): return s.kind == "clatter"), "jamming gears clatters, where they are")
	check(level.gears.get_node_or_null("Loop_gears") != null and Sfx.stream("gears") != null, "turning gears grind")
	await _free(level)


func test_coop() -> void:
	print("Co-op: the kit with a host and a client")
	_game().new_run(11)
	var worlds: Array = await t._coop_worlds(1)
	var machines: Array = await t._coop_load(worlds, BENCH)
	var host = machines[0]
	var client = machines[1]
	for l in machines:  # one process plays every machine: give each its own inventory, as on real machines
		l.player.inventory = Inventory.new()
	check(machines.all(func(l): return l.sync._begun and l.players.count() == 2 and l.patch.jack_labels == host.patch.jack_labels),
		"both machines start the bench with the same jack order")
	client.gear["keyboard"].interact(client.player)
	await _frames(10)
	check(client.player.inventory.has("keyboard") and not host.player.inventory.has("keyboard") and machines.all(func(l): return l.gear["keyboard"].taken),
		"a client takes the keyboard: it's theirs, and gone on every machine")
	host.gear["keyboard"].interact(host.player)
	await _frames(10)
	check(not host.player.inventory.has("keyboard"), "and nobody else can take it")
	client.player.inventory.add("screwdriver")
	await _frames(30)
	client.gears.interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return l.gears.jammed and l.shutter.jammed) and not client.player.inventory.has("screwdriver")
		and is_equal_approx(host.shutter.openness, client.shutter.openness), "a client jams the gears: the shutter stops at the same height everywhere")
	host.gears.interact(host.player)
	await _frames(10)
	check(machines.all(func(l): return not l.gears.jammed) and host.player.inventory.has("screwdriver") and not client.player.inventory.has("screwdriver"),
		"the host pulls the screwdriver out and it's the host's")
	await _frames(60)
	check(host.shutter.target == client.shutter.target, "the shutter's cycle follows the host on every machine")
	var cid: int = client.players.id_of(client.player)
	client.patch.ports[0].interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return l.patch.holding.get(cid, -1) == 0), "a client takes a lead, seen on every machine")
	client.patch.jacks[client.patch.jack_labels.find(client.patch.labels[0])].interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return l.patch.is_linked(l.patch.labels[0])), "and plugs it in everywhere")
	client.fuses.slot("VENDING").interact(client.player)
	await _frames(10)
	client.fuses.slot("TERMINALS").interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return l.fuses.is_live("TERMINALS") and not l.fuses.is_live("VENDING")) and not client.player.inventory.has("fuse"),
		"a client moves a fuse, and every machine's circuits follow")
	client.terminal.interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return l.rig.missing.has("power")), "the power button does nothing anywhere without a cord")
	client.gear["power_cord"].interact(client.player)
	await _frames(10)
	client.rig.parts["power_cord"].interact(client.player)
	await _frames(10)
	client.terminal.interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return not l.rig.missing.has("power") and not l.rig.missing.has("power_cord")), "a client plugs in the cord and switches it on, for everyone")
	# The stuck lift: the host arms it, a client gets everyone out by the roof.
	for l in machines:
		l.player.global_position = l.lift.to_global(Vector3(0, 0.1, 1.0))
		l.lift.open(true)
	await _frames(5)
	host.sync.event("_arm_stall")
	host.sync.event("_ride")
	check(await _until(func(): return machines.all(func(l): return l.stall.stalled), 600), "the lift sticks on every machine")
	client.stall.hatch.interact(client.player)
	await _frames(10)
	check(machines.all(func(l): return l.stall.hatch.is_open), "a client pushes the hatch open for everyone")
	client.player.global_position = client.lift.to_global(Vector3(-1.0, client.stall.roof_y() + ElevatorStall.TO_LANDING - 0.4, 0.45))
	await _frames(5)
	client.stall.door_release.interact(client.player)
	check(await _until(func(): return machines.all(func(l): return l.rides == 1 and not l.stall.stalled), 300)
		and machines.all(func(l): return l.lift_to.contains(l.player.global_position)), "the client pulls the release: the ride ends on every machine, with each player at the floor")
	await t._coop_close(worlds)
