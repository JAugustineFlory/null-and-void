class_name JSCompiler
extends RefCounted
## Turns JSParser's tree into JSVM bytecode. Names are worked out here, once: a
## variable becomes (hops, slot) in its function's environment, so the VM never
## looks a name up by text except for built-ins like console and api.
##
## var c := JSCompiler.new()
## var main := c.compile(tree)   # a JSVM.Proto, or null if c.error is set

const Op = JSVM.Op

var error := {}
var _fn: FnCtx
var _names: Array = []  # every name the program declares, for "did you mean"


class FnCtx:
	var proto: JSVM.Proto
	var parent: FnCtx
	## Innermost last: {name: {slot, kind, owner}}. A scope with "@env" has its own
	## environment at run time (a block whose let is captured by a function made
	## inside it, so each pass gets a fresh variable, as in JavaScript); its "@n"
	## counts its slots. owner is the index of the scope holding the slot, or -1
	## for the function's own environment.
	var scopes: Array = []
	var loops: Array = []  # {breaks, continues, cont_target, iter, break_envs, cont_envs}
	var envs := 0  # block environments open at this point


func compile(tree: Dictionary) -> JSVM.Proto:
	var proto := JSVM.Proto.new()
	proto.name = "(main)"
	proto.is_async = true
	proto.all_names = _names
	_fn = FnCtx.new()
	_fn.proto = proto
	_fn.scopes.append({})
	_block_body(tree.body)
	_emit(Op.CONST, [null], tree.line)
	_emit(Op.RET, [], tree.line)
	return null if error else proto


# --- scopes ------------------------------------------------------------------

func _declare(name: String, kind: String, line: int) -> int:
	var scope: Dictionary = _fn.scopes.back()
	if scope.has(name):
		_fail(line, "%s is already declared above. Use a different name, or drop the %s to change it." % [name, kind])
		return 0
	if not name in _names:
		_names.append(name)
	for i in range(_fn.scopes.size() - 1, -1, -1):
		var owner: Dictionary = _fn.scopes[i]
		if owner.has("@env"):
			owner["@n"] += 1
			scope[name] = {"slot": owner["@n"], "kind": kind, "owner": i}
			return owner["@n"]
	_fn.proto.nslots += 1
	scope[name] = {"slot": _fn.proto.nslots, "kind": kind, "owner": -1}
	return _fn.proto.nslots


## [hops, slot, kind] for a name, or [] when it isn't declared in any enclosing scope.
## hops counts the environments between here and the one holding it.
func _resolve(name: String) -> Array:
	var f := _fn
	var hops := 0
	while f:
		for i in range(f.scopes.size() - 1, -1, -1):
			if f.scopes[i].has(name):
				var v: Dictionary = f.scopes[i][name]
				return [hops + _envs_in(f, v.owner + 1), v.slot, v.kind]
		hops += _envs_in(f, 0) + 1
		f = f.parent
	return []


## Block environments in f's scopes from index `from` inwards.
func _envs_in(f: FnCtx, from: int) -> int:
	var n := 0
	for j in range(from, f.scopes.size()):
		if f.scopes[j].has("@env"):
			n += 1
	return n


## Opens a block environment; returns where to write its size once it's known.
func _env_open(line: int) -> int:
	_fn.scopes.append({"@env": true, "@n": 0})
	_fn.envs += 1
	_emit(Op.NEWENV, [0], line)
	return _here() - 1


func _env_close(at: int, emit_pop: bool, line: int) -> void:
	_fn.proto.code[at] = _fn.scopes.back()["@n"]
	if emit_pop:
		_emit(Op.POPENV, [], line)
	_fn.scopes.pop_back()
	_fn.envs -= 1


## Does a block need its own environment? Only when it declares a let or const
## and makes a function that might keep hold of it.
static func _needs_env(decls: bool, body: Variant) -> bool:
	return decls and _has_function(body)


