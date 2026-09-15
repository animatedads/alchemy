/* QueueRexxMigrationStatus.cls - Queue Fabric subscription status adapter, v0.1-dev8.
 *
 * Live migration status is observation, never execution authority.  QueueRexx
 * consumes the retained migratable.job.status/1 topic through its own ordinary
 * Queue Fabric queue, as retained by Migratable Job v0.2.4.  The migration
 * journal, Job-to-Node ownership state, and the shared QueueBash QID record
 * remain authoritative for mutation and recovery.
 */

::class QueueMigrationStatusContract public
::constant SCHEMA "migratable.job.status/1"
::constant DEFAULT_TOPIC "MIGRATABLE.JOB.STATUS"
::constant HEADER_SCHEMA "migratable-job-schema"
::constant HEADER_JOB_ID "migratable-job-id"
::constant HEADER_MIGRATION_ID "migratable-job-migration-id"
::constant HEADER_SEQUENCE "migratable-job-sequence"
::constant CODE_QUEUE_EMPTY "QUEUE_EMPTY"

::class QueueMigrationStatusIngestCode public
::constant ACCEPTED 1
::constant STALE 2
::constant INVALID 3
::constant QUEUE_ERROR 4
::constant NAME_ACCEPTED "accepted"
::constant NAME_STALE "stale"
::constant NAME_INVALID "invalid"
::constant NAME_QUEUE_ERROR "queue_error"
::method name class
  use arg valueArg
  value = valueArg + 0
  select
    when value == self~ACCEPTED then return self~NAME_ACCEPTED
    when value == self~STALE then return self~NAME_STALE
    when value == self~INVALID then return self~NAME_INVALID
    when value == self~QUEUE_ERROR then return self~NAME_QUEUE_ERROR
    otherwise return "unknown"
  end

::class QueueMigrationStatusIngestResult public
::attribute code get
::attribute detail get
::attribute snapshot get
::method init
  expose code detail snapshot
  use arg codeArg, detailArg = "", snapshotArg = .nil
  code = codeArg + 0
  detail = detailArg~string
  snapshot = snapshotArg
::method accepted
  expose code
  return code == .QueueMigrationStatusIngestCode~ACCEPTED
::method stale
  expose code
  return code == .QueueMigrationStatusIngestCode~STALE
::method invalid
  expose code
  return code == .QueueMigrationStatusIngestCode~INVALID

::class QueueMigrationStatusSnapshot public
::attribute jobId get
::attribute migrationId get
::attribute state get
::attribute stateName get
::attribute sequence get
::attribute startedEpochMs get
::attribute updatedEpochMs get
::attribute payload get
::method init
  expose jobId migrationId state stateName sequence startedEpochMs updatedEpochMs payload
  use strict arg payloadArg
  payload = payloadArg
  jobId = payload["jobId"]~string
  migrationId = payload["migrationId"]~string
  stateName = payload["state"]~string~upper
  state = .QueueMigrationState~fromFrameworkName(stateName)
  numeric digits 30
  sequence = payload["sequence"] + 0
  startedEpochMs = payload["startedEpochMs"] + 0
  updatedEpochMs = payload["updatedEpochMs"] + 0
::method asDirectory
  expose jobId migrationId state stateName sequence startedEpochMs updatedEpochMs
  d = .Directory~new
  d["schema"] = .QueueMigrationStatusContract~SCHEMA
  d["job_id"] = jobId
  d["migration_id"] = migrationId
  d["state"] = stateName
  d["state_code"] = state
  d["sequence"] = sequence
  d["started_epoch_ms"] = startedEpochMs
  d["updated_epoch_ms"] = updatedEpochMs
  return d

::class QueueMigrationStatusCache public
::method init
  expose byJob latestByJob
  byJob = .Directory~new
  latestByJob = .Directory~new

