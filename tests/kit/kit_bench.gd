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
	var x := -6.0
	for item in ["keyboard", "power_cord", "fuse", "crowbar", "fire_extinguisher"]:
		gear[item] = GearPickup.make(kit, item, Vector3(x, 0.0, 2.0))
		x += 1.5
