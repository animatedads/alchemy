/* BifContracts.cls - the contracts of ooRexx built-in functions, read from two C++ codebases:
 * the interpreter (BuiltinFunctions.cpp, and the methods each BIF hands its arguments to) and the
 * rx2cpp native pack (rxbif.cpp). SLAM reads both with its C++ reader; this file holds the vocabulary
 * of each codebase, stated here rather than hidden:
 *   interpreter BIF layer   X_Min / X_Max / X_<arg> = <position>; required_<kind>(X, arg),
 *                           optional_<kind>(X, arg) with kind string, integer, big_integer, pad
 *   interpreter methods     a check on a parameter: a call named ...Argument or optional... / required...,
 *                           whose name says the kind (Length, Position, NonNegative, Positive, Pad, Option), followed through calls that pass parameters on
 *   native pack             kSpecs rows {"NAME", min, max}; in invoke, the branch if (name == "X" ...)
 *                           reads argument k with get(k) string, ct(k[, m]) count >= m (m = 0),
 *                           pad(a, k, ..) one byte, str(a, k, ..) string, caseMode(get(k), ..) option
 * Kinds: STRING, INTEGER (any whole number), LENGTH (>= 0), POSITION (>= 1), COUNT:m (>= m), PAD (one
 * character), OPTION (a letter from a list SLAM does not read).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 */
::requires 'SlamCpp.cls'

::class BifContract public
::attribute name
::attribute min
::attribute max
::attribute kinds         /* position -> kind */
::attribute notes         /* how each kind was found */
::method init
  expose name min max kinds notes
  use strict arg name
  min = ''
  max = ''
  kinds = .directory~new
  notes = .array~new
::method kindAt
  expose kinds
  use strict arg p
  if kinds~hasIndex(p) then return kinds[p]
  return ''
::method show
  expose name min max kinds
  out = name || '(' || min || '..' || max || ')'
  do p = 1 to max
    out = out p || ':' || self~kindAt(p)
  end
  return out
/* Will this side accept these arguments?  'ACCEPT', 'REJECT', or '' (cannot say). */
::method predict
  expose min max
  use strict arg args
  if args~items < min then return 'REJECT'
  if args~items > max then return 'REJECT'
  do p = 1 to args~items
    v = args[p]
    ok = self~fits(self~kindAt(p), v)
    if ok == '' then return ''
    if \ok then return 'REJECT'
  end
  return 'ACCEPT'
::method fits
  use strict arg kind, v
  if kind == '' | kind == 'STRING' then return .true
  if kind == 'PAD' then return v~length == 1
  if kind == 'OPTION' then return ''
  if \datatype(v, 'W') then return .false
  select
    when kind == 'INTEGER' | kind == 'BIG_INTEGER' then return .true
    when kind == 'LENGTH' then return v >= 0
    when kind == 'POSITION' then return v >= 1
    when kind~left(6) == 'COUNT:' then return v >= kind~substr(7)
    otherwise return ''
  end

/* ------------------------------------------------------------------------------------------------ */
::class BifInterpreter public
::attribute methods       /* 'Owner::name' -> array of SlamJavaUnit */
::method init
  expose methods
  methods = .directory~new
::method addMethods
  expose methods
  use strict arg file
  text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
  do u over .SlamCppSplitter~new~split(text)
    k = u~owner || '::' || u~selector
    if \methods~hasIndex(k) then methods[k] = .array~new
    methods[k]~append(u)
  end
/* Contracts of every BUILTIN(X) in the file: name -> BifContract. */
::method read
  use strict arg file
  text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
  out = .directory~new
  do u over .SlamCppSplitter~new~split(text)
    if u~owner \== 'BUILTIN' then iterate
    c = self~builtin(u)
    if c \== .nil then out[c~name] = c
  end
  return out
