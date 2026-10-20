class_name CharacterLooks
extends RefCounted
## What each character wears. CharacterRig.build(parent, CharacterLooks.rourke())
## turns one of these into a body. Every key is optional; missing ones fall back
## to `base()`.


static func base() -> Dictionary:
	return {
		"name": "",
		"height": 1.0,  # scale on the whole body
		"build": 1.0,  # shoulder and waist width
		"skin": Color(0.8, 0.64, 0.52),
		"hair": Color(0.2, 0.15, 0.1),
		"hair_style": "short",  # short, long, bald, cap
		"shirt": Color(0.6, 0.6, 0.6),
		"sleeves": "short",  # short, long
		"pants": Color(0.2, 0.2, 0.22),
		"shoes": Color(0.08, 0.07, 0.07),
		"jacket": null,  # a Color adds an open jacket over the shirt
		"coat": false,  # with a jacket: make it knee-length (lab coat)
		"badge": false,  # clip-on ID badge
		"lanyard": null,  # a Color adds a lanyard
		"glasses": false,
		"mustache": null,  # a Color adds one
		"logo": null,  # a Color adds a chest logo patch
		"belt_radio": false,  # walkie on the belt
		"body": 1,  # body type: 1 (straighter, broader shoulders) or 2 (narrower shoulders, waist and hips)
		"lips": null,  # a Color adds lipstick
		"earrings": null,  # a Color adds small stud earrings
		"shoulder_pads": false,  # with a jacket: squarer 90s shoulders
		"collar": false,  # a shirt collar (polo, blouse); hidden under a jacket
		"headwear": null,  # cap, beanie or hard_hat; drawn over the hair
		"headwear_color": Color(0.2, 0.2, 0.22),
	}


## Skin tones a player can pick, lightest to deepest.
const SKIN_TONES: Array[Color] = [
	Color(0.96, 0.82, 0.72), Color(0.9, 0.73, 0.6), Color(0.84, 0.66, 0.52), Color(0.74, 0.56, 0.42),
	Color(0.62, 0.45, 0.32), Color(0.52, 0.36, 0.25), Color(0.42, 0.29, 0.2), Color(0.32, 0.22, 0.16),
]
const BODY_TYPES := [1, 2]


## One of the IT crew. `index` 0-5 picks their polo color and a few details,
## so six players never look the same. `picks` overrides what the player chose
## in the lobby: {"body": 1 or 2, "skin": an index into SKIN_TONES}.
static func crew(index: int, picks: Dictionary = {}) -> Dictionary:
	var skins := [Color(0.85, 0.68, 0.56), Color(0.55, 0.38, 0.27), Color(0.9, 0.75, 0.62),
		Color(0.4, 0.27, 0.19), Color(0.74, 0.56, 0.42), Color(0.95, 0.8, 0.7)]
	var hairs := [Color(0.18, 0.12, 0.08), Color(0.05, 0.04, 0.04), Color(0.55, 0.38, 0.2),
		Color(0.08, 0.06, 0.05), Color(0.3, 0.2, 0.12), Color(0.7, 0.55, 0.3)]
	var styles := ["short", "cap", "long", "short", "bald", "long"]
	var i := posmod(index, ArtPalette.CREW_COLORS.size())
	var look := base()
	look.merge({
		"name": "Crew %d" % (i + 1),
		"build": [1.0, 1.08, 0.94, 1.12, 1.0, 0.92][i],
		"skin": skins[i],
		"hair": hairs[i],
		"hair_style": styles[i],
		"shirt": ArtPalette.CREW_COLORS[i],
		"pants": Color(0.17, 0.18, 0.2) if i % 2 == 0 else Color(0.33, 0.29, 0.22),
		"logo": Color(0.95, 0.95, 0.92),
		"glasses": i == 2 or i == 5,
		"belt_radio": true,
	}, true)
	if picks.has("body") and int(picks.body) in BODY_TYPES:
		look.body = int(picks.body)
		if look.body == 2:
			look.build = minf(look.build, 1.0)
	if picks.has("skin"):
		look.skin = SKIN_TONES[clampi(int(picks.skin), 0, SKIN_TONES.size() - 1)]
	return look


