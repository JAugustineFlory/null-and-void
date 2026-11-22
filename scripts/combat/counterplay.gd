class_name Counterplay
extends Node
## Fighting back without fists (E7, plan/environment-play-e7.md): stun an enemy, trap
## it, or hide from it.
##   Stun: a fire extinguisher's blast (3 m cone, BLASTS per extinguisher), the
##     flashlight's strobe up close (hold F), or something thrown at it ([G]: anything
##     in your hands tagged "throwable" in Inventory.ITEMS). A thrown thing lands as a
##     pickup, and as a sound every enemy that listens hears.
##   Trap: a locked or jammed door holds any enemy; an enemy's own cage is its own.
##   Hide: a HidingSpot (a locker, under a desk, a cabinet), or crouched in the dark
##     with your light off, where an enemy sees you only from DARK_SIGHT. Hiding is
##     safe unless the enemy saw you get in: then it comes and searches that spot.
##
## Each enemy says what these do to it (host):
##   counter(how: String, from: Vector3)   how: "extinguisher", "strobe" or "thrown"
##   counter_saw(body: Node3D) -> bool     it saw (or heard) them get into hiding
##   counter_search(spot: HidingSpot)      go and look in there
## and keeps hidden players out of its own sight with can_see() below.
##
## Co-op: the host decides every blast, strobe, throw, pickup and hiding place; the
## machine that did it asks the host, and what happens plays out on every machine.
## One per level, or per World ("Counterplay"), next to the Crew.

const EXTINGUISHER := "fire_extinguisher"
const BLASTS := 3
const BLAST_RANGE := 3.0
const BLAST_HALF_ANGLE := 35.0
## Between one blast and the next.
const BLAST_EVERY := 0.8
## The hiss carries like a hard landing (Shredder.HEAR_RANGE scale).
const BLAST_LOUDNESS := 0.7
## The cloud a blast leaves: it hides what's behind it, for this long.
const CLOUD_TIME := 4.0
const CLOUD_RADIUS := 1.4
## Hold the flashlight key this long for the strobe; it reaches this far, this wide.
const STROBE_HOLD := 1.0
const STROBE_RANGE := 4.0
const STROBE_HALF_ANGLE := 30.0
const STROBE_EVERY := 6.0
const STROBE_FX_TIME := 0.6
const THROW_SPEED := 9.0
## Where it lands, as loud as a sprint is to the Shredder... a bit louder.
const THROW_LOUDNESS := 0.6
## How near an enemy's middle a thrown thing has to pass to hit it.
const HIT_RADIUS := 0.7
const THROW_MAX_TIME := 2.5
## A stun again this soon after the last one on the same enemy lasts half as long,
## so a crew can't hold one down forever.
const STUN_REPEAT := 10.0
## Crouched in the dark with your light off, an enemy sees you only this close.
const DARK_SIGHT := 3.0
## A light this bright (light_energy) or more counts as light to be seen by.
const LIT_ENERGY := 0.25

## Prompts and notices (drafts, plan/approvals/v0.10-environment-strings.md).
const THROW_PROMPT := "[G] Throw"
## The extinguisher's hiss (Sound's to record), and a thrown thing landing.
const BLAST_SOUND := "extinguisher"
const LAND_SOUND := "clatter"
const STROBE_HINT := "Hold [F] to strobe"

var level: Node
var players: Node  # NetPlayers
## Peer id -> the HidingSpot they're in (its path from the level).
var hidden := {}
## This machine's fire extinguisher: blasts left in it.
var blasts_left := BLASTS
## Tests: blasts, strobes and throws on this machine, as {"how", ...}.
var log := []

var _had_extinguisher := false
var _blast_cd := 0.0
var _strobe_cd := 0.0
var _strobe_held := 0.0
## The strobe has been used on this machine: its hint is no longer needed.
var _strobed := false
var _lights: Array = []
var _lights_age := INF
var _throws := 0


static func create(for_level: Node, net_players: Node) -> Counterplay:
	var c := Counterplay.new()
	c.name = "Counterplay"
	c.level = for_level
	c.players = net_players
	for_level.add_child(c)
	return c


static func of(node: Node) -> Counterplay:
	var n := node
	while n:
		var c := n.get_node_or_null("Counterplay")
		if c is Counterplay:
			return c
		n = n.get_parent()
	return null


