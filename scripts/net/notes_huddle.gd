class_name NotesHuddle
extends Node
## Crewmates swap notebook notes face to face. Press E on a crewmate to huddle
## up; anyone can join by pressing E on someone already in the huddle. Inside,
## each line on your case pages and each sticky note can be shared with the
## others in the huddle, one line, one case or every case at once. Shared lines
## land on the same case page in their notebooks, so the crew fills in each
## other's blanks.
##
## The host keeps the huddles, so every machine agrees who is in which. Walking
## away (LEAVE_DISTANCE from everyone else in it) or pressing Leave takes you
## out. The notes themselves go straight to the others in your huddle.

signal changed

const LEAVE_DISTANCE := 4.0
const CHECK_EVERY := 0.5

var sync: LevelSync
## huddle id -> member peer ids, the same on every machine.
var groups := {}
## Lines already shared with this huddle (text -> true), so their chips say so.
## Cleared whenever someone joins or leaves.
var sent := {}
var _next_id := 1
var _check_t := 0.0
## This player pressed E on someone and is waiting to be put in their huddle.
var _asked := false


static func create(for_sync: LevelSync) -> NotesHuddle:
	var h := NotesHuddle.new()
	h.name = "NotesHuddle"
	h.sync = for_sync
	for_sync.add_child(h)
	return h


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_left)


func _me() -> int:
	return multiplayer.get_unique_id()


## The huddle `peer` is in, or 0.
func group_of(peer: int) -> int:
	for g in groups:
		if groups[g].has(peer):
			return g
	return 0


## Everyone in `peer`'s huddle, them included; empty if they're in none.
func members(peer: int) -> Array:
	return groups.get(group_of(peer), [])


func in_huddle() -> bool:
	return group_of(_me()) != 0


## The others in this player's huddle.
func others() -> Array:
	return members(_me()).filter(func(id): return id != _me())


func name_of(peer: int) -> String:
	var players = sync.level.get("players")
	var body = players.puppet(peer) if players else null
	if body is PlayerPuppet:
		return body.display_name
	var net := get_node_or_null("/root/Net")
	return net.display_name(peer) if net else "Player %d" % peer


# --- Joining and leaving ------------------------------------------------------

## This player pressed E on `peer`: huddle up with them, or join theirs.
func huddle_with(peer: int) -> void:
	_asked = true
	if sync.is_host():
		_join(_me(), peer)
	else:
		_ask_join.rpc_id(1, peer)


## Step out of the huddle.
func leave() -> void:
	if sync.is_host():
		_remove(_me())
		_publish()
	else:
		_ask_leave.rpc_id(1)


@rpc("any_peer", "reliable")
func _ask_join(peer: int) -> void:
	if sync.is_host():
		_join(multiplayer.get_remote_sender_id(), peer)


@rpc("any_peer", "reliable")
func _ask_leave() -> void:
	if sync.is_host():
		_remove(multiplayer.get_remote_sender_id())
		_publish()


func _join(who: int, with_peer: int) -> void:
	var ids: Array = NetPlayers.ids_for(multiplayer)
	if who == with_peer or not ids.has(who) or not ids.has(with_peer):
		return
	var g := group_of(with_peer)
	if g != 0 and g == group_of(who):
		return
	_remove(who)
	if g == 0:
		g = _next_id
		_next_id += 1
		groups[g] = [with_peer]
	groups[g].append(who)
	_publish()


func _remove(peer: int) -> void:
	var g := group_of(peer)
	if g == 0:
		return
	groups[g].erase(peer)
	if groups[g].size() < 2:
		groups.erase(g)


func _publish() -> void:
	_set_groups.rpc(groups)


@rpc("authority", "call_local", "reliable")
func _set_groups(new_groups: Dictionary) -> void:
	var before := members(_me())
	groups = new_groups
	var after := members(_me())
	if before != after:
		sent.clear()
	changed.emit()
	_tell(before, after)


## Say who came and went, and open the notebook for whoever asked to huddle.
func _tell(before: Array, after: Array) -> void:
	var hud = sync.level.get("hud")
	var asked := _asked
	if not after.is_empty():
		_asked = false
	if after.is_empty():
		if not before.is_empty() and hud:
			hud.notice("You left the notes huddle.", 3.0)
		return
	if before.is_empty():
		var names := ", ".join(others().map(name_of))
		if hud:
			hud.notice("Notes huddle with %s. Tab to share notes." % names, 4.0)
		var notebook = sync.level.get("notebook")
		if asked and notebook and not notebook.is_open():
			notebook.open(NotebookPages.Page.CASES)
		return
	for id in after:
		if not before.has(id) and hud:
			hud.notice("%s joined the notes huddle." % name_of(id), 3.0)
	for id in before:
		if not after.has(id) and hud:
			hud.notice("%s left the notes huddle." % name_of(id), 3.0)


