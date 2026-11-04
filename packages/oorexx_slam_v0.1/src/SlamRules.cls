/* SlamRules.cls - read the rules in code, in a form that is the same in ooRexx and Java.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 * Shapes (SlamSegmenter) say how code is built, so they keep each language's own words; a rule is
 * what the code checks. A GUARD's condition is cut at its top-level OR into atoms; each atom is one
 * reason to stop, and the rule is its negation: what MUST hold to go on.
 *
 *   ooRexx  if rec["status"] <> "ACTIVE" then return ...~failure(...)      MUST  K:status = S:ACTIVE
 *   Java    if (!"ACTIVE".equals(s(d,"status"))) continue;                 MUST  K:status = S:ACTIVE
 *
 * Operands:
 *   K:key   a keyed read: rec["key"] (ooRexx), m.get("key"), and calls to a KEYED READER, a unit
 *           SLAM finds by what it does (takes a map and a key, and reads the map with that key)
 *   V       a value the code was given or holds (its name is kept as a binding, not in the rule)
 *   NOW     the current time: .DateTime~new, Instant.now()
 *   S:text, N:number, NIL, B:true|false; E:... anything else (kept as text, rarely the same twice)
 * Conversions read as the same value: ~string, + 0, String.valueOf(x), and a one-argument call named
 * parse... (parseIso, Instant.parse, Long.parseLong). ~upper, toUpperCase() mark the value ^U.
 * Operators: = == -> EQ; <> \= \== >< != -> NE; < <= > >= (\< is GE, \> is LE); x.equals(y) is EQ,
 * x.isBefore(y) LT, x.isAfter(y) GT. EQ and NE sort their operands; the others put the lower rank
 * (K, NOW, V, E, S, N, NIL, B) on the left and turn the operator round to match.
 * The stop: REJECT (a return or raise naming a failure, a throw), SKIP (continue / iterate: this
 * candidate is not used), STOP (break / leave), RETURN (anything else).
 *
 * Alchemy rules kept: no private methods, expose first, no variable named result, nested IF instead of
 * relying on & short-circuit, no labels inside loops.
 */

::requires 'SlamSegmenter.cls'
::requires 'SlamJava.cls'

/* ------------------------------------------------------------------------------------------------ */
/* One token in the common form: kind ID NUM STR OP DOT KW; text as written (strings without quotes). */
::class SlamRTok public
::attribute kind
::attribute text
::attribute line
::method init
  expose kind text line
  use strict arg kind, text, line

::class SlamRule public
::attribute must          /* the operator and operands, e.g. EQ K:status S:ACTIVE */
::attribute key           /* must, with every V's name removed: what is matched across languages */
::attribute names         /* the names behind each V, in order */
::attribute flags         /* ^U marks */
::attribute stop          /* REJECT SKIP STOP RETURN */
::attribute line
::attribute unit
::attribute lang
::attribute path
::attribute when          /* the key of an enclosing IF the guard sits under, or '' */
::attribute stopToks      /* the tokens of the clause that stops (return 0, raise syntax 93.900 ...), common form */
::method init
  expose must key names flags stop line unit lang path when stopToks
  use strict arg must, key, names, flags, stop, line, unit, lang, path
  when = ''
  stopToks = .array~new
::method show
  expose must names flags
  out = must
  if names \== '' then out = out '   [V:' names || ']'
  if flags \== '' then out = out '  ' flags
  return out
/* Does the rule hold for a keyed value k and a given value v? .true / .false, or '' when the rule is
 * not of a kind SLAM can work out (it says so rather than guess). ^U on a side compares upper case. */
::method holds
  expose must flags
  use strict arg k, v
  parse var must op l r .
  if wordpos(op, 'EQ NE LT LE GT GE') == 0 then return ''
  a = self~valueOf(l, k, v, wordpos('L^U', flags) > 0)
  b = self~valueOf(r, k, v, wordpos('R^U', flags) > 0)
  if a == .nil | b == .nil then return ''
  isNum = datatype(a, 'N') & datatype(b, 'N')
  select
    when op == 'EQ' then do
      if isNum then return a = b
      return a == b
    end
    when op == 'NE' then do
      if isNum then return a \= b
      return a \== b
    end
    when \isNum then return ''
    when op == 'LT' then return a < b
    when op == 'LE' then return a <= b
    when op == 'GT' then return a > b
    otherwise return a >= b
  end
