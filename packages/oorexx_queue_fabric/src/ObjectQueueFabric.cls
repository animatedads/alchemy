/*
 * ObjectQueueFabric v0.9-dev6
 *
 * First-class ooRexx object queues with MQ-like wiring semantics:
 * named queues, secure access, persistent/temporary lifecycle, work-package
 * objects, claim/ack/nack, triggers, routing, durable journal and traffic log.
 *
 * Payloads remain ooRexx objects.  Persistent payloads are encoded only at the
 * persistence boundary by QueueGraphPayloadCodec or another supplied codec.
 */

::class QueueFabricBuild public
::constant VERSION "0.9"
::constant API "queue.fabric/0.9"

/* Development-package identity is deliberately distinct from the aggregate
 * queue.fabric/0.9 API identity. Persistent and wire format identities remain
 * independently versioned and unchanged from the accepted v0.8.2 line. */
::class QueueFabricDevelopmentBuild public
::constant VERSION "0.9-dev6"
::constant ALCHEMY_STANDARD "ALCHEMY-HOUSE-OBJECT-0.5"

::class QueueFabricAlchemyMetadata public
::method standard class
  use strict arg purpose, component, limitations = .nil
  if limitations == .nil then limitations = .array~new
  meta = .directory~new
  meta["purpose"] = purpose
  meta["package_version"] = .QueueFabricDevelopmentBuild~VERSION
  meta["authorship"] = .array~of("Alchemy ooRexx Queue Fabric")
  meta["standards"] = .array~of(.QueueFabricDevelopmentBuild~ALCHEMY_STANDARD, .QueueFabricBuild~API, component)
  meta["design_limitations"] = limitations
  return meta

::class QueueLifecycle public
::constant TEMPORARY "TEMPORARY"
::constant PERMANENT "PERMANENT"

::class QueueRecoveryMode public
::constant STRICT "STRICT"
::constant REPAIR_TORN_TAIL "REPAIR_TORN_TAIL"

::class QueueState public
::constant ACTIVE "ACTIVE"
::constant DISABLED "DISABLED"

::class QueuePackageState public
::constant READY "READY"
::constant INFLIGHT "INFLIGHT"
::constant ACKED "ACKED"

::class QueueUnitOfWorkState public
::constant ACTIVE "ACTIVE"
::constant COMMITTED "COMMITTED"
::constant ROLLEDBACK "ROLLEDBACK"

::class QueueAccess public
::constant PUT "PUT"
::constant GET "GET"
::constant BROWSE "BROWSE"
::constant MANAGE "MANAGE"

::class QueueRouteMode public
::constant COPY "COPY"
::constant REDIRECT "REDIRECT"

::class QueueTriggerKind public
::constant PUT "PUT"
::constant GET "GET"
::constant CLAIM "CLAIM"
::constant ACK "ACK"
::constant NACK "NACK"
::constant RELEASE "RELEASE"
::constant EXPIRE "EXPIRE"
::constant BACKOUT "BACKOUT"
::constant DEAD_LETTER "DEAD_LETTER"
::constant UOW_COMMIT "UOW_COMMIT"
::constant UOW_ROLLBACK "UOW_ROLLBACK"
::constant DEPTH_AT_LEAST "DEPTH_AT_LEAST"
::constant EMPTY "EMPTY"
::constant NONEMPTY "NONEMPTY"

::class QueueOperationResult public
::attribute ok get
::attribute code get
::attribute value get
::attribute detail get
::attribute triggerFailures get

::method init
  expose ok code value detail triggerFailures
  use arg ok = .false, code = "FAILED", value = .nil, detail = "", triggerFailures = .nil
  if triggerFailures == .nil then triggerFailures = .array~new

::method success class
  use arg value = .nil, detail = "", triggerFailures = .nil
  return self~new(.true, "OK", value, detail, triggerFailures)

::method failure class
  use arg code, detail = "", value = .nil
  return self~new(.false, code, value, detail)

::class QueueClock public
::method timestamp class
  return .DateTime~new~string

/* time('F') is a stable high-resolution clock value, but its magnitude is
 * larger than the default Rexx NUMERIC DIGITS setting.  All arithmetic and
 * comparison therefore lives behind this object and explicitly raises
 * precision rather than leaking unsafe arithmetic into queue code. */
::class QueueTimeSource public
::method nowTick
  numeric digits 30
  return time("F")

::method addSeconds
  use arg tick, seconds
  numeric digits 30
  return tick + (seconds * 1000000)

::method isExpired
  use arg expiryTick
  if expiryTick == .nil | expiryTick = "" | expiryTick = 0 then return .false
  numeric digits 30
  return time("F") >= expiryTick

::method secondsUntil
  use arg expiryTick
  if expiryTick == .nil | expiryTick = "" | expiryTick = 0 then return 0
  numeric digits 30
  remaining = expiryTick - self~nowTick
  if remaining <= 0 then return 0
  return remaining / 1000000

::class QueueManagerAuthority
::method init
  nop

::class QueueIdGenerator public
::attribute prefix get
::method init
  expose prefix counter
  use arg prefix = "id"
  counter = 0
::method next
  expose prefix counter
  guard on
  counter += 1
  stamp = .DateTime~new~microseconds
  return prefix || "-" || stamp || "-" || counter

::class QueueAccessPolicy public
::attribute owner get

::method init
  expose owner grants
  use arg owner
  owner = owner~string
  grants = .table~new

::method allows
  expose owner grants
  use arg principal, action
  principal = principal~string
  action = action~string~translate
  if principal = owner then return .true
  return grants~hasIndex(principal || "|" || action)

::method allow
  expose grants
  use arg principal, action
  principal = principal~string
  action = action~string~translate
  grants[principal || "|" || action] = .true
  return .true

::method revoke
  expose grants
  use arg principal, action
  grants~remove(principal~string || "|" || action~string~translate)
  return .true

::method grantRows
  expose grants
  rows = .array~new
  supplier = grants~supplier
  do while supplier~available
    key = supplier~index
    splitAt = key~pos("|")
    row = .array~of(key~substr(1, splitAt - 1), key~substr(splitAt + 1))
    rows~append(row)
    supplier~next
  end
  return rows

::class QueueEndpoint public
::attribute queueId get
::attribute name get
::attribute lifecycle get
::attribute securityDomain get
::attribute maxDepth get
::attribute owner get
::attribute createdAt get
::attribute state get
::attribute backoutThreshold get
::attribute backoutQueue get
::attribute expiringDepth get
::attribute earliestExpiryTick get

::method init
  expose queueId name lifecycle securityDomain maxDepth owner createdAt state accessPolicy packages managerAuthority backoutThreshold backoutQueue expiringDepth earliestExpiryTick
  use arg queueId, name, lifecycle, securityDomain, maxDepth, owner, createdAt = "", authorityCandidate, initialBackoutThreshold = 0, initialBackoutQueue = ""
  queueId = queueId~string
  name = name~string
  lifecycle = lifecycle~string~translate
  securityDomain = securityDomain~string
  maxDepth = maxDepth
  owner = owner~string
  if createdAt = "" then createdAt = .QueueClock~timestamp
  createdAt = createdAt
  state = .QueueState~ACTIVE
  accessPolicy = .QueueAccessPolicy~new(owner)
  packages = .array~new
  managerAuthority = authorityCandidate
  backoutThreshold = initialBackoutThreshold
  backoutQueue = initialBackoutQueue~string
  expiringDepth = 0
  earliestExpiryTick = 0

::method allows
  expose accessPolicy managerAuthority
  use arg principal, action, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  return accessPolicy~allows(principal, action)

::method allowAccess
  expose accessPolicy managerAuthority
  use arg principal, action, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  return accessPolicy~allow(principal, action)

::method revokeAccess
  expose accessPolicy managerAuthority
  use arg principal, action, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  return accessPolicy~revoke(principal, action)

::method packagesSnapshot
  expose packages managerAuthority
  use arg authorityCandidate
  if authorityCandidate \== managerAuthority then return .array~new
  copied = .array~new
  do package over packages
    copied~append(package)
  end
  return copied

::method readyDepth
  expose packages
  count = 0
  do package over packages
    if package~state = .QueuePackageState~READY then count += 1
  end
  return count

::method inflightDepth
  expose packages
  count = 0
  do package over packages
    if package~state = .QueuePackageState~INFLIGHT then count += 1
  end
  return count

::method totalDepth
  expose packages
  return packages~items

::method canAccept
  expose maxDepth state
  if state \= .QueueState~ACTIVE then return .false
  if maxDepth = 0 then return .true
  return self~totalDepth < maxDepth

::method appendPackage
  expose packages managerAuthority expiringDepth earliestExpiryTick
  use arg package, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  packages~append(package)
  if package~expiryTick \= 0 then do
    expiringDepth += 1
    numeric digits 30
    if earliestExpiryTick = 0 | package~expiryTick < earliestExpiryTick then earliestExpiryTick = package~expiryTick
  end
  return .true

::method findPackage
  expose packages managerAuthority
  use arg packageId, authorityCandidate
  if authorityCandidate \== managerAuthority then return .nil
  do package over packages
    if package~packageId = packageId then return package
  end
  return .nil

::method removePackage
  expose packages managerAuthority expiringDepth earliestExpiryTick
  use arg packageId, authorityCandidate
  if authorityCandidate \== managerAuthority then return .nil
  removed = .nil
  kept = .array~new
  do package over packages
    if removed == .nil then do
      if package~packageId = packageId then do
        removed = package
        iterate
      end
    end
    kept~append(package)
  end
  packages = kept
  if removed \== .nil then do
    if removed~expiryTick \= 0 then do
      removedExpiry = removed~expiryTick
      expiringDepth -= 1
      if expiringDepth = 0 then earliestExpiryTick = 0
      else if removedExpiry = earliestExpiryTick then do
        numeric digits 30
        earliestExpiryTick = 0
        do remainingPackage over packages
          if remainingPackage~expiryTick = 0 then iterate
          if earliestExpiryTick = 0 | remainingPackage~expiryTick < earliestExpiryTick then earliestExpiryTick = remainingPackage~expiryTick
        end
      end
    end
  end
  return removed

::method nextReadyPackage
  expose packages managerAuthority
  use arg authorityCandidate
  if authorityCandidate \== managerAuthority then return .nil
  chosen = .nil
  do package over packages
    if package~state \= .QueuePackageState~READY then iterate
    if chosen == .nil then chosen = package
    else do
      if package~priority > chosen~priority then chosen = package
      else if package~priority = chosen~priority then do
        if package~sequence < chosen~sequence then chosen = package
      end
    end
  end
  return chosen

::method setStateInternal
  expose state managerAuthority
  use arg newState, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  state = newState~string~translate
  return .true

::method configureBackoutInternal
  expose backoutThreshold backoutQueue managerAuthority
  use arg threshold, queueName, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  backoutThreshold = threshold
  backoutQueue = queueName~string
  return .true

::class QueueWorkPackage public
::attribute packageId get
::attribute payload get
::attribute headers get
::attribute priority get
::attribute persistent get
::attribute securityDomain get
::attribute routingKey get
::attribute correlationId get
::attribute replyTo get
::attribute requestedQueue get
::attribute currentQueue get
::attribute parentPackageId get
::attribute createdAt get
::attribute state get
::attribute claimedBy get
::attribute claimToken get
::attribute claimedAt get
::attribute deliveryCount get
::attribute backoutCount get
::attribute expiryTick get
::attribute deadLetterReason get
::attribute deadLetterSourceQueue get
::attribute sequence get

::method init
  expose packageId payload headers priority persistent securityDomain routingKey correlationId replyTo requestedQueue currentQueue parentPackageId createdAt state claimedBy claimToken claimedAt deliveryCount backoutCount expiryTick deadLetterReason deadLetterSourceQueue sequence managerAuthority
  use arg packageId, payload, headers, priority, persistent, securityDomain, routingKey, correlationId, replyTo, requestedQueue, currentQueue, parentPackageId, createdAt, packageSequence, authorityCandidate, initialExpiryTick = 0, initialBackoutCount = 0, initialDeadLetterReason = "", initialDeadLetterSourceQueue = ""
  packageId = packageId~string
  payload = payload
  if headers == .nil then headers = .table~new
  headers = headers
  priority = priority
  persistent = persistent
  securityDomain = securityDomain~string
  routingKey = routingKey~string
  correlationId = correlationId~string
  replyTo = replyTo~string
  requestedQueue = requestedQueue~string
  currentQueue = currentQueue~string
  parentPackageId = parentPackageId~string
  if createdAt = "" then createdAt = .QueueClock~timestamp
  createdAt = createdAt
  state = .QueuePackageState~READY
  claimedBy = ""
  claimToken = ""
  claimedAt = ""
  deliveryCount = 0
  backoutCount = initialBackoutCount
  expiryTick = initialExpiryTick
  deadLetterReason = initialDeadLetterReason~string
  deadLetterSourceQueue = initialDeadLetterSourceQueue~string
  sequence = packageSequence
  managerAuthority = authorityCandidate

::method payloadClass
  expose payload
  if payload == .nil then return "NIL"
  return payload~class~id

::method markClaimed
  expose state claimedBy claimToken claimedAt deliveryCount managerAuthority
  use arg principal, token, timestamp, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  state = .QueuePackageState~INFLIGHT
  claimedBy = principal~string
  claimToken = token~string
  claimedAt = timestamp~string
  deliveryCount += 1
  return .true

::method markReady
  expose state claimedBy claimToken claimedAt backoutCount managerAuthority
  use arg authorityCandidate, incrementBackout = .false
  if authorityCandidate \== managerAuthority then return .false
  state = .QueuePackageState~READY
  claimedBy = ""
  claimToken = ""
  claimedAt = ""
  if incrementBackout then backoutCount += 1
  return .true

::method markAcked
  expose state managerAuthority
  use arg authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  state = .QueuePackageState~ACKED
  return .true

::method restoreDeliveryState
  expose state claimedBy claimToken claimedAt deliveryCount currentQueue managerAuthority
  use arg restoredState, restoredClaimedBy, restoredClaimToken, restoredClaimedAt, restoredDeliveryCount, restoredCurrentQueue, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  state = restoredState~string
  claimedBy = restoredClaimedBy~string
  claimToken = restoredClaimToken~string
  claimedAt = restoredClaimedAt~string
  deliveryCount = restoredDeliveryCount
  currentQueue = restoredCurrentQueue~string
  return .true

