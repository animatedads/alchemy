/*
 * ObjectQueueFabric v0.8 distributed channel layer.
 *
 * MQ-like store-and-forward wiring over ObjectQueueManager:
 *   - remote queue definitions
 *   - named sender/receiver channels
 *   - transmission queues
 *   - explicit start/stop/pause/retry state
 *   - receiver-side source/principal binding
 *   - idempotent receiver acceptance via ObjectQueueManager~acceptTransfer
 *
 * The supplied QueueInProcessTransport is deliberately a test/reference
 * transport.  It demonstrates the transport boundary without pretending that
 * an in-process object call is network authentication or encryption.
 */

::class QueueChannelState public
::constant STOPPED "STOPPED"
::constant RUNNING "RUNNING"
::constant RETRYING "RETRYING"
::constant PAUSED "PAUSED"

::class QueueChannelAuthority
::method init
  nop

::class QueueSenderChannel public
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
  expose channelName lifecycle transmissionQueue remoteManager remoteChannel localPrincipal remotePrincipal retryLimit state retryCount sentCount duplicateCount lastError lastAttemptAt lastSuccessAt createdAt managerAuthority
  use arg channelName, lifecycle, transmissionQueue, remoteManager, remoteChannel, localPrincipal, remotePrincipal, retryLimit, authorityCandidate, createdAt = "", initialState = "STOPPED"
  channelName = channelName~string
  lifecycle = lifecycle~string~translate
  transmissionQueue = transmissionQueue~string
  remoteManager = remoteManager~string
  remoteChannel = remoteChannel~string
  localPrincipal = localPrincipal~string
  remotePrincipal = remotePrincipal~string
  retryLimit = retryLimit
  state = initialState~string~translate
  retryCount = 0
  sentCount = 0
  duplicateCount = 0
  lastError = ""
  lastAttemptAt = ""
  lastSuccessAt = ""
  if createdAt = "" then createdAt = .QueueClock~timestamp
  createdAt = createdAt~string
  managerAuthority = authorityCandidate

::method setStateInternal
  expose state managerAuthority retryCount
  use arg newState, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  newState = newState~string~translate
  if newState \= .QueueChannelState~STOPPED & newState \= .QueueChannelState~RUNNING & newState \= .QueueChannelState~PAUSED & newState \= .QueueChannelState~RETRYING then return .false
  state = newState
  if newState = .QueueChannelState~RUNNING then retryCount = 0
  return .true

::method noteAttemptInternal
  expose lastAttemptAt managerAuthority
  use arg authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  lastAttemptAt = .QueueClock~timestamp
  return .true

::method noteFailureInternal
  expose retryCount retryLimit lastError state managerAuthority
  use arg detail, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  retryCount += 1
  lastError = detail~string
  if retryLimit > 0 & retryCount >= retryLimit then state = .QueueChannelState~STOPPED
  else state = .QueueChannelState~RETRYING
  return .true

::method noteSuccessInternal
  expose retryCount sentCount duplicateCount lastError lastSuccessAt state managerAuthority
  use arg wasDuplicate = .false, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  retryCount = 0
  sentCount += 1
  if wasDuplicate then duplicateCount += 1
  lastError = ""
  lastSuccessAt = .QueueClock~timestamp
  state = .QueueChannelState~RUNNING
  return .true

::class QueueReceiverChannel public
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
  expose channelName lifecycle sourceManager inboundPrincipal state receivedCount duplicateCount rejectedCount lastError lastReceiveAt createdAt managerAuthority
  use arg channelName, lifecycle, sourceManager, inboundPrincipal, authorityCandidate, createdAt = "", initialState = "STOPPED"
  channelName = channelName~string
  lifecycle = lifecycle~string~translate
  sourceManager = sourceManager~string
  inboundPrincipal = inboundPrincipal~string
  state = initialState~string~translate
  receivedCount = 0
  duplicateCount = 0
  rejectedCount = 0
  lastError = ""
  lastReceiveAt = ""
  if createdAt = "" then createdAt = .QueueClock~timestamp
  createdAt = createdAt~string
  managerAuthority = authorityCandidate

::method setStateInternal
  expose state managerAuthority
  use arg newState, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  newState = newState~string~translate
  if newState \= .QueueChannelState~STOPPED & newState \= .QueueChannelState~RUNNING & newState \= .QueueChannelState~PAUSED then return .false
  state = newState
  return .true

::method noteReceiveInternal
  expose receivedCount duplicateCount lastError lastReceiveAt managerAuthority
  use arg wasDuplicate = .false, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  receivedCount += 1
  if wasDuplicate then duplicateCount += 1
  lastError = ""
  lastReceiveAt = .QueueClock~timestamp
  return .true

