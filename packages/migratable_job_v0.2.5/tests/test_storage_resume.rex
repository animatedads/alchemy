call mj_test_install_native_crypto
parse source . . testFile
testRoot=filespec("LOCATION",testFile)||"/"
/* Qualification against Storage Fabric v0.1-dev7 resumable local transport. */
root=testRoot||"tmp-storage"
address system "rm -rf "||root
call SysMkDir root
sourcePath=root||"/source.checkpoint"
destRoot=root||"/destinations"

now=1000
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
jobReq=.JobPlacementRequest~new("JOB-STORAGE",req,"OWNER",1000000,1000000)
policyRegistry=.MigratableJobDestinationPolicyRegistry~new
elig=.JobNodeEligibilityPolicy~new(.array~of(.MigratableJobDestinationAssessor~new(policyRegistry)))
reg=.NodeCapabilityRegistry~new
ca=.NodeCapabilityStatement~new("NODE-A",1,"cap-a",uk)
oa=.NodeCapacityObservation~new("NODE-A",1,1,100,100000,8192,50000,8,12000000,0,0,"obs-a")
cb=.NodeCapabilityStatement~new("NODE-B",1,"cap-b",uk)
ob=.NodeCapacityObservation~new("NODE-B",1,1,100,100000,8192,50000,8,6000000,0,0,"obs-b")
reg~advertiseCapability(ca); reg~observeCapacity(oa); reg~advertiseCapability(cb); reg~observeCapacity(ob)
own=.JobNodeOwnershipRegistry~new
alloc=.JobNodeAllocator~new(reg,elig,.nil,.nil,.nil,"STORAGE-Q",.nil,own)
initial=alloc~allocate(jobReq,now,20000)
if \initial~placed | initial~lease~nodeId<>"NODE-A" then call fail "initial placement"
ob2=.NodeCapacityObservation~new("NODE-B",1,2,1100,100000,16384,100000,16,30000000,0,0,"obs-b2")
reg~observeCapacity(ob2)

def=.MigratableJobDefinition~new("JOB-STORAGE",jobReq,"definition:storage","PART-S","OWNER","OOREXX","5.3-r13196","rev-s1",.array~of("input:test"),.array~new,.true,.array~of("NODE-B"))
runtime=.StorageRuntime~new(sourcePath)
engine=.StorageResumableTransferEngine~new(1024)
resolver=.MigratableJobLocalFileTransferResolver~new(destRoot)
transfer=.MigratableJobStorageTransferAdapter~new(engine,resolver)
commit=.StorageCommit~new
handoff=.MigratableJobPlacementHandoff~new(alloc,own)
ledger=.MigratableJobProvenanceLedger~new
coord=.MigratableJobCoordinator~new(runtime,transfer,commit,handoff,ledger,policyRegistry)
m=coord~begin("MIG-STORAGE",def,initial~lease,1200)

/* Two 1KiB chunks, then pause. Storage Fabric writes a durable transfer
 * checkpoint before the coordinator reports PAUSED. */
ok=coord~step(m,1300,20000,2)
if ok then call fail "bounded storage transfer unexpectedly completed"
if m~state<>.MigratableJobMigrationState~PAUSED | m~resumeState<>.MigratableJobMigrationState~TRANSFERRING then call fail "storage transfer did not pause in TRANSFERRING"
dest=destRoot||"/NODE-B/MIG-STORAGE.checkpoint"
if stream(dest,"c","query exists")="" then call fail "partial destination missing"
partial=stream(dest,"c","query size")+0
if partial<>2048 then call fail "unexpected partial destination size "||partial
if stream(dest||".xfer.a","c","query exists")="" & stream(dest||".xfer.b","c","query exists")="" then call fail "Storage checkpoint slots missing"

/* A fresh resolver plan is built on retry; Storage Fabric recognises the
 * transfer identity and resumes at the exact acknowledged byte offset. */
ok=coord~resumePaused(m,1400,20000,0)
if \ok | m~state<>.MigratableJobMigrationState~RUNNING then call fail "resumed storage migration did not complete"
if m~transferVerificationRef="" then call fail "verification reference missing"
if m~destinationCheckpointRef<>dest then call fail "destination checkpoint reference mismatch"
if stream(dest,"c","query size")+0<>stream(sourcePath,"c","query size")+0 then call fail "destination size mismatch"
sourceData=charin(sourcePath,1,stream(sourcePath,"c","query size")); call stream sourcePath,"c","close"
destData=charin(dest,1,stream(dest,"c","query size")); call stream dest,"c","close"
if sourceData<>destData then call fail "destination bytes mismatch"
if runtime~resumeCount<>1 then call fail "runtime resume count"

say "PASS Storage Fabric resumable checkpoint transfer and verified migration resume"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class StorageRuntime subclass MigratableJobExecutionAdapter
::attribute resumeCount get
::method init
  expose sourcePath resumeCount
  use strict arg sourcePathArg
  sourcePath=sourcePathArg~string; resumeCount=0
::method pauseAndCheckpoint
  expose sourcePath
  use strict arg definition, sourceLease, migrationId, nowEpochMs
  content=""
  do i=1 to 12
    content=content||"checkpoint-block-"||i~right(3,"0")||":"||copies("ABCDEFGHIJKLMNOPQRSTUVWXYZ012345",31)||"0a"x
  end
  call charout sourcePath,content,1
  call stream sourcePath,"c","close"
  digest="fixture-state-digest"
  manifest=.MigratableJobCheckpointManifest~new("CKPT-STORAGE",definition~jobId,migrationId,definition~partitionId,sourceLease~nodeId,sourceLease~placementId,sourceLease~ownershipEpoch,definition~runtimeId,definition~runtimeGeneration,definition~executableRevision,"file:"||sourcePath,digest,"inputs:test","outputs:test",nowEpochMs,900,nowEpochMs,1)
  return .MigratableJobCheckpointResult~success(manifest,sourcePath)
::method resumeFromCheckpoint
  expose resumeCount
  use strict arg definition, destinationLease, manifest, destinationCheckpointRef, nowEpochMs
  resumeCount+=1
  if stream(destinationCheckpointRef,"c","query exists")="" then return .MigratableJobResumeResult~failure("DESTINATION_CHECKPOINT_MISSING")
  return .MigratableJobResumeResult~success("execution:storage:"||destinationLease~nodeId)
::method retireSource
  return .true

::class StorageCommit subclass MigratableJobCommitAuthority
::method authorise
  use strict arg migration, nowEpochMs
  if migration~transferVerificationRef="" then return .MigratableJobCommitDecision~deny("NO_VERIFICATION")
  return .MigratableJobCommitDecision~allow("commit:storage")

::requires "MigratableJobStorageAdapter.cls"
::requires "TestForeignCryptoBootstrap.cls"
