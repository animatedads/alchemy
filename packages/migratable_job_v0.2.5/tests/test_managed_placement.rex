call mj_test_install_native_crypto
parse source . . testFile
auditPath=filespec("LOCATION",testFile)||"/tmp-managed-placement.audit"
call SysFileDelete auditPath
call SysFileDelete auditPath||".start"

now=1000
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
placement=.JobPlacementRequest~new("JOB-MANAGED",req,"OWNER",1000000,1000000)
def=.MigratableJobDefinition~new("JOB-MANAGED",placement,"definition:managed","PART-M","OWNER","OOREXX","5.3-r13196","rev-managed")
app=.ManagedApp~new(def)

reg=.NodeCapabilityRegistry~new
ca=.NodeCapabilityStatement~new("NODE-A",1,"cap-a",uk)
oa=.NodeCapacityObservation~new("NODE-A",1,1,100,100000,8192,50000,8,6000000,0,0,"obs-a")
cb=.NodeCapabilityStatement~new("NODE-B",1,"cap-b",uk)
ob=.NodeCapacityObservation~new("NODE-B",1,1,100,100000,16384,100000,16,30000000,0,0,"obs-b")
reg~advertiseCapability(ca); reg~observeCapacity(oa)
reg~advertiseCapability(cb); reg~observeCapacity(ob)

own=.JobNodeOwnershipRegistry~new
elig=.JobNodeEligibilityPolicy~new
alloc=.JobNodeAllocator~new(reg,elig,.nil,.nil,.nil,"MANAGED-TEST",.nil,own)
receipts=.MigratableJobStartReceiptStore~new(auditPath||".start")
starter=.MigratableJobStarter~new(app,receipts)
executor=.MigratableJobLocalPlacedStartExecutor~new("NODE-B",starter)
audit=.MigratableJobPlacementAuditStore~new(auditPath)
tool=.MigratableJobManagedPlacementTool~new(app,alloc,reg,elig,.nil,executor,audit)
startReq=.MigratableJobStartRequest~new("START-MANAGED-1","NEW","JOB-MANAGED","definition:managed","PART-M","",now)

/* Planning is read-only and explains/ranks nodes. */
p=tool~plan(startReq,now,"OP-PLAN")
if p==.nil then call fail "plan missing"
if \p~ok then call fail "plan not ok"
if p~code<>"PLAN_READY" then call fail "plan code"
if p~plan~recommendedNodeId<>"NODE-B" then call fail "plan did not rank NODE-B"
if own~current("JOB-MANAGED",now)<>.nil then call fail "plan mutated ownership"

/* Authoritative allocation goes through JobNodeAllocator. */
a=tool~allocate(startReq,now,20000,"OP-ALLOC")
if \a~ok | a~lease==.nil | a~lease~nodeId<>"NODE-B" then call fail "allocate"
if \own~isCurrent(a~lease,now+1) then call fail "allocator ownership not current"

/* Retry of allocation surfaces the same verified placement, not a new owner. */
a2=tool~allocate(startReq,now+2,20000,"OP-ALLOC-RETRY")
if \a2~ok | a2~code<>"PLACED_REPLAY" then call fail "allocation replay"
if a2~lease~placementId<>a~lease~placementId | a2~lease~ownershipEpoch<>a~lease~ownershipEpoch then call fail "allocation replay changed lease"

c=tool~check(startReq,a~lease,now+3,"OP-CHECK")
if \c~ok | c~code<>"PLACEMENT_CURRENT" then call fail "check"

s=tool~start(startReq,a~lease,now+4,"OP-START")
if \s~ok | s~code<>"RUNNING" | s~startResult==.nil then call fail "start"
if s~startResult~executionRef<>"execution:START-MANAGED-1" then call fail "execution ref"
if app~starts<>1 then call fail "runtime start count"

/* Starter replay remains idempotent under the managed tool. */
s2=tool~start(startReq,a~lease,now+5,"OP-START-RETRY")
if \s2~ok | app~starts<>1 | \s2~startResult~replayed then call fail "managed start replay"

if \audit~verify then call fail "audit verify"

r=tool~release(startReq,a~lease,now+6,"OP-RELEASE","qualification complete")
if \r~ok | r~placementHeld then call fail "release"
if own~current("JOB-MANAGED",now+7)<>.nil then call fail "ownership survived release"
if \audit~verify then call fail "audit verify after release"

say "PASS managed plan/check/allocate/start/replay/release through Job-to-Node authority"
exit 0

fail: procedure
 parse arg m
 say "FAIL" m
 exit 1

::class ManagedApp subclass MigratableJobStarterApplication
::attribute starts
::method init
  expose d starts
  use strict arg defArg
  d=defArg; starts=0
::method definition
  expose d
  return d
::method startNew
  expose starts
  use strict arg request, definition
  starts+=1
  return .MigratableJobResumeResult~success("execution:"||request~startId)

::requires "MigratableJobManagedPlacement.cls"
::requires "TestForeignCryptoBootstrap.cls"