::method acceptPayload guarded
  use strict arg payload
  if payload == .nil then return .QueueMigrationStatusIngestResult~new(.QueueMigrationStatusIngestCode~INVALID, "nil payload")
  if \payload~hasMethod("HASINDEX") then return .QueueMigrationStatusIngestResult~new(.QueueMigrationStatusIngestCode~INVALID, "payload is not keyed")
  required = .Array~of("schema", "jobId", "migrationId", "state", "sequence", "startedEpochMs", "updatedEpochMs")
  do key over required
    if \payload~hasIndex(key) then return .QueueMigrationStatusIngestResult~new(.QueueMigrationStatusIngestCode~INVALID, "missing " || key)
  end
  if payload["schema"]~string \== .QueueMigrationStatusContract~SCHEMA then return .QueueMigrationStatusIngestResult~new(.QueueMigrationStatusIngestCode~INVALID, "schema=" || payload["schema"]~string)
  if payload["jobId"]~string == "" then return .QueueMigrationStatusIngestResult~new(.QueueMigrationStatusIngestCode~INVALID, "jobId empty")
  if payload["migrationId"]~string == "" then return .QueueMigrationStatusIngestResult~new(.QueueMigrationStatusIngestCode~INVALID, "migrationId empty")
  if \datatype(payload["sequence"], "N") then return .QueueMigrationStatusIngestResult~new(.QueueMigrationStatusIngestCode~INVALID, "sequence not numeric")
  if \datatype(payload["startedEpochMs"], "N") then return .QueueMigrationStatusIngestResult~new(.QueueMigrationStatusIngestCode~INVALID, "startedEpochMs not numeric")
  if \datatype(payload["updatedEpochMs"], "N") then return .QueueMigrationStatusIngestResult~new(.QueueMigrationStatusIngestCode~INVALID, "updatedEpochMs not numeric")
  snapshot = .QueueMigrationStatusSnapshot~new(payload)
  return self~acceptSnapshot(snapshot)

::method acceptSnapshot guarded
  expose byJob latestByJob
  use strict arg snapshot
  jobId = snapshot~jobId
  migrationId = snapshot~migrationId
  migrations = byJob[jobId]
  if migrations == .nil then do
    migrations = .Directory~new
    byJob[jobId] = migrations
  end
  previous = migrations[migrationId]
  if previous \== .nil then do
    numeric digits 30
    if snapshot~sequence <= previous~sequence then return .QueueMigrationStatusIngestResult~new(.QueueMigrationStatusIngestCode~STALE, "sequence " || snapshot~sequence || " <= " || previous~sequence, previous)
  end
  migrations[migrationId] = snapshot
  current = latestByJob[jobId]
  if current == .nil then latestByJob[jobId] = snapshot
  else if self~newer(snapshot, current) then latestByJob[jobId] = snapshot
  else if current~migrationId == migrationId then latestByJob[jobId] = snapshot
  return .QueueMigrationStatusIngestResult~new(.QueueMigrationStatusIngestCode~ACCEPTED, "accepted", snapshot)

::method newer private
  use strict arg candidate, current
  numeric digits 30
  if candidate~updatedEpochMs > current~updatedEpochMs then return .true
  if candidate~updatedEpochMs < current~updatedEpochMs then return .false
  if candidate~startedEpochMs > current~startedEpochMs then return .true
  if candidate~startedEpochMs < current~startedEpochMs then return .false
  return candidate~migrationId > current~migrationId

::method latest guarded
  expose latestByJob
  use strict arg jobIdArg
  return latestByJob[jobIdArg~string]

::method get guarded
  expose byJob
  use strict arg jobIdArg, migrationIdArg
  migrations = byJob[jobIdArg~string]
  if migrations == .nil then return .nil
  return migrations[migrationIdArg~string]

::method clearJob guarded
  expose byJob latestByJob
  use strict arg jobIdArg
  jobId = jobIdArg~string
  byJob~remove(jobId)
  latestByJob~remove(jobId)
  return .true

/* Wiring helper + bounded consumer.  It creates/owns only its destination
 * queue and subscription.  It never grants topic authority; SUBSCRIBE
 * authority must already have been issued to principal by Queue Fabric policy. */
