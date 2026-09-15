root = "/mnt/data/queuerexx-dev5-migration-test"
address system "rm -rf " || root
call SysMkDir root
call SysMkDir root || "/running"
call SysMkDir root || "/cancelled"
call SysMkDir root || "/logs"
call SysMkDir root || "/locks"
call SysMkDir root || "/locks/state"

qid = "JOB-MIG-QRX"
jobPath = root || "/running/" || qid || ".job"
s = .Stream~new(jobPath)
if s~open("WRITE REPLACE") \= "READY:" then call fail "cannot create job fixture"
s~lineOut("JOB_ID='" || qid || "'")
s~lineOut("JOB_NAME='migration integration'")
s~lineOut("JOB_CLASS='DEFAULT'")
s~lineOut("PRIORITY='10'")
s~lineOut("COMMAND=('sleep' '100')")
s~lineOut("RUNNER_USED='direct'")
s~lineOut("RUN_PID='99999999'")
s~close

uk = .Array~of("GB")
req = .JobNodeRequirement~new(uk)
placementRequest = .JobPlacementRequest~new(qid, req, "OWNER", 1000000, 1000000)
def = .MigratableJobDefinition~new(qid, placementRequest, "definition:qrx", "PART-1", "OWNER", "OOREXX", "5.3-r13196", "rev-qrx")
source = .JobNodePlacementLease~new("PLACE-S", qid, "NODE-A", "OWNER", 1, 1, 1000, 20000, "req", "cap-a", "obs-a", "1", "", "", "", 1, 0, "")
dest = .JobNodePlacementLease~new("PLACE-D", qid, "NODE-B", "OWNER", 1, 1, 2000, 20000, "req", "cap-b", "obs-b", "1", "", "", "", 3, 0, "")
migration = .MigratableJobMigration~new("MIG-QRX", def, source, 1000)

registry = .QueueMigrationRegistry~new
if \registry~register(migration) then call fail "registry rejected exact framework migration"
if \registry~active(qid) then call fail "NEW migration should be active"
if .QueueMigrationState~fromFrameworkName(.MigratableJobMigrationState~AWAITING_DESTINATION) \= .QueueMigrationState~AWAITING_DESTINATION then call fail "AWAITING_DESTINATION constant mapping failed"
if \.QueueMigrationState~active(.QueueMigrationState~AWAITING_DESTINATION) then call fail "AWAITING_DESTINATION must defer queue liveness interpretation"

record = .QueueStateStore~new(root)~findOne(qid)
if record == .nil | record~state \= .QueueState~RUNNING then call fail "running queue record missing"
obsProvider = .QueueMigrationObservationProvider~new(registry)
obs = obsProvider~observe(record)
if obs~status \= .QueueJobObservation~UNKNOWN then call fail "active migration must defer local stale inference"
if obs~code \= .QueueMigrationObservationProvider~CODE_MIGRATION_IN_PROGRESS then call fail "wrong migration observation code"

/* A health scanner using the overlay must not call the dead local PID stale
 * while the framework owns planned migration continuity. */
aware = .QueueMigrationAwareJobObserver~new(registry)
health = .QueueHealthScanner~new(.QueueStateStore~new(root), aware)~scan
foundStale = .false
foundDeferred = .false
do f over health~findings
  if f~message~pos("stale running job:") == 1 then foundStale = .true
  if f~message~pos("liveness deferred") > 0 then foundDeferred = .true
end
if foundStale then call fail "migration-aware health falsely called source PID stale"
if \foundDeferred then call fail "migration-aware health did not report deferred liveness"

runtime = .GuardCheckingRuntime~new(root)
wrappedRuntime = .QueueRexxMigratableExecutionAdapter~new(runtime, root)
cpResult = wrappedRuntime~pauseAndCheckpoint(def, source, migration~migrationId, 1100)
if cpResult == .nil | \cpResult~ok then call fail "guarded pause/checkpoint failed"
if \runtime~sawPauseLock then call fail "QID lock was not held across pause/checkpoint delegate"

if \testExceptionRelease(root, def, source) then call fail "runtime exception left migration QID lock behind"
manifest = cpResult~manifest
migration~setCheckpoint(manifest, cpResult~transferRef, 1100)
migration~markSourceFenced(1110)
migration~markSourceAdmissionReleased(1111)
migration~setDestinationLease(dest, 1200)
migration~setTransferEvidence("verify:qrx", "storage://NODE-B/CKPT-QRX", 1300)

