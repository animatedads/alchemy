#!/usr/bin/env rexx
/* wf_fleet_job.rex - Alchemy Workflow v0.1-dev1: the full shadow survey on a build host.
 *
 * Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-11-11.
 *
 * From the repository root, with bin/workflow_env.sh sourced:
 *   rexx packages/alchemy_workflow_v0.1-dev1/tools/wf_fleet_job.rex
 *
 * 1. Kit: rexx, g++, make, the ooRexx headers, librexxsql.so and libforeign_runtime.so (each built
 *    here if missing, into the work directory or the Foreign Runtime's own build directory).
 * 2. Body Slam reads the checkout into a fresh database (about 4 minutes).
 * 3. Every package with an integration.json is judged by every step, KitRun included, in shadow mode.
 * 4. Everything goes to WORK/FLEET_RESULT.txt; the progress log to WORK/out/workflow.log.
 * It edits nothing in the checkout except building libforeign_runtime.so when it is missing.
 * Exit 0 when the survey ran (whatever it found); 2 when the kit check failed.
 */
signal on syntax name failed
parse source . . me
home = me~left(me~lastPos('/tools/') - 1)
repo = .File~new(home || '/../..')~absolutePath
p = repo || '/packages'
work = value('WF_FLEET_WORK',, 'ENVIRONMENT')
if work == '' then work = '/tmp/alchemy_workflow_fleet'
address system 'rm -rf' wfq(work) '&& mkdir -p' wfq(work || '/out')
log = .WorkflowLog~new(work || '/out/workflow.log', .true)
res = .array~new
res~append('Alchemy Workflow v0.1-dev1 fleet job: shadow survey of every package with an integration.json')
res~append('host:' hostName() 'started' .DateTime~new~isoDate)

/* 1. kit */
ok = .true
kit = .array~new
kit~append(.array~of('rexx', 'rexx -v 2>&1 | head -1'))
kit~append(.array~of('g++', 'g++ --version 2>&1 | head -1'))
kit~append(.array~of('make', 'make --version 2>&1 | head -1'))
kit~append(.array~of('git', 'git -C' wfq(repo) 'log -1 --format=%h 2>&1'))
do k over kit
  out = run(k[2])
  if out == '' then do
    res~append('kit FAIL' k[1] '(nothing from:' k[2] || ')')
    ok = .false
  end
  else res~append('kit ok  ' k[1] out)
  log~info('kit' k[1] out)
end
rexxHome = .File~new(run('command -v rexx'))~parent
rexxHome = .File~new(rexxHome)~parent
if \SysFileExists(rexxHome || '/include/oorexxapi.h') then do
  res~append('kit FAIL ooRexx headers: no' rexxHome || '/include/oorexxapi.h')
  ok = .false
end
else res~append('kit ok   ooRexx headers' rexxHome || '/include')

fr = p || '/oorexx_foreign_runtime_v0.22.6'
if \SysFileExists(fr || '/build/libforeign_runtime.so') then do
  log~info('building libforeign_runtime.so')
  call run 'make -s -C' wfq(fr) 'OOREXX=' || wfq(rexxHome) 'build/libforeign_runtime.so 2>&1'
end
if SysFileExists(fr || '/build/libforeign_runtime.so') then res~append('kit ok   libforeign_runtime.so' fr || '/build')
else do
  res~append('kit FAIL libforeign_runtime.so: the build did not make it')
  ok = .false
end

sqlDir = value('REXXSQL_LIBDIR',, 'ENVIRONMENT')
if sqlDir == '' then sqlDir = work || '/lib'
if \SysFileExists(sqlDir || '/librexxsql.so') then do
  log~info('building librexxsql.so (a minute or two)')
  call run 'REXX_INCDIR=' || wfq(rexxHome || '/include') 'sh' wfq(p || '/oorexx_rexxsql_backend_v0.1/tools/build_rexxsql.sh') wfq(sqlDir) '2>&1 | tail -1'
end
if SysFileExists(sqlDir || '/librexxsql.so') then res~append('kit ok   librexxsql.so' sqlDir)
else do
  res~append('kit FAIL librexxsql.so: the build did not make it (see' sqlDir || '/build.log)')
  ok = .false
end
ld = value('LD_LIBRARY_PATH',, 'ENVIRONMENT')
call value 'LD_LIBRARY_PATH', sqlDir || ':' || ld, 'ENVIRONMENT'
if \ok then do
  res~append('KIT CHECK FAILED: nothing else was run')
  call finish res, work, log
  exit 2
end

/* 2. Body Slam's database of this checkout */
db = work || '/estate.db'
log~info('Body Slam ingest of' repo)
t0 = .DateTime~new
out = run('rexx' wfq(p || '/oorexx_slam_v0.1/bin/bodyslam.rex') 'ingest' wfq(db) wfq(repo) '2>&1 | tail -2')
secs = (.DateTime~new - t0)~totalSeconds~format(, 0)
if \SysFileExists(db) then do
  res~append('ingest FAIL after' secs 's:' out)
  call finish res, work, log
  exit 2
end
res~append('ingest ok' secs 's |' out~changeStr('0a'x, ' | '))

/* 3. the survey */
list = work || '/packages.list'
call run 'ls -d' wfq(p) || '/*/integration.json | sed ''s#/integration.json##'' >' wfq(list)
n = run('wc -l <' wfq(list))
log~info('survey of' n~strip 'packages')
t0 = .DateTime~new
address system 'rexx' wfq(home || '/bin/workflow.rex') 'survey' wfq(list) '--repo' wfq(repo) '--db' wfq(db) '--work' wfq(work) '--quiet >' wfq(work || '/survey.txt') '2>&1'
secs = (.DateTime~new - t0)~totalSeconds~format(, 0)
res~append('survey' n~strip 'packages in' secs 's (exit' rc || '); one line each, then totals:')
s = .stream~new(work || '/survey.txt')
s~open('read')
do while s~lines > 0
  res~append(s~lineIn)
end
s~close
call finish res, work, log
exit 0

/* the output of a shell command, lines joined with newlines; '' when it printed nothing */
run: procedure
  use strict arg cmd
  address system cmd with output stem o.
  t = ''
  do i = 1 to o.0
    if t \== '' then t = t || '0a'x
    t = t || o.i
  end
  return t~strip

hostName: procedure
  return run('hostname')

finish: procedure
  use strict arg res, work, log
  res~append('finished' .DateTime~new~isoDate)
  s = .stream~new(work || '/FLEET_RESULT.txt')
  s~open('write replace')
  do line over res
    s~lineOut(line)
  end
  s~close
  log~info('result in' work || '/FLEET_RESULT.txt')
  log~close
  return

failed:
  c = condition('O')
  say 'wf_fleet_job: Error' c['CODE'] c['ERRORTEXT']
  say '   ' c['MESSAGE']
  say '    line' c['POSITION'] 'of' c['PROGRAM']
  exit 3

::requires 'AlchemyWorkflow.cls'
::requires 'WorkflowLog.cls'
