/* PiledriverLog.cls - Piledriver v0.1: read a log file into records, patterns, codes and verdicts.
 *
 * Architecture: Tom Dyer (Piledriver: the SLAM component that reads logs, tables and sheets; "is this an
 * error code" and "have I seen this pattern before in this file" are two questions, asked separately).
 * Code: Claude (Opus 5.5), 2026-10-30.
 *
 * Three layers, in order.  No model and no weights: lists, shapes and counts.
 *
 * 1. RECORDS.  A file is PREFIXED when one non-blank line in five or more starts with a time stamp; then a
 *    line with no stamp belongs to the record before it (stack traces, wrapped messages).  Otherwise a line
 *    belongs to the record before it when it is indented, starts "Caused by:", or follows a head that ends
 *    in ':' and is an upper-case "KEY: value" line ("Error in fetch:" / "INTCODE: -24" / "INTERRM: ...").
 *    In a PREFIXED file a stack frame written as its own stamped event ("... - <tab>at x.y(Y.java:42)") joins
 *    the record before it when both are on the same thread ([http-nio-8080-exec-2]).
 *    A Python "Traceback" block takes its indented lines and the first line after them.  A level line
 *    (WARNING: ..., ERROR: ...) never joins a block.  Blank lines and banner lines end a record.  A heading
 *    ("== x ==", "--- x", "### x", or a line between two banners) opens a SECTION; every record after it
 *    carries the section's name.  A heading that holds an ERROR, FAILED or WARNING level word reports a
 *    result, so it is a record ("-- 3 tests FAILED").  A UTF-8 byte order mark is removed.
 *
 * 2. PATTERNS.  Each word of a record's head line is one of:
 *      LIT      a word with no digit: kept as it is
 *      CODE     code-shaped (REXX/SQL-24, ORA-00942, E10): kept, and listed as a code of the record
 *      CODEVAL  the value of a code key, when the value is a number, a code or a SQLSTATE (rc=-1, exit=134,
 *               INTCODE: -24, Error 97.1, SQLSTATE: ZZZZZ): kept, and listed.  A word value ("STATUS: running")
 *               is a plain word with its key, and the counts decide if the key is a status
 *      VAL      anything else with a digit, a path, a file name: masked ("#", "<PATH>", "<FILE>")
 *    Then the counts decide, both ways:
 *      - a code family (prefix) or code key seen 8 or more times with more distinct values than half the
 *        times is an IDENTIFIER in this file, not a code: it is masked.  (lsoa_code=E01000001 ...)
 *      - a short bare number (1 to 4 digits, no leading zero, not the value of a named key) at one place in
 *        one pattern, seen 5 or more times, with at most 12 distinct values and 4 or more uses per value, is
 *        a CODE SLOT: its values are put back (HTTP 200/404/500).  A slot
 *        whose values are all 100 to 599 is an HTTP status.
 *    The TEMPLATE is the masked head line with the code slots put back.  The SIGNATURE is the template plus
 *    the codes of the whole record, so "Error in open:" can be seen before while "REXX/SQL-62" is new.
 *
 * 3. VERDICTS and MEMORY.  A record is ERROR, WARN, MENTION, OK, INFO, DEBUG or NONE (OK, INFO and DEBUG are
 *    its own positive level), ERROR and WARN STRONG or WEAK, with its reasons:
 *      LEVEL x       a level word (ERROR, FAIL, FATAL; WARN)
 *      STACK         a stack trace in the record
 *      CODE k=v      a code key with a value that is not its OK value (rc=-1, exit=134, INTCODE=-24)
 *      HTTP n        an HTTP status slot: 5xx ERROR, 4xx WARN
 *      KEYWORD w     an error word in the head line (strong: terminated, fatal, exception ...)
 *      RARE_CODE v   a code slot value used under 5% of the time where one value has half or more
 *      STATUS k=v    a named key whose word values are a small set (5+ uses, at most 12 values, 4+ uses each)
 *                    holding an OK value: a STATUS key found by counts (ST=OK x101, ST=UNSUPPORTED x2).
 *                    A record with that key at a value that is not OK is an error
 *    A positive level (PASS, OK, INFO, DEBUG) makes every other piece of evidence a MENTION: the line
 *    "PASS ... fails closed" mentions failure; it is not one.  A heading is NONE: it names a topic.
 *    Keyword evidence alone is WEAK; anything else (or a keyword with a code) is STRONG.
 *    SEEN is how many times the template came before in this file; STATUS is NEW (never, here or in the
 *    catalog), KNOWN (not here, but in the catalog from other files), NEW_CODES (the template is known, the
 *    codes are not) or REPEAT.  A RARE TRANSITION is a known template that follows one seen 10 or more
 *    times, by a step (from, to) seen once.
 *
 * The CATALOG is the memory between files: one line per template and per signature, with counts.
 */

::requires 'PiledriverWords.cls'

::class PiledriverRecord public
::attribute lineNo unguarded
::attribute lines unguarded
::attribute stamp unguarded
::attribute level unguarded
::attribute levelWord unguarded
::attribute section unguarded
::attribute heading unguarded
::attribute tokens unguarded
::attribute contTokens unguarded
::attribute skeleton unguarded
::attribute template unguarded
::attribute signature unguarded
::attribute codes unguarded
::attribute verdict unguarded
::attribute strength unguarded
::attribute reasons unguarded
::attribute seen unguarded
::attribute status unguarded
::attribute rare unguarded
::attribute tags unguarded
::attribute message unguarded
::attribute fields unguarded
::attribute fieldOrder unguarded
::attribute fieldKinds unguarded
::attribute parts unguarded
::attribute context unguarded
::method init
  expose lineNo lines stamp level levelWord section heading tokens contTokens skeleton template signature codes verdict strength reasons seen status rare tags message fields fieldOrder fieldKinds parts context
  use strict arg lineNo, first
  lines = .array~of(first)
  stamp = ''; level = ''; levelWord = ''; section = ''; heading = .false
  tags = ''; message = ''; context = ''; fields = .directory~new; fieldOrder = .array~new; fieldKinds = .directory~new; parts = .array~new
  tokens = .array~new; contTokens = .array~new
  skeleton = ''; template = ''; signature = ''
  codes = .array~new; reasons = .array~new
  verdict = 'NONE'; strength = ''; seen = 0; status = ''; rare = ''
