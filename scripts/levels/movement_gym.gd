extends LevelBase
## A practice hall for every move, in the order players meet them: slide,
## mantle, grab and roll, vent crawl, climb, ledge shuffle, shoulder boost;
## and a chair to sit on.
## No puzzles and no threats; reachable from the main menu.

const TEXT := Color(0.92, 0.9, 0.8)

## A teammate standing still, so solo players can practice shoulder boosts.
var teammate: Player


func build() -> void:
	spawn = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(-27, 0.1, 0))
	Greybox.room(geo, Vector3.ZERO, Vector3(62, 8, 10), {})
	for x in range(-26, 30, 8):
		add_light("gym", Vector3(x, 7.8, 0), 12.0, 1.6)
	_sign(Vector3(-25, 2.4, 0), "MOVEMENT GYM\nWalk east. Every station teaches one move.")

	# Sit on a chair, or on the floor.
	Greybox.box(geo, Vector3(-25, 0.225, -3.5), Vector3(0.5, 0.45, 0.5), Color(0.3, 0.3, 0.34), "Chair")
	Greybox.box(geo, Vector3(-25, 0.75, -3.77), Vector3(0.5, 0.6, 0.06), Color(0.3, 0.3, 0.34), "ChairBack")
	Seat.create_at(geo, Vector3(-25, 0.45, -3.5), PI)
	_sign(Vector3(-24, 1.8, -3.2), "E at a chair: sit. Z: sit on the floor.\nSpace or Z: stand up.")
	_sign(Vector3(-24, 2.4, 3.2), "Running, jumping and climbing tire you.\nStand still to get your breath back.")

	# Slide under a jammed shutter.
	Greybox.box(geo, Vector3(-22, 4, -3.25), Vector3(0.2, 8, 3.5), Color.DIM_GRAY)
	Greybox.box(geo, Vector3(-22, 4, 3.25), Vector3(0.2, 8, 3.5), Color.DIM_GRAY)
	Traversal.gate(geo, Vector3(-22, 0, 0), 3.0, 1.0, 8.0, false)
	_sign(Vector3(-23, 2.4, 0), "Sprint (Shift), then Ctrl: slide under.\nYou can let go of Shift just before Ctrl. Or crouch-walk.")

	# Vault a desk by walking into it.
	Greybox.box(geo, Vector3(-20.3, 0.45, 0), Vector3(0.8, 0.9, 10), Color(0.42, 0.3, 0.22))
	_sign(Vector3(-21.2, 1.7, 0), "W + Space at a desk, table or counter: vault over it.")

	# Mantle a waist-high wall.
	Greybox.box(geo, Vector3(-17, 0.6, 0), Vector3(2, 1.2, 10), Color.DIM_GRAY)
	_sign(Vector3(-19, 2.2, 0), "W + Space at a waist-high wall: mantle.")

	# Grab a high edge, then drop and roll.
	Greybox.box(geo, Vector3(-12, 1.2, 0), Vector3(1, 2.4, 10), Color.DIM_GRAY)
	_sign(Vector3(-14, 3.2, 0), "W + Space at a high wall: grab the edge and hang.\nSpace, or W again, to pull up. A / D shimmy,\nS or Ctrl let go.\nTap Ctrl in the air to roll when you land: quiet.")

	# Crawl through a vent.
	Traversal.vent(geo, Vector3(-8, 0, 0), Vector3(-4, 0, 0))
	Greybox.box(geo, Vector3(-6, 4, -2.79), Vector3(0.2, 8, 4.42), Color.DIM_GRAY)
	Greybox.box(geo, Vector3(-6, 4, 2.79), Vector3(0.2, 8, 4.42), Color.DIM_GRAY)
	Greybox.box(geo, Vector3(-6, 4.515, 0), Vector3(0.2, 6.97, 1.16), Color.DIM_GRAY)
	_sign(Vector3(-9, 2.2, 0), "Ctrl: crawl through the vent.\nShift in a vent bangs the duct. Things hear that.")

	# Climb a pipe to a platform.
	Greybox.box(geo, Vector3(7, 2, 0), Vector3(6, 4, 10), Color.DIM_GRAY)
	Traversal.climbable(geo, Vector3(4, 0, 0), Vector3(4, 4, 0), Vector3(-1, 0, 0))
	_sign(Vector3(2, 2.6, -1.5), "W + Space at the pipe: climb.\nW / S up and down, Space to kick off.")

	# Shuffle along a narrow ledge to the far platform.
	Traversal.ledge(geo, Vector3(10, 4, -4.9), Vector3(20, 4, -4.9), Vector3(0, 0, 1))
	Greybox.box(geo, Vector3(25, 2, 0), Vector3(10, 4, 10), Color.DIM_GRAY)
	_sign(Vector3(9.8, 6.0, -3.0), "Step onto the ledge: shuffle along it.")

	# Or get there on a teammate's shoulders.
	teammate = Player.new()
	teammate.name = "Teammate"
	teammate.local_control = false
	add_child(teammate)
	teammate.global_transform = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(19.4, 0.1, 2.5))
	_sign(Vector3(16, 2.8, 2.5), "Look at a teammate and press E: climb on their shoulders.\nSpace jumps off. Too high alone, easy together.\nUp to three can stack.")
	_sign(Vector3(26, 6.2, 0), "You made it. Esc for the menu.")


func start() -> void:
	hud.set_objective("Practice every move. Nothing here can hurt you.")


func _sign(pos: Vector3, text: String) -> void:
	Greybox.label(geo, pos, text, 40, TEXT, -90.0)