::method valueOf
  use strict arg c, k, v, up
  x = .nil
  select
    when c~left(2) == 'K:' then x = k
    when c == 'V' then x = v
    when c~left(2) == 'N:' then x = c~substr(3)
    when c~left(2) == 'S:' then x = c~substr(3)
    otherwise nop
  end
  if x \== .nil then if up then x = x~upper
  return x

/* ------------------------------------------------------------------------------------------------ */
/* Rules as nodes. A RULE node is the same in every language: 'RULE: EQ K:status S:ACTIVE'. Each GUARD
 * that stops on it gets a made edge GUARD -> RULE (freq 0: no prior), scored only by tests. */
::class SlamRuleNodes public
::method ruleNode class
  use strict arg store, rule
  return store~shapeId('RULE', 'RULE', 'RULE:' rule~key)
/* The GUARD node a rule came from: the GUARD instance of its unit at or before its line (a run of
 * same-shape guards is one instance at the first line). */
::method guardNode class
  use strict arg store, rule
  sel = rule~unit~selector
  return store~scalar("SELECT i.shape_id AS id FROM instance i JOIN unit u ON u.id = i.unit_id JOIN shape s ON s.id = i.shape_id WHERE u.path = ? AND u.selector = ? AND s.kind = 'GUARD' AND i.line <= ? ORDER BY i.line DESC LIMIT 1", store~binds(rule~path, sel, rule~line))
::method link class
  use strict arg store, rule
  g = self~guardNode(store, rule)
  if g == '' then return .nil
  n = self~ruleNode(store, rule)
  store~q('INSERT OR IGNORE INTO edge (from_id, to_id, freq) VALUES (?, ?, 0)', store~binds(g, n))
  return .array~of(g, n)

/* ------------------------------------------------------------------------------------------------ */
::class SlamRuleReader public
::attribute readers       /* Java keyed readers found in the file being read: selector -> .true */
::attribute locals        /* local name -> operand, for the unit being read */
::method init
  expose readers locals
  readers = .directory~new
  locals = .directory~new

/* ---- tokens in the common form ---- */
::method rexxTokens
  use strict arg toks
  out = .array~new
  do t over toks
    select
      when t~kind == 'IDENT' then out~append(.SlamRTok~new('ID', t~text, t~line))
      when t~kind == 'NUMBER' then out~append(.SlamRTok~new('NUM', t~text, t~line))
      when t~kind == 'STRING' then out~append(.SlamRTok~new('STR', t~text, t~line))
      when t~kind == 'DOTIDENT' then out~append(.SlamRTok~new('DOT', t~text, t~line))
      when t~kind == 'OP' then do
        op = self~rexxOp(t~text)
        out~append(.SlamRTok~new('OP', op, t~line))
      end
      otherwise nop
    end
  end
  return out
::method rexxOp
  use strict arg x
  select
    when x == '|' then return 'OR'
    when x == '&' then return 'AND'
    when x == '\' then return 'NOT'
    when x == '=' | x == '==' then return 'EQ'
    when wordpos(x, '<> \= \== ><') > 0 then return 'NE'
    when x == '<' then return 'LT'
    when x == '<=' | x == '\>' then return 'LE'
    when x == '>' then return 'GT'
    when x == '>=' | x == '\<' then return 'GE'
    when x == '~' then return '.'
    otherwise return x
  end
