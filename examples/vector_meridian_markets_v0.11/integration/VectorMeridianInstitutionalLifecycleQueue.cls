/* VectorMeridianInstitutionalLifecycleQueue.cls -- institutional synthetic lifecycle boundary v0.6 */

::class VMMInstitutionalLifecycleQueueBuild public
::method protocol class; return "vmm.institutional.synthetic.lifecycle/0.6"
::method instructionQueue class; return "VMM.INSTITUTIONAL.SYNTHETIC.LIFECYCLE.INSTRUCTION"
::method resultQueue class; return "VMM.INSTITUTIONAL.SYNTHETIC.LIFECYCLE.RESULT"
::method securityDomain class; return "VMM_INSTITUTIONAL_SYNTHETIC_LIFECYCLE"
::method vmmPrincipal class; return "VECTOR_MERIDIAN_SYNTHETIC_LIFECYCLE"
::method adminPrincipal class; return "VECTOR_MERIDIAN_SYNTHETIC_ADMIN"


::class VMMInstitutionalPremiumPaymentNotice public
::method init
  expose noticeId idempotencyKey correlationId contractId periodId counterpartyId sourceEntity sourceAuthority currency amount paymentEvidenceRef paidAt
  use arg noticeId="",idempotencyKey="",correlationId="",contractId="",periodId="",counterpartyId="",sourceEntity="",sourceAuthority="",currency="",amount=0,paymentEvidenceRef="",paidAt=""
  if noticeId="" & correlationId="" then return
  if noticeId="" | idempotencyKey="" | correlationId="" | contractId="" | periodId="" | counterpartyId="" | sourceEntity="" | sourceAuthority="" | currency="" | paymentEvidenceRef="" | paidAt="" | amount<=0 then raise syntax 88.900 array("invalid VMM institutional premium payment notice")
::method noticeId; expose noticeId; return noticeId
::method requestId; expose noticeId; return noticeId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method contractId; expose contractId; return contractId
::method periodId; expose periodId; return periodId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method sourceEntity; expose sourceEntity; return sourceEntity
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method currency; expose currency; return currency
::method amount; expose amount; return amount
::method paymentEvidenceRef; expose paymentEvidenceRef; return paymentEvidenceRef
::method paidAt; expose paidAt; return paidAt
::method queuePersistentType; return "vmm.synthetic.lifecycle.premium-payment/1"
::method queuePersistentState
  expose noticeId idempotencyKey correlationId contractId periodId counterpartyId sourceEntity sourceAuthority currency amount paymentEvidenceRef paidAt
  d=.table~new; d["noticeId"]=noticeId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["contractId"]=contractId; d["periodId"]=periodId; d["counterpartyId"]=counterpartyId; d["sourceEntity"]=sourceEntity; d["sourceAuthority"]=sourceAuthority; d["currency"]=currency; d["amount"]=amount; d["paymentEvidenceRef"]=paymentEvidenceRef; d["paidAt"]=paidAt; return d
