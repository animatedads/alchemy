root = "/mnt/data/queuerexx-dev8-wlu-lifecycle-test"
address system "rm -rf " || root
call SysMkDir root
do dir over .array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs")
  call SysMkDir root || "/" || dir
end

keys = .WLUFastMacKeyRing~new
keys~addKey("k1", "00112233445566778899aabbccddeeff")
clock = .WLUTestTimeSource~new(1000000)
ledger = .WLUMemoryLedger~new
authority = .WLUAuthority~new(keys, ledger, clock)
account = .WLUAccount~new("acct", 50000000)
pool = .WLUThroughputPool~new("pool", 5000000)
authority~addAccount(account)
authority~addThroughputPool(pool)
authority~bindAccount("QTEST", "BUILD*", "acct")
authority~bindThroughputPool("QTEST", "BUILD*", "pool")
admission = .QueueJobNodeWLUAdmission~new(authority, root)
journal = .QueueWLULifecycleJournal~new(root)

/* Complete: reservation -> activation -> measured consumption -> settlement. */
setup = makeJob(root, "complete")
record = .QueueStateStore~new(root)~findOne(setup~qid)
placed = reserveJob(admission, record, "nodeA", 11)
if \placed~admitted then call fail "complete admission denied " || placed~code
reservation = placed~reservation
binding = onlyBinding(journal, setup~qid)
if binding~reservationRef \= reservation~reservationId then call fail "durable binding reservation mismatch"
lease = makeLease(setup~qid, "nodeA", reservation~reservationId)
activation = .QueueWLUActivationService~new(root, authority, admission, journal)~activate(setup~qid, lease)
if \activation~ok then call fail "activation failed " || activation~detail
if .QueueStateStore~new(root)~findOne(setup~qid)~state \= .QueueState~RUNNING then call fail "activated job not running"
consumed = .QueueWLUUsageService~new(root, authority, admission, journal)~consume(setup~qid, 1500000, "sample-1")
if \consumed~ok then call fail "consume failed " || consumed~code
completed = .QueueWLUTerminalService~new(root, authority, admission, journal)~complete(setup~qid, 2250000)
if \completed~ok then call fail "complete terminal failed " || completed~detail
if .QueueStateStore~new(root)~findOne(setup~qid)~state \= .QueueState~DONE then call fail "complete did not commit done"
state = authority~reservationState(reservation~reservationId)
if \state~ok | state~value \= .WLUReservationState~SETTLED then call fail "complete WLU not settled"
if account~spentMicroWlu \= 2250000 then call fail "complete actual WLU not charged"
if account~reservedMicroWlu \= 0 then call fail "complete held WLU not released"
if pool~reservedRateMicroWluPerSecond \= 0 then call fail "complete WLU/s not released"
if \journal~phaseExists(binding~transactionId, .QueueWLULifecyclePhase~WLU_COMMITTED) then call fail "complete WLU committed phase missing"

/* Cancel: consumed work is retained, unused reservation and throughput release. */
beforeSpent = account~spentMicroWlu
setup2 = makeJob(root, "cancel")
record2 = .QueueStateStore~new(root)~findOne(setup2~qid)
placed2 = reserveJob(admission, record2, "nodeA", 12)
reservation2 = placed2~reservation
lease2 = makeLease(setup2~qid, "nodeA", reservation2~reservationId)
if \.QueueWLUActivationService~new(root, authority, admission, journal)~activate(setup2~qid, lease2)~ok then call fail "cancel activation failed"
if \.QueueWLUUsageService~new(root, authority, admission, journal)~consume(setup2~qid, 500000, "sample-cancel")~ok then call fail "cancel consume failed"
cancelled = .QueueWLUTerminalService~new(root, authority, admission, journal)~cancel(setup2~qid)
if \cancelled~ok then call fail "cancel terminal failed " || cancelled~detail
if .QueueStateStore~new(root)~findOne(setup2~qid)~state \= .QueueState~CANCELLED then call fail "cancel did not commit cancelled"
state2 = authority~reservationState(reservation2~reservationId)
if \state2~ok | state2~value \= .WLUReservationState~RELEASED then call fail "cancel WLU not released"
if account~spentMicroWlu \= beforeSpent + 500000 then call fail "cancel did not preserve consumed WLU"
if account~reservedMicroWlu \= 0 | pool~reservedRateMicroWluPerSecond \= 0 then call fail "cancel left WLU authority holds"

