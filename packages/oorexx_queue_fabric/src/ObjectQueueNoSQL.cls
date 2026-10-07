/* NoSQLServer v0.73 projection adapter for ObjectQueueFabric v0.8. */

::class QueueNoSQLAdapter public
::attribute manager get
::attribute prefix get

::method init
  expose manager prefix
  use arg manager, prefix = "mq_"
  manager = manager
  prefix = prefix~string

::method query
  use arg principal, sqlText
  engine = self~buildEngine(principal)
  return .NoSQLServerSQL~new(engine)~execute(sqlText)

::method buildEngine private
  expose manager prefix
  use arg principal
  engine = .ObjectDatabaseEngine~new

  queues = .array~new
  do q over manager~authorisedQueues(principal)
    queues~append(.QueueNoSQLQueueRow~new(q))
  end
  queueMap = .ObjectTableMapping~new(prefix || "queues")
  ignore = queueMap~column("queue_name", "VARCHAR", "queueName")
  ignore = queueMap~column("queue_id", "VARCHAR", "queueId")
  ignore = queueMap~column("lifecycle", "VARCHAR", "lifecycle")
  ignore = queueMap~column("security_domain", "VARCHAR", "securityDomain")
  ignore = queueMap~column("max_depth", "INTEGER", "maxDepth")
  ignore = queueMap~column("ready_depth", "INTEGER", "readyDepth")
  ignore = queueMap~column("inflight_depth", "INTEGER", "inflightDepth")
  ignore = queueMap~column("total_depth", "INTEGER", "totalDepth")
  ignore = queueMap~column("state", "VARCHAR", "state")
  ignore = queueMap~column("owner", "VARCHAR", "owner")
  ignore = queueMap~column("created_at", "VARCHAR", "createdAt")
  ignore = queueMap~column("backout_threshold", "INTEGER", "backoutThreshold")
  ignore = queueMap~column("backout_queue", "VARCHAR", "backoutQueue")
  ignore = queueMap~column("expiring_depth", "INTEGER", "expiringDepth")
  ignore = queueMap~column("earliest_expiry_tick", "VARCHAR", "earliestExpiryTick")
  ignore = queueMap~identity("queue_name")
  ignore = engine~register(prefix || "queues", queues, queueMap)

  packages = .array~new
  do package over manager~authorisedPackages(principal)
    packages~append(.QueueNoSQLPackageRow~new(package))
  end
  packageMap = .ObjectTableMapping~new(prefix || "packages")
  ignore = packageMap~column("package_id", "VARCHAR", "packageId")
  ignore = packageMap~column("queue_name", "VARCHAR", "queueName")
  ignore = packageMap~column("state", "VARCHAR", "state")
  ignore = packageMap~column("priority", "INTEGER", "priority")
  ignore = packageMap~column("persistent", "INTEGER", "persistentFlag")
  ignore = packageMap~column("security_domain", "VARCHAR", "securityDomain")
  ignore = packageMap~column("routing_key", "VARCHAR", "routingKey")
  ignore = packageMap~column("correlation_id", "VARCHAR", "correlationId")
  ignore = packageMap~column("reply_to", "VARCHAR", "replyTo")
  ignore = packageMap~column("payload_class", "VARCHAR", "payloadClass")
  ignore = packageMap~column("created_at", "VARCHAR", "createdAt")
  ignore = packageMap~column("claimed_by", "VARCHAR", "claimedBy")
  ignore = packageMap~column("delivery_count", "INTEGER", "deliveryCount")
  ignore = packageMap~column("parent_package_id", "VARCHAR", "parentPackageId")
  ignore = packageMap~column("expiry_tick", "VARCHAR", "expiryTick")
  ignore = packageMap~column("backout_count", "INTEGER", "backoutCount")
  ignore = packageMap~column("dead_letter_reason", "VARCHAR", "deadLetterReason")
  ignore = packageMap~column("dead_letter_source_queue", "VARCHAR", "deadLetterSourceQueue")
  ignore = packageMap~identity("package_id")
  ignore = engine~register(prefix || "packages", packages, packageMap)

  triggerRows = .array~new
  do reg over manager~authorisedTriggers(principal)
    triggerRows~append(.QueueNoSQLTriggerRow~new(reg))
  end
  triggerMap = .ObjectTableMapping~new(prefix || "triggers")
  ignore = triggerMap~column("trigger_id", "VARCHAR", "triggerId")
  ignore = triggerMap~column("queue_name", "VARCHAR", "queueName")
  ignore = triggerMap~column("kind", "VARCHAR", "kind")
  ignore = triggerMap~column("threshold", "INTEGER", "threshold")
  ignore = triggerMap~column("target_kind", "VARCHAR", "targetKind")
  ignore = triggerMap~column("target", "VARCHAR", "targetDescription")
  ignore = triggerMap~column("persistent_registration", "INTEGER", "persistentFlag")
  ignore = triggerMap~column("registered_by", "VARCHAR", "registeredBy")
  ignore = triggerMap~column("registered_at", "VARCHAR", "registeredAt")
  ignore = triggerMap~identity("trigger_id")
  ignore = engine~register(prefix || "triggers", triggerRows, triggerMap)

  routeRows = .array~new
  do rule over manager~authorisedRoutes(principal)
    routeRows~append(.QueueNoSQLRouteRow~new(rule))
  end
  routeMap = .ObjectTableMapping~new(prefix || "routes")
  ignore = routeMap~column("route_id", "VARCHAR", "routeId")
  ignore = routeMap~column("source_queue", "VARCHAR", "sourceQueue")
  ignore = routeMap~column("routing_key", "VARCHAR", "routingKey")
  ignore = routeMap~column("destination_queue", "VARCHAR", "destinationQueue")
  ignore = routeMap~column("mode", "VARCHAR", "mode")
  ignore = routeMap~column("priority", "INTEGER", "priority")
  ignore = routeMap~column("allow_cross_domain", "INTEGER", "crossDomainFlag")
  ignore = routeMap~column("registered_by", "VARCHAR", "registeredBy")
  ignore = routeMap~column("registered_at", "VARCHAR", "registeredAt")
  ignore = routeMap~identity("route_id")
  ignore = engine~register(prefix || "routes", routeRows, routeMap)

  trafficRows = .array~new
  do event over manager~authorisedTraffic(principal)
    trafficRows~append(.QueueNoSQLTrafficRow~new(event))
  end
  trafficMap = .ObjectTableMapping~new(prefix || "traffic")
  ignore = trafficMap~column("event_id", "VARCHAR", "eventId")
  ignore = trafficMap~column("timestamp", "VARCHAR", "timestamp")
  ignore = trafficMap~column("event_type", "VARCHAR", "eventType")
  ignore = trafficMap~column("queue_name", "VARCHAR", "queueName")
  ignore = trafficMap~column("package_id", "VARCHAR", "packageId")
  ignore = trafficMap~column("principal", "VARCHAR", "principal")
  ignore = trafficMap~column("detail", "VARCHAR", "detail")
  ignore = trafficMap~column("source_queue", "VARCHAR", "sourceQueue")
  ignore = trafficMap~column("destination_queue", "VARCHAR", "destinationQueue")
  ignore = trafficMap~column("success", "INTEGER", "successFlag")
  ignore = trafficMap~identity("event_id")
  ignore = engine~register(prefix || "traffic", trafficRows, trafficMap)

  receiptRows = .array~new
  do receipt over manager~authorisedTransferReceipts(principal)
    receiptRows~append(.QueueNoSQLTransferReceiptRow~new(receipt))
  end
  receiptMap = .ObjectTableMapping~new(prefix || "transfer_receipts")
  ignore = receiptMap~column("transfer_id", "VARCHAR", "transferId")
  ignore = receiptMap~column("package_id", "VARCHAR", "packageId")
  ignore = receiptMap~column("queue_name", "VARCHAR", "queueName")
  ignore = receiptMap~column("accepted_at", "VARCHAR", "acceptedAt")
  ignore = receiptMap~column("source_manager", "VARCHAR", "sourceManager")
  ignore = receiptMap~identity("transfer_id")
  ignore = engine~register(prefix || "transfer_receipts", receiptRows, receiptMap)

  managerRows = .array~new
  if principal~string = manager~adminPrincipal then managerRows~append(.QueueNoSQLManagerRow~new(manager))
  managerMap = .ObjectTableMapping~new(prefix || "manager")
  ignore = managerMap~column("fabric_version", "VARCHAR", "fabricVersion")
  ignore = managerMap~column("dead_letter_queue", "VARCHAR", "deadLetterQueue")
  ignore = managerMap~column("active_uow_count", "INTEGER", "activeUnitOfWorkCount")
  ignore = managerMap~column("recovery_warning_count", "INTEGER", "recoveryWarningCount")
  ignore = managerMap~identity("fabric_version")
  ignore = engine~register(prefix || "manager", managerRows, managerMap)

  return engine

