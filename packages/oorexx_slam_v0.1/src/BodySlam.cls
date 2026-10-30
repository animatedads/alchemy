/* BodySlam.cls - Body Slam v0.1: how the estate hangs together, file to file and project to project.
 *
 * Architecture: Tom Dyer (Body Slam: SLAM ingests the whole estate for a project linkage analysis,
 * in a temporary database).  Code: Claude (Opus 5.5), 2026-10-29.
 * Database access: RexxSqlSqliteSession (oorexx_rexxsql_backend_v0.1, Rexx/SQL by Mark Hessling).
 *
 * The work is done in ooRexx collections, then written to one SQLite file for the questions. The file
 * is temporary: the source is the truth, so each ingest starts the file again (no drift).
 *
 * Resolution of ::requires copies what ooRexx 5.3.0 r13196 does, as measured on that build
 * (tests/test_bodyslam.rex runs the same cases on the interpreter):
 *   1. the requiring file's own directory (a relative name is relative to it), then
 *   2. the current directory, then 3. REXX_PATH.  Names are case-sensitive on Linux.
 *   A name with no extension tries NAME.cls, then NAME.rex, then NAME.
 *   Public classes are seen through any chain of requires; a class that is not public is not seen.
 *   Class names are not case-sensitive.
 * Steps 2 and 3 depend on how a program is started, which the source does not say, so a name not found
 * by step 1 is resolved by where it could be, and labelled:
 *   LOCAL      found from the requiring file's directory: what the interpreter loads, always.
 *   PROJECT    found once in the same project (current directory or REXX_PATH inside the project).
 *   ESTATE     found once in the estate, in another project: right only if REXX_PATH names it.
 *   AMBIGUOUS  found more than once (in the project or the estate): REXX_PATH order picks one.
 *   CASE_ONLY  found only with other letter case: fails on Linux.
 *   SYSTEM     not in the estate, but shipped with ooRexx (json.cls, socket.cls ...): found through PATH,
 *              after REXX_PATH (measured). An estate copy of a shipped name SHADOWS the shipped one
 *              whenever REXX_PATH reaches it (req.shadows = 1).
 *   MISSING    not in the estate and not shipped with ooRexx (an external package, or gone).
 *   LIBRARY    ::requires ... LIBRARY: a native library, not a file.
 *   INVALID    not a string or symbol, e.g. ::requires (lib): ooRexx 5.3.0 refuses it (Error 19.904,
 *              measured), so the file cannot load.
 *
 * A USE of .Name is labelled:
 *   SELF       the file defines it.
 *   REQUIRED   a file the requires reach defines it PUBLIC.
 *   NOT_PUBLIC a file the requires reach defines it, but not PUBLIC (fails: measured).
 *   UNDECLARED defined in the estate but in no file the requires reach: it works only if something
 *              else loaded it into the environment. A hidden link.
 *   BEHIND_MISSING  as UNDECLARED, but a require on the way is MISSING: the link is probably through
 *              the file that is not in the estate (found on federationbank_teller_cash_service_v0.1).
 *   BUILTIN    an ooRexx class or environment entry.
 *   UNKNOWN    none of these (an entry the program sets, or a class from outside the estate).
 */

::requires 'RexxSqlBackend.cls'
::requires 'BodySlamScanner.cls'

::class BodySlam public
::attribute root
::attribute files
::attribute byPath
::attribute byBase
::attribute byLowBase
::attribute projects
::attribute scanner
::attribute builtins
::attribute classes
::attribute closures
::attribute log
::attribute session
::attribute system

