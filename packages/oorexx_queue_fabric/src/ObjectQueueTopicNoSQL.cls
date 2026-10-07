/* NoSQLServer v0.73 projection adapter for ObjectQueueFabric v0.8 topics. */

::class QueueTopicNoSQLAdapter public
::attribute topicFabric get
::attribute baseAdapter get
::attribute prefix get

::method init
  expose topicFabric baseAdapter prefix
  use strict arg topicFabric, baseAdapter = .nil, prefix = "mq_"
  topicFabric = topicFabric
  baseAdapter = baseAdapter
  prefix = prefix~string

::method query
  use strict arg principal, sqlText
  engine = self~buildEngine(principal)
  return .NoSQLServerSQL~new(engine)~execute(sqlText)

::method buildEngine private
  use strict arg principal
  engine = .ObjectDatabaseEngine~new
  if \self~snapshotInto(engine, principal) then raise syntax 88.900 array("Unable to project queue topic tables")
  return engine

::method snapshotInto
  expose topicFabric baseAdapter prefix
  use strict arg federatedEngine, principal
  effectiveBase = baseAdapter
  if effectiveBase == .nil then effectiveBase = .QueueNoSQLAdapter~new(topicFabric~queueManager, prefix)
  if \effectiveBase~snapshotInto(federatedEngine, principal) then return .false

  topicRows = .array~new
  do topicObject over topicFabric~authorisedTopics(principal)
    topicRows~append(.QueueNoSQLTopicRow~new(topicObject))
  end
  topicMap = .ObjectTableMapping~new(prefix || "topics")
  ignore = topicMap~column("topic_name", "VARCHAR", "topicName")
  ignore = topicMap~column("topic_id", "VARCHAR", "topicId")
  ignore = topicMap~column("topic_string", "VARCHAR", "topicString")
  ignore = topicMap~column("lifecycle", "VARCHAR", "lifecycle")
  ignore = topicMap~column("security_domain", "VARCHAR", "securityDomain")
  ignore = topicMap~column("owner", "VARCHAR", "owner")
  ignore = topicMap~column("created_at", "VARCHAR", "createdAt")
  ignore = topicMap~identity("topic_name")
  if \federatedEngine~registerSnapshot(prefix || "topics", topicRows, topicMap) then return .false

  subscriptionRows = .array~new
  do subscriptionObject over topicFabric~authorisedSubscriptions(principal)
    subscriptionRows~append(.QueueNoSQLTopicSubscriptionRow~new(subscriptionObject))
  end
  subscriptionMap = .ObjectTableMapping~new(prefix || "topic_subscriptions")
  ignore = subscriptionMap~column("subscription_name", "VARCHAR", "subscriptionName")
  ignore = subscriptionMap~column("subscription_id", "VARCHAR", "subscriptionId")
  ignore = subscriptionMap~column("topic_name", "VARCHAR", "topicName")
  ignore = subscriptionMap~column("pattern", "VARCHAR", "pattern")
  ignore = subscriptionMap~column("resolved_pattern", "VARCHAR", "resolvedPattern")
  ignore = subscriptionMap~column("queue_name", "VARCHAR", "queueName")
  ignore = subscriptionMap~column("lifecycle", "VARCHAR", "lifecycle")
  ignore = subscriptionMap~column("owner", "VARCHAR", "owner")
  ignore = subscriptionMap~column("allow_cross_domain", "INTEGER", "crossDomainFlag")
  ignore = subscriptionMap~column("deliver_retained", "INTEGER", "deliverRetainedFlag")
  ignore = subscriptionMap~column("created_at", "VARCHAR", "createdAt")
  ignore = subscriptionMap~identity("subscription_name")
  if \federatedEngine~registerSnapshot(prefix || "topic_subscriptions", subscriptionRows, subscriptionMap) then return .false

  retainedRows = .array~new
  do publication over topicFabric~authorisedRetained(principal)
    retainedRows~append(.QueueNoSQLRetainedPublicationRow~new(publication))
  end
  retainedMap = .ObjectTableMapping~new(prefix || "retained_publications")
  ignore = retainedMap~column("publication_id", "VARCHAR", "publicationId")
  ignore = retainedMap~column("topic_name", "VARCHAR", "topicName")
  ignore = retainedMap~column("topic_string", "VARCHAR", "topicString")
  ignore = retainedMap~column("payload_class", "VARCHAR", "payloadClass")
  ignore = retainedMap~column("priority", "INTEGER", "priority")
  ignore = retainedMap~column("persistent", "INTEGER", "persistentFlag")
  ignore = retainedMap~column("security_domain", "VARCHAR", "securityDomain")
  ignore = retainedMap~column("correlation_id", "VARCHAR", "correlationId")
  ignore = retainedMap~column("reply_to", "VARCHAR", "replyTo")
  ignore = retainedMap~column("expiry_tick", "VARCHAR", "expiryTick")
  ignore = retainedMap~column("retained_at", "VARCHAR", "retainedAt")
  ignore = retainedMap~identity("publication_id")
  if \federatedEngine~registerSnapshot(prefix || "retained_publications", retainedRows, retainedMap) then return .false

  grantRows = .array~new
  do grantRow over topicFabric~authorisedGrantRows(principal)
    grantRows~append(.QueueNoSQLTopicGrantRow~new(grantRow))
  end
  grantMap = .ObjectTableMapping~new(prefix || "topic_grants")
  ignore = grantMap~column("grant_id", "VARCHAR", "grantId")
  ignore = grantMap~column("topic_name", "VARCHAR", "topicName")
  ignore = grantMap~column("principal", "VARCHAR", "principal")
  ignore = grantMap~column("action", "VARCHAR", "action")
  ignore = grantMap~identity("grant_id")
  if \federatedEngine~registerSnapshot(prefix || "topic_grants", grantRows, grantMap) then return .false

  trafficRows = .array~new
  do event over topicFabric~authorisedTraffic(principal)
    trafficRows~append(.QueueNoSQLTopicTrafficRow~new(event))
  end
  trafficMap = .ObjectTableMapping~new(prefix || "topic_traffic")
  ignore = trafficMap~column("event_id", "VARCHAR", "eventId")
  ignore = trafficMap~column("timestamp", "VARCHAR", "timestamp")
  ignore = trafficMap~column("event_type", "VARCHAR", "eventType")
  ignore = trafficMap~column("topic_name", "VARCHAR", "topicName")
  ignore = trafficMap~column("publication_id", "VARCHAR", "publicationId")
  ignore = trafficMap~column("principal", "VARCHAR", "principal")
  ignore = trafficMap~column("detail", "VARCHAR", "detail")
  ignore = trafficMap~column("topic_string", "VARCHAR", "topicString")
  ignore = trafficMap~column("destination_queue", "VARCHAR", "destinationQueue")
  ignore = trafficMap~column("success", "INTEGER", "successFlag")
  ignore = trafficMap~identity("event_id")
  if \federatedEngine~registerSnapshot(prefix || "topic_traffic", trafficRows, trafficMap) then return .false

  return .true

