/* test_jobs.rex ROOT - newshell_llm v0.1-dev3: plans and watches the LLM
   registers, which run on their own and tell it how they ended.
   Architecture: Tom Dyer. Coding: Claude (Opus 5.5). No network (fake curl). */
use strict arg root
wsDir = root'/build/jobs_ws'
'rm -rf' wsDir
.File~new(wsDir'/logs')~makeDirs
policy = root'/build/jobs.policy'
call SysFileDelete policy
call SysFileDelete root'/build/notify_body.json'
do l over .Array~of('allow llm JobBoard submit *', 'allow llm Workspace run:unzip' wsDir, 'allow llm Workspace run:make' wsDir, 'allow llm Workspace run:./*' wsDir, 'deny * * * *')
  call lineout policy, l
end
call stream policy, 'c', 'close'
call value 'NEWSHELL_POLICY', policy, 'ENVIRONMENT'
call value 'NEWSHELL_FAKE_KEY', 'FAKE-NEWSHELL-KEY', 'ENVIRONMENT'
dump = root'/build/notify_body.json'
call value 'NEWSHELL_FAKE_DUMP', dump, 'ENVIRONMENT'
.ShellPolicy~reload

claude = .Llm~start('claude', 'claude-haiku-5-5', 'NEWSHELL_FAKE_KEY', root'/tests/fixtures/fake_claude_curl.sh')
ws = .Workspace~new(wsDir)
jobs = .JobBoard~new(claude)
claude~provide('ws', ws)
claude~provide('jobs', jobs)
sp = claude~systemPrompt
call check sp~pos('PLANSTEP') > 0 & sp~pos('passIf') > 0 & sp~pos('RUNRESULT') > 0, 'system prompt describes Plan, PlanStep and RunResult'
inbox = .ShellInbox~current

plan3 = "plan = jobs~plan('build hello')" || '0a'x || -
  "s = plan~step('unzip'); s~does(ws, 'run', .Array~of('unzip', '-o', 'hello.zip')); s~passIf('exitIs', 0)" || '0a'x || -
  "s = plan~step('compile'); s~does(ws, 'run', .Array~of('make', '-C', 'hello')); s~passIf('exitIs', 0)" || '0a'x || -
  "s = plan~step('check'); s~does(ws, 'run', .Array~of('./hello/hello')); s~passIf('outputHas', 'Hello from newshell')" || '0a'x || -
  'return jobs~submit(plan)'

-- 1. the bad program: the plan stops at step 2 and the LLM is told
'rexx' root'/tests/make_hello_zip.rex' wsDir 'bad'
p = proposal(claude, plan3)
call check p~state == 'CHECKED', 'plan proposal checks'
prompts = claude~prompts
plan = p~run
call check plan~isA(.Plan), '~run returns the Plan at once'
call waitFor plan
call check plan~state == 'FAILED', 'plan FAILED'
call check plan~atError~index = 2 & plan~atError~name == 'compile', 'atError: step 2, compile'
call check plan~atError~errorLine~caselessPos('error') > 0, 'error point is the compiler error line:' plan~atError~errorLine
r = plan~report
call check r~pos('Stage reached: step 2/3 compile') > 0, 'report names the stage reached'
call check r~pos('step 3 check: NOT RUN') > 0, 'report says step 3 did not run'
call check r~pos('NOISE LINE 150') = 0, 'report does not carry the build noise'
out = plan~atError~result
call check out~stdoutLines >= 200, 'the build really printed' out~stdoutLines 'lines (kept in' out~stdoutFile')'
call check claude~prompts = prompts + 2, 'the LLM was told once, without polling (one follow-up: draft and review)'
call check plan~diagnosis~pos('missing a semicolon') > 0, 'diagnosis (the follow-up''s leading comment) kept on the plan'
call check plan~followUp~isA(.Proposal) & plan~followUp~state == 'CHECKED', 'a follow-up proposal is waiting, checked, not run'
body = readAll(dump)
call check body~pos('NOISE LINE 150') = 0 & body~pos('First error line') > 0, 'the message to the LLM has the error point, not the output'
call check inbox~unread = 1, 'one inbox message'
say r
plan~outcomes~~table
plan~decisions~~table
inbox~take~~table

-- 2. the good program: PASSED, all three steps, no LLM call
'rexx' root'/tests/make_hello_zip.rex' wsDir 'good'
'rm -rf' wsDir'/hello'
prompts = claude~prompts
plan = proposal(claude, plan3~changeStr("'build hello'", "'build hello again'"))~run
call waitFor plan
call check plan~state == 'PASSED', 'good program: plan PASSED'
call check plan~outcomes~items~items = 3, 'three outcomes'
call check claude~prompts = prompts, 'a pass is posted to the inbox, not sent to the LLM'
call check inbox~take~items~items = 1, 'inbox has the pass'

