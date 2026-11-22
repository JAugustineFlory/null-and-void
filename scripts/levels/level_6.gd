extends LevelBase
## Level 6: B1, the sample and records cold store ("The Ones Who Never Left"). Act 2's
## third floor. The crew walks down STAIR 2 from 9 with the two night-shifters, into
## a basement that isn't hostile, only cold and sad: staff who never clocked out are
## still at their rows, as flickering echoes. The crew frees them, record by record,
## with its first scripts.
##
## Stations (curriculum B: a variable (let), if, a loop (while), waiting (await
## sleep), the log (console.log), once for each (for ... of, const) and a query from
## a script (db.query); IS NULL and the L5 requests reviewed). One case at a time on
## the board, in order:
##   1. open     the time office: who's still clocked in? SELECT ... FROM freezer_log
##               WHERE clock_out IS NULL (review). = NULL finds nothing; the rack and
##               the whiteboard disagree with the log ("the rack is not the record").
##   2. pair     the IT cage: the first script pairs one earpiece set each (let,
##               while, await sleep), from the cradle card. Safe here. No count up:
##               the loop never ends (Stop); no wait: the cradle's busy (409); the
##               card's key is the dock cradle's (403). The walkie's static goes.
##   2b. list    the IT cage, warm: the clock's service page shows a loop over the
##               open entries (db.query, for ... of). Run it with only a log in it:
##               the name on every entry still open, one a line. Nothing is written.
##               The page's query is vault A's: only some names; the whole row in
##               one line isn't a name a line. (Teaching's audit, item 1.)
##   3. hold     doors that won't stay open. The anteroom door (Epsilon's sweep, which
##               WARDEN announces) is the practice, warm and with nothing at stake;
##               the deep freeze's door (its own safety timer, no WARDEN; Augustine's
##               call 8) is the pressure, in the cold, until everyone is across.
##               The watchdog: while (true), GET, if locked PATCH open and log, wait.
##               No if: needless writes trip the relay guard (30 s shut).
##   4. release  in Vault C, on the deck over the vaults' wireless (the clock's punches
##               are refused on the wired terminals, 403): loop over the open entries,
##               if it isn't one of the crew's own, POST /clock_outs, log, wait for the
##               slip. Forget the if and the crew's own entries close: their vault goes
##               "unoccupied" (dark, colder, latched), and someone punches them back
##               in by code (call 6). Each one freed tells their story and leaves a
##               memory or a piece of evidence.
##   5. stop     (optional, rewarded) stop every script we started, shut the vault
##               doors, and read them back.
## STAIR 2 down opens once every echo is free. Every station is checked by the state
## the building's services are left in, never by code text. Every line players read
## or hear is in plan/approvals/l6-text.md, approved by Augustine word for word on
## 2026-11-05 ("approve all"); a change here is a new draft until he OKs it. The
## echoes speak through VoiceLines (scene l6_echoes, so recordings play); ECHO_LINES
## keeps the same words for the walkie's static and the subtitle-only fallback. DRAFT
## since (Teaching's B1 walk, 2026-11-05, in l6-text.md): the listing skips the crew's
## own entries (punched in at the landing), its words and tip, and practice's GET line.
##
## v0.10's package (plan/approvals/puzzle-flow-floor-b1.md, approved by Augustine
## 2026-11-22 word for word, with Ines and Tomas's sets): every case shows its shape
## on screen, with pieces found in the world; the open case is solved by pointing at
## who's been inside longest; the pair case is a try with one set, then the loop for
## the crew and the two night-shifters; each chapter lands with the step that needs it;
## the listing opens after the voice in the ear; the tidy-up opens back in the warm;
## and a warm-up area halfway down the corridor.
##
## Layout (level space, north is -z):
##   landing      x -4..4,   z 4..8     STAIR 2 (east wall): down from 9, and on to B2
##   hall         x -3..3,   z -8..4    warm; the anteroom terminal at its north end
##   time office  x -13..-3, z -8..4    the time clock, card rack, whiteboard, terminal
##   IT cage      x 3..10,   z -8..-1   the earpiece cradle, the bench, its terminal
##   passage      x 3..10,   z -1..2    hall to goods-in
##   goods-in     x 10..20,  z -12..2   the dead dock stairs; the conveyor hatch north
##   anteroom     x -2..2,   z -12..-8  the practice door (CS-ante) on the hall side
##   corridor     x -14..20, z -16..-12 cold; Vault C's door at its far (east) end
##   vault A, B   x -12..-4 / -2..6, z -24..-16   samples / records and film
##   vault C      x 20..30,  z -20..-8  the deep freeze
##   plant room   x -22..-14, z -18..-10  the compressors: why it's cold, and warm
##
## Co-op: the host decides (sweeps, timers, the readers' punches, who's where) and
## every machine plays it out through sync.event. The floor's services run on every
## machine in the same order (typed requests through LevelSync, scripts through
## ScriptHost), and change only service state, so every copy agrees; anything that
## depends on time is a host timer that comes back as an event.

## Fired once the crew is on the stairs down: the floor is done.
signal completed

## Player-facing lines, approved by Augustine 2026-11-05: plan/approvals/l6-text.md.
## Case titles carry the story and how the crew feels; their details (the case's
## objective) say what to do (Augustine 2026-11-05).
const TEXT := {
	"case_open": "Cards still IN after all these years?",
	"case_open_do": "Find every visit the time clock never closed",
	"case_pair": "That voice under the static. Get it off our radios",
	"case_pair_do": "Pair an earpiece for each of us at the IT cage cradle",
	"case_list": "Six names in the log. Say every one of them",
	"case_list_do": "At the IT cage terminal, run a loop that logs the name on every entry still open. Not ours",  # DRAFT
	"case_hold": "The doors keep locking. Don't let them shut us out",
	"case_hold_do": "Keep the deep freeze door open until everyone's in Vault C",
	"case_release": "They never got to go home",
	"case_release_do": "From inside Vault C, clock out every entry still open. Not ours",
	"case_stop": "Leave it how we found it",
	"case_stop_do": "Stop every script we started, lock the vault doors, read them back",
	"todo_arrive": "Find the time office, off the hall",
	"todo_down": "Back to the landing, then STAIR 2 down, everyone together",
	"open_done": "%d visits never closed, the oldest from %d. The rack says %d cards are IN. The log is the record.",
	"pair_done": "%d earpiece sets paired, two of them for Ines and Tomas. The walkie's static is gone; we hear each other in our ears now.",
	"list_done": "%s. One line each, read off the log itself. Now we know who we're going in for.",
	"hold_done": "Everyone's across into Vault C. The watchdog kept the door from latching.",
	"hold_done_hand": "Everyone's across into Vault C, between the safety timer's latches.",
	"release_done": "Every entry is closed. %s. They've all clocked out.",
	"stop_done": "Every script stopped, both vault doors locked and read back. B1 is as we found it, minus six.",
	"cold_first": "The cold bites. You won't last long in here.",
	"cold_numb": "You can't feel your hands. Get somewhere warm.",
	"warm": "Warm air. Feeling comes back into your fingers.",
	"static": "The walkie hisses. Under the static, someone is whispering.",
	"earpieces_in": "Earpieces in. The walkie's static is gone.",
	"earpieces_voice": "Then, for one second, clear as day in your ear:",
	"slip_out": "OUT SLIP",
	"door_opens": "%s unlocks.",
	"door_locks": "%s locks.",
	"sweep": "Clunk. Down the hall, a lock drops.",
	"latch": "The deep freeze door swings shut and latches.",
	"guard": "The relay clicks over. %s is held shut.",
	"guard_off": "The relay clicks back. %s answers again.",
	"punch_in": "The vault reader beeps. %s punched in.",
	"punch_floor": "The landing reader beeps. %s punched in.",  # DRAFT
	"unoccupied": "The lights in %s die. The clock thinks nobody's in there.",
	"occupied": "The lights in %s come back on.",
	"slip": "The time clock chatters and prints a slip.",
	"released": "%s clocks out. Something is left on the shelf.",
	"stairs_release": "On the landing, STAIR 2's gate rattles open.",
	"stairs_wait": "Waiting for everyone on the stairs (%d/%d)",
	"cross_wait": "Waiting for everyone in the deep freeze (%d/%d)",
	"book_taken": "Journey through JavaScript. Same series as Easy SQL. The page on loops is dog-eared.",
	"deck_taken": "A loaner deck from the bench. It's yours now.",
	"deck_fitted": "The wireless card clicks in, and the script runner chip. The deck runs scripts now.",
	"deck_none": "You don't have a deck. The bench has loaners.",
	"no_deck_signal": "No signal here.",
	"custodian_heard": "Something heavy moves through the floor below. Then it stops.",
	"custodian_seen": "Down the dock shaft, something huge stands very still. Then it's gone.",
	"inside_release": "The inside release handle won't budge.",
	# SYSOP tips (text only, never lies; each fires once per run).
	"tip_eq_null": "0 rows: = NULL is never true. nothing equals NULL, not even NULL. an empty column is asked for with IS NULL.",
	"tip_not_null": "those are the visits that DID close. you want the ones with nothing in clock_out.",
	"tip_rack": "the rack is cards in slots. the log is what the clock recorded. they don't agree tonight.",
	"tip_pair_endless": "it's still sending: the loop's test never turns false. count paired up inside the loop. and ^T stops a script.",
	"tip_pair_busy": "409 busy: the cradle pairs one set at a time. wait inside the loop, after each request.",
	"tip_pair_key": "403: that's the dock cradle's key, from the card. this cradle has its own.",
	"tip_pair_short": "%d paired, and there are %d of you with Ines and Tomas. one set each: count is how many sets.",
	"tip_list_try": "the service page's loop reads fine with only a log in it: console.log(entry.name), once for each open entry. we're in that log too, as VISITOR: if (entry.name !== \"VISITOR\") around the log keeps us out. try it here, where it's warm. nothing gets written.",  # DRAFT
	"tip_list_vault": "%d of %d names. that's vault A's query, off the page. the open entries are every vault's, as at the time office: drop the AND.",
	"tip_list_row": "that's a whole row in one line. log entry.name: one name a line.",
	"tip_list_ours": "VISITOR is us: VIS-01 and up, punched in at the landing. the names you want are the others. an if around the log keeps ours out: if (entry.name !== \"VISITOR\") { ... }",  # DRAFT
	"tip_guard": "409: the relay guard. writing to a door that's already open counts against it. only PATCH it when the GET says it's locked: that's what if is for.",
	"tip_steps": "the script ran too long without waiting. a loop that never ends needs await sleep(...) inside it.",
	"tip_same_door": "the watchdog's running for %s, the anteroom. the deep freeze is %s. change door, save, run it again.",
	"tip_wired": "403: punches only go through on the vaults' own network. a deck with a wireless card, in a vault.",
	"tip_printing": "409: still printing the last slip. wait longer between punches. GET /clock says how long a slip takes.",
	"tip_visitor": "that was one of ours. the clock thinks they've left the vault. punch them back in: POST /clock_ins with their card and the vault.",
	"tip_card_visitor": "the crew's cards are VIS-01 and up. VISITOR is what the name column says: entry.name !== \"VISITOR\" keeps ours open.",
	"tip_lockup": "every entry's closed. the watchdogs are still holding doors open. ^T stops a script; then PATCH the doors shut and GET them back.",
}

## The to-dos' titles (the story and how the crew feels; TEXT has their details:
## what to do). Approved by Augustine 2026-11-05 21:34Z, plan/approvals/task-titles.md.
const TASK_TITLES := {
	"todo_arrive": "Somebody's still down here",
	"todo_down": "Let them rest",
}

## The echoes' lines, approved 2026-11-05 (each about three lines: the loop they
## whisper at their row, their story while the slip prints, their last words) and
## what each leaves on the shelf. Augustine voices them.
const ECHO_LINES := {
	"whitlow": ["Box forty-one. No, forty-two. They'll want it by morning.",
		"They moved the old files down in eighty-two. I said I'd finish the boxes before I went home. The door was heavy, and the light went out, and I thought, I'll just finish this row.",
		"I finished the row. I can go home now."],
	"delacroix": ["Last trolley. Then I'm done. Last trolley.",
		"Nights on goods-in. Bring it down, sign it in, shut the door behind you. I signed it in. I don't remember the door.",
		"Tell my brother I signed it in."],
	"cole": ["That's not the label I wrote. That's not my label.",
		"The samples came back relabelled. Same jars, new numbers, new dates. I asked who changed them and they said nobody did. So I came down to check the originals.",
		"The originals are in the third tray. Somebody should look."],
	"mensah": ["Round's at three. Round's at three. Round's at...",
		"Every night at three I walked the vaults and signed the sheet. One night the sheet was already signed. My name. My writing. I came down to see who'd done it.",
		"It was a good round. It was always a good round."],
	"abernathy": ["Mind the reels. Mind the reels, they're old.",
		"Film has to be kept cold, or it eats itself. I loved that. Something you look after, so it can remember for you.",
		"Run the old reels sometime. Somebody should see them."],
	"tolliver": ["Release handle's sticking. I've reported it. I have reported it.",
		"Three times I put the ticket in for the inside handle on Vault C. Three times they said next quarter. So I came in on a Sunday to fix it myself.",
		"Next quarter. Tell them it's next quarter."],
	"sorokina": ["Sign here. And here. And here.",
		"I carried the cases between floors. I never knew what was in them; they said it was better that way. That night the case was warm, and everything else was cold.",
		"I never opened it. I want somebody to know I never opened it."],
	"fenner": ["First week. First week. Don't ask, just do it.",
		"I was a temp. First week. They told me to bring a box down and not to read it. I didn't read it. But my own name was on the side.",
		"I'd only been here a week."],
	"haddad": ["Minus twenty-five. Hold it at minus twenty-five.",
		"The deep freeze was mine. You keep it steady, you keep it quiet. My daughter drew me the compressors. I kept it in my locker. I keep thinking she's waiting up.",
		"Tell her the compressors are fine. Tell her I'm coming."],
}
## What each leaves behind: a paper on the shelf at their row (a memory, or a piece
## of evidence the crew can carry out). Approved 2026-11-05.
const ECHO_LEAVES := {
	"whitlow": {"title": "Box label", "lines": [{"text": "BOX 42  -  COMPLETE", "hand": true}, {"text": "A.W.", "hand": true}]},
	"delacroix": {"title": "Goods-in docket", "lines": ["HALCYON GOODS-IN  -  RECEIVED IN GOOD ORDER", {"text": "signed F. Delacroix", "hand": true}]},
	"cole": {"title": "Sample tray card", "lines": ["TRAY 3  -  ORIGINALS", {"text": "relabelled: DESTROYED PER ADMIN", "hand": true}, "Initialled: (blank)"]},
	"mensah": {"title": "Round sheet", "lines": ["SECURITY ROUND  -  VAULTS  -  03:00", {"text": "ticked, every night for a week, in one hand", "hand": true}, "Signed: O. Mensah"]},
	"abernathy": {"title": "Film can label", "lines": [{"text": "HALCYON OPENING DAY 1978", "hand": true}, {"text": "DO NOT DISCARD  -  R.A.", "hand": true}]},
	"tolliver": {"title": "Maintenance ticket", "lines": ["WORK REQUEST: VAULT C INSIDE RELEASE  -  FAULTY", "DEFERRED", "DEFERRED", "DEFERRED", {"text": "G. Tolliver, refrigeration", "hand": true}]},
	"sorokina": {"title": "Courier chit", "lines": ["INTERNAL COURIER  -  CASE 7", "FLOOR 14 TO B1", "DO NOT OPEN", {"text": "L.S.", "hand": true}]},
	"fenner": {"title": "Records box label", "lines": ["PERSONNEL  -  TERMINATED", {"text": "FENNER, P.", "hand": false}, "dated the week he started"]},
	"haddad": {"title": "Crayon drawing", "lines": [{"text": "DADDYS COLD MACHINES", "hand": true}, {"text": "(three big boxes, all smiling)", "hand": true}]},
}

