/* KitRunStep.cls - Alchemy Workflow v0.1-dev1 step "KitRun" (stage qualify): each test run the way the
 * running Autobuild runs it, recording every ooRexx program it starts and what each would load.
 *
 * Architecture: Tom Dyer ("check your line and your parachute"). Code: Claude (Opus 5.5), 2026-11-11.
 *
 * The work is Body Slam v0.2's kitrun (BodySlamKit~run, oorexx_slam_v0.1); this step only reads its lines
 * into findings. It needs Body Slam's database of the estate (setting BODYSLAM_DB) and Body Slam's src
 * and the Rexx/SQL backend on REXX_PATH; without them it is unavailable or skipped, and says why.
 *
 * Rules:
 *   KR-NOT-FOUND  FAIL  ooRexx would not find a program a test starts (Error 3.901)
 *   KR-MISSING    FAIL  a ::requires found nowhere: the program cannot start
 *   KR-INVALID    FAIL  a ::requires ooRexx refuses (Error 19.904)
 *   KR-ENV        FAIL  Autobuild refuses to start the test (exit 125: its environment contract)
 *   KR-OLDER      WARN  loads an older version of a family than the newest in the estate
 *   KR-TWO        WARN  loads one family at two versions
 */
::requires 'AlchemyWorkflow.cls'
::requires 'BodySlamReport.cls'
::requires 'BodySlamKit.cls'

::class KitRunStep public subclass WorkflowStep
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'

::method id
  return 'KitRun'

::method stage
  return 'qualify'

::method describe
  return 'run each test as Autobuild runs it with a stand-in rexx; follow every program it starts through its requires'

::method skipReason
  use strict arg ctx
  if \ctx~manifest~isA(.Directory) then return 'no usable integration.json (Manifest reports it)'
  db = ctx~setting('BODYSLAM_DB')
  if db == '' then return 'no Body Slam database (set BODYSLAM_DB or --db)'
  if \SysFileExists(db) then return 'Body Slam database' db 'is not there'
  return ''

::method intends
  use strict arg ctx
  tests = ctx~manifest
  if tests \== .nil then tests = tests['tests']
  n = 0
  if tests \== .nil then n = tests~items
  return 'run' n 'test(s) in a scratch copy under' ctx~work || ', programs recorded, none run; check each against' ctx~setting('BODYSLAM_DB')

::method run
  use strict arg ctx, res
  report = .BodySlamReport~new(ctx~setting('BODYSLAM_DB'))
  lines = .BodySlamKit~new(report)~run(ctx~pkgDir, ctx~repoRoot, ctx~work || '/kitrun')
  report~close
  test = ''
  do line over lines
    t = line~strip
    if t~left(7) == '== test' then do
      parse var t '== test' test '|' .
      test = test~strip
      iterate
    end
    if t~left(6) == 'kitrun' then do
      res~note(t)
      iterate
    end
    w = t~word(1)
    select
      when t~pos('Error 3.901') > 0 then self~add(res, ctx, 'KR-NOT-FOUND', 'FAIL', test, t, 'name the program relative to the test''s cwd, or put its directory on the test''s rexx_path')
      when t~pos('AUTOBUILD_ENV_CONTRACT') > 0 then self~add(res, ctx, 'KR-ENV', 'FAIL', test, t, 'satisfy the require, require_dirs and require_entries of the test''s environment')
      when w == 'MISSING' then self~add(res, ctx, 'KR-MISSING', 'FAIL', test, t, 'put the directory that holds it on the test''s rexx_path, or correct the ::requires')
      when w == 'INVALID' then self~add(res, ctx, 'KR-INVALID', 'FAIL', test, t, 'give ::requires a literal file name')
      when w == 'OLDER' then self~add(res, ctx, 'KR-OLDER', 'WARN', test, t, 'move to the newest version named, or say in the README why this one is pinned')
      when w == 'TWO' then self~add(res, ctx, 'KR-TWO', 'WARN', test, t, 'load one version of the family only')
      otherwise nop
    end
  end

::method add
  use strict arg res, ctx, rule, severity, test, evidence, fix
  f = self~finding(rule, severity, 'integration.json', 0, 'test' test || ':' evidence, fix)
  f~reproduce = 'rexx packages/oorexx_slam_v0.1/bin/bodyslam.rex kitrun' ctx~setting('BODYSLAM_DB') ctx~relDir ctx~repoRoot
  res~add(f)
