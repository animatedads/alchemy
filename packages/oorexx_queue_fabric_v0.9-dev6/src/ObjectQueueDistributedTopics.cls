/*
 * ObjectQueueFabric v0.8 distributed topic layer.
 *
 * Distributed topics exchange aggregated subscription interest between queue
 * managers.  A publisher records one local distribution work package per
 * interested remote manager in the same UOW as local fan-out.  Existing
 * remote queues/channels provide store-and-forward transport; the receiving
 * manager performs local fan-out through QueueTopicFabric.
 */

::class QueueDistributedTopicBuild public
::constant API "queue.distributed-topic/0.8"

::class QueueDistributedTopicSupport public
::method registerTypes class
  use strict arg payloadCodec
  if payloadCodec == .nil | \payloadCodec~hasMethod("TYPEREGISTRY") then return .false
  registry = payloadCodec~typeRegistry
  ignore = registry~register(.QueueTopicInterestSnapshot~PERSISTENT_TYPE, .QueueTopicInterestSnapshotFactory~new)
  ignore = registry~register(.QueueTopicDistributionWork~PERSISTENT_TYPE, .QueueTopicDistributionWorkFactory~new)
  ignore = registry~register(.QueueRemoteTopicPublication~PERSISTENT_TYPE, .QueueRemoteTopicPublicationFactory~new)
  return .true

::class QueueTopicPeerDefinition public
::attribute remoteManager get
::attribute localTopicName get
::attribute remoteTopicName get
::attribute controlRemoteQueue get
::attribute publicationRemoteQueue get
::attribute lifecycle get
::attribute allowCrossDomain get
::attribute owner get
::attribute createdAt get

::method init
  expose remoteManager localTopicName remoteTopicName controlRemoteQueue publicationRemoteQueue lifecycle allowCrossDomain owner createdAt
  use strict arg remoteManager, localTopicName, remoteTopicName, controlRemoteQueue, publicationRemoteQueue, lifecycle, allowCrossDomain, owner, createdAt = ""
  remoteManager = remoteManager~string
  localTopicName = localTopicName~string
  remoteTopicName = remoteTopicName~string
  controlRemoteQueue = controlRemoteQueue~string
  publicationRemoteQueue = publicationRemoteQueue~string
  lifecycle = lifecycle~string~translate
  allowCrossDomain = allowCrossDomain
  owner = owner~string
  if createdAt = "" then createdAt = .QueueClock~timestamp
  createdAt = createdAt~string

::method key
  expose remoteManager localTopicName
  return remoteManager~translate || "|" || localTopicName~translate

::class QueueTopicRemoteInterest public
::attribute remoteManager get
::attribute localTopicName get
::attribute remoteTopicName get
::attribute revision get
::attribute advertisements get
::attribute updatedAt get

::method init
  expose remoteManager localTopicName remoteTopicName revision advertisements updatedAt
  use strict arg remoteManager, localTopicName, remoteTopicName, revision, advertisements, updatedAt = ""
  remoteManager = remoteManager~string
  localTopicName = localTopicName~string
  remoteTopicName = remoteTopicName~string
  revision = revision
  advertisements = advertisements
  if updatedAt = "" then updatedAt = .QueueClock~timestamp
  updatedAt = updatedAt~string

::method matches
  expose advertisements
  use strict arg topicRoot, concreteTopic
  do advertisement over advertisements
    pattern = advertisement[1]
    resolvedPattern = .QueueTopicPattern~resolvePattern(topicRoot, pattern)
    if .QueueTopicPattern~matches(resolvedPattern, concreteTopic) then return .true
  end
  return .false

::class QueueTopicInterestSnapshot public
::constant PERSISTENT_TYPE "queue.fabric.topic-interest/1"
::attribute snapshotId get
::attribute sourceManager get
::attribute destinationManager get
::attribute sourceTopicName get
::attribute destinationTopicName get
::attribute revision get
::attribute advertisements get
::attribute createdAt get

::method init
  expose snapshotId sourceManager destinationManager sourceTopicName destinationTopicName revision advertisements createdAt
  use strict arg snapshotId = "", sourceManager = "", destinationManager = "", sourceTopicName = "", destinationTopicName = "", revision = 0, advertisements = .nil, createdAt = ""
  snapshotId = snapshotId~string
  sourceManager = sourceManager~string
  destinationManager = destinationManager~string
  sourceTopicName = sourceTopicName~string
  destinationTopicName = destinationTopicName~string
  revision = revision
  if advertisements == .nil then advertisements = .array~new
  advertisements = advertisements
  if createdAt = "" then createdAt = .QueueClock~timestamp
  createdAt = createdAt~string

::method queuePersistentType
  return .QueueTopicInterestSnapshot~PERSISTENT_TYPE

::method queuePersistentState
  expose snapshotId sourceManager destinationManager sourceTopicName destinationTopicName revision advertisements createdAt
  state = .table~new
  state["snapshotId"] = snapshotId
  state["sourceManager"] = sourceManager
  state["destinationManager"] = destinationManager
  state["sourceTopicName"] = sourceTopicName
  state["destinationTopicName"] = destinationTopicName
  state["revision"] = revision~string
  state["advertisements"] = advertisements
  state["createdAt"] = createdAt
  return state

::method queueRestoreState
  expose snapshotId sourceManager destinationManager sourceTopicName destinationTopicName revision advertisements createdAt
  use strict arg state
  snapshotId = state["snapshotId"]~string
  sourceManager = state["sourceManager"]~string
  destinationManager = state["destinationManager"]~string
  sourceTopicName = state["sourceTopicName"]~string
  destinationTopicName = state["destinationTopicName"]~string
  revision = state["revision"]
  advertisements = state["advertisements"]
  createdAt = state["createdAt"]~string
  return self

::class QueueTopicInterestSnapshotFactory public
::method newBlank
  return .QueueTopicInterestSnapshot~new

::class QueueTopicDistributionWork public
::constant PERSISTENT_TYPE "queue.fabric.topic-distribution-work/1"
::attribute originManager get
::attribute publicationId get
::attribute targetManager get
::attribute localTopicName get
::attribute remoteTopicName get
::attribute subtopic get
::attribute payload get
::attribute headers get
::attribute priority get
::attribute persistent get
::attribute securityDomain get
::attribute correlationId get
::attribute replyTo get
::attribute retain get
::attribute path get
::attribute createdAt get

::method init
  expose originManager publicationId targetManager localTopicName remoteTopicName subtopic payload headers priority persistent securityDomain correlationId replyTo retain path createdAt
  use strict arg originManager = "", publicationId = "", targetManager = "", localTopicName = "", remoteTopicName = "", subtopic = "", payload = .nil, headers = .nil, priority = 0, persistent = .false, securityDomain = "DEFAULT", correlationId = "", replyTo = "", retain = .false, path = .nil, createdAt = ""
  originManager = originManager~string
  publicationId = publicationId~string
  targetManager = targetManager~string
  localTopicName = localTopicName~string
  remoteTopicName = remoteTopicName~string
  subtopic = subtopic~string
  payload = payload
  if headers == .nil then headers = .table~new
  headers = headers
  priority = priority
  persistent = persistent
  securityDomain = securityDomain~string
  correlationId = correlationId~string
  replyTo = replyTo~string
  retain = retain
  if path == .nil then path = .array~new
  path = path
  if createdAt = "" then createdAt = .QueueClock~timestamp
  createdAt = createdAt~string