::method head
  expose lines
  return lines[1]
/* The message after a logger's " - " (log4j, logback, Python logging), else the whole message. */
::method body
  expose message
  p = message~pos(' - ')
  if p == 0 then return message
  return message~substr(p + 3)~strip
::method lastLine
  expose lineNo lines
  return lineNo + lines~items - 1
::method describe
  expose lineNo verdict strength template reasons status seen
  v = verdict
  if strength \== '' then v = v || '/' || strength
  text = 'line' lineNo~right(5) v~left(13) status~left(9) template
  if reasons~items > 0 then text = text '  [' || reasons~makeString('L', '; ') || ']'
  return text

::class PiledriverLog public
::attribute name unguarded
::attribute records unguarded
::attribute counts unguarded
::attribute sigCounts unguarded
::attribute firstAt unguarded
::attribute order unguarded
::attribute verdictOf unguarded
::attribute edges unguarded
::attribute slots unguarded
::attribute identifiers unguarded
::attribute catalog unguarded
::attribute catalogSigs unguarded
::attribute prefixed unguarded
::attribute lineCount unguarded

::method init
  expose catalog catalogSigs
  catalog = .directory~new
  catalogSigs = .directory~new
  self~reset

::method reset
  expose name records counts sigCounts firstAt order verdictOf edges slots identifiers prefixed lineCount merged
  merged = .false
  name = ''
  records = .array~new
  counts = .directory~new
  sigCounts = .directory~new
  firstAt = .directory~new
  order = .array~new
  verdictOf = .directory~new
  edges = .directory~new
  slots = .array~new
  identifiers = .array~new
  prefixed = .false
  lineCount = 0

::method readFile
  use strict arg path
  s = .stream~new(path)
  if s~open('read') \== 'READY:' then raise syntax 98.900 array('Piledriver cannot open' path)
  lines = s~arrayIn
  s~close
  do i = 1 to lines~items
    lines[i] = lines[i]~strip('T', '0d'x)
  end
  if lines~items > 0 then if lines[1]~left(3) == 'EFBBBF'x then lines[1] = lines[1]~substr(4)
  return self~readLines(lines, path)

/* LINES: an array of strings.  Returns the records (also kept in ~records). */
::method readLines
  expose name records lineCount prefixed
  use strict arg lines, label = 'lines'
  self~reset
  name = label
  lineCount = lines~items
  prefixed = self~isPrefixed(lines)
  self~assemble(lines)
  self~analyseTokens
  self~decideIdentifiers
  self~buildSkeletons
  self~findSlots
  self~finishTemplates
  do r over records
    self~judge(r)
  end
  self~remember
  return records

/* PREFIXED: one non-blank line in five or more starts with a time stamp. */
::method isPrefixed
  use strict arg lines
  nonBlank = 0; stamped = 0
  do line over lines
    if line~strip == '' then iterate
    nonBlank += 1
    if self~stamped(line) then stamped += 1
  end
  if nonBlank == 0 then return .false
  if stamped == 0 then return .false
  return stamped * 5 >= nonBlank

::method assemble
  expose records prefixed
  use strict arg lines
  n = lines~items
  /* the next and the last non-blank line, for headings made by two banners */
  nextNB = .array~new(n); prevNB = .array~new(n)
  last = 0
  do i = 1 to n
    prevNB[i] = last
    if lines[i]~strip \== '' then last = i
  end
  last = 0
  do i = n to 1 by -1
    nextNB[i] = last
    if lines[i]~strip \== '' then last = i
  end
  cur = .nil; blockOpen = .false; traceback = .false; section = ''
  do i = 1 to n
    line = lines[i]
    s = line~strip
    if s == '' then do
      cur = .nil; blockOpen = .false; traceback = .false
      iterate
    end
    if .PiledriverWords~isBanner(line) then do
      cur = .nil; blockOpen = .false; traceback = .false
      iterate
    end
    headingText = .PiledriverWords~ruledHeading(line)
    if headingText \== '' then if self~badLevelIn(headingText) then headingText = ''
    if headingText == '' then if prevNB[i] > 0 then if nextNB[i] > 0 then if .PiledriverWords~isBanner(lines[prevNB[i]]) then if .PiledriverWords~isBanner(lines[nextNB[i]]) then headingText = s
    if headingText \== '' then do
      section = headingText
      r = .PiledriverRecord~new(i, line)
      r~heading = .true
      r~section = section
      records~append(r)
      cur = .nil; blockOpen = .false; traceback = .false
      iterate
    end
    joins = .false
    if cur \== .nil then do
      indented = verify(line~left(1), ' ' || '09'x) == 0
      if prefixed then do
        joins = \self~stamped(line)
        /* a stack frame logged as its own event ("... - <tab>at x.y(Y.java:42)"), on the same thread */
        if \joins then if self~frameText(line) \== '' then if self~threadOf(line) == self~threadOf(cur~head) then joins = .true
      end
      else do
        if indented then joins = .true
        else if s~left(10) == 'Caused by:' then joins = .true
        else if traceback then do
          joins = .true
          traceback = .false
        end
        else if blockOpen then if self~isUpperKeyLine(s) then joins = .true
      end
    end
    if joins then do
      cur~lines~append(line)
      iterate
    end
    cur = .PiledriverRecord~new(i, line)
    cur~section = section
    records~append(cur)
    blockOpen = s~right(1) == ':'
    traceback = s~left(34) == 'Traceback (most recent call last):'
  end

/* The stack frame in a line, or '': "at x.y(Y.java:42)", "Caused by: ...", "... 3 more", bare and indented
   or after a logger's " - " in a line with its own stamp. */
::method frameText
  use strict arg line
  t = line~translate(' ', '09'x)
  p = t~pos(' - ')
  cands = .array~of(t~strip)
  if p > 0 then cands~append(t~substr(p + 3)~strip)
  do c over cands
    if c~left(3) == 'at ' then if c~word(2)~pos('(') > 1 then if c~word(2)~right(1) == ')' then return c
    if c~left(10) == 'Caused by:' then return c
    if c~left(4) == '... ' then if c~word(3) == 'more' then return c
  end
  return ''

