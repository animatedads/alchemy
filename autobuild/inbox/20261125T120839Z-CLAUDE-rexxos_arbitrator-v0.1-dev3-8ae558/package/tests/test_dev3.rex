/* rexxos_arbitrator v0.1-dev3 tests: pre-approved recovery, and a plan that
   survives a pulled plug.
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
   Run from this directory with oorexx_logging v0.7 on REXX_PATH. */
parse arg scratch
if scratch = '' then scratch = '/tmp/rexxos_arbitrator_dev3_tests'
pass = 0; fail = 0
call SysFileTree scratch'/*', 'old.', 'FSO'
do i = 1 to old.0; call SysFileDelete old.i; end
call SysMkDir scratch

/* ---- 1. Recovery is pre-approved while it only restores ---- */
c = newCluster()
c~addMu('uk2', 'UK', .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000)), '192.0.2.7')
c~addPair(.RolePair~new('LDAP', .Demand~new('ldap', 95, 512)), 'uk1', 'au1')
gw = .Demand~new('rasen-site', 50, 64, 0, 300, 'LOCAL', .true, 'READONLY')
c~place(.ServicePlacement~new(gw, 'rasen.site', 'GATEWAY', 'www.rasenfalcon.com', 300, 'UK', 3600), 'uk1', 0)
tmp = .Demand~new('scratchpad', 40, 256, 0, 0, 'NONE', .false, 'TEMPORARY')
c~place(.ServicePlacement~new(tmp, 'scratch.svc', 'NONE', '', 0, 'UK', 0), 'uk1', 0)
do m over .Array~of('uk1', 'au1'); call completeMu c, m, 0; end
p = c~muDown('uk1', 100)
call check 'recovery: the plan is a RECOVERY plan', p~purpose == 'RECOVERY' & p~approvalClass == 'RECOVERY', p~approvalClass p~recoveryProblem
call check 'recovery: it needs no approval', \p~needsApproval, ''
text = p~describe~makeString('L', '0a'x)
call check 'recovery: every change is marked pre-approved, none needs Tom', text~pos('RECOVERY: pre-approved') > 0 & text~pos('NEEDS TOM') = 0, ''
call check 'recovery: LDAP fails over first', p~steps[1]~kind == 'FENCE_ROLE' & p~steps[2]~address == 'LDAP.main', p~kinds
call check 'recovery: the site is restored on the same site (uk2), from its saved state', stepFor(p, 'ACTIVATE_TASK', 'rasen-site')~mu == 'uk2', ''
call check 'recovery: restore only - no RAM store is made for the site', \hasStep(p, 'ADD_CACHE'), p~kinds
call check 'recovery: the TEMPORARY service is started afresh, and the loss is said', stepFor(p, 'START_TASK', 'scratchpad') \== .nil & decisionWith(c, 'starts afresh') \== '', ''
call check 'recovery: the site keeps its service address', stepFor(p, 'ROUTE_SERVICE', 'rasen-site')~address == 'rasen.site', ''
call check 'recovery: plan is sound', p~ok, p~violations~makeString('L', '; ')
call completeCluster c, p, 100
call check 'recovery: site on uk2, LDAP.main on au1, nothing held by the dead MU', c~whereIs('rasen-site') == 'uk2' & c~roleAt('LDAP.main') == 'au1' & c~held('uk1')~items = 0, c~whereIs('rasen-site') c~held('uk1')~items

/* A DNS edge changes public exposure, so that recovery needs approval. */
c = newCluster()
c~addMu('uk2', 'UK', .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000)), '192.0.2.7')
dn = .Demand~new('rasen-site', 50, 64, 0, 300, 'LOCAL', .true, 'READONLY')
c~place(.ServicePlacement~new(dn, 'rasen.site', 'DNS', 'www.rasenfalcon.com', 300, 'UK', 3600), 'uk1', 0)
call completeMu c, 'uk1', 0
p = c~muDown('uk1', 100)
call check 'DNS edge: recovery that repoints DNS needs approval', p~approvalClass == 'TOM' & p~recoveryProblem~pos('REPOINT_DNS') > 0 & p~needsApproval, p~recoveryProblem
call check 'DNS edge: the description says why', p~describe[1]~pos('needs approval') > 0, p~describe[1]

/* An ordinary plan is never pre-approved. */
a = .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000))
p = a~plan(.Array~of(.Demand~new('x', 10, 100)), 0)
call check 'provision: an ordinary plan still needs Tom', p~approvalClass == 'TOM' & p~needsApproval, p~approvalClass
p~setPurpose('RECOVERY')
p2 = a~plan(.Array~of(.Demand~new('y', 10, 6000, 4000)), 0)
p2~setPurpose('RECOVERY')
call check 'provision: a "recovery" plan that adds swap is not pre-approved', p2~approvalClass == 'TOM' & p2~recoveryProblem~pos('ADD_SWAP') > 0, p2~recoveryProblem

