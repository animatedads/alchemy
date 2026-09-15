root = "/mnt/data/queuerexx-dev8-wlu-scheduling-execution-test"
address system "rm -rf " || root
call SysMkDir root
do dir over .Array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs")
  call SysMkDir root || "/" || dir
end
policy = .AllowPolicy~new

/* Ordinary work exists, but the higher-priority WLU job is not eligible until
 * both WLU reservation and placement authority exist. */
plainReq = .QueueSubmitRequest~new("plain-low", .Array~of("/bin/true"), 10, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp")
plain = .QueueSubmitService~new(root, policy)~submit(plainReq)
if \plain~ok then call fail "plain submit"
wlu = .QueueWLURequirement~managedDemand("QTEST", "BUILD", 1000000, 2000000, 2)
wluReq = .QueueSubmitRequest~new("wlu-high", .Array~of("/bin/sh", "-c", "printf 'wlu-dev8\\n'; exit 0"), 90, "BATCH", .QueueRunnerKind~DIRECT, "/tmp", wlu)
wjob = .QueueSubmitService~new(root, policy)~submit(wluReq)
if \wjob~ok then call fail "WLU submit"

keys = .WLUFastMacKeyRing~new
keys~addKey("k1", "00112233445566778899aabbccddeeff")
clock = .WLUTestTimeSource~new(1000000)
ledger = .WLUMemoryLedger~new
authority = .WLUAuthority~new(keys, ledger, clock)
account = .WLUAccount~new("acct", 10000000)
pool = .WLUThroughputPool~new("pool", 2000000)
authority~addAccount(account); authority~addThroughputPool(pool)
authority~bindAccount("QTEST", "BUILD*", "acct")
authority~bindThroughputPool("QTEST", "BUILD*", "pool")
admission = .QueueJobNodeWLUAdmission~new(authority, root)
journal = .QueueWLULifecycleJournal~new(root)

/* Job-to-Node is the placement/ownership authority.  The scheduler must not
 * infer validity from a copied reservationRef; it asks the allocator to verify
 * the exact current lease against the exact request and live registry evidence. */
registry = .NodeCapabilityRegistry~new
cap = .NodeCapabilityStatement~new("nodeA", 1)
capacity = .NodeCapacityObservation~new("nodeA", 1, 77, 1000000, 1030000, 1024, 1024, 100, 2000000, 0, 0)
if \registry~advertiseCapability(cap) then call fail "capability advertise"
if \registry~observeCapacity(capacity) then call fail "capacity observe"
ownership1 = .JobNodeOwnershipRegistry~new
rawAllocator1 = .JobNodeAllocator~new(registry, .JobNodeEligibilityPolicy~new, .nil, .nil, .nil, "qrx-dev11", admission, ownership1)
allocator1 = .QueueDurableJobNodeAllocator~new(rawAllocator1, ownership1, root, admission)
restored1 = allocator1~restore(1000000)
if \restored1~ok | restored1~restored \= 0 then call fail "initial Job-to-Node durable restore"
jobNodeClock = .QueueFixedJobNodeTimeSource~new(1000001)
placementAuthority1 = .QueueJobNodePlacementAuthority~new(allocator1, jobNodeClock)
leases = .QueueMemoryPlacementLeaseLookup~new
schedAdmission1 = .QueueWLUSchedulingAdmission~new(authority, admission, journal, leases, placementAuthority1)
scheduler = .QueueJobScheduler~new(root, schedAdmission1)

before = scheduler~selectNext
if \before~selected | before~record~qid \= plain~qid then call fail "unreserved WLU job incorrectly displaced eligible plain job"

record = .QueueStateStore~new(root)~findOne(wjob~qid)
place = .QueueWLUPlacementRequestAdapter~fromRecord(record, .JobNodeRequirement~new, "owner")
placed = allocator1~allocate(place, 1000000, 30000)
if \placed~placed then call fail "Job-to-Node placement " || placed~code
lease = placed~lease
reserved = allocator1~admissionReservation(lease)
if reserved == .nil then call fail "Job-to-Node did not retain WLU admission reservation"
leases~put(lease, place)

/* Simulate QueueRexx / allocator process loss before scheduling. The separate
 * WLU authority survives. Job-to-Node must reconstruct ownership, sequence and
 * the authenticated WLU reservation proof from its durable snapshot. */
ownership2 = .JobNodeOwnershipRegistry~new
rawAllocator2 = .JobNodeAllocator~new(registry, .JobNodeEligibilityPolicy~new, .nil, .nil, .nil, "qrx-dev11", admission, ownership2)
allocator2 = .QueueDurableJobNodeAllocator~new(rawAllocator2, ownership2, root, admission)
restored2 = allocator2~restore(1000001)
if \restored2~ok | restored2~restored \= 1 | restored2~blocked \= 0 then call fail "WLU-backed Job-to-Node restore"
if \allocator2~hasAdmission(lease) then call fail "restored Job-to-Node WLU admission missing"
if \allocator2~verifyLease(lease, place, 1000001) then call fail "restored WLU-backed lease rejected"
placementAuthority2 = .QueueJobNodePlacementAuthority~new(allocator2, jobNodeClock)
schedAdmission2 = .QueueWLUSchedulingAdmission~new(authority, admission, journal, leases, placementAuthority2)
scheduler = .QueueJobScheduler~new(root, schedAdmission2)

after = scheduler~selectNext
if \after~selected | after~record~qid \= wjob~qid then call fail "eligible higher-priority WLU job was not selected"
if after~verdict~data["requested_rate_micro_wlu_per_second"] \= 500000 then call fail "WLU/s absent from scheduling decision"
if after~placementLease \= lease then call fail "placement lease context missing"
if after~verdict~data["ownership_epoch"] \= lease~ownershipEpoch then call fail "ownership epoch absent from scheduling decision"
if after~verdict~data["job_node_verification"]["verified"] \= .JSONBoolean~true then call fail "Job-to-Node verification evidence missing"

activation = .QueueWLUActivationService~new(root, authority, admission, journal)
terminal = .QueueWLUTerminalService~new(root, authority, admission, journal)
recovery = .QueueWLULifecycleRecovery~new(root, authority, admission, journal)
exec = .QueueExecutionService~new(root, .nil, .nil, .nil, .nil, .nil, terminal, recovery)
workerAdmission = .QueueWorkerAdmission~new(root, policy)
worker = .QueueTypedWorker~new(scheduler, workerAdmission, exec, activation, policy)
started = worker~startNext
if \started~ok then call fail "typed WLU worker start " || started~code || " " || started~detail
if started~decision~record~qid \= wjob~qid then call fail "worker started wrong job"

final = .nil
do i = 1 to 100
  rr = exec~reconcile(wjob~qid)
  if rr~status == .QueueExecutionStatus~TERMINAL then do; final = rr; leave; end
  if rr~status == .QueueExecutionStatus~AMBIGUOUS then call fail "WLU execution ambiguous " || rr~detail
  call SysSleep 0.05
end
if final == .nil then call fail "WLU execution did not finish"
if final~state \= .QueueState~DONE then call fail "WLU execution terminal state"
resState = authority~reservationState(lease~reservationRef)
if \resState~ok | resState~value \= .WLUReservationState~SETTLED then call fail "WLU reservation not settled after execution"
if account~reservedMicroWlu \= 0 | pool~reservedRateMicroWluPerSecond \= 0 then call fail "WLU execution left capacity reserved"

/* Queue terminal/WLU settlement is separate from Job-to-Node ownership. Once
 * terminal state is authoritative, explicitly release the placement and prove
 * a fresh allocator restart does not resurrect it. */
if \allocator2~releasePlacement(lease) then call fail "durable Job-to-Node release after terminal settlement"
ownership3 = .JobNodeOwnershipRegistry~new
rawAllocator3 = .JobNodeAllocator~new(registry, .JobNodeEligibilityPolicy~new, .nil, .nil, .nil, "qrx-dev11", admission, ownership3)
allocator3 = .QueueDurableJobNodeAllocator~new(rawAllocator3, ownership3, root, admission)
restored3 = allocator3~restore(1000002)
if \restored3~ok | restored3~restored \= 0 then call fail "terminal placement resurrected after restart"
if ownership3~current(wjob~qid, 1000002) \= .nil then call fail "terminal ownership restored as current"

/* Plain job is now next, proving WLU admission does not replace queue priority
 * or permanently starve unmanaged work. */
next = scheduler~selectNext
if \next~selected | next~record~qid \= plain~qid then call fail "plain job not selected after WLU completion"

say "PASS WLU-first scheduling: durable Job-to-Node/WLU admission restart, authoritative lease verification, priority ordering, typed activation, execution, settlement and durable placement release"
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
::requires "QueueRexxJobNodeDurable.cls"
::requires "JobNodeLiveness.cls"