::method queuePersistentType
  return .QueueTopicDistributionWork~PERSISTENT_TYPE

::method queuePersistentState
  expose originManager publicationId targetManager localTopicName remoteTopicName subtopic payload headers priority persistent securityDomain correlationId replyTo retain path createdAt
  state = .table~new
  state["originManager"] = originManager
  state["publicationId"] = publicationId
  state["targetManager"] = targetManager
  state["localTopicName"] = localTopicName
  state["remoteTopicName"] = remoteTopicName
  state["subtopic"] = subtopic
  state["payload"] = payload
  state["headers"] = headers
  state["priority"] = priority~string
  if persistent then state["persistent"] = "1"; else state["persistent"] = "0"
  state["securityDomain"] = securityDomain
  state["correlationId"] = correlationId
  state["replyTo"] = replyTo
  if retain then state["retain"] = "1"; else state["retain"] = "0"
  state["path"] = path
  state["createdAt"] = createdAt
  return state

::method queueRestoreState
  expose originManager publicationId targetManager localTopicName remoteTopicName subtopic payload headers priority persistent securityDomain correlationId replyTo retain path createdAt
  use strict arg state
  originManager = state["originManager"]~string
  publicationId = state["publicationId"]~string
  targetManager = state["targetManager"]~string
  localTopicName = state["localTopicName"]~string
  remoteTopicName = state["remoteTopicName"]~string
  subtopic = state["subtopic"]~string
  payload = state["payload"]
  headers = state["headers"]
  priority = state["priority"]
  persistent = self~truth(state["persistent"])
  securityDomain = state["securityDomain"]~string
  correlationId = state["correlationId"]~string
  replyTo = state["replyTo"]~string
  retain = self~truth(state["retain"])
  path = state["path"]
  createdAt = state["createdAt"]~string
  return self

::method truth private
  use strict arg value
  text = value~string~strip~translate
  return text = "1" | text = "TRUE" | text = "YES" | text = "ON"

::class QueueTopicDistributionWorkFactory public
::method newBlank
  return .QueueTopicDistributionWork~new

::class QueueRemoteTopicPublication public
::constant PERSISTENT_TYPE "queue.fabric.remote-topic-publication/1"
::attribute originManager get
::attribute publicationId get
::attribute sourceManager get
::attribute destinationManager get
::attribute sourceTopicName get
::attribute destinationTopicName get
::attribute subtopic get
::attribute payload get
::attribute headers get
::attribute priority get
::attribute persistent get
::attribute securityDomain get
::attribute correlationId get
::attribute replyTo get
::attribute expirySeconds get
::attribute retain get
::attribute path get
::attribute createdAt get

::method init
  expose originManager publicationId sourceManager destinationManager sourceTopicName destinationTopicName subtopic payload headers priority persistent securityDomain correlationId replyTo expirySeconds retain path createdAt
  use strict arg originManager = "", publicationId = "", sourceManager = "", destinationManager = "", sourceTopicName = "", destinationTopicName = "", subtopic = "", payload = .nil, headers = .nil, priority = 0, persistent = .false, securityDomain = "DEFAULT", correlationId = "", replyTo = "", expirySeconds = 0, retain = .false, path = .nil, createdAt = ""
  originManager = originManager~string
  publicationId = publicationId~string
  sourceManager = sourceManager~string
  destinationManager = destinationManager~string
  sourceTopicName = sourceTopicName~string
  destinationTopicName = destinationTopicName~string
  subtopic = subtopic~string
  payload = payload
  if headers == .nil then headers = .table~new
  headers = headers
  priority = priority
  persistent = persistent
  securityDomain = securityDomain~string
  correlationId = correlationId~string
  replyTo = replyTo~string
  expirySeconds = expirySeconds
  retain = retain
  if path == .nil then path = .array~new
  path = path
  if createdAt = "" then createdAt = .QueueClock~timestamp
  createdAt = createdAt~string

::method queuePersistentType
  return .QueueRemoteTopicPublication~PERSISTENT_TYPE

::method queuePersistentState
  expose originManager publicationId sourceManager destinationManager sourceTopicName destinationTopicName subtopic payload headers priority persistent securityDomain correlationId replyTo expirySeconds retain path createdAt
  state = .table~new
  state["originManager"] = originManager
  state["publicationId"] = publicationId
  state["sourceManager"] = sourceManager
  state["destinationManager"] = destinationManager
  state["sourceTopicName"] = sourceTopicName
  state["destinationTopicName"] = destinationTopicName
  state["subtopic"] = subtopic
  state["payload"] = payload
  state["headers"] = headers
  state["priority"] = priority~string
  if persistent then state["persistent"] = "1"; else state["persistent"] = "0"
  state["securityDomain"] = securityDomain
  state["correlationId"] = correlationId
  state["replyTo"] = replyTo
  state["expirySeconds"] = expirySeconds~string
  if retain then state["retain"] = "1"; else state["retain"] = "0"
  state["path"] = path
  state["createdAt"] = createdAt
  return state

::method queueRestoreState
  expose originManager publicationId sourceManager destinationManager sourceTopicName destinationTopicName subtopic payload headers priority persistent securityDomain correlationId replyTo expirySeconds retain path createdAt
  use strict arg state
  originManager = state["originManager"]~string
  publicationId = state["publicationId"]~string
  sourceManager = state["sourceManager"]~string
  destinationManager = state["destinationManager"]~string
  sourceTopicName = state["sourceTopicName"]~string
  destinationTopicName = state["destinationTopicName"]~string
  subtopic = state["subtopic"]~string
  payload = state["payload"]
  headers = state["headers"]
  priority = state["priority"]
  persistent = self~truth(state["persistent"])
  securityDomain = state["securityDomain"]~string
  correlationId = state["correlationId"]~string
  replyTo = state["replyTo"]~string
  expirySeconds = state["expirySeconds"]
  retain = self~truth(state["retain"])
  path = state["path"]
  createdAt = state["createdAt"]~string
  return self

::method truth private
  use strict arg value
  text = value~string~strip~translate
  return text = "1" | text = "TRUE" | text = "YES" | text = "ON"

::class QueueRemoteTopicPublicationFactory public
::method newBlank
  return .QueueRemoteTopicPublication~new

::class QueueDistributedTopicFabric subclass AlchemyObject public
::attribute managerName get
::attribute queueManager get
::attribute topicFabric get
::attribute channelFabric get
::attribute controlIngressQueue get
::attribute publicationIngressQueue get
::attribute distributionQueue get
::attribute brokerPrincipal get

