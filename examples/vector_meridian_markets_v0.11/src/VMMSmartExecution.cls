/* VMMSmartExecution.cls -- Vector Meridian Markets smart execution v0.4 */

::class VMMSmartExecutionBuild public
::method version class; return "0.4"
::method protocol class; return "vmm.smart-execution/0.4"
::method eventQueue class; return "VMM.EXECUTION.SMART.EVENT"
::method routeQueuePrefix class; return "VMM.EXECUTION.ROUTE."
::method securityDomain class; return "VMM_EXECUTION_SMART"
::method routerPrincipal class; return "VECTOR_MERIDIAN_SMART_ROUTER"
::method adminPrincipal class; return "VECTOR_MERIDIAN_EXECUTION_ADMIN"


::class VMMVenueRoute public
::method init
  expose routeId venueMic adapterId adapterPrincipal executingCounterparty jurisdiction feeBps rebateBps maxOrderNotional priority policyRef evidenceRef status
  use strict arg routeId,venueMic,adapterId,adapterPrincipal,executingCounterparty,jurisdiction,feeBps,rebateBps,maxOrderNotional,priority,policyRef,evidenceRef
  if routeId="" | venueMic="" | adapterId="" | adapterPrincipal="" | executingCounterparty="" | jurisdiction="" | policyRef="" | evidenceRef="" then raise syntax 88.900 array("invalid VMM venue route identity")
  if pos(" ",routeId)>0 | pos(".",routeId)>0 | pos("/",routeId)>0 then raise syntax 88.900 array("VMM venue route id must be queue-safe",routeId)
  if feeBps<0 | rebateBps<0 | maxOrderNotional<=0 | priority<0 then raise syntax 88.900 array("invalid VMM venue route economics")
  status="ACTIVE"
::method routeId; expose routeId; return routeId
::method venueMic; expose venueMic; return venueMic
::method adapterId; expose adapterId; return adapterId
::method adapterPrincipal; expose adapterPrincipal; return adapterPrincipal
::method executingCounterparty; expose executingCounterparty; return executingCounterparty
::method jurisdiction; expose jurisdiction; return jurisdiction
::method feeBps; expose feeBps; return feeBps
::method rebateBps; expose rebateBps; return rebateBps
::method netCostBps; expose feeBps rebateBps; return feeBps-rebateBps
::method maxOrderNotional; expose maxOrderNotional; return maxOrderNotional
::method priority; expose priority; return priority
::method policyRef; expose policyRef; return policyRef
::method evidenceRef; expose evidenceRef; return evidenceRef
::method status; expose status; return status
::method active; expose status; return status="ACTIVE"
::method pause; expose status; status="PAUSED"; return self
::method restrict; expose status; status="RESTRICTED"; return self
::method resume; expose status; status="ACTIVE"; return self
::method queueName; expose routeId; return .VMMSmartExecutionBuild~routeQueuePrefix||routeId


::class VMMVenueQuote public
::method init
  expose quoteId routeId instrumentKey bid ask availableNotional observedAt validUntil evidenceRef sourceAuthority status
  use strict arg quoteId,routeId,instrumentKey,bid,ask,availableNotional,observedAt,validUntil,evidenceRef,sourceAuthority,status="FIRM"
  if quoteId="" | routeId="" | instrumentKey="" | observedAt="" | validUntil="" | evidenceRef="" | sourceAuthority="" then raise syntax 88.900 array("invalid VMM venue quote identity")
  if bid<=0 | ask<=0 | ask<bid | availableNotional<=0 then raise syntax 88.900 array("invalid VMM venue quote economics")
  if status<>"FIRM" & status<>"INDICATIVE" & status<>"STALE" & status<>"RESTRICTED" then raise syntax 88.900 array("invalid VMM venue quote status",status)
::method quoteId; expose quoteId; return quoteId
::method routeId; expose routeId; return routeId
::method instrumentKey; expose instrumentKey; return instrumentKey
::method bid; expose bid; return bid
::method ask; expose ask; return ask
::method availableNotional; expose availableNotional; return availableNotional
::method observedAt; expose observedAt; return observedAt
::method validUntil; expose validUntil; return validUntil
::method evidenceRef; expose evidenceRef; return evidenceRef
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method status; expose status; return status
::method executableAt
  expose status validUntil
  use strict arg at
  return status="FIRM" & at<=validUntil
