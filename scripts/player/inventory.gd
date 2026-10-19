class_name Inventory
extends RefCounted
## What one player carries. The notebook (Tab) and flashlight (F) are always at
## hand; everything else they pick up goes in the inventory and, if there's room,
## onto the hotbar: four slots on keys 1-4. The inventory screen (I) changes which
## items sit in the hotbar.
##
## Each machine keeps its own player's inventory, like the notebook. Pickups are
## decided on the host and played out everywhere with the taker's peer id, and
## only the taker's machine adds the item (see `for_peer`).

signal changed
## The hotbar slot in your hands changed: its item id, or "" for empty hands.
signal selected(item: String)

const HOTBAR_SIZE := 4
## Always carried, with their own keys; listed in the inventory but never on the hotbar.
const FIXED := ["notebook", "flashlight"]
## Clipped on, not held: carried and listed, but never on the hotbar.
const WORN := ["visitor_badge"]
## Everything a player can carry: id -> name and a line about it.
const ITEMS := {
	"notebook": {"name": "Notebook", "key": "Tab", "about": "Notes, tables and the work order."},
	"flashlight": {"name": "Flashlight", "key": "F", "about": "Lights the way. Lights don't always work here."},
	"radio": {"name": "Walkie-talkie", "about": "Channel 1. Hold V to talk to the crew."},
	"screwdriver": {"name": "Screwdriver", "about": "Flat-head. Undoes screws: grates, panels, covers."},
	"cable": {"name": "Network cable", "about": "A coil of Cat5. Strong enough to tie someone up."},
	"visitor_badge": {"name": "Visitor badge", "about": "Clipped on. Card readers upstairs want to see it."},
}

## Every item carried, in the order picked up (the fixed ones first).
var items: Array[String] = []
## The four hotbar slots: an item id, or "" for an empty slot.
var hotbar: Array[String] = []
## The slot in your hands, or -1.
var active := -1


func _init() -> void:
	clear()


## Back to a fresh run: just the notebook and flashlight.
func clear() -> void:
	items.assign(FIXED)
	hotbar.assign([])
	hotbar.resize(HOTBAR_SIZE)
	hotbar.fill("")
	active = -1
	changed.emit()


func has(item: String) -> bool:
	return items.has(item)


static func item_name(item: String) -> String:
	return ITEMS.get(item, {}).get("name", item.capitalize())


## Picks up `item`: it goes in the inventory and into the first empty hotbar slot.
## False if you already have it.
func add(item: String) -> bool:
	if item == "" or items.has(item):
		return false
	items.append(item)
	if not FIXED.has(item) and not WORN.has(item):
		var slot := hotbar.find("")
		if slot >= 0:
			hotbar[slot] = item
	changed.emit()
	return true


## Picks up `item` if `peer` is `my_peer`: the pickup event runs on every machine,
## and only the taker's inventory gains the item.
func add_for_peer(item: String, peer: int, my_peer: int) -> bool:
	return peer == my_peer and add(item)


func remove(item: String) -> void:
	if not items.has(item) or FIXED.has(item):
		return
	items.erase(item)
	var slot := hotbar.find(item)
	if slot >= 0:
		hotbar[slot] = ""
		if slot == active:
			_set_active(-1)
	changed.emit()


## Items you carry that aren't on the hotbar (or fixed): what the inventory screen
## offers for an empty or swapped slot.
func stowed() -> Array[String]:
	var out: Array[String] = []
	for item in items:
		if not FIXED.has(item) and not WORN.has(item) and not hotbar.has(item):
			out.append(item)
	return out


## Puts `item` in hotbar `slot`. If it was already in another slot the two swap;
## whatever was in `slot` goes back in the bag. "" empties the slot.
func assign(slot: int, item: String) -> bool:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return false
	if item != "" and (not items.has(item) or FIXED.has(item) or WORN.has(item)):
		return false
	var was := hotbar.find(item) if item != "" else -1
	var held := hotbar[active] if active >= 0 else ""
	if was >= 0:
		hotbar[was] = hotbar[slot]
	hotbar[slot] = item
	changed.emit()
	# Whatever you were holding stays in your hands if it moved, or is put away if it left the bar.
	if held != "":
		_set_active(hotbar.find(held))
	return true


## Key 1-4: take out what's in that slot, or put it away if it's already out.
## An empty slot puts away what you're holding.
func use_slot(slot: int) -> void:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return
	_set_active(-1 if slot == active or hotbar[slot] == "" else slot)


## The item in your hands, or "".
func active_item() -> String:
	return hotbar[active] if active >= 0 else ""


func _set_active(slot: int) -> void:
	if slot == active:
		return
	active = slot
	selected.emit(active_item())


func to_dict() -> Dictionary:
	return {"items": items.duplicate(), "hotbar": hotbar.duplicate()}


func load_dict(data: Dictionary) -> void:
	items.assign(FIXED)
	for item in data.get("items", []):
		if not items.has(item):
			items.append(item)
	hotbar.fill("")
	var bar: Array = data.get("hotbar", [])
	for i in mini(bar.size(), HOTBAR_SIZE):
		if items.has(bar[i]) and not FIXED.has(bar[i]) and not hotbar.has(bar[i]):
			hotbar[i] = bar[i]
	active = -1
	changed.emit()