/* Crash window: queue terminal committed, WLU settlement missing.  Recovery
 * uses durable reservation proof + terminal intent and completes exactly once. */
beforeSpent = account~spentMicroWlu
setup3 = makeJob(root, "recover")
record3 = .QueueStateStore~new(root)~findOne(setup3~qid)
placed3 = reserveJob(admission, record3, "nodeA", 13)
reservation3 = placed3~reservation
lease3 = makeLease(setup3~qid, "nodeA", reservation3~reservationId)
if \.QueueWLUActivationService~new(root, authority, admission, journal)~activate(setup3~qid, lease3)~ok then call fail "recovery activation failed"
if \.QueueWLUUsageService~new(root, authority, admission, journal)~consume(setup3~qid, 750000, "sample-recover")~ok then call fail "recovery consume failed"
binding3 = onlyBinding(journal, setup3~qid)
prep = .Directory~new
prep["qid"] = setup3~qid
prep["from_state"] = .QueueState~NAME_RUNNING
prep["to_state"] = .QueueState~NAME_DONE
prep["terminal_kind"] = .QueueWLUTerminalKind~NAME_COMPLETE
prep["wlu_action"] = .QueueWLUCloseAction~NAME_SETTLE
prep["reservation_ref"] = reservation3~reservationId
prep["actual_micro_wlu"] = 1000000
if \journal~writePhase(binding3~transactionId, .QueueWLULifecyclePhase~TERMINAL_PREPARED, prep) then call fail "recovery prepare journal failed"
qmove = .QueueTransitionService~new(root)~transition(setup3~qid, .QueueState~RUNNING, .QueueState~DONE, .QueueEvent~JOB_COMPLETED, "test-crash-window")
if \qmove~ok then call fail "recovery queue commit failed"
active3 = authority~reservationState(reservation3~reservationId)
if \active3~ok | active3~value \= .WLUReservationState~ACTIVE then call fail "recovery setup unexpectedly closed WLU"
outcomes = .QueueWLULifecycleRecovery~new(root, authority, admission, journal)~recover
foundRecovered = .false
do o over outcomes
  if o~qid == setup3~qid & o~status == .QueueWLULifecycleStatus~RECOVERED then foundRecovered = .true
end
if \foundRecovered then call fail "recovery did not finish post-queue WLU settlement"
state3 = authority~reservationState(reservation3~reservationId)
if \state3~ok | state3~value \= .WLUReservationState~SETTLED then call fail "recovered WLU not settled"
if account~spentMicroWlu \= beforeSpent + 1000000 then call fail "recovered actual WLU incorrect"
/* Idempotent second recovery must not spend again. */
spentAfter = account~spentMicroWlu
ignore = .QueueWLULifecycleRecovery~new(root, authority, admission, journal)~recover
if account~spentMicroWlu \= spentAfter then call fail "recovery replay double-settled WLU"

/* Cross-engine terminal: no QueueRexx terminal intent exists.  A QueueBash-
 * compatible cancellation is queue authority; recovery synthesizes only the
 * missing WLU release and never reopens/moves the terminal record. */
