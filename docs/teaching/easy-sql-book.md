# Easy SQL: the crew's beginner's book (curriculum)

Status: **APPROVED by Augustine 2026-10-20 03:03Z** ("Easy SQL book is approved"),
word for word as written here. Any change to a chapter line or question goes back to him.
Later chapters are approved the same way, word for word with their why lines, as recorded in
`plan/approvals/floor-18-chapters-and-unlocks.md`: Ch 15 and 16 for floor 18 (2026-10-21 11:44Z, whys 11:49Z),
and Ch 4's LIMIT and Ch 9 "How many?" (2026-10-21 12:12Z).
Format, title pattern and rules are his choices (2026-10-20, plan/act2-story-teaching-combat.md section 3, option C):

- **Title:** *Easy SQL*. Later books follow the same pattern (*Hello HTML!*).
- **Crew huddles.** The game opens in the crew's garage with the first huddle. Each
  later SQL chapter plays as a flashback to a garage huddle before the job, at the
  moment the puzzle starts. A book that arrives later is huddled on the spot or in
  the elevator.
- **Up to 3 new words per puzzle**, each with a 3-question multiple-choice check
  (Augustine, 00:08Z: three questions for each word) that the crew answers together (everyone votes, majority wins, a tie re-votes).
  Solo players read and answer alone.
- **The garage chapters are required:** Ch 0 (table, row, column) before the van,
  and Ch 1 (the shape of a query and the semicolon) as a garage flashback at the
  front desk. Later quizzes can be skipped; the chapter text still plays.
- **Votes** (Home base default): the crew's answer is the most-voted option; a tie
  re-votes; a wrong answer shows its "why" and the same question comes back.
- **3 to 5 puzzles per floor.** All three floors meet it: Floor 1's two extra
  puzzles (stuck_doors, dark_room) were proposed here and built in #96.

Owned by the Teaching and UX thread. The Home base and huddles thread builds the
scenes; puzzle threads own the puzzles.

## Rules for the book

1. **The book teaches words, the building teaches facts.** Chapters never name a
   building table, column, zone, badge or PIN. Those are found in the world.
   Examples use the crew's own garage database only.
