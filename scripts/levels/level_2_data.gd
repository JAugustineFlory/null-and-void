class_name Level2Data
extends RefCounted
## Builds Level 2's database from a seed: the guard roster and the camera list.
## The logic stays the same every run: the coffee-smudged name on tonight's
## night-shift sign-in sheet starts with "Har", and exactly one guard whose name
## starts with Har works nights. Everyone else who could be mistaken for them
## carries a note saying why their PIN won't work.

const HAR_NAMES := ["HARLAN", "HARMON", "HARGROVE", "HARDY", "HARTLEY", "HARPER"]
## Names that contain "har" but don't start with it, to catch LIKE '%Har%'.
const HAR_INSIDE := ["RICHARDS", "SHARPE", "BLANCHARD", "ORCHARD"]
const OTHER_NAMES := [
	"ABBOTT", "ALVAREZ", "BECK", "BOYLE", "BRENNAN", "CALLOWAY", "CHEN", "COLLINS", "DALTON",
	"DIAZ", "DOYLE", "ELLIS", "FENWICK", "FLYNN", "FOSTER", "GALLO", "GREER", "HOLDEN", "IBARRA",
	"JENSEN", "KANE", "KOWALSKI", "LANG", "LOWELL", "MADDOX", "MALONE", "MENDEZ", "MORROW", "NASH",
	"NOLAN", "OKAFOR", "OWENS", "PATEL", "QUINN", "REYES", "ROSS", "SALAZAR", "SLOAN", "STONE",
	"TATE", "TOBIN", "UPTON", "VANCE", "WADE", "WEBB", "YATES", "ZIMMER", "BOWEN", "CROSS",
	"DUNN", "EATON", "FRYE", "GOODE", "KEMP", "LYONS", "MOSS", "PRICE", "SUTTON", "WELLS",
]
const INITIALS := "ABCDEFGJKLMNRSTW"


static func build(run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var used_pins := {}
	var guards := []  # [name, shift, pin, note]

	# The three Har- guards: one night (the answer), one day, one retired.
	var har := HAR_NAMES.duplicate()
	_shuffle(har, rng)
	var answer_name := _full(har[0], rng)
	var answer_pin := _pin(rng, used_pins)
	guards.append([answer_name, "night", answer_pin, "night shift lead. Signed in 22:00"])
	guards.append([_full(har[1], rng), "day", _pin(rng, used_pins), "day shift. Clocked out 18:04"])
	guards.append([_full(har[2], rng), "swing", _pin(rng, used_pins), "retired 1995. PIN revoked"])

	# Officer Pike: signed in legibly, then vanished. Players practice LIKE on him.
	var pike_pin := _pin(rng, used_pins)
	guards.append(["PIKE, H.", "night", pike_pin, "missing since 23:40. PIN suspended"])

	# Names with "har" in the middle. At least one works nights.
	var inside := HAR_INSIDE.duplicate()
	_shuffle(inside, rng)
	for i in inside.size():
		var shift: String = "night" if i < 2 else ["day", "swing"][rng.randi_range(0, 1)]
		guards.append([_full(inside[i], rng), shift, _pin(rng, used_pins), "not on tonight's sign-in sheet"])

	var shifts := ["day", "swing", "night"]
	var reasons := {
		"day": ["day shift", "day shift. Clocked out 18:00", "day shift. On vacation until 10/20"],
		"swing": ["swing shift. Clocked out 22:00", "swing shift", "swing shift. Off sick"],
		"night": ["night off", "on leave", "not on tonight's sign-in sheet"],
	}
	for n in OTHER_NAMES:
		var shift: String = shifts[rng.randi_range(0, 2)]
		var note: String = reasons[shift][rng.randi_range(0, 2)]
		guards.append([_full(n, rng), shift, _pin(rng, used_pins), note])

	_shuffle(guards, rng)
	var rows := []
	for i in guards.size():
		var g: Array = guards[i]
		rows.append("('G-%03d', '%s', '%s', '%s', '%s')" % [100 + i, g[0], g[1], g[2], str(g[3]).replace("'", "''")])

	var sql := """
CREATE TABLE guards (
	badge_id TEXT,
	name TEXT,
	shift TEXT,
	pin TEXT,
	note TEXT
);
INSERT INTO guards VALUES
	%s;

CREATE TABLE cameras (
	id TEXT,
	location TEXT,
	status TEXT,
	last_frame TEXT,
	motion INTEGER,
	note TEXT
);
INSERT INTO cameras VALUES
	('CAM-1', 'Security corridor', 'offline', NULL, 0, 'lens smashed 10/13. Ticket open'),
	('CAM-2', 'Security Office', 'live', '00:41:00', 1, 'normal'),
	('CAM-3', 'Exit vestibule', 'live', '00:41:00', 0, 'normal'),
	('CAM-4', 'Break room', 'offline', NULL, 0, 'unplugged for the coffee machine'),
	('CAM-5', 'East ledge (outside)', 'live', '00:41:00', 0, 'normal');

CREATE TABLE doors (
	id TEXT,
	name TEXT,
	zone TEXT,
	locked INTEGER,
	actuator_fault INTEGER
);
INSERT INTO doors VALUES
	('SEC-EXIT', 'Security wing stairwell', 'S', 1, 0),
	('SRA-EXIT', 'Server Room A rear exit', 'A', 1, 0);
""" % ",\n\t".join(rows)
	return {"sql": sql, "pin": answer_pin, "name": answer_name, "pike_pin": pike_pin}


static func _full(surname: String, rng: RandomNumberGenerator) -> String:
	return "%s, %s." % [surname, INITIALS[rng.randi_range(0, INITIALS.length() - 1)]]


static func _pin(rng: RandomNumberGenerator, used: Dictionary) -> String:
	while true:
		var p := "%04d" % rng.randi_range(1000, 9999)
		if not used.has(p):
			used[p] = true
			return p
	return ""


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
