/* Has SLAM learned how compiler code is written?  Next-segment prediction on code it has not seen.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 *
 * SLAM's edges say "after this node, that node", with counts. Learned from some files, they predict
 * the next segment in files held out (every fifth file, by a fixed checksum of its path). Three levels:
 *   KIND      RUN, GUARD, LOOP, ...
 *   SKELETON  the kind and how it stops or what it holds: GUARD:continue, EXIT:return,
 *             BRANCH{THEN=RUN,EXIT}. Rexx's leave / iterate / raise / signal are break / continue /
 *             throw / throw, and exit is return, so SKELETON is the same vocabulary in every language.
 *   FAMILY    the shape with message, function and class names abstracted (language-specific)
 * Each level also has a CONTEXT variant (KIND+, SKELETON+, FAMILY+): the previous segment together with
 * the kind of segment the sequence sits in (UNIT, LOOP, BRANCH, ARM, ...), as SLAM's <START:ctx>
 * markers already record.
 * The baseline at each level is the most common segment in the training files.
 * Counting and scoring run in SQL inside the stores; ooRexx labels shapes and picks the held-out files.
 *
 * Args: summary file | experiment | experiment ...
 *   experiment: NAME=train-db[:filter]+train-db...>test-db[:filter]@levels
 *   filter: CPP or REXX (by file extension); test files are the held-out fifth of the test store, and
 *   when a training store is also the test store, its held-out fifth is left out of training.
 */
signal on syntax name onSyntax
parse arg summary '|' rest
call lineout summary, , 1
do while rest \== ''
  parse var rest exp '|' rest
  parse var exp name '=' trains '>' test '@' levels
  do lv over levels~makeArray(',')
    res = run(trains, test, lv)
    line = name lv 'TOTAL' res[1] 'MODEL' res[2] 'BASE' res[3] 'SEEN' res[4]
    say line '  model' format(100 * res[2] / res[1], , 1) || '%  base' format(100 * res[3] / res[1], , 1) || '%'
    call lineout summary, line
  end
end
call stream summary, 'C', 'CLOSE'
exit 0

/* One experiment at one level: .array~of(total, model right, baseline right, seen previous). */
run: procedure
  use arg trains, test, level
  parse var test testDb ':' testFilter
  st = .SlamStore~new(testDb)
  call prepare st, testDb, testFilter, 'T', level
  st~q('CREATE TEMP TABLE IF NOT EXISTS trainpairs (a TEXT, b TEXT)')
  st~q('DELETE FROM trainpairs')
  k = 0
  do tr over trains~makeArray('+')
    k += 1
    parse var tr trainDb ':' trainFilter
    if trainDb == testDb then st~q('INSERT INTO trainpairs SELECT a, b FROM lpT WHERE h = 0')
    else do
      alias = 'x' || k
      st~q("ATTACH DATABASE '" || trainDb || "' AS" alias)
      call prepareAttached st, alias, trainDb, trainFilter, level
      st~q('INSERT INTO trainpairs SELECT a, b FROM lp_' || alias)
      st~q('DROP TABLE lp_' || alias)
      st~q('DETACH DATABASE' alias)
    end
  end
  st~q('DROP TABLE IF EXISTS tcount'); st~q('DROP TABLE IF EXISTS best')
  st~q('CREATE TEMP TABLE tcount AS SELECT a, b, count(*) AS n FROM trainpairs GROUP BY a, b')
  st~q('CREATE TEMP TABLE best AS SELECT a, b FROM (SELECT a, b, ROW_NUMBER() OVER (PARTITION BY a ORDER BY n DESC, b) AS rn FROM tcount) WHERE rn = 1')
  g = st~scalar('SELECT b FROM trainpairs GROUP BY b ORDER BY count(*) DESC, b LIMIT 1')
  r = st~q('SELECT count(*) AS total, sum(CASE WHEN best.b IS NOT NULL THEN best.b = lpT.b ELSE lpT.b = ? END) AS model, sum(lpT.b = ?) AS base, sum(best.a IS NOT NULL) AS seen FROM lpT LEFT JOIN best ON best.a = lpT.a WHERE lpT.h = 1', st~binds(g, g))~rows[1]
  out = .array~of(r['TOTAL'], r['MODEL'], r['BASE'], r['SEEN'])
  st~close
  return out

/* The test store's pairs at one level: lpT(h, a, b), h = 1 for a held-out file. */
prepare: procedure
  use arg st, db, filter, tag, level
  call skeletons st, ''
  st~q('DROP TABLE IF EXISTS held'); st~q('CREATE TEMP TABLE held (path TEXT PRIMARY KEY)')
  rows = st~q('SELECT DISTINCT path AS p FROM unit')~rows
  st~begin
  do r over rows
    p = r['P']
    if \keep(p, filter) then iterate
    if checksum(p) // 5 == 0 then st~q('INSERT INTO held (path) VALUES (?)', st~binds(p))
  end
  st~commit
  st~q('DROP TABLE IF EXISTS lpT')
  st~q('CREATE TEMP TABLE lpT AS' pairsSql('main', level, filter, 'h'))
  return

