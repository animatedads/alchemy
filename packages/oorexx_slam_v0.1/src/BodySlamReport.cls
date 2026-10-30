/* BodySlamReport.cls - Body Slam v0.1: the questions, asked of the temporary database in SQL.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 *
 * Each report gives an array of lines. Every report says what it counts, so a line can be checked by
 * hand against the source (file and line are given where there is one).
 *
 * Two strengths of link, kept apart:
 *   DEFINITE  LOCAL, PROJECT and ESTATE requires: one file it can be.
 *   POSSIBLE  DEFINITE plus every candidate of an AMBIGUOUS require: REXX_PATH order picks one.
 */

::requires 'RexxSqlBackend.cls'

::class BodySlamReport public
::attribute session

::method init
  expose session
  use strict arg dbPath
  session = .RexxSqlSqliteSession~open(dbPath)

::method close
  expose session
  session~close

::method q
  expose session
  use arg sql
  binds = .array~new
  do i = 2 to arg()
    binds~append(.array~of('CHAR', arg(i)))
  end
  if binds~items = 0 then r = session~execute(sql)
  else r = session~executeBound(sql, binds)
  if r~status \= 'SUCCESS' then raise syntax 98.900 array('Body Slam report:' r~message '|' sql)
  return r~rows

::method one
  use strict arg sql, a = '', b = ''
  if arg() = 1 then rows = self~q(sql)
  else if arg() = 2 then rows = self~q(sql, a)
  else rows = self~q(sql, a, b)
  if rows~items = 0 then return ''
  return rows[1]['V']

::method levelsSql class
  use strict arg strength
  if strength == 'DEFINITE' then return "('LOCAL','PROJECT','ESTATE')"
  return "('LOCAL','PROJECT','ESTATE','AMBIGUOUS')"

/* ---------- summary ---------- */

::method summary
  out = .array~new
  out~append('projects' self~one('SELECT COUNT(*) AS v FROM project') '(families' self~one('SELECT COUNT(DISTINCT family) AS v FROM project') || ')')
  out~append('files' self~one('SELECT COUNT(*) AS v FROM file') '(ooRexx' self~one('SELECT COUNT(*) AS v FROM file WHERE rexx = 1') || ', lines' self~one('SELECT SUM(lines) AS v FROM file') || ')')
  out~append('classes' self~one('SELECT COUNT(*) AS v FROM cls') '(public' self~one('SELECT COUNT(*) AS v FROM cls WHERE public = 1') || ', distinct names' self~one('SELECT COUNT(DISTINCT name) AS v FROM cls') || ')')
  out~append('routines' self~one('SELECT COUNT(*) AS v FROM routine'))
  out~append('requires' self~one('SELECT COUNT(*) AS v FROM req'))
  do r over self~q('SELECT level AS l, COUNT(*) AS n FROM req GROUP BY level ORDER BY n DESC')
    out~append('  ' r['L']~left(10) r['N'])
  end
  out~append('uses of .Name (one row per name per file; builtins not stored)' self~one('SELECT COUNT(*) AS v FROM use'))
  do r over self~q('SELECT how AS h, COUNT(*) AS n FROM use GROUP BY how ORDER BY n DESC')
    out~append('  ' r['H']~left(10) r['N'])
  end
  out~append('literal topics' self~one('SELECT COUNT(*) AS v FROM topic') '(distinct' self~one('SELECT COUNT(DISTINCT topic) AS v FROM topic') || ')')
  out~append('declared dependencies read' self~one('SELECT COUNT(*) AS v FROM decl') 'from' self~one('SELECT COUNT(DISTINCT project_id) AS v FROM decl') 'projects')
  return out

/* ---------- requires ---------- */

