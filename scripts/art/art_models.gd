class_name ArtModels
extends RefCounted
## Where each model comes from, by id. Load models through here, not by path:
## a private assets folder (paid models, which can't go in this public repo)
## wins when it is there, and the free CC0 model in the repo is the fallback,
## so CI and anyone without the private assets still gets a whole game.
##
##   var scene := ArtModels.scene("character/body1")

## A copy of res://assets/ laid out the same way, holding the paid models.
const PRIVATE_ROOT := "res://assets_private/"
const FREE := {
	"character/body1": "res://assets/art/characters/body1.glb",
	"character/body2": "res://assets/art/characters/body2.glb",
	"character/locomotion": "res://assets/art/characters/locomotion.res",
	# Furniture and fittings from the packs (tools/art/build_props.py): one mesh each.
	"prop/desk_lamp": "res://assets/art/props/desk_lamp.res",
	"prop/generator": "res://assets/art/props/generator.res",
	"prop/hand_truck": "res://assets/art/props/hand_truck.res",
	"prop/metal_desk": "res://assets/art/props/metal_desk.res",
	"prop/metal_rack": "res://assets/art/props/metal_rack.res",
	"prop/utility_box": "res://assets/art/props/utility_box.res",
	"prop/wall_clock": "res://assets/art/props/wall_clock.res",
	"prop/wheelie_bin": "res://assets/art/props/wheelie_bin.res",
	"prop/wood_chair": "res://assets/art/props/wood_chair.res",
	"prop/wood_desk": "res://assets/art/props/wood_desk.res",
}

static var _loaded := {}


## The path the model with this id loads from.
static func path(id: String) -> String:
	var free: String = FREE[id]
	var paid := PRIVATE_ROOT + free.trim_prefix("res://assets/")
	return paid if ResourceLoader.exists(paid) else free


static func scene(id: String) -> PackedScene:
	return load_resource(id) as PackedScene


static func load_resource(id: String) -> Resource:
	if not _loaded.has(id):
		_loaded[id] = load(path(id))
	return _loaded[id]
