extends RefCounted
## The script runner (scripts/ui/script_editor_ui.gd), nano-style and the terminal's
## .script command that opens it.

var _check: Callable
var _tree: SceneTree


func run(tree: SceneTree, check: Callable) -> void:
	_check = check
	_tree = tree
	print("Script runner")
	test_run_and_log()
	test_save()
	test_errors_mark_their_line()
	test_stop_and_keys()
	test_reopening()
	test_terminal_opens_runner()
	test_skins()


func check(cond: bool, name: String) -> void:
	_check.call(cond, name)


## An editor on the tree, open on a fresh JavaScript runtime.
func _editor(code: String, library: BuildingLibrary = null) -> ScriptEditorUI:
	var ed := ScriptEditorUI.new()
	_tree.root.add_child(ed)
	ed.open(ScriptRuntime.for_language("javascript"), {"title": "TEST", "library": library if library else BuildingLibrary.new(), "seed": 1, "code": code})
	return ed


## Code typed in, as a player would (setting text alone doesn't count as an edit).
func _type(ed: ScriptEditorUI, code: String) -> void:
	ed._code.text = code
	ed._code.text_changed.emit()


## Frames of `delta` until the script ends (or `frames` run out).
func _frames(ed: ScriptEditorUI, frames := 600, delta := 0.1) -> void:
	for i in frames:
		if not ed.runtime.is_running():
			return
		ed._process(delta)


## A key pressed while the runner is open, as the player would press it.
func _key(ed: ScriptEditorUI, keycode: Key, ctrl := true) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = keycode
	ev.ctrl_pressed = ctrl
	ed._input(ev)


func test_run_and_log() -> void:
	var ed := _editor("console.log(\"two:\", 1 + 1);\nconsole.warn(\"[b]careful[/b]\");")
	check(ed.visible and ed.code().begins_with("console.log") and not ed.is_modified(), "the runner opens showing the saved script it was given")
	check(ed._title.text.contains("TEST") and ed._title.text.contains("JAVASCRIPT"), "the title names what opened it and the language")
	check(ed._status.text == "ready" and ed._modified.text == "", "before running: ready, nothing modified")
	var bar := ed._keys.values().map(func(b): return b.get_child(0).get_child(0).get_child(0).text + " " + b.get_child(0).get_child(1).text)
	check(bar == ["^S Save", "^R Run", "^T Stop", "^Q Close"], "the key bar lists Save, Run, Stop and Close as nano does")
	_key(ed, KEY_R)
	_frames(ed)
	var log := ed.log_text()
	check(log.begins_with("--- running ---\ntwo: 2\n[b]careful[/b]\n--- finished after"), "Ctrl+R prints a start line, the script's lines (brackets kept as typed), then how long it took")
	check(ed._status.text == "finished", "after it ends the status says finished")
	ed.runtime.stop()

	ed = _editor("for (let i = 0; i < 500; i++) console.log(i);")
	ed.run()
	_frames(ed)
	var lines := ed.log_text().split("\n")
	check(lines.size() == ScriptEditorUI.LOG_LIMIT and lines[-1].begins_with("--- finished"), "the log keeps only its last %d lines" % ScriptEditorUI.LOG_LIMIT)
	ed.queue_free()


func test_save() -> void:
	var ed := _editor("console.log(1);")
	var seen: Array = []
	ed.saved.connect(func(c): seen.append(c))
	_type(ed, "console.log(2);\nconsole.log(3);")
	check(ed.is_modified() and ed._modified.text.contains("Modified") and seen.is_empty(), "an edit marks the script Modified and isn't kept yet")
	_key(ed, KEY_S)
	check(seen == ["console.log(2);\nconsole.log(3);"] and not ed.is_modified() and ed._modified.text == "", "Ctrl+S saves it, passes it on to be kept, and clears Modified")
	check(ed._status.text == "[ Saved, 2 lines. ]", "and says so on the status line")
	_key(ed, KEY_S, false)
	check(seen.size() == 1, "S without Ctrl is just typing")
	_type(ed, "console.log(4);")
	check(ed._status.text == "ready", "the next edit clears the message")
	ed.run()
	_frames(ed)
	check(seen.back() == "console.log(4);" and ed.saved_code == "console.log(4);" and ed.log_text().contains("4"), "Run saves unsaved edits first, so what runs is what's saved")
	ed.queue_free()


