class_name Level6Data
extends RefCounted
## Builds Level 6's data from a seed: B1, the sample and records cold store ("The Ones
## Who Never Left"). Act 2's third floor.
##
## The cold store's lone-worker time clock punches a card IN at every vault door and
## OUT again on the way back, "so nobody is left inside". Its log is the table
## `freezer_log`: one row per visit, clock_out NULL while someone is still in. Over
## Halcyon's years some entries never closed. The people on those cards are still at
## their rows, as echoes: six a run, from a pool of nine (Augustine's call 3b).
##
## The card rack and the IN/OUT whiteboard in the office disagree with the log: the
## supervisor fixed missed punches in the log and never in the rack ("the rack is not
## the record"), a few cards slipped behind it, and the whiteboard is years stale.
##
## The floor's services (one key, the IT tech's): the earpiece cradle in the IT cage,
## the doors, and the time clock. Its punches only go through on the vaults' own
## wireless network; the wired terminals get 403 for them.

## The crew's company, as the visitor cards print it.
const COMPANY := "Byte-Right IT Services"
## Halcyon opened the cold store in 1978.
const OPENED := 1978

## The pool of nine (Augustine 2026-11-05, call 3b): each has a vault and row, a role,
## the year their entry opened, their three lines (the loop they whisper at their row,
## their story as the punch prints, and their last words), and what they leave behind:
## a memory or a piece of evidence. Names, roles and lines are DRAFTS for Voice and
## Augustine (plan/approvals/l6-text.md). WHITLOW is in every run: the night-shifter
## from 9 recognises her initials (call 5b).
const POOL := [
	{"id": "whitlow", "name": "Whitlow, Agnes", "first": "Agnes", "role": "Records clerk", "vault": "B", "row": "B-2",
		"years": [1982, 1984], "leaves": "memory"},
	{"id": "delacroix", "name": "Delacroix, Frank", "first": "Frank", "role": "Goods-in porter", "vault": "A", "row": "A-1",
		"years": [1978, 1981], "leaves": "memory"},
	{"id": "cole", "name": "Cole, Mary-Beth", "first": "Mary-Beth", "role": "Lab technician", "vault": "A", "row": "A-3",
		"years": [1986, 1989], "leaves": "evidence"},
	{"id": "mensah", "name": "Mensah, Osei", "first": "Osei", "role": "Night security", "vault": "C", "row": "C-1",
		"years": [1989, 1992], "leaves": "evidence"},
	{"id": "abernathy", "name": "Abernathy, Ruth", "first": "Ruth", "role": "Film archivist", "vault": "B", "row": "B-4",
		"years": [1983, 1986], "leaves": "memory"},
	{"id": "tolliver", "name": "Tolliver, Gene", "first": "Gene", "role": "Refrigeration engineer", "vault": "C", "row": "C-3",
		"years": [1992, 1995], "leaves": "evidence"},
	{"id": "sorokina", "name": "Sorokina, Lena", "first": "Lena", "role": "Sample courier", "vault": "A", "row": "A-2",
		"years": [1988, 1991], "leaves": "memory"},
	{"id": "fenner", "name": "Fenner, Paul", "first": "Paul", "role": "Temp records clerk", "vault": "B", "row": "B-1",
		"years": [1994, 1996], "leaves": "evidence"},
	{"id": "haddad", "name": "Haddad, Yusuf", "first": "Yusuf", "role": "Deep-freeze technician", "vault": "C", "row": "C-2",
		"years": [1985, 1988], "leaves": "memory"},
]
## Always in the six: the name a night-shifter knows.
const ALWAYS := "whitlow"
const PER_RUN := 6
const VAULTS := {"A": "Vault A (samples)", "B": "Vault B (records and film)", "C": "Vault C (deep freeze)"}
## Ordinary staff whose visits closed properly: the log's long tail.
const STAFF := ["Kowal, Dee", "Marsh, Albert", "Quint, Nora", "Bellweather, Sy", "Kaminski, Joan", "Ibe, Chidi",
	"Varga, Ilona", "Pruitt, Lyle", "Szabo, Edit", "Nakamura, Ken", "Achebe, Femi", "Lowry, Beth"]
