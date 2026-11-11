/* BodySlamKit.cls - Body Slam v0.2: the kit check. Before a job: what will this package actually load,
 * and is each thing it loads the newest version of its family in the estate?
 *
 * Architecture: Tom Dyer ("check your line and your parachute": name the kit and check every item before
 * starting). Code: Claude (Opus 5.5), 2026-11-10.
 *
 * The failure it exists for: on 7 Nov the flight planner loaded crypto.cls from oorexx_crypto_v0.1 (pure
 * ooRexx SHA-512, about 1.2 KB/s) because its REXX_PATH named v0.1, while oorexx_crypto_v0.8.3 hashes the
 * same through the Foreign Runtime about 2,000 times faster. Nothing told anyone until Tom did.
 *
 * kit(dir, rexxPath, cwd): every ooRexx file under dir (the package as it will run, in any checkout).
 * kitFrom(files, rexxPath, cwd, dir): the files given and, transitively, every file they load: exactly
 *   what one program will load.
 * run(pkgDir, repoRoot, work): each test of the package's integration.json run as the running Autobuild
 *   (Python v0.5.x) runs it, in a scratch copy, with ALCHEMY_REPO_ROOT, ALCHEMY_PACKAGE_ROOT and
 *   ALCHEMY_AUTOBUILD_ROOT set, and a stand-in "rexx" first on PATH. The stand-in records the cwd,
 *   REXX_PATH and arguments of every ooRexx program the test starts, and starts none of them; each
 *   recorded program is then followed (kitFrom) with exactly that REXX_PATH and cwd. Shell wrappers,
 *   make, python: whatever starts rexx is seen, with the environment it really built.
 *
 * Each ::requires is resolved in the interpreter's order, measured on ooRexx 5.3.0 r13196
 * (README_BODYSLAM): the requiring file's directory, the current directory, each REXX_PATH entry, PATH.
 * A file found is placed in the estate by its path (<area>/<project>/...), and its family's version is
 * compared with the newest version of that family in Body Slam's database (BodySlam~versionKey).
 *
 *   OK        loads the newest version of its family, or a file of the package itself
 *   OLDER     loads an older version than the newest in the estate (named)
 *   TWO       the same family loads at more than one version
 *   SYSTEM    loads from outside the estate (shipped with ooRexx, or elsewhere on PATH)
 *   MISSING   found nowhere: the program cannot start
 *   INVALID   ::requires (expr): ooRexx refuses it (Error 19.904)
 *   LIBRARY   a native library: not checked here
 * Verdict: FAIL with any MISSING or INVALID, WARN with any OLDER or TWO, else PASS.
 */

::requires 'BodySlam.cls'
::requires 'BodySlamReport.cls'
::requires 'BodySlamScanner.cls'
::requires 'json.cls'

::class BodySlamKit public

::method init
  expose report newest areas
  use strict arg report
  newest = .nil
  areas = .nil

/* family -> its newest project row, from the database */
::method newestOf
  expose report newest
  use strict arg fam
  if newest == .nil then do
    newest = .directory~new
    fams = report~familyRows
    do f over fams~allIndexes
      newest[f] = fams[f]['BEST']
    end
  end
  return newest[fam]

/* the estate's top-level areas (packages, examples, spheres, ...) */
::method areas
  expose report areas
  if areas == .nil then do
    areas = .array~new
    do r over report~q("SELECT DISTINCT CASE WHEN INSTR(path, '/') > 0 THEN SUBSTR(path, 1, INSTR(path, '/') - 1) ELSE path END AS a FROM project")
      areas~append(r['A'])
    end
  end
  return areas

/* "area/project" for an absolute file path, or '' if it is not in an estate-shaped tree */
::method projectOfPath
  use strict arg full
  best = ''; bestAt = 0
  do a over self~areas
    key = '/' || a || '/'
    p = full~lastPos(key)
    if p = 0 then iterate
    rest = full~substr(p + 1)
    parts = rest~makeArray('/')
    if parts~items < 3 then iterate
    if p > bestAt then do
      best = parts[1] || '/' || parts[2]; bestAt = p
    end
  end
  return best