/* The thread of a line: the first [..] word after its first word ("[http-nio-8080-exec-2]"), or ''. */
::method threadOf
  use strict arg line
  ws = line~subWords
  do i = 2 to min(4, ws~items)
    w = ws[i]
    if w~left(1) == '[' then if w~right(1) == ']' then return w~substr(2, w~length - 2)
  end
  return ''

/* A line with a time stamp: as words (2026-10-30 20:34:01, Oct 30 20:34:01) or in its decorations ([0.001s]). */
::method stamped
  use strict arg line
  if .PiledriverWords~timestampWords(line~subWords) > 0 then return .true
  return self~decorations(line)['STAMP'] \== ''

/* Decorations: two or more [..] groups at the start of a line, as the JVM's unified logging writes them:
   [0.001s][info][os,thread].  A group is a STAMP (an uptime such as 0.001s or 12ms, or a time stamp), a LEVEL
   ([info], [warn], [error]), or else a TAG.  Spaces inside a group are padding: [gc        ] is the tag gc.
   Returns a directory COUNT STAMP LEVEL LEVELWORD TAGS REST; COUNT 0 when there are none. */
::method decorations
  use strict arg line
  d = .directory~new
  d['COUNT'] = 0; d['STAMP'] = ''; d['LEVEL'] = ''; d['LEVELWORD'] = ''; d['TAGS'] = ''; d['REST'] = line
  s = line~strip('L')
  groups = .array~new
  do while s~left(1) == '['
    p = s~pos(']')
    if p == 0 then leave
    groups~append(s~substr(2, p - 2)~strip)
    s = s~substr(p + 1)~strip('L')
  end
  if groups~items < 2 then return d
  stamp = ''; tags = ''
  do g over groups
    up = g
    if up~right(2) == 'ms' then up = up~left(up~length - 2)
    else if up~right(1) == 's' then up = up~left(up~length - 1)
    if datatype(up, 'N') then stamp = (stamp g)~strip
    else if .PiledriverWords~timestampWords(g~subWords) > 0 then stamp = (stamp g)~strip
    else if d['LEVEL'] == '' then if .PiledriverWords~level('[' || g || ']') \== '' then do
      d['LEVEL'] = .PiledriverWords~level('[' || g || ']')
      d['LEVELWORD'] = g
    end
    else tags = (tags g)~strip
    else tags = (tags g)~strip
  end
  if stamp == '' then if d['LEVEL'] == '' then return d
  d['COUNT'] = groups~items; d['STAMP'] = stamp; d['TAGS'] = tags; d['REST'] = s
  return d

/* key: value fields.  (id: 1024, name: main) when every item of the group is "key: value"; and one trailing
   "key: value ..." after the first word (java.lang.Object source: jrt:/java.base).  Each value is set aside in
   R~fields and its words are replaced by one marker word @F:key@, so the pattern does not depend on it. */
::method takeFields
  use strict arg r, words
  msg = words~makeString('L', ' ')
  out = ''
  do while msg \== ''
    a = msg~pos('(')
    if a == 0 then leave
    b = msg~pos(')', a)
    if b == 0 then leave
    inner = msg~substr(a + 1, b - a - 1)
    items = inner~makeArray(',')
    ok = items~items > 0
    keys = .array~new; vals = .array~new
    do it over items
      parse var it key ':' val
      key = key~strip; val = val~strip
      if key == '' | val == '' then ok = .false
      else if key~verify(xrange('a', 'z') || xrange('A', 'Z') || '_') \== 0 then ok = .false
      else if it~pos(':') == 0 then ok = .false
      keys~append(key); vals~append(val)
    end
    if ok then do
      repl = .array~new
      do i = 1 to keys~items
        r~fields[keys[i]] = vals[i]
        if r~fieldOrder~index(keys[i]) == .nil then r~fieldOrder~append(keys[i])
        repl~append(keys[i] || ': @F:' || keys[i] || '@')
      end
      out = out || msg~left(a) || repl~makeString('L', ', ') || ')'
    end
    else out = out || msg~left(b)
    msg = msg~substr(b + 1)
  end
  ws = (out || msg)~subWords
  n = ws~items
  do j = n - 1 to 2 by -1
    w = ws[j]
    if w~right(1) \== ':' then iterate
    key = w~left(w~length - 1)
    if key == '' then iterate
    if key~verify(xrange('a', 'z') || xrange('A', 'Z') || '_') \== 0 then iterate
    if .PiledriverWords~level(key) \== '' then iterate
    tail = ws~section(j + 1)~makeString('L', ' ')
    if tail~pos('@F:') > 0 then leave
    r~fields[key] = tail
    if r~fieldOrder~index(key) == .nil then r~fieldOrder~append(key)
    ws = ws~section(1, j)
    ws~append('@F:' || key || '@')
    leave
  end
  return ws

/* A heading that holds ERROR, FAILED, WARNING ... (as a level word) reports a result: it is a record. */
::method badLevelIn
  use strict arg text
  do w over text~subWords
    if wordpos(.PiledriverWords~level(w), 'FATAL ERROR WARN') > 0 then return .true
  end
  return .false

/* "INTCODE: -24", "SQLERRM: no such table": an upper-case key, a colon; not a level word (WARNING:). */
::method isUpperKeyLine
  use strict arg s
  parse var s key ':' .
  if key == '' then return .false
  if key~words \== 1 then return .false
  if s~pos(':') == 0 then return .false
  if key \== key~upper then return .false
  if .PiledriverWords~level(key) \== '' then return .false
  return key~verify(xrange('A', 'Z') || '0123456789_') == 0

