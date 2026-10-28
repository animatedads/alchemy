/* slam.rex - SLAM v0.1 command line.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 *   rexx slam.rex ingest DB DIR [DIR...]     segment every .cls/.rex/.rexx/.orx and .java file into the store
 *                                            (each file by its own language's reader, into the same nodes)
 *   rexx slam.rex corpus DB CSV              load a circular corpus (word,category,definition)
 *   rexx slam.rex stats DB                   counts and the most common nodes
 *   rexx slam.rex node DB NODE               one node: its shape and where it occurs
 *   rexx slam.rex follows DB NODE            best next nodes (TESTED before PRIOR)
 *   rexx slam.rex into DB NODE               best ways into a node
 *   rexx slam.rex record DB FROM TO PASS|FAIL
 *   rexx slam.rex ground DB                check the maths anchors; record each check on word -> code
 *   rexx slam.rex ask DB SENTENCE | V1 V2..  run a request in SLAM's words over the values
 *   rexx slam.rex read DB DOC              read a document with SLAM's own vocabulary (its WORD nodes);
 *                                            'word: definition' lines add words; ``` blocks are code, not words
 *   rexx slam.rex facts DB DOC             read DOC as above; if each word is known, also store each text line
 *                                            as a FACT about the SUBJECT named by the code block before it;
 *                                            'the code:' / 'the result:' / 'the reference says:' blocks are one
 *                                            EXAMPLE with its RESULT and REFERENCE
 *   rexx slam.rex about DB SUBJECT         the facts and examples stored about SUBJECT (any case)
 * NODE is a display id (#00EF), a numeric id, or a canonical text.
 */
signal on syntax name onSyntax
parse arg cmd db rest
cmd = cmd~lower
if cmd == '' | db == '' then do
  say 'usage: rexx slam.rex ingest|corpus|read|facts|about|ground|ask|stats|node|follows|into|record DB ...'
  exit 2
end
store = .SlamStore~new(db)
select
  when cmd == 'ingest' then call ingest store, rest
  when cmd == 'corpus' then call corpus store, rest~strip
  when cmd == 'read' then call readDoc store, rest~strip
  when cmd == 'facts' then call readFacts store, rest~strip
  when cmd == 'about' then call about store, rest~strip
  when cmd == 'ground' then do
    r = .SlamGround~qualify(store)
    say 'anchor checks:' r[1] 'of' r[2] 'true'
    do w over .SlamGround~anchors~allIndexes~sort
      d = store~rate(store~wordId(w), .SlamGround~codeNode(store, .SlamGround~anchors[w]))
      say '  ' w~left(11) '-> SlamMaths~' || .SlamGround~anchors[w]~lower~left(10) d['TIER'] format(d['RATE'], , 2) '(' || d['PASSES'] || '/' || d['TRIALS'] || ')'
    end
  end
  when cmd == 'ask' then do
    parse var rest sentence '|' nums
    vals = .array~new
    do k = 1 to nums~words; vals~append(nums~word(k)); end
    a = .SlamGround~ask(store, sentence~strip, vals)
    select
      when a['STATUS'] == 'OK' then do
        say 'i do:' a['OPS']~makeString('L', ', then ')~changestr(', then ', ' <- ')
        say 'the result is' a['RESULT']~makeString('L', ' ')
      end
      when a['STATUS'] == 'UNKNOWN_WORDS' then say 'some words here are not words i know:' a['UNKNOWN']~makeString('L', ' ')
      when a['STATUS'] == 'NOTHING_TO_RUN' then say 'i know each word, but no word here is one i can run.'
      when a['STATUS'] == 'NOT_TESTED' then say 'i do not run' a['WORD'] || ': it is not tested.'
      when a['STATUS'] == 'TEST_FAILED' then say 'i do not run' a['WORD'] || ': a test of it is false.'
      otherwise say 'error:' a['DETAIL']
    end
  end
  when cmd == 'stats' then call stats store
  when cmd == 'node' then call node store, rest~strip
  when cmd == 'follows' then call edgesOut store, rest~strip, 'OUT'
  when cmd == 'into' then call edgesOut store, rest~strip, 'IN'
  when cmd == 'record' then do
    parse var rest f t outcome .
    store~record(f, t, outcome~upper == 'PASS')
    d = store~rate(f, t)
    say 'edge' f '->' t ':' d['TIER'] 'rate' format(d['RATE'], , 3) '(' || d['PASSES'] || '/' || d['TRIALS'] || ')'
  end
  otherwise do
    say 'unknown command' cmd
    store~close
    exit 2
  end
end
store~close
exit 0

