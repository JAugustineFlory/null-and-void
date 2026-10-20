# SYSOP: style guide for terminal tips

**Team only. This file contains a spoiler.** It isn't generated and never goes to actors.

SYSOP is an unknown user who messages the players' terminals as `[SYSOP]: ...`. Every live tip, nudge and tiered `.hint` comes from SYSOP. WARDEN never helps. SYSOP is Dr. Iris Vale, steering the crew from the vault, and the players learn this at the Level 10 reveal. Everything SYSOP says has to still be true once they know that.

SYSOP is **text only**. It never gets a voice line, so Vale's actor can't give the reveal away. A test checks that `voice_lines.gd` has no SYSOP speaker and that no actor script mentions SYSOP.

## Voice

- **Terse.** One or two short lines. No greetings and no sign-off. Typed fast, the way you'd type when someone could walk in.
- **Kind.** On the players' side, never smug. "Good." is the most praise SYSOP gives.
- **A little hurried.** Lowercase is fine, and so is a dropped word. No typos in SQL, though: the query has to work exactly as written.
- **Never lies.** If SYSOP doesn't know, it says nothing. SYSOP never repeats one of WARDEN's fake-outs. When the terminal lies, SYSOP is the one who says to check.
- **Never explains who it is.** If asked, there's no answer, or a deflection like `not now.`
- **Knows the building.** Room names, table names, which controller sticks, where the vents go. Vale built these systems.
- **Goes quiet when WARDEN is watching.** While WARDEN is active nearby (a lockdown, a camera on the players, a WARDEN line playing), SYSOP waits, or cuts off mid-message with `--` and comes back later.

## When SYSOP notices the crew are beginners (approved 2026-10-20)

Once per run, at the first plain beginner's slip under pressure from the Level 2 lab escape onward (a query with no FROM, a typo like `FORM`, or a hint's explanation line pasted along with the query), SYSOP stops and changes gear:

```
[SYSOP]: wait.
[SYSOP]: you've never done this before. any of you.
[SYSOP]: ok. that's fine. we go slower.
```

From then on SYSOP is more patient: one step per line, one plain "why" per hint, and `good. that's it.` as its top praise. It never says "easy", "simple" or "just", and it still goes quiet around WARDEN. Before: `exit's controller is zone A, status 'fault'. two conditions, join them with AND.` After:

```
[SYSOP]: you need the controller that matches two things.
[SYSOP]: first: zone A. second: status 'fault'.
[SYSOP]: put AND between them so both have to be true.
```

It holds up after the reveal: Vale has just realised the people she's steering out are amateurs, and she has no one else.

## Hint rules (from the puzzle guidance)

- The **first hint is the exact query**, with each keyword explained in a few words.
- Later hints say exactly what to type and where.
- Hints use the in-world names: the table and column names the players can see.

## Examples

```
[SYSOP]: the scraps are numbered. sort them:
[SYSOP]: SELECT * FROM memo_fragments ORDER BY piece_no;
[SYSOP]:   ORDER BY piece_no = smallest piece first
```

```
[SYSOP]: don't trust that echo. check door_status, not door_commands.
```

```
[SYSOP]: exit's controller is zone A, status 'fault'. two conditions, join them with AND.
[SYSOP]: --
```

## Keep the reveal fair

- SYSOP never uses Vale's spoken habits from the Level 2 voicemail ("I'm sorry", "please"). Save one deliberate echo for late in the game, as a clue that's fair on replay. That's the architect's call.
- SYSOP never signs anything, not even with initials. Vale's memo is signed "I.V.".
- SYSOP's timeline has to fit the reveal. SYSOP is active only after Vale's last badge swipe, which is after the Level 2 voicemail (SUN 10/12 1:52 AM).

## What changed in WARDEN's lines

WARDEN's voiced tips were rewritten, keeping the same line ids. WARDEN is a security system, not a villain: silent in Level 0, where only its cheerful pre-recorded PA tapes play (subtitled as PA), and cold and hostile once protocol is breached (Level 1 on). It never helps in either phase. The level threads still own the printed `WARDEN: ...` terminal tips and notices in `scripts/levels/`, and should move those to `[SYSOP]` (see the list in the PR). Two WARDEN lines play voice-only, next to terminal text: `l0_sort_hint` and `l1_found`. Once that terminal text belongs to SYSOP, those two should show their subtitle (`hud.line(id)`), so WARDEN's line is still readable.
