class_name JSParser
extends RefCounted
## Turns the JavaScript players type on a deck into a tree of Dictionaries, one per
## statement or expression, each with "k" (its kind) and "line". Only the taught
## subset parses; everything else stops with a plain message that names the line,
## so a program that parses here is always real JavaScript.
##
## var p := JSParser.new(source)
## var tree := p.parse()        # {} if p.error is set: {line, col, message}

const RESERVED := ["let", "const", "var", "function", "return", "if", "else", "while", "for", "of",
	"break", "continue", "true", "false", "null", "typeof", "async", "await", "new", "class", "this",
	"switch", "case", "default", "do", "try", "catch", "finally", "throw", "delete", "void", "in",
	"instanceof", "yield", "import", "export", "with", "debugger", "super", "extends", "enum"]
## Real JavaScript the deck doesn't run yet, and what to say when it turns up.
const NOT_YET := {
	"var": "Use let (or const) instead of var.",
	"new": "new isn't available on this deck.",
	"class": "Classes aren't available on this deck.",
	"this": "this isn't available on this deck.",
	"switch": "switch isn't available on this deck yet. Use if / else if.",
	"do": "do ... while isn't available on this deck. Use while.",
	"try": "try / catch isn't available on this deck yet.",
	"throw": "throw isn't available on this deck yet. assert() stops a script with a message.",
	"delete": "delete isn't available on this deck.",
	"import": "import isn't available on this deck.",
	"export": "export isn't available on this deck.",
}
const PUNCT := ["===", "!==", "**=", "...", "&&=", "||=", "??=", "==", "!=", "<=", ">=", "&&", "||",
	"??", "?.", "=>", "++", "--", "+=", "-=", "*=", "/=", "%=", "**", "{", "}", "(", ")", "[", "]",
	";", ",", ".", "<", ">", "+", "-", "*", "/", "%", "=", "!", "?", ":", "&", "|", "^", "~"]
const BINARY := {"??": 4, "||": 5, "&&": 6, "==": 10, "!=": 10, "===": 10, "!==": 10,
	"<": 11, ">": 11, "<=": 11, ">=": 11, "+": 13, "-": 13, "*": 14, "/": 14, "%": 14, "**": 15}
const ASSIGN := ["=", "+=", "-=", "*=", "/=", "%=", "**="]

var src: String
var error := {}
var _toks: Array = []
var _i := 0
var _line0 := 0
var _col0 := 0
var _async_depth := 0  # > 0 inside an async function or at the top level
var _fn_depth := 0
var _loop_depth := 0


func _init(source: String, line0 := 0, col0 := 0) -> void:
	src = source
	_line0 = line0
	_col0 = col0


## The whole program, as {k: "Program", body: [...]}. Top-level await is allowed,
## as in a JavaScript module.
func parse() -> Dictionary:
	if not _lex():
		return {}
	_async_depth = 1
	var body := []
	while not _at("eof"):
		var s := _statement()
		if error:
			return {}
		body.append(s)
	return {"k": "Program", "body": body, "line": 1}


# --- lexer -------------------------------------------------------------------