/* ---- 2. Text forms ---- */
call raises 'text: an id with | is refused by the id rule', ".Demand~new('t|x', 1)"
d = .Demand~new('t1', 7, 900, 100, 50, 'FABRIC', .true, 'TEMPORARY', 'WRITETHROUGH', 'CHECKPOINT')
d2 = .Demand~fromText(d~toText)
call check 'text: a demand round-trips', d2~toText == d~toText, d2~toText
st = .ProvisionStep~new('ADD_CACHE', d, 'why | with % and a bar', 50, 'WRITETHROUGH', 'PLANNED', 'note|x')
dd = .Directory~new; dd['t1'] = d
st2 = .ProvisionStep~fromText(st~toText, dd)
call check 'text: a step round-trips, | and % escaped', st2~toText == st~toText & st2~cause == 'why | with % and a bar', st2~toText
m = .MachineState~new(8192, 1024, 40000, 100000)
m~apply(.ProvisionStep~new('START_TASK', d, 'x'), 5)
m~apply(.ProvisionStep~new('ADD_CACHE', d, 'x', 50, 'WRITETHROUGH'), 5)
m~park(.Demand~new('p1', 3, 100, 0, 0, 'NONE', .false, 'DURABLE'))
m2 = .MachineState~fromLines(m~toLines)
call check 'text: the ledger round-trips', m2~toLines~makeString('L', '/') == m~toLines~makeString('L', '/'), m2~toLines~makeString('L', '/')

/* ---- 3. A plan that survives a pulled plug ---- */
/* The reference: T1/T2 on machine B, run without interruption. */
call check 'runner: an uninterrupted run reaches the planned state', runCase(scratch'/clean', 0, '') == 'ok', ''
lines = journalLines(scratch'/clean')
call check 'runner: the journal holds the plan, a BEGIN and DONE per step, and END', countType(lines, 'PLAN') = 1 & countType(lines, 'BEGIN') = 3 & countType(lines, 'DONE') = 3 & countType(lines, 'END') = 1, countType(lines, 'BEGIN') countType(lines, 'DONE')
call check 'runner: the progress went through oorexx_logging', .local~arb.memory~count >= 7, .local~arb.memory~count

do phase over .Array~of('BEFORE_PERFORM', 'AFTER_PERFORM', 'AFTER_SNAPSHOT')
  r = runCase(scratch'/'phase, 2, phase)
  call check 'breaker at step 2' phase': resume finishes, every step done exactly once, ledger matches the machine', r == 'ok', r
end
r = runCase(scratch'/torn', 2, 'AFTER_PERFORM', .true)
call check 'breaker with a torn last journal line and a torn snapshot: still exactly once', r == 'ok', r
call check 'runner: nothing to resume after a finished plan', resumeFinished(scratch'/clean') == .false, ''

say
say 'TOTAL' pass 'passed,' fail 'failed'
if fail > 0 then exit 1
exit 0

check: procedure expose pass fail
  use arg name, ok, detail
  if ok == 1 then do; pass += 1; say 'PASS' name; end
  else do; fail += 1; say 'FAIL' name '['detail']'; end
  return

raises: procedure expose pass fail
  use arg name, code
  signal on syntax name raised
  interpret code
  fail += 1; say 'FAIL' name '[no error raised]'
  return
raised:
  pass += 1; say 'PASS' name
  return

/* Run T1/T2 on machine B through a PlanRunner in dir.  If breakAt > 0 the
   breaker is pulled there; a fresh arbitrator and runner then resume.
   Returns 'ok' or what went wrong. */