/* every ooRexx file under dir, scanned without following */
::method kit
  use strict arg dir, rexxPath, cwd = (dir)
  dir = dir~strip('T', '/')
  call SysFileTree dir || '/*', 'found.', 'FSO'
  files = .array~new
  do i = 1 to found.0
    if .BodySlam~rexxFile(found.i) then files~append(found.i)
  end
  return self~check(files, .false, dir, rexxPath, cwd)

/* the given files and everything they load, transitively */
::method kitFrom
  use strict arg files, rexxPath, cwd, dir
  return self~check(files, .true, dir~strip('T', '/'), rexxPath, cwd)

/* The check itself: a queue of files; each one's requires resolved and judged; with follow, every
   ooRexx file found is queued in turn (once). */
::method check
  use strict arg queue, follow, dir, rexxPath, cwd
  scanner = .BodySlamScanner~new
  own = self~projectOfPath(dir || '/x')
  pathDirs = self~dirsOf(rexxPath)
  sysDirs = self~dirsOf(value('PATH',, 'ENVIRONMENT'))
  seen = .directory~new          /* name|found -> 1 */
  scanned = .set~new
  famVersions = .directory~new   /* family -> set of versions loaded */
  rows = .array~new
  files = 0
  k = 0
  do while k < queue~items
    k += 1
    full = queue[k]
    if scanned~hasIndex(full) then iterate
    scanned~put(full)
    files += 1
    got = scanner~scan(full)
    fileDir = full~left(full~lastPos('/') - 1)
    if full~left(dir~length + 1) == dir || '/' then shown = full~substr(dir~length + 2)
    else shown = full
    do fact over got[1]
      if fact[1] \== 'REQUIRES' then iterate
      at = shown || ':' || fact[2]
      name = fact[3]; kind = fact[4]
      if kind == 'INVALID' then do
        rows~append(.array~of('INVALID', name, at, '', 'ooRexx refuses ::requires (expr)'))
        iterate
      end
      if kind == 'LIBRARY' then do
        if \seen~hasIndex('LIB|' || name) then rows~append(.array~of('LIBRARY', name, at, '', 'native library, not checked'))
        seen['LIB|' || name] = 1
        iterate
      end
      hit = self~resolve(name, fileDir, cwd, pathDirs, sysDirs)
      if follow & hit \== '' then do
        if .BodySlam~rexxFile(hit) then queue~append(hit)
      end
      key = name || '|' || hit
      if seen~hasIndex(key) then iterate
      seen[key] = 1
      if hit == '' then do
        rows~append(.array~of('MISSING', name, at, '', 'not in the file''s directory, the current directory, REXX_PATH or PATH'))
        iterate
      end
      if hit~left(dir~length + 1) == dir || '/' then do
        rows~append(.array~of('OK', name, at, hit, 'the package''s own file'))
        iterate
      end
      proj = self~projectOfPath(hit)
      if proj == '' then do
        rows~append(.array~of('SYSTEM', name, at, hit, 'outside the estate'))
        iterate
      end
      fv = .BodySlam~familyOf(proj)
      fam = fv[1]; ver = fv[2]
      if \famVersions~hasIndex(fam) then famVersions[fam] = .set~new
      famVersions[fam]~put(ver)
      best = self~newestOf(fam)
      if best == .nil then do
        rows~append(.array~of('OK', name, at, hit, fam ver '(family not in the database)'))
        iterate
      end
      if proj == own then do
        rows~append(.array~of('OK', name, at, hit, 'the package''s own project'))
        iterate
      end
      if .BodySlam~versionKey(ver) << .BodySlam~versionKey(best['VER']) then
        rows~append(.array~of('OLDER', name, at, hit, fam ver '- newest in the estate is' best['PATH']))
      else rows~append(.array~of('OK', name, at, hit, fam ver '(newest)'))
    end
  end
  do fam over famVersions~allIndexes
    if famVersions[fam]~items > 1 then
      rows~append(.array~of('TWO', fam, '', '', 'loaded at versions' famVersions[fam]~allItems~sort~makeString('L', ' ')))
  end
  return self~summarise(rows, dir, files)