::method rawPrice
  expose bid ask
  use strict arg side
  if side="LONG" then return ask
  if side="SHORT" then return bid
  raise syntax 88.900 array("invalid VMM route quote side",side)


::class VMMSmartRouteDecision public
::method init
  expose decisionId orderId routeId adapterId venueMic quoteId rawPrice effectivePrice netCostBps availableNotional decidedAt authorityRef evidenceRef
  use strict arg decisionId,orderId,routeId,adapterId,venueMic,quoteId,rawPrice,effectivePrice,netCostBps,availableNotional,decidedAt,authorityRef,evidenceRef
  if decisionId="" | orderId="" | routeId="" | adapterId="" | venueMic="" | quoteId="" | decidedAt="" | authorityRef="" | evidenceRef="" then raise syntax 88.900 array("invalid VMM smart route decision")
  if rawPrice<=0 | effectivePrice<=0 | availableNotional<=0 then raise syntax 88.900 array("invalid VMM smart route decision economics")
::method decisionId; expose decisionId; return decisionId
::method orderId; expose orderId; return orderId
::method routeId; expose routeId; return routeId
::method adapterId; expose adapterId; return adapterId
::method venueMic; expose venueMic; return venueMic
::method quoteId; expose quoteId; return quoteId
::method rawPrice; expose rawPrice; return rawPrice
::method effectivePrice; expose effectivePrice; return effectivePrice
::method netCostBps; expose netCostBps; return netCostBps
::method availableNotional; expose availableNotional; return availableNotional
::method decidedAt; expose decidedAt; return decidedAt
::method authorityRef; expose authorityRef; return authorityRef
::method evidenceRef; expose evidenceRef; return evidenceRef


::class VMMSmartExecutionService public
::method init
  expose engine manager routes quotesByKey decisionsByOrder routeByOrder submittedByKey cancelByKey processedEvents adminPrincipal routerPrincipal
  use strict arg engine,stateRoot,bindAuthority="VMM_SMART_EXECUTION_BIND",adminPrincipal="VECTOR_MERIDIAN_EXECUTION_ADMIN",routerPrincipal="VECTOR_MERIDIAN_SMART_ROUTER"
  if engine==.nil | stateRoot="" | bindAuthority="" then raise syntax 88.900 array("VMM smart execution requires engine, durable state root and binding authority")
  registry=.QueuePayloadTypeRegistry~new
  ignore=registry~register("vmm.execution.command/1",.VMMExecutionCommandFactory~new)
  ignore=registry~register("vmm.execution.ack/1",.VMMExecutionAcknowledgementFactory~new)
  ignore=registry~register("vmm.execution.fill/1",.VMMExecutionFillEventFactory~new)
  ignore=registry~register("vmm.execution.reject/1",.VMMExecutionRejectFactory~new)
  ignore=registry~register("vmm.execution.cancel/1",.VMMExecutionCancelConfirmationFactory~new)
  ignore=registry~register("vmm.execution.reconcile/1",.VMMExecutionReconciliationFactory~new)
  codec=.QueueGraphPayloadCodec~new(registry)
  manager=.ObjectQueueManager~new(stateRoot,codec,adminPrincipal)
  routes=.directory~new; quotesByKey=.directory~new; decisionsByOrder=.directory~new; routeByOrder=.directory~new
  submittedByKey=.directory~new; cancelByKey=.directory~new; processedEvents=.directory~new
  self~ensureEventQueue
  engine~bindExecutionService(self,bindAuthority)

::method manager; expose manager; return manager
::method engine; expose engine; return engine