commit = .QueueRexxMigratableCommitAuthority~new(.AllowCommit~new, root)
decision = commit~authorise(migration, 1400)
if decision == .nil | \decision~allowed then call fail "shared queue authority should allow commit while QID remains running"

resume = wrappedRuntime~resumeFromCheckpoint(def, dest, manifest, "storage://NODE-B/CKPT-QRX", 1410)
if resume == .nil | \resume~ok then call fail "guarded destination resume failed"
if \runtime~sawResumeLock then call fail "QID lock was not held across destination resume delegate"
if .QueueStateStore~new(root)~findOne(qid)~state \= .QueueState~RUNNING then call fail "migration changed authoritative queue state"

/* Now prove a terminal queue transition wins.  Once cancellation acquires the
 * same QID lock and moves the record, destination resume is fail-closed. */
transition = .QueueTransitionService~new(root)
receipt = transition~transition(qid, .QueueState~RUNNING, .QueueState~CANCELLED, .QueueEvent~JOB_CANCELLED)
if \receipt~ok then call fail "cancel transition fixture failed"
resume2 = wrappedRuntime~resumeFromCheckpoint(def, dest, manifest, "storage://NODE-B/CKPT-QRX", 1500)
if resume2~ok then call fail "destination resume bypassed cancelled queue authority"
if resume2~code~pos("QUEUE_AUTHORITY_queue_state_not_running") \= 1 then call fail "unexpected resume denial code " || resume2~code

decision2 = commit~authorise(migration, 1510)
if decision2~allowed then call fail "commit authority bypassed cancelled queue state"

say "PASS exact migratable.job/0.2 integration, AWAITING_DESTINATION mapping, migration-aware health, and QID-locked pause/resume authority"
exit 0


testExceptionRelease: procedure
  use arg root, definition, sourceLease
  bad = .QueueRexxMigratableExecutionAdapter~new(.ThrowingRuntime~new, root)
  signal on syntax name caughtException
  x = bad~pauseAndCheckpoint(definition, sourceLease, "MIG-THROW", 1150)
  signal off syntax
  return .false
caughtException:
  signal off syntax
  lockPath = root || "/locks/state/" || definition~jobId || ".lock"
  return \SysFileExists(lockPath)

fail: procedure
  parse arg message
  say "FAIL" message
  exit 1

::class GuardCheckingRuntime subclass MigratableJobExecutionAdapter
::attribute sawPauseLock get
::attribute sawResumeLock get
::method init
  expose root sawPauseLock sawResumeLock
  use strict arg rootArg
  root = rootArg~string; sawPauseLock = .false; sawResumeLock = .false
::method pauseAndCheckpoint
  expose root sawPauseLock
  use strict arg definition, sourceLease, migrationId, nowEpochMs
  lockPath = root || "/locks/state/" || definition~jobId || ".lock"
  sawPauseLock = SysFileExists(lockPath)
  manifest = .MigratableJobCheckpointManifest~new("CKPT-QRX", definition~jobId, migrationId, definition~partitionId, sourceLease~nodeId, sourceLease~placementId, sourceLease~ownershipEpoch, definition~runtimeId, definition~runtimeGeneration, definition~executableRevision, "state:qrx", "digest:qrx", "inputs:qrx", "outputs:qrx", nowEpochMs, 900, nowEpochMs, 1)
  return .MigratableJobCheckpointResult~success(manifest, "checkpoint://CKPT-QRX")
::method resumeFromCheckpoint
  expose root sawResumeLock
  use strict arg definition, destinationLease, manifest, destinationCheckpointRef, nowEpochMs
  lockPath = root || "/locks/state/" || definition~jobId || ".lock"
  sawResumeLock = SysFileExists(lockPath)
  return .MigratableJobResumeResult~success("execution:" || destinationLease~nodeId)
::method retireSource
  return .true


::class ThrowingRuntime subclass MigratableJobExecutionAdapter
::method pauseAndCheckpoint
  raise syntax 88.900 array("intentional migration runtime failure")
::method resumeFromCheckpoint
  raise syntax 88.900 array("intentional migration runtime failure")
::method retireSource
  return .true

::class AllowCommit subclass MigratableJobCommitAuthority
::method authorise
  use strict arg migration, nowEpochMs
  return .MigratableJobCommitDecision~allow("commit:qrx")

::requires "QueueRexxHealth.cls"
::requires "QueueRexxMigratableJob.cls"
