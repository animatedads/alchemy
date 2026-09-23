call mj_test_install_native_crypto
parse source . . testFile
root=filespec("LOCATION",testFile)||"/tmp-intrinsic"
call SysFileDelete root||".journal"
call SysFileDelete root||".events"

now=1000
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
jobReq=.JobPlacementRequest~new("JOB-IDUR",req,"OWNER",1000000,1000000)
policies=.MigratableJobDestinationPolicyRegistry~new
elig=.JobNodeEligibilityPolicy~new(.array~of(.MigratableJobDestinationAssessor~new(policies)))
reg=.NodeCapabilityRegistry~new
reg~advertiseCapability(.NodeCapabilityStatement~new("NODE-A",1,"cap-a",uk))
reg~observeCapacity(.NodeCapacityObservation~new("NODE-A",1,1,100,100000,8192,50000,8,12000000,0,0,"obs-a"))
reg~advertiseCapability(.NodeCapabilityStatement~new("NODE-B",1,"cap-b",uk))
reg~observeCapacity(.NodeCapacityObservation~new("NODE-B",1,1,100,100000,8192,50000,8,6000000,0,0,"obs-b"))
own=.JobNodeOwnershipRegistry~new
alloc=.JobNodeAllocator~new(reg,elig,.nil,.nil,.nil,"IDUR",.nil,own)
initial=alloc~allocate(jobReq,now,20000)
if \initial~placed then call fail "initial placement"
reg~observeCapacity(.NodeCapacityObservation~new("NODE-B",1,2,1100,100000,16384,100000,16,30000000,0,0,"obs-b2"))
def=.MigratableJobDefinition~new("JOB-IDUR",jobReq,"definition:idur","PART-I","OWNER","OOREXX","5.3-r13196","rev-i",.array~new,.array~new,.true,.array~of("NODE-B"))
runtime=.Runtime~new
handoff=.MigratableJobPlacementHandoff~new(alloc,own)
ledger=.MigratableJobProvenanceLedger~new(root||".events")
journal=.MigratableJobDurableJournal~new(root||".journal")
coord=.MigratableJobCoordinator~new(runtime,.PauseTransfer~new,.Commit~new,handoff,ledger,policies,journal)
m=coord~begin("MIG-IDUR",def,initial~lease,1200)
if coord~step(m,1300,20000,1) then call fail "pause expected"
if m~state<>.MigratableJobMigrationState~PAUSED | m~resumeState<>.MigratableJobMigrationState~TRANSFERRING then call fail "wrong pause state"

/* No caller append here: the coordinator itself must have persisted the state. */
journal2=.MigratableJobDurableJournal~new(root||".journal")
ledger2=.MigratableJobProvenanceLedger~new(root||".events")
coord2=.MigratableJobCoordinator~new(runtime,.CompleteTransfer~new,.Commit~new,handoff,ledger2,policies,journal2)
snap=coord2~restore(def,1400)
if snap==.nil | \snap~valid then call fail "coordinator restore failed"
m2=snap~migration
if m2~state<>.MigratableJobMigrationState~PAUSED | m2~destinationLease==.nil then call fail "intrinsic snapshot incomplete"
if \coord2~resumePaused(m2,1500,20000,0) then call fail "restored migration did not complete"
if m2~state<>.MigratableJobMigrationState~RUNNING then call fail "not running"

journal3=.MigratableJobDurableJournal~new(root||".journal")
snap3=journal3~loadLatest(def)
if \snap3~valid | snap3~migration~state<>.MigratableJobMigrationState~RUNNING then call fail "RUNNING not intrinsically durable"

say "PASS coordinator-intrinsic journaling across pause, restart, resume and RUNNING"
exit 0

fail: procedure
 parse arg m
 say "FAIL" m
 exit 1

::class Runtime subclass MigratableJobExecutionAdapter
::method pauseAndCheckpoint
  use strict arg d,s,mid,now
  c=.MigratableJobCheckpointManifest~new("CKPT-I",d~jobId,mid,d~partitionId,s~nodeId,s~placementId,s~ownershipEpoch,d~runtimeId,d~runtimeGeneration,d~executableRevision,"state:i","digest:i","","",now,now-20,now,1)
  return .MigratableJobCheckpointResult~success(c,"checkpoint:i")
::method resumeFromCheckpoint
  use strict arg d,l,c,r,now
  return .MigratableJobResumeResult~success("execution:intrinsic:"||l~nodeId)
::method retireSource
  return .true

::class PauseTransfer subclass MigratableJobTransferAdapter
::method transfer
  return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~PAUSED,"","partial",100,"pause")
::class CompleteTransfer subclass MigratableJobTransferAdapter
::method transfer
  return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~COMPLETED,"verify:i","dest:i",1000,"")
::class Commit subclass MigratableJobCommitAuthority
::method authorise
  return .MigratableJobCommitDecision~allow("commit:i")

::requires "MigratableJobDurable.cls"
::requires "TestForeignCryptoBootstrap.cls"
