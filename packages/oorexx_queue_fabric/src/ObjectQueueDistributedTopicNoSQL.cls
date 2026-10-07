/* NoSQLServer v0.73 projection adapter for ObjectQueueFabric v0.8 distributed topics. */

::class QueueDistributedTopicNoSQLAdapter public
::attribute distributedTopicFabric get
::attribute baseAdapter get
::attribute prefix get

::method init
  expose distributedTopicFabric baseAdapter prefix
  use strict arg distributedTopicFabric, baseAdapter = .nil, prefix = "mq_"
  distributedTopicFabric = distributedTopicFabric
  baseAdapter = baseAdapter
  prefix = prefix~string

::method query
  use strict arg principal, sqlText
  engine = self~buildEngine(principal)
  return .NoSQLServerSQL~new(engine)~execute(sqlText)

::method buildEngine private
  use strict arg principal
  engine = .ObjectDatabaseEngine~new
  if \self~snapshotInto(engine, principal) then raise syntax 88.900 array("Unable to project distributed topic tables")
  return engine

::method snapshotInto
  expose distributedTopicFabric baseAdapter prefix
  use strict arg federatedEngine, principal
  effectiveBase = baseAdapter
  if effectiveBase == .nil then effectiveBase = .QueueTopicNoSQLAdapter~new(distributedTopicFabric~topicFabric, .nil, prefix)
  if \effectiveBase~snapshotInto(federatedEngine, principal) then return .false

  peerRows = .array~new
  do peerObject over distributedTopicFabric~authorisedPeers(principal)
    peerRows~append(.QueueNoSQLDistributedTopicPeerRow~new(peerObject))
  end
  peerMap = .ObjectTableMapping~new(prefix || "topic_peers")
  ignore = peerMap~column("peer_id", "VARCHAR", "peerId")
  ignore = peerMap~column("remote_manager", "VARCHAR", "remoteManager")
  ignore = peerMap~column("local_topic", "VARCHAR", "localTopicName")
  ignore = peerMap~column("remote_topic", "VARCHAR", "remoteTopicName")
  ignore = peerMap~column("control_remote_queue", "VARCHAR", "controlRemoteQueue")
  ignore = peerMap~column("publication_remote_queue", "VARCHAR", "publicationRemoteQueue")
  ignore = peerMap~column("lifecycle", "VARCHAR", "lifecycle")
  ignore = peerMap~column("allow_cross_domain", "INTEGER", "crossDomainFlag")
  ignore = peerMap~column("owner", "VARCHAR", "owner")
  ignore = peerMap~column("created_at", "VARCHAR", "createdAt")
  ignore = peerMap~identity("peer_id")
  if \federatedEngine~registerSnapshot(prefix || "topic_peers", peerRows, peerMap) then return .false

  interestRows = .array~new
  advertisementRows = .array~new
  do interest over distributedTopicFabric~authorisedRemoteInterests(principal)
    interestRows~append(.QueueNoSQLRemoteTopicInterestRow~new(interest))
    advertIndex = 0
    do advertisement over interest~advertisements
      advertIndex += 1
      advertisementRows~append(.QueueNoSQLRemoteTopicAdvertisementRow~new(interest, advertisement, advertIndex))
    end
  end
  interestMap = .ObjectTableMapping~new(prefix || "remote_topic_interests")
  ignore = interestMap~column("interest_id", "VARCHAR", "interestId")
  ignore = interestMap~column("remote_manager", "VARCHAR", "remoteManager")
  ignore = interestMap~column("local_topic", "VARCHAR", "localTopicName")
  ignore = interestMap~column("remote_topic", "VARCHAR", "remoteTopicName")
  ignore = interestMap~column("revision", "INTEGER", "revision")
  ignore = interestMap~column("advertisement_count", "INTEGER", "advertisementCount")
  ignore = interestMap~column("updated_at", "VARCHAR", "updatedAt")
  ignore = interestMap~identity("interest_id")
  if \federatedEngine~registerSnapshot(prefix || "remote_topic_interests", interestRows, interestMap) then return .false

  advertisementMap = .ObjectTableMapping~new(prefix || "topic_interest_advertisements")
  ignore = advertisementMap~column("advertisement_id", "VARCHAR", "advertisementId")
  ignore = advertisementMap~column("remote_manager", "VARCHAR", "remoteManager")
  ignore = advertisementMap~column("local_topic", "VARCHAR", "localTopicName")
  ignore = advertisementMap~column("pattern", "VARCHAR", "pattern")
  ignore = advertisementMap~column("origin_manager", "VARCHAR", "originManager")
  ignore = advertisementMap~column("path", "VARCHAR", "path")
  ignore = advertisementMap~identity("advertisement_id")
  if \federatedEngine~registerSnapshot(prefix || "topic_interest_advertisements", advertisementRows, advertisementMap) then return .false

  receiptRows = .array~new
  do receiptRow over distributedTopicFabric~authorisedReceipts(principal)
    receiptRows~append(.QueueNoSQLDistributedTopicReceiptRow~new(receiptRow))
  end
  receiptMap = .ObjectTableMapping~new(prefix || "topic_distribution_receipts")
  ignore = receiptMap~column("receipt_id", "VARCHAR", "receiptId")
  ignore = receiptMap~column("origin_manager", "VARCHAR", "originManager")
  ignore = receiptMap~column("publication_id", "VARCHAR", "publicationId")
  ignore = receiptMap~column("destination_topic", "VARCHAR", "destinationTopicName")
  ignore = receiptMap~column("source_manager", "VARCHAR", "sourceManager")
  ignore = receiptMap~column("received_at", "VARCHAR", "receivedAt")
  ignore = receiptMap~identity("receipt_id")
  if \federatedEngine~registerSnapshot(prefix || "topic_distribution_receipts", receiptRows, receiptMap) then return .false

  trafficRows = .array~new
  do event over distributedTopicFabric~authorisedTraffic(principal)
    trafficRows~append(.QueueNoSQLDistributedTopicTrafficRow~new(event))
  end
  trafficMap = .ObjectTableMapping~new(prefix || "distributed_topic_traffic")
  ignore = trafficMap~column("event_id", "VARCHAR", "eventId")
  ignore = trafficMap~column("timestamp", "VARCHAR", "timestamp")
  ignore = trafficMap~column("event_type", "VARCHAR", "eventType")
  ignore = trafficMap~column("topic_name", "VARCHAR", "topicName")
  ignore = trafficMap~column("publication_id", "VARCHAR", "publicationId")
  ignore = trafficMap~column("principal", "VARCHAR", "principal")
  ignore = trafficMap~column("detail", "VARCHAR", "detail")
  ignore = trafficMap~column("source_manager", "VARCHAR", "sourceManager")
  ignore = trafficMap~column("destination_manager", "VARCHAR", "destinationManager")
  ignore = trafficMap~column("success", "INTEGER", "successFlag")
  ignore = trafficMap~identity("event_id")
  if \federatedEngine~registerSnapshot(prefix || "distributed_topic_traffic", trafficRows, trafficMap) then return .false

  return .true

