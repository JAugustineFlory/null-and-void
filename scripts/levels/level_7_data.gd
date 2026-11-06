class_name Level7Data
extends RefCounted
## Builds Level 7's data from a seed: B2, the building's machine room ("Lights Out").
## Act 2's last floor, under the cold store.
##
## B2's services moved to tokens at the upgrade: a key alone gets 401. The IT admin's
## runbook page says how to trade the key for a token (POST /auth/token), and a token
## runs out after a few minutes. The plant ring round WARDEN's core is lit in six
## zones, one circuit each, plus the emergency exit circuit, which is life safety and
## nobody's to switch. The lifts down here are two passenger cars and the freight
## lift, which has been out of service since Tuesday.
##
## The test bench in the admin office is a mock of the same lighting: the same paths,
## the same zone ids, its own fake floor. Scripts are tried there first.

## The crew's company, as the visitor cards print it.
const COMPANY := "Byte-Right IT Services"
## The ring's six zones, clockwise from the lobby door: what each is called, and the
## part of the ring it lights (level space AABB, see level_7.gd).
const ZONE_NAMES := ["Ring south-west", "Ring south-east", "Ring east", "Ring north-east", "Ring north-west", "Ring west"]
## The passenger lifts 1-4 (the memo on 18 names them); two of them come down to B2.
const LIFTS := [1, 2, 3, 4]
## WARDEN's rules before tonight, readable with SELECT on warden_protocols. His 4.0
## rows are added when the crew beats him (level_7.gd). DRAFT: plan/approvals/l7-text.md.
const RULES := [
	[1, "1.0", "Protect the building and the people in it."],
	[2, "1.0", "Doors follow the access schedule."],
	[3, "1.0", "Visitors are escorted at all times."],
	[17, "2.0", "An unescorted visitor is a breach."],
	[31, "3.0", "Under protocol Epsilon, the database only reads."],
	[44, "3.1", "Lights on breached floors are switched by security control."],
]