::method registerRoute
  expose routes manager adminPrincipal routerPrincipal
  use strict arg route
  if \route~isA(.VMMVenueRoute) then raise syntax 88.900 array("VMMVenueRoute required")
  if routes~hasIndex(route~routeId) then raise syntax 88.900 array("duplicate VMM venue route",route~routeId)
  q=route~queueName
  if manager~queue(q)==.nil then self~must(manager~createQueue(q,"PERMANENT",.VMMSmartExecutionBuild~securityDomain,0,adminPrincipal),"create route queue "||q)
  self~must(manager~grant(q,routerPrincipal,.QueueAccess~PUT,adminPrincipal),"grant smart router route PUT")
  self~must(manager~grant(q,routerPrincipal,.QueueAccess~BROWSE,adminPrincipal),"grant smart router route BROWSE")
  self~must(manager~grant(q,route~adapterPrincipal,.QueueAccess~GET,adminPrincipal),"grant venue route GET")
  self~must(manager~grant(q,route~adapterPrincipal,.QueueAccess~BROWSE,adminPrincipal),"grant venue route BROWSE")
  self~must(manager~grant(.VMMSmartExecutionBuild~eventQueue,route~adapterPrincipal,.QueueAccess~PUT,adminPrincipal),"grant venue event PUT")
  routes[route~routeId]=route
  return route

::method route
  expose routes
  use strict arg routeId
  return routes[routeId]

::method recordVenueQuote
  expose routes quotesByKey
  use strict arg quote
  if \quote~isA(.VMMVenueQuote) then raise syntax 88.900 array("VMMVenueQuote required")
  r=routes[quote~routeId]; if r==.nil then raise syntax 88.900 array("venue quote references unknown VMM route",quote~routeId)
  quotesByKey[quote~routeId||"|"||quote~instrumentKey]=quote
  return quote

::method routeDecision
  expose decisionsByOrder
  use strict arg orderId
  return decisionsByOrder[orderId]

::method routeIdForOrder
  expose routeByOrder
  use strict arg orderId
  v=routeByOrder[orderId]; if v==.nil then return ""
  return v

::method submitMarketOrder
  expose engine manager submittedByKey routeByOrder decisionsByOrder routerPrincipal
  use strict arg order,idempotencyKey,correlationId,submittedAt,authorityRef
  if \order~isA(.VMMMarketOrder) then raise syntax 88.900 array("VMMMarketOrder required for smart execution")
  if idempotencyKey="" | correlationId="" | submittedAt="" | authorityRef="" then raise syntax 88.900 array("VMM smart execution submission requires idempotency/correlation/time/authority")
  prior=submittedByKey[idempotencyKey]
  if prior<>.nil then do
    if prior~orderId<>order~orderId then raise syntax 88.900 array("VMM smart execution idempotency key reused for another order",idempotencyKey)
    return .QueueOperationResult~success(prior,"idempotent smart submission")
  end
  routeDecision=self~selectRoute(order,submittedAt,authorityRef)
  route=self~route(routeDecision~routeId)
  engine~assertSmartExecutionPermitted(order,route,submittedAt)
  locateReservation=engine~reserveShortLocateForOrder(order~orderId,submittedAt,authorityRef)
  commandId="VMM-SMART-CMD-"||idempotencyKey
  order~markRiskAccepted(correlationId,commandId)
  i=order~instrumentIdentity
  c=.VMMExecutionCommand~new(commandId,order~orderId,idempotencyKey,correlationId,"SUBMIT",i~identityKey,i~isin,i~venueMic,i~quoteCurrency,i~settlementCurrency,order~side,order~notional,order~orderType,order~limitPrice,order~origin,order~parentTradeId,order~decisionId,submittedAt,authorityRef,"",route~routeId,route~adapterId)
  putResult=manager~put(route~queueName,c,self~options(correlationId,"SMART_SUBMIT",idempotencyKey),routerPrincipal)
  if \putResult~ok then do
    ignore=engine~releaseShortLocateReservation(order~orderId)
    return putResult
  end
  order~markRouted(correlationId,commandId)
  submittedByKey[idempotencyKey]=c; routeByOrder[order~orderId]=route~routeId; decisionsByOrder[order~orderId]=routeDecision
  return .QueueOperationResult~success(c,"smart-routed route="||route~routeId||" package="||putResult~value~packageId)