::method javaTokens
  use strict arg toks
  out = .array~new
  do t over toks
    select
      when t~kind == 'IDENT' then out~append(.SlamRTok~new('ID', t~text, t~line))
      when t~kind == 'NUMBER' then out~append(.SlamRTok~new('NUM', t~text, t~line))
      when t~kind == 'STRING' then do
        v = t~text
        if v~length >= 2 then v = v~substr(2, v~length - 2)
        out~append(.SlamRTok~new('STR', v, t~line))
      end
      when t~kind == 'KEYWORD' then out~append(.SlamRTok~new('KW', t~text, t~line))
      when t~kind == 'OP' then do
        x = t~text
        op = x
        select
          when x == '||' then op = 'OR'
          when x == '&&' then op = 'AND'
          when x == '!' then op = 'NOT'
          when x == '==' then op = 'EQ'
          when x == '!=' then op = 'NE'
          when x == '<' then op = 'LT'
          when x == '<=' then op = 'LE'
          when x == '>' then op = 'GT'
          when x == '>=' then op = 'GE'
          otherwise nop
        end
        out~append(.SlamRTok~new('OP', op, t~line))
      end
      otherwise nop
    end
  end
  return out

/* ---- brackets in a common token array ---- */
::method matchOf
  use strict arg a
  m = .array~new(a~items)
  stack = .array~new
  do i = 1 to a~items
    if a[i]~kind \== 'OP' then iterate
    x = a[i]~text
    if x == '(' | x == '[' then stack~append(i)
    if x == ')' | x == ']' then do
      if stack~items == 0 then iterate
      j = stack[stack~items]
      stack~delete(stack~items)
      m[j] = i
      m[i] = j
    end
  end
  return m
::method sub
  use strict arg a, from, upto
  out = .array~new
  do k = from to upto
    out~append(a[k])
  end
  return out
::method isOp
  use strict arg t, x
  if t~kind \== 'OP' then return .false
  return t~text == x
/* Cut at a top-level operator (depth 0 by ( and [ ). */
::method splitTop
  use strict arg a, op
  parts = .array~new
  cur = .array~new
  depth = 0
  do t over a
    if t~kind == 'OP' then do
      if t~text == '(' | t~text == '[' then depth += 1
      if t~text == ')' | t~text == ']' then depth -= 1
      if depth == 0 then if t~text == op then do
        parts~append(cur)
        cur = .array~new
        iterate
      end
    end
    cur~append(t)
  end
  parts~append(cur)
  return parts
::method stripParens
  use strict arg a
  do forever
    if a~items < 2 then return a
    if \self~isOp(a[1], '(') then return a
    m = self~matchOf(a)
    if m[1] \== a~items then return a
    a = self~sub(a, 2, a~items - 1)
  end

/* ---- operands ---- */
::method rank
  use strict arg c
  p = c
  if c~pos(':') > 0 then p = c~left(c~pos(':') - 1)
  return wordpos(p, 'K NOW V E S N NIL B')
