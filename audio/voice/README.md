# Voice recordings

Put each actor's files in their character's folder, named after the line id:
`audio/voice/rourke/l0_greet_1.wav`, `audio/voice/warden/l1_sealed.wav`, and so on.
Files directly in `audio/voice/` work too.

The actors' scripts are in [docs/script/characters/](../../docs/script/characters/) and the full list is
[docs/script/recording-list.md](../../docs/script/recording-list.md).

The game plays a recording whenever one exists for a line and falls back to the timed subtitle when it doesn't,
so lines can arrive a few at a time. Only `<line_id>.wav` is played; to use a second take, rename it.