::method requestCancel
  expose engine manager cancelByKey routeByOrder routerPrincipal
  use strict arg orderId,idempotencyKey,correlationId,submittedAt,authorityRef,reasonCode
  if orderId="" | idempotencyKey="" | correlationId="" | submittedAt="" | authorityRef="" | reasonCode="" then raise syntax 88.900 array("VMM smart cancel command requires complete identity/evidence")
  prior=cancelByKey[idempotencyKey]
  if prior<>.nil then return .QueueOperationResult~success(prior,"idempotent smart cancellation")
  order=engine~marketOrder(orderId); if order==.nil then raise syntax 88.900 array("unknown VMM market order",orderId)
  routeId=routeByOrder[orderId]; if routeId==.nil then raise syntax 88.900 array("VMM smart cancellation has no routed venue",orderId)
  route=self~route(routeId)
  if order~executionCorrelationId<>correlationId then raise syntax 88.900 array("VMM smart cancellation correlation mismatch")
  if order~state="FILLED" | order~executionState="REJECTED" | order~executionState="CANCELLED" then return .QueueOperationResult~success(order,"order already terminal")
  order~markCancelPending
  i=order~instrumentIdentity; commandId="VMM-SMART-CANCEL-"||idempotencyKey
  c=.VMMExecutionCommand~new(commandId,orderId,idempotencyKey,correlationId,"CANCEL",i~identityKey,i~isin,i~venueMic,i~quoteCurrency,i~settlementCurrency,order~side,order~remainingNotional,order~orderType,order~limitPrice,order~origin,order~parentTradeId,order~decisionId,submittedAt,authorityRef,reasonCode,route~routeId,route~adapterId)
  putResult=manager~put(route~queueName,c,self~options(correlationId,"SMART_CANCEL",idempotencyKey),routerPrincipal)
  if \putResult~ok then return putResult
  cancelByKey[idempotencyKey]=c
  return .QueueOperationResult~success(c,"smart cancel routed route="||route~routeId)

::method claimNextCommand
  expose manager
  use strict arg routeId,adapterId
  route=self~route(routeId); if route==.nil then return .QueueOperationResult~failure("UNKNOWN_SMART_ROUTE",routeId)
  if route~adapterId<>adapterId then return .QueueOperationResult~failure("SMART_ROUTE_ADAPTER_MISMATCH",adapterId)
  return manager~claim(route~queueName,route~adapterPrincipal)

::method acknowledgeCommandPackage
  expose manager
  use strict arg routeId,adapterId,package
  route=self~route(routeId); if route==.nil | route~adapterId<>adapterId then return .QueueOperationResult~failure("SMART_ROUTE_ADAPTER_MISMATCH",adapterId)
  return manager~ack(route~queueName,package~packageId,package~claimToken,route~adapterPrincipal)

::method nackCommandPackage
  expose manager
  use strict arg routeId,adapterId,package
  route=self~route(routeId); if route==.nil | route~adapterId<>adapterId then return .QueueOperationResult~failure("SMART_ROUTE_ADAPTER_MISMATCH",adapterId)
  return manager~nack(route~queueName,package~packageId,package~claimToken,route~adapterPrincipal)

::method publishEvent
  expose manager
  use strict arg routeId,adapterId,event
  route=self~route(routeId); if route==.nil then return .QueueOperationResult~failure("UNKNOWN_SMART_ROUTE",routeId)
  if route~adapterId<>adapterId | event~adapterId<>adapterId then return .QueueOperationResult~failure("SMART_EVENT_ADAPTER_MISMATCH",adapterId)
  if \self~isExecutionEvent(event) then raise syntax 88.900 array("unsupported VMM smart execution event",event~class~id)
  return manager~put(.VMMSmartExecutionBuild~eventQueue,event,self~options(event~correlationId,event~class~id,event~idempotencyKey),route~adapterPrincipal)

