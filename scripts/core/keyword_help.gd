class_name KeywordHelp
extends RefCounted
## The terminal's next-word buttons (plan/teaching/keyword-buttons.md): like a
## code editor's autocomplete, they offer only the words that can come next in
## what's typed, drawn only from what this player has found:
##   - SQL words, once their Easy SQL chapter is in the book (or their reference
##     was read: IS NULL on Mercer's card),
##   - tables on the Tables page (or a table piece on the case board),
##   - a table's columns, once .schema or SELECT * has shown them,
##   - values found as case pieces ('fault', a zone letter).
## Every valid word found is offered, never only the one that solves the puzzle.
## Typing is never blocked: the buttons only ever write words.
##
## On a keyboard (Easy), a SQL word's button comes off once it's been used USES
## times, at the next calm moment; on a pad the buttons never come off. Counts
## are kept on the player's own profile (Profile.word_uses).

## Uses before a word's button comes off (Augustine, 2026-11-07).
const USES := 3
## The notebook's tabs at a terminal: Augustine's three (2026-11-07 01:45Z), then
## the values found on the case board.
const TABS := ["Tables", "Columns", "Commands", "Found"]
## Which tab opens by itself for the words that can come next: the first of
## these with anything in it.
const TAB_PRIORITY := ["Columns", "Tables", "Found", "Commands"]

## The words each chapter teaches, as the buttons write them. "' '", "( )" and
## "{ }" write a pair with the cursor between.
const CHAPTER_TOKENS := {
	"easy_sql_1": ["SELECT", "*", "FROM", ";"],
	"easy_sql_2": ["ORDER BY"],
	"easy_sql_3": [",", ".schema", ".tables"],
	"easy_sql_4": ["DESC", "LIMIT"],
	"easy_sql_5": ["WHERE", "=", "' '"],
	"easy_sql_6": ["AND"],
	"easy_sql_7": [">", "<"],
	"easy_sql_8": ["OR"],
	"easy_sql_count": ["COUNT(*)"],
	"easy_sql_10": ["GET", "/"],
	"easy_sql_11": ["LIKE", "%"],
	"easy_sql_distinct": ["DISTINCT"],
	"easy_sql_group_by": ["GROUP BY"],
	"easy_sql_update": ["UPDATE", "SET"],
	"easy_sql_insert": ["INSERT INTO", "VALUES", "( )"],
	"api_keys": ["X-Api-Key:"],
	"api_patch": ["PATCH", "true", "false", "{ }"],
	"api_post": ["POST"],
}
## Words learned off a paper instead of a chapter (Game.learn_word).
const PAPER_TOKENS := ["IS NULL"]
## The Commands tab's order: the order a query reads.
const ORDER := ["SELECT", "UPDATE", "INSERT INTO", "GET", "POST", "PATCH", ".tables", ".schema",
	"DISTINCT", "*", "COUNT(*)", ",", ")", "FROM", "SET", "VALUES", "( )", "WHERE", "=", ">", "<", "LIKE",
	"IS NULL", "' '", "%", "AND", "OR", "GROUP BY", "ORDER BY", "DESC", "LIMIT", "/", "X-Api-Key:",
	"{ }", "true", "false", ";"]
const STARTERS := ["SELECT", "UPDATE", "INSERT INTO", "GET", "POST", "PATCH", ".tables", ".schema"]
const METHODS := ["GET", "POST", "PATCH"]
## Words made of two (ORDER BY): the tokenizer joins them into one.
const PHRASES := [["ORDER", "BY"], ["GROUP", "BY"], ["INSERT", "INTO"], ["IS", "NULL"]]

## The "Terminal help" setting: "easy" (buttons) or "normal" (none on a keyboard;
## on a pad the buttons stay and only the case's code line goes). Saved for next
## time in PadInput's controls file.
static var mode := "easy"
static var _loaded := false
## Off, no query counts toward a button coming off (the test suite turns it off,
## so one test's queries never take a word off in another's).
static var counting := true


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PadInput.SETTINGS) != OK:
		return
	var m := str(cfg.get_value("terminal", "help", mode))
	mode = m if m in ["easy", "normal"] else "easy"


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PadInput.SETTINGS)
	cfg.set_value("terminal", "help", mode)
	cfg.save(PadInput.SETTINGS)