::routine runCase
  use arg dir, breakAt, phase, tear = .false
  call SysMkDir dir
  machine = .MachineState~new(8192, 1024, 40000, 100000)    /* the real machine */
  eff = .SimulatedEffector~new(machine)
  arb = .MachineArbitrator~new(.MachineState~new(8192, 1024, 40000, 100000))
  t1 = .Demand~new('T1', 60, 512, 0, 20000, 'FABRIC', .true, 'TEMPORARY')
  t2 = .Demand~new('T2', 70, 9000, 4000, 0, 'NONE', .false, 'TEMPORARY')
  plan = arb~plan(.Array~of(t1, t2), 0)
  if plan~kinds \== 'ADD_SWAP START_TASK START_TASK' then return 'unexpected plan' plan~kinds
  service = .LogService~new('arb-test')
  mem = .LogMemoryTarget~new('memory', .Log~INTERNAL)
  service~addTarget(mem)
  service~addTarget(.LogLineTarget~new('progress', .Log~INTERNAL))
  .local~arb.memory = mem
  runner = .PlanRunner~new(dir, arb, eff, service, .array~of('memory', 'progress'))
  if breakAt > 0 then eff~armBreaker(breakAt, phase)
  crashed = pulled(runner, plan)
  if breakAt = 0 & crashed then return 'crashed without a breaker'
  if breakAt > 0 then do
    if \crashed then return 'breaker did not fire'
    if tear then do
      /* The power cut also tore the last journal line and the newest snapshot. */
      call charout dir'/journal.log', '7|BEGIN|plan-1|3|START_TA'
      call stream dir'/journal.log', 'c', 'close'
      call SysFileTree dir'/ledger.*', 'f.', 'FO'
      if f.0 > 0 then do
        newest = f.1; do k = 2 to f.0; if f.k >> newest then newest = f.k; end
        call lineout newest~changeStr('ledger.', 'ledger.9'), 'THROUGH|plan-1:9'
        call stream newest~changeStr('ledger.', 'ledger.9'), 'c', 'close'
      end
    end
    /* A new arbitrator that remembers nothing, and a new runner on the same journal. */
    arb2 = .MachineArbitrator~new(.MachineState~new(8192, 1024, 40000, 100000))
    runner2 = .PlanRunner~new(dir, arb2, eff, service, .array~of('memory', 'progress'))
    if \runner2~resume(0) then return 'resume found nothing'
    arb = arb2
  end
  do i = 1 to 3
    if eff~timesPerformed('plan-1:'i) \= 1 then return 'step' i 'performed' eff~timesPerformed('plan-1:'i) 'times'
  end
  if arb~state~toLines~makeString('L', '/') \== machine~toLines~makeString('L', '/') then
    return 'ledger' arb~state~toLines~makeString('L', '/') 'machine' machine~toLines~makeString('L', '/')
  if \machine~running~hasIndex('T1') | \machine~running~hasIndex('T2') | machine~swapMiB = 0 then return 'machine not in the planned state'
  if tear then do
    /* The torn line stays torn: later records start on lines of their own. */
    torn = 0; begin3 = 0
    do l over journalLines(dir)
      if right(l, 4) \== '|END' then torn += 1
      else do; parse var l . '|' t '|' . '|' n '|' .; if t == 'BEGIN' & n == 3 then begin3 += 1; end
    end
    if torn \= 1 | begin3 \= 1 then return 'journal after the tear: torn lines' torn', BEGIN 3 records' begin3
  end
  return 'ok'

::routine pulled
  use arg runner, plan
  signal on syntax name breaker
  runner~run(plan, 'plan-1', 0)
  return .false
breaker:
  c = condition('O')
  if c~message~pos('BREAKER') = 0 then raise propagate
  return .true

::routine resumeFinished
  use arg dir
  arb = .MachineArbitrator~new(.MachineState~new(8192, 1024, 40000, 100000))
  return .PlanRunner~new(dir, arb, .SimulatedEffector~new(.MachineState~new(8192, 1024, 40000, 100000)))~resume(0)

::routine journalLines
  use arg dir
  r = .Array~new
  s = .stream~new(dir'/journal.log'); s~open('read')
  do while s~lines > 0; r~append(s~linein); end
  s~close
  return r

::routine countType
  use arg lines, type
  n = 0
  do l over lines; parse var l . '|' t '|' .; if t == type then n += 1; end
  return n

::routine completeMu
  use arg c, muId, now
  arb = c~mu(muId)
  do s over arb~plan(c~held(muId), now)~planned; arb~completed(s, now); end
  return

::routine completeCluster
  use arg c, plan, now
  do s over plan~planned; c~completed(s, now); end
  return

::routine newCluster
  c = .ClusterArbitrator~new
  c~addMu('uk1', 'UK', .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000)), '213.255.246.44')
  c~addMu('au1', 'AU', .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000)), '203.0.113.10')
  c~addMu('us1', 'US', .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000)), '198.51.100.20')
  return c

::routine stepFor
  use arg plan, kind, id
  do s over plan~steps; if s~kind == kind & s~demand \== .nil then if s~demand~id == id then return s; end
  return .nil

::routine hasStep
  use arg plan, kind
  do s over plan~steps; if s~kind == kind then return .true; end
  return .false

::routine decisionWith
  use arg c, word
  do t over c~decisions; if t~pos(word) > 0 then return t; end
  return ''

::requires '../src/ClusterArbitrator.cls'
::requires '../src/PlanRunner.cls'
