extends RefCounted
## The whole building's data, the way the World loads it: every floor's seed added
## to one database in route order. A floor's puzzle answers must come out the same
## there as on the floor's own data, or something an earlier floor left in a shared
## table (door_controllers, doors, badges...) changes what the right query returns.
## Run in the route_data group.

var t: SceneTree
var _check: Callable
const SEEDS := 24
## Answers that may differ in the building, by puzzle id, and a value only the
## building's answer shows. Each is checked to still show, so none goes stale.
const KNOWN := {
	# Every light that's out, building-wide: floor G's dead East corridor is out too,
	# and SYSOP's "that's every light that's out" stays true.
	"dark_room": "East corridor",
	# The main entrance (floor G's LOBBY-FRONT, locked behind the crew) is a door that
	# won't release too, and SYSOP's line names it as another floor's.
	"stuck_doors": "Main entrance",
}


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("The whole building's data, in route order")
	await test_lab_after_server_floor()
	await test_every_floor_in_route_order()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


func _game() -> Node:
	return t.root.get_node("/root/Game")


## Teaching's case: Secure Lab B (floor 22) adds its door controllers to the table
## floor 14 already filled. Its answer must be one row, its own, whatever floor 14 did.
func test_lab_after_server_floor() -> void:
	var one_row := 0
	var own_ids := 0
	var rekey_spares := 0
	for s in 200:
		var db := FacilityDB.new()
		db.add_wing("level_0", Level0Data.build(s).sql)
		var f14: Dictionary = Level1Data.build(s)
		db.add_wing("level_1", f14.sql)
		# Floor 14 played: its faulted controller was reset at the rack.
		db.run_silent("UPDATE door_controllers SET status = 'ok' WHERE id = '%s'" % f14.answer)
		var f22: Dictionary = Level2Data.build(s)
		db.add_wing("level_2", f22.sql)
		var rows: Array = db.run_silent("SELECT id FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % f22.lab_zone)
		if rows.size() == 1 and rows[0].id == f22.lab_answer:
			one_row += 1
		var ids: Array = db.run_silent("SELECT id FROM door_controllers GROUP BY id HAVING COUNT(*) > 1")
		if ids.is_empty():
			own_ids += 1
		# Caught and re-keyed: the lab's rows move zone, and floor 14's stay.
		var before: int = db.run_silent("SELECT COUNT(*) AS n FROM door_controllers WHERE zone IN ('A', 'B', 'C', 'D', 'E', 'F')")[0].n
		var k: Dictionary = Level2Data.lab_rekey(s, 1, f22.lab_zone)
		db.run_silent(k.sql)
		var after: int = db.run_silent("SELECT COUNT(*) AS n FROM door_controllers WHERE zone IN ('A', 'B', 'C', 'D', 'E', 'F')")[0].n
		var again: Array = db.run_silent("SELECT id FROM door_controllers WHERE zone = '%s' AND status = 'fault'" % k.zone)
		if before == after and again.size() == 1 and again[0].id == k.answer:
			rekey_spares += 1
	check(one_row == 200, "after floor 14, the lab's query finds exactly the lab's door, every seed (%d/200)" % one_row)
	check(own_ids == 200, "no controller id is used twice in the building (%d/200)" % own_ids)
	check(rekey_spares == 200, "a re-key moves only the lab's controllers, and its query still finds one row (%d/200)" % rekey_spares)


## Every floor in route order, as the World builds them: each floor's puzzle answers
## with the floors before it in the database match its answers on its own data. (A
## floor builds the next one ahead only as its own story ends.)
func test_every_floor_in_route_order() -> void:
	var clashes := {}
	var checked := {}
	var known_seen := {}
	for s in SEEDS:
		_game().new_run(s + 1)
		_game().open_at_home = false
		var world = load("res://scenes/world.tscn").instantiate()
		t.root.add_child(world)
		for i in 3:
			await t.physics_frame
		var puzzles := {}  # route index -> {id: Puzzle}
		var alone := {}  # route index -> FacilityDB with only that floor's data
		for k in range(0, World.ROUTE.size()):
			var wing: LevelBase = world.load_wing(k)
			puzzles[k] = _puzzles_of(wing)
			alone[k] = _alone(k)
			_compare(world, k, puzzles[k], alone[k], clashes, checked, known_seen)
		world.queue_free()
		await t.process_frame
	var floors: Array = checked.keys()
	floors.sort()
	check(floors.size() >= 6, "the sweep checks puzzle answers on most floors (%s)" % ", ".join(floors))
	var lines := []
	for key in clashes:
		lines.append("%s: %s" % [key, clashes[key]])
	check(clashes.is_empty(), "every floor's answers come out the same with the floors before it loaded, over %d seeds%s" % [SEEDS, "" if lines.is_empty() else ":\n    " + "\n    ".join(lines)])
	for id in KNOWN:
		check(known_seen.has(id), "the known difference in '%s' (%s) still shows, so it isn't skipped for nothing" % [id, KNOWN[id]])


## Floor `k`'s seed on a database of its own, as when the floor runs alone.
func _alone(k: int) -> FacilityDB:
	var s: int = _game().run_seed
	var data: Dictionary
	match k:
		0: data = Level0Data.build(s)
		1: data = Level1Data.build(s)
		2: data = Level2Data.build(s)
		3: data = Level3Data.build(s)
		4: data = Level4Data.build(s, _game().ticket_number())
		5: data = Level5Data.build(s)
		6: data = Level6Data.build(s)
		7: data = Level7Data.build(s)
	var db := FacilityDB.new()
	db.load_seed(data.sql)
	if data.has("gates_sql"):  # floor 10 adds its gates as it builds
		db.run_silent(data.gates_sql)
	return db


## Every SELECT puzzle the wing (or a node in it) holds, by id.
func _puzzles_of(wing: Node) -> Dictionary:
	var out := {}
	var stack: Array = [wing]
	while not stack.is_empty():
		var n: Object = stack.pop_back()
		for prop in n.get_property_list():
			if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var v = n.get(prop.name)
			var items: Array = v if v is Array else [v]
			for item in items:
				if item is Puzzle and _is_read(item.solution_sql):
					out[item.id] = item
		if n is Node:
			for c in n.get_children():
				if c.get_script() != null:
					stack.append(c)
	return out


static func _is_read(sql: String) -> bool:
	var head := sql.strip_edges().to_upper()
	return head.begins_with("SELECT") or head.begins_with("WITH")


func _compare(world: Node, k: int, puzzles: Dictionary, alone: FacilityDB, clashes: Dictionary, checked: Dictionary, known_seen: Dictionary) -> void:
	var key: String = World.ROUTE[k].key
	for id in puzzles:
		var p: Puzzle = puzzles[id]
		var shapes := [{"sql": p.solution_sql, "ordered": p.ordered}]
		for alt in p.alternatives:
			if _is_read(alt.sql):
				shapes.append({"sql": alt.sql, "ordered": alt.ordered})
		for shape in shapes:
			var here = _rows(world.db, shape.sql, shape.ordered)
			var own = _rows(alone, shape.sql, shape.ordered)
			if own == null or here == null:
				continue  # needs a table the floor makes in play, not in its seed
			checked[key] = true
			if here == own:
				continue
			if KNOWN.has(id) and str(here).contains(KNOWN[id]):
				known_seen[id] = true
				continue
			var tag := "%s %s" % [key, id]
			if not clashes.has(tag):
				clashes[tag] = "seed %d: alone %s, in the building %s" % [_game().run_seed, str(own).left(160), str(here).left(160)]


## The query's rows as strings, sorted unless order matters; null if it fails.
static func _rows(db: FacilityDB, sql: String, ordered: bool):
	var res: Dictionary = db.execute(sql)
	if not res.ok:
		return null
	var out := []
	for r in res.rows:
		out.append(str(r))
	if not ordered:
		out.sort()
	return out
