extends RefCounted
## The terminal's next-word buttons (KeywordHelp) and the notebook you look down
## at below a terminal's screen (TerminalNotebook): plan/teaching/keyword-buttons.md,
## section 9. The grammar on its own; every puzzle's answer built from the buttons;
## the Tables page's rule for columns; counting uses; and the look-down notebook on
## Server Room A's terminal, with a keyboard and with a pad.

var t: SceneTree
var _check: Callable


func run(tree: SceneTree, check: Callable) -> void:
	t = tree
	_check = check
	var net := t.root.get_node("Net")
	var real_profile = net.profile
	net.profile = Profile.new()  # in memory, so tests never touch a real save
	KeywordHelp.load_settings()
	var real_mode := KeywordHelp.mode
	KeywordHelp.mode = "easy"
	KeywordHelp.counting = true
	InputGlyphs.pad = false
	test_grammar()
	test_counting_words()
	test_every_answer_from_buttons()
	test_profile_keeps_counts()
	await test_tables_page()
	await test_counting_at_terminal()
	await test_look_down()
	await test_look_down_on_pad()
	await test_paper_word()
	InputGlyphs.pad = false
	KeywordHelp.mode = real_mode
	KeywordHelp.counting = false
	net.profile = real_profile


func _game() -> Node:
	return t.root.get_node("Game")


func _net() -> Node:
	return t.root.get_node("Net")


func _frames(n: int) -> void:
	for i in n:
		await t.physics_frame


