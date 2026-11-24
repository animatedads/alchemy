/* ShellSource.cls - a source file as a shell object (newshell v0.1-dev7)
   Architecture: Tom Dyer ("the editor features need line edit / amend / read, lint and
   check").  Coding: Claude (Opus 5.5).  Underneath: oorexx_source_editor v0.1-dev9
   (SourceDocument; dev1-dev8 ChatGPT, dev9 Claude) and oorexx_atomic_file v0.1-dev1.

   src = fs~file('/tmp/job/Hello.rex')~source      -- open: reading needs no grant
   say src~line(3);  src~lines(1, 10)~table
   src~find('say')~table;  src~grep('Atomic?ile')~table      -- rxregexp: ? is any one character
   src~lint~table;  say src~check~ok
   src~amend(3, 4, 'say "hello"')                  -- PROTECTED: edits the copy in memory
   src~save                                         -- PROTECTED: the only write

   Edits change the in-memory copy; save is the single write. save goes through the
   editor's saveChecked: it refuses if the file changed on disk since it was read, and
   refuses an ooRexx edit that breaks a file that compiled when it was read. Every
   protected call is judged by the security manager on the file's path. */
::requires 'ShellObject.cls'
::requires 'SourceEditor.cls'

::class SourceFile public inherit ShellObject
::constant SHELL_HELP "A source file opened for reading and line editing. src~line(n), src~lines(first, last) (a ShellCollection of SourceLine rows: number, text), src~lineCount, src~find(text) and src~grep(regex) (ShellCollection of SourceHit rows: line, column, text; in grep ? matches any one character and . is a literal dot), src~lint (SourceLintRow rows: line, rule, message; rules P1-P4, P7, P9), src~check (a SourceCheck: ok, code, line, message). Editing (PROTECTED, in memory until save): src~replaceLine(n, text), src~insertBefore(n, text), src~insertAfter(n, text), src~amend(first, last, text) (returns the replaced lines; last = first-1 inserts). src~save (PROTECTED) writes once and refuses if the file changed on disk or an ooRexx edit stopped it compiling. Line numbers start at 1."

::method init
  expose path doc loadedSize loadedModified
  use strict arg pathArg
  f = .File~new(pathArg)
  if SysIsFileLink(f~absolutePath) then raise syntax 93.900 array ('Will not open a source through a symbolic link:' pathArg)
  if \f~isFile then raise syntax 93.900 array ('No such file:' pathArg)
  path = f~absolutePath
  doc = .SourceDocument~new(path)
  loadedSize = f~length
  loadedModified = f~lastModified~isoDate

::method path
  expose path
  return path
::method language
  expose doc
  return doc~language
::method lineCount
  expose doc
  return doc~lineCount
::method line
  expose doc
  use strict arg n
  self~checkLine(n)
  return doc~line(n)

::method lines
  expose doc
  use strict arg first = 1, last = (doc~lineCount)
  self~checkLine(first)
  self~checkLine(last)
  rows = .Array~new
  do n = first to last
    rows~append(.SourceLine~new(n, doc~line(n)))
  end
  return .ShellCollection~new(rows)

::method find
  expose doc
  use strict arg text
  return self~hits(doc~find(text, 'text', 'sensitive'))
::method grep
  expose doc
  use strict arg regex
  return self~hits(doc~grep(regex, 'text', 'sensitive'))

::method lint
  expose doc
  rows = .Array~new
  do f over doc~lint
    rows~append(.SourceLintRow~new(f~line, f~rule, f~message))
  end
  return .ShellCollection~new(rows)

::method check
  expose doc
  r = doc~check
  return .SourceCheck~new(r~ok, r~code, r~line, r~message, r~dependencies~items)

/* ---- editing: PROTECTED, in memory until save ---- */
::method replaceLine protected
  expose doc
  use strict arg n, text
  self~checkLine(n)
  doc~replaceLine(n, text)
  return self
::method insertBefore protected
  expose doc
  use strict arg n, text
  self~checkLine(n)
  doc~insertBefore(n, text)
  return self
::method insertAfter protected
  expose doc
  use strict arg n, text
  self~checkLine(n)
  doc~insertAfter(n, text)
  return self
::method amend protected
  expose doc
  use strict arg first, last, text
  old = doc~amend(first, last, text)
  rows = .Array~new
  do i = 1 to old~items
    rows~append(.SourceLine~new(first + i - 1, old[i]))
  end
  return .ShellCollection~new(rows)
::method save protected
  expose doc path loadedSize loadedModified
  doc~saveChecked
  f = .File~new(path)
  loadedSize = f~length
  loadedModified = f~lastModified~isoDate
  return path

/* every protected call is judged on the file's own path */
::method authorityPath
  expose path
  use strict arg name, args
  return path

::method identity
  expose path
  return 'source:'path
::method isCurrent
  expose path loadedSize loadedModified
  f = .File~new(path)
  if \f~isFile then return .false
  return f~length = loadedSize & f~lastModified~isoDate == loadedModified
::method capabilities
  return .Array~of('READ', 'EDIT(policy)', 'SAVE(policy)')
::method fields
  return .Array~of('path', 'language', 'lineCount')
::method relatedSamples
  return .Array~of(.Array~of('rows from lines, find, grep, lint, check', .SourceLine~new(1, '')))

::method hits private
  use strict arg matches
  rows = .Array~new
  do m over matches
    rows~append(.SourceHit~new(m~lineNumber, m~column, m~text))
  end
  return .ShellCollection~new(rows)
::method checkLine private
  expose doc
  use strict arg n
  if \datatype(n, 'W') then raise syntax 93.900 array ('A line number must be a whole number, not' n)
  if n < 1 | n > doc~lineCount then raise syntax 93.900 array ('Line' n 'is outside 1 to' doc~lineCount)

/* ---- rows ---- */
::class SourceLine public inherit ShellObject
::method init
  expose number text
  use strict arg number, text
::method number
  expose number
  return number
::method text
  expose text
  return text
::method fields
  return .Array~of('number', 'text')

::class SourceHit public inherit ShellObject
::method init
  expose line column text
  use strict arg line, column, text
::method line
  expose line
  return line
::method column
  expose column
  return column
::method text
  expose text
  return text
::method fields
  return .Array~of('line', 'column', 'text')

::class SourceLintRow public inherit ShellObject
::method init
  expose line rule message
  use strict arg line, rule, message
::method line
  expose line
  return line
::method rule
  expose rule
  return rule
::method message
  expose message
  return message
::method fields
  return .Array~of('line', 'rule', 'message')

::class SourceCheck public inherit ShellObject
::method init
  expose ok code line message dependencies
  use strict arg ok, code, line, message, dependencies
::method ok
  expose ok
  return ok
::method code
  expose code
  return code
::method line
  expose line
  return line
::method message
  expose message
  return message
::method dependencies
  expose dependencies
  return dependencies
::method fields
  return .Array~of('ok', 'code', 'line', 'message', 'dependencies')