::method snapshotInto
  expose manager prefix
  use arg federatedEngine, principal
  localEngine = self~buildEngine(principal)
  tableNames = .array~of(prefix || "queues", prefix || "packages", prefix || "triggers", prefix || "routes", prefix || "traffic", prefix || "transfer_receipts", prefix || "manager")
  do tableName over tableNames
    tableObject = localEngine~table(tableName)
    collection = tableObject~storage~collection
    mapping = tableObject~mapping
    if \federatedEngine~registerSnapshot(tableName, collection, mapping) then return .false
  end
  return .true

::class QueueNoSQLQueueRow
::attribute queueName get
::attribute queueId get
::attribute lifecycle get
::attribute securityDomain get
::attribute maxDepth get
::attribute readyDepth get
::attribute inflightDepth get
::attribute totalDepth get
::attribute state get
::attribute owner get
::attribute createdAt get
::attribute backoutThreshold get
::attribute backoutQueue get
::attribute expiringDepth get
::attribute earliestExpiryTick get
::method init
  expose queueName queueId lifecycle securityDomain maxDepth readyDepth inflightDepth totalDepth state owner createdAt backoutThreshold backoutQueue expiringDepth earliestExpiryTick
  use arg q
  queueName = q~name
  queueId = q~queueId
  lifecycle = q~lifecycle
  securityDomain = q~securityDomain
  maxDepth = q~maxDepth
  readyDepth = q~readyDepth
  inflightDepth = q~inflightDepth
  totalDepth = q~totalDepth
  state = q~state
  owner = q~owner
  createdAt = q~createdAt
  backoutThreshold = q~backoutThreshold
  backoutQueue = q~backoutQueue
  expiringDepth = q~expiringDepth
  earliestExpiryTick = q~earliestExpiryTick

