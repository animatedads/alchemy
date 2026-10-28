/* SlamSegmenter.cls - SLAM v0.1: cut ooRexx code units into logic segments and give each one a shape.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 * Tokens come from the rx2cpp compiler's own lexer (vendor/rx2cpp, unmodified). This file adds no
 * Rexx scanner: it groups tokens into clauses, nests clauses into IF / DO / SELECT statements, and
 * cuts statements into segments.
 *
 * A segment is identified by its SHAPE, not its text:
 *   - variables become roles by first occurrence in the segment: A1.. (method/routine argument),
 *     F1.. (exposed object field), L1.. (local); the real names are kept as the instance's binding
 *   - strings become S, numbers N
 *   - consecutive clauses of the same shape collapse to one clause marked "+"
 *   - a composite (BRANCH, LOOP, BLOCK, SELECT, ARM) is its own header plus the KIND sequence of its
 *     children; each child is a segment (node) in its own right
 * Two levels: FINE keeps message, function and class names (node identity); FAMILY abstracts them
 * to M, F and .C (the coarser class used for fallback).
 *
 * Segment kinds: ENTRY (expose / use arg / parse arg at unit start), RUN (straight-line clauses that
 * share data), GUARD (if ... then return|raise|signal|leave|iterate|exit, no else), BRANCH, LOOP,
 * BLOCK, SELECT, ARM, EXIT (a terminator), TRAP (signal on / call on), LABEL.
 *
 * Alchemy rules kept: no private methods, expose first, no variable named result, nested IF instead
 * of relying on & short-circuit.
 */

::requires 'core/RxLexer.cls'

/* ------------------------------------------------------------------------------------------------ */
::class SlamUnit public
::attribute kind
::attribute owner
::attribute selector
::attribute line
::attribute tokens
::method init
  expose kind owner selector line tokens
  use strict arg kind, owner, selector, line
  tokens = .array~new
/* Comment- and layout-insensitive identity of the body, used to skip duplicate units on ingest. */
::method signature
  expose tokens
  buf = .mutablebuffer~new
  do t over tokens
    if t~kind == 'SEP' then buf~append(';')
    else do
      buf~append(t~kind~left(1))
      buf~append(t~text)
      buf~append('1f'x)
    end
  end
  return buf~string
::method codeTokenCount
  expose tokens
  n = 0
  do t over tokens
    if t~kind \== 'SEP' then if t~kind \== 'EOF' then n += 1
  end
  return n

/* ------------------------------------------------------------------------------------------------ */
/* Unit boundaries from directive clauses (the lexer, never POS('::METHOD') on raw text). Prologue code
 * before the first directive is a PROLOGUE unit. ::CLASS sets the owner of following methods. */
::class SlamUnitSplitter public
::method split
  use strict arg text
  tokens = .RxLexer~new(text)~scan
  units = .array~new
  owner = ''
  cur = .SlamUnit~new('PROLOGUE', '', '', 1)
  atStart = .true
  n = tokens~items
  i = 1
  do while i <= n
    t = tokens[i]
    if t~kind == 'EOF' then leave
    isDirective = .false
    if atStart then if t~kind == 'OP' then if t~text == '::' then isDirective = .true
    if \isDirective then do
      if cur \== .nil then cur~tokens~append(t)
      atStart = (t~kind == 'SEP')
      i += 1
      iterate
    end
    if cur \== .nil then if cur~codeTokenCount > 0 then units~append(cur)
    cur = .nil
    d = ''
    if i + 1 <= n then d = tokens[i + 1]~text
    nameTok = .nil
    if i + 2 <= n then nameTok = tokens[i + 2]
    select
      when d == 'CLASS' then do
        if nameTok \== .nil then owner = nameTok~text
      end
      when d == 'METHOD' then do
        sel = ''
        if nameTok \== .nil then sel = nameTok~text
        cur = .SlamUnit~new('METHOD', owner, sel, t~line)
      end
      when d == 'ROUTINE' then do
        sel = ''
        if nameTok \== .nil then sel = nameTok~text
        cur = .SlamUnit~new('ROUTINE', '', sel, t~line)
      end
      otherwise nop
    end
    do while i <= n
      if tokens[i]~kind == 'SEP' then leave
      if tokens[i]~kind == 'EOF' then leave
      i += 1
    end
    atStart = .true
    i += 1
  end
  if cur \== .nil then if cur~codeTokenCount > 0 then units~append(cur)
  return units

