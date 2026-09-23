call mj_test_install_native_crypto
/* Edge qualification for planned migration fencing/release and lease reset. */
call testPartialReleaseAndRetire
call testExpiredDestinationReset
say "PASS migration hardening: partial source release retry, nonfatal retire cleanup, expired destination reset/re-placement"
exit 0

testPartialReleaseAndRetire: procedure
  now=1000
  uk=.array~of("GB")
  req=.JobNodeRequirement~new(uk)
  jobReq=.JobPlacementRequest~new("JOB-HARD-1",req,"OWNER",1000000,1000000)
  policyRegistry=.MigratableJobDestinationPolicyRegistry~new
  elig=.JobNodeEligibilityPolicy~new(.array~of(.MigratableJobDestinationAssessor~new(policyRegistry)))
  reg=.NodeCapabilityRegistry~new
  call advertise reg, uk, "NODE-A", 1, 12000000, 100
  call advertise reg, uk, "NODE-B", 1, 6000000, 100
  own=.JobNodeOwnershipRegistry~new
  admission=.FlakyAdmission~new
  alloc=.JobNodeAllocator~new(reg,elig,.nil,.nil,.nil,"HARD-1",admission,own)
  initial=alloc~allocate(jobReq,now,20000)
  if \initial~placed | initial~lease~nodeId<>"NODE-A" then call fail "hard-1 initial placement"
  /* Make B faster only after source placement. */
  ob2=.NodeCapacityObservation~new("NODE-B",1,2,1100,100000,16384,100000,16,30000000,0,0,"obs-b2")
  reg~observeCapacity(ob2)

  def=.MigratableJobDefinition~new("JOB-HARD-1",jobReq,"definition:hard-1","PART-H1","OWNER","OOREXX","5.3-r13196","rev-h1",.array~new,.array~new,.true,.array~of("NODE-B"))
  runtime=.EdgeRuntime~new(.false)
  transfer=.EdgeTransfer~new(.false)
  commit=.EdgeCommit~new
  handoff=.MigratableJobPlacementHandoff~new(alloc,own)
  ledger=.MigratableJobProvenanceLedger~new
  coord=.MigratableJobCoordinator~new(runtime,transfer,commit,handoff,ledger,policyRegistry)
  m=coord~begin("MIG-HARD-1",def,initial~lease,1200)
  ok=coord~step(m,1300,20000,0)
  if ok then call fail "hard-1 should pause on first admission release"
  if m~state<>.MigratableJobMigrationState~PAUSED | m~resumeState<>.MigratableJobMigrationState~PREPARING then call fail "hard-1 wrong pause state"
  if \m~sourceFenced then call fail "hard-1 source fence was not retained after release failure"
  if m~sourceAdmissionReleased then call fail "hard-1 source release should not yet be complete"
  if own~isCurrent(initial~lease,1301) then call fail "hard-1 fenced source remained current"

  ok=coord~resumePaused(m,1400,20000,0)
  if \ok | m~state<>.MigratableJobMigrationState~RUNNING then call fail "hard-1 retry did not complete"
  if \m~sourceAdmissionReleased then call fail "hard-1 source admission release not recorded"
  if runtime~resumeCount<>1 then call fail "hard-1 destination resume count must be exactly one"
  if runtime~retireCount<>1 then call fail "hard-1 source cleanup attempt missing"
  /* retireSource deliberately returns false: this must not replay destination resume. */
  if m~destinationResumed<>.true then call fail "hard-1 destination not marked resumed"
  found=.false
  do e over ledger~events
    if e~kind="SOURCE_RETIRE_DEFERRED" then found=.true
  end
  if \found then call fail "hard-1 deferred source cleanup provenance missing"
  return

