/* PiledriverWords.cls - Piledriver v0.1: the closed lists and token shapes.
 *
 * Architecture: Tom Dyer (Piledriver: the SLAM component that reads logs, tables and sheets, and keeps
 * "what kind of file is this" apart from "is this an error code" and "have I seen this before").
 * Code: Claude (Opus 5.5), 2026-10-30.
 *
 * No model and no weights. Every decision below is a closed list or a shape, and each one is named in the
 * reason Piledriver gives, so a wrong answer can be traced to the line that made it.
 *
 *   level(token)        a severity word: FATAL ERROR WARN OK INFO DEBUG, or ''.  Upper case as written
 *                       (ERROR, FAIL), or bracketed in any case ([error], <warn>); "Error" in a sentence is
 *                       a word, not a level.
 *   keywords(text)      error words in a message, with negation ("0 errors", "no error", "error=0")
 *   codeShaped(core)    REXX/SQL-24, ORA-00942, REX0040E, E10: upper-case letters, a number, an optional suffix
 *                       (not names such as SHA256, WIN32, X86, ISO8601: a closed list)
 *   codeValue(key, v)   is V, after a code key, a code: a number, a code-shaped word, or a five-character
 *                       SQLSTATE.  A word ("STATUS: running") is not: it is left to the counts
 *   codeKey(key)        rc, exit, errno, sqlcode, intcode, status ...: the value after it is a code
 *   okValue(key, v)     0, OK, SUCCESS, PASS (and 2xx for a status key)
 *   mask(core)          digits and hex runs become '#': the shape of a value, not the value
 *   timestampWords(...) how many words at the start of a line are a time stamp
 *   sheetError(v)       #DIV/0!, #N/A, #REF! ... (Excel) and Err:502 (LibreOffice): a spreadsheet error value
 */

::class PiledriverWords public

::method activate class
  expose levels weak strong phrases negators codeKeys codeWords okWords statusKeys sheetErrors months days exts p notCodes
  levels = .directory~new
  call fill levels, 'FATAL EMERG EMERGENCY ALERT CRIT CRITICAL SEVERE PANIC', 'FATAL'
  call fill levels, 'ERROR ERR ERRORS FAIL FAILED FAILURE ABORT ABORTED', 'ERROR'
  call fill levels, 'WARN WARNING WARNINGS', 'WARN'
  call fill levels, 'PASS PASSED OK SUCCESS SUCCEEDED DONE', 'OK'
  call fill levels, 'INFO INFORMATION NOTICE NOTE', 'INFO'
  call fill levels, 'DEBUG TRACE FINE FINER FINEST VERBOSE', 'DEBUG'
  weak = .directory~new
  call fill weak, 'error errors failed failure failures fail fails denied refused unable cannot cant', .true
  call fill weak, 'timeout invalid corrupt corrupted crash crashed killed overflow underflow', .true
  strong = .directory~new
  call fill strong, 'fatal panic abort aborted aborting terminated segfault traceback exception exceptions', .true
  phrases = .array~new
  do p over 'segmentation fault=S|core dumped=S|out of memory=S|stack overflow=S|timed out=W|no such=W|not found=W|could not=W|permission denied=W'~makeArray('|')
    phrases~append(p)
  end
  negators = .directory~new
  call fill negators, '0 no without zero never', .true
  codeKeys = .directory~new
  call fill codeKeys, 'RC RETCODE RETURNCODE RETURN_CODE EXIT EXITCODE EXIT_CODE ERRNO ERRCODE ERROR_CODE', .true
  call fill codeKeys, 'INTCODE SQLCODE SQLSTATE STATUS STATUSCODE STATUS_CODE HTTP_STATUS CODE ERR ERROR', .true
  codeWords = .directory~new
  call fill codeWords, 'ERROR ERRNO CODE RC EXIT STATUS SQLCODE', .true
  okWords = .directory~new
  call fill okWords, 'OK SUCCESS SUCCEEDED SUCCESSFUL PASS PASSED NONE NOERROR DONE COMPLETE COMPLETED FINISHED', .true
  statusKeys = .directory~new
  call fill statusKeys, 'STATUS STATUSCODE STATUS_CODE HTTP_STATUS', .true
  sheetErrors = .directory~new
  call fill sheetErrors, '#NULL! #DIV/0! #VALUE! #REF! #NAME? #NUM! #N/A #GETTING_DATA #SPILL! #CALC!', .true
  call fill sheetErrors, '#FIELD! #BLOCKED! #CONNECT! #BUSY! #UNKNOWN! #EXTERNAL!', .true
  months = .directory~new
  call fill months, 'JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC', .true
  days = .directory~new
  call fill days, 'MON TUE WED THU FRI SAT SUN', .true
  notCodes = .directory~new
  call fill notCodes, 'SHA1 SHA224 SHA256 SHA384 SHA512 WIN16 WIN32 WIN64 X86 X64 ISO8601 ISO9660 IPV4 IPV6', .true
  call fill notCodes, 'AES128 AES192 AES256 RSA1024 RSA2048 RSA4096 ARM64 AMD64 UTF16 UTF32 CP1252 CP437 MP3 MP4', .true
  exts = .directory~new
  call fill exts, 'rex cls rexx nrx log txt csv tsv json xml tmp py java c h cpp hpp js ts sh db sqlite', .true
  call fill exts, 'xlsx ods md html so dll exe cfg conf ini yaml yml out err jar class o a', .true
  return

  fill: procedure
    use arg dir, list, value
    do w over list~subWords
      dir[w] = value
    end
    return

