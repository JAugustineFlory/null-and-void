extends RefCounted
## Lost-player walkthroughs. A "lost player" knows no SQL. It remembers everything it
## was taught, and never guesses. It may use only:
##   - the cumulative taught set: every terminal line and sticky note it has seen in
##     earlier puzzles and levels (each one a line it could have saved with "write note"),
##   - what is on the terminal screen and in the world around it right now.
## It types only queries written out in full on the screen, and asks .hint when it runs
## out of those. tests/curriculum.gd declares what each puzzle teaches and needs: a
## puzzle fails if it needs something outside the taught set before any hint, or if
## something it teaches never appears on a terminal line or sticky note. Physical steps
## (a rack, a PIN, a breaker) must be readable off the screen. Plays Levels 0-2 in order
## so the taught set carries between levels. Owned by the Teaching and UX thread.
##
## Known teaching gaps are reported as GAP lines instead of failures, so the suite
## stays green while the owning thread fixes them. When a gap is fixed, its check
## prints FIXED: move it to a normal check() then.

const KEYWORDS := ["SELECT", "FROM", "WHERE", "AND", "OR", "ORDER BY", "LIKE", "LIMIT", "COUNT", "GET"]

var t: SceneTree
var _check: Callable
var gaps := 0
const Curriculum := preload("res://tests/curriculum.gd")

## Everything the player has been shown so far on terminals and sticky notes: the
## lines it could have written into its notebook. It remembers all of it.
var taught := ""
## keyword -> "safe" or "threat": how the player was placed when it first had to use it.
var first_use := {}
var used_under_threat := {}


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	print("Teaching: lost-player walkthroughs")
	taught = ""
	first_use.clear()
	used_under_threat.clear()
	test_first_hints_explain_every_keyword()
	await walk_level_0()
	for s in [7, 23]:
		await walk_level_1(s)
	for s in [11, 42]:
		await walk_level_2(s)
	check_teaching_order()
	if gaps > 0:
		print("  (%d known teaching gap%s, see docs/teaching/audit-levels-0-2.md)" % [gaps, "" if gaps == 1 else "s"])


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


## A known gap: printed, not failed, until the owning thread fixes it.
func gap(ok: bool, name: String) -> void:
	if ok:
		print("  FIXED ", name, "  (promote this to a normal check)")
	else:
		gaps += 1
		print("  GAP   ", name)


func _game() -> Node:
	return t.root.get_node("/root/Game")


# --- What the player can see ------------------------------------------------

func screen(ui: TerminalUI) -> String:
	return ui._output.get_parsed_text()


## Text written in the world: signs, sticky notes, labels, plus the objective line.
func world_text(level: Node) -> String:
	var parts := PackedStringArray()
	for n in level.find_children("*", "Label3D", true, false):
		parts.append(n.text)
	parts.append(level.hud._objective.text)
	return "\n".join(parts)


## Full queries written out on screen, in order: a SELECT line up to its ;, or a
## GET line's verb and path. Lines that explain a keyword ("SELECT *   every column")
## have no ; and aren't typed.
func queries_in(text: String) -> Array[String]:
	var out: Array[String] = []
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		var upper := line.to_upper()
		if upper.begins_with("SELECT ") and line.contains(";"):
			out.append(line.substr(0, line.find(";") + 1))
		elif upper.begins_with("GET /"):
			out.append(" ".join(line.split(" ", false).slice(0, 2)))
	return out


func keywords_in(text: String) -> Array:
	# Case-sensitive on purpose: screens write SQL in capitals, so prose like "and"
	# or "from" doesn't count as having shown the keyword.
	var found := []
	for k in KEYWORDS:
		if RegEx.create_from_string("\\b" + k.replace(" ", "\\s+") + "\\b").search(text):
			found.append(k)
	return found


## Remember every line on this screen and every sign in view (write-note candidates).
func remember(level: Node, ui: TerminalUI) -> void:
	for line in (screen(ui) + "\n" + world_text(level)).split("\n"):
		if line.strip_edges() != "" and not taught.contains(line):
			taught += line + "\n"


## Is this curriculum item in the text? Keywords match as capitalised words.
func has_item(text: String, item: String) -> bool:
	if KEYWORDS.has(item):
		return keywords_in(text).has(item)
	return text.contains(item)


