call mj_test_install_native_crypto
parse source . . testFile
root=filespec("LOCATION",testFile)||"/tmp-durable"
call SysFileDelete root||".journal"
call SysFileDelete root||".events"

now=1000
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
jobReq=.JobPlacementRequest~new("JOB-MIG-D",req,"OWNER",1000000,1000000)
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
ob2=.NodeCapacityObservation~new("NODE-B",1,2,1100,100000,16384,100000,16,30000000,0,0,"obs-b2")
reg~observeCapacity(ob2)

def=.MigratableJobDefinition~new("JOB-MIG-D",jobReq,"definition:job-mig-d","PART-D","OWNER","OOREXX","5.3-r13196","rev-d1",.array~of("input:sha256:ddd"),.array~new,.true,.array~of("NODE-B"))
runtime=.DurableRuntime~new
transfer=.PauseOnceTransfer~new
commit=.DurableCommit~new
handoff=.MigratableJobPlacementHandoff~new(alloc,own)
ledger=.MigratableJobProvenanceLedger~new(root||".events")
coord=.MigratableJobCoordinator~new(runtime,transfer,commit,handoff,ledger,policyRegistry)
m=coord~begin("MIG-DURABLE",def,initial~lease,1200)

/* First pass deliberately pauses in TRANSFERRING after source has been fenced
 * and a destination lease has been acquired. */
ok=coord~step(m,1300,20000,1)
if ok then call fail "first pass unexpectedly completed"
if m~state<>.MigratableJobMigrationState~PAUSED then call fail "migration should be PAUSED"
if m~resumeState<>.MigratableJobMigrationState~TRANSFERRING then call fail "wrong resume state"
if \m~sourceFenced then call fail "source should be fenced before transfer pause"
if m~destinationLease==.nil then call fail "destination lease should already exist"

dj=.MigratableJobDurableJournal~new(root||".journal")
if \dj~append(m) then call fail "durable append failed"
oldDigest=ledger~lastDigest; oldEvents=ledger~events~items

/* Simulate a coordinator/process restart: reconstruct transaction and reload
 * the hash-chained provenance file. JNA ownership state is authoritative and
 * is still present here; in a real restart it is restored by JNA durable state
 * before migration recovery. */
dj2=.MigratableJobDurableJournal~new(root||".journal")
snap=dj2~loadLatest(def)
if \snap~valid then call fail "durable restore failed: "||snap~code
m2=snap~migration
if m2~state<>.MigratableJobMigrationState~PAUSED then call fail "restored state wrong"
if m2~resumeState<>.MigratableJobMigrationState~TRANSFERRING then call fail "restored resume state wrong"
if m2~destinationLease==.nil | m2~destinationLease~nodeId<>"NODE-B" then call fail "restored destination lease wrong"
if m2~checkpointManifest==.nil | m2~checkpointManifest~checkpointId<>"CKPT-D" then call fail "restored checkpoint wrong"
if \m2~sourceFenced then call fail "restored source fence missing"

ledger2=.MigratableJobProvenanceLedger~new(root||".events")
if ledger2~events~items<>oldEvents then call fail "provenance reload count mismatch"
if ledger2~lastDigest<>oldDigest then call fail "provenance chain head mismatch"

/* New transfer adapter completes on retry from the same migration identity. */
transfer2=.CompleteTransfer~new
coord2=.MigratableJobCoordinator~new(runtime,transfer2,commit,handoff,ledger2,policyRegistry)
ok2=coord2~resumePaused(m2,1500,20000,0)
if \ok2 then call fail "restored migration did not complete"
if m2~state<>.MigratableJobMigrationState~RUNNING then call fail "restored final state not RUNNING"
if ledger2~events~items<=oldEvents then call fail "provenance did not continue after restart"
if ledger2~lastDigest=oldDigest then call fail "provenance chain did not advance"

/* Re-open again to prove the appended post-restart chain validates. */
ledger3=.MigratableJobProvenanceLedger~new(root||".events")
if ledger3~lastDigest<>ledger2~lastDigest then call fail "post-restart provenance head not durable"

say "PASS durable migration restart and hash-chained provenance continuation"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class DurableRuntime subclass MigratableJobExecutionAdapter
::method pauseAndCheckpoint
  use strict arg definition, sourceLease, migrationId, nowEpochMs
  manifest=.MigratableJobCheckpointManifest~new("CKPT-D",definition~jobId,migrationId,definition~partitionId,sourceLease~nodeId,sourceLease~placementId,sourceLease~ownershipEpoch,definition~runtimeId,definition~runtimeGeneration,definition~executableRevision,"storage:checkpoint:D","sha256:state-D","inputs:D","outputs:D",nowEpochMs,900,nowEpochMs,2)
  return .MigratableJobCheckpointResult~success(manifest,"checkpoint://CKPT-D")
::method resumeFromCheckpoint
  use strict arg definition, destinationLease, manifest, destinationCheckpointRef, nowEpochMs
  return .MigratableJobResumeResult~success("execution:durable:"||destinationLease~nodeId)
::method retireSource
  return .true

::class PauseOnceTransfer subclass MigratableJobTransferAdapter
::method transfer
  use strict arg migration, maxChunks=0
  return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~PAUSED,"","storage://partial",2048,"qualification pause")

::class CompleteTransfer subclass MigratableJobTransferAdapter
::method transfer
  use strict arg migration, maxChunks=0
  return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~COMPLETED,"sha256:durable-ok","storage://NODE-B/CKPT-D",8192,"")

::class DurableCommit subclass MigratableJobCommitAuthority
::method authorise
  use strict arg migration, nowEpochMs
  return .MigratableJobCommitDecision~allow("commit:durable")

::requires "MigratableJobDurable.cls"
::requires "TestForeignCryptoBootstrap.cls"