::class QueueNoSQLTopicRow
::attribute topicName get
::attribute topicId get
::attribute topicString get
::attribute lifecycle get
::attribute securityDomain get
::attribute owner get
::attribute createdAt get
::method init
  expose topicName topicId topicString lifecycle securityDomain owner createdAt
  use strict arg topicObject
  topicName = topicObject~name
  topicId = topicObject~topicId
  topicString = topicObject~topicString
  lifecycle = topicObject~lifecycle
  securityDomain = topicObject~securityDomain
  owner = topicObject~owner
  createdAt = topicObject~createdAt

::class QueueNoSQLTopicSubscriptionRow
::attribute subscriptionName get
::attribute subscriptionId get
::attribute topicName get
::attribute pattern get
::attribute resolvedPattern get
::attribute queueName get
::attribute lifecycle get
::attribute owner get
::attribute crossDomainFlag get
::attribute deliverRetainedFlag get
::attribute createdAt get
::method init
  expose subscriptionName subscriptionId topicName pattern resolvedPattern queueName lifecycle owner crossDomainFlag deliverRetainedFlag createdAt
  use strict arg subscriptionObject
  subscriptionName = subscriptionObject~name
  subscriptionId = subscriptionObject~subscriptionId
  topicName = subscriptionObject~topicName
  pattern = subscriptionObject~pattern
  resolvedPattern = subscriptionObject~resolvedPattern
  queueName = subscriptionObject~queueName
  lifecycle = subscriptionObject~lifecycle
  owner = subscriptionObject~owner
  if subscriptionObject~allowCrossDomain then crossDomainFlag = 1
  else crossDomainFlag = 0
  if subscriptionObject~deliverRetained then deliverRetainedFlag = 1
  else deliverRetainedFlag = 0
  createdAt = subscriptionObject~createdAt

::class QueueNoSQLRetainedPublicationRow
::attribute publicationId get
::attribute topicName get
::attribute topicString get
::attribute payloadClass get
::attribute priority get
::attribute persistentFlag get
::attribute securityDomain get
::attribute correlationId get
::attribute replyTo get
::attribute expiryTick get
::attribute retainedAt get
::method init
  expose publicationId topicName topicString payloadClass priority persistentFlag securityDomain correlationId replyTo expiryTick retainedAt
  use strict arg publication
  publicationId = publication~publicationId
  topicName = publication~topicName
  topicString = publication~topicString
  payloadClass = publication~payloadClass
  priority = publication~priority
  if publication~persistent then persistentFlag = 1
  else persistentFlag = 0
  securityDomain = publication~securityDomain
  correlationId = publication~correlationId
  replyTo = publication~replyTo
  expiryTick = publication~expiryTick
  retainedAt = publication~retainedAt

::class QueueNoSQLTopicGrantRow
::attribute grantId get
::attribute topicName get
::attribute principal get
::attribute action get
::method init
  expose grantId topicName principal action
  use strict arg row
  topicName = row[1]
  principal = row[2]
  action = row[3]
  grantId = topicName || "|" || principal || "|" || action

::class QueueNoSQLTopicTrafficRow
::attribute eventId get
::attribute timestamp get
::attribute eventType get
::attribute topicName get
::attribute publicationId get
::attribute principal get
::attribute detail get
::attribute topicString get
::attribute destinationQueue get
::attribute successFlag get
::method init
  expose eventId timestamp eventType topicName publicationId principal detail topicString destinationQueue successFlag
  use strict arg event
  eventId = event~eventId
  timestamp = event~timestamp
  eventType = event~eventType
  topicName = event~queueName
  publicationId = event~packageId
  principal = event~principal
  detail = event~detail
  topicString = event~sourceQueue
  destinationQueue = event~destinationQueue
  if event~success then successFlag = 1
  else successFlag = 0

::requires "ObjectQueueTopics.cls"
::requires "ObjectQueueNoSQL.cls"
