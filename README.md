# Null & Void

A first-person co-op survival-horror escape game where the only way out is to write real code.
You're a contract IT crew trapped inside Halcyon Data Systems in 1997. The doors, lights and
robots are rows in a real SQLite database, and you learn SQL (then HTTP, JavaScript, HTML/CSS
and testing) by using it to survive.

The full design is in [docs/game-plan.md](docs/game-plan.md).

![The front desk](docs/screenshots/l0_spawn.png)

## Status

First playable slice: **Levels 0 and 1**, solo, greybox art, subtitles for placeholder voices.

- **Level 0, The Lobby:** Rourke's tour, Dr. Vale's shredded memo (`SELECT`, `FROM`, `ORDER BY`),
  walkie-talkies behind the desk (climb over it), a jammed shutter to slide under, and an optional
  vent to a forgotten closet.
- **Level 1, Server Room A:** Rourke locks you in and attacks. Knock him down, then tie him up or
  finish it. Use his badge to read WARDEN's self-test, find the faulted door controller with
  `WHERE ... AND ...`, and reset it at the right rack. The faulted rack changes every run.

## Play it

1. Install [Godot 4.7](https://godotengine.org/download) or newer (the standard version, not .NET). It's free.
2. Open Godot, choose **Import**, and select `project.godot` in this folder.
3. Press **F5** (or the Play button).

Controls: WASD move, mouse look, Shift sprint, Ctrl (or C) crouch, Shift+Ctrl slide,
Space jump/mantle, E use, X alternate action, F flashlight, left click strike, Esc pause.

Movement: jump at a high edge while pushing forward to grab it (A/D shimmy, W pull up,
Ctrl let go). Tap Ctrl in the air to roll on landing, which is quiet. Walk into a pipe or
ladder to climb it. Crouch to crawl through vents (Shift in a vent bangs the duct). Step
onto a narrow ledge to shuffle along it. Look at a teammate and press E to climb onto
their shoulders, up to three high; Space jumps off. **Movement gym** on the main menu
has a station for each.

At a terminal: type SQL and press Enter. `.help`, `.tables`, `.schema NAME`, `.hint`, `.reset`.

## Tests

Every puzzle has an automated test proving it can be solved, and that the wrong approaches fail.

```sh
godot --headless --import   # run twice on a fresh checkout; see CLAUDE.md
godot --headless -s tests/run_tests.gd
```

CI runs the same tests on every push and pull request.

Review screenshots (needs a display; on a server use `xvfb-run`):

```sh
xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 -s tools/screenshots.gd -- /tmp/shots
```

## Layout

| Path | What's there |
|---|---|
| `scripts/core/` | `Game` autoload (run state, input), `FacilityDB` (the building's SQLite database), `Puzzle` (result-set puzzle checks) |
| `scripts/player/` | First-person controller (slide, roll, mantle, ledge grab, climb, vents, ledges, shoulder stands) driven by `PlayerControls` so co-op can replay inputs; `MovementVolume` |
| `scripts/world/` | Greybox builders, `Traversal` helpers (vents, gates, climbables, ledges), doors driven by the database, terminals, triggers, interactables |
| `scripts/npc/` | Rourke |
| `scripts/levels/` | One script per level; geometry is built in code |
| `scripts/ui/` | HUD, terminal screen, menu, Field Notes |
| `data/` | Seed SQL for levels |
| `addons/godot-sqlite/` | [godot-sqlite](https://github.com/2shady4u/godot-sqlite) (MIT), desktop binaries |
| `tests/` | Headless test runner |
| `docs/` | Design plan and screenshots |
