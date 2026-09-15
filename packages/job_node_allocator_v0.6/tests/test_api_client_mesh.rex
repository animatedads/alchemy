
route=.ApiRouteRequirement~new("US","LEGAL-EU","VPN","CONTROLLED",.array~of("BANK-API"))
apiNode=.ApiEgressNode~new("EXEC-US-1",.array~of("US"),.array~of("LEGAL-EU"),.array~of("VPN"),.array~of("CONTROLLED"),.array~of("BANK-API"),8,9,"api-proof")
apiCap=.NodeApiEgressCapability~fromApiEgressNode(apiNode)

req=.JobNodeRequirement~new(.array~of("US"),.nil,.nil,.nil,.nil,.array~of("OOREXX/5.3"),.nil,"X86_64",0,0,0,0,0,0,0,route)
job=.JobPlacementRequest~new("API-JOB-1",req,"OWNER-UK",1000000,1000000)
reg=.NodeCapabilityRegistry~new
cap=.NodeCapabilityStatement~new("EXEC-US-1",5,"node-proof",.array~of("US"),.nil,.nil,.nil,.nil,.array~of("OOREXX/5.3"),.nil,"X86_64",8192,100000,4,"rr-1",apiCap)
obs=.NodeCapacityObservation~new("EXEC-US-1",5,2,100,10000,4096,50000,3,3000000,0,0,"obs-proof")
if \reg~advertiseCapability(cap) then call fail "advertise capability"
if \reg~observeCapacity(obs) then call fail "observe capacity"
alloc=.JobNodeAllocator~new(reg)
d=alloc~allocate(job,500,5000)
if \d~placed then call fail "placement failed"
if d~lease~nodeId<>"EXEC-US-1" then call fail "wrong execution node"

/* Actual ApiClient retains authority for reservation/session ownership. */
er=.ApiEgressRegistry~new
er~advertise(apiNode)
sm=.ApiSessionManager~new(er,"EXEC-US-1")
s=sm~acquire(route,"API-JOB-1","OWNER-UK")
if s==.nil then call fail "API session unavailable"
if s~nodeId<>d~lease~nodeId then call fail "API session node mismatch"
if s~ownerNodeId<>"OWNER-UK" then call fail "owner identity lost"
sm~release(s,.true)

/* A route claim absent from node capability is a hard placement failure. */
badRoute=.ApiRouteRequirement~new("US","OTHER-VPN","VPN","CONTROLLED",.array~of("BANK-API"))
badReq=.JobNodeRequirement~new(.array~of("US"),.nil,.nil,.nil,.nil,.array~of("OOREXX/5.3"),.nil,"X86_64",0,0,0,0,0,0,0,badRoute)
badJob=.JobPlacementRequest~new("API-JOB-2",badReq,"OWNER-UK",1000000,1000000)
bad=alloc~allocate(badJob,500,5000)
if bad~placed then call fail "bad route placed"
if bad~exclusionCount("API_ROUTE_REQUIREMENT_UNSATISFIED")<>1 then call fail "missing API route exclusion evidence"

say "PASS API Client v0.2 mesh"
exit 0
fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::requires "../src/JobNodeAllocator.cls"
::requires "ApiClient.cls"
