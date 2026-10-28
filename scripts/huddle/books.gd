class_name Books
extends RefCounted
## The crew's beginner's books, chapter by chapter. A chapter is read in a huddle
## (see Huddle): one player reads its pages aloud, then the crew answers its quiz
## together. Each chapter brings at most three new words.
##
## Approved by Augustine word for word (2026-10-20 03:03Z): the chapter lines and
## questions are plan/teaching/easy-sql-book.md (Teaching and UX owns it), and
## Chapters 0 and 1's pages are plan/approvals/home-base-huddles.md. Change a word
## and it goes back to him. The examples use the crew's own garage records, `jobs`
## and `van_kit`, never a table from the building.
##
## Floor 18's chapters (One of each, Counting in piles) were approved word for word
## on 2026-10-21: pages and questions at 11:44Z, their `why` lines
## (plan/teaching/easy-sql-whys.md) at 11:49Z. Curriculum B (12:12Z): LIMIT joins
## Newest first, and COUNT(*) moved word for word from Counting in piles into its
## own chapter, How many?, for floor 14.
## Chapter zero's table and row questions that leaned on SELECT and FROM before
## Ch 1 teaches them were replaced, with their why lines, word for word at 18:54Z
## (plan/teaching/ground-floor-playtest-teaching.md, item 10).
##
## Floor 10's chapters (Changing a row, Adding a row) were approved word for word,
## pages, questions and why lines, at 18:49Z on 2026-10-21.
## The garage playtest's fixes (plan/teaching/garage-playtest-2026-10-22.md: chapter
## zero's table-name line, its van_kit table and quiz why lines) and the remaining why
## lines, Ch 1-8 and 10-14 (plan/teaching/easy-sql-whys.md), at 01:13Z on 2026-10-22.
## Maddison's lines for Just the columns you need, Newest first, Either one will do,
## How many?, Under pressure, One answer feeds the next and One door's record were
## approved word for word at 17:19Z on 2026-10-28 (plan/approvals/maddison-new-chapter-lines.md).
## Chapter ids never change once shipped: profiles keep "chapter:<id>". The number
## shown is the chapter's place in the list, so a chapter added in the middle
## renumbers the rest by itself. New chapters get a word id (easy_sql_distinct).
##
## Chapter: {id, title, when, required, words, lines, pages: [text], quiz, rounds?}
## `when` is where the huddle plays; `lines` are voice line ids heard over the
## garage radio, one as the book opens and one as it closes. Each quiz question:
## {word, q, options, answer, why, also?}, three per word; `also` is extra text
## shown beside that question only. `answer` indexes `options` as
## written here; the quiz shuffles them per run. `why` ("" until written) shows
## after an answer.
##
## The crew reads a chapter's pages in a huddle (Books.reading_order); its quick
## checks are asked only when a player tests themselves from the book in their
## notebook (BookQuiz). They come in rounds (Books.rounds): each word's three
## questions, with its page on show beside them. Chapters whose
## pages aren't one per word say how in `rounds`: [{pages: [index], word, ref:
## [page index]}], where a round with no word is pages only. A question with
## "closed": true tests memory, so it hides the page.

## A small van_kit beside chapter zero's "What are jobs and van_kit?", under jobs
## (playtest 2026-10-22: only jobs was on show). No caption: that would answer it.
const VAN_KIT := "    van_kit\n    item   | qty | shelf\n    -------+-----+------\n    ladder | 1   | A\n    drill  | 2   | B"

## Easy SQL's teal cover (matches ArtKit.easy_sql_book).
const COVER := Color(0.05, 0.55, 0.6)
## The typewriter font's size on a page, unless it has to shrink to fit (page_bbcode).
const CODE_SIZE := 20