/* ------------------------------------------------------------------------------------------------ */
/* Clauses: split at SEP, after THEN / ELSE / OTHERWISE at bracket depth 0, and after a label. */
::class SlamClauses public
::method build class
  use strict arg tokens
  clauses = .array~new
  cur = .array~new
  depth = 0
  do t over tokens
    if t~kind == 'SEP' | t~kind == 'EOF' then do
      if cur~items > 0 then clauses~append(cur)
      cur = .array~new
      depth = 0
      iterate
    end
    cur~append(t)
    if t~kind == 'OP' then do
      if t~text == '(' | t~text == '[' then depth += 1
      if t~text == ')' | t~text == ']' then depth -= 1
      if t~text == ':' then if cur~items == 2 then if cur[1]~kind == 'IDENT' then do
        clauses~append(cur)
        cur = .array~new
      end
      iterate
    end
    if t~kind == 'IDENT' then if depth <= 0 then if wordpos(t~text, 'THEN ELSE OTHERWISE') > 0 then do
      /* 'if c' then a new line 'then x' is 'if c then x': a THEN that starts a clause joins the IF or WHEN
         clause before it (found reading ooRexx's qtime.rex beside NetRexx's) */
      if t~text == 'THEN' then if cur~items == 1 then if clauses~items > 0 then do
        prev = clauses[clauses~items]
        if prev[1]~kind == 'IDENT' then if wordpos(prev[1]~text, 'IF WHEN') > 0 then if prev[prev~items]~text \== 'THEN' then do
          prev~append(t)
          cur = .array~new
          iterate
        end
      end
      clauses~append(cur)
      cur = .array~new
    end
  end
  if cur~items > 0 then clauses~append(cur)
  return clauses

/* ------------------------------------------------------------------------------------------------ */
::class SlamStmt public
::attribute kind
::attribute clause
::attribute body
::attribute thenStmt
::attribute elseStmt
::attribute arms
::method init
  expose kind clause body thenStmt elseStmt arms
  use strict arg kind, clause
  body = .array~new
  thenStmt = .nil
  elseStmt = .nil
  arms = .array~new

/* Nests clauses into IF / DO / SELECT statements. Malformed input never loops: every path advances. */
::class SlamParser public
::attribute clauses
::attribute pos
::method init
  expose clauses pos
  use strict arg clauses
  pos = 1
::method head
  expose clauses pos
  if pos > clauses~items then return ''
  c = clauses[pos]
  if c[1]~kind \== 'IDENT' then return ''
  if c~items > 1 then do
    second = c[2]
    if second~kind == 'OP' then if wordpos(second~text, '= += -= *= /= %= //= ||= &= |= &&= **= :') > 0 then return ''
  end
  return c[1]~text
::method parseSeq
  expose clauses pos
  use strict arg stopAtEnd
  seq = .array~new
  do while pos <= clauses~items
    h = self~head
    if h == 'END' then do
      if stopAtEnd then leave
      pos += 1
      iterate
    end
    seq~append(self~parseStmt)
  end
  return seq
