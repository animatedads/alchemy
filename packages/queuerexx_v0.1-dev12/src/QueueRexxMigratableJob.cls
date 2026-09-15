/* QueueRexxMigratableJob.cls - Migratable Job v0.2.4 integration, v0.1-dev11.
 *
 * QueueRexx does not duplicate the migration state machine.  The supplied
 * migratable.job/0.2 package remains migration authority.  This adapter binds
 * that lifecycle to QueueRexx's single-QID filesystem authority and state lock.
 */

::class QueueMigrationState public
::constant UNKNOWN 0
::constant NEW 1
::constant PREPARING 2
::constant READY 3
::constant TRANSFERRING 4
::constant COMMITTING 5
::constant AWAITING_DESTINATION 6
::constant RUNNING 7
::constant PAUSED 8
::constant FAILED 9
::constant NAME_UNKNOWN "UNKNOWN"

::method fromFrameworkName class
  use arg valueArg
  if valueArg == .nil then return self~UNKNOWN
  value = valueArg~string~upper
  select
    when value == .MigratableJobMigrationState~NEW then return self~NEW
    when value == .MigratableJobMigrationState~PREPARING then return self~PREPARING
    when value == .MigratableJobMigrationState~READY then return self~READY
    when value == .MigratableJobMigrationState~TRANSFERRING then return self~TRANSFERRING
    when value == .MigratableJobMigrationState~COMMITTING then return self~COMMITTING
    when value == .MigratableJobMigrationState~AWAITING_DESTINATION then return self~AWAITING_DESTINATION
    when value == .MigratableJobMigrationState~RUNNING then return self~RUNNING
    when value == .MigratableJobMigrationState~PAUSED then return self~PAUSED
    when value == .MigratableJobMigrationState~FAILED then return self~FAILED
    otherwise return self~UNKNOWN
  end

::method name class
  use arg valueArg
  value = valueArg + 0
  select
    when value == self~NEW then return .MigratableJobMigrationState~NEW
    when value == self~PREPARING then return .MigratableJobMigrationState~PREPARING
    when value == self~READY then return .MigratableJobMigrationState~READY
    when value == self~TRANSFERRING then return .MigratableJobMigrationState~TRANSFERRING
    when value == self~COMMITTING then return .MigratableJobMigrationState~COMMITTING
    when value == self~AWAITING_DESTINATION then return .MigratableJobMigrationState~AWAITING_DESTINATION
    when value == self~RUNNING then return .MigratableJobMigrationState~RUNNING
    when value == self~PAUSED then return .MigratableJobMigrationState~PAUSED
    when value == self~FAILED then return .MigratableJobMigrationState~FAILED
    otherwise return self~NAME_UNKNOWN
  end

::method active class
  use arg valueArg
  value = valueArg + 0
  return value == self~NEW | value == self~PREPARING | value == self~READY | value == self~TRANSFERRING | value == self~COMMITTING | value == self~AWAITING_DESTINATION | value == self~PAUSED

::class QueueMigrationEvent public
::constant STARTED "job_migration_started"
::constant PAUSED "job_migration_paused"
::constant RUNNING "job_migration_running"
::constant DESTINATION_RESUMED "job_migration_destination_resumed"
::constant FAILED "job_migration_failed"
::constant CHECKPOINTED "job_migration_checkpointed"
::constant RESUME_DENIED "job_migration_resume_denied"

::class QueueMigrationCode public
::constant OK 1
::constant QID_MISMATCH 2
::constant QID_NOT_FOUND 3
::constant DUPLICATE_QID 4
::constant QUEUE_STATE_NOT_RUNNING 5
::constant LOCK_TIMEOUT 6
::constant FRAMEWORK_MIGRATION_REQUIRED 7
::constant DELEGATE_RESULT_MISSING 8

::constant NAME_OK "ok"
::constant NAME_QID_MISMATCH "qid_mismatch"
::constant NAME_QID_NOT_FOUND "qid_not_found"
::constant NAME_DUPLICATE_QID "duplicate_qid"
::constant NAME_QUEUE_STATE_NOT_RUNNING "queue_state_not_running"
::constant NAME_LOCK_TIMEOUT "lock_timeout"
::constant NAME_FRAMEWORK_MIGRATION_REQUIRED "framework_migration_required"
::constant NAME_DELEGATE_RESULT_MISSING "delegate_result_missing"

::method name class
  use arg code
  select
    when code == self~OK then return self~NAME_OK
    when code == self~QID_MISMATCH then return self~NAME_QID_MISMATCH
    when code == self~QID_NOT_FOUND then return self~NAME_QID_NOT_FOUND
    when code == self~DUPLICATE_QID then return self~NAME_DUPLICATE_QID
    when code == self~QUEUE_STATE_NOT_RUNNING then return self~NAME_QUEUE_STATE_NOT_RUNNING
    when code == self~LOCK_TIMEOUT then return self~NAME_LOCK_TIMEOUT
    when code == self~FRAMEWORK_MIGRATION_REQUIRED then return self~NAME_FRAMEWORK_MIGRATION_REQUIRED
    when code == self~DELEGATE_RESULT_MISSING then return self~NAME_DELEGATE_RESULT_MISSING
    otherwise return "unknown"
  end

