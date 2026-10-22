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
## (a rack, a PIN, a breaker) must be readable off the screen. Plays the floors in order
## so the taught set carries between levels. Owned by the Teaching and UX thread.
##
## Known teaching gaps are reported as GAP lines instead of failures, so the suite
## stays green while the owning thread fixes them. When a gap is fixed, its check
## prints FIXED: move it to a normal check() then.

const KEYWORDS := ["SELECT", "FROM", "WHERE", "AND", "OR", "ORDER BY", "DESC", "LIKE", "LIMIT", "COUNT", "GET", ">", "COLUMNS", "DISTINCT", "GROUP BY", "IS NULL", "UPDATE", "SET", "INSERT INTO", "VALUES", "PATCH", "POST"]
## Concepts that aren't one capitalised word: comparing a column with a value, and
## picking columns instead of *.
const KEYWORD_PATTERNS := {
	">": "\\w\\s*>=?\\s*(['\\d?]|enter_)",
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
## keyword -> the puzzle that first needed it.
var first_use_by := {}
var used_under_threat := {}


## `part` splits the walks across CI groups, since the paced walks are slow: "main"
## walks every floor up to 10 with lab seed 11 and runs the whole-game checks; "lab"
## walks Levels 0-1 again (the lab needs what they taught) and then lab seed 42; "api"
## walks floor 9, whose services teach everything their stations need on the floor.
func run(tree: SceneTree, check: Callable, part := "main") -> void:
	t = tree
	_check = check
	print("Teaching: lost-player walkthroughs (%s)" % part)
	taught = ""
	_jot_docs.clear()
	first_use.clear()
	used_under_threat.clear()
	if part == "api":
		await walk_level_5(31, true)
		await walk_level_5(12, false)
		check_teaching_order()
		if gaps > 0:
			print("  (%d known teaching gap%s, see tests/curriculum.gd)" % [gaps, "" if gaps == 1 else "s"])
		return
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
	for s in [3, 23]:
		await walk_level_3(s)
	await walk_level_4(31, true)
	await walk_level_4(12, false)
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


## Full queries written out on screen (or on a paper in the room), in order: a SELECT,
## UPDATE or INSERT line up to its ;, or a GET line's verb and path. Lines that explain
## a keyword ("SELECT *   every column") have no ; and aren't typed.
func queries_in(text: String) -> Array[String]:
	var out: Array[String] = []
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		var upper := line.to_upper()
		if (upper.begins_with("SELECT ") or upper.begins_with("UPDATE ") or upper.begins_with("INSERT INTO ")) and line.contains(";"):
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
	if has_blank(query):
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
	var stuck := false
	var copies := 0
	var silent := []
	var asking := puzzle is RequestPuzzle
	var hints_from: int = ui.terminal.transcript.size()
	while not puzzle.solved and not (done.is_valid() and done.call()):
		var read := remember(level, ui)
		if pace:
			await _spend(read / PACE_READ_CPS)
		var text := screen(ui)
		var on_screen := queries_in(text)
		var fresh: Array[String] = []
		# The notebook is reference, not a script: old queries name other levels'
		# tables, so the player only types what this screen shows, or what's written
		# in full on a paper in this room (a clerk's crib by the terminal).
		for shown in queries_in(text + "\n" + world_text(level, ui.terminal)):
			for q in fill_blanks(level, shown, ui.terminal):
				if not tried.has(q) and not fresh.has(q) and not (asking and q.contains("<")):
					fresh.append(q)
		# A request is copied off a paper in the room, or typed as a hint shows it in white.
		var papers: Array[String] = paper_requests(level, ui.terminal) if asking else ([] as Array[String])
		if asking:
			# A paper's request already sent on this floor isn't sent again: its answer said why.
			for q in papers.filter(func(q): return not _copied.has(q)) + hint_requests(ui.terminal, hints_from):
				if not tried.has(q) and not fresh.has(q):
					fresh.append(q)
		if fresh.is_empty():
			if hints == 0:
				for k in needed:
					if not has_item(taught, k):
						outside.append(k)
			if puzzle.hints.is_empty() and spec.get("ladder", "") == "held":
				# No ladder to climb yet: stuck at once, as a known gap (check_ladder said why).
				gap(false, "%s: a lost player is stuck until its hint ladder is built" % puzzle.id)
				stuck = true
				break
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
			# A write copied off a paper is a beginner's first move. When it changes
			# rows and isn't the answer, a SYSOP line or something in the world must
			# say why (judged the first time it's typed).
			var copy := (papers.has(q) if asking else FacilityDB.is_write(q) and not on_screen.has(q)) and not _copied.has(q)
			var said_from: int = ui.terminal.transcript.size()
			var notice: String = level.hud._notice.text
			ui.run(q)
			if asking:
				await t.physics_frame
				await t.physics_frame
			if copy:
				_copied[q] = true
				copies += 1
				if not asking:
					await t.physics_frame
					await t.physics_frame
				if not puzzle.solved and (_silent_request(ui.terminal, said_from) if asking else _silent(ui.terminal, said_from)) and level.hud._notice.text == notice:
					silent.append(q.replace("\n", " / "))
			if (done.is_valid() and done.call()) or puzzle.solved:
				break
	var read_last := remember(level, ui)
	if pace:
		await _spend(read_last / PACE_READ_CPS)
	for k in needed:
		if not KEYWORDS.has(k):
			continue
		if not first_use.has(k):
			first_use[k] = "threat" if threat else "safe"
			first_use_by[k] = puzzle.id
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
	if copies > 0:
		var said_why := "%s: a paper's %s, copied when it isn't the answer, gets a reason%s" % [puzzle.id, "request" if asking else "write", "" if silent.is_empty() else " (nothing said after %s)" % "; ".join(silent)]
		if spec.has("silent_copy"):
			gap(silent.is_empty(), "%s (%s)" % [said_why, spec.silent_copy])
		else:
			check(silent.is_empty(), said_why)
	return -1 if stuck else hints


## Writes the lost player has copied off papers this floor: each is judged once.
var _copied := {}


## Since line `from` of a terminal's screen: rows changed, and no SYSOP line said why.
func _silent(term: Node, from: int) -> bool:
	var lines := Array(term.transcript).slice(from)
	var changed := RegEx.create_from_string("OK\\. [1-9]\\d* row\\(s\\) changed")
	return lines.any(func(l): return changed.search(str(l)) != null) and not lines.any(func(l): return str(l).contains("SYSOP"))


## Since line `from`: the service took a copied request (2xx) and no SYSOP line said why
## it isn't the answer. An error's own body is its reason.
func _silent_request(term: Node, from: int) -> bool:
	var lines := Array(term.transcript).slice(from)
	return lines.any(func(l): return TerminalUI._plain(str(l)).begins_with("HTTP/1.0 2")) and not lines.any(func(l): return str(l).contains("SYSOP"))


## The player read a paper where it lies (a card in another room, say): its lines
## join the taught set, as lines it could have written down.
func read_paper(level: Node, title: String) -> void:
	for d in level.find_children("*", "Document", true, false):
		if d.title == title:
			for line in d.plain_text().split("\n"):
				if line.strip_edges() != "" and not taught.contains(line):
					taught += line + "\n"
			return
	check(false, "the paper '%s' is in the level" % title)


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


## A hint's shape names each value to fill in: enter_column_name, enter_zone...
const BLANK := "\\benter_[a-z_]+"


func has_blank(query: String) -> bool:
	return RegEx.create_from_string(BLANK).search(query) != null


## Hint 1's query with the value left as a named blank, or "" (the old ladder: hint 1 is exact).
func _shape(p: Puzzle) -> String:
	if p.hints.is_empty():
		return ""
	if p is RequestPuzzle:
		for b in white_blocks(p.hints[0]):
			if has_blank(b):
				return b
		return ""
	for q in queries_in(_plain(p.hints[0])):
		if has_blank(q):
			return q
	return ""


## The exact query the hints end on: the last hint under ladder A, else the first.
func _answer_query(p: Puzzle) -> String:
	if p.hints.is_empty():
		return p.solution_sql
	if p is RequestPuzzle:
		var exact := _exact_requests(p)
		return "\n\n".join(exact) if not exact.is_empty() else p.solution_sql
	var from: String = p.hints[-1] if _shape(p) != "" else p.hints[0]
	for q in queries_in(_plain(from)):
		if not has_blank(q):
			return q
	return p.solution_sql


## How many hints a player who only copies needs at most: the tier with the exact query.
func rescue_tier(p: Puzzle) -> int:
	if p.hints.is_empty():
		return 0
	if p is RequestPuzzle:
		return p.hints.size()  # both request ladders end on what to type
	return p.hints.size() if _shape(p) != "" else 1


func _escape(text: String) -> String:
	var out := ""
	for c in text:
		out += ("\\" + c) if "\\.^$*+?()[]{}|/".contains(c) else c
	return out


## Augustine's hint ladder (option A, 2026-10-18). Hint 1 is the query's shape with
## the value as a named blank (enter_...), a line per keyword, and where to find the value; hint 2 says how
## to find it, without the query; the last hint is the exact query, and it solves the
## puzzle. Every hint uses the real tables. A puzzle with no value to find is marked
## "ladder": "exact" in tests/curriculum.gd: its first hint is the exact query.
func check_ladder(ui: TerminalUI, p: Puzzle) -> void:
	if p is RequestPuzzle:
		check_request_ladder(p)
		return
	if Curriculum.PUZZLES.get(p.id, {}).get("ladder", "") == "held":
		# Drafted, not built: the floor's ladders wait on an approval (see the row).
		gap(not p.hints.is_empty(), "%s: a hint ladder is built (drafted in plan/approvals/l3-text.md, held for approval)" % p.id)
		return
	var first := _plain(p.hints[0])
	var q := _answer_query(p)
	var shape := _shape(p)
	var mode: String = Curriculum.PUZZLES.get(p.id, {}).get("ladder", "")
	if mode == "exact":
		check(shape == "", "%s: no value to find, so hint 1 is the exact query" % p.id)
	elif mode == "review":
		check(shape != "" and p.hints.size() == 2, "%s: review: a reminder with the shape, then the exact query (two tiers)" % p.id)
	else:
		check(shape != "", "%s: hint 1 is the query's shape with the value as a named blank (ladder A)" % p.id)
	if FacilityAPI.is_request(q):
		check(q.begins_with("GET /"), "%s: the exact-query hint is a request the player can type (%s)" % [p.id, q])
	else:
		var on: FacilityDB = _scratch(ui.terminal.db) if FacilityDB.is_write(q) else ui.terminal.db
		check(p.matches(on, on.execute(q)), "%s: the exact-query hint solves it (%s)" % [p.id, q])
	var missing := []
	for k in keywords_in(q):
		var has_line := false
		for line in first.split("\n"):
			var l := line.strip_edges()
			if not l.contains(";") and l != q and l != shape and keywords_in(l).has(k):
				has_line = true
		if not has_line:
			missing.append(k)
	if mode != "review":
		check(missing.is_empty(), "%s: hint 1 has a line for each keyword%s" % [p.id, "" if missing.is_empty() else " (missing %s)" % ", ".join(missing)])
	if shape != "":
		var m := RegEx.create_from_string("^" + RegEx.create_from_string(BLANK).sub(_escape(shape), "(.+?)", true) + "$").search(q)
		check(m != null, "%s: hint 1's shape is the last hint's query with the value blanked (%s vs %s)" % [p.id, shape, q])
		if m:
			for i in range(1, m.get_group_count() + 1):
				var v := m.get_string(i).strip_edges()
				var given := RegEx.create_from_string("(?i)(?<![A-Za-z0-9_])" + _escape(v) + "(?![A-Za-z0-9_])").search(first) != null
				check(not given, "%s: hint 1 doesn't give the value away (%s)" % [p.id, v])
		if mode != "review":
			check(p.hints.size() >= 3, "%s: three tiers: shape, how to find the value, exact query" % p.id)
		for h in p.hints.slice(1, p.hints.size() - 1):
			check(not _plain(h).contains(q), "%s: the middle hints say how to find the value, not the query" % p.id)
	var real := true
	for h in p.hints:
		real = real and not RegEx.create_from_string("(?i)\\b(employees|customers|users|students|orders)\\b").search(h)
	check(real, "%s: hints use the real tables, never an example one" % p.id)


# --- Requests (floor 9's services) -------------------------------------------

## What a hint shows in white, to type as it is: each block's plain text. On screen
## the keywords inside are coloured too, so a block ends at the tag that closes it.
func white_blocks(bbcode: String) -> Array[String]:
	var out: Array[String] = []
	var opened: Array[bool] = []  # each open colour tag: did it start a white block?
	var start := -1
	for m in RegEx.create_from_string("\\[(/?)color[^\\]]*\\]").search_all(bbcode):
		if m.get_string(1) == "":
			var starts := start < 0 and m.get_string() == "[color=#ffffff]"
			if starts:
				start = m.get_end()
			opened.append(starts)
		elif not opened.is_empty() and opened.pop_back():
			out.append(TerminalUI._plain(bbcode.substr(start, m.get_start() - start)).strip_edges())
			start = -1
	return out


## The requests a station's last hint says to type, with no blank left in them.
func _exact_requests(p: Puzzle) -> Array[String]:
	var out: Array[String] = []
	if not p.hints.is_empty():
		for b in white_blocks(p.hints[-1]):
			if not has_blank(b):
				out.append(b)
	return out


## The first of `exact` that `shape` matches with its blanks filled in: the match's
## groups are the values (null: none).
func _shape_match(shape: String, exact: Array) -> RegExMatch:
	if shape == "":
		return null
	var re := RegEx.create_from_string("^" + RegEx.create_from_string(BLANK).sub(_escape(shape), "(.+?)", true) + "$")
	for q in exact:
		var m := re.search(q)
		if m:
			return m
	return null


## The requests the hints since line `from` showed in white, ready to send (no blank).
func hint_requests(term: Node, from: int) -> Array[String]:
	var out: Array[String] = []
	for i in range(from, term.transcript.size()):
		if i < term.transcript_kinds.size() and term.transcript_kinds[i] != "hint":
			continue
		for b in white_blocks(term.transcript[i]):
			if not has_blank(b) and FacilityAPI.is_request(b) and not out.has(b):
				out.append(b)
	return out


## Requests written out on papers in the room, as a beginner copies them: the request
## line, its header lines and its JSON body. Once the player has the HR key (it's in
## what they've read), it goes in a <key> blank; a request with any other blank
## (<badge>, <door>) can't be sent as it is.
func paper_requests(level: Node, at: Node3D) -> Array[String]:
	var data = level.get("data")
	var key: String = str(data.get("keys", {}).get("hr", "")) if data is Dictionary else ""
	var header := RegEx.create_from_string("^[A-Za-z][A-Za-z0-9-]*: \\S")
	var out: Array[String] = []
	for d in level.find_children("*", "Document", true, false):
		if not in_room(d, at):
			continue
		var lines: Array = Array(d.plain_text().split("\n")).map(func(l): return l.strip_edges())
		var i := 0
		while i < lines.size():
			var line: String = lines[i]
			i += 1
			var verb := line.get_slice(" ", 0)
			if not FacilityAPI.is_request(line) or verb != verb.to_upper():
				continue
			var req := [line]
			while i < lines.size() and header.search(lines[i]):
				req.append(lines[i])
				i += 1
			var j := i
			while j < lines.size() and lines[j] == "":
				j += 1
			if j < lines.size() and str(lines[j]).begins_with("{"):
				req.append_array(["", lines[j]])
				i = j + 1
			var typed := "\n".join(req)
			if key != "" and taught.contains(key):
				typed = RegEx.create_from_string("<[^>]*key>").sub(typed, key, true)
			if not typed.contains("<") and not out.has(typed):
				out.append(typed)
	return out


## The request ladders, as a query's but in white blocks. Hint 1 is the request's shape
## with the value as a named blank (enter_...); under ladder A it explains each part on
## a line of its own (the request line, the header, the body) and a middle tier says
## where the value is; the last tier is exactly what to type, every block ready to send
## (the walk sends them: that they solve it is the walk's own check). A "ladder" meta
## on the station overrides its curriculum row: floor 9's passes take ladder A when
## POST wasn't practised at the work order.
func check_request_ladder(p: Puzzle) -> void:
	var spec: Dictionary = Curriculum.PUZZLES.get(p.id, {})
	var mode: String = p.get_meta("ladder", spec.get("ladder", ""))
	var shape := _shape(p)
	var exact := _exact_requests(p)
	check(shape != "", "%s: hint 1 is the request's shape with the value as a named blank (%s)" % [p.id, "review" if mode == "review" else "ladder A"])
	if mode == "review":
		check(p.hints.size() == 2, "%s: review: a reminder with the shape, then exactly what to type (two tiers)" % p.id)
	else:
		check(p.hints.size() >= 3, "%s: three tiers: shape, where the value is, exactly what to type" % p.id)
	check(not exact.is_empty() and exact.all(func(q): return FacilityAPI.is_request(q) and not q.contains("<")), "%s: the last hint is requests to send as they are (%s)" % [p.id, " | ".join(exact).replace("\n", " / ")])
	var m := _shape_match(shape, exact)
	check(m != null, "%s: hint 1's shape is one of the last hint's requests with the value blanked" % p.id)
	if m:
		var first := _plain(p.hints[0])
		for i in range(1, m.get_group_count() + 1):
			var v := m.get_string(i).strip_edges()
			var given := RegEx.create_from_string("(?i)(?<![A-Za-z0-9_])" + _escape(v) + "(?![A-Za-z0-9_])").search(first) != null
			var said := "%s: hint 1 doesn't give the value away (%s)" % [p.id, v]
			if spec.has("shape_gap"):
				gap(not given, "%s (%s)" % [said, spec.shape_gap])
			else:
				check(not given, said)
	if mode != "review" and shape != "":
		var parts := [shape.get_slice(" ", 0) + " /", "X-Api-Key"]
		if shape.contains("{"):
			parts.append("{")
		var shown := shape.split("\n")
		var lines := Array(_plain(p.hints[0]).split("\n")).map(func(l): return l.strip_edges()).filter(func(l): return not shown.has(l))
		var missing := parts.filter(func(part): return not lines.any(func(l): return l.begins_with(part)))
		check(missing.is_empty(), "%s: hint 1 explains each part of the request on a line of its own (the request, the header, the body)%s" % [p.id, "" if missing.is_empty() else " (missing %s)" % ", ".join(missing)])
	for h in p.hints.slice(1, p.hints.size() - 1):
		check(not exact.any(func(q): return white_blocks(h).has(q) or _plain(h).contains(q)), "%s: the middle hints say where the value is, not what to type" % p.id)
	var real := true
	for h in p.hints:
		real = real and not RegEx.create_from_string("(?i)\\b(employees|customers|users|students|orders)\\b").search(h)
	check(real, "%s: hints use the real services, never an example one" % p.id)


## The walks time the queries, so every chapter of every book is already in:
## coming in, its lines would only add time here, and the walks never lean on the
## book (ladder A explains each word). The chapters have their own tests.
func skip_chapters(level: Node) -> void:
	var h := Huddle.of(level)
	for id in Books.chapter_ids():
		h.done[id] = true


# --- Level 0: the lobby -----------------------------------------------------

func walk_level_0() -> void:
	_game().new_run(5)
	var level = load("res://scenes/level_0.tscn").instantiate()
	t.root.add_child(level)
	skip_chapters(level)
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
	var tier := rescue_tier(level.caller_puzzle)  # once the row shows, .hint moves on to adding it
	h = await solve(level, ui, level.caller_puzzle, false, 3, "", false, func(): return level.caller_listed)
	check(h >= 0 and h <= tier, "lobby: a lost player finds the caller once a hint gives the query (hints %d)" % h)
	check(last_table(screen(ui)).any(func(r): return r.get("extension", "") == str(level.data.extension) and r.get("name", "") == "Harold Mercer"), "lobby: the result shows the work order's extension beside Harold Mercer")
	# The answer is theirs to pick out: the row with the work order's extension.
	var lines: Array = ui.noteable_lines()
	var mercer := -1
	for i in lines.size():
		if lines[i].kind == "row" and lines[i].text.contains(str(level.data.extension)):
			mercer = i
	check(mercer >= 0 and ui.write_note(mercer), "lobby: the row with the work order's extension goes in the case page's blank")
	for i in 30:
		if level.caller_puzzle.solved:
			break
		await t.physics_frame
	check(level.caller_puzzle.solved, "lobby: and that answers who called")
	ui.open(level.desk_terminal, level.player)
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
	if p.solution_sql == "" or FacilityDB.is_write(p.solution_sql) or p is RequestPuzzle:
		return out  # an API puzzle's answer comes back as JSON, and a write's isn't rows
	for row in level.db.run_silent(p.solution_sql):
		for v in row.values():
			var value := str(v).to_lower()
			if value.length() < 3 or value.is_valid_float() or p.solution_sql.to_lower().contains(value) \
					or p.givens.any(func(g): return str(g).to_lower() == value) or out.has(value):
				continue
			out.append(value)
	return out


## The values hint 1's shape leaves blank, read off the exact query (lower case).
func _blanks(p: Puzzle) -> Array:
	var shape := _shape(p)
	var out := []
	if shape == "":
		return out
	var m := _shape_match(shape, _exact_requests(p)) if p is RequestPuzzle else RegEx.create_from_string("^" + RegEx.create_from_string(BLANK).sub(_escape(shape), "(.+?)", true) + "$").search(_answer_query(p))
	if m:
		var names := RegEx.create_from_string(BLANK).search_all(shape)
		for i in range(1, m.get_group_count() + 1):
			if i <= names.size() and names[i - 1].get_string() == "enter_service":
				continue  # a service's name is on every boot screen: no secret
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
	skip_chapters(level)
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
	# Then the reset's sign-off: how many controllers are faulted, floor-wide.
	check(_game().current_todo() == level.COUNT_TODO, "server room: once the controller is found, the to-do asks for the sign-off's count")
	h = await solve(level, ui, level.count_puzzle, false)
	check(h >= 0 and h <= rescue_tier(level.count_puzzle), "server room: a lost player counts the faulted controllers once a hint gives the query (hints %d)" % h)
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
	skip_chapters(level)
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
	skip_chapters(level)
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


# --- Level 3: the Records Archive on 18 ---------------------------------------

## The floor's pacing (plan/level-3-records-archive.md): arrive quiet and practise at
## the desk (COUNT from the sticky, DISTINCT from the memo, GROUP BY from the tally);
## the north corridor wakes the Shredder, and Security's sheet there asks which room;
## the night's count under threat names it, the keyholder's badge from the readers'
## log is the code on Mercer's lock; his room is the breather, where the card and his
## battery PC teach IS NULL safely; back at the desk under threat, the slips name the
## box on the returns cart with the stair key in it. Every station has its ladder
## (COUNT's is the short review one: it was practised on 14).
func walk_level_3(seed_value: int) -> void:
	_game().new_run(seed_value)
	var level = load("res://scenes/level_3.tscn").instantiate()
	t.root.add_child(level)
	skip_chapters(level)
	for i in 20:
		await t.physics_frame
	var where := "records archive (seed %d)" % seed_value
	check_case_clues(level, where)
	check_jots(level, where)
	check_no_copy_under_pressure(level, where)
	var ui: TerminalUI = level.terminal_ui
	var p: Player = level.player
	p.local_control = false
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), level.to_global(Vector3(-0.8, 0.1, 2.6)))
	ui.open(level.desk, p)
	var seen := screen(ui) + "\n" + world_text(level, level.desk)
	check(seen.contains("retrieval_slips") and seen.contains("access_log") and seen.contains("catalogue"), "%s: the desk's papers and boot screen name the three tables" % where)
	check(seen.contains(Level3Data.NIGHT), "%s: the night's date is written on the desk the way the readers log it" % where)
	check(seen.contains("COUNT") and seen.contains("DISTINCT") and seen.contains("GROUP BY"), "%s: COUNT, DISTINCT and GROUP BY are found on papers within reach of the desk" % where)
	check(not seen.contains("IS NULL"), "%s: IS NULL is not on the desk: it's the word the crew looks up in Mercer's room" % where)
	# The desk's chores, asked by the clipboard, the memo and the note by the spike.
	var asks := world_text(level, level.desk)
	check(asks.contains("OPEN AT END OF SHIFT") and asks.contains("every department") and asks.contains("never checked back in"), "%s: each practice station is asked for on a paper at the desk" % where)
	_doc(level, "Retrieval slips").open_reader(p).close()
	check(_game().case_info("duties").get("open", false) and not _game().case_info("duties").get("solved", false), "%s: reading the clipboard opens the night clerk's list as a case" % where)
	# Quiet: COUNT as review (its short ladder), then the two new words, each copied
	# off the paper that shows it (found, and practised at once).
	var h := await solve(level, ui, level.slips_puzzle, level.shredder_awake)
	check(h <= rescue_tier(level.slips_puzzle), "%s: the slips count is built from the sticky's shape; a lost player waits on its ladder (hints %d)" % [where, h])
	# The memo's query covers every room: copying it shows DISTINCT at work (the
	# practice) but the station wants the stacks only, so the WHERE is the player's
	# (or its ladder's).
	ui.run("SELECT DISTINCT dept FROM catalogue")
	remember(level, ui)
	var every := last_table(screen(ui)).size()
	check(not level.depts_puzzle.solved and taught.contains("SELECT DISTINCT dept FROM catalogue;"), "%s: DISTINCT is practised by copying the memo, safely, and the stacks station still needs the player's WHERE" % where)
	h = await solve(level, ui, level.depts_puzzle, level.shredder_awake)
	check(h <= rescue_tier(level.depts_puzzle) and level.depts_puzzle.solved and last_table(screen(ui)).size() < every, "%s: the memo's list has more departments than the stacks: the WHERE narrows it, from the player or the ladder (hints %d)" % [where, h])
	h = await solve(level, ui, level.tally_puzzle, level.shredder_awake)
	check(h == 0 and level.tally_puzzle.solved, "%s: GROUP BY is practised from the reader tally on the desk, safely (hints %d)" % [where, h])
	ui.run(level.tally_puzzle.solution_sql)
	var top := ""
	var most := -1
	for r in last_table(screen(ui)):
		for k in r:
			if str(k).to_lower() == "count(*)" and int(r[k]) > most:
				most = int(r[k])
				top = r.get("room", "")
	check(top == "READING ROOM", "%s: the whole log puts the reading room first (the decoy)" % where)
	# The night's question hasn't been asked: its answer doesn't count yet.
	ui.run(level.visits_puzzle.solution_sql)
	check(not level.visits_puzzle.solved and not level.shredder_awake, "%s: before Security's sheet is read, the night's count is no station, and nothing has woken the Shredder" % where)
	ui.close()

	# North: setting foot in the corridor is the pressure peak, and the sheet by the
	# shredding room's reader asks which room.
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(-9.5, 0.1, -23.5)))
	for i in 10:
		await t.physics_frame
	check(level.shredder_awake and level.shredder.active, "%s: the north corridor wakes the Shredder before the question can be read" % where)
	level.shredder.active = false  # keep the walkthrough deterministic from here; the threat is still on
	var sheet = _doc(level, "Reader exceptions")
	check(sheet != null and in_room(sheet, level.find_child("NorthCorridor", true, false)), "%s: Security's sheet hangs in the corridor" % where)
	sheet.open_reader(p).close()
	for i in 3:
		await t.physics_frame
	check(level.room_asked and _game().case_info("room").get("open", false) and not _game().case_info("room").get("solved", false), "%s: reading it opens the room case, unsolved" % where)
	var host: String = level.data.host
	check(level.safe_door.locked, "%s: Mercer's door is locked whichever room it's behind: a crank alone opens nothing" % where)

	# Under threat: the night's count names the room. Not a copy job: the player adds
	# the date (from the slips) and the sort (from Level 0) to the tally's query.
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), level.to_global(Vector3(-0.8, 0.1, 2.6)))
	ui.open(level.desk, p)
	h = await solve(level, ui, level.visits_puzzle, level.shredder_awake)
	check(h <= rescue_tier(level.visits_puzzle), "%s: the night's count is built, not copied; a lost player waits on its ladder (hints %d)" % [where, h])
	if not level.visits_puzzle.solved:
		ui.run(level.visits_puzzle.solution_sql)  # the player who built it from the papers
	check(level.visits_puzzle.solved and _game().case_info("room").get("solved", false) and _game().case_info("room").how.contains(host), "%s: the night's count ranks the host room first and closes the room case" % where)
	var ranked := last_table(screen(ui))
	check(ranked.size() > 0 and ranked[0].get("room", "") == host, "%s: the top row of the result is the room to look in" % where)
	# The code on the lock: the policy sheet says whose badge; the readers' log says which.
	check(world_text(level, level.desk).contains("badge number"), "%s: the lock policy on the desk says the code is the keyholder's badge number" % where)
	h = await solve(level, ui, level.keyholder_puzzle, level.shredder_awake)
	check(h <= rescue_tier(level.keyholder_puzzle), "%s: the keyholder's badge is built, not copied; a lost player waits on its ladder (hints %d)" % [where, h])
	ui.run("SELECT * FROM access_log WHERE room = '%s'" % host)
	remember(level, ui)
	check(level.keyholder_puzzle.solved and not level.mercer_puzzle.solved, "%s: that room's raw rows, read by eye, answer the lock's question, and aren't the catalogue route" % where)
	var badges := {}
	for r in last_table(screen(ui)):
		badges[r.get("badge_id", "")] = true
	check(badges.size() == 1 and badges.has(level.data.visitor_badge), "%s: one badge used that room's reader, and its digits are the code" % where)
	ui.close()
	var code: String = level.data.visitor_badge.get_slice("-", 1)
	level.cranks[host].interact(p)
	for i in 5:
		await t.physics_frame
	level.type_code(code, p)
	check(level.safe_unlocked and not level.safe_door.locked, "%s: the badge number read off the screen opens Mercer's lock" % where)

	# The breather: Mercer's room. The card shows IS NULL on another table; his PC
	# practises it on his own list, safely: the Shredder doesn't fit through side doors.
	var c: Vector3 = level.safe_room_box.get_center()
	p.global_transform = Transform3D(Basis(), level.to_global(Vector3(c.x, 0.1, c.z)))
	for i in 5:
		await t.physics_frame
	read_paper(level, "SQL pocket reference")
	var card: String = _doc(level, "SQL pocket reference").plain_text()
	check(has_item(card, "IS NULL") and card.contains("= NULL") and not card.contains("returned_at"), "%s: Mercer's card shows IS NULL on a table that isn't the puzzle's, and warns off = NULL" % where)
	ui.open(level.pc, p)
	h = await solve(level, ui, level.pc_puzzle, false)
	check(h == 0 and level.pc_puzzle.solved, "%s: IS NULL is practised on Mercer's PC, in the safe room, from the query on its screen (hints %d)" % [where, h])
	ui.close()
	_doc(level, "Mercer's note").open_reader(p).close()
	for i in 3:
		await t.physics_frame
	check(_game().case_info("key").get("open", false) and _game().current_todo() == level.TEXT.todo_key_box, "%s: Mercer's note says where the key is and opens the key case" % where)
	# The cart's boxes are taped: the note alone opens nothing.
	level.cart_boxes[level.data.key_box].interact(p)
	for i in 3:
		await t.physics_frame
	check(not level.key_taken and level.stair_out.locked and level.cart_boxes[level.data.key_box].get_prompt(p) == level.TEXT.box_taped, "%s: with the note read but no query, the key box is still taped: the desk has to name it" % where)
	# Back at the desk, under threat: the box nobody checked back in. The note by the
	# spike sends the player to the slips, so it looks at them first (the column
	# names are on that screen).
	p.global_transform = Transform3D(Basis(Vector3.UP, PI), level.to_global(Vector3(-0.8, 0.1, 2.6)))
	ui.open(level.desk, p)
	ui.run("SELECT * FROM retrieval_slips")
	remember(level, ui)
	check(taught.contains("returned_at") and taught.contains("filled"), "%s: the slips table shows its return-time column and the 'filled' status" % where)
	# The tempting wrong turn first: = NULL, which the card warns off.
	var before := screen(ui).length()
	ui.run("SELECT box_id FROM retrieval_slips WHERE returned_at = NULL")
	check(not level.unreturned_puzzle.solved and screen(ui).substr(before).contains("(0 rows)"), "%s: = NULL finds nothing, as the card warns" % where)
	h = await solve(level, ui, level.unreturned_puzzle, level.shredder_awake)
	check(h <= rescue_tier(level.unreturned_puzzle), "%s: the box with the key is built from the card and the PC, or its ladder (hints %d)" % [where, h])
	ui.run(level.unreturned_puzzle.solution_sql)
	check(level.unreturned_puzzle.solved and _game().case_info("key").get("solved", false), "%s: IS NULL names the box nobody checked back in, and the key case closes" % where)
	var named := last_table(screen(ui)).map(func(r): return r.get("box_id", ""))
	check(named.has(level.data.key_box) and named.size() <= 2, "%s: the result names the key's box (one or two to open, not the whole cart)" % where)
	# The second route to the room, DISTINCT under threat: Mercer's own boxes in the catalogue.
	h = await solve(level, ui, level.mercer_puzzle, level.shredder_awake)
	check(h <= rescue_tier(level.mercer_puzzle), "%s: the catalogue route is built, not copied; a lost player waits on its ladder (hints %d)" % [where, h])
	ui.close()
	# The box on the cart the result named has the key; the stairs open.
	level.cart_boxes[level.data.key_box].interact(p)
	for i in 3:
		await t.physics_frame
	check(level.key_taken and not level.stair_out.locked, "%s: the key is in the box the query named, and it unlocks the stairs down" % where)
	level.queue_free()
	await t.process_frame


