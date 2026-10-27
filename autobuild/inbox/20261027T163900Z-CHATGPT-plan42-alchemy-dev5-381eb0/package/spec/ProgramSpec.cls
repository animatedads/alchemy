/* ProgramSpec.cls
   Language-independent program description format.
   A program is described as a tree of nodes in JSON.
   A generator walks the tree and emits idiomatic code
   for any target language.

   "Code written by hand is bad code.
    Code written by AI by hand is worse code."

   The spec is the canonical form.
   The generator is what makes it a program.
   The verifier is what makes it correct.

   CONSTRUCT OPERATORS (the vocabulary):

   DATA
     declare   name, type?, value?
     assign    target, expr
     const     name, value

   EXPRESSIONS
     add sub mul div mod    left, right
     eq neq lt gt lte gte   left, right
     and or not              left, right?
     concat                  args[]
     index                   collection, key
     call                    routine, args[]
     method                  on, name, args[]
     new                     class, args[]
     nil
     literal                 value

   CONTROL
     if         cond, then[], else[]?
     select     expr, cases[], otherwise[]?
     while      cond, body[]
     until      cond, body[]
     for_each   item, in, body[]
     for_range  var, from, to, step?, body[]
     break
     continue
     return     expr?

   I/O
     output     expr
     input      name
     read_file  path
     write_file path, content

   STRUCTURE
     routine    name, params[], body[]
     class      name, parent?, methods[], attributes[]
     method     name, params[], body[], flags[]?
     module     name, requires[], body[]

   ERROR
     try        body[], catches[]
     catch      condition, body[]
     raise      condition, message?

   JSON wire format:
   {
     "spec": "1.0",
     "module": "CorrectionLookup",
     "nodes": [
       {
         "op": "routine",
         "name": "findBestMatch",
         "params": ["lang", "enWord", "ctx"],
         "body": [
           {"op": "declare", "name": "key",
            "value": {"op": "concat", "args": ["lang", {"op":"literal","value":"."},"enWord"]}},
           {"op": "assign",  "target": "candidates",
            "value": {"op": "method", "on": "_entries", "name": "at", "args": ["key"]}},
           {"op": "if",
            "cond": {"op": "eq", "left": "candidates", "right": {"op": "nil"}},
            "then": [{"op": "return", "value": {"op": "nil"}}]},
           {"op": "return", "value": "candidates"}
         ]
       }
     ]
   }
*/

/* ================================================================== */
/* ProgramSpec -- loads and holds the language-independent description */
/* ================================================================== */
::class ProgramSpec public

::method init
  expose _container _spec _nodes
  use arg container
  self~init:super
  _container = container
  _spec      = .nil
  _nodes     = .Array~new

::method loadFile
  expose _container _spec _nodes
  use arg path
  if stream(path,'c','query exists') = '' then return .false
  signal on syntax name ParseErr
  _spec  = .json~fromJsonFile(path)
  _nodes = _spec~at('nodes')
  if _nodes = .nil then _nodes = .Array~new
  return .true
ParseErr:
  signal off syntax
  say '[ProgramSpec] JSON parse failed -- condition:' condition('C') condition('D')
  return .false

::method loadJson
  expose _spec _nodes
  use arg jsonStr
  signal on syntax name ParseErr
  _spec  = .json~new~fromJson(jsonStr)
  _nodes = _spec~at('nodes')
  if _nodes = .nil then _nodes = .Array~new
  return .true
ParseErr:
  signal off syntax
  return .false

::method nodes
  expose _nodes
  return _nodes

::method name
  expose _spec
  if _spec = .nil then return ''
  return _spec~at('module')

::method moduleName
  expose _spec
  if _spec = .nil then return 'unnamed'
  n = _spec~at('module')
  if n = .nil then return 'unnamed'
  return n

::method routineParams
  /* Return the params array of the named routine, or .nil if not found */
  expose _nodes
  use arg routineName
  routineName = translate(strip(routineName))
  do i = 1 to _nodes~items
    node = _nodes~at(i)
    if node = .nil then iterate
    if translate(node~at('op')) \= 'ROUTINE' then iterate
    if translate(node~at('name')) = routineName then
      return node~at('params')
  end
  return .nil


/* ================================================================== */
/* CodeGenerator -- abstract base                                      */
/* Subclasses override emit* methods for each construct operator.     */
/* ================================================================== */
::class CodeGenerator public

::method init
  expose _indent _indentStr _out
  self~init:super
  _indent    = 0
  _indentStr = '  '   /* 2-space default */
  _out       = .Array~new

::method generate
  use arg spec
  self~emitModule(spec)
  return self~output

::method emitEntryPoint
  /* Base stub -- subclasses override for their language.               */
  use arg mainName, params
  return '/* entry point not implemented for this generator */'

::method output
  expose _out
  lf = '0a'x
  _outStr = ''
  do line over _out
    _outStr = _outStr||line||lf
  end
  return _outStr

::method outputLines
  expose _out
  return _out~items

::method emitModule
  use arg spec
  do i = 1 to spec~nodes~items
    node = spec~nodes~at(i)
    /* Label forbidden inside loop -- use helper for safe per-node emit  */
    self~_safeEmitNode(node, i)   /* continue on failure */
  end

::method _safeEmitNode protected
  use arg node, idx
  nodeName = ''
  nodeOp   = ''
  signal on syntax name NodeFail
  if node \= .nil then do
    if node~hasMethod('at') then do
      nodeOp   = '' || node~at('op')
      nodeName = '' || node~at('name')
    end
  end
  self~emitNode(node)
  signal off syntax
  return .true
NodeFail:
  __nfObj = condition('O')
  __nfC   = condition('C')
  signal off syntax
  say '[plan42] emitNode FAILED at node' idx '  op='||nodeOp '  name='||nodeName
  if __nfObj \= .nil then
    say '[plan42]   ' __nfC ':' __nfObj~message
  else
    say '[plan42]   condition:' __nfC
  return .false