2. **The book's sample tables** are the crew's own business records (proposed in
   place of the draft's `customers`, so every example feels like theirs):
   - `jobs`: job_no, client, town, status ('open', 'done', 'unpaid'), fee
   - `van_kit`: item, qty, shelf
   These are the crew's own records, not an example of the building's tables, so
   the "hints never use example tables" rule is untouched: hints still use only the
   real tables.
3. **A chapter is "found in the world".** The huddle is the first sighting, the
   quiz is a recognition check, and the puzzle stays the safe typed practice. So
   the order found, then practised safely, then used under pressure still holds.
   The lost-player test will count chapter text as taught once the huddles exist
   (`"chapter"` field in tests/curriculum.gd).
4. **Questions have three options**, one correct. Wrong options are real mistakes
   beginners make, never jokes. The correct letter varies.
5. **Never the answer.** No chapter or question contains a puzzle's value or exact
   query.

## Chapter map

| Ch | When the huddle plays | Puzzle | New words |
|---|---|---|---|
| 0 | Garage, before the van (required) | (tutorial) | table, row, column |
| 1 | L0 front desk, garage flashback (required) | peek | SELECT (with *), FROM, `;` |
| 2 | L0, after the memo prints | memo | ORDER BY, smallest first |
| 3 | L0, Rourke's "who called?" | caller | column list, comma, `.schema` |
| 4 | L0, visitor book (optional) | last_visitor | DESC, LIMIT |
| 5 | L1, NOC shift log | stuck_doors | WHERE, `=`, `'quotes'` |
| 6 | L1, Server Room A self-test | controller | AND |
| 7 | L1, Server Room B noise (optional) | hot_rack | `>`, `<`, numbers |
| 8 | L1, dark break room (optional) | dark_room | OR |
| 9 | L1, the reset sign-off form | faulted_count | COUNT(*) |
| 10 | L2 lab lockdown (elevator flashback) | lab_door, badge_log | none: review quiz |
| 11 | L2 camera booth | cameras | GET, path, JSON |
| 12 | L2 booth, sign-in sheet | pike | LIKE, `%` |
| 13 | L2, Pike's PIN suspended | har | none: "one answer feeds the next" review |
| 14 | L2 stairwell panel | door | id in the path |
| 15 | L3, the retention review memo by the card drawers | depts | DISTINCT |
| 16 | L3, the reader tally sheet on the records desk | tally (then visits, under threat) | GROUP BY |

Chapter ids: the first fourteen keep theirs (`easy_sql_0` to `easy_sql_13`, so `easy_sql_9` is now Ch 10, and so on).
The newer ones are named for their word: `easy_sql_count` (Ch 9), `easy_sql_distinct` (Ch 15), `easy_sql_group_by`
(Ch 16). The huddle shows a chapter's position, not its id.

Floor counts: L0 has 4 puzzles. L1 has 5 (stuck_doors and dark_room landed in #96, the faulted count with curriculum B). L2 has 6 (lab_door, badge_log, cameras, pike, har, door), one over the
limit; badge_log is now the har chain's first step, so it can count as part of har.

Notes:
- Ch 4 backs up the N.F. sticky by the visitor book (PR #82), the in-world place DESC is found before its hint.
- Ch 7 fixes the other: `>` is found nowhere near the terminal before its hint.
- Ch 8 brings in OR, which is otherwise never taught by the end of L2.
- Ch 9 brings COUNT onto floor 14 (curriculum B). Floor 22's SYSOP and floor 18's slips station reuse it.
- Curriculum debt stays: COLUMNS, DESC, `>` and LIKE are never needed under
  pressure by the end of L2. Level 3 should use them again.

## Chapters and quizzes

Each word: chapter lines (read aloud in the huddle), then three questions. `*` marks
the correct option.

### Ch 0. Read this first (garage, required, before the van)

Structure and page text: the Home base and huddles thread's draft
(plan/approvals/home-base-huddles.md). Questions below, three per word.

**table**
1. Where does a table's name go in a query? A) after SELECT  *B) after FROM  C) after the ;
2. Which looks like a table name? A) van kit  *B) van_kit  C) Van Kit!
3. Where would you find a table's name in a building? *A) on a label, card or screen nearby  B) the book tells you  C) you guess

**row**
1. In jobs, one row is... *A) one job  B) one column  C) the whole table
2. SELECT * FROM jobs; with 5 jobs shows how many rows? A) 1  B) 3  *C) 5
3. A row goes... *A) across  B) down  C) nowhere

**column**
1. A column goes... A) across  *B) down  C) diagonally
2. In jobs, which is a column? *A) town  B) job 14  C) jobs
3. Each column is... A) one whole thing  *B) one fact about every row  C) the table's name

### Ch 1. Ask for a table (flashback at the front desk, required, peek)

Page text: the Home base and huddles draft. Words: SELECT, FROM, `;`. The star is
taught as part of SELECT ("which columns: * for all of them"), so the chapter stays
at three words.

**SELECT** (with *)
1. What does SELECT do? A) deletes rows  *B) shows you data  C) saves your work
2. Which word starts a query? *A) SELECT  B) SHOW  C) FIND
3. What does * mean after SELECT? *A) every column  B) every table  C) multiply

**FROM**
1. In SELECT qty FROM van_kit; which table is read? A) qty  *B) van_kit  C) SELECT
2. Where does FROM go? *A) after the columns you want  B) at the very start  C) after the ;
3. FROM jobs means... A) delete jobs  *B) look in the jobs table  C) make a jobs table

**; (semicolon)**
1. How does every query end? A) with a full stop .  *B) with a semicolon ;  C) with nothing
2. You typed SELECT item FROM van_kit and nothing happened. What's missing? *A) the ;  B) a second SELECT  C) quotes
3. Which is a whole query? A) SELECT town FROM jobs  B) FROM jobs SELECT town;  *C) SELECT town FROM jobs;

