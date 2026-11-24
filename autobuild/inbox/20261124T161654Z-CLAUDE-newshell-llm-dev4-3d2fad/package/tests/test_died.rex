/* test_died.rex ROOT - newshell_llm v0.1-dev4: a compile killed mid-run.
   unzip runs, compile starts, killall -9 make; the plan sees the step DIED;
   the LLM is told and plans a review of the wreckage; the review reports
   back; the LLM plans a cleanup; the cleanup runs and reports; the LLM
   amends the original plan with a fix; the amended plan passes.
   Architecture: Tom Dyer. Coding: Claude (Opus 5.5). No network (fake curl). */
use strict arg root
wsDir = root'/build/died_ws'
'rm -rf' wsDir
.File~new(wsDir)~makeDirs
policy = root'/build/died.policy'
call SysFileDelete policy
do l over .Array~of('allow llm JobBoard submit *', 'allow llm Workspace run:unzip' wsDir, 'allow llm Workspace run:make' wsDir, -
                    'allow llm Workspace run:./*' wsDir, 'allow llm Workspace remove' wsDir, 'deny * * * *')
  call lineout policy, l
end
call stream policy, 'c', 'close'
call value 'NEWSHELL_POLICY', policy, 'ENVIRONMENT'
call value 'NEWSHELL_FAKE_KEY', 'FAKE-NEWSHELL-KEY', 'ENVIRONMENT'
call value 'NEWSHELL_FAKE_DUMP', '', 'ENVIRONMENT'
.ShellPolicy~reload

claude = .Llm~start('claude', 'claude-haiku-5-5', 'NEWSHELL_FAKE_KEY', root'/tests/fixtures/fake_claude_curl.sh')
ws = .Workspace~new(wsDir)
jobs = .JobBoard~new(claude)
claude~provide('ws', ws)
claude~provide('jobs', jobs)
'rexx' root'/tests/make_hello_zip.rex' wsDir 'slow'

code = "plan = jobs~plan('build hello')" || '0a'x || -
  "s = plan~step('unzip'); s~does(ws, 'run', .Array~of('unzip', '-o', 'hello.zip')); s~passIf('exitIs', 0)" || '0a'x || -
  "s = plan~step('compile'); s~does(ws, 'run', .Array~of('make', '-C', 'hello')); s~passIf('exitIs', 0)" || '0a'x || -
  "s = plan~step('test run'); s~does(ws, 'run', .Array~of('./hello/hello')); s~passIf('outputHas', 'Hello from newshell')" || '0a'x || -
  'return jobs~submit(plan)'

-- 1. unzip runs, compile starts, something kills make
plan = proposal(claude, code)~run
'(sleep 1.2; pkill -9 -x make || killall -9 make) >/dev/null 2>&1 &'
call waitFor plan
call check plan~state == 'DIED', 'plan state DIED (not FAILED)'
e = plan~atError
call check e~index = 2 & e~state == 'DIED', 'atError: step 2 compile DIED'
call check e~result~killedBy = 9, 'killed by signal 9'
r = plan~report
call check r~pos('DIED') > 0 & r~pos('SIGKILL') > 0, 'report says the step DIED of SIGKILL'
call check r~pos('step 3 test run: NOT RUN') > 0, 'test run did not run'
call check r~pos('end of stdout') > 0 & r~pos('sleep 3') > 0, 'report shows what make was doing when it died (sleep 3)'
call check r~pos('Full logs (for ws~tail): .newshell/runs/') > 0, 'log paths are relative, ready for ws~tail'
call check .File~new(wsDir'/hello/build.lock')~exists, 'the wreckage is real: hello/build.lock left behind'
say r

-- 2. the LLM was told and planned a review of the wreckage
f = plan~followUp
call check f \== .nil & f~state == 'CHECKED', 'follow-up proposal waiting, checked'
call check f~code~pos("'review wreckage'") > 0, 'follow-up is a review plan'
call check plan~diagnosis~pos('DIED') > 0, 'diagnosis:' plan~diagnosis~changeStr('0a'x, ' / ')
review = f~run
call waitFor review
call check review~state == 'PASSED', 'review plan PASSED'
call check review~report~pos('build.lock') > 0, 'review report shows what it found: build.lock'
call check review~origin == plan, 'review remembers the job it follows'

-- 3. told what the review found, the LLM plans a cleanup
f = review~followUp
call check f \== .nil & f~code~pos("'cleanup'") > 0, 'follow-up to the review is a cleanup plan'
cleanup = f~run
call waitFor cleanup
call check cleanup~state == 'PASSED', 'cleanup PASSED'
call check \.File~new(wsDir'/hello/build.lock')~exists & \.File~new(wsDir'/hello/hello.o')~exists, 'lock and partial object removed'
call check cleanup~report~pos('History') > 0 & cleanup~report~pos('"build hello" DIED') > 0, 'cleanup report carries the history'