## The host takes out anyone who has walked away from the rest of their huddle.
func _process(delta: float) -> void:
	if groups.is_empty() or not sync.is_host():
		return
	_check_t += delta
	if _check_t < CHECK_EVERY:
		return
	_check_t = 0.0
	var players = sync.level.get("players")
	if players == null:
		return
	var gone := []
	for g in groups:
		for id in groups[g]:
			var body: Node3D = players.puppet(id)
			if body == null:
				continue
			var near := false
			for other in groups[g]:
				var b: Node3D = players.puppet(other)
				if other != id and b and b.global_position.distance_to(body.global_position) <= LEAVE_DISTANCE:
					near = true
			if not near:
				gone.append(id)
	for id in gone:
		_remove(id)
	if not gone.is_empty():
		_publish()


func _on_peer_left(id: int) -> void:
	if sync.is_host() and group_of(id) != 0:
		_remove(id)
		_publish()


# --- Sharing ------------------------------------------------------------------

## A line on a case page: a clue (`from` is where it was read) or a note the
## player wrote or copied (`entry` from Game.notebook_written).
static func clue_item(c: Dictionary, text: String, from: String) -> Dictionary:
	return {"kind": "clue", "case": c.id, "title": c.title, "tables": c.tables, "text": text, "from": from}


static func note_item(game: Node, w: Dictionary) -> Dictionary:
	var c: Dictionary = game.case_info(w.get("case", ""))
	return {"kind": "note", "case": c.get("id", ""), "title": c.get("title", ""), "tables": c.get("tables", []),
		"text": w.text, "label": w.label, "note_kind": w.kind}


static func sticky_item(id: String) -> Dictionary:
	return {"kind": "sticky", "id": id, "text": id}


## Everything on one case page.
static func case_items(game: Node, case_id: String) -> Array:
	var c: Dictionary = game.case_info(case_id)
	if c.is_empty():
		return []
	var out := []
	for k in c.clues:
		out.append(clue_item(c, k.text, k.from))
	for w in game.notebook_written:
		if w.get("case", "") == case_id:
			out.append(note_item(game, w))
	return out


## Every open case page, the notes under none, and the sticky notes.
static func all_items(game: Node) -> Array:
	var out := []
	var open := {}
	for c in game.notebook_cases:
		if c.open:
			open[c.id] = true
			out.append_array(case_items(game, c.id))
	for w in game.notebook_written:
		if not open.has(w.get("case", "")):
			out.append(note_item(game, w))
	for id in game.notebook_notes:
		out.append(sticky_item(id))
	return out


## Send `items` to everyone else in this player's huddle.
func share(items: Array) -> void:
	if items.is_empty() or not in_huddle():
		return
	for it in items:
		sent[it.text] = true
	for peer in others():
		_receive.rpc_id(peer, items)


func was_sent(text: String) -> bool:
	return sent.has(text)


@rpc("any_peer", "reliable")
func _receive(items: Array) -> void:
	var from := multiplayer.get_remote_sender_id()
	if not members(_me()).has(from):
		return
	var who := name_of(from)
	var game := get_node("/root/Game")
	var added := 0
	for it in items:
		if take(game, it, who):
			added += 1
	var hud = sync.level.get("hud")
	if hud and added > 0:
		hud.notice("%s shared %d note%s with you." % [who, added, "" if added == 1 else "s"], 3.0)


## Put one shared item into this player's notebook. False if they had it already.
static func take(game: Node, it: Dictionary, who: String) -> bool:
	if it.kind == "sticky":
		return game.add_note(it.id)
	var case_id: String = it.get("case", "")
	for w in game.notebook_written:
		if w.text == it.text and w.get("case", "") == case_id:
			return false
	var from: String
	if it.kind == "clue":
		from = "%s (from %s)" % [it.from, who]
	elif it.note_kind == "mine" or it.label == "":
		from = "%s's note" % who
	else:
		from = "%s (from %s)" % [it.label, who]
	if case_id == "":
		for w in game.notebook_written:
			if w.text == it.text:
				return false
		game.write_note(from, it.text, "shared")
		return true
	if not game.case_info(case_id).get("open", false):
		game.open_case(case_id, it.title, it.tables)
	return game.add_clue(case_id, it.text, from)
