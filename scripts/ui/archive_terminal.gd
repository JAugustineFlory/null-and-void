class_name ArchiveTerminal
extends MenuModal
## The crew's old PC in the garage's back office (GarageOffice): a non-canonical
## look behind the scenes. It opens on a menu anyone can browse with the mouse,
## keys or a controller (crew files, the company, achievements, cases closed), and
## a query mode runs real SQL, read-only, on the same tables. Never needed.
## plan/garage-secret-room.md.

## Approved by Augustine word for word, 2026-11-05 00:43Z (plan/garage-secret-room.md).
const BOOT := "BYTE-RIGHT ARCHIVE v1.0  -  (c) 1997 Byte-Right IT Services. All rights reserved. Most wrongs too."
const SECTIONS := {"crew": "Crew files", "company": "The company", "achievements": "Achievements", "cases": "Cases closed"}
const QUERY := "Query mode"
const QUERY_HINT := "Type SQL, or press Esc for the menu. Tables: crew, company, achievements, cases."
const RUN := "Run"
const MENU := "Menu"
const LEAVE := "Log off"
const SECRET := "???"
const NO_CASES := "No cases closed yet. Give it time."
const CREW_NOTES := {
	"dana": "Wired a vet's office for me once, and I never gave her back. Calls me 'chief', which I've decided means CEO.",
	"priya": "Fixed my phone in four minutes, then sold me a case for it. Hired on the spot.",
	"rosa": "Twelve years running a school's front office. Counts heads at lunch. Counts mine twice.",
	"kit": "Delivered a parcel to the garage and never left. Climbs first, asks later, mostly doesn't ask.",
	"june": "My aunt. Has talked to every continent from her garden shed, and says 'over' at dinner.",
	"mei": "Answered my ad on a dare. Laughs when she's nervous, so we always know where she is.",
	"marcus": "Ten years of mall security, swore off night work, then I called. Still checks the corners of my kitchen.",
	"theo": "Quick with computers, quicker with a joke. Thinks every job is a video game, and I've stopped correcting him.",
	"sam": "Professional mover. Joined because I asked nicely. Lifts anything, then asks where it goes.",
	"luis": "My oldest friend. Twenty years fixing my plumbing, my van and my bad decisions, mostly by turning them off and on again.",
	"ike": "Told me he 'basically knows SQL'. Calls the van 'our mobile platform'.",
	"walt": "Climbs poles in storms for a living, and still won't go near the photocopier. Says he's only here to keep an eye on us.",
}
const COMPANY := [
	["about", "Byte-Right IT Services. Founded in Maddison's garage. Fleet: one van. On the radio, it's van three."],
	["reviews", "★★★★★ 'They came!' - Bexley Library (paid in exact change).  ★★★★★ 'Very friendly.' - Maddison's mom.  ★☆☆☆☆ 'They unplugged the fridge.' - Kemp Dental."],
	["mission", "We fix what's broken."],
]

## Its rows, as both the menu and query mode show them: table -> [{column: value}].
var tables := {}
## Query mode's own copy of `tables`, read-only (a FacilityDB of its own, not the building's).
var db: FacilityDB
var page := "menu"
var _query: LineEdit
var _result: Label


## The terminal over `parent`, showing what `profile` has earned and closed.
static func show_for(parent: Node, profile: Profile) -> ArchiveTerminal:
	var t := ArchiveTerminal.new()
	t.name = "ArchiveTerminal"
	t.tables = rows_for(profile)
	parent.add_child(t)
	t.show_page("menu")
	return t


## Every table's rows for `profile`.
static func rows_for(profile: Profile) -> Dictionary:
	var crew := []
	for c in PlayableCrew.CAST:
		crew.append({"name": c.name, "age": c.age, "before": c.about, "note": CREW_NOTES.get(c.slug, "")})
	var company := []
	for line in COMPANY:
		company.append({"topic": line[0], "text": line[1]})
	var achievements := []
	for a in Achievements.LIST:
		var earned: bool = profile.earned.has(a.id)
		var hidden := Achievements.is_secret(a.id) and not earned
		achievements.append({"name": SECRET if hidden else a.name, "earned": 1 if earned else 0,
			"how": "" if hidden else Achievements.hint(a.id)})
	var cases := []
	for id in profile.cases:
		var c: Dictionary = profile.cases[id]
		cases.append({"id": id, "question": c.get("title", ""), "answer": c.get("how", "")})
	return {"crew": crew, "company": company, "achievements": achievements, "cases": cases}


