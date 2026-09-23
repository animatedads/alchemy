/* NoSQLServer v0.73 projection adapter for ObjectQueueFabric v0.8 channels. */

::class QueueChannelNoSQLAdapter public
::attribute channelFabric get
::attribute prefix get

::method init
  expose channelFabric prefix
  use arg channelFabric, prefix = "mq_"
  channelFabric = channelFabric
  prefix = prefix~string

::method query
  use arg principal, sqlText
  engine = self~buildEngine(principal)
  return .NoSQLServerSQL~new(engine)~execute(sqlText)

::method buildEngine private
  use strict arg principal
  engine = .ObjectDatabaseEngine~new
  if \self~snapshotInto(engine, principal) then raise syntax 88.900 array("Unable to project queue channel tables")
  return engine

::method snapshotInto
  expose channelFabric prefix
  use strict arg federatedEngine, principal
  baseAdapter = .QueueNoSQLAdapter~new(channelFabric~queueManager, prefix)
  if \baseAdapter~snapshotInto(federatedEngine, principal) then return .false

  senderRows = .array~new
  do channel over channelFabric~authorisedSenderChannels(principal)
    senderRows~append(.QueueNoSQLSenderChannelRow~new(channel))
  end
  senderMap = .ObjectTableMapping~new(prefix || "sender_channels")
  ignore = senderMap~column("channel_name", "VARCHAR", "channelName")
  ignore = senderMap~column("lifecycle", "VARCHAR", "lifecycle")
  ignore = senderMap~column("transmission_queue", "VARCHAR", "transmissionQueue")
  ignore = senderMap~column("remote_manager", "VARCHAR", "remoteManager")
  ignore = senderMap~column("remote_channel", "VARCHAR", "remoteChannel")
  ignore = senderMap~column("local_principal", "VARCHAR", "localPrincipal")
  ignore = senderMap~column("remote_principal", "VARCHAR", "remotePrincipal")
  ignore = senderMap~column("retry_limit", "INTEGER", "retryLimit")
  ignore = senderMap~column("state", "VARCHAR", "state")
  ignore = senderMap~column("retry_count", "INTEGER", "retryCount")
  ignore = senderMap~column("sent_count", "INTEGER", "sentCount")
  ignore = senderMap~column("duplicate_count", "INTEGER", "duplicateCount")
  ignore = senderMap~column("last_error", "VARCHAR", "lastError")
  ignore = senderMap~column("last_attempt_at", "VARCHAR", "lastAttemptAt")
  ignore = senderMap~column("last_success_at", "VARCHAR", "lastSuccessAt")
  ignore = senderMap~column("created_at", "VARCHAR", "createdAt")
  ignore = senderMap~identity("channel_name")
  if \federatedEngine~registerSnapshot(prefix || "sender_channels", senderRows, senderMap) then return .false

  receiverRows = .array~new
  do channel over channelFabric~authorisedReceiverChannels(principal)
    receiverRows~append(.QueueNoSQLReceiverChannelRow~new(channel))
  end
  receiverMap = .ObjectTableMapping~new(prefix || "receiver_channels")
  ignore = receiverMap~column("channel_name", "VARCHAR", "channelName")
  ignore = receiverMap~column("lifecycle", "VARCHAR", "lifecycle")
  ignore = receiverMap~column("source_manager", "VARCHAR", "sourceManager")
  ignore = receiverMap~column("inbound_principal", "VARCHAR", "inboundPrincipal")
  ignore = receiverMap~column("state", "VARCHAR", "state")
  ignore = receiverMap~column("received_count", "INTEGER", "receivedCount")
  ignore = receiverMap~column("duplicate_count", "INTEGER", "duplicateCount")
  ignore = receiverMap~column("rejected_count", "INTEGER", "rejectedCount")
  ignore = receiverMap~column("last_error", "VARCHAR", "lastError")
  ignore = receiverMap~column("last_receive_at", "VARCHAR", "lastReceiveAt")
  ignore = receiverMap~column("created_at", "VARCHAR", "createdAt")
  ignore = receiverMap~identity("channel_name")
  if \federatedEngine~registerSnapshot(prefix || "receiver_channels", receiverRows, receiverMap) then return .false

  remoteRows = .array~new
  do definition over channelFabric~authorisedRemoteQueues(principal)
    remoteRows~append(.QueueNoSQLRemoteQueueRow~new(definition))
  end
  remoteMap = .ObjectTableMapping~new(prefix || "remote_queues")
  ignore = remoteMap~column("alias_name", "VARCHAR", "aliasName")
  ignore = remoteMap~column("lifecycle", "VARCHAR", "lifecycle")
  ignore = remoteMap~column("remote_queue", "VARCHAR", "remoteQueue")
  ignore = remoteMap~column("remote_manager", "VARCHAR", "remoteManager")
  ignore = remoteMap~column("transmission_queue", "VARCHAR", "transmissionQueue")
  ignore = remoteMap~column("channel_name", "VARCHAR", "channelName")
  ignore = remoteMap~column("security_domain", "VARCHAR", "securityDomain")
  ignore = remoteMap~column("owner", "VARCHAR", "owner")
  ignore = remoteMap~column("created_at", "VARCHAR", "createdAt")
  ignore = remoteMap~identity("alias_name")
  if \federatedEngine~registerSnapshot(prefix || "remote_queues", remoteRows, remoteMap) then return .false
  return .true