/* Split each record's head into stamp, level and words; describe each word. */
::method analyseTokens
  expose records prefixed familyStats keyStats litKeyStats
  familyStats = .directory~new
  keyStats = .directory~new
  litKeyStats = .directory~new
  do r over records
    dec = self~decorations(r~head)
    if dec['COUNT'] > 0 then do
      r~stamp = dec['STAMP']
      r~tags = dec['TAGS']
      if dec['LEVEL'] \== '' then do
        r~level = dec['LEVEL']
        r~levelWord = dec['LEVELWORD']
      end
      rest = dec['REST']~subWords
    end
    else do
      ws = r~head~subWords
      k = .PiledriverWords~timestampWords(ws)
      if k > 0 then r~stamp = ws~section(1, k)~makeString('L', ' ')
      rest = ws~section(k + 1)
      if rest~items > 0 then do
        lev = .PiledriverWords~syslogLevel(rest[1])
        if lev \== '' then do
          r~level = lev
          r~levelWord = rest[1]
        end
        else do
          reach = 1
          if prefixed then reach = 5
          do j = 1 to min(reach, rest~items)
            lev = .PiledriverWords~level(rest[j])
            if lev \== '' then do
              r~level = lev
              r~levelWord = rest[j]
              leave
            end
          end
        end
      end
    end
    if dec['COUNT'] == 0 then r~context = self~threadOf(r~head)
    r~message = rest~makeString('L', ' ')
    if \r~heading then rest = self~takeFields(r, rest)
    r~tokens = self~describeWords(rest)
    do x = 2 to r~lines~items
      r~contTokens~append(self~describeWords(r~lines[x]~subWords))
    end
  end

/* Each word: a directory LEAD CORE TRAIL KIND (LIT CODE CODEVAL VAL) KEY FAMILY TEXT. */
::method describeWords
  expose familyStats keyStats litKeyStats
  use strict arg ws
  out = .array~new
  pendingKey = ''; pendingWord = ''
  do t over ws
    d = .directory~new
    d['TEXT'] = t
    lead = ''; trail = ''; core = t
    do while core \== ''
      if '([{<"'''~pos(core~left(1)) == 0 then leave
      lead = lead || core~left(1); core = core~substr(2)
    end
    do while core \== ''
      if ')]}>:;,."''!?'~pos(core~right(1)) == 0 then leave
      trail = core~right(1) || trail; core = core~left(core~length - 1)
    end
    d['LEAD'] = lead; d['CORE'] = core; d['TRAIL'] = trail; d['KEY'] = ''; d['FAMILY'] = ''
    kind = ''
    if pendingWord \== '' then do
      /* "Error 97.1:", "rc -1": a number right after a code word */
      if datatype(core, 'N') then do
        kind = 'CODEVAL'
        d['KEY'] = pendingWord
      end
      pendingWord = ''
    end
    if kind == '' then if pendingKey \== '' then do
      if .PiledriverWords~isCodeKey(pendingKey) then if .PiledriverWords~codeValue(pendingKey, core) then kind = 'CODEVAL'
      if kind == '' then do
        if core~verify('0123456789', 'M') > 0 then kind = 'VAL'
        else kind = 'LIT'
      end
      d['KEY'] = pendingKey
      pendingKey = ''
    end
    if kind == '' then do
      eq = core~pos('=')
      if eq > 1 then do
        key = core~left(eq - 1)
        val = core~substr(eq + 1)
        if val == '' then do
          pendingKey = key
          kind = 'LIT'
        end
        else do
          d['KEY'] = key
          d['CORE'] = val
          d['LEAD'] = lead || key || '='
          if .PiledriverWords~isCodeKey(key) then if .PiledriverWords~codeValue(key, val) then kind = 'CODEVAL'
          if kind == '' then do
            if val~verify('0123456789', 'M') > 0 then kind = 'VAL'
            else kind = 'LIT'
          end
        end
      end
    end
    if kind == '' then do
      if trail~left(1) == ':' then if .PiledriverWords~isCodeKey(core) then if core == core~upper then do
        pendingKey = core
        kind = 'LIT'
      end
    end
    if kind == '' then if .PiledriverWords~codeShaped(core) then do
      kind = 'CODE'
      d['FAMILY'] = .PiledriverWords~family(core)
    end
    if kind == '' then do
      if .PiledriverWords~isCodeWord(core) then if trail == '' then pendingWord = core
      if core~pos('://') > 0 then kind = 'VAL'
      else if .PiledriverWords~isPath(core) then kind = 'VAL'
      else if .PiledriverWords~isFile(core) then kind = 'VAL'
      else if core~verify('0123456789', 'M') > 0 then kind = 'VAL'
      else kind = 'LIT'
    end
    d['KIND'] = kind
    if kind == 'CODE' then call tally familyStats, d['FAMILY'], d['CORE']
    if kind == 'CODEVAL' then call tally keyStats, d['KEY']~upper, d['CORE']
    if kind == 'LIT' then if d['KEY'] \== '' then call tally litKeyStats, d['KEY']~upper, d['CORE']
    out~append(d)
  end
  return out

  tally: procedure
    use arg stats, key, value
    if \stats~hasIndex(key) then stats[key] = .array~of(0, .directory~new)
    entry = stats[key]
    entry[1] = entry[1] + 1
    if entry[2]~hasIndex(value) then entry[2][value] = entry[2][value] + 1
    else entry[2][value] = 1
    return

/* A family or key seen 8+ times with more distinct values than half the times is an identifier here. */
::method decideIdentifiers
  expose records familyStats keyStats identifiers litKeyStats statusKeys
  /* a named key whose word values are a small set holding an OK value is a STATUS key, found by counts */
  statusKeys = .directory~new
  do k over litKeyStats~allIndexes~sort
    entry = litKeyStats[k]
    uses = entry[1]; vals = entry[2]
    if uses < 5 then iterate
    if vals~items < 2 then iterate
    if vals~items > 12 then iterate
    if vals~items * 4 > uses then iterate
    oks = .array~new
    do v over vals~allIndexes~sort
      if .PiledriverWords~okValue(k, v) then oks~append(v)
    end
    how = 'OK value'
    if oks~items == 0 then if .PiledriverWords~isCodeKey(k) then do
      /* the name says status (status=done x11): its most used value, on half the uses or more, is normal */
      top = ''; topCount = 0
      do v over vals~allIndexes~sort
        if vals[v] > topCount then do
          top = v; topCount = vals[v]
        end
      end
      if topCount * 2 >= uses then do
        oks~append(top)
        how = 'the name says status; most used value'
      end
    end
    if oks~items == 0 then iterate
    statusKeys[k] = oks
    parts = .array~new
    do v over vals~allIndexes~sort
      parts~append(v || 'x' || vals[v])
    end
    identifiers~append('status key' k 'found by counts (' || how oks~makeString('L', ',') || '):' parts~makeString('L', ' '))
  end
  idFam = .directory~new; idKey = .directory~new
  do f over familyStats~allIndexes~sort
    entry = familyStats[f]
    if entry[1] >= 8 then if entry[2]~items * 2 > entry[1] then do
      idFam[f] = .true
      identifiers~append('family' f || ':' entry[2]~items 'distinct values in' entry[1] 'uses')
    end
  end
  do k over keyStats~allIndexes~sort
    entry = keyStats[k]
    if entry[1] >= 8 then if entry[2]~items * 2 > entry[1] then do
      idKey[k] = .true
      identifiers~append('key' k || ':' entry[2]~items 'distinct values in' entry[1] 'uses')
    end
  end
  do r over records
    call demote r~tokens
    do ct over r~contTokens
      call demote ct
    end
  end
  return

  demote:
    use arg toks
    do d over toks
      if d['KIND'] == 'CODE' then if idFam~hasIndex(d['FAMILY']) then d['KIND'] = 'VAL'
      if d['KIND'] == 'CODEVAL' then if idKey~hasIndex(d['KEY']~upper) then d['KIND'] = 'VAL'
    end
    return

