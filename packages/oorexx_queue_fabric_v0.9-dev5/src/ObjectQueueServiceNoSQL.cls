/* NoSQLServer v0.77 operational projection for Queue Fabric v0.9 broker service. */

::class QueueBrokerServiceNoSQLAdapter public
::attribute service get
::attribute prefix get

::method init
  expose service prefix
  use strict arg service, prefix = "mq_"
  if service == .nil | \service~isA(.QueueBrokerService) then raise syntax 88.900 array("QueueBrokerServiceNoSQLAdapter requires QueueBrokerService")
  service = service
  prefix = prefix~string

::method query
  use strict arg principal, sqlText
  engine = .ObjectDatabaseEngine~new
  if \self~snapshotInto(engine, principal) then raise syntax 88.900 array("Unable to project queue broker service tables")
  return .NoSQLServerSQL~new(engine)~execute(sqlText)

::method snapshotInto
  expose service prefix
  use strict arg federatedEngine, principal
  serviceRows = .array~new
  retryRows = .array~new
  wluRows = .array~new
  if principal~string = service~adminPrincipal then do
    serviceRows~append(.QueueNoSQLBrokerServiceRow~new(service))
    do retryState over service~retryStateRows
      retryRows~append(.QueueNoSQLBrokerRetryRow~new(service~serviceName, retryState))
    end
    policy = service~admissionPolicy
    if policy~hasMethod("IDENTITY") & policy~hasMethod("SCOPEPREFIX") & policy~hasMethod("EXPECTEDMICROWLU") then wluRows~append(.QueueNoSQLBrokerWLURow~new(service~serviceName, policy))
  end

  serviceMap = .ObjectTableMapping~new(prefix || "broker_services")
  ignore = serviceMap~column("service_name", "VARCHAR", "serviceName")
  ignore = serviceMap~column("state", "VARCHAR", "state")
  ignore = serviceMap~column("pump_interval_seconds", "DECIMAL", "pumpIntervalSeconds")
  ignore = serviceMap~column("retry_base_seconds", "DECIMAL", "retryBaseSeconds")
  ignore = serviceMap~column("retry_cap_seconds", "DECIMAL", "retryCapSeconds")
  ignore = serviceMap~column("heartbeat_interval_seconds", "DECIMAL", "heartbeatIntervalSeconds")
  ignore = serviceMap~column("cycles", "INTEGER", "cycles")
  ignore = serviceMap~column("sent_count", "INTEGER", "sentCount")
  ignore = serviceMap~column("denial_count", "INTEGER", "denialCount")
  ignore = serviceMap~column("failure_count", "INTEGER", "failureCount")
  ignore = serviceMap~column("heartbeat_count", "INTEGER", "heartbeatCount")
  ignore = serviceMap~column("heartbeat_denial_count", "INTEGER", "heartbeatDenialCount")
  ignore = serviceMap~column("heartbeat_failure_count", "INTEGER", "heartbeatFailureCount")
  ignore = serviceMap~column("last_heartbeat_at", "VARCHAR", "lastHeartbeatAt")
  ignore = serviceMap~column("last_heartbeat_error", "VARCHAR", "lastHeartbeatError")
  ignore = serviceMap~column("last_error", "VARCHAR", "lastError")
  ignore = serviceMap~column("admission_policy", "VARCHAR", "admissionPolicy")
  ignore = serviceMap~column("listener_attached", "INTEGER", "listenerAttached")
  ignore = serviceMap~identity("service_name")
  if \federatedEngine~registerSnapshot(prefix || "broker_services", serviceRows, serviceMap) then return .false

  retryMap = .ObjectTableMapping~new(prefix || "broker_retries")
  ignore = retryMap~column("retry_id", "VARCHAR", "retryId")
  ignore = retryMap~column("service_name", "VARCHAR", "serviceName")
  ignore = retryMap~column("channel_name", "VARCHAR", "channelName")
  ignore = retryMap~column("attempts", "INTEGER", "attempts")
  ignore = retryMap~column("deadline_tick", "VARCHAR", "deadlineTick")
  ignore = retryMap~column("seconds_until", "DECIMAL", "secondsUntil")
  ignore = retryMap~identity("retry_id")
  if \federatedEngine~registerSnapshot(prefix || "broker_retries", retryRows, retryMap) then return .false

  wluMap = .ObjectTableMapping~new(prefix || "broker_wlu")
  ignore = wluMap~column("service_name", "VARCHAR", "serviceName")
  ignore = wluMap~column("identity", "VARCHAR", "identity")
  ignore = wluMap~column("scope_prefix", "VARCHAR", "scopePrefix")
  ignore = wluMap~column("expected_micro_wlu", "INTEGER", "expectedMicroWlu")
  ignore = wluMap~column("ceiling_micro_wlu", "INTEGER", "ceilingMicroWlu")
  ignore = wluMap~column("requested_rate_micro_wlu_per_second", "INTEGER", "requestedRateMicroWluPerSecond")
  ignore = wluMap~column("ttl_seconds", "INTEGER", "ttlSeconds")
  ignore = wluMap~column("heartbeat_expected_micro_wlu", "INTEGER", "heartbeatExpectedMicroWlu")
  ignore = wluMap~column("heartbeat_ceiling_micro_wlu", "INTEGER", "heartbeatCeilingMicroWlu")
  ignore = wluMap~column("heartbeat_rate_micro_wlu_per_second", "INTEGER", "heartbeatRateMicroWluPerSecond")
  ignore = wluMap~identity("service_name")
  if \federatedEngine~registerSnapshot(prefix || "broker_wlu", wluRows, wluMap) then return .false
  return .true

