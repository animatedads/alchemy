/* rexxos_arbitrator v0.1-dev6 tests: one runner at a time on a journal.
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
   Run from this directory with oorexx_logging v0.7 on REXX_PATH. */
parse arg scratch
if scratch = '' then scratch = '/tmp/rexxos_arbitrator_dev6_tests'
pass = 0; fail = 0
call SysFileTree scratch'/*', 'old.', 'FSO'
do i = 1 to old.0; call SysFileDelete old.i; end
call SysMkDir scratch

/* ---- 1. A runner takes the lease and every record carries its epoch ---- */
w = world(scratch'/one')
a = runner(w, 'A')
a~run(w['PLAN'], 'plan-1', 0)
call check 'lease: runner A holds epoch 1', a~epoch = 1 & a~currentLease['HOLDER'] == 'A', a~currentLease['HOLDER'] a~epoch
call check 'lease: every journal record carries epoch 1', allEpochs(w['DIR']) == '1', allEpochs(w['DIR'])
call check 'lease: the plan finished, each step once, ledger matches the machine', finishedOnce(w, a~arb, 3), ''

/* ---- 2. A crashed runner's lease blocks others until it expires ---- */
w = world(scratch'/two')
a = runner(w, 'A')
w['EFF']~armBreaker(2, 'AFTER_PERFORM')
call check 'crash: runner A is cut off at step 2', pulled(a, w['PLAN']) == 'BREAKER', ''
b = runner(w, 'B')
call check 'held: runner B is refused while A''s lease runs', resumeError(b) ~pos('LEASE_HELD by A') > 0, ''
w['CLOCK']~advance(61)
b = runner(w, 'B')
call check 'expired: runner B takes over at epoch 2 and finishes', resumeError(b) == '' & b~epoch = 2, b~epoch
call check 'expired: each step once, ledger matches the machine', finishedOnce(w, b~arb, 3), ''

/* ---- 3. A runner that lost its lease mid-step writes nothing more ---- */
w = world(scratch'/three')
w['EFF'] = .ZombieEffector~new(w['MACHINE'], w['CLOCK'])
a = runner(w, 'A')
b = runner(w, 'B')
w['EFF']~armZombie(2, b)
r = pulled(a, w['PLAN'])
call check 'zombie: A stalls in step 2, B takes over and finishes, then A stops with LEASE_LOST', r~pos('LEASE_LOST') > 0 & w['EFF']~zombieFired, r
call check 'zombie: each step once (B found step 2 already done), ledger of B matches the machine', finishedOnce(w, b~arb, 3), ''
call check 'zombie: no epoch-1 record after the first epoch-2 record', noStaleAfterTakeover(w['DIR']), ''

/* ---- 4. A long plan renews its lease ---- */
w = world(scratch'/four')
w['EFF'] = .TickingEffector~new(w['MACHINE'], w['CLOCK'], 25)       /* each step takes 25 s */
a = runner(w, 'A')
a~run(w['PLAN'], 'plan-1', 0)
call check 'renew: 3 steps of 25 s with a 60 s lease finish at epoch 1', a~epoch = 1 & finishedOnce(w, a~arb, 3), a~epoch
call check 'renew: the lease now ends after the last step', a~currentLease['EXPIRES'] > 75, a~currentLease['EXPIRES']

/* ---- 5. A late write from a lost lease does not count ---- */
w = world(scratch'/five')
a = runner(w, 'A')
w['EFF']~armBreaker(2, 'BEFORE_PERFORM')
call pulled a, w['PLAN']
w['CLOCK']~advance(61)
b = runner(w, 'B')
w['EFF']~armBreaker(3, 'BEFORE_PERFORM')
call check 'late write: B (epoch 2) is cut off before step 3', resumeError(b)~pos('BREAKER') > 0, ''
/* The old runner A, still alive somewhere, appends as if it had finished. */
call lineout w['DIR']'/journal.log', '900@1|DONE|plan-1|3|START_TASK|END'
call lineout w['DIR']'/journal.log', '901@1|END|plan-1|3|finished|END'
call stream w['DIR']'/journal.log', 'c', 'close'
w['CLOCK']~advance(61)
c = runner(w, 'C')
call check 'late write: runner C (epoch 3) ignores A''s epoch-1 DONE and END and does step 3', resumeError(c) == '' & c~epoch = 3, c~epoch
call check 'late write: each step once, ledger matches the machine', finishedOnce(w, c~arb, 3), ''

say
say 'TOTAL' pass 'passed,' fail 'failed'
if fail > 0 then exit 1
exit 0

