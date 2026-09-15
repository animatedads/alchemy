::class FederationBankMerchantRiskQueueWorker public
::method init
  expose service manager commandQueue eventQueue principal adminPrincipal
  use arg serviceArg,managerArg,commandQueueArg="MERCHANT.RISK.COMMANDS",eventQueueArg="MERCHANT.RISK.EVENTS",principalArg="merchant-risk-service",adminPrincipalArg="queue-admin"
  service=serviceArg; manager=managerArg; commandQueue=commandQueueArg; eventQueue=eventQueueArg; principal=principalArg; adminPrincipal=adminPrincipalArg
::method install
  expose manager commandQueue eventQueue principal adminPrincipal
  if manager~queue(commandQueue)==.nil then do; rr=manager~createQueue(commandQueue,"TEMPORARY","MERCHANT_RISK",0,adminPrincipal); if \rr~ok then return rr; end
  if manager~queue(eventQueue)==.nil then do; rr=manager~createQueue(eventQueue,"TEMPORARY","MERCHANT_RISK",0,adminPrincipal); if \rr~ok then return rr; end
  ignore=manager~grant(commandQueue,principal,.QueueAccess~GET,adminPrincipal); ignore=manager~grant(commandQueue,principal,.QueueAccess~BROWSE,adminPrincipal); ignore=manager~grant(eventQueue,principal,.QueueAccess~PUT,adminPrincipal)
  return .MBRiskServiceResult~success(self)
::method processOne
  expose service manager commandQueue eventQueue principal adminPrincipal
  claimed=manager~claim(commandQueue,principal); if \claimed~ok then return .MBRiskServiceResult~failure(claimed~code,claimed~detail)
  pkg=claimed~value; env=pkg~payload
  if env==.nil | \env~isA(.MBRiskServiceEnvelope) then do; ignore=manager~ack(commandQueue,pkg~packageId,pkg~claimToken,principal); return .MBRiskServiceResult~failure("INVALID_RISK_COMMAND_PAYLOAD"); end
  before=service~state~events~items
  reply=service~handle(env)
  after=service~state~events~items
  do i=before+1 to after
    e=service~state~events[i]; opts=.table~new; opts["correlationId"]=env~correlationId; put=manager~put(eventQueue,e,opts,principal)
    if \put~ok then do; ignore=manager~nack(commandQueue,pkg~packageId,pkg~claimToken,principal); return .MBRiskServiceResult~failure("EVENT_DELIVERY_FAILED",put~code); end
  end
  if env~replyTo<>"" then do
    if manager~queue(env~replyTo)==.nil then ignore=manager~createQueue(env~replyTo,"TEMPORARY","MERCHANT_RISK_CLIENT",0,adminPrincipal)
    ignore=manager~grant(env~replyTo,principal,.QueueAccess~PUT,adminPrincipal); opts=.table~new; opts["correlationId"]=env~correlationId; put=manager~put(env~replyTo,reply,opts,principal)
    if \put~ok then do; ignore=manager~nack(commandQueue,pkg~packageId,pkg~claimToken,principal); return .MBRiskServiceResult~failure("REPLY_DELIVERY_FAILED",put~code); end
  end
  acked=manager~ack(commandQueue,pkg~packageId,pkg~claimToken,principal); if \acked~ok then return .MBRiskServiceResult~failure("COMMAND_ACK_FAILED",acked~code)
  return .MBRiskServiceResult~success(reply)
::requires "FederationBankMerchantRiskService.cls"
::requires "ObjectQueueFabric.cls"