::method operand
  expose readers locals
  use strict arg a
  d = .directory~new
  d['FLAGS'] = ''
  d['NAME'] = ''
  a = self~stripParens(a)
  /* conversions and case marks, from the end */
  do forever
    n = a~items
    if n >= 3 then if self~isOp(a[n - 1], '.') then if a[n]~kind == 'ID' then if wordpos(a[n]~text~lower, 'string') > 0 then do
      a = self~sub(a, 1, n - 2)
      iterate
    end
    if n >= 3 then if self~isOp(a[n - 1], '.') then if a[n]~kind == 'ID' then if wordpos(a[n]~text~lower, 'upper lower') > 0 then do
      d['FLAGS'] = '^U'
      a = self~sub(a, 1, n - 2)
      iterate
    end
    if n >= 3 then if self~isOp(a[n - 1], '+') then if a[n]~kind == 'NUM' then if a[n]~text = 0 then do
      a = self~sub(a, 1, n - 2)
      iterate
    end
    if n >= 5 then if self~isOp(a[n - 3], '.') then if self~isOp(a[n - 1], '(') then if self~isOp(a[n], ')') then if wordpos(a[n - 2]~text~lower, 'touppercase tolowercase') > 0 then do
      d['FLAGS'] = '^U'
      a = self~sub(a, 1, n - 4)
      iterate
    end
    leave
  end
  n = a~items
  if n == 0 then return self~opnd(d, 'E:')
  m = self~matchOf(a)
  t1 = a[1]
  if n == 1 then do
    select
      when t1~kind == 'STR' then return self~opnd(d, 'S:' || t1~text)
      when t1~kind == 'NUM' then return self~opnd(d, 'N:' || self~num(t1~text))
      when t1~kind == 'DOT' then do
        if t1~text == 'NIL' then return self~opnd(d, 'NIL')
        if wordpos(t1~text, 'TRUE FALSE') > 0 then return self~opnd(d, 'B:' || t1~text~lower)
      end
      when t1~kind == 'KW' then do
        if t1~text == 'null' then return self~opnd(d, 'NIL')
        if wordpos(t1~text, 'true false') > 0 then return self~opnd(d, 'B:' || t1~text)
      end
      when t1~kind == 'ID' then do
        if locals~hasIndex(t1~text~lower) then if locals[t1~text~lower] \== .nil then do
          known = locals[t1~text~lower]
          d['FLAGS'] = (d['FLAGS'] known['FLAGS'])~strip
          d['NAME'] = known['NAME']
          return self~opnd(d, known['C'])
        end
        d['NAME'] = t1~text
        return self~opnd(d, 'V')
      end
      otherwise nop
    end
  end
  if n == 2 then if self~isOp(t1, '-') then if a[2]~kind == 'NUM' then return self~opnd(d, 'N:' || self~num('-' || a[2]~text))
  /* rec["key"] */
  if n == 4 then if t1~kind == 'ID' then if self~isOp(a[2], '[') then if a[3]~kind == 'STR' then if self~isOp(a[4], ']') then return self~opnd(d, 'K:' || a[3]~text)
  /* now: .DateTime~new  /  Instant.now() */
  if n == 3 then if t1~kind == 'DOT' then if t1~text == 'DATETIME' then if a[3]~text~lower == 'new' then return self~opnd(d, 'NOW')
  if n == 5 then if t1~kind == 'ID' then if a[3]~text == 'now' then if self~isOp(a[4], '(') then if self~isOp(a[5], ')') then return self~opnd(d, 'NOW')
  /* receiver.get("key") / receiver.getOrDefault("key", x); conversions; accessors */
  do i = 2 to n - 2
    if \self~isOp(a[i], '.') then iterate
    nm = a[i + 1]~text~lower
    if i + 2 > n then iterate
    if \self~isOp(a[i + 2], '(') then iterate
    if m[i + 2] \== n then iterate
    if wordpos(nm, 'get getordefault') > 0 then if i + 3 <= n then if a[i + 3]~kind == 'STR' then return self~opnd(d, 'K:' || a[i + 3]~text)
    args = self~argsOf(a, i + 2, m)
    /* a conversion: X.parse(y), String.valueOf(y), Long.parseLong(y), self~parseIso(y) */
    if args~items == 1 then if nm~left(5) == 'parse' | nm == 'valueof' then return self~mergeInto(d, self~operand(args[1]))
    /* an accessor: x.name() / x~name, no arguments */
    if args~items == 0 then do
      d['NAME'] = a[i + 1]~text
      return self~opnd(d, 'V')
    end
  end
  /* a call: keyed reader f(map, "key", ...) */
  if t1~kind == 'ID' then if n >= 3 then if self~isOp(a[2], '(') then if m[2] == n then do
    args = self~argsOf(a, 2, m)
    if readers~hasIndex(t1~text) then if args~items >= 2 then if args[2]~items == 1 then if args[2][1]~kind == 'STR' then return self~opnd(d, 'K:' || args[2][1]~text)
  end
  /* x.name / x~name with no call */
  if n == 3 then if t1~kind == 'ID' then if self~isOp(a[2], '.') then if a[3]~kind == 'ID' then do
    d['NAME'] = a[3]~text
    return self~opnd(d, 'V')
  end
  txt = .array~new
  do t over a
    txt~append(t~text~lower)
  end
  return self~opnd(d, 'E:' || txt~makeString('L', ' '))
::method opnd
  use strict arg d, c
  d['C'] = c
  return d
::method mergeInto
  use strict arg d, inner
  inner['FLAGS'] = (d['FLAGS'] inner['FLAGS'])~strip
  return inner
