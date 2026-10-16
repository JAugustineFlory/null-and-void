# Audit: Levels 0-2 (main @ 8120b4a, 2026-10-16)

Covers main with PRs #7 (Level 2), #15 (opening) and #16 (movement) merged.
Lost-player walkthrough: `tests/teaching_tests.gd`, seeds 7 and 23 (Level 1),
11 and 42 (Level 2). Result: every puzzle passes the teaching-order and taught-set
checks; 2 known gaps.

## Summary by puzzle

| Puzzle | Found in world | Practised safely | Under pressure | Hints a lost player needs | Thinking step |
|---|---|---|---|---|---|
| L0 peek (`SELECT *`) | boot text | yes | no (tutorial) | 0 | none (tutorial) |
| L0 memo (`ORDER BY`) | sticky "ORDER matters", WARDEN line | yes | **never in L0-2** | 1 | weak: WARDEN names `piece_no` |
| L1 controller (`WHERE`, `AND`) | self-test example on `doors` | yes (Rourke dealt with) | L2 Har | 1 | combine two clues, read id, find rack |
| L2 cameras (`GET`) | sticky note, boot text | yes (CAM-2 holds it) | L2 door | 0 | read `motion` |
| L2 Pike (`LIKE`) | roster poster, WARDEN text | yes | L2 Har | 0 | none (practice) |
| L2 Har (`LIKE` + `AND`) | sign-in sheet, WARDEN text | n/a (composed) | yes, Watcher loose | 1 | combine Har + night, read PIN |
| L2 door (`GET /doors/..`) | panel boot text, objective | GET practised on cameras | yes | 0 | read note, find breaker |

All first hints are the exact query with a line per keyword. No hint uses an example
table. Every decoy carries a reason (controller notes, guard notes, the wrong breaker
says what it runs, wrong PINs say whose they are).

## Findings

### Fix (blocks a lost player)

1. **Level 2: `.hint` at the vestibule panel goes dead after the door lies** (Level 2
   Security Office). If a player runs `GET /doors/SEC-EXIT` before entering the PIN (the
   panel's boot text invites it), `door_puzzle` is marked solved. After the PIN, the door
   stays shut and `.hint` says "Nothing left to solve here. Keep moving."
   `scripts/levels/level_2.gd:557` sets `door_puzzle.solved = true` before the
   `if not pin_entered ...` guard. Suggested fix: mark it solved only when the door is
   physically open (in `_update_door()`), so the breaker hint stays available.
   Test: GAP "`.hint` at the panel still helps after the door lies".

2. **Level 2: dying to the Watcher says nothing about why** (Level 2 Security Office;
   any new line goes to Voice and story). After CAM-2 freezes, a player who is caught
   only sees "You came to. Everything hurts." Nothing says the camera stopped watching.
   Suggested fix: on the first death after `loose`, a notice such as "CAM-2's picture
   froze at 00:52:13. It wasn't watching. GET /cameras: compare last_frame with
   server_time." Test: GAP "after the Watcher gets you, the screen says why".

### Should fix

3. **Level 2: the Har puzzle's 4th hint is about cameras**, not the Har puzzle
   (`level_2.gd:84`). Move it to the death notice in finding 2, or to the panel.
4. **Field Notes claims the CAM-2 lesson unconditionally.** The "status said live" line
   only appears if the player re-runs `GET /cameras` after the Watcher leaves the office;
   many won't. Field Notes' VERIFY line (`scripts/ui/field_notes.gd:50`) should only say
   the CAM-2 half when `_lie_explained`, or finding 2 makes sure every player sees it.
5. **Curriculum: `ORDER BY` is never used under pressure in Levels 0-2.** Level 3 or
   later should need it again with a threat running (design plan's call where).

### Consider (challenge)

6. **Level 0 memo has no thinking step.** WARDEN's nudge after the first query names the
   column ("a number in the piece_no column ... ORDER BY ... piece_no"). Saying "each
   scrap has a number; sort by the column that holds it" would make the player read the
   header themselves, while hint 1 still gives the exact query. It's the tutorial, so
   this is the design plan's call.
7. **`COUNT` and `LIMIT` are shown in Level 2 but never needed.** Fine as optional, but
   a later puzzle that needs them must first practise them safely.

### Upcoming work to check

- **Write note** (Playtest fixes): every terminal line must be notable, including hints,
  errors and `.schema` output. Please expose which lines are notable (for example a
  method on `TerminalUI`) so the lost-player test can use it instead of assuming.
- **Notebook can't open at a terminal**: the lost-player test assumes the player
  remembers everything taught. Once notes exist, add a "notes only" player that must
  pass using only the lines it chose to save.
- **Elevator endings**: check that the objective names the elevator and that a player
  who misses it gets a reminder.