## The sign on the time clock: where the table's name is found.
const CLOCK_SIGN_LINES := [
	"LONE WORKER TIME CLOCK  -  COLD STORE B1",
	"Punch IN at every vault door. Punch OUT on the way back.",
	"So nobody is left inside.",
	"The vault readers punch your card for you.",
	"Every punch goes in the clock's log: freezer_log",
	{"text": "still inside = no clock_out yet. empty, not zero.", "hand": true},
]
## The supervisor's note by the rack: why counting the rack is wrong.
const SUPERVISOR_LINES := [
	"TO ALL COLD STORE STAFF",
	"Missed punches are fixed in the LOG, not on the rack.",
	"The rack is not the record.",
	{"text": "D. Quarles, cold store supervisor", "hand": true},
]
## The IN/OUT whiteboard: years stale, every name on it long gone.
const WHITEBOARD_LINES := [
	"IN / OUT",
	{"text": "Marsh  - OUT", "hand": true},
	{"text": "Kowal - IN (vault B, back by 4)", "hand": true},
	{"text": "Quint  - OUT", "hand": true},
	{"text": "Pruitt - leave", "hand": true},
	{"text": "(nobody's wiped this in years)", "hand": true},
]
## The cradle card in the IT cage: the first script, filled in for the dock's cradle.
const CRADLE_CARD := [
	"EARPIECE CRADLE  -  PAIRING SCRIPT  (dock cradle, 2 sets)",
	{"text": "let key = \"%s\";", "hand": false},
	{"text": "let count = 2;", "hand": false},
	{"text": "let paired = 0;", "hand": false},
	{"text": "while (paired < count) {", "hand": false},
	{"text": "  let res = await api.post(\"/earpieces/pair\", {}, {\"X-Api-Key\": key});", "hand": false},
	{"text": "  console.log(res.status);", "hand": false},
	{"text": "  paired = paired + 1;", "hand": false},
	{"text": "  await sleep(1000);", "hand": false},
	{"text": "}", "hand": false},
	{"text": "one set at a time, it takes a second each. this is the DOCK cradle's key. the cage's own is on the bench.", "hand": true},
	{"text": "on a terminal: .script opens the runner. ^S save, ^R run, ^T stop", "hand": true},
]
## The sticky on the IT bench: the floor's services key.
const BENCH_STICKY := "IT cage svc key: %s  (doors, cradle, clock)"
## The IT tech's note by the anteroom terminal: the watchdog, for the anteroom door.
const TECH_NOTE := [
	"since Epsilon the sweep re-locks the anteroom every few secs. watchdog:",
	{"text": "let key = \"<the IT key>\";", "hand": false},
	{"text": "let door = \"%s\";", "hand": false},
	{"text": "while (true) {", "hand": false},
	{"text": "  let res = await api.get(\"/doors/\" + door, {\"X-Api-Key\": key});", "hand": false},
	{"text": "  if (res.body.locked) {", "hand": false},
	{"text": "    await api.patch(\"/doors/\" + door, {\"locked\": false}, {\"X-Api-Key\": key});", "hand": false},
	{"text": "    console.log(door + \" opened\");", "hand": false},
	{"text": "  }", "hand": false},
	{"text": "  await sleep(1000);", "hand": false},
	{"text": "}", "hand": false},
	{"text": "ONLY write when it's locked. write to an open door and the relay guard trips: shut 30s.", "hand": true},
	{"text": "deep freeze door shuts on its own safety timer. same trick. GET /doors lists them.", "hand": true},
]
## The deep freeze's door sign.
const VAULT_C_SIGN := [
	"VAULT C  -  DEEP FREEZE  -  -25 C",
	"Door closes and latches on its safety timer.",
	{"text": "inside release OUT OF ORDER. do not go in alone.", "hand": true},
]
## The time clock's service page, pinned beside it: closing entries by hand.
const SERVICE_PAGE := [
	"TIME CLOCK  -  SERVICE PAGE",
	"Close an entry: POST /clock_outs  {\"entry\": <id>}",
	"Vault network only. The wired terminals are refused.",
	"The clock prints a slip for each. Wait for it before the next: GET /clock says how long.",
	"Visitors are punched in on card VIS-nn, name VISITOR.",
	"NEVER close a visitor who is still inside: the vault will think it's empty.",
	"Wrongly closed? POST /clock_ins  {\"card\": \"VIS-nn\", \"vault\": \"<vault>\"}",
	{"text": "last month's missed punches, vault A:", "hand": true},
	{"text": "let open = await db.query(\"SELECT * FROM freezer_log WHERE clock_out IS NULL AND vault = 'A'\");", "hand": false},
	{"text": "for (const entry of open) {", "hand": false},
	{"text": "  await api.post(\"/clock_outs\", {\"entry\": entry.id}, {\"X-Api-Key\": key});", "hand": false},
	{"text": "  await sleep(20000);", "hand": false},
	{"text": "}", "hand": false},
]
## The access point stickers.
const AP_LINES := ["VAULT NETWORK  -  ACCESS POINT", "Wireless decks only. No jacks in the vaults."]
## The bench's sign.
const BENCH_LINES := ["IT CAGE  -  DECK BENCH", "Loaner decks. Wireless cards and script runner chips in the drawer.", {"text": "fit both before you go in the cold. no jacks past the anteroom.", "hand": true}]
## The self-test label on the cradle (V16): one set, the first script. Its last line
## is the cradle card's own.
const SELF_TEST := [
	"EARPIECE CRADLE  -  SELF-TEST  (pairs one set)",
	{"text": "let key = \"<the IT key>\";", "hand": false},
	{"text": "let res = await api.post(\"/earpieces/pair\", {}, {\"X-Api-Key\": key});", "hand": false},
	{"text": "console.log(res.status);", "hand": false},
	{"text": "201 = paired. the IT key's on the bench sticky.", "hand": true},
	{"text": "on a terminal: .script opens the runner. ^S save, ^R run, ^T stop", "hand": true},
]
## The sign over the deep freeze's door (V30): its id, as the anteroom's sign shows its own.
const VAULT_C_DOOR_SIGN := "VAULT C  -  DEEP FREEZE  -  %s"
const ANTE_DOOR_SIGN := "ANTEROOM  -  %s"
## The warm-up area's sign (V32).
const WARM_UP_SIGN := "WARM-UP AREA"

## The queries on screen (the case chip): each case's shape, its pieces colored by
## kind. The open case's (V1) and the try's (V2); the others are their hint 1's.
const OPEN_QUERY := "SELECT name, clock_in FROM {table} WHERE {column} IS NULL ORDER BY clock_in;"
const TRY_QUERY := "let key = \"{key}\";\nlet res = await api.post(\"/earpieces/pair\", {}, {\"X-Api-Key\": key});\nconsole.log(res.status);"
## The pieces (V3, V4, V17, V26, V27).
const TABLE_PIECE := {"id": "table", "label": "The clock's log", "value": "freezer_log", "task": "Find the table the time clock keeps", "where": "The sign on the time clock", "seen_in": "freezer_log", "blank": "enter_table_name"}
const COLUMN_PIECE := {"id": "column", "label": "Empty while someone's inside", "value": "clock_out", "task": "Find the column a visit fills in on the way out", "where": "The sign on the time clock", "blank": "enter_column"}
const KEY_PIECE := {"id": "key", "label": "The IT key", "task": "Find the key the cage's cradle answers to", "where": "The sticky on the deck bench", "blank": "enter_key"}
const ANTE_PIECE := {"id": "ante_door", "label": "The anteroom door", "task": "Find the id of the door that keeps locking", "where": "The sign over the anteroom door", "blank": "enter_door"}
const FREEZER_PIECE := {"id": "freezer_door", "label": "The deep freeze door", "task": "Find the id of Vault C's door", "where": "The sign over Vault C's door", "blank": "enter_door"}
## The pair case's steps (V15; step 2 is the case's details).
const PAIR_STEPS := [{"id": "try", "text": "Test the cradle with one set"}, {"id": "loop", "text": TEXT.case_pair_do}]
## The open case's slot (V5), and the pencil lines under it for a wrong click (V6-V11).
const OPEN_SLOT := "In there the longest:"
const OPEN_RACK := "That's the rack, and the rack is not the record. The blank wants a name from the log."
const OPEN_CLOSED := "That visit clocked out. The blank wants someone who never did."
const OPEN_OURS := "That's us. We punched in at the landing tonight."
const OPEN_NOT_FIRST := "Still in there, but not the longest. Who went in first?"
const OPEN_ROW := "That's the right visit. The blank wants the name on it."
const OPEN_MISS := "Not that one: the blank wants who's been in there the longest."
## A slot no line fills: only the cell in the log does (no paper: the rack is not the record).
const NO_LINE := ["\u0001"]
## The first hint tiers, each a place in the building (Puzzle.spots; V12, V18, V21,
## V25, V28, V29, V31), skipped once it's found.
const SPOT_CLOCK := "the sign on the time clock, in the time office, says where every punch goes."
const SPOT_SELF_TEST := "the label on the cradle has a test script that pairs one set."
const SPOT_CARD := "the pairing card on the bench does it for a whole crew, one set at a time."
const SPOT_PAGE_LIST := "the service page beside the time clock has a loop over the open visits."
const SPOT_NOTE := "the IT tech pinned a note by this terminal about the anteroom door."
const SPOT_VAULT_C := "the sign on Vault C's door says why it won't stay open."
const SPOT_PAGE_RELEASE := "the service page beside the time clock says how to close an entry."
## The chapters of Journey through JavaScript, each landing when its step opens (M3).
const CHAPTER_OF := {"pair": "js_if", "loop": "js_loops", "list": "js_each"}

const CASES := {"open": TEXT.case_open, "pair": TEXT.case_pair, "list": TEXT.case_list, "hold": TEXT.case_hold, "release": TEXT.case_release, "stop": TEXT.case_stop}
const CASE_DO := {"open": TEXT.case_open_do, "pair": TEXT.case_pair_do, "list": TEXT.case_list_do, "hold": TEXT.case_hold_do, "release": TEXT.case_release_do, "stop": TEXT.case_stop_do}
## The cases, in the order they open (the last is optional).
const CASE_ORDER := ["open", "pair", "list", "hold", "release"]

const STAIR_AT := Vector3(4, 0, 6)
const STAIR_YAW := -90.0
const ANTE_DOOR_AT := Vector3(0, 1.15, -8)
const VAULT_C_DOOR_AT := Vector3(20, 1.25, -14)
## The rooms, for the cold, the readers and tests.
const LANDING := AABB(Vector3(-4, -0.5, 4), Vector3(8, 4, 4))
const HALL := AABB(Vector3(-3, -0.5, -8), Vector3(6, 4, 12))
const OFFICE := AABB(Vector3(-13, -0.5, -8), Vector3(10, 4, 12))
const IT_CAGE := AABB(Vector3(3, -0.5, -8), Vector3(7, 4, 7))
const PASSAGE := AABB(Vector3(3, -0.5, -1), Vector3(7, 4, 3))
const GOODS := AABB(Vector3(10, -0.5, -12), Vector3(10, 4, 14))
const ANTEROOM := AABB(Vector3(-2, -0.5, -12), Vector3(4, 4, 4))
const CORRIDOR := AABB(Vector3(-14, -0.5, -16), Vector3(34, 4, 4))
const VAULT_A := AABB(Vector3(-12, -0.5, -24), Vector3(8, 4, 8))
const VAULT_B := AABB(Vector3(-2, -0.5, -24), Vector3(8, 4, 8))
const VAULT_C := AABB(Vector3(20, -0.5, -20), Vector3(10, 4, 12))
const PLANT := AABB(Vector3(-22, -0.5, -18), Vector3(8, 4, 8))
## The warm-up area (M6): a recess off the corridor's north side, halfway between the
## anteroom and Vault C, outside the corridor's cold.
const WARM_UP := AABB(Vector3(8.5, -0.5, -19), Vector3(3, 4, 3))
const VAULT_ROOMS := {"A": VAULT_A, "B": VAULT_B, "C": VAULT_C}
## Where the access points hang: the corridor's and each vault's (the vault network).
const AP_ROOMS := [CORRIDOR, VAULT_A, VAULT_B, VAULT_C, WARM_UP]
## Warm rooms, where the cold lets go.
const WARM_ROOMS := [LANDING, HALL, OFFICE, IT_CAGE, PASSAGE, GOODS, ANTEROOM, PLANT, WARM_UP]
## The rows in each vault, level space: where an echo stands (and faces).
const ROWS := {
	"A-1": [Vector3(-10.5, 0, -18.5), 90.0], "A-2": [Vector3(-8, 0, -21.5), 0.0], "A-3": [Vector3(-5.5, 0, -18.5), -90.0],
	"B-1": [Vector3(-0.5, 0, -18.5), 90.0], "B-2": [Vector3(2, 0, -21.5), 0.0], "B-4": [Vector3(4.5, 0, -18.5), -90.0],
	"C-1": [Vector3(23, 0, -11), 180.0], "C-2": [Vector3(27.5, 0, -14), -90.0], "C-3": [Vector3(23, 0, -17.5), 0.0],
}
## The cold: stamina drains in the cold rooms (more in the deep freeze, more again in
## a vault the clock thinks is empty), then health, but never below COLD_FLOOR: the
## cold slows and hurts, never kills (revive or drag out).
const COLD_DRAIN := 3.0
const COLD_HURT := 0.8
const COLD_FLOOR := 20.0
## Below this much stamina the cold gets into you.
const COLD_LOW := 10.0
const WARM_HEAL := 3.0
## The earpiece cradle pairs one set at a time, this long each.
const PAIR_TIME := 0.6
## Eight sets: one each for the crew, and for Ines and Tomas (M2).
const CRADLE_SLOTS := 8
## Needless writes to an open door before the relay guard trips, and how long it holds.
const GUARD_WRITES := 3
const GUARD_HOLD := 30.0
## The practice door holds once it's been re-opened after this many sweeps in a row.
const HOLD_SWEEPS := 2
## A re-open this soon after a lock counts as the watchdog (or a quick hand) holding it.
const HOLD_WINDOW := 2.5
## How often the floor below makes itself heard, if the Custodian came down.
const CUSTODIAN_EVERY := 70.0
const EXIT_HOLD := 2.0

var data: Dictionary
## The floor's services; every terminal and deck reaches them through its own NetLink.
var api: FacilityAPI
var wired: NetLink
var office: Terminal
var it_terminal: Terminal
var ante_terminal: Terminal
var stair_in: Door
var stair_gate: Door
var ante_door: Door
var vault_c_door: Door
var book: Interactable
var bench: Interactable
var rack: Document
var exit_trigger: Trigger
var crossing: Trigger
var staffers := {}  # "ines"/"tomas" -> Staffer
var echoes := {}  # echo id -> Echo
## Portable decks, one per player slot (Deck1..Deck6), each following its player.
var decks: Array[Terminal] = []
## The network each deck is on (decided by the host): "wired" (a jack, in the warm
## rooms), "vault" (an access point, with a wireless card), or "none".
var deck_net := {}
## Players (by peer id) whose deck has the wireless card and script runner fitted.
var fitted := {}
## The service the current request comes in on: "wired" or "vault" (NetLink sets it).
var net_now := "wired"

## The cradle: sets paired, and busy while the last one pairs.
var paired := 0
var pair_busy := false
var pair_requests := 0
var pair_409s := 0
## Doors: their lock generation (counts every unlock, so a latch timer only shuts the
## opening it was for), needless writes since the last sweep or latch, the relay
## guard, and when each was last locked by the sweep or its timer (host clock).
var door_gen := {}
var needless := {}
var guarded := {}
var _locked_at := {}
## The practice door: sweeps in a row it was re-opened after, quickly.
var held_sweeps := 0
var _held_this_sweep := false
var _since_sweep := 0.0
var _sweep_clock := 0.0
## The time clock's printer: busy while a slip prints.
var printing := false
var last_slip := ""
var _next_entry := 1000
## Crew cards inside each vault right now: card -> vault (the readers' view), and the
## vaults the clock thinks are empty although the crew is inside.
var crew_in := {}
var unoccupied := {}
var released_echoes := {}
var all_free := false
var stairs_open := false
var book_found := false
var earpieces := false
var crossed := false
var watchdog_used := false
var tips_sent := {}
var custodian_down := false
var _custodian_seen := false
var _custodian_clock := 0.0
var _static_clock := 0.0
## Which of tonight's echoes the static carries next, and whether the landing's
## last beat has played.
var _static_turn := 0
var landing_said := false
## The entry whose slip is printing (set where the punch went through, the same on
## every machine), so the slip can be laid by the clock when it's done.
var _slip_row := {}
var _cold_noted := false
var _numb_noted := false
var _was_cold := false
## Health as the cold left it last frame (-1 when not cold): nothing heals in here.
var _cold_health := -1.0
var _started_msec := 0
var _voice: Voice

## Stations. Ladder A for the new words (let, while, wait, if, log); the review
## ladder for IS NULL (floor 18) and the requests (floor 9).
var open_puzzle: Puzzle
var pair_puzzle: RequestPuzzle
var list_puzzle: RequestPuzzle
## The listing case: the open entries' names a script has logged, one a line, this
## run of it (host). The runtimes listened to for them.
var listed := {}
## One run of a script logged a VISITOR line: one of ours, which the listing skips.
var listed_ours := false
var _watched := {}
## The cradle, by script: the screen of the last pair request, whether a run got a
## 409 busy, and how many requests came after one set each (an endless loop).
var _pair_from := ""
var _pair_409_run := false
var _pair_extra := 0
var practice_puzzle: RequestPuzzle
var hold_puzzle: RequestPuzzle
var release_puzzle: RequestPuzzle
var stop_puzzle: RequestPuzzle
## Timings, here so tests can shorten them.
var sweep_every := 8.0
var freezer_timer := 8.0
var punch_interval := 20.0
var guard_hold := GUARD_HOLD
var pair_time := PAIR_TIME
## The listing opens this long after the last set pairs: once the voice in the ear has
## spoken (M4).
var listing_after := 8.0
## The first set the cradle pairs is the try (M1); the run that paired it isn't
## told it's short of sets.
var try_puzzle: RequestPuzzle
var _try_run := false
## Every entry is closed: the tidy-up opens the first time someone's in the warm (M5).
var stop_waiting := false
## Chapters waiting for the book, or for their turn: one lands at each gate (M3).
var pending_chapters: Array = []


