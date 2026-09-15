root = "/mnt/data/queuerexx-dev11-durable-placement-restart"
address system "rm -rf " || root
call SysMkDir root
do dir over .Array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs","locks")
  call SysMkDir root || "/" || dir
end
call SysMkDir root || "/locks/state"

qid = "JOB-MANAGED-DURABLE-024"
call writeRunning root, qid

registry = .NodeCapabilityRegistry~new
cap = .NodeCapabilityStatement~new("NODE-DURABLE", 1)
obs = .NodeCapacityObservation~new("NODE-DURABLE", 1, 5, 1000, 20000, 4096, 4096, 4, 2000000, 0, 0)
if \registry~advertiseCapability(cap) then call fail "capability advertise"
if \registry~observeCapacity(obs) then call fail "capacity observe"
eligibility = .JobNodeEligibilityPolicy~new
placement = .JobPlacementRequest~new(qid, .JobNodeRequirement~new, "OWNER", 1000, 1000)
definition = .MigratableJobDefinition~new(qid, placement, "definition:qrx-durable", "PART-D", "OWNER", "OOREXX", "5.3-r13196", "rev-durable")
digest = .DurableDigest~new

/* First process generation: restore even on an empty journal, then allocate.
 * QueueRexx refuses durable mutation before that restore pass. */
own1 = .JobNodeOwnershipRegistry~new
raw1 = .JobNodeAllocator~new(registry, eligibility, .nil, .nil, .nil, "QRX-DURABLE-1", .nil, own1)
durable1 = .QueueDurableJobNodeAllocator~new(raw1, own1, root)
premature = durable1~allocate(placement, 1000, 5000)
if premature~placed | premature~code \= "DURABLE_RESTORE_REQUIRED" then call fail "durable allocator mutated before restore"
rr1 = durable1~restore(1000)
if \rr1~ok | rr1~restored \= 0 then call fail "empty durable restore"

app1 = .DurableStartApp~new(definition, root)
receipts1 = .MigratableJobStartReceiptStore~new(root || "/start.receipts", digest)
starter1 = .MigratableJobStarter~new(app1, receipts1)
intent1 = .QueueRexxMigratableStartIntentStore~new(root)
executor1 = .QueueRexxPlacedStartExecutor~new(starter1, app1, durable1, root, .AllowPolicy~new, .nil, intent1)
tool1 = .MigratableJobManagedPlacementTool~new(app1, durable1, registry, eligibility, .nil, executor1, .nil, digest)
managed1 = .QueueRexxManagedPlacementFacade~new(tool1, intent1)
request = .MigratableJobStartRequest~new("START-DURABLE-1", "NEW", qid, definition~definitionRef, definition~partitionId, "", 1001)
placed1 = managed1~allocate(request, 1001, 5000, "first-allocate")
if \placed1~ok | placed1~code \= "PLACED" then call fail "initial durable managed allocation " || placed1~code
lease1 = placed1~lease
if lease1~ownershipEpoch \= 1 then call fail "initial ownership epoch"
if \SysFileExists(durable1~journalPath) then call fail "durable placement journal missing"

/* Second process generation: no reuse of raw allocator, ownership registry,
 * managed tool, application or QueueRexx intent-store object. */
own2 = .JobNodeOwnershipRegistry~new
raw2 = .JobNodeAllocator~new(registry, eligibility, .nil, .nil, .nil, "QRX-DURABLE-1", .nil, own2)
durable2 = .QueueDurableJobNodeAllocator~new(raw2, own2, root)
rr2 = durable2~restore(1200)
if \rr2~ok | rr2~restored \= 1 | rr2~blocked \= 0 then call fail "durable placement restore"
if own2~epochFor(qid) \= 1 then call fail "ownership epoch not restored"
if durable2~sequenceValue \= 1 then call fail "allocator sequence not restored"
if \durable2~verifyLease(lease1, placement, 1200) then call fail "restored lease does not verify"

app2 = .DurableStartApp~new(definition, root)
receipts2 = .MigratableJobStartReceiptStore~new(root || "/start.receipts", digest)
starter2 = .MigratableJobStarter~new(app2, receipts2)
intent2 = .QueueRexxMigratableStartIntentStore~new(root)
loaded = intent2~load(qid)
if \loaded~valid | loaded~request == .nil | loaded~request~canonical \= request~canonical then call fail "durable QueueRexx NEW intent not reconstructed"
executor2 = .QueueRexxPlacedStartExecutor~new(starter2, app2, durable2, root, .AllowPolicy~new, .nil, intent2)
tool2 = .MigratableJobManagedPlacementTool~new(app2, durable2, registry, eligibility, .nil, executor2, .nil, digest)
managed2 = .QueueRexxManagedPlacementFacade~new(tool2, intent2)
replayedPlacement = managed2~allocate(loaded~request, 1201, 5000, "restart-allocate")
if \replayedPlacement~ok | replayedPlacement~code \= "PLACED_REPLAY" then call fail "restart did not return PLACED_REPLAY " || replayedPlacement~code
if replayedPlacement~lease~placementId \= lease1~placementId | replayedPlacement~lease~ownershipEpoch \= 1 then call fail "restart minted different placement authority"
started = managed2~start(loaded~request, replayedPlacement~lease, 1202, "restart-start")
if \started~ok | started~code \= "RUNNING" then call fail "restart start failed " || started~code
if app2~starts \= 1 | \app2~sawLock then call fail "restart start did not enter exactly once under QID lock"