ingest: procedure
  use arg store, dirs
  readers = .directory~new                                  /* one splitter and segmenter per language */
  do lang over .array~of('REXX', 'JAVA')
    readers[lang] = .array~of(.SlamLanguages~splitter(lang), .SlamLanguages~segmenter(lang))
  end
  files = 0; skipped = 0; units = 0; dupes = 0; segsTotal = 0
  call time 'R'
  do d = 1 to dirs~words
    call SysFileTree dirs~word(d) || '/*', 'f.', 'FSO'
    do i = 1 to f.0
      lang = .SlamLanguages~of(f.i)
      if lang == '' then iterate
      r = ingestFile(store, readers[lang][1], readers[lang][2], f.i)
      if r == .nil then do
        skipped += 1
        iterate
      end
      files += 1; units += r[1]; dupes += r[2]; segsTotal += r[3]
    end
  end
  secs = time('E')
  say 'files' files ' skipped' skipped ' units' units ' duplicate units' dupes ' segments' segsTotal ' seconds' format(secs, , 1)
  return

ingestFile: procedure
  use arg store, splitter, segmenter, file
  signal on syntax name fileFailed
  if store~scalar('SELECT count(*) AS n FROM unit WHERE path = ?', store~binds(file)) > 0 then return .array~of(0, 0, 0)
  text = charin(file, 1, chars(file))
  call stream file, 'C', 'CLOSE'
  unitList = splitter~split(text)
  store~begin
  n = 0; dup = 0; segCount = 0
  do u over unitList
    segs = segmenter~segmentUnit(u)
    if segs~items == 0 then iterate
    if store~ingestUnit(file, u, segs) == 0 then do
      dup += 1
      iterate
    end
    n += 1
    do s over segs
      segCount += s~size
    end
  end
  store~commit
  return .array~of(n, dup, segCount)
fileFailed:
  say 'skip' file ': rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  if store~inTransaction then store~rollback
  return .nil

corpus: procedure
  use arg store, file
  store~begin
  words = 0
  call linein file
  do while lines(file) > 0
    line = linein(file)~strip('T', '0d'x)
    if line = '' then iterate
    parse var line word ',' cat ',' rest
    if rest~left(1) == '"' then rest = rest~substr(2, rest~length - 2)~changestr('""', '"')
    clean = rest~lower~translate('        ', ';:,.()"''')
    segs = .array~new
    do k = 1 to clean~words
      w = clean~word(k)
      s = .SlamSegment~new('WORD', 0)
      s~fine = 'WORD: ' || w
      s~family = 'WORD'
      segs~append(s)
    end
    u = .SlamUnit~new('WORD', cat, word~lower, 0)
    sig = 'WORD:' || word~lower
    uid = store~unitInsert(file, 'WORD', cat, word~lower, 0, sig)
    ignored = store~wordId(word)
    if uid \== 0 then do
      store~ingestSeq(uid, 0, 'DEF', segs)
      words += 1
    end
  end
  call stream file, 'C', 'CLOSE'
  store~commit
  say 'corpus words loaded:' words
  return

/* SLAM reads a document. Its vocabulary is its own WORD nodes. A line "word: definition" whose word is
   new adds that word, but only if every word of the definition is already known (the word itself may
   appear). Everything else must use known words. Lines between ``` fences are code and are skipped. */
readDoc: procedure
  use arg store, file
  vocab = .directory~new
  r = store~q("SELECT canon AS canon FROM shape WHERE kind = 'WORD'")
  do row over r~rows
    vocab[row['CANON']~substr(7)] = .true
  end
  if vocab~items == 0 then do
    say 'i have no words: load a corpus first'
    return .false
  end
  baseCount = vocab~items
  inCode = .false; lineNo = 0; codeLines = 0; textWords = 0
  unknown = .array~new; defs = .array~new
  do while lines(file) > 0
    line = linein(file)~strip('T', '0d'x)
    lineNo += 1
    s = line~strip
    if s~left(3) == '```' then do
      inCode = \inCode
      iterate
    end
    if inCode then do
      codeLines += 1
      iterate
    end
    parse var s head ':' tail
    isDef = .false
    if tail \== '' then if head~words == 1 then if datatype(head, 'M') then if \vocab~hasIndex(head~lower) then isDef = .true
    if isDef then do
      w = head~lower
      vocab[w] = .true
      ws = cleanWords(tail)
      do x over ws
        if \vocab~hasIndex(x) then unknown~append(lineNo || ': ' || x '(in the definition of' w || ')')
      end
      defs~append(.array~of(w, ws))
      iterate
    end
    do x over cleanWords(s)
      if datatype(x, 'N') then iterate      /* a numeral is a value, not a word */
      textWords += 1
      if \vocab~hasIndex(x) then unknown~append(lineNo || ': ' || x)
    end
  end
  call stream file, 'C', 'CLOSE'
  say 'lines' lineNo ' code lines' codeLines ' words read' textWords ' known words' baseCount ' new words' defs~items
  if unknown~items > 0 then do
    say 'some words here are not words i know:'
    do u over unknown
      say '  ' u
    end
    return .false
  end
  store~begin
  do d over defs
    uid = store~unitInsert(file, 'WORD', 'read', d[1], 0, 'WORD:' || d[1])
    ignored = store~wordId(d[1])
    if uid \== 0 then do
      segs = .array~new
      do x over d[2]
        sg = .SlamSegment~new('WORD', 0)
        sg~fine = 'WORD: ' || x
        sg~family = 'WORD'
        segs~append(sg)
      end
      store~ingestSeq(uid, 0, 'DEF', segs)
    end
  end
  store~commit
  say 'i know each word here. i can read all of it.'
  return .true