::class QueueMigrationStatusSubscriber public
::constant DEFAULT_MAX_DEPTH 256
::constant DEFAULT_DRAIN_LIMIT 256
::attribute queueManager get
::attribute topicFabric get
::attribute topicName get
::attribute queueName get
::attribute subscriptionName get
::attribute principal get
::attribute cache get
::method init
  expose queueManager topicFabric topicName queueName subscriptionName principal cache
  use strict arg queueManagerArg, topicFabricArg, queueNameArg, subscriptionNameArg, principalArg, cacheArg = .nil, topicNameArg = .nil
  if queueManagerArg == .nil | topicFabricArg == .nil then raise syntax 88.900 array("Queue Fabric manager/topic fabric required")
  queueManager = queueManagerArg
  topicFabric = topicFabricArg
  queueName = queueNameArg~string
  subscriptionName = subscriptionNameArg~string
  principal = principalArg~string
  if topicNameArg == .nil then topicName = .QueueMigrationStatusContract~DEFAULT_TOPIC
  else topicName = topicNameArg~string
  if cacheArg == .nil then cache = .QueueMigrationStatusCache~new
  else cache = cacheArg

::method wireJob
  use strict arg jobId, lifecycleArg = .nil, securityDomainArg = "DEFAULT", maxDepthArg = .nil
  pattern = .MigratableJobStatusTopicAddress~jobPattern(jobId)
  return self~wire(pattern, lifecycleArg, securityDomainArg, maxDepthArg)

::method wireAll
  use strict arg lifecycleArg = .nil, securityDomainArg = "DEFAULT", maxDepthArg = .nil
  return self~wire(.MigratableJobStatusTopicAddress~allPattern, lifecycleArg, securityDomainArg, maxDepthArg)

::method wire private
  expose queueManager topicFabric queueName subscriptionName principal topicName
  use strict arg pattern, lifecycleArg = .nil, securityDomainArg = "DEFAULT", maxDepthArg = .nil
  if lifecycleArg == .nil then lifecycle = .QueueLifecycle~TEMPORARY
  else lifecycle = lifecycleArg~string~upper
  if maxDepthArg == .nil then maxDepth = self~DEFAULT_MAX_DEPTH
  else maxDepth = maxDepthArg + 0
  q = queueManager~queue(queueName)
  if q == .nil then do
    created = queueManager~createQueue(queueName, lifecycle, securityDomainArg, maxDepth, principal)
    if \created~ok then return created
  end
  existing = topicFabric~subscription(subscriptionName)
  if existing \== .nil then do
    if existing~queueName == queueName & existing~topicName == topicName & existing~pattern == pattern then return .QueueOperationResult~success(existing, "subscription already wired")
    return .QueueOperationResult~failure("SUBSCRIPTION_NAME_CONFLICT", subscriptionName)
  end
  return topicFabric~subscribe(subscriptionName, topicName, pattern, queueName, lifecycle, principal)

::method drain
  expose queueManager queueName principal cache
  use arg maxMessagesArg = .nil
  if maxMessagesArg == .nil then maxMessages = self~DEFAULT_DRAIN_LIMIT
  else maxMessages = maxMessagesArg + 0
  if maxMessages < 1 then maxMessages = self~DEFAULT_DRAIN_LIMIT
  accepted = 0; stale = 0; invalid = 0; consumed = 0
  do while consumed < maxMessages
    fetched = queueManager~get(queueName, principal)
    if \fetched~ok then do
      if fetched~code == .QueueMigrationStatusContract~CODE_QUEUE_EMPTY then leave
      return .QueueMigrationStatusDrainResult~new(.false, consumed, accepted, stale, invalid, fetched~code, fetched~detail)
    end
    consumed += 1
    ingest = cache~acceptPayload(fetched~value~payload)
    select
      when ingest~code == .QueueMigrationStatusIngestCode~ACCEPTED then accepted += 1
      when ingest~code == .QueueMigrationStatusIngestCode~STALE then stale += 1
      otherwise invalid += 1
    end
  end
  more = .false
  depth = queueManager~depth(queueName, principal)
  if depth~ok then more = depth~value["ready"] > 0
  return .QueueMigrationStatusDrainResult~new(.true, consumed, accepted, stale, invalid, "OK", "", more)

