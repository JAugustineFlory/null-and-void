# Environment kit

Hands-on puzzles for alternate routes, gear and secrets (plan: `environment-play.md`, E3-E6).
Code stays every floor's gate: these never replace a query. They may stand in front of a
terminal (find its keyboard), never instead of its puzzle. Teach each piece in the usual
order: found in the world, practiced once safely, then used under pressure.

Every piece is co-op safe on its own: a press goes to the host with what the presser
carries, the host decides, and every machine plays it out. Wire the floor's own reaction
to the piece's signals inside a `sync.event` if it changes shared state beyond the piece.

| Piece | Make it | Signals / state |
| --- | --- | --- |
| Gear on the floor | `GearPickup.make(parent, "fuse", pos)`, or `GearPickup.place(parent, "fuse", [spot_a, spot_b, spot_c], "g_fuse")` for a seeded spot | `picked(peer, item, left)` |
| Roller shutter | `Shutter.make(self, id, pos, size)`; `cycle = Vector2(open_s, shut_s)` to run by itself, or `set_open(bool)` from a `sync.event` | `settled(open)`, `gap()` |
| Gear train | `GearTrain.make(parent, id, pos, facing, shutter, starts_jammed)` | `jam_changed(jammed, peer)` |
| Fuse box | `FuseBox.make(parent, id, pos, facing, ["LIGHTS", "STAIR DOOR"], [FuseBox.seeded_blown("g_box", 2)])` | `circuit_changed(circuit, live, peer)`, `is_live(circuit)` |
| Patch panel | `PatchPanel.make(parent, id, pos, facing, ["RM 101", "LOBBY"])`; `required` for the lines that matter | `patched(port, jack, peer)`, `solved`, `is_linked(label)` |
| Stuck thing | `ItemLock.make(parent, id, center, size, "crowbar", use_text, need_text)` | `opened(peer)` |
| Broken or switched-off terminal | `TerminalRig.attach(terminal, ["power", "keyboard"], fuse_box, "TERMINALS")` | `fixed(part, peer)`, `assembled` |

Rules that come with it:
- **Gear** (`Inventory.GEAR`: keyboard, power cord, fuse, crowbar, fire extinguisher) takes a
  hotbar slot, and a player carries at most four. Full hands swap with what's on the floor.
  Small things (screwdriver, cable, keys) still go in the bag.
- **Words**: every prompt the kit says is in `kit_words.gd`, and item names are in
  `Inventory.ITEMS`. Fuse and patch labels and a lock's two lines come from the floor, and go
  to Augustine word for word like any other text.
- **Seeds**: put gear and faults somewhere new each run with `GearPickup.place`,
  `FuseBox.seeded_blown` and the patch panel's own shuffle, and test across many seeds.
- **Bodies**: a shutter jammed part-way is a crawl gap. Keep any route under one at least
  1.0 m tall, and add the floor to the `bodies` sweep as usual.
- **Sound**: each piece plays its own sound where it is (`KitPiece._sound`). The bench's
  sweep (`tests/kit_tests.gd`) checks every piece has one.
- `tests/kit/kit_bench.tscn` has one of everything, if you want to see them.