::class QueueMigrationGuardResult public
::attribute ok get
::attribute code get
::attribute record get
::attribute detail get
::attribute lock get
::method init
  expose ok code record detail lock
  use arg okArg, codeArg, recordArg = .nil, detailArg = "", lockArg = .nil
  ok = (okArg == .true); code = codeArg + 0; record = recordArg; detail = detailArg~string; lock = lockArg
::method success class
  use arg recordArg, lockArg = .nil
  return self~new(.true, .QueueMigrationCode~OK, recordArg, "", lockArg)
::method failure class
  use arg codeArg, detailArg = ""
  return self~new(.false, codeArg, .nil, detailArg, .nil)

/* In-memory index only.  Durable migration state remains owned by
 * MigratableJobDurableJournal and Job-to-Node's durable ownership state. */
::class QueueMigrationRegistry public
::method init
  expose migrations
  migrations = .Directory~new
::method register guarded
  expose migrations
  use strict arg migration
  if migration == .nil then return .false
  qid = migration~definition~jobId~string
  if qid == "" then return .false
  migrations[qid] = migration
  return .true
::method get guarded
  expose migrations
  use strict arg qidArg
  qid = qidArg~string
  if migrations~hasIndex(qid) then return migrations[qid]
  return .nil
::method clear guarded
  expose migrations
  use strict arg qidArg
  migrations~remove(qidArg~string)
  return .true
::method active guarded
  use strict arg qidArg
  migration = self~get(qidArg)
  if migration == .nil then return .false
  state = .QueueMigrationState~fromFrameworkName(migration~state)
  return .QueueMigrationState~active(state)

/* Short/critical-section authority guard.  All queue-state-changing actors use
 * the same QID lock, so holding it across pause/checkpoint or resume prevents a
 * cancel/complete/fail transition from racing the execution handoff. */
::class QueueMigrationQueueGuard public
::constant ACTOR "queuerexx-migration"
::attribute root get
::attribute store get
::attribute lockManager get
::method init
  expose root store lockManager
  use arg rootArg, lockManagerArg = .nil
  root = rootArg~string
  store = .QueueStateStore~new(root)
  if lockManagerArg == .nil then lockManager = .QueueStateLockManager~new(root)
  else lockManager = lockManagerArg

::method acquireRunning
  expose store lockManager
  use arg qidArg, timeoutArg = .nil
  qid = qidArg~string
  lock = lockManager~acquire(qid, self~ACTOR, timeoutArg)
  if lock == .nil then return .QueueMigrationGuardResult~failure(.QueueMigrationCode~LOCK_TIMEOUT, "QID state lock unavailable")
  matches = store~findAll(qid)
  if matches~items == 0 then do
    lock~release
    return .QueueMigrationGuardResult~failure(.QueueMigrationCode~QID_NOT_FOUND, "no authoritative queue record")
  end
  if matches~items > 1 then do
    lock~release
    return .QueueMigrationGuardResult~failure(.QueueMigrationCode~DUPLICATE_QID, "QID exists in multiple queue states")
  end
  record = matches[1]
  if record~state \= .QueueState~RUNNING then do
    stateName = record~stateName
    lock~release
    return .QueueMigrationGuardResult~failure(.QueueMigrationCode~QUEUE_STATE_NOT_RUNNING, "queue state is " || stateName || ", not running")
  end
  return .QueueMigrationGuardResult~success(record, lock)

::method validateMigration
  use strict arg migration
  if migration == .nil then return .QueueMigrationGuardResult~failure(.QueueMigrationCode~FRAMEWORK_MIGRATION_REQUIRED, "MigratableJobMigration object required")
  qid = migration~definition~jobId~string
  if qid == "" then return .QueueMigrationGuardResult~failure(.QueueMigrationCode~QID_MISMATCH, "migration definition has no job id")
  return self~acquireRunning(qid, 0)

/* Migratable Job v0.2.4 owns migratable.job.start/1 request binding, durable
 * CLAIMED/RUNNING receipts and replay.  This workload-application decorator
 * adds only the shared QueueBash/QueueRexx QID authority fence around NEW.
 * It deliberately does not implement RECOVER or HANDOFF; those remain inside
 * MigratableJobStarter and its coordinator/destination-runner contracts. */
