/* test_agent.rex ROOT - newshell_llm v0.1-dev5: Codex as a principal.
   Every step is a separate nsh-agent process, as Codex runs it over sshnode:
   the killed compile, review, cleanup and amended plan work across processes
   because jobs are kept in a job store.
   Architecture: Tom Dyer. Coding: Claude (Opus 5.5). No network. */
use strict arg root
b = root'/build/agent'
'rm -rf' b
ws = b'/ws'; state = b'/state'
.File~new(ws)~makeDirs
'rexx' root'/tests/make_hello_zip.rex' ws 'slow'
pol = b'/agent.policy'
do l over .Array~of('deny * Xtpd * *', 'allow codex JobBoard submit *', 'allow codex Workspace run:unzip' ws, 'allow codex Workspace run:make' ws, -
                    'allow codex Workspace run:./*' ws, 'allow codex Workspace remove' ws, 'deny * * * *')
  call lineout pol, l
end
call stream pol, 'c', 'close'
muTools = value('MU_TOOLS_DIR',, 'ENVIRONMENT')
haveAudit = muTools \== '' & .File~new(muTools'/src/NewShellMuAudit.cls')~isFile
cfg = b'/agent.conf'
do l over .Array~of('principal codex', 'state' state, 'policy' pol, 'provide ws Workspace' ws, 'provide net Network', 'provide svc Services', 'provide xtpd Xtpd')
  call lineout cfg, l
end
if haveAudit then call lineout cfg, 'provide mu Mu' muTools'/etc/mu_contract_cats.txt'
call stream cfg, 'c', 'close'
call value 'NEWSHELL_NFT', root'/tests/fixtures/fake_nft.sh', 'ENVIRONMENT'
call value 'NEWSHELL_SYSTEMCTL', root'/tests/fixtures/fake_systemctl.sh', 'ENVIRONMENT'
agentRex = root'/bin/nsh-agent.rex'

-- 1. describe: the agent gets the same brief as an LLM
r = agent('describe')
call check r[1] = 0 & r[2]~pos('net: a NETWORK object') > 0 & r[2]~pos('jobs: a JOBBOARD object') > 0, 'describe lists net and jobs'
call check r[2]~pos('nsh-agent check FILE') > 0, 'the brief tells the agent how to submit'

-- 2. check: problems, and the source of every method the proposal calls
call write 'listen.rex', 'return net~listening~sortedBy(''port'')~first(3)'
r = agent('check' b'/listen.rex')
call check r[1] = 0 & r[2]~pos('CHECKED') > 0, 'check: CHECKED'
call check r[2]~pos('NETWORK~listening') > 0 & r[2]~pos('defined in NETWORK') > 0, 'check prints the source of net~listening'

-- 3. run a read-only proposal
r = agent('run' b'/listen.rex')
call check r[1] = 0 & r[2]~pos('proto') > 0 & r[2]~pos('port') > 0, 'run: listening sockets table'

-- 4. the job: unzip, compile, test run; make is killed mid-compile
call write 'build.rex', "plan = jobs~plan('build hello')" || '0a'x || -
  "s = plan~step('unzip'); s~does(ws, 'run', .Array~of('unzip', '-o', 'hello.zip')); s~passIf('exitIs', 0)" || '0a'x || -
  "s = plan~step('compile'); s~does(ws, 'run', .Array~of('make', '-C', 'hello')); s~passIf('exitIs', 0)" || '0a'x || -
  "s = plan~step('test run'); s~does(ws, 'run', .Array~of('./hello/hello')); s~passIf('outputHas', 'Hello from newshell')" || '0a'x || -
  'return jobs~submit(plan)'
-- kill make once it is mid-compile (its lock exists), not on a timer: start-up time varies by host
'(for i in $(seq 1 300); do [ -f' ws'/hello/build.lock ] && break; sleep 0.1; done; sleep 0.3; pkill -9 -x make || killall -9 make) >/dev/null 2>&1 &'
r = agent('run' b'/build.rex')
call check r[1] = 1, 'run exits 1: a job died'
call check r[2]~pos('===== build hello: DIED') > 0 & r[2]~pos('SIGKILL') > 0, 'the report says the compile DIED of SIGKILL'
call check .File~new(ws'/hello/build.lock')~exists, 'the wreckage: hello/build.lock'

-- 5. a new process: the job is still there
r = agent('jobs')
call check r[1] = 0 & r[2]~pos('build hello') > 0 & r[2]~pos('DIED') > 0, 'jobs: build hello DIED, restored from the store'
r = agent('report build hello')
call check r[2]~pos('Stage reached: step 2/3 compile') > 0, 'report: the kept report'

-- 6. review the wreckage
call write 'review.rex', "plan = jobs~plan('review wreckage')" || '0a'x || "plan~notify('always')" || '0a'x || -
  "s = plan~step('list build tree'); s~does(ws, 'list', .Array~of('hello'))" || '0a'x || 'return jobs~submit(plan)'
