class_name TerminalLook
extends RefCounted
## How a terminal's screen looks: the color behind the text (a "screen") and a
## text theme, which colors each kind of word its own way, as Prettier colors
## code (plan/overhaul-v0.10.md, item 5). Both are picked in the lobby's Gear tab
## (Cosmetics slots "screen" and "terminal"); a shared screen shows the first
## seated player's pair (TerminalMirror).
##
## Terminal text is bbcode written once in the standard colors (STANDARD) and
## shared by the crew; each screen recolors it to its look when it draws it
## (recolor()), so a teammate's theme never changes what's stored.
##
##   var look := TerminalLook.of(loadout.terminal, loadout.screen)
##   label.text = TerminalLook.recolor(bbcode, look)

## The colors terminal text is written in, by what the words are. "text" is the
## plain phosphor (no tag); the rest appear as [color=#...] in the bbcode.
const STANDARD := {
	"text": "73ff8c",  # TerminalScreen.PHOSPHOR
	"keyword": "ffcc59",  # TerminalUI.KEYWORD
	"string": "99ffff",  # text in quotes (as the input line colors it)
	"number": "b3d9ff",
	"echo": "ffffff",  # a typed query, and the name in front of it
	"head": "ffd27f",  # a result's header row (TerminalUI.TABLE_HEAD)
	"rule": "4f8a5c",
	"row": "e2ffe6",
	"row2": "8fdca2",
	"hint": "7fd4ff",  # SYSOP (TerminalUI.HINT)
	"error": "ff6655",
	"dim": "6f8f6f",
	"dim2": "7fa88a",
}
## Roles that are shades of the phosphor: a theme that doesn't set them takes
## them from its own text color.
const PHOSPHOR_ROLES := ["text", "rule", "row", "row2", "dim", "dim2"]

## Text themes (Cosmetics slot "terminal"): the roles each one sets. Its plain
## text is its finish in CharacterLooks.FIXED_COLORS ("phosphor": the player's own
## picked color), and the roles it doesn't set follow that the way a tinted
## phosphor does (TerminalScreen.reskin).
const THEMES := {
	"phosphor": {},
	"amber": {},
	"paper_white": {},
	"microfiche": {"keyword": "ffffff", "head": "e8f6ff"},
	"greenbar": {"keyword": "b6e3a0", "head": "b6e3a0", "rule": "6c8f5a"},
	"night_shift": {"keyword": "ffd27f", "string": "9fe8ff", "head": "ffd27f"},
	# New in v0.10 (names DRAFT, for Augustine).
	"highlighter": {"keyword": "ff6ac1", "string": "f3f99d", "number": "ff9f43",
		"echo": "9aedfe", "head": "57c7ff", "row": "f1f1f0", "row2": "c7c7c7", "rule": "5a5a5a",
		"hint": "9aedfe", "dim": "8a8a8a", "dim2": "a0a0a0"},
	"blueprint": {"keyword": "ffffff", "string": "a8d4ff", "number": "ffe08a",
		"echo": "ffffff", "head": "ffffff", "row": "eef4ff", "row2": "b9cff2", "rule": "7f9cc9", "hint": "ffe08a"},
}
## Screens (Cosmetics slot "screen"): the glass behind the text. "black" is the
## tube's own near-black, which takes a little of the text's color, as it always has.
const SCREENS := {
	"black": Color(0.015, 0.04, 0.02),
	"graphite": Color(0.1, 0.1, 0.11),
	"deep_blue": Color(0.02, 0.06, 0.2),
	"oxblood": Color(0.16, 0.03, 0.04),
	"paper": Color(0.9, 0.89, 0.84),
	"night_shift": Color(0.06, 0.04, 0.13),
}

static var _tag := RegEx.create_from_string("\\[color=#?([0-9a-fA-F]{3,8})\\]")
static var _echo := RegEx.create_from_string("(?s)\\[color=#ffffff\\]([^\\[\\n>]*> )(.*?)\\[/color\\]")
static var _sql_token := RegEx.create_from_string("('(?:[^']|'')*'?)|\\b(\\d+(?:\\.\\d+)?)\\b|\\b([A-Za-z_]+)\\b")