::method restoreExtendedState
  expose backoutCount expiryTick deadLetterReason deadLetterSourceQueue managerAuthority
  use arg restoredBackoutCount, restoredExpiryTick, restoredDeadLetterReason, restoredDeadLetterSourceQueue, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  backoutCount = restoredBackoutCount
  expiryTick = restoredExpiryTick
  deadLetterReason = restoredDeadLetterReason~string
  deadLetterSourceQueue = restoredDeadLetterSourceQueue~string
  return .true

::method moveToQueueInternal
  expose currentQueue state claimedBy claimToken claimedAt deadLetterReason deadLetterSourceQueue expiryTick managerAuthority
  use arg destinationQueue, reason, sourceQueue, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  currentQueue = destinationQueue~string
  state = .QueuePackageState~READY
  claimedBy = ""
  claimToken = ""
  claimedAt = ""
  deadLetterReason = reason~string
  deadLetterSourceQueue = sourceQueue~string
  expiryTick = 0
  return .true

::method isExpired
  expose expiryTick
  use arg timeSource
  return timeSource~isExpired(expiryTick)

::method copyForRoute
  expose payload headers priority persistent securityDomain routingKey correlationId replyTo requestedQueue packageId createdAt sequence managerAuthority expiryTick backoutCount deadLetterReason deadLetterSourceQueue
  use arg newPackageId, destinationQueue, newSequence, authorityCandidate
  if authorityCandidate \== managerAuthority then return .nil
  copiedHeaders = headers~copy
  return .QueueWorkPackage~new(newPackageId, payload, copiedHeaders, priority, persistent, securityDomain, routingKey, correlationId, replyTo, requestedQueue, destinationQueue, packageId, .QueueClock~timestamp, newSequence, managerAuthority, expiryTick, backoutCount, deadLetterReason, deadLetterSourceQueue)

/* ----------------------------------------------------------------------- */
/* Distributed transmission envelope / idempotent receive receipt          */
/* ----------------------------------------------------------------------- */

::class QueueTransmissionEnvelope public
::constant PERSISTENT_TYPE "queue.fabric.transmission-envelope/1"
::attribute transferId get
::attribute sourceManager get
::attribute sourceQueue get
::attribute sourcePackageId get
::attribute destinationManager get
::attribute destinationQueue get
::attribute payload get
::attribute headers get
::attribute priority get
::attribute persistent get
::attribute securityDomain get
::attribute routingKey get
::attribute correlationId get
::attribute replyTo get
::attribute expiryTick get
::attribute createdAt get

::method init
  expose transferId sourceManager sourceQueue sourcePackageId destinationManager destinationQueue payload headers priority persistent securityDomain routingKey correlationId replyTo expiryTick createdAt
  use arg transferId = "", sourceManager = "", sourceQueue = "", sourcePackageId = "", destinationManager = "", destinationQueue = "", payload = .nil, headers = .nil, priority = 0, persistent = .false, securityDomain = "DEFAULT", routingKey = "", correlationId = "", replyTo = "", expiryTick = 0, createdAt = ""
  transferId = transferId~string
  sourceManager = sourceManager~string
  sourceQueue = sourceQueue~string
  sourcePackageId = sourcePackageId~string
  destinationManager = destinationManager~string
  destinationQueue = destinationQueue~string
  payload = payload
  if headers == .nil then headers = .table~new
  headers = headers
  priority = priority
  persistent = persistent
  securityDomain = securityDomain~string
  routingKey = routingKey~string
  correlationId = correlationId~string
  replyTo = replyTo~string
  expiryTick = expiryTick
  if createdAt = "" then createdAt = .QueueClock~timestamp
  createdAt = createdAt~string

::method queuePersistentType
  return .QueueTransmissionEnvelope~PERSISTENT_TYPE

::method queuePersistentState
  expose transferId sourceManager sourceQueue sourcePackageId destinationManager destinationQueue payload headers priority persistent securityDomain routingKey correlationId replyTo expiryTick createdAt
  state = .table~new
  state["transferId"] = transferId
  state["sourceManager"] = sourceManager
  state["sourceQueue"] = sourceQueue
  state["sourcePackageId"] = sourcePackageId
  state["destinationManager"] = destinationManager
  state["destinationQueue"] = destinationQueue
  state["payload"] = payload
  state["headers"] = headers
  state["priority"] = priority~string
  if persistent then state["persistent"] = "1"
  else state["persistent"] = "0"
  state["securityDomain"] = securityDomain
  state["routingKey"] = routingKey
  state["correlationId"] = correlationId
  state["replyTo"] = replyTo
  state["expiryTick"] = expiryTick~string
  state["createdAt"] = createdAt
  return state

::method queueRestoreState
  expose transferId sourceManager sourceQueue sourcePackageId destinationManager destinationQueue payload headers priority persistent securityDomain routingKey correlationId replyTo expiryTick createdAt
  use arg state
  transferId = state["transferId"]~string
  sourceManager = state["sourceManager"]~string
  sourceQueue = state["sourceQueue"]~string
  sourcePackageId = state["sourcePackageId"]~string
  destinationManager = state["destinationManager"]~string
  destinationQueue = state["destinationQueue"]~string
  payload = state["payload"]
  headers = state["headers"]
  priority = state["priority"]
  persistentText = state["persistent"]~string~translate
  persistent = persistentText = "1" | persistentText = "TRUE" | persistentText = "YES" | persistentText = "ON"
  securityDomain = state["securityDomain"]~string
  routingKey = state["routingKey"]~string
  correlationId = state["correlationId"]~string
  replyTo = state["replyTo"]~string
  expiryTick = state["expiryTick"]
  createdAt = state["createdAt"]~string
  return self

::class QueueTransmissionEnvelopeFactory public
::method newBlank
  return .QueueTransmissionEnvelope~new

::class QueueTransferReceipt public
::attribute transferId get
::attribute packageId get
::attribute queueName get
::attribute acceptedAt get
::attribute sourceManager get
::attribute duplicate get

::method init
  expose transferId packageId queueName acceptedAt sourceManager duplicate
  use arg transferId, packageId, queueName, acceptedAt, sourceManager = "", duplicate = .false
  transferId = transferId~string
  packageId = packageId~string
  queueName = queueName~string
  acceptedAt = acceptedAt~string
  sourceManager = sourceManager~string
  duplicate = duplicate

::method asDuplicate
  expose transferId packageId queueName acceptedAt sourceManager
  return .QueueTransferReceipt~new(transferId, packageId, queueName, acceptedAt, sourceManager, .true)

::class QueueUnitOfWork public
::attribute uowId get
::attribute principal get
::attribute state get
::attribute createdAt get
::attribute putCount get
::attribute getCount get

::method init
  expose uowId principal state createdAt stagedPuts reservedGets managerAuthority putCount getCount
  use arg uowId, principal, authorityCandidate
  uowId = uowId~string
  principal = principal~string
  state = .QueueUnitOfWorkState~ACTIVE
  createdAt = .QueueClock~timestamp
  stagedPuts = .array~new
  reservedGets = .array~new
  managerAuthority = authorityCandidate
  putCount = 0
  getCount = 0

::method addPutInternal
  expose stagedPuts state managerAuthority putCount
  use arg queueName, payload, options, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  if state \= .QueueUnitOfWorkState~ACTIVE then return .false
  stagedPuts~append(.array~of(queueName~string, payload, options))
  putCount += 1
  return .true

::method addReservedGetInternal
  expose reservedGets state managerAuthority getCount
  use arg queueName, packageId, claimToken, authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  if state \= .QueueUnitOfWorkState~ACTIVE then return .false
  reservedGets~append(.array~of(queueName~string, packageId~string, claimToken~string))
  getCount += 1
  return .true

::method putEntriesInternal
  expose stagedPuts managerAuthority
  use arg authorityCandidate
  if authorityCandidate \== managerAuthority then return .array~new
  copied = .array~new
  do entry over stagedPuts
    copied~append(entry)
  end
  return copied

::method getEntriesInternal
  expose reservedGets managerAuthority
  use arg authorityCandidate
  if authorityCandidate \== managerAuthority then return .array~new
  copied = .array~new
  do entry over reservedGets
    copied~append(entry)
  end
  return copied

::method markCommittedInternal
  expose state managerAuthority
  use arg authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  if state \= .QueueUnitOfWorkState~ACTIVE then return .false
  state = .QueueUnitOfWorkState~COMMITTED
  return .true

::method markRolledBackInternal
  expose state managerAuthority
  use arg authorityCandidate
  if authorityCandidate \== managerAuthority then return .false
  if state \= .QueueUnitOfWorkState~ACTIVE then return .false
  state = .QueueUnitOfWorkState~ROLLEDBACK
  return .true

::class QueueTriggerEvent public
::attribute eventId get
::attribute queueName get
::attribute eventType get
::attribute beforeDepth get
::attribute afterDepth get
::attribute packageId get
::attribute principal get
::attribute timestamp get

::method init
  expose eventId queueName eventType beforeDepth afterDepth packageId principal timestamp
  use arg eventId, queueName, eventType, beforeDepth, afterDepth, packageId = "", principal = "", timestamp = ""
  eventId = eventId~string
  queueName = queueName~string
  eventType = eventType~string~translate
  beforeDepth = beforeDepth
  afterDepth = afterDepth
  packageId = packageId~string
  principal = principal~string
  if timestamp = "" then timestamp = .QueueClock~timestamp
  timestamp = timestamp

::class QueueDirectTriggerTarget public
::attribute kind get
::attribute persistent get
::attribute description get

::method init
  expose targetObject targetMessage kind persistent description
  use arg targetObject, targetMessage = "onQueueTrigger"
  targetObject = targetObject
  targetMessage = targetMessage~string
  kind = "DIRECT"
  persistent = .false
  description = targetObject~class~id || "~" || targetMessage

::method invoke
  expose targetObject targetMessage
  use arg manager, event
  signal on syntax name triggerError
  callValue = targetObject~send(targetMessage, event)
  signal off syntax
  return .QueueOperationResult~success(callValue, "direct trigger invoked")
triggerError:
  signal off syntax
  return .QueueOperationResult~failure("TRIGGER_FAILED", condition("D"))

::class QueueRegistryTriggerTarget public
::attribute kind get
::attribute persistent get
::attribute environment get
::attribute moduleId get
::attribute message get
::attribute description get

::method init
  expose kind persistent environment moduleId message description
  use arg environment, moduleId, message = "onQueueTrigger"
  environment = environment~string~lower
  moduleId = moduleId~string
  message = message~string
  kind = "REGISTRY"
  persistent = .true
  description = environment || ":" || moduleId || "~" || message

::method invoke
  expose environment moduleId message
  use arg manager, event
  registry = manager~runtimeRegistry
  if registry == .nil then return .QueueOperationResult~failure("RUNTIME_REGISTRY_UNAVAILABLE", environment || ":" || moduleId)
  leaseResult = registry~acquire(environment, moduleId)
  if \leaseResult~ok then return .QueueOperationResult~failure("RUNTIME_TRIGGER_ACQUIRE_FAILED", leaseResult~code || ":" || leaseResult~detail)
  lease = leaseResult~value
  signal on syntax name runtimeTriggerError
  callValue = lease~module~send(message, event)
  signal off syntax
  releaseResult = lease~release
  return .QueueOperationResult~success(callValue, "registry trigger invoked")
runtimeTriggerError:
  signal off syntax
  releaseResult = lease~release
  return .QueueOperationResult~failure("TRIGGER_FAILED", condition("D"))

::class QueueTriggerRegistration public
::attribute triggerId get
::attribute queueName get
::attribute kind get
::attribute threshold get
::attribute target get
::attribute enabled get
::attribute registeredBy get
::attribute registeredAt get

::method init
  expose triggerId queueName kind threshold target enabled registeredBy registeredAt
  use arg triggerId, queueName, kind, threshold, target, registeredBy, registeredAt = ""
  triggerId = triggerId~string
  queueName = queueName~string
  kind = kind~string~translate
  threshold = threshold
  target = target
  enabled = .true
  registeredBy = registeredBy~string
  if registeredAt = "" then registeredAt = .QueueClock~timestamp
  registeredAt = registeredAt

::method matches
  expose kind threshold enabled
  use arg event
  if \enabled then return .false
  select
    when kind = .QueueTriggerKind~DEPTH_AT_LEAST then return event~beforeDepth < threshold & event~afterDepth >= threshold
    when kind = .QueueTriggerKind~EMPTY then return event~beforeDepth > 0 & event~afterDepth = 0
    when kind = .QueueTriggerKind~NONEMPTY then return event~beforeDepth = 0 & event~afterDepth > 0
    otherwise return kind = event~eventType
  end

::class QueueRouteRule public
::attribute routeId get
::attribute sourceQueue get
::attribute routingKey get
::attribute destinationQueue get
::attribute mode get
::attribute priority get
::attribute enabled get
::attribute allowCrossDomain get
::attribute registeredBy get
::attribute registeredAt get

::method init
  expose routeId sourceQueue routingKey destinationQueue mode priority enabled allowCrossDomain registeredBy registeredAt
  use arg routeId, sourceQueue, routingKey, destinationQueue, mode, priority, allowCrossDomain, registeredBy, registeredAt = ""
  routeId = routeId~string
  sourceQueue = sourceQueue~string
  routingKey = routingKey~string
  destinationQueue = destinationQueue~string
  mode = mode~string~translate
  priority = priority
  enabled = .true
  allowCrossDomain = allowCrossDomain
  registeredBy = registeredBy~string
  if registeredAt = "" then registeredAt = .QueueClock~timestamp
  registeredAt = registeredAt

::method matches
  expose enabled routingKey
  use arg wantedKey
  if \enabled then return .false
  if routingKey = "*" then return .true
  return routingKey = wantedKey~string

::class QueueTrafficEvent public
::attribute eventId get
::attribute timestamp get
::attribute eventType get
::attribute queueName get
::attribute packageId get
::attribute principal get
::attribute detail get
::attribute sourceQueue get
::attribute destinationQueue get
::attribute success get

::method init
  expose eventId timestamp eventType queueName packageId principal detail sourceQueue destinationQueue success
  use arg eventId, eventType, queueName, packageId, principal, detail, sourceQueue, destinationQueue, success, timestamp = ""
  eventId = eventId~string
  if timestamp = "" then timestamp = .QueueClock~timestamp
  timestamp = timestamp
  eventType = eventType~string~translate
  queueName = queueName~string
  packageId = packageId~string
  principal = principal~string
  detail = detail~string
  sourceQueue = sourceQueue~string
  destinationQueue = destinationQueue~string
  success = success