check: procedure expose pass fail
  use arg name, ok, detail
  if ok == 1 then do; pass += 1; say 'PASS' name; end
  else do; fail += 1; say 'FAIL' name '['detail']'; end
  return

/* T1/T2 on machine B: ADD_SWAP, START T2, START T1. */
::routine world
  use arg dir
  call SysMkDir dir
  r = .Directory~new
  r['DIR'] = dir
  r['MACHINE'] = .MachineState~new(8192, 1024, 40000, 100000)
  r['CLOCK'] = .TestClock~new
  r['EFF'] = .SimulatedEffector~new(r['MACHINE'])
  arb = .MachineArbitrator~new(.MachineState~new(8192, 1024, 40000, 100000))
  t1 = .Demand~new('T1', 60, 512, 0, 20000, 'FABRIC', .true, 'TEMPORARY')
  t2 = .Demand~new('T2', 70, 9000, 4000, 0, 'NONE', .false, 'TEMPORARY')
  r['PLAN'] = arb~plan(.Array~of(t1, t2), 0)
  r['FIRSTARB'] = arb
  r['SERVICE'] = .LogService~new('arb-test6')
  r['SERVICE']~addTarget(.LogMemoryTarget~new('quiet', .Log~INTERNAL))
  return r

/* A runner with a fresh arbitrator (it remembers nothing) and a 60 s lease. */
::routine runner
  use arg w, holder
  if holder == 'A' then arb = w['FIRSTARB']
  else arb = .MachineArbitrator~new(.MachineState~new(8192, 1024, 40000, 100000))
  return .PlanRunner~new(w['DIR'], arb, w['EFF'], w['SERVICE'], .array~of('quiet'), holder, 60, w['CLOCK'])

::routine pulled
  use arg runner, plan
  signal on syntax name stopped
  runner~run(plan, 'plan-1', 0)
  return ''
stopped:
  m = condition('O')~message
  if m~pos('BREAKER') > 0 then return 'BREAKER'
  return m                       /* LEASE_LOST, or whatever went wrong instead */

::routine resumeError
  use arg runner
  signal on syntax name stopped
  runner~resume(0)
  return ''
stopped:
  m = condition('O')~message
  if m~pos('BREAKER') > 0 | m~pos('LEASE_') > 0 then return m
  raise propagate

::routine finishedOnce
  use arg w, arb, n
  do i = 1 to n; if w['EFF']~timesPerformed('plan-1:'i) \= 1 then return .false; end
  return arb~state~toLines~makeString('L', '/') == w['MACHINE']~toLines~makeString('L', '/')

::routine journal
  use arg dir
  r = .Array~new
  s = .stream~new(dir'/journal.log'); s~open('read')
  do while s~lines > 0; r~append(s~linein); end
  s~close
  return r

::routine allEpochs
  use arg dir
  seen = ''
  do l over journal(dir)
    parse var l k '|' .
    parse var k . '@' e
    if wordpos(e, seen) = 0 then seen = seen e
  end
  return seen~strip

::routine noStaleAfterTakeover
  use arg dir
  saw2 = .false
  do l over journal(dir)
    parse var l k '|' .
    parse var k . '@' e
    if e = 2 then saw2 = .true
    if saw2 & e = 1 then return .false
  end
  return saw2

::class TestClock public
::method init
  expose now
  now = 0
::attribute now get
::method advance
  expose now
  use strict arg n
  now += n

/* Every step takes some seconds of the clock. */
::class TickingEffector public subclass SimulatedEffector
::method init
  expose clock tick
  use strict arg state, clock, tick
  self~init:super(state)
::method perform
  expose clock tick
  use strict arg step, key, now
  clock~advance(tick)
  return self~perform:super(step, key, now)

/* At a chosen step, after performing it, the runner stalls past its lease;
   another runner takes over and finishes before the first wakes up. */
::class ZombieEffector public subclass SimulatedEffector
::method init
  expose clock atStep other fired
  use strict arg state, clock
  self~init:super(state)
  atStep = 0; other = .nil; fired = .false
::method armZombie
  expose atStep other
  use strict arg atStep, other
::method zombieFired
  expose fired
  return fired
::method breaker
  expose clock atStep other fired
  use strict arg phase, n
  if phase == 'AFTER_PERFORM' & n = atStep & \fired then do
    fired = .true
    clock~advance(61)
    other~resume(clock~now)
  end
  return self~breaker:super(phase, n)

::requires '../src/PlanRunner.cls'