## Parse the last result table printed on screen into rows of {column: text}.
func last_table(text: String) -> Array:
	var lines := text.split("\n")
	var rule := -1
	for i in range(lines.size() - 1, 0, -1):
		if RegEx.create_from_string("^-[-+]*$").search(lines[i].strip_edges()):
			rule = i
			break
	if rule < 1:
		return []
	var cols: Array = Array(lines[rule - 1].split("|")).map(func(c): return c.strip_edges())
	var rows := []
	for i in range(rule + 1, lines.size()):
		if lines[i].begins_with("("):
			break
		var cells: Array = Array(lines[i].split("|")).map(func(c): return c.strip_edges())
		var row := {}
		for c in cols.size():
			row[cols[c]] = cells[c] if c < cells.size() else ""
		rows.append(row)
	return rows


func find_interactable(level: Node, prompt_part: String) -> Interactable:
	for n in level.find_children("*", "", true, false):
		if n is Interactable and n.prompt.contains(prompt_part):
			return n
	return null


func has_world_label(level: Node, text: String) -> bool:
	for n in level.find_children("*", "Label3D", true, false):
		if n.text.strip_edges() == text:
			return true
	return false


# --- The lost player -------------------------------------------------------

## Try every full query written on this screen, then ask for hints, until the
## puzzle is solved. Returns how many hints it needed (-1: stuck). Before the first
## hint, everything the puzzle needs must be taught already or on screen now; after
## it's solved, everything it teaches must have been on a terminal line or sticky note.
func solve(level: Node, ui: TerminalUI, puzzle: Puzzle, threat: bool, max_hints: int = 3) -> int:
	var tried := {}
	var hints := 0
	var spec: Dictionary = Curriculum.PUZZLES.get(puzzle.id, {})
	check(not spec.is_empty(), "%s: tests/curriculum.gd says what it teaches and needs" % puzzle.id)
	var needed: Array = spec.get("needs", [])
	var missing := []
	for k in keywords_in(_answer_query(puzzle)):
		if not needed.has(k):
			missing.append(k)
	check(missing.is_empty(), "%s: its curriculum needs list covers every keyword in the answer%s" % [puzzle.id, "" if missing.is_empty() else " (add %s)" % ", ".join(missing)])
	if spec.has("pressure"):
		check(threat == spec.pressure, "%s: %s while it's typed, as tests/curriculum.gd says" % [puzzle.id, "something can hunt the player" if spec.pressure else "nothing can hurt the player"])
	var outside := []
	while not puzzle.solved:
		remember(level, ui)
		var text := screen(ui)
		var fresh: Array[String] = []
		# The notebook is reference, not a script: old queries name other levels'
		# tables, so the player only types what this screen shows.
		for q in queries_in(text):
			if not tried.has(q) and not fresh.has(q):
				fresh.append(q)
		if fresh.is_empty():
			if hints == 0:
				for k in needed:
					if not has_item(taught, k):
						outside.append(k)
			if hints >= max_hints:
				check(false, "%s: a lost player gets stuck even after %d hints" % [puzzle.id, hints])
				return -1
			hints += 1
			ui.run(".hint")
			continue
		for q in fresh:
			tried[q] = true
			ui.run(q)
			if puzzle.solved:
				break
	remember(level, ui)
	for k in needed:
		if not KEYWORDS.has(k):
			continue
		if not first_use.has(k):
			first_use[k] = "threat" if threat else "safe"
		if threat:
			used_under_threat[k] = true
	check(outside.is_empty(), "%s: everything it needs was taught before any hint%s" % [puzzle.id, "" if outside.is_empty() else " (never shown: %s)" % ", ".join(outside)])
	var unoffered := []
	for k in spec.get("teaches", []):
		if not has_item(taught, k):
			unoffered.append(k)
	check(unoffered.is_empty(), "%s: everything it teaches is on a terminal line or sticky note, ready to write down%s" % [puzzle.id, "" if unoffered.is_empty() else " (missing %s)" % ", ".join(unoffered)])
	return hints


## The query the first hint spells out: the answer a player is expected to type.
func _answer_query(p: Puzzle) -> String:
	var queries := queries_in(p.hints[0].replace("[color=#ffffff]", "").replace("[/color]", ""))
	return queries[0] if not queries.is_empty() else p.solution_sql


# --- Rules on every first hint ----------------------------------------------