::class QueueRexxMigratableStarterApplication subclass MigratableJobStarterApplication public
::attribute delegate get
::attribute guard get
::method init
  expose delegate guard
  use strict arg delegateArg, queueRootArg, lockManagerArg = .nil
  if delegateArg == .nil then raise syntax 88.900 array("migratable starter application delegate required")
  delegate = delegateArg
  guard = .QueueMigrationQueueGuard~new(queueRootArg, lockManagerArg)
::method definition
  expose delegate
  use strict arg request
  return delegate~definition(request)
::method startNew
  expose delegate guard
  use strict arg request, definition
  if definition == .nil then return .MigratableJobResumeResult~failure("DEFINITION_MISSING", "starter definition required")
  qid = definition~jobId~string
  if qid == "" then return .MigratableJobResumeResult~failure("QUEUE_AUTHORITY_qid_mismatch", "starter definition has no job id")
  g = guard~acquireRunning(qid)
  if \g~ok then return .MigratableJobResumeResult~failure("QUEUE_AUTHORITY_" || .QueueMigrationCode~name(g~code), g~detail)
  signal on syntax name startNewFailure
  rr = delegate~startNew(request, definition)
  if rr == .nil then rr = .MigratableJobResumeResult~failure("DELEGATE_RESULT_MISSING", "starter application returned nil")
  signal off syntax
  g~lock~release
  return rr
startNewFailure:
  signal off syntax
  g~lock~release
  raise propagate
::method afterStart
  expose delegate
  use strict arg request, result
  return delegate~afterStart(request, result)

/* v0.2.4 managed initial placement calls this seam only after its outer
 * Job-to-Node CHECK. QueueRexx deliberately verifies the exact lease again
 * while holding the shared QID lock immediately before starter entry. This
 * closes the placement-change window between managed placement and runtime
 * side effects without duplicating Job-to-Node's placement rules.
 *
 * The starter supplied here must use the workload application directly rather
 * than QueueRexxMigratableStarterApplication: this executor already owns the
 * QueueRexx QID fence for the placed NEW start, so double-wrapping would try to
 * acquire the same filesystem lock twice. RECOVER and HANDOFF remain on their
 * existing Migratable Job authority paths. */

::class QueueMigratableStartIntentCode public
::constant STORED "STORED"
::constant LOADED "LOADED"
::constant NOT_FOUND "NOT_FOUND"
::constant INVALID "INVALID"
::constant IO_ERROR "IO_ERROR"
::constant REQUEST_MISMATCH "REQUEST_MISMATCH"

::class QueueMigratableStartIntentLookup public
::attribute valid get
::attribute code get
::attribute request get
::attribute detail get
::method init
  expose valid code request detail
  use strict arg validArg, codeArg, requestArg = .nil, detailArg = ""
  valid = (validArg == .true)
  code = codeArg~string
  request = requestArg
  detail = detailArg~string

/* QueueRexx persists only the caller's NEW-start intent. It deliberately does
 * not persist or mint Job-to-Node placement authority. On restart the workload
 * definition reproduces the native JobPlacementRequest and v0.2.4 ALLOCATE
 * either obtains a placement or returns PLACED_REPLAY from Job-to-Node. */
::class QueueRexxMigratableStartIntentStore public
::constant SCHEMA "queuerexx.migratable_start_intent.v1"
::method init
  expose root directory filesystem lockManager
  use strict arg rootArg, filesystemArg = .nil, lockManagerArg = .nil
  root = rootArg~string
  if filesystemArg == .nil then filesystem = .QueuePosixAtomicFileSystem~new
  else filesystem = filesystemArg
  if lockManagerArg == .nil then lockManager = .QueueStateLockManager~new(root, filesystem)
  else lockManager = lockManagerArg
  directory = root || "/queuerexx/migratable-start"
  if \filesystem~ensureDirectory(directory) then raise syntax 88.900 array("could not create QueueRexx migratable start-intent directory", directory)
  ignore = filesystem~ensureOwnerLike(directory, root)

::method pathFor
  expose directory
  use strict arg qidArg
  qid = qidArg~string
  if qid == "" then return ""
  return directory || "/job-" || c2x(qid) || ".json"

