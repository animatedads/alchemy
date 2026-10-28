/* SlamNetRexx.cls - SLAM's fourth language: NetRexx, the other object-oriented Rexx.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 * NetRexx is Rexx, so the lexer here makes Rexx-shaped tokens (symbols in upper case, strings without
 * their quotes, SEP between clauses) and the ooRexx clause builder, parser, shaper and segmenter read
 * them unchanged. Where the two Rexxes write the same thing differently, the lexer writes it the ooRexx
 * way, and says so here:
 *   NetRexx                         read as (ooRexx)
 *   a.b(x)   member access          a~b(x)
 *   this                            self
 *   null                            .nil
 *   x = a -  (trailing '-')         a line continuation, as a trailing ',' is in ooRexx
 *   -- comment, /* nested */        comments
 *   method m(a=int, b, c=-1)        unit M, with a first clause USE ARG A, B, C = -1 (the entry, as in
 *                                   ooRexx: a default value stays; a declared type is kept on the unit,
 *                                   not in the shape)
 *   properties ... x = int 0        fields of the class (F roles), as EXPOSE names are in ooRexx
 *   loop ...                        DO <LOOP> ..., as the rx2cpp lexer writes ooRexx 5's LOOP
 * A program with code before its first method (a NetRexx script) has that code as its PROLOGUE unit.
 * Not read yet: catch / finally inside do and loop (plain clauses for now).
 *
 * Alchemy rules kept: no private methods, expose first, no variable named result, nested IF instead of
 * relying on & short-circuit, no labels inside loops.
 */

::requires 'SlamSegmenter.cls'
::requires 'SlamJava.cls'

/* ------------------------------------------------------------------------------------------------ */
::class SlamNrxLexer public
::attribute src
::method init
  expose src
  use strict arg src