/* names whose require can load more than one file: which copy runs depends on REXX_PATH */
::method ambiguous
  use strict arg limit = 20
  out = .array~new
  out~append('name | requires | candidate files | candidate families | candidate versions')
  sql = "SELECT r.name AS name, COUNT(DISTINCT r.id) AS reqs, COUNT(DISTINCT rt.target_id) AS files, COUNT(DISTINCT p.family) AS fams, COUNT(DISTINCT p.id) AS vers" ,
        "FROM req r JOIN req_target rt ON rt.req_id = r.id JOIN file f ON f.id = rt.target_id JOIN project p ON p.id = f.project_id" ,
        "WHERE r.level = 'AMBIGUOUS' GROUP BY r.name ORDER BY reqs DESC LIMIT ?"
  do r over self~q(sql, limit)
    out~append(r['NAME'] '|' r['REQS'] '|' r['FILES'] '|' r['FAMS'] '|' r['VERS'])
  end
  return out

/* AMBIGUOUS requires whose candidates are in more than one family: not a version question, a name clash */
::method clashes
  use strict arg limit = 20
  out = .array~new
  out~append('name | requires | families it could load from')
  sql = "SELECT r.name AS name, COUNT(DISTINCT r.id) AS reqs, GROUP_CONCAT(DISTINCT p.family) AS fams, COUNT(DISTINCT p.family) AS nf" ,
        "FROM req r JOIN req_target rt ON rt.req_id = r.id JOIN file f ON f.id = rt.target_id JOIN project p ON p.id = f.project_id" ,
        "WHERE r.level IN ('AMBIGUOUS', 'ESTATE') GROUP BY r.name HAVING nf > 1 ORDER BY nf DESC, reqs DESC LIMIT ?"
  do r over self~q(sql, limit)
    out~append(r['NAME'] '|' r['REQS'] '|' r['FAMS'])
  end
  return out

::method missing
  use strict arg limit = 20
  out = .array~new
  out~append('name | requires | projects | one place it is required')
  sql = "SELECT r.name AS name, COUNT(*) AS reqs, COUNT(DISTINCT f.project_id) AS projs, MIN(f.path || ':' || r.line) AS at" ,
        "FROM req r JOIN file f ON f.id = r.file_id WHERE r.level = 'MISSING' GROUP BY r.name ORDER BY reqs DESC LIMIT ?"
  do r over self~q(sql, limit)
    out~append(r['NAME'] '|' r['REQS'] '|' r['PROJS'] '|' r['AT'])
  end
  return out

/* estate files with the name of a package shipped with ooRexx: on REXX_PATH they replace the shipped one */
::method shadows
  use strict arg limit = 20
  out = .array~new
  out~append('shipped name | requires that can load an estate copy instead | estate copies | one copy')
  sql = "SELECT r.name AS name, COUNT(DISTINCT r.id) AS reqs, COUNT(DISTINCT rt.target_id) AS copies, MIN(t.path) AS one" ,
        "FROM req r JOIN req_target rt ON rt.req_id = r.id JOIN file t ON t.id = rt.target_id" ,
        "WHERE r.shadows = 1 GROUP BY r.name ORDER BY reqs DESC LIMIT ?"
  do r over self~q(sql, limit)
    out~append(r['NAME'] '|' r['REQS'] '|' r['COPIES'] '|' r['ONE'])
  end
  return out

/* requires ooRexx refuses: the file that holds one cannot load */
::method invalid
  use strict arg limit = 20
  out = .array~new
  out~append('directive | where')
  sql = "SELECT r.name AS name, f.path || ':' || r.line AS at FROM req r JOIN file f ON f.id = r.file_id WHERE r.level = 'INVALID' ORDER BY f.path LIMIT ?"
  do r over self~q(sql, limit)
    out~append(r['NAME'] '|' r['AT'])
  end
  return out

::method caseOnly
  use strict arg limit = 20
  out = .array~new
  out~append('required as | file that exists | where')
  sql = "SELECT r.name AS name, MIN(t.base) AS base, f.path || ':' || r.line AS at FROM req r JOIN req_target rt ON rt.req_id = r.id" ,
        "JOIN file t ON t.id = rt.target_id JOIN file f ON f.id = r.file_id WHERE r.level = 'CASE_ONLY' GROUP BY r.id ORDER BY f.path LIMIT ?"
  do r over self~q(sql, limit)
    out~append(r['NAME'] '|' r['BASE'] '|' r['AT'])
  end
  return out