/* ----------------------------------------------------------------------- */
/* Persistent payload graph codec                                         */
/* ----------------------------------------------------------------------- */

::class QueuePayloadTypeRegistry public
::method init
  expose factories
  factories = .table~new

::method register
  expose factories
  use arg typeId, factoryObject, blankMessage = "newBlank"
  entry = .array~of(factoryObject, blankMessage~string)
  factories[typeId~string] = entry
  return .true

::method createBlank
  expose factories
  use arg typeId
  entry = factories[typeId~string]
  if entry == .nil then raise syntax 88.900 array("No queue payload factory for type " || typeId)
  return entry[1]~send(entry[2])

::class QueueGraphPayloadCodec public
::attribute typeRegistry get

::method init
  expose typeRegistry
  use arg typeRegistry = .nil
  if typeRegistry == .nil then typeRegistry = .QueuePayloadTypeRegistry~new
  typeRegistry = typeRegistry

::method canEncode
  use arg payload
  signal on syntax name cannotEncode
  encoded = self~encode(payload)
  signal off syntax
  return .true
cannotEncode:
  signal off syntax
  return .false

::method encode
  expose typeRegistry
  use arg payload
  ids = .IdentityTable~new
  nodes = .array~new
  rootToken = self~encodeToken(payload, ids, nodes)
  lines = .array~new
  lines~append("QGRAPH1|" || rootToken)
  do node over nodes
    lines~append(node)
  end
  return self~joinLines(lines)

::method encodeToken private
  use arg value, ids, nodes
  if value == .nil then return "N"
  if value~class == .String then return "S" || c2x(value)

  existing = ids~at(value)
  if existing \== .nil then return "R" || existing
  nodeId = ids~items + 1
  ids~put(nodeId, value)

  classId = value~class~id
  select
    when classId = "Array" then do
      tokens = .array~new
      do i = 1 to value~items
        tokens~append(self~encodeToken(value[i], ids, nodes))
      end
      nodes~append("NODE|" || nodeId || "|A||" || self~join(tokens, ","))
    end
    when classId = "Table" | classId = "IdentityTable" | classId = "Directory" then do
      pairs = .array~new
      supplier = value~supplier
      do while supplier~available
        keyToken = self~encodeToken(supplier~index, ids, nodes)
        valueToken = self~encodeToken(supplier~item, ids, nodes)
        pairs~append(keyToken || "=" || valueToken)
        supplier~next
      end
      nodes~append("NODE|" || nodeId || "|T|" || c2x(classId) || "|" || self~join(pairs, ","))
    end
    otherwise do
      if \value~hasMethod("queuePersistentType") then raise syntax 88.900 array("Payload class is not queue-persistable: " || classId)
      if \value~hasMethod("queuePersistentState") then raise syntax 88.900 array("Payload class lacks queuePersistentState: " || classId)
      typeId = value~queuePersistentType
      state = value~queuePersistentState
      stateToken = self~encodeToken(state, ids, nodes)
      nodes~append("NODE|" || nodeId || "|P|" || c2x(typeId~string) || "|" || stateToken)
    end
  end
  return "R" || nodeId

::method decode
  expose typeRegistry
  use arg encoded
  lines = self~splitLines(encoded)
  if lines~items = 0 then raise syntax 88.900 array("Empty queue graph")
  header = lines[1]
  if \header~startsWith("QGRAPH1|") then raise syntax 88.900 array("Unsupported queue graph format")
  rootToken = header~substr(9)
  descriptions = .table~new
  objects = .table~new

  /* First pass: parse node descriptions and allocate all placeholders. */
  do i = 2 to lines~items
    line = lines[i]
    fields = self~split(line, "|")
    if fields~items < 5 then raise syntax 88.900 array("Malformed queue graph node")
    if fields[1] \= "NODE" then raise syntax 88.900 array("Unknown queue graph record")
    nodeId = fields[2]
    kind = fields[3]
    typeHex = fields[4]
    data = fields[5]
    descriptions[nodeId] = .array~of(kind, typeHex, data)
    select
      when kind = "A" then objects[nodeId] = .array~new
      when kind = "T" then do
        classId = x2c(typeHex)
        if classId = "Directory" then objects[nodeId] = .directory~new
        else if classId = "IdentityTable" then objects[nodeId] = .IdentityTable~new
        else objects[nodeId] = .table~new
      end
      when kind = "P" then objects[nodeId] = typeRegistry~createBlank(x2c(typeHex))
      otherwise raise syntax 88.900 array("Unknown queue graph node kind " || kind)
    end
  end

  /* Second pass: populate collection placeholders. */
  supplier = descriptions~supplier
  do while supplier~available
    nodeId = supplier~index
    desc = supplier~item
    kind = desc[1]
    data = desc[3]
    object = objects[nodeId]
    select
      when kind = "A" then do
        if data \= "" then do token over self~split(data, ",")
          object~append(self~decodeToken(token, objects))
        end
      end
      when kind = "T" then do
        if data \= "" then do pair over self~split(data, ",")
          eqAt = pair~pos("=")
          if eqAt = 0 then raise syntax 88.900 array("Malformed queue graph map entry")
          keyToken = pair~substr(1, eqAt - 1)
          valueToken = pair~substr(eqAt + 1)
          object~put(self~decodeToken(valueToken, objects), self~decodeToken(keyToken, objects))
        end
      end
      otherwise nop
    end
    supplier~next
  end

  /* Third pass: restore domain objects after their state containers exist. */
  supplier = descriptions~supplier
  do while supplier~available
    nodeId = supplier~index
    desc = supplier~item
    if desc[1] = "P" then do
      object = objects[nodeId]
      if \object~hasMethod("queueRestoreState") then raise syntax 88.900 array("Persistent payload lacks queueRestoreState")
      restoredValue = object~queueRestoreState(self~decodeToken(desc[3], objects))
    end
    supplier~next
  end
  return self~decodeToken(rootToken, objects)

::method decodeToken private
  use arg token, objects
  if token = "N" then return .nil
  kind = token~left(1)
  data = token~substr(2)
  if kind = "S" then return x2c(data)
  if kind = "R" then do
    object = objects[data]
    if object == .nil then raise syntax 88.900 array("Unknown queue graph reference " || data)
    return object
  end
  raise syntax 88.900 array("Unknown queue graph token")

::method join private
  use arg values, separator
  text = ""
  do i = 1 to values~items
    if i > 1 then text ||= separator
    text ||= values[i]
  end
  return text

::method joinLines private
  use arg lines
  return self~join(lines, "0a"x)

::method splitLines private
  use arg text
  return self~split(text, "0a"x)

::method split private
  use arg text, separator
  parts = .array~new
  start = 1
  do forever
    where = text~pos(separator, start)
    if where = 0 then do
      parts~append(text~substr(start))
      leave
    end
    parts~append(text~substr(start, where - start))
    start = where + separator~length
  end
  return parts

/* ----------------------------------------------------------------------- */
/* Append-only durable store                                               */
/* ----------------------------------------------------------------------- */

::class QueueRecordCodec public
::method encode class
  use arg tag, fields
  line = tag~string
  do field over fields
    if field == .nil then field = ""
    line ||= "|" || c2x(field~string)
  end
  return line

::method decode class
  use arg line
  pieces = self~split(line, "|")
  if pieces~items = 0 then return .nil
  row = .array~new
  row~append(pieces[1])
  do i = 2 to pieces~items
    signal on syntax name badRecord
    value = x2c(pieces[i])
    signal off syntax
    row~append(value)
  end
  return row
badRecord:
  signal off syntax
  return .nil

::method split class
  use arg text, separator
  parts = .array~new
  start = 1
  do forever
    where = text~pos(separator, start)
    if where = 0 then do
      parts~append(text~substr(start))
      leave
    end
    parts~append(text~substr(start, where - start))
    start = where + separator~length
  end
  return parts

::class QueueDurableStore public
::attribute root get
::attribute journalPath get
::attribute trafficPath get
::attribute recordProtector get
::attribute recoveryMode get
::attribute recoveryWarnings get

::method init
  expose root journalPath trafficPath recordProtector recoveryMode recoveryWarnings
  use arg root, recordProtector = .nil, recoveryMode = "STRICT"
  root = root~string
  journalPath = root || "/queue.journal"
  trafficPath = root || "/traffic.log"
  recordProtector = recordProtector
  recoveryMode = recoveryMode~string~strip~translate
  if recoveryMode \= .QueueRecoveryMode~STRICT then do
    if recoveryMode \= .QueueRecoveryMode~REPAIR_TORN_TAIL then raise syntax 88.900 array("Unknown queue recovery mode: " || recoveryMode)
  end
  recoveryWarnings = .array~new
  ignore = self~ensureDirectory(root)

::method ensureDirectory private
  use arg path
  ignore = RxFuncAdd("SysMkDir", "rxunixsys", "SysMkDir")
  parts = .QueueRecordCodec~split(path, "/")
  current = ""
  if path~startsWith("/") then current = "/"
  do part over parts
    if part = "" then iterate
    if current = "/" then current ||= part
    else if current = "" then current = part
    else current ||= "/" || part
    rc = SysMkDir(current)
  end
  return .true

::method appendJournal
  expose journalPath
  use arg tag, fields
  return self~appendProtectedLine(journalPath, "JOURNAL", .QueueRecordCodec~encode(tag, fields))

::method appendTraffic
  expose trafficPath
  use arg trafficEvent
  fields = .array~of(trafficEvent~eventId, trafficEvent~timestamp, trafficEvent~eventType, trafficEvent~queueName, trafficEvent~packageId, trafficEvent~principal, trafficEvent~detail, trafficEvent~sourceQueue, trafficEvent~destinationQueue, trafficEvent~success)
  return self~appendProtectedLine(trafficPath, "TRAFFIC", .QueueRecordCodec~encode("TRAFFIC", fields))

::method appendProtectedLine private
  expose recordProtector
  use arg path, streamName, line
  guard on
  protectedLine = line
  if recordProtector \== .nil then protectedLine = recordProtector~protect(streamName, line)
  return self~appendLine(path, protectedLine)

::method appendLine private
  use arg path, line
  guard on
  probe = .Stream~new(path)
  existing = probe~query("exists")
  if existing \= "" then do
    openProbe = probe~open("read")
    if openProbe \= "READY:" then raise syntax 88.900 array("Cannot inspect queue store before append " || path || ": " || openProbe)
    existingChars = probe~chars
    ignore = probe~close
    if existingChars > 0 then do
      if \self~hasTerminalLineBreak(path) then raise syntax 88.900 array("Queue store has an unterminated tail; repair recovery is required before append: " || path)
    end
  end
  stream = .Stream~new(path)
  openStatus = stream~open("write append")
  if openStatus \= "READY:" then raise syntax 88.900 array("Cannot open queue store " || path || ": " || openStatus)
  writeStatus = stream~lineOut(line)
  closeStatus = stream~close
  return .true

::method readJournal
  expose journalPath
  return self~readRecords(journalPath, "JOURNAL")

::method readTraffic
  expose trafficPath
  return self~readRecords(trafficPath, "TRAFFIC")

::method readRecords private
  expose recordProtector recoveryMode recoveryWarnings
  use arg path, streamName
  rows = .array~new
  rawLines = .array~new
  stream = .Stream~new(path)
  exists = stream~query("exists")
  if exists = "" then do
    if recordProtector \== .nil then do
      ignore = recordProtector~beginRead(streamName)
      ignore = recordProtector~finishRead(streamName)
    end
    return rows
  end
  hasTerminalLineBreak = self~hasTerminalLineBreak(path)
  openStatus = stream~open("read")
  if openStatus \= "READY:" then raise syntax 88.900 array("Cannot read queue store " || path || ": " || openStatus)
  do while stream~lines > 0
    rawLines~append(stream~lineIn)
  end
  closeStatus = stream~close

  if recordProtector \== .nil then ignore = recordProtector~beginRead(streamName)
  do i = 1 to rawLines~items
    line = rawLines[i]
    signal on syntax name recordReadFailure
    if recordProtector \== .nil then line = recordProtector~unprotect(streamName, line)
    decoded = .QueueRecordCodec~decode(line)
    if decoded == .nil then raise syntax 88.900 array("Malformed queue store record in " || path)
    signal off syntax
    rows~append(decoded)
  end
  if \hasTerminalLineBreak then do
    if recoveryMode = .QueueRecoveryMode~REPAIR_TORN_TAIL then do
      ignore = self~rewriteLines(path, rawLines)
      recoveryWarnings~append("NORMALIZED_UNTERMINATED_VALID_TAIL|" || streamName || "|" || path)
    end
    else do
      if recordProtector \== .nil then ignore = recordProtector~finishRead(streamName)
      raise syntax 88.900 array("Queue store has a valid but unterminated final record: " || path)
    end
  end
  if recordProtector \== .nil then ignore = recordProtector~finishRead(streamName)
  return rows

recordReadFailure:
  signal off syntax
  failureDetail = condition("D")
  if recoveryMode = .QueueRecoveryMode~REPAIR_TORN_TAIL then do
    if i = rawLines~items then do
      if \hasTerminalLineBreak then do
        kept = .array~new
        do n = 1 to i - 1
          kept~append(rawLines[n])
        end
        ignore = self~rewriteLines(path, kept)
        recoveryWarnings~append("REPAIRED_TORN_TAIL|" || streamName || "|" || path || "|" || failureDetail)
        if recordProtector \== .nil then ignore = recordProtector~finishRead(streamName)
        return rows
      end
    end
  end
  raise syntax 88.900 array(failureDetail)

::method hasTerminalLineBreak private
  use arg path
  stream = .Stream~new(path)
  exists = stream~query("exists")
  if exists = "" then return .true
  openStatus = stream~open("read")
  if openStatus \= "READY:" then raise syntax 88.900 array("Cannot inspect queue store " || path || ": " || openStatus)
  count = stream~chars
  if count = 0 then do
    closeStatus = stream~close
    return .true
  end
  lastByte = stream~charIn(count, 1)
  closeStatus = stream~close
  if lastByte = "0a"x then return .true
  if lastByte = "0d"x then return .true
  return .false

::method rewriteLines private
  use arg path, lines
  stream = .Stream~new(path)
  openStatus = stream~open("write replace")
  if openStatus \= "READY:" then raise syntax 88.900 array("Cannot repair queue store " || path || ": " || openStatus)
  do line over lines
    ignore = stream~lineOut(line)
  end
  closeStatus = stream~close
  return .true

