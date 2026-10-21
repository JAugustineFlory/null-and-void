# NULL & VOID: Game Plan (v3)

*Repo copy of the project's living plan, synced on 2026-10-21. Paths starting `plan/` are planning files kept in the project's shared files, not in this repo.*

*Working title. Alternatives: **SELECT * FROM Shadows**, **Dead Lock**, **Root Access**.*

A first-person co-op survival-horror detective escape game for 1 to 6 players. You are physically inside a locked-down facility, sprinting, crawling through vents and edging along ledges while something hunts you. You can't get out without writing **real code**: SQL, HTTP, JavaScript, HTML/CSS and tests. Players leave knowing things they can use on Monday.

**Feel references:** The Backrooms (a new entity per level), Lethal Company and R.E.P.O. (radio co-op horror), Destiny (fluid first-person movement), Mirror's Edge (traversal), Keep Talking and Nobody Explodes (split information).

**What changed in v3:** code is now required on every critical path; locking doors behind you is a running mechanic; the story opens with a traitor escort and ends with an evidence escape and a hidden rescue; the safe room has a real backstory; all-terminal events scale with player count; the portable deck gains upgrades and player-built UI; a lights-out level was added; the curriculum is spread and interleaved over 12 levels; testing (TDD) is a core thread; the cap is now 6 players.

---

## 1. Design pillars

1. **Real skills, no fake syntax.** Real SQLite, real HTTP, real JavaScript, real HTML/CSS.
2. **The building is the database.** Doors, lights, cameras, arms and elevators are data. Changing the world means changing data.
3. **You are there.** First person, fluid movement, physical presence and physical danger.
4. **Trust, then verify (then test).** Terminals can lie. Checking your work, and later writing tests, is how you survive.
5. **Code is always the key; skill picks the route.** *(Revised.)* No critical path can be completed without writing code. Movement, teamwork and nerve change *which* path you take, how fast, and what you avoid, but never replace the code. See section 5.
6. **Seal what's behind you.** Entities follow. Locking, quarantining and shutting things down behind you is part of every level.
7. **Completable.** About 12 levels, 30 to 45 minutes each, roughly 7 to 8 hours. Each level ends with a "Field Notes" card.

---

## 2. Story

