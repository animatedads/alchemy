/* Vector Meridian Markets v0.6 package; FederationBank arm's-length Queue Fabric protocol remains v0.3 */

::class VMMArmLengthBuild public
::method protocol class; return "vmm.federation.arm_length/0.3"
::method rfqQueue class; return "VMM.ARM_LENGTH.RFQ"
::method quoteQueue class; return "VMM.ARM_LENGTH.QUOTE"
::method executeQueue class; return "VMM.ARM_LENGTH.EXECUTE"
::method confirmQueue class; return "VMM.ARM_LENGTH.CONFIRM"
::method securityDomain class; return "VMM_FEDERATION_ARM_LENGTH"
::method federationPrincipal class; return "FEDERATIONBANK_MERCHANT_VMM_GATEWAY"
::method vmmPrincipal class; return "VECTOR_MERIDIAN_ARM_LENGTH_DEALER"
::method adminPrincipal class; return "VECTOR_MERIDIAN_ARM_LENGTH_ADMIN"


::class VMMArmLengthRFQ public
::method init
  expose rfqId idempotencyKey correlationId sourceEntity sourceAuthority instrumentRef economicUnderlyingId isin venueMic representationType quoteCurrency settlementCurrency denominationCurrency resolutionEvidenceRef productType customerSide notional anonRelationshipRef requestedAt
  use arg rfqId="",idempotencyKey="",correlationId="",sourceEntity="",sourceAuthority="",instrumentRef="",economicUnderlyingId="",isin="",venueMic="",representationType="",quoteCurrency="",settlementCurrency="",denominationCurrency="",resolutionEvidenceRef="",productType="",customerSide="",notional=0,anonRelationshipRef="",requestedAt=""
  if rfqId="" & correlationId="" then return
  if rfqId="" | idempotencyKey="" | correlationId="" | sourceEntity<>"FEDERATIONBANK_MERCHANT_BANK" | sourceAuthority="" then raise syntax 88.900 array("invalid Federation/VMM arm-length RFQ identity")
  if instrumentRef="" | economicUnderlyingId="" | isin="" | venueMic="" | representationType="" | quoteCurrency="" | settlementCurrency="" | denominationCurrency="" | resolutionEvidenceRef="" then raise syntax 88.900 array("arm-length RFQ requires exact instrument identity")
  if productType="" | anonRelationshipRef="" | requestedAt="" | notional<=0 then raise syntax 88.900 array("invalid arm-length RFQ economics/evidence")
  if customerSide<>"LONG" & customerSide<>"SHORT" then raise syntax 88.900 array("invalid arm-length RFQ customer side")
::method rfqId; expose rfqId; return rfqId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method sourceEntity; expose sourceEntity; return sourceEntity
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method instrumentRef; expose instrumentRef; return instrumentRef
::method economicUnderlyingId; expose economicUnderlyingId; return economicUnderlyingId
::method isin; expose isin; return isin
::method venueMic; expose venueMic; return venueMic
::method representationType; expose representationType; return representationType
::method quoteCurrency; expose quoteCurrency; return quoteCurrency
::method settlementCurrency; expose settlementCurrency; return settlementCurrency
::method denominationCurrency; expose denominationCurrency; return denominationCurrency
::method resolutionEvidenceRef; expose resolutionEvidenceRef; return resolutionEvidenceRef
::method productType; expose productType; return productType
::method customerSide; expose customerSide; return customerSide
::method notional; expose notional; return notional
::method anonRelationshipRef; expose anonRelationshipRef; return anonRelationshipRef
::method requestedAt; expose requestedAt; return requestedAt
::method queuePersistentType; return "vmm.arm_length.rfq/1"
::method queuePersistentState
  expose rfqId idempotencyKey correlationId sourceEntity sourceAuthority instrumentRef economicUnderlyingId isin venueMic representationType quoteCurrency settlementCurrency denominationCurrency resolutionEvidenceRef productType customerSide notional anonRelationshipRef requestedAt
  d=.table~new; d["rfqId"]=rfqId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["sourceEntity"]=sourceEntity; d["sourceAuthority"]=sourceAuthority; d["instrumentRef"]=instrumentRef; d["economicUnderlyingId"]=economicUnderlyingId; d["isin"]=isin; d["venueMic"]=venueMic; d["representationType"]=representationType; d["quoteCurrency"]=quoteCurrency; d["settlementCurrency"]=settlementCurrency; d["denominationCurrency"]=denominationCurrency; d["resolutionEvidenceRef"]=resolutionEvidenceRef; d["productType"]=productType; d["customerSide"]=customerSide; d["notional"]=notional; d["anonRelationshipRef"]=anonRelationshipRef; d["requestedAt"]=requestedAt; return d