/* ----------------------------------------------------------------------- */
/* Queue manager                                                           */
/* ----------------------------------------------------------------------- */

::class ObjectQueueManager subclass AlchemyObject public
::attribute runtimeRegistry get
::attribute adminPrincipal get
::attribute payloadCodec get
::attribute recoveryWarnings get
::attribute durableStore get
::attribute deadLetterQueue get
::attribute timeSource get

::method init
  expose queues queueOrder triggers routes traffic packageIndex transferReceipts idGenerator eventIdGenerator uowIdGenerator sequence durableStore payloadCodec adminPrincipal runtimeRegistry recoveryWarnings recovering authority deadLetterQueue timeSource unitsOfWork queueReferenceGuards
  use arg storeRoot = "", payloadCodec = .nil, adminPrincipal = "queue-admin", runtimeRegistry = .nil, recordProtector = .nil, recoveryMode = "STRICT", timeSource = .nil
  queues = .table~new
  queueOrder = .array~new
  triggers = .array~new
  routes = .array~new
  traffic = .array~new
  packageIndex = .table~new
  transferReceipts = .table~new
  idGenerator = .QueueIdGenerator~new("pkg")
  eventIdGenerator = .QueueIdGenerator~new("evt")
  uowIdGenerator = .QueueIdGenerator~new("uow")
  sequence = 0
  authority = .QueueManagerAuthority~new
  if payloadCodec == .nil then payloadCodec = .QueueGraphPayloadCodec~new
  payloadCodec = payloadCodec
  if payloadCodec~hasMethod("typeRegistry") then ignore = payloadCodec~typeRegistry~register(.QueueTransmissionEnvelope~PERSISTENT_TYPE, .QueueTransmissionEnvelopeFactory~new)
  adminPrincipal = adminPrincipal~string
  runtimeRegistry = runtimeRegistry
  recoveryWarnings = .array~new
  recovering = .false
  deadLetterQueue = ""
  unitsOfWork = .table~new
  queueReferenceGuards = .array~new
  if timeSource == .nil then timeSource = .QueueTimeSource~new
  if storeRoot = "" then durableStore = .nil
  else durableStore = .QueueDurableStore~new(storeRoot, recordProtector, recoveryMode)

  limitations = .array~of("No distributed XA; each queue manager commits only local durable state", "Alchemy metadata is runtime observability and is not journaled into queue payload graphs")
  meta = .QueueFabricAlchemyMetadata~standard("Queue manager and local queue/UOW authority", "queue.manager/0.9-dev3", limitations)
  self~initAlchemy(meta)
  self~registerStateVariable("adminPrincipal", "INTERNAL", "queue-manager administrative principal")
  self~registerStateVariable("deadLetterQueue", "CUSTOMER", "configured dead-letter queue name")
  self~registerStateVariable("recoveryWarnings", "INTERNAL", "bounded recovery warning evidence")
  self~registerMethodContract("CREATEQUEUE", "Create one named queue", .array~of("NAME", "LIFECYCLE", "SECURITY_DOMAIN", "MAX_DEPTH", "OWNER", "PRINCIPAL"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("PUT", "Place one object payload on a local queue", .array~of("QUEUE", "PAYLOAD", "PRINCIPAL"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("CLAIM", "Claim one ready work package for recoverable delivery", .array~of("QUEUE", "CONSUMER", "PRINCIPAL"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("BEGINUNITOFWORK", "Create one local queue-manager unit of work", .array~of("PRINCIPAL"), "QUEUEOPERATIONRESULT", .false)
  self~describeMethodPolicy("CREATEQUEUE", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("PUT", "FALSE", "CUSTOMER", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("CLAIM", "FALSE", "CUSTOMER", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("BEGINUNITOFWORK", "FALSE", "CUSTOMER", "SENSITIVE", "MUTATE", "NONE")
  self~recordRelationship("PAYLOAD_CODEC", payloadCodec, "explicit persistence-boundary graph codec", "INTERNAL")
  if runtimeRegistry \== .nil then self~recordRelationship("RUNTIME_REGISTRY", runtimeRegistry, "optional persistent trigger target registry", "INTERNAL")
  if durableStore \== .nil then self~recordRelationship("DURABLE_STORE", durableStore, "append-only queue journal and traffic store", "INTERNAL")

  if durableStore \== .nil then self~recover

::method setRuntimeRegistry
  expose runtimeRegistry
  use arg registry
  runtimeRegistry = registry
  return .true

::method queue
  expose queues
  use arg queueName
  return queues[queueName~string~translate]

::method accessAllowed
  use arg queueName, principal, action
  q = self~queue(queueName)
  if q == .nil then return .false
  return self~authorised(q, principal, action)

::method registerQueueReferenceGuard
  expose queueReferenceGuards
  use arg guardObject, principal = ""
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "reference guard registration requires admin")
  if guardObject == .nil then return .QueueOperationResult~failure("INVALID_REFERENCE_GUARD")
  if \guardObject~hasMethod("CANDELETEQUEUE") then return .QueueOperationResult~failure("INVALID_REFERENCE_GUARD")
  guard on
  do existingGuard over queueReferenceGuards
    if existingGuard == guardObject then do
      guard off
      return .QueueOperationResult~success(guardObject, "already registered")
    end
  end
  queueReferenceGuards~append(guardObject)
  guard off
  return .QueueOperationResult~success(guardObject, "registered")

::method unregisterQueueReferenceGuard
  expose queueReferenceGuards
  use arg guardObject, principal = ""
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "reference guard deregistration requires admin")
  guard on
  keptGuards = .array~new
  removed = .false
  do existingGuard over queueReferenceGuards
    if existingGuard == guardObject then removed = .true
    else keptGuards~append(existingGuard)
  end
  queueReferenceGuards = keptGuards
  guard off
  return .QueueOperationResult~success(removed)

::method queues
  expose queueOrder
  copied = .array~new
  do q over queueOrder
    copied~append(q)
  end
  return copied

::method triggers
  expose triggers
  copied = .array~new
  do reg over triggers
    copied~append(reg)
  end
  return copied

::method routes
  expose routes
  copied = .array~new
  do rule over routes
    copied~append(rule)
  end
  return copied

::method traffic
  expose traffic
  copied = .array~new
  do event over traffic
    copied~append(event)
  end
  return copied

::method activeUnitOfWorkCount
  expose unitsOfWork
  return unitsOfWork~items

::method transferReceiptCount
  expose transferReceipts
  return transferReceipts~items

::method transferReceipt
  expose transferReceipts
  use arg transferId
  return transferReceipts[transferId~string]

::method isAdmin private
  expose adminPrincipal
  use arg principal
  return principal~string = adminPrincipal

::method authorised private
  expose authority
  use arg queueObject, principal, action
  if self~isAdmin(principal) then return .true
  return queueObject~allows(principal, action, authority)

::method createQueue
  expose queues queueOrder durableStore recovering adminPrincipal authority
  use arg queueName, lifecycle = "TEMPORARY", securityDomain = "DEFAULT", maxDepth = 0, principal = ""
  queueName = queueName~string~strip
  lifecycle = lifecycle~string~translate
  if queueName = "" then return .QueueOperationResult~failure("INVALID_QUEUE_NAME")
  if principal = "" then principal = adminPrincipal
  if lifecycle \= .QueueLifecycle~TEMPORARY & lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("INVALID_LIFECYCLE", lifecycle)
  if lifecycle = .QueueLifecycle~PERMANENT then do
    if durableStore == .nil then return .QueueOperationResult~failure("PERSISTENCE_UNAVAILABLE", "Permanent queues require a durable store root")
  end
  if maxDepth < 0 then return .QueueOperationResult~failure("INVALID_MAX_DEPTH", maxDepth)
  key = queueName~translate
  guard on
  if queues~hasIndex(key) then do
    guard off
    return .QueueOperationResult~failure("QUEUE_EXISTS", queueName)
  end
  queueId = "queue-" || queueName
  q = .QueueEndpoint~new(queueId, queueName, lifecycle, securityDomain, maxDepth, principal, "", authority)
  queues[key] = q
  queueOrder~append(q)
  if durableStore \== .nil & lifecycle = .QueueLifecycle~PERMANENT & \recovering then ignore = durableStore~appendJournal("QCREATE", .array~of(queueId, queueName, lifecycle, securityDomain, maxDepth, principal, q~createdAt))
  ignore = self~recordTrafficLocked("CREATE_QUEUE", queueName, "", principal, lifecycle, queueName, queueName, .true)
  guard off
  return .QueueOperationResult~success(q, "queue created")

::method deleteQueue
  expose queues queueOrder triggers routes durableStore deadLetterQueue queueReferenceGuards
  use arg queueName, principal
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~MANAGE) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  do referenceGuard over queueReferenceGuards
    guardCheck = referenceGuard~canDeleteQueue(q~name)
    if guardCheck \== .nil then do
      if guardCheck~hasMethod("OK") then do
        if \guardCheck~ok then return guardCheck
      end
    end
  end
  guard on
  if q~totalDepth > 0 then do
    guard off
    return .QueueOperationResult~failure("QUEUE_NOT_EMPTY", queueName)
  end
  if deadLetterQueue = q~name then do
    guard off
    return .QueueOperationResult~failure("QUEUE_REFERENCED_AS_DEAD_LETTER", q~name)
  end
  do existingQueue over queueOrder
    if existingQueue~name = q~name then iterate
    if existingQueue~backoutQueue = q~name then do
      guard off
      return .QueueOperationResult~failure("QUEUE_REFERENCED_AS_BACKOUT", existingQueue~name)
    end
  end
  queues~remove(queueName~string~translate)
  keptQueues = .array~new
  do existingQueue over queueOrder
    if existingQueue~name \= q~name then keptQueues~append(existingQueue)
  end
  queueOrder = keptQueues
  keptTriggers = .array~new
  do reg over triggers
    if reg~queueName \= q~name then keptTriggers~append(reg)
  end
  triggers = keptTriggers
  keptRoutes = .array~new
  do rule over routes
    if rule~sourceQueue \= q~name & rule~destinationQueue \= q~name then keptRoutes~append(rule)
  end
  routes = keptRoutes
  if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT then ignore = durableStore~appendJournal("QDELETE", .array~of(q~name))
  ignore = self~recordTrafficLocked("DELETE_QUEUE", q~name, "", principal, "", q~name, q~name, .true)
  guard off
  return .QueueOperationResult~success(q, "queue deleted")

::method grant
  expose durableStore authority
  use arg queueName, grantee, action, principal
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~MANAGE) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  action = action~string~translate
  if action \= .QueueAccess~PUT & action \= .QueueAccess~GET & action \= .QueueAccess~BROWSE & action \= .QueueAccess~MANAGE then return .QueueOperationResult~failure("INVALID_ACCESS", action)
  guard on
  ignore = q~allowAccess(grantee, action, authority)
  if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT then ignore = durableStore~appendJournal("ACLALLOW", .array~of(q~name, grantee, action))
  ignore = self~recordTrafficLocked("ACL_ALLOW", q~name, "", principal, grantee || ":" || action, q~name, q~name, .true)
  guard off
  return .QueueOperationResult~success(.true)

::method revoke
  expose durableStore authority
  use arg queueName, grantee, action, principal
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~MANAGE) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  action = action~string~translate
  guard on
  ignore = q~revokeAccess(grantee, action, authority)
  if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT then ignore = durableStore~appendJournal("ACLREVOKE", .array~of(q~name, grantee, action))
  ignore = self~recordTrafficLocked("ACL_REVOKE", q~name, "", principal, grantee || ":" || action, q~name, q~name, .true)
  guard off
  return .QueueOperationResult~success(.true)

::method beginUnitOfWork
  expose unitsOfWork uowIdGenerator authority adminPrincipal
  use arg principal = ""
  if principal = "" then principal = adminPrincipal
  guard on
  uow = .QueueUnitOfWork~new(uowIdGenerator~next, principal, authority)
  unitsOfWork[uow~uowId] = uow
  ignore = self~recordTrafficLocked("UOW_BEGIN", "", "", principal, uow~uowId, "", "", .true)
  guard off
  return .QueueOperationResult~success(uow)

::method activeUnitOfWork private
  expose unitsOfWork
  use arg uow
  if uow == .nil then return .false
  if \uow~hasMethod("uowId") then return .false
  known = unitsOfWork[uow~uowId]
  if known == .nil then return .false
  if known \== uow then return .false
  return uow~state = .QueueUnitOfWorkState~ACTIVE

::method uowPut
  expose authority
  use arg uow, queueName, payload, options = .nil
  if \self~activeUnitOfWork(uow) then return .QueueOperationResult~failure("UOW_NOT_ACTIVE")
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, uow~principal, .QueueAccess~PUT) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  if options == .nil then options = .table~new
  expirySeconds = self~option(options, "expirySeconds", 0)
  if \datatype(expirySeconds, "N") then return .QueueOperationResult~failure("INVALID_EXPIRY", expirySeconds)
  if expirySeconds < 0 then return .QueueOperationResult~failure("INVALID_EXPIRY", expirySeconds)
  stagedOptions = options~copy
  headers = stagedOptions["headers"]
  if headers \== .nil then do
    if headers~hasMethod("copy") then stagedOptions["headers"] = headers~copy
  end
  if \uow~addPutInternal(q~name, payload, stagedOptions, authority) then return .QueueOperationResult~failure("UOW_STAGE_FAILED")
  return .QueueOperationResult~success(uow, "put staged")

::method uowGet
  expose authority idGenerator
  use arg uow, queueName
  if \self~activeUnitOfWork(uow) then return .QueueOperationResult~failure("UOW_NOT_ACTIVE")
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  principal = uow~principal
  if \self~authorised(q, principal, .QueueAccess~GET) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  guard on
  sweepResult = self~expireReadyLocked(q, principal)
  beforeDepth = q~readyDepth
  package = q~nextReadyPackage(authority)
  if package == .nil then do
    guard off
    ignore = self~dispatchEvents(sweepResult[2])
    return .QueueOperationResult~failure("QUEUE_EMPTY", queueName)
  end
  token = idGenerator~next
  uowOwner = "UOW:" || uow~uowId
  ignore = package~markClaimed(uowOwner, token, .QueueClock~timestamp, authority)
  if \uow~addReservedGetInternal(q~name, package~packageId, token, authority) then do
    ignore = package~markReady(authority)
    guard off
    return .QueueOperationResult~failure("UOW_STAGE_FAILED")
  end
  claimEvent = self~newTriggerEventLocked(q~name, .QueueTriggerKind~CLAIM, beforeDepth, q~readyDepth, package~packageId, principal)
  ignore = self~recordTrafficLocked("UOW_CLAIM", q~name, package~packageId, principal, uow~uowId, q~name, q~name, .true)
  guard off
  events = sweepResult[2]
  events~append(claimEvent)
  failures = self~dispatchEvents(events)
  return .QueueOperationResult~success(package, "reserved by " || uow~uowId, failures)

::method commitUnitOfWork
  expose authority unitsOfWork sequence idGenerator packageIndex durableStore payloadCodec timeSource adminPrincipal
  use arg uow, extraJournalRows = .nil
  if \self~activeUnitOfWork(uow) then return .QueueOperationResult~failure("UOW_NOT_ACTIVE")
  principal = uow~principal
  guard on
  if \self~activeUnitOfWork(uow) then do
    guard off
    return .QueueOperationResult~failure("UOW_NOT_ACTIVE")
  end
  getEntries = uow~getEntriesInternal(authority)
  putEntries = uow~putEntriesInternal(authority)
  deltas = .table~new
  queueRefs = .table~new

  /* Revalidate every reservation while holding the manager guard. */
  do entry over getEntries
    q = self~queue(entry[1])
    if q == .nil then do; guard off; return .QueueOperationResult~failure("QUEUE_NOT_FOUND", entry[1]); end
    package = q~findPackage(entry[2], authority)
    if package == .nil then do; guard off; return .QueueOperationResult~failure("UOW_RESERVATION_LOST", entry[2]); end
    if package~state \= .QueuePackageState~INFLIGHT then do; guard off; return .QueueOperationResult~failure("UOW_RESERVATION_LOST", entry[2]); end
    if package~claimedBy \= ("UOW:" || uow~uowId) | package~claimToken \= entry[3] then do; guard off; return .QueueOperationResult~failure("UOW_RESERVATION_LOST", entry[2]); end
    key = q~name~translate
    if deltas[key] == .nil then deltas[key] = 0
    deltas[key] = deltas[key] - 1
    queueRefs[key] = q
  end

  plans = .array~new
  do entry over putEntries
    source = self~queue(entry[1])
    if source == .nil then do; guard off; return .QueueOperationResult~failure("QUEUE_NOT_FOUND", entry[1]); end
    if \self~authorised(source, principal, .QueueAccess~PUT) then do; guard off; return .QueueOperationResult~failure("ACCESS_DENIED", source~name); end
    payload = entry[2]
    options = entry[3]
    priority = self~option(options, "priority", 0)
    persistent = self~truth(self~option(options, "persistent", .false))
    routingKey = self~option(options, "routingKey", "")
    correlationId = self~option(options, "correlationId", "")
    replyTo = self~option(options, "replyTo", "")
    headers = self~option(options, "headers", .table~new)
    securityDomain = self~option(options, "securityDomain", source~securityDomain)
    expirySeconds = self~option(options, "expirySeconds", 0)
    if \datatype(expirySeconds, "N") | expirySeconds < 0 then do; guard off; return .QueueOperationResult~failure("INVALID_EXPIRY", expirySeconds); end
    if expirySeconds = 0 then expiryTick = 0
    else expiryTick = timeSource~addSeconds(timeSource~nowTick, expirySeconds)
    if securityDomain \= source~securityDomain then do; guard off; return .QueueOperationResult~failure("SECURITY_DOMAIN_MISMATCH", securityDomain || " != " || source~securityDomain); end
    decisions = self~routeDecisionsLocked(source, routingKey)
    if \decisions~ok then do; guard off; return decisions; end
    targets = decisions~value
    if persistent then do
      needsEncoding = .false
      do targetSpec over targets
        if targetSpec[1]~lifecycle = .QueueLifecycle~PERMANENT then needsEncoding = .true
      end
      if needsEncoding then do
        if \payloadCodec~canEncode(payload) then do; guard off; return .QueueOperationResult~failure("PAYLOAD_NOT_PERSISTABLE", payload~class~id); end
        if \payloadCodec~canEncode(headers) then do; guard off; return .QueueOperationResult~failure("HEADERS_NOT_PERSISTABLE"); end
      end
    end
    do targetSpec over targets
      target = targetSpec[1]
      allowCross = targetSpec[2]
      if target~securityDomain \= securityDomain & \allowCross then do; guard off; return .QueueOperationResult~failure("ROUTE_SECURITY_DOMAIN_DENIED", source~name || " -> " || target~name); end
      if target~state \= .QueueState~ACTIVE then do; guard off; return .QueueOperationResult~failure("QUEUE_FULL_OR_DISABLED", target~name); end
      key = target~name~translate
      if deltas[key] == .nil then deltas[key] = 0
      deltas[key] = deltas[key] + 1
      queueRefs[key] = target
    end
    plans~append(.array~of(source, targets, payload, headers, priority, persistent, securityDomain, routingKey, correlationId, replyTo, expiryTick))
  end

  supplier = deltas~supplier
  do while supplier~available
    key = supplier~index
    delta = supplier~item
    q = queueRefs[key]
    projected = q~totalDepth + delta
    if q~maxDepth > 0 & projected > q~maxDepth then do
      guard off
      return .QueueOperationResult~failure("QUEUE_FULL_OR_DISABLED", q~name)
    end
    supplier~next
  end

  mutationPuts = .array~new
  createdPackages = .array~new
  do plan over plans
    source = plan[1]; targets = plan[2]; payload = plan[3]; headers = plan[4]
    priority = plan[5]; persistent = plan[6]; securityDomain = plan[7]; routingKey = plan[8]
    correlationId = plan[9]; replyTo = plan[10]; expiryTick = plan[11]
    basePackage = .nil
    do i = 1 to targets~items
      target = targets[i][1]
      sequence += 1
      packageId = idGenerator~next
      if i = 1 then do
        workPackage = .QueueWorkPackage~new(packageId, payload, headers~copy, priority, persistent, securityDomain, routingKey, correlationId, replyTo, source~name, target~name, "", .QueueClock~timestamp, sequence, authority, expiryTick)
        basePackage = workPackage
      end
      else workPackage = basePackage~copyForRoute(packageId, target~name, sequence, authority)
      mutationPuts~append(.array~of(source, target, workPackage))
      createdPackages~append(workPackage)
    end
  end

  durableRows = .array~new
  do entry over getEntries
    q = self~queue(entry[1]); package = q~findPackage(entry[2], authority)
    if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT & package~persistent then durableRows~append(.array~of("PREMOVE", q~name, package~packageId))
  end
  do mutation over mutationPuts
    target = mutation[2]; package = mutation[3]
    if durableStore \== .nil & target~lifecycle = .QueueLifecycle~PERMANENT & package~persistent then durableRows~append(self~packageRowLocked("PPUT", target, package))
  end
  if extraJournalRows \== .nil then do
    if principal \= adminPrincipal then do
      guard off
      return .QueueOperationResult~failure("UOW_EXTENSION_REQUIRES_ADMIN")
    end
    do extraRow over extraJournalRows
      if extraRow == .nil then iterate
      if \extraRow~hasMethod("ITEMS") then do
        guard off
        return .QueueOperationResult~failure("INVALID_UOW_EXTENSION_ROW")
      end
      durableRows~append(extraRow)
    end
  end

  signal on syntax name uowJournalFailure
  if durableRows~items > 0 then ignore = self~journalRowsLocked(durableRows)
  signal off syntax

  events = .array~new
  touched = .table~new
  do entry over getEntries
    q = self~queue(entry[1]); package = q~findPackage(entry[2], authority)
    beforeDepth = q~readyDepth
    ignore = q~removePackage(package~packageId, authority)
    packageIndex~remove(package~packageId)
    ignore = package~markAcked(authority)
    events~append(self~newTriggerEventLocked(q~name, .QueueTriggerKind~ACK, beforeDepth, q~readyDepth, package~packageId, principal))
    touched[q~name~translate] = q
    ignore = self~recordTrafficLocked("UOW_ACK", q~name, package~packageId, principal, uow~uowId, q~name, q~name, .true)
  end
  do mutation over mutationPuts
    source = mutation[1]; target = mutation[2]; package = mutation[3]
    beforeDepth = target~readyDepth
    ignore = target~appendPackage(package, authority)
    packageIndex[package~packageId] = package
    events~append(self~newTriggerEventLocked(target~name, .QueueTriggerKind~PUT, beforeDepth, target~readyDepth, package~packageId, principal))
    touched[target~name~translate] = target
    ignore = self~recordTrafficLocked("UOW_PUT", target~name, package~packageId, principal, uow~uowId, source~name, target~name, .true)
  end
  supplier = touched~supplier
  do while supplier~available
    q = supplier~item
    events~append(self~newTriggerEventLocked(q~name, .QueueTriggerKind~UOW_COMMIT, q~readyDepth, q~readyDepth, "", principal))
    supplier~next
  end
  ignore = uow~markCommittedInternal(authority)
  unitsOfWork~remove(uow~uowId)
  ignore = self~recordTrafficLocked("UOW_COMMIT", "", "", principal, uow~uowId || ";puts=" || createdPackages~items || ";gets=" || getEntries~items, "", "", .true)
  guard off
  failures = self~dispatchEvents(events)
  return .QueueOperationResult~success(uow, "puts=" || createdPackages~items || ";gets=" || getEntries~items, failures)

uowJournalFailure:
  signal off syntax
  detail = condition("D")
  guard off
  return .QueueOperationResult~failure("UOW_JOURNAL_FAILED", detail)

::method rollbackUnitOfWork
  expose authority unitsOfWork durableStore
  use arg uow
  if \self~activeUnitOfWork(uow) then return .QueueOperationResult~failure("UOW_NOT_ACTIVE")
  principal = uow~principal
  guard on
  events = .array~new
  touched = .table~new
  getEntries = uow~getEntriesInternal(authority)
  do entry over getEntries
    q = self~queue(entry[1])
    if q == .nil then iterate
    package = q~findPackage(entry[2], authority)
    if package == .nil then iterate
    if package~state \= .QueuePackageState~INFLIGHT then iterate
    if package~claimedBy \= ("UOW:" || uow~uowId) | package~claimToken \= entry[3] then iterate
    beforeDepth = q~readyDepth
    ignore = package~markReady(authority, .true)
    moved = .false
    if q~backoutThreshold > 0 & package~backoutCount >= q~backoutThreshold then do
      target = self~backoutTargetLocked(q)
      if target \== .nil then do
        beforeTarget = target~readyDepth
        ignore = q~removePackage(package~packageId, authority)
        if q~backoutQueue \= "" & target~name = q~backoutQueue then do
          disposition = "BACKOUT_THRESHOLD"
          targetKind = .QueueTriggerKind~BACKOUT
        end
        else do
          disposition = "BACKOUT_TO_DEAD_LETTER"
          targetKind = .QueueTriggerKind~DEAD_LETTER
        end
        ignore = package~moveToQueueInternal(target~name, disposition, q~name, authority)
        ignore = target~appendPackage(package, authority)
        ignore = self~journalMoveLocked(q, target, package)
        events~append(self~newTriggerEventLocked(target~name, targetKind, beforeTarget, target~readyDepth, package~packageId, principal))
        touched[target~name~translate] = target
        moved = .true
      end
    end
    if \moved then do
      if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT & package~persistent then ignore = self~journalPackageLocked("PSTATE", q, package)
    end
    events~append(self~newTriggerEventLocked(q~name, .QueueTriggerKind~NACK, beforeDepth, q~readyDepth, package~packageId, principal))
    touched[q~name~translate] = q
    ignore = self~recordTrafficLocked("UOW_NACK", q~name, package~packageId, principal, uow~uowId || ";backoutCount=" || package~backoutCount, q~name, package~currentQueue, .true)
  end
  supplier = touched~supplier
  do while supplier~available
    q = supplier~item
    events~append(self~newTriggerEventLocked(q~name, .QueueTriggerKind~UOW_ROLLBACK, q~readyDepth, q~readyDepth, "", principal))
    supplier~next
  end
  ignore = uow~markRolledBackInternal(authority)
  unitsOfWork~remove(uow~uowId)
  ignore = self~recordTrafficLocked("UOW_ROLLBACK", "", "", principal, uow~uowId, "", "", .true)
  guard off
  failures = self~dispatchEvents(events)
  return .QueueOperationResult~success(uow, "rolled back", failures)

::method setDeadLetterQueue
  expose deadLetterQueue durableStore
  use arg queueName = "", principal = ""
  if \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", "dead-letter configuration requires admin")
  queueName = queueName~string~strip
  if queueName \= "" then do
    target = self~queue(queueName)
    if target == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
    if durableStore \== .nil & target~lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("DLQ_NOT_PERMANENT", queueName)
    queueName = target~name
  end
  guard on
  deadLetterQueue = queueName
  if durableStore \== .nil then ignore = durableStore~appendJournal("MDEADLETTER", .array~of(deadLetterQueue))
  ignore = self~recordTrafficLocked("SET_DEAD_LETTER", queueName, "", principal, deadLetterQueue, queueName, queueName, .true)
  guard off
  return .QueueOperationResult~success(deadLetterQueue)

::method configureBackout
  expose durableStore authority deadLetterQueue
  use arg queueName, threshold = 0, backoutQueue = "", principal = ""
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~MANAGE) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  if threshold < 0 then return .QueueOperationResult~failure("INVALID_BACKOUT_THRESHOLD", threshold)
  backoutQueue = backoutQueue~string~strip
  if threshold > 0 then do
    if backoutQueue = "" then do
      if deadLetterQueue = "" then return .QueueOperationResult~failure("BACKOUT_QUEUE_REQUIRED", queueName)
      target = self~queue(deadLetterQueue)
      if target == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", deadLetterQueue)
    end
    else do
      target = self~queue(backoutQueue)
      if target == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", backoutQueue)
    end
    if target~name = q~name then return .QueueOperationResult~failure("BACKOUT_QUEUE_SELF_REFERENCE", queueName)
    if target~securityDomain \= q~securityDomain then return .QueueOperationResult~failure("BACKOUT_SECURITY_DOMAIN_DENIED", q~name || " -> " || target~name)
    if q~lifecycle = .QueueLifecycle~PERMANENT & target~lifecycle \= .QueueLifecycle~PERMANENT then return .QueueOperationResult~failure("BACKOUT_QUEUE_NOT_PERMANENT", target~name)
    if backoutQueue \= "" then backoutQueue = target~name
  end
  else backoutQueue = ""
  guard on
  ignore = q~configureBackoutInternal(threshold, backoutQueue, authority)
  if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT then ignore = durableStore~appendJournal("QBACKOUT", .array~of(q~name, threshold, backoutQueue))
  ignore = self~recordTrafficLocked("CONFIGURE_BACKOUT", q~name, "", principal, threshold || ":" || backoutQueue, q~name, backoutQueue, .true)
  guard off
  return .QueueOperationResult~success(q)

::method sweepExpired
  use arg queueName, principal
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~BROWSE) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  guard on
  sweepResult = self~expireReadyLocked(q, principal)
  guard off
  failures = self~dispatchEvents(sweepResult[2])
  return .QueueOperationResult~success(sweepResult[1], "expired=" || sweepResult[1], failures)

::method depth
  use arg queueName, principal
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~BROWSE) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  guard on
  sweepResult = self~expireReadyLocked(q, principal)
  row = .table~new
  row["ready"] = q~readyDepth
  row["inflight"] = q~inflightDepth
  row["total"] = q~totalDepth
  guard off
  failures = self~dispatchEvents(sweepResult[2])
  return .QueueOperationResult~success(row, "expired=" || sweepResult[1], failures)