func _ready() -> void:
	super()
	db = FacilityDB.new()
	var sql := ""
	for table in tables:
		var cols: Array = _columns(table)
		sql += "CREATE TABLE %s (%s);\n" % [table, ", ".join(cols)]
		for row in tables[table]:
			sql += "INSERT INTO %s VALUES (%s);\n" % [table, ", ".join(cols.map(func(k): return FacilityDB._sql_literal(row[k])))]
	db.load_seed(sql)
	db.read_only = true


func _columns(table: String) -> Array:
	match table:
		"crew": return ["name", "age", "before", "note"]
		"company": return ["topic", "text"]
		"achievements": return ["name", "earned", "how"]
		_: return ["id", "question", "answer"]


## Show the menu, a section ("crew"...), or "query".
func show_page(id: String) -> void:
	page = id
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var boot := _mono(BOOT, 16, ThemeUtil.DIM)
	box.add_child(boot)
	if id == "menu":
		for key in SECTIONS:
			var b := SettingsPanel.button(SECTIONS[key])
			b.name = "Section_" + key
			b.pressed.connect(show_page.bind(key))
			box.add_child(b)
		var q := SettingsPanel.button(QUERY)
		q.name = "Query"
		q.pressed.connect(show_page.bind("query"))
		box.add_child(q)
		add_back(LEAVE)
	elif id == "query":
		box.add_child(SettingsPanel.heading(QUERY))
		box.add_child(_mono(QUERY_HINT, 16, ThemeUtil.DIM))
		_query = LineEdit.new()
		_query.name = "SQL"
		_query.custom_minimum_size = Vector2(640, 44)
		_query.add_theme_font_override("font", ThemeUtil.mono())
		_query.text_submitted.connect(func(_t): run_query())
		box.add_child(_query)
		var run := SettingsPanel.button(RUN)
		run.name = "Run"
		run.pressed.connect(run_query)
		box.add_child(run)
		_result = _mono("", 15, ThemeUtil.GREEN)
		_result.name = "Result"
		box.add_child(_result)
		_menu_button()
	else:
		box.add_child(SettingsPanel.heading(SECTIONS[id]))
		var rows: Array = tables[id]
		if rows.is_empty():
			box.add_child(_mono(NO_CASES, 18, ThemeUtil.AMBER))
		for row in rows:
			box.add_child(_entry(id, row))
		_menu_button()
	PadFocus.focus_first.call_deferred(box)


## Query mode: run what's typed against the archive's own tables.
func run_query() -> Dictionary:
	var res := db.execute(_query.text)
	if not res.ok:
		_result.text = FacilityDB.explain_error(res.error) if res.error != "" else db.read_only_error
		_result.add_theme_color_override("font_color", ThemeUtil.RED)
		return res
	_result.add_theme_color_override("font_color", ThemeUtil.GREEN)
	var lines := [" | ".join(res.columns)]
	for row in res.rows:
		lines.append(" | ".join(res.columns.map(func(k): return str(row[k]))))
	_result.text = "\n".join(lines)
	return res


## One row of a section as the menu shows it.
func _entry(table: String, row: Dictionary) -> Control:
	var e := VBoxContainer.new()
	e.add_theme_constant_override("separation", 0)
	match table:
		"crew":
			e.add_child(ThemeUtil.label("%s  (%s)  -  %s" % [row.name, row.age, row.before], 19, ThemeUtil.AMBER))
			e.add_child(_mono(row.note, 16, Color(0.85, 0.85, 0.85)))
		"company":
			e.add_child(_mono(row.text, 17, Color(0.85, 0.85, 0.85)))
		"achievements":
			e.add_child(ThemeUtil.label(row.name, 19, ThemeUtil.AMBER if row.earned else ThemeUtil.DIM))
			if not row.earned and row.how != "":
				e.add_child(_mono(row.how, 15, ThemeUtil.DIM))
		_:
			e.add_child(ThemeUtil.label(row.question, 19, ThemeUtil.AMBER))
			e.add_child(_mono(row.answer, 16, Color(0.85, 0.85, 0.85)))
	return e


func _menu_button() -> void:
	var back := SettingsPanel.button(MENU)
	back.name = "Back"
	back.pressed.connect(show_page.bind("menu"))
	box.add_child(back)


func _mono(text: String, size: int, color: Color) -> Label:
	var l := ThemeUtil.label(text, size, color)
	l.add_theme_font_override("font", ThemeUtil.mono())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 640
	return l


## Esc or B: from a section back to the menu, from the menu out.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if page == "menu":
			close()
		else:
			show_page("menu")
