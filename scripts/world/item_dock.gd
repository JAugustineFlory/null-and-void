class_name ItemDock
extends Interactable
## A place where each player takes their own: walkie-talkies on a charger, visitor
## badges on the counter, spare cable. Pressing E takes one for you; the others
## stay for your teammates. With no item it only records who used it (everyone
## signing the visitor log). Co-op: the host decides, every machine plays it out.

## Someone took theirs (on every machine).
signal taken(peer_id: int)

## The inventory item each player gets ("" for none).
var item := ""
## Peer ids that have taken theirs.
var taken_by := {}
## One model per item on show, hidden as they're taken (add with add_model).
var models: Array[Node3D] = []
## Shown when you press it again after taking yours.
var already := "You already have one."


static func make(parent: Node, center: Vector3, size: Vector3, prompt_text: String, item_id: String = "") -> ItemDock:
	var d := ItemDock.new()
	d.position = center
	d.prompt = prompt_text
	d.item = item_id
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	d.add_child(shape)
	parent.add_child(d)
	d.add_to_group("interactable")
	d.used.connect(d._on_used)
	return d


func add_model(model: Node3D) -> void:
	models.append(model)


## Show one item for each player (up to the models there are).
func stock(count: int) -> void:
	for i in models.size():
		models[i].visible = i < count - taken_by.size()


func get_prompt(player: Node) -> String:
	if _has_one(player):
		return already if enabled else ""
	return super.get_prompt(player)


## Pressing it again, or with one already from an earlier floor, takes nothing.
func interact(player: Node) -> void:
	if not _has_one(player):
		super.interact(player)


func _has_one(player: Node) -> bool:
	var lvl := _level()
	if lvl and taken_by.has(lvl.players.id_of(player)):
		return true
	var inv = player.get("inventory")
	return item != "" and inv != null and inv.has(item)


func has_taken(peer_id: int) -> bool:
	return taken_by.has(peer_id)


## Host: someone pressed it.
func _on_used(player: Node) -> void:
	var lvl := _level()
	var id: int = lvl.players.id_of(player) if lvl else 0
	if taken_by.has(id):
		return
	var sync := LevelSync.of(self)
	if sync:
		sync.run_on(self, "take", [id])
	else:
		take(id)


## On every machine: `peer_id` takes theirs.
func take(peer_id: int) -> void:
	if taken_by.has(peer_id):
		return
	taken_by[peer_id] = true
	for i in range(models.size() - 1, -1, -1):
		if models[i].visible:
			models[i].visible = false
			break
	var lvl := _level()
	if item != "" and lvl and peer_id == lvl.players.id_of(lvl.player):
		lvl.player.inventory.add(item)
	taken.emit(peer_id)


## The level this is in (it has the players). Duck-typed, like Document._level.
func _level() -> Node:
	var n := get_parent()
	while n and n.get("players") == null:
		n = n.get_parent()
	return n


## Simple box models on the dock, one per player (up to `count`), in a row along x.
func add_boxes(count: int, spacing: float, size: Vector3, color: Color, y: float = 0.0) -> void:
	for i in count:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		m.mesh = bm
		m.material_override = Greybox.mat(color)
		m.position = Vector3((i - (count - 1) / 2.0) * spacing, y + size.y / 2.0, 0)
		m.name = "Item%d" % i
		add_child(m)
		add_model(m)


## A charger of walkie-talkies, one each. Optional: taking one clips it on and
## turns on the radio (Hold V) for that player. Spares turn up on later floors too.
static func walkies(parent: Node, center: Vector3) -> ItemDock:
	var d := make(parent, center, Vector3(0.9, 0.2, 0.3), "Take a walkie-talkie", "radio")
	for i in 6:
		var radio := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.17, 0.04)
		radio.mesh = bm
		radio.material_override = Greybox.mat(Color(0.15, 0.16, 0.14))
		radio.position = Vector3(-0.375 + i * 0.15, 0.04, 0)
		radio.name = "Radio%d" % i
		var aerial := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.012, 0.12, 0.012)
		aerial.mesh = am
		aerial.material_override = Greybox.mat(Color(0.08, 0.08, 0.08))
		aerial.position = Vector3(0.022, 0.14, 0)
		radio.add_child(aerial)
		d.add_child(radio)
		d.add_model(radio)
	d.already = "You already have a walkie-talkie."
	d.taken.connect(d._on_walkie_taken)
	return d


func _on_walkie_taken(peer_id: int) -> void:
	var lvl := _level()
	if not lvl or peer_id != lvl.players.id_of(lvl.player):
		return
	var game := get_node_or_null("/root/Game")
	if game:
		game.has_walkie = true
	if lvl.hud:
		if lvl.sync.is_online():
			lvl.hud.notice("Walkie-talkie clipped on. Hold V to talk on the radio. Up close, just talk.", 6.0)
		else:
			lvl.hud.notice("Picked up a walkie-talkie. Channel 1. Nobody else is on it.", 5.0)