/* ---------- classes ---------- */

/* a public class name defined in more than one family: two classes, one name */
::method duplicates
  use strict arg limit = 20
  out = .array~new
  out~append('class | families | files | families (first 6)')
  sql = "SELECT c.name AS name, COUNT(DISTINCT p.family) AS nf, COUNT(DISTINCT c.file_id) AS nfiles, GROUP_CONCAT(DISTINCT p.family) AS fams" ,
        "FROM cls c JOIN file f ON f.id = c.file_id JOIN project p ON p.id = f.project_id WHERE c.public = 1" ,
        "GROUP BY c.name HAVING nf > 1 ORDER BY nf DESC, nfiles DESC LIMIT ?"
  do r over self~q(sql, limit)
    fams = r['FAMS']~makeArray(',')
    shown = .array~new
    do i = 1 to min(6, fams~items)
      shown~append(fams[i])
    end
    out~append(r['NAME'] '|' r['NF'] '|' r['NFILES'] '|' shown~makeString('L', ', '))
  end
  return out

/* .Name used where no require reaches its definition: a hidden link */
::method undeclared
  use strict arg limit = 20
  out = .array~new
  out~append('class | using files | using projects | defined in families | one use')
  sql = "SELECT u.name AS name, COUNT(*) AS nfiles, COUNT(DISTINCT f.project_id) AS nproj, MIN(f.path || ':' || u.line) AS at," ,
        "(SELECT GROUP_CONCAT(DISTINCT p2.family) FROM cls c2 JOIN file f2 ON f2.id = c2.file_id JOIN project p2 ON p2.id = f2.project_id WHERE c2.name = u.name) AS fams" ,
        "FROM use u JOIN file f ON f.id = u.file_id WHERE u.how = 'UNDECLARED' GROUP BY u.name ORDER BY nfiles DESC LIMIT ?"
  do r over self~q(sql, limit)
    out~append(r['NAME'] '|' r['NFILES'] '|' r['NPROJ'] '|' r['FAMS'] '|' r['AT'])
  end
  return out

::method notPublic
  use strict arg limit = 20
  out = .array~new
  out~append('class | used at | defined (not public) at')
  sql = "SELECT u.display AS name, f.path || ':' || u.line AS at, t.path AS def FROM use u JOIN file f ON f.id = u.file_id" ,
        "JOIN file t ON t.id = u.target_id WHERE u.how = 'NOT_PUBLIC' ORDER BY f.path LIMIT ?"
  do r over self~q(sql, limit)
    out~append(r['NAME'] '|' r['AT'] '|' r['DEF'])
  end
  return out

/* ---------- projects ---------- */

::method edgeSql class
  use strict arg strength
  return "SELECT ps.family AS src, pt.family AS dst, COUNT(*) AS n FROM req_target rt JOIN req r ON r.id = rt.req_id" ,
         "JOIN file fs ON fs.id = rt.file_id JOIN file ft ON ft.id = rt.target_id" ,
         "JOIN project ps ON ps.id = fs.project_id JOIN project pt ON pt.id = ft.project_id" ,
         "WHERE ps.family <> pt.family AND r.level IN" .BodySlamReport~levelsSql(strength) "GROUP BY ps.family, pt.family"

::method familyEdges
  use strict arg limit = 20, strength = 'DEFINITE'
  out = .array~new
  out~append('family -> family | requires (' || strength || ')')
  do r over self~q(.BodySlamReport~edgeSql(strength) 'ORDER BY n DESC LIMIT ?', limit)
    out~append(r['SRC'] '->' r['DST'] '|' r['N'])
  end
  return out

/* which families are used by the most other families */
::method hubs
  use strict arg limit = 20, strength = 'DEFINITE'
  out = .array~new
  out~append('family | families that require it (' || strength || ') | requires into it')
  sql = 'SELECT dst AS fam, COUNT(*) AS users, SUM(n) AS reqs FROM (' .BodySlamReport~edgeSql(strength) ') GROUP BY dst ORDER BY users DESC LIMIT ?'
  do r over self~q(sql, limit)
    out~append(r['FAM'] '|' r['USERS'] '|' r['REQS'])
  end
  return out

