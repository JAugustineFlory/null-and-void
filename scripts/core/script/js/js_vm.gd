class_name JSVM
extends RefCounted
## Runs JSCompiler's bytecode a few thousand steps at a time, so a deck script can
## loop and wait for seconds without stalling the game. Player code never becomes
## GDScript: it can only touch the values and built-ins handed to it here.
##
## Sandbox: no files, no network, no engine objects. Limits: STEP_LIMIT steps
## without waiting, MAX_DEPTH nested calls, and HEAP_LIMIT live list items,
## object properties and characters.
##
## JavaScript values: number = float, string = String, boolean = bool,
## undefined = null, null = JSVM.NULL, and Arr, Obj, Fn, Native, Promise below.

signal printed(text: String, kind: String)

const STEP_LIMIT := 100_000
const TICK_USEC := 2_000  # time a script may use per frame
const SLICE := 1_024  # steps between clock checks
const MAX_DEPTH := 200
const HEAP_LIMIT := 200_000
const MAX_ITEMS := 10_000
const MAX_TEXT := 100_000
const GC_EVERY := 50_000

enum Op {
	LOADL, LOAD, CONST, STORE, ASSIGN, POP, DUP, DUP2, LOAD_G, STORE_G, UPD_G, TDZ,
	JMP, JF, JCMPF, LT, GT, LE, GE, SEQ, SNE, JF_KEEP, JT_KEEP, JNN_KEEP, JNULLISH,
	ADD, SUB, MUL, DIV, MOD, POW, EQ, NE, NOT, NEG, PLUS, TYPEOF, TYPEOF_G,
	GET, CALLM, CALL, RET, GETI, SET, SETI, ARRAY, OBJECT, TPL, CLOSURE,
	UPD_L, ITER, NEXT, AWAIT, UPD_P, UPD_I, NEWENV, POPENV, COPYENV,
}
enum { DONE, SUSPENDED, OUT_OF_STEPS, FAILED }


class Nul:
	pass


class Tdz:
	pass


static var NULL := Nul.new()
static var TDZ := Tdz.new()


class Proto:
	var name := ""
	var nparams := 0
	var nslots := 0
	var is_async := false
	var code: Array = []
	var lines: PackedInt32Array = PackedInt32Array()
	var all_names: Array = []  # every name the program declares, shared by all its functions


class Arr:
	var items: Array = []


class Obj:
	var props: Dictionary = {}


class Fn:
	var proto: Proto
	var env: Array


## A built-in function. `fn` is Callable(vm: JSVM, args: Array) -> Variant.
class Native:
	var name: String
	var fn: Callable

	func _init(n: String, f: Callable) -> void:
		name = n
		fn = f


class Promise:
	var state := 0  # 0 waiting, 1 done
	var value: Variant = null
	var waiters: Array = []  # Fibers


class Frame:
	var proto: Proto
	var pc := 0
	var env: Array
	var base := 0
	var sync_return := false  # a built-in like map() is waiting for this call


class Fiber:
	var frames: Array = []
	var stack: Array = []
	var promise := Promise.new()


var globals := {}
var error := {}  # {line, message} once the script has failed
var now := 0.0  # seconds of game time since the script started
var steps_total := 0
var rng := RandomNumberGenerator.new()

var _main: Fiber
var _runnable: Array = []
var _timers: Array = []  # [at, Promise], soonest first
var _steps_hot := 0
var _allocated := 0
var _heap: Array = []  # WeakRefs to every Arr and Obj, to break cycles when the script ends
var _cur: Fiber
var _err_line := 0


func _init() -> void:
	JSStdlib.install(self)


## Starts `main` (from JSCompiler.compile). Run it with tick() each frame.
func start(main: Proto, seed_value := 0) -> void:
	rng.seed = seed_value
	_main = _fiber_for(_make_fn(main, []), [])
	_runnable.append(_main)


## Is anything left to run, now or after a wait?
func busy() -> bool:
	return error.is_empty() and (not _runnable.is_empty() or not _timers.is_empty() or _waiting_fibers())


