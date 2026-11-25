/* rexxos_arbitrator dev1 machine tests, kept in dev2.
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
   Run from this directory: rexx test_dev1.rex */
pass = 0; fail = 0

/* ---- 1. The Rasen Falcon static site (machine A: 4096 MiB, base 512) ---- */
a = .MachineState~new(4096, 512, 20000, 50000)
arb = .MachineArbitrator~new(a)
site = .Demand~new('rasen-site', 50, 64, 0, 300, 'LOCAL', .true, 'READONLY')
p = arb~plan(.Array~of(site), 0)
call check 'site: low load gives start then RAM store', p~kinds == 'START_TASK ADD_CACHE', p~kinds
call check 'site: plan is sound', p~ok, p~violations~makeString('L', '; ')
call check 'site: RAM store holds the whole site', p~planned[2]~sizeMiB = 300 & p~planned[2]~mode == 'READONLY', p~planned[2]
text = p~describe~makeString('L', '0a'x)
call check 'site: read-only store is verified before the switch', text~pos('verify the copy against its digest') > 0 & text~pos('verify') < text~pos("switch rasen-site's root to the RAM store"), ''
call check 'site: machine changes need approval', p~needsApproval & text~pos('NEEDS TOM''S DIRECT APPROVAL') > 0, ''
call completeAll arb, p, 0
call check 'site: state records the store', a~caches~hasIndex('rasen-site') & a~running~hasIndex('rasen-site'), ''
p = arb~plan(.Array~of(site), 10)
call check 'site: nothing to do in the target state', p~steps~items = 0, p~kinds

big = .Demand~new('analysis', 80, 3300)          /* must not page */
p = arb~plan(.Array~of(site, big), 20)
call check 'site: RAM demand takes the store back first', p~kinds == 'DROP_CACHE START_TASK', p~kinds
call check 'site: read-only store needs no flush', p~kinds~wordpos('FLUSH_CACHE') = 0, p~kinds
call check 'site: plan is sound', p~ok, p~violations~makeString('L', '; ')
text = p~describe~makeString('L', '0a'x)
call check 'site: root switches back before the store goes', text~pos("switch rasen-site's root back to its drive") > 0 & text~pos("switch rasen-site's root back") < text~pos('release the RAM store'), ''
call completeAll arb, p, 20

p = arb~plan(.Array~of(site), 100)
call check 'site: demand gone, store comes back', p~kinds == 'STOP_TASK ADD_CACHE', p~kinds
call completeAll arb, p, 100

/* Hysteresis: an existing store only has to fit; a new one needs headroom. */
mid = .Demand~new('mid', 80, 3200)              /* leaves 320 MiB; headroom is 615 */
p = arb~plan(.Array~of(site, mid), 200)
call check 'hysteresis: existing store kept when it still fits', p~kinds == 'START_TASK', p~kinds
b0 = .MachineState~new(4096, 512, 20000, 50000)
arb0 = .MachineArbitrator~new(b0)
p = arb0~plan(.Array~of(site, mid), 0)
call check 'hysteresis: new store not made without headroom', p~kinds == 'START_TASK START_TASK', p~kinds

/* ---- 2. Tom's T1/T2 (machine B: 8192 MiB, base 1024) ---- */
b = .MachineState~new(8192, 1024, 40000, 100000)
arb = .MachineArbitrator~new(b)
t1 = .Demand~new('T1', 60, 512, 0, 20000, 'FABRIC', .true, 'TEMPORARY')
t2 = .Demand~new('T2', 70, 9000, 4000)
p = arb~plan(.Array~of(t1, t2), 0)
call check 'T1/T2: swap first, then T2, then T1', p~kinds == 'ADD_SWAP START_TASK START_TASK' & p~planned[2]~demand~id == 'T2', p~kinds
call check 'T1/T2: swap sized to the excess plus margin', p~planned[1]~sizeMiB = 2579, p~planned[1]~sizeMiB
call check 'T1/T2: no RAM cache while swapping', p~kinds~wordpos('ADD_CACHE') = 0, p~kinds
call check 'T1/T2: plan is sound', p~ok, p~violations~makeString('L', '; ')
call completeAll arb, p, 0

