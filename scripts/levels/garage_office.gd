class_name GarageOffice
extends Node3D
## The garage's secret: the side door in the back corner is locked, and its spare
## key is hidden somewhere in the garage, with a riddle on the door saying where.
## Behind it is Maddison's back office and the crew's old PC (ArchiveTerminal): the
## crew files, the company, achievements and cases closed. Out of the story, and
## never needed. Built by HomeBase; the key and the door are shared (host decides,
## HomeBase._office_* run everywhere), the PC is each player's own to read.
## plan/garage-secret-room.md.

## Approved by Augustine word for word, 2026-11-05 00:43Z (plan/garage-secret-room.md).
const PLATE := "OFFICE"
const DOOR_PROMPT := "Open the door"
const LOCKED := "Locked."
const UNLOCK_PROMPT := "Unlock the office"
const KEY_PROMPT := "Take the spare key"
const PC_PROMPT := "Use the computer"
## Where the key can be, one per run (Game.run_seed), each with its riddle.
const SPOTS := [
	{"id": "coffee", "riddle": "Spare key is with the only thing in this garage that works every morning. - M"},
	{"id": "glove", "riddle": "Spare key is where we put our nerves. - M"},
	{"id": "bench", "riddle": "Spare key is under the bench where nothing ever gets fixed. - M"},
]

## The office, behind the garage's west wall (garage-local).
const ROOM := Vector3(-9.65, 0, 4.4)
const ROOM_SIZE := Vector3(3.1, 2.6, 3.2)
## The door's hinge, at the south edge of the side door's opening.
const HINGE := HomeBase.SIDE_DOOR + Vector3(-0.03, 0, -0.45)
const PC_AT := ROOM + Vector3(-1.15, 0, 0.6)
## Where each SPOTS key lies (garage-local): in the coffee tin on the counter, in
## the glove hanging off the punch bag's stand, taped low on the workbench's front.
const KEY_AT := {
	"coffee": HomeBase.COUNTER + Vector3(0, 1.13, -1.5),
	"glove": HomeBase.PUNCH_BAG + Vector3(-HomeBase.BAG_STAND_HALF, 1.2, 0.1),
	"bench": HomeBase.BENCH + Vector3(0.6, 0.25, 0.53),
}

var home: Node3D
var spot: Dictionary
var key: Interactable
var door: Interactable
var pc: Interactable
var door_pivot: Node3D
## Who has the key (0: nobody yet), and whether the door is open.
var key_holder := 0
var unlocked := false


static func build(level: Node3D) -> GarageOffice:
	var o := GarageOffice.new()
	o.name = "Office"
	o.home = level
	level.add_child(o)
	o._build()
	return o


