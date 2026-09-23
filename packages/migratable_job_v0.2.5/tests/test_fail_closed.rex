call mj_test_install_native_crypto
/* Fail-closed qualification without a live allocator: nil adapter outcomes and
 * binding violations must produce state, not NIL-method crashes. */
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
pr=.JobPlacementRequest~new("JOB-FC",req,"OWNER",1000,1000)
def=.MigratableJobDefinition~new("JOB-FC",pr,"definition:fc","PART-FC","OWNER","OOREXX","5.3-r13196","rev-fc")
source=.JobNodePlacementLease~new("PLACE-S","JOB-FC","NODE-A","OWNER",1,1,1000,10000,"req","cap","obs","1","","","",1,0,"")

/* 1. No checkpoint result: pause fail-closed rather than dereference NIL. */
m1=.MigratableJobMigration~new("MIG-FC-1",def,source,1100)
c1=.MigratableJobCoordinator~new(.NilCheckpointRuntime~new,.GoodTransfer~new,.GoodCommit~new,.FakeHandoff~new)
if c1~step(m1,1200,5000,0) then call fail "nil checkpoint unexpectedly completed"
if m1~state<>.MigratableJobMigrationState~PAUSED | m1~failureCode<>"CHECKPOINT_FAILED" then call fail "nil checkpoint not fail-closed"

/* 2. A checkpoint bound to a different source placement is an integrity
 * failure, not a recoverable pause. */
m2=.MigratableJobMigration~new("MIG-FC-2",def,source,1100)
c2=.MigratableJobCoordinator~new(.BadBindingRuntime~new,.GoodTransfer~new,.GoodCommit~new,.FakeHandoff~new)
if c2~step(m2,1200,5000,0) then call fail "bad checkpoint unexpectedly completed"
if m2~state<>.MigratableJobMigrationState~FAILED | m2~failureCode<>"CHECKPOINT_BINDING_INVALID" then call fail "bad checkpoint binding did not fail integrity"

/* 3. Missing commit-authority decision must pause COMMITTING. */
m3=.MigratableJobMigration~new("MIG-FC-3",def,source,1100)
c3=.MigratableJobCoordinator~new(.GoodRuntime~new,.GoodTransfer~new,.NilCommit~new,.FakeHandoff~new)
if c3~step(m3,1200,5000,0) then call fail "nil commit unexpectedly completed"
if m3~state<>.MigratableJobMigrationState~PAUSED | m3~resumeState<>.MigratableJobMigrationState~COMMITTING | m3~failureCode<>"COMMIT_DENIED" then call fail "nil commit did not pause fail-closed"

say "PASS fail-closed checkpoint/result/binding/commit authority paths"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class FakeHandoff
::method fenceSource
  use strict arg m, now
  m~markSourceFenced(now); m~markSourceAdmissionReleased(now)
  return .JobNodePlacementDecision~new(.true,"FENCED",m~sourceLease)
::method allocateDestination
  use strict arg m, now, leaseMs=30000
  lease=.JobNodePlacementLease~new("PLACE-D-"||m~migrationId,m~definition~jobId,"NODE-B","OWNER",1,1,now,now+leaseMs,"req","cap","obs","1","","","",3,0,"")
  m~setDestinationLease(lease,now)
  return .JobNodePlacementDecision~new(.true,"PLACED",lease)
::method verifyDestination
  return .true
::method releaseDestination
  return .true

::class NilCheckpointRuntime subclass MigratableJobExecutionAdapter
::method pauseAndCheckpoint
  return .nil
::method resumeFromCheckpoint
  return .nil
::method retireSource
  return .true

::class BadBindingRuntime subclass MigratableJobExecutionAdapter
::method pauseAndCheckpoint
  use strict arg definition, sourceLease, migrationId, now
  c=.MigratableJobCheckpointManifest~new("CKPT-BAD",definition~jobId,migrationId,definition~partitionId,sourceLease~nodeId,"WRONG-PLACEMENT",sourceLease~ownershipEpoch,definition~runtimeId,definition~runtimeGeneration,definition~executableRevision,"state","digest","","",now,now-10,now,1)
  return .MigratableJobCheckpointResult~success(c,"checkpoint://bad")
::method resumeFromCheckpoint
  return .nil
::method retireSource
  return .true

::class GoodRuntime subclass MigratableJobExecutionAdapter
::method pauseAndCheckpoint
  use strict arg definition, sourceLease, migrationId, now
  c=.MigratableJobCheckpointManifest~new("CKPT-GOOD",definition~jobId,migrationId,definition~partitionId,sourceLease~nodeId,sourceLease~placementId,sourceLease~ownershipEpoch,definition~runtimeId,definition~runtimeGeneration,definition~executableRevision,"state","digest","","",now,now-10,now,1)
  return .MigratableJobCheckpointResult~success(c,"checkpoint://good")
::method resumeFromCheckpoint
  return .MigratableJobResumeResult~success("execution")
::method retireSource
  return .true

::class GoodTransfer subclass MigratableJobTransferAdapter
::method transfer
  use strict arg m, maxChunks=0
  return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~COMPLETED,"verify","checkpoint://dest",10,"")

::class GoodCommit subclass MigratableJobCommitAuthority
::method authorise
  return .MigratableJobCommitDecision~allow("commit")

::class NilCommit subclass MigratableJobCommitAuthority
::method authorise
  return .nil

::requires "MigratableJob.cls"
::requires "TestForeignCryptoBootstrap.cls"