::method parseStmt
  expose clauses pos
  c = clauses[pos]
  h = self~head
  if c~items == 2 then if c[1]~kind == 'IDENT' then if c[2]~kind == 'OP' then if c[2]~text == ':' then do
    pos += 1
    return .SlamStmt~new('LABEL', c)
  end
  select
    when h == 'IF' then do
      s = .SlamStmt~new('IF', c)
      pos += 1
      if pos <= clauses~items then do
        h2 = self~head
        if h2 \== 'ELSE' then if h2 \== 'END' then s~thenStmt = self~parseStmt
      end
      if pos <= clauses~items then if self~head == 'ELSE' then do
        pos += 1
        if pos <= clauses~items then if self~head \== 'END' then s~elseStmt = self~parseStmt
      end
      return s
    end
    when h == 'DO' then do
      s = .SlamStmt~new('DO', c)
      pos += 1
      s~body = self~parseSeq(.true)
      if self~head == 'END' then pos += 1
      return s
    end
    when h == 'SELECT' then do
      s = .SlamStmt~new('SELECT', c)
      pos += 1
      do while pos <= clauses~items
        h2 = self~head
        if h2 == 'END' then do
          pos += 1
          leave
        end
        if h2 == 'WHEN' then do
          arm = .SlamStmt~new('WHEN', clauses[pos])
          pos += 1
          if pos <= clauses~items then if self~head \== 'END' then arm~thenStmt = self~parseStmt
          s~arms~append(arm)
          iterate
        end
        if h2 == 'OTHERWISE' then do
          arm = .SlamStmt~new('OTHERWISE', clauses[pos])
          pos += 1
          arm~body = self~parseSeq(.true)
          s~arms~append(arm)
          iterate
        end
        s~body~append(self~parseStmt)
      end
      return s
    end
    otherwise do
      pos += 1
      return .SlamStmt~new('SIMPLE', c)
    end
  end

/* ------------------------------------------------------------------------------------------------ */
::class SlamSegment public
::attribute kind
::attribute fine
::attribute family
::attribute line
::attribute repeat
::attribute binding
::attribute sequences
::method init
  expose kind fine family line repeat binding sequences
  use strict arg kind, line
  fine = ''
  family = ''
  repeat = 1
  binding = ''
  sequences = .array~new
::method addSequence
  expose sequences
  use strict arg ctx, segs
  sequences~append(.array~of(ctx, segs))
/* Total segments in this subtree, this one included. */
::method size
  expose sequences
  n = 1
  do sq over sequences
    do s over sq[2]
      n += s~size
    end
  end
  return n

/* Role allocation for one segment. */
::class SlamRoles public
::attribute args
::attribute fields
::attribute map
::attribute nA
::attribute nF
::attribute nL
::method init
  expose args fields map nA nF nL
  use strict arg args, fields
  map = .directory~new
  nA = 0
  nF = 0
  nL = 0
::method role
  expose args fields map nA nF nL
  use strict arg name
  if map~hasIndex(name) then return map[name]
  select
    when fields~hasIndex(name) then do
      nF += 1
      r = 'F' || nF
    end
    when args~hasIndex(name) then do
      nA += 1
      r = 'A' || nA
    end
    otherwise do
      nL += 1
      r = 'L' || nL
    end
  end
  map[name] = r
  return r
::method binding
  expose map
  out = .array~new
  do k over map~allIndexes~sort
    out~append(map[k] || '=' || k)
  end
  return out~makeString('L', ' ')

/* ------------------------------------------------------------------------------------------------ */
::class SlamShaper public
::constant INSTRUCTIONS 'ADDRESS ARG CALL DO DROP ELSE END EXIT EXPOSE FORWARD GUARD IF INTERPRET ITERATE LEAVE NOP NUMERIC OTHERWISE PARSE PROCEDURE PULL PUSH QUEUE RAISE REPLY RETURN SAY SELECT SIGNAL TRACE USE WHEN'
::method subkeywords
  use strict arg instr
  select
    when instr == 'IF' | instr == 'WHEN' then return 'THEN'
    when instr == 'DO' then return 'TO BY FOR WHILE UNTIL OVER FOREVER WITH INDEX ITEM COUNTER LABEL <LOOP>'
    when instr == 'USE' then return 'STRICT ARG'
    when instr == 'PARSE' then return 'UPPER LOWER CASELESS ARG LINEIN PULL SOURCE VALUE VAR VERSION WITH'
    when instr == 'RAISE' then return 'SYNTAX ERROR FAILURE HALT NOVALUE NOTREADY LOSTDIGITS USER PROPAGATE ARRAY ADDITIONAL DESCRIPTION EXIT RETURN'
    when instr == 'SIGNAL' | instr == 'CALL' then return 'ON OFF NAME VALUE ERROR FAILURE HALT NOVALUE NOTREADY SYNTAX LOSTDIGITS USER ANY'
    when instr == 'NUMERIC' then return 'DIGITS FUZZ FORM SCIENTIFIC ENGINEERING VALUE'
    when instr == 'FORWARD' then return 'TO MESSAGE ARGUMENTS ARRAY CLASS CONTINUE'
    when instr == 'GUARD' then return 'ON OFF WHEN'
    when instr == 'SELECT' then return 'CASE'
    when instr == 'PROCEDURE' then return 'EXPOSE'
    when instr == 'ADDRESS' then return 'WITH VALUE'
    otherwise return ''
  end