const BOOKS := {
	"easy_sql": {
		"title": "EASY SQL",
		"name": "Easy SQL",
		"chapters": [
			{
				"id": "easy_sql_0",
				"title": "Read this first",
				"when": "garage, required, before the van",
				"required": true,
				"words": ["table", "row", "column"],
				"lines": [],
				# The jobs table stays on show for every question.
				"rounds": [{"pages": [0, 1], "word": "table", "ref": [1]}, {"word": "row", "ref": [1]},
					{"word": "column", "ref": [1]}, {"pages": [2]}],
				"pages": [
					"A database is a stack of tables.\n\nA table is a grid, like a spreadsheet. It has a name, and it holds facts about one kind of thing.\nA table's name is all one word. Where you'd put a space, it has _ instead: van_kit.",
					"Each ROW is one thing: one job, one van.\nEach COLUMN is one fact about it: a name, a number, a date.\n\n    jobs\n    job_no | client         | town    | status | fee\n    -------+----------------+---------+--------+----\n    1      | Kemp Dental    | Ashford | done   | 80\n    2      | Bexley Library | Bexley  | open   | 120\n\nThis table is called jobs. It has 2 rows and 5 columns.",
					"To get anything out of a database, you ask it a question. The questions are written in SQL.\n\nChapter 1 is your first question.",
				],
				"quiz": [
					{"word": "table", "q": "What are jobs and van_kit?", "also": VAN_KIT,
						"options": ["two rows", "two tables", "two columns"], "answer": 1, "why": "Each is a whole table: jobs holds the jobs, and van_kit holds the kit."},
					{"word": "table", "q": "Which looks like a table name?",
						"options": ["van kit", "van_kit", "Van Kit!"], "answer": 1, "why": "A space would split the name into two words, so table names join words with _ instead: van_kit. Marks like ! aren't allowed either."},
					{"word": "table", "q": "Where would you find a table's name in a building?",
						"options": ["on a label, card or screen nearby", "the book tells you", "you guess"], "answer": 0, "why": "Tables are named where people work: on labels, cards and screens. Look around."},
					{"word": "row", "q": "In jobs, one row is...",
						"options": ["one job", "one column", "the whole table"], "answer": 0, "why": "A row is one thing. In jobs, that's one job."},
					{"word": "row", "q": "jobs has 5 jobs in it. How many rows is that?",
						"options": ["1", "3", "5"], "answer": 2, "why": "One job is one row, so five jobs make five rows."},
					{"word": "row", "q": "A row goes...",
						"options": ["across", "down", "nowhere"], "answer": 0, "why": "A row runs across: one job, all its facts, side by side."},
					{"word": "column", "q": "A column goes...",
						"options": ["across", "down", "diagonally"], "answer": 1, "why": "A column runs down: the same fact for every row."},
					{"word": "column", "q": "In jobs, which is a column?",
						"options": ["town", "job 14", "jobs"], "answer": 0, "why": "town is a fact every job has. Job 14 is a row, and jobs is the table."},
					{"word": "column", "q": "Each column is...",
						"options": ["one whole thing", "one fact about every row", "the table's name"], "answer": 1, "why": "A column is one fact, like town or fee, for every row."},
				],
			},
			{
				"id": "easy_sql_1",
				"title": "Ask for a table",
				"when": "flashback at the front desk, required, peek",
				"required": true,
				"words": ["SELECT", "FROM", "; (semicolon)"],
				"rounds": [{"pages": [0, 1], "word": "SELECT", "ref": [0, 1]}, {"word": "FROM", "ref": [0]},
					{"pages": [2], "word": "; (semicolon)", "ref": [2]}],
				"lines": ["l0_huddle_select_1", "l0_huddle_select_2"],
				"pages": [
					"Every question starts the same way:\n\n    SELECT columns FROM table;\n\nSELECT says which columns you want to see.\nFROM says which table to read them from.",
					"Don't know the columns yet? Use a star. * means every column:\n\n    SELECT * FROM jobs;\n\nThat shows the whole jobs table.",
					"Always end with a semicolon (;). It tells the database your question is finished.\n\nCapitals don't matter, but spelling does: the table's name has to be exact.",
				],
				"quiz": [
					{"word": "SELECT", "q": "What does SELECT do?",
						"options": ["deletes rows", "shows you data", "saves your work"], "answer": 1, "why": "SELECT means \"show me\". It never changes anything."},
					{"word": "SELECT", "q": "Which word starts a query?",
						"options": ["SELECT", "SHOW", "FIND"], "answer": 0, "why": "Every query starts with SELECT."},
					{"word": "SELECT", "q": "What does * mean after SELECT?",
						"options": ["every column", "every table", "multiply"], "answer": 0, "why": "* means every column. SELECT * shows whole rows."},
					{"word": "FROM", "q": "In SELECT qty FROM van_kit; which table is read?",
						"options": ["qty", "van_kit", "SELECT"], "answer": 1, "why": "The table's name comes right after FROM. qty is a column."},
					{"word": "FROM", "q": "Where does FROM go?",
						"options": ["after the columns you want", "at the very start", "after the ;"], "answer": 0, "why": "First what you want (SELECT ...), then where it lives (FROM ...)."},
					{"word": "FROM", "q": "FROM jobs means...",
						"options": ["delete jobs", "look in the jobs table", "make a jobs table"], "answer": 1, "why": "FROM jobs just says where to look. It never changes the table."},
					{"word": "; (semicolon)", "q": "How does every query end?",
						"options": ["with a full stop .", "with a semicolon ;", "with nothing"], "answer": 1, "why": "The semicolon is the full stop of a query."},
					{"word": "; (semicolon)", "q": "You typed SELECT item FROM van_kit and nothing happened. What's missing?",
						"options": ["the ;", "a second SELECT", "quotes"], "answer": 0, "why": "Without the ; the terminal waits for the rest of your question."},
					{"word": "; (semicolon)", "q": "Which is a whole query?",
						"options": ["SELECT town FROM jobs", "FROM jobs SELECT town;", "SELECT town FROM jobs;"], "answer": 2, "why": "SELECT, then FROM, then the ; at the end."},
				],
			},
			{
				"id": "easy_sql_2",
				"title": "Putting things in order",
				"when": "L0, memo",
				"required": false,
				"words": ["ORDER BY", "smallest first"],
				"lines": ["l0_huddle_order_1", "l0_huddle_order_2"],
				"pages": [
					"ORDER BY\n\nRows come out in whatever order they were saved.\n\nAdd ORDER BY and a column name, before the ;, to sort them.",
					"smallest first\n\nORDER BY puts the smallest first: 1, 2, 3, or A, B, C, or earliest time.",
				],
				"quiz": [
					{"word": "ORDER BY", "q": "Where does ORDER BY go?",
						"options": ["before SELECT", "after the table name, before ;", "after the ;"], "answer": 1, "why": "ORDER BY goes at the end, after the table name and before the ;."},
					{"word": "ORDER BY", "q": "SELECT * FROM jobs ORDER BY fee; sorts by...",
						"options": ["client", "fee", "job_no"], "answer": 1, "why": "The column after ORDER BY is the one it sorts by: fee."},
					{"word": "ORDER BY", "q": "Without ORDER BY, rows come out...",
						"options": ["sorted A to Z", "in saved order", "newest first"], "answer": 1, "why": "Rows come out in the order they were saved, until you sort them."},
					{"word": "smallest first", "q": "ORDER BY qty puts which first?",
						"options": ["the smallest qty", "the biggest qty", "random"], "answer": 0, "why": "ORDER BY starts with the smallest: the lowest qty comes first."},
					{"word": "smallest first", "q": "ORDER BY town puts which town first?",
						"options": ["Zebulon", "Ashford", "the last one saved"], "answer": 1, "why": "Words sort A to Z, so Ashford comes before Zebulon."},
					{"word": "smallest first", "q": "ORDER BY job_no lists jobs...",
						"options": ["1, 2, 3...", "3, 2, 1...", "mixed"], "answer": 0, "why": "Numbers sort smallest first: 1, 2, 3."},
				],
			},
			{
				"id": "easy_sql_3",
				"title": "Just the columns you need",
				"when": "L0, caller",
				"required": false,
				"words": ["column list", "comma", ".schema"],
				"lines": ["l0_huddle_columns_1", "l0_huddle_columns_2"],
				"pages": [
					"column list\n\nInstead of *, name the columns you want. The answer gets narrower and easier to read.",
					"comma\n\nPut a comma between column names. No comma after the last one.",
					".schema\n\nDon't know a table's columns? Type .schema and the table's name.\n\nDot-commands talk to the terminal, not the database: no ; needed.",
				],
				"quiz": [
					{"word": "column list", "q": "SELECT client, fee FROM jobs; shows...",
						"options": ["every column", "client and fee", "only fee"], "answer": 1, "why": "Only the columns you name come back: client and fee."},
					{"word": "column list", "q": "Why name columns instead of *?",
						"options": ["wide tables are hard to read", "* is broken", "it's faster to type"], "answer": 0, "why": "A wide table won't fit on the screen. Name just the columns you need."},
					{"word": "column list", "q": "Which shows only item and shelf?",
						"options": ["SELECT * FROM van_kit;", "SELECT item, shelf FROM van_kit;", "SELECT van_kit FROM item, shelf;"], "answer": 1, "why": "Columns go after SELECT, the table after FROM."},
					{"word": "comma", "q": "Which is right?",
						"options": ["SELECT client, town FROM jobs;", "SELECT client town FROM jobs;", "SELECT client, town, FROM jobs;"], "answer": 0, "why": "One comma between each pair of columns, none after the last."},
					{"word": "comma", "q": "Commas go...",
						"options": ["after every word", "between column names", "after FROM"], "answer": 1, "why": "Commas only separate the column names."},
					{"word": "comma", "q": "SELECT item, FROM van_kit; is wrong because...",
						"options": ["item is wrong", "there's a comma after the last column", "it needs a *"], "answer": 1, "why": "A comma after the last column leaves the database waiting for another one."},
					{"word": ".schema", "q": ".schema van_kit shows...",
						"options": ["every row", "the column names", "the table's age"], "answer": 1, "why": ".schema lists a table's columns."},
					{"word": ".schema", "q": "Does .schema need a ; at the end?",
						"options": ["yes", "no", "only on Fridays"], "answer": 1, "why": "Commands that start with a dot talk to the terminal. They don't need a ;."},
					{"word": ".schema", "q": "You need a column's exact name. You type...",
						"options": ["SELECT columns;", ".schema and the table name", "ORDER BY"], "answer": 1, "why": ".schema and the table's name shows every column's exact spelling."},
				],
			},
			{
				"id": "easy_sql_4",
				"title": "Newest first",
				"when": "L0, last_visitor, optional",
				"required": false,
				"words": ["DESC", "LIMIT"],
				"lines": ["l0_huddle_desc_1", "l0_huddle_desc_2"],
				"pages": [
					"DESC\n\nAdd DESC after ORDER BY's column to flip it: biggest first, latest first.",
					"LIMIT\n\nLIMIT and a number, at the very end, keeps only that many rows from the top.\n\nWith ORDER BY and DESC first, LIMIT 3 gives you the newest three.",
				],
				"quiz": [
					{"word": "DESC", "q": "ORDER BY fee DESC puts which first?",
						"options": ["the smallest fee", "the biggest fee", "the oldest job"], "answer": 1, "why": "DESC flips the sort: the biggest fee comes first."},
					{"word": "DESC", "q": "Where does DESC go?",
						"options": ["before ORDER BY", "after the column name in ORDER BY", "after the ;"], "answer": 1, "why": "DESC goes straight after the column in ORDER BY, before the ;."},
					{"word": "DESC", "q": "To see the latest times first you add...",
						"options": ["DESC", "LAST", "nothing"], "answer": 0, "why": "DESC puts the latest time first."},
					{"word": "LIMIT", "q": "SELECT * FROM jobs ORDER BY fee DESC LIMIT 3; shows...",
						"options": ["every job except three", "the three smallest fees", "the three biggest fees"], "answer": 2, "why": "DESC puts the biggest fee on top, and LIMIT 3 keeps the top three."},
					{"word": "LIMIT", "q": "Where does LIMIT go?",
						"options": ["at the very end, just before the ;", "straight after SELECT", "before ORDER BY"], "answer": 0, "why": "LIMIT comes last, after ORDER BY, right before the ;."},
					{"word": "LIMIT", "q": "With no ORDER BY, LIMIT 2 gives...",
						"options": ["the two newest rows", "the first two rows, in saved order", "an error"], "answer": 1, "why": "LIMIT keeps rows from the top. With no ORDER BY, the top is whatever was saved first."},
				],
			},
			{
				"id": "easy_sql_5",
				"title": "Keeping only some rows",
				"when": "L1, stuck_doors, PROPOSED step",
				"required": false,
				"words": ["WHERE", "= (equals)", "'quotes'"],
				"lines": ["l1_huddle_where_1"],
				"pages": [
					"WHERE\n\nWHERE keeps only the rows that match. It goes after the table name.",
					"= (equals)\n\n= means 'is exactly'. Column on the left, value on the right.",
					"'quotes'\n\nWords go in 'single quotes'. Numbers don't.",
				],
				"quiz": [
					{"word": "WHERE", "q": "SELECT * FROM jobs WHERE status = 'open'; shows...",
						"options": ["every job", "only open jobs", "no jobs"], "answer": 1, "why": "WHERE keeps only the rows that match: the open jobs."},
					{"word": "WHERE", "q": "Where does WHERE go?",
						"options": ["after the table name", "before SELECT", "after the ;"], "answer": 0, "why": "WHERE goes after the table name, before the ;."},
					{"word": "WHERE", "q": "WHERE is for...",
						"options": ["sorting", "filtering", "naming columns"], "answer": 1, "why": "WHERE filters rows. ORDER BY sorts them."},
					{"word": "= (equals)", "q": "WHERE town = 'Ashford' keeps rows where town is...",
						"options": ["exactly Ashford", "near Ashford", "not Ashford"], "answer": 0, "why": "= means exactly that value, nothing near it."},
					{"word": "= (equals)", "q": "Which is the right way round?",
						"options": ["WHERE qty = 4", "WHERE 4 qty =", "WHERE = qty 4"], "answer": 0, "why": "Column first, then =, then the value."},
					{"word": "= (equals)", "q": "WHERE shelf = 'B' finds...",
						"options": ["shelves A and B", "only shelf B", "every shelf"], "answer": 1, "why": "= 'B' keeps only rows where shelf is exactly B."},
					{"word": "'quotes'", "q": "Which is right?",
						"options": ["WHERE status = open", "WHERE status = 'open'", "WHERE 'status' = open"], "answer": 1, "why": "Words go in single quotes. Column names don't."},
					{"word": "'quotes'", "q": "Which needs quotes?",
						"options": ["'done'", "12", "neither"], "answer": 0, "why": "Words like 'done' need quotes. Numbers don't."},
					{"word": "'quotes'", "q": "WHERE qty = '4' or WHERE qty = 4 for a number?",
						"options": ["'4'", "4", "\"four\""], "answer": 1, "why": "Numbers go in bare: qty = 4."},
				],
			},
			{
				"id": "easy_sql_6",
				"title": "Both must be true",
				"when": "L1, controller",
				"required": false,
				"words": ["AND"],
				"lines": ["l1_huddle_where_2"],
				"pages": [
					"AND\n\nAND joins two conditions. A row stays only if both are true.",
				],
				"quiz": [
					{"word": "AND", "q": "WHERE status = 'open' AND town = 'Ashford' keeps...",
						"options": ["all open jobs", "open jobs in Ashford", "every Ashford job"], "answer": 1, "why": "AND keeps a row only if both conditions hold: open, and in Ashford."},
					{"word": "AND", "q": "With AND, a row stays when...",
						"options": ["both are true", "either is true", "neither is true"], "answer": 0, "why": "With AND, both must be true."},
					{"word": "AND", "q": "AND goes...",
						"options": ["before WHERE", "between two conditions", "after the ;"], "answer": 1, "why": "AND joins two conditions, after WHERE."},
				],
			},
			{
				"id": "easy_sql_7",
				"title": "More than, less than",
				"when": "L1, hot_rack, optional",
				"required": false,
				"words": ["> (more than)", "< (less than)", "numbers"],
				"lines": ["l1_huddle_compare_1", "l1_huddle_compare_2"],
				"pages": [
					"> (more than)\n\n> keeps rows where the column is more than a number.",
					"< (less than)\n\n< is the other way: less than.",
					"numbers\n\nNumbers go in without quotes, so the database compares them as numbers.",
				],
				"quiz": [
					{"word": "> (more than)", "q": "WHERE fee > 100 keeps fees of...",
						"options": ["100 and under", "over 100", "exactly 100"], "answer": 1, "why": "> means more than, so 100 itself doesn't count."},
					{"word": "> (more than)", "q": "Is 100 > 100 true?",
						"options": ["yes", "no", "sometimes"], "answer": 1, "why": "100 isn't more than 100. They're equal."},
					{"word": "> (more than)", "q": "Which finds items with more than 10 in stock?",
						"options": ["WHERE qty > 10", "WHERE qty < 10", "WHERE 10 qty >"], "answer": 0, "why": "qty > 10: the column, then >, then the number."},
					{"word": "< (less than)", "q": "WHERE qty < 2 keeps...",
						"options": ["items with 0 or 1 left", "items with 2 left", "items with more than 2"], "answer": 0, "why": "< 2 keeps anything under 2: that's 0 and 1."},
					{"word": "< (less than)", "q": "The open side of < and > faces...",
						"options": ["the smaller number", "the bigger number", "the column"], "answer": 1, "why": "The open side faces the bigger number."},
					{"word": "< (less than)", "q": "To find cheap jobs under 50 you type...",
						"options": ["WHERE fee > 50", "WHERE fee < 50", "WHERE fee = < 50"], "answer": 1, "why": "Under 50 is less than 50: fee < 50."},
					{"word": "numbers", "q": "Which is right?",
						"options": ["WHERE fee > 40", "WHERE fee > '40'", "WHERE fee > forty"], "answer": 0, "why": "Numbers go in bare: no quotes, no words."},
					{"word": "numbers", "q": "Why no quotes on numbers?",
						"options": ["quotes are banned", "so they compare as numbers", "to save typing"], "answer": 1, "why": "Without quotes, 9 is less than 40. In quotes they're compared like words."},
					{"word": "numbers", "q": "Temperatures like 38 are...",
						"options": ["numbers", "words", "dates"], "answer": 0, "why": "A temperature is a number, so it goes in without quotes."},
				],
			},
			{
				"id": "easy_sql_8",
				"title": "Either one will do",
				"when": "L1, dark_room, PROPOSED optional",
				"required": false,
				"words": ["OR"],
				"lines": ["l1_huddle_or_1", "l1_huddle_or_2"],
				"pages": [
					"OR\n\nOR keeps a row if either condition is true.",
				],
				"quiz": [
					{"word": "OR", "q": "WHERE status = 'open' OR status = 'unpaid' keeps...",
						"options": ["only open jobs", "open and unpaid jobs", "no jobs"], "answer": 1, "why": "OR keeps a row if either condition is true: open or unpaid."},
					{"word": "OR", "q": "With OR, a row stays when...",
						"options": ["both are true", "at least one is true", "neither is true"], "answer": 1, "why": "With OR, one true condition is enough."},
					{"word": "OR", "q": "AND or OR to find jobs in Ashford or Bexley?",
						"options": ["AND", "OR", "neither"], "answer": 1, "why": "A job can't be in two towns at once, so AND would find nothing. OR finds both."},
				],
			},
			{
				"id": "easy_sql_count",
				"title": "How many?",
				"when": "L1, the reset sign-off form, count",
				"required": false,
				"words": ["COUNT(*)"],
				"lines": ["l1_huddle_count_1", "l1_huddle_count_2"],
				"pages": [
					"COUNT(*)\n\nSELECT COUNT(*) gives one number: how many rows there are, instead of the rows themselves.\n\nAdd a WHERE and it counts only the rows that match.",
				],
				"quiz": [
					{"word": "COUNT(*)", "q": "SELECT COUNT(*) FROM jobs; with 12 jobs shows...",
						"options": ["all 12 jobs", "the last job", "one number: 12"], "answer": 2, "why": "COUNT(*) doesn't show the rows. It counts them and gives one number."},
					{"word": "COUNT(*)", "q": "SELECT COUNT(*) FROM jobs WHERE status = 'unpaid'; counts...",
						"options": ["only the unpaid jobs", "every job", "the unpaid fees, added up"], "answer": 0, "why": "WHERE picks the rows first, and COUNT(*) counts only those. It counts rows, not fees."},
					{"word": "COUNT(*)", "q": "COUNT(*) goes...",
						"options": ["after the table name", "after SELECT, where the columns go", "after WHERE"], "answer": 1, "why": "COUNT(*) sits where the columns go, right after SELECT."},
				],
			},
			{
				"id": "easy_sql_9",
				"title": "Under pressure",
				"when": "L2 lab lockdown, review",
				"required": false,
				"words": [],
				"lines": ["l2_huddle_pressure_1", "l2_huddle_pressure_2"],
				"pages": [
					"Same tools as the server floor. Breathe.",
				],
				"quiz": [
					{"word": "", "q": "To keep rows in one zone that are also faulted you use...",
						"options": ["OR", "AND", "ORDER BY"], "answer": 1, "why": "Both must be true, so AND."},
					{"word": "", "q": "To read a log in time order you add...",
						"options": ["ORDER BY and the time column", "DESC only", "WHERE time"], "answer": 0, "why": "ORDER BY and the time column puts the log in time order."},
					{"word": "", "q": "A word value like fault goes in...",
						"options": ["no quotes", "'single quotes'", "brackets"], "answer": 1, "why": "A word value goes in single quotes, like 'fault'."},
				],
			},
			{
				"id": "easy_sql_10",
				"title": "Asking a server",
				"when": "L2 camera booth, cameras",
				"required": false,
				"words": ["GET", "path", "JSON"],
				"lines": ["l2_huddle_get_1", "l2_huddle_get_2"],
				"pages": [
					"GET\n\nSome systems answer web requests, not SQL. GET asks for data.\n\nNo SELECT, no ;. Just GET and a path.",
					"path\n\nThe path after GET says what you want, starting with /.",
					"JSON\n\nAnswers come back as JSON. { } holds one thing's fields; [ ] is a list of them.\n\nEach field is a name, a colon, and a value: \"qty\": 4.",
				],
				"quiz": [
					{"word": "GET", "q": "GET /van does what?",
						"options": ["asks for data about the van", "deletes the van", "runs SQL"], "answer": 0, "why": "GET asks for data. It doesn't change or delete anything."},
					{"word": "GET", "q": "Does a GET need a ; at the end?",
						"options": ["yes", "no", "two of them"], "answer": 1, "why": "A request isn't SQL, so no ;."},
					{"word": "GET", "q": "Which is a request?",
						"options": ["SELECT /jobs;", "GET /jobs", "GET jobs;"], "answer": 1, "why": "GET, a space, then a path starting with /."},
					{"word": "path", "q": "In GET /jobs, the path is...",
						"options": ["GET", "/jobs", "jobs;"], "answer": 1, "why": "The path is the part after GET, starting with /."},
					{"word": "path", "q": "Paths start with...",
						"options": ["/", ";", "*"], "answer": 0, "why": "Every path starts with a slash."},
					{"word": "path", "q": "GET /van_kit asks for...",
						"options": ["the jobs", "the van kit", "everything"], "answer": 1, "why": "The path names what you're asking for: /van_kit."},
					{"word": "JSON", "q": "In JSON, [ ] means...",
						"options": ["one field", "a list", "an error"], "answer": 1, "why": "Square brackets hold a list."},
					{"word": "JSON", "q": "\"status\": \"open\" says...",
						"options": ["status is open", "open the status", "nothing"], "answer": 0, "why": "Each field is a name, a colon, then its value."},
					{"word": "JSON", "q": "{ } holds...",
						"options": ["one thing's fields", "a list of things", "a query"], "answer": 0, "why": "Curly brackets hold one thing's fields."},
				],
			},
			{
				"id": "easy_sql_11",
				"title": "Half a name",
				"when": "L2 booth, pike",
				"required": false,
				"words": ["LIKE", "% (percent)"],
				"lines": ["l2_huddle_like_1", "l2_huddle_like_2"],
				"pages": [
					"LIKE\n\nLIKE matches a pattern instead of an exact value.",
					"% (percent)\n\n% means 'any letters, or none'. 'Ash%' matches Ash, Ashford, Ashley.",
				],
				"quiz": [
					{"word": "LIKE", "q": "LIKE is for...",
						"options": ["exact matches", "patterns", "sorting"], "answer": 1, "why": "LIKE matches a pattern, not an exact value."},
					{"word": "LIKE", "q": "Which is right?",
						"options": ["WHERE client LIKE 'Ash%'", "WHERE LIKE client 'Ash%'", "WHERE client = LIKE 'Ash%'"], "answer": 0, "why": "Column, then LIKE, then the pattern in quotes."},
					{"word": "LIKE", "q": "You can only read the start of a name. You use...",
						"options": ["=", "LIKE", "ORDER BY"], "answer": 1, "why": "When you only have the start of a name, LIKE and % fill in the rest."},
					{"word": "% (percent)", "q": "'Bex%' matches...",
						"options": ["Bexley", "Abex", "Bonex"], "answer": 0, "why": "'Bex%' means \"starts with Bex\", then anything."},
					{"word": "% (percent)", "q": "Where does % go to match names starting with Mac?",
						"options": ["'%Mac'", "'Mac%'", "'M%ac'"], "answer": 1, "why": "% after Mac means \"starts with Mac\"."},
					{"word": "% (percent)", "q": "Does 'Ash%' match plain \"Ash\"?",
						"options": ["yes", "no", "only in capitals"], "answer": 0, "why": "% can stand for no letters at all, so plain Ash matches too."},
				],
			},
			{
				"id": "easy_sql_12",
				"title": "One answer feeds the next",
				"when": "L2, har",
				"required": false,
				"words": [],
				"lines": ["l2_huddle_feeds_1", "l2_huddle_feeds_2"],
				"pages": [
					"Sometimes the answer isn't the answer. It's what you need for the next query.",
				],
				"quiz": [
					{"word": "", "q": "A first query gives you an id. Next you...",
						"options": ["use it in a WHERE", "start over", "type it after the ;"], "answer": 0, "why": "Put the id from the first answer into the next query's WHERE."},
					{"word": "", "q": "A first query told you job 14 is the one. To get its client you type...",
						"options": ["SELECT 14;", "SELECT client FROM jobs WHERE job_no = 14;", "ORDER BY 14"], "answer": 1, "why": "The first answer, 14, goes into WHERE job_no = 14."},
					{"word": "", "q": "A log sorted by time shows the last person through a door at the...",
						"options": ["top", "bottom", "middle"], "answer": 1, "why": "Sorted oldest first, the latest swipe is at the bottom."},
				],
			},
			{
				"id": "easy_sql_13",
				"title": "One door's record",
				"when": "L2 stairwell panel, door",
				"required": false,
				"words": ["id in the path"],
				"lines": ["l2_huddle_door_1", "l2_huddle_door_2"],
				"pages": [
					"id in the path\n\nAdd an id to the path to ask about one thing: GET /jobs/14.",
				],
				"quiz": [
					{"word": "id in the path", "q": "GET /jobs/14 asks for...",
						"options": ["all jobs", "job 14 only", "14 jobs"], "answer": 1, "why": "An id at the end of the path asks for that one thing."},
					{"word": "id in the path", "q": "To ask about one door you need its...",
						"options": ["id", "colour", "zone"], "answer": 0, "why": "Each thing has its own id. That's what goes in the path."},
					{"word": "id in the path", "q": "Where does the id go?",
						"options": ["before GET", "at the end of the path", "in quotes after it"], "answer": 1, "why": "The id goes at the end of the path, after a /."},
				],
			},
			{
				"id": "easy_sql_distinct",
				"title": "One of each",
				"when": "L3, the retention review memo, depts",
				"required": false,
				"words": ["DISTINCT"],
				"lines": [],
				"pages": [
					"DISTINCT\n\nDISTINCT goes straight after SELECT. Each different value comes back once, however many rows share it.\n\nSELECT town FROM jobs; gives one line per job. SELECT DISTINCT town FROM jobs; gives one line per town.",
				],
				"quiz": [
					{"word": "DISTINCT", "q": "Ten jobs in three towns. SELECT DISTINCT town FROM jobs; shows how many rows?",
						"options": ["10", "3", "1"], "answer": 1, "why": "DISTINCT keeps each different town once. Three towns, three rows."},
					{"word": "DISTINCT", "q": "Where does DISTINCT go?",
						"options": ["after the table name", "just before the ;", "straight after SELECT"], "answer": 2, "why": "DISTINCT goes right after SELECT, before the column it works on."},
					{"word": "DISTINCT", "q": "SELECT DISTINCT town FROM jobs WHERE status = 'open'; shows...",
						"options": ["each town with an open job, once", "every open job", "every town, once"], "answer": 0, "why": "WHERE keeps the open jobs first. Then DISTINCT shows each of their towns once."},
				],
			},
			{
				"id": "easy_sql_group_by",
				"title": "Counting in piles",
				"when": "L3, the reader tally sheet, tally",
				"required": false,
				"words": ["GROUP BY"],
				"lines": [],
				"pages": [
					"GROUP BY\n\nGROUP BY sorts the rows into piles, one pile for each different value in a column. It goes after the table name and any WHERE.\n\nWith COUNT(*), you get one line per pile and how many are in it. Put the column in SELECT too, so you can see which pile is which.\n\nPiles come out in any order. ORDER BY COUNT(*) DESC puts the biggest pile first.",
				],
				"quiz": [
					{"word": "GROUP BY", "q": "SELECT town, COUNT(*) FROM jobs GROUP BY town; shows...",
						"options": ["one line per job", "one line per town, with how many jobs each", "one number for all the jobs"], "answer": 1, "why": "GROUP BY town makes one pile per town, and COUNT(*) counts each pile."},
					{"word": "GROUP BY", "q": "Where does GROUP BY go?",
						"options": ["straight after SELECT", "after the ;", "after the table name and any WHERE, before ORDER BY"], "answer": 2, "why": "GROUP BY comes after FROM and any WHERE, and before ORDER BY."},
					{"word": "GROUP BY", "q": "Which shelf holds the most kinds of kit? After GROUP BY shelf you add...",
						"options": ["ORDER BY COUNT(*) DESC", "ORDER BY shelf DESC", "DISTINCT shelf"], "answer": 0, "why": "ORDER BY COUNT(*) DESC sorts the piles by size, biggest first. Sorting by shelf only puts the names in order."},
				],
			},
			{
				"id": "easy_sql_update",
				"title": "Changing a row",
				"when": "L4, the facilities work order, the tripped breaker",
				"required": false,
				"words": ["UPDATE", "SET", "check it took"],
				"lines": ["l4_huddle_update_1", "l4_huddle_update_2"],
				"pages": [
					"UPDATE\n\nUPDATE changes rows that are already in a table. UPDATE, the table's name, then SET.\n\nAlways add a WHERE to pick the rows. Without one, UPDATE changes every row in the table.",
					"SET\n\nSET names the column to change and its new value: SET status = 'done'.\n\nWords still go in 'single quotes'. Numbers don't.",
					"check it took\n\nAfter a change, the terminal tells you how many rows changed. If it's 0, your WHERE matched nothing.\n\nThen SELECT the row again and read it. That's how you know it took.",
				],
				"quiz": [
					{"word": "UPDATE", "q": "UPDATE jobs SET status = 'done' WHERE job_no = 14; changes...",
						"options": ["every job", "only job 14", "nothing until you SELECT"], "answer": 1, "why": "The WHERE picks job 14, so only that row changes."},
					{"word": "UPDATE", "q": "UPDATE jobs SET status = 'done'; has no WHERE. It changes...",
						"options": ["only the first job", "nothing: it needs a WHERE", "every job in the table"], "answer": 2, "why": "With no WHERE, UPDATE changes every row in the table. That's why you always add one."},
					{"word": "UPDATE", "q": "What comes straight after UPDATE?",
						"options": ["the table's name", "a column's name", "SET"], "answer": 0, "why": "The table's name comes straight after UPDATE. SET and the column come next."},
					{"word": "SET", "q": "UPDATE van_kit SET qty = 0 WHERE item = 'ladder'; Which column changes?",
						"options": ["qty", "item", "van_kit"], "answer": 0, "why": "SET names the column that changes: qty. The WHERE only picks which row."},
					{"word": "SET", "q": "Which is right?",
						"options": ["UPDATE jobs SET 'done' WHERE job_no = 14;", "UPDATE jobs status = 'done' WHERE job_no = 14;", "UPDATE jobs SET status = 'done' WHERE job_no = 14;"], "answer": 2, "why": "SET says which column gets the new value. Without it, the database doesn't know where 'done' goes."},
					{"word": "SET", "q": "Where does SET go?",
						"options": ["after the WHERE", "after the table's name, before the WHERE", "before UPDATE"], "answer": 1, "why": "SET comes after the table's name and before the WHERE."},
					{"word": "check it took", "q": "You changed a row, and the terminal says 1 row changed. What next?",
						"options": ["nothing: it's done", "SELECT the row and read it", "send the UPDATE again"], "answer": 1, "why": "The terminal counts the rows it changed. It can't tell you it was the right row, or that it stayed that way. Reading it back can."},
					{"word": "check it took", "q": "An UPDATE changes 0 rows. Why?",
						"options": ["the WHERE matched no rows: maybe a typo in the value", "it changed every row", "it worked fine"], "answer": 0, "why": "0 rows changed means nothing matched the WHERE, so nothing changed. Check the value for a typo."},
					{"word": "check it took", "q": "Which checks job 14's status after the change?",
						"options": ["UPDATE jobs SET status = 'done' WHERE job_no = 14;", "SELECT COUNT(*) FROM jobs;", "SELECT status FROM jobs WHERE job_no = 14;"], "answer": 2, "why": "Picking job 14 and reading its status shows whether the change took. Counting jobs says nothing about status."},
				],
			},
			{
				"id": "easy_sql_insert",
				"title": "Adding a row",
				"when": "L4, the contractor log clipboard, the work log",
				"required": false,
				"words": ["INSERT INTO", "VALUES", "same order"],
				"lines": ["l4_huddle_insert_1", "l4_huddle_insert_2"],
				"pages": [
					"INSERT INTO\n\nINSERT INTO adds a brand-new row. INSERT INTO, the table's name, then the columns you're filling, in brackets.\n\nUPDATE changes a row that's already there. INSERT INTO makes a new one.",
					"VALUES\n\nVALUES comes after the columns, with the new row's values in brackets: VALUES ('Nash', 'Ashford', 80);\n\nWords in 'single quotes', numbers without, and a comma between each.",
					"same order\n\nThe values line up with the columns you named: first value, first column; second value, second column.\n\nSwap two and the values land in the wrong columns, often with no error to warn you.",
				],
				"quiz": [
					{"word": "INSERT INTO", "q": "INSERT INTO jobs (client, town, fee) ... does what?",
						"options": ["changes a job", "adds a new job", "shows the jobs"], "answer": 1, "why": "INSERT INTO adds a brand-new row. UPDATE is the one that changes a row already there."},
					{"word": "INSERT INTO", "q": "Which starts an insert into van_kit?",
						"options": ["INSERT INTO van_kit (item, qty, shelf)", "INSERT van_kit INTO (item, qty, shelf)", "SELECT INTO van_kit (item, qty, shelf)"], "answer": 0, "why": "It's INSERT INTO, then the table's name, then the columns in brackets."},
					{"word": "INSERT INTO", "q": "To log a job you've never had before, you use...",
						"options": ["UPDATE", "SELECT", "INSERT INTO"], "answer": 2, "why": "UPDATE can only change rows that exist. A new job needs INSERT INTO."},
					{"word": "VALUES", "q": "Which is right?",
						"options": ["VALUES 'rope', 2, 'C';", "VALUES (rope, 2, C);", "VALUES ('rope', 2, 'C');"], "answer": 2, "why": "The values go in brackets, with words in quotes and commas between."},
					{"word": "VALUES", "q": "VALUES (Nash, 'Ashford', 80) gives an error. What's wrong?",
						"options": ["80 needs quotes", "Nash needs quotes", "there's one comma too many"], "answer": 1, "why": "Nash is a word, so it needs 'single quotes'. 80 is a number, so it doesn't."},
					{"word": "VALUES", "q": "Where does VALUES go?",
						"options": ["after the column list, before the ;", "before INSERT INTO", "after the ;"], "answer": 0, "why": "VALUES comes after the column list and before the ;."},
					{"word": "same order", "q": "INSERT INTO van_kit (item, qty) VALUES (3, 'rope'); puts...",
						"options": ["3 in item and 'rope' in qty", "'rope' in item and 3 in qty", "nothing: it won't run"], "answer": 0, "why": "Values go in the order the columns are named, so 3 lands in item and 'rope' in qty. Swap them to fix it."},
					{"word": "same order", "q": "INSERT INTO jobs (client, town, fee) VALUES ('Nash', 'Ashford', 80); The town is...",
						"options": ["Nash", "Ashford", "80"], "answer": 1, "why": "town is the second column named, so it gets the second value: Ashford."},
					{"word": "same order", "q": "You named three columns. How many values do you give?",
						"options": ["one", "as many as you like", "three"], "answer": 2, "why": "One value for each column you named: three columns, three values."},
				],
			},
		],
	},
	# The sequel, found on floor 9's training shelf (Level 5): the building's services,
	# asked through the terminal. Title is Augustine's (2026-10-22, with his apostrophe).
	# Pages, questions and why lines are DRAFTS until he approves them word for word:
	# plan/approvals/l5-text.md. The examples use the garage's own job board service
	# (/jobs and /van_kit, the same records as Easy SQL), never one of the building's.
	"acceptable_apis": {
		"title": "ACCEPTABLE API'S",
		"chapters": [
			{
				"id": "api_codes",
				"title": "Read the number",
				"when": "L5, desk sheet (with Chapter 2)",
				"required": false,
				"words": ["status code", "4xx"],
				"lines": ["l5_huddle_codes_1", "l5_huddle_codes_2"],
				"pages": [
					"status code\n\nEvery answer starts with a number. 200 OK: here's what you asked for. 201 Created: made it. Two hundreds are good news.\n\nThe number comes before the answer. Read it first.",
					"4xx\n\nFour hundreds mean the request was wrong, and each one says how.\n400: a field is missing or wrong (it names it). 401: no key, or a key it doesn't know. 403: a real key, not allowed to do this. 404: nothing at that path. 409: it can't, the way things are now (it says why).\n\nFive hundreds are the service's own fault. Try again later.",
				],
				"quiz": [
					{"word": "status code", "q": "The job board answers 200. That's...",
						"options": ["good: here's what you asked for", "bad: it refused", "a count of jobs"], "answer": 0, "why": "Two hundreds are good news. 200 OK means here's your answer."},
					{"word": "status code", "q": "Where's the status code?",
						"options": ["at the end of the answer", "at the start of the answer", "in the body you sent"], "answer": 1, "why": "It's the first thing in the answer, before anything else."},
					{"word": "status code", "q": "201 is...",
						"options": ["an error", "Created: it made what you asked", "a page number"], "answer": 1, "why": "201 Created is the good answer to a POST."},
					{"word": "4xx", "q": "404 means...",
						"options": ["the service is down", "nothing at that path", "the body was wrong"], "answer": 1, "why": "404 Not Found: there's nothing where you asked."},
					{"word": "4xx", "q": "A 409 says the panel is over its limit. You...",
						"options": ["send the same request again", "change what's in the way, then try again", "give up: the service is broken"], "answer": 1, "why": "409 means it can't, the way things are now. Change what's in the way; the message says what."},
					{"word": "4xx", "q": "Which is the service's own fault?",
						"options": ["400", "404", "500"], "answer": 2, "why": "Five hundreds are the service's problem. Four hundreds are yours."},
				],
			},
			{
				"id": "api_keys",
				"title": "A key with every request",
				"when": "L5, desk sheet (with Chapter 1)",
				"required": false,
				"words": ["header", "X-Api-Key"],
				"lines": ["l5_huddle_keys_1", "l5_huddle_keys_2"],
				"pages": [
					"header\n\nA header is a line under the request: a label, a colon, a value. It's about the request, not part of what you're asking for.\n\nGET /jobs\nX-Api-Key: 1a2b-3c4d\n\nOn the terminal, Shift+Enter starts the header's line. An empty line sends it all.",
					"X-Api-Key\n\nSome services only answer people with a key. The key goes in the X-Api-Key header, on every request.\n\nNo key: 401. A key it doesn't know: 401. The right key for the wrong job: 403.\n\nKeys are issued to people. Somebody's key is written down somewhere near where they sit.",
				],
				"quiz": [
					{"word": "header", "q": "Where does a header go?",
						"options": ["on the line under the request", "inside the body", "before the request"], "answer": 0, "why": "The request line first, then its headers, one per line."},
					{"word": "header", "q": "Which is a header?",
						"options": ["X-Api-Key: 1a2b-3c4d", "{\"X-Api-Key\": \"1a2b-3c4d\"}", "GET /X-Api-Key"], "answer": 0, "why": "A label, a colon, a value, on its own line."},
					{"word": "header", "q": "On the terminal, you start a header's line with...",
						"options": ["Enter", "Shift+Enter", "a comma"], "answer": 1, "why": "Enter on an empty line sends the request. Shift+Enter starts a new line inside it."},
					{"word": "X-Api-Key", "q": "The service answers 401. That means...",
						"options": ["the path is wrong", "it wants a key it knows", "it made what you asked"], "answer": 1, "why": "401: no key, or a key it doesn't recognise. Send it again with the right one."},
					{"word": "X-Api-Key", "q": "A real key gets 403. That means...",
						"options": ["the key is allowed to, but the path is wrong", "the key is real, but not allowed to do this", "the key has expired"], "answer": 1, "why": "403: the key works, for something else. This needs a different key."},
					{"word": "X-Api-Key", "q": "You sent the key once and got 200. The next request...",
						"options": ["needs the key again", "remembers it", "needs a new key"], "answer": 0, "why": "A key goes with every request. The service doesn't remember you."},
				],
			},
			{
				"id": "api_patch",
				"title": "Changing one thing",
				"when": "L5, facilities clipboard (panel)",
				"required": false,
				"words": ["PATCH", "true / false"],
				"lines": ["l5_huddle_patch_1", "l5_huddle_patch_2"],
				"pages": [
					"PATCH\n\nPATCH changes one thing about one record, and leaves the rest alone. The record is in the path, the change is in the body.\n\nPATCH /van_kit/rope\n\n{\"qty\": 3}\n\nchanges the rope's qty to 3 and nothing else. Like UPDATE with its WHERE built in: the path says which one.",
					"true / false\n\nSome fields are a switch: on or off, locked or not. Their values are true and false, with no quotes.\n\n{\"charged\": true}\n\n\"true\" in quotes is a word, not a switch, and the service says 400.",
				],
				"quiz": [
					{"word": "PATCH", "q": "PATCH /van_kit/rope with {\"shelf\": \"C\"} does what?",
						"options": ["moves every item to shelf C", "moves the rope to shelf C", "makes a new rope"], "answer": 1, "why": "The path names the one record (the rope); the body says the one change."},
					{"word": "PATCH", "q": "Which SQL word is PATCH most like?",
						"options": ["SELECT", "INSERT INTO", "UPDATE"], "answer": 2, "why": "Both change a record that's already there. PATCH carries its WHERE in the path."},
					{"word": "PATCH", "q": "To change the fee on job 12, the path is...",
						"options": ["PATCH /jobs", "PATCH /jobs/12", "PATCH /fee/12"], "answer": 1, "why": "The service, then the one record: /jobs/12."},
					{"word": "true / false", "q": "Which switches the van's charger on?",
						"options": ["{\"charged\": \"true\"}", "{\"charged\": true}", "{\"charged\": on}"], "answer": 1, "why": "A switch's value is true or false with no quotes. In quotes it's just a word."},
					{"word": "true / false", "q": "{\"locked\": false} means...",
						"options": ["unlock it", "lock it", "it's not valid"], "answer": 0, "why": "false turns the switch off: not locked."},
					{"word": "true / false", "q": "The service answers 400 to {\"charged\": \"yes\"}. Why?",
						"options": ["yes should be true", "charged needs capitals", "the body needs a comma"], "answer": 0, "why": "A switch only takes true or false. \"yes\" is a word it doesn't know."},
				],
			},
			{
				"id": "api_post",
				"title": "Making something new",
				"when": "L5, carbon copy (work order)",
				"required": false,
				"words": ["POST", "body"],
				"lines": ["l5_huddle_post_1", "l5_huddle_post_2"],
				"pages": [
					"POST\n\nGET asks a service for what it has. POST asks it to make something new.\n\nPOST /jobs\n\nasks the job board to make a new job. The service answers 201 Created when it has, and tells you what it made.",
					"body\n\nA POST carries the new thing in a body: after the headers, an empty line, then the fields in braces.\n\n{\"client\": \"Nash\", \"town\": \"Ashford\", \"fee\": 80}\n\nEvery field the service wants, every time. Words in \"double quotes\", numbers without. Leave one out and it answers 400 and names the field.",
				],
				"quiz": [
					{"word": "POST", "q": "POST /jobs does what?",
						"options": ["lists the jobs", "makes a new job", "deletes a job"], "answer": 1, "why": "POST asks the service to make something new. GET is the one that lists."},
					{"word": "POST", "q": "The job board answers 201 to a POST. That means...",
						"options": ["it made the new job", "it refused", "it's thinking about it"], "answer": 0, "why": "201 Created: the service made what you asked for."},
					{"word": "POST", "q": "To see the jobs you already have, you use...",
						"options": ["POST /jobs", "GET /jobs", "NEW /jobs"], "answer": 1, "why": "GET looks, POST makes. Looking at what's there is a GET."},
					{"word": "body", "q": "Where does the body go?",
						"options": ["on the same line as POST", "after the headers and an empty line", "before POST"], "answer": 1, "why": "The request line, then its headers, then an empty line, then the body."},
					{"word": "body", "q": "Which body is right?",
						"options": ["{\"client\": \"Nash\", \"fee\": 80}", "{client: Nash, fee: 80}", "(\"client\" = \"Nash\", \"fee\" = 80)"], "answer": 0, "why": "Braces round the whole thing, each field's name in double quotes, a colon, then its value."},
					{"word": "body", "q": "You POST a job without its fee. The board answers 400 and names \"fee\". You...",
						"options": ["POST it again with the fee in", "POST it again without the fee", "try GET instead"], "answer": 0, "why": "400 means the request was wrong, and it said which field. Put the field in and send it again."},
				],
			},
			{
				"id": "api_check",
				"title": "Ask again",
				"when": "L5, escort procedure (lockup)",
				"required": false,
				"words": ["ask again"],
				"lines": ["l5_huddle_check_1", "l5_huddle_check_2"],
				"pages": [
					"ask again\n\n200 means the service took your change, just then. It doesn't promise it's still that way, or that the thing it's for has happened.\n\nAfter a PATCH or a POST, GET the record back and read it. If it says what you changed, it took. If it doesn't, something changed it back.",
				],
				"quiz": [
					{"word": "ask again", "q": "You PATCH the van's charger to true and get 200. Is it charging?",
						"options": ["yes, 200 says so", "GET it back and see", "no, 200 means it refused"], "answer": 1, "why": "200 means it heard you. Whether it took is in the record: GET it back."},
					{"word": "ask again", "q": "After POST /jobs answers 201, how do you see the new job?",
						"options": ["POST /jobs again", "GET /jobs", "wait for it to show"], "answer": 1, "why": "Ask for it back with a GET. Posting again makes a second one."},
					{"word": "ask again", "q": "You GET the record back and it's as it was before your change. Then...",
						"options": ["the change took", "something put it back", "GET is broken"], "answer": 1, "why": "The record is the truth. If it's unchanged, something undid it, whatever the number said."},
				],
			},
		],
	},
}


