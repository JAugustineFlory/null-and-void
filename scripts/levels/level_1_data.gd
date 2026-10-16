class_name Level1Data
extends RefCounted
## Builds Level 1's database from a seed, so each run has a different faulted controller.
## The logic stays the same: exactly one controller is in zone A AND has status 'fault'.
## Every other controller that isn't 'ok' carries a note saying why it can be ignored,
## so players who read the whole table can tell the decoys apart.

const ROOM_RACKS := 8  # DC-1 .. DC-8 are physical racks in Server Room A


static func build(run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var rack_ids := []
	for i in range(1, ROOM_RACKS + 1):
		rack_ids.append(i)
	_shuffle(rack_ids, rng)
	var zone_a: Array = rack_ids.slice(0, 4)
	var zone_b_room: Array = rack_ids.slice(4, 8)
	var answer: int = zone_a[0]
	var offline_a: int = zone_a[1]
	var fault_b: int = zone_b_room[0]

	var rows := []
	for i in range(1, 13):
		var zone := "C"
		if zone_a.has(i):
			zone = "A"
		elif zone_b_room.has(i) or i == 9 or i == 10:
			zone = "B"
		var status := "ok"
		if i == answer or i == fault_b or i == 11:
			status = "fault"
		elif i == offline_a or i == 12:
			status = "offline"
		var where := "Server Room A, rack %d" % i if i <= ROOM_RACKS else ("Cold Lab" if zone == "C" else "Records Archive")
		var note := "normal"
		if i == answer:
			note = "lock relay stuck. Needs a manual reset."
		elif i == offline_a:
			note = "off on purpose: maintenance 10/14"
		elif i == fault_b:
			note = "runs Records Archive door, not this room"
		elif i == 11:
			note = "runs Cold Lab door. Ice in lock, ticket open"
		elif i == 12:
			note = "decommissioned 1996"
		var reset_at := "1997-10-%02d %02d:%02d" % [rng.randi_range(1, 12), rng.randi_range(0, 23), rng.randi_range(0, 59)]
		rows.append("('DC-%d', '%s', '%s', '%s', '%s', '%s')" % [i, zone, status, where, reset_at, note])

	var sql := """
CREATE TABLE door_controllers (
	id TEXT,
	zone TEXT,
	status TEXT,
	location TEXT,
	last_reset TEXT,
	note TEXT
);
INSERT INTO door_controllers VALUES
	%s;

-- doors and badges are building-wide tables (FacilityDB.SHARED_SCHEMA); this wing only adds rows.
INSERT INTO doors VALUES
	('SRA-ENTRY', 'Server Room A entrance', 'A', 0, 0),
	('SRA-EXIT', 'Server Room A rear exit', 'A', 1, 0),
	('COLD-LAB', 'Cold Lab', 'C', 1, 0),
	('ARCHIVE', 'Records Archive', 'B', 0, 0);

INSERT INTO badges VALUES
	('R-0117', 'ROURKE, D.', 'ESCORT', 'Server Room A'),
	('V-0042', 'VALE, I.', 'LEAD', 'Incinerator wing'),
	('P-0230', 'PIKE, H.', 'SECURITY', 'Security Office'),
	('D-0001', 'DIRECTOR', 'ALL', 'Offsite');
""" % ",\n\t".join(rows)
	return {"sql": sql, "answer": "DC-%d" % answer}


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
