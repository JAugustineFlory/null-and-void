class_name GarageLab
extends Node3D
## The garage's lab: a lean-to annex through the west wall, between Maddison's
## desk and the whiteboard. Six computers in two rows face a whiteboard on its
## west wall (the crew's practice cases, plan/garage-lab-v0.10.md), and six
## lockers line its north wall, one per player, each with their name on it.
## A player's own locker opens their Customize panel (LookPicker, no Crew tab:
## who you play is set in the lobby), and what they change shows on the crew
## straight away. Built by HomeBase; the shell is part of the garage's outside
## (HomeBase._build_shell), so the pre-game lobby's shot of the garage matches.

## Drafts, waiting on Augustine's word-for-word OK (plan/garage-lab-v0.10.md, part 4).
const SIGN := "LAB"
const LOCKER_PROMPT := "Open your locker"
## Approved for the back office (GarageOffice.PC_PROMPT).
const PC_PROMPT := GarageOffice.PC_PROMPT

## The annex (garage-local): its floor's middle and its inside size. The garage's
## west wall (x -8) is its east wall; it stops short of the back office (z 2.6).
const ROOM := Vector3(-11.0, 0, -1.8)
const ROOM_SIZE := Vector3(6.0, 3.0, 8.4)
## The doorway in the garage's west wall, between the desk and the whiteboard.
const DOOR_Z := -2.3
const DOOR_SIZE := Vector2(1.6, 2.4)
## The whiteboard the desks face, on the lab's west wall.
const BOARD := Vector3(-13.88, 1.5, -1.4)
## The desks' middles: two rows of three, every one facing the board (-X). Each
## player sits east of theirs (DESK_SEAT).
const DESKS := [
	Vector3(-12.7, 0, -3.4), Vector3(-12.7, 0, -1.4), Vector3(-12.7, 0, 0.6),
	Vector3(-10.4, 0, -3.4), Vector3(-10.4, 0, -1.4), Vector3(-10.4, 0, 0.6),
]
const DESK_SIZE := Vector3(0.6, 0.76, 1.0)
const DESK_SEAT := Vector3(0.7, 0.45, 0.0)
## The lockers' middles, along the north wall, the host's first.
const LOCKERS := [
	Vector3(-13.6, 0, -5.65), Vector3(-13.0, 0, -5.65), Vector3(-12.4, 0, -5.65),
	Vector3(-11.8, 0, -5.65), Vector3(-11.2, 0, -5.65), Vector3(-10.6, 0, -5.65),
]
const LOCKER_SIZE := Vector3(0.58, 1.9, 0.5)

var home: Node3D
## One per desk, in DESKS order. Off until the tutorial (PR 2) turns them on.
var computers: Array[Interactable] = []
var seats: Array[Seat] = []
## One per locker, in LOCKERS order: its door, and the name card on it.
var lockers: Array[Interactable] = []
var name_cards: Array[Label3D] = []
## Whose each locker is (peer ids, in the player order; 0: nobody's).
var owners: Array[int] = []
## This player's Customize panel while it's open.
var panel: MenuModal
## Everyone's look as last dressed here, by peer id, to see whose changed.
var _dressed := {}


static func build(level: Node3D) -> GarageLab:
	var lab := GarageLab.new()
	lab.name = "Lab"
	lab.home = level
	level.add_child(lab)
	lab._build()
	return lab