::method noteRejectInternal
  expose rejectedCount lastError managerAuthority
  use arg detail, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  rejectedCount += 1
  lastError = detail~string
  return .true

::class QueueRemoteQueueDefinition public
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
  expose aliasName lifecycle remoteQueue remoteManager transmissionQueue channelName securityDomain owner createdAt accessPolicy managerAuthority
  use arg aliasName, lifecycle, remoteQueue, remoteManager, transmissionQueue, channelName, securityDomain, owner, authorityCandidate, createdAt = ""
  aliasName = aliasName~string
  lifecycle = lifecycle~string~translate
  remoteQueue = remoteQueue~string
  remoteManager = remoteManager~string
  transmissionQueue = transmissionQueue~string
  channelName = channelName~string
  securityDomain = securityDomain~string
  owner = owner~string
  if createdAt = "" then createdAt = .QueueClock~timestamp
  createdAt = createdAt~string
  accessPolicy = .QueueAccessPolicy~new(owner)
  managerAuthority = authorityCandidate

::method allowsInternal
  expose accessPolicy managerAuthority
  use arg principal, action, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  return accessPolicy~allows(principal, action)

::method allowInternal
  expose accessPolicy managerAuthority
  use arg principal, action, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  return accessPolicy~allow(principal, action)

::method revokeInternal
  expose accessPolicy managerAuthority
  use arg principal, action, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  return accessPolicy~revoke(principal, action)

::method grantRowsInternal
  expose accessPolicy managerAuthority
  use arg authorityCandidate
  if authorityCandidate \== managerAuthority then return .array~new
  return accessPolicy~grantRows

::class QueueInProcessTransport public
::method init
  expose endpoints
  endpoints = .table~new

::method registerEndpoint
  expose endpoints
  use arg managerName, channelFabric
  guard on
  endpoints[managerName~string~translate] = channelFabric
  guard off
  return .true

::method unregisterEndpoint
  expose endpoints
  use arg managerName
  guard on
  removed = endpoints~remove(managerName~string~translate)
  guard off
  return removed

::method deliver
  expose endpoints
  use arg remoteManager, remoteChannel, envelope, principal
  guard on
  endpoint = endpoints[remoteManager~string~translate]
  guard off
  if endpoint == .nil then return .QueueOperationResult~failure("REMOTE_MANAGER_UNAVAILABLE", remoteManager)
  return endpoint~receiveEnvelope(envelope, remoteChannel, principal)

::class QueueChannelFabric subclass AlchemyObject public
::attribute managerName get
::attribute queueManager get
::attribute adminPrincipal get
::attribute transport get