func _lex() -> bool:
	var i := 0
	var line := 1 + _line0
	var col := 1 + _col0
	var nl := true
	var n := src.length()
	while i < n:
		var c := src[i]
		if c == "\n":
			i += 1
			line += 1
			col = 1
			nl = true
			continue
		if c == " " or c == "\t" or c == "\r":
			i += 1
			col += 1
			continue
		if c == "/" and i + 1 < n and src[i + 1] == "/":
			while i < n and src[i] != "\n":
				i += 1
			continue
		if c == "/" and i + 1 < n and src[i + 1] == "*":
			var end := src.find("*/", i + 2)
			if end < 0:
				return _lex_fail(line, col, "This /* comment is never closed with */.")
			for j in range(i, end + 2):
				if src[j] == "\n":
					line += 1
					col = 0
					nl = true
				col += 1
			i = end + 2
			continue
		var tok := {"line": line, "col": col, "nl": nl}
		nl = false
		var start := i
		if _is_digit(c) or (c == "." and i + 1 < n and _is_digit(src[i + 1])):
			while i < n and (_is_digit(src[i]) or src[i] == "." or src[i] == "_"):
				i += 1
			if i < n and (src[i] == "e" or src[i] == "E"):
				i += 1
				if i < n and (src[i] == "+" or src[i] == "-"):
					i += 1
				while i < n and _is_digit(src[i]):
					i += 1
			var text := src.substr(start, i - start).replace("_", "")
			if text.count(".") > 1 or not text.is_valid_float():
				return _lex_fail(line, col, "%s isn't a number." % text)
			if i < n and _is_ident_char(src[i]):
				return _lex_fail(line, col, "A name can't start with a digit.")
			tok["t"] = "num"
			tok["v"] = text.to_float()
		elif _is_ident_start(c):
			while i < n and _is_ident_char(src[i]):
				i += 1
			var word := src.substr(start, i - start)
			tok["t"] = "kw" if word in RESERVED else "name"
			tok["v"] = word
		elif c == "\"" or c == "'":
			var s := ""
			i += 1
			while true:
				if i >= n or src[i] == "\n":
					return _lex_fail(line, col, "This text never ends: close it with %s on the same line." % c)
				if src[i] == c:
					i += 1
					break
				if src[i] == "\\":
					if i + 1 >= n:
						return _lex_fail(line, col, "This text never ends: close it with %s on the same line." % c)
					s += _escape(src[i + 1])
					i += 2
					continue
				s += src[i]
				i += 1
			tok["t"] = "str"
			tok["v"] = s
		elif c == "`":
			var parts := []  # String or {src, line, col}
			var s := ""
			i += 1
			var l := line
			var cc := col + 1
			while true:
				if i >= n:
					return _lex_fail(line, col, "This template text never ends: close it with `.")
				var ch := src[i]
				if ch == "`":
					i += 1
					break
				if ch == "\\" and i + 1 < n:
					s += _escape(src[i + 1])
					i += 2
					cc += 2
					continue
				if ch == "$" and i + 1 < n and src[i + 1] == "{":
					parts.append(s)
					s = ""
					var depth := 1
					var j := i + 2
					while j < n and depth > 0:
						if src[j] == "{":
							depth += 1
						elif src[j] == "}":
							depth -= 1
						j += 1
					if depth > 0:
						return _lex_fail(l, cc, "This ${ is never closed with }.")
					parts.append({"src": src.substr(i + 2, j - 1 - (i + 2)), "line": l, "col": cc + 2})
					for k in range(i, j):
						if src[k] == "\n":
							l += 1
							cc = 0
						cc += 1
					i = j
					continue
				if ch == "\n":
					l += 1
					cc = 0
				s += ch
				cc += 1
				i += 1
			parts.append(s)
			tok["t"] = "tpl"
			tok["v"] = parts
			col = cc
			line = l
			_toks.append(tok)
			continue
		else:
			var found := ""
			for p in PUNCT:
				if src.substr(i, p.length()) == p:
					found = p
					break
			if found == "":
				return _lex_fail(line, col, "%s can't be used here." % c)
			i += found.length()
			tok["t"] = "op"
			tok["v"] = found
		col += i - start
		_toks.append(tok)
	_toks.append({"t": "eof", "v": "", "line": line, "col": col, "nl": true})
	return true


func _escape(c: String) -> String:
	match c:
		"n": return "\n"
		"t": return "\t"
		"r": return "\r"
	return c


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