static func _has_function(node: Variant) -> bool:
	if node is Dictionary:
		if node.get("k") == "Func" or node.get("k") == "FuncDecl":
			return true
		for v in node.values():
			if (v is Dictionary or v is Array) and _has_function(v):
				return true
	elif node is Array:
		for v in node:
			if _has_function(v):
				return true
	return false


static func _declares(body: Array) -> bool:
	for st in body:
		if st.k == "Let":
			return true
	return false


## Declares every let, const and function in a block before running it, as
## JavaScript does, then makes the functions so they can be called early.
func _block_body(body: Array) -> void:
	for s in body:
		if s.k == "Let":
			for d in s.decls:
				var slot := _declare(d.name, s.kind, d.line)
				_emit(Op.TDZ, [slot], d.line)
		elif s.k == "FuncDecl":
			_declare(s.name, "function", s.line)
	for s in body:
		if s.k == "FuncDecl":
			_closure(s)
			_store(s.name, s.line, true)
	for s in body:
		if error:
			return
		if s.k != "FuncDecl":
			_stmt(s)


# --- statements --------------------------------------------------------------

func _stmt(s: Dictionary) -> void:
	if error:
		return
	match s.k:
		"Expr":
			var e: Dictionary = s.expr
			if e.k == "Assign" and e.target.k == "Ident":
				_assign(e, false)
			elif e.k == "Update" and e.target.k == "Ident" and not _resolve(e.target.name).is_empty():
				_update(e, true)
			else:
				_expr(e)
				_emit(Op.POP, [], s.line)
		"Let":
			for d in s.decls:
				if d.init == null:
					_emit(Op.CONST, [null], d.line)
				else:
					_expr(d.init, d.name)
				_store(d.name, d.line, true)
		"Block":
			if _needs_env(_declares(s.body), s.body):
				var at := _env_open(s.line)
				_block_body(s.body)
				_env_close(at, true, s.line)
			else:
				_fn.scopes.append({})
				_block_body(s.body)
				_fn.scopes.pop_back()
		"If":
			var to_else := _test(s.test)
			_scoped(s.then)
			if s["else"] != null:
				var to_end := _jump(Op.JMP, s.line)
				_patch(to_else)
				_scoped(s["else"])
				_patch(to_end)
			else:
				_patch(to_else)
		"While":
			var top := _here()
			var to_end := _test(s.test)
			_loop_begin(top, false, _fn.envs, _fn.envs)
			_scoped(s.body)
			_emit(Op.JMP, [top], s.line)
			_patch(to_end)
			_loop_end(_here())
		"For":
			# With a function in the body, each pass gets a fresh copy of the loop's
			# let variables (COPYENV), as JavaScript does.
			var env: bool = s.init != null and s.init.k == "Let" and _has_function(s.body)
			var env_at := -1
			if env:
				env_at = _env_open(s.line)
			else:
				_fn.scopes.append({})
			if s.init != null:
				if s.init.k == "Let":
					_block_body([s.init])
				else:
					_stmt(s.init)
			var top := _here()
			var to_end := -1
			if s.test != null:
				to_end = _test(s.test)
			_loop_begin(-1, false, _fn.envs, _fn.envs)
			_scoped(s.body)
			_fn.loops.back().cont_target = _here()
			if env:
				_emit(Op.COPYENV, [], s.line)
			if s.update != null:
				_expr(s.update)
				_emit(Op.POP, [], s.line)
			_emit(Op.JMP, [top], s.line)
			if to_end >= 0:
				_patch(to_end)
			_loop_end(_here())
			if env:
				_env_close(env_at, true, s.line)
			else:
				_fn.scopes.pop_back()
		"ForOf":
			_expr(s.iter)
			_emit(Op.ITER, [_text(s.iter)], s.line)
			var top := _here()
			var to_end := _jump(Op.NEXT, s.line)
			var outer := _fn.envs
			var env := _has_function(s.body)
			var env_at := -1
			if env:
				env_at = _env_open(s.line)  # a fresh loop variable each pass
			else:
				_fn.scopes.append({})
			var slot := _declare(s.name, s.kind, s.line)
			_emit(Op.STORE, [0, slot], s.line)
			_loop_begin(-1, true, outer, _fn.envs)
			_scoped(s.body)
			_fn.loops.back().cont_target = _here()
			if env:
				_env_close(env_at, true, s.line)
			else:
				_fn.scopes.pop_back()
			_emit(Op.JMP, [top], s.line)
			_patch(to_end)
			_loop_end(_here())
		"Break":
			var loop: Dictionary = _fn.loops.back()
			for i in _fn.envs - loop.break_envs:
				_emit(Op.POPENV, [], s.line)
			if loop.iter:
				_emit(Op.POP, [], s.line)
			loop.breaks.append(_jump(Op.JMP, s.line))
		"Continue":
			var loop: Dictionary = _fn.loops.back()
			for i in _fn.envs - loop.cont_envs:
				_emit(Op.POPENV, [], s.line)
			loop.continues.append(_jump(Op.JMP, s.line))
		"Return":
			if s.arg == null:
				_emit(Op.CONST, [null], s.line)
			else:
				_expr(s.arg)
			_emit(Op.RET, [], s.line)
		"FuncDecl":
			pass  # made at the top of its block
		"Empty":
			pass