::class QueueNoSQLDistributedTopicPeerRow
::attribute peerId get
::attribute remoteManager get
::attribute localTopicName get
::attribute remoteTopicName get
::attribute controlRemoteQueue get
::attribute publicationRemoteQueue get
::attribute lifecycle get
::attribute crossDomainFlag get
::attribute owner get
::attribute createdAt get
::method init
  expose peerId remoteManager localTopicName remoteTopicName controlRemoteQueue publicationRemoteQueue lifecycle crossDomainFlag owner createdAt
  use strict arg peerObject
  remoteManager = peerObject~remoteManager
  localTopicName = peerObject~localTopicName
  remoteTopicName = peerObject~remoteTopicName
  peerId = remoteManager || "|" || localTopicName
  controlRemoteQueue = peerObject~controlRemoteQueue
  publicationRemoteQueue = peerObject~publicationRemoteQueue
  lifecycle = peerObject~lifecycle
  if peerObject~allowCrossDomain then crossDomainFlag = 1
  else crossDomainFlag = 0
  owner = peerObject~owner
  createdAt = peerObject~createdAt

::class QueueNoSQLRemoteTopicInterestRow
::attribute interestId get
::attribute remoteManager get
::attribute localTopicName get
::attribute remoteTopicName get
::attribute revision get
::attribute advertisementCount get
::attribute updatedAt get
::method init
  expose interestId remoteManager localTopicName remoteTopicName revision advertisementCount updatedAt
  use strict arg interest
  remoteManager = interest~remoteManager
  localTopicName = interest~localTopicName
  remoteTopicName = interest~remoteTopicName
  interestId = remoteManager || "|" || localTopicName
  revision = interest~revision
  advertisementCount = interest~advertisements~items
  updatedAt = interest~updatedAt

::class QueueNoSQLRemoteTopicAdvertisementRow
::attribute advertisementId get
::attribute remoteManager get
::attribute localTopicName get
::attribute pattern get
::attribute originManager get
::attribute path get
::method init
  expose advertisementId remoteManager localTopicName pattern originManager path
  use strict arg interest, advertisement, advertIndex
  remoteManager = interest~remoteManager
  localTopicName = interest~localTopicName
  pattern = advertisement[1]
  originManager = advertisement[2]
  path = self~pathText(advertisement[3])
  advertisementId = remoteManager || "|" || localTopicName || "|" || advertIndex
::method pathText private
  use strict arg pathArray
  text = ""
  do item over pathArray
    if text \= "" then text ||= ">"
    text ||= item~string
  end
  return text

::class QueueNoSQLDistributedTopicReceiptRow
::attribute receiptId get
::attribute originManager get
::attribute publicationId get
::attribute destinationTopicName get
::attribute sourceManager get
::attribute receivedAt get
::method init
  expose receiptId originManager publicationId destinationTopicName sourceManager receivedAt
  use strict arg row
  originManager = row[2]
  publicationId = row[3]
  destinationTopicName = row[4]
  sourceManager = row[5]
  receivedAt = row[6]
  receiptId = originManager || "|" || publicationId || "|" || destinationTopicName

::class QueueNoSQLDistributedTopicTrafficRow
::attribute eventId get
::attribute timestamp get
::attribute eventType get
::attribute topicName get
::attribute publicationId get
::attribute principal get
::attribute detail get
::attribute sourceManager get
::attribute destinationManager get
::attribute successFlag get
::method init
  expose eventId timestamp eventType topicName publicationId principal detail sourceManager destinationManager successFlag
  use strict arg event
  eventId = event~eventId
  timestamp = event~timestamp
  eventType = event~eventType
  topicName = event~queueName
  publicationId = event~packageId
  principal = event~principal
  detail = event~detail
  sourceManager = event~sourceQueue
  destinationManager = event~destinationQueue
  if event~success then successFlag = 1
  else successFlag = 0

::requires "ObjectQueueDistributedTopics.cls"
::requires "ObjectQueueTopicNoSQL.cls"