## The floor's services on one network: a request through this link is answered by
## the floor's API as if it came in on `net` (a wired terminal's, or a deck's, whose
## network moves with it). Everything else about the API is the floor's.
class NetLink:
	extends FacilityAPI
	var level: Node
	var net := "wired"
	var deck := -1
	## Whose screen this is: office, it, ante, or deck<n> (SYSOP answers there).
	var terminal := "ante"

	func send(method: String, path: String, headers := {}, body := "") -> Dictionary:
		var on := net
		if deck >= 0:
			on = level.deck_net.get(deck, "none")
		if on == "none":
			return _reply({"status": 503, "body": {"error": "No signal. The deck needs a jack or an access point (and a wireless card for that)."}})
		level.net_now = on
		var res: Dictionary = level.api.send(method, path, headers, body)
		level.net_now = "wired"
		level._on_sent(self, method, path, res)
		return res


func build() -> void:
	data = Level6Data.build(Game.run_seed)
	load_level_seed(data.sql)
	db.read_only = true  # Epsilon (floor 10 on): the database only reads
	sweep_every = data.sweep
	freezer_timer = data.freezer_timer
	punch_interval = data.punch_interval
	custodian_down = not get_node("/root/Game").custodian_sealed
	api = _make_api()
	wired = _link("wired")
	_make_puzzles()

	var colors := {"floor": Color(0.32, 0.33, 0.34), "wall": Color(0.62, 0.64, 0.64)}
	var cold := {"floor": Color(0.55, 0.6, 0.64), "wall": Color(0.78, 0.84, 0.88)}
	# The landing: STAIR 2 on the east wall, down from 9 and on down to B2.
	Greybox.room(geo, Vector3(0, 0, 6), Vector3(8, 3.2, 4), colors, [
		{"wall": "n", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "e", "at": 0.0, "width": Stairwell.DOOR_W, "height": Stairwell.DOOR_H},
	])
	Greybox.label(geo, Vector3(0, 2.75, 7.88), "B1   COLD STORE", 56, Color(0.75, 0.8, 0.85), 180)
	stair_in = Stairwell.build(self, geo, STAIR_AT, STAIR_YAW, "B1", "STAIR 2", 1)
	stair_in.name = "Door_STAIR-IN"  # unlocked once the whole crew is down (start())
	exit_door = stair_in
	_build_stair_gate()

	_build_hall(colors)
	_build_office(colors)
	_build_it_cage(colors)
	_build_goods(colors)
	_build_anteroom(colors)
	_build_corridor(cold)
	_build_warm_up(colors)
	_build_vaults(cold)
	_build_plant(colors)
	_place_people()
	_label_rows()
	_make_decks()

	add_light("LB1-LANDING", Vector3(0, 3.2, 6), 6.0, 0.8)
	add_light("LB1-OFFICE", Vector3(-8, 3.2, -2), 9.0, 0.9, Color(1.0, 0.92, 0.8))
	add_light("LB1-IT", Vector3(6.5, 3.0, -4.5), 6.0, 0.9)
	add_light("LB1-GOODS", Vector3(15, 3.2, -5), 9.0, 0.6, Color(1.0, 0.85, 0.6))
	add_light("LB1-LANDING", Vector3(0, 3.0, -2), 7.0, 0.6)
	for x in [-9.0, 3.0, 15.0]:
		add_light("LB1-CORRIDOR", Vector3(x, 3.0, -14), 8.0, 0.7, Color(0.75, 0.88, 1.0))
	add_light("LB1-A", Vector3(-8, 3.0, -20), 7.0, 0.7, Color(0.75, 0.88, 1.0))
	add_light("LB1-B", Vector3(2, 3.0, -20), 7.0, 0.7, Color(0.75, 0.88, 1.0))
	add_light("LB1-C", Vector3(25, 3.0, -14), 8.0, 0.7, Color(0.7, 0.85, 1.0))
	add_light("LB1-PLANT", Vector3(-18, 3.0, -14), 7.0, 0.8, Color(1.0, 0.75, 0.5))

	spawn = Transform3D(Basis(Vector3.UP, deg_to_rad(STAIR_YAW + 180.0)), Stairwell.landing_slot(STAIR_AT, STAIR_YAW, 0))
	# The crossing: everyone in the deep freeze (a crew together, as floors end).
	crossing = Trigger.create(self, Vector3(25, 1, -14), Vector3(9, 2, 11))
	crossing.name = "Crossing"
	crossing.require_all = true
	crossing.waiting.connect(func(n, total): sync.team_notice(TEXT.cross_wait % [n, total]))
	crossing.entered.connect(func(_b): sync.event("_crossed"), CONNECT_ONE_SHOT)
	# The vault readers: every visit punches the card in, and out again on the way back.
	for v in VAULT_ROOMS:
		var box: AABB = VAULT_ROOMS[v]
		var reader := Area3D.new()
		reader.name = "Reader_" + v
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = box.size - Vector3(0.6, 0, 0.6)
		shape.shape = bs
		reader.add_child(shape)
		reader.position = box.get_center()
		add_child(reader)
		reader.body_entered.connect(_on_reader.bind(v, true))
		reader.body_exited.connect(_on_reader.bind(v, false))
	# The way down: past STAIR 2's gate, at the copied landing for B2 below.
	var below := Stairwell.landing_box()
	var holder := Stairwell.of(stair_in)
	exit_trigger = Trigger.create(holder, below.get_center() - Vector3(0, Stairwell.STOREY, 0), below.size)
	exit_trigger.name = "StairsDown"
	exit_trigger.require_all = true
	exit_trigger.waiting.connect(func(n, total): sync.team_notice(TEXT.stairs_wait % [n, total]))
	exit_trigger.entered.connect(func(_b): sync.event("_on_exit"), CONNECT_ONE_SHOT)
	# Each screen has its own link, so a script's mistakes are answered where they're made.
	wired.terminal = "office"
	office.api = wired
	it_terminal.api = _link("wired", -1, "it")
	ante_terminal.api = _link("wired", -1, "ante")
	# No escort on file: every B1 screen runs under the security policy (P1).
	for term in [office, it_terminal, ante_terminal]:
		term.policy = true


## A link to the floor's services on one network (or a deck's, `deck` >= 0), from
## the screen `terminal`.
func _link(net: String, deck := -1, terminal := "ante") -> NetLink:
	var l := NetLink.new()
	l.level = self
	l.net = net
	l.deck = deck
	l.terminal = terminal
	return l


## STAIR 2 goes on down to B2, behind a gate across the flight: cold store staff only,
## after hours. It opens once every entry on B1 is closed.
func _build_stair_gate() -> void:
	var holder := Stairwell.of(stair_in)
	var mid := (-Stairwell.INNER - Stairwell.CORE) / 2.0
	stair_gate = Door.create(holder, "STAIR-2-GATE", Vector3(mid, 1.1, Stairwell.LANDING_Z - 0.05), Vector3(Stairwell.INNER - Stairwell.CORE, 2.2, 0.06), Color(0.55, 0.5, 0.2))
	stair_gate.name = "StairGate"
	Greybox.label(holder, Vector3(mid, 2.45, Stairwell.LANDING_Z + 0.02), "B2  -  STAFF ONLY AFTER HOURS", 22, Color(0.8, 0.2, 0.1), 0.0)


func player_spawn(index: int) -> Transform3D:
	return global_transform * Transform3D(spawn.basis, Stairwell.landing_slot(STAIR_AT, STAIR_YAW, index))


# --- The rooms ------------------------------------------------------------------------

func _build_hall(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(0, 0, -2), Vector3(6, 3.2, 12), colors, [
		{"wall": "s", "at": 0.0, "width": 2.4, "height": 2.4},
		{"wall": "w", "at": -2.0, "width": 1.4, "height": 2.3},
		{"wall": "e", "at": -4.5, "width": 1.4, "height": 2.3},
		{"wall": "e", "at": 0.5, "width": 2.0, "height": 2.4},
		{"wall": "n", "at": 0.0, "width": 1.6, "height": 2.3},
	])
	Greybox.label(geo, Vector3(0, 2.8, -7.88), "VAULTS  >", 36, Color(0.75, 0.85, 0.95), 0)
	Greybox.label(geo, Vector3(-2.88, 2.6, -2), "TIME OFFICE", 28, Color(0.8, 0.8, 0.75), 90)
	Greybox.label(geo, Vector3(2.88, 2.6, -4.5), "IT CAGE", 28, Color(0.8, 0.8, 0.75), -90)
	Greybox.label(geo, Vector3(2.88, 2.6, 0.5), "GOODS-IN", 28, Color(0.8, 0.8, 0.75), -90)
	# The anteroom terminal, on a wall shelf by the door: the practice watchdog runs here.
	Greybox.box(geo, Vector3(-2.2, 0.5, -6.6), Vector3(1.2, 1.0, 0.8), Color(0.4, 0.4, 0.42), "AnteDesk")
	ante_terminal = Terminal.spawn(geo, Vector3(-2.2, 1.0, -6.6), 90, "ANTEROOM", db, terminal_ui)
	ante_terminal.name = "AnteTerminal"
	ante_terminal.set_meta("scripts", true)
	ante_terminal.set_meta("ticked_elsewhere", true)
	ante_terminal.puzzles = [practice_puzzle]
	ante_terminal.boot_lines = [
		"HALCYON COLD STORE  -  ANTEROOM",
		"Services: /doors  /clock      Scripts: .script",
	]
	ante_terminal.requested.connect(_on_request.bind("ante"))
	var note := Document.place(geo, Vector3(-2.88, 1.6, -5.4), -90, "Tech's note", _tech_note(), false, "paper", Vector2(0.21, 0.3))
	note.name = "TechNote"
	note.clues = [{"case": "hold", "text": "The IT tech's watchdog: while (true), GET the door, if it's locked PATCH it open and log it, then wait. Only write when it's locked, or the relay guard holds it shut 30 s. Change door to hold another."}]
	note.spot = "tech_note"


func _build_office(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(-8, 0, -2), Vector3(10, 3.2, 12), {"floor": Color(0.36, 0.32, 0.28), "wall": colors.wall}, [
		{"wall": "e", "at": -2.0, "width": 1.4, "height": 2.3},
	])
	Greybox.label(geo, Vector3(-8, 2.8, -7.88), "TIME OFFICE  -  COLD STORE", 40, Color(0.8, 0.78, 0.7), 0)
	# The lone-worker time clock by the door, its sign and its service page.
	Greybox.box(geo, Vector3(-3.4, 1.4, -4.2), Vector3(0.3, 0.6, 0.5), Color(0.55, 0.5, 0.4), "TimeClock")
	Greybox.label(geo, Vector3(-3.56, 1.55, -4.2), data.clock, 28, Color(1.0, 0.25, 0.15), -90).name = "Clock"
	# The slip tray under it: every entry the clock closes tonight prints one here.
	Greybox.box(geo, Vector3(-3.75, 0.9, -4.2), Vector3(0.5, 0.04, 0.6), Color(0.45, 0.42, 0.36), "SlipTray")
	var sign := Document.place(geo, Vector3(-3.12, 1.6, -5.3), 90, "Time clock sign", CLOCK_SIGN_LINES, false, "laminated", Vector2(0.28, 0.3))
	sign.name = "ClockSign"
	sign.clues = [{"case": "open", "text": "The time clock: every vault visit punches IN, and OUT again on the way back. The log is freezer_log. Still inside = no clock_out yet."}]
	sign.pieces = [{"case": "open", "piece": "table", "text": "freezer_log", "kind": "table"}, {"case": "open", "piece": "column", "text": "clock_out", "kind": "column"}]
	sign.spot = "clock_sign"
	sign.read_by.connect(func(_p): sync.event("_ask", ["open"]))
	var page := Document.place(geo, Vector3(-3.12, 1.6, -3.1), 90, "Clock service page", _service_page(), false, "paper", Vector2(0.21, 0.3))
	page.name = "ServicePage"
	# Quiet until the listing: its clues wait in Floor notes until their cases open (M4).
	page.clues = [
		{"case": "list", "text": "The service page's loop: db.query runs the open-visits query from a script, and for (const entry of open) goes once for each row it found. Its query is vault A's."},
		{"case": "release", "text": "The clock's service page: POST /clock_outs with {\"entry\": id}, vault network only. Wait for each slip (GET /clock). Visitors are VIS-nn, name VISITOR: never close one who's still inside."},
	]
	page.spot = "service_page"
	# The card rack on the north wall: the cards in its IN slots, as players see them.
	Greybox.box(geo, Vector3(-7, 1.4, -7.8), Vector3(2.4, 1.6, 0.2), Color(0.5, 0.45, 0.35), "CardRack")
	rack = Document.place(geo, Vector3(-7, 1.5, -7.66), 0, "Card rack (IN)", _rack_lines(), false, "clipboard", Vector2(0.3, 0.4))
	rack.name = "CardRack"
	rack.clues = [{"case": "open", "text": "The card rack shows %d cards in the IN slots." % data.rack_in.size()}]
	rack.read_by.connect(func(_p): sync.event("_rack_read"))
	var quarles := Document.place(geo, Vector3(-9.2, 1.7, -7.88), 180, "Supervisor's note", SUPERVISOR_LINES, false, "paper", Vector2(0.21, 0.2))
	quarles.clues = [{"case": "open", "text": "The supervisor: missed punches are fixed in the log, not the rack. The rack is not the record."}]
	# The IN/OUT whiteboard on the west wall.
	Greybox.panel(geo, Vector3(-12.9, 1.6, -1), Vector3(0.04, 1.0, 1.8), Color(0.92, 0.92, 0.9), 0.0)
	Document.place(geo, Vector3(-12.88, 1.6, 0.2), -90, "IN/OUT whiteboard", WHITEBOARD_LINES, false, "laminated", Vector2(0.3, 0.3))
	# The supervisor's desk and the office terminal.
	Greybox.box(geo, Vector3(-8, 0.5, 1.5), Vector3(2.8, 1.0, 0.8), Color(0.42, 0.34, 0.28), "OfficeDesk")
	office = Terminal.spawn(geo, Vector3(-8.6, 1.0, 1.5), 180, "TIME OFFICE", db, terminal_ui)
	office.name = "OfficeTerminal"
	office.puzzles = [open_puzzle]
	office.boot_lines = [
		"HALCYON COLD STORE  -  TIME OFFICE",
		"The database reads (Protocol Epsilon). Services: /clock  /freezer_log",
	]
	office.queried.connect(_on_query.bind("office"))
	office.query_failed.connect(func(_sql, _r):
		if _is_host() and not Game.case_info("open").get("open", false):
			sync.event("_ask", ["open"]))  # a refused first look counts too
	office.requested.connect(_on_request.bind("office"))
	# The policy's card (P5), beside the floor's first policy terminal.
	TerminalPolicy.place_card(geo, Vector3(-7.55, 1.002, 1.35), 180, true).name = "PolicyCard"
	# A space heater humming under the desk: why this room is warm.
	Greybox.box(geo, Vector3(-6.8, 0.25, 1.6), Vector3(0.5, 0.5, 0.3), Color(0.6, 0.3, 0.2), "Heater")
	Greybox.ceiling_light(geo, Vector3(-6.8, 0.6, 2.0), 2.0, 0.3, Color(1.0, 0.45, 0.2))


