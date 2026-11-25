/* rexxos_arbitrator v0.1-dev2 tests: swapping tasks out whole, the state
   rule, and cross-arbitration across MUs.
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
   Run from this directory: rexx test_dev2.rex */
pass = 0; fail = 0

/* ---- 1. A task whose state survives is swapped out whole (machine B: 8192, base 1024) ---- */
b = .MachineState~new(8192, 1024, 40000, 100000)
arb = .MachineArbitrator~new(b)
b1 = .Demand~new('B1', 30, 3000, 0, 0, 'NONE', .false, 'TEMPORARY', '', 'CHECKPOINT')
call completeAll arb, arb~plan(.Array~of(b1), 0), 0
web = .Demand~new('web', 90, 5000)
p = arb~plan(.Array~of(b1, web), 10)
call check 'swap-out: more important demand swaps out the checkpointed task, no waiting', p~kinds == 'ASK_CLUSTER DEACTIVATE_TASK START_TASK', p~kinds
call check 'swap-out: the cluster is asked where B1 resumes', stepOf(p, 'ASK_CLUSTER')~note~pos('activate B1') > 0, stepOf(p, 'ASK_CLUSTER')~note
call check 'swap-out: plan is sound', p~ok, p~violations~makeString('L', '; ')
text = p~describe~makeString('L', '0a'x)
call check 'swap-out: state written to its checkpoint and verified before RAM is released', text~pos("write B1's state to its checkpoint") > 0 & text~pos('verify the saved state against its digest') > 0 & text~pos('verify the saved state') < text~pos("release B1's RAM"), ''
call check 'swap-out: undo is ACTIVATE_TASK', stepOf(p, 'DEACTIVATE_TASK')~inverse == 'ACTIVATE_TASK', ''

b = .MachineState~new(8192, 1024, 40000, 100000)
arb = .MachineArbitrator~new(b)
call completeAll arb, arb~plan(.Array~of(b1), 0), 0
big = .Demand~new('big', 70, 6000, 2000)
p = arb~plan(.Array~of(b1, big), 10)
call check 'swap-out instead of swap: no swap file when a task can be swapped out', p~kinds == 'ASK_CLUSTER DEACTIVATE_TASK START_TASK' & p~kinds~wordpos('ADD_SWAP') = 0, p~kinds
call check 'swap-out instead of swap: plan is sound', p~ok, p~violations~makeString('L', '; ')
call completeAll arb, p, 10
call check 'swap-out: B1 is parked, not running', b~parked~hasIndex('B1') & \b~running~hasIndex('B1'), ''
p = arb~plan(.Array~of(b1), 20)
call check 'activate: room again, B1 resumes from its saved state', p~kinds == 'STOP_TASK ACTIVATE_TASK', p~kinds
text = p~describe~makeString('L', '0a'x)
call check 'activate: saved state verified before resuming', text~pos("read B1's saved state from its checkpoint") > 0 & text~pos('verify it against its digest') < text~pos('resume B1'), ''

/* A task whose state cannot travel is not swapped out: swap as before. */
b = .MachineState~new(8192, 1024, 40000, 100000)
arb = .MachineArbitrator~new(b)
tmp = .Demand~new('scratch', 30, 3000, 0, 0, 'NONE', .false, 'TEMPORARY')
call completeAll arb, arb~plan(.Array~of(tmp), 0), 0
p = arb~plan(.Array~of(tmp, big), 10)
call check 'TEMPORARY state: not swapped out; swap provisioned instead', p~kinds == 'ADD_SWAP START_TASK', p~kinds

/* A task with a dirty write-back cache: flush, drop, swap out, then the new work. */
a = .MachineState~new(4096, 512, 20000, 50000)
arba = .MachineArbitrator~new(a)
tw = .Demand~new('tw', 20, 500, 0, 2000, 'FABRIC', .true, 'TEMPORARY', '', 'CHECKPOINT')
p = arba~plan(.Array~of(tw), 0)
call check 'cache: checkpointed temporary data gets a write-back cache', p~kinds == 'START_TASK ADD_CACHE' & stepOf(p, 'ADD_CACHE')~mode == 'WRITEBACK', p~kinds
call completeAll arba, p, 0
a~markDirty('tw')
hot = .Demand~new('hot', 90, 3300)
p = arba~plan(.Array~of(tw, hot), 10)
call check 'cache: flushed and dropped before the task is swapped out', p~kinds == 'ASK_CLUSTER FLUSH_CACHE DROP_CACHE DEACTIVATE_TASK START_TASK', p~kinds
call check 'cache: plan is sound', p~ok, p~violations~makeString('L', '; ')

