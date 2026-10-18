class_name StickyNote
extends Interactable
## A sticky note with one piece of SQL on it (see StickyNotes). A loose note is taken
## by whoever picks it up. A note stuck to a terminal stays put, and anyone can copy
## it into their notebook.

signal taken(player: Node)

## A note lying on a desk is drawn this much bigger than a real one, so it reads
## from where you stand.
const DESK_SCALE := 1.5

var note_id := ""
## Stuck to a terminal: copied, not taken.
var on_terminal := false


## Stick a note on a terminal's monitor, bottom-left of the screen.
## Taped to the top-right of the CRT's bezel (TerminalScreen), hanging off the
## case's edge rather than over the glass, so it never covers the screen's text
## (which runs from the left).
static func on_monitor(terminal: Node3D, id: String) -> StickyNote:
	return place(terminal, Vector3(0.232, 0.335, 0.195), id, true)


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
	bs.size = Vector3(0.14, 0.14, 0.16) if not flat else Vector3(0.18, 0.06, 0.18)
	shape.shape = bs
	shape.position.z = 0.07 if not flat else 0.0
	n.add_child(shape)
	# The look: ArtProps faces -Z, so turn it to face out of the monitor or desk.
	var art := ArtProps.sticky_note(n, Vector3.ZERO, 180.0, StickyNotes.get_note(id).get("label", ""), ArtProps.STICKY_YELLOW, flat)
	if flat:
		art.scale = Vector3.ONE * DESK_SCALE  # read from standing height, not leaning over the desk
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
			_file(player)
		taken.emit(player)
		return
	# A loose note: the host decides who got it, gives it to them, and removes
	# it on every machine. Only the taker's machine has their notebook.
	var sync := LevelSync.of(self)
	if sync == null:
		_file(player)
		_remove()
		return
	var players: Node = sync.level.get("players")
	var id: int = players.id_of(player) if players else multiplayer.get_unique_id()
	if id == multiplayer.get_unique_id():
		_file(player)
	elif id != 0:
		_give.rpc_id(id)
	sync.run_on(self, "_remove")


## The taker's machine: the note goes in their notebook.
@rpc("authority", "reliable")
func _give() -> void:
	var level := _level()
	_file(level.player if level else null)


## Into the notebook. Held in your hands (Game.diegetic_ui), you watch it go onto
## the page first (player.file_into_notebook), and it's written down when it lands;
## a note on a terminal stays where it is and a copy goes in.
func _file(player: Node) -> void:
	if not (get_node("/root/Game").diegetic_ui and player and player.has_method("file_into_notebook")):
		_write_down()
		return
	var level := _level()
	if level and level.get("notebook") and not level.notebook.is_open():
		level.notebook.open(NotebookPages.Page.NOTES)  # open at the page it goes on
	if not player.file_into_notebook(self, on_terminal):
		_write_down()  # hands busy: it still goes in
		return
	# The note itself may be gone by the time it lands (a loose one is removed at
	# once), so what's written down doesn't depend on it.
	var id := note_id
	var hud = _level().hud if _level() else null
	var game := get_node("/root/Game")
	player.sticky_filed.connect(func(_p): StickyNote.write_down(game, hud, id), CONNECT_ONE_SHOT)


## Every machine: the note is gone. While it's still flying onto the taker's
## notebook page it's only hidden, and freed once it lands.
func _remove() -> void:
	taken.emit(null)
	remove_from_group("interactable")
	visible = false
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	var level := _level()
	var p: Node = level.player if level else null
	if p and p.has_method("is_filing") and p.is_filing() and p.has_signal("sticky_filed"):
		p.sticky_filed.connect(func(_n): queue_free(), CONNECT_ONE_SHOT)
	else:
		queue_free()


func _write_down() -> void:
	var level := _level()
	StickyNote.write_down(get_node("/root/Game"), level.hud if level else null, note_id)


## Note `id` goes in this machine's notebook, with a notice on `hud`.
static func write_down(game: Node, hud: Node, id: String) -> void:
	var title: String = StickyNotes.get_note(id).get("title", "")
	if game.add_note(id) and hud:
		hud.notice("Added to your notebook (Tab): %s" % title, 4.0)


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
