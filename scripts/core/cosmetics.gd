class_name Cosmetics
extends RefCounted
## Everything a player can wear or carry, and how they unlock. A loadout is
## what one player picked:
##
##   {"crew": "kit", "body": 2, "skin": 3,
##    "hair": {"item": "long", "color": Color(...)}, ...one per worn slot,
##    "flashlight": {"item": "standard", "color": Color(...)}, ...one per tool}
##
## The crew member sets only the voice and body type. Worn slots are Graphics'
## CharacterLooks.SLOTS (CharacterLooks.outfit draws them); tools are
## CharacterLooks.TOOL_SLOTS, drawn by the held items and the terminal screen.
## Every color is free. Adding an item is one line in ITEMS; it shows in the
## lobby once Graphics can draw it (its id is in CharacterLooks.SLOTS).
##
## `unlock` says who owns an item: "default" (everyone), "achievement:<id>",
## "secret:<id>" or "purchase:<sku>". Locked items show in the lobby with their
## `hint`; secret ones stay hidden until owned (Augustine, 2026-10-20). Levels
## grant them with LevelSync.unlock(source), which every player present gets.
## An item with a `color` (a tool skin like the amber terminal) sets the slot's
## color when picked; the player can still change it.

const WORN_SLOTS := ["hair", "head", "top", "jacket", "legs", "feet", "face", "ears", "belt"]
const TOOL_SLOTS := ["flashlight", "walkie", "notebook", "terminal"]
const SLOT_NAMES := {
	"hair": "Hair", "head": "Hat", "top": "Top", "jacket": "Jacket", "legs": "Legs",
	"feet": "Shoes", "face": "Face", "ears": "Ears", "belt": "Belt",
	"flashlight": "Flashlight", "walkie": "Walkie", "notebook": "Notebook", "terminal": "Terminal",
}
## What the tools look like before anyone changes them.
const TOOL_COLORS := {
	"flashlight": Color(0.12, 0.12, 0.13), "walkie": Color(0.1, 0.1, 0.1),
	"notebook": NotebookView.COVER, "terminal": TerminalScreen.PHOSPHOR,
}

