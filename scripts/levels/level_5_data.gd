class_name Level5Data
extends RefCounted
## Builds Level 5's data from a seed: the Personnel Wing on floor 9 (payroll and HR).
## Floor 9's records live on the building's services, not in its tables: HR's staff
## records and the badge readers' log answer to the HR service (a key opens it), and
## the floor's panel and work orders answer to the Facilities service. The doors and
## lights are rows in the building-wide tables, as on every floor.
##
## What stays the same every run: Epsilon shed the floor's load, so payroll is dark,
## the air handler is off and the records cage's lock has no power. The HR manager's
## key opens the services; the temp's key opens only the mail room. Two night-shift
## staffers are hiding, one in the records cage and one in the payroll store (which
## is which changes with the seed), and two Mimics wear their faces with somebody
## else's badge on the lanyard. Vale's record says deceased, and was edited after.

## The crew's company, as printed on its work order.
const COMPANY := "Byte-Right IT Services"
## The HR service's key holder, the temp, the two night-shifters, and the two badges
## the Mimics wear (each with its own reason not to answer a reader).
const MANAGER := {"name": "Okonjo, Beatrice", "dept": "Personnel", "role": "HR manager", "shift": "day"}
const TEMP := {"name": "Fisk, Danny", "dept": "Personnel", "role": "Temp (mail room)", "shift": "day"}
const NIGHT := [
	{"name": "Oyelaran, Nadia", "first": "Nadia", "dept": "Records", "role": "Records clerk", "shift": "night", "line": "l5_nadia_passed"},
	{"name": "Reyes, Tomas", "first": "Tomas", "dept": "Payroll", "role": "Payroll clerk", "shift": "night", "line": "l5_tomas_passed"},
]
## The two hiding places, with the reader each one badges in at and the door that
## shuts it: the Mimics borrow the faces, the badge log tells them apart.
const HIDES := [
	{"id": "cage", "reader": "PERS-CAGE", "door": "PERS-CAGE", "place": "the records cage"},
	{"id": "store", "reader": "PERS-STORE", "door": "PERS-STORE", "place": "the payroll store"},
]
const LOST := [
	{"id": "ST-0416", "name": "Patel, Rina", "dept": "Payroll", "role": "Payroll clerk", "shift": "day", "status": "on leave", "note": "Badge reported lost 10/13. Reader access revoked."},
	{"id": "ST-0590", "name": "Hale, Jonah", "dept": "Records", "role": "Records clerk", "shift": "day", "status": "left 09/30", "note": "Badge not returned. Reader access revoked."},
]
const DAY := {"id": "ST-0233", "name": "Lindqvist, Erik", "dept": "Payroll", "role": "Payroll supervisor", "shift": "day"}
## Vale's record: deceased, and edited the night after by an account on floor 30.
const VALE := {"id": "ST-0077", "name": "Vale, Iris", "dept": "Engineering", "role": "Lead engineer", "shift": "day",
	"status": "deceased", "note": "Deceased 10/14/97.", "last_edited": "10/15/97 02:14", "edited_by": "EXEC-30"}
## The air handler the floor's clipboard names, and the carbon copy's (floor 14's).
const AHU := "AHU-9"
const EXAMPLE_ORDER := {"floor": 14, "unit": "AHU-14", "fault": "belt squeal"}
## The panel's night limit, in amps.
const LIMIT := 40
## Every circuit on panel 9: [id, circuit, amps, on, note]. The copier bank is the
## heavy thing left on; the lights and the cage lock were shed; the two that stay off
## say why. The amps vary a little with the seed (below), the shape never does.
const CIRCUITS := [
	["C9-01", "PAYROLL LIGHTS", 12, false, "Shed 23:40 under Epsilon."],
	["C9-02", "HR LIGHTS", 6, true, ""],
	["C9-03", "COPIER BANK", 20, true, "Left on. Payroll's three copiers."],
	["C9-04", "RECORDS CAGE LOCK", 2, false, "Shed 23:40 under Epsilon. The cage door holds shut without it."],
	["C9-05", "VENDING", 6, true, ""],
	["C9-06", "AHU-9 FANS", 15, false, "Night interlock. AHU-9 restarts on a logged work order, not from the panel."],
	["C9-07", "SERVER CLOSET 9", 10, false, "LOCKED OUT by IT 10/13. Do not energize."],
	["C9-08", "EMERGENCY LIGHTS", 3, true, ""],
]
## The floor's clock reads 00:MM when the crew arrives.
const CLOCK_HOUR := 0


