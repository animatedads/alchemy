/* slam.rex - SLAM v0.1 command line.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 *   rexx slam.rex ingest DB DIR [DIR...]     segment every .cls/.rex/.rexx/.orx file into the store
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
 * NODE is a display id (#00EF), a numeric id, or a canonical text.
 */
signal on syntax name onSyntax
parse arg cmd db rest
cmd = cmd~lower
if cmd == '' | db == '' then do
  say 'usage: rexx slam.rex ingest|corpus|stats|node|follows|into|record DB ...'
  exit 2
end
store = .SlamStore~new(db)
select
  when cmd == 'ingest' then call ingest store, rest
  when cmd == 'corpus' then call corpus store, rest~strip
  when cmd == 'read' then call readDoc store, rest~strip
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
  splitter = .SlamUnitSplitter~new
  segmenter = .SlamSegmenter~new
  files = 0; skipped = 0; units = 0; dupes = 0; segsTotal = 0
  call time 'R'
  do d = 1 to dirs~words
    call SysFileTree dirs~word(d) || '/*', 'f.', 'FSO'
    do i = 1 to f.0
      ext = f.i~substr(f.i~lastPos('.') + 1)~lower
      if wordpos(ext, 'cls rex rexx orx') == 0 then iterate
      r = ingestFile(store, splitter, segmenter, f.i)
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
    return
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
    return
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
::requires 'SlamStore.cls'
::requires 'SlamGround.cls'