static func build(run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 7919 + 13
	# The zone ids: B2-Z and two digits, all different, in ring order.
	var used := {}
	var zones := []
	for i in ZONE_NAMES.size():
		var n := rng.randi_range(10, 99)
		while used.has(n):
			n = rng.randi_range(10, 99)
		used[n] = true
		zones.append({"id": "B2-Z%02d" % n, "name": ZONE_NAMES[i], "ring": i})
	var em_n := rng.randi_range(1, 9)
	var emergency := {"id": "B2-EM%d" % em_n, "name": "Emergency exit lighting", "ring": -1}
	# The order GET /lights lists them in: the service's own, not the ring's.
	var listed: Array = zones.duplicate()
	listed.append(emergency)
	_shuffle(listed, rng)
	# Two of the four passenger lifts serve B2; the freight lift is the decoy.
	var cars: Array = LIFTS.duplicate()
	_shuffle(cars, rng)
	cars = cars.slice(0, 2)
	cars.sort()
	var lifts := []
	for c in cars:
		lifts.append({"id": "LIFT-%d" % c, "name": "Passenger lift %d" % c, "kind": "passenger"})
	lifts.append({"id": "LIFT-F", "name": "Freight lift", "kind": "freight"})
	_shuffle(lifts, rng)
	var key := _key(rng)
	# The runbook's example token: from the admin's training slides, long expired.
	var example := "tok_"
	for i in 12:
		example += "0123456789abcdef"[rng.randi_range(0, 15)]
	# Which two zones WARDEN cuts first, when he hears the crew below him.
	var first_cut: Array = zones.map(func(z): return z.id)
	_shuffle(first_cut, rng)
	# Never the closet's zone: its maglock fails open in the dark (the fight's lockout
	# route), and WARDEN only learns to cut it once the crew fights back.
	first_cut = first_cut.filter(func(id): return id != zones[0].id).slice(0, 2)
	var data := {
		"zones": zones, "emergency": emergency, "listed": listed.map(func(z): return z.id),
		"lifts": lifts, "key": key, "example_token": example,
		# A token lasts a few minutes (seeded): long enough for a script, short enough
		# that an old one copied off a screen won't do.
		"token_seconds": float(rng.randi_range(150, 240)),
		"token_seed": rng.randi(),
		"bench_seed": rng.randi(),
		"first_cut": first_cut,
		"clock": "%02d:%02d" % [2, rng.randi_range(0, 20)],
		"company": COMPANY,
	}
	_fight(data, rng)
	data["sql"] = _sql(data)
	return data


## The fight (case 4) and the lifts (case 5), drawn after everything above so the
## first three cases' data stays the same for a seed.
static func _fight(data: Dictionary, rng: RandomNumberGenerator) -> void:
	# WARDEN's own key and token, the ones his cuts go through; and the backup key's
	# tokens he mints when the crew revokes his own (the revoke route's last stand).
	data["warden_key"] = _key(rng)
	data["warden_token"] = _token(rng)
	var minted := []
	for i in rng.randi_range(4, 6):
		minted.append(_token(rng))
	data["warden_minted"] = minted
	# The auth log: everyone who asked B2 for a token tonight and earlier this week.
	# WARDEN's line is one of many.
	var entries := []
	var holders := ["IT admin (G.P.)", "Facilities", "Fire control", "Lift controller", "Building management", "Backup job"]
	var n := rng.randi_range(22, 28)
	for i in n:
		var day: String = ["Mon 10/13", "Tue 10/14", "Wed 10/15"][mini(i * 3 / n, 2)]
		entries.append({"token": _token(rng), "holder": holders[rng.randi_range(0, holders.size() - 1)],
			"issued": "%s %02d:%02d" % [day, rng.randi_range(0, 23), rng.randi_range(0, 59)], "state": "expired"})
	var at := rng.randi_range(n / 2, n)
	entries.insert(at, {"token": data.warden_token, "holder": "WARDEN", "issued": "Wed 10/15 19:00", "state": "ok"})
	data["auth_log"] = entries
	# His cuts: one beat between them, quickening as the crew wins (level_7.gd), and
	# the zone he holds on the watchdog route's last stand (never the closet's).
	data["cut_every"] = float(rng.randi_range(14, 20))
	var held: Array = data.zones.slice(1).map(func(z): return z.id)
	data["held_zone"] = held[rng.randi_range(0, held.size() - 1)]
	# The two plant rooms the night-shifters shelter in, and how long each room's gas
	# suppression counts down once WARDEN arms it.
	data["suppression"] = {"B2-MOTOR": float(rng.randi_range(110, 140)), "B2-UPS": float(rng.randi_range(110, 140))}
	# The car that comes for the crew: the first passenger lift that serves B2.
	var cars: Array = data.lifts.filter(func(l): return l.kind == "passenger").map(func(l): return l.id)
	cars.sort()
	data["car"] = cars[0]


static func _token(rng: RandomNumberGenerator) -> String:
	var out := "tok_"
	for i in 12:
		out += "0123456789abcdef"[rng.randi_range(0, 15)]
	return out


## The floor's lights in the building's lights table: the ring's zones, the emergency
## circuit, and the rooms off the lobby (on the admin circuit, not the ring's).
static func _sql(data: Dictionary) -> String:
	var rows := PackedStringArray()
	for z in data.zones:
		rows.append("\t('%s', '%s', -2, 1, 'ok')" % [z.id, z.name])
	rows.append("\t('%s', '%s', -2, 0, 'standby')" % [data.emergency.id, data.emergency.name])
	for r in [["LB2-LANDING", "Stair landing"], ["LB2-LOBBY", "Lift lobby"], ["LB2-ADMIN", "IT admin office"], ["LB2-MOTOR", "Lift motor room"]]:
		rows.append("\t('%s', '%s', -2, 1, 'ok')" % r)
	return """
INSERT INTO lights VALUES
%s;
INSERT INTO doors VALUES
	('B2-MOTOR', 'B2, lift motor room', 'B2', 1, 0),
	('B2-NETCL', 'B2, network closet', 'B2', 1, 0),
	('B2-UPS', 'B2, battery room', 'B2', 1, 0);
CREATE TABLE IF NOT EXISTS warden_protocols (rule_no INTEGER, version TEXT, rule TEXT);
INSERT INTO warden_protocols VALUES
%s;
""" % [",\n".join(rows), ",\n".join(PackedStringArray(RULES.map(func(r): return "\t(%d, '%s', '%s')" % [r[0], r[1], str(r[2]).replace("'", "''")])))]


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


## A zone by id (the six or the emergency circuit), or {}.
static func zone(data: Dictionary, id: String) -> Dictionary:
	for z in data.zones + [data.emergency]:
		if z.id.to_upper() == id.to_upper():
			return z
	return {}