::method emitNode
  use arg node
  if node = .nil then return
  op = translate(node~at('op'))
  select
    when op = 'ROUTINE'   then self~emitRoutine(node)
    when op = 'CLASS'     then self~emitClass(node)
    when op = 'METHOD'    then self~emitMethod(node)
    when op = 'DECLARE'   then self~emitDeclare(node)
    when op = 'ASSIGN'    then self~emitAssign(node)
    when op = 'CONST'     then self~emitConst(node)
    when op = 'IF'        then self~emitIf(node)
    when op = 'SELECT'    then self~emitSelect(node)
    when op = 'WHILE'     then self~emitWhile(node)
    when op = 'UNTIL'     then self~emitUntil(node)
    when op = 'FOR_EACH'  then self~emitForEach(node)
    when op = 'FOR_RANGE' then self~emitForRange(node)
    when op = 'RETURN'    then self~emitReturn(node)
    when op = 'OUTPUT'    then self~emitOutput(node)
    when op = 'TRY'       then self~emitTry(node)
    when op = 'RAISE'     then self~emitRaise(node)
    when op = 'BREAK'     then self~emitBreak(node)
    when op = 'CONTINUE'  then self~emitContinue(node)
    otherwise self~emit('/* unknown op: '||node~at('op')||' */')
  end

::method emitBody
  expose _indent
  use arg body
  if body = .nil then return
  _indent = _indent + 1
  do i = 1 to body~items
    self~emitNode(body~at(i))
  end
  _indent = _indent - 1

::method emitExpr
  /* Recursively render an expression node to a string.              */
  use arg expr
  if expr = .nil then return self~nilLiteral
  if expr~isA(.String) then return expr
  if \(expr~isA(.Directory)) then return expr~string
  op = translate(expr~at('op'))
  select
    when op = 'LITERAL'  then return self~quoteLiteral(expr~at('value'))
    when op = 'NIL'      then return self~nilLiteral
    when op = 'CONCAT'   then return self~emitConcat(expr~at('args'))
    when op = 'CALL'     then return self~emitCallExpr(expr)
    when op = 'METHOD'   then return self~emitMethodExpr(expr)
    when op = 'NEW'      then return self~emitNewExpr(expr)
    when op = 'INDEX'    then return self~emitIndexExpr(expr)
    when op = 'ADD'      then return self~binop(expr, self~opAdd)
    when op = 'SUB'      then return self~binop(expr, self~opSub)
    when op = 'MUL'      then return self~binop(expr, self~opMul)
    when op = 'DIV'      then return self~binop(expr, self~opDiv)
    when op = 'EQ'       then return self~binop(expr, self~opEq)
    when op = 'NEQ'      then return self~binop(expr, self~opNeq)
    when op = 'LT'       then return self~binop(expr, self~opLt)
    when op = 'GT'       then return self~binop(expr, self~opGt)
    when op = 'AND'      then return self~emitAnd(expr)
    when op = 'OR'       then return self~emitOr(expr)
    when op = 'NOT'      then return self~emitNot(expr)
    otherwise return '/* expr? '||op||' */'
  end

::method binop private
  use arg expr, opStr
  return '('||self~emitExpr(expr~at('left'))||' '||opStr||' '||self~emitExpr(expr~at('right'))||')'

::method emit protected
  expose _out _indent _indentStr
  use arg line
  if \(_out~isA(.Array)) then say '[plan42-gen] emit: _out NOT Array -- is' _out
  _out~append(copies(_indentStr, _indent)||line)

/* Language-specific tokens -- subclasses override */
::method opAdd;  return '+'
::method opSub;  return '-'
::method opMul;  return '*'
::method opDiv;  return '/'
::method opEq;   return '='
::method opNeq;  return '!='
::method nilLiteral; return 'null'
::method quoteLiteral
  use arg v
  if datatype(v,'N') then return v
  return '"'||v||'"'

/* Default implementations raise "not implemented" */
::method emitRoutine;  use arg n; self~emit('/* routine: '||n~at('name')||' -- not implemented in this generator */')
::method emitClass;    use arg n; self~emit('/* class: '||n~at('name')||' -- not implemented */')
::method emitMethod;   use arg n; self~emit('/* method: '||n~at('name')||' -- not implemented */')
::method emitDeclare;  use arg n; self~emit('/* declare: '||n~at('name')||' -- not implemented */')
::method emitAssign;   use arg n; self~emit('/* assign -- not implemented */')
::method emitConst;    use arg n; self~emit('/* const -- not implemented */')
::method emitIf;       use arg n; self~emit('/* if -- not implemented */')
::method emitSelect;   use arg n; self~emit('/* select -- not implemented */')
::method emitWhile;    use arg n; self~emit('/* while -- not implemented */')
::method emitUntil;    use arg n; self~emit('/* until -- not implemented */')
::method emitForEach;  use arg n; self~emit('/* for_each -- not implemented */')
::method emitForRange; use arg n; self~emit('/* for_range -- not implemented */')
::method emitReturn;   use arg n; self~emit('/* return -- not implemented */')
::method emitOutput;   use arg n; self~emit('/* output -- not implemented */')
::method emitTry;      use arg n; self~emit('/* try -- not implemented */')
::method emitRaise;    use arg n; self~emit('/* raise -- not implemented */')
::method emitBreak;    use arg n; self~emit('/* break -- not implemented */')
::method emitContinue; use arg n; self~emit('/* continue -- not implemented */')
::method emitConcat;   use arg args; return '/* concat */'
::method emitCallExpr; use arg n; return n~at('routine')||'()'
::method emitMethodExpr; use arg n; return n~at('on')||'.something()'
::method emitNewExpr;  use arg n; return 'new '||n~at('class')
::method emitIndexExpr; use arg n; return n~at('collection')||'['||n~at('key')||']'
::method emitAnd;      use arg n; return '('||self~emitExpr(n~at('left'))||' && '||self~emitExpr(n~at('right'))||')'
::method emitOr;       use arg n; return '('||self~emitExpr(n~at('left'))||' || '||self~emitExpr(n~at('right'))||')'
::method emitNot;      use arg n; return '!'||self~emitExpr(n~at('expr'))


