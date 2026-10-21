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