/* ---- 2. The state rule ---- */
call check 'state: DURABLE data lives on a fabric by default', .Demand~new('x', 1, 10)~stateWhere == 'FABRIC', ''
call check 'state: TEMPORARY data is TEMPORARY by default', .Demand~new('x', 1, 10, 0, 0, 'NONE', .false, 'TEMPORARY')~stateWhere == 'TEMPORARY', ''
call check 'state: importance is the priority', .Demand~new('x', 42, 10)~importance = 42, ''
call raises 'state: LOCAL state is refused (an MU holds nothing that cannot be rebuilt or moved)', ".Demand~new('x', 1, 10, 0, 0, 'NONE', .false, 'DURABLE', '', 'LOCAL')"
call raises 'state: DURABLE data cannot have TEMPORARY state', ".Demand~new('x', 1, 10, 0, 0, 'NONE', .false, 'DURABLE', '', 'TEMPORARY')"
call raises 'state: activating with no saved state is refused', 'call activateUnparked'
call raises 'state: a TEMPORARY task cannot be parked', 'call parkTemporary'

/* ---- 3. Cross-arbitration: the Rasen Falcon site follows the sun ---- */
day = 86400 * 10
c = newCluster()
site = .Demand~new('rasen-site', 50, 64, 0, 300, 'LOCAL', .true, 'READONLY')
svc = .ServicePlacement~new(site, 'rasen.site', 'DNS', 'www.rasenfalcon.com', 300, 'UK', 3600)
svc~rule('AU', '22:00', '08:00', 50)
svc~rule('US', '', '', 60)
c~place(svc, 'uk1', 0)
call completeMu c, 'uk1', day
call check 'site: starts on UK tin with its RAM store', c~mu('uk1')~state~caches~hasIndex('rasen-site'), ''

p = c~planMoves(day + 12 * 3600, access(80, 10, 10))
call check 'site: midday with UK traffic stays in the UK', p~steps~items = 0 & c~decisions[1]~pos('stay in UK') > 0, c~decisions[1]
p = c~planMoves(day + 23 * 3600, access(20, 70, 10))
call check 'site: 23:00 GMT with Australian traffic moves to AU', p~kinds == 'ACTIVATE_TASK ADD_CACHE CHECK_SERVING ROUTE_SERVICE REPOINT_DNS WAIT_DNS DROP_CACHE DEACTIVATE_TASK', p~kinds
call check 'site: new copy on au1, old released on uk1', p~steps[1]~mu == 'au1' & p~steps[p~steps~items]~mu == 'uk1', ''
call check 'site: route moves before the old copy goes, and old DNS answers expire first', posOf(p, 'ROUTE_SERVICE') < posOf(p, 'DEACTIVATE_TASK') & posOf(p, 'WAIT_DNS') < posOf(p, 'DROP_CACHE'), ''
call check 'site: checked before anyone is sent to it', posOf(p, 'CHECK_SERVING') < posOf(p, 'ROUTE_SERVICE'), ''
call check 'site: route and DNS changes need approval, waiting and checking do not', stepOf(p, 'ROUTE_SERVICE')~changesMachine & stepOf(p, 'REPOINT_DNS')~changesMachine & \stepOf(p, 'WAIT_DNS')~changesMachine & \stepOf(p, 'CHECK_SERVING')~changesMachine, ''
call check 'site: clients keep the same service address', stepOf(p, 'ROUTE_SERVICE')~actions~makeString('L', ' ')~pos('clients keep the same service address') > 0, ''
call check 'site: plan is sound', p~ok, p~violations~makeString('L', '; ')
call completeCluster c, p, day + 23 * 3600
call check 'site: now on au1', c~whereIs('rasen-site') == 'au1' & c~mu('au1')~state~running~hasIndex('rasen-site') & \c~mu('uk1')~state~running~hasIndex('rasen-site'), c~whereIs('rasen-site')
call check 'site: nothing of it left parked on uk1', \c~mu('uk1')~state~parked~hasIndex('rasen-site'), ''

p = c~planMoves(day + 23 * 3600 + 1800, access(90, 5, 5))
call check 'site: half an hour later it is held by its minimum residence', p~steps~items = 0 & c~decisions[1]~pos('minimum residence') > 0, c~decisions[1]
p = c~planMoves(day + 86400 + 8 * 3600 + 1800, access(20, 70, 10))
call check 'site: 08:30 GMT goes home to UK tin even with Australian traffic', p~kinds~pos('ROUTE_SERVICE') > 0 & p~steps[1]~mu == 'uk1', p~kinds
call completeCluster c, p, day + 86400 + 8 * 3600 + 1800
p = c~planMoves(day + 86400 + 15 * 3600, access(25, 10, 65))
call check 'site: a lot of access from the USA moves it to the US', p~kinds~pos('ROUTE_SERVICE') > 0 & p~steps[1]~mu == 'us1', p~kinds