### Ch 2. Putting things in order (L0, memo)

**ORDER BY**
- "Rows come out in whatever order they were saved."
- "Add ORDER BY and a column name, before the ;, to sort them."

1. Where does ORDER BY go? A) before SELECT  *B) after the table name, before ;  C) after the ;
2. SELECT * FROM jobs ORDER BY fee; sorts by... A) client  *B) fee  C) job_no
3. Without ORDER BY, rows come out... A) sorted A to Z  *B) in saved order  C) newest first

**smallest first**
- "ORDER BY puts the smallest first: 1, 2, 3, or A, B, C, or earliest time."

1. ORDER BY qty puts which first? *A) the smallest qty  B) the biggest qty  C) random
2. ORDER BY town puts which town first? A) Zebulon  *B) Ashford  C) the last one saved
3. ORDER BY job_no lists jobs... *A) 1, 2, 3...  B) 3, 2, 1...  C) mixed

### Ch 3. Just the columns you need (L0, caller)

**column list**
- "Instead of *, name the columns you want. The answer gets narrower and easier to read."

1. SELECT client, fee FROM jobs; shows... A) every column  *B) client and fee  C) only fee
2. Why name columns instead of *? *A) wide tables are hard to read  B) * is broken  C) it's faster to type
3. Which shows only item and shelf? A) SELECT * FROM van_kit;  *B) SELECT item, shelf FROM van_kit;  C) SELECT van_kit FROM item, shelf;

**comma**
- "Put a comma between column names. No comma after the last one."

1. Which is right? *A) SELECT client, town FROM jobs;  B) SELECT client town FROM jobs;  C) SELECT client, town, FROM jobs;
2. Commas go... A) after every word  *B) between column names  C) after FROM
3. SELECT item, FROM van_kit; is wrong because... A) item is wrong  *B) there's a comma after the last column  C) it needs a *

**.schema**
- "Don't know a table's columns? Type .schema and the table's name."
- "Dot-commands talk to the terminal, not the database: no ; needed."

1. .schema van_kit shows... A) every row  *B) the column names  C) the table's age
2. Does .schema need a ; at the end? A) yes  *B) no  C) only on Fridays
3. You need a column's exact name. You type... A) SELECT columns;  *B) .schema and the table name  C) ORDER BY

### Ch 4. Newest first (L0, last_visitor, optional)

**DESC**
- "Add DESC after ORDER BY's column to flip it: biggest first, latest first."

1. ORDER BY fee DESC puts which first? A) the smallest fee  *B) the biggest fee  C) the oldest job
2. Where does DESC go? A) before ORDER BY  *B) after the column name in ORDER BY  C) after the ;
3. To see the latest times first you add... *A) DESC  B) LAST  C) nothing

**LIMIT**
- "LIMIT and a number, at the very end, keeps only that many rows from the top."
- "With ORDER BY and DESC first, LIMIT 3 gives you the newest three."

1. SELECT * FROM jobs ORDER BY fee DESC LIMIT 3; shows... A) every job except three  B) the three smallest fees  *C) the three biggest fees
2. Where does LIMIT go? *A) at the very end, just before the ;  B) straight after SELECT  C) before ORDER BY
3. With no ORDER BY, LIMIT 2 gives... A) the two newest rows  *B) the first two rows, in saved order  C) an error

Why lines (approved 2026-10-21 12:12Z):
1. DESC puts the biggest fee on top, and LIMIT 3 keeps the top three.
2. LIMIT comes last, after ORDER BY, right before the ;.
3. LIMIT keeps rows from the top. With no ORDER BY, the top is whatever was saved first.

### Ch 5. Keeping only some rows (L1, stuck_doors)

The NOC log says the night alarms came from doors that won't release; querying the
locked doors (SELECT name, zone FROM doors WHERE locked = 1) gives their zone. The
value is a number, so the quotes questions below include one for numbers going in
without quotes, which is what the puzzle's second hint says.

