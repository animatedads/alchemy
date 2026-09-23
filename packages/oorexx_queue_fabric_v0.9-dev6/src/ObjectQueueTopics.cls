/*
 * ObjectQueueFabric v0.8 topic / publish-subscribe layer.
 *
 * Topics are routing objects over queues, not replacement queue types.
 * Publications remain rich ooRexx object graphs.  Each matching subscription
 * delivers a normal QueueWorkPackage to its destination queue through the
 * ObjectQueueManager unit-of-work interface.
 *
 * Topic hierarchy:
 *   / separates levels
 *   + matches exactly one level
 *   # matches zero or more levels and must be the final pattern level
 */

::class QueueTopicAccess public
::constant PUBLISH "PUBLISH"
::constant SUBSCRIBE "SUBSCRIBE"
::constant BROWSE "BROWSE"
::constant MANAGE "MANAGE"

::class QueueTopicAuthority
::method init
  nop

::class QueueTopicPattern public
::method canonicalRoot class
  use strict arg topicString
  text = self~trimSlashes(topicString~string~strip)
  if text = "" then return .QueueOperationResult~failure("INVALID_TOPIC_STRING", topicString)
  if text~pos("+") > 0 | text~pos("#") > 0 then return .QueueOperationResult~failure("TOPIC_STRING_HAS_WILDCARD", topicString)
  segments = .QueueRecordCodec~split(text, "/")
  do segment over segments
    if segment = "" then return .QueueOperationResult~failure("INVALID_TOPIC_STRING", topicString)
  end
  return .QueueOperationResult~success(text)

::method canonicalSubtopic class
  use strict arg subtopic
  text = self~trimSlashes(subtopic~string~strip)
  if text = "" then return .QueueOperationResult~success("")
  if text~pos("+") > 0 | text~pos("#") > 0 then return .QueueOperationResult~failure("SUBTOPIC_HAS_WILDCARD", subtopic)
  segments = .QueueRecordCodec~split(text, "/")
  do segment over segments
    if segment = "" then return .QueueOperationResult~failure("INVALID_SUBTOPIC", subtopic)
  end
  return .QueueOperationResult~success(text)

::method canonicalPattern class
  use strict arg pattern
  text = self~trimSlashes(pattern~string~strip)
  if text = "" then return .QueueOperationResult~success("")
  segments = .QueueRecordCodec~split(text, "/")
  do i = 1 to segments~items
    segment = segments[i]
    if segment = "" then return .QueueOperationResult~failure("INVALID_TOPIC_PATTERN", pattern)
    if segment = "#" then do
      if i \= segments~items then return .QueueOperationResult~failure("INVALID_TOPIC_PATTERN", "# must be the final level")
      iterate
    end
    if segment = "+" then iterate
    if segment~pos("+") > 0 | segment~pos("#") > 0 then return .QueueOperationResult~failure("INVALID_TOPIC_PATTERN", pattern)
  end
  return .QueueOperationResult~success(text)

::method resolve class
  use strict arg root, subtopic
  if subtopic = "" then return root
  return root || "/" || subtopic

::method resolvePattern class
  use strict arg root, pattern
  if pattern = "" then return root
  return root || "/" || pattern

::method matches class
  use strict arg resolvedPattern, concreteTopic
  patternSegments = .QueueRecordCodec~split(resolvedPattern, "/")
  topicSegments = .QueueRecordCodec~split(concreteTopic, "/")
  topicIndex = 1
  do patternIndex = 1 to patternSegments~items
    segment = patternSegments[patternIndex]
    if segment = "#" then return .true
    if topicIndex > topicSegments~items then return .false
    if segment \= "+" & segment \= topicSegments[topicIndex] then return .false
    topicIndex = topicIndex + 1
  end
  return topicIndex > topicSegments~items

::method trimSlashes class private
  use strict arg text
  do while text~length > 0
    if text~substr(1, 1) \= "/" then leave
    text = text~substr(2)
  end
  do while text~length > 0
    if text~substr(text~length, 1) \= "/" then leave
    text = text~substr(1, text~length - 1)
  end
  return text

::class QueueTopicDefinition public
::attribute topicId get
::attribute name get
::attribute topicString get
::attribute lifecycle get
::attribute securityDomain get
::attribute owner get
::attribute createdAt get

::method init
  expose topicId name topicString lifecycle securityDomain owner createdAt accessPolicy topicAuthority
  use strict arg topicId, name, topicString, lifecycle, securityDomain, owner, authorityCandidate, createdAt = ""
  topicId = topicId~string
  name = name~string
  topicString = topicString~string
  lifecycle = lifecycle~string~translate
  securityDomain = securityDomain~string
  owner = owner~string
  if createdAt = "" then createdAt = .QueueClock~timestamp
  createdAt = createdAt~string
  accessPolicy = .QueueAccessPolicy~new(owner)
  topicAuthority = authorityCandidate

::method allowsInternal
  expose accessPolicy topicAuthority
  use strict arg principal, action, authorityCandidate
  if authorityCandidate \== topicAuthority then return .false
  return accessPolicy~allows(principal, action)

::method allowInternal
  expose accessPolicy topicAuthority
  use strict arg principal, action, authorityCandidate
  if authorityCandidate \== topicAuthority then return .false
  return accessPolicy~allow(principal, action)

::method revokeInternal
  expose accessPolicy topicAuthority
  use strict arg principal, action, authorityCandidate
  if authorityCandidate \== topicAuthority then return .false
  return accessPolicy~revoke(principal, action)

::method grantRowsInternal
  expose accessPolicy topicAuthority
  use strict arg authorityCandidate
  if authorityCandidate \== topicAuthority then return .array~new
  return accessPolicy~grantRows

::class QueueTopicSubscription public
::attribute subscriptionId get
::attribute name get
::attribute topicName get
::attribute pattern get
::attribute resolvedPattern get
::attribute queueName get
::attribute lifecycle get
::attribute owner get
::attribute allowCrossDomain get
::attribute deliverRetained get
::attribute createdAt get

::method init
  expose subscriptionId name topicName pattern resolvedPattern queueName lifecycle owner allowCrossDomain deliverRetained createdAt
  use strict arg subscriptionId, name, topicName, pattern, resolvedPattern, queueName, lifecycle, owner, allowCrossDomain = .false, deliverRetained = .true, createdAt = ""
  subscriptionId = subscriptionId~string
  name = name~string
  topicName = topicName~string
  pattern = pattern~string
  resolvedPattern = resolvedPattern~string
  queueName = queueName~string
  lifecycle = lifecycle~string~translate
  owner = owner~string
  allowCrossDomain = allowCrossDomain
  deliverRetained = deliverRetained
  if createdAt = "" then createdAt = .QueueClock~timestamp
  createdAt = createdAt~string

