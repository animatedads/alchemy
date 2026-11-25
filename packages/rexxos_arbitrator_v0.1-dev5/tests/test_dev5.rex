/* rexxos_arbitrator v0.1-dev5 tests: moving LDAP.main when LDAP.main died.
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
   Run from this directory with oorexx_logging v0.7 on REXX_PATH. */
parse arg scratch
if scratch = '' then scratch = '/tmp/rexxos_arbitrator_dev5_tests'
pass = 0; fail = 0
call SysFileTree scratch'/*', 'old.', 'FSO'
do i = 1 to old.0; call SysFileDelete old.i; end
call SysMkDir scratch

w = buildWorld(); c = w['CLUSTER']; world = w['WORLD']

/* ---- 1. Normal running, then the main stops answering ---- */
r = world~daemon('us1')~lookup('svc.x')
call check 'normal: a daemon resolves through LDAP.main', r[1] == 'FRESH' & r[2] == 'us1', r~makeString('L', ' ')
world~kill('uk1')
r = world~daemon('us1')~lookup('svc.x')
call check 'main silent, no quorum yet: the daemon reads from the spare, marked STALE', r[1] == 'STALE' & r[2] == 'us1', r~makeString('L', ' ')
call check 'main silent: no daemon changes its bootstrap file on its own', world~daemon('us1')~record~epoch = 1 & world~daemon('us1')~record~main == 'uk1', ''

/* ---- 2. The quorum decides; the role moves by announcement ---- */
plan = c~muDown('uk1', 100)
call check 'plan: LDAP is self-routing, so its role moves are announced, not published through LDAP', plan~kinds == 'FENCE_ROLE ANNOUNCE_ROLE ACTIVATE_TASK CHECK_SERVING ANNOUNCE_ROLE', plan~kinds
call check 'plan: still a pre-approved recovery plan', plan~approvalClass == 'RECOVERY', plan~recoveryProblem
call check 'plan: the fence names the LDAP epoch authority', plan~steps[1]~actions[1]~pos('IdentityPeerEpochAuthority~promote') > 0, plan~steps[1]~actions[1]
call SysMkDir scratch'/announce'
runner = .PlanRunner~new(scratch'/announce', c, world, quietService(), .array~of('quiet'))
runner~run(plan, 'ldap-1', 100)
ok = .true
do m over .Array~of('au1', 'us1', 'uk2')
  f = world~daemon(m)~record
  if f~main \== 'au1' | f~spare \== 'uk2' | f~epoch \= 2 | f~version \= 3 then ok = .false
end
call check 'after: every live daemon file says main au1, spare uk2, epoch 2, version 3', ok, world~daemon('us1')~record~canonical
r = world~daemon('us1')~lookup('svc.x')
call check 'after: lookups go through the new main again (FRESH)', r[1] == 'FRESH', r[1]
call check 'after: the cluster agrees (LDAP.main au1, LDAP.spare uk2, epoch 2)', c~roleAt('LDAP.main') == 'au1' & c~roleAt('LDAP.spare') == 'uk2' & c~epochOf('LDAP') = 2, ''
call check 'after: the dead MU daemon was not reached and still holds epoch 1', world~daemon('uk1')~record~epoch = 1, ''

/* ---- 3. Announcements a daemon must refuse ---- */
d = world~daemon('us1')
cur = d~record
fake = .RoleRecord~new('LDAP', 'uk1', 'au1', 9, 9, cur~seeds, cur~keys)
call check 'refuse: a forged signature', d~offer(fake, cur~keys[1], 'SUM12345') == 'REJECTED_BAD_SIGNATURE', ''
rogue = .RoleAuthority~new~addKey('K-rogue', 'other secret')
call check 'refuse: a key the file does not trust', d~offer(fake, 'K-rogue', rogue~sign('K-rogue', fake~canonical)) == 'REJECTED_UNTRUSTED_KEY', ''
old = .RoleRecord~new('LDAP', 'uk1', 'au1', 1, 7, cur~seeds, cur~keys)
call check 'refuse: a genuine but older record (the old main announcing epoch 1)', d~offer(old, cur~keys[1], world~authority~sign(cur~keys[1], old~canonical)) == 'REJECTED_NOT_NEWER', ''
call check 'refuse: the file is unchanged after all three', d~record == cur, ''

/* ---- 4. The old main comes back ---- */
src = world~returnMu('uk1', 'LDAP')
call check 'return: the old main daemon catches up from its file (au1 answered)', src == 'au1' & world~daemon('uk1')~record~epoch = 2, src
call check 'return: the old LDAP main hears the higher epoch and stands down', world~ldapRoleOf('uk1') == 'stood-down' & \world~answersAsMain('uk1', 2), world~ldapRoleOf('uk1')

/* ---- 5. A daemon that slept through two failures ---- */
w = buildWorld(); c = w['CLUSTER']; world = w['WORLD']
world~sleep('us2')
world~kill('uk1')
call SysMkDir scratch'/double'
runner = .PlanRunner~new(scratch'/double', c, world, quietService(), .array~of('quiet'))
runner~run(c~muDown('uk1', 100), 'ldap-a', 100)
world~kill('au1')
p2 = c~muDown('au1', 200)
call check 'second failure: uk2 becomes main, a new spare on another site (us1)', p2~kinds == 'FENCE_ROLE ANNOUNCE_ROLE ACTIVATE_TASK CHECK_SERVING ANNOUNCE_ROLE' & p2~steps[3]~mu == 'us1', p2~kinds p2~steps[3]~mu
runner~run(p2, 'ldap-b', 200)
call check 'second failure: live daemons hold epoch 3, main uk2, spare us1', world~daemon('us1')~record~epoch = 3 & world~daemon('us1')~record~main == 'uk2' & world~daemon('us1')~record~spare == 'us1', world~daemon('us1')~record~canonical
call check 'sleeper: its file still names the dead uk1 and au1', world~daemon('us2')~record~main == 'uk1' & world~daemon('us2')~record~spare == 'au1', ''
src = world~wake('us2')
call check 'sleeper wakes: main and spare in its file are both gone, a seed answers, epoch 3 adopted', src \== 'NO_ROLE_SOURCE' & world~daemon('us2')~record~epoch = 3 & world~daemon('us2')~record~main == 'uk2', src
call check 'sleeper: lookups FRESH through uk2', world~daemon('us2')~lookup('svc.x')[1] == 'FRESH', ''

