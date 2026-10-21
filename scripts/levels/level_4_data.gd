class_name Level4Data
extends RefCounted
## Builds Level 4's database from a seed: the Power Plant on floor 10, the tower's
## mid-height mechanical floor. Each table has a visible source in the world:
##   breakers        the breaker panel along the switchgear hall's west wall (one
##                   labelled box per row, with its tag hanging off it)
##   contractor_log  the clipboard by the controller terminal: who logged in to work
##                   on the plant, and when
## The floor's doors and lights are rows in the building-wide tables.
##
## What stays the same every run: Tuesday's power event tripped the PLANT CONTROL
## breaker, so the door and lift control room has no power and its door can't open.
## Facilities' work order says to reset it. Which box it is changes with the seed. The
## other tripped or switched-off breakers each carry a tag saying why they stay off.

## Every circuit on the floor's panel: [circuit, feeds]. The work order's example is
## always CB-03 (the riser fans), so its own id never changes.
const TARGET := ["PLANT CONTROL", "Door and lift control room: lights, door power"]
const EXAMPLE_ID := "CB-03"
const EXAMPLE := ["RISER FANS", "Stair and lift shaft fans"]
## Off for a reason: each one's tag says why, so a crew reading SELECT * can rule it out.
## The charging bay's is the floor's foreshadowing: switched back on (no WHERE), the
## thing in the bay stirs behind its door.
const DECOYS := [
	["CHARGING BAY", "Custodian charging bay", "tripped", "Tripped Tue. LEAVE OFF until Facilities has inspected the bay. - R.O."],
	["LIFT MOTORS", "Lifts 1-4 hoist motors", "off", "LOCKED OUT by Coastline Elevator Co. Do not reset."],
	["CANTEEN 11", "Floor 11 canteen (fed from 10)", "tripped", "Floor 11's ticket, not ours. Their kitchen trips it nightly."],
]
const ON := [
	["FLOOR 10 LIGHTS", "Plant hall and corridor lights"],
	["GANTRY ARM", "Switchgear gantry arm"],
	["STAIR LIGHTS", "STAIR 1 lights, all floors"],
	["PUMPS", "Chilled water pumps"],
	["UPS 10", "Plant 10 battery backup"],
	["WORKSHOP", "Plant workshop sockets"],
	["EMERGENCY LIGHTS", "Exit signs and emergency lights"],
]
## The clock over the controller room's door reads 00:MM, and that's the time the
## crew logs in with.
const CLOCK_HOUR := 0
## The crew's company, as printed on its work order.
const COMPANY := "Byte-Right IT Services"


static func build(run_seed: int, ticket: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 7919 + 4
	# Breaker ids CB-01..CB-12: the example keeps CB-03, the rest are dealt out.
	var circuits: Array = [TARGET] + DECOYS + ON
	var ids := []
	for i in range(1, circuits.size() + 2):
		var id := "CB-%02d" % i
		if id != EXAMPLE_ID:
			ids.append(id)
	_shuffle(ids, rng)
	var rows := []  # [id, circuit, feeds, state, note]
	var target_id: String = ids[0]
	rows.append([target_id, TARGET[0], TARGET[1], "tripped", "Tripped Tue. 10/14, power event"])
	for i in DECOYS.size():
		var d: Array = DECOYS[i]
		rows.append([ids[1 + i], d[0], d[1], d[2], d[3]])
	for i in ON.size():
		rows.append([ids[1 + DECOYS.size() + i], ON[i][0], ON[i][1], "on", ""])
	rows.append([EXAMPLE_ID, EXAMPLE[0], EXAMPLE[1], "on", "Reset 09/22, WO-11873"])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	var start_states := {}
	for r in rows:
		start_states[r[0]] = r[3]

	# The contractor log: earlier jobs this month, oldest first, each in the
	# clipboard's column order. The lift contractor's is the one that locked out the
	# lift motors, so its tag and its row agree.
	var minute := rng.randi_range(12, 58)
	var time_in := "%02d:%02d" % [CLOCK_HOUR, minute]
	var log := [
		["Delmont Courier", "WO-%05d" % rng.randi_range(10000, 99999), "14:20"],
		["Quill Pest Control", "WO-%05d" % rng.randi_range(10000, 99999), "07:45"],
		["Coastline Elevator Co.", "WO-%05d" % rng.randi_range(10000, 99999), "10:15"],
	]
	var sql := """
-- The breaker panel on floor 10: one row per breaker box, as its label and tag read.
CREATE TABLE breakers (
	id TEXT,
	circuit TEXT,
	feeds TEXT,
	state TEXT,
	note TEXT
);
INSERT INTO breakers VALUES
	%s;

-- The plant's contractor log, kept on the controller (the clipboard says log in first).
CREATE TABLE contractor_log (
	company TEXT,
	job TEXT,
	time_in TEXT
);
INSERT INTO contractor_log VALUES
	%s;

-- doors and lights are building-wide (FacilityDB.SHARED_SCHEMA). This wing adds floor 10's
-- rows. The control room's door is unlocked but has no power until its breaker is reset:
-- the database says open, the door stays shut (actuator_fault).
INSERT INTO doors VALUES
	('PLANT-CTRL', 'Plant 10, door and lift control', 'P', 0, 1),
	('PLANT-BAY', 'Plant 10, charging bay', 'P', 1, 0);
INSERT INTO lights VALUES
	('L10-LOBBY', 'Lift lobby', 10, 1, 'ok'),
	('L10-HALL', 'Switchgear hall', 10, 1, 'ok'),
	('L10-CTRL', 'Door and lift control', 10, 0, 'no power: breaker tripped'),
	('L10-BAY', 'Charging bay', 10, 0, 'no power: breaker tripped');
""" % [
		",\n\t".join(rows.map(_values)),
		",\n\t".join(log.map(_values)),
	]
	return {"sql": sql, "target": target_id, "breakers": rows, "start_states": start_states,
		"decoys": rows.filter(func(r): return r[0] != target_id and r[3] != "on").map(func(r): return r[0]),
		"bay_breaker": rows.filter(func(r): return r[1] == DECOYS[0][0])[0][0],
		"time_in": time_in, "ticket": ticket, "company": COMPANY, "log": log,
		"example_log": log[2]}


## One row's values, quoted for SQL. A null stays a real NULL.
static func _values(row: Array) -> String:
	return "(%s)" % ", ".join(row.map(func(v): return "NULL" if v == null else "'%s'" % str(v).replace("'", "''")))


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
