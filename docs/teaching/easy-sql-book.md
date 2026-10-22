# Easy SQL: the crew's beginner's book (curriculum)

Status: **APPROVED by Augustine 2026-10-20 03:03Z** ("Easy SQL book is approved"),
word for word as written here. Any change to a chapter line or question goes back to him.
Later chapters are approved the same way, word for word with their why lines, as recorded in
`plan/approvals/floor-18-chapters-and-unlocks.md`: Ch 15 and 16 for floor 18 (2026-10-21 11:44Z, whys 11:49Z),
Ch 4's LIMIT and Ch 9 "How many?" (2026-10-21 12:12Z), Ch 17 and 18 for floor 10 (2026-10-21 18:49Z, whys included),
and the why lines for Ch 0 to 8 and Ch 10 to 14 (2026-10-22 01:13Z, with the garage playtest fixes in
`plan/teaching/garage-playtest-2026-10-22.md`). Every question's why line now sits under its word.
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
| 17 | L4, the facilities work order on floor 10 | the tripped breaker (then the main entrance, under threat) | UPDATE, SET, check it took |
| 18 | L4, the contractor log clipboard on floor 10 | the work log (then the Custodian's bay lockout, under threat) | INSERT INTO, VALUES, same order |

Chapter ids: the first fourteen keep theirs (`easy_sql_0` to `easy_sql_13`, so `easy_sql_9` is now Ch 10, and so on).
The newer ones are named for their word: `easy_sql_count` (Ch 9), `easy_sql_distinct` (Ch 15), `easy_sql_group_by`
(Ch 16), `easy_sql_update` (Ch 17) and `easy_sql_insert` (Ch 18). The huddle shows a chapter's position, not its id.

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
(plan/approvals/home-base-huddles.md). Questions below, three per word. Table Q1 and row Q2 were
replaced on 2026-10-21 (18:54Z, approved word for word with their why lines) so the garage quiz no longer uses SELECT
and FROM before Ch 1 teaches them. On 2026-10-22 (01:13Z, garage playtest) the first page gained a line on table names
("A table's name is all one word. Where you'd put a space, it has _ instead: van_kit."), and table Q1 shows a small
van_kit grid under jobs.

**table**
1. What are jobs and van_kit? A) two rows  *B) two tables  C) two columns
2. Which looks like a table name? A) van kit  *B) van_kit  C) Van Kit!
3. Where would you find a table's name in a building? *A) on a label, card or screen nearby  B) the book tells you  C) you guess

Why lines (approved 2026-10-22 01:13Z; table 1 and row 2 on 2026-10-21 18:54Z):
1. Each is a whole table: jobs holds the jobs, and van_kit holds the kit.
2. A space would split the name into two words, so table names join words with _ instead: van_kit. Marks like ! aren't allowed either.
3. Tables are named where people work: on labels, cards and screens. Look around.

**row**
1. In jobs, one row is... *A) one job  B) one column  C) the whole table
2. jobs has 5 jobs in it. How many rows is that? A) 1  B) 3  *C) 5
3. A row goes... *A) across  B) down  C) nowhere

Why lines (approved 2026-10-22 01:13Z; table 1 and row 2 on 2026-10-21 18:54Z):
1. A row is one thing. In jobs, that's one job.
2. One job is one row, so five jobs make five rows.
3. A row runs across: one job, all its facts, side by side.

**column**
1. A column goes... A) across  *B) down  C) diagonally
2. In jobs, which is a column? *A) town  B) job 14  C) jobs
3. Each column is... A) one whole thing  *B) one fact about every row  C) the table's name

Why lines (approved 2026-10-22 01:13Z; table 1 and row 2 on 2026-10-21 18:54Z):
1. A column runs down: the same fact for every row.
2. town is a fact every job has. Job 14 is a row, and jobs is the table.
3. A column is one fact, like town or fee, for every row.

### Ch 1. Ask for a table (flashback at the front desk, required, peek)

Page text: the Home base and huddles draft. Words: SELECT, FROM, `;`. The star is
taught as part of SELECT ("which columns: * for all of them"), so the chapter stays
at three words.

**SELECT** (with *)
1. What does SELECT do? A) deletes rows  *B) shows you data  C) saves your work
2. Which word starts a query? *A) SELECT  B) SHOW  C) FIND
3. What does * mean after SELECT? *A) every column  B) every table  C) multiply