::method init
  expose managerName queueManager topicFabric channelFabric controlIngressQueue publicationIngressQueue distributionQueue brokerPrincipal peers remoteInterests txRevisions dirty receipts traffic idGenerator recovering
  use strict arg managerName, queueManager, topicFabric, channelFabric, controlIngressQueue, publicationIngressQueue, distributionQueue, brokerPrincipal = ""
  managerName = managerName~string~strip
  if managerName = "" then raise syntax 88.900 array("Distributed topic fabric requires manager name")
  if queueManager == .nil | topicFabric == .nil | channelFabric == .nil then raise syntax 88.900 array("Distributed topic fabric requires queue/topic/channel collaborators")
  queueManager = queueManager
  topicFabric = topicFabric
  channelFabric = channelFabric
  controlIngressQueue = controlIngressQueue~string
  publicationIngressQueue = publicationIngressQueue~string
  distributionQueue = distributionQueue~string
  if brokerPrincipal = "" then brokerPrincipal = queueManager~adminPrincipal
  brokerPrincipal = brokerPrincipal~string
  if brokerPrincipal \= queueManager~adminPrincipal then raise syntax 88.900 array("Distributed topic broker currently requires queue-manager admin authority")
  if queueManager~queue(controlIngressQueue) == .nil then raise syntax 88.900 array("Distributed topic control ingress queue not found")
  if queueManager~queue(publicationIngressQueue) == .nil then raise syntax 88.900 array("Distributed topic publication ingress queue not found")
  if queueManager~queue(distributionQueue) == .nil then raise syntax 88.900 array("Distributed topic distribution queue not found")
  peers = .table~new
  remoteInterests = .table~new
  txRevisions = .table~new
  dirty = .table~new
  receipts = .table~new
  traffic = .array~new
  idGenerator = .QueueIdGenerator~new("dt-" || managerName)
  recovering = .false

  limitations = .array~of("No distributed XA; source and receiver brokers commit independent local UOWs", "Manager-path metadata suppresses loops but does not claim global publication ordering")
  meta = .QueueFabricAlchemyMetadata~standard("Distributed topic interest aggregation and durable remote publication", "queue.distributed.topic.fabric/0.9-dev3", limitations)
  self~initAlchemy(meta)
  self~registerStateVariable("managerName", "PUBLIC", "local distributed-topic manager identity")
  self~registerStateVariable("controlIngressQueue", "INTERNAL", "control advertisement ingress queue")
  self~registerStateVariable("publicationIngressQueue", "INTERNAL", "remote publication ingress queue")
  self~registerStateVariable("distributionQueue", "INTERNAL", "durable outbound distribution queue")
  self~registerStateVariable("brokerPrincipal", "INTERNAL", "distributed topic broker principal")
  self~registerMethodContract("DEFINEPEER", "Define one explicit remote topic peer", .array~of("REMOTE_MANAGER", "LOCAL_TOPIC", "REMOTE_TOPIC", "CONTROL_REMOTE_QUEUE", "PUBLICATION_REMOTE_QUEUE"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("PUMPDISTRIBUTION", "Move bounded distributed-topic work through channel fabric", .array~of("MAX_MESSAGES"), "QUEUEOPERATIONRESULT", .false)
  self~describeMethodPolicy("DEFINEPEER", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("PUMPDISTRIBUTION", "FALSE", "CUSTOMER", "SENSITIVE", "MUTATE", "NONE")
  self~recordRelationship("QUEUE_MANAGER", queueManager, "durable local queue/UOW authority", "INTERNAL")
  self~recordRelationship("TOPIC_FABRIC", topicFabric, "local subscription and retained-state authority", "INTERNAL")
  self~recordRelationship("CHANNEL_FABRIC", channelFabric, "store-and-forward remote transport authority", "INTERNAL")

  ignore = .QueueDistributedTopicSupport~registerTypes(queueManager~payloadCodec)
  transportObject = channelFabric~transport
  if transportObject \== .nil then do
    if transportObject~hasMethod("PAYLOADCODEC") then ignore = .QueueDistributedTopicSupport~registerTypes(transportObject~payloadCodec)
  end
  if queueManager~durableStore \== .nil then self~recover
  sinkResult = topicFabric~registerPublicationSink(self, queueManager~adminPrincipal)
  if \sinkResult~ok then raise syntax 88.900 array("Unable to register distributed topic publication sink: " || sinkResult~code)
  guardResult = queueManager~registerQueueReferenceGuard(self, queueManager~adminPrincipal)
  if \guardResult~ok then raise syntax 88.900 array("Unable to register distributed topic queue-reference guard: " || guardResult~code)
  do peerObject over self~peers
    dirty[peerObject~key] = .true
  end

::method canDeleteQueue
  expose controlIngressQueue publicationIngressQueue distributionQueue
  use strict arg queueName
  queueName = queueName~string
  if queueName = controlIngressQueue then return .QueueOperationResult~failure("DISTRIBUTED_TOPIC_QUEUE_REFERENCED", "control ingress")
  if queueName = publicationIngressQueue then return .QueueOperationResult~failure("DISTRIBUTED_TOPIC_QUEUE_REFERENCED", "publication ingress")
  if queueName = distributionQueue then return .QueueOperationResult~failure("DISTRIBUTED_TOPIC_QUEUE_REFERENCED", "distribution queue")
  return .QueueOperationResult~success(.true)

::method peer
  expose peers
  use strict arg remoteManager, localTopicName
  return peers[self~peerKey(remoteManager, localTopicName)]

::method peers
  expose peers
  rows = .array~new
  supplier = peers~supplier
  do while supplier~available
    rows~append(supplier~item)
    supplier~next
  end
  return rows

::method remoteInterests
  expose remoteInterests
  rows = .array~new
  supplier = remoteInterests~supplier
  do while supplier~available
    rows~append(supplier~item)
    supplier~next
  end
  return rows

::method receipts
  expose receipts
  rows = .array~new
  supplier = receipts~supplier
  do while supplier~available
    rows~append(supplier~item)
    supplier~next
  end
  return rows

::method traffic
  expose traffic
  rows = .array~new
  do event over traffic
    rows~append(event)
  end
  return rows

::method authorisedPeers
  expose queueManager
  use strict arg principal
  if principal~string \= queueManager~adminPrincipal then return .array~new
  return self~peers

::method authorisedRemoteInterests
  expose queueManager
  use strict arg principal
  if principal~string \= queueManager~adminPrincipal then return .array~new
  return self~remoteInterests

::method authorisedReceipts
  expose queueManager
  use strict arg principal
  if principal~string \= queueManager~adminPrincipal then return .array~new
  return self~receipts

::method authorisedTraffic
  expose queueManager
  use strict arg principal
  if principal~string \= queueManager~adminPrincipal then return .array~new
  return self~traffic

::method definePeer
  expose peers queueManager topicFabric channelFabric dirty managerName controlIngressQueue publicationIngressQueue distributionQueue
  use strict arg remoteManager, localTopicName, remoteTopicName, controlRemoteQueue, publicationRemoteQueue, lifecycle = "TEMPORARY", allowCrossDomain = .false, principal = ""
  if principal = "" then principal = queueManager~adminPrincipal
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "distributed topic peer administration")
  remoteManager = remoteManager~string~strip
  if remoteManager = "" | remoteManager~translate = self~managerName~translate then return .QueueOperationResult~failure("INVALID_REMOTE_MANAGER", remoteManager)
  localTopic = topicFabric~topic(localTopicName)
  if localTopic == .nil then return .QueueOperationResult~failure("TOPIC_NOT_FOUND", localTopicName)
  lifecycle = lifecycle~string~translate
  if lifecycle \= .QueueLifecycle~TEMPORARY & lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("INVALID_LIFECYCLE", lifecycle)
  controlDefinition = channelFabric~remoteQueue(controlRemoteQueue)
  publicationDefinition = channelFabric~remoteQueue(publicationRemoteQueue)
  if controlDefinition == .nil then return .QueueOperationResult~failure("REMOTE_QUEUE_NOT_FOUND", controlRemoteQueue)
  if publicationDefinition == .nil then return .QueueOperationResult~failure("REMOTE_QUEUE_NOT_FOUND", publicationRemoteQueue)
  if controlDefinition~remoteManager \= remoteManager | publicationDefinition~remoteManager \= remoteManager then return .QueueOperationResult~failure("REMOTE_MANAGER_MISMATCH", remoteManager)
  if allowCrossDomain & \self~isAdmin(principal) then return .QueueOperationResult~failure("CROSS_DOMAIN_PEER_REQUIRES_ADMIN")
  if lifecycle = .QueueLifecycle~PERMANENT then do
    if queueManager~durableStore == .nil then return .QueueOperationResult~failure("PERSISTENCE_UNAVAILABLE")
    if localTopic~lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("PERMANENT_PEER_REQUIRES_PERMANENT_TOPIC", localTopic~name)
    if queueManager~queue(controlIngressQueue)~lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("PERMANENT_PEER_REQUIRES_PERMANENT_CONTROL_INGRESS")
    if queueManager~queue(publicationIngressQueue)~lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("PERMANENT_PEER_REQUIRES_PERMANENT_PUBLICATION_INGRESS")
    if queueManager~queue(distributionQueue)~lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("PERMANENT_PEER_REQUIRES_PERMANENT_DISTRIBUTION_QUEUE")
  end
  key = self~peerKey(remoteManager, localTopic~name)
  guard on
  if peers~hasIndex(key) then do
    guard off
    return .QueueOperationResult~failure("DISTRIBUTED_TOPIC_PEER_EXISTS", key)
  end
  peerObject = .QueueTopicPeerDefinition~new(remoteManager, localTopic~name, remoteTopicName, controlDefinition~aliasName, publicationDefinition~aliasName, lifecycle, self~truth(allowCrossDomain), principal)
  peers[key] = peerObject
  dirty[key] = .true
  if lifecycle = .QueueLifecycle~PERMANENT then ignore = queueManager~durableStore~appendJournal("DTPEER", .array~of(peerObject~remoteManager, peerObject~localTopicName, peerObject~remoteTopicName, peerObject~controlRemoteQueue, peerObject~publicationRemoteQueue, peerObject~lifecycle, peerObject~allowCrossDomain, peerObject~owner, peerObject~createdAt))
  ignore = self~recordTrafficLocked("DT_PEER_DEFINE", localTopic~name, "", principal, remoteManager || ":" || remoteTopicName, managerName, remoteManager, .true)
  guard off
  return .QueueOperationResult~success(peerObject)

::method deletePeer
  expose peers remoteInterests txRevisions dirty queueManager
  use strict arg remoteManager, localTopicName, principal = ""
  if principal = "" then principal = queueManager~adminPrincipal
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "distributed topic peer administration")
  key = self~peerKey(remoteManager, localTopicName)
  peerObject = peers[key]
  if peerObject == .nil then return .QueueOperationResult~failure("DISTRIBUTED_TOPIC_PEER_NOT_FOUND", key)
  guard on
  peers~remove(key)
  remoteInterests~remove(key)
  txRevisions~remove(key)
  dirty~remove(key)
  if peerObject~lifecycle = .QueueLifecycle~PERMANENT & queueManager~durableStore \== .nil then ignore = queueManager~durableStore~appendJournal("DTPEERDELETE", .array~of(peerObject~remoteManager, peerObject~localTopicName))
  ignore = self~recordTrafficLocked("DT_PEER_DELETE", peerObject~localTopicName, "", principal, peerObject~remoteManager, managerName, peerObject~remoteManager, .true)
  guard off
  return .QueueOperationResult~success(peerObject)

::method topicSubscriptionsChanged
  expose peers dirty
  use strict arg topicName
  do peerObject over self~peers
    if peerObject~localTopicName~translate = topicName~string~translate then dirty[peerObject~key] = .true
  end
  return .true

::method syncPeer
  expose queueManager topicFabric channelFabric txRevisions dirty idGenerator managerName brokerPrincipal
  use strict arg remoteManager, localTopicName, principal = ""
  if principal = "" then principal = queueManager~adminPrincipal
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "distributed topic interest sync")
  peerObject = self~peer(remoteManager, localTopicName)
  if peerObject == .nil then return .QueueOperationResult~failure("DISTRIBUTED_TOPIC_PEER_NOT_FOUND", remoteManager || "|" || localTopicName)
  advertisements = self~localAdvertisements(peerObject~localTopicName, peerObject~remoteManager)
  key = peerObject~key
  revision = txRevisions[key]
  if revision == .nil then revision = 0
  revision += 1
  if peerObject~lifecycle = .QueueLifecycle~PERMANENT & queueManager~durableStore \== .nil then ignore = queueManager~durableStore~appendJournal("DTTXREV", .array~of(peerObject~remoteManager, peerObject~localTopicName, revision))
  txRevisions[key] = revision
  snapshot = .QueueTopicInterestSnapshot~new(idGenerator~next, managerName, peerObject~remoteManager, peerObject~localTopicName, peerObject~remoteTopicName, revision, advertisements)
  options = .table~new
  options["persistent"] = peerObject~lifecycle = .QueueLifecycle~PERMANENT
  controlDefinition = channelFabric~remoteQueue(peerObject~controlRemoteQueue)
  options["securityDomain"] = controlDefinition~securityDomain
  putResult = channelFabric~put(peerObject~controlRemoteQueue, snapshot, options, brokerPrincipal)
  if \putResult~ok then return .QueueOperationResult~failure("INTEREST_SYNC_QUEUE_FAILED", putResult~code || ":" || putResult~detail)
  dirty~remove(key)
  ignore = self~recordTraffic("DT_INTEREST_SYNC", peerObject~localTopicName, snapshot~snapshotId, principal, "revision=" || revision || ";advertisements=" || advertisements~items, managerName, peerObject~remoteManager, .true)
  return .QueueOperationResult~success(snapshot)