static func build(run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 7919 + 5
	# Badge numbers, dealt out so a walkthrough's can't be copied.
	var badge_ids := []
	while badge_ids.size() < 5:
		var id := "ST-%04d" % rng.randi_range(100, 999)
		if not badge_ids.has(id) and not ["ST-0416", "ST-0590", "ST-0233", "ST-0077"].has(id):
			badge_ids.append(id)
	var hides: Array = HIDES.duplicate(true)
	if rng.randi() % 2 == 0:
		hides.reverse()  # Nadia in the store, Tomas in the cage
	var staff := []
	var manager := MANAGER.duplicate()
	manager["id"] = badge_ids[0]
	manager["status"] = "off site"
	manager["note"] = "Left 18:30."
	staff.append(manager)
	var temp := TEMP.duplicate()
	temp["id"] = badge_ids[1]
	temp["status"] = "off site"
	temp["note"] = "Left 17:02. Temp key: mail room only."
	staff.append(temp)
	var night := []
	for i in NIGHT.size():
		var s: Dictionary = NIGHT[i].duplicate()
		s["id"] = badge_ids[2 + i]
		s["status"] = "on floor"
		s["note"] = "Night shift 22:00-06:00."
		s["hide"] = hides[i]
		staff.append(s)
		night.append(s)
	var day := DAY.duplicate()
	day["status"] = "off site"
	day["note"] = "Left 17:58."
	staff.append(day)
	for l in LOST:
		staff.append(l.duplicate())
	staff.append(VALE.duplicate())
	staff.sort_custom(func(a, b): return a.id < b.id)

	# The services' keys: the manager's opens HR, Facilities and the doors; the temp's
	# opens the mail room and nothing here.
	var keys := {"hr": _key(rng), "temp": _key(rng)}
	# The panel: the copier bank's load and the lights' vary so the sum has to be read,
	# but the copiers always have to go off for the lights to fit under the limit.
	var circuits: Array = CIRCUITS.duplicate(true)
	circuits[0][2] = rng.randi_range(10, 14)  # payroll lights
	circuits[2][2] = rng.randi_range(18, 22)  # copier bank
	var minute := rng.randi_range(31, 52)
	var clock := "%02d:%02d" % [CLOCK_HOUR, minute]
	# The badge readers' log so far tonight: the day staff out, the night staff in,
	# and each night-shifter badged into their hiding place within the last hour.
	var swipes := []
	swipes.append({"badge": temp.id, "reader": "G-LOBBY", "dir": "OUT", "time": "17:02"})
	swipes.append({"badge": day.id, "reader": "G-LOBBY", "dir": "OUT", "time": "17:58"})
	swipes.append({"badge": manager.id, "reader": "G-LOBBY", "dir": "OUT", "time": "18:30"})
	swipes.append({"badge": night[0].id, "reader": "PERS-FRONT", "dir": "IN", "time": "22:0%d" % rng.randi_range(1, 9)})
	swipes.append({"badge": night[1].id, "reader": "PERS-FRONT", "dir": "IN", "time": "22:1%d" % rng.randi_range(0, 9)})
	for s in night:
		swipes.append({"badge": s.id, "reader": s.hide.reader, "dir": "IN", "time": "23:%02d" % rng.randi_range(41, 58)})
	# Floor 9's doors and lights in the building-wide tables. The cage's lock has no
	# power until its circuit is back (actuator_fault): the table says locked, and a
	# PATCH to open it is refused until then.
	var sql := """
INSERT INTO doors VALUES
	('PERS-CAGE', 'Personnel 9, records cage', '9', 1, 1),
	('PERS-STORE', 'Personnel 9, payroll store', '9', 1, 0),
	('PERS-DOCK', 'Personnel 9, loading door (dock stairs)', '9', 1, 0);
INSERT INTO lights VALUES
	('L9-LOBBY', 'Lift lobby', 9, 1, 'ok'),
	('L9-HR', 'HR front', 9, 1, 'ok'),
	('L9-OFFICE', 'HR manager', 9, 1, 'ok'),
	('L9-PAY', 'Payroll', 9, 0, 'shed'),
	('L9-CAGE', 'Records cage', 9, 0, 'shed'),
	('L9-STORE', 'Payroll store', 9, 0, 'shed');
"""
	return {"sql": sql, "staff": staff, "night": night, "manager": manager, "temp": temp, "day": day, "keys": keys,
		"circuits": circuits, "limit": LIMIT, "swipes": swipes, "clock": clock, "minute": minute,
		"example_order": EXAMPLE_ORDER, "ahu": AHU, "company": COMPANY,
		"example_key_id": _example_key_id(rng)}


## A service key: two groups of four hex characters, like the ones on the desk sheet.
static func _key(rng: RandomNumberGenerator) -> String:
	var hex := "0123456789abcdef"
	var out := ""
	for i in 8:
		if i == 4:
			out += "-"
		out += hex[rng.randi_range(0, 15)]
	return out


## The staff id the desk sheet's example request asks for: another floor's clerk,
## never one of tonight's people.
static func _example_key_id(rng: RandomNumberGenerator) -> String:
	return "ST-1%03d" % rng.randi_range(100, 999)


## A staff record as the HR service answers it. Vale's carries its edit history;
## the others don't (nobody has touched them).
static func staff_json(s: Dictionary) -> Dictionary:
	var out := {"id": s.id, "name": s.name, "dept": s.dept, "role": s.role, "shift": s.shift, "status": s.status, "note": s.get("note", "")}
	if s.has("last_edited"):
		out["last_edited"] = s.last_edited
		out["edited_by"] = s.edited_by
	return out
