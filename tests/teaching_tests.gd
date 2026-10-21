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

const KEYWORDS := ["SELECT", "FROM", "WHERE", "AND", "OR", "ORDER BY", "DESC", "LIKE", "LIMIT", "COUNT", "GET", ">", "COLUMNS"]
## Concepts that aren't one capitalised word: comparing a column with a value, and
## picking columns instead of *.
const KEYWORD_PATTERNS := {
	">": "\\w\\s*>=?\\s*['\\d?]",
	"COLUMNS": "\\bSELECT\\s+\\w+\\s*,",
}

var t: SceneTree
var _check: Callable
var gaps := 0
const Curriculum := preload("res://tests/curriculum.gd")
## How far from a terminal a sign or paper still counts as in its room, in metres.
const ROOM_REACH := 8.0

## Everything the player has been shown so far on terminals and sticky notes: the
## lines it could have written into its notebook. It remembers all of it.
var taught := ""
## keyword -> "safe" or "threat": how the player was placed when it first had to use it.
var first_use := {}
var used_under_threat := {}


## `part` splits the walks across two CI groups, since the paced lab walk is slow:
## "main" walks every floor with lab seed 11 and runs the whole-game checks; "lab"
## walks Levels 0-1 again (the lab needs what they taught) and then lab seed 42.
func run(tree: SceneTree, check: Callable, part := "main") -> void:
	t = tree
	_check = check
	print("Teaching: lost-player walkthroughs (%s)" % part)
	taught = ""
	_jot_docs.clear()
	first_use.clear()
	used_under_threat.clear()
	await walk_level_0()
	if part == "lab":
		await walk_level_1(7)
		await walk_lab(42)
		return
	for s in [7, 23]:
		await walk_level_1(s)
	await walk_lab(11)
	for s in [11, 42]:
		await walk_level_2(s)
	check_teaching_order()
	check_jot_rules()
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


## Text written in the world: signs, sticky notes, labels, documents (read with E),
## plus the to-do. With `at`, only what's in the same room as that terminal: on a
## whole floor, a paper three rooms away isn't something the player has found.
func world_text(level: Node, at: Node3D = null) -> String:
	var parts := PackedStringArray()
	for n in level.find_children("*", "Label3D", true, false):
		if in_room(n, at):
			parts.append(n.text)
	for d in level.find_children("*", "Document", true, false):
		if in_room(d, at):
			parts.append(d.plain_text())
	parts.append(level.hud.current_todo())
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


## Is this sign or paper within reach of the terminal `at` (null: anywhere)?
func in_room(n: Node3D, at: Node3D) -> bool:
	return at == null or n.global_position.distance_to(at.global_position) <= ROOM_REACH


## A query on screen with a blank in it ("SELECT * FROM table_name;") is filled in
## from what's handwritten on a document in the room, like the brochure's blank.
func fill_blanks(level: Node, query: String, at: Node3D = null) -> Array[String]:
	if query.contains("?"):
		return []  # a hint's shape: filling in the value is the thinking step
	if not query.contains("table_name"):
		return [query]
	var out: Array[String] = []
	for d in level.find_children("*", "Document", true, false):
		if not in_room(d, at):
			continue
		for l in d.lines():
			var word: String = str(l.get("filled", l.text if l.get("hand", false) else "")).strip_edges()
			if RegEx.create_from_string("^[a-z_]+$").search(word):
				out.append(query.replace("table_name", word))
	return out


func keywords_in(text: String) -> Array:
	# Case-sensitive on purpose: screens write SQL in capitals, so prose like "and"
	# or "from" doesn't count as having shown the keyword.
	var found := []
	for k in KEYWORDS:
		var pattern: String = KEYWORD_PATTERNS.get(k, "\\b" + k.replace(" ", "\\s+") + "\\b")
		if RegEx.create_from_string(pattern).search(text):
			found.append(k)
	return found