const ITEMS := [
	{"slot": "hair", "item": "short", "name": "Short", "unlock": "default"},
	{"slot": "hair", "item": "long", "name": "Long", "unlock": "default"},
	{"slot": "hair", "item": "bob", "name": "Bob", "unlock": "default"},
	{"slot": "hair", "item": "bald", "name": "Bald", "unlock": "default"},
	{"slot": "head", "item": "none", "name": "None", "unlock": "default"},
	{"slot": "head", "item": "cap", "name": "Ball cap", "unlock": "default"},
	{"slot": "head", "item": "beanie", "name": "Beanie", "unlock": "default"},
	{"slot": "head", "item": "hard_hat", "name": "Hard hat", "unlock": "achievement:floor_g", "hint": "Finish the ground floor."},
	{"slot": "top", "item": "polo", "name": "Polo", "unlock": "default"},
	{"slot": "top", "item": "tee", "name": "T-shirt", "unlock": "default"},
	{"slot": "top", "item": "longsleeve", "name": "Long-sleeve shirt", "unlock": "default"},
	{"slot": "top", "item": "blouse", "name": "Blouse", "unlock": "default"},
	{"slot": "jacket", "item": "none", "name": "None", "unlock": "default"},
	{"slot": "jacket", "item": "jacket", "name": "Work jacket", "unlock": "default"},
	{"slot": "jacket", "item": "blazer", "name": "Blazer", "unlock": "default"},
	{"slot": "jacket", "item": "coat", "name": "Long coat", "unlock": "default"},
	{"slot": "legs", "item": "pants", "name": "Trousers", "unlock": "default"},
	{"slot": "feet", "item": "shoes", "name": "Work shoes", "unlock": "default"},
	{"slot": "face", "item": "none", "name": "None", "unlock": "default"},
	{"slot": "face", "item": "glasses", "name": "Glasses", "unlock": "default"},
	{"slot": "face", "item": "mustache", "name": "Mustache", "unlock": "default"},
	{"slot": "ears", "item": "none", "name": "None", "unlock": "default"},
	{"slot": "ears", "item": "studs", "name": "Stud earrings", "unlock": "default"},
	{"slot": "belt", "item": "radio", "name": "Belt radio", "unlock": "default"},
	{"slot": "belt", "item": "none", "name": "None", "unlock": "default"},
	{"slot": "flashlight", "item": "standard", "name": "Standard", "unlock": "default"},
	{"slot": "walkie", "item": "standard", "name": "Standard", "unlock": "default"},
	{"slot": "notebook", "item": "spiral", "name": "Spiral", "unlock": "default"},
	{"slot": "terminal", "item": "phosphor", "name": "Phosphor", "unlock": "default"},
	# The first unlocks (Augustine, 2026-10-20 23:24Z; plan/approvals/unlocks.md).
	# Worn ones show once Graphics adds their ids to CharacterLooks.SLOTS.
	{"slot": "notebook", "item": "easy_sql", "name": "Easy SQL cover", "unlock": "achievement:book_easy_sql",
		"hint": "Pick up the crew's first book.", "color": Color(0.05, 0.55, 0.6)},
	{"slot": "face", "item": "reading_glasses", "name": "Reading glasses", "unlock": "achievement:easy_sql_half", "hint": "Finish half of Easy SQL."},
	{"slot": "top", "item": "byte_right_polo", "name": "Byte-Right polo", "unlock": "achievement:easy_sql_done", "hint": "Finish every chapter of Easy SQL."},
	{"slot": "feet", "item": "high_tops", "name": "High-tops", "unlock": "achievement:first_block", "hint": "Block a hit in a real fight."},
	{"slot": "terminal", "item": "amber", "name": "Amber", "unlock": "achievement:floor_14", "hint": "Finish floor 14.", "color": Color(1.0, 0.7, 0.2)},
	{"slot": "jacket", "item": "security", "name": "Security jacket", "unlock": "achievement:floor_22", "hint": "Finish floor 22."},
	{"slot": "head", "item": "mercer_cap", "name": "Mercer's cap", "unlock": "secret:mercer_vent_tape"},
	{"slot": "walkie", "item": "gold", "name": "Gold", "unlock": "secret:roster_thu", "color": Color(0.83, 0.66, 0.22)},
	{"slot": "jacket", "item": "press", "name": "Press jacket", "unlock": "secret:ending_news"},
]

## The catalogue in use: ITEMS, unless a test swaps in its own (reset() puts it back).
static var catalogue: Array = ITEMS.duplicate(true)


static func reset() -> void:
	catalogue = ITEMS.duplicate(true)


static func all_slots() -> Array:
	return WORN_SLOTS + TOOL_SLOTS


static func key(slot: String, item: String) -> String:
	return "%s/%s" % [slot, item]


## One item's entry ({slot, item, name, unlock, hint}), or {}.
static func info(slot: String, item: String) -> Dictionary:
	for it in catalogue:
		if it.slot == slot and it.item == item:
			return it
	return {}


## The items in `slot` that can be drawn now, in catalogue order.
static func items_in(slot: String) -> Array:
	return catalogue.filter(func(it): return it.slot == slot and drawable(slot, it.item))


static func drawable(slot: String, item: String) -> bool:
	if CharacterLooks.SLOTS.has(slot):
		return item in CharacterLooks.SLOTS[slot]
	return slot in TOOL_SLOTS


static func is_secret(it: Dictionary) -> bool:
	return str(it.get("unlock", "")).begins_with("secret:")


## The items `source` ("achievement:<id>", "secret:<id>" or "purchase:<sku>") unlocks.
static func unlocked_by(source: String) -> Array:
	return catalogue.filter(func(it): return it.get("unlock", "") == source)


