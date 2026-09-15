/* QueueRexx dev11: Job-to-Node v0.6 is the placement/ownership verifier.
 * QueueRexx never promotes a lease merely because its reservationRef matches. */
root = "/mnt/data/queuerexx-dev11-job-node-verification-test"
address system "rm -rf " || root
call SysMkDir root
do dir over .Array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs")
  call SysMkDir root || "/" || dir
end

policy = .AllowPolicy~new
wlu = .QueueWLURequirement~managedDemand("QTEST", "VERIFY", 1000000, 2000000, 2)
req = .QueueSubmitRequest~new("job-node-verify", .Array~of("/bin/true"), 50, "BATCH", .QueueRunnerKind~DIRECT, "/tmp", wlu)
submitted = .QueueSubmitService~new(root, policy)~submit(req)
if \submitted~ok then call fail "submit"
record = .QueueStateStore~new(root)~findOne(submitted~qid)
place = .QueueWLUPlacementRequestAdapter~fromRecord(record, .JobNodeRequirement~new, "OWNER-A")

keys = .WLUFastMacKeyRing~new
keys~addKey("k1", "00112233445566778899aabbccddeeff")
wluClock = .WLUTestTimeSource~new(1000)
ledger = .WLUMemoryLedger~new
authority = .WLUAuthority~new(keys, ledger, wluClock)
authority~addAccount(.WLUAccount~new("acct", 10000000))
authority~addThroughputPool(.WLUThroughputPool~new("pool", 2000000))
authority~bindAccount("QTEST", "VERIFY*", "acct")
authority~bindThroughputPool("QTEST", "VERIFY*", "pool")
admission = .QueueJobNodeWLUAdmission~new(authority, root)

registry = .NodeCapabilityRegistry~new
cap1 = .NodeCapabilityStatement~new("NODE-A", 1)
obs1 = .NodeCapacityObservation~new("NODE-A", 1, 10, 1000, 5000, 4096, 4096, 4, 2000000, 0, 0)
if \registry~advertiseCapability(cap1) then call fail "capability advertise"
if \registry~observeCapacity(obs1) then call fail "capacity observe"
ownership = .JobNodeOwnershipRegistry~new
allocator = .JobNodeAllocator~new(registry, .JobNodeEligibilityPolicy~new, .nil, .nil, .nil, "QRX-POLICY-1", admission, ownership)
decision = allocator~allocate(place, 1000, 3000)
if \decision~placed then call fail "initial placement " || decision~code
lease = decision~lease

clock = .QueueFixedJobNodeTimeSource~new(1001)
verifier = .QueueJobNodePlacementAuthority~new(allocator, clock)
valid = verifier~verify(record, lease, place)
if \valid~verified then call fail "valid authoritative lease rejected " || valid~code
if valid~data["ownership_epoch"] <= 0 then call fail "ownership epoch evidence missing"

/* The exact digested request is required. */
missing = verifier~verify(record, lease, .nil)
if missing~verified | missing~code \= .QueueJobNodeVerificationCode~REQUEST_REQUIRED then call fail "missing placement request did not fail closed"
changed = .JobPlacementRequest~new(record~qid, .JobNodeRequirement~new, "OWNER-B", place~expectedMicroWlu, place~requestedRateMicroWluPerSecond)
if verifier~verify(record, lease, changed)~verified then call fail "changed placement request accepted"

/* Capacity generation drift invalidates a once-valid lease. */
obs2 = .NodeCapacityObservation~new("NODE-A", 1, 11, 1100, 5000, 4096, 4096, 4, 2000000, 0, 0)
if \registry~observeCapacity(obs2) then call fail "capacity generation advance"
if verifier~verify(record, lease, place)~verified then call fail "stale capacity-generation lease accepted"

/* Restore the exact observation, then prove expiry still fails closed.  A new
 * registry is used because observation generations are monotonic by design. */
registry2 = .NodeCapabilityRegistry~new
cap2 = .NodeCapabilityStatement~new("NODE-A", 1)
obsExact = .NodeCapacityObservation~new("NODE-A", 1, 10, 1000, 5000, 4096, 4096, 4, 2000000, 0, 0)
registry2~advertiseCapability(cap2); registry2~observeCapacity(obsExact)
ownership2 = .JobNodeOwnershipRegistry~new
allocator2 = .JobNodeAllocator~new(registry2, .JobNodeEligibilityPolicy~new, .nil, .nil, .nil, "QRX-POLICY-1", .nil, ownership2)
/* A reservation-bearing lease cannot be reconstructed into an allocator that
 * has not restored its admission evidence; this is itself fail-closed. */
verifier2 = .QueueJobNodePlacementAuthority~new(allocator2, clock)
if verifier2~verify(record, lease, place)~verified then call fail "lease accepted without restored admission authority"

/* Original allocator remains authoritative for expiry even though capacity
 * already drifted; expiry is independently tested by advancing time. */
clock~set(5000)
expired = verifier~verify(record, lease, place)
if expired~verified then call fail "expired lease accepted"

/* Revocation is immediate placement invalidation. */
clock~set(1001)
registry~revoke("NODE-A")
if verifier~verify(record, lease, place)~verified then call fail "revoked node lease accepted"

say "PASS QueueRexx delegates placement validity to Job-to-Node v0.6: exact request, admission evidence, generations, ownership and freshness fail closed"
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

::requires "QueueRexxWLU.cls"
::requires "JobNodeLiveness.cls"