func _build_it_cage(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(6.5, 0, -4.5), Vector3(7, 3.0, 7), {"floor": Color(0.3, 0.3, 0.32), "wall": colors.wall.darkened(0.1)}, [
		{"wall": "w", "at": -4.5, "width": 1.4, "height": 2.3},
	])
	# The cradle on the east wall: eight slots, its self-test label beside it (the try).
	Greybox.box(geo, Vector3(9.6, 1.1, -5.8), Vector3(0.5, 0.2, 2.0), Color(0.2, 0.2, 0.22), "Cradle")
	for i in CRADLE_SLOTS:
		Greybox.box(geo, Vector3(9.5, 1.24, -6.64 + i * 0.24), Vector3(0.12, 0.08, 0.12), Color(0.85, 0.2, 0.15), "CradleSlot%d" % i)
	var label := Document.place(geo, Vector3(9.88, 1.65, -4.3), 90, "Cradle self-test label", SELF_TEST, false, "laminated", Vector2(0.3, 0.24))
	label.name = "SelfTestLabel"
	label.spot = "self_test"
	label.read_by.connect(func(_p): sync.event("_ask", ["pair"]))
	# The cradle card, at the bench's other end, beside the key sticky: the pairing
	# card, for the loop (step 2). Reading it early only notes its clue (M3).
	var card := Document.place(geo, Vector3(6.8, 1.55, -7.88), 180, "Pairing card", _cradle_card(), false, "laminated", Vector2(0.3, 0.36))
	card.name = "CradleCard"
	card.clues = [{"case": "pair", "text": "The cradle card: a pairing script. let makes a box with a name; while repeats while its test is true; await sleep(1000) waits a second. Its key is the dock cradle's."}]
	card.spot = "pairing_card"
	# The IT terminal, on the bench's end.
	Greybox.box(geo, Vector3(6.5, 0.5, -7.3), Vector3(4.0, 1.0, 0.8), Color(0.38, 0.38, 0.4), "Bench")
	it_terminal = Terminal.spawn(geo, Vector3(5.2, 1.0, -7.3), 0, "IT CAGE", db, terminal_ui)
	it_terminal.name = "ITTerminal"
	it_terminal.set_meta("scripts", true)
	it_terminal.set_meta("ticked_elsewhere", true)
	it_terminal.puzzles = [try_puzzle, pair_puzzle, list_puzzle]
	it_terminal.boot_lines = [
		"HALCYON IT  -  COLD STORE CAGE",
		"Services: /earpieces  /doors  /clock      Scripts: .script",
	]
	it_terminal.requested.connect(_on_request.bind("it"))
	var sticky := Document.place(geo, Vector3(6.4, 1.003, -7.1), 0, "Key sticky", [{"text": BENCH_STICKY % data.key, "hand": true}], true, "sticky")
	sticky.name = "KeySticky"
	sticky.clues = [{"case": "pair", "text": "On the IT bench: the cage's service key, %s (doors, cradle, clock)." % data.key}]
	# Every script on the floor wants the key (V17).
	sticky.pieces = ["pair", "hold", "release", "stop"].map(func(c): return {"case": c, "piece": "key", "text": data.key, "kind": "value"})
	Document.place(geo, Vector3(8.0, 1.6, -7.88), 180, "Bench sign", BENCH_LINES, false, "laminated", Vector2(0.28, 0.24))
	# The bench: a loaner deck for anyone without one, and the upgrades for every deck.
	bench = Interactable.create(self, Vector3(7.6, 1.08, -7.3), Vector3(0.6, 0.12, 0.4), "Fit a deck for scripts (wireless card, script runner)", Color(0.25, 0.3, 0.35))
	bench.name = "DeckBench"
	bench.used.connect(func(p): sync.event("_bench_used", [players.id_of(p) if players else 1]))
	# The book under a mug at the bench's far end.
	Greybox.box(geo, Vector3(8.4, 1.08, -7.2), Vector3(0.09, 0.12, 0.09), Color(0.85, 0.85, 0.82), "Mug")
	book = Interactable.create(self, Vector3(8.4, 1.02, -7.2), Vector3(0.24, 0.04, 0.3), "Pick up: Journey through JavaScript", Color(0.95, 0.75, 0.1))
	book.name = "Book"
	book.used.connect(func(p): sync.event("_book_found", [players.id_of(p)]))
	# The passage to goods-in, south of the cage.
	Greybox.room(geo, Vector3(6.5, 0, 0.5), Vector3(7, 3.0, 3), colors, [
		{"wall": "w", "at": 0.5, "width": 2.0, "height": 2.4},
		{"wall": "e", "at": 0.5, "width": 2.0, "height": 2.4},
	])


func _build_goods(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(15, 0, -5), Vector3(10, 3.4, 14), {"floor": Color(0.28, 0.28, 0.28), "wall": colors.wall.darkened(0.2)}, [
		{"wall": "w", "at": 5.5, "width": 2.0, "height": 2.4},
		{"wall": "n", "at": 0.0, "width": 1.2, "height": 1.1},
		{"wall": "e", "at": -1.0, "width": 2.0, "height": 2.6},
	])
	Greybox.label(geo, Vector3(15, 2.9, 1.88), "GOODS-IN", 40, Color(0.8, 0.8, 0.75), 180)
	# The dead dock stairs, east: a dark shaft, roped off. (On 9 they were already gone.)
	Greybox.box(geo, Vector3(21.5, 1.6, -6), Vector3(3, 3.2, 2.4), Color(0.05, 0.05, 0.06), "DockShaft")
	Greybox.box(geo, Vector3(19.7, 1.0, -6), Vector3(0.05, 0.05, 2.0), Color(0.9, 0.75, 0.1), "Rope")
	Greybox.label(geo, Vector3(19.9, 2.4, -6), "DOCK STAIRS  -  OUT OF SERVICE", 22, Color(0.7, 0.15, 0.1), -90)
	# The conveyor to the vaults, through a hatch in the north wall: a crawl.
	Greybox.box(geo, Vector3(15, 0.35, -8.5), Vector3(1.2, 0.1, 6.5), Color(0.2, 0.2, 0.2), "Conveyor")
	Greybox.label(geo, Vector3(15, 1.5, -11.88), "CONVEYOR TO VAULTS", 20, Color(0.8, 0.8, 0.75), 0)
	Traversal.vent(self, Vector3(15, 0.0, -11.2), Vector3(15, 0.0, -12.8), Vector2(1.2, 1.1))
	# Pallets and a dead forklift.
	for z in [-2.0, -4.5]:
		Greybox.box(geo, Vector3(12, 0.5, z), Vector3(1.2, 1.0, 1.2), Color(0.5, 0.4, 0.28), "Pallet")
	Greybox.box(geo, Vector3(17.5, 0.8, 0.0), Vector3(1.2, 1.6, 2.2), Color(0.75, 0.6, 0.1), "Forklift")


func _build_anteroom(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(0, 0, -10), Vector3(4, 3.0, 4), {"floor": colors.floor, "wall": Color(0.7, 0.75, 0.78)}, [
		{"wall": "s", "at": 0.0, "width": 1.6, "height": 2.3},
		{"wall": "n", "at": 0.0, "width": 1.6, "height": 2.3},
	])
	ante_door = add_door(data.doors.ante, ANTE_DOOR_AT, Vector3(1.6, 2.3, 0.12))
	# The strip curtain on the cold side: you walk through it.
	for i in 6:
		Greybox.panel(geo, Vector3(-0.65 + i * 0.26, 1.2, -11.95), Vector3(0.24, 2.2, 0.01), Color(0.8, 0.9, 1.0, 0.4), 0.0)
	# The sign over its door, hall side: the id the watchdog needs (V26).
	var sign := Document.place(geo, Vector3(0, 2.5, -7.9), 180, "Sign over the anteroom door", [ANTE_DOOR_SIGN % data.doors.ante], false, "laminated", Vector2(0.5, 0.12))
	sign.name = "AnteDoorSign"
	sign.pieces = [{"case": "hold", "piece": "ante_door", "text": data.doors.ante, "kind": "value"}]


func _build_corridor(cold: Dictionary) -> void:
	Greybox.room(geo, Vector3(3, 0, -14), Vector3(34, 3.0, 4), cold, [
		{"wall": "s", "at": -3.0, "width": 1.6, "height": 2.3},
		{"wall": "s", "at": 12.0, "width": 1.2, "height": 1.1},
		{"wall": "n", "at": -11.0, "width": 1.6, "height": 2.3},
		{"wall": "n", "at": -1.0, "width": 1.6, "height": 2.3},
		{"wall": "n", "at": 7.0, "width": 1.6, "height": 2.3},
		{"wall": "e", "at": 0.0, "width": 1.6, "height": 2.5},
		{"wall": "w", "at": 0.0, "width": 1.6, "height": 2.3},
	])
	Greybox.label(geo, Vector3(-8, 2.5, -15.88), "VAULT A  -  SAMPLES", 24, Color(0.2, 0.3, 0.4), 0)
	Greybox.label(geo, Vector3(2, 2.5, -15.88), "VAULT B  -  RECORDS / FILM", 24, Color(0.2, 0.3, 0.4), 0)
	Greybox.label(geo, Vector3(10, 2.55, -15.88), WARM_UP_SIGN, 24, Color(0.85, 0.5, 0.2), 0).name = "WarmUpSign"
	Greybox.label(geo, Vector3(-13.88, 2.5, -14), "PLANT", 26, Color(0.2, 0.3, 0.4), 90)
	vault_c_door = add_door(data.doors.vault_c, VAULT_C_DOOR_AT, Vector3(0.12, 2.5, 1.6))
	# The sign over its door, with its id (V30, V27), and the sign beside it.
	var over := Document.place(geo, Vector3(19.88, 2.57, -14), -90, "Sign over Vault C's door", [VAULT_C_DOOR_SIGN % data.doors.vault_c], false, "laminated", Vector2(0.56, 0.1))
	over.name = "VaultCDoorSign"
	over.pieces = [{"case": "hold", "piece": "freezer_door", "text": data.doors.vault_c, "kind": "value"}]
	var sign := Document.place(geo, Vector3(19.88, 1.5, -12.6), 90, "Vault C sign", VAULT_C_SIGN, false, "laminated", Vector2(0.26, 0.2))
	sign.name = "VaultCSign"
	sign.spot = "vault_c_sign"
	_access_point(Vector3(10, 2.9, -12.2), 180)
	# Frost on the pipes along the ceiling.
	Greybox.box(geo, Vector3(3, 2.8, -15.6), Vector3(33, 0.12, 0.12), Color(0.9, 0.95, 1.0), "Pipe")


func _build_vaults(cold: Dictionary) -> void:
	for v in [["A", Vector3(-8, 0, -20)], ["B", Vector3(2, 0, -20)]]:
		Greybox.room(geo, v[1], Vector3(8, 3.0, 8), cold, [
			{"wall": "s", "at": 0.0, "width": 1.6, "height": 2.3},
		])
		# Its freezer door: heavy, on a hinge, swings shut on its own.
		var d := Door.create(self, "VAULT-" + v[0], v[1] + Vector3(0, 1.15, 4), Vector3(1.6, 2.3, 0.14), Color(0.8, 0.84, 0.86))
		d.make_hinged(Vector3(-0.8, 0, 0), 95.0)
		# Shelving rows.
		for x in [-2.8, 2.8]:
			Greybox.box(geo, v[1] + Vector3(x, 1.0, -0.5), Vector3(0.6, 2.0, 5.0), Color(0.7, 0.72, 0.74), "Shelf")
		Greybox.box(geo, v[1] + Vector3(0, 1.0, -3.4), Vector3(4.0, 2.0, 0.6), Color(0.7, 0.72, 0.74), "Shelf")
		_access_point(v[1] + Vector3(3.6, 2.7, 0), -90)
	# The deep freeze: frost thick on everything.
	Greybox.room(geo, Vector3(25, 0, -14), Vector3(10, 3.2, 12), {"floor": Color(0.7, 0.75, 0.8), "wall": Color(0.88, 0.92, 0.95)}, [
		{"wall": "w", "at": 0.0, "width": 1.6, "height": 2.5},
	])
	for z in [-10.0, -18.0]:
		Greybox.box(geo, Vector3(25, 1.0, z), Vector3(6.0, 2.0, 0.7), Color(0.75, 0.8, 0.84), "Shelf")
	Greybox.box(geo, Vector3(29.3, 1.0, -14), Vector3(0.7, 2.0, 6.0), Color(0.75, 0.8, 0.84), "Shelf")
	_access_point(Vector3(21, 2.9, -9.2), 180)
	# The inside release, by the door: broken since before most of them.
	var release := Interactable.create(self, Vector3(20.25, 1.1, -15.4), Vector3(0.12, 0.3, 0.12), "Pull the inside release", Color(0.6, 0.15, 0.1))
	release.name = "InsideRelease"
	release.local_only = true
	release.used.connect(func(_p): hud.notice(TEXT.inside_release, 3.0))


func _build_plant(colors: Dictionary) -> void:
	Greybox.room(geo, Vector3(-18, 0, -14), Vector3(8, 3.2, 8), {"floor": Color(0.3, 0.3, 0.3), "wall": colors.wall.darkened(0.25)}, [
		{"wall": "e", "at": 0.0, "width": 1.6, "height": 2.3},
	])
	# The compressors: why the vaults are cold, and why this room is warm.
	for z in [-16.0, -13.5, -11.0]:
		Greybox.box(geo, Vector3(-20.5, 0.8, z), Vector3(1.6, 1.6, 1.8), Color(0.45, 0.5, 0.45), "Compressor")
	Greybox.label(geo, Vector3(-21.88, 2.4, -14), "COMPRESSORS 1-3", 26, Color(0.8, 0.8, 0.75), 90)
	Hum.create(geo, AABB(Vector3(-22, 0, -18), Vector3(8, 3, 8)))


## The warm-up area (M6, V32): a recess off the corridor's north side, halfway down
## it, with a space heater like the time office's. Its own access point keeps a deck
## on the vault network (no jacks past the anteroom).
func _build_warm_up(colors: Dictionary) -> void:
	Greybox.room(geo, WARM_UP.get_center() * Vector3(1, 0, 1), Vector3(3, 3.0, 3), {"floor": Color(0.36, 0.32, 0.28), "wall": colors.wall}, [
		{"wall": "s", "at": 0.0, "width": 1.6, "height": 2.3},
	])
	Greybox.box(geo, Vector3(10.9, 0.25, -18.55), Vector3(0.5, 0.5, 0.3), Color(0.6, 0.3, 0.2), "Heater")
	Greybox.ceiling_light(geo, Vector3(10.9, 0.6, -18.1), 2.0, 0.3, Color(1.0, 0.45, 0.2))
	_access_point(Vector3(9.2, 2.9, -17.5), 0)


## A ceiling access point with its sticker: the vault network.
func _access_point(at: Vector3, facing: float) -> void:
	Greybox.box(geo, at, Vector3(0.3, 0.06, 0.3), Color(0.9, 0.9, 0.88), "AccessPoint")
	Greybox.ceiling_light(geo, at + Vector3(0, -0.06, 0), 0.6, 0.4, Color(0.3, 1.0, 0.4))


## The night-shifters from 9 waiting on the landing (call 5b), the six echoes at
## their rows, and (if it came down) the shape in the dock shaft.
func _place_people() -> void:
	for s in [["ines", "Oyelaran, Ines", "Ines", Vector3(-2.6, 0, 6.4)], ["tomas", "Lindqvist, Tomas", "Tomas", Vector3(-2.6, 0, 5.2)]]:
		var st := Staffer.new()
		st.name = "Staffer_" + s[2]
		st.staff_name = s[1]
		st.first_name = s[2]
		st.position = s[3]
		add_child(st)
		st.state = "waiting"
		st._crouch(false)
		staffers[s[0]] = st
	for i in data.echoes.size():
		var e: Dictionary = data.echoes[i]
		var row: Array = ROWS[e.row]
		var echo := Echo.make(self, e.id, e.first, row[0], row[1], float(i) * 1.37)
		echo.set_meta("row", e.row)
		echo.whispered.connect(_on_whisper)
		echoes[e.id] = echo


## Every row's label over its shelf, where someone standing at the row reads it.
func _label_rows() -> void:
	for id in ROWS:
		var row: Array = ROWS[id]
		var fwd := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(row[1]))
		Greybox.label(geo, row[0] + fwd * 0.55 + Vector3(0, 2.25, 0), "ROW " + id, 22, Color(0.9, 0.9, 0.85), row[1]).name = "RowLabel_" + id


func _make_decks() -> void:
	for i in 6:
		var d := Terminal.new()
		d.name = "Deck%d" % (i + 1)
		d.terminal_name = "PORTABLE DECK"
		d.db = db
		d.ui = terminal_ui
		d.api = _link("deck", i, "deck%d" % i)
		d.prompt = ""
		d.enabled = false
		d.boot_lines = ["HALCYON PORTABLE DECK  -  FIELD UNIT", "Network: follows you (jacks in the warm rooms, access points with a wireless card)."]
		d.puzzles = [hold_puzzle, release_puzzle, stop_puzzle]
		d.policy = true  # a B1 screen too (P1)
		d.set_meta("ticked_elsewhere", true)
		d.requested.connect(_on_request.bind("deck"))
		# Where its keys click and beep: in its holder's hands (it follows them).
		d.focus_point = Marker3D.new()
		d.focus_point.name = "FocusPoint"
		d.focus_point.position = Vector3(0, 1.1, -0.3)
		d.add_child(d.focus_point)
		d.stand_point = Marker3D.new()
		d.stand_point.name = "StandPoint"
		d.add_child(d.stand_point)
		add_child(d)
		decks.append(d)
		deck_net[i] = "none"


## The cradle card, with the dock cradle's key on it.
func _cradle_card() -> Array:
	var lines := CRADLE_CARD.duplicate(true)
	lines[1] = {"text": CRADLE_CARD[1].text % data.dock_key, "hand": false}
	return lines


func _tech_note() -> Array:
	var lines := TECH_NOTE.duplicate(true)
	lines[2] = {"text": TECH_NOTE[2].text % data.doors.ante, "hand": false}
	return lines


func _service_page() -> Array:
	return SERVICE_PAGE.duplicate(true)


