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
	first_cut = first_cut.slice(0, 2)
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
	data["sql"] = _sql(data)
	return data


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
	('B2-NETCL', 'B2, network closet', 'B2', 1, 0);
""" % ",\n".join(rows)


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