/* Behind XTP gateways the public name never changes. */
c = newCluster()
site2 = .Demand~new('rasen-site', 50, 64, 0, 300, 'LOCAL', .true, 'READONLY')
svc2 = .ServicePlacement~new(site2, 'rasen.site', 'GATEWAY', 'www.rasenfalcon.com', 300, 'UK', 3600)
svc2~rule('AU', '22:00', '08:00', 50)
c~place(svc2, 'uk1', 0)
call completeMu c, 'uk1', day
p = c~planMoves(day + 23 * 3600, access(20, 70, 10))
call check 'gateway edge: the move is a route change only, no DNS steps', p~kinds == 'ACTIVATE_TASK ADD_CACHE CHECK_SERVING ROUTE_SERVICE DROP_CACHE DEACTIVATE_TASK', p~kinds

/* No room in the zone: it stays, and says why. */
c = newCluster()
c~hold('au1', .Demand~new('hog', 90, 3550))
call completeMu c, 'au1', 0
site3 = .Demand~new('rasen-site', 50, 64, 0, 300, 'LOCAL', .true, 'READONLY')
svc3 = .ServicePlacement~new(site3, 'rasen.site', 'GATEWAY', 'www.rasenfalcon.com', 300, 'UK', 3600)
svc3~rule('AU', '22:00', '08:00', 50)
c~place(svc3, 'uk1', 0)
call completeMu c, 'uk1', day
p = c~planMoves(day + 23 * 3600, access(20, 70, 10))
call check 'no room: no MU in AU can take it without displacing other work', p~steps~items = 0 & c~decisions[1]~pos('no MU there') > 0, c~decisions[1]

/* A checkpointed service hands over: one owner at a time. */
c = newCluster()
game = .Demand~new('game', 60, 1000, 0, 0, 'NONE', .false, 'TEMPORARY', '', 'CHECKPOINT')
svc4 = .ServicePlacement~new(game, 'game.svc', 'NONE', '', 0, 'UK', 600)
svc4~rule('US', '', '', 60)
c~place(svc4, 'uk1', 0)
call completeMu c, 'uk1', day
p = c~planMoves(day + 15 * 3600, access(30, 0, 70))
call check 'checkpoint: old copy swapped out first, then resumed on the target, then the route', p~kinds == 'DEACTIVATE_TASK ACTIVATE_TASK CHECK_SERVING ROUTE_SERVICE' & p~steps[1]~mu == 'uk1' & p~steps[2]~mu == 'us1', p~kinds
call check 'checkpoint: the outage is stated', decisionWith(c, 'outage') \== '', ''
call completeCluster c, p, day + 15 * 3600
call check 'checkpoint: running on us1 only', c~whereIs('game') == 'us1' & c~mu('us1')~state~running~hasIndex('game') & \c~mu('uk1')~state~running~hasIndex('game') & \c~mu('uk1')~state~parked~hasIndex('game'), ''

/* TEMPORARY state stays put. */
c = newCluster()
eph = .Demand~new('eph', 60, 500, 0, 0, 'NONE', .false, 'TEMPORARY')
svc5 = .ServicePlacement~new(eph, 'eph.svc', 'NONE', '', 0, 'UK', 0)
svc5~rule('US', '', '', 60)
c~place(svc5, 'uk1', 0)
call completeMu c, 'uk1', day
p = c~planMoves(day, access(10, 0, 90))
call check 'temporary: a service whose state is TEMPORARY does not move', p~steps~items = 0 & c~decisions[1]~pos('cannot move') > 0, c~decisions[1]