func test_first_hints_explain_every_keyword() -> void:
	var l0 = load("res://scripts/levels/level_0.gd").new()
	var l1 = load("res://scripts/levels/level_1.gd").new()
	var l2 = load("res://scripts/levels/level_2.gd").new()
	var all: Array = [l0.peek_puzzle, l0.memo_puzzle, l1.controller_puzzle, l2.cameras_puzzle, l2.pike_puzzle, l2.har_puzzle, l2.door_puzzle]
	for p in all:
		var hint: String = p.hints[0].replace("[color=#ffffff]", "").replace("[/color]", "")
		var q := _answer_query(p)
		var explained := true
		var missing := []
		for k in keywords_in(q):
			var has_line := false
			for line in hint.split("\n"):
				if not line.contains(";") and line.strip_edges() != q and keywords_in(line).has(k):
					has_line = true
			if not has_line:
				explained = false
				missing.append(k)
		check(q != "" and explained, "%s: first hint is the exact query with a line for each keyword%s" % [p.id, "" if explained else " (missing %s)" % ", ".join(missing)])
	for p in all:
		var real := true
		for h in p.hints.slice(1):
			real = real and not RegEx.create_from_string("(?i)\\b(employees|customers|users|students|orders)\\b").search(h)
		check(real, "%s: later hints use the real tables, never an example one" % p.id)
	l0.free()
	l1.free()
	l2.free()


# --- Level 0: the lobby -----------------------------------------------------

func walk_level_0() -> void:
	_game().new_run(5)
	var level = load("res://scenes/level_0.tscn").instantiate()
	t.root.add_child(level)
	for i in 20:
		await t.physics_frame
	var ui: TerminalUI = level.terminal_ui
	ui.open(level.desk_terminal, level.player)
	var h := solve(level, ui, level.peek_puzzle, false)
	check(h == 0, "lobby: the boot screen alone gets a new player through the first query (hints %d)" % h)
	h = solve(level, ui, level.memo_puzzle, false)
	check(h >= 0 and h <= 1, "lobby: a lost player sorts the memo with at most the first hint (hints %d)" % h)
	check(screen(ui).contains("RECONSTRUCTED"), "lobby: the memo reads back in order on screen")
	ui.close()
	level.queue_free()
	await t.process_frame


# --- Level 1: Server Room A -------------------------------------------------

func walk_level_1(seed_value: int) -> void:
	_game().new_run(seed_value)
	var level = load("res://scenes/level_1.tscn").instantiate()
	t.root.add_child(level)
	for i in 20:
		await t.physics_frame
	level.rourke.state = Rourke.State.IDLE
	level._on_rourke_resolved("tied")
	var ui: TerminalUI = level.terminal_ui
	ui.open(level.terminal, level.player)
	check(screen(ui).contains("door_controllers") and screen(ui).contains("zone A"), "server room: the self-test names the table and both clues on screen")
	var h := solve(level, ui, level.controller_puzzle, false)
	check(h >= 0 and h <= 1, "server room: a lost player finds the controller with at most the first hint (hints %d)" % h)
	# Read the answer off the result table, then find that rack in the room.
	var rows := last_table(screen(ui))
	var id: String = rows[0].get("id", "") if rows.size() == 1 else ""
	check(id != "" and has_world_label(level, id), "server room: the result names one controller, and a rack is labelled %s" % id)
	ui.close()
	var panel := find_interactable(level, "Reset controller " + id)
	check(panel != null, "server room: that rack has a reset panel the player can press")
	if panel:
		panel.interact(level.player)
	for i in 5:
		await t.physics_frame
	check(level.doors["SRA-EXIT"].is_open, "server room: resetting the controller read off the screen opens the exit")
	level.queue_free()
	await t.process_frame


# --- Level 2: Security Office -----------------------------------------------