::method queueRestoreState
  expose noticeId idempotencyKey correlationId contractId periodId counterpartyId sourceEntity sourceAuthority currency amount paymentEvidenceRef paidAt
  use arg d
  noticeId=d["noticeId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; contractId=d["contractId"]; periodId=d["periodId"]; counterpartyId=d["counterpartyId"]; sourceEntity=d["sourceEntity"]; sourceAuthority=d["sourceAuthority"]; currency=d["currency"]; amount=d["amount"]; paymentEvidenceRef=d["paymentEvidenceRef"]; paidAt=d["paidAt"]; return .true
::class VMMInstitutionalPremiumPaymentNoticeFactory public
::method newBlank; return .VMMInstitutionalPremiumPaymentNotice~new


::class VMMInstitutionalReferenceChangeRequest public
::method init
  expose requestId idempotencyKey correlationId contractId newSnapshotId changeType counterpartyId sourceEntity sourceAuthority effectiveAt changeEvidenceRef
  use arg requestId="",idempotencyKey="",correlationId="",contractId="",newSnapshotId="",changeType="",counterpartyId="",sourceEntity="",sourceAuthority="",effectiveAt="",changeEvidenceRef=""
  if requestId="" & correlationId="" then return
  if requestId="" | idempotencyKey="" | correlationId="" | contractId="" | newSnapshotId="" | counterpartyId="" | sourceEntity="" | sourceAuthority="" | effectiveAt="" | changeEvidenceRef="" then raise syntax 88.900 array("invalid VMM institutional reference change request")
  if changeType<>"CLIENT_SUBSTITUTION" & changeType<>"CORPORATE_ACTION" then raise syntax 88.900 array("invalid VMM institutional reference change type",changeType)
::method requestId; expose requestId; return requestId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method contractId; expose contractId; return contractId
::method newSnapshotId; expose newSnapshotId; return newSnapshotId
::method changeType; expose changeType; return changeType
::method counterpartyId; expose counterpartyId; return counterpartyId
::method sourceEntity; expose sourceEntity; return sourceEntity
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method effectiveAt; expose effectiveAt; return effectiveAt
::method changeEvidenceRef; expose changeEvidenceRef; return changeEvidenceRef
::method queuePersistentType; return "vmm.synthetic.lifecycle.reference-change/1"
::method queuePersistentState
  expose requestId idempotencyKey correlationId contractId newSnapshotId changeType counterpartyId sourceEntity sourceAuthority effectiveAt changeEvidenceRef
  d=.table~new; d["requestId"]=requestId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["contractId"]=contractId; d["newSnapshotId"]=newSnapshotId; d["changeType"]=changeType; d["counterpartyId"]=counterpartyId; d["sourceEntity"]=sourceEntity; d["sourceAuthority"]=sourceAuthority; d["effectiveAt"]=effectiveAt; d["changeEvidenceRef"]=changeEvidenceRef; return d
::method queueRestoreState
  expose requestId idempotencyKey correlationId contractId newSnapshotId changeType counterpartyId sourceEntity sourceAuthority effectiveAt changeEvidenceRef
  use arg d
  requestId=d["requestId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; contractId=d["contractId"]; newSnapshotId=d["newSnapshotId"]; changeType=d["changeType"]; counterpartyId=d["counterpartyId"]; sourceEntity=d["sourceEntity"]; sourceAuthority=d["sourceAuthority"]; effectiveAt=d["effectiveAt"]; changeEvidenceRef=d["changeEvidenceRef"]; return .true
::class VMMInstitutionalReferenceChangeRequestFactory public
::method newBlank; return .VMMInstitutionalReferenceChangeRequest~new


::class VMMInstitutionalLifecycleResult public
::method init
  expose resultId requestId correlationId actionType contractId status referenceId processedAt vmmEntity
  use arg resultId="",requestId="",correlationId="",actionType="",contractId="",status="",referenceId="",processedAt="",vmmEntity=""
  if resultId="" & correlationId="" then return
  if resultId="" | requestId="" | correlationId="" | actionType="" | contractId="" | status="" | referenceId="" | processedAt="" | vmmEntity<>"VECTOR_MERIDIAN_MARKETS_LTD" then raise syntax 88.900 array("invalid VMM institutional lifecycle result")
::method resultId; expose resultId; return resultId
::method requestId; expose requestId; return requestId
::method correlationId; expose correlationId; return correlationId
::method actionType; expose actionType; return actionType
::method contractId; expose contractId; return contractId
::method status; expose status; return status
::method referenceId; expose referenceId; return referenceId
::method processedAt; expose processedAt; return processedAt
::method vmmEntity; expose vmmEntity; return vmmEntity
::method queuePersistentType; return "vmm.synthetic.lifecycle.result/1"
::method queuePersistentState
  expose resultId requestId correlationId actionType contractId status referenceId processedAt vmmEntity
  d=.table~new; d["resultId"]=resultId; d["requestId"]=requestId; d["correlationId"]=correlationId; d["actionType"]=actionType; d["contractId"]=contractId; d["status"]=status; d["referenceId"]=referenceId; d["processedAt"]=processedAt; d["vmmEntity"]=vmmEntity; return d
::method queueRestoreState
  expose resultId requestId correlationId actionType contractId status referenceId processedAt vmmEntity
  use arg d
  resultId=d["resultId"]; requestId=d["requestId"]; correlationId=d["correlationId"]; actionType=d["actionType"]; contractId=d["contractId"]; status=d["status"]; referenceId=d["referenceId"]; processedAt=d["processedAt"]; vmmEntity=d["vmmEntity"]; return .true
::class VMMInstitutionalLifecycleResultFactory public
::method newBlank; return .VMMInstitutionalLifecycleResult~new


::class VMMInstitutionalLifecycleQueueService public
::method init
  expose productService manager adminPrincipal clientPrincipal vmmPrincipal clientEntity counterpartyId processedByKey
  use strict arg productService,stateRoot,clientPrincipal,clientEntity,counterpartyId,adminPrincipal="VECTOR_MERIDIAN_SYNTHETIC_ADMIN",vmmPrincipal="VECTOR_MERIDIAN_SYNTHETIC_LIFECYCLE"
  if productService==.nil | stateRoot="" | clientPrincipal="" | clientEntity="" | counterpartyId="" then raise syntax 88.900 array("institutional lifecycle queue service requires product service, durable root and client identity")
  registry=.QueuePayloadTypeRegistry~new
  ignore=registry~register("vmm.synthetic.lifecycle.premium-payment/1",.VMMInstitutionalPremiumPaymentNoticeFactory~new)
  ignore=registry~register("vmm.synthetic.lifecycle.reference-change/1",.VMMInstitutionalReferenceChangeRequestFactory~new)
  ignore=registry~register("vmm.synthetic.lifecycle.result/1",.VMMInstitutionalLifecycleResultFactory~new)
  manager=.ObjectQueueManager~new(stateRoot,.QueueGraphPayloadCodec~new(registry),adminPrincipal)
  processedByKey=.directory~new
  self~ensureQueues
::method manager; expose manager; return manager
::method processNextInstruction
  expose productService manager vmmPrincipal clientEntity counterpartyId processedByKey
  use strict arg processedAt,riskApprovalRef="",vmmAuthority=""
  claim=manager~claim(.VMMInstitutionalLifecycleQueueBuild~instructionQueue,vmmPrincipal); if \claim~ok then return claim
  package=claim~value; msg=package~payload
  if \msg~hasMethod("idempotencyKey") | \msg~hasMethod("sourceEntity") | \msg~hasMethod("counterpartyId") then return self~reject(package,"INVALID_LIFECYCLE_INSTRUCTION")
  if msg~sourceEntity<>clientEntity | msg~counterpartyId<>counterpartyId then return self~reject(package,"INSTITUTIONAL_IDENTITY_MISMATCH")
  prior=processedByKey[msg~idempotencyKey]
  if prior<>.nil then do
    pub=self~put(.VMMInstitutionalLifecycleQueueBuild~resultQueue,prior,msg~correlationId,"RESULT",msg~idempotencyKey,vmmPrincipal); if \pub~ok then return self~retry(package,pub)
    ignore=self~ack(package,vmmPrincipal); return .QueueOperationResult~success(prior,"idempotent institutional lifecycle instruction")
  end
  k=productService~contract(msg~contractId); if k==.nil | k~counterpartyId<>counterpartyId then return self~reject(package,"CONTRACT_COUNTERPARTY_MISMATCH")
  if msg~isA(.VMMInstitutionalPremiumPaymentNotice) then do
    s=.VMMSyntheticPremiumSettlement~new("SET-"||msg~noticeId,msg~contractId,msg~periodId,msg~currency,msg~amount,msg~sourceEntity,"VECTOR_MERIDIAN_MARKETS_LTD",msg~paymentEvidenceRef,msg~paidAt,msg~sourceAuthority)
    x=productService~recordPremiumSettlement(s)
    result=.VMMInstitutionalLifecycleResult~new("RES-"||msg~noticeId,msg~noticeId,msg~correlationId,"PREMIUM_PAYMENT",msg~contractId,"RECORDED",x~settlementId,processedAt,productService~vmm~legalEntity)
  end
  else if msg~isA(.VMMInstitutionalReferenceChangeRequest) then do
    if riskApprovalRef="" | vmmAuthority="" then return self~reject(package,"VMM_REFERENCE_CHANGE_APPROVAL_REQUIRED")
    x=productService~applyPortfolioChange("CHG-"||msg~requestId,msg~contractId,msg~newSnapshotId,msg~changeType,msg~effectiveAt,msg~changeEvidenceRef,riskApprovalRef,vmmAuthority)
    result=.VMMInstitutionalLifecycleResult~new("RES-"||msg~requestId,msg~requestId,msg~correlationId,"REFERENCE_CHANGE",msg~contractId,"RECORDED",x~changeId,processedAt,productService~vmm~legalEntity)
  end
  else return self~reject(package,"UNSUPPORTED_LIFECYCLE_INSTRUCTION")
  pub=self~put(.VMMInstitutionalLifecycleQueueBuild~resultQueue,result,msg~correlationId,"RESULT",msg~idempotencyKey,vmmPrincipal); if \pub~ok then return self~retry(package,pub)
  processedByKey[msg~idempotencyKey]=result; ignore=self~ack(package,vmmPrincipal)
  return .QueueOperationResult~success(result,"institutional lifecycle instruction recorded")
::method ensureQueues private
  expose manager adminPrincipal clientPrincipal vmmPrincipal
  domain=.VMMInstitutionalLifecycleQueueBuild~securityDomain
  q=.VMMInstitutionalLifecycleQueueBuild~instructionQueue; if manager~queue(q)==.nil then self~must(manager~createQueue(q,"PERMANENT",domain,0,adminPrincipal),"create lifecycle instruction queue")
  q=.VMMInstitutionalLifecycleQueueBuild~resultQueue; if manager~queue(q)==.nil then self~must(manager~createQueue(q,"PERMANENT",domain,0,adminPrincipal),"create lifecycle result queue")
  self~must(manager~grant(.VMMInstitutionalLifecycleQueueBuild~instructionQueue,clientPrincipal,.QueueAccess~PUT,adminPrincipal),"client lifecycle PUT")
  self~must(manager~grant(.VMMInstitutionalLifecycleQueueBuild~instructionQueue,vmmPrincipal,.QueueAccess~GET,adminPrincipal),"VMM lifecycle GET")
  self~must(manager~grant(.VMMInstitutionalLifecycleQueueBuild~resultQueue,vmmPrincipal,.QueueAccess~PUT,adminPrincipal),"VMM lifecycle result PUT")
  self~must(manager~grant(.VMMInstitutionalLifecycleQueueBuild~resultQueue,clientPrincipal,.QueueAccess~GET,adminPrincipal),"client lifecycle result GET")
::method put private
  expose manager
  use strict arg queueName,payload,correlationId,kind,idempotencyKey,principal
  o=.table~new; o["persistent"]=.true; o["correlationId"]=correlationId; h=.table~new; h["protocol"]=.VMMInstitutionalLifecycleQueueBuild~protocol; h["kind"]=kind; h["idempotencyKey"]=idempotencyKey; o["headers"]=h
  return manager~put(queueName,payload,o,principal)
::method ack private
  expose manager
  use strict arg package,principal
  return manager~ack(.VMMInstitutionalLifecycleQueueBuild~instructionQueue,package~packageId,package~claimToken,principal)
::method reject private
  expose manager vmmPrincipal
  use strict arg package,code
  ignore=manager~nack(.VMMInstitutionalLifecycleQueueBuild~instructionQueue,package~packageId,package~claimToken,vmmPrincipal); return .QueueOperationResult~failure(code)
::method retry private
  expose manager vmmPrincipal
  use strict arg package,failure
  ignore=manager~nack(.VMMInstitutionalLifecycleQueueBuild~instructionQueue,package~packageId,package~claimToken,vmmPrincipal); return failure
::method must private
  use strict arg result,label
  if \result~ok then raise syntax 88.900 array("institutional lifecycle Queue Fabric setup failed",label,result~code,result~detail)
  return result


::class VMMInstitutionalLifecycleQueueClient public
::method init
  expose manager clientPrincipal clientEntity counterpartyId submitted
  use strict arg manager,clientPrincipal,clientEntity,counterpartyId
  if manager==.nil | clientPrincipal="" | clientEntity="" | counterpartyId="" then raise syntax 88.900 array("institutional lifecycle queue client requires manager and legal identity")
  submitted=.directory~new
::method submitInstruction
  expose manager clientPrincipal clientEntity counterpartyId submitted
  use strict arg msg
  if \msg~isA(.VMMInstitutionalPremiumPaymentNotice) & \msg~isA(.VMMInstitutionalReferenceChangeRequest) then raise syntax 88.900 array("unsupported institutional lifecycle message")
  if msg~sourceEntity<>clientEntity | msg~counterpartyId<>counterpartyId then raise syntax 88.900 array("institutional lifecycle client identity mismatch")
  prior=submitted[msg~idempotencyKey]; if prior<>.nil then return .QueueOperationResult~success(prior,"idempotent institutional lifecycle submit")
  o=.table~new; o["persistent"]=.true; o["correlationId"]=msg~correlationId; h=.table~new; h["protocol"]=.VMMInstitutionalLifecycleQueueBuild~protocol; h["kind"]="INSTRUCTION"; h["idempotencyKey"]=msg~idempotencyKey; o["headers"]=h
  r=manager~put(.VMMInstitutionalLifecycleQueueBuild~instructionQueue,msg,o,clientPrincipal); if r~ok then submitted[msg~idempotencyKey]=msg; return r
::method receiveResult
  expose manager clientPrincipal
  r=manager~claim(.VMMInstitutionalLifecycleQueueBuild~resultQueue,clientPrincipal); if \r~ok then return r
  p=r~value; x=p~payload; a=manager~ack(.VMMInstitutionalLifecycleQueueBuild~resultQueue,p~packageId,p~claimToken,clientPrincipal); if \a~ok then return a; return .QueueOperationResult~success(x,"institutional lifecycle result received")

::requires "VMMSyntheticProducts.cls"
::requires "ObjectQueueFabric.cls"
