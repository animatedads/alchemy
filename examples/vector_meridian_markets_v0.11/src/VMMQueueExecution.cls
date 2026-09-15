/* VMMQueueExecution.cls -- Vector Meridian Markets queue-native execution spine v0.4 */

::class VMMExecutionBuild public
::method version class; return "0.4"
::method protocol class; return "vmm.execution/0.4"
::method commandQueue class; return "VMM.EXECUTION.COMMAND"
::method eventQueue class; return "VMM.EXECUTION.EVENT"
::method securityDomain class; return "VMM_EXECUTION"
::method routerPrincipal class; return "VECTOR_MERIDIAN_EXECUTION_ROUTER"
::method venuePrincipal class; return "VECTOR_MERIDIAN_VENUE_ADAPTER"
::method adminPrincipal class; return "VECTOR_MERIDIAN_EXECUTION_ADMIN"


::class VMMExecutionCommand public
::method init
  expose commandId orderId idempotencyKey correlationId action instrumentKey isin venueMic quoteCurrency settlementCurrency side notional orderType limitPrice origin parentTradeId decisionId createdAt authorityRef reasonCode routeId targetAdapterId
  use arg commandId="",orderId="",idempotencyKey="",correlationId="",action="",instrumentKey="",isin="",venueMic="",quoteCurrency="",settlementCurrency="",side="",notional=0,orderType="",limitPrice=0,origin="",parentTradeId="",decisionId="",createdAt="",authorityRef="",reasonCode="",routeId="",targetAdapterId=""
  if commandId="" & orderId="" & action="" then return
  if commandId="" | orderId="" | idempotencyKey="" | correlationId="" | action="" | createdAt="" | authorityRef="" then raise syntax 88.900 array("invalid VMM execution command identity")
  if action<>"SUBMIT" & action<>"CANCEL" then raise syntax 88.900 array("invalid VMM execution command action",action)
  if action="SUBMIT" then do
    if instrumentKey="" | isin="" | venueMic="" | quoteCurrency="" | settlementCurrency="" then raise syntax 88.900 array("VMM SUBMIT command requires exact instrument identity")
    if side<>"LONG" & side<>"SHORT" then raise syntax 88.900 array("invalid VMM execution command side",side)
    if notional<=0 then raise syntax 88.900 array("invalid VMM execution command notional")
    if orderType<>"MARKET" & orderType<>"LIMIT" then raise syntax 88.900 array("invalid VMM execution order type",orderType)
    if orderType="LIMIT" & limitPrice<=0 then raise syntax 88.900 array("VMM execution limit command requires price")
  end
::method commandId; expose commandId; return commandId
::method orderId; expose orderId; return orderId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method action; expose action; return action
::method instrumentKey; expose instrumentKey; return instrumentKey
::method isin; expose isin; return isin
::method venueMic; expose venueMic; return venueMic
::method quoteCurrency; expose quoteCurrency; return quoteCurrency
::method settlementCurrency; expose settlementCurrency; return settlementCurrency
::method side; expose side; return side
::method notional; expose notional; return notional
::method orderType; expose orderType; return orderType
::method limitPrice; expose limitPrice; return limitPrice
::method origin; expose origin; return origin
::method parentTradeId; expose parentTradeId; return parentTradeId
::method decisionId; expose decisionId; return decisionId
::method createdAt; expose createdAt; return createdAt
::method authorityRef; expose authorityRef; return authorityRef
::method reasonCode; expose reasonCode; return reasonCode
::method routeId; expose routeId; return routeId
::method targetAdapterId; expose targetAdapterId; return targetAdapterId
::method queuePersistentType; return "vmm.execution.command/1"
::method queuePersistentState
  expose commandId orderId idempotencyKey correlationId action instrumentKey isin venueMic quoteCurrency settlementCurrency side notional orderType limitPrice origin parentTradeId decisionId createdAt authorityRef reasonCode routeId targetAdapterId
  d=.table~new
  d["commandId"]=commandId; d["orderId"]=orderId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["action"]=action
  d["instrumentKey"]=instrumentKey; d["isin"]=isin; d["venueMic"]=venueMic; d["quoteCurrency"]=quoteCurrency; d["settlementCurrency"]=settlementCurrency
  d["side"]=side; d["notional"]=notional; d["orderType"]=orderType; d["limitPrice"]=limitPrice; d["origin"]=origin; d["parentTradeId"]=parentTradeId; d["decisionId"]=decisionId
  d["createdAt"]=createdAt; d["authorityRef"]=authorityRef; d["reasonCode"]=reasonCode; d["routeId"]=routeId; d["targetAdapterId"]=targetAdapterId
  return d