Why lines (approved 2026-10-22 01:13Z):
1. SELECT means "show me". It never changes anything.
2. Every query starts with SELECT.
3. * means every column. SELECT * shows whole rows.

**FROM**
1. In SELECT qty FROM van_kit; which table is read? A) qty  *B) van_kit  C) SELECT
2. Where does FROM go? *A) after the columns you want  B) at the very start  C) after the ;
3. FROM jobs means... A) delete jobs  *B) look in the jobs table  C) make a jobs table

Why lines (approved 2026-10-22 01:13Z):
1. The table's name comes right after FROM. qty is a column.
2. First what you want (SELECT ...), then where it lives (FROM ...).
3. FROM jobs just says where to look. It never changes the table.

**; (semicolon)**
1. How does every query end? A) with a full stop .  *B) with a semicolon ;  C) with nothing
2. You typed SELECT item FROM van_kit and nothing happened. What's missing? *A) the ;  B) a second SELECT  C) quotes
3. Which is a whole query? A) SELECT town FROM jobs  B) FROM jobs SELECT town;  *C) SELECT town FROM jobs;

Why lines (approved 2026-10-22 01:13Z):
1. The semicolon is the full stop of a query.
2. Without the ; the terminal waits for the rest of your question.
3. SELECT, then FROM, then the ; at the end.

### Ch 2. Putting things in order (L0, memo)

**ORDER BY**
- "Rows come out in whatever order they were saved."
- "Add ORDER BY and a column name, before the ;, to sort them."

1. Where does ORDER BY go? A) before SELECT  *B) after the table name, before ;  C) after the ;
2. SELECT * FROM jobs ORDER BY fee; sorts by... A) client  *B) fee  C) job_no
3. Without ORDER BY, rows come out... A) sorted A to Z  *B) in saved order  C) newest first

Why lines (approved 2026-10-22 01:13Z):
1. ORDER BY goes at the end, after the table name and before the ;.
2. The column after ORDER BY is the one it sorts by: fee.
3. Rows come out in the order they were saved, until you sort them.

**smallest first**
- "ORDER BY puts the smallest first: 1, 2, 3, or A, B, C, or earliest time."

1. ORDER BY qty puts which first? *A) the smallest qty  B) the biggest qty  C) random
2. ORDER BY town puts which town first? A) Zebulon  *B) Ashford  C) the last one saved
3. ORDER BY job_no lists jobs... *A) 1, 2, 3...  B) 3, 2, 1...  C) mixed

Why lines (approved 2026-10-22 01:13Z):
1. ORDER BY starts with the smallest: the lowest qty comes first.
2. Words sort A to Z, so Ashford comes before Zebulon.
3. Numbers sort smallest first: 1, 2, 3.

### Ch 3. Just the columns you need (L0, caller)

**column list**
- "Instead of *, name the columns you want. The answer gets narrower and easier to read."

1. SELECT client, fee FROM jobs; shows... A) every column  *B) client and fee  C) only fee
2. Why name columns instead of *? *A) wide tables are hard to read  B) * is broken  C) it's faster to type
3. Which shows only item and shelf? A) SELECT * FROM van_kit;  *B) SELECT item, shelf FROM van_kit;  C) SELECT van_kit FROM item, shelf;

Why lines (approved 2026-10-22 01:13Z):
1. Only the columns you name come back: client and fee.
2. A wide table won't fit on the screen. Name just the columns you need.
3. Columns go after SELECT, the table after FROM.

**comma**
- "Put a comma between column names. No comma after the last one."

1. Which is right? *A) SELECT client, town FROM jobs;  B) SELECT client town FROM jobs;  C) SELECT client, town, FROM jobs;
2. Commas go... A) after every word  *B) between column names  C) after FROM
3. SELECT item, FROM van_kit; is wrong because... A) item is wrong  *B) there's a comma after the last column  C) it needs a *

Why lines (approved 2026-10-22 01:13Z):
1. One comma between each pair of columns, none after the last.
2. Commas only separate the column names.
3. A comma after the last column leaves the database waiting for another one.

**.schema**
- "Don't know a table's columns? Type .schema and the table's name."
- "Dot-commands talk to the terminal, not the database: no ; needed."

1. .schema van_kit shows... A) every row  *B) the column names  C) the table's age
2. Does .schema need a ; at the end? A) yes  *B) no  C) only on Fridays
3. You need a column's exact name. You type... A) SELECT columns;  *B) .schema and the table name  C) ORDER BY

