parse arg qbRoot
if qbRoot == "" then do; say "FAIL QueueBash root required"; exit 2; end
root = "/mnt/data/queuerexx-dev8-wlu-queuebash-cancel-test"
address system "rm -rf " || root
call SysMkDir root
do dir over .array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs")
  call SysMkDir root || "/" || dir
end

wlu = .QueueWLURequirement~managedDemand("QTEST", "BUILD", 2000000, 3000000, 4)
req = .QueueSubmitRequest~new("wlu-qb-cancel", .Array~of("/bin/sleep","60"), 25, "BATCH", .QueueRunnerKind~DIRECT, "/tmp", wlu)
submitted = .QueueSubmitService~new(root, .AllowPolicy~new)~submit(req)
if \submitted~ok then call fail "staged submit failed"

keys = .WLUFastMacKeyRing~new
keys~addKey("k1", "00112233445566778899aabbccddeeff")
clock = .WLUTestTimeSource~new(1000000)
authority = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)
account = .WLUAccount~new("acct", 10000000)
pool = .WLUThroughputPool~new("pool", 2000000)
authority~addAccount(account); authority~addThroughputPool(pool)
authority~bindAccount("QTEST", "BUILD*", "acct")
authority~bindThroughputPool("QTEST", "BUILD*", "pool")
admission = .QueueJobNodeWLUAdmission~new(authority, root)
record = .QueueStateStore~new(root)~findOne(submitted~qid)
nodeReq = .JobNodeRequirement~new
place = .QueueWLUPlacementRequestAdapter~fromRecord(record, nodeReq, "owner")
cap = .NodeCapabilityStatement~new("nodeA", 1)
capacity = .NodeCapacityObservation~new("nodeA", 1, 19, 0, 0, 1024, 1024, 100, 2000000, 0, 0)
admitted = admission~reserve(place, cap, capacity, 30000)
if \admitted~admitted then call fail "WLU reserve failed " || admitted~code
reservation = admitted~reservation
lease = .JobNodePlacementLease~new("p-qb-cancel", submitted~qid, "nodeA", "owner", 1, 19, 0, 30000, "r", "c", "o", "1", "", reservation~reservationId)
activated = .QueueWLUActivationService~new(root, authority, admission)~activate(submitted~qid, lease)
if \activated~ok then call fail "activation failed " || activated~detail
if \.QueueWLUUsageService~new(root, authority, admission)~consume(submitted~qid, 250000, "before-qb-cancel")~ok then call fail "usage consume failed"

/* QueueBash performs the actual shared-filesystem terminal mutation. */
cmd = "QUEUEBASH_ROOT=" || root || " QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc 'source " || qbRoot || "/queuebash.sh >/dev/null; queue cancel --force " || submitted~qid || " >/dev/null'"
address system cmd
if rc \= 0 then call fail "QueueBash cancel failed rc=" || rc
cancelled = .QueueStateStore~new(root)~findOne(submitted~qid)
if cancelled == .nil | cancelled~state \= .QueueState~CANCELLED then call fail "QueueBash did not leave cancelled authority"
stateBefore = authority~reservationState(reservation~reservationId)
if \stateBefore~ok | stateBefore~value \= .WLUReservationState~ACTIVE then call fail "QueueBash unexpectedly mutated WLU authority"

outcomes = .QueueWLULifecycleRecovery~new(root, authority, admission)~recover
stateAfter = authority~reservationState(reservation~reservationId)
if \stateAfter~ok | stateAfter~value \= .WLUReservationState~RELEASED then call fail "QueueRexx did not recover WLU release after QueueBash cancel"
if account~spentMicroWlu \= 250000 then call fail "measured WLU was not retained after QueueBash cancel"
if account~reservedMicroWlu \= 0 | pool~reservedRateMicroWluPerSecond \= 0 then call fail "WLU hold/rate remained after recovery"
if .QueueStateStore~new(root)~findOne(submitted~qid)~state \= .QueueState~CANCELLED then call fail "WLU recovery changed QueueBash terminal state"

say "PASS real QueueBash 0.18.144 cancel remains queue authority and QueueRexx recovers WLU release"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class AllowPolicy subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::method assessExecution
  return .QueuePolicyVerdict~allow("TEST_ALLOW")

::requires "QueueRexxOperations.cls"
::requires "QueueRexxWLU.cls"