## The annex's walls, floor and roof under `solid` (no door: the doorway is a gap
## in the garage's own west wall).
static func build_shell(solid: Node3D) -> void:
	var t := 0.2
	var wall := Color(0.82, 0.8, 0.74)
	var west := ROOM.x - ROOM_SIZE.x / 2
	var east := ROOM.x + ROOM_SIZE.x / 2
	Greybox.box(solid, ROOM + Vector3(0, -t / 2, 0), Vector3(ROOM_SIZE.x, t, ROOM_SIZE.z), Color(0.55, 0.55, 0.52), "FloorLab")
	Greybox.box(solid, ROOM + Vector3(0, ROOM_SIZE.y + t / 2, 0), Vector3(ROOM_SIZE.x + t, t, ROOM_SIZE.z + t), Color(0.85, 0.84, 0.8), "CeilingLab")
	Greybox.box(solid, Vector3(west, ROOM_SIZE.y / 2, ROOM.z), Vector3(t, ROOM_SIZE.y, ROOM_SIZE.z + t), wall, "Wall_LabW")
	for side in [-1.0, 1.0]:
		var z: float = ROOM.z + side * ROOM_SIZE.z / 2
		Greybox.box(solid, Vector3((west + east) / 2 - t / 4, ROOM_SIZE.y / 2, z), Vector3(east - west + t / 2, ROOM_SIZE.y, t), wall, "Wall_LabN" if side < 0 else "Wall_LabS")


func _build() -> void:
	var geo: Node3D = home.geo
	# Over the doorway, on the garage side.
	Greybox.label(geo, Vector3(-7.88, DOOR_SIZE.y + 0.3, DOOR_Z), SIGN, 64, Color(0.1, 0.3, 0.6), 90.0).name = "LabSign"
	# The whiteboard (blank: the practice cases go up on it).
	Greybox.panel(geo, BOARD, Vector3(0.04, 1.2, 2.4), Color(0.95, 0.95, 0.93)).name = "LabBoard"
	Greybox.panel(geo, BOARD + Vector3(0.0, -0.66, 0), Vector3(0.1, 0.04, 2.4), Color(0.6, 0.6, 0.62)).name = "LabBoardTray"

	for i in DESKS.size():
		var at: Vector3 = DESKS[i]
		Greybox.box(geo, at + Vector3(0, DESK_SIZE.y / 2, 0), DESK_SIZE, Color(0.55, 0.5, 0.42), "LabDesk%d" % i)
		# A beige box and its screen, facing the chair.
		Greybox.box(geo, at + Vector3(-0.08, DESK_SIZE.y + 0.2, 0), Vector3(0.38, 0.36, 0.4), Color(0.78, 0.75, 0.66), "LabMonitor%d" % i)
		Greybox.panel(geo, at + Vector3(0.115, DESK_SIZE.y + 0.21, 0), Vector3(0.01, 0.26, 0.32), Color(0.15, 0.35, 0.2), 0.5)
		var pc := Interactable.create(home, at + Vector3(0.05, DESK_SIZE.y + 0.2, 0), Vector3(0.5, 0.4, 0.5), PC_PROMPT, Color.BLACK, false)
		pc.name = "LabPC%d" % i
		pc.enabled = false  # the practice cases turn them on
		computers.append(pc)
		var seat_top: Vector3 = at + DESK_SEAT
		Greybox.box(geo, Vector3(seat_top.x, seat_top.y / 2, seat_top.z), Vector3(0.42, seat_top.y, 0.42), Color(0.2, 0.2, 0.22), "LabChair%d" % i)
		var seat := Seat.create_at(home, seat_top, PI / 2, Vector2(0.42, 0.42))  # facing the board (-X)
		seat.name = "LabSeat%d" % i
		seats.append(seat)

	for i in LOCKERS.size():
		var at: Vector3 = LOCKERS[i]
		Greybox.box(geo, at + Vector3(0, LOCKER_SIZE.y / 2, -0.03), LOCKER_SIZE - Vector3(0, 0, 0.06), Color(0.35, 0.42, 0.5), "Locker%d" % i)
		var front: float = LOCKER_SIZE.z / 2
		var door := Interactable.create(home, at + Vector3(0, LOCKER_SIZE.y / 2, front - 0.02), Vector3(LOCKER_SIZE.x - 0.04, LOCKER_SIZE.y - 0.04, 0.04),
			LOCKER_PROMPT, Color(0.4, 0.48, 0.57))
		door.name = "LockerDoor%d" % i
		door.local_only = true  # your own locker, on your own machine
		door.enabled = false  # until it's known whose it is (assign)
		door.used.connect(func(_p): open_locker())
		lockers.append(door)
		var vent := Greybox.panel(geo, at + Vector3(0, LOCKER_SIZE.y - 0.3, front + 0.005), Vector3(0.3, 0.12, 0.005), Color(0.2, 0.24, 0.28))
		vent.name = "LockerVent%d" % i
		Greybox.panel(geo, at + Vector3(0, 1.45, front + 0.005), Vector3(0.36, 0.12, 0.005), Color(0.95, 0.94, 0.88)).name = "NameCard%d" % i
		var card := Greybox.label(geo, at + Vector3(0, 1.45, front + 0.01), "", 18, Color(0.1, 0.1, 0.12))
		card.name = "NameText%d" % i
		name_cards.append(card)
		owners.append(0)

	for z in [-3.6, 0.4]:
		home.add_light("garage", Vector3(ROOM.x, ROOM_SIZE.y, z), 6.0, 1.2, Color(1.0, 0.96, 0.9))


