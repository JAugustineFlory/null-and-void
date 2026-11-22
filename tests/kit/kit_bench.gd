extends LevelBase
## A bare room with one of every environment-kit piece, for tests/kit_tests.gd:
## gear to pick up, a cycling shutter on a gear train, a second train that starts
## jammed, a fuse box, a patch panel, a crowbar hatch and a terminal that starts
## switched off with its parts missing, on the fuse box's TERMINALS circuit (blown).

var kit: Node3D
var shutter: Shutter
var gears: GearTrain
var stuck_gears: GearTrain
var fuses: FuseBox
var patch: PatchPanel
var hatch: ItemLock
var terminal: Terminal
var rig: TerminalRig
var gear := {}
## A roll-up door whose chain gear starts jammed with a crowbar; freed, its hand chain
## lifts the door to a 1.0 m gap.
var rollup: Shutter
var rollup_gears: GearTrain
var chain: ItemLock
## A lift out at x 30 (its shaft needs open sky) that can stall, riding to one at x 40.
var lift: Elevator
var lift_to: Elevator
var stall: ElevatorStall
var rides := 0


func build() -> void:
	spawn = Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 3))
	Greybox.room(geo, Vector3.ZERO, Vector3(20, 4, 12), {})
	add_light("bench", Vector3(0, 3.8, 0), 14.0)
	kit = Node3D.new()
	kit.name = "Kit"
	add_child(kit)
	shutter = Shutter.make(self, "bench", Vector3(0, 1.2, -5.9), Vector3(2, 2.4, 0.12))
	shutter.cycle = Vector2(0.6, 0.6)
	shutter.speed = 1.5
	gears = GearTrain.make(kit, "bench", Vector3(2, 1.4, -5.85), 0.0, shutter)
	stuck_gears = GearTrain.make(kit, "stuck", Vector3(4, 1.4, -5.85), 0.0, null, true)
	fuses = FuseBox.make(kit, "bench", Vector3(-3, 1.5, -5.85), 0.0, ["LIGHTS", "TERMINALS", "STAIR DOOR", "VENDING"], [1])
	patch = PatchPanel.make(kit, "bench", Vector3(-6, 1.5, -5.9), 0.0, ["RM 101", "RM 102", "RM 103", "LOBBY"])
	hatch = ItemLock.make(kit, "hatch", Vector3(-8, 0.5, 0), Vector3(0.1, 0.8, 0.8), "crowbar", "Pry the hatch open", "The hatch is stuck.")
	Greybox.box(geo, Vector3(6, 0.4, 0), Vector3(1.2, 0.8, 0.8), Color(0.4, 0.3, 0.2), "Desk")
	terminal = Terminal.spawn(geo, Vector3(6, 0.8, 0), 90, "BENCH", db, terminal_ui)
	rig = TerminalRig.attach(terminal, ["power", "power_cord", "monitor_cable", "keyboard"], fuses, "TERMINALS")
	rollup = Shutter.make(self, "rollup", Vector3(-4, 1.3, 5.9), Vector3(3, 2.6, 0.12), 180)
	rollup_gears = GearTrain.make(kit, "rollup", Vector3(-1.6, 1.3, 5.85), 180, rollup, true, "crowbar")
	chain = ItemLock.make(kit, "chain", Vector3(-2.3, 1.2, 5.85), Vector3(0.1, 1.2, 0.1), "", "Pull the chain", "The chain won't move.")
	chain.sound = "rattle"
	chain.enabled = false
	rollup_gears.jam_changed.connect(func(on, _peer): chain.enabled = not on)
	chain.opened.connect(func(_peer): rollup.open_to(1.0))
	Greybox.box(geo, Vector3(35, -0.1, 0), Vector3(16, 0.2, 8), Color(0.3, 0.3, 0.32), "LiftFloor")
	lift = Elevator.create(self, geo, Vector3(30, 0, -1), 0, "G", ["G", "1", "2", "3"], "3")
	lift_to = Elevator.create(self, geo, Vector3(40, 0, -1), 0, "3", ["G", "1", "2", "3"])
	lift.link_to(lift_to)
	stall = ElevatorStall.attach(lift, geo, "bench_lift")
	var x := -6.0
	for item in ["keyboard", "power_cord", "fuse", "crowbar", "fire_extinguisher"]:
		gear[item] = GearPickup.make(kit, item, Vector3(x, 0.0, 2.0))
		x += 1.5


## Every machine (a sync.event): the doors shut and it rides, stalling if armed.
func _ride() -> void:
	lift.close()
	await lift.closed
	await lift.ride()
	rides += 1


func _arm_stall() -> void:
	stall.arm()
