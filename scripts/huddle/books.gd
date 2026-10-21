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
##
## Chapter ids never change once shipped: profiles keep "chapter:<id>". The number
## shown is the chapter's place in the list, so a chapter added in the middle
## renumbers the rest by itself. New chapters get a word id (easy_sql_distinct).
##
## Chapter: {id, title, when, required, words, lines, pages: [text], quiz}
## `when` is where the huddle plays; `lines` are voice line ids heard over the
## garage radio, one as the book opens and one as it closes. Each quiz question:
## {word, q, options, answer, why}, three per word. `answer` indexes `options` as
## written here; the huddle shuffles them per run. `why` ("" until written) shows
## after the crew votes.

const BOOKS := {
	"easy_sql": {
		"title": "EASY SQL",
		"chapters": [
			{
				"id": "easy_sql_0",
				"title": "Read this first",
				"when": "garage, required, before the van",
				"required": true,
				"words": ["table", "row", "column"],
				"lines": [],
				"pages": [
					"A database is a stack of tables.\n\nA table is a grid, like a spreadsheet. It has a name, and it holds facts about one kind of thing.",
					"Each ROW is one thing: one job, one van.\nEach COLUMN is one fact about it: a name, a number, a date.\n\n    jobs\n    job_no | client         | town    | status | fee\n    -------+----------------+---------+--------+----\n    1      | Kemp Dental    | Ashford | done   | 80\n    2      | Bexley Library | Bexley  | open   | 120\n\nThis table is called jobs. It has 2 rows and 5 columns.",
					"To get anything out of a database, you ask it a question. The questions are written in SQL.\n\nChapter 1 is your first question.",
				],
				"quiz": [
					{"word": "table", "q": "Where does a table's name go in a query?",
						"options": ["after SELECT", "after FROM", "after the ;"], "answer": 1, "why": ""},
					{"word": "table", "q": "Which looks like a table name?",
						"options": ["van kit", "van_kit", "Van Kit!"], "answer": 1, "why": ""},
					{"word": "table", "q": "Where would you find a table's name in a building?",
						"options": ["on a label, card or screen nearby", "the book tells you", "you guess"], "answer": 0, "why": ""},
					{"word": "row", "q": "In jobs, one row is...",
						"options": ["one job", "one column", "the whole table"], "answer": 0, "why": ""},
					{"word": "row", "q": "SELECT * FROM jobs; with 5 jobs shows how many rows?",
						"options": ["1", "3", "5"], "answer": 2, "why": ""},
					{"word": "row", "q": "A row goes...",
						"options": ["across", "down", "nowhere"], "answer": 0, "why": ""},
					{"word": "column", "q": "A column goes...",
						"options": ["across", "down", "diagonally"], "answer": 1, "why": ""},
					{"word": "column", "q": "In jobs, which is a column?",
						"options": ["town", "job 14", "jobs"], "answer": 0, "why": ""},
					{"word": "column", "q": "Each column is...",
						"options": ["one whole thing", "one fact about every row", "the table's name"], "answer": 1, "why": ""},
				],
			},
			{
				"id": "easy_sql_1",
				"title": "Ask for a table",
				"when": "flashback at the front desk, required, peek",
				"required": true,
				"words": ["SELECT", "FROM", "; (semicolon)"],
				"lines": ["l0_huddle_select_1", "l0_huddle_select_2"],
				"pages": [
					"Every question starts the same way:\n\n    SELECT columns FROM table;\n\nSELECT says which columns you want to see.\nFROM says which table to read them from.",
					"Don't know the columns yet? Use a star. * means every column:\n\n    SELECT * FROM jobs;\n\nThat shows the whole jobs table.",
					"Always end with a semicolon (;). It tells the database your question is finished.\n\nCapitals don't matter, but spelling does: the table's name has to be exact.",
				],
				"quiz": [
					{"word": "SELECT", "q": "What does SELECT do?",
						"options": ["deletes rows", "shows you data", "saves your work"], "answer": 1, "why": ""},
					{"word": "SELECT", "q": "Which word starts a query?",
						"options": ["SELECT", "SHOW", "FIND"], "answer": 0, "why": ""},
					{"word": "SELECT", "q": "What does * mean after SELECT?",
						"options": ["every column", "every table", "multiply"], "answer": 0, "why": ""},
					{"word": "FROM", "q": "In SELECT qty FROM van_kit; which table is read?",
						"options": ["qty", "van_kit", "SELECT"], "answer": 1, "why": ""},
					{"word": "FROM", "q": "Where does FROM go?",
						"options": ["after the columns you want", "at the very start", "after the ;"], "answer": 0, "why": ""},
					{"word": "FROM", "q": "FROM jobs means...",
						"options": ["delete jobs", "look in the jobs table", "make a jobs table"], "answer": 1, "why": ""},
					{"word": "; (semicolon)", "q": "How does every query end?",
						"options": ["with a full stop .", "with a semicolon ;", "with nothing"], "answer": 1, "why": ""},
					{"word": "; (semicolon)", "q": "You typed SELECT item FROM van_kit and nothing happened. What's missing?",
						"options": ["the ;", "a second SELECT", "quotes"], "answer": 0, "why": ""},
					{"word": "; (semicolon)", "q": "Which is a whole query?",
						"options": ["SELECT town FROM jobs", "FROM jobs SELECT town;", "SELECT town FROM jobs;"], "answer": 2, "why": ""},
				],
			},
			{
				"id": "easy_sql_2",
				"title": "Putting things in order",
				"when": "L0, memo",
				"required": false,
				"words": ["ORDER BY", "smallest first"],
				"lines": [],
				"pages": [
					"ORDER BY\n\nRows come out in whatever order they were saved.\n\nAdd ORDER BY and a column name, before the ;, to sort them.",
					"smallest first\n\nORDER BY puts the smallest first: 1, 2, 3, or A, B, C, or earliest time.",
				],
				"quiz": [
					{"word": "ORDER BY", "q": "Where does ORDER BY go?",
						"options": ["before SELECT", "after the table name, before ;", "after the ;"], "answer": 1, "why": ""},
					{"word": "ORDER BY", "q": "SELECT * FROM jobs ORDER BY fee; sorts by...",
						"options": ["client", "fee", "job_no"], "answer": 1, "why": ""},
					{"word": "ORDER BY", "q": "Without ORDER BY, rows come out...",
						"options": ["sorted A to Z", "in saved order", "newest first"], "answer": 1, "why": ""},
					{"word": "smallest first", "q": "ORDER BY qty puts which first?",
						"options": ["the smallest qty", "the biggest qty", "random"], "answer": 0, "why": ""},
					{"word": "smallest first", "q": "ORDER BY town puts which town first?",
						"options": ["Zebulon", "Ashford", "the last one saved"], "answer": 1, "why": ""},
					{"word": "smallest first", "q": "ORDER BY job_no lists jobs...",
						"options": ["1, 2, 3...", "3, 2, 1...", "mixed"], "answer": 0, "why": ""},
				],
			},
			{
				"id": "easy_sql_3",
				"title": "Just the columns you need",
				"when": "L0, caller",
				"required": false,
				"words": ["column list", "comma", ".schema"],
				"lines": [],
				"pages": [
					"column list\n\nInstead of *, name the columns you want. The answer gets narrower and easier to read.",
					"comma\n\nPut a comma between column names. No comma after the last one.",
					".schema\n\nDon't know a table's columns? Type .schema and the table's name.\n\nDot-commands talk to the terminal, not the database: no ; needed.",
				],
				"quiz": [
					{"word": "column list", "q": "SELECT client, fee FROM jobs; shows...",
						"options": ["every column", "client and fee", "only fee"], "answer": 1, "why": ""},
					{"word": "column list", "q": "Why name columns instead of *?",
						"options": ["wide tables are hard to read", "* is broken", "it's faster to type"], "answer": 0, "why": ""},
					{"word": "column list", "q": "Which shows only item and shelf?",
						"options": ["SELECT * FROM van_kit;", "SELECT item, shelf FROM van_kit;", "SELECT van_kit FROM item, shelf;"], "answer": 1, "why": ""},
					{"word": "comma", "q": "Which is right?",
						"options": ["SELECT client, town FROM jobs;", "SELECT client town FROM jobs;", "SELECT client, town, FROM jobs;"], "answer": 0, "why": ""},
					{"word": "comma", "q": "Commas go...",
						"options": ["after every word", "between column names", "after FROM"], "answer": 1, "why": ""},
					{"word": "comma", "q": "SELECT item, FROM van_kit; is wrong because...",
						"options": ["item is wrong", "there's a comma after the last column", "it needs a *"], "answer": 1, "why": ""},
					{"word": ".schema", "q": ".schema van_kit shows...",
						"options": ["every row", "the column names", "the table's age"], "answer": 1, "why": ""},
					{"word": ".schema", "q": "Does .schema need a ; at the end?",
						"options": ["yes", "no", "only on Fridays"], "answer": 1, "why": ""},
					{"word": ".schema", "q": "You need a column's exact name. You type...",
						"options": ["SELECT columns;", ".schema and the table name", "ORDER BY"], "answer": 1, "why": ""},
				],
			},
			{
				"id": "easy_sql_4",
				"title": "Newest first",
				"when": "L0, last_visitor, optional",
				"required": false,
				"words": ["DESC", "LIMIT"],
				"lines": [],
				"pages": [
					"DESC\n\nAdd DESC after ORDER BY's column to flip it: biggest first, latest first.",
					"LIMIT\n\nLIMIT and a number, at the very end, keeps only that many rows from the top.\n\nWith ORDER BY and DESC first, LIMIT 3 gives you the newest three.",
				],
				"quiz": [
					{"word": "DESC", "q": "ORDER BY fee DESC puts which first?",
						"options": ["the smallest fee", "the biggest fee", "the oldest job"], "answer": 1, "why": ""},
					{"word": "DESC", "q": "Where does DESC go?",
						"options": ["before ORDER BY", "after the column name in ORDER BY", "after the ;"], "answer": 1, "why": ""},
					{"word": "DESC", "q": "To see the latest times first you add...",
						"options": ["DESC", "LAST", "nothing"], "answer": 0, "why": ""},
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
				"lines": [],
				"pages": [
					"WHERE\n\nWHERE keeps only the rows that match. It goes after the table name.",
					"= (equals)\n\n= means 'is exactly'. Column on the left, value on the right.",
					"'quotes'\n\nWords go in 'single quotes'. Numbers don't.",
				],
				"quiz": [
					{"word": "WHERE", "q": "SELECT * FROM jobs WHERE status = 'open'; shows...",
						"options": ["every job", "only open jobs", "no jobs"], "answer": 1, "why": ""},
					{"word": "WHERE", "q": "Where does WHERE go?",
						"options": ["after the table name", "before SELECT", "after the ;"], "answer": 0, "why": ""},
					{"word": "WHERE", "q": "WHERE is for...",
						"options": ["sorting", "filtering", "naming columns"], "answer": 1, "why": ""},
					{"word": "= (equals)", "q": "WHERE town = 'Ashford' keeps rows where town is...",
						"options": ["exactly Ashford", "near Ashford", "not Ashford"], "answer": 0, "why": ""},
					{"word": "= (equals)", "q": "Which is the right way round?",
						"options": ["WHERE qty = 4", "WHERE 4 qty =", "WHERE = qty 4"], "answer": 0, "why": ""},
					{"word": "= (equals)", "q": "WHERE shelf = 'B' finds...",
						"options": ["shelves A and B", "only shelf B", "every shelf"], "answer": 1, "why": ""},
					{"word": "'quotes'", "q": "Which is right?",
						"options": ["WHERE status = open", "WHERE status = 'open'", "WHERE 'status' = open"], "answer": 1, "why": ""},
					{"word": "'quotes'", "q": "Which needs quotes?",
						"options": ["'done'", "12", "neither"], "answer": 0, "why": ""},
					{"word": "'quotes'", "q": "WHERE qty = '4' or WHERE qty = 4 for a number?",
						"options": ["'4'", "4", "\"four\""], "answer": 1, "why": ""},
				],
			},
			{
				"id": "easy_sql_6",
				"title": "Both must be true",
				"when": "L1, controller",
				"required": false,
				"words": ["AND"],
				"lines": [],
				"pages": [
					"AND\n\nAND joins two conditions. A row stays only if both are true.",
				],
				"quiz": [
					{"word": "AND", "q": "WHERE status = 'open' AND town = 'Ashford' keeps...",
						"options": ["all open jobs", "open jobs in Ashford", "every Ashford job"], "answer": 1, "why": ""},
					{"word": "AND", "q": "With AND, a row stays when...",
						"options": ["both are true", "either is true", "neither is true"], "answer": 0, "why": ""},
					{"word": "AND", "q": "AND goes...",
						"options": ["before WHERE", "between two conditions", "after the ;"], "answer": 1, "why": ""},
				],
			},
			{
				"id": "easy_sql_7",
				"title": "More than, less than",
				"when": "L1, hot_rack, optional",
				"required": false,
				"words": ["> (more than)", "< (less than)", "numbers"],
				"lines": [],
				"pages": [
					"> (more than)\n\n> keeps rows where the column is more than a number.",
					"< (less than)\n\n< is the other way: less than.",
					"numbers\n\nNumbers go in without quotes, so the database compares them as numbers.",
				],
				"quiz": [
					{"word": "> (more than)", "q": "WHERE fee > 100 keeps fees of...",
						"options": ["100 and under", "over 100", "exactly 100"], "answer": 1, "why": ""},
					{"word": "> (more than)", "q": "Is 100 > 100 true?",
						"options": ["yes", "no", "sometimes"], "answer": 1, "why": ""},
					{"word": "> (more than)", "q": "Which finds items with more than 10 in stock?",
						"options": ["WHERE qty > 10", "WHERE qty < 10", "WHERE 10 qty >"], "answer": 0, "why": ""},
					{"word": "< (less than)", "q": "WHERE qty < 2 keeps...",
						"options": ["items with 0 or 1 left", "items with 2 left", "items with more than 2"], "answer": 0, "why": ""},
					{"word": "< (less than)", "q": "The open side of < and > faces...",
						"options": ["the smaller number", "the bigger number", "the column"], "answer": 1, "why": ""},
					{"word": "< (less than)", "q": "To find cheap jobs under 50 you type...",
						"options": ["WHERE fee > 50", "WHERE fee < 50", "WHERE fee = < 50"], "answer": 1, "why": ""},
					{"word": "numbers", "q": "Which is right?",
						"options": ["WHERE fee > 40", "WHERE fee > '40'", "WHERE fee > forty"], "answer": 0, "why": ""},
					{"word": "numbers", "q": "Why no quotes on numbers?",
						"options": ["quotes are banned", "so they compare as numbers", "to save typing"], "answer": 1, "why": ""},
					{"word": "numbers", "q": "Temperatures like 38 are...",
						"options": ["numbers", "words", "dates"], "answer": 0, "why": ""},
				],
			},
			{
				"id": "easy_sql_8",
				"title": "Either one will do",
				"when": "L1, dark_room, PROPOSED optional",
				"required": false,
				"words": ["OR"],
				"lines": [],
				"pages": [
					"OR\n\nOR keeps a row if either condition is true.",
				],
				"quiz": [
					{"word": "OR", "q": "WHERE status = 'open' OR status = 'unpaid' keeps...",
						"options": ["only open jobs", "open and unpaid jobs", "no jobs"], "answer": 1, "why": ""},
					{"word": "OR", "q": "With OR, a row stays when...",
						"options": ["both are true", "at least one is true", "neither is true"], "answer": 1, "why": ""},
					{"word": "OR", "q": "AND or OR to find jobs in Ashford or Bexley?",
						"options": ["AND", "OR", "neither"], "answer": 1, "why": ""},
				],
			},
			{
				"id": "easy_sql_count",
				"title": "How many?",
				"when": "L1, the reset sign-off form, count",
				"required": false,
				"words": ["COUNT(*)"],
				"lines": [],
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
				"lines": [],
				"pages": [
					"Same tools as the server floor. Breathe.",
				],
				"quiz": [
					{"word": "", "q": "To keep rows in one zone that are also faulted you use...",
						"options": ["OR", "AND", "ORDER BY"], "answer": 1, "why": ""},
					{"word": "", "q": "To read a log in time order you add...",
						"options": ["ORDER BY and the time column", "DESC only", "WHERE time"], "answer": 0, "why": ""},
					{"word": "", "q": "A word value like fault goes in...",
						"options": ["no quotes", "'single quotes'", "brackets"], "answer": 1, "why": ""},
				],
			},
			{
				"id": "easy_sql_10",
				"title": "Asking a server",
				"when": "L2 camera booth, cameras",
				"required": false,
				"words": ["GET", "path", "JSON"],
				"lines": [],
				"pages": [
					"GET\n\nSome systems answer web requests, not SQL. GET asks for data.\n\nNo SELECT, no ;. Just GET and a path.",
					"path\n\nThe path after GET says what you want, starting with /.",
					"JSON\n\nAnswers come back as JSON. { } holds one thing's fields; [ ] is a list of them.\n\nEach field is a name, a colon, and a value: \"qty\": 4.",
				],
				"quiz": [
					{"word": "GET", "q": "GET /van does what?",
						"options": ["asks for data about the van", "deletes the van", "runs SQL"], "answer": 0, "why": ""},
					{"word": "GET", "q": "Does a GET need a ; at the end?",
						"options": ["yes", "no", "two of them"], "answer": 1, "why": ""},
					{"word": "GET", "q": "Which is a request?",
						"options": ["SELECT /jobs;", "GET /jobs", "GET jobs;"], "answer": 1, "why": ""},
					{"word": "path", "q": "In GET /jobs, the path is...",
						"options": ["GET", "/jobs", "jobs;"], "answer": 1, "why": ""},
					{"word": "path", "q": "Paths start with...",
						"options": ["/", ";", "*"], "answer": 0, "why": ""},
					{"word": "path", "q": "GET /van_kit asks for...",
						"options": ["the jobs", "the van kit", "everything"], "answer": 1, "why": ""},
					{"word": "JSON", "q": "In JSON, [ ] means...",
						"options": ["one field", "a list", "an error"], "answer": 1, "why": ""},
					{"word": "JSON", "q": "\"status\": \"open\" says...",
						"options": ["status is open", "open the status", "nothing"], "answer": 0, "why": ""},
					{"word": "JSON", "q": "{ } holds...",
						"options": ["one thing's fields", "a list of things", "a query"], "answer": 0, "why": ""},
				],
			},
			{
				"id": "easy_sql_11",
				"title": "Half a name",
				"when": "L2 booth, pike",
				"required": false,
				"words": ["LIKE", "% (percent)"],
				"lines": [],
				"pages": [
					"LIKE\n\nLIKE matches a pattern instead of an exact value.",
					"% (percent)\n\n% means 'any letters, or none'. 'Ash%' matches Ash, Ashford, Ashley.",
				],
				"quiz": [
					{"word": "LIKE", "q": "LIKE is for...",
						"options": ["exact matches", "patterns", "sorting"], "answer": 1, "why": ""},
					{"word": "LIKE", "q": "Which is right?",
						"options": ["WHERE client LIKE 'Ash%'", "WHERE LIKE client 'Ash%'", "WHERE client = LIKE 'Ash%'"], "answer": 0, "why": ""},
					{"word": "LIKE", "q": "You can only read the start of a name. You use...",
						"options": ["=", "LIKE", "ORDER BY"], "answer": 1, "why": ""},
					{"word": "% (percent)", "q": "'Bex%' matches...",
						"options": ["Bexley", "Abex", "Bonex"], "answer": 0, "why": ""},
					{"word": "% (percent)", "q": "Where does % go to match names starting with Mac?",
						"options": ["'%Mac'", "'Mac%'", "'M%ac'"], "answer": 1, "why": ""},
					{"word": "% (percent)", "q": "Does 'Ash%' match plain \"Ash\"?",
						"options": ["yes", "no", "only in capitals"], "answer": 0, "why": ""},
				],
			},
			{
				"id": "easy_sql_12",
				"title": "One answer feeds the next",
				"when": "L2, har",
				"required": false,
				"words": [],
				"lines": [],
				"pages": [
					"Sometimes the answer isn't the answer. It's what you need for the next query.",
				],
				"quiz": [
					{"word": "", "q": "A first query gives you an id. Next you...",
						"options": ["use it in a WHERE", "start over", "type it after the ;"], "answer": 0, "why": ""},
					{"word": "", "q": "A first query told you job 14 is the one. To get its client you type...",
						"options": ["SELECT 14;", "SELECT client FROM jobs WHERE job_no = 14;", "ORDER BY 14"], "answer": 1, "why": ""},
					{"word": "", "q": "A log sorted by time shows the last person through a door at the...",
						"options": ["top", "bottom", "middle"], "answer": 1, "why": ""},
				],
			},
			{
				"id": "easy_sql_13",
				"title": "One door's record",
				"when": "L2 stairwell panel, door",
				"required": false,
				"words": ["id in the path"],
				"lines": [],
				"pages": [
					"id in the path\n\nAdd an id to the path to ask about one thing: GET /jobs/14.",
				],
				"quiz": [
					{"word": "id in the path", "q": "GET /jobs/14 asks for...",
						"options": ["all jobs", "job 14 only", "14 jobs"], "answer": 1, "why": ""},
					{"word": "id in the path", "q": "To ask about one door you need its...",
						"options": ["id", "colour", "zone"], "answer": 0, "why": ""},
					{"word": "id in the path", "q": "Where does the id go?",
						"options": ["before GET", "at the end of the path", "in quotes after it"], "answer": 1, "why": ""},
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
