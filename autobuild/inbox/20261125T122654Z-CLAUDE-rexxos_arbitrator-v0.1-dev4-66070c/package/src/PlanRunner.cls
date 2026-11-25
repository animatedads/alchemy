/* rexxos_arbitrator v0.1-dev4: carrying out a plan so that a pulled plug
   loses nothing.
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).

   Tom Dyer, 2026-11-25: the lab manager would pull the circuit breaker
   about 45 minutes before an exam or essay was due.  If you had not saved
   your work and planned your recovery, it was on you.

   The PlanRunner carries out a plan step by step through an effector (the
   real machine or cluster later; a SimulatedEffector or SimulatedCluster
   now) and keeps a journal and snapshots, so that after a pulled plug a new runner
   resumes where the old one stopped and does nothing twice:

     PLAN, DEMAND and STEP records     the whole plan, before the first step
     snapshot through PLAN:0           the record as the plan begins (dev4)
     BEGIN i                           written before step i is attempted
     (the effector performs step i)
     snapshot n                        the ledger with step i applied, and
                                       the step it is applied through
     DONE i                            written after the snapshot
     END                               the plan is finished

   On resume, a step with BEGIN and no DONE is in doubt.  The effector is
   asked whether its effect is present; the snapshot says whether the
   ledger already has it.  So the step is performed again only if it did
   not happen, and applied to the ledger only if the ledger lacks it.

   A record is one line ending '|END'; a line torn by the power cut lacks
   it and is ignored.  A snapshot is a new numbered file ending 'END'; the
   newest complete one wins, so nothing is overwritten in place.

   Every BEGIN, DONE, RESUME and IN-DOUBT goes through the estate's logging
   framework (oorexx_logging v0.7) so the run is never a black box.  The
   files live in a directory standing in for the Storage Fabric.

   dev4: the owner is a MachineArbitrator (machine plans) or a
   ClusterArbitrator (cluster and recovery plans).  Either answers
   completed(step, now), snapshotLines and restoreFromLines. */

::requires 'ClusterArbitrator.cls'
::requires 'LoggingCore.cls'

/* ------------------------------------------------------------------ */
/* A log target that keeps events and prints each as one progress line. */
::class LogLineTarget public subclass LogMemoryTarget
::method init
  expose out
  use strict arg name = 'progress', scopeValue = 'INTERNAL', out = .stdout
  self~init:super(name, scopeValue)
::method accept
  expose out
  use strict arg event
  if \self~accept:super(event) then return .false
  out~lineout('  [log' event~levelName']' event~payload)
  return .true

/* ------------------------------------------------------------------ */
/* Stands in for a machine.  It keeps its own state, remembers which steps
   it performed, and can pull the breaker at a chosen step and phase. */
::class SimulatedEffector public
::method init
  expose state performed breakAt breakPhase
  use strict arg state
  performed = .Directory~new       /* plan:step -> count */
  breakAt = 0; breakPhase = ''
::attribute state get
/* phase: BEFORE_PERFORM, AFTER_PERFORM or AFTER_SNAPSHOT. */
::method armBreaker
  expose breakAt breakPhase
  use strict arg breakAt, breakPhase
  if wordpos(breakPhase, 'BEFORE_PERFORM AFTER_PERFORM AFTER_SNAPSHOT') = 0 then raise syntax 93.900 array ('Unknown breaker phase' breakPhase)
  return self
::method breaker
  expose breakAt breakPhase
  use strict arg phase, n
  if n = breakAt & phase == breakPhase then do
    breakAt = 0
    raise syntax 93.900 array ('BREAKER pulled at step' n phase)
  end
  return self
::method perform
  expose state performed
  use strict arg step, key, now
  self~breaker('BEFORE_PERFORM', step~sequenceNo)
  state~apply(step, now)
  self~remember(key)
  self~breaker('AFTER_PERFORM', step~sequenceNo)
  return .true
::method remember
  expose performed
  use strict arg key
  if performed~hasIndex(key) then performed[key] += 1
  else performed[key] = 1
  return self