/* ================================================================== */
/* OORexxGenerator                                                    */
/* ================================================================== */
::class OORexxGenerator subclass CodeGenerator public

::method opEq;   return '='
::method opNeq;  return '\='
::method opLt;   return '<'
::method opGt;   return '>'
::method nilLiteral; return '.nil'

::method emitRoutine
  use arg node
  params = self~joinParams(node~at('params'), ', ')
  self~emit('::routine '||node~at('name')||' public')
  self~emit('  use arg '||params)
  self~emitBody(node~at('body'))

::method emitMethod
  use arg node
  flags  = ''
  fArr   = node~at('flags')
  if fArr \= .nil then do
    do f over fArr; flags = flags ' '||translate(f); end
  end
  params = self~joinParams(node~at('params'), ', ')
  self~emit('::method '||node~at('name')||flags)
  self~emit('  expose '||node~at('exposes'))   /* expose FIRST -- OORexx rule */
  self~emit('  use arg '||params)
  self~emitBody(node~at('body'))

::method emitDeclare
  use arg node
  if node~at('value') \= .nil then
    self~emit(node~at('name')||' = '||self~emitExpr(node~at('value')))
  else
    self~emit(node~at('name')||' = .nil')

::method emitAssign
  use arg node
  self~emit(node~at('target')||' = '||self~emitExpr(node~at('expr')))

::method emitIf
  use arg node
  self~emit('if '||self~emitExpr(node~at('cond'))||' then do')
  self~emitBody(node~at('then'))
  els = node~at('else')
  if els \= .nil & els~items > 0 then do
    self~emit('end')
    self~emit('else do')
    self~emitBody(els)
  end
  self~emit('end')

::method emitWhile
  use arg node
  self~emit('do while '||self~emitExpr(node~at('cond')))
  self~emitBody(node~at('body'))
  self~emit('end')

::method emitForEach
  use arg node
  self~emit('do '||node~at('item')||' over '||node~at('in'))
  self~emitBody(node~at('body'))
  self~emit('end')

::method emitForRange
  use arg node
  step = node~at('step')
  if step = .nil then step = 1
  self~emit('do '||node~at('var')||' = '||node~at('from')||' to '||node~at('to')||' by '||step)
  self~emitBody(node~at('body'))
  self~emit('end')

::method emitReturn
  use arg node
  if node~at('expr') = .nil then self~emit('return')
  else self~emit('return '||self~emitExpr(node~at('expr')))

::method emitOutput
  use arg node
  self~emit('say '||self~emitExpr(node~at('expr')))

::method emitTry
  use arg node
  catches = node~at('catches')
  if catches = .nil | catches~items = 0 then do
    self~emitBody(node~at('body')); return
  end
  do i = 1 to catches~items
    c = catches~at(i)
    self~emit('signal on '||c~at('condition')||' name Catch'||i)
  end
  self~emitBody(node~at('body'))
  do i = 1 to catches~items
    c = catches~at(i)
    self~emit('Catch'||i||':')
    self~emit('  signal off '||c~at('condition'))
    self~emitBody(c~at('body'))
  end

::method emitRaise
  use arg node
  self~emit('signal '||node~at('condition'))

::method emitBreak;    self~emit('leave')
::method emitContinue; self~emit('iterate')

::method emitConcat
  use arg args
  parts = ''
  do i = 1 to args~items
    if i > 1 then parts = parts||'||'
    parts = parts||self~emitExpr(args~at(i))
  end
  return parts

::method emitMethodExpr
  use arg n
  args = self~joinArgs(n~at('args'))
  return n~at('on')||'~'||n~at('name')||'('||args||')'

::method emitNewExpr
  use arg n
  args = self~joinArgs(n~at('args'))
  return '.'||n~at('class')||'~new('||args||')'

::method emitAnd
  use arg n
  /* OORexx & does not short-circuit -- emit nested if instead        */
  return '/* use nested if for: '||self~emitExpr(n~at('left'))||' AND '||self~emitExpr(n~at('right'))||' */'

::method emitNot
  use arg n
  return '\'||self~emitExpr(n~at('expr'))

::method joinParams private
  use arg params, sep
  if params = .nil then return ''
  out = ''
  do i = 1 to params~items
    if i > 1 then out = out||sep
    out = out||params~at(i)
  end
  return out

::method joinArgs private
  use arg args
  if args = .nil then return ''
  return self~joinParams(args, ', ')


/* ================================================================== */
/* PythonGenerator                                                    */
/* ================================================================== */
::class PythonGenerator subclass CodeGenerator public

::method init
  expose _indent _indentStr _out
  self~init:super
  _indentStr = '    '    /* Python uses 4 spaces -- override base 2-space */

::method nilLiteral; return 'None'
::method opAnd;      return 'and'
::method opOr;       return 'or'
::method opNot;      return 'not '
::method opNeq;      return '!='

::method emitRoutine
  use arg node
  params = self~joinParams(node~at('params'))
  self~emit('def '||node~at('name')||'('||params||'):')
  self~emitBody(node~at('body'))
  self~emit('')