::method processNextEvent
  expose engine manager processedEvents routerPrincipal routeByOrder
  claim=manager~claim(.VMMSmartExecutionBuild~eventQueue,routerPrincipal)
  if \claim~ok then return claim
  package=claim~value; event=package~payload
  if \self~isExecutionEvent(event) then do
    ignore=manager~nack(.VMMSmartExecutionBuild~eventQueue,package~packageId,package~claimToken,routerPrincipal)
    return .QueueOperationResult~failure("UNSUPPORTED_SMART_EXECUTION_EVENT",event~class~id)
  end
  if processedEvents~hasIndex(event~eventId) then do
    ignore=manager~ack(.VMMSmartExecutionBuild~eventQueue,package~packageId,package~claimToken,routerPrincipal)
    return .QueueOperationResult~success(event,"duplicate smart execution event ignored")
  end
  routeId=routeByOrder[event~orderId]; if routeId==.nil then do
    ignore=manager~nack(.VMMSmartExecutionBuild~eventQueue,package~packageId,package~claimToken,routerPrincipal)
    return .QueueOperationResult~failure("SMART_EVENT_ORDER_ROUTE_UNKNOWN",event~orderId)
  end
  route=self~route(routeId)
  if event~adapterId<>route~adapterId then do
    ignore=manager~nack(.VMMSmartExecutionBuild~eventQueue,package~packageId,package~claimToken,routerPrincipal)
    return .QueueOperationResult~failure("SMART_EVENT_WRONG_ADAPTER",event~adapterId)
  end
  signal on syntax name eventFailure
  select
    when event~isA(.VMMExecutionAcknowledgement) then ignore=engine~acceptExecutionAcknowledgement(event~orderId,event~commandId,event~correlationId,event~venueOrderRef,event~eventId,self)
    when event~isA(.VMMExecutionFillEvent) then do
      if event~routeId<>routeId then raise syntax 88.900 array("VMM smart fill route mismatch",event~routeId,routeId)
      ignore=engine~acceptSmartQueuedFill(event~fillId,event~orderId,event~commandId,event~correlationId,event~venueExecutionRef,event~fillNotional,event~price,event~executedAt,event~executingCounterparty,event~settlementRef,event~eventId,event~routeId,event~feeAmount,event~rebateAmount,self)
    end
    when event~isA(.VMMExecutionReject) then ignore=engine~acceptExecutionRejection(event~orderId,event~commandId,event~correlationId,event~eventId,self)
    when event~isA(.VMMExecutionCancelConfirmation) then ignore=engine~acceptExecutionCancellation(event~orderId,event~commandId,event~correlationId,event~eventId,self)
    when event~isA(.VMMExecutionReconciliation) then do
      select
        when event~status="ACKNOWLEDGED" then ignore=engine~acceptExecutionAcknowledgement(event~orderId,event~commandId,event~correlationId,event~venueOrderRef,event~eventId,self)
        when event~status="REJECTED" then ignore=engine~acceptExecutionRejection(event~orderId,event~commandId,event~correlationId,event~eventId,self)
        when event~status="CANCELLED" then ignore=engine~acceptExecutionCancellation(event~orderId,event~commandId,event~correlationId,event~eventId,self)
        otherwise ignore=engine~acceptExecutionUnknown(event~orderId,event~commandId,event~correlationId,event~eventId,self)
      end
    end
    otherwise raise syntax 88.900 array("unsupported VMM smart execution event")
  end
  signal off syntax
  processedEvents[event~eventId]=event
  ack=manager~ack(.VMMSmartExecutionBuild~eventQueue,package~packageId,package~claimToken,routerPrincipal)
  if \ack~ok then return ack
  return .QueueOperationResult~success(event,"smart execution event applied")

eventFailure:
  signal off syntax
  ignore=manager~nack(.VMMSmartExecutionBuild~eventQueue,package~packageId,package~claimToken,routerPrincipal)
  c=condition("O"); detail="VMM smart execution event application failed"
  if c<>.nil then if c~hasIndex("DESCRIPTION") then detail=c["DESCRIPTION"]
  return .QueueOperationResult~failure("SMART_EXECUTION_EVENT_APPLICATION_FAILED",detail)

::method commandDepth
  expose manager routerPrincipal
  use strict arg routeId
  route=self~route(routeId); if route==.nil then return -1
  r=manager~depth(route~queueName,routerPrincipal); if \r~ok then return -1
  return r~value["total"]