::method put
  expose idGenerator sequence durableStore payloadCodec packageIndex authority timeSource
  use arg queueName, payload, options = .nil, principal = ""
  source = self~queue(queueName)
  if source == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(source, principal, .QueueAccess~PUT) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  if options == .nil then options = .table~new
  priority = self~option(options, "priority", 0)
  persistent = self~truth(self~option(options, "persistent", .false))
  routingKey = self~option(options, "routingKey", "")
  correlationId = self~option(options, "correlationId", "")
  replyTo = self~option(options, "replyTo", "")
  headers = self~option(options, "headers", .table~new)
  securityDomain = self~option(options, "securityDomain", source~securityDomain)
  expirySeconds = self~option(options, "expirySeconds", 0)
  if \datatype(expirySeconds, "N") then return .QueueOperationResult~failure("INVALID_EXPIRY", expirySeconds)
  if expirySeconds < 0 then return .QueueOperationResult~failure("INVALID_EXPIRY", expirySeconds)
  if expirySeconds = 0 then expiryTick = 0
  else expiryTick = timeSource~addSeconds(timeSource~nowTick, expirySeconds)
  if securityDomain \= source~securityDomain then return .QueueOperationResult~failure("SECURITY_DOMAIN_MISMATCH", securityDomain || " != " || source~securityDomain)
  guard on
  decisions = self~routeDecisionsLocked(source, routingKey)
  if \decisions~ok then do
    guard off
    return decisions
  end
  targets = decisions~value
  if persistent then do
    needsEncoding = .false
    do targetSpec over targets
      if targetSpec[1]~lifecycle = .QueueLifecycle~PERMANENT then needsEncoding = .true
    end
    if needsEncoding then do
      if \payloadCodec~canEncode(payload) then do
        guard off
        return .QueueOperationResult~failure("PAYLOAD_NOT_PERSISTABLE", payload~class~id)
      end
      if \payloadCodec~canEncode(headers) then do
        guard off
        return .QueueOperationResult~failure("HEADERS_NOT_PERSISTABLE")
      end
    end
  end
  /* Preflight every target before touching any queue. */
  do targetSpec over targets
    targetQueue = targetSpec[1]
    allowCross = targetSpec[2]
    if targetQueue~securityDomain \= securityDomain & \allowCross then do
      guard off
      return .QueueOperationResult~failure("ROUTE_SECURITY_DOMAIN_DENIED", source~name || " -> " || targetQueue~name)
    end
    if \targetQueue~canAccept then do
      guard off
      return .QueueOperationResult~failure("QUEUE_FULL_OR_DISABLED", targetQueue~name)
    end
  end

  createdPackages = .array~new
  triggerEvents = .array~new
  basePackage = .nil
  do i = 1 to targets~items
    targetSpec = targets[i]
    targetQueue = targetSpec[1]
    beforeDepth = targetQueue~readyDepth
    sequence += 1
    if i = 1 then do
      packageId = idGenerator~next
      basePackage = .QueueWorkPackage~new(packageId, payload, headers~copy, priority, persistent, securityDomain, routingKey, correlationId, replyTo, source~name, targetQueue~name, "", .QueueClock~timestamp, sequence, authority, expiryTick)
      workPackage = basePackage
    end
    else do
      packageId = idGenerator~next
      workPackage = basePackage~copyForRoute(packageId, targetQueue~name, sequence, authority)
    end
    ignore = targetQueue~appendPackage(workPackage, authority)
    packageIndex[workPackage~packageId] = workPackage
    createdPackages~append(workPackage)
    if durableStore \== .nil & targetQueue~lifecycle = .QueueLifecycle~PERMANENT & persistent then ignore = self~journalPackageLocked("PPUT", targetQueue, workPackage)
    afterDepth = targetQueue~readyDepth
    triggerEvents~append(self~newTriggerEventLocked(targetQueue~name, .QueueTriggerKind~PUT, beforeDepth, afterDepth, workPackage~packageId, principal))
    ignore = self~recordTrafficLocked("PUT", targetQueue~name, workPackage~packageId, principal, "routingKey=" || routingKey, source~name, targetQueue~name, .true)
  end
  guard off
  triggerFailures = self~dispatchEvents(triggerEvents)
  return .QueueOperationResult~success(basePackage, "packages=" || createdPackages~items, triggerFailures)

