class_name StickyNotes
extends RefCounted
## Every sticky note in the building. Each one teaches one piece of SQL: what it does,
## the shape to type, and a worked example on some other table. An example is never a
## puzzle's answer; the notes add to the .hint tiers, they don't replace them.

const NOTES := {
	"select_from": {
		"title": "SELECT and FROM",
		"label": "SELECT *\nFROM ...",
		"what": "SELECT picks which columns to show. * means every column. FROM names the table to read them from.",
		"syntax": "SELECT columns FROM table;",
		"example": "SELECT * FROM staff_directory;\nSELECT name, title FROM staff_directory;",
		"tip": "Swap in the table you want. End with ; and press Enter.",
	},
	"order_by": {
		"title": "ORDER BY",
		"label": "ORDER BY\nsorts!",
		"what": "ORDER BY sorts the rows by one column, smallest first. Add DESC after the column for biggest first.",
		"syntax": "SELECT columns FROM table ORDER BY column;",
		"example": "SELECT * FROM staff_directory ORDER BY extension;\nSELECT * FROM staff_directory ORDER BY extension DESC;",
		"tip": "ORDER BY goes at the end, just before the ;. Use a column from your own table.",
	},
	"where_and": {
		"title": "WHERE and AND",
		"label": "WHERE ...\nAND ...",
		"what": "WHERE keeps only the rows where a condition is true. AND adds a second condition: a row must pass both.",
		"syntax": "SELECT columns FROM table WHERE column = value AND column = value;",
		"example": "SELECT * FROM doors WHERE zone = 'A';\nSELECT * FROM doors WHERE zone = 'A' AND locked = 1;",
		"tip": "Text goes in 'single quotes'. Numbers don't.",
	},
}


static func get_note(id: String) -> Dictionary:
	return NOTES.get(id, {})