::method emitEntryPoint
  /* Generate argparse CLI entry point for the named main routine.     */
  /* Called by run_plan42.rex after generate().                        */
  use arg mainName, params
  lf = '0a'x
  out  = lf
  out  = out||'if __name__ == "__main__":' ||lf
  out  = out||'    import argparse as _ap_mod'||lf
  out  = out||'    _p = _ap_mod.ArgumentParser()'||lf
  if params \= .nil then do
    do i = 1 to params~items
      pname = params~at(i)
      out = out||'    _p.add_argument("--'||pname||'", default="")'||lf
    end
  end
  out = out||'    _a = _p.parse_args()'||lf
  /* Build call */
  callArgs = ''
  if params \= .nil then do
    do i = 1 to params~items
      if i > 1 then callArgs = callArgs||', '
      callArgs = callArgs||'_a.'||params~at(i)
    end
  end
  out = out||'    '||mainName||'('||callArgs||')'||lf
  return out

::method emitDeclare
  use arg node
  if node~at('value') \= .nil then
    self~emit(node~at('name')||' = '||self~emitExpr(node~at('value')))
  else
    self~emit(node~at('name')||' = None')

::method emitAssign
  use arg node
  self~emit(node~at('target')||' = '||self~emitExpr(node~at('expr')))

::method emitIf
  use arg node
  self~emit('if '||self~emitExpr(node~at('cond'))||':')
  self~emitBody(node~at('then'))
  els = node~at('else')
  if els \= .nil & els~items > 0 then do
    self~emit('else:')
    self~emitBody(els)
  end

::method emitWhile
  use arg node
  self~emit('while '||self~emitExpr(node~at('cond'))||':')
  self~emitBody(node~at('body'))

::method emitForEach
  use arg node
  self~emit('for '||node~at('item')||' in '||node~at('in')||':')
  self~emitBody(node~at('body'))

::method emitForRange
  use arg node
  step = node~at('step')
  if step = .nil then
    self~emit('for '||node~at('var')||' in range('||node~at('from')||', '||node~at('to')||'):')
  else
    self~emit('for '||node~at('var')||' in range('||node~at('from')||', '||node~at('to')||', '||step||'):')
  self~emitBody(node~at('body'))

::method emitReturn
  use arg node
  if node~at('expr') = .nil then self~emit('return')
  else self~emit('return '||self~emitExpr(node~at('expr')))

::method emitOutput
  use arg node
  self~emit('print('||self~emitExpr(node~at('expr'))||')')

::method emitTry
  use arg node
  self~emit('try:')
  self~emitBody(node~at('body'))
  catches = node~at('catches')
  if catches \= .nil then do
    do i = 1 to catches~items
      c = catches~at(i)
      self~emit('except '||c~at('condition')||':')
      self~emitBody(c~at('body'))
    end
  end

::method emitRaise
  use arg node
  self~emit('raise '||node~at('condition')||'("'||node~at('message')||'")')

::method emitBreak;    self~emit('break')
::method emitContinue; self~emit('continue')

::method emitMethodExpr
  use arg n
  args = self~joinParams(n~at('args'))
  return n~at('on')||'.'||n~at('name')||'('||args||')'

::method emitNewExpr
  use arg n
  args = self~joinParams(n~at('args'))
  return n~at('class')||'('||args||')'

::method emitConcat
  use arg args
  parts = ''
  do i = 1 to args~items
    if i > 1 then parts = parts||' + '
    parts = parts||'str('||self~emitExpr(args~at(i))||')'
  end
  return parts

::method emitAnd
  use arg n
  return '('||self~emitExpr(n~at('left'))||' and '||self~emitExpr(n~at('right'))||')'

::method emitOr
  use arg n
  return '('||self~emitExpr(n~at('left'))||' or '||self~emitExpr(n~at('right'))||')'

::method emitNot
  use arg n
  return '(not '||self~emitExpr(n~at('expr'))||')'

::method joinParams private
  use arg params
  if params = .nil then return ''
  out = ''
  do i = 1 to params~items
    if i > 1 then out = out||', '
    out = out||params~at(i)
  end
  return out


/* ================================================================== */
/* BashGenerator                                                      */
/* ================================================================== */
::class BashGenerator subclass CodeGenerator public

::method nilLiteral; return '""'
::method opEq;  return '='
::method opNeq; return '!='

::method emitRoutine
  use arg node
  self~emit(node~at('name')||'() {')
  /* Bash: positional params $1 $2 etc */
  params = node~at('params')
  if params \= .nil then do
    do i = 1 to params~items
      self~emit('  local '||params~at(i)||'="$'||i||'"')
    end
  end
  self~emitBody(node~at('body'))
  self~emit('}')
  self~emit('')

::method emitDeclare
  use arg node
  if node~at('value') \= .nil then
    self~emit('local '||node~at('name')||'='||self~emitExpr(node~at('value')))
  else
    self~emit('local '||node~at('name')||'=""')

::method emitAssign
  use arg node
  self~emit(node~at('target')||'='||self~emitExpr(node~at('expr')))

::method emitIf
  use arg node
  self~emit('if [[ '||self~emitExpr(node~at('cond'))||' ]]; then')
  self~emitBody(node~at('then'))
  els = node~at('else')
  if els \= .nil & els~items > 0 then do
    self~emit('else')
    self~emitBody(els)
  end
  self~emit('fi')

::method emitWhile
  use arg node
  self~emit('while [[ '||self~emitExpr(node~at('cond'))||' ]]; do')
  self~emitBody(node~at('body'))
  self~emit('done')

::method emitForEach
  use arg node
  self~emit('for '||node~at('item')||' in "${!'||node~at('in')||'[@]}"; do')
  self~emitBody(node~at('body'))
  self~emit('done')

::method emitReturn
  use arg node
  if node~at('expr') = .nil then self~emit('return 0')
  else self~emit('echo '||self~emitExpr(node~at('expr'))||'; return 0')

::method emitOutput
  use arg node
  self~emit('echo '||self~emitExpr(node~at('expr')))

::method emitBreak;    self~emit('break')
::method emitContinue; self~emit('continue')