::method eventDepth
  expose manager routerPrincipal
  r=manager~depth(.VMMSmartExecutionBuild~eventQueue,routerPrincipal); if \r~ok then return -1
  return r~value["total"]

::method selectRoute private
  expose routes quotesByKey
  use strict arg order,at,authorityRef
  i=order~instrumentIdentity; bestRoute=.nil; bestQuote=.nil; bestEffective=0
  do routeId over routes
    route=routes[routeId]
    if route~active & route~venueMic=i~venueMic & order~remainingNotional<=route~maxOrderNotional then do
      q=quotesByKey[routeId||"|"||i~identityKey]
      if q<>.nil then if q~executableAt(at) & q~availableNotional>=order~remainingNotional then do
        raw=q~rawPrice(order~side); netBps=route~netCostBps
        if order~side="LONG" then effective=raw*(1+(netBps/10000)); else effective=raw*(1-(netBps/10000))
        choose=.false
        if bestRoute==.nil then choose=.true
        else if order~side="LONG" & effective<bestEffective then choose=.true
        else if order~side="SHORT" & effective>bestEffective then choose=.true
        else if effective=bestEffective & route~priority<bestRoute~priority then choose=.true
        else if effective=bestEffective & route~priority=bestRoute~priority & route~routeId<bestRoute~routeId then choose=.true
        if choose then do; bestRoute=route; bestQuote=q; bestEffective=effective; end
      end
    end
  end
  if bestRoute==.nil then raise syntax 88.900 array("VMM smart router found no executable route",order~orderId,i~identityKey)
  raw=bestQuote~rawPrice(order~side)
  return .VMMSmartRouteDecision~new("ROUTEDEC-"||order~orderId,order~orderId,bestRoute~routeId,bestRoute~adapterId,bestRoute~venueMic,bestQuote~quoteId,raw,bestEffective,bestRoute~netCostBps,bestQuote~availableNotional,at,authorityRef,bestRoute~evidenceRef||"|"||bestQuote~evidenceRef)

::method ensureEventQueue private
  expose manager adminPrincipal routerPrincipal
  q=.VMMSmartExecutionBuild~eventQueue
  if manager~queue(q)==.nil then self~must(manager~createQueue(q,"PERMANENT",.VMMSmartExecutionBuild~securityDomain,0,adminPrincipal),"create smart event queue")
  self~must(manager~grant(q,routerPrincipal,.QueueAccess~GET,adminPrincipal),"grant smart router event GET")
  self~must(manager~grant(q,routerPrincipal,.QueueAccess~BROWSE,adminPrincipal),"grant smart router event BROWSE")
  return .true

::method options private
  use strict arg correlationId,kind,idempotencyKey
  o=.table~new; o["persistent"]=.true; o["correlationId"]=correlationId
  h=.table~new; h["protocol"]=.VMMSmartExecutionBuild~protocol; h["kind"]=kind; h["idempotencyKey"]=idempotencyKey; o["headers"]=h
  return o

::method isExecutionEvent private
  use strict arg event
  return event~isA(.VMMExecutionAcknowledgement) | event~isA(.VMMExecutionFillEvent) | event~isA(.VMMExecutionReject) | event~isA(.VMMExecutionCancelConfirmation) | event~isA(.VMMExecutionReconciliation)

::method must private
  use strict arg result,label
  if \result~ok then raise syntax 88.900 array("VMM smart Queue Fabric setup failed",label,result~code,result~detail)
  return result


::class VMMSmartVenueAdapter public
::method init
  expose service route seenCommands venueOrderByOrder commandByOrder
  use strict arg service,route
  if service==.nil | \route~isA(.VMMVenueRoute) then raise syntax 88.900 array("VMM smart venue adapter requires service and route")
  registered=service~route(route~routeId)
  if registered==.nil | registered~adapterId<>route~adapterId then raise syntax 88.900 array("VMM smart venue route not registered",route~routeId)
  seenCommands=.directory~new; venueOrderByOrder=.directory~new; commandByOrder=.directory~new

