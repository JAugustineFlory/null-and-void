class_name Level3Data
extends RefCounted
## Builds Level 3's database from a seed: the Records Archive on floor 18.
## Three tables, each with a visible source in the world:
##   access_log      the badge readers beside every room door (time, badge, holder, room)
##   catalogue       the archive's box records: the labels on the shelves, the card drawers
##   retrieval_slips the paper slips on the records desk's spike
## The puzzles that read them are on HOLD (plan/level-3-records-archive.md): the
## checks can change, so this builds the data any skill could read.
##
## What stays the same every run: one side room on 18 was visited far more than any
## other that night (10/15), and Mercer's safe room is behind it. By day the reading
## room is the busiest room in the archive, so a count over the whole log points at
## the wrong room: the night matters. Which side room it is changes with the seed.

## The side rooms that could hide the safe room, as the readers log them.
const CANDIDATES := ["VAULT C", "MAP ROOM", "COLD STORE"]
## Every reader on the floor.
const ROOMS := ["READING ROOM", "STACKS", "MICROFICHE", "SHRED ROOM", "SUPPLY", "VAULT C", "MAP ROOM", "COLD STORE"]
## The night of the job.
const NIGHT := "1997-10-15"
## Who kept going into that room that night. The holder is a placeholder until
## Augustine says whose visits they are; the badge number changes with the seed,
## and its last four digits are the code of the push-button lock on Mercer's door
## (facilities policy: a lock's code is its keyholder's badge number).
const VISITOR := "RECORDS CLERK (NIGHT)"
## The night patrol: every room once or twice.
const PATROL := ["G-0127", "SECURITY STAFF"]
## Day staff who pull boxes: lots of reading room rows, by day.
const DAY_BADGES := [["A-0291", "ARCHIVIST"], ["A-0302", "RECORDS CLERK"], ["A-0288", "RECORDS CLERK"], ["L-0044", "LEGAL"], ["F-0107", "FINANCE"]]
const DEPARTMENTS := ["LEGAL", "FINANCE", "FACILITIES", "RESEARCH", "PERSONNEL", "SECURITY"]
const TITLES := ["Correspondence", "Invoices", "Contracts", "Lab notebooks", "Site drawings", "Personnel files", "Vendor files", "Minutes", "Incident reports", "Payroll"]