::method persist
  expose root filesystem lockManager
  use strict arg startRequest
  if startRequest == .nil then return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~INVALID, .nil, "start request required")
  if startRequest~mode \= .MigratableJobStartMode~NEW then return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~INVALID, .nil, "only NEW start intent is persisted")
  path = self~pathFor(startRequest~jobId)
  if path == "" then return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~INVALID, .nil, "job id required")

  acquired = lockManager~acquireDetailed(startRequest~jobId, .QueueLockActor~MIGRATABLE_START_INTENT)
  if \acquired~acquired then return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~IO_ERROR, .nil, "start-intent lock " || .QueueLockAcquireStatus~name(acquired~status) || ":" || acquired~detail)
  lock = acquired~handle

  /* One QID has one durable NEW invocation. Retries of that exact invocation
   * are idempotent; a different startId/request must never replace it. */
  existing = self~load(startRequest~jobId)
  if \existing~valid then do
    lock~release
    return existing
  end
  if existing~request \= .nil then do
    if existing~request~canonical == startRequest~canonical then do
      lock~release
      return .QueueMigratableStartIntentLookup~new(.true, .QueueMigratableStartIntentCode~STORED, existing~request, "exact NEW-start intent already persisted")
    end
    lock~release
    return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~REQUEST_MISMATCH, existing~request, "a different NEW-start intent is already durable for this QID")
  end

  d = .Directory~new
  d["schema"] = self~SCHEMA
  d["start_id"] = startRequest~startId
  d["mode"] = startRequest~mode
  d["job_id"] = startRequest~jobId
  d["definition_ref"] = startRequest~definitionRef
  d["partition_id"] = startRequest~partitionId
  d["migration_id"] = startRequest~migrationId
  d["requested_epoch_ms"] = startRequest~requestedEpochMs
  d["checkpoint_override"] = startRequest~checkpointOverride
  d["lease_duration_ms"] = startRequest~leaseDurationMs
  d["max_transfer_chunks"] = startRequest~maxTransferChunks
  d["metadata_ref"] = startRequest~metadataRef
  temp = path || ".tmp." || .QueueKernelTime~nonce
  signal on syntax name intentWriteFailure
  ignore = .QueueSerialization~toJsonFile(d, temp)
  /* move(), unlike replace(), refuses an existing destination. The shared QID
   * lock is the normal cooperating-writer fence; no-overwrite is an additional
   * fail-closed guard against accidental replacement. */
  if \filesystem~move(temp, path) then do
    if SysFileExists(temp) then call SysFileDelete temp
    signal off syntax
    lock~release
    return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~IO_ERROR, .nil, "exclusive start-intent commit failed")
  end
  ignore = filesystem~ensureOwnerLikeShallow(path, root)
  signal off syntax
  if \lock~release then return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~IO_ERROR, startRequest, "start intent committed but QID lock release failed")
  return .QueueMigratableStartIntentLookup~new(.true, .QueueMigratableStartIntentCode~STORED, startRequest)
intentWriteFailure:
  signal off syntax
  if temp \= "" then if SysFileExists(temp) then call SysFileDelete temp
  lock~release
  return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~IO_ERROR, .nil, "start-intent JSON write failed")

::method load
  use strict arg qidArg
  path = self~pathFor(qidArg)
  if path == "" | \SysFileExists(path) then return .QueueMigratableStartIntentLookup~new(.true, .QueueMigratableStartIntentCode~NOT_FOUND)
  signal on syntax name intentReadFailure
  d = .QueueSerialization~fromJsonFile(path)
  if d == .nil then do
    signal off syntax
    return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~INVALID, .nil, "start-intent JSON is empty")
  end
  if d["schema"] \= self~SCHEMA then do
    signal off syntax
    return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~INVALID, .nil, "start-intent schema mismatch")
  end
  if d["job_id"]~string \= qidArg~string | d["mode"]~string \= .MigratableJobStartMode~NEW then do
    signal off syntax
    return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~INVALID, .nil, "start-intent identity/mode mismatch")
  end
  startId = d["start_id"]~string
  definitionRef = d["definition_ref"]~string
  if startId == "" | definitionRef == "" then do
    signal off syntax
    return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~INVALID, .nil, "start-intent binding is incomplete")
  end
  req = .MigratableJobStartRequest~new(startId, d["mode"], d["job_id"], definitionRef, d["partition_id"], d["migration_id"], d["requested_epoch_ms"], .nil, d["checkpoint_override"], d["lease_duration_ms"], d["max_transfer_chunks"], d["metadata_ref"])
  signal off syntax
  return .QueueMigratableStartIntentLookup~new(.true, .QueueMigratableStartIntentCode~LOADED, req)
intentReadFailure:
  signal off syntax
  return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~INVALID, .nil, "start-intent JSON failed validation")

::method matches
  use strict arg startRequest
  if startRequest == .nil then return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~INVALID, .nil, "start request required")
  loaded = self~load(startRequest~jobId)
  if \loaded~valid then return loaded
  if loaded~request == .nil then return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~NOT_FOUND, .nil, "durable NEW-start intent is missing")
  if loaded~request~canonical \= startRequest~canonical then return .QueueMigratableStartIntentLookup~new(.false, .QueueMigratableStartIntentCode~REQUEST_MISMATCH, loaded~request, "caller request differs from durable NEW-start intent")
  return loaded

/* Thin v0.2.4 frontage. It makes NEW intent durable before authoritative
 * allocation, then delegates every placement action to Migratable Job. */
