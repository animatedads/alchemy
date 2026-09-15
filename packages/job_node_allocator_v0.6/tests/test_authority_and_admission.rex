/* Hard external authority + ranked admission fallback + release. */
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
job=.JobPlacementRequest~new("JOB-AUTH",req,"OWNER",1000000,1000000)
r=.NodeCapabilityRegistry~new

/* FAST is fitter but external authority forbids it. */
cf=.NodeCapabilityStatement~new("FAST",1,"p",uk)
of=.NodeCapacityObservation~new("FAST",1,1,100,10000,32000,100000,16,50000000,0,0,"o")
r~advertiseCapability(cf); r~observeCapacity(of)
cs=.NodeCapabilityStatement~new("SAFE",1,"p",uk)
os=.NodeCapacityObservation~new("SAFE",1,1,100,10000,16000,100000,8,10000000,0,0,"o")
r~advertiseCapability(cs); r~observeCapacity(os)
assessors=.array~of(.DenyFast~new)
elig=.JobNodeEligibilityPolicy~new(assessors)
a=.JobNodeAllocator~new(r,elig)
d=a~allocate(job,200,5000)
if \d~placed | d~lease~nodeId<>"SAFE" then call fail "hard authority did not exclude FAST"
if d~exclusionCount("SECURITY_POLICY_DENIED")<>1 then call fail "missing external authority evidence"

/* With no hard denial, admission authority rejects FAST reservation and the
 * allocator must try SAFE, not dispatch without admission. */
adm=.FallbackAdmission~new
a2=.JobNodeAllocator~new(r,.JobNodeEligibilityPolicy~new,.nil,.nil,.nil,"2",adm)
d2=a2~allocate(job,200,5000)
if \d2~placed then call fail "fallback placement failed"
if d2~lease~nodeId<>"SAFE" then call fail "did not fall back after admission denial"
if d2~lease~reservationRef<>"RES-SAFE" then call fail "reservation ref not bound into lease"
if adm~attempts<>2 then call fail "expected two admission attempts"
if \a2~releasePlacement(d2~lease) then call fail "release placement failed"
if adm~released<>1 then call fail "reservation was not released"

say "PASS hard external authority and ranked admission fallback/release"
exit 0
fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class DenyFast subclass JobNodeHardConstraintAssessor
::method assess
  use arg request,capability,capacity,now
  if capability~nodeId="FAST" then return .array~of("SECURITY_POLICY_DENIED")
  return .array~new

::class FakeReservation
::attribute reservationId get
::method init
  expose reservationId
  use arg id
  reservationId=id

::class FallbackAdmission subclass JobNodeAdmissionAuthority
::attribute attempts get
::attribute released get
::method init
  expose attempts released
  attempts=0; released=0
::method reserve
  expose attempts
  use arg request,capability,capacity,ttl
  attempts+=1
  if capability~nodeId="FAST" then return .JobNodeAdmissionResult~deny("WLU_RESERVATION_DENIED","test")
  x=.FakeReservation~new("RES-SAFE")
  return .JobNodeAdmissionResult~allow(x,x~reservationId)
::method release
  expose released
  use arg reservation
  released+=1
  return .true

::requires "../src/JobNodeAllocator.cls"
