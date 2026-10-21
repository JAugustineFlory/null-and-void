class_name JSStdlib
extends RefCounted
## The built-ins every deck script has: console, Math, JSON, Object.keys and
## friends, list and text methods, sleep() and assert(). The game adds its own
## (api and db, in JSRuntime); nothing here reaches outside the script.

const Arr = JSVM.Arr
const Obj = JSVM.Obj
const Native = JSVM.Native


static func install(vm: JSVM) -> void:
	var g := vm.globals
	g["undefined"] = null
	g["NaN"] = NAN
	g["Infinity"] = INF
	g["console"] = _host_obj({
		"log": func(v: JSVM, a: Array): return _print(v, a, "log"),
		"info": func(v: JSVM, a: Array): return _print(v, a, "log"),
		"warn": func(v: JSVM, a: Array): return _print(v, a, "warn"),
		"error": func(v: JSVM, a: Array): return _print(v, a, "error"),
	})
	g["Math"] = _host_obj({
		"floor": func(_v, a): return floorf(_n(a, 0)),
		"ceil": func(_v, a): return ceilf(_n(a, 0)),
		"round": func(_v, a): return floorf(_n(a, 0) + 0.5),
		"trunc": func(_v, a): return float(int(_n(a, 0))),
		"abs": func(_v, a): return absf(_n(a, 0)),
		"sqrt": func(_v, a): return sqrt(_n(a, 0)) if _n(a, 0) >= 0 else NAN,
		"pow": func(_v, a): return pow(_n(a, 0), _n(a, 1)),
		"min": func(_v, a): return _minmax(a, true),
		"max": func(_v, a): return _minmax(a, false),
		"random": func(v: JSVM, _a): return v.rng.randf(),
	})
	g["Math"].props["PI"] = PI
	g["JSON"] = _host_obj({
		"stringify": func(v: JSVM, a: Array): return _stringify_top(v, a),
		"parse": func(v: JSVM, a: Array): return _parse(v, a),
	})
	g["Object"] = _host_obj({
		"keys": func(v: JSVM, a: Array): return _entries(v, a, 0),
		"values": func(v: JSVM, a: Array): return _entries(v, a, 1),
		"entries": func(v: JSVM, a: Array): return _entries(v, a, 2),
	})
	g["Array"] = _host_obj({"isArray": func(_v, a): return a.size() > 0 and a[0] is Arr})
	g["Number"] = Native.new("Number", func(_v, a): return 0.0 if a.is_empty() else JSVM.to_num(a[0]))
	g["String"] = Native.new("String", func(_v, a): return "" if a.is_empty() else JSVM.to_str(a[0]))
	g["Boolean"] = Native.new("Boolean", func(_v, a): return not a.is_empty() and JSVM.truthy(a[0]))
	g["parseInt"] = Native.new("parseInt", func(_v, a): return _parse_int(JSVM.to_str(_a(a, 0))))
	g["parseFloat"] = Native.new("parseFloat", func(_v, a): return _parse_float(JSVM.to_str(_a(a, 0))))
	g["isNaN"] = Native.new("isNaN", func(_v, a): return is_nan(_n(a, 0)))
	## Game globals, not standard JavaScript (like a browser's own extras):
	## await sleep(ms) pauses the script; assert(test, message) stops it if test is false.
	g["sleep"] = Native.new("sleep", func(v: JSVM, a: Array): return v.sleep_promise(_n(a, 0) / 1000.0))
	g["assert"] = Native.new("assert", func(v: JSVM, a: Array):
		if not JSVM.truthy(_a(a, 0)):
			v.fail("assert failed: %s" % (JSVM.to_str(a[1]) if a.size() > 1 else "the test was false"))
		return null)


static func _host_obj(fns: Dictionary) -> Obj:
	var o := Obj.new()
	for k in fns:
		o.props[k] = Native.new(k, fns[k])
	return o


static func _a(args: Array, i: int) -> Variant:
	return args[i] if i < args.size() else null


static func _n(args: Array, i: int) -> float:
	return JSVM.to_num(_a(args, i))


static func _minmax(args: Array, lo: bool) -> float:
	var best := INF if lo else -INF
	for x in args:
		var n := JSVM.to_num(x)
		if is_nan(n):
			return NAN
		best = minf(best, n) if lo else maxf(best, n)
	return best


static func _parse_int(s: String) -> float:
	var m := RegEx.create_from_string("^\\s*([+-]?\\d+)").search(s)
	return float(m.get_string(1).to_int()) if m else NAN


static func _parse_float(s: String) -> float:
	var m := RegEx.create_from_string("^\\s*([+-]?(\\d+\\.?\\d*|\\.\\d+)([eE][+-]?\\d+)?)").search(s)
	return m.get_string(1).to_float() if m else NAN