::class QueueRexxManagedPlacementFacade public
::attribute tool get
::attribute intentStore get
::method init
  expose tool intentStore
  use strict arg toolArg, intentStoreArg
  if toolArg == .nil | intentStoreArg == .nil then raise syntax 88.900 array("managed placement tool and start-intent store required")
  tool = toolArg; intentStore = intentStoreArg

::method plan
  expose tool
  use strict arg startRequest, nowEpochMs = 0, operationId = ""
  return tool~plan(startRequest, nowEpochMs, operationId)

::method check
  expose tool
  use strict arg startRequest, lease, nowEpochMs = 0, operationId = ""
  return tool~check(startRequest, lease, nowEpochMs, operationId)

::method allocate
  expose tool intentStore
  use strict arg startRequest, nowEpochMs = 0, leaseDurationMs = 30000, operationId = ""
  saved = intentStore~persist(startRequest)
  if \saved~valid then return .MigratableJobPlacementResult~new(.false, "QUEUEREXX_START_INTENT_WRITE_FAILED", .MigratableJobPlacementAction~ALLOCATE, operationId, startRequest~jobId, .nil, .nil, .nil, .false, saved~code || ":" || saved~detail)
  return tool~allocate(startRequest, nowEpochMs, leaseDurationMs, operationId)

::method start
  expose tool intentStore
  use strict arg startRequest, lease, nowEpochMs = 0, operationId = ""
  matched = intentStore~matches(startRequest)
  if \matched~valid then return .MigratableJobPlacementResult~new(.false, "QUEUEREXX_START_INTENT_INVALID", .MigratableJobPlacementAction~START, operationId, startRequest~jobId, lease, .nil, .nil, lease \= .nil, matched~code || ":" || matched~detail)
  return tool~start(startRequest, lease, nowEpochMs, operationId)

::method allocateStart
  expose tool intentStore
  use strict arg startRequest, nowEpochMs = 0, leaseDurationMs = 30000, operationId = ""
  saved = intentStore~persist(startRequest)
  if \saved~valid then return .MigratableJobPlacementResult~new(.false, "QUEUEREXX_START_INTENT_WRITE_FAILED", .MigratableJobPlacementAction~ALLOCATE_START, operationId, startRequest~jobId, .nil, .nil, .nil, .false, saved~code || ":" || saved~detail)
  return tool~allocateStart(startRequest, nowEpochMs, leaseDurationMs, operationId)

::method release
  expose tool intentStore
  use strict arg startRequest, lease, nowEpochMs = 0, operationId = "", reason = "operator-request"
  matched = intentStore~matches(startRequest)
  if \matched~valid then return .MigratableJobPlacementResult~new(.false, "QUEUEREXX_START_INTENT_INVALID", .MigratableJobPlacementAction~RELEASE, operationId, startRequest~jobId, lease, .nil, .nil, lease \= .nil, matched~code || ":" || matched~detail)
  return tool~release(startRequest, lease, nowEpochMs, operationId, reason)

::class QueueRexxPlacedStartExecutor subclass MigratableJobPlacedStartExecutor public
::attribute starter get
::attribute application get
::attribute allocator get
::attribute guard get
::attribute policyGate get
::method init
  expose starter application allocator guard policyGate intentStore
  use strict arg starterArg, applicationArg, allocatorArg, queueRootArg, policyGateArg = .nil, lockManagerArg = .nil, intentStoreArg = .nil
  if starterArg == .nil | applicationArg == .nil | allocatorArg == .nil then raise syntax 88.900 array("starter, application and Job-to-Node allocator required")
  starter = starterArg
  application = applicationArg
  allocator = allocatorArg
  guard = .QueueMigrationQueueGuard~new(queueRootArg, lockManagerArg)
  if policyGateArg == .nil then policyGate = .QueueDenyAllOperationPolicyGate~new
  else policyGate = policyGateArg
  intentStore = intentStoreArg