/* A severity word, or ''. */
::method level class
  expose levels
  use strict arg token
  if token == '' then return ''
  bracketed = verify(token~left(1), '[<(') == 0
  core = token~strip('L', '[<(')~strip('T', ':')~strip('T', ']>)')~strip('T', ':')~strip('T', '-')
  if core == '' then return ''
  if \bracketed then if core \== core~upper then return ''
  up = core~upper
  if levels~hasIndex(up) then return levels[up]
  return ''

/* The rank of a level: lower is worse.  '' ranks after all. */
::method rank class
  use strict arg level
  r = wordpos(level, 'FATAL ERROR WARN OK INFO DEBUG')
  if r == 0 then return 9
  return r

/* syslog <PRI> at the start of a line: severity is PRI // 8. */
::method syslogLevel class
  use strict arg token
  if token~left(1) \== '<' then return ''
  p = token~pos('>')
  if p < 3 then return ''
  n = token~substr(2, p - 2)
  if \datatype(n, 'W') then return ''
  sev = n // 8
  if sev <= 2 then return 'FATAL'
  if sev == 3 then return 'ERROR'
  if sev == 4 then return 'WARN'
  if sev <= 6 then return 'INFO'
  return 'DEBUG'

/* Error words in TEXT. Returns an array of "S word" (strong) or "W word" (weak); negated hits are left out. */
::method keywords class
  expose weak strong phrases negators
  use strict arg text
  hits = .array~new
  clean = text~lower~changeStr("'", '')
  clean = clean~translate(' ', '=:;,.()[]{}<>"!?/\|*#@$%^&+~`')
  ws = clean~subWords
  n = ws~items
  do i = 1 to n
    w = ws[i]
    kind = ''
    if strong~hasIndex(w) then kind = 'S'
    else if weak~hasIndex(w) then kind = 'W'
    if kind == '' then iterate
    if i > 1 then if negators~hasIndex(ws[i - 1]) then iterate
    if i < n then if ws[i + 1] == '0' then iterate
    hits~append(kind w)
  end
  padded = ' ' || ws~makeString('L', ' ') || ' '
  do p over phrases
    parse var p phrase '=' kind
    at = padded~pos(' ' || phrase || ' ')
    if at == 0 then iterate
    before = padded~left(at)~strip~subWords
    if before~items > 0 then if negators~hasIndex(before[before~items]) then iterate
    hits~append(kind phrase)
  end
  return hits

::method isCodeKey class
  expose codeKeys
  use strict arg key
  return codeKeys~hasIndex(key~upper)

::method isCodeWord class
  expose codeWords
  use strict arg word
  return codeWords~hasIndex(word~upper)

::method isStatusKey class
  expose statusKeys
  use strict arg key
  return statusKeys~hasIndex(key~upper)

/* After a code key, is V a code?  A number, a code-shaped word, or a 5-character SQLSTATE (ZZZZZ, 42S02). */
::method codeValue class
  use strict arg key, v
  if datatype(v, 'N') then return .true
  if self~codeShaped(v) then return .true
  if key~upper == 'SQLSTATE' then if v~length == 5 then if v~verify(xrange('A', 'Z') || '0123456789') == 0 then return .true
  return .false

/* Is V the "nothing went wrong" value of KEY? */
::method okValue class
  expose okWords statusKeys
  use strict arg key, v
  if v == '' then return .true
  if okWords~hasIndex(v~upper) then return .true
  if v~verify('0') == 0 then return .true
  if datatype(v, 'N') then do
    if v = 0 then return .true
    if statusKeys~hasIndex(key~upper) then if datatype(v, 'W') then if v >= 200 then if v < 300 then return .true
  end
  return .false

