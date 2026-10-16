# NULL & VOID: Game Plan (v3)

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
Halcyon Data Systems, an isolated research campus, 1997. CRT terminals, beige servers, humming fluorescent tubes, VHS tapes, endless liminal corridors.

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

### WARDEN
The facility AI. Dry, sarcastic, and increasingly hostile. Early on it "helps" with hints because it's following protocol; later it actively fights the players (see Level 7).

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

## 11. Curriculum: spread and interleaved

SQL is still the backbone, but other skills are introduced early in small doses so that by Levels 5 to 6 players are mixing the whole stack. Each level adds a few new words or ideas and reuses earlier ones.

| Lvl | SQL | HTTP / APIs | JavaScript | HTML / CSS | Testing |
|---|---|---|---|---|---|
| 0 | `SELECT`, `FROM`, `ORDER BY` | | | | |
| 1 | `WHERE`, `AND`/`OR` | | | | Read diagnostics |
| 2 | `LIKE`, `LIMIT`, `COUNT` | `GET` a JSON camera list | | | Verify by reading |
| 3 | `DISTINCT`, `GROUP BY` | | | Inspect a page; the `hidden` attribute | |
| 4 | `UPDATE`, `INSERT`, transactions | `POST`, `PATCH`, status codes | | | Verify after write |
| 5 | `JOIN` | API keys, headers | Variables, `if` | | Saved check queries |
| 6 | `IS NULL`, subqueries | | Arrays, loops | Simple forms | Checks as a suite |
| 7 | Roles and permission tables | Auth tokens | Timers, watchdog loops | | Assertions |
| 8 | Aggregates across shards | Chaining calls | Functions, `async`/`fetch` | | API response checks |
| 9 | `CASE` | | Debugging, reading others' code | | **TDD** red, green, fix |
| 10 | Window into `audit_log` | Network tab | DOM, events | CSS selectors, DevTools, custom deck UI | |
| 11 | SQL injection, parameterized queries | Full flow | Version history / diff | | Regression test |

---

## 12. Levels

Hostile levels alternate with creepy-but-not-hunting ones, and completion styles vary: escape, survive, free, rescue, protect.

| Lvl | Location | Threat | Hunts you? | Completion style |
|---|---|---|---|---|
| 0 | Lobby (tour) | The Hum | No | Explore |
| 1 | Server Room A | Rourke | Yes (human) | Survive the betrayal |
| 2 | Security Office | The Watcher | Yes | Escape |
| 3 | Records Archive | The Shredder | Partly (by sound) | Find the safe room |
| 4 | Power Plant | The Custodian | Yes | Escape and seal it in |
| 5 | Personnel Wing | The Mimics | Yes (deceive) | Find the real people |
| 6 | Cold Storage | The Ones Who Never Left | No | Free them |
| 7 | The Dark Floor | WARDEN (lights out) | Yes, with others | Beat WARDEN |
| 8 | Robotics Bay | The Swarm | Yes | All-terminal event |
| 9 | Maintenance Tunnels | The Custodian (in vents) | Yes | Fix it with TDD |
| 10 | Admin Portal | The Glitch | No (unsettling) | Uncover; Vale reveal |
| 11 | The Vault | The Director and collapse | Yes | Escape with evidence and Vale |

### Level 0: The Lobby — "The Tour"
- Rourke's tour: the job, Mercer's story, the safe-room rumor. Introduces voices, the facility and terminals.
- **Puzzle:** Rourke "lets" you try a terminal: `SELECT` and `ORDER BY` to reassemble Vale's shredded memo. It hints she knew something.
- **Entity: The Hum**, a low tone that grows in the dark. Teaches fear of the dark without danger.
- **Find:** walkie-talkies.

### Level 1: Server Room A — "The Escort"
- Rourke locks you in and attacks. A fight or a chase through server aisles; kill or subdue him.
- **Code gate:** WARDEN's diagnostics (your first test output) show which subsystems failed. `WHERE` / `AND` on `door_controllers` finds the one controller you can reset to get out.
- **Lockdown begins.**

### Level 2: Security Office — "Who Badged In?"
- **Entity: The Watcher**, moves only when unseen. `GET /cameras` returns JSON of live camera states (first API taste).
- **Code gate:** `LIKE 'Har%'` on a smudged name gives a guard's PIN.
- **Routes:** ledge outside the window, ceiling vent boost, or main door past the Watcher.
- **First terminal lie:** a hardware fault.