::method matches
  expose resolvedPattern
  use strict arg concreteTopic
  return .QueueTopicPattern~matches(resolvedPattern, concreteTopic)

::class QueueRetainedPublication public
::attribute publicationId get
::attribute topicName get
::attribute topicString get
::attribute payload get
::attribute headers get
::attribute priority get
::attribute persistent get
::attribute securityDomain get
::attribute correlationId get
::attribute replyTo get
::attribute expiryTick get
::attribute retainedAt get

::method init
  expose publicationId topicName topicString payload headers priority persistent securityDomain correlationId replyTo expiryTick retainedAt
  use strict arg publicationId, topicName, topicString, payload, headers, priority, persistent, securityDomain, correlationId, replyTo, expiryTick = 0, retainedAt = ""
  publicationId = publicationId~string
  topicName = topicName~string
  topicString = topicString~string
  payload = payload
  headers = headers
  priority = priority
  persistent = persistent
  securityDomain = securityDomain~string
  correlationId = correlationId~string
  replyTo = replyTo~string
  expiryTick = expiryTick
  if retainedAt = "" then retainedAt = .QueueClock~timestamp
  retainedAt = retainedAt~string

::method payloadClass
  expose payload
  if payload == .nil then return "NIL"
  return payload~class~id

::method isExpired
  expose expiryTick
  use strict arg timeSource
  return timeSource~isExpired(expiryTick)

::class QueueTopicPublishReceipt public
::attribute publicationId get
::attribute topicName get
::attribute topicString get
::attribute matchedCount get
::attribute deliveredCount get
::attribute retained get
::attribute remoteManagerCount get

::method init
  expose publicationId topicName topicString matchedCount deliveredCount retained remoteManagerCount
  use strict arg publicationId, topicName, topicString, matchedCount, deliveredCount, retained, remoteManagerCount = 0
  publicationId = publicationId~string
  topicName = topicName~string
  topicString = topicString~string
  matchedCount = matchedCount
  deliveredCount = deliveredCount
  retained = retained
  remoteManagerCount = remoteManagerCount

::class QueueTopicFabric subclass AlchemyObject public
::attribute queueManager get
::attribute brokerPrincipal get
::attribute recoveryWarnings get