::method init
  expose root files byPath byBase byLowBase projects scanner builtins classes closures log system
  use strict arg root, systemDir = ''
  /* the packages shipped with ooRexx: the .cls and .rex files beside the rexx program */
  system = .set~new
  if systemDir == '' then do
    exe = SysSearchPath('PATH', 'rexx')
    if exe \== '' then systemDir = exe~left(exe~lastPos('/') - 1)
  end
  if systemDir \== '' then do
    call SysFileTree systemDir || '/*', 'sys.', 'FO'
    do i = 1 to sys.0
      b = sys.i~substr(sys.i~lastPos('/') + 1)
      low = b~lower
      if low~right(4) == '.cls' | low~right(4) == '.rex' then system~put(b)
    end
  end
  root = root~strip('T', '/')
  files = .array~new
  byPath = .directory~new
  byBase = .directory~new
  byLowBase = .directory~new
  projects = .directory~new
  scanner = .BodySlamScanner~new
  classes = .directory~new
  closures = .directory~new
  log = .array~new
  builtins = .set~new
  do name over .environment~allIndexes
    builtins~put(name~upper)
  end
  do name over .local~allIndexes
    builtins~put(name~upper)
  end
  do name over .array~of('NIL', 'TRUE', 'FALSE', 'CONTEXT', 'LINE', 'RS', 'METHODS', 'RESOURCES', 'ENDOFLINE', 'ROUTINES', 'ENVIRONMENT', 'LOCAL', 'STDIN', 'STDOUT', 'STDERR', 'STDQUE', 'INPUT', 'OUTPUT', 'ERROR', 'DEBUGINPUT', 'TRACEOUTPUT', 'SYSCARGS')
    builtins~put(name)
  end

/* ---------- paths and projects ---------- */

::method normalize class
  use strict arg path
  out = .array~new
  do part over path~makeArray('/')
    if part == '' then iterate
    if part == '.' then iterate
    if part == '..' then do
      if out~items > 0 then do
        if out[out~last] \== '..' then do
          out~delete(out~last)
          iterate
        end
      end
      out~append('..')
      iterate
    end
    out~append(part)
  end
  return out~makeString('L', '/')

::method projectOf class
  use strict arg rel
  parts = rel~makeArray('/')
  if parts~items >= 3 then return parts[1] || '/' || parts[2]
  if parts~items = 2 then return parts[1]
  return '(root)'

/* family and version from a project's last name: alchemy_objects_v0.8 -> alchemy_objects, 0.8 */
::method familyOf class
  use strict arg project
  name = project~substr(project~lastPos('/') + 1)
  low = name~lower
  p = 0
  i = low~lastPos('v')
  do while i > 1
    sep = low~substr(i - 1, 1)
    if sep == '_' | sep == '-' then do
      if datatype(low~substr(i + 1, 1), 'W') then do
        p = i
        leave
      end
    end
    i = low~lastPos('v', i - 1)
  end
  if p = 0 then return .array~of(name, '')
  return .array~of(name~left(p - 2), name~substr(p + 1))

::method rexxFile class
  use strict arg rel
  base = rel~substr(rel~lastPos('/') + 1)
  dot = base~lastPos('.')
  if dot = 0 then return .false
  ext = base~substr(dot + 1)~lower
  return wordpos(ext, 'rex cls rexx rxs frm testgroup') > 0

/* ---------- walk ---------- */

::method walk
  expose root files byPath byBase byLowBase projects
  call SysFileTree root || '/*', 'found.', 'FSO'
  skip = root || '/.git/'
  do i = 1 to found.0
    full = found.i
    if full~left(skip~length) == skip then iterate
    rel = full~substr(root~length + 2)
    proj = .BodySlam~projectOf(rel)
    if \projects~hasIndex(proj) then do
      fv = .BodySlam~familyOf(proj)
      projects[proj] = .directory~of(('NAME', proj), ('FAMILY', fv[1]), ('VERSION', fv[2]), ('ID', projects~items + 1))
    end
    f = .directory~new
    f['ID'] = files~items + 1
    f['PATH'] = rel
    f['DIR'] = .BodySlam~dirOf(rel)
    f['BASE'] = rel~substr(rel~lastPos('/') + 1)
    f['PROJECT'] = proj
    f['REXX'] = .BodySlam~rexxFile(rel)
    f['LINES'] = 0
    f['REQS'] = .array~new
    f['USES'] = .array~new
    f['CLASSES'] = .array~new
    f['ROUTINES'] = .array~new
    f['TOPICS'] = .array~new
    files~append(f)
    byPath[rel] = f
    self~addTo(byBase, f['BASE'], f)
    self~addTo(byLowBase, f['BASE']~lower, f)
  end
  return files~items

::method dirOf class
  use strict arg rel
  slash = rel~lastPos('/')
  if slash = 0 then return ''
  return rel~left(slash - 1)