::method syncDirtyInterests
  expose dirty queueManager
  use strict arg principal = ""
  if principal = "" then principal = queueManager~adminPrincipal
  synced = 0
  keys = .array~new
  supplier = dirty~supplier
  do while supplier~available
    keys~append(supplier~index)
    supplier~next
  end
  do key over keys
    splitAt = key~pos("|")
    remoteManager = key~substr(1, splitAt - 1)
    localTopicName = key~substr(splitAt + 1)
    syncResult = self~syncPeer(remoteManager, localTopicName, principal)
    if \syncResult~ok then return syncResult
    synced += 1
  end
  return .QueueOperationResult~success(synced)

::method resyncPeer
  expose queueManager
  use strict arg remoteManager, principal = ""
  if principal = "" then principal = queueManager~adminPrincipal
  synced = 0
  do peerObject over self~peers
    if peerObject~remoteManager~translate \= remoteManager~string~translate then iterate
    syncResult = self~syncPeer(peerObject~remoteManager, peerObject~localTopicName, principal)
    if \syncResult~ok then return syncResult
    synced += 1
  end
  return .QueueOperationResult~success(synced)

::method remoteInterestCount
  expose managerName
  use strict arg topicObject, concreteTopic, publicationOptions
  if self~truth(self~option(publicationOptions, "distributionSuppress", .false)) then return .QueueOperationResult~success(0)
  path = self~normalizedPath(self~option(publicationOptions, "distributionPath", .nil))
  count = 0
  do peerObject over self~peers
    if peerObject~localTopicName \= topicObject~name then iterate
    if self~pathContains(path, peerObject~remoteManager) then iterate
    interest = self~remoteInterest(peerObject)
    if interest == .nil then iterate
    if interest~matches(topicObject~topicString, concreteTopic) then count += 1
  end
  return .QueueOperationResult~success(count)

