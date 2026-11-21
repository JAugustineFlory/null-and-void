class_name Level2Data
extends RefCounted
## Builds Level 2's database from a seed: the guard roster, the camera list, and
## the badge readers' log, whose last guard swipe through SEC-EXIT is the night lead.
## The logic stays the same every run: the coffee-smudged name on tonight's
## night-shift sign-in sheet (the paper backup of the badge reader, which logs
## guards into this table) starts with "Har", and exactly one guard whose name
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
	"ROWE",
]
const INITIALS := "ABCDEFGJKLMNRSTW"
## The terminal policy's cap (TerminalPolicy.CAP): rows a query shows at most.
const CAP_ROWS := 20


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
	guards.append([answer_name, "night", answer_pin, "night shift lead. Badged in 22:00"])
	guards.append([_full(har[1], rng), "day", _pin(rng, used_pins), "day shift. Clocked out 18:04"])
	guards.append([_full(har[2], rng), "swing", _pin(rng, used_pins), "retired 1995. PIN revoked"])

	# Officer Pike: his name is clear on the sheet (marked NO SHOW). Players practice LIKE on him.
	var pike_pin := _pin(rng, used_pins)
	guards.append(["PIKE, H.", "night", pike_pin, "no-show since Tue 10/14. PIN suspended"])

	# Names with "har" in the middle. At least one works nights.
	var inside := HAR_INSIDE.duplicate()
	_shuffle(inside, rng)
	for i in inside.size():
		var shift: String = "night" if i < 2 else ["day", "swing"][rng.randi_range(0, 1)]
		guards.append([_full(inside[i], rng), shift, _pin(rng, used_pins), "didn't badge in tonight"])

	var shifts := ["day", "swing", "night"]
	var reasons := {
		"day": ["day shift", "day shift. Clocked out 18:00", "day shift. On vacation until 10/20"],
		"swing": ["swing shift. Clocked out 22:00", "swing shift", "swing shift. Off sick"],
		"night": ["night off", "on leave", "didn't badge in tonight"],
	}
	for n in OTHER_NAMES:
		var shift: String = shifts[rng.randi_range(0, 2)]
		var note: String = reasons[shift][rng.randi_range(0, 2)]
		guards.append([_full(n, rng), shift, _pin(rng, used_pins), note])

	_shuffle(guards, rng)
	# The policy shows 20 rows at most: Pike's and the night lead's rows come after
	# the first 20 as stored, so only a search finds them (v0.10 floor 22 package).
	# The lead goes past row 20, but among the first 20 night-shift rows, so
	# WHERE shift = 'night' and the notes are a route (layout and data).
	var lead_row = guards.filter(func(g): return g[0] == answer_name)[0]
	guards.erase(lead_row)
	var spots := []
	var nights := 0
	for i in guards.size() + 1:
		if i >= CAP_ROWS and nights < CAP_ROWS:
			spots.append(i)
		if i < guards.size() and guards[i][1] == "night":
			nights += 1
	guards.insert(spots[rng.randi_range(0, spots.size() - 1)], lead_row)
	# Then Pike, by a swap that never moves the lead.
	var pike_at := guards.find(guards.filter(func(g): return g[0] == "PIKE, H.")[0])
	if pike_at < CAP_ROWS:
		var to := rng.randi_range(CAP_ROWS, guards.size() - 1)
		while guards[to][0] == answer_name:
			to = rng.randi_range(CAP_ROWS, guards.size() - 1)
		var tmp = guards[pike_at]
		guards[pike_at] = guards[to]
		guards[to] = tmp
	# Which breaker tripped the stairwell door's actuator (the first terminal lie).
	var breaker := rng.randi_range(1, 4)
	var badge_of := {}  # name -> badge id
	for i in guards.size():
		badge_of[guards[i][0]] = "G-%03d" % (100 + i)
	# Guards' swipes through the stairwell door tonight. The readers log a guard's
	# badge number, not the name. The day and swing guards went out before the night
	# lead came in, so the last guard badge through SEC-EXIT is tonight's lead.
	var swipes := [["1997-10-15 18:04", badge_of[guards.filter(func(g): return g[3] == "day shift. Clocked out 18:04")[0][0]]]]
	var swing := guards.filter(func(g): return g[1] == "swing" and not str(g[3]).begins_with("retired"))
	for i in 2:
		var at: String = ["21:52", "21:57"][i]
		swing[i][3] = "swing shift. Clocked out " + at
		swipes.append(["1997-10-15 " + at, badge_of[swing[i][0]]])
	swipes.append(["1997-10-15 22:00", badge_of[answer_name]])
	# The briefing room's roster board: tonight's night shift, with badge numbers.
	var roster := [[answer_name, badge_of[answer_name], "LEAD"], ["PIKE, H.", badge_of["PIKE, H."], "NO SHOW"]]
	for g in guards:
		if g[1] == "night" and g[3] == "didn't badge in tonight" and roster.size() < 4:
			roster.append([g[0], badge_of[g[0]], "OFF"])
	var rows := []
	for i in guards.size():
		var g: Array = guards[i]
		rows.append("('%s', '%s', '%s', '%s', '%s')" % [badge_of[g[0]], g[0], g[1], g[2], str(g[3]).replace("'", "''")])

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

