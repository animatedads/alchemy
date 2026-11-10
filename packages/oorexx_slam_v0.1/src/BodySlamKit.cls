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
 * kit(dir, rexxPath, cwd) scans every ooRexx file under dir (the package as it will run, in any checkout),
 * and resolves each ::requires in the interpreter's order, measured on ooRexx 5.3.0 r13196 (README_BODYSLAM):
 * the requiring file's directory, the current directory, each REXX_PATH entry, then PATH. A file found is
 * placed in the estate by its path (<area>/<project>/...), and its family's version is compared with the
 * newest version of that family in Body Slam's database (BodySlam~versionKey).
 *
 *   OK        loads the newest version of its family, or a file of the package itself
 *   OLDER     loads an older version than the newest in the estate (named)
 *   TWO       the same family loads at more than one version in this package
 *   SYSTEM    loads from outside the estate (shipped with ooRexx, or elsewhere on PATH)
 *   MISSING   found nowhere: the package cannot start
 *   INVALID   ::requires (expr): ooRexx refuses it (Error 19.904)
 *   LIBRARY   a native library: not checked here
 * Verdict: FAIL with any MISSING or INVALID, WARN with any OLDER or TWO, else PASS.
 */

::requires 'BodySlam.cls'
::requires 'BodySlamReport.cls'
::requires 'BodySlamScanner.cls'

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
    cand = parts[1] || '/' || parts[2]
    if best == '' | p > bestAt then do
      best = cand; bestAt = p
    end
  end
  return best

::method kit
  use strict arg dir, rexxPath, cwd = (dir)
  dir = dir~strip('T', '/')
  scanner = .BodySlamScanner~new
  call SysFileTree dir || '/*', 'found.', 'FSO'
  own = self~projectOfPath(dir || '/x')
  pathDirs = .array~new
  do p over rexxPath~makeArray(':')
    if p \== '' then pathDirs~append(p~strip('T', '/'))
  end
  sysDirs = .array~new
  do p over value('PATH',, 'ENVIRONMENT')~makeArray(':')
    if p \== '' then sysDirs~append(p~strip('T', '/'))
  end
  seen = .directory~new          /* name|found -> result row */
  famVersions = .directory~new   /* family -> set of versions loaded */
  rows = .array~new
  files = 0
  do i = 1 to found.0
    full = found.i
    if \.BodySlam~rexxFile(full) then iterate
    files += 1
    got = scanner~scan(full)
    fileDir = full~left(full~lastPos('/') - 1)
    do fact over got[1]
      if fact[1] \== 'REQUIRES' then iterate
      at = full~substr(dir~length + 2) || ':' || fact[2]
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
      key = name || '|' || hit
      if seen~hasIndex(key) then iterate
      seen[key] = 1
      if hit == '' then do
        rows~append(.array~of('MISSING', name, at, '', 'not in the file''s directory, the current directory, REXX_PATH or PATH'))
        iterate
      end
      proj = self~projectOfPath(hit)
      if hit~left(dir~length + 1) == dir || '/' then do
        rows~append(.array~of('OK', name, at, hit, 'the package''s own file'))
        iterate
      end
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