func _build() -> void:
	var geo: Node3D = home.geo
	var wall := Color(0.62, 0.6, 0.55)
	var t := 0.2
	Greybox.box(geo, ROOM + Vector3(0, -0.05, 0), Vector3(ROOM_SIZE.x, 0.1, ROOM_SIZE.z), Color(0.35, 0.3, 0.26), "OfficeFloor")
	Greybox.box(geo, ROOM + Vector3(0, ROOM_SIZE.y + 0.05, 0), Vector3(ROOM_SIZE.x, 0.1, ROOM_SIZE.z), Color(0.8, 0.79, 0.75), "OfficeCeiling")
	Greybox.box(geo, ROOM + Vector3(-ROOM_SIZE.x / 2 - t / 2, ROOM_SIZE.y / 2, 0), Vector3(t, ROOM_SIZE.y, ROOM_SIZE.z), wall, "OfficeWallW")
	for side in [-1.0, 1.0]:
		Greybox.box(geo, ROOM + Vector3(0, ROOM_SIZE.y / 2, side * (ROOM_SIZE.z / 2 + t / 2)), Vector3(ROOM_SIZE.x + t * 2, ROOM_SIZE.y, t), wall, "OfficeWall")
	# Filing cabinets along the back, and the desk with the crew's old PC.
	for i in 3:
		Greybox.box(geo, ROOM + Vector3(-1.2, 0.65, -1.1 + i * 0.55), Vector3(0.6, 1.3, 0.5), Color(0.45, 0.47, 0.45), "Cabinet")
	Greybox.box(geo, PC_AT + Vector3(0.05, 0.38, 0), Vector3(0.8, 0.76, 1.3), Color(0.4, 0.32, 0.24), "OfficeDesk")
	Greybox.box(geo, PC_AT + Vector3(0, 0.97, 0), Vector3(0.45, 0.42, 0.45), Color(0.78, 0.75, 0.66), "OldPC")
	Greybox.panel(geo, PC_AT + Vector3(0.231, 0.99, 0), Vector3(0.01, 0.3, 0.36), Color(0.2, 0.6, 0.3), 0.6)
	pc = Interactable.create(home, PC_AT + Vector3(0.12, 0.97, 0), Vector3(0.3, 0.45, 0.5), PC_PROMPT, Color.BLACK, false)
	pc.name = "OfficePC"
	pc.local_only = true  # reading it is each player's own
	pc.used.connect(func(_p): open_terminal())
	var light := OmniLight3D.new()
	light.name = "OfficeLight"
	light.position = ROOM + Vector3(0, ROOM_SIZE.y - 0.2, 0)
	light.omni_range = 4.0
	light.light_energy = 1.0
	light.light_color = Color(1.0, 0.9, 0.75)
	geo.add_child(light)

	# The door: hinged at the opening's south edge, swinging into the office.
	door_pivot = Node3D.new()
	door_pivot.name = "OfficeDoorHinge"
	door_pivot.position = HINGE
	home.add_child(door_pivot)  # off geo: it moves
	door = Interactable.create(door_pivot, Vector3(0, 1.05, 0.45), Vector3(0.06, 2.1, 0.9), DOOR_PROMPT, Color(0.5, 0.42, 0.32))
	door.name = "OfficeDoor"
	door.used.connect(_on_door)
	Greybox.label(door_pivot, Vector3(0.04, 1.7, 0.45), PLATE, 40, Color(0.12, 0.12, 0.12), 90.0)
	# The riddle, on a sticky under the plate.
	spot = SPOTS[_game().run_seed % SPOTS.size()]
	Greybox.panel(door_pivot, Vector3(0.035, 1.35, 0.45), Vector3(0.005, 0.2, 0.22), Color(1.0, 0.92, 0.4))
	var riddle := Greybox.label(door_pivot, Vector3(0.04, 1.35, 0.45), spot.riddle, 9, Color(0.1, 0.1, 0.3), 90.0)
	riddle.name = "Riddle"
	riddle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	riddle.width = 95.0

	# Where the key could be: a coffee tin and a glove are always there, so their
	# being there gives nothing away.
	# Neither has collision, so aiming at one finds the key inside it, which is
	# what a look in the tin or the glove is.
	Greybox.panel(geo, KEY_AT.coffee, Vector3(0.14, 0.18, 0.14), Color(0.55, 0.15, 0.12)).name = "CoffeeTin"
	Greybox.panel(geo, KEY_AT.glove, Vector3(0.14, 0.24, 0.18), Color(0.7, 0.1, 0.1)).name = "Glove"
	var at: Vector3 = KEY_AT[spot.id]
	var hidden: bool = spot.id != "bench"
	key = Interactable.create(home, at, Vector3(0.18, 0.24, 0.18) if hidden else Vector3(0.1, 0.05, 0.02), KEY_PROMPT, Color(0.85, 0.7, 0.3), not hidden)
	key.name = "SpareKey"
	key.used.connect(func(p): home.sync.event("_office_key", [home.players.id_of(p)]))


## Every machine: player `id` took the key.
func take_key(id: int) -> void:
	key_holder = id
	key.visible = false
	key.enabled = false
	if _mine(id):
		door.prompt = UNLOCK_PROMPT


## Host: someone tried the door.
func _on_door(p: Node) -> void:
	var id: int = home.players.id_of(p)
	if unlocked:
		return
	if id != 0 and id == key_holder:
		home.sync.event("_office_open", [id])
	else:
		home.sync.run_on(self, "_locked_for", [id])


## Every machine: tell player `id` it's locked.
func _locked_for(id: int) -> void:
	if _mine(id):
		home.hud.notice(LOCKED, 2.0)


## Every machine: the door unlocks and swings into the office.
func open() -> void:
	if unlocked:
		return
	unlocked = true
	door.enabled = false
	create_tween().tween_property(door_pivot, "rotation:y", deg_to_rad(-100.0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## This player sits down at the PC.
func open_terminal() -> ArchiveTerminal:
	var player: Node = home.player
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	layer.name = "ArchiveLayer"
	layer.layer = 25
	home.add_child(layer)
	var t := ArchiveTerminal.show_for(layer, home.get_node("/root/Net").profile)
	t.tree_exited.connect(func():
		layer.queue_free()
		if is_instance_valid(player):
			player.input_locked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	return t


func _mine(id: int) -> bool:
	return home.players.puppet(id) == home.player


func _game() -> Node:
	return get_node("/root/Game")
