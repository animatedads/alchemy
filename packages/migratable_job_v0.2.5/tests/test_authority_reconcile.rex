call mj_test_install_native_crypto
now=1000
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
jobReq=.JobPlacementRequest~new("JOB-REC",req,"OWNER",1000,1000)
policies=.MigratableJobDestinationPolicyRegistry~new
elig=.JobNodeEligibilityPolicy~new(.array~of(.MigratableJobDestinationAssessor~new(policies)))
reg=.NodeCapabilityRegistry~new
reg~advertiseCapability(.NodeCapabilityStatement~new("NODE-A",1,"cap-a",uk))
reg~observeCapacity(.NodeCapacityObservation~new("NODE-A",1,1,100,10000,4096,9000,8,20000000,0,0,"obs-a"))
reg~advertiseCapability(.NodeCapabilityStatement~new("NODE-B",1,"cap-b",uk))
reg~observeCapacity(.NodeCapacityObservation~new("NODE-B",1,1,100,10000,4096,9000,8,10000000,0,0,"obs-b"))
own=.JobNodeOwnershipRegistry~new
alloc=.JobNodeAllocator~new(reg,elig,.nil,.nil,.nil,"REC",.nil,own)
initial=alloc~allocate(jobReq,now,20000)
if \initial~placed | initial~lease~nodeId<>"NODE-A" then call fail "initial placement"
def=.MigratableJobDefinition~new("JOB-REC",jobReq,"definition:rec","PART-R","OWNER","OOREXX","5.3-r13196","rev-r",.array~new,.array~new,.true,.array~of("NODE-B"))
m=.MigratableJobMigration~new("MIG-REC",def,initial~lease,1100)
cp=.MigratableJobCheckpointManifest~new("CKPT-R",def~jobId,m~migrationId,def~partitionId,initial~lease~nodeId,initial~lease~placementId,initial~lease~ownershipEpoch,def~runtimeId,def~runtimeGeneration,def~executableRevision,"state:r","digest:r","","",1150,1000,1150,1)
m~setCheckpoint(cp,"checkpoint:r",1150)
policies~set(def~jobId,.MigratableJobDestinationPolicy~new(initial~lease~nodeId,.true,.array~of("NODE-B")))

/* Simulate process death after Job-to-Node committed the fence and replacement
 * but before Migratable Job recorded either transition. */
if \own~fence(initial~lease) then call fail "authority fence"
if \alloc~releasePlacement(initial~lease) then call fail "source release"
reg~observeCapacity(.NodeCapacityObservation~new("NODE-B",1,2,1160,10000,8192,18000,16,40000000,0,0,"obs-b2"))
placed=alloc~allocate(jobReq,1170,20000)
if \placed~placed | placed~lease~nodeId<>"NODE-B" then call fail "replacement placement"
if m~sourceFenced | m~sourceAdmissionReleased | m~destinationLease<>.nil then call fail "fixture already mutated"

h=.MigratableJobPlacementHandoff~new(alloc,own)
r=h~reconcile(m,1180)
if \r~ok | \r~changed then call fail "reconcile failed"
if \m~sourceFenced | \m~sourceAdmissionReleased then call fail "source authority not reconstructed"
if m~destinationLease==.nil | m~destinationLease~placementId<>placed~lease~placementId then call fail "destination lease not reconstructed"
if m~destinationLease~ownershipEpoch<=initial~lease~ownershipEpoch then call fail "ownership epoch did not advance"

say "PASS allocator-authoritative reconciliation closes fence/placement journal crash window"
exit 0
fail: procedure
 parse arg m
 say "FAIL" m
 exit 1
::requires "MigratableJob.cls"
::requires "TestForeignCryptoBootstrap.cls"