# --- Level 4: the Power Plant on 10, and the way down to G -------------------

## Floor 10's new SQL: UPDATE, INSERT, and checking that a write took. The lost player
## types the writes it finds written out in full (the work order's, the clipboard's,
## the lockup card's) and climbs the ladders for its own values. With `seal`, the crew
## locks the Custodian in its bay (INSERT under pressure), and the read-back at the
## bay's panel runs on its 30-second clock, paced as a first-time player; the ground
## floor is quiet then. Without it, the Custodian is loose all the way down, and the
## front doors' UPDATE and its read-back are typed with it coming.
func walk_level_4(seed_value: int, seal: bool) -> void:
	_game().new_run(seed_value)
	var level = load("res://scenes/level_4.tscn").instantiate()
	t.root.add_child(level)
	skip_chapters(level)
	for i in 20:
		await t.physics_frame
	level.completed.disconnect(level._on_completed)  # the walk ends with the floor, not in the next scene
	var net: Node = t.root.get_node("/root/Net")
	var earned: Array = net.profile.earned.duplicate()
	_copied.clear()
	var where := "power plant (seed %d, %s)" % [seed_value, "sealed" if seal else "loose"]
	check_no_copy_under_pressure(level, where)
	var ui: TerminalUI = level.terminal_ui
	var p: Player = level.player
	p.local_control = false
	# The hall's papers, seen on the way in: the gantry card and the doors' signs.
	for title in ["Gantry card", "Control room sign", "Bay sign"]:
		read_paper(level, title)

	# Quiet: the work order at the plant desk. Its UPDATE is last month's breaker, so
	# copying it practises the shape and changes nothing; tonight's id is the
	# player's own step, or its ladder's.
	_doc(level, "Facilities work order").open_reader(p).close()
	ui.open(level.maint, p)
	var h := await solve(level, ui, level.reset_puzzle, _hunted(level))
	check(h <= rescue_tier(level.reset_puzzle) and level.reset_puzzle.solved and not level.alarm, "%s: tonight's breaker is reset from the work order's shape and the panel, with no alarm (hints %d)" % [where, h])
	check(_said(level.maint, level.TEXT.tip_example), "%s: the work order's own UPDATE, copied, gets SYSOP's why" % where)
	h = await solve(level, ui, level.check_puzzle, _hunted(level))
	check(h == 0 and level.check_puzzle.solved and _game().case_info("power").get("solved", false), "%s: SYSOP asks whether it took, the panel's SELECT is on the screen, and reading it back signs off the work order (hints %d)" % [where, h])
	ui.close()
	# A query's answer is what the panel shows now, with tonight's breaker on.
	check_case_clues(level, where)
	check_jots(level, where)

	# The control room, open with the power back: the clipboard's rule, then the
	# crew's own row in the log, read back. The clerk's crib is another contractor's.
	check(await _until(func(): return level.ctrl_door.is_open, 10.0), "%s: with the power back, the control room's door opens" % where)
	_doc(level, "Contractor log").open_reader(p).close()
	ui.open(level.controller, p)
	h = await solve(level, ui, level.login_puzzle, _hunted(level))
	check(h <= rescue_tier(level.login_puzzle) and level.login_puzzle.solved and not level.logged_in, "%s: the crew's own row goes in, from the crib's shape, the notebook's number and the clock, or the ladder (hints %d)" % [where, h])
	h = await solve(level, ui, level.login_read_puzzle, _hunted(level))
	check(h <= rescue_tier(level.login_read_puzzle) and level.logged_in, "%s: read back, the log-in counts (hints %d)" % [where, h])
	# Facilities' notice names the fire exit. Its row would have said CONTAINMENT.
	h = await solve(level, ui, level.main_doors_puzzle, _hunted(level))
	check(h <= rescue_tier(level.main_doors_puzzle) and level.accident, "%s: main_doors, opened by the notice's name, is the accident (hints %d)" % [where, h])
	level.custodian.process_mode = Node.PROCESS_MODE_DISABLED  # keep the walk deterministic: it's loose, but stands still
	check(_hunted(level), "%s: the Custodian is loose" % where)

	if seal:
		# The lockout, with the Custodian loose. The card by the panel (in view of the
		# plant desk) names the table and its columns; the row is the player's to build.
		h = await solve(level, ui, level.lockout_puzzle, _hunted(level))
		check(h <= rescue_tier(level.lockout_puzzle) and level.lockout_until > 0, "%s: the bay's lockout is logged, built from the card and the panel, or the ladder (hints %d)" % [where, h])
		ui.close()
		var tries := 0
		while not level.sealed and tries < 2:
			tries += 1
			if level.lockout_until == 0:
				# It lapsed: the row came out. Log it again (its query is on the screen now).
				ui.open(level.controller, p)
				await solve(level, ui, level.lockout_puzzle, _hunted(level))
				ui.close()
			# The clock, measured: across to the bay's panel at a run, then the read-back
			# as a first-time player reads, thinks and types (PACE_*).
			Engine.time_scale = 4.0
			paced = 0.0
			var ended := [-1.0]
			await _spend(_bay_run(level) / Player.SPRINT_SPEED)
			ui.open(level.bay_terminal, p)
			h = await solve(level, ui, level.readback_puzzle, _hunted(level), 3, "", true, func():
				if ended[0] < 0.0 and (level.sealed or level.lockout_until == 0):
					ended[0] = paced
				return ended[0] >= 0.0)
			ui.close()
			Engine.time_scale = 1.0
			print("  INFO  lockout read-back (seed %d, try %d): %s %d s after the lockout went in, of %d (%d hint%s)" % [seed_value, tries, "sealed" if level.sealed else "lapsed", ended[0], level.LOCKOUT_WINDOW, h, "" if h == 1 else "s"])
		check(level.sealed and _game().case_info("seal").get("solved", false), "%s: a first-time player seals the bay within two tries of the read-back clock" % where)
	else:
		ui.close()

	# Down STAIR 1 to the ground floor, where the crew came in.
	p.global_transform = Transform3D(Basis(), level.to_global(level.STAIR_OUT_AT + Vector3(2.4, 0.1, 0)))
	check(await _until(func(): return level.on_ground and not p.input_locked, 10.0), "%s: everyone on the stairs, and down to G" % where)
	level.lie_time = 0.3
	check_no_copy_under_pressure(level, where + ", on G")
	# The front doors: the lockup card shows the dock's UPDATE and names main_entrance.
	# Sealed, nothing hunts the crew down here (the architect knows; no fix asked).
	var calm := "" if _hunted(level) else "sealed, nothing hunts on G: told the architect 2026-10-21, no fix asked"
	ui.open(level.front_desk, p)
	h = await solve(level, ui, level.entrance_puzzle, _hunted(level), 3, calm)
	check(h <= rescue_tier(level.entrance_puzzle) and level.entrance_puzzle.solved, "%s: the front doors' row is changed, from the card's shape and its last line, or the ladder (hints %d)" % [where, h])
	check(_said(level.front_desk, level.TEXT.tip_dock), "%s: the card's dock UPDATE, copied, gets SYSOP's why" % where)
	check(await _until(func(): return level.db.read_only, 5.0), "%s: then Epsilon puts the row back" % where)
	var done := [false]
	level.completed.connect(func(): done[0] = true)
	h = await solve(level, ui, level.verify_puzzle, _hunted(level), 3, calm)
	check(h <= rescue_tier(level.verify_puzzle) and _game().case_info("entrance").get("solved", false), "%s: reading the row back shows the lie (hints %d)" % [where, h])
	ui.close()
	Engine.time_scale = 4.0
	check(await _until(func(): return done[0], 40.0), "%s: locked in, the floor ends" % where)
	Engine.time_scale = 1.0
	net.profile.earned = earned
	level.queue_free()
	await t.process_frame