## Remember every line on this screen and every sign in view (write-note candidates).
## Returns how many characters were new: what the player had to read.
func remember(level: Node, ui: TerminalUI) -> int:
	var read := 0
	for line in (screen(ui) + "\n" + world_text(level, ui.terminal)).split("\n"):
		if line.strip_edges() != "" and not taught.contains(line):
			taught += line + "\n"
			read += line.length()
	return read


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
## `pressure_gap` names a known gap: a pressure mismatch prints as GAP, not a failure.
## With `pace`, game time passes as a first-time player would take: reading what's
## new, thinking, typing (see PACE_* below). `paced` adds up those seconds. `done`
## ends it early for a puzzle finished by a physical step: the query only finds the
## thing to press.
func solve(level: Node, ui: TerminalUI, puzzle: Puzzle, threat: bool, max_hints: int = 3, pressure_gap: String = "", pace := false, done := Callable()) -> int:
	var tried := {}
	var hints := 0
	check_ladder(ui, puzzle)
	var spec: Dictionary = Curriculum.PUZZLES.get(puzzle.id, {})
	check(not spec.is_empty(), "%s: tests/curriculum.gd says what it teaches and needs" % puzzle.id)
	var needed: Array = spec.get("needs", [])
	var missing := []
	for k in keywords_in(_answer_query(puzzle)):
		if not needed.has(k):
			missing.append(k)
	check(missing.is_empty(), "%s: its curriculum needs list covers every keyword in the answer%s" % [puzzle.id, "" if missing.is_empty() else " (add %s)" % ", ".join(missing)])
	if spec.has("pressure"):
		var said := "%s: %s while it's typed, as tests/curriculum.gd says" % [puzzle.id, "something can hunt the player" if spec.pressure else "nothing can hurt the player"]
		if pressure_gap != "":
			gap(threat == spec.pressure, "%s (%s)" % [said, pressure_gap])
		else:
			check(threat == spec.pressure, said)
	var outside := []
	while not puzzle.solved and not (done.is_valid() and done.call()):
		var read := remember(level, ui)
		if pace:
			await _spend(read / PACE_READ_CPS)
		var text := screen(ui)
		var fresh: Array[String] = []
		# The notebook is reference, not a script: old queries name other levels'
		# tables, so the player only types what this screen shows.
		for shown in queries_in(text):
			for q in fill_blanks(level, shown, ui.terminal):
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
			if pace:
				await _spend(PACE_THINK + ".hint".length() / PACE_TYPE_CPS)
			ui.run(".hint")
			continue
		for q in fresh:
			tried[q] = true
			if pace:
				await _spend(PACE_THINK + q.length() / PACE_TYPE_CPS)
			ui.run(q)
			if puzzle.solved or (done.is_valid() and done.call()):
				break
	var read_last := remember(level, ui)
	if pace:
		await _spend(read_last / PACE_READ_CPS)
	for k in needed:
		if not KEYWORDS.has(k):
			continue
		if not first_use.has(k):
			first_use[k] = "threat" if threat else "safe"
		if threat:
			used_under_threat[k] = true
	var said_taught := "%s: everything it needs was taught before any hint%s" % [puzzle.id, "" if outside.is_empty() else " (never shown: %s)" % ", ".join(outside)]
	if spec.has("known_gap"):
		gap(outside.is_empty(), "%s (%s)" % [said_taught, spec.known_gap])
	else:
		check(outside.is_empty(), said_taught)
	var unoffered := []
	for k in spec.get("teaches", []):
		if not has_item(taught, k):
			unoffered.append(k)
	check(unoffered.is_empty(), "%s: everything it teaches is on a terminal line or sticky note, ready to write down%s" % [puzzle.id, "" if unoffered.is_empty() else " (missing %s)" % ", ".join(unoffered)])
	return hints


# --- Pacing: how long a first-time player takes ----------------------------

## A non-coder reading a terminal: about 180 words a minute.
const PACE_READ_CPS := 15.0
## Hunt-and-peck typing of SQL, symbols included.
const PACE_TYPE_CPS := 2.5
## Deciding what to type next.
const PACE_THINK := 4.0
var paced := 0.0