Why lines (approved 2026-10-22 01:13Z):
1. .schema lists a table's columns.
2. Commands that start with a dot talk to the terminal. They don't need a ;.
3. .schema and the table's name shows every column's exact spelling.

### Ch 4. Newest first (L0, last_visitor, optional)

**DESC**
- "Add DESC after ORDER BY's column to flip it: biggest first, latest first."

1. ORDER BY fee DESC puts which first? A) the smallest fee  *B) the biggest fee  C) the oldest job
2. Where does DESC go? A) before ORDER BY  *B) after the column name in ORDER BY  C) after the ;
3. To see the latest times first you add... *A) DESC  B) LAST  C) nothing

Why lines (approved 2026-10-22 01:13Z):
1. DESC flips the sort: the biggest fee comes first.
2. DESC goes straight after the column in ORDER BY, before the ;.
3. DESC puts the latest time first.

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

Why lines (approved 2026-10-22 01:13Z):
1. WHERE keeps only the rows that match: the open jobs.
2. WHERE goes after the table name, before the ;.
3. WHERE filters rows. ORDER BY sorts them.

**= (equals)**
- "= means 'is exactly'. Column on the left, value on the right."

1. WHERE town = 'Ashford' keeps rows where town is... *A) exactly Ashford  B) near Ashford  C) not Ashford
2. Which is the right way round? *A) WHERE qty = 4  B) WHERE 4 qty =  C) WHERE = qty 4
3. WHERE shelf = 'B' finds... A) shelves A and B  *B) only shelf B  C) every shelf

Why lines (approved 2026-10-22 01:13Z):
1. = means exactly that value, nothing near it.
2. Column first, then =, then the value.
3. = 'B' keeps only rows where shelf is exactly B.

**'quotes'**
- "Words go in 'single quotes'. Numbers don't."

1. Which is right? A) WHERE status = open  *B) WHERE status = 'open'  C) WHERE 'status' = open
2. Which needs quotes? *A) 'done'  B) 12  C) neither
3. WHERE qty = '4' or WHERE qty = 4 for a number? A) '4'  *B) 4  C) "four"

Why lines (approved 2026-10-22 01:13Z):
1. Words go in single quotes. Column names don't.
2. Words like 'done' need quotes. Numbers don't.
3. Numbers go in bare: qty = 4.

### Ch 6. Both must be true (L1, controller)

**AND**
- "AND joins two conditions. A row stays only if both are true."

1. WHERE status = 'open' AND town = 'Ashford' keeps... A) all open jobs  *B) open jobs in Ashford  C) every Ashford job
2. With AND, a row stays when... *A) both are true  B) either is true  C) neither is true
3. AND goes... A) before WHERE  *B) between two conditions  C) after the ;

Why lines (approved 2026-10-22 01:13Z):
1. AND keeps a row only if both conditions hold: open, and in Ashford.
2. With AND, both must be true.
3. AND joins two conditions, after WHERE.

### Ch 7. More than, less than (L1, hot_rack, optional)

**> (more than)**
- "> keeps rows where the column is more than a number."

1. WHERE fee > 100 keeps fees of... A) 100 and under  *B) over 100  C) exactly 100
2. Is 100 > 100 true? A) yes  *B) no  C) sometimes
3. Which finds items with more than 10 in stock? *A) WHERE qty > 10  B) WHERE qty < 10  C) WHERE 10 qty >

Why lines (approved 2026-10-22 01:13Z):
1. > means more than, so 100 itself doesn't count.
2. 100 isn't more than 100. They're equal.
3. qty > 10: the column, then >, then the number.

**< (less than)**
- "< is the other way: less than."

1. WHERE qty < 2 keeps... *A) items with 0 or 1 left  B) items with 2 left  C) items with more than 2
2. The open side of < and > faces... A) the smaller number  *B) the bigger number  C) the column
3. To find cheap jobs under 50 you type... A) WHERE fee > 50  *B) WHERE fee < 50  C) WHERE fee = < 50

Why lines (approved 2026-10-22 01:13Z):
1. < 2 keeps anything under 2: that's 0 and 1.
2. The open side faces the bigger number.
3. Under 50 is less than 50: fee < 50.

**numbers**
- "Numbers go in without quotes, so the database compares them as numbers."

