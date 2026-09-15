root = "/mnt/data/queuerexx-dev11-managed-placement"
address system "rm -rf " || root
call SysMkDir root
do dir over .Array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs","locks")
  call SysMkDir root || "/" || dir
end
call SysMkDir root || "/locks/state"

if .MigratableJobPlacementContract~API \= "migratable.job.placement/1" then call fail "wrong managed placement contract"
if .MigratableJobStartContract~API \= "migratable.job.start/1" then call fail "wrong starter contract"

/* Normal path: managed placement owns allocation/check/start composition, while
 * QueueRexx contributes only policy + shared QID state fencing at runtime entry. */
qid = "JOB-MANAGED-024"
call writeRunning root, qid
registry = .NodeCapabilityRegistry~new
cap = .NodeCapabilityStatement~new("NODE-A", 1)
obs = .NodeCapacityObservation~new("NODE-A", 1, 7, 1000, 10000, 4096, 4096, 4, 2000000, 0, 0)
if \registry~advertiseCapability(cap) then call fail "capability advertise"
if \registry~observeCapacity(obs) then call fail "capacity observe"
ownership = .JobNodeOwnershipRegistry~new
eligibility = .JobNodeEligibilityPolicy~new
allocator = .JobNodeAllocator~new(registry, eligibility, .nil, .nil, .nil, "QRX-MJ-024", .nil, ownership)

reqs = .JobNodeRequirement~new
placement = .JobPlacementRequest~new(qid, reqs, "OWNER", 1000, 1000)
definition = .MigratableJobDefinition~new(qid, placement, "definition:qrx-managed", "PART-A", "OWNER", "OOREXX", "5.3-r13196", "rev-managed")
app = .ManagedStartApp~new(definition, root)
digest = .ManagedDigest~new
receiptStore = .MigratableJobStartReceiptStore~new(root || "/start.receipts", digest)
starter = .MigratableJobStarter~new(app, receiptStore)
intentStore = .QueueRexxMigratableStartIntentStore~new(root)
executor = .QueueRexxPlacedStartExecutor~new(starter, app, allocator, root, .AllowPolicy~new, .nil, intentStore)
audit = .MigratableJobPlacementAuditStore~new(root || "/placement.receipts", digest)
tool = .MigratableJobManagedPlacementTool~new(app, allocator, registry, eligibility, .nil, executor, audit, digest)
managed = .QueueRexxManagedPlacementFacade~new(tool, intentStore)
request = .MigratableJobStartRequest~new("START-MANAGED-1", "NEW", qid, definition~definitionRef, definition~partitionId, "", 1001)

plan = managed~plan(request, 1001, "op-plan")
if \plan~ok | plan~code \= "PLAN_READY" then call fail "managed plan"
if plan~plan~recommendedNodeId \= "NODE-A" then call fail "managed plan recommendation"
allocated = managed~allocate(request, 1001, 3000, "op-allocate")
if \allocated~ok | allocated~code \= "PLACED" | allocated~lease == .nil then call fail "managed allocate"
lease = allocated~lease

/* A fresh QueueRexx store instance reconstructs the exact NEW request without
 * retaining the raw JobPlacementRequest. Re-allocation is answered by upstream
 * v0.2.4 as PLACED_REPLAY against Job-to-Node's current lease. */
restartIntent = .QueueRexxMigratableStartIntentStore~new(root)
loaded = restartIntent~load(qid)
if \loaded~valid | loaded~request == .nil then call fail "durable start-intent reload"
if loaded~request~canonical \= request~canonical then call fail "durable start-intent changed request"
restartManaged = .QueueRexxManagedPlacementFacade~new(tool, restartIntent)
realloc = restartManaged~allocate(loaded~request, 1002, 3000, "op-reallocate")
if \realloc~ok | realloc~code \= "PLACED_REPLAY" then call fail "managed allocation replay " || realloc~code
if realloc~lease~placementId \= lease~placementId | realloc~lease~ownershipEpoch \= lease~ownershipEpoch then call fail "allocation replay changed ownership"