::class QueueNoSQLSenderChannelRow
::attribute channelName get
::attribute lifecycle get
::attribute transmissionQueue get
::attribute remoteManager get
::attribute remoteChannel get
::attribute localPrincipal get
::attribute remotePrincipal get
::attribute retryLimit get
::attribute state get
::attribute retryCount get
::attribute sentCount get
::attribute duplicateCount get
::attribute lastError get
::attribute lastAttemptAt get
::attribute lastSuccessAt get
::attribute createdAt get
::method init
  expose channelName lifecycle transmissionQueue remoteManager remoteChannel localPrincipal remotePrincipal retryLimit state retryCount sentCount duplicateCount lastError lastAttemptAt lastSuccessAt createdAt
  use arg channel
  channelName = channel~channelName
  lifecycle = channel~lifecycle
  transmissionQueue = channel~transmissionQueue
  remoteManager = channel~remoteManager
  remoteChannel = channel~remoteChannel
  localPrincipal = channel~localPrincipal
  remotePrincipal = channel~remotePrincipal
  retryLimit = channel~retryLimit
  state = channel~state
  retryCount = channel~retryCount
  sentCount = channel~sentCount
  duplicateCount = channel~duplicateCount
  lastError = channel~lastError
  lastAttemptAt = channel~lastAttemptAt
  lastSuccessAt = channel~lastSuccessAt
  createdAt = channel~createdAt

::class QueueNoSQLReceiverChannelRow
::attribute channelName get
::attribute lifecycle get
::attribute sourceManager get
::attribute inboundPrincipal get
::attribute state get
::attribute receivedCount get
::attribute duplicateCount get
::attribute rejectedCount get
::attribute lastError get
::attribute lastReceiveAt get
::attribute createdAt get
::method init
  expose channelName lifecycle sourceManager inboundPrincipal state receivedCount duplicateCount rejectedCount lastError lastReceiveAt createdAt
  use arg channel
  channelName = channel~channelName
  lifecycle = channel~lifecycle
  sourceManager = channel~sourceManager
  inboundPrincipal = channel~inboundPrincipal
  state = channel~state
  receivedCount = channel~receivedCount
  duplicateCount = channel~duplicateCount
  rejectedCount = channel~rejectedCount
  lastError = channel~lastError
  lastReceiveAt = channel~lastReceiveAt
  createdAt = channel~createdAt

::class QueueNoSQLRemoteQueueRow
::attribute aliasName get
::attribute lifecycle get
::attribute remoteQueue get
::attribute remoteManager get
::attribute transmissionQueue get
::attribute channelName get
::attribute securityDomain get
::attribute owner get
::attribute createdAt get
::method init
  expose aliasName lifecycle remoteQueue remoteManager transmissionQueue channelName securityDomain owner createdAt
  use arg definition
  aliasName = definition~aliasName
  lifecycle = definition~lifecycle
  remoteQueue = definition~remoteQueue
  remoteManager = definition~remoteManager
  transmissionQueue = definition~transmissionQueue
  channelName = definition~channelName
  securityDomain = definition~securityDomain
  owner = definition~owner
  createdAt = definition~createdAt

::requires "ObjectQueueNoSQL.cls"
::requires "ObjectQueueChannels.cls"
