class_name StatePuzzle
extends Puzzle
## A puzzle solved by changing the database, not by reading it (Level 4's UPDATE and
## INSERT stations). After any write that changed a row, the table's state is read
## back with `state_sql` and compared, as a result set, with `expected_sql`: any
## write, or run of writes, that leaves the right rows passes. `solution_sql` is one
## write that does it (the hint ladder's last tier ends on it).

var state_sql := ""
var expected_sql := ""


func _init(p_id: String, p_solution: String, p_state: String, p_expected: String, p_columns: Array, p_hints: Array = []) -> void:
	super(p_id, p_solution, p_columns, false, p_hints)
	state_sql = p_state
	expected_sql = p_expected


## Only a write that changed something counts; then the table's state decides.
func matches(db: FacilityDB, result: Dictionary) -> bool:
	if not result.get("ok", false) or int(result.get("changes", 0)) == 0:
		return false
	return state_ok(db)


## Whether the table is as it should be now, however it got there.
func state_ok(db: FacilityDB) -> bool:
	var rows := db.run_silent(state_sql)
	if rows.is_empty():
		return false
	return _matches_shape(db, {"ok": true, "rows": rows, "columns": rows[0].keys()}, expected_sql, columns, false)
