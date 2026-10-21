# Art credits

Every model, texture and animation in the game is listed here with its source and licence.

**Licence rules:**
- CC0 is preferred.
- CC-BY is fine with a credit line here and in the game's credits.
- Nothing licensed non-commercial or share-alike goes in.

Packs waiting to be picked from are staged outside the repository (the project's `art/packs/`). A pack is added here when its first file is committed, and only the pieces we use are committed, never a whole pack or its `.blend` sources.

## Packs we use

| Creator | Pack | Link | Licence | What we use | Support the creator |
|---|---|---|---|---|---|
| Quaternius | Universal Base Characters (Standard) | https://quaternius.com/packs/universalbasecharacters.html | CC0 1.0 | The male and female base bodies, their skeleton, eyes and eyebrows, and the hairstyles (parted, long, buzzed, beard). Rebuilt into `assets/art/characters/body1.glb` and `body2.glb` with our own clothes, hats and glasses. | https://www.patreon.com/quaternius |
| Quaternius | Ultimate House Interior | https://quaternius.com/packs/ultimatehomeinterior.html | CC0 1.0 | The wooden chair (`wood_chair`), the desk lamp (`desk_lamp`) and the wheelie bin, repainted navy for confidential waste (`wheelie_bin`). | https://www.patreon.com/quaternius |
| Quaternius | Ultimate Furniture | https://quaternius.com/packs/ultimatefurniture.html | CC0 1.0 | The old wooden desk with drawers (`wood_desk`). | https://www.patreon.com/quaternius |
| Poly Haven | Portable Generator, Hand Truck, Worn Metal Rack, Metal Office Desk, Utility Box 01, Wall Clock | https://polyhaven.com/a/portable_generator, https://polyhaven.com/a/hand_truck, https://polyhaven.com/a/worn_metal_rack, https://polyhaven.com/a/metal_office_desk, https://polyhaven.com/a/utility_box_01, https://polyhaven.com/a/wall_clock | CC0 1.0 | Those six props, decimated to low poly with their textures flattened into one colour per face (`generator`, `hand_truck`, `metal_rack`, `metal_desk`, `utility_box`, `wall_clock`). | https://www.patreon.com/polyhaven |
| Quaternius | Universal Animation Library (Standard) | https://quaternius.com/packs/universalanimationlibrary.html | CC0 1.0 | Four clips: idle, walk, jog and sprint, copied into `assets/art/characters/locomotion.res`. | https://www.patreon.com/quaternius |

## Our own work

| Asset | Where in the repo | Built by |
|---|---|---|
| Clothes, shoes, jackets, hats, glasses, badges, lanyards and radios | inside `body1.glb`, `body2.glb` | `tools/art/build_characters.py` |
| Body paint shader (skin, shirt, trousers, shoes, lipstick) | `assets/art/characters/body.gdshader` | Hand-written |
| Furniture and fittings built in code: shelving, archive boxes, card catalogues, shredders, conveyors and the rest | `scripts/art/art_props.gd`, `scripts/art/dress_level_*.gd` (big pieces as one mesh each, `scripts/art/art_mesh.gd`) | Hand-written |
| Every game-specific pose (sitting, crouching, crawling, talking, waving, typing, falling down and more) | `scripts/art/character_rig.gd` | Hand-written |

## Rebuilding the character models

The character models are built in Blender from code, so they can be changed and rebuilt without hand editing. Both scripts read the unzipped packs (defaults point at the project's `art/packs/quaternius/`):

    pip install bpy==5.0.1          # needs Python 3.11
    python -I tools/art/build_characters.py -- assets/art/characters [BASE_CHARACTERS_DIR]
    godot --headless -s tools/art/extract_clips.gd -- [ANIMATION_LIBRARY_DIR]

The furniture from the packs is built the same way, then packed into the small compressed meshes the game loads (`assets/art/props/<id>.res`, through `ArtModels` ids `prop/<id>`):

    python -I tools/art/build_props.py -- /tmp/props [PACKS_DIR] [ID ...]
    godot --headless -s tools/art/pack_props.gd -- /tmp/props assets/art/props

Commit the rebuilt files together with the script change.

## Paid models later

Models load by id through `scripts/art/art_models.gd`. A file at the same path under `res://assets_private/` (a private assets repo, since this one is public) replaces the free one, so paid or hand-made models can drop in without code changes, and anyone without them still gets the free CC0 version.
