class_name FirstAidCabinet
extends Interactable
## The first-aid cabinet on STAIR 1's landing 5 (plan/approvals/stair-landings.md,
## C): sealed shut, E breaks the seal and opens it, E again takes the one kit in
## it. Whoever takes the kit carries it (Inventory "first_aid_kit"); in their hands,
## it patches them up (attack) or brings a downed teammate straight round (E on
## them, see teammate_prompt and patch).
##
## It's the same cabinet whichever trip passes landing 5 (down from 10, up from G),
## so what's happened to it belongs to the run (Game.first_aid), not to this node.
## Co-op: the host decides, every machine plays it out, and only the taker gets the kit.

const ITEM := "first_aid_kit"
## Lines approved by Augustine, 2026-11-05 ("approve all"), word for word.
const STICKER := "FIRST AID.\nBREAK SEAL IN AN EMERGENCY."
const OPEN_PROMPT := "Open the first-aid cabinet"
const TAKE_PROMPT := "Take the first-aid kit"
const EMPTY := "Empty. Someone's already taken the kit."
const PATCH_PROMPT := "[E] Patch them up with the first-aid kit"
const PATCHED_SELF := "Patched up. The kit's used up."
const PATCHED_THEM := "You patched up %s. The kit's used up."
const PATCHED_YOU := "%s patched you up."
## Game.first_aid: still sealed (""), opened, or the kit taken.
const SEALED := ""
const OPENED := "open"
const TAKEN := "taken"
const SIZE := Vector3(0.42, 0.52, 0.15)

var _door: Node3D
var _seal: Node3D
var _kit: Node3D


## A cabinet whose back is on a wall, its front (local +Z) facing out, centred at
## `pos` in `parent`'s space; `facing_deg` turns its front.
static func make(pos: Vector3, facing_deg: float) -> FirstAidCabinet:
	var c := FirstAidCabinet.new()
	c.name = "FirstAidCabinet"
	c.position = pos
	c.rotation_degrees.y = facing_deg
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = SIZE
	shape.shape = bs
	c.add_child(shape)
	c._build()
	c.add_to_group("interactable")
	c.used.connect(c._on_used)
	return c


func _build() -> void:
	var white := Greybox.mat(Color(0.9, 0.9, 0.87), 0.0, 0.6)
	var green := Greybox.mat(Color(0.1, 0.55, 0.25))
	# The box: back, sides, top and bottom, open at the front.
	var t := 0.015
	_part(self, Vector3(SIZE.x, SIZE.y, t), Vector3(0, 0, -SIZE.z / 2.0 + t / 2.0), white, "Back")
	for sx in [-1.0, 1.0]:
		_part(self, Vector3(t, SIZE.y, SIZE.z), Vector3(sx * (SIZE.x - t) / 2.0, 0, 0), white, "Side")
	for sy in [-1.0, 1.0]:
		_part(self, Vector3(SIZE.x, t, SIZE.z), Vector3(0, sy * (SIZE.y - t) / 2.0, 0), white, "Lid")
	_part(self, Vector3(SIZE.x - 2 * t, t, SIZE.z - t), Vector3(0, 0, 0), white, "Shelf")
	# The kit on the shelf: a red-cross pouch.
	_kit = Node3D.new()
	_kit.name = "Kit"
	add_child(_kit)
	_part(_kit, Vector3(0.24, 0.14, 0.09), Vector3(0, 0.08, -0.01), Greybox.mat(Color(0.75, 0.12, 0.1)), "Pouch")
	_part(_kit, Vector3(0.1, 0.03, 0.005), Vector3(0, 0.08, 0.037), Greybox.mat(Color(0.95, 0.95, 0.95)), "CrossH")
	_part(_kit, Vector3(0.03, 0.1, 0.005), Vector3(0, 0.08, 0.037), Greybox.mat(Color(0.95, 0.95, 0.95)), "CrossV")
	# The door, hinged on its left edge, with the green cross and the sticker.
	_door = Node3D.new()
	_door.name = "Door"
	_door.position = Vector3(-SIZE.x / 2.0, 0, SIZE.z / 2.0)
	add_child(_door)
	_part(_door, Vector3(SIZE.x, SIZE.y, 0.015), Vector3(SIZE.x / 2.0, 0, 0.0075), white, "Panel")
	_part(_door, Vector3(0.16, 0.05, 0.004), Vector3(SIZE.x / 2.0, 0.1, 0.017), green, "CrossH")
	_part(_door, Vector3(0.05, 0.16, 0.004), Vector3(SIZE.x / 2.0, 0.1, 0.017), green, "CrossV")
	var sticker := Label3D.new()
	sticker.name = "Sticker"
	sticker.text = STICKER
	sticker.font_size = 36
	sticker.pixel_size = 0.0011
	sticker.modulate = Color(0.08, 0.3, 0.14)
	sticker.outline_size = 0
	sticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sticker.position = Vector3(SIZE.x / 2.0, -0.12, 0.0165)
	_door.add_child(sticker)
	# The seal: a red plastic tag across the door's free edge.
	_seal = _part(self, Vector3(0.012, 0.06, 0.03), Vector3(SIZE.x / 2.0, -0.02, SIZE.z / 2.0 + 0.005), Greybox.mat(Color(0.85, 0.08, 0.06)), "Seal")
	refresh()