::method init
  expose managerName queueManager adminPrincipal transport senderChannels receiverChannels remoteQueues idGenerator authority
  use arg managerName, queueManager, transport = .nil, adminPrincipal = ""
  managerName = managerName~string~strip
  if managerName = "" then raise syntax 88.900 array("Queue channel fabric requires a manager name")
  if queueManager == .nil then raise syntax 88.900 array("Queue channel fabric requires an ObjectQueueManager")
  queueManager = queueManager
  if adminPrincipal = "" then adminPrincipal = queueManager~adminPrincipal
  adminPrincipal = adminPrincipal~string
  if transport == .nil then transport = .QueueInProcessTransport~new
  transport = transport
  senderChannels = .table~new
  receiverChannels = .table~new
  remoteQueues = .table~new
  idGenerator = .QueueIdGenerator~new("xfer-" || managerName)
  authority = .QueueChannelAuthority~new

  limitations = .array~of("Transport is at-least-once; receiver insertion is idempotent by transfer receipt", "Channel retry is local store-and-forward rather than distributed XA")
  meta = .QueueFabricAlchemyMetadata~standard("Sender/receiver channel wiring and store-and-forward", "queue.channel.fabric/0.9-dev3", limitations)
  self~initAlchemy(meta)
  self~registerStateVariable("managerName", "PUBLIC", "local queue-manager identity")
  self~registerStateVariable("adminPrincipal", "INTERNAL", "channel administration principal")
  self~registerMethodContract("PUMP", "Pump bounded work from one sender channel", .array~of("CHANNEL", "MAX_MESSAGES", "PRINCIPAL"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("RECEIVEENVELOPE", "Idempotently accept one inbound transfer", .array~of("CHANNEL", "ENVELOPE", "SOURCE_MANAGER", "PRINCIPAL"), "QUEUEOPERATIONRESULT", .false)
  self~describeMethodPolicy("PUMP", "FALSE", "CUSTOMER", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("RECEIVEENVELOPE", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~recordRelationship("QUEUE_MANAGER", queueManager, "queue-state authority", "INTERNAL")
  self~recordRelationship("TRANSPORT", transport, "delivery transport collaborator", "INTERNAL")

  self~recoverDefinitions

::method senderChannel
  expose senderChannels
  use arg channelName
  return senderChannels[channelName~string~translate]

::method receiverChannel
  expose receiverChannels
  use arg channelName
  return receiverChannels[channelName~string~translate]

::method remoteQueue
  expose remoteQueues
  use arg aliasName
  return remoteQueues[aliasName~string~translate]

::method senderChannels
  expose senderChannels
  rows = .array~new
  supplier = senderChannels~supplier
  do while supplier~available
    rows~append(supplier~item)
    supplier~next
  end
  return rows

::method receiverChannels
  expose receiverChannels
  rows = .array~new
  supplier = receiverChannels~supplier
  do while supplier~available
    rows~append(supplier~item)
    supplier~next
  end
  return rows

::method remoteQueues
  expose remoteQueues
  rows = .array~new
  supplier = remoteQueues~supplier
  do while supplier~available
    rows~append(supplier~item)
    supplier~next
  end
  return rows

::method defineSenderChannel
  expose senderChannels queueManager adminPrincipal authority
  use arg channelName, transmissionQueue, remoteManager, remoteChannel = "", localPrincipal = "", remotePrincipal = "", retryLimit = 0, lifecycle = "TEMPORARY", principal = ""
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "channel administration")
  channelName = channelName~string~strip
  transmissionQueue = transmissionQueue~string~strip
  remoteManager = remoteManager~string~strip
  if remoteChannel = "" then remoteChannel = channelName
  if localPrincipal = "" then localPrincipal = adminPrincipal
  if remotePrincipal = "" then remotePrincipal = adminPrincipal
  lifecycle = lifecycle~string~translate
  if channelName = "" | transmissionQueue = "" | remoteManager = "" then return .QueueOperationResult~failure("INVALID_CHANNEL_DEFINITION")
  if senderChannels~hasIndex(channelName~translate) then return .QueueOperationResult~failure("CHANNEL_EXISTS", channelName)
  if lifecycle \= .QueueLifecycle~TEMPORARY & lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("INVALID_LIFECYCLE", lifecycle)
  if \datatype(retryLimit, "W") | retryLimit < 0 then return .QueueOperationResult~failure("INVALID_RETRY_LIMIT", retryLimit)
  xmit = queueManager~queue(transmissionQueue)
  if xmit == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", transmissionQueue)
  if lifecycle = .QueueLifecycle~PERMANENT then do
    if queueManager~durableStore == .nil then return .QueueOperationResult~failure("PERSISTENCE_UNAVAILABLE")
    if xmit~lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("PERMANENT_CHANNEL_REQUIRES_PERMANENT_XMITQ", transmissionQueue)
  end
  channel = .QueueSenderChannel~new(channelName, lifecycle, xmit~name, remoteManager, remoteChannel, localPrincipal, remotePrincipal, retryLimit, authority)
  guard on
  senderChannels[channelName~translate] = channel
  if lifecycle = .QueueLifecycle~PERMANENT then ignore = queueManager~durableStore~appendJournal("CHDEFINE", .array~of(channelName, lifecycle, xmit~name, remoteManager, remoteChannel, localPrincipal, remotePrincipal, retryLimit, channel~createdAt))
  guard off
  return .QueueOperationResult~success(channel)

::method deleteSenderChannel
  expose senderChannels remoteQueues queueManager
  use arg channelName, principal = ""
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "channel administration")
  channel = self~senderChannel(channelName)
  if channel == .nil then return .QueueOperationResult~failure("CHANNEL_NOT_FOUND", channelName)
  do definition over self~remoteQueues
    if definition~channelName = channel~channelName then return .QueueOperationResult~failure("CHANNEL_IN_USE", definition~aliasName)
  end
  guard on
  senderChannels~remove(channel~channelName~translate)
  if channel~lifecycle = .QueueLifecycle~PERMANENT & queueManager~durableStore \== .nil then ignore = queueManager~durableStore~appendJournal("CHDELETE", .array~of(channel~channelName))
  guard off
  return .QueueOperationResult~success(channel)

::method defineReceiverChannel
  expose receiverChannels queueManager adminPrincipal authority
  use arg channelName, sourceManager, inboundPrincipal = "", lifecycle = "TEMPORARY", principal = ""
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "receiver channel administration")
  channelName = channelName~string~strip
  sourceManager = sourceManager~string~strip
  if inboundPrincipal = "" then inboundPrincipal = adminPrincipal
  lifecycle = lifecycle~string~translate
  if channelName = "" | sourceManager = "" then return .QueueOperationResult~failure("INVALID_RECEIVER_CHANNEL_DEFINITION")
  if receiverChannels~hasIndex(channelName~translate) then return .QueueOperationResult~failure("RECEIVER_CHANNEL_EXISTS", channelName)
  if lifecycle \= .QueueLifecycle~TEMPORARY & lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("INVALID_LIFECYCLE", lifecycle)
  if lifecycle = .QueueLifecycle~PERMANENT & queueManager~durableStore == .nil then return .QueueOperationResult~failure("PERSISTENCE_UNAVAILABLE")
  channel = .QueueReceiverChannel~new(channelName, lifecycle, sourceManager, inboundPrincipal, authority)
  guard on
  receiverChannels[channelName~translate] = channel
  if lifecycle = .QueueLifecycle~PERMANENT then ignore = queueManager~durableStore~appendJournal("RCDEFINE", .array~of(channelName, lifecycle, sourceManager, inboundPrincipal, channel~createdAt))
  guard off
  return .QueueOperationResult~success(channel)

::method deleteReceiverChannel
  expose receiverChannels queueManager
  use arg channelName, principal = ""
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "receiver channel administration")
  channel = self~receiverChannel(channelName)
  if channel == .nil then return .QueueOperationResult~failure("RECEIVER_CHANNEL_NOT_FOUND", channelName)
  guard on
  receiverChannels~remove(channel~channelName~translate)
  if channel~lifecycle = .QueueLifecycle~PERMANENT & queueManager~durableStore \== .nil then ignore = queueManager~durableStore~appendJournal("RCDELETE", .array~of(channel~channelName))
  guard off
  return .QueueOperationResult~success(channel)