::method num
  use strict arg x
  y = x~changeStr('_', '')
  if y~right(1)~upper == 'L' then y = y~left(y~length - 1)
  if datatype(y, 'N') then return y + 0
  return x
/* Arguments of the call whose '(' is at open: arrays of tokens, cut at top-level commas. */
::method argsOf
  use strict arg a, open, m
  close = m[open]
  if close == open + 1 then return .array~new
  return self~splitTop(self~sub(a, open + 1, close - 1), ',')

/* ---- atoms ---- */
::method mirror
  use strict arg op
  select
    when op == 'LT' then return 'GT'
    when op == 'GT' then return 'LT'
    when op == 'LE' then return 'GE'
    when op == 'GE' then return 'LE'
    otherwise return op
  end
::method negate
  use strict arg op
  select
    when op == 'EQ' then return 'NE'
    when op == 'NE' then return 'EQ'
    when op == 'LT' then return 'GE'
    when op == 'GE' then return 'LT'
    when op == 'LE' then return 'GT'
    when op == 'GT' then return 'LE'
    when op == 'TRUE' then return 'FALSE'
    when op == 'FALSE' then return 'TRUE'
    otherwise return op
  end
/* An atom -> directory OP L R (operand directories); R is .nil for TRUE / FALSE. */
::method atom
  use strict arg a
  a = self~stripParens(a)
  if a~items > 0 then if self~isOp(a[1], 'NOT') then do
    inner = self~atom(self~sub(a, 2, a~items))
    inner['OP'] = self~negate(inner['OP'])
    return inner
  end
  depth = 0
  do i = 1 to a~items
    t = a[i]
    if t~kind \== 'OP' then iterate
    if t~text == '(' | t~text == '[' then depth += 1
    if t~text == ')' | t~text == ']' then depth -= 1
    if depth \== 0 then iterate
    if wordpos(t~text, 'EQ NE LT LE GT GE') > 0 then return self~cmp(t~text, self~operand(self~sub(a, 1, i - 1)), self~operand(self~sub(a, i + 1, a~items)))
  end
  /* x.equals(y), x.isBefore(y), x.isAfter(y), x.equalsIgnoreCase(y) */
  n = a~items
  if n >= 4 then if self~isOp(a[n], ')') then do
    m = self~matchOf(a)
    open = m[n]
    if open > 2 then if self~isOp(a[open - 2], '.') then do
      nm = a[open - 1]~text~lower
      args = self~argsOf(a, open, m)
      if args~items == 1 then do
        left = self~operand(self~sub(a, 1, open - 3))
        right = self~operand(args[1])
        if nm == 'equalsignorecase' then do
          left['FLAGS'] = '^U'
          right['FLAGS'] = '^U'
        end
        select
          when nm == 'equals' | nm == 'equalsignorecase' then return self~cmp('EQ', left, right)
          when nm == 'isbefore' then return self~cmp('LT', left, right)
          when nm == 'isafter' then return self~cmp('GT', left, right)
          otherwise nop
        end
      end
    end
  end
  d = .directory~new
  d['OP'] = 'TRUE'
  d['L'] = self~operand(a)
  d['R'] = .nil
  return d
::method cmp
  use strict arg op, l, r
  rl = self~rank(l['C'])
  rr = self~rank(r['C'])
  swap = .false
  if op == 'EQ' | op == 'NE' then do
    if rl > rr then swap = .true
    if rl == rr then if l['C'] >> r['C'] then swap = .true
  end
  else if rl > rr then do
    swap = .true
    op = self~mirror(op)
  end
  d = .directory~new
  d['OP'] = op
  if swap then do
    d['L'] = r
    d['R'] = l
  end
  else do
    d['L'] = l
    d['R'] = r
  end
  return d