func _ready() -> void:
	var inv = _my_inventory()
	if inv:
		_had_extinguisher = inv.has(EXTINGUISHER)
		inv.changed.connect(_on_inventory_changed)
	# Gear on the floor: an extinguisher picked up has the blasts it had.
	for g in level.find_children("*", "GearPickup", true, false):
		_watch_gear(g)
	get_tree().node_added.connect(func(n): if n is GearPickup: _watch_gear.call_deferred(n))


# --- What enemies ask --------------------------------------------------------

## Whoever is hiding in `spot` (a Player or a teammate's puppet), or null.
static func hiding_in(spot: Node) -> Node3D:
	if spot == null or not spot.is_inside_tree():
		return null
	for b in spot.get_tree().get_nodes_in_group("player"):
		if b.get_viewport() == spot.get_viewport() and hidden_in(b) == spot:
			return b
	return null


## The HidingSpot `body` (a Player or a teammate's puppet) is in, or null.
static func hidden_in(body: Node) -> Node:
	if body == null or not body.has_meta("hidden_in"):
		return null
	var spot = body.get_meta("hidden_in")
	return spot if is_instance_valid(spot) else null


## Could an enemy that sees `sight` metres see `body` from `from`? Hidden: never.
## Crouched in the dark with the light off: only from DARK_SIGHT. (Walls are the
## enemy's own ray to check.)
static func can_see(from: Vector3, body: Node3D, sight: float) -> bool:
	if body == null or hidden_in(body) != null:
		return false
	var d := from.distance_to(body.global_position)
	if d > sight:
		return false
	return d <= DARK_SIGHT or not in_dark(body)


## Crouched (or crawling), the flashlight off, and no lamp shining on them.
static func in_dark(body: Node3D) -> bool:
	if body == null or not (body.get("crouching") == true or body.get("crawling") == true):
		return false
	if _light_on(body):
		return false
	var c := of(body)
	return c != null and not c.lit(body.global_position + Vector3.UP * 0.6)


static func _light_on(body: Node) -> bool:
	var torch = body.get("flashlight")
	if torch == null:
		torch = body.get("_light")  # a puppet's
	return torch is Light3D and torch.visible


## Is `at` (world space) in the light of a lamp? Players' flashlights don't count:
## whoever carries one is lit by it (in_dark), not what it points at.
func lit(at: Vector3) -> bool:
	if _lights_age > 1.0:
		_lights_age = 0.0
		_lights = level.find_children("*", "Light3D", true, false).filter(func(l): return not (l is DirectionalLight3D) and not _carried(l))
	for l in _lights:
		if not is_instance_valid(l) or not l.is_visible_in_tree() or l.light_energy < LIT_ENERGY:
			continue
		var off: Vector3 = at - l.global_position
		if l is OmniLight3D:
			if off.length() <= l.omni_range * 0.8:
				return true
		elif l is SpotLight3D:
			var fwd: Vector3 = -l.global_basis.z
			if off.length() <= l.spot_range * 0.8 and off.length() > 0.01 and rad_to_deg(fwd.angle_to(off)) <= l.spot_angle:
				return true
	return false


func _carried(l: Node) -> bool:
	var n := l.get_parent()
	while n and n != level:
		if n is Player or n is PlayerPuppet:
			return true
		n = n.get_parent()
	return false


## Host: a stun of `base` seconds on `enemy`, halved if it was stunned less than
## STUN_REPEAT seconds ago.
static func stun_time(enemy: Node, base: float) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	var last: float = enemy.get_meta("counter_stunned_at", -INF)
	enemy.set_meta("counter_stunned_at", now)
	return base * 0.5 if now - last < STUN_REPEAT else base


## Host: whoever is still in `spot` comes out (the enemy searching it found them).
## True if somebody was in there.
func pull_out(spot: Node) -> bool:
	var path := level.get_path_to(spot)
	for id in hidden:
		if hidden[id] == path:
			_run("_pulled", [id])
			return true
	return false


# --- What players do -----------------------------------------------------------

## This machine's player, holding the fire extinguisher, gives it a blast. False
## if they can't now (empty, or too soon).
func blast() -> bool:
	var p := _me()
	if p == null or p.inventory.active_item() != EXTINGUISHER or _blast_cd > 0.0 or blasts_left <= 0:
		return false
	blasts_left -= 1
	_blast_cd = BLAST_EVERY
	var eye := _eye(p)
	log.append({"how": "extinguisher", "left": blasts_left})
	_ask("_host_blast", [eye[0], eye[1]])
	return true