::method setSenderState private
  expose queueManager authority
  use arg channelName, newState, principal
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "channel administration")
  channel = self~senderChannel(channelName)
  if channel == .nil then return .QueueOperationResult~failure("CHANNEL_NOT_FOUND", channelName)
  guard on
  if \channel~setStateInternal(newState, authority) then do
    guard off
    return .QueueOperationResult~failure("INVALID_CHANNEL_STATE", newState)
  end
  if channel~lifecycle = .QueueLifecycle~PERMANENT & queueManager~durableStore \== .nil & newState \= .QueueChannelState~RETRYING then ignore = queueManager~durableStore~appendJournal("CHSTATE", .array~of(channel~channelName, newState))
  guard off
  return .QueueOperationResult~success(channel)

::method startSenderChannel
  use arg channelName, principal = ""
  return self~setSenderState(channelName, .QueueChannelState~RUNNING, principal)

::method stopSenderChannel
  use arg channelName, principal = ""
  return self~setSenderState(channelName, .QueueChannelState~STOPPED, principal)

::method pauseSenderChannel
  use arg channelName, principal = ""
  return self~setSenderState(channelName, .QueueChannelState~PAUSED, principal)

::method setReceiverState private
  expose queueManager authority
  use arg channelName, newState, principal
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "receiver channel administration")
  channel = self~receiverChannel(channelName)
  if channel == .nil then return .QueueOperationResult~failure("RECEIVER_CHANNEL_NOT_FOUND", channelName)
  guard on
  if \channel~setStateInternal(newState, authority) then do
    guard off
    return .QueueOperationResult~failure("INVALID_CHANNEL_STATE", newState)
  end
  if channel~lifecycle = .QueueLifecycle~PERMANENT & queueManager~durableStore \== .nil then ignore = queueManager~durableStore~appendJournal("RCSTATE", .array~of(channel~channelName, newState))
  guard off
  return .QueueOperationResult~success(channel)

::method startReceiverChannel
  use arg channelName, principal = ""
  return self~setReceiverState(channelName, .QueueChannelState~RUNNING, principal)

::method stopReceiverChannel
  use arg channelName, principal = ""
  return self~setReceiverState(channelName, .QueueChannelState~STOPPED, principal)

::method pauseReceiverChannel
  use arg channelName, principal = ""
  return self~setReceiverState(channelName, .QueueChannelState~PAUSED, principal)