::class QueueNoSQLBrokerServiceRow
::attribute serviceName get
::attribute state get
::attribute pumpIntervalSeconds get
::attribute retryBaseSeconds get
::attribute retryCapSeconds get
::attribute heartbeatIntervalSeconds get
::attribute cycles get
::attribute sentCount get
::attribute denialCount get
::attribute failureCount get
::attribute heartbeatCount get
::attribute heartbeatDenialCount get
::attribute heartbeatFailureCount get
::attribute lastHeartbeatAt get
::attribute lastHeartbeatError get
::attribute lastError get
::attribute admissionPolicy get
::attribute listenerAttached get

::method init
  expose serviceName state pumpIntervalSeconds retryBaseSeconds retryCapSeconds heartbeatIntervalSeconds cycles sentCount denialCount failureCount heartbeatCount heartbeatDenialCount heartbeatFailureCount lastHeartbeatAt lastHeartbeatError lastError admissionPolicy listenerAttached
  use strict arg service
  serviceName = service~serviceName
  state = service~state
  pumpIntervalSeconds = service~pumpIntervalSeconds
  retryBaseSeconds = service~retryBaseSeconds
  retryCapSeconds = service~retryCapSeconds
  heartbeatIntervalSeconds = service~heartbeatIntervalSeconds
  cycles = service~cycles
  sentCount = service~sentCount
  denialCount = service~denialCount
  failureCount = service~failureCount
  heartbeatCount = service~heartbeatCount
  heartbeatDenialCount = service~heartbeatDenialCount
  heartbeatFailureCount = service~heartbeatFailureCount
  lastHeartbeatAt = service~lastHeartbeatAt
  lastHeartbeatError = service~lastHeartbeatError
  lastError = service~lastError
  admissionPolicy = service~admissionPolicy~class~id
  if service~listener == .nil then listenerAttached = 0
  else listenerAttached = 1

::class QueueNoSQLBrokerRetryRow
::attribute retryId get
::attribute serviceName get
::attribute channelName get
::attribute attempts get
::attribute deadlineTick get
::attribute secondsUntil get

::method init
  expose retryId serviceName channelName attempts deadlineTick secondsUntil
  use strict arg serviceName, retryState
  channelName = retryState~channelName
  retryId = serviceName || "|" || channelName
  attempts = retryState~attempts
  deadlineTick = retryState~deadlineTick~string
  secondsUntil = retryState~secondsUntil

::class QueueNoSQLBrokerWLURow
::attribute serviceName get
::attribute identity get
::attribute scopePrefix get
::attribute expectedMicroWlu get
::attribute ceilingMicroWlu get
::attribute requestedRateMicroWluPerSecond get
::attribute ttlSeconds get
::attribute heartbeatExpectedMicroWlu get
::attribute heartbeatCeilingMicroWlu get
::attribute heartbeatRateMicroWluPerSecond get

::method init
  expose serviceName identity scopePrefix expectedMicroWlu ceilingMicroWlu requestedRateMicroWluPerSecond ttlSeconds heartbeatExpectedMicroWlu heartbeatCeilingMicroWlu heartbeatRateMicroWluPerSecond
  use strict arg serviceName, policy
  identity = policy~identity
  scopePrefix = policy~scopePrefix
  expectedMicroWlu = policy~expectedMicroWlu
  ceilingMicroWlu = policy~ceilingMicroWlu
  requestedRateMicroWluPerSecond = policy~requestedRateMicroWluPerSecond
  ttlSeconds = policy~ttlSeconds
  heartbeatExpectedMicroWlu = policy~heartbeatExpectedMicroWlu
  heartbeatCeilingMicroWlu = policy~heartbeatCeilingMicroWlu
  heartbeatRateMicroWluPerSecond = policy~heartbeatRateMicroWluPerSecond

::requires "ObjectQueueBrokerService.cls"
::requires "ObjectQueueWLU.cls"
::requires "NoSQLServer.cls"