/* An atom that stops the code -> the SlamRule of what must hold. */
::method ruleOf
  use strict arg atom, stop, line, unit, lang, path
  op = self~negate(atom['OP'])
  l = atom['L']
  r = atom['R']
  must = op l['C']
  names = l['NAME']
  flags = ''
  if l['FLAGS'] \== '' then flags = 'L' || l['FLAGS']
  if r \== .nil then do
    must = must r['C']
    names = (names r['NAME'])~strip
    if r['FLAGS'] \== '' then flags = (flags 'R' || r['FLAGS'])~strip
  end
  return .SlamRule~new(must, must, names~strip, flags, stop, line, unit, lang, path)
::method stopOf
  use strict arg c
  first = c[1]~text~lower
  if wordpos(first, 'continue iterate') > 0 then return 'SKIP'
  if wordpos(first, 'break leave') > 0 then return 'STOP'
  if wordpos(first, 'throw raise') > 0 then return 'REJECT'
  do t over c
    if t~kind == 'ID' then if wordpos(t~text~lower, 'failure failed fail') > 0 then return 'REJECT'
  end
  return 'RETURN'
/* A clause that names a local: ooRexx  X = expr ;  Java  [Type] x = expr. Kept when expr is a keyed
 * read, the time now, or a constant, so later guards on x read as guards on that. */
::method noteLocal
  expose locals
  use strict arg c
  do i = 2 to c~items - 1
    if \self~isOp(c[i], 'EQ') then if \self~isOp(c[i], '=') then iterate
    if c[i - 1]~kind \== 'ID' then return
    nm = c[i - 1]~text~lower
    /* a name assigned twice is not one value: it is never read through */
    if locals~hasIndex(nm) then do
      locals[nm] = .nil
      return
    end
    v = self~operand(self~sub(c, i + 1, c~items))
    p = self~rank(v['C'])
    if p == 1 | p == 2 then do
      v['NAME'] = c[i - 1]~text
      locals[nm] = v
    end
    else locals[nm] = .nil
    return
  end

/* ---- units ---- */
/* Rules of one ooRexx unit (SlamUnit from SlamUnitSplitter). */
::method rexxUnit
  expose locals
  use strict arg unit, path
  locals = .directory~new
  clauses = .SlamClauses~build(unit~tokens)
  stmts = .SlamParser~new(clauses)~parseSeq(.false)
  out = .array~new
  self~walk(stmts, 'REXX', unit, path, out, '')
  return out
/* Rules of one Java unit (SlamJavaUnit). */
::method javaUnit
  expose locals
  use strict arg unit, path
  locals = .directory~new
  stmts = .SlamJavaParser~new(unit~tokens)~parseSeq(unit~tokens~items + 1)
  out = .array~new
  self~walk(stmts, 'JAVA', unit, path, out, '')
  return out
::method common
  use strict arg c, lang
  if lang == 'REXX' then return self~rexxTokens(c)
  return self~javaTokens(c)
/* The condition of an IF clause: ooRexx  IF c THEN ;  Java  if ( c ). */
::method condOf
  use strict arg c, lang
  a = self~common(c, lang)
  if lang == 'REXX' then do
    n = a~items
    if n > 0 then if a[n]~kind == 'ID' then if a[n]~text == 'THEN' then n -= 1
    return self~sub(a, 2, n)
  end
  return self~stripParens(self~sub(a, 2, a~items))
::method isTerm
  use strict arg s, lang
  if s == .nil then return .false
  if s~kind \== 'SIMPLE' then return .false
  if lang == 'REXX' then return .SlamShaper~new~clauseClass(s~clause) == 'TERM'
  return .SlamJavaShaper~new~clauseClass(s~clause) == 'TERM'
