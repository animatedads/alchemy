/* BodySlamScanner.cls - Body Slam v0.1: read one ooRexx file for the facts that join files to files.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 *
 * Body Slam asks how the estate hangs together, so it reads only what links a file to other files:
 *   REQUIRES  ::requires "name" [LIBRARY] [NAMESPACE ns]
 *   CLASS     ::class name [METACLASS m] [SUBCLASS s | MIXINCLASS s] [PUBLIC] [INHERIT a b ...]
 *   ROUTINE   ::routine name [PUBLIC] [EXTERNAL ...]
 *   USE       .Name in code (an environment symbol: a class, or an entry the program put there)
 *   PUBLISH / SUBSCRIBE / EMIT   ~publish("topic"), ~subscribe("topic"), ~emit("topic") with a literal topic
 *
 * Why not SLAM's lexer (rx2cpp's RxLexer): it reads every clause, at about 770 lines a second, so the
 * whole estate (1.35M lines) would take half an hour. These facts need only comments, strings and the
 * start of a line, so this scanner removes comments (block comments nest, as in Rexx; -- to end of line),
 * replaces each string by a marker '01'x n '02'x, and looks at what is left. tests/test_bodyslam.rex
 * checks its directive facts against RxLexer's tokens on real files.
 *
 * Each line is cut into clauses at ';' (outside comments and strings), so `::method m; return .true`
 * gives the directive and the use. Stated limits: a clause continued on the next line (a trailing comma)
 * is read as two; a topic built at run time is not a literal and is not read; a USE is a symbol, not a type
 * check, so .Foo used only as an environment entry reads as a USE of Foo.
 *
 * Each fact is an array: kind, line, a, b, c, d.
 */

::class BodySlamScanner public
::attribute depth
::attribute strs
::attribute facts

::method init
  expose depth strs facts
  depth = 0
  strs = .array~new
  facts = .array~new

/* Scan one file; return the array of facts and the line count (as facts~lines, kept in a directory). */
::method scan
  expose depth strs facts
  use strict arg path
  depth = 0
  facts = .array~new
  s = .stream~new(path)
  if s~open('read shareread') \= 'READY:' then return .array~of(facts, 0)
  lines = s~arrayIn
  s~close
  seen = .directory~new
  do n = 1 to lines~items
    raw = lines[n]
    if raw~right(1) == '0d'x then raw = raw~left(raw~length - 1)
    strs = .array~new
    code = self~clean(raw)
    if code~strip == '' then iterate
    /* each clause of the line: comments and strings are gone, so a ';' here ends a clause */
    do clause over code~makeArray(';')
      t = clause~strip
      if t == '' then iterate
      if t~left(2) == '::' then do
        self~directive(t, n)
        iterate
      end
      self~uses(clause, n, seen)
      self~topics(clause, n)
    end
  end
  do name over seen~allIndexes
    pair = seen[name]
    facts~append(.array~of('USE', pair[2], name, pair[1], pair[3]))
  end
  return .array~of(facts, lines~items)

/* Remove comments; replace each string by '01'x index '02'x and keep its value in strs. */
::method clean
  expose depth strs
  use strict arg line
  out = ''
  i = 1
  n = line~length
  do while i <= n
    if depth > 0 then do
      a = line~pos('*/', i)
      b = line~pos('/*', i)
      opens = .false
      if b > 0 then do
        if a = 0 then opens = .true
        else if b < a then opens = .true
      end
      if opens then do
        depth += 1
        i = b + 2
        iterate
      end
      if a = 0 then leave
      depth -= 1
      i = a + 2
      iterate
    end
    j = verify(line, '/"''-', 'M', i)
    if j = 0 then do
      out = out || line~substr(i)
      leave
    end
    out = out || line~substr(i, j - i)
    c = line~substr(j, 1)
    nx = line~substr(j + 1, 1)
    if c == '/' then do
      if nx == '*' then do
        depth = 1
        i = j + 2
        iterate
      end
      out = out || '/'
      i = j + 1
      iterate
    end
    if c == '-' then do
      if nx == '-' then leave
      out = out || '-'
      i = j + 1
      iterate
    end
    /* a quote: find its end; a doubled quote inside is one quote character */
    k = line~pos(c, j + 1)
    do while k > 0
      if line~substr(k + 1, 1) \== c then leave
      k = line~pos(c, k + 2)
    end
    if k = 0 then k = n + 1
    value = line~substr(j + 1, k - j - 1)~changestr(c || c, c)
    strs~append(value)
    out = out || '01'x || strs~items || '02'x
    i = k + 1
  end
  return out