static func _part(parent: Node3D, size: Vector3, pos: Vector3, m: Material, part_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi, true)
	return mi


static func _game() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("Game") if loop else null


## What's happened to the cabinet this run.
static func state() -> String:
	var g := _game()
	if g == null:
		return SEALED
	return str(g.get("first_aid"))


static func _set_state(s: String) -> void:
	var g := _game()
	if g:
		g.set("first_aid", s)


## Door, seal and kit as the run has left them (the other trip may have opened it).
func refresh() -> void:
	var s := state()
	if _door:
		_door.rotation_degrees.y = 0.0 if s == SEALED else -105.0
		_seal.visible = s == SEALED
		_kit.visible = s != TAKEN


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		refresh()


func get_prompt(_player: Node) -> String:
	match state():
		SEALED:
			return "[E] " + OPEN_PROMPT
		OPENED:
			return "[E] " + TAKE_PROMPT
	return EMPTY


func interact(player: Node) -> void:
	if state() != TAKEN:
		super.interact(player)


## Host: someone pressed E on it: it opens, or (once it's open) they take the kit.
func _on_used(player: Node) -> void:
	var lvl := _level()
	var id: int = lvl.players.id_of(player) if lvl else 0
	var next := OPENED if state() == SEALED else TAKEN
	var sync := LevelSync.of(self)
	if sync:
		sync.run_on(self, "advance", [id, next])
	else:
		advance(id, next)


## On every machine: `peer_id` opened it (`next` OPENED) or took the kit (TAKEN).
func advance(peer_id: int, next: String) -> void:
	_set_state(next)
	if next == TAKEN:
		var lvl := _level()
		if lvl and lvl.player and peer_id == lvl.players.id_of(lvl.player):
			lvl.player.inventory.add(ITEM)
	refresh()


## The level this is in (it has the players), like ItemDock._level.
func _level() -> Node:
	var n := get_parent()
	while n and n.get("players") == null:
		n = n.get_parent()
	return n


# --- Using the kit -------------------------------------------------------------

## The kit is in `player`'s hands.
static func holding(player: Node) -> bool:
	var inv = player.get("inventory") if player else null
	return inv != null and inv.active_item() == ITEM


## Attack with the kit in your hands: patch yourself up. True if the kit was in
## your hands (it does nothing else, even at full health: no swinging it at people).
static func use_on_self(player: Node) -> bool:
	if not holding(player):
		return false
	var combat: PlayerCombat = player.get("combat")
	if combat == null or combat.down or float(player.get("health")) >= PlayerCombat.MAX_HEALTH:
		return true
	combat.heal_full()
	player.inventory.remove(ITEM)
	var hud: Node = player.get("hud")
	if hud:
		hud.notice(PATCHED_SELF, 3.0)
	return true


## E on downed teammate `id`, with the kit in `by`'s hands: the kit's prompt in
## place of the usual hand up (one key can't do both); otherwise the usual.
static func teammate_prompt(by: Node, crew: CrewVitals, id: int) -> String:
	if holding(by) and crew.downed.has(id) and not CrewVitals.is_down(by):
		return PATCH_PROMPT
	return crew.revive_prompt(id)


## E on downed teammate `id` with the kit in `by`'s hands: up at once, to full
## health, even if they've passed out. False (do the usual) without the kit.
static func patch(by: Node, crew: CrewVitals, id: int) -> bool:
	if not holding(by) or not crew.downed.has(id):
		return false
	crew.revive(id, PlayerCombat.MAX_HEALTH, true)
	return true


## On every machine, once the host has brought `id` round with `by`'s kit: the kit
## is used up, and both of them hear who patched up whom.
static func patched(crew: CrewVitals, id: int, by: int) -> void:
	var me := crew.my_id()
	var player: Node = crew.players.player if crew.players else null
	if player == null:
		return
	var hud: Node = player.get("hud")
	if by == me:
		player.inventory.remove(ITEM)
		if hud:
			hud.notice(PATCHED_THEM % _name(crew, id), 4.0)
	elif id == me and hud:
		hud.notice(PATCHED_YOU % _name(crew, by), 4.0)


static func _name(crew: CrewVitals, id: int) -> String:
	var net := crew.get_node_or_null("/root/Net")
	return net.display_name(id) if net else "Player"
