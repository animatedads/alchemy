/* VectorMeridianInstitutionalSyntheticQueue.cls -- contract-formation queue boundary remains protocol v0.5 in VMM v0.6 */

::class VMMInstitutionalSyntheticQueueBuild public
::method protocol class; return "vmm.institutional.synthetic/0.5"
::method requestQueue class; return "VMM.INSTITUTIONAL.SYNTHETIC.REQUEST"
::method offerQueue class; return "VMM.INSTITUTIONAL.SYNTHETIC.OFFER"
::method acceptQueue class; return "VMM.INSTITUTIONAL.SYNTHETIC.ACCEPT"
::method confirmQueue class; return "VMM.INSTITUTIONAL.SYNTHETIC.CONFIRM"
::method securityDomain class; return "VMM_INSTITUTIONAL_SYNTHETIC"
::method vmmPrincipal class; return "VECTOR_MERIDIAN_SYNTHETIC_DEALER"
::method adminPrincipal class; return "VECTOR_MERIDIAN_SYNTHETIC_ADMIN"


::class VMMInstitutionalSyntheticRequest public
::method init
  expose requestId idempotencyKey correlationId counterpartyId sourceEntity sourceAuthority portfolioSnapshotId productType currency requestedNotional requestedMaturity requestedAt
  use arg requestId="",idempotencyKey="",correlationId="",counterpartyId="",sourceEntity="",sourceAuthority="",portfolioSnapshotId="",productType="",currency="",requestedNotional=0,requestedMaturity="",requestedAt=""
  if requestId="" & correlationId="" then return
  if requestId="" | idempotencyKey="" | correlationId="" | counterpartyId="" | sourceEntity="" | sourceAuthority="" | portfolioSnapshotId="" | currency="" | requestedMaturity="" | requestedAt="" then raise syntax 88.900 array("invalid VMM institutional synthetic request")
  if productType<>"PORTFOLIO_LOSS_PROTECTION" | requestedNotional<=0 then raise syntax 88.900 array("invalid VMM institutional synthetic request economics")
::method requestId; expose requestId; return requestId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method sourceEntity; expose sourceEntity; return sourceEntity
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method portfolioSnapshotId; expose portfolioSnapshotId; return portfolioSnapshotId
::method productType; expose productType; return productType
::method currency; expose currency; return currency
::method requestedNotional; expose requestedNotional; return requestedNotional
::method requestedMaturity; expose requestedMaturity; return requestedMaturity
::method requestedAt; expose requestedAt; return requestedAt
::method queuePersistentType; return "vmm.synthetic.request/1"
::method queuePersistentState
  expose requestId idempotencyKey correlationId counterpartyId sourceEntity sourceAuthority portfolioSnapshotId productType currency requestedNotional requestedMaturity requestedAt
  d=.table~new; d["requestId"]=requestId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["counterpartyId"]=counterpartyId; d["sourceEntity"]=sourceEntity; d["sourceAuthority"]=sourceAuthority; d["portfolioSnapshotId"]=portfolioSnapshotId; d["productType"]=productType; d["currency"]=currency; d["requestedNotional"]=requestedNotional; d["requestedMaturity"]=requestedMaturity; d["requestedAt"]=requestedAt; return d