## The two cards the supervisor fixed in the log but left IN on the rack.
const FIXED_NOTE := "missed punch, closed by supervisor"


static func build(run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 6007 + 11
	# Who's here tonight: Whitlow, and five more of the eight, in a seeded order.
	var rest: Array = POOL.filter(func(e): return e.id != ALWAYS)
	_shuffle(rest, rng)
	var picked: Array = [POOL.filter(func(e): return e.id == ALWAYS)[0]] + rest.slice(0, PER_RUN - 1)
	_shuffle(picked, rng)
	var used_cards := {}
	var echoes := []
	for e in picked:
		var echo: Dictionary = e.duplicate(true)
		echo["card"] = _card(rng, used_cards)
		echo["year"] = rng.randi_range(e.years[0], e.years[1])
		echo["clock_in"] = "%d-%02d-%02d %02d:%02d" % [echo.year, rng.randi_range(1, 12), rng.randi_range(1, 28), rng.randi_range(0, 5), rng.randi_range(0, 59)]
		echoes.append(echo)
	echoes.sort_custom(func(a, b): return a.clock_in < b.clock_in)

	# The log: closed visits across the years, the echoes' open ones among them, the
	# two missed punches the supervisor closed, and last week's visits.
	var log := []
	for i in 34:
		var y := rng.randi_range(OPENED, 1996)
		var m := rng.randi_range(1, 12)
		var d := rng.randi_range(1, 28)
		var h := rng.randi_range(6, 21)
		var mi := rng.randi_range(0, 49)
		log.append({"card": _card(rng, used_cards), "name": STAFF[rng.randi_range(0, STAFF.size() - 1)], "vault": ["A", "B", "C"][rng.randi_range(0, 2)],
			"clock_in": "%d-%02d-%02d %02d:%02d" % [y, m, d, h, mi], "clock_out": "%d-%02d-%02d %02d:%02d" % [y, m, d, h, mi + rng.randi_range(3, 10)], "note": ""})
	for e in echoes:
		log.append({"card": e.card, "name": e.name, "vault": e.vault, "clock_in": e.clock_in, "clock_out": null, "note": ""})
	var fixed := []
	for i in 2:
		var y := rng.randi_range(1990, 1996)
		var stamp := "%d-%02d-%02d %02d:%02d" % [y, rng.randi_range(1, 12), rng.randi_range(1, 28), rng.randi_range(7, 18), rng.randi_range(0, 49)]
		var row := {"card": _card(rng, used_cards), "name": STAFF[(i * 5 + rng.randi_range(0, 3)) % STAFF.size()], "vault": ["A", "B"][i],
			"clock_in": stamp, "clock_out": stamp.left(14) + "59", "note": FIXED_NOTE}
		log.append(row)
		fixed.append(row)
	for i in 3:
		var day := rng.randi_range(6, 13)
		var h := rng.randi_range(8, 16)
		log.append({"card": _card(rng, used_cards), "name": STAFF[rng.randi_range(0, STAFF.size() - 1)], "vault": ["A", "B", "C"][i],
			"clock_in": "1997-10-%02d %02d:1%d" % [day, h, i], "clock_out": "1997-10-%02d %02d:2%d" % [day, h, i], "note": ""})
	log.sort_custom(func(a, b): return a.clock_in < b.clock_in)
	for i in log.size():
		log[i]["id"] = 101 + i
	for e in echoes:
		e["entry"] = log.filter(func(r): return r.card == e.card)[0].id

	# The rack in the office: the echoes' cards in the IN slots, except the one that
	# slipped down behind it, and the two fixed cards still IN. Counting it is wrong:
	# it always shows one more card than the log has open.
	var behind := [echoes[rng.randi_range(0, echoes.size() - 1)].card]
	var rack_in := []
	for e in echoes:
		if not behind.has(e.card):
			rack_in.append({"card": e.card, "name": e.name})
	for f in fixed:
		rack_in.append({"card": f.card, "name": f.name})
	_shuffle(rack_in, rng)

	var key := _key(rng)
	var dock_key := _key(rng)
	# The door ids, seeded so a walkthrough's can't be copied.
	var n := rng.randi_range(10, 89)
	var doors := {"ante": "CS-%02d" % n, "vault_c": "CS-%02d" % (n + 3), "it": "CS-%02d" % (n + 5), "office": "CS-%02d" % (n + 6)}
	var sql := _sql(log, doors)
	return {
		"sql": sql, "echoes": echoes, "log": log, "fixed": fixed, "rack_in": rack_in, "behind": behind,
		"key": key, "dock_key": dock_key, "doors": doors,
		# Epsilon's sweep re-locks the floor's ordinary doors every few seconds; the deep
		# freeze's door latches on its safety timer; the time clock prints a release slip
		# and takes this long before the next punch (about one story).
		"sweep": float(rng.randi_range(6, 10)),
		"freezer_timer": float(rng.randi_range(6, 10)),
		"punch_interval": float(rng.randi_range(15, 25)),
		"clock": "%02d:%02d" % [1, rng.randi_range(5, 25)],
		"company": COMPANY,
	}


## The floor's rows in the building's tables (doors and lights), and its own table:
## the time clock's log.
static func _sql(log: Array, doors: Dictionary) -> String:
	var rows := PackedStringArray()
	for r in log:
		rows.append("\t(%d, '%s', '%s', '%s', '%s', %s, '%s')" % [r.id, r.card, r.name.replace("'", "''"), r.vault, r.clock_in,
			"NULL" if r.clock_out == null else "'%s'" % r.clock_out, r.note])
	return """
CREATE TABLE freezer_log (
	id INTEGER PRIMARY KEY,
	card TEXT,
	name TEXT,
	vault TEXT,
	clock_in TEXT,
	clock_out TEXT,
	note TEXT
);
INSERT INTO freezer_log VALUES
%s;
INSERT INTO doors VALUES
	('%s', 'Cold store B1, anteroom door', 'B1', 1, 0),
	('%s', 'Cold store B1, Vault C (deep freeze)', 'B1', 1, 0),
	('%s', 'Cold store B1, IT cage', 'B1', 0, 0),
	('%s', 'Cold store B1, time office', 'B1', 0, 0);
INSERT INTO lights VALUES
	('LB1-LANDING', 'Stair landing', -1, 1, 'ok'),
	('LB1-OFFICE', 'Time office', -1, 1, 'ok'),
	('LB1-IT', 'IT cage', -1, 1, 'ok'),
	('LB1-GOODS', 'Goods-in', -1, 1, 'ok'),
	('LB1-CORRIDOR', 'Vault corridor', -1, 1, 'cold'),
	('LB1-A', 'Vault A', -1, 1, 'cold'),
	('LB1-B', 'Vault B', -1, 1, 'cold'),
	('LB1-C', 'Vault C', -1, 1, 'cold'),
	('LB1-PLANT', 'Plant room', -1, 1, 'ok');
""" % [",\n".join(rows), doors.ante, doors.vault_c, doors.it, doors.office]


## A punch card's number, C- and four digits, never one already dealt.
static func _card(rng: RandomNumberGenerator, used: Dictionary) -> String:
	while true:
		var c := "C-%04d" % rng.randi_range(1000, 9999)
		if not used.has(c):
			used[c] = true
			return c
	return ""


## A service key: two groups of four hex characters.
static func _key(rng: RandomNumberGenerator) -> String:
	var hex := "0123456789abcdef"
	var out := ""
	for i in 8:
		if i == 4:
			out += "-"
		out += hex[rng.randi_range(0, 15)]
	return out


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


## An echo by id among this run's six, or {}.
static func echo(data: Dictionary, id: String) -> Dictionary:
	for e in data.echoes:
		if e.id == id:
			return e
	return {}