sameSaved = intentStore~persist(request)
if \sameSaved~valid | sameSaved~code \= .QueueMigratableStartIntentCode~STORED then call fail "exact durable start-intent retry was not idempotent"
changedIntent = .MigratableJobStartRequest~new("START-MANAGED-DIFFERENT", "NEW", qid, definition~definitionRef, definition~partitionId, "", 1002)
changedSaved = intentStore~persist(changedIntent)
if changedSaved~valid | changedSaved~code \= .QueueMigratableStartIntentCode~REQUEST_MISMATCH then call fail "different durable start-intent overwrote original"
reloadedOriginal = intentStore~load(qid)
if \reloadedOriginal~valid | reloadedOriginal~request~canonical \= request~canonical then call fail "original durable start-intent was replaced"
changedStart = managed~start(changedIntent, lease, 1002, "op-intent-conflict")
if changedStart~ok | changedStart~code \= "QUEUEREXX_START_INTENT_INVALID" then call fail "durable start-intent mismatch not rejected"

checked = managed~check(request, lease, 1002, "op-check")
if \checked~ok | checked~code \= "PLACEMENT_CURRENT" then call fail "managed check"

started = managed~start(request, lease, 1003, "op-start")
if \started~ok | started~code \= "RUNNING" then call fail "managed start " || started~code || ":" || started~detail
if started~startResult == .nil | \started~startResult~ok then call fail "managed start result missing"
if app~starts \= 1 then call fail "workload start count"
if \app~sawLock then call fail "QueueRexx QID lock not held at workload entry"

replayed = managed~start(request, lease, 1004, "op-replay")
if \replayed~ok | replayed~code \= "RUNNING" then call fail "managed replay"
if replayed~startResult == .nil | \replayed~startResult~replayed then call fail "standard starter replay not preserved"
if app~starts \= 1 then call fail "managed replay duplicated runtime start"
if \audit~verify then call fail "managed placement audit verification"

/* Race proof: outer v0.2.4 START verification succeeds, then policy evaluation
 * advances the node capacity generation before QueueRexx's launch-boundary
 * verification. Runtime entry must be refused and placement must remain held. */
raceRoot = root || "/race"
call SysMkDir raceRoot
do dir over .Array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs","locks")
  call SysMkDir raceRoot || "/" || dir
end
call SysMkDir raceRoot || "/locks/state"
qid2 = "JOB-MANAGED-RACE"
call writeRunning raceRoot, qid2
registry2 = .NodeCapabilityRegistry~new
cap2 = .NodeCapabilityStatement~new("NODE-RACE", 1)
obs2 = .NodeCapacityObservation~new("NODE-RACE", 1, 20, 2000, 10000, 4096, 4096, 4, 2000000, 0, 0)
registry2~advertiseCapability(cap2); registry2~observeCapacity(obs2)
ownership2 = .JobNodeOwnershipRegistry~new
eligibility2 = .JobNodeEligibilityPolicy~new
allocator2 = .JobNodeAllocator~new(registry2, eligibility2, .nil, .nil, .nil, "QRX-MJ-024", .nil, ownership2)
placement2 = .JobPlacementRequest~new(qid2, .JobNodeRequirement~new, "OWNER", 1000, 1000)
definition2 = .MigratableJobDefinition~new(qid2, placement2, "definition:qrx-race", "PART-B", "OWNER", "OOREXX", "5.3-r13196", "rev-race")
app2 = .ManagedStartApp~new(definition2, raceRoot)
store2 = .MigratableJobStartReceiptStore~new(raceRoot || "/start.receipts", digest)
starter2 = .MigratableJobStarter~new(app2, store2)
driftPolicy = .DriftPolicy~new(registry2)
intentStore2 = .QueueRexxMigratableStartIntentStore~new(raceRoot)
executor2 = .QueueRexxPlacedStartExecutor~new(starter2, app2, allocator2, raceRoot, driftPolicy, .nil, intentStore2)
tool2 = .MigratableJobManagedPlacementTool~new(app2, allocator2, registry2, eligibility2, .nil, executor2, .nil, digest)
managed2 = .QueueRexxManagedPlacementFacade~new(tool2, intentStore2)
request2 = .MigratableJobStartRequest~new("START-RACE-1", "NEW", qid2, definition2~definitionRef, definition2~partitionId, "", 2001)
allocated2 = managed2~allocate(request2, 2001, 3000, "race-allocate")
if \allocated2~ok then call fail "race allocation"
raced = managed2~start(request2, allocated2~lease, 2002, "race-start")
if raced~ok then call fail "launch-boundary placement race was accepted"
if raced~code \= "START_FAILED_PLACEMENT_HELD" then call fail "unexpected race code " || raced~code
if raced~startResult == .nil then call fail "race start result missing"
if raced~startResult~code \= "PLACEMENT_INVALID_AT_LAUNCH" then call fail "launch boundary did not identify stale placement"
if app2~starts \= 0 then call fail "stale placement reached runtime"
if \raced~placementHeld then call fail "failed start did not retain placement"