## Something can hunt the crew on floor 10: the Custodian, from the accident until
## its bay is sealed.
func _hunted(level: Node) -> bool:
	return level.accident and not level.sealed


## How far a player runs from the controller to the bay's panel: out of the control
## room, along the hall and into the bay (metres, on the floor plan).
func _bay_run(level: Node) -> float:
	var way: Array = [level.controller.global_position, level.to_global(level.CTRL_DOOR_AT), level.to_global(level.BAY_DOOR_AT), level.bay_terminal.global_position]
	var metres := 0.0
	for i in way.size() - 1:
		var a: Vector3 = way[i]
		var b: Vector3 = way[i + 1]
		metres += Vector2(a.x - b.x, a.z - b.z).length()
	return metres


# --- Level 5: the Personnel Wing, floor 9 ---------------------------------------

## Floor 9 through the building's services: requests with the HR key in a header and a
## JSON body, typed as the hints show them in white or copied off the papers. Sealed on
## 10 (`seal`), the crew logs the work order, so POST is practised before the passes,
## and its stretch is paced as a first-time player against the air's grace; nothing
## hunts the passes and the lockup then (a known gap). Loose, the crew props the stair
## door instead: POST is new at the passes (ladder A), and the Custodian is up the dock
## stairs before them. The voice on the radio comes as soon as the service answers, so
## the crew checks it at the desk.
func walk_level_5(seed_value: int, seal: bool) -> void:
	_game().new_run(seed_value)
	_game().custodian_sealed = seal
	var level = load("res://scenes/level_5.tscn").instantiate()
	t.root.add_child(level)
	skip_chapters(level)
	for i in 20:
		await t.physics_frame
	level.completed.disconnect(level._on_completed)  # the walk ends with the floor, not in the next scene
	var net: Node = t.root.get_node("/root/Net")
	var earned: Array = net.profile.earned.duplicate()
	_copied.clear()
	var where := "personnel wing (seed %d, %s)" % [seed_value, "sealed, work order" if seal else "loose, stair door propped"]
	var ui: TerminalUI = level.terminal_ui
	var p: Player = level.player
	p.local_control = false
	level.lure_delay = 0.3

	# The HR front desk: the desk sheet's request carries the HR key in a header.
	_doc(level, "Personnel request sheet").open_reader(p).close()
	ui.open(level.hr, p)
	var h := await solve(level, ui, level.key_puzzle, _hunted_9(level))
	check(h <= rescue_tier(level.key_puzzle) and level.key_puzzle.solved, "%s: the HR service answers to the manager's key, from the desk sheet or the ladder (hints %d)" % [where, h])
	check(_said(level.hr, level.TEXT.tip_header), "%s: the sheet's request, sent without a key, gets 401 and SYSOP's word on where a key goes" % where)
	check(await _until(func(): return level.lures == 1, 5.0), "%s: then a voice on the radio wants the loading door" % where)
	h = await solve(level, ui, level.swipes_puzzle, _hunted_9(level))
	check(h <= rescue_tier(level.swipes_puzzle) and level.swipes_puzzle.solved and not level.dock_opened, "%s: the readers' log shows it isn't who it sounds like, and the loading door stays shut (hints %d)" % [where, h])
	ui.close()
	check_case_clues(level, where)
	check_jots(level, where)

	# Payroll's panel. The clipboard's crib is another panel's circuit and the carbon
	# copy another floor's order: copied, each gets SYSOP's why.
	if not seal:
		level.prop_time = 0.3
		level.prop.used.emit(p)  # propped on the way up: the floor clears without a work order
		check(await _until(func(): return level.air_cleared, 5.0), "%s: the stair door propped, the air clears" % where)
	_doc(level, "Facilities clipboard").open_reader(p).close()
	_doc(level, "Carbon copy").open_reader(p).close()
	ui.open(level.panel, p)
	h = await solve(level, ui, level.circuits_puzzle, _hunted_9(level))
	check(h <= rescue_tier(level.circuits_puzzle) and level.power_back, "%s: payroll's lights and the cage lock come back, the copiers off first, from the clipboard or the ladder (hints %d)" % [where, h])
	check(_said(level.panel, level.TEXT.tip_example), "%s: the clipboard's crib, copied, answers 404 and SYSOP says it's another panel's" % where)
	if seal:
		# From the power on, the air counts: the read-back and the work order, at a
		# first-timer's pace, inside the grace.
		Engine.time_scale = 4.0
		paced = 0.0
		h = await solve(level, ui, level.check_circuits_puzzle, _hunted_9(level), 3, "", true)
		check(h <= rescue_tier(level.check_circuits_puzzle) and level.check_circuits_puzzle.solved, "%s: the panel read back (hints %d)" % [where, h])
		var read_back := paced
		h = await solve(level, ui, level.air_puzzle, _hunted_9(level), 3, "", true)
		Engine.time_scale = 1.0
		print("  INFO  work order (seed %d): logged %d s after the power came back (the panel's read-back %d s, then the order), of the air's %d s grace (%d hint%s)" % [seed_value, paced, read_back, level.air_grace, h, "" if h == 1 else "s"])
		check(h <= rescue_tier(level.air_puzzle) and level.air_on, "%s: the work order logged for this floor's unit, from the carbon copy's shape and the clipboard, or the ladder (hints %d)" % [where, h])
		gap(level._air_ticks == 0, "%s: a first-time player reads the panel back and logs the work order before the air hurts (%d s of %d; told the architect 2026-10-22: a longer grace, or the clock from the read-back)" % [where, paced, level.air_grace])
		check(_said(level.panel, level.TEXT.tip_unit), "%s: the carbon copy's order, copied, goes in for floor 14's unit and SYSOP says so" % where)
		h = await solve(level, ui, level.check_air_puzzle, _hunted_9(level))
		check(h <= rescue_tier(level.check_air_puzzle) and level.check_air_puzzle.solved, "%s: the work order read back (hints %d)" % [where, h])
	else:
		h = await solve(level, ui, level.check_circuits_puzzle, _hunted_9(level))
		check(h <= rescue_tier(level.check_circuits_puzzle) and level.check_circuits_puzzle.solved, "%s: the panel read back (hints %d)" % [where, h])
		check(level.custodian_timed and not _hunted_9(level), "%s: with the power back and the air clear, the Custodian starts up the dock stairs" % where)
		level._custodian_arrives()  # its climb, cut short
		level.custodian.process_mode = Node.PROCESS_MODE_DISABLED  # keep the walk deterministic: it's loose, but stands still
		check(_hunted_9(level), "%s: the Custodian is loose on the floor" % where)
	ui.close()

	# The night-shifters, then the lockup, at the desk. The procedure's requests have
	# blanks (<their badge>, <door>): there's nothing on it to copy whole.
	_doc(level, "Escort procedure").open_reader(p).close()
	var ladder: String = "review" if seal else "a"
	check(level.passes_ladder == ladder, "%s: the passes take %s" % [where, "the review ladder: POST was practised at the work order" if seal else "ladder A: POST is new here"])
	level.passes_puzzle.set_meta("ladder", "review" if level.passes_ladder == "review" else "")
	var calm := "" if _hunted_9(level) else "sealed, nothing hunts the passes and the lockup: the architect put it to Augustine with plan/approvals/l5-text.md"
	ui.open(level.hr, p)
	h = await solve(level, ui, level.passes_puzzle, _hunted_9(level), 3, calm)
	check(h <= rescue_tier(level.passes_puzzle) and level.passes_puzzle.solved and level.out.size() == 2, "%s: both night-shifters passed and out, their doors opened through the service (hints %d)" % [where, h])
	h = await solve(level, ui, level.lockup_puzzle, _hunted_9(level), 3, calm)
	check(h <= rescue_tier(level.lockup_puzzle) and level.lockup_puzzle.solved, "%s: every door opened tonight locked again%s (hints %d)" % [where, "" if seal else ", the loading door too", h])
	h = await solve(level, ui, level.check_lockup_puzzle, _hunted_9(level), 3, calm)
	check(h <= rescue_tier(level.check_lockup_puzzle) and level.released, "%s: read back, STAIR 2 releases (hints %d)" % [where, h])
	if seal:
		# Optional, and safe here: Vale's own record (the review ladder, once the rest is done).
		h = await solve(level, ui, level.vale_puzzle, _hunted_9(level))
		check(h <= rescue_tier(level.vale_puzzle) and _game().case_info("vale").get("solved", false), "%s: Vale's record, by her badge from the staff list (hints %d)" % [where, h])
	ui.close()

	var done := [false]
	level.completed.connect(func(): done[0] = true)
	p.global_transform = Transform3D(Basis(), level.to_global(level.STAIR_OUT_AT + Vector3(-2.4, 0.1, 0)))
	Engine.time_scale = 4.0
	check(await _until(func(): return done[0], 40.0), "%s: everyone on STAIR 2, the floor ends" % where)
	Engine.time_scale = 1.0
	net.profile.earned = earned
	level.queue_free()
	await t.process_frame


