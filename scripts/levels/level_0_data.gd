class_name Level0Data
extends RefCounted
## Builds the ground floor's database from a seed: the memo scraps (data/level_0.sql),
## plus a staff directory and visitor log whose numbers change every run, so a
## walkthrough can't hand over the caller's extension or Vale's sign-in time.
##   - staff_directory: the work order's caller extension is Harold Mercer's line,
##     though he left in 1994. Another Building Services row means the department
##     alone doesn't give him away: the extension does.
##   - visitors: stored oldest first; sorted newest first, the crew's own row comes
##     top, then Vale's, never signed out.
##   - lights: the ground floor's rooms (the east corridor's is dead).

const SEED_PATH := "res://data/level_0.sql"
const CALLER := "Harold Mercer"
const CALLER_DEPT := "Building Services"


static func build(run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var used := {}
	var ext := func(lo: int, hi: int) -> int:
		var n := rng.randi_range(lo, hi)
		while used.has(n):
			n = rng.randi_range(lo, hi)
		used[n] = true
		return n
	var caller_ext: int = ext.call(4100, 4899)
	# name, title, dept, extension, floor, email, status
	var staff := [
		["Harold Mercer", "Founder", CALLER_DEPT, caller_ext, "G", "hmercer", "LEFT 03/94"],
		["Iris Vale", "Lead Engineer", "Research", ext.call(2300, 2399), "22", "ivale", "MISSING"],
		["Dale Rourke", "Facilities Manager", "Facilities", 2210, "G", "drourke", "ON SHIFT"],
		["Harlan Pike", "Night Security", "Security", 1102, "22", "hpike", "NO SHOW"],
		["Office of the Director", "Director", "Executive", 1000, "30", "director", "OFFSITE"],
		["Ruth Okonkwo", "Building Engineer", CALLER_DEPT, ext.call(4100, 4899), "G", "rokonkwo", "DAY SHIFT"],
		["Glen Haskins", "Network Admin", "IT", ext.call(3100, 3999), "14", "ghaskins", "DAY SHIFT"],
		["Tess Marlow", "NOC Operator", "IT", ext.call(3100, 3999), "14", "tmarlow", "NIGHT SHIFT"],
		["Paul Brandt", "Mailroom Clerk", "Mail Services", ext.call(1200, 1299), "G", "pbrandt", "DAY SHIFT"],
		["Nadia Ferris", "Receptionist", "Front Desk", ext.call(1000, 1099), "G", "nferris", "DAY SHIFT"],
		["Owen Sato", "Research Assistant", "Research", ext.call(2300, 2399), "22", "osato", "ON LEAVE"],
		["Carla Dimas", "Payroll", "Finance", ext.call(5000, 5999), "9", "cdimas", "DAY SHIFT"],
	]
	var vale_min := rng.randi_range(31, 55)
	var vale_in := "1997-10-15 21:%02d" % vale_min
	var staff_rows := staff.map(func(r): return "('%s', '%s', '%s', %d, '%s', '%s@halcyon.com', '%s')" % r)
	var sql := FileAccess.get_file_as_string(SEED_PATH) + """

CREATE TABLE staff_directory (
	name TEXT,
	title TEXT,
	dept TEXT,
	extension INTEGER,
	floor TEXT,
	email TEXT,
	status TEXT
);
INSERT INTO staff_directory VALUES
	%s;

CREATE TABLE visitors (
	id INTEGER,
	name TEXT,
	company TEXT,
	escort TEXT,
	signed_in TEXT,
	signed_out TEXT
);
INSERT INTO visitors VALUES
	(306, 'M. Quill', 'Quill Pest Control', 'ROURKE, D.', '1997-10-10 07:30', '1997-10-10 08:05'),
	(307, 'Board delegation', 'Halcyon Board', 'DIRECTOR', '1997-10-13 09:00', '1997-10-13 11:30'),
	(308, 'T. Reyes', 'Coastline Elevator Co.', 'ROURKE, D.', '1997-10-14 10:15', '1997-10-14 13:40'),
	(309, 'P. Okafor', 'Delmont Courier', 'NONE', '1997-10-15 16:40', '1997-10-15 16:52'),
	(310, 'VALE, I.', 'Halcyon (staff)', 'NONE', '%s', NULL),
	(311, 'Contract IT crew', 'Byte-Right IT Services', 'ROURKE, D.', '1997-10-15 23:04', NULL);

-- lights is building-wide (FacilityDB.SHARED_SCHEMA): one row per room. A row
-- whose id is a light group (LevelBase.add_light) switches that group's lights.
INSERT INTO lights VALUES
	('lobby', 'Lobby', 0, 1, 'ok'),
	('mailroom', 'Mailroom', 0, 1, 'ok'),
	('cafeteria', 'Cafeteria', 0, 1, 'ok'),
	('it_closet', 'IT closet', 0, 1, 'ok'),
	('G-EAST', 'East corridor', 0, 0, 'dead');
""" % [",\n\t".join(staff_rows), vale_in]
	return {"sql": sql, "extension": caller_ext, "caller": CALLER, "vale_in": vale_in, "staff": staff}


## What the work order's "Caller:" line says for this run.
static func caller_line(run_seed: int) -> String:
	return "ext. %d, building services" % build(run_seed).extension