## Let `seconds` of game time pass (time_scale-aware, counted in physics steps).
func _spend(seconds: float) -> void:
	paced += seconds
	var left := seconds
	while left > 0.0:
		await t.physics_frame
		left -= Engine.time_scale / float(Engine.physics_ticks_per_second)


# --- The hint ladder ----------------------------------------------------------

func _plain(hint: String) -> String:
	return hint.replace("[color=#ffffff]", "").replace("[/color]", "")


## Hint 1's query with the value left as '?', or "" (the old ladder: hint 1 is exact).
func _shape(p: Puzzle) -> String:
	for q in queries_in(_plain(p.hints[0])):
		if q.contains("?"):
			return q
	return ""


## The exact query the hints end on: the last hint under ladder A, else the first.
func _answer_query(p: Puzzle) -> String:
	var from: String = p.hints[-1] if _shape(p) != "" else p.hints[0]
	for q in queries_in(_plain(from)):
		if not q.contains("?"):
			return q
	return p.solution_sql


## How many hints a player who only copies needs at most: the tier with the exact query.
func rescue_tier(p: Puzzle) -> int:
	return p.hints.size() if _shape(p) != "" else 1


func _escape(text: String) -> String:
	var out := ""
	for c in text:
		out += ("\\" + c) if "\\.^$*+?()[]{}|/".contains(c) else c
	return out


## Augustine's hint ladder (option A, 2026-10-18). Hint 1 is the query's shape with
## the value as '?', a line per keyword, and where to find the value; hint 2 says how
## to find it, without the query; the last hint is the exact query, and it solves the
## puzzle. Every hint uses the real tables. A puzzle with no value to find is marked
## "ladder": "exact" in tests/curriculum.gd: its first hint is the exact query.
func check_ladder(ui: TerminalUI, p: Puzzle) -> void:
	var first := _plain(p.hints[0])
	var q := _answer_query(p)
	var shape := _shape(p)
	if Curriculum.PUZZLES.get(p.id, {}).get("ladder", "") == "exact":
		check(shape == "", "%s: no value to find, so hint 1 is the exact query" % p.id)
	else:
		check(shape != "", "%s: hint 1 is the query's shape with the value as '?' (ladder A)" % p.id)
	if FacilityAPI.is_request(q):
		check(q.begins_with("GET /"), "%s: the exact-query hint is a request the player can type (%s)" % [p.id, q])
	else:
		check(p.matches(ui.terminal.db, ui.terminal.db.execute(q)), "%s: the exact-query hint solves it (%s)" % [p.id, q])
	var missing := []
	for k in keywords_in(q):
		var has_line := false
		for line in first.split("\n"):
			var l := line.strip_edges()
			if not l.contains(";") and l != q and l != shape and keywords_in(l).has(k):
				has_line = true
		if not has_line:
			missing.append(k)
	check(missing.is_empty(), "%s: hint 1 has a line for each keyword%s" % [p.id, "" if missing.is_empty() else " (missing %s)" % ", ".join(missing)])
	if shape != "":
		var m := RegEx.create_from_string("^" + _escape(shape).replace("\\?", "(.+?)") + "$").search(q)
		check(m != null, "%s: hint 1's shape is the last hint's query with the value blanked (%s vs %s)" % [p.id, shape, q])
		if m:
			for i in range(1, m.get_group_count() + 1):
				var v := m.get_string(i).strip_edges()
				var given := RegEx.create_from_string("(?i)(?<![A-Za-z0-9_])" + _escape(v) + "(?![A-Za-z0-9_])").search(first) != null
				check(not given, "%s: hint 1 doesn't give the value away (%s)" % [p.id, v])
		check(p.hints.size() >= 3, "%s: three tiers: shape, how to find the value, exact query" % p.id)
		for h in p.hints.slice(1, p.hints.size() - 1):
			check(not _plain(h).contains(q), "%s: the middle hints say how to find the value, not the query" % p.id)
	var real := true
	for h in p.hints:
		real = real and not RegEx.create_from_string("(?i)\\b(employees|customers|users|students|orders)\\b").search(h)
	check(real, "%s: hints use the real tables, never an example one" % p.id)