**WHERE**
- "WHERE keeps only the rows that match. It goes after the table name."

1. SELECT * FROM jobs WHERE status = 'open'; shows... A) every job  *B) only open jobs  C) no jobs
2. Where does WHERE go? *A) after the table name  B) before SELECT  C) after the ;
3. WHERE is for... A) sorting  *B) filtering  C) naming columns

**= (equals)**
- "= means 'is exactly'. Column on the left, value on the right."

1. WHERE town = 'Ashford' keeps rows where town is... *A) exactly Ashford  B) near Ashford  C) not Ashford
2. Which is the right way round? *A) WHERE qty = 4  B) WHERE 4 qty =  C) WHERE = qty 4
3. WHERE shelf = 'B' finds... A) shelves A and B  *B) only shelf B  C) every shelf

**'quotes'**
- "Words go in 'single quotes'. Numbers don't."

1. Which is right? A) WHERE status = open  *B) WHERE status = 'open'  C) WHERE 'status' = open
2. Which needs quotes? *A) 'done'  B) 12  C) neither
3. WHERE qty = '4' or WHERE qty = 4 for a number? A) '4'  *B) 4  C) "four"

### Ch 6. Both must be true (L1, controller)

**AND**
- "AND joins two conditions. A row stays only if both are true."

1. WHERE status = 'open' AND town = 'Ashford' keeps... A) all open jobs  *B) open jobs in Ashford  C) every Ashford job
2. With AND, a row stays when... *A) both are true  B) either is true  C) neither is true
3. AND goes... A) before WHERE  *B) between two conditions  C) after the ;

### Ch 7. More than, less than (L1, hot_rack, optional)

**> (more than)**
- "> keeps rows where the column is more than a number."

1. WHERE fee > 100 keeps fees of... A) 100 and under  *B) over 100  C) exactly 100
2. Is 100 > 100 true? A) yes  *B) no  C) sometimes
3. Which finds items with more than 10 in stock? *A) WHERE qty > 10  B) WHERE qty < 10  C) WHERE 10 qty >

**< (less than)**
- "< is the other way: less than."

1. WHERE qty < 2 keeps... *A) items with 0 or 1 left  B) items with 2 left  C) items with more than 2
2. The open side of < and > faces... A) the smaller number  *B) the bigger number  C) the column
3. To find cheap jobs under 50 you type... A) WHERE fee > 50  *B) WHERE fee < 50  C) WHERE fee = < 50

**numbers**
- "Numbers go in without quotes, so the database compares them as numbers."

1. Which is right? *A) WHERE fee > 40  B) WHERE fee > '40'  C) WHERE fee > forty
2. Why no quotes on numbers? A) quotes are banned  *B) so they compare as numbers  C) to save typing
3. Temperatures like 38 are... *A) numbers  B) words  C) dates

### Ch 8. Either one will do (L1, dark_room, optional)

The dark break room. `lights` shows its bulb 'dead'; listing every light that's
'dead' OR 'flickering' (facilities' card) unlocks the circuit reset by its door.

**OR**
- "OR keeps a row if either condition is true."

1. WHERE status = 'open' OR status = 'unpaid' keeps... A) only open jobs  *B) open and unpaid jobs  C) no jobs
2. With OR, a row stays when... A) both are true  *B) at least one is true  C) neither is true
3. AND or OR to find jobs in Ashford or Bexley? A) AND  *B) OR  C) neither

### Ch 9. How many? (L1, the reset sign-off form, faulted_count)

**COUNT(*)**
- "SELECT COUNT(*) gives one number: how many rows there are, instead of the rows themselves."
- "Add a WHERE and it counts only the rows that match."

1. SELECT COUNT(*) FROM jobs; with 12 jobs shows... A) all 12 jobs  B) the last job  *C) one number: 12
2. SELECT COUNT(*) FROM jobs WHERE status = 'unpaid'; counts... *A) only the unpaid jobs  B) every job  C) the unpaid fees, added up
3. COUNT(*) goes... A) after the table name  *B) after SELECT, where the columns go  C) after WHERE

