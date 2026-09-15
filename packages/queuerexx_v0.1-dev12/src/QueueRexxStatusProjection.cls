/* QueueRexxStatusProjection.cls - authority-preserving status projection, v0.1-dev8.
 *
 * The projection deliberately carries durable migration authority and retained
 * Queue Fabric status side-by-side.  It never collapses the topic read model
 * into migration authority.  Sequence comparison exists to describe freshness,
 * not to grant transition/resume/commit authority.
 */

::class QueueMigrationProjectionRelation public
::constant NONE 0
::constant DURABLE_ONLY 1
::constant LIVE_ONLY 2
::constant IN_SYNC 3
::constant LIVE_AHEAD 4
::constant DURABLE_AHEAD 5
::constant MIGRATION_MISMATCH 6
::constant STATE_CONFLICT 7
::constant NAME_NONE "none"
::constant NAME_DURABLE_ONLY "durable_only"
::constant NAME_LIVE_ONLY "live_only"
::constant NAME_IN_SYNC "in_sync"
::constant NAME_LIVE_AHEAD "live_ahead"
::constant NAME_DURABLE_AHEAD "durable_ahead"
::constant NAME_MIGRATION_MISMATCH "migration_mismatch"
::constant NAME_STATE_CONFLICT "state_conflict"
::constant NAME_UNKNOWN "unknown"
::method name class
  use arg valueArg
  value = valueArg + 0
  select
    when value == self~NONE then return self~NAME_NONE
    when value == self~DURABLE_ONLY then return self~NAME_DURABLE_ONLY
    when value == self~LIVE_ONLY then return self~NAME_LIVE_ONLY
    when value == self~IN_SYNC then return self~NAME_IN_SYNC
    when value == self~LIVE_AHEAD then return self~NAME_LIVE_AHEAD
    when value == self~DURABLE_AHEAD then return self~NAME_DURABLE_AHEAD
    when value == self~MIGRATION_MISMATCH then return self~NAME_MIGRATION_MISMATCH
    when value == self~STATE_CONFLICT then return self~NAME_STATE_CONFLICT
    otherwise return self~NAME_UNKNOWN
  end

::class QueueMigrationProjectionSource public
::constant DURABLE "migratable_job_durable_authority"
::constant LIVE "queue_fabric_retained_status"
::constant NONE "none"

::class QueueMigrationStatusProjection public
::attribute qid get
::attribute relation get
::attribute durablePresent get
::attribute livePresent get
::attribute durableMigration get
::attribute liveSnapshot get
::attribute detail get
::method init
  expose qid relation durablePresent livePresent durableMigration liveSnapshot detail
  use strict arg qidArg, relationArg, durableArg = .nil, liveArg = .nil, detailArg = ""
  qid = qidArg~string
  relation = relationArg + 0
  durableMigration = durableArg
  liveSnapshot = liveArg
  durablePresent = (durableArg \== .nil)
  livePresent = (liveArg \== .nil)
  detail = detailArg~string

::method asDirectory
  expose qid relation durablePresent livePresent durableMigration liveSnapshot detail
  d = .Directory~new
  d["schema"] = .QueueSchema~MIGRATION_STATUS_PROJECTION
  d["job_id"] = qid
  d["relation"] = .QueueMigrationProjectionRelation~name(relation)
  d["detail"] = detail
  d["durable_present"] = .QueueRexxUtil~jsonBoolean(durablePresent)
  d["live_present"] = .QueueRexxUtil~jsonBoolean(livePresent)
  d["authority_note"] = "durable Migratable Job state and Job-to-Node ownership remain authority; retained Queue Fabric status is observation only"
  if durablePresent then d["durable"] = self~durableDirectory(durableMigration)
  if livePresent then d["live"] = self~liveDirectory(liveSnapshot)
  return d

::method durableDirectory private
  use strict arg migration
  x = .Directory~new
  stateCode = .QueueMigrationState~fromFrameworkName(migration~state)
  x["source"] = .QueueMigrationProjectionSource~DURABLE
  x["authoritative"] = .JSONBoolean~true
  x["migration_id"] = migration~migrationId
  x["state"] = .QueueMigrationState~name(stateCode)
  x["state_code"] = stateCode
  x["sequence"] = migration~sequence
  x["started_epoch_ms"] = migration~startedEpochMs
  x["updated_epoch_ms"] = migration~updatedEpochMs
  x["resume_state"] = migration~resumeState
  x["failure_code"] = migration~failureCode
  x["failure_detail"] = migration~failureDetail
  x["source_node"] = migration~sourceLease~nodeId
  if migration~destinationLease \== .nil then x["destination_node"] = migration~destinationLease~nodeId
  if migration~checkpointManifest \== .nil then do
    x["checkpoint_id"] = migration~checkpointManifest~checkpointId
    x["checkpoint_state_ref"] = migration~checkpointManifest~stateRef
    x["checkpoint_state_digest"] = migration~checkpointManifest~stateDigest
  end
  x["source_fenced"] = .QueueRexxUtil~jsonBoolean(migration~sourceFenced)
  x["source_admission_released"] = .QueueRexxUtil~jsonBoolean(migration~sourceAdmissionReleased)
  x["destination_resumed"] = .QueueRexxUtil~jsonBoolean(migration~destinationResumed)
  x["execution_ref"] = migration~executionRef
  return x

::method liveDirectory private
  use strict arg snapshot
  x = snapshot~asDirectory
  x["source"] = .QueueMigrationProjectionSource~LIVE
  x["authoritative"] = .JSONBoolean~false
  return x