### The setup
Halcyon Data Systems, an isolated research campus, 1997. Its heart is **Halcyon Tower**, a 30-storey glass-and-concrete skyscraper standing alone over dark woods and car parks (Augustine, 2026-10-19: window ledges only make sense high up). Each level is one floor of the tower; the elevator indicator shows real floor numbers, and every outside window looks down on the campus lights far below. Floor map (Augustine approved G/14/22 2026-10-20 via #74; Act 2 approved the same day moves the Records Archive to 18, on the stairs down): G ground floor (L0), 9 payroll, 14 server floor (L1), 18 Records Archive (L3), 22 security floor (L2), 30 the director, plus basements (B1 and below). Every floor has emergency stairs signed "do not use elevators"; people work other floors by day. **Story, book and combat rework (approved 2026-10-20): see `plan/act2-story-teaching-combat.md`; it wins over older text here.** CRT terminals, beige servers, humming fluorescent tubes, VHS tapes, endless liminal corridors.

The players are a contract IT crew called in at 11 p.m. to "fix a database problem." Officially, Dr. Iris Vale, the lead engineer, is missing and her systems need recovering.

**The real reason they're there:** the director needs scapegoats. Vale discovered his unsafe experiment, and he plans to pin her disappearance on the outside contractors.

### The escort (Level 0 to 1)
A friendly facilities manager, **Dale Rourke**, meets the crew at the gate and gives them the tour. He's charming, chatty, and the director's plant.

On the walk he explains the job and the building's history:
- Halcyon's founder and first CEO, **Harold Mercer**, fought against wiring the campus to an AI. The board fired him and installed WARDEN anyway.
- There's an old rumor that Mercer built a **safe room** somewhere in the building, cut off from the grid and the network so it could never be hacked. Rourke laughs it off.

Rourke leads them to the first server room, then locks the door with himself inside and attacks. The players must stop him:

| Choice | Consequence |
|---|---|
| **Kill him** | He was the only one with authorization. His badge's dead-man switch fires and WARDEN triggers a full lockdown immediately. |
| **Knock him out and tie him up** | The players move on. Later he escapes and either manually triggers WARDEN's protocols or flees the building, which triggers it. He can return later as a human threat (Level 7 and the finale). |

Either way the lockdown starts. The choice changes later scenes and dialogue, not whether you can finish.

### Early story beats (from the Voice and story thread, PR #5)
- **Mercer's cassette** (Level 0 vent closet) hints that he built a room WARDEN can't enter and that "the building's records remember where". This sets up Level 3's floor plan; Level 3 still confirms it.
- **WARDEN** says "a copy has been sent to the director" when Vale's memo is rebuilt.
- **Level 2 lines:** an escaped Rourke radios that the night guard "hasn't been seen since Tuesday"; if Rourke is dead, WARDEN says the escort is unavailable. Vale's voicemail to the night desk asks them to pull camera nine's tape (cold lab) and not give their PIN to "Dale". Its timestamp must come before her last badge swipe, so it doesn't spoil that she's alive.

### WARDEN
The facility's security system (Augustine, 2026-10-17). It is not a villain by nature. Until protocol is breached and the crew loses its escort, WARDEN is neutral and procedural: polite announcements, access checks and policy reminders, like any building system. Once protocol is breached (Rourke turns, is killed, or is gone), it treats the crew as intruders. It becomes cold, then increasingly hostile: lockdowns, refusals, warnings and diagnostics that may lie. Later it actively fights the players (see Level 7). It never gives tips or hints at any stage. The Level 0 PA announcer is WARDEN's own pre-recorded PA module (Augustine, 2026-10-17); its awakening arc and the final fight are in `plan/warden-arc.md` (approved 2026-10-17).

### Mercer's safe room (the hub)
Found in Level 3. Mercer's rumor was true: a sealed room with no network, no grid power (a generator and battery bank) and analog locks. WARDEN can't see or hear inside.

- **Why it's safe** is now a story fact, not a game rule.
- It has an **air-gapped terminal** with an old offline copy of the database. Players bring data back on **floppy disks** to load it, and learn that the offline copy can be stale (a real lesson in replication and sync).
- It holds the **cork board** (section 4) and a workbench for **deck upgrades** (section 6).
- Some levels return to it; others are too far away and you're on your own.

### What players believe and what's true
- **What they believe:** Vale is dead. The evidence says so: her last badge swipe is into the incinerator wing, `employees.status` says `deceased`, and there's blood in her office.
- **Their goal:** get out alive and clear their names by collecting Vale's research and proof of what the director did.
- **The reveal (end of Level 10):** some of the terminal "fake-outs" weren't WARDEN. Someone has been quietly editing rows to steer the players. The `rows affected` log traces back to an account that should be dead. Vale is alive, hiding in the vault, and she edited her own death record.

### Evidence, endings and rewards
The game is won by **escaping with the evidence**, not by pinning the right answer.

- **Evidence is physical:** floppy disks with exported tables, Vale's lab notebook, a VHS security tape, a Zip disk of the director's deleted files, printed audit logs. Players carry it and can lose it (dropped when downed, recoverable).
- **Side quest: get Vale out alive.** After the reveal she joins the escape. She's slow, injured, and the entities want her most.

| Ending | Evidence | Vale | Result |
|---|---|---|---|
| **Exonerated** | Complete | Alive | Best ending. The director is arrested, Vale testifies, unlocks a bonus epilogue and her research notes as a playable "Vale's Lab" challenge set. |
| **Cleared** | Complete | Lost | You're cleared; the experiment is buried. Bittersweet. |
| **Suspects** | Partial | Alive or lost | You escape but stay under investigation. A hook to replay. |

Rourke's fate (dead, captured, escaped) adds variations to each ending.

**Evidence tab (Augustine, 2026-10-19, for a later level):** once the crew knows it's been framed, the notebook gains an Evidence tab. At a printer terminal, players re-run queries on tables they found on earlier floors (`badge_log`, the syslog, `visitors`) and print the results as physical evidence. This is why the notebook keeps a list of the tables they've found. The Level 2 frame records stay as they are until then.

---

## 3. Players, comms and playstyles

### 1 to 6 players
Six is the cap, scaled by design rather than bolted on (see section 13 for why games usually stop at 4). With 5 or 6, playstyles can be filled in pairs, like two Operators or two Climbers.

| Playstyle | What they do |
|---|---|
| **Operator** | Writes queries and scripts at a terminal; controls doors, lights, arms, elevators. |
| **Archivist** | Collects and reads paper, keeps the cork board, feeds the Operator what they need. |
| **Verifier / Scout** | Confirms doors really opened, watches cameras, tracks entities, writes checks. |
| **Climber** | Takes movement routes: vents, ledges, shafts; carries evidence. |

Nobody is assigned a role. Anyone can do anything.

### Comms progression
- **Levels 0 to 5: walkie-talkies.** Push-to-talk, limited range, battery, heavy static near entities. Otherwise proximity voice.
- **Level 5: the radio becomes unsafe.** The Mimics can speak on it in a teammate's voice.
- **Level 6 onward: earpieces.** Hands-free, always-on, longer range. The Mimics can't get in.

### Solo play
- You physically run between terminal, paper and door.
- The portable deck (Level 4) lets you query from any network jack.
- Team-only physical moves have solo alternatives (stack crates, find a ladder, use the robot arm as a step).
- All-terminal events are solved by **writing a script** that runs the other terminals for you (section 7).

---

## 4. The cork board (optional, encouraged)

In the safe room, never required. Players who can hold it all in their heads can skip it. Uses:

- **Database map (an ERD).** Pin table cards and run string between related columns. The game gives you blank table cards when you first query a new table.
- **Floor maps.** Sketch and pin floor layouts as you explore.
- **Fragment assembly.** Physically piece together torn notes.
- **What we know / how we get out.** Sticky notes for leads, options and suspects.
- **Printouts.** Print query results on the dot-matrix printer and pin them.

Later, the deck can photograph the board and carry a copy (section 6).

---

## 5. Code is the key: routes and obstacles

Every level's critical path has at least one **code gate**. Routes differ in *how much* and *what else* they need.

### Example: the ceiling access panel (Level 4)
| Route | Needs |
|---|---|
| **Fast** | `UPDATE arm SET ...` to move the robot arm under the panel **and** one player on another's shoulders to reach it |
| **Solo / careful** | A longer query sequence to move the arm in steps, then climb the arm itself |
| **Advanced coder** | A transaction that moves the arm, cuts the fan and unlocks the panel in one go, with a verify query, so even one player can climb straight up |

### Entity encounters: bypass or brave
Code can also **avoid** an entity, or skill can get you **past** it:
- **Bypass:** reroute through a vent by opening the vent grate with code, kill the cameras the Watcher uses, trigger a noise decoy in another room.
- **Brave it:** open the main door and sneak, sprint, slide, throw a distraction, or blind it with a light burst. Still requires the code to open that main door.

### Seal what's behind you
Entities follow you between areas. Each level ends with a **lockdown checklist** you can complete or skip:
- `UPDATE doors SET locked = 1 WHERE zone = 'C'` and verify it actually locked.
- Quarantine an entity: cut power to its zone, shut down the Custodian's charging bay, flood a vent with halon.
- Rewards for doing it well: the next level starts calmer; skipping it means that entity can appear again later.
- Lessons: cleaning up after yourself, closing what you open, least privilege.

### Replay rewards
- **Route medals** for each route per level.
- **Scenarios:** seeded data, different faulty doors, remixed entity behavior.
- **Challenge modifiers:** no hints, no map, lights-out, no `ROLLBACK`, hardcore (evidence lost on death).
- **Language unlocks:** replay scripting levels in **Python** instead of JavaScript, or SQL levels in **PostgreSQL** dialect.
- **Ranks:** time, hints used, data integrity, verified-before-trusting, doors sealed.

---

## 6. The portable deck

Found in Level 4. A ruggedized 1997 laptop that plugs into any network jack.

### Built-in apps
- **Terminal:** SQL, then API console, then script editor.
- **Camera:** take photos of notes, maps and the cork board.
- **Map:** auto-fills as you explore and from floor-plan data you query.
- **Notes:** pinned text and query results.

### Upgrades (at the safe-room workbench)
| Upgrade | Unlocked by | Does |
|---|---|---|
| Battery pack | Level 4 | Longer use away from jacks |
| Wireless card | Level 6 | Query near access points, no jack needed |
| Camera feed | Level 7 | View CCTV on the deck |
| Script runner | Level 8 | Save and rerun your own scripts |
| **Custom UI** | Level 10 | Build your own deck apps in HTML/CSS/JS: a cork-board replacement, an entity tracker, a dashboard |

Custom UI is a real reward for strong players: an endless sandbox where what you learned in Act III becomes your own tool.

---

## 7. All-terminal events

Some moments require **every player at a separate terminal at the same time**, in different rooms. The tension: you're alone, typing, and you have to trust your room is safe.

Scaling: the job splits into one part per player.
- **Quorum unlock:** the vault needs N authorization codes entered within 10 seconds of each other (a two-person rule, scaled to N).
- **Sharded data:** the evidence table is split across servers, one per player. Each player queries their shard; together the answers make the key.
- **Distributed transaction:** every terminal must `COMMIT` its part; if any one fails, all of them roll back.

Before an event, players secure their rooms (lock doors, kill lights, check cameras). During it, entities roam.

**Solo version:** write a script on the deck that sends the commands to the other terminals for you, and trigger it from the one you're at. Doing it by hand is possible but frantic.

Appears in Levels 8 and 11, with a smaller 2-terminal teaser in Level 4.

---

## 8. Movement and traversal

First-person and fluid: sprint, slide, crouch, roll, crawl, mantle, climb, ledge-shuffle.

| Move | Use |
|---|---|
| **Slide, crouch or roll** under half-walls, jammed shutters, and partly opened or broken gates | Fast escapes, shortcuts |
| **Crawl** through vents | Hidden routes, avoiding entities. Loud if you bang the walls. |
| **Ledge-shuffle**, flat against the wall outside a window | Reaching rooms from outside |
| **Climb** pipes, shelves, shafts, elevator cables | Reaching other floors |
| **Mantle / vault** | Fluid chases |

**Co-op moves:** boost, shoulder stand (up to 3 high with 3 players), pull-up, hold a door.

**Code-driven moves:** robot arm, freight elevator, cranes, conveyor belts, retractable catwalks.

---

## 9. Unreliable feedback: the terminal lies

After a command, an echo like `> DOOR E4: OPENED` appears. It can be:

1. **True.** It opened.
2. **Hardware fault.** The database changed but the door jammed. Check `door_status` (the sensor), not `door_commands` (the request), or send someone to look.
3. **Fake-out.** The table never changed. A `SELECT` afterward, or "rows affected: 0", exposes it. Early on, WARDEN does this. Later, some fake-outs are Vale steering you (the Level 10 reveal).

Some levels show door indicators on a map, some are terminal-only, and some give CCTV. The lesson: a request being acknowledged isn't the state changing.

---

## 10. Testing as a core skill (TDD)

Testing grows through the whole game, tied to "trust, then verify":

| Stage | Level | What players do |
|---|---|---|
| **Read tests** | 1 | WARDEN's diagnostics print pass/fail checks. Players read them to find what's broken and where to go. |
| **Verify after writing** | 2 to 4 | Run a `SELECT` after every `UPDATE`. A check query that should return 0 rows is a test. |
| **Write checks** | 5 to 6 | Save check queries on the deck; rerun them to see whether a door, zone or record is in the right state. |
| **Write assertions** | 7 to 8 | `assert(lights.on === true)` in a watchdog script; API response checks (`expect(status).toBe(200)`). |
| **Test first (TDD)** | 9 | Write tests that describe what the Custodian should do, watch them fail, fix the code, watch them pass. |
| **Regression test** | 11 | Prove the SQL-injection fix works and stays fixed. |

---

## 11. Curriculum: three acts (option B)

**Approved by Augustine on 2026-10-21 ("Curriculum option B").** The options and reasons are in `plan/teaching/curriculum-acts-options.md`, and the eight decisions are recorded in `plan/approvals/curriculum-b.md`. Chapters, hints, SYSOP tips and story lines that come out of it still go to Augustine word for word.

- **Act 1: read the building (Levels 0 to 3).**
  - Act 1 teaches SQL for reading, and with it the three habits the rest of the game leans on: patience, attention to detail, and how to learn.
  - Its last new word, `IS NULL`, comes from a reference card rather than a lesson.
  - It ends in Mercer's safe room.
- **Act 2: fix the building's backend (Levels 4 to 7), on the way down.**
  - The `main_doors` write is the last new SQL. Containment protocol Epsilon then locks the database to read-only, so changes go through the building's web services.
  - After that, the crew writes its first scripts.
  - It ends with the lifts running again.
- **Act 3: fix what reality shows (Levels 8 to 13), on the way back up.**
  - Reality's glitches are display bugs.
  - 3a (Levels 8 to 10) is HTML and CSS. 3b (Levels 11 to 13) is JavaScript in the browser.
  - There is a hub between the halves.
- **The finale (Level 14)** uses everything, and ends on security.
- **One language for both acts.** JavaScript carries Act 2's scripts and Act 3's pages, because browsers only run JavaScript. Other languages come later as DLC (section 14).

Every new concept is found in the world, practised once safely, then used under pressure. Each level adds a few new words and reuses earlier ones.

| Act | Lvl | SQL | HTTP / services | Scripts (JavaScript) | Pages (HTML, CSS, JS) | Testing |
|---|---|---|---|---|---|---|
| 1 | 0 | `SELECT`, `FROM`, columns, `ORDER BY`, `DESC`, `LIMIT` | | | | |
| 1 | 1 | `WHERE`, `=`, quotes, `AND`, `OR`, `>`, `<`, `COUNT` | | | | Read diagnostics |
| 1 | 2 | `LIKE` | `GET`, an id in the path, JSON | | | Verify by reading |
| 1 | 3 | `GROUP BY`, `DISTINCT`, `IS NULL` (looked up, not taught) | | | | |
| 2 | 4 | `UPDATE ... WHERE`, `INSERT` (the last new SQL) | | | | Verify after write |
| 2 | 5 | (reads only from here) | `POST`, `PATCH`, a JSON body, status codes, headers, API keys | | | Check the response |
| 2 | 6 | | | First script: variables, `if`, loops, waiting | | Saved checks |
| 2 | 7 | | Auth tokens | Functions, lists, many devices, logs | | Test bench before running; assertions |
| 3a | 8 | | | | Inspect a page, elements, attributes, `hidden` | |
| 3a | 9 | | | | CSS selectors, `display`, `visibility`, `position`, `z-index` | |
| 3a | 10 | Read `audit_log` (the reveal) | | | Forms and layout | UI checks |
| 3b | 11 | | | | DOM, `querySelector`, events | |
| 3b | 12 | | The network tab | | `fetch` from a page to Act 2's services | API checks |
| 3b | 13 | | | Debugging the same JavaScript | Console, breakpoints | **TDD** red, green, fix |
| Finale | 14 | `JOIN`, SQL injection, parameterized queries | Auth, the full flow | Version history / diff | | Regression test |

**The habits in Act 1:**
- **Patience:**
  - Waiting out the Watcher.
  - Hints only on request.
  - On floor 18, the Shredder hunts by sound, and the "typing is loud" setting teaches planning a query before typing it.
- **Attention to detail:**
  - Semicolons and quotes.
  - Exact names copied off papers.
  - Calendar secrets.
  - Reading the real error message.
- **How to learn:**
  - The book, the notebook glossary, case pages and the hint ladder.
  - Floor 18's last new word, which the crew looks up on Mercer's reference card, then practises on his offline PC before using it.
  - From Act 2 on, books get thinner and references do more.

**Books** (placeholder titles in Augustine's pattern; he approves them):
- Act 1: "Easy SQL".
- Act 2: "Easy APIs" (Level 5) and "Easy JavaScript" (Levels 6 and 7).
- Act 3: "Hello HTML!" (3a) and the second half of "Easy JavaScript" (3b).

New books get their huddle on the spot in Act 2, and in the elevator once the lifts run again in Act 3.

---

## 12. Levels

Hostile levels alternate with creepy-but-not-hunting ones, and completion styles vary: escape, survive, free, rescue, protect.

The game has 15 floors under curriculum B. If the schedule needs 12, merge Level 9 into 10 and Level 12 into 13, and fold the finale into 3b; Act 3 is still the biggest act. Act 3 can ship as two free updates (3a, then 3b and the finale).

**Not yet decided:**
- Building floor numbers for Levels 4 to 13. Act 2 goes down to G and the basements; Act 3 climbs back up to the director on 30.
- The setting and threat of the two new floors (9 and 12).
- These are the architect's to set, with Augustine.

| Act | Lvl | Was | Location | Threat | Hunts you? | Completion style |
|---|---|---|---|---|---|---|
| 1 | 0 | 0 | Ground floor (G) | The Hum | No | Explore |
| 1 | 1 | 1 | Server floor (14) | The Hum | No | Earn Rourke's trust |
| 1 | 2 | 2 | Security floor (22) | Rourke, then the Watcher | Yes | Survive the betrayal, then escape |
| 1 | 3 | 3 | Records Archive (18) | The Shredder | Partly (by sound) | Find the safe room |
| 2 | 4 | 4 | Power Plant | The Custodian | Yes | Escape and seal it in |
| 2 | 5 | 5 | Personnel Wing | The Mimics | Yes (deceive) | Find the real people |
| 2 | 6 | 6 | Cold Storage | The Ones Who Never Left | No | Free them |
| 2 | 7 | 7 | The Dark Floor | WARDEN (lights out) | Yes, with others | Beat WARDEN; the lifts run again |
| 3a | 8 | (new) | Back through 18, then up | The Glitch | No (unsettling) | Recover Mercer's floor plan |
| 3a | 9 | (new) | To decide | To decide | | |
| 3a | 10 | 10 | Admin Portal | The Glitch | No (unsettling) | Uncover; Vale reveal |
| 3b | 11 | 8 | Robotics Bay | The Swarm | Yes | All-terminal event |
| 3b | 12 | (new) | To decide | To decide | | |
| 3b | 13 | 9 | Maintenance Tunnels | The Custodian (in vents) | Yes | Fix it with TDD |
| Finale | 14 | 11 | The Vault (30) | The Director and collapse | Yes | Escape with evidence and Vale |

**Old level numbers elsewhere in this plan.** Sections 2, 6, 7, 9 and 10 still use the 12-level numbers until they are renumbered.
- Levels 0 to 7 and 10 keep their numbers.
- Old 8 (Robotics Bay) is now 11, old 9 (Maintenance Tunnels) is now 13, and old 11 (the Vault) is now 14.

### Level 0: Ground floor — "The Tour"
- Rourke's tour: the job, Mercer's story, the safe-room rumor. It introduces the voices, the facility and the terminals.
- **Puzzles:** `SELECT` and `ORDER BY` reassemble Vale's shredded memo, and the visitor log is read newest first with `DESC`. `LIMIT` folds into "newest first" (curriculum B).
- **Entity: The Hum**, a low tone that grows in the dark. It teaches fear of the dark without danger.
- **Find:** walkie-talkies.

### Level 1: Server floor — "The Escort"
- No threat: the whole floor builds trust in Rourke (see `plan/floors-expansion.md`).
- **The job, practised safely:** WARDEN's diagnostics (the first test output) show which subsystems failed. `WHERE` / `AND` on `door_controllers` finds the faulting controller, and Rourke has the crew reset it.
- **Other puzzles:** comparison (`>`, `<`) and `OR`. `COUNT` is added here as the floor's fifth puzzle (curriculum B), practised safely.

### Level 2: Security floor — "Who Badged In?"
- Rourke frames the crew in Vale's lab and turns on them, then the Watcher hunts the floor (see `plan/floors-expansion.md`).
- **Entity: The Watcher**, moves only when unseen. `GET /cameras` returns JSON of live camera states (the first web request).
- **Code gate:** `LIKE 'Har%'` on a smudged name gives a guard's PIN.
- **Routes:** a ledge outside the window, a ceiling vent boost, or the main door past the Watcher.
- **First terminal lie:** a hardware fault.

### Level 3: Records Archive (18) — "Mercer's Room" (Act 1 ends)
- **Entity: The Shredder**, blind, hunts by sound. It wakes when the crew enters the north corridor or turns a shelving crank.
- **Words:**
  - `COUNT`, `DISTINCT` and `GROUP BY` are found on papers at the records desk and practised there before the Shredder wakes.
  - The night's busiest reader (`GROUP BY` + `COUNT(*)` + `ORDER BY ... DESC`) is then counted under threat.
  - `IS NULL` is looked up on Mercer's reference card, practised on his offline PC in the safe room, and used under threat at the desk.
- **Code gates:**
  - The night's count names the side room.
  - The keyholder's badge from the readers' log opens the push-button lock on Mercer's door. The badge is Mercer's own, and why it was in use stays unexplained for now (Augustine, 2026-10-21).
  - The box nobody checked back in holds the stair key.
- **Finds the safe room.** It holds the first floppy-disk evidence, and it is a hub that later floors return to.
- **Moved to Level 8 (curriculum B):** the archive intranet's `hidden` record (Mercer's old floor plan).
- **Traversal:** climbing towering shelves while the Shredder passes below.

### Level 4: Power Plant — "Don't Forget the WHERE" (Act 2 opens)
- **Story (approved Act 2 plan):**
  - The crew tries to leave the way it came in and opens the `main_doors` row, which is really the containment doors. The entities get out.
  - The "Never open main_doors" sticky turns up, and WARDEN announces Containment protocol Epsilon.
  - At the main entrance, `UPDATE gates SET unlocked = TRUE WHERE name = 'main_entrance';` says 1 row affected, then Epsilon re-locks it: a terminal lie that teaches verify after write.
- **Entity: The Custodian**, released in the accident. **Seal it:** lock the charging bay behind you, or it follows you to later levels.
- **Words:** `UPDATE ... WHERE`, `INSERT`, and verify after write. This is the last new SQL.
  - Epsilon then locks the database to read-only. Its wording goes to Augustine; the idea is "direct writes suspended, services only".
  - Reads still work, so Act 1's skills keep finding things.
- **Find:** the portable deck. A 2-terminal teaser event. The robot-arm route to the ceiling panel (section 5) stays as the physical shortcut.

### Level 5: Personnel Wing — "Faces That Don't Match"
- **Entity: The Mimics**, wearing staff faces and teammates' voices on the radio.
- **Words:**
  - The building's services: `POST` and `PATCH` with a JSON body.
  - Status codes (201, 400, 401, 403, 409).
  - A header with an API key found on a sticky.
  - Checking a change with `GET`.
- **Code gates:**
  - An API key unlocks the HR service, which shows who was really where.
  - Power and air come back one request at a time.
- **Story:** evidence that Vale's death record was edited (players assume by the director).

### Level 6: Cold Storage — "The Ones Who Never Left"
- **Not hostile.** Staff who never clocked out are trapped as flickering echoes, bound to their rows. Creepy and sad.
- **Words:** the first script, in JavaScript: variables, `if`, a loop, waiting. The deck's script editor arrives here.
- **Code gates:**
  - `WHERE clock_out IS NULL` (from Level 3) finds them.
  - A script loop releases each one, record by record, through the services, as their stories play out.
  - A watchdog script holds a door while the crew crosses.
- **Completion:** free them all. Each one freed gives a piece of evidence or a memory.
- **Find:** earpieces.

### Level 7: The Dark Floor — "Lights Out" (Act 2 ends)
- WARDEN cuts the lights again and again. The Custodian and, if he escaped, Rourke are in the dark with you.
- **Words:** functions, lists, and looping over many devices. Logs, and testing a script on a test bench before it touches the building (assertions). Auth tokens.
- **Three ways to beat WARDEN (all need code):**
  1. **Physical lockout:** reach the network closet and pull WARDEN's uplink, then reroute the lights to a local controller with a service request.
  2. **Security:** revoke WARDEN's token through the auth service, so it can't change the lights.
  3. **Watchdog script:** check the lights every second and restore them, with an assertion that alerts you when it fails. WARDEN escalates; you patch.
- **End:** the lifts run again. From here on, new books get their huddle in the elevator.

### Level 8: "Hello HTML!" (Act 3a opens)
- Reality's display layer is failing. **Entity: The Glitch** (moved up from Level 10): unsettling, never attacks, and hides things, including parts of the world.
- **Words:** inspecting a page, elements, attributes, `hidden`.
- **Code gate:** Mercer's old floor plan, a record marked `hidden` on the archive intranet (planted on floor 18 in Level 3, reached through the safe-room hub).
- **Setting:** to decide.

### Level 9: (new floor) — CSS
- **Words:** CSS selectors, `display`, `visibility`, `position`, `z-index`, colour and contrast.
- **Glitches to fix:**
  - A wall drawn across a corridor.
  - A doorway set to `display: none`.
  - A room too dark to read.
- **Setting and threat:** to decide.

### Level 10: Admin Portal — "The Hidden Button" (Act 3a ends)
- **Entity: The Glitch.**
- **Words:** forms and layout, and UI checks.
- **Code gates:** unhide the "Release Lockdown" button with CSS, and use the same inspector to unhide hidden doorways in the world.
- **Unlock:** the custom deck UI.
- **The reveal:** `audit_log` shows fake-outs written by Vale's "dead" account. She's alive, in the vault. A plain read is enough here; `JOIN` waits for the finale.
- **Hub:** a save between the halves.

### Level 11: Robotics Bay — "Quorum" (Act 3b opens)
- **Entity: The Swarm**, drones that react to light and patrol in formation.
- **Words:** JavaScript in the browser: the DOM, `querySelector`, events. Examples are dead switches, keypads that ignore clicks, and the drones' control panels.
- **Main event:** an all-terminal event (section 7) while the Swarm patrols.
- A recap huddle opens 3b for players returning after a break.

### Level 12: (new floor) — fetch
- **Words:** `fetch` and the network tab. Panels call Act 2's services, so the full stack comes together. API checks.
- **Glitch to fix:** a panel that loads forever.
- **Setting and threat:** to decide.

### Level 13: Maintenance Tunnels — "Fix the Loop"
- **Entity: The Custodian, now hunting in the vents.**
- **Words:** debugging with the console and breakpoints.
- **Code gate (TDD):**
  - Write tests for how the Custodian should behave ("treats crew as authorized", "loop exits").
  - Watch them fail, fix its script, and watch them pass.
  - Upload the fix, and the Custodian stands down for good.

### Level 14: The Vault (30) — "Proof" (the finale)
- **Threats:** the director, Rourke (if he escaped), and earlier entities breaking loose as WARDEN collapses.
- **Code gates:**
  - `JOIN` `audit_log` with the staff records to prove who did what.
  - SQL injection on the director's login, then learn why it worked.
  - A version-history diff proving he changed the Custodian's script.
  - Rewrite the login with parameterized queries plus a regression test.
  - A final all-terminal quorum to open the gate.
- **Escape:** carry the evidence and get Vale out alive for the best ending.
- **Reward:** a downloadable personal cheat sheet of every real query and line of code your team wrote.

**Ethics note.** The injection puzzle is framed explicitly: this is why real systems use parameterized queries, and you only test systems you're authorized to test.

---

## 13. Why 6 players, and what it costs

Games often cap at 4 because every extra player multiplies the work: puzzles need enough jobs for everyone, entities need retuning or they become trivial, voice and network traffic grows, and levels need space for more bodies. R.E.P.O. runs at 6, and Lethal Company is regularly modded to more, so 6 is very doable with host-based co-op. The design handles it by:
- Puzzles with **parallel jobs** that scale (all-terminal events, sharded data, multi-room checks).
- Entities that scale with player count (speed, number, aggression).
- Paired playstyles at 5 to 6 players.
- Playtesting at 1, 3 and 6 players every milestone.

---

## 14. DLC and sequels

Each continuation **builds on the base game's skills** (SQL, HTTP, JavaScript, HTML/CSS and testing as familiar ground) and adds new ones, with harder, more complex puzzles. The base game is complete without any DLC, and no DLC gates its story.

| Chapter | Setting | Story | New skills (on top of base) |
|---|---|---|---|
| **Halcyon** (base) | 1997 research campus | Survive, find the evidence, rescue Vale | SQL, HTTP, JavaScript (scripts and pages), HTML/CSS, testing |
| **Python pack** (language DLC, first) | The base game | The same story | Python in place of JavaScript for the server scripts |
| **Deep Line** (DLC 1) | Offshore drilling rig, storm | The crew vanished; the rig is sinking | Linux command line, bash, permissions, logs |
| **Signal** (DLC 2) | Abandoned hospital network | A patient the records say never existed | Networking: IPs, ports, DNS, firewalls |
| **Cold Storage** (sequel) | Arctic seed vault | Vale returns; the experiment wasn't contained | Python, data pipelines, git (shares the Python pack's interpreter) |
| **Java and C** (story DLC, later) | New floors where those languages are naturally used | To decide | C for robot firmware (bit flags on door relays); Java for an enterprise system in the payroll offices on floor 9 |

