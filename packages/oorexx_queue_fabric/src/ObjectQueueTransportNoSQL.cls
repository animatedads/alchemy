/* NoSQLServer v0.77 projection adapter for Queue Fabric socket transport. */

::class QueueTransportNoSQLAdapter public
::attribute transport get
::attribute listener get
::attribute channelFabric get
::attribute prefix get

::method init
  expose transport listener channelFabric prefix
  use strict arg transport, channelFabric, listener = .nil, prefix = "mq_"
  transport = transport
  channelFabric = channelFabric
  listener = listener
  prefix = prefix~string

::method query
  use strict arg principal, sqlText
  engine = self~buildEngine(principal)
  return .NoSQLServerSQL~new(engine)~execute(sqlText)

::method buildEngine private
  use strict arg principal
  engine = .ObjectDatabaseEngine~new
  if \self~snapshotInto(engine, principal) then raise syntax 88.900 array("Unable to project queue transport tables")
  return engine

::method snapshotInto
  expose transport listener channelFabric prefix
  use strict arg federatedEngine, principal
  channelAdapter = .QueueChannelNoSQLAdapter~new(channelFabric, prefix)
  if \channelAdapter~snapshotInto(federatedEngine, principal) then return .false

  endpointRows = .array~new
  do endpoint over transport~authorisedEndpoints(principal)
    endpointRows~append(.QueueNoSQLTransportEndpointRow~new(endpoint))
  end
  endpointMap = .ObjectTableMapping~new(prefix || "transport_endpoints")
  ignore = endpointMap~column("endpoint_id", "VARCHAR", "endpointId")
  ignore = endpointMap~column("endpoint_order", "INTEGER", "endpointOrder")
  ignore = endpointMap~column("remote_manager", "VARCHAR", "remoteManager")
  ignore = endpointMap~column("host", "VARCHAR", "host")
  ignore = endpointMap~column("port", "INTEGER", "port")
  ignore = endpointMap~column("principal", "VARCHAR", "principal")
  ignore = endpointMap~column("key_id", "VARCHAR", "keyId")
  ignore = endpointMap~column("attempt_count", "INTEGER", "attemptCount")
  ignore = endpointMap~column("success_count", "INTEGER", "successCount")
  ignore = endpointMap~column("failure_count", "INTEGER", "failureCount")
  ignore = endpointMap~column("last_error", "VARCHAR", "lastError")
  ignore = endpointMap~column("last_attempt_at", "VARCHAR", "lastAttemptAt")
  ignore = endpointMap~column("last_success_at", "VARCHAR", "lastSuccessAt")
  ignore = endpointMap~column("health_attempt_count", "INTEGER", "healthAttemptCount")
  ignore = endpointMap~column("health_success_count", "INTEGER", "healthSuccessCount")
  ignore = endpointMap~column("health_failure_count", "INTEGER", "healthFailureCount")
  ignore = endpointMap~column("last_health_at", "VARCHAR", "lastHealthAt")
  ignore = endpointMap~column("last_health_error", "VARCHAR", "lastHealthError")
  ignore = endpointMap~identity("endpoint_id")
  if \federatedEngine~registerSnapshot(prefix || "transport_endpoints", endpointRows, endpointMap) then return .false

  listenerRows = .array~new
  if listener \== .nil then do
    if principal~string = transport~adminPrincipal then listenerRows~append(.QueueNoSQLTransportListenerRow~new(listener))
  end
  listenerMap = .ObjectTableMapping~new(prefix || "transport_listeners")
  ignore = listenerMap~column("manager_name", "VARCHAR", "managerName")
  ignore = listenerMap~column("bind_host", "VARCHAR", "bindHost")
  ignore = listenerMap~column("port", "INTEGER", "port")
  ignore = listenerMap~column("connection_count", "INTEGER", "connectionCount")
  ignore = listenerMap~column("authenticated_count", "INTEGER", "authenticatedCount")
  ignore = listenerMap~column("accepted_count", "INTEGER", "acceptedCount")
  ignore = listenerMap~column("rejected_count", "INTEGER", "rejectedCount")
  ignore = listenerMap~column("probe_count", "INTEGER", "probeCount")
  ignore = listenerMap~column("last_error", "VARCHAR", "lastError")
  ignore = listenerMap~identity("manager_name")
  if \federatedEngine~registerSnapshot(prefix || "transport_listeners", listenerRows, listenerMap) then return .false
  return .true

::class QueueNoSQLTransportEndpointRow
::attribute endpointId get
::attribute endpointOrder get
::attribute remoteManager get
::attribute host get
::attribute port get
::attribute principal get
::attribute keyId get
::attribute attemptCount get
::attribute successCount get
::attribute failureCount get
::attribute lastError get
::attribute lastAttemptAt get
::attribute lastSuccessAt get
::attribute healthAttemptCount get
::attribute healthSuccessCount get
::attribute healthFailureCount get
::attribute lastHealthAt get
::attribute lastHealthError get

::method init
  expose endpointId endpointOrder remoteManager host port principal keyId attemptCount successCount failureCount lastError lastAttemptAt lastSuccessAt healthAttemptCount healthSuccessCount healthFailureCount lastHealthAt lastHealthError
  use strict arg endpoint
  endpointId = endpoint~endpointId
  endpointOrder = endpoint~endpointOrder
  remoteManager = endpoint~remoteManager
  host = endpoint~host
  port = endpoint~port
  principal = endpoint~principal
  keyId = endpoint~keyId
  attemptCount = endpoint~attemptCount
  successCount = endpoint~successCount
  failureCount = endpoint~failureCount
  lastError = endpoint~lastError
  lastAttemptAt = endpoint~lastAttemptAt
  lastSuccessAt = endpoint~lastSuccessAt
  healthAttemptCount = endpoint~healthAttemptCount
  healthSuccessCount = endpoint~healthSuccessCount
  healthFailureCount = endpoint~healthFailureCount
  lastHealthAt = endpoint~lastHealthAt
  lastHealthError = endpoint~lastHealthError

::class QueueNoSQLTransportListenerRow
::attribute managerName get
::attribute bindHost get
::attribute port get
::attribute connectionCount get
::attribute authenticatedCount get
::attribute acceptedCount get
::attribute rejectedCount get
::attribute probeCount get
::attribute lastError get

::method init
  expose managerName bindHost port connectionCount authenticatedCount acceptedCount rejectedCount probeCount lastError
  use strict arg listener
  managerName = listener~managerName
  bindHost = listener~bindHost
  port = listener~port
  connectionCount = listener~connectionCount
  authenticatedCount = listener~authenticatedCount
  acceptedCount = listener~acceptedCount
  rejectedCount = listener~rejectedCount
  probeCount = listener~probeCount
  lastError = listener~lastError

::requires "ObjectQueueChannelNoSQL.cls"
::requires "ObjectQueueSocketTransport.cls"