## The rack's IN slots: the cards a player can see there (not what the log says).
func _rack_lines() -> Array:
	var lines: Array = ["CARDS IN"]
	for c in data.rack_in:
		lines.append({"text": "%s  %s" % [c.card, c.name], "hand": false})
	lines.append({"text": "(a card's wedged down the back. can't reach it.)", "hand": true})
	return lines


func net_setup() -> void:
	for k in staffers:
		sync.replicate(staffers[k], staffers[k].sync_properties())


func apply_environment(env: Environment) -> void:
	env.ambient_light_energy = 0.07
	env.fog_density = 0.045


func start() -> void:
	_started_msec = Time.get_ticks_msec()
	stair_in.locked = false  # the crew's all down: out of the stairwell, onto B1
	for term in [office, it_terminal, ante_terminal]:
		term.ensure_booted()
	_voice = Voice.new()
	_voice.name = "B1Voice"
	add_child(_voice)
	if completed.get_connections().is_empty():
		completed.connect(_on_completed)
	if player and not player.inventory.selected.is_connected(_on_selected):
		player.inventory.selected.connect(_on_selected)
	pair_puzzle.hints[2] = "type .script, then this, then ^R:\n    [color=#ffffff]%s[/color]" % _pair_script(data.key, str(_pair_count()))
	Game.cell_rule = _cell_counts  # this floor's slots, from here on
	_set_cases()
	if not Game.answer_found.is_connected(_on_answer_found):
		Game.answer_found.connect(_on_answer_found)
		Game.cell_missed.connect(_on_cell_missed)
		Game.line_noted.connect(_on_line_noted)
	hud.todo(TASK_TITLES.todo_arrive, TEXT.todo_arrive)
	_lines(["l6_arrive_pa", "l6_arrive_tease"], 0.8)
	# The landing's reader punches every visitor in to the floor: the crew's own cards
	# are in the log from the start, so the listing has ours to leave out (DRAFT).
	if _is_host():
		for i in _crew_count():
			sync.event("_punch_floor", ["VIS-%02d" % (i + 1)])
	_after_story(6.0, func():
		await _say("l6_ines_arrive")
		await _say("l6_tomas_arrive"))


## Runs `fn` after `seconds` of play, if the floor's still here.
func _after_story(seconds: float, fn: Callable) -> void:
	await get_tree().create_timer(seconds, false).timeout
	if is_inside_tree():
		fn.call()


## A line by id: Voice's recording and subtitle once VoiceLines has it, else the
## draft here as a subtitle (LINES).
func _say(id: String) -> void:
	if hud and not VoiceLines.get_line(id).is_empty():
		await hud.line(id)


## Lines in order, with a pause between (the PA, then his own voice).
func _lines(ids: Array, pause := 1.0) -> void:
	var first := true
	for id in ids:
		if not first:
			await get_tree().create_timer(pause, false).timeout
			if not is_inside_tree():
				return
		first = false
		await _say(id)


func floor_time() -> String:
	var elapsed := 0
	if _started_msec > 0:
		elapsed = int((Time.get_ticks_msec() - _started_msec) / 60000.0)
	var h := int(data.clock.left(2))
	var m := int(data.clock.right(2)) + elapsed
	return "1997-10-16 %02d:%02d" % [(h + m / 60) % 24, m % 60]


func _is_host() -> bool:
	return sync == null or sync.is_host()


## Host: `method` runs on every machine after `seconds` (a timer the services need).
func _later(seconds: float, method: String, args := []) -> void:
	if not _is_host() or not is_inside_tree():
		return
	await get_tree().create_timer(seconds, false).timeout
	if is_inside_tree():
		sync.event(method, args)


# --- The services ---------------------------------------------------------------------

## The floor's services behind one key (the IT tech's): the earpiece cradle, the
## doors, and the time clock. The dock cradle's key is real and opens only the dock's
## cradle (403 here). Handlers change only service state and the building's tables,
## the same on every machine; what that means for the floor plays out from there.
func _make_api() -> FacilityAPI:
	var a := FacilityAPI.new()
	a.add_key(data.key, ["it", "doors", "clock"], "IT tech")
	a.add_key(data.dock_key, ["dock"], "dock cradle")
	a.route("GET", "/earpieces", func(_p):
		return {"status": 200, "body": {"cradle": "IT-CAGE", "slots": CRADLE_SLOTS, "paired": paired, "busy": pair_busy}}, "it")
	a.route("POST", "/earpieces/pair", func(_p, req):
		return _pair(req), "it")
	a.route("GET", "/doors", func(_p):
		return {"status": 200, "body": {"doors": _b1_doors().map(_door_json)}}, "doors")
	a.route("GET", "/doors/:id", func(p):
		var row := _door_row(str(p[0]))
		if row.is_empty():
			return {"status": 404, "body": {"error": "No door %s on B1. GET /doors lists them." % p[0]}}
		return {"status": 200, "body": _door_json(row)}, "doors")
	a.route("PATCH", "/doors/:id", func(p, req):
		return _patch_door(str(p[0]).to_upper(), req), "doors")
	a.route("GET", "/clock", func(_p):
		return {"status": 200, "body": {"clock": "LONE WORKER B1", "printing": printing, "last_slip": last_slip, "slip_seconds": int(punch_interval)}}, "clock")
	a.route("GET", "/freezer_log", func(_p):
		return {"status": 200, "body": {"open": _open_entries()}}, "clock")
	a.route("GET", "/freezer_log/:id", func(p):
		var r := _entry(int(str(p[0])))
		if r.is_empty():
			return {"status": 404, "body": {"error": "No entry %s. GET /freezer_log lists the open ones." % p[0]}}
		return {"status": 200, "body": r}, "clock")
	a.route("POST", "/clock_outs", func(_p, req):
		return _clock_out(req), "clock")
	a.route("POST", "/clock_ins", func(_p, req):
		return _clock_in(req), "clock")
	return a


## POST /earpieces/pair: one set at a time; the cradle is busy while one pairs.
func _pair(req: Dictionary) -> Dictionary:
	pair_requests += 1
	var bad := FacilityAPI.check_fields(req.body, {})
	if bad != "":
		return {"status": 400, "body": {"error": bad + " The pair request's body is empty: {}"}}
	if pair_busy:
		pair_409s += 1
		return {"status": 409, "body": {"error": "Busy: still pairing the last set. Wait for it."}}
	if paired >= CRADLE_SLOTS:
		pair_409s += 1
		return {"status": 409, "body": {"error": "Every set in the cradle is paired already."}}
	paired += 1
	pair_busy = true
	_after_pair()
	return {"status": 201, "body": {"set": paired, "paired": paired, "of": CRADLE_SLOTS}}


func _after_pair() -> void:
	_check_pairing()
	_later(pair_time, "_pair_done")


## Every machine: the set in the cradle finished pairing.
func _pair_done() -> void:
	pair_busy = false


## The floor's doors in the doors table.
func _b1_doors() -> Array:
	return db.run_silent("SELECT id, name, locked FROM doors WHERE zone = 'B1' ORDER BY id")


func _door_row(id: String) -> Dictionary:
	var rows := db.run_silent("SELECT id, name, locked FROM doors WHERE zone = 'B1' AND UPPER(id) = '%s'" % id.to_upper().replace("'", ""))
	return rows[0] if not rows.is_empty() else {}


## A door as the service answers: whether it's locked, and what locks it.
func _door_json(row: Dictionary) -> Dictionary:
	var id := str(row.id)
	var out := {"id": id, "name": row.name, "locked": int(row.locked) == 1}
	if id == data.doors.vault_c:
		out["closes"] = "safety timer, %d s" % int(freezer_timer)
	elif id == data.doors.ante:
		out["closes"] = "Epsilon sweep"
	if guarded.has(id):
		out["relay_guard"] = "held shut"
	return out


## PATCH /doors/<id> {"locked": bool}. Unlocking an open door is a needless write:
## a few between sweeps and the relay guard holds it shut. The deep freeze's door
## won't unlatch while the clock thinks Vault C is empty.
func _patch_door(id: String, req: Dictionary) -> Dictionary:
	var row := _door_row(id)
	if row.is_empty():
		return {"status": 404, "body": {"error": "No door %s on B1. GET /doors lists them." % id}}
	id = str(row.id)
	var bad := FacilityAPI.check_fields(req.body, {"locked": TYPE_BOOL})
	if bad != "":
		return {"status": 400, "body": {"error": bad}}
	var lock: bool = req.body.locked
	var was_locked := int(row.locked) == 1
	if lock:
		if not was_locked:
			_set_locked(id, true)
		return {"status": 200, "body": _door_json(_door_row(id))}
	if guarded.has(id):
		return {"status": 409, "body": {"error": "Relay guard: too many writes. %s is held shut for %d s." % [id, int(guard_hold)]}}
	if id == data.doors.vault_c and unoccupied.has("C"):
		return {"status": 409, "body": {"error": "Vault C is empty by the clock: its door stays latched until someone is clocked in."}}
	if not was_locked:
		needless[id] = needless.get(id, 0) + 1
		if needless[id] >= GUARD_WRITES:
			_trip_guard(id)
			return {"status": 409, "body": {"error": "Relay guard: too many writes. %s is held shut for %d s." % [id, int(guard_hold)]}}
		return {"status": 200, "body": _door_json(row)}
	_set_locked(id, false)
	return {"status": 200, "body": _door_json(_door_row(id))}


## Every machine (a request or an event): a B1 door's lock changes in the doors table.
func _set_locked(id: String, lock: bool) -> void:
	db.run_silent("UPDATE doors SET locked = %d WHERE id = '%s'" % [1 if lock else 0, id])
	db.sync_world()
	if lock:
		if hud and is_inside_tree():
			hud.notice(TEXT.door_locks % _door_name(id), 2.5, ThemeUtil.AMBER, HUD.Turn.NORMAL)  # the vault's doors cycle: news, not spam
		return
	door_gen[id] = door_gen.get(id, 0) + 1
	if hud and is_inside_tree():
		hud.notice(TEXT.door_opens % _door_name(id), 2.5, ThemeUtil.AMBER, HUD.Turn.NORMAL)  # the vault's doors cycle: news, not spam
	if id == data.doors.ante:
		_on_ante_opened()
	if id == data.doors.vault_c:
		_on_vault_c_opened()
		_later(freezer_timer, "_latch", [id, door_gen[id]])


func _door_name(id: String) -> String:
	var row := _door_row(id)
	return str(row.get("name", id)).trim_prefix("Cold store B1, ")


func _door_locked(id: String) -> bool:
	var row := _door_row(id)
	return row.is_empty() or int(row.locked) == 1


func _trip_guard(id: String) -> void:
	guarded[id] = true
	needless[id] = 0
	if not _door_locked(id):
		db.run_silent("UPDATE doors SET locked = 1 WHERE id = '%s'" % id)
		db.sync_world()
	if hud and is_inside_tree():
		hud.notice(TEXT.guard % _door_name(id), 4.0, ThemeUtil.RED)
		if not tips_sent.has("guard_pa"):
			tips_sent["guard_pa"] = true
			_lines(["l6_guard_pa", "l6_guard_tease"])
	_tip_all("guard")
	_later(guard_hold, "_guard_off", [id])


## Every machine: the relay guard lets go.
func _guard_off(id: String) -> void:
	guarded.erase(id)
	if hud and is_inside_tree():
		hud.notice(TEXT.guard_off % _door_name(id), 3.0)


## Every machine: the deep freeze door's safety timer ran out for the opening `gen`.
func _latch(id: String, gen: int) -> void:
	if door_gen.get(id, 0) != gen or _door_locked(id):
		return
	db.run_silent("UPDATE doors SET locked = 1 WHERE id = '%s'" % id)
	db.sync_world()
	needless[id] = 0
	_locked_at[id] = _sweep_clock
	if hud and is_inside_tree():
		hud.notice(TEXT.latch, 2.5)


## Every machine: Epsilon's sweep re-locks B1's ordinary doors (the anteroom; the IT
## cage and the office stand open, propped, and the sweep can't move a propped door).
func _sweep() -> void:
	var id: String = data.doors.ante
	needless[id] = 0
	if not _held_this_sweep and _locked_at.has(id):
		held_sweeps = 0  # it stayed shut through the last one
	_held_this_sweep = false
	if not _door_locked(id):
		db.run_silent("UPDATE doors SET locked = 1 WHERE id = '%s'" % id)
		db.sync_world()
		_locked_at[id] = _sweep_clock
		if hud and is_inside_tree():
			hud.notice(TEXT.sweep, 2.0)


## Every machine: the anteroom door opened. Soon after the sweep locked it, that's a
## hold (the watchdog, or a quick hand); two sweeps in a row is the practice done.
## Decided on the host (its clock); the case moves on every machine.
func _on_ante_opened() -> void:
	var id: String = data.doors.ante
	if not _is_host():
		return
	if _locked_at.has(id) and _sweep_clock - float(_locked_at[id]) <= HOLD_WINDOW and not _held_this_sweep:
		_held_this_sweep = true
		held_sweeps += 1
		if held_sweeps >= HOLD_SWEEPS and not practice_puzzle.solved:
			sync.event("_on_solved", ["practice"])


## The deep freeze door opened again just after it latched: something's holding it.
func _on_vault_c_opened() -> void:
	if _is_host() and _locked_at.has(data.doors.vault_c) and _sweep_clock - float(_locked_at[data.doors.vault_c]) <= HOLD_WINDOW and not watchdog_used:
		sync.event("_watchdog_seen")


func _watchdog_seen() -> void:
	watchdog_used = true


# --- The time clock ---------------------------------------------------------------------

func _entry(id: int) -> Dictionary:
	var rows := db.run_silent("SELECT * FROM freezer_log WHERE id = %d" % id)
	return rows[0] if not rows.is_empty() else {}


func _open_entries() -> Array:
	return db.run_silent("SELECT * FROM freezer_log WHERE clock_out IS NULL ORDER BY id")


## POST /clock_outs {"entry": id}: the vault network only; one slip at a time.
func _clock_out(req: Dictionary) -> Dictionary:
	if net_now != "vault":
		return {"status": 403, "body": {"error": "Punches only go through on the vaults' own network. This one is wired."}}
	var bad := FacilityAPI.check_fields(req.body, {"entry": TYPE_INT})
	if bad != "":
		return {"status": 400, "body": {"error": bad}}
	var row := _entry(int(req.body.entry))
	if row.is_empty():
		return {"status": 404, "body": {"error": "No entry %d. The open ones: SELECT * FROM freezer_log WHERE clock_out IS NULL" % int(req.body.entry)}}
	if row.clock_out != null:
		return {"status": 409, "body": {"error": "Entry %d is already closed." % int(row.id)}}
	if printing:
		return {"status": 409, "body": {"error": "Still printing the last slip. Wait for it."}}
	var stamp := floor_time()
	db.run_silent("UPDATE freezer_log SET clock_out = '%s', note = 'closed by hand' WHERE id = %d" % [stamp, int(row.id)])
	printing = true
	last_slip = "Entry %d, %s, OUT %s" % [int(row.id), row.name, stamp]
	_slip_row = {"id": int(row.id), "card": row.card, "name": row.name, "clock_in": row.clock_in, "clock_out": stamp}
	_after_slip()
	_closed(row)
	return {"status": 201, "body": {"entry": int(row.id), "card": row.card, "name": row.name, "clock_out": stamp}}


func _after_slip() -> void:
	if hud and is_inside_tree():
		hud.notice(TEXT.slip, 2.0)
	_later(punch_interval, "_slip_done")


## Every machine: the slip's printed; the clock takes the next punch.
func _slip_done() -> void:
	printing = false
	if not _slip_row.is_empty():
		_lay_slip(_slip_row)
		_slip_row = {}


## The printed slip goes on the tray under the clock: who, in when, out when, and how
## long they were inside. The crew finds the pile on the way back through the office.
func _lay_slip(r: Dictionary) -> void:
	var n := find_children("Slip_*", "", false, false).size()
	var at := Vector3(-3.75 + 0.02 * (n % 3), 0.925 + 0.004 * n, -4.2 + 0.03 * (n % 4) - 0.04)
	var lines := ["LONE WORKER B1  -  %s" % TEXT.slip_out, "%s   %s" % [str(r.name).to_upper(), r.card],
		"IN   %s" % r.clock_in, "OUT  %s" % r.clock_out, "INSIDE: " + inside_for(str(r.clock_in), str(r.clock_out))]
	var doc := Document.place(self, at, -90, "Out slip: %s" % r.name, lines, true, "paper", Vector2(0.1, 0.16))
	doc.name = "Slip_%d" % int(r.id)
	if not str(r.name) == "VISITOR":
		doc.clues = [{"case": "release", "text": "%s's slip: in %s, out %s. %s." % [r.name, r.clock_in, r.clock_out, inside_for(str(r.clock_in), str(r.clock_out))]}]
	LevelSync.name_nodes(doc)