::method emitEntryPoint
  use arg mainName, params
  lf = '0a'x
  out = lf||'# ?? CLI entry point ??????????????????????????????????????????'||lf
  if params \= .nil then do
    do i = 1 to params~items
      pname = params~at(i)
      out = out||pname||'=""'||lf
    end
  end
  out = out||'while [[ $# -gt 0 ]]; do'||lf
  out = out||'  case "$1" in'||lf
  if params \= .nil then do
    do i = 1 to params~items
      pname = params~at(i)
      out = out||'    --'||pname||') '||pname||'="$2"; shift 2 ;;'||lf
    end
  end
  out = out||'    *) shift ;;'||lf
  out = out||'  esac'||lf
  out = out||'done'||lf
  callArgs = ''
  if params \= .nil then do
    do i = 1 to params~items
      if i > 1 then callArgs = callArgs||' '
      callArgs = callArgs||'"$'||params~at(i)||'"'
    end
  end
  out = out||mainName||' '||callArgs||lf
  return out

::method emitConcat
  use arg args
  parts = ''
  do i = 1 to args~items
    parts = parts||self~emitExpr(args~at(i))
  end
  return '"'||parts||'"'

::method emitAnd
  use arg n
  return self~emitExpr(n~at('left'))||' && '||self~emitExpr(n~at('right'))

::method emitOr
  use arg n
  return self~emitExpr(n~at('left'))||' || '||self~emitExpr(n~at('right'))

::method emitNot
  use arg n
  return '! '||self~emitExpr(n~at('expr'))


/* ================================================================== */
/* GeneratorFactory -- returns the right generator for a target lang   */
/* ================================================================== */
::requires 'json.cls'
::requires 'PyNodes.cls'
::requires 'RustNodes.cls'


/* ================================================================== */
/* IMPLEMENTATION EXTENSION                                           */
/*                                                                    */
/* impl      -- define a named capability with per-language impls      */
/* impl_use  -- reference a defined capability by name                 */
/*                                                                    */
/* Implementation types:                                              */
/*   inline       -- emit verbatim code for this language              */
/*   library      -- declare a require/import + emit a call            */
/*   external_call -- delegate to ExternalCall transport               */
/*   spec         -- recurse: the impl IS another ProgramSpec subtree  */
/*                                                                    */
/* Example spec node:                                                 */
/* {                                                                  */
/*   "op": "impl",                                                    */
/*   "name": "readJsonFile",                                          */
/*   "abstract": "Read and parse a JSON file",                        */
/*   "params": ["path"],                                              */
/*   "returns": "object",                                             */
/*   "implementations": {                                             */
/*     "oorexx": {                                                     */
/*       "type": "library",                                           */
/*       "requires": ["json.cls"],                                    */
/*       "body": [                                                    */
/*         {"op":"declare","name":"f","value":                        */
/*           {"op":"new","class":"Stream","args":["path"]}},          */
/*         {"op":"declare","name":"raw","value":                      */
/*           {"op":"method","on":"f","name":"charin",                 */
/*            "args":[{"op":"literal","value":1},                     */
/*                    {"op":"method","on":"f","name":"chars"}]}},      */
/*         {"op":"return","value":                                    */
/*           {"op":"method","on":".json~new","name":"fromJson",       */
/*            "args":["raw"]}}                                        */
/*       ]                                                            */
/*     },                                                             */
/*     "python": {                                                    */
/*       "type": "library",                                           */
/*       "requires": ["import json"],                                 */
/*       "inline": "with open(path,'r') as f: return json.load(f)"   */
/*     },                                                             */
/*     "bash": {                                                      */
/*       "type": "command",                                           */
/*       "requires": ["jq"],                                          */
/*       "inline": "jq . \"$path\""                                   */
/*     },                                                             */
/*     "oorexx_fallback": {                                           */
/*       "type": "external_call",                                     */
/*       "transport": "transport.isolated",                           */
/*       "command": "python3",                                        */
/*       "args_template": ["read_json.py", "{path}"]                 */
/*     }                                                              */
/*   }                                                                */
/* }                                                                  */
/* ================================================================== */

/* ================================================================== */
/* ImplRegistry -- holds all named impl definitions for a spec         */
/* ================================================================== */
::class ImplRegistry public

::method init
  expose _impls
  self~init:super
  _impls = .Directory~new

::method register
  expose _impls
  use arg node
  name = node~at('name')
  if name \= .nil then _impls~put(node, translate(name))

::method resolve
  expose _impls
  use arg name
  return _impls~at(translate(name))

::method items
  expose _impls
  return _impls~items


/* ================================================================== */
/* Extension to CodeGenerator -- impl/impl_use dispatch               */
/* ================================================================== */
/* Add these methods by reopening CodeGenerator via a mixin approach. */
/* In practice these are added directly to CodeGenerator above,      */
/* shown here separately for clarity.                                 */
/* ================================================================== */

::class ImplAwareGenerator subclass CodeGenerator public

::method init
  expose _registry _language _requires
  self~init:super
  _registry = .ImplRegistry~new
  _language = 'generic'
  _requires = .Array~new   /* accumulated require/import statements */

::method "language="
  expose _language
  use arg lang
  _language = translate(lang)

::method generate
  expose _registry
  use arg spec
  /* First pass: register all impl nodes                               */
  do i = 1 to spec~nodes~items
    node = spec~nodes~at(i)
    if node = .nil then iterate
    if translate(node~at('op')) = 'IMPL' then do
      ok = self~_safeRegister(node, i)
      if \ok then say '[plan42] WARNING: impl registration failed at node' i
    end
  end
  /* Second pass: emit                                                */
  self~emitModule(spec)
  /* Prepend accumulated requires via self~output (CodeGenerator scope) */
  return self~outputWithRequires

::method _safeRegister protected
  expose _registry
  use arg node, idx
  signal on syntax name RegFail
  _registry~register(node)
  signal off syntax
  return .true