::method summarise
  use strict arg rows, dir, files
  counts = .directory~new
  do s over .array~of('OK', 'OLDER', 'TWO', 'SYSTEM', 'MISSING', 'INVALID', 'LIBRARY'); counts[s] = 0; end
  do r over rows; counts[r[1]] = counts[r[1]] + 1; end
  verdict = 'PASS'
  if counts['OLDER'] + counts['TWO'] > 0 then verdict = 'WARN'
  if counts['MISSING'] + counts['INVALID'] > 0 then verdict = 'FAIL'
  out = .array~new
  out~append('kit' verdict '|' dir '|' files 'ooRexx files |' rows~items 'distinct loads | OK' counts['OK'] 'OLDER' counts['OLDER'] 'TWO' counts['TWO'] 'SYSTEM' counts['SYSTEM'] 'MISSING' counts['MISSING'] 'INVALID' counts['INVALID'] 'LIBRARY' counts['LIBRARY'])
  /* problems first, then the rest */
  do s over .array~of('MISSING', 'INVALID', 'OLDER', 'TWO', 'SYSTEM', 'LIBRARY', 'OK')
    do r over rows
      if r[1] \== s then iterate
      line = '  ' r[1]~left(7) r[2]
      if r[3] \== '' then line = line '(' || r[3] || ')'
      if r[4] \== '' then line = line '->' r[4]
      out~append(line '|' r[5])
    end
  end
  return out

::method dirsOf
  use strict arg path
  out = .array~new
  do p over path~makeArray(':')
    if p \== '' then out~append(p~strip('T', '/'))
  end
  return out

/* where ooRexx 5.3.0 loads NAME from (measured order); '' if nowhere */
::method resolve
  use strict arg name, fileDir, cwd, pathDirs, sysDirs
  dirs = .array~of(fileDir, cwd)
  do d over pathDirs; dirs~append(d); end
  do d over sysDirs; dirs~append(d); end
  do d over dirs
    do t over .BodySlam~tries(name)
      if t~left(1) == '/' then cand = t
      else cand = d || '/' || t
      if SysFileExists(cand) then do
        if \SysIsFileDirectory(cand) then return cand
      end
    end
  end
  return ''


/* ---------- per test, as the running Autobuild runs it ---------- */