## How long between two of the clock's stamps ("YYYY-MM-DD HH:MM"), in words.
static func inside_for(from_stamp: String, to_stamp: String) -> String:
	var a := from_stamp.split(" ")
	var b := to_stamp.split(" ")
	if a.size() < 2 or b.size() < 2:
		return ""
	var ad := a[0].split("-")
	var bd := b[0].split("-")
	var at := a[1].split(":")
	var bt := b[1].split(":")
	var months := (int(bd[0]) - int(ad[0])) * 12 + int(bd[1]) - int(ad[1])
	if int(bd[2]) < int(ad[2]):
		months -= 1
	if months >= 12:
		return "%d years, %d months" % [months / 12, months % 12]
	if months >= 1:
		return "%d months" % months
	var mins := (int(bd[2]) - int(ad[2])) * 1440 + (int(bt[0]) - int(at[0])) * 60 + int(bt[1]) - int(at[1])
	if mins >= 1440:
		return "%d days" % (mins / 1440)
	return "%d h %02d min" % [mins / 60, mins % 60]


## POST /clock_ins {"card": "VIS-nn", "vault": "C"}: a visitor wrongly clocked out,
## back in. Only the crew's own cards, and only someone really in that vault.
func _clock_in(req: Dictionary) -> Dictionary:
	if net_now != "vault":
		return {"status": 403, "body": {"error": "Punches only go through on the vaults' own network. This one is wired."}}
	var bad := FacilityAPI.check_fields(req.body, {"card": TYPE_STRING, "vault": TYPE_STRING})
	if bad != "":
		return {"status": 400, "body": {"error": bad}}
	var card := str(req.body.card).to_upper()
	var vault := str(req.body.vault).to_upper().trim_prefix("VAULT ").strip_edges()
	if not card.begins_with("VIS-"):
		return {"status": 403, "body": {"error": "Staff cards punch in at the vault readers, not here."}}
	if not VAULT_ROOMS.has(vault):
		return {"status": 400, "body": {"error": "\"vault\" is A, B or C."}}
	if crew_in.get(card, "") != vault:
		return {"status": 409, "body": {"error": "The reader doesn't see %s in Vault %s." % [card, vault]}}
	if _open_crew_entry(card, vault) > 0:
		return {"status": 409, "body": {"error": "%s is already clocked in to Vault %s." % [card, vault]}}
	var id := _add_entry(card, vault)
	_occupancy(vault)
	return {"status": 201, "body": {"entry": id, "card": card, "vault": vault}}


func _add_entry(card: String, vault: String) -> int:
	_next_entry += 1
	db.run_silent("INSERT INTO freezer_log VALUES (%d, '%s', 'VISITOR', '%s', '%s', NULL, '')" % [_next_entry, card, vault, floor_time()])
	return _next_entry


func _open_crew_entry(card: String, vault: String) -> int:
	var rows := db.run_silent("SELECT id FROM freezer_log WHERE card = '%s' AND vault = '%s' AND clock_out IS NULL" % [card, vault])
	return int(rows[0].id) if not rows.is_empty() else 0


## Every machine: an entry was closed by hand. An echo's: they're released. One of the
## crew's: the clock thinks they've left, and if nobody else is clocked in there,
## the vault goes dark and cold, and the deep freeze latches (call 6).
func _closed(row: Dictionary) -> void:
	if str(row.name) == "VISITOR":
		_tip_all("visitor")
		_occupancy(str(row.vault))
		return
	for e in data.echoes:
		if e.card == row.card:
			_release(e.id)


## Every machine: whether the clock thinks a vault with the crew in it is empty.
func _occupancy(vault: String) -> void:
	if not Level6Data.VAULTS.has(vault):
		return  # the landing's entries: nothing hangs on them
	var inside := crew_in.keys().filter(func(c): return crew_in[c] == vault)
	var empty := not inside.is_empty() and inside.all(func(c): return _open_crew_entry(c, vault) == 0)
	var room: String = Level6Data.VAULTS[vault]
	if empty and not unoccupied.has(vault):
		unoccupied[vault] = true
		db.run_silent("UPDATE lights SET is_on = 0 WHERE id = 'LB1-%s'" % vault)
		db.sync_world()
		if vault == "C" and not _door_locked(data.doors.vault_c):
			db.run_silent("UPDATE doors SET locked = 1 WHERE id = '%s'" % data.doors.vault_c)
			db.sync_world()
		if hud and is_inside_tree():
			hud.notice(TEXT.unoccupied % room, 4.0, ThemeUtil.RED)
	elif not empty and unoccupied.has(vault):
		unoccupied.erase(vault)
		db.run_silent("UPDATE lights SET is_on = 1 WHERE id = 'LB1-%s'" % vault)
		db.sync_world()
		if hud and is_inside_tree():
			hud.notice(TEXT.occupied % room, 3.0)


## Host: a vault's reader saw a player go in or out. Their card punches.
func _on_reader(body: Node, vault: String, entering: bool) -> void:
	if not _is_host() or not body.is_in_group("player"):
		return
	var id := players.id_of(body) if players else 1
	if id <= 0:
		return
	sync.event("_punch", [_card_of(id), vault, entering])


func _card_of(peer_id: int) -> String:
	return "VIS-%02d" % (NetPlayers.index_of(peer_id, multiplayer) + 1)


## Every machine: a crew card punched at a vault's reader.
func _punch(card: String, vault: String, entering: bool) -> void:
	SfxTouch.reader(get_node_or_null("Reader_" + vault), true)
	if entering:
		crew_in[card] = vault
		if _open_crew_entry(card, vault) == 0:
			_add_entry(card, vault)
		if hud and is_inside_tree() and card == _card_of(multiplayer.get_unique_id()):
			hud.notice(TEXT.punch_in % card, 2.0)
	else:
		if crew_in.get(card, "") == vault:
			crew_in.erase(card)
		var open := _open_crew_entry(card, vault)
		if open > 0:
			db.run_silent("UPDATE freezer_log SET clock_out = '%s' WHERE id = %d" % [floor_time(), open])
	_occupancy(vault)


## Every machine: a crew card punched in at the landing's reader, on arrival. The
## entry is the floor's (vault B1): no lights or door hang on it.
func _punch_floor(card: String) -> void:
	if _open_crew_entry(card, "B1") == 0:
		_add_entry(card, "B1")
	if hud and is_inside_tree() and card == _card_of(multiplayer.get_unique_id()):
		hud.notice(TEXT.punch_floor % card, 2.0)


# --- The stations ----------------------------------------------------------------------

func _make_puzzles() -> void:
	var key: String = data.key
	# 1. Who's been in there longest? IS NULL was practised on 18: the review ladder.
	# Solved by pointing at the name (the slot, _set_cases), not by the query.
	open_puzzle = Puzzle.new("open", "SELECT name, clock_in FROM freezer_log WHERE clock_out IS NULL ORDER BY clock_in", ["name", "clock_in"], true, [
		"the shape, with the empty column left as enter_column:\n" +
		"    [color=#ffffff]SELECT name, clock_in FROM freezer_log WHERE enter_column IS NULL ORDER BY clock_in;[/color]\n" +
		"enter_column is the one a visit fills in on the way out. still inside = nothing in it. IS NULL asks for nothing; = NULL never matches. ORDER BY clock_in puts whoever went in first at the top.",
		"type this:\n" +
		"    [color=#ffffff]SELECT name, clock_in FROM freezer_log WHERE clock_out IS NULL ORDER BY clock_in;[/color]\n" +
		"the top name has been in there the longest. point at it and add it to your notebook.",
	])
	open_puzzle.case_id = "open"
	open_puzzle.spots = [{"id": "clock_sign", "text": SPOT_CLOCK}]
	# 2a. The try (M1): the editor, let, a request as a script line and the log, run
	# once for one set. Any set paired ticks it. Ladder A.
	try_puzzle = RequestPuzzle.new("try", _try_script(key), func(_l, _r): return paired >= 1, [
		"the shape, with the key left as enter_key:\n" +
		"    [color=#ffffff]%s[/color]\n" % _try_script("enter_key") +
		"  let key = ...   a variable: a box with a name, holding the key\n" +
		"  let res = await api.post(\"/earpieces/pair\", {}, {\"X-Api-Key\": key})   the same POST you'd type, as one script line: the path, then the body ({} is empty), then the header. await waits for the cradle's answer, and res holds it\n" +
		"  console.log(res.status)   writes the answer's code (201, 403, 409) in the runner's log, so you can see each try\n" +
		"enter_key is this cradle's own key, on the sticky on the bench.\n" +
		"type .script to open the runner, then ^S saves and ^R runs it.",
		"type .script, then this, then ^R:\n    [color=#ffffff]%s[/color]" % _try_script(key),
	], func(): return paired >= 1)
	try_puzzle.case_id = "pair"
	try_puzzle.spots = [{"id": "self_test", "text": SPOT_SELF_TEST}]
	# 2. One set each: let, while and waiting are new, so ladder A.
	var script := _pair_script(key, "enter_count")
	pair_puzzle = RequestPuzzle.new("pair", script, func(_l, _r): return _pair_ok(), [
		"the shape, with the key and the count left as enter_key and enter_count:\n" +
		"    [color=#ffffff]%s[/color]\n" % _pair_script("enter_key", "enter_count") +
		"  let key = ...   a variable: a box with a name, holding the key\n" +
		"  while (paired < count) { ... }   do what's in the braces again and again, while the test is true\n" +
		"  let res = await api.post(\"/earpieces/pair\", {}, {\"X-Api-Key\": key})   the same POST you'd type, as one script line: the path, then the body ({} is empty), then the header. await waits for the cradle's answer, and res holds it\n" +
		"  console.log(res.status)   writes the answer's code (201, 403, 409) in the runner's log, so you can see each try\n" +
		"  paired = paired + 1   count one more, or the test never turns false\n" +
		"  await sleep(1000)   wait a second (1000 ms) before the next\n" +
		"enter_key is this cradle's own key. enter_count is how many sets: one for each of you, and one each for Ines and Tomas.\n" +
		"type .script to open the runner, then ^S saves and ^R runs it.",
		"the card's script is for the dock cradle: its key is the dock's. this cradle's key is on the sticky on the bench. count is how many sets: one each.",
		"type .script, then this, then ^R:\n    [color=#ffffff]%s[/color]" % _pair_script(key, str(_pair_count())),
	], _pair_ok)
	pair_puzzle.case_id = "pair"
	pair_puzzle.spots = [{"id": "pairing_card", "text": SPOT_CARD}]
	# 2b. The listing, warm: for ... of and db.query are new, so ladder A. Checked by
	# what the log says (every open name, one a line), never by the code.
	list_puzzle = RequestPuzzle.new("list", _list_script("clock_out IS NULL"), func(_l, _r): return false, [
		"the shape, with the query's test left as enter_condition:\n" +
		"    [color=#ffffff]%s[/color]\n" % _list_script("enter_condition") +
		"  let open = await db.query(\"SELECT ...\")   runs a query from the script. await waits for its answer, and open holds the rows it found, one for each\n" +
		"  for (const entry of open) { ... }   once for each row in open, as entry. const is a box the loop fills fresh each time round\n" +
		"  entry.name   that row's name column\n" +
		"  if (entry.name !== \"VISITOR\") { ... }   only the rows that aren't ours. we punched in at the landing, on cards VIS-01 and up, name VISITOR. !== asks \"is it different?\"\n" +
		"  console.log(entry.name)   writes it in the runner's log: one line a name\n" +
		"enter_condition is the open visits, as at the time office. no key and no wait: this only reads. type .script to open the runner, then ^S saves and ^R runs it.",
		"the service page by the time clock has the loop. its query is vault A's: the open visits are every vault's, as at the time office. it was written before visitors had cards: an if around the log keeps ours out. log entry.name and nothing else; nothing gets written.",
		"type .script, then this, then ^R:\n    [color=#ffffff]%s[/color]" % _list_script("clock_out IS NULL"),
	], list_ok)
	list_puzzle.case_id = "list"
	list_puzzle.spots = [{"id": "service_page", "text": SPOT_PAGE_LIST}]
	# 3. The practice: the anteroom door held through two sweeps. if is new: ladder A.
	practice_puzzle = RequestPuzzle.new("practice", _watchdog(key, data.doors.ante), func(_l, _r): return practice_ok(), [
		"the shape, with the door left as enter_door:\n" +
		"    [color=#ffffff]%s[/color]\n" % _watchdog(key, "enter_door") +
		"  while (true) { ... }   keep going until someone presses Stop (^T)\n" +
		"  \"/doors/\" + door   + joins text: \"/doors/\" and what's in door make the path\n" +
		"  let res = await api.get(\"/doors/\" + door, {\"X-Api-Key\": key})   the same GET you'd type, as one script line: the path, then the header (a GET has no body). res holds the door's answer\n" +
		"  res.body.locked   the door's answer. body is the JSON you've seen on 9, and .locked is its locked field, true or false\n" +
		"  if (res.body.locked) { ... }   only when the GET says it's locked. a write to an open door counts against the relay guard\n" +
		"  await api.patch(\"/doors/\" + door, {\"locked\": false}, {\"X-Api-Key\": key})   the same PATCH you'd type: the path, the body and the header\n" +
		"  console.log(...)   a line in the runner's log, so you can see what it did\n" +
		"enter_door is the anteroom's door id. it's on its sign, and in GET /doors.",
		"the tech's note by this terminal is the whole watchdog. the door id is over the anteroom door.",
		"type .script, then this, then ^R:\n    [color=#ffffff]%s[/color]" % _watchdog(key, data.doors.ante),
	], practice_ok)
	practice_puzzle.case_id = "hold"
	practice_puzzle.spots = [{"id": "tech_note", "text": SPOT_NOTE}]
	# The pressure: the deep freeze's door, from the deck in the cold. if and the
	# loop are practised at the anteroom now: the review ladder.
	hold_puzzle = RequestPuzzle.new("hold", _watchdog(key, data.doors.vault_c), func(_l, _r): return crossed, [
		"the shape: the anteroom's watchdog, with the door left as enter_door:\n" +
		"    [color=#ffffff]%s[/color]\n" % _watchdog(key, "enter_door") +
		"enter_door is the deep freeze's id: on its sign, and in GET /doors. it latches on its own timer, so the watchdog has to keep up.",
		"on your deck: .script, then this, then ^R. then everyone in:\n    [color=#ffffff]%s[/color]" % _watchdog(key, data.doors.vault_c),
	], func(): return crossed)
	hold_puzzle.case_id = "hold"
	hold_puzzle.spots = [{"id": "vault_c_sign", "text": SPOT_VAULT_C}]
	# 4. The release, under pressure: ladder A, its loop line given.
	release_puzzle = RequestPuzzle.new("release", _release_script(key, "visitor", int(punch_interval) * 1000 + 1000), func(_l, _r): return all_free, [
		"the shape, with the blanks left as enter_ words:\n" +
		"    [color=#ffffff]%s[/color]\n" % _release_shape() +
		"  let open = await db.query(\"SELECT ...\")   runs a query from the script, and open holds the rows it found\n" +
		"  for (const entry of open) { ... }   once for each row the query found, as entry\n" +
		"  entry.id, entry.name   that row's id and name columns\n" +
		"  if (enter_check) { ... }   only the rows that aren't ours: ours say VISITOR in the name column. !== asks \"is it different?\"\n" +
		"  await sleep(enter_milliseconds)   GET /clock says slip_seconds. sleep counts in ms (1000 is one second), so wait a bit longer than slip_seconds x 1000\n" +
		"enter_key is the IT key, on the sticky on the bench, as before. enter_condition is the open visits, as at the time office. it has to run here, on the vaults' network: your deck, in Vault C.",
		"the service page by the time clock has most of it. it was written before visitors had cards: it closes everyone. the clock answers GET /clock with slip_seconds.",
		"on your deck, in Vault C: .script, then this, then ^R:\n    [color=#ffffff]%s[/color]" % _release_script(key, "visitor", int(punch_interval) * 1000 + 1000),
	], func(): return all_free)
	release_puzzle.case_id = "release"
	release_puzzle.spots = [{"id": "service_page", "text": SPOT_PAGE_RELEASE}]
	# 5. Stop what we started: stopping and PATCH are practised now, so the review ladder.
	stop_puzzle = RequestPuzzle.new("stop", "PATCH /doors/%s\nX-Api-Key: %s\n\n{\"locked\": true}" % [data.doors.vault_c, key], func(line: String, res: Dictionary):
		return res.status == 200 and _method_of(line) == "GET" and _path_of(line).begins_with("/doors") and stop_ok(), [
		"the shape: ^T in each runner that's still going, then for each door:\n" +
		"    [color=#ffffff]PATCH /doors/enter_door\nX-Api-Key: %s\n\n{\"locked\": true}[/color]\n" % key +
		"enter_door is each of the two doors you held open, the anteroom's and the deep freeze's. GET /doors lists them. then GET /doors reads them back.",
		"^T on every runner (the anteroom terminal's, every deck's), then type these, Enter twice after each:\n" +
		"    [color=#ffffff]PATCH /doors/%s\nX-Api-Key: %s\n\n{\"locked\": true}[/color]\n" % [data.doors.vault_c, key] +
		"    [color=#ffffff]PATCH /doors/%s\nX-Api-Key: %s\n\n{\"locked\": true}[/color]\n" % [data.doors.ante, key] +
		"    [color=#ffffff]GET /doors\nX-Api-Key: %s[/color]" % key,
	])
	stop_puzzle.case_id = "stop"


