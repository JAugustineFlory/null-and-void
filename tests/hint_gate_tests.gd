extends RefCounted
## `.hint` starts in the world (spec G2, plan/teaching/puzzle-flow-v0.10.md
## section 3): its first tier names the spot for the first piece the crew still
## lacks, and the tiers go on only once someone has found it. And the crew's
## commentary, which no floor played before, can be turned on for a floor
## (LevelBase.start_commentary).

var _tree: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check
	await test_hint_spots()
	await test_commentary_hook()
	await test_floor_g()


func _game() -> Node:
	return _tree.root.get_node("/root/Game")


func _frames(n: int) -> void:
	for i in n:
		await _tree.physics_frame


func _last_line(term: Node) -> String:
	return TerminalUI._plain(term.transcript[term.transcript.size() - 1])


func test_hint_spots() -> void:
	print("Hints start in the world")
	var g := _game()
	g.new_run(21)
	check(g.spots_found.is_empty() and g.find_spot("a") and not g.find_spot("a") and g.spot_found("a"), "a spot is found once, and stays found")
	g.new_run(21)
	check(not g.spot_found("a"), "a new run starts with none found")
	# The puzzle on its own: spots in order, skipping one found or whose piece is in hand.
	var p := Puzzle.new("t", "SELECT 1;", [], false, ["tier one", "tier two", "tier three"])
	p.case_id = "t_case"
	p.spots = [{"id": "card", "text": "the card", "piece": "table"}, {"id": "phone", "text": "the phone"}]
	g.open_case("t_case", "Test case")
	g.set_pieces("t_case", [{"id": "table", "label": "The table", "value": "memo_fragments", "task": "Find the table", "where": "The card"}], "SELECT * FROM {table};")
	check(p.spot_hint(g) == "the card", "the first tier names the spot for the first piece still missing")
	g.collect_piece("t_case", "table", "somewhere else")
	check(p.spot_hint(g) == "the phone", "a spot whose piece is already in hand is skipped")
	g.find_spot("phone")
	check(p.spot_hint(g) == "", "with every spot found, there's no world tier")
	# At a terminal: .hint gives the spot until someone finds it, then the tiers.
	g.new_run(21)
	var level = load("res://scenes/level_0.tscn").instantiate()
	_tree.root.add_child(level)
	await _frames(12)
	var term: Node = level.desk_terminal
	var pz: Puzzle = null
	for q in term.puzzles:
		if not q.solved:
			pz = q
			break
	check(pz != null, "the desk terminal has a puzzle to hint at")
	if pz == null:
		level.queue_free()
		return
	pz.spots = [{"id": "test_card", "text": "The scanner came with a quick-start card."}, {"id": "schema:visitors", "text": "Type .schema, a space and the table's name."}]
	pz.hint_index = 0
	var ui: TerminalUI = level.terminal_ui
	ui.open(term, level.player)
	ui.run(".hint")
	check(_last_line(term).contains("The scanner came with a quick-start card.") and pz.hint_index == 0, ".hint first points at the spot, without using up a tier")
	ui.run(".hint")
	check(_last_line(term).contains("quick-start card") and pz.hint_index == 0, "and keeps pointing there until someone finds it")
	var card := Document.place(level.geo, Vector3(1, 1, 1), 0.0, "Test card", [{"text": "Step 1"}], false)
	card.spot = "test_card"
	card.report_open(level.player)
	check(g.spot_found("test_card"), "reading the paper that is the spot finds it")
	ui.run(".hint")
	check(_last_line(term).contains(".schema") and pz.hint_index == 0, "then .hint moves on to the next spot")
	ui.run(".schema visitors")
	check(g.spot_found("schema:visitors"), "running .schema on a table finds that table's spot")
	ui.run(".hint")
	check(pz.hint_index == 1 and _last_line(term).contains(TerminalUI._plain(pz.hints[0]).left(20)), "with every spot found, the tiers go on as before")
	ui.close()
	level.queue_free()
	await _tree.process_frame