::method scan
  expose src
  out = .array~new
  n = src~length
  letters = xrange('a', 'z') || xrange('A', 'Z') || '_$'
  idChars = letters || '0123456789'
  ops3 = '\== >>= <<='
  ops2 = '\= == <> >< <= >= \< \> || && // ** << >>'
  i = 1
  line = 1
  lineStart = 1
  do while i <= n
    ch = src~subchar(i)
    col = i - lineStart + 1
    if ch == '0a'x then do
      call newline out, line, col
      line += 1
      lineStart = i + 1
      i += 1
      iterate
    end
    if pos(ch, ' ' || '09'x || '0d'x || '0c'x) > 0 then do
      i += 1
      iterate
    end
    nx = ''
    if i < n then nx = src~subchar(i + 1)
    if ch == '-' then if nx == '-' then do
      k = src~pos('0a'x, i)
      if k == 0 then i = n + 1
      else i = k
      iterate
    end
    if ch == '/' then if nx == '*' then do
      /* nested block comment */
      depth = 1
      k = i + 2
      do while k <= n
        if src~substr(k, 2) == '/*' then do
          depth += 1
          k += 2
          iterate
        end
        if src~substr(k, 2) == '*/' then do
          depth -= 1
          k += 2
          if depth == 0 then leave
          iterate
        end
        if src~subchar(k) == '0a'x then do
          line += 1
          lineStart = k + 1
        end
        k += 1
      end
      i = k
      iterate
    end
    if ch == ';' then do
      call sep out, line, col
      i += 1
      iterate
    end
    if ch == '"' | ch == "'" then do
      /* a doubled quote is the quote itself */
      v = ''
      k = i + 1
      do forever
        e = src~pos(ch, k)
        if e == 0 then do
          v = v || src~substr(k)
          k = n + 1
          leave
        end
        v = v || src~substr(k, e - k)
        if src~subchar(e + 1) == ch then do
          v = v || ch
          k = e + 2
          iterate
        end
        k = e + 1
        leave
      end
      out~append(.SlamJToken~new('STRING', v, line, col, line, col + k - i))
      i = k
      iterate
    end
    isNumber = datatype(ch, 'W')
    if ch == '.' then if datatype(nx, 'W') then isNumber = .true
    if isNumber then do
      k = verify(src, '0123456789.', 'N', i + 1)
      if k == 0 then k = n + 1
      if k <= n then if pos(src~subchar(k), 'eE') > 0 then do
        m = k + 1
        if pos(src~subchar(m), '+-') > 0 then m += 1
        if datatype(src~subchar(m), 'W') then do
          k = verify(src, '0123456789', 'N', m)
          if k == 0 then k = n + 1
        end
      end
      out~append(.SlamJToken~new('NUMBER', src~substr(i, k - i), line, col, line, col + k - i))
      i = k
      iterate
    end
    if pos(ch, letters) > 0 then do
      k = verify(src, idChars, 'N', i)
      if k == 0 then k = n + 1
      word = src~substr(i, k - i)~upper
      atStart = .true
      if out~items > 0 then if out[out~items]~kind \== 'SEP' then if wordpos(out[out~items]~text, 'THEN ELSE OTHERWISE') == 0 then atStart = .false
      isLoop = .false
      if word == 'LOOP' then if atStart then if wordpos(src~substr(k)~strip('L')~left(1), '= ( ~ ,') == 0 then isLoop = .true
      select
        when isLoop then do
          /* as the rx2cpp lexer writes ooRexx 5's LOOP: DO and the marker <LOOP> */
          out~append(.SlamJToken~new('IDENT', 'DO', line, col, line, col + k - i))
          out~append(.SlamJToken~new('IDENT', '<LOOP>', line, col, line, col + k - i))
        end
        when word == 'THIS' then out~append(.SlamJToken~new('IDENT', 'SELF', line, col, line, col + k - i))
        when word == 'NULL' then out~append(.SlamJToken~new('DOTIDENT', 'NIL', line, col, line, col + k - i))
        otherwise out~append(.SlamJToken~new('IDENT', word, line, col, line, col + k - i))
      end
      i = k
      iterate
    end
    /* member access: a '.' after a name, ')' or ']' and before a name is ooRexx's '~' */
    if ch == '.' then if out~items > 0 then if pos(nx, letters) > 0 then do
      p = out[out~items]
      if p~kind == 'IDENT' | p~text == ')' | p~text == ']' then do
        out~append(.SlamJToken~new('OP', '~', line, col, line, col + 1))
        i += 1
        iterate
      end
    end
    three = src~substr(i, 3)
    if wordpos(three, ops3) > 0 then do
      out~append(.SlamJToken~new('OP', three, line, col, line, col + 3))
      i += 3
      iterate
    end
    two = src~substr(i, 2)
    if wordpos(two, ops2) > 0 then do
      out~append(.SlamJToken~new('OP', two, line, col, line, col + 2))
      i += 2
      iterate
    end
    out~append(.SlamJToken~new('OP', ch, line, col, line, col + 1))
    i += 1
  end
  call sep out, line, 1
  out~append(.SlamJToken~new('EOF', '<eof>', line, 1, line, 1))
  return out

/* A line end: a clause separator, unless the line ended with '-' (a continuation). */
::routine newline
  use arg out, line, col
  if out~items > 0 then do
    last = out[out~items]
    if last~kind == 'OP' then if last~text == '-' then do
      out~delete(out~items)
      return
    end
  end
  call sep out, line, col
  return
::routine sep
  use arg out, line, col
  if out~items == 0 then return
  if out[out~items]~kind == 'SEP' then return
  out~append(.SlamJToken~new('SEP', ';', line, col, line, col + 1))
  return

/* ------------------------------------------------------------------------------------------------ */
::class SlamNrxUnit public subclass SlamUnit
::attribute fields
::attribute types         /* argument name -> declared type text */
::attribute returns
::method init
  expose fields types returns
  use strict arg kind, owner, selector, line
  self~init:super(kind, owner, selector, line)
  fields = .directory~new
  types = .directory~new
  returns = ''

/* Units from NetRexx clauses. CLASS sets the owner; METHOD starts a unit; PROPERTIES starts a section
 * whose assignments name fields; IMPORT, PACKAGE and OPTIONS are skipped. */