func _until(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await t.physics_frame
	return cond.call()


## Everything a player could have found by Level 1's terminal, after .tables,
## SELECT * FROM doors and .schema door_controllers.
func _level_1_found() -> Dictionary:
	return {
		"commands": ["SELECT", ".tables", ".schema", "*", ",", "FROM", "WHERE", "=", "' '", "AND", "ORDER BY", "DESC", "LIMIT", ";"],
		"tables": ["door_controllers", "doors", "lights", "racks"],
		"columns": {"doors": ["id", "locked", "name", "zone"], "door_controllers": ["id", "status", "zone"]},
		"values": ["'D'"],
	}


func _all(offer: Dictionary) -> Array:
	var out: Array = offer.Commands + offer.Tables + offer.Found
	for g in offer.Columns:
		out += g[1]
	return out


func test_grammar() -> void:
	print("Keyword buttons: the words that can come next")
	var have := _level_1_found()
	var level_0 := {"commands": ["SELECT", "*", "FROM", ";"], "tables": [], "columns": {}, "values": []}
	_check.call(KeywordHelp.next_words("", level_0).Commands == ["SELECT"], "on the ground floor, with chapter 1 in, a query can start only with SELECT")
	var start := KeywordHelp.next_words("", have)
	_check.call(start.Commands == ["SELECT", ".tables", ".schema"] and start.Tables.is_empty() and start.Columns.is_empty(), "at the start: only the commands found that can start one")
	var sel := KeywordHelp.next_words("SELECT ", have)
	_check.call(sel.Commands == ["*"] and sel.Columns.size() == 2 and sel.Columns[0][0] == "door_controllers" and sel.Columns[1][1] == ["id", "locked", "name", "zone"],
		"after SELECT: * and every column found, under its table (A to Z)")
	_check.call(KeywordHelp.best_tab(sel) == "Columns", "and the Columns tab opens by itself")
	var from := KeywordHelp.next_words("SELECT id FROM ", have)
	_check.call(from.Tables == ["door_controllers", "doors", "lights", "racks"] and from.Commands.is_empty() and KeywordHelp.best_tab(from) == "Tables",
		"after FROM: every table on the Tables page, never only the right one")
	_check.call(KeywordHelp.next_words("SELECT id FROM door_controllers ", have).Commands == ["WHERE", "ORDER BY", "LIMIT", ";"], "after a table: WHERE, ORDER BY, LIMIT and ; (GROUP BY isn't found yet)")
	var where := KeywordHelp.next_words("SELECT id FROM door_controllers WHERE ", have)
	_check.call(where.Columns == [["door_controllers", ["id", "status", "zone"]]], "after WHERE: only the columns of the table after FROM")
	_check.call(KeywordHelp.next_words("SELECT id FROM lights WHERE ", have).Columns.is_empty(), "a table whose columns haven't been seen offers none")
	_check.call(KeywordHelp.next_words("SELECT id FROM doors WHERE zone ", have).Commands == ["="], "after a column in WHERE: the signs found (only = so far)")
	var val := KeywordHelp.next_words("SELECT id FROM doors WHERE zone = ", have)
	_check.call(val.Found == ["'D'"] and val.Commands == ["' '"] and KeywordHelp.best_tab(val) == "Found", "after =: the values found on the case board, and a pair of quotes")
	_check.call(KeywordHelp.next_words("SELECT id FROM doors WHERE zone = 'D' ", have).Commands == ["AND", "ORDER BY", "LIMIT", ";"], "after a value: AND, ORDER BY, LIMIT and ;")
	_check.call(KeywordHelp.next_words("SELECT id FROM doors WHERE zone = 'D' AND ", have).Columns == [["doors", ["id", "locked", "name", "zone"]]], "after AND: that table's columns again")
	_check.call(KeywordHelp.next_words("SELECT * FROM doors;", have).Commands.is_empty(), "after ; nothing: Enter runs it")
	_check.call(_all(KeywordHelp.next_words("SELECT FROM doors ", have)).is_empty(), "a query that's gone wrong offers nothing rather than a guess")
	# Half a word typed: only the words it starts, written over it.
	var half := KeywordHelp.next_words("SELECT id FROM do", have)
	_check.call(half.Tables == ["door_controllers", "doors"] and half.replace == 2, "half a table name typed: only the tables it starts, written over it")
	var sel_typed := KeywordHelp.next_words("SELECT", have)
	_check.call(sel_typed.replace == 0 and sel_typed.Commands == ["*"], "a whole word typed with no space yet is taken as typed")
	_check.call(KeywordHelp.next_words(".sc", have).Commands == [".schema"] and KeywordHelp.next_words(".schema ", have).Tables.size() == 4, ".schema, then every table")
	# Writing a word in.
	_check.call(KeywordHelp.insert("", "SELECT") == ["SELECT ", 0] and KeywordHelp.insert("SELECT", "*") == ["SELECT * ", 0], "a word gets a space either side of it")
	_check.call(KeywordHelp.insert("SELECT * FROM doors ", ";") == ["SELECT * FROM doors;", 0] and KeywordHelp.insert("SELECT id ", ",") == ["SELECT id, ", 0], "; and , sit right after the word before them")
	_check.call(KeywordHelp.insert("WHERE zone = ", "' '") == ["WHERE zone = ''", 1], "a pair of quotes leaves the cursor between them")
	_check.call(KeywordHelp.insert("SELECT id FROM do", "doors", 2) == ["SELECT id FROM doors ", 0], "a word picked over half of it replaces the half")
	_check.call(KeywordHelp.past_pair("WHERE zone = 'D", "'") == ["WHERE zone = 'D'", ""] and KeywordHelp.past_pair("WHERE zone = '", "'") == ["WHERE zone = '", "'"],
		"inside a pair of quotes with something typed, the buttons read past them")
	var grouped := {"commands": KeywordHelp.ORDER, "tables": ["access_log"], "columns": {"access_log": ["room", "time"]}, "values": []}
	_check.call(KeywordHelp.next_words("SELECT room, ", grouped).Commands == ["COUNT(*)"] and KeywordHelp.next_words("SELECT room FROM access_log GROUP BY room ORDER BY ", grouped).Commands == ["COUNT(*)"],
		"COUNT(*) after a comma in SELECT and after ORDER BY")


func test_counting_words() -> void:
	print("Keyword buttons: which words a query used")
	_check.call(KeywordHelp.used_in("SELECT id FROM doors WHERE zone = 'D' AND status = 'fault';") == ["SELECT", "FROM", "WHERE", "=", "' '", "AND", ";"], "each word once, as the buttons write it")
	_check.call(KeywordHelp.used_in("SELECT name FROM staff WHERE name = 'SELECT FROM'") == ["SELECT", "FROM", "WHERE", "=", "' '"], "words inside a value don't count")
	_check.call(KeywordHelp.used_in("SELECT COUNT(*) FROM racks") == ["SELECT", "COUNT(*)", "FROM"] and KeywordHelp.used_in("SELECT * FROM racks").has("*"), "COUNT(*) is one word, and isn't a *")
	_check.call(KeywordHelp.used_in(".schema doors") == [".schema"] and KeywordHelp.used_in("GET /doors") == ["GET", "/"], "dot commands and requests count too")
	_check.call(KeywordHelp.same_query("select *  from doors;") == KeywordHelp.same_query("SELECT * FROM doors"), "the same query again, spaced or capitalised differently, is the same query")
	_check.call(KeywordHelp.off_notice(["ORDER BY"]) == "No more training wheels! You've used ORDER BY 3 times. Now you type it yourself."
		and KeywordHelp.off_notice(["SELECT", "FROM", "WHERE", "ORDER BY"]) == "No more training wheels! You've used SELECT, FROM, WHERE and ORDER BY 3 times or more. Now you type them yourself.",
		"the notices read as Augustine approved them, with his 3")
	var easy := KeywordHelp.easy_sql_tokens()
	_check.call(easy.has("SELECT") and easy.has("INSERT INTO") and not easy.has("PATCH") and not easy.has("IS NULL"), "Look, No Buttons is every Easy SQL word, not the API book's or Mercer's card's")


## Every puzzle's answer in the game, built word by word from the buttons, with
## everything it needs found: a word the buttons can't offer at its step is a gap
## in the grammar. Values and numbers the player reads off the screen are typed.
func test_every_answer_from_buttons() -> void:
	print("Keyword buttons: every puzzle's answer can be built from them")
	var queries := _puzzle_queries()
	_check.call(queries.size() > 30, "found the puzzles' answers (%d)" % queries.size())
	var gaps := []
	for q in queries:
		var gap := _walk(q)
		if gap != "":
			gaps.append(gap)
	_check.call(gaps.is_empty(), "every answer's words are offered at each step%s" % ("" if gaps.is_empty() else ": " + "; ".join(gaps)))


func _puzzle_queries() -> Array:
	var out := []
	var re := RegEx.create_from_string("Puzzle\\.new\\(\"[a-z_0-9]+\",\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	for f in DirAccess.get_files_at("res://scripts/levels"):
		if not f.ends_with(".gd"):
			continue
		for m in re.search_all(FileAccess.get_file_as_string("res://scripts/levels/" + f)):
			var q := m.get_string(1).replace("\\n", "\n").replace("\\\"", "\"")
			q = q.replace("VALUES %s", "VALUES ('Byte-Right', 'repair', '21:40')").replace("%%", "%").replace("%s", "X1").replace("%d", "4")
			if not q.begins_with("SELECT") and not q.begins_with("UPDATE") and not q.begins_with("INSERT") and not FacilityAPI.is_request(q):
				continue
			out.append(q.split("\n")[0] if FacilityAPI.is_request(q) else q)
	return out


## "" if every word of `q` is offered at its step, else what wasn't.
func _walk(q: String) -> String:
	var toks := KeywordHelp.tokens(q if FacilityAPI.is_request(q) else q + ";")
	var tables := []
	var cols := []
	var values := []
	for i in toks.size():
		var tok: String = toks[i]
		var up := tok.to_upper()
		if i > 0 and str(toks[i - 1]).to_upper() in ["FROM", "UPDATE", "INSERT INTO"]:
			tables.append(tok)
		elif tok.begins_with("'"):
			values.append(tok)
		elif RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$").search(tok) and not KeywordHelp.ORDER.has(up) and not tables.has(tok):
			cols.append(tok)
	var have := {"commands": KeywordHelp.ORDER, "tables": tables, "columns": {}, "values": values}
	for tb in tables:
		have.columns[tb] = cols
	var typed := ""
	for tok in toks:
		var offer := KeywordHelp.next_words(typed, have)
		var ok := _all(offer).any(func(w): return str(w).to_lower() == str(tok).to_lower())
		# Typed, not offered: numbers, signs no chapter teaches, a path's name, X1
		# (a %s left in an answer), and ) after the ( a button wrote.
		ok = ok or (tok == "(" and _all(offer).has("( )")) or tok.is_valid_float() or tok in ["!=", "<>", ">=", "<="] or (tok.begins_with("/") and _all(offer).has("/")) or tok == "X1"
		if not ok:
			return "%s: after \"%s\" no %s (offered %s)" % [q.replace("\n", " "), typed.strip_edges(), tok, _all(offer)]
		typed += tok + " "
		if FacilityAPI.is_request(q) and tok.begins_with("/"):
			break  # the rest of a request is its path, headers and body, typed
	return ""


func test_profile_keeps_counts() -> void:
	print("Keyword buttons: counts are kept on your profile")
	var path := "user://keyword_tests_profile.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var p := Profile.open(path)
	p.use_words(["SELECT", "FROM"])
	p.use_words(["SELECT"])
	p.words_off.append("FROM")
	p.buttons_tip = true
	p.save()
	var back := Profile.open(path)
	_check.call(back.uses_of("SELECT") == 2 and back.uses_of("FROM") == 1 and back.words_off == ["FROM"] and back.buttons_tip, "counts, words off and the tip survive a save and load")
	back.reset_words()
	_check.call(Profile.open(path).word_uses.is_empty() and Profile.open(path).words_off.is_empty(), "putting the training wheels back on makes every word a button again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- At Server Room A's terminal -------------------------------------------------------

func _level_1() -> Node:
	_game().new_run(7)
	var level = load("res://scenes/level_1.tscn").instantiate()
	t.root.add_child(level)
	t.call("_lower_chapters_read", [level])
	for i in 20:
		await t.physics_frame
	level.terminal.locked = false
	_game().open_case("controller", "Which door controller keeps faulting?", ["door_controllers", "doors"], level.OBJ_CONTROLLER)
	_game().set_pieces("controller", level.controller_pieces(level.zone), level.CONTROLLER_QUERY, level.CONTROLLER_STEPS)
	_game().book_chapters.assign(["easy_sql_1", "easy_sql_2", "easy_sql_3", "easy_sql_4", "easy_sql_5", "easy_sql_6"])
	return level


func _step_up(level: Node) -> bool:
	_game().diegetic_ui = true  # the terminal on its own glass, the notebook in your hands
	var p = level.player
	p.global_position = level.terminal.stand_point.global_position + Vector3.UP * 0.05
	p.global_rotation = level.terminal.stand_point.global_rotation
	await _until(func(): return p.is_on_floor(), 3.0)
	await _frames(5)
	for i in 20:  # once the player's settled on the floor by the desk
		level.terminal._on_used(p)
		if p.is_using_terminal():
			break
		await _frames(3)
	var ok := await _until(func(): return level.terminal_ui.visible and level.terminal_ui.is_on_screen(), 6.0)
	return ok


func _done(level: Node) -> void:
	_game().diegetic_ui = false
	level.terminal_ui.close()
	await _frames(3)
	level.queue_free()
	await t.process_frame


func test_tables_page() -> void:
	print("Keyword buttons: the Tables page lists names first, columns once seen")
	var level = await _level_1()
	var ui: TerminalUI = level.terminal_ui
	ui.open(level.terminal, level.player)
	ui.run(".tables")
	await t.process_frame
	var g := _game()
	_check.call(g.notebook_tables.has("doors") and g.notebook_tables.doors.is_empty() and g.notebook_tables.door_controllers.is_empty(), ".tables writes down every table's name, and no columns")
	_check.call(KeywordHelp.found_columns(g).is_empty() and KeywordHelp.found_tables(g).has("doors"), "so the buttons offer the tables, but no columns yet")
	ui.run(".schema door_controllers")
	await t.process_frame
	var schema: Array = level.terminal.db.table_schema("door_controllers").map(func(c): return c["name"])
	_check.call(g.notebook_tables.door_controllers == schema and g.notebook_tables.doors.is_empty(), ".schema writes in that table's columns, and only that table's")
	ui.run("SELECT name FROM doors;")
	await t.process_frame
	_check.call(g.notebook_tables.doors == ["name"], "a query's own result columns go in (it typed and ran them)")
	ui.run("SELECT * FROM doors;")
	await t.process_frame
	_check.call(g.notebook_tables.doors.size() > 1 and g.notebook_tables.doors.has("zone"), "SELECT * writes in every column")
	ui.run(".tables")
	await t.process_frame
	_check.call(g.notebook_tables.doors.has("zone"), "and .tables again never wipes them")
	# A table piece found on the case board counts as found, before any query.
	g.new_run(8)
	g.open_case("memo", "What does the memo say?", ["memo_fragments"])
	g.set_pieces("memo", [{"id": "table", "label": "The table", "value": "memo_fragments", "task": "", "where": "", "seen_in": "memo_fragments"}], "SELECT * FROM {table};")
	g.collect_piece("memo", "table", "ScanRight")
	_check.call(KeywordHelp.found_tables(g) == ["memo_fragments"] and g.notebook_tables.is_empty(), "a table piece on the case board is offered after FROM, though the Tables page is still empty")
	g.set_pieces("memo", [{"id": "column", "label": "", "value": "extension", "task": "", "where": "", "seen_in": "staff_directory"}])
	g.discover_table("staff_directory", [])
	_check.call(not g.has_piece("memo", "column"), "a column piece isn't found by its table's name alone")
	g.discover_table("staff_directory", ["name", "extension"])
	_check.call(g.has_piece("memo", "column"), "it's found once that column is on the Tables page")
	await _done(level)


func test_counting_at_terminal() -> void:
	print("Keyword buttons: counting uses, and words coming off")
	var level = await _level_1()
	var ui: TerminalUI = level.terminal_ui
	var g := _game()
	var profile: Profile = _net().profile
	profile.reset_words()
	ui.open(level.terminal, level.player)
	ui.run("SELEC * FROM doors;")
	await t.process_frame
	_check.call(profile.uses_of("FROM") == 0, "a query with an error doesn't count")
	ui.run("SELECT * FROM doors;")
	ui.run("SELECT *  FROM doors;")
	await t.process_frame
	_check.call(profile.uses_of("SELECT") == 1 and profile.uses_of(";") == 1, "the same query twice counts once")
	ui.show_query(level.terminal, "SELECT id FROM door_controllers;", level.terminal.db.execute("SELECT id FROM door_controllers;"), 99)
	_check.call(profile.uses_of("SELECT") == 1, "a crewmate's query counts for nobody else")
	ui.run("SELECT id FROM doors;")
	await t.process_frame
	_check.call(profile.uses_of("SELECT") == 2 and profile.words_off.is_empty(), "two uses: still a button")
	# The third use is on the controller puzzle, still open: it waits.
	ui.run("SELECT name FROM doors;")
	await t.process_frame
	await t.process_frame
	_check.call(profile.uses_of("SELECT") == 3 and profile.words_off.is_empty() and g.words_waiting.get("SELECT", "?") == "controller",
		"the third use comes while the terminal's puzzle is open: the word waits (%s)" % [g.words_waiting])
	g.solve_case("controller", "found it")
	await t.process_frame
	_check.call(profile.words_off == ["SELECT", "FROM", ";"], "once it's solved, the words used 3 times come off (%s)" % [profile.words_off])
	var notice: String = level.hud._notice.text
	_check.call(notice.contains("No more training wheels! You've used ") and notice.contains("3 times or more. Now you type them yourself.") and notice.contains("Achievement: No More Training Wheels"),
		"with one notice for them all, and the achievement (%s)" % notice)
	_check.call(profile.earned.has("achievement:no_training_wheels") and not profile.earned.has("achievement:look_no_buttons"), "No More Training Wheels, not yet Look, No Buttons")
	var after := KeywordHelp.found_commands(g).filter(func(w): return not profile.words_off.has(w))
	_check.call(not after.has("SELECT") and after.has("WHERE"), "SELECT is off the buttons; WHERE isn't yet")
	# On Normal, words used 3 times don't come off; switching to Easy takes them all off at once.
	profile.reset_words()
	KeywordHelp.mode = "normal"
	for w in ["ORDER BY", "DESC", "LIMIT"]:
		for i in 3:
			profile.use_words([w])
	ui._words_check()
	_check.call(profile.words_off.is_empty(), "on Normal no button comes off (there are none)")
	KeywordHelp.mode = "easy"
	ui._words_check()
	_check.call(profile.words_off == ["ORDER BY", "DESC", "LIMIT"] and level.hud._notice.text.begins_with("No more training wheels! You've used ORDER BY, DESC and LIMIT 3 times or more."),
		"switching to Easy takes off every word used 3 times or more, with one notice")
	# A pad: nothing comes off, and tapped words don't count.
	profile.reset_words()
	InputGlyphs.pad = true
	for i in 3:
		profile.use_words(["WHERE"])
	ui._words_check()
	_check.call(profile.words_off.is_empty(), "on a pad, no button comes off however often it's used")
	ui._input.text = ""
	ui.insert_word("SELECT")
	ui._input.text += "id FROM doors WHERE locked = 1;"
	ui._submit()
	await t.process_frame
	_check.call(profile.uses_of("SELECT") == 0 and profile.uses_of("WHERE") == 4, "on a pad, a tapped word doesn't count; a typed one does")
	InputGlyphs.pad = false
	profile.reset_words()
	await _done(level)


func test_look_down() -> void:
	print("Keyword buttons: looking down at your notebook at a terminal (keyboard)")
	var level = await _level_1()
	var ui: TerminalUI = level.terminal_ui
	var p = level.player
	_net().profile.reset_words()
	_check.call(await _step_up(level), "stepping up to the terminal puts it on the glass")
	var book := ui.book
	_check.call(book.is_open() and not book.down and book.held != null and book.held.visible, "the notebook's held below the screen, not looked at yet")
	_check.call(book._hint.visible and book._hint.text == "[Tab] Look down: your notebook", "a hint below the screen says how to look down at it")
	var cam_before: Transform3D = p.camera.global_transform
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	ui._on_input_key(tab)
	await _until(func(): return book.amount >= 1.0, 2.0)
	await _frames(2)
	_check.call(book.down and p.terminal_look > 0.99 and p.camera.global_transform.basis.z.y > cam_before.basis.z.y + 0.2, "Tab: you look down (the view tips down)")
	_check.call(not level.terminal.screen.keyboard.visible, "the terminal's keyboard is out of the way of the book")
	_check.call(book._prompt_box.visible and book._prompts.text.contains("Tab  Look up at the screen") and book._prompts.text.contains("Esc  Step away") and not book._hint.visible,
		"looked down, the keys to look up and to step away are both on screen")
	_check.call(ui._input.has_focus() or ui.visible, "the typing line still has the keys")
	_check.call(book.tab == "Commands" and book.words() == ["SELECT", ".tables", ".schema"], "nothing typed: the Commands tab, with what can start a query (%s)" % [book.words()])
	_check.call(_page_text(book.view.left).contains(level.OBJ_CONTROLLER) and _page_text(book.view.left).contains("SELECT id FROM"), "the left page has the case and its query so far")
	var dots: Label = book.chips[0].box.find_child("Uses", true, false)
	_check.call(dots != null and dots.text == "○○○", "each command shows its uses out of 3")
	book.pick(0)
	await t.process_frame
	_check.call(ui._input.text == "SELECT ", "clicking a word writes it into the typing line, as if typed")
	ui.run(".tables")
	ui.run(".schema door_controllers")
	book.refresh(true)
	var cols: Array = level.terminal.db.table_schema("door_controllers").map(func(c): return c["name"])
	cols.sort()
	_check.call(book.tab == "Columns" and book.words() == cols, "after SELECT: the Columns tab, only the columns seen: door_controllers' (%s)" % [book.words()])
	# Clicking a word on the page through the pointer, the way a player does.
	var box: Control = book.chips[0].box
	await _frames(3)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = box.size / 2
	box.gui_input.emit(press)
	await t.process_frame
	_check.call(ui._input.text == "SELECT id ", "a click on a column's button writes it")
	ui._input.text += "FROM "
	ui._input.set_caret_column(ui._input.text.length())
	ui._typed()
	_check.call(book.tab == "Tables" and book.words().size() == level.terminal.db.table_names().size(), "after FROM: the Tables tab, with every table")
	book._on_tab("Commands")
	_check.call(book.tab == "Commands" and book.words().is_empty() and _page_text(book.view.right).contains("Nothing on this tab can come next."), "turning to a tab by hand shows its words, here none")
	# Normal: the case and the query, no buttons.
	KeywordHelp.mode = "normal"
	book.refresh(true)
	_check.call(book.view._tab_buttons.is_empty() and book.chips.is_empty() and _page_text(book.view.left).contains("SELECT id FROM"), "on Normal: the case and its query so far, no tabs and no buttons")
	KeywordHelp.mode = "easy"
	ui._on_input_key(tab)
	await _until(func(): return book.amount <= 0.0, 2.0)
	_check.call(not book.down and p.terminal_look == 0.0 and level.terminal.screen.keyboard.visible and book._hint.visible, "Tab again: back up at the screen, with the keyboard back")
	ui._on_input_key(tab)
	await _until(func(): return book.amount >= 1.0, 2.0)
	ui.close()
	await _until(func(): return p.terminal_look == 0.0 and not p.is_using_terminal(), 3.0)
	_check.call(not book.is_open() and not book._layer.visible and p.terminal_look == 0.0 and level.terminal.screen.keyboard.visible, "stepping away while looking down puts it all away, and the view comes back up as you step back")
	await _done(level)


func test_look_down_on_pad() -> void:
	print("Keyword buttons: looking down at your notebook at a terminal (pad)")
	var level = await _level_1()
	var ui: TerminalUI = level.terminal_ui
	_net().profile.reset_words()
	for i in 3:
		_net().profile.use_words(["SELECT"])
	_net().profile.words_off.append("SELECT")
	_check.call(await _step_up(level), "stepping up to the terminal")
	InputGlyphs.pad = true
	var book := ui.book
	book.refresh(true)
	var view := InputEventJoypadButton.new()
	view.button_index = JOY_BUTTON_BACK
	view.pressed = true
	_check.call(ui._on_pad(view) and book.down, "View: look down at the notebook")
	_check.call(book._prompts.text.contains("View  Look up") and book._prompts.text.contains("B  Step away"), "looked down, the pad's buttons to look up and step away are on screen (%s)" % book._prompts.text)
	_check.call(book.words().has("SELECT"), "on a pad the buttons never come off, even a word that came off on the keyboard")
	_check.call(book.chips[0].box.get_theme_stylebox("panel").border_color == TerminalNotebook.FOCUS_EDGE, "the tile the d-pad is on is lit")
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	ui._on_pad(right)
	_check.call(book.focus == 1, "the d-pad moves along the tiles")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	var lit: String = book.chips[1].word
	ui._on_pad(a)
	_check.call(ui._input.text.strip_edges() == lit, "A writes the lit word in (%s)" % ui._input.text)
	ui._input.text = ""
	ui._typed()
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	var was := book.tab
	ui._on_pad(rb)
	_check.call(book.tab != was, "RB turns the tabs")
	_check.call(_page_text(book.view.left).contains("SELECT id FROM"), "on Easy the case's query shows")
	KeywordHelp.mode = "normal"
	book.refresh(true)
	_check.call(not _page_text(book.view.left).contains("SELECT id FROM") and not book.view._tab_buttons.is_empty(), "on Normal the query doesn't, and the buttons stay")
	KeywordHelp.mode = "easy"
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	ui._on_pad(b)
	await _frames(3)
	_check.call(not ui.visible and not book.is_open(), "B steps away")
	InputGlyphs.pad = false
	_net().profile.reset_words()
	await _done(level)


func test_paper_word() -> void:
	print("Keyword buttons: a word learned off a paper")
	_game().new_run(3)
	var d := Document.new()
	d.words = ["IS NULL"]
	t.root.add_child(d)
	d._report_read(null)
	_check.call(_game().learned_words.has("IS NULL") and KeywordHelp.found_commands(_game()).has("IS NULL"), "reading Mercer's card puts IS NULL on the buttons")
	var l3: GDScript = load("res://scripts/levels/level_3.gd")
	_check.call(l3.source_code.contains("card.words = [\"IS NULL\"]"), "floor 18's card is the paper that teaches it")
	d.queue_free()
	await t.process_frame


func _page_text(page: Node) -> String:
	var out := []
	for n in page.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return "\n".join(out)
