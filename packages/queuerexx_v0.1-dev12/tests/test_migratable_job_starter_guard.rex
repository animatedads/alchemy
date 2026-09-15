root = "/mnt/data/queuerexx-dev10-starter-guard"
address system "rm -rf " || root
call SysMkDir root
call SysMkDir root || "/running"
call SysMkDir root || "/cancelled"
call SysMkDir root || "/logs"
call SysMkDir root || "/locks"
call SysMkDir root || "/locks/state"

if .MigratableJobStartContract~API \= "migratable.job.start/1" then call fail "wrong starter contract"

qid = "JOB-START-QRX"
call writeRunning root, qid
uk = .Array~of("GB")
reqs = .JobNodeRequirement~new(uk)
placement = .JobPlacementRequest~new(qid, reqs, "OWNER", 1000, 1000)
def = .MigratableJobDefinition~new(qid, placement, "definition:qrx-start", "PART-A", "OWNER", "OOREXX", "5.3-r13196", "rev-start")
app = .GuardStartApp~new(def, root)
guarded = .QueueRexxMigratableStarterApplication~new(app, root)
store = .MigratableJobStartReceiptStore~new(root || "/start.receipts", .GuardTestDigest~new)
starter = .MigratableJobStarter~new(guarded, store)
req = .MigratableJobStartRequest~new("START-QRX-1", "NEW", qid, def~definitionRef, def~partitionId, "", 1000)

r1 = starter~start(req)
if r1 == .nil | \r1~ok | r1~state \= .MigratableJobStartState~RUNNING then call fail "guarded NEW did not run"
if r1~executionRef \= "execution:START-QRX-1" then call fail "unexpected execution ref"
if app~starts \= 1 then call fail "NEW executor count"
if \app~sawLock then call fail "QID lock not held across NEW executor"

/* Durable start receipt owns replay.  The QueueRexx guard is not re-entered and
 * the workload executor is not called a second time. */
r2 = starter~start(req)
if \r2~ok | \r2~replayed then call fail "starter replay not recognised"
if app~starts \= 1 then call fail "durable replay duplicated NEW execution"

/* Once shared queue authority becomes terminal, a different startId cannot
 * launch the workload even though the upstream starter request itself is valid. */
move = .QueueTransitionService~new(root)~transition(qid, .QueueState~RUNNING, .QueueState~CANCELLED, .QueueEvent~JOB_CANCELLED)
if \move~ok then call fail "cancel fixture transition failed"
blocked = .MigratableJobStartRequest~new("START-QRX-2", "NEW", qid, def~definitionRef, def~partitionId, "", 1100)
r3 = starter~start(blocked)
if r3~ok then call fail "terminal queue authority permitted NEW start"
if r3~code \= "QUEUE_AUTHORITY_queue_state_not_running" then call fail "unexpected terminal denial " || r3~code
if app~starts \= 1 then call fail "blocked NEW reached workload executor"

/* Delegate exceptions must not strand the shared QID lock. */
qid2 = "JOB-START-THROW"
call writeRunning root, qid2
placement2 = .JobPlacementRequest~new(qid2, reqs, "OWNER", 1000, 1000)
def2 = .MigratableJobDefinition~new(qid2, placement2, "definition:qrx-throw", "PART-B", "OWNER", "OOREXX", "5.3-r13196", "rev-throw")
throwApp = .ThrowStartApp~new(def2)
throwGuard = .QueueRexxMigratableStarterApplication~new(throwApp, root)
throwStore = .MigratableJobStartReceiptStore~new(root || "/throw.receipts", .GuardTestDigest~new)
throwStarter = .MigratableJobStarter~new(throwGuard, throwStore)
throwReq = .MigratableJobStartRequest~new("START-THROW-1", "NEW", qid2, def2~definitionRef, def2~partitionId, "", 1200)
if \testExceptionRelease(root, qid2, throwStarter, throwReq) then call fail "NEW executor exception left QID lock behind"

say "PASS migratable.job.start/1 NEW is fenced by shared QID authority, durable replay remains upstream-owned, and exception paths release the lock"
exit 0

writeRunning: procedure
  use arg root, qid
  p = root || "/running/" || qid || ".job"
  s = .Stream~new(p)
  if s~open("WRITE REPLACE") \= "READY:" then return .false
  s~lineOut("JOB_ID='" || qid || "'")
  s~lineOut("JOB_NAME='starter guard'")
  s~lineOut("JOB_CLASS='DEFAULT'")
  s~lineOut("PRIORITY='10'")
  s~lineOut("COMMAND=('sleep' '100')")
  s~lineOut("RUNNER_USED='direct'")
  s~close
  return .true

testExceptionRelease: procedure
  use arg root, qid, starter, request
  signal on syntax name caughtException
  ignore = starter~start(request)
  signal off syntax
  return .false
caughtException:
  signal off syntax
  return \SysFileExists(root || "/locks/state/" || qid || ".lock")

fail: procedure
  parse arg message
  say "FAIL" message
  exit 1

::class GuardStartApp subclass MigratableJobStarterApplication
::attribute starts
::attribute sawLock
::method init
  expose definitionObject root starts sawLock
  use strict arg definitionArg, rootArg
  definitionObject = definitionArg; root = rootArg~string; starts = 0; sawLock = .false
::method definition
  expose definitionObject
  use strict arg request
  return definitionObject
::method startNew
  expose root starts sawLock
  use strict arg request, definition
  starts += 1
  sawLock = SysFileExists(root || "/locks/state/" || definition~jobId || ".lock")
  return .MigratableJobResumeResult~success("execution:" || request~startId)

::class ThrowStartApp subclass MigratableJobStarterApplication
::method init
  expose definitionObject
  use strict arg definitionArg
  definitionObject = definitionArg
::method definition
  expose definitionObject
  use strict arg request
  return definitionObject
::method startNew
  raise syntax 88.900 array("intentional starter workload failure")

::class GuardTestDigest public
::method digest
  use strict arg text
  return c2x(text~string)

::requires "QueueRexxMigratableJob.cls"
