class_name PryDoors
extends Node3D
## E9 (environment play): a stuck lift's doors, pried apart by two players at
## once. Each takes hold of one door's edge (aim at it, hold E) and holds on;
## when both are held by strong crew (PlayableCrew.STRONG), or either of the two
## carries a crowbar, for PRY_TIME, the doors give: `pried_open` fires on every
## machine and the grips go dead. The stall (Environment puzzles) opens the
## doors on that. Co-op: the host decides; each player holds on on their own
## machine. Build one with make().

## Every machine: they're open.
signal pried_open
## Every machine: who's holding changed (holders), and whether that pair can do it.
signal changed

const PRY_TIME := 2.0
const CROWBAR := "crowbar"
## Augustine approved these words (2026-11-22).
const HOLD := "Hold [E] to pry the door"
const WAITING := "Someone needs to pull the other door."
const WONT_BUDGE := "It won't budge. It takes two strong pairs of hands, or a crowbar."
const PRYING := "Pull!"
## Let go if you're pulled further than this (metres) from your grip.
const REACH := 1.2

## Peer id on each grip (0 for nobody); the same on every machine.
var holders := [0, 0]
## The host says the pair on it now can open it.
var able := false
var opened := false
## Off (the car isn't stuck), its grips offer nothing. ElevatorStall sets it.
var enabled := true:
	set(value):
		enabled = value
		for g in grips:
			_switch(g, value and not opened)
		if not value and not opened and (holders[0] != 0 or holders[1] != 0):
			var sync := LevelSync.of(self) if is_inside_tree() else null
			if sync == null or sync.is_host():
				_crowbar.clear()
				_publish([0, 0])
var grips: Array[PryGrip] = []
## Host: each holder's say on what they carry ({peer: has a crowbar}).
var _crowbar := {}
var _t := 0.0


## Two grips `width` apart across `center` (the gap between the leaves, a metre
## up), facing `out` (toward the people inside). In `parent`'s space.
static func make(parent: Node3D, center: Vector3, out: Vector3, width: float = 0.5) -> PryDoors:
	var d := PryDoors.new()
	d.name = "PryDoors"
	d.position = center
	out = Vector3(out.x, 0, out.z).normalized()
	var across := out.cross(Vector3.UP).normalized()
	parent.add_child(d)
	for i in 2:
		var g := PryGrip.new()
		g.name = "Grip%d" % i
		g.doors = d
		g.index = i
		g.prompt = HOLD
		g.kind = "none"
		g.position = across * (width / 2.0) * (-1.0 if i == 0 else 1.0) + out * 0.05
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.2, 0.5, 0.2)
		shape.shape = bs
		g.add_child(shape)
		d.add_child(g)
		g.add_to_group("interactable")
		d.grips.append(g)
	return d


## A grip on or off. Off, it isn't there at all, so it's never in the doorway of a
## lift that isn't stuck.
static func _switch(g: PryGrip, on: bool) -> void:
	g.enabled = on
	for c in g.get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", not on)


## E9 for a lift that can stick (ElevatorStall): the pry just inside its doors
## and the climb up through its roof hatch, both under the car and linked to the
## stall, so they're on only while it's stuck (the climb once the hatch is open
## too). Returns the pry; the climb is `stall.hatch_climb`.
static func fit(stall: ElevatorStall) -> PryDoors:
	var e := stall.elevator
	var doors := make(e, Vector3(0, 1.0, 0.2), Vector3.BACK, 0.5)
	var rim := stall.hatch_rim()
	var roof := stall.roof_spot()
	var climb := Traversal.hatch(e, e.to_local(rim), ElevatorStall.HATCH.size, e.to_local(roof))
	climb.name = "HatchClimb"
	climb.a = rim
	climb.b = roof
	stall.link_pry(doors)
	stall.link_hatch_climb(climb)
	return doors


## On the machine whose player pressed E on grip `index`: ask to take hold.
func ask_hold(index: int, player: Player) -> void:
	var crowbar: bool = player.inventory != null and player.inventory.has(CROWBAR)
	var sync := LevelSync.of(self)
	if sync and not sync.is_host():
		_ask_hold.rpc_id(1, index, crowbar)
	else:
		_host_hold(_peer_of(player), index, crowbar, player)


## On the machine whose player let go.
func ask_release(player: Player) -> void:
	var sync := LevelSync.of(self)
	if sync and not sync.is_host():
		_ask_release.rpc_id(1)
	else:
		_host_release(_peer_of(player))


