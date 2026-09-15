::class FederationBankBranchDayQueueEventSink subclass FederationBankBranchDayEventSink public
::method init
  expose manager queueName principal
  use arg managerArg,queueNameArg="FB.BRANCH.DAY.EVENTS",principalArg="fb-branch-day-service"
  manager=managerArg; queueName=queueNameArg~string; principal=principalArg~string
::method publish
  expose manager queueName principal
  use arg event
  options=.table~new; options["correlationId"]=event~correlationId; q=manager~queue(queueName); if q<>.nil then if q~lifecycle=.QueueLifecycle~PERMANENT then options["persistent"]=.true
  r=manager~put(queueName,event,options,principal); if r~ok then return .FederationBankBranchDayServiceResult~success(event); return .FederationBankBranchDayServiceResult~failure(r~code,r~detail)

::class FederationBankBranchDayQueueWorker public
::method init
  expose service manager commandQueue eventQueue principal adminPrincipal lifecycle
  use arg serviceArg,managerArg,commandQueueArg="FB.BRANCH.DAY.COMMANDS",eventQueueArg="FB.BRANCH.DAY.EVENTS",principalArg="fb-branch-day-service",adminPrincipalArg="queue-admin",lifecycleArg="TEMPORARY"
  service=serviceArg; manager=managerArg; commandQueue=commandQueueArg~string; eventQueue=eventQueueArg~string; principal=principalArg~string; adminPrincipal=adminPrincipalArg~string; lifecycle=lifecycleArg~string~upper
::method ensureQueue private
  expose manager adminPrincipal lifecycle
  use arg name
  if manager~queue(name)<>.nil then return .FederationBankBranchDayServiceResult~success(manager~queue(name))
  r=manager~createQueue(name,lifecycle,"FEDERATIONBANK_BRANCH_DAY",0,adminPrincipal); if r~ok then return .FederationBankBranchDayServiceResult~success(r~value); return .FederationBankBranchDayServiceResult~failure(r~code,r~detail)
::method install
  expose manager commandQueue eventQueue principal adminPrincipal
  r=self~ensureQueue(commandQueue); if \r~ok then return r; r=self~ensureQueue(eventQueue); if \r~ok then return r
  ignore=manager~grant(commandQueue,principal,.QueueAccess~GET,adminPrincipal); ignore=manager~grant(commandQueue,principal,.QueueAccess~BROWSE,adminPrincipal); ignore=manager~grant(eventQueue,principal,.QueueAccess~PUT,adminPrincipal); return .FederationBankBranchDayServiceResult~success(self)
::method processOne
  expose service manager commandQueue principal adminPrincipal
  claimed=manager~claim(commandQueue,principal); if \claimed~ok then return .FederationBankBranchDayServiceResult~failure(claimed~code,claimed~detail)
  package=claimed~value; env=package~payload
  if env==.nil | \env~isA(.FederationBankBranchDayServiceEnvelope) then do; ignore=manager~ack(commandQueue,package~packageId,package~claimToken,principal); return .FederationBankBranchDayServiceResult~failure("INVALID_BRANCH_DAY_COMMAND_PAYLOAD"); end
  reply=service~handle(env)
  if env~replyTo<>"" then do
    if manager~queue(env~replyTo)==.nil then ignore=manager~createQueue(env~replyTo,"TEMPORARY","FEDERATIONBANK_BRANCH_DAY",0,adminPrincipal)
    ignore=manager~grant(env~replyTo,principal,.QueueAccess~PUT,adminPrincipal); o=.table~new; o["correlationId"]=env~correlationId; pr=manager~put(env~replyTo,reply,o,principal); if \pr~ok then do; ignore=manager~nack(commandQueue,package~packageId,package~claimToken,principal); return .FederationBankBranchDayServiceResult~failure("REPLY_DELIVERY_FAILED",pr~code||":"||pr~detail); end
  end
  a=manager~ack(commandQueue,package~packageId,package~claimToken,principal); if \a~ok then return .FederationBankBranchDayServiceResult~failure("COMMAND_ACK_FAILED",a~code||":"||a~detail)
  return .FederationBankBranchDayServiceResult~success(reply)
::requires "FederationBankBranchDayServicePersistence.cls"