::method stagePublication
  expose queueManager distributionQueue managerName
  use strict arg topicObject, publicationId, concreteTopic, payload, publicationOptions, uow
  path = self~normalizedPath(self~option(publicationOptions, "distributionPath", .nil))
  originManager = self~option(publicationOptions, "distributionOrigin", "")
  if originManager = "" then originManager = managerName
  if \self~pathContains(path, managerName) then path~append(managerName)
  subtopic = self~relativeSubtopic(topicObject~topicString, concreteTopic)
  staged = 0
  do peerObject over self~peers
    if peerObject~localTopicName \= topicObject~name then iterate
    if self~pathContains(path, peerObject~remoteManager) then iterate
    interest = self~remoteInterest(peerObject)
    if interest == .nil then iterate
    if \interest~matches(topicObject~topicString, concreteTopic) then iterate
    work = .QueueTopicDistributionWork~new(originManager, publicationId, peerObject~remoteManager, topicObject~name, peerObject~remoteTopicName, subtopic, payload, self~option(publicationOptions, "headers", .table~new)~copy, self~option(publicationOptions, "priority", 0), self~truth(self~option(publicationOptions, "persistent", .false)), self~option(publicationOptions, "securityDomain", topicObject~securityDomain), self~option(publicationOptions, "correlationId", ""), self~option(publicationOptions, "replyTo", ""), self~truth(self~option(publicationOptions, "retain", .false)), self~copyArray(path))
    putOptions = .table~new
    putOptions["persistent"] = work~persistent
    putOptions["securityDomain"] = queueManager~queue(distributionQueue)~securityDomain
    putOptions["routingKey"] = concreteTopic
    putOptions["expirySeconds"] = self~option(publicationOptions, "expirySeconds", 0)
    stageResult = queueManager~uowPut(uow, distributionQueue, work, putOptions)
    if \stageResult~ok then return .QueueOperationResult~failure("DISTRIBUTION_STAGE_FAILED", peerObject~remoteManager || ":" || stageResult~code || ":" || stageResult~detail)
    staged += 1
  end
  return .QueueOperationResult~success(staged)

::method pumpDistribution
  expose queueManager channelFabric distributionQueue brokerPrincipal managerName
  use strict arg maxMessages = 0, principal = ""
  if principal = "" then principal = queueManager~adminPrincipal
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "distributed topic pump")
  sent = 0
  do forever
    if maxMessages > 0 & sent >= maxMessages then leave
    claimResult = queueManager~claim(distributionQueue, brokerPrincipal)
    if \claimResult~ok then do
      if claimResult~code = "QUEUE_EMPTY" then leave
      return .QueueOperationResult~failure("DISTRIBUTION_CLAIM_FAILED", claimResult~code || ":" || claimResult~detail)
    end
    package = claimResult~value
    work = package~payload
    if work == .nil | \work~hasMethod("QUEUEPERSISTENTTYPE") | work~queuePersistentType \= .QueueTopicDistributionWork~PERSISTENT_TYPE then do
      ignore = queueManager~nack(distributionQueue, package~packageId, package~claimToken, brokerPrincipal, "INVALID_DISTRIBUTION_WORK")
      return .QueueOperationResult~failure("INVALID_DISTRIBUTION_WORK", package~packageId)
    end
    peerObject = self~peer(work~targetManager, work~localTopicName)
    if peerObject == .nil then do
      ignore = queueManager~release(distributionQueue, package~packageId, package~claimToken, brokerPrincipal, "peer unavailable")
      return .QueueOperationResult~failure("DISTRIBUTED_TOPIC_PEER_NOT_FOUND", work~targetManager)
    end
    remainingSeconds = 0
    if package~expiryTick \= 0 then do
      remainingSeconds = queueManager~timeSource~secondsUntil(package~expiryTick)
      if remainingSeconds <= 0 then do
        ignore = queueManager~ack(distributionQueue, package~packageId, package~claimToken, brokerPrincipal)
        iterate
      end
    end
    path = self~copyArray(work~path)
    if \self~pathContains(path, managerName) then path~append(managerName)
    remotePublication = .QueueRemoteTopicPublication~new(work~originManager, work~publicationId, managerName, peerObject~remoteManager, work~localTopicName, work~remoteTopicName, work~subtopic, work~payload, work~headers~copy, work~priority, work~persistent, work~securityDomain, work~correlationId, work~replyTo, remainingSeconds, work~retain, path)
    options = .table~new
    options["persistent"] = work~persistent
    remoteDefinition = channelFabric~remoteQueue(peerObject~publicationRemoteQueue)
    options["securityDomain"] = remoteDefinition~securityDomain
    options["routingKey"] = work~localTopicName || "/" || work~subtopic
    options["correlationId"] = work~correlationId
    options["replyTo"] = work~replyTo
    options["expirySeconds"] = remainingSeconds
    sendResult = channelFabric~put(peerObject~publicationRemoteQueue, remotePublication, options, brokerPrincipal)
    if \sendResult~ok then do
      ignore = queueManager~release(distributionQueue, package~packageId, package~claimToken, brokerPrincipal, "remote staging:" || sendResult~code)
      return .QueueOperationResult~failure("REMOTE_TOPIC_STAGE_FAILED", sendResult~code || ":" || sendResult~detail)
    end
    ackResult = queueManager~ack(distributionQueue, package~packageId, package~claimToken, brokerPrincipal)
    if \ackResult~ok then return .QueueOperationResult~failure("DISTRIBUTION_ACK_FAILED", ackResult~code)
    sent += 1
    ignore = self~recordTraffic("DT_PUBLICATION_STAGED", work~localTopicName, work~publicationId, principal, peerObject~remoteManager, managerName, peerObject~remoteManager, .true)
  end
  return .QueueOperationResult~success(sent)