/* The masked text of one word. */
::method piece
  use strict arg d
  if d['KIND'] == 'NAME' then return d['LEAD'] || '<name>' || d['TRAIL']
  if d['KIND'] \== 'VAL' then return d['LEAD'] || d['CORE'] || d['TRAIL']
  core = d['CORE']
  if core~pos('://') > 0 then m = .PiledriverWords~pathMask(core)
  else if .PiledriverWords~isPath(core) then m = .PiledriverWords~pathMask(core)
  else if .PiledriverWords~isFile(core) then m = '<FILE>'
  else m = .PiledriverWords~mask(core)
  return d['LEAD'] || m || d['TRAIL']

::method buildSkeletons
  expose records slotStats fieldStats namePositions
  slotStats = .directory~new; fieldStats = .directory~new; namePositions = .array~new
  do r over records
    parts = .array~new
    do d over r~tokens
      parts~append(self~piece(d))
    end
    r~parts = parts
  end
  /* NAME positions (Gemini's rule: a word that is new in each line is a name).  A plain word at one place
     in a pattern of 3+ words, with 2+ other plain words fixed around it, new in each of 3+ lines. */
  nameStats = .directory~new
  wild = .array~new                 /* every key first, from the parts as they are; then apply (no key moves) */
  do r over records
    if r~heading then iterate
    n = r~parts~items
    if n < 3 then iterate
    do j = 1 to n
      if \self~nameCandidate(r, j) then iterate
      key = self~wildKey(r, j)
      if key == '' then iterate
      wild~append(.array~of(r, j, key))
      if \nameStats~hasIndex(key) then nameStats[key] = .array~of(0, .directory~new)
      entry = nameStats[key]
      entry[1] = entry[1] + 1
      entry[2][r~tokens[j]['CORE']] = 1
    end
  end
  do w over wild
    r = w[1]; j = w[2]; key = w[3]
    entry = nameStats[key]
    if entry[1] < 3 then iterate
    if entry[2]~items \== entry[1] then iterate
    d = r~tokens[j]
    d['KIND'] = 'NAME'
    r~parts[j] = self~piece(d)
    if namePositions~index(key) == .nil then namePositions~append(key)
  end
  do r over records
    r~skeleton = r~parts~makeString('L', ' ')
  end
  /* FIELD kinds, by pattern and key (Gemini's rule): CODE when the value is in half the lines of the pattern
     or more, and seen twice or more (a value seen once is new, so it is a NAME, also in a pattern of two
     lines); NAME when it is new (once); REPEAT when it is neither. */
  do r over records
    do k over r~fieldOrder
      fk = r~skeleton || '00'x || k
      if \fieldStats~hasIndex(fk) then fieldStats[fk] = .array~of(0, .directory~new)
      entry = fieldStats[fk]
      entry[1] = entry[1] + 1
      v = r~fields[k]
      if entry[2]~hasIndex(v) then entry[2][v] = entry[2][v] + 1
      else entry[2][v] = 1
    end
  end
  do r over records
    do k over r~fieldOrder
      entry = fieldStats[r~skeleton || '00'x || k]
      c = entry[2][r~fields[k]]
      if c >= 2 then if c * 2 >= entry[1] then do
        r~fieldKinds[k] = 'CODE'
        iterate
      end
      if c == 1 then r~fieldKinds[k] = 'NAME'
      else r~fieldKinds[k] = 'REPEAT'
    end
  end
  do r over records
    if r~heading then iterate
    do j = 1 to r~tokens~items
      d = r~tokens[j]
      if d['KIND'] \== 'VAL' then iterate
      if d['KEY'] \== '' then iterate
      if \.PiledriverWords~shortCode(d['CORE']) then iterate
      key = r~skeleton || '00'x || j
      if \slotStats~hasIndex(key) then slotStats[key] = .array~of(0, .directory~new, r~skeleton, j)
      entry = slotStats[key]
      entry[1] = entry[1] + 1
      vals = entry[2]
      if vals~hasIndex(d['CORE']) then vals[d['CORE']] = vals[d['CORE']] + 1
      else vals[d['CORE']] = 1
    end
  end

/* A plain word with no field marker, at a place where a name can be. */
::method nameCandidate
  use strict arg r, j
  d = r~tokens[j]
  if d['KIND'] \== 'LIT' then return .false
  if d['KEY'] \== '' then return .false
  if d['CORE'] == '' then return .false
  if d['CORE']~pos('@F:') > 0 then return .false
  if d['TEXT'] == r~levelWord then return .false
  return .true

/* The pattern with place J left open, keyed by the tags; '' when fewer than 2 other plain words are fixed. */
::method wildKey
  use strict arg r, j
  fixed = 0
  key = r~tags || '00'x || r~parts~items
  do i = 1 to r~parts~items
    if i == j then key = key || '00'x || '*'
    else do
      key = key || '00'x || r~parts[i]
      if r~tokens[i]['KIND'] == 'LIT' then fixed += 1
    end
  end
  if fixed < 2 then return ''
  return key