## A chapter by id, with its book's title added as `book`, or {} if there is none.
static func chapter(id: String) -> Dictionary:
	for book_id in BOOKS:
		var book: Dictionary = BOOKS[book_id]
		for ch in book.chapters:
			if ch.id == id:
				var out: Dictionary = ch.duplicate(true)
				out["book"] = book.title
				out["book_id"] = book_id
				out["number"] = book.chapters.find(ch)
				return out
	return {}


## The pages of chapter `ch`, by index, in the order a huddle reads them.
static func reading_order(ch: Dictionary) -> Array:
	var out := []
	for r in rounds(ch):
		out.append_array(r.pages)
	return out


## How chapter `ch` is tested: rounds of {pages, questions, ref}, each a list of
## indexes into its pages or quiz. One round per word when each page is a word's
## (it starts with the word's name); otherwise the chapter's own `rounds`, or for a
## review, every page and then every question.
static func rounds(ch: Dictionary) -> Array:
	var quiz: Array = ch.get("quiz", [])
	var pages: Array = ch.get("pages", [])
	var words: Array = ch.get("words", [])
	var out := []
	if ch.has("rounds"):
		for r in ch.rounds:
			var qs := []
			if r.has("word"):
				for i in quiz.size():
					if quiz[i].word == r.word:
						qs.append(i)
			out.append({"pages": r.get("pages", []), "questions": qs, "ref": r.get("ref", [])})
		return out
	var one_per_word := not words.is_empty() and words.size() == pages.size()
	for i in pages.size():
		one_per_word = one_per_word and String(pages[i]).begins_with(words[i] + "\n")
	if one_per_word:
		for i in words.size():
			var qs := []
			for j in quiz.size():
				if quiz[j].word == words[i]:
					qs.append(j)
			out.append({"pages": [i], "questions": qs, "ref": [i]})
		return out
	return [{"pages": range(pages.size()), "questions": range(quiz.size()), "ref": range(pages.size())}]


