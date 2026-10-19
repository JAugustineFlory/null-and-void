class_name TerminalMirror
extends Node
## Keeps every terminal's screen the same on every machine, so teammates can
## read over each other's shoulders: who is seated, the line they are typing,
## and the lines a terminal prints for its own commands (.help, .hint, .clear).
## Query results already reach every screen through LevelSync.
##
## Seats, lines and clears go through the host, so every machine gets them in
## the same order as query results. The typed line is sent to the other
## players at most TYPING_RATE times a second.

const TYPING_RATE := 10.0
const MAX_TYPED := 512

var sync: LevelSync
## Typed text waiting to be sent: terminal path -> text.
var _pending_typing := {}
var _since_typing_sent := 0.0


static func create(for_sync: LevelSync) -> TerminalMirror:
	var m := TerminalMirror.new()
	m.name = "TerminalMirror"
	m.sync = for_sync
	for_sync.add_child(m)
	return m


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_left)


func _level() -> Node:
	return sync.level


func _me() -> int:
	return multiplayer.get_unique_id()


# --- Seats -------------------------------------------------------------------

## This player sat down at `terminal` (on) or stepped away (off).
func seat(terminal: Node, on: bool) -> void:
	var path := _level().get_path_to(terminal)
	if not on:
		_stop_typing(path)
	if sync.is_host():
		_set_seat.rpc(path, _me(), on)
	else:
		_request_seat.rpc_id(1, path, on)


@rpc("any_peer", "reliable")
func _request_seat(path: NodePath, on: bool) -> void:
	if sync.is_host():
		_set_seat.rpc(path, multiplayer.get_remote_sender_id(), on)


@rpc("authority", "call_local", "reliable")
func _set_seat(path: NodePath, peer: int, on: bool) -> void:
	var terminal := _level().get_node_or_null(path)
	if terminal == null:
		return
	if on:
		terminal.ensure_booted()
		if not terminal.seated.has(peer):
			terminal.seated.append(peer)
	else:
		terminal.seated.erase(peer)
		terminal.typing.erase(peer)
	_place_puppets(terminal)
	terminal.screen_changed.emit()


## Teammates at `terminal` lean in from its sides; anyone who left stands up.
func _place_puppets(terminal: Node) -> void:
	var players = _level().get("players")
	if players == null:
		return
	for p in players.all_players():
		if p is PlayerPuppet:
			if terminal.seated.has(p.peer_id):
				p.sit_at(terminal, terminal.seated.find(p.peer_id))
			elif p.at_terminal == terminal:
				p.sit_at(null)


func _on_peer_left(id: int) -> void:
	for terminal in _terminals():
		if terminal.seated.has(id) or terminal.typing.has(id):
			terminal.seated.erase(id)
			terminal.typing.erase(id)
			terminal.screen_changed.emit()


func _terminals() -> Array:
	return _level().find_children("*", "", true, false).filter(func(n): return n is Terminal)


# --- The typed line ----------------------------------------------------------

## This player's input line at `terminal` now reads `text`.
func typed(terminal: Node, text: String) -> void:
	text = text.left(MAX_TYPED)
	if terminal.typing.get(_me(), "") == text:
		return
	terminal.typing[_me()] = text
	terminal.screen_changed.emit()
	if sync.is_online():
		_pending_typing[_level().get_path_to(terminal)] = text


func _process(delta: float) -> void:
	_since_typing_sent += delta
	if _pending_typing.is_empty() or _since_typing_sent < 1.0 / TYPING_RATE:
		return
	_since_typing_sent = 0.0
	for path in _pending_typing:
		_show_typing.rpc(path, _pending_typing[path])
	_pending_typing.clear()


## Clear this player's typed line everywhere (on submit or stepping away).
func _stop_typing(path: NodePath) -> void:
	_pending_typing.erase(path)
	var terminal := _level().get_node_or_null(path)
	if terminal:
		terminal.typing.erase(_me())
		terminal.screen_changed.emit()
	if sync.is_online():
		_clear_typing.rpc(path)


## Typing is cleared when a line is submitted.
func submitted(terminal: Node) -> void:
	_stop_typing(_level().get_path_to(terminal))


# Reliable, so a stale line can never land after the clear that follows it.
@rpc("any_peer", "reliable")
func _show_typing(path: NodePath, text: String) -> void:
	var terminal := _level().get_node_or_null(path)
	var peer := multiplayer.get_remote_sender_id()
	if terminal == null or not terminal.seated.has(peer):
		return
	terminal.typing[peer] = text.left(MAX_TYPED)
	terminal.screen_changed.emit()


@rpc("any_peer", "reliable")
func _clear_typing(path: NodePath) -> void:
	var terminal := _level().get_node_or_null(path)
	if terminal and terminal.typing.erase(multiplayer.get_remote_sender_id()):
		terminal.screen_changed.emit()


# --- Lines and clears --------------------------------------------------------

## Print a line on every copy of `terminal`'s screen.
func line(terminal: Node, bbcode: String, kind: String = "") -> void:
	var path := _level().get_path_to(terminal)
	if sync.is_host():
		_print.rpc(path, bbcode, kind)
	else:
		_request_print.rpc_id(1, path, bbcode, kind)


@rpc("any_peer", "reliable")
func _request_print(path: NodePath, bbcode: String, kind: String) -> void:
	if sync.is_host():
		_print.rpc(path, bbcode, kind)


@rpc("authority", "call_local", "reliable")
func _print(path: NodePath, bbcode: String, kind: String) -> void:
	var terminal := _level().get_node_or_null(path)
	if terminal:
		terminal.print_line(bbcode, kind)


## Wipe `terminal`'s screen on every machine.
func clear(terminal: Node) -> void:
	var path := _level().get_path_to(terminal)
	if sync.is_host():
		_clear.rpc(path)
	else:
		_request_clear.rpc_id(1, path)


@rpc("any_peer", "reliable")
func _request_clear(path: NodePath) -> void:
	if sync.is_host():
		_clear.rpc(path)


@rpc("authority", "call_local", "reliable")
func _clear(path: NodePath) -> void:
	var terminal := _level().get_node_or_null(path)
	if terminal:
		terminal.clear_screen()