/* The instruction keyword a clause starts with, or '' for assignments, message clauses and labels. */
::method instructionOf
  use strict arg c
  if c[1]~kind \== 'IDENT' then return ''
  if wordpos(c[1]~text, self~INSTRUCTIONS) == 0 then return ''
  if c~items > 1 then do
    second = c[2]
    if second~kind == 'OP' then if wordpos(second~text, '= += -= *= /= %= //= ||= &= |= &&= **= : ~ ~~ [') > 0 then return ''
  end
  return c[1]~text
::method clauseClass
  use strict arg c
  instr = self~instructionOf(c)
  if instr == '' then return 'PLAIN'
  if wordpos(instr, 'EXPOSE USE ARG') > 0 then return 'ENTRY'
  if instr == 'PARSE' then do
    last = min(4, c~items)
    do k = 2 to last
      if c[k]~kind == 'IDENT' then if c[k]~text == 'ARG' then return 'ENTRY'
    end
    return 'PLAIN'
  end
  if wordpos(instr, 'RETURN EXIT RAISE LEAVE ITERATE FORWARD REPLY') > 0 then return 'TERM'
  if instr == 'SIGNAL' | instr == 'CALL' then do
    if c~items >= 2 then if c[2]~kind == 'IDENT' then if wordpos(c[2]~text, 'ON OFF') > 0 then return 'TRAP'
    if instr == 'SIGNAL' then return 'TERM'
  end
  return 'PLAIN'
/* What one token is, inside its clause. */
::method tokenRole
  use strict arg c, i, instr, subs
  t = c[i]
  if t~kind == 'STRING' then return 'STRING'
  if t~kind == 'NUMBER' then return 'NUMBER'
  if t~kind == 'DOTIDENT' then return 'DOT'
  if t~kind \== 'IDENT' then return 'OP'
  up = t~text
  if i == 1 then if instr \== '' then return 'KEYWORD'
  if wordpos(up, subs) > 0 then return 'KEYWORD'
  if i > 1 then do
    p = c[i - 1]
    if p~kind == 'OP' then if p~text == '~' | p~text == '~~' then return 'MESSAGE'
  end
  if up == 'SELF' | up == 'SUPER' then return 'SELF'
  if i == 1 then if c~items == 2 then if c[2]~kind == 'OP' then if c[2]~text == ':' then return 'LABEL'
  if i == 2 then if instr == 'CALL' then return 'FUNCTION'
  if i < c~items then do
    nx = c[i + 1]
    if nx~kind == 'OP' then if nx~text == '(' then if nx~line == t~endLine then if nx~col == t~endCol then return 'FUNCTION'
  end
  return 'VAR'
/* Pieces of a (possibly compound) symbol: X.I. -> X, I, '' */
::method pieces
  use strict arg name
  out = .array~new
  s = name
  do forever
    p = s~pos('.')
    if p == 0 then do
      out~append(s)
      leave
    end
    out~append(s~left(p - 1))
    s = s~substr(p + 1)
  end
  return out
::method roleName
  use strict arg name, roles
  parts = self~pieces(name)
  out = .array~new
  do k = 1 to parts~items
    piece = parts[k]
    select
      when piece == '' then out~append('')
      when k > 1 & datatype(piece, 'W') then out~append('N')
      otherwise out~append(roles~role(piece))
    end
  end
  return out~makeString('L', '.')