### Language packs (curriculum B, approved 2026-10-21)
**How they work.** Puzzles check what happens in the building, never the code text. This extends the `Puzzle.matches` rule:
- A script passes when the door stays held, every robot gets its new route, or the breaker stays on.
- Every language gets the same small building library: run a query, send a request, wait, write to the log.
- So any language that can call that library passes the same puzzle.
- In co-op, each player could pick their own language at their own terminal. Hints follow the language of the player who asked.

**What a pack swaps.** Only the server-script slot: Act 2's script puzzles, plus any Act 3 puzzle where code runs on the building rather than in a page.
- SQL, HTTP, HTML, CSS, browser JavaScript and testing stay in the base game.
- Browser puzzles stay JavaScript, because that is what browsers run.

**What each pack costs:**
- A sandboxed interpreter (no file or network access, a step limit, a memory cap, run on the co-op host).
- The building library binding.
- A book with quizzes.
- A hint ladder for every script puzzle, written in that language.
- Beginner-friendly error messages.
- A test group of its own (right and tempting-wrong solutions, and the lost-player walk).

Player code never runs as GDScript, because Godot's runtime GDScript is not a sandbox. Interpreter candidates (a native engine per platform, or a teaching-subset interpreter written in GDScript) are in `plan/teaching/curriculum-acts-options.md`.

