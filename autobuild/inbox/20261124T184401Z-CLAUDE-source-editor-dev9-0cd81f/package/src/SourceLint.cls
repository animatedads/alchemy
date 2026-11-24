/* SourceLint.cls - lint and check for ooRexx sources (source editor v0.1-dev9)
   Architecture: Tom Dyer (24 November 2026: the editor needs read, line
   edit / amend, lint and check). Coding: Claude (Opus 5.5).

   lint   the traps that have already cost runs, each with its line:
          P1-P4 from RexxPitfallChecker (PitfallChecker.cls, brought here
          from oorexx_slam_bostoncrab v0.24, where its header already said an
          editor should be able to ask it), and
          P7  "call x~y" or "call .X~y": a syntax error in ooRexx
          P9  a variable named RESULT, RC or SIGL: ooRexx sets them itself
              (RESULT after every message instruction and CALL)
   check  does the source compile? It is compiled with its ::requires lines
          blanked (line numbers kept), so a syntax error is reported where it
          is; a ::requires that cannot be found, or a class that is not
          defined here, is a DEPENDENCY, not a syntax error.

   findings = .SourceLinter~new~lint(lines)        -- Array of SourceLintFinding
   r = .SourceSyntaxCheck~new~check(lines, searchDirs)   -- a SourceCheckResult */
::requires 'PitfallChecker.cls'

::class SourceLintFinding public
::attribute rule get
::attribute line get
::attribute column get
::attribute text get
::attribute message get
::method init
  expose rule line column text message
  use strict arg rule, line, column, text, message
::method string
  expose rule line column text message
  return line':'column' 'rule' 'message' | 'text~strip

::class SourceLinter public
::method lint
  use strict arg lines
  found = .Array~new
  do p over .RexxPitfallChecker~new~check(lines)
    found~append(.SourceLintFinding~new(p~rule, p~line, p~column, lines[p~line], pitfallMessage(p~rule, p~names)))
  end
  code = codeOnly(lines)
  do n = 1 to code~items
    c = code[n]
    -- P7: call x~y / call .X~y
    t = c~strip
    if t~word(1)~upper == 'CALL' then do
      target = t~word(2)
      if target~pos('~') > 0 then
        found~append(.SourceLintFinding~new('P7', n, c~caselessPos('call') , lines[n], 'call x~y is a syntax error; write x~y as a message instruction'))
    end
    -- P9: RESULT, RC or SIGL assigned as a variable
    do v over .Array~of('RESULT', 'RC', 'SIGL')
      at = assignedAt(c, v)
      if at > 0 then found~append(.SourceLintFinding~new('P9', n, at, lines[n], v~lower 'is set by ooRexx itself (RESULT after every message instruction and CALL); use another name'))
    end
  end
  return found~sortWith(.SourceLintOrder~new)

::class SourceLintOrder public
::method compare
  use strict arg a, b
  if a~line < b~line then return -1
  if a~line > b~line then return 1
  if a~column < b~column then return -1
  if a~column > b~column then return 1
  return 0

::class SourceCheckResult public
::attribute ok get
::attribute code get
::attribute message get
::attribute line get
::attribute dependencies get
::method init
  expose ok code message line dependencies
  use strict arg ok, code = '', message = '', line = 0, dependencies = (.Array~new)
::method string
  expose ok code message line dependencies
  if ok then text = 'OK: compiles'
  else text = 'SYNTAX' code 'line' line':' message
  do d over dependencies; text = text'; DEPENDENCY' d; end
  return text

::class SourceSyntaxCheck public
::method check
  use strict arg lines, searchDirs = (.Array~new)
  src = .Array~new
  deps = .Array~new
  do n = 1 to lines~items
    t = lines[n]~strip
    if t~left(10)~caselessEquals('::requires') then do
      src~append('')                                 -- keep the line numbers
      parse var t . name rest
      name = name~strip('B', '"')~strip('B', "'")
      if rest~caselessPos('LIBRARY') = 0, \resolvable(name, searchDirs) then deps~append('::requires' name 'is not found on the search path')
    end
    else src~append(lines[n])
  end
  signal on syntax name failed
  r = .Routine~new('source-check', src)
  signal off syntax
  return .SourceCheckResult~new(.true, '', '', 0, deps)
