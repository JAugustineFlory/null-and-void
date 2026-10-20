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


func _init(p_id: String, p_solution: String, p_columns: Array, p_ordered: bool, p_hints: Array = []) -> void:
	id = p_id
	solution_sql = p_solution
	columns = p_columns
	ordered = p_ordered
	hints = p_hints
	case_id = p_id


func matches(db: FacilityDB, result: Dictionary) -> bool:
	if not result.ok or result.rows.is_empty():
		return false
	var lower_cols := []
	for c in result.columns:
		lower_cols.append(str(c).to_lower())
	for c in columns:
		if not lower_cols.has(c):
			return false
	var got := _project(result.rows)
	var expected := _project(db.run_silent(solution_sql))
	if not ordered:
		got.sort()
		expected.sort()
	return got == expected


func next_hint() -> String:
	if hints.is_empty():
		return "No hints for this one."
	var h: String = hints[min(hint_index, hints.size() - 1)]
	hint_index += 1
	return h


func _project(rows: Array) -> Array:
	var out := []
	for row in rows:
		var lowered := {}
		for k in row.keys():
			lowered[str(k).to_lower()] = row[k]
		var parts := PackedStringArray()
		for c in columns:
			parts.append(str(lowered.get(c, "<missing>")))
		out.append("\u001f".join(parts))
	return out
