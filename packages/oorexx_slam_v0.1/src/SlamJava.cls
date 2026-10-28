/* SlamJava.cls - SLAM's second language: read Java into the same nodes and edges as ooRexx.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 * Only the parts that depend on the language are here: a Java lexer, a unit splitter (methods,
 * constructors, initializer blocks, by class), a statement parser, and a shaper (what each token is).
 * They produce the same SlamStmt trees and SlamSegment kinds as the ooRexx reader, so the segmenter's
 * leaf / composite / collapse code, the store, the edge weights and Task run unchanged.
 *
 * How Java maps onto SLAM's kinds:
 *   ENTRY   the parameter list (Java has no USE ARG; the declaration is the entry)
 *   RUN     straight-line statements that share data
 *   GUARD   if (c) return|throw|break|continue|yield ...; with no else (a { } around the one
 *           statement means the same thing and is unwrapped)
 *   BRANCH  if / else;  LOOP  for, enhanced for, while, do-while;  BLOCK  { } and synchronized (x) { }
 *   SELECT  switch, each case or default an ARM (the switch header plus every case label is its header)
 *   TRY     try / catch / finally (Java's own kind: ooRexx has SIGNAL ON instead, a TRAP leaf)
 *   EXIT    return, throw, break, continue, yield;  LABEL  name:
 * Shapes, as in ooRexx: parameters A1.., fields F1.., locals L1..; strings and chars S; numbers N.
 * true, false and null render .true .false .nil, as ooRexx's .true .false .nil do. FINE keeps member,
 * method and class names; FAMILY abstracts them to M, F and .C.
 *
 * Alchemy rules kept: no private methods, expose first, no variable named result, nested IF instead
 * of relying on & short-circuit, no labels inside loops.
 */

::requires 'SlamSegmenter.cls'

/* ------------------------------------------------------------------------------------------------ */
::class SlamJToken public
::attribute kind
::attribute text
::attribute line
::attribute col
::attribute endLine
::attribute endCol
::method init
  expose kind text line col endLine endCol
  use strict arg kind, text, line, col, endLine, endCol

/* ------------------------------------------------------------------------------------------------ */
/* Kinds: IDENT, KEYWORD, NUMBER, STRING (strings, chars, text blocks), ANNOT (@Name), OP. Comments
 * and layout are dropped. '>' is always one token, so List<List<X>> closes as two '>' tokens. */