::method browse
  expose authority
  use arg queueName, principal
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~BROWSE) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  guard on
  sweepResult = self~expireReadyLocked(q, principal)
  package = q~nextReadyPackage(authority)
  guard off
  ignore = self~dispatchEvents(sweepResult[2])
  if package == .nil then return .QueueOperationResult~failure("QUEUE_EMPTY", queueName)
  return .QueueOperationResult~success(package)

::method get
  expose durableStore packageIndex authority
  use arg queueName, principal
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~GET) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  guard on
  sweepResult = self~expireReadyLocked(q, principal)
  beforeDepth = q~readyDepth
  package = q~nextReadyPackage(authority)
  if package == .nil then do
    guard off
    ignore = self~dispatchEvents(sweepResult[2])
    return .QueueOperationResult~failure("QUEUE_EMPTY", queueName)
  end
  removed = q~removePackage(package~packageId, authority)
  packageIndex~remove(package~packageId)
  ignore = package~markAcked(authority)
  if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT & package~persistent then ignore = durableStore~appendJournal("PREMOVE", .array~of(q~name, package~packageId))
  afterDepth = q~readyDepth
  event = self~newTriggerEventLocked(q~name, .QueueTriggerKind~GET, beforeDepth, afterDepth, package~packageId, principal)
  ignore = self~recordTrafficLocked("GET", q~name, package~packageId, principal, "", q~name, q~name, .true)
  guard off
  combinedEvents = sweepResult[2]
  combinedEvents~append(event)
  failures = self~dispatchEvents(combinedEvents)
  return .QueueOperationResult~success(package, "message removed", failures)

::method claim
  expose idGenerator durableStore authority
  use arg queueName, principal
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~GET) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  guard on
  sweepResult = self~expireReadyLocked(q, principal)
  beforeDepth = q~readyDepth
  package = q~nextReadyPackage(authority)
  if package == .nil then do
    guard off
    ignore = self~dispatchEvents(sweepResult[2])
    return .QueueOperationResult~failure("QUEUE_EMPTY", queueName)
  end
  token = idGenerator~next
  ignore = package~markClaimed(principal, token, .QueueClock~timestamp, authority)
  if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT & package~persistent then ignore = self~journalPackageLocked("PSTATE", q, package)
  afterDepth = q~readyDepth
  event = self~newTriggerEventLocked(q~name, .QueueTriggerKind~CLAIM, beforeDepth, afterDepth, package~packageId, principal)
  ignore = self~recordTrafficLocked("CLAIM", q~name, package~packageId, principal, "", q~name, q~name, .true)
  guard off
  combinedEvents = sweepResult[2]
  combinedEvents~append(event)
  failures = self~dispatchEvents(combinedEvents)
  return .QueueOperationResult~success(package, "claimToken=" || token, failures)

::method ack
  expose durableStore packageIndex authority
  use arg queueName, packageId, claimToken, principal
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~GET) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  guard on
  package = q~findPackage(packageId, authority)
  if package == .nil then do
    guard off
    return .QueueOperationResult~failure("PACKAGE_NOT_FOUND", packageId)
  end
  if package~state \= .QueuePackageState~INFLIGHT then do
    guard off
    return .QueueOperationResult~failure("PACKAGE_NOT_CLAIMED", packageId)
  end
  if package~claimedBy \= principal~string | package~claimToken \= claimToken~string then do
    guard off
    return .QueueOperationResult~failure("CLAIM_TOKEN_MISMATCH", packageId)
  end
  beforeDepth = q~readyDepth
  ignore = q~removePackage(packageId, authority)
  packageIndex~remove(packageId)
  ignore = package~markAcked(authority)
  if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT & package~persistent then ignore = durableStore~appendJournal("PREMOVE", .array~of(q~name, packageId))
  event = self~newTriggerEventLocked(q~name, .QueueTriggerKind~ACK, beforeDepth, q~readyDepth, packageId, principal)
  ignore = self~recordTrafficLocked("ACK", q~name, packageId, principal, "", q~name, q~name, .true)
  guard off
  failures = self~dispatchEvents(.array~of(event))
  return .QueueOperationResult~success(package, "acknowledged", failures)

::method nack
  expose durableStore authority
  use arg queueName, packageId, claimToken, principal
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~GET) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  guard on
  package = q~findPackage(packageId, authority)
  if package == .nil then do
    guard off
    return .QueueOperationResult~failure("PACKAGE_NOT_FOUND", packageId)
  end
  if package~state \= .QueuePackageState~INFLIGHT then do
    guard off
    return .QueueOperationResult~failure("PACKAGE_NOT_CLAIMED", packageId)
  end
  if package~claimedBy \= principal~string | package~claimToken \= claimToken~string then do
    guard off
    return .QueueOperationResult~failure("CLAIM_TOKEN_MISMATCH", packageId)
  end
  beforeDepth = q~readyDepth
  ignore = package~markReady(authority, .true)
  events = .array~new
  detail = "requeued"
  moved = .false
  if q~backoutThreshold > 0 & package~backoutCount >= q~backoutThreshold then do
    target = self~backoutTargetLocked(q)
    if target \== .nil then do
      beforeTarget = target~readyDepth
      ignore = q~removePackage(packageId, authority)
      if q~backoutQueue \= "" & target~name = q~backoutQueue then do
        disposition = "BACKOUT_THRESHOLD"
        targetEventKind = .QueueTriggerKind~BACKOUT
        trafficType = "BACKOUT"
      end
      else do
        disposition = "BACKOUT_TO_DEAD_LETTER"
        targetEventKind = .QueueTriggerKind~DEAD_LETTER
        trafficType = "BACKOUT_DEAD_LETTER"
      end
      ignore = package~moveToQueueInternal(target~name, disposition, q~name, authority)
      ignore = target~appendPackage(package, authority)
      ignore = self~journalMoveLocked(q, target, package)
      events~append(self~newTriggerEventLocked(target~name, targetEventKind, beforeTarget, target~readyDepth, packageId, principal))
      ignore = self~recordTrafficLocked(trafficType, q~name, packageId, principal, "destination=" || target~name || ";backoutCount=" || package~backoutCount, q~name, target~name, .true)
      detail = "backed out to " || target~name
      moved = .true
    end
    else detail = "backout threshold reached; destination unavailable; requeued"
  end
  if \moved then do
    if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT & package~persistent then ignore = self~journalPackageLocked("PSTATE", q, package)
  end
  orderedEvents = .array~new
  orderedEvents~append(self~newTriggerEventLocked(q~name, .QueueTriggerKind~NACK, beforeDepth, q~readyDepth, packageId, principal))
  do dispositionEvent over events
    orderedEvents~append(dispositionEvent)
  end
  ignore = self~recordTrafficLocked("NACK", q~name, packageId, principal, detail || ";backoutCount=" || package~backoutCount, q~name, package~currentQueue, .true)
  guard off
  failures = self~dispatchEvents(orderedEvents)
  return .QueueOperationResult~success(package, detail, failures)

::method release
  expose durableStore authority
  use arg queueName, packageId, claimToken, principal, detail = "released"
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~GET) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  guard on
  package = q~findPackage(packageId, authority)
  if package == .nil then do
    guard off
    return .QueueOperationResult~failure("PACKAGE_NOT_FOUND", packageId)
  end
  if package~state \= .QueuePackageState~INFLIGHT then do
    guard off
    return .QueueOperationResult~failure("PACKAGE_NOT_CLAIMED", packageId)
  end
  if package~claimedBy \= principal~string | package~claimToken \= claimToken~string then do
    guard off
    return .QueueOperationResult~failure("CLAIM_TOKEN_MISMATCH", packageId)
  end
  beforeDepth = q~readyDepth
  ignore = package~markReady(authority, .false)
  if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT & package~persistent then ignore = self~journalPackageLocked("PSTATE", q, package)
  event = self~newTriggerEventLocked(q~name, .QueueTriggerKind~RELEASE, beforeDepth, q~readyDepth, packageId, principal)
  ignore = self~recordTrafficLocked("RELEASE", q~name, packageId, principal, detail, q~name, q~name, .true)
  guard off
  failures = self~dispatchEvents(.array~of(event))
  return .QueueOperationResult~success(package, detail, failures)