static func _print(vm: JSVM, args: Array, kind: String) -> Variant:
	var parts := PackedStringArray()
	for x in args:
		parts.append(x if x is String else inspect(x))
	vm.printed.emit(" ".join(parts), kind)
	return null


## A value as console.log writes it. Text on its own prints as it is; inside
## lists and objects everything reads the way JSON is written, with keys and
## text in double quotes: [1, 2], { "error": "Can't reach it." }. (Node writes
## { error: 'Can\'t reach it.' }, which beginners who just learned JSON misread.)
## Short values stay on one line; longer ones go one entry per line.
static func inspect(v: Variant) -> String:
	return v if v is String else _shown(v, 0, "")


const LINE_WIDTH := 72
const SHOWN_DEPTH := 6


static func _shown(v: Variant, depth: int, gap: String) -> String:
	if v is String:
		return _quoted(v)
	var parts := PackedStringArray()
	var keys: Array = []
	if v is Arr:
		if v.items.is_empty():
			return "[]"
		if depth >= SHOWN_DEPTH:
			return "[...]"
		for x in v.items:
			parts.append(_shown(x, depth + 1, gap + "  "))
	elif v is Obj:
		if v.props.is_empty():
			return "{}"
		if depth >= SHOWN_DEPTH:
			return "{...}"
		for k in v.props:
			keys.append(_quoted(k) + ": ")
			parts.append(_shown(v.props[k], depth + 1, gap + "  "))
	elif v is JSVM.Fn:
		return "[Function: %s]" % v.proto.name if v.proto.name != "" else "[Function (anonymous)]"
	elif v is Native:
		return "[Function: %s]" % v.name
	elif v is JSVM.Promise:
		return "Promise { %s }" % (_shown(v.value, depth + 1, gap) if v.state == 1 else "<pending>")
	else:
		return JSVM.to_str(v)
	var items := PackedStringArray()
	for i in parts.size():
		items.append((keys[i] if keys else "") + parts[i])
	var one := ("[%s]" if v is Arr else "{ %s }") % ", ".join(items)
	if gap.length() + one.length() <= LINE_WIDTH and not one.contains("\n"):
		return one
	var inner := ",\n" + gap + "  "
	return ("[\n%s  %s\n%s]" if v is Arr else "{\n%s  %s\n%s}") % [gap, inner.join(items), gap]


## Text in double quotes, as JSON writes it: only " and \ and control characters are escaped.
static func _quoted(s: String) -> String:
	return "\"%s\"" % s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")


# --- JSON --------------------------------------------------------------------------

static func _stringify_top(vm: JSVM, args: Array) -> Variant:
	var indent := ""
	if args.size() > 2:
		indent = " ".repeat(clampi(int(JSVM.to_num(args[2])), 0, 10)) if args[2] is float else JSVM.to_str(args[2]).substr(0, 10)
	return _stringify(vm, _a(args, 0), indent, "", 0)


static func _stringify(vm: JSVM, v: Variant, indent: String, gap: String, depth: int) -> Variant:
	if depth > 50:
		return vm.fail("JSON.stringify went too deep: does an object contain itself?")
	if v is String:
		return JSON.stringify(v)
	if v is float:
		return JSVM.num_str(v) if not is_nan(v) and not is_inf(v) else "null"
	if v is bool:
		return "true" if v else "false"
	if v is JSVM.Nul:
		return "null"
	var inner := gap + indent
	var sep := ",\n" + inner if indent != "" else ","
	var open_pad := "\n" + inner if indent != "" else ""
	var close_pad := "\n" + gap if indent != "" else ""
	if v is Arr:
		if v.items.is_empty():
			return "[]"
		var parts := PackedStringArray()
		for x in v.items:
			var s = _stringify(vm, x, indent, inner, depth + 1)
			parts.append("null" if s == null else s)
		return "[" + open_pad + sep.join(parts) + close_pad + "]"
	if v is Obj:
		var parts := PackedStringArray()
		for k in v.props:
			var s = _stringify(vm, v.props[k], indent, inner, depth + 1)
			if s != null:
				parts.append(JSON.stringify(k) + (": " if indent != "" else ":") + s)
		if parts.is_empty():
			return "{}"
		return "{" + open_pad + sep.join(parts) + close_pad + "}"
	return null  # undefined and functions are left out, as in JavaScript


static func _parse(vm: JSVM, args: Array) -> Variant:
	var r := StrictJSON.parse(JSVM.to_str(_a(args, 0)))
	if not r.ok:
		return vm.fail("JSON.parse: line %d of the text: %s" % [r.line, r.message])
	return to_js(vm, r.value)