::class SlamJavaLexer public
::constant KEYWORDS 'abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public return short static strictfp super switch synchronized this throw throws transient try void volatile while true false null'
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
  ws = ' ' || '09'x || '0a'x || '0d'x || '0c'x
  ops2 = '-> :: ++ -- && || == != <= >= += -= *= /= %= &= |= ^= <<'
  i = 1
  line = 1
  lineStart = 1
  do while i <= n
    j = verify(src, ws, 'N', i)
    if j == 0 then leave
    if j > i then do
      chunk = src~substr(i, j - i)
      nl = chunk~countStr('0a'x)
      if nl > 0 then do
        line += nl
        lineStart = i + chunk~lastPos('0a'x)
      end
      i = j
    end
    ch = src~subchar(i)
    col = i - lineStart + 1
    nx = ''
    if i < n then nx = src~subchar(i + 1)
    if ch == '/' then do
      if nx == '/' then do
        k = src~pos('0a'x, i)
        if k == 0 then i = n + 1
        else i = k
        iterate
      end
      if nx == '*' then do
        k = src~pos('*/', i + 2)
        if k == 0 then k = n - 1
        chunk = src~substr(i, k + 2 - i)
        nl = chunk~countStr('0a'x)
        if nl > 0 then do
          line += nl
          lineStart = i + chunk~lastPos('0a'x)
        end
        i = k + 2
        iterate
      end
    end
    if ch == '"' then do
      if src~substr(i, 3) == '"""' then do
        k = src~pos('"""', i + 3)
        if k == 0 then k = n - 2
        chunk = src~substr(i, k + 3 - i)
        nl = chunk~countStr('0a'x)
        out~append(.SlamJToken~new('STRING', chunk, line, col, line + nl, col))
        if nl > 0 then do
          line += nl
          lineStart = i + chunk~lastPos('0a'x)
        end
        i = k + 3
        iterate
      end
      k = self~quoteEnd(i, '"')
      out~append(.SlamJToken~new('STRING', src~substr(i, k + 1 - i), line, col, line, col + k + 1 - i))
      i = k + 1
      iterate
    end
    if ch == "'" then do
      k = self~quoteEnd(i, "'")
      out~append(.SlamJToken~new('STRING', src~substr(i, k + 1 - i), line, col, line, col + k + 1 - i))
      i = k + 1
      iterate
    end
    isNumber = datatype(ch, 'W')
    if ch == '.' then if datatype(nx, 'W') then isNumber = .true
    if isNumber then do
      k = verify(src, idChars || '.', 'N', i + 1)
      if k == 0 then k = n + 1
      /* an exponent sign: 1e-5, 2.5E+3 (not in hex, where e is a digit) */
      if k <= n then if pos(src~subchar(k), '+-') > 0 then if pos(src~subchar(k - 1), 'eE') > 0 then if src~substr(i, 2)~lower \== '0x' then do
        k = verify(src, idChars || '.', 'N', k + 1)
        if k == 0 then k = n + 1
      end
      out~append(.SlamJToken~new('NUMBER', src~substr(i, k - i), line, col, line, col + k - i))
      i = k
      iterate
    end
    if pos(ch, letters) > 0 then do
      k = verify(src, idChars, 'N', i)
      if k == 0 then k = n + 1
      word = src~substr(i, k - i)
      kind = 'IDENT'
      if wordpos(word, self~KEYWORDS) > 0 then kind = 'KEYWORD'
      out~append(.SlamJToken~new(kind, word, line, col, line, col + k - i))
      i = k
      iterate
    end
    if ch == '@' then if pos(nx, letters) > 0 then do
      k = verify(src, idChars, 'N', i + 1)
      if k == 0 then k = n + 1
      out~append(.SlamJToken~new('ANNOT', src~substr(i, k - i), line, col, line, col + k - i))
      i = k
      iterate
    end
    if src~substr(i, 3) == '...' | src~substr(i, 3) == '<<=' then do
      out~append(.SlamJToken~new('OP', src~substr(i, 3), line, col, line, col + 3))
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
  return out
