# Null & Void: notes for agents

- Engine: Godot 4.7 (GDScript); CI pins 4.7.1. Run tests with `godot --headless --import; godot --headless --import && godot --headless -s tests/run_tests.gd` (a fresh headless import on 4.7.1 can crash on exit after finishing, so import twice). Tests must pass before pushing.
- Design source of truth: `docs/game-plan.md`. Augustine directs, playtests and voice-acts; agents build.
- Levels build their geometry in code with `Greybox` helpers (`scripts/world/greybox.gd`), not hand-edited scenes. Static geometry goes under `LevelBase.geo` so navigation bakes from it; moving things (doors, NPCs) go elsewhere.
- Puzzles are checked by comparing result sets (`Puzzle.matches`), never by matching query text. Every new puzzle needs tests for the correct solution and for the tempting wrong ones.
- The building's state lives in `FacilityDB`. Doors and lights follow the `doors` and `lights` tables via `sync_world()`.
- Randomize per-run data from `Game.run_seed` so walkthroughs can't be copied, and test across many seeds.
- Scripts loaded by `tests/run_tests.gd` must not reference the `Game` autoload by name at parse time; use `get_node("/root/Game")` there.
- Teach in this order on every new concept: found in the world, practiced once safely, then used under pressure.
- Co-op (`scripts/net/`): the host decides and every machine plays it out. Host-side handlers (triggers, puzzle matches, `Interactable.used`) call `sync.event("_method", [args])`, which runs that level method everywhere in order; never change shared state only on one machine.
- NPCs are simulated on the host: call `sync.replicate(npc, props)` in the level's `net_setup()`. Level text for a terminal goes through `terminal.print_line()` (screens are shared), not `ui.print_line()`.
- Use `Trigger.require_all` when everyone must be present (traps, level exits). Set a body's transform before `add_child`, or it sits at the origin for one physics step and can fire triggers there.