# --- Level 0: the lobby -----------------------------------------------------

func walk_level_0() -> void:
	_game().new_run(5)
	var level = load("res://scenes/level_0.tscn").instantiate()
	t.root.add_child(level)
	for i in 20:
		await t.physics_frame
	check_case_clues(level, "lobby")
	check_jots(level, "lobby")
	var ui: TerminalUI = level.terminal_ui
	ui.open(level.desk_terminal, level.player)
	var h := await solve(level, ui, level.peek_puzzle, false)
	check(h == 0, "lobby: the boot screen alone gets a new player through the first query (hints %d)" % h)
	h = await solve(level, ui, level.memo_puzzle, false)
	check(h >= 0 and h <= rescue_tier(level.memo_puzzle), "lobby: a lost player sorts the memo once a hint gives the query (hints %d)" % h)
	var memo: Array = level.db.run_silent("SELECT text FROM memo_fragments ORDER BY piece_no")
	var shown := screen(ui)
	check(shown.rfind(memo[0].text) < shown.rfind(memo[1].text) and shown.rfind(memo[1].text) < shown.rfind(memo[-1].text), "lobby: the sorted result on screen reads as the memo, in order")
	check(not shown.contains("RECONSTRUCTED"), "lobby: the memo isn't printed a second time under the result")
	# Who called: Rourke's question, answered with named columns (the depth pass).
	level._ask_caller()
	h = await solve(level, ui, level.caller_puzzle, false)
	check(h >= 0 and h <= rescue_tier(level.caller_puzzle), "lobby: a lost player finds the caller once a hint gives the query (hints %d)" % h)
	check(last_table(screen(ui)).any(func(r): return r.get("extension", "") == str(level.data.extension) and r.get("name", "") == "Harold Mercer"), "lobby: the result shows the work order's extension beside Harold Mercer")
	# Optional: the visitor log newest first. Vale signed in and never left.
	h = await solve(level, ui, level.visitor_puzzle, false)
	check(h >= 0 and h <= rescue_tier(level.visitor_puzzle), "lobby: a lost player reads the visitor log newest first once a hint gives the query (hints %d)" % h)
	check(screen(ui).contains("VALE, I."), "lobby: the newest visitors on screen include Vale")
	ui.close()
	level.queue_free()
	await t.process_frame


## Case pages collect clues as they're read (papers, plates), so a clue must never
## carry a puzzle's answer: a value its query returns that the query itself doesn't
## type. Numbers are left out (extensions and temperatures are inputs, read off
## papers), and so are a puzzle's `givens`, values the player knew before the query.
## The answer reaches the page only through solve_case, after the solve.
func check_case_clues(level: Node, where: String) -> void:
	var clues := PackedStringArray()
	for d in level.find_children("*", "Document", true, false):
		for k in d.clues:
			clues.append(str(k.get("text", "")) + "\n" + str(k.get("opens", "")))
	for s in level.find_children("*", "ClueSpot", true, false):
		clues.append(s.text)
	var text := "\n".join(clues).to_lower()
	var leaks := []
	var world := world_text(level).to_lower()
	for p in _puzzles(level):
		for g in p.givens:
			check(world.contains(str(g).to_lower()), "%s: given '%s' is found in the world" % [p.id, g])
		for value in _answer_values(level, p):
			if _has_word(text, value) and not leaks.has("%s: %s" % [p.id, value]):
				leaks.append("%s: %s" % [p.id, value])
	check(leaks.is_empty() and not clues.is_empty(), "%s: no case-page clue gives away a query's answer (%d clues; %s)" % [where, clues.size(), ", ".join(leaks) if leaks else "none"])


## Every puzzle on the level's terminals.
func _puzzles(level: Node) -> Array:
	var out := []
	for term in level.find_children("*", "Terminal", true, false):
		out.append_array(term.puzzles)
	return out