/* strongly connected families (Tarjan): families that require each other, directly or round a ring */
::method cycles
  use strict arg strength = 'DEFINITE'
  adj = .directory~new
  do r over self~q(.BodySlamReport~edgeSql(strength))
    if \adj~hasIndex(r['SRC']) then adj[r['SRC']] = .array~new
    adj[r['SRC']]~append(r['DST'])
    if \adj~hasIndex(r['DST']) then adj[r['DST']] = .array~new
  end
  st = .directory~of(('INDEX', 0), ('STACK', .array~new), ('ON', .set~new), ('IDX', .directory~new), ('LOW', .directory~new), ('OUT', .array~new))
  do v over adj~allIndexes~sort
    if \st['IDX']~hasIndex(v) then self~tarjan(v, adj, st)
  end
  out = .array~new
  out~append('families that require each other (' || strength || '):' st['OUT']~items 'groups')
  do g over st['OUT']
    out~append('  ' g~items || ':' g~sort~makeString('L', ', '))
  end
  return out

::method tarjan
  use strict arg v, adj, st
  st['IDX'][v] = st['INDEX']
  st['LOW'][v] = st['INDEX']
  st['INDEX'] = st['INDEX'] + 1
  st['STACK']~append(v)
  st['ON']~put(v)
  do w over adj[v]
    if \st['IDX']~hasIndex(w) then do
      self~tarjan(w, adj, st)
      st['LOW'][v] = min(st['LOW'][v], st['LOW'][w])
    end
    else if st['ON']~hasIndex(w) then st['LOW'][v] = min(st['LOW'][v], st['IDX'][w])
  end
  if st['LOW'][v] = st['IDX'][v] then do
    group = .array~new
    do forever
      w = st['STACK'][st['STACK']~last]
      st['STACK']~delete(st['STACK']~last)
      st['ON']~remove(w)
      group~append(w)
      if w == v then leave
    end
    if group~items > 1 then st['OUT']~append(group)
  end

/* ---------- blast radius ---------- */

/* What can break if TARGET changes: TARGET is a class name, else the end of a file path.
   The files that require it, at any depth, by project; DEFINITE and POSSIBLE kept apart. */
::method blast
  use strict arg target, limit = 25
  out = .array~new
  start = "SELECT DISTINCT file_id AS id FROM cls WHERE name = ?"
  key = target~upper
  kind = 'class'
  if self~one('SELECT COUNT(*) AS v FROM cls WHERE name = ?', key) = 0 then do
    start = "SELECT id FROM file WHERE path = ? OR path LIKE ?"
    kind = 'file'
  end
  if kind == 'class' then starts = self~one('SELECT COUNT(DISTINCT file_id) AS v FROM cls WHERE name = ?', key)
  else starts = self~one('SELECT COUNT(*) AS v FROM file WHERE path = ? OR path LIKE ?', target, '%/' || target)
  out~append('blast radius of' kind target || ':' starts 'defining file(s)')
  if starts = 0 then return out
  do strength over .array~of('DEFINITE', 'POSSIBLE')
    sql = "WITH RECURSIVE hit(id) AS (" start "UNION SELECT rt.file_id FROM req_target rt JOIN hit ON rt.target_id = hit.id" ,
          "JOIN req r ON r.id = rt.req_id WHERE r.level IN" .BodySlamReport~levelsSql(strength) ")" ,
          "SELECT p.path AS proj, COUNT(*) AS n FROM hit JOIN file f ON f.id = hit.id JOIN project p ON p.id = f.project_id" ,
          "GROUP BY p.path ORDER BY n DESC"
    if kind == 'class' then rows = self~q(sql, key)
    else rows = self~q(sql, target, '%/' || target)
    total = 0
    do r over rows
      total += r['N']
    end
    out~append(strength || ':' total 'files in' rows~items 'projects')
    do i = 1 to min(limit, rows~items)
      out~append('  ' rows[i]['PROJ'] rows[i]['N'])
    end
  end
  return out

/* ---------- topics ---------- */