::method start
  expose starter application allocator guard policyGate intentStore
  use strict arg lease, startRequest, nowEpochMs
  if startRequest == .nil then return .nil
  if startRequest~mode \= .MigratableJobStartMode~NEW then return .MigratableJobStartResult~failure(startRequest, "QUEUEREXX_MANAGED_START_REQUIRES_NEW", "RECOVER/HANDOFF retain their existing authority paths")
  if intentStore \= .nil then do
    durableIntent = intentStore~matches(startRequest)
    if \durableIntent~valid then return .MigratableJobStartResult~failure(startRequest, "QUEUEREXX_START_INTENT_INVALID", durableIntent~code || ":" || durableIntent~detail)
  end
  if lease == .nil then return .MigratableJobStartResult~failure(startRequest, "PLACEMENT_LEASE_REQUIRED", "Job-to-Node placement lease required")
  definition = application~definition(startRequest)
  if definition == .nil then return .MigratableJobStartResult~failure(startRequest, "DEFINITION_MISSING", "workload definition required")
  if definition~jobId \= startRequest~jobId | lease~jobId \= startRequest~jobId then return .MigratableJobStartResult~failure(startRequest, "QUEUE_PLACEMENT_JOB_MISMATCH", "queue, starter and placement identity differ")
  if definition~definitionRef \= startRequest~definitionRef then return .MigratableJobStartResult~failure(startRequest, "DEFINITION_BINDING_MISMATCH", "starter request does not bind to workload definition")
  if startRequest~partitionId \= "" & definition~partitionId \= startRequest~partitionId then return .MigratableJobStartResult~failure(startRequest, "PARTITION_BINDING_MISMATCH", "starter request does not bind to workload partition")
  placementRequest = definition~placementRequest
  if placementRequest == .nil then return .MigratableJobStartResult~failure(startRequest, "PLACEMENT_REQUEST_MISSING", "workload definition has no Job-to-Node request")
  if placementRequest~jobId \= startRequest~jobId then return .MigratableJobStartResult~failure(startRequest, "PLACEMENT_REQUEST_JOB_MISMATCH", "placement request does not bind to queue QID")

  g = guard~acquireRunning(startRequest~jobId)
  if \g~ok then return .MigratableJobStartResult~failure(startRequest, "QUEUE_AUTHORITY_" || .QueueMigrationCode~name(g~code), g~detail)

  signal on syntax name placedStartFailure
  verdict = policyGate~assessExecution(g~record)
  if verdict == .nil | \verdict~isAllowed then do
    detail = "execution policy denied"
    if verdict \= .nil then detail = verdict~code || ":" || verdict~detail
    signal off syntax
    g~lock~release
    return .MigratableJobStartResult~failure(startRequest, "QUEUE_POLICY_DENIED", detail)
  end

  /* This second verification is intentional even though the v0.2.4 managed
   * placement tool has just verified the lease. Queue authority is now locked,
   * and runtime entry is still ahead of us, so this is the final placement
   * fence before side effects. */
  if \allocator~verifyLease(lease, placementRequest, nowEpochMs) then do
    signal off syntax
    g~lock~release
    return .MigratableJobStartResult~failure(startRequest, "PLACEMENT_INVALID_AT_LAUNCH", "Job-to-Node rejected the lease at the QueueRexx launch boundary")
  end

  started = starter~start(startRequest)
  if started == .nil then started = .MigratableJobStartResult~failure(startRequest, "START_RESULT_MISSING", "standard starter returned nil")
  signal off syntax
  g~lock~release
  return started

placedStartFailure:
  signal off syntax
  g~lock~release
  raise propagate

::class QueueMigrationObservationProvider public
::constant PROVIDER_ID "migratable-job-v0.2"
::constant CODE_MIGRATION_IN_PROGRESS "MIGRATION_IN_PROGRESS"
::constant CODE_MIGRATION_PAUSED "MIGRATION_PAUSED"
::constant CODE_MIGRATION_FAILED "MIGRATION_FAILED"
::constant CODE_DESTINATION_RUNNING "MIGRATION_DESTINATION_RUNNING"
::attribute registry get
::method init
  expose registry
  use strict arg registryArg
  registry = registryArg
::method observe
  expose registry
  use strict arg record
  migration = registry~get(record~qid)
  if migration == .nil then return .QueueJobObservation~new(.QueueJobObservation~NOT_APPLICABLE, self~PROVIDER_ID, "NO_ACTIVE_MIGRATION")
  state = .QueueMigrationState~fromFrameworkName(migration~state)
  evidence = .Directory~new
  evidence["migration_id"] = migration~migrationId
  evidence["migration_state"] = .QueueMigrationState~name(state)
  evidence["source_node"] = migration~sourceLease~nodeId
  if migration~destinationLease \= .nil then evidence["destination_node"] = migration~destinationLease~nodeId
  if state == .QueueMigrationState~RUNNING then return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_DESTINATION_RUNNING, "migration framework reports destination resumed; destination liveness requires its execution provider", evidence)
  if state == .QueueMigrationState~FAILED then return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_MIGRATION_FAILED, migration~failureCode || ":" || migration~failureDetail, evidence)
  if state == .QueueMigrationState~PAUSED then return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_MIGRATION_PAUSED, "migration is durably paused; local stale inference is deferred", evidence)
  if .QueueMigrationState~active(state) then return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_MIGRATION_IN_PROGRESS, "planned migration owns execution continuity; local stale inference is deferred", evidence)
  return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_MIGRATION_IN_PROGRESS, "migration state is not locally conclusive", evidence)

/* Wrap the real execution-runtime adapter.  QueueRexx does not implement
 * checkpoint semantics here; it guards the shared QID and delegates the exact
 * framework contract. */