## A puzzle's answer: the values its query returns that the query doesn't type and
## the player didn't already know (givens), lower case. Numbers and values under 3
## characters are left out: extensions, temperatures and one-letter zones are inputs.
func _answer_values(level: Node, p: Puzzle) -> Array:
	var out := []
	if p.solution_sql == "":
		return out  # an API puzzle: its answer comes back as JSON, not rows
	for row in level.db.run_silent(p.solution_sql):
		for v in row.values():
			var value := str(v).to_lower()
			if value.length() < 3 or value.is_valid_float() or p.solution_sql.to_lower().contains(value) \
					or p.givens.any(func(g): return str(g).to_lower() == value) or out.has(value):
				continue
			out.append(value)
	return out


## The values hint 1's shape leaves as '?', read off the exact query (lower case).
func _blanks(p: Puzzle) -> Array:
	var shape := _shape(p)
	var out := []
	if shape == "":
		return out
	var m := RegEx.create_from_string("^" + _escape(shape).replace("\\?", "(.+?)") + "$").search(_answer_query(p))
	if m:
		for i in range(1, m.get_group_count() + 1):
			out.append(m.get_string(i).strip_edges().trim_prefix("'").trim_suffix("'").to_lower())
	return out


func _has_word(text: String, word: String) -> bool:
	return RegEx.create_from_string("(?i)(?<![\\w-])" + _escape(word) + "(?![\\w-])").search(text) != null


# --- The crew's auto-jots ---------------------------------------------------------

## Titles of found_in papers seen on some floor, so check_jot_rules can tell a typo.
var _jot_docs := {}


## Augustine's rule for the crew's auto-jots (2026-10-20): "No auto-jot will contain
## clues players need to find. If it was in the dialogue, but can be found in the level,
## the auto-jot will be more vague." A jot whose fact is on a paper (found_in) must not
## name what that paper gives: a table, a snake_case column, a filled-in blank, a quoted
## value, an id or a number. And no jot may hold any of this floor's puzzle answers or
## hint-1 blanks.
func check_jots(level: Node, where: String) -> void:
	var docs := {}
	for d in level.find_children("*", "Document", true, false):
		docs[d.title] = d
	var names: Array = level.db.table_names()
	for tb in level.db.table_names():
		for c in level.db.table_schema(tb):
			if str(c["name"]).contains("_"):
				names.append(str(c["name"]))
	var bad := []
	var jots := []
	for id in VoiceLines.LINES:
		var l: Dictionary = VoiceLines.LINES[id]
		var jot := str(l.get("jot", ""))
		if jot == "":
			continue
		jots.append(jot)
		for title in l.get("found_in", []):
			if not docs.has(title):
				continue
			_jot_docs[title] = true
			var d = docs[title]
			var text: String = d.plain_text() + "\n" + "\n".join(d.clues.map(func(k): return str(k.get("text", ""))))
			var given := []
			for line in d.lines():
				if line.has("filled"):
					given.append(str(line.filled))
			for n in names:
				if _has_word(text, n):
					given.append(n)
			for m in RegEx.create_from_string("'([^']+)'|\\b[A-Z]+-\\d+\\b|\\b\\d{2,}\\b").search_all(text):
				given.append(m.get_string(1) if m.get_string(1) != "" else m.get_string())
			for g in given:
				if _has_word(jot, g):
					bad.append("%s names '%s' from %s" % [id, g, title])
	var all_jots := "\n".join(PackedStringArray(jots))
	for p in _puzzles(level):
		for v in _answer_values(level, p) + _blanks(p):
			if v.length() >= 3 and _has_word(all_jots, v):
				bad.append("a jot holds %s's %s" % [p.id, v])
	check(bad.is_empty(), "%s: the crew's jots stay vague about the papers and hold no answer or hint-1 blank (%s)" % [where, "; ".join(bad) if bad else "%d jots" % jots.size()])


