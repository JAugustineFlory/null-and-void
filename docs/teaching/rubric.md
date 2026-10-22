# Teaching and UX rubric

Every puzzle and level PR is checked against this before it reaches a merge checkpoint.
The audience has no coding experience. Owned by the Teaching and UX thread; fixes go to
the owning thread through the Game design plan thread.

## Teaching order (CLAUDE.md)

1. **Found in the world.** A new keyword, table or idea first appears on a terminal
   line, a sticky note or a sign, before the player needs a hint.
2. **Practised once safely.** The first puzzle that needs it has no threat running.
3. **Used under pressure.** A later puzzle needs it again while something is after you.

**Every piece is introduced before players use it** (Augustine, 2026-10-21). A word with an Easy SQL
chapter has its chapter unlock once, at its map moment, before the puzzle that first needs it (for example,
Ch 2's ORDER BY unlocks when the memo's scraps print out of order). Chapters come in quietly and the book is
reference (Augustine, 2026-10-22: no quizzes, no book popups), so ladder A's first hint still explains every
keyword: a player who never opens the book meets each word before using it. Only these words are deliberately
learned without a chapter, from a reference found in the world:
- **IS NULL** (floor 18), from Mercer's reference card.
- **Auth tokens** (Act 2), from an IT admin's runbook page.

Any other word a puzzle needs without its chapter having unlocked is a bug.

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
- **Hint ladder (option A, Augustine 2026-10-18).** Players find the value; hints teach
  how, and only the last one gives it away:
  1. **Hint 1** is the query's shape with the value left as a named blank such as
     `enter_column_name` or `'enter_zone'` (Augustine, 2026-10-22: never `?`), one line per keyword
     saying what it does, and where the value can be found ("the zone is whichever one
     the stuck doors share"). It never contains the value.
  2. **Hint 2** says how to find the value (which paper, room or query), without the
     full query.
  3. **The last hint** is the exact query, and typing it solves the puzzle.
  All hints use the real tables, never an example table, and say exactly what to type
  and where.
- **Review ladder (Augustine, 2026-10-21).** A word already practised safely on an
  earlier floor can use a two-step ladder: hint 1 is the shape with a named blank and where the
  value is, with no line per keyword; hint 2 is the exact query. Only for review: the
  first puzzle that practises a word always uses ladder A.
- **Every gate is a short investigation** (plan/depth-pass-floors-0-2.md): a step's
  result is the next step's input, and values come from data or the world, not from a
  hint paper or a SYSOP line.
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

`tests/teaching_tests.gd` plays Levels 0-3 in order as a player who knows no SQL. It
types only queries written out in full on screen and asks `.hint` when it runs out.
`tests/curriculum.gd` declares what each puzzle `teaches` and `needs`; the test builds a
cumulative taught set (every terminal line and sticky note seen so far) and fails when:

- a puzzle needs something outside the taught set before any hint,
- something a puzzle teaches never appears on a terminal line or sticky note,
- the needs list misses a keyword from the exact-query hint,
- a puzzle breaks the hint ladder (checked every time a puzzle is walked, on every
  seed): hint 1 isn't the exact query's shape with a named blank, gives the value away, or lacks
  a line per keyword; a middle hint holds the full query; the exact query doesn't solve
  the puzzle; or a hint uses an example table. A puzzle with no value to find is
  marked `"ladder": "exact"` in the curriculum and keeps an exact first hint. A review
  puzzle is marked `"ladder": "review"`: exactly two hints, and no line per keyword,
- the player can't finish once a hint gives the exact query, or can't read the
  physical step (rack, PIN, breaker) off the screen,
- a keyword is first needed under threat.

The lost player never fills in a blank itself: that's the thinking step the ladder
leaves to real players. Keywords include `DESC`, `>` (a comparison with a value) and
`COLUMNS` (SELECT naming columns instead of `*`).

**The lab's response clock is measured, not estimated.** In the lab walk, game time passes
as a first-time player would spend it: reading new text at 15 characters a second,
4 seconds to decide each command, typing at 2.5 characters a second, and 10 seconds
to cross to the switch wall. The run prints the seconds used per seed and fails if
the security response arrives first.

Known gaps print as `GAP` (not failures) until the owner fixes them; then they print
`FIXED` and get promoted to normal checks. **Every new puzzle needs a row in
`tests/curriculum.gd` and a step in the walkthrough.**

`tests/teaching_voice_tests.gd` scans the level, world and terminal scripts and fails on
every tip spoken by WARDEN (or in WARDEN's amber, or in its subtitled voice lines), every
`.hint` not from [SYSOP], every unsigned tip, every HUD notice that says what to type, and
every to-do built from a puzzle's answer. An indented line (an example query) belongs to
the line above it; a device readout in capitals ("MOTION SENSOR: ...") isn't a tip.

Documents (papers read with E) count as found in the world. Still to come: a "notes
only" player that may use only lines it wrote into the notebook (`noteable_lines()` /
`write_note()`).