1. Which is right? *A) WHERE fee > 40  B) WHERE fee > '40'  C) WHERE fee > forty
2. Why no quotes on numbers? A) quotes are banned  *B) so they compare as numbers  C) to save typing
3. Temperatures like 38 are... *A) numbers  B) words  C) dates

Why lines (approved 2026-10-22 01:13Z):
1. Numbers go in bare: no quotes, no words.
2. Without quotes, 9 is less than 40. In quotes they're compared like words.
3. A temperature is a number, so it goes in without quotes.

### Ch 8. Either one will do (L1, dark_room, optional)

The dark break room. `lights` shows its bulb 'dead'; listing every light that's
'dead' OR 'flickering' (facilities' card) unlocks the circuit reset by its door.

**OR**
- "OR keeps a row if either condition is true."

1. WHERE status = 'open' OR status = 'unpaid' keeps... A) only open jobs  *B) open and unpaid jobs  C) no jobs
2. With OR, a row stays when... A) both are true  *B) at least one is true  C) neither is true
3. AND or OR to find jobs in Ashford or Bexley? A) AND  *B) OR  C) neither

Why lines (approved 2026-10-22 01:13Z):
1. OR keeps a row if either condition is true: open or unpaid.
2. With OR, one true condition is enough.
3. A job can't be in two towns at once, so AND would find nothing. OR finds both.

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

Why lines (approved 2026-10-22 01:13Z):
1. Both must be true, so AND.
2. ORDER BY and the time column puts the log in time order.
3. A word value goes in single quotes, like 'fault'.

### Ch 11. Asking a server (L2 camera booth, cameras)

**GET**
- "Some systems answer web requests, not SQL. GET asks for data."
- "No SELECT, no ;. Just GET and a path."

1. GET /van does what? *A) asks for data about the van  B) deletes the van  C) runs SQL
2. Does a GET need a ; at the end? A) yes  *B) no  C) two of them
3. Which is a request? A) SELECT /jobs;  *B) GET /jobs  C) GET jobs;

Why lines (approved 2026-10-22 01:13Z):
1. GET asks for data. It doesn't change or delete anything.
2. A request isn't SQL, so no ;.
3. GET, a space, then a path starting with /.

**path**
- "The path after GET says what you want, starting with /."

1. In GET /jobs, the path is... A) GET  *B) /jobs  C) jobs;
2. Paths start with... *A) /  B) ;  C) *
3. GET /van_kit asks for... A) the jobs  *B) the van kit  C) everything

Why lines (approved 2026-10-22 01:13Z):
1. The path is the part after GET, starting with /.
2. Every path starts with a slash.
3. The path names what you're asking for: /van_kit.

**JSON**
- "Answers come back as JSON. { } holds one thing's fields; [ ] is a list of them."
- "Each field is a name, a colon, and a value: "qty": 4."

1. In JSON, [ ] means... A) one field  *B) a list  C) an error
2. "status": "open" says... *A) status is open  B) open the status  C) nothing
3. { } holds... *A) one thing's fields  B) a list of things  C) a query

Why lines (approved 2026-10-22 01:13Z):
1. Square brackets hold a list.
2. Each field is a name, a colon, then its value.
3. Curly brackets hold one thing's fields.

### Ch 12. Half a name (L2 booth, pike)

**LIKE**
- "LIKE matches a pattern instead of an exact value."

1. LIKE is for... A) exact matches  *B) patterns  C) sorting
2. Which is right? *A) WHERE client LIKE 'Ash%'  B) WHERE LIKE client 'Ash%'  C) WHERE client = LIKE 'Ash%'
3. You can only read the start of a name. You use... A) =  *B) LIKE  C) ORDER BY

Why lines (approved 2026-10-22 01:13Z):
1. LIKE matches a pattern, not an exact value.
2. Column, then LIKE, then the pattern in quotes.
3. When you only have the start of a name, LIKE and % fill in the rest.

**% (percent)**
- "% means 'any letters, or none'. 'Ash%' matches Ash, Ashford, Ashley."

1. 'Bex%' matches... *A) Bexley  B) Abex  C) Bonex
2. Where does % go to match names starting with Mac? A) '%Mac'  *B) 'Mac%'  C) 'M%ac'
3. Does 'Ash%' match plain "Ash"? *A) yes  B) no  C) only in capitals

