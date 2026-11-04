/* dev8 repair destination planner semantic smoke.
 * Uses fake provider/source objects; no network or Git process is invoked. */
ref=.StorageRef~new("repair:test","sha256:"||copies("a",64))
obj=.StorageObject~new(ref,"repair-test",100,"application/octet-stream")
locA=.StorageLocation~new("local-a","/safe/a","dom-a",.StorageLocationState~AVAILABLE,"",.true,"sha256:a",.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE,"node-a","VENDOR-A","SITE-A","VENDOR-A/SITE-A")
obj~addLocation(locA)
req=.StorageReplicaRequirement~new(2,2,2,2)

sameProvider=.FakeGitProvider~new("git-same","VENDOR-A","SITE-A","VENDOR-A/SITE-A")
betterProvider=.FakeGitProvider~new("git-better","VENDOR-B","SITE-B","VENDOR-B/SITE-B")
sameDest=.StorageGitRepairDestination~new(sameProvider,999)
betterDest=.StorageGitRepairDestination~new(betterProvider,1)
resolver=.FakeSourceResolver~new(.true)
planner=.StorageRepairDestinationPlanner~new(resolver,.array~of(sameDest,betterDest))
result=planner~repair(obj,req,.directory~new)
call assert result~ok,"planner repaired"
call assert result~value~providerId="git-better","policy gain beats preference"
assessment=.StorageReplicaPolicy~new~assess(obj,req)
call assert assessment~satisfied,"requirement satisfied after admitted replica"
call assert betterProvider~storeCount=1,"better provider stored once"
call assert sameProvider~storeCount=0,"same-domain provider not selected"

obj2=.StorageObject~new(ref,"repair-test-2",100,"application/octet-stream")
obj2~addLocation(locA)
resolver2=.FakeSourceResolver~new(.false)
planner2=.StorageRepairDestinationPlanner~new(resolver2,.array~of(betterDest))
failed=planner2~repair(obj2,req,.directory~new)
call assert \\failed~ok,"unverified source rejected"
call assert failed~code="SOURCE_NOT_VERIFIED","unverified source code"

say "PASS Storage repair destination planner semantic smoke"
exit 0

assert: procedure
  use strict arg condition,label
  if \\condition then do
    say "FAIL" label
    exit 1
  end
  return

::class FakeSourceResolver public
::method init
  expose verified
  use strict arg verifiedArg
  verified=verifiedArg
::method resolve
  expose verified
  use strict arg object,payload
  if verified then return .StorageRepairSourceResult~success("/tmp/fake-source","sha256:verified")
  return .StorageRepairSourceResult~new(.true,"OK","","/tmp/fake-source","",.false)

::class FakeGitPutResult public
::attribute ok get
::attribute code get
::attribute location get
::attribute chunksWritten get
::attribute chunksReused get
::method init
  expose ok code location chunksWritten chunksReused
  use strict arg locationArg
  ok=.true; code="OK"; location=locationArg; chunksWritten=1; chunksReused=0

::class FakeGitProvider public
::attribute providerId get
::attribute vendorId get
::attribute siteId get
::attribute failureDomainId get
::attribute lifecycle get
::attribute storeCount get
::method init
  expose providerId vendorId siteId failureDomainId lifecycle storeCount
  use strict arg providerArg,vendorArg,siteArg,failureArg
  providerId=providerArg; vendorId=vendorArg; siteId=siteArg; failureDomainId=failureArg
  lifecycle=.StorageServiceLifecycle~new(.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE)
  storeCount=0
::method canDurable
  return .true
::method countsAsDurable
  return .true
::method store
  expose providerId vendorId siteId failureDomainId lifecycle storeCount
  use strict arg ref,path,observedAt
  storeCount+=1
  loc=.StorageLocation~new(providerId,"git:test@commit:manifest","git:"||providerId,.StorageLocationState~AVAILABLE,observedAt,.true,ref~digest,.StorageSafetyClass~SAFE,lifecycle~state,"",vendorId,siteId,failureDomainId)
  return .FakeGitPutResult~new(loc)

::requires "../src/StorageRepairPlanner.cls"