::method render
  use strict arg c, roles, mode
  instr = self~instructionOf(c)
  subs = self~subkeywords(instr)
  out = .array~new
  do i = 1 to c~items
    t = c[i]
    r = self~tokenRole(c, i, instr, subs)
    select
      when r == 'STRING' then out~append('S')
      when r == 'NUMBER' then out~append('N')
      when r == 'OP' then out~append(t~text)
      when r == 'DOT' then do
        if mode == 'FAMILY' then do
          if wordpos(t~text, 'TRUE FALSE NIL') == 0 then out~append('.C')
          else out~append('.' || t~text~lower)
        end
        else out~append('.' || t~text~lower)
      end
      when r == 'KEYWORD' then out~append(t~text~lower)
      when r == 'MESSAGE' then do
        if mode == 'FAMILY' then out~append('M')
        else out~append(t~text~lower)
      end
      when r == 'FUNCTION' then do
        if mode == 'FAMILY' then out~append('F')
        else out~append(t~text~lower)
      end
      when r == 'SELF' then out~append(t~text~lower)
      when r == 'LABEL' then out~append('label')
      otherwise out~append(self~roleName(t~text, roles))
    end
  end
  return out~makeString('L', ' ')
/* Names a clause reads or writes (compound pieces separately); SELF counts as shared object state. */
::method varsOf
  use strict arg c
  instr = self~instructionOf(c)
  subs = self~subkeywords(instr)
  vars = .directory~new
  do i = 1 to c~items
    r = self~tokenRole(c, i, instr, subs)
    if r == 'SELF' then vars['SELF'] = .true
    if r == 'VAR' then do
      do piece over self~pieces(c[i]~text)
        if piece \== '' then if \datatype(piece, 'W') then vars[piece] = .true
      end
    end
  end
  return vars
/* The family shape of one clause on its own (fresh roles): the key for repetition collapse. */
::method clauseKey
  use strict arg c, ctx
  return self~render(c, .SlamRoles~new(ctx['ARGS'], ctx['FIELDS']), 'FAMILY')
/* Unit-level argument and field names, for A and F roles. */
::method unitContext
  use strict arg clauses
  args = .directory~new
  fields = .directory~new
  do c over clauses
    instr = self~instructionOf(c)
    if instr == 'EXPOSE' then do
      do i = 2 to c~items
        if c[i]~kind == 'IDENT' then fields[self~pieces(c[i]~text)[1]] = .true
      end
    end
    if instr == 'USE' | instr == 'ARG' | instr == 'PARSE' then do
      argAt = 0
      if instr == 'ARG' then argAt = 1
      else do
        do i = 2 to c~items
          if c[i]~kind == 'IDENT' then if c[i]~text == 'ARG' then do
            argAt = i
            leave
          end
        end
      end
      if argAt == 0 then iterate
      depth = 0
      do i = argAt + 1 to c~items
        t = c[i]
        if t~kind == 'OP' then do
          if t~text == '(' then depth += 1
          if t~text == ')' then depth -= 1
          iterate
        end
        if t~kind \== 'IDENT' then iterate
        if depth > 0 then iterate
        if instr == 'USE' then do
          p = c[i - 1]
          isName = .false
          if i - 1 == argAt then isName = .true
          if p~kind == 'OP' then if p~text == ',' then isName = .true
          if \isName then iterate
        end
        args[self~pieces(t~text)[1]] = .true
      end
    end
  end
  ctx = .directory~new
  ctx['ARGS'] = args
  ctx['FIELDS'] = fields
  return ctx

/* ------------------------------------------------------------------------------------------------ */
::class SlamRun public
::attribute kind
::attribute clauses
::attribute vars
::method init
  expose kind clauses vars
  kind = ''
  clauses = .array~new
  vars = .directory~new
::method isEmpty
  expose clauses
  return clauses~items == 0
::method add
  expose clauses vars
  use strict arg c, newVars = .nil
  clauses~append(c)
  if newVars \== .nil then do
    do k over newVars~allIndexes
      vars[k] = .true
    end
  end
::method shares
  expose vars
  use strict arg other
  do k over other~allIndexes
    if vars~hasIndex(k) then return .true
  end
  return .false

/* ------------------------------------------------------------------------------------------------ */
::class SlamSegmenter public
::attribute shaper
::method init
  expose shaper
  shaper = .SlamShaper~new