::method addTo
  use strict arg dir, key, item
  if \dir~hasIndex(key) then dir[key] = .array~new
  dir[key]~append(item)

/* ---------- scan ---------- */

::method scanAll
  expose files scanner classes root
  n = 0
  do f over files
    if \f['REXX'] then iterate
    got = scanner~scan(root || '/' || f['PATH'])
    f['LINES'] = got[2]
    n += 1
    do fact over got[1]
      kind = fact[1]
      select
        when kind == 'REQUIRES' then f['REQS']~append(.directory~of(('LINE', fact[2]), ('NAME', fact[3]), ('KIND', fact[4]), ('NS', fact[5])))
        when kind == 'CLASS' then do
          c = .directory~of(('LINE', fact[2]), ('NAME', fact[3]~upper), ('DISPLAY', fact[3]), ('PUBLIC', fact[4]), ('PARENT', fact[5]), ('INHERIT', fact[6]), ('FILE', f))
          f['CLASSES']~append(c)
          self~addTo(classes, c['NAME'], c)
          if fact[5] \== '' then f['USES']~append(.directory~of(('LINE', fact[2]), ('NAME', fact[5]), ('DISPLAY', fact[5]), ('COUNT', 1), ('ROLE', 'PARENT')))
          do w over fact[6]~makeArray(' ')
            if w \== '' then f['USES']~append(.directory~of(('LINE', fact[2]), ('NAME', w), ('DISPLAY', w), ('COUNT', 1), ('ROLE', 'INHERIT')))
          end
        end
        when kind == 'ROUTINE' then f['ROUTINES']~append(.directory~of(('LINE', fact[2]), ('NAME', fact[3]), ('PUBLIC', fact[4])))
        when kind == 'USE' then f['USES']~append(.directory~of(('LINE', fact[2]), ('NAME', fact[3]), ('DISPLAY', fact[5]), ('COUNT', fact[4]), ('ROLE', 'CODE')))
        otherwise f['TOPICS']~append(.directory~of(('LINE', fact[2]), ('TOPIC', fact[3]), ('ROLE', kind)))
      end
    end
  end
  return n

/* ---------- resolve requires ---------- */

::method tries class
  use strict arg name
  base = name~substr(name~lastPos('/') + 1)
  if base~pos('.') > 0 then return .array~of(name)
  return .array~of(name || '.cls', name || '.rex', name)

/* files whose path ends with /tail (or is tail); tail has no leading ../ */
::method endingIn
  expose byBase
  use strict arg tail, index, lower
  base = tail~substr(tail~lastPos('/') + 1)
  if lower then do
    base = base~lower
    tail = tail~lower
  end
  out = .array~new
  if \index~hasIndex(base) then return out
  do f over index[base]
    p = f['PATH']
    if lower then p = p~lower
    if p == tail then out~append(f)
    else if p~right(tail~length + 1) == '/' || tail then out~append(f)
  end
  return out

