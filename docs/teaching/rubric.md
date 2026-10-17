# Teaching and UX rubric

Every puzzle and level PR is checked against this before it reaches a merge checkpoint.
The audience has no coding experience. Owned by the Teaching and UX thread; fixes go to
the owning thread through the Game design plan thread.

## Teaching order (CLAUDE.md)

1. **Found in the world.** A new keyword, table or idea first appears on a terminal
   line, a sticky note or a sign, before the player needs a hint.
2. **Practised once safely.** The first puzzle that needs it has no threat running.
3. **Used under pressure.** A later puzzle needs it again while something is after you.

## Who teaches (Augustine, 2026-10-17)

Every tip and hint comes from inside the world. Nothing reads as a game UI talking
to the player (plan: "Who teaches: SYSOP, Mercer's notes and the world").

- **[SYSOP]** speaks live tips, nudges and every `.hint` tier on the terminal. SYSOP is
  Vale: never lies, knows the building, goes quiet when WARDEN watches closely.
- **Mercer's notes** ("- H.M.") on manuals and printouts, and **sticky notes**, carry
  syntax and worked examples on non-puzzle tables.
- **In-world documents** (brochures, desk cards, memos, rosters, manuals) carry table
  names, column names and codes. They count as taught, like terminal lines.
- **WARDEN never helps.** It can state facts, threaten and lie, but never says what to
  type or do. **HUD notices are only for controls** ("Hold Ctrl to crouch", "Added to
  your notebook (Tab)"), never for what to type or where to go.
- **Objectives are notebook to-dos** in the character's handwriting, never HUD text,
  and never name a puzzle's answer (no rack id, PIN, breaker or guard name).
- **Notebook-first:** each level is solvable from what a careful player wrote down
  from terminals, stickies and documents.

## Rules on every puzzle

- **Never needs anything not yet taught.** Every keyword, table, column, value and fact
  in the answer was shown in an earlier puzzle or level, or is on screen now. The player
  is assumed to remember what they were taught, never to guess.
- **Everything taught can be written down.** Each thing a puzzle teaches appears on a
  terminal line (or a sticky note), so the player is offered it as a "write note" line.
  Voice lines and HUD notices alone don't count.
- **First hint** is the exact query, then one line per keyword saying what it does.
- **Later hints** say exactly what to type and where ("add AND shift = 'night' to the
  end, before the ;"), use the real tables, never an example table.
- **Hints are opt-in tiers**, and `.hint` must still help at every step, including after
  a "lie" (the keypad says opened, the door didn't move).
- **Every decoy has a visible reason**: a `note` column, or a refusal that says why.
- **Physical steps are readable off the screen**: the rack id, PIN or breaker the player
  needs appears in the result, and the matching label exists in the world.
- **Deaths explain themselves** the first time: what killed you and what to check.

## Challenge (keep it a puzzle)

Each puzzle keeps at least one real thinking step that hints don't do for you
before the player asks:

- **Read the result**: the answer is in the output, not in a message about it.
- **Combine two clues**: e.g. a smudged name plus the shift on the sheet.
- **Act under threat**: type while something is moving.

A Level 0 tutorial step may skip this; nothing after it should.

## Lost-player test

`tests/teaching_tests.gd` plays Levels 0-2 in order as a player who knows no SQL. It
types only queries written out in full on screen and asks `.hint` when it runs out.
`tests/curriculum.gd` declares what each puzzle `teaches` and `needs`; the test builds a
cumulative taught set (every terminal line and sticky note seen so far) and fails when:

- a puzzle needs something outside the taught set before any hint,
- something a puzzle teaches never appears on a terminal line or sticky note,
- the needs list misses a keyword from the first hint's query,
- the player can't finish with at most the first hint, or can't read the physical step
  (rack, PIN, breaker) off the screen,
- a keyword is first needed under threat.

Known gaps print as `GAP` (not failures) until the owner fixes them; then they print
`FIXED` and get promoted to normal checks. **Every new puzzle needs a row in
`tests/curriculum.gd` and a step in the walkthrough.**

`tests/teaching_voice_tests.gd` scans the level, world and terminal scripts and flags
every tip spoken by WARDEN (or in WARDEN's amber), every `.hint` not from [SYSOP], and
every HUD notice that says what to type, and every to-do or objective built from a
puzzle's answer. These print as `GAP` until fixed.

Still to come: a "notes only" player that may use only lines it wrote into the notebook
(`noteable_lines()` / `write_note()`), and in-world Document lines in the taught set
once the Document interactable lands.