/* Third process generation: restore the same placement again and call the
 * exact same start. The standard starter receipt must suppress a second
 * workload entry even though all QueueRexx/JTN objects were reconstructed. */
own3 = .JobNodeOwnershipRegistry~new
raw3 = .JobNodeAllocator~new(registry, eligibility, .nil, .nil, .nil, "QRX-DURABLE-1", .nil, own3)
durable3 = .QueueDurableJobNodeAllocator~new(raw3, own3, root)
rr3 = durable3~restore(1300)
if \rr3~ok | rr3~restored \= 1 then call fail "second durable restore"
app3 = .DurableStartApp~new(definition, root)
starter3 = .MigratableJobStarter~new(app3, .MigratableJobStartReceiptStore~new(root || "/start.receipts", digest))
intent3 = .QueueRexxMigratableStartIntentStore~new(root)
executor3 = .QueueRexxPlacedStartExecutor~new(starter3, app3, durable3, root, .AllowPolicy~new, .nil, intent3)
tool3 = .MigratableJobManagedPlacementTool~new(app3, durable3, registry, eligibility, .nil, executor3, .nil, digest)
managed3 = .QueueRexxManagedPlacementFacade~new(tool3, intent3)
retryPlacement = managed3~allocate(intent3~load(qid)~request, 1301, 5000, "restart2-allocate")
if \retryPlacement~ok | retryPlacement~code \= "PLACED_REPLAY" then call fail "second placement replay"
retryStart = managed3~start(request, retryPlacement~lease, 1302, "restart2-start")
if \retryStart~ok | retryStart~startResult == .nil | \retryStart~startResult~replayed then call fail "starter replay after full reconstruction"
if app3~starts \= 0 then call fail "starter replay launched a second runtime"
if own3~epochFor(qid) \= 1 | durable3~sequenceValue \= 1 then call fail "restart advanced placement authority"

/* Explicit release is itself durable. A fourth restore must not resurrect the
 * old owner. */
released = managed3~release(request, retryPlacement~lease, 1303, "release", "qualification cleanup")
if \released~ok | released~code \= "RELEASED" | released~placementHeld then call fail "durable release"
own4 = .JobNodeOwnershipRegistry~new
raw4 = .JobNodeAllocator~new(registry, eligibility, .nil, .nil, .nil, "QRX-DURABLE-1", .nil, own4)
durable4 = .QueueDurableJobNodeAllocator~new(raw4, own4, root)
rr4 = durable4~restore(1400)
if \rr4~ok | rr4~restored \= 0 then call fail "released placement resurrected"
if own4~current(qid, 1400) \= .nil then call fail "released ownership restored as current"

/* A later corrupt committed snapshot must fail closed rather than falling back
 * to the earlier clean state or permitting fresh mutation. */
js = .Stream~new(durable4~journalPath); js~open("WRITE APPEND")
js~lineOut("BEGIN|999|999"); js~lineOut("COMMIT|999|BAD|"); js~close
own5 = .JobNodeOwnershipRegistry~new
raw5 = .JobNodeAllocator~new(registry, eligibility, .nil, .nil, .nil, "QRX-DURABLE-1", .nil, own5)
durable5 = .QueueDurableJobNodeAllocator~new(raw5, own5, root)
rr5 = durable5~restore(1500)
if rr5~ok | rr5~code \= "DURABLE_JOURNAL_INTEGRITY_FAILED" then call fail "corrupt durable journal did not fail closed"
if durable5~ready then call fail "corrupt durable restore marked allocator ready"
blocked = durable5~allocate(placement, 1501, 5000)
if blocked~placed | blocked~code \= "DURABLE_RESTORE_REQUIRED" then call fail "mutation allowed after corrupt restore"
if own5~current(qid, 1501) \= .nil then call fail "corrupt restore resurrected owner"

say "PASS QueueRexx + Migratable Job v0.2.4 + Job-to-Node v0.6 durable NEW placement: restore-required, ownership/sequence recovery, exact intent replay, PLACED_REPLAY, one runtime start, starter replay, durable release and corrupt-journal fail-closed"
exit 0

writeRunning: procedure
  use arg root, qid
  p = root || "/running/" || qid || ".job"
  s = .Stream~new(p)
  if s~open("WRITE REPLACE") \= "READY:" then return .false
  s~lineOut("JOB_ID='" || qid || "'")
  s~lineOut("JOB_NAME='durable managed placement test'")
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

::class DurableStartApp subclass MigratableJobStarterApplication
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

::class DurableDigest public
::method digest
  use strict arg text
  return c2x(text~string)

::requires "QueueRexxMigratableJob.cls"
::requires "QueueRexxJobNodeDurable.cls"