**Order.**
- Python comes first. It brings the most beginners, and the Cold Storage sequel reuses its interpreter.
- Java and C come later as story DLC with their own floors, rather than as swaps.

---

## 15. Tech stack

**Recommended: Godot 4** (changed from Unity in v2, because agents will build most of the game).

Godot stores scenes and scripts as plain text files, runs headless from the command line, is free and open source, and builds without a license server. That means agents can create, edit, test and build the game directly in the cloud. Unity scenes are hard to edit outside the editor and need license activation for builds, which would keep agents from building and testing on their own.

| Layer | Godot 4 choice |
|---|---|
| Language | GDScript, with C# where useful |
| Movement | Custom first-person controller (sprint, slide, crouch, roll, mantle, climb, ledge) |
| Networking | Godot high-level multiplayer + **GodotSteam** lobbies, host-based, up to 6 players |
| Voice | Steam voice via GodotSteam, with radio filters (static, range, occlusion) |
| SQL | **godot-sqlite** (real SQLite) |
| JavaScript | An embedded JS interpreter in a sandbox |
| HTML/CSS | A web view on in-world screens and the deck |
| Tests | **GUT** (Godot Unit Test) for the game's own code; puzzle solutions tested automatically |
| Platform | PC on Steam first |

**Tradeoff:** Unity has more horror and co-op assets for sale and more polished voice tools. Godot has fewer ready-made assets, so the plan leans on free and paid 3D asset packs and Godot's own lighting.

