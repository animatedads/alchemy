call mj_test_install_native_crypto
now=2000
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
pReq=.JobPlacementRequest~new("JOB-HOLD",req,"OWNER")
def=.MigratableJobDefinition~new("JOB-HOLD",pReq,"definition:hold","PART-H","OWNER")
app=.FailApp~new(def)
reg=.NodeCapabilityRegistry~new
cap=.NodeCapabilityStatement~new("NODE-X",1,"cap-x",uk)
obs=.NodeCapacityObservation~new("NODE-X",1,1,100,100000,4096,20000,4,1000000)
reg~advertiseCapability(cap); reg~observeCapacity(obs)
own=.JobNodeOwnershipRegistry~new
elig=.JobNodeEligibilityPolicy~new
alloc=.JobNodeAllocator~new(reg,elig,.nil,.nil,.nil,"HOLD",.nil,own)
store=.MigratableJobStartReceiptStore~new("/tmp/mj-managed-hold-start.receipts")
call SysFileDelete "/tmp/mj-managed-hold-start.receipts"
starter=.MigratableJobStarter~new(app,store)
exec=.MigratableJobLocalPlacedStartExecutor~new("NODE-X",starter)
tool=.MigratableJobManagedPlacementTool~new(app,alloc,reg,elig,.nil,exec)
sr=.MigratableJobStartRequest~new("START-HOLD","NEW","JOB-HOLD","definition:hold","PART-H","",now)

r=tool~allocateStart(sr,now,20000,"OP-HOLD")
if r~ok then call fail "start failure reported success"
if r~code<>"START_FAILED_PLACEMENT_HELD" then call fail "wrong failure code"
if \r~placementHeld | r~lease==.nil then call fail "placement not held"
if \own~isCurrent(r~lease,now+1) then call fail "ownership was released after ambiguous/failed start"

/* Explicit release is the only cleanup path. */
rel=tool~release(sr,r~lease,now+2,"OP-HOLD-RELEASE","confirmed not running")
if \rel~ok then call fail "explicit release"
if own~current("JOB-HOLD",now+3)<>.nil then call fail "release did not clear ownership"

say "PASS failed managed start retains placement until explicit release"
exit 0

fail: procedure
 parse arg m
 say "FAIL" m
 exit 1

::class FailApp subclass MigratableJobStarterApplication
::method init
 expose d
 use strict arg defArg
 d=defArg
::method definition
 expose d
 return d
::method startNew
 use strict arg request, definition
 return .MigratableJobResumeResult~failure("RUNTIME_START_FAILED","qualification failure")

::requires "MigratableJobManagedPlacement.cls"
::requires "TestForeignCryptoBootstrap.cls"
