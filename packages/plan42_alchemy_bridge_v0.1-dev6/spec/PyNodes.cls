/* PyNodes.cls -- OO Python code-generation node tree for Plan42        */
/* Each class represents one Python construct.                           */
/* Usage: build a tree of PyNode objects from the spec, then call       */
/*        root~render('') to get the complete Python source.            */

/* ================================================================== */
/* PyNode -- abstract base                                              */
/* ================================================================== */
::class PyNode public
::method render
  use arg ind
  return ''            /* subclasses override */


/* ================================================================== */
/* Leaf / expression nodes                                             */
/* ================================================================== */

::class PyLiteral subclass PyNode public
::method init
  expose _val
  use arg val
  _val = val

::method render
  expose _val
  use arg ind
  v = _val
  if v = .nil then return 'None'
  if v~isA(.Array) then do
    out = '['
    do i = 1 to v~items
      if i > 1 then out = out||', '
      out = out||(.PyLiteral~new(v~at(i))~render(''))
    end
    return out||']'
  end
  if v~isA(.Directory) then do
    out = '{'
    first = .true
    do k over v~allIndexes
      if \first then out = out||', '
      out = out||(.PyLiteral~new(k)~render(''))||': '||(.PyLiteral~new(v~at(k))~render(''))
      first = .false
    end
    return out||'}'
  end
  s = ''||v
  if datatype(s, 'N') then return s
  s = s~changeStr('\', '\\')
  s = s~changeStr('"', '\"')
  s = s~changeStr('0a'x, '\n')
  s = s~changeStr('09'x, '\t')
  s = s~changeStr('0d'x, '\r')
  return '"'||s||'"'


::class PyVar subclass PyNode public
::method init
  expose _name
  use arg name
  _name = name
::method render
  expose _name
  use arg ind
  return _name


::class PyConcat subclass PyNode public
::method init
  expose _l _r
  use arg l, r
  _l = l; _r = r
::method render
  expose _l _r
  use arg ind
  return 'str('||_l~render('')||') + str('||_r~render('')||')'


::class PyBinOp subclass PyNode public
::method init
  expose _l _op _r
  use arg l, op, r
  _l = l; _op = op; _r = r
::method render
  expose _l _op _r
  use arg ind
  return _l~render('')||' '||_op||' '||_r~render('')


::class PyNot subclass PyNode public
::method init
  expose _e
  use arg e
  _e = e
::method render
  expose _e
  use arg ind
  return 'not ('||_e~render('')||')'


::class PyCallExpr subclass PyNode public
::method init
  expose _func _args
  use arg func, args
  _func = func; _args = args
::method render
  expose _func _args
  use arg ind
  argStr = ''
  if _args \= .nil then do
    do i = 1 to _args~items
      if i > 1 then argStr = argStr||', '
      argStr = argStr||_args~at(i)~render('')
    end
  end
  return _func||'('||argStr||')'


::class PyMethodExpr subclass PyNode public
::method init
  expose _obj _meth _args
  use arg obj, meth, args
  _obj = obj; _meth = meth; _args = args
::method render
  expose _obj _meth _args
  use arg ind
  argStr = ''
  if _args \= .nil then do
    do i = 1 to _args~items
      if i > 1 then argStr = argStr||', '
      argStr = argStr||_args~at(i)~render('')
    end
  end
  return _obj~render('')||'.'||_meth||'('||argStr||')'


/* ================================================================== */
/* Statement nodes                                                     */
/* ================================================================== */

::class PyCast subclass PyNode public
::method init
  expose _expr _to
  use arg expr, to
  _expr = expr; _to = to
::method render
  expose _expr _to
  use arg ind
  if ind = .nil then ind = ''
  inner = _expr~render('')
  t = translate(_to)
  select
    when t = 'STR'   then return 'str('||inner||')'
    when t = 'INT'   then return 'int('||inner||')'
    when t = 'FLOAT' then return 'float('||inner||')'
    when t = 'BOOL'  then return 'bool('||inner||')'
    when t = 'LIST'  then return 'list('||inner||')'
    when t = 'DICT'  then return 'dict('||inner||')'
    otherwise        return inner
  end


::class PyPass subclass PyNode public
::method render
  use arg ind
  if ind = .nil then ind = ''
  return ind||'pass'


::class PyReturn subclass PyNode public
::method init
  expose _e
  use arg e
  _e = e
::method render
  expose _e
  use arg ind
  if ind = .nil then ind = ''
  if _e = .nil then return ind||'return'
  return ind||'return '||_e~render('')


::class PyAssign subclass PyNode public
::method init
  expose _name _e
  use arg name, e
  _name = name; _e = e
::method render
  expose _name _e
  use arg ind
  if ind = .nil then ind = ''
  return ind||_name||' = '||_e~render('')


::class PyExprStmt subclass PyNode public
::method init
  expose _e
  use arg e
  _e = e
::method render
  expose _e
  use arg ind
  if ind = .nil then ind = ''
  return ind||_e~render('')


::class PyOutput subclass PyNode public
::method init
  expose _e
  use arg e
  _e = e
::method render
  expose _e
  use arg ind
  if ind = .nil then ind = ''
  return ind||'print('||_e~render('')||')'


::class PyIf subclass PyNode public
::method init
  expose _cond _body
  use arg cond, body
  _cond = cond; _body = body
::method render
  expose _cond _body
  use arg ind
  if ind = .nil then ind = ''
  lf = '0a'x
  bInd = ind||'    '
  out = ind||'if '||_cond~render('')||':'
  if _body = .nil | _body~items = 0 then return out||lf||bInd||'pass'
  do stmt over _body; out = out||lf||stmt~render(bInd); end
  return out


::class PyFor subclass PyNode public
::method init
  expose _var _in _body
  use arg var, inExpr, body
  _var = var; _in = inExpr; _body = body
::method render
  expose _var _in _body
  use arg ind
  if ind = .nil then ind = ''
  lf = '0a'x
  bInd = ind||'    '
  out = ind||'for '||_var||' in '||_in~render('')||':'
  if _body = .nil | _body~items = 0 then return out||lf||bInd||'pass'
  do stmt over _body; out = out||lf||stmt~render(bInd); end
  return out


::class PyDef subclass PyNode public
::method init
  expose _name _params _body
  use arg name, params, body
  _name = name; _params = params; _body = body
::method render
  expose _name _params _body
  use arg ind
  if ind = .nil then ind = ''
  lf = '0a'x
  bInd = ind||'    '
  out = ind||'def '||_name||'('||_params||'):'
  if _body = .nil | _body~items = 0 then return out||lf||bInd||'pass'
  do stmt over _body; out = out||lf||stmt~render(bInd); end
  return out


::class PyConst subclass PyNode public
::method init
  expose _name _e
  use arg name, e
  _name = name; _e = e
::method render
  expose _name _e
  use arg ind
  if ind = .nil then ind = ''
  return ind||_name||' = '||_e~render('')


/* ================================================================== */
/* PyRawBlock -- pre-formed Python (runtime helpers, shebang, etc.)   */
/* ================================================================== */
::class PyRawBlock subclass PyNode public
::method init
  expose _lines
  use arg lines    /* Array of strings */
  _lines = lines
::method render
  expose _lines
  use arg ind
  lf = '0a'x
  out = ''
  do line over _lines; out = out||line||lf; end
  return out


/* ================================================================== */
/* PyModule -- top-level container                                     */
/* ================================================================== */
::class PyModule subclass PyNode public
::method init
  expose _items
  _items = .Array~new
::method add
  expose _items
  use arg node
  _items~append(node)
::method render
  expose _items
  use arg ind
  if ind = .nil then ind = ''
  lf = '0a'x
  out = ''
  do item over _items; out = out||item~render(ind)||lf; end
  return out


/* ================================================================== */
/* Plan42PythonBuilder                                                 */
/* Converts a Plan42 spec (OORexx Directories/Arrays from json.cls)   */
/* into a PyModule tree, then renders it to Python source.            */
/* ================================================================== */
::class Plan42PythonBuilder public

::method init
  expose _gen
  use arg gen     /* PythonImplGenerator -- used for _resolveImplNode */
  _gen = gen

/* ---- impl name -> Python function name ---- */
::method safeImplFuncName
  expose _gen
  use arg implName
  safe = implName~changeStr('.','_')~changeStr('-','_')
  safe = translate(safe,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')
  if translate(left(implName,10)) = 'PREFERRED.' then return '_p42_'||safe
  if translate(left(implName,4)) = 'WIK.'       then return '_p42_'||safe
  if _gen~_resolveImplNode(implName) \= .nil    then return '_p42_impl_'||safe
  return safe   /* routine reference -- call directly */

/* ---- expressions ---- */
::method buildExpr
  expose _gen
  use arg node
  if node = .nil then return .PyLiteral~new(.nil)
  if node~isA(.String)    then return .PyVar~new(node)
  if node~isA(.Array)     then return .PyLiteral~new(node)
  /* Directory with no 'op' field is a plain dict literal             */
  if node~isA(.Directory) & node~at('op') = .nil then
    return .PyLiteral~new(node)
  op = translate(node~at('op'))
  select
    when op = 'LITERAL'  then do
      val = node~at('value')
      /* type:str on a literal makes it unambiguously a string, not a var */
      typ = node~at('type')
      if typ \= .nil & translate(typ) = 'STR' & val~isA(.String) then
        return .PyLiteral~new(val)
      return .PyLiteral~new(val)
    end
    when op = 'VAR'      then return .PyVar~new(node~at('name'))
    when op = 'CAST'     then return .PyCast~new(self~buildExpr(node~at('expr')), node~at('to'))
    when op = 'NIL'      then return .PyLiteral~new(.nil)
    when op = 'CONCAT'   then return .PyConcat~new(self~buildExpr(node~at('left')), self~buildExpr(node~at('right')))
    when op = 'ADD'      then return .PyBinOp~new(self~buildExpr(node~at('left')), '+',   self~buildExpr(node~at('right')))
    when op = 'SUB'      then return .PyBinOp~new(self~buildExpr(node~at('left')), '-',   self~buildExpr(node~at('right')))
    when op = 'MUL'      then return .PyBinOp~new(self~buildExpr(node~at('left')), '*',   self~buildExpr(node~at('right')))
    when op = 'DIV'      then return .PyBinOp~new(self~buildExpr(node~at('left')), '/',   self~buildExpr(node~at('right')))
    when op = 'MOD'      then return .PyBinOp~new(self~buildExpr(node~at('left')), '%',   self~buildExpr(node~at('right')))
    when op = 'EQ'       then return .PyBinOp~new(self~buildExpr(node~at('left')), '==',  self~buildExpr(node~at('right')))
    when op = 'NEQ'      then return .PyBinOp~new(self~buildExpr(node~at('left')), '!=',  self~buildExpr(node~at('right')))
    when op = 'GT'       then return .PyBinOp~new(self~buildExpr(node~at('left')), '>',   self~buildExpr(node~at('right')))
    when op = 'LT'       then return .PyBinOp~new(self~buildExpr(node~at('left')), '<',   self~buildExpr(node~at('right')))
    when op = 'GTE'      then return .PyBinOp~new(self~buildExpr(node~at('left')), '>=',  self~buildExpr(node~at('right')))
    when op = 'LTE'      then return .PyBinOp~new(self~buildExpr(node~at('left')), '<=',  self~buildExpr(node~at('right')))
    when op = 'AND'      then return .PyBinOp~new(self~buildExpr(node~at('left')), 'and', self~buildExpr(node~at('right')))
    when op = 'OR'       then return .PyBinOp~new(self~buildExpr(node~at('left')), 'or',  self~buildExpr(node~at('right')))
    when op = 'NOT'      then return .PyNot~new(self~buildExpr(node~at('value')))
    when op = 'IMPL_USE' then return self~buildCallExpr(node~at('name'), node~at('args'))
    when op = 'METHOD'   then do
      aExprs = self~buildArgList(node~at('args'))
      return .PyMethodExpr~new(self~buildExpr(node~at('obj')), node~at('name'), aExprs)
    end
    when op = 'INDEX'    then do
      obj = self~buildExpr(node~at('obj'))
      idx = self~buildExpr(node~at('index'))
      return .PyVar~new(obj~render('')||'['||idx~render('')||']')
    end
    otherwise            return .PyVar~new('# expr:'||op)
  end

::method buildCallExpr
  use arg implName, argsArr
  return .PyCallExpr~new(self~safeImplFuncName(implName), self~buildArgList(argsArr))

::method buildArgList
  use arg arr
  out = .Array~new
  if arr = .nil          then return out
  if \arr~isA(.Array)   then return out
  do i = 1 to arr~items; out~append(self~buildExpr(arr~at(i))); end
  return out

/* ---- statements ---- */
::method buildBody
  use arg arr
  stmts = .Array~new
  if arr = .nil         then return stmts
  if \arr~isA(.Array)  then return stmts
  do i = 1 to arr~items
    s = self~buildStmt(arr~at(i))
    if s \= .nil then stmts~append(s)
  end
  return stmts

::method buildStmt
  use arg node
  if node = .nil then return .nil
  op = translate(node~at('op'))
  select
    when op = 'RETURN'   then return .PyReturn~new(self~buildExpr(node~at('expr')))
    when op = 'DECLARE'  then do
      typ = node~at('type')
      val = node~at('value')
      if val = .nil & typ \= .nil then do
        /* typed declare with no value: use language default          */
        t = translate(typ)
        select
          when t = 'DICT'  then val = .PyVar~new('{}')
          when t = 'LIST'  then val = .PyVar~new('[]')
          when t = 'INT'   then val = .PyLiteral~new(0)
          when t = 'STR'   then val = .PyLiteral~new('')
          otherwise             val = .PyLiteral~new(.nil)
        end
        return .PyAssign~new(node~at('name'), val)
      end
      return .PyAssign~new(node~at('name'), self~buildExpr(val))
    end
    when op = 'ASSIGN'   then return .PyAssign~new(node~at('name'), self~buildExpr(node~at('value')))
    when op = 'OUTPUT'   then return .PyOutput~new(self~buildExpr(node~at('expr')))
    when op = 'CONTINUE' then return .PyExprStmt~new(.PyVar~new('continue'))
    when op = 'BREAK'    then return .PyExprStmt~new(.PyVar~new('break'))
    when op = 'IF'       then do
      return .PyIf~new(self~buildExpr(node~at('cond')), self~buildBody(node~at('body')))
    end
    when op = 'FOR_EACH' then do
      return .PyFor~new(node~at('var'), self~buildExpr(node~at('in')), self~buildBody(node~at('body')))
    end
    when op = 'IMPL_USE' then do
      call = self~buildCallExpr(node~at('name'), node~at('args'))
      res  = node~at('result')
      if res \= .nil & res \= 'The NIL object' then
        return .PyAssign~new(res, call)
      return .PyExprStmt~new(call)
    end
    otherwise return .PyVar~new('# '||op)
  end

/* ---- impl helpers (wik.*, custom impls) ---- */
::method buildImplHelper
  expose _gen
  use arg implNode, implName, params
  /* Get the inline implementation for PYTHON3 */
  implDef = _gen~resolveImpl(implNode)
  if implDef = .nil then return .nil
  inlineCode = implDef~at('inline')
  if inlineCode = .nil then return .nil
  /* Substitute param names literally in the inline template */
  code = inlineCode
  if params \= .nil then do
    do pi = 1 to params~items
      pname = params~at(pi)
      code = code~changeStr('{'||pname||'}', pname)
    end
  end
  /* Build param string */
  paramStr = ''
  if params \= .nil then do
    do pi = 1 to params~items
      if pi > 1 then paramStr = paramStr||', '
      paramStr = paramStr||params~at(pi)
    end
  end
  funcName = self~safeImplFuncName(implName)
  body = .Array~new
  body~append(.PyReturn~new(.PyVar~new(code)))
  return .PyDef~new(funcName, paramStr, body)

/* ---- full module ---- */
::method buildModule
  expose _gen
  use arg spec
  module = .PyModule~new
  /* Shebang + header */
  hdr = .Array~new
  hdr~append('#!/usr/bin/env python3')
  hdr~append('# Generated by Plan42 -- '||spec~name)
  hdr~append('')
  module~add(.PyRawBlock~new(hdr))
  /* Runtime helpers */
  module~add(.PyRawBlock~new(self~runtimeHelperLines))
  /* Custom impl helpers from spec */
  do i = 1 to spec~nodes~items
    node = spec~nodes~at(i)
    if node = .nil then iterate
    if translate(node~at('op')) \= 'IMPL' then iterate
    implName = node~at('name')
    implNode = _gen~_resolveImplNode(implName)
    if implNode = .nil then iterate
    helper = self~buildImplHelper(implNode, implName, node~at('params'))
    if helper \= .nil then do
      module~add(helper)
      module~add(.PyRawBlock~new(.Array~of('')))
    end
  end
  /* Spec nodes: consts then routines */
  do i = 1 to spec~nodes~items
    node = spec~nodes~at(i)
    if node = .nil then iterate
    op = translate(node~at('op'))
    if op = 'CONST' then do
      module~add(.PyConst~new(node~at('name'), self~buildExpr(node~at('value'))))
      module~add(.PyRawBlock~new(.Array~of('')))
    end
  end
  do i = 1 to spec~nodes~items
    node = spec~nodes~at(i)
    if node = .nil then iterate
    op = translate(node~at('op'))
    if op = 'ROUTINE' then do
      pArr = node~at('params')
      paramStr = ''
      if pArr \= .nil then do
        do pi = 1 to pArr~items
          if pi > 1 then paramStr = paramStr||', '
          paramStr = paramStr||pArr~at(pi)
        end
      end
      body = self~buildBody(node~at('body'))
      module~add(.PyDef~new(node~at('name'), paramStr, body))
      module~add(.PyRawBlock~new(.Array~of('')))
    end
  end
  return module

/* ---- runtime helper function bodies ---- */
::method runtimeHelperLines
  lf = '0a'x
  lines = .Array~new

  call addLine 'def _p42_unresolved_impl(name, *args):'
  call addLine '    raise NotImplementedError('
  call addLine "        f'Plan42 impl unresolved: {name}  args={args!r}')"
  call addLine ''

  call addLine 'def _p42_preferred_file_stream_lines(path):'
  call addLine '    with open(str(path), "r", encoding="utf-8", errors="replace") as _f:'
  call addLine '        for _line in _f: yield _line'
  call addLine ''

  call addLine 'def _p42_preferred_data_jsonl_parse(line):'
  call addLine '    import json as _json'
  call addLine '    raw = (line or "").strip()'
  call addLine '    if not raw: return None'
  call addLine '    try: return _json.loads(raw)'
  call addLine '    except Exception: return None'
  call addLine ''

  call addLine 'def _p42_preferred_ui_progress(counter, interval, label=""):'
  call addLine '    try:'
  call addLine '        if int(interval) > 0 and int(counter) % int(interval) == 0:'
  call addLine '            print(str(counter) + " " + str(label), flush=True)'
  call addLine '    except Exception: pass'
  call addLine ''

  call addLine 'def _p42_preferred_file_multiwrite_open(output_dir, keys, suffixes):'
  call addLine '    from pathlib import Path'
  call addLine '    root = Path(str(output_dir))'
  call addLine '    root.mkdir(parents=True, exist_ok=True)'
  call addLine '    handles = {}'
  call addLine '    for _k in keys:'
  call addLine '        for _s in suffixes:'
  call addLine '            handles[(_k, _s)] = (root / (_k + "." + _s)).open("w", encoding="utf-8")'
  call addLine '    return handles'
  call addLine ''

  call addLine 'def _p42_preferred_file_multiwrite_write(handles, key, suffix, line):'
  call addLine '    _h = handles.get((str(key), str(suffix)))'
  call addLine '    if _h: _h.write(str(line))'
  call addLine ''

  call addLine 'def _p42_preferred_file_multiwrite_close(handles):'
  call addLine '    for _h in handles.values(): _h.close()'
  call addLine ''

  call addLine 'def _p42_preferred_file_write_tsv(data, path):'
  call addLine '    from pathlib import Path'
  call addLine '    with Path(str(path)).open("w", encoding="utf-8") as _f:'
  call addLine '        if isinstance(data, dict):'
  call addLine '            for _k in sorted(data):'
  call addLine '                _v = data[_k]'
  call addLine '                if isinstance(_v, (list, tuple, set)):'
  call addLine '                    _v = " ".join(str(_x) for _x in _v)'
  call addLine '                _f.write(str(_k) + "\t" + str(_v) + "\n")'
  call addLine ''

  call addLine 'def _p42_soundex_key(text):'
  call addLine '    _s = "".join(_c for _c in str(text).upper() if _c.isalpha())'
  call addLine '    if not _s: return "Z000"'
  call addLine '    _CODES = {"B":"1","F":"1","P":"1","V":"1","C":"2","G":"2","J":"2",'
  call addLine '              "K":"2","Q":"2","S":"2","X":"2","Z":"2","D":"3","T":"3",'
  call addLine '              "L":"4","M":"5","N":"5","R":"6"}'
  call addLine '    _out = _s[0]; _prev = _CODES.get(_s[0], "0")'
  call addLine '    for _ch in _s[1:]:'
  call addLine '        _code = _CODES.get(_ch, "0")'
  call addLine '        if _code != "0" and _code != _prev: _out += _code'
  call addLine '        if _code != "0": _prev = _code'
  call addLine '        if len(_out) >= 4: break'
  call addLine '    return (_out + "000")[:4]'
  call addLine ''

  call addLine 'def _p42_preferred_data_soundex_from_ipa(output_dir, lang):'
  call addLine '    from pathlib import Path'
  call addLine '    _p = Path(str(output_dir)) / (str(lang) + ".ipa")'
  call addLine '    _buckets = {}'
  call addLine '    if not _p.exists(): return _buckets'
  call addLine '    with _p.open("r", encoding="utf-8", errors="replace") as _f:'
  call addLine '        for _line in _f:'
  call addLine '            _line = _line.rstrip("\n")'
  call addLine '            if not _line or "\t" not in _line: continue'
  call addLine '            _word, _ipa = _line.split("\t", 1)'
  call addLine '            _key = _p42_soundex_key(_ipa or _word)'
  call addLine '            _buckets.setdefault(_key, []).append(_word)'
  call addLine '    return _buckets'
  call addLine ''

  call addLine '_P42_TOPIC_NOISE = {"noun","verb","adjective","adverb","proper","pronoun",'
  call addLine '    "plural","singular","masculine","feminine","neuter","uncountable",'
  call addLine '    "transitive","intransitive","obsolete","countable","common"}'
  call addLine ''

  call addLine 'def _normalise_topic(raw):'
  call addLine '    import re as _re'
  call addLine '    _t = _re.sub(r"^[a-z]{2,5}[:_/ -]+", "", str(raw or "").strip().lower())'
  call addLine '    _t = _re.sub(r"[^\w\s-]+", " ", _t)'
  call addLine '    _words = [_w for _w in _t.split() if _w and _w not in _P42_TOPIC_NOISE]'
  call addLine '    _r = " ".join(_words).strip()'
  call addLine '    return _r if len(_r) >= 3 else ""'
  call addLine ''

  call addLine 'def _extract_topics(entry):'
  call addLine '    _found = set()'
  call addLine '    def _add(v):'
  call addLine '        if isinstance(v, str):'
  call addLine '            _n = _normalise_topic(v)'
  call addLine '            if _n: _found.add(_n)'
  call addLine '        elif isinstance(v, list):'
  call addLine '            for _i in v: _add(_i)'
  call addLine '    for _key in ("topics","categories","tags","raw_tags"): _add(entry.get(_key))'
  call addLine '    for _s in (entry.get("senses") or []):'
  call addLine '        if not isinstance(_s, dict): continue'
  call addLine '        for _key in ("topics","categories","tags","raw_tags"): _add(_s.get(_key))'
  call addLine '        for _g in (_s.get("glosses") or []):'
  call addLine '            if isinstance(_g, str) and len(_g) <= 80: _add(_g)'
  call addLine '    return sorted(_found)'
  call addLine ''

  call addLine 'def _first_ipa(entry):'
  call addLine '    for _s in (entry.get("sounds") or []):'
  call addLine '        if not isinstance(_s, dict): continue'
  call addLine '        _ipa = _s.get("ipa") or _s.get("enpr") or ""'
  call addLine '        if _ipa: return str(_ipa).strip("/[] ")'
  call addLine '    return ""'
  call addLine ''

  call addLine 'def _p42_collapse_tsv(path, merge=False):'
  call addLine '    from pathlib import Path'
  call addLine '    _p = Path(str(path))'
  call addLine '    if not _p.exists(): return'
  call addLine '    _rows = {}; _order = []'
  call addLine '    with _p.open("r", encoding="utf-8", errors="replace") as _f:'
  call addLine '        for _line in _f:'
  call addLine '            _line = _line.rstrip("\n")'
  call addLine '            if not _line: continue'
  call addLine '            _k, _v = (_line.split("\t",1) if "\t" in _line else (_line,""))'
  call addLine '            if _k not in _rows:'
  call addLine '                _rows[_k] = set() if merge else _v; _order.append(_k)'
  call addLine '            if merge: _rows[_k].update(_x for _x in _v.split() if _x)'
  call addLine '    _tmp = _p.with_suffix(_p.suffix + ".tmp")'
  call addLine '    with _tmp.open("w", encoding="utf-8") as _f:'
  call addLine '        for _k in _order:'
  call addLine '            _v = " ".join(sorted(_rows[_k])) if merge else _rows[_k]'
  call addLine '            _f.write(_k + "\t" + _v + "\n")'
  call addLine '    _tmp.replace(_p)'
  call addLine ''
  call addLine 'def _p42_wik_collapse_words(output_dir, lang):'
  call addLine '    from pathlib import Path'
  call addLine '    _p42_collapse_tsv(Path(str(output_dir)) / (str(lang) + ".words"), merge=False)'
  call addLine ''
  call addLine 'def _p42_wik_collapse_scope(output_dir, lang):'
  call addLine '    from pathlib import Path'
  call addLine '    _p42_collapse_tsv(Path(str(output_dir)) / (str(lang) + ".scope"), merge=True)'
  call addLine ''
  call addLine 'def _p42_wik_collapse_ipa(output_dir, lang):'
  call addLine '    from pathlib import Path'
  call addLine '    _p42_collapse_tsv(Path(str(output_dir)) / (str(lang) + ".ipa"), merge=False)'
  call addLine ''
  call addLine 'def wik_collapse_words(output_dir, lang): return _p42_wik_collapse_words(output_dir, lang)'
  call addLine 'def wik_collapse_scope(output_dir, lang): return _p42_wik_collapse_scope(output_dir, lang)'
  call addLine 'def wik_collapse_ipa(output_dir, lang): return _p42_wik_collapse_ipa(output_dir, lang)'
  call addLine ''

  return lines

addLine:
  use arg txt
  lines~append(txt)
  return