---

### One world, streamed wings (decided 2026-10-16)
Augustine asked for one continuous map instead of separate levels with loading screens, to avoid co-op lag-outs.
- **World scene:** one persistent scene holds the players, the network session, the HUD and one FacilityDB for the whole building.
- **Wings:** each "level" is a wing sub-scene, still built with Greybox, with its own seed tables added to the shared DB when it loads. The host loads the next wing in the background behind its sealed door before the door opens, and every peer builds the same wing locally from `Game.run_seed`.
- **Checkpoints:** a level ends at a checkpoint, not a scene change. Field Notes becomes an overlay there. Respawns use the latest checkpoint.
- **Seal behind:** a wing's entry door seals once every player is through. Wings two or more behind are unloaded, except the safe-room hub, which stays loaded once found.
- **Tests:** every wing must also load on its own in a test harness, so puzzles stay testable per level.
- **Shared tables:** `doors`, `lights` and `badges` are building-wide. Wings only INSERT their rows, with ids prefixed by the wing (SRA-*, SEC-*). Every other table name must be unique across the building. A test loads every wing's seed into one DB in order.
- **Row ownership:** a door or light row belongs to the wing that physically contains it. A wing that only mentions a door in its story doesn't insert it, though Level 1 holds COLD-LAB and ARCHIVE until those wings exist, and then they move.