## Advances game time by `delta` seconds and runs for up to `usec` microseconds.
func tick(delta: float, usec := TICK_USEC) -> void:
	now += delta
	while not _timers.is_empty() and _timers[0][0] <= now + 0.000001:
		var t: Array = _timers.pop_front()
		resolve(t[1], null)
	var deadline := Time.get_ticks_usec() + usec
	while not _runnable.is_empty() and error.is_empty() and Time.get_ticks_usec() < deadline:
		var f: Fiber = _runnable.front()
		var r := _exec(f, SLICE)
		if r != OUT_OF_STEPS:
			_runnable.erase(f)


## Throws away everything the script made, breaking any loops of references.
func stop() -> void:
	_runnable.clear()
	_timers.clear()
	_main = null
	_cur = null
	for w in _heap:
		var o = w.get_ref()
		if o is Arr:
			o.items.clear()
		elif o is Obj:
			o.props.clear()
		elif o is Fn:
			o.env = []
		elif o is Fiber:
			o.frames.clear()
			o.stack.clear()
		elif o is Promise:
			o.waiters.clear()
			o.value = null
	_heap.clear()
	# Built-ins and listeners can hold whoever made them (the runtime), which holds us.
	globals.clear()
	for c in printed.get_connections():
		printed.disconnect(c.callable)


func fail(message: String) -> Variant:
	if error.is_empty():
		error = {"line": _err_line, "message": message}
	return null


## A promise that finishes after `seconds` of game time.
func sleep_promise(seconds: float) -> Promise:
	var p := Promise.new()
	_heap.append(weakref(p))
	var at := now + maxf(seconds, 0.0)
	var i := 0
	while i < _timers.size() and _timers[i][0] <= at:
		i += 1
	_timers.insert(i, [at, p])
	return p


func resolved(v: Variant) -> Promise:
	var p := Promise.new()
	p.state = 1
	p.value = v
	return p


func resolve(p: Promise, v: Variant) -> void:
	if p.state != 0:
		return
	p.state = 1
	p.value = v
	for f in p.waiters:
		f.stack.append(v)
		_runnable.append(f)
	p.waiters.clear()


## Is anything ready to run now (rather than only waiting on a sleep)?
func has_work() -> bool:
	return not _runnable.is_empty()


func _waiting_fibers() -> bool:
	return _main != null and _main.promise.state == 0


# --- values --------------------------------------------------------------------

func make_arr(items: Array) -> Arr:
	var a := Arr.new()
	a.items = items
	_count(items.size() + 1)
	_heap.append(weakref(a))
	return a


func make_obj(props: Dictionary) -> Obj:
	var o := Obj.new()
	o.props = props
	_count(props.size() + 1)
	_heap.append(weakref(o))
	return o


func _make_fn(proto: Proto, env: Array) -> Fn:
	var f := Fn.new()
	f.proto = proto
	f.env = env
	_heap.append(weakref(f))
	return f


func _count(cells: int) -> void:
	_allocated += cells
	if _allocated > GC_EVERY:
		_allocated = 0
		var live := _measure_heap()
		if live > HEAP_LIMIT:
			fail("The script is holding too much: %d list items and properties. The limit is %d." % [live, HEAP_LIMIT])


## Counts what the script can still reach.
func _measure_heap() -> int:
	var seen := {}
	var todo: Array = []
	for f in _all_fibers():
		todo.append_array(f.stack)
		for fr in f.frames:
			todo.append(fr.env)
	var live := 0
	while not todo.is_empty():
		var v = todo.pop_back()
		if v is Array:
			for x in v:
				if x is Object or x is Array:
					todo.append(x)
		elif v is Arr or v is Obj or v is Fn or v is Promise:
			var id: int = v.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			if v is Arr:
				live += v.items.size() + 1
				todo.append(v.items)
			elif v is Obj:
				live += v.props.size() + 1
				todo.append(v.props.values())
			elif v is Fn:
				todo.append(v.env)
			elif v is Promise:
				todo.append(v.value)
				for w in v.waiters:
					todo.append(w.stack)
		elif v is String:
			live += v.length() / 16
	# Forget what has been freed. Anything still alive but out of reach (a loop of
	# references) is kept and emptied when the script ends: a built-in in the
	# middle of map() or sort() can hold values this walk can't see.
	var kept: Array = []
	for w in _heap:
		if w.get_ref() != null:
			kept.append(w)
	_heap = kept
	if _heap.size() > HEAP_LIMIT * 4:
		fail("The script has made too many things that refer to themselves. Avoid lines like obj.self = obj inside a loop.")
	return live


