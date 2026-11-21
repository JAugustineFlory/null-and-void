class_name PieceKind
## The four kinds of piece a query is made of, each with one color and one shape
## cue, used the same way everywhere (puzzle-flow spec, section 4): the query with
## blanks on screen, the slide-up, the typing line and SYSOP's hints. The cue is
## there for players who can't tell some of the colors apart:
## - keyword (SELECT, WHERE, DESC, >): bold
## - table (staff_directory): on a box
## - column (extension): underlined
## - value ('fault', 40, Harold Mercer): italic

enum { KEYWORD, TABLE, COLUMN, VALUE }

const NAMES := ["keyword", "table", "column", "value"]
## On the dark screen: a terminal, the HUD.
const COLORS := [Color("#ffcc59"), Color("#6fb4ff"), Color("#ff8fc8"), Color("#7fe0c4")]
## A blank still to find: its kind's color, faded.
const MISSING_ALPHA := 0.55
## The box behind a table's name.
const TABLE_BOX := Color(0.43, 0.7, 1.0, 0.18)

## The words a query is built from (the terminal's own list, plus the request
## verbs and the script words the later floors use).
const WORDS := ["SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "ORDER", "BY", "ASC", "DESC", "LIMIT", "LIKE",
	"IN", "IS", "NULL", "AS", "DISTINCT", "COUNT", "GROUP", "HAVING", "JOIN", "ON", "UPDATE", "SET", "INSERT",
	"INTO", "VALUES", "DELETE", "BEGIN", "COMMIT", "ROLLBACK", "GET", "POST", "PATCH", "PUT", "SUM", "AVG",
	"MIN", "MAX", "BETWEEN"]
const SIGNS := ["=", "<", ">", "<=", ">=", "!=", "<>", "*"]


static func color(kind: int) -> Color:
	return COLORS[clampi(kind, 0, COLORS.size() - 1)]


static func hex(kind: int, missing := false) -> String:
	var c := color(kind)
	if missing:
		c.a = MISSING_ALPHA
	return "#" + c.to_html(missing)


## What kind piece `p` is (Game.set_pieces' dicts): its own `kind` if it says,
## else read off its blank's name (enter_table_name), its table, or its value.
static func of_piece(p: Dictionary) -> int:
	var named := NAMES.find(str(p.get("kind", "")))
	if named >= 0:
		return named
	var blank := str(p.get("blank", ""))
	if blank.begins_with("enter_"):
		return of_blank(blank)
	var value := str(p.get("value", ""))
	var seen := str(p.get("seen_in", ""))
	if seen != "":
		return TABLE if value == seen else COLUMN
	return of_value(value)


## A hint's own blank (enter_table_name, enter_column_name, enter_zone): the
## kind of thing it wants.
static func of_blank(blank: String) -> int:
	if blank.contains("table"):
		return TABLE
	if blank.contains("column"):
		return COLUMN
	return VALUE


## A piece's value on its own: a query word or sign (ORDER BY, DESC, LIMIT 5, >)
## is a keyword; anything else is a value.
static func of_value(value: String) -> int:
	var v := value.strip_edges()
	if v in SIGNS:
		return KEYWORD
	var first := v.split(" ", false)[0] if v != "" else ""
	return KEYWORD if first != "" and first == first.to_upper() and first in WORDS else VALUE


## `text` in `kind`'s color and shape cue, as BBCode. `missing`: a blank still to
## find, faded. The text is escaped here.
static func bbcode(text: String, kind: int, missing := false) -> String:
	var t := "[color=%s]%s[/color]" % [hex(kind, missing), text.replace("[", "[lb]")]
	match kind:
		KEYWORD:
			return "[b]%s[/b]" % t
		TABLE:
			return "[bgcolor=#%s]%s[/bgcolor]" % [TABLE_BOX.to_html(true), t]
		COLUMN:
			return "[u]%s[/u]" % t
	return "[i]%s[/i]" % t


## Case `case`'s query (Game.case_info's dict) as BBCode, word for word the
## same text as Game.case_query: each piece in its kind's color (faded while
## it's still a blank), the query's own words as keywords, and a hint's blank
## (enter_column_name) in the color of what it wants. `fresh`: a piece id just
## written in, drawn brighter.
static func query_bbcode(c: Dictionary, missing_text: String, fresh := "") -> String:
	var q: String = c.get("query", "")
	var assemble: bool = c.get("assemble", true)
	var out := ""
	var at := 0
	for m in RegEx.create_from_string("\\{([a-z_]+)\\}").search_all(q):
		out += words_bbcode(q.substr(at, m.get_start() - at))
		var piece := {}
		for p in c.get("pieces", []):
			if p.id == m.get_string(1):
				piece = p
		if piece.is_empty():
			out += words_bbcode(m.get_string())
		else:
			var shown: bool = piece.get("found", false) and assemble
			var text := str(piece.value) if shown else str(piece.get("blank", missing_text))
			var b := bbcode(text, of_piece(piece), not shown)
			out += ("[outline_size=4][outline_color=#ffffff40]%s[/outline_color][/outline_size]" % b) if piece.id == fresh and shown else b
		at = m.get_end()
	return out + words_bbcode(q.substr(at))


## A query's fixed text as BBCode: its words as keywords, a hint's own blank
## (enter_x) in the color of what it wants, faded, and the rest as it is.
static func words_bbcode(text: String) -> String:
	var out := ""
	var at := 0
	for m in RegEx.create_from_string("\\benter_[a-z_]+\\b|\\b[A-Z]+\\b").search_all(text):
		out += text.substr(at, m.get_start() - at).replace("[", "[lb]")
		var w := m.get_string()
		if w.begins_with("enter_"):
			out += bbcode(w, of_blank(w), true)
		elif w in WORDS:
			out += bbcode(w, KEYWORD)
		else:
			out += w
		at = m.get_end()
	return out + text.substr(at).replace("[", "[lb]")