-- doors is building-wide (FacilityDB.SHARED_SCHEMA). This wing only adds SEC- rows.
INSERT INTO doors VALUES
	('SEC-OFFICE', 'Security Office', 'S', 1, 0),
	('SEC-EXIT', 'Security wing stairwell', 'S', 1, 1);

CREATE TABLE door_status (
	door_id TEXT,
	sensor TEXT,
	actuator TEXT,
	note TEXT
);
INSERT INTO door_status VALUES
	('SEC-OFFICE', 'closed', 'ok', 'lockdown: guard PIN required'),
	('SEC-EXIT', 'closed', 'fault', 'actuator breaker B-%d tripped 00:12. Reset it at the breaker box by the door');
""" % [",\n\t".join(rows), breaker]
	var lab := _lab(run_seed, swipes, _day_swipes(guards, badge_of, swing, rng))
	return {"sql": sql + lab.sql, "pin": answer_pin, "name": answer_name, "pike_pin": pike_pin, "breaker": breaker,
		"badge": badge_of[answer_name], "badge_time": "22:00", "decoy_badges": swipes.slice(0, 3).map(func(w): return w[1]),
		"roster": roster, "lab_zone": lab.zone, "lab_answer": lab.answer, "lab_switches": lab.switches}


## Secure Lab B: its door controllers and the badge log. A separate random stream,
## so the guard roster stays the same for a seed.
## The lab's zone changes per run, and its door is the one controller in that zone
## with status 'fault'. Another zone on this floor has a fault too, and the lab's
## zone has an offline and an ok one, so both WHERE conditions matter.
## In the whole building, door_controllers already holds floor 14's DC-1 to DC-15
## in zones A to F, so the lab's zones and ids are ones no other floor uses: the
## lab's query must find its one row whichever floors came first.
const LAB_ZONES := ["G", "H", "J", "K"]
const LAB_IDS_FROM := 21  # DC-21 to DC-26
const VISITOR_BADGES := 6


## The rest of the day at the floor's readers, before tonight: the day guards in
## through SEC-EXIT at the start of their shift and the swing guards at theirs,
## rounds at the office door, Vale at her lab, and Rourke in for the night. Every
## one is before the swing guards leave (21:52), so the only guard swipe after
## 21:57 is still the night lead's 22:00, and `ORDER BY time` doesn't reach
## tonight in 20 rows. [time, badge, holder, door].
static func _day_swipes(guards: Array, badge_of: Dictionary, swing: Array, rng: RandomNumberGenerator) -> Array:
	var out := []
	var day := guards.filter(func(g): return g[1] == "day" and not str(g[3]).contains("vacation"))
	for i in mini(4, day.size()):
		out.append(["1997-10-15 05:%02d" % (48 + i * 3), badge_of[day[i][0]], "SECURITY STAFF", "SEC-EXIT"])
		for h in [9, 12, 15]:
			if (i + h) % 2 == 0:
				out.append(["1997-10-15 %02d:%02d" % [h, rng.randi_range(0, 59)], badge_of[day[i][0]], "SECURITY STAFF", "SEC-OFFICE"])
	for i in mini(2, swing.size()):  # the two who badge out at 21:52 and 21:57
		out.append(["1997-10-15 13:%02d" % (50 + i * 4), badge_of[swing[i][0]], "SECURITY STAFF", "SEC-EXIT"])
		out.append(["1997-10-15 %02d:%02d" % [17 + i * 2, rng.randi_range(0, 59)], badge_of[swing[i][0]], "SECURITY STAFF", "SEC-OFFICE"])
	out.append(["1997-10-15 07:56", "V-0042", "VALE, I.", "SEC-EXIT"])
	out.append(["1997-10-15 08:03", "V-0042", "VALE, I.", "SECLAB-B"])
	out.append(["1997-10-15 13:12", "V-0042", "VALE, I.", "SECLAB-B"])
	out.append(["1997-10-15 19:40", "V-0042", "VALE, I.", "SECLAB-B"])
	out.append(["1997-10-15 21:20", "R-0117", "ROURKE, D.", "SEC-EXIT"])
	out.append(["1997-10-15 21:24", "R-0117", "ROURKE, D.", "NIGHT DESK"])
	return out


## `guard_swipes` are [time, badge] pairs through SEC-EXIT; the last is the night lead's.
## `day` is the rest of the day's swipes (_day_swipes), stored in among tonight's.
static func _lab(run_seed: int, guard_swipes: Array, day: Array = []) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 7919 + 2
	var zone: String = LAB_ZONES[rng.randi_range(0, LAB_ZONES.size() - 1)]
	var c := _lab_controllers(zone, rng)
	var rows: Array = c.rows
	# Who badged where tonight, in the order the reader stored them (not by time).
	# Vale's 23:12 swipe is the same minute as the server floor's syslog line.
	var log := [
		["1997-10-15 23:12", "V-0042", "VALE, I.", "SECLAB-B"],
		["1997-10-15 23:40", "R-0117", "ROURKE, D.", "SECLAB-B-REAR"],
		["1997-10-15 23:55", "R-0117", "ROURKE, D.", "NIGHT DESK"],
		["1997-10-15 21:58", "V-0042", "VALE, I.", "NIGHT DESK"],
	]
	for w in guard_swipes:
		log.append([w[0], w[1], "SECURITY STAFF", "SEC-EXIT"])
	log.append_array(day)
	_shuffle(log, rng)
	# Stored out of time order, and the last SEC-EXIT row stored isn't the latest,
	# so reading the table as it comes gives the wrong guard. ORDER BY time doesn't.
	var lead: Array = log.filter(func(r): return r[1] == guard_swipes[-1][1])[0]
	var exits := log.filter(func(r): return r[3] == "SEC-EXIT")
	if exits[-1] == lead:
		var a := log.find(lead)
		var b := log.find(exits[0])
		log[a] = exits[0]
		log[b] = lead
	var sorted_log := log.duplicate()
	sorted_log.sort()
	if log == sorted_log:
		log.reverse()
	log = log.map(func(r): return "('%s', '%s', '%s', '%s')" % r)
	var visitors := []
	for i in range(1, VISITOR_BADGES + 1):
		visitors.append("('VIS-%02d', 'BYTE-RIGHT IT (VISITOR)', 'VISITOR', 'Front desk')" % i)
	var sql := """