::method queueRestoreState
  expose requestId idempotencyKey correlationId counterpartyId sourceEntity sourceAuthority portfolioSnapshotId productType currency requestedNotional requestedMaturity requestedAt
  use arg d
  requestId=d["requestId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; counterpartyId=d["counterpartyId"]; sourceEntity=d["sourceEntity"]; sourceAuthority=d["sourceAuthority"]; portfolioSnapshotId=d["portfolioSnapshotId"]; productType=d["productType"]; currency=d["currency"]; requestedNotional=d["requestedNotional"]; requestedMaturity=d["requestedMaturity"]; requestedAt=d["requestedAt"]; return .true
::class VMMInstitutionalSyntheticRequestFactory public
::method newBlank; return .VMMInstitutionalSyntheticRequest~new


::class VMMInstitutionalSyntheticOfferMessage public
::method init
  expose responseId requestId correlationId offerId counterpartyId portfolioSnapshotId currency protectedNotional attachmentLossPct exhaustionLossPct premiumAmount maturity validUntil offeredAt vmmEntity
  use arg responseId="",requestId="",correlationId="",offerId="",counterpartyId="",portfolioSnapshotId="",currency="",protectedNotional=0,attachmentLossPct=0,exhaustionLossPct=0,premiumAmount=0,maturity="",validUntil="",offeredAt="",vmmEntity=""
  if responseId="" & offerId="" then return
  if responseId="" | requestId="" | correlationId="" | offerId="" | counterpartyId="" | portfolioSnapshotId="" | currency="" | maturity="" | validUntil="" | offeredAt="" | vmmEntity<>"VECTOR_MERIDIAN_MARKETS_LTD" then raise syntax 88.900 array("invalid VMM institutional synthetic offer message")
  if protectedNotional<=0 | attachmentLossPct<0 | exhaustionLossPct<=attachmentLossPct | premiumAmount<0 then raise syntax 88.900 array("invalid VMM institutional synthetic offer economics")
::method responseId; expose responseId; return responseId
::method requestId; expose requestId; return requestId
::method correlationId; expose correlationId; return correlationId
::method offerId; expose offerId; return offerId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method portfolioSnapshotId; expose portfolioSnapshotId; return portfolioSnapshotId
::method currency; expose currency; return currency
::method protectedNotional; expose protectedNotional; return protectedNotional
::method attachmentLossPct; expose attachmentLossPct; return attachmentLossPct
::method exhaustionLossPct; expose exhaustionLossPct; return exhaustionLossPct
::method premiumAmount; expose premiumAmount; return premiumAmount
::method maturity; expose maturity; return maturity
::method validUntil; expose validUntil; return validUntil
::method offeredAt; expose offeredAt; return offeredAt
::method vmmEntity; expose vmmEntity; return vmmEntity
::method queuePersistentType; return "vmm.synthetic.offer/1"
::method queuePersistentState
  expose responseId requestId correlationId offerId counterpartyId portfolioSnapshotId currency protectedNotional attachmentLossPct exhaustionLossPct premiumAmount maturity validUntil offeredAt vmmEntity
  d=.table~new; d["responseId"]=responseId; d["requestId"]=requestId; d["correlationId"]=correlationId; d["offerId"]=offerId; d["counterpartyId"]=counterpartyId; d["portfolioSnapshotId"]=portfolioSnapshotId; d["currency"]=currency; d["protectedNotional"]=protectedNotional; d["attachmentLossPct"]=attachmentLossPct; d["exhaustionLossPct"]=exhaustionLossPct; d["premiumAmount"]=premiumAmount; d["maturity"]=maturity; d["validUntil"]=validUntil; d["offeredAt"]=offeredAt; d["vmmEntity"]=vmmEntity; return d
::method queueRestoreState
  expose responseId requestId correlationId offerId counterpartyId portfolioSnapshotId currency protectedNotional attachmentLossPct exhaustionLossPct premiumAmount maturity validUntil offeredAt vmmEntity
  use arg d
  responseId=d["responseId"]; requestId=d["requestId"]; correlationId=d["correlationId"]; offerId=d["offerId"]; counterpartyId=d["counterpartyId"]; portfolioSnapshotId=d["portfolioSnapshotId"]; currency=d["currency"]; protectedNotional=d["protectedNotional"]; attachmentLossPct=d["attachmentLossPct"]; exhaustionLossPct=d["exhaustionLossPct"]; premiumAmount=d["premiumAmount"]; maturity=d["maturity"]; validUntil=d["validUntil"]; offeredAt=d["offeredAt"]; vmmEntity=d["vmmEntity"]; return .true
::class VMMInstitutionalSyntheticOfferMessageFactory public
::method newBlank; return .VMMInstitutionalSyntheticOfferMessage~new


::class VMMInstitutionalSyntheticAcceptance public
::method init
  expose acceptanceId idempotencyKey correlationId offerId contractId counterpartyId sourceEntity sourceAuthority acceptedAt
  use arg acceptanceId="",idempotencyKey="",correlationId="",offerId="",contractId="",counterpartyId="",sourceEntity="",sourceAuthority="",acceptedAt=""
  if acceptanceId="" & offerId="" then return
  if acceptanceId="" | idempotencyKey="" | correlationId="" | offerId="" | contractId="" | counterpartyId="" | sourceEntity="" | sourceAuthority="" | acceptedAt="" then raise syntax 88.900 array("invalid VMM institutional synthetic acceptance")
::method acceptanceId; expose acceptanceId; return acceptanceId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method offerId; expose offerId; return offerId
::method contractId; expose contractId; return contractId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method sourceEntity; expose sourceEntity; return sourceEntity
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method acceptedAt; expose acceptedAt; return acceptedAt
::method queuePersistentType; return "vmm.synthetic.accept/1"
::method queuePersistentState
  expose acceptanceId idempotencyKey correlationId offerId contractId counterpartyId sourceEntity sourceAuthority acceptedAt
  d=.table~new; d["acceptanceId"]=acceptanceId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["offerId"]=offerId; d["contractId"]=contractId; d["counterpartyId"]=counterpartyId; d["sourceEntity"]=sourceEntity; d["sourceAuthority"]=sourceAuthority; d["acceptedAt"]=acceptedAt; return d
::method queueRestoreState
  expose acceptanceId idempotencyKey correlationId offerId contractId counterpartyId sourceEntity sourceAuthority acceptedAt
  use arg d
  acceptanceId=d["acceptanceId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; offerId=d["offerId"]; contractId=d["contractId"]; counterpartyId=d["counterpartyId"]; sourceEntity=d["sourceEntity"]; sourceAuthority=d["sourceAuthority"]; acceptedAt=d["acceptedAt"]; return .true
::class VMMInstitutionalSyntheticAcceptanceFactory public
::method newBlank; return .VMMInstitutionalSyntheticAcceptance~new


::class VMMInstitutionalSyntheticConfirmation public
::method init
  expose confirmationId acceptanceId correlationId offerId contractId counterpartyId currency protectedNotional premiumAmount tradeDate vmmEntity
  use arg confirmationId="",acceptanceId="",correlationId="",offerId="",contractId="",counterpartyId="",currency="",protectedNotional=0,premiumAmount=0,tradeDate="",vmmEntity=""
  if confirmationId="" & contractId="" then return
  if confirmationId="" | acceptanceId="" | correlationId="" | offerId="" | contractId="" | counterpartyId="" | currency="" | tradeDate="" | vmmEntity<>"VECTOR_MERIDIAN_MARKETS_LTD" then raise syntax 88.900 array("invalid VMM institutional synthetic confirmation")
  if protectedNotional<=0 | premiumAmount<0 then raise syntax 88.900 array("invalid VMM institutional synthetic confirmation economics")
::method confirmationId; expose confirmationId; return confirmationId
::method acceptanceId; expose acceptanceId; return acceptanceId
::method correlationId; expose correlationId; return correlationId
::method offerId; expose offerId; return offerId
::method contractId; expose contractId; return contractId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method currency; expose currency; return currency
::method protectedNotional; expose protectedNotional; return protectedNotional
::method premiumAmount; expose premiumAmount; return premiumAmount
::method tradeDate; expose tradeDate; return tradeDate
::method vmmEntity; expose vmmEntity; return vmmEntity
::method queuePersistentType; return "vmm.synthetic.confirm/1"
::method queuePersistentState
  expose confirmationId acceptanceId correlationId offerId contractId counterpartyId currency protectedNotional premiumAmount tradeDate vmmEntity
  d=.table~new; d["confirmationId"]=confirmationId; d["acceptanceId"]=acceptanceId; d["correlationId"]=correlationId; d["offerId"]=offerId; d["contractId"]=contractId; d["counterpartyId"]=counterpartyId; d["currency"]=currency; d["protectedNotional"]=protectedNotional; d["premiumAmount"]=premiumAmount; d["tradeDate"]=tradeDate; d["vmmEntity"]=vmmEntity; return d
::method queueRestoreState
  expose confirmationId acceptanceId correlationId offerId contractId counterpartyId currency protectedNotional premiumAmount tradeDate vmmEntity
  use arg d
  confirmationId=d["confirmationId"]; acceptanceId=d["acceptanceId"]; correlationId=d["correlationId"]; offerId=d["offerId"]; contractId=d["contractId"]; counterpartyId=d["counterpartyId"]; currency=d["currency"]; protectedNotional=d["protectedNotional"]; premiumAmount=d["premiumAmount"]; tradeDate=d["tradeDate"]; vmmEntity=d["vmmEntity"]; return .true
::class VMMInstitutionalSyntheticConfirmationFactory public
::method newBlank; return .VMMInstitutionalSyntheticConfirmation~new


::class VMMInstitutionalSyntheticQueueService public
::method init
  expose productService manager adminPrincipal clientPrincipal vmmPrincipal clientEntity counterpartyId requestByKey acceptanceByKey
  use strict arg productService,stateRoot,clientPrincipal,clientEntity,counterpartyId,adminPrincipal="VECTOR_MERIDIAN_SYNTHETIC_ADMIN",vmmPrincipal="VECTOR_MERIDIAN_SYNTHETIC_DEALER"
  if productService==.nil | stateRoot="" | clientPrincipal="" | clientEntity="" | counterpartyId="" then raise syntax 88.900 array("institutional synthetic queue service requires product service, durable root and client identity")
  registry=.QueuePayloadTypeRegistry~new
  ignore=registry~register("vmm.synthetic.request/1",.VMMInstitutionalSyntheticRequestFactory~new)
  ignore=registry~register("vmm.synthetic.offer/1",.VMMInstitutionalSyntheticOfferMessageFactory~new)
  ignore=registry~register("vmm.synthetic.accept/1",.VMMInstitutionalSyntheticAcceptanceFactory~new)
  ignore=registry~register("vmm.synthetic.confirm/1",.VMMInstitutionalSyntheticConfirmationFactory~new)
  manager=.ObjectQueueManager~new(stateRoot,.QueueGraphPayloadCodec~new(registry),adminPrincipal)
  requestByKey=.directory~new; acceptanceByKey=.directory~new
  self~ensureQueues
::method manager; expose manager; return manager
::method processNextRequest
  expose productService manager vmmPrincipal clientEntity counterpartyId requestByKey
  use strict arg offerId,attachmentLossPct,exhaustionLossPct,premiumAmount,effectiveAt,validUntil,offeredAt,modelEvidenceRef,marketDataEvidenceRef,riskApprovalRef
  claim=manager~claim(.VMMInstitutionalSyntheticQueueBuild~requestQueue,vmmPrincipal); if \claim~ok then return claim
  package=claim~value; msg=package~payload
  if \msg~isA(.VMMInstitutionalSyntheticRequest) then return self~reject(.VMMInstitutionalSyntheticQueueBuild~requestQueue,package,"INVALID_SYNTHETIC_REQUEST")
  if msg~sourceEntity<>clientEntity | msg~counterpartyId<>counterpartyId then return self~reject(.VMMInstitutionalSyntheticQueueBuild~requestQueue,package,"INSTITUTIONAL_IDENTITY_MISMATCH")
  prior=requestByKey[msg~idempotencyKey]
  if prior<>.nil then do
    pub=self~put(.VMMInstitutionalSyntheticQueueBuild~offerQueue,prior,msg~correlationId,"OFFER",msg~idempotencyKey,vmmPrincipal); if \pub~ok then return self~retry(.VMMInstitutionalSyntheticQueueBuild~requestQueue,package,pub)
    ignore=self~ack(.VMMInstitutionalSyntheticQueueBuild~requestQueue,package,vmmPrincipal); return .QueueOperationResult~success(prior,"idempotent institutional synthetic request")
  end
  o=productService~createOffer(offerId,msg~requestId,msg~counterpartyId,msg~portfolioSnapshotId,msg~currency,msg~requestedNotional,attachmentLossPct,exhaustionLossPct,premiumAmount,effectiveAt,msg~requestedMaturity,validUntil,offeredAt,modelEvidenceRef,marketDataEvidenceRef,riskApprovalRef)
  t=o~terms
  response=.VMMInstitutionalSyntheticOfferMessage~new("RESP-"||msg~requestId,msg~requestId,msg~correlationId,o~offerId,o~counterpartyId,t~snapshotId,t~currency,t~protectedNotional,t~attachmentLossPct,t~exhaustionLossPct,t~premiumAmount,t~maturity,o~validUntil,o~offeredAt,productService~vmm~legalEntity)
  pub=self~put(.VMMInstitutionalSyntheticQueueBuild~offerQueue,response,msg~correlationId,"OFFER",msg~idempotencyKey,vmmPrincipal); if \pub~ok then return self~retry(.VMMInstitutionalSyntheticQueueBuild~requestQueue,package,pub)
  requestByKey[msg~idempotencyKey]=response; ignore=self~ack(.VMMInstitutionalSyntheticQueueBuild~requestQueue,package,vmmPrincipal)
  return .QueueOperationResult~success(response,"institutional synthetic request priced")
::method processNextAcceptance
  expose productService manager vmmPrincipal clientEntity counterpartyId acceptanceByKey
  claim=manager~claim(.VMMInstitutionalSyntheticQueueBuild~acceptQueue,vmmPrincipal); if \claim~ok then return claim
  package=claim~value; msg=package~payload
  if \msg~isA(.VMMInstitutionalSyntheticAcceptance) then return self~reject(.VMMInstitutionalSyntheticQueueBuild~acceptQueue,package,"INVALID_SYNTHETIC_ACCEPTANCE")
  if msg~sourceEntity<>clientEntity | msg~counterpartyId<>counterpartyId then return self~reject(.VMMInstitutionalSyntheticQueueBuild~acceptQueue,package,"INSTITUTIONAL_IDENTITY_MISMATCH")
  prior=acceptanceByKey[msg~idempotencyKey]
  if prior<>.nil then do
    pub=self~put(.VMMInstitutionalSyntheticQueueBuild~confirmQueue,prior,msg~correlationId,"CONFIRM",msg~idempotencyKey,vmmPrincipal); if \pub~ok then return self~retry(.VMMInstitutionalSyntheticQueueBuild~acceptQueue,package,pub)
    ignore=self~ack(.VMMInstitutionalSyntheticQueueBuild~acceptQueue,package,vmmPrincipal); return .QueueOperationResult~success(prior,"idempotent institutional synthetic acceptance")
  end
  k=productService~acceptOffer(msg~contractId,msg~offerId,msg~acceptedAt,msg~sourceEntity,msg~sourceAuthority)
  c=.VMMInstitutionalSyntheticConfirmation~new("CONF-"||msg~acceptanceId,msg~acceptanceId,msg~correlationId,k~offerId,k~contractId,k~counterpartyId,k~terms~currency,k~terms~protectedNotional,k~terms~premiumAmount,k~tradeDate,productService~vmm~legalEntity)
  pub=self~put(.VMMInstitutionalSyntheticQueueBuild~confirmQueue,c,msg~correlationId,"CONFIRM",msg~idempotencyKey,vmmPrincipal); if \pub~ok then return self~retry(.VMMInstitutionalSyntheticQueueBuild~acceptQueue,package,pub)
  acceptanceByKey[msg~idempotencyKey]=c; ignore=self~ack(.VMMInstitutionalSyntheticQueueBuild~acceptQueue,package,vmmPrincipal)
  return .QueueOperationResult~success(c,"institutional synthetic contract booked")
::method ensureQueues private
  expose manager adminPrincipal clientPrincipal vmmPrincipal
  domain=.VMMInstitutionalSyntheticQueueBuild~securityDomain
  do q over .array~of(.VMMInstitutionalSyntheticQueueBuild~requestQueue,.VMMInstitutionalSyntheticQueueBuild~offerQueue,.VMMInstitutionalSyntheticQueueBuild~acceptQueue,.VMMInstitutionalSyntheticQueueBuild~confirmQueue)
    if manager~queue(q)==.nil then self~must(manager~createQueue(q,"PERMANENT",domain,0,adminPrincipal),"create "||q)
  end
  self~must(manager~grant(.VMMInstitutionalSyntheticQueueBuild~requestQueue,clientPrincipal,.QueueAccess~PUT,adminPrincipal),"client request PUT")
  self~must(manager~grant(.VMMInstitutionalSyntheticQueueBuild~requestQueue,vmmPrincipal,.QueueAccess~GET,adminPrincipal),"VMM request GET")
  self~must(manager~grant(.VMMInstitutionalSyntheticQueueBuild~offerQueue,vmmPrincipal,.QueueAccess~PUT,adminPrincipal),"VMM offer PUT")
  self~must(manager~grant(.VMMInstitutionalSyntheticQueueBuild~offerQueue,clientPrincipal,.QueueAccess~GET,adminPrincipal),"client offer GET")
  self~must(manager~grant(.VMMInstitutionalSyntheticQueueBuild~acceptQueue,clientPrincipal,.QueueAccess~PUT,adminPrincipal),"client accept PUT")
  self~must(manager~grant(.VMMInstitutionalSyntheticQueueBuild~acceptQueue,vmmPrincipal,.QueueAccess~GET,adminPrincipal),"VMM accept GET")
  self~must(manager~grant(.VMMInstitutionalSyntheticQueueBuild~confirmQueue,vmmPrincipal,.QueueAccess~PUT,adminPrincipal),"VMM confirm PUT")
  self~must(manager~grant(.VMMInstitutionalSyntheticQueueBuild~confirmQueue,clientPrincipal,.QueueAccess~GET,adminPrincipal),"client confirm GET")
::method put private
  expose manager
  use strict arg queueName,payload,correlationId,kind,idempotencyKey,principal
  o=.table~new; o["persistent"]=.true; o["correlationId"]=correlationId; h=.table~new; h["protocol"]=.VMMInstitutionalSyntheticQueueBuild~protocol; h["kind"]=kind; h["idempotencyKey"]=idempotencyKey; o["headers"]=h
  return manager~put(queueName,payload,o,principal)
::method ack private
  expose manager
  use strict arg queueName,package,principal
  return manager~ack(queueName,package~packageId,package~claimToken,principal)
::method reject private
  expose manager vmmPrincipal
  use strict arg queueName,package,code
  ignore=manager~nack(queueName,package~packageId,package~claimToken,vmmPrincipal); return .QueueOperationResult~failure(code)
::method retry private
  expose manager vmmPrincipal
  use strict arg queueName,package,failure
  ignore=manager~nack(queueName,package~packageId,package~claimToken,vmmPrincipal); return failure
::method must private
  use strict arg result,label
  if \result~ok then raise syntax 88.900 array("institutional synthetic Queue Fabric setup failed",label,result~code,result~detail)
  return result


::class VMMInstitutionalSyntheticQueueClient public
::method init
  expose manager clientPrincipal clientEntity counterpartyId submittedRequests submittedAcceptances
  use strict arg manager,clientPrincipal,clientEntity,counterpartyId
  if manager==.nil | clientPrincipal="" | clientEntity="" | counterpartyId="" then raise syntax 88.900 array("institutional synthetic queue client requires manager and legal identity")
  submittedRequests=.directory~new; submittedAcceptances=.directory~new
::method submitRequest
  expose manager clientPrincipal clientEntity counterpartyId submittedRequests
  use strict arg msg
  if \msg~isA(.VMMInstitutionalSyntheticRequest) then raise syntax 88.900 array("VMMInstitutionalSyntheticRequest required")
  if msg~sourceEntity<>clientEntity | msg~counterpartyId<>counterpartyId then raise syntax 88.900 array("institutional synthetic client message identity mismatch")
  prior=submittedRequests[msg~idempotencyKey]; if prior<>.nil then return .QueueOperationResult~success(prior,"idempotent institutional request")
  r=self~put(.VMMInstitutionalSyntheticQueueBuild~requestQueue,msg,msg~correlationId,"REQUEST",msg~idempotencyKey); if r~ok then submittedRequests[msg~idempotencyKey]=msg; return r
::method receiveOffer
  expose manager clientPrincipal
  r=manager~claim(.VMMInstitutionalSyntheticQueueBuild~offerQueue,clientPrincipal); if \r~ok then return r
  p=r~value; o=p~payload; a=manager~ack(.VMMInstitutionalSyntheticQueueBuild~offerQueue,p~packageId,p~claimToken,clientPrincipal); if \a~ok then return a; return .QueueOperationResult~success(o,"synthetic offer received")
::method submitAcceptance
  expose manager clientPrincipal clientEntity counterpartyId submittedAcceptances
  use strict arg msg
  if \msg~isA(.VMMInstitutionalSyntheticAcceptance) then raise syntax 88.900 array("VMMInstitutionalSyntheticAcceptance required")
  if msg~sourceEntity<>clientEntity | msg~counterpartyId<>counterpartyId then raise syntax 88.900 array("institutional synthetic client acceptance identity mismatch")
  prior=submittedAcceptances[msg~idempotencyKey]; if prior<>.nil then return .QueueOperationResult~success(prior,"idempotent institutional acceptance")
  r=self~put(.VMMInstitutionalSyntheticQueueBuild~acceptQueue,msg,msg~correlationId,"ACCEPT",msg~idempotencyKey); if r~ok then submittedAcceptances[msg~idempotencyKey]=msg; return r
::method receiveConfirmation
  expose manager clientPrincipal
  r=manager~claim(.VMMInstitutionalSyntheticQueueBuild~confirmQueue,clientPrincipal); if \r~ok then return r
  p=r~value; c=p~payload; a=manager~ack(.VMMInstitutionalSyntheticQueueBuild~confirmQueue,p~packageId,p~claimToken,clientPrincipal); if \a~ok then return a; return .QueueOperationResult~success(c,"synthetic confirmation received")
::method put private
  expose manager clientPrincipal
  use strict arg queueName,payload,correlationId,kind,idempotencyKey
  o=.table~new; o["persistent"]=.true; o["correlationId"]=correlationId; h=.table~new; h["protocol"]=.VMMInstitutionalSyntheticQueueBuild~protocol; h["kind"]=kind; h["idempotencyKey"]=idempotencyKey; o["headers"]=h
  return manager~put(queueName,payload,o,clientPrincipal)

::requires "VMMSyntheticProducts.cls"
::requires "ObjectQueueFabric.cls"