RegFail:
  signal off syntax
  say '[plan42] register FAILED at node' idx '  condition:' condition('C') '  description:' condition('D')
  return .false

::method outputWithRequires
  expose _requires
  lf = '0a'x
  preamble = ''
  do r over _requires
    preamble = preamble||r||lf
  end
  if _requires~items > 0 then preamble = preamble||lf
  /* _out lives in CodeGenerator scope -- access it via self~output     */
  return preamble||self~output

::method emitNode
  use arg node
  if node = .nil then return
  op = translate(node~at('op'))
  if op = 'IMPL'     then return   /* declarations only, not emitted inline */
  if op = 'IMPL_USE' then do; self~emitImplUse(node); return; end
  self~emitNode:super(node)

::method _requiresPreamble protected
  /* Return formatted requires/imports preamble for subclass use.     */
  expose _requires
  lf = '0a'x
  preamble = ''
  do r over _requires
    preamble = preamble||r||lf
  end
  if _requires~items > 0 then preamble = preamble||lf
  return preamble

::method _resolveImplNode protected
  /* Access _registry from ImplAwareGenerator scope for subclasses    */
  expose _registry
  use arg name
  return _registry~resolve(name)

::method _registryItems protected
  expose _registry
  return _registry~items

::method loadPreferred
  /* Load preferred.capabilities.json and register all caps in _registry
     so the existing resolveImpl / emitImplBody chain handles them.    */
  expose _registry
  use arg path
  if stream(path,'c','query exists') = '' then return .false
  signal on syntax name LoadPrefFail
  prefData = .json~fromJsonFile(path)
  signal off syntax
  if prefData = .nil then return .false
  caps = prefData~at('capabilities')
  if caps = .nil then return .false
  registered = 0
  do i = 1 to caps~items
    cap = caps~at(i)
    if cap = .nil then iterate
    /* Uppercase the implementation language keys so resolveImpl finds them */
    rawImpls = cap~at('implementations')
    if rawImpls \= .nil then do
      newImpls = .Directory~new
      do k over rawImpls~allIndexes
        newImpls~put(rawImpls~at(k), translate(k))
      end
      cap~put(newImpls, 'implementations')
    end
    _registry~register(cap)
    registered = registered + 1
  end
  say '[plan42] preferred: registered' registered 'capabilities'
  return .true
LoadPrefFail:
  signal off syntax
  say '[plan42] preferred: failed to load' path
  return .false

::method _resolveInline protected
  /* Resolve an impl_use to its inline code string.
     Returns the code string (with result assignment if resVar given),
     or .nil if not found. Caller adds the indent prefix before emit.  */
  expose _registry _language _requires
  use arg implName, callArgs, resVar

  implNode = _registry~resolve(implName)
  if implNode = .nil then return .nil

  impl = self~resolveImpl(implNode)
  if impl = .nil then return .nil

  /* Accumulate requires/imports */
  reqs = impl~at('requires')
  if reqs \= .nil then do
    do r over reqs
      r = strip(r)
      if r = '' then iterate
      fmtR = self~formatRequire(r)
      found = .false
      do existing over _requires
        if existing = fmtR then do; found = .true; leave; end
      end
      if \found then _requires~append(fmtR)
    end
  end

  /* Get inline code and substitute args */
  implType = translate(impl~at('type'))
  if implType = 'INLINE' | implType = 'LIBRARY' then do
    code = impl~at('inline')
    if code \= .nil then do
      code = self~substituteArgs(code, implNode~at('params'), callArgs)
      if resVar \= .nil & resVar \= 'The NIL object' then
        return resVar||' = '||code
      else
        return code
    end
  end
  return .nil

::method emitImplUse
  /* Reference to a named impl -- resolve and emit for our language.   */
  expose _registry _language
  use arg node
  name   = node~at('name')
  args   = node~at('args')
  resVar = node~at('result')

  inlined = self~_resolveInline(name, args, resVar)
  if inlined \= .nil then do
    self~emit(inlined)
    return
  end

  /* Stub -- compilable but clearly not final */
  if resVar \= .nil & resVar \= 'The NIL object' then
    self~emit(resVar||' = None  # impl: '||name)
  else
    self~emit('pass  # impl: '||name)



