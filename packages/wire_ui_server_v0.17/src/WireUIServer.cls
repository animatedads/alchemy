/* Queue Fabric adapter: direct queues for live communications; topics only for definition wiring. */
::requires "WireUIProtocol.cls"
::requires "ObjectQueueFabric.cls"
::requires "ObjectQueueTopics.cls"

::class WireUIServer subclass AlchemyObject public
::method init
  expose queueManager topicFabric applications adminPrincipal
  use arg queueManager, topicFabric = .nil, adminPrincipal = "admin"
  self~init:super(.WireUIAlchemy~metadata("Queue Fabric adapter for Wire UI live and definition channels"))
  if topicFabric == .nil then topicFabric = .QueueTopicFabric~new(queueManager)
  applications = .table~new

::method registerApplication
  expose applications
  use arg app
  applications[app~applicationId] = app
  return app

::method directQueueName
  use arg accessPointId, direction
  return "WIREUI."direction~translate"."accessPointId~translate

::method provisionAccessPoint
  expose queueManager adminPrincipal
  use arg accessPointId, principal
  inq = self~directQueueName(accessPointId, "IN")
  outq = self~directQueueName(accessPointId, "OUT")
  if queueManager~queue(inq) == .nil then ignore = queueManager~createQueue(inq, "TEMPORARY", "WIREUI", 0, adminPrincipal)
  if queueManager~queue(outq) == .nil then ignore = queueManager~createQueue(outq, "TEMPORARY", "WIREUI", 0, adminPrincipal)
  ignore = queueManager~grant(inq, principal, .QueueAccess~PUT, adminPrincipal)
  ignore = queueManager~grant(outq, principal, .QueueAccess~GET, adminPrincipal)
  ignore = queueManager~grant(outq, principal, .QueueAccess~BROWSE, adminPrincipal)
  return .WireUIResult~success(.array~of(inq, outq))

::method enqueueToAccessPoint
  expose queueManager adminPrincipal
  use arg accessPointId, message, correlationId = ""
  options = .table~new
  options["correlationId"] = correlationId
  return queueManager~put(self~directQueueName(accessPointId, "OUT"), message, options, adminPrincipal)

::method receiveFromAccessPoint
  expose queueManager applications adminPrincipal
  use arg accessPointId, principal
  inq = self~directQueueName(accessPointId, "IN")
  claim = queueManager~claim(inq, adminPrincipal)
  if \claim~ok then return .WireUIResult~failure(claim~code, claim~detail)
  package = claim~value
  message = package~payload
  appId = self~field(message, "applicationId", "")
  app = applications[appId]
  if app == .nil then result = .WireUIResult~failure("APPLICATION_NOT_FOUND", appId)
  else result = app~receive(message)
  ignore = queueManager~ack(inq, package~packageId, package~claimToken, adminPrincipal)
  return result

::method definitionQueueName
  use arg accessPointId
  return "WIREUI.DEF."accessPointId~translate

::method provisionDefinitionSubscription
  expose queueManager topicFabric adminPrincipal
  use arg accessPointId, principal
  qname = self~definitionQueueName(accessPointId)
  if queueManager~queue(qname) == .nil then ignore = queueManager~createQueue(qname, "TEMPORARY", "WIREUI", 0, adminPrincipal)
  ignore = queueManager~grant(qname, principal, .QueueAccess~GET, adminPrincipal)
  ignore = queueManager~grant(qname, principal, .QueueAccess~BROWSE, adminPrincipal)
  if topicFabric~topic("WIREUI.DEFINITIONS") == .nil then do
    r = topicFabric~defineTopic("WIREUI.DEFINITIONS", "wireui/definitions", "TEMPORARY", "WIREUI", adminPrincipal)
    if \r~ok then return .WireUIResult~failure(r~code, r~detail)
  end
  return .WireUIResult~success(qname)

::method syncDefinitionSubscriptions
  expose applications topicFabric adminPrincipal
  use arg applicationId
  app = applications[applicationId]
  if app == .nil then return .WireUIResult~failure("APPLICATION_NOT_FOUND", applicationId)
  qname = self~definitionQueueName(app~accessPointId)
  desired = .set~new
  prefix = "WUI."applicationId"."
  do sub over app~activeSubscriptions
    do defId over sub~definitionIds
      sid = prefix||sub~subscriptionId"."defId
      desired~put(sid~translate)
      if topicFabric~subscription(sid) == .nil then do
        r = topicFabric~subscribe(sid, "WIREUI.DEFINITIONS", defId, qname, "TEMPORARY", adminPrincipal)
        if \r~ok then return .WireUIResult~failure(r~code, r~detail)
      end
    end
  end
  existing = topicFabric~subscriptions
  do current over existing
    if current~name~left(prefix~length)~translate = prefix~translate then do
      if \desired~hasIndex(current~name~translate) then do
        r = topicFabric~unsubscribe(current~name, adminPrincipal)
        if \r~ok then return .WireUIResult~failure(r~code, r~detail)
      end
    end
  end
  return .WireUIResult~success(.true)

::method publishRequiredDefinitions
  expose applications topicFabric adminPrincipal
  use arg applicationId, cachedManifest = .nil
  app = applications[applicationId]
  if app == .nil then return .WireUIResult~failure("APPLICATION_NOT_FOUND", applicationId)
  sync = self~syncDefinitionSubscriptions(applicationId)
  if \sync~ok then return sync
  defs = app~requiredDefinitions(cachedManifest)
  receipts = .array~new
  do def over defs
    options = .table~new
    options["subtopic"] = def["definitionKey"]
    options["correlationId"] = applicationId"/"def["contentAddress"]
    r = topicFabric~publish("WIREUI.DEFINITIONS", def, options, adminPrincipal)
    if \r~ok then return .WireUIResult~failure(r~code, r~detail)
    receipts~append(r~value)
  end
  return .WireUIResult~success(receipts)

::method offerDefinitions
  expose applications
  use arg applicationId, cachedManifest = .nil
  app = applications[applicationId]
  if app == .nil then return .WireUIResult~failure("APPLICATION_NOT_FOUND", applicationId)
  defs = app~requiredDefinitions(cachedManifest)
  fields = .table~new
  fields["applicationId"] = applicationId
  fields["definitions"] = defs
  releaseContext=app~siteReleaseContext
  if releaseContext\==.nil then fields["siteRelease"]=releaseContext
  return .WireUIResult~success(.WireUIProtocol~message(.WireUIProtocol~UI_DEFINITION_REQUIRED, fields))

::method offerMaterials
  expose applications
  use arg applicationId
  app=applications[applicationId]
  if app==.nil then return .WireUIResult~failure("APPLICATION_NOT_FOUND",applicationId)
  return app~materialSetMessages

::method enqueueMaterialsToAccessPoint
  expose applications
  use arg applicationId
  app=applications[applicationId]
  if app==.nil then return .WireUIResult~failure("APPLICATION_NOT_FOUND",applicationId)
  r=app~materialSetMessages
  if \r~ok then return r
  receipts=.array~new
  do message over r~value
    q=self~enqueueToAccessPoint(app~accessPointId,message,applicationId"/material")
    if \q~ok then return .WireUIResult~failure(q~code,q~detail)
    receipts~append(q~value)
  end
  return .WireUIResult~success(receipts,"MATERIAL_SETS_ENQUEUED")

::method field private
  use arg table, key, default = .nil
  if table~hasIndex(key) then return table[key]
  return default

::requires "WireUIAlchemy.cls"