::class QueueRexxMigratableExecutionAdapter subclass MigratableJobExecutionAdapter public
::attribute delegate get
::attribute guard get
::attribute eventBus get
::method init
  expose delegate guard eventBus
  use strict arg delegateArg, queueRootArg, eventBusArg = .nil, lockManagerArg = .nil
  if delegateArg == .nil then raise syntax 88.900 array("migratable execution delegate required")
  delegate = delegateArg
  guard = .QueueMigrationQueueGuard~new(queueRootArg, lockManagerArg)
  if eventBusArg == .nil then do
    eventBus = .QueueEventBus~new
    eventBus~addSink(.QueueBashEventLog~new(queueRootArg))
  end
  else eventBus = eventBusArg

::method pauseAndCheckpoint
  expose delegate guard eventBus
  use strict arg definition, sourceLease, migrationId, nowEpochMs
  qid = definition~jobId
  g = guard~acquireRunning(qid)
  if \g~ok then return .MigratableJobCheckpointResult~failure("QUEUE_AUTHORITY_" || .QueueMigrationCode~name(g~code), g~detail)
  signal on syntax name pauseAdapterFailure
  adapterResult = delegate~pauseAndCheckpoint(definition, sourceLease, migrationId, nowEpochMs)
  if adapterResult \= .nil then do
    if adapterResult~ok then do
      detail = "migration=" || migrationId || " checkpoint=" || adapterResult~manifest~checkpointId
      self~publish(eventBus, .QueueMigrationEvent~CHECKPOINTED, qid, detail)
    end
  end
  signal off syntax
  g~lock~release
  return adapterResult
pauseAdapterFailure:
  signal off syntax
  g~lock~release
  raise propagate

::method resumeFromCheckpoint
  expose delegate guard eventBus
  use strict arg definition, destinationLease, manifest, destinationCheckpointRef, nowEpochMs
  qid = definition~jobId
  g = guard~acquireRunning(qid)
  if \g~ok then do
    self~publish(eventBus, .QueueMigrationEvent~RESUME_DENIED, qid, "migration=" || manifest~migrationId || " reason=" || .QueueMigrationCode~name(g~code), "")
    return .MigratableJobResumeResult~failure("QUEUE_AUTHORITY_" || .QueueMigrationCode~name(g~code), g~detail)
  end
  signal on syntax name resumeAdapterFailure
  adapterResult = delegate~resumeFromCheckpoint(definition, destinationLease, manifest, destinationCheckpointRef, nowEpochMs)
  if adapterResult == .nil then adapterResult = .MigratableJobResumeResult~failure("DELEGATE_RESULT_MISSING", "execution adapter returned nil")
  if adapterResult~ok then self~publish(eventBus, .QueueMigrationEvent~DESTINATION_RESUMED, qid, "migration=" || manifest~migrationId || " destination=" || destinationLease~nodeId || " execution=" || adapterResult~executionRef)
  signal off syntax
  g~lock~release
  return adapterResult
resumeAdapterFailure:
  signal off syntax
  g~lock~release
  raise propagate

::method retireSource
  expose delegate
  use strict arg definition, sourceLease, migrationId, nowEpochMs
  return delegate~retireSource(definition, sourceLease, migrationId, nowEpochMs)

::method publish private
  use arg eventBus, eventType, qid, detail, stateNameArg = .nil
  if stateNameArg == .nil then stateName = .QueueState~NAME_RUNNING
  else stateName = stateNameArg~string
  data = .Directory~new
  data["detail"] = detail
  event = .QueueEvent~new("migration-" || qid || "-" || .QueueKernelTime~nonce, eventType, qid, stateName, .QueueKernelTime~nowIso, data)
  return eventBus~publishChecked(event)

/* Defence in depth at the commit-authority boundary.  The execution adapter
 * repeats this validation while holding the same QID lock across resume, so a
 * later cancel/terminal transition cannot slip between authorisation and
 * execution commit. */
::class QueueRexxMigratableCommitAuthority subclass MigratableJobCommitAuthority public
::attribute delegate get
::attribute guard get
::method init
  expose delegate guard
  use strict arg delegateArg, queueRootArg, lockManagerArg = .nil
  if delegateArg == .nil then raise syntax 88.900 array("migratable commit authority delegate required")
  delegate = delegateArg
  guard = .QueueMigrationQueueGuard~new(queueRootArg, lockManagerArg)
::method authorise
  expose delegate guard
  use strict arg migration, nowEpochMs
  g = guard~validateMigration(migration)
  if \g~ok then return .MigratableJobCommitDecision~deny("QUEUE_AUTHORITY_" || .QueueMigrationCode~name(g~code), g~detail)
  g~lock~release
  decision = delegate~authorise(migration, nowEpochMs)
  if decision == .nil then return .MigratableJobCommitDecision~deny("COMMIT_AUTHORITY_RESULT_MISSING", "delegate returned nil")
  return decision