beforeSpent = account~spentMicroWlu
setup4 = makeJob(root, "external-cancel")
record4 = .QueueStateStore~new(root)~findOne(setup4~qid)
placed4 = reserveJob(admission, record4, "nodeA", 14)
reservation4 = placed4~reservation
lease4 = makeLease(setup4~qid, "nodeA", reservation4~reservationId)
if \.QueueWLUActivationService~new(root, authority, admission, journal)~activate(setup4~qid, lease4)~ok then call fail "external cancel activation failed"
if \.QueueWLUUsageService~new(root, authority, admission, journal)~consume(setup4~qid, 250000, "sample-external-cancel")~ok then call fail "external cancel consume failed"
external = .QueueTransitionService~new(root)~transition(setup4~qid, .QueueState~RUNNING, .QueueState~CANCELLED, .QueueEvent~JOB_CANCELLED, "queuebash-compatible-external")
if \external~ok then call fail "external cancel transition failed"
ignore = .QueueWLULifecycleRecovery~new(root, authority, admission, journal)~recover
state4 = authority~reservationState(reservation4~reservationId)
if \state4~ok | state4~value \= .WLUReservationState~RELEASED then call fail "external cancel WLU not recovered/released"
if account~spentMicroWlu \= beforeSpent + 250000 then call fail "external cancel lost consumed WLU"
if .QueueStateStore~new(root)~findOne(setup4~qid)~state \= .QueueState~CANCELLED then call fail "WLU recovery changed QueueBash terminal authority"

/* Exception safety: an authority condition while metering must never strand
 * the ordinary QID lock.  The job remains running and can be terminated by a
 * normal authority afterward. */
setup5 = makeJob(root, "usage-exception")
record5 = .QueueStateStore~new(root)~findOne(setup5~qid)
placed5 = reserveJob(admission, record5, "nodeA", 15)
reservation5 = placed5~reservation
lease5 = makeLease(setup5~qid, "nodeA", reservation5~reservationId)
if \.QueueWLUActivationService~new(root, authority, admission, journal)~activate(setup5~qid, lease5)~ok then call fail "usage exception activation failed"
throwConsume = .ThrowingAuthority~new(authority, .ThrowingAuthority~OP_CONSUME)
if \expectUsageSyntax(root, setup5~qid, throwConsume, admission, journal) then call fail "injected consume syntax was not propagated"
probe5 = .QueueStateLockManager~new(root)~acquireDetailed(setup5~qid, .QueueLockActor~WLU_USAGE, 0)
if \probe5~acquired then call fail "usage syntax stranded QID lock"
probe5~handle~release
if \.QueueWLUTerminalService~new(root, authority, admission, journal)~cancel(setup5~qid)~ok then call fail "usage exception cleanup cancel failed"

/* Exception safety after the queue commit is even more important.  Inject a
 * settlement condition after running->done; the lock must be released and the
 * durable terminal intent must let recovery finish exactly the WLU side. */
setup6 = makeJob(root, "terminal-exception")
record6 = .QueueStateStore~new(root)~findOne(setup6~qid)
placed6 = reserveJob(admission, record6, "nodeA", 16)
reservation6 = placed6~reservation
lease6 = makeLease(setup6~qid, "nodeA", reservation6~reservationId)
if \.QueueWLUActivationService~new(root, authority, admission, journal)~activate(setup6~qid, lease6)~ok then call fail "terminal exception activation failed"
throwSettle = .ThrowingAuthority~new(authority, .ThrowingAuthority~OP_SETTLE)
if \expectTerminalSyntax(root, setup6~qid, throwSettle, admission, journal) then call fail "injected settle syntax was not propagated"
if .QueueStateStore~new(root)~findOne(setup6~qid)~state \= .QueueState~DONE then call fail "terminal exception did not preserve committed queue authority"
probe6 = .QueueStateLockManager~new(root)~acquireDetailed(setup6~qid, .QueueLockActor~WLU_RECOVERY, 0)
if \probe6~acquired then call fail "terminal syntax stranded QID lock"
probe6~handle~release
state6 = authority~reservationState(reservation6~reservationId)
if \state6~ok | state6~value \= .WLUReservationState~ACTIVE then call fail "injected terminal failure unexpectedly closed WLU"
outcomes6 = .QueueWLULifecycleRecovery~new(root, authority, admission, journal)~recover
state6b = authority~reservationState(reservation6~reservationId)
if \state6b~ok | state6b~value \= .WLUReservationState~SETTLED then call fail "terminal exception recovery did not settle WLU"

