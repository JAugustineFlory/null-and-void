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

`ArtProps`: desk, office_chair, crt_monitor (off, green or blue screen), server_rack (lit or dead), filing_cabinet, potted_plant, water_cooler, exit_sign, sticky_note, car, boxes, poster, cable_tray, troffer (a recessed fluorescent fitting with a real light whose panel glow follows the mood). Solid props are StaticBody3D with one box collider; put them under `LevelBase.geo` so navigation bakes around them. `PropFlashlight` and `PropWalkie` are the hand-held items.

## Notebook, sticky notes and elevators

Designed ahead of the mechanics (game plan, "Notebook and elevators"). Playtest fixes builds the behavior with greybox stand-ins; these are the looks to swap in. Lookdev shots: `tools/notebook_shots.gd`, saved in `docs/art/screenshots/notebook/`.

- **Notebook UI** (`NotebookView`, `NotebookArt`): a 1997 spiral notebook on a navy pressboard cover, cream ruled pages with a red margin and wire coils. The player's notes are in handwriting (Patrick Hand); SQL is in a typewriter face (Courier Prime) so quotes, commas and `*` stay readable. Both fonts (and Mercer's, below) are OFL and ship in `assets/art/fonts/`. Put the view on CanvasLayer 15: above VHS (3), below the terminal (20).
  - `book.left` / `book.right` are the pages; `add_tab("Notes")` adds an index tab and emits `tab_pressed`; `show_book()`, `hide_book()`, `turn_page(callable)`, `clear_pages()`.
  - `NotebookArt.sticky(keyword, syntax, example, color)` is a found note taped onto a page; `table_card(name, columns)` is a table written down for the Tables page; `note_line(text, label)` is a terminal line copied in, a strip of green-bar printout with the player's handwritten label; `write_button()` is the small yellow "+ note" tab to put beside each terminal output line; `heading()`, `hand()`, `code()`, `margin_note()` for the rest (Field Notes too).
