call mj_test_install_native_crypto
now=1000
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
jobReq=.JobPlacementRequest~new("JOB-MIG-1",req,"OWNER",1000000,1000000)

policyRegistry=.MigratableJobDestinationPolicyRegistry~new
assessors=.array~of(.MigratableJobDestinationAssessor~new(policyRegistry))
elig=.JobNodeEligibilityPolicy~new(assessors)
reg=.NodeCapabilityRegistry~new

ca=.NodeCapabilityStatement~new("NODE-A",1,"cap-a",uk)
oa=.NodeCapacityObservation~new("NODE-A",1,1,100,100000,8192,50000,8,12000000,0,0,"obs-a")
cb=.NodeCapabilityStatement~new("NODE-B",1,"cap-b",uk)
ob=.NodeCapacityObservation~new("NODE-B",1,1,100,100000,8192,50000,8,6000000,0,0,"obs-b")
reg~advertiseCapability(ca); reg~observeCapacity(oa)
reg~advertiseCapability(cb); reg~observeCapacity(ob)

own=.JobNodeOwnershipRegistry~new
alloc=.JobNodeAllocator~new(reg,elig,.nil,.nil,.nil,"MIG-TEST",.nil,own)
initial=alloc~allocate(jobReq,now,20000)
if \initial~placed then call fail "initial placement failed"
if initial~lease~nodeId<>"NODE-A" then call fail "initial source should be NODE-A"

/* Faster capacity appears on NODE-B before the planned handoff. */
ob2=.NodeCapacityObservation~new("NODE-B",1,2,1100,100000,16384,100000,16,30000000,0,0,"obs-b2")
if \reg~observeCapacity(ob2) then call fail "updated destination capacity rejected"

def=.MigratableJobDefinition~new("JOB-MIG-1",jobReq,"definition:job-mig-1","PART-7","OWNER","OOREXX","5.3-r13196","rev-a1",.array~of("input:sha256:aaa"),.array~new,.true,.array~of("NODE-B"))
runtime=.TestMigrationRuntime~new
transfer=.TestMigrationTransfer~new
commit=.TestCommitAuthority~new
handoff=.MigratableJobPlacementHandoff~new(alloc,own)
ledger=.MigratableJobProvenanceLedger~new
coord=.MigratableJobCoordinator~new(runtime,transfer,commit,handoff,ledger,policyRegistry)

m=coord~begin("MIG-0001",def,initial~lease,1200)
if m~state<>.MigratableJobMigrationState~NEW then call fail "begin state"
ok=coord~step(m,1300,20000,0)
if \ok then call fail "migration did not complete"
if m~state<>.MigratableJobMigrationState~RUNNING then call fail "final state not RUNNING"
if m~destinationLease==.nil then call fail "destination lease missing"
if m~destinationLease~nodeId<>"NODE-B" then call fail "planned migration did not select NODE-B"
if own~isCurrent(initial~lease,1400) then call fail "source lease survived ownership fence"
if \own~isCurrent(m~destinationLease,1400) then call fail "destination is not current owner"
if m~destinationLease~ownershipEpoch<=initial~lease~ownershipEpoch then call fail "ownership epoch did not advance"
if m~transferVerificationRef<>"sha256:checkpoint-verified" then call fail "transfer evidence missing"
if m~commitEvidenceRef<>"commit:test-authority" then call fail "commit evidence missing"
if ledger~events~items<7 then call fail "provenance event chain too short"
if ledger~lastDigest="" then call fail "provenance digest missing"
if runtime~pauseCount<>1 | runtime~resumeCount<>1 | runtime~retireCount<>1 then call fail "runtime calls wrong"

say "PASS planned live-node migration, checkpoint binding, fencing, re-placement, transfer, commit and provenance"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class TestMigrationRuntime subclass MigratableJobExecutionAdapter
::attribute pauseCount
::attribute resumeCount
::attribute retireCount
::method init
  expose pauseCount resumeCount retireCount
  pauseCount=0; resumeCount=0; retireCount=0
::method pauseAndCheckpoint
  expose pauseCount
  use strict arg definition, sourceLease, migrationId, nowEpochMs
  pauseCount+=1
  manifest=.MigratableJobCheckpointManifest~new("CKPT-1",definition~jobId,migrationId,definition~partitionId,sourceLease~nodeId,sourceLease~placementId,sourceLease~ownershipEpoch,definition~runtimeId,definition~runtimeGeneration,definition~executableRevision,"storage:checkpoint:1","sha256:state-1","inputs:manifest:1","outputs:manifest:1",nowEpochMs,900,nowEpochMs,1)
  return .MigratableJobCheckpointResult~success(manifest,"checkpoint://CKPT-1")
::method resumeFromCheckpoint
  expose resumeCount
  use strict arg definition, destinationLease, manifest, destinationCheckpointRef, nowEpochMs
  resumeCount+=1
  if destinationLease~jobId<>definition~jobId then return .MigratableJobResumeResult~failure("JOB_MISMATCH")
  if destinationCheckpointRef="" then return .MigratableJobResumeResult~failure("CHECKPOINT_REF_MISSING")
  return .MigratableJobResumeResult~success("execution:"||destinationLease~nodeId||":"||manifest~checkpointId)
::method retireSource
  expose retireCount
  use strict arg definition, sourceLease, migrationId, nowEpochMs
  retireCount+=1
  return .true

::class TestMigrationTransfer subclass MigratableJobTransferAdapter
::method transfer
  use strict arg migration, maxChunks=0
  return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~COMPLETED,"sha256:checkpoint-verified","storage://NODE-B/CKPT-1",4096,"")

::class TestCommitAuthority subclass MigratableJobCommitAuthority
::method authorise
  use strict arg migration, nowEpochMs
  if migration~transferVerificationRef="" then return .MigratableJobCommitDecision~deny("TRANSFER_NOT_VERIFIED")
  return .MigratableJobCommitDecision~allow("commit:test-authority")

::requires "MigratableJob.cls"
::requires "TestForeignCryptoBootstrap.cls"