::method builtin
  use strict arg u
  x = u~selector
  t = u~tokens
  c = .BifContract~new(x)
  pos = .directory~new          /* argument name -> position */
  locals = .directory~new       /* local variable -> position */
  n = t~items
  do i = 1 to n - 2
    if t[i]~kind \== 'IDENT' then iterate
    if t[i]~text~left(x~length + 1) \== x || '_' then iterate
    if t[i + 1]~text \== '=' then iterate
    if t[i + 2]~kind \== 'NUMBER' then iterate
    suffix = t[i]~text~substr(x~length + 2)
    if suffix == 'Min' then c~min = t[i + 2]~text
    else if suffix == 'Max' then c~max = t[i + 2]~text
    else pos[suffix] = t[i + 2]~text
  end
  if c~min == '' | c~max == '' then return .nil
  do i = 1 to n - 5
    if t[i]~kind \== 'IDENT' then iterate
    parse value t[i]~text with req '_' kind
    if wordpos(req, 'required optional') == 0 then iterate
    if t[i + 1]~text \== '(' then iterate
    if t[i + 2]~text \== x then iterate
    argName = t[i + 4]~text
    if \pos~hasIndex(argName) then iterate
    p = pos[argName]
    c~kinds[p] = kind~upper
    c~notes~append(p || ':' || kind~upper '(BIF:' t[i]~text || ')')
    if i > 2 then if t[i - 1]~text == '=' then if t[i - 2]~kind == 'IDENT' then locals[t[i - 2]~text] = p
  end
  /* the method the BIF hands its arguments to: return recv->m(args) */
  do i = 1 to n - 4
    if t[i]~text \== 'return' then iterate
    if t[i + 1]~kind \== 'IDENT' then iterate
    if t[i + 2]~text \== '->' then iterate
    recv = t[i + 1]~text
    meth = t[i + 3]~text
    if t[i + 4]~text \== '(' then iterate
    argPos = self~callArgs(t, i + 4, locals)
    self~follow(c, 'RexxString', meth, argPos, 1)
    leave
  end
  return c
/* Arguments of the call whose '(' is at t[open]: an array of BIF positions (0 when an argument is not
 * a name that maps to one). */
::method callArgs
  use strict arg t, open, names
  out = .array~new
  depth = 0
  cur = ''
  count = 0
  do k = open + 1 to t~items
    tk = t[k]
    if tk~text == '(' | tk~text == '[' then depth += 1
    if tk~text == ')' | tk~text == ']' then do
      if depth == 0 then do
        out~append(self~posOf(cur, names, count))
        return out
      end
      depth -= 1
    end
    if tk~text == ',' then if depth == 0 then do
      out~append(self~posOf(cur, names, count))
      cur = ''
      count = 0
      iterate
    end
    count += 1
    if count == 1 then cur = tk~text
  end
  return out
::method posOf
  use strict arg first, names, count
  if count \== 1 then return 0
  if names~hasIndex(first) then return names[first]
  return 0
/* Read the argument checks in Owner::meth, and follow calls that pass its parameters on. */
::method follow
  expose methods
  use strict arg c, owner, meth, argPos, depth
  if depth > 3 then return
  k = owner || '::' || meth
  if \methods~hasIndex(k) then return
  unit = .nil
  do u over methods[k]
    if self~paramList(u)~items == argPos~items then unit = u
  end
  if unit == .nil then return
  params = self~paramList(unit)
  byName = .directory~new
  do i = 1 to params~items
    if argPos[i] > 0 then byName[params[i]] = argPos[i]
  end
  t = unit~tokens
  do i = 1 to t~items - 2
    if t[i]~kind \== 'IDENT' then iterate
    if t[i + 1]~text \== '(' then iterate
    nm = t[i]~text
    kind = ''
    isCheck = (nm~right(8) == 'Argument')
    if wordpos(nm~upper~left(8), 'OPTIONAL REQUIRED') > 0 then isCheck = .true
    if isCheck then do
      /* the kind is in the name after 'optional' / 'required' (lengthArgument, optionalPadArgument) */
      base = nm~upper
      if base~left(8) == 'OPTIONAL' then base = base~substr(9)
      if base~left(8) == 'REQUIRED' then base = base~substr(9)
      if base~pos('LENGTH') > 0 then kind = 'LENGTH'
      if base~pos('NONNEGATIVE') > 0 then kind = 'LENGTH'
      if base~left(8) == 'POSITIVE' then kind = 'POSITION'
      if base~pos('POSITION') > 0 then kind = 'POSITION'
      if base~pos('PAD') > 0 then kind = 'PAD'
      if base~pos('OPTION') > 0 then kind = 'OPTION'
    end
    if kind \== '' then do
      p = t[i + 2]~text
      if byName~hasIndex(p) then do
        c~kinds[byName[p]] = kind
        c~notes~append(byName[p] || ':' || kind '(' || owner || '::' || meth || ':' nm || ')')
      end
      iterate
    end
    /* Owner2::m2(...) passing parameters on */
    if i > 2 then if t[i - 1]~text == '::' then if t[i - 2]~kind == 'IDENT' then do
      nextPos = self~callArgs(t, i + 1, byName)
      hit = .false
      do q over nextPos
        if q > 0 then hit = .true
      end
      if hit then self~follow(c, t[i - 2]~text, nm, nextPos, depth + 1)
    end
  end