Why lines (approved 2026-10-21 11:49Z, with the move here approved 12:12Z):
1. COUNT(*) doesn't show the rows. It counts them and gives one number.
2. WHERE picks the rows first, and COUNT(*) counts only those. It counts rows, not fees.
3. COUNT(*) sits where the columns go, right after SELECT.

### Ch 10. Under pressure (L2 lab lockdown, review)

No new words. A review huddle, played as a fast elevator flashback: "Same tools as
the server floor. Breathe."

1. To keep rows in one zone that are also faulted you use... A) OR  *B) AND  C) ORDER BY
2. To read a log in time order you add... *A) ORDER BY and the time column  B) DESC only  C) WHERE time
3. A word value like fault goes in... A) no quotes  *B) 'single quotes'  C) brackets

### Ch 11. Asking a server (L2 camera booth, cameras)

**GET**
- "Some systems answer web requests, not SQL. GET asks for data."
- "No SELECT, no ;. Just GET and a path."

1. GET /van does what? *A) asks for data about the van  B) deletes the van  C) runs SQL
2. Does a GET need a ; at the end? A) yes  *B) no  C) two of them
3. Which is a request? A) SELECT /jobs;  *B) GET /jobs  C) GET jobs;

**path**
- "The path after GET says what you want, starting with /."

1. In GET /jobs, the path is... A) GET  *B) /jobs  C) jobs;
2. Paths start with... *A) /  B) ;  C) *
3. GET /van_kit asks for... A) the jobs  *B) the van kit  C) everything

**JSON**
- "Answers come back as JSON. { } holds one thing's fields; [ ] is a list of them."
- "Each field is a name, a colon, and a value: "qty": 4."

1. In JSON, [ ] means... A) one field  *B) a list  C) an error
2. "status": "open" says... *A) status is open  B) open the status  C) nothing
3. { } holds... *A) one thing's fields  B) a list of things  C) a query

### Ch 12. Half a name (L2 booth, pike)

**LIKE**
- "LIKE matches a pattern instead of an exact value."

1. LIKE is for... A) exact matches  *B) patterns  C) sorting
2. Which is right? *A) WHERE client LIKE 'Ash%'  B) WHERE LIKE client 'Ash%'  C) WHERE client = LIKE 'Ash%'
3. You can only read the start of a name. You use... A) =  *B) LIKE  C) ORDER BY

**% (percent)**
- "% means 'any letters, or none'. 'Ash%' matches Ash, Ashford, Ashley."

1. 'Bex%' matches... *A) Bexley  B) Abex  C) Bonex
2. Where does % go to match names starting with Mac? A) '%Mac'  *B) 'Mac%'  C) 'M%ac'
3. Does 'Ash%' match plain "Ash"? *A) yes  B) no  C) only in capitals

### Ch 13. One answer feeds the next (L2, har)

No new words. A review huddle on chaining.
- "Sometimes the answer isn't the answer. It's what you need for the next query."

1. A first query gives you an id. Next you... *A) use it in a WHERE  B) start over  C) type it after the ;
2. A first query told you job 14 is the one. To get its client you type... A) SELECT 14;  *B) SELECT client FROM jobs WHERE job_no = 14;  C) ORDER BY 14
3. A log sorted by time shows the last person through a door at the... A) top  *B) bottom  C) middle

### Ch 14. One door's record (L2 stairwell panel, door)

**id in the path**
- "Add an id to the path to ask about one thing: GET /jobs/14."

1. GET /jobs/14 asks for... A) all jobs  *B) job 14 only  C) 14 jobs
2. To ask about one door you need its... *A) id  B) colour  C) zone
3. Where does the id go? A) before GET  *B) at the end of the path  C) in quotes after it

### Floor 18 chapters: APPROVED by Augustine word for word (2026-10-21 11:44Z, "Approve all")