/* A masked whole number at one place in one pattern: 5+ uses, at most 12 values, 4+ uses per value. */
::method findSlots
  expose slotStats slots slotIndex
  slotIndex = .directory~new
  do key over slotStats~allIndexes~sort
    entry = slotStats[key]
    uses = entry[1]; vals = entry[2]
    if uses < 5 then iterate
    if vals~items > 12 then iterate
    if vals~items * 4 > uses then iterate
    http = .true
    top = ''; topCount = 0
    do v over vals~allIndexes~sort
      if v < 100 | v > 599 then http = .false
      if vals[v] > topCount then do
        top = v; topCount = vals[v]
      end
    end
    slot = .directory~new
    slot['SKELETON'] = entry[3]; slot['POS'] = entry[4]; slot['USES'] = uses; slot['VALUES'] = vals
    slot['HTTP'] = http; slot['TOP'] = top; slot['TOPCOUNT'] = topCount
    slot['CONSTANT'] = vals~items == 1
    slots~append(slot)
    slotIndex[key] = slot
  end

::method finishTemplates
  expose records slotIndex
  do r over records
    parts = .array~new
    do j = 1 to r~tokens~items
      d = r~tokens[j]
      key = r~skeleton || '00'x || j
      isSlot = .false
      if slotIndex~hasIndex(key) then if slotIndex[key]['VALUES']~hasIndex(d['CORE']) then isSlot = .true
      if isSlot then do
        d['KIND'] = 'SLOT'
        d['SLOT'] = slotIndex[key]
        parts~append(d['LEAD'] || d['CORE'] || d['TRAIL'])
      end
      else parts~append(r~parts[j])
    end
    t = parts~makeString('L', ' ')
    do k over r~fieldOrder
      if r~fieldKinds[k] == 'CODE' then t = t~changeStr('@F:' || k || '@', r~fields[k])
      else t = t~changeStr('@F:' || k || '@', '<' || k || '>')
    end
    if r~tags \== '' then t = '[' || r~tags || ']' t
    r~template = t
    if r~template == '' then r~template = '(empty)'
    codes = r~codes
    call collect r~tokens
    do ct over r~contTokens
      call collect ct
    end
    if codes~items == 0 then r~signature = r~template
    else r~signature = r~template '{' || codes~makeString('L', ' ') || '}'
  end
  return

  collect:
    use arg toks
    do d over toks
      if d['KIND'] == 'CODE' then codes~append(d['CORE'])
      if d['KIND'] == 'CODEVAL' then codes~append(d['KEY']~upper || '=' || d['CORE'])
    end
    return

/* The verdict of one record, with its reasons. */
::method judge
  expose statusKeys
  use strict arg r
  if r~heading then do
    r~verdict = 'NONE'
    r~reasons~append('HEADING')
    return
  end
  errs = .array~new; warns = .array~new
  strong = .false; weakOnly = .true; hasCode = .false
  /* stack traces */
  do x = 2 to r~lines~items
    s = r~lines[x]~strip
    stack = self~frameText(r~lines[x]) \== ''
    if s~left(6) == 'File "' then if s~pos(', line ') > 0 then stack = .true
    if s~left(34) == 'Traceback (most recent call last):' then stack = .true
    if stack then do
      errs~append('STACK')
      leave
    end
  end
  if r~head~strip~left(34) == 'Traceback (most recent call last):' then errs~append('STACK')
  /* codes */
  all = .array~new
  do d over r~tokens
    all~append(d)
  end
  do ct over r~contTokens
    do d over ct
      all~append(d)
    end
  end
  do d over all
    if d['KIND'] == 'CODEVAL' then do
      hasCode = .true
      if \.PiledriverWords~okValue(d['KEY'], d['CORE']) then errs~append('CODE' d['KEY']~upper || '=' || d['CORE'])
    end
    if d['KIND'] == 'CODE' then hasCode = .true
    if d['KIND'] == 'LIT' then if d['KEY'] \== '' then if statusKeys~hasIndex(d['KEY']~upper) then do
      hasCode = .true
      if statusKeys[d['KEY']~upper]~index(d['CORE']) == .nil then errs~append('STATUS' d['KEY']~upper || '=' || d['CORE'] '(key found by counts)')
    end
    if d['KIND'] == 'SLOT' then do
      slot = d['SLOT']
      v = d['CORE']
      if slot['CONSTANT'] then nop
      else if slot['HTTP'] then do
        if v >= 500 then errs~append('HTTP' v)
        else if v >= 400 then warns~append('HTTP' v)
      end
      else if v \== slot['TOP'] then if slot['TOPCOUNT'] * 2 >= slot['USES'] then if slot['VALUES'][v] * 20 < slot['USES'] then warns~append('RARE_CODE' v)
    end
  end
  if errs~items > 0 then weakOnly = .false
  /* keywords: the plain words (LIT) of the head line, not the level word, not paths, files or values */
  words = .array~new
  levelDropped = .false
  do d over r~tokens
    if d['KIND'] \== 'LIT' then iterate
    if d['KEY'] \== '' then iterate          /* error=false: a key names a field; it is not an event */
    if \levelDropped then if d['TEXT'] == r~levelWord then do
      levelDropped = .true
      iterate
    end
    words~append(d['TEXT'])
  end
  text = words~makeString('L', ' ')
  do hit over .PiledriverWords~keywords(text)
    parse var hit kind word
    errs~append('KEYWORD' word)
    if kind == 'S' then weakOnly = .false
  end
  if hasCode then weakOnly = .false
  /* the level */
  lev = r~level
  if lev == 'FATAL' | lev == 'ERROR' then do
    errs~append('LEVEL' r~levelWord~strip('B', '[]<>:')~upper)
    weakOnly = .false
  end
  if lev == 'WARN' then warns~append('LEVEL' r~levelWord~strip('B', '[]<>:')~upper)
  positive = wordpos(lev, 'OK INFO DEBUG') > 0
  do e over errs
    if r~reasons~index(e) == .nil then r~reasons~append(e)
  end
  do w over warns
    if r~reasons~index(w) == .nil then r~reasons~append(w)
  end
  if positive then do
    if errs~items + warns~items > 0 then r~verdict = 'MENTION'
    else r~verdict = lev
    return
  end
  if errs~items > 0 then do
    r~verdict = 'ERROR'
    if weakOnly then r~strength = 'WEAK'
    else r~strength = 'STRONG'
    return
  end
  if warns~items > 0 then do
    r~verdict = 'WARN'
    r~strength = 'STRONG'
    return
  end
  r~verdict = 'NONE'