## The pairing script, as the card has it, with this cradle's key and the count.
static func _pair_script(key: String, count: String) -> String:
	return "let key = \"%s\";\nlet count = %s;\nlet paired = 0;\nwhile (paired < count) {\n  let res = await api.post(\"/earpieces/pair\", {}, {\"X-Api-Key\": key});\n  console.log(res.status);\n  paired = paired + 1;\n  await sleep(1000);\n}" % [key, count]


## The try (M1): one set, as the cradle's self-test label has it, with `key`.
static func _try_script(key: String) -> String:
	return "let key = \"%s\";\nlet res = await api.post(\"/earpieces/pair\", {}, {\"X-Api-Key\": key});\nconsole.log(res.status);" % key


## The listing: the page's loop with only a log in it, and an if that leaves the
## crew's own entries out (DRAFT: !== practised warm). `cond` is the query's test.
static func _list_script(cond: String) -> String:
	return "let open = await db.query(\"SELECT * FROM freezer_log WHERE %s\");\nfor (const entry of open) {\n  if (entry.name !== \"VISITOR\") {\n    console.log(entry.name);\n  }\n}" % cond


static func _watchdog(key: String, door: String) -> String:
	return "let key = \"%s\";\nlet door = \"%s\";\nwhile (true) {\n  let res = await api.get(\"/doors/\" + door, {\"X-Api-Key\": key});\n  if (res.body.locked) {\n    await api.patch(\"/doors/\" + door, {\"locked\": false}, {\"X-Api-Key\": key});\n    console.log(door + \" opened\");\n  }\n  await sleep(1000);\n}" % [key, door]


## The release script. `check` is the if's test; the loop line is given.
static func _release_script(key: String, check: String, ms: int) -> String:
	if check == "visitor":
		check = "entry.name !== \"VISITOR\""
	return "let key = \"%s\";\nlet open = await db.query(\"SELECT * FROM freezer_log WHERE clock_out IS NULL\");\nfor (const entry of open) {\n  if (%s) {\n    let res = await api.post(\"/clock_outs\", {\"entry\": entry.id}, {\"X-Api-Key\": key});\n    console.log(entry.name + \": \" + res.status);\n    await sleep(%d);\n  }\n}" % [key, check, ms]


static func _release_shape() -> String:
	return "let key = \"enter_key\";\nlet open = await db.query(\"SELECT * FROM freezer_log WHERE enter_condition\");\nfor (const entry of open) {\n  if (enter_check) {\n    let res = await api.post(\"/clock_outs\", {\"entry\": entry.id}, {\"X-Api-Key\": key});\n    console.log(entry.name + \": \" + res.status);\n    await sleep(enter_milliseconds);\n  }\n}"


## How many of the crew there are (tests can say).
var crew_size := 0


func _crew_count() -> int:
	if crew_size > 0:
		return crew_size
	return players.count() if players else 1


## How many sets: one for each of the crew, and one each for Ines and Tomas (M2).
func _pair_count() -> int:
	return _crew_count() + 2


func _pair_ok() -> bool:
	return paired >= _pair_count()


## The names on the entries still open (the echoes', never the crew's VISITOR).
func _open_names() -> Array:
	return db.run_silent("SELECT name FROM freezer_log WHERE clock_out IS NULL AND name != 'VISITOR'").map(func(r): return str(r.name))


## Every open name logged, one a line, by one run of a script.
func list_ok() -> bool:
	var names := _open_names()
	return not names.is_empty() and not listed_ours and names.all(func(n): return listed.has(n))


func practice_ok() -> bool:
	return held_sweeps >= HOLD_SWEEPS


## Every watchdog stopped, both vault doors locked, and nothing else holding them.
func stop_ok() -> bool:
	return all_free and not _scripts_running() and _door_locked(data.doors.vault_c) and _door_locked(data.doors.ante)


## Any script still running on B1: a terminal's or a deck's.
func _scripts_running() -> bool:
	for t in _script_terminals():
		var rt = t.get_meta("script_runtime") if t.has_meta("script_runtime") else null
		if rt and rt.is_running():
			return true
	return false


func _script_terminals() -> Array:
	var out: Array = [it_terminal, ante_terminal]
	out.append_array(decks)
	return out


func _method_of(line: String) -> String:
	return line.strip_edges().get_slice(" ", 0).to_upper()


func _path_of(line: String) -> String:
	return line.strip_edges().get_slice("\n", 0).get_slice(" ", 1).to_lower()


func puzzles() -> Array:
	return [open_puzzle, try_puzzle, pair_puzzle, list_puzzle, practice_puzzle, hold_puzzle, release_puzzle, stop_puzzle]


## Host: a SQL read at the time office.
func _on_query(sql: String, result: Dictionary, _ui: TerminalUI, which: String) -> void:
	var upper := sql.to_upper()
	if upper.contains("FREEZER_LOG"):
		if RegEx.create_from_string("=\\s*NULL").search(upper) != null:
			sync.event("_tip", ["eq_null", which])
		elif upper.contains("IS NOT NULL"):
			sync.event("_tip", ["not_null", which])
	# No paper needed: the first query here opens the case, so the click has a slot.
	if not Game.case_info("open").get("open", false):
		sync.event("_ask", ["open"])


## Host: a request typed at a terminal or deck. Its station checks; the services did
## the rest already, on every machine, and SYSOP answered from _on_sent.
func _on_request(line: String, res: Dictionary, _ui: TerminalUI, _which: String) -> void:
	if not stop_puzzle.solved and stop_puzzle.request_matches(line, res):
		sync.event("_on_solved", ["stop"])


## Host: any request the floor's services answered, typed or from a script, from the
## screen `link.terminal`. The mistakes SYSOP has a line for, answered there.
func _on_sent(link: NetLink, method: String, path: String, res: Dictionary) -> void:
	if not _is_host():
		return
	var which: String = link.terminal
	method = method.to_upper()
	var status := int(res.get("status", 0))
	var error := str(res.get("body", {}).get("error", "")) if res.get("body") is Dictionary else ""
	if method == "POST" and path.begins_with("/earpieces/pair"):
		_pair_from = which
		if status == 403:
			sync.event("_tip", ["pair_key", which])
		elif status == 409 and error.begins_with("Busy"):
			_pair_409_run = true
			sync.event("_tip", ["pair_busy", which])
		if pair_puzzle.solved:
			_pair_extra += 1
			if _pair_extra >= 3:
				sync.event("_tip", ["pair_endless", which])
	elif path.begins_with("/clock_"):
		if status == 403:
			sync.event("_tip", ["wired", which])
		elif status == 409 and path.begins_with("/clock_outs") and printing:
			sync.event("_tip", ["printing", which])
	elif method == "GET" and path.to_upper() == ("/doors/" + str(data.doors.ante)).to_upper() and which.begins_with("deck"):
		if practice_puzzle.solved and not crossed:
			sync.event("_tip", ["same_door", which, [data.doors.ante, data.doors.vault_c]])


## Every machine: a SYSOP tip on the screen it was earned at (once per run). `args`
## fill the line's blanks.
func _tip(id: String, which: String, args := []) -> void:
	if tips_sent.has(id):
		return
	tips_sent[id] = true
	var term := _terminal(which)
	if term and TEXT.has("tip_" + id):
		var text: String = TEXT["tip_" + id]
		if not args.is_empty():
			text = text % args
		term.print_line(TerminalUI.sysop(text), "hint")


## A tip that comes from the services (scripts too): shown on every script screen.
func _tip_all(id: String) -> void:
	if tips_sent.has(id) or not TEXT.has("tip_" + id):
		return
	tips_sent[id] = true
	for t in [it_terminal, ante_terminal]:
		if t:
			t.print_line(TerminalUI.sysop(TEXT["tip_" + id]), "hint")


func _terminal(which: String) -> Terminal:
	match which:
		"office": return office
		"it": return it_terminal
		"ante": return ante_terminal
	if which.begins_with("deck") and which.length() > 4:
		var i := int(which.trim_prefix("deck"))
		if i >= 0 and i < decks.size():
			return decks[i]
	return ante_terminal


## Every machine: the cradle has paired a set. The first is the try (step 1); one
## each, Ines and Tomas too, and the case is done.
func _check_pairing() -> void:
	if not try_puzzle.solved and paired >= 1:
		_try_run = true
		_on_solved("try")
	if not pair_puzzle.solved and _pair_ok():
		_on_solved("pair")


## Every machine: a station passed.
func _on_solved(id: String) -> void:
	for p in puzzles():
		if p.id == id:
			if p.solved:
				return
			p.solved = true
	match id:
		"open":
			_open_case("open")
			var open := db.run_silent("SELECT clock_in FROM freezer_log WHERE clock_out IS NULL AND name != 'VISITOR' ORDER BY clock_in")
			var oldest := int(str(open[0].clock_in).left(4)) if not open.is_empty() else 0
			_solve("open", TEXT.open_done % [open.size(), oldest, data.rack_in.size()])
			_lines(["l6_records_pa", "l6_records_tease"])
			_next_case()
		"try":
			# Step 2, the loop, with its chapter (M1, M3).
			_open_case("pair")
			Game.tick_step("pair", "try")
			_set_cases()
			_gate(CHAPTER_OF.loop)
		"pair":
			_open_case("pair")
			_solve("pair", TEXT.pair_done % paired)
			_earpieces_in()
			# The listing waits for the voice in the ear (M4).
			if _is_host():
				_later(listing_after, "_next_case")
		"list":
			_open_case("list")
			_solve("list", TEXT.list_done % ", ".join(PackedStringArray(_open_names())))
			_next_case()
		"practice":
			_open_case("hold")
			_set_cases()  # the deep freeze: the bare shape, under pressure
			_gate()
		"hold":
			_open_case("hold")
			_solve("hold", TEXT.hold_done if watchdog_used else TEXT.hold_done_hand)
			_next_case()
		"release":
			_open_case("release")
			var names := PackedStringArray(data.echoes.map(func(e): return e.first))
			_solve("release", TEXT.release_done % ", ".join(names))
			_next_case()
		"stop":
			_open_case("stop")
			_solve("stop", TEXT.stop_done)
			_lines(["l6_stopped_pa", "l6_stopped_tease"])
			sync.unlock("achievement:b1_left_tidy")


## Every machine: case `id` opens (once), with its chapter if it has one, and the
## crew's next waiting chapter lands (a gate: M3).
func _open_case(id: String) -> void:
	if Game.open_case(id, CASES[id], ["freezer_log"] if id == "open" else [], CASE_DO[id]):
		_gate(CHAPTER_OF.get(id, ""))
		if id == "list":
			_tip("list_try", "it")  # SYSOP's warm try, with its if, on the cage's screen (M4)


## Every machine: case `id` is solved, with what was found; a gate too.
func _solve(id: String, how: String) -> void:
	if Game.case_info(id).get("solved", false):
		return
	Game.solve_case(id, how)
	_gate()


## One case at a time, in order (the case board): the next one opens when the last
## is done. Case 5 is optional, and opens back in the warm once everyone's free (M5).
func _next_case() -> void:
	for id in CASE_ORDER:
		if not Game.case_info(id).get("solved", false):
			_open_case(id)
			return
	if all_free and not stop_puzzle.solved:
		stop_waiting = true


## Every machine: someone in the crew is back in the warm with every entry closed.
## Leaving it tidy opens (M5).
func _open_stop() -> void:
	if not stop_waiting:
		return
	stop_waiting = false
	_open_case("stop")


## Host, each frame while the tidy-up waits: the first of the crew in a warm room.
func _stop_check() -> void:
	for id in (players.all_ids() if players else [1]):
		var body: Node3D = player if (players == null or id == players.id_of(player)) else players.puppet(id)
		if body and WARM_ROOMS.any(func(r): return r.has_point(to_local(body.global_position))):
			sync.event("_open_stop")
			return


## Every machine: a paper opened a case. Only in order: case 2 waits for case 1.
func _ask(id: String) -> void:
	var at := CASE_ORDER.find(id)
	for i in at:
		if not Game.case_info(CASE_ORDER[i]).get("solved", false):
			return
	_open_case(id)


## Every machine: each case's pieces, its steps and its query on screen, as it
## stands now (the case chip shows the selected one's). The open case's slot is the
## name of whoever's been in there longest.
func _set_cases() -> void:
	var key := _piece(KEY_PIECE, data.key)
	Game.set_pieces("open", [TABLE_PIECE, COLUMN_PIECE], OPEN_QUERY)
	if Game.case_info("open").get("blank", {}).is_empty():
		var first: Dictionary = data.echoes[0]  # sorted by clock_in: in there longest
		Game.set_blank("open", OPEN_SLOT, NO_LINE, str(first.name), {"column": "name", "values": [str(first.name)], "rows": [{"card": str(first.card)}]})
	Game.set_pieces("pair", [key], _pair_script("{key}", "enter_count") if try_puzzle.solved else TRY_QUERY, PAIR_STEPS)
	Game.set_pieces("list", [], _list_script("enter_condition"))
	if practice_puzzle.solved:
		# The deep freeze, under pressure: the bare shape, never filled in.
		Game.set_pieces("hold", [key, _piece(FREEZER_PIECE, data.doors.vault_c)], _watchdog("{key}", "{freezer_door}"))
		Game.set_assemble("hold", false)
	else:
		Game.set_pieces("hold", [key, _piece(ANTE_PIECE, data.doors.ante)], _watchdog("{key}", "{ante_door}"))
	Game.set_pieces("release", [key], _release_shape().replace("enter_key", "{key}"))
	Game.set_assemble("release", false)
	Game.set_pieces("stop", [key], "PATCH /doors/enter_door\nX-Api-Key: {key}\n\n{\"locked\": true}\n\nGET /doors\nX-Api-Key: {key}", [], true)


static func _piece(def: Dictionary, value: String) -> Dictionary:
	var p := def.duplicate()
	p["value"] = value
	return p


# --- Pointing at the answer ------------------------------------------------------------------

## Game.cell_rule: B1's one slot is the open case's, and its own rule (set_blank's)
## says it all. Set here so an earlier floor's rule doesn't judge it.
func _cell_counts(_case_id: String, _f: Dictionary) -> bool:
	return true


## This player's click filled a slot: the host hears whose it was.
func _on_answer_found(id: String) -> void:
	if id == "open":
		sync.report_answer(id)


## Host: a player put the open case's answer in its slot.
func case_answered(answer: String, _peer: int) -> void:
	if answer == "open" and not open_puzzle.solved:
		sync.event("_on_solved", ["open"])


## The freezer_log entry a result row shows, as far as it shows one: by its id, its
## card, or its name and clock_in (a staff name can be on many visits). {} if none.
func _log_row(row: Dictionary) -> Dictionary:
	var shown := {}
	for k in row:
		shown[str(k).to_lower()] = row[k]
	var where := ""
	if shown.has("id") and str(shown.id).is_valid_int():
		where = "id = %d" % int(str(shown.id))
	elif shown.has("card") and shown.card != null:
		where = "card = '%s'" % str(shown.card).replace("'", "''")
	elif shown.has("name") and shown.has("clock_in") and shown.name != null and shown.clock_in != null:
		where = "name = '%s' AND clock_in = '%s'" % [str(shown.name).replace("'", "''"), str(shown.clock_in).replace("'", "''")]
	if where == "":
		return {}
	var rows := db.run_silent("SELECT * FROM freezer_log WHERE " + where)
	return rows[0] if rows.size() == 1 else {}


## This player pointed at a cell that isn't who's been in there longest: a pencil
## line under the blank says why (V7-V11; this player's notebook only).
func _on_cell_missed(column: String, value: String, row: Dictionary) -> void:
	var c: Dictionary = Game.case_info("open")
	if not c.get("open", false) or c.get("solved", false):
		return
	var col := column.to_lower()
	var shown := {}
	for k in row:
		shown[str(k).to_lower()] = row[k]
	if not shown.has(col):
		shown[col] = value
	var log_cols := ["card", "name", "vault", "clock_in", "clock_out"]
	if not log_cols.any(func(k): return shown.has(k)) and Game.case_selected() != "open":
		return  # nothing to do with the log, and another case in hand
	var first: Dictionary = data.echoes[0]
	var entry := _log_row(shown)
	var who := str(shown.get("name", entry.get("name", "")))
	var note := OPEN_MISS
	if who == "VISITOR":
		note = OPEN_OURS
	elif not entry.is_empty() and str(entry.card) == str(first.card):
		note = OPEN_ROW
	elif col == "name":
		var visits := db.run_silent("SELECT clock_out FROM freezer_log WHERE name = '%s'" % who.replace("'", "''"))
		if not entry.is_empty():
			visits = [entry]
		if not visits.is_empty() and visits.all(func(r): return r.clock_out != null):
			note = OPEN_CLOSED
		elif not visits.is_empty() and visits.any(func(r): return r.clock_out == null):
			note = OPEN_NOT_FIRST
	Game.blank_miss("open", note)