::method pumpControlIngress
  expose queueManager controlIngressQueue brokerPrincipal
  use strict arg maxMessages = 0, principal = ""
  if principal = "" then principal = queueManager~adminPrincipal
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "distributed topic control pump")
  handled = 0
  do forever
    if maxMessages > 0 & handled >= maxMessages then leave
    claimResult = queueManager~claim(controlIngressQueue, brokerPrincipal)
    if \claimResult~ok then do
      if claimResult~code = "QUEUE_EMPTY" then leave
      return .QueueOperationResult~failure("CONTROL_CLAIM_FAILED", claimResult~code || ":" || claimResult~detail)
    end
    package = claimResult~value
    snapshot = package~payload
    if snapshot == .nil | \snapshot~hasMethod("QUEUEPERSISTENTTYPE") | snapshot~queuePersistentType \= .QueueTopicInterestSnapshot~PERSISTENT_TYPE then do
      ignore = queueManager~nack(controlIngressQueue, package~packageId, package~claimToken, brokerPrincipal, "INVALID_INTEREST_SNAPSHOT")
      return .QueueOperationResult~failure("INVALID_INTEREST_SNAPSHOT", package~packageId)
    end
    applyResult = self~applyInterestSnapshot(snapshot)
    if \applyResult~ok then do
      ignore = queueManager~release(controlIngressQueue, package~packageId, package~claimToken, brokerPrincipal, "interest retry:" || applyResult~code)
      return applyResult
    end
    ackResult = queueManager~ack(controlIngressQueue, package~packageId, package~claimToken, brokerPrincipal)
    if \ackResult~ok then return .QueueOperationResult~failure("CONTROL_ACK_FAILED", ackResult~code)
    handled += 1
  end
  return .QueueOperationResult~success(handled)

::method pumpPublicationIngress
  expose queueManager publicationIngressQueue brokerPrincipal receipts managerName topicFabric
  use strict arg maxMessages = 0, principal = ""
  if principal = "" then principal = queueManager~adminPrincipal
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "distributed topic publication pump")
  handled = 0
  do forever
    if maxMessages > 0 & handled >= maxMessages then leave
    claimResult = queueManager~claim(publicationIngressQueue, brokerPrincipal)
    if \claimResult~ok then do
      if claimResult~code = "QUEUE_EMPTY" then leave
      return .QueueOperationResult~failure("PUBLICATION_CLAIM_FAILED", claimResult~code || ":" || claimResult~detail)
    end
    package = claimResult~value
    remotePublication = package~payload
    if remotePublication == .nil | \remotePublication~hasMethod("QUEUEPERSISTENTTYPE") | remotePublication~queuePersistentType \= .QueueRemoteTopicPublication~PERSISTENT_TYPE then do
      ignore = queueManager~nack(publicationIngressQueue, package~packageId, package~claimToken, brokerPrincipal, "INVALID_REMOTE_TOPIC_PUBLICATION")
      return .QueueOperationResult~failure("INVALID_REMOTE_TOPIC_PUBLICATION", package~packageId)
    end
    validateResult = self~validateRemotePublication(remotePublication)
    if \validateResult~ok then do
      ignore = queueManager~nack(publicationIngressQueue, package~packageId, package~claimToken, brokerPrincipal, validateResult~code)
      return validateResult
    end
    receiptKey = self~receiptKey(remotePublication~originManager, remotePublication~publicationId, remotePublication~destinationTopicName)
    if receipts~hasIndex(receiptKey) then do
      ignore = queueManager~ack(publicationIngressQueue, package~packageId, package~claimToken, brokerPrincipal)
      handled += 1
      iterate
    end
    path = self~copyArray(remotePublication~path)
    if self~pathContains(path, managerName) then do
      ignore = queueManager~ack(publicationIngressQueue, package~packageId, package~claimToken, brokerPrincipal)
      handled += 1
      ignore = self~recordTraffic("DT_LOOP_SUPPRESSED", remotePublication~destinationTopicName, remotePublication~publicationId, principal, remotePublication~originManager, remotePublication~sourceManager, managerName, .true)
      iterate
    end
    path~append(managerName)
    localTopic = topicFabric~topic(remotePublication~destinationTopicName)
    headers = remotePublication~headers~copy
    headers["oqf.remote.origin"] = remotePublication~originManager
    headers["oqf.remote.source_manager"] = remotePublication~sourceManager
    headers["oqf.remote.path"] = self~pathText(path)
    options = .table~new
    options["subtopic"] = remotePublication~subtopic
    options["headers"] = headers
    options["priority"] = remotePublication~priority
    options["persistent"] = remotePublication~persistent
    options["securityDomain"] = localTopic~securityDomain
    options["correlationId"] = remotePublication~correlationId
    options["replyTo"] = remotePublication~replyTo
    options["expirySeconds"] = remotePublication~expirySeconds
    options["retain"] = remotePublication~retain
    options["publicationId"] = remotePublication~publicationId
    options["distributionOrigin"] = remotePublication~originManager
    options["distributionPath"] = path
    receiptRow = .array~of("DTPUBRECEIPT", remotePublication~originManager, remotePublication~publicationId, remotePublication~destinationTopicName, remotePublication~sourceManager, .QueueClock~timestamp)
    options["brokerJournalRows"] = .array~of(receiptRow)
    publishResult = topicFabric~publish(remotePublication~destinationTopicName, remotePublication~payload, options, brokerPrincipal)
    if \publishResult~ok then do
      ignore = queueManager~release(publicationIngressQueue, package~packageId, package~claimToken, brokerPrincipal, "remote topic retry:" || publishResult~code)
      return .QueueOperationResult~failure("REMOTE_TOPIC_PUBLISH_FAILED", publishResult~code || ":" || publishResult~detail)
    end
    receipts[receiptKey] = receiptRow
    ackResult = queueManager~ack(publicationIngressQueue, package~packageId, package~claimToken, brokerPrincipal)
    if \ackResult~ok then return .QueueOperationResult~failure("PUBLICATION_ACK_FAILED", ackResult~code)
    handled += 1
    ignore = self~recordTraffic("DT_PUBLICATION_ACCEPT", remotePublication~destinationTopicName, remotePublication~publicationId, principal, remotePublication~originManager, remotePublication~sourceManager, managerName, .true)
  end
  return .QueueOperationResult~success(handled)