/* Seen before, status and transitions. */
::method remember
  expose records counts sigCounts firstAt order verdictOf edges catalog catalogSigs
  prev = ''
  do r over records
    t = r~template
    if counts~hasIndex(t) then r~seen = counts[t]
    else r~seen = 0
    if r~seen == 0 then do
      if catalog~hasIndex(t) then r~status = 'KNOWN'
      else r~status = 'NEW'
      order~append(t)
      firstAt[t] = r
    end
    else do
      known = sigCounts~hasIndex(r~signature)
      if \known then known = catalogSigs~hasIndex(r~signature)
      if known then r~status = 'REPEAT'
      else r~status = 'NEW_CODES'
    end
    if r~seen == 0 then if r~status == 'KNOWN' then if \catalogSigs~hasIndex(r~signature) then r~status = 'NEW_CODES'
    counts[t] = r~seen + 1
    if sigCounts~hasIndex(r~signature) then sigCounts[r~signature] = sigCounts[r~signature] + 1
    else sigCounts[r~signature] = 1
    worst = r~verdict
    if verdictOf~hasIndex(t) then if self~worse(verdictOf[t], worst) then worst = verdictOf[t]
    verdictOf[t] = worst
    if prev \== '' then do
      e = prev || '0a'x || t
      if edges~hasIndex(e) then edges[e] = edges[e] + 1
      else edges[e] = 1
    end
    prev = t
  end
  prev = .nil
  do r over records
    if prev \== .nil then do
      e = prev~template || '0a'x || r~template
      if counts[prev~template] >= 10 then if edges[e] == 1 then if counts[r~template] > 1 then r~rare = 'after' prev~template '(seen' counts[prev~template] 'times), this follows it once'
    end
    prev = r
  end

::method worse
  use strict arg a, b
  order = 'ERROR WARN MENTION OK INFO DEBUG NONE'
  return wordpos(a, order) < wordpos(b, order)

/* --- questions ------------------------------------------------------------------------------------ */

::method errors
  expose records
  use strict arg verdicts = 'ERROR'
  out = .array~new
  do r over records
    if wordpos(r~verdict, verdicts) > 0 then out~append(r)
  end
  return out

::method recordAt
  expose records
  use strict arg lineNo
  do r over records
    if r~lineNo <= lineNo then if r~lastLine >= lineNo then return r
  end
  return .nil

/* Paths of things (threads) through the log.  A thing is the value of field IDKEY; its name is field NAMEKEY.
   A record mentions a thing when its IDKEY field is the id, or a word of it is the id ("(1031)"), or it holds
   the thing's name as words ("pool-1-thread-2").  The thing's state in that record is the value of field
   STATEKEY (lower case), or, in a record with fields, the last word before them ("attached"), or else the
   first three words ("deadlock_risk_detected").  Edges are the steps from one state to the next, START first.
   Returns a directory: PATHS id -> array of states; LINES id -> array of line numbers; NAMES id -> name;
   EDGES "a -> b" -> count; ORDER the ids in the order first seen. */
::method entityPaths
  expose records
  use strict arg idKey = 'id', nameKey = 'name', stateKey = 'state'
  out = .directory~new
  paths = .directory~new; lineNos = .directory~new; names = .directory~new; edges = .directory~new; order = .array~new
  out['PATHS'] = paths; out['LINES'] = lineNos; out['NAMES'] = names; out['EDGES'] = edges; out['ORDER'] = order
  do r over records
    if r~fields~hasIndex(idKey) then do
      id = r~fields[idKey]
      if \paths~hasIndex(id) then do
        paths[id] = .array~new; lineNos[id] = .array~new; order~append(id)
      end
      if r~fields~hasIndex(nameKey) then names[id] = r~fields[nameKey]
    end
  end
  do r over records
    words = ' ' || r~message~translate('  ', '(),') || ' '
    do id over order
      hit = .false
      if r~fields~hasIndex(idKey) then if r~fields[idKey] == id then hit = .true
      if \hit then if words~pos(' ' || id || ' ') > 0 then hit = .true
      if \hit then if names~hasIndex(id) then if words~pos(' ' || names[id] || ' ') > 0 then hit = .true
      if \hit then iterate
      paths[id]~append(self~stateOf(r, stateKey))
      lineNos[id]~append(r~lineNo)
    end
  end
  do id over order
    prev = 'START'
    do st over paths[id]
      e = prev '->' st
      if edges~hasIndex(e) then edges[e] = edges[e] + 1
      else edges[e] = 1
      prev = st
    end
  end
  return out

::method stateOf
  use strict arg r, stateKey
  if r~fields~hasIndex(stateKey) then return r~fields[stateKey]~lower
  before = .array~new
  do d over r~tokens
    if d['LEAD']~pos('(') > 0 then leave
    if d['CORE']~pos('@F:') > 0 then leave
    before~append(d['CORE']~lower)
  end
  if r~fields~items > 0 then if before~items > 0 then return before[before~items]
  return before~section(1, min(3, before~items))~makeString('L', '_')

/* A rule on pairs: each record holding OPENTEXT must have a record holding CLOSETEXT after it, before the next
   OPENTEXT record or the end.  Returns a directory RESULT (.true/.false), PAIRS (array "open close" line
   numbers), FAIL (the line number of the first open with no close, or 0), PROOF (text). */
::method pairRule
  expose records
  use strict arg openText, closeText
  out = .directory~new
  pairs = .array~new
  out['PAIRS'] = pairs; out['FAIL'] = 0; out['RESULT'] = .true
  open = 0
  do r over records
    if r~message~pos(openText) > 0 then do
      if open > 0 then do
        out['RESULT'] = .false; out['FAIL'] = open
        out['PROOF'] = 'the' openText 'at line' open 'is followed by another at line' r~lineNo 'with no' closeText 'between them'
        return out
      end
      open = r~lineNo
    end
    else if r~message~pos(closeText) > 0 then do
      if open > 0 then pairs~append(open r~lineNo)
      open = 0
    end
  end
  if open > 0 then do
    out['RESULT'] = .false; out['FAIL'] = open
    out['PROOF'] = 'the' openText 'at line' open 'has no' closeText 'before the end of the log'
    return out
  end
  out['PROOF'] = pairs~items 'pairs, each' openText 'closed before the next one:' pairs~makeString('L', ', ')
  return out

