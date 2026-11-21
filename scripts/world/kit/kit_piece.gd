class_name KitPiece
extends Interactable
## The base of the environment kit (plan/environment-play.md, E3-E6): things players
## fix, jam, plug in or carry. Code stays the floor's gate; these open other routes,
## gear and secrets. Floor builders place the pieces (see scripts/world/kit/README.md).
##
## Co-op: each machine keeps its own player's inventory, so a press carries what the
## presser holds (`hand_of`) to the host. The host decides (`decide`) and every machine
## plays it out (`play`), where only the presser's machine changes its inventory.
## A piece never emits `used`: it plays its own sound, where it is, on every machine
## (`_sound`, which also fires `touched` for the hands).

## Anything the presser carries that the decision needs, as plain data.
static func hand_of(player: Node) -> Dictionary:
	var inv = player.get("inventory") if player else null
	var lvl := level_of(player) if player else null
	return {
		"peer": lvl.players.id_of(player) if lvl and lvl.players else 0,
		"items": Array(inv.items) if inv else [],
		"held": inv.active_item() if inv else "",
	}


## There's a free hand for `item` in `hand` (see Inventory.room_for).
static func has_room(hand: Dictionary, item: String) -> bool:
	var items: Array = hand.get("items", [])
	return not items.has(item) and (not Inventory.GEAR.has(item) or Inventory.gear_count(items) < Inventory.MAX_GEAR)


static func carries(hand: Dictionary, item: String) -> bool:
	return (hand.get("items", []) as Array).has(item)


## The level `node` is in: the one with the players. Duck-typed, like ItemDock._level.
static func level_of(node: Node) -> Node:
	var n := node.get_parent() if node else null
	while n and n.get("players") == null:
		n = n.get_parent()
	return n


## What it says to this player: "" for nothing. `can_use` false shows it without [E].
func prompt_for(_hand: Dictionary) -> String:
	return prompt


func can_use(_hand: Dictionary) -> bool:
	return true


## Host: what pressing it does, for player `peer` holding `hand`. Calls `play`.
func decide(_peer: int, _hand: Dictionary) -> void:
	pass


func get_prompt(player: Node) -> String:
	_seen_shining(player)
	if not enabled:
		return ""
	var hand := hand_of(player)
	var p := prompt_for(hand)
	if p == "":
		return ""
	return "[E] " + p if can_use(hand) else p


func interact(player: Node) -> void:
	if not enabled:
		return
	var hand := hand_of(player)
	if not can_use(hand):
		return
	var sync := LevelSync.of(self)
	if sync and sync.forward_args(self, "report_use", [hand]):
		return
	report_use(player, hand)


## Host: a player pressed it, holding `hand`.
func report_use(player: Node, hand: Dictionary) -> void:
	if enabled and can_use(hand):
		decide(_peer_of(player), hand)


## Host: run `method(args)` on this piece on every machine (only here, offline).
func play(method: StringName, args: Array = []) -> void:
	var sync := LevelSync.of(self)
	if sync and sync.level and sync.level.is_ancestor_of(self):
		sync.run_on(self, method, args)
	else:
		callv(method, args)


# --- On every machine ---------------------------------------------------------

## True on the machine of player `peer`: the one whose inventory changes.
func is_mine(peer: int) -> bool:
	var lvl := level_of(self)
	return lvl == null or lvl.players == null or lvl.players.id_of(lvl.player) == peer


## The local player's inventory if `peer` is the local player, else null.
func inventory_of(peer: int) -> Inventory:
	var lvl := level_of(self)
	if lvl == null or not is_mine(peer) or lvl.get("player") == null:
		return null
	return lvl.player.inventory


func _give(peer: int, item: String) -> void:
	var inv := inventory_of(peer)
	if inv:
		inv.add(item)


func _take(peer: int, item: String) -> void:
	var inv := inventory_of(peer)
	if inv:
		inv.remove(item)


## A notice for player `peer` only.
func _tell(peer: int, text: String, seconds := 3.0) -> void:
	var lvl := level_of(self)
	if lvl and is_mine(peer) and lvl.get("hud"):
		lvl.hud.notice(text, seconds)


## `sound` where it is, and the hands' cue for player `peer`.
func _sound(peer: int, sound: String) -> void:
	touched.emit(peer)
	var parent := get_parent()
	if parent is Node3D and is_inside_tree():
		Sfx.play(parent, sound, position)


func _peer_of(player: Node) -> int:
	var sync := LevelSync.of(self)
	if sync:
		return sync.peer_of(player)
	var lvl := level_of(self)
	return lvl.players.id_of(player) if lvl and lvl.players else 0


## An aim box for a piece, `size` big, centred on it.
func _shape(size: Vector3, at := Vector3.ZERO) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.position = at
	add_child(shape)
	return shape


static func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = Greybox.mat(color, emission)
	m.position = at
	parent.add_child(m)
	return m


## Picks one of `count` choices for `key` from this run's seed (Game.run_seed), so
## each run puts gear and faults somewhere else, the same on every machine.
static func seeded(key: String, count: int) -> int:
	if count <= 1:
		return 0
	var tree := Engine.get_main_loop() as SceneTree
	var game := tree.root.get_node_or_null("Game") if tree else null
	var run_seed: int = game.run_seed if game else 0
	return absi(hash("%d|%s" % [run_seed, key])) % count
