class_name Books
extends RefCounted
## The crew's beginner's books, chapter by chapter. A chapter is read in a huddle
## (see Huddle): one player reads its pages aloud, then the crew answers its quiz
## together. Each chapter brings at most three new words.
##
## DRAFT TEXT: Teaching and UX designs the chapters and quizzes, and Augustine
## approves every word before it ships. Book examples use the book's own
## `customers` table, never a table from the building.
##
## Chapter: {id, title, words, pages: [text], quiz: [{q, options, answer, why}]}
## `answer` indexes `options` as written here; the huddle shuffles the options
## per run, so the right one isn't always in the same place.

const BOOKS := {
	"easy_sql": {
		"title": "EASY SQL",
		"tagline": "Databases for people who'd rather be doing anything else",
		"chapters": [
			{
				"id": "easy_sql_0",
				"title": "Read this first",
				"words": ["table", "row", "column"],
				"pages": [
					"A database is a stack of tables.\n\nA table is a grid, like a spreadsheet. It has a name, and it holds facts about one kind of thing.",
					"Each ROW is one thing: one customer, one door, one scrap of paper.\nEach COLUMN is one fact about it: a name, a number, a date.\n\n    customers\n    id | name | city\n    ---+------+--------\n    1  | Ann  | Dayton\n    2  | Bo   | Akron\n\nThis table is called customers. It has 2 rows and 3 columns.",
					"To get anything out of a database, you ask it a question. The questions are written in SQL.\n\nChapter 1 is your first question.",
				],
				"quiz": [
					{"q": "In the customers table, what is one row?",
						"options": ["One customer", "Every customer's name", "The table's name"], "answer": 0,
						"why": "A row is one thing: here, one customer. The columns are the facts about it."},
					{"q": "How many columns does the customers table have?",
						"options": ["3", "2", "6"], "answer": 0,
						"why": "id, name and city: three columns, one for each fact."},
					{"q": "Which of these is a column?",
						"options": ["city", "Ann", "customers"], "answer": 0,
						"why": "city is a fact every row has. Ann is what one row holds in its name column, and customers is the table's name."},
				],
			},
			{
				"id": "easy_sql_1",
				"title": "Ask for a table",
				"words": ["SELECT", "FROM", ";"],
				"pages": [
					"Every question starts the same way:\n\n    SELECT columns FROM table;\n\nSELECT says which columns you want to see.\nFROM says which table to read them from.",
					"Don't know the columns yet? Use a star. * means every column:\n\n    SELECT * FROM customers;\n\nThat shows the whole customers table.",
					"Always end with a semicolon (;). It tells the database your question is finished.\n\nCapitals don't matter, but spelling does: the table's name has to be exact.",
				],
				"quiz": [
					{"q": "Which word says which table to read?",
						"options": ["FROM", "SELECT", ";"], "answer": 0,
						"why": "FROM names the table. SELECT names the columns, and ; ends the question."},
					{"q": "What does * mean after SELECT?",
						"options": ["Every column", "Every table", "Multiply"], "answer": 0,
						"why": "SELECT * shows every column of the table you name after FROM."},
					{"q": "Which question shows the whole customers table?",
						"options": ["SELECT * FROM customers;", "FROM customers SELECT *;", "SELECT customers FROM *;"], "answer": 0,
						"why": "SELECT comes first, then the columns, then FROM and the table, then the semicolon."},
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