::method topics
  use strict arg limit = 20
  out = .array~new
  out~append('published, never subscribed (literal topics)')
  sql = "SELECT t.topic AS topic, COUNT(*) AS n, MIN(f.path || ':' || t.line) AS at FROM topic t JOIN file f ON f.id = t.file_id" ,
        "WHERE t.role = 'PUBLISH' AND t.topic NOT IN (SELECT topic FROM topic WHERE role = 'SUBSCRIBE') GROUP BY t.topic ORDER BY n DESC LIMIT ?"
  do r over self~q(sql, limit)
    out~append('  ' r['TOPIC'] '|' r['N'] '|' r['AT'])
  end
  out~append('subscribed, never published (literal topics)')
  sql = "SELECT t.topic AS topic, COUNT(*) AS n, MIN(f.path || ':' || t.line) AS at FROM topic t JOIN file f ON f.id = t.file_id" ,
        "WHERE t.role = 'SUBSCRIBE' AND t.topic NOT IN (SELECT topic FROM topic WHERE role IN ('PUBLISH', 'EMIT')) GROUP BY t.topic ORDER BY n DESC LIMIT ?"
  do r over self~q(sql, limit)
    out~append('  ' r['TOPIC'] '|' r['N'] '|' r['AT'])
  end
  out~append('topics that join two families (publisher family -> subscriber family): links no require shows')
  sql ="SELECT DISTINCT ps.family AS src, pd.family AS dst, t1.topic AS topic FROM topic t1 JOIN topic t2 ON t2.topic = t1.topic AND t2.role = 'SUBSCRIBE'" ,
        "JOIN file f1 ON f1.id = t1.file_id JOIN file f2 ON f2.id = t2.file_id JOIN project ps ON ps.id = f1.project_id JOIN project pd ON pd.id = f2.project_id" ,
        "WHERE t1.role IN ('PUBLISH', 'EMIT') AND ps.family <> pd.family ORDER BY src, dst LIMIT ?"
  do r over self~q(sql, limit)
    out~append('  ' r['SRC'] '->' r['DST'] '|' r['TOPIC'])
  end
  return out

/* ---------- declared against found ---------- */

::method declared
  use strict arg limit = 25
  out = .array~new
  out~append('declared in DEPENDENCIES, not in the repository | declared by | nearest versions here')
  sql = "SELECT d.declared AS dep, p.path AS proj, d.file || ':' || d.line AS at," ,
        "(SELECT GROUP_CONCAT(v, ' ') FROM (SELECT CASE WHEN q.version = '' THEN '(unversioned)' ELSE q.version END AS v FROM project q WHERE q.family = d.family ORDER BY q.version)) AS here" ,
        "FROM decl d JOIN project p ON p.id = d.project_id" ,
        "WHERE NOT EXISTS (SELECT 1 FROM project q WHERE q.path LIKE '%/' || d.declared OR q.path = d.declared) ORDER BY p.path LIMIT ?"
  do r over self~q(sql, limit)
    here = r['HERE']
    if here == '' then here = '(family not here)'
    out~append('  ' r['DEP'] '|' r['AT'] '|' here)
  end
  out~append('required (DEFINITE) but not declared, in projects that have a DEPENDENCIES file | family required')
  sql = "SELECT DISTINCT ps.path AS proj, pt.family AS fam FROM req_target rt JOIN req r ON r.id = rt.req_id" ,
        "JOIN file fs ON fs.id = rt.file_id JOIN file ft ON ft.id = rt.target_id" ,
        "JOIN project ps ON ps.id = fs.project_id JOIN project pt ON pt.id = ft.project_id" ,
        "WHERE ps.family <> pt.family AND r.level IN" .BodySlamReport~levelsSql('DEFINITE') ,
        "AND ps.id IN (SELECT project_id FROM decl)" ,
        "AND NOT EXISTS (SELECT 1 FROM decl d WHERE d.project_id = ps.id AND d.family = pt.family) ORDER BY ps.path LIMIT ?"
  do r over self~q(sql, limit)
    out~append('  ' r['PROJ'] '|' r['FAM'])
  end
  return out