-- 3. a program the policy does not allow: the step's action is refused
p = proposal(claude, "plan = jobs~plan('tidy')" || '0a'x || "s = plan~step('remove'); s~does(ws, 'run', .Array~of('rm', '-rf', 'hello')); s~passIf('exitIs', 0)" || '0a'x || 'return jobs~submit(plan)')
plan = p~run
call waitFor plan
call check plan~state == 'FAILED' & plan~atError~reason~pos('98.948') > 0, 'run:rm refused by the policy:' plan~atError~reason
call check .File~new(wsDir'/hello/hello.c')~exists, 'nothing removed'
denied = .false
do d over plan~decisions~items; if d~verdict == 'deny', d~target~caselessPos('run:rm') > 0 then denied = .true; end
call check denied, 'deny receipt names WORKSPACE~run:rm'
inbox~take

-- 4. watches
w = jobs~watch('fileAppears', wsDir'/logs', '*.log')~every(1)
p = proposal(claude, "w = jobs~watch('fileAppears', ws~path'/logs', '*.log')" || '0a'x || 'w~every(1)' || '0a'x || 'return jobs~submit(w)')
w = p~run
call SysSleep 1.5
call check w~state == 'ARMED', 'fileAppears watch armed'
call check .ShellCollection~new(.Array~of(w))~asTable~pos('ARMED') > 0, 'an armed watch can be tabled (poll holds no lock)'
call lineout wsDir'/logs/app.log', 'started'; call stream wsDir'/logs/app.log', 'c', 'close'
call waitFor w
call check w~state == 'FIRED' & w~event~pos('app.log') > 0, 'watch fired on logs/app.log:' w~event
call check w~diagnosis \== '', 'the LLM was told about the event'
inbox~take

w = proposal(claude, "w = jobs~watch('diskFreeBelow', ws~path, 1e18)" || '0a'x || 'return jobs~submit(w)')~run
call waitFor w
call check w~state == 'FIRED' & w~event~pos('below') > 0, 'diskFreeBelow 1e18 fires:' w~event
w = proposal(claude, "w = jobs~watch('diskFreeBelow', ws~path, 1)" || '0a'x || 'w~every(1)' || '0a'x || 'return jobs~submit(w)')~run
call SysSleep 2.5
call check w~state == 'ARMED', 'diskFreeBelow 1 byte stays armed'
w~stop
call waitFor w
call check w~state == 'STOPPED', 'watch stopped'
inbox~take

call check jobs~jobs~asTable~pos('PASSED') > 0 & jobs~jobs~asTable~pos('FIRED') > 0, 'jobs table mixes plans and watches'

-- 5. no way round submit
c = .ProposalCheck~new
call check c~problems("p = jobs~plan('x')" || '0a'x || 'p~launch' || '0a'x || 'return p')~items > 0, 'lint rejects ~launch'
call check c~problems("p = jobs~plan('x')" || '0a'x || 'p~execute' || '0a'x || 'return p')~items > 0, 'lint rejects ~execute'
r = .Routine~new('raw', .Array~of('use arg jobs', "p = jobs~plan('x'); p~step('a')", 'p~launch', 'return p'), .context~package)
r~setSecurityManager(.ShellSecurityManager~new('llm'))
signal on syntax name launchRefused
r~call(jobs)
call check .false, 'launch from llm code should be refused'
launchRefused:
  signal off syntax
  call check condition('O')~code == '98.948', 'security manager refuses Plan~launch from llm code'

say 'NEWSHELL_LLM JOBS: OK'
exit 0

waitFor: procedure
  use strict arg job
  do 120 while \job~settled
    call SysSleep 0.25
  end
  return

proposal: procedure
  use strict arg llm, code
  p = .Proposal~new(llm, 'test', code)
  p~setFinal(code)
  if p~state \== 'CHECKED' then do; p~show; say 'FAILED: proposal did not check'; exit 85; end
  return p

readAll: procedure
  use strict arg path
  s = .Stream~new(path)
  if s~open('READ') \= 'READY:' then return ''
  text = s~charIn(1, s~chars); s~close
  return text

check: procedure
  use arg ok, label
  if \ok then do; say 'FAILED:' label; exit 85; end
  say 'ok  ' label
  return

::requires 'ShellJobs.cls'
::requires 'ShellLlm.cls'