::method resolveOne
  expose byPath byBase byLowBase system
  use strict arg f, r
  r['TARGETS'] = .array~new
  r['SHADOWS'] = 0
  if r['KIND'] == 'LIBRARY' then do
    r['LEVEL'] = 'LIBRARY'
    return
  end
  if r['KIND'] == 'INVALID' then do
    r['LEVEL'] = 'INVALID'
    return
  end
  name = r['NAME']
  tryList = .BodySlam~tries(name)
  /* 1. the requiring file's own directory */
  do t over tryList
    if t~left(1) == '/' then iterate
    if f['DIR'] == '' then p = .BodySlam~normalize(t)
    else p = .BodySlam~normalize(f['DIR'] || '/' || t)
    if byPath~hasIndex(p) then do
      if system~hasIndex(t~substr(t~lastPos('/') + 1)) then r['SHADOWS'] = 1
      r['LEVEL'] = 'LOCAL'
      r['TARGETS']~append(byPath[p])
      return
    end
  end
  /* 2 and 3: where it could be, by the name's tail (a leading ../ or ./ says nothing outside step 1) */
  do t over tryList
    tail = .BodySlam~normalize(t)
    do while tail~left(3) == '../'
      tail = tail~substr(4)
    end
    if tail == '' then iterate
    hits = self~endingIn(tail, byBase, .false)
    if hits~items = 0 then iterate
    if system~hasIndex(t~substr(t~lastPos('/') + 1)) then r['SHADOWS'] = 1
    inProject = .array~new
    do h over hits
      if h['PROJECT'] == f['PROJECT'] then inProject~append(h)
    end
    if inProject~items = 1 then do
      r['LEVEL'] = 'PROJECT'
      r['TARGETS'] = inProject
      return
    end
    if inProject~items > 1 then do
      r['LEVEL'] = 'AMBIGUOUS'
      r['TARGETS'] = inProject
      return
    end
    if hits~items = 1 then r['LEVEL'] = 'ESTATE'
    else r['LEVEL'] = 'AMBIGUOUS'
    r['TARGETS'] = hits
    return
  end
  do t over tryList
    if system~hasIndex(t) then do
      r['LEVEL'] = 'SYSTEM'
      return
    end
  end
  do t over tryList
    tail = .BodySlam~normalize(t)
    do while tail~left(3) == '../'
      tail = tail~substr(4)
    end
    hits = self~endingIn(tail, byLowBase, .true)
    if hits~items > 0 then do
      r['LEVEL'] = 'CASE_ONLY'
      r['TARGETS'] = hits
      return
    end
  end
  r['LEVEL'] = 'MISSING'

::method resolveAll
  expose files
  n = 0
  do f over files
    do r over f['REQS']
      self~resolveOne(f, r)
      n += 1
    end
  end
  return n

/* every file the requires reach from f (f not included unless a cycle returns to it) */
::method closure
  expose closures
  use strict arg f
  key = f['ID']
  if closures~hasIndex(key) then return closures[key]
  seen = .set~new
  todo = .queue~new
  do r over f['REQS']
    do t over r['TARGETS']
      if r['LEVEL'] \== 'CASE_ONLY' then todo~queue(t)
    end
  end
  do while todo~items > 0
    g = todo~pull
    if seen~hasIndex(g['ID']) then iterate
    seen~put(g['ID'])
    do r over g['REQS']
      do t over r['TARGETS']
        if r['LEVEL'] \== 'CASE_ONLY' then do
          if \seen~hasIndex(t['ID']) then todo~queue(t)
        end
      end
    end
  end
  closures[key] = seen
  return seen

::method missingInReach
  expose files
  use strict arg f, reach
  do r over f['REQS']
    if r['LEVEL'] == 'MISSING' then return .true
  end
  do id over reach
    g = files[id]
    do r over g['REQS']
      if r['LEVEL'] == 'MISSING' then return .true
    end
  end
  return .false

::method classifyUses
  expose files classes builtins
  n = 0
  do f over files
    own = .set~new
    do c over f['CLASSES']
      own~put(c['NAME'])
    end
    do u over f['USES']
      n += 1
      u['TARGET'] = .nil
      name = u['NAME']
      if own~hasIndex(name) then do
        u['HOW'] = 'SELF'
        u['TARGET'] = f
        iterate
      end
      if classes~hasIndex(name) then do
        reach = self~closure(f)
        pub = .nil
        priv = .nil
        do c over classes[name]
          if reach~hasIndex(c['FILE']['ID']) then do
            if c['PUBLIC'] = 1 then do
              if pub == .nil then pub = c
            end
            else if priv == .nil then priv = c
          end
        end
        if pub \== .nil then do
          u['HOW'] = 'REQUIRED'
          u['TARGET'] = pub['FILE']
          iterate
        end
        if builtins~hasIndex(name) then do
          u['HOW'] = 'BUILTIN'
          iterate
        end
        if priv \== .nil then do
          u['HOW'] = 'NOT_PUBLIC'
          u['TARGET'] = priv['FILE']
          iterate
        end
        u['HOW'] = 'UNDECLARED'
        if self~missingInReach(f, reach) then u['HOW'] = 'BEHIND_MISSING'
        iterate
      end
      if builtins~hasIndex(name) then u['HOW'] = 'BUILTIN'
      else u['HOW'] = 'UNKNOWN'
    end
  end
  return n