Why lines (approved 2026-10-22 01:13Z):
1. 'Bex%' means "starts with Bex", then anything.
2. % after Mac means "starts with Mac".
3. % can stand for no letters at all, so plain Ash matches too.

### Ch 13. One answer feeds the next (L2, har)

No new words. A review huddle on chaining.
- "Sometimes the answer isn't the answer. It's what you need for the next query."

1. A first query gives you an id. Next you... *A) use it in a WHERE  B) start over  C) type it after the ;
2. A first query told you job 14 is the one. To get its client you type... A) SELECT 14;  *B) SELECT client FROM jobs WHERE job_no = 14;  C) ORDER BY 14
3. A log sorted by time shows the last person through a door at the... A) top  *B) bottom  C) middle

Why lines (approved 2026-10-22 01:13Z):
1. Put the id from the first answer into the next query's WHERE.
2. The first answer, 14, goes into WHERE job_no = 14.
3. Sorted oldest first, the latest swipe is at the bottom.

### Ch 14. One door's record (L2 stairwell panel, door)

**id in the path**
- "Add an id to the path to ask about one thing: GET /jobs/14."

1. GET /jobs/14 asks for... A) all jobs  *B) job 14 only  C) 14 jobs
2. To ask about one door you need its... *A) id  B) colour  C) zone
3. Where does the id go? A) before GET  *B) at the end of the path  C) in quotes after it

Why lines (approved 2026-10-22 01:13Z):
1. An id at the end of the path asks for that one thing.
2. Each thing has its own id. That's what goes in the path.
3. The id goes at the end of the path, after a /.

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

### Level 4 chapters: Ch 17 and Ch 18 APPROVED by Augustine word for word, 2026-10-21 18:49Z ("All approved", on the waiting-on-augustine.md list)

Chapters 17 and 18 are for floor 10, where Act 2 opens (plan/level-4-power-plant.md). UPDATE and INSERT are the last new
SQL in the game: after the main entrance lies, the database goes read-only. Each chapter has three words, three questions
per word, and a why line per question, approved with them and shown under each word. The examples are the crew's `jobs` and `van_kit` only.

- **The forgotten WHERE** is a line under UPDATE and a question, so the work order's safe, loud mistake has been warned about first.
- **"Check it took"** teaches verify after write before the main entrance needs it. It doesn't quote the terminal's
  message, so the Level 4 thread can word that message as it likes.
- **INSERT uses the column-list form**: `INSERT INTO table (columns) VALUES (values);`. The table fills in any column the
  crew leaves out (an id, a time). The contractor log's clipboard should show the same form, on another table.
- **"Look at a row before you write to it" is left out on purpose.** The spec has the `main_doors` case page name that
  lesson afterwards.

### Ch 17. Changing a row (L4, the facilities work order, the tripped breaker)

**UPDATE**
- "UPDATE changes rows that are already in a table. UPDATE, the table's name, then SET."
- "Always add a WHERE to pick the rows. Without one, UPDATE changes every row in the table."

1. UPDATE jobs SET status = 'done' WHERE job_no = 14; changes... A) every job  *B) only job 14  C) nothing until you SELECT
2. UPDATE jobs SET status = 'done'; has no WHERE. It changes... A) only the first job  B) nothing: it needs a WHERE  *C) every job in the table
3. What comes straight after UPDATE? *A) the table's name  B) a column's name  C) SET

Why lines (approved 2026-10-21 18:49Z):
1. The WHERE picks job 14, so only that row changes.
2. With no WHERE, UPDATE changes every row in the table. That's why you always add one.
3. The table's name comes straight after UPDATE. SET and the column come next.

**SET**
- "SET names the column to change and its new value: SET status = 'done'."
- "Words still go in 'single quotes'. Numbers don't."

1. UPDATE van_kit SET qty = 0 WHERE item = 'ladder'; Which column changes? *A) qty  B) item  C) van_kit
2. Which is right? A) UPDATE jobs SET 'done' WHERE job_no = 14;  B) UPDATE jobs status = 'done' WHERE job_no = 14;  *C) UPDATE jobs SET status = 'done' WHERE job_no = 14;
3. Where does SET go? A) after the WHERE  *B) after the table's name, before the WHERE  C) before UPDATE

Why lines (approved 2026-10-21 18:49Z):
1. SET names the column that changes: qty. The WHERE only picks which row.
2. SET says which column gets the new value. Without it, the database doesn't know where 'done' goes.
3. SET comes after the table's name and before the WHERE.

