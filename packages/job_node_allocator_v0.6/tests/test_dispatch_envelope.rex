uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
job=.JobPlacementRequest~new("JOB-D",req,"OWNER-X",1000,0)
r=.NodeCapabilityRegistry~new
c=.NodeCapabilityStatement~new("EXEC-7",1,"proof",uk)
o=.NodeCapacityObservation~new("EXEC-7",1,2,100,10000,1000,1000,1,1000,0,0,"obs")
r~advertiseCapability(c); r~observeCapacity(o)
a=.JobNodeAllocator~new(r)
d=a~allocate(job,200,1000)
e=.JobNodeDispatchEnvelope~new(d~lease,"PAYLOAD")
if e~ownerNodeId<>"OWNER-X" then call fail "owner lost"
if e~executionNodeId<>"EXEC-7" then call fail "execution node lost"
if e~placementId<>d~lease~placementId then call fail "lease identity lost"
if e~payload<>"PAYLOAD" then call fail "payload lost"
say "PASS queue-neutral dispatch envelope preserves owner/execution identity"
exit 0
fail: procedure
 parse arg m
 say "FAIL" m
 exit 1
::requires "../src/JobNodeDispatch.cls"
