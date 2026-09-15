/* Object Queue Fabric wiring for Shannon.
 * Rich turn/audit objects remain objects inside the fabric.
 *
 * v0.7 consumes the queue/topic/NoSQL surfaces it actually uses and records
 * the loaded implementation/API identities.  Runtime release numbers are not
 * authority and are deliberately not hard-pinned here.
 * projection.  The SQL projection is derived/index material; the queued rich
 * audit object remains authoritative evidence.
 */

::class ShannonQueueService public
::attribute manager get
::attribute session get
::attribute triggerRegistration get
::attribute auditCatalog get
::attribute topicBus get

::method init
  expose manager session triggerRegistration worker auditCatalog topicBus
  use arg sessionArg, storeRoot = ''
  session = sessionArg

  manager = .ObjectQueueManager~new(storeRoot, .QueueGraphPayloadCodec~new, 'shannon-admin')
  auditCatalog = .ShannonAuditCatalog~new

  ignored = self~must(manager~createQueue('SHANNON.INBOUND', 'TEMPORARY', 'OURLADYAIR.CHAT', 100, 'shannon-admin'), 'create inbound')
  ignored = self~must(manager~createQueue('SHANNON.OUTBOUND', 'TEMPORARY', 'OURLADYAIR.CHAT', 100, 'shannon-admin'), 'create outbound')
  ignored = self~must(manager~createQueue('SHANNON.AUDIT', 'TEMPORARY', 'OURLADYAIR.AUDIT', 100, 'shannon-admin'), 'create audit')

  ignored = self~must(manager~grant('SHANNON.INBOUND', 'passenger', .QueueAccess~PUT, 'shannon-admin'), 'grant passenger input')
  ignored = self~must(manager~grant('SHANNON.INBOUND', 'shannon-worker', .QueueAccess~GET, 'shannon-admin'), 'grant worker input')
  ignored = self~must(manager~grant('SHANNON.OUTBOUND', 'shannon-worker', .QueueAccess~PUT, 'shannon-admin'), 'grant worker output')
  ignored = self~must(manager~grant('SHANNON.OUTBOUND', 'passenger', .QueueAccess~GET, 'shannon-admin'), 'grant passenger output')
  ignored = self~must(manager~grant('SHANNON.OUTBOUND', 'passenger', .QueueAccess~BROWSE, 'shannon-admin'), 'grant passenger output browse')
  ignored = self~must(manager~grant('SHANNON.AUDIT', 'shannon-worker', .QueueAccess~PUT, 'shannon-admin'), 'grant worker audit')
  ignored = self~must(manager~grant('SHANNON.AUDIT', 'auditor', .QueueAccess~BROWSE, 'shannon-admin'), 'grant auditor browse')
  ignored = self~must(manager~grant('SHANNON.AUDIT', 'auditor', .QueueAccess~GET, 'shannon-admin'), 'grant auditor get')

  topicBus = .ShannonTopicBus~new(manager)

  worker = .ShannonQueueWorker~new(manager, session, auditCatalog, topicBus)
  registration = manager~registerTrigger('SHANNON.INBOUND', .QueueTriggerKind~NONEMPTY, .QueueDirectTriggerTarget~new(worker, 'onQueueTrigger'), 0, 'shannon-admin')
  ignored = self~must(registration, 'register Shannon trigger')
  triggerRegistration = registration~value

::method submit
  expose manager
  use arg text
  payload = .directory~new
  payload['kind'] = 'PASSENGER_TURN'
  payload['text'] = text~string
  options = .table~new
  options['correlationId'] = .DateTime~new~string
  return manager~put('SHANNON.INBOUND', payload, options, 'passenger')

::method receive
  expose manager
  return manager~get('SHANNON.OUTBOUND', 'passenger')

::method auditDepth
  expose manager
  depthOperation = manager~depth('SHANNON.AUDIT', 'auditor')
  if \depthOperation~ok then return -1
  return depthOperation~value['total']

::method getAudit
  expose manager
  return manager~get('SHANNON.AUDIT', 'auditor')

::method queryAudit
  expose auditCatalog
  use arg sqlText
  return auditCatalog~query(sqlText)

::method queueFabricVersion
  return .QueueFabricBuild~VERSION

::method queueFabricApi
  return .QueueFabricBuild~API

::method noSQLServerVersion
  return .NoSQLServerBuild~RELEASE

::method must private
  use arg operationResult, label
  if \operationResult~ok then raise syntax 88.900 array(label || ': ' || operationResult~code || ' ' || operationResult~detail)
  return operationResult

::class ShannonQueueWorker public
::attribute processed get

::method init
  expose manager session processed busy auditCatalog topicBus
  use arg managerArg, sessionArg, auditCatalogArg, topicBusArg
  manager = managerArg
  session = sessionArg
  auditCatalog = auditCatalogArg
  topicBus = topicBusArg
  processed = 0
  busy = .false

::method onQueueTrigger
  expose manager session processed busy auditCatalog topicBus
  use arg event
  if busy then return .true
  busy = .true
  do forever
    claim = manager~claim('SHANNON.INBOUND', 'shannon-worker')
    if \claim~ok then leave
    package = claim~value
    payload = package~payload
    turnResult = session~respond(payload['text'])

    outbound = .directory~new
    outbound['kind'] = 'SHANNON_REPLY'
    outbound['turn'] = turnResult~turnNumber
    outbound['text'] = turnResult~finalText
    outbound['mode'] = turnResult~mode
    outbound['result'] = turnResult
    putOut = manager~put('SHANNON.OUTBOUND', outbound, .nil, 'shannon-worker')
    if \putOut~ok then raise syntax 88.900 array('outbound put failed:' putOut~code)

    audit = turnResult~auditRecord
    queueView = .directory~new
    queueView['fabricVersion'] = .QueueFabricBuild~VERSION
    queueView['fabricApi'] = .QueueFabricBuild~API
    queueView['auditProjection'] = 'NoSQLServer/' || .NoSQLServerBuild~RELEASE
    queueView['projectionAuthority'] = 'DERIVED_INDEX_ONLY'
    queueView['topicRoutingAuthority'] = 'DERIVED_EVENT_ROUTING_ONLY'
    audit['queue'] = queueView

    topicOperation = topicBus~publishGovernedTurn(audit)
    if topicOperation~ok then do
      queueView['topicPublication'] = 'PUBLISHED'
      queueView['topicClassification'] = topicOperation~value['classification']
    end
    else do
      /* Observer-topic failure is evidence, not authority over the passenger
         response.  Queue/audit processing continues and records the failure. */
      queueView['topicPublication'] = 'FAILED'
      queueView['topicPublicationCode'] = topicOperation~code
      queueView['topicPublicationDetail'] = topicOperation~detail
    end

    putAudit = manager~put('SHANNON.AUDIT', audit, .nil, 'shannon-worker')
    if \putAudit~ok then raise syntax 88.900 array('audit put failed:' putAudit~code)

    /* Derived management/index projection.  The queue object above is the
       evidence source; this projection does not control ACK or governance. */
    ignored = auditCatalog~indexAudit(audit)

    ack = manager~ack('SHANNON.INBOUND', package~packageId, package~claimToken, 'shannon-worker')
    if \ack~ok then raise syntax 88.900 array('input ack failed:' ack~code)
    processed += 1
  end
  busy = .false
  return .true

::requires 'ShannonChatbot.cls'
::requires 'ShannonAuditCatalog.cls'
::requires 'ShannonTopicBus.cls'
::requires 'ObjectQueueFabric.cls'