::method run
  use strict arg pkgDir, repoRoot, work
  pkgDir = pkgDir~strip('T', '/'); repoRoot = repoRoot~strip('T', '/'); work = work~strip('T', '/')
  out = .array~new
  manifest = pkgDir || '/integration.json'
  if \SysFileExists(manifest) then do
    out~append('kitrun FAIL |' pkgDir '| no integration.json: Autobuild cannot run this package')
    return out
  end
  doc = self~readJson(manifest)
  if doc == .nil then do
    out~append('kitrun FAIL |' pkgDir '| integration.json does not parse')
    return out
  end
  pkgName = pkgDir~substr(pkgDir~lastPos('/') + 1)
  scratch = work || '/kitrun_' || pkgName
  shimDir = work || '/kitrun_shim'
  address system 'rm -rf' q(scratch) '&& mkdir -p' q(work) q(shimDir) '&& cp -a' q(pkgDir) q(scratch)
  /* the stand-in: records cwd, REXX_PATH, arguments, and where the program was at the moment it was
     started (the cwd, then REXX_PATH). Some tests write a program into a temporary directory, run it
     there, and remove the directory on exit; kitrun looks after the test has finished, so without
     this record such a program reads as "not found" (oorexx_rexxsql_backend_v0.1's SSC live suites,
     11 Nov). Starts nothing. */
  shim = shimDir || '/rexx'
  call SysFileDelete shim
  s = .stream~new(shim); s~open('write replace')
  s~lineOut('#!/bin/sh')
  s~lineOut('# Body Slam kitrun stand-in for rexx: records each ooRexx program a test would start, runs none.')
  s~lineOut('p=""')
  s~lineOut('for a in "$@"; do case "$a" in -e) p=""; break;; -*) ;; *) p="$a"; break;; esac; done')
  s~lineOut('found=""')
  s~lineOut('case "$p" in')
  s~lineOut('  "") ;;')
  s~lineOut('  /*) [ -f "$p" ] && found="$p" ;;')
  s~lineOut('  *) if [ -f "$PWD/$p" ]; then found="$PWD/$p"; else')
  s~lineOut('       IFS=:; for d in $REXX_PATH; do if [ -z "$found" ] && [ -f "$d/$p" ]; then found="$d/$p"; fi; done; unset IFS')
  s~lineOut('     fi ;;')
  s~lineOut('esac')
  s~lineOut('printf ''%s\t%s\t%s\t%s\t%s\n'' "$PWD" "$REXX_PATH" "$PATH" "$found" "$*" >> "$BODYSLAM_KIT_LOG"')
  s~lineOut('exit 0')
  s~close
  address system 'chmod 755' q(shim)
  worst = 'PASS'
  tests = doc['tests']
  if tests == .nil then tests = .array~new
  /* The environment as the running Autobuild builds it: v0.4's _apply_environment (kept by v0.5,
     v0.5.1 and v0.5.2), first with the package's environment over the service's own, then with the
     test's environment over that; then v0.4's _requirements. The service's REXX_PATH is taken as empty,
     so nothing of this machine leaks in. */
  base = .directory~new
  base['PATH'] = value('PATH',, 'ENVIRONMENT')
  base['REXX_PATH'] = ''
  pkgSpec = doc['environment']; if pkgSpec == .nil then pkgSpec = .directory~new
  wd = doc['working_directory']; if wd == .nil then wd = '.'
  n = 0
  do t over tests
    n += 1
    name = t['name']; if name == .nil then name = 'test' n
    argv = t['argv']; if argv == .nil then argv = .array~new
    cwd = t['cwd']; if cwd == .nil then cwd = wd
    if cwd~left(1) \== '/' then cwd = scratch || '/' || cwd
    secs = t['timeout_seconds']; if secs == .nil then secs = 60
    testSpec = t['environment']; if testSpec == .nil then testSpec = .directory~new
    problems = .array~new
    env = self~applyEnv(base, pkgSpec, scratch, work, repoRoot, problems)
    env = self~applyEnv(env, testSpec, scratch, work, repoRoot, problems)
    do sp over .array~of(pkgSpec, testSpec)
      self~requirements(sp, env, scratch, work, repoRoot, problems)
    end
    if problems~items > 0 then do
      out~append('== test' name '| argv' argv~makeString('L', ' ') '| AUTOBUILD_ENV_CONTRACT: Autobuild refuses to start it (exit 125)')
      do p over problems; out~append('     ' p~changeStr(scratch, pkgDir)); end
      worst = 'FAIL'
      iterate
    end
    log = work || '/kitrun_' || n || '.log'
    call SysFileDelete log
    cmd = ''
    do a over argv; cmd = cmd q(a~string); end
    assigns = ''
    do k over env~allIndexes
      if k == 'PATH' then iterate
      assigns = assigns k || '=' || q(env[k])
    end
    line = 'cd' q(cwd) '&& env' assigns 'BODYSLAM_KIT_LOG=' || q(log) 'PATH=' || q(shimDir || ':' || env['PATH']) ,
      'timeout' secs || 's' cmd '> /dev/null 2>&1'
    address system line
    testRc = rc
    calls = self~calls(log)
    out~append('== test' name '| argv' argv~makeString('L', ' ') '| exit' testRc '|' calls~items 'ooRexx program(s) started')
    if calls~items = 0 then out~append('   (no ooRexx program started: nothing to check)')
    if testRc \= 0 then out~append('   (the test stopped with exit' testRc 'under the stand-in, which prints nothing; programs after that point are not seen)')
    done = .set~new
    do c over calls
      prog = self~entry(c['ARGS'])
      if prog == '' then iterate
      /* the program as ooRexx 5.3.0 finds it (measured 10 Nov): the current directory, then each
         REXX_PATH entry, then each PATH entry (the stand-in's own directory left out) */
      script = self~program(prog, c['CWD'], c['REXX_PATH'], c['PATH'], shimDir)
      key = prog || '|' || script || '|' || c['REXX_PATH'] || '|' || c['CWD']
      if done~hasIndex(key) then iterate
      done~put(key)
      if script == '' then if c['FOUND'] \== '' then do
        out~append('   -- rexx' prog ': the program was at' c['FOUND'] 'when the test started it; the test removed that directory before kitrun could follow its requires (WARN)')
        if worst == 'PASS' then worst = 'WARN'
        iterate
      end
      if script == '' then do
        out~append('   -- rexx' prog ': ooRexx would not find the program (cwd' c['CWD']~changeStr(scratch, pkgDir) || ', then REXX_PATH, then PATH): Error 3.901 (FAIL)')
        worst = 'FAIL'
        iterate
      end
      shown = script~changeStr(scratch, pkgDir)
      lines = self~kitFrom(.array~of(script), c['REXX_PATH'], c['CWD'], scratch)
      v = lines[1]~word(2)
      entries = c['REXX_PATH']~makeArray(':')~items
      out~append('   -- rexx' shown '|' v '| cwd' c['CWD']~changeStr(scratch, pkgDir) '| REXX_PATH entries' entries)
      do i = 2 to lines~items
        if lines[i]~word(1) \== 'OK' then out~append('     ' lines[i]~strip~changeStr(scratch, pkgDir))
      end
      if v == 'FAIL' then worst = 'FAIL'
      else if v == 'WARN' & worst == 'PASS' then worst = 'WARN'
    end
  end
  address system 'rm -rf' q(scratch)
  out~append('kitrun' worst '|' pkgDir '|' n 'tests run as Autobuild runs them, ooRexx programs recorded, not run')
  return out

