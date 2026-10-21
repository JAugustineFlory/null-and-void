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
| Quaternius | Universal Animation Library (Standard) | https://quaternius.com/packs/universalanimationlibrary.html | CC0 1.0 | Four clips: idle, walk, jog and sprint, copied into `assets/art/characters/locomotion.res`. | https://www.patreon.com/quaternius |

## Our own work

| Asset | Where in the repo | Built by |
|---|---|---|
| Clothes, shoes, jackets, hats, glasses, badges, lanyards and radios | inside `body1.glb`, `body2.glb` | `tools/art/build_characters.py` |
| Body paint shader (skin, shirt, trousers, shoes, lipstick) | `assets/art/characters/body.gdshader` | Hand-written |
| Every game-specific pose (sitting, crouching, crawling, talking, waving, typing, falling down and more) | `scripts/art/character_rig.gd` | Hand-written |

## Rebuilding the character models

The character models are built in Blender from code, so they can be changed and rebuilt without hand editing. Both scripts read the unzipped packs (defaults point at the project's `art/packs/quaternius/`):

    pip install bpy==5.0.1          # needs Python 3.11
    python -I tools/art/build_characters.py -- assets/art/characters [BASE_CHARACTERS_DIR]
    godot --headless -s tools/art/extract_clips.gd -- [ANIMATION_LIBRARY_DIR]

Commit the rebuilt files together with the script change.

## Paid models later

Models load by id through `scripts/art/art_models.gd`. A file at the same path under `res://assets_private/` (a private assets repo, since this one is public) replaces the free one, so paid or hand-made models can drop in without code changes, and anyone without them still gets the free CC0 version.
