# Null & Void: art and animation guide

Owned by the Graphics and animations thread. Code lives in `scripts/art/`; preview everything in `scenes/art_gallery.tscn`; screenshots come from `tools/art_shots.gd`.

## Direction

**Lo-fi realistic, VHS grain, Backrooms liminal** (game plan section 18). Simple shapes, believable proportions, real-world materials, and lighting doing the heavy lifting. We are not chasing photorealism: a clean low-poly look ages well, runs on modest PCs with six players, and agents can build it in code.

The building has two faces, and the art must sell the switch:

| Before the turn (Level 0) | After the turn (Level 1 on) |
|---|---|
| A normal 90s corporate office at night. Bright, even fluorescent light. Beige walls, teal carpet, navy branding. Nothing is broken. Faint VHS (0.08). | The same spaces, wrong. Dying tubes, thick air, sick green or emergency red, dark corners. Stronger VHS (0.3 to 0.5). |

Rule of thumb: Level 0 must be screenshot-able as a boring office. If a playtester feels uneasy before Rourke turns, the dread is coming too early.

## Palette

All colors live in `ArtPalette` (`scripts/art/art_palette.gd`). Use the constants instead of new `Color(...)` literals so a wing can be re-graded in one place.

- **Halcyon office:** beige drywall, teal-grey carpet tiles, off-white 60 cm ceiling tiles, wood-laminate desks, navy `HALCYON_NAVY` with gold accents for the brand.
- **Back of house:** concrete, brushed metal, black racks, safety yellow.
- **Devices:** beige 90s plastic, green-phosphor screens.
- **Byte-Right IT (the players):** each player wears one of six `CREW_COLORS` polos (blue, orange, green, magenta, yellow, cyan). Different hues, similar brightness, so teammates read apart in the dark and for colorblind players.
- **Light colors:** cool fluorescent (office), warm (lamps, van), sodium (car park), sick green (after the turn), emergency red (lockdown), moon blue (dark floors), screen green.

## Surfaces

`ArtPalette.surface(kind)` returns a shared, textured material: carpet, ceiling_tile, drywall, laminate, partition, concrete, floor_tile, metal, rack, asphalt, plastic, dark_plastic. Textures are 128 px, generated in code and mapped in world space (triplanar), so they line up across Greybox boxes of any size with no UVs. `tint` gives stained or faded variants without a new texture.

## Lighting moods

`ArtMood` holds five moods: `office`, `night_exterior`, `after_hours`, `lockdown`, `dark`. Each sets the WorldEnvironment (ambient, fog, exposure, glow, grade), the ceiling lights (color and energy), flicker and VHS strength.

- `ArtMood.environment(mood)` makes an Environment; `ArtMood.apply(env, mood)` switches an existing one.
- `ArtMood.apply_to_lights(lights, mood)` recolors fittings and keeps each light's own design energy. It never touches `visible`, which belongs to the `lights` table through `sync_world()`.
- `dark` keeps a sliver of ambient so floors still read. Pitch black is not scary, it is just frustrating.

## Characters

`CharacterRig.build(parent, look)` builds a low-poly person (about 25 pieces) from primitives. Looks are in `CharacterLooks`: `crew(0..5)`, `rourke()`, `vale()`, `mercer()`, `night_guard()`.

- **Rourke:** big, friendly, navy facilities jacket over a pale shirt, khakis, grey hair and mustache, badge on a Halcyon lanyard, radio on his belt. He should look like the nicest guy in the building.
- **Vale:** lab coat, dark clothes, glasses, long dark hair.
- **Mercer:** older, bald with a grey fringe, cardigan, glasses.
- **Night guard:** grey-blue uniform, cap, gold patch.
- **Crew:** Byte-Right polo with a white logo patch, belt radio, varied builds, skin tones and hair.

### Animation

Procedural, no imported clips, so it is tiny and needs no animation sync:

- **Walking and running are automatic.** The rig measures its own speed from its position each frame (teleports ignored) and drives the walk cycle. Anything that already syncs position animates correctly on every machine.
- **Actions** via `rig.play(name)`. Upper-body actions keep the legs walking: idle, talk, wave, point, radio, flashlight, type, hands_up, windup, strike. Full-body actions take over: stagger, down, dead, tied, sit, crouch, crawl. `rig.crouching` (1.25 m bent-knee stance) and `rig.crawling` (vents and low gaps; wins over crouching) follow the player's stance while they move.
- `rig.head_pitch` follows a teammate's camera pitch; `rig.look_target` turns the head toward a point (Rourke watching the crew on the tour).
- Poses blend smoothly; the body falls and gets up at a slower, weightier rate.

### Hooking it up (for the owning threads)

- **Rourke** (`scripts/npc/rourke.gd`): replace the `_part` calls in `_ready` with `_rig = CharacterRig.build(_body, CharacterLooks.rourke())`, then call `_rig.play(...)` on state changes: `windup` during the tell, `stagger`, `down`, `tied`, `dead`, `talk` while he speaks, otherwise `idle`. Drop the manual `_body.rotation.x` tilts, since the rig lies down itself. Because the rig reads `state`-driven actions and position, co-op needs no new synced properties.
- **Player puppets** (`scripts/net/player_puppet.gd`): build `CharacterRig.build(_body, CharacterLooks.crew(slot))`, set `rig.head_pitch` from the synced pitch, `rig.crouching` from `crouching`, `rig.crawling` from `crawling`, and `play("radio")` while that player transmits.
- **First person** (`scripts/player/`): `HeldItems.attach(camera, CharacterLooks.crew(slot))` shows your flashlight (with shadows) and raises the walkie while push-to-talk is held.

## Props

`ArtProps`: desk, office_chair, crt_monitor (off, green or blue screen), server_rack (lit or dead), filing_cabinet, potted_plant, water_cooler, exit_sign, troffer (a recessed fluorescent fitting with a real light whose panel glow follows the mood). Solid props are StaticBody3D with one box collider; put them under `LevelBase.geo` so navigation bakes around them. `PropFlashlight` and `PropWalkie` are the hand-held items.

## Performance budget (six players)

- A character is at most 32 mesh pieces; props at most ~10. Meshes and materials are cached and shared.
- Only big pieces cast shadows. Only the local player's flashlight has shadows; teammates' flashlights light the room without them.
- Rigs more than 30 m from the camera animate at a quarter rate; hidden rigs don't animate.
- Ceiling lights stay shadowless omnis (as Greybox does). Use a shadowed light only where a shadow is the point of the scene.
- The VHS overlay is a single full-screen pass and switches off completely at intensity 0.

## Furnishing a level

Augustine's rule: a level gets dressed only after the Game design plan thread marks it complete or ready to furnish. Dressing means swapping Greybox colors for `ArtPalette.surface()` materials, adding props, fitting troffers and a mood, and wiring characters to rigs, without moving collision the puzzles or routes depend on. Each furnished level gets before and after screenshots in its PR (`tools/dress_shots.gd`).

How it's wired, so level threads and art never edit the same lines:
- Each level's dressing lives in `scripts/art/dress_level_N.gd` (`DressLevelN.apply(self)`), called by **one line** at the end of that level's `build()`, before navigation bakes. Positions are in the wing's own space.
- `ArtDress.reskin` swaps materials on existing Greybox pieces by name and zone; it never changes their collision.
- Solid props are tagged `art_prop`; tests check they stay clear of every route, stop, terminal and panel the level needs. Add new keep-clear points to `tests/art_tests.gd` when a level changes.
- `ArtDress.link_light_panels` makes each ceiling panel follow its light: red in a lockdown, dark when the `lights` table switches it off.
- `NpcLook.attach(rourke, CharacterLooks.rourke(), hud)` gives Rourke his model from the outside: it hides his greybox body and picks animations from his `state` (wind-up, stagger, down, tied, dead) and from his subtitles (talking).

Furnished so far: Level 0 (lobby, reception, hall, closet, car park; the van waits for its six-seat rework) and Level 1 (Server Room A).