released = managed2~release(request2, allocated2~lease, 2003, "race-release", "test-established-no-runtime")
if \released~ok | released~code \= "RELEASED" | released~placementHeld then call fail "explicit release after failed start"

/* Queue authority remains a separate final fence even with a current lease.
 * Use a fresh QID so write-once durable intent is not weakened merely to create
 * the terminal-state fixture. */
qid3 = "JOB-MANAGED-TERMINAL"
call writeRunning root, qid3
placement3 = .JobPlacementRequest~new(qid3, .JobNodeRequirement~new, "OWNER", 1000, 1000)
definition3 = .MigratableJobDefinition~new(qid3, placement3, "definition:qrx-terminal", "PART-C", "OWNER", "OOREXX", "5.3-r13196", "rev-terminal")
app3 = .ManagedStartApp~new(definition3, root)
starter3 = .MigratableJobStarter~new(app3, receiptStore)
executor3 = .QueueRexxPlacedStartExecutor~new(starter3, app3, allocator, root, .AllowPolicy~new, .nil, intentStore)
tool3 = .MigratableJobManagedPlacementTool~new(app3, allocator, registry, eligibility, .nil, executor3, audit, digest)
managed3 = .QueueRexxManagedPlacementFacade~new(tool3, intentStore)
blockedRequest = .MigratableJobStartRequest~new("START-MANAGED-TERMINAL", "NEW", qid3, definition3~definitionRef, definition3~partitionId, "", 1005)
blockedAllocation = managed3~allocate(blockedRequest, 1005, 3000, "op-terminal-allocate")
if \blockedAllocation~ok then call fail "terminal fixture allocation"
move = .QueueTransitionService~new(root)~transition(qid3, .QueueState~RUNNING, .QueueState~CANCELLED, .QueueEvent~JOB_CANCELLED)
if \move~ok then call fail "terminal queue fixture"
blocked = managed3~start(blockedRequest, blockedAllocation~lease, 1006, "op-terminal")
if blocked~ok then call fail "terminal queue authority permitted placed start"
if blocked~startResult == .nil then call fail "terminal denial start result missing"
if blocked~startResult~code \= "QUEUE_AUTHORITY_queue_state_not_running" then call fail "unexpected terminal denial " || blocked~startResult~code
if app3~starts \= 0 then call fail "terminal denial reached workload"

say "PASS Migratable Job v0.2.4 managed placement: write-once durable NEW intent, PLACED_REPLAY restart, Job-to-Node allocation/check, QueueRexx final QID+policy+lease fence, starter replay, race rejection, held-placement failure and explicit release"
exit 0

writeRunning: procedure
  use arg root, qid
  p = root || "/running/" || qid || ".job"
  s = .Stream~new(p)
  if s~open("WRITE REPLACE") \= "READY:" then return .false
  s~lineOut("JOB_ID='" || qid || "'")
  s~lineOut("JOB_NAME='managed placement test'")
  s~lineOut("JOB_CLASS='DEFAULT'")
  s~lineOut("PRIORITY='10'")
  s~lineOut("COMMAND=('sleep' '100')")
  s~lineOut("RUNNER_USED='direct'")
  s~close
  return .true

fail: procedure
  parse arg message
  say "FAIL" message
  exit 1

::class ManagedStartApp subclass MigratableJobStarterApplication
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

::class AllowPolicy subclass QueueOperationPolicyGate
::method assessExecution
  use strict arg record
  return .QueuePolicyVerdict~allow("TEST_ALLOW")

::class DriftPolicy subclass QueueOperationPolicyGate
::method init
  expose registry fired
  use strict arg registryArg
  registry = registryArg; fired = .false
::method assessExecution
  expose registry fired
  use strict arg record
  if \fired then do
    fired = .true
    changed = .NodeCapacityObservation~new("NODE-RACE", 1, 21, 2002, 10000, 4096, 4096, 4, 2000000, 0, 0)
    registry~observeCapacity(changed)
  end
  return .QueuePolicyVerdict~allow("TEST_ALLOW_AFTER_DRIFT")

::class ManagedDigest public
::method digest
  use strict arg text
  return c2x(text~string)

::requires "QueueRexxMigratableJob.cls"
::requires "JobNodeLiveness.cls"