::method queueRestoreState
  expose commandId orderId idempotencyKey correlationId action instrumentKey isin venueMic quoteCurrency settlementCurrency side notional orderType limitPrice origin parentTradeId decisionId createdAt authorityRef reasonCode routeId targetAdapterId
  use arg d
  commandId=d["commandId"]; orderId=d["orderId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; action=d["action"]
  instrumentKey=d["instrumentKey"]; isin=d["isin"]; venueMic=d["venueMic"]; quoteCurrency=d["quoteCurrency"]; settlementCurrency=d["settlementCurrency"]
  side=d["side"]; notional=d["notional"]; orderType=d["orderType"]; limitPrice=d["limitPrice"]; origin=d["origin"]; parentTradeId=d["parentTradeId"]; decisionId=d["decisionId"]
  createdAt=d["createdAt"]; authorityRef=d["authorityRef"]; reasonCode=d["reasonCode"]
  routeId=""; targetAdapterId=""; if d~hasIndex("routeId") then routeId=d["routeId"]; if d~hasIndex("targetAdapterId") then targetAdapterId=d["targetAdapterId"]
  return .true

::class VMMExecutionCommandFactory public
::method newBlank; return .VMMExecutionCommand~new


::class VMMExecutionAcknowledgement public
::method init
  expose eventId commandId orderId idempotencyKey correlationId venueOrderRef adapterId acknowledgedAt
  use arg eventId="",commandId="",orderId="",idempotencyKey="",correlationId="",venueOrderRef="",adapterId="",acknowledgedAt=""
  if eventId="" & orderId="" then return
  if eventId="" | commandId="" | orderId="" | idempotencyKey="" | correlationId="" | venueOrderRef="" | adapterId="" | acknowledgedAt="" then raise syntax 88.900 array("invalid VMM execution acknowledgement")
::method eventId; expose eventId; return eventId
::method commandId; expose commandId; return commandId
::method orderId; expose orderId; return orderId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method venueOrderRef; expose venueOrderRef; return venueOrderRef
::method adapterId; expose adapterId; return adapterId
::method acknowledgedAt; expose acknowledgedAt; return acknowledgedAt
::method queuePersistentType; return "vmm.execution.ack/1"
::method queuePersistentState
  expose eventId commandId orderId idempotencyKey correlationId venueOrderRef adapterId acknowledgedAt
  d=.table~new; d["eventId"]=eventId; d["commandId"]=commandId; d["orderId"]=orderId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["venueOrderRef"]=venueOrderRef; d["adapterId"]=adapterId; d["acknowledgedAt"]=acknowledgedAt; return d
::method queueRestoreState
  expose eventId commandId orderId idempotencyKey correlationId venueOrderRef adapterId acknowledgedAt
  use arg d
  eventId=d["eventId"]; commandId=d["commandId"]; orderId=d["orderId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; venueOrderRef=d["venueOrderRef"]; adapterId=d["adapterId"]; acknowledgedAt=d["acknowledgedAt"]; return .true

::class VMMExecutionAcknowledgementFactory public
::method newBlank; return .VMMExecutionAcknowledgement~new


::class VMMExecutionFillEvent public
::method init
  expose eventId commandId orderId idempotencyKey correlationId fillId venueExecutionRef fillNotional price currency executedAt executingCounterparty settlementRef adapterId routeId feeAmount rebateAmount
  use arg eventId="",commandId="",orderId="",idempotencyKey="",correlationId="",fillId="",venueExecutionRef="",fillNotional=0,price=0,currency="",executedAt="",executingCounterparty="",settlementRef="",adapterId="",routeId="",feeAmount=0,rebateAmount=0
  if eventId="" & orderId="" then return
  if eventId="" | commandId="" | orderId="" | idempotencyKey="" | correlationId="" | fillId="" | venueExecutionRef="" | currency="" | executedAt="" | executingCounterparty="" | adapterId="" then raise syntax 88.900 array("invalid VMM execution fill event")
  if fillNotional<=0 | price<=0 | feeAmount<0 | rebateAmount<0 then raise syntax 88.900 array("invalid VMM execution fill event economics")
::method eventId; expose eventId; return eventId
::method commandId; expose commandId; return commandId
::method orderId; expose orderId; return orderId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method fillId; expose fillId; return fillId
::method venueExecutionRef; expose venueExecutionRef; return venueExecutionRef
::method fillNotional; expose fillNotional; return fillNotional
::method price; expose price; return price
::method currency; expose currency; return currency
::method executedAt; expose executedAt; return executedAt
::method executingCounterparty; expose executingCounterparty; return executingCounterparty
::method settlementRef; expose settlementRef; return settlementRef
::method adapterId; expose adapterId; return adapterId
::method routeId; expose routeId; return routeId
::method feeAmount; expose feeAmount; return feeAmount
::method rebateAmount; expose rebateAmount; return rebateAmount
::method netExecutionCost; expose feeAmount rebateAmount; return feeAmount-rebateAmount
::method queuePersistentType; return "vmm.execution.fill/1"
::method queuePersistentState
  expose eventId commandId orderId idempotencyKey correlationId fillId venueExecutionRef fillNotional price currency executedAt executingCounterparty settlementRef adapterId routeId feeAmount rebateAmount
  d=.table~new; d["eventId"]=eventId; d["commandId"]=commandId; d["orderId"]=orderId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["fillId"]=fillId; d["venueExecutionRef"]=venueExecutionRef; d["fillNotional"]=fillNotional; d["price"]=price; d["currency"]=currency; d["executedAt"]=executedAt; d["executingCounterparty"]=executingCounterparty; d["settlementRef"]=settlementRef; d["adapterId"]=adapterId; d["routeId"]=routeId; d["feeAmount"]=feeAmount; d["rebateAmount"]=rebateAmount; return d
::method queueRestoreState
  expose eventId commandId orderId idempotencyKey correlationId fillId venueExecutionRef fillNotional price currency executedAt executingCounterparty settlementRef adapterId routeId feeAmount rebateAmount
  use arg d
  eventId=d["eventId"]; commandId=d["commandId"]; orderId=d["orderId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; fillId=d["fillId"]; venueExecutionRef=d["venueExecutionRef"]; fillNotional=d["fillNotional"]; price=d["price"]; currency=d["currency"]; executedAt=d["executedAt"]; executingCounterparty=d["executingCounterparty"]; settlementRef=d["settlementRef"]; adapterId=d["adapterId"]; routeId=""; feeAmount=0; rebateAmount=0; if d~hasIndex("routeId") then routeId=d["routeId"]; if d~hasIndex("feeAmount") then feeAmount=d["feeAmount"]; if d~hasIndex("rebateAmount") then rebateAmount=d["rebateAmount"]; return .true

::class VMMExecutionFillEventFactory public
::method newBlank; return .VMMExecutionFillEvent~new


::class VMMExecutionReject public
::method init
  expose eventId commandId orderId idempotencyKey correlationId reasonCode detail adapterId rejectedAt
  use arg eventId="",commandId="",orderId="",idempotencyKey="",correlationId="",reasonCode="",detail="",adapterId="",rejectedAt=""
  if eventId="" & orderId="" then return
  if eventId="" | commandId="" | orderId="" | idempotencyKey="" | correlationId="" | reasonCode="" | adapterId="" | rejectedAt="" then raise syntax 88.900 array("invalid VMM execution rejection")
::method eventId; expose eventId; return eventId
::method commandId; expose commandId; return commandId
::method orderId; expose orderId; return orderId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method reasonCode; expose reasonCode; return reasonCode
::method detail; expose detail; return detail
::method adapterId; expose adapterId; return adapterId
::method rejectedAt; expose rejectedAt; return rejectedAt
::method queuePersistentType; return "vmm.execution.reject/1"
::method queuePersistentState
  expose eventId commandId orderId idempotencyKey correlationId reasonCode detail adapterId rejectedAt
  d=.table~new; d["eventId"]=eventId; d["commandId"]=commandId; d["orderId"]=orderId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["reasonCode"]=reasonCode; d["detail"]=detail; d["adapterId"]=adapterId; d["rejectedAt"]=rejectedAt; return d
::method queueRestoreState
  expose eventId commandId orderId idempotencyKey correlationId reasonCode detail adapterId rejectedAt
  use arg d
  eventId=d["eventId"]; commandId=d["commandId"]; orderId=d["orderId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; reasonCode=d["reasonCode"]; detail=d["detail"]; adapterId=d["adapterId"]; rejectedAt=d["rejectedAt"]; return .true

::class VMMExecutionRejectFactory public
::method newBlank; return .VMMExecutionReject~new


::class VMMExecutionCancelConfirmation public
::method init
  expose eventId commandId orderId idempotencyKey correlationId venueOrderRef adapterId cancelledAt
  use arg eventId="",commandId="",orderId="",idempotencyKey="",correlationId="",venueOrderRef="",adapterId="",cancelledAt=""
  if eventId="" & orderId="" then return
  if eventId="" | commandId="" | orderId="" | idempotencyKey="" | correlationId="" | adapterId="" | cancelledAt="" then raise syntax 88.900 array("invalid VMM execution cancellation confirmation")
::method eventId; expose eventId; return eventId
::method commandId; expose commandId; return commandId
::method orderId; expose orderId; return orderId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method venueOrderRef; expose venueOrderRef; return venueOrderRef
::method adapterId; expose adapterId; return adapterId
::method cancelledAt; expose cancelledAt; return cancelledAt
::method queuePersistentType; return "vmm.execution.cancel/1"
::method queuePersistentState
  expose eventId commandId orderId idempotencyKey correlationId venueOrderRef adapterId cancelledAt
  d=.table~new; d["eventId"]=eventId; d["commandId"]=commandId; d["orderId"]=orderId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["venueOrderRef"]=venueOrderRef; d["adapterId"]=adapterId; d["cancelledAt"]=cancelledAt; return d
::method queueRestoreState
  expose eventId commandId orderId idempotencyKey correlationId venueOrderRef adapterId cancelledAt
  use arg d
  eventId=d["eventId"]; commandId=d["commandId"]; orderId=d["orderId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; venueOrderRef=d["venueOrderRef"]; adapterId=d["adapterId"]; cancelledAt=d["cancelledAt"]; return .true

::class VMMExecutionCancelConfirmationFactory public
::method newBlank; return .VMMExecutionCancelConfirmation~new


::class VMMExecutionReconciliation public
::method init
  expose eventId commandId orderId idempotencyKey correlationId status venueOrderRef reasonCode adapterId reconciledAt
  use arg eventId="",commandId="",orderId="",idempotencyKey="",correlationId="",status="",venueOrderRef="",reasonCode="",adapterId="",reconciledAt=""
  if eventId="" & orderId="" then return
  if eventId="" | commandId="" | orderId="" | idempotencyKey="" | correlationId="" | status="" | adapterId="" | reconciledAt="" then raise syntax 88.900 array("invalid VMM execution reconciliation")
  if status<>"ACKNOWLEDGED" & status<>"REJECTED" & status<>"CANCELLED" & status<>"UNKNOWN" then raise syntax 88.900 array("invalid VMM reconciliation status",status)
  if status="ACKNOWLEDGED" & venueOrderRef="" then raise syntax 88.900 array("acknowledged reconciliation requires venue order reference")
::method eventId; expose eventId; return eventId
::method commandId; expose commandId; return commandId
::method orderId; expose orderId; return orderId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method status; expose status; return status
::method venueOrderRef; expose venueOrderRef; return venueOrderRef
::method reasonCode; expose reasonCode; return reasonCode
::method adapterId; expose adapterId; return adapterId
::method reconciledAt; expose reconciledAt; return reconciledAt
::method queuePersistentType; return "vmm.execution.reconcile/1"
::method queuePersistentState
  expose eventId commandId orderId idempotencyKey correlationId status venueOrderRef reasonCode adapterId reconciledAt
  d=.table~new; d["eventId"]=eventId; d["commandId"]=commandId; d["orderId"]=orderId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["status"]=status; d["venueOrderRef"]=venueOrderRef; d["reasonCode"]=reasonCode; d["adapterId"]=adapterId; d["reconciledAt"]=reconciledAt; return d
::method queueRestoreState
  expose eventId commandId orderId idempotencyKey correlationId status venueOrderRef reasonCode adapterId reconciledAt
  use arg d
  eventId=d["eventId"]; commandId=d["commandId"]; orderId=d["orderId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; status=d["status"]; venueOrderRef=d["venueOrderRef"]; reasonCode=d["reasonCode"]; adapterId=d["adapterId"]; reconciledAt=d["reconciledAt"]; return .true

::class VMMExecutionReconciliationFactory public
::method newBlank; return .VMMExecutionReconciliation~new


::class VMMQueueExecutionService public
::method init
  expose engine manager submittedByKey cancelByKey processedEvents adminPrincipal routerPrincipal venuePrincipal
  use strict arg engine,stateRoot,bindAuthority="VMM_EXECUTION_BIND",adminPrincipal="VECTOR_MERIDIAN_EXECUTION_ADMIN",routerPrincipal="VECTOR_MERIDIAN_EXECUTION_ROUTER",venuePrincipal="VECTOR_MERIDIAN_VENUE_ADAPTER"
  if engine==.nil | stateRoot="" | bindAuthority="" then raise syntax 88.900 array("VMM queue execution requires engine, durable state root and binding authority")
  registry=.QueuePayloadTypeRegistry~new
  ignore=registry~register("vmm.execution.command/1",.VMMExecutionCommandFactory~new)
  ignore=registry~register("vmm.execution.ack/1",.VMMExecutionAcknowledgementFactory~new)
  ignore=registry~register("vmm.execution.fill/1",.VMMExecutionFillEventFactory~new)
  ignore=registry~register("vmm.execution.reject/1",.VMMExecutionRejectFactory~new)
  ignore=registry~register("vmm.execution.cancel/1",.VMMExecutionCancelConfirmationFactory~new)
  ignore=registry~register("vmm.execution.reconcile/1",.VMMExecutionReconciliationFactory~new)
  codec=.QueueGraphPayloadCodec~new(registry)
  manager=.ObjectQueueManager~new(stateRoot,codec,adminPrincipal)
  self~ensureQueues
  submittedByKey=.directory~new; cancelByKey=.directory~new; processedEvents=.directory~new
  engine~bindExecutionService(self,bindAuthority)

::method manager; expose manager; return manager
::method engine; expose engine; return engine

::method submitMarketOrder
  expose engine manager submittedByKey routerPrincipal
  use strict arg order,idempotencyKey,correlationId,submittedAt,authorityRef
  if \order~isA(.VMMMarketOrder) then raise syntax 88.900 array("VMMMarketOrder required for queue execution")
  if idempotencyKey="" | correlationId="" | submittedAt="" | authorityRef="" then raise syntax 88.900 array("VMM execution submission requires idempotency/correlation/time/authority")
  prior=submittedByKey[idempotencyKey]
  if prior<>.nil then do
    if prior~orderId<>order~orderId then raise syntax 88.900 array("VMM execution idempotency key reused for another order",idempotencyKey)
    return .QueueOperationResult~success(prior,"idempotent submission")
  end
  if order~instrumentIdentity==.nil then raise syntax 88.900 array("VMM queue execution requires exact tradable instrument identity")
  commandId="VMM-CMD-"||idempotencyKey
  order~markRiskAccepted(correlationId,commandId)
  i=order~instrumentIdentity
  c=.VMMExecutionCommand~new(commandId,order~orderId,idempotencyKey,correlationId,"SUBMIT",i~identityKey,i~isin,i~venueMic,i~quoteCurrency,i~settlementCurrency,order~side,order~notional,order~orderType,order~limitPrice,order~origin,order~parentTradeId,order~decisionId,submittedAt,authorityRef,"")
  options=self~options(correlationId,"SUBMIT",idempotencyKey)
  putResult=manager~put(.VMMExecutionBuild~commandQueue,c,options,routerPrincipal)
  if \putResult~ok then return putResult
  packageId=putResult~value~packageId
  ignore=order~markRouted(correlationId,commandId)
  submittedByKey[idempotencyKey]=c
  return .QueueOperationResult~success(c,"routed package="||packageId)

::method requestCancel
  expose engine manager cancelByKey routerPrincipal
  use strict arg orderId,idempotencyKey,correlationId,submittedAt,authorityRef,reasonCode
  if orderId="" | idempotencyKey="" | correlationId="" | submittedAt="" | authorityRef="" | reasonCode="" then raise syntax 88.900 array("VMM cancel command requires complete identity/evidence")
  prior=cancelByKey[idempotencyKey]
  if prior<>.nil then do
    if prior~orderId<>orderId then raise syntax 88.900 array("VMM cancel idempotency key reused for another order")
    return .QueueOperationResult~success(prior,"idempotent cancellation")
  end
  order=engine~marketOrder(orderId); if order==.nil then raise syntax 88.900 array("unknown VMM market order",orderId)
  if order~executionCorrelationId<>correlationId then raise syntax 88.900 array("VMM cancellation correlation mismatch")
  if order~state="FILLED" | order~executionState="REJECTED" | order~executionState="CANCELLED" then return .QueueOperationResult~success(order,"order already terminal")
  order~markCancelPending
  i=order~instrumentIdentity
  commandId="VMM-CANCEL-"||idempotencyKey
  c=.VMMExecutionCommand~new(commandId,orderId,idempotencyKey,correlationId,"CANCEL",i~identityKey,i~isin,i~venueMic,i~quoteCurrency,i~settlementCurrency,order~side,order~remainingNotional,order~orderType,order~limitPrice,order~origin,order~parentTradeId,order~decisionId,submittedAt,authorityRef,reasonCode)
  putResult=manager~put(.VMMExecutionBuild~commandQueue,c,self~options(correlationId,"CANCEL",idempotencyKey),routerPrincipal)
  if \putResult~ok then return putResult
  packageId=putResult~value~packageId
  cancelByKey[idempotencyKey]=c
  return .QueueOperationResult~success(c,"cancel routed package="||packageId)

::method claimNextCommand
  expose manager venuePrincipal
  return manager~claim(.VMMExecutionBuild~commandQueue,venuePrincipal)

::method acknowledgeCommandPackage
  expose manager venuePrincipal
  use strict arg package
  return manager~ack(.VMMExecutionBuild~commandQueue,package~packageId,package~claimToken,venuePrincipal)

::method nackCommandPackage
  expose manager venuePrincipal
  use strict arg package
  return manager~nack(.VMMExecutionBuild~commandQueue,package~packageId,package~claimToken,venuePrincipal)

::method publishEvent
  expose manager venuePrincipal
  use strict arg event
  if \self~isExecutionEvent(event) then raise syntax 88.900 array("unsupported VMM execution event class",event~class~id)
  correlationId=event~correlationId
  options=self~options(correlationId,event~class~id,event~idempotencyKey)
  return manager~put(.VMMExecutionBuild~eventQueue,event,options,venuePrincipal)

::method processNextEvent
  expose engine manager processedEvents routerPrincipal
  claim=manager~claim(.VMMExecutionBuild~eventQueue,routerPrincipal)
  if \claim~ok then return claim
  package=claim~value; event=package~payload
  if \self~isExecutionEvent(event) then do
    ignore=manager~nack(.VMMExecutionBuild~eventQueue,package~packageId,package~claimToken,routerPrincipal)
    return .QueueOperationResult~failure("UNSUPPORTED_EXECUTION_EVENT",event~class~id)
  end
  if processedEvents~hasIndex(event~eventId) then do
    ignore=manager~ack(.VMMExecutionBuild~eventQueue,package~packageId,package~claimToken,routerPrincipal)
    return .QueueOperationResult~success(event,"duplicate execution event ignored")
  end
  signal on syntax name eventFailure
  select
    when event~isA(.VMMExecutionAcknowledgement) then ignore=engine~acceptExecutionAcknowledgement(event~orderId,event~commandId,event~correlationId,event~venueOrderRef,event~eventId,self)
    when event~isA(.VMMExecutionFillEvent) then ignore=engine~acceptQueuedFill(event~fillId,event~orderId,event~commandId,event~correlationId,event~venueExecutionRef,event~fillNotional,event~price,event~executedAt,event~executingCounterparty,event~settlementRef,event~eventId,self)
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
    otherwise raise syntax 88.900 array("unsupported VMM execution event")
  end
  signal off syntax
  processedEvents[event~eventId]=event
  ack=manager~ack(.VMMExecutionBuild~eventQueue,package~packageId,package~claimToken,routerPrincipal)
  if \ack~ok then return ack
  return .QueueOperationResult~success(event,"execution event applied")

eventFailure:
  signal off syntax
  ignore=manager~nack(.VMMExecutionBuild~eventQueue,package~packageId,package~claimToken,routerPrincipal)
  c=condition("O"); detail="VMM execution event application failed"
  if c<>.nil then if c~hasIndex("DESCRIPTION") then detail=c["DESCRIPTION"]
  return .QueueOperationResult~failure("EXECUTION_EVENT_APPLICATION_FAILED",detail)

::method commandDepth
  expose manager routerPrincipal
  r=manager~depth(.VMMExecutionBuild~commandQueue,routerPrincipal); if \r~ok then return -1
  return r~value["total"]
::method eventDepth
  expose manager routerPrincipal
  r=manager~depth(.VMMExecutionBuild~eventQueue,routerPrincipal); if \r~ok then return -1
  return r~value["total"]

::method ensureQueues private
  expose manager adminPrincipal routerPrincipal venuePrincipal
  cq=.VMMExecutionBuild~commandQueue; eq=.VMMExecutionBuild~eventQueue; domain=.VMMExecutionBuild~securityDomain
  if manager~queue(cq)==.nil then self~must(manager~createQueue(cq,"PERMANENT",domain,0,adminPrincipal),"create command queue")
  if manager~queue(eq)==.nil then self~must(manager~createQueue(eq,"PERMANENT",domain,0,adminPrincipal),"create event queue")
  self~must(manager~grant(cq,routerPrincipal,.QueueAccess~PUT,adminPrincipal),"grant router command PUT")
  self~must(manager~grant(cq,routerPrincipal,.QueueAccess~BROWSE,adminPrincipal),"grant router command BROWSE")
  self~must(manager~grant(cq,venuePrincipal,.QueueAccess~GET,adminPrincipal),"grant venue command GET")
  self~must(manager~grant(cq,venuePrincipal,.QueueAccess~BROWSE,adminPrincipal),"grant venue command BROWSE")
  self~must(manager~grant(eq,venuePrincipal,.QueueAccess~PUT,adminPrincipal),"grant venue event PUT")
  self~must(manager~grant(eq,routerPrincipal,.QueueAccess~GET,adminPrincipal),"grant router event GET")
  self~must(manager~grant(eq,routerPrincipal,.QueueAccess~BROWSE,adminPrincipal),"grant router event BROWSE")
  return .true

::method options private
  use strict arg correlationId,kind,idempotencyKey
  o=.table~new; o["persistent"]=.true; o["correlationId"]=correlationId
  h=.table~new; h["protocol"]=.VMMExecutionBuild~protocol; h["kind"]=kind; h["idempotencyKey"]=idempotencyKey
  o["headers"]=h; return o

::method isExecutionEvent private
  use strict arg event
  return event~isA(.VMMExecutionAcknowledgement) | event~isA(.VMMExecutionFillEvent) | event~isA(.VMMExecutionReject) | event~isA(.VMMExecutionCancelConfirmation) | event~isA(.VMMExecutionReconciliation)

::method must private
  use strict arg result,label
  if \result~ok then raise syntax 88.900 array("VMM Queue Fabric setup failed",label,result~code,result~detail)
  return result


::class VMMQueueVenueAdapter public
::method init
  expose service adapterId seenCommands venueOrderByOrder commandByOrder
  use strict arg service,adapterId="SIMULATED_VENUE_ADAPTER"
  if service==.nil | adapterId="" then raise syntax 88.900 array("VMM venue adapter requires service and adapter identity")
  seenCommands=.directory~new; venueOrderByOrder=.directory~new; commandByOrder=.directory~new

::method processNextCommand
  expose service adapterId seenCommands venueOrderByOrder commandByOrder
  use strict arg at
  claim=service~claimNextCommand
  if \claim~ok then return claim
  package=claim~value; command=package~payload
  if \command~isA(.VMMExecutionCommand) then do
    ignore=service~nackCommandPackage(package)
    return .QueueOperationResult~failure("INVALID_EXECUTION_COMMAND",command~class~id)
  end
  prior=seenCommands[command~commandId]
  if prior<>.nil then do
    if command~action="SUBMIT" then event=.VMMExecutionAcknowledgement~new("ACK-"||command~commandId,command~commandId,command~orderId,command~idempotencyKey,command~correlationId,prior,adapterId,at)
    else event=.VMMExecutionCancelConfirmation~new("CANCEL-"||command~commandId,command~commandId,command~orderId,command~idempotencyKey,command~correlationId,venueOrderByOrder[command~orderId],adapterId,at)
    pub=service~publishEvent(event); if \pub~ok then do; ignore=service~nackCommandPackage(package); return pub; end
    ignore=service~acknowledgeCommandPackage(package)
    return .QueueOperationResult~success(event,"idempotent venue command replay")
  end
  if command~action="SUBMIT" then do
    venueRef="VENUE-"||command~orderId
    seenCommands[command~commandId]=venueRef; venueOrderByOrder[command~orderId]=venueRef; commandByOrder[command~orderId]=command
    event=.VMMExecutionAcknowledgement~new("ACK-"||command~commandId,command~commandId,command~orderId,command~idempotencyKey,command~correlationId,venueRef,adapterId,at)
  end
  else do
    seenCommands[command~commandId]="CANCELLED"
    commandByOrder[command~orderId]=commandByOrder[command~orderId]
    event=.VMMExecutionCancelConfirmation~new("CANCEL-"||command~commandId,command~commandId,command~orderId,command~idempotencyKey,command~correlationId,venueOrderByOrder[command~orderId],adapterId,at)
  end
  pub=service~publishEvent(event)
  if \pub~ok then do; ignore=service~nackCommandPackage(package); return pub; end
  ignore=service~acknowledgeCommandPackage(package)
  return .QueueOperationResult~success(event,"venue command processed")

::method publishFill
  expose service adapterId commandByOrder
  use strict arg orderId,fillId,venueExecutionRef,fillNotional,price,currency,executedAt,executingCounterparty,settlementRef=""
  command=commandByOrder[orderId]
  if command==.nil then raise syntax 88.900 array("venue adapter has no acknowledged VMM order",orderId)
  eventId="FILL-"||fillId
  e=.VMMExecutionFillEvent~new(eventId,command~commandId,orderId,"FILL-"||fillId,command~correlationId,fillId,venueExecutionRef,fillNotional,price,currency,executedAt,executingCounterparty,settlementRef,adapterId)
  return service~publishEvent(e)

::method publishUnknown
  expose service adapterId commandByOrder venueOrderByOrder
  use strict arg orderId,eventId,at,reasonCode="STATUS_UNKNOWN"
  command=commandByOrder[orderId]; if command==.nil then raise syntax 88.900 array("venue adapter has no VMM order",orderId)
  e=.VMMExecutionReconciliation~new(eventId,command~commandId,orderId,"RECON-"||eventId,command~correlationId,"UNKNOWN",venueOrderByOrder[orderId],reasonCode,adapterId,at)
  return service~publishEvent(e)

::method publishReconciledAcknowledged
  expose service adapterId commandByOrder venueOrderByOrder
  use strict arg orderId,eventId,at
  command=commandByOrder[orderId]; if command==.nil then raise syntax 88.900 array("venue adapter has no VMM order",orderId)
  e=.VMMExecutionReconciliation~new(eventId,command~commandId,orderId,"RECON-"||eventId,command~correlationId,"ACKNOWLEDGED",venueOrderByOrder[orderId],"",adapterId,at)
  return service~publishEvent(e)


::class VMMExecutionJsonAdapter public
::method init
  expose service adapterId
  use strict arg service,adapterId="JSON_EXECUTION_EDGE"
  if service==.nil | adapterId="" then raise syntax 88.900 array("VMM JSON execution adapter requires Queue Fabric service")

::method commandToJson
  use strict arg command
  if \command~isA(.VMMExecutionCommand) then raise syntax 88.900 array("VMMExecutionCommand required")
  d=.directory~new; d["protocol"]=.VMMExecutionBuild~protocol; d["kind"]="execution_command"; d["command_id"]=command~commandId; d["order_id"]=command~orderId; d["idempotency_key"]=command~idempotencyKey; d["correlation_id"]=command~correlationId; d["action"]=command~action
  d["instrument_key"]=command~instrumentKey; d["isin"]=command~isin; d["venue_mic"]=command~venueMic; d["quote_currency"]=command~quoteCurrency; d["settlement_currency"]=command~settlementCurrency; d["side"]=command~side; d["notional"]=command~notional; d["order_type"]=command~orderType; d["limit_price"]=command~limitPrice; d["origin"]=command~origin; if command~routeId<>"" then d["route_id"]=command~routeId; if command~targetAdapterId<>"" then d["target_adapter_id"]=command~targetAdapterId
  return .JSON~toJSON(d)

::method eventFromJson
  expose service adapterId
  use strict arg jsonText
  d=.JSON~fromJSON(jsonText)
  if \d~isA(.Directory) then raise syntax 88.900 array("VMM JSON execution event root must be object")
  if \d~hasIndex("protocol") | d["protocol"]<>.VMMExecutionBuild~protocol then raise syntax 88.900 array("VMM JSON execution protocol mismatch")
  if \d~hasIndex("type") then raise syntax 88.900 array("VMM JSON execution event type required")
  t=d["type"]~string~translate
  select
    when t="ACK" then e=.VMMExecutionAcknowledgement~new(self~text(d,"event_id"),self~text(d,"command_id"),self~text(d,"order_id"),self~text(d,"idempotency_key"),self~text(d,"correlation_id"),self~text(d,"venue_order_ref"),adapterId,self~text(d,"at"))
    when t="FILL" then e=.VMMExecutionFillEvent~new(self~text(d,"event_id"),self~text(d,"command_id"),self~text(d,"order_id"),self~text(d,"idempotency_key"),self~text(d,"correlation_id"),self~text(d,"fill_id"),self~text(d,"venue_execution_ref"),d["notional"]+0,d["price"]+0,self~text(d,"currency"),self~text(d,"at"),self~text(d,"executing_counterparty"),self~text(d,"settlement_ref",""),adapterId,self~text(d,"route_id",""),self~num(d,"fee_amount",0),self~num(d,"rebate_amount",0))
    when t="REJECT" then e=.VMMExecutionReject~new(self~text(d,"event_id"),self~text(d,"command_id"),self~text(d,"order_id"),self~text(d,"idempotency_key"),self~text(d,"correlation_id"),self~text(d,"reason_code"),self~text(d,"detail",""),adapterId,self~text(d,"at"))
    when t="CANCELLED" then e=.VMMExecutionCancelConfirmation~new(self~text(d,"event_id"),self~text(d,"command_id"),self~text(d,"order_id"),self~text(d,"idempotency_key"),self~text(d,"correlation_id"),self~text(d,"venue_order_ref",""),adapterId,self~text(d,"at"))
    when t="RECONCILE" then e=.VMMExecutionReconciliation~new(self~text(d,"event_id"),self~text(d,"command_id"),self~text(d,"order_id"),self~text(d,"idempotency_key"),self~text(d,"correlation_id"),self~text(d,"status"),self~text(d,"venue_order_ref",""),self~text(d,"reason_code",""),adapterId,self~text(d,"at"))
    otherwise raise syntax 88.900 array("unsupported VMM JSON execution event type",t)
  end
  /* Deliberately only enqueue. This adapter has no engine reference and cannot book a fill directly. */
  return service~publishEvent(e)

::method text private
  use strict arg d,key,defaultValue=""
  if \d~hasIndex(key) then return defaultValue
  return d[key]~string
::method num private
  use strict arg d,key,defaultValue=0
  if \d~hasIndex(key) then return defaultValue
  return d[key]+0

::requires "VectorMeridianMarkets.cls"
::requires "ObjectQueueFabric.cls"
::requires "json.cls"