### Notebook and elevators (decided 2026-10-16, from Augustine's Level 2 playtest)
- **Notebook:** each player carries a notebook (default key: Tab) that can't be opened while using a terminal.
  - Sticky notes are found in the world. Each holds one SQL keyword with its syntax and a worked example, and becomes a notebook page.
  - A sticky note stuck to a terminal can be copied into the notebook with E.
  - A "Tables" page records each table a player discovers (through .tables or a query), with its columns.
  - Field Notes moves into the notebook as its end-of-level summary.
  - In co-op, each player has their own notebook. A found note goes to the player who picked it up, so teammates have to share what they know. Terminal stickies can be copied by anyone.
  - Sticky notes add to the hint tiers; they don't replace them. A note's example must not be the puzzle's answer.
  - **Write note (Augustine, 2026-10-16):** every terminal line (query results, hints, errors, sticky notes, `.schema` output) has a "write note" option. It copies that line into the player's notebook, and the player can add a short label of their own. Players choose their own references; nothing is copied automatically except found sticky notes and the Tables page. The notebook still can't open at a terminal, so players have to take good notes and study them, or remember.
- **Lost-player tests (Teaching and UX thread):** each puzzle gets a walkthrough test that carries a cumulative "taught" set: every keyword, table and fact shown so far in earlier puzzles and levels, plus what's on screen now. The test fails if a solution needs anything outside that set, or if a taught concept was never offered as a write-note line. It assumes the player remembers what they were taught; it doesn't assume they guessed.
- **Elevators:** from Level 1 on, each level ends at an elevator.
  - The button works only when every living player is inside.
  - The doors must close before the level's threat arrives.
  - The doors closing is the checkpoint and the seal_behind. The ride hides the next wing's background load, and the next wing starts as the doors open.
  - Level 0 still flows into Level 1 on foot, as part of Rourke's tour.