func test_commentary_hook() -> void:
	print("The crew's commentary, turned on for a floor")
	var g := _game()
	g.new_run(22)
	var level = load("res://scenes/level_0.tscn").instantiate()
	_tree.root.add_child(level)
	await _frames(12)
	var first: Commentary = level.commentary
	check(first != null and first.is_in_group(Commentary.GROUP) and level.start_commentary() == first, "the ground floor turns its commentary on, once")
	# Started again with a case already solved, as on a floor reached with cases behind it.
	first.queue_free()
	level.commentary = null
	await _tree.process_frame
	g.open_case("memo", "Old case")
	g.solve_case("memo", "done")
	var c: Commentary = level.start_commentary()
	check(c != null and c != first and level.start_commentary() == c, "start_commentary makes one Commentary for the floor")
	check(not _pay("peek").any(func(l): return c.played.has(l)), "a case solved before it started plays no payoff")
	g.open_case("caller", "Who called?")
	await _frames(1)
	check(g.main_case() != "caller" or c.case_id == "caller", "it follows the case being worked on (%s)" % c.case_id)
	var on := c.case_id
	var term: Node = level.desk_terminal
	var ui: TerminalUI = level.terminal_ui
	ui.open(term, level.player)
	ui.run("SELECT * FROM no_such_table;")
	ui.run("SELECT * FROM no_such_table;")
	check(on == "" or c.fails >= 2, "it hears failed queries at the floor's terminals")
	ui.run(".hint")
	check(c.sysop_helped, "and .hint")
	ui.close()
	var doc := Document.place(level.geo, Vector3(1, 1, 1), 0.0, "HALCYON STAFF DIRECTORY", [{"text": "Front desk 1001"}], false)
	c.watch_documents(level)
	doc.report_open(level.player)
	check(c.seen.has("HALCYON STAFF DIRECTORY"), "and every paper read")
	if on != "":
		g.solve_case(on, "found")
		check(_pay(on).all(func(l): return c.played.has(l)), "a case solved plays its payoff")
	level.queue_free()
	await _tree.process_frame


## Floor G's hints start at its spots (G26-G30), and its commentary follows its
## cases under the puzzles' own ids.
func test_floor_g() -> void:
	print("Floor G: hints start in the world, and the crew talks")
	var g := _game()
	g.new_run(23)
	var level = load("res://scenes/level_0.tscn").instantiate()
	_tree.root.add_child(level)
	await _frames(12)
	var k: Dictionary = level.get_script().get_script_constant_map()
	var term: Node = level.desk_terminal
	check(term.next_hint() == k.SPOT_CARD, "the first .hint on G sends the crew to the scanner's card (G26)")
	var card: Document = null
	for d in level.find_children("*", "Document", true, false):
		if d.spot == "scan_card":
			card = d
	check(card != null, "the scanner's card is that spot")
	if card:
		card.report_open(level.player)
	check(g.spot_found("scan_card") and term.next_hint() != k.SPOT_CARD, "once it's read, .hint goes on to the tiers")
	check(level.caller_puzzle.spots[0].text == k.SPOT_SCHEMA and level.visitor_puzzle.spots[1].text == k.SPOT_NIGHT_DESK, "the caller and visitor cases start at .schema and the night desk's stickies (G29, G30)")
	var c: Commentary = level.commentary
	check(c != null, "G's commentary is on")
	g.open_case("memo", "What does the memo say?", ["memo_fragments"], "Read it")
	await _frames(1)
	check(c.case_id == "peek", "the memo case is the commentary's peek (%s)" % c.case_id)
	level.comment("memo_scraps")
	check(c.played.has("l0_cc_memo_disc"), "the floor's own moments play their discovery lines")
	level.queue_free()
	await _tree.process_frame


static func _pay(id: String) -> Array:
	return Commentary.NUDGES.get(id, {}).get("pay", [])


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)