**check it took**
- "After a change, the terminal tells you how many rows changed. If it's 0, your WHERE matched nothing."
- "Then SELECT the row again and read it. That's how you know it took."

1. You changed a row, and the terminal says 1 row changed. What next? A) nothing: it's done  *B) SELECT the row and read it  C) send the UPDATE again
2. An UPDATE changes 0 rows. Why? *A) the WHERE matched no rows: maybe a typo in the value  B) it changed every row  C) it worked fine
3. Which checks job 14's status after the change? A) UPDATE jobs SET status = 'done' WHERE job_no = 14;  B) SELECT COUNT(*) FROM jobs;  *C) SELECT status FROM jobs WHERE job_no = 14;

Why lines (approved 2026-10-21 18:49Z):
1. The terminal counts the rows it changed. It can't tell you it was the right row, or that it stayed that way. Reading it back can.
2. 0 rows changed means nothing matched the WHERE, so nothing changed. Check the value for a typo.
3. Picking job 14 and reading its status shows whether the change took. Counting jobs says nothing about status.

### Ch 18. Adding a row (L4, the contractor log clipboard, the work log)

**INSERT INTO**
- "INSERT INTO adds a brand-new row. INSERT INTO, the table's name, then the columns you're filling, in brackets."
- "UPDATE changes a row that's already there. INSERT INTO makes a new one."

1. INSERT INTO jobs (client, town, fee) ... does what? A) changes a job  *B) adds a new job  C) shows the jobs
2. Which starts an insert into van_kit? *A) INSERT INTO van_kit (item, qty, shelf)  B) INSERT van_kit INTO (item, qty, shelf)  C) SELECT INTO van_kit (item, qty, shelf)
3. To log a job you've never had before, you use... A) UPDATE  B) SELECT  *C) INSERT INTO

Why lines (approved 2026-10-21 18:49Z):
1. INSERT INTO adds a brand-new row. UPDATE is the one that changes a row already there.
2. It's INSERT INTO, then the table's name, then the columns in brackets.
3. UPDATE can only change rows that exist. A new job needs INSERT INTO.

**VALUES**
- "VALUES comes after the columns, with the new row's values in brackets: VALUES ('Nash', 'Ashford', 80);"
- "Words in 'single quotes', numbers without, and a comma between each."

1. Which is right? A) VALUES 'rope', 2, 'C';  B) VALUES (rope, 2, C);  *C) VALUES ('rope', 2, 'C');
2. VALUES (Nash, 'Ashford', 80) gives an error. What's wrong? A) 80 needs quotes  *B) Nash needs quotes  C) there's one comma too many
3. Where does VALUES go? *A) after the column list, before the ;  B) before INSERT INTO  C) after the ;

Why lines (approved 2026-10-21 18:49Z):
1. The values go in brackets, with words in quotes and commas between.
2. Nash is a word, so it needs 'single quotes'. 80 is a number, so it doesn't.
3. VALUES comes after the column list and before the ;.

**same order**
- "The values line up with the columns you named: first value, first column; second value, second column."
- "Swap two and the values land in the wrong columns, often with no error to warn you."

1. INSERT INTO van_kit (item, qty) VALUES (3, 'rope'); puts... *A) 3 in item and 'rope' in qty  B) 'rope' in item and 3 in qty  C) nothing: it won't run
2. INSERT INTO jobs (client, town, fee) VALUES ('Nash', 'Ashford', 80); The town is... A) Nash  *B) Ashford  C) 80
3. You named three columns. How many values do you give? A) one  B) as many as you like  *C) three

Why lines (approved 2026-10-21 18:49Z):
1. Values go in the order the columns are named, so 3 lands in item and 'rope' in qty. Swap them to fix it.
2. town is the second column named, so it gets the second value: Ashford.
3. One value for each column you named: three columns, three values.

## Decisions (Augustine, 2026-10-20 03:03Z)

1. The two PROPOSED Level 1 puzzles are approved: the stuck doors as their own step,
   and the optional dark room with OR. Playtest fixes builds them.
2. The crew's `jobs` and `van_kit` tables are approved as the book's sample data
   ("that reinforces the plug-and-play approach for sql queries").

Every question has a one-line "why", approved word for word and shown under its word above (the huddle shows it
after each vote).