p = arb~plan(.Array~of(t1), 100)
call check 'T1/T2: T2 gone early, swap removal deferred', p~kinds == 'STOP_TASK ADD_CACHE' & stepOf(p, 'REMOVE_SWAP')~status == 'DEFERRED', p~kinds
p = arb~plan(.Array~of(t1), 1000)
call check 'T1/T2: T2 gone, swap goes, RAM cache for T1', p~kinds == 'STOP_TASK REMOVE_SWAP ADD_CACHE', p~kinds
c = stepOf(p, 'ADD_CACHE')
call check 'T1/T2: T1 gets a write-back cache (its request is TEMPORARY)', c~mode == 'WRITEBACK', c~mode
call check 'T1/T2: cache is RAM above headroom', c~sizeMiB = 7168 - 512 - 1229, c~sizeMiB
call check 'T1/T2: plan is sound', p~ok, p~violations~makeString('L', '; ')
call completeAll arb, p, 1000

/* A new RAM demand: the write-back cache is flushed before it is given back. */
b~markDirty('T1')
t3 = .Demand~new('T3', 90, 4000)
p = arb~plan(.Array~of(t1, t3), 1100)
call check 'flush: write-back cache flushed, dropped, then T3', p~kinds == 'FLUSH_CACHE DROP_CACHE START_TASK', p~kinds
call check 'flush: plan is sound', p~ok, p~violations~makeString('L', '; ')

/* Write-through: nothing to flush. */
w = .MachineState~new(8192, 1024, 40000, 100000)
arbw = .MachineArbitrator~new(w)
t1d = .Demand~new('T1', 60, 512, 0, 20000, 'FABRIC', .true, 'DURABLE')
p = arbw~plan(.Array~of(t1d), 0)
call check 'write-through: DURABLE request gets a write-through cache', stepOf(p, 'ADD_CACHE')~mode == 'WRITETHROUGH', p~kinds
call completeAll arbw, p, 0
p = arbw~plan(.Array~of(t1d, t3), 10)
call check 'write-through: dropped with no flush', p~kinds == 'DROP_CACHE START_TASK', p~kinds

/* Case by case: a request may name its own cache mode. */
t1x = .Demand~new('T1x', 60, 512, 0, 2000, 'FABRIC', .true, 'TEMPORARY', 'WRITETHROUGH')
call check 'case by case: request names write-through for temporary data', t1x~cacheMode == 'WRITETHROUGH', t1x~cacheMode

/* ---- 3. Asking the cluster ---- */
e = .MachineState~new(8192, 1024, 40000, 100000)
arbe = .MachineArbitrator~new(e)
t4 = .Demand~new('T4', 40, 8000)                 /* must not page, bigger than RAM */
p = arbe~plan(.Array~of(t4), 0)
call check 'cluster: unpageable demand bigger than RAM goes to the cluster, no swap', p~kinds == 'ASK_CLUSTER', p~kinds
call check 'cluster: asking needs no approval', \p~needsApproval, ''

t2t = .Demand~new('T2', 70, 9000, 4000, 0, 'NONE', .false, 'TEMPORARY')   /* state cannot travel */
call completeAll arbe, arbe~plan(.Array~of(t2t), 0), 0
t5 = .Demand~new('T5', 95, 3000)
p = arbe~plan(.Array~of(t2t, t5), 10)
call check 'cluster: higher priority asks the cluster to move the lower', p~kinds == 'ASK_CLUSTER' & stepOf(p, 'ASK_CLUSTER')~demand~id == 'T2', p~kinds
s = stepOf(p, 'START_TASK')
call check 'cluster: the new task waits for the move', s \== .nil & s~status == 'WAITING' & s~demand~id == 'T5', s
call check 'cluster: the arbitrator never stops the moved task itself', p~kinds~wordpos('STOP_TASK') = 0, p~kinds
p = arbe~plan(.Array~of(t5), 20)                 /* the cluster moved T2: an event */
call check 'cluster: after the move, re-plan stops T2 and starts T5', p~kinds == 'STOP_TASK START_TASK', p~kinds