func _all_fibers() -> Array:
	var out: Array = _runnable.duplicate()
	if _cur and not _cur in out:
		out.append(_cur)
	if _main and not _main in out:
		out.append(_main)
	return out


static func truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_FLOAT:
			return v != 0.0 and not is_nan(v)
		TYPE_STRING:
			return v != ""
		TYPE_NIL:
			return false
	return not v is Nul


static func to_num(v: Variant) -> float:
	match typeof(v):
		TYPE_FLOAT:
			return v
		TYPE_INT:
			return float(v)
		TYPE_BOOL:
			return 1.0 if v else 0.0
		TYPE_STRING:
			var s: String = v.strip_edges()
			if s == "":
				return 0.0
			if s.is_valid_float() and not s.ends_with("."):
				return s.to_float()
			if s == "Infinity":
				return INF
			if s == "-Infinity":
				return -INF
			return NAN
		TYPE_NIL:
			return NAN
	if v is Nul:
		return 0.0
	if v is Arr:
		return to_num(to_str(v))
	return NAN


static func to_str(v: Variant) -> String:
	match typeof(v):
		TYPE_STRING:
			return v
		TYPE_FLOAT:
			return num_str(v)
		TYPE_INT:
			return str(v)
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_NIL:
			return "undefined"
	if v is Nul:
		return "null"
	if v is Arr:
		var parts := PackedStringArray()
		for x in v.items:
			parts.append("" if x == null or x is Nul else to_str(x))
		return ",".join(parts)
	if v is Obj:
		return "[object Object]"
	if v is Promise:
		return "[object Promise]"
	if v is Fn or v is Native:
		return "function %s() { ... }" % (v.proto.name if v is Fn else v.name)
	return str(v)


## A number written the way JavaScript writes it: 3, 0.5, 0.30000000000000004, 1e+21.
static func num_str(x: float) -> String:
	if is_nan(x):
		return "NaN"
	if is_inf(x):
		return "Infinity" if x > 0 else "-Infinity"
	if x == floorf(x) and absf(x) < 1e21:
		return str(int(x))
	var s := var_to_str(x)
	if not s.contains("e"):
		return s
	var mant := s.get_slice("e", 0)
	var ex := s.get_slice("e", 1).to_int()
	if ex >= 21:
		return "%se+%d" % [mant, ex]
	if ex <= -7:
		return "%se-%d" % [mant, -ex]
	var neg := mant.begins_with("-")
	var digits := mant.trim_prefix("-").replace(".", "")
	var out := "0." + "0".repeat(-ex - 1) + digits
	return ("-" if neg else "") + out


static func type_of(v: Variant) -> String:
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			return "number"
		TYPE_STRING:
			return "string"
		TYPE_BOOL:
			return "boolean"
		TYPE_NIL:
			return "undefined"
	if v is Fn or v is Native:
		return "function"
	return "object"