## A look: every role's Color, plus "bg" (the glass). `text_entry` and
## `screen_entry` are loadout entries ({item, color}); missing ones are the defaults.
static func of(text_entry: Variant = {}, screen_entry: Variant = {}) -> Dictionary:
	var t: Dictionary = text_entry if text_entry is Dictionary else {}
	var s: Dictionary = screen_entry if screen_entry is Dictionary else {}
	var theme := str(t.get("item", "phosphor"))
	if not THEMES.has(theme):
		theme = "phosphor"
	# The plain text: the theme's own finish (CharacterLooks.FIXED_COLORS), or the
	# phosphor in the player's picked color.
	var text: Color = CharacterLooks.terminal_skin(t if theme != "phosphor" or t.get("item") == "phosphor" else {})
	var set_roles: Dictionary = THEMES[theme]
	var look := {"theme": theme, "text": text}
	for role in STANDARD:
		if role == "text":
			continue
		if set_roles.has(role):
			look[role] = Color.html(set_roles[role])
		else:
			look[role] = TerminalScreen.reskin(Color.html(STANDARD[role]), text)
	var screen := str(s.get("item", "black"))
	if not SCREENS.has(screen):
		screen = "black"
	look.screen = screen
	look.bg = TerminalScreen.reskin(SCREENS.black, text) if screen == "black" else SCREENS[screen]
	if look.bg.get_luminance() > 0.5:
		_for_light_screen(look)
	return look


## The standard look: phosphor on black, as every terminal looked before themes.
static func standard() -> Dictionary:
	return of({}, {})


## On a light screen the light inks would vanish: every role goes dark, keeping its hue.
static func _for_light_screen(look: Dictionary) -> void:
	for role in STANDARD:
		var c: Color = look[role]
		var v := 0.18 if role in ["text", "echo", "row", "head", "keyword"] else 0.32
		look[role] = Color.from_hsv(c.h, clampf(c.s * 1.2, 0.0, 1.0) if c.s > 0.08 else 0.0, v)


## `bbcode` as it shows in `look`: each standard color swapped for the look's.
## Any other green turns to the look's text color, as a tinted phosphor always
## did (TerminalScreen.reskin); reds, ambers and whites keep theirs.
static func recolor(bbcode: String, look: Dictionary) -> String:
	bbcode = _highlight_echoes(bbcode)
	var by_hex := {}
	for role in STANDARD:
		by_hex[STANDARD[role]] = role
	var out := ""
	var at := 0
	for m in _tag.search_all(bbcode):
		out += bbcode.substr(at, m.get_start() - at)
		var hex := m.get_string(1).to_lower()
		var role = by_hex.get(hex)
		if role != null and look.has(role):
			out += "[color=#%s]" % look[role].to_html(false)
		elif Color.html_is_valid(hex) and look.has("text"):
			out += "[color=#%s]" % TerminalScreen.reskin(Color.html(hex), look.text).to_html()
		else:
			out += m.get_string()
		at = m.get_end()
	return out + bbcode.substr(at)


## Each typed query on screen (TerminalUI's echo: "[color=#ffffff]who> query[/color]",
## stored plain so the crew's shared transcript reads as typed) with its words colored.
static func _highlight_echoes(bbcode: String) -> String:
	var out := ""
	var at := 0
	for m in _echo.search_all(bbcode):
		out += bbcode.substr(at, m.get_start() - at)
		out += "[color=#%s]%s%s[/color]" % [STANDARD.echo, m.get_string(1), highlight_sql(m.get_string(2), TerminalUI.KEYWORDS)]
		at = m.get_end()
	return out + bbcode.substr(at)


## A typed query as it echoes on screen, in the standard colors: keywords,
## quoted text and numbers each their own, everything else the echo's white.
## `sql` is already escaped for bbcode ([ written as [lb]).
static func highlight_sql(sql: String, keywords: Array) -> String:
	var out := ""
	var at := 0
	for m in _sql_token.search_all(sql):
		out += sql.substr(at, m.get_start() - at)
		var word := m.get_string()
		if m.get_string(1) != "":
			out += "[color=#%s]%s[/color]" % [STANDARD.string, word]
		elif m.get_string(2) != "":
			out += "[color=#%s]%s[/color]" % [STANDARD.number, word]
		elif word.to_upper() in keywords:
			out += "[color=#%s]%s[/color]" % [STANDARD.keyword, word]
		else:
			out += word
		at = m.get_end()
	return out + sql.substr(at)