## Every Easy SQL word, for "Look, No Buttons".
static func easy_sql_tokens() -> Array:
	var out := []
	for id in CHAPTER_TOKENS:
		if str(id).begins_with("easy_sql"):
			for t in CHAPTER_TOKENS[id]:
				if not out.has(t):
					out.append(t)
	return out


## Is `word` one the buttons count uses of (a word a chapter or paper teaches)?
static func is_counted(word: String) -> bool:
	if PAPER_TOKENS.has(word):
		return true
	for id in CHAPTER_TOKENS:
		if CHAPTER_TOKENS[id].has(word):
			return true
	return false


# --- What this player has found ------------------------------------------------

## The SQL words found so far: their chapters are in the book this run, or they
## were learned off a paper (Game.learned_words). In ORDER.
static func found_commands(game: Node) -> Array:
	var have := {}
	for id in game.book_chapters:
		for t in CHAPTER_TOKENS.get(id, []):
			have[t] = true
	var learned = game.get("learned_words")
	if learned is Array:
		for t in learned:
			have[t] = true
	return ORDER.filter(func(t): return have.has(t))


## The tables found: on the Tables page, or a table piece found on a case board.
## A to Z.
static func found_tables(game: Node) -> Array:
	var have := {}
	for t in game.notebook_tables:
		have[str(t)] = true
	for c in game.notebook_cases:
		if not c.get("open", false):
			continue
		for p in c.get("pieces", []):
			if p.get("found", false) and str(p.get("seen_in", "")) != "" and str(p.get("value", "")) == str(p.seen_in):
				have[str(p.value)] = true
	var out := have.keys()
	out.sort()
	return out


## The columns found, by table: only once .schema or SELECT * has shown them.
## Each table's columns A to Z.
static func found_columns(game: Node) -> Dictionary:
	var out := {}
	for t in game.notebook_tables:
		var cols: Array = game.notebook_tables[t].duplicate()
		if cols.is_empty():
			continue
		cols.sort()
		out[str(t)] = cols
	return out


## Values found as pieces on the open cases' boards, newest case first, as they're
## typed in a query ('fault' quoted, 45 as it is). Not tables, columns or SQL words.
static func found_values(game: Node) -> Array:
	var out := []
	var tables := found_tables(game)
	var cols := {}
	for t in game.notebook_tables:
		for c in game.notebook_tables[t]:
			cols[str(c)] = true
	for c in game.notebook_cases:
		if not c.get("open", false) or c.get("solved", false):
			continue
		for p in c.get("pieces", []):
			var v := str(p.get("value", ""))
			if not p.get("found", false) or v == "" or tables.has(v) or cols.has(v) or ORDER.has(v.to_upper()) or ORDER.has(v):
				continue
			var shown := v if v.is_valid_float() else "'%s'" % v.replace("'", "''")
			if not out.has(shown):
				out.append(shown)
	return out


## Everything found, as next_words() takes it.
static func found(game: Node) -> Dictionary:
	return {"commands": found_commands(game), "tables": found_tables(game),
		"columns": found_columns(game), "values": found_values(game)}


# --- What can come next -----------------------------------------------------------

## The words that can come next after `typed` (the text before the cursor), from
## `have` (found()). Returns {"Commands": [..], "Tables": [..], "Columns":
## [[table, [cols]]], "Found": [..], "replace": n}: `replace` is how many
## characters before the cursor a picked word writes over (a word half typed).
static func next_words(typed: String, have: Dictionary) -> Dictionary:
	var toks := tokens(typed)
	var partial := ""
	if not toks.is_empty() and typed != "" and not typed[typed.length() - 1] in [" ", "\n", "\t"]:
		var last: String = toks[-1]
		if _word_like(last):
			partial = last
	if partial != "":
		var before := _offer(_state(toks.slice(0, toks.size() - 1)), have)
		var narrowed := _narrow(before, partial)
		if _count(narrowed) > 0:
			narrowed["replace"] = partial.length()
			return narrowed
	var out := _offer(_state(toks), have)
	out["replace"] = 0
	return out