/* REXX/SQL-24, ORA-00942, REX0040E, E10, HTTP-500: an upper-case prefix (letters, '/', '_'), an optional '-',
   at least two digits (one after a '-'), and at most two upper-case letters after them. */
::method codeShaped class
  expose notCodes
  use strict arg core
  if notCodes~hasIndex(core) then return .false
  len = core~length
  if len < 3 then return .false
  if len > 24 then return .false
  if verify(core~left(1), xrange('A', 'Z')) \== 0 then return .false
  i = 1
  do while i <= len
    if verify(core~substr(i, 1), xrange('A', 'Z') || '/_') \== 0 then leave
    i += 1
  end
  prefixLen = i - 1
  sep = 0
  if i <= len then if core~substr(i, 1) == '-' then do
    sep = 1
    i += 1
  end
  digitStart = i
  do while i <= len
    if verify(core~substr(i, 1), '0123456789') \== 0 then leave
    i += 1
  end
  digits = i - digitStart
  if digits == 0 then return .false
  if digits < 2 then if sep == 0 then return .false
  suffix = core~substr(i)
  if suffix~length > 2 then return .false
  if suffix \== '' then if verify(suffix, xrange('A', 'Z')) \== 0 then return .false
  if prefixLen > 12 then return .false
  return .true

/* The family of a code: its prefix, with the separator ("REXX/SQL-", "ORA-", "E"). */
::method family class
  use strict arg core
  p = verify(core, '0123456789', 'M')
  if p == 0 then return core
  return core~left(p - 1)

/* digits and hex runs become '#'.  A piece is cut at - . : / , = _ ( ) [ ] + | ; and becomes '#' when it is all
   digits, or all hex and 8 or more long (FFFFFFFF), or all hex with a digit and 4 or more long (00FF);
   in other pieces each digit run becomes '#'. */
::method mask class
  use strict arg core
  seps = '-.:/,=_()[]+|;'
  out = ''
  piece = ''
  do i = 1 to core~length
    c = core~substr(i, 1)
    if seps~pos(c) > 0 then do
      out = out || maskPiece(piece) || c
      piece = ''
    end
    else piece = piece || c
  end
  return out || maskPiece(piece)

  maskPiece: procedure
    use arg piece
    if piece == '' then return ''
    if piece~verify('0123456789') == 0 then return '#'
    p = piece
    if p~left(2)~lower == '0x' then p = p~substr(3)
    if p \== '' then if p~verify('0123456789abcdefABCDEF') == 0 then do
      if p~length >= 8 then return '#'
      if p~verify('0123456789', 'M') > 0 then if p~length >= 4 then return '#'
    end
    o = ''
    inDigits = .false
    do i = 1 to piece~length
      c = piece~substr(i, 1)
      if '0123456789'~pos(c) > 0 then do
        if \inDigits then o = o || '#'
        inDigits = .true
        iterate
      end
      inDigits = .false
      o = o || c
    end
    return o

/* Hex-encoded text: all hex, even length, 4 or more, and every byte printable.  Returns the text or ''. */
::method hexText class
  use strict arg v
  if v~length < 4 then return ''
  if v~length // 2 \== 0 then return ''
  if v~verify('0123456789abcdefABCDEF') \== 0 then return ''
  t = v~x2c
  if t~verify(xrange('20'x, '7e'x)) \== 0 then return ''
  return t

/* A short code: a whole number of 1 to 4 digits, with a sign or not, and no leading zero. */
::method shortCode class
  use strict arg v
  d = v~strip('L', '-')~strip('L', '+')
  if d == '' then return .false
  if d~verify('0123456789') \== 0 then return .false
  if d~length > 4 then return .false
  if d~length > 1 then if d~left(1) == '0' then return .false
  return .true

/* A path keeps its words; a segment that is a number (101), long hex, or a uuid becomes '#':
   /api/v1/user/101 -> /api/v1/user/#; 23.html -> #.html.  A segment with digits and no letter is masked as
   in MASK (2026:20:01:01 -> #:#:#:#); a segment with a letter is a word (v1 stays v1). */