static func _is_ident_start(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_" or c == "$"


static func _is_ident_char(c: String) -> bool:
	return _is_ident_start(c) or _is_digit(c)


# --- statements --------------------------------------------------------------

func _statement() -> Dictionary:
	var t := _peek()
	var line: int = t.line
	if t.t == "kw":
		if NOT_YET.has(t.v):
			return _fail(t, NOT_YET[t.v])
		match t.v:
			"let", "const":
				var d := _declaration()
				_semi()
				return d
			"function":
				return _function_decl(false)
			"async":
				if _peek(1).v == "function":
					_next()
					return _function_decl(true)
			"return":
				_next()
				if _fn_depth == 0:
					return _fail(t, "return only works inside a function.")
				var arg = null
				if not _at_op(";") and not _at_op("}") and not _at("eof") and not _peek().nl:
					arg = _expression()
				_semi()
				return {"k": "Return", "arg": arg, "line": line}
			"if":
				_next()
				_expect("(", "Put the condition in brackets: if (...)")
				var test := _expression()
				_expect(")", "Close the condition with )")
				var then := _statement()
				var other = null
				if _at_kw("else"):
					_next()
					other = _statement()
				return {"k": "If", "test": test, "then": then, "else": other, "line": line}
			"while":
				_next()
				_expect("(", "Put the condition in brackets: while (...)")
				var test := _expression()
				_expect(")", "Close the condition with )")
				return {"k": "While", "test": test, "body": _loop_body(), "line": line}
			"for":
				return _for()
			"break", "continue":
				_next()
				if _loop_depth == 0:
					return _fail(t, "%s only works inside a loop." % t.v)
				_semi()
				return {"k": "Break" if t.v == "break" else "Continue", "line": line}
	if _at_op("{"):
		return _block()
	if _at_op(";"):
		_next()
		return {"k": "Empty", "line": line}
	var e := _expression()
	_semi()
	return {"k": "Expr", "expr": e, "line": line}


func _block() -> Dictionary:
	var open := _peek()
	var line: int = open.line
	_expect("{", "This needs { } around its lines.")
	var body := []
	while not _at_op("}"):
		if _at("eof"):
			return _fail(open, "This { is never closed with }.")
		body.append(_statement())
		if error:
			return {}
	_next()
	return {"k": "Block", "body": body, "line": line}


func _loop_body() -> Dictionary:
	_loop_depth += 1
	var body := _statement()
	_loop_depth -= 1
	return body


func _declaration() -> Dictionary:
	var kw: String = _next().v
	var line: int = _peek().line
	var decls := []
	while true:
		var name_tok := _peek()
		if name_tok.t != "name":
			if name_tok.t == "op" and (name_tok.v == "{" or name_tok.v == "["):
				return _fail(name_tok, "Unpacking (let {a} = ...) isn't available on this deck yet.")
			return _fail(name_tok, "%s needs a name after it." % kw)
		_next()
		var init = null
		if _at_op("="):
			_next()
			init = _assignment()
		elif kw == "const" and not (_at_kw("of")):
			return _fail(name_tok, "const %s needs a value: const %s = ..." % [name_tok.v, name_tok.v])
		decls.append({"name": name_tok.v, "init": init, "line": name_tok.line})
		if not _at_op(","):
			break
		_next()
	return {"k": "Let", "kind": kw, "decls": decls, "line": line}


func _for() -> Dictionary:
	var line: int = _next().line
	_expect("(", "for needs brackets: for (...)")
	var init = null
	if _at_kw("let") or _at_kw("const"):
		if _peek(1).t == "name" and _peek(2).t == "kw" and _peek(2).v == "of":
			var kind: String = _next().v
			var name: String = _next().v
			_next()
			var iter := _expression()
			_expect(")", "Close the for with )")
			return {"k": "ForOf", "kind": kind, "name": name, "iter": iter, "body": _loop_body(), "line": line}
		if _peek(2).t == "kw" and _peek(2).v == "in":
			return _fail(_peek(2), "for ... in isn't available on this deck. Use for (const key of Object.keys(obj)).")
		init = _declaration()
	elif _at_kw("var"):
		return _fail(_peek(), NOT_YET["var"])
	elif not _at_op(";"):
		init = {"k": "Expr", "expr": _expression(), "line": line}
	_expect(";", "A for loop needs two ; inside its brackets: for (start; test; step)")
	var test = null if _at_op(";") else _expression()
	_expect(";", "A for loop needs two ; inside its brackets: for (start; test; step)")
	var update = null if _at_op(")") else _expression()
	_expect(")", "Close the for with )")
	return {"k": "For", "init": init, "test": test, "update": update, "body": _loop_body(), "line": line}


func _function_decl(is_async: bool) -> Dictionary:
	var line: int = _next().line
	var name_tok := _peek()
	if name_tok.t != "name":
		return _fail(name_tok, "A function needs a name: function name(...) { ... }")
	_next()
	var f := _function_rest(name_tok.v, is_async, line)
	f["k"] = "FuncDecl"
	return f


func _function_rest(name: String, is_async: bool, line: int) -> Dictionary:
	_expect("(", "A function's inputs go in brackets: function %s(a, b)" % name)
	var params := _params()
	if error:
		return {}
	return _function_body(name, params, is_async, false, line)


func _params() -> Array:
	var params := []
	while not _at_op(")"):
		var t := _peek()
		if t.t == "op" and t.v == "...":
			_fail(t, "Rest inputs (...args) aren't available on this deck.")
			return []
		if t.t != "name":
			_fail(t, "Inputs need plain names, separated by commas.")
			return []
		if t.v in params:
			_fail(t, "Two inputs are both called %s." % t.v)
			return []
		params.append(_next().v)
		if _at_op("="):
			_fail(_peek(), "Default values for inputs aren't available on this deck.")
			return []
		if not _at_op(")"):
			_expect(",", "Separate inputs with commas.")
			if error:
				return []
	_next()
	return params


func _function_body(name: String, params: Array, is_async: bool, arrow: bool, line: int) -> Dictionary:
	var saved_loop := _loop_depth
	var saved_async := _async_depth
	_loop_depth = 0
	_async_depth = 1 if is_async else 0
	_fn_depth += 1
	var body
	var expr_body := false
	if arrow and not _at_op("{"):
		body = _assignment()
		expr_body = true
	else:
		body = _block()
	_fn_depth -= 1
	_loop_depth = saved_loop
	_async_depth = saved_async
	return {"k": "Func", "name": name, "params": params, "body": body, "expr_body": expr_body,
		"async": is_async, "line": line}


# --- expressions -------------------------------------------------------------

func _expression() -> Dictionary:
	var e := _assignment()
	if _at_op(","):
		return _fail(_peek(), "Commas can't join expressions here. Use one statement per line.")
	return e


func _assignment() -> Dictionary:
	if error:
		return {}
	var arrow := _try_arrow()
	if not arrow.is_empty() or error:
		return arrow
	var left := _conditional()
	if _peek().t == "op" and _peek().v in ASSIGN:
		var op_tok := _next()
		if left.get("k") != "Ident" and left.get("k") != "Member" and left.get("k") != "Index":
			return _fail(op_tok, "The left side of %s must be a name or a property." % op_tok.v)
		if left.get("optional", false):
			return _fail(op_tok, "?. can't be on the left of %s." % op_tok.v)
		var value := _assignment()
		return {"k": "Assign", "op": op_tok.v, "target": left, "value": value, "line": op_tok.line}
	return left


## x => ..., (a, b) => ..., async x => ...; {} when the next tokens aren't an arrow function.
func _try_arrow() -> Dictionary:
	var j := _i
	var is_async := false
	if _toks[j].t == "kw" and _toks[j].v == "async" and not _toks[j + 1].nl:
		is_async = true
		j += 1
	var line: int = _toks[j].line
	if _toks[j].t == "name" and _toks[j + 1].t == "op" and _toks[j + 1].v == "=>":
		_i = j + 2
		return _function_body("", [_toks[j].v], is_async, true, line)
	if _toks[j].t == "op" and _toks[j].v == "(":
		var depth := 0
		var k := j
		while k < _toks.size():
			var t: Dictionary = _toks[k]
			if t.t == "op" and (t.v == "(" or t.v == "[" or t.v == "{"):
				depth += 1
			elif t.t == "op" and (t.v == ")" or t.v == "]" or t.v == "}"):
				depth -= 1
				if depth == 0:
					break
			elif t.t == "eof":
				return {}
			k += 1
		if k + 1 < _toks.size() and _toks[k + 1].t == "op" and _toks[k + 1].v == "=>":
			_i = j + 1
			var params := _params()
			if error:
				return {}
			_next()  # =>
			return _function_body("", params, is_async, true, line)
	return {}


func _conditional() -> Dictionary:
	var test := _binary(0)
	if _at_op("?"):
		var line: int = _next().line
		var a := _assignment()
		_expect(":", "A ? needs a : after it: test ? yes : no")
		var b := _assignment()
		return {"k": "Cond", "test": test, "a": a, "b": b, "line": line}
	return test


func _binary(min_prec: int) -> Dictionary:
	var left := _unary()
	while not error:
		var t := _peek()
		if t.t != "op":
			if t.t == "kw" and (t.v == "in" or t.v == "instanceof"):
				return _fail(t, "%s isn't available on this deck." % t.v)
			break
		if t.v == "&" or t.v == "|" or t.v == "^":
			return _fail(t, "%s on its own is a bit operator, which this deck doesn't run. Did you mean %s%s?" % [t.v, t.v, t.v])
		if not BINARY.has(t.v):
			break
		var prec: int = BINARY[t.v]
		if prec < min_prec:
			break
		_next()
		var right := _binary(prec if t.v == "**" else prec + 1)
		var k := "Logical" if t.v in ["&&", "||", "??"] else "Binary"
		left = {"k": k, "op": t.v, "l": left, "r": right, "line": t.line}
	return left


func _unary() -> Dictionary:
	var t := _peek()
	if t.t == "op" and t.v in ["!", "-", "+"]:
		_next()
		return {"k": "Unary", "op": t.v, "arg": _unary(), "line": t.line}
	if t.t == "op" and t.v == "~":
		return _fail(t, "~ is a bit operator, which this deck doesn't run.")
	if t.t == "op" and (t.v == "++" or t.v == "--"):
		_next()
		var target := _unary()
		return _update(t, target, true)
	if t.t == "kw" and t.v == "typeof":
		_next()
		return {"k": "Unary", "op": "typeof", "arg": _unary(), "line": t.line}
	if t.t == "kw" and t.v == "await":
		if _async_depth == 0:
			return _fail(t, "await only works inside an async function. Write async function ... or async () => ...")
		_next()
		return {"k": "Await", "arg": _unary(), "line": t.line}
	var e := _postfix()
	var p := _peek()
	if p.t == "op" and (p.v == "++" or p.v == "--") and not p.nl:
		_next()
		return _update(p, e, false)
	return e


func _update(t: Dictionary, target: Dictionary, prefix: bool) -> Dictionary:
	if target.get("k") != "Ident" and target.get("k") != "Member" and target.get("k") != "Index":
		return _fail(t, "%s only works on a name or a property." % t.v)
	return {"k": "Update", "op": t.v, "prefix": prefix, "target": target, "line": t.line}


func _postfix() -> Dictionary:
	var e := _primary()
	while not error:
		var t := _peek()
		if t.t != "op":
			break
		if t.v == ".":
			_next()
			var name := _next()
			if name.t != "name" and name.t != "kw":
				return _fail(name, "A . needs a property name after it.")
			e = {"k": "Member", "obj": e, "name": name.v, "optional": false, "line": t.line}
		elif t.v == "?.":
			_next()
			if _at_op("("):
				_next()
				e = {"k": "Call", "callee": e, "args": _args(), "optional": true, "line": t.line}
			elif _at_op("["):
				_next()
				var idx := _expression()
				_expect("]", "Close the [ with ]")
				e = {"k": "Index", "obj": e, "index": idx, "optional": true, "line": t.line}
			else:
				var name := _next()
				if name.t != "name" and name.t != "kw":
					return _fail(name, "A ?. needs a property name after it.")
				e = {"k": "Member", "obj": e, "name": name.v, "optional": true, "line": t.line}
		elif t.v == "[":
			_next()
			var idx := _expression()
			_expect("]", "Close the [ with ]")
			e = {"k": "Index", "obj": e, "index": idx, "optional": false, "line": t.line}
		elif t.v == "(":
			_next()
			e = {"k": "Call", "callee": e, "args": _args(), "optional": false, "line": t.line}
		else:
			break
	return e


func _args() -> Array:
	var args := []
	while not _at_op(")"):
		if _at_op("..."):
			_fail(_peek(), "Spreading (...list) isn't available on this deck yet.")
			return []
		args.append(_assignment())
		if error:
			return []
		if not _at_op(")"):
			_expect(",", "Separate the inputs with commas.")
			if error:
				return []
	_next()
	return args


func _primary() -> Dictionary:
	var t := _next()
	var line: int = t.line
	match t.t:
		"num":
			return {"k": "Num", "v": t.v, "line": line}
		"str":
			return {"k": "Str", "v": t.v, "line": line}
		"tpl":
			var quasis := []
			var exprs := []
			for part in t.v:
				if part is String:
					quasis.append(part)
					continue
				var sub := JSParser.new(part.src, part.line - 1, part.col - 1)
				sub._async_depth = _async_depth
				sub._fn_depth = _fn_depth
				if not sub._lex():
					error = sub.error
					return {}
				var e := sub._expression()
				if sub.error:
					error = sub.error
					return {}
				if not sub._at("eof"):
					return _fail(sub._peek(), "Only one expression fits inside ${ }.")
				exprs.append(e)
			return {"k": "Tpl", "quasis": quasis, "exprs": exprs, "line": line}
		"name":
			return {"k": "Ident", "name": t.v, "line": line}
		"kw":
			match t.v:
				"true", "false":
					return {"k": "Bool", "v": t.v == "true", "line": line}
				"null":
					return {"k": "Null", "line": line}
				"function":
					var name := ""
					if _peek().t == "name":
						name = _next().v
					return _function_rest(name, false, line)
				"async":
					if _at_kw("function"):
						_next()
						var name := ""
						if _peek().t == "name":
							name = _next().v
						return _function_rest(name, true, line)
					return {"k": "Ident", "name": "async", "line": line}
			if NOT_YET.has(t.v):
				return _fail(t, NOT_YET[t.v])
			return _fail(t, "%s can't be used here." % t.v)
		"op":
			match t.v:
				"(":
					var e := _expression()
					_expect(")", "This ( is never closed with ).")
					return e
				"[":
					var items := []
					while not _at_op("]"):
						if _at_op("..."):
							return _fail(_peek(), "Spreading (...list) isn't available on this deck yet.")
						if _at_op(","):
							return _fail(_peek(), "A list can't have an empty slot.")
						items.append(_assignment())
						if error:
							return {}
						if not _at_op("]"):
							_expect(",", "Separate list items with commas.")
							if error:
								return {}
					_next()
					return {"k": "Array", "items": items, "line": line}
				"{":
					return _object(line)
	if t.t == "eof":
		return _fail(t, "The code ends too soon. Is something not finished?")
	return _fail(t, "%s can't be used here." % str(t.v))


func _object(line: int) -> Dictionary:
	var props := []
	while not _at_op("}"):
		var key := _next()
		var name := ""
		match key.t:
			"name", "kw":
				name = key.v
			"str":
				name = key.v
			"num":
				name = JSVM.num_str(key.v)
			_:
				if key.t == "op" and key.v == "[":
					return _fail(key, "Computed keys ({[k]: v}) aren't available on this deck.")
				if key.t == "op" and key.v == "...":
					return _fail(key, "Spreading (...obj) isn't available on this deck yet.")
				return _fail(key, "Each property needs a name: { name: value }")
		var value: Dictionary
		if _at_op(":"):
			_next()
			value = _assignment()
		elif key.t == "name" and (_at_op(",") or _at_op("}")):
			value = {"k": "Ident", "name": name, "line": key.line}
		elif _at_op("("):
			_next()
			var params := _params()
			value = _function_body(name, params, false, false, key.line)
		else:
			return _fail(_peek(), "Put a : between a property and its value: { %s: ... }" % name)
		if error:
			return {}
		props.append({"key": name, "value": value})
		if not _at_op("}"):
			_expect(",", "Separate properties with commas.")
			if error:
				return {}
	_next()
	return {"k": "Object", "props": props, "line": line}


# --- token helpers -------------------------------------------------------------

func _peek(ahead := 0) -> Dictionary:
	return _toks[mini(_i + ahead, _toks.size() - 1)]


func _next() -> Dictionary:
	var t: Dictionary = _toks[_i]
	if _i < _toks.size() - 1:
		_i += 1
	return t


func _at(type: String) -> bool:
	return _toks[_i].t == type


func _at_op(v: String) -> bool:
	return _toks[_i].t == "op" and _toks[_i].v == v


func _at_kw(v: String) -> bool:
	return _toks[_i].t == "kw" and _toks[_i].v == v


func _expect(v: String, message: String) -> void:
	if error:
		return
	if _at_op(v):
		_next()
	else:
		_fail(_peek(), message)


## End of a statement: a ;, or (as JavaScript allows) a new line, a } or the end.
func _semi() -> void:
	if error:
		return
	if _at_op(";"):
		_next()
	elif not (_at_op("}") or _at("eof") or _peek().nl):
		var t := _peek()
		if t.t == "name" or t.t == "str" or t.t == "num":
			_fail(t, "Something is missing before %s: an operator like + or a comma?" % _show(t))
		else:
			_fail(t, "%s can't go here. End the line first?" % _show(t))


func _show(t: Dictionary) -> String:
	if t.t == "str":
		return "\"%s\"" % t.v
	if t.t == "num":
		return JSVM.num_str(t.v)
	return str(t.v)


func _fail(t: Dictionary, message: String) -> Dictionary:
	return _fail_at(t.line, t.col, message)


func _fail_at(line: int, col: int, message: String) -> Dictionary:
	if not error:
		error = {"line": line, "col": col, "message": message}
	_i = _toks.size() - 1 if _toks.size() > 0 else 0
	return {}


func _lex_fail(line: int, col: int, message: String) -> bool:
	_fail_at(line, col, message)
	return false