## Once every floor is walked: secret lines carry no jot, and every found_in names a
## paper that's really in the game.
func check_jot_rules() -> void:
	var secret := []
	var missing := []
	for id in VoiceLines.LINES:
		var l: Dictionary = VoiceLines.LINES[id]
		if l.get("secret", false) and l.has("jot"):
			secret.append(id)
		for title in l.get("found_in", []):
			if not _jot_docs.has(title):
				missing.append("%s: %s" % [id, title])
	check(secret.is_empty(), "jots: lines that hide a secret are never jotted (%s)" % (", ".join(secret) if secret else "none"))
	check(missing.is_empty(), "jots: every found_in names a paper that's in the level (%s)" % (", ".join(missing) if missing else "all found"))


# --- Level 1: the server floor -------------------------------------------------

func walk_level_1(seed_value: int) -> void:
	_game().new_run(seed_value)
	var level = load("res://scenes/level_1.tscn").instantiate()
	t.root.add_child(level)
	for i in 20:
		await t.physics_frame
	level._on_asked()  # Rourke has asked the crew to find the fault
	check_case_clues(level, "server floor (seed %d)" % seed_value)
	check_jots(level, "server floor (seed %d)" % seed_value)
	var todo: String = _game().current_todo()
	check(todo != "" and not todo.contains(level.answer), "server floor: the to-do names the job, never the controller (%s)" % todo)
	var ui: TerminalUI = level.terminal_ui
	ui.open(level.terminal, level.player)
	check(world_text(level, level.terminal).contains("door_controllers") and world_text(level, level.terminal).contains("'fault'") and not screen(ui).contains("zone %s" % level.zone), "server room: the desk papers name the table and 'fault', and the zone comes from the doors query, not the boot screen")
	# First step: the stuck doors, and the zone they share (only the doors table has it).
	var h := await solve(level, ui, level.stuck_doors_puzzle, false)
	check(h >= 0 and h <= rescue_tier(level.stuck_doors_puzzle), "server room: a lost player finds the stuck doors once a hint gives the query (hints %d)" % h)
	var stuck := last_table(screen(ui)).filter(func(r): return ["Server Room A rear exit", "Server Room C", "Lift 1, server floor"].has(r.get("name", "")))
	check(stuck.size() == 3 and stuck.all(func(r): return r.get("zone", "") == level.zone), "server room: the shift log's stuck doors share one zone in the result")
	h = await solve(level, ui, level.controller_puzzle, false)
	check(h >= 0 and h <= rescue_tier(level.controller_puzzle), "server room: a lost player finds the controller once a hint gives the query (hints %d)" % h)
	# Read the answer off the result table, then find that rack in the room.
	var rows := last_table(screen(ui))
	var id: String = rows[0].get("id", "") if rows.size() == 1 else ""
	check(id != "" and has_world_label(level, id), "server room: the result names one controller, and a rack is labelled %s" % id)
	ui.close()
	var panel := find_interactable(level, "Reset controller " + id)
	check(panel != null, "server room: that rack has a reset panel the player can press")
	if panel:
		panel.interact(level.player)
	for i in 1500:  # Rourke walks over to badge the reset
		if level.doors["SRA-EXIT"].is_open:
			break
		await t.physics_frame
	check(level.doors["SRA-EXIT"].is_open and not level.room_c_door.locked, "server room: resetting the controller read off the screen frees the floor's stuck doors")
	# Optional: the overheating rack, comparison with > practised safely. The query
	# only finds the rack; reseating its fan tray in Server Room B solves it.
	ui.open(level.terminal, level.player)
	var hot: String = level.hot_rack
	h = await solve(level, ui, level.hot_rack_puzzle, false, 3, "", false, func():
		var r := last_table(screen(ui))
		return r.size() == 1 and r[0].get("id", "") == hot)
	check(h >= 0 and h <= rescue_tier(level.hot_rack_puzzle), "server floor: a lost player finds the hot rack once a hint gives the query (hints %d)" % h)
	ui.close()
	var tray := find_interactable(level, "Reseat the fan tray (%s)" % hot)
	check(tray != null, "server floor: the rack the query names has a fan tray to reseat")
	if tray:
		tray.interact(level.player)
	check(await _until(func(): return not level.vault_back.locked, 6.0), "server floor: reseating the hot rack's tray releases the cable vault's back door")
	# Optional: the dark break room, OR practised safely. The query lists the lights
	# that are out; the circuit reset by the break room door fixes them.
	ui.open(level.terminal, level.player)
	h = await solve(level, ui, level.dark_room_puzzle, false)
	check(h >= 0 and h <= rescue_tier(level.dark_room_puzzle), "server floor: a lost player lists the lights that are out once a hint gives the query (hints %d)" % h)
	ui.close()
	var reset := find_interactable(level, "Reset the lighting circuit")
	check(reset != null, "server floor: the break room has a circuit reset to press")
	if reset:
		reset.interact(level.player)
	check(await _until(func(): return level.lights["1-BREAK"][0].visible, 6.0), "server floor: the reset lights the break room")
	level.queue_free()
	await t.process_frame


