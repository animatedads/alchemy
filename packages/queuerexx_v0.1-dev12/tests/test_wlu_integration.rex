root = "/mnt/data/queuerexx-dev8-wlu-integration-test"
address system "rm -rf " || root
call SysMkDir root
call SysMkDir root || "/pending"
call SysMkDir root || "/waiting"
call SysMkDir root || "/running"
call SysMkDir root || "/pol_blocked"
call SysMkDir root || "/done"
call SysMkDir root || "/failed"
call SysMkDir root || "/cancelled"
call SysMkDir root || "/logs"

wlu = .QueueWLURequirement~managedDemand("QTEST", "BUILD", 2000000, 3000000, 4)
req = .QueueSubmitRequest~new("wlu authority", .Array~of("/bin/true"), 25, "BATCH", .QueueRunnerKind~DIRECT, "/tmp", wlu)
receipt = .QueueSubmitService~new(root, .AllowPolicy~new)~submit(req)
if \receipt~ok then call fail "WLU staged submit failed"

keys = .WLUFastMacKeyRing~new
keys~addKey("k1", "00112233445566778899aabbccddeeff")
clock = .WLUTestTimeSource~new(1000000)
ledger = .WLUMemoryLedger~new
authority = .WLUAuthority~new(keys, ledger, clock)
account = .WLUAccount~new("acct", 10000000)
pool = .WLUThroughputPool~new("pool", 2000000)
authority~addAccount(account)
authority~addThroughputPool(pool)
authority~bindAccount("QTEST", "BUILD*", "acct")
authority~bindThroughputPool("QTEST", "BUILD*", "pool")

admission = .QueueJobNodeWLUAdmission~new(authority, root)
nodeReq = .JobNodeRequirement~new
record = .QueueStateStore~new(root)~findOne(receipt~qid)
place = .QueueWLUPlacementRequestAdapter~fromRecord(record, nodeReq, "owner")
if place~expectedMicroWlu \= 2000000 then call fail "placement adapter expected WLU"
if place~requestedRateMicroWluPerSecond \= 500000 then call fail "placement adapter WLU/s"
cap = .NodeCapabilityStatement~new("nodeA", 1)
capacity = .NodeCapacityObservation~new("nodeA", 1, 7, 0, 0, 1024, 1024, 100, 2000000, 0, 0)

admitted = admission~reserve(place, cap, capacity, 30000)
if \admitted~admitted then call fail "WLU admission denied " || admitted~code || " " || admitted~detail
reservation = admitted~reservation
if reservation == .nil then call fail "WLU reservation missing"
if admitted~reservationRef \= reservation~reservationId then call fail "reservationRef mismatch"
if reservation~expectedMicroWlu \= 2000000 then call fail "expected work collapsed"
if reservation~reservedMicroWlu \= 3000000 then call fail "ceiling work not reserved"
if reservation~reservedRateMicroWluPerSecond \= 500000 then call fail "delivery rate not reserved"
if account~reservedMicroWlu \= 3000000 then call fail "account reservation amount"
if pool~reservedRateMicroWluPerSecond \= 500000 then call fail "throughput pool reservation"

lease = .JobNodePlacementLease~new("p1", receipt~qid, "nodeA", "owner", 1, 7, 0, 30000, "r", "c", "o", "1", "", reservation~reservationId)
projection = .QueueWLUStatusProjector~new(authority)~project(.QueueStateStore~new(root)~findOne(receipt~qid), lease)~asDirectory
if projection["state"] \= .QueueWLUProjectionState~NAME_ACTIVE then call fail "active WLU projection"
if projection["reservation_ref"] \= reservation~reservationId then call fail "projection reservation ref"

reservedBefore = account~reservedMicroWlu
badPlace = .JobPlacementRequest~new(receipt~qid, nodeReq, "owner", 1000000, 100000)
bad = admission~reserve(badPlace, cap, capacity, 30000)
if bad~admitted then call fail "understated WLU placement was admitted"
if bad~code \= .QueueWLUCode~DEMAND_MISMATCH then call fail "understated demand wrong denial code " || bad~code
if account~reservedMicroWlu \= reservedBefore then call fail "mismatched request changed WLU authority"

if \admission~release(reservation) then call fail "WLU release failed"
if account~reservedMicroWlu \= 0 then call fail "account WLU not released"
if pool~reservedRateMicroWluPerSecond \= 0 then call fail "throughput WLU/s not released"
released = .QueueWLUStatusProjector~new(authority)~project(.QueueStateStore~new(root)~findOne(receipt~qid), lease)~asDirectory
if released["state"] \= .QueueWLUProjectionState~NAME_RELEASED then call fail "released WLU projection"

say "PASS exact WLU v0.12 + Job-to-Node reservation, full ceiling/rate authority and mismatch rejection"
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