## This machine's player strobes the flashlight at whatever is in front of them.
func strobe() -> bool:
	var p := _me()
	if p == null or _strobe_cd > 0.0:
		return false
	_strobe_cd = STROBE_EVERY
	_strobed = true
	p.flashlight.visible = true
	var eye := _eye(p)
	log.append({"how": "strobe"})
	_ask("_host_strobe", [eye[0], eye[1]])
	return true


## This machine's player throws what's in their hands, if it's throwable.
func throw_held() -> bool:
	var p := _me()
	if p == null:
		return false
	var item: String = p.inventory.active_item()
	if not throwable(item):
		return false
	var left := blasts_left if item == EXTINGUISHER else -1
	p.inventory.remove(item)
	var eye := _eye(p)
	log.append({"how": "thrown", "item": item})
	_ask("_host_throw", [item, eye[0], eye[1], left])
	return true


static func throwable(item: String) -> bool:
	return item != "" and Inventory.ITEMS.get(item, {}).get("throwable", false) == true


## A prompt when there's nothing to use in front of you: throw what's in your
## hands, or, until you've used it once, the strobe when an enemy is close.
func prompt_for(p: Node) -> String:
	if p != _me():
		return ""
	if throwable(p.inventory.active_item()):
		return THROW_PROMPT
	if not _strobed and _strobe_cd <= 0.0 and _enemy_near(p, STROBE_RANGE):
		return STROBE_HINT
	return ""


## This machine's player got into `spot` (or out of it).
func report_hide(spot: Node, on: bool) -> void:
	_ask("_host_hide", [level.get_path_to(spot) if on else NodePath(""), on])


func _process(delta: float) -> void:
	_lights_age += delta
	_blast_cd = maxf(0.0, _blast_cd - delta)
	_strobe_cd = maxf(0.0, _strobe_cd - delta)
	var p := _me()
	if p == null or not p.local_control or p.input_locked:
		_strobe_held = 0.0
		return
	# Hold the flashlight key for the strobe.
	if InputMap.has_action("flashlight") and Input.is_action_pressed("flashlight"):
		_strobe_held += delta
		if _strobe_held >= STROBE_HOLD:
			_strobe_held = -INF  # once per hold
			strobe()
	else:
		_strobe_held = 0.0


func _unhandled_input(event: InputEvent) -> void:
	var p := _me()
	if p == null or not p.local_control or p.input_locked:
		return
	if InputMap.has_action("throw") and event.is_action_pressed("throw"):
		if throw_held():
			get_viewport().set_input_as_handled()


func _on_inventory_changed() -> void:
	var has: bool = _my_inventory().has(EXTINGUISHER)
	if has and not _had_extinguisher:
		blasts_left = BLASTS  # a full one, unless the gear it came off says otherwise (_on_gear_picked)
	_had_extinguisher = has


func _watch_gear(g: Node) -> void:
	if is_instance_valid(g) and level.is_ancestor_of(g) and not g.picked.is_connected(_on_gear_picked):
		g.picked.connect(_on_gear_picked.bind(g))


## Every machine: someone took gear `got` off the floor, leaving `left` there.
func _on_gear_picked(peer: int, got: String, left: String, g: Node) -> void:
	if peer != _my_id():
		return
	if got == EXTINGUISHER:
		blasts_left = int(g.get_meta("blasts", BLASTS))
		g.remove_meta("blasts")
	if left == EXTINGUISHER:
		# The one we put down keeps what we had left in it, on every machine.
		_ask("_host_gear_blasts", [level.get_path_to(g), blasts_left])


# --- The host decides ------------------------------------------------------------

func _host_blast(_id: int, eye: Vector3, dir: Vector3) -> void:
	for e in _enemies():
		if _in_cone(e, eye, dir, BLAST_RANGE, BLAST_HALF_ANGLE):
			e.counter("extinguisher", eye)
	_hear(eye, BLAST_LOUDNESS)
	_run("_cloud", [eye + dir.normalized() * 1.5])


func _host_strobe(id: int, eye: Vector3, dir: Vector3) -> void:
	for e in _enemies():
		if _in_cone(e, eye, dir, STROBE_RANGE, STROBE_HALF_ANGLE):
			e.counter("strobe", eye)
	_run("_strobe_fx", [id])


