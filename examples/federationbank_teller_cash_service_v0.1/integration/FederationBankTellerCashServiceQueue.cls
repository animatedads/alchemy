/* Queue Fabric command/event boundary for Teller Cash Service v0.1. */

::class FederationBankTellerCashQueueEventSink subclass FederationBankTellerCashEventSink public
::method init
  expose manager queueName principal
  use arg managerArg,queueNameArg="FB.TELLER.CASH.EVENTS",principalArg="fb-teller-cash-service"
  manager=managerArg; queueName=queueNameArg~string; principal=principalArg~string
::method publish
  expose manager queueName principal
  use arg event
  options=.table~new; options["correlationId"]=event~correlationId
  q=manager~queue(queueName); if q<>.nil then if q~lifecycle=.QueueLifecycle~PERMANENT then options["persistent"]=.true
  r=manager~put(queueName,event,options,principal)
  if r~ok then return .FederationBankTellerCashServiceResult~success(event)
  return .FederationBankTellerCashServiceResult~failure(r~code,r~detail)

::class FederationBankTellerCashQueueWorker public
::method init
  expose service manager commandQueue eventQueue principal adminPrincipal lifecycle
  use arg serviceArg,managerArg,commandQueueArg="FB.TELLER.CASH.COMMANDS",eventQueueArg="FB.TELLER.CASH.EVENTS",principalArg="fb-teller-cash-service",adminPrincipalArg="queue-admin",lifecycleArg="TEMPORARY"
  service=serviceArg; manager=managerArg; commandQueue=commandQueueArg~string; eventQueue=eventQueueArg~string; principal=principalArg~string; adminPrincipal=adminPrincipalArg~string; lifecycle=lifecycleArg~string~upper
::method ensureQueue private
  expose manager adminPrincipal lifecycle
  use arg name
  if manager~queue(name)<>.nil then return .FederationBankTellerCashServiceResult~success(manager~queue(name))
  r=manager~createQueue(name,lifecycle,"FEDERATIONBANK_TELLER_CASH",0,adminPrincipal)
  if r~ok then return .FederationBankTellerCashServiceResult~success(r~value)
  return .FederationBankTellerCashServiceResult~failure(r~code,r~detail)
::method install
  expose manager commandQueue eventQueue principal adminPrincipal
  r=self~ensureQueue(commandQueue); if \r~ok then return r
  r=self~ensureQueue(eventQueue); if \r~ok then return r
  ignore=manager~grant(commandQueue,principal,.QueueAccess~GET,adminPrincipal); ignore=manager~grant(commandQueue,principal,.QueueAccess~BROWSE,adminPrincipal); ignore=manager~grant(eventQueue,principal,.QueueAccess~PUT,adminPrincipal)
  return .FederationBankTellerCashServiceResult~success(self)
::method processOne
  expose service manager commandQueue principal adminPrincipal
  claimed=manager~claim(commandQueue,principal); if \claimed~ok then return .FederationBankTellerCashServiceResult~failure(claimed~code,claimed~detail)
  package=claimed~value; env=package~payload
  if env==.nil | \env~isA(.FederationBankTellerCashServiceEnvelope) then do; ignore=manager~ack(commandQueue,package~packageId,package~claimToken,principal); return .FederationBankTellerCashServiceResult~failure("INVALID_FBTELCASH_COMMAND_PAYLOAD"); end
  reply=service~handle(env)
  if env~replyTo<>"" then do
    if manager~queue(env~replyTo)==.nil then ignore=manager~createQueue(env~replyTo,"TEMPORARY","FEDERATIONBANK_TELLER_CASH",0,adminPrincipal)
    ignore=manager~grant(env~replyTo,principal,.QueueAccess~PUT,adminPrincipal); options=.table~new; options["correlationId"]=env~correlationId; putReply=manager~put(env~replyTo,reply,options,principal)
    if \putReply~ok then do; ignore=manager~nack(commandQueue,package~packageId,package~claimToken,principal); return .FederationBankTellerCashServiceResult~failure("REPLY_DELIVERY_FAILED",putReply~code||":"||putReply~detail); end
  end
  acked=manager~ack(commandQueue,package~packageId,package~claimToken,principal); if \acked~ok then return .FederationBankTellerCashServiceResult~failure("COMMAND_ACK_FAILED",acked~code||":"||acked~detail)
  return .FederationBankTellerCashServiceResult~success(reply)

::requires "FederationBankTellerCashServicePersistence.cls"