::class SlamNrxSplitter public
::method split
  use strict arg text
  toks = .SlamNrxLexer~new(text)~scan
  units = .array~new
  owner = ''
  classUnits = .array~new
  fields = .directory~new
  cur = .SlamNrxUnit~new('PROLOGUE', '', '', 1)
  inProps = .false
  clause = .array~new
  do t over toks
    if t~kind == 'EOF' then leave
    if t~kind \== 'SEP' then do
      clause~append(t)
      iterate
    end
    if clause~items == 0 then iterate
    first = ''
    if clause[1]~kind == 'IDENT' then first = clause[1]~text
    second = ''
    if clause~items > 1 then second = clause[2]~text
    isDirective = .false
    if wordpos(first, 'CLASS METHOD PROPERTIES IMPORT PACKAGE OPTIONS') > 0 then if wordpos(second, '= += -=') == 0 then isDirective = .true
    if \isDirective then do
      if inProps then do
        /* a property: name = type [value] or name = value */
        if clause[1]~kind == 'IDENT' then fields[clause[1]~text] = .true
      end
      else do
        do x over clause; cur~tokens~append(x); end
        cur~tokens~append(t)
      end
      clause = .array~new
      iterate
    end
    select
      when first == 'CLASS' then do
        if cur~codeTokenCount > 0 then units~append(cur)
        do u over classUnits; u~fields = fields; end
        classUnits = .array~new
        fields = .directory~new
        owner = second
        cur = .SlamNrxUnit~new('PROLOGUE', owner, '', clause[1]~line)
        inProps = .false
      end
      when first == 'METHOD' then do
        if cur~codeTokenCount > 0 then units~append(cur)
        cur = self~methodUnit(owner, clause)
        classUnits~append(cur)
        inProps = .false
      end
      when first == 'PROPERTIES' then inProps = .true
      otherwise nop
    end
    clause = .array~new
  end
  if cur~codeTokenCount > 0 then units~append(cur)
  do u over classUnits; u~fields = fields; end
  return units
/* METHOD name ( a = type , b ) [RETURNS type] [modifiers]: the unit, starting with USE ARG a, b. */
::method methodUnit
  use strict arg owner, clause
  name = ''
  if clause~items > 1 then name = clause[2]~text
  u = .SlamNrxUnit~new('METHOD', owner, name, clause[1]~line)
  args = .array~new
  if clause~items > 2 then if clause[3]~text == '(' then do
    depth = 0
    seg = .array~new
    do k = 4 to clause~items
      t = clause[k]
      if t~text == '(' then depth += 1
      if t~text == ')' then do
        if depth == 0 then do
          if seg~items > 0 then args~append(seg)
          leave
        end
        depth -= 1
      end
      if t~text == ',' then if depth == 0 then do
        args~append(seg)
        seg = .array~new
        iterate
      end
      seg~append(t)
    end
  end
  do k = 1 to clause~items - 1
    if clause[k]~text == 'RETURNS' then u~returns = clause[k + 1]~text
  end
  if args~items == 0 then return u
  line = clause[1]~line
  u~tokens~append(.SlamJToken~new('IDENT', 'USE', line, 1, line, 4))
  u~tokens~append(.SlamJToken~new('IDENT', 'ARG', line, 5, line, 8))
  do k = 1 to args~items
    a = args[k]
    if k > 1 then u~tokens~append(.SlamJToken~new('OP', ',', line, 9, line, 10))
    u~tokens~append(a[1])
    /* a = literal is a default value, kept as ooRexx's USE ARG a = literal is; a = type is kept on the
       unit, not in the shape */
    if a~items > 2 then if a[2]~text == '=' then do
      isLiteral = .false
      if a[3]~kind == 'STRING' | a[3]~kind == 'NUMBER' then isLiteral = .true
      if a~items > 3 then if a[3]~text == '-' then if a[4]~kind == 'NUMBER' then isLiteral = .true
      if isLiteral then do
        do m = 2 to a~items; u~tokens~append(a[m]); end
      end
      else do
        typ = ''
        do m = 3 to a~items; typ = typ a[m]~text; end
        u~types[a[1]~text] = typ~strip
      end
    end
  end
  u~tokens~append(.SlamJToken~new('SEP', ';', line, 1, line, 2))
  return u

/* The ooRexx segmenter, with a NetRexx unit's fields as F roles (no EXPOSE in NetRexx). */
::class SlamNrxSegmenter public subclass SlamSegmenter
::method segmentUnit
  use strict arg unit
  clauses = .SlamClauses~build(unit~tokens)
  if clauses~items == 0 then return .array~new
  sh = self~shaper
  ctx = sh~unitContext(clauses)
  do f over unit~fields~allIndexes
    if \ctx['ARGS']~hasIndex(f) then ctx['FIELDS'][f] = .true
  end
  stmts = .SlamParser~new(clauses)~parseSeq(.false)
  return self~segmentSeq(stmts, ctx, .true)