func _host_throw(id: int, item: String, eye: Vector3, dir: Vector3, left: int) -> void:
	var flight := _fly(id, eye, dir.normalized() * THROW_SPEED)
	_throws += 1
	var path: PackedVector3Array = flight.path
	_run("_thrown_fx", [item, path, float(flight.time), left, "Thrown%d" % _throws])
	await get_tree().create_timer(flight.time).timeout
	if not is_inside_tree():
		return
	var land: Vector3 = path[path.size() - 1]
	var hit = flight.hit  # untyped: it may have been freed while the thing flew
	if is_instance_valid(hit):
		hit.counter("thrown", land)
	_hear(land, THROW_LOUDNESS)
	var flat := land - path[0]
	_run("_landed", [item, land, left, "Thrown%d" % _throws, rad_to_deg(atan2(-flat.x, -flat.z))])


func _host_gear_blasts(_id: int, path: NodePath, left: int) -> void:
	_run("_gear_blasts", [path, left])


func _host_hide(id: int, path: NodePath, on: bool) -> void:
	var seen := []
	if on:
		var body := _body_of(id)
		for e in _enemies():
			if e.has_method("counter_saw") and e.counter_saw(body):
				seen.append(e)
	_run("_set_hidden", [id, path if on else NodePath("")])
	var spot := level.get_node_or_null(path) if on else null
	for e in seen:
		if e.has_method("counter_search"):
			e.counter_search(spot)


## A thrown thing's flight, stepped like the physics: {"path", "time", "hit"}.
func _fly(id: int, from: Vector3, vel: Vector3) -> Dictionary:
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var space := (level as Node3D).get_world_3d().direct_space_state
	var skip: Array[RID] = []
	var thrower := _body_of(id)
	if thrower is CollisionObject3D:
		skip.append(thrower.get_rid())
	var enemies := _enemies()
	var past: Array[RID] = skip.duplicate()  # the ray goes through enemies: the segment test hits them
	for e in enemies:
		if e is CollisionObject3D:
			past.append(e.get_rid())
	var dt := 1.0 / 60.0
	var pos := from
	var t := 0.0
	var path := PackedVector3Array([from])
	while t < THROW_MAX_TIME:
		var next := pos + vel * dt
		vel.y -= g * dt
		t += dt
		for e in enemies:
			var mid: Vector3 = e.global_position + Vector3.UP * 1.1
			if Geometry3D.get_closest_point_to_segment(mid, pos, next).distance_to(mid) < HIT_RADIUS:
				path.append(_floor_under(space, next, skip))
				return {"path": path, "time": t, "hit": e}
		var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos, next, 1, past))
		if not r.is_empty():
			var at: Vector3 = r.position + r.normal * 0.12
			path.append(_floor_under(space, at, skip) if r.normal.y < 0.7 else at)
			return {"path": path, "time": t, "hit": null}
		pos = next
		if int(t / dt) % 4 == 0:
			path.append(pos)
	path.append(_floor_under(space, pos, skip))
	return {"path": path, "time": t, "hit": null}


func _floor_under(space: PhysicsDirectSpaceState3D, at: Vector3, skip: Array[RID]) -> Vector3:
	var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 30.0, 1, skip))
	return (r.position + Vector3.UP * 0.08) if not r.is_empty() else at


func _hear(at: Vector3, loudness: float) -> void:
	for e in _enemies():
		if e.has_method("hear"):
			e.hear(at, loudness)


func _in_cone(e: Node3D, eye: Vector3, dir: Vector3, reach: float, half_angle: float) -> bool:
	var mid: Vector3 = e.global_position + Vector3.UP * 1.1
	var off := mid - eye
	var flat_d := off.length()
	if flat_d > reach + 0.5:
		return false
	if flat_d > 0.6 and rad_to_deg(dir.angle_to(off)) > half_angle:
		return false
	var skip: Array[RID] = []
	if e is CollisionObject3D:
		skip.append(e.get_rid())
	for b in level.get_tree().get_nodes_in_group("player"):
		if b is CollisionObject3D:
			skip.append(b.get_rid())
	var q := PhysicsRayQueryParameters3D.create(eye, mid, 1, skip)
	return (level as Node3D).get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# --- Every machine ---------------------------------------------------------------

