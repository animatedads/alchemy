::class FederationBankRelationshipQueueEventSink subclass FederationBankRelationshipEventSink public
::method init
  expose manager queueName principal
  use arg managerArg,queueNameArg="FB.RELATIONSHIP.EVENTS",principalArg="fb-relationship-service"
  manager=managerArg; queueName=queueNameArg~string; principal=principalArg~string
::method publish
  expose manager queueName principal
  use arg event
  options=.table~new; options["correlationId"]=event~correlationId
  q=manager~queue(queueName); if q<>.nil then if q~lifecycle=.QueueLifecycle~PERMANENT then options["persistent"]=.true
  r=manager~put(queueName,event,options,principal)
  if r~ok then return .FederationBankRelationshipServiceResult~success(event)
  return .FederationBankRelationshipServiceResult~failure(r~code,r~detail)

::class FederationBankRelationshipQueueWorker public
::method init
  expose service manager commandQueue eventQueue principal adminPrincipal lifecycle
  use arg serviceArg,managerArg,commandQueueArg="FB.RELATIONSHIP.COMMANDS",eventQueueArg="FB.RELATIONSHIP.EVENTS",principalArg="fb-relationship-service",adminPrincipalArg="queue-admin",lifecycleArg="TEMPORARY"
  service=serviceArg; manager=managerArg; commandQueue=commandQueueArg~string; eventQueue=eventQueueArg~string; principal=principalArg~string; adminPrincipal=adminPrincipalArg~string; lifecycle=lifecycleArg~string~upper
::method install
  expose manager commandQueue eventQueue principal adminPrincipal
  r=self~ensureQueue(commandQueue); if \r~ok then return r
  r=self~ensureQueue(eventQueue); if \r~ok then return r
  ignore=manager~grant(commandQueue,principal,.QueueAccess~GET,adminPrincipal); ignore=manager~grant(commandQueue,principal,.QueueAccess~BROWSE,adminPrincipal); ignore=manager~grant(eventQueue,principal,.QueueAccess~PUT,adminPrincipal)
  return .FederationBankRelationshipServiceResult~success(self)
::method ensureQueue private
  expose manager adminPrincipal lifecycle
  use arg name
  if manager~queue(name)<>.nil then return .FederationBankRelationshipServiceResult~success(manager~queue(name))
  r=manager~createQueue(name,lifecycle,"FEDERATIONBANK_RELATIONSHIP",0,adminPrincipal)
  if r~ok then return .FederationBankRelationshipServiceResult~success(r~value)
  return .FederationBankRelationshipServiceResult~failure(r~code,r~detail)
::method processOne
  expose service manager commandQueue principal adminPrincipal
  claimed=manager~claim(commandQueue,principal); if \claimed~ok then return .FederationBankRelationshipServiceResult~failure(claimed~code,claimed~detail)
  package=claimed~value; envelope=package~payload
  if envelope==.nil | \envelope~isA(.FederationBankRelationshipServiceEnvelope) then do; ignore=manager~ack(commandQueue,package~packageId,package~claimToken,principal); return .FederationBankRelationshipServiceResult~failure("INVALID_FBREL_COMMAND_PAYLOAD"); end
  reply=service~handle(envelope)
  if envelope~replyTo<>"" then do
    if manager~queue(envelope~replyTo)==.nil then ignore=manager~createQueue(envelope~replyTo,"TEMPORARY","FEDERATIONBANK_RELATIONSHIP",0,adminPrincipal)
    ignore=manager~grant(envelope~replyTo,principal,.QueueAccess~PUT,adminPrincipal); options=.table~new; options["correlationId"]=envelope~correlationId; putReply=manager~put(envelope~replyTo,reply,options,principal)
    if \putReply~ok then do; ignore=manager~nack(commandQueue,package~packageId,package~claimToken,principal); return .FederationBankRelationshipServiceResult~failure("REPLY_DELIVERY_FAILED",putReply~code||":"||putReply~detail); end
  end
  acked=manager~ack(commandQueue,package~packageId,package~claimToken,principal); if \acked~ok then return .FederationBankRelationshipServiceResult~failure("COMMAND_ACK_FAILED",acked~code||":"||acked~detail)
  return .FederationBankRelationshipServiceResult~success(reply)
::requires "FederationBankRelationshipServicePersistence.cls"