::method defineRemoteQueue
  expose remoteQueues queueManager authority adminPrincipal
  use arg aliasName, remoteQueue, remoteManager, transmissionQueue, channelName, securityDomain = "", lifecycle = "TEMPORARY", owner = "", principal = ""
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "remote queue administration")
  aliasName = aliasName~string~strip
  remoteQueue = remoteQueue~string~strip
  remoteManager = remoteManager~string~strip
  transmissionQueue = transmissionQueue~string~strip
  channelName = channelName~string~strip
  lifecycle = lifecycle~string~translate
  if owner = "" then owner = principal
  if owner = "" then owner = adminPrincipal
  if aliasName = "" | remoteQueue = "" | remoteManager = "" | transmissionQueue = "" | channelName = "" then return .QueueOperationResult~failure("INVALID_REMOTE_QUEUE_DEFINITION")
  if remoteQueues~hasIndex(aliasName~translate) then return .QueueOperationResult~failure("REMOTE_QUEUE_EXISTS", aliasName)
  channel = self~senderChannel(channelName)
  if channel == .nil then return .QueueOperationResult~failure("CHANNEL_NOT_FOUND", channelName)
  if channel~remoteManager \= remoteManager then return .QueueOperationResult~failure("REMOTE_MANAGER_MISMATCH", remoteManager)
  if channel~transmissionQueue \= transmissionQueue then return .QueueOperationResult~failure("TRANSMISSION_QUEUE_MISMATCH", transmissionQueue)
  xmit = queueManager~queue(transmissionQueue)
  if xmit == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", transmissionQueue)
  if securityDomain = "" then securityDomain = xmit~securityDomain
  securityDomain = securityDomain~string
  if xmit~securityDomain \= securityDomain then return .QueueOperationResult~failure("SECURITY_DOMAIN_MISMATCH", securityDomain || " != " || xmit~securityDomain)
  if lifecycle \= .QueueLifecycle~TEMPORARY & lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("INVALID_LIFECYCLE", lifecycle)
  if lifecycle = .QueueLifecycle~PERMANENT then do
    if channel~lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("PERMANENT_REMOTE_QUEUE_REQUIRES_PERMANENT_CHANNEL", channelName)
    if xmit~lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("PERMANENT_REMOTE_QUEUE_REQUIRES_PERMANENT_XMITQ", transmissionQueue)
  end
  definition = .QueueRemoteQueueDefinition~new(aliasName, lifecycle, remoteQueue, remoteManager, transmissionQueue, channelName, securityDomain, owner, authority)
  guard on
  remoteQueues[aliasName~translate] = definition
  if lifecycle = .QueueLifecycle~PERMANENT then ignore = queueManager~durableStore~appendJournal("RQDEFINE", .array~of(aliasName, lifecycle, remoteQueue, remoteManager, transmissionQueue, channelName, securityDomain, owner, definition~createdAt))
  guard off
  return .QueueOperationResult~success(definition)

::method deleteRemoteQueue
  expose remoteQueues queueManager
  use arg aliasName, principal = ""
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "remote queue administration")
  definition = self~remoteQueue(aliasName)
  if definition == .nil then return .QueueOperationResult~failure("REMOTE_QUEUE_NOT_FOUND", aliasName)
  guard on
  remoteQueues~remove(definition~aliasName~translate)
  if definition~lifecycle = .QueueLifecycle~PERMANENT & queueManager~durableStore \== .nil then ignore = queueManager~durableStore~appendJournal("RQDELETE", .array~of(definition~aliasName))
  guard off
  return .QueueOperationResult~success(definition)

::method grantRemotePut
  expose authority queueManager
  use arg aliasName, grantee, principal = ""
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "remote queue administration")
  definition = self~remoteQueue(aliasName)
  if definition == .nil then return .QueueOperationResult~failure("REMOTE_QUEUE_NOT_FOUND", aliasName)
  guard on
  ignore = definition~allowInternal(grantee, .QueueAccess~PUT, authority)
  if definition~lifecycle = .QueueLifecycle~PERMANENT & queueManager~durableStore \== .nil then ignore = queueManager~durableStore~appendJournal("RQALLOW", .array~of(definition~aliasName, grantee, .QueueAccess~PUT))
  guard off
  return .QueueOperationResult~success(definition)

::method revokeRemotePut
  expose authority queueManager
  use arg aliasName, grantee, principal = ""
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "remote queue administration")
  definition = self~remoteQueue(aliasName)
  if definition == .nil then return .QueueOperationResult~failure("REMOTE_QUEUE_NOT_FOUND", aliasName)
  guard on
  ignore = definition~revokeInternal(grantee, .QueueAccess~PUT, authority)
  if definition~lifecycle = .QueueLifecycle~PERMANENT & queueManager~durableStore \== .nil then ignore = queueManager~durableStore~appendJournal("RQREVOKE", .array~of(definition~aliasName, grantee, .QueueAccess~PUT))
  guard off
  return .QueueOperationResult~success(definition)