## Something can hurt the crew on floor 9 while they type: the Custodian loose on the
## floor, or the air past its grace. The Mimics never attack (Augustine's call).
func _hunted_9(level: Node) -> bool:
	var air: bool = level.air_armed and level.power_back and not (level.air_on or level.air_cleared or level.released) and level._air_time >= level.air_grace
	return (level.custodian_here and not level.released) or air


## A pressure puzzle is built, not copied: no full query written on a paper within
## reach of a terminal (or on its boot screen) may pass a `pressure: true` puzzle.
## Writes are tried on a copy of the building, so the floor stays as it is.
func check_no_copy_under_pressure(level: Node, where: String) -> void:
	var copied := []
	for term in level.find_children("*", "Terminal", true, false):
		var on: FacilityDB = term.db
		var text := world_text(level, term) + "\n" + "\n".join(term.boot_lines)
		for q in queries_in(text):
			for shown in fill_blanks(level, q, term):
				var into: FacilityDB = _scratch(on) if FacilityDB.is_write(shown) else on
				var result: Dictionary = into.execute(shown)
				for p in _puzzles(level):
					# A write passes a state puzzle only if the rows weren't right already.
					if Curriculum.PUZZLES.get(p.id, {}).get("pressure", false) and p.matches(into, result) and not (p is StatePuzzle and p.state_ok(on)):
						copied.append("%s solves %s" % [shown, p.id])
	check(copied.is_empty(), "%s: no query written on a paper or boot screen passes a pressure puzzle (%s)" % [where, "; ".join(copied) if copied else "built, not copied"])