## Only the offered words that start with `prefix` (any case) and aren't it.
static func _narrow(offer: Dictionary, prefix: String) -> Dictionary:
	var p := prefix.to_lower()
	var keep := func(w: String) -> bool: return w.to_lower().begins_with(p) and w.to_lower() != p
	var out := {"Commands": offer.Commands.filter(keep), "Tables": offer.Tables.filter(keep), "Found": offer.Found.filter(keep), "Columns": []}
	for g in offer.Columns:
		var cols: Array = g[1].filter(keep)
		if not cols.is_empty():
			out.Columns.append([g[0], cols])
	return out


static func _count(offer: Dictionary) -> int:
	var n: int = offer.Commands.size() + offer.Tables.size() + offer.Found.size()
	for g in offer.Columns:
		n += g[1].size()
	return n


## Could this token be half of a longer word (a name, a keyword, a quoted value)?
static func _word_like(tok: String) -> bool:
	return tok.begins_with("'") or tok.begins_with(".") or tok.begins_with("/") or RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_\\-]*:?$").search(tok) != null


## The query's words: names, keywords (ORDER BY as one), numbers, quoted values
## (an unclosed one too), paths, and each sign as its own.
static func tokens(text: String) -> Array:
	var raw := []
	var re := RegEx.create_from_string("'(?:[^']|'')*'?|\\.[A-Za-z_]+|/[A-Za-z0-9_/\\-]*|[A-Za-z_][A-Za-z0-9_\\-]*:?|\\d+(?:\\.\\d+)?|<=|>=|!=|<>|\\S")
	for m in re.search_all(text):
		raw.append(m.get_string())
	var out := []
	var i := 0
	while i < raw.size():
		var w: String = raw[i]
		var joined := false
		for ph in PHRASES:
			if i + 1 < raw.size() and w.to_upper() == ph[0] and str(raw[i + 1]).to_upper() == ph[1]:
				out.append(ph[0] + " " + ph[1])
				i += 2
				joined = true
				break
		if joined:
			continue
		if w.to_upper() == "COUNT" and i + 3 < raw.size() and raw[i + 1] == "(" and raw[i + 2] == "*" and raw[i + 3] == ")":
			out.append("COUNT(*)")
			i += 4
			continue
		out.append(w)
		i += 1
	return out