failed:
  c = condition('O')
  code = c~code
  where = c~position
  if where == .nil then where = 0
  -- a class this source names but does not define is a dependency, not a syntax error
  if code~left(3) == '98.' | code == '43.901' then do
    deps~append(c~message)
    return .SourceCheckResult~new(.true, '', '', 0, deps)
  end
  return .SourceCheckResult~new(.false, code, c~message, where, deps)

/* -------------------------------------------------------------- helpers -- */
::routine pitfallMessage
  use strict arg rule, names = .nil
  select
    when rule == 'P1' then return 'a string followed at once by ( is a call to a routine named by the string; write s || (x)'
    when rule == 'P2' then return 'a string followed at once by x or b is a hex or binary literal; write s || x'
    when rule == 'P3' then return 'two names differ only in case ('spelled(names)'): ooRexx names are case-insensitive, so they are one name'
    when rule == 'P4' then return 'a USE ARG name is also a loop control variable ('spelled(names)'): the loop overwrites the argument'
    otherwise return 'pitfall' rule
  end

::routine spelled
  use strict arg names
  if names == .nil then return '?'
  if names~isA(.Array) then return names~makeString('L', ' / ')
  return names~string

/* Each line with ooRexx comments and the insides of strings blanked; line
   numbers and columns kept. '' and "" inside a string are the quote itself. */
::routine codeOnly
  use strict arg lines
  out = .Array~new
  depth = 0
  do line over lines
    buf = .MutableBuffer~new
    i = 1; quote = ''
    do while i <= line~length
      ch = line~subchar(i); pair = line~substr(i, 2)
      if depth > 0 then do
        if pair == '*/' then do; depth -= 1; buf~append('  '); i += 2; iterate; end
        if pair == '/*' then do; depth += 1; buf~append('  '); i += 2; iterate; end
        buf~append(' '); i += 1; iterate
      end
      if quote \== '' then do
        if ch == quote, line~subchar(i + 1) == quote then do; buf~append('  '); i += 2; iterate; end
        if ch == quote then do; quote = ''; buf~append(ch); i += 1; iterate; end
        buf~append(' '); i += 1; iterate
      end
      if ch == '"' | ch == "'" then do; quote = ch; buf~append(ch); i += 1; iterate; end
      if pair == '/*' then do; depth = 1; buf~append('  '); i += 2; iterate; end
      if pair == '--' then do; buf~append(copies(' ', line~length - i + 1)); leave; end
      buf~append(ch); i += 1
    end
    out~append(buf~string)
  end
  return out

/* The column where name is assigned (name = value, not name == or a message), or 0. */
::routine assignedAt
  use strict arg code, name
  u = code~upper
  at = u~pos(name)
  do while at > 0
    if at > 1 then before = u~subchar(at - 1); else before = ''
    after = u~substr(at + name~length)~strip('L')
    if (at = 1 | \isNameChar(before)) & before \== '~' & before \== '.', after~left(1) == '=', after~left(2) \== '==' then do
      -- only at the start of a clause: nothing but blanks or a ; before it
      lead = u~left(at - 1)
      semi = lead~lastPos(';')
      if lead~substr(semi + 1)~strip == '' then return at
    end
    at = u~pos(name, at + 1)
  end
  return 0

::routine isNameChar
  use strict arg c
  if c == '' then return .false
  return c~datatype('A') | pos(c, '_!?.') > 0

::routine resolvable
  use strict arg name, searchDirs
  if name~left(1) == '/' then return .File~new(name)~exists
  dirs = .Array~new
  do d over searchDirs; dirs~append(d); end
  do d over value('REXX_PATH',, 'ENVIRONMENT')~makeArray(':'); dirs~append(d); end
  do d over dirs
    if d == '' then iterate
    if .File~new(d'/'name)~exists then return .true
  end
  return .false
