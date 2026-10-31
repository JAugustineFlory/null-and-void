class_name WorkOrderForm
extends RefCounted
## The crew's Byte-Right work order as it sits in the notebook: a printed
## dispatch form (header, customer, the job they were sent for, sign-off lines)
## with the crew's own to-dos written underneath. The printed scope is the job
## Byte-Right thinks it is: nothing on it hints that anything is wrong.
## Built as separate pieces so the notebook can split it across pages.

const FORM_PAPER := Color(0.99, 0.985, 0.96)
const PRINT := Color(0.12, 0.12, 0.14)
const FORM_RULE := Color(0.62, 0.62, 0.6)
const BAND := Color(0.16, 0.27, 0.42)  # Byte-Right blue
const STAMP := Color(0.72, 0.16, 0.12, 0.85)
## A highlighter stroke over a printed line the crew marked in the briefing (Game.ticket_marks).
const HIGHLIGHT := Color(1.0, 0.9, 0.2, 0.5)
## Across the work order once the job is over (Game.end_job). Drafts for
## Augustine's word-for-word OK.
const VOID_STAMP := "VOID"
const VOID_NOTE := "This isn't the job any more. What we're doing now is under Cases."


## Every piece in reading order. `ticket` is Game.ticket(): the printed fields,
## the order number and the crew's tasks. The printed form fills a page of
## `page_height` by itself (the crew's notes start on the next page), so it's
## always seen whole.
static func build(ticket: Dictionary, page_height: float = 0.0) -> Array[Control]:
	var form := VBoxContainer.new()
	form.name = "WorkOrder"
	form.add_theme_constant_override("separation", 8)
	var scope := _scope(ticket)
	scope.size_flags_vertical = Control.SIZE_EXPAND_FILL  # takes up whatever the page has left
	for part in [_header(ticket), _details(ticket), scope, _signoff()]:
		form.add_child(part)
	form.custom_minimum_size.y = page_height
	var items: Array[Control] = [form]
	if ticket.get("void", false):
		var stamp := _type(VOID_STAMP, 34, STAMP, false)
		stamp.name = "Void"
		stamp.rotation_degrees = -4.0
		items.append(stamp)
		items.append(NotebookArt.hand(VOID_NOTE, 22, NotebookArt.PENCIL))
	items.append(NotebookArt.hand("Crew notes", 30))
	# Only the job's own tasks: once it's over, tasks go on their case's checklist.
	var todo: Array = ticket.get("tasks", []).filter(func(t): return t.get("case", "") == "")
	if todo.is_empty():
		items.append(NotebookArt.hand("Nothing yet.", 24, NotebookArt.PENCIL))
	for task in todo.slice(maxi(0, todo.size() - 6)):
		var filled: String = task.get("filled", "")
		if task.done:
			items.append(NotebookArt.hand("[x]  %s%s" % [task.text, ("  - " + filled) if filled != "" else ""], 22, NotebookArt.PENCIL))
		else:
			items.append(NotebookArt.hand("[  ]  %s" % task.text, 26))
	return items


## The blue band across the top: company and form name, then the order number
## and the priority stamp.
static func _header(t: Dictionary) -> Control:
	var sheet := _sheet()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	sheet.add_child(box)
	var band := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BAND
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	band.add_theme_stylebox_override("panel", sb)
	var top := HBoxContainer.new()
	band.add_child(top)
	var company := _type(t.company, 20, Color.WHITE, false)
	company.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(company)
	top.add_child(_type("WORK ORDER", 20, Color.WHITE, false))
	box.add_child(band)
	box.add_child(_type(t.get("tagline", ""), 15, FORM_RULE.darkened(0.3)))
	var row := HBoxContainer.new()
	var num := _type("No. %s" % t.get("order", ""), 23, PRINT, false)
	num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(num)
	row.add_child(_type(t.get("priority", ""), 20, STAMP, false))
	box.add_child(row)
	return sheet


## Who it's for and who to ask for: a two-column grid of printed fields.
static func _details(t: Dictionary) -> Control:
	var sheet := _sheet()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	sheet.add_child(grid)
	for field in [["Customer:", t.customer, "customer"], ["Site:", t.get("site", ""), "site"], ["Contact:", t.contact, "contact"], ["Caller:", t.get("caller", ""), "caller"], ["Problem:", t.problem, "problem"], ["Billing:", t.get("billing", ""), "billing"]]:
		if str(field[1]) == "":
			continue
		grid.add_child(_type(field[0], 17, FORM_RULE.darkened(0.35), false))
		var value := _type(str(field[1]), 19)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(_marked(value, t, field[2]))
	return sheet


## The scope of work: the job they were sent to do, with blank check boxes.
static func _scope(t: Dictionary) -> Control:
	var sheet := _sheet()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	sheet.add_child(box)
	box.add_child(_type("SCOPE OF WORK", 19, BAND, false))
	box.add_child(_rule())
	var tasks: Array = t.get("scope", [])
	for i in tasks.size():
		box.add_child(_marked(_type("%d. [ ] %s" % [i + 1, tasks[i]], 19), t, "scope_%d" % i))
	return sheet


## A printed line, run over with highlighter if the crew marked it (`key` in the
## ticket's marks). Named Marked_<key> for tests.
static func _marked(line: Label, t: Dictionary, key: String) -> Label:
	if t.get("marks", []).has(key):
		line.name = "Marked_" + key
		var sb := StyleBoxFlat.new()
		sb.bg_color = HIGHLIGHT
		sb.set_corner_radius_all(3)
		sb.skew = Vector2(-0.08, 0)  # a hand-drawn stroke, not a printed box
		line.add_theme_stylebox_override("normal", sb)
	return line


static func _signoff() -> Control:
	var sheet := _sheet()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	sheet.add_child(box)
	box.add_child(_type("Technician: ______________  In: _____", 16, FORM_RULE.darkened(0.35)))
	box.add_child(_type("Client sign-off: _________  Out: ____", 16, FORM_RULE.darkened(0.35)))
	return sheet


## One printed section of the form: off-white paper with a thin grey border.
static func _sheet() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = FORM_PAPER
	sb.border_color = FORM_RULE
	sb.set_border_width_all(1)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.15)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(1, 2)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = FORM_RULE
	r.custom_minimum_size = Vector2(0, 1)
	return r


## Printed text. `wrap` false for short labels that sit beside others in a row,
## which would otherwise squeeze to a letter per line.
static func _type(text: String, size: int, color: Color = PRINT, wrap: bool = true) -> Label:
	var l := NotebookArt.code(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return l