## Player customisation. A loadout is {slot: {"item": id, "color": Color}} plus
## "name", "body" (1 or 2, from the chosen character) and "skin" (a SKIN_TONES
## index). Every item's color tints it. Unlockable items add ids to a slot,
## never new slots; each slot holds one item so the rig stays in budget.
## The first id in each list is the default; "none" leaves the slot empty.
const SLOTS := {
	"hair": ["short", "long", "bob", "bald"],
	"head": ["none", "cap", "beanie", "hard_hat"],
	"top": ["polo", "tee", "longsleeve", "blouse"],
	"jacket": ["none", "jacket", "blazer", "coat"],
	"legs": ["pants"],
	"feet": ["shoes"],
	"face": ["none", "glasses", "mustache"],
	"ears": ["none", "studs"],
	"belt": ["radio", "none"],
}
## Skins for things the player holds rather than wears (applied by HeldItems
## and the terminal, not the rig).
const TOOL_SLOTS := ["flashlight", "walkie", "notebook", "terminal"]
const SLOT_COLORS := {
	"hair": Color(0.2, 0.15, 0.1), "head": Color(0.2, 0.25, 0.45), "top": Color(0.6, 0.6, 0.6),
	"jacket": Color(0.17, 0.21, 0.31), "legs": Color(0.2, 0.2, 0.22), "feet": Color(0.08, 0.07, 0.07),
	"face": Color(0.12, 0.1, 0.1), "ears": Color(0.85, 0.75, 0.4), "belt": ArtPalette.DARK_PLASTIC,
}


## A customised player look from a loadout (see SLOTS). Unknown items and
## missing slots fall back to that slot's default.
static func outfit(slots: Dictionary) -> Dictionary:
	var look := base()
	look.name = str(slots.get("name", ""))
	look.body = int(slots.get("body", 1)) if int(slots.get("body", 1)) in BODY_TYPES else 1
	if look.body == 2:
		look.build = 0.95
	look.skin = SKIN_TONES[clampi(int(slots.get("skin", 2)), 0, SKIN_TONES.size() - 1)]
	look.logo = Color(0.95, 0.95, 0.92)
	var pick := func(slot: String) -> Array:
		var entry = slots.get(slot, {})
		var item: String = str(entry.get("item", "")) if entry is Dictionary else ""
		if not item in SLOTS[slot]:
			item = SLOTS[slot][0]
		var color = entry.get("color") if entry is Dictionary else null
		return [item, color if color is Color else SLOT_COLORS[slot]]
	var hair: Array = pick.call("hair")
	look.hair_style = hair[0]
	look.hair = hair[1]
	var head: Array = pick.call("head")
	if head[0] != "none":
		look.headwear = head[0]
		look.headwear_color = head[1]
	var top: Array = pick.call("top")
	look.shirt = top[1]
	look.sleeves = "long" if top[0] in ["longsleeve", "blouse"] else "short"
	look.collar = top[0] in ["polo", "blouse"]
	var jacket: Array = pick.call("jacket")
	if jacket[0] != "none":
		look.jacket = jacket[1]
		look.coat = jacket[0] == "coat"
		look.shoulder_pads = jacket[0] == "blazer"
		look.logo = null  # the polo's patch is under the jacket
	look.pants = pick.call("legs")[1]
	look.shoes = pick.call("feet")[1]
	var face: Array = pick.call("face")
	if face[0] == "glasses":
		look.glasses = face[1]
	elif face[0] == "mustache":
		look.mustache = face[1]
	var ears: Array = pick.call("ears")
	if ears[0] == "studs":
		look.earrings = ears[1]
	look.belt_radio = pick.call("belt")[0] == "radio"
	return look