## Where `toks` leaves the statement: {at, table, method}.
static func _state(toks: Array) -> Dictionary:
	var s := {"at": "start", "table": "", "method": ""}
	for tok in toks:
		var u := str(tok).to_upper()
		var at: String = s.at
		if u == ";":
			s.at = "done"
			continue
		match at:
			"start":
				if u == "SELECT":
					s.at = "select"
				elif u == ".SCHEMA":
					s.at = "schema"
				elif u == ".TABLES":
					s.at = "done"
				elif u == "UPDATE":
					s.at = "update_table"
				elif u == "INSERT INTO":
					s.at = "insert_table"
				elif u in METHODS:
					s.at = "path"
					s.method = u
				else:
					s.at = "lost"
			"schema":
				s.at = "done"
			"select", "select_more":
				if u == "DISTINCT" and at == "select":
					s.at = "select_distinct"
				elif u == "FROM":
					s.at = "lost"
				else:
					s.at = "select_item"
			"select_distinct":
				s.at = "select_item"
			"select_item":
				if u == ",":
					s.at = "select_more"
				elif u == "FROM":
					s.at = "from"
				else:
					s.at = "lost"
			"from":
				s.table = str(tok)
				s.at = "after_table"
			"after_table", "after_cond", "after_group", "after_order", "after_desc":
				if u in ["WHERE", "AND", "OR"] and (at != "after_table" or u == "WHERE") and not (at in ["after_group", "after_order", "after_desc"]):
					s.at = "cond_col"
				elif u == "GROUP BY" and at in ["after_table", "after_cond"]:
					s.at = "group_col"
				elif u == "ORDER BY" and at in ["after_table", "after_cond", "after_group"]:
					s.at = "order_col"
				elif u == "DESC" and at == "after_order":
					s.at = "after_desc"
				elif u == "," and at in ["after_order", "after_desc"]:
					s.at = "order_col"
				elif u == "LIMIT":
					s.at = "limit"
				else:
					s.at = "lost"
			"cond_col":
				s.at = "cond_op"
			"cond_op":
				if u in ["=", ">", "<", "LIKE", ">=", "<=", "!=", "<>"]:
					s.at = "cond_val"
				elif u == "IS NULL":
					s.at = "after_cond"
				else:
					s.at = "lost"
			"cond_val":
				s.at = "after_cond"
			"group_col":
				s.at = "after_group"
			"order_col":
				s.at = "after_order"
			"limit":
				s.at = "after_limit"
			"update_table":
				s.table = str(tok)
				s.at = "after_update"
			"after_update":
				s.at = "set_col" if u == "SET" else "lost"
			"set_col":
				s.at = "set_eq"
			"set_eq":
				s.at = "set_val" if u == "=" else "lost"
			"set_val":
				s.at = "after_set"
			"after_set":
				if u == ",":
					s.at = "set_col"
				elif u == "WHERE":
					s.at = "cond_col"
				else:
					s.at = "lost"
			"insert_table":
				s.table = str(tok)
				s.at = "after_insert"
			"after_insert":
				if u == "VALUES":
					s.at = "values"
				elif u == "(":
					s.at = "insert_cols"
				else:
					s.at = "lost"
			"insert_cols":
				s.at = "insert_cols_sep"
			"insert_cols_sep":
				if u == ",":
					s.at = "insert_cols"
				elif u == ")":
					s.at = "after_insert_cols"
				else:
					s.at = "lost"
			"after_insert_cols":
				s.at = "values" if u == "VALUES" else "lost"
			"values":
				s.at = "values_in" if u == "(" else "lost"
			"values_in":
				s.at = "values_sep"
			"values_sep":
				if u == ",":
					s.at = "values_in"
				elif u == ")":
					s.at = "after_values"
				else:
					s.at = "lost"
			"path":
				s.at = "after_path" if str(tok).begins_with("/") else "lost"
			"after_path", "after_key":
				if u == "X-API-KEY:" and at == "after_path":
					s.at = "key"
				elif u == "{":
					s.at = "body"
				else:
					s.at = "lost"
			"key":
				s.at = "after_key"
			"body":
				pass  # inside the JSON body: true, false and found values, till it closes
			_:
				s.at = "lost"
	return s