/* Is the effect of this step present?  A real effector looks at the
   machine; this one remembers what it did. */
::method effected
  expose performed
  use strict arg step, key
  return performed~hasIndex(key)
::method timesPerformed
  expose performed
  use strict arg key
  if performed~hasIndex(key) then return performed[key]
  return 0

/* ------------------------------------------------------------------ */
/* Stands in for a cluster: a machine per MU, the XTP route table, DNS and
   role epochs.  Like the SimulatedEffector it remembers what it did and
   can pull the breaker. */
::class SimulatedCluster public subclass SimulatedEffector
::method init
  expose machines routes dns epochs
  self~init:super(.MachineState~new(2, 1, 0))
  machines = .Directory~new; routes = .Directory~new; dns = .Directory~new; epochs = .Directory~new
::method addMachine
  expose machines
  use strict arg mu, state
  machines[mu] = state
  return self
::method machine
  expose machines
  use strict arg mu
  return machines[mu]
::method routes
  expose routes
  return routes
::method epochs
  expose epochs
  return epochs
::method setRoute
  expose routes
  use strict arg address, mu
  routes[address] = mu
  return self
::method perform
  expose machines routes epochs
  use strict arg step, key, now
  self~breaker('BEFORE_PERFORM', step~sequenceNo)
  k = step~kind
  select
    when wordpos(k, .ProvisionStep~kinds) > 0 & k \== 'ASK_CLUSTER' then do
      m = machines[step~mu]
      /* The target reads the saved state from the fabric; the source's goes to it. */
      if k == 'ACTIVATE_TASK' & \m~parked~hasIndex(step~demand~id) then m~park(step~demand)
      m~apply(step, now)
      if step~role == 'SOURCE' & k == 'DEACTIVATE_TASK' then m~unpark(step~demand~id)
    end
    when k == 'ROUTE_SERVICE' then routes[step~address] = step~mu
    when k == 'FENCE_ROLE' then do
      parse value step~address with name '.' .
      if epochs~hasIndex(name) then epochs[name] += 1
      else epochs[name] = 2
    end
    otherwise nop                                /* CHECK_SERVING, WAIT_DNS, REPOINT_DNS */
  end
  self~remember(key)
  self~breaker('AFTER_PERFORM', step~sequenceNo)
  return .true

/* ------------------------------------------------------------------ */
/* A step with its place in the plan, as the runner hands it on. */
::class JournalStep public
::method init
  expose step sequenceNo
  use strict arg step, sequenceNo
::attribute step get
::attribute sequenceNo get
::method string
  expose step
  return step~string
::method unknown
  expose step
  use strict arg name, args
  forward to (step) message (name) arguments (args)

/* ------------------------------------------------------------------ */
::class PlanRunner public
::method init
  expose dir arb effector service logger seq snapNo
  use strict arg dir, arb, effector, service = .nil, targets = .nil
  if targets == .nil then targets = .array~of('progress')
  if \arb~isA(.MachineArbitrator) & \arb~isA(.ClusterArbitrator) then raise syntax 93.900 array ('PlanRunner needs a MachineArbitrator or a ClusterArbitrator')
  if \.File~new(dir)~isDirectory then raise syntax 93.900 array ('No journal directory' dir)
  if service == .nil then do
    service = .LogService~new('arbitrator-runner')
    service~addTarget(.LogLineTarget~new('progress', .Log~INTERNAL))
  end
  rule = .LogRule~new('arbitrator-runner-steps', 'rexxos_arbitrator', 'PLANRUNNER', 'STEP', .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .nil, targets, .array~of(.Log~BODY))
  service~addRule(rule)
  logger = service~loggerFor(self, 'STEP', .array~new, .Log~INTERNAL)
  call endTornLine dir'/journal.log'
  seq = lastSequence(dir)
  snapNo = lastSnapshotNo(dir)
::attribute arb get
::method journalPath
  expose dir
  return dir'/journal.log'

