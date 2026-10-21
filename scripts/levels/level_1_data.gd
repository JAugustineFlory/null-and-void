class_name Level1Data
extends RefCounted
## Builds Level 1's database from a seed, so each run has a different faulted
## controller in a different zone. Nothing printed names the zone: players read
## it off the stuck doors in the doors table (the plates on the doors only show a red light).
## The logic stays the same: exactly one controller is in the stuck doors' zone AND
## has status 'fault'. Every other controller that isn't 'ok' carries a note saying
## why it can be ignored, so players who read the whole table can tell the decoys apart.
## Also seeded: Server Room B's overheating rack (racks.temp_c > 40) and the floor's
## lights: the break room's is 'dead' and the north corridor's 'flickering' (the
## optional dark room: dead OR flickering), and an unused bay is 'off' on purpose.
## How many controllers are faulted floor-wide (the reset sign-off's COUNT) varies
## (3, 5 or 6): the answer, the Records Archive and Cold Lab ones, and 0, 2 or 3 more
## Records Archive controllers (DC-13 on), outside the stuck doors' zone. Those counts
## never equal a tempting wrong count: a zone's controllers (4), the healthy ones (7),
## Server Room A's racks (8), every controller, or every one that isn't 'ok'.

const ROOM_RACKS := 8  # DC-1 .. DC-8 are physical racks in Server Room A
const SRB_RACKS := 6  # RB-1 .. RB-6 in Server Room B
## The server floor's stuck doors (named in the NOC shift log), all in the faulted zone.
const STUCK_DOORS := ["SRA-EXIT", "SRC", "LIFT-1"]
## The fire interlock on the cable vault's back door: sealed while any rack is over this.
const INTERLOCK_C := 40


static func build(run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var letters := ["A", "B", "C", "D", "E", "F"]
	_shuffle(letters, rng)
	var zone: String = letters[0]  # this floor's stuck doors and the faulted controller
	var other: String = letters[1]  # the rest of the floor, and half of Server Room A
	var cold: String = letters[2]  # the Cold Lab, another floor's problem
	var rack_ids := []
	for i in range(1, ROOM_RACKS + 1):
		rack_ids.append(i)
	_shuffle(rack_ids, rng)
	var zone_a: Array = rack_ids.slice(0, 4)
	var zone_b_room: Array = rack_ids.slice(4, 8)
	var answer: int = zone_a[0]
	var offline_a: int = zone_a[1]
	var fault_b: int = zone_b_room[0]
	# Its own generator, so the rest of a seed's data stays as it was.
	var extra_rng := RandomNumberGenerator.new()
	extra_rng.seed = hash([run_seed, "extra_faults"])
	var extra_faults: int = [0, 2, 3][extra_rng.randi_range(0, 2)]

	var rows := []
	for i in range(1, 13):
		var z := cold
		if zone_a.has(i):
			z = zone
		elif zone_b_room.has(i) or i == 9 or i == 10:
			z = other
		var status := "ok"
		if i == answer or i == fault_b or i == 11:
			status = "fault"
		elif i == offline_a or i == 12:
			status = "offline"
		var where := "Server Room A, rack %d" % i if i <= ROOM_RACKS else ("Cold Lab" if z == cold else "Records Archive")
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
		rows.append("('DC-%d', '%s', '%s', '%s', '%s', '%s')" % [i, z, status, where, reset_at, note])
	for i in range(13, 13 + extra_faults):
		var reset_at := "1997-10-%02d %02d:%02d" % [extra_rng.randi_range(1, 12), extra_rng.randi_range(0, 23), extra_rng.randi_range(0, 59)]
		rows.append("('DC-%d', '%s', 'fault', 'Records Archive', '%s', 'runs Records Archive door. Ticket open')" % [i, other, reset_at])

	# Server Room B: one rack runs hot. Another sits right on the limit, so > and >=
	# give different answers, and a rack in the locked Server Room C runs warm too.
	var hot: int = rng.randi_range(1, SRB_RACKS)
	var edge: int = hot % SRB_RACKS + 1
	var racks := []
	for i in range(1, SRB_RACKS + 1):
		var t := rng.randi_range(24, 34)
		var load := rng.randi_range(30, 70)
		var note := "normal"
		if i == hot:
			t = rng.randi_range(INTERLOCK_C + 3, INTERLOCK_C + 9)
			load = rng.randi_range(85, 98)
			note = "fan alarm"
		elif i == edge:
			t = INTERLOCK_C
			note = "warm. watch it"
		racks.append("('RB-%d', 'Server Room B', %d, %d, '%s')" % [i, t, load, note])
	racks.append("('RC-1', 'Server Room C', 37, 55, 'normal')")
	racks.append("('RC-2', 'Server Room C', 35, 41, 'normal')")

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

CREATE TABLE racks (
	id TEXT,
	room TEXT,
	temp_c INTEGER,
	load_pct INTEGER,
	note TEXT
);
INSERT INTO racks VALUES
	%s;

-- doors, lights and badges are building-wide tables (FacilityDB.SHARED_SCHEMA);
-- this wing only adds rows. The doors that won't release share the faulted zone.
INSERT INTO doors VALUES
	('SRA-ENTRY', 'Server Room A entrance', '{zone}', 0, 0),
	('SRA-EXIT', 'Server Room A rear exit', '{zone}', 1, 1),
	('SRC', 'Server Room C', '{zone}', 1, 1),
	('LIFT-1', 'Lift 1, server floor', '{zone}', 1, 1),
	('NOC', 'Network operations', '{other}', 0, 0),
	('CABLE-VAULT', 'Cable vault', '{other}', 0, 0),
	('BREAK', 'Break room', '{other}', 0, 0),
	('SRB', 'Server Room B', '{other}', 0, 0),
	('COLD-LAB', 'Cold Lab', '{cold}', 1, 1),
	('ARCHIVE', 'Records Archive', '{other}', 0, 0);

-- One row per room; a row whose id is a light group (LevelBase.add_light) switches it.
INSERT INTO lights VALUES
	('room', 'Server Room A', 1, 1, 'ok'),
	('noc', 'Network operations', 1, 1, 'ok'),
	('vault', 'Cable vault', 1, 1, 'ok'),
	('srb', 'Server Room B', 1, 1, 'ok'),
	('1-BREAK', 'Break room', 1, 0, 'dead'),
	('src', 'Server Room C', 1, 1, 'ok'),
	('1-HALL-N', 'North corridor', 1, 1, 'flickering'),
	('1-VAULT-BAY', 'Cable vault spare bay (unused)', 1, 0, 'off');

INSERT INTO badges VALUES
	('R-0117', 'ROURKE, D.', 'ESCORT', 'Server Room A'),
	('V-0042', 'VALE, I.', 'LEAD', 'Incinerator wing'),
	('P-0230', 'PIKE, H.', 'SECURITY', 'Security Office'),
	('D-0001', 'DIRECTOR', 'ALL', 'Offsite');
""" % [",\n\t".join(rows), ",\n\t".join(racks)]
	sql = sql.format({"zone": zone, "other": other, "cold": cold})
	return {"sql": sql, "answer": "DC-%d" % answer, "zone": zone, "other_zone": other, "hot_rack": "RB-%d" % hot, "faulted": 3 + extra_faults}


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
