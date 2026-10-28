/* NetRexx -> Java: learn translation edges from NetRexxC's own output, then predict the Java of files
 * SLAM has not seen.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 * NetRexxC keeps every statement on its source line. On each line, the NetRexx segments that start
 * there and the Java segments that start there are the same code in two languages:
 *   line patterns   the kinds on the line, NetRexx -> Java (a loop is LOOP -> BLOCK RUN LABEL LOOP:
 *                   NetRexxC wraps the for in a block holding the loop variable's setup)
 *   segment pairs   in order along the line, each NetRexx segment takes the next Java segment of the
 *                   same kind, else the next one; Java segments left over are the compiler's wrapping
 * For files in the training set each segment pair adds to a translation edge NetRexx node -> Java node
 * (its prior), and each line pattern is counted.
 * For held-out files (every fifth, by a fixed checksum of the path) SLAM predicts the Java node from
 * the edges before looking, and records each outcome on the edge it used (its tested tier).
 * A NetRexx shape never seen in training is predicted at FAMILY level, then at kind level.
 *
 * Args: directory of .nrx files with their .java.keep (NetRexxC -keep) | store | summary file
 * Summary lines:  KEY value
 */
signal on syntax name onSyntax
parse arg dir '|' db '|' summary
call SysFileDelete db
store = .SlamStore~new(db)
nseg = .SlamNrxSegmenter~new
jseg = .SlamJavaSegmenter~new
train = .array~new; test = .array~new; testLines = .array~new; linePat = .directory~new
files = 0; failed = 0; unpaired = 0; trainFiles = 0; testFiles = 0
call SysFileTree dir || '/*.nrx', 'f.', 'FSO'
do i = 1 to f.0
  nrx = f.i
  jf = nrx~left(nrx~length - 4) || '.java.keep'
  if stream(jf, 'C', 'QUERY EXISTS') == '' then iterate
  files += 1
  rel = nrx~substr(dir~length + 2)
  sum = 0
  do k = 1 to rel~length; sum += c2d(rel~subchar(k)); end
  isTest = (sum // 5 == 0)
  pairs = pairFile(nrx, jf, nseg, jseg)
  if pairs == .nil then do
    failed += 1
    iterate
  end
  unpaired += pairs[2]
  if isTest then do
    testFiles += 1
    do p over pairs[1]; test~append(p); end
    do l over pairs[3]; testLines~append(l); end
  end
  else do
    trainFiles += 1
    do p over pairs[1]; train~append(p); end
    do l over pairs[3]; call bump linePat, l[1], l[2]; end
  end
end

/* learn: translation edges, and the FAMILY and kind tables for shapes never seen */
fam = .directory~new; kinds = .directory~new
store~begin
do p over train
  n = store~shapeId(p[1], p[3], p[2])
  j = store~shapeId(p[4], p[6], p[5])
  store~translateAdd(n, j)
  call bump fam, p[1] || ':' || p[3], p[4] || ':' || p[6]
  call bump kinds, p[1], p[4]
end
store~commit
edges = store~scalar('SELECT count(*) AS n FROM translate')

/* predict the held-out files, then look */
seen = 0; fineRight = 0; famTried = 0; famRight = 0; kindRight = 0; changedKind = 0
store~begin
do p over test
  if p[1] \== p[4] then changedKind += 1
  if argmax(kinds, p[1]) == p[4] then kindRight += 1
  n = store~findShape(p[2])
  rows = .array~new
  if n \== '' then rows = store~translations(n)
  if rows~items > 0 then do
    seen += 1
    predicted = rows[1]['TO']
    actual = store~findShape(p[5])
    ok = (actual \== '') & (predicted = actual)
    if ok then fineRight += 1
    store~translateRecord(n, predicted, ok)
  end
  else do
    famTried += 1
    if argmax(fam, p[1] || ':' || p[3]) == p[4] || ':' || p[6] then famRight += 1
  end
end
store~commit
testedEdges = store~scalar('SELECT count(*) AS n FROM translate WHERE trials > 0')
/* line patterns: predict the Java kinds on each held-out line from its NetRexx kinds */
lineSeen = 0; lineRight = 0; lineSame = 0
do l over testLines
  if l[1] == l[2] then lineSame += 1          /* the baseline: Java has the same kinds as NetRexx */
  guess = argmax(linePat, l[1])
  if guess == '' then iterate
  lineSeen += 1
  if guess == l[2] then lineRight += 1
end
call lineout summary, , 1
call out 'FILES' files
call out 'FAILED' failed
call out 'TRAIN_FILES' trainFiles
call out 'TEST_FILES' testFiles
call out 'TRAIN_PAIRS' train~items
call out 'TEST_PAIRS' test~items
call out 'UNPAIRED' unpaired
call out 'EDGES' edges
call out 'SEEN' seen
call out 'FINE_RIGHT' fineRight
call out 'FAMILY_TRIED' famTried
call out 'FAMILY_RIGHT' famRight
call out 'KIND_RIGHT' kindRight
call out 'KIND_CHANGED' changedKind
call out 'TESTED_EDGES' testedEdges
call out 'TEST_LINES' testLines~items
call out 'LINE_SEEN' lineSeen
call out 'LINE_RIGHT' lineRight
call out 'LINE_SAME' lineSame
call out 'LOOP_LINE' argmax(linePat, 'LOOP')
call out 'SELECT_LINE' argmax(linePat, 'SELECT')
/* the kinds NetRexx structures become in Java (from the training pairs) */
do k over kinds~allIndexes~sort
  row = kinds[k]
  txt = ''
  do j over row~allIndexes~sort; txt = txt j || '=' || row[j]; end
  call out 'KINDMAP_' || k txt~strip
end
call stream summary, 'C', 'CLOSE'
store~close
say 'files' files ' failed' failed ' train pairs' train~items ' test pairs' test~items ' fine seen' seen ' fine right' fineRight ' family right' famRight 'of' famTried ' kind right' kindRight ' lines' lineRight 'of' lineSeen 'seen of' testLines~items
exit 0

out:
  call lineout summary, arg(1)
  return

bump: procedure
  use arg table, a, b
  if \table~hasIndex(a) then table[a] = .directory~new
  row = table[a]
  if row~hasIndex(b) then row[b] = row[b] + 1
  else row[b] = 1
  return

argmax: procedure
  use arg table, a
  if \table~hasIndex(a) then return ''
  best = ''; bestN = -1
  do b over table[a]~allIndexes~sort
    if table[a][b] > bestN then do; best = b; bestN = table[a][b]; end
  end
  return best

/* Pairs of one file: array(kind, fine, family) of the NetRexx segment and the Java segment that starts
   on its line. Returns .array~of(pairs, unpaired), or .nil when either side cannot be read. */
pairFile: procedure
  use arg nrx, jf, nseg, jseg
  signal on syntax name fileFailed
  text = charin(nrx, 1, chars(nrx)); call stream nrx, 'C', 'CLOSE'
  nsegs = .array~new
  do u over .SlamNrxSplitter~new~split(text)
    call flatten nseg~segmentUnit(u), nsegs
  end
  text = charin(jf, 1, chars(jf)); call stream jf, 'C', 'CLOSE'
  jsegs = .array~new
  do u over .SlamJavaSplitter~new~split(text)
    call flatten jseg~segmentUnit(u), jsegs
  end
  nBy = byLine(nsegs); jBy = byLine(jsegs)
  pairs = .array~new; lines = .array~new
  missing = 0
  do ln over nBy~allIndexes
    nl = nBy[ln]
    if \jBy~hasIndex(ln) then do
      missing += nl~items
      iterate
    end
    jl = jBy[ln]
    lines~append(.array~of(kindsOf(nl), kindsOf(jl)))
    idx = 1
    do n over nl
      at = 0
      do k = idx to jl~items
        if jl[k]~kind == n~kind then do; at = k; leave; end
      end
      if at == 0 then if idx <= jl~items then at = idx
      if at == 0 then do
        missing += 1
        iterate
      end
      j = jl[at]
      pairs~append(.array~of(n~kind, n~fine, n~family, j~kind, j~fine, j~family, nrx, ln))
      idx = at + 1
    end
  end
  return .array~of(pairs, missing, lines)
fileFailed:
  return .nil

byLine: procedure
  use arg segs
  d = .directory~new
  do s over segs
    if \d~hasIndex(s~line) then d[s~line] = .array~new
    d[s~line]~append(s)
  end
  return d

kindsOf: procedure
  use arg segs
  out = ''
  do s over segs; out = out s~kind; end
  return out~strip

flatten: procedure
  use arg segs, out
  do s over segs
    out~append(s)
    do sq over s~sequences
      call flatten sq[2], out
    end
  end
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamLanguages.cls'
::requires 'SlamStore.cls'