/* A unit -> its top-level segment sequence (each composite carries its own child sequences). */
::method segmentUnit
  expose shaper
  use strict arg unit
  clauses = .SlamClauses~build(unit~tokens)
  if clauses~items == 0 then return .array~new
  ctx = shaper~unitContext(clauses)
  stmts = .SlamParser~new(clauses)~parseSeq(.false)
  return self~segmentSeq(stmts, ctx, .true)
::method segmentSeq
  expose shaper
  use strict arg stmts, ctx, unitLevel
  segs = .array~new
  run = .SlamRun~new
  entryPhase = unitLevel
  do s over stmts
    if s~kind == 'SIMPLE' then do
      c = s~clause
      cls = shaper~clauseClass(c)
      if cls == 'ENTRY' then if \entryPhase then cls = 'PLAIN'
      if cls \== 'ENTRY' then entryPhase = .false
      select
        when cls == 'ENTRY' then do
          if run~kind \== 'ENTRY' then run = self~flush(run, segs, ctx)
          run~kind = 'ENTRY'
          run~add(c)
        end
        when cls == 'PLAIN' then do
          vars = shaper~varsOf(c)
          if run~kind \== 'RUN' then run = self~flush(run, segs, ctx)
          else if \run~shares(vars) then run = self~flush(run, segs, ctx)
          run~kind = 'RUN'
          run~add(c, vars)
        end
        otherwise do
          run = self~flush(run, segs, ctx)
          kind = 'EXIT'
          if cls == 'TRAP' then kind = 'TRAP'
          segs~append(self~leaf(kind, .array~of(c), ctx))
        end
      end
      iterate
    end
    entryPhase = .false
    run = self~flush(run, segs, ctx)
    select
      when s~kind == 'IF' then segs~append(self~ifSegment(s, ctx))
      when s~kind == 'DO' then segs~append(self~doSegment(s, ctx))
      when s~kind == 'SELECT' then segs~append(self~selectSegment(s, ctx))
      when s~kind == 'LABEL' then segs~append(self~leaf('LABEL', .array~of(s~clause), ctx))
      otherwise do
        extra = self~otherSegment(s, ctx)
        if extra \== .nil then segs~append(extra)
      end
    end
  end
  run = self~flush(run, segs, ctx)
  return self~collapse(segs)
/* A statement kind the ooRexx reader never makes (another language's reader adds its own): no segment. */
::method otherSegment
  use strict arg s, ctx
  return .nil
::method flush
  use strict arg run, segs, ctx
  if run~isEmpty then return run
  segs~append(self~leaf(run~kind, run~clauses, ctx))
  return .SlamRun~new
/* A leaf segment: role-renamed clauses, consecutive same-shape clauses collapsed to one marked "+". */
::method leaf
  expose shaper
  use strict arg kind, clauses, ctx
  roles = .SlamRoles~new(ctx['ARGS'], ctx['FIELDS'])
  famRoles = .SlamRoles~new(ctx['ARGS'], ctx['FIELDS'])
  parts = .array~new
  famParts = .array~new
  i = 1
  do while i <= clauses~items
    c = clauses[i]
    key = shaper~clauseKey(c, ctx)
    j = i + 1
    do while j <= clauses~items
      if shaper~clauseKey(clauses[j], ctx) \== key then leave
      j += 1
    end
    if j - i > 1 then do
      parts~append(shaper~render(c, roles, 'FAMILY') '+')
      famParts~append(shaper~render(c, famRoles, 'FAMILY') '+')
    end
    else do
      parts~append(shaper~render(c, roles, 'FINE'))
      famParts~append(shaper~render(c, famRoles, 'FAMILY'))
    end
    i = j
  end
  seg = .SlamSegment~new(kind, clauses[1][1]~line)
  seg~fine = kind || ': ' || parts~makeString('L', ' ; ')
  seg~family = kind || ': ' || famParts~makeString('L', ' ; ')
  seg~binding = roles~binding
  return seg
/* Statement -> the statement sequence it stands for (a bare DO ... END is its body). */
::method asSeq
  use strict arg stmt
  if stmt == .nil then return .array~new
  if stmt~kind == 'DO' then if stmt~clause~items == 1 then return stmt~body
  return .array~of(stmt)