func test_errors_mark_their_line() -> void:
	var ed := _editor("console.log(\"ok\");\nlet = 5;")
	ed.run()
	check(not ed.runtime.is_running() and ed.error_line() == 2, "a mistake found before running marks its line")
	check(ed.log_text().begins_with("Line 2:") and ed.log_text().contains("2 | let = 5;"), "and the log shows the line with a caret, nothing run")
	check(ed._code.get_line_background_color(1).a > 0.0, "the marked line is tinted in the editor")
	_type(ed, "console.log(\"ok\");\nlet x = 5;")
	check(ed.error_line() == 0 and ed._code.get_line_background_color(1).a == 0.0, "editing clears the mark")

	_type(ed, "console.log(\"before\");\nconst door = null;\nconsole.log(door.locked);")
	ed.run()
	_frames(ed)
	check(ed.error_line() == 3 and ed._status.text == "stopped on an error", "an error while running marks its line too and says so")
	check(ed.log_text().contains("before") and ed.log_text().contains("Line 3:"), "lines printed before the error stay in the log")
	ed.queue_free()


func test_stop_and_keys() -> void:
	var ed := _editor("while (true) {\n  await sleep(500);\n}")
	_key(ed, KEY_T)
	check(ed._status.text == "[ Nothing is running. ]", "Stop is always there; with nothing running it says so")
	_key(ed, KEY_R)
	check(ed.runtime.is_running(), "Ctrl+R runs the script")
	ed.stop()
	_key(ed, KEY_ENTER)
	check(ed.runtime.is_running() and ed.log_text().count("--- running ---") == 2, "and so does Ctrl+Enter")
	_frames(ed, 30)
	check(ed.runtime.is_running() and ed._status.text.begins_with("waiting") and ed._keys[KEY_R].modulate.a < 1.0 and ed._keys[KEY_T].modulate.a == 1.0, "a waiting script shows waiting, with Run dimmed and Stop lit")
	var runs := ed.log_text().count("--- running ---")
	ed.run()
	check(ed.log_text().count("--- running ---") == runs, "Run does nothing while a script is running")
	_key(ed, KEY_T)
	check(not ed.runtime.is_running() and ed._status.text == "stopped" and ed.log_text().contains("--- stopped after 3.0 s ---"), "Ctrl+T stops it and says when")

	var closed := [0]
	ed.closed.connect(func(): closed[0] += 1)
	ed.run()
	_key(ed, KEY_ESCAPE, false)
	check(closed[0] == 1 and not ed.visible, "Esc closes the runner")
	ed._process(0.5)
	check(ed.runtime.is_running() and ed.runtime.clock() >= 0.5, "a script keeps running (and ticking) after the runner closes")
	_key(ed, KEY_T)
	check(ed.runtime.is_running(), "keys do nothing while the runner is closed")
	ed.open(ed.runtime, {"title": "TEST"})
	_key(ed, KEY_Q)
	check(closed[0] == 2 and not ed.visible, "Ctrl+Q closes it too")
	ed.stop()

	ed.open(ed.runtime, {"title": "TEST", "ticks": false})
	ed.run()
	ed._process(0.5)
	check(ed.runtime.is_running() and ed.runtime.clock() == 0.0, "with ticks off the runner leaves ticking to whoever owns the runtime")
	ed.stop()
	ed.queue_free()


func test_reopening() -> void:
	var ed := _editor("console.log(\"first\");")
	var first := ed.runtime
	ed.run()
	_frames(ed)
	_type(ed, "console.log(\"unsaved\");")
	ed.close()
	ed.open(first, {"title": "TEST", "code": "ignored"})
	check(ed.log_text().contains("first") and ed.code() == "console.log(\"unsaved\");" and ed.is_modified(), "reopening on the same runtime keeps its log and unsaved edits")
	var other := ScriptRuntime.for_language("javascript")
	ed.open(other, {"title": "OTHER", "code": "console.log(\"second\");"})
	check(ed.log_text() == "" and ed.code() == "console.log(\"second\");" and not ed.is_modified() and ed._title.text.contains("OTHER"), "a different runtime starts clean with its own saved script")
	ed.run()
	_frames(ed)
	check(not first.printed.get_connections().any(func(c): return c.callable.get_object() == ed), "the runner lets go of a runtime it no longer shows")
	check(ed.log_text().contains("second") and not ed.log_text().contains("first"), "and only the shown runtime's lines reach the log")

	# A runtime that's already running and keeps its own log (co-op's stand-in for the host's script).
	var gd := GDScript.new()
	gd.source_code = "extends ScriptRuntime\nfunc language(): return \"javascript\"\nfunc is_running(): return true\nfunc log_history(): return [[\"door [1] open\", \"log\"], [\"slow\", \"warn\"]]\n"
	gd.reload()
	ed.open(gd.new(), {"title": "TEST"})
	check(ed.log_text() == "--- running ---\ndoor [1] open\nslow", "opened mid-run, the runner shows the running line and what was logged so far")
	ed.runtime = null
	ed.queue_free()