## This player noted a line off a paper: one of the card rack's, for the open case's
## blank, isn't the record (V6).
func _on_line_noted(text: String, kind: String) -> void:
	var c: Dictionary = Game.case_info("open")
	if kind != "document" or not c.get("open", false) or c.get("solved", false) or rack == null:
		return
	if rack.doc_lines.any(func(l): return str(l.text).strip_edges() == text.strip_edges() and str(l.text).begins_with("C-")):
		Game.blank_miss("open", OPEN_RACK)


func _rack_read() -> void:
	_ask("open")
	if not tips_sent.has("ines_whitlow"):
		tips_sent["ines_whitlow"] = true
		await _say("l6_ines_whitlow")
		_say("l6_tomas_whitlow")


# --- The listing (every script runner is listened to) --------------------------------------

## Every frame: a runner that appeared (opened for the first time, or adopted online)
## is listened to for what its script logs.
func _watch_scripts() -> void:
	for t in _script_terminals():
		var rt = t.get_meta("script_runtime") if t and t.has_meta("script_runtime") else null
		if rt == null or _watched.has(rt):
			continue
		_watched[rt] = true
		rt.printed.connect(_on_script_printed)
		rt.finished.connect(func(ok, _err): _on_script_finished(t, ok))


## Host: a script logged a line. One open name on it counts; a whole row's worth of
## them on one line doesn't (that isn't a name a line); VISITOR is one of ours.
func _on_script_printed(text: String, kind: String) -> void:
	if not _is_host() or list_puzzle == null or list_puzzle.solved or kind != "log":
		return
	var names := _open_names()
	var on_line: Array = names.filter(func(n): return text.contains(n))
	if on_line.size() == 1:
		listed[on_line[0]] = true
	elif on_line.size() > 1:
		sync.event("_tip", ["list_row", "it"])
	elif text.contains("VISITOR"):
		listed_ours = true


## Host: a script on `term` ended (`ok`: on its own, not stopped or failed). The
## listing is judged by the whole run: every open name, one a line, and none of
## ours; some names but not all is the page's own query (vault A's). The cradle's:
## too few sets, when the script that asked for them is done.
func _on_script_finished(term: Node, ok: bool) -> void:
	if not _is_host():
		return
	if list_puzzle and not list_puzzle.solved and not listed.is_empty():
		var n := _open_names().size()
		if list_ok():
			sync.event("_on_solved", ["list"])
		elif listed_ours:
			sync.event("_tip", ["list_ours", "it"])
		elif listed.size() < n:
			sync.event("_tip", ["list_vault", "it", [listed.size(), n]])
	listed.clear()
	listed_ours = false
	var which := _which_of(term)
	# The run that paired the first set was the try: it's step 1 done, not short (M1).
	if ok and which == _pair_from and not _pair_409_run and not _try_run and not pair_puzzle.solved and paired > 0 and paired < _pair_count():
		sync.event("_tip", ["pair_short", which, [paired, _pair_count()]])
	if which == _pair_from:
		_pair_409_run = false
		_try_run = false


## The screen name of a terminal or deck (what its link says).
func _which_of(term: Node) -> String:
	if term and term.get("api") is NetLink:
		return term.api.terminal
	return "ante"


# --- Earpieces and the walkie -----------------------------------------------------------

## Every machine: one set each is paired. The walkie's static, and whatever's under
## it, is gone; the crew talks in their ears.
func _earpieces_in() -> void:
	if earpieces:
		return
	earpieces = true
	get_node("/root/Game").set_meta("earpieces", true)
	if hud and is_inside_tree():
		hud.notice(TEXT.earpieces_in, 4.0)
		_after_story(2.5, func():
			hud.notice(TEXT.earpieces_voice, 3.0)
			var lines: Array = ECHO_LINES.get(Level6Data.ALWAYS, [])
			if not lines.is_empty():
				hud.say("A VOICE", str(lines[0]), 5.0))


# --- The decks --------------------------------------------------------------------------

## Every machine: someone used the bench. Their deck gets the wireless card and the
## script runner; anyone who came down without a deck (a floor picked from the
## Levels screen, say) takes a loaner, fitted already. Inventories are each
## machine's own, so only the user's machine adds the deck.
func _bench_used(peer_id: int) -> void:
	var me := players.id_of(player) if players else 1
	fitted[peer_id] = true
	var i := NetPlayers.index_of(peer_id, multiplayer)
	if i >= 0 and i < decks.size():
		decks[i].set_meta("scripts", true)
	if peer_id == me and player:
		if player.inventory.add("deck"):
			hud.notice(TEXT.deck_taken, 4.0)
		hud.notice(TEXT.deck_fitted, 4.0)


## This machine's player took something out of their hotbar: the deck opens.
func _on_selected(item: String) -> void:
	if item != "deck" or not active or terminal_ui.visible:
		return
	open_deck()


## Opens this machine's player's deck, on whatever network it can reach from here.
func open_deck() -> void:
	var i := players.my_index() if players else 0
	if i < 0 or i >= decks.size():
		return
	terminal_ui.open(decks[i], player)


## Host, each frame: which network each player's deck can reach where they stand.
func _deck_nets() -> void:
	for id in (players.all_ids() if players else [1]):
		var i := NetPlayers.index_of(id, multiplayer)
		if i < 0 or i >= decks.size():
			continue
		var body: Node3D = player if (players == null or id == players.id_of(player)) else players.puppet(id)
		var net := "none"
		if body:
			var p := to_local(body.global_position)
			if fitted.has(id) and AP_ROOMS.any(func(r): return r.has_point(p)):
				net = "vault"
			elif WARM_ROOMS.any(func(r): return r.has_point(p)):
				net = "wired"
		if deck_net.get(i, "none") != net:
			sync.event("_set_deck_net", [i, net])


## Each deck goes where its holder is (every machine moves its copies).
func _follow_decks() -> void:
	if players == null:
		if player and not decks.is_empty():
			decks[0].global_position = player.global_position
		return
	for id in players.all_ids():
		var i := NetPlayers.index_of(id, multiplayer)
		var body: Node3D = player if id == players.id_of(player) else players.puppet(id)
		if body and i >= 0 and i < decks.size():
			decks[i].global_position = body.global_position


## Every machine: a deck moved onto another network.
func _set_deck_net(i: int, net: String) -> void:
	deck_net[i] = net


# --- The echoes ---------------------------------------------------------------------------

## This machine's player came close to an echo: its whisper, quietly.
func _on_whisper(e: Echo) -> void:
	var lines: Array = ECHO_LINES.get(e.echo_id, [])
	if lines.is_empty() or not hud:
		return
	var id := "l6_echo_%s_loop" % e.echo_id
	if VoiceLines.ids_in_scene("l6_echoes").has(id):
		hud.line(id)
	else:
		hud.say(e.echo_name.to_upper(), lines[0], -1.0, HUD.Turn.CAN_WAIT)


## Every machine: an echo's entry is closed. Their story plays while the slip prints;
## then they go, and leave what they kept on the shelf.
func _release(id: String) -> void:
	if released_echoes.has(id):
		return
	released_echoes[id] = true
	var e: Echo = echoes.get(id)
	if e:
		e.begin_release()
	if is_inside_tree():
		_tell(id)
	if released_echoes.size() >= data.echoes.size() and not all_free:
		all_free = true
		_on_all_free()


func _tell(id: String) -> void:
	var lines: Array = ECHO_LINES.get(id, [])
	var echo: Dictionary = Level6Data.echo(data, id)
	var who: String = str(echo.get("first", id)).to_upper()
	for n in [1, 2]:
		var vid := "l6_echo_%s_%s" % [id, "story" if n == 1 else "free"]
		if VoiceLines.ids_in_scene("l6_echoes").has(vid):
			await hud.line(vid)
		elif n < lines.size():
			await hud.say(who, lines[n])
		if not is_inside_tree():
			return
	var e: Echo = echoes.get(id)
	if e:
		e.set_free()
	_leave(id)
	hud.notice(TEXT.released % echo.get("first", id), 4.0)


## What an echo leaves at their row: a paper to pick up (a memory, or evidence).
func _leave(id: String) -> void:
	var echo: Dictionary = Level6Data.echo(data, id)
	var leaves: Dictionary = ECHO_LEAVES.get(id, {})
	if echo.is_empty() or leaves.is_empty():
		return
	var row: Array = ROWS[echo.row]
	var at: Vector3 = row[0] + Vector3(0, 1.02, 0)
	var doc := Document.place(self, at, row[1], leaves.title, leaves.lines, true, "paper", Vector2(0.15, 0.12))
	doc.name = "Left_" + id
	doc.clues = [{"case": "release", "text": "%s left this at %s: %s" % [echo.first, echo.row, leaves.title]}]
	LevelSync.name_nodes(doc)


## Every machine: the last entry is closed. STAIR 2's gate opens.
func _on_all_free() -> void:
	_on_solved("release")
	_lines(["l6_free_pa", "l6_free_tease"], 1.0)
	if not stairs_open:
		stairs_open = true
		stair_gate.set_open(true)
		if hud and is_inside_tree():
			hud.notice(TEXT.stairs_release, 4.0)
			hud.todo(TASK_TITLES.todo_down, TEXT.todo_down)
		# In the World, B2 builds now at the foot of STAIR 2, and the crew walks down
		# to it; on its own the floor ends on the stairs.
		prepare_next()
		var next: Node = world.wings.get("level_7") if world else null
		if next:
			exit_trigger.monitoring = false
			walk_stairs(stair_in, next.stair_in, true, "_down_to_b2", TEXT.stairs_wait)
	if all_free and _scripts_running():
		_tip_all("lockup")
	# Back on the landing, the night-shifters have a question.
	var t := Trigger.create(self, LANDING.get_center(), LANDING.size)
	t.name = "LandingAfter"
	t.entered.connect(func(_b): sync.event("_landing_after"), CONNECT_ONE_SHOT)


## Every machine: the first of the crew is back on the landing with every entry closed.
func _landing_after() -> void:
	if landing_said:
		return
	landing_said = true
	await _say("l6_ines_after")
	await _say("l6_tomas_after")


## Every machine: everyone's across into the deep freeze.
func _crossed() -> void:
	if crossed:
		return
	crossed = true
	_on_solved("hold")


# --- The book --------------------------------------------------------------------------------

## Every machine: somebody took the book from under the mug.
func _book_found(peer_id: int) -> void:
	if book_found:
		return
	book_found = true
	book.enabled = false
	book.visible = false
	if players and peer_id == players.id_of(player):
		hud.notice(TEXT.book_taken, 5.0)
	sync.unlock_for([peer_id], "achievement:journey_js_pickup")
	for id in ["l6_book_find", "l6_book_open"]:
		if not VoiceLines.get_line(id).is_empty():
			await hud.line(id)
	_gate()  # the earliest chapter waiting; the rest one per step after (M3)


## Every machine: a gate (a case or a step opening, a case solved). Its own chapter,
## if it has one, joins the wait; once the book is found, the earliest one waiting
## lands, quietly: the book's notice only (nothing stops, nothing is spoken on B1).
## One per gate.
func _gate(chapter := "") -> void:
	var huddle := Huddle.of(self)
	if huddle == null:
		return
	if chapter != "" and not huddle.done.has(chapter) and not pending_chapters.has(chapter) and not Books.chapter(chapter).is_empty():
		pending_chapters.append(chapter)
	if not book_found:
		return
	while not pending_chapters.is_empty() and huddle.done.has(pending_chapters[0]):
		pending_chapters.pop_front()
	if not pending_chapters.is_empty():
		_book_huddle(pending_chapters.pop_front())


## Every machine: chapter `id` of Journey through JavaScript lands in the crew's book.
func _book_huddle(id: String) -> void:
	if Huddle.of(self) == null or Huddle.of(self).done.has(id) or Books.chapter(id).is_empty():
		return
	await Huddle.of(self).run(id, Huddle.REMEMBERED)


# --- Every frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not active:
		return
	_sweep_clock += delta
	if _is_host():
		_since_sweep += delta
		if _since_sweep >= sweep_every:
			_since_sweep = 0.0
			sync.event("_sweep")
		_deck_nets()
		if stop_waiting:
			_stop_check()
		if custodian_down:
			_custodian_clock += delta
			if _custodian_clock >= CUSTODIAN_EVERY:
				_custodian_clock = 0.0
				sync.event("_custodian_heard")
	_watch_scripts()
	# Solo: B1's scripts keep running while you're away from their runner. (Online,
	# ScriptHost runs them on the host.)
	if sync == null or not sync.is_online():
		for t in _script_terminals():
			var rt = t.get_meta("script_runtime") if t.has_meta("script_runtime") else null
			if rt and rt.is_running():
				rt.tick(delta)
	_follow_decks()
	_static(delta)
	_cold(delta)
	_dock_glimpse()


## The walkie's hiss, now and then, until the earpieces are in.
func _static(delta: float) -> void:
	if earpieces or not get_node("/root/Game").has_walkie:
		return
	_static_clock += delta
	if _static_clock >= 45.0:
		_static_clock = 0.0
		hud.notice(TEXT.static, 3.0)
		_static_whisper()


## Under the hiss, a few words from one of tonight's rows: the next of them each
## time, so a crew that listens hears every name's loop before they see anyone.
func _static_whisper() -> void:
	if data.echoes.is_empty() or not hud:
		return
	var e: Dictionary = data.echoes[_static_turn % data.echoes.size()]
	_static_turn += 1
	var lines: Array = ECHO_LINES.get(e.id, [])
	if not lines.is_empty():
		hud.say("STATIC", "..." + str(lines[0]).to_lower() + "...", 4.0, HUD.Turn.CAN_WAIT)


## This machine's player and the cold.
func _cold(delta: float) -> void:
	if not player or not player.is_inside_tree() or player.health <= 0.0:
		return
	var p := to_local(player.global_position)
	var rate := 0.0
	if VAULT_C.has_point(p):
		rate = 2.0
	elif CORRIDOR.has_point(p) or VAULT_A.has_point(p) or VAULT_B.has_point(p):
		rate = 1.0
	for v in unoccupied:
		if VAULT_ROOMS[v].has_point(p):
			rate *= 2.0
	if rate > 0.0:
		_was_cold = true
		if not _cold_noted:
			_cold_noted = true
			hud.notice(TEXT.cold_first, 4.0)
		# Nobody's body warms itself back up in here: health can't climb while cold.
		if _cold_health >= 0.0 and player.health > _cold_health:
			player.health = _cold_health
		player.spend_stamina(COLD_DRAIN * rate * delta)
		if (player.stamina < COLD_LOW or player.winded) and player.health > COLD_FLOOR:
			player.health = maxf(COLD_FLOOR, player.health - COLD_HURT * rate * delta)
			if not _numb_noted:
				_numb_noted = true
				hud.notice(TEXT.cold_numb, 4.0, ThemeUtil.RED)
		_cold_health = player.health
		return
	_cold_health = -1.0
	if WARM_ROOMS.any(func(r): return r.has_point(p)):
		if _was_cold:
			_was_cold = false
			_numb_noted = false
			hud.notice(TEXT.warm, 3.0)
		if player.health < 100.0:
			player.health = minf(100.0, player.health + WARM_HEAL * delta)


## Every machine: if it came down, the Custodian is heard through the floor below.
func _custodian_heard() -> void:
	if hud and is_inside_tree():
		hud.notice(TEXT.custodian_heard, 4.0)


## Once, the first time this player looks into goods-in: something in the dock shaft.
func _dock_glimpse() -> void:
	if not custodian_down or _custodian_seen or not player:
		return
	if GOODS.has_point(to_local(player.global_position)) and to_local(player.global_position).x > 16.0:
		_custodian_seen = true
		hud.notice(TEXT.custodian_seen, 4.0, ThemeUtil.RED)


# --- The way down --------------------------------------------------------------------------

## Every machine: everyone's past the gate, a storey down STAIR 2.
func _on_exit() -> void:
	get_node("/root/Net").earn("achievement:floor_b1", hud)
	if not player:
		return
	player.input_locked = true
	await get_tree().create_timer(EXIT_HOLD, false).timeout
	if not is_inside_tree():
		return
	Game.completed_level = "level_6"
	Game.next_level = "level_7"  # Field Notes' Continue: the next floor, in the building
	completed.emit()


## Every machine: everyone is down STAIR 2 on B2's landing. Play moves to the
## machine room.
func _down_to_b2() -> void:
	get_node("/root/Net").earn("achievement:floor_b1", hud)
	stairs.seal(Stairwell.of(stair_in))
	active = false  # B1's clocks, cold and deck stay behind: B2's deck opens from here on
	Game.completed_level = "level_6"
	Game.next_level = "level_7"
	finish_level("level_7")


func _on_completed() -> void:
	await hud.fade(true, 1.2)
	finish_level("field_notes")


func on_player_died() -> void:
	player.respawn(spawn_point())