/* ---------- declared dependencies (DEPENDENCIES.* at a project's root) ---------- */

::method declared
  expose files root
  out = .array~new
  do f over files
    if f['BASE']~upper~left(12) \== 'DEPENDENCIES' then iterate
    if f['DIR'] \== f['PROJECT'] then iterate
    s = .stream~new(root || '/' || f['PATH'])
    if s~open('read shareread') \= 'READY:' then iterate
    lines = s~arrayIn
    s~close
    seenHere = .set~new
    do n = 1 to lines~items
      text = lines[n]~translate(' ', '`"''()[],;:*|<>=')
      do w over text~makeArray(' ')
        if w == '' then iterate
        w = w~strip('T', '.')
        if w~pos('/') > 0 then w = w~substr(w~lastPos('/') + 1)
        if w~right(4)~lower == '.zip' then w = w~left(w~length - 4)
        fv = .BodySlam~familyOf(w)
        if fv[2] == '' then iterate
        if w \== w~lower then iterate
        if seenHere~hasIndex(w) then iterate
        seenHere~put(w)
        out~append(.directory~of(('PROJECT', f['PROJECT']), ('LINE', n), ('DECLARED', w), ('FAMILY', fv[1]), ('VERSION', fv[2]), ('FILE', f['PATH'])))
      end
    end
  end
  return out

/* ---------- the database ---------- */

::method q
  expose session
  use strict arg sql, binds = .nil
  if binds == .nil then r = session~execute(sql)
  else r = session~executeBound(sql, binds)
  if r~status \= 'SUCCESS' then raise syntax 98.900 array('Body Slam store:' r~message '|' sql)
  return r

/* Rexx/SQL 2.6B3 fails ("SQL logic error") when a bound value is the empty string (measured), so an
   empty value is written into the statement as '' and only the others are bound. */
::method row
  use arg sql
  binds = .array~new
  text = ''
  rest = sql
  do i = 2 to arg()
    p = rest~pos('?')
    text = text || rest~left(p - 1)
    rest = rest~substr(p + 1)
    if arg(i) == '' then text = text || "''"
    else do
      text = text || '?'
      binds~append(.array~of('CHAR', arg(i)))
    end
  end
  text = text || rest
  if binds~items = 0 then return self~q(text)
  return self~q(text, binds)

