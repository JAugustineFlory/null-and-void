class_name StickyNote
extends Interactable
## A sticky note with one piece of SQL on it (see StickyNotes). A loose note is taken
## by whoever picks it up. A note stuck to a terminal stays put, and anyone can copy
## it into their notebook.

signal taken(player: Node)

var note_id := ""
## Stuck to a terminal: copied, not taken.
var on_terminal := false


## Stick a note on a terminal's monitor, bottom-left of the screen.
static func on_monitor(terminal: Node3D, id: String) -> StickyNote:
	return place(terminal, Vector3(-0.17, 0.09, 0.237), id, true)


static func place(parent: Node, pos: Vector3, id: String, stuck_to_terminal: bool, facing_deg: float = 0.0, flat: bool = false) -> StickyNote:
	var n := StickyNote.new()
	n.note_id = id
	n.on_terminal = stuck_to_terminal
	n.prompt = "Copy the sticky note into your notebook" if stuck_to_terminal else "Take the sticky note"
	# Copying is each player's own business; taking a loose note is decided by the host.
	n.local_only = stuck_to_terminal
	n.position = pos
	n.rotation_degrees.y = facing_deg
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# Bigger than the paper and pushed forward, so it's easy to aim at and wins
	# over a terminal behind it.
	bs.size = Vector3(0.14, 0.14, 0.16) if not flat else Vector3(0.14, 0.06, 0.14)
	shape.shape = bs
	shape.position.z = 0.07 if not flat else 0.0
	n.add_child(shape)
	# The look: ArtProps faces -Z, so turn it to face out of the monitor or desk.
	ArtProps.sticky_note(n, Vector3.ZERO, 180.0, StickyNotes.get_note(id).get("label", ""), ArtProps.STICKY_YELLOW, flat)
	parent.add_child(n)
	n.add_to_group("interactable")
	n.used.connect(n._on_used)
	return n


func get_prompt(player: Node) -> String:
	if on_terminal and _is_local(player) and get_node("/root/Game").notebook_notes.has(note_id):
		return ""
	return super(player)


func _on_used(player: Node) -> void:
	if on_terminal:
		if _is_local(player):
			_write_down()
		taken.emit(player)
		return
	# A loose note: the host decides who got it, gives it to them, and removes
	# it on every machine. Only the taker's machine has their notebook.
	var sync := LevelSync.of(self)
	if sync == null:
		_write_down()
		_remove()
		return
	var players: Node = sync.level.get("players")
	var id: int = players.id_of(player) if players else multiplayer.get_unique_id()
	if id == multiplayer.get_unique_id():
		_write_down()
	elif id != 0:
		_give.rpc_id(id)
	sync.run_on(self, "_remove")


## The taker's machine: the note goes in their notebook.
@rpc("authority", "reliable")
func _give() -> void:
	_write_down()


## Every machine: the note is gone.
func _remove() -> void:
	taken.emit(null)
	queue_free()


func _write_down() -> void:
	var title: String = StickyNotes.get_note(note_id).get("title", "")
	var level := _level()
	if get_node("/root/Game").add_note(note_id) and level and level.hud:
		level.hud.notice("Added to your notebook (Tab): %s" % title, 4.0)


## Only the local player's pickups go in this machine's notebook.
func _is_local(player: Node) -> bool:
	var level := _level()
	return level == null or level.player == null or player == level.player


## The level this note is in. Duck-typed: naming LevelBase here would pull the Game
## autoload into the test runner at parse time.
func _level() -> Node:
	var n := get_parent()
	while n and not n.has_method("finish_level"):
		n = n.get_parent()
	return n