static func build(run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 6007 + 3
	var host: String = CANDIDATES[rng.randi_range(0, CANDIDATES.size() - 1)]
	# Four digits from 1000 up, so it never reads like a day badge (A-02xx, A-03xx).
	var code := "%04d" % rng.randi_range(1000, 9999)
	var visitor_badge := "A-" + code

	# That night: the host room gets the most visits by a clear margin; every other
	# room a different, smaller count, so there are no ties in the order.
	var night_counts := {}
	var others := ROOMS.filter(func(r): return r != host)
	_shuffle(others, rng)
	for i in others.size():
		night_counts[others[i]] = 1 + i  # 1..7
	night_counts[host] = 8 + others.size() + rng.randi_range(2, 5)  # 17..20
	var log := []  # [time, badge, holder, room]
	var minute := 19 * 60 + 30
	var night_rows := []
	for room in ROOMS:
		for n in night_counts[room]:
			var who := [visitor_badge, VISITOR] if room == host or rng.randf() < 0.5 else PATROL
			night_rows.append([who[0], who[1], room])
	_shuffle(night_rows, rng)
	for r in night_rows:
		minute += rng.randi_range(3, 12)
		log.append(["%s %02d:%02d" % [NIGHT, (minute / 60) % 24, minute % 60], r[0], r[1], r[2]])
	# Earlier that week, by day: the reading room is where everyone goes, so over the
	# whole log it beats the host room. Other rooms get a few day visits too. Nothing
	# by day on the 15th: the date alone picks out that night's rows.
	var day_total := 0
	for day in ["1997-10-13", "1997-10-14"]:
		var t := 8 * 60 + 40
		var visits := rng.randi_range(9, 12)
		for n in visits:
			t += rng.randi_range(8, 40)
			if t > 17 * 60 + 30:
				break
			var who: Array = DAY_BADGES[rng.randi_range(0, DAY_BADGES.size() - 1)]
			var room := "READING ROOM"
			if rng.randf() < 0.3:
				room = ["STACKS", "MICROFICHE", "SHRED ROOM", "SUPPLY"][rng.randi_range(0, 3)]
			else:
				day_total += 1
			log.append(["%s %02d:%02d" % [day, t / 60, t % 60], who[0], who[1], room])
	# The reading room must win over the whole log, or the decoy teaches nothing.
	while day_total <= night_counts[host] + night_counts["READING ROOM"]:
		log.append(["1997-10-14 %02d:%02d" % [rng.randi_range(9, 16), rng.randi_range(0, 59)], DAY_BADGES[0][0], DAY_BADGES[0][1], "READING ROOM"])
		day_total += 1
	# Stored in the order the readers reported in, not by time.
	_shuffle(log, rng)

	# The catalogue: boxes on 18, by aisle and shelf. Mercer's own boxes are in the
	# host room; the rest are spread over the stacks. Departments repeat, so a list of
	# them has duplicates to collapse.
	var boxes := []  # [box_id, title, dept, room, aisle, shelf, status, note]
	var used_ids := {}
	for i in 36:
		var dept: String = DEPARTMENTS[rng.randi_range(0, DEPARTMENTS.size() - 1)]
		var aisle := rng.randi_range(1, 5)
		var shelf := rng.randi_range(1, 6)
		var status := "on shelf"
		var note := ""
		if rng.randf() < 0.08:
			status = "destroyed"
			note = "shredded per retention schedule"
		boxes.append([_box_id(rng, used_ids, 1990 + rng.randi_range(0, 7)), "%s %d" % [TITLES[rng.randi_range(0, TITLES.size() - 1)], 1990 + rng.randi_range(0, 7)], dept, "STACKS", "A%d" % aisle, str(shelf), status, note])
	for i in 3:
		boxes.append([_box_id(rng, used_ids, 1994), ["Founder's papers", "Site drawings 1988", "Correspondence 1994"][i], "EXECUTIVE", host, "R1", str(i + 1), "on shelf", "restricted. Do not pull without the archivist"])
	for c in CANDIDATES:
		if c == host:
			continue
		for i in 2:
			boxes.append([_box_id(rng, used_ids, 1991 + i), "%s %d" % [TITLES[rng.randi_range(0, TITLES.size() - 1)], 1991 + i], DEPARTMENTS[rng.randi_range(0, DEPARTMENTS.size() - 1)], c, "R1", str(i + 1), "on shelf", ""])
	_shuffle(boxes, rng)

	# Retrieval slips: paper requests the desk works through. A few are still open
	# (nothing pulled yet). Of the filled ones, most boxes came back and the clerk
	# wrote the time; one or two never did, so returned_at is NULL: an empty cell,
	# not '' and not 0. Those boxes are 'out' in the catalogue.
	var slips := []  # [slip_no, box_id, requested_by, status, returned_at, note]
	var open_slips := rng.randi_range(3, 5)
	var unreturned_n := rng.randi_range(1, 2)
	var unreturned := []
	var slip_boxes := boxes.filter(func(b): return b[3] == "STACKS" and b[6] != "destroyed").duplicate()
	_shuffle(slip_boxes, rng)
	for i in 9:
		var b: Array = slip_boxes[i]
		var status := "open" if i < open_slips else "filled"
		var note := "" if status == "filled" else "waiting on the night clerk"
		var returned_at = null
		if status == "filled":
			if i < open_slips + unreturned_n:
				b[6] = "out"
				b[7] = "pulled to the reading room"
				unreturned.append(b[0])
			else:
				returned_at = "1997-10-%02d %02d:%02d" % [rng.randi_range(13, 14), rng.randi_range(9, 16), rng.randi_range(0, 59)]
		slips.append(["S-%04d" % (2200 + i * 3 + rng.randi_range(0, 2)), b[0], DAY_BADGES[rng.randi_range(0, DAY_BADGES.size() - 1)][1], status, returned_at, note])
	_shuffle(slips, rng)

	var sql := """
-- The badge readers beside every room door on 18, as they reported in.
CREATE TABLE access_log (
	time TEXT,
	badge_id TEXT,
	holder TEXT,
	room TEXT
);
INSERT INTO access_log VALUES
	%s;

-- The archive catalogue: one row per box, as the labels on the shelves read.
CREATE TABLE catalogue (
	box_id TEXT,
	title TEXT,
	dept TEXT,
	room TEXT,
	aisle TEXT,
	shelf TEXT,
	status TEXT,
	note TEXT
);
INSERT INTO catalogue VALUES
	%s;

-- The paper slips on the records desk's spike.
CREATE TABLE retrieval_slips (
	slip_no TEXT,
	box_id TEXT,
	requested_by TEXT,
	status TEXT,
	returned_at TEXT,
	note TEXT
);
INSERT INTO retrieval_slips VALUES
	%s;

-- doors and lights are building-wide (FacilityDB.SHARED_SCHEMA). This wing adds floor 18's rows.
INSERT INTO doors VALUES
	('ARC-VAULT-C', 'Records Archive, Vault C', 'A', 0, 0),
	('ARC-MAP', 'Records Archive, map room', 'A', 0, 0),
	('ARC-COLD', 'Records Archive, cold store', 'A', 0, 0),
	('ARC-SUPPLY', 'Records Archive, supply closet', 'A', 0, 0),
	('ARC-SHRED', 'Records Archive, shredding room', 'A', 0, 0),
	('ARC-FICHE', 'Records Archive, microfiche room', 'A', 0, 0);
INSERT INTO lights VALUES
	('L18-LOBBY', 'Lift lobby', 18, 1, 'ok'),
	('L18-DESK', 'Records desk', 18, 1, 'ok'),
	('L18-READ', 'Reading room', 18, 1, 'ok'),
	('L18-STACKS', 'Stacks', 18, 0, 'occupancy sensor: no motion after 19:00'),
	('L18-HALL-W', 'West hall', 18, 1, 'ok'),
	('L18-HALL-E', 'East hall', 18, 1, 'ok'),
	('L18-NORTH', 'North corridor', 18, 1, 'ok'),
	('L18-SHRED', 'Shredding room', 18, 1, 'ok'),
	('L18-FICHE', 'Microfiche room', 18, 0, 'tube out. Ticket open since 10/09'),
	('L18-VAULT-C', 'Vault C', 18, 1, 'ok'),
	('L18-MAP', 'Map room', 18, 1, 'ok'),
	('L18-COLD', 'Cold store', 18, 1, 'ok');
""" % [
		",\n\t".join(log.map(_values)),
		",\n\t".join(boxes.map(_values)),
		",\n\t".join(slips.map(_values)),
	]
	var open_list := slips.filter(func(s): return s[3] == "open")
	return {"sql": sql, "host": host, "night_counts": night_counts, "open_slips": open_list.size(),
		"visitor_badge": visitor_badge, "code": code, "unreturned": unreturned,
		"mercer_boxes": boxes.filter(func(b): return b[3] == host).map(func(b): return b[0])}


## One row's values, quoted for SQL ("Founder's papers" needs its quote doubled).
## A null stays a real NULL, so IS NULL finds it and = '' doesn't.
static func _values(row: Array) -> String:
	return "(%s)" % ", ".join(row.map(func(v): return "NULL" if v == null else "'%s'" % str(v).replace("'", "''")))


static func _box_id(rng: RandomNumberGenerator, used: Dictionary, year: int) -> String:
	while true:
		var id := "B-%d-%03d" % [year % 100, rng.randi_range(1, 999)]
		if not used.has(id):
			used[id] = true
			return id
	return ""


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