::method store
  expose session files projects
  use strict arg dbPath, decl
  if dbPath \== ':memory:' then call SysFileDelete dbPath
  session = .RexxSqlSqliteSession~open(dbPath)
  self~q('CREATE TABLE project (id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE, family TEXT NOT NULL, version TEXT NOT NULL)')
  self~q('CREATE TABLE file (id INTEGER PRIMARY KEY, project_id INTEGER NOT NULL, path TEXT NOT NULL UNIQUE, base TEXT NOT NULL, rexx INTEGER NOT NULL, lines INTEGER NOT NULL)')
  self~q('CREATE TABLE req (id INTEGER PRIMARY KEY, file_id INTEGER NOT NULL, line INTEGER NOT NULL, name TEXT NOT NULL, kind TEXT NOT NULL, ns TEXT, level TEXT NOT NULL, ncand INTEGER NOT NULL, shadows INTEGER NOT NULL)')
  self~q('CREATE TABLE req_target (req_id INTEGER NOT NULL, file_id INTEGER NOT NULL, target_id INTEGER NOT NULL)')
  self~q('CREATE TABLE cls (file_id INTEGER NOT NULL, line INTEGER NOT NULL, name TEXT NOT NULL, display TEXT NOT NULL, public INTEGER NOT NULL, parent TEXT, inherit TEXT)')
  self~q('CREATE TABLE routine (file_id INTEGER NOT NULL, line INTEGER NOT NULL, name TEXT NOT NULL, public INTEGER NOT NULL)')
  self~q('CREATE TABLE use (file_id INTEGER NOT NULL, line INTEGER NOT NULL, name TEXT NOT NULL, display TEXT NOT NULL, count INTEGER NOT NULL, role TEXT NOT NULL, how TEXT NOT NULL, target_id INTEGER)')
  self~q('CREATE TABLE topic (file_id INTEGER NOT NULL, line INTEGER NOT NULL, topic TEXT NOT NULL, role TEXT NOT NULL)')
  self~q('CREATE TABLE decl (project_id INTEGER NOT NULL, file TEXT NOT NULL, line INTEGER NOT NULL, declared TEXT NOT NULL, family TEXT NOT NULL, version TEXT NOT NULL)')
  self~q('BEGIN IMMEDIATE')
  do p over projects~allItems
    self~row('INSERT INTO project (id, path, family, version) VALUES (?, ?, ?, ?)', p['ID'], p['NAME'], p['FAMILY'], p['VERSION'])
  end
  rid = 0
  do f over files
    pid = projects[f['PROJECT']]['ID']
    self~row('INSERT INTO file (id, project_id, path, base, rexx, lines) VALUES (?, ?, ?, ?, ?, ?)', f['ID'], pid, f['PATH'], f['BASE'], f['REXX']~?(1, 0), f['LINES'])
    do r over f['REQS']
      rid += 1
      self~row('INSERT INTO req (id, file_id, line, name, kind, ns, level, ncand, shadows) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', rid, f['ID'], r['LINE'], r['NAME'], r['KIND'], r['NS'], r['LEVEL'], r['TARGETS']~items, r['SHADOWS'])
      do t over r['TARGETS']
        self~row('INSERT INTO req_target (req_id, file_id, target_id) VALUES (?, ?, ?)', rid, f['ID'], t['ID'])
      end
    end
    do c over f['CLASSES']
      self~row('INSERT INTO cls (file_id, line, name, display, public, parent, inherit) VALUES (?, ?, ?, ?, ?, ?, ?)', f['ID'], c['LINE'], c['NAME'], c['DISPLAY'], c['PUBLIC'], c['PARENT'], c['INHERIT'])
    end
    do x over f['ROUTINES']
      self~row('INSERT INTO routine (file_id, line, name, public) VALUES (?, ?, ?, ?)', f['ID'], x['LINE'], x['NAME'], x['PUBLIC'])
    end
    do u over f['USES']
      if u['HOW'] == 'BUILTIN' then iterate
      tid = ''
      if u['TARGET'] \== .nil then tid = u['TARGET']['ID']
      self~row('INSERT INTO use (file_id, line, name, display, count, role, how, target_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', f['ID'], u['LINE'], u['NAME'], u['DISPLAY'], u['COUNT'], u['ROLE'], u['HOW'], tid)
    end
    do t over f['TOPICS']
      self~row('INSERT INTO topic (file_id, line, topic, role) VALUES (?, ?, ?, ?)', f['ID'], t['LINE'], t['TOPIC'], t['ROLE'])
    end
  end
  do d over decl
    self~row('INSERT INTO decl (project_id, file, line, declared, family, version) VALUES (?, ?, ?, ?, ?, ?)', projects[d['PROJECT']]['ID'], d['FILE'], d['LINE'], d['DECLARED'], d['FAMILY'], d['VERSION'])
  end
  self~q('COMMIT')
  self~q('CREATE INDEX ix_req_file ON req (file_id)')
  self~q('CREATE INDEX ix_rt_target ON req_target (target_id)')
  self~q('CREATE INDEX ix_rt_file ON req_target (file_id)')
  self~q('CREATE INDEX ix_cls_name ON cls (name)')
  self~q('CREATE INDEX ix_use_name ON use (name)')
  self~q('CREATE INDEX ix_file_project ON file (project_id)')
  self~q('CREATE INDEX ix_topic ON topic (topic)')
  /* how blanked builtins: kept out of the table, counted here */
  return session

/* The whole run: walk, scan, resolve, classify, store. Returns a directory of counts and seconds. */
::method ingest
  expose log session
  use strict arg dbPath
  out = .directory~new
  t0 = time('E')
  out['FILES'] = self~walk
  out['SCANNED'] = self~scanAll
  out['REQUIRES'] = self~resolveAll
  out['USES'] = self~classifyUses
  decl = self~declared
  out['DECLARED'] = decl~items
  t1 = time('E')
  self~store(dbPath, decl)
  out['READ_SECONDS'] = format(t1 - t0, , 1)
  out['STORE_SECONDS'] = format(time('E') - t1, , 1)
  return out