/* Position of the closing quote of a string or char literal starting at i (a backslash escapes). */
::method quoteEnd
  expose src
  use strict arg i, q
  k = i + 1
  do forever
    e = src~pos(q, k)
    if e == 0 then return src~length
    b = src~pos('\', k)
    if b == 0 then return e
    if b > e then return e
    k = b + 2
  end

/* ------------------------------------------------------------------------------------------------ */
/* Matching bracket positions for ( ) [ ] { } over a token array (generics' < > are not brackets). */
::class SlamJavaMatch public
::method build class
  use strict arg toks
  match = .array~new(toks~items)
  stack = .array~new
  do i = 1 to toks~items
    t = toks[i]
    if t~kind \== 'OP' then iterate
    if pos(t~text, '([{') > 0 then do
      stack~append(i)
      iterate
    end
    if pos(t~text, ')]}') > 0 then do
      if stack~items == 0 then iterate
      j = stack[stack~items]
      stack~delete(stack~items)
      match[j] = i
      match[i] = j
    end
  end
  /* unclosed brackets close at the end, so every walk still advances */
  do j over stack
    match[j] = toks~items
  end
  return match

/* ------------------------------------------------------------------------------------------------ */
/* A Java code unit: the body tokens (between the braces), the parameter tokens, and the fields of
 * its class. */
::class SlamJavaUnit public subclass SlamUnit
::attribute params
::attribute fields
::attribute returns
::method init
  expose params fields returns
  use strict arg kind, owner, selector, line
  self~init:super(kind, owner, selector, line)
  params = .array~new
  fields = .directory~new
  returns = ''
/* Duplicate filter: the parameter tokens count too, so int f(int a) and long f(long a) differ. */
::method signature
  expose params
  buf = .mutablebuffer~new
  do t over params
    buf~append(t~kind~left(1))
    buf~append(t~text)
    buf~append('1f'x)
  end
  buf~append('1e'x)
  buf~append(self~signature:super)
  return buf~string
::method codeTokenCount
  return self~tokens~items

/* ------------------------------------------------------------------------------------------------ */
/* Units from type bodies. A class, interface, enum or record sets the owner (Outer.Inner when nested);
 * a member with a parameter list and a body is a METHOD (CTOR when named after its class); a bare
 * or static block is INIT. Field names are collected per type, so A1 / F1 / L1 roles work as in ooRexx.
 * Lambdas, anonymous classes and local classes stay inside the statement that holds them. */
::class SlamJavaSplitter public
::attribute toks
::attribute match
::attribute units
::method split
  expose toks match units
  use strict arg text
  toks = .SlamJavaLexer~new(text)~scan
  match = .SlamJavaMatch~build(toks)
  units = .array~new
  self~members('', 1, toks~items + 1, .false, .directory~new)
  return units
::method isTypeWord
  use strict arg t, nx
  if t~kind == 'KEYWORD' then if wordpos(t~text, 'class interface enum') > 0 then return .true
  if t~kind == 'IDENT' then if t~text == 'record' then if nx \== .nil then if nx~kind == 'IDENT' then return .true
  return .false
/* Members of one type body, tokens from .. to-1. */
::method members
  expose toks match units
  use strict arg owner, from, upto, isEnum, fields
  mine = .array~new
  i = from
  if isEnum then i = self~skipEnumConstants(from, upto)
  do while i < upto
    t = toks[i]
    if t~kind == 'OP' then if t~text == ';' then do
      i += 1
      iterate
    end
    header = .array~new
    j = i
    stop = ''
    hasAssign = .false
    hasParen = .false
    do while j < upto
      tj = toks[j]
      if tj~kind == 'ANNOT' then do
        j = self~skipAnnotation(j, upto)
        iterate
      end
      if tj~kind == 'OP' then do
        if tj~text == ';' then do
          stop = ';'
          leave
        end
        if tj~text == '{' then do
          if \hasAssign then do
            stop = '{'
            leave
          end
          /* an initializer's array literal, lambda body or anonymous class: part of the field */
          do k = j to match[j]
            header~append(toks[k])
          end
          j = match[j] + 1
          iterate
        end
        if tj~text == '(' | tj~text == '[' then do
          if tj~text == '(' then if \hasAssign then hasParen = .true
          do k = j to match[j]
            header~append(toks[k])
          end
          j = match[j] + 1
          iterate
        end
        if tj~text == '=' then if \hasParen then hasAssign = .true
      end
      header~append(tj)
      j += 1
    end
    if stop == '' then leave
    if stop == ';' then do
      if header~items > 0 then do
        first = header[1]~text
        if wordpos(first, 'package import') == 0 then if \hasParen then self~fieldNames(header, fields)
      end
      i = j + 1
      iterate
    end
    /* stop == '{' */
    close = match[j]
    typeAt = 0
    do k = 1 to header~items
      nxk = .nil
      if k < header~items then nxk = header[k + 1]
      if self~isTypeWord(header[k], nxk) then do
        typeAt = k
        leave
      end
    end
    select
      when typeAt > 0 then do
        name = ''
        if typeAt < header~items then name = header[typeAt + 1]~text
        inner = name
        if owner \== '' then inner = owner || '.' || name
        innerFields = .directory~new
        if header[typeAt]~text == 'record' then self~recordComponents(header, typeAt, innerFields)
        self~members(inner, j + 1, close, header[typeAt]~text == 'enum', innerFields)
      end
      when hasParen then do
        u = self~methodUnit(owner, header, j, close)
        if u \== .nil then do
          mine~append(u)
          units~append(u)
        end
      end
      otherwise do
        sel = 'init'
        if header~items > 0 then if header[1]~text == 'static' then sel = 'static'
        u = .SlamJavaUnit~new('INIT', owner, sel, toks[j]~line)
        do k = j + 1 to close - 1
          u~tokens~append(toks[k])
        end
        if u~tokens~items > 0 then do
          mine~append(u)
          units~append(u)
        end
      end
    end
    i = close + 1
  end
  do u over mine
    u~fields = fields
  end
::method skipAnnotation
  expose toks match
  use strict arg j, upto
  j += 1
  do while j + 1 < upto
    if toks[j]~kind \== 'OP' then leave
    if toks[j]~text \== '.' then leave
    j += 2
  end
  if j < upto then if toks[j]~kind == 'OP' then if toks[j]~text == '(' then j = match[j] + 1
  return j
/* Enum constants (with their arguments and bodies) up to the first ';' at this level. */
::method skipEnumConstants
  expose toks match
  use strict arg from, upto
  j = from
  do while j < upto
    t = toks[j]
    if t~kind == 'OP' then do
      if t~text == ';' then return j + 1
      if pos(t~text, '({[') > 0 then do
        j = match[j] + 1
        iterate
      end
    end
    j += 1
  end
  return upto
/* Field declarators: the name before '=', ',' or the end, outside generics and initializers. */
::method fieldNames
  use strict arg header, fields
  angle = 0
  depth = 0
  inInit = .false
  do k = 1 to header~items
    t = header[k]
    if t~kind == 'OP' then do
      if pos(t~text, '([{') > 0 then depth += 1
      if pos(t~text, ')]}') > 0 then depth -= 1
    end
    if inInit then do
      if depth == 0 then if t~kind == 'OP' then if t~text == ',' then inInit = .false
      iterate
    end
    if t~kind == 'OP' then do
      if t~text == '<' then angle += 1
      if t~text == '>' then angle -= 1
      if t~text == '=' then inInit = .true
      iterate
    end
    if t~kind \== 'IDENT' then iterate
    if angle > 0 then iterate
    if depth > 0 then iterate
    if k == header~items then do
      fields[t~text] = .true
      iterate
    end
    nx = header[k + 1]
    if nx~kind == 'OP' then if wordpos(nx~text, '= , [') > 0 then fields[t~text] = .true
  end
::method recordComponents
  use strict arg header, typeAt, fields
  do k = typeAt + 1 to header~items
    if header[k]~kind == 'OP' then if header[k]~text == '(' then do
      do n over self~paramNames(header, k)
        fields[n] = .true
      end
      return
    end
  end
/* Names in a parameter list that opens at header[open]: the identifier before each ',' or ')' at
 * depth 0 (generic angles count as depth). */
::method paramNames
  use strict arg header, open
  names = .array~new
  depth = 0
  angle = 0
  do k = open + 1 to header~items
    t = header[k]
    if t~kind == 'OP' then do
      if t~text == '<' then angle += 1
      if t~text == '>' then angle -= 1
      if pos(t~text, '([{') > 0 then depth += 1
      if pos(t~text, ')]}') > 0 then do
        if depth == 0 then do
          if k > open + 1 then if header[k - 1]~kind == 'IDENT' then names~append(header[k - 1]~text)
          return names
        end
        depth -= 1
      end
      if t~text == ',' then if depth == 0 then if angle == 0 then if header[k - 1]~kind == 'IDENT' then names~append(header[k - 1]~text)
    end
  end
  return names
::method methodUnit
  expose toks
  use strict arg owner, header, j, close
  open = 0
  do k = 1 to header~items
    if header[k]~kind == 'OP' then if header[k]~text == '(' then do
      open = k
      leave
    end
  end
  if open < 2 then return .nil
  name = header[open - 1]~text
  simpleOwner = owner
  if owner~pos('.') > 0 then simpleOwner = owner~substr(owner~lastPos('.') + 1)
  kind = 'METHOD'
  if name == simpleOwner then kind = 'CTOR'
  u = .SlamJavaUnit~new(kind, owner, name, header[open - 1]~line)
  /* parameters: the tokens between the parentheses */
  depth = 0
  do k = open + 1 to header~items
    t = header[k]
    if t~kind == 'OP' then do
      if t~text == '(' then depth += 1
      if t~text == ')' then do
        if depth == 0 then leave
        depth -= 1
      end
    end
    if t~kind \== 'ANNOT' then u~params~append(t)
  end
  /* the declared return type: the tokens between the modifiers and the name */
  ret = .array~new
  do k = 1 to open - 2
    t = header[k]
    if t~kind == 'KEYWORD' then if wordpos(t~text, 'public protected private static final abstract synchronized native strictfp default') > 0 then iterate
    if t~kind == 'IDENT' then if t~text == 'sealed' then iterate
    ret~append(t~text)
  end
  u~returns = ret~makeString('L', ' ')
  do k = j + 1 to close - 1
    u~tokens~append(toks[k])
  end
  return u

/* ------------------------------------------------------------------------------------------------ */
/* Java statements -> SlamStmt trees (kinds IF, DO, SELECT, SIMPLE, LABEL, plus TRY and BLOCKH, which
 * the Java segmenter cuts). A clause never includes its ';'. Every path advances. */
::class SlamJavaParser public
::attribute toks
::attribute match
::attribute pos
::method init
  expose toks match pos
  use strict arg toks
  match = .SlamJavaMatch~build(toks)
  pos = 1
::method isKw
  expose toks
  use strict arg at, words
  if at > toks~items then return .false
  t = toks[at]
  if t~kind \== 'KEYWORD' then return .false
  return wordpos(t~text, words) > 0
::method isOp
  expose toks
  use strict arg at, text
  if at > toks~items then return .false
  t = toks[at]
  if t~kind \== 'OP' then return .false
  return t~text == text
::method slice
  expose toks
  use strict arg from, upto
  out = .array~new
  do k = from to upto
    if toks[k]~kind \== 'ANNOT' then out~append(toks[k])
  end
  return out
::method parseSeq
  expose pos
  use strict arg endPos
  seq = .array~new
  do while pos < endPos
    s = self~parseStmt(endPos)
    if s \== .nil then seq~append(s)
  end
  return seq
/* A statement's statements: a bare { } is its body, anything else is itself. */
::method asSeqOf
  use strict arg s
  if s == .nil then return .array~new
  if s~kind == 'DO' then if s~clause~items == 1 then return s~body
  return .array~of(s)
/* { one statement } after if / else means that statement. */
::method unwrap
  use strict arg s
  if s == .nil then return .nil
  if s~kind == 'DO' then if s~clause~items == 1 then if s~body~items == 1 then return s~body[1]
  return s
/* Header 'kw ( ... )' starting at pos: the tokens and the position after ')'. */
::method parenHeader
  expose toks match pos
  use strict arg endPos
  first = pos
  k = pos + 1
  if k < endPos then if self~isOp(k, '(') then return self~slice(first, match[k])
  return self~slice(first, first)
::method parseStmt
  expose toks match pos
  use strict arg endPos
  t = toks[pos]
  if t~kind == 'ANNOT' then do
    pos += 1
    if pos < endPos then if self~isOp(pos, '(') then pos = match[pos] + 1
    return .nil
  end
  if t~kind == 'OP' then do
    if t~text == ';' then do
      pos += 1
      return .nil
    end
    if t~text == '{' then do
      s = .SlamStmt~new('DO', .array~of(t))
      close = match[pos]
      pos += 1
      s~body = self~parseSeq(close)
      pos = close + 1
      return s
    end
  end
  if t~kind == 'IDENT' then if self~isOp(pos + 1, ':') then if \self~isOp(pos + 2, ':') then do
    s = .SlamStmt~new('LABEL', self~slice(pos, pos + 1))
    pos += 2
    return s
  end
  if t~kind == 'KEYWORD' then do
    w = t~text
    select
      when w == 'if' then do
        s = .SlamStmt~new('IF', self~parenHeader(endPos))
        pos = self~afterParen(endPos)
        if pos < endPos then s~thenStmt = self~unwrap(self~parseStmt(endPos))
        if pos < endPos then if self~isKw(pos, 'else') then do
          pos += 1
          if pos < endPos then s~elseStmt = self~unwrap(self~parseStmt(endPos))
        end
        return s
      end
      when w == 'for' | w == 'while' then do
        s = .SlamStmt~new('DO', self~parenHeader(endPos))
        pos = self~afterParen(endPos)
        if pos < endPos then s~body = self~asSeqOf(self~parseStmt(endPos))
        return s
      end
      when w == 'do' then do
        head = .array~of(t)
        pos += 1
        bodyStmt = .nil
        if pos < endPos then bodyStmt = self~parseStmt(endPos)
        if pos < endPos then if self~isKw(pos, 'while') then do
          do x over self~parenHeader(endPos)
            head~append(x)
          end
          pos = self~afterParen(endPos)
          if pos < endPos then if self~isOp(pos, ';') then pos += 1
        end
        s = .SlamStmt~new('DO', head)
        s~body = self~asSeqOf(bodyStmt)
        return s
      end
      when w == 'switch' then if self~isOp(pos + 1, '(') then if self~isOp(match[pos + 1] + 1, '{') then do
        s = .SlamStmt~new('SELECT', self~parenHeader(endPos))
        pos = self~afterParen(endPos)
        close = match[pos]
        pos += 1
        self~switchArms(s, close)
        pos = close + 1
        return s
      end
      when w == 'try' then do
        head = .array~of(t)
        pos += 1
        if pos < endPos then if self~isOp(pos, '(') then do
          do x over self~slice(pos, match[pos])
            head~append(x)
          end
          pos = match[pos] + 1
        end
        s = .SlamStmt~new('TRY', head)
        if pos < endPos then s~body = self~asSeqOf(self~parseStmt(endPos))
        do while pos < endPos
          if \self~isKw(pos, 'catch finally') then leave
          if toks[pos]~text == 'catch' then do
            arm = .SlamStmt~new('CATCH', self~parenHeader(endPos))
            pos = self~afterParen(endPos)
          end
          else do
            arm = .SlamStmt~new('FINALLY', .array~of(toks[pos]))
            pos += 1
          end
          if pos < endPos then arm~body = self~asSeqOf(self~parseStmt(endPos))
          s~arms~append(arm)
        end
        return s
      end
      when w == 'synchronized' then if self~isOp(pos + 1, '(') then do
        s = .SlamStmt~new('BLOCKH', self~parenHeader(endPos))
        pos = self~afterParen(endPos)
        if pos < endPos then s~body = self~asSeqOf(self~parseStmt(endPos))
        return s
      end
      when wordpos(w, 'class interface enum') > 0 then do
        /* a local type: its header is one clause; its body is not read as statements */
        first = pos
        do while pos < endPos
          if self~isOp(pos, '{') then leave
          pos += 1
        end
        s = .SlamStmt~new('SIMPLE', self~slice(first, min(pos, endPos) - 1))
        if pos < endPos then pos = match[pos] + 1
        return s
      end
      otherwise nop
    end
  end
  return self~simpleClause(endPos)
::method afterParen
  expose match pos
  use strict arg endPos
  if pos + 1 < endPos then if self~isOp(pos + 1, '(') then return match[pos + 1] + 1
  return pos + 1
/* One statement up to ';' at depth 0; lambdas, anonymous classes, switch expressions and array
 * literals inside it stay in the clause. */
::method simpleClause
  expose toks match pos
  use strict arg endPos
  first = pos
  do while pos < endPos
    t = toks[pos]
    if t~kind == 'OP' then do
      if t~text == ';' then leave
      if pos(t~text, '([{') > 0 then do
        pos = match[pos] + 1
        iterate
      end
    end
    pos += 1
  end
  s = .SlamStmt~new('SIMPLE', self~slice(first, min(pos, endPos) - 1))
  pos += 1
  if s~clause~items == 0 then return .nil
  return s
/* case X: / case X -> / default: arms of a switch body that ends at close. */
::method switchArms
  expose toks match pos
  use strict arg s, close
  do while pos < close
    if \self~isKw(pos, 'case default') then do
      st = self~parseStmt(close)
      if st \== .nil then s~body~append(st)
      iterate
    end
    first = pos
    arrow = .false
    do while pos < close
      t = toks[pos]
      if t~kind == 'OP' then do
        if t~text == ':' then leave
        if t~text == '->' then do
          arrow = .true
          leave
        end
        if pos(t~text, '([{') > 0 then do
          pos = match[pos] + 1
          iterate
        end
      end
      pos += 1
    end
    arm = .SlamStmt~new('CASE', self~slice(first, min(pos, close - 1)))
    pos += 1
    if arrow then do
      if pos < close then arm~body = self~asSeqOf(self~parseStmt(close))
    end
    else do
      do while pos < close
        if self~isKw(pos, 'case default') then leave
        st = self~parseStmt(close)
        if st \== .nil then arm~body~append(st)
      end
    end
    s~arms~append(arm)
  end

/* ------------------------------------------------------------------------------------------------ */
/* What each Java token is in its clause, and the clause's shape. Same interface the segmenter uses
 * on the ooRexx shaper: clauseClass, varsOf, clauseKey, render, plus unitContext for a Java unit. */
::class SlamJavaShaper public
::constant TERMS 'return throw break continue'
::attribute current
::method clauseClass
  use strict arg c
  t = c[1]
  if t~kind == 'KEYWORD' then if wordpos(t~text, self~TERMS) > 0 then return 'TERM'
  if t~kind == 'IDENT' then if t~text == 'yield' then do
    if c~items == 1 then return 'TERM'
    if c[2]~kind \== 'OP' then return 'TERM'
    if wordpos(c[2]~text, '= . ( [ ++ -- += -=') == 0 then return 'TERM'
  end
  return 'PLAIN'
/* VAR (a role), MESSAGE (member after . or ::), FUNCTION (a call with no receiver), CLASS, KEYWORD,
 * LITERAL (true false null), SELF (this super), STRING, NUMBER, ANNOT, OP. */
::method tokenRole
  use strict arg c, i, ctx
  t = c[i]
  k = t~kind
  if k == 'STRING' then return 'STRING'
  if k == 'NUMBER' then return 'NUMBER'
  if k == 'ANNOT' then return 'ANNOT'
  if k == 'OP' then return 'OP'
  if k == 'KEYWORD' then do
    if wordpos(t~text, 'true false null') > 0 then return 'LITERAL'
    if t~text == 'this' | t~text == 'super' then return 'SELF'
    return 'KEYWORD'
  end
  name = t~text
  nx = .nil
  if i < c~items then nx = c[i + 1]
  if name == 'var' then if nx \== .nil then if nx~kind == 'IDENT' then return 'KEYWORD'
  if name == 'yield' then if i == 1 then if self~clauseClass(c) == 'TERM' then return 'KEYWORD'
  if i > 1 then do
    p = c[i - 1]
    if p~kind == 'OP' then if p~text == '.' | p~text == '::' then return 'MESSAGE'
    if p~kind == 'KEYWORD' then if p~text == 'new' then return 'CLASS'
  end
  if nx \== .nil then if nx~kind == 'OP' then if nx~text == '(' then return 'FUNCTION'
  if ctx['ARGS']~hasIndex(name) then return 'VAR'
  if ctx['FIELDS']~hasIndex(name) then return 'VAR'
  if name~left(1) >>= 'A' then if name~left(1) <<= 'Z' then return 'CLASS'
  return 'VAR'
::method render
  use strict arg c, roles, mode
  ctx = .directory~new
  ctx['ARGS'] = roles~args
  ctx['FIELDS'] = roles~fields
  out = .array~new
  do i = 1 to c~items
    t = c[i]
    r = self~tokenRole(c, i, ctx)
    select
      when r == 'STRING' then out~append('S')
      when r == 'NUMBER' then out~append('N')
      when r == 'OP' then out~append(t~text)
      when r == 'ANNOT' then nop
      when r == 'LITERAL' then do
        if t~text == 'null' then out~append('.nil')
        else out~append('.' || t~text)
      end
      when r == 'SELF' then out~append(t~text)
      when r == 'KEYWORD' then out~append(t~text)
      when r == 'MESSAGE' then do
        if mode == 'FAMILY' then out~append('M')
        else out~append(t~text~lower)
      end
      when r == 'FUNCTION' then do
        if mode == 'FAMILY' then out~append('F')
        else out~append(t~text~lower)
      end
      when r == 'CLASS' then do
        if mode == 'FAMILY' then out~append('.C')
        else out~append('.' || t~text~lower)
      end
      otherwise out~append(roles~role(t~text))
    end
  end
  return out~makeString('L', ' ')
/* Names a clause reads or writes; this / super count as shared object state (as SELF in ooRexx). */
::method varsOf
  use strict arg c, ctx = .nil
  if ctx == .nil then ctx = self~current
  if ctx == .nil then do
    ctx = .directory~new
    ctx['ARGS'] = .directory~new
    ctx['FIELDS'] = .directory~new
  end
  vars = .directory~new
  do i = 1 to c~items
    r = self~tokenRole(c, i, ctx)
    if r == 'SELF' then vars['SELF'] = .true
    if r == 'VAR' then vars[c[i]~text] = .true
  end
  return vars
::method clauseKey
  use strict arg c, ctx
  return self~render(c, .SlamRoles~new(ctx['ARGS'], ctx['FIELDS']), 'FAMILY')
/* Parameters are A roles; fields of the class are F roles unless a parameter of the same name hides
 * them (Java scoping; ooRexx has no such case). */
::method unitContext
  use strict arg unit
  args = .directory~new
  hdr = .array~of(.SlamJToken~new('OP', '(', 0, 0, 0, 0))
  do t over unit~params
    hdr~append(t)
  end
  hdr~append(.SlamJToken~new('OP', ')', 0, 0, 0, 0))
  do n over .SlamJavaSplitter~new~paramNames(hdr, 1)
    args[n] = .true
  end
  fields = .directory~new
  do n over unit~fields~allIndexes
    if \args~hasIndex(n) then fields[n] = .true
  end
  ctx = .directory~new
  ctx['ARGS'] = args
  ctx['FIELDS'] = fields
  return ctx

/* ------------------------------------------------------------------------------------------------ */
/* The ooRexx segmenter with the Java shaper; adds the Java-only statement kinds TRY and BLOCKH. */
::class SlamJavaSegmenter public subclass SlamSegmenter
::method init
  self~init:super
  self~shaper = .SlamJavaShaper~new
::method segmentUnit
  use strict arg unit
  sh = self~shaper
  ctx = sh~unitContext(unit)
  sh~current = ctx                      /* the base segmenter calls varsOf(c) without a context */
  segs = .array~new
  if unit~params~items > 0 then do
    clause = .array~new
    do t over unit~params
      clause~append(t)
    end
    segs~append(self~leaf('ENTRY', .array~of(clause), ctx))
  end
  stmts = .SlamJavaParser~new(unit~tokens)~parseSeq(unit~tokens~items + 1)
  do s over self~segmentSeq(stmts, ctx, .false)
    segs~append(s)
  end
  return segs
::method otherSegment
  use strict arg s, ctx
  if s~kind == 'TRY' then do
    seg = .SlamSegment~new('TRY', s~clause[1]~line)
    seg~addSequence('TRY', self~segmentSeq(s~body, ctx, .false))
    header = .array~of(s~clause)
    do arm over s~arms
      seg~addSequence(arm~kind, self~segmentSeq(arm~body, ctx, .false))
      header~append(arm~clause)
    end
    self~composite(seg, header, ctx)
    return seg
  end
  if s~kind == 'BLOCKH' then do
    seg = .SlamSegment~new('BLOCK', s~clause[1]~line)
    seg~addSequence('BLOCK', self~segmentSeq(s~body, ctx, .false))
    self~composite(seg, .array~of(s~clause), ctx)
    return seg
  end
  return .nil

/* ------------------------------------------------------------------------------------------------ */
/* Which reader a file needs, by its extension. */
::class SlamLanguages public
::method of class
  use strict arg file
  ext = file~substr(file~lastPos('.') + 1)~lower
  if wordpos(ext, 'cls rex rexx orx') > 0 then return 'REXX'
  if ext == 'java' then return 'JAVA'
  return ''
::method splitter class
  use strict arg lang
  if lang == 'JAVA' then return .SlamJavaSplitter~new
  return .SlamUnitSplitter~new
::method segmenter class
  use strict arg lang
  if lang == 'JAVA' then return .SlamJavaSegmenter~new
  return .SlamSegmenter~new