c0 = .MachineState~new(4096, 512, 1000, 0)
arbc = .MachineArbitrator~new(c0)
t6 = .Demand~new('T6', 30, 6000, 4000)
p = arbc~plan(.Array~of(t6), 0)
call check 'cluster: no disk for swap, demand goes to the cluster', p~kinds == 'ASK_CLUSTER', p~kinds
call check 'cluster: plan is sound', p~ok, p~violations~makeString('L', '; ')
f = .MachineState~new(4096, 512, 20000, 100)
arbf = .MachineArbitrator~new(f)
p = arbf~plan(.Array~of(.Demand~new('needs-fabric', 10, 64, 0, 500, 'FABRIC')), 0)
call check 'cluster: not enough fabric space', p~kinds == 'ASK_CLUSTER' & stepOf(p, 'ASK_CLUSTER')~cause~pos('fabric') > 0, stepOf(p, 'ASK_CLUSTER')~cause

/* ---- 4. Invariants, steps and validation ---- */
s1 = .MachineState~new(1024, 256, 100)
s1~apply(.ProvisionStep~new('START_TASK', .Demand~new('huge', 1, 2000), 'test'))
call check 'invariant: resident over budget is reported', s1~violations~items >= 1, s1~violations~makeString('L', '; ')
call check 'step: inverses', .ProvisionStep~new('ADD_SWAP', .nil, 'x', 1)~inverse == 'REMOVE_SWAP' & .ProvisionStep~new('ADD_CACHE', site, 'x', 1, 'READONLY')~inverse == 'DROP_CACHE', ''
call check 'step: flush has no inverse', .ProvisionStep~new('FLUSH_CACHE', site, 'x')~inverse == '', ''
call raises 'step: dirty write-back cache cannot be dropped', 'call dropDirty'
call raises 'demand: DURABLE data may not use write-back', ".Demand~new('x', 1, 0, 0, 10, 'LOCAL', .true, 'DURABLE', 'WRITEBACK')"
call raises 'demand: read-only cache needs read-only data', ".Demand~new('x', 1, 0, 0, 10, 'LOCAL', .true, 'TEMPORARY', 'READONLY')"
call raises 'demand: pageable cannot exceed RAM', ".Demand~new('x', 1, 10, 20)"
call raises 'demand: RAM speed needs storage', ".Demand~new('x', 1, 10, 0, 0, 'NONE', .true)"
call raises 'demand: bad id refused', ".Demand~new('a b', 1)"
call raises 'plan: same demand twice refused', "call twice"
call raises 'step: unknown kind refused', ".ProvisionStep~new('REBOOT', .nil, 'x')"

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

completeAll: procedure
  use arg arb, plan, now
  do s over plan~planned; arb~completed(s, now); end
  return

stepOf: procedure
  use arg plan, kind
  do s over plan~steps; if s~kind == kind then return s; end
  return .nil

::requires '../src/Arbitrator.cls'

/* Routines, not internal labels: an internal routine inherits the
   caller's SIGNAL ON SYNTAX and would take the trap in its own activation. */
::routine dropDirty
  m = .MachineState~new(4096, 512, 1000)
  d = .Demand~new('t', 1, 64, 0, 100, 'LOCAL', .true, 'TEMPORARY')
  m~apply(.ProvisionStep~new('ADD_CACHE', d, 'x', 100, 'WRITEBACK'))
  m~markDirty('t')
  m~apply(.ProvisionStep~new('DROP_CACHE', d, 'x', 100, 'WRITEBACK'))
  return

::routine twice
  d = .Demand~new('t', 1)
  .MachineArbitrator~new(.MachineState~new(1024, 256, 10))~plan(.Array~of(d, d), 0)
  return