/* No source at all: an honest failure. */
lonely = .XtpDaemonSim~new('zz9', world, .RoleRecord~new('LDAP', 'uk1', 'au1', 1, 1, .Array~of('uk1', 'au1'), .Array~of('K-role-1')), 'K-role-1', 'SUM0')
call check 'no source: main, spare and every seed are gone - NO_ROLE_SOURCE, file kept', lonely~start == 'NO_ROLE_SOURCE' & lonely~record~epoch = 1, lonely~lastSource

/* ---- 6. Locking the authority stops role changes; unlocking and resuming finishes ---- */
w = buildWorld(); c = w['CLUSTER']; world = w['WORLD']
world~kill('uk1')
world~authority~lock('K-role-1')
plan = c~muDown('uk1', 100)
call SysMkDir scratch'/locked'
runner = .PlanRunner~new(scratch'/locked', c, world, quietService(), .array~of('quiet'))
msg = runUntilError(runner, plan, 'ldap-L')
call check 'locked: the announcement is refused at signing (AUTH_LOCKED)', msg~pos('AUTH_LOCKED') > 0, msg
call check 'locked: no daemon file changed', world~daemon('us1')~record~epoch = 1 & world~daemon('us1')~record~main == 'uk1', world~daemon('us1')~record~canonical
call check 'locked: the fence (step 1) is done; the announcement (step 2) is in the journal as begun, not done', journalHas(scratch'/locked', 'DONE|ldap-L|1|') & journalHas(scratch'/locked', 'BEGIN|ldap-L|2|') & \journalHas(scratch'/locked', 'DONE|ldap-L|2|'), ''
world~authority~unlock('K-role-1')
c2 = .ClusterArbitrator~new
runner2 = .PlanRunner~new(scratch'/locked', c2, world, quietService(), .array~of('quiet'))
call check 'unlocked: a fresh arbitrator resumes the plan from the journal', runner2~resume(100), ''
call check 'unlocked: every live daemon now holds epoch 2, main au1, spare uk2', world~daemon('us1')~record~epoch = 2 & world~daemon('us1')~record~main == 'au1' & world~daemon('us1')~record~spare == 'uk2', world~daemon('us1')~record~canonical
call check 'unlocked: each step performed exactly once', onceEach(world, 'ldap-L', plan~planned~items), ''

/* ---- 7. Text form keeps selfRouting ---- */
w = buildWorld()
c3 = .ClusterArbitrator~new~restoreFromLines(w['CLUSTER']~snapshotLines)
call check 'text: a restored cluster still announces LDAP role moves', c3~muDown('uk1', 1)~kinds~pos('ANNOUNCE_ROLE') > 0, ''

say
say 'TOTAL' pass 'passed,' fail 'failed'
if fail > 0 then exit 1
exit 0

check: procedure expose pass fail
  use arg name, ok, detail
  if ok == 1 then do; pass += 1; say 'PASS' name; end
  else do; fail += 1; say 'FAIL' name '['detail']'; end
  return

::routine buildWorld
  c = .ClusterArbitrator~new
  ids = .Array~of('uk1 UK 213.255.246.44', 'au1 AU 203.0.113.10', 'us1 US 198.51.100.20', 'uk2 UK 192.0.2.7', 'us2 US 198.51.100.21')
  do x over ids
    parse var x id zone addr
    c~addMu(id, zone, .MachineArbitrator~new(.MachineState~new(4096, 512, 20000, 50000)), addr)
  end
  c~addPair(.RolePair~new('LDAP', .Demand~new('ldap', 95, 512), .true), 'uk1', 'au1')
  do m over .Array~of('uk1', 'au1')
    arb = c~mu(m)
    do s over arb~plan(c~held(m), 0)~planned; arb~completed(s, 0); end
  end
  auth = .RoleAuthority~new~addKey('K-role-1', 'held in the su-locked account')
  world = .RoleWorld~new(auth, 'K-role-1')
  do x over ids; parse var x id .; world~addMu(id, c~mu(id)~state~copy); end
  world~bootstrap('LDAP', 'uk1', 'au1', .Array~of('uk1', 'au1', 'us1', 'uk2', 'us2'))
  world~setRoute('svc.x', 'us1')
  r = .Directory~new; r['CLUSTER'] = c; r['WORLD'] = world
  return r

::routine quietService
  s = .LogService~new('arb-test5')
  s~addTarget(.LogMemoryTarget~new('quiet', .Log~INTERNAL))
  return s

::routine runUntilError
  use arg runner, plan, id
  signal on syntax name failed
  runner~run(plan, id, 100)
  return 'no error'
failed:
  return condition('O')~message

::routine journalHas
  use arg dir, fragment
  s = .stream~new(dir'/journal.log'); s~open('read')
  found = .false
  do while s~lines > 0; if s~linein~pos(fragment) > 0 then found = .true; end
  s~close
  return found

::routine onceEach
  use arg world, id, n
  do i = 1 to n; if world~timesPerformed(id':'i) \= 1 then return .false; end
  return .true

::requires '../src/RoleBootstrap.cls'