/* ---- 4. LDAP.main and LDAP.spare: service addresses on separate sites ---- */
c = newCluster()
c~addMu('uk2', 'UK', .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000)), '192.0.2.7')
ldap = .RolePair~new('LDAP', .Demand~new('ldap', 95, 512))
c~addPair(ldap, 'uk1', 'au1')
call completeMu c, 'uk1', 0; call completeMu c, 'au1', 0
call check 'roles: LDAP.main on uk1, LDAP.spare on au1', c~roleAt('LDAP.main') == 'uk1' & c~roleAt('LDAP.spare') == 'au1', c~roleAt('LDAP.main') c~roleAt('LDAP.spare')
p = c~muDown('uk1', 100)
call check 'failover: fence, the spare becomes the main, a new spare is made and named', p~kinds == 'FENCE_ROLE ROUTE_SERVICE ACTIVATE_TASK CHECK_SERVING ROUTE_SERVICE', p~kinds
call check 'failover: the old main is fenced before LDAP.main moves', posOf(p, 'FENCE_ROLE') < posOf(p, 'ROUTE_SERVICE') & p~steps[2]~address == 'LDAP.main' & p~steps[2]~mu == 'au1', ''
call check 'failover: the new spare is on a site other than the new main (au1 is AU; uk2 is UK)', p~steps[3]~mu == 'uk2', p~steps[3]~mu
call check 'failover: the new spare has caught up before it is named', posOf(p, 'CHECK_SERVING') < p~steps~items & p~steps[p~steps~items]~address == 'LDAP.spare', ''
call check 'failover: plan is sound', p~ok, p~violations~makeString('L', '; ')
call completeCluster c, p, 100
call check 'failover: LDAP.main is now au1, LDAP.spare uk2, epoch 2', c~roleAt('LDAP.main') == 'au1' & c~roleAt('LDAP.spare') == 'uk2' & c~epochOf('LDAP') = 2, c~roleAt('LDAP.main') c~roleAt('LDAP.spare') c~epochOf('LDAP')
call check 'failover: clients still address LDAP.main; only the route moved', stepActions(p, 2)~pos('clients keep LDAP.main') > 0, stepActions(p, 2)
p = c~muDown('uk2', 200)
call check 'spare lost: only a new spare is made, on a site other than the main', p~kinds == 'ACTIVATE_TASK CHECK_SERVING ROUTE_SERVICE' & p~steps[1]~mu == 'us1', p~kinds
call completeCluster c, p, 200
call check 'spare lost: LDAP.spare is us1, LDAP.main unchanged, epoch unchanged', c~roleAt('LDAP.spare') == 'us1' & c~roleAt('LDAP.main') == 'au1' & c~epochOf('LDAP') = 2, ''
p = c~muDown('us1', 300)
call check 'no other site left: running without a spare is reported, not hidden', \p~ok & p~violations~makeString('L', ' ')~pos('no MU on another site') > 0, p~violations~makeString('L', '; ')
call raises 'roles: main and spare on the same site refused', 'call sameSite'
call raises 'roles: a hot spare needs fabric state', ".RolePair~new('X', .Demand~new('x', 1, 64, 0, 0, 'NONE', .false, 'TEMPORARY'))"

call raises 'service: bad window refused', "x = .ServicePlacement~new(.Demand~new('s', 1), 's', 'NONE', '', 0, 'UK')~rule('AU', '25:00', '08:00', 0)"
call raises 'service: a public name needs an edge', ".ServicePlacement~new(.Demand~new('s', 1), 's', 'NONE', 'www.example.org', 0, 'UK')"

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

::routine completeAll
  use arg arb, plan, now
  do s over plan~planned; arb~completed(s, now); end
  return

/* Let an MU's own arbitrator bring it to the state its held demands ask for. */
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

::routine access
  use arg uk, au, us
  z = .Directory~new; z['UK'] = uk; z['AU'] = au; z['US'] = us
  r = .Directory~new
  do id over .Array~of('rasen-site', 'game', 'eph'); r[id] = z; end
  return r

::routine stepOf
  use arg plan, kind
  do s over plan~steps; if s~kind == kind then return s; end
  return .nil

::routine posOf
  use arg plan, kind
  do i = 1 to plan~steps~items; if plan~steps[i]~kind == kind then return i; end
  return 0

::routine stepActions
  use arg plan, n
  return plan~steps[n]~actions~makeString('L', ' ')

::routine sameSite
  c = newCluster()
  c~addMu('uk2', 'UK', .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000)), '192.0.2.7')
  c~addPair(.RolePair~new('LDAP', .Demand~new('ldap', 95, 512)), 'uk1', 'uk2')
  return

::routine decisionWith
  use arg c, word
  do t over c~decisions; if t~pos(word) > 0 then return t; end
  return ''

/* Routines, not internal labels: an internal routine inherits the
   caller's SIGNAL ON SYNTAX and would take the trap in its own activation. */
::routine activateUnparked
  m = .MachineState~new(4096, 512, 1000)
  m~apply(.ProvisionStep~new('ACTIVATE_TASK', .Demand~new('t', 1, 64), 'x'))
  return

::routine parkTemporary
  m = .MachineState~new(4096, 512, 1000)
  m~park(.Demand~new('t', 1, 64, 0, 0, 'NONE', .false, 'TEMPORARY'))
  return

::requires '../src/ClusterArbitrator.cls'