::method put
  expose queueManager idGenerator authority managerName
  use arg queueOrAlias, payload, options = .nil, principal = ""
  definition = self~remoteQueue(queueOrAlias)
  if definition == .nil then return queueManager~put(queueOrAlias, payload, options, principal)
  if \definition~allowsInternal(principal, .QueueAccess~PUT, authority) then return .QueueOperationResult~failure("ACCESS_DENIED", definition~aliasName)
  channel = self~senderChannel(definition~channelName)
  if channel == .nil then return .QueueOperationResult~failure("CHANNEL_NOT_FOUND", definition~channelName)
  if options == .nil then options = .table~new
  priority = self~option(options, "priority", 0)
  persistent = self~truth(self~option(options, "persistent", .false))
  routingKey = self~option(options, "routingKey", "")
  correlationId = self~option(options, "correlationId", "")
  replyTo = self~option(options, "replyTo", "")
  headers = self~option(options, "headers", .table~new)
  securityDomain = self~option(options, "securityDomain", definition~securityDomain)
  expirySeconds = self~option(options, "expirySeconds", 0)
  if \datatype(expirySeconds, "N") | expirySeconds < 0 then return .QueueOperationResult~failure("INVALID_EXPIRY", expirySeconds)
  if securityDomain \= definition~securityDomain then return .QueueOperationResult~failure("SECURITY_DOMAIN_MISMATCH", securityDomain || " != " || definition~securityDomain)
  if expirySeconds = 0 then expiryTick = 0
  else expiryTick = queueManager~timeSource~addSeconds(queueManager~timeSource~nowTick, expirySeconds)
  transferId = idGenerator~next
  envelope = .QueueTransmissionEnvelope~new(transferId, managerName, definition~aliasName, transferId, definition~remoteManager, definition~remoteQueue, payload, headers~copy, priority, persistent, securityDomain, routingKey, correlationId, replyTo, expiryTick)
  xmitOptions = .table~new
  xmitOptions["priority"] = priority
  xmitOptions["persistent"] = persistent
  xmitOptions["securityDomain"] = securityDomain
  xmitOptions["expirySeconds"] = expirySeconds
  xmitResult = queueManager~put(definition~transmissionQueue, envelope, xmitOptions, channel~localPrincipal)
  if \xmitResult~ok then return xmitResult
  return .QueueOperationResult~success(envelope, "queued for transmission;transferId=" || transferId, xmitResult~triggerFailures)