-- Secure Lab B. door_controllers is the server floor's table; on its own this wing makes it.
CREATE TABLE IF NOT EXISTS door_controllers (
	id TEXT,
	zone TEXT,
	status TEXT,
	location TEXT,
	last_reset TEXT,
	note TEXT
);
INSERT INTO door_controllers VALUES
	%s;

-- The badge readers' log: every swipe, at every reader on this floor.
CREATE TABLE badge_log (
	time TEXT,
	badge_id TEXT,
	holder TEXT,
	door TEXT
);
INSERT INTO badge_log VALUES
	%s;

INSERT OR IGNORE INTO badges VALUES
	%s;

INSERT INTO doors VALUES
	('SECLAB-B', 'Secure Lab B', '%s', 1, 0),
	('SECLAB-B-REAR', 'Secure Lab B rear door', '%s', 1, 0);
INSERT INTO door_status VALUES
	('SECLAB-B', 'closed', 'ok', 'badge door: staff badge or escort'),
	('SECLAB-B-REAR', 'closed', 'ok', 'staff only');
""" % [",\n\t".join(rows), ",\n\t".join(log), ",\n\t".join(visitors), zone, zone]
	return {"sql": sql, "zone": zone, "answer": c.answer, "switches": c.switches}


## Caught by the security response, the crew wakes up locked in again, and the lab's
## controllers have been re-keyed to another zone. `attempt` counts from 1.
static func lab_rekey(run_seed: int, attempt: int, old_zone: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 7919 + 2 + attempt * 104729
	var zones := LAB_ZONES.filter(func(z): return z != old_zone)
	var zone: String = zones[rng.randi_range(0, zones.size() - 1)]
	var c := _lab_controllers(zone, rng)
	var sql := """
DELETE FROM door_controllers WHERE id IN (%s);
INSERT INTO door_controllers VALUES
	%s;
UPDATE doors SET zone = '%s' WHERE id IN ('SECLAB-B', 'SECLAB-B-REAR');
""" % [", ".join(c.ids.map(func(i): return "'%s'" % i)), ",\n\t".join(c.rows), zone]
	return {"sql": sql, "zone": zone, "answer": c.answer, "switches": c.switches}


## The six controllers DC-21 to DC-26: three in the lab's zone, three in zone S.
static func _lab_controllers(zone: String, rng: RandomNumberGenerator) -> Dictionary:
	var ids := []
	for i in range(LAB_IDS_FROM, LAB_IDS_FROM + 6):
		ids.append("DC-%d" % i)
	_shuffle(ids, rng)
	# [zone, status, location, note]
	var specs := [
		[zone, "fault", "Secure Lab B, main door", "lockdown relay latched. Needs a manual reset."],
		[zone, "offline", "Secure Lab B, fume hood", "off on purpose: hood serviced 10/13"],
		[zone, "ok", "Secure Lab B, rear door", "normal"],
		["S", "fault", "Interview room door", "runs the interview room, not the lab. Ticket open"],
		["S", "ok", "Briefing room door", "normal"],
		["S", "offline", "Camera room door", "decommissioned 1996"],
	]
	var rows := []
	var switches := []
	for i in specs.size():
		var c: Array = specs[i]
		var reset_at := "1997-10-%02d %02d:%02d" % [rng.randi_range(1, 14), rng.randi_range(0, 23), rng.randi_range(0, 59)]
		rows.append("('%s', '%s', '%s', '%s', '%s', '%s')" % [ids[i], c[0], c[1], c[2], reset_at, c[3]])
		if c[0] == zone:
			switches.append(ids[i])
	switches.sort()
	return {"rows": rows, "ids": ids, "answer": ids[0], "switches": switches}


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