::method applyInterestSnapshot private
  expose managerName remoteInterests queueManager distributionQueue brokerPrincipal topicFabric
  use strict arg snapshot
  if snapshot~destinationManager~translate \= managerName~translate then return .QueueOperationResult~failure("INTEREST_DESTINATION_MANAGER_MISMATCH", snapshot~destinationManager)
  peerObject = self~peer(snapshot~sourceManager, snapshot~destinationTopicName)
  if peerObject == .nil then return .QueueOperationResult~failure("DISTRIBUTED_TOPIC_PEER_NOT_FOUND", snapshot~sourceManager || "|" || snapshot~destinationTopicName)
  if peerObject~remoteTopicName~translate \= snapshot~sourceTopicName~translate then return .QueueOperationResult~failure("INTEREST_TOPIC_MAPPING_MISMATCH", snapshot~sourceTopicName)
  key = peerObject~key
  current = remoteInterests[key]
  if current \== .nil then do
    if snapshot~revision <= current~revision then return .QueueOperationResult~success(current, "stale/duplicate interest snapshot")
  end
  advertisements = self~validatedAdvertisements(snapshot~advertisements, snapshot~sourceManager, snapshot~destinationManager)
  if advertisements == .nil then return .QueueOperationResult~failure("INVALID_REMOTE_INTEREST_PATTERN")
  uowResult = queueManager~beginUnitOfWork(brokerPrincipal)
  if \uowResult~ok then return uowResult
  uow = uowResult~value
  localTopic = topicFabric~topic(peerObject~localTopicName)
  retainedQueued = 0
  do retainedPublication over topicFabric~retainedPublications
    if retainedPublication~topicName \= localTopic~name then iterate
    matched = .false
    do advertisement over advertisements
      pattern = advertisement[1]
      resolvedPattern = .QueueTopicPattern~resolvePattern(localTopic~topicString, pattern)
      if .QueueTopicPattern~matches(resolvedPattern, retainedPublication~topicString) then do
        matched = .true
        leave
      end
    end
    if \matched then iterate
    retainedPath = self~pathFromHeaders(retainedPublication~headers)
    if self~pathContains(retainedPath, peerObject~remoteManager) then iterate
    if \self~pathContains(retainedPath, managerName) then retainedPath~append(managerName)
    retainedOrigin = retainedPublication~headers["oqf.remote.origin"]
    if retainedOrigin == .nil | retainedOrigin = "" then retainedOrigin = managerName
    subtopic = self~relativeSubtopic(localTopic~topicString, retainedPublication~topicString)
    work = .QueueTopicDistributionWork~new(retainedOrigin, retainedPublication~publicationId, peerObject~remoteManager, localTopic~name, peerObject~remoteTopicName, subtopic, retainedPublication~payload, retainedPublication~headers~copy, retainedPublication~priority, retainedPublication~persistent, retainedPublication~securityDomain, retainedPublication~correlationId, retainedPublication~replyTo, .true, retainedPath)
    putOptions = .table~new
    putOptions["persistent"] = retainedPublication~persistent
    putOptions["securityDomain"] = queueManager~queue(distributionQueue)~securityDomain
    if retainedPublication~expiryTick = 0 then putOptions["expirySeconds"] = 0
    else do
      remaining = queueManager~timeSource~secondsUntil(retainedPublication~expiryTick)
      if remaining <= 0 then iterate
      putOptions["expirySeconds"] = remaining
    end
    stageResult = queueManager~uowPut(uow, distributionQueue, work, putOptions)
    if \stageResult~ok then do
      ignore = queueManager~rollbackUnitOfWork(uow)
      return .QueueOperationResult~failure("RETAINED_HANDOFF_STAGE_FAILED", stageResult~code || ":" || stageResult~detail)
    end
    retainedQueued += 1
  end
  encodedAdvertisements = queueManager~payloadCodec~encode(advertisements)
  interestRow = .array~of("DTINTEREST", peerObject~remoteManager, peerObject~localTopicName, peerObject~remoteTopicName, snapshot~revision, encodedAdvertisements, .QueueClock~timestamp)
  commitResult = queueManager~commitUnitOfWork(uow, .array~of(interestRow))
  if \commitResult~ok then do
    ignore = queueManager~rollbackUnitOfWork(uow)
    return .QueueOperationResult~failure("INTEREST_COMMIT_FAILED", commitResult~code || ":" || commitResult~detail)
  end
  interest = .QueueTopicRemoteInterest~new(peerObject~remoteManager, peerObject~localTopicName, peerObject~remoteTopicName, snapshot~revision, advertisements)
  remoteInterests[key] = interest
  ignore = self~markOtherPeersDirty(peerObject~localTopicName, peerObject~remoteManager)
  ignore = self~recordTraffic("DT_INTEREST_APPLY", peerObject~localTopicName, snapshot~snapshotId, brokerPrincipal, "revision=" || snapshot~revision || ";advertisements=" || advertisements~items || ";retained=" || retainedQueued, peerObject~remoteManager, managerName, .true)
  return .QueueOperationResult~success(interest)

::method validateRemotePublication private
  expose managerName topicFabric
  use strict arg remotePublication
  if remotePublication~destinationManager~translate \= managerName~translate then return .QueueOperationResult~failure("TOPIC_DESTINATION_MANAGER_MISMATCH", remotePublication~destinationManager)
  peerObject = self~peer(remotePublication~sourceManager, remotePublication~destinationTopicName)
  if peerObject == .nil then return .QueueOperationResult~failure("DISTRIBUTED_TOPIC_PEER_NOT_FOUND", remotePublication~sourceManager || "|" || remotePublication~destinationTopicName)
  if peerObject~remoteTopicName~translate \= remotePublication~sourceTopicName~translate then return .QueueOperationResult~failure("REMOTE_TOPIC_MAPPING_MISMATCH", remotePublication~sourceTopicName)
  localTopic = topicFabric~topic(peerObject~localTopicName)
  if localTopic == .nil then return .QueueOperationResult~failure("TOPIC_NOT_FOUND", peerObject~localTopicName)
  if remotePublication~securityDomain \= localTopic~securityDomain & \peerObject~allowCrossDomain then return .QueueOperationResult~failure("REMOTE_TOPIC_SECURITY_DOMAIN_DENIED", remotePublication~securityDomain || " -> " || localTopic~securityDomain)
  if self~pathContains(remotePublication~path, managerName) then return .QueueOperationResult~success(.true, "loop candidate")
  return .QueueOperationResult~success(.true)

::method remoteInterest private
  expose remoteInterests
  use strict arg peerObject
  return remoteInterests[peerObject~key]

