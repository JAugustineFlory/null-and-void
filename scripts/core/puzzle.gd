class_name Puzzle
extends RefCounted
## A puzzle is solved when a player's query returns the same data as the solution.
## Any correct query works, like in real life. Only the listed columns are compared,
## so `SELECT *` is fine as long as it includes them.

var id: String
var solution_sql: String
var columns: Array
var ordered: bool
## Three hint tiers: a nudge, a concept, then a near-answer.
var hints: Array
var hint_index := 0
var solved := false
## The notebook case page this puzzle belongs to (its own id unless set).
var case_id := ""
## Values its result shows that the player already knew before running it (names
## from a paper, the case's own premise), so they aren't the answer. The teaching
## tests let case-page clues carry these.
var givens: Array = []


func _init(p_id: String, p_solution: String, p_columns: Array, p_ordered: bool, p_hints: Array = []) -> void:
	id = p_id
	solution_sql = p_solution
	columns = p_columns
	ordered = p_ordered
	hints = p_hints
	case_id = p_id


## Any correct form passes: a required column is matched by name, or, when the player
## named it differently (COUNT(slip_no), COUNT(*) AS n), by its values, as long as the
## whole result then agrees. With `distinct`, repeated rows collapse before comparing
## (a list of boxes and the one room they share are the same answer). `accept_also`
## adds another shape of right answer (the top row with its count, say).
var distinct := false
var alternatives: Array = []


## Another right answer with its own shape: `cols` are the columns it must show.
func accept_also(sql: String, cols: Array, p_ordered: bool) -> void:
	alternatives.append({"sql": sql, "columns": cols, "ordered": p_ordered})


func matches(db: FacilityDB, result: Dictionary) -> bool:
	if not result.ok or result.rows.is_empty():
		return false
	if _matches_shape(db, result, solution_sql, columns, ordered):
		return true
	for alt in alternatives:
		if _matches_shape(db, result, alt.sql, alt.columns, alt.ordered):
			return true
	return false


func _matches_shape(db: FacilityDB, result: Dictionary, sql: String, cols: Array, is_ordered: bool) -> bool:
	var have := []  # the result's column names, lower case
	for c in result.columns:
		have.append(str(c).to_lower())
	var mapping := {}
	var missing := []
	for c in cols:
		if have.has(c):
			mapping[c] = c
		else:
			missing.append(c)
	var spare := have.filter(func(k): return not cols.has(k))
	if missing.size() > 2 or missing.size() > spare.size():
		return false
	var expected := _project(db.run_silent(sql), cols, {})
	if missing.is_empty():
		return _same(_project(result.rows, cols, mapping), expected, is_ordered)
	# A column the player named differently: try each spare column in its place.
	for a in spare:
		var m1 := mapping.duplicate()
		m1[missing[0]] = a
		if missing.size() == 1:
			if _same(_project(result.rows, cols, m1), expected, is_ordered):
				return true
			continue
		for b in spare:
			if b == a:
				continue
			var m2 := m1.duplicate()
			m2[missing[1]] = b
			if _same(_project(result.rows, cols, m2), expected, is_ordered):
				return true
	return false


func _same(got: Array, expected: Array, is_ordered: bool) -> bool:
	if distinct:
		got = _unique(got)
		expected = _unique(expected)
	if not is_ordered or distinct:
		got.sort()
		expected.sort()
	return got == expected


func _unique(rows: Array) -> Array:
	var seen := {}
	for r in rows:
		seen[r] = true
	return seen.keys()


func next_hint() -> String:
	if hints.is_empty():
		return "No hints for this one."
	var h: String = hints[min(hint_index, hints.size() - 1)]
	hint_index += 1
	return h


## Each row as one string of the required columns' values, in `cols` order. `mapping`
## says which result column stands for each required one (by name when absent).
func _project(rows: Array, cols: Array, mapping: Dictionary) -> Array:
	var out := []
	for row in rows:
		var lowered := {}
		for k in row.keys():
			lowered[str(k).to_lower()] = row[k]
		var parts := PackedStringArray()
		for c in cols:
			parts.append(str(lowered.get(mapping.get(c, c), "<missing>")))
		out.append("\u001f".join(parts))
	return out
