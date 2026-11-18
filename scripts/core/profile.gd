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
## Cases this player has solved, on any run: id -> {title, how} (Game.solve_case).
## The garage's back-office PC lists them (ArchiveTerminal).
var cases := {}
## The terminal's word buttons (KeywordHelp): how many times this player has used
## each SQL word in a query that ran (word -> n), the words whose button has come
## off, and whether the first-time tip about the buttons has shown.
var word_uses := {}
var words_off: Array = []
var buttons_tip := false


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
	var c = cfg.get_value("cases", "closed", {})
	p.cases = c if c is Dictionary else {}
	var u = cfg.get_value("terminal", "word_uses", {})
	if u is Dictionary:
		for k in u:
			if k is String and (u[k] is int or u[k] is float):
				p.word_uses[k] = int(u[k])
	var w = cfg.get_value("terminal", "words_off", [])
	p.words_off = w.filter(func(x): return x is String) if w is Array else []
	p.buttons_tip = bool(cfg.get_value("terminal", "buttons_tip", false))
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
	cfg.set_value("cases", "closed", cases)
	cfg.set_value("terminal", "word_uses", word_uses)
	cfg.set_value("terminal", "words_off", words_off)
	cfg.set_value("terminal", "buttons_tip", buttons_tip)
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


## Record a solved case. False if it was already on the list.
func close_case(id: String, title: String, how: String) -> bool:
	if cases.has(id):
		return false
	cases[id] = {"title": title, "how": how}
	save()
	return true


## Own one item outright. False if they already had it.
func grant(item_key: String) -> bool:
	if has_item(item_key) or not item_key.contains("/") or Cosmetics.info(item_key.get_slice("/", 0), item_key.get_slice("/", 1)).is_empty():
		return false
	owned.append(item_key)
	save()
	return true


## Count one use of each of `words` (KeywordHelp.used_in). Returns the ones that
## just reached KeywordHelp.USES.
func use_words(words: Array) -> Array:
	var reached := []
	for w in words:
		var n: int = int(word_uses.get(w, 0)) + 1
		word_uses[w] = n
		if n == KeywordHelp.USES:
			reached.append(w)
	if not words.is_empty():
		save()
	return reached


func uses_of(word: String) -> int:
	return int(word_uses.get(word, 0))


## "Put the training wheels back on": every word is a button again.
func reset_words() -> void:
	word_uses.clear()
	words_off.clear()
	save()