func test_terminal_opens_runner() -> void:
	var host := Node3D.new()
	_tree.root.add_child(host)
	var ui := TerminalUI.new()
	host.add_child(ui)
	var t := Terminal.spawn(host, Vector3.ZERO, 0, "COLD STORE 2", FacilityDB.new(), ui)
	ui.terminal = t
	ui.run(".help")
	check(not "\n".join(t.transcript).contains(".script"), ".help doesn't list .script on a terminal without scripts")
	ui.run(".script")
	check(TerminalUI._plain(t.transcript[-1]).contains("Unknown command .script") and ui._editor == null, "and .script there is an unknown command")

	t.set_meta("scripts", true)
	ui.run(".help")
	check("\n".join(t.transcript).contains(".script"), ".help lists .script where the level allows scripts")
	ui.run(".script")
	var ed := ui._editor
	check(ed != null and ed.visible and ed._title.text.contains("COLD STORE 2"), ".script opens the runner, titled with the terminal's name")
	check(ed.runtime == t.get_meta("script_runtime") and ed.runtime.language() == "javascript", "the terminal keeps its own JavaScript runtime")
	_type(ed, "await sleep(1000);\nconsole.log(\"done\");")
	check(not t.has_meta("script_code"), "unsaved edits aren't kept on the terminal")
	ed.save()
	check(t.get_meta("script_code") == ed.code(), "saving keeps the script on the terminal")
	ed.run()
	ed.close()
	ed._process(0.4)
	ui.run(".script")
	check(ed.runtime.is_running() and t.get_meta("script_code") == ed.code() and ed.log_text().contains("--- running ---"), "back at the terminal, .script shows the same script still running")

	var t2 := Terminal.spawn(host, Vector3(3, 0, 0), 0, "LOBBY", FacilityDB.new(), ui)
	t2.set_meta("scripts", true)
	ui.terminal = t2
	ui.run(".script")
	check(ed.code() == "" and ed.runtime != t.get_meta("script_runtime"), "another terminal has its own runner state")
	check((t.get_meta("script_runtime") as ScriptRuntime).is_running(), "while the first terminal's script carries on")
	(t.get_meta("script_runtime") as ScriptRuntime).stop()
	host.queue_free()


## Players' unlocked terminal skins color the runner too, as they do the screen.
func test_skins() -> void:
	var host := Node3D.new()
	_tree.root.add_child(host)
	var ui := TerminalUI.new()
	host.add_child(ui)
	var t := Terminal.spawn(host, Vector3.ZERO, 0, "COLD STORE 2", FacilityDB.new(), ui)
	t.set_meta("scripts", true)
	ui.terminal = t
	ui.run(".script")
	var ed := ui._editor
	var looks_default := func() -> bool:
		return ed._top_style.bg_color == ThemeUtil.GREEN and ed._back.color == ScriptEditorUI.INK \
			and ed._code.get_theme_color("font_color") == ScriptEditorUI.CODE_TEXT \
			and ed._code.get_theme_color("background_color") == ScriptEditorUI.CODE_BACK \
			and ed._status.get_theme_color("font_color") == ThemeUtil.DIM \
			and ed._colored(["x", "log"]).contains("bfffc8") and not ed._code.has_theme_color_override("font_placeholder_color")
	check(looks_default.call(), "on the default phosphor skin the runner looks as it always has")

	var amber := CharacterLooks.terminal_skin({"item": "amber"})
	t.skin_color = amber
	ui.run(".script")
	check(ed.skin == amber and ed._top_style.bg_color == TerminalScreen.reskin(ThemeUtil.GREEN, amber) and ed._top_style.bg_color != ThemeUtil.GREEN,
		"opened from an amber terminal, the title bar takes the terminal's skin")
	check(ed._code.get_theme_color("font_color") == TerminalScreen.reskin(ScriptEditorUI.CODE_TEXT, amber) and ed._colored(["x", "log"]).contains(TerminalScreen.reskin(ScriptEditorUI.COLORS.log, amber).to_html(false)),
		"and so do the code text and the log")
	var h := ed._code.syntax_highlighter as CodeHighlighter
	check(h.get_keyword_color("let") == Color(1.0, 0.8, 0.35) and ed._colored(["x", "error"]).contains("ff6655"), "keywords and errors keep their own colors on any skin")
	for sk in [amber, Color(0.15, 0.25, 1.0), Color(1, 1, 1)]:
		var text := TerminalScreen.reskin(ScriptEditorUI.CODE_TEXT, sk).get_luminance()
		var back := TerminalScreen.reskin(ScriptEditorUI.CODE_BACK, sk).get_luminance()
		check((text + 0.05) / (back + 0.05) >= 4.5, "code text stays readable on a %s skin (contrast %.1f)" % [sk.to_html(false), (text + 0.05) / (back + 0.05)])
	t.skin_color = TerminalScreen.PHOSPHOR
	ui.run(".script")
	check(looks_default.call(), "and back on a phosphor terminal it's the default again")
	host.queue_free()