/* the stand-in's records: CWD, REXX_PATH, ARGS */
::method calls
  use strict arg log
  out = .array~new
  if \SysFileExists(log) then return out
  s = .stream~new(log); s~open('read')
  do while s~lines > 0
    parse value s~lineIn with cwd '09'x rp '09'x path '09'x found '09'x args
    out~append(.directory~of(('CWD', cwd), ('REXX_PATH', rp), ('PATH', path), ('FOUND', found), ('ARGS', args)))
  end
  s~close
  return out

/* the program a rexx command line starts: the first word that is not an option; '' for rexx -e */
::method entry
  use strict arg args
  do w over args~makeArray(' ')
    if w == '' then iterate
    if w == '-e' then return ''
    if w~left(1) == '-' then iterate
    return w
  end
  return ''

::method readJson
  use strict arg f
  signal on syntax name bad
  s = .stream~new(f); s~open('read shareread')
  body = s~charIn(1, s~chars); s~close
  return .json~fromJson(body)
bad:
  return .nil

::routine q
  use strict arg s
  return "'" || s~changeStr("'", "'\''") || "'"

/* where ooRexx finds the program of "rexx PROG": PROG itself if absolute, else the current directory,
   each REXX_PATH entry, each PATH entry (measured on 5.3.0 r13196: cwd before REXX_PATH before PATH);
   '' if nowhere */
::method program
  use strict arg prog, cwd, rexxPath, path, skipDir
  if prog~left(1) == '/' then do
    if SysFileExists(prog) then return prog
    return ''
  end
  dirs = .array~of(cwd)
  do d over self~dirsOf(rexxPath); dirs~append(d); end
  do d over self~dirsOf(path)
    if d \== skipDir then dirs~append(d)
  end
  do d over dirs
    cand = d || '/' || prog
    if SysFileExists(cand) then do
      if \SysIsFileDirectory(cand) then return cand
    end
  end
  return ''

/* Autobuild v0.4 _apply_environment: set (each value expanded), prepend_path and append_path around
   PATH, rexx_path (replace, prepend or append), then the three ALCHEMY_ variables. */