Recorded in `plan/approvals/floor-18-chapters-and-unlocks.md`. Chapter ids: `easy_sql_distinct` (Ch 15) and
`easy_sql_group_by` (Ch 16); the old chapters keep their ids. Their "why" lines were approved at 11:49Z and sit under each word.

Chapters 15 and 16 are for floor 18, the end of Act 1 (curriculum option B). Level 3's draft titles are kept. The
book's rules apply, so each word gets three questions, not the two in Level 3's draft. Nothing here names a building
table, room or value; the examples are the crew's `jobs` and `van_kit`.

- **The slips station has no huddle.** It counts without groups, and it's review: Ch 9 teaches COUNT on floor 14.
- **COUNT(*) moved to Ch 9** word for word, with its whys (approved 2026-10-21 12:12Z). Ch 16 keeps GROUP BY; its
  lines still say "With COUNT(*)", which is now review.
- **IS NULL deliberately has no chapter.** The crew looks it up on Mercer's reference card.
- **Ordering by a count.** Chapter 16's third GROUP BY line covers `ORDER BY COUNT(*) DESC`. No paper on 18 shows
  it, and the night's count under threat needs it. Approved with the rest.

### Ch 15. One of each (L3, the retention review memo, depts)

**DISTINCT**
- "DISTINCT goes straight after SELECT. Each different value comes back once, however many rows share it."
- "SELECT town FROM jobs; gives one line per job. SELECT DISTINCT town FROM jobs; gives one line per town."

1. Ten jobs in three towns. SELECT DISTINCT town FROM jobs; shows how many rows? A) 10  *B) 3  C) 1
2. Where does DISTINCT go? A) after the table name  B) just before the ;  *C) straight after SELECT
3. SELECT DISTINCT town FROM jobs WHERE status = 'open'; shows... *A) each town with an open job, once  B) every open job  C) every town, once

Why lines (approved 2026-10-21 11:49Z; the huddle shows one after each vote):
1. DISTINCT keeps each different town once. Three towns, three rows.
2. DISTINCT goes right after SELECT, before the column it works on.
3. WHERE keeps the open jobs first. Then DISTINCT shows each of their towns once.

### Ch 16. Counting in piles (L3, the reader tally sheet, tally)

**GROUP BY**
- "GROUP BY sorts the rows into piles, one pile for each different value in a column. It goes after the table name and any WHERE."
- "With COUNT(*), you get one line per pile and how many are in it. Put the column in SELECT too, so you can see which pile is which."
- "Piles come out in any order. ORDER BY COUNT(*) DESC puts the biggest pile first."

1. SELECT town, COUNT(*) FROM jobs GROUP BY town; shows... A) one line per job  *B) one line per town, with how many jobs each  C) one number for all the jobs
2. Where does GROUP BY go? A) straight after SELECT  B) after the ;  *C) after the table name and any WHERE, before ORDER BY
3. Which shelf holds the most kinds of kit? After GROUP BY shelf you add... *A) ORDER BY COUNT(*) DESC  B) ORDER BY shelf DESC  C) DISTINCT shelf

Why lines (approved 2026-10-21 11:49Z):
1. GROUP BY town makes one pile per town, and COUNT(*) counts each pile.
2. GROUP BY comes after FROM and any WHERE, and before ORDER BY.
3. ORDER BY COUNT(*) DESC sorts the piles by size, biggest first. Sorting by shelf only puts the names in order.

**Curriculum debt (update):** the night's count under threat uses a column list, DESC and LIKE again. `>` is
still never needed under pressure in Act 1.

## Decisions (Augustine, 2026-10-20 03:03Z)

1. The two PROPOSED Level 1 puzzles are approved: the stuck doors as their own step,
   and the optional dark room with OR. Playtest fixes builds them.
2. The crew's `jobs` and `van_kit` tables are approved as the book's sample data
   ("that reinforces the plug-and-play approach for sql queries").

Still to write, and to approve: a one-line "why" for each answer (the huddle shows
it after a wrong vote).