-- 4. the LLM amends the original plan with a fix, which runs and passes
f = cleanup~followUp
call check f \== .nil & f~code~pos('amend') > 0, 'follow-up to the cleanup amends the original plan'
again = f~run
call check again~stepCount = 4 & again~stepAt(2)~name == 'clear stale lock', 'amended plan: 4 steps, new step 2 clears the lock'
call check plan~stepCount = 3 & plan~state == 'DIED', 'the original plan is untouched'
call waitFor again
call check again~state == 'PASSED', 'amended plan PASSED'
call check again~report~pos('"cleanup" PASSED') > 0, 'its history: build hello, review, cleanup'
say again~report
call check claude~prompts = 6, 'three follow-ups, two rounds each; the LLM never polled'
jobs~jobs~~table

-- 5. the amended plan survives a stale lock: plant one and run it again
call lineout wsDir'/hello/build.lock', ''; call stream wsDir'/hello/build.lock', 'c', 'close'
'rm -f' wsDir'/hello/hello' wsDir'/hello/hello.o'
third = jobs~find('build hello, attempt 2')~amend('build hello, attempt 3')
r3 = .Routine~new('sub', .Array~of('use arg jobs, p', 'return jobs~submit(p)'), .context~package)
r3~setSecurityManager(.ShellSecurityManager~new('llm'))
r3~call(jobs, third)
call waitFor third
call check third~state == 'PASSED', 'with a stale lock planted, the amended plan still passes'

-- 6. confinement: no path outside the workspace
call refusedInside "ws~remove('../escape.txt')", 'remove ../escape.txt refused'
call refusedInside "ws~run('make', '-C', '/etc')", 'make -C /etc refused'
call refusedInside "ws~tail('/etc/passwd')", 'tail /etc/passwd refused'

-- 7. exitIs 0 on a non-program step; an empty file is reported as empty
p = jobs~plan('probe')
p~step('remove nothing')~does(ws, 'remove', .Array~of('hello/no_such_file'))~passIf('exitIs', 0)
p~step('tail empty')~does(ws, 'tail', .Array~of('.newshell/runs/002-make.err'))
r4 = .Routine~new('sub', .Array~of('use arg jobs, p', 'return jobs~submit(p)'), .context~package)
r4~setSecurityManager(.ShellSecurityManager~new('llm'))
r4~call(jobs, p)
call waitFor p
call check p~state == 'PASSED', 'exitIs 0 passes for a completed remove'
q = jobs~plan('probe list')
q~step('list has Makefile')~does(ws, 'list', .Array~of('hello'))~passIf('outputHas', 'Makefile')~passIf('outputLacks', 'build.lock')
r4~call(jobs, q)
call waitFor q
call check q~state == 'PASSED', 'outputHas/outputLacks read a ws~list table'
c2 = jobs~plan('probe continue')
c2~step('missing')~does(ws, 'list', .Array~of('hello'))~passIf('fileExists', 'hello/build.lock')~onFail('continue')
c2~step('absent')~does(ws, 'list', .Array~of('hello'))~passIf('fileAbsent', 'hello/build.lock')
r4~call(jobs, c2)
call waitFor c2
call check c2~state == 'FAILED' & c2~outcomes~items~items = 2 & c2~outcomes~items[2]~state == 'PASS', 'continue runs on, but the plan ends FAILED; fileAbsent passes'
call check p~report = '' | p~outcomes~items[2]~findings~pos('empty') > 0, 'an empty file is reported as empty'

-- 8. amend, insertStep, removeStep, stepNamed
p = jobs~plan('x'); p~step('a'); p~step('b')
q = p~amend('y'); q~insertStep(1, 'first'); q~insertStep(4, 'last'); q~removeStep(3)
names = ''; do s over q~steps~items; names = names s~index':'s~name; end
call check names~strip == '1:first 2:a 3:last', 'insertStep/removeStep renumber:' names
call check p~stepCount = 2, 'amend leaves the original alone'
call check q~stepNamed('a')~index = 2 & q~stepNamed('nope') == .nil, 'stepNamed finds by name after inserts'

say 'NEWSHELL_LLM DIED: OK'
exit 0

refusedInside: procedure expose ws
  use strict arg line, label
  r = .Routine~new('raw', .Array~of('use arg ws', line, 'return 0'), .context~package)
  r~setSecurityManager(.ShellSecurityManager~new('llm'))
  signal on syntax name wasRefused
  r~call(ws)
  say 'FAILED: not refused:' label; exit 85
wasRefused:
  c = condition('O')
  if c~message~pos('outside the workspace') = 0 then do; say 'FAILED:' label c~message; exit 85; end
  say 'ok  ' label
  return

waitFor: procedure
  use strict arg job
  do 160 while \job~settled
    call SysSleep 0.25
  end
  return

proposal: procedure
  use strict arg llm, code
  p = .Proposal~new(llm, 'test', code)
  p~setFinal(code)
  if p~state \== 'CHECKED' then do; p~show; say 'FAILED: proposal did not check'; exit 85; end
  return p

check: procedure
  use arg ok, label
  if \ok then do; say 'FAILED:' label; exit 85; end
  say 'ok  ' label
  return

::requires 'ShellJobs.cls'
::requires 'ShellLlm.cls'
