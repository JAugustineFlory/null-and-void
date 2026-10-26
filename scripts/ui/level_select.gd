class_name LevelSelect
## The Levels panel: start a run on any floor the crew has reached. Before v1.0 the
## floors nobody has reached yet can still be opened, so playtesters can go straight
## to the one they're testing; from v1.0 on they stay locked until the floor before
## them is finished.
##
## A floor counts as reached when the floor before it was finished, which the player's
## profile already records as its achievement (Cosmetics unlock sources).

## Play order: the scene key, what the floor is called, and the achievement earned
## by finishing it.
const FLOORS := [
	{"key": "level_0", "name": "Ground floor", "done": "achievement:floor_g"},
	{"key": "level_1", "name": "Floor 14  -  Server room", "done": "achievement:floor_14"},
	{"key": "level_2", "name": "Floor 22  -  Security office", "done": "achievement:floor_22"},
	{"key": "level_3", "name": "Floor 18  -  Records archive", "done": "achievement:floor_18"},
	{"key": "level_4", "name": "Floor 10  -  Power plant", "done": "achievement:floor_10"},
	{"key": "level_5", "name": "Floor 9  -  Personnel wing", "done": "achievement:floor_9"},
]


## True while every floor can be opened from the Levels screen: playtest builds,
## until `game/levels_any_floor` in project.godot is turned off for release.
static func testing() -> bool:
	return bool(ProjectSettings.get_setting("game/levels_any_floor", true))


## How far the crew has got: the number of floors they can start on, at least one.
static func reached(earned: Array) -> int:
	var n := 1
	for floor_entry in FLOORS:
		if floor_entry.done in earned:
			n += 1
	return mini(n, FLOORS.size())


## The panel, over `parent`. A floor picked starts a fresh run on it, or, with
## `on_pick`, hands its key (a Game.LEVELS key) to whoever opened the panel: the
## garage's nav bar picks the floor a co-op host's crew will start on.
static func open(parent: Node, on_pick := Callable()) -> MenuModal:
	var m := MenuModal.open(parent)
	var net := parent.get_node_or_null("/root/Net")
	var earned: Array = net.profile.earned if net and net.profile else []
	var open_to := reached(earned)
	m.box.add_child(SettingsPanel.heading("Levels"))
	for i in FLOORS.size():
		var floor_entry: Dictionary = FLOORS[i]
		var locked := i >= open_to
		var b := SettingsPanel.button(floor_entry.name)
		b.disabled = locked and not testing()
		if locked:
			b.text += "   (not reached yet)"
		var key: String = floor_entry.key
		b.pressed.connect(func(): _picked(parent, m, on_pick, key))
		m.box.add_child(b)
	var gym := SettingsPanel.button("Movement gym  -  practice jumps and climbs")
	gym.pressed.connect(func(): _picked(parent, m, on_pick, "movement_gym"))
	m.box.add_child(gym)
	m.add_back()
	return m


## A row was pressed: hand it over if someone's waiting for it, else start there.
static func _picked(parent: Node, panel: MenuModal, on_pick: Callable, key: String) -> void:
	if on_pick.is_valid():
		panel.close()
		on_pick.call(key)
		return
	var game := parent.get_node("/root/Game")
	game.new_run()
	game.goto(key)