/* A word of a directive: a string marker gives the string's value (case kept); a symbol is upper-cased,
   as Rexx does. The second item says whether the word was a string. */
::method token
  expose strs
  use strict arg w
  if w~left(1) == '01'x then do
    parse var w '01'x idx '02'x
    if datatype(idx, 'W') then do
      if idx <= strs~items then return .array~of(strs[idx], .true)
    end
  end
  return .array~of(w~upper, .false)

::method directive
  expose facts
  use strict arg t, n
  body = t~substr(3)~strip
  if body~left(1) == '01'x then kw = ''
  else parse upper var body kw .
  rest = body~subword(2)
  select
    when kw == 'REQUIRES' then do
      if rest == '' then do
        facts~append(.array~of('REQUIRES', n, '', 'INVALID', ''))
        return
      end
      first = rest~word(1)
      if first~left(1) == '(' then do
        facts~append(.array~of('REQUIRES', n, t, 'INVALID', ''))
        return
      end
      w = self~token(first)
      kind = 'FILE'
      ns = ''
      do i = 2 to rest~words
        up = rest~word(i)~upper
        if up == 'LIBRARY' then kind = 'LIBRARY'
        if up == 'NAMESPACE' then do
          nsw = self~token(rest~word(i + 1))
          ns = nsw[1]
        end
      end
      facts~append(.array~of('REQUIRES', n, w[1], kind, ns))
    end
    when kw == 'CLASS' then do
      if rest == '' then return
      w = self~token(rest~word(1))
      name = w[1]
      public = 0
      parent = ''
      how = ''
      inherit = ''
      i = 2
      do while i <= rest~words
        up = rest~word(i)~upper
        select
          when up == 'PUBLIC' then public = 1
          when up == 'PRIVATE' then public = 0
          when up == 'SUBCLASS' then do
            i += 1
            pw = self~token(rest~word(i))
            parent = pw[1]~upper
            how = 'SUBCLASS'
          end
          when up == 'MIXINCLASS' then do
            i += 1
            pw = self~token(rest~word(i))
            parent = pw[1]~upper
            how = 'MIXINCLASS'
          end
          when up == 'METACLASS' then i += 1
          when up == 'INHERIT' then do
            do while i < rest~words
              i += 1
              iw = self~token(rest~word(i))
              inherit = (inherit iw[1]~upper)~strip
            end
          end
          otherwise nop
        end
        i += 1
      end
      facts~append(.array~of('CLASS', n, name, public, parent, inherit))
    end
    when kw == 'ROUTINE' then do
      if rest == '' then return
      w = self~token(rest~word(1))
      public = 0
      if wordpos('PUBLIC', rest~upper) > 0 then public = 1
      facts~append(.array~of('ROUTINE', n, w[1], public, '', ''))
    end
    otherwise nop
  end

/* .Name where the dot does not follow a symbol character (so not a compound tail, not a number). */
::method uses
  use strict arg code, n, seen
  symch = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_!?.'
  start = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_!?'
  p = code~pos('.')
  do while p > 0
    ok = .true
    if p > 1 then do
      if symch~pos(code~substr(p - 1, 1)) > 0 then ok = .false
    end
    if ok then do
      if start~pos(code~substr(p + 1, 1)) = 0 then ok = .false
    end
    if ok then do
      e = verify(code, symch, 'N', p + 1)
      if e = 0 then e = code~length + 1
      name = code~substr(p + 1, e - p - 1)
      dotAt = name~pos('.')
      if dotAt > 0 then name = name~left(dotAt - 1)
      up = name~upper
      if seen~hasIndex(up) then do
        pair = seen[up]
        pair[1] = pair[1] + 1
      end
      else seen[up] = .array~of(1, n, name)
      p = code~pos('.', e)
    end
    else p = code~pos('.', p + 1)
  end

::method topics
  expose facts strs
  use strict arg code, n
  up = code~upper
  do role over .array~of('PUBLISH', 'SUBSCRIBE', 'EMIT')
    key = '~' || role
    p = up~pos(key)
    do while p > 0
      q = p + key~length
      rest = code~substr(q)~strip('L')
      if rest~left(1) == '(' then do
        rest = rest~substr(2)~strip('L')
        if rest~left(1) == '01'x then do
          parse var rest '01'x idx '02'x after
          if datatype(idx, 'W') then do
            if idx <= strs~items then facts~append(.array~of(role, n, strs[idx], '', ''))
          end
        end
      end
      p = up~pos(key, q)
    end
  end