::class QueueMigrationStatusDrainResult public
::attribute ok get
::attribute consumed get
::attribute accepted get
::attribute stale get
::attribute invalid get
::attribute code get
::attribute detail get
::attribute more get
::method init
  expose ok consumed accepted stale invalid code detail more
  use arg okArg, consumedArg = 0, acceptedArg = 0, staleArg = 0, invalidArg = 0, codeArg = "OK", detailArg = "", moreArg = .false
  ok = (okArg == .true)
  consumed = consumedArg + 0
  accepted = acceptedArg + 0
  stale = staleArg + 0
  invalid = invalidArg + 0
  code = codeArg~string
  detail = detailArg~string
  more = (moreArg == .true)

/* Observer over the subscribed Queue Fabric read model.  Topic data can defer
 * unsafe local stale inference, but it never proves mutation authority. */
::class QueueMigrationTopicObservationProvider public
::constant PROVIDER_ID "migratable-job-status-topic-v0.2.2"
::constant CODE_STATUS_ACTIVE "MIGRATION_STATUS_ACTIVE"
::constant CODE_STATUS_PAUSED "MIGRATION_STATUS_PAUSED"
::constant CODE_STATUS_FAILED "MIGRATION_STATUS_FAILED"
::constant CODE_STATUS_DESTINATION_RUNNING "MIGRATION_STATUS_DESTINATION_RUNNING"
::attribute cache get
::method init
  expose cache
  use strict arg cacheArg
  cache = cacheArg
::method observe
  expose cache
  use strict arg record
  snapshot = cache~latest(record~qid)
  if snapshot == .nil then return .QueueJobObservation~new(.QueueJobObservation~NOT_APPLICABLE, self~PROVIDER_ID, "NO_SUBSCRIBED_STATUS")
  evidence = snapshot~asDirectory
  payload = snapshot~payload
  if payload~hasIndex("sourceNodeId") then evidence["source_node"] = payload["sourceNodeId"]
  if payload~hasIndex("destinationNodeId") then evidence["destination_node"] = payload["destinationNodeId"]
  state = snapshot~state
  if state == .QueueMigrationState~RUNNING then return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_STATUS_DESTINATION_RUNNING, "retained migration status reports destination resumed; execution liveness remains provider-owned", evidence)
  if state == .QueueMigrationState~FAILED then return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_STATUS_FAILED, "migration status reports failure; reconcile against durable authority before stale mutation", evidence)
  if state == .QueueMigrationState~PAUSED then return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_STATUS_PAUSED, "migration is paused; local process death is not stale-job proof", evidence)
  if .QueueMigrationState~active(state) then return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_STATUS_ACTIVE, "subscribed migration status owns execution continuity observation; local stale inference is deferred", evidence)
  return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_STATUS_ACTIVE, "subscribed migration status is forward/unknown state; fail conservative", evidence)

::class QueueMigrationTopicAwareJobObserver public
::attribute baseObserver get
::attribute migrationObserver get
::attribute subscriber get
::method init
  expose baseObserver migrationObserver subscriber
  use strict arg subscriberArg, providerRegistryArg = .nil
  subscriber = subscriberArg
  baseObserver = .QueueJobObserver~new(providerRegistryArg)
  migrationObserver = .QueueMigrationTopicObservationProvider~new(subscriber~cache)
::method refresh
  expose subscriber
  use arg maxMessagesArg = .nil
  if maxMessagesArg == .nil then return subscriber~drain
  return subscriber~drain(maxMessagesArg)
::method observe
  expose baseObserver migrationObserver
  use strict arg record
  migrationObservation = migrationObserver~observe(record)
  if migrationObservation~status \= .QueueJobObservation~NOT_APPLICABLE then return migrationObservation
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

::requires "QueueRexxMigratableJob.cls"
::requires "MigratableJobStatusTopic.cls"
::requires "ObjectQueueTopics.cls"