### Who teaches: SYSOP, Mercer's notes and the world (decided 2026-10-17, Augustine)
Every tip and hint comes from inside the world. Nothing reads as a game UI talking to the player.
- **SYSOP:** an unknown user who messages the terminal (`[SYSOP]: ...`). Live tips, nudges and the tiered `.hint` answers come from SYSOP, in a terse, kind, slightly hurried voice. The wording keeps the puzzle-hint rules. Since 2026-10-18 (Augustine), hint 1 gives the query's shape with the value left blank and says where to find the value, hint 2 shows how to find it, and the last hint gives the exact query. Hints still say exactly what to type and where. SYSOP never explains who they are. At the Level 10 reveal, SYSOP turns out to be Vale, steering the players from the vault. SYSOP's lines must stay true to that: she knows the building, never lies to the players, and goes quiet when WARDEN is watching closely.
- **Mercer's notes:** handwritten margin notes ("- H.M.") on old manuals, binders and printouts. They carry syntax explanations and worked examples on non-puzzle tables. They are the main physical teaching source, alongside sticky notes.
- **The world carries the clues:** table names, column names, codes and hints live on in-world documents that blend into the level, such as brochures, laminated desk cards, memos stapled to corkboards, shift rosters and vendor manuals. Example: a "new guard clock-in system" brochure says it stores times "in a table of your choice", with "guards" handwritten in the blank.
- **Notebook-first:** players copy lines from these documents into their notebook (E on a document, or "+ note" on any terminal line). The level is solvable from what a careful player wrote down.
- **No immersion-breaking hints:** no floating text, no narrator and no game-voice tips. HUD notices are only for controls ("Added to your notebook (Tab)").
- **Objectives (Augustine, 2026-10-17):** no HUD objective line. Objectives are a short to-do list in the notebook, in the character's handwriting ("Get the exit door open"), and they never name an answer. The HUD only flashes "Notebook updated (Tab)".
- **Job ticket (Augustine, 2026-10-17):** the to-do list is the crew's Byte-Right job ticket: what they were hired to do for Halcyon, with tasks filled in as they go. Later levels can reverse-engineer it for clues. In Level 0 WARDEN is silent: the building PA plays generic corporate reminders ("Your files belong to Halcyon!"), and Rourke notes the rebuilt memo "for the director".