/* Carry out every PLANNED step of a plan, journalled. */
::method run
  expose dir
  use strict arg plan, planId, now
  if verify(planId, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.') > 0 | planId == '' then
    raise syntax 93.900 array ('Plan id must be letters, digits, - _ .')
  steps = plan~planned
  demands = .Directory~new
  do st over steps; if st~demand \== .nil then demands[st~demand~id] = st~demand; end
  self~record('PLAN', planId, steps~items, plan~approvalClass)
  do id over demands~allIndexes~sort; self~record('DEMAND', planId, 0, demands[id]~toText); end
  do i = 1 to steps~items; self~record('STEP', planId, i, steps[i]~toText); end
  self~snapshot(planId':0')                  /* the record as the plan begins */
  self~progress('plan' planId':' steps~items 'steps (' || plan~approvalClass || ')')
  self~carryOut(planId, steps, 1, now)
  return self

/* After a pulled plug: finish the last unfinished plan in the journal. */
::method resume
  expose arb
  use strict arg now
  j = self~readJournal
  if j['PLAN'] == '' then do
    self~progress('resume: nothing unfinished in the journal')
    return .false
  end
  planId = j['PLAN']; steps = j['STEPS']; done = j['DONE']; begun = j['BEGUN']
  snap = self~latestSnapshot
  /* The ledger as of the newest complete snapshot. */
  if snap \== .nil then do
    arb~restoreFromLines(snap['LINES'])
    through = snap['THROUGH']
  end
  else through = ''
  self~progress('resume: plan' planId', ledger snapshot through' through', steps done' done~items 'of' steps~items)
  self~record('RESUME', planId, 0, 'through' through)
  next = 1
  do i = 1 to steps~items
    if done~hasIndex(i) then do; next = i + 1; iterate; end
    if begun~hasIndex(i) then do
      st = .JournalStep~new(steps[i], i)
      key = planId':'i
      happened = self~effectorEffected(st, key)
      inLedger = (through == key)
      self~progress('step' i st~string 'was in doubt: effect present' yn(happened)', in ledger' yn(inLedger))
      self~record('INDOUBT', planId, i, 'effect' yn(happened) 'ledger' yn(inLedger))
      if happened then do
        if \inLedger then do
          arb~completed(steps[i], now)
          self~snapshot(key)
        end
        self~record('DONE', planId, i, steps[i]~kind)
        next = i + 1
      end
      else next = i
      leave
    end
    next = i
    leave
  end
  self~carryOut(planId, steps, next, now)
  return .true

::method carryOut private
  expose arb effector
  use strict arg planId, steps, first, now
  do i = first to steps~items
    st = .JournalStep~new(steps[i], i)
    key = planId':'i
    self~record('BEGIN', planId, i, steps[i]~kind)
    self~progress('step' i'/'steps~items st~string 'begins:' steps[i]~cause)
    effector~perform(st, key, now)
    arb~completed(steps[i], now)
    self~snapshot(key)
    effector~breaker('AFTER_SNAPSHOT', i)
    self~record('DONE', planId, i, steps[i]~kind)
    self~progress('step' i'/'steps~items st~string 'done')
  end
  self~record('END', planId, steps~items, 'finished')
  self~progress('plan' planId 'finished')
  return

::method effectorEffected private
  expose effector
  use strict arg st, key
  return effector~effected(st, key)

/* One journal line, flushed before anything else happens. */
::method record private
  expose seq
  use strict arg type, planId, n, text
  seq += 1
  path = self~journalPath
  call lineout path, seq'|'type'|'planId'|'n'|'text'|END'
  call stream path, 'c', 'close'
  return

/* A new numbered snapshot file; the old ones are left until a newer one is complete. */
::method snapshot private
  expose dir arb snapNo
  use strict arg through
  snapNo += 1
  path = dir'/ledger.'right(snapNo, 6, '0')
  s = .stream~new(path)
  s~open('write replace')
  s~lineout('THROUGH|'through)
  do l over arb~snapshotLines; s~lineout(l); end
  s~lineout('END')
  s~close
  /* Keep the newest two. */
  old = dir'/ledger.'right(snapNo - 2, 6, '0')
  if snapNo > 2 then call SysFileDelete old
  return

::method latestSnapshot
  expose dir
  call SysFileTree dir'/ledger.*', 'f.', 'FO'
  names = .Array~new
  do i = 1 to f.0; names~append(f.i); end
  names = names~sort
  do i = names~items to 1 by -1
    lines = .Array~new
    s = .stream~new(names[i]); s~open('read')
    do while s~lines > 0; lines~append(s~linein); end
    s~close
    if lines~items < 3 then iterate
    if lines[lines~items] \== 'END' then iterate          /* torn by the power cut */
    parse value lines[1] with tag '|' through
    if tag \== 'THROUGH' then iterate
    r = .Directory~new; r['THROUGH'] = through
    body = .Array~new
    do k = 2 to lines~items - 1; body~append(lines[k]); end
    r['LINES'] = body
    return r
  end
  return .nil

/* The last plan without END: its steps, and which were begun and done. */
::method readJournal
  r = .Directory~new; r['PLAN'] = ''
  path = self~journalPath
  if \.File~new(path)~exists then return r
  s = .stream~new(path); s~open('read')
  plans = .Directory~new; order = .Array~new
  do while s~lines > 0
    line = s~linein
    if right(line, 4) \== '|END' then iterate                /* torn by the power cut */
    body = left(line, length(line) - 4)
    parse var body . '|' type '|' planId '|' n '|' text
    if \plans~hasIndex(planId) then do
      p = .Directory~new; p['DEMANDS'] = .Directory~new; p['STEPLINES'] = .Array~new
      p['BEGUN'] = .Directory~new; p['DONE'] = .Directory~new; p['ENDED'] = .false
      plans[planId] = p; order~append(planId)
    end
    p = plans[planId]
    select
      when type == 'DEMAND' then do; d = .Demand~fromText(text); p['DEMANDS'][d~id] = d; end
      when type == 'STEP'  then p['STEPLINES']~append(text)
      when type == 'BEGIN' then p['BEGUN'][n] = .true
      when type == 'DONE'  then p['DONE'][n] = .true
      when type == 'END'   then p['ENDED'] = .true
      otherwise nop
    end
  end
  s~close
  do i = order~items to 1 by -1
    p = plans[order[i]]
    if p['ENDED'] then leave
    steps = .Array~new
    do t over p['STEPLINES']
      if t~startsWith('CSTEP|') then steps~append(.ClusterStep~fromText(t, p['DEMANDS']))
      else steps~append(.ProvisionStep~fromText(t, p['DEMANDS']))
    end
    r['PLAN'] = order[i]; r['STEPS'] = steps; r['BEGUN'] = p['BEGUN']; r['DONE'] = p['DONE']
    leave
  end
  return r

::method progress private
  expose logger
  use strict arg text
  logger~log(.Log~INFO, text)
  return

::routine yn
  use strict arg b
  if b then return 'yes'
  return 'no'

/* A line torn by the power cut is left as it is (it lacks |END and is
   ignored), but the next record must start on a line of its own. */
::routine endTornLine
  use strict arg path
  if \.File~new(path)~exists then return
  n = chars(path)
  call stream path, 'c', 'close'
  if n = 0 then return
  last = charin(path, n, 1)
  call stream path, 'c', 'close'
  if last \== '0a'x then do
    call charout path, '0a'x
    call stream path, 'c', 'close'
  end
  return

::routine lastSequence
  use strict arg dir
  path = dir'/journal.log'
  if \.File~new(path)~exists then return 0
  n = 0
  s = .stream~new(path); s~open('read')
  do while s~lines > 0
    line = s~linein
    if right(line, 4) \== '|END' then iterate
    parse var line k '|' .
    if k~datatype('W') then n = max(n, k)
  end
  s~close
  return n

::routine lastSnapshotNo
  use strict arg dir
  call SysFileTree dir'/ledger.*', 'f.', 'FO'
  n = 0
  do i = 1 to f.0
    x = substr(f.i, lastpos('.', f.i) + 1)
    if x~datatype('W') then n = max(n, x)
  end
  return n
