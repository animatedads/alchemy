/* rexxos_arbitrator v0.1-dev4 tests: cluster and recovery plans survive a
   pulled plug.
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
   Run from this directory with oorexx_logging v0.7 on REXX_PATH. */
parse arg scratch
if scratch = '' then scratch = '/tmp/rexxos_arbitrator_dev4_tests'
pass = 0; fail = 0
call SysFileTree scratch'/*', 'old.', 'FSO'
do i = 1 to old.0; call SysFileDelete old.i; end
call SysMkDir scratch

/* ---- 1. Text forms of the cluster ---- */
w = buildWorld()
c = w['CLUSTER']
lines = c~snapshotLines
c2 = .ClusterArbitrator~new~restoreFromLines(lines)
call check 'cluster text: the whole cluster round-trips', c2~snapshotLines~makeString('L', '/') == lines~makeString('L', '/'), ''
a = .Directory~new; z = .Directory~new; z['UK'] = 20; z['AU'] = 70; z['US'] = 10; a['rasen-site'] = z
k1 = c~planMoves(10 * 86400 + 23 * 3600, a)~kinds
k2 = c2~planMoves(10 * 86400 + 23 * 3600, a)~kinds
call check 'cluster text: the restored cluster plans the same move', k1 == k2 & k1 \== '', k1 '/' k2
p = buildWorld()['CLUSTER']~muDown('uk1', 100)
dd = .Directory~new
do st over p~steps; if st~demand \== .nil then dd[st~demand~id] = st~demand; end
same = .true
do st over p~steps
  back = .ClusterStep~fromText(st~toText, dd)
  if back~toText \== st~toText | back~mu \== st~mu | back~address \== st~address then same = .false
end
call check 'cluster text: every recovery step round-trips with its MU, role and address', same, ''

/* ---- 2. A recovery plan, journalled ---- */
r = runRecovery(scratch'/clean', 0, '')
call check 'recovery run: uninterrupted, the world ends as planned', r == 'ok', r
do spec over .Array~of('1 BEFORE_PERFORM', '2 AFTER_PERFORM', '3 AFTER_PERFORM', '5 AFTER_SNAPSHOT', '8 BEFORE_PERFORM')
  parse var spec n phase
  r = runRecovery(scratch'/s'n'_'phase, n, phase)
  call check 'recovery run: breaker at step' n phase'; a cluster arbitrator that remembers nothing resumes; every step once; ledgers, routes and epochs match the world', r == 'ok', r
end

say
say 'TOTAL' pass 'passed,' fail 'failed'
if fail > 0 then exit 1
exit 0

check: procedure expose pass fail
  use arg name, ok, detail
  if ok == 1 then do; pass += 1; say 'PASS' name; end
  else do; fail += 1; say 'FAIL' name '['detail']'; end
  return

/* The cluster of dev3's recovery test, and the world it describes. */
::routine buildWorld
  c = .ClusterArbitrator~new
  c~addMu('uk1', 'UK', .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000)), '213.255.246.44')
  c~addMu('au1', 'AU', .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000)), '203.0.113.10')
  c~addMu('us1', 'US', .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000)), '198.51.100.20')
  c~addMu('uk2', 'UK', .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000)), '192.0.2.7')
  c~addPair(.RolePair~new('LDAP', .Demand~new('ldap', 95, 512)), 'uk1', 'au1')
  site = .Demand~new('rasen-site', 50, 64, 0, 300, 'LOCAL', .true, 'READONLY')
  svc = .ServicePlacement~new(site, 'rasen.site', 'GATEWAY', 'www.rasenfalcon.com', 300, 'UK', 3600)
  svc~rule('AU', '22:00', '08:00', 50)
  c~place(svc, 'uk1', 0)
  do m over .Array~of('uk1', 'au1')
    arb = c~mu(m)
    do s over arb~plan(c~held(m), 0)~planned; arb~completed(s, 0); end
  end
  sim = .SimulatedCluster~new
  do m over .Array~of('uk1', 'au1', 'us1', 'uk2'); sim~addMachine(m, c~mu(m)~state~copy); end
  sim~setRoute('LDAP.main', 'uk1'); sim~setRoute('LDAP.spare', 'au1'); sim~setRoute('rasen.site', 'uk1')
  r = .Directory~new; r['CLUSTER'] = c; r['SIM'] = sim
  return r