## Plain Godot data (from JSON or the game) as deck values.
static func to_js(vm: JSVM, v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL:
			return JSVM.NULL
		TYPE_INT:
			return float(v)
		TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return v
		TYPE_STRING_NAME:
			return str(v)
		TYPE_DICTIONARY:
			var props := {}
			for k in v:
				props[str(k)] = to_js(vm, v[k])
			return vm.make_obj(props)
		TYPE_ARRAY:
			var items := []
			for x in v:
				items.append(to_js(vm, x))
			return vm.make_arr(items)
	return JSVM.NULL


## Deck values as plain Godot data, for the game to read.
static func from_js(v: Variant) -> Variant:
	if v is Arr:
		var out := []
		for x in v.items:
			out.append(from_js(x))
		return out
	if v is Obj:
		var out := {}
		for k in v.props:
			out[k] = from_js(v.props[k])
		return out
	if v is JSVM.Nul or v == null:
		return null
	if v is float or v is String or v is bool:
		return v
	return null


static func _entries(vm: JSVM, args: Array, which: int) -> Variant:
	var o = _a(args, 0)
	var items := []
	if o is Obj:
		for k in o.props:
			match which:
				0: items.append(k)
				1: items.append(o.props[k])
				2: items.append(vm.make_arr([k, o.props[k]]))
	elif o is Arr:
		for i in o.items.size():
			match which:
				0: items.append(str(i))
				1: items.append(o.items[i])
				2: items.append(vm.make_arr([str(i), o.items[i]]))
	elif JSVM.nullish(o):
		return vm.fail("Object.%s needs an object, but got %s." % [["keys", "values", "entries"][which], JSVM.describe(o)])
	return vm.make_arr(items)


# --- methods on lists, text and numbers ---------------------------------------------------

## `obj.name` as a function bound to obj, or null if there's no such method.
static func bound(vm: JSVM, obj: Variant, name: String) -> Variant:
	if obj is Arr:
		if not name in ARRAY_METHODS:
			return null
		return Native.new(name, func(v: JSVM, a: Array): return _array_method(v, obj, name, a))
	if obj is String:
		if not name in STRING_METHODS:
			return null
		return Native.new(name, func(v: JSVM, a: Array): return _string_method(v, obj, name, a))
	if obj is float:
		if name == "toFixed":
			return Native.new(name, func(_v, a): return _to_fixed(obj, int(_n(a, 0))))
		if name == "toString":
			return Native.new(name, func(_v, _a2): return JSVM.num_str(obj))
	if obj is JSVM.Promise and name == "then":
		return Native.new(name, func(v: JSVM, _a2): return v.fail(".then isn't available on this deck. Use await instead."))
	return null


const ARRAY_METHODS := ["push", "pop", "shift", "unshift", "includes", "indexOf", "join", "slice",
	"concat", "reverse", "map", "filter", "find", "findIndex", "forEach", "some", "every", "reduce", "sort", "at"]
const STRING_METHODS := ["toUpperCase", "toLowerCase", "includes", "startsWith", "endsWith", "indexOf",
	"slice", "substring", "split", "trim", "padStart", "padEnd", "repeat", "replace", "replaceAll", "at", "charAt"]


static func _array_method(vm: JSVM, arr: Arr, name: String, a: Array) -> Variant:
	var items := arr.items
	match name:
		"push":
			if items.size() + a.size() > JSVM.MAX_ITEMS:
				return vm.fail("A list can't hold more than %d items." % JSVM.MAX_ITEMS)
			items.append_array(a)
			vm._count(a.size())
			return float(items.size())
		"pop":
			return items.pop_back()
		"shift":
			return items.pop_front()
		"unshift":
			for i in range(a.size() - 1, -1, -1):
				items.push_front(a[i])
			vm._count(a.size())
			return float(items.size())
		"includes":
			for x in items:
				if JSVM.strict_eq(x, _a(a, 0)) or (x is float and _a(a, 0) is float and is_nan(x) and is_nan(a[0])):
					return true
			return false
		"indexOf":
			for i in items.size():
				if JSVM.strict_eq(items[i], _a(a, 0)):
					return float(i)
			return -1.0
		"join":
			var sep := "," if a.is_empty() or a[0] == null else JSVM.to_str(a[0])
			var parts := PackedStringArray()
			for x in items:
				parts.append("" if JSVM.nullish(x) else JSVM.to_str(x))
			return sep.join(parts)
		"slice":
			var r := _range(items.size(), a)
			return vm.make_arr(items.slice(r[0], r[1]))
		"concat":
			var out := items.duplicate()
			for x in a:
				if x is Arr:
					out.append_array(x.items)
				else:
					out.append(x)
			return vm.make_arr(out)
		"reverse":
			items.reverse()
			return arr
		"at":
			var i := int(_n(a, 0))
			if i < 0:
				i += items.size()
			return items[i] if i >= 0 and i < items.size() else null
		"sort":
			var cmp = _a(a, 0)
			var bad := [false]
			if cmp == null:
				items.sort_custom(func(x, y): return JSVM.to_str(x) < JSVM.to_str(y))
			else:
				items.sort_custom(func(x, y):
					if bad[0]:
						return false
					var r = vm.call_sync(cmp, [x, y])
					if vm.error:
						bad[0] = true
						return false
					return JSVM.to_num(r) < 0)
			return arr
	# The rest call a function for each item.
	var fn = _a(a, 0)
	if not (fn is JSVM.Fn or fn is Native):
		return vm.fail("%s needs a function, like list.%s(x => ...)" % [name, name])
	var out := []
	var acc = _a(a, 1)
	var start := 0
	if name == "reduce" and a.size() < 2:
		if items.is_empty():
			return vm.fail("reduce on an empty list needs a starting value: list.reduce((sum, x) => sum + x, 0)")
		acc = items[0]
		start = 1
	for i in range(start, items.size()):
		var x = items[i]
		var r = vm.call_sync(fn, [acc, x, float(i)] if name == "reduce" else [x, float(i)])
		if vm.error:
			return null
		match name:
			"map":
				out.append(r)
			"filter":
				if JSVM.truthy(r):
					out.append(x)
			"find":
				if JSVM.truthy(r):
					return x
			"findIndex":
				if JSVM.truthy(r):
					return float(i)
			"some":
				if JSVM.truthy(r):
					return true
			"every":
				if not JSVM.truthy(r):
					return false
			"reduce":
				acc = r
	match name:
		"map", "filter":
			return vm.make_arr(out)
		"findIndex":
			return -1.0
		"some":
			return false
		"every":
			return true
		"reduce":
			return acc
	return null


static func _string_method(vm: JSVM, s: String, name: String, a: Array) -> Variant:
	match name:
		"toUpperCase": return s.to_upper()
		"toLowerCase": return s.to_lower()
		"trim": return s.strip_edges()
		"includes": return s.contains(JSVM.to_str(_a(a, 0)))
		"startsWith": return s.begins_with(JSVM.to_str(_a(a, 0)))
		"endsWith": return s.ends_with(JSVM.to_str(_a(a, 0)))
		"indexOf": return float(s.find(JSVM.to_str(_a(a, 0))))
		"slice":
			var r := _range(s.length(), a)
			return s.substr(r[0], maxi(r[1] - r[0], 0))
		"substring":
			var x := clampi(int(_n(a, 0)) if a.size() > 0 else 0, 0, s.length())
			var y := clampi(int(_n(a, 1)) if a.size() > 1 and a[1] != null else s.length(), 0, s.length())
			return s.substr(mini(x, y), absi(y - x))
		"split":
			if a.is_empty() or a[0] == null:
				return vm.make_arr([s])
			var sep := JSVM.to_str(a[0])
			var parts: Array = Array(s.split(sep)) if sep != "" else Array(s.split(""))
			if sep == "":
				parts = []
				for c in s:
					parts.append(c)
			return vm.make_arr(parts)
		"padStart", "padEnd":
			var n := int(_n(a, 0))
			var pad := " " if a.size() < 2 else JSVM.to_str(a[1])
			if s.length() >= n or pad == "":
				return s
			var fill := pad.repeat(ceili(float(n - s.length()) / pad.length())).substr(0, n - s.length())
			return fill + s if name == "padStart" else s + fill
		"repeat":
			var n := int(_n(a, 0))
			if n < 0 or s.length() * n > JSVM.MAX_TEXT:
				return vm.fail("repeat can't make text that long.")
			return s.repeat(n)
		"replace":
			var find := JSVM.to_str(_a(a, 0))
			var at := s.find(find)
			return s if at < 0 else s.substr(0, at) + JSVM.to_str(_a(a, 1)) + s.substr(at + find.length())
		"replaceAll":
			return s.replace(JSVM.to_str(_a(a, 0)), JSVM.to_str(_a(a, 1)))
		"at", "charAt":
			var i := int(_n(a, 0))
			if name == "at" and i < 0:
				i += s.length()
			if i >= 0 and i < s.length():
				return s[i]
			return null if name == "at" else ""
	return null


static func _range(size: int, a: Array) -> Array:
	var x := int(_n(a, 0)) if a.size() > 0 and a[0] != null else 0
	var y := int(_n(a, 1)) if a.size() > 1 and a[1] != null else size
	if x < 0:
		x = maxi(size + x, 0)
	if y < 0:
		y = maxi(size + y, 0)
	return [mini(x, size), mini(y, size)]


static func _to_fixed(x: float, digits: int) -> String:
	digits = clampi(digits, 0, 20)
	return String.num(x, digits).pad_decimals(digits) if digits > 0 else str(int(roundf(x)))