::method pathMask class
  use strict arg core
  out = ''
  seg = ''
  do i = 1 to core~length + 1
    if i <= core~length then c = core~substr(i, 1)
    else c = '/'
    if c == '/' | c == '?' | c == '&' | c == '=' then do
      out = out || segMask(seg)
      if i <= core~length then out = out || c
      seg = ''
    end
    else seg = seg || c
  end
  return out

  segMask: procedure
    use arg seg
    if seg == '' then return ''
    if seg~verify('0123456789') == 0 then return '#'
    if seg~verify('0123456789abcdefABCDEF-') == 0 then if seg~length >= 8 then if seg~verify('0123456789', 'M') > 0 then return '#'
    p = seg~lastPos('.')
    if p > 1 then if seg~left(p - 1)~verify('0123456789') == 0 then return '#' || seg~substr(p)
    if seg~verify('0123456789', 'M') > 0 then if seg~verify(xrange('a', 'z') || xrange('A', 'Z'), 'M') == 0 then return .PiledriverWords~mask(seg)
    return seg

/* A path: starts / ./ ../ ~/ or a drive (C:\), or holds two or more '/'. */
::method isPath class
  use strict arg core
  if core~left(1) == '/' then if core~length > 1 then return .true
  if core~left(2) == './' then return .true
  if core~left(3) == '../' then return .true
  if core~left(2) == '~/' then return .true
  if core~length > 2 then if core~substr(2, 2) == ':\' then return .true
  if core~countStr('/') >= 2 then if core~pos('://') == 0 then return .true
  return .false

/* A file name: base.ext with ext, as written (lower case), in the closed list. */
::method isFile class
  expose exts
  use strict arg core
  p = core~lastPos('.')
  if p < 2 then return .false
  if core~pos('/') > 0 then return .false
  ext = core~substr(p + 1)
  return exts~hasIndex(ext)          /* as written: java.lang.Class is a class, Main.class is a file */

/* How many words, from FIRST, are a time stamp (0 if none).  WS is an array of words. */
::method timestampWords class
  expose months days
  use strict arg ws, first = 1
  n = ws~items
  if first > n then return 0
  t1 = ws[first]~strip('L', '[')
  s1 = self~shape(t1)
  /* 2026-10-30, 2026/10/30, 2026-10-30T20:34:01.123Z */
  if s1~left(10) == '9999-99-99' | s1~left(10) == '9999/99/99' then do
    if s1~length > 10 then return 1
    if first < n then if self~shape(ws[first + 1])~left(5) == '99:99' then return 2
    return 1
  end
  /* 30/Oct/2026:20:34:01 (+0000]) */
  if s1~left(11) == '99/aaa/9999' then do
    if first < n then if verify(ws[first + 1]~left(1), '+-') == 0 then if datatype(ws[first + 1]~strip('T', ']')~substr(2), 'W') then return 2
    return 1
  end
  /* 20:34:01 */
  if s1~left(8) == '99:99:99' then return 1
  /* [Thu] Oct 30 20:34:01 [2026] */
  k = first
  if days~hasIndex(t1~left(3)~upper) then if t1~length <= 4 then k += 1
  if k + 2 > n then return 0
  m = ws[k]~strip('L', '[')
  if \months~hasIndex(m~left(3)~upper) then return 0
  if m~length > 4 then return 0
  if \datatype(ws[k + 1], 'W') then return 0
  if self~shape(ws[k + 2])~left(8) \== '99:99:99' then return 0
  used = k + 2 - first + 1
  if k + 3 <= n then if self~shape(ws[k + 3]~strip('T', ']'))  == '9999' then used += 1
  return used

/* digits -> 9, letters -> a, the rest as it is. */
::method shape class
  use strict arg s
  return s~translate(copies('9', 10) || copies('a', 52), '0123456789' || xrange('a', 'z') || xrange('A', 'Z'))

::method sheetError class
  expose sheetErrors
  use strict arg v
  if sheetErrors~hasIndex(v~upper) then return .true
  if v~left(4) == 'Err:' then if datatype(v~substr(5), 'W') then return .true
  return .false

/* A banner line: only rule characters, three or more. */
::method isBanner class
  use strict arg line
  s = line~strip
  if s~length < 3 then return .false
  return s~verify('=-*#_~+') == 0

/* A heading made with rule characters: "== x ==", "--- x", "### x", "***** x *****".  Returns its text or ''. */
::method ruledHeading class
  use strict arg line
  s = line~strip
  first = s~left(1)
  if '=-#*'~pos(first) == 0 then return ''
  run = s~verify(first) - 1
  if run <= 0 then return ''
  if first == '*' then if run < 4 then return ''
  if run < 2 then return ''
  if s~substr(run + 1, 1) \== ' ' then return ''
  text = s~substr(run + 1)~strip~strip('T', first)~strip
  if text == '' then return ''
  return text
