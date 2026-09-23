now=5000
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
pReq=.JobPlacementRequest~new("JOB-PENDING",req,"OWNER")
def=.MigratableJobDefinition~new("JOB-PENDING",pReq,"definition:pending","PART-P","OWNER")
app=.PendingApp~new(def)
reg=.NodeCapabilityRegistry~new
cap=.NodeCapabilityStatement~new("NODE-P",1,"cap-p",uk)
obs=.NodeCapacityObservation~new("NODE-P",1,1,100,100000,4096,20000,4,1000000)
reg~advertiseCapability(cap); reg~observeCapacity(obs)
own=.JobNodeOwnershipRegistry~new
elig=.JobNodeEligibilityPolicy~new
alloc=.JobNodeAllocator~new(reg,elig,.nil,.TestDigest~new,.nil,"PENDING",.nil,own)
executor=.PendingExecutor~new
tool=.MigratableJobManagedPlacementTool~new(app,alloc,reg,elig,.nil,executor)
sr=.MigratableJobStartRequest~new("START-PENDING","NEW","JOB-PENDING","definition:pending","PART-P","",now)
r=tool~allocateStart(sr,now,20000,"OP-PENDING")
if \r~ok then call fail "pending dispatch reported failure"
if r~code<>"START_PENDING_PLACEMENT_HELD" then call fail "wrong pending code" r~code
if \r~placementHeld | r~lease==.nil then call fail "pending placement not held"
if r~startResult==.nil | r~startResult~state<>.MigratableJobStartState~PENDING then call fail "pending start result missing"
if \own~isCurrent(r~lease,now+1) then call fail "pending placement lost ownership"
say "PASS remote start uncertainty is PENDING with placement held"
exit 0
fail: procedure
  parse arg a,b
  say "FAIL" a b
  exit 1
::class PendingApp subclass MigratableJobStarterApplication
::method init
 expose d
 use strict arg defArg
 d=defArg
::method definition
 expose d
 use arg request=.nil
 return d
::method startNew
 use strict arg request, definition
 return .MigratableJobResumeResult~success("should-not-run")
::class PendingExecutor subclass MigratableJobPlacedStartExecutor
::method start
 use strict arg lease, request, nowEpochMs
 return .MigratableJobStartResult~pending(request,"REMOTE_START_PENDING","","qualification pending")
::class TestDigest
::method digest
 use strict arg text
 return "D:"||text
::requires "MigratableJobManagedPlacement.cls"
