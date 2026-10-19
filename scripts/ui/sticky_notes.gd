class_name StickyNotes
extends RefCounted
## Every sticky note in the building. Each one teaches one piece of SQL: what it does,
## the shape to type, and a worked example on some other table. An example is never a
## puzzle's answer; the notes add to the .hint tiers, they don't replace them.
## The paper is small: at most 4 lines of syntax and example, 30 characters each.

const NOTES := {
	"select_from": {
		"title": "SELECT and FROM",
		"label": "SELECT * FROM",
		"what": "SELECT picks which columns to show. * means every column. FROM names the table to read them from.",
		"syntax": "SELECT columns FROM table;",
		"example": "SELECT * FROM lights;\nSELECT room, status\n  FROM lights;",
		"tip": "Swap in the table you want. End with ; and press Enter.",
	},
	"order_by": {
		"title": "ORDER BY",
		"label": "ORDER BY",
		"what": "ORDER BY sorts the rows by one column, smallest first. Add DESC after the column for biggest first.",
		"syntax": "SELECT ... ORDER BY column;",
		"example": "SELECT * FROM lights\n  ORDER BY room DESC;",
		"tip": "ORDER BY goes at the end, just before the ;. Use a column from your own table.",
	},
	"where_and": {
		"title": "WHERE and AND",
		"label": "WHERE AND",
		"what": "WHERE keeps only the rows where a condition is true. AND adds a second condition: a row must pass both.",
		"syntax": "SELECT ... WHERE col = value;",
		"example": "SELECT * FROM doors\n  WHERE zone = 'A'\n  AND locked = 1;",
		"tip": "Text goes in 'single quotes'. Numbers don't.",
	},
	"like": {
		"title": "LIKE patterns",
		"label": "LIKE 'Dale%'",
		"what": "LIKE keeps rows whose text matches a pattern. % stands for any letters, or none.",
		"syntax": "WHERE col LIKE 'Ab%';",
		"example": "SELECT * FROM staff_directory\n  WHERE name LIKE 'Dale%';",
		"tip": "Keep the 'single quotes'. 'Ab%' starts with Ab; '%ab%' has ab anywhere.",
	},
}


static func get_note(id: String) -> Dictionary:
	return NOTES.get(id, {})