## A copy of the building to try a write on: what the query would do, with the
## floor left as it is.
func _scratch(of: FacilityDB) -> FacilityDB:
	var copy := FacilityDB.new()
	copy.db.query(of.dump())
	return copy


func _said(term: Node, line: String) -> bool:
	return Array(term.transcript).any(func(l): return TerminalUI._plain(l).contains(line))


func _doc(level: Node, title: String) -> Node:
	for d in level.find_children("*", "Document", true, false):
		if d.title == title:
			return d
	return null


# --- Found, practised safely, then used under pressure -----------------------

func check_teaching_order() -> void:
	var threat_first := []
	var owned_up := {}
	for k in first_use:
		if first_use[k] != "threat":
			continue
		# A puzzle row may own up to this ("threat_first": why); it prints as a gap.
		var spec: Dictionary = Curriculum.PUZZLES.get(first_use_by.get(k, ""), {})
		if spec.has("threat_first"):
			owned_up[first_use_by[k]] = true
			gap(false, "%s is first needed under threat, in %s (%s)" % [k, first_use_by[k], spec.threat_first])
		else:
			threat_first.append(k)
	check(threat_first.is_empty(), "every keyword is first needed somewhere safe, never first under threat%s" % ("" if threat_first.is_empty() else " (%s)" % ", ".join(threat_first)))
	# A row still owning up to a threat-first keyword that is now first used safely:
	# the marker is stale, so it prints FIXED until the row drops it.
	for id in Curriculum.PUZZLES:
		if Curriculum.PUZZLES[id].has("threat_first") and not owned_up.has(id):
			gap(true, "%s: its threat_first marker is stale (nothing it needs is first used under threat any more)" % id)
	var never := []
	for k in first_use:
		if not used_under_threat.has(k):
			never.append(k)
	# Not a failure in Levels 0-2: later levels must bring these back under pressure.
	print("  INFO  taught but not yet used under pressure: %s" % (", ".join(never) if not never.is_empty() else "none"))