::class QueueMigrationStatusProjector public
::attribute registry get
::attribute cache get
::method init
  expose registry cache
  use strict arg registryArg, cacheArg
  if registryArg == .nil | cacheArg == .nil then raise syntax 88.900 array("migration registry and status cache required")
  registry = registryArg
  cache = cacheArg

::method project
  expose registry cache
  use strict arg qidArg
  qid = qidArg~string
  durable = registry~get(qid)
  live = cache~latest(qid)
  if durable == .nil & live == .nil then return .QueueMigrationStatusProjection~new(qid, .QueueMigrationProjectionRelation~NONE, .nil, .nil, "no migration evidence")
  if durable \== .nil & live == .nil then return .QueueMigrationStatusProjection~new(qid, .QueueMigrationProjectionRelation~DURABLE_ONLY, durable, .nil, "durable migration is known; no retained topic snapshot has been consumed")
  if durable == .nil & live \== .nil then return .QueueMigrationStatusProjection~new(qid, .QueueMigrationProjectionRelation~LIVE_ONLY, .nil, live, "retained status is available but this process has no durable migration object; do not treat topic state as authority")

  if durable~migrationId \== live~migrationId then return .QueueMigrationStatusProjection~new(qid, .QueueMigrationProjectionRelation~MIGRATION_MISMATCH, durable, live, "durable and retained status refer to different migration ids")

  numeric digits 30
  durableSequence = durable~sequence + 0
  liveSequence = live~sequence + 0
  if liveSequence > durableSequence then return .QueueMigrationStatusProjection~new(qid, .QueueMigrationProjectionRelation~LIVE_AHEAD, durable, live, "retained subscriber has observed a newer published revision than the locally registered durable object")
  if durableSequence > liveSequence then return .QueueMigrationStatusProjection~new(qid, .QueueMigrationProjectionRelation~DURABLE_AHEAD, durable, live, "durable migration is newer than the last retained status consumed by this subscriber")

  durableState = .QueueMigrationState~fromFrameworkName(durable~state)
  if durableState \= live~state then return .QueueMigrationStatusProjection~new(qid, .QueueMigrationProjectionRelation~STATE_CONFLICT, durable, live, "same migration sequence reports different durable/live states; reconcile before trusting observation")
  return .QueueMigrationStatusProjection~new(qid, .QueueMigrationProjectionRelation~IN_SYNC, durable, live, "durable and retained status agree at the same migration sequence")

/* A consumer-facing job status projection.  Queue state remains filesystem
 * authority, runner/migration observations remain observations.  This object is
 * intentionally read-only and contains no transition methods. */
::class QueueJobStatusProjection public
::attribute directory get
::method init
  expose directory
  use strict arg directoryArg
  directory = directoryArg
::method asDirectory
  expose directory
  return directory

::class QueueJobStatusProjector public
::attribute store get
::attribute observer get
::attribute migrationProjector get
::attribute wluProjector get
::method init
  expose store observer migrationProjector wluProjector
  use arg storeArg, observerArg, migrationProjectorArg, wluProjectorArg = .nil
  if storeArg == .nil | observerArg == .nil | migrationProjectorArg == .nil then raise syntax 88.900 array("store, observer and migration projector required")
  store = storeArg; observer = observerArg; migrationProjector = migrationProjectorArg; wluProjector = wluProjectorArg
::method project
  expose store observer migrationProjector wluProjector
  use strict arg qidArg
  qid = qidArg~string
  matches = store~findAll(qid)
  d = .Directory~new
  d["schema"] = .QueueSchema~JOB_STATUS_PROJECTION
  d["qid"] = qid
  d["queuebash_compatibility_baseline"] = .QueueRexxVersion~queueBashCompatibility
  d["record_count"] = matches~items
  d["authority_note"] = "queue filesystem owns queue state; Migratable Job/Job-to-Node own migration authority; status topic and runner probes are observational"
  if matches~items \= 1 then do
    d["ok"] = .JSONBoolean~false
    if matches~items == 0 then d["code"] = "QUEUE_RECORD_NOT_FOUND"
    else d["code"] = "DUPLICATE_QUEUE_STATE"
    states = .Array~new
    do r over matches; states~append(r~stateName); end
    d["states_seen"] = states
    d["migration"] = migrationProjector~project(qid)~asDirectory
    w = .Directory~new
    w["schema"] = .QueueSchema~WLU_PROJECTION
    w["qid"] = qid
    w["state"] = .QueueWLUProjectionState~NAME_UNKNOWN
    w["authority_note"] = "WLU projection requires exactly one authoritative queue record"
    d["wlu"] = w
    return .QueueJobStatusProjection~new(d)
  end
  record = matches[1]
  observation = observer~observe(record)
  d["ok"] = .JSONBoolean~true
  d["code"] = "OK"
  d["queue_state"] = record~stateName
  d["queue_state_code"] = record~state
  d["job_file"] = record~path
  d["observation"] = observation~asDirectory
  d["migration"] = migrationProjector~project(qid)~asDirectory
  if wluProjector \= .nil then d["wlu"] = wluProjector~project(record)~asDirectory
  else do
    w = record~wluRequirement~asDirectory
    w["schema"] = .QueueSchema~WLU_PROJECTION
    w["qid"] = qid
    if record~wluRequirement~managed then w["state"] = .QueueWLUProjectionState~NAME_DECLARED
    else w["state"] = .QueueWLUProjectionState~NAME_UNMANAGED
    w["authoritative"] = .JSONBoolean~false
    w["authority_note"] = "static queue declaration only; WLU authority state not connected to this projection"
    d["wlu"] = w
  end
  return .QueueJobStatusProjection~new(d)

::requires "QueueRexxCore.cls"
::requires "QueueRexxHealth.cls"
::requires "QueueRexxMigratableJob.cls"
::requires "QueueRexxMigrationStatus.cls"