::method queueRestoreState
  expose rfqId idempotencyKey correlationId sourceEntity sourceAuthority instrumentRef economicUnderlyingId isin venueMic representationType quoteCurrency settlementCurrency denominationCurrency resolutionEvidenceRef productType customerSide notional anonRelationshipRef requestedAt
  use arg d
  rfqId=d["rfqId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; sourceEntity=d["sourceEntity"]; sourceAuthority=d["sourceAuthority"]; instrumentRef=d["instrumentRef"]; economicUnderlyingId=d["economicUnderlyingId"]; isin=d["isin"]; venueMic=d["venueMic"]; representationType=d["representationType"]; quoteCurrency=d["quoteCurrency"]; settlementCurrency=d["settlementCurrency"]; denominationCurrency=d["denominationCurrency"]; resolutionEvidenceRef=d["resolutionEvidenceRef"]; productType=d["productType"]; customerSide=d["customerSide"]; notional=d["notional"]; anonRelationshipRef=d["anonRelationshipRef"]; requestedAt=d["requestedAt"]; return .true

::class VMMArmLengthRFQFactory public
::method newBlank; return .VMMArmLengthRFQ~new


::class VMMArmLengthQuote public
::method init
  expose responseId rfqId correlationId quoteId strategyId instrumentRef instrumentKey currency notional bid ask validUntil quotedAt vmmEntity
  use arg responseId="",rfqId="",correlationId="",quoteId="",strategyId="",instrumentRef="",instrumentKey="",currency="",notional=0,bid=0,ask=0,validUntil="",quotedAt="",vmmEntity=""
  if responseId="" & rfqId="" then return
  if responseId="" | rfqId="" | correlationId="" | quoteId="" | strategyId="" | instrumentRef="" | instrumentKey="" | currency="" | validUntil="" | quotedAt="" | vmmEntity<>"VECTOR_MERIDIAN_MARKETS_LTD" then raise syntax 88.900 array("invalid VMM arm-length quote response")
  if notional<=0 | bid<=0 | ask<=0 | ask<bid then raise syntax 88.900 array("invalid VMM arm-length quote economics")
::method responseId; expose responseId; return responseId
::method rfqId; expose rfqId; return rfqId
::method correlationId; expose correlationId; return correlationId
::method quoteId; expose quoteId; return quoteId
::method strategyId; expose strategyId; return strategyId
::method instrumentRef; expose instrumentRef; return instrumentRef
::method instrumentKey; expose instrumentKey; return instrumentKey
::method currency; expose currency; return currency
::method notional; expose notional; return notional
::method bid; expose bid; return bid
::method ask; expose ask; return ask
::method validUntil; expose validUntil; return validUntil
::method quotedAt; expose quotedAt; return quotedAt
::method vmmEntity; expose vmmEntity; return vmmEntity
::method queuePersistentType; return "vmm.arm_length.quote/1"
::method queuePersistentState
  expose responseId rfqId correlationId quoteId strategyId instrumentRef instrumentKey currency notional bid ask validUntil quotedAt vmmEntity
  d=.table~new; d["responseId"]=responseId; d["rfqId"]=rfqId; d["correlationId"]=correlationId; d["quoteId"]=quoteId; d["strategyId"]=strategyId; d["instrumentRef"]=instrumentRef; d["instrumentKey"]=instrumentKey; d["currency"]=currency; d["notional"]=notional; d["bid"]=bid; d["ask"]=ask; d["validUntil"]=validUntil; d["quotedAt"]=quotedAt; d["vmmEntity"]=vmmEntity; return d
::method queueRestoreState
  expose responseId rfqId correlationId quoteId strategyId instrumentRef instrumentKey currency notional bid ask validUntil quotedAt vmmEntity
  use arg d
  responseId=d["responseId"]; rfqId=d["rfqId"]; correlationId=d["correlationId"]; quoteId=d["quoteId"]; strategyId=d["strategyId"]; instrumentRef=d["instrumentRef"]; instrumentKey=d["instrumentKey"]; currency=d["currency"]; notional=d["notional"]; bid=d["bid"]; ask=d["ask"]; validUntil=d["validUntil"]; quotedAt=d["quotedAt"]; vmmEntity=d["vmmEntity"]; return .true

::class VMMArmLengthQuoteFactory public
::method newBlank; return .VMMArmLengthQuote~new


::class VMMArmLengthExecutionInstruction public
::method init
  expose instructionId idempotencyKey correlationId quoteId tradeId acceptedAt sourceEntity sourceAuthority
  use arg instructionId="",idempotencyKey="",correlationId="",quoteId="",tradeId="",acceptedAt="",sourceEntity="",sourceAuthority=""
  if instructionId="" & quoteId="" then return
  if instructionId="" | idempotencyKey="" | correlationId="" | quoteId="" | tradeId="" | acceptedAt="" | sourceEntity<>"FEDERATIONBANK_MERCHANT_BANK" | sourceAuthority="" then raise syntax 88.900 array("invalid VMM arm-length execution instruction")
::method instructionId; expose instructionId; return instructionId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method quoteId; expose quoteId; return quoteId
::method tradeId; expose tradeId; return tradeId
::method acceptedAt; expose acceptedAt; return acceptedAt
::method sourceEntity; expose sourceEntity; return sourceEntity
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method queuePersistentType; return "vmm.arm_length.execute/1"
::method queuePersistentState
  expose instructionId idempotencyKey correlationId quoteId tradeId acceptedAt sourceEntity sourceAuthority
  d=.table~new; d["instructionId"]=instructionId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["quoteId"]=quoteId; d["tradeId"]=tradeId; d["acceptedAt"]=acceptedAt; d["sourceEntity"]=sourceEntity; d["sourceAuthority"]=sourceAuthority; return d
::method queueRestoreState
  expose instructionId idempotencyKey correlationId quoteId tradeId acceptedAt sourceEntity sourceAuthority
  use arg d
  instructionId=d["instructionId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; quoteId=d["quoteId"]; tradeId=d["tradeId"]; acceptedAt=d["acceptedAt"]; sourceEntity=d["sourceEntity"]; sourceAuthority=d["sourceAuthority"]; return .true

::class VMMArmLengthExecutionInstructionFactory public
::method newBlank; return .VMMArmLengthExecutionInstruction~new


::class VMMArmLengthTradeConfirmation public
::method init
  expose confirmationId instructionId correlationId tradeId quoteId principalSide currency notional price executedAt vmmEntity counterpartyChannel
  use arg confirmationId="",instructionId="",correlationId="",tradeId="",quoteId="",principalSide="",currency="",notional=0,price=0,executedAt="",vmmEntity="",counterpartyChannel=""
  if confirmationId="" & tradeId="" then return
  if confirmationId="" | instructionId="" | correlationId="" | tradeId="" | quoteId="" | currency="" | executedAt="" | vmmEntity<>"VECTOR_MERIDIAN_MARKETS_LTD" | counterpartyChannel<>"FEDERATIONBANK_MERCHANT_FLOW" then raise syntax 88.900 array("invalid VMM arm-length trade confirmation")
  if principalSide<>"LONG" & principalSide<>"SHORT" | notional<=0 | price<=0 then raise syntax 88.900 array("invalid VMM arm-length trade confirmation economics")
::method confirmationId; expose confirmationId; return confirmationId
::method instructionId; expose instructionId; return instructionId
::method correlationId; expose correlationId; return correlationId
::method tradeId; expose tradeId; return tradeId
::method quoteId; expose quoteId; return quoteId
::method principalSide; expose principalSide; return principalSide
::method currency; expose currency; return currency
::method notional; expose notional; return notional
::method price; expose price; return price
::method executedAt; expose executedAt; return executedAt
::method vmmEntity; expose vmmEntity; return vmmEntity
::method counterpartyChannel; expose counterpartyChannel; return counterpartyChannel
::method queuePersistentType; return "vmm.arm_length.confirm/1"
::method queuePersistentState
  expose confirmationId instructionId correlationId tradeId quoteId principalSide currency notional price executedAt vmmEntity counterpartyChannel
  d=.table~new; d["confirmationId"]=confirmationId; d["instructionId"]=instructionId; d["correlationId"]=correlationId; d["tradeId"]=tradeId; d["quoteId"]=quoteId; d["principalSide"]=principalSide; d["currency"]=currency; d["notional"]=notional; d["price"]=price; d["executedAt"]=executedAt; d["vmmEntity"]=vmmEntity; d["counterpartyChannel"]=counterpartyChannel; return d
::method queueRestoreState
  expose confirmationId instructionId correlationId tradeId quoteId principalSide currency notional price executedAt vmmEntity counterpartyChannel
  use arg d
  confirmationId=d["confirmationId"]; instructionId=d["instructionId"]; correlationId=d["correlationId"]; tradeId=d["tradeId"]; quoteId=d["quoteId"]; principalSide=d["principalSide"]; currency=d["currency"]; notional=d["notional"]; price=d["price"]; executedAt=d["executedAt"]; vmmEntity=d["vmmEntity"]; counterpartyChannel=d["counterpartyChannel"]; return .true

::class VMMArmLengthTradeConfirmationFactory public
::method newBlank; return .VMMArmLengthTradeConfirmation~new


::class VMMArmLengthFlowService public
::method init
  expose vmm manager adminPrincipal federationPrincipal vmmPrincipal rfqByKey executionByKey
  use strict arg vmm,stateRoot,adminPrincipal="VECTOR_MERIDIAN_ARM_LENGTH_ADMIN",federationPrincipal="FEDERATIONBANK_MERCHANT_VMM_GATEWAY",vmmPrincipal="VECTOR_MERIDIAN_ARM_LENGTH_DEALER"
  if vmm==.nil | stateRoot="" then raise syntax 88.900 array("arm-length flow service requires VMM and durable Queue Fabric root")
  registry=.QueuePayloadTypeRegistry~new
  ignore=registry~register("vmm.arm_length.rfq/1",.VMMArmLengthRFQFactory~new)
  ignore=registry~register("vmm.arm_length.quote/1",.VMMArmLengthQuoteFactory~new)
  ignore=registry~register("vmm.arm_length.execute/1",.VMMArmLengthExecutionInstructionFactory~new)
  ignore=registry~register("vmm.arm_length.confirm/1",.VMMArmLengthTradeConfirmationFactory~new)
  manager=.ObjectQueueManager~new(stateRoot,.QueueGraphPayloadCodec~new(registry),adminPrincipal)
  self~ensureQueues
  rfqByKey=.directory~new; executionByKey=.directory~new
::method manager; expose manager; return manager

::method processNextRFQ
  expose vmm manager vmmPrincipal rfqByKey
  use strict arg strategyId,quoteId,referencePrice,spreadBps,validUntil,quotedAt
  claim=manager~claim(.VMMArmLengthBuild~rfqQueue,vmmPrincipal)
  if \claim~ok then return claim
  package=claim~value; msg=package~payload
  if \msg~isA(.VMMArmLengthRFQ) then return self~rejectPackage(.VMMArmLengthBuild~rfqQueue,package,"INVALID_ARM_LENGTH_RFQ")
  prior=rfqByKey[msg~idempotencyKey]
  if prior<>.nil then do
    pub=self~put(.VMMArmLengthBuild~quoteQueue,prior,msg~correlationId,"QUOTE",msg~idempotencyKey,vmmPrincipal)
    if \pub~ok then return self~retryPackage(.VMMArmLengthBuild~rfqQueue,package,pub)
    ignore=self~ack(.VMMArmLengthBuild~rfqQueue,package,vmmPrincipal)
    return .QueueOperationResult~success(prior,"idempotent RFQ replay")
  end
  i=.VMMTradableInstrument~new(msg~instrumentRef,msg~economicUnderlyingId,msg~isin,msg~venueMic,msg~representationType,msg~quoteCurrency,msg~settlementCurrency,msg~denominationCurrency,msg~resolutionEvidenceRef)
  r=.VMMFlowRequest~new(msg~rfqId,msg~instrumentRef,msg~productType,msg~customerSide,msg~quoteCurrency,msg~notional,msg~anonRelationshipRef,msg~sourceEntity,msg~requestedAt,"",i)
  q=vmm~requestQuote(r,strategyId,quoteId,referencePrice,spreadBps,validUntil)
  response=.VMMArmLengthQuote~new("RESP-"||msg~rfqId,msg~rfqId,msg~correlationId,q~quoteId,q~strategyId,q~instrumentRef,q~instrumentKey,q~currency,q~notional,q~bid,q~ask,q~validUntil,quotedAt,vmm~legalEntity)
  pub=self~put(.VMMArmLengthBuild~quoteQueue,response,msg~correlationId,"QUOTE",msg~idempotencyKey,vmmPrincipal)
  if \pub~ok then return self~retryPackage(.VMMArmLengthBuild~rfqQueue,package,pub)
  rfqByKey[msg~idempotencyKey]=response
  ignore=self~ack(.VMMArmLengthBuild~rfqQueue,package,vmmPrincipal)
  return .QueueOperationResult~success(response,"RFQ priced by VMM")

::method processNextExecution
  expose vmm manager vmmPrincipal executionByKey
  claim=manager~claim(.VMMArmLengthBuild~executeQueue,vmmPrincipal)
  if \claim~ok then return claim
  package=claim~value; msg=package~payload
  if \msg~isA(.VMMArmLengthExecutionInstruction) then return self~rejectPackage(.VMMArmLengthBuild~executeQueue,package,"INVALID_ARM_LENGTH_EXECUTION")
  prior=executionByKey[msg~idempotencyKey]
  if prior<>.nil then do
    pub=self~put(.VMMArmLengthBuild~confirmQueue,prior,msg~correlationId,"CONFIRM",msg~idempotencyKey,vmmPrincipal)
    if \pub~ok then return self~retryPackage(.VMMArmLengthBuild~executeQueue,package,pub)
    ignore=self~ack(.VMMArmLengthBuild~executeQueue,package,vmmPrincipal)
    return .QueueOperationResult~success(prior,"idempotent execution replay")
  end
  t=vmm~executeQuote(msg~tradeId,msg~quoteId,msg~acceptedAt,"ARM_LENGTH_QUEUE:"||msg~sourceAuthority)
  c=.VMMArmLengthTradeConfirmation~new("CONF-"||msg~instructionId,msg~instructionId,msg~correlationId,t~tradeId,t~quoteId,t~principalSide,t~currency,t~notional,t~price,t~executedAt,vmm~legalEntity,t~counterpartyChannel)
  pub=self~put(.VMMArmLengthBuild~confirmQueue,c,msg~correlationId,"CONFIRM",msg~idempotencyKey,vmmPrincipal)
  if \pub~ok then return self~retryPackage(.VMMArmLengthBuild~executeQueue,package,pub)
  executionByKey[msg~idempotencyKey]=c
  ignore=self~ack(.VMMArmLengthBuild~executeQueue,package,vmmPrincipal)
  return .QueueOperationResult~success(c,"arm-length execution booked by VMM")

::method ensureQueues private
  expose manager adminPrincipal federationPrincipal vmmPrincipal
  domain=.VMMArmLengthBuild~securityDomain
  do qname over .array~of(.VMMArmLengthBuild~rfqQueue,.VMMArmLengthBuild~quoteQueue,.VMMArmLengthBuild~executeQueue,.VMMArmLengthBuild~confirmQueue)
    if manager~queue(qname)==.nil then self~must(manager~createQueue(qname,"PERMANENT",domain,0,adminPrincipal),"create "||qname)
  end
  self~must(manager~grant(.VMMArmLengthBuild~rfqQueue,federationPrincipal,.QueueAccess~PUT,adminPrincipal),"federation RFQ PUT")
  self~must(manager~grant(.VMMArmLengthBuild~rfqQueue,vmmPrincipal,.QueueAccess~GET,adminPrincipal),"VMM RFQ GET")
  self~must(manager~grant(.VMMArmLengthBuild~quoteQueue,vmmPrincipal,.QueueAccess~PUT,adminPrincipal),"VMM quote PUT")
  self~must(manager~grant(.VMMArmLengthBuild~quoteQueue,federationPrincipal,.QueueAccess~GET,adminPrincipal),"federation quote GET")
  self~must(manager~grant(.VMMArmLengthBuild~executeQueue,federationPrincipal,.QueueAccess~PUT,adminPrincipal),"federation execute PUT")
  self~must(manager~grant(.VMMArmLengthBuild~executeQueue,vmmPrincipal,.QueueAccess~GET,adminPrincipal),"VMM execute GET")
  self~must(manager~grant(.VMMArmLengthBuild~confirmQueue,vmmPrincipal,.QueueAccess~PUT,adminPrincipal),"VMM confirm PUT")
  self~must(manager~grant(.VMMArmLengthBuild~confirmQueue,federationPrincipal,.QueueAccess~GET,adminPrincipal),"federation confirm GET")
  return .true

::method put private
  expose manager
  use strict arg queueName,payload,correlationId,kind,idempotencyKey,principal
  o=.table~new; o["persistent"]=.true; o["correlationId"]=correlationId
  h=.table~new; h["protocol"]=.VMMArmLengthBuild~protocol; h["kind"]=kind; h["idempotencyKey"]=idempotencyKey; o["headers"]=h
  return manager~put(queueName,payload,o,principal)
::method ack private
  expose manager
  use strict arg queueName,package,principal
  return manager~ack(queueName,package~packageId,package~claimToken,principal)
::method rejectPackage private
  expose manager vmmPrincipal
  use strict arg queueName,package,code
  ignore=manager~nack(queueName,package~packageId,package~claimToken,vmmPrincipal)
  return .QueueOperationResult~failure(code)
::method retryPackage private
  expose manager vmmPrincipal
  use strict arg queueName,package,failure
  ignore=manager~nack(queueName,package~packageId,package~claimToken,vmmPrincipal)
  return failure
::method must private
  use strict arg resultObject,label
  if \resultObject~ok then raise syntax 88.900 array("arm-length Queue Fabric setup failed",label,resultObject~code,resultObject~detail)
  return resultObject


::class FederationMerchantVMMQueueClient public
::method init
  expose manager federationPrincipal submittedRFQ submittedExecution
  use strict arg manager,federationPrincipal="FEDERATIONBANK_MERCHANT_VMM_GATEWAY"
  if manager==.nil then raise syntax 88.900 array("Federation/VMM queue client requires Queue Fabric manager")
  submittedRFQ=.directory~new; submittedExecution=.directory~new

::method submitRFQ
  expose manager federationPrincipal submittedRFQ
  use strict arg msg
  if \msg~isA(.VMMArmLengthRFQ) then raise syntax 88.900 array("VMMArmLengthRFQ required")
  prior=submittedRFQ[msg~idempotencyKey]
  if prior<>.nil then return .QueueOperationResult~success(prior,"idempotent Federation RFQ")
  r=self~put(.VMMArmLengthBuild~rfqQueue,msg,msg~correlationId,"RFQ",msg~idempotencyKey)
  if r~ok then submittedRFQ[msg~idempotencyKey]=msg
  return r
::method receiveQuote
  expose manager federationPrincipal
  r=manager~claim(.VMMArmLengthBuild~quoteQueue,federationPrincipal)
  if \r~ok then return r
  p=r~value; q=p~payload; a=manager~ack(.VMMArmLengthBuild~quoteQueue,p~packageId,p~claimToken,federationPrincipal)
  if \a~ok then return a
  return .QueueOperationResult~success(q,"quote received")
::method submitExecution
  expose manager federationPrincipal submittedExecution
  use strict arg msg
  if \msg~isA(.VMMArmLengthExecutionInstruction) then raise syntax 88.900 array("VMMArmLengthExecutionInstruction required")
  prior=submittedExecution[msg~idempotencyKey]
  if prior<>.nil then return .QueueOperationResult~success(prior,"idempotent Federation execution")
  r=self~put(.VMMArmLengthBuild~executeQueue,msg,msg~correlationId,"EXECUTE",msg~idempotencyKey)
  if r~ok then submittedExecution[msg~idempotencyKey]=msg
  return r
::method receiveTradeConfirmation
  expose manager federationPrincipal
  r=manager~claim(.VMMArmLengthBuild~confirmQueue,federationPrincipal)
  if \r~ok then return r
  p=r~value; c=p~payload; a=manager~ack(.VMMArmLengthBuild~confirmQueue,p~packageId,p~claimToken,federationPrincipal)
  if \a~ok then return a
  return .QueueOperationResult~success(c,"trade confirmation received")
::method put private
  expose manager federationPrincipal
  use strict arg queueName,payload,correlationId,kind,idempotencyKey
  o=.table~new; o["persistent"]=.true; o["correlationId"]=correlationId
  h=.table~new; h["protocol"]=.VMMArmLengthBuild~protocol; h["kind"]=kind; h["idempotencyKey"]=idempotencyKey; o["headers"]=h
  return manager~put(queueName,payload,o,federationPrincipal)

::requires "VectorMeridianMarkets.cls"
::requires "ObjectQueueFabric.cls"