::method applyEnv
  use strict arg base, spec, pkg, work, repo, problems
  e = base~copy
  sets = spec['set']
  if sets \== .nil then do k over sets~allIndexes
    e[k] = self~expand(sets[k]~string, e, pkg, work, repo, problems)
  end
  pre = .array~new; app = .array~new
  if spec['prepend_path'] \== .nil then do x over spec['prepend_path']; pre~append(self~pathItem(x~string, e, pkg, work, repo, problems)); end
  if spec['append_path'] \== .nil then do x over spec['append_path']; app~append(self~pathItem(x~string, e, pkg, work, repo, problems)); end
  if pre~items + app~items > 0 then do
    parts = pre~copy
    if e['PATH'] \== .nil & e['PATH'] \== '' then parts~append(e['PATH'])
    do a over app; parts~append(a); end
    e['PATH'] = parts~makeString('L', ':')
  end
  rp = spec['rexx_path']
  if rp \== .nil then do
    entries = .array~new
    if rp['entries'] \== .nil then do x over rp['entries']; entries~append(self~pathItem(x~string, e, pkg, work, repo, problems)); end
    old = e['REXX_PATH']; if old == .nil then old = ''
    mode = rp['mode']; if mode == .nil then mode = 'replace'
    select
      when mode == 'replace' then parts = entries
      when mode == 'prepend' then do
        parts = entries~copy
        if old \== '' then parts~append(old)
      end
      otherwise do
        parts = .array~new
        if old \== '' then parts~append(old)
        do x over entries; parts~append(x); end
      end
    end
    e['REXX_PATH'] = parts~makeString('L', ':')
  end
  e['ALCHEMY_PACKAGE_ROOT'] = pkg; e['ALCHEMY_AUTOBUILD_ROOT'] = work; e['ALCHEMY_REPO_ROOT'] = repo
  return e

/* Autobuild v0.4 _expand: ${NAME} from the environment and PACKAGE_ROOT, AUTOBUILD_ROOT, REPO_ROOT,
   up to 8 rounds; a token still unresolved is an error */
::method expand
  use strict arg text, env, pkg, work, repo, problems
  map = env~copy
  map['PACKAGE_ROOT'] = pkg; map['AUTOBUILD_ROOT'] = work; map['REPO_ROOT'] = repo
  do round = 1 to 8
    newer = ''
    rest = text
    do forever
      p = rest~pos('${')
      if p = 0 then leave
      e = rest~pos('}', p)
      if e = 0 then leave
      key = rest~substr(p + 2, e - p - 2)
      newer = newer || rest~left(p - 1)
      if map~hasIndex(key) then newer = newer || map[key]
      else newer = newer || '${' || key || '}'
      rest = rest~substr(e + 1)
    end
    newer = newer || rest
    if newer == text then leave
    text = newer
  end
  if text~pos('${') > 0 then problems~append('unresolved environment token in' text)
  return text

/* Autobuild v0.4 _path_item: expanded; relative paths are inside the package */
::method pathItem
  use strict arg value, env, pkg, work, repo, problems
  t = self~expand(value, env, pkg, work, repo, problems)
  if t~left(1) == '/' then return t
  return pkg || '/' || t

/* Autobuild v0.4 _requirements */
::method requirements
  use strict arg spec, env, pkg, work, repo, problems
  if spec['require'] \== .nil then do k over spec['require']
    v = env[k~string]
    if v == .nil | v == '' then problems~append('required environment variable missing:' k)
  end
  if spec['require_dirs'] \== .nil then do k over spec['require_dirs']
    v = env[k~string]
    if v == .nil | v == '' then problems~append('required directory export missing:' k)
    else if \SysIsFileDirectory(v) then problems~append('required directory export is not a directory:' k || '=' || v)
  end
  rp = spec['rexx_path']
  if rp \== .nil then do
    if rp['require_entries'] == .true then do x over rp['entries']
      p = self~pathItem(x~string, env, pkg, work, repo, problems)
      if \SysIsFileDirectory(p) then problems~append('REXX_PATH entry is not a directory:' p)
    end
  end
  return