func _set_hidden(id: int, path: NodePath) -> void:
	var spot: Node = level.get_node_or_null(path) if not path.is_empty() else null
	if spot:
		hidden[id] = path
	else:
		hidden.erase(id)
	var body := _body_of(id)
	if body == null:
		return
	if spot:
		body.set_meta("hidden_in", spot)
	elif body.has_meta("hidden_in"):
		body.remove_meta("hidden_in")
	if body is PlayerPuppet:
		body.visible = spot == null  # tucked away inside: nobody sees them


func _pulled(id: int) -> void:
	if id == _my_id():
		var p := _me()
		if p and p.is_sitting():
			p.stand_up(true)
	_set_hidden(id, NodePath(""))


func _cloud(at: Vector3) -> void:
	SightCloud.make(level, at, CLOUD_RADIUS, CLOUD_TIME)
	if Sfx.KINDS.has(BLAST_SOUND):  # Sound records it; silent till then
		Sfx.play(level, BLAST_SOUND, (level as Node3D).to_local(at))


func _strobe_fx(id: int) -> void:
	var body := _body_of(id)
	var torch = body.get("flashlight") if body else null
	if torch == null and body:
		torch = body.get("_light")
	if not torch is Light3D:
		return
	var base: float = torch.light_energy
	var tw := create_tween()
	for i in 6:
		tw.tween_property(torch, "light_energy", base * 4.0, STROBE_FX_TIME / 12.0)
		tw.tween_property(torch, "light_energy", 0.0, STROBE_FX_TIME / 12.0)
	tw.tween_property(torch, "light_energy", base, 0.01)


func _thrown_fx(item: String, path: PackedVector3Array, time: float, _left: int, node_name: String) -> void:
	var it := ThrownItem.make(level, item, path[0])
	it.name = "Flying" + node_name
	it.fly(path, time)


## Down: it lies where it landed as gear anyone can pick up (the same node on every machine).
func _landed(item: String, at: Vector3, left: int, node_name: String, yaw_deg: float) -> void:
	var flying := level.get_node_or_null("Flying" + node_name)
	if flying:
		flying.queue_free()
	var g := GearPickup.make(level, item, (level as Node3D).to_local(at), yaw_deg)
	g.name = node_name
	if left >= 0:
		g.set_meta("blasts", left)
	Sfx.play(level, LAND_SOUND, (level as Node3D).to_local(at))


func _gear_blasts(path: NodePath, left: int) -> void:
	var g := level.get_node_or_null(path)
	if g:
		g.set_meta("blasts", left)


# --- Plumbing --------------------------------------------------------------------

func _ask(method: String, args: Array) -> void:
	if _is_host():
		callv(method, [_my_id()] + args)
	else:
		_ask_host.rpc_id(1, method, args)


@rpc("any_peer", "reliable")
func _ask_host(method: String, args: Array) -> void:
	if _is_host() and method in ["_host_blast", "_host_strobe", "_host_throw", "_host_gear_blasts", "_host_hide"]:
		callv(method, [multiplayer.get_remote_sender_id()] + args)


func _run(method: StringName, args: Array) -> void:
	var s := LevelSync.of(level)
	if s and s.is_online():
		s.run_on(self, method, args)
	else:
		callv(method, args)


func _is_host() -> bool:
	var s := LevelSync.of(level)
	return s == null or s.is_host()


func _my_id() -> int:
	return multiplayer.get_unique_id()


func _me() -> Player:
	return players.player if players and players.player is Player else null


func _my_inventory():
	var p := _me()
	return p.inventory if p else null


func _body_of(id: int) -> Node3D:
	if players == null:
		return null
	if id == _my_id():
		return players.player
	return players.puppet(id)


## The enemies in this world that answer to counterplay.
func _enemies() -> Array:
	return level.get_tree().get_nodes_in_group("npc").filter(func(e): return e.has_method("counter") and e.get_viewport() == level.get_viewport() and e.is_inside_tree())


func _enemy_near(p: Node3D, reach: float) -> bool:
	return _enemies().any(func(e): return e.global_position.distance_to(p.global_position) < reach)


## Eye position and look direction (world space).
func _eye(p: Player) -> Array:
	var cam: Camera3D = p.get("camera")
	if cam:
		return [cam.global_position, -cam.global_basis.z]
	return [p.global_position + Vector3.UP * 1.6, -p.global_basis.z]