::method acceptTransfer
  expose idGenerator sequence durableStore payloadCodec packageIndex transferReceipts authority timeSource
  use arg transferId, queueName, payload, options = .nil, principal = ""
  transferId = transferId~string~strip
  if transferId = "" then return .QueueOperationResult~failure("INVALID_TRANSFER_ID")
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~PUT) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  if options == .nil then options = .table~new
  sourceManager = self~option(options, "sourceManager", "")~string
  existingReceipt = transferReceipts[transferId]
  if existingReceipt \== .nil then do
    if existingReceipt~queueName \= q~name then return .QueueOperationResult~failure("TRANSFER_ID_CONFLICT", transferId)
    if existingReceipt~sourceManager \= "" & sourceManager \= "" & existingReceipt~sourceManager \= sourceManager then return .QueueOperationResult~failure("TRANSFER_ID_CONFLICT", transferId)
    return .QueueOperationResult~success(existingReceipt~asDuplicate, "duplicate transfer")
  end

  priority = self~option(options, "priority", 0)
  persistent = self~truth(self~option(options, "persistent", .false))
  routingKey = self~option(options, "routingKey", "")
  correlationId = self~option(options, "correlationId", "")
  replyTo = self~option(options, "replyTo", "")
  headers = self~option(options, "headers", .table~new)
  securityDomain = self~option(options, "securityDomain", q~securityDomain)
  expiryTick = self~option(options, "expiryTick", 0)
  sourceQueue = self~option(options, "sourceQueue", q~name)~string
  sourcePackageId = self~option(options, "sourcePackageId", "")~string
  if expiryTick == .nil | expiryTick = "" then expiryTick = 0
  if securityDomain \= q~securityDomain then return .QueueOperationResult~failure("SECURITY_DOMAIN_MISMATCH", securityDomain || " != " || q~securityDomain)
  if expiryTick \= 0 then do
    if timeSource~isExpired(expiryTick) then return .QueueOperationResult~failure("MESSAGE_EXPIRED", transferId)
  end

  guard on
  /* Re-check the receipt while holding the manager guard. */
  existingReceipt = transferReceipts[transferId]
  if existingReceipt \== .nil then do
    guard off
    if existingReceipt~queueName \= q~name then return .QueueOperationResult~failure("TRANSFER_ID_CONFLICT", transferId)
    if existingReceipt~sourceManager \= "" & sourceManager \= "" & existingReceipt~sourceManager \= sourceManager then return .QueueOperationResult~failure("TRANSFER_ID_CONFLICT", transferId)
    return .QueueOperationResult~success(existingReceipt~asDuplicate, "duplicate transfer")
  end
  if \q~canAccept then do
    guard off
    return .QueueOperationResult~failure("QUEUE_FULL_OR_DISABLED", q~name)
  end
  if persistent & q~lifecycle = .QueueLifecycle~PERMANENT then do
    if \payloadCodec~canEncode(payload) then do
      guard off
      return .QueueOperationResult~failure("PAYLOAD_NOT_PERSISTABLE", payload~class~id)
    end
    if \payloadCodec~canEncode(headers) then do
      guard off
      return .QueueOperationResult~failure("HEADERS_NOT_PERSISTABLE")
    end
  end

  sequence += 1
  packageId = idGenerator~next
  package = .QueueWorkPackage~new(packageId, payload, headers~copy, priority, persistent, securityDomain, routingKey, correlationId, replyTo, sourceQueue, q~name, sourcePackageId, .QueueClock~timestamp, sequence, authority, expiryTick)
  acceptedAt = .QueueClock~timestamp

  signal on syntax name transferJournalFailure
  if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT & persistent then do
    packageRow = self~packageRowLocked("PPUT", q, package)
    encodedRow = payloadCodec~encode(packageRow)
    ignore = durableStore~appendJournal("TRANSFERACCEPT", .array~of(transferId, encodedRow, acceptedAt, sourceManager))
  end
  signal off syntax

  beforeDepth = q~readyDepth
  ignore = q~appendPackage(package, authority)
  packageIndex[packageId] = package
  receipt = .QueueTransferReceipt~new(transferId, packageId, q~name, acceptedAt, sourceManager, .false)
  transferReceipts[transferId] = receipt
  event = self~newTriggerEventLocked(q~name, .QueueTriggerKind~PUT, beforeDepth, q~readyDepth, packageId, principal)
  ignore = self~recordTrafficLocked("TRANSFER_ACCEPT", q~name, packageId, principal, "transferId=" || transferId || ";sourceManager=" || sourceManager, sourceQueue, q~name, .true)
  guard off
  failures = self~dispatchEvents(.array~of(event))
  return .QueueOperationResult~success(receipt, "accepted transfer", failures)

transferJournalFailure:
  signal off syntax
  detail = condition("D")
  guard off
  return .QueueOperationResult~failure("TRANSFER_JOURNAL_FAILED", detail)

::method checkpointPackage
  expose durableStore authority
  use arg queueName, packageId, principal
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~MANAGE) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  package = q~findPackage(packageId, authority)
  if package == .nil then return .QueueOperationResult~failure("PACKAGE_NOT_FOUND", packageId)
  if durableStore == .nil | q~lifecycle \= .QueueLifecycle~PERMANENT | \package~persistent then return .QueueOperationResult~failure("PACKAGE_NOT_DURABLE", packageId)
  guard on
  ignore = self~journalPackageLocked("PSTATE", q, package)
  ignore = self~recordTrafficLocked("CHECKPOINT", q~name, packageId, principal, "", q~name, q~name, .true)
  guard off
  return .QueueOperationResult~success(package)

::method registerTrigger
  expose triggers durableStore idGenerator
  use arg queueName, kind, target, threshold = 0, principal = ""
  q = self~queue(queueName)
  if q == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", queueName)
  if \self~authorised(q, principal, .QueueAccess~MANAGE) then return .QueueOperationResult~failure("ACCESS_DENIED", queueName)
  kind = kind~string~translate
  if \self~validTriggerKind(kind) then return .QueueOperationResult~failure("INVALID_TRIGGER_KIND", kind)
  if target == .nil then return .QueueOperationResult~failure("INVALID_TRIGGER_TARGET")
  if \target~hasMethod("invoke") then return .QueueOperationResult~failure("INVALID_TRIGGER_TARGET")
  triggerId = idGenerator~next
  reg = .QueueTriggerRegistration~new(triggerId, q~name, kind, threshold, target, principal)
  guard on
  triggers~append(reg)
  if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT & target~persistent & target~kind = "REGISTRY" then ignore = durableStore~appendJournal("TREGISTER", .array~of(reg~triggerId, q~name, kind, threshold, target~environment, target~moduleId, target~message, principal, reg~registeredAt))
  ignore = self~recordTrafficLocked("REGISTER_TRIGGER", q~name, "", principal, triggerId || ":" || kind, q~name, q~name, .true)
  guard off
  return .QueueOperationResult~success(reg)

::method deregisterTrigger
  expose triggers durableStore
  use arg triggerId, principal
  guard on
  found = .nil
  do reg over triggers
    if reg~triggerId = triggerId then do
      found = reg
      leave
    end
  end
  if found == .nil then do
    guard off
    return .QueueOperationResult~failure("TRIGGER_NOT_FOUND", triggerId)
  end
  q = self~queue(found~queueName)
  if q == .nil then do
    guard off
    return .QueueOperationResult~failure("ACCESS_DENIED", found~queueName)
  end
  if \self~authorised(q, principal, .QueueAccess~MANAGE) then do
    guard off
    return .QueueOperationResult~failure("ACCESS_DENIED", found~queueName)
  end
  keptTriggers = .array~new
  do reg over triggers
    if reg~triggerId \= triggerId then keptTriggers~append(reg)
  end
  triggers = keptTriggers
  if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT & found~target~persistent then ignore = durableStore~appendJournal("TDEREGISTER", .array~of(triggerId))
  ignore = self~recordTrafficLocked("DEREGISTER_TRIGGER", q~name, "", principal, triggerId, q~name, q~name, .true)
  guard off
  return .QueueOperationResult~success(found)

::method registerRoute
  expose routes durableStore idGenerator
  use arg sourceQueue, routingKey, destinationQueue, mode = "REDIRECT", priority = 0, allowCrossDomain = .false, principal = ""
  source = self~queue(sourceQueue)
  destination = self~queue(destinationQueue)
  if source == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", sourceQueue)
  if destination == .nil then return .QueueOperationResult~failure("QUEUE_NOT_FOUND", destinationQueue)
  if \self~authorised(source, principal, .QueueAccess~MANAGE) then return .QueueOperationResult~failure("ACCESS_DENIED", sourceQueue)
  if \self~authorised(destination, principal, .QueueAccess~MANAGE) & \self~isAdmin(principal) then return .QueueOperationResult~failure("ACCESS_DENIED", destinationQueue)
  mode = mode~string~translate
  if mode \= .QueueRouteMode~COPY & mode \= .QueueRouteMode~REDIRECT then return .QueueOperationResult~failure("INVALID_ROUTE_MODE", mode)
  if allowCrossDomain & \self~isAdmin(principal) then return .QueueOperationResult~failure("CROSS_DOMAIN_ROUTE_REQUIRES_ADMIN")
  if source~securityDomain \= destination~securityDomain & \allowCrossDomain then return .QueueOperationResult~failure("ROUTE_SECURITY_DOMAIN_DENIED")
  routeId = idGenerator~next
  rule = .QueueRouteRule~new(routeId, source~name, routingKey, destination~name, mode, priority, allowCrossDomain, principal)
  guard on
  routes~append(rule)
  if durableStore \== .nil & source~lifecycle = .QueueLifecycle~PERMANENT & destination~lifecycle = .QueueLifecycle~PERMANENT then ignore = durableStore~appendJournal("RREGISTER", .array~of(routeId, source~name, routingKey, destination~name, mode, priority, allowCrossDomain, principal, rule~registeredAt))
  ignore = self~recordTrafficLocked("REGISTER_ROUTE", source~name, "", principal, routeId || ":" || destination~name, source~name, destination~name, .true)
  guard off
  return .QueueOperationResult~success(rule)

::method deregisterRoute
  expose routes durableStore
  use arg routeId, principal
  guard on
  found = .nil
  do rule over routes
    if rule~routeId = routeId then do
      found = rule
      leave
    end
  end
  if found == .nil then do
    guard off
    return .QueueOperationResult~failure("ROUTE_NOT_FOUND", routeId)
  end
  q = self~queue(found~sourceQueue)
  if q == .nil then do
    guard off
    return .QueueOperationResult~failure("ACCESS_DENIED", found~sourceQueue)
  end
  if \self~authorised(q, principal, .QueueAccess~MANAGE) then do
    guard off
    return .QueueOperationResult~failure("ACCESS_DENIED", found~sourceQueue)
  end
  keptRoutes = .array~new
  do rule over routes
    if rule~routeId \= routeId then keptRoutes~append(rule)
  end
  routes = keptRoutes
  if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT then ignore = durableStore~appendJournal("RDEREGISTER", .array~of(routeId))
  ignore = self~recordTrafficLocked("DEREGISTER_ROUTE", q~name, "", principal, routeId, found~sourceQueue, found~destinationQueue, .true)
  guard off
  return .QueueOperationResult~success(found)

::method validTriggerKind private
  use arg kind
  return kind = .QueueTriggerKind~PUT | kind = .QueueTriggerKind~GET | kind = .QueueTriggerKind~CLAIM | kind = .QueueTriggerKind~ACK | kind = .QueueTriggerKind~NACK | kind = .QueueTriggerKind~RELEASE | kind = .QueueTriggerKind~EXPIRE | kind = .QueueTriggerKind~BACKOUT | kind = .QueueTriggerKind~DEAD_LETTER | kind = .QueueTriggerKind~UOW_COMMIT | kind = .QueueTriggerKind~UOW_ROLLBACK | kind = .QueueTriggerKind~DEPTH_AT_LEAST | kind = .QueueTriggerKind~EMPTY | kind = .QueueTriggerKind~NONEMPTY

::method routeDecisionsLocked private
  expose routes
  use arg source, routingKey
  matching = .array~new
  redirects = .array~new
  copies = .array~new
  do rule over routes
    if rule~sourceQueue \= source~name then iterate
    if \rule~matches(routingKey) then iterate
    if rule~mode = .QueueRouteMode~REDIRECT then redirects~append(rule)
    else copies~append(rule)
  end
  if redirects~items > 1 then return .QueueOperationResult~failure("AMBIGUOUS_REDIRECT", source~name || ":" || routingKey)
  if redirects~items = 1 then do
    rule = redirects[1]
    destination = self~queue(rule~destinationQueue)
    if destination == .nil then return .QueueOperationResult~failure("ROUTE_DESTINATION_NOT_FOUND", rule~destinationQueue)
    matching~append(.array~of(destination, rule~allowCrossDomain))
  end
  else matching~append(.array~of(source, .false))

  /* Copies are deterministic by priority descending then route id. */
  if copies~items > 1 then copies~sortWith(.QueueRouteComparator~new)
  do rule over copies
    destination = self~queue(rule~destinationQueue)
    if destination == .nil then return .QueueOperationResult~failure("ROUTE_DESTINATION_NOT_FOUND", rule~destinationQueue)
    matching~append(.array~of(destination, rule~allowCrossDomain))
  end
  return .QueueOperationResult~success(matching)

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

::method deadLetterTargetLocked private
  expose deadLetterQueue
  use arg sourceQueue
  if deadLetterQueue = "" then return .nil
  target = self~queue(deadLetterQueue)
  if target == .nil then return .nil
  if target~name = sourceQueue~name then return .nil
  if target~securityDomain \= sourceQueue~securityDomain then return .nil
  if \target~canAccept then return .nil
  return target

::method backoutTargetLocked private
  use arg sourceQueue
  targetName = sourceQueue~backoutQueue
  if targetName = "" then return self~deadLetterTargetLocked(sourceQueue)
  target = self~queue(targetName)
  if target == .nil then return .nil
  if target~name = sourceQueue~name then return .nil
  if target~securityDomain \= sourceQueue~securityDomain then return .nil
  if \target~canAccept then return .nil
  return target

::method expireReadyLocked private
  expose authority packageIndex durableStore timeSource deadLetterQueue
  use arg q, principal
  count = 0
  events = .array~new
  if q~expiringDepth = 0 then return .array~of(count, events)
  if \timeSource~isExpired(q~earliestExpiryTick) then return .array~of(count, events)
  snapshot = q~packagesSnapshot(authority)
  do package over snapshot
    if package~state \= .QueuePackageState~READY then iterate
    if \package~isExpired(timeSource) then iterate
    beforeSource = q~readyDepth
    target = self~deadLetterTargetLocked(q)
    ignore = q~removePackage(package~packageId, authority)
    if target \== .nil then do
      beforeTarget = target~readyDepth
      ignore = package~moveToQueueInternal(target~name, "EXPIRED", q~name, authority)
      ignore = target~appendPackage(package, authority)
      ignore = self~journalMoveLocked(q, target, package)
      events~append(self~newTriggerEventLocked(q~name, .QueueTriggerKind~EXPIRE, beforeSource, q~readyDepth, package~packageId, principal))
      events~append(self~newTriggerEventLocked(target~name, .QueueTriggerKind~DEAD_LETTER, beforeTarget, target~readyDepth, package~packageId, principal))
      ignore = self~recordTrafficLocked("EXPIRE_DEAD_LETTER", q~name, package~packageId, principal, "destination=" || target~name, q~name, target~name, .true)
    end
    else do
      packageIndex~remove(package~packageId)
      ignore = package~markAcked(authority)
      if durableStore \== .nil & q~lifecycle = .QueueLifecycle~PERMANENT & package~persistent then ignore = durableStore~appendJournal("PREMOVE", .array~of(q~name, package~packageId))
      events~append(self~newTriggerEventLocked(q~name, .QueueTriggerKind~EXPIRE, beforeSource, q~readyDepth, package~packageId, principal))
      detail = "discarded"
      if deadLetterQueue \= "" then detail = "dead-letter unavailable; discarded"
      ignore = self~recordTrafficLocked("EXPIRE", q~name, package~packageId, principal, detail, q~name, "", .true)
    end
    count += 1
  end
  return .array~of(count, events)