testExpiredDestinationReset: procedure
  now=2000
  uk=.array~of("GB")
  req=.JobNodeRequirement~new(uk)
  jobReq=.JobPlacementRequest~new("JOB-HARD-2",req,"OWNER",1000000,1000000)
  policyRegistry=.MigratableJobDestinationPolicyRegistry~new
  elig=.JobNodeEligibilityPolicy~new(.array~of(.MigratableJobDestinationAssessor~new(policyRegistry)))
  reg=.NodeCapabilityRegistry~new
  call advertise reg, uk, "NODE-A", 1, 12000000, 100
  call advertise reg, uk, "NODE-B", 1, 6000000, 100
  own=.JobNodeOwnershipRegistry~new
  alloc=.JobNodeAllocator~new(reg,elig,.nil,.nil,.nil,"HARD-2",.nil,own)
  initial=alloc~allocate(jobReq,now,20000)
  if \initial~placed then call fail "hard-2 initial placement"
  ob2=.NodeCapacityObservation~new("NODE-B",1,2,2100,100000,16384,100000,16,30000000,0,0,"obs-b2")
  reg~observeCapacity(ob2)

  def=.MigratableJobDefinition~new("JOB-HARD-2",jobReq,"definition:hard-2","PART-H2","OWNER","OOREXX","5.3-r13196","rev-h2",.array~new,.array~new,.true,.array~of("NODE-B"))
  runtime=.EdgeRuntime~new(.true)
  transfer=.EdgeTransfer~new(.true)
  commit=.EdgeCommit~new
  handoff=.MigratableJobPlacementHandoff~new(alloc,own)
  ledger=.MigratableJobProvenanceLedger~new
  coord=.MigratableJobCoordinator~new(runtime,transfer,commit,handoff,ledger,policyRegistry)
  m=coord~begin("MIG-HARD-2",def,initial~lease,2200)
  /* 100 ms destination lease; transfer deliberately pauses. */
  ok=coord~step(m,2300,100,1)
  if ok | m~state<>.MigratableJobMigrationState~PAUSED | m~resumeState<>.MigratableJobMigrationState~TRANSFERRING then call fail "hard-2 initial transfer pause"
  oldPlacement=m~destinationLease~placementId
  /* Resume after destination lease expiry. No transfer is allowed against it. */
  ok=coord~resumePaused(m,2500,5000,1)
  if ok then call fail "hard-2 expiry pass should reset and pause"
  if m~state<>.MigratableJobMigrationState~PAUSED | m~resumeState<>.MigratableJobMigrationState~PREPARING then call fail "hard-2 invalid destination did not reset to PREPARING"
  if m~destinationLease<>.nil then call fail "hard-2 invalid destination lease retained"
  if transfer~callCount<>1 then call fail "hard-2 transfer was invoked on expired destination"

  ok=coord~resumePaused(m,2600,5000,0)
  if \ok | m~state<>.MigratableJobMigrationState~RUNNING then call fail "hard-2 re-placement did not complete"
  if m~destinationLease==.nil | m~destinationLease~placementId=oldPlacement then call fail "hard-2 destination was not re-placed"
  if transfer~callCount<>2 then call fail "hard-2 transfer was not repeated exactly once on replacement"
  return

advertise: procedure
  use arg reg, uk, node, gen, speed, epoch
  c=.NodeCapabilityStatement~new(node,gen,"cap-"||node,uk)
  o=.NodeCapacityObservation~new(node,gen,1,epoch,100000,8192,50000,8,speed,0,0,"obs-"||node)
  reg~advertiseCapability(c); reg~observeCapacity(o)
  return

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class FlakyAdmission subclass JobNodeAdmissionAuthority
::attribute reserveCount get
::attribute releaseCount get
::method init
  expose reserveCount releaseCount
  reserveCount=0; releaseCount=0
::method reserve
  expose reserveCount
  use strict arg placementRequest, capability, capacity, leaseDurationMs
  reserveCount+=1
  token="reservation-"||reserveCount
  return .JobNodeAdmissionResult~allow(token,"reservation-ref-"||reserveCount)
::method release
  expose releaseCount
  use strict arg reservation
  releaseCount+=1
  if releaseCount=1 then return .false
  return .true

::class EdgeRuntime subclass MigratableJobExecutionAdapter
::attribute resumeCount get
::attribute retireCount get
::method init
  expose retireSucceeds resumeCount retireCount
  use strict arg retireSucceedsArg=.true
  retireSucceeds=(retireSucceedsArg==.true); resumeCount=0; retireCount=0
::method pauseAndCheckpoint
  use strict arg definition, sourceLease, migrationId, nowEpochMs
  id="CKPT-"||migrationId
  manifest=.MigratableJobCheckpointManifest~new(id,definition~jobId,migrationId,definition~partitionId,sourceLease~nodeId,sourceLease~placementId,sourceLease~ownershipEpoch,definition~runtimeId,definition~runtimeGeneration,definition~executableRevision,"storage:"||id,"sha256:"||id,"inputs","outputs",nowEpochMs,nowEpochMs-100,nowEpochMs,1)
  return .MigratableJobCheckpointResult~success(manifest,"checkpoint://"||id)
::method resumeFromCheckpoint
  expose resumeCount
  use strict arg definition, destinationLease, manifest, destinationCheckpointRef, nowEpochMs
  resumeCount+=1
  return .MigratableJobResumeResult~success("execution:"||destinationLease~nodeId||":"||manifest~checkpointId)
::method retireSource
  expose retireSucceeds retireCount
  use strict arg definition, sourceLease, migrationId, nowEpochMs
  retireCount+=1
  return retireSucceeds

::class EdgeTransfer subclass MigratableJobTransferAdapter
::attribute callCount get
::method init
  expose pauseFirst callCount
  use strict arg pauseFirstArg=.false
  pauseFirst=(pauseFirstArg==.true); callCount=0
::method transfer
  expose pauseFirst callCount
  use strict arg migration, maxChunks=0
  callCount+=1
  if pauseFirst & callCount=1 then return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~PAUSED,"","partial",1024,"bounded pause")
  return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~COMPLETED,"sha256:verified:"||migration~migrationId,"storage://"||migration~destinationLease~nodeId||"/"||migration~migrationId,4096,"")

::class EdgeCommit subclass MigratableJobCommitAuthority
::method authorise
  use strict arg migration, nowEpochMs
  if migration~transferVerificationRef="" then return .MigratableJobCommitDecision~deny("NO_TRANSFER_EVIDENCE")
  return .MigratableJobCommitDecision~allow("commit:edge")

::requires "MigratableJob.cls"
::requires "TestForeignCryptoBootstrap.cls"