::class QueueNoSQLPackageRow
::attribute packageId get
::attribute queueName get
::attribute state get
::attribute priority get
::attribute persistentFlag get
::attribute securityDomain get
::attribute routingKey get
::attribute correlationId get
::attribute replyTo get
::attribute payloadClass get
::attribute createdAt get
::attribute claimedBy get
::attribute deliveryCount get
::attribute parentPackageId get
::attribute expiryTick get
::attribute backoutCount get
::attribute deadLetterReason get
::attribute deadLetterSourceQueue get
::method init
  expose packageId queueName state priority persistentFlag securityDomain routingKey correlationId replyTo payloadClass createdAt claimedBy deliveryCount parentPackageId expiryTick backoutCount deadLetterReason deadLetterSourceQueue
  use arg package
  packageId = package~packageId
  queueName = package~currentQueue
  state = package~state
  priority = package~priority
  if package~persistent then persistentFlag = 1
  else persistentFlag = 0
  securityDomain = package~securityDomain
  routingKey = package~routingKey
  correlationId = package~correlationId
  replyTo = package~replyTo
  payloadClass = package~payloadClass
  createdAt = package~createdAt
  claimedBy = package~claimedBy
  deliveryCount = package~deliveryCount
  parentPackageId = package~parentPackageId
  expiryTick = package~expiryTick
  backoutCount = package~backoutCount
  deadLetterReason = package~deadLetterReason
  deadLetterSourceQueue = package~deadLetterSourceQueue

