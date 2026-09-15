::class RelationshipCRMQueueEventSink subclass RelationshipCRMEventSink public
::method init
  expose manager queueName principal
  use arg managerArg,queueNameArg="RELATIONSHIP.CRM.EVENTS",principalArg="relationship-crm-service"
  manager=managerArg; queueName=queueNameArg~string; principal=principalArg~string
::method publish
  expose manager queueName principal
  use arg e
  options=.table~new; options["correlationId"]=e~correlationId
  q=manager~queue(queueName); if q<>.nil then if q~lifecycle=.QueueLifecycle~PERMANENT then options["persistent"]=.true
  rr=manager~put(queueName,e,options,principal); if rr~ok then return .RelationshipCRMServiceResult~success(e)
  return .RelationshipCRMServiceResult~failure(rr~code,rr~detail)

::class RelationshipCRMQueueWorker public
::method init
  expose service manager commandQueue eventQueue principal adminPrincipal lifecycle
  use arg serviceArg,managerArg,commandQueueArg="RELATIONSHIP.CRM.COMMANDS",eventQueueArg="RELATIONSHIP.CRM.EVENTS",principalArg="relationship-crm-service",adminPrincipalArg="queue-admin",lifecycleArg="TEMPORARY"
  service=serviceArg; manager=managerArg; commandQueue=commandQueueArg~string; eventQueue=eventQueueArg~string; principal=principalArg~string; adminPrincipal=adminPrincipalArg~string; lifecycle=lifecycleArg~string~upper
::method install
  expose manager commandQueue eventQueue principal adminPrincipal
  rr=self~ensureQueue(commandQueue); if \rr~ok then return rr
  rr=self~ensureQueue(eventQueue); if \rr~ok then return rr
  ignore=manager~grant(commandQueue,principal,.QueueAccess~GET,adminPrincipal); ignore=manager~grant(commandQueue,principal,.QueueAccess~BROWSE,adminPrincipal); ignore=manager~grant(eventQueue,principal,.QueueAccess~PUT,adminPrincipal)
  return .RelationshipCRMServiceResult~success(self)
::method ensureQueue private
  expose manager adminPrincipal lifecycle
  use arg name
  if manager~queue(name)<>.nil then return .RelationshipCRMServiceResult~success(manager~queue(name))
  rr=manager~createQueue(name,lifecycle,"RELATIONSHIP_CRM",0,adminPrincipal); if rr~ok then return .RelationshipCRMServiceResult~success(rr~value); return .RelationshipCRMServiceResult~failure(rr~code,rr~detail)
::method processOne
  expose service manager commandQueue principal adminPrincipal
  claimed=manager~claim(commandQueue,principal); if \claimed~ok then return .RelationshipCRMServiceResult~failure(claimed~code,claimed~detail)
  pkg=claimed~value; env=pkg~payload
  if env==.nil | \env~isA(.RelationshipCRMServiceEnvelope) then do; ignore=manager~ack(commandQueue,pkg~packageId,pkg~claimToken,principal); return .RelationshipCRMServiceResult~failure("INVALID_CRM_COMMAND_PAYLOAD"); end
  reply=service~handle(env)
  if env~replyTo<>"" then do
    if manager~queue(env~replyTo)==.nil then ignore=manager~createQueue(env~replyTo,"TEMPORARY","RELATIONSHIP_CRM",0,adminPrincipal)
    ignore=manager~grant(env~replyTo,principal,.QueueAccess~PUT,adminPrincipal); options=.table~new; options["correlationId"]=env~correlationId; put=manager~put(env~replyTo,reply,options,principal)
    if \put~ok then do; ignore=manager~nack(commandQueue,pkg~packageId,pkg~claimToken,principal); return .RelationshipCRMServiceResult~failure("REPLY_DELIVERY_FAILED",put~code||":"||put~detail); end
  end
  acked=manager~ack(commandQueue,pkg~packageId,pkg~claimToken,principal); if \acked~ok then return .RelationshipCRMServiceResult~failure("COMMAND_ACK_FAILED",acked~code||":"||acked~detail)
  return .RelationshipCRMServiceResult~success(reply)
::requires "RelationshipCRMServicePersistence.cls"