/* Thin lifecycle wrapper around the supplied coordinator.  It does not
 * reproduce its state machine; it only indexes the exact migration object and
 * emits QueueBash-compatible extension events. */
::class QueueRexxMigratableCoordinator public
::attribute delegate get
::attribute registry get
::attribute eventBus get
::method init
  expose delegate registry eventBus
  use strict arg delegateArg, registryArg, queueRootArg, eventBusArg = .nil
  if delegateArg == .nil | registryArg == .nil then raise syntax 88.900 array("migratable coordinator delegate and registry required")
  delegate = delegateArg; registry = registryArg
  if eventBusArg == .nil then do
    eventBus = .QueueEventBus~new
    eventBus~addSink(.QueueBashEventLog~new(queueRootArg))
  end
  else eventBus = eventBusArg
::method begin
  expose delegate registry eventBus
  use strict arg migrationId, definition, sourceLease, nowEpochMs
  m = delegate~begin(migrationId, definition, sourceLease, nowEpochMs)
  if m \= .nil then do
    registry~register(m)
    self~publish(eventBus, .QueueMigrationEvent~STARTED, m, "migration=" || m~migrationId || " source=" || m~sourceLease~nodeId)
  end
  return m
::method step
  expose delegate registry eventBus
  use strict arg migration, nowEpochMs, leaseDurationMs = 30000, maxTransferChunks = 0
  registry~register(migration)
  ok = delegate~step(migration, nowEpochMs, leaseDurationMs, maxTransferChunks)
  self~publishState(eventBus, migration)
  return ok
::method resumePaused
  expose delegate registry eventBus
  use strict arg migration, nowEpochMs, leaseDurationMs = 30000, maxTransferChunks = 0
  registry~register(migration)
  ok = delegate~resumePaused(migration, nowEpochMs, leaseDurationMs, maxTransferChunks)
  self~publishState(eventBus, migration)
  return ok
::method publishState private
  use arg eventBus, migration
  state = .QueueMigrationState~fromFrameworkName(migration~state)
  if state == .QueueMigrationState~RUNNING then eventType = .QueueMigrationEvent~RUNNING
  else if state == .QueueMigrationState~FAILED then eventType = .QueueMigrationEvent~FAILED
  else if state == .QueueMigrationState~PAUSED then eventType = .QueueMigrationEvent~PAUSED
  else return .true
  detail = "migration=" || migration~migrationId || " state=" || .QueueMigrationState~name(state)
  if migration~failureCode \= "" then detail ||= " code=" || migration~failureCode
  return self~publish(eventBus, eventType, migration, detail)
::method publish private
  use arg eventBus, eventType, migration, detail
  qid = migration~definition~jobId
  data = .Directory~new; data["detail"] = detail
  event = .QueueEvent~new("migration-" || migration~migrationId || "-" || migration~sequence, eventType, qid, .QueueState~NAME_RUNNING, .QueueKernelTime~nowIso, data)
  return eventBus~publishChecked(event)


/* Health/observe overlay.  While an exact framework migration is known, its
 * lifecycle evidence takes precedence over local PID/systemd stale inference.
 * Once no migration is registered, ordinary QueueRexx runner observation is
 * used unchanged. */
::class QueueMigrationAwareJobObserver public
::attribute baseObserver get
::attribute migrationObserver get
::method init
  expose baseObserver migrationObserver
  use strict arg migrationRegistryArg, providerRegistryArg = .nil
  baseObserver = .QueueJobObserver~new(providerRegistryArg)
  migrationObserver = .QueueMigrationObservationProvider~new(migrationRegistryArg)
::method observe
  expose baseObserver migrationObserver
  use strict arg record
  m = migrationObserver~observe(record)
  if m~status \= .QueueJobObservation~NOT_APPLICABLE then return m
  return baseObserver~observe(record)
::method providerFor
  expose baseObserver
  use strict arg record
  return baseObserver~providerFor(record)
::method asDirectory
  use strict arg record
  observation = self~observe(record)
  d = .Directory~new
  d["schema"] = .QueueSchema~JOB_OBSERVATION
  d["queuebash_compatibility_baseline"] = .QueueRexxVersion~queueBashCompatibility
  d["qid"] = record~qid
  d["state"] = record~stateName
  d["observation"] = observation~asDirectory
  return d

::requires "QueueRexxCore.cls"
::requires "QueueRexxProviders.cls"
::requires "QueueRexxHealth.cls"
::requires "QueueRexxEvents.cls"
::requires "QueueRexxMutation.cls"
::requires "MigratableJob.cls"
::requires "MigratableJobStarter.cls"
::requires "MigratableJobManagedPlacement.cls"
::requires "QueueRexxOperations.cls"
::requires "QueueRexxSerialization.cls"
