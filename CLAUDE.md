# Null & Void: notes for agents

- Engine: Godot 4.7 (GDScript); CI pins 4.7.1. Run tests with `godot --headless --import && godot --headless -s tests/run_tests.gd`. Tests must pass before pushing.
- Design source of truth: `docs/game-plan.md`. Augustine directs, playtests and voice-acts; agents build.
- Levels build their geometry in code with `Greybox` helpers (`scripts/world/greybox.gd`), not hand-edited scenes. Static geometry goes under `LevelBase.geo` so navigation bakes from it; moving things (doors, NPCs) go elsewhere.
- Puzzles are checked by comparing result sets (`Puzzle.matches`), never by matching query text. Every new puzzle needs tests for the correct solution and for the tempting wrong ones.
- The building's state lives in `FacilityDB`. Doors and lights follow the `doors` and `lights` tables via `sync_world()`.
- Randomize per-run data from `Game.run_seed` so walkthroughs can't be copied, and test across many seeds.
- Scripts loaded by `tests/run_tests.gd` must not reference the `Game` autoload by name at parse time; use `get_node("/root/Game")` there.
- Teach in this order on every new concept: found in the world, practiced once safely, then used under pressure.