## A loop or if body: a block gets its own scope; a lone let there is an error in JavaScript.
func _scoped(s: Dictionary) -> void:
	if s.k == "Let":
		_fail(s.line, "A %s here needs { } around it." % s.kind)
		return
	_stmt(s)


## break_envs and cont_envs: how many block environments are open where a break
## and a continue land.
func _loop_begin(cont_target: int, iter: bool, break_envs: int, cont_envs: int) -> void:
	_fn.loops.append({"breaks": [], "continues": [], "cont_target": cont_target, "iter": iter,
		"break_envs": break_envs, "cont_envs": cont_envs})


func _loop_end(end: int) -> void:
	var loop: Dictionary = _fn.loops.pop_back()
	for at in loop.breaks:
		_fn.proto.code[at] = end
	for at in loop.continues:
		_fn.proto.code[at] = loop.cont_target


## A condition, then a jump past what follows when it's false; returns where to
## write that jump's target. Comparisons jump in one step.
func _test(e: Dictionary) -> int:
	if e.k == "Binary" and e.op in ["<", ">", "<=", ">=", "===", "!=="]:
		_expr(e.l)
		_expr(e.r)
		_emit(Op.JCMPF, [_binop(e.op), -1], e.line)
		return _here() - 1
	_expr(e)
	return _jump(Op.JF, e.line)


# --- expressions -------------------------------------------------------------

## `name_hint` names a function written as `const openDoor = () => ...`.
func _expr(e: Dictionary, name_hint := "") -> void:
	if error:
		return
	var line: int = e.line
	match e.k:
		"Num", "Str", "Bool":
			_emit(Op.CONST, [e.v], line)
		"Null":
			_emit(Op.CONST, [JSVM.NULL], line)
		"Ident":
			_load(e.name, line)
		"Tpl":
			for i in e.quasis.size():
				_emit(Op.CONST, [e.quasis[i]], line)
				if i < e.exprs.size():
					_expr(e.exprs[i])
			_emit(Op.TPL, [e.quasis.size() + e.exprs.size()], line)
		"Array":
			for item in e.items:
				_expr(item)
			_emit(Op.ARRAY, [e.items.size()], line)
		"Object":
			var keys := []
			for p in e.props:
				if p.key in keys:
					_fail(line, "This object has %s twice." % p.key)
					return
				keys.append(p.key)
				_expr(p.value, p.key)
			_emit(Op.OBJECT, [keys], line)
		"Func":
			if e.name == "" and name_hint != "":
				e.name = name_hint
			_closure(e)
		"Unary":
			if e.op == "typeof" and e.arg.k == "Ident" and _resolve(e.arg.name).is_empty():
				_emit(Op.TYPEOF_G, [e.arg.name], line)
				return
			_expr(e.arg)
			_emit({"!": Op.NOT, "-": Op.NEG, "+": Op.PLUS, "typeof": Op.TYPEOF}[e.op], [], line)
		"Binary":
			_expr(e.l)
			_expr(e.r)
			_emit(_binop(e.op), [], line)
		"Logical":
			_expr(e.l)
			var j := _jump({"&&": Op.JF_KEEP, "||": Op.JT_KEEP, "??": Op.JNN_KEEP}[e.op], line)
			_expr(e.r)
			_patch(j)
		"Cond":
			_expr(e.test)
			var to_b := _jump(Op.JF, line)
			_expr(e.a)
			var to_end := _jump(Op.JMP, line)
			_patch(to_b)
			_expr(e.b)
			_patch(to_end)
		"Assign":
			_assign(e)
		"Update":
			_update(e)
		"Await":
			_expr(e.arg)
			_emit(Op.AWAIT, [], line)
		"Member", "Index", "Call":
			var jumps := []
			_chain(e, jumps)
			for j in jumps:
				_patch(j)
		_:
			_fail(line, "This can't be used here.")


