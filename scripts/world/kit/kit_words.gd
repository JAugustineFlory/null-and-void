class_name KitWords
extends RefCounted
## Every word the environment kit says to players, in one place, so Augustine can
## approve them word for word (and so a floor builder never invents its own). `%s` is
## filled in with an item's name (Inventory.ITEMS) or a label. Floor-specific words
## (fuse labels, patch-panel labels, what a stuck hatch says) come from the floor.

const W := {
	# Gear lying around (GearPickup).
	"pick_up": "Pick up the %s",
	"swap": "Swap your %s for the %s",
	"hands_full": "Your hands are full. Hold the gear you'd leave here (1-4) to swap it.",
	"already": "You already carry a %s.",
	# A gear train (GearTrain).
	"jam": "Jam the gears with your %s",
	"turning": "The gears are turning. Something could jam them.",
	"unjam": "Pull the %s out of the gears",
	"jammed_already": "Something's jammed in the gears: a %s.",
	# A fuse box (FuseSlot): %s is the slot's label.
	"fuse_pull": "Pull the %s fuse",
	"fuse_fit": "Fit your fuse in %s",
	"fuse_swap": "Swap your fuse for the blown %s fuse",
	"fuse_blown": "The %s fuse has blown.",
	"fuse_empty": "No fuse in %s.",
	"fuse_works": "The %s fuse is fine.",
	# A patch panel (PatchPoint): %s is the port's or jack's label.
	"lead_take": "Take the %s lead",
	"lead_back": "Let go of the %s lead",
	"lead_plug": "Plug the %s lead in here",
	"lead_unplug": "Unplug the %s lead",
	"lead_busy": "Someone's holding the %s lead.",
	# A terminal that starts broken or switched off (TerminalRig).
	"power_on": "Press the power button",
	"no_power": "Nothing. It isn't getting any power.",
	"no_picture": "The power light's on, but there's no picture.",
	"no_keyboard": "There's no keyboard.",
	"fit_keyboard": "Plug in the keyboard",
	"fit_cord": "Plug in the power cord",
	"no_cord": "The power cord is missing.",
	"reseat_cable": "Push the monitor cable back in",
}


static func say(key: String, args: Array = []) -> String:
	var text: String = W.get(key, key)
	return text % args if not args.is_empty() else text


## An item's name in lower case, for the middle of a sentence ("the keyboard").
static func item(id: String) -> String:
	return Inventory.item_name(id).to_lower()