::method resolveImpl protected
  expose _language
  use arg implNode
  impls = implNode~at('implementations')
  if impls = .nil then return .nil
  /* Exact language match */
  impl = impls~at(_language)
  if impl \= .nil then return impl
  /* JSON keys are lowercase -- try lowercase language name */
  lcLang = translate(_language,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')
  impl = impls~at(lcLang)
  if impl \= .nil then return impl
  /* Fallback: {language}_fallback */
  impl = impls~at(_language||'_fallback')
  if impl \= .nil then return impl
  impl = impls~at(lcLang||'_fallback')
  if impl \= .nil then return impl
  /* Fallback: generic */
  impl = impls~at('generic')
  return impl

::method emitImplBody
  expose _requires
  use arg name, impl, callArgs, paramNames
  implType = translate(impl~at('type'))

  /* Accumulate requires/imports                                      */
  reqs = impl~at('requires')
  if reqs \= .nil then do
    do r over reqs
      if wordpos(r, _requires~makeString('L',' ')) = 0 then
        _requires~append(self~formatRequire(r))
    end
  end

  select
    when implType = 'INLINE' then do
      /* Verbatim code block -- substitute param names for call args   */
      code = impl~at('inline')
      if code \= .nil then do
        code = self~substituteArgs(code, paramNames, callArgs)
        self~emit(code)
      end
      else if impl~at('body') \= .nil then do
        self~emitBody(impl~at('body'))
      end
    end

    when implType = 'LIBRARY' then do
      /* Library call -- may have body (spec nodes) or inline snippet  */
      if impl~at('body') \= .nil then do
        self~emitBody(impl~at('body'))
      end
      else if impl~at('inline') \= .nil then do
        code = self~substituteArgs(impl~at('inline'), paramNames, callArgs)
        self~emit(code)
      end
    end

    when implType = 'EXTERNAL_CALL' then do
      /* Delegate to ExternalCall at runtime                          */
      transport = impl~at('transport')
      command   = impl~at('command')
      argsT     = impl~at('args_template')
      self~emitExternalCall(transport, command, argsT, paramNames, callArgs)
    end

    when implType = 'SPEC' then do
      /* The implementation is itself a ProgramSpec -- recurse         */
      subSpec = .ProgramSpec~new(.nil)
      if subSpec~loadJson(.json~new~toJson(impl~at('spec'))) then do
        do i = 1 to subSpec~nodes~items
          self~emitNode(subSpec~nodes~at(i))
        end
      end
    end

    otherwise
      self~emit('/* unknown impl type: '||implType||' */')
  end

::method emitStub
  /* Emit a compilable but clearly broken stub so code won't silently fail */
  use arg implNode
  name   = implNode~at('name')
  params = implNode~at('params')
  if params = .nil then params = .Array~new
  self~emit('/* TODO: implement '||name||' for '||self~language()||' */')
  self~emit(self~raiseNotImplemented(name))

::method substituteArgs protected
  use arg template, paramNames, callArgs
  if paramNames = .nil | callArgs = .nil then return template
  out = template
  do i = 1 to paramNames~items
    if i > callArgs~items then leave
    pname = paramNames~at(i)
    aval  = self~emitExpr(callArgs~at(i))
    out   = changestr('{'||pname||'}', out, aval)
  end
  return out

::method language
  expose _language
  return _language

/* Language-specific overrides for requires and stubs */
::method formatRequire;       use arg r; return '/* require: '||r||' */'
::method raiseNotImplemented; use arg n; return '/* NOT IMPLEMENTED: '||n||' */'
::method emitExternalCall
  use arg transport, command, argsT, paramNames, callArgs
  self~emit('/* external_call: '||command||' via '||transport||' */')


/* ================================================================== */
/* OORexxImplGenerator -- OORexx with impl support                     */
/* ================================================================== */
::class OORexxImplGenerator subclass ImplAwareGenerator public

::method init
  self~init:super
  self~language = 'OOREXX'

::method formatRequire
  use arg r
  return "::requires '"||r||"'"

::method raiseNotImplemented
  use arg name
  return "signal NOTIMPLEMENTED   /* "||name||" */"

::method emitExternalCall
  use arg transport, command, argsT, paramNames, callArgs
  /* Emit an actual ExternalCall block for OORexx                     */
  self~emit('_xcall = .ExternalCall~new(_container)')
  self~emit("_xcall~command = '"||command||"'")
  self~emit('_xcall~args    = .Array~new')
  if argsT \= .nil then do
    do i = 1 to argsT~items
      arg = argsT~at(i)
      arg = self~substituteArgs(arg, paramNames, callArgs)
      self~emit("_xcall~args~append('"||arg||"')")
    end
  end
  if transport \= .nil then
    self~emit("_xcall~transport = _container~get('"||transport||"')")
  self~emit('_xcall~run')
  self~emit('_xcallResult = _xcall~result')

::method emitEntryPoint
  /* OORexx entry point: parse --key value pairs from arg string       */
  use arg mainName, params
  lf = '0a'x
  out = lf||'/* ?? CLI entry point ???????????????????????????????????????? */'||lf
  out = out||'parse arg _allArgs'||lf
  out = out||'_argDir = .Directory~new'||lf
  out = out||'do while strip(_allArgs) \= ""'||lf
  out = out||'  parse var _allArgs _k _v _allArgs'||lf
  out = out||"  if left(_k,2) = '--' then do"||lf
  out = out||"    _k = substr(_k,3)"||lf
  out = out||'    _argDir~put(_v, translate(_k))'||lf
  out = out||'  end'||lf
  out = out||'end'||lf
  callArgs = ''
  if params \= .nil then do
    do i = 1 to params~items
      pname = params~at(i)
      if i > 1 then callArgs = callArgs||', '
      callArgs = callArgs||"_argDir~at('"||translate(pname)||"')"
    end
  end
  out = out||'call '||mainName||' '||callArgs||lf
  return out


/* ================================================================== */
/* PythonImplGenerator                                                */
/* ================================================================== */
::class PythonImplGenerator subclass ImplAwareGenerator public

::method init
  self~init:super
  self~language = 'PYTHON3'

::method generate
  use arg spec
  /* Register all IMPL nodes first */
  do i = 1 to spec~nodes~items
    node = spec~nodes~at(i)
    if node = .nil then iterate
    if translate(node~at('op')) = 'IMPL' then self~_safeRegister(node, i)
  end
  /* Build OO tree and render */
  builder = .Plan42PythonBuilder~new(self)
  module  = builder~buildModule(spec)
  return module~render('')

::method outputWithRequires
  /* generate() returns complete source directly; runner calls this   */
  /* for compatibility -- we simply forward to generate output        */
  return self~output

::method emitEntryPoint
  use arg mainName, params
  lf = '0a'x
  out = lf||'if __name__ == "__main__":'||lf
  out = out||'    import argparse as _p42_argparse'||lf
  out = out||'    _p42_parser = _p42_argparse.ArgumentParser()'||lf
  if params \= .nil then do
    do i = 1 to params~items
      pname = params~at(i)
      out = out||'    _p42_parser.add_argument("--'||pname||'", default="")'||lf
    end
  end
  out = out||'    _p42_args = _p42_parser.parse_args()'||lf
  callArgs = ''
  if params \= .nil then do
    do i = 1 to params~items
      if i > 1 then callArgs = callArgs||', '
      callArgs = callArgs||'_p42_args.'||params~at(i)
    end
  end
  out = out||'    '||mainName||'('||callArgs||')'||lf
  return out


/* ================================================================== */
/* RustImplGenerator                                                   */
/* ================================================================== */
::class RustImplGenerator subclass ImplAwareGenerator public

::method init
  self~init:super
  self~language = 'RUST'

::method generate
  use arg spec
  /* Register all IMPL nodes */
  do i = 1 to spec~nodes~items
    node = spec~nodes~at(i)
    if node = .nil then iterate
    if translate(node~at('op')) = 'IMPL' then self~_safeRegister(node, i)
  end
  builder = .Plan42RustBuilder~new(self)
  module  = builder~buildModule(spec)
  return module~render('')

::method outputWithRequires
  return self~output

::method emitEntryPoint
  use arg mainName, params
  lf = '0a'x
  out  = lf||'fn main() {'||lf
  out  = out||'    let args: Vec<String> = std::env::args().collect();'||lf
  do i = 1 to params~items
    pname = params~at(i)
    out  = out||'    let mut _p42_'||pname||' = String::new();'||lf
  end
  out  = out||'    let mut _p42_i = 1usize;'||lf
  out  = out||'    while _p42_i + 1 < args.len() {'||lf
  out  = out||'        match args[_p42_i].as_str() {'||lf
  do i = 1 to params~items
    pname = params~at(i)
    out  = out||'            "--'||pname||'" => { _p42_'||pname||,
           ' = args[_p42_i+1].clone(); _p42_i += 2; }'||lf
  end
  out  = out||'            _ => { _p42_i += 1; }'||lf
  out  = out||'        }'||lf
  out  = out||'    }'||lf
  /* Type-aware conversions before the call                           */
  out  = out||'    let _tl: Vec<String> = if _p42_target_langs.is_empty() {'||lf
  out  = out||'        SUPPORTED_LANGS.iter().map(|s| s.to_string()).collect()'||lf
  out  = out||'    } else {'||lf
  out  = out||'        _p42_target_langs.split(",").map(str::to_string).collect()'||lf
  out  = out||'    };'||lf
  out  = out||'    let _pi: i64 = _p42_progress_interval.parse().unwrap_or(0);'||lf
  callArgs = ''
  do i = 1 to params~items
    if i > 1 then callArgs = callArgs||', '
    pname = params~at(i)
    select
      when pname = 'target_langs'      then callArgs = callArgs||'&_tl'
      when pname = 'progress_interval' then callArgs = callArgs||'_pi'
      otherwise                        callArgs = callArgs||'&_p42_'||pname
    end
  end
  out  = out||'    p42_main('||callArgs||');'||lf
  out  = out||'}'||lf
  return out

::method formatRequire
  use arg r
  return r

::class BashImplGenerator subclass ImplAwareGenerator public

::method init
  self~init:super
  self~language = 'BASH'

::method formatRequire
  use arg r
  return 'command -v '||r||' >/dev/null || { echo "requires: '||r||'" >&2; exit 1; }'

::method raiseNotImplemented
  use arg name
  return 'echo "NOT IMPLEMENTED: '||name||'" >&2; return 1'

::method emitExternalCall
  use arg transport, command, argsT, paramNames, callArgs
  argsStr = command
  if argsT \= .nil then do
    do i = 1 to argsT~items
      arg = self~substituteArgs(argsT~at(i), paramNames, callArgs)
      argsStr = argsStr||' "'||arg||'"'
    end
  end
  self~emit('_xcall_stdout=$('||argsStr||' 2>/tmp/xcall_err.txt)')
  self~emit('_xcall_rc=$?')


/* ================================================================== */
/* PreferredModule integration into ImplAwareGenerator                */
/* When impl_use references "preferred.*", resolve via PreferredModule */
/* ================================================================== */
::class PreferredAwareGenerator subclass ImplAwareGenerator public

::method init
  expose _preferred _probeMode
  self~init:super
  _preferred = .nil
  _probeMode = 'RESILIENT'

::method "preferred="
  expose _preferred
  use arg p
  _preferred = p

::method "probeMode="
  expose _probeMode
  use arg m
  _probeMode = m

::method emitImplUse
  expose _preferred _probeMode
  use arg node
  name = node~at('name')
  /* If preferred module is loaded and name starts with "preferred."   */
  if _preferred \= .nil then do
    if left(translate(name),10) = 'PREFERRED.' then do
      capName = substr(name, 11)   /* strip "preferred." prefix */
      impl = _preferred~resolve(capName, self~language, _probeMode)
      if impl \= .nil then do
        callArgs = node~at('args')
        /* Resolve params from the capability definition               */
        cap = _preferred~resolveCap(capName)
        params = .nil
        if cap \= .nil then params = cap~at('params')
        self~emitImplBody(capName, impl, callArgs, params)
        return
      end
      /* No preferred impl found -- emit loud stub                      */
      self~emit('/* PREFERRED: no implementation for '||capName||' in '||self~language()||' -- STUB */')
      return
    end
  end
  self~emitImplUse:super(node)


/* Updated GeneratorFactory */
::class GeneratorFactory public

::method forLanguage class
  use arg lang, container
  gen = .nil
  _lang = translate(strip(lang))
  select
    when _lang = 'OOREXX' | _lang = 'REXX'             then gen = .OORexxImplGenerator~new
    when _lang = 'PYTHON' | _lang = 'PYTHON3'           then gen = .PythonImplGenerator~new
    when _lang = 'RUST'                                  then gen = .RustImplGenerator~new
    when _lang = 'BASH'   | _lang = 'SH'               then gen = .BashImplGenerator~new
    otherwise gen = .ImplAwareGenerator~new
  end
  /* Wire preferred module if container available */
  if container \= .nil then do
    pref = container~get('preferred')
    if pref \= .nil then gen~preferred = pref
  end
  return gen

::requires 'preferred/PreferredModule.cls'