prepareAttached: procedure
  use arg st, alias, db, filter, level
  call skeletons st, alias
  st~q('CREATE TEMP TABLE lp_' || alias 'AS' pairsSql(alias, level, filter, ''))
  return

/* SQL for the pairs (previous, next) of one store at one level; a sequence's first segment follows
   <START>. With hcol, a column h says whether the file is held out. */
pairsSql: procedure
  use arg schema, level, filter, hcol
  ctx = (level~right(1) == '+')
  base = level~strip('T', '+')
  select
    when base == 'KIND' then lab = 's.kind'
    when base == 'FAMILY' then lab = 's.family'
    otherwise lab = 'k.skel'
  end
  where = ''
  if filter == 'CPP' then where = "WHERE (u.path LIKE '%.cpp' OR u.path LIKE '%.h' OR u.path LIKE '%.hpp' OR u.path LIKE '%.cc')"
  if filter == 'REXX' then where = "WHERE (u.path LIKE '%.cls' OR u.path LIKE '%.rex')"
  if filter == 'JAVA' then where = "WHERE u.path LIKE '%.java'"
  hsel = ''
  if hcol \== '' then hsel = '(u.path IN (SELECT path FROM held)) AS h,'
  pk = "'*'"
  if ctx then pk = "coalesce(ps.kind, 'UNIT')"
  inner = 'SELECT' hsel lab 'AS lab,' pk 'AS pk, i.unit_id AS uid, i.parent_id AS par, i.id AS id, i.seq AS seq, u.path AS path FROM' schema || '.instance i JOIN' schema || '.unit u ON u.id = i.unit_id JOIN' schema || '.shape s ON s.id = i.shape_id JOIN' schema || '.skel k ON k.shape_id = i.shape_id LEFT JOIN' schema || '.instance pi ON pi.id = i.parent_id LEFT JOIN' schema || '.shape ps ON ps.id = pi.shape_id' where
  hpass = ''
  if hcol \== '' then hpass = 'h,'
  return 'SELECT' hpass "pk || '|' || CASE WHEN seq = 1 THEN '<START>' ELSE LAG(lab) OVER (PARTITION BY uid, par ORDER BY id) END AS a, lab AS b FROM (" inner ')'

keep: procedure
  use arg p, filter
  ext = p~substr(p~lastPos('.') + 1)~lower
  if filter == 'CPP' then return wordpos(ext, 'cpp h hpp cc') > 0
  if filter == 'REXX' then return wordpos(ext, 'cls rex') > 0
  if filter == 'JAVA' then return ext == 'java'
  return .true

checksum: procedure
  use arg p
  /* the path below the last 'llvm-project/', 'oorexx2cpp/' or 'alchemy/' marker, so the split does not
     depend on where the source was unpacked */
  do m over .array~of('llvm-project/', 'oorexx2cpp/', 'alchemy/')
    at = p~pos(m)
    if at > 0 then p = p~substr(at + m~length)
  end
  sum = 0
  do k = 1 to p~length; sum += c2d(p~subchar(k)); end
  return sum

/* skel(shape_id, skel): the SKELETON label of every shape in a store (made once, then kept). */
skeletons: procedure
  use arg st, alias
  prefix = ''
  if alias \== '' then prefix = alias || '.'
  st~q('CREATE TABLE IF NOT EXISTS' prefix || 'skel (shape_id INTEGER PRIMARY KEY, skel TEXT NOT NULL)')
  have = st~scalar('SELECT count(*) AS n FROM' prefix || 'skel')
  total = st~scalar('SELECT count(*) AS n FROM' prefix || 'shape')
  if have = total then return
  st~q('DELETE FROM' prefix || 'skel')
  last = 0
  do forever
    rows = st~q('SELECT id AS id, kind AS kind, canon AS canon FROM' prefix || 'shape WHERE id > ? ORDER BY id LIMIT 20000', st~binds(last))~rows
    if rows~items == 0 then leave
    st~begin
    do r over rows
      st~q('INSERT INTO' prefix || 'skel (shape_id, skel) VALUES (?, ?)', st~binds(r['ID'], skeleton(r['KIND'], r['CANON'])))
      last = r['ID']
    end
    st~commit
  end
  return

skeleton: procedure
  use arg kind, canon
  if wordpos(kind, 'BRANCH LOOP BLOCK SELECT ARM TRY') > 0 then do
    at = canon~lastPos(' {')
    if at > 0 then return kind || canon~substr(at + 1)
    return kind
  end
  if kind == 'GUARD' then do
    at = canon~lastPos('; ')
    if at == 0 then return kind
    return kind || ':' || stopWord(canon~substr(at + 2)~word(1))
  end
  if kind == 'EXIT' then return kind || ':' || stopWord(canon~substr(canon~pos(':') + 2)~word(1))
  return kind

stopWord: procedure
  use arg w
  w = w~lower
  select
    when w == 'leave' then return 'break'
    when w == 'iterate' then return 'continue'
    when w == 'raise' | w == 'signal' then return 'throw'
    when w == 'exit' then return 'return'
    otherwise return w
  end

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamStore.cls'