::method processNextCommand
  expose service route seenCommands venueOrderByOrder commandByOrder
  use strict arg at
  claim=service~claimNextCommand(route~routeId,route~adapterId)
  if \claim~ok then return claim
  package=claim~value; command=package~payload
  if \command~isA(.VMMExecutionCommand) then do
    ignore=service~nackCommandPackage(route~routeId,route~adapterId,package)
    return .QueueOperationResult~failure("INVALID_SMART_EXECUTION_COMMAND",command~class~id)
  end
  if command~routeId<>route~routeId | command~targetAdapterId<>route~adapterId then do
    ignore=service~nackCommandPackage(route~routeId,route~adapterId,package)
    return .QueueOperationResult~failure("SMART_COMMAND_ROUTE_MISMATCH",command~routeId)
  end
  prior=seenCommands[command~commandId]
  if prior<>.nil then do
    if command~action="SUBMIT" then event=.VMMExecutionAcknowledgement~new("ACK-"||command~commandId,command~commandId,command~orderId,command~idempotencyKey,command~correlationId,prior,route~adapterId,at)
    else event=.VMMExecutionCancelConfirmation~new("CANCEL-"||command~commandId,command~commandId,command~orderId,command~idempotencyKey,command~correlationId,venueOrderByOrder[command~orderId],route~adapterId,at)
    pub=service~publishEvent(route~routeId,route~adapterId,event)
    if \pub~ok then do; ignore=service~nackCommandPackage(route~routeId,route~adapterId,package); return pub; end
    ignore=service~acknowledgeCommandPackage(route~routeId,route~adapterId,package)
    return .QueueOperationResult~success(event,"idempotent smart venue command replay")
  end
  if command~action="SUBMIT" then do
    venueRef=route~routeId||"-"||command~orderId
    seenCommands[command~commandId]=venueRef; venueOrderByOrder[command~orderId]=venueRef; commandByOrder[command~orderId]=command
    event=.VMMExecutionAcknowledgement~new("ACK-"||command~commandId,command~commandId,command~orderId,command~idempotencyKey,command~correlationId,venueRef,route~adapterId,at)
  end
  else do
    seenCommands[command~commandId]="CANCELLED"
    event=.VMMExecutionCancelConfirmation~new("CANCEL-"||command~commandId,command~commandId,command~orderId,command~idempotencyKey,command~correlationId,venueOrderByOrder[command~orderId],route~adapterId,at)
  end
  pub=service~publishEvent(route~routeId,route~adapterId,event)
  if \pub~ok then do; ignore=service~nackCommandPackage(route~routeId,route~adapterId,package); return pub; end
  ignore=service~acknowledgeCommandPackage(route~routeId,route~adapterId,package)
  return .QueueOperationResult~success(event,"smart venue command processed")

::method publishFill
  expose service route commandByOrder
  use strict arg orderId,fillId,venueExecutionRef,fillNotional,price,currency,executedAt,settlementRef=""
  command=commandByOrder[orderId]
  if command==.nil then raise syntax 88.900 array("smart venue adapter has no acknowledged VMM order",orderId)
  value=fillNotional*price; feeAmount=value*(route~feeBps/10000); rebateAmount=value*(route~rebateBps/10000)
  e=.VMMExecutionFillEvent~new("FILL-"||fillId,command~commandId,orderId,"FILL-"||fillId,command~correlationId,fillId,venueExecutionRef,fillNotional,price,currency,executedAt,route~executingCounterparty,settlementRef,route~adapterId,route~routeId,feeAmount,rebateAmount)
  return service~publishEvent(route~routeId,route~adapterId,e)

::method publishUnknown
  expose service route commandByOrder venueOrderByOrder
  use strict arg orderId,eventId,at,reasonCode="STATUS_UNKNOWN"
  command=commandByOrder[orderId]; if command==.nil then raise syntax 88.900 array("smart venue adapter has no VMM order",orderId)
  e=.VMMExecutionReconciliation~new(eventId,command~commandId,orderId,"RECON-"||eventId,command~correlationId,"UNKNOWN",venueOrderByOrder[orderId],reasonCode,route~adapterId,at)
  return service~publishEvent(route~routeId,route~adapterId,e)


::requires "VMMQueueExecution.cls"