## Book `book_id`'s name as people say it ("Easy SQL"; its cover says EASY SQL).
static func book_name(book_id: String) -> String:
	var book: Dictionary = BOOKS.get(book_id, {})
	return book.get("name", book.get("title", ""))


## A book page as BBCode for a RichTextLabel `room` px wide. Indented lines are
## code: they show in the typewriter font, at `size` or smaller, so that the
## widest of them fits without wrapping (a table split over two lines can't be
## read; playtest 2026-10-22).
static func page_bbcode(text: String, room: float, size: int = CODE_SIZE) -> String:
	var lines := text.split("\n")
	var widest := 0.0
	for line in lines:
		if line.begins_with("    "):
			widest = maxf(widest, ThemeUtil.mono().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var fit := size
	if room > 0.0 and widest > room:
		fit = maxi(10, floori(size * room / widest))
	var out := []
	for line in lines:
		var safe := line.replace("[", "[lb]")
		out.append("[font_size=%d][code]%s[/code][/font_size]" % [fit, safe] if line.begins_with("    ") else safe)
	return "\n".join(out)


## The chapter ids of book `book_id`, in order.
static func book_chapter_ids(book_id: String) -> Array[String]:
	var ids: Array[String] = []
	for ch in BOOKS.get(book_id, {}).get("chapters", []):
		ids.append(ch.id)
	return ids


## Every chapter id, in book order.
static func chapter_ids() -> Array[String]:
	var ids: Array[String] = []
	for book_id in BOOKS:
		for ch in BOOKS[book_id].chapters:
			ids.append(ch.id)
	return ids


## A question's options in this run's order, and where the right one ended up:
## {options, answer}. Every machine gets the same order from the run seed.
static func shuffled(question: Dictionary, run_seed: int, salt: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d/%s" % [run_seed, salt])
	var order := range(question.options.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var options := []
	for i in order:
		options.append(question.options[i])
	return {"options": options, "answer": order.find(question.answer)}
