::class FederationBankExternalCashQueueEventSink subclass FederationBankExternalCashEventSink public
::method init
  expose manager queueName principal
  use arg managerArg,queueNameArg="FB.EXTERNAL.CASH.EVENTS",principalArg="fb-external-cash-service"
  manager=managerArg; queueName=queueNameArg~string; principal=principalArg~string
::method publish
  expose manager queueName principal
  use arg event
  o=.table~new; o["correlationId"]=event~correlationId; q=manager~queue(queueName); if q<>.nil then if q~lifecycle=.QueueLifecycle~PERMANENT then o["persistent"]=.true
  r=manager~put(queueName,event,o,principal); if r~ok then return .FederationBankExternalCashServiceResult~success(event); return .FederationBankExternalCashServiceResult~failure(r~code,r~detail)

::class FederationBankExternalCashQueueWorker public
::method init
  expose service manager commandQueue eventQueue principal adminPrincipal lifecycle
  use arg serviceArg,managerArg,commandQueueArg="FB.EXTERNAL.CASH.COMMANDS",eventQueueArg="FB.EXTERNAL.CASH.EVENTS",principalArg="fb-external-cash-service",adminPrincipalArg="queue-admin",lifecycleArg="TEMPORARY"
  service=serviceArg; manager=managerArg; commandQueue=commandQueueArg~string; eventQueue=eventQueueArg~string; principal=principalArg~string; adminPrincipal=adminPrincipalArg~string; lifecycle=lifecycleArg~string~upper
::method ensureQueue private
  expose manager adminPrincipal lifecycle
  use arg n
  if manager~queue(n)<>.nil then return .FederationBankExternalCashServiceResult~success(manager~queue(n))
  r=manager~createQueue(n,lifecycle,"FEDERATIONBANK_EXTERNAL_CASH",0,adminPrincipal); if r~ok then return .FederationBankExternalCashServiceResult~success(r~value); return .FederationBankExternalCashServiceResult~failure(r~code,r~detail)
::method install
  expose manager commandQueue eventQueue principal adminPrincipal
  r=self~ensureQueue(commandQueue); if \r~ok then return r; r=self~ensureQueue(eventQueue); if \r~ok then return r; ignore=manager~grant(commandQueue,principal,.QueueAccess~GET,adminPrincipal); ignore=manager~grant(commandQueue,principal,.QueueAccess~BROWSE,adminPrincipal); ignore=manager~grant(eventQueue,principal,.QueueAccess~PUT,adminPrincipal); return .FederationBankExternalCashServiceResult~success(self)
::method processOne
  expose service manager commandQueue principal
  c=manager~claim(commandQueue,principal); if \c~ok then return .FederationBankExternalCashServiceResult~failure(c~code,c~detail)
  pkg=c~value; env=pkg~payload
  if env==.nil | \env~isA(.FederationBankExternalCashServiceEnvelope) then do; ignore=manager~ack(commandQueue,pkg~packageId,pkg~claimToken,principal); return .FederationBankExternalCashServiceResult~failure("INVALID_EXTERNAL_CASH_COMMAND_PAYLOAD"); end
  reply=service~handle(env); a=manager~ack(commandQueue,pkg~packageId,pkg~claimToken,principal); if \a~ok then return .FederationBankExternalCashServiceResult~failure("COMMAND_ACK_FAILED",a~code); return .FederationBankExternalCashServiceResult~success(reply)
::requires "FederationBankExternalCashServicePersistence.cls"