---

- **Hide the papers (Augustine, 2026-10-17):** from Level 3 on, hint papers are hidden in places players search: desk drawers, taped under tables, inside binders, behind a loose ceiling tile. Searching is part of the puzzle; the first clue for a new concept stays easy to find.

### Diegetic notebook and terminals (Augustine's playtest round 3, 2026-10-17)
No full-screen menus for the notebook or terminals. The current overlay UIs keep working until the new versions land.
- **Notebook:** Tab pulls the notebook from a pocket or belt with an animation. It opens in the player's hands and takes up only part of the screen. "+ note" visibly writes the line into it. Tabs are Work order, Tables, Notes (stickies and copied text), then Field Notes. The work order is a professional, printed ticket listing the crew's original (false) tasks.
- **Terminals:** pressing E moves the player into position at the terminal, and the camera focuses on its screen. The text renders on the in-world CRT, so teammates can walk up and read it. Each terminal has a keyboard prop, and typing animation is optional. Text must stay readable at the focused distance.
- **Copying lines:** hovering over a line highlights it and shows a subtle "add to notebook".
- **Ownership:** Graphics builds the held notebook, the screens that render the UI (SubViewport onto a mesh), and the keyboards. Movement builds the pull-out pose and the walk to a terminal with camera focus. Co-op mirrors each terminal's screen text to the other players. Playtest wires the mechanics. NotebookPages and TerminalUI keep their logic, so the lost-player tests keep passing.
- **Order:** the notebook first, because it involves one player and is self-contained. Terminals second.

### Level scale and pacing (Augustine, 2026-10-17)
Augustine will ask for every level to become longer and larger once Levels 0-2 look and feel good. Until then, levels 0-2 are polished at their current size, but everything built from Level 3 on follows these rules from the start so it doesn't need rebuilding:
- **Pacing rhythm:** each level alternates quiet stretches (explore, read documents, take notes) with intense ones (a chase down hallways, ducking into rooms to hide). Roughly: arrive quiet, find and practise, a pressure peak, a breather, the main puzzle under threat, then the exit.
- **Layout:** loops, not corridors. Every hunted space has at least two ways around, side rooms with a door that closes, and hiding spots (lockers, under desks, behind shelving). Long hallways are kept for chases.
- **Routes:** every code gate has at least two routes (the plan's "skill only changes the route" rule), and at least one physical shortcut for movement-skilled players.
- **Build for growth:** Greybox layouts are built from reusable room and hall pieces so a level can be lengthened later without rewriting its puzzles.

### World rules from the Level 2 playtest (Augustine, 2026-10-17)
- **Nothing discoverable is labelled.** Vents, panels, ledges and hidden routes get no signs or floating labels; a hover prompt shows only when a player looks right at them. Players should find out for themselves that "you can open the vents!"
- **Papers look real.** Every document has a real format (ruled tables, letterheads, forms), with handwriting, stains and stamps drawn on.
- **Read by picking up.** Players lift papers and cards to read them; copying a sticky note means taking it and putting it in the notebook.
- **The database has a reason.** Every row players read has an in-world source (a badge reader, camera, clock-in terminal), and something in the world shows it.
- **Whole floors.** Every level is a whole floor; Levels 0 to 2 are being expanded now. See `plan/floors-expansion.md`, which also moves Rourke's betrayal to Vale's lab in Level 2 (Augustine's pick, 2026-10-17). Where this section and older text disagree, floors-expansion.md wins.
- **Make it make sense** (Augustine, 2026-10-18). Everything in the world has a visible reason. A dark room has a dead bulb, a tripped breaker or an unplugged lamp. Chairs face the table they belong to, papers face the person who would read them, and NPCs stand where their request makes sense (Rourke never blocks the button he asks you to press). Tools rest on surfaces.

## 16. How we build it

- **Agents** write the code, levels (in greybox), puzzle data, seed databases, tests and builds, in a GitHub repository.
- **Augustine** directs, playtests each build, and voice-acts characters (Rourke, WARDEN, Vale, Mercer recordings, the Ones Who Never Left).
- **Friends** playtest. Two already know SQL, which makes them good at catching puzzle bugs and calibrating difficulty; the others test the learning curve.
- Every puzzle ships with an automated test proving it's solvable, so agents can change levels without breaking them.

---

## 17. First playable slice

**Scope:** Levels 0 and 1, 1 to 6 players, greybox art.

1. First-person controller: sprint, crouch, slide, roll under a gate, mantle, crawl a vent.
2. In-world terminal with real SQLite, schema browser, results view.
3. Rourke: the tour (placeholder voice lines), the betrayal, kill or subdue, and the resulting lockdown.
4. WARDEN diagnostics (read-the-tests puzzle).
5. Walkie-talkies with static and range, plus proximity voice.
6. Doors and lights driven by data, synced for all players; one hardware-fault echo.
7. Automated tests that each puzzle can be solved.

**Milestones**
- **M1, Solo greybox:** movement, terminal, Level 0 end to end. Augustine playtests.
- **M2, Co-op:** 2 to 6 players in a Steam lobby, synced doors, radios.
- **M3, Betrayal:** Level 1 with Rourke, both outcomes, lockdown. First voice recording pass.
- **M4, Friends playtest:** the SQL-savvy pair checks the puzzles; everyone else tests the learning curve. Measure: did they finish, were they scared, can they write `SELECT ... WHERE` afterward without help, and did they want to replay.

---

## 18. Open decisions (defaults chosen)

| Question | Default |
|---|---|
| Engine | Godot 4 (see section 15) |
| Platform | PC (Steam) first |
| Players | 1 to 6 |
| Audience | Teens and adults with no coding background |
| Art style | Lo-fi realistic, VHS grain, Backrooms liminal |
| Base game length | 12 levels, about 7 to 8 hours |