::method localAdvertisements private
  expose managerName topicFabric remoteInterests
  use strict arg topicName, targetManager
  advertisements = .array~new
  seen = .table~new
  do subscriptionObject over topicFabric~subscriptions
    if subscriptionObject~topicName \= topicName then iterate
    path = .array~of(managerName)
    key = subscriptionObject~pattern || "|" || managerName~translate || "|" || self~pathText(path)
    if seen~hasIndex(key) then iterate
    seen[key] = .true
    advertisements~append(.array~of(subscriptionObject~pattern, managerName, path))
  end
  supplier = remoteInterests~supplier
  do while supplier~available
    interest = supplier~item
    supplier~next
    if interest~localTopicName \= topicName then iterate
    if interest~remoteManager~translate = targetManager~string~translate then iterate
    do advertisement over interest~advertisements
      pattern = advertisement[1]
      originManager = advertisement[2]
      path = self~copyArray(advertisement[3])
      if self~pathContains(path, targetManager) then iterate
      if \self~pathContains(path, managerName) then path~append(managerName)
      key = pattern || "|" || originManager~string~translate || "|" || self~pathText(path)
      if seen~hasIndex(key) then iterate
      seen[key] = .true
      advertisements~append(.array~of(pattern, originManager, path))
    end
  end
  return advertisements

::method validatedAdvertisements private
  use strict arg incomingAdvertisements, sourceManager, destinationManager
  if incomingAdvertisements == .nil | \incomingAdvertisements~hasMethod("ITEMS") then return .nil
  advertisements = .array~new
  seen = .table~new
  do advertisement over incomingAdvertisements
    if advertisement == .nil | \advertisement~hasMethod("ITEMS") | advertisement~items < 3 then return .nil
    checkResult = .QueueTopicPattern~canonicalPattern(advertisement[1])
    if \checkResult~ok then return .nil
    originManager = advertisement[2]~string~strip
    if originManager = "" then return .nil
    path = self~copyArray(advertisement[3])
    if path~items = 0 then return .nil
    if \self~pathContains(path, sourceManager) then return .nil
    if self~pathContains(path, destinationManager) then return .nil
    canonical = checkResult~value
    key = canonical || "|" || originManager~translate || "|" || self~pathText(path)
    if seen~hasIndex(key) then iterate
    seen[key] = .true
    advertisements~append(.array~of(canonical, originManager, path))
  end
  return advertisements

::method markOtherPeersDirty private
  expose dirty
  use strict arg topicName, sourceManager
  do peerObject over self~peers
    if peerObject~localTopicName \= topicName then iterate
    if peerObject~remoteManager~translate = sourceManager~string~translate then iterate
    dirty[peerObject~key] = .true
  end
  return .true

::method recover private
  expose queueManager recovering peers remoteInterests txRevisions receipts
  recovering = .true
  rows = queueManager~durableStore~readJournal
  do row over rows
    if row~items = 0 then iterate
    if row[1] = "UOWCOMMIT" then do
      if row~items < 2 then iterate
      nestedRows = queueManager~payloadCodec~decode(row[2])
      do nestedRow over nestedRows
        ignore = self~applyRecoveryRow(nestedRow)
      end
    end
    else ignore = self~applyRecoveryRow(row)
  end
  recovering = .false
  return .true

::method applyRecoveryRow private
  expose peers remoteInterests txRevisions receipts queueManager
  use strict arg row
  if row == .nil | row~items = 0 then return .false
  tag = row[1]
  select
    when tag = "DTPEER" then do
      if row~items < 10 then return .false
      peerObject = .QueueTopicPeerDefinition~new(row[2], row[3], row[4], row[5], row[6], row[7], self~truth(row[8]), row[9], row[10])
      peers[peerObject~key] = peerObject
    end
    when tag = "DTPEERDELETE" then do
      if row~items >= 3 then peers~remove(self~peerKey(row[2], row[3]))
    end
    when tag = "DTTXREV" then do
      if row~items >= 4 then txRevisions[self~peerKey(row[2], row[3])] = row[4]
    end
    when tag = "DTINTEREST" then do
      if row~items < 7 then return .false
      advertisements = queueManager~payloadCodec~decode(row[6])
      interest = .QueueTopicRemoteInterest~new(row[2], row[3], row[4], row[5], advertisements, row[7])
      remoteInterests[self~peerKey(row[2], row[3])] = interest
    end
    when tag = "DTPUBRECEIPT" then do
      if row~items < 6 then return .false
      receipts[self~receiptKey(row[2], row[3], row[4])] = row
    end
    otherwise nop
  end
  return .true

::method peerKey private
  use strict arg remoteManager, localTopicName
  return remoteManager~string~translate || "|" || localTopicName~string~translate

::method receiptKey private
  use strict arg originManager, publicationId, destinationTopicName
  return originManager~string~translate || "|" || publicationId~string || "|" || destinationTopicName~string~translate

::method relativeSubtopic private
  use strict arg root, concreteTopic
  if concreteTopic = root then return ""
  prefix = root || "/"
  if concreteTopic~startsWith(prefix) then return concreteTopic~substr(prefix~length + 1)
  return concreteTopic

::method normalizedPath private
  use strict arg path
  if path == .nil then return .array~new
  if path~hasMethod("ITEMS") then return self~copyArray(path)
  return .array~new

::method copyArray private
  use strict arg source
  copied = .array~new
  if source == .nil then return copied
  do item over source
    copied~append(item)
  end
  return copied

::method pathContains private
  use strict arg path, manager
  managerText = manager~string~translate
  if path == .nil then return .false
  do item over path
    if item~string~translate = managerText then return .true
  end
  return .false

::method pathText private
  use strict arg path
  text = ""
  do item over path
    if text \= "" then text ||= ">"
    text ||= item~string
  end
  return text

::method pathFromHeaders private
  use strict arg headers
  path = .array~new
  if headers == .nil then return path
  text = headers["oqf.remote.path"]
  if text == .nil | text = "" then return path
  parts = .QueueRecordCodec~split(text~string, ">")
  do item over parts
    if item \= "" then path~append(item)
  end
  return path

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

::method isAdmin private
  expose queueManager
  use strict arg principal
  return principal~string = queueManager~adminPrincipal

::method recordTraffic
  use strict arg eventType, topicName, publicationId, principal, detail, source, destination, success
  guard on
  event = self~recordTrafficLocked(eventType, topicName, publicationId, principal, detail, source, destination, success)
  guard off
  return event

::method recordTrafficLocked private
  expose traffic queueManager idGenerator
  use strict arg eventType, topicName, publicationId, principal, detail, source, destination, success
  event = .QueueTrafficEvent~new(idGenerator~next, eventType, topicName, publicationId, principal, detail, source, destination, success)
  traffic~append(event)
  if queueManager~durableStore \== .nil then ignore = queueManager~durableStore~appendTraffic(event)
  return event

::requires "ObjectQueueTopics.cls"
::requires "ObjectQueueChannels.cls"
::requires "AlchemyObject.cls"
