journalPath="/tmp/job_node_allocator_v05_wlu_restart.journal"
call SysFileDelete journalPath
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
job=.JobPlacementRequest~new("JOB-WLU-DURABLE",req,"OWNER",2000000,500000)
r=.NodeCapabilityRegistry~new
c=.NodeCapabilityStatement~new("N1",1,"p",uk)
o=.NodeCapacityObservation~new("N1",1,7,100,10000,4096,10000,4,1000000,0,0,"o")
r~advertiseCapability(c); r~observeCapacity(o)
wa=.DurableFakeWLUAuthority~new
adapter=.JobNodeWLUAdmission~new(wa,"WORKER-ID","placement")
own1=.JobNodeOwnershipRegistry~new
alloc1=.JobNodeAllocator~new(r,.nil,.nil,.nil,.nil,"5",adapter,own1)
m1=.JobNodeDurablePlacementManager~new(alloc1,own1,.JobNodeDurableJournal~new(journalPath),adapter)
d=m1~allocate(job,200,3500)
if \d~placed then call fail "WLU durable placement failed"
if d~lease~reservationRef<>"WLU-DURABLE-1" then call fail "reservation ref not bound"

/* Simulate allocator process loss while the separate WLU authority survives. */
own2=.JobNodeOwnershipRegistry~new
alloc2=.JobNodeAllocator~new(r,.nil,.nil,.nil,.nil,"5",adapter,own2)
m2=.JobNodeDurablePlacementManager~new(alloc2,own2,.JobNodeDurableJournal~new(journalPath),adapter)
rr=m2~restore(400)
if \rr~ok | rr~restored<>1 then call fail "WLU reservation not recovered"
if \alloc2~hasAdmission(d~lease) then call fail "recovered admission proof missing"
if \alloc2~verifyLease(d~lease,job,400) then call fail "WLU-backed restored lease rejected"
if \m2~releasePlacement(d~lease) then call fail "release through reconstructed WLU proof failed"
if wa~lastReleased==.nil then call fail "reconstructed WLU reservation not released"
if wa~lastReleased~reservationId<>"WLU-DURABLE-1" then call fail "wrong recovered reservation id"
if wa~lastReleased~proof~algorithm<>"SIPHASH-2-4-128" then call fail "proof algorithm not recovered"
if wa~lastReleased~proof~keyId<>"K1" | wa~lastReleased~proof~tag<>"0123456789abcdef0123456789abcdef" then call fail "proof material not recovered"
if wa~lastReleased~bucketIds~items<>2 | wa~lastReleased~throughputPoolIds~items<>1 then call fail "reservation arrays not recovered"

say "PASS durable WLU reservation proof reconstruction and release after restart"
exit 0
fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class FakeWLUResult
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg o,c,d,v
  ok=o; code=c; detail=d; value=v

::class DurableFakeWLUAuthority
::attribute lastReleased get
::method init
  expose active lastReleased
  active=.directory~new; lastReleased=.nil
::method reserveDemand
  expose active
  use arg identity,scope,demand,seconds,requestId
  proof=.WLUProof~new("SIPHASH-2-4-128","K1","0123456789abcdef0123456789abcdef")
  reservation=.WLUReservation~new("WLU-DURABLE-1",identity,"ACCOUNT-1",scope,"RATE-1","1",demand~ceilingMicroWlu,100,100000,.array~of("B1","B2"),1,proof,demand~expectedMicroWlu,demand~requestedRateMicroWluPerSecond,.array~of("P1"))
  active[reservation~reservationId]=.true
  return .FakeWLUResult~new(.true,"OK","",reservation)
::method reservationState
  expose active
  use strict arg reservationId
  if active[reservationId~string]==.true then return .FakeWLUResult~new(.true,"OK","",.WLUReservationState~ACTIVE)
  return .FakeWLUResult~new(.true,"OK","",.WLUReservationState~RELEASED)
::method release
  expose active lastReleased
  use strict arg reservation
  lastReleased=reservation
  active[reservation~reservationId]=.false
  return .FakeWLUResult~new(.true,"OK","",.WLUReservationState~RELEASED)

::requires "../src/JobNodeDurableState.cls"
::requires "../src/JobNodeWLUAdapter.cls"