::method pump
  expose queueManager transport authority
  use arg channelName, maxMessages = 0, principal = ""
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "channel pump")
  channel = self~senderChannel(channelName)
  if channel == .nil then return .QueueOperationResult~failure("CHANNEL_NOT_FOUND", channelName)
  if \datatype(maxMessages, "W") | maxMessages < 0 then return .QueueOperationResult~failure("INVALID_MAX_MESSAGES", maxMessages)
  guard on
  if channel~state = .QueueChannelState~STOPPED | channel~state = .QueueChannelState~PAUSED then do
    guard off
    return .QueueOperationResult~failure("CHANNEL_NOT_RUNNING", channel~state)
  end
  sent = 0
  do forever
    if maxMessages > 0 & sent >= maxMessages then leave
    claimResult = queueManager~claim(channel~transmissionQueue, channel~localPrincipal)
    if \claimResult~ok then do
      if claimResult~code = "QUEUE_EMPTY" then leave
      ignore = channel~noteFailureInternal(claimResult~code || ":" || claimResult~detail, authority)
      stateNow = channel~state
      if stateNow = .QueueChannelState~STOPPED then self~persistSenderRuntimeStop(channel)
      guard off
      return .QueueOperationResult~failure("CHANNEL_CLAIM_FAILED", claimResult~code || ":" || claimResult~detail, channel)
    end
    package = claimResult~value
    envelope = package~payload
    if envelope == .nil | \envelope~hasMethod("queuePersistentType") then do
      releaseResult = queueManager~release(channel~transmissionQueue, package~packageId, package~claimToken, channel~localPrincipal, "invalid transmission envelope")
      ignore = channel~noteFailureInternal("INVALID_TRANSMISSION_ENVELOPE", authority)
      stateNow = channel~state
      if stateNow = .QueueChannelState~STOPPED then self~persistSenderRuntimeStop(channel)
      guard off
      return .QueueOperationResult~failure("INVALID_TRANSMISSION_ENVELOPE", package~packageId, channel)
    end
    if envelope~queuePersistentType \= .QueueTransmissionEnvelope~PERSISTENT_TYPE then do
      releaseResult = queueManager~release(channel~transmissionQueue, package~packageId, package~claimToken, channel~localPrincipal, "invalid transmission envelope type")
      ignore = channel~noteFailureInternal("INVALID_TRANSMISSION_ENVELOPE", authority)
      stateNow = channel~state
      if stateNow = .QueueChannelState~STOPPED then self~persistSenderRuntimeStop(channel)
      guard off
      return .QueueOperationResult~failure("INVALID_TRANSMISSION_ENVELOPE", package~packageId, channel)
    end
    ignore = channel~noteAttemptInternal(authority)
    delivery = transport~deliver(channel~remoteManager, channel~remoteChannel, envelope, channel~remotePrincipal)
    if \delivery~ok then do
      releaseResult = queueManager~release(channel~transmissionQueue, package~packageId, package~claimToken, channel~localPrincipal, "channel retry:" || delivery~code)
      ignore = channel~noteFailureInternal(delivery~code || ":" || delivery~detail, authority)
      stateNow = channel~state
      if stateNow = .QueueChannelState~STOPPED then self~persistSenderRuntimeStop(channel)
      guard off
      return .QueueOperationResult~failure("CHANNEL_DELIVERY_FAILED", delivery~code || ":" || delivery~detail, channel)
    end
    ackResult = queueManager~ack(channel~transmissionQueue, package~packageId, package~claimToken, channel~localPrincipal)
    if \ackResult~ok then do
      ignore = channel~noteFailureInternal("LOCAL_ACK_FAILED:" || ackResult~code, authority)
      stateNow = channel~state
      if stateNow = .QueueChannelState~STOPPED then self~persistSenderRuntimeStop(channel)
      guard off
      return .QueueOperationResult~failure("CHANNEL_ACK_FAILED", ackResult~code || ":" || ackResult~detail, channel)
    end
    receipt = delivery~value
    wasDuplicate = .false
    if receipt \== .nil then do
      if receipt~hasMethod("duplicate") then wasDuplicate = receipt~duplicate
    end
    ignore = channel~noteSuccessInternal(wasDuplicate, authority)
    sent += 1
  end
  guard off
  return .QueueOperationResult~success(channel, "sent=" || sent || ";state=" || channel~state)

::method receiveEnvelope
  expose managerName queueManager authority
  use arg envelope, receiverChannelName, principal
  channel = self~receiverChannel(receiverChannelName)
  if channel == .nil then return .QueueOperationResult~failure("RECEIVER_CHANNEL_NOT_FOUND", receiverChannelName)
  if channel~state \= .QueueChannelState~RUNNING then return .QueueOperationResult~failure("RECEIVER_CHANNEL_NOT_RUNNING", channel~state)
  if envelope == .nil | \envelope~hasMethod("queuePersistentType") then return .QueueOperationResult~failure("INVALID_TRANSMISSION_ENVELOPE")
  if envelope~queuePersistentType \= .QueueTransmissionEnvelope~PERSISTENT_TYPE then return .QueueOperationResult~failure("INVALID_TRANSMISSION_ENVELOPE")
  if envelope~destinationManager \= managerName then do
    ignore = channel~noteRejectInternal("DESTINATION_MANAGER_MISMATCH", authority)
    return .QueueOperationResult~failure("DESTINATION_MANAGER_MISMATCH", envelope~destinationManager)
  end
  if envelope~sourceManager \= channel~sourceManager then do
    ignore = channel~noteRejectInternal("SOURCE_MANAGER_MISMATCH", authority)
    return .QueueOperationResult~failure("SOURCE_MANAGER_MISMATCH", envelope~sourceManager)
  end
  if principal~string \= channel~inboundPrincipal then do
    ignore = channel~noteRejectInternal("CHANNEL_PRINCIPAL_MISMATCH", authority)
    return .QueueOperationResult~failure("CHANNEL_PRINCIPAL_MISMATCH", principal)
  end
  options = .table~new
  options["priority"] = envelope~priority
  options["persistent"] = envelope~persistent
  options["securityDomain"] = envelope~securityDomain
  options["routingKey"] = envelope~routingKey
  options["correlationId"] = envelope~correlationId
  options["replyTo"] = envelope~replyTo
  options["headers"] = envelope~headers
  options["expiryTick"] = envelope~expiryTick
  options["sourceManager"] = envelope~sourceManager
  options["sourceQueue"] = envelope~sourceQueue
  options["sourcePackageId"] = envelope~sourcePackageId
  acceptResult = queueManager~acceptTransfer(envelope~transferId, envelope~destinationQueue, envelope~payload, options, principal)
  if acceptResult~ok then do
    receipt = acceptResult~value
    wasDuplicate = .false
    if receipt \== .nil then wasDuplicate = receipt~duplicate
    ignore = channel~noteReceiveInternal(wasDuplicate, authority)
  end
  else ignore = channel~noteRejectInternal(acceptResult~code || ":" || acceptResult~detail, authority)
  return acceptResult

