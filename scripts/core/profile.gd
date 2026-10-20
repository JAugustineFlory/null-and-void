class_name Profile
extends RefCounted
## This player's saved choices, kept on their own computer: their name, what
## they picked in the lobby (a partial Cosmetics loadout; anything left out
## follows their place in the player order) and which items they own.
##
## Achievements and secrets unlock items by id: `earn("secret:roster_thu")`
## owns every catalogue item with that unlock, including ones added later.
## Purchases will `grant` single items.

const PATH := "user://profile.cfg"

## Where it saves; "" keeps it in memory only (tests).
var path := ""
var name := ""
var loadout := {}
## Achievement, secret and purchase ids this player has earned.
var earned: Array = []
## Items granted one by one (Cosmetics.key ids).
var owned: Array = []


static func open(at: String = PATH) -> Profile:
	var p := Profile.new()
	p.path = at
	var cfg := ConfigFile.new()
	if at == "" or cfg.load(at) != OK:
		return p
	var n = cfg.get_value("player", "name", "")
	p.name = str(n).strip_edges().left(16) if n is String else ""
	var e = cfg.get_value("unlocks", "earned", [])
	p.earned = e.filter(func(x): return x is String) if e is Array else []
	var o = cfg.get_value("unlocks", "owned", [])
	p.owned = o.filter(func(x): return x is String) if o is Array else []
	var l = cfg.get_value("player", "loadout", {})
	p.loadout = Cosmetics.trim(l, p) if l is Dictionary else {}
	return p


func save() -> void:
	if path == "":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", name)
	cfg.set_value("player", "loadout", loadout)
	cfg.set_value("unlocks", "earned", earned)
	cfg.set_value("unlocks", "owned", owned)
	cfg.save(path)


func has_item(item_key: String) -> bool:
	var parts := item_key.split("/")
	var it := Cosmetics.info(parts[0], parts[1] if parts.size() > 1 else "")
	if it.is_empty():
		return false
	return it.unlock == "default" or owned.has(item_key) or earned.has(it.unlock)


## Record an achievement, secret or purchase. Returns the keys of the items it
## newly unlocks (empty if it was already earned).
func earn(source: String) -> Array:
	if earned.has(source):
		return []
	var before := Cosmetics.unlocked_by(source).filter(func(it): return has_item(Cosmetics.key(it.slot, it.item)))
	earned.append(source)
	save()
	return Cosmetics.unlocked_by(source).filter(func(it): return not before.has(it)).map(
		func(it): return Cosmetics.key(it.slot, it.item))


## Own one item outright. False if they already had it.
func grant(item_key: String) -> bool:
	if has_item(item_key) or not item_key.contains("/") or Cosmetics.info(item_key.get_slice("/", 0), item_key.get_slice("/", 1)).is_empty():
		return false
	owned.append(item_key)
	save()
	return true
