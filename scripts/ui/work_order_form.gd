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


## Every piece in reading order. `ticket` is Game.ticket(): the printed fields,
## the order number and the crew's tasks.
static func build(ticket: Dictionary) -> Array[Control]:
	var items: Array[Control] = [_header(ticket), _details(ticket), _scope(ticket), _signoff()]
	items.append(NotebookArt.hand("Crew notes", 30))
	var todo: Array = ticket.get("tasks", [])
	if todo.is_empty():
		items.append(NotebookArt.hand("Nothing yet.", 24, NotebookArt.PENCIL))
	for task in todo.slice(maxi(0, todo.size() - 6)):
		var filled: String = task.get("filled", "")
		if task.done:
			items.append(NotebookArt.hand("[x]  %s%s" % [task.text, ("  - " + filled) if filled != "" else ""], 22, NotebookArt.PENCIL))
		else:
			items.append(NotebookArt.hand("[  ]  %s" % task.text, 26))
	return items


## The blue band across the top: company, form name, order number, priority stamp.
static func _header(t: Dictionary) -> Control:
	var sheet := _sheet()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	sheet.add_child(box)
	var band := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BAND
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	band.add_theme_stylebox_override("panel", sb)
	var top := HBoxContainer.new()
	band.add_child(top)
	var company := _type(t.company, 15, Color.WHITE)
	company.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(company)
	top.add_child(_type("WORK ORDER", 15, Color.WHITE))
	box.add_child(band)
	box.add_child(_type(t.get("tagline", ""), 12, FORM_RULE.darkened(0.3)))
	var row := HBoxContainer.new()
	var num := _type("No. %s" % t.get("order", ""), 16)
	num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(num)
	var stamp := _type(t.get("priority", ""), 14, STAMP)
	stamp.rotation_degrees = -3.0
	row.add_child(stamp)
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
	for field in [["Customer:", t.customer], ["Site:", t.get("site", "")], ["Contact:", t.contact], ["Problem:", t.problem], ["Billing:", t.get("billing", "")]]:
		if str(field[1]) == "":
			continue
		var key := _type(field[0], 13, FORM_RULE.darkened(0.35))
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(key)
		var value := _type(str(field[1]), 14)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
	return sheet


## The scope of work: the job they were sent to do, with blank check boxes.
static func _scope(t: Dictionary) -> Control:
	var sheet := _sheet()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	sheet.add_child(box)
	box.add_child(_type("SCOPE OF WORK", 14, BAND))
	box.add_child(_rule())
	var tasks: Array = t.get("scope", [])
	for i in tasks.size():
		box.add_child(_type("%d. [ ] %s" % [i + 1, tasks[i]], 14))
	return sheet


static func _signoff() -> Control:
	var sheet := _sheet()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	sheet.add_child(box)
	box.add_child(_type("Technician: ________________  Time in: ____", 13, FORM_RULE.darkened(0.35)))
	box.add_child(_type("Client sign-off: ____________  Time out: ___", 13, FORM_RULE.darkened(0.35)))
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


static func _type(text: String, size: int, color: Color = PRINT) -> Label:
	var l := NotebookArt.code(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