## What player number `index` (0 = host) wears until they change it, so
## teammates who never open the picker still look different.
static func default_loadout(index: int) -> Dictionary:
	var i := posmod(index, ArtPalette.CREW_COLORS.size())
	var hairs := [Color(0.18, 0.12, 0.08), Color(0.05, 0.04, 0.04), Color(0.55, 0.38, 0.2),
		Color(0.08, 0.06, 0.05), Color(0.3, 0.2, 0.12), Color(0.7, 0.55, 0.3)]
	var crew_slugs := PlayableCrew.slugs()
	var crew: String = crew_slugs[posmod(index, crew_slugs.size())]
	var out := {
		"crew": crew,
		"body": int(PlayableCrew.info(crew).body),
		"skin": [2, 5, 1, 6, 3, 0][i],
		"hair": {"item": ["short", "short", "long", "short", "bald", "long"][i], "color": hairs[i]},
		"head": {"item": "cap" if i == 1 else "none", "color": CharacterLooks.SLOT_COLORS.head},
		"top": {"item": "polo", "color": ArtPalette.CREW_COLORS[i]},
		"jacket": {"item": "none", "color": CharacterLooks.SLOT_COLORS.jacket},
		"legs": {"item": "pants", "color": Color(0.17, 0.18, 0.2) if i % 2 == 0 else Color(0.33, 0.29, 0.22)},
		"feet": {"item": "shoes", "color": CharacterLooks.SLOT_COLORS.feet},
		"face": {"item": "glasses" if i == 2 or i == 5 else "none", "color": CharacterLooks.SLOT_COLORS.face},
		"ears": {"item": "none", "color": CharacterLooks.SLOT_COLORS.ears},
		"belt": {"item": "radio", "color": CharacterLooks.SLOT_COLORS.belt},
	}
	for slot in TOOL_SLOTS:
		out[slot] = {"item": items_in(slot)[0].item, "color": TOOL_COLORS[slot]}
	return out


## Only the valid parts of `choice`: a crew slug, a skin index, and per slot an
## item in the catalogue and/or a color. With `owner` (a Profile), items they
## don't own are dropped too. What's left is still a partial loadout.
static func trim(choice: Dictionary, owner: Object = null) -> Dictionary:
	var out := {}
	if not PlayableCrew.info(str(choice.get("crew", ""))).is_empty():
		out.crew = str(choice.crew)
	var skin = choice.get("skin")
	if (skin is int or skin is float) and int(skin) >= 0 and int(skin) < CharacterLooks.SKIN_TONES.size():
		out.skin = int(skin)
	for slot in all_slots():
		var e = choice.get(slot)
		if not e is Dictionary:
			continue
		var part := {}
		var item = e.get("item")
		if item is String and not info(slot, item).is_empty() and (owner == null or owner.has_item(key(slot, item))):
			part.item = item
		var color = e.get("color")
		if color is Color:
			part.color = Color(clampf(color.r, 0, 1), clampf(color.g, 0, 1), clampf(color.b, 0, 1))
		if not part.is_empty():
			out[slot] = part
	return out


## A whole loadout: what's valid in `choice`, the rest from default_loadout(index).
static func clean(choice: Dictionary, index: int) -> Dictionary:
	var out := merge(default_loadout(index), trim(choice))
	out.body = int(PlayableCrew.info(out.crew).body)
	return out


## `change` laid over `loadout`, slot by slot: {"top": {"color": c}} keeps the top's item.
static func merge(loadout: Dictionary, change: Dictionary) -> Dictionary:
	var out := loadout.duplicate(true)
	for k in change:
		if change[k] is Dictionary and out.get(k) is Dictionary:
			out[k].merge(change[k], true)
		else:
			out[k] = change[k].duplicate(true) if change[k] is Dictionary else change[k]
	return out