say "PASS first-class WLU lifecycle: durable binding, activation, consumption, settlement/release, exception-safe locks and crash/cross-engine recovery"
exit 0

makeJob: procedure expose root
  use strict arg rootArg, suffix
  wlu = .QueueWLURequirement~managedDemand("QTEST", "BUILD", 2000000, 3000000, 4)
  req = .QueueSubmitRequest~new("wlu-" || suffix, .Array~of("/bin/true"), 25, "BATCH", .QueueRunnerKind~DIRECT, "/tmp", wlu)
  receipt = .QueueSubmitService~new(rootArg, .AllowPolicy~new)~submit(req)
  if \receipt~ok then do
    say "FAIL job setup" suffix receipt~code receipt~detail
    exit 1
  end
  return receipt

reserveJob: procedure
  use strict arg admission, record, nodeId, generation
  nodeReq = .JobNodeRequirement~new
  place = .QueueWLUPlacementRequestAdapter~fromRecord(record, nodeReq, "owner")
  cap = .NodeCapabilityStatement~new(nodeId, 1)
  capacity = .NodeCapacityObservation~new(nodeId, 1, generation, 0, 0, 1024, 1024, 100, 5000000, 0, 0)
  return admission~reserve(place, cap, capacity, 30000)

makeLease: procedure
  use strict arg qid, nodeId, reservationRef
  return .JobNodePlacementLease~new("p-" || qid, qid, nodeId, "owner", 1, 1, 0, 30000, "r", "c", "o", "1", "", reservationRef)

onlyBinding: procedure
  use strict arg journal, qid
  bindings = journal~bindingsFor(qid)
  if bindings~items \= 1 then do
    say "FAIL expected one durable WLU binding for" qid "got" bindings~items
    exit 1
  end
  return bindings[1]

expectUsageSyntax: procedure
  use strict arg root, qid, authority, admission, journal
  signal on syntax name usageCaught
  ignore = .QueueWLUUsageService~new(root, authority, admission, journal)~consume(qid, 1000, "injected-usage-condition")
  signal off syntax
  return .false
usageCaught:
  signal off syntax
  return .true

expectTerminalSyntax: procedure
  use strict arg root, qid, authority, admission, journal
  signal on syntax name terminalCaught
  ignore = .QueueWLUTerminalService~new(root, authority, admission, journal)~complete(qid, 100000)
  signal off syntax
  return .false
terminalCaught:
  signal off syntax
  return .true

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class ThrowingAuthority public
::constant OP_CONSUME 1
::constant OP_SETTLE 2
::constant OP_RELEASE 3
::attribute delegate get
::attribute failOperation get
::method init
  expose delegate failOperation
  use strict arg delegateArg, failOperationArg
  delegate = delegateArg
  failOperation = failOperationArg + 0
::method reservationState
  expose delegate
  forward to (delegate)
::method consume
  expose delegate failOperation
  if failOperation == self~OP_CONSUME then raise syntax 88.900 array("injected WLU consume condition")
  forward to (delegate)
::method settle
  expose delegate failOperation
  if failOperation == self~OP_SETTLE then raise syntax 88.900 array("injected WLU settle condition")
  forward to (delegate)
::method release
  expose delegate failOperation
  if failOperation == self~OP_RELEASE then raise syntax 88.900 array("injected WLU release condition")
  forward to (delegate)

::class AllowPolicy subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::method assessExecution
  return .QueuePolicyVerdict~allow("TEST_ALLOW")

::requires "QueueRexxOperations.cls"
::requires "QueueRexxWLU.cls"