## What `state` offers, from what's been found.
static func _offer(state: Dictionary, have: Dictionary) -> Dictionary:
	var out := {"Commands": [], "Tables": [], "Columns": [], "Found": []}
	var cmds: Array = have.get("commands", [])
	var words := func(list: Array) -> Array:
		return ORDER.filter(func(t): return list.has(t) and cmds.has(t))
	var cols: Dictionary = have.get("columns", {})
	var of_table := func() -> Array:
		for t in cols:
			if str(t).to_lower() == str(state.table).to_lower():
				return [[t, cols[t]]]
		return []
	var all_columns := func() -> Array:
		var names := cols.keys()
		names.sort()
		return names.map(func(t): return [t, cols[t]])
	var values: Array = have.get("values", [])
	match state.at:
		"start":
			out.Commands = words.call(STARTERS)
		"schema", "from", "update_table", "insert_table":
			out.Tables = have.get("tables", []).duplicate()
		"select":
			out.Commands = words.call(["*", "COUNT(*)", "DISTINCT"])
			out.Columns = all_columns.call()
		"select_more":
			out.Commands = words.call(["COUNT(*)"])
			out.Columns = all_columns.call()
		"select_distinct":
			out.Columns = all_columns.call()
		"select_item":
			out.Commands = words.call([",", "FROM"])
		"after_table":
			out.Commands = words.call(["WHERE", "GROUP BY", "ORDER BY", "LIMIT", ";"])
		"cond_col", "group_col", "set_col", "insert_cols":
			out.Columns = of_table.call()
		"order_col":
			out.Columns = of_table.call()
			out.Commands = words.call(["COUNT(*)"])
		"cond_op":
			out.Commands = words.call(["=", ">", "<", "LIKE", "IS NULL"])
		"cond_val", "set_val", "values_in":
			out.Found = values.duplicate()
			out.Commands = words.call(["' '"])
		"after_cond":
			out.Commands = words.call(["AND", "OR", "GROUP BY", "ORDER BY", "LIMIT", ";"])
		"after_group":
			out.Commands = words.call(["ORDER BY", "LIMIT", ";"])
		"after_order":
			out.Commands = words.call(["DESC", ",", "LIMIT", ";"])
		"after_desc":
			out.Commands = words.call([",", "LIMIT", ";"])
		"after_limit":
			out.Commands = words.call([";"])
		"after_update":
			out.Commands = words.call(["SET"])
		"set_eq":
			out.Commands = words.call(["="])
		"after_set":
			out.Commands = words.call([",", "WHERE", ";"])
		"after_insert":
			out.Commands = words.call(["( )", "VALUES"])
		"insert_cols_sep", "values_sep":
			out.Commands = words.call([","]) + ([")"] if cmds.has("( )") else [])
		"after_insert_cols":
			out.Commands = words.call(["VALUES"])
		"values":
			out.Commands = words.call(["( )"])
		"after_values":
			out.Commands = words.call([";"])
		"path":
			out.Commands = words.call(["/"])
		"after_path":
			out.Commands = words.call(["X-Api-Key:"] + ([] if state.method == "GET" else ["{ }"]))
		"key":
			out.Found = values.duplicate()
		"after_key":
			out.Commands = words.call([] if state.method == "GET" else ["{ }"])
		"body":
			out.Commands = words.call(["true", "false"])
			out.Found = values.duplicate()
	return out


## The tab that opens by itself for `offer`: the first in TAB_PRIORITY with words.
static func best_tab(offer: Dictionary) -> String:
	for tab in TAB_PRIORITY:
		if not offer.get(tab, []).is_empty():
			return tab
	return "Commands"


# --- Writing a word in ------------------------------------------------------------

## The text before and after the cursor as the buttons read it. A button writes a
## pair of quotes or braces (' ', { }) with the cursor between; once something's
## typed in it, the pair counts as closed, so the buttons offer what comes after
## it (and picking one carries on after the closing mark). Returns [before, after].
static func past_pair(before: String, after: String) -> Array:
	var closer := _open_pair(before)
	if closer == "" or not after.begins_with(closer):
		return [before, after]
	var opener: String = {"'": "'", "}": "{"}[closer]
	if before.substr(before.rfind(opener) + 1).strip_edges() == "":
		return [before, after]
	return [before + closer, after.substr(1)]


## The closing mark of the pair the cursor is inside, or "".
static func _open_pair(before: String) -> String:
	if before.count("'") % 2 == 1:
		return "'"
	var bare := RegEx.create_from_string("'(?:[^']|'')*'").sub(before, "", true)
	if bare.count("{") > bare.count("}"):
		return "}"
	return ""