- **Sticky notes in the world** (`ArtProps.sticky_note(parent, pos, facing, keyword, color, flat_on_desk)`): 7.6 cm notes in canary, pink, blue or green (`ArtProps.STICKY_COLORS`), one keyword in handwriting, a strip of tape, never stuck on quite straight. They glow very faintly so a note can be spotted on a dark desk. Stick one to a CRT bezel (the corner at about `+0.17, +0.32` from the monitor's origin) or lay it on a desk top (y 0.762). Visual only: parent it under the Interactable that picks it up.
- **Elevator** (`ArtElevator.build(parent, pos, facing, interior, floors)`): brushed-steel car with center-opening doors, wood handrail, warm ceiling light, a button panel inside, a call button outside and amber floor indicators above the doors on both sides. Origin is the middle of the doorway at floor level, on the center line of the wing's 20 cm Greybox wall, facing -Z (you walk in along +Z); the steel landing face, call button and floor indicator sit just proud of that wall. It adds no collision: the mechanics own the shaft and doors and drive the look with `open_amount` (0 shut to 1 open; tween it), `set_floor("B1")`, `set_direction(-1/0/1)`, `light_button("B1")`, `light_call()` and `set_car_light(scale)` for a power cut mid-ride.

## Documents: brochures, desk cards, manuals, memos, clipboards

Where hints and table names hide in the world (game plan: in-world notes, no immersion-breaking hints). Lookdev shots: `tools/document_shots.gd`, saved in `docs/art/screenshots/documents/`.

- **Props** (`ArtProps`, visual only, facing -Z like a poster): `binder(parent, pos, facing, title, open)` (open on a desk at a manual page, or closed and standing), `desk_card(...)` (a glossy laminated tent card), `brochure(..., flat_on_desk)` (a trifold, open flat or standing in an acrylic holder), `memo(..., flat_on_desk)` (two stapled sheets on a wall, a corkboard or a desk), `corkboard(parent, pos, facing, size)` (pin memos to its face at z -0.017), `clipboard(..., flat_on_desk)` (a roster under a metal clip, on a desk or a wall hook). On a desk, `pos` is the spot on the desk top (y 0.762); on a wall, the center. Each sets meta `doc_size` (Vector3) so the mechanics can size the Interactable's collider. Body text in the world is grey bars: nobody reads it from arm's length, they press E.
- **Reading view** (`DocumentView`, CanvasLayer 15 like the notebook): the document held up close. `set_paper("memo" | "manual" | "card" | "brochure" | "clipboard")`, `set_title()`, `add_line(text)` (typed; pointing at it lays a yellow highlighter band over the line and shows a "+ add to notebook" chip at its right end, the same as on terminal lines, and the chip emits `copy_requested(text)`), `add_margin_note(text, author)` beside the last line, `add_blank(before, filled, after, author)` for a printed blank filled in by hand (adding it copies the whole sentence), `clear()`, `show_doc()`, `hide_doc()`, and `closed` from its close button.
- **Papers look real** (Augustine, Level 2 playtest). Nothing in the building is a blank sheet with typing on it: it's company stationery, a printed form, a page torn from a manual. Memos carry the Halcyon letterhead and the creases of being folded for an envelope; clipboard sheets are printed forms with a header and a form number; every paper is a little aged at the edges. Forms are filled in by hand, by different people in different pens. Accidents tell stories: a coffee spill hides a name, a red pen writes NO SHOW across a row, a rubber stamp says who logged it.
- **A Document's lines** go in whole with `add_lines(document.lines())`; `add_entry(line)` takes one. Besides typed lines, `{"text", "hand": true, "author"}`, blanks (`{"before", "filled", "after"}`) and `""` gaps, a line can be `{"columns": ["NAME", "BADGE #", "IN"], "widths": [3, 2, 1]}` (a printed ruled table: column names on a grey band), `{"row": ["PIKE, H.", "", ""], "over": "NO SHOW", "text": "..."}` (a row filled in by hand, each name in its own pen, `over` written across it in red), or `{"stamp": "RECEIVED 10/15", "color": "blue"}` (a rubber stamp in the margin over the lines above). Any line can add `"stain": "coffee"`; on a row, `"stain_at": 0` centres the spill just after what's written in that cell, so write only the letters that stay readable ("Har") and the rest shows as ink bled into the coffee. Copying a line copies its `text`; an empty row has nothing to copy.
- **Two hands.** The crew writes in Patrick Hand, blue ballpoint. Harold Mercer writes in Caveat (OFL, `NotebookArt.old_hand_font()`), dark fountain-pen ink (`NotebookArt.FOUNTAIN_INK`), slanted and a size larger, and signs "- H.M." so players learn to recognize him before they know who he is.

## Held notebook and in-world screens

No full-screen menus (game plan, "Diegetic notebook and terminals"). Lookdev: `tools/diegetic_shots.gd`, saved in `docs/art/screenshots/diegetic/`.

- **Held notebook** (`HeldNotebook.attach(camera, look)`): a pocket notebook held open low in the view, with the room still visible above it. `set_content(control)` puts a NotebookPages (or any Control holding a NotebookView) into its SubViewport, and switches that NotebookView to `embedded`, so it isn't dimmed or scaled. `open_book()` pulls it out of the pocket and opens the cover. `close_book()` puts it away; while it's away the SubViewport doesn't render. `write_in(item)` writes a line that was just added to a page: it appears left to right behind a pen nib (`NotebookView.write_in` does the 2D part). Mouse clicks and hovers on the pages are forwarded to the buttons drawn on them, so the mouse must be visible while it's open. Its size follows the camera's FOV and the window shape: the book spans 62% of the width and at most 62% of the height. `book_root` is the node for Movement to pose.
- **Picking up a paper** (`HeldPaper.attach(camera, look)`): `lift(document)` reaches out with your right hand (the arm stretches at most 55 cm; a paper further off comes to meet it), takes the paper off the desk or wall and brings it up to read in both hands, filling 80% of the view's height, then emits `lifted`. The paper in your hands is the document's own page, drawn by a DocumentView in a SubViewport from `paper_kind()`, `title` and `lines()`, lit by the room. The prop in the world is hidden while it's held. `put_back()` returns it and shows the prop again (`put_down`). Open the close-up DocumentView when `lift()` finishes and call `put_back()` when it closes. Lookdev: `tools/hands_shots.gd`.
- **Taking a sticky note** (`held_notebook.take_sticky(note, item, keep)`): with the notebook open, the book dips out of the way while your free hand reaches for the note, peels it off and presses it onto the page where `item` (the sticky you just added to the NotebookView) is; `item` stays hidden until the note lands. `keep` leaves the world note where it was and brings a copy (a note stuck to a terminal). `page_to_world(px)` turns a spot on the page image into a world position. `HeldNotebook.make_hand(parent, side, look)` builds the first-person hand both use.
- **Terminal screens** (`TerminalScreen.attach(terminal)`): dresses a Terminal as a beige CRT with a keyboard (`ArtProps.keyboard`) on the desk in front. The terminal's text is drawn on the glass through a phosphor shader with scanlines, vignette and soft glow. The greybox monitor meshes are hidden, but the collider and glow light are kept. By default the glass shows `display`, a big-type (40 px on a 1280x960 screen) copy of the transcript that a teammate can read over your shoulder. Fill it with `set_lines()`, `add_line()`, `set_title()` and `set_typing()`, and recolor it with `set_tint()`. It only re-renders when the text changes. `host(terminal_ui)` puts the interactive TerminalUI on the glass while you type (keys and clicks are forwarded), and `release()` takes it back. `focus_transform(fov)` is where Movement's camera should sit so the screen fills 85% of the view's height. `follow(terminal)` keeps the glass in step with co-op's terminal fields (`screen_changed`, `transcript`, `seated`, `typing`): one "name> text_" prompt line per player typing.

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

Furnished so far: Level 0 (lobby, reception, hall, closet, car park and the six-seat van, `DressVan`) and Level 1 (Server Room A).