r = agent('run' b'/review.rex --follows build hello')
call check r[1] = 0 & r[2]~pos('build.lock') > 0, 'review found build.lock'
call check r[2]~pos('"build hello" DIED') > 0, 'review report carries the history'

-- 7. clean up
call write 'cleanup.rex', "plan = jobs~plan('cleanup')" || '0a'x || -
  "s = plan~step('remove lock'); s~does(ws, 'remove', .Array~of('hello/build.lock')); s~passIf('fileAbsent', 'hello/build.lock')" || '0a'x || -
  "s = plan~step('remove partial object'); s~does(ws, 'remove', .Array~of('hello/hello.o'))" || '0a'x || 'return jobs~submit(plan)'
r = agent('run' b'/cleanup.rex --follows review wreckage')
call check r[1] = 0 & r[2]~pos('===== cleanup: PASSED') > 0, 'cleanup PASSED'

-- 8. amend the original plan, found in the store, and run it
call write 'amend.rex', "old = jobs~find('build hello')" || '0a'x || "p = old~amend('build hello, attempt 2')" || '0a'x || -
  "s = p~insertStep(2, 'clear stale lock'); s~does(ws, 'remove', .Array~of('hello/build.lock')); s~passIf('fileAbsent', 'hello/build.lock')" || '0a'x || -
  'return jobs~submit(p)'
r = agent('run' b'/amend.rex --follows cleanup')
call check r[1] = 0 & r[2]~pos('===== build hello, attempt 2: PASSED') > 0, 'the amended plan, rebuilt from the store, PASSED'
call check r[2]~pos('"cleanup" PASSED') > 0 & r[2]~pos('"review wreckage" PASSED') > 0, 'its history: build hello, review, cleanup'
call check r[2]~pos('step 2 clear stale lock: PASS') > 0, 'step 2 is the new one'

-- 9. starting xtpd is refused: the policy decides
call write 'xtpd.rex', "xtpd~bringUp('/etc/xtpd/xtpd.conf')" || '0a'x || 'return 1'
r = agent('run' b'/xtpd.rex')
call check r[1] = 2 & r[2]~pos('REFUSED') > 0 & r[2]~pos('XTPD~bringup') > 0, 'xtpd~bringUp refused for codex'

-- 10. a rejected proposal never runs
call write 'bad.rex', 'address system "touch' b'/HACKED"' || '0a'x || 'return 1'
r = agent('run' b'/bad.rex')
call check r[1] = 2 & r[2]~pos('PROBLEM') > 0 & \.File~new(b'/HACKED')~exists, 'rejected: ADDRESS'

-- 11. services and the firewall (fixtures)
call write 'svc.rex', 'return svc~failed'
r = agent('run' b'/svc.rex')
call check r[1] = 0 & r[2]~pos('xtpd.service') > 0 & r[2]~pos('failed') > 0, 'svc~failed: xtpd.service'
call write 'fw.rex', 'return net~firewall~rules'
r = agent('run' b'/fw.rex')
call check r[1] = 0 & r[2]~pos('tcp dport 22 accept') > 0 & r[2]~pos('mu_fence') > 0, 'net~firewall~rules: the fence'
call write 'fwset.rex', 'return net~firewall~sets'
r = agent('run' b'/fwset.rex')
call check r[2]~pos('xtp_peers') > 0 & r[2]~pos('80.240.21.156') > 0, 'net~firewall~sets: xtp_peers and its elements'
call write 'chains.rex', 'return net~firewall~chains'
r = agent('run' b'/chains.rex')
call check r[2]~pos('input') > 0 & r[2]~pos('drop') > 0, 'chain input, policy drop'

-- 12. the MU audit (when the estate's mu-tools are here)
if haveAudit then do
  call write 'audit.rex', 'return mu~audit'
  r = agent('run' b'/audit.rex')
  call check r[1] = 0 & r[2]~pos('thin') > 0 & r[2]~pos('findingCount') > 0, 'mu~audit runs the estate audit'
end
else say 'SKIP mu~audit: MU_TOOLS_DIR has no NewShellMuAudit.cls'

say 'NEWSHELL_LLM AGENT: OK'
exit 0

agent: procedure expose agentRex cfg
  use strict arg line
  outLines = .Array~new; errLines = .Array~new
  address system 'rexx' agentRex '--config' cfg line with output using (outLines) error using (errLines)
  return .Array~of(rc, outLines~makeString('L', '0a'x))

write: procedure expose b
  use strict arg name, text
  path = b'/'name
  call SysFileDelete path
  call charout path, text
  call stream path, 'c', 'close'
  return

check: procedure
  use arg ok, label
  if \ok then do; say 'FAILED:' label; exit 85; end
  say 'ok  ' label
  return