@rpc("any_peer", "reliable")
func _ask_hold(index: int, crowbar: bool) -> void:
	_host_hold(multiplayer.get_remote_sender_id(), index, crowbar)


@rpc("any_peer", "reliable")
func _ask_release() -> void:
	_host_release(multiplayer.get_remote_sender_id())


## Bodies for a test's own players, with no co-op session: peer id -> Player.
var _local := {}


func _host_hold(peer: int, index: int, crowbar: bool, body: Player = null) -> void:
	if opened or index < 0 or index > 1 or holders[index] != 0 or holders.has(peer):
		return
	if body:
		_local[peer] = body
	_crowbar[peer] = crowbar
	var h := holders.duplicate()
	h[index] = peer
	_publish(h)


func _host_release(peer: int) -> void:
	var i := holders.find(peer)
	if i < 0:
		return
	_crowbar.erase(peer)
	var h := holders.duplicate()
	h[i] = 0
	_publish(h)


## Host: can these two do it?
func _can_pry(h: Array) -> bool:
	if h[0] == 0 or h[1] == 0:
		return false
	if _crowbar.get(h[0], false) or _crowbar.get(h[1], false):
		return true
	return PlayableCrew.is_strong(_crew_of(h[0])) and PlayableCrew.is_strong(_crew_of(h[1]))


## Who `peer` plays (a PlayableCrew slug): their own body says in a test; in a
## game, their look (the same on every machine).
func _crew_of(peer: int) -> String:
	var body = _local.get(peer)
	if body and str(body.get("crew")) != "":
		return str(body.crew)
	var lvl := _level()
	if lvl:
		return str(NetPlayers.look_for(lvl, peer).get("crew", ""))
	return ""


func _publish(h: Array) -> void:
	var ok := _can_pry(h)
	var sync := LevelSync.of(self)
	if sync:
		sync.run_on(self, "set_holders", [h, ok])
	else:
		set_holders(h, ok)


## Every machine: who holds each grip, and whether they can open it.
func set_holders(h: Array, ok: bool) -> void:
	holders = h.duplicate()
	able = ok
	var me := _my_player()
	for i in 2:
		var who: int = holders[i]
		var body: Player = _local.get(who) if _local.has(who) else (me if me and who == _peer_of(me) else null)
		if body and body.gripping != grips[i]:
			body.take_grip(grips[i])
	if me and me.gripping and me.gripping.doors == self and not holders.has(_peer_of(me)):
		me.drop_grip()
	for who in _local:
		var b: Player = _local[who]
		if is_instance_valid(b) and b.gripping and b.gripping.doors == self and not holders.has(who):
			b.drop_grip()
	changed.emit()


func _physics_process(delta: float) -> void:
	if opened:
		return
	var sync := LevelSync.of(self)
	if sync and not sync.is_host():
		return
	_t = _t + delta if enabled and able and holders[0] != 0 and holders[1] != 0 else 0.0
	if _t >= PRY_TIME:
		_t = 0.0
		if sync:
			sync.run_on(self, "pried")
		else:
			pried()


## Every machine: the doors gave.
func pried() -> void:
	if opened:
		return
	opened = true
	set_holders([0, 0], false)
	for g in grips:
		_switch(g, false)
	pried_open.emit()


## What a player on (or looking at) grip `index` sees.
func prompt_for(index: int, player: Node) -> String:
	if opened:
		return ""
	var me: int = _peer_of(player)
	if holders[index] == me and me != 0 or (player is Player and (player as Player).gripping == grips[index]):
		if holders[1 - index] == 0:
			return WAITING
		return PRYING if able else WONT_BUDGE
	if holders[index] != 0:
		return ""
	return HOLD


func _peer_of(player: Node) -> int:
	var lvl := _level()
	if lvl and lvl.get("players"):
		return lvl.players.id_of(player)
	for k in _local:
		if _local[k] == player:
			return k
	return player.get_instance_id() if player else 0


func _my_player() -> Player:
	var lvl := _level()
	return lvl.player as Player if lvl and lvl.get("player") is Player else null


## The level this is in (it has the players). Duck-typed, like ItemDock._level.
func _level() -> Node:
	var n := get_parent()
	while n and n.get("players") == null:
		n = n.get_parent()
	return n