/* The values of field KEY in order: an array of directories LINE VALUE CONTEXT MESSAGE BODY. */
::method fieldSeries
  expose records
  use strict arg key
  out = .array~new
  do r over records
    if \r~fields~hasIndex(key) then iterate
    d = .directory~new
    d['LINE'] = r~lineNo; d['VALUE'] = r~fields[key]; d['CONTEXT'] = r~context; d['MESSAGE'] = r~message; d['BODY'] = r~body
    out~append(d)
  end
  return out

/* Records with field KEY, grouped by its value: directory value -> array of "line thing", where the thing is
   the record's first word. */
::method groupBy
  expose records
  use strict arg key
  out = .directory~new
  do r over records
    if \r~fields~hasIndex(key) then iterate
    v = r~fields[key]
    if \out~hasIndex(v) then out[v] = .array~new
    out[v]~append(r~lineNo r~message~word(1))
  end
  return out

/* The memory between files. */
::method loadCatalog
  expose catalog catalogSigs
  use strict arg path
  if \.File~new(path)~exists then return 0
  s = .stream~new(path)
  s~open('read')
  n = 0
  do line over s~arrayIn
    line = line~strip('T', '0d'x)
    parse var line kind '09'x count '09'x verdict '09'x text
    if kind == 'T' then catalog[text] = count verdict
    if kind == 'S' then catalogSigs[text] = count
    n += 1
  end
  s~close
  return n

/* Add this file's templates and signatures to the catalog (in memory), then write it. */
::method saveCatalog
  expose catalog catalogSigs counts sigCounts verdictOf merged
  use strict arg path
  if merged \== .true then call merge
  merged = .true
  out = .array~new
  do t over catalog~allIndexes~sort
    parse value catalog[t] with c v
    out~append('T' || '09'x || c || '09'x || v || '09'x || t)
  end
  do sg over catalogSigs~allIndexes~sort
    out~append('S' || '09'x || catalogSigs[sg] || '09'x || '-' || '09'x || sg)
  end
  call SysFileDelete path
  s = .stream~new(path)
  s~open('write replace')
  s~arrayOut(out)
  s~close
  return out~items

  /* this file's counts into the catalog, once (a second save writes the same catalog again) */
  merge:
  do t over counts
    before = 0; v = verdictOf[t]
    if catalog~hasIndex(t) then do
      parse value catalog[t] with before oldV
      if self~worse(oldV, v) then v = oldV
    end
    catalog[t] = before + counts[t] v
  end
  do sg over sigCounts
    before = 0
    if catalogSigs~hasIndex(sg) then before = catalogSigs[sg]
    catalogSigs[sg] = before + sigCounts[sg]
  end
  return

/* Templates in the catalog that this file does not have: what went away. */
::method gone
  expose catalog counts
  out = .array~new
  do t over catalog~allIndexes~sort
    if \counts~hasIndex(t) then do
      parse value catalog[t] with c v
      out~append(.array~of(t, c, v))
    end
  end
  return out

/* Templates of this file not in the catalog: what is new. */
::method arrived
  expose order catalog counts verdictOf
  out = .array~new
  do t over order
    if \catalog~hasIndex(t) then out~append(.array~of(t, counts[t], verdictOf[t]))
  end
  return out

/* A report in lines. */
::method report
  expose name records counts order verdictOf slots identifiers prefixed lineCount
  use strict arg most = 12
  out = .array~new
  nErr = 0; nWarn = 0; nMention = 0; nNew = 0; nStrong = 0
  sections = .directory~new; sectionOrder = .array~new
  do r over records
    if r~verdict == 'ERROR' then do
      nErr += 1
      if r~strength == 'STRONG' then nStrong += 1
      sec = r~section
      if sec == '' then sec = '(no section)'
      if \sections~hasIndex(sec) then do
        sections[sec] = 0
        sectionOrder~append(sec)
      end
      sections[sec] = sections[sec] + 1
    end
    if r~verdict == 'WARN' then nWarn += 1
    if r~verdict == 'MENTION' then nMention += 1
  end
  mode = 'unprefixed'
  if prefixed then mode = 'prefixed (time stamps)'
  out~append('piledriver:' name)
  out~append('  lines' lineCount '  records' records~items '  templates' counts~items '  mode' mode)
  out~append('  errors' nErr '(strong' nStrong || ')  warnings' nWarn '  mentions' nMention)
  out~append('templates, most used first:')
  ranked = .array~new
  do t over order
    ranked~append(counts[t]~right(8, '0') || '09'x || t)
  end
  ranked = ranked~sortWith(.DescendingComparator~new)
  do i = 1 to min(most, ranked~items)
    parse value ranked[i] with c '09'x t
    out~append('  ' || format(c)~right(6) verdictOf[t]~left(8) t)
  end
  constants = 0
  do slot over slots
    if slot['CONSTANT'] then constants += 1
  end
  if constants > 0 then out~append('constants put back (one value, 5+ uses):' constants)
  if slots~items > constants then do
    out~append('code slots (found by counts):')
    do slot over slots
      if slot['CONSTANT'] then iterate
      vals = .array~new
      do v over slot['VALUES']~allIndexes~sort
        vals~append(v || 'x' || slot['VALUES'][v])
      end
      kind = 'CODE'
      if slot['HTTP'] then kind = 'HTTP'
      out~append('  ' kind 'word' slot['POS'] 'of "' || slot['SKELETON'] || '":' vals~makeString('L', ' '))
    end
  end
  if identifiers~items > 0 then do
    out~append('decided by counts:')
    do x over identifiers
      out~append('  ' x)
    end
  end
  if nErr > 0 then do
    out~append('errors by section:')
    do sec over sectionOrder
      out~append('  ' || sections[sec]~right(5) sec)
    end
    out~append('errors (first' most || '):')
    shown = 0
    do r over records
      if r~verdict \== 'ERROR' then iterate
      shown += 1
      if shown > most then leave
      out~append('  ' r~describe)
    end
  end
  rares = 0
  do r over records
    if r~rare \== '' then do
      if rares == 0 then out~append('rare transitions:')
      rares += 1
      if rares <= most then out~append('  line' r~lineNo || ':' r~template '-' r~rare)
    end
  end
  return out
