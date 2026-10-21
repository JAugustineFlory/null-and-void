class_name StrictJSON
extends RefCounted
## A JSON reader that accepts only real JSON (Godot's own allows trailing commas)
## and says what's wrong in plain words, pointing at the line. Request bodies on
## the facility API go through it (and, later, JSON.parse in deck scripts).
##
## StrictJSON.parse('{"locked": false}')
##   -> {ok: true, value: {"locked": false}}
##   -> {ok: false, line: 1, col: 12, message: "..."} when it isn't JSON

var _s: String
var _i := 0
var _err := {}


static func parse(text: String) -> Dictionary:
	var p := StrictJSON.new()
	p._s = text
	p._ws()
	if p._i >= text.length():
		return p._result(null, "There's no JSON here: it's empty.")
	var v = p._value()
	if p._err.is_empty():
		p._ws()
		if p._i < text.length():
			p._fail("Something is left over after the JSON ends: %s" % p._near())
	return p._result(v, "")


func _result(v: Variant, message: String) -> Dictionary:
	if message != "":
		_fail(message)
	if not _err.is_empty():
		return {"ok": false, "line": _err.line, "col": _err.col, "message": _err.message}
	return {"ok": true, "value": v}


func _value() -> Variant:
	if not _err.is_empty():
		return null
	_ws()
	if _i >= _s.length():
		return _fail("The JSON ends too soon. Is a } or ] missing?")
	var c := _s[_i]
	match c:
		"{":
			return _object()
		"[":
			return _array()
		"\"":
			return _string()
		"'":
			return _fail("JSON text needs double quotes (\"), not single quotes (').")
		"t":
			return _word("true", true)
		"f":
			return _word("false", false)
		"n":
			return _word("null", null)
		"T", "F", "N":
			return _fail("Use lowercase true, false and null in JSON.")
	if c == "-" or (c >= "0" and c <= "9"):
		return _number()
	if c == "}" or c == "]" or c == ",":
		return _fail("A value is missing before %s." % c)
	return _fail("%s isn't a JSON value. Text needs double quotes: \"like this\"." % _near())


func _object() -> Variant:
	var out := {}
	_i += 1
	_ws()
	if _peek() == "}":
		_i += 1
		return out
	while true:
		_ws()
		var c := _peek()
		if c == "}":
			return _fail("There's an extra comma before }.")
		if c == "'":
			return _fail("Property names need double quotes (\"), not single quotes (').")
		if c != "\"":
			if c == "":
				return _fail("The JSON ends before this { is closed with }.")
			return _fail("Property names need double quotes: \"%s\": ..." % _near_word())
		var key: String = _string()
		if not _err.is_empty():
			return null
		_ws()
		if _peek() != ":":
			return _fail("Put a : after \"%s\"." % key)
		_i += 1
		out[key] = _value()
		if not _err.is_empty():
			return null
		_ws()
		c = _peek()
		if c == ",":
			_i += 1
			continue
		if c == "}":
			_i += 1
			return out
		if c == "":
			return _fail("The JSON ends before this { is closed with }.")
		return _fail("A comma is missing between properties.")
	return out


func _array() -> Variant:
	var out := []
	_i += 1
	_ws()
	if _peek() == "]":
		_i += 1
		return out
	while true:
		_ws()
		if _peek() == "]":
			return _fail("There's an extra comma before ].")
		out.append(_value())
		if not _err.is_empty():
			return null
		_ws()
		var c := _peek()
		if c == ",":
			_i += 1
			continue
		if c == "]":
			_i += 1
			return out
		if c == "":
			return _fail("The JSON ends before this [ is closed with ].")
		return _fail("A comma is missing between list items.")
	return out


func _string() -> Variant:
	_i += 1
	var out := ""
	while true:
		if _i >= _s.length() or _s[_i] == "\n":
			return _fail("This text never ends: close it with \".")
		var c := _s[_i]
		if c == "\"":
			_i += 1
			return out
		if c == "\\":
			_i += 1
			var e := _peek()
			match e:
				"\"", "\\", "/":
					out += e
				"n":
					out += "\n"
				"t":
					out += "\t"
				"r":
					out += "\r"
				"b":
					out += char(8)
				"f":
					out += char(12)
				"u":
					var hex := _s.substr(_i + 1, 4)
					if hex.length() < 4 or not hex.is_valid_hex_number():
						return _fail("\\u needs four hex digits, like \\u00e9.")
					out += char(hex.hex_to_int())
					_i += 4
				_:
					return _fail("\\%s isn't a JSON escape." % e)
			_i += 1
			continue
		out += c
		_i += 1
	return out


func _number() -> Variant:
	var start := _i
	if _peek() == "-":
		_i += 1
	while _i < _s.length() and (_s[_i] >= "0" and _s[_i] <= "9" or _s[_i] in [".", "e", "E", "+", "-"]):
		_i += 1
	var text := _s.substr(start, _i - start)
	var re := RegEx.create_from_string("^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$")
	if re.search(text) == null:
		_i = start
		return _fail("%s isn't a JSON number." % text)
	if text.contains(".") or text.contains("e") or text.contains("E"):
		return text.to_float()
	return text.to_int() if text.length() < 16 else text.to_float()


func _word(word: String, v: Variant) -> Variant:
	if _s.substr(_i, word.length()) == word:
		_i += word.length()
		return v
	return _fail("%s isn't a JSON value. Text needs double quotes: \"like this\"." % _near_word())


func _ws() -> void:
	while _i < _s.length() and _s[_i] in [" ", "\t", "\n", "\r"]:
		_i += 1


func _peek() -> String:
	return _s[_i] if _i < _s.length() else ""


func _near() -> String:
	var w := _near_word()
	return w if w != "" else _peek()


func _near_word() -> String:
	var j := _i
	while j < _s.length() and not _s[j] in [" ", "\t", "\n", "\r", ",", ":", "}", "]", "{", "["]:
		j += 1
	return _s.substr(_i, mini(j - _i, 20))


func _fail(message: String) -> Variant:
	if _err.is_empty():
		var before := _s.substr(0, _i)
		var line := before.count("\n") + 1
		var col := _i - before.rfind("\n")
		_err = {"line": line, "col": col, "message": message}
	_i = _s.length()
	return null