::method newTriggerEventLocked private
  expose eventIdGenerator
  use arg queueName, eventType, beforeDepth, afterDepth, packageId, principal
  return .QueueTriggerEvent~new(eventIdGenerator~next, queueName, eventType, beforeDepth, afterDepth, packageId, principal)

::method dispatchEvents private
  expose triggers
  use arg events
  failures = .array~new
  do event over events
    regs = .array~new
    guard on
    do reg over triggers
      if reg~queueName \= event~queueName then iterate
      if reg~kind = .QueueTriggerKind~DEPTH_AT_LEAST | reg~kind = .QueueTriggerKind~EMPTY | reg~kind = .QueueTriggerKind~NONEMPTY then iterate
      if reg~matches(event) then regs~append(reg)
    end
    guard off
    do reg over regs
      invocation = reg~target~invoke(self, event)
      if \invocation~ok then do
        failures~append(reg~triggerId || ":" || invocation~code || ":" || invocation~detail)
        guard on
        ignore = self~recordTrafficLocked("TRIGGER_FAILED", event~queueName, event~packageId, event~principal, reg~triggerId || ":" || invocation~detail, event~queueName, event~queueName, .false)
        guard off
      end
      else do
        guard on
        ignore = self~recordTrafficLocked("TRIGGER_FIRED", event~queueName, event~packageId, event~principal, reg~triggerId, event~queueName, event~queueName, .true)
        guard off
      end
    end

    /* Edge triggers are evaluated against every mutation event. */
    edgeRegs = .array~new
    guard on
    do reg over triggers
      if reg~queueName \= event~queueName then iterate
      if reg~kind \= .QueueTriggerKind~DEPTH_AT_LEAST & reg~kind \= .QueueTriggerKind~EMPTY & reg~kind \= .QueueTriggerKind~NONEMPTY then iterate
      if reg~matches(event) then edgeRegs~append(reg)
    end
    guard off
    do reg over edgeRegs
      /* Avoid firing twice if an event itself somehow uses the edge kind. */
      if reg~kind = event~eventType then iterate
      invocation = reg~target~invoke(self, event)
      if \invocation~ok then failures~append(reg~triggerId || ":" || invocation~code || ":" || invocation~detail)
    end
  end
  return failures

::method packageFieldsLocked private
  expose payloadCodec
  use arg q, package
  signal on syntax name payloadEncodeFailure
  encodedHeaders = payloadCodec~encode(package~headers)
  encodedPayload = payloadCodec~encode(package~payload)
  signal off syntax
  return .array~of(q~name, package~packageId, package~priority, package~persistent, package~securityDomain, package~routingKey, package~correlationId, package~replyTo, package~requestedQueue, package~currentQueue, package~parentPackageId, package~createdAt, package~state, package~claimedBy, package~claimToken, package~claimedAt, package~deliveryCount, package~sequence, encodedHeaders, encodedPayload, package~expiryTick, package~backoutCount, package~deadLetterReason, package~deadLetterSourceQueue)
payloadEncodeFailure:
  signal off syntax
  raise syntax 88.900 array("Persistent package encoding failed: " || condition("D"))

::method packageRowLocked private
  use arg tag, q, package
  fields = self~packageFieldsLocked(q, package)
  row = .array~new
  row~append(tag)
  do field over fields
    row~append(field)
  end
  return row

::method journalRowsLocked private
  expose durableStore payloadCodec
  use arg rows
  if durableStore == .nil then return .true
  if rows~items = 0 then return .true
  encodedRows = payloadCodec~encode(rows)
  return durableStore~appendJournal("UOWCOMMIT", .array~of(encodedRows))

::method journalMoveLocked private
  expose durableStore
  use arg sourceQueue, destinationQueue, package
  if durableStore == .nil | \package~persistent then return .true
  rows = .array~new
  if sourceQueue~lifecycle = .QueueLifecycle~PERMANENT then rows~append(.array~of("PREMOVE", sourceQueue~name, package~packageId))
  if destinationQueue~lifecycle = .QueueLifecycle~PERMANENT then rows~append(self~packageRowLocked("PSTATE", destinationQueue, package))
  if rows~items = 0 then return .true
  return self~journalRowsLocked(rows)

::method journalPackageLocked private
  expose durableStore
  use arg tag, q, package
  fields = self~packageFieldsLocked(q, package)
  return durableStore~appendJournal(tag, fields)

::method recordTrafficLocked private
  expose traffic durableStore eventIdGenerator
  use arg eventType, queueName, packageId, principal, detail, sourceQueue, destinationQueue, success
  event = .QueueTrafficEvent~new(eventIdGenerator~next, eventType, queueName, packageId, principal, detail, sourceQueue, destinationQueue, success)
  traffic~append(event)
  if durableStore \== .nil then ignore = durableStore~appendTraffic(event)
  return event

::method recover private
  expose durableStore recovering recoveryWarnings traffic
  recovering = .true
  rows = durableStore~readJournal
  do row over rows
    signal on syntax name recoveryRecordError
    ignore = self~applyRecoveryRecord(row)
    signal off syntax
  end
  recovering = .false
  trafficRows = durableStore~readTraffic
  do row over trafficRows
    if row~items < 11 then iterate
    if row[1] \= "TRAFFIC" then iterate
    traffic~append(.QueueTrafficEvent~new(row[2], row[4], row[5], row[6], row[7], row[8], row[9], row[10], self~truth(row[11]), row[3]))
  end
  do warning over durableStore~recoveryWarnings
    recoveryWarnings~append(warning)
  end
  return .true
recoveryRecordError:
  signal off syntax
  recoveryWarnings~append(condition("D"))
  recovering = .false
  return .false

::method applyRecoveryRecord private
  expose queues queueOrder triggers routes packageIndex transferReceipts payloadCodec sequence authority deadLetterQueue
  use arg row
  tag = row[1]
  select
    when tag = "QCREATE" then do
      if row~items < 8 then return .false
      key = row[3]~translate
      if \queues~hasIndex(key) then do
        q = .QueueEndpoint~new(row[2], row[3], row[4], row[5], row[6], row[7], row[8], authority)
        queues[key] = q
        queueOrder~append(q)
      end
    end
    when tag = "QDELETE" then do
      q = self~queue(row[2])
      if q \== .nil then do
        queues~remove(q~name~translate)
        keptQueues = .array~new
        do existingQueue over queueOrder
          if existingQueue~name \= q~name then keptQueues~append(existingQueue)
        end
        queueOrder = keptQueues
        do package over q~packagesSnapshot(authority)
          packageIndex~remove(package~packageId)
        end
        keptTriggers = .array~new
        do reg over triggers
          if reg~queueName \= q~name then keptTriggers~append(reg)
        end
        triggers = keptTriggers
        keptRoutes = .array~new
        do rule over routes
          if rule~sourceQueue \= q~name & rule~destinationQueue \= q~name then keptRoutes~append(rule)
        end
        routes = keptRoutes
      end
    end
    when tag = "ACLALLOW" then do
      q = self~queue(row[2]); if q \== .nil then ignore = q~allowAccess(row[3], row[4], authority)
    end
    when tag = "ACLREVOKE" then do
      q = self~queue(row[2]); if q \== .nil then ignore = q~revokeAccess(row[3], row[4], authority)
    end
    when tag = "PPUT" | tag = "PSTATE" then do
      if row~items < 21 then return .false
      q = self~queue(row[2])
      if q == .nil then return .false
      existing = q~findPackage(row[3], authority)
      headers = payloadCodec~decode(row[20])
      payload = payloadCodec~decode(row[21])
      if existing \== .nil then do
        ignore = q~removePackage(existing~packageId, authority)
        packageIndex~remove(existing~packageId)
      end
      expiryTick = 0
      backoutCount = 0
      deadLetterReason = ""
      deadLetterSourceQueue = ""
      if row~items >= 22 then expiryTick = row[22]
      if row~items >= 23 then backoutCount = row[23]
      if row~items >= 24 then deadLetterReason = row[24]
      if row~items >= 25 then deadLetterSourceQueue = row[25]
      package = .QueueWorkPackage~new(row[3], payload, headers, row[4], self~truth(row[5]), row[6], row[7], row[8], row[9], row[10], row[11], row[12], row[13], row[19], authority, expiryTick, backoutCount, deadLetterReason, deadLetterSourceQueue)
      restoredState = row[14]
      restoredClaimedBy = row[15]
      restoredClaimToken = row[16]
      restoredClaimedAt = row[17]
      if restoredState = .QueuePackageState~INFLIGHT then do
        restoredState = .QueuePackageState~READY
        restoredClaimedBy = ""
        restoredClaimToken = ""
        restoredClaimedAt = ""
      end
      ignore = package~restoreDeliveryState(restoredState, restoredClaimedBy, restoredClaimToken, restoredClaimedAt, row[18], row[11], authority)
      ignore = package~restoreExtendedState(backoutCount, expiryTick, deadLetterReason, deadLetterSourceQueue, authority)
      ignore = q~appendPackage(package, authority)
      packageIndex[package~packageId] = package
      if row[19] > sequence then sequence = row[19]
    end
    when tag = "PREMOVE" then do
      q = self~queue(row[2])
      if q \== .nil then do
        ignore = q~removePackage(row[3], authority)
        packageIndex~remove(row[3])
      end
    end
    when tag = "QBACKOUT" then do
      if row~items < 4 then return .false
      q = self~queue(row[2])
      if q \== .nil then ignore = q~configureBackoutInternal(row[3], row[4], authority)
    end
    when tag = "MDEADLETTER" then do
      if row~items < 2 then return .false
      deadLetterQueue = row[2]
    end
    when tag = "UOWCOMMIT" then do
      if row~items < 2 then return .false
      operations = payloadCodec~decode(row[2])
      do operationRow over operations
        if operationRow~items = 0 then iterate
        if operationRow[1] = "UOWCOMMIT" then return .false
        ignore = self~applyRecoveryRecord(operationRow)
      end
    end
    when tag = "TRANSFERACCEPT" then do
      if row~items < 5 then return .false
      transferId = row[2]
      packageRow = payloadCodec~decode(row[3])
      if packageRow == .nil | packageRow~items < 3 then return .false
      if packageRow[1] \= "PPUT" then return .false
      ignore = self~applyRecoveryRecord(packageRow)
      transferReceipts[transferId] = .QueueTransferReceipt~new(transferId, packageRow[3], packageRow[2], row[4], row[5], .false)
    end
    when tag = "TREGISTER" then do
      if row~items < 10 then return .false
      q = self~queue(row[3])
      if q \== .nil then do
        target = .QueueRegistryTriggerTarget~new(row[6], row[7], row[8])
        triggers~append(.QueueTriggerRegistration~new(row[2], row[3], row[4], row[5], target, row[9], row[10]))
      end
    end
    when tag = "TDEREGISTER" then do
      keptTriggers = .array~new
      do reg over triggers
        if reg~triggerId \= row[2] then keptTriggers~append(reg)
      end
      triggers = keptTriggers
    end
    when tag = "RREGISTER" then do
      if row~items < 10 then return .false
      source = self~queue(row[3]); destination = self~queue(row[5])
      if source \== .nil & destination \== .nil then routes~append(.QueueRouteRule~new(row[2], row[3], row[4], row[5], row[6], row[7], self~truth(row[8]), row[9], row[10]))
    end
    when tag = "RDEREGISTER" then do
      keptRoutes = .array~new
      do rule over routes
        if rule~routeId \= row[2] then keptRoutes~append(rule)
      end
      routes = keptRoutes
    end
    otherwise nop
  end
  return .true

::method authorisedQueues
  expose queueOrder
  use arg principal
  rows = .array~new
  do q over queueOrder
    if self~authorised(q, principal, .QueueAccess~BROWSE) then rows~append(q)
  end
  return rows

::method authorisedPackages
  expose queueOrder authority
  use arg principal
  rows = .array~new
  do q over queueOrder
    if \self~authorised(q, principal, .QueueAccess~BROWSE) then iterate
    do package over q~packagesSnapshot(authority)
      rows~append(package)
    end
  end
  return rows

::method authorisedTriggers
  expose triggers
  use arg principal
  rows = .array~new
  do reg over triggers
    q = self~queue(reg~queueName)
    if q \== .nil then do
      if self~authorised(q, principal, .QueueAccess~BROWSE) then rows~append(reg)
    end
  end
  return rows

::method authorisedRoutes
  expose routes
  use arg principal
  rows = .array~new
  do route over routes
    q = self~queue(route~sourceQueue)
    if q \== .nil then do
      if self~authorised(q, principal, .QueueAccess~BROWSE) then rows~append(route)
    end
  end
  return rows

::method authorisedTransferReceipts
  expose transferReceipts
  use arg principal
  rows = .array~new
  supplier = transferReceipts~supplier
  do while supplier~available
    receipt = supplier~item
    q = self~queue(receipt~queueName)
    if q == .nil then do
      if self~isAdmin(principal) then rows~append(receipt)
    end
    else if self~authorised(q, principal, .QueueAccess~BROWSE) then rows~append(receipt)
    supplier~next
  end
  return rows

::method authorisedTraffic
  expose traffic
  use arg principal
  rows = .array~new
  do event over traffic
    q = self~queue(event~queueName)
    if q == .nil then do
      if self~isAdmin(principal) then rows~append(event)
    end
    else if self~authorised(q, principal, .QueueAccess~BROWSE) then rows~append(event)
  end
  return rows

::class QueueRouteComparator public
::method compare
  use arg left, right
  if left~priority > right~priority then return -1
  if left~priority < right~priority then return 1
  return left~routeId~compareTo(right~routeId)

::requires "AlchemyObject.cls"