## One link of a.b?.c(d)[e]; every ?. jumps to the end of the whole chain.
func _chain(e: Dictionary, jumps: Array) -> void:
	var line: int = e.line
	match e.k:
		"Member":
			_chain_obj(e.obj, jumps)
			if e.optional:
				jumps.append(_jump(Op.JNULLISH, line))
			_emit(Op.GET, [e.name, _text(e.obj)], line)
		"Index":
			_chain_obj(e.obj, jumps)
			if e.optional:
				jumps.append(_jump(Op.JNULLISH, line))
			_expr(e.index)
			_emit(Op.GETI, [_text(e.obj)], line)
		"Call":
			var callee: Dictionary = e.callee
			if callee.k == "Member" and not e.optional:
				_chain_obj(callee.obj, jumps)
				if callee.optional:
					jumps.append(_jump(Op.JNULLISH, line))
				for a in e.args:
					_expr(a)
				_emit(Op.CALLM, [callee.name, e.args.size(), _text(callee)], line)
			else:
				_chain_obj(callee, jumps)
				if e.optional:
					jumps.append(_jump(Op.JNULLISH, line))
				for a in e.args:
					_expr(a)
				_emit(Op.CALL, [e.args.size(), _text(callee)], line)


func _chain_obj(e: Dictionary, jumps: Array) -> void:
	if e.k == "Member" or e.k == "Index" or e.k == "Call":
		_chain(e, jumps)
	else:
		_expr(e)


## `keep` leaves the assigned value on the stack, for `a = b = 0` and `f(x = 1)`.
func _assign(e: Dictionary, keep := true) -> void:
	var t: Dictionary = e.target
	var line: int = e.line
	var op: String = e.op
	match t.k:
		"Ident":
			if op != "=":
				_load(t.name, line)
			_expr(e.value, t.name)
			if op != "=":
				_emit(_binop(op.trim_suffix("=")), [], line)
			if keep:
				_emit(Op.DUP, [], line)
			_store(t.name, line, false)
		"Member":
			_expr(t.obj)
			if op != "=":
				_emit(Op.DUP, [], line)
				_emit(Op.GET, [t.name, _text(t.obj)], line)
			_expr(e.value)
			if op != "=":
				_emit(_binop(op.trim_suffix("=")), [], line)
			_emit(Op.SET, [t.name, _text(t.obj)], line)
		"Index":
			_expr(t.obj)
			_expr(t.index)
			if op != "=":
				_emit(Op.DUP2, [], line)
				_emit(Op.GETI, [_text(t.obj)], line)
			_expr(e.value)
			if op != "=":
				_emit(_binop(op.trim_suffix("=")), [], line)
			_emit(Op.SETI, [_text(t.obj)], line)


