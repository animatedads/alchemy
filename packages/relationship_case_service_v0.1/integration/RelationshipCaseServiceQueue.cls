/* Queue Fabric command/event adapter. Transport does not own case semantics. */
::class RelationshipCaseQueueEventSink subclass RelationshipCaseEventSink public
::method init
  expose manager queueName principal
  use arg managerArg, queueNameArg = "RELATIONSHIP.CASE.EVENTS", principalArg = "relationship-case-service"
  manager = managerArg; queueName = queueNameArg~string; principal = principalArg~string
::method publish
  expose manager queueName principal
  use arg event
  options = .table~new; options["correlationId"] = event~correlationId
  q = manager~queue(queueName)
  if q <> .nil then do
    if q~lifecycle = .QueueLifecycle~PERMANENT then options["persistent"] = .true
  end
  result = manager~put(queueName, event, options, principal)
  if result~ok then return .RelationshipCaseServiceResult~success(event)
  return .RelationshipCaseServiceResult~failure(result~code, result~detail)

::class RelationshipCaseQueueWorker public
::attribute commandQueue get
::attribute eventQueue get
::attribute principal get
::method init
  expose service manager commandQueue eventQueue principal adminPrincipal lifecycle
  use arg serviceArg, managerArg, commandQueueArg = "RELATIONSHIP.CASE.COMMANDS", eventQueueArg = "RELATIONSHIP.CASE.EVENTS", principalArg = "relationship-case-service", adminPrincipalArg = "queue-admin", lifecycleArg = "TEMPORARY"
  service = serviceArg; manager = managerArg; commandQueue = commandQueueArg~string; eventQueue = eventQueueArg~string; principal = principalArg~string; adminPrincipal = adminPrincipalArg~string; lifecycle = lifecycleArg~string~upper
::method install
  expose manager commandQueue eventQueue principal adminPrincipal lifecycle
  result = self~ensureQueue(commandQueue); if \result~ok then return result
  result = self~ensureQueue(eventQueue); if \result~ok then return result
  ignore = manager~grant(commandQueue, principal, .QueueAccess~GET, adminPrincipal)
  ignore = manager~grant(commandQueue, principal, .QueueAccess~BROWSE, adminPrincipal)
  ignore = manager~grant(eventQueue, principal, .QueueAccess~PUT, adminPrincipal)
  return .RelationshipCaseServiceResult~success(self)
::method ensureQueue private
  expose manager adminPrincipal lifecycle
  use arg name
  if manager~queue(name) <> .nil then return .RelationshipCaseServiceResult~success(manager~queue(name))
  result = manager~createQueue(name, lifecycle, "RELATIONSHIP_CASE", 0, adminPrincipal)
  if result~ok then return .RelationshipCaseServiceResult~success(result~value)
  return .RelationshipCaseServiceResult~failure(result~code, result~detail)
::method processOne
  expose service manager commandQueue principal adminPrincipal
  claimed = manager~claim(commandQueue, principal)
  if \claimed~ok then return .RelationshipCaseServiceResult~failure(claimed~code, claimed~detail)
  package = claimed~value; envelope = package~payload
  if envelope == .nil | \envelope~isA(.RelationshipCaseServiceEnvelope) then do
    ignore = manager~ack(commandQueue, package~packageId, package~claimToken, principal)
    return .RelationshipCaseServiceResult~failure("INVALID_CASE_COMMAND_PAYLOAD")
  end
  reply = service~handle(envelope)
  if envelope~replyTo <> "" then do
    if manager~queue(envelope~replyTo) == .nil then ignore = manager~createQueue(envelope~replyTo, "TEMPORARY", "RELATIONSHIP_CASE", 0, adminPrincipal)
    ignore = manager~grant(envelope~replyTo, principal, .QueueAccess~PUT, adminPrincipal)
    options = .table~new; options["correlationId"] = envelope~correlationId
    putReply = manager~put(envelope~replyTo, reply, options, principal)
    if \putReply~ok then do
      ignore = manager~nack(commandQueue, package~packageId, package~claimToken, principal)
      return .RelationshipCaseServiceResult~failure("REPLY_DELIVERY_FAILED", putReply~code || ":" || putReply~detail)
    end
  end
  acked = manager~ack(commandQueue, package~packageId, package~claimToken, principal)
  if \acked~ok then return .RelationshipCaseServiceResult~failure("COMMAND_ACK_FAILED", acked~code || ":" || acked~detail)
  return .RelationshipCaseServiceResult~success(reply)

::requires "RelationshipCaseServicePersistence.cls"
