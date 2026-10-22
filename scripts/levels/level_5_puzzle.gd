class_name RequestPuzzle
extends Puzzle
## A puzzle solved through the building's services (Level 5's GET, POST and PATCH
## stations), never by the request's text. `passes` is given the request as typed
## and the service's answer ({status, body}) and decides from what happened: the
## answer's status and body, or the state the service is left in (`state_ok`). The
## hint ladder is the same as a query's, and its last tier ends on `solution_sql`,
## which here is one request that does it (several lines when it carries a header
## or a body).

## Callable(line: String, res: Dictionary) -> bool: did this request do it?
var passes: Callable
## Callable() -> bool: is the service in the state the station wants, however it
## got there? Empty when only the answer counts.
var state: Callable


func _init(p_id: String, p_solution: String, p_passes: Callable, p_hints: Array = [], p_state := Callable()) -> void:
	super(p_id, p_solution, [], false, p_hints)
	passes = p_passes
	state = p_state


## A request went through: the station passes when the answer, or the state it
## leaves, is right.
func request_matches(line: String, res: Dictionary) -> bool:
	if passes.is_valid() and passes.call(line, res):
		return true
	return state_ok()


func state_ok() -> bool:
	return state.is_valid() and state.call()


## Requests aren't queries: a SQL result never solves a request station.
func matches(_db: FacilityDB, _result: Dictionary) -> bool:
	return false
