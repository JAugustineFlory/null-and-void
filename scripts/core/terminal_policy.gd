class_name TerminalPolicy
extends RefCounted
## The building's terminal security policy, on terminals the crew uses without an
## escort (Augustine's call C, 2026-11-18; plan/teaching/v0.10-policy.md). A
## terminal is under it when its level sets `Terminal.policy = true`.
##
## - `SELECT * FROM` one table with nothing after it is refused, on every table,
##   whatever its size: naming the columns, or adding WHERE, ORDER BY, LIMIT,
##   GROUP BY, a JOIN or a count, lets it through. `WHERE 1 = 1` passes too.
## - No more than CAP rows are ever shown.
## - It covers what a query shows, not what it changes, and never the dot
##   commands. Officially `.tables` and `.schema` don't exist (`.help` leaves them
##   out), but they still work.
## No line the system shows explains the way past it: the posted card (CARD, a
## staff document), the crew's notebook (NOTE) and SYSOP (HINT_*) do.

## Most rows a query shows under the policy.
const CAP := 20
## P1: under the session line of a terminal's boot screen.
const BOOT_LINE := "NO ESCORT ON FILE: TERMINAL SECURITY POLICY IN EFFECT."
## P2: the refusal. Nothing runs, and nothing shows under it.
const REFUSAL := "ERROR 42501: insufficient privilege"
## P4: under a result that had more than CAP rows.
const CAPPED := "POLICY: OUTPUT CAPPED AT 20 ROWS (LIMIT 20)."
## P7: in `.help`, in place of its .tables and .schema lines.
const HELP_LINE := "Unescorted session: security policy in effect. See posted policy. Output capped at 20 rows."
## P6: the crew's own note when any copy of the card is read.
const NOTE := "Security policy on unescorted terminals: SELECT * FROM a table won't run on its own. Name the columns, or add a WHERE, ORDER BY, LIMIT or COUNT. Output capped at 20 rows."
## P9: SYSOP's `.hint` after a refusal, before the case's own tiers: before any
## copy of the card is read (a), then once a floor after (b).
const HINT_UNREAD := "security posts its policy by the terminals. read it: it says what's allowed."
const HINT_READ := "the policy won't run SELECT * on its own. name the columns you need, or add a WHERE, an ORDER BY or a LIMIT. it's in your notebook."
## The hint spot every copy of the card is (Document.spot): reading one finds it.
const SPOT := "policy_card"
## P5: the laminated card by the first policy terminal on each floor. Rourke's
## extension is handwritten into the blank (`hand`).
const CARD_TITLE := "TERMINAL SECURITY POLICY"
const CARD := [
	{"text": "TERMINAL SECURITY POLICY"},
	{"text": "Applies to unescorted sessions (no staff escort on file)."},
	{"text": ""},
	{"text": "1. SELECT * FROM a table, with nothing more, is restricted."},
	{"text": "   Name the columns you need, or add at least one of:"},
	{"text": "     WHERE       matching rows only"},
	{"text": "     ORDER BY    sorted (DESC = newest first)"},
	{"text": "     LIMIT       first rows only"},
	{"text": "     COUNT(*)    row count only"},
	{"text": "2. Output is capped at 20 rows (LIMIT 20)."},
	{"text": "   For the latest entries, sort newest first: ORDER BY ... DESC"},
	{"text": ""},
	{"text": "Questions? Contact your escort."},
	{"text": "Night escort: ROURKE, D.  ext. 2210", "hand": true},
	{"text": "                              - Halcyon Security"},
]

## Words that can follow a table and mean the query asks for more than all of it.
const _MORE := ["where", "group", "order", "limit", "having", "join", "inner", "left", "right", "full", "cross", "natural", "union", "intersect", "except", "offset", "window"]


## Whether the policy refuses `sql`: its outer statement is `SELECT *` (or
## `DISTINCT *`, or `t.*`) from one table, or from a subquery, with nothing after
## it. A subquery inside it doesn't count, and neither does anything quoted.
static func refuses(sql: String) -> bool:
	var s := _outer(sql)
	var m := RegEx.create_from_string("(?is)^select\\s+(?:all\\s+|distinct\\s+)?(?:[a-z_][a-z0-9_]*\\s*\\.\\s*)?\\*\\s+from\\s*([a-z_][a-z0-9_]*|'')(?:\\s+(?:as\\s+)?([a-z_][a-z0-9_]*))?$").search(s)
	if m == null:
		return false
	var alias := m.get_string(2).to_lower()
	return alias == "" or not _MORE.has(alias)


## The statement's top level: quoted text emptied, parenthesized parts made one
## word (_sub_), comments and the closing ; dropped, spaces squeezed.
static func _outer(sql: String) -> String:
	var s := RegEx.create_from_string("'(?:[^']|'')*'|\"(?:[^\"]|\"\")*\"").sub(sql, "''", true)
	s = RegEx.create_from_string("--[^\\n]*|/\\*[\\s\\S]*?\\*/").sub(s, " ", true)
	var paren := RegEx.create_from_string("\\([^()]*\\)")
	while paren.search(s):
		s = paren.sub(s, " _sub_ ", true)
	s = s.strip_edges()
	while s.ends_with(";"):
		s = s.trim_suffix(";").strip_edges()
	return RegEx.create_from_string("\\s+").sub(s, " ", true)


## Run `sql` on `db` under the policy: refused ({ok: false, error: REFUSAL,
## policy: "refused"}, and nothing runs), or run, with at most CAP rows shown
## (`capped` when some were cut).
static func run(db: FacilityDB, sql: String) -> Dictionary:
	if refuses(sql):
		return {"ok": false, "error": REFUSAL, "policy": "refused", "rows": [], "columns": [], "changes": 0}
	return cap(db.execute(sql))


## The card (P5), laminated, by a floor's first policy terminal. Reading any copy
## finds SPOT for the crew, which puts NOTE in their notebooks.
static func place_card(parent: Node, pos: Vector3, facing_deg: float, flat := true) -> Document:
	var d := Document.place(parent, pos, facing_deg, CARD_TITLE, CARD, flat, "laminated", Vector2(0.24, 0.3))
	d.spot = SPOT
	return d


## `result` with at most CAP rows.
static func cap(result: Dictionary) -> Dictionary:
	var rows: Array = result.get("rows", [])
	if result.get("ok", false) and rows.size() > CAP:
		result.rows = rows.slice(0, CAP)
		result["capped"] = true
	return result


## Boot text with BOOT_LINE under its session line (the one naming the session,
## else the first).
static func boot_with_line(lines: Array) -> Array:
	var out := lines.duplicate()
	if out.has(BOOT_LINE):
		return out
	var at := 0
	for i in out.size():
		if str(out[i]).to_upper().contains("SESSION"):
			at = i
			break
	out.insert(mini(at + 1, out.size()), BOOT_LINE)
	return out