::method persistSenderRuntimeStop private
  expose queueManager
  use arg channel
  if channel~lifecycle = .QueueLifecycle~PERMANENT & queueManager~durableStore \== .nil then ignore = queueManager~durableStore~appendJournal("CHSTATE", .array~of(channel~channelName, .QueueChannelState~STOPPED))
  return .true

::method authorisedSenderChannels
  use arg principal
  if \self~isAdmin(principal) then return .array~new
  return self~senderChannels

::method authorisedReceiverChannels
  use arg principal
  if \self~isAdmin(principal) then return .array~new
  return self~receiverChannels

::method authorisedRemoteQueues
  expose authority
  use arg principal
  rows = .array~new
  do definition over self~remoteQueues
    if self~isAdmin(principal) | definition~allowsInternal(principal, .QueueAccess~PUT, authority) then rows~append(definition)
  end
  return rows

::method remoteGrantRows
  expose authority
  use arg aliasName, principal = ""
  if \self~isAdmin(principal) then return .array~new
  definition = self~remoteQueue(aliasName)
  if definition == .nil then return .array~new
  return definition~grantRowsInternal(authority)

::method recoverDefinitions private
  expose queueManager senderChannels receiverChannels remoteQueues authority adminPrincipal
  if queueManager~durableStore == .nil then return .true
  rows = queueManager~durableStore~readJournal
  do row over rows
    if row~items = 0 then iterate
    tag = row[1]
    select
      when tag = "CHDEFINE" then do
        if row~items < 10 then iterate
        senderChannels[row[2]~translate] = .QueueSenderChannel~new(row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9], authority, row[10], .QueueChannelState~STOPPED)
      end
      when tag = "CHDELETE" then do
        if row~items >= 2 then senderChannels~remove(row[2]~translate)
      end
      when tag = "CHSTATE" then do
        if row~items >= 3 then do
          channel = senderChannels[row[2]~translate]
          if channel \== .nil then ignore = channel~setStateInternal(row[3], authority)
        end
      end
      when tag = "RCDEFINE" then do
        if row~items < 6 then iterate
        receiverChannels[row[2]~translate] = .QueueReceiverChannel~new(row[2], row[3], row[4], row[5], authority, row[6], .QueueChannelState~STOPPED)
      end
      when tag = "RCDELETE" then do
        if row~items >= 2 then receiverChannels~remove(row[2]~translate)
      end
      when tag = "RCSTATE" then do
        if row~items >= 3 then do
          channel = receiverChannels[row[2]~translate]
          if channel \== .nil then ignore = channel~setStateInternal(row[3], authority)
        end
      end
      when tag = "RQDEFINE" then do
        if row~items < 10 then iterate
        remoteQueues[row[2]~translate] = .QueueRemoteQueueDefinition~new(row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9], authority, row[10])
      end
      when tag = "RQDELETE" then do
        if row~items >= 2 then remoteQueues~remove(row[2]~translate)
      end
      when tag = "RQALLOW" then do
        if row~items >= 4 then do
          definition = remoteQueues[row[2]~translate]
          if definition \== .nil then ignore = definition~allowInternal(row[3], row[4], authority)
        end
      end
      when tag = "RQREVOKE" then do
        if row~items >= 4 then do
          definition = remoteQueues[row[2]~translate]
          if definition \== .nil then ignore = definition~revokeInternal(row[3], row[4], authority)
        end
      end
      otherwise nop
    end
  end
  return .true

::method isAdmin private
  expose adminPrincipal
  use arg principal
  if principal = "" then principal = adminPrincipal
  return principal~string = adminPrincipal

::method option private
  use arg options, key, defaultValue
  value = options[key]
  if value == .nil then return defaultValue
  return value

::method truth private
  use arg value
  if value == .true then return .true
  text = value~string~translate
  return text = "1" | text = "TRUE" | text = "YES" | text = "ON"

::requires "ObjectQueueFabric.cls"
::requires "AlchemyObject.cls"