### Level 3: Records Archive — "Mercer's Room"
- **Entity: The Shredder**, blind, hunts by sound.
- **Code gates:** `GROUP BY` reveals the most-visited room that night; an archive web page has a record marked `hidden` that players unhide by inspecting the HTML. It's Mercer's old floor plan.
- **Finds the safe room.** First floppy-disk evidence.
- **Traversal:** climbing towering shelves while the Shredder passes below.

### Level 4: Power Plant — "Don't Forget the WHERE"
- **Entity: The Custodian**, released if you run the panicked note's `UPDATE doors SET locked = 0` with no `WHERE`.
- **Code gates:** transactions and verify-after-write; `PATCH` the generator API; robot arm plus shoulders to the ceiling panel (section 5).
- **Seal it:** lock the charging bay behind you, or it follows you in later levels.
- **Find:** the portable deck. A 2-terminal teaser event.

### Level 5: Personnel Wing — "Faces That Don't Match"
- **Entity: The Mimics**, wearing staff faces and teammates' voices on the radio.
- **Code gates:** three-way `JOIN` shows who was really where; a small JS `if` on the deck filters badge lists; an API key unlocks the HR system.
- **Story:** evidence that Vale's death record was edited (players assume by the director).

### Level 6: Cold Storage — "The Ones Who Never Left"
- **Not hostile.** Staff who never clocked out are trapped as flickering echoes, bound to their database rows. Creepy and sad.
- **Code gates:** `WHERE clock_out IS NULL` finds them; subqueries against `employees_backup` restore what was deleted; a JS loop releases each one, record by record, as their stories play out.
- **Completion:** free them all. Each one freed gives a piece of evidence or a memory.
- **Find:** earpieces.

### Level 7: The Dark Floor — "Lights Out"
- WARDEN cuts the lights again and again. The Custodian and, if he escaped, Rourke are in the dark with you.
- **Three ways to beat WARDEN (all need code):**
  1. **Physical lockout:** reach the network closet and pull WARDEN's uplink, then reroute the lights to a local controller with a short config query.
  2. **Security:** write a permissions table and revoke WARDEN's role so it can't write to `lights`; use auth tokens on the light API.
  3. **Watchdog app:** write a script on the deck that checks the lights every second and restores them, with an assertion that alerts you when it fails. WARDEN escalates; you patch.

### Level 8: Robotics Bay — "Quorum"
- **Entity: The Swarm**, drones that react to light and patrol in formation.
- **Main event:** an all-terminal sharded unlock (section 7) while the Swarm patrols.
- **Code:** `async` / `fetch` chains to dock the drones; aggregates across shards.

### Level 9: Maintenance Tunnels — "Fix the Loop"
- **Entity: The Custodian, now hunting in the vents.**
- **Code gate (TDD):** write tests for how the Custodian should behave ("treats crew as authorized", "loop exits"), watch them fail, fix the script, watch them pass. Upload the fix, and the Custodian stands down for good.

### Level 10: Admin Portal — "The Hidden Button"
- **Entity: The Glitch.** Unsettling, never attacks. It hides things, including parts of the world.
- **Code gates:** unhide the "Release Lockdown" button with CSS; read console errors; watch network calls; use the same inspector to unhide hidden doorways in the world.
- **Unlock:** custom deck UI.
- **The reveal:** the `audit_log` shows fake-outs written by Vale's "dead" account. She's alive, in the vault.

### Level 11: The Vault — "Proof"
- **Threats:** the director, Rourke (if he escaped), and earlier entities breaking loose as WARDEN collapses.
- **Code gates:** SQL injection on the director's login (then learn why it worked); a version-history diff proving he changed the Custodian's script; rewrite the login with parameterized queries plus a regression test; final all-terminal quorum to open the gate.
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

Each continuation **builds on the base game's skills** (using SQL, HTTP, JS and testing as familiar ground) and adds new ones, with harder, more complex puzzles.

| Chapter | Setting | Story | New skills (on top of base) |
|---|---|---|---|
| **Halcyon** (base) | 1997 research campus | Survive, find the evidence, rescue Vale | SQL, HTTP, JS, HTML/CSS, testing |
| **Deep Line** (DLC 1) | Offshore drilling rig, storm | The crew vanished; the rig is sinking | Linux command line, bash, permissions, logs |
| **Signal** (DLC 2) | Abandoned hospital network | A patient the records say never existed | Networking: IPs, ports, DNS, firewalls |
| **Cold Storage** (sequel) | Arctic seed vault | Vale returns; the experiment wasn't contained | Python, data pipelines, git |

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