/* uk1 is pulled; the recovery plan runs through a PlanRunner.  With a
   breaker, a new ClusterArbitrator (knowing nothing) resumes from the
   journal.  Returns 'ok' or what is wrong. */
::routine runRecovery
  use arg dir, breakAt, phase
  call SysMkDir dir
  w = buildWorld(); c = w['CLUSTER']; sim = w['SIM']
  plan = c~muDown('uk1', 100)
  if plan~kinds \== 'FENCE_ROLE ROUTE_SERVICE ACTIVATE_TASK CHECK_SERVING ROUTE_SERVICE ACTIVATE_TASK CHECK_SERVING ROUTE_SERVICE' then return 'unexpected plan' plan~kinds
  if plan~approvalClass \== 'RECOVERY' then return 'not a pre-approved recovery plan'
  service = .LogService~new('arb-test4')
  service~addTarget(.LogLineTarget~new('progress', .Log~INTERNAL))
  runner = .PlanRunner~new(dir, c, sim, service, .array~of('progress'))
  if breakAt > 0 then sim~armBreaker(breakAt, phase)
  crashed = pulled(runner, plan)
  if breakAt = 0 & crashed then return 'crashed without a breaker'
  if breakAt > 0 then do
    if \crashed then return 'breaker did not fire'
    c = .ClusterArbitrator~new                 /* remembers nothing */
    runner2 = .PlanRunner~new(dir, c, sim, service, .array~of('progress'))
    if \runner2~resume(100) then return 'resume found nothing'
  end
  do i = 1 to plan~planned~items
    if sim~timesPerformed('rec-1:'i) \= 1 then return 'step' i 'performed' sim~timesPerformed('rec-1:'i) 'times'
  end
  if c~roleAt('LDAP.main') \== 'au1' | c~roleAt('LDAP.spare') \== 'uk2' | c~whereIs('rasen-site') \== 'uk2' then
    return 'cluster view: main' c~roleAt('LDAP.main') 'spare' c~roleAt('LDAP.spare') 'site' c~whereIs('rasen-site')
  if c~epochOf('LDAP') \= 2 | sim~epochs['LDAP'] \= 2 then return 'epochs: cluster' c~epochOf('LDAP') 'world' sim~epochs['LDAP']
  do a over .Array~of('LDAP.main', 'LDAP.spare', 'rasen.site')
    want = c~roleAt(a); if want == '' then want = c~whereIs('rasen-site')
    if sim~routes[a] \== want then return 'route' a 'is' sim~routes[a] 'in the world,' want 'in the cluster'
  end
  do m over .Array~of('uk1', 'au1', 'us1', 'uk2')
    if c~mu(m)~state~toLines~makeString('L', '/') \== sim~machine(m)~toLines~makeString('L', '/') then
      return 'ledger of' m 'differs from the machine:' c~mu(m)~state~toLines~makeString('L', '/') '<>' sim~machine(m)~toLines~makeString('L', '/')
  end
  if \c~mu('uk2')~state~running~hasIndex('LDAP-3') | \c~mu('uk2')~state~running~hasIndex('rasen-site') then return 'uk2 is not running the new spare and the site'
  return 'ok'

::routine pulled
  use arg runner, plan
  signal on syntax name breaker
  runner~run(plan, 'rec-1', 100)
  return .false
breaker:
  c = condition('O')
  if c~message~pos('BREAKER') = 0 then raise propagate
  return .true

::requires '../src/PlanRunner.cls'