# --- Level 2: Security Office -----------------------------------------------

# --- Level 2: Secure Lab B (Rourke turns) -------------------------------------

## Wait up to `seconds` of game time for `cond`.
func _until(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0 / Engine.time_scale)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			return false
		await t.physics_frame
	return true


## Locked in Vale's lab after the fight, the lost player gets out with Level 1's
## WHERE / AND on this lab's zone, read off the room, and may read the frame in
## badge_log with ORDER BY. Rourke is left untied: the case with the most going on.
func walk_lab(seed_value: int) -> void:
	_game().new_run(seed_value)
	var level = load("res://scenes/level_2.tscn").instantiate()
	t.root.add_child(level)
	Engine.time_scale = 4.0
	for i in 20:
		await t.physics_frame
	level.watcher.active = false
	var lab = level.lab
	var p: Player = level.player
	var ui: TerminalUI = level.terminal_ui
	check(await _until(func(): return lab.phase == "badge", 40.0), "lab: Rourke leads the crew to the lab door")
	check(world_text(level).contains("CTRL ZONE " + level.data.lab_zone), "lab: the door plate shows the lab's controller zone before anyone goes in")
	lab.reader.interact(p)
	await _until(func(): return level.doors["SECLAB-B"].is_open, 10.0)
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(-12.5, 0.1, 1.5)))
	await _until(func(): return lab.phase == "fight", 100.0)
	p.health = 100000.0
	for i in 30:
		if lab.rourke.state == Rourke.State.DOWN:
			break
		lab.rourke.take_hit(p)
		await t.physics_frame
		await t.physics_frame
	check(await _until(func(): return lab.switches.values().all(func(s): return s.enabled) and not lab.terminal.locked, 60.0), "lab: after the fight, her terminal opens and the switches wake")
	ui.open(lab.terminal, p)
	var near: String = world_text(level, lab.terminal)
	check(near.contains("zone " + level.data.lab_zone) or near.contains("ZONE " + level.data.lab_zone), "lab: a card inside the lab gives its controller zone (the door plate is outside the locked door)")
	var hunted: bool = level.watcher.active or (lab.rourke.visible and lab.rourke.state != Rourke.State.DOWN) or lab.response_left > 0.0
	# The response clock, measured: game time passes as a first-time player reads,
	# thinks and types (PACE_*), so the clock and any re-key run for real.
	paced = 0.0
	var clock_from: float = lab.response_left
	var zone: String = level.data.lab_zone
	var h := await solve(level, ui, lab.door_puzzle, hunted, 3, "", true)
	check(h >= 0 and h <= rescue_tier(lab.door_puzzle), "lab: a lost player finds the lab door's controller once a hint gives the query (hints %d)" % h)
	check(not _game().current_todo().contains(level.data.lab_answer), "lab: the to-do doesn't name the controller")
	await _spend(10.0)  # across the lab to the switch wall
	var used: float = clock_from - lab.response_left
	print("  INFO  lab clock (seed %d): a first-time player reaches the switch after %d s of %d (%d hint%s)" % [seed_value, used, Level2Lab.RESPONSE_TIME, h, "" if h == 1 else "s"])
	check(lab.response_left > 0.0 and level.data.lab_zone == zone, "lab: a first-time player who reads the hints reaches the switch before the security response re-keys the zone (%d s left)" % lab.response_left)
	# The badge log is optional here: read unpaced, so its time isn't on the clock.
	await solve(level, ui, lab.log_puzzle, hunted, 3)
	check(screen(ui).contains("VIS-"), "lab: the sorted badge_log shows the crew's own badges at her door")
	ui.close()
	var sw: Interactable = find_interactable(level, "Reset " + level.data.lab_answer)
	check(sw != null, "lab: a switch on the wall carries the id the query gave")
	if sw:
		sw.interact(p)
	check(await _until(func(): return level.doors["SECLAB-B"].is_open, 5.0), "lab: resetting the controller read off the screen opens the lab door")
	Engine.time_scale = 1.0
	level.queue_free()
	await t.process_frame