::method walk
  use strict arg stmts, lang, unit, path, out, when
  do s over stmts
    select
      when s~kind == 'SIMPLE' then self~noteLocal(self~common(s~clause, lang))
      when s~kind == 'IF' then do
        cond = self~condOf(s~clause, lang)
        thenS = s~thenStmt
        if s~elseStmt == .nil then if self~isTerm(thenS, lang) then do
          stopToks = self~common(thenS~clause, lang)
          stop = self~stopOf(stopToks)
          line = s~clause[1]~line
          do part over self~splitTop(cond, 'OR')
            ands = self~splitTop(part, 'AND')
            if ands~items > 1 then do
              /* a stop on (a AND b): what must hold is NOT ALL(a; b), kept as one rule */
              k = .array~new
              nm = ''
              do x over ands
                a = self~atom(x)
                txt = a['OP'] a['L']['C']
                nm = nm a['L']['NAME']
                if a['R'] \== .nil then do
                  txt = txt a['R']['C']
                  nm = nm a['R']['NAME']
                end
                k~append(txt)
              end
              must = 'NOTALL(' || k~makeString('L', '; ') || ')'
              r = .SlamRule~new(must, must, nm~space, '', stop, line, unit, lang, path)
              r~when = when
              r~stopToks = stopToks
              out~append(r)
              iterate
            end
            r = self~ruleOf(self~atom(part), stop, line, unit, lang, path)
            r~when = when
            r~stopToks = stopToks
            out~append(r)
          end
          iterate
        end
        /* IF c THEN <guard>: the guard holds only when c does */
        inner = when
        if s~elseStmt == .nil then do
          k = .array~new
          do part over self~splitTop(cond, 'AND')
            a = self~atom(part)
            txt = a['OP'] a['L']['C']
            if a['R'] \== .nil then txt = txt a['R']['C']
            k~append(txt)
          end
          inner = k~makeString('L', ' AND ')
        end
        if thenS \== .nil then self~walk(.array~of(thenS), lang, unit, path, out, inner)
        if s~elseStmt \== .nil then self~walk(.array~of(s~elseStmt), lang, unit, path, out, when)
      end
      when s~kind == 'DO' | s~kind == 'BLOCKH' then self~walk(s~body, lang, unit, path, out, when)
      when s~kind == 'SELECT' | s~kind == 'TRY' then do
        self~walk(s~body, lang, unit, path, out, when)
        do arm over s~arms
          if arm~thenStmt \== .nil then self~walk(.array~of(arm~thenStmt), lang, unit, path, out, when)
          self~walk(arm~body, lang, unit, path, out, when)
        end
      end
      otherwise nop
    end
  end
/* Java keyed readers in a file: a unit taking (Map m, String k, ...) whose body reads m with k, by
 * m.get(k), m.getOrDefault(k, ..), or by calling a keyed reader with (m, k). */
::method findReaders
  expose readers
  use strict arg units
  readers = .directory~new
  do forever
    added = 0
    do u over units
      if readers~hasIndex(u~selector) then iterate
      p = u~params
      if p~items < 4 then iterate
      if p[1]~text \== 'Map' then iterate
      hdr = .array~of(.SlamJToken~new('OP', '(', 0, 0, 0, 0))
      do t over p; hdr~append(t); end
      hdr~append(.SlamJToken~new('OP', ')', 0, 0, 0, 0))
      names = .SlamJavaSplitter~new~paramNames(hdr, 1)       /* generics' commas are not boundaries */
      if names~items < 2 then iterate
      mName = names[1]
      kName = names[2]
      t = u~tokens
      hit = .false
      do i = 1 to t~items - 3
        if t[i]~text == mName then if t[i + 1]~text == '.' then if wordpos(t[i + 2]~text, 'get getOrDefault') > 0 then if t[i + 3]~text == '(' then if i + 4 <= t~items then if t[i + 4]~text == kName then hit = .true
        if readers~hasIndex(t[i]~text) then if t[i + 1]~text == '(' then if t[i + 2]~text == mName then if t[i + 3]~text == ',' then if i + 4 <= t~items then if t[i + 4]~text == kName then hit = .true
      end
      if hit then do
        readers[u~selector] = .true
        added += 1
      end
    end
    if added == 0 then leave
  end
  return readers

/* ---- comparing two units' rules ---- */
/* Keys two rule lists share, and Jaccard similarity over their key sets. */
::method similarity class
  use strict arg a, b
  ka = .directory~new
  kb = .directory~new
  do r over a; ka[r~key] = .true; end
  do r over b; kb[r~key] = .true; end
  both = 0
  do k over ka~allIndexes
    if kb~hasIndex(k) then both += 1
  end
  union = ka~items + kb~items - both
  if union == 0 then return 0
  return both / union