## `discard`: a statement like i++ whose value nobody reads.
func _update(e: Dictionary, discard := false) -> void:
	var t: Dictionary = e.target
	var delta := 1.0 if e.op == "++" else -1.0
	var line: int = e.line
	match t.k:
		"Ident":
			var r := _resolve(t.name)
			if r.is_empty():
				_emit(Op.UPD_G, [t.name, delta, e.prefix], line)
			elif r[2] == "const":
				_fail(line, "%s is a const, so it can't change. Declare it with let instead." % t.name)
			else:
				_emit(Op.UPD_L, [r[0], r[1], delta, 2 if discard else (1 if e.prefix else 0), t.name], line)
		"Member":
			_expr(t.obj)
			_emit(Op.UPD_P, [t.name, delta, e.prefix, _text(t.obj)], line)
		"Index":
			_expr(t.obj)
			_expr(t.index)
			_emit(Op.UPD_I, [delta, e.prefix, _text(t.obj)], line)


func _load(name: String, line: int) -> void:
	var r := _resolve(name)
	if r.is_empty():
		_emit(Op.LOAD_G, [name], line)
	elif r[0] == 0:
		_emit(Op.LOADL, [r[1], name], line)
	else:
		_emit(Op.LOAD, [r[0], r[1], name], line)


## Pops the top of the stack into `name`. `init` is a let/const/function being set up.
func _store(name: String, line: int, init: bool) -> void:
	var r := _resolve(name)
	if r.is_empty():
		_emit(Op.STORE_G, [name], line)
		return
	if r[2] == "const" and not init:
		_fail(line, "%s is a const, so it can't change. Declare it with let instead." % name)
		return
	if init:
		_emit(Op.STORE, [r[0], r[1]], line)
	else:
		_emit(Op.ASSIGN, [r[0], r[1], name], line)


func _closure(f: Dictionary) -> void:
	var proto := JSVM.Proto.new()
	proto.all_names = _names
	proto.name = f.name
	proto.nparams = f.params.size()
	proto.is_async = f.async
	var ctx := FnCtx.new()
	ctx.proto = proto
	ctx.parent = _fn
	ctx.scopes.append({})
	_fn = ctx
	for p in f.params:
		_declare(p, "let", f.line)
	if f.expr_body:
		_expr(f.body)
		_emit(Op.RET, [], f.line)
	else:
		_block_body(f.body.body)
		_emit(Op.CONST, [null], f.line)
		_emit(Op.RET, [], f.line)
	_fn = ctx.parent
	_emit(Op.CLOSURE, [proto], f.line)


func _binop(op: String) -> int:
	return {"+": Op.ADD, "-": Op.SUB, "*": Op.MUL, "/": Op.DIV, "%": Op.MOD, "**": Op.POW,
		"==": Op.EQ, "!=": Op.NE, "===": Op.SEQ, "!==": Op.SNE, "<": Op.LT, ">": Op.GT,
		"<=": Op.LE, ">=": Op.GE}[op]


## How an expression reads, for error messages: `doors[i].locked`, `openDoor(...)`.
func _text(e: Dictionary) -> String:
	match e.k:
		"Ident":
			return e.name
		"Member":
			return "%s%s%s" % [_text(e.obj), "?." if e.optional else ".", e.name]
		"Index":
			return "%s[%s]" % [_text(e.obj), _text(e.index)]
		"Call":
			return "%s(...)" % _text(e.callee)
		"Num":
			return JSVM.num_str(e.v)
		"Str":
			return "\"%s\"" % e.v
	return "(...)"


# --- code ----------------------------------------------------------------------

func _emit(op: int, args: Array, line: int) -> void:
	var p := _fn.proto
	p.code.append(op)
	p.lines.append(line)
	for a in args:
		p.code.append(a)
		p.lines.append(line)


func _here() -> int:
	return _fn.proto.code.size()


## Emits a jump with its target left blank; returns where to write it.
func _jump(op: int, line: int) -> int:
	_emit(op, [-1], line)
	return _fn.proto.code.size() - 1


func _patch(at: int) -> void:
	_fn.proto.code[at] = _here()


func _fail(line: int, message: String) -> void:
	if not error:
		error = {"line": line, "col": 0, "message": message}