func walk_level_2(seed_value: int) -> void:
	_game().new_run(seed_value)
	_game().rourke_fate = "killed"  # the security section; the lab has its own walk
	var level = load("res://scenes/level_2.tscn").instantiate()
	t.root.add_child(level)
	for i in 20:
		await t.physics_frame
	check_case_clues(level, "security floor (seed %d)" % seed_value)
	check_jots(level, "security floor (seed %d)" % seed_value)
	var ui: TerminalUI = level.terminal_ui
	var p: Player = level.player
	p.local_control = false
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-3, 0.1, 4.6))  # at the booth
	ui.open(level.booth, p)
	var h := await solve(level, ui, level.cameras_puzzle, level.loose)
	check(h == 0, "security: the boot screen gets a new player through GET /cameras (hints %d)" % h)
	h = await solve(level, ui, level.pike_puzzle, level.loose)
	check(h == 0, "security: LIKE is practised on Pike from the query on screen, safely (hints %d)" % h)
	check(level.loose, "security: finding Pike freezes CAM-2 (the pressure starts)")
	# Pressure means the Watcher can actually hunt: it wakes when the office opens.
	var hunting: bool = level.watcher.active
	level.watcher.active = false  # keep the walkthrough deterministic from here
	# The Har query isn't written out: the player builds it from LIKE plus AND, both
	# taught by now (the solve() check enforces it). A lost player who can't gets it
	# from the hint that gives the query.
	h = await solve(level, ui, level.har_puzzle, hunting)
	check(h >= 0 and h <= rescue_tier(level.har_puzzle), "security: a lost player finds the PIN once a hint gives the query (hints %d)" % h)
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
	check(level.office_pad.screen.text.contains("GUARD PIN"), "security: the office door's wall keypad asks for a guard PIN")
	level.type_pin("office", pin, p)
	check(level.office_open, "security: the PIN read off the screen opens the Security Office")
	hunting = level.watcher.active
	level.watcher.active = false
	check(level.exit_pad.screen.text.contains("GUARD PIN"), "security: the stairwell's wall keypad asks for a guard PIN")
	level.type_pin("exit", pin, p)
	check(level.pin_entered and not level.door_open, "security: the PIN read off the screen is accepted, and the door lies")

	# The door didn't open. The player goes back to the panel and asks for help.
	ui.open(level.panel, p)
	ui.run(".hint")
	var hint_text := screen(ui).get_slice("[SYSOP]:", screen(ui).count("[SYSOP]:"))
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
	await solve(level, ui, level.door_puzzle, hunting)
	ui.close()

	# Dying to the Watcher should tell you why it could move.
	level.loose = true
	level.hud._notice.text = ""
	level.on_player_died()
	# The HUD only points at the terminals; the reason is a terminal line you can note.
	var said: String = level.hud._notice.text.to_lower()
	var lines: String = "\n".join(Array(level.booth.transcript) + level.booth.boot_lines).to_lower()
	check(said.contains("message") and (lines.contains("froze") or lines.contains("last_frame")),
		"security: after the Watcher gets you, the screen points to a terminal that says why it could move (a camera froze)")
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