::class QueueNoSQLTriggerRow
::attribute triggerId get
::attribute queueName get
::attribute kind get
::attribute threshold get
::attribute targetKind get
::attribute targetDescription get
::attribute persistentFlag get
::attribute registeredBy get
::attribute registeredAt get
::method init
  expose triggerId queueName kind threshold targetKind targetDescription persistentFlag registeredBy registeredAt
  use arg registration
  triggerId = registration~triggerId
  queueName = registration~queueName
  kind = registration~kind
  threshold = registration~threshold
  targetKind = registration~target~kind
  targetDescription = registration~target~description
  if registration~target~persistent then persistentFlag = 1
  else persistentFlag = 0
  registeredBy = registration~registeredBy
  registeredAt = registration~registeredAt

::class QueueNoSQLRouteRow
::attribute routeId get
::attribute sourceQueue get
::attribute routingKey get
::attribute destinationQueue get
::attribute mode get
::attribute priority get
::attribute crossDomainFlag get
::attribute registeredBy get
::attribute registeredAt get
::method init
  expose routeId sourceQueue routingKey destinationQueue mode priority crossDomainFlag registeredBy registeredAt
  use arg rule
  routeId = rule~routeId
  sourceQueue = rule~sourceQueue
  routingKey = rule~routingKey
  destinationQueue = rule~destinationQueue
  mode = rule~mode
  priority = rule~priority
  if rule~allowCrossDomain then crossDomainFlag = 1
  else crossDomainFlag = 0
  registeredBy = rule~registeredBy
  registeredAt = rule~registeredAt

::class QueueNoSQLTrafficRow
::attribute eventId get
::attribute timestamp get
::attribute eventType get
::attribute queueName get
::attribute packageId get
::attribute principal get
::attribute detail get
::attribute sourceQueue get
::attribute destinationQueue get
::attribute successFlag get
::method init
  expose eventId timestamp eventType queueName packageId principal detail sourceQueue destinationQueue successFlag
  use arg event
  eventId = event~eventId
  timestamp = event~timestamp
  eventType = event~eventType
  queueName = event~queueName
  packageId = event~packageId
  principal = event~principal
  detail = event~detail
  sourceQueue = event~sourceQueue
  destinationQueue = event~destinationQueue
  if event~success then successFlag = 1
  else successFlag = 0

::requires "ObjectQueueFabric.cls"

::class QueueNoSQLTransferReceiptRow
::attribute transferId get
::attribute packageId get
::attribute queueName get
::attribute acceptedAt get
::attribute sourceManager get
::method init
  expose transferId packageId queueName acceptedAt sourceManager
  use arg receipt
  transferId = receipt~transferId
  packageId = receipt~packageId
  queueName = receipt~queueName
  acceptedAt = receipt~acceptedAt
  sourceManager = receipt~sourceManager

::class QueueNoSQLManagerRow
::attribute fabricVersion get
::attribute deadLetterQueue get
::attribute activeUnitOfWorkCount get
::attribute recoveryWarningCount get
::method init
  expose fabricVersion deadLetterQueue activeUnitOfWorkCount recoveryWarningCount
  use arg manager
  fabricVersion = .QueueFabricBuild~VERSION
  deadLetterQueue = manager~deadLetterQueue
  activeUnitOfWorkCount = manager~activeUnitOfWorkCount
  recoveryWarningCount = manager~recoveryWarnings~items

::requires "NoSQLServer.cls"