## Every machine, once the crew is known (HomeBase.net_setup): each player's
## locker, in the player order, gets their name; only your own opens.
func assign() -> void:
	var ids: Array = home.players.all_ids()
	var net := get_node_or_null("/root/Net")
	for i in lockers.size():
		var id: int = ids[i] if i < ids.size() else 0
		owners[i] = id
		var who := ""
		if id != 0 and net:
			# Everyone's name as the roster has it (the host numbers a repeat); solo, yours.
			who = net.display_name(id) if net.roster.has(id) or id != multiplayer.get_unique_id() else net.player_name
		elif id != 0:
			who = "Player %d" % id
		name_cards[i].text = who
		lockers[i].enabled = id != 0 and id == multiplayer.get_unique_id()
	for id in ids:
		_dressed[id] = NetPlayers.look_for(self, id)
	if net and not net.roster_changed.is_connected(_on_roster_changed):
		net.roster_changed.connect(_on_roster_changed)


## Your locker, as one of the crew sees it (nothing when there are fewer than six).
func locker_of(id: int) -> Interactable:
	var i := owners.find(id)
	return lockers[i] if i != -1 else null


## This player opens their locker: their Customize panel over the garage.
func open_locker() -> MenuModal:
	if is_instance_valid(panel):
		return panel
	var player: Node = home.player
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	layer.name = "LockerLayer"
	layer.layer = 25
	home.add_child(layer)
	panel = MenuModal.open(layer)
	panel.name = "Locker"
	var picker := LookPicker.new()
	picker.with_crew = false  # who you play is set in the lobby
	panel.box.add_child(picker)
	picker.set_name_editable(false)  # it's on the locker
	panel.add_back()
	panel.tree_exited.connect(func():
		layer.queue_free()
		if is_instance_valid(player):
			player.input_locked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	return panel


## Someone's look changed (a locker, here or on another machine): dress them in it.
func _on_roster_changed() -> void:
	for id in home.players.all_ids():
		var look := NetPlayers.look_for(self, id)
		if _dressed.get(id) == look:
			continue
		_dressed[id] = look
		if id == multiplayer.get_unique_id():
			restyle_me(look)
		else:
			var body = home.players.puppet(id)
			if body is PlayerPuppet:
				body.restyle(look)


## Your own body, as you see it, and the notebook in your hands, in `look`.
func restyle_me(look: Dictionary) -> void:
	var player: Node3D = home.player
	var fp := player.get_node_or_null("FirstPersonBody")
	if fp:
		player.remove_child(fp)  # so the new one takes its name
		fp.queue_free()
		FirstPersonBody.attach(player, look)
	if home.notebook:
		home.notebook.rebuild()
