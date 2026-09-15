/* Exercise the real WLUWorkDemand type through the allocator adapter. */
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
job=.JobPlacementRequest~new("JOB-WLU",req,"OWNER",2000000,500000)
r=.NodeCapabilityRegistry~new
c=.NodeCapabilityStatement~new("N1",1,"p",uk)
o=.NodeCapacityObservation~new("N1",1,7,100,10000,4096,10000,4,1000000,0,0,"o")
r~advertiseCapability(c); r~observeCapacity(o)
wa=.FakeWLUAuthority~new
adapter=.JobNodeWLUAdmission~new(wa,"WORKER-ID","placement")
a=.JobNodeAllocator~new(r,.nil,.nil,.nil,.nil,"2",adapter)
d=a~allocate(job,200,3500)
if \d~placed then call fail "WLU-backed placement failed"
if wa~demand==.nil | \wa~demand~isA(.WLUWorkDemand) then call fail "real WLUWorkDemand not supplied"
if wa~demand~expectedMicroWlu<>2000000 then call fail "expected WLU mismatch"
if wa~demand~requestedRateMicroWluPerSecond<>500000 then call fail "WLU rate mismatch"
if wa~ttl<>4 then call fail "lease TTL not rounded to WLU seconds"
if d~lease~reservationRef<>"WLU-R1" then call fail "WLU reservation not bound to placement lease"
renewed=a~renewPlacement(d~lease,job,1000,3500)
if \renewed~placed | renewed~code<>"RENEWED" then call fail "WLU-backed renewal failed"
if renewed~lease~reservationRef<>"WLU-R2" then call fail "renewal reservation not replaced"
if wa~releaseCount<>1 then call fail "old WLU reservation not released during renewal"
if \a~releasePlacement(renewed~lease) then call fail "WLU release failed"
if wa~releaseCount<>2 then call fail "WLU release count"
say "PASS real WLU v0.12 admission adapter"
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
::class FakeWLUReservation
::attribute reservationId get
::method init
  expose reservationId
  use arg id
  reservationId=id
::class FakeWLUAuthority
::attribute demand get
::attribute ttl get
::attribute releaseCount get
::method init
  expose demand ttl releaseCount reserveCount
  demand=.nil; ttl=0; releaseCount=0; reserveCount=0
::method reserveDemand
  expose demand ttl reserveCount
  use arg identity,scope,d,seconds,requestId
  demand=d; ttl=seconds; reserveCount+=1
  return .FakeWLUResult~new(.true,"OK","",.FakeWLUReservation~new("WLU-R"||reserveCount))
::method release
  expose releaseCount
  use arg reservation
  releaseCount+=1
  return .FakeWLUResult~new(.true,"OK","",reservation)

::requires "../src/JobNodeWLUAdapter.cls"