static func strict_eq(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	return a == b


static func loose_eq(a: Variant, b: Variant) -> bool:
	if strict_eq(a, b):
		return true
	var an: bool = a == null or a is Nul
	var bn: bool = b == null or b is Nul
	if an or bn:
		return an and bn
	if a is Object or b is Object:
		if a is Object and b is Object:
			return false
		return loose_eq(to_str(a) if a is Arr else a, to_str(b) if b is Arr else b)
	return to_num(a) == to_num(b)


static func nullish(v: Variant) -> bool:
	return v == null or v is Nul


# --- running -------------------------------------------------------------------

func _fiber_for(fn: Fn, args: Array) -> Fiber:
	var f := Fiber.new()
	_heap.append(weakref(f))
	_heap.append(weakref(f.promise))
	f.frames.append(_frame_for(fn, args, 0))
	return f


func _frame_for(fn: Fn, args: Array, base: int) -> Frame:
	var fr := Frame.new()
	fr.proto = fn.proto
	fr.base = base
	var env := []
	env.resize(fn.proto.nslots + 1)
	env[0] = fn.env
	for i in mini(args.size(), fn.proto.nparams):
		env[i + 1] = args[i]
	fr.env = env
	return fr


## Calls a deck function from a built-in (map, filter, sort...) and returns its result.
func call_sync(fn: Variant, args: Array) -> Variant:
	if fn is Native:
		return fn.fn.call(self, args)
	if not fn is Fn:
		return fail("That isn't a function.")
	if fn.proto.is_async:
		return _start_async(fn, args)
	var fiber := _cur
	if fiber.frames.size() >= MAX_DEPTH:
		return fail("Too many calls inside calls (%d). Does a function keep calling itself?" % MAX_DEPTH)
	var fr := _frame_for(fn, args, fiber.stack.size())
	fr.sync_return = true
	fiber.frames.append(fr)
	var depth := fiber.frames.size()
	var r := _exec(fiber, 1 << 30, depth)
	if r == SUSPENDED:
		return fail("await can't pause inside forEach, map or filter. Use a for ... of loop instead.")
	if r == FAILED:
		return null
	return fiber.stack.pop_back()


func _start_async(fn: Fn, args: Array) -> Promise:
	var f := _fiber_for(fn, args)
	var saved := _cur
	var r := _exec(f, 1 << 30)
	_cur = saved
	if r == OUT_OF_STEPS:
		_runnable.append(f)
	return f.promise


## Runs `fiber` until it finishes, waits, fails, or uses `budget` steps. With
## `sync_depth`, also stops once the call at that depth returns.
func _exec(fiber: Fiber, budget: int, sync_depth := 0) -> int:
	_cur = fiber
	var fr: Frame = fiber.frames.back()
	var code: Array = fr.proto.code
	var stack: Array = fiber.stack
	var pc := fr.pc
	var allowed := mini(budget, STEP_LIMIT - _steps_hot)
	var left := allowed
	while true:
		left -= 1
		if left < 0:
			fr.pc = pc
			_used(allowed)
			if _steps_hot >= STEP_LIMIT:
				_err_line = fr.proto.lines[pc]
				fail("This script ran %d steps without waiting. Is a loop never ending? Long loops need await sleep(...) inside." % STEP_LIMIT)
				return FAILED
			return OUT_OF_STEPS
		var op: int = code[pc]
		if op < Op.JMP:
			match op:
				Op.LOADL:
					var v = fr.env[code[pc + 1]]
					if v is Tdz:
						_err_line = fr.proto.lines[pc]
						fail("%s is used before its let line runs. Move the let above this line." % code[pc + 2])
						return _failed(allowed - left)
					stack.append(v)
					pc += 3
				Op.LOAD:
					var e: Array = fr.env
					for h in code[pc + 1]:
						e = e[0]
					var v = e[code[pc + 2]]
					if v is Tdz:
						_err_line = fr.proto.lines[pc]
						fail("%s is used before its let line runs. Move the let above this line." % code[pc + 3])
						return _failed(allowed - left)
					stack.append(v)
					pc += 4
				Op.CONST:
					stack.append(code[pc + 1])
					pc += 2
				Op.STORE:
					var e: Array = fr.env
					for h in code[pc + 1]:
						e = e[0]
					e[code[pc + 2]] = stack.pop_back()
					pc += 3
				Op.ASSIGN:
					var e: Array = fr.env
					for h in code[pc + 1]:
						e = e[0]
					if e[code[pc + 2]] is Tdz:
						_err_line = fr.proto.lines[pc]
						fail("%s is changed before its let line runs. Move the let above this line." % code[pc + 3])
						return _failed(allowed - left)
					e[code[pc + 2]] = stack.pop_back()
					pc += 4
				Op.POP:
					stack.pop_back()
					pc += 1
				Op.DUP:
					stack.append(stack.back())
					pc += 1
				Op.DUP2:
					stack.append(stack[-2])
					stack.append(stack[-2])
					pc += 1
				Op.LOAD_G:
					var name: String = code[pc + 1]
					if not globals.has(name):
						_err_line = fr.proto.lines[pc]
						var like := _closest(name, fr.proto.all_names + globals.keys())
						if like != "":
							fail("%s isn't defined. Did you mean %s?" % [name, like])
						else:
							fail("%s isn't defined. Check the spelling, or declare it with let." % name)
						return _failed(allowed - left)
					stack.append(globals[name])
					pc += 2
				Op.STORE_G, Op.UPD_G:
					_err_line = fr.proto.lines[pc]
					var name: String = code[pc + 1]
					var like := _closest(name, fr.proto.all_names)
					if globals.has(name):
						fail("%s is built in, so it can't be changed." % name)
					elif like != "":
						fail("%s isn't declared. Did you mean %s?" % [name, like])
					else:
						fail("%s isn't declared. Write let %s = ... the first time." % [name, name])
					return _failed(allowed - left)
				Op.TDZ:
					fr.env[code[pc + 1]] = TDZ
					pc += 2
		elif op < Op.ADD:
			match op:
				Op.JMP:
					pc = code[pc + 1]
				Op.JF:
					if truthy(stack.pop_back()):
						pc += 2
					else:
						pc = code[pc + 1]
				Op.JCMPF:
					var b = stack.pop_back()
					var a = stack.pop_back()
					var cmp: int = code[pc + 1]
					var yes: bool
					if a is float and b is float:
						match cmp:
							Op.LT: yes = a < b
							Op.GT: yes = a > b
							Op.LE: yes = a <= b
							Op.GE: yes = a >= b
							Op.SEQ: yes = a == b
							_: yes = a != b
					elif cmp == Op.SEQ:
						yes = strict_eq(a, b)
					elif cmp == Op.SNE:
						yes = not strict_eq(a, b)
					else:
						yes = _compare(cmp, a, b)
					pc = pc + 3 if yes else code[pc + 2]
				Op.LT, Op.GT, Op.LE, Op.GE:
					var b = stack.pop_back()
					var a = stack.pop_back()
					stack.append(_compare(op, a, b))
					pc += 1
				Op.SEQ:
					var b = stack.pop_back()
					stack.append(strict_eq(stack.pop_back(), b))
					pc += 1
				Op.SNE:
					var b = stack.pop_back()
					stack.append(not strict_eq(stack.pop_back(), b))
					pc += 1
				Op.JF_KEEP:
					if truthy(stack.back()):
						stack.pop_back()
						pc += 2
					else:
						pc = code[pc + 1]
				Op.JT_KEEP:
					if truthy(stack.back()):
						pc = code[pc + 1]
					else:
						stack.pop_back()
						pc += 2
				Op.JNN_KEEP:
					if nullish(stack.back()):
						stack.pop_back()
						pc += 2
					else:
						pc = code[pc + 1]
				Op.JNULLISH:
					if nullish(stack.back()):
						stack[-1] = null
						pc = code[pc + 1]
					else:
						pc += 2
		elif op < Op.GET:
			match op:
				Op.ADD:
					var b = stack.pop_back()
					var a = stack.pop_back()
					if a is float and b is float:
						stack.append(a + b)
					elif a is String or b is String or a is Arr or b is Arr or a is Obj or b is Obj:
						var s := to_str(a) + to_str(b)
						if s.length() > MAX_TEXT:
							_err_line = fr.proto.lines[pc]
							fail("That text is too long (over %d characters)." % MAX_TEXT)
							return _failed(allowed - left)
						stack.append(s)
					else:
						stack.append(to_num(a) + to_num(b))
					pc += 1
				Op.SUB, Op.MUL, Op.DIV, Op.MOD, Op.POW:
					var b := to_num(stack.pop_back())
					var a := to_num(stack.pop_back())
					match op:
						Op.SUB: stack.append(a - b)
						Op.MUL: stack.append(a * b)
						Op.DIV: stack.append(a / b if b != 0.0 else (NAN if a == 0.0 or is_nan(a) else signf(a) * INF))
						Op.MOD: stack.append(fmod(a, b) if b != 0.0 else NAN)
						Op.POW: stack.append(pow(a, b))
					pc += 1
				Op.EQ:
					var b = stack.pop_back()
					stack.append(loose_eq(stack.pop_back(), b))
					pc += 1
				Op.NE:
					var b = stack.pop_back()
					stack.append(not loose_eq(stack.pop_back(), b))
					pc += 1
				Op.NOT:
					stack.append(not truthy(stack.pop_back()))
					pc += 1
				Op.NEG:
					stack.append(-to_num(stack.pop_back()))
					pc += 1
				Op.PLUS:
					stack.append(to_num(stack.pop_back()))
					pc += 1
				Op.TYPEOF:
					stack.append(type_of(stack.pop_back()))
					pc += 1
				Op.TYPEOF_G:
					stack.append(type_of(globals.get(code[pc + 1])))
					pc += 2
		elif op < Op.UPD_L:
			match op:
				Op.GET:
					_err_line = fr.proto.lines[pc]
					var v = get_prop(stack.pop_back(), code[pc + 1], code[pc + 2])
					if error:
						return _failed(allowed - left)
					stack.append(v)
					pc += 3
				Op.CALL, Op.CALLM:
					_err_line = fr.proto.lines[pc]
					var callm := op == Op.CALLM
					var argc: int = code[pc + 2] if callm else code[pc + 1]
					var args := stack.slice(stack.size() - argc)
					stack.resize(stack.size() - argc)
					var target = stack.pop_back()
					var fn = null
					if callm:
						fn = method(target, code[pc + 1], code[pc + 3])
						pc += 4
					else:
						fn = target
						pc += 3
					if error:
						return _failed(allowed - left)
					if fn is Fn and not fn.proto.is_async:
						if fiber.frames.size() >= MAX_DEPTH:
							fail("Too many calls inside calls (%d). Does a function keep calling itself?" % MAX_DEPTH)
							return _failed(allowed - left)
						fr.pc = pc
						fr = _frame_for(fn, args, stack.size())
						fiber.frames.append(fr)
						code = fr.proto.code
						pc = 0
						continue
					var result = null
					if fn is Fn:
						fr.pc = pc
						result = _start_async(fn, args)
						_cur = fiber
					elif fn is Native:
						fr.pc = pc
						result = fn.fn.call(self, args)
					else:
						fail("%s isn't a function, so it can't be called with ( )." % code[pc - 1])
					if error:
						return _failed(allowed - left)
					stack.append(result)
				Op.RET:
					var v = stack.pop_back()
					stack.resize(fr.base)
					fiber.frames.pop_back()
					var was_sync := fr.sync_return
					if fiber.frames.is_empty():
						_used(allowed - left)
						resolve(fiber.promise, v)
						return DONE
					stack.append(v)
					if was_sync and fiber.frames.size() < sync_depth:
						_used(allowed - left)
						return DONE
					fr = fiber.frames.back()
					code = fr.proto.code
					pc = fr.pc
				Op.GETI:
					_err_line = fr.proto.lines[pc]
					var key = stack.pop_back()
					var v = get_index(stack.pop_back(), key, code[pc + 1])
					if error:
						return _failed(allowed - left)
					stack.append(v)
					pc += 2
				Op.SET:
					_err_line = fr.proto.lines[pc]
					var v = stack.pop_back()
					set_prop(stack.pop_back(), code[pc + 1], v, code[pc + 2])
					if error:
						return _failed(allowed - left)
					stack.append(v)
					pc += 3
				Op.SETI:
					_err_line = fr.proto.lines[pc]
					var v = stack.pop_back()
					var key = stack.pop_back()
					set_index(stack.pop_back(), key, v, code[pc + 1])
					if error:
						return _failed(allowed - left)
					stack.append(v)
					pc += 2
				Op.ARRAY:
					var n: int = code[pc + 1]
					var items := stack.slice(stack.size() - n)
					stack.resize(stack.size() - n)
					stack.append(make_arr(items))
					pc += 2
				Op.OBJECT:
					var keys: Array = code[pc + 1]
					var n := keys.size()
					var props := {}
					var at := stack.size() - n
					for i in n:
						props[keys[i]] = stack[at + i]
					stack.resize(at)
					stack.append(make_obj(props))
					pc += 2
				Op.TPL:
					var n: int = code[pc + 1]
					var s := ""
					for i in range(stack.size() - n, stack.size()):
						s += to_str(stack[i])
					stack.resize(stack.size() - n)
					stack.append(s)
					pc += 2
				Op.CLOSURE:
					stack.append(_make_fn(code[pc + 1], fr.env))
					pc += 2
		else:
			match op:
				Op.UPD_L:
					var e: Array = fr.env
					for h in code[pc + 1]:
						e = e[0]
					var old = e[code[pc + 2]]
					if old is Tdz:
						_err_line = fr.proto.lines[pc]
						fail("%s is changed before its let line runs. Move the let above this line." % code[pc + 5])
						return _failed(allowed - left)
					var n := to_num(old)
					e[code[pc + 2]] = n + code[pc + 3]
					match code[pc + 4]:
						0: stack.append(n)
						1: stack.append(n + code[pc + 3])
					pc += 6
				Op.ITER:
					_err_line = fr.proto.lines[pc]
					var v = stack.pop_back()
					if v is Arr:
						stack.append([v.items, 0])
					elif v is String:
						stack.append([v, 0])
					else:
						fail("for ... of needs a list or text, but %s is %s." % [code[pc + 1], describe(v)])
						return _failed(allowed - left)
					pc += 2
				Op.NEXT:
					var it: Array = stack.back()
					var src = it[0]
					var i: int = it[1]
					if i < src.size() if src is Array else i < src.length():
						it[1] = i + 1
						stack.append(src[i])
						pc += 2
					else:
						stack.pop_back()
						pc = code[pc + 1]
				Op.AWAIT:
					var v = stack.pop_back()
					pc += 1
					if v is Promise:
						if v.state == 0:
							fr.pc = pc
							v.waiters.append(fiber)
							_used(allowed - left)
							_steps_hot = 0
							return SUSPENDED
						v = v.value
					stack.append(v)
				Op.UPD_P, Op.UPD_I:
					_err_line = fr.proto.lines[pc]
					var key = code[pc + 1] if op == Op.UPD_P else stack.pop_back()
					var obj = stack.pop_back()
					var k := 1 if op == Op.UPD_P else 0
					var src: String = code[pc + 3 + k]
					var old := to_num(get_index(obj, key, src))
					var nv: float = old + code[pc + 1 + k]
					if not error:
						set_index(obj, key, nv, src)
					if error:
						return _failed(allowed - left)
					stack.append(nv if code[pc + 2 + k] else old)
					pc += 4 + k
				Op.NEWENV:
					var e := []
					e.resize(code[pc + 1] + 1)
					e[0] = fr.env
					fr.env = e
					pc += 2
				Op.POPENV:
					fr.env = fr.env[0]
					pc += 1
				Op.COPYENV:
					fr.env = fr.env.duplicate()
					pc += 1
				_:
					fail("Unknown step %d" % op)
					return _failed(allowed - left)
	return FAILED


## The declared name most like `name` (a typo or a wrong capital), or "".
static func _closest(name: String, names: Array) -> String:
	var best := ""
	var score := 0.55
	for n in names:
		if n == name:
			continue
		var sim := 1.0 if n.to_lower() == name.to_lower() else name.similarity(n)
		if sim > score:
			score = sim
			best = n
	return best


func _failed(steps: int) -> int:
	_used(steps)
	return FAILED


func _used(steps: int) -> void:
	_steps_hot += steps
	steps_total += steps


func _compare(op: int, a: Variant, b: Variant) -> bool:
	if a is String and b is String:
		match op:
			Op.LT: return a < b
			Op.GT: return a > b
			Op.LE: return a <= b
			_: return a >= b
	var x := to_num(a)
	var y := to_num(b)
	match op:
		Op.LT: return x < y
		Op.GT: return x > y
		Op.LE: return x <= y
		_: return x >= y


# --- properties ------------------------------------------------------------------

## What a value is, in a phrase: "undefined", "a number", "a list".
static func describe(v: Variant) -> String:
	if v == null:
		return "undefined"
	if v is Nul:
		return "null"
	if v is Arr:
		return "a list"
	if v is Obj:
		return "an object"
	if v is Promise:
		return "a promise (did you forget await?)"
	match type_of(v):
		"number": return "a number"
		"string": return "text"
		"boolean": return "true/false"
		"function": return "a function"
	return "something else"


func get_prop(obj: Variant, name: String, src: String) -> Variant:
	if obj is Obj:
		return obj.props.get(name)
	if obj is Arr:
		if name == "length":
			return float(obj.items.size())
		return JSStdlib.bound(self, obj, name)
	if obj is String:
		if name == "length":
			return float(obj.length())
		return JSStdlib.bound(self, obj, name)
	if nullish(obj):
		return fail("%s is %s, so it has no .%s" % [src, describe(obj), name])
	if obj is float or obj is Promise:
		return JSStdlib.bound(self, obj, name)
	return null


func get_index(obj: Variant, key: Variant, src: String) -> Variant:
	if obj is Arr:
		if key is float:
			var i := int(key)
			if float(i) == key and i >= 0 and i < obj.items.size():
				return obj.items[i]
			return null
		return get_prop(obj, to_str(key), src)
	if obj is String and key is float:
		var i := int(key)
		if float(i) == key and i >= 0 and i < obj.length():
			return obj[i]
		return null
	if obj is Obj:
		return obj.props.get(to_str(key))
	return get_prop(obj, to_str(key), src)


func set_prop(obj: Variant, name: String, v: Variant, src: String) -> void:
	if obj is Obj:
		if not obj.props.has(name):
			if obj.props.size() >= MAX_ITEMS:
				fail("%s has too many properties (the limit is %d)." % [src, MAX_ITEMS])
				return
			_count(1)
		obj.props[name] = v
	elif obj is Arr and name == "length":
		var n := to_num(v)
		if n < 0 or n != floorf(n) or n > MAX_ITEMS:
			fail("A list's length must be a whole number from 0 to %d." % MAX_ITEMS)
			return
		obj.items.resize(int(n))
	elif nullish(obj):
		fail("%s is %s, so .%s can't be set on it." % [src, describe(obj), name])
	elif obj is Arr:
		fail("Lists hold items by number: %s[0] = ..., not .%s" % [src, name])
	else:
		fail("%s is %s, so .%s can't be set on it." % [src, describe(obj), name])


func set_index(obj: Variant, key: Variant, v: Variant, src: String) -> void:
	if obj is Arr and key is float:
		var i := int(key)
		if float(i) != key or i < 0:
			fail("List positions are whole numbers from 0, so %s can't be one." % num_str(key))
			return
		if i >= MAX_ITEMS:
			fail("%s can't hold more than %d items." % [src, MAX_ITEMS])
			return
		if i >= obj.items.size():
			_count(i + 1 - obj.items.size())
			obj.items.resize(i + 1)
		obj.items[i] = v
		return
	set_prop(obj, to_str(key), v, src)


## The function `obj.name(...)` calls.
func method(obj: Variant, name: String, src: String) -> Variant:
	var fn = get_prop(obj, name, src.get_slice(".", 0) if src.contains(".") else src)
	if error:
		return null
	if fn is Fn or fn is Native:
		return fn
	if fn == null:
		return fail("%s isn't a function: %s has no %s." % [src, describe(obj) if not obj is Obj else src.rsplit(".", true, 1)[0], name])
	return fail("%s isn't a function, it's %s." % [src, describe(fn)])