::method paramList
  use strict arg u
  hdr = .array~of(.SlamJToken~new('OP', '(', 0, 0, 0, 0))
  do t over u~params
    hdr~append(t)
  end
  hdr~append(.SlamJToken~new('OP', ')', 0, 0, 0, 0))
  return .SlamCppSplitter~new~paramNames(hdr, 1)

/* ------------------------------------------------------------------------------------------------ */
::class BifNative public
::method read
  use strict arg file
  text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
  out = .directory~new
  t = .SlamCppLexer~new(text)~scan
  /* kSpecs = { {"NAME", min, max}, ... } */
  at = 0
  do i = 1 to t~items
    if t[i]~text == 'kSpecs' then if t[i + 1]~text == '=' then do
      at = i + 2
      leave
    end
  end
  if at > 0 then do
    k = at + 1
    do while k + 6 <= t~items
      if t[k]~text == '}' then if t[k + 1]~text \== ',' then leave
      if t[k]~text == '{' then if t[k + 1]~kind == 'STRING' then do
        nm = t[k + 1]~text~strip('B', '"')
        c = .BifContract~new(nm)
        c~min = t[k + 3]~text
        c~max = t[k + 5]~text
        out[nm] = c
        k += 7
        iterate
      end
      k += 1
    end
  end
  /* invoke: each branch if (name == "X" || ...) and the argument reads inside it */
  inv = .nil
  do u over .SlamCppSplitter~new~split(text)
    if u~selector == 'invoke' then inv = u
  end
  if inv == .nil then return out
  stmts = .SlamJavaParser~new(inv~tokens)~parseSeq(inv~tokens~items + 1)
  self~branches(stmts, out)
  return out
::method branches
  use strict arg stmts, out
  do s over stmts
    if s~kind \== 'IF' then iterate
    names = .array~new
    cl = s~clause
    do k = 1 to cl~items - 2
      if cl[k]~text == 'name' then if cl[k + 1]~text == '==' then if cl[k + 2]~kind == 'STRING' then names~append(cl[k + 2]~text~strip('B', '"'))
    end
    if names~items == 0 then iterate
    body = .array~new
    self~flatten(s~thenStmt, body)
    do nm over names
      if out~hasIndex(nm) then self~argReads(out[nm], body)
    end
  end
::method flatten
  use strict arg s, body
  if s == .nil then return
  do t over s~clause; body~append(t); end
  do x over s~body; self~flatten(x, body); end
  self~flatten(s~thenStmt, body)
  self~flatten(s~elseStmt, body)
  do x over s~arms; self~flatten(x, body); end
::method argReads
  use strict arg c, t
  n = t~items
  do i = 1 to n - 3
    if t[i]~kind \== 'IDENT' then iterate
    if t[i + 1]~text \== '(' then iterate
    nm = t[i]~text
    select
      when nm == 'get' then if t[i + 2]~kind == 'NUMBER' then do
        p = t[i + 2]~text + 1
        if c~kindAt(p) \== 'OPTION' then call setKind c, p, 'STRING', 'get(' || (p - 1) || ')'
      end
      when nm == 'ct' then if t[i + 2]~kind == 'NUMBER' then do
        p = t[i + 2]~text + 1
        m = 0
        if t[i + 3]~text == ',' then if t[i + 4]~kind == 'NUMBER' then m = t[i + 4]~text
        call setKind c, p, 'COUNT:' || m, 'ct(' || (p - 1) || ')'
      end
      when nm == 'pad' | nm == 'str' then if i + 4 <= n then if t[i + 4]~kind == 'NUMBER' then do
        p = t[i + 4]~text + 1
        kind = 'STRING'
        if nm == 'pad' then kind = 'PAD'
        if c~kindAt(p) \== 'OPTION' then call setKind c, p, kind, nm || '(a,' || (p - 1) || ')'
      end
      when nm == 'caseMode' then if t[i + 2]~text == 'get' then if t[i + 4]~kind == 'NUMBER' then call setKind c, t[i + 4]~text + 1, 'OPTION', 'caseMode(get(' || t[i + 4]~text || '))'
      otherwise nop
    end
  end
  return

::routine setKind
  use arg c, p, kind, how
  c~kinds[p] = kind
  c~notes~append(p || ':' || kind '(' || how || ')')
  return