## `before` (the text before the cursor) with `word` written in, over the last
## `replace` characters (a word half typed): [new text before the cursor, how far
## the cursor sits back from its end]. A word gets a space before it (unless it
## follows an opening bracket) and after it; ; , and ) sit right after the word
## before them; a pair (' ', { }) leaves the cursor between, and ( ) writes its
## ( alone, with ) a button of its own once something's in it.
static func insert(before: String, word: String, replace: int = 0) -> Array:
	var b := before.substr(0, maxi(0, before.length() - replace))
	var text := word
	var back := 0
	if word in ["' '", "{ }"]:
		text = word.replace(" ", "")
		back = 1
	elif word == "( )":
		text = "("
	var tight_left := word in [";", ",", ")"]
	if not tight_left and b != "" and not b[b.length() - 1] in [" ", "\n", "(", "{", "/"]:
		b += " "
	elif tight_left:
		b = b.rstrip(" ")
	b += text
	if back == 0 and not word in [";", "/", "( )"]:
		b += " "
	return [b, back]


# --- Counting uses ------------------------------------------------------------------

## The words found in `sql` (each once), as the buttons write them. Words inside
## quoted values don't count (a value 'SELECT' isn't a use of SELECT).
static func used_in(sql: String) -> Array:
	var t := sql.strip_edges()
	var out := []
	if t.to_lower().begins_with(".tables"):
		return [".tables"]
	if t.to_lower().begins_with(".schema"):
		return [".schema"]
	var bare := RegEx.create_from_string("'(?:[^']|'')*'?").sub(t, "''", true)
	var no_count := RegEx.create_from_string("(?i)\\bCOUNT\\s*\\(\\s*\\*\\s*\\)").sub(bare, "", true)
	var checks := {
		"SELECT": "\\bSELECT\\b", "FROM": "\\bFROM\\b", "WHERE": "\\bWHERE\\b", "AND": "\\bAND\\b",
		"OR": "\\bOR\\b", "ORDER BY": "\\bORDER\\s+BY\\b", "GROUP BY": "\\bGROUP\\s+BY\\b",
		"DESC": "\\bDESC\\b", "LIMIT": "\\bLIMIT\\b", "LIKE": "\\bLIKE\\b", "DISTINCT": "\\bDISTINCT\\b",
		"IS NULL": "\\bIS\\s+NULL\\b", "UPDATE": "^\\s*UPDATE\\b", "SET": "\\bSET\\b",
		"INSERT INTO": "\\bINSERT\\s+INTO\\b", "VALUES": "\\bVALUES\\b",
		"GET": "^\\s*GET\\b", "POST": "^\\s*POST\\b", "PATCH": "^\\s*PATCH\\b",
		"true": "\\btrue\\b", "false": "\\bfalse\\b", "X-Api-Key:": "\\bX-Api-Key\\s*:",
	}
	for word in checks:
		if RegEx.create_from_string("(?i)" + checks[word]).search(bare):
			out.append(word)
	if RegEx.create_from_string("(?i)\\bCOUNT\\s*\\(\\s*\\*\\s*\\)").search(bare):
		out.append("COUNT(*)")
	if no_count.contains("*"):
		out.append("*")
	for sign in [";", ",", "=", ">", "<"]:
		if bare.contains(sign):
			out.append(sign)
	if t.contains("'"):
		out.append("' '")
	if t.contains("%"):
		out.append("%")
	if RegEx.create_from_string("(?i)\\bVALUES\\s*\\(").search(bare):
		out.append("( )")
	if bare.contains("{"):
		out.append("{ }")
	if RegEx.create_from_string("^\\s*[A-Za-z]+\\s+/").search(bare):
		out.append("/")
	return ORDER.filter(func(w): return out.has(w))


## The same query, however it was spaced or capitalised: for "the exact same query
## again doesn't count".
static func same_query(sql: String) -> String:
	return " ".join(sql.replace("\n", " ").strip_edges().rstrip(";").split(" ", false)).to_lower()


## The notice when words come off: the approved wording (Augustine, 2026-11-05),
## with his 3.
static func off_notice(words: Array) -> String:
	if words.size() == 1:
		return "No more training wheels! You've used %s %d times. Now you type it yourself." % [words[0], USES]
	var list := ", ".join(words.slice(0, words.size() - 1)) + " and " + str(words[-1])
	return "No more training wheels! You've used %s %d times or more. Now you type them yourself." % [list, USES]