::method ifSegment
  expose shaper
  use strict arg s, ctx
  thenS = s~thenStmt
  elseS = s~elseStmt
  if elseS == .nil then if thenS \== .nil then if thenS~kind == 'SIMPLE' then if shaper~clauseClass(thenS~clause) == 'TERM' then
    return self~leaf('GUARD', .array~of(s~clause, thenS~clause), ctx)
  seg = .SlamSegment~new('BRANCH', s~clause[1]~line)
  seg~addSequence('THEN', self~segmentSeq(self~asSeq(thenS), ctx, .false))
  if elseS \== .nil then seg~addSequence('ELSE', self~segmentSeq(self~asSeq(elseS), ctx, .false))
  self~composite(seg, .array~of(s~clause), ctx)
  return seg
::method doSegment
  use strict arg s, ctx
  kind = 'LOOP'
  if s~clause~items == 1 then kind = 'BLOCK'
  seg = .SlamSegment~new(kind, s~clause[1]~line)
  seg~addSequence(kind, self~segmentSeq(s~body, ctx, .false))
  self~composite(seg, .array~of(s~clause), ctx)
  return seg
::method selectSegment
  use strict arg s, ctx
  seg = .SlamSegment~new('SELECT', s~clause[1]~line)
  arms = .array~new
  do arm over s~arms
    a = .SlamSegment~new('ARM', arm~clause[1]~line)
    if arm~kind == 'WHEN' then a~addSequence('ARM', self~segmentSeq(self~asSeq(arm~thenStmt), ctx, .false))
    else a~addSequence('ARM', self~segmentSeq(arm~body, ctx, .false))
    self~composite(a, .array~of(arm~clause), ctx)
    arms~append(a)
  end
  seg~addSequence('SELECT', arms)
  /* A SELECT is identified by its arms' conditions (shared roles, repeats collapsed), not only by the
     kinds of its arms: arm kinds alone made every SELECT in the estate one of two nodes. */
  header = .array~of(s~clause)
  do arm over s~arms
    header~append(arm~clause)
  end
  self~composite(seg, header, ctx)
  return seg
/* Composite identity: own header shape plus the KIND sequence of each child sequence. */
::method composite
  expose shaper
  use strict arg seg, headerClauses, ctx
  roles = .SlamRoles~new(ctx['ARGS'], ctx['FIELDS'])
  famRoles = .SlamRoles~new(ctx['ARGS'], ctx['FIELDS'])
  head = .array~new
  famHead = .array~new
  i = 1
  do while i <= headerClauses~items
    c = headerClauses[i]
    key = shaper~clauseKey(c, ctx)
    j = i + 1
    do while j <= headerClauses~items
      if shaper~clauseKey(headerClauses[j], ctx) \== key then leave
      j += 1
    end
    if j - i > 1 then do
      head~append(shaper~render(c, roles, 'FAMILY') '+')
      famHead~append(shaper~render(c, famRoles, 'FAMILY') '+')
    end
    else do
      head~append(shaper~render(c, roles, 'FINE'))
      famHead~append(shaper~render(c, famRoles, 'FAMILY'))
    end
    i = j
  end
  inner = .array~new
  do sq over seg~sequences
    kinds = .array~new
    prev = ''
    do child over sq[2]
      k = child~kind
      if child~repeat > 1 then k = k || '+'
      if k == prev then do
        if kinds[kinds~items]~right(1) \== '+' then kinds[kinds~items] = k || '+'
        iterate
      end
      kinds~append(k)
      prev = k
    end
    inner~append(sq[1] || '=' || kinds~makeString('L', ','))
  end
  tail = ' {' || inner~makeString('L', ' ') || '}'
  seg~fine = seg~kind || ': ' || head~makeString('L', ' ; ') || tail
  seg~family = seg~kind || ': ' || famHead~makeString('L', ' ; ') || tail
  seg~binding = roles~binding
/* Consecutive siblings with the same fine shape become one segment with a repeat count. */
::method collapse
  use strict arg segs
  out = .array~new
  do s over segs
    if out~items > 0 then do
      last = out[out~items]
      if last~fine == s~fine then do
        last~repeat = last~repeat + s~repeat
        iterate
      end
    end
    out~append(s)
  end
  return out