## Maddison Kowalski, Byte-Right's CEO, around 40: mature, confident and upbeat.
## 1997 small-business-owner style: a raspberry blazer with 90s shoulders over a
## cream blouse, charcoal slacks, a glossy auburn bob, red lipstick, and the
## company pin on her lapel.
## `age` is 40 or 50 (Augustine is choosing): at 50 her auburn has gone a little
## silver and she wears reading glasses.
static func maddison(age: int = 40) -> Dictionary:
	var look := base()
	look.merge({
		"name": "Maddison",
		"body": 2,
		"height": 0.99,
		"build": 0.95,
		"skin": Color(0.88, 0.71, 0.6),
		"hair": Color(0.42, 0.17, 0.09),
		"hair_style": "bob",
		"shirt": Color(0.93, 0.89, 0.8),
		"sleeves": "long",
		"pants": Color(0.2, 0.2, 0.23),
		"shoes": Color(0.1, 0.05, 0.06),
		"jacket": Color(0.62, 0.12, 0.3),
		"shoulder_pads": true,
		"logo": ArtPalette.BYTERIGHT_BLUE,
		"lips": Color(0.66, 0.1, 0.16),
	}, true)
	if age >= 50:
		look.hair = Color(0.52, 0.34, 0.27)
		look.glasses = true
	return look


## Dale Rourke, facilities. Friendly, a bit heavy, navy work jacket, badge.
static func rourke() -> Dictionary:
	var look := base()
	look.merge({
		"name": "Rourke",
		"height": 1.04,
		"build": 1.15,
		"skin": Color(0.84, 0.66, 0.55),
		"hair": Color(0.45, 0.43, 0.4),
		"shirt": Color(0.78, 0.76, 0.7),
		"sleeves": "long",
		"pants": Color(0.45, 0.4, 0.3),
		"jacket": Color(0.17, 0.21, 0.31),
		"badge": true,
		"lanyard": ArtPalette.HALCYON_NAVY,
		"mustache": Color(0.4, 0.38, 0.35),
		"belt_radio": true,
	}, true)
	return look


## Dr. Vale. Lab coat over dark clothes, glasses.
static func vale() -> Dictionary:
	var look := base()
	look.merge({
		"name": "Vale",
		"height": 0.96,
		"build": 0.9,
		"skin": Color(0.7, 0.52, 0.4),
		"hair": Color(0.08, 0.06, 0.05),
		"hair_style": "long",
		"shirt": Color(0.2, 0.2, 0.24),
		"sleeves": "long",
		"pants": Color(0.12, 0.12, 0.14),
		"jacket": Color(0.9, 0.9, 0.88),
		"coat": true,
		"badge": true,
		"lanyard": ArtPalette.HALCYON_NAVY,
		"glasses": true,
	}, true)
	return look


## Mercer, the old lead engineer (photos, memories). Cardigan, glasses, grey.
static func mercer() -> Dictionary:
	var look := base()
	look.merge({
		"name": "Mercer",
		"height": 0.98,
		"skin": Color(0.86, 0.72, 0.62),
		"hair": Color(0.75, 0.75, 0.72),
		"hair_style": "bald",
		"shirt": Color(0.85, 0.83, 0.75),
		"sleeves": "long",
		"pants": Color(0.3, 0.28, 0.25),
		"jacket": Color(0.4, 0.3, 0.22),
		"glasses": true,
		"badge": true,
	}, true)
	return look


## The missing night guard (Level 2). Grey-blue uniform and cap.
static func night_guard() -> Dictionary:
	var look := base()
	look.merge({
		"name": "Night guard",
		"build": 1.05,
		"skin": Color(0.6, 0.44, 0.32),
		"hair_style": "cap",
		"hair": Color(0.15, 0.17, 0.22),  # cap color
		"shirt": Color(0.42, 0.48, 0.56),
		"sleeves": "long",
		"pants": Color(0.15, 0.17, 0.22),
		"badge": true,
		"logo": ArtPalette.HALCYON_GOLD,
		"belt_radio": true,
	}, true)
	return look