/* Facts. A document that SLAM can read (readDoc gives .true) is read again.
   A code block after a blank line or a heading names the SUBJECT (subjectOf its first line: 'SUBSTR',
   'PARSE ARG', 'Error 40', '.String~pos', '::CLASS'). A code block right after a text line names a part of the
   subject (an option, a sub keyword): the subject becomes the main subject and that name ('STREAM OPEN').
   Three text lines mark an example instead, and are not facts:
     the code:             the next code block is the code of an example of the subject (EXAMPLE)
     the result:           the next code block is what that code printed when it was run, or 'not run' (RESULT)
     the reference says:   the next code block is what the reference says the code gives (REFERENCE)
   The three units of one example share the line number of its 'the code:' line, in their sig
   (EXAMPLE:file:line, RESULT:file:line, REFERENCE:file:line), so a second run stores nothing new.
   Every other line outside code (not a heading, not blank) is a FACT about the subject: a unit of kind FACT
   whose sequence is its words (numerals are VALUE nodes, not words), so facts also give word -> word edges.
   A fact before the first code block has the subject '-'. */
readFacts: procedure
  use arg store, file
  if \readDoc(store, file) then return
  subject = '-'; main = '-'; inCode = .false; mode = ''; pending = ''; first = .false; prevBlank = .true
  lineNo = 0; exLine = 0; facts = 0; examples = 0
  nl = '0a'x
  store~begin
  do while lines(file) > 0
    line = linein(file)~strip('T', '0d'x)
    lineNo += 1
    s = line~strip
    if s~left(3) == '```' then do
      inCode = \inCode
      if inCode then do
        mode = pending
        if mode == '' then do
          if prevBlank then mode = 'SUBJECT'
          else mode = 'PART'
        end
        pending = ''
        buf = ''
        first = .true
        iterate
      end
      if wordpos(mode, 'EXAMPLE RESULT REFERENCE') > 0 then do
        uid = store~unitInsert(file, mode, subject, buf, exLine, mode || ':' || file || ':' || exLine)
        if mode == 'EXAMPLE' then if uid \== 0 then examples += 1
      end
      mode = ''
      prevBlank = .false
      iterate
    end
    if inCode then do
      if mode == 'SUBJECT' then do
        if first then do
          main = subjectOf(s)
          subject = main
        end
        first = .false
        iterate
      end
      if mode == 'PART' then do
        if first then subject = partOf(main, s)
        first = .false
        iterate
      end
      if first then buf = line
      else buf = buf || nl || line
      first = .false
      iterate
    end
    prevBlank = .false
    if s == '' then do
      prevBlank = .true
      iterate
    end
    if s~left(1) == '#' then do
      prevBlank = .true
      iterate
    end
    if s == 'the code:' then do
      pending = 'EXAMPLE'
      exLine = lineNo
      iterate
    end
    if s == 'the result:' then do
      pending = 'RESULT'
      iterate
    end
    if s == 'the reference says:' then do
      pending = 'REFERENCE'
      iterate
    end
    segs = .array~new
    do x over cleanWords(s)
      if datatype(x, 'N') then do
        sg = .SlamSegment~new('VALUE', lineNo)
        sg~fine = 'VALUE: ' || x
        sg~family = 'VALUE'
      end
      else do
        sg = .SlamSegment~new('WORD', lineNo)
        sg~fine = 'WORD: ' || x
        sg~family = 'WORD'
      end
      segs~append(sg)
    end
    if segs~items == 0 then iterate
    uid = store~unitInsert(file, 'FACT', subject, '', lineNo, 'FACT:' || file || ':' || lineNo)
    if uid \== 0 then do
      store~ingestSeq(uid, 0, 'FACT', segs)
      facts += 1
    end
  end
  call stream file, 'C', 'CLOSE'
  store~commit
  say 'facts stored' facts ' examples stored' examples
  return