::method init
  expose queueManager brokerPrincipal topics topicOrder subscriptions subscriptionOrder retained traffic authority topicIdGenerator subscriptionIdGenerator publicationIdGenerator eventIdGenerator recoveryWarnings recovering publicationSinks
  use strict arg queueManager, brokerPrincipal = ""
  queueManager = queueManager
  if brokerPrincipal = "" then brokerPrincipal = queueManager~adminPrincipal
  brokerPrincipal = brokerPrincipal~string
  topics = .table~new
  topicOrder = .array~new
  subscriptions = .table~new
  subscriptionOrder = .array~new
  retained = .table~new
  traffic = .array~new
  authority = .QueueTopicAuthority~new
  topicIdGenerator = .QueueIdGenerator~new("topic")
  subscriptionIdGenerator = .QueueIdGenerator~new("sub")
  publicationIdGenerator = .QueueIdGenerator~new("pub")
  eventIdGenerator = .QueueIdGenerator~new("tevt")
  recoveryWarnings = .array~new
  recovering = .false
  publicationSinks = .array~new

  limitations = .array~of("Topic publication fans out through local queue-manager UOW only", "A permanent subscription does not upgrade non-persistent publications")
  meta = .QueueFabricAlchemyMetadata~standard("Hierarchical topic routing, retained state and local atomic fan-out", "queue.topic.fabric/0.9-dev3", limitations)
  self~initAlchemy(meta)
  self~registerStateVariable("brokerPrincipal", "INTERNAL", "topic broker principal")
  self~registerStateVariable("recoveryWarnings", "INTERNAL", "topic recovery warning evidence")
  self~registerMethodContract("PUBLISH", "Publish one object payload through local topic fan-out", .array~of("TOPIC", "SUBTOPIC", "PAYLOAD", "PRINCIPAL"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("SUBSCRIBE", "Create one queue-backed topic subscription", .array~of("TOPIC", "NAME", "PATTERN", "QUEUE", "PRINCIPAL"), "QUEUEOPERATIONRESULT", .false)
  self~describeMethodPolicy("PUBLISH", "FALSE", "CUSTOMER", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("SUBSCRIBE", "FALSE", "CUSTOMER", "SENSITIVE", "MUTATE", "NONE")
  self~recordRelationship("QUEUE_MANAGER", queueManager, "queue-backed delivery and local UOW authority", "INTERNAL")

  do event over queueManager~traffic
    if event~eventType~startsWith("TOPIC_") then traffic~append(event)
  end
  if queueManager~durableStore \== .nil then self~recover
  registerResult = queueManager~registerQueueReferenceGuard(self, queueManager~adminPrincipal)
  if \registerResult~ok then raise syntax 88.900 array("Unable to register topic queue-reference guard: " || registerResult~code || ":" || registerResult~detail)

::method registerPublicationSink
  expose publicationSinks queueManager
  use strict arg sink, principal = ""
  if principal = "" then principal = queueManager~adminPrincipal
  if principal~string \= queueManager~adminPrincipal then return .QueueOperationResult~failure("ACCESS_DENIED", "topic publication sink administration")
  if sink == .nil then return .QueueOperationResult~failure("INVALID_PUBLICATION_SINK")
  if \sink~hasMethod("REMOTEINTERESTCOUNT") | \sink~hasMethod("STAGEPUBLICATION") then return .QueueOperationResult~failure("INVALID_PUBLICATION_SINK")
  guard on
  do existingSink over publicationSinks
    if existingSink == sink then do
      guard off
      return .QueueOperationResult~success(sink, "already registered")
    end
  end
  publicationSinks~append(sink)
  guard off
  return .QueueOperationResult~success(sink, "registered")

::method unregisterPublicationSink
  expose publicationSinks queueManager
  use strict arg sink, principal = ""
  if principal = "" then principal = queueManager~adminPrincipal
  if principal~string \= queueManager~adminPrincipal then return .QueueOperationResult~failure("ACCESS_DENIED", "topic publication sink administration")
  kept = .array~new
  removed = .false
  guard on
  do existingSink over publicationSinks
    if existingSink == sink then removed = .true
    else kept~append(existingSink)
  end
  publicationSinks = kept
  guard off
  return .QueueOperationResult~success(removed)

::method publicationSinks
  expose publicationSinks
  copied = .array~new
  guard on
  do sink over publicationSinks
    copied~append(sink)
  end
  guard off
  return copied

::method canDeleteQueue
  expose subscriptionOrder
  use strict arg queueName
  guard on
  do subscriptionObject over subscriptionOrder
    if subscriptionObject~queueName = queueName~string then do
      guard off
      return .QueueOperationResult~failure("TOPIC_SUBSCRIPTION_QUEUE_REFERENCED", subscriptionObject~name)
    end
  end
  guard off
  return .QueueOperationResult~success(.true)

::method topic
  expose topics
  use strict arg topicName
  return topics[topicName~string~translate]

::method topics
  expose topicOrder
  copied = .array~new
  do topicObject over topicOrder
    copied~append(topicObject)
  end
  return copied

::method subscription
  expose subscriptions
  use strict arg subscriptionName
  return subscriptions[subscriptionName~string~translate]

::method subscriptions
  expose subscriptionOrder
  copied = .array~new
  do subscriptionObject over subscriptionOrder
    copied~append(subscriptionObject)
  end
  return copied

::method retainedPublications
  expose retained
  ignore = self~sweepRetained
  copied = .array~new
  supplier = retained~supplier
  do while supplier~available
    copied~append(supplier~item)
    supplier~next
  end
  return copied

::method traffic
  expose traffic
  copied = .array~new
  do event over traffic
    copied~append(event)
  end
  return copied

::method defineTopic
  expose queueManager topics topicOrder authority topicIdGenerator recovering
  use strict arg topicName, topicString, lifecycle = "TEMPORARY", securityDomain = "DEFAULT", principal = ""
  if principal = "" then principal = queueManager~adminPrincipal
  topicName = topicName~string~strip
  if topicName = "" then return .QueueOperationResult~failure("INVALID_TOPIC_NAME")
  lifecycle = lifecycle~string~translate
  if lifecycle \= .QueueLifecycle~TEMPORARY & lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("INVALID_LIFECYCLE", lifecycle)
  rootCheck = .QueueTopicPattern~canonicalRoot(topicString)
  if \rootCheck~ok then return rootCheck
  if lifecycle = .QueueLifecycle~PERMANENT & queueManager~durableStore == .nil then return .QueueOperationResult~failure("PERSISTENCE_UNAVAILABLE", "Permanent topics require a durable store")
  key = topicName~translate
  guard on
  if topics~hasIndex(key) then do
    guard off
    return .QueueOperationResult~failure("TOPIC_EXISTS", topicName)
  end
  topicObject = .QueueTopicDefinition~new(topicIdGenerator~next, topicName, rootCheck~value, lifecycle, securityDomain, principal, authority)
  topics[key] = topicObject
  topicOrder~append(topicObject)
  if queueManager~durableStore \== .nil & lifecycle = .QueueLifecycle~PERMANENT & \recovering then ignore = queueManager~durableStore~appendJournal("TOPICCREATE", .array~of(topicObject~topicId, topicObject~name, topicObject~topicString, topicObject~lifecycle, topicObject~securityDomain, topicObject~owner, topicObject~createdAt))
  ignore = self~recordTrafficLocked("TOPIC_CREATE", topicObject~name, "", principal, topicObject~topicString, topicObject~topicString, "", .true)
  guard off
  return .QueueOperationResult~success(topicObject, "topic created")

::method deleteTopic
  expose topics topicOrder subscriptions subscriptionOrder retained queueManager
  use strict arg topicName, principal = ""
  topicObject = self~topic(topicName)
  if topicObject == .nil then return .QueueOperationResult~failure("TOPIC_NOT_FOUND", topicName)
  if \self~authorised(topicObject, principal, .QueueTopicAccess~MANAGE) then return .QueueOperationResult~failure("ACCESS_DENIED", topicName)
  guard on
  do subscriptionObject over subscriptionOrder
    if subscriptionObject~topicName = topicObject~name then do
      guard off
      return .QueueOperationResult~failure("TOPIC_HAS_SUBSCRIPTIONS", subscriptionObject~name)
    end
  end
  topics~remove(topicObject~name~translate)
  keptTopics = .array~new
  do existingTopic over topicOrder
    if existingTopic~name \= topicObject~name then keptTopics~append(existingTopic)
  end
  topicOrder = keptTopics
  removeKeys = .array~new
  supplier = retained~supplier
  do while supplier~available
    publication = supplier~item
    if publication~topicName = topicObject~name then removeKeys~append(supplier~index)
    supplier~next
  end
  do key over removeKeys
    retained~remove(key)
  end
  if queueManager~durableStore \== .nil & topicObject~lifecycle = .QueueLifecycle~PERMANENT then ignore = queueManager~durableStore~appendJournal("TOPICDELETE", .array~of(topicObject~name))
  ignore = self~recordTrafficLocked("TOPIC_DELETE", topicObject~name, "", principal, topicObject~topicString, topicObject~topicString, "", .true)
  guard off
  return .QueueOperationResult~success(.true)

::method grantTopicAccess
  expose authority queueManager
  use strict arg topicName, grantee, action, principal = ""
  topicObject = self~topic(topicName)
  if topicObject == .nil then return .QueueOperationResult~failure("TOPIC_NOT_FOUND", topicName)
  if \self~authorised(topicObject, principal, .QueueTopicAccess~MANAGE) then return .QueueOperationResult~failure("ACCESS_DENIED", topicName)
  action = action~string~translate
  if \self~validAccess(action) then return .QueueOperationResult~failure("INVALID_TOPIC_ACCESS", action)
  guard on
  ignore = topicObject~allowInternal(grantee, action, authority)
  if queueManager~durableStore \== .nil & topicObject~lifecycle = .QueueLifecycle~PERMANENT then ignore = queueManager~durableStore~appendJournal("TOPICALLOW", .array~of(topicObject~name, grantee, action))
  ignore = self~recordTrafficLocked("TOPIC_ACL_ALLOW", topicObject~name, "", principal, grantee || ":" || action, topicObject~topicString, "", .true)
  guard off
  return .QueueOperationResult~success(.true)

::method revokeTopicAccess
  expose authority queueManager
  use strict arg topicName, grantee, action, principal = ""
  topicObject = self~topic(topicName)
  if topicObject == .nil then return .QueueOperationResult~failure("TOPIC_NOT_FOUND", topicName)
  if \self~authorised(topicObject, principal, .QueueTopicAccess~MANAGE) then return .QueueOperationResult~failure("ACCESS_DENIED", topicName)
  action = action~string~translate
  if \self~validAccess(action) then return .QueueOperationResult~failure("INVALID_TOPIC_ACCESS", action)
  guard on
  ignore = topicObject~revokeInternal(grantee, action, authority)
  if queueManager~durableStore \== .nil & topicObject~lifecycle = .QueueLifecycle~PERMANENT then ignore = queueManager~durableStore~appendJournal("TOPICREVOKE", .array~of(topicObject~name, grantee, action))
  ignore = self~recordTrafficLocked("TOPIC_ACL_REVOKE", topicObject~name, "", principal, grantee || ":" || action, topicObject~topicString, "", .true)
  guard off
  return .QueueOperationResult~success(.true)

::method subscribe
  expose queueManager subscriptions subscriptionOrder authority subscriptionIdGenerator
  use strict arg subscriptionName, topicName, pattern, queueName, lifecycle = "TEMPORARY", principal = "", options = .nil
  topicObject = self~topic(topicName)
  if topicObject == .nil then return .QueueOperationResult~failure("TOPIC_NOT_FOUND", topicName)
  if principal = "" then principal = queueManager~adminPrincipal
  if \self~authorised(topicObject, principal, .QueueTopicAccess~SUBSCRIBE) then return .QueueOperationResult~failure("ACCESS_DENIED", topicName)
  subscriptionName = subscriptionName~string~strip
  if subscriptionName = "" then return .QueueOperationResult~failure("INVALID_SUBSCRIPTION_NAME")
  lifecycle = lifecycle~string~translate
  if lifecycle \= .QueueLifecycle~TEMPORARY & lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("INVALID_LIFECYCLE", lifecycle)
  patternCheck = .QueueTopicPattern~canonicalPattern(pattern)
  if \patternCheck~ok then return patternCheck
  q = queueManager~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \queueManager~accessAllowed(q~name, principal, .QueueAccess~MANAGE) then return .QueueOperationResult~failure("QUEUE_MANAGE_REQUIRED", q~name)
  if options == .nil then options = .table~new
  allowCrossDomain = self~truth(self~option(options, "allowCrossDomain", .false))
  deliverRetained = self~truth(self~option(options, "deliverRetained", .true))
  if q~securityDomain \= topicObject~securityDomain then do
    if \allowCrossDomain then return .QueueOperationResult~failure("TOPIC_SECURITY_DOMAIN_DENIED", topicObject~securityDomain || " -> " || q~securityDomain)
    if \self~isAdmin(principal) then return .QueueOperationResult~failure("CROSS_DOMAIN_SUBSCRIPTION_REQUIRES_ADMIN")
  end
  if lifecycle = .QueueLifecycle~PERMANENT then do
    if queueManager~durableStore == .nil then return .QueueOperationResult~failure("PERSISTENCE_UNAVAILABLE", "Permanent subscriptions require a durable store")
    if topicObject~lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("PERMANENT_SUBSCRIPTION_REQUIRES_PERMANENT_TOPIC", topicObject~name)
    if q~lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("PERMANENT_SUBSCRIPTION_REQUIRES_PERMANENT_QUEUE", q~name)
  end
  key = subscriptionName~translate
  guard on
  if subscriptions~hasIndex(key) then do
    guard off
    return .QueueOperationResult~failure("SUBSCRIPTION_EXISTS", subscriptionName)
  end
  resolvedPattern = .QueueTopicPattern~resolvePattern(topicObject~topicString, patternCheck~value)
  subscriptionObject = .QueueTopicSubscription~new(subscriptionIdGenerator~next, subscriptionName, topicObject~name, patternCheck~value, resolvedPattern, q~name, lifecycle, principal, allowCrossDomain, deliverRetained)
  guard off
  if deliverRetained then do
    replayResult = self~deliverRetainedTo(subscriptionObject)
    if \replayResult~ok then return replayResult
  end
  guard on
  if subscriptions~hasIndex(key) then do
    guard off
    return .QueueOperationResult~failure("SUBSCRIPTION_EXISTS", subscriptionName)
  end
  subscriptions[key] = subscriptionObject
  subscriptionOrder~append(subscriptionObject)
  if queueManager~durableStore \== .nil & lifecycle = .QueueLifecycle~PERMANENT then ignore = queueManager~durableStore~appendJournal("SUBCREATE", .array~of(subscriptionObject~subscriptionId, subscriptionObject~name, subscriptionObject~topicName, subscriptionObject~pattern, subscriptionObject~resolvedPattern, subscriptionObject~queueName, subscriptionObject~lifecycle, subscriptionObject~owner, subscriptionObject~allowCrossDomain, subscriptionObject~deliverRetained, subscriptionObject~createdAt))
  ignore = self~recordTrafficLocked("TOPIC_SUBSCRIBE", topicObject~name, subscriptionObject~subscriptionId, principal, subscriptionObject~pattern, topicObject~topicString, q~name, .true)
  guard off
  ignore = self~notifySubscriptionChange(topicObject~name)
  return .QueueOperationResult~success(subscriptionObject, "subscription created")

::method unsubscribe
  expose subscriptions subscriptionOrder queueManager
  use strict arg subscriptionName, principal = ""
  subscriptionObject = self~subscription(subscriptionName)
  if subscriptionObject == .nil then return .QueueOperationResult~failure("SUBSCRIPTION_NOT_FOUND", subscriptionName)
  topicObject = self~topic(subscriptionObject~topicName)
  if topicObject == .nil then return .QueueOperationResult~failure("TOPIC_NOT_FOUND", subscriptionObject~topicName)
  if principal \= subscriptionObject~owner & \self~authorised(topicObject, principal, .QueueTopicAccess~MANAGE) then return .QueueOperationResult~failure("ACCESS_DENIED", subscriptionName)
  guard on
  subscriptions~remove(subscriptionObject~name~translate)
  keptSubscriptions = .array~new
  do existingSubscription over subscriptionOrder
    if existingSubscription~name \= subscriptionObject~name then keptSubscriptions~append(existingSubscription)
  end
  subscriptionOrder = keptSubscriptions
  if queueManager~durableStore \== .nil & subscriptionObject~lifecycle = .QueueLifecycle~PERMANENT then ignore = queueManager~durableStore~appendJournal("SUBDELETE", .array~of(subscriptionObject~name))
  ignore = self~recordTrafficLocked("TOPIC_UNSUBSCRIBE", topicObject~name, subscriptionObject~subscriptionId, principal, subscriptionObject~pattern, topicObject~topicString, subscriptionObject~queueName, .true)
  guard off
  ignore = self~notifySubscriptionChange(topicObject~name)
  return .QueueOperationResult~success(.true)

::method publish
  expose queueManager brokerPrincipal subscriptionOrder publicationIdGenerator retained
  use strict arg topicName, payload, options = .nil, principal = ""
  topicObject = self~topic(topicName)
  if topicObject == .nil then return .QueueOperationResult~failure("TOPIC_NOT_FOUND", topicName)
  if principal = "" then principal = queueManager~adminPrincipal
  if \self~authorised(topicObject, principal, .QueueTopicAccess~PUBLISH) then return .QueueOperationResult~failure("ACCESS_DENIED", topicName)
  if options == .nil then options = .table~new
  subtopicCheck = .QueueTopicPattern~canonicalSubtopic(self~option(options, "subtopic", ""))
  if \subtopicCheck~ok then return subtopicCheck
  concreteTopic = .QueueTopicPattern~resolve(topicObject~topicString, subtopicCheck~value)
  headers = self~option(options, "headers", .table~new)
  if headers == .nil then headers = .table~new
  if \headers~hasMethod("COPY") then return .QueueOperationResult~failure("INVALID_HEADERS", "headers must support COPY")
  priority = self~option(options, "priority", 0)
  persistent = self~truth(self~option(options, "persistent", .false))
  correlationId = self~option(options, "correlationId", "")
  replyTo = self~option(options, "replyTo", "")
  expirySeconds = self~option(options, "expirySeconds", 0)
  retainPublication = self~truth(self~option(options, "retain", .false))
  securityDomain = self~option(options, "securityDomain", topicObject~securityDomain)
  if securityDomain \= topicObject~securityDomain then return .QueueOperationResult~failure("SECURITY_DOMAIN_MISMATCH", securityDomain || " != " || topicObject~securityDomain)
  if \datatype(expirySeconds, "N") then return .QueueOperationResult~failure("INVALID_EXPIRY", expirySeconds)
  if expirySeconds < 0 then return .QueueOperationResult~failure("INVALID_EXPIRY", expirySeconds)
  if retainPublication & topicObject~lifecycle = .QueueLifecycle~PERMANENT then do
    if brokerPrincipal \= queueManager~adminPrincipal then return .QueueOperationResult~failure("BROKER_ADMIN_REQUIRED_FOR_DURABLE_RETAIN", brokerPrincipal)
    if \queueManager~payloadCodec~canEncode(payload) then return .QueueOperationResult~failure("RETAIN_PAYLOAD_NOT_PERSISTABLE")
    if \queueManager~payloadCodec~canEncode(headers) then return .QueueOperationResult~failure("RETAIN_HEADERS_NOT_PERSISTABLE")
  end

  brokerJournalRows = self~option(options, "brokerJournalRows", .nil)
  if brokerJournalRows \== .nil then do
    if principal~string \= brokerPrincipal then return .QueueOperationResult~failure("BROKER_JOURNAL_ROWS_REQUIRE_BROKER", principal)
    if \brokerJournalRows~hasMethod("ITEMS") then return .QueueOperationResult~failure("INVALID_BROKER_JOURNAL_ROWS")
  end

  publicationId = self~option(options, "publicationId", "")
  if publicationId = "" then publicationId = publicationIdGenerator~next
  else do
    if principal~string \= brokerPrincipal then return .QueueOperationResult~failure("BROKER_PUBLICATION_ID_REQUIRES_BROKER", principal)
    publicationId = publicationId~string
  end

  matches = .array~new
  guard on
  do subscriptionObject over subscriptionOrder
    if subscriptionObject~topicName \= topicObject~name then iterate
    if subscriptionObject~matches(concreteTopic) then matches~append(subscriptionObject)
  end
  guard off

  normalizedOptions = .table~new
  normalizedOptions["headers"] = headers~copy
  normalizedOptions["priority"] = priority
  normalizedOptions["persistent"] = persistent
  normalizedOptions["securityDomain"] = securityDomain
  normalizedOptions["correlationId"] = correlationId
  normalizedOptions["replyTo"] = replyTo
  normalizedOptions["expirySeconds"] = expirySeconds
  normalizedOptions["retain"] = retainPublication
  normalizedOptions["distributionOrigin"] = self~option(options, "distributionOrigin", "")
  normalizedOptions["distributionPath"] = self~option(options, "distributionPath", .nil)
  normalizedOptions["distributionSuppress"] = self~truth(self~option(options, "distributionSuppress", .false))

  remoteCount = 0
  sinkRows = .array~new
  do sink over self~publicationSinks
    countResult = sink~remoteInterestCount(topicObject, concreteTopic, normalizedOptions)
    if \countResult~ok then return .QueueOperationResult~failure("TOPIC_REMOTE_INTEREST_FAILED", countResult~code || ":" || countResult~detail)
    sinkRows~append(.array~of(sink, countResult~value))
    remoteCount += countResult~value
  end

  needsUow = matches~items > 0 | remoteCount > 0 | brokerJournalRows \== .nil
  pendingRetained = .nil
  commitRows = .nil
  if needsUow then do
    uowResult = queueManager~beginUnitOfWork(brokerPrincipal)
    if \uowResult~ok then return .QueueOperationResult~failure("TOPIC_UOW_BEGIN_FAILED", uowResult~detail)
    uow = uowResult~value
    do subscriptionObject over matches
      q = queueManager~queue(subscriptionObject~queueName)
      if q == .nil then do
        ignore = queueManager~rollbackUnitOfWork(uow)
        return .QueueOperationResult~failure("SUBSCRIPTION_QUEUE_NOT_FOUND", subscriptionObject~queueName)
      end
      deliveryHeaders = headers~copy
      deliveryHeaders["oqf.topic.name"] = topicObject~name
      deliveryHeaders["oqf.topic.string"] = concreteTopic
      deliveryHeaders["oqf.topic.subscription"] = subscriptionObject~name
      deliveryHeaders["oqf.topic.publication_id"] = publicationId
      deliveryHeaders["oqf.topic.retained"] = 0
      putOptions = .table~new
      putOptions["headers"] = deliveryHeaders
      putOptions["priority"] = priority
      putOptions["persistent"] = persistent
      putOptions["securityDomain"] = q~securityDomain
      putOptions["routingKey"] = concreteTopic
      putOptions["correlationId"] = correlationId
      putOptions["replyTo"] = replyTo
      putOptions["expirySeconds"] = expirySeconds
      stageResult = queueManager~uowPut(uow, q~name, payload, putOptions)
      if \stageResult~ok then do
        ignore = queueManager~rollbackUnitOfWork(uow)
        return .QueueOperationResult~failure("TOPIC_STAGE_FAILED", subscriptionObject~name || ":" || stageResult~code || ":" || stageResult~detail)
      end
    end

    do sinkRow over sinkRows
      if sinkRow[2] <= 0 then iterate
      stageRemoteResult = sinkRow[1]~stagePublication(topicObject, publicationId, concreteTopic, payload, normalizedOptions, uow)
      if \stageRemoteResult~ok then do
        ignore = queueManager~rollbackUnitOfWork(uow)
        return .QueueOperationResult~failure("TOPIC_REMOTE_STAGE_FAILED", stageRemoteResult~code || ":" || stageRemoteResult~detail)
      end
    end

    commitRows = .array~new
    if brokerJournalRows \== .nil then do extraRow over brokerJournalRows
      commitRows~append(extraRow)
    end
    if retainPublication then do
      if expirySeconds = 0 then expiryTick = 0
      else expiryTick = queueManager~timeSource~addSeconds(queueManager~timeSource~nowTick, expirySeconds)
      retainedHeaders = headers~copy
      pendingRetained = .QueueRetainedPublication~new(publicationId, topicObject~name, concreteTopic, payload, retainedHeaders, priority, persistent, topicObject~securityDomain, correlationId, replyTo, expiryTick)
      if topicObject~lifecycle = .QueueLifecycle~PERMANENT then do
        encodedHeaders = queueManager~payloadCodec~encode(pendingRetained~headers)
        encodedPayload = queueManager~payloadCodec~encode(pendingRetained~payload)
        commitRows~append(.array~of("TOPICRETAIN", pendingRetained~topicName, pendingRetained~topicString, pendingRetained~publicationId, encodedHeaders, encodedPayload, pendingRetained~priority, pendingRetained~persistent, pendingRetained~securityDomain, pendingRetained~correlationId, pendingRetained~replyTo, pendingRetained~expiryTick, pendingRetained~retainedAt))
      end
    end
    if commitRows~items = 0 then commitRows = .nil
    commitResult = queueManager~commitUnitOfWork(uow, commitRows)
    if \commitResult~ok then do
      ignore = queueManager~rollbackUnitOfWork(uow)
      ignore = self~recordTraffic("TOPIC_PUBLISH_FAILED", topicObject~name, publicationId, principal, commitResult~code || ":" || commitResult~detail, concreteTopic, "", .false)
      return .QueueOperationResult~failure("TOPIC_DELIVERY_FAILED", commitResult~code || ":" || commitResult~detail)
    end
  end

  retainedFlag = .false
  if retainPublication then do
    if pendingRetained == .nil then do
      if expirySeconds = 0 then expiryTick = 0
      else expiryTick = queueManager~timeSource~addSeconds(queueManager~timeSource~nowTick, expirySeconds)
      retainedHeaders = headers~copy
      pendingRetained = .QueueRetainedPublication~new(publicationId, topicObject~name, concreteTopic, payload, retainedHeaders, priority, persistent, topicObject~securityDomain, correlationId, replyTo, expiryTick)
      if topicObject~lifecycle = .QueueLifecycle~PERMANENT then do
        encodedHeaders = queueManager~payloadCodec~encode(pendingRetained~headers)
        encodedPayload = queueManager~payloadCodec~encode(pendingRetained~payload)
        retainUowResult = queueManager~beginUnitOfWork(brokerPrincipal)
        if \retainUowResult~ok then return .QueueOperationResult~failure("TOPIC_UOW_BEGIN_FAILED", retainUowResult~detail)
        retainRows = .array~new
        retainRows~append(.array~of("TOPICRETAIN", pendingRetained~topicName, pendingRetained~topicString, pendingRetained~publicationId, encodedHeaders, encodedPayload, pendingRetained~priority, pendingRetained~persistent, pendingRetained~securityDomain, pendingRetained~correlationId, pendingRetained~replyTo, pendingRetained~expiryTick, pendingRetained~retainedAt))
        retainCommit = queueManager~commitUnitOfWork(retainUowResult~value, retainRows)
        if \retainCommit~ok then do
          ignore = queueManager~rollbackUnitOfWork(retainUowResult~value)
          return .QueueOperationResult~failure("RETAIN_JOURNAL_FAILED", retainCommit~code || ":" || retainCommit~detail)
        end
      end
    end
    retainResult = self~storeRetained(pendingRetained, topicObject, .true)
    if \retainResult~ok then return retainResult
    retainedFlag = .true
  end
  ignore = self~recordTraffic("TOPIC_PUBLISH", topicObject~name, publicationId, principal, "matched=" || matches~items || ";remoteManagers=" || remoteCount || ";retained=" || retainedFlag, concreteTopic, "", .true)
  receipt = .QueueTopicPublishReceipt~new(publicationId, topicObject~name, concreteTopic, matches~items, matches~items, retainedFlag, remoteCount)
  return .QueueOperationResult~success(receipt, "delivered=" || matches~items || ";remoteManagers=" || remoteCount)

::method clearRetained
  expose retained queueManager
  use strict arg topicName, subtopic = "", principal = ""
  topicObject = self~topic(topicName)
  if topicObject == .nil then return .QueueOperationResult~failure("TOPIC_NOT_FOUND", topicName)
  if \self~authorised(topicObject, principal, .QueueTopicAccess~MANAGE) then return .QueueOperationResult~failure("ACCESS_DENIED", topicName)
  subtopicCheck = .QueueTopicPattern~canonicalSubtopic(subtopic)
  if \subtopicCheck~ok then return subtopicCheck
  concreteTopic = .QueueTopicPattern~resolve(topicObject~topicString, subtopicCheck~value)
  key = self~retainedKey(topicObject~name, concreteTopic)
  guard on
  existed = retained~hasIndex(key)
  retained~remove(key)
  if existed & queueManager~durableStore \== .nil & topicObject~lifecycle = .QueueLifecycle~PERMANENT then ignore = queueManager~durableStore~appendJournal("TOPICCLEAR", .array~of(topicObject~name, concreteTopic))
  if existed then ignore = self~recordTrafficLocked("TOPIC_RETAIN_CLEAR", topicObject~name, "", principal, concreteTopic, concreteTopic, "", .true)
  guard off
  return .QueueOperationResult~success(existed)

::method sweepRetained
  expose retained queueManager
  removeKeys = .array~new
  guard on
  supplier = retained~supplier
  do while supplier~available
    publication = supplier~item
    if publication~isExpired(queueManager~timeSource) then removeKeys~append(supplier~index)
    supplier~next
  end
  do key over removeKeys
    publication = retained[key]
    retained~remove(key)
    topicObject = self~topic(publication~topicName)
    if topicObject \== .nil then do
      if queueManager~durableStore \== .nil & topicObject~lifecycle = .QueueLifecycle~PERMANENT then ignore = queueManager~durableStore~appendJournal("TOPICCLEAR", .array~of(topicObject~name, publication~topicString))
      ignore = self~recordTrafficLocked("TOPIC_RETAIN_EXPIRE", topicObject~name, publication~publicationId, queueManager~adminPrincipal, publication~topicString, publication~topicString, "", .true)
    end
  end
  guard off
  return removeKeys~items

::method authorisedTopics
  expose topicOrder
  use strict arg principal
  rows = .array~new
  do topicObject over topicOrder
    if self~authorised(topicObject, principal, .QueueTopicAccess~BROWSE) then rows~append(topicObject)
  end
  return rows

::method authorisedSubscriptions
  expose subscriptionOrder
  use strict arg principal
  rows = .array~new
  do subscriptionObject over subscriptionOrder
    topicObject = self~topic(subscriptionObject~topicName)
    if topicObject \== .nil then do
      if self~authorised(topicObject, principal, .QueueTopicAccess~BROWSE) then rows~append(subscriptionObject)
    end
  end
  return rows

::method authorisedRetained
  expose retained
  use strict arg principal
  ignore = self~sweepRetained
  rows = .array~new
  supplier = retained~supplier
  do while supplier~available
    publication = supplier~item
    topicObject = self~topic(publication~topicName)
    if topicObject \== .nil then do
      if self~authorised(topicObject, principal, .QueueTopicAccess~BROWSE) then rows~append(publication)
    end
    supplier~next
  end
  return rows

::method authorisedTraffic
  expose traffic
  use strict arg principal
  rows = .array~new
  do event over traffic
    topicObject = self~topic(event~queueName)
    if topicObject == .nil then do
      if self~isAdmin(principal) then rows~append(event)
    end
    else if self~authorised(topicObject, principal, .QueueTopicAccess~BROWSE) then rows~append(event)
  end
  return rows

::method authorisedGrantRows
  expose topicOrder authority
  use strict arg principal
  rows = .array~new
  do topicObject over topicOrder
    if \self~authorised(topicObject, principal, .QueueTopicAccess~MANAGE) then iterate
    do grantRow over topicObject~grantRowsInternal(authority)
      rows~append(.array~of(topicObject~name, grantRow[1], grantRow[2]))
    end
  end
  return rows

::method deliverRetainedTo private
  expose retained queueManager brokerPrincipal
  use strict arg subscriptionObject
  ignore = self~sweepRetained
  matching = .array~new
  supplier = retained~supplier
  do while supplier~available
    publication = supplier~item
    if publication~topicName = subscriptionObject~topicName then do
      if subscriptionObject~matches(publication~topicString) then matching~append(publication)
    end
    supplier~next
  end
  if matching~items = 0 then return .QueueOperationResult~success(0)
  q = queueManager~queue(subscriptionObject~queueName)
  if q == .nil then return .QueueOperationResult~failure("SUBSCRIPTION_QUEUE_NOT_FOUND", subscriptionObject~queueName)
  uowResult = queueManager~beginUnitOfWork(brokerPrincipal)
  if \uowResult~ok then return .QueueOperationResult~failure("TOPIC_UOW_BEGIN_FAILED", uowResult~detail)
  uow = uowResult~value
  do publication over matching
    deliveryHeaders = publication~headers~copy
    deliveryHeaders["oqf.topic.name"] = publication~topicName
    deliveryHeaders["oqf.topic.string"] = publication~topicString
    deliveryHeaders["oqf.topic.subscription"] = subscriptionObject~name
    deliveryHeaders["oqf.topic.publication_id"] = publication~publicationId
    deliveryHeaders["oqf.topic.retained"] = 1
    putOptions = .table~new
    putOptions["headers"] = deliveryHeaders
    putOptions["priority"] = publication~priority
    putOptions["persistent"] = publication~persistent
    putOptions["securityDomain"] = q~securityDomain
    putOptions["routingKey"] = publication~topicString
    putOptions["correlationId"] = publication~correlationId
    putOptions["replyTo"] = publication~replyTo
    if publication~expiryTick = 0 then putOptions["expirySeconds"] = 0
    else do
      remainingSeconds = queueManager~timeSource~secondsUntil(publication~expiryTick)
      if remainingSeconds <= 0 then iterate
      putOptions["expirySeconds"] = remainingSeconds
    end
    stageResult = queueManager~uowPut(uow, q~name, publication~payload, putOptions)
    if \stageResult~ok then do
      ignore = queueManager~rollbackUnitOfWork(uow)
      return .QueueOperationResult~failure("RETAINED_REPLAY_STAGE_FAILED", stageResult~code || ":" || stageResult~detail)
    end
  end
  commitResult = queueManager~commitUnitOfWork(uow)
  if \commitResult~ok then do
    ignore = queueManager~rollbackUnitOfWork(uow)
    return .QueueOperationResult~failure("RETAINED_REPLAY_FAILED", commitResult~code || ":" || commitResult~detail)
  end
  return .QueueOperationResult~success(matching~items, "retained replayed")

::method storeRetained private
  expose retained queueManager
  use strict arg publication, topicObject, journalAlreadyWritten = .false
  key = self~retainedKey(publication~topicName, publication~topicString)
  guard on
  if \journalAlreadyWritten & queueManager~durableStore \== .nil & topicObject~lifecycle = .QueueLifecycle~PERMANENT then do
    signal on syntax name retainJournalFailure
    encodedHeaders = queueManager~payloadCodec~encode(publication~headers)
    encodedPayload = queueManager~payloadCodec~encode(publication~payload)
    ignore = queueManager~durableStore~appendJournal("TOPICRETAIN", .array~of(publication~topicName, publication~topicString, publication~publicationId, encodedHeaders, encodedPayload, publication~priority, publication~persistent, publication~securityDomain, publication~correlationId, publication~replyTo, publication~expiryTick, publication~retainedAt))
    signal off syntax
  end
  retained[key] = publication
  ignore = self~recordTrafficLocked("TOPIC_RETAIN", publication~topicName, publication~publicationId, queueManager~adminPrincipal, publication~topicString, publication~topicString, "", .true)
  guard off
  return .QueueOperationResult~success(publication)
retainJournalFailure:
  signal off syntax
  detailText = condition("D")
  guard off
  return .QueueOperationResult~failure("RETAIN_JOURNAL_FAILED", detailText)

::method recover private
  expose queueManager recovering recoveryWarnings
  recovering = .true
  rows = queueManager~durableStore~readJournal
  do row over rows
    if row~items = 0 then iterate
    if row[1] = "UOWCOMMIT" then do
      if row~items < 2 then iterate
      nestedRows = queueManager~payloadCodec~decode(row[2])
      do nestedRow over nestedRows
        if nestedRow~items = 0 then iterate
        if \nestedRow[1]~startsWith("TOPIC") & \nestedRow[1]~startsWith("SUB") then iterate
        signal on syntax name topicRecoveryFailure
        ignore = self~applyRecoveryRecord(nestedRow)
        signal off syntax
      end
      iterate
    end
    if \row[1]~startsWith("TOPIC") & \row[1]~startsWith("SUB") then iterate
    signal on syntax name topicRecoveryFailure
    ignore = self~applyRecoveryRecord(row)
    signal off syntax
  end
  recovering = .false
  return .true
topicRecoveryFailure:
  signal off syntax
  recoveryWarnings~append(condition("D"))
  recovering = .false
  return .false

::method applyRecoveryRecord private
  expose topics topicOrder subscriptions subscriptionOrder retained authority queueManager recoveryWarnings
  use strict arg row
  tag = row[1]
  select
    when tag = "TOPICCREATE" then do
      if row~items < 8 then return .false
      key = row[3]~translate
      if \topics~hasIndex(key) then do
        topicObject = .QueueTopicDefinition~new(row[2], row[3], row[4], row[5], row[6], row[7], authority, row[8])
        topics[key] = topicObject
        topicOrder~append(topicObject)
      end
    end
    when tag = "TOPICDELETE" then do
      if row~items < 2 then return .false
      topicObject = self~topic(row[2])
      if topicObject \== .nil then do
        topics~remove(topicObject~name~translate)
        keptTopics = .array~new
        do existingTopic over topicOrder
          if existingTopic~name \= topicObject~name then keptTopics~append(existingTopic)
        end
        topicOrder = keptTopics
        keptSubscriptions = .array~new
        do subscriptionObject over subscriptionOrder
          if subscriptionObject~topicName = topicObject~name then subscriptions~remove(subscriptionObject~name~translate)
          else keptSubscriptions~append(subscriptionObject)
        end
        subscriptionOrder = keptSubscriptions
        removeKeys = .array~new
        supplier = retained~supplier
        do while supplier~available
          publication = supplier~item
          if publication~topicName = topicObject~name then removeKeys~append(supplier~index)
          supplier~next
        end
        do key over removeKeys
          retained~remove(key)
        end
      end
    end
    when tag = "TOPICALLOW" then do
      if row~items < 4 then return .false
      topicObject = self~topic(row[2])
      if topicObject \== .nil then ignore = topicObject~allowInternal(row[3], row[4], authority)
    end
    when tag = "TOPICREVOKE" then do
      if row~items < 4 then return .false
      topicObject = self~topic(row[2])
      if topicObject \== .nil then ignore = topicObject~revokeInternal(row[3], row[4], authority)
    end
    when tag = "SUBCREATE" then do
      if row~items < 12 then return .false
      topicObject = self~topic(row[4])
      q = queueManager~queue(row[7])
      if topicObject == .nil | q == .nil then do
        recoveryWarnings~append("SUBSCRIPTION_RECOVERY_REFERENCE_MISSING|" || row[3])
        return .false
      end
      key = row[3]~translate
      if \subscriptions~hasIndex(key) then do
        subscriptionObject = .QueueTopicSubscription~new(row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9], self~truth(row[10]), self~truth(row[11]), row[12])
        subscriptions[key] = subscriptionObject
        subscriptionOrder~append(subscriptionObject)
      end
    end
    when tag = "SUBDELETE" then do
      if row~items < 2 then return .false
      subscriptionObject = self~subscription(row[2])
      if subscriptionObject \== .nil then do
        subscriptions~remove(subscriptionObject~name~translate)
        keptSubscriptions = .array~new
        do existingSubscription over subscriptionOrder
          if existingSubscription~name \= subscriptionObject~name then keptSubscriptions~append(existingSubscription)
        end
        subscriptionOrder = keptSubscriptions
      end
    end
    when tag = "TOPICRETAIN" then do
      if row~items < 13 then return .false
      topicObject = self~topic(row[2])
      if topicObject == .nil then return .false
      headers = queueManager~payloadCodec~decode(row[5])
      payload = queueManager~payloadCodec~decode(row[6])
      publication = .QueueRetainedPublication~new(row[4], row[2], row[3], payload, headers, row[7], self~truth(row[8]), row[9], row[10], row[11], row[12], row[13])
      if \publication~isExpired(queueManager~timeSource) then retained[self~retainedKey(publication~topicName, publication~topicString)] = publication
    end
    when tag = "TOPICCLEAR" then do
      if row~items < 3 then return .false
      retained~remove(self~retainedKey(row[2], row[3]))
    end
    otherwise nop
  end
  return .true

::method notifySubscriptionChange private
  use strict arg topicName
  do sink over self~publicationSinks
    if sink~hasMethod("TOPICSUBSCRIPTIONSCHANGED") then ignore = sink~topicSubscriptionsChanged(topicName)
  end
  return .true

::method authorised private
  expose authority queueManager
  use strict arg topicObject, principal, action
  if self~isAdmin(principal) then return .true
  return topicObject~allowsInternal(principal, action, authority)

::method isAdmin private
  expose queueManager
  use strict arg principal
  return principal~string = queueManager~adminPrincipal

::method validAccess private
  use strict arg action
  return action = .QueueTopicAccess~PUBLISH | action = .QueueTopicAccess~SUBSCRIBE | action = .QueueTopicAccess~BROWSE | action = .QueueTopicAccess~MANAGE

::method retainedKey private
  use strict arg topicName, topicString
  return topicName~string~translate || "|" || topicString~string

::method option private
  use strict arg options, key, defaultValue
  value = options[key]
  if value == .nil then return defaultValue
  return value

::method truth private
  use strict arg value
  if value == .true then return .true
  text = value~string~strip~translate
  return text = "1" | text = "TRUE" | text = "YES" | text = "ON"

::method recordTraffic
  use strict arg eventType, topicName, publicationId, principal, detail, source, destination, success
  guard on
  event = self~recordTrafficLocked(eventType, topicName, publicationId, principal, detail, source, destination, success)
  guard off
  return event

::method recordTrafficLocked private
  expose traffic queueManager eventIdGenerator
  use strict arg eventType, topicName, publicationId, principal, detail, source, destination, success
  event = .QueueTrafficEvent~new(eventIdGenerator~next, eventType, topicName, publicationId, principal, detail, source, destination, success)
  traffic~append(event)
  if queueManager~durableStore \== .nil then ignore = queueManager~durableStore~appendTraffic(event)
  return event

::requires "ObjectQueueFabric.cls"
::requires "AlchemyObject.cls"