func walk_level_2(seed_value: int) -> void:
	_game().new_run(seed_value)
	var level = load("res://scenes/level_2.tscn").instantiate()
	t.root.add_child(level)
	for i in 20:
		await t.physics_frame
	var ui: TerminalUI = level.terminal_ui
	var p: Player = level.player
	p.local_control = false
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-3, 0.1, 4.6))  # at the booth
	ui.open(level.booth, p)
	var h := solve(level, ui, level.cameras_puzzle, level.loose)
	check(h == 0, "security: the boot screen gets a new player through GET /cameras (hints %d)" % h)
	h = solve(level, ui, level.pike_puzzle, level.loose)
	check(h == 0, "security: LIKE is practised on Pike from the query on screen, safely (hints %d)" % h)
	check(level.loose, "security: finding Pike freezes CAM-2 (the pressure starts)")
	# Pressure means the Watcher can actually hunt: it wakes when the office opens.
	var hunting: bool = level.watcher.active
	level.watcher.active = false  # keep the walkthrough deterministic from here
	# The Har query isn't written out: the player builds it from LIKE plus AND, both
	# taught by now (the solve() check enforces it). A lost player who can't gets it
	# from the first hint.
	h = solve(level, ui, level.har_puzzle, hunting)
	check(h >= 0 and h <= 1, "security: a lost player finds the PIN with at most the first hint (hints %d)" % h)
	var rows := last_table(screen(ui))
	var pin: String = rows[0].get("pin", "") if rows.size() == 1 else ""
	check(pin.length() == 4, "security: the result shows one guard and their PIN")
	ui.close()

	# Curious players check the door panel before the PIN: its boot text invites it.
	ui.open(level.panel, p)
	ui.run("GET /doors/SEC-EXIT")
	remember(level, ui)
	ui.close()

	# The main path: the PIN opens the office door, then the stairwell keypad past the Watcher.
	var office_pad := find_interactable(level, "Enter guard PIN (office door)")
	check(office_pad != null, "security: the office door's keypad is labelled for a guard PIN")
	office_pad.interact(p)
	level.keypad_ui._on_submit(pin)
	check(level.office_open, "security: the PIN read off the screen opens the Security Office")
	hunting = level.watcher.active
	level.watcher.active = false
	var keypad := find_interactable(level, "Enter guard PIN (SEC-EXIT)")
	check(keypad != null, "security: the stairwell keypad is labelled for a guard PIN")
	keypad.interact(p)
	level.keypad_ui._on_submit(pin)
	check(level.pin_entered and not level.door_open, "security: the PIN read off the screen is accepted, and the door lies")

	# The door didn't open. The player goes back to the panel and asks for help.
	ui.open(level.panel, p)
	ui.run(".hint")
	var hint_text := screen(ui).get_slice("WARDEN:", screen(ui).count("WARDEN:"))
	check(hint_text.contains("B-") or hint_text.to_lower().contains("breaker"),
		"security: .hint at the panel still helps after the door lies, even if the player checked the door earlier (says: %s)" % hint_text.strip_edges().left(60))
	var before := screen(ui).length()
	for q in queries_in(screen(ui)):
		ui.run(q)
		if level.door_checked:
			break
	var after := screen(ui).substr(before)
	var m := RegEx.create_from_string("B-(\\d)").search(after)
	check(m != null, "security: re-checking the door shows which breaker tripped")
	ui.close()
	var breaker := find_interactable(level, "Reset breaker " + (m.get_string() if m else "?"))
	check(breaker != null, "security: that breaker is labelled in the box")
	if breaker:
		breaker.interact(p)
	for i in 5:
		await t.physics_frame
	check(level.doors["SEC-EXIT"].is_open, "security: the breaker read off the screen opens SEC-EXIT")
	# The door puzzle counts as solved once the door really opens: check what it taught.
	ui.open(level.panel, p)
	solve(level, ui, level.door_puzzle, hunting)
	ui.close()

	# Dying to the Watcher should tell you why it could move.
	level.loose = true
	level.hud._notice.text = ""
	level.on_player_died()
	var said: String = level.hud._notice.text.to_lower() + level.hud._objective.text.to_lower()
	check(said.contains("camera") or said.contains("frozen") or said.contains("last_frame"),
		"security: after the Watcher gets you, the screen says why it could move (a camera froze)")
	level.queue_free()
	await t.process_frame


# --- Found, practised safely, then used under pressure -----------------------

func check_teaching_order() -> void:
	var threat_first := []
	for k in first_use:
		if first_use[k] == "threat":
			threat_first.append(k)
	check(threat_first.is_empty(), "every keyword is first needed somewhere safe, never first under threat%s" % ("" if threat_first.is_empty() else " (%s)" % ", ".join(threat_first)))
	var never := []
	for k in first_use:
		if not used_under_threat.has(k):
			never.append(k)
	# Not a failure in Levels 0-2: later levels must bring these back under pressure.
	print("  INFO  taught but not yet used under pressure: %s" % (", ".join(never) if not never.is_empty() else "none"))