/* The name in the first line of a code block: optional [ ] parts go, the text from '(' goes, then the first
   word and up to three more words that are whole numbers or names in upper case ('PARSE ARG', 'Error 40'). */
subjectOf: procedure
  use arg codeLine
  t = codeLine
  do forever
    a = t~pos('[')
    if a == 0 then leave
    b = t~pos(']', a)
    if b == 0 then leave
    t = t~left(a - 1) t~substr(b + 1)
  end
  if t~strip~left(1) \== '(' then parse var t t '(' .
  if t~words == 0 then do
    if codeLine~words == 0 then return '-'
    return codeLine~word(1)
  end
  out = t~word(1)
  do k = 2 to min(4, t~words)
    w = t~word(k)
    if datatype(w, 'W') then out = out w
    else if isUpperName(w) then out = out w
    else leave
  end
  return out

isUpperName: procedure
  use arg w
  if verify(w~left(1), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ') \== 0 then return .false
  return verify(w, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.') == 0

/* A part of the main subject: its own name when it starts with the same word ('NUMERIC FORM' under
   'NUMERIC DIGITS'), else the main subject and its name ('STREAM OPEN'). */
partOf: procedure
  use arg main, codeLine
  n = subjectOf(codeLine)
  if n~word(1) == main~word(1) then return n
  return main n

about: procedure
  use arg store, subject
  r = store~q("SELECT id AS id, kind AS kind, selector AS sel, path AS path, line AS line FROM unit WHERE kind IN ('FACT', 'EXAMPLE', 'RESULT', 'REFERENCE') AND lower(owner) = lower(?) ORDER BY path, line, kind", store~binds(subject))
  n = 0
  do row over r~rows
    n += 1
    if row['KIND'] \== 'FACT' then do
      say '  ' || row['KIND']~lower || ':' row['SEL']~changestr('0a'x, ' | ')
      iterate
    end
    ws = store~q('SELECT s.canon AS canon FROM instance i JOIN shape s ON s.id = i.shape_id WHERE i.unit_id = ? AND i.parent_id = 0 ORDER BY i.seq', store~binds(row['ID']))
    text = ''
    do w over ws~rows
      text = text w['CANON']~substr(w['CANON']~pos(': ') + 2)
    end
    say '  ' || text~strip
  end
  if n == 0 then say 'i know no facts about' subject
  return
cleanWords: procedure
  use arg text
  clean = text~lower~translate('', '.,;:()"''?!#*`[]{}<>')   /* output table empty: every listed character becomes a blank */
  out = .array~new
  do k = 1 to clean~words
    out~append(clean~word(k))
  end
  return out

stats: procedure
  use arg store
  d = store~stats
  do k over .array~of('UNITS', 'INSTANCES', 'SHAPES', 'FAMILIES', 'WORDS', 'EDGES', 'WEIGHTS')
    say k~left(10) d[k]
  end
  say 'most common nodes:'
  do row over store~topShapes(15)
    say '  #' || .SlamStore~displayId(row['ID']) row['N']~right(7) ' ' row['CANON']~left(110)
  end
  return

node: procedure
  use arg store, n
  id = store~resolve(n)
  say '#' || .SlamStore~displayId(id) store~canonOf(id)
  r = store~q('SELECT u.path AS path, u.owner AS owner, u.selector AS sel, i.line AS line, i.binding AS binding FROM instance i JOIN unit u ON u.id = i.unit_id WHERE i.shape_id = ? LIMIT 8', store~binds(id))
  do row over r~rows
    say '   ' row['OWNER'] || '~' || row['SEL'] 'line' row['LINE'] ' ' row['BINDING']
  end
  return

edgesOut: procedure
  use arg store, n, direction
  id = store~resolve(n)
  say '#' || .SlamStore~displayId(id) store~canonOf(id)~left(100)
  if direction == 'OUT' then list = store~successors(id, 12)
  else list = store~entriesInto(id, 12)
  arrow = '->'
  if direction == 'IN' then arrow = '<-'
  do d over list
    say '  ' arrow '#' || .SlamStore~displayId(d['NODE']) d['TIER']~left(6) format(d['RATE'], , 3) 'freq' d['FREQ']~right(5) ' ' store~canonOf(d['NODE'])~left(90)
  end
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1

::requires 'SlamSegmenter.cls'
::requires 'SlamJava.cls'
::requires 'SlamStore.cls'
::requires 'SlamGround.cls'
